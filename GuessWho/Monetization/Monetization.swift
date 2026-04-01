import Combine
import Foundation
import SwiftUI
import UIKit

#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif
#if canImport(UserMessagingPlatform)
import UserMessagingPlatform
#endif

enum BannerAdPlacement: CaseIterable {
    case homeInline
    case trainingInline
    case helpInline
}

enum ResultGateAdOutcome: Equatable {
    case completed
    case skipped
    case unavailable
}

protocol RandomValueProviding {
    func nextUnitIntervalValue() -> Double
}

struct SystemRandomValueProvider: RandomValueProviding {
    func nextUnitIntervalValue() -> Double {
        Double.random(in: 0..<1)
    }
}

struct ResultGatePolicy {
    let probability: Double
    private let randomValueProvider: RandomValueProviding

    static let `default` = ResultGatePolicy(
        probability: 0.30,
        randomValueProvider: SystemRandomValueProvider()
    )

    init(
        probability: Double,
        randomValueProvider: RandomValueProviding
    ) {
        self.probability = probability
        self.randomValueProvider = randomValueProvider
    }

    func shouldPresentAd() -> Bool {
        randomValueProvider.nextUnitIntervalValue() < probability
    }
}

struct ResultGateSession {
    private(set) var hasPendingAdRequirement = false

    mutating func shouldRequireAd(using policyDecision: @autoclosure () -> Bool) -> Bool {
        if hasPendingAdRequirement {
            return true
        }

        if policyDecision() {
            hasPendingAdRequirement = true
            return true
        }

        return false
    }

    mutating func resolve(with outcome: ResultGateAdOutcome) {
        switch outcome {
        case .completed, .unavailable:
            hasPendingAdRequirement = false
        case .skipped:
            break
        }
    }

    mutating func reset() {
        hasPendingAdRequirement = false
    }
}

enum AdMobConfiguration {
    static let usesTestAds = false
    static let enablesDebugLogging = false

    // Replace these with your real AdMob ad unit IDs when production inventory is ready.
    static let rewardedInterstitialResultUnitID = usesTestAds
        ? "ca-app-pub-3940256099942544/6978759866"
        : "ca-app-pub-7761493379186505/3091701453"

    static func bannerUnitID(for placement: BannerAdPlacement) -> String {
        if usesTestAds {
            return "ca-app-pub-3940256099942544/2435281174"
        }

        return "ca-app-pub-7761493379186505/8016725074"
    }
}

enum MonetizationLogger {
    static func log(_ message: String) {
        guard AdMobConfiguration.enablesDebugLogging else { return }
        print("[Monetization] \(message)")
    }
}

protocol MonetizationServing: AnyObject {
    func start() async
    func preloadAds() async
    func shouldPresentResultGateAd() -> Bool
    func presentResultGateAd() async -> ResultGateAdOutcome
    var isPrivacyOptionsRequired: Bool { get }
    func presentPrivacyOptions() async
}

@MainActor
final class MonetizationCoordinator: ObservableObject {
    @Published private(set) var isPrivacyOptionsRequired = false

    private let service: MonetizationServing

    init(service: MonetizationServing? = nil) {
        self.service = service ?? DefaultMonetizationService(resultGatePolicy: .default)
    }

    func start() async {
        await service.start()
        isPrivacyOptionsRequired = service.isPrivacyOptionsRequired
    }

    func shouldPresentResultGateAd() -> Bool {
        service.shouldPresentResultGateAd()
    }

    func presentResultGateAd() async -> ResultGateAdOutcome {
        await service.presentResultGateAd()
    }

    func presentPrivacyOptions() async {
        await service.presentPrivacyOptions()
        isPrivacyOptionsRequired = service.isPrivacyOptionsRequired
    }
}

#if canImport(GoogleMobileAds) && canImport(UserMessagingPlatform)
@MainActor
final class DefaultMonetizationService: NSObject, MonetizationServing, FullScreenContentDelegate {
    private let resultGatePolicy: ResultGatePolicy
    private var rewardedInterstitialAd: RewardedInterstitialAd?
    private var didEarnReward = false
    private var adContinuation: CheckedContinuation<ResultGateAdOutcome, Never>?
    private var hasStartedSDK = false

    var isPrivacyOptionsRequired: Bool {
        ConsentInformation.shared.privacyOptionsRequirementStatus == .required
    }

    init(resultGatePolicy: ResultGatePolicy) {
        self.resultGatePolicy = resultGatePolicy
    }

    func start() async {
        MonetizationLogger.log("start requested")
        await requestConsentIfNeeded()
        MonetizationLogger.log("consent status updated, canRequestAds=\(ConsentInformation.shared.canRequestAds)")

        guard ConsentInformation.shared.canRequestAds else {
            MonetizationLogger.log("ads cannot be requested after consent flow")
            return
        }

        if !hasStartedSDK {
            MonetizationLogger.log("starting Google Mobile Ads SDK")
            _ = await MobileAds.shared.start()
            hasStartedSDK = true
            MonetizationLogger.log("Google Mobile Ads SDK started")
        }

        await preloadAds()
    }

    func preloadAds() async {
        guard ConsentInformation.shared.canRequestAds else {
            MonetizationLogger.log("preload skipped because canRequestAds=false")
            return
        }

        MonetizationLogger.log("preloading rewarded interstitial")
        await loadRewardedInterstitialIfNeeded()
    }

    func shouldPresentResultGateAd() -> Bool {
        let shouldPresent = ConsentInformation.shared.canRequestAds
            && rewardedInterstitialAd != nil
            && resultGatePolicy.shouldPresentAd()
        MonetizationLogger.log(
            "shouldPresentResultGateAd=\(shouldPresent) canRequestAds=\(ConsentInformation.shared.canRequestAds) hasAd=\(rewardedInterstitialAd != nil)"
        )
        return shouldPresent
    }

    func presentResultGateAd() async -> ResultGateAdOutcome {
        guard ConsentInformation.shared.canRequestAds else {
            MonetizationLogger.log("presentResultGateAd aborted because canRequestAds=false")
            return .unavailable
        }

        MonetizationLogger.log("presentResultGateAd requested")
        await loadRewardedInterstitialIfNeeded()

        guard
            let rewardedInterstitialAd,
            let rootViewController = UIApplication.shared.topMostViewController()
        else {
            MonetizationLogger.log("presentResultGateAd unavailable because ad or rootViewController is missing")
            return .unavailable
        }

        didEarnReward = false
        rewardedInterstitialAd.fullScreenContentDelegate = self

        return await withCheckedContinuation { continuation in
            adContinuation = continuation
            rewardedInterstitialAd.present(from: rootViewController) { [weak self] in
                self?.didEarnReward = true
            }
        }
    }

    private func loadRewardedInterstitialIfNeeded() async {
        guard rewardedInterstitialAd == nil else {
            MonetizationLogger.log("rewarded interstitial already loaded")
            return
        }
        guard ConsentInformation.shared.canRequestAds else {
            MonetizationLogger.log("rewarded interstitial load skipped because canRequestAds=false")
            return
        }

        do {
            MonetizationLogger.log("loading rewarded interstitial with unitID=\(AdMobConfiguration.rewardedInterstitialResultUnitID)")
            rewardedInterstitialAd = try await RewardedInterstitialAd.load(
                with: AdMobConfiguration.rewardedInterstitialResultUnitID,
                request: Request()
            )
            rewardedInterstitialAd?.fullScreenContentDelegate = self
            MonetizationLogger.log("rewarded interstitial loaded successfully")
        } catch {
            rewardedInterstitialAd = nil
            MonetizationLogger.log("rewarded interstitial failed to load: \(error.localizedDescription)")
        }
    }

    func presentPrivacyOptions() async {
        guard isPrivacyOptionsRequired else { return }

        do {
            try await ConsentForm.presentPrivacyOptionsForm(from: nil)
        } catch {
            MonetizationLogger.log("privacy options form failed: \(error.localizedDescription)")
            return
        }

        if ConsentInformation.shared.canRequestAds {
            if !hasStartedSDK {
                MonetizationLogger.log("starting Google Mobile Ads SDK after privacy options")
                _ = await MobileAds.shared.start()
                hasStartedSDK = true
                MonetizationLogger.log("Google Mobile Ads SDK started after privacy options")
            }
            await preloadAds()
        }
    }

    private func requestConsentIfNeeded() async {
        let parameters = RequestParameters()

        do {
            MonetizationLogger.log("requesting consent info update")
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                ConsentInformation.shared.requestConsentInfoUpdate(with: parameters) { error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: ())
                    }
                }
            }

            try await ConsentForm.loadAndPresentIfRequired(from: nil)
            MonetizationLogger.log("consent form flow completed")
        } catch {
            MonetizationLogger.log("consent flow failed: \(error.localizedDescription)")
            return
        }
    }

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        MonetizationLogger.log("rewarded interstitial dismissed, didEarnReward=\(didEarnReward)")
        finishPresentedAd(with: didEarnReward ? .completed : .skipped)
        rewardedInterstitialAd = nil
        Task {
            await loadRewardedInterstitialIfNeeded()
        }
    }

    func ad(
        _ ad: FullScreenPresentingAd,
        didFailToPresentFullScreenContentWithError error: Error
    ) {
        MonetizationLogger.log("rewarded interstitial failed to present: \(error.localizedDescription)")
        finishPresentedAd(with: .unavailable)
        rewardedInterstitialAd = nil
    }

    private func finishPresentedAd(with outcome: ResultGateAdOutcome) {
        adContinuation?.resume(returning: outcome)
        adContinuation = nil
    }
}
#else
@MainActor
final class DefaultMonetizationService: MonetizationServing {
    private let resultGatePolicy: ResultGatePolicy

    var isPrivacyOptionsRequired: Bool { false }

    init(resultGatePolicy: ResultGatePolicy) {
        self.resultGatePolicy = resultGatePolicy
    }

    func start() async {}

    func preloadAds() async {}

    func shouldPresentResultGateAd() -> Bool {
        false
    }

    func presentResultGateAd() async -> ResultGateAdOutcome {
        .unavailable
    }

    func presentPrivacyOptions() async {}
}
#endif

extension UIApplication {
    func topMostViewController(
        base: UIViewController? = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController
    ) -> UIViewController? {
        if let navigationController = base as? UINavigationController {
            return topMostViewController(base: navigationController.visibleViewController)
        }

        if let tabBarController = base as? UITabBarController,
           let selectedViewController = tabBarController.selectedViewController {
            return topMostViewController(base: selectedViewController)
        }

        if let presentedViewController = base?.presentedViewController {
            return topMostViewController(base: presentedViewController)
        }

        return base
    }
}
