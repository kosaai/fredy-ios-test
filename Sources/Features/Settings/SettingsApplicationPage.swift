import SwiftUI

/// Application-letter editor structure as defined by Fredy v31.
/// Edits are temporary view state; templates and personal data are neither
/// sent to Fredy nor stored locally before a settings API is authorized.
struct SettingsApplicationPage: View {
    @State private var profile: [String: String] = [:]
    @State private var flags: [String: String] = [:]
    @State private var employment = ""
    @State private var language = "de"
    @State private var template = ""

    private struct Field: Identifiable {
        let id: String
        let title: String
    }

    private struct PlaceholderGroup: Identifiable {
        let id: String
        let title: String
        let names: [String]
    }

    private static let contacts: [Field] = [
        .init(id: "firstName", title: "الاسم الأول"),
        .init(id: "lastName", title: "اسم العائلة"),
        .init(id: "street", title: "الشارع ورقم المنزل"),
        .init(id: "zip", title: "الرمز البريدي"),
        .init(id: "city", title: "المدينة"),
        .init(id: "phone", title: "رقم الهاتف"),
        .init(id: "email", title: "البريد الإلكتروني")
    ]
    private static let household: [Field] = [
        .init(id: "adults", title: "عدد البالغين"),
        .init(id: "children", title: "عدد الأطفال"),
        .init(id: "pets", title: "الحيوانات الأليفة")
    ]
    private static let occupation: [Field] = [
        .init(id: "occupation", title: "المهنة"),
        .init(id: "employer", title: "جهة العمل"),
        .init(id: "netIncome", title: "صافي الدخل الشهري (€)")
    ]
    private static let extraFlags: [Field] = [
        .init(id: "smoker", title: "هل الأسرة مدخنة؟"),
        .init(id: "schufa", title: "هل يتوفر تقرير SCHUFA؟"),
        .init(id: "wbs", title: "هل تتوفر شهادة WBS؟"),
        .init(id: "guarantor", title: "هل يمكن توفير ضامن؟")
    ]
    private static let placeholders: [PlaceholderGroup] = [
        .init(id: "listing", title: "بيانات الإعلان", names: [
            "listing.title", "listing.address", "listing.price", "listing.size",
            "listing.rooms", "listing.pricePerSqm", "listing.link",
            "listing.provider", "listing.publishedAt"
        ]),
        .init(id: "applicant", title: "بيانات مقدم الطلب", names: [
            "applicant.fullName", "applicant.firstName", "applicant.lastName",
            "applicant.address", "applicant.street", "applicant.zip",
            "applicant.city", "applicant.phone", "applicant.email",
            "applicant.household", "applicant.pets", "applicant.smoker",
            "applicant.occupation", "applicant.employer",
            "applicant.employmentType", "applicant.netIncome",
            "applicant.moveInDate", "applicant.schufa", "applicant.wbs",
            "applicant.guarantor", "applicant.extra"
        ]),
        .init(id: "contact", title: "بيانات جهة الاتصال", names: [
            "contact.name", "contact.company", "contact.salutation"
        ]),
        .init(id: "env", title: "متغيرات عامة", names: ["today"])
    ]

    var body: some View {
        VStack(spacing: 16) {
            SettingsReadOnlyNote("هذه الحقول فارغة عمدًا لأنها لا تعرض ملفك الشخصي المحفوظ. ما تكتبه داخل الصفحة مؤقت ولا يُرسل إلى الخادم.")

            SettingsCard("معلومات التواصل", detail: "بيانات نموذج طلب السكن ورسالة التواصل مع المالك.") {
                ForEach(Self.contacts) { field in profileInput(field) }
            }

            SettingsCard("الأسرة") {
                ForEach(Self.household) { field in profileInput(field) }
            }

            SettingsCard("العمل والدخل") {
                ForEach(Self.occupation) { field in profileInput(field) }
                Picker("نوع العمل", selection: $employment) {
                    Text("غير محدد").tag("")
                    Text("عقد دائم").tag("permanent")
                    Text("عقد مؤقت").tag("temporary")
                    Text("عمل حر").tag("selfEmployed")
                    Text("موظف حكومي").tag("civilServant")
                    Text("طالب").tag("student")
                    Text("متقاعد").tag("retired")
                }
            }

            SettingsCard("تفاصيل طلب السكن") {
                profileInput(.init(id: "moveInDate", title: "تاريخ الانتقال (YYYY-MM-DD)"))
                ForEach(Self.extraFlags) { flag in
                    Picker(flag.title, selection: Binding(
                        get: { flags[flag.id] ?? "unset" },
                        set: { flags[flag.id] = $0 }
                    )) {
                        Text("لم أجب").tag("unset")
                        Text("نعم").tag("yes")
                        Text("لا").tag("no")
                    }
                    .pickerStyle(.menu)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("معلومات إضافية").font(.subheadline)
                    TextEditor(text: binding(for: "extra"))
                        .frame(height: 95)
                        .scrollContentBackground(.hidden)
                        .background(Color(uiColor: .tertiarySystemGroupedBackground),
                                    in: RoundedRectangle(cornerRadius: 9))
                }
            }

            SettingsCard("قالب رسالة طلب السكن",
                         detail: "يعرض الخادم رسالة الطلب ويتيح تحرير قالب حسب اللغة، وإدراج الحقول المتغيرة ومعاينة النص الناتج عبر الخادم.") {
                Picker("لغة الرسالة", selection: $language) {
                    Text("الألمانية").tag("de")
                    Text("الإنجليزية").tag("en")
                    Text("الإيطالية").tag("it")
                }

                LabeledContent("نوع العقار", value: "إيجار")

                Text("محرر القالب").font(.subheadline.weight(.medium))
                TextEditor(text: $template)
                    .frame(height: 210)
                    .scrollContentBackground(.hidden)
                    .background(Color(uiColor: .tertiarySystemGroupedBackground),
                                in: RoundedRectangle(cornerRadius: 12))

                DisclosureGroup("إدراج متغيرات القالب") {
                    ForEach(Self.placeholders) { group in
                        VStack(alignment: .leading, spacing: 7) {
                            Text(group.title).font(.footnote.weight(.semibold))
                            ForEach(group.names, id: \.self) { name in
                                Button {
                                    template += "{{" + name + "}}"
                                } label: {
                                    Text(name)
                                        .font(.caption.monospaced())
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                }

                Divider()
                Text("معاينة الرسالة")
                    .font(.subheadline.weight(.semibold))
                Text("تحتاج معاينة القالب الحقيقي إلى خدمة الخادم؛ لن نعرض رسالة مُنشأة من بيانات غير محفوظة.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if !profile.isEmpty || !flags.isEmpty || !template.isEmpty {
                Button("تجاهل الإدخالات المحلية", role: .destructive) {
                    profile.removeAll()
                    flags.removeAll()
                    employment = ""
                    language = "de"
                    template = ""
                }
            }
        }
        .accessibilityIdentifier("settings.application")
    }

    private func binding(for key: String) -> Binding<String> {
        Binding(get: { profile[key] ?? "" }, set: { profile[key] = $0 })
    }

    private func profileInput(_ field: Field) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(field.title)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField(field.title, text: binding(for: field.id))
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
        }
    }
}
