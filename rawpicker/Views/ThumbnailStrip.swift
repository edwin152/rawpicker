import SwiftUI

struct ThumbnailStrip: View {
    @EnvironmentObject private var viewer: ViewerModel

    var body: some View {
        ScrollViewReader { scrollProxy in
            ScrollView(.horizontal) {
                LazyHStack(spacing: 8) {
                    ForEach(Array(viewer.visibleAssets.enumerated()), id: \.element.id) { index, asset in
                        ThumbnailCell(
                            asset: asset,
                            image: viewer.thumbnails[asset.id],
                            isSelected: index == viewer.currentIndex,
                            isFavorite: viewer.isFavorite(asset)
                        )
                        .id(asset.id)
                        .onAppear {
                            viewer.loadThumbnail(for: asset)
                        }
                        .onTapGesture {
                            viewer.select(index: index)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
            .onChange(of: viewer.currentAsset?.id) { _, id in
                scrollToCurrent(id, with: scrollProxy)
            }
            .onChange(of: viewer.showFavoritesOnly) { _, _ in
                scrollToCurrent(viewer.currentAsset?.id, with: scrollProxy)
            }
            .onChange(of: viewer.visibleAssets.map(\.id)) { _, _ in
                scrollToCurrent(viewer.currentAsset?.id, with: scrollProxy)
            }
            .onAppear {
                scrollToCurrent(viewer.currentAsset?.id, with: scrollProxy)
            }
        }
    }

    private func scrollToCurrent(_ id: RawAsset.ID?, with scrollProxy: ScrollViewProxy) {
        guard let id else { return }
        withAnimation(.easeOut(duration: 0.18)) {
            scrollProxy.scrollTo(id, anchor: .center)
        }
    }
}

private struct ThumbnailCell: View {
    let asset: RawAsset
    let image: DecodedImage?
    let isSelected: Bool
    let isFavorite: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white.opacity(0.06))

            if let image {
                Image(decorative: image.cgImage, scale: 1)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 92, height: 76)
                    .clipped()
            } else {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .frame(width: 92, height: 76)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isSelected ? Color.accentColor : .white.opacity(0.12), lineWidth: isSelected ? 3 : 1)
        )
        .overlay(alignment: .bottom) {
            HStack(spacing: 4) {
                Image(systemName: isFavorite ? "star.fill" : "star")
                    .foregroundStyle(isFavorite ? .yellow : .white.opacity(0.78))
                Text(asset.url.pathExtension.uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
            }
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(.black.opacity(0.58), in: RoundedRectangle(cornerRadius: 4))
            .padding(4)
        }
    }
}
