//
//  FamilySimilarityModel.swift
//  GuessWho
//
//  Created by Charlie Kim on 3/23/26.
//

import Foundation

enum QualityThresholds {
    static let minimumAcceptedScore = 0.45
}

enum ParentRole: String, CaseIterable, Identifiable, Codable {
    case father
    case mother

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .father:
            return "아빠"
        case .mother:
            return "엄마"
        }
    }
}

struct FaceSample: Identifiable, Equatable, Codable {
    let id: UUID
    let role: ParentRole?
    let name: String
    let createdAt: Date
    let imageData: Data
    let embedding: [Double]
    let qualityScore: Double
    let qualityNotes: [String]

    init(
        id: UUID = UUID(),
        role: ParentRole?,
        name: String,
        createdAt: Date = Date(),
        imageData: Data,
        embedding: [Double],
        qualityScore: Double,
        qualityNotes: [String] = []
    ) {
        self.id = id
        self.role = role
        self.name = name
        self.createdAt = createdAt
        self.imageData = imageData
        self.embedding = embedding
        self.qualityScore = qualityScore
        self.qualityNotes = qualityNotes
    }

    var qualityPercentage: Int {
        Int((qualityScore * 100).rounded())
    }

    var isRecommendedForTraining: Bool {
        qualityScore >= QualityThresholds.minimumAcceptedScore
    }
}

struct TrainedParentModel: Equatable, Codable {
    let role: ParentRole
    let sampleCount: Int
    let selectedSampleCount: Int
    let centroid: [Double]
    let trainedAt: Date

    var isReady: Bool {
        selectedSampleCount >= 3 && !centroid.isEmpty
    }
}

struct SimilaritySummary: Equatable, Codable {
    let fatherScore: Int
    let motherScore: Int
    let analyzedAt: Date

    var winner: String {
        fatherScore >= motherScore ? ParentRole.father.displayName : ParentRole.mother.displayName
    }

    var winnerScore: Int {
        max(fatherScore, motherScore)
    }
}
