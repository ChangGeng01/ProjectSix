import Foundation
import QinaoWorldPrior

// M287 — L9 dream cycle real-model counterfactual prompt expansion.
//
// ## Why this exists
//
// `QinaoLoop+MultiCandidateGeneration` (M100) fans out one seed
// into N variants by ID alone — every variant shares the same
// prompt and lets the organ endpoint vary sampling. That's
// useful for diversity-by-temperature, but it isn't real
// counterfactual exploration: every variant asks the LLM the
// same question.
//
// `QinaoWorldPriorVault.counterfactualBranches(for:templateID:)`
// (M84) generates the *raw material* for genuine multi-path
// reasoning: each branch carries a `perturbKind`
// (dropPrecondition / introduceBlocker / crossDomain) and a
// natural-language `description` of the perturbation. M84 wires
// those branches into post-generation contradiction refinement
// (`refineAgainstCounterfactuals`), but the dream-cycle still
// generates candidates from the original prompt only — branches
// don't reach the LLM.
//
// `expandWithCounterfactual(seed:branches:)` closes the gap at
// the prompt layer. Given one parent seed and N branches it
// returns 1 + N candidate seeds: the parent unchanged plus one
// variant per branch whose prompt is prefixed with the branch's
// perturbation directive. When passed downstream to
// `generateCandidates(sessionID:seeds:)` the LLM sees genuinely
// different prompts per variant and produces genuinely different
// completions per perturbation — real multi-path, not ID-only
// fan-out.
//
// ## Doctrine
//
// - **N=0 branches → 1 seed (parent unchanged).** No fan-out
//   unless the host has actually fetched branches from L4.
// - **Parent seed always first.** Preserves caller track-by-ID
//   for the primary candidate (mirrors M100 invariant).
// - **Variant ID grammar:** `"<parentID>#cf-<perturbKind.rawValue>-<i>"`
//   where `i` is the 1-indexed branch position in the input array.
//   Always includes the index even when only one branch of that kind
//   is present, so audit grep patterns are uniform. Stable,
//   deterministic, audit-keyable, collision-free even when the L4
//   seeder emits multiple branches of the same `perturbKind` for
//   the same template (e.g. `tmpl-body-hydration` produces 3
//   `dropPrecondition` branches at varying evidence rungs).
// - **Variant prompt grammar:**
//   `"Counterfactual perspective (<kind>): <description>\n\n<parentPrompt>"`.
//   Parent prompt kept verbatim at the end so the LLM still
//   answers the original question, just under the perturbed lens.
// - **Variant confidence demoted by branch evidence rung.** Lower
//   rung means we trust the branch less, so the variant's
//   `confidence` is reduced more aggressively. Concretely:
//   `variantConfidence = parentConfidence * (rung / 4.0)` clamped
//   to [0,1]. axiomatic(4)→1.0×, wellSupported(3)→0.75×,
//   plausible(2)→0.5×, speculative(1)→0.25×, contested(0)→0×.
// - **All other CandidateSeed fields preserved verbatim** from
//   parent. M287 is purely prompt + ID + confidence; numeric
//   risk axes unchanged.
//
// ## Pure helper
//
// No I/O, no actor hop, no LLM call. Deterministic for the same
// `(seed, branches)` pair. Unit-testable in isolation.

extension QinaoLoop {

    /// M287 — expand a parent seed into 1 + N candidate seeds: the
    /// parent unchanged followed by one variant per counterfactual
    /// branch whose prompt is prefixed with the branch's
    /// perturbation directive. See file-level doc for full
    /// doctrine.
    ///
    /// - Parameters:
    ///   - seed: the parent candidate seed.
    ///   - branches: counterfactual branches from
    ///     `QinaoWorldPriorVault.counterfactualBranches(...)`.
    ///     Empty array returns just the parent unchanged.
    /// - Returns: `1 + branches.count` candidate seeds, parent
    ///   first, variant order matching `branches` order.
    public static func expandWithCounterfactual(
        seed: CandidateSeed,
        branches: [QinaoWorldPriorCounterfactualBranch]
    ) -> [CandidateSeed] {
        guard !branches.isEmpty else {
            return [seed]
        }
        var result: [CandidateSeed] = []
        result.reserveCapacity(1 + branches.count)
        result.append(seed)
        for (idx, branch) in branches.enumerated() {
            result.append(makeCounterfactualVariant(
                parent: seed,
                branch: branch,
                branchIndex: idx + 1))
        }
        return result
    }

    /// Compose one counterfactual variant from a parent seed and
    /// a single branch. Pure helper, deterministic. `branchIndex`
    /// is 1-based and always appended to the variant ID so multiple
    /// branches of the same `perturbKind` don't collide.
    static func makeCounterfactualVariant(
        parent: CandidateSeed,
        branch: QinaoWorldPriorCounterfactualBranch,
        branchIndex: Int
    ) -> CandidateSeed {
        let kindLabel = branch.perturbKind.rawValue
        let variantID =
            "\(parent.candidateID)#cf-\(kindLabel)-\(branchIndex)"
        let variantPrompt = composeCounterfactualPrompt(
            parentPrompt: parent.prompt,
            kindLabel: kindLabel,
            description: branch.description)
        let variantConfidence = demoteConfidence(
            parentConfidence: parent.confidence,
            evidence: branch.branchEvidence)
        return CandidateSeed(
            candidateID: variantID,
            title: parent.title,
            prompt: variantPrompt,
            context: parent.context,
            role: parent.role,
            expectedBenefit: parent.expectedBenefit,
            expectedCost: parent.expectedCost,
            reversibility: parent.reversibility,
            confidence: variantConfidence,
            evidenceGap: parent.evidenceGap,
            manipulationRisk: parent.manipulationRisk,
            emotionalBias: parent.emotionalBias,
            boundaryConflict: parent.boundaryConflict,
            worldPriorClaim: parent.worldPriorClaim)
    }

    /// Compose the variant prompt by prefixing the parent prompt
    /// with the perturbation directive. Stable, UI-keyable.
    static func composeCounterfactualPrompt(
        parentPrompt: String,
        kindLabel: String,
        description: String
    ) -> String {
        "Counterfactual perspective (\(kindLabel)): "
            + description + "\n\n" + parentPrompt
    }

    /// Demote parent confidence by branch evidence rung. Lower
    /// rung → larger demotion. Output clamped to [0,1].
    static func demoteConfidence(
        parentConfidence: Double,
        evidence: QinaoWorldPriorEvidenceLevel
    ) -> Double {
        let factor = Double(evidence.rank) / 4.0
        let demoted = parentConfidence * factor
        return min(max(demoted, 0.0), 1.0)
    }
}
