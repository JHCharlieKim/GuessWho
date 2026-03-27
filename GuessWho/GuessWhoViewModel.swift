//
//  GuessWhoViewModel.swift
//  GuessWho
//
//  Created by Charlie Kim on 3/23/26.
//

import Combine
import Foundation

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
    @Published private(set) var processingMessage: String?
    @Published private(set) var lastErrorMessage: String?
    @Published private(set) var fewShotStatusMessage = "사진 학습 준비 전"
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

    var childQualityWarning: String? {
        guard let childSample, !childSample.isRecommendedForTraining else { return nil }
        if childSample.qualityNotes.isEmpty {
            return "자녀 사진 품질이 낮아 결과가 부정확할 수 있어요."
        }
        return "자녀 사진 품질이 낮아 결과가 흔들릴 수 있어요: \(childSample.qualityNotes.joined(separator: ", "))"
    }

    func addSamples(from imageDatas: [Data], to role: ParentRole) async {
        guard !imageDatas.isEmpty else { return }

        isProcessing = true
        processingMessage = "\(role.displayName) 사진을 분석하고 있어요..."
        defer {
            isProcessing = false
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
                    name: "\(role.displayName) 사진 \(startingCount + index + 1)"
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
                title: "\(role.displayName) 사진 일부가 학습에서 제외됐어요",
                message: excludedSamples.count == addedSamples.count
                    ? "올린 사진이 기준에 맞지 않아 학습에 반영되지 않았어요. 더 선명한 정면 사진으로 다시 시도해주세요."
                    : "\(excludedSamples.count)장이 기준에 맞지 않아 제외됐어요. 남은 사진으로는 계속 학습을 진행합니다.",
                style: .warning
            )
        }

        retrainIfPossible()
        processingMessage = "\(role.displayName) 사진으로 학습 상태를 업데이트하고 있어요..."
        await refreshFewShotTraining()
        persist()
    }

    func updateChildSample(from imageData: Data?) async {
        guard let imageData else { return }

        isProcessing = true
        processingMessage = "자녀 사진에서 얼굴 특징을 추출하고 있어요..."
        defer {
            isProcessing = false
            processingMessage = nil
        }

        lastErrorMessage = nil

        do {
            let ordinal = fatherSamples.count + motherSamples.count + 1
            childSample = try extractor.makeSample(
                from: imageData,
                role: nil,
                name: "자녀 사진 \(ordinal)"
            )
            latestSummary = nil
            persist()
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func removeSample(_ sample: FaceSample, from role: ParentRole) async {
        isProcessing = true
        processingMessage = "\(role.displayName) 사진을 제외하고 다시 정리하고 있어요..."
        defer {
            isProcessing = false
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
            lastErrorMessage = "부모 사진 3장씩과 자녀 사진이 모두 준비되어야 해요."
            latestSummary = nil
            return nil
        }

        isProcessing = true
        processingMessage = "부모 모델과 자녀 사진을 비교하는 중이에요..."
        defer {
            isProcessing = false
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
        fewShotStatusMessage = "디버그 초기화 완료"
        processingMessage = nil
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
