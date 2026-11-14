import SwiftUI

@MainActor
struct AuthenticatedView: View {
    let user: FredyUser

    var body: some View {
        List {
            Section {
                Label("login.success", systemImage: "checkmark.circle")
                    .font(.headline)
                Text(user.username)
                    .textSelection(.disabled)
                    .accessibilityIdentifier("login.authenticated_username")
                Text("login.success_note")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .navigationTitle("login.title")
        .accessibilityIdentifier("login.authenticated")
    }
}
