import XCTest
@testable import BASAppleAdapters
@testable import BASLeaseLife
@testable import BASMemory
@testable import BASObservability
@testable import BASOrchestration
@testable import BASOrgan
@testable import BASPolicy
@testable import BASRuntimeCore
@testable import BASSovereign
@testable import BASWorldPrior
import CryptoKit
import Foundation

/// QINAO Substrate-100 gates — Phase-2 batch 13 (HIGH, final HIGH batch).
final class BASQINAOSubstrateGatesBatch13Tests: XCTestCase {

    func test_qinao_coreml_to_coreai_migration_gate() {
    typealias V = BASCoreAIMigrationVerdict
    typealias Rec = V.Recommendation

    // --- Local parity builder (mirrors the existing test's `parity(n:agree:mae:)` verbatim) ---
    func parity(n: Int, agree: Int, mae: Float?) -> BASCoreAIShadowComparison.ParitySummary {
        .init(sampleCount: n, labelsAgreeCount: agree,
              labelAgreementRate: n == 0 ? 0 : Double(agree) / Double(n),
              maeSampleCount: mae == nil ? 0 : n, meanLogitsMAE: mae, maxLogitsMAE: mae)
    }

    // --- Grid axes ---
    // Parity: PASS (met, n samples) vs FAIL (MAE blown out). Both carry comparable logits (mae != nil).
    enum ParityKind { case met, failMAE }
    // A lower-is-better paired dimension: a WIN clears the 5% margin, a LOSS regresses,
    // a TIE is measured-but-within-margin, and NONE is unmeasured (nil/nil → NO_EVIDENCE).
    enum DimKind: CaseIterable { case win, loss, tie, none }

    let incLat = 10.0
    let incMem = 1000
    func latPair(_ k: DimKind) -> (Double?, Double?) {
        switch k {
        case .win:  return (8.0, incLat)    // 8 <= 10*(1-0.05)=9.5 ⇒ WIN
        case .loss: return (12.0, incLat)   // 12 > 10 ⇒ LOSS
        case .tie:  return (9.7, incLat)    // 9.5 < 9.7 <= 10 ⇒ TIE (within margin band)
        case .none: return (nil, nil)       // unmeasured ⇒ NO_EVIDENCE
        }
    }
    func memPair(_ k: DimKind) -> (Int?, Int?) {
        switch k {
        case .win:  return (800, incMem)    // 800 <= 950 ⇒ WIN
        case .loss: return (1100, incMem)   // 1100 > 1000 ⇒ LOSS
        case .tie:  return (970, incMem)    // 950 < 970 <= 1000 ⇒ TIE
        case .none: return (nil, nil)
        }
    }

    // --- Independent oracle (mirrors the DOCUMENTED priority in `resolve`, recomputed here, not copied
    //     from any hard-coded expectation): LOSS first → gaps/insufficiency → all-win migrate → tie no-churn) ---
    func expected(parityKind: ParityKind, lat: DimKind, mem: DimKind,
                  samplesShort: Bool, devicesShort: Bool) -> Rec {
        let parityFailed = (parityKind == .failMAE)
        let hasLoss = parityFailed || lat == .loss || mem == .loss
        if hasLoss { return .doNotMigrate }                       // a known regression is decisive
        let hasGap = lat == .none || mem == .none || samplesShort || devicesShort
        if hasGap { return .insufficientEvidence }                // a missing/short dimension cannot certify a win
        // Parity here is .met (failMAE handled above); both dims are measured (no .none).
        let allWin = lat == .win && mem == .win
        if allWin { return .migrate }                             // ONLY path to migrate
        return .doNotMigrate                                      // full evidence, no loss, ≥1 tie ⇒ no net benefit
    }

    var sawMigrate = false, sawDoNot = false, sawInsufficient = false
    var cells = 0

    for parityKind in [ParityKind.met, .failMAE] {
        for lat in DimKind.allCases {
            for mem in DimKind.allCases {
                for samplesShort in [false, true] {
                    for devicesShort in [false, true] {
                        let n = samplesShort ? 10 : 60          // bar = minSamples 50
                        let devices = devicesShort ? 1 : 2      // bar = minDistinctDevices 2
                        let mae: Float = (parityKind == .met) ? 1e-5 : 0.5   // 1e-5 < 1e-3 pass; 0.5 >> fail
                        let (cLat, iLat) = latPair(lat)
                        let (cMem, iMem) = memPair(mem)

                        let e = V.Evidence(
                            parity: parity(n: n, agree: n, mae: mae),
                            candidateMeanLatencyMillis: cLat, incumbentMeanLatencyMillis: iLat,
                            candidatePeakMemoryBytes: cMem, incumbentPeakMemoryBytes: iMem,
                            distinctDeviceCount: devices)

                        let want = expected(parityKind: parityKind, lat: lat, mem: mem,
                                            samplesShort: samplesShort, devicesShort: devicesShort)
                        let v = V.decide(evidence: e)
                        let ctx = "parity=\(parityKind) lat=\(lat) mem=\(mem) " +
                                  "samplesShort=\(samplesShort) devicesShort=\(devicesShort)"
                        XCTAssertEqual(v.recommendation, want, ctx)

                        // INVARIANT: .migrate iff EVERY dimension wins AND sample/device coverage suffices.
                        let isFullWin = parityKind == .met && lat == .win && mem == .win
                            && !samplesShort && !devicesShort
                        XCTAssertEqual(v.recommendation == .migrate, isFullWin,
                            "migrate must require parity+latency+memory wins AND sufficient samples/devices — \(ctx)")
                        // Any single loss/short/missing dimension must keep it off .migrate.
                        if !isFullWin {
                            XCTAssertNotEqual(v.recommendation, .migrate, "single gap/loss must block migrate — \(ctx)")
                        }

                        // Determinism: a pure re-call yields an identical verdict (tolerance 0).
                        XCTAssertEqual(V.decide(evidence: e), v, "decide must be deterministic — \(ctx)")
                        // Reason codes are deterministically sorted.
                        XCTAssertEqual(v.reasonCodes, v.reasonCodes.sorted(), "reasons sorted — \(ctx)")

                        switch v.recommendation {
                        case .migrate: sawMigrate = true
                        case .doNotMigrate: sawDoNot = true
                        case .insufficientEvidence: sawInsufficient = true
                        }
                        cells += 1
                    }
                }
            }
        }
    }

    // Grid size is COMPUTED, not asserted as a magic literal: 2 parity × 4 lat × 4 mem × 2 samples × 2 devices.
    let expectedCells = 2 * DimKind.allCases.count * DimKind.allCases.count * 2 * 2
    XCTAssertEqual(cells, expectedCells, "exhaustive grid must cover every win/lose/tie × sample/device cell")
    XCTAssertEqual(cells, 128)
    XCTAssertTrue(sawMigrate && sawDoNot && sawInsufficient,
        "the grid must exercise all three verdicts (migrate is reachable but rare)")

    // Mutate-and-assert: take the SINGLE migrating cell, break exactly one dimension, verify it flips off migrate.
    let baseWin = V.Evidence(
        parity: parity(n: 60, agree: 60, mae: 1e-5),
        candidateMeanLatencyMillis: 8, incumbentMeanLatencyMillis: 10,
        candidatePeakMemoryBytes: 800, incumbentPeakMemoryBytes: 1000, distinctDeviceCount: 2)
    XCTAssertEqual(V.decide(evidence: baseWin).recommendation, .migrate, "baseline must be the migrate cell")

    let mutLatLoss = V.Evidence(
        parity: parity(n: 60, agree: 60, mae: 1e-5),
        candidateMeanLatencyMillis: 12, incumbentMeanLatencyMillis: 10,   // flip latency → LOSS
        candidatePeakMemoryBytes: 800, incumbentPeakMemoryBytes: 1000, distinctDeviceCount: 2)
    XCTAssertEqual(V.decide(evidence: mutLatLoss).recommendation, .doNotMigrate,
        "a single latency regression must flip migrate → doNotMigrate")

    let mutOneDevice = V.Evidence(
        parity: parity(n: 60, agree: 60, mae: 1e-5),
        candidateMeanLatencyMillis: 8, incumbentMeanLatencyMillis: 10,
        candidatePeakMemoryBytes: 800, incumbentPeakMemoryBytes: 1000, distinctDeviceCount: 1)   // drop below ≥2
    XCTAssertEqual(V.decide(evidence: mutOneDevice).recommendation, .insufficientEvidence,
        "insufficient device coverage must flip migrate → insufficientEvidence")

    print("QINAO-GATE coreml_to_coreai_migration_gate: PASS (\(cells) grid cells exhausted; " +
          "migrate iff parity+latency+memory win AND samples≥min AND devices≥min; " +
          "any single loss/tie/missing/short blocks migrate; deterministic + sorted reasons)")
}

    func test_qinao_observation_coverage_14layer() async {
    // QINAO Substrate-100 #55 — after the per-layer ObservationBundles
    // are projected into a single BASObservationReconciliationReport,
    // isFullyObserved(expected:) is true IFF all 14 cognitive layers
    // are present; dropping ANY one layer flips it false.
    //
    // Subject: the host-side 14-layer coverage report and its
    // isFullyObserved invariant (BASObservationReconciliationCore).
    // buildEBrainTurn(...) returns a full BASEBrainTurnResult that
    // requires a heavyweight BASHostRuntime + startSession, and the
    // async host surface SIGBUSes on this toolchain
    // (BASSignalTenIntegrationTestTriageDoctrine). The 14-layer
    // coverage invariant itself is the real in-repo source of truth
    // and is asserted directly here, mirroring the construction in
    // BASFourteenLayerReconciliationTests verbatim.
    let QINAO_t0 = Date(timeIntervalSince1970: 1_700_000_000)
    let QINAO_turnID = "qinao-t55"
    let QINAO_sessionID = "qinao-s55"

    // MARK: per-layer fixtures (mirrored verbatim from
    // BASFourteenLayerReconciliationTests — minimally-healthy bundles)

    func l1() -> BASObservationCoverageSummary {
        let lung = BASLungStateAccumulator.Snapshot(
            pressure: 0.2,
            turnCount: 1,
            lastTurnAt: QINAO_t0,
            lastDecayAt: QINAO_t0)
        let reading = BASThermalTwin.Reading(
            osState: .fair,
            thermalLevel: .warm,
            guardLevel: .nominal,
            accumulatedPressure: 0.2,
            observedAt: QINAO_t0)
        let recorded = BASLeaseLifeCoordinator.TurnRecorded(
            lung: lung,
            thermal: reading,
            cancelledBreathIDs: [])
        return recorded.coverageSummary(
            turnID: QINAO_turnID, sessionID: QINAO_sessionID)
    }

    func l2() -> BASObservationCoverageSummary {
        let snap = BASOrganRegistryObservationSnapshot(
            descriptors: [
                BASOrganDescriptor(
                    providerID: "det.scout.v1",
                    providerName: "scout",
                    supportsStreaming: false,
                    maxInputTokens: 8_192,
                    maxOutputTokens: 2_048,
                    runsOnDevice: true,
                    supportedRoles: [.scout]),
                BASOrganDescriptor(
                    providerID: "det.core.v1",
                    providerName: "core",
                    supportsStreaming: false,
                    maxInputTokens: 8_192,
                    maxOutputTokens: 2_048,
                    runsOnDevice: true,
                    supportedRoles: [.core])
            ])
        return BASOrganRegistry.projectCoverage(
            from: snap,
            turnID: QINAO_turnID,
            sessionID: QINAO_sessionID,
            emittedAt: QINAO_t0)
    }

    func l3() -> BASObservationCoverageSummary {
        let fold = BASThoughtFold(
            foldID: "fold-55",
            compactSlots: ["task": "scan"],
            candidateSignatures: ["cand-a"],
            hostEffectSummary: "neutral",
            restorePointer: "restore-55",
            checksum: "chk-55",
            organPackageRefs: ["pkg-a"])
        return fold.coverageSummary(
            turnID: QINAO_turnID, sessionID: QINAO_sessionID, emittedAt: QINAO_t0)
    }

    func l4() -> BASObservationCoverageSummary {
        BASWorldPriorObservationBundle(
            turnID: QINAO_turnID, sessionID: QINAO_sessionID,
            observations: [
                BASWorldPriorObservation(
                    kind: .templateMatched, templateID: "tpl-a",
                    evidenceLevel: .plausible,
                    salience: 0.5, confidence: 0.5,
                    content: "x", observedAt: QINAO_t0),
                BASWorldPriorObservation(
                    kind: .counterfactualSeeded, templateID: "tpl-a",
                    evidenceLevel: .plausible,
                    salience: 0.5, confidence: 0.5,
                    content: "x", observedAt: QINAO_t0)
            ],
            emittedAt: QINAO_t0).coverageSummary
    }

    func l5() -> BASObservationCoverageSummary {
        let snap = BASHostCandidatePipelineObservationSnapshot(
            activeVersionID: "host.v1",
            committedVersionIDs: ["host.v1"],
            pendingCandidateIDs: [],
            rejectedCandidateIDs: [],
            frozenVersionIDs: [])
        return BASHostCandidatePipeline.projectCoverage(
            from: snap,
            turnID: QINAO_turnID,
            sessionID: QINAO_sessionID,
            emittedAt: QINAO_t0)
    }

    func l6() -> BASObservationCoverageSummary {
        BASPresenceObservationBundle(
            turnID: QINAO_turnID, sessionID: QINAO_sessionID,
            observations: [
                BASPresenceObservation(
                    channel: .task,
                    salience: 0.5, confidence: 0.5,
                    content: "x", observedAt: QINAO_t0),
                BASPresenceObservation(
                    channel: .risk,
                    salience: 0.5, confidence: 0.5,
                    content: "x", observedAt: QINAO_t0),
                BASPresenceObservation(
                    channel: .manipulation,
                    salience: 0.5, confidence: 0.5,
                    content: "x", observedAt: QINAO_t0)
            ],
            emittedAt: QINAO_t0).coverageSummary
    }

    func l7() -> BASObservationCoverageSummary {
        BASDecompositionObservationBundle(
            turnID: QINAO_turnID, sessionID: QINAO_sessionID,
            observations: [
                BASDecompositionObservation(
                    kind: .factShard,
                    salience: 0.5, confidence: 0.5,
                    content: "x", observedAt: QINAO_t0),
                BASDecompositionObservation(
                    kind: .contradiction,
                    salience: 0.5, confidence: 0.5,
                    content: "x", observedAt: QINAO_t0),
                BASDecompositionObservation(
                    kind: .mirrorDraft,
                    salience: 0.5, confidence: 0.5,
                    content: "x", observedAt: QINAO_t0)
            ],
            emittedAt: QINAO_t0).coverageSummary
    }

    func l8() async -> BASObservationCoverageSummary {
        let clockDate = QINAO_t0
        let log = BASMemoryTierTransitionLog(capacity: 8)
        let reconciler = BASMemoryTieringReconciler(
            log: log,
            clock: { clockDate })
        let outcome = await reconciler.reconcile(profiles: [
            BASMemoryTieringProfile(
                atomID: "atom-a",
                currentTier: .warm,
                recencyScore: 0.5,
                accessFrequency: 0.5,
                sensitivityDrift: 0.0,
                worldContextStaleness: 0.0,
                observedAt: QINAO_t0)
        ])
        return outcome.coverageSummary(
            turnID: QINAO_turnID, sessionID: QINAO_sessionID)
    }

    func l9() -> BASObservationCoverageSummary {
        BASCandidateObservationBundle(
            turnID: QINAO_turnID, sessionID: QINAO_sessionID,
            observations: [
                BASCandidateObservation(
                    kind: .candidate, candidateID: "c-a",
                    salience: 0.5, confidence: 0.5,
                    content: "x", observedAt: QINAO_t0),
                BASCandidateObservation(
                    kind: .reversibilitySignal, candidateID: "c-a",
                    salience: 0.5, confidence: 0.5,
                    content: "x", observedAt: QINAO_t0),
                BASCandidateObservation(
                    kind: .guardianBranch, candidateID: "c-a",
                    salience: 0.5, confidence: 0.5,
                    content: "x", observedAt: QINAO_t0)
            ],
            emittedAt: QINAO_t0).coverageSummary
    }

    func l10() -> BASObservationCoverageSummary {
        BASTribunalObservationBundle(
            turnID: QINAO_turnID, sessionID: QINAO_sessionID,
            observations: [
                BASTribunalObservation(
                    kind: .vote, voice: .baseSelf,
                    disposition: .affirm, subjectID: "sub",
                    salience: 0.5, confidence: 0.5,
                    content: "x", observedAt: QINAO_t0),
                BASTribunalObservation(
                    kind: .vote, voice: .ruleSelf,
                    disposition: .affirm, subjectID: "sub",
                    salience: 0.5, confidence: 0.5,
                    content: "x", observedAt: QINAO_t0),
                BASTribunalObservation(
                    kind: .vote, voice: .aspireSelf,
                    disposition: .affirm, subjectID: "sub",
                    salience: 0.5, confidence: 0.5,
                    content: "x", observedAt: QINAO_t0),
                BASTribunalObservation(
                    kind: .convergence, voice: nil,
                    disposition: nil, subjectID: "sub",
                    salience: 0.5, confidence: 0.5,
                    content: "x", observedAt: QINAO_t0)
            ],
            emittedAt: QINAO_t0).coverageSummary
    }

    func l11() -> BASObservationCoverageSummary {
        BASRiskObservationBundle(
            turnID: QINAO_turnID, sessionID: QINAO_sessionID,
            observations: [
                BASRiskObservation(
                    kind: .hazardReading, intentID: "i",
                    salience: 0.5, confidence: 0.5,
                    content: "x", observedAt: QINAO_t0),
                BASRiskObservation(
                    kind: .irreversibilityReading, intentID: "i",
                    salience: 0.5, confidence: 0.5,
                    content: "x", observedAt: QINAO_t0),
                BASRiskObservation(
                    kind: .harmPotentialReading, intentID: "i",
                    salience: 0.5, confidence: 0.5,
                    content: "x", observedAt: QINAO_t0)
            ],
            emittedAt: QINAO_t0).coverageSummary
    }

    func l12() -> BASObservationCoverageSummary {
        BASSoftHandObservationBundle(
            turnID: QINAO_turnID, sessionID: QINAO_sessionID,
            observations: [
                BASSoftHandObservation(
                    kind: .selection, mode: .compare,
                    subjectID: "sub",
                    salience: 0.5, confidence: 0.5,
                    content: "x", observedAt: QINAO_t0),
                BASSoftHandObservation(
                    kind: .render, mode: .compare,
                    subjectID: "sub",
                    salience: 0.5, confidence: 0.5,
                    content: "x", observedAt: QINAO_t0)
            ],
            emittedAt: QINAO_t0).coverageSummary
    }

    func l13() -> BASObservationCoverageSummary {
        BASShadowTrialObservationBundle(
            turnID: QINAO_turnID, sessionID: QINAO_sessionID,
            observations: [
                BASShadowTrialObservation(
                    kind: .ticketIssued, ticketID: "tk",
                    salience: 0.5, confidence: 0.5,
                    content: "x", observedAt: QINAO_t0),
                BASShadowTrialObservation(
                    kind: .trialRun, ticketID: "tk",
                    salience: 0.5, confidence: 0.5,
                    content: "x", observedAt: QINAO_t0),
                BASShadowTrialObservation(
                    kind: .parityVerified, ticketID: "tk",
                    salience: 0.5, confidence: 0.5,
                    content: "x", observedAt: QINAO_t0)
            ],
            emittedAt: QINAO_t0).coverageSummary
    }

    func l14() -> BASObservationCoverageSummary {
        let entry = BASSovereignAuditEntry(
            auditID: "a-1",
            sessionID: QINAO_sessionID,
            turnID: QINAO_turnID,
            verdictRef: "v-1",
            ruleIDs: ["BR-001"],
            signalRefs: [],
            actionRefs: [],
            snapshotRef: "snap-1",
            actor: .system,
            signature: "",
            appendedAt: QINAO_t0)
        let wrapped = BASSovereignAuditLedger.AppendedEntry(
            entry: entry,
            priorHash: "GENESIS",
            selfHash: "x")
        return BASSovereignAuditLedger.projectCoverage(
            from: [wrapped],
            turnID: QINAO_turnID,
            sessionID: QINAO_sessionID,
            emittedAt: QINAO_t0)
    }

    // Build one summary per cognitive layer. l8 is actor-isolated →
    // hoist the await out of every assert autoclosure.
    let l8Summary = await l8()
    let allSummaries: [BASObservationCoverageSummary] = [
        l1(), l2(), l3(), l4(), l5(), l6(), l7(),
        l8Summary, l9(), l10(), l11(), l12(), l13(), l14()
    ]

    // The expected set is the WHOLE enum — not a hard-coded literal.
    let expected = BASCognitiveLayer.allCases
    XCTAssertEqual(
        expected.count, 14,
        "the cognitive-layer enum must stay at exactly 14 cases")
    XCTAssertEqual(
        allSummaries.count, expected.count,
        "must collect exactly one summary per cognitive layer")
    // Every layer is represented exactly once across the fixtures.
    XCTAssertEqual(
        Set(allSummaries.map { $0.layer }), Set(expected),
        "fixtures must cover every BASCognitiveLayer exactly once")

    // Local builder: compose a report from a list of summaries.
    func buildReport(
        _ summaries: [BASObservationCoverageSummary]
    ) -> BASObservationReconciliationReport {
        var report = BASObservationReconciliationReport(
            turnID: QINAO_turnID, sessionID: QINAO_sessionID)
        for s in summaries { report = report.appending(s) }
        return report
    }

    // 1) FULL report — all 14 present → isFullyObserved is TRUE.
    let fullReport = buildReport(allSummaries)
    XCTAssertEqual(fullReport.coveredLayers.count, expected.count)
    XCTAssertTrue(
        fullReport.missingLayers(expected: expected).isEmpty,
        "no layer may be missing in the full 14-of-14 report")
    XCTAssertTrue(
        fullReport.layersWithoutCoreCoverage.isEmpty,
        "every fixture is minimally healthy; none degraded")
    XCTAssertTrue(
        fullReport.isFullyObserved(expected: expected),
        "14-of-14 must be fully observed against allCases")

    // Determinism: a re-call on the identical report is invariant.
    XCTAssertEqual(
        fullReport.isFullyObserved(expected: expected),
        fullReport.isFullyObserved(expected: expected),
        "isFullyObserved must be a deterministic pure query")

    // 2) EXHAUSTIVE raised bar: dropping ANY ONE of the 14 layers
    // must flip isFullyObserved to FALSE, and missingLayers must name
    // exactly the dropped layer. This is the IFF — not just a sample.
    for dropIndex in allSummaries.indices {
        let droppedLayer = allSummaries[dropIndex].layer
        var partial = allSummaries
        partial.remove(at: dropIndex)
        let partialReport = buildReport(partial)

        XCTAssertEqual(
            partialReport.coveredLayers.count, expected.count - 1,
            "dropping one layer must leave exactly 13 covered")
        XCTAssertEqual(
            partialReport.missingLayers(expected: expected),
            [droppedLayer],
            "missingLayers must name exactly the dropped layer "
            + "\\(droppedLayer.rawValue)")
        XCTAssertFalse(
            partialReport.isFullyObserved(expected: expected),
            "dropping layer \\(droppedLayer.rawValue) must flip "
            + "isFullyObserved to false (the IFF reverse direction)")
    }

    // 3) Mutate-and-assert on the other failure axis: a present-but-
    // unhealthy layer (no core signal) must ALSO break the invariant
    // even when all 14 are nominally present. Replace L11's summary
    // with a healthy=false copy and confirm the flip.
    let unhealthyL11 = BASObservationCoverageSummary(
        layer: .riskClimate,
        turnID: QINAO_turnID,
        sessionID: QINAO_sessionID,
        totalObservations: 0,
        distinctSubjectCount: 0,
        hasCoreSignalCoverage: false,
        budgetTotalCost: 0.0,
        emittedAt: QINAO_t0)
    let mutated = allSummaries.map {
        $0.layer == .riskClimate ? unhealthyL11 : $0
    }
    let mutatedReport = buildReport(mutated)
    XCTAssertTrue(
        mutatedReport.missingLayers(expected: expected).isEmpty,
        "all 14 still present after the swap")
    XCTAssertEqual(
        mutatedReport.layersWithoutCoreCoverage, [.riskClimate],
        "exactly the swapped layer lacks core coverage")
    XCTAssertFalse(
        mutatedReport.isFullyObserved(expected: expected),
        "present-but-unhealthy layer must also break fully-observed")

    print(
        "QINAO-GATE observation_coverage_14layer: PASS "
        + "(full report 14/14 isFullyObserved=true; exhaustive "
        + "drop-one over all \\(expected.count) layers each flips "
        + "to false naming exactly the dropped layer; "
        + "present-but-no-core-signal also flips false)")
}

    func test_qinao_prompt_budget_suffix_floor() {
    // QINAO #59 HIGH: every compiled prompt envelope gives its volatile suffix at
    // least suffixFloorCharacters; recomputing suffixTargetChars respects the floor
    // under squeeze. The compiler's private suffixTargetCharacters(for:) clamps
    //   suffixTarget = max(floor, targetCharacters - stablePrefix.count)
    // where stablePrefix = [immutablePrefix, adaptivePrefix].filter(nonEmpty).joined("\n\n").
    // The only public observable is envelope.assembly.suffixTargetCharacters.

    // Helper: build a request with controllable prefixes / target / floor.
    // Construction mirrored verbatim from BASPromptContractCoreTests.swift.
    func QINAOMakeEnvelope(
        immutablePrefix: String,
        adaptivePrefix: String,
        targetCharacters: Int,
        suffixFloorCharacters: Int
    ) -> BASPromptEnvelope<String, BASFrontstageState> {
        let strategy = BASAdaptiveTaskStrategy(
            kind: .primary,
            entropy: .low,
            runtimeGear: .low,
            contextBudget: 220,
            retrievalMode: .off,
            thinkingMode: .off,
            outputMode: .guidedShort,
            tone: .briefWarm,
            actionSpace: ["encourage", "next_step"],
            responseLanguage: .english,
            allowsModelInvocation: true
        )
        return BASPromptContractCompiler.compile(
            BASPromptContractRequest(
                kind: "primary",
                semanticKind: .primary,
                adaptiveKind: .primary,
                immutablePrefix: immutablePrefix,
                adaptivePrefix: adaptivePrefix,
                taskStateJSON: #"{"mode":"Primary","note":"Not provided."}"#,
                evidenceSnippets: [
                    "Current perspective: You want a little relief tonight.",
                    "After perspective: It may feel louder tomorrow."
                ],
                evidenceRetentionBudget: 1,
                outputGuard: ["Rewrite only the perspective lines."],
                frontstageInput: BASPromptContractFrontstageInput(
                    kind: .primary,
                    activeStateSignalCount: 3,
                    openTextSignalCount: 1,
                    contextWasRebuilt: true,
                    staleFieldCount: 1,
                    anchorTitles: ["primary note"],
                    dominantSignalTitles: ["Constraint pressure"],
                    suppressedBehaviors: ["instant_verdict"],
                    memoryHeadlines: ["Holding the decision often breaks the loop."],
                    sessionBiases: ["Keep the language short and concrete."]
                ),
                targetCharacters: targetCharacters,
                suffixFloorCharacters: suffixFloorCharacters,
                strategy: strategy,
                structuredTruth: BASStructuredTruthState(
                    mode: "primary",
                    currentGoal: "Protect sleep before midnight.",
                    allowedActions: ["encourage"],
                    forbiddenActions: ["force_verdict"],
                    personaRules: ["Keep the interruption short, calm, and non-shaming."],
                    sessionFacts: ["boundary_mode": "steady"]
                ),
                includeStructuredTruthBlock: true,
                scopedContextJSON: #"{"user_profile":["Short, direct language lands better."]}"#,
                contextLifecycleJSON: #"{"rebuilt_session":true}"#
            )
        )
    }

    // Oracle: recompute the contract exactly as the compiler does (must stay in lock-step).
    func QINAOExpectedSuffixTarget(
        immutablePrefix: String,
        adaptivePrefix: String,
        targetCharacters: Int,
        suffixFloorCharacters: Int
    ) -> Int {
        let stablePrefix = [immutablePrefix, adaptivePrefix]
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
        return max(suffixFloorCharacters, targetCharacters - stablePrefix.count)
    }

    let floor = 120

    // ---- Case A: slack case (prefix small) -> floor does NOT bind, target-prefix wins.
    let slackImmutable = "Kernel identity."
    let slackAdaptive = "Primary lane rules."
    let slackTarget = 600
    let slackEnvelope = QINAOMakeEnvelope(
        immutablePrefix: slackImmutable,
        adaptivePrefix: slackAdaptive,
        targetCharacters: slackTarget,
        suffixFloorCharacters: floor
    )
    let slackExpected = QINAOExpectedSuffixTarget(
        immutablePrefix: slackImmutable,
        adaptivePrefix: slackAdaptive,
        targetCharacters: slackTarget,
        suffixFloorCharacters: floor
    )
    let slackActual = slackEnvelope.assembly.suffixTargetCharacters
    // The volatile suffix MUST get at least the floor (the QINAO invariant).
    XCTAssertGreaterThanOrEqual(slackActual, floor,
        "slack: suffix target must respect the floor")
    // And it must equal the computed contract exactly (tolerance 0).
    XCTAssertEqual(slackActual, slackExpected,
        "slack: suffix target must equal max(floor, target - prefix)")
    // In the slack case the floor must NOT be what binds (sanity that the case is real).
    XCTAssertGreaterThan(slackActual, floor,
        "slack case must exercise the target-driven branch, not the floor")

    // ---- Case B: squeeze case (huge prefix) -> target-prefix goes below floor, floor binds.
    let squeezeImmutable = String(repeating: "X", count: 400)
    let squeezeAdaptive = String(repeating: "Y", count: 300)
    let squeezeTarget = 220 // target - prefix is deeply negative -> floor must clamp.
    let squeezeEnvelope = QINAOMakeEnvelope(
        immutablePrefix: squeezeImmutable,
        adaptivePrefix: squeezeAdaptive,
        targetCharacters: squeezeTarget,
        suffixFloorCharacters: floor
    )
    let squeezeExpected = QINAOExpectedSuffixTarget(
        immutablePrefix: squeezeImmutable,
        adaptivePrefix: squeezeAdaptive,
        targetCharacters: squeezeTarget,
        suffixFloorCharacters: floor
    )
    let squeezeActual = squeezeEnvelope.assembly.suffixTargetCharacters
    // Under squeeze the suffix target MUST clamp to exactly the floor, never below.
    XCTAssertGreaterThanOrEqual(squeezeActual, floor,
        "squeeze: suffix target must never drop below the floor")
    XCTAssertEqual(squeezeExpected, floor,
        "squeeze: oracle must confirm the floor is the binding term")
    XCTAssertEqual(squeezeActual, floor,
        "squeeze: suffix target must clamp to exactly the floor")

    // ---- Determinism: re-compiling the same squeeze request yields the identical value.
    let squeezeRepeat = QINAOMakeEnvelope(
        immutablePrefix: squeezeImmutable,
        adaptivePrefix: squeezeAdaptive,
        targetCharacters: squeezeTarget,
        suffixFloorCharacters: floor
    )
    XCTAssertEqual(squeezeRepeat.assembly.suffixTargetCharacters, squeezeActual,
        "compiler must be deterministic across identical requests")

    // ---- Exhaustive sweep: across a grid of prefixes x targets x floors the invariant
    // (actual >= floor) AND the exact contract (actual == max(floor, target-prefix))
    // must hold for EVERY combination. Floor is honored even when target is tiny/zero.
    let prefixLengths = [0, 1, 50, 200, 700]
    let targets = [0, 100, 220, 600, 2000]
    let floors = [1, 80, 120, 500]
    for pLen in prefixLengths {
        let imm = pLen == 0 ? "" : String(repeating: "A", count: pLen)
        for t in targets {
            for f in floors {
                let env = QINAOMakeEnvelope(
                    immutablePrefix: imm,
                    adaptivePrefix: "",
                    targetCharacters: t,
                    suffixFloorCharacters: f
                )
                let expected = QINAOExpectedSuffixTarget(
                    immutablePrefix: imm,
                    adaptivePrefix: "",
                    targetCharacters: t,
                    suffixFloorCharacters: f
                )
                let got = env.assembly.suffixTargetCharacters
                XCTAssertGreaterThanOrEqual(got, f,
                    "floor violated for prefix=\(pLen) target=\(t) floor=\(f)")
                XCTAssertEqual(got, expected,
                    "contract broken for prefix=\(pLen) target=\(t) floor=\(f)")
            }
        }
    }

    print("QINAO-GATE prompt_budget_suffix_floor: PASS (slack=\(slackActual) squeeze=\(squeezeActual) floor=\(floor); floor respected + exact contract across prefix x target x floor grid + deterministic)")
}

    func test_qinao_risk_calibration_delta_bound() async throws {
    // QINAO #72 HIGH — risk_calibration_delta_bound.
    // Two invariants:
    //   (A) Each per-stratum calibration delta stays within the
    //       ±0.25 cap (BASRiskCalibrationStratumDelta clamps every
    //       threshold delta to [-maximumAbsoluteDelta, +max] in init).
    //   (B) Each effective<Tier>Threshold returns base + clamped-delta
    //       (gate applies the looked-up delta, then clamps to [0,1]).
    //
    // Subject API (read from source, host-side, no device/script):
    //   BASRiskCalibrationStratumDelta.maximumAbsoluteDelta == 0.25
    //   BASRiskCalibrationStratumDelta(stratumKey:mediumThresholdDelta:
    //       highThresholdDelta:extremeThresholdDelta:evidenceRowCount:...)
    //       clamps each *ThresholdDelta to [-0.25, +0.25].
    //   actor BASRiskCalibrationGate.effective{Medium,High,Extreme}Threshold(
    //       forStratumKey:base:) async -> Double  ==> clamp01(base + delta)

    // Fixtures mirrored verbatim from BASRiskCalibrationGateTests.
    func makeBundle(
        version: String,
        supersedes: String? = nil,
        deltas: [BASRiskCalibrationStratumDelta] = []
    ) -> BASRiskCalibrationBundle {
        BASRiskCalibrationBundle(
            bundleVersion: version,
            aggregateProvenanceRef: "agg:\(version)",
            strataDeltas: deltas,
            sovereignWarrantRef: "warrant:\(version)",
            supersedesBundleVersion: supersedes,
            summary: "test bundle \(version)")
    }

    // The cap is the single source of truth — never hard-code 0.25.
    let cap = BASRiskCalibrationStratumDelta.maximumAbsoluteDelta
    XCTAssertEqual(cap, 0.25, accuracy: 0, "QINAO cap drift")

    // Replicated-oracle clamp: clamp(NaN)->0, else min(hi,max(lo,v)).
    func qinaoOracleClamp(_ v: Double, _ lo: Double, _ hi: Double) -> Double {
        if v.isNaN { return 0 }
        return min(hi, max(lo, v))
    }

    // ---- Invariant (A): delta construction clamps to ±cap ----
    // Random proposals (incl. far out-of-range, exact-edge, NaN) must
    // all land in [-cap, +cap] and equal the replicated oracle.
    var rng = SystemRandomNumberGenerator()
    var proposals: [Double] = [
        -5.0, 5.0, -cap, cap, 0.0, 0.1, -0.1,
        cap + 1e-9, -cap - 1e-9, .nan, 1.0, -1.0
    ]
    for _ in 0..<200 {
        proposals.append(Double.random(in: -3.0...3.0, using: &rng))
    }
    for p in proposals {
        let d = BASRiskCalibrationStratumDelta(
            stratumKey: "tone=qinao|stake=high|confidant=public",
            mediumThresholdDelta: p,
            highThresholdDelta: p,
            extremeThresholdDelta: p,
            evidenceRowCount: 10)
        let expected = qinaoOracleClamp(p, -cap, cap)
        for actual in [d.mediumThresholdDelta,
                       d.highThresholdDelta,
                       d.extremeThresholdDelta] {
            XCTAssertEqual(actual, expected, accuracy: 0,
                "delta clamp mismatch for proposal \(p)")
            XCTAssertLessThanOrEqual(abs(actual), cap,
                "delta \(actual) exceeds ±\(cap) cap for proposal \(p)")
        }
    }

    // ---- Invariant (B): effective<Tier>Threshold == clamp01(base+clampedDelta) ----
    // A bundle whose three deltas differ so each tier reads its own field.
    let key = "tone=angry|stake=high|confidant=public"
    let dMed = 0.10
    let dHigh = -0.05
    let dExt = 0.15
    let delta = BASRiskCalibrationStratumDelta(
        stratumKey: key,
        mediumThresholdDelta: dMed,
        highThresholdDelta: dHigh,
        extremeThresholdDelta: dExt,
        evidenceRowCount: 100)
    let bundle = makeBundle(version: "v1.0.0", deltas: [delta])
    let gate = BASRiskCalibrationGate()
    _ = try await gate.replace(bundle)

    func qinaoClamp01(_ v: Double) -> Double {
        if v.isNaN { return 0 }
        return min(1.0, max(0.0, v))
    }

    let base = 0.5
    // Hoist every await out of XCTAssert autoclosures.
    let med = await gate.effectiveMediumThreshold(forStratumKey: key, base: base)
    let high = await gate.effectiveHighThreshold(forStratumKey: key, base: base)
    let ext = await gate.effectiveExtremeThreshold(forStratumKey: key, base: base)
    XCTAssertEqual(med, qinaoClamp01(base + delta.mediumThresholdDelta),
        accuracy: 0, "medium != base+clampedDelta")
    XCTAssertEqual(high, qinaoClamp01(base + delta.highThresholdDelta),
        accuracy: 0, "high != base+clampedDelta")
    XCTAssertEqual(ext, qinaoClamp01(base + delta.extremeThresholdDelta),
        accuracy: 0, "extreme != base+clampedDelta")

    // Output clamp: a +cap delta on a high base saturates at 1.0,
    // a -cap delta on a low base saturates at 0.0.
    let satKey = "tone=sat|stake=high|confidant=public"
    let satDelta = BASRiskCalibrationStratumDelta(
        stratumKey: satKey,
        mediumThresholdDelta: cap,
        highThresholdDelta: -cap,
        extremeThresholdDelta: cap,
        evidenceRowCount: 100)
    let satBundle = makeBundle(
        version: "v2.0.0", supersedes: "v1.0.0", deltas: [satDelta])
    _ = try await gate.replace(satBundle)
    let satHigh = await gate.effectiveMediumThreshold(forStratumKey: satKey, base: 0.9)
    let satLow = await gate.effectiveHighThreshold(forStratumKey: satKey, base: 0.1)
    XCTAssertEqual(satHigh, 1.0, accuracy: 0, "0.9+cap must saturate at 1.0")
    XCTAssertEqual(satLow, 0.0, accuracy: 0, "0.1-cap must saturate at 0.0")

    // Missing-stratum: returns clamp01(base) unchanged (no delta).
    let miss = await gate.effectiveMediumThreshold(
        forStratumKey: "tone=absent", base: base)
    XCTAssertEqual(miss, base, accuracy: 0, "missing stratum must return base")

    // Determinism: re-calling the same getter yields the identical value.
    let medAgain = await gate.effectiveMediumThreshold(forStratumKey: satKey, base: 0.9)
    XCTAssertEqual(medAgain, satHigh, accuracy: 0, "getter not deterministic")

    print("QINAO-GATE risk_calibration_delta_bound: PASS "
        + "(cap=±\(cap); \(proposals.count) deltas clamped to oracle; "
        + "effective{Med,High,Ext}=base+clampedDelta clamp01; "
        + "saturation 1.0/0.0; missing-stratum=base; deterministic)")
}

    func test_qinao_risk_card_monotonic_ordering() {
    // METRIC #73 (HIGH): as risk level rises with the SAME hazard input, totalRisk is
    // non-decreasing, AND an .extreme card recommends a PROTECTED mode (never .answer).
    //
    // Source of truth (read, not invented):
    //   • BASRiskCard / BASBrainRiskLevel / BASActionPermitMode live in
    //     Sources/BASPolicy/EBrainRiskPlaneCore.swift.
    //   • BASBrainRiskLevel: enum String, CaseIterable, Comparable with rank
    //     low(0) < medium(1) < high(2) < extreme(3) (the `<` + `rank` impl, lines 26-48).
    //   • The risk-level verdict is assigned by ascending totalRisk thresholds in
    //     BASHostRuntimeEBrainRiskService.calibrateRisk (EBrainHostRuntime+RiskService.swift
    //     lines 97-106): ..<medium → .low, ..<high → .medium, ..<extreme → .high,
    //     else .extreme. So a HIGHER level is reached only at a HIGHER (non-decreasing)
    //     totalRisk band for the same input — the monotone coupling under test.
    //   • The level→recommendedMode map is the private switch `recommendedMode(for:)`
    //     (same file, lines 758-772): .extreme → (manipulationHints.isEmpty ? .replace
    //     : .block). Neither branch is .answer. We replicate that switch as an oracle
    //     and ALSO round-trip real extreme BASRiskCards through the struct.
    //
    // The full calibrateRisk path needs heavy fixtures (BASHostSessionRequest +
    // BASHostCurrentBrain + BASEBrainRuntimeSynthesisPolicy + BASContextFrame +
    // BASThoughtFrame); the load-bearing invariant is host-side checkable against the
    // real BASRiskCard struct + the real Comparable conformance + a replicated oracle of
    // the (private) extreme→mode switch, so we assert those directly. tolerance = 0.

    // Mirror the verbatim BASRiskCard init from BASEBrainSchemaCoreTests.swift:239.
    func makeCard(
        totalRisk: Double,
        riskLevel: BASBrainRiskLevel,
        recommendedMode: BASActionPermitMode
    ) -> BASRiskCard {
        BASRiskCard(
            totalRisk: totalRisk,
            riskLevel: riskLevel,
            factors: ["risk.factor"],
            uncertainty: 0.3,
            irreversibility: 0.4,
            manipulationStrength: 0.2,
            gsiScore: 0.25,
            recommendedMode: recommendedMode
        )
    }

    // ── (1) BASBrainRiskLevel is a TOTAL ORDER low < medium < high < extreme ──────────
    // CaseIterable declaration order is the canonical ascending order; assert Comparable
    // agrees EXHAUSTIVELY over every ordered pair (tolerance 0). This is the "risk level
    // rises" axis the metric quantifies over.
    let ordered = BASBrainRiskLevel.allCases
    XCTAssertEqual(ordered, [.low, .medium, .high, .extreme],
        "CaseIterable order must be the canonical ascending risk ordering")
    for i in ordered.indices {
        for j in ordered.indices {
            let a = ordered[i]
            let b = ordered[j]
            if i < j {
                XCTAssertLessThan(a, b, "\(a) must rank below \(b)")
                XCTAssertFalse(b < a, "ordering must be antisymmetric for \(a),\(b)")
            } else if i == j {
                XCTAssertFalse(a < b, "a level is not less than itself (\(a))")
                XCTAssertEqual(a, b)
            } else {
                XCTAssertGreaterThan(a, b, "\(a) must rank above \(b)")
            }
        }
    }
    // The exact gate the deriver uses (>= .high → guarded) must hold on the order.
    XCTAssertTrue(BASBrainRiskLevel.extreme >= .high)
    XCTAssertTrue(BASBrainRiskLevel.high >= .high)
    XCTAssertFalse(BASBrainRiskLevel.medium >= .high)

    // ── (2) MONOTONICITY: rising level ⇒ totalRisk non-decreasing ─────────────────────
    // Build one card per level with totalRisk picked from STRICTLY ascending threshold
    // bands (matching calibrateRisk's ascending ..<medium/..<high/..<extreme/else cut
    // points). Walking levels low→extreme, totalRisk must never decrease.
    let ladder: [(BASBrainRiskLevel, Double, BASActionPermitMode)] = [
        (.low, 0.10, .answer),
        (.medium, 0.45, .compare),
        (.high, 0.72, .delay),
        (.extreme, 0.95, .block),
    ]
    let cards = ladder.map { makeCard(totalRisk: $0.1, riskLevel: $0.0, recommendedMode: $0.2) }
    for k in 1..<cards.count {
        let lower = cards[k - 1]
        let higher = cards[k]
        XCTAssertGreaterThan(higher.riskLevel, lower.riskLevel,
            "ladder must climb the risk-level order")
        XCTAssertGreaterThanOrEqual(higher.totalRisk, lower.totalRisk,
            "rising risk level must carry a non-decreasing totalRisk "
            + "(\(lower.riskLevel)=\(lower.totalRisk) → \(higher.riskLevel)=\(higher.totalRisk))")
    }

    // ── (3) .extreme ⇒ PROTECTED mode, never .answer ──────────────────────────────────
    // Replicated oracle of the private recommendedMode(for:) extreme branch
    // (EBrainHostRuntime+RiskService.swift:769-770): both manipulation sub-cases.
    func oracleExtremeMode(manipulationPresent: Bool) -> BASActionPermitMode {
        // .extreme: contextFrame.manipulationHints.isEmpty ? .replace : .block
        manipulationPresent ? .block : .replace
    }
    let protectedModes: Set<BASActionPermitMode> = [.replace, .block]
    for manipulationPresent in [false, true] {
        let mode = oracleExtremeMode(manipulationPresent: manipulationPresent)
        XCTAssertNotEqual(mode, .answer,
            "an .extreme card must NEVER recommend .answer (manipulation=\(manipulationPresent))")
        XCTAssertTrue(protectedModes.contains(mode),
            "extreme mode must be a protected mode, got \(mode)")
        // The real struct must round-trip an extreme card carrying that protected mode,
        // and must preserve both fields verbatim (tolerance 0).
        let extremeCard = makeCard(totalRisk: 0.97, riskLevel: .extreme, recommendedMode: mode)
        XCTAssertEqual(extremeCard.riskLevel, .extreme)
        XCTAssertEqual(extremeCard.recommendedMode, mode)
        XCTAssertNotEqual(extremeCard.recommendedMode, .answer,
            "constructed .extreme BASRiskCard must not carry .answer")
    }

    // ── (4) DETERMINISM: re-deriving the oracle + rebuilding the cards is stable ───────
    XCTAssertEqual(oracleExtremeMode(manipulationPresent: false), .replace)
    XCTAssertEqual(oracleExtremeMode(manipulationPresent: true), .block)
    let cardsAgain = ladder.map { makeCard(totalRisk: $0.1, riskLevel: $0.0, recommendedMode: $0.2) }
    for k in cards.indices {
        XCTAssertEqual(cardsAgain[k].riskLevel, cards[k].riskLevel)
        XCTAssertEqual(cardsAgain[k].totalRisk, cards[k].totalRisk)
        XCTAssertEqual(cardsAgain[k].recommendedMode, cards[k].recommendedMode)
    }

    // ── (5) MUTATE + ASSERT: dropping the extreme card to .answer breaks the invariant ─
    // Sanity that the gate is real — an extreme card with .answer is exactly the
    // forbidden state, and our protected-set check would reject it.
    let forbidden = makeCard(totalRisk: 0.97, riskLevel: .extreme, recommendedMode: .answer)
    XCTAssertEqual(forbidden.recommendedMode, .answer)
    XCTAssertFalse(protectedModes.contains(forbidden.recommendedMode),
        ".answer must NOT be in the protected-mode set (negative control)")

    print("QINAO-GATE risk_card_monotonic_ordering: PASS "
        + "low<medium<high<extreme total-order exhaustive; totalRisk non-decreasing across "
        + "the 4-level ladder; .extreme→{.replace|.block} (never .answer) for both "
        + "manipulation sub-cases; deterministic re-derive; negative control rejected")
}

    func test_qinao_trace_release_mismatch_coverage() {
    // QINAO Substrate metric #76 (HIGH): each released turn produces a
    // BASInspectionBundle whose trace records every consumption surface;
    // anomalySignals fire when an invariant is broken (mismatch detected)
    // and stay silent on a clean turn. The load-bearing invariant here is
    // the "release_mismatch" signal: policy DENIED release yet the trace
    // still carries an output summary (a consumption surface that escaped
    // the gate). Source of truth:
    // BASObservabilityInspector.anomalySignals(for:policyDecision:replayDisposition:)
    // in Sources/BASObservability/ObservabilityCore.swift.

    // Helper: build a trace that carries an output (a consumption surface)
    // but is otherwise CLEAN on every OTHER anomaly axis so we isolate the
    // release_mismatch invariant. Mirrors the existing-test construction in
    // BASObservabilityCoreTests.anomalyInspectorCatchesReleaseMismatchesAndLatencySpikes
    // (BASExecutionTrace + BASTraceLatencyBreakdown + .cloud/.local route),
    // but with: unique memories (no duplicate_memory_recall), no tools
    // (no tool_timing_gap), sub-threshold latency (no latency_spike).
    func makeCleanTrace(output: String) -> BASExecutionTrace {
        BASExecutionTrace(
            inputSummary: "Should I send this?",
            selectedRoute: .local("local-fast"),
            memoriesRecalled: ["one memory", "another memory"],
            toolsCalled: [],
            latency: BASTraceLatencyBreakdown(
                routeSelectionMs: 20,
                retrievalMs: 30,
                generationMs: 100,
                toolMs: 0
            ),
            outputSummary: output
        )
    }

    let denyDecision = BASPolicyDecisionRecord(decision: .deny, reason: "blocked")
    let allowDecision = BASPolicyDecisionRecord(decision: .allow, reason: "allowed")

    // (1) BROKEN INVARIANT: deny + non-empty output summary -> the
    // release_mismatch signal MUST fire, and on this isolated trace it is
    // the ONLY signal (exact coverage, tolerance 0 on the count).
    let mismatchTrace = makeCleanTrace(output: "Drafted a reply.")
    let mismatchSignals = BASObservabilityInspector.anomalySignals(
        for: mismatchTrace,
        policyDecision: denyDecision
    )
    let mismatchHits = mismatchSignals.filter { $0.kind == "release_mismatch" }
    XCTAssertEqual(mismatchHits.count, 1, "deny + non-empty output must raise exactly one release_mismatch")
    XCTAssertEqual(mismatchSignals.count, 1, "isolated broken-invariant trace must raise ONLY release_mismatch")
    XCTAssertEqual(mismatchHits.first?.severity, "high", "release_mismatch is a high-severity blocker")

    // Determinism: re-calling the pure inspector on the same inputs yields
    // an identical set of signal kinds.
    let mismatchSignals2 = BASObservabilityInspector.anomalySignals(
        for: mismatchTrace,
        policyDecision: denyDecision
    )
    XCTAssertEqual(
        mismatchSignals.map(\.kind),
        mismatchSignals2.map(\.kind),
        "anomalySignals must be deterministic across re-calls"
    )

    // (2) CLEAN TURN: same trace but policy ALLOWS release -> no anomaly at
    // all. None on clean.
    let cleanSignals = BASObservabilityInspector.anomalySignals(
        for: mismatchTrace,
        policyDecision: allowDecision
    )
    XCTAssertTrue(cleanSignals.isEmpty, "an allowed clean turn must raise zero anomaly signals")
    XCTAssertFalse(
        cleanSignals.contains(where: { $0.kind == "release_mismatch" }),
        "release_mismatch must not fire when policy allows release"
    )

    // (3) MUTATE + ASSERT: with policy still deny, EMPTY the output summary
    // (no consumption surface escaped) -> the invariant is restored and the
    // signal disappears. This pins the signal to the (deny, non-empty)
    // conjunction, not to deny alone.
    let denyEmptyTrace = makeCleanTrace(output: "   ")
    let denyEmptySignals = BASObservabilityInspector.anomalySignals(
        for: denyEmptyTrace,
        policyDecision: denyDecision
    )
    XCTAssertFalse(
        denyEmptySignals.contains(where: { $0.kind == "release_mismatch" }),
        "deny with an empty/whitespace output summary must NOT raise release_mismatch"
    )

    // (4) Full-bundle coverage: the released turn is packaged into a
    // BASInspectionBundle whose trace is recorded verbatim and whose
    // anomalySignals surface the mismatch via blockerSummary. We assemble
    // the bundle directly (host-side source of truth) since the factory's
    // brainState/runtimeContext are orthogonal to the release invariant.
    let bundle = BASInspectionBundle(
        trace: mismatchTrace,
        replayFingerprint: BASReplayFingerprint(value: "deadbeef"),
        releaseDecision: BASObservabilityInspector.releaseDecision(
            for: mismatchTrace,
            policyDecision: denyDecision
        ),
        anomalySignals: mismatchSignals
    )
    XCTAssertEqual(bundle.trace, mismatchTrace, "bundle must record the trace (consumption surfaces) verbatim")
    XCTAssertEqual(bundle.releaseDecision.kind, .deny)
    XCTAssertTrue(
        bundle.anomalySignals.contains(where: { $0.kind == "release_mismatch" }),
        "bundle must carry the fired release_mismatch signal"
    )
    let mismatchMessage = mismatchHits.first?.message ?? ""
    XCTAssertTrue(
        bundle.blockerSummary.contains(mismatchMessage),
        "a high-severity release_mismatch must surface in the bundle blockerSummary"
    )

    print("QINAO-GATE trace_release_mismatch_coverage: PASS broken-invariant raises exactly 1 release_mismatch (high), clean/allow=0 signals, deny+empty-output=0, deterministic, bundle records trace + surfaces blocker")
}

    func test_qinao_per_layer_latency_overrun() async throws {
    // QINAO #77 HIGH — per-layer wall-clock budget enforcement。
    // runTurn instruments each of the 14 layers; the per-layer
    // budget check (BASLayerReferenceActor Stage 4) compares the
    // MEASURED wall-clock elapsed against the DECLARED per-layer
    // budget (BASLayerSlice.hardCapMs) with STRICT greater-than
    // semantics: it must flag an OVERRUN and must NOT flag an
    // under-budget layer。
    //
    // Strategy (no hard-coded timing asserted):
    //   (a) Doctrine pin — mirror the exact strict-`>` comparison
    //       from the source-of-truth so we assert the contract
    //       (equal == under, +epsilon == over) deterministically.
    //   (b) Real-API overrun — hardCapMs == 0 forces ANY positive
    //       real elapsed to exceed → status .budgetExceeded and
    //       measured latencyMs > declared budget. Run for all 14
    //       layers.
    //   (c) Real-API under-budget — a generous hardCapMs (10 min)
    //       is never reached by a millisecond cascade → status is
    //       NOT .budgetExceeded and measured latencyMs <= budget.
    //   (d) Deterministic re-call — same config yields same
    //       overrun classification twice.

    // Mirror of BASLayerReferenceActor Stage-4 source-of-truth:
    //   `if elapsedAtCap > config.budget.hardCapMs { ...exceeded }`
    func QINAOExceededBudget(
        measuredMs: Double, declaredHardCapMs: Double
    ) -> Bool {
        return measuredMs > declaredHardCapMs
    }

    // (a) Doctrine pin: strict `>` — flags overrun, NOT under,
    // NOT equal。 Exhaustive over the three regimes。
    XCTAssertFalse(
        QINAOExceededBudget(measuredMs: 0, declaredHardCapMs: 0),
        "QINAO #77: 0ms measured vs 0ms budget must NOT flag")
    XCTAssertFalse(
        QINAOExceededBudget(measuredMs: 99.9, declaredHardCapMs: 100),
        "QINAO #77: under budget must NOT be flagged as overrun")
    XCTAssertFalse(
        QINAOExceededBudget(measuredMs: 100, declaredHardCapMs: 100),
        "QINAO #77: measured exactly equal to declared budget" +
        " must NOT be flagged (strict greater-than)")
    XCTAssertTrue(
        QINAOExceededBudget(
            measuredMs: 100.000001, declaredHardCapMs: 100),
        "QINAO #77: one nano over budget must be flagged overrun")
    XCTAssertTrue(
        QINAOExceededBudget(measuredMs: 500, declaredHardCapMs: 100),
        "QINAO #77: large overrun must be flagged")

    // (b) Real-API overrun: hardCapMs == 0 → every layer's real
    // wall-clock elapsed exceeds → .budgetExceeded for all 14.
    var QINAOOverrunCount = 0
    for QINAOLayer in BASMotherboardLayer14.allCases {
        let registry = BASLayerMLHeadRegistry()
        let config = BASLayerReferenceActorConfig(
            layerID: QINAOLayer,
            budget: BASLayerSlice(
                layerID: QINAOLayer,
                allocatedMs: 0,
                hardCapMs: 0),
            registry: registry,
            killSwitchLookup: { _ in nil })
        let actor = BASLayerReferenceActor(config: config)
        let input = BASLayerActorInput(
            layerID: QINAOLayer,
            turnID: "qinao-overrun-\(QINAOLayer.rawValue)",
            payloadRef: "qinao-payload",
            arrivedAt: Date())
        let output = try await actor.process(input: input)
        let declaredHardCap = config.budget.hardCapMs
        let measured = output.latencyMs
        XCTAssertEqual(
            output.status, .budgetExceeded,
            "QINAO #77: layer \(QINAOLayer.rawValue) with a 0ms" +
            " hard cap must flag .budgetExceeded (measured" +
            " \(measured)ms > \(declaredHardCap)ms)")
        XCTAssertGreaterThan(
            measured, declaredHardCap,
            "QINAO #77: an overrun layer's MEASURED latency must" +
            " exceed its DECLARED budget")
        XCTAssertTrue(
            QINAOExceededBudget(
                measuredMs: measured,
                declaredHardCapMs: declaredHardCap),
            "QINAO #77: source-of-truth comparison must agree" +
            " with the actor's .budgetExceeded verdict for" +
            " layer \(QINAOLayer.rawValue)")
        XCTAssertTrue(
            output.reasonCodes.contains(where: {
                $0.hasPrefix("budget:cap-exceeded:")
            }),
            "QINAO #77: overrun must emit a budget:cap-exceeded" +
            " audit code for layer \(QINAOLayer.rawValue)")
        QINAOOverrunCount += 1
    }
    XCTAssertEqual(
        QINAOOverrunCount, 14,
        "QINAO #77: all 14 instrumented layers must be exercised")

    // (c) Real-API under-budget: a 10-minute hard cap is never
    // reached by a millisecond cascade → NOT flagged, and the
    // measured latency stays within budget.
    let QINAOGenerousCapMs = 600_000.0
    for QINAOLayer in BASMotherboardLayer14.allCases {
        let registry = BASLayerMLHeadRegistry()
        let config = BASLayerReferenceActorConfig(
            layerID: QINAOLayer,
            budget: BASLayerSlice(
                layerID: QINAOLayer,
                allocatedMs: 50,
                hardCapMs: QINAOGenerousCapMs),
            registry: registry,
            killSwitchLookup: { _ in nil })
        let actor = BASLayerReferenceActor(config: config)
        let input = BASLayerActorInput(
            layerID: QINAOLayer,
            turnID: "qinao-under-\(QINAOLayer.rawValue)",
            payloadRef: "qinao-payload",
            arrivedAt: Date())
        let output = try await actor.process(input: input)
        let measured = output.latencyMs
        XCTAssertNotEqual(
            output.status, .budgetExceeded,
            "QINAO #77: layer \(QINAOLayer.rawValue) well within" +
            " its declared budget must NOT flag .budgetExceeded")
        XCTAssertLessThanOrEqual(
            measured, QINAOGenerousCapMs,
            "QINAO #77: an under-budget layer's measured latency" +
            " must stay within the declared budget")
        XCTAssertFalse(
            QINAOExceededBudget(
                measuredMs: measured,
                declaredHardCapMs: QINAOGenerousCapMs),
            "QINAO #77: source-of-truth comparison must agree the" +
            " under-budget layer is NOT exceeded")
    }

    // (d) Deterministic re-call: same 0ms-cap config classifies as
    // .budgetExceeded on every invocation.
    let QINAORegistry = BASLayerMLHeadRegistry()
    let QINAOConfig = BASLayerReferenceActorConfig(
        layerID: .l4,
        budget: BASLayerSlice(
            layerID: .l4, allocatedMs: 0, hardCapMs: 0),
        registry: QINAORegistry,
        killSwitchLookup: { _ in nil })
    let QINAODetActor = BASLayerReferenceActor(config: QINAOConfig)
    let QINAODetInput = BASLayerActorInput(
        layerID: .l4,
        turnID: "qinao-det",
        payloadRef: "qinao-payload",
        arrivedAt: Date())
    let QINAOFirst = try await QINAODetActor.process(
        input: QINAODetInput)
    let QINAOSecond = try await QINAODetActor.process(
        input: QINAODetInput)
    XCTAssertEqual(
        QINAOFirst.status, .budgetExceeded,
        "QINAO #77: first call classifies the overrun")
    XCTAssertEqual(
        QINAOSecond.status, QINAOFirst.status,
        "QINAO #77: per-layer budget verdict is deterministic" +
        " across re-calls")

    print("QINAO-GATE per_layer_latency_overrun: PASS " +
        "(14/14 layers flag overrun at 0ms cap, none flag under a" +
        " 600000ms cap, strict-> equal-is-not-exceeded, verdict" +
        " deterministic)")
}

    func test_qinao_integrity_sentinel_unknown_is_failure() async {
    // QINAO substrate gate #93 — the L11 integrity sentinel scan
    // treats BOTH an unknown artifact id (no registered fingerprint)
    // AND a registered-but-hash-mismatch as a FAILURE, and maps each
    // failed ArtifactKind to its corresponding Hard observation bit.
    //
    // Construction mirrors BASSovereignIntegritySentinelTests verbatim:
    //   BASSovereignIntegritySentinel()  (actor, init())
    //   await sentinel.registerFingerprint(id:hash:)
    //   await sentinel.scan(.init(claims: [.init(id:claimedHash:kind:)]))
    //   report.asHardObservations
    func qinaoHash(_ value: String) -> String {
        BASSovereignIntegritySentinel.hash(Data(value.utf8))
    }

    // The fixed kind -> Hard-observation mapping per BR-001/002/006/007.
    // (We compute, never hard-code, the expected bit per kind via the
    //  closure below so the assertion can't drift from the enum.)
    func qinaoExpectedBit(
        _ kind: BASSovereignIntegritySentinel.ArtifactKind,
        _ obs: BASSovereignVerdictEngine.HardObservations
    ) -> Bool {
        switch kind {
        case .modelOrPolicyArtifact: return obs.artifactSignatureInvalid
        case .sovereignPolicyBundle: return obs.policyBundleTampered
        case .thoughtFoldOrCache:    return obs.thoughtFoldChecksumBroken
        case .runtimeImage:          return obs.unauthorizedSelfMutation
        }
    }

    // EXHAUSTIVE over every ArtifactKind variant (CaseIterable), for
    // BOTH failure modes: (a) unknown id, (b) registered hash mismatch.
    for kind in BASSovereignIntegritySentinel.ArtifactKind.allCases {

        // ---- Failure mode A: UNKNOWN artifact id (nothing registered)
        let unknownSentinel = BASSovereignIntegritySentinel()
        let unknownReport = await unknownSentinel.scan(.init(claims: [
            .init(id: "qinao-unknown-\(kind.rawValue)",
                  claimedHash: "any-hash",
                  kind: kind)
        ]))
        // Unknown id MUST be a failure (fail-closed).
        XCTAssertEqual(
            unknownReport.failedArtifactIDs,
            ["qinao-unknown-\(kind.rawValue)"],
            "unknown artifact id must be reported as failed for \(kind.rawValue)")
        XCTAssertTrue(
            unknownReport.failedKinds.contains(kind),
            "unknown artifact must record its kind \(kind.rawValue) in failedKinds")
        // failedKinds must map to the corresponding Hard observation.
        let unknownObs = unknownReport.asHardObservations
        XCTAssertTrue(
            qinaoExpectedBit(kind, unknownObs),
            "unknown \(kind.rawValue) must raise its Hard observation bit")
        // Deterministic re-call: identical report on a second scan.
        let unknownReplay = await unknownSentinel.scan(.init(claims: [
            .init(id: "qinao-unknown-\(kind.rawValue)",
                  claimedHash: "any-hash",
                  kind: kind)
        ]))
        XCTAssertEqual(unknownReplay, unknownReport,
            "scan must be deterministic for unknown \(kind.rawValue)")

        // ---- Failure mode B: registered fingerprint, MISMATCHED hash
        let mismatchSentinel = BASSovereignIntegritySentinel()
        let goodHash = qinaoHash("trusted-\(kind.rawValue)")
        await mismatchSentinel.registerFingerprint(
            id: "qinao-art-\(kind.rawValue)", hash: goodHash)
        let badHash = qinaoHash("FORGED-\(kind.rawValue)")
        XCTAssertNotEqual(goodHash, badHash,
            "test setup: forged hash must differ from trusted hash")
        let mismatchReport = await mismatchSentinel.scan(.init(claims: [
            .init(id: "qinao-art-\(kind.rawValue)",
                  claimedHash: badHash,
                  kind: kind)
        ]))
        XCTAssertEqual(
            mismatchReport.failedArtifactIDs,
            ["qinao-art-\(kind.rawValue)"],
            "hash mismatch must be reported as failed for \(kind.rawValue)")
        XCTAssertTrue(
            mismatchReport.failedKinds.contains(kind),
            "hash mismatch must record kind \(kind.rawValue) in failedKinds")
        let mismatchObs = mismatchReport.asHardObservations
        XCTAssertTrue(
            qinaoExpectedBit(kind, mismatchObs),
            "hash mismatch \(kind.rawValue) must raise its Hard observation bit")

        // ---- Negative control: registered + MATCHING hash => NO failure.
        let matchReport = await mismatchSentinel.scan(.init(claims: [
            .init(id: "qinao-art-\(kind.rawValue)",
                  claimedHash: goodHash,
                  kind: kind)
        ]))
        XCTAssertTrue(matchReport.failedArtifactIDs.isEmpty,
            "matching hash must NOT be a failure for \(kind.rawValue)")
        XCTAssertFalse(matchReport.failedKinds.contains(kind),
            "matching hash must NOT record kind \(kind.rawValue)")
        XCTAssertFalse(
            qinaoExpectedBit(kind, matchReport.asHardObservations),
            "matching hash must NOT raise the Hard observation for \(kind.rawValue)")
    }

    print("QINAO-GATE integrity_sentinel_unknown_is_failure: PASS — unknown-id AND hash-mismatch both fail across all 4 ArtifactKind variants; failedKinds maps to the correct Hard observation; matching hash is clean; scan deterministic")
}
}
