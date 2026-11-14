import SwiftUI

/// The original Fredy preferences comprise appearance/language and the
/// deletion policy (soft/hard, optionally skip confirmation).
struct SettingsPreferencesPage: View {
    @Binding var darkAppearance: Bool
    @State private var deletionChoice = DeletionChoice.unselected
    @State private var skipConfirmation = false

    private enum DeletionChoice: String, CaseIterable {
        case unselected = "غير محدد"
        case soft = "حذف قابل للاستعادة"
        case hard = "حذف نهائي"
    }

    var body: some View {
        VStack(spacing: 16) {
            SettingsCard("المظهر", detail: "يُطبّق اختيار مظهر الآيفون فورًا على هذا التطبيق فقط.") {
                Toggle(isOn: $darkAppearance) {
                    Label("الوضع الداكن", systemImage: "moon.stars")
                }
                .tint(Color.accentColor)
                LabeledContent("لغة التطبيق", value: "العربية")
            }

            SettingsCard("حذف الإعلانات",
                         detail: "في Fredy تختار الحذف القابل للاستعادة أو الحذف النهائي، ويمكنك تجاوز تأكيد الحذف.") {
                Picker("طريقة الحذف", selection: $deletionChoice) {
                    ForEach(DeletionChoice.allCases, id: \.self) { choice in
                        Text(choice.rawValue).tag(choice)
                    }
                }
                .pickerStyle(.menu)
                Toggle("تجاوز رسالة تأكيد الحذف", isOn: $skipConfirmation)
                if deletionChoice == .hard {
                    Label("الحذف النهائي قد يزيل البيانات بحيث لا يمكن استعادتها.",
                          systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
                SettingsReadOnlyNote("طريقة الحذف وخيار التأكيد يُعرضان ويُغيَّران محليًا في هذه الصفحة فقط؛ لا تُجلب القيمة الحقيقية ولا تُحفظ في Fredy.")
            }
        }
        .accessibilityIdentifier("settings.preferences")
    }
}
