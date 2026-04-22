import SwiftUI

struct ToolbarView: View {
    @EnvironmentObject private var viewer: ViewerModel

    var body: some View {
        HStack(spacing: 12) {
            Button {
                viewer.open()
            } label: {
                Label(L10n.ui("Open"), systemImage: "folder.badge.plus")
            }

            Divider()
                .frame(height: 22)

            Button {
                viewer.goPrevious()
            } label: {
                Image(systemName: "chevron.left")
            }
            .disabled(!viewer.canGoPrevious)

            Button {
                viewer.goNext()
            } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(!viewer.canGoNext)

            Text(viewer.statusText)
                .foregroundStyle(.white.opacity(0.82))
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            if !viewer.visibleAssets.isEmpty {
                Text("\(viewer.currentIndex + 1) / \(viewer.visibleAssets.count)")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.7))
            }

            Button {
                viewer.toggleFavoriteCurrent()
            } label: {
                Image(systemName: viewer.currentAsset.map(viewer.isFavorite) == true ? "star.fill" : "star")
                    .foregroundStyle(viewer.currentAsset.map(viewer.isFavorite) == true ? .yellow : .white.opacity(0.76))
            }
            .disabled(!viewer.hasCurrentAsset)
            .help(L10n.ui("Set 5 stars / reset rating"))

            Divider()
                .frame(height: 22)

            Button {
                viewer.toggleFavoritesFilter()
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: viewer.showFavoritesOnly ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                    Image(systemName: "star.fill")
                        .font(.system(size: 7, weight: .bold))
                        .offset(x: 3, y: -3)
                }
                .foregroundStyle(viewer.showFavoritesOnly ? .yellow : .white.opacity(0.76))
            }
            .disabled(!viewer.canToggleFavoritesFilter)
            .help(L10n.ui("Show 5-star photos only"))

            Button {
                viewer.toggleFit()
            } label: {
                Image(systemName: viewer.isFitMode ? "arrow.up.left.and.arrow.down.right" : "viewfinder")
            }
            .disabled(!viewer.hasCurrentAsset)
            .help(L10n.ui("Fit / 100%"))

            Button {
                viewer.showExif.toggle()
            } label: {
                Image(systemName: viewer.showExif ? "info.circle.fill" : "info.circle")
            }
            .disabled(!viewer.hasCurrentAsset)
            .help(L10n.ui("Toggle EXIF"))
        }
        .buttonStyle(.borderless)
    }
}
