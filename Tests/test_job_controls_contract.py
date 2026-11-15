"""Source gates only: no live mutations, fake accounts/listings or Swift runtime claims."""
from pathlib import Path
import unittest
ROOT = Path(__file__).resolve().parents[1]

class JobControlsContract(unittest.TestCase):
    def test_verified_put_bool_and_shared_permission_contract(self):
        service=(ROOT/'Sources/Shared/Authentication/FredyAuthService.swift').read_text()
        self.assertTrue('func setJobEnabled(id: String, enabled: Bool)' in service, 'Exact enabled write is missing')
        body=service.split('func setJobEnabled(',1)[1].split('func runSearch(',1)[0]
        for token in ['"status": enabled', 'api/jobs/\\(id)/status', 'method: "PUT"', 'response.statusCode == 200']:
            self.assertTrue(token in body, token)
        self.assertNotIn('decode(',body)  # The actual acknowledgement is empty.
        self.assertEqual(service.count('URLSession('),1)
        dto=(ROOT/'Sources/Shared/Jobs/SearchJob.swift').read_text()
        for token in ['let isOnlyShared: Bool?', 'forKey: .isOnlyShared', 'func setJobEnabled(', 'func runSearch(']:
            self.assertTrue(token in dto,token)
        self.assertNotIn('isOnlyShared = false',dto)

    def test_job_actions_require_explicit_intent_and_confirmed_readback(self):
        source=(ROOT/'Sources/Features/Jobs/JobsModel.swift').read_text()
        for token in ['func requestRun(', 'func requestEnabledChange(', 'pendingAction == nil',
                      'job.isOnlyShared == false', 'job.running == false', 'job.enabled != nil',
                      'writeAttempted = true', 'runAccepted = true', 'service.runSearch(id:',
                      'service.setJobEnabled(id:', 'confirmed.enabled == enabled',
                      'requiresRefresh.insert(id)', 'Task.checkCancellation()', 'case .sessionExpired:']:
            self.assertTrue(token in source,token)
        self.assertEqual(source.count('service.runSearch(id:'),1)
        self.assertEqual(source.count('service.setJobEnabled(id:'),1)
        action=source.split('private func performControl(',1)[1]
        self.assertNotIn('startAll',action)
        self.assertNotIn('Task.sleep',action)
        self.assertNotIn('jobs[index]',action)

    def test_existing_controls_use_confirmed_model_not_design_placeholders(self):
        source=(ROOT/'Sources/Features/Jobs/JobsView.swift').read_text()
        for token in ['.confirmationDialog(', 'model.requestRun(id: job.id)',
                      'model.requestEnabledChange(id: job.id, enabled: enabled)',
                      '.disabled(!model.canRun(job))', '.disabled(!model.canChangeEnabled(job))',
                      'model.actionNotices[job.id]', 'model.pendingAction?.id == job.id',
                      '.environment(\\.layoutDirection, .rightToLeft)']:
            self.assertTrue(token in source,token)
        self.assertNotIn('Button { showDesignNotice = true } label: {\n                    Image(systemName: "play.fill")',source)
        self.assertEqual(source.count('Button(action: showDesignNotice)'),0)  # Stage 2 wires edit/copy; delete previews stay below.
        self.assertIn('model.openManagement(id: job.id, duplicate: false)',source)
        self.assertIn('model.openManagement(id: job.id, duplicate: true)',source)
        self.assertEqual(source.count('Button(role: .destructive, action: showDesignNotice)'),2)

    def test_no_notification_side_effects_from_new_controls(self):
        dto=(ROOT/'Sources/Shared/Jobs/SearchJob.swift').read_text()
        model=(ROOT/'Sources/Features/Jobs/JobsModel.swift').read_text()
        for token in ['let hasNoNotificationChannels: Bool?', 'nestedUnkeyedContainer(forKey: .notificationAdapter)', '.isAtEnd']:
            self.assertTrue(token in dto,token)
        self.assertTrue('job.hasNoNotificationChannels == true' in model)
        self.assertTrue('guard current.hasNoNotificationChannels == true' in model)
        self.assertTrue('guard !enabled || current.hasNoNotificationChannels == true' in model)
        self.assertTrue('notificationChannelsNotAllowed' in model)

    def test_native_syntax_membership_branding_and_localization(self):
        import hashlib, json, re, struct
        from tree_sitter import Language, Parser
        import tree_sitter_swift
        from openstep_parser import OpenStepDecoder
        parser=Parser(Language(tree_sitter_swift.language()))
        files=sorted((ROOT/'Sources').rglob('*.swift'))
        self.assertEqual(len(files),39)
        for p in files:
            self.assertFalse(parser.parse(p.read_bytes()).root_node.has_error,str(p.relative_to(ROOT)))
        with (ROOT/'FredyTest.xcodeproj/project.pbxproj').open() as f:
            pbx=OpenStepDecoder.ParseFromFile(f)
        objects=pbx['objects']
        refs={v['fileRef'] for v in objects.values() if v['isa']=='PBXBuildFile'}
        compiled={objects[r]['path'] for r in refs if objects[r].get('lastKnownFileType')=='sourcecode.swift'}
        self.assertEqual(compiled,{str(p.relative_to(ROOT)) for p in files})
        source='\n'.join(p.read_text() for p in files)
        source=re.sub(r'\.accessibilityIdentifier\("[^\"]+"\)', '',source)
        keys=set(re.findall(r'"((?:home|about|login|listings|jobs|tabs)\.[a-z_]+)"',source))
        catalog=json.loads((ROOT/'Resources/Localizable.xcstrings').read_text())['strings']
        for key in keys:
            for locale in ['ar','en']:
                unit=catalog[key]['localizations'][locale]['stringUnit']
                self.assertEqual(unit['state'],'translated')
                self.assertTrue(unit['value'])
        for name in ['AppIcon.appiconset','BrandLogo.imageset']:
            data=(ROOT/'Resources/FindHausAssets.xcassets'/name/'FindHausIcon.png').read_bytes()
            self.assertEqual(data[:8],bytes([137,80,78,71,13,10,26,10]))
            self.assertEqual(struct.unpack('>II',data[16:24]),(1024,1024))
            self.assertEqual(hashlib.sha256(data).hexdigest(),'498f0da9ca74fa240e8dcb53f790e38adac0dcc53c4134a4020c05b32a66c6ce')

if __name__ == '__main__': unittest.main(verbosity=2)
