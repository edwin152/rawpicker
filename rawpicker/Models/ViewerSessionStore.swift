import Foundation

final class ViewerSessionStore {
    func load() -> ViewerSession? {
        ViewerSession.load()
    }

    func save(sources: [URL], selectedAssetID: String?) {
        let sources = sources.map { url in
            ViewerSession.Source(url: url)
        }

        ViewerSession(
            sources: sources,
            selectedAssetID: selectedAssetID
        )
        .save()
    }

    func clear() {
        ViewerSession.clear()
    }
}

struct ViewerSession: Codable {
    static let storageKey = "RawPicker.LastSession"

    struct Source: Codable {
        let path: String
        let isDirectory: Bool
        let bookmarkData: Data?

        init(url: URL) {
            path = url.path
            isDirectory = url.isExistingDirectory
            bookmarkData = try? url.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        }

        func resolvedURL() -> URL? {
            guard let bookmarkData else {
                return URL(fileURLWithPath: path, isDirectory: isDirectory)
            }

            var isStale = false
            if let url = try? URL(
                resolvingBookmarkData: bookmarkData,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) {
                return url
            }

            return URL(fileURLWithPath: path, isDirectory: isDirectory)
        }
    }

    let sources: [Source]
    let selectedAssetID: String?

    static func load() -> ViewerSession? {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return nil }
        return try? JSONDecoder().decode(ViewerSession.self, from: data)
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: storageKey)
    }
}

private extension URL {
    var isExistingDirectory: Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) && isDirectory.boolValue
    }
}
