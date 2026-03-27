//
//  GuessWhoViewModel.swift
//  GuessWho
//
//  Created by Charlie Kim on 3/23/26.
//

import Combine
import Foundation

enum ProcessingStage: Equatable {
    case analyzingParent(ParentRole)
    case updatingTraining(ParentRole)
    case extractingChildFeatures
    case removingParent(ParentRole)
    case comparing

    var title: String {
        switch self {
        case .analyzingParent, .extractingChildFeatures:
            return L10n.string(.processingTitleCheckingFace)
        case .updatingTraining, .removingParent:
            return L10n.string(.processingTitleUpdatingPhotos)
        case .comparing:
            return L10n.string(.processingTitleCalculatingResult)
        }
    }

    var message: String {
        switch self {
        case let .analyzingParent(role):
            return L10n.format(.processingMessageAnalyzeParent, role.displayName)
        case let .updatingTraining(role):
            return L10n.format(.processingMessageUpdateTraining, role.displayName)
        case .extractingChildFeatures:
            return L10n.string(.processingMessageExtractChild)
        case let .removingParent(role):
            return L10n.format(.processingMessageRemoveParent, role.displayName)
        case .comparing:
            return L10n.string(.processingMessageCompare)
        }
    }
}

struct UserNotice: Equatable, Identifiable {
    enum Style: Equatable {
        case info
        case warning
    }

    let id = UUID()
    let title: String
    let message: String
    let style: Style
}

@MainActor
final class GuessWhoViewModel: ObservableObject {
    @Published private(set) var fatherSamples: [FaceSample]
    @Published private(set) var motherSamples: [FaceSample]
    @Published private(set) var childSample: FaceSample?
    @Published private(set) var fatherModel: TrainedParentModel?
    @Published private(set) var motherModel: TrainedParentModel?
    @Published private(set) var latestSummary: SimilaritySummary?
    @Published private(set) var isProcessing = false
    @Published private(set) var processingStage: ProcessingStage?
    @Published private(set) var processingMessage: String?
    @Published private(set) var lastErrorMessage: String?
    @Published private(set) var fewShotStatusMessage = L10n.string(.fewShotIdle)
    @Published var transientNotice: UserNotice?

    private let extractor: FaceEmbeddingExtracting
    private let engine: FamilySimilarityScoring
    private let fewShotTrainer: FamilyFewShotTraining
    private let store: GuessWhoStore

    convenience init() {
        self.init(
            extractor: VisionFaceEmbeddingExtractor(),
            engine: OnDeviceSimilarityEngine(),
            fewShotTrainer: UpdatableFamilyFewShotTrainer(),
            store: GuessWhoStore()
        )
    }

    init(
        extractor: FaceEmbeddingExtracting,
        engine: FamilySimilarityScoring,
        fewShotTrainer: FamilyFewShotTraining,
        store: GuessWhoStore
    ) {
        self.extractor = extractor
        self.engine = engine
        self.fewShotTrainer = fewShotTrainer
        self.store = store

        let persisted = store.load()
        self.fatherSamples = persisted?.fatherSamples ?? []
        self.motherSamples = persisted?.motherSamples ?? []
        self.childSample = persisted?.childSample
        self.latestSummary = persisted?.latestSummary

        retrainIfPossible()
        Task {
            await refreshFewShotTraining()
        }
    }

    var fatherReady: Bool {
        fatherModel?.isReady == true
    }

    var motherReady: Bool {
        motherModel?.isReady == true
    }

    var canAnalyze: Bool {
        fatherReady && motherReady && childSample != nil
    }

    var processingTitle: String {
        processingStage?.title ?? L10n.string(.processingTitlePreparingPhotos)
    }

    var childQualityWarning: String? {
        guard let childSample, !childSample.isRecommendedForTraining else { return nil }
        if childSample.qualityNotes.isEmpty {
            return L10n.string(.childQualityLow)
        }
        return L10n.format(.childQualityLowWithNotes, childSample.qualityNotes.joined(separator: ", "))
    }

    func addSamples(from imageDatas: [Data], to role: ParentRole) async {
        guard !imageDatas.isEmpty else { return }

        isProcessing = true
        processingStage = .analyzingParent(role)
        processingMessage = processingStage?.message
        defer {
            isProcessing = false
            processingStage = nil
            processingMessage = nil
        }

        lastErrorMessage = nil

        var addedSamples: [FaceSample] = []
        let startingCount = sampleCount(for: role)

        for (index, data) in imageDatas.enumerated() {
            do {
                let sample = try extractor.makeSample(
                    from: data,
                    role: role,
                    name: L10n.format(.sampleParentName, role.displayName, startingCount + index + 1)
                )
                addedSamples.append(sample)
            } catch {
                lastErrorMessage = error.localizedDescription
            }
        }

        guard !addedSamples.isEmpty else { return }

        switch role {
        case .father:
            fatherSamples.append(contentsOf: addedSamples)
        case .mother:
            motherSamples.append(contentsOf: addedSamples)
        }

        let excludedSamples = addedSamples.filter { !$0.isRecommendedForTraining }
        if !excludedSamples.isEmpty {
            transientNotice = UserNotice(
                title: L10n.format(.noticeExcludedSomePhotosTitle, role.displayName),
                message: excludedSamples.count == addedSamples.count
                    ? L10n.string(.noticeExcludedAllPhotosMessage)
                    : L10n.format(.noticeExcludedPartialPhotosMessage, excludedSamples.count),
                style: .warning
            )
        }

        retrainIfPossible()
        processingStage = .updatingTraining(role)
        processingMessage = processingStage?.message
        await refreshFewShotTraining()
        persist()
    }

    func updateChildSample(from imageData: Data?) async {
        guard let imageData else { return }

        isProcessing = true
        processingStage = .extractingChildFeatures
        processingMessage = processingStage?.message
        defer {
            isProcessing = false
            processingStage = nil
            processingMessage = nil
        }

        lastErrorMessage = nil

        do {
            let ordinal = fatherSamples.count + motherSamples.count + 1
            childSample = try extractor.makeSample(
                from: imageData,
                role: nil,
                name: L10n.format(.sampleChildName, ordinal)
            )
            latestSummary = nil
            persist()
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func removeSample(_ sample: FaceSample, from role: ParentRole) async {
        isProcessing = true
        processingStage = .removingParent(role)
        processingMessage = processingStage?.message
        defer {
            isProcessing = false
            processingStage = nil
            processingMessage = nil
        }

        latestSummary = nil
        lastErrorMessage = nil

        switch role {
        case .father:
            fatherSamples.removeAll { $0.id == sample.id }
        case .mother:
            motherSamples.removeAll { $0.id == sample.id }
        }

        retrainIfPossible()
        await refreshFewShotTraining()
        persist()
    }

    func analyze() async -> SimilaritySummary? {
        guard
            let childSample,
            let fatherModel,
            let motherModel
        else {
            lastErrorMessage = L10n.string(.analyzeRequirementsMissing)
            latestSummary = nil
            return nil
        }

        isProcessing = true
        processingStage = .comparing
        processingMessage = processingStage?.message
        defer {
            isProcessing = false
            processingStage = nil
            processingMessage = nil
        }

        let summary = await fewShotTrainer.predict(for: childSample) ?? engine.compare(
            child: childSample,
            fatherModel: fatherModel,
            motherModel: motherModel
        )
        latestSummary = summary
        persist()
        return summary
    }

    func sampleCount(for role: ParentRole) -> Int {
        samples(for: role).count
    }

    func resetForDebugging() {
        fatherSamples = []
        motherSamples = []
        childSample = nil
        fatherModel = nil
        motherModel = nil
        latestSummary = nil
        lastErrorMessage = nil
        fewShotStatusMessage = L10n.string(.resetDebugCompleted)
        processingMessage = nil
        processingStage = nil
        fewShotTrainer.reset()
        store.reset()
    }

    private func retrainIfPossible() {
        fatherModel = engine.trainModel(for: .father, samples: fatherSamples)
        motherModel = engine.trainModel(for: .mother, samples: motherSamples)
    }

    private func samples(for role: ParentRole) -> [FaceSample] {
        switch role {
        case .father:
            return fatherSamples
        case .mother:
            return motherSamples
        }
    }

    private func persist() {
        store.save(
            GuessWhoPersistenceState(
                fatherSamples: fatherSamples,
                motherSamples: motherSamples,
                childSample: childSample,
                latestSummary: latestSummary
            )
        )
    }

    private func refreshFewShotTraining() async {
        fewShotStatusMessage = await fewShotTrainer.updateModel(
            fatherSamples: fatherSamples,
            motherSamples: motherSamples
        )
    }
}
