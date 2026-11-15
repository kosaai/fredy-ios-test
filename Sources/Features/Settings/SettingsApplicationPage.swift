import SwiftUI

/// Real account profile and template overrides; explicit scoped save with read-back.
/// Preview is not called because upstream renders against a fabricated listing.
@MainActor
struct SettingsApplicationPage: View {
    let model: AccountSettingsModel
    @State private var language = "de"
    private var template: Binding<String> {
        Binding(get: { model.draft["application_templates"][language]["rent"].stringValue ?? "" },
                set: { model.draft["application_templates"][language]["rent"] = .string($0) })
    }

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
            SettingsReadOnlyNote("الحقول من ملف الحساب المحفوظ. تحفظ كل بطاقة القسم المطلوب فقط؛ تبقى مسودات الأقسام الأخرى دون إرسال، ولا يُرسل بريد أو طلب سكن.")

            SettingsCard("معلومات التواصل", detail: "بيانات نموذج طلب السكن ورسالة التواصل مع المالك.") {
                ForEach(Self.contacts) { field in profileInput(field) }
            }

            SettingsCard("الأسرة") {
                ForEach(Self.household) { field in profileInput(field) }
            }

            SettingsCard("العمل والدخل") {
                ForEach(Self.occupation) { field in profileInput(field) }
                Picker("نوع العمل", selection: model.profileText("employmentType")) {
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
                    Picker(flag.title, selection: model.profileFlag(flag.id)) {
                        Text("لم أجب").tag("unset")
                        Text("قيمة محفوظة غير معروفة").tag("unknown").disabled(true)
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

            SettingsSaveControl(model: model, key: .applicant_profile)
                .disabled(!model.canEdit(.applicant_profile))

            SettingsCard("قالب رسالة طلب السكن",
                         detail: "يعرض الخادم رسالة الطلب ويتيح تحرير قالب حسب اللغة، وإدراج الحقول المتغيرة ومعاينة النص الناتج عبر الخادم.") {
                Picker("لغة الرسالة", selection: $language) {
                    Text("الألمانية").tag("de")
                    Text("الإنجليزية").tag("en")
                    Text("الإيطالية").tag("it")
                }

                LabeledContent("نوع العقار", value: "إيجار")

                Text("محرر القالب").font(.subheadline.weight(.medium))
                TextEditor(text: template)
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
                                    template.wrappedValue += "{{" + name + "}}"
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
                Text("معاينة الخادم تعتمد إعلانًا تجريبيًا، لذلك لا تُستخدم هنا. بعد الحفظ اعرض رسالة إعلان فعلي من بطاقة الإعلان؛ لا نولّد معاينة وهمية.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            SettingsReadOnlyNote("إذا لم يوجد تخصيص محفوظ لهذه اللغة فالمحرر فارغ، ويظل الخادم يستخدم قالبه الافتراضي. حفظ المحرر يكتب تخصيص الإيجار فقط ويحافظ على لغات وقوالب الشراء الأخرى.")
            Button("إزالة تخصيص الإيجار من المسودة لهذه اللغة") {
                var values = model.draft["application_templates"][language].objectValue ?? [:]
                values.removeValue(forKey: "rent")
                model.draft["application_templates"][language] = .object(values)
            }
            .disabled(!model.canEdit(.application_templates))
            SettingsSaveControl(model: model, key: .application_templates)
                .disabled(!model.canEdit(.application_templates))
        }
        .accessibilityIdentifier("settings.application")
    }

    private func binding(for key: String) -> Binding<String> {
        model.profileText(key)
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
