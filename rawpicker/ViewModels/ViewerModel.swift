import Combine
import SwiftUI

@MainActor
final class ViewerModel: ObservableObject {
    @Published private(set) var assets: [RawAsset] = []
    @Published private(set) var visibleAssets: [RawAsset] = []
    @Published var currentIndex: Int = 0
    @Published var currentImage: DecodedImage?
    @Published var thumbnails: [String: DecodedImage] = [:]
    @Published var exif = ExifInfo()
    @Published var isLoading = false
    @Published var statusText = L10n.openPrompt
    @Published var isFitMode = true
    @Published var zoomScale: CGFloat = 1
    @Published var panOffset: CGSize = .zero
    @Published var showExif = true
    @Published var showFavoritesOnly = false
    @Published private(set) var ratingByID: [String: Int] = [:]
    @Published var isZoomed = false
    @Published private(set) var isExportingFavorites = false

    private var decoder = RawDecoder()
    private var cache = ImageCache(capacity: 56)
    private let fileSelectionService = FileSelectionService()
    private let navigationPaceTracker = NavigationPaceTracker()
    private let sessionStore = ViewerSessionStore()
    private var favoriteFilteredAssets: [RawAsset] = []
    private var baseIndex = 0
    private var favoriteIndex = 0
    private var currentTask: Task<Void, Never>?
    private var decodeTasks: [CacheKey: Task<DecodedImage?, Never>] = [:]
    private var thumbnailTasks: [String: Task<Void, Never>] = [:]
    private var viewportSettlingTask: Task<Void, Never>?
    private var ratingLoadTask: Task<Void, Never>?
    private var activeRepeatDirection: Int?
    private var loadedSourceURLs: [URL] = []
    private var securityScopedSourceURLs: [URL] = []

    init() {
        restoreLastSession()
    }

    var currentAsset: RawAsset? {
        guard visibleAssets.indices.contains(currentIndex) else { return nil }
        return visibleAssets[currentIndex]
    }

    var hasProject: Bool {
        !loadedSourceURLs.isEmpty || !assets.isEmpty || currentImage != nil
    }

    var hasCurrentAsset: Bool {
        currentAsset != nil
    }

    var canGoPrevious: Bool {
        !visibleAssets.isEmpty && currentIndex > 0
    }

    var canGoNext: Bool {
        !visibleAssets.isEmpty && currentIndex < visibleAssets.count - 1
    }

    var canToggleFavoritesFilter: Bool {
        !assets.isEmpty
    }

    var favoriteCount: Int {
        assets.filter { isFavorite($0) }.count
    }

    var canExportFavorites: Bool {
        favoriteCount > 0 && !isExportingFavorites
    }

    func open() {
        fileSelectionService.openSources { [weak self] urls in
            self?.load(urls: urls)
        }
    }

    func closeProject() {
        resetToInitialState(clearSession: true)
    }

    func load(urls: [URL]) {
        load(urls: urls, selectedAssetID: nil, shouldPersist: true)
    }

    private func load(urls: [URL], selectedAssetID: String?, shouldPersist: Bool) {
        cancelWork()
        resetRuntimeCaches()
        replaceSecurityScopedSourceURLs(with: urls)
        if shouldPersist {
            sessionStore.clear()
        }
        loadedSourceURLs = urls.map(\.standardizedFileURL)
        assets = FileLoader.assets(from: urls)
        favoriteFilteredAssets = []
        baseIndex = 0
        favoriteIndex = 0
        ratingByID = [:]
        loadRatings(for: assets)
        thumbnails = [:]
        if let selectedAssetID,
           let restoredIndex = assets.firstIndex(where: { $0.id == selectedAssetID }) {
            baseIndex = restoredIndex
        }
        currentImage = nil
        exif = ExifInfo()
        showFavoritesOnly = false
        activateCurrentList()
        statusText = assets.isEmpty ? L10n.noSupportedRawFiles : L10n.rawFilesLoaded(assets.count)
        if shouldPersist {
            persistSession()
        }
        loadCurrent(resetViewport: true, strategy: .slow(direction: 0))
    }

    func goPrevious(isRepeat: Bool = false) {
        guard !visibleAssets.isEmpty else { return }
        navigate(to: max(0, currentIndex - 1), direction: -1, isRepeat: isRepeat)
    }

    func goNext(isRepeat: Bool = false) {
        guard !visibleAssets.isEmpty else { return }
        navigate(to: min(visibleAssets.count - 1, currentIndex + 1), direction: 1, isRepeat: isRepeat)
    }

    func select(index: Int) {
        guard visibleAssets.indices.contains(index), index != currentIndex else { return }
        setCurrentIndex(index)
        persistSession()
        loadCurrent(resetViewport: true, strategy: .slow(direction: 0))
    }

    func endDirectionalNavigation() {
        guard let direction = activeRepeatDirection else { return }
        activeRepeatDirection = nil
        loadCurrent(resetViewport: false, strategy: navigationPaceTracker.strategy(for: direction))
    }

    func toggleFavoriteCurrent() {
        guard let asset = currentAsset else { return }
        let oldRating = rating(for: asset)
        let newRating = oldRating == XmpRatingStore.favoriteRating
            ? XmpRatingStore.defaultRating
            : XmpRatingStore.favoriteRating

        setRating(newRating, for: asset, revertingTo: oldRating)
    }

    func toggleFavoritesFilter() {
        showFavoritesOnly.toggle()
        applyFavoriteFilter()
    }

    func exportFavorites(mode: FavoriteExportMode) {
        let favorites = assets.filter { isFavorite($0) }
        guard !favorites.isEmpty, !isExportingFavorites else { return }

        fileSelectionService.openExportDirectory { [weak self] directoryURL in
            guard let self else { return }
            self.exportFavorites(favorites, to: directoryURL, mode: mode)
        }
    }

    func isFavorite(_ asset: RawAsset) -> Bool {
        rating(for: asset) == XmpRatingStore.favoriteRating
    }

    func rating(for asset: RawAsset) -> Int {
        ratingByID[asset.id, default: XmpRatingStore.defaultRating]
    }

    func toggleFit() {
        isFitMode.toggle()
        if isFitMode {
            panOffset = .zero
        } else {
            zoomScale = 1
        }
        onZoomChanged()
    }

    func zoomIn() {
        isFitMode = false
        zoomScale = min(12, zoomScale * 1.25)
        onZoomChanged()
    }

    func zoomOut() {
        isFitMode = false
        zoomScale = max(0.1, zoomScale / 1.25)
        onZoomChanged()
    }

    func onZoomChanged() {
        isZoomed = !isFitMode
        guard isZoomed else {
            viewportSettlingTask?.cancel()
            viewportSettlingTask = nil
            return
        }

        scheduleSettledHighQualityDecode(displayScale: Double(zoomScale))
    }

    func onViewportChanged(displayScale: CGFloat) {
        isZoomed = !isFitMode
        guard isZoomed else {
            viewportSettlingTask?.cancel()
            viewportSettlingTask = nil
            return
        }

        scheduleSettledHighQualityDecode(displayScale: Double(displayScale))
    }

    private func scheduleSettledHighQualityDecode(displayScale: Double) {
        guard let asset = currentAsset else { return }

        viewportSettlingTask?.cancel()
        cancelFullDecodeForCurrent()
        let request = ZoomDecodeRequest(
            assetID: asset.id,
            index: currentIndex,
            displayScale: displayScale
        )

        viewportSettlingTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 700_000_000)
            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard let self,
                      self.isZoomed,
                      self.currentIndex == request.index,
                      self.currentAsset?.id == request.assetID,
                      abs(Double(self.zoomScale) - request.displayScale) < 0.001
                else { return }

                self.triggerFullDecodeForCurrent()
            }
        }
    }

    private func cancelFullDecodeForCurrent() {
        guard let asset = currentAsset else { return }
        let fullKey = CacheKey(assetID: asset.id, kind: .full)
        guard let task = decodeTasks[fullKey], !task.isCancelled else { return }

        task.cancel()
        decodeTasks[fullKey] = nil
        isLoading = false
    }

    private func triggerFullDecodeForCurrent() {
        guard let asset = currentAsset else { return }
        let index = currentIndex
        isLoading = true
        let fullKey = CacheKey(assetID: asset.id, kind: .full)
        Task {
            if let full = await cache.image(for: fullKey) {
                if currentIndex == index, currentAsset?.id == asset.id {
                    preserveViewportWhenReplacingPreview(with: full)
                    currentImage = full
                    isLoading = false
                }
                return
            }
            if let full = await imageTask(for: asset, kind: .full, priority: .utility).value {
                if currentIndex == index, currentAsset?.id == asset.id {
                    preserveViewportWhenReplacingPreview(with: full)
                    currentImage = full
                    isLoading = false
                }
            } else {
                if currentIndex == index, currentAsset?.id == asset.id {
                    isLoading = false
                }
            }
        }
    }

    func loadThumbnail(for asset: RawAsset) {
        if thumbnails[asset.id] != nil || thumbnailTasks[asset.id] != nil {
            return
        }

        thumbnailTasks[asset.id] = Task { [asset] in
            let key = CacheKey(assetID: asset.id, kind: .thumbnail)
            if let cached = await cache.image(for: key) {
                await MainActor.run {
                    thumbnails[asset.id] = cached
                    thumbnailTasks[asset.id] = nil
                }
                return
            }

            guard let image = await decodeThumbnail(asset) else {
                await MainActor.run {
                    thumbnailTasks[asset.id] = nil
                }
                return
            }

            await cache.insert(image, for: key)
            await MainActor.run {
                thumbnails[asset.id] = image
                thumbnailTasks[asset.id] = nil
            }
        }
    }

    private func navigate(to index: Int, direction: Int, isRepeat: Bool) {
        guard visibleAssets.indices.contains(index), index != currentIndex else { return }
        navigationPaceTracker.record(direction: direction)
        setCurrentIndex(index)
        persistSession()

        if isRepeat {
            activeRepeatDirection = direction
            scrubToCurrentAsset()
        } else {
            activeRepeatDirection = nil
            loadCurrent(resetViewport: true, strategy: navigationPaceTracker.strategy(for: direction))
        }
    }

    private func scrubToCurrentAsset() {
        currentTask?.cancel()

        for (key, task) in decodeTasks where key.kind == .full {
            task.cancel()
        }
        decodeTasks = decodeTasks.filter { $0.key.kind != .full }

        guard let asset = currentAsset else { return }

        isFitMode = true
        zoomScale = 1
        panOffset = .zero
        isZoomed = false
        statusText = asset.displayName
        isLoading = false

        let previewKey = CacheKey(assetID: asset.id, kind: .preview)
        if let thumb = thumbnails[asset.id] {
            currentImage = thumb
        }

        Task {
            if let preview = await cache.image(for: previewKey) {
                if currentIndex == visibleAssets.firstIndex(where: { $0.id == asset.id }) ?? -1 {
                    currentImage = preview
                }
            }
        }
    }

    private func setCurrentIndex(_ index: Int) {
        currentIndex = clampedIndex(index, count: visibleAssets.count)
        if showFavoritesOnly {
            favoriteIndex = currentIndex
        } else {
            baseIndex = currentIndex
        }
    }

    private func activateCurrentList() {
        if showFavoritesOnly {
            visibleAssets = favoriteFilteredAssets
            favoriteIndex = clampedIndex(favoriteIndex, count: visibleAssets.count)
            currentIndex = favoriteIndex
        } else {
            visibleAssets = assets
            baseIndex = clampedIndex(baseIndex, count: visibleAssets.count)
            currentIndex = baseIndex
        }
    }

    private func clampedIndex(_ index: Int, count: Int) -> Int {
        min(max(index, 0), max(count - 1, 0))
    }

    private func rebuildFavoriteList() {
        favoriteFilteredAssets = assets.filter { isFavorite($0) }
        favoriteIndex = clampedIndex(favoriteIndex, count: favoriteFilteredAssets.count)
    }

    private func applyFavoriteFilter() {
        if showFavoritesOnly {
            rebuildFavoriteList()
        }

        activateCurrentList()
        persistSession()

        currentImage = nil
        exif = ExifInfo()
        statusText = visibleAssets.isEmpty
            ? (showFavoritesOnly ? "" : L10n.noSupportedRawFiles)
            : (showFavoritesOnly ? L10n.favoriteRawFilesVisible(visibleAssets.count) : L10n.rawFilesVisible(visibleAssets.count))
        loadCurrent(resetViewport: true, strategy: .slow(direction: 0))
    }

    private func loadCurrent(resetViewport: Bool, strategy: PreloadStrategy) {
        currentTask?.cancel()

        guard let asset = currentAsset else {
            decodeTasks.values.forEach { $0.cancel() }
            decodeTasks.removeAll()
            isLoading = false
            return
        }

        if resetViewport {
            isFitMode = true
            zoomScale = 1
            panOffset = .zero
            isZoomed = false
        }

        isLoading = true
        statusText = asset.displayName
        scheduleDecodeWindow(around: currentIndex, strategy: strategy)

        currentTask = Task { [asset, index = currentIndex] in
            async let exifInfo = readExif(asset)

            if let full = await cache.image(for: CacheKey(assetID: asset.id, kind: .full)) {
                publish(full, exif: await exifInfo, assetID: asset.id, index: index, loading: false)
                return
            }

            if let preview = await cache.image(for: CacheKey(assetID: asset.id, kind: .preview)) {
                publish(preview, exif: await exifInfo, assetID: asset.id, index: index, loading: false)
            } else if let thumbnail = await cache.image(for: CacheKey(assetID: asset.id, kind: .thumbnail)) {
                publish(thumbnail, exif: await exifInfo, assetID: asset.id, index: index, loading: true)
            }

            if Task.isCancelled { return }
            if await cache.image(for: CacheKey(assetID: asset.id, kind: .preview)) == nil,
               let preview = await imageTask(for: asset, kind: .preview, priority: .userInitiated).value {
                publish(preview, exif: await exifInfo, assetID: asset.id, index: index, loading: false)
            }

            if Task.isCancelled { return }

            if isZoomed {
                if let full = await imageTask(for: asset, kind: .full, priority: .userInitiated).value {
                    publish(full, exif: await exifInfo, assetID: asset.id, index: index, loading: false)
                } else {
                    publish(nil, exif: await exifInfo, assetID: asset.id, index: index, loading: false)
                }
            }
        }
    }

    private func publish(_ image: DecodedImage?, exif exifInfo: ExifInfo, assetID: String, index: Int, loading: Bool) {
        guard index == currentIndex, currentAsset?.id == assetID else { return }
        if let image {
            preserveViewportWhenReplacingPreview(with: image)
            currentImage = image
        }
        exif = exifInfo
        isLoading = loading
    }

    private func preserveViewportWhenReplacingPreview(with newImage: DecodedImage) {
        guard !isFitMode,
              let currentImage,
              currentImage.pixelSize.width > 0,
              newImage.pixelSize.width > 0,
              abs(currentImage.pixelSize.width - newImage.pixelSize.width) > 1
        else { return }

        zoomScale *= currentImage.pixelSize.width / newImage.pixelSize.width
    }

    private func scheduleDecodeWindow(around index: Int, strategy: PreloadStrategy) {
        let requests = decodeRequests(around: index, strategy: strategy)
        let wantedKeys = Set(requests.map(\.key))

        for (key, task) in decodeTasks where !wantedKeys.contains(key) {
            task.cancel()
            decodeTasks[key] = nil
        }

        for request in requests {
            _ = imageTask(for: request.asset, kind: request.kind, priority: request.priority)
        }
    }

    private func decodeRequests(around index: Int, strategy: PreloadStrategy) -> [DecodeRequest] {
        var requests: [DecodeRequest] = []
        for offset in strategy.offsets {
            let assetIndex = index + offset
            guard visibleAssets.indices.contains(assetIndex) else { continue }

            let asset = visibleAssets[assetIndex]
            let priority: TaskPriority = offset == 0 ? .userInitiated : .utility
            requests.append(DecodeRequest(asset: asset, kind: .thumbnail, priority: priority))
            requests.append(DecodeRequest(asset: asset, kind: .preview, priority: priority))

            guard offset == 0, isZoomed else { continue }
            requests.append(DecodeRequest(asset: asset, kind: .full, priority: priority))
        }
        return requests
    }

    private func imageTask(
        for asset: RawAsset,
        kind: ImageKind,
        priority: TaskPriority
    ) -> Task<DecodedImage?, Never> {
        let key = CacheKey(assetID: asset.id, kind: kind)
        if let task = decodeTasks[key] {
            return task
        }

        let task: Task<DecodedImage?, Never> = Task(priority: priority) { [cache] in
            if Task.isCancelled { return nil }
            if let cached = await cache.image(for: key) {
                return cached
            }

            let image = await Self.decode(asset, kind: kind, priority: priority)
            guard !Task.isCancelled, let image else {
                return nil
            }

            await cache.insert(image, for: key)
            return image
        }

        decodeTasks[key] = task

        if kind == .thumbnail {
            Task { [weak self, asset, task] in
                guard let image = await task.value else { return }
                await MainActor.run {
                    self?.thumbnails[asset.id] = image
                }
            }
        }

        return task
    }

    private func loadRatings(for assets: [RawAsset]) {
        ratingLoadTask?.cancel()

        ratingLoadTask = Task { [assets] in
            let ratings = await Task.detached(priority: .utility) {
                var ratings: [String: Int] = [:]
                for asset in assets {
                    if Task.isCancelled { return ratings }
                    let rating = await XmpRatingStore.rating(for: asset)
                    if await rating != XmpRatingStore.defaultRating {
                        ratings[asset.id] = rating
                    }
                }
                return ratings
            }.value

            guard !Task.isCancelled else { return }
            let expectedIDs = Set(assets.map(\.id))
            guard Set(self.assets.map(\.id)) == expectedIDs else { return }
            self.ratingByID = ratings
            self.rebuildFavoriteList()
            if self.showFavoritesOnly {
                self.activateCurrentList()
                self.currentImage = nil
                self.exif = ExifInfo()
                self.loadCurrent(resetViewport: true, strategy: .slow(direction: 0))
            }
        }
    }

    private func setRating(_ rating: Int, for asset: RawAsset, revertingTo oldRating: Int) {
        if rating == XmpRatingStore.defaultRating {
            ratingByID[asset.id] = nil
        } else {
            ratingByID[asset.id] = rating
        }

        if !showFavoritesOnly {
            rebuildFavoriteList()
        }

        Task { [asset, rating, oldRating] in
            do {
                try await Task.detached(priority: .utility) {
                    try await XmpRatingStore.setRating(rating, for: asset)
                }.value
            } catch {
                await MainActor.run {
                    if self.rating(for: asset) == rating {
                        if oldRating == XmpRatingStore.defaultRating {
                            self.ratingByID[asset.id] = nil
                        } else {
                            self.ratingByID[asset.id] = oldRating
                        }

                        if !self.showFavoritesOnly {
                            self.rebuildFavoriteList()
                        }
                    }
                    self.statusText = L10n.xmpWriteFailed(assetName: asset.displayName)
                }
            }
        }
    }

    private func exportFavorites(_ favorites: [RawAsset], to directoryURL: URL, mode: FavoriteExportMode) {
        isExportingFavorites = true
        statusText = L10n.exportFavoritesInProgress(favorites.count)

        Task { [favorites, directoryURL, mode] in
            let summary = await Task.detached(priority: .utility) {
                try? await FavoriteExporter.export(assets: favorites, to: directoryURL, mode: mode)
            }.value

            await MainActor.run {
                self.isExportingFavorites = false

                guard let summary else {
                    self.statusText = L10n.exportFavoritesFailed
                    return
                }

                if mode == .move, !summary.movedAssets.isEmpty {
                    self.reloadListsAfterMovingFavorites()
                }

                self.statusText = L10n.exportFavoritesCompleted(
                    summary.exportedCount,
                    failedCount: summary.failedCount,
                    mode: mode
                )
            }
        }
    }

    private func reloadListsAfterMovingFavorites() {
        let selectedAssetID = currentAsset?.id
        let fallbackIndex = currentIndex
        let wasShowingFavoritesOnly = showFavoritesOnly

        cancelWork()
        resetRuntimeCaches()
        thumbnails = [:]
        assets = FileLoader.assets(from: loadedSourceURLs)
        ratingByID = ratingByID.filter { id, _ in
            assets.contains { $0.id == id }
        }
        rebuildFavoriteList()

        if let selectedAssetID,
           let reloadedIndex = assets.firstIndex(where: { $0.id == selectedAssetID }) {
            baseIndex = reloadedIndex
        } else {
            baseIndex = clampedIndex(fallbackIndex, count: assets.count)
        }

        if wasShowingFavoritesOnly {
            favoriteIndex = clampedIndex(fallbackIndex, count: favoriteFilteredAssets.count)
        }

        activateCurrentList()
        currentImage = nil
        exif = ExifInfo()
        isLoading = false
        loadRatings(for: assets)
        persistSession()
        loadCurrent(resetViewport: true, strategy: .slow(direction: 0))
    }

    private static func decode(
        _ asset: RawAsset,
        kind: ImageKind,
        priority: TaskPriority
    ) async -> DecodedImage? {
        let decoder = await MainActor.run { RawDecoder() }
        let task: Task<DecodedImage?, Never> = Task.detached(priority: priority) {
            if Task.isCancelled { return nil }
            switch kind {
            case .thumbnail:
                return try? await decoder.decodeThumbnail(asset)
            case .preview:
                return try? await decoder.decodePreview(asset)
            case .full:
                return try? await decoder.decodeFull(asset)
            }
        }

        return await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            task.cancel()
        }
    }

    private func decodeThumbnail(_ asset: RawAsset) async -> DecodedImage? {
        let decoder = decoder
        return await Task.detached(priority: .utility) {
            try? await decoder.decodeThumbnail(asset)
        }.value
    }

    private func readExif(_ asset: RawAsset) async -> ExifInfo {
        let decoder = decoder
        return await Task.detached(priority: .utility) {
            await decoder.readExif(asset)
        }.value
    }

    private func cancelWork() {
        currentTask?.cancel()
        viewportSettlingTask?.cancel()
        ratingLoadTask?.cancel()
        viewportSettlingTask = nil
        ratingLoadTask = nil
        decodeTasks.values.forEach { $0.cancel() }
        decodeTasks.removeAll()
        thumbnailTasks.values.forEach { $0.cancel() }
        thumbnailTasks.removeAll()
    }

    private func resetRuntimeCaches() {
        let oldCache = cache
        let oldDecoder = decoder
        cache = ImageCache(capacity: 56)
        decoder = RawDecoder()
        oldDecoder.clearCaches()
        URLCache.shared.removeAllCachedResponses()
        Task {
            await oldCache.removeAll()
        }
    }

    private func restoreLastSession() {
        guard let session = sessionStore.load() else { return }

        let existingSources = session.sources.compactMap { source -> URL? in
            guard let url = source.resolvedURL() else { return nil }
            let didAccess = url.startAccessingSecurityScopedResource()
            defer {
                if didAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            var isDirectory: ObjCBool = false
            let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)

            if source.isDirectory {
                return exists && isDirectory.boolValue ? url : nil
            }

            return exists && !isDirectory.boolValue && FileLoader.isSupported(url) ? url : nil
        }

        let missingRequiredDirectory = session.sources.contains { source in
            guard source.isDirectory else { return false }
            return !existingSources.contains { $0.path == source.path }
        }

        guard !missingRequiredDirectory, !existingSources.isEmpty else {
            resetToInitialState(clearSession: true)
            return
        }

        load(urls: existingSources, selectedAssetID: session.selectedAssetID, shouldPersist: true)
    }

    private func persistSession() {
        guard !loadedSourceURLs.isEmpty else { return }
        sessionStore.save(sources: loadedSourceURLs, selectedAssetID: currentAsset?.id)
    }

    private func resetToInitialState(clearSession: Bool) {
        cancelWork()
        resetRuntimeCaches()
        releaseSecurityScopedSourceURLs()
        assets = []
        visibleAssets = []
        favoriteFilteredAssets = []
        baseIndex = 0
        favoriteIndex = 0
        loadedSourceURLs = []
        ratingByID = [:]
        thumbnails = [:]
        currentIndex = 0
        currentImage = nil
        exif = ExifInfo()
        isLoading = false
        statusText = L10n.openPrompt
        isFitMode = true
        zoomScale = 1
        panOffset = .zero
        isZoomed = false
        isExportingFavorites = false
        showFavoritesOnly = false
        activeRepeatDirection = nil
        if clearSession {
            sessionStore.clear()
        }
    }

    private func replaceSecurityScopedSourceURLs(with urls: [URL]) {
        releaseSecurityScopedSourceURLs()
        securityScopedSourceURLs = urls.filter { $0.startAccessingSecurityScopedResource() }
    }

    private func releaseSecurityScopedSourceURLs() {
        securityScopedSourceURLs.forEach { $0.stopAccessingSecurityScopedResource() }
        securityScopedSourceURLs = []
    }
}

private struct DecodeRequest {
    let asset: RawAsset
    let kind: ImageKind
    let priority: TaskPriority

    var key: CacheKey {
        CacheKey(assetID: asset.id, kind: kind)
    }
}

private struct ZoomDecodeRequest: Sendable {
    let assetID: String
    let index: Int
    let displayScale: Double
}
