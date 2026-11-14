import SwiftUI

@MainActor
struct AppRootView: View {
    @State private var model = LoginModel()

    var body: some View {
        Group {
            if case .authenticated = model.state {
                AuthenticatedTabs(service: model.service, onSessionExpired: { model.returnToLogin() })
            } else {
                NavigationStack { LoginView(model: model) }
            }
        }
        // Keep the existing Arabic/RTL flow; no shell redesign.
        .environment(\.locale, Locale(identifier: "ar"))
        .environment(\.layoutDirection, .rightToLeft)
    }
}

#Preview("Arabic login") {
    AppRootView()
}

#Preview("Arabic · Dark · Large text") {
    AppRootView()
        .environment(\.dynamicTypeSize, .accessibility3)
        .preferredColorScheme(.dark)
}
