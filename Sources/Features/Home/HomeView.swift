import SwiftUI

/// Overview presents only listings and search jobs returned by the authenticated Fredy API.
@MainActor
struct HomeView: View {
    let data: AppDataModel
    private var model: ListingsModel { data.home }
    private var dashboard: FindHausDashboardSnapshot? { data.dashboard }
    private var dashboardLoading: Bool { data.dashboardState == .loading }
    private var dashboardError: String? {
        guard case .failed(let failure) = data.dashboardState else { return nil }
        switch failure {
        case .dashboardDecoding:
            return "تعذّر تحليل بيانات الإحصاءات؛ صيغة البيانات غير متوافقة مع التطبيق."
        case .server:
            return "فشل طلب إحصاءات الخادم (HTTP). أعد المحاولة لاحقًا."
        case .accessDenied:
            return "رفض الخادم صلاحية الوصول إلى الإحصاءات."
        case .rateLimited:
            return "رفض الخادم طلب الإحصاءات لكثرة الطلبات؛ انتظر ثم أعد التحميل."
        case .network:
            return "تعذّر الاتصال لتحميل الإحصاءات. تحقق من الشبكة."
        case .invalidResponse:
            return "استجابة الإحصاءات ليست بصيغة JSON المتوقعة."
        case .sessionExpired: return nil
        case .invalidInput, .conflict, .imageUnavailable:
            return "تعذّر إتمام طلب إحصاءات الخادم."
        }
    }
    @State private var confirmingSearch = false
    @State private var startingSearch = false
    @State private var searchNotice: String?
    @State private var showingSearchNotice = false

    let jobsModel: JobsModel
    let dashboardService: any FredyDashboardServing
    let jobsService: any FredyJobsServing
    let listingActions: any FredyListingActionServing
    let onShowListings: () -> Void
    let onShowJobs: () -> Void
    let onSessionExpired: () -> Void

    init(service: any FredyClientServing, jobsModel: JobsModel, data: AppDataModel,
         onShowListings: @escaping () -> Void,
         onShowJobs: @escaping () -> Void,
         onSessionExpired: @escaping () -> Void) {
        self.data = data
        self.jobsModel = jobsModel
        self.dashboardService = service
        self.jobsService = service
        self.listingActions = service
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
                // Fredy dashboard metrics, never fabricated from a single loaded page.
                // Keep this overview compact; detailed listings and jobs follow below.
                VStack(alignment: .leading, spacing: 10) {
                    Text(Date.now, format: .dateTime.weekday(.wide).month(.wide).day()
                        .locale(Locale(identifier: "ar")))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let count = dashboard?.newToday {
                        Text(count == 0 ? "لا توجد إعلانات جديدة اليوم" :
                             "\(count) إعلان جديد اليوم")
                            .font(.system(.title2, design: .rounded, weight: .bold))
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("home.today_count")
                    } else {
                        Text(dashboardLoading ? "جار تحميل إعلانات اليوم..." :
                             "عدد الإعلانات الجديدة اليوم غير متاح")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    HStack(alignment: .top, spacing: 7) {
                        Circle()
                            .fill(enabledJobsCount > 0 && jobsModel.state == .loaded ?
                                  Color.green : Color.secondary)
                            .frame(width: 7, height: 7)
                            .padding(.top, 4)

                        VStack(alignment: .leading, spacing: 3) {
                            if jobsModel.state == .loaded && enabledJobsCount == 0 {
                                Text("لا توجد مهام بحث دوري مفعّلة")
                            } else if enabledJobsCount > 0,
                                      let minutes = dashboard?.intervalMinutes {
                                Text("البحث الدوري كل \(minutes) دقيقة")
                            } else {
                                Text("جدولة البحث غير متاحة")
                            }

                            if let last = dashboard?.lastRunDate {
                                HStack(spacing: 5) {
                                    Text("آخر تشغيل:")
                                    Text(last, style: .relative)
                                }
                            }

                            if enabledJobsCount > 0, let next = dashboard?.nextRunDate {
                                HStack(spacing: 5) {
                                    Text("التشغيل القادم:")
                                    Text(next, style: .relative)
                                }
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }

                    HStack(alignment: .center, spacing: 10) {
                        Button {
                            confirmingSearch = true
                        } label: {
                            HStack(spacing: 8) {
                                if startingSearch {
                                    ProgressView().tint(.white)
                                } else {
                                    Image(systemName: "play.fill")
                                }
                                Text(startingSearch ? "جار إرسال طلب البحث" : "ابحث الآن")
                                    .font(.subheadline.weight(.semibold))
                            }
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color(red: 0.31, green: 0.38, blue: 0.99))
                        .frame(minHeight: 44)
                        .disabled(startingSearch || jobsModel.state != .loaded ||
                                  jobsModel.jobs.isEmpty)
                        .accessibilityIdentifier("home.search_now")

                        if dashboardError != nil {
                            Button("إعادة تحميل الإحصاءات") {
                                Task { await reloadDashboard() }
                            }
                            .font(.caption.weight(.semibold))
                            .frame(minHeight: 44)
                        }
                        Spacer(minLength: 0)
                    }

                    if let dashboardError {
                        Label(dashboardError, systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    Color(uiColor: .secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 22)
                )
                .accessibilityIdentifier("home.search_summary")

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
                        Task { await data.refresh(jobs: jobsModel, force: true) }
                    }
                } else if model.items.isEmpty {
                    ContentUnavailableView("لا توجد إعلانات لعرضها",
                                           systemImage: "building.2",
                                           description: Text("لا توجد نتائج محمّلة من الخادم."))
                } else {
                    ForEach(Array(model.items.prefix(3))) { listing in
                        ListingRow(listing: listing, images: model.images,
                                   actions: listingActions,
                                   onChanged: {
                                       data.scheduleRefresh(jobs: jobsModel)
                                   },
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
            await data.refresh(jobs: jobsModel)
        }
        .refreshable {
            await data.refresh(jobs: jobsModel, force: true)
        }
        .confirmationDialog(
            "تشغيل البحث الآن لكل المهام؟",
            isPresented: $confirmingSearch,
            titleVisibility: .visible
        ) {
            Button("تشغيل البحث مرة واحدة") { startSearchNow() }
            Button("إلغاء", role: .cancel) {}
        } message: {
            Text("سيرسل التطبيق طلبًا واحدًا إلى Fredy. قبول الطلب لا يعني اكتمال البحث أو العثور على إعلانات جديدة.")
        }
        .alert("حالة طلب البحث", isPresented: $showingSearchNotice) {
            Button("حسنًا", role: .cancel) {}
        } message: {
            Text(searchNotice ?? "لا توجد نتيجة متاحة.")
        }
        .onChange(of: model.state) { _, state in
            if state == .sessionExpired { onSessionExpired() }
        }
    }

    private func reloadDashboard() async {
        await data.refresh(jobs: jobsModel, force: true)
    }

    private func startSearchNow() {
        guard !startingSearch, jobsModel.state == .loaded,
              !jobsModel.jobs.isEmpty else { return }
        startingSearch = true

        Task {
            defer { startingSearch = false }
            do {
                // startAll has no per-request notification suppression. Check the entire fresh
                // visible collection, including disabled/shared jobs, rather than a cached subset.
                let freshJobs = try await jobsService.fetchJobs()
                try Task.checkCancellation()
                guard !data.sessionExpired, jobsModel.state != .sessionExpired else {
                    onSessionExpired()
                    return
                }
                guard !freshJobs.isEmpty,
                      freshJobs.allSatisfy({ $0.hasNoNotificationChannels == true }) else {
                    searchNotice = "لم يُرسل طلب تشغيل: توجد قنوات تنبيه أو أن بياناتها غير مؤكدة، أو لا توجد مهام للتحقق منها. لم نغيّر أي قناة."
                    showingSearchNotice = true
                    return
                }
                try await dashboardService.startAllSearches()
                data.observeSearch(jobs: jobsModel)
                searchNotice = "قبل الخادم طلب تشغيل البحث. النتائج ليست جاهزة بعد؛ اسحب لتحديث الصفحة لاحقًا."
            } catch let failure as ListingsFailure {
                if failure == .sessionExpired {
                    onSessionExpired()
                    return
                }
                searchNotice = "لم يؤكد الخادم بدء البحث. لم تُرسل أي طلبات إضافية."
            } catch {
                searchNotice = "تعذر إرسال طلب البحث. يمكنك المحاولة يدويًا لاحقًا."
            }
            showingSearchNotice = true
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
