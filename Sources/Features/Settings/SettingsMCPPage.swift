import SwiftUI

/// The v31 MCP settings structure: account-level server switch, OAuth access
/// link, and tool groups split by the registered readOnlyHint.
/// This catalog is from upstream source, NOT a claim about current enablement.
/// The official web UI loads current tools and disabledTools from the server.
struct SettingsMCPPage: View {
    let onOpenConnections: () -> Void
    @State private var expanded: Set<String> = []

    private struct CatalogTool: Identifiable {
        let id: String
        let title: String
        let info: String
        let readOnly: Bool
    }

    private static let catalog: [CatalogTool] = [
        .init(id: "list_jobs", title: "قائمة مهام البحث", info: "استعراض الأبحاث المحفوظة مع التصفية وتقسيم الصفحات.", readOnly: true),
        .init(id: "get_job", title: "تفاصيل مهمة البحث", info: "قراءة تفاصيل مهمة بحث محددة.", readOnly: true),
        .init(id: "list_listings", title: "البحث في الإعلانات", info: "استعراض إعلانات العقارات مع البحث والمرشحات والصفحات.", readOnly: true),
        .init(id: "get_listing", title: "تفاصيل إعلان", info: "قراءة المعلومات المتاحة عن إعلان واحد.", readOnly: true),
        .init(id: "get_application_letter", title: "رسالة طلب السكن", info: "إنشاء رسالة طلب من بيانات وقالب محفوظين لدى Fredy.", readOnly: true),
        .init(id: "get_photo_for_listing", title: "صورة الإعلان", info: "جلب صورة الإعلان إذا كانت متاحة.", readOnly: true),
        .init(id: "calculate_financing", title: "حساب تمويل شراء", info: "أداة موجودة في مصدر Fredy الأصلي؛ لا يستخدمها تطبيق الإيجارات ولا يربطها.", readOnly: true),
        .init(id: "get_current_date_time", title: "التاريخ والوقت الحاليان", info: "إرجاع التاريخ والوقت إلى عميل MCP.", readOnly: true),
        .init(id: "add_listing_note", title: "إضافة ملاحظة", info: "إلحاق نص بملاحظات إعلان دون استبدال النص السابق.", readOnly: false),
        .init(id: "set_listing_notes", title: "استبدال الملاحظات", info: "استبدال ملاحظات الإعلان، وقد يؤدي إلى حذف النص السابق.", readOnly: false),
        .init(id: "watch_listing", title: "إضافة إلى قائمة المتابعة", info: "إضافة إعلان إلى قائمة المتابعة.", readOnly: false),
        .init(id: "unwatch_listing", title: "إزالة من قائمة المتابعة", info: "إزالة الإعلان من قائمة المتابعة.", readOnly: false),
        .init(id: "start_job_draft", title: "بدء مسودة مهمة", info: "بدء إعداد مهمة بحث جديدة عبر محادثة MCP.", readOnly: false),
        .init(id: "update_job_draft", title: "تحديث مسودة مهمة", info: "تعديل مسودة مهمة البحث قبل إنشائها.", readOnly: false),
        .init(id: "create_job_from_draft", title: "إنشاء مهمة من المسودة", info: "إنشاء مهمة البحث بعد تأكيد بيانات المسودة.", readOnly: false),
        .init(id: "discard_job_draft", title: "التخلص من المسودة", info: "إلغاء المسودة غير المنشورة.", readOnly: false)
    ]

    var body: some View {
        VStack(spacing: 16) {
            SettingsCard("خادم MCP",
                         detail: "في Fredy الأصلي يمكنك السماح لخادم MCP بخدمة حسابك أو إيقافه؛ يجب حفظ التغيير ليُطبَّق.") {
                LabeledContent("حالة الخادم") {
                    Text("غير محمّلة")
                        .foregroundStyle(.secondary)
                }

                Button {
                    // The active server state must be fetched before it can be changed.
                } label: {
                    Label("تشغيل / إيقاف الخادم", systemImage: "power")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(true)

                Button(action: onOpenConnections) {
                    Label("الاتصالات المعتمدة عبر OAuth", systemImage: "person.crop.circle.badge.checkmark")
                }

                SettingsReadOnlyNote("في Fredy تُقرأ الحالة المحفوظة والخادم والأدوات عبر GET /api/user/mcp-server. لم نربط هذا الطلب أو تعديل الإعدادات بعد؛ لذلك لا نعرض حالة تشغيل افتراضية.")
            }

            SettingsCard("أدوات MCP",
                         detail: "الأدوات المسجّلة في مصدر Fredy v31 مقسمة إلى قراءة وكتابة. هذه قائمة إمكانات المصدر، وليست قائمة مفعّلة من حسابك.") {
                toolGroup(readOnly: true)
                Divider()
                toolGroup(readOnly: false)
                SettingsReadOnlyNote("عند ربط قراءة الإعدادات تُعرض أسماء الأدوات وأوصافها وحالاتها مباشرةً من الخادم، بما فيها أي أداة جديدة، مع خيارات تفعيل كل أداة وحفظ التغييرات.")
            }
        }
        .accessibilityIdentifier("settings.mcp")
    }

    private func toolGroup(readOnly: Bool) -> some View {
        let tools = Self.catalog.filter { $0.readOnly == readOnly }
        return VStack(alignment: .leading, spacing: 13) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(readOnly ? "أدوات القراءة" : "أدوات الكتابة")
                        .font(.headline)
                    Text(readOnly
                         ? "تقرأ البيانات دون تغييرها."
                         : "يمكن أن تعدّل الملاحظات والمتابعة والمهام. اتصال OAuth يحتاج تفويض الكتابة.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("المصدر: \(tools.count)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Button("تفعيل الكل / إيقاف الكل") {}
                .buttonStyle(.bordered)
                .disabled(true)

            ForEach(tools) { tool in
                DisclosureGroup(isExpanded: Binding(
                    get: { expanded.contains(tool.id) },
                    set: { isExpanded in
                        if isExpanded { expanded.insert(tool.id) }
                        else { expanded.remove(tool.id) }
                    }
                )) {
                    VStack(alignment: .leading, spacing: 9) {
                        Text(tool.info)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        LabeledContent("حالة الأداة") {
                            Text("غير محمّلة")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.top, 7)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(tool.title)
                            .font(.subheadline.weight(.medium))
                        Text(tool.id)
                            .font(.caption2.monospaced())
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                Divider()
            }
        }
    }
}
