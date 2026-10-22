import AppKit
import XCTest
@testable import PhotoSelect

@MainActor
final class ImagePipelineTests: XCTestCase {
    func testJPEGIsDownsampledAndCached() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let url = directory.appendingPathComponent("large.jpg")
        try makeJPEG(at: url, width: 2_400, height: 1_600)

        let loaded = await ImagePipeline.shared.load(url: url, maxPixel: 320)
        let first = try XCTUnwrap(loaded)
        XCTAssertLessThanOrEqual(max(first.size.width, first.size.height), 320)

        let cached = ImagePipeline.shared.cachedImage(for: url, maxPixel: 320)
        XCTAssertTrue(first === cached)
        XCTAssertNil(ImagePipeline.shared.cachedImage(
            for: url,
            maxPixel: ImagePipeline.inspectionMaxPixel
        ))
    }

    private func makeJPEG(at url: URL, width: Int, height: Int) throws {
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            XCTFail("Could not create bitmap")
            return
        }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        NSColor(calibratedRed: 0.12, green: 0.35, blue: 0.68, alpha: 1).setFill()
        NSRect(x: 0, y: 0, width: width, height: height).fill()
        NSGraphicsContext.restoreGraphicsState()

        let data = try XCTUnwrap(bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.85]))
        try data.write(to: url, options: .atomic)
    }
}
