import Foundation
import Observation

enum LoginState: Equatable {
    case idle
    case restoring
    case loading
    case failed(LoginFailure)
    case authenticated(FredyUser)
}

@Observable
@MainActor
final class LoginModel {
    var username = ""
    var password = ""
    private(set) var state: LoginState = .restoring
    @ObservationIgnored let service: any FredyClientServing

    init() {
        service = FredyAuthService()
    }

    init(service: any FredyClientServing) {
        self.service = service
    }

    var isLoading: Bool { state == .loading }

    var canSubmit: Bool {
        !isLoading && !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !password.isEmpty
    }

    func restoreSession() async {
        guard state == .restoring else { return }
        do {
            if let user = try await service.restoreSession() {
                try Task.checkCancellation()
                state = .authenticated(user)
            } else {
                state = .idle
            }
        } catch is CancellationError {
            state = .idle
        } catch let failure as LoginFailure {
            state = .failed(failure)
        } catch {
            state = .failed(.network)
        }
    }

    func returnToLogin() {
        username = ""
        password = ""
        state = .failed(.sessionNotVerified)
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
