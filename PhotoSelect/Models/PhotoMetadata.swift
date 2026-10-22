import Foundation

struct PhotoMetadata: Equatable, Sendable {
    struct Location: Equatable, Sendable {
        let latitude: Double
        let longitude: Double
        let altitude: String?
    }

    struct Field: Identifiable, Equatable, Sendable {
        let id: String
        let label: String
        let value: String

        init(id: String? = nil, label: String, value: String) {
            self.id = id ?? label
            self.label = label
            self.value = value
        }
    }

    struct Section: Identifiable, Equatable, Sendable {
        let id: String
        let title: String
        let symbol: String
        let fields: [Field]

        init(id: String? = nil, title: String, symbol: String, fields: [Field]) {
            self.id = id ?? title
            self.title = title
            self.symbol = symbol
            self.fields = fields
        }
    }

    let filename: String
    let headline: String
    let subheadline: String
    let sections: [Section]
    let rawFields: [Field]
    let location: Location?

    func value(for label: String) -> String? {
        sections.lazy
            .flatMap(\.fields)
            .first(where: { $0.label == label })?
            .value
    }

    var copyText: String {
        let curated = sections.flatMap { section in
            [section.title] + section.fields.map { "\($0.label): \($0.value)" }
        }
        return ([filename, headline, subheadline] + curated).joined(separator: "\n")
    }
}
