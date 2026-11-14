import SwiftUI

/// Fredy-inspired job cards. Read-only visual controls until the corresponding
/// existing Fredy REST operations are explicitly authorized for this screen.
@MainActor
struct JobsView: View {
    @State private var model: JobsModel
    @State private var retryTask: Task<Void, Never>?
    let onSessionExpired: () -> Void
    let onSelect: (String) -> Void

    init(service: any FredyJobsServing, model: JobsModel? = nil,
         onSelect: @escaping (String) -> Void = { _ in },
         onSessionExpired: @escaping () -> Void) {
        _model = State(initialValue: model ?? JobsModel(service: service))
        self.onSessionExpired = onSessionExpired
        self.onSelect = onSelect
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                if model.state == .sessionExpired {
                    Label("listings.session_expired", systemImage: "lock")
                    Button("listings.sign_in", action: onSessionExpired)
                        .buttonStyle(.borderedProminent)
                } else {
                    ForEach(model.jobs) { job in
                        JobCard(job: job, onSelect: { onSelect(job.id) })
                    }

                    if model.isLoading || model.state == .idle {
                        ProgressView("jobs.loading")
                            .frame(maxWidth: .infinity, minHeight: 90)
                    } else if case .failed(let failure) = model.state {
                        Label(LocalizedStringKey(failure.localizationKey),
                              systemImage: "exclamationmark.triangle")
                            .fixedSize(horizontal: false, vertical: true)
                        Button("listings.retry", action: retry)
                            .buttonStyle(.bordered)
                            .frame(minHeight: 44)
                    } else if model.jobs.isEmpty {
                        ContentUnavailableView("لا توجد مهام بحث",
                                               systemImage: "magnifyingglass",
                                               description: Text("أضف مهمة جديدة من زر + في الأعلى."))
                    } else {
                        Text("jobs.snapshot_note")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 18)
            .padding(.bottom, 30)
        }
        .environment(\.colorScheme, .dark)
        .background(Color(red: 0.065, green: 0.065, blue: 0.063).ignoresSafeArea())
        .navigationTitle("مهام البحث")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color(red: 0.065, green: 0.065, blue: 0.063), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .accessibilityIdentifier("jobs.screen")
        .task { await model.loadIfNeeded() }
        .refreshable { await model.reload() }
        .onChange(of: model.state) { _, state in
            if state == .sessionExpired { onSessionExpired() }
        }
        .onDisappear { retryTask?.cancel() }
    }

    private func retry() {
        guard retryTask == nil else { return }
        retryTask = Task {
            await model.reload()
            retryTask = nil
        }
    }
}

@MainActor
private struct JobCard: View {
    let job: SearchJob
    let onSelect: () -> Void
    @State private var presentingDesignNotice = false

    private let cardBackground = Color(red: 0.095, green: 0.095, blue: 0.092)
    private let foreground = Color(red: 0.96, green: 0.96, blue: 0.96)
    private let secondary = Color(red: 0.62, green: 0.62, blue: 0.61)
    private let border = Color(red: 0.19, green: 0.19, blue: 0.18)

    private var providers: String {
        guard let provider = job.provider, !provider.isEmpty else { return "المصدر غير متاح" }
        let titles = provider.map { entry -> String in
            switch entry.id.lowercased() {
            case "immoscout": return "Immoscout"
            case "immowelt": return "Immowelt"
            case "kleinanzeigen": return "Kleinanzeigen"
            default: return entry.id
            }
        }
        return titles.joined(separator: " · ")
    }

    private var lastRunDescription: String {
        guard let timestamp = job.lastRunAt, timestamp > 0 else {
            return "آخر تشغيل غير متاح"
        }
        let relative = RelativeDateTimeFormatter()
        relative.locale = Locale(identifier: "ar")
        relative.unitsStyle = .full
        let date = Date(timeIntervalSince1970: timestamp / 1_000)
        return "آخر تشغيل " + relative.localizedString(for: date, relativeTo: Date())
    }

    private var statusTint: Color {
        if job.running == true { return Color(red: 0.93, green: 0.68, blue: 0.37) }
        if job.enabled == true { return Color(red: 0.56, green: 0.78, blue: 0.65) }
        return secondary
    }

    var body: some View {
        VStack(spacing: 0) {
            // Match the Fredy web card's left identity / right listings count.
            HStack(alignment: .top, spacing: 14) {
                HStack(alignment: .top, spacing: 14) {
                    Circle()
                        .fill(statusTint)
                        .frame(width: 10, height: 10)
                        .padding(.top, 11)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 10) {
                        Text(job.name ?? String(localized: "jobs.untitled",
                                                locale: Locale(identifier: "ar")))
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(foreground)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        Text(providers)
                            .font(.system(size: 16))
                            .foregroundStyle(secondary)

                        Text(lastRunDescription)
                            .font(.system(size: 15))
                            .foregroundStyle(secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        if job.running == nil {
                            Text("jobs.unknown")
                                .font(.caption2)
                                .foregroundStyle(secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                Spacer(minLength: 8)
                Button(action: onSelect) {
                    VStack(alignment: .trailing, spacing: 5) {
                        if let count = job.numberOfFoundListings {
                            Text(count, format: .number)
                                .font(.system(size: 31, weight: .semibold, design: .rounded))
                                .foregroundStyle(foreground)
                        } else {
                            Text("jobs.unavailable")
                                .font(.caption)
                                .foregroundStyle(secondary)
                        }
                        Text("الإعلانات")
                            .font(.system(size: 13))
                            .foregroundStyle(secondary)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("عرض الإعلانات المحفوظة لهذه المهمة")
            }
            .environment(\.layoutDirection, .leftToRight)
            .padding(.bottom, 27)

            Rectangle()
                .fill(border)
                .frame(height: 1)

            HStack(spacing: 10) {
                Button(action: showDesignNotice) {
                    ZStack(alignment: job.enabled == true ? .trailing : .leading) {
                        Capsule()
                            .fill(job.enabled == true ? Color.white : Color(red: 0.35, green: 0.35, blue: 0.35))
                            .frame(width: 46, height: 27)
                        Circle()
                            .fill(job.enabled == true ? Color.black : Color.white)
                            .frame(width: 21, height: 21)
                            .padding(.horizontal, 3)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("تفعيل أو إيقاف البحث الدوري")
                .accessibilityValue(job.enabled == true ? "مفعّل" : job.enabled == false ? "متوقف" : "غير معروف")

                Spacer(minLength: 0)

                Button(action: showDesignNotice) {
                    Label("تشغيل", systemImage: "play.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(foreground)
                        .padding(.horizontal, 13)
                        .frame(height: 39)
                        .overlay(RoundedRectangle(cornerRadius: 10)
                            .stroke(border.opacity(1.0), lineWidth: 1.5))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("تشغيل مهمة البحث")

                Button(action: showDesignNotice) {
                    Image(systemName: "pencil")
                        .font(.system(size: 19))
                        .frame(width: 35, height: 42)
                }
                .accessibilityLabel("تعديل المهمة")

                Button(action: showDesignNotice) {
                    Image(systemName: "square.on.square")
                        .font(.system(size: 19))
                        .frame(width: 35, height: 42)
                }
                .accessibilityLabel("نسخ المهمة")

                Menu {
                    Button(role: .destructive, action: showDesignNotice) {
                        Label("حذف جميع إعلانات هذه المهمة", systemImage: "list.bullet.minus")
                    }
                    Button(role: .destructive, action: showDesignNotice) {
                        Label("حذف المهمة", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 20, weight: .medium))
                        .frame(width: 43, height: 39)
                        .background(Color(red: 0.15, green: 0.15, blue: 0.14),
                                    in: Capsule())
                }
                .accessibilityLabel("مزيد من الخيارات")
            }
            .foregroundStyle(secondary)
            .environment(\.layoutDirection, .leftToRight)
            .padding(.top, 16)
        }
        .padding(20)
        .background(cardBackground, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18)
            .stroke(border, lineWidth: 1))
        .alert("واجهة التحكم", isPresented: $presentingDesignNotice) {
            Button("حسنًا", role: .cancel) {}
        } message: {
            Text("هذا الزر للعرض حاليًا. لم يُنفَّذ أي تغيير على مهام Fredy أو إعلاناتها.")
        }
    }

    private func showDesignNotice() {
        presentingDesignNotice = true
    }
}
