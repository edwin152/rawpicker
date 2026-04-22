import SwiftUI

struct ExifPanel: View {
    let info: ExifInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            ExifRow(label: "Camera", value: info.cameraModel)
            ExifRow(label: "Lens", value: info.lensModel)
            ExifRow(label: "ISO", value: info.iso)
            ExifRow(label: "Shutter", value: info.shutter)
            ExifRow(label: "Aperture", value: info.aperture)
            ExifRow(label: "Focal", value: info.focalLength)
        }
        .padding(14)
        .frame(width: 230, alignment: .leading)
        .background(.black.opacity(0.58), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        )
        .padding(.vertical, 20)
    }
}

private struct ExifRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(L10n.ui(label))
                .textCase(.uppercase)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white.opacity(0.42))
            Text(value)
                .font(.callout)
                .lineLimit(2)
                .foregroundStyle(.white.opacity(0.9))
        }
    }
}
