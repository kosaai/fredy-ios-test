import SwiftUI

struct HomeView: View {
    var body: some View {
        List {
            Section {
                InfoBlock(
                    title: "home.title",
                    message: "home.message",
                    systemImage: "house"
                )
                .padding(.vertical, 12)
            }

            Section {
                Label("home.local", systemImage: "iphone")
                Text("home.note")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section {
                NavigationLink {
                    AboutView()
                } label: {
                    Label("about.title", systemImage: "info.circle")
                        .frame(minHeight: 44)
                }
                .accessibilityIdentifier("home.about")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(Text(verbatim: "Fredy Test"))
        .accessibilityIdentifier("home.screen")
    }
}

#Preview {
    NavigationStack {
        HomeView()
    }
}
