import Foundation

final class FolderBookmarkStore {
    private let defaults: UserDefaults
    private let bookmarkKey = "lastPhotoFolderBookmark"
    private let recentBookmarksKey = "recentPhotoFolderBookmarks"
    private let recentLimit = 8

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func save(_ url: URL) throws {
        let data = try bookmarkData(for: url)
        defaults.set(data, forKey: bookmarkKey)
        try addRecent(url, bookmarkData: data)
    }

    func resolve() throws -> URL? {
        guard let data = defaults.data(forKey: bookmarkKey) else { return nil }
        var isStale = false
        let url = try URL(
            resolvingBookmarkData: data,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
        guard isAvailableDirectory(url) else {
            clear()
            return nil
        }
        if isStale {
            try save(url)
        }
        return url
    }

    func clear() {
        defaults.removeObject(forKey: bookmarkKey)
    }

    func resolveRecent() -> [URL] {
        let bookmarks = defaults.array(forKey: recentBookmarksKey) as? [Data] ?? []
        var resolved: [(url: URL, bookmark: Data)] = []
        resolved.reserveCapacity(bookmarks.count)

        for bookmark in bookmarks {
            guard let result = try? resolve(bookmark) else { continue }
            guard isAvailableDirectory(result.url) else { continue }
            let refreshed = result.isStale
                ? (try? bookmarkData(for: result.url)) ?? bookmark
                : bookmark
            guard !resolved.contains(where: { $0.url.standardizedFileURL == result.url.standardizedFileURL }) else {
                continue
            }
            resolved.append((result.url, refreshed))
        }

        defaults.set(resolved.map(\.bookmark), forKey: recentBookmarksKey)
        return resolved.map(\.url)
    }

    func clearRecent() {
        defaults.removeObject(forKey: recentBookmarksKey)
    }

    private func addRecent(_ url: URL, bookmarkData: Data) throws {
        let standardizedURL = url.standardizedFileURL
        let existing = defaults.array(forKey: recentBookmarksKey) as? [Data] ?? []
        let retained = existing.filter { bookmark in
            guard let resolved = try? resolve(bookmark).url else { return false }
            return resolved.standardizedFileURL != standardizedURL
        }
        defaults.set(Array(([bookmarkData] + retained).prefix(recentLimit)), forKey: recentBookmarksKey)
    }

    private func bookmarkData(for url: URL) throws -> Data {
        try url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }

    private func resolve(_ data: Data) throws -> (url: URL, isStale: Bool) {
        var isStale = false
        let url = try URL(
            resolvingBookmarkData: data,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
        return (url, isStale)
    }

    private func isAvailableDirectory(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
            && isDirectory.boolValue
    }
}
