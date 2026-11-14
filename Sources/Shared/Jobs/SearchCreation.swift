import Foundation

struct JobProvider: Codable, Equatable, Sendable {
    let id: String
    let url: String
}

struct SearchProvider: Decodable, Sendable {
    let id: String
    let baseUrl: String?

    var isGermanImmoScout: Bool {
        guard let baseUrl, let host = URLComponents(string: baseUrl)?.host?.lowercased() else { return false }
        return ["www.immobilienscout24.de", "immobilienscout24.de"].contains(host)
    }
}

enum SearchInputFailure: Error {
    case nameRequired, invalidURL, duplicateURL, providerUnavailable

    var localizationKey: String {
        switch self {
        case .nameRequired: return "jobs.error_name"
        case .invalidURL: return "jobs.error_url"
        case .duplicateURL: return "jobs.error_duplicate"
        case .providerUnavailable: return "jobs.error_provider"
        }
    }
}

/// Validate locally, but submit the pasted URL, not a translated/rebuilt search.
enum SearchURL {
    static func validate(_ text: String) throws -> String {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, value.utf8.count <= 16_384,
              !value.unicodeScalars.contains(where: { CharacterSet.whitespacesAndNewlines.union(.controlCharacters).contains($0) }),
              let components = URLComponents(string: value),
              components.scheme == "https",
              ["www.immobilienscout24.de", "immobilienscout24.de"].contains(components.host?.lowercased() ?? ""),
              components.user == nil, components.password == nil,
              components.port == nil || components.port == 443,
              components.fragment == nil,
              components.url != nil else { throw SearchInputFailure.invalidURL }
        let segments = components.percentEncodedPath.split(separator: "/").map(String.init)
        guard segments.count >= 3, segments.first == "Suche", segments[1] == "de",
              segments.last?.hasSuffix("-mieten") == true,
              !components.path.hasSuffix("/") else { throw SearchInputFailure.invalidURL }
        // Foundation may percent-escape a malformed input. Do not silently repair it.
        let raw = Array(value.utf8)
        for index in raw.indices where raw[index] == 37 {
            guard index + 2 < raw.count,
                  isHex(raw[index + 1]), isHex(raw[index + 2]) else { throw SearchInputFailure.invalidURL }
        }
        let query = components.queryItems ?? []
        if segments.contains("radius") && !query.contains(where: { $0.name == "geocoordinates" && !($0.value ?? "").isEmpty }) {
            throw SearchInputFailure.invalidURL
        }
        if segments.contains("shape") && !query.contains(where: { $0.name == "shape" && !($0.value ?? "").isEmpty }) {
            throw SearchInputFailure.invalidURL
        }
        return value
    }

    private static func isHex(_ value: UInt8) -> Bool {
        (48...57).contains(value) || (65...70).contains(value) || (97...102).contains(value)
    }

    /// Comparison ONLY; never send this canonical representation to Fredy.
    /// Preserve every query value, including repeated keys and unknown filters.
    static func duplicateKey(_ text: String) -> String? {
        guard var components = URLComponents(string: text.trimmingCharacters(in: .whitespacesAndNewlines)),
              let host = components.host?.lowercased(),
              ["immobilienscout24.de", "www.immobilienscout24.de"].contains(host) else { return nil }
        components.host = "immobilienscout24.de"
        components.scheme = "https"
        if components.port == 443 { components.port = nil }
        components.fragment = nil
        components.queryItems = components.queryItems?.sorted {
            if $0.name == $1.name { return ($0.value ?? "") < ($1.value ?? "") }
            return $0.name < $1.name
        }
        return components.string
    }

    /// A label for the search area in the stored URL, NOT a geocoded listing city.
    static func regionLabel(_ text: String) -> String? {
        guard let components = URLComponents(string: text),
              ["immobilienscout24.de", "www.immobilienscout24.de"].contains(components.host?.lowercased() ?? ""),
              !(components.queryItems ?? []).contains(where: { ["geocodes", "shape", "geocoordinates"].contains($0.name) }) else { return nil }
        let segments = components.percentEncodedPath.split(separator: "/").map(String.init)
        guard segments.count >= 4, segments.first == "Suche", segments[1] == "de",
              !segments.contains("radius"), !segments.contains("shape") else { return nil }
        return segments.dropFirst(2).dropLast().joined(separator: " / ")
    }
}

/// Fredy v31 POST /api/jobs/ is an upsert with an EMPTY success body.
/// An explicit new id is needed for exact read-back. Never reuse an existing id.
struct SearchCreation: Encodable, Sendable {
    let jobId: String
    let name: String
    let enabled = false
    let provider: [JobProvider]
    let notificationAdapter: [String] = []
    let blacklist: [String] = []
    let excludedLocations: [String] = []
    let shareWithUsers: [String] = []
    let dealType = "rent"

    init(name: String, urlText: String) throws {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty, cleanName.count <= 200 else { throw SearchInputFailure.nameRequired }
        let url = try SearchURL.validate(urlText)
        jobId = UUID().uuidString
        self.name = cleanName
        provider = [JobProvider(id: "immoscout", url: url)]
    }
}
