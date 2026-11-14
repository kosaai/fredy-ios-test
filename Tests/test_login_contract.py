"""Executable source-contract checks; these do NOT execute Swift/URLSession."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]


class LoginSourceContract(unittest.TestCase):
    def test_arabic_login_has_secure_input_and_loading_error_success_states(self):
        paths = [ROOT / "Sources/Features/Authentication" / name for name in ["LoginModel.swift", "LoginView.swift", "AuthenticatedView.swift"]]
        self.assertTrue(all(p.exists() for p in paths), "Native authentication UI is missing")
        model, view, success = [p.read_text() for p in paths]
        for required in ['@Observable', '@MainActor', 'case loading', 'case failed', 'case authenticated', 'password = ""', 'Task.checkCancellation()', 'guard !isLoading']:
            self.assertIn(required, model)
        self.assertLess(model.index('password = ""', model.index('func signIn()')), model.index('try await service.signIn'))
        self.assertIn('catch is CancellationError', model)
        for required in ['SecureField', 'TextField', '.username', '.password', 'ProgressView', '.failed', '.disabled(model.isLoading)', '.textInputAutocapitalization(.never)']:
            self.assertIn(required, view)
        root = (ROOT / "Sources/App/AppRootView.swift").read_text()
        for required in ['LoginView', 'ListingsView', '.rightToLeft', 'Locale(identifier: "ar")']:
            self.assertIn(required, root)
        self.assertIn('user.username', success)
        for source in [model, view, success]:
            for forbidden in ['URLSession', 'UserDefaults', 'print(', 'debugPrint(', 'Logger(']:
                self.assertNotIn(forbidden, source)

    def test_session_service_verifies_cookie_and_user_before_success(self):
        path = ROOT / "Sources/Shared/Authentication/FredyAuthService.swift"
        self.assertTrue(path.exists(), "Fredy session service has not been implemented")
        source = path.read_text()
        for required in ['URLSessionConfiguration.ephemeral', 'fredy-ios/1.0', 'https://fredy.salatiq.online', 'api/login', 'api/login/user', 'fredy-admin-session', 'isSecure', 'JSONEncoder', 'JSONDecoder', 'cookies(for:', 'httpCookieStorage', 'urlCredentialStorage = nil', 'urlCache = nil', 'willPerformHTTPRedirection', 'completionHandler(nil)']:
            self.assertIn(required, source)
        for required in ['let userId: String', 'let username: String', 'let isAdmin: Bool', 'decode(FredyUser.self', '!user.userId.isEmpty, !user.username.isEmpty', 'probe.mimeType == "application/json"', 'defer {', 'case 401:', 'case 403:', 'case 429:']:
            self.assertIn(required, source)
        self.assertLess(source.index('path: "api/login"'), source.index('path: "api/login/user"'))
        self.assertIn('Task.checkCancellation()', source)
        for forbidden in ['HTTPCookieStorage.shared', 'URLSession.shared', 'UserDefaults', 'print(', 'debugPrint(', 'Logger(', '/api/jobs']:
            self.assertNotIn(forbidden, source)
        self.assertNotRegex(source, r'password\s*[:=]\s*"[^"\n]+"')
        self.assertNotRegex(source, r'setValue\([^\n]+forHTTPHeaderField:\s*"(?:Cookie|Authorization)"')


if __name__ == "__main__":
    unittest.main(verbosity=2)
