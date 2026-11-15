import Foundation

struct FredyUser: Decodable, Equatable, Sendable {
    let userId: String
    let username: String
    let isAdmin: Bool
}

enum LoginFailure: Error, Equatable {
    case missingFields
    case invalidCredentials
    case rateLimited
    case accessDenied
    case sessionNotVerified
    case serverUnavailable
    case network

    var localizationKey: String {
        switch self {
        case .missingFields: return "login.error_required"
        case .invalidCredentials: return "login.error_credentials"
        case .rateLimited: return "login.error_rate_limit"
        case .accessDenied: return "login.error_access"
        case .sessionNotVerified: return "login.error_session"
        case .serverUnavailable: return "login.error_server"
        case .network: return "login.error_network"
        }
    }
}

@MainActor
protocol FredyAuthServing {
    func signIn(username: String, password: String) async throws -> FredyUser
}

/// One isolated, memory-only cookie jar for this test client's lifetime.
/// Neither requests, response bodies, credentials nor cookie values are logged.
@MainActor
final class FredyAuthService: FredyClientServing {
    let synchronization = DataSynchronization()
    private static let origin = URL(string: "https://fredy.salatiq.online")
    private let session: URLSession
    private let cookieStorage: HTTPCookieStorage?
    private var sessionGeneration = 0
    private var sessionVerified = false

    init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpShouldSetCookies = true
        configuration.httpCookieAcceptPolicy = .always
        configuration.urlCredentialStorage = nil
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 40
        cookieStorage = configuration.httpCookieStorage
        session = URLSession(
            configuration: configuration,
            delegate: RejectRedirects(),
            delegateQueue: nil
        )
    }

    deinit {
        session.invalidateAndCancel()
    }

    func signIn(username: String, password: String) async throws -> FredyUser {
        sessionGeneration += 1
        let generation = sessionGeneration
        sessionVerified = false
        clearCookies()
        var verified = false
        defer {
            if !verified && generation == sessionGeneration {
                clearCookies()
            }
        }

        do {
            try Task.checkCancellation()
            let body = try JSONEncoder().encode(Credentials(username: username, password: password))
            let (_, response) = try await perform(path: "api/login", method: "POST", body: body)
            try validate(response, verifyingSession: false)

            guard let origin = Self.origin,
                  cookieStorage?.cookies(for: origin)?.contains(where: {
                      $0.name == "fredy-admin-session" && $0.isSecure
                  }) == true else {
                throw LoginFailure.sessionNotVerified
            }

            // A POST 200 alone is not proof: the same URLSession must send its
            // signed cookie back and receive a complete authenticated user.
            let (data, probe) = try await perform(path: "api/login/user", method: "GET")
            try validate(probe, verifyingSession: true)
            guard probe.mimeType == "application/json",
                  let user = try? JSONDecoder().decode(FredyUser.self, from: data),
                  !user.userId.isEmpty, !user.username.isEmpty else {
                throw LoginFailure.sessionNotVerified
            }
            try Task.checkCancellation()
            guard generation == sessionGeneration else { throw CancellationError() }
            sessionVerified = true
            synchronization.reset()
            verified = true
            return user
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as LoginFailure {
            throw error
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch {
            // Never surface raw response bodies, URL errors or request details.
            throw LoginFailure.network
        }
    }

    func fetchSearchProviders() async throws -> [SearchProvider] {
        let (data, response) = try await authenticatedRead(path: "api/jobs/provider/")
        guard response.mimeType == "application/json",
              let providers = try? JSONDecoder().decode([SearchProvider].self, from: data) else {
            throw ListingsFailure.invalidResponse
        }
        return providers
    }

    func fetchMCPSettings() async throws -> MCPSettingsSnapshot {
        let (data, response) = try await authenticatedRead(path: "api/user/mcp-server")
        guard response.mimeType == "application/json",
              let snapshot = try? JSONDecoder().decode(MCPSettingsSnapshot.self, from: data)
        else { throw ListingsFailure.invalidResponse }
        return snapshot
    }

    func saveMCPSettings(_ configuration: MCPConfiguration) async throws {
        let body = try JSONEncoder().encode(configuration)
        let response = try await authenticatedWrite(path: "api/user/mcp-server", body: body)
        guard response.statusCode == 200 else { throw ListingsFailure.invalidResponse }
        // POST's settings body is not persistence proof; the model performs an independent GET.
    }

    func fetchAccountSettings() async throws -> JSONValue {
        let value = try await readEditableValue(path: "api/user/settings/")
        guard let object = value.objectValue else { throw ListingsFailure.invalidResponse }
        // Do not retain unrelated account secrets/configuration from the response.
        let allowed = Set(AccountSettingKey.allCases.map(\.rawValue) + ["language"])
        return .object(object.filter { allowed.contains($0.key) })
    }

    func saveAccountSetting(_ key: AccountSettingKey, value: JSONValue) async throws {
        let body = try JSONEncoder().encode(JSONValue.object([key.rawValue: value]))
        let response = try await authenticatedWrite(path: "api/user/settings/\(key.endpoint)", body: body)
        guard response.statusCode == 200 else { throw ListingsFailure.invalidResponse }
    }

    func fetchManagedJobs() async throws -> [JSONValue] {
        let value = try await readEditableValue(path: "api/jobs/")
        guard let jobs = value.arrayValue, jobs.allSatisfy({ $0.objectValue != nil && $0["id"].stringValue?.isEmpty == false })
        else { throw ListingsFailure.invalidResponse }
        return jobs
    }

    func saveManagedJob(_ payload: JSONValue) async throws {
        guard let id = payload["jobId"].stringValue else { throw ListingsFailure.invalidInput }
        try requireListingID(id)
        let body = try JSONEncoder().encode(payload)
        let response = try await authenticatedWrite(path: "api/jobs/", body: body)
        guard response.statusCode == 200 else { throw ListingsFailure.invalidResponse }
    }

    private func readEditableValue(path: String) async throws -> JSONValue {
        let (data, response) = try await authenticatedRead(path: path)
        guard response.mimeType == "application/json",
              let value = try? JSONDecoder().decode(JSONValue.self, from: data) else { throw ListingsFailure.invalidResponse }
        return value
    }

    func createSearch(_ draft: SearchCreation) async throws {
        let body = try JSONEncoder().encode(draft)
        let response = try await authenticatedWrite(path: "api/jobs/", body: body)
        guard response.statusCode == 200 else { throw ListingsFailure.invalidResponse }
    }

    func setJobEnabled(id: String, enabled: Bool) async throws {
        guard !id.isEmpty, id.utf8.allSatisfy({
            (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) || $0 == 45 || $0 == 95
        }) else { throw ListingsFailure.invalidInput }
        let body = try JSONSerialization.data(withJSONObject: ["status": enabled])
        let response = try await authenticatedWrite(path: "api/jobs/\(id)/status", body: body, method: "PUT")
        // v31 returns an empty 200 acknowledgement, not a job object.
        guard response.statusCode == 200 else { throw ListingsFailure.invalidResponse }
    }

    func runSearch(id: String) async throws {
        guard !id.isEmpty, id.utf8.allSatisfy({
            (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) || $0 == 45 || $0 == 95
        }) else { throw ListingsFailure.invalidResponse }
        let response = try await authenticatedWrite(path: "api/jobs/\(id)/run")
        guard response.statusCode == 202 else { throw ListingsFailure.invalidResponse }
    }

    // IDs are nanoids. Validate before constructing paths; never escape/rewrite
    // a value supplied by the UI or allow path traversal.
    private func requireListingID(_ id: String) throws {
        guard !id.isEmpty, id.utf8.allSatisfy({
            (48...57).contains($0) || (65...90).contains($0) ||
            (97...122).contains($0) || $0 == 45 || $0 == 95
        }) else { throw ListingsFailure.invalidInput }
    }

    func toggleListingWatch(id: String) async throws {
        try requireListingID(id)
        let body = try JSONSerialization.data(withJSONObject: ["listingId": id])
        _ = try await authenticatedWrite(path: "api/listings/watch", body: body)
    }

    func setListingStatus(id: String, status: String?) async throws {
        try requireListingID(id)
        guard status == nil || ["applied", "rejected", "accepted"].contains(status!) else {
            throw ListingsFailure.invalidInput
        }
        let body = try JSONSerialization.data(
            withJSONObject: ["status": status.map { $0 as Any } ?? NSNull()]
        )
        _ = try await authenticatedWrite(path: "api/listings/\(id)/status", body: body)
    }

    func fetchListingApplication(id: String) async throws -> ListingApplicationDraft {
        try requireListingID(id)
        let (data, response) = try await authenticatedRead(path: "api/listings/\(id)/application")
        guard response.mimeType == "application/json", data.count < 100_000,
              let letter = try? JSONDecoder().decode(ListingApplicationDraft.self, from: data)
        else { throw ListingsFailure.invalidResponse }
        return letter
    }

    func softRemoveListing(id: String) async throws {
        try requireListingID(id)
        // Fredy's DELETE /api/listings/ supports a recoverable removal.
        // Never expose hardDelete from this compact iPhone action.
        let body = try JSONSerialization.data(
            withJSONObject: ["ids": [id], "hardDelete": false]
        )
        _ = try await authenticatedWrite(path: "api/listings/", body: body, method: "DELETE")
    }

    private func authenticatedWrite(path: String, body: Data? = nil, method: String = "POST") async throws -> HTTPURLResponse {
        try Task.checkCancellation()
        guard sessionVerified else { throw ListingsFailure.sessionExpired }
        let generation = sessionGeneration
        // Even an unacknowledged write may have committed. Reconcile by reads, never replay.
        defer { synchronization.invalidate() }
        do {
            let (_, response) = try await perform(path: path, method: method, body: body)
            try Task.checkCancellation()
            guard generation == sessionGeneration else { throw CancellationError() }
            if response.statusCode == 401 {
                sessionVerified = false
                sessionGeneration += 1
                clearCookies()
                synchronization.expire()
                throw ListingsFailure.sessionExpired
            }
            switch response.statusCode {
            case 200, 202: return response
            case 400: throw ListingsFailure.invalidInput
            case 403: throw ListingsFailure.accessDenied
            case 409: throw ListingsFailure.conflict
            case 429: throw ListingsFailure.rateLimited
            default: throw ListingsFailure.server
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch let failure as ListingsFailure {
            throw failure
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch {
            throw ListingsFailure.network
        }
    }

    func fetchDashboardSnapshot() async throws -> FindHausDashboardSnapshot {
        let (data, response) = try await authenticatedRead(path: "api/dashboard")
        guard response.mimeType == "application/json",
              let snapshot = try? JSONDecoder().decode(FindHausDashboardSnapshot.self, from: data)
        else { throw ListingsFailure.invalidResponse }
        return snapshot
    }

    func startAllSearches() async throws {
        // Exact Fredy v31 route; one user-confirmed POST, no retry or polling.
        let response = try await authenticatedWrite(path: "api/jobs/startAll")
        guard response.statusCode == 202 else { throw ListingsFailure.invalidResponse }
    }

    func fetchJobs() async throws -> [SearchJob] {
        let (data, response) = try await authenticatedRead(path: "api/jobs/")
        guard response.mimeType == "application/json",
              let jobs = try? JSONDecoder().decode([SearchJob].self, from: data) else {
            throw ListingsFailure.invalidResponse
        }
        return jobs
    }

    func fetchListings(page: Int, pageSize: Int, jobID: String? = nil) async throws -> ListingPage {
        guard page > 0, (1...1000).contains(pageSize) else { throw ListingsFailure.invalidResponse }
        var queryItems = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "pageSize", value: String(pageSize))
        ]
        if let jobID { queryItems.append(URLQueryItem(name: "jobNameFilter", value: jobID)) }
        let (data, response) = try await authenticatedRead(path: "api/listings/table", queryItems: queryItems)
        guard response.mimeType == "application/json",
              let decoded = try? JSONDecoder().decode(ListingPage.self, from: data),
              decoded.page == page, decoded.result.count <= pageSize else {
            throw ListingsFailure.invalidResponse
        }
        guard jobID == nil || decoded.result.allSatisfy({ $0.jobID == jobID }) else {
            throw ListingsFailure.invalidResponse
        }
        return decoded
    }

    func fetchMapListings(jobID: String?) async throws -> [RentalListing] {
        var query: [URLQueryItem] = []
        if let jobID {
            try requireListingID(jobID)
            query.append(URLQueryItem(name: "jobId", value: jobID))
        }
        let (data, response) = try await authenticatedRead(path: "api/listings/map", queryItems: query)
        guard response.mimeType == "application/json",
              let decoded = try? JSONDecoder().decode(MapListingEnvelope.self, from: data),
              jobID == nil || decoded.listings.allSatisfy({ $0.jobID == jobID }) else {
            throw ListingsFailure.invalidResponse
        }
        return decoded.listings
    }

    func fetchListingDetail(id: String) async throws -> RentalListing {
        try requireListingID(id)
        let (data, response) = try await authenticatedRead(path: "api/listings/\(id)")
        guard response.mimeType == "application/json",
              let decoded = try? JSONDecoder().decode(RentalListing.self, from: data),
              decoded.id == id else { throw ListingsFailure.invalidResponse }
        return decoded
    }

    func fetchListingImage(id: String) async throws -> Data {
        // Fredy IDs are nanoids. Reject path separators/escaping, never repair an ID.
        guard !id.isEmpty, id.utf8.allSatisfy({
            (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) || $0 == 45 || $0 == 95
        }) else { throw ListingsFailure.imageUnavailable }
        let (data, response) = try await authenticatedRead(path: "api/listings/\(id)/image", accept: "image/*")
        guard response.mimeType?.hasPrefix("image/") == true, !data.isEmpty,
              data.count <= 8 * 1024 * 1024 else { throw ListingsFailure.imageUnavailable }
        return data
    }

    private func authenticatedRead(
        path: String,
        queryItems: [URLQueryItem] = [],
        accept: String = "application/json"
    ) async throws -> (Data, HTTPURLResponse) {
        try Task.checkCancellation()
        guard sessionVerified else { throw ListingsFailure.sessionExpired }
        let generation = sessionGeneration
        do {
            let (data, response) = try await perform(path: path, method: "GET", queryItems: queryItems, accept: accept)
            try Task.checkCancellation()
            guard generation == sessionGeneration else { throw CancellationError() }
            if response.statusCode == 401 {
                sessionVerified = false
                sessionGeneration += 1
                clearCookies()
                synchronization.expire()
                throw ListingsFailure.sessionExpired
            }
            switch response.statusCode {
            case 200: return (data, response)
            case 403: throw ListingsFailure.accessDenied
            case 404: throw accept == "image/*" ? ListingsFailure.imageUnavailable : .server
            case 429: throw ListingsFailure.rateLimited
            default: throw ListingsFailure.server
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch let failure as ListingsFailure {
            throw failure
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch {
            throw ListingsFailure.network
        }
    }

    private func perform(
        path: String,
        method: String,
        body: Data? = nil,
        queryItems: [URLQueryItem] = [],
        accept: String = "application/json"
    ) async throws -> (Data, HTTPURLResponse) {
        guard let url = Self.origin?.appendingPathComponent(path) else {
            throw LoginFailure.serverUnavailable
        }
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw LoginFailure.serverUnavailable
        }
        if !queryItems.isEmpty { components.queryItems = queryItems }
        guard let requestURL = components.url else { throw LoginFailure.serverUnavailable }
        var request = URLRequest(url: requestURL)
        request.httpMethod = method
        request.httpBody = body
        request.setValue("fredy-ios/1.0", forHTTPHeaderField: "User-Agent")
        request.setValue(accept, forHTTPHeaderField: "Accept")
        request.setValue("no-store", forHTTPHeaderField: "Cache-Control")
        if body != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw LoginFailure.serverUnavailable
        }
        return (data, http)
    }

    private func validate(_ response: HTTPURLResponse, verifyingSession: Bool) throws {
        switch response.statusCode {
        case 200: return
        case 401:
            throw verifyingSession ? LoginFailure.sessionNotVerified : .invalidCredentials
        case 403: throw LoginFailure.accessDenied
        case 429: throw LoginFailure.rateLimited
        default: throw LoginFailure.serverUnavailable
        }
    }

    private func clearCookies() {
        for cookie in cookieStorage?.cookies ?? [] {
            cookieStorage?.deleteCookie(cookie)
        }
    }
}

private struct Credentials: Encodable {
    let username: String
    let password: String
}

/// Reject even same-origin redirects: never replay a credential-bearing POST.
private final class RejectRedirects: NSObject, URLSessionTaskDelegate {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}
