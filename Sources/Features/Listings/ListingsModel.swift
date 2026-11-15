import Foundation
import Observation

enum ListingsState: Equatable {
    case idle, loading, ready
    case failed(ListingsFailure)
    case sessionExpired

    var isFailure: Bool { if case .failed = self { return true }; return false }
}

@Observable
@MainActor
final class ListingsModel {
    private(set) var items: [RentalListing] = []
    private(set) var state: ListingsState = .idle
    private(set) var hasMore = true
    private var lastPage = 0
    private let pageSize = 20
    private var requestGeneration = 0
    private var selectedJobID: String?
    @ObservationIgnored private var pageTask: Task<Void, Never>?
    @ObservationIgnored private let service: any FredyListingsServing
    @ObservationIgnored let images: ListingImageLoader

    init(service: any FredyListingsServing, images: ListingImageLoader? = nil) {
        self.service = service
        self.images = images ?? ListingImageLoader(service: service)
    }

    var isLoading: Bool { state == .loading }

    func changeJob(_ id: String?) async {
        guard state != .sessionExpired else { return }
        invalidate()
        selectedJobID = id
        await loadNextPage()
    }

    func loadInitialIfNeeded() async {
        guard lastPage == 0, state == .idle || state.isFailure || isLoading else { return }
        await loadNextPage()
    }

    func invalidate() {
        guard state != .sessionExpired else { return }
        requestGeneration += 1
        pageTask?.cancel()
        pageTask = nil
        lastPage = 0
        items = []
        hasMore = true
        state = .idle
    }

    func reload() async {
        guard state != .sessionExpired else { return }
        invalidate()
        await loadNextPage()
    }

    func loadNextPage() async {
        if let task = pageTask { await task.value; return }
        guard state != .sessionExpired, hasMore else { return }
        let generation = requestGeneration
        let task = Task {
            defer { if generation == requestGeneration { pageTask = nil } }
            await performLoadNextPage()
        }
        pageTask = task
        await task.value
    }

    private func performLoadNextPage() async {
        guard !isLoading, hasMore, state != .sessionExpired else { return }
        let previousState = state
        let generation = requestGeneration
        let requestedPage = lastPage + 1
        state = .loading
        do {
            let response = try await service.fetchListings(page: requestedPage, pageSize: pageSize, jobID: selectedJobID)
            try Task.checkCancellation()
            guard generation == requestGeneration else { return }
            guard state != .sessionExpired else { return }
            guard response.page == requestedPage else { throw ListingsFailure.invalidResponse }
            var seen = Set(items.map(\.id))
            let rentals = response.result.filter(\.isRental)
            items.append(contentsOf: rentals.filter { seen.insert($0.id).inserted })
            lastPage = response.page
            // The server total counts ALL deal types, not the filtered rental rows.
            // Division avoids overflowing page * pageSize on an invalid huge total.
            let pageCount = response.totalNumber == 0 ? 0 : 1 + (response.totalNumber - 1) / pageSize
            hasMore = !response.result.isEmpty && lastPage < pageCount
            state = .ready
        } catch is CancellationError {
            guard generation == requestGeneration else { return }
            if state != .sessionExpired { state = previousState }
        } catch let failure as ListingsFailure {
            guard generation == requestGeneration else { return }
            if state == .sessionExpired { return }
            if failure == .sessionExpired { expireSession() }
            else { state = .failed(failure) }
        } catch {
            guard generation == requestGeneration else { return }
            if state != .sessionExpired { state = .failed(.network) }
        }
    }

    func expireSession() {
        requestGeneration += 1
        pageTask?.cancel()
        pageTask = nil
        items = []
        hasMore = false
        images.clear()
        state = .sessionExpired
    }
}
