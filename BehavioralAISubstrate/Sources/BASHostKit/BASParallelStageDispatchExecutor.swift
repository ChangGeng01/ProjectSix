// MARK: - BASParallelStageDispatchExecutor — chapter 四百二十五 / M1072
// 系统熵 reduction
//
// Phase 2 entropy chapter 四百二十五 second cut:REAL working
// parallel-stage dispatch executor。 Moves the second
// ADR-018-pending item (`parallelDispatchDriver`) from
// `.pending` to `.shipped`。
//
// ## Why this is REAL (not scaffolding)
//
// Chapter 四百十四 shipped M1027 BASParallelStageAssembleOrder
// — the typed wrapper that anchors chapter 三百九二 byte-
// stability across non-deterministic async-let completion
// order。 But no actual driver existed that runs the
// async let fan-outs and produces the typed assembly。
//
// `BASParallelStageDispatchExecutor` ships the REAL driver:
//
//   - `dispatchTwoWayFanOut(group:first:second:...)` runs
//     2 async-let tasks in parallel + assembles canonically
//   - `dispatchFourWayFanOut(group:stages:steps:)` runs
//     4 async-let tasks in parallel + assembles canonically
//
// Both anchor chapter 三百九二 byte-stability:async-let
// completion order is non-deterministic but `.canonical
// Outputs` always returns in M1000-pinned order via M1027
// `BASParallelStageAssembleOrder`。
//
// ## What this ships (M1072)
//
//   - `BASParallelStageDispatchExecutor` actor
//   - `StageStep<Output>` typealias
//   - `dispatchTwoWayFanOut(group:first:second:firstStep:
//      secondStep:)` REAL async-let 2-way executor
//   - `dispatchFourWayFanOut(group:stages:steps:)` REAL
//     async-let 4-way executor (serves M1 stage)
//
// ## Doctrine pins held
//
//   - All chapter 四百三/…/四百二十四 doctrine pins
//   - chapter 一百八十五 — typed closure shape
//   - chapter 二百一一 — single source-of-truth for
//     parallel dispatch logic
//   - chapter 三百九二 (CRITICAL) — async-let completion
//     order is non-deterministic but canonicalOutputs is
//     byte-stable via M1027 wrapper
//   - ADR-014 OPT-IN — purely additive
//   - ADR-018 — moves `parallelDispatchDriver` from
//     `.pending` to `.shipped`

import Foundation

/// Real working actor that executes parallel-stage fan-outs
/// using `async let`,producing byte-stable canonical
/// assemblies via M1027 `BASParallelStageAssembleOrder`。
public actor BASParallelStageDispatchExecutor {

    // MARK: - Typed step closure

    /// Typed closure shape for one stage step in a parallel
    /// fan-out。 Caller wraps a real stage service (or stub)
    /// inside this closure。 Pure with respect to the
    /// dispatch:no inputs,output-out。
    public typealias StageStep<Output: Sendable> =
        @Sendable () async -> Output

    public init() {}

    // MARK: - Two-way fan-out (entryAA2 / dD2)

    /// Execute 2-way parallel fan-out via `async let`。
    /// Both tasks run in parallel;`canonicalOutputs`
    /// returns them in M1000-pinned order。
    ///
    /// chapter 三百九二 byte-stability anchor:async-let
    /// completion order is non-deterministic but the
    /// returned assembly's `.canonicalOutputs` is byte-
    /// stable。
    public func dispatchTwoWayFanOut<Output: Sendable>(
        group: BASTurnRuntimeStageParallelGroup,
        first: BASTurnRuntimeStage,
        second: BASTurnRuntimeStage,
        firstStep: @escaping StageStep<Output>,
        secondStep: @escaping StageStep<Output>
    ) async -> BASParallelStageAssembleOrder<Output> {
        async let firstResult = firstStep()
        async let secondResult = secondStep()
        let r1 = await firstResult
        let r2 = await secondResult
        return BASParallelStageAssembleOrder<Output>(
            group: group,
            outputsByStage: [
                first: r1,
                second: r2
            ])
    }

    // MARK: - Four-way fan-out (M1 internal)

    /// Execute 4-way parallel fan-out via `async let`。
    /// All 4 tasks run in parallel;assembled outputs are
    /// returned in caller-declared stage order。
    ///
    /// chapter 三百九二 byte-stability anchor:async-let
    /// completion order is non-deterministic but the
    /// returned array order matches `stages` parameter
    /// order exactly。
    public func dispatchFourWayFanOut<Output: Sendable>(
        group: BASTurnRuntimeStageParallelGroup,
        stages: [BASTurnRuntimeStage],
        steps: [StageStep<Output>]
    ) async -> BASParallelStageAssembleOrder<Output> {
        precondition(
            stages.count == 4 && steps.count == 4,
            "four-way fan-out requires exactly 4 stages " +
            "and 4 steps")
        async let r0 = steps[0]()
        async let r1 = steps[1]()
        async let r2 = steps[2]()
        async let r3 = steps[3]()
        let o0 = await r0
        let o1 = await r1
        let o2 = await r2
        let o3 = await r3
        return BASParallelStageAssembleOrder<Output>(
            group: group,
            outputsByStage: [
                stages[0]: o0,
                stages[1]: o1,
                stages[2]: o2,
                stages[3]: o3
            ])
    }
}
