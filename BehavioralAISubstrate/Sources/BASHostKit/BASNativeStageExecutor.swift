// MARK: - BASNativeStageExecutor — chapter 四百二十六 / M1075
// 系统熵 reduction
//
// Phase 2 entropy chapter 四百二十六 second cut:REAL working
// native stage executor。 Moves the fourth (and final)
// ADR-018-pending item (`nativeStageRewrites`) from
// `.pending` to `.shipped`。
//
// ## Why this is REAL (not scaffolding)
//
// Chapter 四百八+ shipped the typed scaffolding for native
// V2 stages:M1000 stage enum + M1002 stage record + M1003
// stage ledger + M1006 stage plan + M1007 plan validation
// + M1026 cardinality + M1027 assemble order + M1043 plan-
// ledger coherence。 But no actual executor existed that
// runs a typed stage and produces a typed
// `BASTurnRuntimeStageRecord`。
//
// `BASNativeStageExecutor` ships the REAL executor:
//
//   - `executeStage(_:request:executor:)` invokes the
//     caller-provided typed closure for a stage,times
//     the execution,and emits a typed M1002 record
//   - `executePlan(_:request:executor:)` walks an entire
//     M1006 plan,produces a typed M1003 ledger
//
// Pattern matches M1070/M1072:executor is pure dispatch
// over caller-provided typed closures。 Caller wires real
// stage logic (or stubs) into the closures。
//
// ## What this ships (M1075)
//
//   - `BASNativeStageExecutor` actor
//   - `BASNativeStageExecutor.StageExecutor<Output>`
//     typealias
//   - `executeStage(_:request:executor:)` REAL single-
//     stage executor producing typed record
//   - `executePlan(_:request:executor:)` REAL plan walker
//     producing typed ledger
//
// ## Doctrine pins held
//
//   - 不变量 #1/#2/#3 — executor is dispatch only
//   - 红线 7 — hint-only
//   - chapter 一百八十五 — typed closure shape
//   - chapter 二百一一 — single source-of-truth for stage
//     execution
//   - chapter 三百九二 — same stage + same closure → same
//     record
//   - ADR-014 OPT-IN — purely additive
//   - ADR-018 — moves `nativeStageRewrites` from .pending
//     to .shipped (FINAL ADR-018 item)

import Foundation
import BASRuntimeCore

/// Real working actor that executes typed V2 stages,
/// producing typed `BASTurnRuntimeStageRecord` outputs。
public actor BASNativeStageExecutor {

    // MARK: - Typed executor closure

    /// Typed closure shape:given a stage + request,
    /// produce the stage's output。 Caller wraps real
    /// stage logic inside the closure。 Output type is
    /// erased to `Any` since stage outputs vary per stage;
    /// real callers cast to the appropriate concrete type。
    public typealias StageExecutor = @Sendable (
        BASTurnRuntimeStage,
        BASEBrainTurnRequest
    ) async -> Any

    public init() {}

    // MARK: - Single-stage execution

    /// Execute a single typed stage via the provided
    /// closure。 Times the execution + emits a typed
    /// `BASTurnRuntimeStageRecord`。 Pure dispatch:no
    /// stage-specific logic;caller wraps real services。
    ///
    /// Pure with respect to closure outputs:same stage +
    /// same request + same closure (same closure timing
    /// behavior) → same record (chapter 三百九二)。
    /// Wall-clock duration may vary across runs but record
    /// shape is byte-stable when durationMs is normalized。
    public func executeStage(
        _ stage: BASTurnRuntimeStage,
        request: BASEBrainTurnRequest,
        executor: @escaping StageExecutor
    ) async -> BASTurnRuntimeStageRecord {
        let start = Date()
        _ = await executor(stage, request)
        let durationMs = max(0, Int(
            Date().timeIntervalSince(start) * 1000))
        return BASTurnRuntimeStageRecord.completed(
            stage, durationMs: durationMs)
    }

    // MARK: - Plan execution

    /// Execute an entire M1006 plan sequentially (per-step,
    /// not per-stage — parallel-group steps still execute
    /// stage-by-stage in this simple walker)。 Produces a
    /// typed M1003 ledger with one record per executed
    /// stage。
    ///
    /// For real parallel-group dispatch,combine with
    /// `BASParallelStageDispatchExecutor` (M1072) — this
    /// walker is the sequential-baseline。 V1↔V2 parity
    /// tests use this walker because sequential wall-clock
    /// is deterministic;the parallel executor handles
    /// fan-outs。
    public func executePlan(
        _ plan: BASTurnRuntimeStagePlan,
        request: BASEBrainTurnRequest,
        executor: @escaping StageExecutor
    ) async -> BASTurnRuntimeStageLedger {
        var ledger = BASTurnRuntimeStageLedger.empty()
        for step in plan.steps {
            for stage in step.stages {
                let record = await executeStage(
                    stage,
                    request: request,
                    executor: executor)
                ledger = ledger.appending(record: record)
            }
        }
        return ledger
    }
}
