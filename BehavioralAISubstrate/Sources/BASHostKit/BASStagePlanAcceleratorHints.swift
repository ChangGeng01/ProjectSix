// MARK: - BASStagePlanAcceleratorHints
// chapter 四百三十三 / M1104 — RADICAL EVOLUTION SWEEP wrap-up
//
// Sidecar struct mapping `BASTurnRuntimeStage` →
// `BASStageAcceleratorHint`。 Lets callers attach
// per-stage scheduler hints to a plan WITHOUT modifying
// `BASTurnRuntimeStagePlan` itself。
//
// ## Why this exists (system entropy framing)
//
// The Phase F M1102 BASHardwareAwareScheduler accepts a
// `BASStageAcceleratorHint` per dispatch decision but
// has no caller wired to it。 The natural wiring would
// be "attach a hint to each stage step inside
// BASTurnRuntimeStagePlan,then have BASNativeStage
// Executor consult the scheduler before each stage"。
//
// In autonomous mode that direct modification is too
// risky:
//
//   1. BASTurnRuntimeStagePlan is referenced by 30+
//      tests + the canonical 16-step builder + the
//      M1101 runWithPlan dispatch path
//   2. Adding a per-step hint slot would change the
//      Codable shape + break replay golden fixtures
//   3. BASNativeStageExecutor would need a scheduler
//      injection point + invocation guard
//
// `BASStagePlanAcceleratorHints` is the SIDECAR:
// callers construct one independently of the plan,
// pass both to a scheduler-aware dispatch loop, and
// the original plan stays untouched。 Future native V2
// stage rewrites consume both surfaces;callers that
// don't care about hardware-aware dispatch ignore the
// sidecar entirely。
//
// ## What this ships (M1104)
//
//   - `BASStagePlanAcceleratorHints` Sendable + Codable
//     + Equatable struct (dictionary mapping
//     BASTurnRuntimeStage → BASStageAcceleratorHint)
//   - `init(_:)` taking the dictionary directly
//   - `init()` empty constructor
//   - `with(stage:hint:)` immutable updater
//   - `hint(for:)` lookup returning Optional
//   - `stageCount` accessor + `isEmpty` predicate
//   - `coversAllStages(in:)` helper checking whether
//     every step's stage in a given plan has a hint
//
// ## What this DOES NOT ship (deferred)
//
//   - BASTurnRuntimeStagePlan modification to carry
//     `acceleratorHint:` per-step (would change Codable
//     + break golden fixtures)
//   - BASNativeStageExecutor.executePlan integration
//     (depends on plan modification above)
//   - Default canonical hints set (per-stage hints are
//     caller-defined;the scheduler's `.balanced`
//     preference is the safe default)
//
// All 3 deferred items land in follow-up chapters
// under explicit user control。
//
// ## Doctrine pins held
//
//   - chapter 一百八十五 — anti-magic-number (typed
//     stage-keyed dictionary;no raw String stage
//     names)
//   - chapter 二百一一 — single source-of-truth (one
//     sidecar per dispatch loop;no per-step hint
//     duplication inside the plan)
//   - chapter 三百九二 — replay-determinism (Codable
//     via sortedKeys JSON;Dictionary serialization
//     is order-stable on stage rawvalue)
//   - 不变量 #1/#2/#3 — V1 byte-equality preserved
//     (sidecar is purely additive;BASTurnRuntimeStage
//     Plan untouched)
//   - 红线 7 — hint-only (literally — these are
//     scheduler hints,not commitment authority)
//   - ADR-014 OPT-IN — purely additive

import Foundation
import BASMetalSubstrate

/// Sidecar bundle mapping `BASTurnRuntimeStage` keys
/// to `BASStageAcceleratorHint` values。 Caller-owned;
/// the V2 runtime engine + BASNativeStageExecutor
/// consume the sidecar alongside the plan when
/// hardware-aware dispatch is wanted。
public struct BASStagePlanAcceleratorHints:
    Equatable, Codable, Sendable
{

    /// Per-stage hint storage。 Stages without a hint
    /// fall through to scheduler default (`.balanced`
    /// preference + .conservative capability)。
    public let hints:
        [BASTurnRuntimeStage: BASStageAcceleratorHint]

    public init(
        _ hints:
            [BASTurnRuntimeStage:
                BASStageAcceleratorHint] = [:]
    ) {
        self.hints = hints
    }

    /// Empty sidecar — no per-stage hints。 The
    /// scheduler treats every stage as if it had the
    /// `.balanced` default。
    public static let empty: BASStagePlanAcceleratorHints =
        BASStagePlanAcceleratorHints()

    // MARK: - Lookup

    /// Returns the hint registered for the given stage,
    /// or nil。
    public func hint(
        for stage: BASTurnRuntimeStage
    ) -> BASStageAcceleratorHint? {
        return hints[stage]
    }

    // MARK: - Immutable update

    /// Returns a new sidecar with `hint` registered for
    /// `stage`。 Replaces any existing hint for the
    /// stage。
    public func with(
        stage: BASTurnRuntimeStage,
        hint: BASStageAcceleratorHint
    ) -> BASStagePlanAcceleratorHints {
        var updated = hints
        updated[stage] = hint
        return BASStagePlanAcceleratorHints(updated)
    }

    /// Returns a new sidecar with the hint for `stage`
    /// removed。
    public func without(
        stage: BASTurnRuntimeStage
    ) -> BASStagePlanAcceleratorHints {
        var updated = hints
        updated.removeValue(forKey: stage)
        return BASStagePlanAcceleratorHints(updated)
    }

    // MARK: - Aggregates

    /// Number of stages with registered hints。
    public var stageCount: Int { hints.count }

    /// `true` when no hints registered (sidecar carries
    /// the scheduler's default behavior)。
    public var isEmpty: Bool { hints.isEmpty }

    // MARK: - Plan coverage

    /// Returns `true` if every stage in `plan`'s steps
    /// has a hint registered。 Useful for callers that
    /// want to fail fast when a plan is missing hints
    /// for stages that would otherwise fall through to
    /// scheduler defaults。
    public func coversAllStages(
        in plan: BASTurnRuntimeStagePlan
    ) -> Bool {
        for step in plan.steps {
            for stage in step.stages {
                if hints[stage] == nil { return false }
            }
        }
        return true
    }

    /// Returns the stages in `plan` that DO NOT have a
    /// hint registered。 Sorted by stage rawvalue for
    /// replay-determinism (chapter 三百九二)。
    public func stagesMissingHints(
        in plan: BASTurnRuntimeStagePlan
    ) -> [BASTurnRuntimeStage] {
        var missing: Set<BASTurnRuntimeStage> = []
        for step in plan.steps {
            for stage in step.stages {
                if hints[stage] == nil {
                    missing.insert(stage)
                }
            }
        }
        return missing.sorted { $0.rawValue < $1.rawValue }
    }
}
