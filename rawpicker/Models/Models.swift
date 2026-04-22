import AppKit
import Foundation

nonisolated enum ImageKind: Hashable, Sendable {
    case thumbnail
    case preview
    case full
}

struct RawAsset: Identifiable, Hashable, Sendable {
    let id: String
    let url: URL

    var displayName: String {
        url.deletingPathExtension().lastPathComponent
    }
}

struct ExifInfo: Equatable, Sendable {
    var cameraModel: String = "-"
    var lensModel: String = "-"
    var iso: String = "-"
    var shutter: String = "-"
    var aperture: String = "-"
    var focalLength: String = "-"
}

struct DecodedImage: @unchecked Sendable {
    let cgImage: CGImage
    let pixelSize: CGSize

    init(_ cgImage: CGImage) {
        self.cgImage = cgImage
        pixelSize = CGSize(width: cgImage.width, height: cgImage.height)
    }
}

nonisolated struct CacheKey: Hashable, Sendable {
    let assetID: String
    let kind: ImageKind
}
