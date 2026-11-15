import SwiftUI

/// Existing native Connections page, driven only by the authenticated account's live grant list.
@MainActor
struct SettingsConnectionsPage: View {
    let model: OAuthConnectionsModel
    @State private var confirmingRevocation = false

    var body: some View {
        VStack(spacing: 16) {
            SettingsCard("اتصالات MCP المعتمدة",
                         detail: "يعرض الخادم اتصالات OAuth ذات تفويض تجديد سارٍ، ونطاقاتها ووقت المنح المبلغ عنه. ليست هذه قائمة بكل التوكنات أو سجلًا لكل الاتصالات السابقة.") {
                if model.busy { ProgressView("جارٍ الاتصال بالخادم…") }
                if let notice = model.notice { Text(notice).font(.footnote) }
                if model.phase == .uncertain {
                    Button("التحقق بالقراءة دون تكرار الإلغاء") { model.reconcile() }
                        .buttonStyle(.bordered)
                        .frame(minHeight: 44)
                } else {
                    Button("إعادة قراءة الاتصالات") { model.reload() }
                        .buttonStyle(.bordered)
                        .frame(minHeight: 44)
                        .disabled(model.busy || model.sessionExpired)
                }
                if model.connections == nil {
                    SettingsReadOnlyNote("لم تُحمّل قائمة صالحة؛ لا نفترض خلو الحساب من الاتصالات.")
                } else {
                    Text("القائمة والصلاحيات بحسب آخر قراءة، وليست اختبارًا فعليًا لوصول عميل MCP.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }

            if let connections = model.connections {
                if connections.isEmpty {
                    SettingsCard("لا توجد تفويضات OAuth سارية في آخر قراءة") {
                        SettingsReadOnlyNote("يعرض هذا API الاتصالات القادرة على تجديد الوصول فقط؛ لا يحصي توكنات MCP اليدوية أو كل التوكنات القديمة.")
                    }
                } else {
                    ForEach(connections) { grant in
                        connectionCard(grant)
                    }
                }
            }

            SettingsCard("مستويات الوصول") {
                Label("mcp:read — قراءة البيانات المسموح بها", systemImage: "eye")
                Label("mcp:write — طلب عمليات تعديل البيانات المسموح بها", systemImage: "pencil")
                Text("تعرض القائمة اتحاد نطاقات التفويضات السارية للاتصال، لا نطاق كل توكن منفرد. صلاحيات الموارد وإعدادات MCP للحساب تبقى شروطًا إضافية. لا توجد هنا ترقية صلاحيات أو إنشاء اتصال أو عرض توكنات.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .accessibilityIdentifier("settings.connections")
        .task { model.reload() }
        .onDisappear { model.cancelProposal() }
        .confirmationDialog("إلغاء وصول هذا الاتصال؟", isPresented: $confirmingRevocation, titleVisibility: .visible) {
            Button("إلغاء الوصول والتحقق", role: .destructive) { model.confirmRevocation() }
            Button("إبقاء الاتصال", role: .cancel) { model.cancelProposal() }
        } message: {
            if let target = model.proposal {
                Text("الاتصال: \(target.displayName)\nالمعرف: \(target.clientId)\nالنطاقات: \(target.scopes.joined(separator: ", "))\nسيُطلب إلغاء تفويضات هذا الاتصال السارية لحسابك، ثم التحقق بقراءة مستقلة. قد يحتاج العميل إلى تفويض جديد؛ لا يُلغى عمل سبق تنفيذه ولا تتغير إعدادات أدوات MCP.")
            }
        }
        .onChange(of: confirmingRevocation) { _, presented in
            if !presented { model.cancelProposal() }
        }
    }

    private func connectionCard(_ grant: OAuthConnection) -> some View {
        SettingsCard(grant.displayName) {
            LabeledContent("معرف الاتصال") {
                Text(grant.clientId).font(.caption.monospaced())
                    .environment(\.layoutDirection, .leftToRight)
            }
            LabeledContent("وقت المنح بحسب الخادم") {
                Text(grant.grantedDate.formatted(.dateTime.year().month().day().hour().minute().locale(Locale(identifier: "ar"))))
            }
            Text("يعتمد الوقت على أقدم رمز تجديد سارٍ حاليًا، وقد يتغير عند التجديد؛ ليس سجلًا مضمونًا لأول موافقة.")
                .font(.caption).foregroundStyle(.secondary)
            if grant.scopes.isEmpty {
                SettingsReadOnlyNote("لم يعرض الخادم نطاقات لهذا الاتصال؛ لا نفترض أنه للقراءة فقط.")
            } else {
                ForEach(grant.scopes, id: \.self) { scope in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(scope).font(.caption.monospaced())
                            .environment(\.layoutDirection, .leftToRight)
                        Text(scopeDescription(scope)).font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }
            Button(role: .destructive) {
                model.proposeRevoke(grant)
                confirmingRevocation = model.proposal != nil
            } label: {
                Label("إلغاء وصول الاتصال", systemImage: "xmark.shield")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered)
            .disabled(!model.canRevoke)
            .accessibilityLabel("إلغاء وصول \(grant.displayName)")
            .accessibilityHint("معرف الاتصال \(grant.clientId)")
        }
    }

    private func scopeDescription(_ scope: String) -> String {
        switch scope {
        case "mcp:read": "قراءة المهام والإعلانات التي يسمح بها الحساب."
        case "mcp:write": "يشمل نطاق التعديل، مع بقاء صلاحيات الموارد وإعدادات MCP وبقية قيود الخادم."
        default: "نطاق أرسله الخادم غير موصوف هنا؛ لا نستنتج منه صلاحية قراءة أو كتابة."
        }
    }
}
