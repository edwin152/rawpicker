import AppKit
import Foundation

@MainActor
final class FileSelectionService {
    func openSources(completion: @escaping @MainActor ([URL]) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = []
        open(panel, completion: completion)
    }

    func openExportDirectory(completion: @escaping @MainActor (URL) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = L10n.ui("Export")
        open(panel) { urls in
            guard let url = urls.first else { return }
            completion(url)
        }
    }

    private func open(_ panel: NSOpenPanel, completion: @escaping @MainActor ([URL]) -> Void) {
        panel.begin { response in
            guard response == .OK else { return }
            Task { @MainActor in
                completion(panel.urls)
            }
        }
    }
}
