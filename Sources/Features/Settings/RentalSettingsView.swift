import SwiftUI

/// FindHaus settings, organized as a native iPhone-style vertical menu.
/// Account drafts are owned by the authenticated shell, including uncertain writes.
@MainActor
struct RentalSettingsView: View {
    @Binding var darkAppearance: Bool
    let model: AccountSettingsModel
    @Environment(\.dismiss) private var dismiss
    @State private var navigationPath: [FindHausSettingsSection] = []

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 9) {
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text("الإعدادات")
                                .font(.system(size: 33, weight: .bold, design: .rounded))
                            Label("خاصة بك", systemImage: "person.crop.circle")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(.quaternary, in: Capsule())
                        }
                        Text("إعدادات الخادم المشتركة تُدار من لوحة إدارة الخادم.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    VStack(spacing: 0) {
                        ForEach(FindHausSettingsSection.allCases) { section in
                            NavigationLink(value: section) {
                                HStack(spacing: 13) {
                                    Image(systemName: section.symbol)
                                        .font(.system(size: 19, weight: .medium))
                                        .foregroundStyle(Color.accentColor)
                                        .frame(width: 28, height: 30)
                                        .accessibilityHidden(true)

                                    Text(section.title)
                                        .font(.body)
                                        .foregroundStyle(.primary)
                                    Spacer(minLength: 8)

                                    Image(systemName: "chevron.left")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.tertiary)
                                        .accessibilityHidden(true)
                                }
                                .frame(minHeight: 57)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("settings.open." + section.rawValue)

                            if section != FindHausSettingsSection.allCases.last {
                                Divider().padding(.leading, 41)
                            }
                        }
                    }
                    .padding(.horizontal, 17)
                    .background(
                        Color(uiColor: .secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 20)
                    )
                    .accessibilityIdentifier("settings.sections")

                    SettingsStatusBanner(model: model)
                }
                .padding(.horizontal, 18)
                .padding(.top, 26)
                .padding(.bottom, 28)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("إغلاق") { dismiss() }
                }
            }
            .navigationDestination(for: FindHausSettingsSection.self) { section in
                settingsDetail(for: section)
            }
            .accessibilityIdentifier("settings.screen")
        }
        .task { await model.loadIfNeeded() }
        .interactiveDismissDisabled(model.busy)
    }

    private func settingsDetail(for section: FindHausSettingsSection) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Group {
                    switch section {
                    case .general:
                        SettingsPreferencesPage(darkAppearance: $darkAppearance, model: model)
                    case .travelTime:
                        SettingsTravelTimePage(model: model)
                    case .listingDetails:
                        SettingsListingDetailsPage(model: model)
                    case .application:
                        SettingsApplicationPage(model: model)
                    case .notifications:
                        SettingsNotificationsPage()
                    case .connections:
                        SettingsConnectionsPage()
                    case .mcp:
                        SettingsMCPPage(onOpenConnections: {
                            navigationPath.append(.connections)
                        })
                    }
                }

                .disabled(!model.editable)

                SettingsStatusBanner(model: model)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18)
            .padding(.top, 19)
            .padding(.bottom, 30)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(section.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private enum FindHausSettingsSection: String, CaseIterable, Identifiable, Hashable {
    case general, travelTime, listingDetails, application, notifications, connections, mcp

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "الإعدادات العامة"
        case .travelTime: "وقت التنقل"
        case .listingDetails: "تفاصيل الإعلانات"
        case .application: "طلب السكن"
        case .notifications: "قنوات الإشعار"
        case .connections: "الاتصالات"
        case .mcp: "خادم MCP"
        }
    }

    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .travelTime: "tram"
        case .listingDetails: "building.2"
        case .application: "doc.text"
        case .notifications: "bell"
        case .connections: "link"
        case .mcp: "server.rack"
        }
    }
}

/// Reusable native card for the settings hierarchy.
struct SettingsCard<Content: View>: View {
    let title: String
    let detail: String?
    let content: Content

    init(_ title: String, detail: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.detail = detail
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title).font(.headline)
            if let detail {
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Divider()
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(17)
        .background(Color(uiColor: .secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 20))
    }
}

struct SettingsReadOnlyNote: View {
    let message: String

    init(_ message: String = "العناصر هنا لعرض بنية الإعدادات. لا تُحمَّل القيم المحفوظة ولا تُرسل تغييرات إلى الخادم.") {
        self.message = message
    }

    var body: some View {
        Label(message, systemImage: "info.circle")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

@MainActor
struct SettingsSaveControl: View {
    let model: AccountSettingsModel
    let key: AccountSettingKey
    @State private var confirming = false

    var body: some View {
        Button("حفظ هذا القسم") { confirming = true }
            .buttonStyle(.borderedProminent)
            .frame(minHeight: 44)
            .disabled(!model.canSave(key))
            .confirmationDialog("حفظ إعدادات الحساب؟", isPresented: $confirming, titleVisibility: .visible) {
                Button("حفظ والتحقق من الخادم") { model.save(key) }
                Button("إلغاء", role: .cancel) {}
            } message: {
                Text(key == .home_addresses
                     ? "تُرسل قائمة العناوين الحالية كاملة. قد يحدد الخادم مواقعها ويعيد حساب المسافات وأوقات التنقل للإعلانات المحفوظة في الخلفية."
                     : "سيُحفظ هذا القسم فقط، ثم تُقرأ قيمته مجددًا. لا يُرسل بريد أو Telegram ولا تُشغّل مهمة بحث بهذا الزر.")
            }
    }
}

@MainActor
private struct SettingsStatusBanner: View {
    let model: AccountSettingsModel
    @State private var confirmingReload = false
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if model.busy { ProgressView("جارٍ الاتصال بالخادم…") }
            if let notice = model.notice { Text(notice).font(.footnote) }
            if model.uncertain {
                Button("التحقق من الحفظ دون تكراره") { Task { await model.reconcile() } }
                    .disabled(model.busy)
            } else if !model.loaded {
                Text("لم تُحمّل إعدادات الحساب؛ الحقول ليست قيمًا محفوظة مؤكدة.").font(.footnote)
                Button("تحميل الإعدادات") { Task { await model.loadIfNeeded() } }
                    .disabled(model.busy)
            } else {
                Text("القيم من آخر قراءة للحساب. لا يُرسل أي تعديل حتى تأكيد حفظ القسم.").font(.footnote)
                Button("إعادة تحميل المحفوظ وتجاهل المسودات") { confirmingReload = true }
                    .disabled(model.busy)
            }
        }
        .foregroundStyle(.secondary)
        .confirmationDialog("تجاهل المسودات غير المحفوظة؟", isPresented: $confirmingReload, titleVisibility: .visible) {
            Button("إعادة التحميل", role: .destructive) { Task { await model.reloadDiscardingDraft() } }
            Button("إلغاء", role: .cancel) {}
        }
    }
}
