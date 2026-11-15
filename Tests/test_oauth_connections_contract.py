"""Stage 4.2 source contracts, not Swift execution; no grants/tokens/response fixtures."""
from pathlib import Path
import unittest
ROOT = Path(__file__).resolve().parents[1]
def source(path): return (ROOT / path).read_text()
MODEL = 'Sources/Features/Settings/OAuthConnectionsModel.swift'

class OAuthConnectionsContracts(unittest.TestCase):
    def test_exact_session_routes_and_strict_grants_without_credentials(self):
        self.assertTrue((ROOT / MODEL).exists(), 'Real OAuth grant DTO missing')
        model = source(MODEL)
        for token in ['let clientId: String', 'let clientName: String?', 'let grantedAt: Int64', 'let scopes: [String]', 'decode(String?.self, forKey: .clientName)', 'isValidClientID', 'utf8.count == 32', 'grantedAt >= 0', 'Date(timeIntervalSince1970: Double(grantedAt) / 1000)', 'Set(scopes).count == scopes.count']:
            self.assertIn(token, model)
        service = source('Sources/Shared/Authentication/FredyAuthService.swift')
        methods = service.split('func fetchOAuthConnections()', 1)[1].split('func fetchMCPSettings()', 1)[0]
        for token in ['authenticatedRead(path: "api/user/mcp-oauth-grants")', '[OAuthConnection].self', 'Set(grants.map(\\.clientId)).count == grants.count', 'OAuthConnection.isValidClientID(clientID)', 'api/user/mcp-oauth-grants/\\(clientID)', 'method: "DELETE"', 'body: nil', 'response.statusCode == 200']:
            self.assertIn(token, methods)
        self.assertEqual(service.count('URLSession('), 1)
        for forbidden in ['Bearer', 'access_token', 'refresh_token', '/authorize', '/token', '/register', 'print(', 'SavedSession', 'UserDefaults']:
            self.assertNotIn(forbidden, methods)

    def test_confirmed_revoke_uses_one_delete_and_get_only_uncertainty_recovery(self):
        text = source(MODEL)
        for token in ['final class OAuthConnectionsModel', 'func proposeRevoke(', 'func cancelProposal()', 'func confirmRevocation()', 'func reconcile()', 'fresh.first(where:', '== target else', 'attemptedWrite = true', 'service.revokeOAuthConnection(clientID: target.clientId)', 'receivedAcknowledgement = true', '!fresh.contains(where:', 'receivedAcknowledgement || !rejected', 'phase != .uncertain', 'handle(error, mayHaveCommitted: true)', 'generation += 1; sessionExpired = true', 'connections = nil; proposal = nil; pending = nil; notice = nil']:
            self.assertIn(token, text)
        self.assertEqual(text.count('service.revokeOAuthConnection('), 1)
        for method in ['func reload()', 'func confirmRevocation()', 'func reconcile()']:
            body = text.split(method, 1)[1].split('\n    func ', 1)[0]
            self.assertIn('task == nil', body)
            self.assertIn('generation == revision { task = nil }', body)
        recovery = text.split('func reconcile()', 1)[1].split('private func', 1)[0]
        self.assertNotIn('revokeOAuthConnection(', recovery)
        cancel = text.split('func cancelProposal()', 1)[1].split('func confirmRevocation()', 1)[0]
        self.assertNotIn('service.', cancel)
        self.assertNotIn('connections =', cancel)
        for forbidden in ['URLSession(', 'UserDefaults', 'print(', 'Task.sleep', 'while ', 'access_token', 'refresh_token']:
            self.assertNotIn(forbidden, text)

    def test_native_connections_page_has_explicit_confirmation_and_shared_lifetime(self):
        page = source('Sources/Features/Settings/SettingsConnectionsPage.swift')
        for token in ['let model: OAuthConnectionsModel', 'if let connections = model.connections', 'connections.isEmpty', 'ForEach(connections)', 'grant.clientId', 'grant.grantedDate', 'grant.scopes', 'case "mcp:read"', 'case "mcp:write"', 'default:', 'model.proposeRevoke(grant)', 'model.confirmRevocation()', 'model.reconcile()', '.confirmationDialog(', '.onChange(of: confirmingRevocation)', 'if !presented { model.cancelProposal() }', '.onDisappear { model.cancelProposal() }', '.task { model.reload() }']:
            self.assertIn(token, page)
        for token in ['URLSession(', 'static let connections', '.disabled(true)', 'ASWebAuthenticationSession', 'UserDefaults']:
            self.assertNotIn(token, page)
        shell = source('Sources/App/AuthenticatedTabs.swift')
        for token in ['@State private var connectionsModel: OAuthConnectionsModel', 'connectionsModel: connectionsModel', 'connectionsModel.sessionExpired', 'connectionsModel.expireSession()']:
            self.assertIn(token, shell)
        root = source('Sources/Features/Settings/RentalSettingsView.swift')
        self.assertIn('SettingsConnectionsPage(model: connectionsModel)', root)
        self.assertIn('section != .connections && section != .mcp && !model.editable', root)
        self.assertIn('section != .mcp && section != .connections { SettingsStatusBanner', root)
        self.assertIn('FredyOAuthConnectionsServing', source('Sources/Shared/Listings/RentalListing.swift'))

    def test_model_registered_in_existing_target_and_reviewed_corpus(self):
        self.assertIn(MODEL, source('FredyTest.xcodeproj/project.pbxproj'))
        import json
        scope = json.loads(source('tools/public-scope.json'))
        for field in ['files', 'graph_files']:
            self.assertIn(MODEL, scope[field])
            self.assertIn('Tests/test_oauth_connections_contract.py', scope[field])
        for p in ['Tests/validate_project.py', 'Tests/test_job_controls_contract.py']:
            self.assertIn('40)', source(p).replace(' ', ''))

    def test_grant_dates_use_arabic_formatting_without_changing_wire_milliseconds(self):
        self.assertIn('Date(timeIntervalSince1970: Double(grantedAt) / 1000)', source(MODEL))
        page = source('Sources/Features/Settings/SettingsConnectionsPage.swift')
        self.assertIn('locale(Locale(identifier: "ar"))', page)
        self.assertIn('grant.grantedDate.formatted(', page)

if __name__ == '__main__': unittest.main(verbosity=2)
