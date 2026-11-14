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
        .tint(Color(red: 0.31, green: 0.38, blue: 0.99))
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
