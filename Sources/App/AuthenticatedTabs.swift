import SwiftUI

@MainActor
struct AuthenticatedTabs: View {
    let service: any FredyClientServing
    let onSessionExpired: () -> Void

    @State private var expired = false
    @State private var selection: SectionTab = .home
    @State private var selectedJobID: String?
    @State private var addingSearch = false
    @State private var showingBudget = false
    @State private var showingSettings = false
    @State private var darkAppearance = false
    @State private var saveTask: Task<Void, Never>?
    @State private var refreshToken = 0
    @State private var jobsModel: JobsModel
    @State private var workflow: AddSearchModel

    private enum SectionTab: Hashable { case home, listings, jobs, map }

    init(service: any FredyClientServing, onSessionExpired: @escaping () -> Void) {
        self.service = service
        self.onSessionExpired = onSessionExpired
        let jobs = JobsModel(service: service)
        _jobsModel = State(initialValue: jobs)
        _workflow = State(initialValue: AddSearchModel(service: service, jobsModel: jobs))
    }

    var body: some View {
        if expired {
            NavigationStack {
                List {
                    Label("listings.session_expired", systemImage: "lock")
                    Button("listings.sign_in", action: onSessionExpired)
                        .frame(minHeight: 44)
                        .buttonStyle(.borderedProminent)
                }
                .navigationTitle("login.title")
            }
        } else {
            // Native TabView adopts the system's Liquid Glass appearance on supported iOS versions.
            TabView(selection: $selection) {
                NavigationStack {
                    HomeView(service: service, jobsModel: jobsModel,
                             onShowListings: { selection = .listings },
                             onShowJobs: { selection = .jobs },
                             onSessionExpired: expire)
                        .toolbar { topActions }
                }
                .tabItem { Label("الرئيسية", systemImage: "house.fill") }
                .tag(SectionTab.home)

                NavigationStack {
                    ListingsView(service: service, jobsModel: jobsModel,
                                 selectedJobID: $selectedJobID, refreshToken: refreshToken,
                                 onSessionExpired: expire)
                        .toolbar { topActions }
                }
                .tabItem { Label("tabs.listings", systemImage: "building.2.fill") }
                .tag(SectionTab.listings)

                NavigationStack {
                    JobsView(service: service, model: jobsModel, onSelect: selectJob,
                             onSessionExpired: expire)
                        .safeAreaInset(edge: .bottom) {
                            if workflow.phase != .idle {
                                SearchProgressView(model: workflow)
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(.regularMaterial)
                            }
                        }
                        .toolbar {
                            topActions
                            addSearchButton
                        }
                }
                .tabItem { Label("tabs.jobs", systemImage: "magnifyingglass") }
                .tag(SectionTab.jobs)

                NavigationStack {
                    RentalMapView()
                        .toolbar { topActions }
                }
                .tabItem { Label("الخريطة", systemImage: "map.fill") }
                .tag(SectionTab.map)
            }
            .tint(Color(red: 0.74, green: 0.27, blue: 0.23))
            .preferredColorScheme(darkAppearance ? .dark : nil)
            .task { await jobsModel.loadIfNeeded() }
            .onChange(of: jobsModel.state) { _, state in
                if state == .sessionExpired { expire() }
            }
            .onChange(of: workflow.phase) { _, phase in
                if phase == .sessionExpired { expire() }
            }
            .onChange(of: workflow.resultsRevision) { _, _ in refreshToken += 1 }
            .sheet(isPresented: $showingBudget) {
                RentalBudgetView()
            }
            .sheet(isPresented: $showingSettings) {
                RentalSettingsView(darkAppearance: $darkAppearance)
            }
            .sheet(isPresented: $addingSearch, onDismiss: { refreshToken += 1 }) {
                AddSearchView(model: workflow, onSave: saveSearch, onSelect: selectJob)
            }
            .onDisappear { saveTask?.cancel() }
        }
    }

    @ToolbarContentBuilder
    private var topActions: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button {
                showingBudget = true
            } label: {
                Label("الميزانية", systemImage: "wallet.pass")
            }
            .accessibilityIdentifier("navigation.budget")

            Button {
                showingSettings = true
            } label: {
                Label("الإعدادات", systemImage: "gearshape")
            }
            .accessibilityIdentifier("navigation.settings")
        }
    }

    @ToolbarContentBuilder
    private var addSearchButton: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                workflow.prepareNewDraft()
                addingSearch = true
            } label: {
                Label("jobs.add_title", systemImage: "plus")
            }
            .accessibilityIdentifier("jobs.add_search")
        }
    }

    private func saveSearch() {
        guard saveTask == nil, workflow.canSubmit else { return }
        saveTask = Task {
            await workflow.saveAndSearch()
            saveTask = nil
        }
    }

    private func selectJob(_ id: String) {
        selectedJobID = id
        refreshToken += 1
        selection = .listings
    }

    private func expire() {
        expired = true
        addingSearch = false
        showingBudget = false
        showingSettings = false
        saveTask?.cancel()
    }
}
