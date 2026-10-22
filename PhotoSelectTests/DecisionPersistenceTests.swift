import XCTest
@testable import PhotoSelect

final class DecisionPersistenceTests: XCTestCase {
    func testRecordsSurviveReloadAndCanBeRemoved() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let persistenceURL = directory.appendingPathComponent("decisions.json")
        let photoURL = directory.appendingPathComponent("frame-001.jpg")
        let firstStore = DecisionPersistence(fileURL: persistenceURL)
        try await firstStore.set(.init(decision: .keep, categories: []), for: photoURL)
        try await firstStore.set(.init(decision: .hero, categories: ["Portrait"]), for: photoURL)

        let reloadedStore = DecisionPersistence(fileURL: persistenceURL)
        let reloaded = await reloadedStore.record(for: photoURL)
        XCTAssertEqual(reloaded?.decision, .hero)
        XCTAssertEqual(reloaded?.categories, ["Portrait"])

        try await reloadedStore.removeRecords(for: [photoURL])
        let afterRemoval = DecisionPersistence(fileURL: persistenceURL)
        let removed = await afterRemoval.record(for: photoURL)
        XCTAssertNil(removed)
    }
}

final class FolderBookmarkStoreTests: XCTestCase {
    func testRecentFoldersAreDeduplicatedAndLimitedToEight() throws {
        let suiteName = "PhotoSelectTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let folders = try (1...10).map { index in
            let folder = root.appendingPathComponent("shoot-\(index)", isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            return folder
        }

        let store = FolderBookmarkStore(defaults: defaults)
        for folder in folders {
            try store.save(folder)
        }

        XCTAssertEqual(store.resolveRecent().map(\.lastPathComponent), Array((3...10).reversed()).map { "shoot-\($0)" })

        try store.save(folders[4])
        let reordered = store.resolveRecent().map(\.lastPathComponent)
        XCTAssertEqual(reordered.first, "shoot-5")
        XCTAssertEqual(reordered.count, 8)
        XCTAssertEqual(Set(reordered).count, reordered.count)

        try FileManager.default.removeItem(at: folders[4])
        XCTAssertFalse(store.resolveRecent().contains(where: { $0.lastPathComponent == "shoot-5" }))
        XCTAssertThrowsError(try store.resolve())

        store.clearRecent()
        XCTAssertTrue(store.resolveRecent().isEmpty)
    }
}
