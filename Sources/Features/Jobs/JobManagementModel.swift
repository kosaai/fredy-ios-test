import Foundation
import Observation

@Observable
@MainActor
final class JobManagementModel: Identifiable {
    enum Phase: Equatable { case idle, loading, ready, saving, verified, uncertain, failed, sessionExpired }
    nonisolated let id = UUID()
    let sourceID: String
    let duplicate: Bool
    var name = ""
    var providers: [JSONValue] = []
    private(set) var phase: Phase = .idle
    private(set) var notice: String?
    private(set) var hasAttemptedWrite = false
    private(set) var sourceBaseline: JSONValue?
    private var sourceOwner: JSONValue = .null
    private var expected: JSONValue?
    private var receivedAcknowledgement = false
    private var uncertaintyLocked = false
    private var newID = UUID().uuidString
    @ObservationIgnored private let service: any FredyJobManagementServing
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private let onSaved: () -> Void
    @ObservationIgnored private let onExpired: () -> Void

    init(sourceID: String, duplicate: Bool, service: any FredyJobManagementServing,
         onSaved: @escaping () -> Void, onExpired: @escaping () -> Void) {
        self.sourceID = sourceID; self.duplicate = duplicate; self.service = service
        self.onSaved = onSaved; self.onExpired = onExpired
    }
    var busy: Bool { phase == .loading || phase == .saving }
    var blocksWrites: Bool { busy || phase == .uncertain }
    var canSave: Bool { phase == .ready && !hasAttemptedWrite && !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    func loadIfNeeded() async { if phase == .idle { await reloadDraft() } }

    func reloadDraft() async {
        guard !busy, phase != .uncertain, phase != .sessionExpired else { return }
        hasAttemptedWrite = false; receivedAcknowledgement = false; uncertaintyLocked = false
        phase = .loading
        do {
            let jobs = try await service.fetchManagedJobs()
            try Task.checkCancellation()
            guard phase != .sessionExpired else { return }
            guard let source = jobs.first(where: { $0["id"] == .string(sourceID) }),
                  source["isOnlyShared"] == .bool(false), source["userId"].stringValue?.isEmpty == false else {
                throw ListingsFailure.accessDenied
            }
            let payload = try Self.writable(source)
            sourceBaseline = payload; sourceOwner = source["userId"]
            name = (duplicate ? "نسخة من " : "") + (source["name"].stringValue ?? "")
            providers = payload["provider"].arrayValue ?? []
            expected = nil; hasAttemptedWrite = false; newID = UUID().uuidString
            phase = .ready; notice = nil
        } catch { handle(error) }
    }

    func save() {
        guard canSave, task == nil, let sourceBaseline else { return }
        var desired = sourceBaseline
        desired["name"] = .string(name.trimmingCharacters(in: .whitespacesAndNewlines))
        desired["provider"] = .array(providers)
        if duplicate { desired["jobId"] = .string(newID); desired["enabled"] = .bool(false) }
        guard duplicate || desired != sourceBaseline else { notice = "لم تتغير حقول قابلة للحفظ؛ لم يُرسل طلب."; return }
        // Unedited provider objects/URL bytes are retained; new URL input is strict, never repaired.
        let oldProviders = sourceBaseline["provider"].arrayValue ?? []
        guard providers.count == oldProviders.count, providers.enumerated().allSatisfy({ index, entry in
            guard let object = entry.objectValue, object["id"] == oldProviders[index]["id"],
                  let url = entry["url"].stringValue, !url.isEmpty else { return false }
            var preserved = oldProviders[index]
            preserved["url"] = entry["url"]
            guard entry == preserved else { return false }
            if url == oldProviders[index]["url"].stringValue { return true }
            guard url.utf8.count <= 16_384,
                  !url.unicodeScalars.contains(where: { CharacterSet.whitespacesAndNewlines.union(.controlCharacters).contains($0) }),
                  let parsed = URLComponents(string: url), parsed.scheme == "https", parsed.host?.isEmpty == false,
                  parsed.user == nil, parsed.password == nil, parsed.url != nil else { return false }
            // URL parsing must not repair malformed percent escapes.
            let bytes = Array(url.utf8)
            return bytes.indices.filter { bytes[$0] == 37 }.allSatisfy { i in
                i + 2 < bytes.count && [bytes[i + 1], bytes[i + 2]].allSatisfy { (48...57).contains($0) || (65...70).contains($0) || (97...102).contains($0) }
            }
        }) else { notice = "رابط غير صالح أو تغيّر ترتيب/هوية المزوّد. لا نصلح الرابط ولا نسقط إعداداته تلقائيًا."; return }
        expected = desired
        let submitted = desired
        phase = .saving
        notice = "جارٍ التحقق من أحدث إعدادات المهمة…"
        task = Task {
            defer { task = nil }
            do {
                let fresh = try await service.fetchManagedJobs()
                try Task.checkCancellation()
                guard let source = fresh.first(where: { $0["id"] == .string(sourceID) }),
                      source["isOnlyShared"] == .bool(false), source["userId"] == sourceOwner else { throw ListingsFailure.accessDenied }
                guard try Self.writable(source) == sourceBaseline else { throw DataEditIssue.conflict }
                if duplicate {
                    guard !fresh.contains(where: { $0["id"] == .string(newID) }) else { throw DataEditIssue.conflict }
                } else {
                    guard source["running"] == .bool(false) else { throw DataEditIssue.conflict }
                    guard submitted["enabled"] != .bool(true) || submitted["notificationAdapter"].arrayValue?.isEmpty == true else {
                        throw DataEditIssue.unsupported
                    }
                }
                hasAttemptedWrite = true
                try await service.saveManagedJob(submitted)
                receivedAcknowledgement = true
                try Task.checkCancellation()
                let after = try await service.fetchManagedJobs()
                try Task.checkCancellation()
                try verify(after)
            } catch { handle(error) }
        }
    }

    func reconcile() async {
        guard phase == .uncertain, !busy else { return }
        phase = .saving
        do {
            let after = try await service.fetchManagedJobs()
            try Task.checkCancellation()
            try verify(after)
        } catch { handle(error) }
    }

    func expireSession() {
        task?.cancel()
        phase = .sessionExpired
        sourceBaseline = nil; sourceOwner = .null; expected = nil
        providers = []; name = ""; notice = nil
    }

    private func verify(_ jobs: [JSONValue]) throws {
        guard let expected, let targetID = expected["jobId"].stringValue,
              let actual = jobs.first(where: { $0["id"] == .string(targetID) }),
              actual["isOnlyShared"] == .bool(false), try Self.writable(actual) == expected else { throw DataEditIssue.notConfirmed }
        if duplicate {
            guard let sourceBaseline, let source = jobs.first(where: { $0["id"] == .string(sourceID) }),
                  source["userId"] == sourceOwner, try Self.writable(source) == sourceBaseline else { throw DataEditIssue.notConfirmed }
        }
        phase = .verified
        notice = duplicate ? "تأكد وجود النسخة الجديدة وإعداداتها بقراءة مستقلة، والأصل ما يزال كما قُرئ. النسخة متوقفة ولم نطلب بحثًا."
            : "تأكد حفظ حقول المهمة وإعداداتها وصلاحيات المشاركة بقراءة مستقلة. لم نرسل تشغيلًا أو تنبيهًا."
        onSaved()
    }

    private func handle(_ error: Error) {
        guard phase != .sessionExpired else { return }
        if let failure = error as? ListingsFailure {
            switch failure {
            case .sessionExpired:
                phase = .sessionExpired; sourceBaseline = nil; sourceOwner = .null; expected = nil
                providers = []; name = ""; notice = nil; onExpired(); return
            case .invalidInput, .accessDenied, .conflict, .rateLimited:
                if hasAttemptedWrite && (receivedAcknowledgement || uncertaintyLocked) { break }
                phase = .failed
                notice = "رفض الخادم الطلب أو تعارضت الصلاحيات/البيانات. أعد تحميل مسودة حديثة قبل أي محاولة جديدة."
                return
            default: break
            }
        }
        if hasAttemptedWrite {
            uncertaintyLocked = true
            phase = .uncertain
            notice = "الحفظ غير مؤكد. لا نكرر POST ولا ننشئ نسخة أخرى. استخدم التحقق القرائي من نفس الهوية."
        } else {
            phase = .failed
            notice = (error as? DataEditIssue) == .unsupported
                ? "أوقف جدولة هذه المهمة أولًا من أزرار المرحلة الأولى: حفظ مهمة مفعّلة ذات قنوات تنبيه محجوب. لم نغيّر قنواتها."
                : "تعذر تحميل المهمة أو تغيّرت منذ فتحها، أو أن بنيتها غير مدعومة. لم نرسل كتابة؛ أعد تحميل المسودة."
        }
    }

    /// Full v31 upsert payload; never rebuild a job from the lossy display DTO.
    static func writable(_ source: JSONValue) throws -> JSONValue {
        guard let object = source.objectValue, let id = source["id"].stringValue, !id.isEmpty,
              source["enabled"].boolValue != nil, let providers = source["provider"].arrayValue,
              providers.allSatisfy({ $0.objectValue != nil && $0["id"].stringValue?.isEmpty == false && $0["url"].stringValue != nil }),
              let channels = source["notificationAdapter"].arrayValue,
              channels.allSatisfy({ $0["configuredAdapterId"].stringValue?.isEmpty == false }),
              ["blacklist", "excludedLocations", "shared_with_user"].allSatisfy({ source[$0].arrayValue?.allSatisfy { $0.stringValue != nil } == true }),
              ["spatialFilter", "specFilter", "commuteFilter", "name"].allSatisfy({ object.keys.contains($0) }),
              ["rent", "buy"].contains(source["dealType"].stringValue ?? "") else { throw DataEditIssue.unsupported }
        return .object([
            "jobId": .string(id), "name": source["name"], "enabled": source["enabled"],
            "provider": .array(providers), "blacklist": source["blacklist"], "excludedLocations": source["excludedLocations"],
            "shareWithUsers": source["shared_with_user"],
            "notificationAdapter": .array(channels.map { .object(["configuredAdapterId": $0["configuredAdapterId"]]) }),
            "spatialFilter": source["spatialFilter"], "specFilter": source["specFilter"],
            "commuteFilter": source["commuteFilter"], "dealType": source["dealType"]
        ])
    }
}
