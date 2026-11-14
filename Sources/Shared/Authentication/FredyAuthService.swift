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
final class FredyAuthService: FredyAuthServing {
    private static let origin = URL(string: "https://fredy.salatiq.online")
    private let session: URLSession
    private let cookieStorage: HTTPCookieStorage?

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
        clearCookies()
        var verified = false
        defer {
            if !verified {
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

    private func perform(
        path: String,
        method: String,
        body: Data? = nil
    ) async throws -> (Data, HTTPURLResponse) {
        guard let url = Self.origin?.appendingPathComponent(path) else {
            throw LoginFailure.serverUnavailable
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        request.setValue("fredy-ios/1.0", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
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
