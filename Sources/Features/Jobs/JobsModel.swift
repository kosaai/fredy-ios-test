import Foundation
import Observation

enum JobsState: Equatable {
    case idle, loading, loaded
    case failed(ListingsFailure)
    case sessionExpired
}

@Observable
@MainActor
final class JobsModel {
    private(set) var jobs: [SearchJob] = []
    private(set) var runRevision = 0
    private(set) var state: JobsState = .idle
    private var generation = 0
    private(set) var pendingAction: JobControlIntent?
    private(set) var pendingRemoval: JobRemovalIntent?
    private(set) var removalNotice: String?
    private(set) var management: JobManagementModel?
    var managementPresented = false
    private(set) var actionNotices: [String: String] = [:]
    private var requiresRefresh: Set<String> = []
    @ObservationIgnored private var actionTask: Task<Void, Never>?
    @ObservationIgnored private var removalTask: Task<Void, Never>?
    @ObservationIgnored private let service: any FredyJobsServing

    init(service: any FredyJobsServing) {
        self.service = service
    }

    var isLoading: Bool { state == .loading }

    func loadIfNeeded() async {
        guard state == .idle else { return }
        await reload()
    }

    func reload() async {
        guard !isLoading, pendingAction == nil, pendingRemoval == nil,
              management?.busy != true, state != .sessionExpired else { return }
        let previousState = state
        let requestGeneration = generation
        state = .loading
        do {
            let result = try await service.fetchJobs()
            try Task.checkCancellation()
            guard requestGeneration == generation else { return }
            guard state != .sessionExpired else { return }
            var seen = Set<String>()
            jobs = result.filter { seen.insert($0.id).inserted }
            requiresRefresh.removeAll()
            state = .loaded
        } catch is CancellationError {
            guard requestGeneration == generation else { return }
            if state != .sessionExpired { state = previousState }
        } catch let failure as ListingsFailure {
            guard requestGeneration == generation else { return }
            if state == .sessionExpired { return }
            if failure == .sessionExpired {
                jobs = []
                state = .sessionExpired
            } else {
                state = .failed(failure)
            }
        } catch {
            guard requestGeneration == generation else { return }
            if state != .sessionExpired { state = .failed(.network) }
        }
    }

    func acceptSnapshot(_ snapshot: [SearchJob]) {
        guard state != .sessionExpired, pendingAction == nil, pendingRemoval == nil else { return }
        generation += 1
        var seen = Set<String>()
        jobs = snapshot.filter { seen.insert($0.id).inserted }
        state = .loaded
    }

    func canRun(_ job: SearchJob) -> Bool {
        canControl(job) && job.running == false && job.hasNoNotificationChannels == true
    }

    func canChangeEnabled(_ job: SearchJob) -> Bool {
        canControl(job) && job.enabled != nil &&
            (job.enabled == true || job.hasNoNotificationChannels == true)
    }

    private func canControl(_ job: SearchJob) -> Bool {
        state == .loaded && pendingAction == nil && pendingRemoval == nil &&
            management?.blocksWrites != true && job.isOnlyShared == false &&
            !requiresRefresh.contains(job.id)
    }

    func canManage(_ job: SearchJob) -> Bool {
        state == .loaded && pendingAction == nil && pendingRemoval == nil &&
            management?.blocksWrites != true && job.isOnlyShared == false
    }

    /// Deletion is deliberately unavailable until the scheduler is disabled and
    /// the exact job is confirmed stopped. Shared or unknown permissions fail closed.
    func canRemove(_ job: SearchJob) -> Bool {
        state == .loaded && pendingAction == nil && pendingRemoval == nil &&
        management?.blocksWrites != true && !requiresRefresh.contains(job.id) &&
        job.isOnlyShared == false && job.enabled == false && job.running == false &&
        job.dealType == "rent" && !(job.name ?? "").isEmpty
    }

    func requestRemoval(_ intent: JobRemovalIntent) {
        guard pendingAction == nil, pendingRemoval == nil,
              actionTask == nil, removalTask == nil,
              let current = jobs.first(where: { $0.id == intent.id }),
              canRemove(current) else { return }
        pendingRemoval = intent // Synchronous lock before any await or network side effect.
        generation += 1
        removalNotice = "جارٍ التحقق من أحدث حالة المهمة قبل الحذف…"
        removalTask = Task { await performRemoval(intent, baseline: current) }
    }

    /// At most one DELETE attempt after a fresh permission, identity, and status read.
    /// Lost/ambiguous DELETE acknowledgements are never replayed automatically.
    private func performRemoval(_ intent: JobRemovalIntent, baseline: SearchJob) async {
        let id = intent.id
        var writeAttempted = false
        defer { pendingRemoval = nil; removalTask = nil }
        do {
            let before = try await service.fetchJobs()
            try Task.checkCancellation()
            guard state != .sessionExpired,
                  let current = before.first(where: { $0.id == id }),
                  current.isOnlyShared == false, current.enabled == false,
                  current.running == false, current.dealType == "rent",
                  current.name == baseline.name, current.provider == baseline.provider,
                  current.numberOfFoundListings == baseline.numberOfFoundListings else {
                throw ListingsFailure.conflict
            }
            writeAttempted = true
            switch intent {
            case .clearListings:
                try await service.hideAllListingsForJob(id: id)
            case .deleteJob:
                try await service.deleteSearchJob(id: id)
            }
            try Task.checkCancellation()
            let after = try await service.fetchJobs()
            try Task.checkCancellation()
            guard state != .sessionExpired else { return }
            switch intent {
            case .clearListings:
                guard let confirmed = after.first(where: { $0.id == id }),
                      confirmed.numberOfFoundListings == 0 else {
                    throw ListingsFailure.invalidResponse
                }
            case .deleteJob:
                guard !after.contains(where: { $0.id == id }) else {
                    throw ListingsFailure.invalidResponse
                }
            }
            generation += 1
            var seen = Set<String>()
            jobs = after.filter { seen.insert($0.id).inserted }
            state = .loaded
            requiresRefresh.remove(id)
            removalNotice = intent.isJobDeletion
                ? "تأكد حذف المهمة من الخادم. حذفها قد يشمل إعلاناتها أيضًا."
                : "أكد الخادم إخفاء جميع إعلانات المهمة، مع إبقاء مهمة البحث محفوظة."
        } catch is CancellationError {
            if state != .sessionExpired {
                if writeAttempted { requiresRefresh.insert(id) }
                removalNotice = writeAttempted
                    ? "نتيجة الحذف غير مؤكدة؛ حدّث المهام للتحقق. لم نكرر طلب الحذف."
                    : "أُلغي التحقق قبل إرسال أي حذف."
            }
        } catch let failure as ListingsFailure {
            if failure == .sessionExpired {
                expireManagementSession()
                return
            }
            if writeAttempted { requiresRefresh.insert(id) }
            removalNotice = writeAttempted
                ? "نتيجة الحذف غير مؤكدة. حدّث القائمة للتحقق، ولا تكرر الحذف. " + controlError(failure)
                : "لم يُرسل أي حذف؛ تغيّرت بيانات المهمة أو لا تملك صلاحية. " + controlError(failure)
        } catch {
            if state != .sessionExpired {
                if writeAttempted { requiresRefresh.insert(id) }
                removalNotice = writeAttempted
                    ? "تعذر التحقق بعد الحذف؛ لا نعيد إرساله. حدّث القائمة للتحقق."
                    : "تعذر التحقق من المهمة؛ لم نرسل حذفًا."
            }
        }
    }

    func openManagement(id: String, duplicate: Bool) {
        if management?.blocksWrites == true { managementPresented = true; return }
        guard let job = jobs.first(where: { $0.id == id }), canManage(job) else { return }
        management = JobManagementModel(sourceID: id, duplicate: duplicate, service: service,
            onSaved: { [weak self] in Task { await self?.reload() } },
            onExpired: { [weak self] in self?.expireManagementSession() })
        managementPresented = true
    }

    func expireSession() {
        actionTask?.cancel()
        removalTask?.cancel()
        pendingRemoval = nil
        removalNotice = nil
        management?.expireSession()
        pendingAction = nil
        expireManagementSession()
    }

    private func expireManagementSession() {
        generation += 1; jobs = []; actionNotices = [:]; requiresRefresh.removeAll()
        removalTask?.cancel(); pendingRemoval = nil; removalNotice = nil
        managementPresented = false; management = nil; state = .sessionExpired
    }

    func requestRun(id: String) {
        guard let job = jobs.first(where: { $0.id == id }), canRun(job) else { return }
        beginControl(.run(id))
    }

    func requestEnabledChange(id: String, enabled: Bool) {
        guard let job = jobs.first(where: { $0.id == id }), canChangeEnabled(job) else { return }
        guard !enabled || job.hasNoNotificationChannels == true else { return }
        beginControl(.enabled(id, enabled))
    }

    private func beginControl(_ intent: JobControlIntent) {
        guard pendingAction == nil, pendingRemoval == nil, actionTask == nil, removalTask == nil else { return }
        pendingAction = intent
        generation += 1
        actionNotices[intent.id] = "جارٍ التحقق من المهمة وإرسال الطلب…"
        // Shared-model ownership survives navigation/scroll recycling; never replay.
        actionTask = Task { await performControl(intent) }
    }

    private func performControl(_ intent: JobControlIntent) async {
        let id = intent.id
        var writeAttempted = false
        var runAccepted = false
        defer { pendingAction = nil; actionTask = nil }
        do {
            let before = try await service.fetchJobs()
            try Task.checkCancellation()
            guard state != .sessionExpired,
                  let current = before.first(where: { $0.id == id }) else { throw ListingsFailure.invalidResponse }
            guard current.isOnlyShared == false else { throw ListingsFailure.accessDenied }
            switch intent {
            case .run:
                guard current.hasNoNotificationChannels == true else { throw JobControlFailure.notificationChannelsNotAllowed }
                guard current.running != nil else { throw ListingsFailure.invalidResponse }
                guard current.running == false else { throw ListingsFailure.conflict }
                writeAttempted = true
                try await service.runSearch(id: id)
                runAccepted = true
                runRevision += 1
            case .enabled(_, let enabled):
                guard !enabled || current.hasNoNotificationChannels == true else { throw JobControlFailure.notificationChannelsNotAllowed }
                guard current.enabled != nil else { throw ListingsFailure.invalidResponse }
                writeAttempted = true
                try await service.setJobEnabled(id: id, enabled: enabled)
            }
            try Task.checkCancellation()
            let snapshot = try await service.fetchJobs()
            try Task.checkCancellation()
            guard state != .sessionExpired,
                  let confirmed = snapshot.first(where: { $0.id == id }) else { throw ListingsFailure.invalidResponse }
            if case .enabled(_, let enabled) = intent {
                guard confirmed.enabled == enabled else { throw ListingsFailure.invalidResponse }
            }
            // Only a real read-back can move the displayed switch or running state.
            generation += 1
            var seen = Set<String>()
            jobs = snapshot.filter { seen.insert($0.id).inserted }
            state = .loaded
            requiresRefresh.remove(id)
            switch intent {
            case .run:
                actionNotices[id] = "قُبل طلب التشغيل مرة واحدة. الحالة من آخر قراءة؛ القبول لا يعني اكتمال البحث أو نجاح المزوّد."
            case .enabled(_, let enabled):
                actionNotices[id] = enabled
                    ? "أكد الخادم تفعيل البحث الدوري. لم نرسل تشغيلًا يدويًا أو نغيّر قنوات التنبيه."
                    : "أكد الخادم إيقاف البحث الدوري. هذا لا يلغي بحثًا قيد التشغيل."
            }
        } catch JobControlFailure.notificationChannelsNotAllowed {
            requiresRefresh.insert(id)
            actionNotices[id] = "لم نرسل الطلب: قنوات التنبيه غير فارغة أو غير مؤكدة. لا يدعم هذا المسار كتم التنبيهات، والإيقاف فقط يبقى متاحًا بعد التحديث."
        } catch is CancellationError {
            if state != .sessionExpired {
                if writeAttempted { requiresRefresh.insert(id) }
                actionNotices[id] = "تعذر تأكيد الطلب. حدّث القائمة للتحقق؛ لم نكرر أي كتابة."
            }
        } catch let failure as ListingsFailure {
            if failure == .sessionExpired {
                generation += 1
                jobs = []
                actionNotices = [:]
                requiresRefresh.removeAll()
                state = .sessionExpired
                return
            }
            requiresRefresh.insert(id)
            actionNotices[id] = runAccepted
                ? "قُبل طلب التشغيل، لكن تعذر تحديث المهمة. حدّث القائمة؛ لم نكرر التشغيل. " + controlError(failure)
                : controlError(failure) + (writeAttempted ? " حدّث القائمة لتأكيد الحالة؛ لم نكرر الكتابة." : " لم نرسل كتابة إلى الخادم.")
        } catch {
            guard state != .sessionExpired else { return }
            if writeAttempted { requiresRefresh.insert(id) }
            actionNotices[id] = "تعذر تأكيد الطلب. حدّث القائمة؛ لم نعد إرسال أي كتابة."
        }
    }

    private func controlError(_ failure: ListingsFailure) -> String {
        switch failure {
        case .sessionExpired: return "انتهت الجلسة. أعد تسجيل الدخول."
        case .accessDenied: return "لا تسمح صلاحياتك بهذا الإجراء، أو رفض الخادم الوصول."
        case .conflict: return "رفض التشغيل لتعارض أو لأن المهمة قيد التشغيل."
        case .rateLimited: return "طلبات كثيرة؛ انتظر ثم حدّث الحالة."
        case .invalidInput: return "تعذر قبول بيانات المهمة."
        case .invalidResponse, .dashboardDecoding: return "لم يؤكد رد الخادم الحالة المطلوبة."
        case .network: return "تعذر الاتصال بالخادم."
        case .server, .imageUnavailable: return "تعذر إتمام الطلب لدى الخادم."
        }
    }
}

enum JobControlIntent: Equatable {
    case run(String)
    case enabled(String, Bool)

    var id: String {
        switch self {
        case .run(let id), .enabled(let id, _): return id
        }
    }
}

private enum JobControlFailure: Error {
    case notificationChannelsNotAllowed
}

enum JobRemovalIntent: Equatable {
    case clearListings(String)
    case deleteJob(String)

    var id: String {
        switch self {
        case .clearListings(let id), .deleteJob(let id): return id
        }
    }

    var isJobDeletion: Bool {
        if case .deleteJob = self { return true }
        return false
    }
}
