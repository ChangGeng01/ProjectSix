import XCTest
@testable import BASOrchestration

/// M52 — L9 dream-loop frontier main-chain wiring.
///
/// The M24 per-candidate observation primitives (shape covered by
/// `BASCandidateObservationTests`) were originally emitted only by
/// hand-crafted test helpers; the real materialization path didn't
/// produce a bundle at all. These tests pin the main-chain behavior:
///
///   1. `materializeThoughtArtifacts` emits a bundle whenever the
///      frontier is non-nil (coherent pair by construction).
///   2. The bundle's observations mirror the frontier's decisions —
///      anything the frontier asserted must appear as an observation.
///   3. `hasCoreSignalCoverage` is true for non-degenerate turns, so
///      the M32 coverage projection receives real L9 data rather
///      than a test-only sidecar.
///   4. Budget stays clamped in [0, 1] under every realistic bundle
///      size.
///   5. Turn + session IDs are stamped so the L14 audit surface can
///      correlate bundles with the frontier.
final class BASCandidateObservationMaterializationTests: XCTestCase {

    // MARK: - Fixtures

    /// Canonical candidate with customizable knobs. Defaults yield
    /// a "reversible + guard" candidate that the frontier picks up
    /// on both dimensions.
    private func candidate(
        id: String,
        benefit: Double = 0.7,
        cost: Double = 0.2,
        reversibility: Double = 0.75,
        confidence: Double = 0.7,
        title: String = "candidate",
        summary: String = "do a bounded reversible thing",
        evidence: [String] = []
    ) -> BASCandidatePath {
        BASCandidatePath(
            candidateID: id,
            title: title,
            actionSummary: summary,
            requiredEvidence: evidence,
            expectedBenefit: benefit,
            expectedCost: cost,
            reversibility: reversibility,
            confidence: confidence)
    }

    private func frame(
        candidates: [BASCandidatePath],
        stepIndex: Int = 3,
        decomposeRef: String = "decomp-m52",
        forecasts: [BASForecastItem] = [],
        critiques: [BASCritiqueItem] = []
    ) -> BASThoughtFrame {
        BASThoughtFrame(
            stepIndex: stepIndex,
            decomposeRef: decomposeRef,
            candidates: candidates,
            forecasts: forecasts,
            critiques: critiques)
    }

    // MARK: - 1. Emission

    func testMaterializationEmitsBundleWhenCandidatesPresent() {
        let frame = frame(candidates: [
            candidate(id: "a"),
            candidate(id: "b", reversibility: 0.3, confidence: 0.4)
        ])

        let art = BASNeuralMaterializationCompiler
            .materializeThoughtArtifacts(thoughtFrame: frame)

        XCTAssertNotNil(art.candidateFrontier)
        XCTAssertNotNil(art.candidateObservationBundle)
        XCTAssertFalse(
            art.candidateObservationBundle?.observations.isEmpty
                ?? true)
    }

    func testEmptyCandidatesYieldNilBundleAndNilFrontier() {
        let frame = frame(candidates: [])
        let art = BASNeuralMaterializationCompiler
            .materializeThoughtArtifacts(thoughtFrame: frame)

        XCTAssertNil(art.candidateFrontier)
        XCTAssertNil(art.candidateObservationBundle)
    }

    // MARK: - 2. Bundle mirrors frontier decisions

    func testBundleEmitsOneCandidateObservationPerCandidate() {
        let cands = [
            candidate(id: "a"),
            candidate(id: "b"),
            candidate(id: "c")
        ]
        let art = BASNeuralMaterializationCompiler
            .materializeThoughtArtifacts(
                thoughtFrame: frame(candidates: cands))

        let bundle = try? XCTUnwrap(art.candidateObservationBundle)
        let candObs = bundle?.observations(of: .candidate) ?? []
        XCTAssertEqual(
            Set(candObs.map(\.candidateID)),
            Set(cands.map(\.candidateID)))
        XCTAssertEqual(candObs.count, cands.count)
    }

    func testDominanceObservationsMirrorFrontierOrder() throws {
        // Benefit dominates the dominance score; rank should be
        // a > b > c. Reversibility equal so no tie-breaker noise.
        let cands = [
            candidate(id: "c", benefit: 0.3),
            candidate(id: "a", benefit: 0.9),
            candidate(id: "b", benefit: 0.6)
        ]
        let art = BASNeuralMaterializationCompiler
            .materializeThoughtArtifacts(
                thoughtFrame: frame(candidates: cands))

        let frontier = try XCTUnwrap(art.candidateFrontier)
        let bundle = try XCTUnwrap(art.candidateObservationBundle)
        let domObs = bundle.observations(of: .dominanceSignal)
            .sorted { $0.salience > $1.salience }
        XCTAssertEqual(
            domObs.map(\.candidateID),
            frontier.dominanceOrder)
    }

    func testReversibilityObservationsMirrorFrontier() throws {
        let cands = [
            candidate(id: "rev", reversibility: 0.8),
            candidate(id: "low", reversibility: 0.2)
        ]
        let art = BASNeuralMaterializationCompiler
            .materializeThoughtArtifacts(
                thoughtFrame: frame(candidates: cands))

        let frontier = try XCTUnwrap(art.candidateFrontier)
        let bundle = try XCTUnwrap(art.candidateObservationBundle)
        let revIDs = bundle.observations(of: .reversibilitySignal)
            .map(\.candidateID)
        XCTAssertEqual(Set(revIDs), Set(frontier.reversiblePaths))
        XCTAssertTrue(revIDs.contains("rev"))
        XCTAssertFalse(revIDs.contains("low"))
    }

    func testGuardianBranchObservationsMirrorFrontier() throws {
        let cands = [
            candidate(
                id: "hi-rev",
                reversibility: 0.85,
                title: "run",
                summary: "execute a fast path"),
            // guard via reversibility
            candidate(
                id: "lexicon",
                reversibility: 0.3,
                title: "pause and review",
                summary: "hold the call for a beat"),
            // guard via lexicon (title)
            candidate(
                id: "plain",
                reversibility: 0.5,
                title: "normal",
                summary: "execute quickly")
            // neither reversibility >= 0.7 nor any guard-lexicon
            // token — must NOT land in guardPaths.
        ]
        let art = BASNeuralMaterializationCompiler
            .materializeThoughtArtifacts(
                thoughtFrame: frame(candidates: cands))

        let frontier = try XCTUnwrap(art.candidateFrontier)
        let bundle = try XCTUnwrap(art.candidateObservationBundle)
        let guardIDs = bundle.observations(of: .guardianBranch)
            .map(\.candidateID)
        XCTAssertEqual(Set(guardIDs), Set(frontier.guardPaths))
        XCTAssertTrue(guardIDs.contains("hi-rev"))
        XCTAssertTrue(guardIDs.contains("lexicon"))
        XCTAssertFalse(guardIDs.contains("plain"))
    }

    func testDelayRecommendationsMirrorFrontier() throws {
        // A candidate whose summary contains "verify" triggers the
        // delayed-path heuristic.
        let cands = [
            candidate(
                id: "delay",
                summary: "verify the claim before acting"),
            candidate(
                id: "run",
                summary: "do the thing now")
        ]
        let art = BASNeuralMaterializationCompiler
            .materializeThoughtArtifacts(
                thoughtFrame: frame(candidates: cands))

        let frontier = try XCTUnwrap(art.candidateFrontier)
        let bundle = try XCTUnwrap(art.candidateObservationBundle)
        let delayIDs = bundle
            .observations(of: .delayRecommendation)
            .map(\.candidateID)
        XCTAssertEqual(Set(delayIDs), Set(frontier.delayedPaths))
        XCTAssertTrue(delayIDs.contains("delay"))
        XCTAssertFalse(delayIDs.contains("run"))
    }

    func testDiversityObservationCarriesFrontierScore() throws {
        let cands = [
            candidate(
                id: "a",
                title: "option alpha",
                summary: "path alpha"),
            candidate(
                id: "b",
                title: "option beta",
                summary: "path beta",
                evidence: ["cite-1"])
        ]
        let art = BASNeuralMaterializationCompiler
            .materializeThoughtArtifacts(
                thoughtFrame: frame(candidates: cands))

        let frontier = try XCTUnwrap(art.candidateFrontier)
        let bundle = try XCTUnwrap(art.candidateObservationBundle)
        let diversity = bundle.observations(of: .diversitySignal)
        XCTAssertEqual(diversity.count, 1)
        let obs = try XCTUnwrap(diversity.first)
        XCTAssertEqual(obs.salience, frontier.diversityScore)
        XCTAssertEqual(obs.candidateID, frontier.dominanceOrder.first)
    }

    // MARK: - 3. Core coverage

    func testBundleHasCoreSignalCoverageForGuardCandidate() throws {
        // .candidate + .reversibilitySignal + .guardianBranch are
        // the three core signals. A single reversible-enough
        // candidate covers all three.
        let art = BASNeuralMaterializationCompiler
            .materializeThoughtArtifacts(
                thoughtFrame: frame(candidates: [
                    candidate(id: "x", reversibility: 0.8)
                ]))

        let bundle = try XCTUnwrap(art.candidateObservationBundle)
        XCTAssertTrue(bundle.hasCoreSignalCoverage)
    }

    func testBundleMissesCoreCoverageWhenGuardPathAbsent() throws {
        // Low reversibility + neutral copy → no reversibility obs
        // and no guardianBranch obs. Core coverage should be false.
        let art = BASNeuralMaterializationCompiler
            .materializeThoughtArtifacts(
                thoughtFrame: frame(candidates: [
                    candidate(
                        id: "only-low",
                        reversibility: 0.2,
                        title: "plain",
                        summary: "plain action")
                ]))

        let bundle = try XCTUnwrap(art.candidateObservationBundle)
        XCTAssertFalse(bundle.hasCoreSignalCoverage)
    }

    // MARK: - 4. Budget clamping

    func testBundleBudgetStaysClampedWithManyCandidates() throws {
        let many = (0..<20).map {
            candidate(
                id: "c\($0)",
                reversibility: 0.85,
                title: "pause and review",  // force guard path
                summary: "verify and wait before acting")
        }
        let art = BASNeuralMaterializationCompiler
            .materializeThoughtArtifacts(
                thoughtFrame: frame(candidates: many))

        let bundle = try XCTUnwrap(art.candidateObservationBundle)
        let cost = BASCandidateObservationBudget
            .totalCost(for: bundle)
        XCTAssertGreaterThanOrEqual(cost, 0)
        XCTAssertLessThanOrEqual(cost, 1)
    }

    // MARK: - 5. Turn + session stamping

    func testBundleStampsTurnAndSessionFromThoughtFrame() throws {
        let art = BASNeuralMaterializationCompiler
            .materializeThoughtArtifacts(
                thoughtFrame: frame(
                    candidates: [candidate(id: "x")],
                    stepIndex: 42,
                    decomposeRef: "decomp-xyz"))

        let bundle = try XCTUnwrap(art.candidateObservationBundle)
        XCTAssertEqual(bundle.turnID, "l9.turn.step-42")
        XCTAssertEqual(bundle.sessionID, "decomp-xyz")
    }

    // MARK: - 6. Coverage projection integration

    func testMaterializedBundleFeedsM32CoverageProjection()
        throws
    {
        let art = BASNeuralMaterializationCompiler
            .materializeThoughtArtifacts(
                thoughtFrame: frame(candidates: [
                    candidate(id: "a", reversibility: 0.8),
                    candidate(id: "b", reversibility: 0.75)
                ]))

        let bundle = try XCTUnwrap(art.candidateObservationBundle)
        let summary = bundle.coverageSummary
        XCTAssertEqual(summary.layer, .dreamLoop)
        XCTAssertEqual(summary.distinctSubjectCount, 2)
        XCTAssertTrue(summary.hasCoreSignalCoverage)
    }

    // MARK: - 7. Backwards-compatibility

    func testDefaultMaterializationInitStillAcceptsNoBundle() {
        // Ensures the additive field defaults so pre-M52 call sites
        // that construct a BASNeuralThoughtMaterialization by hand
        // (e.g. the two test call sites in BASEBrainSchemaCoreTests)
        // continue to compile without changes.
        let art = BASNeuralThoughtMaterialization(
            candidateFrontier: nil,
            counterfactualBundles: nil,
            critiqueBundles: nil,
            uncertaintyLedger: nil,
            evidenceDebts: nil,
            convergenceCertificate: nil,
            loopLeaseReceipt: nil,
            sovereignBreakpointHints: nil)
        XCTAssertNil(art.candidateObservationBundle)
    }
}
