import SwiftUI

/// FindHaus settings, organized as a native iPhone-style vertical menu.
/// All seven settings screens remain presentation-only unless explicitly integrated.
struct RentalSettingsView: View {
    @Binding var darkAppearance: Bool
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

                    Text("القيم المرتبطة بالخادم غير محمّلة حاليًا. تغييرها يحتاج ربط الإعدادات الفعلية أولًا.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
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
    }

    private func settingsDetail(for section: FindHausSettingsSection) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Group {
                    switch section {
                    case .general:
                        SettingsPreferencesPage(darkAppearance: $darkAppearance)
                    case .travelTime:
                        SettingsTravelTimePage()
                    case .listingDetails:
                        SettingsListingDetailsPage()
                    case .application:
                        SettingsApplicationPage()
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

                Text("إعدادات الخادم للعرض حاليًا؛ لم تُجلب القيم المحفوظة، ولا تُرسل تعديلات إلى الخادم.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
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
