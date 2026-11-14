import SwiftUI

@MainActor
struct AuthenticatedTabs: View {
    let service: any FredyClientServing
    let onSessionExpired: () -> Void
    @State private var expired = false
    @State private var selection: SectionTab = .listings
    @State private var selectedJobID: String?
    @State private var addingSearch = false
    @State private var saveTask: Task<Void, Never>?
    @State private var refreshToken = 0
    @State private var jobsModel: JobsModel
    @State private var workflow: AddSearchModel

    private enum SectionTab: Hashable { case listings, jobs }

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
            // iOS 17-compatible native tabs, one navigation stack per section.
            TabView(selection: $selection) {
                NavigationStack {
                    ListingsView(service: service, jobsModel: jobsModel,
                                 selectedJobID: $selectedJobID, refreshToken: refreshToken,
                                 onSessionExpired: expire)
                        .toolbar { addSearchButton }
                }
                .tabItem { Label("tabs.listings", systemImage: "house.fill") }
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
                        .toolbar { addSearchButton }
                }
                .tabItem { Label("tabs.jobs", systemImage: "list.bullet.rectangle.fill") }
                .tag(SectionTab.jobs)
            }
            .task { await jobsModel.loadIfNeeded() }
            .onChange(of: jobsModel.state) { _, state in
                if state == .sessionExpired { expire() }
            }
            .onChange(of: workflow.phase) { _, phase in
                if phase == .sessionExpired { expire() }
            }
            .onChange(of: workflow.resultsRevision) { _, _ in refreshToken += 1 }
            .sheet(isPresented: $addingSearch, onDismiss: { refreshToken += 1 }) {
                AddSearchView(model: workflow, onSave: saveSearch, onSelect: selectJob)
            }
            .onDisappear { saveTask?.cancel() }
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
        // Remove BOTH tabs and their view-owned data/tasks on any detected 401.
        expired = true
        addingSearch = false
        saveTask?.cancel()
    }
}
