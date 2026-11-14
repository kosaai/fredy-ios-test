import SwiftUI

/// Native counterpart of Fredy's combined addresses/place-types travel time page.
/// These are ephemeral on-screen drafts; no geocoding/transport requests are made.
struct SettingsTravelTimePage: View {
    @State private var entries: [TravelDraft] = []

    private struct PlaceCategory: Identifiable {
        let id: String
        let title: String
    }

    private static let categories: [PlaceCategory] = [
        .init(id: "supermarket", title: "سوبرماركت"),
        .init(id: "bakery", title: "مخبز"),
        .init(id: "pharmacy", title: "صيدلية"),
        .init(id: "doctor", title: "طبيب"),
        .init(id: "kindergarten", title: "روضة أطفال"),
        .init(id: "school", title: "مدرسة"),
        .init(id: "gym", title: "نادي رياضي"),
        .init(id: "swimmingPool", title: "مسبح"),
        .init(id: "park", title: "حديقة"),
        .init(id: "restaurant", title: "مطعم"),
        .init(id: "postOffice", title: "مكتب بريد"),
        .init(id: "busStop", title: "موقف حافلة"),
        .init(id: "trainStation", title: "محطة قطار")
    ]

    var body: some View {
        VStack(spacing: 16) {
            SettingsCard("العناوين وأنواع الأماكن",
                         detail: "يقيس الخادم وقت الوصول من كل إعلان إلى عنوان محدد أو أقرب مكان من فئة تختارها. تُعاد حسابات التنقل بعد حفظ التغييرات على الخادم.") {
                SettingsReadOnlyNote("العناوين المخزنة وتقدم حساب أوقات التنقل غير محمّلين. الإدخالات التي تنشئها هنا غير محفوظة.")
                if entries.isEmpty {
                    ContentUnavailableView("لا توجد إدخالات محلية",
                                           systemImage: "mappin.and.ellipse",
                                           description: Text("أضف عنوانًا أو نوع مكان لرؤية حقول الإعدادات."))
                }

                ForEach($entries) { $entry in
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label(entry.kind == .address ? "عنوان" : "نوع مكان",
                                  systemImage: entry.kind == .address ? "mappin.circle" : "building.2")
                                .font(.headline)
                            Spacer()
                            Button(role: .destructive) {
                                entries.removeAll { $0.id == entry.id }
                            } label: {
                                Image(systemName: "trash")
                            }
                            .accessibilityLabel("إزالة الإدخال")
                        }

                        TextField("اسم مختصر", text: $entry.label)
                            .textFieldStyle(.roundedBorder)

                        if entry.kind == .address {
                            TextField("عنوان الشارع والمدينة", text: $entry.address)
                                .textFieldStyle(.roundedBorder)
                        } else {
                            Picker("فئة المكان", selection: $entry.category) {
                                Text("اختر الفئة").tag("")
                                ForEach(Self.categories) { category in
                                    Text(category.title).tag(category.id)
                                }
                            }
                        }

                        Picker("وسيلة المواصلات", selection: $entry.mode) {
                            Text("المواصلات العامة").tag("transit")
                            Text("السيارة").tag("car")
                            Text("الدراجة").tag("bike")
                            Text("المشي").tag("walk")
                        }

                        if entry.mode == "transit" {
                            Picker("وقت المغادرة", selection: $entry.departure) {
                                ForEach(["06:00", "07:00", "07:30", "08:00",
                                         "08:30", "09:00", "12:00", "17:00",
                                         "17:30", "18:00"], id: \.self) { time in
                                    Text(time).tag(time)
                                }
                            }
                        }
                    }
                    .padding(13)
                    .background(Color(uiColor: .tertiarySystemGroupedBackground),
                                in: RoundedRectangle(cornerRadius: 14))
                }

                Button {
                    entries.append(TravelDraft(kind: .address))
                } label: {
                    Label("إضافة عنوان", systemImage: "plus.circle")
                }
                .buttonStyle(.bordered)

                Button {
                    entries.append(TravelDraft(kind: .category))
                } label: {
                    Label("إضافة نوع مكان", systemImage: "plus.circle")
                }
                .buttonStyle(.bordered)

                if !entries.isEmpty {
                    Button("تجاهل الإدخالات المحلية", role: .destructive) {
                        entries.removeAll()
                    }
                    .font(.footnote)
                }
            }
        }
        .accessibilityIdentifier("settings.travel_time")
    }
}

private struct TravelDraft: Identifiable {
    enum Kind { case address, category }

    let id = UUID()
    let kind: Kind
    var label = ""
    var address = ""
    var category = ""
    var mode = "transit"
    var departure = "08:00"
}
