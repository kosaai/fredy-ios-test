import SwiftUI

@MainActor
struct ListingsView: View {
    @State private var model: ListingsModel
    @State private var actionTask: Task<Void, Never>?
    @State private var searchText = ""
    @State private var priceCeiling = 0
    @State private var minimumRooms = 0
    let jobsModel: JobsModel
    let listingActions: any FredyListingActionServing
    @Binding var selectedJobID: String?
    let refreshToken: Int
    let onSessionExpired: () -> Void

    init(service: any FredyClientServing, jobsModel: JobsModel,
         selectedJobID: Binding<String?>, refreshToken: Int,
         onSessionExpired: @escaping () -> Void) {
        _model = State(initialValue: ListingsModel(service: service))
        self.jobsModel = jobsModel
        self.listingActions = service
        _selectedJobID = selectedJobID
        self.refreshToken = refreshToken
        self.onSessionExpired = onSessionExpired
    }

    private struct RequestKey: Equatable {
        let jobID: String?
        let refresh: Int
    }

    /// Filters only the already fetched page(s), never silently claims server-wide coverage.
    private var displayedItems: [RentalListing] {
        model.items.filter { listing in
            let search = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            let matchesText = search.isEmpty ||
                [listing.title, listing.address, listing.jobName]
                    .compactMap { $0 }.contains { $0.localizedCaseInsensitiveContains(search) }
            let matchesPrice = priceCeiling == 0 ||
                (listing.euroPrice.map { $0 <= Double(priceCeiling) } == true)
            let matchesRooms = minimumRooms == 0 ||
                (listing.rooms.map { $0 >= Double(minimumRooms) } == true)
            return matchesText && matchesPrice && matchesRooms
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("الإيجار").font(.caption).foregroundStyle(.secondary)
                    Text("الإعلانات").font(.system(size: 32, weight: .bold, design: .rounded))
                    Text("تصفّح العقارات المحفوظة من عمليات البحث.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                        TextField("بحث ضمن الإعلانات المحمّلة", text: $searchText)
                            .textInputAutocapitalization(.never)
                    }
                    .padding(13)
                    .background(Color(uiColor: .secondarySystemGroupedBackground),
                                in: RoundedRectangle(cornerRadius: 14))

                    Menu {
                        if selectedJobID != nil {
                            Button {
                                selectedJobID = nil
                            } label: {
                                Label("عرض إعلانات كل الأبحاث", systemImage: "rectangle.stack")
                            }
                            Divider()
                        }
                        Picker("أقصى سعر", selection: $priceCeiling) {
                            Text("كل الأسعار").tag(0)
                            Text("حتى 700 €").tag(700)
                            Text("حتى 1,000 €").tag(1000)
                            Text("حتى 1,500 €").tag(1500)
                        }
                        Picker("عدد الغرف", selection: $minimumRooms) {
                            Text("كل الغرف").tag(0)
                            Text("غرفتان أو أكثر").tag(2)
                            Text("3 غرف أو أكثر").tag(3)
                            Text("4 غرف أو أكثر").tag(4)
                        }
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.title3)
                            .frame(width: 46, height: 46)
                            .background(Color(uiColor: .secondarySystemGroupedBackground),
                                        in: RoundedRectangle(cornerRadius: 14))
                    }
                    .accessibilityLabel("فلاتر النتائج المحمّلة")
                }

                if !model.items.isEmpty {
                    LabeledContent("listings.loaded_count",
                                   value: displayedItems.count.formatted(.number.locale(Locale(identifier: "ar"))))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

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
                }

                if model.state == .sessionExpired {
                    Label("listings.session_expired", systemImage: "lock")
                    Button("listings.sign_in", action: onSessionExpired)
                        .buttonStyle(.borderedProminent)
                } else {
                    ForEach(displayedItems) { listing in
                        ListingRow(listing: listing, images: model.images,
                                   actions: listingActions,
                                   onChanged: {
                                       Task { await model.reload(); await jobsModel.reload() }
                                   },
                                   onSessionExpired: model.expireSession)
                    }

                    if model.isLoading || model.state == .idle {
                        ProgressView("listings.loading")
                            .frame(maxWidth: .infinity, minHeight: 75)
                    } else if case .failed(let failure) = model.state {
                        VStack(spacing: 12) {
                            Label(LocalizedStringKey(failure.localizationKey),
                                  systemImage: "exclamationmark.triangle")
                            Button("listings.retry", action: loadMore)
                                .buttonStyle(.bordered)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    } else {
                        if displayedItems.isEmpty {
                            ContentUnavailableView(
                                "لا توجد نتائج ضمن الإعلانات المحمّلة",
                                systemImage: "line.3.horizontal.decrease.circle",
                                description: Text(model.hasMore
                                    ? "قد تتوفر نتائج أخرى عند تحميل الصفحة التالية."
                                    : "جرّب تغيير فلاتر البحث.")
                            )
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
            .padding(.horizontal, 17)
            .padding(.top, 20)
            .padding(.bottom, 26)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("listings.title")
        .navigationBarTitleDisplayMode(.inline)
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
