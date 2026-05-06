// MARK: - BASLayerKillSwitchID — chapter 三百〇一 / M788
//
// Phase Beta 第三刀 (final foundation cut): per-layer kill switch
// 14-case enum + typed kill switch state + per-layer error
// boundary report。完成 Phase Beta foundation;Phase Gamma
// (chapter 三百〇二+) 开始 wire OPT-IN → PROD。
//
// ## 这一刀 ship 什么
//
// 4 个 typed primitives:
//
//   - `BASLayerKillSwitchID` (14 case enum: l1Wake / l2NeuralOrgan /
//     l3FoldedLung / l4Horizon / l5HostConstitution / l6Situation /
//     l7MirrorBlade / l8Memory / l9Dream / l10Tribunal / l11Risk /
//     l12SoftHand / l13Evolution / l14Sovereign) — per-layer kill
//     switch identifiers
//   - `BASLayerKillSwitchState` (BASSchemaVersioned 1.0.0) — typed
//     state record: switchID / active / reason / activatedAt /
//     activatedBy
//   - `BASLayerKillSwitchReason` (8-case enum) — typed reason: manual /
//     thermalEmergency / sovereignVerdict / budgetCascade /
//     observabilityHalt / quarantineEscalation / errorBoundaryTrip /
//     dependencyMissing
//   - `BASLayerErrorBoundaryReport` (BASSchemaVersioned 1.0.0) —
//     per-call error boundary report: layerID / errorKind /
//     gracefulSkipApplied / fallthroughStrategy / capturedAt
//
// ## Why now
//
// Phase Alpha file split 让每 layer 独立 file;Phase Beta foundation
// (chapters 二百九十九-三百〇一) 提供 typed contract;chapter 三百
// shipped slice + ML head;chapter 三百〇一 (本刀) ships kill switch
// + error boundary 完成 protocol contract trio。Phase Gamma 起的
// OPT-IN→PROD wire-up 即可使用这套 typed primitives。
//
// **0 behavior change**:purely additive new file。无现有 runtime
// path 变更。
//
// ## Doctrine pins held
//
//   - 不变量 #1 / #2 / #3 全保 — kill switch 不影响 wake / weight /
//     audit path,只是 typed observability + control plane
//   - 红线 7 watcher hint only:kill switch 是 control plane,
//     不直接 issue verdict;`activatedBy` field 只是 metadata
//   - 单提交口 (L11/L14) 不变 — kill switch 只 declare layer
//     unavailable,不替换 verdict authority
//   - chapter 二百一一 single-source-of-truth: 14-case enum 集中
//     管理 (vs scattered per-layer constants)
//   - chapter 一百八十五 anti-magic-number: 14 cases + 8 reasons,
//     全 typed
//   - chapter 一百三 schema-version: 1.0.0 invariants
//   - chapter 一百三十 BR-014 sovereign-domain-scope: kill switch
//     reason `sovereignVerdict` is the ONLY case that requires L14
//     warrant; other cases are observability-class
//   - chapter 二百九十九 BASLayerActorError: error boundary report
//     can be derived from caught BASLayerActorError instances

import Foundation

// MARK: - 14-case kill switch enum

/// L1-L14 per-layer kill switch identifiers。每 layer 一 case;
/// raw value 是 kebab-case 稳定 string,匹配 audit code prefix。
///
/// ## Doctrine note
///
/// chapter 二百九十九 plan extended `BASLayerKillSwitchID from 3 → 14
/// cases`. 14 case 一一对应 BASMotherboardLayer14。Layer-level
/// granularity allows L14 sovereign to fire targeted layer halts
/// (e.g. quarantine just L9 dream loop while L1 wake stays alive).
public enum BASLayerKillSwitchID:
    String,
    Sendable,
    Equatable,
    Hashable,
    Codable,
    CaseIterable
{
    case l1Wake = "l1-wake"
    case l2NeuralOrgan = "l2-neural-organ"
    case l3FoldedLung = "l3-folded-lung"
    case l4Horizon = "l4-horizon"
    case l5HostConstitution = "l5-host-constitution"
    case l6Situation = "l6-situation"
    case l7MirrorBlade = "l7-mirror-blade"
    case l8Memory = "l8-memory"
    case l9Dream = "l9-dream"
    case l10Tribunal = "l10-tribunal"
    case l11Risk = "l11-risk"
    case l12SoftHand = "l12-soft-hand"
    case l13Evolution = "l13-evolution"
    case l14Sovereign = "l14-sovereign"

    /// Map kill switch ID back to its corresponding
    /// `BASMotherboardLayer14` case。1:1 mapping doctrine pin.
    public var motherboardLayer: BASMotherboardLayer14 {
        switch self {
        case .l1Wake: return .l1
        case .l2NeuralOrgan: return .l2
        case .l3FoldedLung: return .l3
        case .l4Horizon: return .l4
        case .l5HostConstitution: return .l5
        case .l6Situation: return .l6
        case .l7MirrorBlade: return .l7
        case .l8Memory: return .l8
        case .l9Dream: return .l9
        case .l10Tribunal: return .l10
        case .l11Risk: return .l11
        case .l12SoftHand: return .l12
        case .l13Evolution: return .l13
        case .l14Sovereign: return .l14
        }
    }

    /// Inverse mapping: `BASMotherboardLayer14` → kill switch ID。
    /// Used by error-boundary reporters when they have a layer
    /// reference but need a kill switch ID for audit trail.
    public static func forLayer(
        _ layer: BASMotherboardLayer14
    ) -> BASLayerKillSwitchID {
        switch layer {
        case .l1: return .l1Wake
        case .l2: return .l2NeuralOrgan
        case .l3: return .l3FoldedLung
        case .l4: return .l4Horizon
        case .l5: return .l5HostConstitution
        case .l6: return .l6Situation
        case .l7: return .l7MirrorBlade
        case .l8: return .l8Memory
        case .l9: return .l9Dream
        case .l10: return .l10Tribunal
        case .l11: return .l11Risk
        case .l12: return .l12SoftHand
        case .l13: return .l13Evolution
        case .l14: return .l14Sovereign
        }
    }
}

// MARK: - Kill switch reason taxonomy

/// 8-case typed reason for why a kill switch is active。
///
/// ## Doctrine note
///
/// `sovereignVerdict` 是唯一需要 L14 warrant 的 reason (BR-014
/// chapter 一百三十 sovereign-domain-scope);其他 reasons 是
/// observability-class — 可由 thermal twin / kernel monitor /
/// budget enforcer 自动 trigger。
public enum BASLayerKillSwitchReason:
    String,
    Sendable,
    Equatable,
    Hashable,
    Codable,
    CaseIterable
{
    case manual
    case thermalEmergency = "thermal-emergency"
    case sovereignVerdict = "sovereign-verdict"
    case budgetCascade = "budget-cascade"
    case observabilityHalt = "observability-halt"
    case quarantineEscalation = "quarantine-escalation"
    case errorBoundaryTrip = "error-boundary-trip"
    case dependencyMissing = "dependency-missing"
}

// MARK: - Kill switch state record

/// Typed state record for an individual kill switch。每 turn
/// coordinator 维护一个 `[BASLayerKillSwitchID: BASLayerKillSwitchState]` map;
/// `BASLayerActor.process` 调用前查 map,active state → 直接抛
/// `BASLayerActorError.killSwitchActive` 走 error-boundary
/// graceful skip。
public struct BASLayerKillSwitchState:
    BASSchemaVersioned, Sendable
{
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var switchID: BASLayerKillSwitchID
    public var active: Bool
    public var reason: BASLayerKillSwitchReason
    public var detail: String
    public var activatedAt: Date?
    public var activatedBy: String?

    public init(
        schemaVersion: String
            = BASLayerKillSwitchState.currentSchemaVersion,
        switchID: BASLayerKillSwitchID,
        active: Bool,
        reason: BASLayerKillSwitchReason = .manual,
        detail: String = "",
        activatedAt: Date? = nil,
        activatedBy: String? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.switchID = switchID
        self.active = active
        self.reason = reason
        self.detail = detail
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.activatedAt = activatedAt
        self.activatedBy = activatedBy?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Error boundary fall-through strategies

/// 5-case typed strategy for what to do when `BASLayerActor.process`
/// throws a `BASLayerActorError`。Coordinator looks at the captured
/// error + applies one of these strategies。
public enum BASLayerErrorFallthroughStrategy:
    String,
    Sendable,
    Equatable,
    Hashable,
    Codable,
    CaseIterable
{
    /// Continue turn without this layer's output (default for
    /// observability-class layers). Audit emits status =
    /// `errorBoundaryHandled`.
    case gracefulSkip = "graceful-skip"

    /// Use cached/last-known output for this layer (e.g. host
    /// constitution stays at last-known when L5 actor errors).
    case useLastKnown = "use-last-known"

    /// Cascade to ML head fallthrough (chapter 三百一三+);only
    /// valid when actor has `mlHeadSlot` configured.
    case mlHeadFallthrough = "ml-head-fallthrough"

    /// Abort whole turn (only L1 wake / L11 permit / L14 verdict
    /// errors should ever reach this — L1 wake failure means
    /// 不变量 #1 violation which is unrecoverable).
    case abortTurn = "abort-turn"

    /// Escalate to sovereign quarantine (L14 path);used when
    /// error indicates contamination / privilege violation.
    case sovereignEscalate = "sovereign-escalate"
}

// MARK: - Error boundary report

/// Per-call error-boundary report。Coordinator 每次 catch
/// `BASLayerActorError` 时构造一个;feeds audit ledger via
/// reasonCodes。
public struct BASLayerErrorBoundaryReport:
    BASSchemaVersioned, Sendable
{
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var layerID: BASMotherboardLayer14
    public var errorKind: String
    public var detail: String
    public var fallthroughStrategy: BASLayerErrorFallthroughStrategy
    public var gracefulSkipApplied: Bool
    public var capturedAt: Date

    public init(
        schemaVersion: String
            = BASLayerErrorBoundaryReport.currentSchemaVersion,
        layerID: BASMotherboardLayer14,
        errorKind: String,
        detail: String = "",
        fallthroughStrategy: BASLayerErrorFallthroughStrategy
            = .gracefulSkip,
        gracefulSkipApplied: Bool = true,
        capturedAt: Date
    ) {
        self.schemaVersion = schemaVersion
        self.layerID = layerID
        self.errorKind = errorKind
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.detail = detail
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.fallthroughStrategy = fallthroughStrategy
        self.gracefulSkipApplied = gracefulSkipApplied
        self.capturedAt = capturedAt
    }
}

public extension BASLayerErrorBoundaryReport {
    /// Convenience builder — derive a typed report from a thrown
    /// `BASLayerActorError`。Default strategy is `.gracefulSkip`
    /// for budget/dependency/internalFailure cases;
    /// `.sovereignEscalate` for `quarantine`;
    /// `.abortTurn` for L1 wake errors (不变量 #1 enforcement).
    static func from(
        error: BASLayerActorError,
        capturedAt: Date
    ) -> BASLayerErrorBoundaryReport {
        let layerID = layerID(of: error)
        let errorKind = errorKindString(error)
        let detail = errorDetailString(error)
        let strategy = defaultStrategy(
            for: error, layerID: layerID)
        return BASLayerErrorBoundaryReport(
            layerID: layerID,
            errorKind: errorKind,
            detail: detail,
            fallthroughStrategy: strategy,
            gracefulSkipApplied: strategy == .gracefulSkip,
            capturedAt: capturedAt)
    }

    private static func layerID(
        of error: BASLayerActorError
    ) -> BASMotherboardLayer14 {
        switch error {
        case .budgetExceeded(let id, _),
             .killSwitchActive(let id, _),
             .dependencyMissing(let id, _),
             .quarantine(let id, _),
             .internalFailure(let id, _):
            return id
        }
    }

    private static func errorKindString(
        _ error: BASLayerActorError
    ) -> String {
        switch error {
        case .budgetExceeded: return "budget-exceeded"
        case .killSwitchActive: return "kill-switch-active"
        case .dependencyMissing: return "dependency-missing"
        case .quarantine: return "quarantine"
        case .internalFailure: return "internal-failure"
        }
    }

    private static func errorDetailString(
        _ error: BASLayerActorError
    ) -> String {
        switch error {
        case .budgetExceeded(_, let allowedMs):
            return "allowed-ms:\(allowedMs)"
        case .killSwitchActive(_, let reason):
            return reason
        case .dependencyMissing(_, let missingRef):
            return missingRef
        case .quarantine(_, let reason):
            return reason
        case .internalFailure(_, let message):
            return message
        }
    }

    private static func defaultStrategy(
        for error: BASLayerActorError,
        layerID: BASMotherboardLayer14
    ) -> BASLayerErrorFallthroughStrategy {
        // L1 wake error must abort turn (不变量 #1)
        if layerID == .l1 { return .abortTurn }
        // L11 permit / L14 sovereign error must escalate
        // (single-commit-mouth doctrine)
        if layerID == .l11 || layerID == .l14 {
            return .sovereignEscalate
        }
        // Quarantine error always escalates
        if case .quarantine = error {
            return .sovereignEscalate
        }
        // All other cases default to graceful skip
        return .gracefulSkip
    }
}
