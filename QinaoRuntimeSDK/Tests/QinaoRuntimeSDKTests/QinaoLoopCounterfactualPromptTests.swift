import XCTest
@testable import QinaoLoop
import QinaoWorldPrior

/// M287 — L9 dream cycle real-model counterfactual prompt 接入
/// (helper layer).
///
/// `QinaoLoop.expandWithCounterfactual(seed:branches:)` is a pure
/// deterministic helper that takes one parent seed and N
/// counterfactual branches and returns 1 + N candidate seeds: the
/// original seed unchanged plus one variant per branch whose prompt
/// is prefixed with that branch's perturbation directive.
///
/// Doctrine pinned by these tests:
/// - N=0 branches → 1 seed (parent unchanged) — no fan-out unless
///   asked
/// - N≥1 branches → 1 + N seeds (parent first, variant order
///   matches input)
/// - Variant ID grammar: `"<parentID>#cf-<perturbKind.rawValue>-<i>"`
///   (1-indexed; always present, collision-free under same-kind repeats)
/// - Variant prompt grammar:
///   `"Counterfactual perspective (<kind>): <description>\n\n<parentPrompt>"`
/// - Variant confidence demoted by branch evidence rung
///   (axiomatic→×1.0 … contested→×0.0)
/// - All other `CandidateSeed` fields preserved verbatim from
///   parent
/// - Same inputs → same outputs (pure deterministic)
final class QinaoLoopCounterfactualPromptTests: XCTestCase {

    // MARK: - Fixtures

    private func makeParentSeed() -> QinaoLoop.CandidateSeed {
        QinaoLoop.CandidateSeed(
            candidateID: "plan-A",
            title: "Original plan",
            prompt: "Decide whether to send the message now.",
            context: ["recent message tone is sharp"],
            role: .core,
            expectedBenefit: 0.6,
            expectedCost: 0.4,
            reversibility: 0.7,
            confidence: 0.8,
            evidenceGap: 0.2,
            manipulationRisk: 0.1,
            emotionalBias: 0.5,
            boundaryConflict: 0.2,
            worldPriorClaim: nil)
    }

    private func makeBranch(
        kind: QinaoWorldPriorPerturbKind,
        description: String,
        evidence: QinaoWorldPriorEvidenceLevel = .plausible,
        templateID: String = "tmpl-relationship-conflict"
    ) -> QinaoWorldPriorCounterfactualBranch {
        QinaoWorldPriorCounterfactualBranch(
            seedTemplateID: templateID,
            perturbKind: kind,
            description: description,
            branchEvidence: evidence,
            bridgeID: kind == .crossDomain
                ? "bridge-mood-finance" : nil)
    }

    // MARK: - Tests

    func test_emptyBranches_returnsParentSeedUnchanged() {
        let parent = makeParentSeed()
        let result = QinaoLoop.expandWithCounterfactual(
            seed: parent, branches: [])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0], parent)
    }

    func test_threeBranches_returnsFourSeedsParentFirst() {
        let parent = makeParentSeed()
        let branches = [
            makeBranch(
                kind: .dropPrecondition,
                description: "Suppose tone wasn't sharp"),
            makeBranch(
                kind: .introduceBlocker,
                description: "Suppose recipient is asleep"),
            makeBranch(
                kind: .crossDomain,
                description: "If this were a financial decision"),
        ]
        let result = QinaoLoop.expandWithCounterfactual(
            seed: parent, branches: branches)
        XCTAssertEqual(result.count, 4)
        XCTAssertEqual(result[0].candidateID, "plan-A")
        XCTAssertEqual(result[0].prompt, parent.prompt)
    }

    func test_variantIDGrammar() {
        let parent = makeParentSeed()
        let branches = [
            makeBranch(kind: .dropPrecondition, description: "x"),
            makeBranch(kind: .introduceBlocker, description: "y"),
            makeBranch(kind: .crossDomain, description: "z"),
        ]
        let result = QinaoLoop.expandWithCounterfactual(
            seed: parent, branches: branches)
        XCTAssertEqual(
            result[1].candidateID, "plan-A#cf-dropPrecondition-1")
        XCTAssertEqual(
            result[2].candidateID, "plan-A#cf-introduceBlocker-2")
        XCTAssertEqual(
            result[3].candidateID, "plan-A#cf-crossDomain-3")
    }

    func test_sameKindBranches_yieldUniqueIDs() {
        // Mirrors `tmpl-body-hydration`'s seeded shape: 3 branches
        // all of kind `.dropPrecondition`. M288 surfaced this as an
        // ID collision before M287's grammar got the 1-indexed
        // suffix; pinning here so that regression can never recur.
        let parent = makeParentSeed()
        let branches = [
            makeBranch(
                kind: .dropPrecondition,
                description: "drop A",
                evidence: .plausible),
            makeBranch(
                kind: .dropPrecondition,
                description: "drop B",
                evidence: .speculative),
            makeBranch(
                kind: .dropPrecondition,
                description: "drop C",
                evidence: .speculative),
        ]
        let result = QinaoLoop.expandWithCounterfactual(
            seed: parent, branches: branches)
        XCTAssertEqual(result.count, 4)
        let ids = result.map(\.candidateID)
        // All variant IDs unique (1 + 3 = 4 unique).
        XCTAssertEqual(Set(ids).count, 4)
        XCTAssertEqual(
            result[1].candidateID, "plan-A#cf-dropPrecondition-1")
        XCTAssertEqual(
            result[2].candidateID, "plan-A#cf-dropPrecondition-2")
        XCTAssertEqual(
            result[3].candidateID, "plan-A#cf-dropPrecondition-3")
    }

    func test_variantPromptInjection() {
        let parent = makeParentSeed()
        let branch = makeBranch(
            kind: .dropPrecondition,
            description: "Suppose the precondition no longer holds")
        let result = QinaoLoop.expandWithCounterfactual(
            seed: parent, branches: [branch])
        XCTAssertEqual(result.count, 2)
        let variantPrompt = result[1].prompt
        XCTAssertTrue(variantPrompt.contains(
            "Counterfactual perspective (dropPrecondition):"))
        XCTAssertTrue(variantPrompt.contains(
            "Suppose the precondition no longer holds"))
        XCTAssertTrue(variantPrompt.hasSuffix(parent.prompt))
    }

    func test_variantConfidenceDemotedByEvidenceRung() {
        let parent = makeParentSeed() // confidence = 0.8
        let speculative = makeBranch(
            kind: .crossDomain,
            description: "x",
            evidence: .speculative) // rank 1
        let plausible = makeBranch(
            kind: .dropPrecondition,
            description: "y",
            evidence: .plausible) // rank 2
        let wellSupported = makeBranch(
            kind: .introduceBlocker,
            description: "z",
            evidence: .wellSupported) // rank 3

        let result = QinaoLoop.expandWithCounterfactual(
            seed: parent,
            branches: [speculative, plausible, wellSupported])

        let specConf = result[1].confidence
        let plausConf = result[2].confidence
        let wellConf = result[3].confidence
        XCTAssertLessThan(specConf, plausConf)
        XCTAssertLessThan(plausConf, wellConf)
        XCTAssertLessThan(wellConf, parent.confidence)
    }

    func test_axiomaticBranchPreservesParentConfidence() {
        let parent = makeParentSeed() // confidence = 0.8
        let axiom = makeBranch(
            kind: .dropPrecondition,
            description: "x",
            evidence: .axiomatic) // rank 4 → factor 1.0
        let result = QinaoLoop.expandWithCounterfactual(
            seed: parent, branches: [axiom])
        XCTAssertEqual(
            result[1].confidence, parent.confidence, accuracy: 1e-9)
    }

    func test_contestedBranchZeroesConfidence() {
        let parent = makeParentSeed() // confidence = 0.8
        let contested = makeBranch(
            kind: .crossDomain,
            description: "x",
            evidence: .contested) // rank 0 → factor 0.0
        let result = QinaoLoop.expandWithCounterfactual(
            seed: parent, branches: [contested])
        XCTAssertEqual(result[1].confidence, 0.0, accuracy: 1e-9)
    }

    func test_otherFieldsPreservedFromParent() {
        let parent = makeParentSeed()
        let branch = makeBranch(
            kind: .introduceBlocker, description: "x")
        let result = QinaoLoop.expandWithCounterfactual(
            seed: parent, branches: [branch])
        let variant = result[1]
        XCTAssertEqual(variant.title, parent.title)
        XCTAssertEqual(variant.context, parent.context)
        XCTAssertEqual(variant.role, parent.role)
        XCTAssertEqual(
            variant.expectedBenefit, parent.expectedBenefit)
        XCTAssertEqual(variant.expectedCost, parent.expectedCost)
        XCTAssertEqual(variant.reversibility, parent.reversibility)
        XCTAssertEqual(variant.evidenceGap, parent.evidenceGap)
        XCTAssertEqual(
            variant.manipulationRisk, parent.manipulationRisk)
        XCTAssertEqual(variant.emotionalBias, parent.emotionalBias)
        XCTAssertEqual(
            variant.boundaryConflict, parent.boundaryConflict)
        XCTAssertEqual(
            variant.worldPriorClaim, parent.worldPriorClaim)
    }

    func test_pureDeterministic_sameInputsSameOutputs() {
        let parent = makeParentSeed()
        let branches = [
            makeBranch(kind: .dropPrecondition, description: "x"),
            makeBranch(kind: .crossDomain, description: "y"),
        ]
        let r1 = QinaoLoop.expandWithCounterfactual(
            seed: parent, branches: branches)
        let r2 = QinaoLoop.expandWithCounterfactual(
            seed: parent, branches: branches)
        XCTAssertEqual(r1, r2)
    }
}
