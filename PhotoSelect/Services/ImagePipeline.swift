import AppKit
import Foundation
import ImageIO
import QuickLookThumbnailing

@MainActor
final class ImagePipeline: ObservableObject {
    static let shared = ImagePipeline()

    /// One stable tier is used by both the visible preview and neighbor prefetch.
    /// This is deliberate: mismatched cache tiers make prefetch look implemented
    /// while still forcing a second decode when the user advances.
    nonisolated static let previewMaxPixel: CGFloat = 3_200
    nonisolated static let inspectionMaxPixel: CGFloat = 7_680
    nonisolated static let filmstripMaxPixel: CGFloat = 320

    nonisolated private static let rawExtensions: Set<String> = [
        "dng", "cr2", "cr3", "nef", "nrw", "arw", "raf", "rw2",
        "orf", "pef", "fff", "3fr", "rwl", "mos", "mrw", "srw", "x3f"
    ]

    private let cache = NSCache<NSString, NSImage>()
    private var tasks: [String: Task<NSImage?, Never>] = [:]
    private var prefetchTask: Task<Void, Never>?

    init() {
        cache.countLimit = 96
        cache.totalCostLimit = 256 * 1024 * 1024
    }

    func cachedImage(for url: URL, maxPixel: CGFloat) -> NSImage? {
        let pixelSize = normalizedPixelSize(maxPixel)
        return cache.object(forKey: cacheKey(url: url, maxPixel: pixelSize) as NSString)
    }

    func load(url: URL, maxPixel: CGFloat) async -> NSImage? {
        let pixelSize = normalizedPixelSize(maxPixel)
        let key = cacheKey(url: url, maxPixel: pixelSize)

        if let cached = cache.object(forKey: key as NSString) {
            return cached
        }
        if let task = tasks[key] {
            return await task.value
        }

        let task = Task.detached(priority: .userInitiated) { [url] () -> NSImage? in
            guard !Task.isCancelled else { return nil }

            let isRAW = Self.rawExtensions.contains(url.pathExtension.lowercased())
            if isRAW {
                if let image = await Self.quickLookPreview(url: url, maxPixel: pixelSize) {
                    return image
                }
                guard !Task.isCancelled else { return nil }
                return Self.imageIOPreview(url: url, maxPixel: pixelSize)
            }

            if let image = Self.imageIOPreview(url: url, maxPixel: pixelSize) {
                return image
            }
            guard !Task.isCancelled else { return nil }
            return await Self.quickLookPreview(url: url, maxPixel: pixelSize)
        }

        tasks[key] = task
        let image = await task.value
        tasks[key] = nil

        if let image {
            let cost = max(1, Int(image.size.width * image.size.height * 4))
            cache.setObject(image, forKey: key as NSString, cost: cost)
        }
        return image
    }

    /// Prefetch is intentionally sequential. Launching many RAW decodes at once
    /// competes with the foreground request for CPU, disk bandwidth, and memory.
    /// The caller orders URLs with the most likely next frame first.
    func prefetch(urls: [URL], maxPixel: CGFloat = ImagePipeline.previewMaxPixel) {
        prefetchTask?.cancel()
        guard !urls.isEmpty else {
            prefetchTask = nil
            return
        }

        prefetchTask = Task(priority: .utility) { [weak self] in
            guard let self else { return }
            for url in urls {
                guard !Task.isCancelled else { return }
                if self.cachedImage(for: url, maxPixel: maxPixel) == nil {
                    _ = await self.load(url: url, maxPixel: maxPixel)
                }
            }
        }
    }

    func resetPrefetching() {
        prefetchTask?.cancel()
        prefetchTask = nil
    }

    private func cacheKey(url: URL, maxPixel: CGFloat) -> String {
        "\(url.standardizedFileURL.path)|\(Int(maxPixel))"
    }

    private func normalizedPixelSize(_ requested: CGFloat) -> CGFloat {
        let clamped = min(max(requested, 320), ImagePipeline.inspectionMaxPixel)
        let bucket: CGFloat = clamped <= 640 ? 160 : 640
        return ceil(clamped / bucket) * bucket
    }

    nonisolated private static func imageIOPreview(url: URL, maxPixel: CGFloat) -> NSImage? {
        let sourceOptions: [CFString: Any] = [
            kCGImageSourceShouldCache: false
        ]
        guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions as CFDictionary) else {
            return nil
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(320, Int(maxPixel)),
            kCGImageSourceShouldCacheImmediately: true
        ]

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }

        return NSImage(
            cgImage: cgImage,
            size: NSSize(width: cgImage.width, height: cgImage.height)
        )
    }

    nonisolated private static func quickLookPreview(url: URL, maxPixel: CGFloat) async -> NSImage? {
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: CGSize(width: maxPixel, height: maxPixel),
            scale: 1,
            representationTypes: .all
        )

        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { representation, _ in
                    continuation.resume(returning: representation?.nsImage)
                }
            }
        } onCancel: {
            QLThumbnailGenerator.shared.cancel(request)
        }
    }
}
