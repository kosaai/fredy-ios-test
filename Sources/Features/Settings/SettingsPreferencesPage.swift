import SwiftUI

@MainActor
struct SettingsPreferencesPage: View {
    @Binding var darkAppearance: Bool
    let model: AccountSettingsModel

    var body: some View {
        VStack(spacing: 16) {
            SettingsCard("المظهر", detail: "يُحمّل اختيار الحساب؛ لا يُطبّق تعديل المسودة إلا بعد الحفظ والتحقق.") {
                Picker("مظهر الحساب", selection: Binding(
                    get: { model.draft["theme"].stringValue ?? "" },
                    set: { model.draft["theme"] = .string($0) }
                )) {
                    Text("غير محفوظ / غير معروف").tag("")
                    Text("فاتح").tag("light")
                    Text("داكن").tag("dark")
                }
                LabeledContent("لغة التطبيق", value: "العربية")
                LabeledContent("لغة حساب Fredy", value: model.saved["language"].stringValue ?? "غير محفوظة")
                SettingsSaveControl(model: model, key: .theme)
            }
            .disabled(!model.canEdit(.theme))

            SettingsCard("حذف الإعلانات", detail: "تُقرأ سياسة الحساب الفعلية. الحذف النهائي غير مسموح في FindHaus ولا يفعّل هذا الخيار أي حذف.") {
                Picker("طريقة الحذف", selection: Binding(
                    get: { model.draft["listing_deletion_preference"]["hardDelete"].boolValue.map { $0 ? "hard" : "soft" } ?? "" },
                    set: { choice in
                        guard choice == "soft" else { return }
                        model.draft["listing_deletion_preference"]["hardDelete"] = .bool(false)
                        if model.draft["listing_deletion_preference"]["skipPrompt"].boolValue == nil {
                            model.draft["listing_deletion_preference"]["skipPrompt"] = .bool(false)
                        }
                    }
                )) {
                    Text("غير محفوظ / غير معروف").tag("")
                    Text("حذف قابل للاستعادة").tag("soft")
                    Text("حذف نهائي — قراءة فقط").tag("hard").disabled(true)
                }
                Picker("تجاوز رسالة تأكيد الحذف", selection: Binding(
                    get: { model.draft["listing_deletion_preference"]["skipPrompt"].boolValue.map { $0 ? "yes" : "no" } ?? "" },
                    set: { if !$0.isEmpty { model.draft["listing_deletion_preference"]["skipPrompt"] = .bool($0 == "yes") } }
                )) {
                    Text("غير محفوظ / غير معروف").tag("")
                    Text("إبقاء التأكيد").tag("no")
                    Text("تجاوز التأكيد في Fredy").tag("yes")
                }
                SettingsReadOnlyNote("بطاقة الإعلان في FindHaus تبقى قابلة للاستعادة ومع تأكيد، حتى لو كانت سياسة واجهة Fredy مختلفة. لن نرسل hardDelete=true.")
                SettingsSaveControl(model: model, key: .listing_deletion_preference)
            }
            .disabled(!model.canEdit(.listing_deletion_preference))
        }
        .accessibilityIdentifier("settings.preferences")
    }
}
