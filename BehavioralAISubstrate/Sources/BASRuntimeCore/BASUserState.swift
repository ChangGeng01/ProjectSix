// MARK: - BASUserState — chapter 三百五五 / M842
//
// Phase P1 G2 第一刀: typed user state vector S_t。Closes G2 from
// chapter 三百五三 / M840 Chenglu Cognitive OS roadmap。
//
// ## Why this exists
//
// Per the user's vision §3.3:
//
// > Mamba 不应该负责最终聊天。它最强的位置是:处理连续状态、长期
// > 趋势、事件流、记忆热度、风险变化。
// > 最终它输出的不是自然语言,而是 state_vector / risk_trend /
// > memory_heat / wake_score / retrieval_depth / reasoning_depth /
// > response_mode / model_route。
//
// G2 ships the **typed shape** of that state vector + a **hand-coded
// reducer** as the swap-target for the future SSM model (G8 / P2)。
// The reducer is intentionally lightweight — heuristic formulas
// mirroring `BASMemoryTieringProfile` heat composition — so the
// substrate has continuous-state observability today,without
// blocking on SSM training (which needs the event log corpus from
// G1 first)。
//
// ## What this file ships (M842 第一刀 of three)
//
//   - `BASUserState` Codable Sendable struct with 8 typed fields:
//     emotionalTrend / projectMomentum / memoryHeat / riskTrend /
//     complexityAddictionScore / agentRouteHistory /
//     lastNEventKinds / generatedAt / stateID
//   - `BASUserStateInit` factory for the zero state S_0
//   - Convenience accessors and clamp invariants
//
// Reducer + Store ship in companion files:
//   - `BASUserStateReducer.swift` — pure-function fold
//   - `BASMemory/BASUserStateStore.swift` — persistence + history
//
// ## Doctrine pins held
//
//   - 不变量 #1 / #2 / #3 全保 — state vector is OBSERVATION ONLY,
//     does NOT mutate L11 permit gate
//   - 红线 7 hint-only — every layer reads S_t as a hint;substrate
//     decisions made by L11 permit unchanged
//   - 单提交口 (L11/L14) 不变 — state reducer is config plane,
//     never the commit gate
//   - chapter 二百一一 single-source-of-truth — ONE typed state
//     shape across all layers + ONE reducer
//   - chapter 一百八十五 anti-magic-number — all clamp boundaries +
//     decay coefficients are named typed constants
//   - ADR-014 OPT-IN → PROD — state vector starts as
//     observation-only,does NOT replace existing decision paths
//   - **Critical pin**: when G8 SSM lands in P2,it replaces the
//     hand-coded reducer in `BASUserStateReducer.swift` ONLY。The
//     `BASUserState` shape stays stable so all layer consumers
//     remain unchanged。This is the swap-target architecture。

import Foundation

// MARK: - User state (S_t)

/// Typed continuous-state user vector。Updated per event by the
/// reducer (`BASUserStateReducer`)。Persisted per turn by
/// `BASUserStateStore`。Read by all 14 layers as hint material。
///
/// **Lifecycle**:
///
///   S_0 (zero state, fresh user) →
///   reducer(S_{t-1}, event_t) →
///   S_t (persisted, available to next turn) →
///   ...
///
/// **Stability invariant**: this struct's shape is DELIBERATELY
/// kept stable across reducer evolutions。M842 hand-coded reducer
/// + future P2 G8 SSM reducer + future research reducers all
/// produce / consume the SAME `BASUserState`。Adding fields requires
/// schema-version bump + Codable migration shim。
public struct BASUserState: Codable, Equatable, Sendable {

    // MARK: - Identity

    /// Stable UUIDv4 — unique per state snapshot。Used by event log
    /// `stateBeforeID` / `stateAfterID` cross-references (G1)。
    public let stateID: String

    /// Wall-clock millis at which this state was generated。
    public let generatedAtMs: Int64

    /// Schema version pin — bumped on shape changes for migration
    /// detection。
    public let schemaVersion: String

    // MARK: - Continuous tendencies (clamped [-1, 1] or [0, 1])

    /// Emotional trend score:`[-1, 1]`,negative = trending toward
    /// distress, positive = trending toward calm/positive。Reducer
    /// updates via exponential moving average over recent emotion
    /// tags (chapter 一百八十五 anti-magic-number — coefficient
    /// pinned in reducer)。
    public let emotionalTrend: Double

    /// Project momentum:`[-1, 1]`,negative = stalling/regressing,
    /// positive = advancing。Computed from event actions associated
    /// with project tags (eg. "permit:answer" on project events
    /// adds momentum;"skip:thermal-pause" subtracts)。
    public let projectMomentum: Double

    /// Memory heat:`[0, 1]`,how often memory atoms are being
    /// touched。Mirrors `BASMemoryTieringProfile.recencyScore`
    /// composition pattern。
    public let memoryHeat: Double

    /// Risk trend:`[-1, 1]`,negative = risk descending,positive =
    /// risk ascending。Computed from event riskBand transitions
    /// over the last N events。
    public let riskTrend: Double

    /// Complexity addiction score:`[0, 1]`,detector for the
    /// pattern "user adds technology / scope / sub-questions
    /// without converging on output"。User vision §10 example:
    /// "焦虑 → 加技术 → 做不完 → 焦虑" loop。
    public let complexityAddictionScore: Double

    // MARK: - Categorical / discrete state

    /// Last 3 agent routes (most recent first)。Used by L2 model
    /// router to detect routing thrashing。Strings match
    /// `dispatchPolicy.rawValue` (eg. "single-llm", "local-only",
    /// "skip-block")。Bounded to length 3 by reducer (chapter 一百
    /// 八十五 anti-magic-number — max length pinned)。
    public let agentRouteHistory: [String]

    /// Last N event kinds (most recent first)。Bounded to length
    /// 10 by reducer。Used by L1 wake gate to detect
    /// repetitive-input patterns。
    public let lastNEventKinds: [String]

    // MARK: - Doctrine constants

    public static let currentSchemaVersion: String = "1.0.0"

    /// Default zero-state ("fresh user") factory。
    public static let zero: BASUserState = .init(
        stateID: "00000000-0000-0000-0000-000000000000",
        generatedAtMs: 0,
        schemaVersion: BASUserState.currentSchemaVersion,
        emotionalTrend: 0,
        projectMomentum: 0,
        memoryHeat: 0,
        riskTrend: 0,
        complexityAddictionScore: 0,
        agentRouteHistory: [],
        lastNEventKinds: [])

    /// Maximum length of `agentRouteHistory` (chapter 一百八十五
    /// anti-magic-number)。Reducer truncates to this。
    public static let agentRouteHistoryCap: Int = 3

    /// Maximum length of `lastNEventKinds` (chapter 一百八十五)。
    public static let lastNEventKindsCap: Int = 10

    // MARK: - Init with clamp invariants

    public init(
        stateID: String,
        generatedAtMs: Int64,
        schemaVersion: String =
            BASUserState.currentSchemaVersion,
        emotionalTrend: Double,
        projectMomentum: Double,
        memoryHeat: Double,
        riskTrend: Double,
        complexityAddictionScore: Double,
        agentRouteHistory: [String],
        lastNEventKinds: [String]
    ) {
        self.stateID = stateID
        self.generatedAtMs = generatedAtMs
        self.schemaVersion = schemaVersion
        // Clamp signed tendencies to [-1, 1]
        self.emotionalTrend = max(-1, min(1, emotionalTrend))
        self.projectMomentum = max(-1, min(1, projectMomentum))
        self.riskTrend = max(-1, min(1, riskTrend))
        // Clamp unsigned scores to [0, 1]
        self.memoryHeat = max(0, min(1, memoryHeat))
        self.complexityAddictionScore = max(
            0, min(1, complexityAddictionScore))
        // Bound array lengths
        self.agentRouteHistory = Array(
            agentRouteHistory.prefix(
                Self.agentRouteHistoryCap))
        self.lastNEventKinds = Array(
            lastNEventKinds.prefix(
                Self.lastNEventKindsCap))
    }

    // MARK: - Convenience

    /// Is this state the zero state (fresh user, no events ever
    /// reduced)?
    public var isZero: Bool {
        self == Self.zero
    }

    /// True if `complexityAddictionScore` exceeds the typed
    /// caution threshold。Chapter 一百八十五 anti-magic-number —
    /// threshold pinned here, not duplicated at consumer sites。
    public var isComplexityAddictionElevated: Bool {
        complexityAddictionScore >= Self.complexityAddictionThreshold
    }

    public static let complexityAddictionThreshold: Double = 0.6

    /// True if `riskTrend` is sustained-positive。L11 risk gate
    /// reads this as input hint (does NOT decide on it alone)。
    public var isRiskTrendingUp: Bool {
        riskTrend >= Self.riskTrendUpThreshold
    }

    public static let riskTrendUpThreshold: Double = 0.3

    /// True if `projectMomentum` is sustained-negative。L7 planner
    /// reads this as input hint。
    public var isProjectStalling: Bool {
        projectMomentum <= -Self.projectStallingThreshold
    }

    public static let projectStallingThreshold: Double = 0.3
}
