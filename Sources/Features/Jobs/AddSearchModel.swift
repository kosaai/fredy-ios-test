import Foundation
import Observation

enum ProviderCatalogState: Equatable { case idle, loading, ready, failed }

enum AddSearchPhase: Equatable {
    case idle, validating, saving, verifying, starting, waiting, running, stopped
    case uncertain, failed(String), sessionExpired
}

/// Owned by the authenticated shell: closing a sheet never replays a mutation.
@Observable
@MainActor
final class AddSearchModel {
    var name = ""
    var urlText = ""
    private(set) var selectedProvider: GermanRentalProvider = .immoscout
    private(set) var availableProviders: [GermanRentalProvider] = []
    private(set) var providerCatalogState: ProviderCatalogState = .idle
    private(set) var phase: AddSearchPhase = .idle
    private(set) var savedJobID: String?
    private(set) var hasAttemptedCreate = false
    private(set) var hasAttemptedRun = false
    private(set) var resultsRevision = 0
    // Fredy exposes running/lastRunAt, but NO provider success/failure outcome.
    let providerOutcomeUnknown = "jobs.provider_outcome_unknown"
    private var draft: SearchCreation?
    @ObservationIgnored private let service: any FredyClientServing
    @ObservationIgnored private let jobsModel: JobsModel

    init(service: any FredyClientServing, jobsModel: JobsModel) {
        self.service = service
        self.jobsModel = jobsModel
    }

    var isBusy: Bool {
        switch phase {
        case .validating, .saving, .verifying, .starting, .waiting, .running: return true
        default: return false
        }
    }

    var canSubmit: Bool {
        !isBusy && !hasAttemptedCreate && phase != .sessionExpired &&
        providerCatalogState == .ready && availableProviders.contains(selectedProvider)
    }

    func chooseProvider(_ provider: GermanRentalProvider) {
        guard !isBusy, !hasAttemptedCreate, availableProviders.contains(provider) else { return }
        if selectedProvider != provider {
            selectedProvider = provider
            urlText = "" // Never silently send a URL intended for the previous provider.
        }
    }

    /// Read-only catalog. Only declared German rental providers exposed by Fredy are selectable.
    func loadProviders() async {
        guard !isBusy, phase != .sessionExpired, !hasAttemptedCreate,
              providerCatalogState != .loading else { return }
        providerCatalogState = .loading
        do {
            let metadata = try await service.fetchSearchProviders()
            try checkSession()
            availableProviders = GermanRentalProvider.allCases.filter { $0.registered(in: metadata) }
            if availableProviders.isEmpty {
                providerCatalogState = .failed
            } else {
                if !availableProviders.contains(selectedProvider) {
                    selectedProvider = availableProviders[0]
                    urlText = ""
                }
                providerCatalogState = .ready
            }
        } catch is CancellationError {
            if phase != .sessionExpired { providerCatalogState = .idle }
        } catch let failure as ListingsFailure where failure == .sessionExpired {
            expireSession()
        } catch {
            availableProviders = []
            providerCatalogState = .failed
        }
    }

    var statusKey: String {
        switch phase {
        case .idle: return "jobs.add_hint"
        case .validating: return "jobs.validating"
        case .saving: return "jobs.saving"
        case .verifying: return "jobs.verifying"
        case .starting: return "jobs.starting"
        case .waiting: return "jobs.accepted"
        case .running: return "jobs.running"
        case .stopped: return "jobs.run_stopped"
        case .uncertain: return "jobs.uncertain"
        case .failed(let key): return key
        case .sessionExpired: return "listings.session_expired"
        }
    }

    func prepareNewDraft() {
        // Keep an ambiguous POST locked until a read-only reconciliation succeeds.
        guard !isBusy, phase != .uncertain, phase != .sessionExpired else { return }
        name = ""
        urlText = ""
        selectedProvider = .immoscout
        draft = nil
        savedJobID = nil
        hasAttemptedCreate = false
        hasAttemptedRun = false
        phase = .idle
    }

    func saveAndSearch() async {
        guard canSubmit else { return }
        phase = .validating
        do {
            let chosen = selectedProvider
            let search = try SearchCreation(name: name, urlText: urlText, selectedProvider: chosen)
            draft = search
            let providers = try await service.fetchSearchProviders()
            try checkSession()
            guard chosen.registered(in: providers) else {
                throw SearchInputFailure.providerUnavailable
            }
            let existing = try await service.fetchJobs()
            try checkSession()
            jobsModel.acceptSnapshot(existing)
            guard !existing.contains(where: { $0.id == search.jobId }) else { throw ListingsFailure.invalidResponse }
            // Missing/malformed provider arrays cannot prove the URL is unique.
            guard existing.allSatisfy({ $0.provider != nil }) else { throw ListingsFailure.invalidResponse }
            guard let searchKey = SearchURL.duplicateKey(search.provider[0].url) else {
                throw SearchInputFailure.invalidURL
            }
            if let duplicate = existing.first(where: { job in
                job.provider?.contains(where: {
                    $0.id == search.provider[0].id &&
                    SearchURL.duplicateKey($0.url) == searchKey
                }) == true
            }) {
                savedJobID = duplicate.id
                throw SearchInputFailure.duplicateURL
            }
            phase = .saving
            hasAttemptedCreate = true
            try await service.createSearch(search)
            try checkSession()
            phase = .verifying
            let created = try await verifyCreatedJob(search)
            savedJobID = created.id
            resultsRevision += 1
            let previousRun = created.lastRunAt
            phase = .starting
            // Set BEFORE awaiting, including lost-response/cancellation cases.
            hasAttemptedRun = true
            try await service.runSearch(id: created.id)
            try checkSession()
            phase = .waiting
            await observeRun(id: created.id, previousRun: previousRun)
        } catch is CancellationError {
            guard phase != .sessionExpired else { return }
            phase = hasAttemptedCreate ? .uncertain : .idle
        } catch let failure as SearchInputFailure {
            phase = .failed(failure.localizationKey)
        } catch let failure as ListingsFailure {
            handle(failure)
        } catch {
            handle(.network)
        }
    }

    /// Acknowledgement is not identity: re-read the exact client-selected new id.
    private func verifyCreatedJob(_ search: SearchCreation) async throws -> SearchJob {
        let snapshot = try await service.fetchJobs()
        try checkSession()
        jobsModel.acceptSnapshot(snapshot)
        guard let created = snapshot.first(where: { $0.id == search.jobId }),
              created.name == search.name, created.enabled == false,
              created.provider == search.provider, created.dealType == "rent" else {
            throw ListingsFailure.invalidResponse
        }
        return created
    }

    private func observeRun(id: String, previousRun: Double?) async {
        let deadline = ContinuousClock.now.advanced(by: .seconds(300))
        var sawRunning = false
        do {
            while ContinuousClock.now < deadline {
                try checkSession()
                let snapshot = try await service.fetchJobs()
                try checkSession()
                jobsModel.acceptSnapshot(snapshot)
                guard let job = snapshot.first(where: { $0.id == id }) else { throw ListingsFailure.invalidResponse }
                if job.running == true {
                    sawRunning = true
                    phase = .running
                } else if job.running == false,
                          sawRunning || (job.lastRunAt != nil && job.lastRunAt != previousRun) {
                    // This means stopped, NOT successful or an error-free empty search.
                    phase = .stopped
                    resultsRevision += 1
                    return
                }
                try await Task.sleep(for: .seconds(2))
            }
            phase = .uncertain
            resultsRevision += 1
        } catch is CancellationError {
            guard phase != .sessionExpired else { return }
            phase = .uncertain
        } catch let failure as ListingsFailure {
            handle(failure)
        } catch {
            handle(.network)
        }
    }

    /// GET only. Never retry either POST after an ambiguous delivery.
    func reconcile() async {
        guard !isBusy, phase != .sessionExpired, let draft else { return }
        phase = .verifying
        do {
            let created = try await verifyCreatedJob(draft)
            savedJobID = created.id
            phase = .failed("jobs.saved_no_replay")
            resultsRevision += 1
        } catch is CancellationError {
            guard phase != .sessionExpired else { return }
            phase = .uncertain
        } catch let failure as ListingsFailure {
            handle(failure)
        } catch {
            phase = .uncertain
        }
    }

    private func checkSession() throws {
        guard phase != .sessionExpired else { throw ListingsFailure.sessionExpired }
        try Task.checkCancellation()
    }

    func expireSession() { handle(.sessionExpired) }

    private func handle(_ failure: ListingsFailure) {
        guard phase != .sessionExpired else { return }
        if failure == .sessionExpired {
            name = ""
            urlText = ""
            availableProviders = []
            providerCatalogState = .idle
            draft = nil
            savedJobID = nil
            phase = .sessionExpired
        } else if hasAttemptedCreate && [.network, .server, .invalidResponse].contains(failure) {
            phase = .uncertain
        } else {
            phase = .failed(failure.localizationKey)
        }
    }
}
