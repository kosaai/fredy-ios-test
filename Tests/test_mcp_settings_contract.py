"""Stage 4.1 offline source contracts only; no MCP invocation or account fixtures."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
def source(p): return (ROOT/p).read_text()
class MCPSettingsContracts(unittest.TestCase):
    def test_exact_cookie_authenticated_get_post_and_strict_live_catalog(self):
        service=source('Sources/Shared/Authentication/FredyAuthService.swift')
        for text in ['func fetchMCPSettings()', 'func saveMCPSettings(', 'api/user/mcp-server', 'MCPSettingsSnapshot.self', 'JSONEncoder().encode(configuration)']:
            self.assertIn(text,service)
        self.assertEqual(service.count('URLSession('),1)
        body=service.split('func saveMCPSettings(',1)[1].split('private func',1)[0]
        self.assertIn('authenticatedWrite(',body)
        self.assertIn('response.statusCode == 200',body)
        self.assertNotIn('method: "PUT"',body)
        path=ROOT/'Sources/Features/Settings/MCPSettingsModel.swift'
        self.assertTrue(path.exists())
        text=path.read_text()
        for token in ['let enabled: Bool', 'let disabledTools: [String]', 'let tools: [MCPTool]', 'let readOnly: Bool', 'Set(tools.map(\\.name))', 'isSubset(of: names)', 'DecodingError.dataCorrupted']:
            self.assertIn(token,text)
    def test_confirmed_write_checks_baseline_and_verifies_with_independent_get(self):
        text=source('Sources/Features/Settings/MCPSettingsModel.swift')
        for token in ['final class MCPSettingsModel', 'func proposeServer(', 'func proposeTool(', 'func proposeGroup(', 'func confirmChange()', 'fresh == baseline', 'attemptedWrite = true', 'service.saveMCPSettings(desired)', 'receivedAcknowledgement = true', 'confirmed.configuration == desired', 'confirmed.tools == baseline.tools', 'func reconcile()', 'mayHaveCommitted', 'generation == revision', 'func expireSession()']:
            self.assertIn(token,text)
        self.assertEqual(text.count('service.saveMCPSettings('),1)
        recovery=text.split('func reconcile()',1)[1].split('private func',1)[0]
        self.assertNotIn('saveMCPSettings(',recovery)
        self.assertIn('phase == .uncertain',recovery)
        self.assertIn('guard !sessionExpired else { return }',text)

    def test_native_page_uses_server_tools_confirmation_and_shell_lifetime(self):
        page=source('Sources/Features/Settings/SettingsMCPPage.swift')
        for token in ['let model: MCPSettingsModel', 'snapshot.tools', '.readOnly', '.confirmationDialog(', 'model.confirmChange()', 'model.cancelProposal()', 'model.proposeTool(', 'model.proposeGroup(', 'model.proposeServer(', 'model.reconcile()', 'model.reload()', 'tool.description', 'tool.name', 'onOpenConnections']:
            self.assertIn(token,page)
        self.assertNotIn('static let catalog',page)
        self.assertNotIn('CatalogTool',page)
        self.assertNotIn('URLSession(',page)
        shell=source('Sources/App/AuthenticatedTabs.swift')
        for token in ['@State private var mcpModel: MCPSettingsModel','mcpModel.sessionExpired','mcpModel.expireSession()','mcpModel: mcpModel']:
            self.assertIn(token,shell)
        root=source('Sources/Features/Settings/RentalSettingsView.swift')
        self.assertIn('SettingsMCPPage(model: mcpModel',root)
        self.assertIn('section != .mcp && !model.editable',root)

    def test_dismissing_confirmation_drops_proposal_without_a_write(self):
        page=source('Sources/Features/Settings/SettingsMCPPage.swift')
        self.assertIn('.onChange(of: confirmingChange)',page)
        self.assertIn('if !presented { model.cancelProposal() }',page)
        self.assertIn('متاحة بحسب آخر قراءة للحساب',page)
        model=source('Sources/Features/Settings/MCPSettingsModel.swift')
        cancel=model.split('func cancelProposal()',1)[1].split('func confirmChange()',1)[0]
        self.assertNotIn('saveMCPSettings(',cancel)
        self.assertNotIn('snapshot =',cancel)

    def test_uncertain_writes_stay_locked_after_rejected_readback_and_across_navigation(self):
        model=source('Sources/Features/Settings/MCPSettingsModel.swift')
        self.assertIn('receivedAcknowledgement || !rejected',model)
        self.assertIn('handle(error, mayHaveCommitted: true)',model)
        self.assertIn('phase != .uncertain',model.split('func reload()',1)[1].split('func proposeServer(',1)[0])
        self.assertIn('generation += 1; sessionExpired = true',model)
        self.assertIn('snapshot = nil; proposal = nil; pending = nil; notice = nil',model)
        for method in ['func reload()', 'func confirmChange()', 'func reconcile()']:
            body=model.split(method,1)[1].split('\n    func ',1)[0]
            self.assertIn('task == nil',body)
            self.assertIn('generation == revision { task = nil }',body)
        self.assertIn('snapshot = confirmed; pending = nil; phase = .verified',model)

    def test_permission_changes_do_not_invoke_tools_grant_oauth_or_assume_catalog_defaults(self):
        model=source('Sources/Features/Settings/MCPSettingsModel.swift')
        for token in ['try values.decode(Bool.self, forKey: .enabled)', 'try values.decode([String].self, forKey: .disabledTools)', 'try values.decode([MCPTool].self, forKey: .tools)', 'names.count == tools.count', 'Set(disabledTools).count == disabledTools.count']:
            self.assertIn(token,model)
        self.assertIn('configuration.disabledTools',model.split('func proposeServer(',1)[1].split('func proposeTool(',1)[0])
        service=source('Sources/Shared/Authentication/FredyAuthService.swift')
        transport=service.split('func fetchMCPSettings()',1)[1].split('func fetchAccountSettings()',1)[0]
        for forbidden in ['/api/mcp', '/oauth', '/grants', 'Bearer', 'userId', 'disabledTools: []', 'enabled: true', 'print(', 'URLSession(']:
            self.assertNotIn(forbidden,transport)
        for forbidden in ['runSearch(', 'startAllSearches(', 'delete', 'UserDefaults', 'URLSession(', 'while ', 'Task.sleep']:
            self.assertNotIn(forbidden,model)

    def test_new_mcp_source_is_registered_in_the_existing_target_and_public_corpus(self):
        path='Sources/Features/Settings/MCPSettingsModel.swift'
        self.assertIn(path,source('FredyTest.xcodeproj/project.pbxproj'))
        import json
        scope=json.loads(source('tools/public-scope.json'))
        self.assertIn(path,scope['files'])
        self.assertIn(path,scope['graph_files'])
        self.assertIn('Tests/test_mcp_settings_contract.py',scope['files'])

if __name__=='__main__': unittest.main(verbosity=2)
