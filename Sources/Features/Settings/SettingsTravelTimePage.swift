import SwiftUI

@MainActor
struct SettingsTravelTimePage: View {
    let model: AccountSettingsModel
    private var entries: [JSONValue] { model.draft["home_addresses"].arrayValue ?? [] }
    private static let categoryTitles = [
        "supermarket": "سوبرماركت", "bakery": "مخبز", "pharmacy": "صيدلية", "doctor": "طبيب",
        "kindergarten": "روضة أطفال", "school": "مدرسة", "gym": "نادي رياضي", "swimmingPool": "مسبح",
        "park": "حديقة", "restaurant": "مطعم", "postOffice": "مكتب بريد", "busStop": "موقف حافلة", "trainStation": "محطة قطار"
    ]

    var body: some View {
        VStack(spacing: 16) {
            SettingsCard("العناوين وأنواع الأماكن", detail: "تُحمّل العناوين المحفوظة. حفظها قد يجري geocoding ويعيد حساب المسافات وأوقات التنقل في الخلفية، ولا يعني اكتمال تلك الحسابات.") {
                if entries.isEmpty {
                    Text(model.loaded ? "لا توجد عناوين في المسودة الحالية." : "لم تُحمّل عناوين الحساب بعد.")
                }
                ForEach(Array(entries.indices), id: \.self) { index in
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label(entries[index]["kind"] == .string("category") ? "نوع مكان" : "عنوان", systemImage: "mappin.circle")
                            Spacer()
                            Button(role: .destructive) {
                                var values = entries
                                guard values.indices.contains(index) else { return }
                                values.remove(at: index)
                                model.draft["home_addresses"] = .array(values)
                            } label: { Image(systemName: "trash") }
                            .accessibilityLabel("إزالة من المسودة؛ لا يُرسل إلا بالحفظ")
                        }
                        TextField("اسم مختصر وفريد", text: text(index, "label"))
                        if entries[index]["kind"] == .string("category") {
                            Picker("فئة المكان", selection: text(index, "category")) {
                                Text("اختر الفئة").tag("")
                                ForEach(AccountSettingsModel.placeCategories, id: \.self) { id in Text(Self.categoryTitles[id] ?? id).tag(id) }
                            }
                        } else {
                            TextField("عنوان الشارع والمدينة", text: text(index, "address"))
                        }
                        Picker("وسيلة المواصلات", selection: text(index, "mode")) {
                            Text("المواصلات العامة").tag("transit")
                            Text("السيارة").tag("car")
                            Text("الدراجة").tag("bike")
                            Text("المشي").tag("walk")
                        }
                        TextField("وقت المغادرة HH:mm — فارغ للوقت الافتراضي", text: departure(index))
                            .keyboardType(.numbersAndPunctuation)
                            .environment(\.layoutDirection, .leftToRight)
                        if entries[index]["coords"]["lat"] == .number(-1) {
                            SettingsReadOnlyNote("العنوان محفوظ لكن تحديد الإحداثيات لم ينجح في آخر قراءة. هذا ليس نجاح تحديد موقع.")
                        }
                    }
                    .textFieldStyle(.roundedBorder)
                    .padding(13)
                    .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
                }
                Button("إضافة عنوان") { append(category: false) }
                    .buttonStyle(.bordered)
                    .disabled(entries.count >= 20)
                Button("إضافة نوع مكان") { append(category: true) }
                    .buttonStyle(.bordered)
                    .disabled(entries.count >= 20)
                SettingsSaveControl(model: model, key: .home_addresses)
            }
            .disabled(!model.canEdit(.home_addresses))
        }
        .accessibilityIdentifier("settings.travel_time")
    }

    private func append(category: Bool) {
        guard entries.count < 20 else { return }
        var value: JSONValue = .object(["label": .string(""), "mode": .string("transit")])
        if category { value["kind"] = .string("category"); value["category"] = .string("") }
        else { value["address"] = .string("") }
        model.draft["home_addresses"] = .array(entries + [value])
    }

    private func text(_ index: Int, _ key: String) -> Binding<String> {
        Binding(get: { entries.indices.contains(index) ? entries[index][key].stringValue ?? "" : "" }, set: { value in
            var values = entries
            guard values.indices.contains(index) else { return }
            values[index][key] = .string(value)
            model.draft["home_addresses"] = .array(values)
        })
    }

    private func departure(_ index: Int) -> Binding<String> {
        Binding(get: { entries.indices.contains(index) ? entries[index]["departure"]["time"].stringValue ?? "" : "" }, set: { value in
            var values = entries
            guard values.indices.contains(index) else { return }
            if value.isEmpty {
                var object = values[index].objectValue ?? [:]; object.removeValue(forKey: "departure"); values[index] = .object(object)
            } else { values[index]["departure"] = .object(["time": .string(value)]) }
            model.draft["home_addresses"] = .array(values)
        })
    }
}
