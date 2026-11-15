import Foundation
import Observation

struct MapListingEnvelope: Decodable, Sendable {
    let listings: [RentalListing]
}

@MainActor
protocol FredyMapServing {
    func fetchMapListings(jobID: String?) async throws -> [RentalListing]
    func fetchListingDetail(id: String) async throws -> RentalListing
}

@Observable
@MainActor
final class RentalMapModel {
    private(set) var items: [RentalListing] = []
    private(set) var state: ListingsState = .idle
    private(set) var selectedID: String?
    private(set) var detail: RentalListing?
    private(set) var detailState: ListingsState = .idle
    private(set) var activated = false
    private var selectedJobID: String?
    private var requestGeneration = 0
    private var selectionGeneration = 0
    @ObservationIgnored private let service: any FredyMapServing
    @ObservationIgnored private var mapTask: Task<Void, Never>?
    @ObservationIgnored private var detailTask: Task<Void, Never>?

    init(service: any FredyMapServing) { self.service = service }

    func load(jobID: String?) async {
        guard state != .sessionExpired else { return }
        activated = true
        if jobID != selectedJobID { invalidate(); selectedJobID = jobID }
        if let task = mapTask { await task.value; return }
        guard state != .ready else { return }
        let generation = requestGeneration
        let task = Task {
            defer { if generation == requestGeneration { mapTask = nil } }
            await performLoad(jobID: jobID)
        }
        mapTask = task
        await task.value
    }

    private func performLoad(jobID: String?) async {
        guard state != .sessionExpired else { return }
        let generation = requestGeneration
        state = .loading
        do {
            let listings = try await service.fetchMapListings(jobID: jobID)
            try Task.checkCancellation()
            guard generation == requestGeneration, jobID == selectedJobID, state != .sessionExpired else { return }
            var seen = Set<String>()
            items = listings.filter { $0.isRental && $0.hasVerifiedCoordinates && seen.insert($0.id).inserted }
            state = .ready
        } catch is CancellationError {
            guard generation == requestGeneration, state != .sessionExpired else { return }
            state = .idle
        } catch {
            guard generation == requestGeneration, state != .sessionExpired else { return }
            let failure = (error as? ListingsFailure) ?? .network
            if failure == .sessionExpired { expireSession() }
            else { state = .failed(failure) }
        }
    }

    func invalidate() {
        guard state != .sessionExpired else { return }
        requestGeneration += 1
        mapTask?.cancel()
        mapTask = nil
        items = []
        state = .idle
        dismissSelection()
    }

    func selectListing(id: String) {
        guard state == .ready, items.contains(where: { $0.id == id }) else { return }
        dismissSelection()
        selectedID = id
        detailState = .loading
        let detailGeneration = selectionGeneration
        detailTask = Task {
            do {
                let listing = try await service.fetchListingDetail(id: id)
                try Task.checkCancellation()
                guard detailGeneration == selectionGeneration, selectedID == id,
                      state != .sessionExpired else { return }
                guard listing.id == id, listing.isRental,
                      selectedJobID == nil || listing.jobID == selectedJobID else { throw ListingsFailure.invalidResponse }
                detail = listing
                detailState = .ready
            } catch is CancellationError {
                guard detailGeneration == selectionGeneration, state != .sessionExpired else { return }
                detailState = .idle
            } catch {
                guard detailGeneration == selectionGeneration, state != .sessionExpired else { return }
                let failure = (error as? ListingsFailure) ?? .network
                if failure == .sessionExpired { expireSession() }
                else { detailState = .failed(failure) }
            }
        }
    }

    func dismissSelection() {
        selectionGeneration += 1
        detailTask?.cancel()
        detailTask = nil
        selectedID = nil
        detail = nil
        detailState = .idle
    }

    func expireSession() {
        invalidate()
        state = .sessionExpired
        detailState = .sessionExpired
    }
}
