import SwiftUI

struct AppRootView: View {
    var body: some View {
        NavigationStack {
            HomeView()
        }
    }
}

#Preview("English") {
    AppRootView()
        .environment(\.locale, Locale(identifier: "en"))
}

#Preview("Arabic · Dark · Large text") {
    AppRootView()
        .environment(\.locale, Locale(identifier: "ar"))
        .environment(\.layoutDirection, .rightToLeft)
        .environment(\.dynamicTypeSize, .accessibility3)
        .preferredColorScheme(.dark)
}
