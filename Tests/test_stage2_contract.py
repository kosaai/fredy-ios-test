"""Offline source contracts, not executed Swift or live persisted-settings evidence."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
class StageTwoContracts(unittest.TestCase):
    def test_same_session_verified_settings_and_full_job_transport(self):
        service=(ROOT/'Sources/Shared/Authentication/FredyAuthService.swift').read_text()
        for token in ['func fetchAccountSettings(', 'func saveAccountSetting(', 'func fetchManagedJobs(', 'func saveManagedJob(', 'api/user/settings/', 'key.endpoint']:
            self.assertTrue(token in service,token)
        self.assertEqual(service.count('URLSession('),1)
        data=ROOT/'Sources/Shared/Settings/JSONValue.swift'
        self.assertTrue(data.exists())
        text=data.read_text()
        for token in ['case object([String: JSONValue])','case number(Decimal)','listing-deletion-preference','provider-details','home-address','applicant-profile','application-templates']:
            self.assertTrue(token in text,token)
    def test_settings_save_is_scoped_conflict_checked_and_read_back(self):
        path=ROOT/'Sources/Features/Settings/AccountSettingsModel.swift'
        self.assertTrue(path.exists(),'Settings coordinator missing')
        text=path.read_text()
        for token in ['fresh[key.rawValue] == baseline', 'pending = (key, desired)', 'service.saveAccountSetting(', 'func reconcile(', 'func matches(', 'case .home_addresses:', 'hardDelete', 'Task.checkCancellation()', 'expire()']:
            self.assertTrue(token in text,token)
        self.assertEqual(text.count('service.saveAccountSetting('),1)
        recovery=text.split('func reconcile(',1)[1].split('private func',1)[0]
        self.assertNotIn('saveAccountSetting(',recovery)

    def test_settings_ui_is_bound_to_account_data_not_local_placeholders(self):
        root=(ROOT/'Sources/Features/Settings/RentalSettingsView.swift').read_text()
        for token in ['AccountSettingsModel', 'model.loadIfNeeded()', 'SettingsSaveControl', 'model.reconcile()']:
            self.assertTrue(token in root,token)
        for filename,key in [('SettingsPreferencesPage.swift','listing_deletion_preference'),('SettingsTravelTimePage.swift','home_addresses'),('SettingsListingDetailsPage.swift','provider_details'),('SettingsApplicationPage.swift','applicant_profile')]:
            text=(ROOT/'Sources/Features/Settings'/filename).read_text()
            self.assertTrue('let model: AccountSettingsModel' in text,filename)
            self.assertTrue(key in text,filename)
            self.assertNotIn('هذه الحقول فارغة عمدًا',text)
        shell=(ROOT/'Sources/App/AuthenticatedTabs.swift').read_text()
        self.assertTrue('settingsModel.sessionExpired' in shell)

    def test_edit_and_duplicate_preserve_full_documents_without_replay(self):
        path=ROOT/'Sources/Features/Jobs/JobManagementModel.swift'
        self.assertTrue(path.exists(),'Job management coordinator missing')
        text=path.read_text()
        for token in ['shared_with_user', 'shareWithUsers', 'configuredAdapterId', 'spatialFilter', 'specFilter', 'commuteFilter', 'sourceBaseline', 'hasAttemptedWrite = true', 'service.saveManagedJob(', 'UUID().uuidString', 'case .sessionExpired', 'func reconcile(', 'func writable(']:
            self.assertTrue(token in text,token)
        self.assertEqual(text.count('service.saveManagedJob('),1)
        self.assertNotIn('runSearch(',text)
        self.assertNotIn('DELETE',text)
        self.assertTrue('desired["enabled"] = .bool(false)' in text)
        self.assertTrue('fresh.contains(where:' in text)

    def test_jobs_editor_is_shell_owned_and_only_confirmed_buttons_write(self):
        source=(ROOT/'Sources/Features/Jobs/JobsView.swift').read_text()
        for token in ['model.openManagement(id: job.id, duplicate: false)', 'model.openManagement(id: job.id, duplicate: true)', '.sheet(item:', 'JobManagementView(model:']:
            self.assertTrue(token in source,token)
        path=ROOT/'Sources/Features/Jobs/JobManagementView.swift'
        self.assertTrue(path.exists())
        text=path.read_text()
        for token in ['.confirmationDialog(', 'model.save()', 'model.reconcile()', 'model.loadIfNeeded()', '.leftToRight']:
            self.assertTrue(token in text,token)
        state=(ROOT/'Sources/Features/Jobs/JobsModel.swift').read_text()
        self.assertTrue('private(set) var management: JobManagementModel?' in state)
        self.assertTrue('management?.blocksWrites != true' in state)

    def test_readback_failures_cannot_turn_uncertain_writes_into_retryable_rejections(self):
        settings=(ROOT/'Sources/Features/Settings/AccountSettingsModel.swift').read_text()
        jobs=(ROOT/'Sources/Features/Jobs/JobManagementModel.swift').read_text()
        self.assertTrue('mayHaveCommitted: acknowledged' in settings)
        self.assertTrue('mayHaveCommitted: true' in settings)
        self.assertTrue('mayHaveCommitted || uncertain' in settings)
        self.assertTrue('receivedAcknowledgement || uncertaintyLocked' in jobs)
        self.assertTrue('uncertaintyLocked = true' in jobs)

    def test_new_sources_are_registered_and_unsafe_defaults_are_not_written(self):
        project=(ROOT/'FredyTest.xcodeproj/project.pbxproj').read_text()
        for name in ['JSONValue.swift','AccountSettingsModel.swift','JobManagementModel.swift','JobManagementView.swift']:
            self.assertTrue(name in project,name)
        settings=(ROOT/'Sources/Features/Settings/AccountSettingsModel.swift').read_text()
        self.assertTrue('value["hardDelete"] == .bool(false)' in settings)
        flags=settings.split('func profileFlag(',1)[1]
        self.assertTrue('.bool(value == "yes")' in flags)
        self.assertNotIn('application-preview', (ROOT/'Sources/Shared/Authentication/FredyAuthService.swift').read_text())

    def test_saving_one_setting_keeps_dirty_other_sections_original_baselines(self):
        text=(ROOT/'Sources/Features/Settings/AccountSettingsModel.swift').read_text()
        accept=text.split('private func accept(',1)[1].split('private func handle(',1)[0]
        self.assertTrue('nextSaved[field.rawValue] = baseline' in accept)
        self.assertTrue('saved = nextSaved' in accept)

    def test_provider_options_cannot_be_dropped_by_an_editor_url_change(self):
        text=(ROOT/'Sources/Features/Jobs/JobManagementModel.swift').read_text()
        self.assertTrue('var preserved = oldProviders[index]' in text)
        self.assertTrue('preserved["url"] = entry["url"]' in text)
        self.assertTrue('entry == preserved' in text)

    def test_confirmed_light_theme_overrides_system_dark_without_using_draft(self):
        text=(ROOT/'Sources/App/AuthenticatedTabs.swift').read_text()
        self.assertTrue('.preferredColorScheme(accountColorScheme)' in text)
        section=text.split('private var accountColorScheme',1)[1].split('@ToolbarContentBuilder',1)[0]
        self.assertTrue('settingsModel.saved["theme"]' in section)
        self.assertTrue('case "light": return .light' in section)
        self.assertNotIn('draft',section)

    def test_clearing_addresses_verifies_the_actual_absent_setting_representation(self):
        text=(ROOT/'Sources/Features/Settings/AccountSettingsModel.swift').read_text()
        matches=text.split('private func matches(',1)[1].split('private func validate(',1)[0]
        self.assertTrue('left.isEmpty && actual == .null' in matches)

    def test_travel_category_controls_keep_arabic_titles_and_real_ids(self):
        text=(ROOT/'Sources/Features/Settings/SettingsTravelTimePage.swift').read_text()
        self.assertTrue('"supermarket": "سوبرماركت"' in text)
        self.assertTrue('Text(Self.categoryTitles[id] ?? id).tag(id)' in text)

    def test_saved_theme_is_reloaded_with_the_authenticated_shell(self):
        text=(ROOT/'Sources/App/AuthenticatedTabs.swift').read_text()
        self.assertTrue('await jobsModel.loadIfNeeded()\n                await settingsModel.loadIfNeeded()' in text)

if __name__=='__main__':unittest.main(verbosity=2)
