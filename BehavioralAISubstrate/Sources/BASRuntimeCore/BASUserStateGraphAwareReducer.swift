// MARK: - BASUserStateGraphAwareReducer — chapter 三百七一 / M858
//
// Composes:
//   - M842 (chapter 三百五五) `BASUserStateReducer` — base
//     hand-coded reducer
//   - M856 (chapter 三百六九) `BASKnowledgeGraph` — typed cycle
//     detection
//   - M857 (chapter 三百七十) graph extractor — auto-populates
//     graph from event log
//
// Closes the user-vision §10 "complexity addiction loop"
// detection feedback loop:
//
//   event → graph extractor (M857) → graph populated (M856)
//     → cycle detection finds delays-cycle on this event's
//        project
//     → reducer (M842) base output bumped on
//        complexityAddictionScore
//     → user state reflects cycle-presence as elevated score
//     → L9 / L10 / L14 actors consume score as hint
//
// ## Why a separate file (not modify M842 reducer)
//
// chapter 二百一一 single-source-of-truth doctrine:the M842
// reducer stays pure (no graph dependency)。This file ships the
// COMPOSED reducer that adds graph-awareness as an opt-in
// extension。Hosts that don't need cycle-aware state updates
// keep using `BASUserStateReducer.reduce(...)` unchanged。
//
// ## Doctrine pins held
//
//   - All M842 + M856 + M857 pins apply
//   - 不变量 #1 / #2 / #3 全保 — composer is pure orchestration,
//     no permit/verdict mutation
//   - 红线 7 hint-only — adjusted state vector is observation/
//     hint material;substrate decisions still made by L11
//   - 单提交口 (L11/L14) 不变 — composer feeds gate as INPUT
//   - chapter 二百一一 single-source-of-truth — base M842
//     reducer remains the canonical fold;this file COMPOSES,
//     doesn't duplicate
//   - chapter 一百八十五 anti-magic-number — cycle-bonus step
//     + multi-cycle scaling cap named typed constants
//   - ADR-014 OPT-IN → PROD — hosts that don't pass a graph
//     keep base reducer behavior (zero behavior change)

import Foundation

// MARK: - Composed reducer namespace

/// Async composer: runs M842 base reducer,then queries the
/// M856 graph for delays-cycles involving the event's project,
/// adjusts the resulting state's `complexityAddictionScore`
/// upward when cycles are detected。
///
/// **Determinism**: same `(prior, event, graph state)` triple
/// always produces same output。Required for replay correctness
/// (G1 BASEventReplayRunner)。
///
/// **Async**: required because graph cycle detection is actor-
/// isolated。
public enum BASUserStateGraphAwareReducer {

    /// Bonus step added to `complexityAddictionScore` per
    /// detected delays-cycle involving the event's project。
    /// Chapter 一百八十五 anti-magic-number — pinned typed
    /// constant。
    public static let cycleDetectionBonusStep: Double = 0.15

    /// Maximum total bonus the cycle-aware path adds in a single
    /// reduce call (clamps even when many cycles are detected)。
    /// Prevents one event from saturating the score in a single
    /// fold step — score should grow gradually。
    public static let cycleDetectionMaxBonus: Double = 0.45

    // MARK: - Reduce

    /// Composed fold: base M842 reducer + M856 graph-cycle
    /// bonus on `complexityAddictionScore`。
    ///
    /// **Behavior**:
    ///   - Always runs M842 base reducer first (deterministic)
    ///   - If `event.project` is nil → return base unchanged
    ///   - If graph has zero delays-cycles involving the
    ///     project → return base unchanged
    ///   - If graph has N delays-cycles involving project →
    ///     base + min(N * cycleDetectionBonusStep,
    ///     cycleDetectionMaxBonus) on complexity score
    ///
    /// **Cycle filter**: only delays-edge cycles count toward
    /// the bonus。This is the user-vision §10 specific signal:
    /// "焦虑→加技术→做不完→焦虑" is a delays cycle。Pure
    /// causes-cycles (eg. event A causes event B causes A again)
    /// don't trigger the bonus — those are normal interaction
    /// patterns,not the addiction signal。
    ///
    /// - Parameters:
    ///   - prior: state vector S_{t-1}
    ///   - event: current event being applied
    ///   - graph: M856 knowledge graph (typically populated by
    ///     M857 extractor before this call)
    ///   - newStateID: caller-supplied UUIDv4
    ///   - generatedAtMs: caller-supplied wall-clock ms
    /// - Returns: next state with cycle-adjusted complexity
    ///   addiction score
    public static func reduce(
        prior: BASUserState,
        event: BASEventLogEntry,
        graph: BASKnowledgeGraph,
        newStateID: String,
        generatedAtMs: Int64
    ) async -> BASUserState {
        // Stage 1: base M842 reducer (pure, sync)
        let base = BASUserStateReducer.reduce(
            prior: prior,
            event: event,
            newStateID: newStateID,
            generatedAtMs: generatedAtMs)
        // Stage 2: project-scoped cycle lookup
        guard let project = event.project,
              !project.isEmpty
        else {
            return base
        }
        let projectNodeID = "project:\(project)"
        let cycles = await graph.detectCycles(
            filter: { cycle in
                cycle.containsEdgeKind(.delays)
                    && cycle.nodeIDs.contains(projectNodeID)
            })
        guard !cycles.isEmpty else {
            return base
        }
        // Stage 3: scale + clamp bonus
        let rawBonus = Double(cycles.count)
            * cycleDetectionBonusStep
        let clampedBonus = min(
            rawBonus, cycleDetectionMaxBonus)
        // BASUserState init clamps complexityAddictionScore to
        // [0, 1] so the addition can't escape the invariant。
        return BASUserState(
            stateID: base.stateID,
            generatedAtMs: base.generatedAtMs,
            schemaVersion: base.schemaVersion,
            emotionalTrend: base.emotionalTrend,
            projectMomentum: base.projectMomentum,
            memoryHeat: base.memoryHeat,
            riskTrend: base.riskTrend,
            complexityAddictionScore:
                base.complexityAddictionScore
                + clampedBonus,
            agentRouteHistory: base.agentRouteHistory,
            lastNEventKinds: base.lastNEventKinds)
    }
}
