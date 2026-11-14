import SwiftUI

/// Presentation settings only: no imaginary server settings or notification links.
struct RentalSettingsView: View {
    @Binding var darkAppearance: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("المظهر") {
                    Toggle(isOn: $darkAppearance) {
                        Label("الوضع الداكن", systemImage: "moon.stars")
                    }
                    .tint(Color(red: 0.74, green: 0.27, blue: 0.23))
                    LabeledContent("لغة الواجهة", value: "العربية")
                }

                Section("البحث") {
                    LabeledContent {
                        Text("Fredy")
                            .foregroundStyle(.secondary)
                    } label: {
                        Label("مصدر البيانات", systemImage: "server.rack")
                    }
                    Text("جدولة البحث والإعدادات الإدارية لا تُعدَّل من هذه الواجهة حاليًا.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("الخصوصية") {
                    Label("لا توجد تكاملات مع Telegram أو خدمات إشعارات خارجية في واجهة الآيفون.", systemImage: "hand.raised")
                        .font(.footnote)
                }
            }
            .navigationTitle("الإعدادات")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("إغلاق", action: { dismiss() })
                }
            }
            .accessibilityIdentifier("settings.screen")
        }
    }
}
