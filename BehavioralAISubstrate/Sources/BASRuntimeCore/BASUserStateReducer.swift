// MARK: - BASUserStateReducer — chapter 三百五五 / M842
//
// Phase P1 G2 第二刀: pure-function reducer that folds events into
// the user state vector S_t。
//
// ## What this is (and is NOT)
//
// **This is**:
//   - A typed pure function `reduce(prior: S_{t-1}, event: E_t) -> S_t`
//   - Heuristic formulas (EMA + decay + simple counters) that mirror
//     `BASMemoryTieringProfile` heat composition style
//   - The **swap-target** for the future P2 G8 SSM model — when the
//     SSM is trained,it replaces this file's reduce(...) body, the
//     BASUserState shape stays stable
//
// **This is NOT**:
//   - A learned model. There is no ML in this file. Coefficients
//     are hand-picked + chapter 一百八十五 anti-magic-number named。
//   - A decision-maker. State updates are observation-class
//     (红线 7) — substrate decisions are made by L11 permit gate,
//     not by S_t。
//
// ## Reducer formulas (M842)
//
//   - **emotionalTrend**: EMA over event.emotion ∈ {anxious,
//     calm, ambitious, ...} → [-1, 1] mapping;decay coefficient
//     0.7 (lean recent)
//   - **projectMomentum**: when event.project is non-nil and
//     event.actions contains "permit:answer" / "tool:..." →
//     +0.05;when "skip:..." → -0.05;clamped [-1, 1]
//   - **memoryHeat**: count(event.memoryRefs) > 0 → +0.10;else
//     -0.05;clamped [0, 1]
//   - **riskTrend**: event.riskBand → numeric (low=-0.05,
//     medium=0, high=+0.05),EMA decay 0.85
//   - **complexityAddictionScore**: detect "many events same
//     project, no commit/permit/answer" pattern → +0.10 when
//     pattern matches,decay -0.05 each commit-class event
//   - **agentRouteHistory**: prepend dispatch-policy from
//     event.actions (if present),cap at 3
//   - **lastNEventKinds**: prepend event.kind.rawValue,cap at 10
//
// All coefficients pinned as named constants (chapter 一百八十五)。
//
// ## Doctrine pins held
//
//   - All BASUserState.swift pins apply
//   - 单提交口 (L11/L14) 不变 — reducer is pure,deterministic,
//     no side effects beyond returning new state
//   - chapter 二百一一 single-source-of-truth — ONE reduce(...)
//     entry point;no per-layer reducers

import Foundation

// MARK: - Reducer namespace

/// Pure-function reducer that produces the next user state given
/// the prior state and the next event。
///
/// **Determinism**: same `(prior, event)` pair always produces the
/// same output。Important for replay (G1 BASEventReplayRunner)。
///
/// **Statelessness**: the reducer keeps NO internal state — every
/// call gets fresh prior + event,returns fresh next state。
///
/// **Swap-target invariant**: when P2 G8 SSM ships,it replaces
/// this enum's `reduce(...)` body。The function signature stays
/// stable so all consumers continue working unchanged。
public enum BASUserStateReducer {

    // MARK: - Reducer coefficients (chapter 一百八十五 anti-magic-number)

    /// EMA decay for emotionalTrend (lean recent)。Range (0, 1] —
    /// closer to 1 = slower decay,closer to 0 = faster decay。
    public static let emotionalTrendDecay: Double = 0.7

    /// Project momentum step per advancing event。
    public static let projectMomentumStep: Double = 0.05

    /// Memory heat step when event references memory atoms。
    public static let memoryHeatGainStep: Double = 0.10

    /// Memory heat decay step when event has no memory refs。
    public static let memoryHeatDecayStep: Double = 0.05

    /// EMA decay for riskTrend。
    public static let riskTrendDecay: Double = 0.85

    /// Risk band → numeric step (per-event risk delta)。
    public static let riskStepLow: Double = -0.05
    public static let riskStepMedium: Double = 0.0
    public static let riskStepHigh: Double = 0.05

    /// Complexity addiction step when pattern detected。
    public static let complexityAddictionGainStep: Double = 0.10

    /// Complexity addiction decay step on commit-class events。
    public static let complexityAddictionDecayStep: Double = 0.05

    // MARK: - Reduce

    /// Fold a single event into the prior state to produce the
    /// next state。
    ///
    /// - Parameters:
    ///   - prior: state vector S_{t-1} (use BASUserState.zero for
    ///     S_0)
    ///   - event: event being applied
    ///   - newStateID: caller supplies UUIDv4 for the new state's
    ///     identity (allows deterministic testing)。
    ///   - generatedAtMs: caller supplies wall-clock ms。
    /// - Returns: next state S_t with all clamps applied
    public static func reduce(
        prior: BASUserState,
        event: BASEventLogEntry,
        newStateID: String,
        generatedAtMs: Int64
    ) -> BASUserState {

        // emotionalTrend — EMA over event emotion mapping
        let emotionDelta = mapEmotionToDelta(event.emotion)
        let nextEmotionalTrend =
            prior.emotionalTrend * emotionalTrendDecay
            + emotionDelta * (1.0 - emotionalTrendDecay)

        // projectMomentum — discrete step on tagged events
        let momentumStep = computeMomentumStep(event: event)
        let nextProjectMomentum =
            prior.projectMomentum + momentumStep

        // memoryHeat — gain on memory-touch, decay on miss
        let nextMemoryHeat =
            event.memoryRefs.isEmpty
                ? prior.memoryHeat - memoryHeatDecayStep
                : prior.memoryHeat + memoryHeatGainStep

        // riskTrend — EMA over riskBand mapping
        let riskDelta = mapRiskBandToDelta(event.riskBand)
        let nextRiskTrend =
            prior.riskTrend * riskTrendDecay
            + riskDelta * (1.0 - riskTrendDecay)

        // complexityAddictionScore — pattern-based
        let nextComplexity = computeComplexityAddiction(
            prior: prior, event: event)

        // agentRouteHistory — prepend if action carries dispatch
        var nextRouteHistory = prior.agentRouteHistory
        if let routeAction = event.actions.first(where: {
            $0.hasPrefix("dispatch:")
        }) {
            let route = String(routeAction
                .dropFirst("dispatch:".count))
            nextRouteHistory.insert(route, at: 0)
        }

        // lastNEventKinds — prepend always
        var nextEventKinds = prior.lastNEventKinds
        nextEventKinds.insert(event.kind.rawValue, at: 0)

        return BASUserState(
            stateID: newStateID,
            generatedAtMs: generatedAtMs,
            schemaVersion: BASUserState.currentSchemaVersion,
            emotionalTrend: nextEmotionalTrend,
            projectMomentum: nextProjectMomentum,
            memoryHeat: nextMemoryHeat,
            riskTrend: nextRiskTrend,
            complexityAddictionScore: nextComplexity,
            agentRouteHistory: nextRouteHistory,
            lastNEventKinds: nextEventKinds)
        // BASUserState init applies all clamps + array length caps
    }

    // MARK: - Helper formulas

    /// Map emotion tag → delta in `[-1, 1]`。Mirrors the canonical
    /// tone vocabulary from `BASChengluFeatureEncoder.tones`。
    /// Unknown emotions return 0 (neutral)。
    static func mapEmotionToDelta(_ emotion: String?) -> Double {
        guard let emotion else { return 0 }
        switch emotion.lowercased() {
        // Distress / negative
        case "anxious", "frustrated", "overwhelmed",
             "stressed", "afraid":
            return -0.5
        case "sad", "lonely", "tired":
            return -0.3
        // Neutral / contemplative
        case "thoughtful", "curious", "exploratory":
            return 0.1
        // Calm / positive
        case "calm", "focused", "clear":
            return 0.3
        case "happy", "ambitious", "excited",
             "confident", "satisfied":
            return 0.5
        default:
            return 0
        }
    }

    /// Compute project-momentum delta from event actions + project
    /// presence。
    static func computeMomentumStep(
        event: BASEventLogEntry
    ) -> Double {
        // Only adjust momentum for events that bind to a project
        guard event.project != nil else { return 0 }
        let advancingActions: Set<String> = [
            "permit:answer", "permit:mirror"
        ]
        let stallingActions: Set<String> = [
            "permit:block", "permit:replace", "permit:delay",
            "skip:thermal-pause"
        ]
        var step: Double = 0
        for action in event.actions {
            // Tool calls advance project (substrate engaging)
            if action.hasPrefix("tool:") {
                step += projectMomentumStep
            } else if advancingActions.contains(action) {
                step += projectMomentumStep
            } else if stallingActions.contains(action) {
                step -= projectMomentumStep
            }
        }
        return step
    }

    /// Map risk band → delta in `[-1, 1]` for EMA。
    static func mapRiskBandToDelta(
        _ band: BASEventLogRiskBand
    ) -> Double {
        switch band {
        case .low: return riskStepLow
        case .medium: return riskStepMedium
        case .high: return riskStepHigh
        case .unknown: return 0
        }
    }

    /// Detect the "complexity addiction" pattern: many events on
    /// the same project that are NOT producing commit-class
    /// outputs (no permit:answer / tool:* actions)。User vision
    /// §10 example: "焦虑 → 加技术 → 做不完 → 焦虑"。
    static func computeComplexityAddiction(
        prior: BASUserState,
        event: BASEventLogEntry
    ) -> Double {
        // Commit-class actions decay the score
        let isCommitClass = event.actions.contains {
            $0.hasPrefix("permit:answer")
            || $0.hasPrefix("permit:mirror")
            || $0.hasPrefix("tool:")
        }
        if isCommitClass {
            return prior.complexityAddictionScore
                - complexityAddictionDecayStep
        }
        // Non-commit events on a tagged project add to score
        // Plus the recent kinds being repetitive (chat/voice/file)
        // without committing → increases the loop signal
        if event.project != nil {
            let recentKinds = prior.lastNEventKinds.prefix(5)
            let allInputClass = recentKinds.allSatisfy { kind in
                kind == BASEventLogKind.chat.rawValue
                || kind == BASEventLogKind.voice.rawValue
                || kind == BASEventLogKind.file.rawValue
                || kind == BASEventLogKind.web.rawValue
                || kind == BASEventLogKind.image.rawValue
            }
            if allInputClass && !recentKinds.isEmpty {
                return prior.complexityAddictionScore
                    + complexityAddictionGainStep
            }
        }
        return prior.complexityAddictionScore
    }
}
