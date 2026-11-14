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

    var isRental: Bool { dealType == "rent" }
    var euroPrice: Double? { currency == "EUR" ? price : nil }

    private enum CodingKeys: String, CodingKey {
        case id, title, address, price, size, rooms, currency, dealType
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

    var localizationKey: String {
        switch self {
        case .sessionExpired: return "listings.session_expired"
        case .accessDenied: return "listings.error_access"
        case .rateLimited: return "listings.error_rate_limit"
        case .server: return "listings.error_server"
        case .invalidResponse: return "listings.error_response"
        case .network: return "listings.error_network"
        case .imageUnavailable: return "listings.image_unavailable"
        }
    }
}

@MainActor
protocol FredyListingsServing {
    func fetchListings(page: Int, pageSize: Int) async throws -> ListingPage
    func fetchListingImage(id: String) async throws -> Data
}

@MainActor
protocol FredyClientServing: FredyAuthServing, FredyListingsServing, FredyJobsServing {}
