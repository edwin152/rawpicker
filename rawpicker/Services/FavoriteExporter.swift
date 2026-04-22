import Foundation

enum FavoriteExportMode: Sendable {
    case copy
    case move
}

struct FavoriteExportSummary: Sendable {
    let mode: FavoriteExportMode
    let exportedCount: Int
    let failedCount: Int
    let movedAssets: [String: URL]
}

enum FavoriteExporter {
    static func export(
        assets: [RawAsset],
        to directoryURL: URL,
        mode: FavoriteExportMode
    ) throws -> FavoriteExportSummary {
        let fileManager = FileManager.default
        var exportedCount = 0
        var failedCount = 0
        var movedAssets: [String: URL] = [:]

        for asset in assets {
            do {
                let destinationURL = uniqueDestinationURL(
                    for: asset.url,
                    in: directoryURL,
                    mode: mode,
                    fileManager: fileManager
                )
                try transferItem(from: asset.url, to: destinationURL, mode: mode, fileManager: fileManager)
                try transferSidecar(
                    for: asset.url,
                    rawDestinationURL: destinationURL,
                    mode: mode,
                    fileManager: fileManager
                )

                exportedCount += 1
                if mode == .move {
                    movedAssets[asset.id] = destinationURL
                }
            } catch {
                failedCount += 1
            }
        }

        return FavoriteExportSummary(
            mode: mode,
            exportedCount: exportedCount,
            failedCount: failedCount,
            movedAssets: movedAssets
        )
    }

    private static func transferSidecar(
        for rawURL: URL,
        rawDestinationURL: URL,
        mode: FavoriteExportMode,
        fileManager: FileManager
    ) throws {
        let sidecarURL = rawURL.deletingPathExtension().appendingPathExtension("xmp")
        guard fileManager.fileExists(atPath: sidecarURL.path) else { return }

        let sidecarDestinationURL = rawDestinationURL.deletingPathExtension().appendingPathExtension("xmp")
        try transferItem(from: sidecarURL, to: sidecarDestinationURL, mode: mode, fileManager: fileManager)
    }

    private static func transferItem(
        from sourceURL: URL,
        to destinationURL: URL,
        mode: FavoriteExportMode,
        fileManager: FileManager
    ) throws {
        guard sourceURL.standardizedFileURL != destinationURL.standardizedFileURL else { return }

        switch mode {
        case .copy:
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
        case .move:
            try fileManager.moveItem(at: sourceURL, to: destinationURL)
        }
    }

    private static func uniqueDestinationURL(
        for sourceURL: URL,
        in directoryURL: URL,
        mode: FavoriteExportMode,
        fileManager: FileManager
    ) -> URL {
        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        let pathExtension = sourceURL.pathExtension
        let hasSidecar = fileManager.fileExists(
            atPath: sourceURL.deletingPathExtension().appendingPathExtension("xmp").path
        )
        var destinationURL = directoryURL.appendingPathComponent(sourceURL.lastPathComponent)

        if mode == .move,
           sourceURL.standardizedFileURL == destinationURL.standardizedFileURL {
            return destinationURL
        }

        guard destinationExists(destinationURL, hasSidecar: hasSidecar, fileManager: fileManager) else { return destinationURL }

        var suffix = 1
        repeat {
            let filename = pathExtension.isEmpty
                ? "\(baseName) \(suffix)"
                : "\(baseName) \(suffix).\(pathExtension)"
            destinationURL = directoryURL.appendingPathComponent(filename)
            suffix += 1
        } while destinationExists(destinationURL, hasSidecar: hasSidecar, fileManager: fileManager)

        return destinationURL
    }

    private static func destinationExists(
        _ destinationURL: URL,
        hasSidecar: Bool,
        fileManager: FileManager
    ) -> Bool {
        if fileManager.fileExists(atPath: destinationURL.path) {
            return true
        }

        guard hasSidecar else { return false }

        let sidecarDestinationURL = destinationURL.deletingPathExtension().appendingPathExtension("xmp")
        return fileManager.fileExists(atPath: sidecarDestinationURL.path)
    }
}
