import SwiftUI

@MainActor
struct ImageCanvasView: View {
    @EnvironmentObject private var viewer: ViewerModel

    var body: some View {
        GeometryReader { _ in
            ZStack {
                Color.black.opacity(0.2)

                if let image = viewer.currentImage {
                    imageView(image)
                } else if viewer.assets.isEmpty {
                    EmptyStateView()
                }

                if viewer.isLoading, viewer.currentImage != nil {
                    LoadingBadge()
                }
            }
            .clipped()
        }
    }

    @MainActor
    private func imageView(_ decoded: DecodedImage) -> some View {
        ImageViewport(
            decoded: decoded,
            isFitMode: Binding(
                get: { viewer.isFitMode },
                set: { viewer.isFitMode = $0 }
            ),
            zoomScale: Binding(
                get: { viewer.zoomScale },
                set: { viewer.zoomScale = $0 }
            ),
            panOffset: Binding(
                get: { viewer.panOffset },
                set: { viewer.panOffset = $0 }
            ),
            onZoomChanged: {
                viewer.onZoomChanged()
            },
            onViewportChanged: { displayScale in
                viewer.onViewportChanged(displayScale: displayScale)
            }
        )
    }

    private func setIsFitMode(_ isFitMode: Bool) {
        guard viewer.isFitMode != isFitMode else { return }
        DispatchQueue.main.async {
            guard viewer.isFitMode != isFitMode else { return }
            viewer.isFitMode = isFitMode
        }
    }

    private func setZoomScale(_ zoomScale: CGFloat) {
        guard abs(viewer.zoomScale - zoomScale) > 0.0001 else { return }
        DispatchQueue.main.async {
            guard abs(viewer.zoomScale - zoomScale) > 0.0001 else { return }
            viewer.zoomScale = zoomScale
        }
    }

    private func setPanOffset(_ panOffset: CGSize) {
        guard viewer.panOffset != panOffset else { return }
        DispatchQueue.main.async {
            guard viewer.panOffset != panOffset else { return }
            viewer.panOffset = panOffset
        }
    }
}

private struct LoadingBadge: View {
    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                ProgressView()
                    .controlSize(.small)
                    .padding(8)
                    .background(.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 6))
                    .padding(12)
            }
        }
        .allowsHitTesting(false)
    }
}
