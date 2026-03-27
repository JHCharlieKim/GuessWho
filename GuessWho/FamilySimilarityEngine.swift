//
//  FamilySimilarityEngine.swift
//  GuessWho
//
//  Created by Charlie Kim on 3/23/26.
//

import CoreGraphics
import CoreImage
import Foundation
import UIKit
import Vision

enum FaceAnalysisError: LocalizedError {
    case failedToLoadImage
    case faceNotFound
    case invalidEmbedding

    var errorDescription: String? {
        switch self {
        case .failedToLoadImage:
            return L10n.string(.faceErrorLoadImage)
        case .faceNotFound:
            return L10n.string(.faceErrorNotFound)
        case .invalidEmbedding:
            return L10n.string(.faceErrorInvalidEmbedding)
        }
    }
}

protocol FaceEmbeddingExtracting {
    func makeSample(from imageData: Data, role: ParentRole?, name: String) throws -> FaceSample
}

protocol FamilySimilarityScoring {
    func trainModel(for role: ParentRole, samples: [FaceSample]) -> TrainedParentModel?
    func compare(child: FaceSample, fatherModel: TrainedParentModel, motherModel: TrainedParentModel) -> SimilaritySummary
}

private struct FaceQualityAssessment {
    let score: Double
    let notes: [String]
}

struct VisionFaceEmbeddingExtractor: FaceEmbeddingExtracting {
    private let ciContext = CIContext()
    private let embeddingDimension = 16
    private let landmarkVectorLength = 20

    func makeSample(from imageData: Data, role: ParentRole?, name: String) throws -> FaceSample {
        let cgImage = try normalizedCGImage(from: imageData)
        let faceObservation = try detectPrimaryFace(in: cgImage)
        let faceImage = try cropFace(from: cgImage, using: faceObservation)
        let embedding = try embedding(from: faceImage, faceObservation: faceObservation)
        let quality = qualityAssessment(for: faceObservation, croppedFace: faceImage)

        return FaceSample(
            role: role,
            name: name,
            imageData: imageData,
            embedding: embedding,
            qualityScore: quality.score,
            qualityNotes: quality.notes
        )
    }

    private func normalizedCGImage(from data: Data) throws -> CGImage {
        guard let image = UIImage(data: data) else {
            throw FaceAnalysisError.failedToLoadImage
        }

        if let cgImage = image.cgImage, image.imageOrientation == .up {
            return cgImage
        }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        let normalized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }

        guard let cgImage = normalized.cgImage else {
            throw FaceAnalysisError.failedToLoadImage
        }

        return cgImage
    }

    private func detectPrimaryFace(in image: CGImage) throws -> VNFaceObservation {
        let request = VNDetectFaceLandmarksRequest()
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])

        guard
            let observations = request.results,
            let face = observations.max(by: { $0.boundingBox.width * $0.boundingBox.height < $1.boundingBox.width * $1.boundingBox.height })
        else {
            throw FaceAnalysisError.faceNotFound
        }

        return face
    }

    private func cropFace(from image: CGImage, using face: VNFaceObservation) throws -> CGImage {
        let width = CGFloat(image.width)
        let height = CGFloat(image.height)
        let boundingBox = face.boundingBox

        var expandedRect = CGRect(
            x: max(0, boundingBox.minX - 0.1),
            y: max(0, boundingBox.minY - 0.12),
            width: boundingBox.width + 0.2,
            height: boundingBox.height + 0.24
        )
        expandedRect.size.width = min(1 - expandedRect.minX, expandedRect.width)
        expandedRect.size.height = min(1 - expandedRect.minY, expandedRect.height)

        let cropRect = CGRect(
            x: expandedRect.minX * width,
            y: (1 - expandedRect.maxY) * height,
            width: expandedRect.width * width,
            height: expandedRect.height * height
        ).integral

        guard let cropped = image.cropping(to: cropRect) else {
            throw FaceAnalysisError.faceNotFound
        }

        return cropped
    }

    private func embedding(from faceImage: CGImage, faceObservation: VNFaceObservation) throws -> [Double] {
        let textureEmbedding = try textureEmbedding(from: faceImage)
        let landmarkEmbedding = landmarkEmbedding(from: faceObservation)
        return normalized(textureEmbedding + landmarkEmbedding)
    }

    private func textureEmbedding(from faceImage: CGImage) throws -> [Double] {
        let grayscaleImage = try resizedGrayscaleFace(from: faceImage)
        let bytesPerRow = embeddingDimension
        let totalBytes = embeddingDimension * embeddingDimension
        var pixels = Array(repeating: UInt8(0), count: totalBytes)

        guard let context = CGContext(
            data: &pixels,
            width: embeddingDimension,
            height: embeddingDimension,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            throw FaceAnalysisError.invalidEmbedding
        }

        context.draw(grayscaleImage, in: CGRect(x: 0, y: 0, width: embeddingDimension, height: embeddingDimension))

        let raw = pixels.map { Double($0) / 255.0 }
        let mean = raw.reduce(0, +) / Double(raw.count)
        let centered = raw.map { $0 - mean }
        let magnitude = sqrt(centered.map { $0 * $0 }.reduce(0, +))

        guard magnitude > 0 else {
            throw FaceAnalysisError.invalidEmbedding
        }

        return centered.map { $0 / magnitude }
    }

    private func landmarkEmbedding(from faceObservation: VNFaceObservation) -> [Double] {
        guard let landmarks = faceObservation.landmarks else {
            return Array(repeating: 0, count: landmarkVectorLength)
        }

        let leftEye = averagePoint(in: landmarks.leftEye)
        let rightEye = averagePoint(in: landmarks.rightEye)
        let nose = averagePoint(in: landmarks.nose)
        let outerLips = averagePoint(in: landmarks.outerLips)
        let innerLips = averagePoint(in: landmarks.innerLips)
        let leftEyebrow = averagePoint(in: landmarks.leftEyebrow)
        let rightEyebrow = averagePoint(in: landmarks.rightEyebrow)
        let contourTop = point(at: 0.5, in: landmarks.faceContour)
        let contourBottom = point(at: 0.95, in: landmarks.faceContour)

        let eyeDistance = distance(leftEye, rightEye)
        let browDistance = distance(leftEyebrow, rightEyebrow)
        let browToEye = ((leftEye.y - leftEyebrow.y) + (rightEye.y - rightEyebrow.y)) / 2
        let noseToMouth = outerLips.y - nose.y
        let mouthOpen = abs(outerLips.y - innerLips.y)
        let faceHeight = contourTop == .zero && contourBottom == .zero ? 1.0 : max(0.001, contourTop.y - contourBottom.y)

        let vector: [Double] = [
            leftEye.x, leftEye.y,
            rightEye.x, rightEye.y,
            nose.x, nose.y,
            outerLips.x, outerLips.y,
            leftEyebrow.x, leftEyebrow.y,
            rightEyebrow.x, rightEyebrow.y,
            eyeDistance,
            browDistance,
            browToEye,
            noseToMouth,
            mouthOpen,
            faceHeight,
            distance(leftEye, nose),
            distance(rightEye, nose)
        ]

        return normalized(vector)
    }

    private func resizedGrayscaleFace(from image: CGImage) throws -> CGImage {
        let ciImage = CIImage(cgImage: image)
        let scaleX = CGFloat(embeddingDimension) / ciImage.extent.width
        let scaleY = CGFloat(embeddingDimension) / ciImage.extent.height
        let transformed = ciImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        guard let cgImage = ciContext.createCGImage(transformed, from: CGRect(x: 0, y: 0, width: embeddingDimension, height: embeddingDimension)) else {
            throw FaceAnalysisError.invalidEmbedding
        }

        return cgImage
    }

    private func averagePoint(in region: VNFaceLandmarkRegion2D?) -> CGPoint {
        guard let region, region.pointCount > 0 else { return .zero }

        let points = region.normalizedPoints
        let sum = points.reduce(CGPoint.zero) { partial, point in
            CGPoint(x: partial.x + CGFloat(point.x), y: partial.y + CGFloat(point.y))
        }

        return CGPoint(
            x: sum.x / CGFloat(region.pointCount),
            y: sum.y / CGFloat(region.pointCount)
        )
    }

    private func point(at progress: CGFloat, in region: VNFaceLandmarkRegion2D?) -> CGPoint {
        guard let region, region.pointCount > 0 else { return .zero }
        let index = min(region.pointCount - 1, max(0, Int(CGFloat(region.pointCount - 1) * progress)))
        let point = region.normalizedPoints[index]
        return CGPoint(x: CGFloat(point.x), y: CGFloat(point.y))
    }

    private func distance(_ lhs: CGPoint, _ rhs: CGPoint) -> Double {
        let dx = Double(lhs.x - rhs.x)
        let dy = Double(lhs.y - rhs.y)
        return sqrt(dx * dx + dy * dy)
    }

    private func normalized(_ vector: [Double]) -> [Double] {
        let magnitude = sqrt(vector.map { $0 * $0 }.reduce(0, +))
        guard magnitude > 0 else { return vector }
        return vector.map { $0 / magnitude }
    }

    private func qualityAssessment(for faceObservation: VNFaceObservation, croppedFace: CGImage) -> FaceQualityAssessment {
        var score = 1.0
        var notes: [String] = []

        let faceArea = Double(faceObservation.boundingBox.width * faceObservation.boundingBox.height)
        if faceArea < 0.08 {
            score -= 0.35
            notes.append(L10n.string(.qualityFaceTooSmall))
        } else if faceArea < 0.14 {
            score -= 0.18
        }

        let centerednessX = abs(Double(faceObservation.boundingBox.midX) - 0.5)
        let centerednessY = abs(Double(faceObservation.boundingBox.midY) - 0.5)
        if centerednessX > 0.24 || centerednessY > 0.28 {
            score -= 0.2
            notes.append(L10n.string(.qualityFaceOffCenter))
        }

        let aspectRatio = Double(faceObservation.boundingBox.height / max(faceObservation.boundingBox.width, 0.001))
        if aspectRatio < 0.9 || aspectRatio > 1.8 {
            score -= 0.12
            notes.append(L10n.string(.qualityFaceAngleLarge))
        }

        let sharpness = estimatedSharpness(for: croppedFace)
        if sharpness < 0.035 {
            score -= 0.3
            notes.append(L10n.string(.qualityImageBlurry))
        } else if sharpness < 0.06 {
            score -= 0.15
        }

        let brightness = estimatedBrightness(for: croppedFace)
        if brightness < 0.18 || brightness > 0.9 {
            score -= 0.12
            notes.append(L10n.string(.qualityLightingPoor))
        }

        let clamped = max(0.0, min(1.0, score))
        return FaceQualityAssessment(score: clamped, notes: notes)
    }

    private func estimatedBrightness(for image: CGImage) -> Double {
        guard let pixels = grayscalePixels(from: image, dimension: 16) else { return 0.5 }
        return pixels.reduce(0, +) / Double(pixels.count)
    }

    private func estimatedSharpness(for image: CGImage) -> Double {
        guard let pixels = grayscalePixels(from: image, dimension: 32) else { return 0.0 }
        let dimension = 32
        var total = 0.0
        var count = 0.0

        for y in 1..<dimension {
            for x in 1..<dimension {
                let current = pixels[(y * dimension) + x]
                let left = pixels[(y * dimension) + (x - 1)]
                let top = pixels[((y - 1) * dimension) + x]
                total += abs(current - left) + abs(current - top)
                count += 2
            }
        }

        return count > 0 ? total / count : 0.0
    }

    private func grayscalePixels(from image: CGImage, dimension: Int) -> [Double]? {
        let ciImage = CIImage(cgImage: image)
        let scaleX = CGFloat(dimension) / ciImage.extent.width
        let scaleY = CGFloat(dimension) / ciImage.extent.height
        let transformed = ciImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        guard let cgImage = ciContext.createCGImage(transformed, from: CGRect(x: 0, y: 0, width: dimension, height: dimension)) else {
            return nil
        }

        let totalBytes = dimension * dimension
        var pixels = Array(repeating: UInt8(0), count: totalBytes)
        guard let context = CGContext(
            data: &pixels,
            width: dimension,
            height: dimension,
            bitsPerComponent: 8,
            bytesPerRow: dimension,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            return nil
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: dimension, height: dimension))
        return pixels.map { Double($0) / 255.0 }
    }
}

struct OnDeviceSimilarityEngine: FamilySimilarityScoring {
    private let maximumTrainingSamples = 8

    func trainModel(for role: ParentRole, samples: [FaceSample]) -> TrainedParentModel? {
        guard samples.count >= 3 else { return nil }

        let selectedSamples = trainingSamples(from: samples)
        guard selectedSamples.count >= 3 else { return nil }

        let centroid = average(selectedSamples.map(\.embedding))
        return TrainedParentModel(
            role: role,
            sampleCount: samples.count,
            selectedSampleCount: selectedSamples.count,
            centroid: centroid,
            trainedAt: Date()
        )
    }

    func compare(child: FaceSample, fatherModel: TrainedParentModel, motherModel: TrainedParentModel) -> SimilaritySummary {
        let fatherScore = similarityScore(between: child.embedding, and: fatherModel.centroid)
        let motherScore = similarityScore(between: child.embedding, and: motherModel.centroid)

        return SimilaritySummary(
            fatherScore: fatherScore,
            motherScore: motherScore,
            analyzedAt: Date()
        )
    }

    private func average(_ vectors: [[Double]]) -> [Double] {
        guard let first = vectors.first else { return [] }
        var sums = Array(repeating: 0.0, count: first.count)

        for vector in vectors {
            for index in vector.indices {
                sums[index] += vector[index]
            }
        }

        let count = Double(vectors.count)
        let averaged = sums.map { $0 / count }
        let magnitude = sqrt(averaged.map { $0 * $0 }.reduce(0, +))

        guard magnitude > 0 else { return averaged }
        return averaged.map { $0 / magnitude }
    }

    private func similarityScore(between lhs: [Double], and rhs: [Double]) -> Int {
        guard lhs.count == rhs.count, !lhs.isEmpty else { return 0 }

        let cosine = zip(lhs, rhs).map(*).reduce(0, +)
        let normalized = max(0.0, min(1.0, (cosine + 1.0) / 2.0))
        return Int((normalized * 100.0).rounded())
    }

    private func trainingSamples(from samples: [FaceSample]) -> [FaceSample] {
        let qualitySorted = samples
            .filter(\.isRecommendedForTraining)
            .sorted { lhs, rhs in
                if lhs.qualityScore == rhs.qualityScore {
                    return lhs.createdAt > rhs.createdAt
                }
                return lhs.qualityScore > rhs.qualityScore
            }

        let selected = Array(qualitySorted.prefix(maximumTrainingSamples))
        if selected.count >= 3 {
            return selected
        }

        return Array(
            samples
                .sorted { lhs, rhs in
                    if lhs.qualityScore == rhs.qualityScore {
                        return lhs.createdAt > rhs.createdAt
                    }
                    return lhs.qualityScore > rhs.qualityScore
                }
                .prefix(min(maximumTrainingSamples, samples.count))
        )
    }
}
