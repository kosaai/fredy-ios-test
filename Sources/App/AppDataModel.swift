import Foundation
import Observation

/// Session-local invalidation, not an event stream or a successful-write assertion.
@Observable
@MainActor
final class DataSynchronization {
    private(set) var revision = 0
    private(set) var expired = false
    func invalidate() { guard !expired else { return }; revision += 1 }
    func expire() { expired = true; revision += 1 }
    func reset() { expired = false; revision += 1 }
}

/// Shared by all four tabs. No persistent personal snapshots or periodic polling.
@Observable
@MainActor
final class AppDataModel {
    let home: ListingsModel
    let filtered: ListingsModel
    let map: RentalMapModel
    private(set) var dashboard: FindHausDashboardSnapshot?
    private(set) var dashboardState: ListingsState = .idle
    private(set) var sessionExpired = false
    var observationPaused = false
    private var selectedJobID: String?
    private var filteredActivated = false
    private var requestedRevision = 0
    private var completedRevision = -1
    private var includeJobs = true
    @ObservationIgnored private let service: any FredyClientServing
    @ObservationIgnored private var refreshTask: Task<Void, Never>?
    @ObservationIgnored private var observationTask: Task<Void, Never>?
    @ObservationIgnored private var scheduledTask: Task<Void, Never>?

    init(service: any FredyClientServing) {
        self.service = service
        let home = ListingsModel(service: service)
        self.home = home
        filtered = ListingsModel(service: service, images: home.images)
        map = RentalMapModel(service: service)
    }

    func listings(for jobID: String?) -> ListingsModel { jobID == nil ? home : filtered }

    func selectJob(_ jobID: String?) async {
        guard !sessionExpired else { return }
        filteredActivated = true
        if selectedJobID != jobID {
            selectedJobID = jobID
            map.invalidate()
            if jobID != nil { await filtered.changeJob(jobID) }
            else { filtered.invalidate(); await home.loadInitialIfNeeded() }
            guard selectedJobID == jobID else { return }
            if map.activated { await map.load(jobID: jobID) }
        } else {
            await listings(for: jobID).loadInitialIfNeeded()
        }
    }

    func loadMap() async { await map.load(jobID: selectedJobID) }

    func invalidate(includeJobs: Bool = true) {
        guard !sessionExpired else { return }
        requestedRevision += 1
        self.includeJobs = self.includeJobs || includeJobs
        home.invalidate()
        filtered.invalidate()
        map.invalidate()
        dashboard = nil
        dashboardState = .idle
    }

    func scheduleRefresh(jobs: JobsModel, includeJobs: Bool = true) {
        guard !sessionExpired else { return }
        invalidate(includeJobs: includeJobs)
        scheduledTask?.cancel()
        scheduledTask = Task {
            do { try await Task.sleep(for: .milliseconds(250)) }
            catch { return }
            guard !Task.isCancelled else { return }
            await refresh(jobs: jobs)
        }
    }

    func refresh(jobs: JobsModel, force: Bool = false) async {
        guard !sessionExpired else { return }
        if force { invalidate() }
        if let task = refreshTask { await task.value; return }
        let task = Task {
            defer { refreshTask = nil }
            // A mutation during a read forces another pass; old generations cannot publish.
            while completedRevision < requestedRevision && !sessionExpired && !Task.isCancelled {
                let revision = requestedRevision
                let refreshJobs = includeJobs
                includeJobs = false
                if refreshJobs, completedRevision >= 0 || jobs.state != .loaded { await jobs.reload() }
                if jobs.state == .sessionExpired { expireSession(); break }
                await home.loadInitialIfNeeded()
                if filteredActivated, selectedJobID != nil { await filtered.loadInitialIfNeeded() }
                await loadDashboard()
                if map.activated { await loadMap() }
                if service.synchronization.expired || home.state == .sessionExpired ||
                    filtered.state == .sessionExpired || map.state == .sessionExpired {
                    expireSession(); break
                }
                if revision == requestedRevision { completedRevision = revision }
            }
        }
        refreshTask = task
        await task.value
    }

    private func loadDashboard() async {
        guard dashboardState != .ready, dashboardState != .loading, !sessionExpired else { return }
        let revision = requestedRevision
        dashboardState = .loading
        do {
            let fresh = try await service.fetchDashboardSnapshot()
            try Task.checkCancellation()
            guard revision == requestedRevision, !sessionExpired else { return }
            dashboard = fresh
            dashboardState = .ready
        } catch is CancellationError {
            if revision == requestedRevision, !sessionExpired { dashboardState = .idle }
        } catch {
            guard revision == requestedRevision, !sessionExpired else { return }
            let failure = (error as? ListingsFailure) ?? .network
            if failure == .sessionExpired { expireSession() }
            else { dashboardState = .failed(failure) }
        }
    }

    /// Only a real accepted/observed search starts this finite GET-only window.
    func observeSearch(jobs: JobsModel) {
        guard observationTask == nil, !sessionExpired, !observationPaused else { return }
        let baseline = jobs.jobs
        observationTask = Task {
            defer { observationTask = nil }
            var seenRunning = baseline.contains { $0.running == true }
            for _ in 0..<12 {
                do {
                    try await Task.sleep(for: .seconds(5))
                    try Task.checkCancellation()
                    guard !sessionExpired else { return }
                    await jobs.reload()
                    try Task.checkCancellation()
                    guard jobs.state == .loaded else { return }
                    let running = jobs.jobs.contains { $0.running == true }
                    seenRunning = seenRunning || running
                    let advanced = jobs.jobs.contains { job in
                        baseline.first(where: { $0.id == job.id })?.lastRunAt != job.lastRunAt
                    }
                    if !running && (seenRunning || advanced) {
                        scheduleRefresh(jobs: jobs, includeJobs: false)
                        return
                    }
                } catch { return }
            }
            // Unknown/queued/long-running: snapshot remains labelled, manual refresh stays available.
        }
    }

    func stopSearchObservation() { observationTask?.cancel() }

    func expireSession() {
        guard !sessionExpired else { return }
        sessionExpired = true
        observationTask?.cancel()
        requestedRevision += 1
        scheduledTask?.cancel()
        refreshTask?.cancel()
        home.expireSession()
        filtered.expireSession()
        map.expireSession()
        dashboard = nil
        dashboardState = .sessionExpired
    }
}
