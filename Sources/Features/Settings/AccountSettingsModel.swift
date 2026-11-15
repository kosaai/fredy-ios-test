import Foundation
import Observation
import SwiftUI

enum DataEditIssue: Error, Equatable {
    case conflict, invalid, notConfirmed, unsupported
}

@Observable
@MainActor
final class AccountSettingsModel {
    private(set) var saved: JSONValue = .object([:])
    var draft: JSONValue = .object([:])
    private(set) var providers: [SearchProvider] = []
    private(set) var loaded = false
    private(set) var busy = false
    private(set) var sessionExpired = false
    private(set) var uncertain = false
    private(set) var needsReload = false
    private(set) var notice: String?
    private(set) var providerNotice: String?
    private var pending: (AccountSettingKey, JSONValue)?
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private let service: any FredyClientServing

    init(service: any FredyClientServing) { self.service = service }
    var editable: Bool { loaded && !busy && !uncertain && !needsReload && !sessionExpired }

    func canEdit(_ key: AccountSettingKey) -> Bool {
        guard editable else { return false }
        let v = saved[key.rawValue]
        if v == .null { return true }
        switch key {
        case .theme: return v.stringValue != nil
        case .blacklist_filter_on_provider_details: return v.boolValue != nil
        case .provider_details: return v.arrayValue?.allSatisfy { $0.stringValue != nil } == true
        case .home_addresses: return v.arrayValue?.allSatisfy { $0.objectValue != nil } == true
        default: return v.objectValue != nil
        }
    }

    func canSave(_ key: AccountSettingKey) -> Bool {
        canEdit(key) && draft[key.rawValue] != saved[key.rawValue]
    }

    func loadIfNeeded() async { if !loaded { await reloadDiscardingDraft() } }

    func reloadDiscardingDraft() async {
        guard !busy, !uncertain, !sessionExpired else { return }
        busy = true
        defer { busy = false }
        do {
            let value = try await service.fetchAccountSettings()
            try Task.checkCancellation()
            saved = value; draft = value; loaded = true; needsReload = false; notice = nil
            do {
                providers = try await service.fetchSearchProviders()
                providerNotice = nil
            } catch {
                if (error as? ListingsFailure) == .sessionExpired { throw error }
                providers = []
                providerNotice = "تعذر تحميل قائمة المزوّدين؛ اختيارهم محجوب، وبقية الإعدادات المحفوظة متاحة."
            }
        } catch { handle(error, wrote: false) }
    }

    /// A single explicit save, not a multi-endpoint pseudo-transaction.
    func save(_ key: AccountSettingKey) {
        guard task == nil, canSave(key) else { return }
        let desired = draft[key.rawValue]
        do { try validate(key, desired) } catch { handle(error, wrote: false); return }
        let baseline = saved[key.rawValue]
        busy = true
        notice = "جارٍ التحقق والحفظ…"
        task = Task {
            var wrote = false
            var acknowledged = false
            defer { busy = false; task = nil }
            do {
                let fresh = try await service.fetchAccountSettings()
                try Task.checkCancellation()
                guard fresh[key.rawValue] == baseline else { throw DataEditIssue.conflict }
                pending = (key, desired)
                wrote = true
                try await service.saveAccountSetting(key, value: desired)
                acknowledged = true
                try Task.checkCancellation()
                let confirmed = try await service.fetchAccountSettings()
                try Task.checkCancellation()
                guard matches(key, desired, confirmed[key.rawValue]) else { throw DataEditIssue.notConfirmed }
                accept(confirmed, key: key)
            } catch { handle(error, wrote: wrote, mayHaveCommitted: acknowledged) }
        }
    }

    func reconcile() async {
        guard !busy, !sessionExpired, let (key, desired) = pending else { return }
        busy = true
        defer { busy = false }
        do {
            let confirmed = try await service.fetchAccountSettings()
            try Task.checkCancellation()
            guard matches(key, desired, confirmed[key.rawValue]) else { throw DataEditIssue.notConfirmed }
            accept(confirmed, key: key)
        } catch { handle(error, wrote: true, mayHaveCommitted: true) }
    }

    private func accept(_ value: JSONValue, key: AccountSettingKey) {
        // Keep unsaved edits in other cards; adopt fresh values only for untouched cards.
        var nextSaved = value
        for field in AccountSettingKey.allCases {
            let baseline = saved[field.rawValue]
            if field == key || draft[field.rawValue] == baseline {
                draft[field.rawValue] = value[field.rawValue]
            } else {
                // A dirty draft is still based on its original snapshot, not this later read.
                nextSaved[field.rawValue] = baseline
            }
        }
        saved = nextSaved; pending = nil; uncertain = false; needsReload = false
        notice = key == .home_addresses
            ? "تأكد حفظ العناوين بقراءة مستقلة. الحسابات الجغرافية وأوقات التنقل قد تُستكمل لاحقًا؛ الحفظ ليس اكتمال الحساب."
            : "تأكد حفظ هذه القيمة بقراءة مستقلة من الخادم. التعديلات في البطاقات الأخرى لم تُرسل."
    }

    private func handle(_ error: Error, wrote: Bool, mayHaveCommitted: Bool = false) {
        if (error as? ListingsFailure) == .sessionExpired { expire(); return }
        let rejected = [ListingsFailure.accessDenied, .invalidInput, .conflict, .rateLimited].contains(error as? ListingsFailure ?? .network)
        if wrote && (!rejected || mayHaveCommitted || uncertain) { uncertain = true }
        else { pending = nil; needsReload = (error as? DataEditIssue) != .invalid }
        if (error as? DataEditIssue) == .invalid {
            notice = "القيمة غير صالحة أو تتجاوز حدود الخادم. راجع الحقول؛ لم يُرسل حفظ."
        } else if uncertain {
            notice = "نتيجة الحفظ غير مؤكدة. احتُفظ بالمسودة وآخر قراءة؛ استخدم التحقق القرائي فقط، ولن نكرر الحفظ."
        } else if (error as? DataEditIssue) == .conflict {
            notice = "تغيّرت هذه الإعدادات منذ فتحها. أعد تحميل المحفوظ بعد مراجعة مسودتك؛ لم نستبدل التغيير الجديد."
        } else {
            notice = "تعذر إتمام الطلب أو رفضه الخادم. راجع الصلاحيات والاتصال، ثم أعد تحميل القيم. لم نعرض نجاحًا أو نعد إرسال كتابة."
        }
    }

    private func expire() {
        sessionExpired = true; loaded = false; saved = .object([:]); draft = .object([:])
        pending = nil; providers = []; notice = nil; providerNotice = nil
    }

    private func matches(_ key: AccountSettingKey, _ expected: JSONValue, _ actual: JSONValue) -> Bool {
        guard key == .home_addresses else { return expected == actual }
        // Server geocodes and rebuilds addresses: verify every routing input, not generated coords.
        guard let left = expected.arrayValue else { return false }
        // v31 clears the stored key for []; GET therefore omits it, rather than echoing [].
        if left.isEmpty && actual == .null { return true }
        guard let right = actual.arrayValue, left.count == right.count else { return false }
        return zip(left, right).allSatisfy { a, b in
            let category = a["kind"] == .string("category")
            let fields = category ? ["label", "category", "kind", "mode", "departure"] : ["label", "address", "mode", "departure"]
            return fields.allSatisfy { a[$0] == b[$0] }
        }
    }

    private func validate(_ key: AccountSettingKey, _ value: JSONValue) throws {
        switch key {
        case .theme:
            guard ["dark", "light"].contains(value.stringValue ?? "") else { throw DataEditIssue.invalid }
        case .listing_deletion_preference:
            guard value["hardDelete"] == .bool(false), value["skipPrompt"].boolValue != nil else { throw DataEditIssue.invalid }
        case .provider_details:
            guard let entries = value.arrayValue, entries.allSatisfy({ $0.stringValue?.isEmpty == false }) else { throw DataEditIssue.invalid }
        case .blacklist_filter_on_provider_details:
            guard value.boolValue != nil else { throw DataEditIssue.invalid }
        case .applicant_profile:
            guard value.objectValue != nil, try serializedLength(value) <= 20_000 else { throw DataEditIssue.invalid }
        case .application_templates:
            guard let languages = value.objectValue else { throw DataEditIssue.invalid }
            for (language, entries) in languages {
                guard ["de", "en", "it"].contains(language), let kinds = entries.objectValue else { throw DataEditIssue.invalid }
                for (kind, text) in kinds {
                    guard ["rent", "buy"].contains(kind), let text = text.stringValue, text.utf16.count <= 20_000 else { throw DataEditIssue.invalid }
                }
            }
        case .home_addresses:
            guard let entries = value.arrayValue, entries.count <= 20 else { throw DataEditIssue.invalid }
            var labels = Set<String>()
            for entry in entries {
                guard let label = entry["label"].stringValue, !label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      label.utf16.count <= 300, labels.insert(label.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()).inserted,
                      ["transit", "car", "bike", "walk"].contains(entry["mode"].stringValue ?? "") else { throw DataEditIssue.invalid }
                if entry["kind"] == .string("category") {
                    guard Self.placeCategories.contains(entry["category"].stringValue ?? "") else { throw DataEditIssue.invalid }
                } else {
                    guard let address = entry["address"].stringValue, !address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                          address.utf16.count <= 300 else { throw DataEditIssue.invalid }
                }
                if entry["departure"] != .null {
                    guard let time = entry["departure"]["time"].stringValue,
                          time.range(of: "^(?:[01][0-9]|2[0-3]):[0-5][0-9]$", options: .regularExpression) != nil else { throw DataEditIssue.invalid }
                }
            }
        }
    }

    private func serializedLength(_ value: JSONValue) throws -> Int {
        let data = try JSONEncoder().encode(value)
        guard let text = String(data: data, encoding: .utf8) else { throw DataEditIssue.invalid }
        return text.utf16.count
    }

    static let placeCategories = ["supermarket", "bakery", "pharmacy", "doctor", "kindergarten", "school", "gym", "swimmingPool", "park", "restaurant", "postOffice", "busStop", "trainStation"]

    func profileText(_ field: String) -> Binding<String> {
        Binding(get: {
            let v = self.draft["applicant_profile"][field]
            if case .number(let number) = v { return NSDecimalNumber(decimal: number).stringValue }
            return v.stringValue ?? ""
        }, set: { self.draft["applicant_profile"][field] = .string($0) })
    }

    func profileFlag(_ field: String) -> Binding<String> {
        Binding(get: {
            let value = self.draft["applicant_profile"][field]
            return value.boolValue.map { $0 ? "yes" : "no" } ?? (value == .null ? "unset" : "unknown")
        }, set: { value in
            if value == "unset" {
                var object = self.draft["applicant_profile"].objectValue ?? [:]; object.removeValue(forKey: field)
                self.draft["applicant_profile"] = .object(object)
            } else { self.draft["applicant_profile"][field] = .bool(value == "yes") }
        })
    }
}
