import SwiftUI

struct HelpTabView: View {
    let palette: AppPalette

    var body: some View {
        NavigationStack {
            ZStack {
                appBackgroundGradient().ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 22) {
                        photoGuideSection
                        disclaimerSection
                        privacyNotice
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle(L10n.string(.helpNavigationTitle))
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var photoGuideSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            PageSectionHeader(
                eyebrow: L10n.string(.helpPhotoEyebrow),
                title: L10n.string(.helpPhotoTitle),
                detail: L10n.string(.helpPhotoDetail)
            )

            HelpBulletCard(
                icon: "sun.max.fill",
                title: L10n.string(.helpBrightTitle),
                message: L10n.string(.helpBrightMessage),
                accent: palette.warning
            )

            HelpBulletCard(
                icon: "person.crop.square",
                title: L10n.string(.helpSingleFaceTitle),
                message: L10n.string(.helpSingleFaceMessage),
                accent: palette.deepBlue
            )

            HelpBulletCard(
                icon: "sparkles",
                title: L10n.string(.helpAddMoreTitle),
                message: L10n.string(.helpAddMoreMessage),
                accent: palette.green
            )
        }
    }

    private var disclaimerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            PageSectionHeader(
                eyebrow: L10n.string(.helpNoticeEyebrow),
                title: L10n.string(.helpNoticeTitle),
                detail: L10n.string(.helpNoticeDetail)
            )

            InfoBanner(
                title: L10n.string(.helpDisclaimerTitle),
                message: L10n.string(.helpDisclaimerMessage),
                accent: .red
            )
        }
    }

    private var privacyNotice: some View {
        InfoBanner(
            title: L10n.string(.privacyTitle),
            message: L10n.string(.privacyMessage),
            accent: palette.green
        )
    }
}
