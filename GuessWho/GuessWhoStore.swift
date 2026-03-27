//
//  GuessWhoStore.swift
//  GuessWho
//
//  Created by Charlie Kim on 3/23/26.
//

import Foundation

struct GuessWhoPersistenceState: Codable {
    var fatherSamples: [FaceSample]
    var motherSamples: [FaceSample]
    var childSample: FaceSample?
    var latestSummary: SimilaritySummary?
}

struct GuessWhoStore {
    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(fileManager: FileManager = .default) {
        let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? fileManager.temporaryDirectory
        let directoryURL = baseURL.appendingPathComponent("GuessWho", isDirectory: true)

        if !fileManager.fileExists(atPath: directoryURL.path) {
            try? fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        }

        self.fileURL = directoryURL.appendingPathComponent("family-similarity-state.json")
        encoder.outputFormatting = [.prettyPrinted]
    }

    func load() -> GuessWhoPersistenceState? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? decoder.decode(GuessWhoPersistenceState.self, from: data)
    }

    func save(_ state: GuessWhoPersistenceState) {
        guard let data = try? encoder.encode(state) else { return }
        try? data.write(to: fileURL, options: [.atomic])
    }

    func reset() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
