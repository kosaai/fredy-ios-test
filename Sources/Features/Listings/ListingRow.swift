import SwiftUI
import UIKit

/// A native, compact rental card with the real Fredy v31 user actions.
/// The existing title, location, price, rooms and square photo remain unchanged.
@MainActor
struct ListingRow: View {
    let listing: RentalListing
    let images: ListingImageLoader
    let actions: any FredyListingActionServing
    let onChanged: () -> Void
    let onSessionExpired: () -> Void

    @State private var initializedFromServer = false
    @State private var watched: Bool?
    @State private var decision: String?
    @State private var busy = false
    @State private var showingLetter = false
    @State private var confirmingRemoval = false
    @State private var showingError = false
    @State private var errorMessage = ""

    private let photoSide: CGFloat = 116

    private var originalURL: URL? {
        guard let raw = listing.link,
              let parts = URLComponents(string: raw),
              parts.scheme?.lowercased() == "https",
              let host = parts.host, !host.isEmpty,
              parts.user == nil, parts.password == nil
        else { return nil }
        return parts.url
    }

    private var statusTitle: String {
        switch decision {
        case "applied": "تم التقديم"
        case "rejected": "مرفوض"
        case "accepted": "مقبول"
        default: "الحالة"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 13) {
                VStack(alignment: .leading, spacing: 9) {
                    Text(listing.title ?? String(localized: "listings.untitled",
                                                 locale: Locale(identifier: "ar")))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if let address = listing.address {
                        Text(address)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if let price = listing.euroPrice {
                        Text(price, format: .currency(code: "EUR"))
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(red: 0.14, green: 0.47, blue: 0.34))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Text("listings.unavailable")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 13) {
                        if let rooms = listing.rooms {
                            Label {
                                Text(rooms, format: .number.locale(Locale(identifier: "ar")))
                            } icon: {
                                Image(systemName: "door.left.hand.closed")
                            }
                        }

                        if let size = listing.size {
                            Label {
                                Text(size, format: .number.locale(Locale(identifier: "ar")))
                                + Text(" m²")
                            } icon: {
                                Image(systemName: "square.dashed")
                            }
                        }
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                ListingImageView(listingID: listing.id, loader: images,
                                 onSessionExpired: onSessionExpired,
                                 thumbnailSize: photoSide)
                    .frame(width: photoSide, height: photoSide)
                    .background(Color(uiColor: .tertiarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(alignment: .topLeading) {
                        Button(action: toggleWatch) {
                            Image(systemName: watched == true ? "star.fill" : "star")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(watched == true ? .yellow : .primary)
                                .frame(width: 31, height: 31)
                                .background(.regularMaterial, in: Circle())
                        }
                        .buttonStyle(.plain)
                        .disabled(busy || watched == nil)
                        .padding(5)
                        .accessibilityLabel(watched == true ? "إزالة من المتابعة" : "إضافة إلى المتابعة")
                        .accessibilityIdentifier("listing.watch")
                    }
                    .overlay(alignment: .topTrailing) {
                        if let publishedDate = listing.publishedDate {
                            Text(publishedDate, style: .relative)
                                .font(.system(size: 9, weight: .medium))
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 5)
                                .background(.regularMaterial, in: Capsule())
                                .padding(5)
                        }
                    }
                    .accessibilityIdentifier("listings.thumbnail")
            }

            Divider()

            HStack(spacing: 8) {
                Text(listing.provider ?? "المصدر غير متاح")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer(minLength: 6)

                Menu {
                    Button("بدون حالة") { updateStatus(nil) }
                    Button("تم التقديم") { updateStatus("applied") }
                    Button("مرفوض") { updateStatus("rejected") }
                    Button("مقبول") { updateStatus("accepted") }
                } label: {
                    Label(statusTitle, systemImage: "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 11)
                        .padding(.vertical, 8)
                        .background(Color(uiColor: .tertiarySystemGroupedBackground),
                                    in: Capsule())
                }
                .disabled(busy)
                .accessibilityIdentifier("listing.status")
            }

            HStack(spacing: 13) {
                Button {
                    showingLetter = true
                } label: {
                    Label("نسخ رسالة التقديم", systemImage: "doc.on.doc")
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
                .disabled(busy)
                .accessibilityIdentifier("listing.application")

                if let originalURL {
                    Link(destination: originalURL) {
                        Image(systemName: "arrow.up.right.square")
                            .frame(width: 26, height: 40)
                    }
                    .accessibilityLabel("فتح الإعلان الأصلي")
                    .accessibilityIdentifier("listing.external_link")
                }

                Menu {
                    Button("إزالة الإعلان", systemImage: "trash", role: .destructive) {
                        confirmingRemoval = true
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 20))
                        .frame(width: 27, height: 40)
                }
                .disabled(busy)
                .accessibilityLabel("خيارات الإعلان")
                .accessibilityIdentifier("listing.more")
            }
            .foregroundStyle(.primary)

            if busy {
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            Color(uiColor: .secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 19)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 19)
                .strokeBorder(Color(uiColor: .separator).opacity(0.18), lineWidth: 0.5)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("listings.row.horizontal")
        .onAppear {
            guard !initializedFromServer else { return }
            watched = listing.isWatched
            decision = listing.decision
            initializedFromServer = true
        }
        .onChange(of: listing.isWatched) { _, value in watched = value }
        .onChange(of: listing.decision) { _, value in decision = value }
        .sheet(isPresented: $showingLetter) {
            ListingApplicationSheet(
                listingID: listing.id, actions: actions,
                onApplied: {
                    decision = "applied"
                    watched = true
                    onChanged()
                },
                onSessionExpired: onSessionExpired
            )
        }
        .confirmationDialog(
            "إزالة الإعلان من القائمة؟",
            isPresented: $confirmingRemoval,
            titleVisibility: .visible
        ) {
            Button("إزالة قابلة للاستعادة", role: .destructive, action: removeListing)
            Button("إلغاء", role: .cancel) {}
        } message: {
            Text("سيُخفى هذا الإعلان من القائمة، ويمكن استعادته من Fredy. لن يُحذف نهائيًا.")
        }
        .alert("تعذر إتمام العملية", isPresented: $showingError) {
            Button("حسنًا", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    private func toggleWatch() {
        guard !busy, let watched else { return }
        busy = true
        Task {
            defer { busy = false }
            do {
                try await actions.toggleListingWatch(id: listing.id)
                self.watched = !watched
                onChanged()
            } catch { handle(error) }
        }
    }

    private func updateStatus(_ next: String?) {
        guard !busy, next != decision else { return }
        busy = true
        Task {
            defer { busy = false }
            do {
                try await actions.setListingStatus(id: listing.id, status: next)
                decision = next
                if next != nil { watched = true }
                onChanged()
            } catch { handle(error) }
        }
    }

    private func removeListing() {
        guard !busy else { return }
        busy = true
        Task {
            defer { busy = false }
            do {
                try await actions.softRemoveListing(id: listing.id)
                onChanged()
            } catch { handle(error) }
        }
    }

    private func handle(_ error: Error) {
        if let failure = error as? ListingsFailure, failure == .sessionExpired {
            onSessionExpired()
            return
        }
        if let failure = error as? ListingsFailure {
            switch failure {
            case .accessDenied:
                errorMessage = "ليس لديك صلاحية لتنفيذ هذا الإجراء."
            case .rateLimited:
                errorMessage = "طلبات كثيرة. حاول مجددًا لاحقًا."
            case .invalidInput, .invalidResponse:
                errorMessage = "لم يقبل الخادم العملية المطلوبة."
            case .conflict:
                errorMessage = "تعارض مع حالة الإعلان الحالية."
            default:
                errorMessage = "تعذر الاتصال بالخادم أو إتمام الطلب."
            }
        } else {
            errorMessage = "تعذر تنفيذ الطلب. تحقق من الاتصال وأعد المحاولة."
        }
        showingError = true
    }
}

@MainActor
private struct ListingApplicationSheet: View {
    let listingID: String
    let actions: any FredyListingActionServing
    let onApplied: () -> Void
    let onSessionExpired: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var loading = true
    @State private var copying = false
    @State private var letterText = ""
    @State private var hasProfile: Bool?
    @State private var missing: [String] = []
    @State private var unknown: [String] = []
    @State private var notice: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if loading {
                        ProgressView("جلب رسالة التقديم")
                            .frame(maxWidth: .infinity, minHeight: 100)
                    } else {
                        if hasProfile == false {
                            Label("بيانات مقدم الطلب غير مكتملة في إعدادات الخادم.",
                                  systemImage: "person.crop.circle.badge.exclamationmark")
                                .font(.footnote)
                                .foregroundStyle(.orange)
                        }
                        if !missing.isEmpty {
                            Text("حقول ناقصة: " + missing.joined(separator: "، "))
                                .font(.footnote)
                                .foregroundStyle(.orange)
                        }
                        if !unknown.isEmpty {
                            Text("متغيرات غير معروفة: " + unknown.joined(separator: "، "))
                                .font(.footnote)
                                .foregroundStyle(.orange)
                        }
                        TextEditor(text: $letterText)
                            .frame(minHeight: 250)
                            .padding(9)
                            .scrollContentBackground(.hidden)
                            .background(Color(uiColor: .secondarySystemGroupedBackground),
                                        in: RoundedRectangle(cornerRadius: 15))
                            .accessibilityIdentifier("listing.application.text")

                        Button(action: copyAndMarkApplied) {
                            if copying { ProgressView() }
                            else { Label("نسخ الرسالة وتحديد تم التقديم", systemImage: "doc.on.doc") }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(copying || letterText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("listing.application.copy")

                        Text("لن تتغير حالة الإعلان إلا بعد نسخ الرسالة بالفعل.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    if let notice {
                        Text(notice)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding()
            }
            .navigationTitle("رسالة التقديم")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("إغلاق") { dismiss() }
                }
            }
            .task { await loadLetter() }
        }
    }

    private func loadLetter() async {
        loading = true
        defer { loading = false }
        do {
            let draft = try await actions.fetchListingApplication(id: listingID)
            try Task.checkCancellation()
            letterText = draft.text
            hasProfile = draft.hasProfile
            missing = draft.missing ?? []
            unknown = draft.unknown ?? []
            notice = nil
        } catch is CancellationError {
            return
        } catch {
            if (error as? ListingsFailure) == .sessionExpired {
                onSessionExpired()
                dismiss()
                return
            }
            notice = "لم نتمكن من جلب رسالة حقيقية من الخادم. لا توجد رسالة جاهزة للنسخ."
        }
    }

    private func copyAndMarkApplied() {
        guard !copying, !letterText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        // A user explicitly requested the pasteboard write. No automatic copy.
        UIPasteboard.general.string = letterText
        guard UIPasteboard.general.string == letterText else {
            notice = "لم تنجح عملية النسخ."
            return
        }
        copying = true
        Task {
            defer { copying = false }
            do {
                try await actions.setListingStatus(id: listingID, status: "applied")
                onApplied()
                dismiss()
            } catch {
                if (error as? ListingsFailure) == .sessionExpired {
                    onSessionExpired()
                    dismiss()
                } else {
                    notice = "نُسخت الرسالة، لكن لم تُحفَظ حالة «تم التقديم». يمكنك اختيار الحالة يدويًا."
                }
            }
        }
    }
}
