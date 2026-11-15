import SwiftUI

@MainActor
struct AuthenticatedTabs: View {
    let service: any FredyClientServing
    let onSessionExpired: () -> Void

    @Environment(\.scenePhase) private var scenePhase
    @State private var expired = false
    @State private var selection: SectionTab = .home
    @State private var selectedJobID: String?
    @State private var addingSearch = false
    @State private var showingBudget = false
    @State private var showingSettings = false
    @State private var darkAppearance = false
    @State private var saveTask: Task<Void, Never>?
    @State private var refreshToken = 0
    @State private var data: AppDataModel
    @State private var jobsModel: JobsModel
    @State private var workflow: AddSearchModel
    @State private var settingsModel: AccountSettingsModel
    @State private var mcpModel: MCPSettingsModel

    private enum SectionTab: Hashable { case home, listings, jobs, map }

    init(service: any FredyClientServing, onSessionExpired: @escaping () -> Void) {
        self.service = service
        self.onSessionExpired = onSessionExpired
        _data = State(initialValue: AppDataModel(service: service))
        let jobs = JobsModel(service: service)
        _jobsModel = State(initialValue: jobs)
        _workflow = State(initialValue: AddSearchModel(service: service, jobsModel: jobs))
        _settingsModel = State(initialValue: AccountSettingsModel(service: service))
        _mcpModel = State(initialValue: MCPSettingsModel(service: service))
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
                    HomeView(service: service, jobsModel: jobsModel, data: data,
                             onShowListings: { selection = .listings },
                             onShowJobs: { selection = .jobs },
                             onSessionExpired: expire)
                        .toolbar { topActions }
                }
                .tabItem { Label("الرئيسية", systemImage: "house.fill") }
                .tag(SectionTab.home)

                NavigationStack {
                    ListingsView(service: service, jobsModel: jobsModel, data: data,
                                 selectedJobID: $selectedJobID, refreshToken: refreshToken,
                                 onSessionExpired: expire)
                        .toolbar { topActions }
                }
                .tabItem { Label("tabs.listings", systemImage: "building.2.fill") }
                .tag(SectionTab.listings)

                NavigationStack {
                    JobsView(service: service, model: jobsModel,
                             onRefresh: { await data.refresh(jobs: jobsModel, force: true) }, onSelect: selectJob,
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
                    RentalMapView(data: data, jobsModel: jobsModel, actions: service, onSessionExpired: expire)
                        .toolbar { topActions }
                }
                .tabItem { Label("الخريطة", systemImage: "map.fill") }
                .tag(SectionTab.map)
            }
            .tint(Color(red: 0.31, green: 0.38, blue: 0.99))
            .preferredColorScheme(accountColorScheme)
            .task {
                data.observationPaused = scenePhase != .active || workflow.isBusy
                await jobsModel.loadIfNeeded()
                await settingsModel.loadIfNeeded()
                await data.refresh(jobs: jobsModel)
            }
            .onChange(of: jobsModel.state) { _, state in
                if state == .sessionExpired { expire() }
            }
            .onChange(of: workflow.phase) { _, phase in
                if phase == .sessionExpired { expire() }
            }
            .onChange(of: settingsModel.sessionExpired) { _, value in
                if value { expire() }
            }
            .onChange(of: mcpModel.sessionExpired) { _, value in
                if value { expire() }
            }
            .onChange(of: settingsModel.saved["theme"]) { _, value in
                if let theme = value.stringValue, ["light", "dark"].contains(theme) {
                    darkAppearance = theme == "dark"
                }
            }
            .onChange(of: service.synchronization.revision) { _, _ in
                if service.synchronization.expired { expire() }
                else { data.scheduleRefresh(jobs: jobsModel) }
            }
            .onChange(of: data.sessionExpired) { _, value in if value { expire() } }
            .onChange(of: jobsModel.jobs) { old, fresh in
                if !old.isEmpty, old != fresh { data.scheduleRefresh(jobs: jobsModel, includeJobs: false) }
            }
            .onChange(of: jobsModel.runRevision) { _, _ in
                if !workflow.isBusy, scenePhase == .active { data.observeSearch(jobs: jobsModel) }
            }
            .onChange(of: workflow.isBusy) { _, busy in
                data.observationPaused = busy || scenePhase != .active
                if busy { data.stopSearchObservation() }
            }
            .onChange(of: scenePhase) { _, phase in
                data.observationPaused = phase != .active || workflow.isBusy
                if phase != .active { data.stopSearchObservation() }
                else {
                    // Returning from Safari must not clear map markers, camera, or an open listing sheet.
                    // Server mutations and explicit refresh actions still invalidate data as before.
                    if !workflow.isBusy, jobsModel.jobs.contains(where: { $0.running == true }) {
                        data.observeSearch(jobs: jobsModel)
                    }
                }
            }
            .onChange(of: jobsModel.pendingAction) { old, fresh in
                if old != nil, fresh == nil { data.scheduleRefresh(jobs: jobsModel, includeJobs: false) }
            }
            .onChange(of: workflow.resultsRevision) { _, _ in data.scheduleRefresh(jobs: jobsModel) }
            .sheet(isPresented: $showingBudget) {
                RentalBudgetView()
            }
            .sheet(isPresented: $showingSettings) {
                RentalSettingsView(darkAppearance: $darkAppearance, model: settingsModel, mcpModel: mcpModel)
            }
            .sheet(isPresented: $addingSearch) {
                AddSearchView(model: workflow, onSave: saveSearch, onSelect: selectJob)
            }
            .onDisappear { saveTask?.cancel() }
        }
    }

    private var accountColorScheme: ColorScheme? {
        switch settingsModel.saved["theme"].stringValue ?? "" {
        case "light": return .light
        case "dark": return .dark
        default: return darkAppearance ? .dark : nil
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
        guard !expired else { return }
        data.expireSession()
        jobsModel.expireSession()
        settingsModel.expireSession()
        mcpModel.expireSession()
        workflow.expireSession()
        expired = true
        addingSearch = false
        showingBudget = false
        showingSettings = false
        saveTask?.cancel()
    }
}
