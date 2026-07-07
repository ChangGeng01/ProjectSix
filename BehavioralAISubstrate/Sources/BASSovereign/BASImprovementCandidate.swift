import Foundation

// P2 改进候选一等对象(RSI 章程 2026-07-07)——让采纳事件在基座内【可表示、可审计】。
// 宪法界:明确【不可执行】——采纳 = 人改代码极性 + git commit(ADR-014),本类型只把那个
// 人类介质里的事件表示成对象并留收据;任何机器环拿到这个类型也拿不到采纳权。
// FSM 样式复用 BASUpdateTicketLifecycle(状态 + 迁移历史 + 非法迁移抛错)。

/// What kind of thing a candidate proposes to change. 权重轴故意不存在(不建清单#6)。
public enum BASImprovementKind: String, Codable, Sendable, CaseIterable {
    case constant   // 数值常数(cacheLimit/阈值/预算)
    case route      // 车道/路由策略极性
    case prompt     // 系统提示/persona 散文
    case skill      // 技能/playbook 条目
}

public enum BASImprovementState: String, Codable, Sendable, CaseIterable {
    case proposed        // 候选已表示(证据可以为空)
    case shadowTesting   // 影子测量中(预注册判据已冻结)
    case certified       // 判据过门(判决候选 = PASS;仍未采纳)
    case adopted         // 人签采纳(operatorSignature 必填;收据入账本)
    case rejected        // 人签拒绝 或 判据失败
    case rolledBack      // 采纳后回滚(rollbackAnchor 必填)
}

public struct BASImprovementTransition: Codable, Sendable, Equatable {
    public let from: BASImprovementState
    public let to: BASImprovementState
    public let atMs: Int64
    public let reasonCodes: [String]
    public init(from: BASImprovementState, to: BASImprovementState,
                atMs: Int64, reasonCodes: [String] = []) {
        self.from = from
        self.to = to
        self.atMs = atMs
        self.reasonCodes = reasonCodes
    }
}

/// The first-class improvement candidate. IMMUTABLE (coding-style rule): every transition
/// returns a NEW candidate with the history appended.
public struct BASImprovementCandidate: Codable, Sendable, Equatable {

    public enum LifecycleError: Error, Equatable {
        case illegalTransition(from: BASImprovementState, to: BASImprovementState)
        case missingOperatorSignature   // adopted 必须人签
        case missingRollbackAnchor      // adopted/rolledBack 必须可回滚
    }

    public let id: String
    public let kind: BASImprovementKind
    /// 现值出处(file:line / ADR ref)——候选改的是【哪里的什么】。
    public let currentValueProvenance: String
    public let currentValue: String
    public let proposedValue: String
    /// 预注册判据 ref(P1 BASABProtocolSpec 的序列化/账本路径)——测量前冻结的证明。
    public let preRegisteredCriteriaRef: String
    /// 证据 refs(账本段落/日志路径/报告 JSON)。
    public var evidenceRefs: [String]
    /// 回滚锚(旧值文件/commit hash/快照路径)——adopted 前必填。
    public var rollbackAnchor: String?
    /// 人签(操作员标识 + 时刻)——采纳权的唯一载体,机器永远填不了自己的名字。
    public var operatorSignature: String?
    public private(set) var state: BASImprovementState
    public private(set) var history: [BASImprovementTransition]

    public init(id: String, kind: BASImprovementKind, currentValueProvenance: String,
                currentValue: String, proposedValue: String, preRegisteredCriteriaRef: String,
                evidenceRefs: [String] = []) {
        self.id = id
        self.kind = kind
        self.currentValueProvenance = currentValueProvenance
        self.currentValue = currentValue
        self.proposedValue = proposedValue
        self.preRegisteredCriteriaRef = preRegisteredCriteriaRef
        self.evidenceRefs = evidenceRefs
        self.rollbackAnchor = nil
        self.operatorSignature = nil
        self.state = .proposed
        self.history = []
    }

    /// The legal FSM: proposed→shadow→certified→adopted→rolledBack; rejected 从任何
    /// 未采纳态可达(人可随时否决);其余非法。
    static let legalTransitions: [BASImprovementState: Set<BASImprovementState>] = [
        .proposed: [.shadowTesting, .rejected],
        .shadowTesting: [.certified, .rejected],
        .certified: [.adopted, .rejected],
        .adopted: [.rolledBack],
        .rejected: [],
        .rolledBack: [],
    ]

    /// Pure transition — returns a NEW candidate; throws on illegal moves or missing
    /// adoption prerequisites (signature + rollback anchor).
    public func transitioned(
        to next: BASImprovementState, atMs: Int64, reasonCodes: [String] = [],
        operatorSignature: String? = nil
    ) throws -> BASImprovementCandidate {
        guard Self.legalTransitions[state]?.contains(next) == true else {
            throw LifecycleError.illegalTransition(from: state, to: next)
        }
        var copy = self
        if next == .adopted {
            guard let sig = operatorSignature ?? copy.operatorSignature, !sig.isEmpty else {
                throw LifecycleError.missingOperatorSignature
            }
            guard copy.rollbackAnchor != nil else {
                throw LifecycleError.missingRollbackAnchor
            }
            copy.operatorSignature = sig
        }
        copy.state = next
        copy.history = history + [BASImprovementTransition(
            from: state, to: next, atMs: atMs, reasonCodes: reasonCodes)]
        return copy
    }

    /// The adoption receipt line — append-only ledger material (git hash of the polarity
    /// change + the candidate). Human-readable by design (可解释性章程:裁决可读性同权重)。
    public func receiptLine(gitHash: String) -> String {
        "📜 improvement id=\(id) kind=\(kind.rawValue) state=\(state.rawValue) "
            + "\(currentValue)→\(proposedValue) @\(currentValueProvenance) "
            + "criteria=\(preRegisteredCriteriaRef) git=\(gitHash) "
            + "sig=\(operatorSignature ?? "UNSIGNED")"
    }
}
