import SwiftUI

/// Fredy web supports external notification adapters, but the iPhone project
/// explicitly excludes Telegram and other third-party delivery integrations.
struct SettingsNotificationsPage: View {
    var body: some View {
        VStack(spacing: 16) {
            SettingsCard("قنوات الإشعار",
                         detail: "يدير Fredy الأصلي قنوات إشعار قابلة للإضافة والتعديل والاختبار والحذف، وتُربط بمهام البحث.") {
                Label("إشعارات تطبيق الآيفون", systemImage: "bell.badge")
                    .font(.headline)

                Text("يقتصر هذا التطبيق على التنبيهات من داخل التطبيق نفسه. لم تُربط خدمة APNs بعد، لذلك لا توجد قناة مفعّلة أو بيانات قناة يُمكن عرضها.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                LabeledContent("قائمة القنوات") {
                    Text("لم تُحمَّل")
                        .foregroundStyle(.secondary)
                }

                Button {
                    // Native push notification setup is outside the authorized UI scope.
                } label: {
                    Label("إعداد قناة إشعارات التطبيق", systemImage: "plus.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(true)

                SettingsReadOnlyNote("أوامر تجربة القناة وتعديلها واستنساخها وحذفها ستظهر فقط بعد توفر بيانات حقيقية وربط الإشعارات الأصلية. لن تُضاف قنوات خارجية.")
            }
        }
        .accessibilityIdentifier("settings.notifications")
    }
}
