import Foundation
import Observation

struct MCPTool: Decodable, Equatable, Identifiable, Sendable {
    let name: String
    let title: String
    let description: String
    let readOnly: Bool
    var id: String { name }
}

struct MCPConfiguration: Codable, Equatable, Sendable {
    let enabled: Bool
    let disabledTools: [String]

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.enabled == rhs.enabled && Set(lhs.disabledTools) == Set(rhs.disabledTools)
    }
}

struct MCPSettingsSnapshot: Decodable, Equatable, Sendable {
    let configuration: MCPConfiguration
    let tools: [MCPTool]
    private enum CodingKeys: String, CodingKey { case enabled, disabledTools, tools }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let enabled = try values.decode(Bool.self, forKey: .enabled)
        let disabledTools = try values.decode([String].self, forKey: .disabledTools)
        tools = try values.decode([MCPTool].self, forKey: .tools)
        let names = Set(tools.map(\.name))
        guard names.count == tools.count,
              names.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }),
              Set(disabledTools).count == disabledTools.count,
              Set(disabledTools).isSubset(of: names) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Invalid MCP catalog"))
        }
        configuration = MCPConfiguration(enabled: enabled, disabledTools: disabledTools)
    }
}

@MainActor
protocol FredyMCPSettingsServing {
    func fetchMCPSettings() async throws -> MCPSettingsSnapshot
    func saveMCPSettings(_ configuration: MCPConfiguration) async throws
}

@Observable
@MainActor
final class MCPSettingsModel {
    enum Phase: Equatable { case idle, loading, ready, saving, verified, uncertain, failed, sessionExpired }
    private(set) var snapshot: MCPSettingsSnapshot?
    private(set) var proposal: MCPConfiguration?
    private(set) var phase: Phase = .idle
    private(set) var notice: String?
    private(set) var sessionExpired = false
    private var pending: (desired: MCPConfiguration, baseline: MCPSettingsSnapshot)?
    private var receivedAcknowledgement = false
    private var generation = 0
    @ObservationIgnored private let service: any FredyMCPSettingsServing
    @ObservationIgnored private var task: Task<Void, Never>?

    init(service: any FredyMCPSettingsServing) { self.service = service }
    var busy: Bool { phase == .loading || phase == .saving }
    var canEdit: Bool { !sessionExpired && snapshot != nil && (phase == .ready || phase == .verified) }

    func loadIfNeeded() { if phase == .idle { reload() } }

    func reload() {
        guard !busy, phase != .uncertain, !sessionExpired, task == nil else { return }
        proposal = nil; snapshot = nil; notice = nil
        phase = .loading
        let revision = generation
        task = Task {
            defer { if generation == revision { task = nil } }
            do {
                let fresh = try await service.fetchMCPSettings()
                try check(revision)
                snapshot = fresh; phase = .ready
            } catch { handle(error, mayHaveCommitted: false) }
        }
    }

    func proposeServer(enabled: Bool) {
        guard let configuration = snapshot?.configuration else { return }
        propose(MCPConfiguration(enabled: enabled, disabledTools: configuration.disabledTools))
    }

    func proposeTool(name: String, enabled: Bool) {
        guard let snapshot, snapshot.tools.contains(where: { $0.name == name }) else { return }
        proposeTools(names: [name], enabled: enabled)
    }

    func proposeGroup(readOnly: Bool, enabled: Bool) {
        guard let snapshot else { return }
        proposeTools(names: snapshot.tools.filter { $0.readOnly == readOnly }.map(\.name), enabled: enabled)
    }

    private func proposeTools(names: [String], enabled: Bool) {
        guard let snapshot else { return }
        var disabled = Set(snapshot.configuration.disabledTools)
        if enabled { disabled.subtract(names) } else { disabled.formUnion(names) }
        propose(MCPConfiguration(enabled: snapshot.configuration.enabled, disabledTools: disabled.sorted()))
    }

    private func propose(_ configuration: MCPConfiguration) {
        guard canEdit, proposal == nil, configuration != snapshot?.configuration else { return }
        proposal = configuration
    }

    func cancelProposal() { proposal = nil }

    func confirmChange() {
        guard canEdit, task == nil, let desired = proposal, let baseline = snapshot else { return }
        proposal = nil
        pending = (desired, baseline)
        receivedAcknowledgement = false
        phase = .saving; notice = "جارٍ التحقق من أحدث صلاحيات MCP…"
        let revision = generation
        task = Task {
            var attemptedWrite = false
            defer { if generation == revision { task = nil } }
            do {
                let fresh = try await service.fetchMCPSettings()
                try check(revision)
                guard fresh == baseline else { throw MCPSettingsIssue.conflict }
                attemptedWrite = true
                try await service.saveMCPSettings(desired)
                receivedAcknowledgement = true
                try check(revision)
                let confirmed = try await service.fetchMCPSettings()
                try check(revision)
                guard confirmed.configuration == desired, confirmed.tools == baseline.tools else { throw MCPSettingsIssue.notConfirmed }
                accept(confirmed)
            } catch {
                let rejected = [ListingsFailure.invalidInput, .accessDenied, .conflict, .rateLimited].contains(error as? ListingsFailure ?? .network)
                handle(error, mayHaveCommitted: attemptedWrite && (receivedAcknowledgement || !rejected))
            }
        }
    }

    func reconcile() {
        guard phase == .uncertain, task == nil, !sessionExpired, let pending else { return }
        phase = .saving
        let revision = generation
        task = Task {
            defer { if generation == revision { task = nil } }
            do {
                let confirmed = try await service.fetchMCPSettings()
                try check(revision)
                guard confirmed.configuration == pending.desired, confirmed.tools == pending.baseline.tools else { throw MCPSettingsIssue.notConfirmed }
                accept(confirmed)
            } catch { handle(error, mayHaveCommitted: true) }
        }
    }

    private func accept(_ confirmed: MCPSettingsSnapshot) {
        snapshot = confirmed; pending = nil; phase = .verified
        notice = "تأكد حفظ حالة MCP وصلاحيات الأدوات بقراءة مستقلة من الخادم. لم نغيّر تفويضات OAuth أو نستدعِ أداة."
    }

    private func check(_ revision: Int) throws {
        guard generation == revision, !sessionExpired else { throw CancellationError() }
        try Task.checkCancellation()
    }

    private func handle(_ error: Error, mayHaveCommitted: Bool) {
        guard !sessionExpired else { return }
        if (error as? ListingsFailure) == .sessionExpired { expireSession(); return }
        if mayHaveCommitted {
            phase = .uncertain
            notice = "نتيجة الحفظ غير مؤكدة. قد تكون الصلاحيات تغيّرت؛ استخدم التحقق القرائي فقط. لن نكرر الكتابة أو نعرض نجاحًا."
        } else {
            pending = nil; phase = .failed
            if (error as? MCPSettingsIssue) == .conflict {
                notice = "تغيّرت إعدادات أو قائمة أدوات MCP منذ تحميلها. لم نرسل حفظًا؛ أعد القراءة وراجع الصلاحيات قبل التأكيد."
            } else if (error as? ListingsFailure) == .accessDenied {
                notice = "رفض الخادم صلاحية الوصول أو التعديل؛ قد يمنع وضع العرض التجريبي الحفظ. لم نعرض نجاحًا."
            } else if (error as? ListingsFailure) == .rateLimited {
                notice = "طلبات كثيرة؛ انتظر ثم أعد القراءة يدويًا. لم نكرر أي طلب."
            } else {
                notice = "تعذر قراءة أو تأكيد إعدادات MCP. تحقق من الاتصال وأعد القراءة؛ لا توجد حالة تشغيل أو صلاحيات افتراضية."
            }
        }
    }

    func expireSession() {
        generation += 1; sessionExpired = true
        task?.cancel(); task = nil
        snapshot = nil; proposal = nil; pending = nil; notice = nil
        phase = .sessionExpired
    }
}

private enum MCPSettingsIssue: Error, Equatable { case conflict, notConfirmed }
