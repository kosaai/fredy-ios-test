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
        for required in ['LoginView', 'AuthenticatedTabs', '.rightToLeft', 'Locale(identifier: "ar")']:
            self.assertIn(required, root)
        self.assertIn('user.username', success)
        for source in [model, view, success]:
            for forbidden in ['URLSession', 'UserDefaults', 'print(', 'debugPrint(', 'Logger(']:
                self.assertNotIn(forbidden, source)

    def test_animated_auth_design_does_not_fake_registration_or_social_login(self):
        view = (ROOT / "Sources/Features/Authentication/LoginView.swift").read_text()
        for required in [
            "matchedGeometryEffect", "withAnimation", "accessibilityReduceMotion",
            "signInFields", "signUpFields", "register.submit", "SecureField",
            "login.username", "login.password", "await model.signIn()",
            ".disabled(true)", "لا يدعم الخادم التسجيل الذاتي",
        ]:
            self.assertIn(required, view)
        for forbidden in [
            "createUser(", "registerUser(", "GoogleSignIn", "ASAuthorization",
            "URLSession(", "UserDefaults", "WKWebView",
        ]:
            self.assertNotIn(forbidden, view)

    def test_auth_mode_switch_keeps_card_top_anchored(self):
        view = (ROOT / "Sources/Features/Authentication/LoginView.swift").read_text()
        self.assertIn(".frame(minHeight: geometry.size.height, alignment: .top)", view)
        self.assertIn(".frame(maxWidth: .infinity, alignment: .top)", view)
        self.assertIn(".padding(.top, 18)", view)
        self.assertNotIn("Spacer(minLength: 18)", view)
        self.assertNotIn("Spacer(minLength: 10)", view)
        self.assertIn('matchedGeometryEffect(id: "activeMode"', view)
        self.assertIn("withAnimation(reduceMotion ? nil : .spring", view)
        self.assertIn("await model.signIn()", view)

    def test_auth_forms_do_not_slide_over_logo_or_overlap_when_switching(self):
        view = (ROOT / "Sources/Features/Authentication/LoginView.swift").read_text()
        form_region = view.split("if mode == .signIn {", 1)[1].split("footer", 1)[0]
        self.assertEqual(form_region.count("insertion: .opacity"), 2)
        self.assertEqual(form_region.count("removal: .identity"), 2)
        self.assertNotIn(".move(edge:", form_region)
        self.assertIn(".clipShape(UnevenRoundedRectangle(", view)
        self.assertIn(".padding(.top, -48)", view)
        self.assertIn('matchedGeometryEffect(id: "activeMode"', view)
        self.assertIn("withAnimation(reduceMotion ? nil : .spring(response: 0.52, dampingFraction: 0.83))", view)
        self.assertIn(".frame(minHeight: geometry.size.height, alignment: .top)", view)

    def test_login_restores_only_a_server_verified_protected_session(self):
        service = (ROOT / "Sources/Shared/Authentication/FredyAuthService.swift").read_text()
        model = (ROOT / "Sources/Features/Authentication/LoginModel.swift").read_text()
        root = (ROOT / "Sources/App/AppRootView.swift").read_text()
        for required in [
            "import Security", "SecItemAdd", "SecItemUpdate", "SecItemCopyMatching",
            "SecItemDelete", "kSecAttrAccessibleWhenUnlockedThisDeviceOnly",
            "kSecAttrSynchronizable", "SavedSession.save(", "SavedSession.load(",
            "SavedSession.clear()", "fredy-admin-session.sig",
            'perform(path: "api/login/user", method: "GET")',
            "func restoreSession() async throws -> FredyUser?"
        ]:
            self.assertIn(required, service)
        self.assertIn("case restoring", model)
        self.assertIn("private(set) var state: LoginState = .restoring", model)
        self.assertIn("if let user = try await service.restoreSession()", model)
        self.assertIn("else if case .restoring = model.state", root)
        self.assertIn(".task { await model.restoreSession() }", root)
        self.assertNotIn("UserDefaults", service)
        self.assertNotIn("HTTPCookieStorage.shared", service)

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
        for forbidden in ['HTTPCookieStorage.shared', 'URLSession.shared', 'UserDefaults', 'print(', 'debugPrint(', 'Logger(']:
            self.assertNotIn(forbidden, source)
        self.assertNotRegex(source, r'password\s*[:=]\s*"[^"\n]+"')
        self.assertNotRegex(source, r'setValue\([^\n]+forHTTPHeaderField:\s*"(?:Cookie|Authorization)"')


if __name__ == "__main__":
    unittest.main(verbosity=2)
