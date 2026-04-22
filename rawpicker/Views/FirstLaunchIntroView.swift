import SwiftUI

struct FirstLaunchIntroView: View {
    let onOpen: () -> Void
    let onDismiss: () -> Void

    private let features: [IntroFeature] = [
        IntroFeature(
            icon: "folder.badge.plus",
            titleKey: "intro.feature.open.title",
            bodyKey: "intro.feature.open.body"
        ),
        IntroFeature(
            icon: "star.fill",
            titleKey: "intro.feature.rate.title",
            bodyKey: "intro.feature.rate.body"
        ),
        IntroFeature(
            icon: "line.3.horizontal.decrease.circle",
            titleKey: "intro.feature.filter.title",
            bodyKey: "intro.feature.filter.body"
        ),
        IntroFeature(
            icon: "square.and.arrow.up",
            titleKey: "intro.feature.export.title",
            bodyKey: "intro.feature.export.body"
        ),
        IntroFeature(
            icon: "info.circle",
            titleKey: "intro.feature.exif.title",
            bodyKey: "intro.feature.exif.body"
        )
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            header

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 14),
                    GridItem(.flexible(), spacing: 14)
                ],
                alignment: .leading,
                spacing: 14
            ) {
                ForEach(features) { feature in
                    IntroFeatureRow(feature: feature)
                }
            }

            HStack {
                Button(L10n.ui("intro.skip")) {
                    onDismiss()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.62))

                Spacer()

                Button {
                    onOpen()
                } label: {
                    Label(L10n.ui("intro.openButton"), systemImage: "folder.badge.plus")
                }
                .buttonStyle(.borderedProminent)

                Button(L10n.ui("intro.startButton")) {
                    onDismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(28)
        .frame(width: 680)
        .background(Color(red: 0.075, green: 0.078, blue: 0.088))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 34, weight: .light))
                    .foregroundStyle(.white.opacity(0.82))

                Text(L10n.ui("intro.title"))
                    .font(.largeTitle.weight(.semibold))
                    .foregroundStyle(.white)
            }

            Text(L10n.ui("intro.subtitle"))
                .font(.body)
                .foregroundStyle(.white.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)

            Text(AppVersion.display)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.5))
        }
    }
}

private struct IntroFeatureRow: View {
    let feature: IntroFeature

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: feature.icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(feature.icon == "star.fill" ? .yellow : .white.opacity(0.82))
                .frame(width: 28, height: 28)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 5) {
                Text(L10n.ui(feature.titleKey))
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.94))

                Text(L10n.ui(feature.bodyKey))
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.64))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct IntroFeature: Identifiable {
    let icon: String
    let titleKey: String
    let bodyKey: String

    var id: String { titleKey }
}
