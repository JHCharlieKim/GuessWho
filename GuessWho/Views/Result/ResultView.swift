import SwiftUI

struct ResultView: View {
    let summary: SimilaritySummary
    let childSample: FaceSample?
    @Environment(\.dismiss) private var dismiss
    @State private var sharePayload: ResultSharePayload?

    private let palette = AppPalette()

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color.white, Color(red: 0.94, green: 0.97, blue: 1.0), Color(red: 0.98, green: 0.95, blue: 0.94)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        resultHero

                        HStack(spacing: 14) {
                            ResultScoreCard(
                                title: L10n.string(.resultFatherSimilarity),
                                score: summary.fatherScore,
                                accent: palette.deepBlue
                            )
                            ResultScoreCard(
                                title: L10n.string(.resultMotherSimilarity),
                                score: summary.motherScore,
                                accent: palette.coral
                            )
                        }

                        if let childSample {
                            resultPhotoCard(childSample: childSample)
                        }

                        InfoBanner(
                            title: L10n.string(.resultEntertainmentTitle),
                            message: L10n.string(.resultEntertainmentMessage),
                            accent: .red
                        )
                    }
                    .padding(20)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        sharePayload = ResultSharePayload.make(
                            summary: summary,
                            childSample: childSample,
                            palette: palette
                        )
                    } label: {
                        Label(L10n.string(.resultShareButton), systemImage: "square.and.arrow.up")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.string(.actionClose)) {
                        dismiss()
                    }
                }
            }
            .sheet(item: $sharePayload) { payload in
                ActivityView(items: payload.items)
            }
        }
    }

    private var resultHero: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.string(.resultTitle))
                .font(.largeTitle.weight(.bold))

            Text(L10n.format(.resultWinnerMessage, summary.winner))
                .font(.title2.weight(.bold))

            Text(L10n.format(.resultWinnerScore, summary.winner, summary.winnerScore))
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [palette.ink, palette.deepBlue],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 32, style: .continuous)
        )
        .foregroundStyle(.white)
    }

    private func resultPhotoCard(childSample: FaceSample) -> some View {
        HStack(spacing: 14) {
            SampleThumbnail(sample: childSample)
                .frame(width: 96, height: 96)

            Text(L10n.string(.resultPhotoDescription))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .background(.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}

struct ResultScoreCard: View {
    let title: String
    let score: Int
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            Text("\(score)")
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundStyle(accent)

            ProgressView(value: Double(score), total: 100)
                .tint(accent)

            Text(scoreDescription)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
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
