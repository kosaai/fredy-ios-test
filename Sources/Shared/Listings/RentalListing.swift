import Foundation

struct ListingPage: Decodable, Sendable {
    let totalNumber: Int
    let page: Int
    let result: [RentalListing]

    private enum CodingKeys: String, CodingKey { case totalNumber, page, result }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        totalNumber = try values.decode(Int.self, forKey: .totalNumber)
        page = try values.decode(Int.self, forKey: .page)
        result = try values.decode([RentalListing].self, forKey: .result)
        guard totalNumber >= 0, page > 0 else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Invalid page envelope"))
        }
    }
}

struct RentalListing: Decodable, Identifiable, Sendable {
    let id: String
    let title: String?
    let address: String?
    let price: Double?
    let size: Double?
    let rooms: Double?
    let currency: String?
    let dealType: String?
    let jobID: String?
    let jobName: String?
    let provider: String?
    let link: String?
    let isWatched: Bool?
    let decision: String?
    let publishedDate: Date?

    var isRental: Bool { dealType == "rent" }
    var euroPrice: Double? { currency == "EUR" ? price : nil }

    private enum CodingKeys: String, CodingKey {
        case id, title, address, price, size, rooms, currency, dealType
        case jobID = "job_id"
        case jobName = "job_name"
        case provider, link, isWatched, status
        case publishedAt = "published_at"
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(String.self, forKey: .id)
        guard !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DecodingError.dataCorruptedError(forKey: .id, in: values, debugDescription: "Missing listing identity")
        }
        title = values.optionalText(.title)
        address = values.optionalText(.address)
        price = values.optionalNumber(.price)
        size = values.optionalNumber(.size)
        rooms = values.optionalNumber(.rooms)
        currency = values.optionalText(.currency)
        dealType = values.optionalText(.dealType)
        jobID = values.optionalText(.jobID)
        jobName = values.optionalText(.jobName)
        provider = values.optionalText(.provider)
        link = values.optionalText(.link)
        if let watchNumber = try? values.decodeIfPresent(Int.self, forKey: .isWatched) {
            isWatched = watchNumber == 1
        } else {
            isWatched = try? values.decodeIfPresent(Bool.self, forKey: .isWatched)
        }
        decision = (try? values.decodeIfPresent(ListingDecisionRecord.self, forKey: .status))?.status
        let timestamp = values.optionalNumber(.publishedAt) ?? values.optionalNumber(.createdAt)
        if let timestamp, timestamp > 946_684_800_000, timestamp < 4_102_444_800_000 {
            publishedDate = Date(timeIntervalSince1970: timestamp / 1000)
        } else {
            publishedDate = nil
        }
    }
}

private extension KeyedDecodingContainer {
    func optionalText(_ key: Key) -> String? {
        guard let value = try? decodeIfPresent(String.self, forKey: key),
              !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return value
    }

    func optionalNumber(_ key: Key) -> Double? {
        if let value = try? decodeIfPresent(Double.self, forKey: key), value.isFinite, value >= 0 {
            return value
        }
        if let text = optionalText(key), let value = Double(text), value.isFinite, value >= 0 {
            return value
        }
        return nil
    }
}

enum ListingsFailure: Error, Equatable {
    case sessionExpired, accessDenied, rateLimited, server, invalidResponse, network, imageUnavailable
    case invalidInput, conflict

    var localizationKey: String {
        switch self {
        case .sessionExpired: return "listings.session_expired"
        case .accessDenied: return "listings.error_access"
        case .rateLimited: return "listings.error_rate_limit"
        case .server: return "listings.error_server"
        case .invalidResponse: return "listings.error_response"
        case .network: return "listings.error_network"
        case .imageUnavailable: return "listings.image_unavailable"
        case .invalidInput: return "jobs.error_rejected"
        case .conflict: return "jobs.error_conflict"
        }
    }
}

@MainActor
protocol FredyListingsServing {
    func fetchListings(page: Int, pageSize: Int, jobID: String?) async throws -> ListingPage
    func fetchListingImage(id: String) async throws -> Data
}

@MainActor
protocol FredyClientServing: FredyAuthServing, FredyListingsServing, FredyJobsServing, FredySearchCreating, FredyListingActionServing, FredyDashboardServing {}

private struct ListingDecisionRecord: Decodable {
    let status: String?
}

/// Exact user-facing data returned by GET /api/listings/:listingId/application.
struct ListingApplicationDraft: Decodable, Sendable {
    let text: String
    let hasProfile: Bool?
    let missing: [String]?
    let unknown: [String]?
}

/// Authenticated, explicit per-listing operations supported by the official
/// Fredy v31 API. These are not synthetic local favorites or status values.
@MainActor
protocol FredyListingActionServing {
    func toggleListingWatch(id: String) async throws
    func setListingStatus(id: String, status: String?) async throws
    func fetchListingApplication(id: String) async throws -> ListingApplicationDraft
    func softRemoveListing(id: String) async throws
}


/// Fredy's authenticated dashboard snapshot (GET /api/dashboard).
/// A missing per-day array means "unknown", not a zero count.
struct FindHausDashboardSnapshot: Decodable, Sendable {
    struct General: Decodable, Sendable {
        let interval: Double?
        let lastRun: Double?
        let nextRun: Double?
    }

    struct Trend: Decodable, Sendable {
        struct Day: Decodable, Sendable {
            let count: Int
        }
        let perDay: [Day]?
    }

    let general: General?
    let trend: Trend?

    var newToday: Int? {
        guard let count = trend?.perDay?.last?.count, count >= 0 else { return nil }
        return count
    }

    var intervalMinutes: Int? {
        guard let interval = general?.interval, interval.isFinite,
              interval > 0, interval <= Double(Int.max) else { return nil }
        return Int(interval)
    }

    var lastRunDate: Date? { date(milliseconds: general?.lastRun) }
    var nextRunDate: Date? { date(milliseconds: general?.nextRun) }

    private func date(milliseconds: Double?) -> Date? {
        guard let value = milliseconds, value.isFinite,
              value > 946_684_800_000, value < 4_102_444_800_000 else { return nil }
        return Date(timeIntervalSince1970: value / 1000)
    }
}

@MainActor
protocol FredyDashboardServing {
    func fetchDashboardSnapshot() async throws -> FindHausDashboardSnapshot
    /// Enqueue one manually requested server-side search of the user's jobs.
    /// HTTP 202 acknowledges the request, not completion or new results.
    func startAllSearches() async throws
}
