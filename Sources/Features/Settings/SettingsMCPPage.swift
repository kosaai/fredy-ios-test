import SwiftUI

/// Account-level tool availability, not OAuth grants or tool invocation.
@MainActor
struct SettingsMCPPage: View {
    let model: MCPSettingsModel
    let onOpenConnections: () -> Void
    @State private var expanded: Set<String> = []
    @State private var confirmingChange = false

    var body: some View {
        VStack(spacing: 16) {
            SettingsCard("خادم MCP",
                         detail: "إعدادات حسابك فقط، وليست تشغيلًا أو إيقافًا لخدمة الخادم العامة.") {
                LabeledContent("آخر حالة مقروءة") {
                    if let snapshot = model.snapshot {
                        Text(snapshot.configuration.enabled ? "مفعّل للحساب" : "متوقف للحساب")
                    } else {
                        Text("غير محمّلة").foregroundStyle(.secondary)
                    }
                }
                Button {
                    if let snapshot = model.snapshot {
                        model.proposeServer(enabled: !snapshot.configuration.enabled)
                        presentConfirmation()
                    }
                } label: {
                    Label("تشغيل / إيقاف الخادم", systemImage: "power")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
                .disabled(!model.canEdit)

                Button(action: onOpenConnections) {
                    Label("الاتصالات المعتمدة عبر OAuth", systemImage: "person.crop.circle.badge.checkmark")
                }
                SettingsReadOnlyNote("إيقاف MCP لا يحذف التوكنات أو الاتصالات السابقة؛ إعادة تفعيله قد تعيد وصولها ضمن صلاحياتها القائمة. إدارة OAuth غير موصولة في هذه المرحلة، ولا يمنح هذا الإعداد تفويض كتابة لاتصال للقراءة فقط.")

                if model.busy { ProgressView("جارٍ قراءة أو التحقق من إعدادات MCP…") }
                if let notice = model.notice {
                    Text(notice).font(.footnote).foregroundStyle(.secondary)
                }
                if model.phase == .uncertain {
                    SettingsReadOnlyNote("الحالة المعروضة هي آخر قراءة مؤكدة وقد تختلف الآن عن الخادم. الحفظ محجوب حتى تأكيد الهدف بقراءة مستقلة، حتى بعد إغلاق الإعدادات وإعادة فتحها.")
                    Button("التحقق من الحفظ دون إعادة إرساله") { model.reconcile() }
                        .frame(minHeight: 44)
                } else {
                    Button("إعادة قراءة إعدادات MCP") { model.reload() }
                        .disabled(model.busy || model.sessionExpired)
                        .frame(minHeight: 44)
                }
            }

            SettingsCard("أدوات MCP",
                         detail: "الأسماء والأوصاف وتصنيف القراءة أو الكتابة تأتي من قائمة الخادم الحقيقية؛ السماح للأداة لا يستدعيها.") {
                if let snapshot = model.snapshot {
                    if snapshot.tools.isEmpty {
                        Text("لم يُرجع الخادم أدوات مسجّلة.").foregroundStyle(.secondary)
                    }
                    toolGroup(snapshot: snapshot, readOnly: true)
                    Divider()
                    toolGroup(snapshot: snapshot, readOnly: false)
                    SettingsReadOnlyNote("المفاتيح تحدد السماح للأدوات عند تشغيل MCP للحساب. إذا كان MCP متوقفًا فلن تكون أي أداة متاحة، ولو بقي السماح الفردي محفوظًا. الأدوات المضافة مستقبلًا تبدأ مفعّلة حسب سياسة Fredy، وليست قائمة سماح ثابتة.")
                } else {
                    Text("لا توجد قائمة أدوات مؤكدة بعد. لا نعرض أدوات أو صلاحيات افتراضية.")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityIdentifier("settings.mcp")
        .task { model.reload() }
        .onDisappear { model.cancelProposal() }
        .onChange(of: confirmingChange) { _, presented in
            if !presented { model.cancelProposal() }
        }
        .confirmationDialog("تأكيد تغيير صلاحيات MCP للحساب؟",
                            isPresented: $confirmingChange, titleVisibility: .visible) {
            Button("تأكيد التغيير والتحقق من حفظه") { model.confirmChange() }
            Button("إلغاء", role: .cancel) { model.cancelProposal() }
        } message: {
            Text(confirmationText)
        }
    }

    private var confirmationText: String {
        guard let snapshot = model.snapshot, let desired = model.proposal else { return "لم يُرسل تغيير." }
        let changed = snapshot.tools.filter {
            snapshot.configuration.disabledTools.contains($0.name) != desired.disabledTools.contains($0.name)
        }
        let names = changed.map { $0.title.isEmpty ? $0.name : $0.title }.joined(separator: "، ")
        return "حالة MCP بعد الحفظ: \(desired.enabled ? "مفعّل" : "متوقف"). " +
            (changed.isEmpty ? "تبقى اختيارات الأدوات كما هي. " : "الأدوات التي سيتغير السماح لها: \(names). ") +
            "قد يؤثر ذلك في العملاء المتصلين وصلاحيات قراءة أو تعديل بياناتك. لا يحذف هذا التغيير الاتصالات أو يمنح OAuth صلاحيات جديدة. لن نعرض نجاحًا قبل قراءة مستقلة تؤكد الحفظ."
    }

    private func presentConfirmation() {
        if model.proposal != nil { confirmingChange = true }
    }

    private func toolGroup(snapshot: MCPSettingsSnapshot, readOnly: Bool) -> some View {
        let tools = snapshot.tools.filter { $0.readOnly == readOnly }
        let allEnabled = tools.allSatisfy { !snapshot.configuration.disabledTools.contains($0.name) }
        return VStack(alignment: .leading, spacing: 13) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(readOnly ? "أدوات القراءة" : "أدوات الكتابة").font(.headline)
                    Text(readOnly ? "تصنيف الخادم: قراءة فقط." : "قد تغيّر هذه الأدوات بيانات الحساب؛ السماح هنا ليس تفويض OAuth.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Spacer()
                Text("الخادم: \(tools.count)").font(.caption2).foregroundStyle(.secondary)
            }
            Button(allEnabled ? "إيقاف الكل" : "تفعيل الكل") {
                model.proposeGroup(readOnly: readOnly, enabled: !allEnabled)
                presentConfirmation()
            }
            .buttonStyle(.bordered)
            .disabled(!model.canEdit || tools.isEmpty)

            ForEach(tools) { tool in
                DisclosureGroup(isExpanded: Binding(
                    get: { expanded.contains(tool.id) },
                    set: { if $0 { expanded.insert(tool.id) } else { expanded.remove(tool.id) } }
                )) {
                    VStack(alignment: .leading, spacing: 9) {
                        Text(tool.description).font(.footnote).foregroundStyle(.secondary)
                        Toggle("السماح للأداة عند تشغيل MCP", isOn: Binding(
                            get: { !snapshot.configuration.disabledTools.contains(tool.name) },
                            set: { value in
                                model.proposeTool(name: tool.name, enabled: value)
                                presentConfirmation()
                            }
                        ))
                        .disabled(!model.canEdit)
                        LabeledContent("متاحة بحسب آخر قراءة للحساب") {
                            Text(snapshot.configuration.enabled && !snapshot.configuration.disabledTools.contains(tool.name) ? "نعم" : "لا")
                        }
                        .font(.caption)
                    }
                    .padding(.top, 7)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(tool.title.isEmpty ? tool.name : tool.title).font(.subheadline.weight(.medium))
                        Text(tool.name).font(.caption2.monospaced()).foregroundStyle(.secondary)
                            .environment(\.layoutDirection, .leftToRight)
                            .lineLimit(2)
                    }
                }
                Divider()
            }
        }
    }
}
