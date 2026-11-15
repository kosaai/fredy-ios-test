import Foundation

struct JobProvider: Codable, Equatable, Sendable {
    let id: String
    let url: String
}

/// German rental providers reviewed against the installed Fredy 31 adapter inventory.
/// The runtime list is intersected with the server's real provider metadata.
enum GermanRentalProvider: String, CaseIterable, Identifiable, Sendable {
    case immoscout, immowelt, kleinanzeigen, wgGesucht, ohneMakler
    case deutscheWohnen, betterhomes, einsAImmobilien, engelVoelkers
    case imaxx, immobilienDe, immoswp, regionalimmobilien24, schwarzesbrett, sparkasse

    var id: String { rawValue }

    var title: String {
        switch self {
        case .immoscout: return "ImmoScout24"
        case .immowelt: return "Immowelt"
        case .kleinanzeigen: return "Kleinanzeigen"
        case .wgGesucht: return "WG-Gesucht"
        case .ohneMakler: return "Ohne-Makler"
        case .deutscheWohnen: return "Deutsche Wohnen"
        case .betterhomes: return "Betterhomes"
        case .einsAImmobilien: return "1A-Immobilienmarkt"
        case .engelVoelkers: return "Engel & Völkers"
        case .imaxx: return "Imaxx"
        case .immobilienDe: return "Immobilien.de"
        case .immoswp: return "Immo SWP"
        case .regionalimmobilien24: return "Regionalimmobilien24"
        case .schwarzesbrett: return "Schwarzes Brett Bremen"
        case .sparkasse: return "Sparkassen Immobilien"
        }
    }

    var site: String {
        switch self {
        case .immoscout: return "immobilienscout24.de"
        case .immowelt: return "immowelt.de"
        case .kleinanzeigen: return "kleinanzeigen.de"
        case .wgGesucht: return "wg-gesucht.de"
        case .ohneMakler: return "ohne-makler.net"
        case .deutscheWohnen: return "deutsche-wohnen.com"
        case .betterhomes: return "betterhomes.de"
        case .einsAImmobilien: return "1a-immobilienmarkt.de"
        case .engelVoelkers: return "engelvoelkers.com"
        case .imaxx: return "imaxx.de"
        case .immobilienDe: return "immobilien.de"
        case .immoswp: return "immo.swp.de"
        case .regionalimmobilien24: return "regionalimmobilien24.de"
        case .schwarzesbrett: return "schwarzesbrett.bremen.de"
        case .sparkasse: return "immobilien.sparkasse.de"
        }
    }

    /// No arbitrary subdomain allowance; only known canonical and www hosts.
    func accepts(host: String) -> Bool {
        let host = host.lowercased()
        return host == site || host == "www." + site
    }

    var urlHint: String {
        switch self {
        case .immoscout: return "انسخ رابط نتائج الإيجار من ImmoScout24، وليس رابط إعلان."
        case .immowelt: return "انسخ رابط classified-search مع locations و distributionTypes=Rent."
        case .kleinanzeigen: return "اختر قسم الشقق أو المنازل للإيجار وانسخ رابط النتائج."
        case .wgGesucht: return "اختر غرفًا أو شققًا للإيجار وانسخ رابط نتائج البحث."
        case .deutscheWohnen: return "انسخ رابط نتائج /mieten/mietangebote."
        case .betterhomes: return "الرابط يجب أن يحتوي على searchType=rent."
        default: return "انسخ رابط نتائج الإيجار بفلاتره كاملةً؛ رابط الإعلان الفردي غير مدعوم."
        }
    }

    func registered(in metadata: [SearchProvider]) -> Bool {
        metadata.contains { provider in
            guard provider.id == rawValue else { return false }
            if let baseUrl = provider.baseUrl, !baseUrl.isEmpty {
                guard let host = URLComponents(string: baseUrl)?.host,
                      accepts(host: host) else { return false }
            }
            return true
        }
    }
}

struct SearchProvider: Decodable, Sendable {
    let id: String
    let baseUrl: String?

    var isGermanImmoScout: Bool {
        GermanRentalProvider.immoscout.registered(in: [self])
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

/// Preserve the exact search URL for Fredy; reject URLs we cannot affirm are rentals.
enum SearchURL {
    static func validate(_ text: String, provider: GermanRentalProvider = .immoscout) throws -> String {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, value.utf8.count <= 16_384,
              !value.unicodeScalars.contains(where: { CharacterSet.whitespacesAndNewlines.union(.controlCharacters).contains($0) }),
              let components = URLComponents(string: value),
              components.scheme == "https",
              let host = components.host, provider.accepts(host: host),
              components.user == nil, components.password == nil,
              components.port == nil || components.port == 443,
              components.fragment == nil,
              components.url != nil else { throw SearchInputFailure.invalidURL }

        // Foundation may escape malformed input: never silently repair the user's URL.
        let raw = Array(value.utf8)
        for index in raw.indices where raw[index] == 37 {
            guard index + 2 < raw.count,
                  isHex(raw[index + 1]), isHex(raw[index + 2]) else {
                throw SearchInputFailure.invalidURL
            }
        }

        let segments = components.percentEncodedPath.split(separator: "/").map(String.init)
        let path = components.percentEncodedPath.lowercased()
        let query = components.percentEncodedQuery?.lowercased() ?? ""
        guard !segments.isEmpty, path != "/",
              !path.contains("/s-anzeige/"), !path.contains("/expose/"),
              !path.contains("/expose/"), !path.contains("/objekt/"),
              !path.contains("-kaufen"), !path.contains("/kaufen"),
              !query.contains("distributiontypes=buy"),
              !query.contains("searchtype=buy") else { throw SearchInputFailure.invalidURL }

        let items = components.queryItems ?? []
        func parameter(_ key: String) -> [String] {
            items.filter { $0.name.caseInsensitiveCompare(key) == .orderedSame }
                .compactMap(\.value)
        }
        let rentMarker = ["miet", "rent", "kaltmiete", "vermiet"]
        let searchable = (path + "?" + query).lowercased()
        let hasRentalSignal = rentMarker.contains { searchable.contains($0) }

        switch provider {
        case .immoscout:
            guard segments.count >= 3, segments.first == "Suche", segments[1] == "de",
                  segments.last?.hasSuffix("-mieten") == true,
                  !components.path.hasSuffix("/") else { throw SearchInputFailure.invalidURL }
            if segments.contains("radius") && !items.contains(where: { $0.name == "geocoordinates" && !($0.value ?? "").isEmpty }) {
                throw SearchInputFailure.invalidURL
            }
            if segments.contains("shape") && !items.contains(where: { $0.name == "shape" && !($0.value ?? "").isEmpty }) {
                throw SearchInputFailure.invalidURL
            }
        case .immowelt:
            guard path == "/classified-search",
                  !parameter("locations").allSatisfy({ $0.isEmpty }),
                  !parameter("distributionTypes").isEmpty,
                  parameter("distributionTypes").allSatisfy({ $0.caseInsensitiveCompare("Rent") == .orderedSame }) else {
                throw SearchInputFailure.invalidURL
            }
        case .kleinanzeigen:
            guard path.contains("wohnung-mieten") || path.contains("haus-mieten") ||
                  path.contains("wg-zimmer") || path.contains("immobilien-mieten") else {
                throw SearchInputFailure.invalidURL
            }
        case .wgGesucht:
            guard path.contains("wg-zimmer") || path.contains("wohnungen-in") ||
                  path.contains("1-zimmer-wohnungen") || path.contains("apartments-in") else {
                throw SearchInputFailure.invalidURL
            }
        case .deutscheWohnen:
            guard path.hasPrefix("/mieten/mietangebote") else { throw SearchInputFailure.invalidURL }
        case .betterhomes:
            guard parameter("searchType").contains(where: { $0.caseInsensitiveCompare("rent") == .orderedSame }) else {
                throw SearchInputFailure.invalidURL
            }
        case .engelVoelkers:
            // The .com domain is international: accept only its German-market search URLs.
            guard path.hasPrefix("/de-de/") || path.hasPrefix("/de/") ||
                  path.contains("/deutschland/") else { throw SearchInputFailure.invalidURL }
            guard hasRentalSignal else { throw SearchInputFailure.invalidURL }
        default:
            // A conservative fallback for providers whose URL dialects vary.
            // We do not infer rental intent from country/domain or dealType alone.
            guard hasRentalSignal, segments.count > 0 else { throw SearchInputFailure.invalidURL }
        }
        return value
    }

    private static func isHex(_ value: UInt8) -> Bool {
        (48...57).contains(value) || (65...70).contains(value) || (97...102).contains(value)
    }

    /// Comparison ONLY; never send the normalized form to Fredy.
    static func duplicateKey(_ text: String) -> String? {
        guard var components = URLComponents(string: text.trimmingCharacters(in: .whitespacesAndNewlines)),
              let host = components.host?.lowercased(),
              GermanRentalProvider.allCases.contains(where: { $0.accepts(host: host) }) else { return nil }
        components.host = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
        components.scheme = "https"
        if components.port == 443 { components.port = nil }
        components.fragment = nil
        components.queryItems = components.queryItems?.sorted {
            if $0.name == $1.name { return ($0.value ?? "") < ($1.value ?? "") }
            return $0.name < $1.name
        }
        return components.string
    }

    /// A label for the Scout search area, NOT a geocoded city.
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

    init(name: String, urlText: String, selectedProvider: GermanRentalProvider = .immoscout) throws {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty, cleanName.count <= 200 else { throw SearchInputFailure.nameRequired }
        let url = try SearchURL.validate(urlText, provider: selectedProvider)
        jobId = UUID().uuidString
        self.name = cleanName
        provider = [JobProvider(id: selectedProvider.rawValue, url: url)]
    }
}
