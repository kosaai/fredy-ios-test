import SwiftUI

@MainActor
struct SettingsListingDetailsPage: View {
    let model: AccountSettingsModel

    private var selected: [JSONValue] { model.draft["provider_details"].arrayValue ?? [] }
    private var ids: [String] {
        Array(Set(model.providers.map(\.id) + selected.compactMap(\.stringValue))).sorted()
    }

    var body: some View {
        VStack(spacing: 16) {
            SettingsCard("جلب تفاصيل الإعلانات من المزوّدين", detail: "اختيار المزوّد قد يسبب طلبات تفاصيل إضافية مستقبلًا. لا يعيد هذا الحفظ ملء الإعلانات القديمة تلقائيًا، ولا يضمن دعم كل مزوّد لجلب التفاصيل.") {
                if let warning = model.providerNotice { SettingsReadOnlyNote(warning) }
                ForEach(ids, id: \.self) { id in
                    Toggle(id, isOn: Binding(
                        get: { selected.contains(.string(id)) },
                        set: { chosen in
                            var values = selected
                            if chosen && !values.contains(.string(id)) { values.append(.string(id)) }
                            if !chosen { values.removeAll { $0 == .string(id) } }
                            model.draft["provider_details"] = .array(values)
                        }
                    ))
                }
                if ids.isEmpty { Text("لا توجد قائمة مزوّدين محمّلة؛ لا نفترض نجاح تحميلها.") }
                SettingsSaveControl(model: model, key: .provider_details)
            }
            .disabled(!model.canEdit(.provider_details) || model.providers.isEmpty)

            SettingsCard("تصفية الكلمات المحظورة", detail: "القيمة المحفوظة في الحساب، وليست تفعيلًا لجلب التفاصيل بحد ذاته.") {
                Picker("التصفية على الوصف الكامل", selection: Binding(
                    get: { model.draft["blacklist_filter_on_provider_details"].boolValue.map { $0 ? "yes" : "no" } ?? "" },
                    set: { if !$0.isEmpty { model.draft["blacklist_filter_on_provider_details"] = .bool($0 == "yes") } }
                )) {
                    Text("غير محفوظ / غير معروف").tag("")
                    Text("مفعّلة").tag("yes")
                    Text("متوقفة").tag("no")
                }
                SettingsSaveControl(model: model, key: .blacklist_filter_on_provider_details)
            }
            .disabled(!model.canEdit(.blacklist_filter_on_provider_details))
        }
        .accessibilityIdentifier("settings.listing_details")
    }
}
