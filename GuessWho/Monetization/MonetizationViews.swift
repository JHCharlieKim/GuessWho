import SwiftUI

#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

struct ResultGateIntroSheet: View {
    let onSkip: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Capsule()
                .fill(Color.secondary.opacity(0.25))
                .frame(width: 42, height: 5)
                .frame(maxWidth: .infinity)

            Text(L10n.string(.adResultGateTitle))
                .font(.title3.weight(.bold))

            Text(L10n.string(.adResultGateMessage))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            InfoBanner(
                title: L10n.string(.adResultGateRewardTitle),
                message: L10n.string(.adResultGateRewardMessage),
                accent: .orange
            )

            VStack(spacing: 10) {
                Button(action: onConfirm) {
                    Text(L10n.string(.adResultGateConfirm))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle(colors: [.orange, .red]))

                Button(action: onSkip) {
                    Text(L10n.string(.adResultGateSkip))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SubtleTextButtonStyle())
            }
        }
        .padding(24)
        .presentationDetents([.height(320)])
        .presentationDragIndicator(.hidden)
    }
}

struct InlineBannerAdSlot: View {
    let placement: BannerAdPlacement

    var body: some View {
        GeometryReader { proxy in
            #if canImport(GoogleMobileAds)
            AdMobBannerSlot(
                placement: placement,
                availableWidth: max(proxy.size.width, 0)
            )
            .frame(width: proxy.size.width, height: 60)
            #else
            InlineAdPlaceholderCard()
                .frame(width: proxy.size.width, height: 100, alignment: .leading)
            #endif
        }
        .frame(height: 60)
    }
}

private struct InlineAdPlaceholderCard: View {
    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.string(.adBannerSponsored))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)

                Text(L10n.string(.adBannerPlaceholderTitle))
                    .font(.headline)

                Text(L10n.string(.adBannerPlaceholderMessage))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "megaphone.fill")
                .font(.title2)
                .foregroundStyle(.orange)
        }
        .padding(18)
        .background(.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.orange.opacity(0.16), lineWidth: 1)
        }
    }
}

#if canImport(GoogleMobileAds)
private struct AdMobBannerSlot: UIViewRepresentable {
    let placement: BannerAdPlacement
    let availableWidth: CGFloat

    func makeUIView(context: Context) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = .clear

        let bannerView = BannerView(adSize: AdSizeBanner)
        bannerView.adUnitID = AdMobConfiguration.bannerUnitID(for: placement)
        bannerView.rootViewController = UIApplication.shared.topMostViewController()
        bannerView.delegate = context.coordinator
        bannerView.translatesAutoresizingMaskIntoConstraints = false
        bannerView.clipsToBounds = true
        containerView.addSubview(bannerView)

        NSLayoutConstraint.activate([
            bannerView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            bannerView.topAnchor.constraint(equalTo: containerView.topAnchor),
            bannerView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])

        context.coordinator.bannerView = bannerView
        MonetizationLogger.log("banner makeUIView placement=\(placement.logName) unitID=\(bannerView.adUnitID ?? "nil")")
        return containerView
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        guard let bannerView = context.coordinator.bannerView else { return }

        bannerView.rootViewController = UIApplication.shared.topMostViewController()
        let width = resolvedWidth(for: bannerView)
        guard width > 0 else {
            MonetizationLogger.log("banner width unresolved for placement=\(placement.logName)")
            return
        }

        let adSize = AdSizeBanner
        if isAdSizeEqualToSize(size1: bannerView.adSize, size2: adSize), context.coordinator.hasLoadedAd {
            return
        }

        MonetizationLogger.log("banner loading placement=\(placement.logName) width=\(width) unitID=\(bannerView.adUnitID ?? "nil")")
        bannerView.adSize = adSize
        context.coordinator.hasLoadedAd = true
        bannerView.load(Request())
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(placement: placement)
    }

    private func resolvedWidth(for bannerView: BannerView) -> CGFloat {
        if availableWidth > 0 {
            return availableWidth
        }

        if bannerView.bounds.width > 0 {
            return bannerView.bounds.width
        }

        if let windowWidth = bannerView.window?.windowScene?.screen.bounds.width {
            return max(windowWidth - 40, 0)
        }

        return 0
    }

    final class Coordinator: NSObject, BannerViewDelegate {
        private let placement: BannerAdPlacement
        weak var bannerView: BannerView?
        var hasLoadedAd = false

        init(placement: BannerAdPlacement) {
            self.placement = placement
        }

        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            MonetizationLogger.log(
                "banner loaded placement=\(placement.logName) size=\(bannerView.bounds.width)x\(bannerView.bounds.height)"
            )
        }

        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: any Error) {
            hasLoadedAd = false
            MonetizationLogger.log(
                "banner failed placement=\(placement.logName) error=\(error.localizedDescription)"
            )
        }

        func bannerViewDidRecordImpression(_ bannerView: BannerView) {
            MonetizationLogger.log("banner impression placement=\(placement.logName)")
        }

        func bannerViewDidRecordClick(_ bannerView: BannerView) {
            MonetizationLogger.log("banner click placement=\(placement.logName)")
        }
    }
}

private extension BannerAdPlacement {
    var logName: String {
        switch self {
        case .homeInline:
            "homeInline"
        case .trainingInline:
            "trainingInline"
        case .helpInline:
            "helpInline"
        }
    }
}
#endif
