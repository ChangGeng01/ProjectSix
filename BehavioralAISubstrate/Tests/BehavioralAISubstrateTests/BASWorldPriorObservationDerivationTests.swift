import XCTest
@testable import BASOrchestration
@testable import BASWorldPrior

/// M59 — L4 world-prior main-chain wiring.
///
/// Before M59 the `BASWorldPriorObservation{,Bundle}` primitives
/// (M30) existed, but the BAS coordinator never emitted a bundle on
/// the main-chain thought frame. The L14 audit surface could verify
/// "what L4 said about template T" only by reading the vault, never
/// by reading a per-turn record. These tests pin the main-chain
/// behavior:
///
///   1. `BASWorldPriorObservationBundle.derive(
///        fromThoughtFrame:turnID:sessionID:emittedAt:)` emits a
///      bundle whose contents deterministically mirror the input
///      frame (same inputs → same bundle byte-for-byte).
///   2. Two disjoint paths route the derivation — primary
///      (frame has candidates) and empty (frame has no candidates).
///      The empty path is the legitimate "no-L4-turn" signal and
///      correctly yields `hasCoreSignalCoverage == false` + zero
///      observations.
///   3. Each of the six signal kinds (.templateMatched /
///      .counterfactualSeeded / .domainBridgeCrossed /
///      .boundaryBedrockConsulted / .evidenceRevised /
///      .priorContradiction) is emitted iff the structural
///      precondition holds; no ghost signals.
///   4. `BASThoughtFrame.withDerivedWorldPriorObservationBundle(
///      turnID:sessionID:emittedAt:)` returns a copy with the
///      bundle attached and leaves every other field untouched.
///   5. The bundle feeds the M32 L4 coverage projection
///      (`hasCoreSignalCoverage` == has `.templateMatched` AND
///      (`.counterfactualSeeded` OR `.boundaryBedrockConsulted`);
///      `templateIDs` == distinct template IDs first-seen).
///   6. Budget stays clamped in [0, 1] even when many signals fire.
final class BASWorldPriorObservationDerivationTests: XCTestCase {

    // MARK: - Fixtures

    private let fixedDate = Date(timeIntervalSince1970: 1_000_000)
    private let turnID = "t-abc"
    private let sessionID = "s-xyz"

    private func candidate(
        id: String = "cand-1",
        confidence: Double = 0.7
    ) -> BASCandidatePath {
        BASCandidatePath(
            candidateID: id,
            title: "t-\(id)",
            actionSummary: "summary",
            expectedBenefit: 0.6,
            expectedCost: 0.3,
            reversibility: 0.8,
            confidence: confidence
        )
    }

    private func counterfactualBundle(
        candidateID: String = "cand-1",
        uncertainty: Double = 0.3,
        affectedDomains: [String] = ["physical"]
    ) -> BASCounterfactualBundle {
        BASCounterfactualBundle(
            candidateID: candidateID,
            shortTerm: "short",
            midTerm: "mid",
            worstCase: "worst",
            uncertainty: uncertainty,
            affectedDomains: affectedDomains
        )
    }

    private func critiqueBundle(
        candidateID: String = "cand-1",
        evidenceGap: Double = 0.2,
        manipulationRisk: Double = 0.2,
        emotionalBias: Double = 0.2,
        boundaryConflict: Double = 0.2,
        critiqueStrength: Double = 0.4
    ) -> BASCritiqueBundle {
        BASCritiqueBundle(
            candidateID: candidateID,
            evidenceGap: evidenceGap,
            manipulationRisk: manipulationRisk,
            emotionalBias: emotionalBias,
            boundaryConflict: boundaryConflict,
            critiqueStrength: critiqueStrength
        )
    }

    private func uncertaintyLedger(
        ledgerID: String = "ul-1",
        weakPredictions: [String] = [],
        confidenceFloor: Double = 0.6
    ) -> BASUncertaintyLedger {
        BASUncertaintyLedger(
            ledgerID: ledgerID,
            weakPredictions: weakPredictions,
            confidenceFloor: confidenceFloor
        )
    }

    private func thoughtFrame(
        candidates: [BASCandidatePath] = [],
        counterfactualBundles: [BASCounterfactualBundle]? = nil,
        critiqueBundles: [BASCritiqueBundle]? = nil,
        uncertaintyLedger: BASUncertaintyLedger? = nil
    ) -> BASThoughtFrame {
        BASThoughtFrame(
            stepIndex: 1,
            decomposeRef: "d-1",
            candidates: candidates,
            counterfactualBundles: counterfactualBundles,
            critiqueBundles: critiqueBundles,
            uncertaintyLedger: uncertaintyLedger,
            stabilityScore: 0.5
        )
    }

    // MARK: - Empty path

    func testEmptyFrameYieldsEmptyBundle() {
        let frame = thoughtFrame(candidates: [])
        let bundle = BASWorldPriorObservationBundle.derive(
            fromThoughtFrame: frame,
            turnID: turnID,
            sessionID: sessionID,
            emittedAt: fixedDate)
        XCTAssertEqual(bundle.turnID, turnID)
        XCTAssertEqual(bundle.sessionID, sessionID)
        XCTAssertEqual(bundle.emittedAt, fixedDate)
        XCTAssertTrue(bundle.observations.isEmpty)
        XCTAssertFalse(bundle.hasCoreSignalCoverage)
        XCTAssertEqual(bundle.templateIDs, [])
    }

    func testEmptyFrameIsValidNotCoverageGap() {
        // Plain signal that "no candidates" is legitimate — the L14
        // audit surface should not treat this as an L4 gap.
        let frame = thoughtFrame()
        let bundle = BASWorldPriorObservationBundle.derive(
            fromThoughtFrame: frame,
            turnID: turnID,
            sessionID: sessionID,
            emittedAt: fixedDate)
        let summary = bundle.coverageSummary
        XCTAssertEqual(summary.totalObservations, 0)
        XCTAssertFalse(summary.hasCoreSignalCoverage)
        XCTAssertEqual(summary.distinctSubjectCount, 0)
        XCTAssertEqual(summary.budgetTotalCost, 0.0, accuracy: 1e-9)
    }

    // MARK: - Primary path: templateMatched

    func testCandidatesEmitTemplateMatched() {
        let frame = thoughtFrame(
            candidates: [
                candidate(id: "cand-1", confidence: 0.9),
                candidate(id: "cand-2", confidence: 0.4)
            ]
        )
        let bundle = BASWorldPriorObservationBundle.derive(
            fromThoughtFrame: frame,
            turnID: turnID,
            sessionID: sessionID,
            emittedAt: fixedDate)
        let tm = bundle.observations(of: .templateMatched)
        XCTAssertEqual(tm.count, 2)
        XCTAssertEqual(
            tm[0].templateID,
            "l4.template.candidate:cand-1")
        XCTAssertEqual(tm[0].evidenceLevel, .wellSupported)
        XCTAssertEqual(
            tm[1].templateID,
            "l4.template.candidate:cand-2")
        XCTAssertEqual(tm[1].evidenceLevel, .speculative)
    }

    func testTemplateMatchedOnlyIsNotCoreCoverage() {
        // templateMatched alone is insufficient — needs
        // counterfactualSeeded OR boundaryBedrockConsulted.
        let frame = thoughtFrame(
            candidates: [candidate()]
        )
        let bundle = BASWorldPriorObservationBundle.derive(
            fromThoughtFrame: frame,
            turnID: turnID,
            sessionID: sessionID,
            emittedAt: fixedDate)
        XCTAssertFalse(bundle.hasCoreSignalCoverage)
    }

    // MARK: - Primary path: counterfactualSeeded

    func testCounterfactualEmitsSeededSignal() {
        let frame = thoughtFrame(
            candidates: [candidate()],
            counterfactualBundles: [
                counterfactualBundle(
                    candidateID: "cand-1",
                    uncertainty: 0.1,
                    affectedDomains: ["physical"])
            ]
        )
        let bundle = BASWorldPriorObservationBundle.derive(
            fromThoughtFrame: frame,
            turnID: turnID,
            sessionID: sessionID,
            emittedAt: fixedDate)
        let cf = bundle.observations(of: .counterfactualSeeded)
        XCTAssertEqual(cf.count, 1)
        XCTAssertEqual(
            cf[0].templateID,
            "l4.counterfactual.domain:physical")
        // uncertainty 0.1 → confidence 0.9 → .wellSupported
        XCTAssertEqual(cf[0].evidenceLevel, .wellSupported)
        XCTAssertTrue(bundle.hasCoreSignalCoverage)
    }

    func testCounterfactualWithoutDomainDefaultsToUnknown() {
        let frame = thoughtFrame(
            candidates: [candidate()],
            counterfactualBundles: [
                counterfactualBundle(
                    candidateID: "cand-1",
                    uncertainty: 0.5,
                    affectedDomains: [])
            ]
        )
        let bundle = BASWorldPriorObservationBundle.derive(
            fromThoughtFrame: frame,
            turnID: turnID,
            sessionID: sessionID,
            emittedAt: fixedDate)
        let cf = bundle.observations(of: .counterfactualSeeded)
        XCTAssertEqual(
            cf.first?.templateID,
            "l4.counterfactual.domain:unknown")
    }

    // MARK: - Primary path: domainBridgeCrossed

    func testMultipleDomainsEmitBridge() {
        let frame = thoughtFrame(
            candidates: [candidate()],
            counterfactualBundles: [
                counterfactualBundle(
                    candidateID: "cand-1",
                    uncertainty: 0.2,
                    affectedDomains: ["physical", "social"])
            ]
        )
        let bundle = BASWorldPriorObservationBundle.derive(
            fromThoughtFrame: frame,
            turnID: turnID,
            sessionID: sessionID,
            emittedAt: fixedDate)
        let bridges = bundle.observations(of: .domainBridgeCrossed)
        XCTAssertEqual(bridges.count, 1)
        XCTAssertEqual(
            bridges[0].templateID,
            "l4.bridge.domains:physical-social")
    }

    func testSingleDomainDoesNotEmitBridge() {
        let frame = thoughtFrame(
            candidates: [candidate()],
            counterfactualBundles: [
                counterfactualBundle(affectedDomains: ["physical"])
            ]
        )
        let bundle = BASWorldPriorObservationBundle.derive(
            fromThoughtFrame: frame,
            turnID: turnID,
            sessionID: sessionID,
            emittedAt: fixedDate)
        XCTAssertTrue(
            bundle.observations(of: .domainBridgeCrossed).isEmpty)
    }

    // MARK: - Primary path: boundaryBedrockConsulted

    func testHighBoundaryConflictEmitsBedrockConsulted() {
        let frame = thoughtFrame(
            candidates: [candidate()],
            critiqueBundles: [
                critiqueBundle(
                    candidateID: "cand-1",
                    boundaryConflict: 0.7,
                    critiqueStrength: 0.6)
            ]
        )
        let bundle = BASWorldPriorObservationBundle.derive(
            fromThoughtFrame: frame,
            turnID: turnID,
            sessionID: sessionID,
            emittedAt: fixedDate)
        let br = bundle.observations(
            of: .boundaryBedrockConsulted)
        XCTAssertEqual(br.count, 1)
        XCTAssertEqual(br[0].evidenceLevel, .axiomatic)
        XCTAssertTrue(bundle.hasCoreSignalCoverage)
    }

    func testLowBoundaryConflictDoesNotEmit() {
        let frame = thoughtFrame(
            candidates: [candidate()],
            critiqueBundles: [
                critiqueBundle(boundaryConflict: 0.2)
            ]
        )
        let bundle = BASWorldPriorObservationBundle.derive(
            fromThoughtFrame: frame,
            turnID: turnID,
            sessionID: sessionID,
            emittedAt: fixedDate)
        XCTAssertTrue(
            bundle
                .observations(of: .boundaryBedrockConsulted)
                .isEmpty)
    }

    // MARK: - Primary path: evidenceRevised

    func testHighEvidenceGapEmitsRevised() {
        let frame = thoughtFrame(
            candidates: [candidate()],
            critiqueBundles: [
                critiqueBundle(evidenceGap: 0.6)
            ]
        )
        let bundle = BASWorldPriorObservationBundle.derive(
            fromThoughtFrame: frame,
            turnID: turnID,
            sessionID: sessionID,
            emittedAt: fixedDate)
        let er = bundle.observations(of: .evidenceRevised)
        XCTAssertEqual(er.count, 1)
        XCTAssertEqual(er[0].evidenceLevel, .speculative)
    }

    func testLedgerWeakPredictionsEmitRevised() {
        let frame = thoughtFrame(
            candidates: [candidate()],
            uncertaintyLedger: uncertaintyLedger(
                ledgerID: "ul-a",
                weakPredictions: ["p1", "p2", "p3"],
                confidenceFloor: 0.4)
        )
        let bundle = BASWorldPriorObservationBundle.derive(
            fromThoughtFrame: frame,
            turnID: turnID,
            sessionID: sessionID,
            emittedAt: fixedDate)
        let er = bundle.observations(of: .evidenceRevised)
        XCTAssertEqual(er.count, 3)
        XCTAssertEqual(
            er[0].templateID,
            "l4.evidence.ledger:ul-a.prediction:0")
        XCTAssertEqual(
            er[2].templateID,
            "l4.evidence.ledger:ul-a.prediction:2")
    }

    // MARK: - Primary path: priorContradiction

    func testAxiomaticCollisionEmitsPriorContradiction() {
        let frame = thoughtFrame(
            candidates: [candidate()],
            critiqueBundles: [
                critiqueBundle(
                    candidateID: "cand-1",
                    boundaryConflict: 0.9,
                    critiqueStrength: 0.95)
            ]
        )
        let bundle = BASWorldPriorObservationBundle.derive(
            fromThoughtFrame: frame,
            turnID: turnID,
            sessionID: sessionID,
            emittedAt: fixedDate)
        let pc = bundle.observations(of: .priorContradiction)
        XCTAssertEqual(pc.count, 1)
        XCTAssertEqual(pc[0].salience, 1.0, accuracy: 1e-9)
        XCTAssertEqual(pc[0].confidence, 1.0, accuracy: 1e-9)
        XCTAssertEqual(pc[0].evidenceLevel, .axiomatic)
        XCTAssertTrue(
            bundle.priorContradiction(
                forTemplate:
                    "l4.contradiction.candidate:cand-1"))
    }

    func testHighBoundaryAloneDoesNotEmitContradiction() {
        let frame = thoughtFrame(
            candidates: [candidate()],
            critiqueBundles: [
                critiqueBundle(
                    candidateID: "cand-1",
                    boundaryConflict: 0.9,
                    critiqueStrength: 0.5)
            ]
        )
        let bundle = BASWorldPriorObservationBundle.derive(
            fromThoughtFrame: frame,
            turnID: turnID,
            sessionID: sessionID,
            emittedAt: fixedDate)
        XCTAssertTrue(
            bundle
                .observations(of: .priorContradiction)
                .isEmpty)
    }

    // MARK: - Frame helper

    func testWithDerivedAttachesBundleAndPreservesFields() {
        let original = thoughtFrame(
            candidates: [candidate()],
            counterfactualBundles: [counterfactualBundle()]
        )
        let withBundle = original
            .withDerivedWorldPriorObservationBundle(
                turnID: turnID,
                sessionID: sessionID,
                emittedAt: fixedDate)
        XCTAssertNotNil(withBundle.worldPriorObservationBundle)
        XCTAssertEqual(
            withBundle.worldPriorObservationBundle?.turnID,
            turnID)
        XCTAssertEqual(
            withBundle.worldPriorObservationBundle?.sessionID,
            sessionID)
        // Stepindex / decomposeRef / stabilityScore preserved.
        XCTAssertEqual(withBundle.stepIndex, original.stepIndex)
        XCTAssertEqual(
            withBundle.decomposeRef,
            original.decomposeRef)
        XCTAssertEqual(
            withBundle.stabilityScore,
            original.stabilityScore)
        // Candidates / counterfactualBundles preserved.
        XCTAssertEqual(
            withBundle.candidates.count,
            original.candidates.count)
        XCTAssertEqual(
            withBundle.counterfactualBundles?.count,
            original.counterfactualBundles?.count)
    }

    func testWithDerivedIsDeterministic() {
        let frame = thoughtFrame(
            candidates: [
                candidate(id: "cand-1", confidence: 0.8),
                candidate(id: "cand-2", confidence: 0.5)
            ],
            counterfactualBundles: [
                counterfactualBundle(
                    candidateID: "cand-1",
                    uncertainty: 0.2,
                    affectedDomains: ["physical", "social"])
            ],
            critiqueBundles: [
                critiqueBundle(
                    candidateID: "cand-2",
                    evidenceGap: 0.6,
                    boundaryConflict: 0.85,
                    critiqueStrength: 0.9)
            ]
        )
        let first = BASWorldPriorObservationBundle.derive(
            fromThoughtFrame: frame,
            turnID: turnID,
            sessionID: sessionID,
            emittedAt: fixedDate)
        let second = BASWorldPriorObservationBundle.derive(
            fromThoughtFrame: frame,
            turnID: turnID,
            sessionID: sessionID,
            emittedAt: fixedDate)
        XCTAssertEqual(first, second)
    }

    // MARK: - Budget

    func testBudgetClampsToOne() {
        // Dense frame: 5 candidates + 5 counterfactuals (each
        // 2-domain so bridges fire too) + 5 critiques with axiomatic
        // collision + weak predictions. Raw budget far > 1.0.
        var cfs: [BASCounterfactualBundle] = []
        var crits: [BASCritiqueBundle] = []
        for i in 0 ..< 5 {
            cfs.append(counterfactualBundle(
                candidateID: "c-\(i)",
                uncertainty: 0.2,
                affectedDomains: ["physical", "social"]))
            crits.append(critiqueBundle(
                candidateID: "c-\(i)",
                evidenceGap: 0.7,
                boundaryConflict: 0.9,
                critiqueStrength: 0.9))
        }
        let frame = thoughtFrame(
            candidates: (0 ..< 5).map {
                candidate(id: "c-\($0)", confidence: 0.7)
            },
            counterfactualBundles: cfs,
            critiqueBundles: crits,
            uncertaintyLedger: uncertaintyLedger(
                weakPredictions: ["p1", "p2", "p3"])
        )
        let bundle = BASWorldPriorObservationBundle.derive(
            fromThoughtFrame: frame,
            turnID: turnID,
            sessionID: sessionID,
            emittedAt: fixedDate)
        let cost = BASWorldPriorObservationBudget.totalCost(
            for: bundle)
        XCTAssertLessThanOrEqual(cost, 1.0)
        XCTAssertGreaterThan(cost, 0.9) // saturated
    }

    // MARK: - Coverage summary parity

    func testCoverageSummaryMirrorsBundle() {
        let frame = thoughtFrame(
            candidates: [candidate(id: "cand-1")],
            counterfactualBundles: [
                counterfactualBundle(affectedDomains: ["physical"])
            ]
        )
        let bundle = BASWorldPriorObservationBundle.derive(
            fromThoughtFrame: frame,
            turnID: turnID,
            sessionID: sessionID,
            emittedAt: fixedDate)
        let summary = bundle.coverageSummary
        XCTAssertEqual(summary.layer, .worldPrior)
        XCTAssertEqual(summary.turnID, turnID)
        XCTAssertEqual(summary.sessionID, sessionID)
        XCTAssertEqual(
            summary.totalObservations, bundle.observations.count)
        XCTAssertEqual(
            summary.distinctSubjectCount,
            bundle.templateIDs.count)
        XCTAssertEqual(
            summary.hasCoreSignalCoverage,
            bundle.hasCoreSignalCoverage)
    }

    // MARK: - Codable

    func testBundleCodableRoundTrip() throws {
        let frame = thoughtFrame(
            candidates: [candidate()],
            counterfactualBundles: [counterfactualBundle()],
            critiqueBundles: [
                critiqueBundle(
                    boundaryConflict: 0.7,
                    critiqueStrength: 0.6)
            ]
        )
        let bundle = BASWorldPriorObservationBundle.derive(
            fromThoughtFrame: frame,
            turnID: turnID,
            sessionID: sessionID,
            emittedAt: fixedDate)
        let data = try JSONEncoder().encode(bundle)
        let decoded = try JSONDecoder().decode(
            BASWorldPriorObservationBundle.self,
            from: data)
        XCTAssertEqual(bundle, decoded)
    }

    func testThoughtFrameCodableRoundTripIncludesBundle() throws {
        let original = thoughtFrame(
            candidates: [candidate()],
            counterfactualBundles: [counterfactualBundle()]
        )
        .withDerivedWorldPriorObservationBundle(
            turnID: turnID,
            sessionID: sessionID,
            emittedAt: fixedDate)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASThoughtFrame.self,
            from: data)
        XCTAssertEqual(
            decoded.worldPriorObservationBundle,
            original.worldPriorObservationBundle)
    }

    // MARK: - Ledger

    func testLedgerRingBufferCapacity() async {
        let ledger = BASWorldPriorObservationLedger(capacity: 3)
        for i in 0 ..< 5 {
            let bundle = BASWorldPriorObservationBundle(
                turnID: "t-\(i)",
                sessionID: sessionID,
                observations: [],
                emittedAt: fixedDate)
            await ledger.record(bundle)
        }
        let count = await ledger.count()
        let snapshot = await ledger.snapshot()
        XCTAssertEqual(count, 3)
        XCTAssertEqual(snapshot.map(\.turnID), ["t-2", "t-3", "t-4"])
    }

    func testLedgerQueryBySession() async {
        let ledger = BASWorldPriorObservationLedger()
        let sA = "session-a"
        let sB = "session-b"
        await ledger.record(BASWorldPriorObservationBundle(
            turnID: "t1", sessionID: sA,
            observations: [], emittedAt: fixedDate))
        await ledger.record(BASWorldPriorObservationBundle(
            turnID: "t2", sessionID: sB,
            observations: [], emittedAt: fixedDate))
        await ledger.record(BASWorldPriorObservationBundle(
            turnID: "t3", sessionID: sA,
            observations: [], emittedAt: fixedDate))
        let a = await ledger.bundles(forSession: sA)
        let b = await ledger.bundles(forSession: sB)
        XCTAssertEqual(a.map(\.turnID), ["t1", "t3"])
        XCTAssertEqual(b.map(\.turnID), ["t2"])
    }
}
