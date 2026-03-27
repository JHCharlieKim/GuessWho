//
//  ContentView.swift
//  GuessWho
//
//  Created by Charlie Kim on 3/23/26.
//

import PhotosUI
import SwiftUI

struct ContentView: View {
    enum SectionID: Hashable {
        case training
        case child
    }

    enum Tab: Hashable {
        case home
        case training
        case help
    }

    @StateObject private var viewModel = GuessWhoViewModel()
    @StateObject private var monetization = MonetizationCoordinator()
    @State private var selectedTab: Tab = .home

    @State private var fatherPickerItems: [PhotosPickerItem] = []
    @State private var motherPickerItems: [PhotosPickerItem] = []
    @State private var childPickerItem: PhotosPickerItem?

    @State private var shouldShowResult = false
    @State private var shouldConfirmReset = false
    @State private var shouldShowResultGateIntro = false
    @State private var shouldPresentResultGateAdAfterIntroDismiss = false
    @State private var isPresentingResultGateAd = false
    @State private var noticeDismissTask: Task<Void, Never>?

    private let palette = AppPalette()

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeTabView(
                palette: palette,
                lastErrorMessage: viewModel.lastErrorMessage,
                isTrainingReady: isTrainingReady,
                childSample: viewModel.childSample,
                childQualityWarning: viewModel.childQualityWarning,
                isProcessing: viewModel.isProcessing,
                childPickerItem: $childPickerItem,
                floatingTitle: floatingTitle,
                floatingDetail: floatingDetail,
                floatingButtonTitle: floatingButtonTitle,
                onOpenTraining: { selectedTab = .training },
                onAnalyze: analyze
            )
            .tabItem {
                Label(L10n.string(.tabHome), systemImage: "house.fill")
            }
            .tag(Tab.home)

            TrainingTabView(
                palette: palette,
                processingTitle: viewModel.processingTitle,
                processingMessage: viewModel.processingMessage,
                isProcessing: viewModel.isProcessing,
                fatherSampleCount: viewModel.sampleCount(for: .father),
                motherSampleCount: viewModel.sampleCount(for: .mother),
                fatherSelectedCount: viewModel.fatherModel?.selectedSampleCount ?? 0,
                motherSelectedCount: viewModel.motherModel?.selectedSampleCount ?? 0,
                fatherReady: viewModel.fatherReady,
                motherReady: viewModel.motherReady,
                fatherSamples: viewModel.fatherSamples,
                motherSamples: viewModel.motherSamples,
                fatherSubtitle: parentSubtitle(for: .father),
                motherSubtitle: parentSubtitle(for: .mother),
                fatherPickerItems: $fatherPickerItems,
                motherPickerItems: $motherPickerItems,
                hasAnySavedData: hasAnySavedData,
                onRemoveFatherSample: removeFatherSample,
                onRemoveMotherSample: removeMotherSample,
                onReset: { shouldConfirmReset = true }
            )
            .tabItem {
                Label(L10n.string(.tabTraining), systemImage: "photo.stack.fill")
            }
            .tag(Tab.training)

            HelpTabView(
                palette: palette,
                monetization: monetization
            )
                .tabItem {
                    Label(L10n.string(.tabHelp), systemImage: "questionmark.circle.fill")
                }
                .tag(Tab.help)
        }
        .sheet(isPresented: $shouldShowResult) {
            resultSheet
        }
        .sheet(isPresented: $shouldShowResultGateIntro, onDismiss: handleResultGateIntroDismiss) {
            ResultGateIntroSheet(
                onSkip: {
                    shouldPresentResultGateAdAfterIntroDismiss = false
                    shouldShowResultGateIntro = false
                    viewModel.transientNotice = UserNotice(
                        title: L10n.string(.adResultGateSkippedTitle),
                        message: L10n.string(.adResultGateSkippedMessage),
                        style: .info
                    )
                },
                onConfirm: {
                    shouldPresentResultGateAdAfterIntroDismiss = true
                    shouldShowResultGateIntro = false
                }
            )
        }
        .alert(L10n.string(.alertResetTitle), isPresented: $shouldConfirmReset) {
            Button(L10n.string(.actionCancel), role: .cancel) {}
            Button(L10n.string(.actionResetAllData), role: .destructive) {
                resetAllData()
            }
        } message: {
            Text(L10n.string(.alertResetMessage))
        }
        .onChange(of: fatherPickerItems, handleFatherPickerChange)
        .onChange(of: motherPickerItems, handleMotherPickerChange)
        .onChange(of: childPickerItem, handleChildPickerChange)
        .onChange(of: viewModel.transientNotice) { _, newNotice in
            guard newNotice != nil else { return }
            scheduleNoticeDismiss()
        }
        .overlay {
            if viewModel.isProcessing || isPresentingResultGateAd {
                ProcessingOverlay(
                    title: isPresentingResultGateAd ? L10n.string(.adLoadingTitle) : viewModel.processingTitle,
                    message: isPresentingResultGateAd
                        ? L10n.string(.adLoadingMessage)
                        : (viewModel.processingMessage ?? L10n.string(.processingTitleWorking))
                )
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
        .task {
            await monetization.start()
        }
    }

    private var isTrainingReady: Bool {
        viewModel.fatherReady && viewModel.motherReady
    }

    private var hasAnySavedData: Bool {
        !viewModel.fatherSamples.isEmpty
            || !viewModel.motherSamples.isEmpty
            || viewModel.childSample != nil
            || viewModel.latestSummary != nil
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
                    L10n.string(.resultUnavailableTitle),
                    systemImage: "exclamationmark.triangle",
                    description: Text(L10n.string(.resultUnavailableMessage))
                )
            }
        }
    }

    private var floatingTitle: String {
        if !isTrainingReady {
            return L10n.string(.homeFloatingTitleStartTraining)
        }

        if viewModel.childSample == nil {
            return L10n.string(.homeFloatingTitleModelReady)
        }

        return L10n.string(.homeFloatingTitleResultReady)
    }

    private var floatingDetail: String {
        if !isTrainingReady {
            return L10n.string(.homeFloatingDetailNeedTraining)
        }

        if viewModel.childSample == nil {
            return L10n.string(.homeFloatingDetailNeedChild)
        }

        return L10n.string(.homeFloatingDetailCanReviewResult)
    }

    private var floatingButtonTitle: String {
        if !isTrainingReady {
            return L10n.string(.homeFloatingButtonTrain)
        }

        if viewModel.childSample == nil {
            return L10n.string(.homeFloatingButtonPickPhoto)
        }

        return L10n.string(.homeFloatingButtonShowResult)
    }

    private func parentSubtitle(for role: ParentRole) -> String {
        let count = viewModel.sampleCount(for: role)
        let isReady = role == .father ? viewModel.fatherReady : viewModel.motherReady

        if isReady {
            let selectedCount = role == .father
                ? viewModel.fatherModel?.selectedSampleCount ?? count
                : viewModel.motherModel?.selectedSampleCount ?? count
            return L10n.format(.parentSubtitleReady, count, selectedCount)
        }

        return L10n.format(.parentSubtitleNotReady, count)
    }

    private func analyze() {
        Task {
            if await viewModel.analyze() != nil {
                beginResultPresentationFlow()
            }
        }
    }

    private func beginResultPresentationFlow() {
        if monetization.shouldPresentResultGateAd() {
            shouldShowResultGateIntro = true
        } else {
            shouldShowResult = true
        }
    }

    private func handleResultGateIntroDismiss() {
        guard shouldPresentResultGateAdAfterIntroDismiss else { return }
        shouldPresentResultGateAdAfterIntroDismiss = false
        presentResultGateAd()
    }

    private func presentResultGateAd() {
        Task {
            isPresentingResultGateAd = true
            try? await Task.sleep(for: .milliseconds(300))
            let outcome = await monetization.presentResultGateAd()
            isPresentingResultGateAd = false

            switch outcome {
            case .completed:
                shouldShowResult = true
            case .skipped:
                viewModel.transientNotice = UserNotice(
                    title: L10n.string(.adResultGateSkippedTitle),
                    message: L10n.string(.adResultGateSkippedMessage),
                    style: .info
                )
            case .unavailable:
                viewModel.transientNotice = UserNotice(
                    title: L10n.string(.adResultGateUnavailableTitle),
                    message: L10n.string(.adResultGateUnavailableMessage),
                    style: .info
                )
                shouldShowResult = true
            }
        }
    }

    private func removeFatherSample(_ sample: FaceSample) {
        Task {
            await viewModel.removeSample(sample, from: .father)
        }
    }

    private func removeMotherSample(_ sample: FaceSample) {
        Task {
            await viewModel.removeSample(sample, from: .mother)
        }
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

    private func resetAllData() {
        fatherPickerItems = []
        motherPickerItems = []
        childPickerItem = nil
        shouldShowResult = false
        shouldShowResultGateIntro = false
        isPresentingResultGateAd = false
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

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
