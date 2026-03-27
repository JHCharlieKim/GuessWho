import PhotosUI
import SwiftUI

struct HomeTabView: View {
    let palette: AppPalette
    let lastErrorMessage: String?
    let isTrainingReady: Bool
    let childSample: FaceSample?
    let childQualityWarning: String?
    let isProcessing: Bool
    @Binding var childPickerItem: PhotosPickerItem?
    let floatingTitle: String
    let floatingDetail: String
    let floatingButtonTitle: String
    let onOpenTraining: () -> Void
    let onAnalyze: () -> Void

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ZStack {
                    appBackgroundGradient().ignoresSafeArea()

                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 22) {
                            heroSection

                            if !isTrainingReady {
                                onboardingHomeSection
                            }

                            InlineBannerAdSlot(placement: .homeInline)

                            if let lastErrorMessage {
                                InfoBanner(
                                    title: L10n.string(.noticePhotoProcessingTitle),
                                    message: lastErrorMessage,
                                    accent: palette.warning
                                )
                            }

                            if isTrainingReady {
                                childSection
                                    .id(ContentView.SectionID.child)
                                compactTrainingShortcutSection
                                    .id(ContentView.SectionID.training)
                            } else {
                                compactTrainingShortcutSection
                                    .id(ContentView.SectionID.training)
                            }

                            privacyNotice
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 120)
                    }
                }
                .navigationTitle(L10n.string(.homeNavigationTitle))
                .navigationBarTitleDisplayMode(.inline)
                .safeAreaInset(edge: .bottom) {
                    floatingAnalyzeBar(proxy: proxy)
                }
            }
        }
    }

    private var heroSection: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [palette.ink, palette.deepBlue, palette.coral],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Circle()
                .fill(.white.opacity(0.12))
                .frame(width: 220, height: 220)
                .blur(radius: 8)
                .offset(x: 180, y: -20)

            Circle()
                .fill(palette.sky.opacity(0.18))
                .frame(width: 140, height: 140)
                .blur(radius: 2)
                .offset(x: -30, y: 150)

            VStack(alignment: .leading, spacing: 18) {
                Label(L10n.string(.homeHeroBadge), systemImage: "sparkles")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.92))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.white.opacity(0.14), in: Capsule())

                Text(isTrainingReady ? L10n.string(.homeHeroReadyTitle) : L10n.string(.homeHeroNotReadyTitle))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(isTrainingReady ? L10n.string(.homeHeroReadyMessage) : L10n.string(.homeHeroNotReadyMessage))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.84))
            }
            .padding(26)
        }
        .shadow(color: palette.ink.opacity(0.14), radius: 30, x: 0, y: 18)
    }

    private var onboardingHomeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            PageSectionHeader(
                eyebrow: L10n.string(.homeOnboardingEyebrow),
                title: L10n.string(.homeOnboardingTitle),
                detail: L10n.string(.homeOnboardingDetail)
            )

            ActionSummaryCard(
                title: L10n.string(.homeActionTitle),
                subtitle: L10n.string(.homeActionSubtitle),
                message: L10n.string(.homeActionMessage),
                accent: palette.deepBlue,
                primaryTitle: L10n.string(.homeActionPrimary),
                primaryIcon: "arrow.right.circle.fill",
                primaryAction: onOpenTraining,
                secondaryTitle: childSample == nil ? nil : L10n.string(.homeActionSecondaryReady),
                secondaryIcon: "checkmark.circle.fill",
                secondaryAction: nil
            )
        }
    }

    private var compactTrainingShortcutSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            PageSectionHeader(
                eyebrow: L10n.string(.homeTrainingEyebrow),
                title: isTrainingReady ? L10n.string(.homeTrainingReadyTitle) : L10n.string(.homeTrainingNeedTitle),
                detail: isTrainingReady ? L10n.string(.homeTrainingReadyDetail) : L10n.string(.homeTrainingNeedDetail)
            )

            InfoBanner(
                title: isTrainingReady ? L10n.string(.homeTrainingBannerReadyTitle) : L10n.string(.homeTrainingBannerNeedTitle),
                message: isTrainingReady ? L10n.string(.homeTrainingBannerReadyMessage) : L10n.string(.homeTrainingBannerNeedMessage),
                accent: palette.deepBlue
            )
        }
    }

    private var childSection: some View {
        let childUploadTitle = childSample == nil ? L10n.string(.homeChildUploadSelect) : L10n.string(.homeChildUploadChange)

        return VStack(alignment: .leading, spacing: 16) {
            PageSectionHeader(
                eyebrow: L10n.string(.homeChildEyebrow),
                title: L10n.string(.homeChildTitle),
                detail: L10n.string(.homeChildDetail)
            )

            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center, spacing: 16) {
                    SampleAvatar(sample: childSample)
                        .frame(width: 92, height: 92)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(childSample?.name ?? L10n.string(.homeChildPlaceholderTitle))
                            .font(.headline)
                        Text(childSample == nil ? L10n.string(.homeChildPlaceholderMessage) : L10n.string(.homeChildSelectedMessage))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                PhotosPicker(
                    selection: $childPickerItem,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    Label(childUploadTitle, systemImage: "photo.badge.plus")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle(colors: [palette.coral, palette.deepBlue]))
                .disabled(isProcessing)

                if let childQualityWarning {
                    InfoBanner(
                        title: L10n.string(.homeChildQualityTitle),
                        message: childQualityWarning,
                        accent: palette.warning
                    )
                }
            }
            .padding(22)
            .background(SurfaceCardBackground(palette: palette))
        }
    }

    private var privacyNotice: some View {
        InfoBanner(
            title: L10n.string(.privacyTitle),
            message: L10n.string(.privacyMessage),
            accent: palette.green
        )
    }

    private func floatingAnalyzeBar(proxy: ScrollViewProxy) -> some View {
        VStack(spacing: 0) {
            Divider()
                .overlay(.white.opacity(0.18))

            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(floatingTitle)
                        .font(.headline)
                        .foregroundStyle(.white)

                    Text(floatingDetail)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.76))
                }

                Spacer(minLength: 8)

                Button {
                    if isTrainingReady {
                        if childSample == nil {
                            scrollTo(.child, proxy: proxy)
                        } else {
                            onAnalyze()
                        }
                    } else {
                        onOpenTraining()
                    }
                } label: {
                    Text(floatingButtonTitle)
                        .frame(minWidth: 108)
                }
                .buttonStyle(FloatingActionButtonStyle(isEnabled: !isProcessing))
                .disabled(isProcessing)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 18)
            .background(
                LinearGradient(
                    colors: [palette.ink.opacity(0.95), palette.deepBlue.opacity(0.94)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
        }
    }

    private func scrollTo(_ section: ContentView.SectionID, proxy: ScrollViewProxy) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.86)) {
            proxy.scrollTo(section, anchor: .top)
        }
    }
}
