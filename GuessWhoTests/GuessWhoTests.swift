//
//  GuessWhoTests.swift
//  GuessWhoTests
//
//  Created by Charlie Kim on 3/23/26.
//

import Testing
@testable import GuessWho

struct GuessWhoTests {
    @Test func similarityEngineRequiresThreeSamples() async throws {
        let engine = OnDeviceSimilarityEngine()
        let samples = (1...2).map { makeSample(role: .father, ordinal: $0) }

        #expect(engine.trainModel(for: .father, samples: samples) == nil)
    }

    @Test func similarityEngineProducesScoresBetweenZeroAndHundred() async throws {
        let engine = OnDeviceSimilarityEngine()
        let fatherModel = engine.trainModel(for: .father, samples: (1...3).map { makeSample(role: .father, ordinal: $0) })
        let motherModel = engine.trainModel(for: .mother, samples: (1...3).map { makeSample(role: .mother, ordinal: $0) })
        let child = makeSample(role: nil, ordinal: 1)

        let result = engine.compare(child: child, fatherModel: try #require(fatherModel), motherModel: try #require(motherModel))

        #expect(result.fatherScore >= 0)
        #expect(result.fatherScore <= 100)
        #expect(result.motherScore >= 0)
        #expect(result.motherScore <= 100)
    }

    @Test func similarityEnginePrefersHighQualitySamplesForTraining() async throws {
        let engine = OnDeviceSimilarityEngine()
        let samples = [
            makeSample(role: .father, ordinal: 1, qualityScore: 0.95),
            makeSample(role: .father, ordinal: 2, qualityScore: 0.91),
            makeSample(role: .father, ordinal: 3, qualityScore: 0.88),
            makeSample(role: .father, ordinal: 4, qualityScore: 0.20)
        ]

        let model = try #require(engine.trainModel(for: .father, samples: samples))

        #expect(model.sampleCount == 4)
        #expect(model.selectedSampleCount == 3)
    }

    @MainActor
    @Test func viewModelRestoresPersistedSamples() async throws {
        let state = GuessWhoPersistenceState(
            fatherSamples: (1...3).map { makeSample(role: .father, ordinal: $0) },
            motherSamples: (1...3).map { makeSample(role: .mother, ordinal: $0) },
            childSample: makeSample(role: nil, ordinal: 1),
            latestSummary: SimilaritySummary(fatherScore: 60, motherScore: 40, analyzedAt: Date())
        )
        let store = GuessWhoStore(fileManager: .default)
        store.save(state)

        let viewModel = GuessWhoViewModel(
            extractor: VisionFaceEmbeddingExtractor(),
            engine: OnDeviceSimilarityEngine(),
            fewShotTrainer: UpdatableFamilyFewShotTrainer(),
            store: store
        )

        #expect(viewModel.sampleCount(for: .father) == 3)
        #expect(viewModel.sampleCount(for: .mother) == 3)
        #expect(viewModel.childSample != nil)
        #expect(viewModel.fatherReady)
        #expect(viewModel.motherReady)
    }
}

private func makeSample(role: ParentRole?, ordinal: Int, qualityScore: Double = 0.9) -> FaceSample {
    let base = role == .father ? 0.2 : role == .mother ? -0.2 : 0.0
    let embedding = (0..<16).map { index in
        base + Double(index + ordinal) / 100.0
    }

    return FaceSample(
        role: role,
        name: "sample-\(ordinal)",
        imageData: Data([0x00, 0x01, 0x02]),
        embedding: embedding,
        qualityScore: qualityScore,
        qualityNotes: qualityScore < 0.45 ? ["test-low-quality"] : []
    )
}
