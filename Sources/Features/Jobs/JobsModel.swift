import Foundation
import Observation

enum JobsState: Equatable {
    case idle, loading, loaded
    case failed(ListingsFailure)
    case sessionExpired
}

@Observable
@MainActor
final class JobsModel {
    private(set) var jobs: [SearchJob] = []
    private(set) var state: JobsState = .idle
    @ObservationIgnored private let service: any FredyJobsServing

    init(service: any FredyJobsServing) {
        self.service = service
    }

    var isLoading: Bool { state == .loading }

    func loadIfNeeded() async {
        guard state == .idle else { return }
        await reload()
    }

    func reload() async {
        guard !isLoading, state != .sessionExpired else { return }
        let previousState = state
        state = .loading
        do {
            let result = try await service.fetchJobs()
            try Task.checkCancellation()
            guard state != .sessionExpired else { return }
            var seen = Set<String>()
            jobs = result.filter { seen.insert($0.id).inserted }
            state = .loaded
        } catch is CancellationError {
            if state != .sessionExpired { state = previousState }
        } catch let failure as ListingsFailure {
            if state == .sessionExpired { return }
            if failure == .sessionExpired {
                jobs = []
                state = .sessionExpired
            } else {
                state = .failed(failure)
            }
        } catch {
            if state != .sessionExpired { state = .failed(.network) }
        }
    }
}
