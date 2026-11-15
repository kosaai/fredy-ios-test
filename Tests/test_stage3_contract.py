"""Offline Stage 3 source guards; not Apple runtime/network evidence."""
from pathlib import Path
import unittest
ROOT = Path(__file__).resolve().parents[1]
def source(path): return (ROOT/path).read_text()
class StageThreeContracts(unittest.TestCase):
    def test_verified_map_and_detail_transport_same_session(self):
        text = source('Sources/Shared/Authentication/FredyAuthService.swift')
        for token in ['func fetchMapListings(', 'api/listings/map', 'URLQueryItem(name: "jobId"', 'func fetchListingDetail(', 'decoded.id == id', 'MapListingEnvelope']:
            self.assertIn(token, text)
        self.assertEqual(text.count('URLSession('), 1)
        self.assertNotIn('/geocode',text)
        self.assertNotIn('CLGeocoder',text)
    def test_map_rejects_invalid_coordinates_and_guards_both_request_generations(self):
        dto = source('Sources/Shared/Listings/RentalListing.swift')
        for token in ['latitude.isFinite', 'longitude.isFinite', '(-90...90).contains(latitude)', '(-180...180).contains(longitude)', 'latitude != -1, longitude != -1']:
            self.assertIn(token,dto)
        model = source('Sources/Features/Map/RentalMapModel.swift')
        for token in ['@Observable', 'func invalidate()', 'generation == requestGeneration', 'detailGeneration == selectionGeneration', 'hasVerifiedCoordinates', 'seen.insert', 'isRental', 'func expireSession()', 'Task.checkCancellation()', 'detailTask?.cancel()', 'jobID == selectedJobID']:
            self.assertIn(token,model)
        self.assertNotIn('geocode',model.lower())

    def test_shared_sync_coalesces_reads_and_invalidates_inflight_pages(self):
        path=ROOT/'Sources/App/AppDataModel.swift'
        self.assertTrue(path.exists(), 'Shell data coordinator missing')
        text=path.read_text()
        for token in ['@Observable', 'refreshTask', 'await task.value', 'requestedRevision', 'completedRevision', 'func invalidate(', 'func expireSession()', 'map.activated', 'includeJobs', 'Task.sleep', 'home.images']:
            self.assertIn(token,text)
        page=source('Sources/Features/Listings/ListingsModel.swift')
        self.assertIn('func invalidate()',page)
        self.assertIn('state == .idle || state.isFailure',page)
        invalidate=page.split('func invalidate()',1)[1].split('func ',1)[0]
        self.assertIn('requestGeneration += 1',invalidate)
        self.assertIn('state = .idle',invalidate)
        service=source('Sources/Shared/Authentication/FredyAuthService.swift')
        self.assertIn('let synchronization = DataSynchronization()',service)
        self.assertIn('defer { synchronization.invalidate() }',service)
        self.assertIn('synchronization.expire()',service)

    def test_map_selection_reuses_listing_card_authenticated_images_and_detail(self):
        text=source('Sources/Features/Map/RentalMapView.swift')
        for token in ['Map(position: $camera, selection: $selectedPin)', 'Marker(', '.tag(listing.id)', 'model.selectListing(id:', '.sheet(item:', 'ListingRow(', 'images: data.home.images', 'listing.description', 'model.detailState', 'data.refresh(jobs: jobsModel, force: true)', 'model.items.isEmpty']:
            self.assertIn(token,text)
        for token in ['CLGeocoder', 'MKLocalSearch', 'URLSession(', 'AsyncImage', 'latitude: 51.1657']:
            self.assertNotIn(token,text)

    def test_all_tabs_use_shell_data_and_mutation_invalidation_not_discarded_sheets(self):
        shell=source('Sources/App/AuthenticatedTabs.swift')
        for token in ['@State private var data: AppDataModel', 'data: data', 'service.synchronization.revision', 'service.synchronization.expired', 'data.scheduleRefresh(jobs:', 'jobsModel.jobs', 'data.expireSession()']:
            self.assertIn(token,shell)
        self.assertNotIn('onDismiss: { refreshToken += 1 }',shell)
        for name in ['Home/HomeView.swift','Listings/ListingsView.swift']:
            text=source('Sources/Features/'+name)
            self.assertIn('let data: AppDataModel',text)
            self.assertNotIn('State(initialValue: ListingsModel(',text)
            self.assertIn('data.refresh(jobs: jobsModel, force: true)',text)
        self.assertIn('data.selectJob(selectedJobID)',source('Sources/Features/Listings/ListingsView.swift'))
        card=source('Sources/Features/Listings/ListingRow.swift')
        self.assertIn('watched = true\n                    onChanged()',card)
        self.assertIn('self.watched = !watched\n                onChanged()',card)
        self.assertIn('if next != nil { watched = true }\n                onChanged()',card)

    def test_expiry_clears_all_shell_owned_personal_state_and_stops_tasks(self):
        shell=source('Sources/App/AuthenticatedTabs.swift')
        expire=shell.split('private func expire()',1)[1]
        for token in ['jobsModel.expireSession()', 'settingsModel.expireSession()', 'workflow.expireSession()', 'data.expireSession()']:
            self.assertIn(token,expire)
        for path in ['Sources/Features/Jobs/JobsModel.swift', 'Sources/Features/Jobs/JobManagementModel.swift', 'Sources/Features/Settings/AccountSettingsModel.swift', 'Sources/Features/Jobs/AddSearchModel.swift']:
            self.assertIn('func expireSession()',source(path))

    def test_reauthentication_resets_session_signal_only_after_verified_login(self):
        service=source('Sources/Shared/Authentication/FredyAuthService.swift')
        self.assertIn('sessionVerified = true\n            synchronization.reset()',service)
        signal=source('Sources/App/AppDataModel.swift')
        self.assertIn('func reset() { expired = false; revision += 1 }',signal)

    def test_shared_images_coalesce_inflight_requests_and_expiry_cancels_them(self):
        text=source('Sources/Features/Listings/ListingImageView.swift')
        for token in ['private var requests: [String: Task<Data, Error>]', 'requests[id] = request', 'try await request.value', 'cacheGeneration == generation', 'requests.values.forEach { $0.cancel() }', 'requests.removeAll()']:
            self.assertIn(token,text)
        self.assertEqual(text.count('service.fetchListingImage(id: id)'),1)

    def test_tab_cancellation_cannot_cancel_shared_page_or_map_reads(self):
        page=source('Sources/Features/Listings/ListingsModel.swift')
        for token in ['private var pageTask: Task<Void, Never>?', 'if let task = pageTask { await task.value; return }', 'await performLoadNextPage()', 'pageTask?.cancel()', 'generation == requestGeneration { pageTask = nil }']:
            self.assertIn(token,page)
        maps=source('Sources/Features/Map/RentalMapModel.swift')
        for token in ['private var mapTask: Task<Void, Never>?', 'if let task = mapTask { await task.value; return }', 'await performLoad(jobID: jobID)', 'mapTask?.cancel()', 'generation == requestGeneration { mapTask = nil }']:
            self.assertIn(token,maps)

    def test_search_observation_is_bounded_readonly_and_not_parallel_to_add_search(self):
        data=source('Sources/App/AppDataModel.swift')
        self.assertIn('func observeSearch(jobs: JobsModel)',data)
        observer=data.split('func observeSearch(jobs: JobsModel)',1)[1].split('func stopSearchObservation()',1)[0]
        for token in ['observationTask == nil', '0..<12', 'Task.sleep(for: .seconds(5))', 'await jobs.reload()', 'Task.checkCancellation()', 'seenRunning']:
            self.assertIn(token,observer)
        for token in ['runSearch(', 'startAllSearches(', 'authenticatedWrite', 'while true']:
            self.assertNotIn(token,observer)
        shell=source('Sources/App/AuthenticatedTabs.swift')
        self.assertIn('jobsModel.runRevision',shell)
        self.assertIn('!workflow.isBusy',shell)
        self.assertIn('data.stopSearchObservation()',shell)
        home=source('Sources/Features/Home/HomeView.swift')
        self.assertIn('data.observeSearch(jobs: jobsModel)',home)

    def test_background_or_add_search_blocks_new_parallel_search_observation(self):
        text=source('Sources/App/AppDataModel.swift')
        self.assertIn('!observationPaused',text.split('func observeSearch(',1)[1].split('let baseline',1)[0])
        shell=source('Sources/App/AuthenticatedTabs.swift')
        self.assertIn('data.observationPaused = busy || scenePhase != .active',shell)
        self.assertIn('data.observationPaused = phase != .active || workflow.isBusy',shell)

    def test_expiry_is_terminal_even_for_late_editor_and_search_read_completions(self):
        account=source('Sources/Features/Settings/AccountSettingsModel.swift')
        self.assertIn('guard !sessionExpired else { return }\n            saved = value',account)
        self.assertIn('let freshProviders = try await',account)
        manager=source('Sources/Features/Jobs/JobManagementModel.swift')
        self.assertIn('guard phase != .sessionExpired else { return }\n            guard let source',manager)
        search=source('Sources/Features/Jobs/AddSearchModel.swift')
        self.assertIn('private func checkSession() throws',search)
        self.assertIn('guard phase != .sessionExpired else { throw ListingsFailure.sessionExpired }',search)
        self.assertIn('catch is CancellationError {\n            guard phase != .sessionExpired else { return }',search)

    def test_first_frame_of_a_new_job_filter_cannot_display_previous_job_rows(self):
        text=source('Sources/Features/Listings/ListingsView.swift')
        self.assertIn('let matchesJob = selectedJobID == nil || listing.jobID == selectedJobID',text)
        self.assertIn('return matchesJob && matchesText && matchesPrice && matchesRooms',text)

    def test_singleflight_slot_cleanup_happens_inside_owned_task_before_waiters_resume(self):
        data=source('Sources/App/AppDataModel.swift')
        self.assertIn('let task = Task {\n            defer { refreshTask = nil }',data)
        self.assertNotIn('await task.value\n        refreshTask = nil',data)
        for path,slot in [('Sources/Features/Listings/ListingsModel.swift','pageTask'),('Sources/Features/Map/RentalMapModel.swift','mapTask')]:
            text=source(path)
            self.assertIn('defer { if generation == requestGeneration { '+slot+' = nil } }',text)
            self.assertNotIn('await task.value\n        if generation == requestGeneration',text)

    def test_returning_from_external_listing_does_not_reset_map_or_open_detail(self):
        shell = source('Sources/App/AuthenticatedTabs.swift')
        foreground = shell.split('.onChange(of: scenePhase) { _, phase in', 1)[1].split('.onChange(of: jobsModel.pendingAction)', 1)[0]
        self.assertIn('data.observationPaused = phase != .active || workflow.isBusy', foreground)
        self.assertIn('data.stopSearchObservation()', foreground)
        self.assertIn('data.observeSearch(jobs: jobsModel)', foreground)
        self.assertNotIn('data.scheduleRefresh(', foreground)
        self.assertNotIn('data.invalidate(', foreground)
        map_view = source('Sources/Features/Map/RentalMapView.swift')
        self.assertIn('@State private var camera: MapCameraPosition = .automatic', map_view)
        self.assertIn('.task { await data.loadMap() }', map_view)
        self.assertIn('data.refresh(jobs: jobsModel, force: true)', map_view)
        map_model = source('Sources/Features/Map/RentalMapModel.swift')
        self.assertIn('guard state != .ready else { return }', map_model)

if __name__ == '__main__': unittest.main(verbosity=2)
