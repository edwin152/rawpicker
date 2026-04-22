import SwiftUI

struct DropOverlay: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 10)
            .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 3, dash: [10, 7]))
            .background(
                Color.accentColor.opacity(0.12),
                in: RoundedRectangle(cornerRadius: 10)
            )
            .overlay {
                VStack(spacing: 10) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 34, weight: .medium))
                    Text(L10n.ui("Drop RAW files or folders"))
                        .font(.headline)
                }
                .foregroundStyle(.white)
                .padding(18)
                .background(.black.opacity(0.56), in: RoundedRectangle(cornerRadius: 8))
            }
            .padding(20)
    }
}
