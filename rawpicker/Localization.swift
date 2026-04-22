import Foundation

enum L10n {
    private static let bundleName = "work.edwin.rawpicker_RawPicker.bundle"

    private static var bundle: Bundle {
        if let resourceURL = Bundle.main.resourceURL?.appendingPathComponent(bundleName),
           let appBundle = Bundle(url: resourceURL) {
            return appBundle
        }

        return .main
    }

    static func ui(_ key: String) -> String {
        text(key)
    }

    static var openPrompt: String {
        text("status.openPrompt")
    }

    static var noSupportedRawFiles: String {
        text("status.noSupportedRawFiles")
    }

    static func rawFilesLoaded(_ count: Int) -> String {
        format("status.rawFilesLoaded", count)
    }

    static func rawFilesVisible(_ count: Int) -> String {
        format("status.rawFilesVisible", count)
    }

    static func favoriteRawFilesVisible(_ count: Int) -> String {
        format("status.favoriteRawFilesVisible", count)
    }

    static func xmpWriteFailed(assetName: String) -> String {
        format("status.xmpWriteFailed", assetName)
    }

    static func focalLength(_ focalLength: Double, fullFrameEquivalent: Double?) -> String {
        guard let fullFrameEquivalent else {
            return format("exif.focalLength", formattedMillimeters(focalLength))
        }

        return format(
            "exif.focalLengthWithFullFrameEquivalent",
            formattedMillimeters(focalLength),
            formattedMillimeters(fullFrameEquivalent)
        )
    }

    static func exportFavoritesInProgress(_ count: Int) -> String {
        format("status.exportFavoritesInProgress", count)
    }

    static var exportFavoritesFailed: String {
        text("status.exportFavoritesFailed")
    }

    static func exportFavoritesCompleted(
        _ exportedCount: Int,
        failedCount: Int,
        mode: FavoriteExportMode
    ) -> String {
        let key = failedCount == 0
            ? (mode == .move ? "status.moveFavoritesCompleted" : "status.copyFavoritesCompleted")
            : (mode == .move ? "status.moveFavoritesCompletedWithFailures" : "status.copyFavoritesCompletedWithFailures")

        if failedCount == 0 {
            return format(key, exportedCount)
        }

        return format(key, exportedCount, failedCount)
    }

    private static func text(_ key: String) -> String {
        NSLocalizedString(key, bundle: bundle, comment: "")
    }

    private static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(
            format: text(key),
            locale: Locale.current,
            arguments: arguments
        )
    }

    private static func formattedMillimeters(_ value: Double) -> String {
        if value >= 10 || value.rounded() == value {
            return String(format: "%.0f", value)
        }

        return String(format: "%.1f", value)
    }
}
