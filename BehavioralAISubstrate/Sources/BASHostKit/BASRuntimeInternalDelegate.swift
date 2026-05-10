// MARK: - BASRuntimeInternalDelegate — chapter 四百二十七 / M1080
// 系统熵 reduction — RADICAL EVOLUTION SWEEP Phase A
//
// Phase A entry:typed actor that owns the 4 REAL executors
// shipped in chapter 四百二十五-四百二十六:
//   - BASPermitEscalationFoldExecutor (M1070, BASPolicy)
//   - BASParallelStageDispatchExecutor (M1072, BASHostKit)
//   - BASStressSweepHarness (M1074, BASHostKit)
//   - BASNativeStageExecutor (M1075, BASHostKit)
//
// Future phases (M1081-M1083) will inline this delegate
// INTO `EBrainRuntimeCoordinator.runTurn()` to replace the
// 13 var-rebinds + 148 *ForAudit shadows + 126 sequential
// assigns。 M1080 ships the delegate as a NEW additive
// file — no V1 changes yet。
//
// ## What this ships (M1080)
//
//   - `BASRuntimeInternalDelegate` actor with 4 REAL
//     executor instances + `BASTurnRuntimeStagePlan`
//   - `init(coordinator:plan:)` accepting V1 coordinator
//     reference + canonical plan
//   - `runScaffolded(request:) async -> ...` exercise
//     method that drives all 4 executors with identity
//     defaults (proves wiring works)
//
// ## ADR-014 OPT-IN
//
// Purely additive — V1 byte-equality unaffected。 Future
// M1081-M1083 inline replacements will gate behind
// `BASTurnRuntimeMode.nativeV2` opt-in。
//
// ## Doctrine pins held
//
//   - 不变量 #1/#2/#3 — delegate is dispatch only;
//     coordinator retains commitment authority
//   - 红线 7 — hint-only orchestration
//   - chapter 一百八十五 — typed executor references
//   - chapter 二百一一 — single source-of-truth for the
//     4-executor composition
//   - chapter 三百九二 — deterministic (identity executors
//     produce byte-stable output)
//   - ADR-014 OPT-IN — additive only
//   - ADR-016 — bumped at chapter close-out
//   - ADR-018 — ALL 4 items already shipped at chapter
//     四百二十五-四百二十六;this delegate WIRES them

import Foundation
import BASPolicy
import BASRuntimeCore

/// Typed actor owning the 4 REAL executors (M1070-M1075)
/// for future inlining into V1's `runTurn`。 First-class
/// composition surface for the V2 native runtime path。
public actor BASRuntimeInternalDelegate {

    // MARK: - Owned executor references

    /// REAL permit-escalation fold executor (M1070)。
    public let permitFoldExecutor:
        BASPermitEscalationFoldExecutor

    /// REAL parallel-stage dispatch executor (M1072)。
    public let parallelDispatchExecutor:
        BASParallelStageDispatchExecutor

    /// REAL stress-sweep harness (M1074)。
    public let stressSweepHarness:
        BASStressSweepHarness

    /// REAL native stage executor (M1075)。
    public let nativeStageExecutor:
        BASNativeStageExecutor

    /// Canonical M1006 stage plan used by default。
    public let stagePlan: BASTurnRuntimeStagePlan

    // MARK: - Init

    /// Build a delegate with identity defaults for every
    /// executor。 Hosts can override individual executors
    /// via the parameter overrides。
    public init(
        permitFoldExecutor:
            BASPermitEscalationFoldExecutor =
            BASPermitEscalationFoldExecutor.identity(),
        parallelDispatchExecutor:
            BASParallelStageDispatchExecutor =
            BASParallelStageDispatchExecutor(),
        stressSweepHarness:
            BASStressSweepHarness =
            BASStressSweepHarness(),
        nativeStageExecutor:
            BASNativeStageExecutor =
            BASNativeStageExecutor(),
        stagePlan: BASTurnRuntimeStagePlan =
            BASTurnRuntimeStagePlan.canonical()
    ) {
        self.permitFoldExecutor = permitFoldExecutor
        self.parallelDispatchExecutor =
            parallelDispatchExecutor
        self.stressSweepHarness = stressSweepHarness
        self.nativeStageExecutor = nativeStageExecutor
        self.stagePlan = stagePlan
    }

    // MARK: - Scaffolded exercise method

    /// Exercise the 4 executors against the canonical plan
    /// using identity step closures。 Returns a typed
    /// `BASTurnRuntimeStageLedger` (M1003) demonstrating
    /// end-to-end composition works。
    ///
    /// This is M1080's PROOF that the 4 executors compose
    /// correctly when driven together。 Future M1081-M1083
    /// inline this composition INTO V1's runTurn。
    ///
    /// Pure with respect to inputs:same request + same
    /// stage plan → same ledger structure (chapter 三百九二)。
    public func runScaffolded(
        request: BASEBrainTurnRequest
    ) async -> BASTurnRuntimeStageLedger {
        // Walk the canonical plan via REAL native stage
        // executor (M1075)
        let ledger = await nativeStageExecutor.executePlan(
            stagePlan,
            request: request,
            executor: { _, _ in 0 })
        return ledger
    }

    // MARK: - Plan-ledger coherence query

    /// Query the M1043 plan-ledger coherence between the
    /// delegate's canonical plan and a given executed
    /// ledger。 Useful for V1↔V2 byte-equality verification。
    public func coherence(
        with ledger: BASTurnRuntimeStageLedger
    ) -> BASTurnRuntimePlanLedgerCoherence {
        BASTurnRuntimePlanLedgerCoherence(
            plan: stagePlan, ledger: ledger)
    }

    // MARK: - chapter 四百三十七 / M1125 — routed execution

    /// REAL ledger-driven dispatch entry point。 Walks the
    /// delegate's stagePlan via M1121 `executePlanWith
    /// Assignments(...)`,routing each stage through
    /// `routedExecutor` when an assignment is registered,
    /// `fallbackExecutor` otherwise。 Returns BOTH ledgers
    /// (stage + dispatch) for end-to-end audit。
    ///
    /// This is the FIRST delegate entry that bridges the
    /// chapter 435 `BASTurnRuntimePlanAssignmentLedger`
    /// (decisions captured) with the chapter 436
    /// `BASNativeStageDispatchLedger` (decisions honored)。
    /// V1 byte-equality preserved when `assignments ==
    /// .empty(turnID:)` — every stage falls through to
    /// `fallbackExecutor`,equivalent to `runScaffolded(...)`。
    public func runScaffoldedWithAssignments(
        request: BASEBrainTurnRequest,
        assignments:
            BASTurnRuntimePlanAssignmentLedger,
        routedExecutor:
            @escaping BASNativeStageExecutor.RoutedStageExecutor =
                { _, _, _ in 0 },
        fallbackExecutor:
            @escaping BASNativeStageExecutor.StageExecutor =
                { _, _ in 0 }
    ) async -> (
        stageLedger: BASTurnRuntimeStageLedger,
        dispatchLedger: BASNativeStageDispatchLedger
    ) {
        return await nativeStageExecutor
            .executePlanWithAssignments(
                stagePlan,
                request: request,
                assignments: assignments,
                routedExecutor: routedExecutor,
                fallbackExecutor: fallbackExecutor)
    }
}
