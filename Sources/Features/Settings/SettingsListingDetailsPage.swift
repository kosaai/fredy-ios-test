import SwiftUI

/// Fredy v31 listing-details preferences: provider-specific detail fetching and
/// blacklist checks on downloaded descriptions. Selection is intentionally
/// unavailable until the actual saved provider settings are read.
struct SettingsListingDetailsPage: View {
    var body: some View {
        VStack(spacing: 16) {
            SettingsCard("جلب تفاصيل الإعلانات من المزوّدين",
                         detail: "يختار الخادم البوابات التي يُجلب منها وصف الإعلان الكامل. قد يؤدي ذلك إلى طلب إضافي لكل إعلان، لذا يُفضّل عدم تشغيلها دون حاجة.") {
                LabeledContent("المزوّدون المحددون") {
                    Text("لم تُحمَّل إعدادات الحساب")
                        .foregroundStyle(.secondary)
                }
                Button {
                    // Intentionally no operation; provider settings are not loaded.
                } label: {
                    Label("اختيار المزوّدين", systemImage: "checklist")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(true)

                SettingsReadOnlyNote("عند ربط إعدادات الخادم سيظهر هنا اختيار متعدد من المزوّدين الحقيقيين، وليس قائمة أسماء ثابتة.")
            }

            SettingsCard("تصفية الكلمات المحظورة",
                         detail: "يسمح الخادم بتطبيق القائمة السوداء على نص الوصف الكامل الذي يرجعه المزوّد بعد جلب تفاصيل الإعلان.") {
                Toggle("تفعيل التصفية على تفاصيل المزوّد", isOn: .constant(false))
                    .disabled(true)
                SettingsReadOnlyNote("لا يمكن تحديد هذا الخيار حتى تُحمَّل المزوّدات المحفوظة وقيمة التصفية من الخادم.")
            }
        }
        .accessibilityIdentifier("settings.listing_details")
    }
}
