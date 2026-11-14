import Foundation

struct SearchJob: Decodable, Identifiable, Sendable {
    let id: String
    let name: String?
    let enabled: Bool?
    let running: Bool?
    let numberOfFoundListings: Int?
    let provider: [JobProvider]?
    let dealType: String?
    let lastRunAt: Double?

    var regionLabel: String? {
        guard let provider, !provider.isEmpty else { return nil }
        let labels = provider.compactMap { SearchURL.regionLabel($0.url) }
        guard labels.count == provider.count else { return nil }
        let unique = Set(labels)
        return unique.count == 1 ? unique.first : nil
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, enabled, running, numberOfFoundListings, provider, dealType, lastRunAt
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(String.self, forKey: .id)
        guard !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DecodingError.dataCorruptedError(forKey: .id, in: values, debugDescription: "Missing job identity")
        }
        let text = try? values.decodeIfPresent(String.self, forKey: .name)
        name = text.flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
        // The actual REST mapper emits Booleans, not SQLite's integer flags.
        // Missing/null/wrong types remain unknown, never silently false.
        enabled = try? values.decodeIfPresent(Bool.self, forKey: .enabled)
        running = try? values.decodeIfPresent(Bool.self, forKey: .running)
        provider = try? values.decodeIfPresent([JobProvider].self, forKey: .provider)
        dealType = try? values.decodeIfPresent(String.self, forKey: .dealType)
        if let timestamp = try? values.decodeIfPresent(Double.self, forKey: .lastRunAt), timestamp.isFinite, timestamp >= 0 {
            lastRunAt = timestamp
        } else {
            lastRunAt = nil
        }
        if let count = try? values.decodeIfPresent(Int.self, forKey: .numberOfFoundListings), count >= 0 {
            numberOfFoundListings = count
        } else {
            numberOfFoundListings = nil
        }
    }
}

@MainActor
protocol FredyJobsServing {
    func fetchJobs() async throws -> [SearchJob]
}

@MainActor
protocol FredySearchCreating {
    func fetchSearchProviders() async throws -> [SearchProvider]
    func createSearch(_ draft: SearchCreation) async throws
    func runSearch(id: String) async throws
}
