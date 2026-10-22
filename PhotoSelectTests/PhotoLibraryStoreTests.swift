import XCTest
@testable import PhotoSelect

@MainActor
final class PhotoLibraryStoreTests: XCTestCase {
    func testPreviewZoomIsClampedToInspectionRange() {
        XCTAssertEqual(PhotoLibraryStore.clampedZoom(0.1), 1)
        XCTAssertEqual(PhotoLibraryStore.clampedZoom(3.25), 3.25)
        XCTAssertEqual(PhotoLibraryStore.clampedZoom(20), 8)
    }

    func testDecisionInUnreviewedFilterDoesNotSkipNextPhotoAndUndoRestoresIt() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        for name in ["001.jpg", "002.jpg", "003.jpg"] {
            XCTAssertTrue(FileManager.default.createFile(
                atPath: directory.appendingPathComponent(name).path,
                contents: Data()
            ))
        }

        let persistence = DecisionPersistence(fileURL: directory.appendingPathComponent("decisions.json"))
        let defaults = try XCTUnwrap(UserDefaults(suiteName: UUID().uuidString))
        let store = PhotoLibraryStore(
            persistence: persistence,
            preferences: defaults,
            prefetchEnabled: false
        )

        await store.open(folder: directory, remember: false)
        store.setFilter(.unreviewed)
        XCTAssertEqual(store.currentAsset?.filename, "001.jpg")

        store.apply(.keep)
        XCTAssertEqual(store.currentAsset?.filename, "002.jpg")
        XCTAssertEqual(store.visibleAssets.map(\.filename), ["002.jpg", "003.jpg"])

        store.undo()
        XCTAssertEqual(store.currentAsset?.filename, "001.jpg")
        XCTAssertEqual(store.currentAsset?.decision, .unreviewed)
        XCTAssertEqual(store.visibleAssets.count, 3)
    }

    func testLeavingActiveFilterKeepsAValidCurrentPhotoWhenAutoAdvanceIsOff() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        for name in ["001.jpg", "002.jpg", "003.jpg"] {
            XCTAssertTrue(FileManager.default.createFile(
                atPath: directory.appendingPathComponent(name).path,
                contents: Data()
            ))
        }

        let persistence = DecisionPersistence(fileURL: directory.appendingPathComponent("decisions.json"))
        let defaults = try XCTUnwrap(UserDefaults(suiteName: UUID().uuidString))
        let store = PhotoLibraryStore(
            persistence: persistence,
            preferences: defaults,
            prefetchEnabled: false
        )

        await store.open(folder: directory, remember: false)
        store.autoAdvance = false
        store.setFilter(.unreviewed)

        XCTAssertEqual(store.currentAsset?.filename, "001.jpg")
        store.apply(.keep)

        XCTAssertEqual(store.currentAsset?.filename, "002.jpg")
        XCTAssertEqual(store.count(for: .keep), 1)
        XCTAssertEqual(store.count(for: .unreviewed), 2)

        store.undo()
        XCTAssertEqual(store.currentAsset?.filename, "001.jpg")
        XCTAssertEqual(store.count(for: .keep), 0)
        XCTAssertEqual(store.count(for: .unreviewed), 3)
    }

    func testAssetIdentityIsStableForTheSamePath() {
        let url = URL(fileURLWithPath: "/tmp/shoot/frame.nef")
        XCTAssertEqual(PhotoAsset(url: url).id, PhotoAsset(url: url).id)
    }

    func testFirstAndLastNavigateWithinCurrentFilter() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        for name in ["001.jpg", "002.jpg", "003.jpg"] {
            XCTAssertTrue(FileManager.default.createFile(
                atPath: directory.appendingPathComponent(name).path,
                contents: Data()
            ))
        }

        let persistence = DecisionPersistence(fileURL: directory.appendingPathComponent("decisions.json"))
        let defaults = try XCTUnwrap(UserDefaults(suiteName: UUID().uuidString))
        let store = PhotoLibraryStore(
            persistence: persistence,
            preferences: defaults,
            prefetchEnabled: false
        )

        await store.open(folder: directory, remember: false)
        store.last()
        XCTAssertEqual(store.currentAsset?.filename, "003.jpg")

        store.first()
        XCTAssertEqual(store.currentAsset?.filename, "001.jpg")
    }

    func testUndoAfterChangingFilterNeverLeavesAnInvisibleCurrentID() async throws {
        let fixture = try makeStoreFixture(filenames: ["001.jpg", "002.jpg", "003.jpg"])
        defer { try? FileManager.default.removeItem(at: fixture.directory) }

        await fixture.store.open(folder: fixture.directory, remember: false)
        fixture.store.apply(.keep)
        fixture.store.setFilter(.hero)

        XCTAssertNil(fixture.store.currentID)
        fixture.store.undo()

        XCTAssertEqual(fixture.store.filter, .hero)
        XCTAssertNil(fixture.store.currentID)
        XCTAssertNil(fixture.store.currentAsset)
        XCTAssertEqual(fixture.store.count(for: .unreviewed), 3)
        XCTAssertEqual(fixture.store.count(for: .keep), 0)
    }

    func testRapidNavigationRemainsInsideTheActiveFilteredSequence() async throws {
        let fixture = try makeStoreFixture(
            filenames: (1...40).map { String(format: "%03d.jpg", $0) }
        )
        defer { try? FileManager.default.removeItem(at: fixture.directory) }

        await fixture.store.open(folder: fixture.directory, remember: false)
        fixture.store.setFilter(.all)

        for _ in 0..<75 { fixture.store.next() }
        XCTAssertEqual(fixture.store.currentAsset?.filename, "040.jpg")

        for _ in 0..<90 { fixture.store.previous() }
        XCTAssertEqual(fixture.store.currentAsset?.filename, "001.jpg")
        XCTAssertTrue(fixture.store.visibleAssets.contains(where: { $0.id == fixture.store.currentID }))
    }

    func testConsecutiveDecisionsCompleteUnreviewedWithoutSkippingFrames() async throws {
        let filenames = (1...24).map { String(format: "%03d.jpg", $0) }
        let fixture = try makeStoreFixture(filenames: filenames)
        defer { try? FileManager.default.removeItem(at: fixture.directory) }

        await fixture.store.open(folder: fixture.directory, remember: false)
        XCTAssertTrue(fixture.store.autoAdvance)

        for expectedFilename in filenames {
            XCTAssertEqual(fixture.store.currentAsset?.filename, expectedFilename)
            fixture.store.apply(.select)
        }

        XCTAssertNil(fixture.store.currentID)
        XCTAssertTrue(fixture.store.visibleAssets.isEmpty)
        XCTAssertEqual(fixture.store.count(for: .select), filenames.count)
        XCTAssertEqual(fixture.store.count(for: .unreviewed), 0)
    }

    func testRestoredDecisionsOpenInUnreviewed() async throws {
        let fixture = try makeStoreFixture(filenames: ["001.jpg", "002.jpg", "003.jpg"])
        defer { try? FileManager.default.removeItem(at: fixture.directory) }

        try await fixture.persistence.set(
            .init(decision: .keep, categories: []),
            for: fixture.directory.appendingPathComponent("001.jpg")
        )
        try await fixture.persistence.set(
            .init(decision: .hero, categories: []),
            for: fixture.directory.appendingPathComponent("003.jpg")
        )

        await fixture.store.open(folder: fixture.directory, remember: false)

        XCTAssertEqual(fixture.store.filter, .unreviewed)
        XCTAssertEqual(fixture.store.currentAsset?.filename, "002.jpg")
        XCTAssertEqual(fixture.store.count(for: .keep), 1)
        XCTAssertEqual(fixture.store.count(for: .hero), 1)
        XCTAssertEqual(fixture.store.count(for: .unreviewed), 1)
    }

    func testPrefetchUsesActiveFilterAndRequestsNextFramesFirst() async throws {
        let filenames = (1...7).map { String(format: "%03d.jpg", $0) }
        let fixture = try makeStoreFixture(filenames: filenames)
        defer { try? FileManager.default.removeItem(at: fixture.directory) }

        for index in [1, 3, 5, 7] {
            try await fixture.persistence.set(
                .init(decision: .hero, categories: []),
                for: fixture.directory.appendingPathComponent(String(format: "%03d.jpg", index))
            )
        }

        await fixture.store.open(folder: fixture.directory, remember: false)
        fixture.store.setFilter(.hero)
        let thirdHero = try XCTUnwrap(
            fixture.store.visibleAssets.first(where: { $0.filename == "003.jpg" })
        )
        fixture.store.select(thirdHero.id)

        XCTAssertEqual(
            fixture.store.prefetchURLs.map(\.lastPathComponent),
            ["005.jpg", "007.jpg", "001.jpg"]
        )
    }

    func testExportURLPreservesExistingFilesWithNumericSuffix() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let source = URL(fileURLWithPath: "/tmp/frame.jpg")
        XCTAssertTrue(FileManager.default.createFile(
            atPath: directory.appendingPathComponent("frame.jpg").path,
            contents: Data()
        ))
        XCTAssertTrue(FileManager.default.createFile(
            atPath: directory.appendingPathComponent("frame-2.jpg").path,
            contents: Data()
        ))

        let available = PhotoLibraryStore.availableExportURL(for: source, in: directory)
        XCTAssertEqual(available.lastPathComponent, "frame-3.jpg")
    }

    func testExportCopiesLeavesSourceInPlace() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let sourceDirectory = root.appendingPathComponent("source", isDirectory: true)
        let destinationDirectory = root.appendingPathComponent("export", isDirectory: true)
        try FileManager.default.createDirectory(at: sourceDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let source = sourceDirectory.appendingPathComponent("hero.jpg")
        let contents = Data("original photo bytes".utf8)
        try contents.write(to: source)

        let defaults = try XCTUnwrap(UserDefaults(suiteName: UUID().uuidString))
        let store = PhotoLibraryStore(
            persistence: DecisionPersistence(fileURL: root.appendingPathComponent("decisions.json")),
            preferences: defaults,
            prefetchEnabled: false
        )

        await store.exportCopies(
            [PhotoAsset(url: source, decision: .hero)],
            decision: .hero,
            to: destinationDirectory
        )

        let exported = destinationDirectory.appendingPathComponent("hero.jpg")
        XCTAssertEqual(try Data(contentsOf: source), contents)
        XCTAssertEqual(try Data(contentsOf: exported), contents)
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
    }

    private func makeStoreFixture(
        filenames: [String]
    ) throws -> (directory: URL, persistence: DecisionPersistence, store: PhotoLibraryStore) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        for filename in filenames {
            let created = FileManager.default.createFile(
                atPath: directory.appendingPathComponent(filename).path,
                contents: Data()
            )
            guard created else {
                throw CocoaError(.fileWriteUnknown)
            }
        }

        let persistence = DecisionPersistence(fileURL: directory.appendingPathComponent("decisions.json"))
        let defaults = UserDefaults(suiteName: UUID().uuidString) ?? .standard
        let store = PhotoLibraryStore(
            persistence: persistence,
            preferences: defaults,
            prefetchEnabled: false
        )
        return (directory, persistence, store)
    }
}
