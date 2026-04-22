import SwiftUI

struct EmptyStateView: View {
    @EnvironmentObject private var viewer: ViewerModel

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.white.opacity(0.65))

            Text(L10n.ui("Open RAW files or a folder"))
                .font(.title2.weight(.medium))
                .foregroundStyle(.white.opacity(0.9))

            Button {
                viewer.open()
            } label: {
                Label(L10n.ui("Open"), systemImage: "folder.badge.plus")
            }
        }
    }
}
