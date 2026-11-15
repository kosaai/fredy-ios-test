"""Source contract gates only; never Swift runtime or live job mutations."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]

class AddSearchContract(unittest.TestCase):
    def test_explicit_single_create_and_run_are_verified_without_replay(self):
        path = ROOT / 'Sources/Features/Jobs/AddSearchModel.swift'
        self.assertTrue(path.is_file(), 'Save & Search coordinator is missing')
        source = path.read_text()
        for token in ['hasAttemptedCreate', 'hasAttemptedRun', 'service.fetchJobs()',
                      'service.fetchSearchProviders()', 'service.createSearch(',
                      'service.runSearch(', 'verifyCreatedJob', 'Task.checkCancellation()',
                      'duplicateURL', 'case uncertain', 'lastRunAt', 'providerOutcomeUnknown']:
            self.assertIn(token, source)
        self.assertEqual(source.count('service.createSearch('), 1)
        self.assertEqual(source.count('service.runSearch('), 1)
        self.assertLess(source.index('hasAttemptedCreate = true'), source.index('service.createSearch('))
        self.assertLess(source.index('hasAttemptedRun = true'), source.index('service.runSearch('))
        service = (ROOT / 'Sources/Shared/Authentication/FredyAuthService.swift').read_text()
        for token in ['func createSearch(', 'func runSearch(', 'api/jobs/provider/',
                      'authenticatedWrite', 'method: "POST"', 'statusCode == 202']:
            self.assertIn(token, service)
        self.assertEqual(service.count('URLSession('), 1)
        self.assertNotIn('startAll', service)
        self.assertNotIn('provider_details', service)

    def test_arabic_form_is_explicit_and_shell_owns_inflight_work(self):
        path = ROOT / 'Sources/Features/Jobs/AddSearchView.swift'
        self.assertTrue(path.is_file(), 'Native add-search form is missing')
        view = path.read_text()
        for token in ['Form {', 'TextField("jobs.search_name"', 'TextField("jobs.search_url"',
                      '.keyboardType(.URL)', '.leftToRight', 'jobs.save_search',
                      '.disabled(!model.canSubmit)', 'model.statusKey', 'model.reconcile()',
                      'providerOutcomeUnknown']:
            self.assertIn(token, view)
        tabs = (ROOT / 'Sources/App/AuthenticatedTabs.swift').read_text()
        for token in ['AddSearchView(', 'saveTask', 'workflow.saveAndSearch()', '.sheet(',
                      'systemImage: "plus"', 'selectedJobID', 'jobsModel', 'workflow.resultsRevision']:
            self.assertIn(token, tabs)
        for forbidden in ['.task { await model.saveAndSearch()', 'URLSession(', 'https://']:
            self.assertNotIn(forbidden, view)

    def test_german_rental_provider_picker_uses_live_metadata_and_original_urls(self):
        source = (ROOT / 'Sources/Shared/Jobs/SearchCreation.swift').read_text()
        model = (ROOT / 'Sources/Features/Jobs/AddSearchModel.swift').read_text()
        view = (ROOT / 'Sources/Features/Jobs/AddSearchView.swift').read_text()
        for provider in [
            'immoscout', 'immowelt', 'kleinanzeigen', 'wgGesucht', 'ohneMakler',
            'deutscheWohnen', 'betterhomes', 'einsAImmobilien', 'engelVoelkers',
            'imaxx', 'immobilienDe', 'immoswp', 'regionalimmobilien24',
            'schwarzesbrett', 'sparkasse'
        ]:
            self.assertIn(provider, source)
        for token in ['provider.accepts(host: host)', 'selectedProvider.rawValue',
                      'selectedProvider: GermanRentalProvider = .immoscout',
                      'let dealType = "rent"', 'let enabled = false',
                      'let notificationAdapter: [String] = []',
                      'components.fragment == nil', 'return value',
                      'case .immowelt:', 'parameter("distributionTypes")',
                      'case .kleinanzeigen:', 'case .wgGesucht:']:
            self.assertIn(token, source)
        for token in ['func loadProviders() async', 'service.fetchSearchProviders()',
                      'GermanRentalProvider.allCases.filter',
                      'guard chosen.registered(in: providers)',
                      'func chooseProvider(', 'urlText = "" // Never silently send',
                      'hasAttemptedCreate = true', 'service.createSearch(',
                      'service.runSearch(', 'verifyCreatedJob', 'searchKey',
                      '$0.id == search.provider[0].id']:
            self.assertIn(token, model)
        for token in ['providerSection', 'detailsSection', 'submitSection',
                      'ForEach(model.availableProviders)', 'model.chooseProvider(source)',
                      'UIPasteboard.general.string', '.keyboardType(.URL)',
                      'model.loadProviders()', '.disabled(!model.canSubmit)',
                      '.interactiveDismissDisabled(model.isBusy)', 'jobs.save_search',
                      'model.reconcile()', 'providerOutcomeUnknown']:
            self.assertIn(token, view)
        self.assertNotIn('inberlinwohnen', source.lower())
        self.assertEqual(model.count('service.createSearch('), 1)
        self.assertEqual(model.count('service.runSearch('), 1)

    def test_selected_rental_provider_has_explicit_external_website_link(self):
        source = (ROOT / 'Sources/Shared/Jobs/SearchCreation.swift').read_text()
        view = (ROOT / 'Sources/Features/Jobs/AddSearchView.swift').read_text()
        model = (ROOT / 'Sources/Features/Jobs/AddSearchModel.swift').read_text()
        self.assertIn('var websiteURL: URL?', source)
        self.assertIn('URL(string: "https://" + site)', source)
        self.assertIn('if model.providerCatalogState == .ready,', view)
        self.assertIn('model.availableProviders.contains(model.selectedProvider)', view)
        self.assertIn('let websiteURL = model.selectedProvider.websiteURL', view)
        self.assertIn('Link(destination: websiteURL)', view)
        self.assertIn('jobs.open_provider_website', view)
        self.assertIn('systemImage: "arrow.up.right.square"', view)
        self.assertIn('model.chooseProvider(source)', view)
        self.assertIn('model.urlText = pasted', view)
        self.assertIn('service.createSearch(search)', model)
        self.assertNotIn('URLSession(', view)
        self.assertEqual(model.count('service.createSearch('), 1)
        self.assertEqual(model.count('service.runSearch('), 1)

    def test_job_selection_is_preserved_without_cluttered_filter_chips(self):
        source = (ROOT / 'Sources/Shared/Authentication/FredyAuthService.swift').read_text()
        self.assertIn('URLQueryItem(name: "jobNameFilter"', source)
        model = (ROOT / 'Sources/Features/Listings/ListingsModel.swift').read_text()
        for token in ['requestGeneration', 'generation == requestGeneration', 'func changeJob(',
                      'jobID: selectedJobID', 'response.totalNumber', 'response.result.isEmpty']:
            self.assertIn(token, model)
        listing = (ROOT / 'Sources/Shared/Listings/RentalListing.swift').read_text()
        self.assertIn('case jobID = "job_id"', listing)
        view = (ROOT / 'Sources/Features/Listings/ListingsView.swift').read_text()
        for token in ['@Binding var selectedJobID: String?', 'data.selectJob(selectedJobID)',
                      '.task(id:', 'data.refresh(jobs: jobsModel, force: true)', 'selectedJobID = nil',
                      'عرض إعلانات كل الأبحاث', 'TextField("بحث ضمن الإعلانات المحمّلة"']:
            self.assertIn(token, view)
        for unwanted in ['SearchFilterChips(', 'selectedRegion', 'jobs.active_count_note',
                         'jobs.region_from_url', 'allowedJobIDs']:
            self.assertNotIn(unwanted, view)

    def test_creation_cannot_upsert_existing_id_and_filtered_page_cannot_widen(self):
        model = (ROOT / 'Sources/Features/Jobs/AddSearchModel.swift').read_text()
        self.assertIn('existing.contains(where: { $0.id == search.jobId })', model,
                      'Upsert API requires an explicit collision guard')
        service = (ROOT / 'Sources/Shared/Authentication/FredyAuthService.swift').read_text()
        self.assertIn('decoded.result.allSatisfy({ $0.jobID == jobID })', service,
                      'Filtered responses must not silently contain another job')

    def test_url_path_is_not_repaired_and_partial_provider_regions_are_not_claimed(self):
        source = (ROOT / 'Sources/Shared/Jobs/SearchCreation.swift').read_text()
        self.assertTrue('components.percentEncodedPath.split' in source,
                        'Validate the path Fredy actually reads, not a decoded repair')
        for token in ['components.scheme == "https"', 'components.user == nil',
                      'components.password == nil', 'components.port == 443',
                      'hasSuffix("-mieten")', 'let enabled = false',
                      'let notificationAdapter: [String] = []', 'let shareWithUsers: [String] = []',
                      'let dealType = "rent"', 'id: selectedProvider.rawValue, url: url',
                      'return value', 'components.queryItems?.sorted']:
            self.assertTrue(token in source, token)
        job = (ROOT / 'Sources/Shared/Jobs/SearchJob.swift').read_text()
        self.assertTrue('labels.count == provider.count' in job,
                        'A job with unclassified providers must not be labelled as one region')

if __name__ == '__main__':
    unittest.main(verbosity=2)
