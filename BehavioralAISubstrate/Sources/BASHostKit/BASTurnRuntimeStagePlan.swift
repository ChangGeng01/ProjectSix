// MARK: - BASTurnRuntimeStagePlan — chapter 四百九 / M1006
// 系统熵 reduction
//
// Phase 2 entropy chapter 四百九 entry:typed value type
// describing the canonical execution plan over the 18 V2
// stages (M1000)。 Native V2 stage rewrites (deferred to
// future v2+) walk this plan step-by-step to drive runTurn,
// honoring declared parallel-group fan-outs。
//
// ## Why this exists (system entropy framing)
//
// M1000 ships the 18 stage names and their 4 parallel-group
// memberships。 But there is no typed primitive declaring
// the canonical execution ORDER of those stages or the
// canonical step-grouping。 Future native V2 stage rewrites
// would otherwise hard-code the order inline,producing
// scattered stage-order entropy duplicated across every
// rewrite scaffold。
//
// `BASTurnRuntimeStagePlan` ships the canonical plan as a
// typed value:
//
//   - 16 steps,each step is one parallel group OR one
//     sequential stage
//   - Step 1: [A, A2]    @ entryAA2     (2-way parallel)
//   - Step 2: [B]                       (sequential)
//   - Step 3: [C]                       (sequential)
//   - Step 4: [D, D2]    @ dD2          (2-way parallel)
//   - Step 5: [E]                       (sequential)
//   - Step 6: [F]                       (sequential)
//   - Step 7: [G]                       (sequential)
//   - Step 8: [H]                       (sequential)
//   - Step 9: [I]                       (sequential)
//   - Step 10:[J]                       (sequential)
//   - Step 11:[K]                       (sequential)
//   - Step 12:[L]                       (sequential)
//   - Step 13:[M1]       @ m1FourWay    (4-way fan-out
//                                        internally)
//   - Step 14:[N]                       (sequential)
//   - Step 15:[O]        @ o12Way       (12-way fan-out
//                                        internally)
//   - Step 16:[P]                       (sequential)
//
// Total = 16 steps,18 stages,4 parallel-group steps,
// 12 sequential steps。
//
// ## What this ships (M1006)
//
//   - `BASTurnRuntimeStageStep` typed value type (1-N
//     stages + optional parallel-group identifier)
//   - `BASTurnRuntimeStagePlan` typed value type (sequence
//     of steps)
//   - `.canonical()` factory returning the canonical
//     16-step plan
//   - aggregate accessors: orderedStages /
//     parallelStepCount / sequentialStepCount /
//     stageCount / stepCount
//
// ## What this does NOT ship (deferred to chapter 四百九+)
//
//   - Driver function that EXECUTES the plan against a V2
//     actor (would need to inject service-by-service
//     callbacks per stage — large, separate cut)
//   - Validation that the plan covers all 18 stages
//     exactly once (M1007 will pin this)
//   - Plan variants for special-case turns (eg. tribunal
//     rerun bypass) — separate cut once the canonical plan
//     is exercised
//
// ## Doctrine pins held
//
//   - 不变量 #1/#2/#3 — pure value type;no commitment
//     surface
//   - chapter 一百八十五 anti-magic-number — step-group
//     names + parallelism declared via M1000 enums,not
//     raw strings
//   - chapter 二百一一 single-source-of-truth — canonical
//     plan owned here;future V2 rewrites consume,don't
//     duplicate the order
//   - chapter 三百九二 replay-determinism — same canonical
//     plan every call
//   - ADR-014 OPT-IN — purely additive;V1 untouched

import Foundation

/// Typed value type describing one step of a stage plan。
/// A step is either a single sequential stage (`stages.count
/// == 1` && `parallelGroup == nil`) OR a fan-out parallel
/// group (`parallelGroup != nil`)。
public struct BASTurnRuntimeStageStep:
    Codable, Equatable, Sendable, Hashable
{

    // MARK: - Storage

    /// Stages that run together in this step。 For a
    /// sequential step,exactly 1 stage。 For a parallel
    /// step,N stages (M1000's parallel-group cardinality)。
    public let stages: [BASTurnRuntimeStage]

    /// Parallel-group identifier when this step fans out;
    /// `nil` when this step runs sequentially (one stage)。
    public let parallelGroup: BASTurnRuntimeStageParallelGroup?

    // MARK: - Init

    public init(
        stages: [BASTurnRuntimeStage],
        parallelGroup: BASTurnRuntimeStageParallelGroup? = nil
    ) {
        self.stages = stages
        self.parallelGroup = parallelGroup
    }

    // MARK: - Convenience factories

    /// Build a sequential step holding exactly one stage。
    public static func sequential(
        _ stage: BASTurnRuntimeStage
    ) -> BASTurnRuntimeStageStep {
        BASTurnRuntimeStageStep(
            stages: [stage], parallelGroup: nil)
    }

    /// Build a parallel-group step holding the listed stages。
    public static func parallel(
        _ stages: [BASTurnRuntimeStage],
        group: BASTurnRuntimeStageParallelGroup
    ) -> BASTurnRuntimeStageStep {
        BASTurnRuntimeStageStep(
            stages: stages, parallelGroup: group)
    }

    // MARK: - Accessors

    /// `true` when the step fans out (parallelGroup != nil)。
    public var isParallel: Bool {
        parallelGroup != nil
    }

    /// `true` when the step runs sequentially (one stage)。
    public var isSequential: Bool {
        parallelGroup == nil
    }

    /// Number of stages in this step。
    public var stageCount: Int { stages.count }
}

/// Typed value type holding the canonical execution plan
/// over the 18 V2 stages。 Future native V2 stage rewrites
/// walk this plan step-by-step。
public struct BASTurnRuntimeStagePlan:
    Codable, Equatable, Sendable
{

    // MARK: - Storage

    /// Steps in execution order。 Default-empty for ad-hoc
    /// constructions;`.canonical()` returns the canonical
    /// 16-step plan derived from the M1000 DAG topology。
    public let steps: [BASTurnRuntimeStageStep]

    // MARK: - Init

    public init(steps: [BASTurnRuntimeStageStep] = []) {
        self.steps = steps
    }

    // MARK: - Canonical plan

    /// The canonical 16-step plan over the 18 M1000 stages,
    /// matching the chapter 四百三 entropy audit's runTurn
    /// DAG topology。 Same input → same plan every call
    /// (chapter 三百九二)。
    public static func canonical() -> BASTurnRuntimeStagePlan {
        BASTurnRuntimeStagePlan(steps: [
            // Step 1: parallel A‖A2
            .parallel([.stageA, .stageA2], group: .entryAA2),
            // Step 2-3: sequential B → C
            .sequential(.stageB),
            .sequential(.stageC),
            // Step 4: parallel D‖D2
            .parallel([.stageD, .stageD2], group: .dD2),
            // Step 5-12: sequential E → L
            .sequential(.stageE),
            .sequential(.stageF),
            .sequential(.stageG),
            .sequential(.stageH),
            .sequential(.stageI),
            .sequential(.stageJ),
            .sequential(.stageK),
            .sequential(.stageL),
            // Step 13: M1 (4-way fan-out internally)
            .parallel([.stageM1], group: .m1FourWay),
            // Step 14: sequential N
            .sequential(.stageN),
            // Step 15: O (12-way fan-out internally)
            .parallel([.stageO], group: .o12Way),
            // Step 16: sequential P
            .sequential(.stageP)
        ])
    }

    // MARK: - Aggregate accessors

    /// Number of steps in this plan。
    public var stepCount: Int { steps.count }

    /// Total number of stage occurrences across all steps。
    /// Sums each step's stage count。
    public var stageCount: Int {
        steps.reduce(0) { $0 + $1.stageCount }
    }

    /// All stages in plan order,flattening parallel-group
    /// steps into their member stages。
    public var orderedStages: [BASTurnRuntimeStage] {
        steps.flatMap { $0.stages }
    }

    /// Number of steps that fan out (have a parallelGroup)。
    public var parallelStepCount: Int {
        steps.filter { $0.isParallel }.count
    }

    /// Number of steps that run sequentially (no
    /// parallelGroup)。
    public var sequentialStepCount: Int {
        steps.filter { $0.isSequential }.count
    }
}
