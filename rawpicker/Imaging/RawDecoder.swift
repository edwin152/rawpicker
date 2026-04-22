import AppKit
import CoreImage
import ImageIO
import UniformTypeIdentifiers

final class RawDecoder: @unchecked Sendable {
    private let context = CIContext(options: [
        .cacheIntermediates: true,
        .workingColorSpace: CGColorSpace(name: CGColorSpace.displayP3) as Any,
        .outputColorSpace: CGColorSpace(name: CGColorSpace.displayP3) as Any
    ])

    func clearCaches() {
        context.clearCaches()
    }

    func decodeThumbnail(_ asset: RawAsset) throws -> DecodedImage {
        try decodeEmbedded(asset, maxPixelSize: 256)
    }

    func decodePreview(_ asset: RawAsset) throws -> DecodedImage {
        if let image = try? decodeEmbedded(asset, maxPixelSize: 2200) {
            return image
        }
        return try decodeRAW(asset, maxPixelSize: 2200)
    }

    func decodeFull(_ asset: RawAsset) throws -> DecodedImage {
        try decodeRAW(asset, maxPixelSize: nil)
    }

    func readExif(_ asset: RawAsset) -> ExifInfo {
        guard let source = CGImageSourceCreateWithURL(asset.url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        else {
            return ExifInfo()
        }

        let tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any]
        let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any]
        let maker = properties[kCGImagePropertyMakerFujiDictionary] as? [CFString: Any]

        let camera = stringValue(tiff?[kCGImagePropertyTIFFModel])
        let lens = stringValue(exif?[kCGImagePropertyExifLensModel])
            ?? stringValue(maker?["LensModel" as CFString])

        return ExifInfo(
            cameraModel: camera ?? "-",
            lensModel: lens ?? "-",
            iso: isoValue(exif?[kCGImagePropertyExifISOSpeedRatings]),
            shutter: shutterValue(exif?[kCGImagePropertyExifExposureTime]),
            aperture: apertureValue(exif?[kCGImagePropertyExifFNumber]),
            focalLength: focalValue(
                exif?[kCGImagePropertyExifFocalLength],
                equivalentValue: exif?[kCGImagePropertyExifFocalLenIn35mmFilm],
                exif: exif,
                properties: properties
            )
        )
    }

    private func decodeEmbedded(_ asset: RawAsset, maxPixelSize: Int) throws -> DecodedImage {
        guard let source = CGImageSourceCreateWithURL(asset.url as CFURL, nil) else {
            throw DecodeError.cannotOpenSource
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageIfAbsent: true,
            kCGImageSourceCreateThumbnailFromImageAlways: false,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true
        ]

        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw DecodeError.cannotCreateImage
        }
        return DecodedImage(image)
    }

    private func decodeRAW(_ asset: RawAsset, maxPixelSize: Int?) throws -> DecodedImage {
        let options: [CIImageOption: Any] = [
            .applyOrientationProperty: true
        ]

        guard var ciImage = CIImage(contentsOf: asset.url, options: options) else {
            throw DecodeError.cannotCreateImage
        }

        if let maxPixelSize {
            ciImage = scaled(ciImage, maxPixelSize: maxPixelSize)
        }

        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            throw DecodeError.cannotCreateImage
        }

        return DecodedImage(cgImage)
    }

    private func scaled(_ image: CIImage, maxPixelSize: Int) -> CIImage {
        let extent = image.extent
        let maxSide = max(extent.width, extent.height)
        guard maxSide > CGFloat(maxPixelSize) else {
            return image
        }

        let scale = CGFloat(maxPixelSize) / maxSide
        return image
            .transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            .cropped(to: CGRect(
                x: 0,
                y: 0,
                width: extent.width * scale,
                height: extent.height * scale
            ))
    }
}

enum DecodeError: Error {
    case cannotOpenSource
    case cannotCreateImage
}

private func stringValue(_ value: Any?) -> String? {
    if let string = value as? String, !string.isEmpty { return string }
    return nil
}

private func isoValue(_ value: Any?) -> String {
    if let values = value as? [Int], let iso = values.first { return "ISO \(iso)" }
    if let iso = value as? Int { return "ISO \(iso)" }
    return "-"
}

private func shutterValue(_ value: Any?) -> String {
    guard let seconds = value as? Double else { return "-" }
    if seconds <= 0 { return "-" }
    if seconds >= 1 { return String(format: "%.1fs", seconds) }
    return "1/\(Int(round(1.0 / seconds)))s"
}

private func apertureValue(_ value: Any?) -> String {
    guard let aperture = value as? Double else { return "-" }
    return String(format: "f/%.1f", aperture)
}

private func focalValue(
    _ value: Any?,
    equivalentValue: Any?,
    exif: [CFString: Any]?,
    properties: [CFString: Any]
) -> String {
    guard let focal = numberValue(value), focal > 0 else { return "-" }
    let equivalent = fullFrameEquivalentFocalLength(
        focalLength: focal,
        equivalentValue: equivalentValue,
        exif: exif,
        properties: properties
    )
    return L10n.focalLength(focal, fullFrameEquivalent: equivalent)
}

private func fullFrameEquivalentFocalLength(
    focalLength: Double,
    equivalentValue: Any?,
    exif: [CFString: Any]?,
    properties: [CFString: Any]
) -> Double? {
    let sensorDiagonal = sensorDiagonalMillimeters(exif: exif, properties: properties)
    let fullFrameDiagonal = hypot(36.0, 24.0)

    if let sensorDiagonal, isFullFrameSensor(sensorDiagonal: sensorDiagonal, fullFrameDiagonal: fullFrameDiagonal) {
        return nil
    }

    if let equivalent = numberValue(equivalentValue),
       equivalent > 0,
       !isFullFrameEquivalent(focalLength: focalLength, equivalent: equivalent) {
        return equivalent
    }

    guard let sensorDiagonal, sensorDiagonal > 0 else { return nil }
    let cropFactor = fullFrameDiagonal / sensorDiagonal
    guard !isFullFrameCropFactor(cropFactor) else { return nil }
    return focalLength * cropFactor
}

private func isFullFrameEquivalent(focalLength: Double, equivalent: Double) -> Bool {
    abs(focalLength - equivalent) < max(1.0, focalLength * 0.05)
}

private func isFullFrameSensor(sensorDiagonal: Double, fullFrameDiagonal: Double) -> Bool {
    isFullFrameCropFactor(fullFrameDiagonal / sensorDiagonal)
}

private func isFullFrameCropFactor(_ cropFactor: Double) -> Bool {
    cropFactor >= 0.95 && cropFactor <= 1.05
}

private func sensorDiagonalMillimeters(exif: [CFString: Any]?, properties: [CFString: Any]) -> Double? {
    guard let pixelWidth = numberValue(exif?[kCGImagePropertyExifPixelXDimension])
            ?? numberValue(properties[kCGImagePropertyPixelWidth]),
          let pixelHeight = numberValue(exif?[kCGImagePropertyExifPixelYDimension])
            ?? numberValue(properties[kCGImagePropertyPixelHeight]),
          let xResolution = numberValue(exif?[kCGImagePropertyExifFocalPlaneXResolution]),
          let yResolution = numberValue(exif?[kCGImagePropertyExifFocalPlaneYResolution]),
          let unitLength = focalPlaneResolutionUnitMillimeters(exif?[kCGImagePropertyExifFocalPlaneResolutionUnit]),
          pixelWidth > 0,
          pixelHeight > 0,
          xResolution > 0,
          yResolution > 0
    else {
        return nil
    }

    let sensorWidth = pixelWidth / xResolution * unitLength
    let sensorHeight = pixelHeight / yResolution * unitLength
    guard sensorWidth > 0, sensorHeight > 0 else { return nil }
    return hypot(sensorWidth, sensorHeight)
}

private func focalPlaneResolutionUnitMillimeters(_ value: Any?) -> Double? {
    switch Int(numberValue(value) ?? 2) {
    case 2:
        return 25.4
    case 3:
        return 10
    case 4:
        return 1
    case 5:
        return 0.001
    default:
        return nil
    }
}

private func numberValue(_ value: Any?) -> Double? {
    switch value {
    case let value as Double:
        return value
    case let value as Float:
        return Double(value)
    case let value as CGFloat:
        return Double(value)
    case let value as Int:
        return Double(value)
    case let value as Int32:
        return Double(value)
    case let value as Int64:
        return Double(value)
    case let value as NSNumber:
        return value.doubleValue
    case let value as String:
        return Double(value)
    default:
        return nil
    }
}
