import SwiftUI
import UIKit

enum ShareConfiguration {
    static let appName = "GuessWho"
    // Fill in the live App Store URL once the app is published.
    static let appDownloadURL: URL? = nil
}

struct ResultSharePayload: Identifiable {
    let id = UUID()
    let items: [Any]

    @MainActor
    static func make(
        summary: SimilaritySummary,
        childSample: FaceSample?,
        palette: AppPalette
    ) -> ResultSharePayload? {
        let shareImage = ResultShareImageRenderer.render(
            summary: summary,
            childSample: childSample,
            palette: palette
        )

        var items: [Any] = [shareImage]
        let message = shareMessage(summary: summary)
        items.append(message)

        if let url = ShareConfiguration.appDownloadURL {
            items.append(url)
        }

        return ResultSharePayload(items: items)
    }

    private static func shareMessage(summary: SimilaritySummary) -> String {
        let winnerLine = L10n.format(.resultShareMessageWinner, summary.winner, summary.winnerScore)

        if let url = ShareConfiguration.appDownloadURL {
            return [
                L10n.string(.resultShareMessageIntro),
                winnerLine,
                L10n.string(.resultShareMessageDownload),
                url.absoluteString
            ]
            .joined(separator: "\n")
        }

        return [
            L10n.string(.resultShareMessageIntro),
            winnerLine
        ]
        .joined(separator: "\n")
    }
}

enum ResultShareImageRenderer {
    @MainActor
    static func render(
        summary: SimilaritySummary,
        childSample: FaceSample?,
        palette: AppPalette
    ) -> UIImage {
        let content = ResultShareCard(
            summary: summary,
            childSample: childSample,
            palette: palette
        )
        .frame(width: 1080, height: 1350)

        let renderer = ImageRenderer(content: content)
        renderer.scale = 1
        renderer.proposedSize = .init(width: 1080, height: 1350)

        return renderer.uiImage ?? UIImage()
    }
}

private struct ResultShareCard: View {
    let summary: SimilaritySummary
    let childSample: FaceSample?
    let palette: AppPalette

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.98, green: 0.97, blue: 0.94),
                    Color(red: 0.92, green: 0.96, blue: 1.0),
                    Color(red: 0.95, green: 0.93, blue: 0.99)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(alignment: .leading, spacing: 34) {
                shareHeader
                childPhotoBlock
                scoreGrid
                footerCard
            }
            .padding(56)
        }
    }

    private var shareHeader: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(ShareConfiguration.appName.uppercased())
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(palette.deepBlue)
                .tracking(2)

            Text(L10n.string(.resultShareImageTitle))
                .font(.system(size: 74, weight: .bold, design: .rounded))
                .foregroundStyle(palette.ink)

            Text(L10n.format(.resultShareImageWinner, summary.winner, summary.winnerScore))
                .font(.system(size: 42, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var childPhotoBlock: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 44, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [palette.deepBlue.opacity(0.18), .white.opacity(0.92)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            SampleAvatar(sample: childSample)
                .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
                .padding(28)

            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.string(.resultShareChildLabel))
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.92))

                Text(L10n.string(.resultShareChildCaption))
                    .font(.system(size: 24, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.82))
            }
            .padding(.horizontal, 38)
            .padding(.vertical, 28)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [Color.black.opacity(0.02), Color.black.opacity(0.45)],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                in: UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 44, bottomTrailingRadius: 44, topTrailingRadius: 0)
            )
        }
        .frame(height: 620)
        .shadow(color: palette.ink.opacity(0.12), radius: 30, x: 0, y: 16)
    }

    private var scoreGrid: some View {
        HStack(spacing: 24) {
            ShareScoreCard(
                title: L10n.string(.resultFatherSimilarity),
                score: summary.fatherScore,
                accent: palette.deepBlue
            )
            ShareScoreCard(
                title: L10n.string(.resultMotherSimilarity),
                score: summary.motherScore,
                accent: palette.coral
            )
        }
    }

    private var footerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n.string(.resultShareFooterTitle))
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(palette.ink)

            Text(L10n.string(.resultShareFooterMessage))
                .font(.system(size: 26, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)

            if let url = ShareConfiguration.appDownloadURL {
                Text(url.absoluteString)
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundStyle(palette.deepBlue)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 34, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .stroke(.white.opacity(0.82), lineWidth: 1)
        }
    }
}

private struct ShareScoreCard: View {
    let title: String
    let score: Int
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(title)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)

            Text("\(score)%")
                .font(.system(size: 88, weight: .bold, design: .rounded))
                .foregroundStyle(accent)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.black.opacity(0.08))

                    Capsule()
                        .fill(accent.gradient)
                        .frame(width: proxy.size.width * (Double(score) / 100))
                }
            }
            .frame(height: 18)

            Text(scoreDescription)
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .padding(30)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.94), in: RoundedRectangle(cornerRadius: 34, style: .continuous))
        .shadow(color: accent.opacity(0.14), radius: 22, x: 0, y: 14)
    }

    private var scoreDescription: String {
        switch score {
        case 80...:
            return L10n.string(.resultScoreHigh)
        case 60...:
            return L10n.string(.resultScoreMedium)
        default:
            return L10n.string(.resultScoreLow)
        }
    }
}

struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
