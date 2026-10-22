import AppKit
import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import PhotoSelect

final class PhotoMetadataReaderTests: XCTestCase {
    func testReadsCuratedAndRawExifMetadata() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let url = directory.appendingPathComponent("capture.jpg")
        try makeJPEGWithExif(at: url)

        let metadata = PhotoMetadataReader.readMetadata(from: url)
        let fields = metadata.sections.flatMap(\.fields)

        XCTAssertEqual(metadata.filename, "capture.jpg")
        XCTAssertTrue(metadata.subheadline.contains("640 × 480"))
        XCTAssertEqual(fields.first(where: { $0.label == "Camera" })?.value, "Example Optics Camera One")
        XCTAssertEqual(fields.first(where: { $0.label == "Lens" })?.value, "Prime 35mm")
        XCTAssertEqual(fields.first(where: { $0.label == "ISO" })?.value, "200")
        XCTAssertFalse(metadata.rawFields.isEmpty)
    }

    private func makeJPEGWithExif(at url: URL) throws {
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: 640,
            pixelsHigh: 480,
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
        NSColor(calibratedRed: 0.16, green: 0.42, blue: 0.76, alpha: 1).setFill()
        NSRect(x: 0, y: 0, width: 640, height: 480).fill()
        NSGraphicsContext.restoreGraphicsState()

        let image = try XCTUnwrap(bitmap.cgImage)
        let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(
            url as CFURL,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ))
        let properties: [CFString: Any] = [
            kCGImagePropertyTIFFDictionary: [
                kCGImagePropertyTIFFMake: "Example Optics",
                kCGImagePropertyTIFFModel: "Camera One"
            ],
            kCGImagePropertyExifDictionary: [
                kCGImagePropertyExifLensModel: "Prime 35mm",
                kCGImagePropertyExifFNumber: 2.8,
                kCGImagePropertyExifExposureTime: 0.008,
                kCGImagePropertyExifISOSpeedRatings: [200]
            ]
        ]
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
    }
}
