//
//  FamilyFewShotTrainer.swift
//  GuessWho
//
//  Created by Charlie Kim on 3/23/26.
//

import CoreML
import Foundation

protocol FamilyFewShotTraining: AnyObject {
    func updateModel(fatherSamples: [FaceSample], motherSamples: [FaceSample]) async -> String
    func predict(for childSample: FaceSample) async -> SimilaritySummary?
    func reset()
}

final class UpdatableFamilyFewShotTrainer: FamilyFewShotTraining {
    private enum Constants {
        static let modelName = "FamilyFewShotClassifier"
        static let embeddingFeatureName = "embedding"
        static let labelFeatureName = "label"
        static let labelProbabilitiesFeatureName = "labelProbability"
    }

    private let modelConfiguration: MLModelConfiguration
    private var updatedModel: MLModel?

    init(modelConfiguration: MLModelConfiguration = MLModelConfiguration()) {
        self.modelConfiguration = modelConfiguration
    }

    func updateModel(fatherSamples: [FaceSample], motherSamples: [FaceSample]) async -> String {
        guard fatherSamples.count >= 3, motherSamples.count >= 3 else {
            return L10n.string(.fewShotNeedsMinimumSamples)
        }

        guard let sourceModelURL = Bundle.main.url(forResource: Constants.modelName, withExtension: "mlmodelc") else {
            return L10n.string(.fewShotModelMissing)
        }

        do {
            let trainingData = try makeTrainingBatchProvider(
                fatherSamples: fatherSamples,
                motherSamples: motherSamples
            )
            updatedModel = try await runUpdateTask(
                sourceModelURL: sourceModelURL,
                trainingData: trainingData
            )
            return L10n.string(.fewShotTrainingComplete)
        } catch {
            return L10n.format(.fewShotTrainingFailed, error.localizedDescription)
        }
    }

    func predict(for childSample: FaceSample) async -> SimilaritySummary? {
        do {
            let model = try await activeModel()
            let input = try makePredictionInput(from: childSample.embedding)
            let output = try await model.prediction(from: input)

            guard
                let probabilities = output.featureValue(for: Constants.labelProbabilitiesFeatureName)?.dictionaryValue as? [String: Double]
            else {
                return nil
            }

            let fatherScore = Int(((probabilities[ParentRole.father.rawValue] ?? 0) * 100).rounded())
            let motherScore = Int(((probabilities[ParentRole.mother.rawValue] ?? 0) * 100).rounded())

            return SimilaritySummary(
                fatherScore: fatherScore,
                motherScore: motherScore,
                analyzedAt: Date()
            )
        } catch {
            return nil
        }
    }

    private func activeModel() async throws -> MLModel {
        if let updatedModel {
            return updatedModel
        }

        guard let sourceModelURL = Bundle.main.url(forResource: Constants.modelName, withExtension: "mlmodelc") else {
            throw NSError(domain: "GuessWho.FewShot", code: 404, userInfo: [NSLocalizedDescriptionKey: L10n.string(.fewShotModelUnavailable)])
        }

        return try MLModel(contentsOf: sourceModelURL, configuration: modelConfiguration)
    }

    private func makeTrainingBatchProvider(
        fatherSamples: [FaceSample],
        motherSamples: [FaceSample]
    ) throws -> MLBatchProvider {
        let selectedFather = fatherSamples.filter { $0.isRecommendedForTraining }
        let selectedMother = motherSamples.filter { $0.isRecommendedForTraining }
        let samples = selectedFather + selectedMother

        let providers = try samples.map { sample in
            let embeddingValue = try MLFeatureValue(multiArray: makeMultiArray(from: sample.embedding))
            let label = sample.role?.rawValue ?? ParentRole.father.rawValue
            let labelValue = MLFeatureValue(string: label)
            return try MLDictionaryFeatureProvider(
                dictionary: [
                    Constants.embeddingFeatureName: embeddingValue,
                    Constants.labelFeatureName: labelValue
                ]
            )
        }

        return MLArrayBatchProvider(array: providers)
    }

    private func makePredictionInput(from embedding: [Double]) throws -> MLDictionaryFeatureProvider {
        let embeddingValue = try MLFeatureValue(multiArray: makeMultiArray(from: embedding))
        return try MLDictionaryFeatureProvider(
            dictionary: [Constants.embeddingFeatureName: embeddingValue]
        )
    }

    private func makeMultiArray(from embedding: [Double]) throws -> MLMultiArray {
        let multiArray = try MLMultiArray(shape: [NSNumber(value: embedding.count)], dataType: .double)
        for (index, value) in embedding.enumerated() {
            multiArray[index] = NSNumber(value: value)
        }
        return multiArray
    }

    private func runUpdateTask(
        sourceModelURL: URL,
        trainingData: MLBatchProvider
    ) async throws -> MLModel {
        try await withCheckedThrowingContinuation { continuation in
            do {
                let updateTask = try MLUpdateTask(
                    forModelAt: sourceModelURL,
                    trainingData: trainingData,
                    configuration: modelConfiguration
                ) { context in
                    continuation.resume(returning: context.model)
                }
                updateTask.resume()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    func reset() {
        updatedModel = nil
    }
}
