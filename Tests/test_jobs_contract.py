"""Offline source checks only: no Swift execution, credentials or job fixtures."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class JobsSourceContract(unittest.TestCase):
    def test_native_jobs_and_tabs_cover_readonly_refresh_and_shared_expiry(self):
        names = ['Sources/Features/Jobs/JobsModel.swift', 'Sources/Features/Jobs/JobsView.swift', 'Sources/App/AuthenticatedTabs.swift']
        self.assertTrue(all((ROOT / n).exists() for n in names), 'Native jobs/tabs are missing')
        model, view, tabs = [(ROOT / n).read_text() for n in names]
        for token in ['@Observable', '@MainActor', 'guard !isLoading', 'service.fetchJobs()', 'Task.checkCancellation()', 'seen.insert', 'jobs = []', 'case sessionExpired', 'state = previousState']:
            self.assertIn(token, model)
        for token in ['.refreshable', '.task', 'ProgressView', 'model.jobs.isEmpty', '.failed', '.sessionExpired', 'job.name', 'job.enabled', 'job.running', 'job.numberOfFoundListings', 'jobs.unknown', 'jobs.unavailable', 'onSessionExpired']:
            self.assertIn(token, view)
        for token in ['TabView', '.tabItem', 'ListingsView(service: service', 'JobsView(service: service', '@State private var expired', 'if expired', 'NavigationStack']:
            self.assertIn(token, tabs)
        listings = (ROOT / 'Sources/Features/Listings/ListingsView.swift').read_text()
        self.assertIn('.onChange(of: model.state)', listings)
        self.assertIn('AuthenticatedTabs(service: model.service', (ROOT / 'Sources/App/AppRootView.swift').read_text())
        for source in [model, view, tabs]:
            for token in ['URLSession(', 'AsyncImage', 'UserDefaults', 'print(', 'debugPrint(', 'Toggle(', '.onDelete', '.swipeActions', 'runJob', 'deleteJob', 'createJob', 'updateJob']:
                self.assertNotIn(token, source)

    def test_jobs_use_existing_authenticated_get_and_array_response(self):
        source = (ROOT / 'Sources/Shared/Authentication/FredyAuthService.swift').read_text()
        self.assertTrue('func fetchJobs()' in source, 'Authenticated jobs read is missing')
        start = source.index('    func fetchJobs()')
        end = source.index('    func fetchListings(', start)
        method = source[start:end]
        self.assertIn('authenticatedRead(path: "api/jobs/")', method)
        self.assertIn('decode([SearchJob].self', method)
        self.assertIn('response.mimeType == "application/json"', method)
        for token in ['perform(', 'POST', 'PUT', 'PATCH', 'DELETE', '/run', '/events', '/data']:
            self.assertNotIn(token, method)
        self.assertEqual(source.count('URLSession('), 1)
        protocol = (ROOT / 'Sources/Shared/Listings/RentalListing.swift').read_text()
        self.assertIn('FredyListingsServing, FredyJobsServing', protocol)

    def test_dashboard_uses_real_fredy_counts_and_confirmed_one_shot_run(self):
        dto = (ROOT / 'Sources/Shared/Listings/RentalListing.swift').read_text()
        service = (ROOT / 'Sources/Shared/Authentication/FredyAuthService.swift').read_text()
        home = (ROOT / 'Sources/Features/Home/HomeView.swift').read_text()
        self.assertIn('struct FindHausDashboardSnapshot: Decodable', dto)
        for field in ['perDay', 'newToday', 'intervalMinutes', 'lastRunDate', 'nextRunDate']:
            self.assertIn(field, dto)
        self.assertIn('FredyDashboardServing', dto)
        self.assertIn('authenticatedRead(path: "api/dashboard")', service)
        self.assertIn('authenticatedWrite(path: "api/jobs/startAll")', service)
        self.assertIn('response.statusCode == 202', service)
        self.assertIn('dashboardService.fetchDashboardSnapshot()', home)
        self.assertIn('dashboardService.startAllSearches()', home)
        for label in ['إعلان جديد اليوم', 'البحث الدوري كل', 'آخر تشغيل:',
                      'التشغيل القادم:', 'ابحث الآن', 'home.search_summary']:
            self.assertIn(label, home)
        self.assertIn('.confirmationDialog(', home)
        self.assertIn('isPresented: $confirmingSearch', home)
        self.assertIn('disabled(startingSearch', home)
        self.assertIn('Task { await reloadDashboard() }', home)
        self.assertNotIn('73 new', home)
        self.assertNotIn('Telegram', home)
        self.assertNotIn('URLSession(', home)

    def test_actual_job_fields_are_optional_without_invented_defaults(self):
        path = ROOT / 'Sources/Shared/Jobs/SearchJob.swift'
        self.assertTrue(path.exists(), 'Read-only job DTO is missing')
        source = path.read_text()
        for text in ['let id: String', 'let name: String?', 'let enabled: Bool?', 'let running: Bool?', 'let numberOfFoundListings: Int?', 'decodeIfPresent', 'count >= 0', 'FredyJobsServing', 'func fetchJobs()']:
            self.assertIn(text, source)
        for text in ['isEnabled', 'isRunning', 'listingCount', 'UUID()', '?? false', '?? 0']:
            self.assertNotIn(text, source)


if __name__ == '__main__':
    unittest.main(verbosity=2)
