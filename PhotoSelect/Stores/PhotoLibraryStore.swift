import AppKit
import Foundation

@MainActor
final class PhotoLibraryStore: ObservableObject {
    @Published private(set) var assets: [PhotoAsset] = []
    @Published var currentID: PhotoAsset.ID?
    @Published private(set) var filter: LibraryFilter = .unreviewed

    @Published var autoAdvance: Bool {
        didSet { preferences.set(autoAdvance, forKey: PreferenceKey.autoAdvance) }
    }

    @Published var showFilmstrip: Bool {
        didSet { preferences.set(showFilmstrip, forKey: PreferenceKey.showFilmstrip) }
    }

    /// Focus Mode is intentionally session-only. It is a temporary viewing state,
    /// not a persistent product preference.
    @Published var focusMode = false
    @Published var previewZoomScale: CGFloat = 1

    @Published private(set) var isLoading = false
    @Published private(set) var isMovingToTrash = false
    @Published private(set) var isExporting = false
    @Published private(set) var indexedCount = 0
    @Published var alertMessage: String?
    @Published private(set) var currentFolder: URL?
    @Published private(set) var recentFolders: [URL] = []
    @Published private var decisionCounts: [PhotoDecision: Int] = [:]

    private struct UndoEntry {
        let id: PhotoAsset.ID
        let oldDecision: PhotoDecision
    }

    private enum PreferenceKey {
        static let autoAdvance = "autoAdvance"
        static let showFilmstrip = "showFilmstrip"
    }

    nonisolated private static let supportedExtensions: Set<String> = [
        "jpg", "jpeg", "heic", "heif", "png", "tif", "tiff",
        "dng", "cr2", "cr3", "nef", "nrw", "arw", "raf", "rw2",
        "orf", "pef", "fff", "3fr", "rwl", "mos", "mrw", "srw", "x3f"
    ]

    private let persistence: DecisionPersistence
    private let preferences: UserDefaults
    private let bookmarkStore: FolderBookmarkStore
    private let prefetchEnabled: Bool
    private var undoStack: [UndoEntry] = []
    private var securityScopedFolder: URL?
    private var openGeneration = UUID()
    private var attemptedFolderRestore = false

    init(
        persistence: DecisionPersistence = .shared,
        preferences: UserDefaults = .standard,
        bookmarkStore: FolderBookmarkStore? = nil,
        prefetchEnabled: Bool = true
    ) {
        self.persistence = persistence
        self.preferences = preferences
        self.bookmarkStore = bookmarkStore ?? FolderBookmarkStore(defaults: preferences)
        self.prefetchEnabled = prefetchEnabled

        preferences.register(defaults: [
            PreferenceKey.autoAdvance: true,
            PreferenceKey.showFilmstrip: false
        ])
        autoAdvance = preferences.bool(forKey: PreferenceKey.autoAdvance)
        showFilmstrip = preferences.bool(forKey: PreferenceKey.showFilmstrip)
        recentFolders = self.bookmarkStore.resolveRecent()
        resetDecisionCounts()
    }

    deinit {
        securityScopedFolder?.stopAccessingSecurityScopedResource()
    }

    var visibleAssets: [PhotoAsset] {
        switch filter {
        case .all:
            assets
        case .unreviewed:
            assets.filter { $0.decision == .unreviewed }
        case .keep:
            assets.filter { $0.decision == .keep }
        case .select:
            assets.filter { $0.decision == .select }
        case .hero:
            assets.filter { $0.decision == .hero }
        case .reject:
            assets.filter { $0.decision == .reject }
        }
    }

    var currentAsset: PhotoAsset? {
        guard let currentID else { return nil }
        return visibleAssets.first(where: { $0.id == currentID })
    }

    var currentIndex: Int? {
        guard let currentID else { return nil }
        return visibleAssets.firstIndex(where: { $0.id == currentID })
    }

    var reviewedCount: Int {
        max(0, assets.count - count(for: .unreviewed))
    }

    var visibleCount: Int {
        count(for: filter)
    }

    var canNavigateBackward: Bool {
        guard let currentIndex else { return false }
        return currentIndex > 0
    }

    var canNavigateForward: Bool {
        guard let currentIndex else { return false }
        return currentIndex + 1 < visibleAssets.count
    }

    var canUndo: Bool { !undoStack.isEmpty }

    // Export is intentionally not exposed in the current UI. The tested helper
    // remains available for a later review/export phase without blocking the core MVP.
    var canExportVisible: Bool {
        exportDecision != nil && !visibleAssets.isEmpty && !isExporting
    }

    var exportActionTitle: String {
        guard let exportDecision else { return "Export Selected Copies…" }
        return "Export \(exportDecision.title) Copies…"
    }

    private var exportDecision: PhotoDecision? {
        switch filter {
        case .keep: .keep
        case .select: .select
        case .hero: .hero
        case .all, .unreviewed, .reject: nil
        }
    }

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.title = "Open a shoot"
        panel.message = "PhotoSelect reads photos in place. Reject remains a saved decision until you explicitly move rejected files to Trash."
        panel.prompt = "Open"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            Task { await self?.open(folder: url) }
        }
    }

    func openRecentFolder(_ url: URL) {
        Task { await open(folder: url) }
    }

    func clearRecentFolders() {
        bookmarkStore.clearRecent()
        recentFolders = []
    }

    func restoreLastFolderIfAvailable() async {
        guard !attemptedFolderRestore else { return }
        attemptedFolderRestore = true
        do {
            guard let url = try bookmarkStore.resolve() else { return }
            await open(folder: url, remember: false)
        } catch {
            bookmarkStore.clear()
            alertMessage = "PhotoSelect could not reopen the previous folder. Choose it again to restore access."
        }
    }

    func open(folder: URL, remember: Bool = true) async {
        let generation = UUID()
        openGeneration = generation
        ImagePipeline.shared.resetPrefetching()

        securityScopedFolder?.stopAccessingSecurityScopedResource()
        securityScopedFolder = folder.startAccessingSecurityScopedResource() ? folder : nil

        assets = []
        currentID = nil
        currentFolder = folder
        filter = .unreviewed
        focusMode = false
        undoStack.removeAll(keepingCapacity: true)
        indexedCount = 0
        resetDecisionCounts()
        isLoading = true

        if remember {
            do {
                try bookmarkStore.save(folder)
                recentFolders = bookmarkStore.resolveRecent()
            } catch {
                alertMessage = "The folder opened, but PhotoSelect could not remember access for the next launch."
            }
        }

        for await urls in Self.imageBatches(in: folder) {
            guard generation == openGeneration else { return }

            let savedRecords = await persistence.records(for: urls)
            let newAssets = urls.map { url in
                let record = savedRecords[url.standardizedFileURL.path]
                return PhotoAsset(
                    url: url,
                    decision: record?.decision ?? .unreviewed,
                    categories: record?.categories ?? []
                )
            }

            assets.append(contentsOf: newAssets)
            for asset in newAssets {
                adjustCount(asset.decision, by: 1)
            }
            assets.sort { $0.url.path.localizedStandardCompare($1.url.path) == .orderedAscending }
            indexedCount = assets.count

            if currentID == nil {
                currentID = visibleAssets.first?.id
                prefetchAroundCurrent()
            }

            await Task.yield()
        }

        guard generation == openGeneration else { return }
        isLoading = false
        if currentID == nil {
            currentID = visibleAssets.first?.id
        }
        prefetchAroundCurrent()
    }

    func setFilter(_ newFilter: LibraryFilter) {
        guard filter != newFilter else { return }
        let selectedID = currentID
        filter = newFilter

        if let selectedID, visibleAssets.contains(where: { $0.id == selectedID }) {
            currentID = selectedID
        } else {
            currentID = visibleAssets.first?.id
        }
        prefetchAroundCurrent()
    }

    func select(_ id: PhotoAsset.ID) {
        guard visibleAssets.contains(where: { $0.id == id }) else { return }
        currentID = id
        prefetchAroundCurrent()
    }

    func next() {
        move(by: 1)
    }

    func previous() {
        move(by: -1)
    }

    func first() {
        guard let first = visibleAssets.first else { return }
        currentID = first.id
        prefetchAroundCurrent()
    }

    func last() {
        guard let last = visibleAssets.last else { return }
        currentID = last.id
        prefetchAroundCurrent()
    }

    func zoomIn() {
        previewZoomScale = Self.clampedZoom(previewZoomScale * 1.35)
    }

    func zoomOut() {
        previewZoomScale = Self.clampedZoom(previewZoomScale / 1.35)
    }

    func zoomToFit() {
        previewZoomScale = 1
    }

    nonisolated static func clampedZoom(_ scale: CGFloat) -> CGFloat {
        min(max(scale, 1), 8)
    }

    func apply(_ decision: PhotoDecision) {
        let before = visibleAssets
        guard let current = currentAsset,
              let visibleIndex = before.firstIndex(where: { $0.id == current.id }),
              let assetIndex = assets.firstIndex(where: { $0.id == current.id }) else { return }

        let oldDecision = assets[assetIndex].decision
        if oldDecision != decision {
            assets[assetIndex].decision = decision
            adjustCount(oldDecision, by: -1)
            adjustCount(decision, by: 1)

            undoStack.append(UndoEntry(id: current.id, oldDecision: oldDecision))
            if undoStack.count > 10_000 {
                undoStack.removeFirst(undoStack.count - 10_000)
            }
            persist(assets[assetIndex])
        }

        let after = visibleAssets
        let retainedIndex = after.firstIndex(where: { $0.id == current.id })

        // If the new decision removes the current photo from the active filter,
        // move to the nearest remaining photo even when Auto Advance is off.
        if retainedIndex == nil {
            currentID = after.isEmpty ? nil : after[min(visibleIndex, after.count - 1)].id
        } else if autoAdvance, let retainedIndex {
            let destination = min(retainedIndex + 1, after.count - 1)
            currentID = after[destination].id
        }

        prefetchAroundCurrent()
    }

    func undo() {
        guard let item = undoStack.popLast(),
              let index = assets.firstIndex(where: { $0.id == item.id }) else { return }

        let currentDecision = assets[index].decision
        assets[index].decision = item.oldDecision
        adjustCount(currentDecision, by: -1)
        adjustCount(item.oldDecision, by: 1)

        let list = visibleAssets
        if list.contains(where: { $0.id == item.id }) {
            currentID = item.id
        } else if let currentID, list.contains(where: { $0.id == currentID }) {
            self.currentID = currentID
        } else {
            currentID = list.first?.id
        }
        persist(assets[index])
        prefetchAroundCurrent()
    }

    func moveRejectedToTrash() async {
        let rejected = assets.filter { $0.decision == .reject }
        guard !rejected.isEmpty, !isMovingToTrash else { return }
        isMovingToTrash = true

        let result = await Task.detached(priority: .userInitiated) {
            var moved: [PhotoAsset.ID] = []
            var movedURLs: [URL] = []
            var failures: [String] = []

            for asset in rejected {
                do {
                    _ = try FileManager.default.trashItem(at: asset.url, resultingItemURL: nil)
                    moved.append(asset.id)
                    movedURLs.append(asset.url)
                } catch {
                    failures.append(asset.filename)
                }
            }
            return (Set(moved), movedURLs, failures)
        }.value

        assets.removeAll { result.0.contains($0.id) }
        adjustCount(.reject, by: -result.0.count)

        do {
            try await persistence.removeRecords(for: result.1)
        } catch {
            alertMessage = "Files reached Trash, but PhotoSelect could not clean up their saved decisions: \(error.localizedDescription)"
        }

        currentID = visibleAssets.first?.id
        isMovingToTrash = false
        prefetchAroundCurrent()

        if !result.2.isEmpty {
            let examples = result.2.prefix(3).joined(separator: ", ")
            alertMessage = "Moved \(result.0.count) file(s) to Trash. Could not move \(result.2.count): \(examples)"
        }
    }

    // MARK: - Deferred export support

    func chooseExportDestination() {
        guard let decision = exportDecision, canExportVisible else { return }
        let assetsToExport = visibleAssets
        let panel = NSOpenPanel()
        panel.title = "Export \(decision.title) Copies"
        panel.message = "Choose where to copy \(assetsToExport.count) \(decision.title.lowercased()) photo(s). Originals stay in their current folder."
        panel.prompt = "Export Copies"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.begin { [weak self] response in
            guard response == .OK, let destination = panel.url else { return }
            Task {
                await self?.exportCopies(
                    assetsToExport,
                    decision: decision,
                    to: destination
                )
            }
        }
    }

    func exportCopies(
        _ assetsToExport: [PhotoAsset],
        decision: PhotoDecision,
        to destination: URL
    ) async {
        guard !assetsToExport.isEmpty, !isExporting else { return }
        isExporting = true
        let hasSecurityScope = destination.startAccessingSecurityScopedResource()

        let result = await Task.detached(priority: .userInitiated) {
            var copied = 0
            var failures: [String] = []
            for asset in assetsToExport {
                do {
                    let target = Self.availableExportURL(for: asset.url, in: destination)
                    try FileManager.default.copyItem(at: asset.url, to: target)
                    copied += 1
                } catch {
                    failures.append(asset.filename)
                }
            }
            return (copied, failures)
        }.value

        if hasSecurityScope {
            destination.stopAccessingSecurityScopedResource()
        }
        isExporting = false

        if result.1.isEmpty {
            alertMessage = "Exported \(result.0) \(decision.title) photo copy/copies to \(destination.lastPathComponent). Originals were not changed."
        } else {
            let examples = result.1.prefix(3).joined(separator: ", ")
            alertMessage = "Exported \(result.0) copy/copies. Could not copy \(result.1.count): \(examples)"
        }
    }

    nonisolated static func availableExportURL(for source: URL, in destination: URL) -> URL {
        let fileManager = FileManager.default
        let original = destination.appendingPathComponent(source.lastPathComponent, isDirectory: false)
        guard fileManager.fileExists(atPath: original.path) else { return original }

        let base = source.deletingPathExtension().lastPathComponent
        let pathExtension = source.pathExtension
        var suffix = 2
        while true {
            let filename = pathExtension.isEmpty
                ? "\(base)-\(suffix)"
                : "\(base)-\(suffix).\(pathExtension)"
            let candidate = destination.appendingPathComponent(filename, isDirectory: false)
            if !fileManager.fileExists(atPath: candidate.path) {
                return candidate
            }
            suffix += 1
        }
    }

    func count(for filter: LibraryFilter) -> Int {
        switch filter {
        case .all:
            assets.count
        case .unreviewed:
            decisionCounts[.unreviewed, default: 0]
        case .keep:
            decisionCounts[.keep, default: 0]
        case .select:
            decisionCounts[.select, default: 0]
        case .hero:
            decisionCounts[.hero, default: 0]
        case .reject:
            decisionCounts[.reject, default: 0]
        }
    }

    private func move(by offset: Int) {
        let list = visibleAssets
        guard !list.isEmpty else { return }

        guard let currentID,
              let index = list.firstIndex(where: { $0.id == currentID }) else {
            self.currentID = list.first?.id
            prefetchAroundCurrent()
            return
        }

        let destination = min(max(index + offset, 0), list.count - 1)
        guard destination != index else { return }
        self.currentID = list[destination].id
        prefetchAroundCurrent()
    }

    private func persist(_ asset: PhotoAsset) {
        Task { [weak self, persistence] in
            do {
                try await persistence.set(
                    .init(decision: asset.decision, categories: asset.categories),
                    for: asset.url
                )
            } catch {
                self?.alertMessage = "Could not save the latest decision: \(error.localizedDescription)"
            }
        }
    }

    private func prefetchAroundCurrent() {
        guard prefetchEnabled else { return }
        ImagePipeline.shared.prefetch(
            urls: prefetchURLs,
            maxPixel: ImagePipeline.previewMaxPixel
        )
    }

    /// Navigation follows the active filter, so prefetch that sequence rather
    /// than neighboring files in the full library. Next frames are requested first.
    var prefetchURLs: [URL] {
        guard let currentID else { return [] }

        let list = visibleAssets
        guard let index = list.firstIndex(where: { $0.id == currentID }) else { return [] }

        return [1, 2, 3, -1, -2].compactMap { offset in
            let candidate = index + offset
            guard list.indices.contains(candidate) else { return nil }
            return list[candidate].url
        }
    }

    private func resetDecisionCounts() {
        decisionCounts = Dictionary(uniqueKeysWithValues: PhotoDecision.allCases.map { ($0, 0) })
    }

    private func adjustCount(_ decision: PhotoDecision, by delta: Int) {
        let next = decisionCounts[decision, default: 0] + delta
        decisionCounts[decision] = max(0, next)
    }

    nonisolated private static func imageBatches(in folder: URL) -> AsyncStream<[URL]> {
        let extensions = supportedExtensions
        return AsyncStream { continuation in
            let worker = Task.detached(priority: .userInitiated) {
                enumerateImageBatches(in: folder, extensions: extensions) { batch in
                    guard !Task.isCancelled else { return false }
                    continuation.yield(batch)
                    return true
                }
                continuation.finish()
            }
            continuation.onTermination = { @Sendable _ in worker.cancel() }
        }
    }

    nonisolated private static func enumerateImageBatches(
        in folder: URL,
        extensions: Set<String>,
        yield: ([URL]) -> Bool
    ) {
        let keys: [URLResourceKey] = [.isRegularFileKey, .isHiddenKey]
        guard let enumerator = FileManager.default.enumerator(
            at: folder,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return }

        var batch: [URL] = []
        batch.reserveCapacity(128)

        for case let url as URL in enumerator {
            guard extensions.contains(url.pathExtension.lowercased()) else { continue }
            let values = try? url.resourceValues(forKeys: Set(keys))
            guard values?.isRegularFile == true, values?.isHidden != true else { continue }

            batch.append(url)
            if batch.count == 128 {
                guard yield(batch) else { return }
                batch.removeAll(keepingCapacity: true)
            }
        }

        if !batch.isEmpty {
            _ = yield(batch)
        }
    }
}
