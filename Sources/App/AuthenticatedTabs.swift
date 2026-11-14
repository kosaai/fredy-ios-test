import SwiftUI

@MainActor
struct AuthenticatedTabs: View {
    let service: any FredyClientServing
    let onSessionExpired: () -> Void
    @State private var expired = false
    @State private var selection: SectionTab = .listings

    private enum SectionTab: Hashable { case listings, jobs }

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
                    ListingsView(service: service, onSessionExpired: expire)
                }
                .tabItem { Label("tabs.listings", systemImage: "house.fill") }
                .tag(SectionTab.listings)

                NavigationStack {
                    JobsView(service: service, onSessionExpired: expire)
                }
                .tabItem { Label("tabs.jobs", systemImage: "list.bullet.rectangle.fill") }
                .tag(SectionTab.jobs)
            }
        }
    }

    private func expire() {
        // Remove BOTH tabs and their view-owned data/tasks on any detected 401.
        expired = true
    }
}
