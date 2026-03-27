//
//  ContentView.swift
//  GuessWho
//
//  Created by Charlie Kim on 3/23/26.
//

import PhotosUI
import SwiftUI

struct ContentView: View {
    private enum SectionID: Hashable {
        case training
        case child
        case result
    }

    private enum Tab: Hashable {
        case home
        case training
        case help
    }

    @StateObject private var viewModel = GuessWhoViewModel()
    @State private var selectedTab: Tab = .home

    @State private var fatherPickerItems: [PhotosPickerItem] = []
    @State private var motherPickerItems: [PhotosPickerItem] = []
    @State private var childPickerItem: PhotosPickerItem?

    @State private var shouldShowResult = false
    @State private var shouldConfirmReset = false
    @State private var noticeDismissTask: Task<Void, Never>?

    var body: some View {
        TabView(selection: $selectedTab) {
            homeTab
                .tabItem {
                    Label("홈", systemImage: "house.fill")
                }
                .tag(Tab.home)

            trainingTab
                .tabItem {
                    Label("학습", systemImage: "photo.stack.fill")
                }
                .tag(Tab.training)

            helpTab
                .tabItem {
                    Label("도움말", systemImage: "questionmark.circle.fill")
                }
                .tag(Tab.help)
        }
        .sheet(isPresented: $shouldShowResult) {
            resultSheet
        }
        .alert("모든 데이터를 지울까요?", isPresented: $shouldConfirmReset) {
            Button("취소", role: .cancel) {}
            Button("모든 데이터 지우기", role: .destructive) {
                resetAllData()
            }
        } message: {
            Text("등록한 부모 사진, 자녀 사진, 분석 결과가 모두 삭제됩니다.")
        }
        .onChange(of: fatherPickerItems, handleFatherPickerChange)
        .onChange(of: motherPickerItems, handleMotherPickerChange)
        .onChange(of: childPickerItem, handleChildPickerChange)
        .onChange(of: viewModel.transientNotice) { _, newNotice in
            guard newNotice != nil else { return }
            scheduleNoticeDismiss()
        }
        .overlay {
            if viewModel.isProcessing {
                ProcessingOverlay(message: viewModel.processingMessage ?? "작업 중이에요...")
            }
        }
        .overlay(alignment: .top) {
            if let notice = viewModel.transientNotice {
                NoticeToast(notice: notice)
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(2)
            }
        }
    }

    private var homeTab: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ZStack {
                    backgroundGradient.ignoresSafeArea()

                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 22) {
                            heroSection
                            primaryExperienceSection(proxy: proxy)

                            if let lastErrorMessage = viewModel.lastErrorMessage {
                                InfoBanner(
                                    title: "사진 처리 안내",
                                    message: lastErrorMessage,
                                    accent: palette.warning
                                )
                            }

                            if isTrainingReady {
                                childSection
                                    .id(SectionID.child)
                                compactTrainingShortcutSection
                                    .id(SectionID.training)
                            } else {
                                compactTrainingShortcutSection
                                    .id(SectionID.training)
                            }

                            privacyNotice
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 120)
                    }
                }
                .navigationTitle("홈")
                .navigationBarTitleDisplayMode(.inline)
                .safeAreaInset(edge: .bottom) {
                    floatingAnalyzeBar(proxy: proxy)
                }
            }
        }
    }

    private var trainingTab: some View {
        NavigationStack {
            ZStack {
                backgroundGradient.ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 22) {
                        trainingOverviewSection

                        if viewModel.isProcessing {
                            TrainingProgressCard(
                                title: processingTitle,
                                message: viewModel.processingMessage ?? "사진을 준비하고 있어요..."
                            )
                        }

                        parentTrainingSection
                        postTrainingGuideSection
                        resetSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("학습")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var helpTab: some View {
        NavigationStack {
            ZStack {
                backgroundGradient.ignoresSafeArea()

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
            .navigationTitle("도움말")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var palette: AppPalette {
        AppPalette()
    }

    private var resultSheet: some View {
        Group {
            if let summary = viewModel.latestSummary {
                ResultView(
                    summary: summary,
                    childSample: viewModel.childSample
                )
            } else {
                ContentUnavailableView(
                    "결과를 만들 수 없어요",
                    systemImage: "exclamationmark.triangle",
                    description: Text("부모 모델 학습과 자녀 사진 준비가 끝난 뒤 다시 시도해주세요.")
                )
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
                Label("닮은우리", systemImage: "sparkles")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.92))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.white.opacity(0.14), in: Capsule())

                Text(isTrainingReady ? "모델 준비가 끝났어요\n이제 바로 결과를 확인하고\n원하면 더 학습할 수 있어요" : "먼저 부모 사진으로 학습을 시작하고\n모델이 준비되면 바로\n결과를 확인할 수 있어요")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(isTrainingReady ? "이제 결과를 바로 확인할 수 있고, 원하면 사진을 더 추가해 정확도를 높일 수 있어요." : "학습을 통해 누구와 닮았는지 비교해볼 수 있어요!")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.84))
            }
            .padding(26)
        }
        .shadow(color: palette.ink.opacity(0.14), radius: 30, x: 0, y: 18)
    }

    private var isTrainingReady: Bool {
        viewModel.fatherReady && viewModel.motherReady
    }

    private var needsChildPhoto: Bool {
        isTrainingReady && viewModel.childSample == nil
    }

    private var hasAnySavedData: Bool {
        !viewModel.fatherSamples.isEmpty
            || !viewModel.motherSamples.isEmpty
            || viewModel.childSample != nil
            || viewModel.latestSummary != nil
    }

    @ViewBuilder
    private func primaryExperienceSection(proxy: ScrollViewProxy) -> some View {
        if !isTrainingReady {
            onboardingHomeSection(proxy: proxy)
        }
    }

    private func onboardingHomeSection(proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            PageSectionHeader(
                eyebrow: "Start Here",
                title: "먼저 학습을 시작해주세요",
                detail: "아직 모델이 준비되지 않았어요."
            )

            ActionSummaryCard(
                title: "학습 전 단계",
                subtitle: "결과를 보기 위해서는 먼저 학습이 필요해요.",
                message: "부모 각각 최소 3장씩 등록하면 모델이 활성화됩니다. 사진이 많을수록 품질 좋은 샘플을 골라 더 안정적으로 학습할 수 있어요.",
                accent: palette.deepBlue,
                primaryTitle: "학습하러 가기",
                primaryIcon: "arrow.right.circle.fill",
                primaryAction: { selectedTab = .training },
                secondaryTitle: viewModel.childSample == nil ? nil : "자녀 사진은 이미 준비됐어요",
                secondaryIcon: "checkmark.circle.fill",
                secondaryAction: nil
            )
        }
    }

    private var compactTrainingShortcutSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            PageSectionHeader(
                eyebrow: "Training",
                title: isTrainingReady ? "추가 사진으로 더 학습하기" : "학습을 완료해주세요",
                detail: isTrainingReady ? "더 많은 사진을 넣어 결과를 더 안정적으로 만들 수 있어요." : "부모 사진이 충분히 모이면 바로 결과를 확인할 수 있어요."
            )

            InfoBanner(
                title: isTrainingReady ? "사진을 더 추가할 수 있어요" : "부모 사진을 먼저 준비해주세요",
                message: isTrainingReady ? "결과가 애매하게 느껴진다면 부모 사진을 더 추가해보세요. 좋은 사진이 많을수록 비교가 더 안정적이에요." : "부모 사진을 각각 3장 이상 등록해보세요. 준비가 끝나면 바로 결과를 확인할 수 있어요.",
                accent: palette.deepBlue
            )
        }
    }

    private var trainingOverviewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            PageSectionHeader(
                eyebrow: "Training Hub",
                title: "부모 사진을 관리하고 학습을 보강하세요",
                detail: "부모 사진을 추가하거나 제외하면서 비교에 사용할 기준을 더 안정적으로 만들 수 있어요."
            )

            HStack(spacing: 12) {
                TrainingStatusMetric(
                    title: "아빠",
                    value: "\(viewModel.fatherModel?.selectedSampleCount ?? 0)/\(viewModel.sampleCount(for: .father))",
                    isReady: viewModel.fatherReady,
                    accent: palette.deepBlue
                )
                TrainingStatusMetric(
                    title: "엄마",
                    value: "\(viewModel.motherModel?.selectedSampleCount ?? 0)/\(viewModel.sampleCount(for: .mother))",
                    isReady: viewModel.motherReady,
                    accent: palette.coral
                )
            }
        }
    }

    private var photoGuideSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            PageSectionHeader(
                eyebrow: "Photo Guide",
                title: "이런 사진이 더 잘 맞아요",
                detail: "학습과 분석 정확도를 높이기 위한 기본 가이드입니다."
            )

            HelpBulletCard(
                icon: "sun.max.fill",
                title: "밝고 선명한 정면 사진",
                message: "얼굴 윤곽과 눈, 코, 입이 잘 보이는 사진일수록 좋은 샘플로 선택될 가능성이 높아요.",
                accent: palette.warning
            )

            HelpBulletCard(
                icon: "person.crop.square",
                title: "한 사람 얼굴이 크게 나온 사진",
                message: "얼굴이 너무 작거나 여러 명이 같이 나온 사진은 학습에서 제외될 수 있어요.",
                accent: palette.deepBlue
            )

            HelpBulletCard(
                icon: "sparkles",
                title: "결과가 애매하면 사진을 더 추가하기",
                message: "결과가 애매하게 느껴지면 부모 사진을 더 추가해보세요. 사진이 많을수록 더 안정적으로 비교할 수 있어요.",
                accent: palette.green
            )
        }
    }

    private var privacyNotice: some View {
        InfoBanner(
            title: "사진은 업로드되지 않아요",
            message: "분석에 필요한 학습과 유사도 계산은 모두 이 기기에서만 처리됩니다. 서버 전송 없이 안심하고 테스트할 수 있어요.",
            accent: palette.green
        )
    }

    private var parentTrainingSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            PageSectionHeader(
                eyebrow: "Traning",
                title: "부모 사진 학습",
                detail: "정면에 가깝고 선명한 사진일수록 결과가 안정적이에요."
            )

            ParentTrainingCard(
                title: "아빠 사진",
                subtitle: parentSubtitle(for: .father),
                samples: viewModel.fatherSamples,
                accent: palette.deepBlue,
                pickerSelection: $fatherPickerItems,
                onRemoveSample: { sample in
                    Task {
                        await viewModel.removeSample(sample, from: .father)
                    }
                }
            )

            ParentTrainingCard(
                title: "엄마 사진",
                subtitle: parentSubtitle(for: .mother),
                samples: viewModel.motherSamples,
                accent: palette.coral,
                pickerSelection: $motherPickerItems,
                onRemoveSample: { sample in
                    Task {
                        await viewModel.removeSample(sample, from: .mother)
                    }
                }
            )

            TrainingStatusCard(
                fatherCount: viewModel.sampleCount(for: .father),
                motherCount: viewModel.sampleCount(for: .mother),
                fatherSelectedCount: viewModel.fatherModel?.selectedSampleCount ?? 0,
                motherSelectedCount: viewModel.motherModel?.selectedSampleCount ?? 0,
                fewShotStatusMessage: viewModel.fewShotStatusMessage,
                fatherReady: viewModel.fatherReady,
                motherReady: viewModel.motherReady
            )
        }
    }

    private var childSection: some View {
        let childUploadTitle = viewModel.childSample == nil ? "자녀 사진 선택" : "자녀 사진 바꾸기"

        return VStack(alignment: .leading, spacing: 16) {
            PageSectionHeader(
                eyebrow: "Ready",
                title: "결과를 확인할 수 있어요",
                detail: "자녀 사진 한 장만 선택하면 비교할 수 있어요."
            )

            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center, spacing: 16) {
                    SampleAvatar(sample: viewModel.childSample)
                        .frame(width: 92, height: 92)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(viewModel.childSample?.name ?? "자녀 사진을 선택해주세요")
                            .font(.headline)
                        Text(viewModel.childSample == nil ? "웃는 얼굴보다 눈과 얼굴 윤곽이 잘 보이는 정면 사진이 더 좋아요." : "이 사진을 기준으로 아빠/엄마 양쪽과의 유사도를 계산합니다.")
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
                .disabled(viewModel.isProcessing)

                if let childQualityWarning = viewModel.childQualityWarning {
                    InfoBanner(
                        title: "사진 품질을 한 번 확인해주세요",
                        message: childQualityWarning,
                        accent: palette.warning
                    )
                }
            }
            .padding(22)
            .background(surfaceCard)
        }
    }

    private var readinessSummary: some View {
        HStack(spacing: 12) {
            ReadinessPill(
                title: "아빠",
                isReady: viewModel.fatherReady,
                accent: palette.deepBlue
            )

            ReadinessPill(
                title: "엄마",
                isReady: viewModel.motherReady,
                accent: palette.coral
            )

            ReadinessPill(
                title: "자녀",
                isReady: viewModel.childSample != nil,
                accent: palette.green
            )
        }
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
                        if viewModel.childSample == nil {
                            scrollTo(.child, proxy: proxy)
                        } else {
                            Task {
                                if await viewModel.analyze() != nil {
                                    shouldShowResult = true
                                }
                            }
                        }
                    } else {
                        selectedTab = .training
                    }
                } label: {
                    Text(floatingButtonTitle)
                        .frame(minWidth: 108)
                }
                .buttonStyle(FloatingActionButtonStyle(isEnabled: !viewModel.isProcessing))
                .disabled(viewModel.isProcessing)
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

    private var floatingTitle: String {
        if !isTrainingReady {
            return "학습을 시작해주세요"
        }

        if viewModel.childSample == nil {
            return "모델 준비 완료"
        }

        return "결과를 바로 확인할 수 있어요"
    }

    private var floatingDetail: String {
        if !isTrainingReady {
            return "부모 사진을 더 등록하면 결과 확인 단계로 넘어갈 수 있어요."
        }

        if viewModel.childSample == nil {
            return "이제 자녀 사진만 선택하면 분석할 수 있어요."
        }

        return "결과 확인 후에도 추가 사진으로 모델을 더 학습시킬 수 있어요."
    }

    private var floatingButtonTitle: String {
        if !isTrainingReady {
            return "학습하기"
        }

        if viewModel.childSample == nil {
            return "사진 선택"
        }

        return "결과 확인"
    }

    private var processingTitle: String {
        guard let message = viewModel.processingMessage else {
            return "사진을 준비하고 있어요"
        }

        if message.contains("업데이트") || message.contains("학습") {
            return "사진을 반영하고 있어요"
        }

        if message.contains("추출") {
            return "얼굴 정보를 확인하고 있어요"
        }

        if message.contains("비교") {
            return "결과를 계산하고 있어요"
        }

        return "처리 중이에요"
    }

    private var postTrainingGuideSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            PageSectionHeader(
                eyebrow: "Improve",
                title: "부모 사진을 더 추가해보세요",
                detail: "사진이 많을수록 더 좋은 샘플을 고를 수 있어 학습이 더 안정적일 수 있어요."
            )

            InfoBanner(
                title: "사진은 언제든 보강할 수 있어요",
                message: "밝고 선명한 부모 사진을 더 추가하면 좋은 샘플을 다시 골라 학습 상태를 업데이트합니다.",
                accent: palette.deepBlue
            )
        }
    }

    private var resetSection: some View {
        VStack(spacing: 10) {
            Button {
                shouldConfirmReset = true
            } label: {
                Text("모든 데이터 지우기")
                    .font(.footnote.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SubtleTextButtonStyle())
            .disabled(!hasAnySavedData)
        }
        .padding(.top, 8)
    }

    private var disclaimerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            PageSectionHeader(
                eyebrow: "Notice",
                title: "주의사항",
                detail: "꼭 읽어주세요."
            )
            
            InfoBanner(
                title: "재미를 위한 서비스예요",
                message: "이 결과는 얼굴 특징 유사도를 재미로 보여주는 기능이며, 친자확인이나 법적·의학적 판단 용도로 사용할 수 없습니다.",
                accent: .red
            )
        }
    }

    private var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.99, green: 0.97, blue: 0.94),
                Color(red: 0.95, green: 0.97, blue: 0.99),
                Color(red: 0.92, green: 0.96, blue: 0.95)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var surfaceCard: some View {
        RoundedRectangle(cornerRadius: 30, style: .continuous)
            .fill(.white.opacity(0.78))
            .overlay {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(.white.opacity(0.72), lineWidth: 1)
            }
            .shadow(color: palette.ink.opacity(0.07), radius: 22, x: 0, y: 14)
    }

    private func parentSubtitle(for role: ParentRole) -> String {
        let count = viewModel.sampleCount(for: role)
        let isReady = role == .father ? viewModel.fatherReady : viewModel.motherReady

        if isReady {
            let selectedCount = role == .father ? viewModel.fatherModel?.selectedSampleCount ?? count : viewModel.motherModel?.selectedSampleCount ?? count
            return "현재 \(count)장 중 품질 좋은 \(selectedCount)장으로 학습 중"
        }

        return "현재 \(count)장 등록됨, 최소 3장이 있어야 학습 시작"
    }

    private func handleFatherPickerChange(_: [PhotosPickerItem], _ newItems: [PhotosPickerItem]) {
        Task {
            let imageDatas = await loadImageData(from: newItems)
            await viewModel.addSamples(from: imageDatas, to: .father)
            fatherPickerItems = []
        }
    }

    private func handleMotherPickerChange(_: [PhotosPickerItem], _ newItems: [PhotosPickerItem]) {
        Task {
            let imageDatas = await loadImageData(from: newItems)
            await viewModel.addSamples(from: imageDatas, to: .mother)
            motherPickerItems = []
        }
    }

    private func handleChildPickerChange(_: PhotosPickerItem?, _ newItem: PhotosPickerItem?) {
        Task {
            let imageData = await loadImageData(from: newItem)
            await viewModel.updateChildSample(from: imageData)
            childPickerItem = nil
        }
    }

    private func loadImageData(from items: [PhotosPickerItem]) async -> [Data] {
        var imageDatas: [Data] = []

        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self) {
                imageDatas.append(data)
            }
        }

        return imageDatas
    }

    private func loadImageData(from item: PhotosPickerItem?) async -> Data? {
        guard let item else { return nil }
        return try? await item.loadTransferable(type: Data.self)
    }

    private func scrollTo(_ section: SectionID, proxy: ScrollViewProxy) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.86)) {
            proxy.scrollTo(section, anchor: .top)
        }
    }

    private func resetAllData() {
        fatherPickerItems = []
        motherPickerItems = []
        childPickerItem = nil
        shouldShowResult = false
        viewModel.resetForDebugging()
    }

    private func scheduleNoticeDismiss() {
        noticeDismissTask?.cancel()
        noticeDismissTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if !Task.isCancelled {
                withAnimation(.easeOut(duration: 0.2)) {
                    viewModel.transientNotice = nil
                }
            }
        }
    }
}

private struct AppPalette {
    let ink = Color(red: 0.09, green: 0.13, blue: 0.22)
    let deepBlue = Color(red: 0.16, green: 0.39, blue: 0.77)
    let sky = Color(red: 0.44, green: 0.75, blue: 0.93)
    let coral = Color(red: 0.96, green: 0.49, blue: 0.41)
    let green = Color(red: 0.24, green: 0.68, blue: 0.52)
    let warning = Color(red: 0.92, green: 0.58, blue: 0.21)
}

private struct PageSectionHeader: View {
    let eyebrow: String
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if (!eyebrow.isEmpty) {
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

private struct HeroMetricPill: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.white.opacity(0.72))
            Text(value)
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct ActionSummaryCard: View {
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

    var bodyView: some View {
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

    var body: some View {
        bodyView
    }
}

private struct HelpBulletCard: View {
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

private struct NoticeToast: View {
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

private struct TrainingProgressCard: View {
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

                Text("잠시만 기다려주세요. 사진 수와 기기 상태에 따라 몇 초 정도 걸릴 수 있어요.")
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

private struct WorkflowStepCard: View {
    let number: String
    let title: String
    let detail: String
    let isActive: Bool
    let isComplete: Bool
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text(number)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(isComplete ? .white : accent)
                    .frame(width: 32, height: 32)
                    .background(isComplete ? accent : accent.opacity(0.14), in: Circle())

                Spacer()

                Image(systemName: isComplete ? "checkmark.circle.fill" : "arrow.right")
                    .foregroundStyle(isComplete ? accent : .secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 118, alignment: .topLeading)
        .background(.white.opacity(isActive ? 0.82 : 0.62), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(isComplete ? accent.opacity(0.32) : .white.opacity(0.6), lineWidth: 1)
        }
        .shadow(color: accent.opacity(isActive ? 0.14 : 0.05), radius: 18, x: 0, y: 10)
    }
}

private struct ParentTrainingCard: View {
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
                    Text("\(samples.count)장")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(accent)
                    Text(samples.count >= 3 ? "기준 충족" : "더 필요")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(samples.count >= 3 ? .green : .secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }

            if samples.isEmpty {
                EmptyPhotoState(
                    title: "아직 등록된 사진이 없어요",
                    message: "밝은 곳에서 찍은 정면 사진을 먼저 추가해보세요."
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
                Label("\(title) 추가하기", systemImage: "plus.viewfinder")
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

private struct EmptyPhotoState: View {
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

private struct TrainingStatusCard: View {
    let fatherCount: Int
    let motherCount: Int
    let fatherSelectedCount: Int
    let motherSelectedCount: Int
    let fewShotStatusMessage: String
    let fatherReady: Bool
    let motherReady: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("학습 준비 상태")
                .font(.headline)

            HStack(spacing: 12) {
                TrainingStatusMetric(
                    title: "아빠 모델",
                    value: "\(fatherSelectedCount)/\(fatherCount)",
                    isReady: fatherReady,
                    accent: .blue
                )
                TrainingStatusMetric(
                    title: "엄마 모델",
                    value: "\(motherSelectedCount)/\(motherCount)",
                    isReady: motherReady,
                    accent: .pink
                )
            }

            Text(
                fatherReady && motherReady
                ? "두 모델 모두 준비됐어요. 품질이 낮은 사진은 자동 제외하고 좋은 샘플 위주로 학습합니다."
                : "부모 각각 최소 3장씩 등록되면 사진 학습을 시작할 수 있어요."
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .padding(22)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
    }
}

private struct TrainingStatusMetric: View {
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

private struct ReadinessPill: View {
    let title: String
    let isReady: Bool
    let accent: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isReady ? "checkmark.circle.fill" : "circle.dashed")
                .foregroundStyle(isReady ? accent : .secondary)

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(accent.opacity(isReady ? 0.14 : 0.06), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct ResultView: View {
    let summary: SimilaritySummary
    let childSample: FaceSample?
    @Environment(\.dismiss) private var dismiss

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
                                title: "아빠 유사도",
                                score: summary.fatherScore,
                                accent: palette.deepBlue
                            )
                            ResultScoreCard(
                                title: "엄마 유사도",
                                score: summary.motherScore,
                                accent: palette.coral
                            )
                        }

                        if let childSample {
                            resultPhotoCard(childSample: childSample)
                        }

                        InfoBanner(
                            title: "친자확인 용도로 사용할 수 없어요",
                            message: "이 화면의 수치는 오락용 얼굴 유사도 표현입니다. 의학적, 법적, 과학적 판정 결과가 아닙니다.",
                            accent: .red
                        )
                    }
                    .padding(20)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var resultHero: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("분석 결과")
                .font(.largeTitle.weight(.bold))

            Text("이번 사진은 \(summary.winner)와 더 비슷해 보여요")
                .font(.title2.weight(.bold))

            Text("\(summary.winner) 점수 \(summary.winnerScore) / 100")
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

            Text("선택된 자녀 사진 기준으로 부모 사진 학습 결과와 얼굴 특징 유사도를 계산한 결과입니다. 학습 결과가 준비되어 있으면 그 값을 먼저 반영합니다.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .background(.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}

private struct ResultScoreCard: View {
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
            return "꽤 높은 유사도"
        case 60...:
            return "비슷한 편"
        default:
            return "가벼운 참고용"
        }
    }
}

private struct SampleThumbnail: View {
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

                Text(sample.isRecommendedForTraining ? "품질 \(sample.qualityPercentage)" : "학습 제외 \(sample.qualityPercentage)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(sample.isRecommendedForTraining ? .white.opacity(0.9) : .yellow)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(alignment: .topLeading) {
            if !sample.isRecommendedForTraining {
                Text("제외")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.yellow, in: Capsule())
                    .padding(8)
            }
        }
        .overlay(alignment: .topTrailing) {
            HStack(spacing: 6) {
                if let onRemove {
                    Button(action: onRemove) {
                        Image(systemName: "xmark")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(8)
                            .background(Color.black.opacity(0.45), in: Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

private struct SampleAvatar: View {
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

private struct ProcessingOverlay: View {
    let message: String

    private var title: String {
        if message.contains("업데이트") || message.contains("학습") {
            return "사진을 반영하고 있어요"
        }

        if message.contains("추출") {
            return "얼굴 정보를 확인하고 있어요"
        }

        if message.contains("비교") {
            return "결과를 계산하고 있어요"
        }

        return "처리 중이에요"
    }

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

                    Text("앱을 닫지 않고 잠시만 기다려주세요.")
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

private struct InfoBanner: View {
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

private struct PrimaryButtonStyle: ButtonStyle {
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

private struct SecondaryButtonStyle: ButtonStyle {
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

private struct FloatingActionButtonStyle: ButtonStyle {
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

private struct SubtleTextButtonStyle: ButtonStyle {
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

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
