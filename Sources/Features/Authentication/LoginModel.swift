import Foundation
import Observation

enum LoginState: Equatable {
    case idle
    case loading
    case failed(LoginFailure)
    case authenticated(FredyUser)
}

@Observable
@MainActor
final class LoginModel {
    var username = ""
    var password = ""
    private(set) var state: LoginState = .idle
    @ObservationIgnored private let service: any FredyAuthServing

    init() {
        service = FredyAuthService()
    }

    init(service: any FredyAuthServing) {
        self.service = service
    }

    var isLoading: Bool { state == .loading }

    var canSubmit: Bool {
        !isLoading && !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !password.isEmpty
    }

    func signIn() async {
        guard !isLoading else { return }
        let submittedUsername = username
        let submittedPassword = password
        password = ""
        guard !submittedUsername.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !submittedPassword.isEmpty else {
            state = .failed(.missingFields)
            return
        }
        state = .loading
        do {
            let user = try await service.signIn(username: submittedUsername, password: submittedPassword)
            try Task.checkCancellation()
            state = .authenticated(user)
        } catch is CancellationError {
            state = .idle
        } catch let error as LoginFailure {
            state = .failed(error)
        } catch {
            state = .failed(.network)
        }
    }
}
