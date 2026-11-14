import SwiftUI

/// Overview presents only listings and search jobs returned by the authenticated Fredy API.
@MainActor
struct HomeView: View {
    @State private var model: ListingsModel
    let jobsModel: JobsModel
    let onShowListings: () -> Void
    let onShowJobs: () -> Void
    let onSessionExpired: () -> Void

    init(service: any FredyListingsServing, jobsModel: JobsModel,
         onShowListings: @escaping () -> Void,
         onShowJobs: @escaping () -> Void,
         onSessionExpired: @escaping () -> Void) {
        _model = State(initialValue: ListingsModel(service: service))
        self.jobsModel = jobsModel
        self.onShowListings = onShowListings
        self.onShowJobs = onShowJobs
        self.onSessionExpired = onSessionExpired
    }

    private var enabledJobsCount: Int {
        jobsModel.jobs.filter { $0.enabled == true }.count
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("متابعة البحث عن الإيجار")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.72))
                    Text("عقاراتك في مكان واحد")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("نتائج عمليات البحث المحفوظة")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.76))
                    Button(action: onShowListings) {
                        Label("عرض الإعلانات", systemImage: "arrow.up.left")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.white)
                    .foregroundStyle(.black)
                    .padding(.top, 6)
                }
                .padding(22)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    LinearGradient(colors: [.init(red: 0.31, green: 0.38, blue: 0.99),
                                            .init(red: 0.25, green: 0.30, blue: 0.81)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 26)
                )

                HStack(spacing: 10) {
                    metric(value: model.items.count, title: "إعلانات محمّلة",
                           symbol: "building.2")
                    metric(value: jobsModel.jobs.count, title: "عمليات البحث",
                           symbol: "magnifyingglass")
                    metric(value: enabledJobsCount, title: "بحث دوري مفعّل",
                           symbol: "arrow.clockwise")
                }

                HStack {
                    Text("أحدث الإعلانات المحمّلة")
                        .font(.title3.bold())
                    Spacer()
                    Button("عرض الكل", action: onShowListings)
                        .font(.subheadline.weight(.semibold))
                }

                if model.state == .idle || model.isLoading {
                    ProgressView("listings.loading")
                        .frame(maxWidth: .infinity, minHeight: 95)
                } else if case .failed(let failure) = model.state {
                    Label(LocalizedStringKey(failure.localizationKey),
                          systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.secondary)
                    Button("listings.retry") {
                        Task { await model.loadInitialIfNeeded() }
                    }
                } else if model.items.isEmpty {
                    ContentUnavailableView("لا توجد إعلانات لعرضها",
                                           systemImage: "building.2",
                                           description: Text("لا توجد نتائج محمّلة من الخادم."))
                } else {
                    ForEach(Array(model.items.prefix(3))) { listing in
                        ListingRow(listing: listing, images: model.images,
                                   onSessionExpired: model.expireSession)
                    }
                }

                HStack {
                    Text("مهام البحث").font(.title3.bold())
                    Spacer()
                    Button("كل المهام", action: onShowJobs)
                        .font(.subheadline.weight(.semibold))
                }
                if jobsModel.isLoading {
                    ProgressView("jobs.loading")
                } else if jobsModel.jobs.isEmpty {
                    Text("لا توجد مهام محفوظة.")
                        .foregroundStyle(.secondary)
                } else {
                    VStack(spacing: 0) {
                        ForEach(jobsModel.jobs.prefix(4)) { job in
                            HStack {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(job.name ?? String(localized: "jobs.untitled",
                                                            locale: Locale(identifier: "ar")))
                                        .font(.subheadline.weight(.semibold))
                                    Text(job.enabled == true ? "الجدولة مفعّلة" :
                                            job.enabled == false ? "الجدولة متوقفة" : "حالة الجدولة غير معروفة")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if let count = job.numberOfFoundListings {
                                    Text(count, format: .number)
                                        .font(.title3.weight(.bold))
                                } else {
                                    Text("—").foregroundStyle(.secondary)
                                }
                            }
                            .padding(16)
                            if job.id != jobsModel.jobs.prefix(4).last?.id {
                                Divider().padding(.horizontal, 16)
                            }
                        }
                    }
                    .background(Color(uiColor: .secondarySystemGroupedBackground),
                                in: RoundedRectangle(cornerRadius: 21))
                }
            }
            .padding(.horizontal, 17)
            .padding(.top, 20)
            .padding(.bottom, 26)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("الرئيسية")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("home.screen")
        .task {
            await jobsModel.loadIfNeeded()
            await model.loadInitialIfNeeded()
        }
        .refreshable {
            await jobsModel.reload()
            await model.reload()
        }
        .onChange(of: model.state) { _, state in
            if state == .sessionExpired { onSessionExpired() }
        }
    }

    private func metric(value: Int, title: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: symbol)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(value, format: .number)
                .font(.system(.title2, design: .rounded, weight: .bold))
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 90, alignment: .leading)
        .padding(12)
        .background(Color(uiColor: .secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 17))
    }
}
