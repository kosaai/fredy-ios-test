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
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("إدارة البحث").font(.caption).foregroundStyle(.secondary)
                    Text("الأبحاث").font(.system(size: 32, weight: .bold, design: .rounded))
                    Text("عمليات البحث المحفوظة ومعلومات تشغيلها الفعلية.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if model.state == .sessionExpired {
                    Label("listings.session_expired", systemImage: "lock")
                    Button("listings.sign_in", action: onSessionExpired)
                        .buttonStyle(.borderedProminent)
                } else {
                    ForEach(model.jobs) { job in
                        Button { onSelect(job.id) } label: {
                            JobRow(job: job)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint(Text("jobs.show_results"))
                    }

                    if model.isLoading || model.state == .idle {
                        ProgressView("jobs.loading")
                            .frame(maxWidth: .infinity, minHeight: 90)
                    } else if case .failed(let failure) = model.state {
                        Label(LocalizedStringKey(failure.localizationKey),
                              systemImage: "exclamationmark.triangle")
                            .fixedSize(horizontal: false, vertical: true)
                        Button("listings.retry", action: retry)
                            .buttonStyle(.bordered)
                            .frame(minHeight: 44)
                    } else if model.jobs.isEmpty {
                        ContentUnavailableView("لا توجد مهام بحث",
                                               systemImage: "magnifyingglass",
                                               description: Text("أضف مهمة جديدة من زر + في الأعلى."))
                    } else {
                        Text("jobs.snapshot_note")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 17)
            .padding(.top, 20)
            .padding(.bottom, 26)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("jobs.title")
        .navigationBarTitleDisplayMode(.inline)
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
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 7) {
                    Text(job.name ?? String(localized: "jobs.untitled",
                                            locale: Locale(identifier: "ar")))
                        .font(.headline)
                        .fixedSize(horizontal: false, vertical: true)
                    if let region = job.regionLabel {
                        Label(region, systemImage: "mappin")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    HStack(spacing: 7) {
                        Circle()
                            .fill(job.running == true ? Color.orange :
                                    job.enabled == true ? Color.green : Color.secondary)
                            .frame(width: 7, height: 7)
                        if let running = job.running {
                            Text(LocalizedStringKey(running ? "jobs.running" : "jobs.not_running"))
                        } else {
                            Text("jobs.unknown")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    if let count = job.numberOfFoundListings {
                        Text(count, format: .number)
                            .font(.system(.title, design: .rounded, weight: .bold))
                    } else {
                        Text("jobs.unavailable")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text("jobs.listing_count")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            HStack {
                Label {
                    if let enabled = job.enabled {
                        Text(LocalizedStringKey(enabled ? "jobs.enabled" : "jobs.disabled"))
                    } else {
                        Text("jobs.unknown")
                    }
                } icon: {
                    Image(systemName: "arrow.clockwise")
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                Spacer()
                Text("jobs.show_results")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(red: 0.74, green: 0.27, blue: 0.23))
                Image(systemName: "chevron.left")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .background(Color(uiColor: .secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 22))
        .accessibilityElement(children: .combine)
    }
}
