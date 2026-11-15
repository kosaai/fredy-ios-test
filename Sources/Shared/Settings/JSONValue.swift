import Foundation

/// Lossless object/array edits preserve unedited provider/filter/profile fields.
/// Runtime account documents are memory-only and are never logged or persisted here.
indirect enum JSONValue: Codable, Equatable, Sendable {
    case object([String: JSONValue])
    case array([JSONValue])
    case string(String)
    case number(Decimal)
    case bool(Bool)
    case null

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let v = try? c.decode(Bool.self) { self = .bool(v) }
        else if let v = try? c.decode(String.self) { self = .string(v) }
        else if let v = try? c.decode([String: JSONValue].self) { self = .object(v) }
        else if let v = try? c.decode([JSONValue].self) { self = .array(v) }
        else { self = .number(try c.decode(Decimal.self)) }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .object(let v): try c.encode(v)
        case .array(let v): try c.encode(v)
        case .string(let v): try c.encode(v)
        case .number(let v): try c.encode(v)
        case .bool(let v): try c.encode(v)
        case .null: try c.encodeNil()
        }
    }

    subscript(_ key: String) -> JSONValue {
        get { objectValue?[key] ?? .null }
        set { var value = objectValue ?? [:]; value[key] = newValue; self = .object(value) }
    }
    var objectValue: [String: JSONValue]? { if case .object(let v) = self { return v }; return nil }
    var arrayValue: [JSONValue]? { if case .array(let v) = self { return v }; return nil }
    var stringValue: String? { if case .string(let v) = self { return v }; return nil }
    var boolValue: Bool? { if case .bool(let v) = self { return v }; return nil }
}

enum AccountSettingKey: String, CaseIterable {
    case theme, listing_deletion_preference, home_addresses, provider_details
    case blacklist_filter_on_provider_details, applicant_profile, application_templates
    var endpoint: String {
        switch self {
        case .theme: return "theme"
        case .listing_deletion_preference: return "listing-deletion-preference"
        case .home_addresses: return "home-address"
        case .provider_details: return "provider-details"
        case .blacklist_filter_on_provider_details: return "blacklist-filter-on-details"
        case .applicant_profile: return "applicant-profile"
        case .application_templates: return "application-templates"
        }
    }
}

@MainActor
protocol FredyAccountSettingsServing {
    func fetchAccountSettings() async throws -> JSONValue
    func saveAccountSetting(_ key: AccountSettingKey, value: JSONValue) async throws
}

@MainActor
protocol FredyJobManagementServing {
    func fetchManagedJobs() async throws -> [JSONValue]
    func saveManagedJob(_ payload: JSONValue) async throws
}
