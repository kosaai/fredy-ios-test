import Foundation

struct SearchJob: Decodable, Identifiable, Sendable {
    let id: String
    let name: String?
    let enabled: Bool?
    let running: Bool?
    let numberOfFoundListings: Int?

    private enum CodingKeys: String, CodingKey {
        case id, name, enabled, running, numberOfFoundListings
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
