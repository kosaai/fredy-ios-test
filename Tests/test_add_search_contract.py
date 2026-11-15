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
                      'let dealType = "rent"', 'id: "immoscout", url: url',
                      'return value', 'components.queryItems?.sorted']:
            self.assertTrue(token in source, token)
        job = (ROOT / 'Sources/Shared/Jobs/SearchJob.swift').read_text()
        self.assertTrue('labels.count == provider.count' in job,
                        'A job with unclassified providers must not be labelled as one region')

if __name__ == '__main__':
    unittest.main(verbosity=2)
