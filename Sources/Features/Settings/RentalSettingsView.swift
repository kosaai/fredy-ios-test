import SwiftUI

/// Native iPhone presentation of the seven user-settings areas present in Fredy v31.
/// The existing login/listings/jobs client is unchanged. Server settings are not
/// fetched or written here; every section describes that boundary explicitly.
struct RentalSettingsView: View {
    @Binding var darkAppearance: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var selectedSection: FredySettingsSection = .preferences

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 9) {
                        HStack(spacing: 10) {
                            Text("الإعدادات")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                            Label("خاصة بك", systemImage: "person.crop.circle")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(.quaternary, in: Capsule())
                        }
                        Text("الإعدادات العامة لجميع المستخدمين توجد في لوحة إدارة الخادم.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 18)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 14) {
                            ForEach(FredySettingsSection.allCases) { section in
                                Button {
                                    selectedSection = section
                                } label: {
                                    VStack(spacing: 10) {
                                        Text(section.title)
                                            .font(.subheadline.weight(selectedSection == section ? .semibold : .regular))
                                            .foregroundStyle(selectedSection == section ? Color.primary : Color.secondary)
                                            .fixedSize(horizontal: true, vertical: false)
                                        Capsule()
                                            .fill(selectedSection == section ? Color.accentColor : Color.clear)
                                            .frame(height: 3)
                                    }
                                }
                                .buttonStyle(.plain)
                                .accessibilityAddTraits(selectedSection == section ? .isSelected : [])
                            }
                        }
                        .padding(.horizontal, 18)
                    }
                    .accessibilityIdentifier("settings.sections")

                    Group {
                        switch selectedSection {
                        case .preferences:
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
                            SettingsMCPPage(onOpenConnections: { selectedSection = .connections })
                        }
                    }
                    .padding(.horizontal, 18)
                    .id(selectedSection)

                    Text("تعديل إعدادات الخادم غير مفعّل في هذه المرحلة. لا توجد بيانات حساب أو أدوات مفعّلة معروضة بصورة افتراضية.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 18)
                        .padding(.bottom, 16)
                }
                .padding(.top, 20)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("إغلاق") { dismiss() }
                }
            }
            .accessibilityIdentifier("settings.screen")
        }
    }
}

private enum FredySettingsSection: String, CaseIterable, Identifiable {
    case preferences, travelTime, listingDetails, application, notifications, connections, mcp

    var id: String { rawValue }
    var title: String {
        switch self {
        case .preferences: "التفضيلات"
        case .travelTime: "وقت التنقل"
        case .listingDetails: "تفاصيل الإعلانات"
        case .application: "طلب السكن"
        case .notifications: "قنوات الإشعار"
        case .connections: "الاتصالات"
        case .mcp: "خادم MCP"
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
