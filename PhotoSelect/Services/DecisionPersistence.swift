import Foundation

actor DecisionPersistence {
    static let shared = DecisionPersistence()

    struct Record: Codable {
        var decision: PhotoDecision
        var categories: Set<String>
    }

    private struct Mutation: Codable {
        let key: String
        let record: Record?
    }

    private var records: [String: Record] = [:]
    private let fileURL: URL
    private let journalURL: URL
    private var journalEntryCount = 0
    private let compactionThreshold = 1_000

    init(fileURL: URL? = nil) {
        let fm = FileManager.default
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("PhotoSelect", isDirectory: true)
            try? fm.createDirectory(at: base, withIntermediateDirectories: true)
            self.fileURL = base.appendingPathComponent("decisions.json")
        }
        journalURL = self.fileURL.appendingPathExtension("journal")

        if let data = try? Data(contentsOf: self.fileURL),
           let decoded = try? JSONDecoder().decode([String: Record].self, from: data) {
            records = decoded
        }
        if let journalData = try? Data(contentsOf: journalURL) {
            for line in journalData.split(separator: 0x0A) {
                guard let mutation = try? JSONDecoder().decode(Mutation.self, from: Data(line)) else { continue }
                records[mutation.key] = mutation.record
                journalEntryCount += 1
            }
        }
    }

    func record(for url: URL) -> Record? {
        records[Self.key(for: url)]
    }

    func records(for urls: [URL]) -> [String: Record] {
        var matches: [String: Record] = [:]
        matches.reserveCapacity(urls.count)
        for url in urls {
            let key = Self.key(for: url)
            matches[key] = records[key]
        }
        return matches
    }

    func set(_ record: Record, for url: URL) throws {
        let key = Self.key(for: url)
        try append([Mutation(key: key, record: record)])
        records[key] = record
        try compactIfNeeded()
    }

    func removeRecords(for urls: [URL]) throws {
        let mutations = urls.map { Mutation(key: Self.key(for: $0), record: nil) }
        try append(mutations)
        urls.forEach { records.removeValue(forKey: Self.key(for: $0)) }
        try compactIfNeeded()
    }

    private func append(_ mutations: [Mutation]) throws {
        guard !mutations.isEmpty else { return }
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        var data = Data()
        for mutation in mutations {
            data.append(try encoder.encode(mutation))
            data.append(0x0A)
        }

        if FileManager.default.fileExists(atPath: journalURL.path) {
            let handle = try FileHandle(forWritingTo: journalURL)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
            try handle.synchronize()
        } else {
            try data.write(to: journalURL, options: [.atomic])
        }
        journalEntryCount += mutations.count
    }

    private func compactIfNeeded() throws {
        guard journalEntryCount >= compactionThreshold else { return }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(records)
        try data.write(to: fileURL, options: [.atomic])
        try FileManager.default.removeItem(at: journalURL)
        journalEntryCount = 0
    }

    nonisolated private static func key(for url: URL) -> String {
        url.standardizedFileURL.path
    }
}
