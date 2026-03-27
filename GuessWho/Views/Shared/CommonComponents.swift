import PhotosUI
import SwiftUI

struct PageSectionHeader: View {
    let eyebrow: String
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !eyebrow.isEmpty {
                Text(eyebrow.uppercased())
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .tracking(1.2)
            }

            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)

            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

struct ActionSummaryCard: View {
    let title: String
    let subtitle: String
    let message: String
    let accent: Color
    let primaryTitle: String
    let primaryIcon: String
    let primaryAction: () -> Void
    let secondaryTitle: String?
    let secondaryIcon: String?
    let secondaryAction: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.title3.weight(.bold))
                    Text(subtitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(accent)
                }

                Spacer()

                Image(systemName: "point.3.connected.trianglepath.dotted")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(accent)
            }

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(spacing: 10) {
                Button(action: primaryAction) {
                    Label(primaryTitle, systemImage: primaryIcon)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle(colors: [accent, accent.opacity(0.72)]))

                if let secondaryTitle, let secondaryIcon {
                    if let secondaryAction {
                        Button(action: secondaryAction) {
                            Label(secondaryTitle, systemImage: secondaryIcon)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(SecondaryButtonStyle(accent: accent))
                    } else {
                        Label(secondaryTitle, systemImage: secondaryIcon)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(Color.black.opacity(0.04), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                }
            }
        }
        .padding(22)
        .background(.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(accent.opacity(0.14), lineWidth: 1)
        }
        .shadow(color: accent.opacity(0.1), radius: 20, x: 0, y: 14)
    }
}

struct HelpBulletCard: View {
    let icon: String
    let title: String
    let message: String
    let accent: Color

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title3.weight(.bold))
                .foregroundStyle(accent)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

struct NoticeToast: View {
    let notice: UserNotice

    private var accent: Color {
        switch notice.style {
        case .info:
            return .blue
        case .warning:
            return .orange
        }
    }

    private var icon: String {
        switch notice.style {
        case .info:
            return "checkmark.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(accent)

            VStack(alignment: .leading, spacing: 4) {
                Text(notice.title)
                    .font(.subheadline.weight(.bold))
                Text(notice.message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(accent.opacity(0.18), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: 8)
    }
}

struct TrainingProgressCard: View {
    let title: String
    let message: String

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.12))
                    .frame(width: 54, height: 54)

                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.blue)
                    .scaleEffect(1.05)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(L10n.string(.progressWaitHint))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(.white.opacity(0.84), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.blue.opacity(0.1), lineWidth: 1)
        }
    }
}

struct ParentTrainingCard: View {
    let title: String
    let subtitle: String
    let samples: [FaceSample]
    let accent: Color
    @Binding var pickerSelection: [PhotosPickerItem]
    let onRemoveSample: (FaceSample) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.title3.weight(.bold))
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(L10n.format(.photoCountUnit, samples.count))
                        .font(.headline.weight(.bold))
                        .foregroundStyle(accent)
                    Text(samples.count >= 3 ? L10n.string(.statusReady) : L10n.string(.statusNeedMore))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(samples.count >= 3 ? .green : .secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }

            if samples.isEmpty {
                EmptyPhotoState(
                    title: L10n.string(.emptyPhotoTitle),
                    message: L10n.string(.emptyPhotoMessage)
                )
            } else {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3),
                    spacing: 12
                ) {
                    ForEach(samples) { sample in
                        SampleThumbnail(
                            sample: sample,
                            onRemove: { onRemoveSample(sample) }
                        )
                    }
                }
            }

            PhotosPicker(
                selection: $pickerSelection,
                maxSelectionCount: 10,
                matching: .images,
                photoLibrary: .shared()
            ) {
                Label(L10n.format(.trainingCardAddPhotos, title), systemImage: "plus.viewfinder")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SecondaryButtonStyle(accent: accent))
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(.white.opacity(0.8))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(accent.opacity(0.16), lineWidth: 1)
        }
        .shadow(color: accent.opacity(0.1), radius: 20, x: 0, y: 14)
    }
}

struct EmptyPhotoState: View {
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.title2.weight(.bold))
                .foregroundStyle(.secondary)

            Text(title)
                .font(.subheadline.weight(.semibold))

            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(Color.black.opacity(0.03), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

struct TrainingStatusCard: View {
    let fatherCount: Int
    let motherCount: Int
    let fatherSelectedCount: Int
    let motherSelectedCount: Int
    let fatherReady: Bool
    let motherReady: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.string(.trainingStatusTitle))
                .font(.headline)

            HStack(spacing: 12) {
                TrainingStatusMetric(
                    title: L10n.string(.trainingModelFather),
                    value: "\(fatherSelectedCount)/\(fatherCount)",
                    isReady: fatherReady,
                    accent: .blue
                )
                TrainingStatusMetric(
                    title: L10n.string(.trainingModelMother),
                    value: "\(motherSelectedCount)/\(motherCount)",
                    isReady: motherReady,
                    accent: .pink
                )
            }

            Text(
                fatherReady && motherReady
                ? L10n.string(.trainingStatusReadyMessage)
                : L10n.string(.trainingStatusNeedMessage)
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .padding(22)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
    }
}

struct TrainingStatusMetric: View {
    let title: String
    let value: String
    let isReady: Bool
    let accent: Color

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(value)
                    .font(.title3.weight(.bold))
            }

            Spacer()

            Image(systemName: isReady ? "checkmark.seal.fill" : "clock.fill")
                .font(.title3)
                .foregroundStyle(isReady ? accent : .orange)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

struct SampleThumbnail: View {
    let sample: FaceSample
    var onRemove: (() -> Void)? = nil

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            SampleAvatar(sample: sample)

            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.72)],
                startPoint: .center,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(sample.name)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .foregroundStyle(.white)

                Text(sample.isRecommendedForTraining
                     ? L10n.format(.sampleQualityIncluded, sample.qualityPercentage)
                     : L10n.format(.sampleQualityExcluded, sample.qualityPercentage))
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(sample.isRecommendedForTraining ? .white.opacity(0.9) : .yellow)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(alignment: .topLeading) {
            if !sample.isRecommendedForTraining {
                Text(L10n.string(.sampleExcludedBadge))
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.yellow, in: Capsule())
                    .padding(8)
            }
        }
        .overlay(alignment: .topTrailing) {
            if let onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(8)
                        .background(Color.black.opacity(0.45), in: Circle())
                }
                .buttonStyle(.plain)
                .padding(8)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

struct SampleAvatar: View {
    let sample: FaceSample?

    var body: some View {
        Group {
            if let sample, let uiImage = UIImage(data: sample.imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(sampleColor.gradient)
                    .overlay {
                        Image(systemName: sample == nil ? "face.smiling" : "person.crop.square.fill")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundStyle(.white)
                    }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var sampleColor: Color {
        switch sample?.role {
        case .father?:
            return .blue
        case .mother?:
            return .pink
        case nil:
            return .orange
        }
    }
}

struct ProcessingOverlay: View {
    let title: String
    let message: String

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black.opacity(0.4), Color.blue.opacity(0.28)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.12))
                        .frame(width: 84, height: 84)

                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                        .scaleEffect(1.4)
                }

                VStack(spacing: 8) {
                    Text(title)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)

                    Text(message)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.94))

                    Text(L10n.string(.processingOverlayWait))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.76))
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 28)
            .frame(maxWidth: 320)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(.white.opacity(0.16), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.18), radius: 24, x: 0, y: 16)
        }
        .transition(.opacity)
    }
}

struct InfoBanner: View {
    let title: String
    let message: String
    let accent: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "sparkles.rectangle.stack.fill")
                .font(.title3)
                .foregroundStyle(accent)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    let colors: [Color]

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .foregroundStyle(.white)
            .background(
                LinearGradient(
                    colors: colors,
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: RoundedRectangle(cornerRadius: 22, style: .continuous)
            )
            .shadow(color: colors.last?.opacity(0.24) ?? .clear, radius: 18, x: 0, y: 10)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    let accent: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .foregroundStyle(accent)
            .background(
                accent.opacity(configuration.isPressed ? 0.18 : 0.1),
                in: RoundedRectangle(cornerRadius: 20, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(accent.opacity(0.12), lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

struct FloatingActionButtonStyle: ButtonStyle {
    let isEnabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.bold))
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .foregroundStyle(isEnabled ? Color.black : Color.white.opacity(0.8))
            .background(
                isEnabled ? Color.white : Color.white.opacity(0.16),
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct SubtleTextButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .foregroundStyle(Color.secondary)
            .background(
                Color.black.opacity(configuration.isPressed ? 0.08 : 0.04),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .opacity(configuration.isPressed ? 0.9 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
