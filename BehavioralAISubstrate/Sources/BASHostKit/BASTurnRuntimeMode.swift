// MARK: - BASTurnRuntimeMode — chapter 四百二十七 / M1081
// 系统熵 reduction — RADICAL EVOLUTION SWEEP
//
// Phase A second cut:typed enum naming the 3 runtime
// execution modes for `BASTurnRuntimeEngine`。 Hosts opt
// into V2 native execution via this enum;default is
// `.v1ByteEqual` for ADR-014 OPT-IN compliance。
//
// ## Why this exists (RADICAL EVOLUTION)
//
// The 4 REAL executors (M1070-M1075) + M1080
// BASRuntimeInternalDelegate exist but have no caller
// switch to activate them。 `BASTurnRuntimeMode` is the
// typed switch:
//
//   - `.v1ByteEqual` (default):existing V1 delegation
//     path,byte-equal to pre-M1080 baseline
//   - `.nativeV2`:V2 native execution via runWithPlan()
//     using the 4 REAL executors
//   - `.stressSweepDual`:run BOTH V1 + V2 paths per turn
//     and digest-compare via M1074 BASStressSweepHarness
//
// ## ADR-033 Step 3b update — the mode switch is now LIVE
//
// Through M1081 the mode was STORED on the engine but `runTurn` IGNORED it (always V1 —
// the ch1044 严查 finding). As of ADR-033 Step 3b `runTurn` READS `runtimeMode`:
// `.nativeV2` dispatches `runWithPlan(...)` (the real native executors). The result stays
// V1-derived / byte-equal (proven across canonical60 by BASEBrainTurnResultReplayHarness),
// so this honors ADR-014 / R1 while making the `.nativeV2` label TRUE, not aspirational.
//
// ## What this ships (M1081)
//
//   - `BASTurnRuntimeMode` typed enum (3 cases) +
//     CaseIterable + Codable + Hashable + Sendable
//   - Raw values pinned per chapter 一百八十五
//
// ## Doctrine pins held
//
//   - 不变量 #1/#2/#3 — mode is dispatch only;commitment
//     authority unchanged
//   - 红线 7 — hint-only enum
//   - chapter 一百八十五 — typed enum,raw values pinned
//   - chapter 二百一一 — single source-of-truth for V1↔V2
//     mode switching
//   - chapter 三百九二 — same enum every call
//   - ADR-014 OPT-IN — `.v1ByteEqual` default preserves
//     V1 byte-equality

import Foundation

/// Typed enum naming the 3 runtime execution modes for
/// `BASTurnRuntimeEngine`。
public enum BASTurnRuntimeMode:
    String, Codable, Equatable, Hashable, Sendable, CaseIterable
{
    /// Default mode:V2 actor delegates to V1 coordinator
    /// for byte-equal output。 ADR-014 OPT-IN compliance。
    case v1ByteEqual = "v1-byte-equal"
    /// Native V2 mode:`BASTurnRuntimeEngine.runTurn` dispatches `runWithPlan(...)`,
    /// executing the M1075 BASNativeStageExecutor + M1072 BASParallelStageDispatchExecutor
    /// + M1070 BASPermitEscalationFoldExecutor。 Hosts opt in。 The returned
    /// `BASEBrainTurnResult` remains V1-derived (ADR-014) and is BYTE-EQUAL to
    /// `.v1ByteEqual` — proven across canonical60 by
    /// `BASEBrainTurnResultReplayHarness.v1VsRunWithPlanParityVerdict` (ADR-033 Step 3b)。
    /// The native path's observable effect is additional stage-ledger / dispatch telemetry,
    /// NOT a different answer。
    case nativeV2 = "native-v2"
    /// Dual mode:run BOTH V1 and V2 paths per turn,
    /// digest-compare via M1074 BASStressSweepHarness。
    /// Used during V2 default-mode flip validation。
    case stressSweepDual = "stress-sweep-dual"
}
