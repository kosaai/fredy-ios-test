import SwiftUI

@MainActor
struct ListingsView: View {
    @State private var model: ListingsModel
    @State private var actionTask: Task<Void, Never>?
    let onSessionExpired: () -> Void

    init(service: any FredyListingsServing, onSessionExpired: @escaping () -> Void) {
        _model = State(initialValue: ListingsModel(service: service))
        self.onSessionExpired = onSessionExpired
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
                if !model.items.isEmpty {
                    LabeledContent("listings.loaded_count", value: model.items.count.formatted(.number.locale(Locale(identifier: "ar"))))
                }
                ForEach(model.items) { listing in
                    ListingRow(listing: listing, images: model.images, onSessionExpired: model.expireSession)
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
                    if model.items.isEmpty {
                        Text(LocalizedStringKey(model.hasMore ? "listings.empty_page" : "listings.empty"))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if model.hasMore {
                        Button("listings.load_more", action: loadMore)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .buttonStyle(.bordered)
                    }
                }
            }
        }
        .navigationTitle("listings.title")
        .accessibilityIdentifier("listings.screen")
        .task { await model.loadInitialIfNeeded() }
        .refreshable { await model.reload() }
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
