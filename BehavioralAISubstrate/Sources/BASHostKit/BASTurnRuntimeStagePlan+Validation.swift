// MARK: - BASTurnRuntimeStagePlan+Validation — chapter 四百九 / M1007
// 系统熵 reduction
//
// Phase 2 entropy chapter 四百九 second cut:typed validation
// surface for `BASTurnRuntimeStagePlan` (M1006)。 Future
// native V2 stage rewrites and audit consumers can grep these
// validation results to catch malformed plans before runtime
// dispatch。
//
// ## Why this exists (system entropy framing)
//
// `BASTurnRuntimeStagePlan` ships the typed shape but says
// nothing about what makes a plan VALID。 Without typed
// validation predicates,future plan variants (eg. tribunal
// rerun bypass plan,degraded-mode plan) would each rederive
// "is this plan well-formed?" inline,producing scattered
// validation entropy。
//
// `BASTurnRuntimeStagePlanValidationIssue` ships the typed
// failure cases;`validate()` returns the typed list (empty
// = valid)。 `isCanonical` returns true only when the plan
// matches `.canonical()` byte-for-byte。
//
// ## What this ships (M1007)
//
//   - `BASTurnRuntimeStagePlanValidationIssue` typed enum
//     (4 cases: missingStage / duplicateStage /
//     parallelGroupMembershipMismatch /
//     sequentialStepHasMultipleStages)
//   - `BASTurnRuntimeStagePlan.validate()` returning typed
//     issue list (empty = valid)
//   - `BASTurnRuntimeStagePlan.isWellFormed` Bool accessor
//   - `BASTurnRuntimeStagePlan.isCanonical` Bool accessor
//
// ## What this does NOT ship (deferred)
//
//   - Repair function that converts a malformed plan into
//     the closest valid variant (large,separate cut)
//
// ## Doctrine pins held
//
//   - 不变量 #1/#2/#3 — pure value/predicate;no commitment
//     surface
//   - chapter 一百八十五 anti-magic-number — issue cases
//     typed not raw strings
//   - chapter 二百一一 single-source-of-truth — validation
//     rules owned here;future plan variants consume,
//     don't duplicate
//   - chapter 三百九二 — deterministic
//   - ADR-014 OPT-IN — purely additive

import Foundation

/// Typed enum naming the failure modes a stage plan can
/// have。 Audit consumers grep these to filter malformed
/// plans。
public enum BASTurnRuntimeStagePlanValidationIssue:
    Equatable, Hashable, Sendable
{
    /// One or more `BASTurnRuntimeStage` cases never appear
    /// in any step。 Associated value is the missing
    /// stages in `BASTurnRuntimeStage.allCases` order。
    case missingStages([BASTurnRuntimeStage])
    /// One or more stages appear in more than one step,or
    /// more than once within a single step。 Associated
    /// value is the duplicated stages。
    case duplicateStages([BASTurnRuntimeStage])
    /// A parallel step has a member stage whose M1000
    /// `parallelGroup` doesn't match the step's declared
    /// parallel group。 Associated value is the offending
    /// stage and the step's declared group。
    case parallelGroupMismatch(
        stage: BASTurnRuntimeStage,
        declaredGroup:
            BASTurnRuntimeStageParallelGroup)
    /// A sequential step (`parallelGroup == nil`) holds
    /// more than one stage。 Associated value is the step
    /// index and the stage count。
    case sequentialStepHasMultipleStages(
        stepIndex: Int, stageCount: Int)
}

extension BASTurnRuntimeStagePlan {

    // MARK: - Validation

    /// Return the typed list of issues with this plan,
    /// empty if well-formed。 Pure;same plan → same list。
    public func validate()
        -> [BASTurnRuntimeStagePlanValidationIssue]
    {
        var issues:
            [BASTurnRuntimeStagePlanValidationIssue] = []

        // Pass 1:per-step well-formedness。
        for (idx, step) in steps.enumerated() {
            // Sequential step must hold exactly one stage。
            if step.parallelGroup == nil && step.stages.count > 1 {
                issues.append(
                    .sequentialStepHasMultipleStages(
                        stepIndex: idx,
                        stageCount: step.stages.count))
            }
            // Parallel step's member stages must match
            // the step's declared parallel group per the
            // M1000 enum。
            if let group = step.parallelGroup {
                for stage in step.stages
                where stage.parallelGroup != group {
                    issues.append(
                        .parallelGroupMismatch(
                            stage: stage,
                            declaredGroup: group))
                }
            }
        }

        // Pass 2:coverage check + duplicate check。
        var counts: [BASTurnRuntimeStage: Int] = [:]
        for stage in orderedStages {
            counts[stage, default: 0] += 1
        }
        let missing = BASTurnRuntimeStage.allCases
            .filter { counts[$0, default: 0] == 0 }
        if !missing.isEmpty {
            issues.append(.missingStages(missing))
        }
        let duplicates = BASTurnRuntimeStage.allCases
            .filter { (counts[$0] ?? 0) > 1 }
        if !duplicates.isEmpty {
            issues.append(.duplicateStages(duplicates))
        }

        return issues
    }

    /// `true` when the plan has zero validation issues。
    public var isWellFormed: Bool {
        validate().isEmpty
    }

    /// `true` when the plan equals `.canonical()` byte-for-
    /// byte。
    public var isCanonical: Bool {
        self == BASTurnRuntimeStagePlan.canonical()
    }
}
