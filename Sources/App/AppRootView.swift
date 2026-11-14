import SwiftUI

@MainActor
struct AppRootView: View {
    @State private var model = LoginModel()

    var body: some View {
        NavigationStack {
            if case .authenticated(let user) = model.state {
                AuthenticatedView(user: user)
            } else {
                LoginView(model: model)
            }
        }
        // Only the authentication flow is in scope for this step.
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
