import PhotosUI
import SwiftUI

struct TrainingTabView: View {
    let palette: AppPalette
    let processingTitle: String
    let processingMessage: String?
    let isProcessing: Bool
    let fatherSampleCount: Int
    let motherSampleCount: Int
    let fatherSelectedCount: Int
    let motherSelectedCount: Int
    let fatherReady: Bool
    let motherReady: Bool
    let fatherSamples: [FaceSample]
    let motherSamples: [FaceSample]
    let fatherSubtitle: String
    let motherSubtitle: String
    @Binding var fatherPickerItems: [PhotosPickerItem]
    @Binding var motherPickerItems: [PhotosPickerItem]
    let hasAnySavedData: Bool
    let onRemoveFatherSample: (FaceSample) -> Void
    let onRemoveMotherSample: (FaceSample) -> Void
    let onReset: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                appBackgroundGradient().ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 22) {
                        trainingOverviewSection

                        if isProcessing {
                            TrainingProgressCard(
                                title: processingTitle,
                                message: processingMessage ?? L10n.string(.processingTitlePreparingPhotos)
                            )
                        }

                        InlineBannerAdSlot(placement: .trainingInline)

                        parentTrainingSection
                        postTrainingGuideSection
                        resetSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle(L10n.string(.trainingNavigationTitle))
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var trainingOverviewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            PageSectionHeader(
                eyebrow: L10n.string(.trainingOverviewEyebrow),
                title: L10n.string(.trainingOverviewTitle),
                detail: L10n.string(.trainingOverviewDetail)
            )

            HStack(spacing: 12) {
                TrainingStatusMetric(
                    title: L10n.string(.parentFather),
                    value: "\(fatherSelectedCount)/\(fatherSampleCount)",
                    isReady: fatherReady,
                    accent: palette.deepBlue
                )
                TrainingStatusMetric(
                    title: L10n.string(.parentMother),
                    value: "\(motherSelectedCount)/\(motherSampleCount)",
                    isReady: motherReady,
                    accent: palette.coral
                )
            }
        }
    }

    private var parentTrainingSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            PageSectionHeader(
                eyebrow: L10n.string(.trainingParentEyebrow),
                title: L10n.string(.trainingParentTitle),
                detail: L10n.string(.trainingParentDetail)
            )

            ParentTrainingCard(
                title: L10n.string(.roleFatherPhoto),
                subtitle: fatherSubtitle,
                samples: fatherSamples,
                accent: palette.deepBlue,
                pickerSelection: $fatherPickerItems,
                onRemoveSample: onRemoveFatherSample
            )

            ParentTrainingCard(
                title: L10n.string(.roleMotherPhoto),
                subtitle: motherSubtitle,
                samples: motherSamples,
                accent: palette.coral,
                pickerSelection: $motherPickerItems,
                onRemoveSample: onRemoveMotherSample
            )

            TrainingStatusCard(
                fatherCount: fatherSampleCount,
                motherCount: motherSampleCount,
                fatherSelectedCount: fatherSelectedCount,
                motherSelectedCount: motherSelectedCount,
                fatherReady: fatherReady,
                motherReady: motherReady
            )
        }
    }

    private var postTrainingGuideSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            PageSectionHeader(
                eyebrow: L10n.string(.trainingImproveEyebrow),
                title: L10n.string(.trainingImproveTitle),
                detail: L10n.string(.trainingImproveDetail)
            )

            InfoBanner(
                title: L10n.string(.trainingImproveBannerTitle),
                message: L10n.string(.trainingImproveBannerMessage),
                accent: palette.deepBlue
            )
        }
    }

    private var resetSection: some View {
        VStack(spacing: 10) {
            Button {
                onReset()
            } label: {
                Text(L10n.string(.actionResetAllData))
                    .font(.footnote.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SubtleTextButtonStyle())
            .disabled(!hasAnySavedData)
        }
        .padding(.top, 8)
    }
}
