import SwiftUI

/// Fredy v31 connections page manages previously authorized OAuth MCP clients.
/// No client identity or access grant is invented in an offline UI.
struct SettingsConnectionsPage: View {
    var body: some View {
        VStack(spacing: 16) {
            SettingsCard("اتصالات MCP المعتمدة",
                         detail: "يعرض Fredy التطبيقات التي سبق منحها وصول OAuth إلى مهامك وإعلاناتك، ونوع الصلاحية وتاريخ منحها، مع إمكانية إلغاء الوصول.") {
                LabeledContent("الجهة المتصلة") {
                    Text("غير محمّلة").foregroundStyle(.secondary)
                }
                LabeledContent("الصلاحية") {
                    Text("قراءة / كتابة")
                        .foregroundStyle(.secondary)
                }
                LabeledContent("تاريخ منح الوصول") {
                    Text("غير محمّل").foregroundStyle(.secondary)
                }

                SettingsReadOnlyNote("لم تُجلب قائمة اتصالات OAuth الفعلية من Fredy. لا يمكن افتراض عدم وجود اتصالات ولا يمكن إلغاء أي وصول من هذه الصفحة حاليًا.")
                Button(role: .destructive) {
                    // No destructive server request or synthetic client identifier.
                } label: {
                    Label("إلغاء وصول اتصال", systemImage: "xmark.shield")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(true)
            }

            SettingsCard("مستويات الوصول") {
                Label("قراءة — عرض المهام والإعلانات", systemImage: "eye")
                Label("كتابة — تعديل البيانات المسموح بها", systemImage: "pencil")
                Text("أي اتصال يمتلك القراءة فقط لا يحصل على صلاحية الكتابة تلقائيًا؛ يلزمه تفويض OAuth مستقل.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityIdentifier("settings.connections")
    }
}
