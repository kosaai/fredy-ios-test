import Foundation
import Observation

/// Metadata only. This API does not expose bearer credentials or all historical authorizations.
struct OAuthConnection: Decodable, Equatable, Identifiable, Sendable {
    let clientId: String
    let clientName: String?
    let grantedAt: Int64
    let scopes: [String]
    var id: String { clientId }
    var displayName: String {
        guard let clientName, !clientName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return clientId }
        return clientName
    }
    var grantedDate: Date { Date(timeIntervalSince1970: Double(grantedAt) / 1000) }
    private enum CodingKeys: String, CodingKey { case clientId, clientName, grantedAt, scopes }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        clientId = try values.decode(String.self, forKey: .clientId)
        clientName = try values.decode(String?.self, forKey: .clientName)
        grantedAt = try values.decode(Int64.self, forKey: .grantedAt)
        scopes = try values.decode([String].self, forKey: .scopes)
        guard Self.isValidClientID(clientId), grantedAt >= 0, grantedAt <= 253_402_300_799_999,
              Set(scopes).count == scopes.count,
              scopes.allSatisfy({ !$0.isEmpty && !$0.contains(where: { $0.isWhitespace || $0.isNewline }) }) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Invalid OAuth grant metadata"))
        }
    }

    /// Installed v31 creates a 32-character nanoid; never normalize or interpolate an unvalidated ID.
    static func isValidClientID(_ value: String) -> Bool {
        value.utf8.count == 32 && value.utf8.allSatisfy {
            (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) || $0 == 45 || $0 == 95
        }
    }
}

@MainActor
protocol FredyOAuthConnectionsServing {
    func fetchOAuthConnections() async throws -> [OAuthConnection]
    func revokeOAuthConnection(clientID: String) async throws
}

@Observable
@MainActor
final class OAuthConnectionsModel {
    enum Phase: Equatable { case idle, loading, ready, revoking, verified, uncertain, failed, sessionExpired }
    private(set) var connections: [OAuthConnection]?
    private(set) var proposal: OAuthConnection?
    private(set) var phase: Phase = .idle
    private(set) var notice: String?
    private(set) var sessionExpired = false
    private var pending: OAuthConnection?
    private var receivedAcknowledgement = false
    private var generation = 0
    @ObservationIgnored private let service: any FredyOAuthConnectionsServing
    @ObservationIgnored private var task: Task<Void, Never>?

    init(service: any FredyOAuthConnectionsServing) { self.service = service }
    var busy: Bool { phase == .loading || phase == .revoking }
    var canRevoke: Bool { !sessionExpired && connections != nil && (phase == .ready || phase == .verified) }

    func reload() {
        guard !busy, phase != .uncertain, !sessionExpired, task == nil else { return }
        connections = nil; proposal = nil; notice = nil
        phase = .loading
        let revision = generation
        task = Task {
            defer { if generation == revision { task = nil } }
            do {
                let fresh = try await service.fetchOAuthConnections()
                try check(revision)
                connections = fresh; phase = .ready
            } catch { handle(error, mayHaveCommitted: false) }
        }
    }

    func proposeRevoke(_ target: OAuthConnection) {
        guard canRevoke, proposal == nil, connections?.contains(target) == true else { return }
        proposal = target
    }

    func cancelProposal() { proposal = nil }

    func confirmRevocation() {
        guard canRevoke, task == nil, let target = proposal else { return }
        proposal = nil; pending = target; receivedAcknowledgement = false
        phase = .revoking; notice = "جارٍ التحقق من أحدث تفويض قبل الإلغاء…"
        let revision = generation
        task = Task {
            var attemptedWrite = false
            defer { if generation == revision { task = nil } }
            do {
                let fresh = try await service.fetchOAuthConnections()
                try check(revision)
                guard fresh.first(where: { $0.clientId == target.clientId }) == target else { throw OAuthConnectionsIssue.changed }
                attemptedWrite = true
                try await service.revokeOAuthConnection(clientID: target.clientId)
                receivedAcknowledgement = true
                try check(revision)
                let confirmed = try await service.fetchOAuthConnections()
                try check(revision)
                try acceptAbsence(confirmed, target: target)
            } catch {
                let rejected = [ListingsFailure.invalidInput, .accessDenied, .conflict, .rateLimited].contains(error as? ListingsFailure ?? .network)
                handle(error, mayHaveCommitted: attemptedWrite && (receivedAcknowledgement || !rejected))
            }
        }
    }

    func reconcile() {
        guard phase == .uncertain, task == nil, !sessionExpired, let target = pending else { return }
        phase = .revoking
        let revision = generation
        task = Task {
            defer { if generation == revision { task = nil } }
            do {
                let fresh = try await service.fetchOAuthConnections()
                try check(revision)
                try acceptAbsence(fresh, target: target)
            } catch { handle(error, mayHaveCommitted: true) }
        }
    }

    private func acceptAbsence(_ fresh: [OAuthConnection], target: OAuthConnection) throws {
        guard !fresh.contains(where: { $0.clientId == target.clientId }) else { throw OAuthConnectionsIssue.notConfirmed }
        connections = fresh; pending = nil; phase = .verified
        notice = receivedAcknowledgement
            ? "أكدت قراءة مستقلة بعد طلب الإلغاء أن الاتصال لم يعد ضمن التفويضات السارية. هذه حالة آخر قراءة، وليست ضمانًا ضد تفويض جديد."
            : "لم يعد الاتصال ضمن التفويضات السارية بحسب قراءة مستقلة. لم يتأكد رد الإلغاء؛ لا يمكن الجزم بسبب غيابه."
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
            notice = "نتيجة الإلغاء غير مؤكدة. قد يكون الوصول تغيّر؛ تحقق بالقراءة فقط. لن نكرر الإلغاء أو نعرض نجاحًا غير مثبت."
        } else {
            pending = nil; phase = .failed
            if (error as? OAuthConnectionsIssue) == .changed {
                notice = "تغيّر التفويض أو لم يعد ظاهرًا منذ تحميله. لم نرسل إلغاءً؛ أعد القراءة وراجع الاتصال قبل تأكيد جديد."
            } else if (error as? ListingsFailure) == .accessDenied {
                notice = "رفض الخادم صلاحية الوصول أو الإلغاء. أعد القراءة بعد مراجعة صلاحيات حسابك؛ لم نعرض نجاحًا."
            } else if (error as? ListingsFailure) == .rateLimited {
                notice = "طلبات كثيرة؛ انتظر وأعد القراءة يدويًا. لم نكرر الإلغاء."
            } else {
                notice = "تعذر تحميل اتصالات OAuth أو تأكيد حالتها. لا نفترض خلو الحساب أو صلاحيات اتصال؛ أعد القراءة يدويًا."
            }
        }
    }

    func expireSession() {
        generation += 1; sessionExpired = true
        task?.cancel(); task = nil
        connections = nil; proposal = nil; pending = nil; notice = nil
        phase = .sessionExpired
    }
}

private enum OAuthConnectionsIssue: Error, Equatable { case changed, notConfirmed }
