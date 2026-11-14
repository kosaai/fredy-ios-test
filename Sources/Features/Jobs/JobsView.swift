import SwiftUI

@MainActor
struct JobsView: View {
    @State private var model: JobsModel
    @State private var retryTask: Task<Void, Never>?
    let onSessionExpired: () -> Void
    let onSelect: (String) -> Void

    init(service: any FredyJobsServing, model: JobsModel? = nil,
         onSelect: @escaping (String) -> Void = { _ in },
         onSessionExpired: @escaping () -> Void) {
        _model = State(initialValue: model ?? JobsModel(service: service))
        self.onSessionExpired = onSessionExpired
        self.onSelect = onSelect
    }

    var body: some View {
        List {
            if model.state == .sessionExpired {
                Label("listings.session_expired", systemImage: "lock")
                Button("listings.sign_in", action: onSessionExpired)
                    .buttonStyle(.borderedProminent)
                    .frame(minHeight: 44)
            } else {
                Section {
                    ForEach(model.jobs) { job in
                        Button { onSelect(job.id) } label: {
                            JobRow(job: job)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint(Text("jobs.show_results"))
                    }
                } footer: {
                    if !model.jobs.isEmpty { Text("jobs.snapshot_note") }
                }
                if model.isLoading || model.state == .idle {
                    ProgressView("jobs.loading")
                        .frame(maxWidth: .infinity, minHeight: 44)
                } else if case .failed(let failure) = model.state {
                    Label(LocalizedStringKey(failure.localizationKey), systemImage: "exclamationmark.triangle")
                        .fixedSize(horizontal: false, vertical: true)
                    Button("listings.retry", action: retry)
                        .buttonStyle(.bordered)
                        .frame(minHeight: 44)
                } else if model.jobs.isEmpty {
                    Text("jobs.empty")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("jobs.title")
        .accessibilityIdentifier("jobs.screen")
        .task { await model.loadIfNeeded() }
        .refreshable { await model.reload() }
        .onChange(of: model.state) { _, state in
            if state == .sessionExpired { onSessionExpired() }
        }
        .onDisappear { retryTask?.cancel() }
    }

    private func retry() {
        guard retryTask == nil else { return }
        retryTask = Task {
            await model.reload()
            retryTask = nil
        }
    }
}

@MainActor
private struct JobRow: View {
    let job: SearchJob

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(job.name ?? String(localized: "jobs.untitled", locale: Locale(identifier: "ar")))
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)
            LabeledContent("jobs.enabled_status") {
                if let enabled = job.enabled {
                    Text(LocalizedStringKey(enabled ? "jobs.enabled" : "jobs.disabled"))
                } else {
                    Text("jobs.unknown")
                }
            }
            LabeledContent("jobs.running_status") {
                if let running = job.running {
                    Text(LocalizedStringKey(running ? "jobs.running" : "jobs.not_running"))
                } else {
                    Text("jobs.unknown")
                }
            }
            LabeledContent("jobs.listing_count") {
                if let count = job.numberOfFoundListings {
                    Text(count, format: .number.locale(Locale(identifier: "ar")))
                } else {
                    Text("jobs.unavailable")
                }
            }
        }
        .padding(.vertical, 8)
    }
}
