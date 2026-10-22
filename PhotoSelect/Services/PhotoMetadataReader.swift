import Foundation
import ImageIO

actor PhotoMetadataReader {
    static let shared = PhotoMetadataReader()

    private struct CacheKey: Hashable {
        let path: String
        let modificationDate: Date?
    }

    private var cache: [CacheKey: PhotoMetadata] = [:]
    private var cacheOrder: [CacheKey] = []
    private let cacheLimit = 256

    func metadata(for url: URL) async -> PhotoMetadata {
        let values = try? url.resourceValues(forKeys: [.contentModificationDateKey])
        let key = CacheKey(path: url.standardizedFileURL.path, modificationDate: values?.contentModificationDate)
        if let cached = cache[key] {
            return cached
        }

        let metadata = await Task.detached(priority: .userInitiated) {
            Self.readMetadata(from: url)
        }.value

        cache[key] = metadata
        cacheOrder.append(key)
        if cacheOrder.count > cacheLimit {
            let expiredCount = cacheOrder.count - cacheLimit
            let expired = cacheOrder.prefix(expiredCount)
            for key in expired {
                cache.removeValue(forKey: key)
            }
            cacheOrder.removeFirst(expiredCount)
        }
        return metadata
    }

    nonisolated static func readMetadata(from url: URL) -> PhotoMetadata {
        let source = CGImageSourceCreateWithURL(url as CFURL, nil)
        let properties = source
            .flatMap { CGImageSourceCopyPropertiesAtIndex($0, 0, nil) as? [CFString: Any] }
            ?? [:]

        let exif = dictionary(properties[kCGImagePropertyExifDictionary])
        let tiff = dictionary(properties[kCGImagePropertyTIFFDictionary])
        let gps = dictionary(properties[kCGImagePropertyGPSDictionary])
        let fileValues = try? url.resourceValues(forKeys: [
            .fileSizeKey,
            .contentModificationDateKey,
            .creationDateKey,
            .typeIdentifierKey
        ])

        let width = integer(properties[kCGImagePropertyPixelWidth] ?? properties[kCGImagePropertyWidth])
        let height = integer(properties[kCGImagePropertyPixelHeight] ?? properties[kCGImagePropertyHeight])
        let dimensions = width.flatMap { width in height.map { "\(width) × \($0)" } } ?? "Dimensions unavailable"
        let fileSize = fileValues?.fileSize.map { ByteCountFormatter.string(fromByteCount: Int64($0), countStyle: .file) }
            ?? "Size unavailable"
        let format = url.pathExtension.uppercased().isEmpty ? "Image" : url.pathExtension.uppercased()

        let capture = compactFields([
            field("Date Captured", formattedExifDate(string(exif[kCGImagePropertyExifDateTimeOriginal]))),
            field("Camera", joined(tiff[kCGImagePropertyTIFFMake], tiff[kCGImagePropertyTIFFModel])),
            field("Lens", string(exif[kCGImagePropertyExifLensModel])),
            field("Focal Length", decimal(exif[kCGImagePropertyExifFocalLength]).map { formatNumber($0, suffix: " mm") }),
            field("35 mm Equivalent", decimal(exif[kCGImagePropertyExifFocalLenIn35mmFilm]).map { formatNumber($0, suffix: " mm") }),
            field("Aperture", decimal(exif[kCGImagePropertyExifFNumber]).map { "ƒ/\(formatNumber($0))" }),
            field("Shutter Speed", decimal(exif[kCGImagePropertyExifExposureTime]).map(formatExposureTime)),
            field("ISO", isoValue(exif[kCGImagePropertyExifISOSpeedRatings])),
            field("Exposure Bias", decimal(exif[kCGImagePropertyExifExposureBiasValue]).map(formatExposureBias)),
            field("Exposure Program", exposureProgram(exif[kCGImagePropertyExifExposureProgram])),
            field("Metering Mode", meteringMode(exif[kCGImagePropertyExifMeteringMode])),
            field("White Balance", whiteBalance(exif[kCGImagePropertyExifWhiteBalance])),
            field("Flash", flashValue(exif[kCGImagePropertyExifFlash])),
            field("Camera Serial", string(exif[kCGImagePropertyExifBodySerialNumber])),
            field("Lens Serial", string(exif[kCGImagePropertyExifLensSerialNumber]))
        ])

        let image = compactFields([
            PhotoMetadata.Field(label: "Dimensions", value: dimensions),
            field("Color Model", string(properties[kCGImagePropertyColorModel])),
            field("Color Profile", string(properties[kCGImagePropertyProfileName])),
            field("EXIF Color Space", colorSpace(exif[kCGImagePropertyExifColorSpace])),
            field("Bit Depth", integer(properties[kCGImagePropertyDepth]).map { "\($0)-bit" }),
            field("Orientation", orientation(properties[kCGImagePropertyOrientation])),
            field("DPI", dpi(properties)),
            field("Software", string(tiff[kCGImagePropertyTIFFSoftware]))
        ])

        let location = locationSummary(gps)
        let file = compactFields([
            PhotoMetadata.Field(label: "Format", value: format),
            PhotoMetadata.Field(label: "File Size", value: fileSize),
            field("Created", formattedFileDate(fileValues?.creationDate)),
            field("Modified", formattedFileDate(fileValues?.contentModificationDate)),
            field("Type Identifier", fileValues?.typeIdentifier),
            PhotoMetadata.Field(label: "Path", value: url.standardizedFileURL.path)
        ])

        var sections = [
            PhotoMetadata.Section(title: "Capture", symbol: "camera.aperture", fields: capture),
            PhotoMetadata.Section(title: "Image", symbol: "photo", fields: image)
        ]
        if !location.fields.isEmpty {
            sections.append(.init(title: "Location", symbol: "location", fields: location.fields))
        }
        let rights = compactFields([
            field("Artist", string(tiff[kCGImagePropertyTIFFArtist])),
            field("Copyright", string(tiff[kCGImagePropertyTIFFCopyright]))
        ])
        if !rights.isEmpty {
            sections.append(.init(title: "Rights", symbol: "signature", fields: rights))
        }
        sections.append(.init(title: "File", symbol: "doc", fields: file))

        return PhotoMetadata(
            filename: url.lastPathComponent,
            headline: [joined(tiff[kCGImagePropertyTIFFMake], tiff[kCGImagePropertyTIFFModel]), string(exif[kCGImagePropertyExifLensModel])]
                .compactMap { $0 }
                .first ?? format,
            subheadline: "\(dimensions)  •  \(fileSize)",
            sections: sections.filter { !$0.fields.isEmpty },
            rawFields: flattened(properties),
            location: location.location
        )
    }

    nonisolated private static func dictionary(_ value: Any?) -> [CFString: Any] {
        value as? [CFString: Any] ?? [:]
    }

    nonisolated private static func field(_ label: String, _ value: String?) -> PhotoMetadata.Field? {
        guard let value, !value.isEmpty else { return nil }
        return .init(label: label, value: value)
    }

    nonisolated private static func compactFields(_ values: [PhotoMetadata.Field?]) -> [PhotoMetadata.Field] {
        values.compactMap { $0 }
    }

    nonisolated private static func string(_ value: Any?) -> String? {
        switch value {
        case let string as String: string.trimmingCharacters(in: .whitespacesAndNewlines)
        case let number as NSNumber: number.stringValue
        default: nil
        }
    }

    nonisolated private static func integer(_ value: Any?) -> Int? {
        if let number = value as? NSNumber { return number.intValue }
        return (value as? String).flatMap(Int.init)
    }

    nonisolated private static func decimal(_ value: Any?) -> Double? {
        if let number = value as? NSNumber { return number.doubleValue }
        return (value as? String).flatMap(Double.init)
    }

    nonisolated private static func joined(_ first: Any?, _ second: Any?) -> String? {
        let values = [string(first), string(second)].compactMap { $0 }.filter { !$0.isEmpty }
        return values.isEmpty ? nil : values.joined(separator: " ")
    }

    nonisolated private static func formatNumber(_ value: Double, suffix: String = "") -> String {
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        return (formatter.string(from: NSNumber(value: value)) ?? String(value)) + suffix
    }

    nonisolated private static func formatExposureTime(_ seconds: Double) -> String {
        guard seconds > 0 else { return "0 s" }
        if seconds < 1 {
            return "1/\(Int((1 / seconds).rounded())) s"
        }
        return "\(formatNumber(seconds)) s"
    }

    nonisolated private static func formatExposureBias(_ value: Double) -> String {
        let sign = value > 0 ? "+" : ""
        return "\(sign)\(formatNumber(value)) EV"
    }

    nonisolated private static func isoValue(_ value: Any?) -> String? {
        if let numbers = value as? [NSNumber], let first = numbers.first {
            return first.stringValue
        }
        return string(value)
    }

    nonisolated private static func whiteBalance(_ value: Any?) -> String? {
        guard let value = integer(value) else { return nil }
        return value == 0 ? "Auto" : "Manual"
    }

    nonisolated private static func flashValue(_ value: Any?) -> String? {
        guard let value = integer(value) else { return nil }
        return value & 0x1 == 1 ? "Fired" : "Did not fire"
    }

    nonisolated private static func exposureProgram(_ value: Any?) -> String? {
        guard let value = integer(value) else { return nil }
        let names = [
            0: "Not defined",
            1: "Manual",
            2: "Program AE",
            3: "Aperture priority",
            4: "Shutter priority",
            5: "Creative",
            6: "Action",
            7: "Portrait",
            8: "Landscape"
        ]
        return names[value] ?? "\(value)"
    }

    nonisolated private static func meteringMode(_ value: Any?) -> String? {
        guard let value = integer(value) else { return nil }
        let names = [
            0: "Unknown",
            1: "Average",
            2: "Center-weighted",
            3: "Spot",
            4: "Multi-spot",
            5: "Pattern",
            6: "Partial",
            255: "Other"
        ]
        return names[value] ?? "\(value)"
    }

    nonisolated private static func colorSpace(_ value: Any?) -> String? {
        guard let value = integer(value) else { return nil }
        switch value {
        case 1: return "sRGB"
        case 65_535: return "Uncalibrated"
        default: return "\(value)"
        }
    }

    nonisolated private static func orientation(_ value: Any?) -> String? {
        guard let value = integer(value) else { return nil }
        let names = [
            1: "Up",
            2: "Up, mirrored",
            3: "Down",
            4: "Down, mirrored",
            5: "Left, mirrored",
            6: "Right",
            7: "Right, mirrored",
            8: "Left"
        ]
        return names[value] ?? "\(value)"
    }

    nonisolated private static func dpi(_ properties: [CFString: Any]) -> String? {
        guard let x = decimal(properties[kCGImagePropertyDPIWidth]),
              let y = decimal(properties[kCGImagePropertyDPIHeight]) else { return nil }
        if abs(x - y) < 0.01 {
            return formatNumber(x)
        }
        return "\(formatNumber(x)) × \(formatNumber(y))"
    }

    nonisolated private static func formattedExifDate(_ value: String?) -> String? {
        guard let value else { return nil }
        let source = DateFormatter()
        source.locale = Locale(identifier: "en_US_POSIX")
        source.dateFormat = "yyyy:MM:dd HH:mm:ss"
        guard let date = source.date(from: value) else { return value }
        return formattedFileDate(date)
    }

    nonisolated private static func formattedFileDate(_ value: Date?) -> String? {
        guard let value else { return nil }
        return value.formatted(date: .abbreviated, time: .shortened)
    }

    nonisolated private static func locationSummary(
        _ gps: [CFString: Any]
    ) -> (fields: [PhotoMetadata.Field], location: PhotoMetadata.Location?) {
        guard var latitude = decimal(gps[kCGImagePropertyGPSLatitude]),
              var longitude = decimal(gps[kCGImagePropertyGPSLongitude]) else { return ([], nil) }
        if string(gps[kCGImagePropertyGPSLatitudeRef])?.uppercased() == "S" { latitude *= -1 }
        if string(gps[kCGImagePropertyGPSLongitudeRef])?.uppercased() == "W" { longitude *= -1 }

        var fields = [PhotoMetadata.Field(
            label: "Coordinates",
            value: String(format: "%.6f°, %.6f°", latitude, longitude)
        )]
        var altitudeText: String?
        if var altitude = decimal(gps[kCGImagePropertyGPSAltitude]) {
            if integer(gps[kCGImagePropertyGPSAltitudeRef]) == 1 { altitude *= -1 }
            altitudeText = formatNumber(altitude, suffix: " m")
            fields.append(.init(label: "Altitude", value: altitudeText ?? ""))
        }
        return (
            fields,
            PhotoMetadata.Location(
                latitude: latitude,
                longitude: longitude,
                altitude: altitudeText
            )
        )
    }

    nonisolated private static func flattened(_ properties: [CFString: Any]) -> [PhotoMetadata.Field] {
        var result: [PhotoMetadata.Field] = []
        flatten(properties, prefix: nil, into: &result)
        return result.sorted {
            $0.label.localizedStandardCompare($1.label) == .orderedAscending
        }
    }

    nonisolated private static func flatten(
        _ dictionary: [CFString: Any],
        prefix: String?,
        into result: inout [PhotoMetadata.Field]
    ) {
        for (key, value) in dictionary {
            let keyText = key as String
            let label = [prefix, keyText].compactMap { $0 }.joined(separator: " › ")
            if let nested = value as? [CFString: Any] {
                flatten(nested, prefix: label, into: &result)
            } else if let array = value as? [Any] {
                let rendered = array.compactMap(string).joined(separator: ", ")
                if !rendered.isEmpty {
                    result.append(.init(id: label, label: label, value: rendered))
                }
            } else if let rendered = string(value), !rendered.isEmpty {
                result.append(.init(id: label, label: label, value: rendered))
            }
        }
    }
}
