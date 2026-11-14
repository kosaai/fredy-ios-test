import Foundation
import Observation

enum ListingsState: Equatable {
    case idle, loading, ready
    case failed(ListingsFailure)
    case sessionExpired
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
    @ObservationIgnored private let service: any FredyListingsServing
    @ObservationIgnored let images: ListingImageLoader

    init(service: any FredyListingsServing) {
        self.service = service
        images = ListingImageLoader(service: service)
    }

    var isLoading: Bool { state == .loading }

    func changeJob(_ id: String?) async {
        guard state != .sessionExpired else { return }
        requestGeneration += 1
        selectedJobID = id
        lastPage = 0
        items = []
        hasMore = true
        state = .idle
        await loadNextPage()
    }

    func loadInitialIfNeeded() async {
        guard lastPage == 0, state == .idle else { return }
        await loadNextPage()
    }

    func reload() async {
        guard !isLoading, state != .sessionExpired else { return }
        requestGeneration += 1
        lastPage = 0
        items = []
        hasMore = true
        await loadNextPage()
    }

    func loadNextPage() async {
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
        items = []
        hasMore = false
        images.clear()
        state = .sessionExpired
    }
}
