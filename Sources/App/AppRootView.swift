import SwiftUI

@MainActor
struct AppRootView: View {
    @State private var model = LoginModel()

    var body: some View {
        Group {
            if case .authenticated = model.state {
                AuthenticatedTabs(service: model.service, onSessionExpired: { model.returnToLogin() })
            } else if case .restoring = model.state {
                ZStack {
                    Color(red: 0.88, green: 0.93, blue: 1.0).ignoresSafeArea()
                    ProgressView("جارٍ التحقق من جلسة الدخول المحفوظة…")
                }
            } else {
                NavigationStack { LoginView(model: model) }
            }
        }
        .task { await model.restoreSession() }
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
