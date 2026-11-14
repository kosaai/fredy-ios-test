import SwiftUI

@MainActor
struct ListingsView: View {
    @State private var model: ListingsModel
    @State private var actionTask: Task<Void, Never>?
    @State private var selectedRegion: String?
    let jobsModel: JobsModel
    @Binding var selectedJobID: String?
    let refreshToken: Int
    let onSessionExpired: () -> Void

    init(service: any FredyListingsServing, jobsModel: JobsModel,
         selectedJobID: Binding<String?>, refreshToken: Int,
         onSessionExpired: @escaping () -> Void) {
        _model = State(initialValue: ListingsModel(service: service))
        self.jobsModel = jobsModel
        _selectedJobID = selectedJobID
        self.refreshToken = refreshToken
        self.onSessionExpired = onSessionExpired
    }

    private struct RequestKey: Equatable {
        let jobID: String?
        let refresh: Int
    }

    private var visibleItems: [RentalListing] {
        guard let selectedRegion else { return model.items }
        let allowedJobIDs = Set(jobsModel.jobs.filter { $0.regionLabel == selectedRegion }.map(\.id))
        return model.items.filter { listing in
            listing.jobID.map { allowedJobIDs.contains($0) } == true
        }
    }

    var body: some View {
        List {
            if model.state == .sessionExpired {
                Section {
                    Label("listings.session_expired", systemImage: "lock")
                    Button("listings.sign_in", action: onSessionExpired)
                        .frame(minHeight: 44)
                        .buttonStyle(.borderedProminent)
                }
            } else {
                Section {
                    SearchFilterChips(jobs: jobsModel.jobs, selectedJobID: $selectedJobID,
                                      selectedRegion: $selectedRegion)
                    if jobsModel.isLoading {
                        ProgressView("jobs.loading")
                    } else if case .failed(let failure) = jobsModel.state {
                        Text(LocalizedStringKey(failure.localizationKey))
                        Button("jobs.refresh_searches") {
                            guard actionTask == nil else { return }
                            actionTask = Task {
                                await jobsModel.reload()
                                actionTask = nil
                            }
                        }
                        .frame(minHeight: 44)
                    }
                }
                if !model.items.isEmpty {
                    LabeledContent("listings.loaded_count", value: visibleItems.count.formatted(.number.locale(Locale(identifier: "ar"))))
                }
                ForEach(visibleItems) { listing in
                    VStack(alignment: .leading, spacing: 8) {
                        if let jobName = listing.jobName {
                            Text(jobName).font(.caption).foregroundStyle(.secondary)
                        }
                        ListingRow(listing: listing, images: model.images, onSessionExpired: model.expireSession)
                    }
                }
                if model.isLoading || model.state == .idle {
                    ProgressView("listings.loading")
                        .frame(maxWidth: .infinity, minHeight: 44)
                } else if case .failed(let failure) = model.state {
                    Section {
                        Label(LocalizedStringKey(failure.localizationKey), systemImage: "exclamationmark.triangle")
                            .fixedSize(horizontal: false, vertical: true)
                        Button("listings.retry", action: loadMore)
                            .frame(minHeight: 44)
                            .buttonStyle(.bordered)
                    }
                } else {
                    if visibleItems.isEmpty {
                        Text(LocalizedStringKey(model.hasMore ? "listings.empty_page" : "listings.empty"))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if model.hasMore {
                        Button("listings.load_more", action: loadMore)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .buttonStyle(.bordered)
                    }
                    Text("jobs.provider_outcome_unknown")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("listings.title")
        .accessibilityIdentifier("listings.screen")
        .task(id: RequestKey(jobID: selectedJobID, refresh: refreshToken)) {
            actionTask?.cancel()
            actionTask = nil
            await model.changeJob(selectedJobID)
        }
        .refreshable {
            await jobsModel.reload()
            await model.reload()
        }
        .onChange(of: selectedJobID) { _, id in
            if id != nil { selectedRegion = nil }
        }
        .onChange(of: model.state) { _, state in
            if state == .sessionExpired { onSessionExpired() }
        }
        .onDisappear { actionTask?.cancel() }
    }

    private func loadMore() {
        guard actionTask == nil else { return }
        actionTask = Task {
            await model.loadNextPage()
            actionTask = nil
        }
    }
}
