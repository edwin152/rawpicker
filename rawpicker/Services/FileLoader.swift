import Foundation

enum FileLoader {
    static let supportedExtensions: Set<String> = [
        "raf", "dng", "nef", "cr2", "cr3", "arw", "rw2", "orf", "pef"
    ]

    static func assets(from urls: [URL]) -> [RawAsset] {
        let files = urls.flatMap { url in
            if url.hasDirectoryPath {
                return scanFolder(url)
            }
            return isExistingSupportedFile(url) ? [url] : []
        }

        return files
            .uniqued()
            .sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
            .map { RawAsset(id: $0.standardizedFileURL.path, url: $0) }
    }

    static func scanFolder(_ folder: URL) -> [URL] {
        let keys: [URLResourceKey] = [.isRegularFileKey, .isDirectoryKey, .isHiddenKey]
        guard let enumerator = FileManager.default.enumerator(
            at: folder,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }

        return enumerator.compactMap { item in
            guard let url = item as? URL else { return nil }
            return isSupported(url) ? url : nil
        }
    }

    static func isSupported(_ url: URL) -> Bool {
        supportedExtensions.contains(url.pathExtension.lowercased())
    }

    private static func isExistingSupportedFile(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
            && !isDirectory.boolValue
            && isSupported(url)
    }
}

private extension Array where Element == URL {
    func uniqued() -> [URL] {
        var seen = Set<String>()
        return filter { url in
            seen.insert(url.standardizedFileURL.path).inserted
        }
    }
}
