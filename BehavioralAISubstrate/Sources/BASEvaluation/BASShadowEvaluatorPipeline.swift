// MARK: - BASShadowEvaluatorPipeline — chapter 二百六十 / M754
//
// Multi-evaluator composition primitive — Stage 3 Step 5 of 5.
//
// ## Why this exists
//
// chapter 一百七十七 P3 "Multi-CoreML pipeline" envisions multiple
// `BASShadowEvaluating` conformers running together (e.g. one
// substrate-reaudit + one ML-backed body-feature classifier +
// one memory-importance rerank head). Until chapter 二百六十,
// hosts had to either pick ONE evaluator or write ad-hoc
// composition code. Composition is generic enough to deserve a
// shared primitive.
//
// chapter 二百六十 ships `BASShadowEvaluatorPipeline`:
//   - Wraps an ordered array of `any BASShadowEvaluating`
//     conformers.
//   - Conforms to `BASShadowEvaluating` itself (so a pipeline is
//     drop-in for any conformer slot).
//   - Runs the evaluators concurrently via `TaskGroup` (each
//     evaluator's `evaluate` is independent — `prompt` + `body`
//     + `prePermitMode` are read-only inputs).
//   - Merges per-evaluator results into one `BASShadowEvaluationResult`
//     using a configurable `MergeStrategy`.
//
// Real `.mlpackage` shipping is operator decision (chapter
// 二百六十八 ML-backed evaluator + real bench data); the
// pipeline ships independent of that — once an ML-backed
// evaluator exists, hosts compose it with substrate-reaudit
// without further changes.
//
// ## Doctrine pins
//
//   - 不变量 #1 / #2 / #3 unchanged: pipeline is observability —
//     it composes observability inputs into one observability
//     output. No production state is mutated.
//   - 红线 7 watcher-only-hint: the merged result is a HINT.
//     Hosts decide whether to act on `shifted == true`.
//   - chapter 二百六十六 / M748 single-source-of-truth: protocol
//     stays in `BASShadowEvaluating.swift`; this file is one
//     conformer that composes others.

import Foundation
import BASRuntimeCore

/// Strategy for merging per-evaluator `shifted` flags into a
/// single pipeline-level `shifted`. Codable so audit trails can
/// record which strategy was active.
public enum BASShadowEvaluatorMergeStrategy:
    String, Sendable, Codable, Hashable, CaseIterable
{
    /// `shifted = true` if ANY non-skipped evaluator returned
    /// `shifted: true`. Most permissive — hint fires on any
    /// evaluator's signal. Default.
    case anyShifted = "any-shifted"

    /// `shifted = true` only if ALL non-skipped evaluators
    /// returned `shifted: true`. Most conservative — hint fires
    /// only on unanimous signal.
    case allShifted = "all-shifted"

    /// `shifted = true` if strictly more than half of non-skipped
    /// evaluators returned `shifted: true`. Tie or below half →
    /// `false`.
    case majorityShifted = "majority-shifted"
}

/// A pipeline of `BASShadowEvaluating` conformers running
/// concurrently and merging their results. Conforms to
/// `BASShadowEvaluating` itself so a pipeline can be passed
/// anywhere a single evaluator is expected.
public struct BASShadowEvaluatorPipeline: BASShadowEvaluating {

    public static let defaultMergeStrategy: BASShadowEvaluatorMergeStrategy =
        .anyShifted

    public let evaluatorVersion: String

    /// Composed evaluators. Order is stable (preserved in
    /// reasonCodes for forensic audit).
    public let evaluators: [any BASShadowEvaluating]

    public let mergeStrategy: BASShadowEvaluatorMergeStrategy

    public init(
        evaluators: [any BASShadowEvaluating],
        mergeStrategy: BASShadowEvaluatorMergeStrategy =
            BASShadowEvaluatorPipeline.defaultMergeStrategy,
        evaluatorVersion: String? = nil
    ) {
        self.evaluators = evaluators
        self.mergeStrategy = mergeStrategy
        if let supplied = evaluatorVersion?
            .trimmingCharacters(
                in: .whitespacesAndNewlines),
            !supplied.isEmpty
        {
            self.evaluatorVersion = supplied
        } else {
            // Auto-derive version string from inner evaluator
            // versions for forensic audit. Format:
            //   "pipeline:<strategy>:[v1+v2+v3]"
            let parts = evaluators.map { $0.evaluatorVersion }
            self.evaluatorVersion =
                "pipeline:\(mergeStrategy.rawValue):" +
                "[\(parts.joined(separator: "+"))]"
        }
    }

    public func evaluate(
        prompt: String,
        body: String,
        prePermitMode: String,
        sessionRef: String,
        turnRef: String
    ) async -> BASShadowEvaluationResult {
        // Empty pipeline → skipped.
        guard !evaluators.isEmpty else {
            return BASShadowEvaluationResult.skipped(
                evaluatorVersion: evaluatorVersion)
        }

        // Run evaluators concurrently. Each is independent —
        // they all read the same inputs and produce independent
        // results.
        let evaluators = self.evaluators
        let results = await withTaskGroup(
            of: (Int, BASShadowEvaluationResult).self,
            returning: [BASShadowEvaluationResult].self
        ) { group in
            for (index, evaluator) in evaluators.enumerated() {
                group.addTask {
                    let result = await evaluator.evaluate(
                        prompt: prompt,
                        body: body,
                        prePermitMode: prePermitMode,
                        sessionRef: sessionRef,
                        turnRef: turnRef)
                    return (index, result)
                }
            }
            // Collect in submission order so audit trail is
            // deterministic.
            var collected: [(Int, BASShadowEvaluationResult)] =
                []
            for await pair in group {
                collected.append(pair)
            }
            collected.sort { $0.0 < $1.0 }
            return collected.map { $0.1 }
        }

        // Filter out skipped evaluators for merge.
        let nonSkipped = results.filter {
            $0.postPermitMode != nil
        }

        // All-skipped path → pipeline returns skipped.
        guard !nonSkipped.isEmpty else {
            return BASShadowEvaluationResult.skipped(
                evaluatorVersion: evaluatorVersion)
        }

        // Merge `shifted` per strategy.
        let shiftedCount = nonSkipped.filter { $0.shifted }
            .count
        let merged: Bool
        switch mergeStrategy {
        case .anyShifted:
            merged = shiftedCount > 0
        case .allShifted:
            merged = shiftedCount == nonSkipped.count
        case .majorityShifted:
            merged = shiftedCount * 2 > nonSkipped.count
        }

        // Aggregate post-permit-mode: pick the first
        // non-nil one (substrate-driven evaluators populate this;
        // ML-backed conformers may return nil but still
        // contribute to `shifted`). Audit trail records all
        // per-evaluator post-permit-modes in reason codes.
        let aggregatedPermitMode = nonSkipped.compactMap {
            $0.postPermitMode
        }.first

        let aggregatedAuditCount = nonSkipped.compactMap {
            $0.postAuditCodeCount
        }.reduce(0, +)

        // Build merged reason codes:
        //   pipeline:strategy:<strategy-raw>
        //   pipeline:non-skipped-count:<N>
        //   pipeline:shifted-count:<K>
        //   pipeline:merged-shifted:<bool>
        //   pipeline:evaluator:<index>:<version>:<shifted>:<postMode?>
        var mergedCodes: [String] = [
            "pipeline:strategy:\(mergeStrategy.rawValue)",
            "pipeline:non-skipped-count:\(nonSkipped.count)",
            "pipeline:shifted-count:\(shiftedCount)",
            "pipeline:merged-shifted:\(merged)"
        ]
        for (index, result) in results.enumerated() {
            let mode = result.postPermitMode ?? "-skipped-"
            mergedCodes.append(
                "pipeline:evaluator:\(index):" +
                "\(result.evaluatorVersion):" +
                "shifted=\(result.shifted):" +
                "post=\(mode)")
        }

        return BASShadowEvaluationResult(
            postPermitMode: aggregatedPermitMode,
            postAuditCodeCount: aggregatedAuditCount,
            shifted: merged,
            reasonCodes: mergedCodes,
            evaluatorVersion: evaluatorVersion)
    }
}
