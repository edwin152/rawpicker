import SwiftUI
import UniformTypeIdentifiers

@MainActor
struct ContentView: View {
    @EnvironmentObject private var viewer: ViewerModel
    @AppStorage("hasSeenFirstLaunchIntro") private var hasSeenFirstLaunchIntro = false
    @State private var isDropTargeted = false
    @State private var isShowingFirstLaunchIntro = false

    var body: some View {
        ZStack {
            Color(red: 0.045, green: 0.047, blue: 0.052)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                ToolbarView()
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)

                ZStack(alignment: .trailing) {
                    ImageCanvasView()

                    if viewer.showExif, viewer.currentAsset != nil {
                        ExifPanel(info: viewer.exif)
                            .padding(.trailing, 18)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }

                ThumbnailStrip()
                    .frame(height: 112)
                    .background(.black.opacity(0.36))
            }

            KeyboardHandler(
                onPrevious: viewer.goPrevious,
                onNext: viewer.goNext,
                onEndDirection: viewer.endDirectionalNavigation,
                onToggleFavorite: viewer.toggleFavoriteCurrent
            )
            .frame(width: 0, height: 0)

            if isDropTargeted {
                DropOverlay()
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isDropTargeted) { providers in
            loadDroppedFileURLs(from: providers)
            return true
        }
        .onAppear {
            if !hasSeenFirstLaunchIntro {
                isShowingFirstLaunchIntro = true
            }
        }
        .sheet(isPresented: $isShowingFirstLaunchIntro) {
            FirstLaunchIntroView(
                onOpen: {
                    completeFirstLaunchIntro()
                    viewer.open()
                },
                onDismiss: completeFirstLaunchIntro
            )
        }
    }

    private func loadDroppedFileURLs(from providers: [NSItemProvider]) {
        Task {
            let urls = await DroppedFileURLLoader.urls(from: providers)
            viewer.load(urls: urls)
        }
    }

    private func completeFirstLaunchIntro() {
        hasSeenFirstLaunchIntro = true
        isShowingFirstLaunchIntro = false
    }
}
