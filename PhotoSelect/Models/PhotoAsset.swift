import Foundation

struct PhotoAsset: Identifiable, Hashable, Codable {
    typealias ID = String

    let id: ID
    let url: URL
    var decision: PhotoDecision
    var categories: Set<String>

    init(url: URL, decision: PhotoDecision = .unreviewed, categories: Set<String> = []) {
        let standardizedURL = url.standardizedFileURL
        self.id = standardizedURL.path
        self.url = standardizedURL
        self.decision = decision
        self.categories = categories
    }

    var filename: String { url.lastPathComponent }
    var fileExtension: String { url.pathExtension.uppercased() }
}

enum PhotoDecision: String, Codable, CaseIterable, Identifiable {
    case unreviewed
    case reject
    case keep
    case select
    case hero

    var id: String { rawValue }

    var title: String {
        switch self {
        case .unreviewed: "Unreviewed"
        case .reject: "Reject"
        case .keep: "Keep"
        case .select: "Select"
        case .hero: "Hero"
        }
    }

    var symbol: String {
        switch self {
        case .unreviewed: "circle"
        case .reject: "xmark"
        case .keep: "checkmark"
        case .select: "star"
        case .hero: "sparkles"
        }
    }
}

enum LibraryFilter: String, CaseIterable, Identifiable {
    case all
    case unreviewed
    case keep
    case select
    case hero
    case reject

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "All Photos"
        case .unreviewed: "Unreviewed"
        case .keep: "Keep"
        case .select: "Select"
        case .hero: "Hero"
        case .reject: "Rejected"
        }
    }

    var symbol: String {
        switch self {
        case .all: "photo.on.rectangle.angled"
        case .unreviewed: "circle.dotted"
        case .keep: "checkmark.circle"
        case .select: "star"
        case .hero: "sparkles"
        case .reject: "trash"
        }
    }
}
