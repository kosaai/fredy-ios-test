import SwiftUI

struct AboutView: View {
    var body: some View {
        List {
            Section("about.scope") {
                Text("about.scope_message")
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section("about.design") {
                Text("about.design_message")
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("about.title")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("about.screen")
    }
}

#Preview {
    NavigationStack {
        AboutView()
    }
}
