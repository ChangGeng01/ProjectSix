import XCTest
import BASRuntimeCore
@testable import BASWorldPrior
@testable import BASPolicy
@testable import BASMemory
@testable import BASOrchestration
@testable import BASLeaseLife
@testable import BASOrgan
@testable import BASSovereign

/// M43 — end-to-end 14-layer reconciliation integration tests.
///
/// The M32/M37/M38/M39/M40/M41/M42 wave closed per-layer coverage
/// projections at 14-of-14. `BASObservationCoverageProjectionTests
/// .testEightLayerReconciliationAssemblesFullReport` already proved
/// the eight *bundle-based* layers (L4 / L6 / L7 / L9 / L10 / L11 /
/// L12 / L13) compose into one `BASObservationReconciliationReport`.
/// This file closes the composability proof for the full stack: a
/// minimally-compliant fixture for every one of the **14 cognitive
/// layers** — bundle-based *and* non-bundle-based (L1 / L2 / L3 / L5
/// / L8 / L14) — feeds into a single report and the report is
/// `isFullyObserved(expected: BASCognitiveLayer.allCases)`.
///
/// Deliberately minimal per-layer content — we're proving cross-layer
/// composition, not re-testing each layer's internal semantics (those
/// live in the dedicated per-layer coverage test files).
final class BASFourteenLayerReconciliationTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)
    private let turnID = "t-14"
    private let sessionID = "s-14"

    // MARK: - Per-layer fixtures

    private func l1Summary() -> BASObservationCoverageSummary {
        // L1 — lease & life. A nominal guard-level TurnRecorded with
        // lung + thermal is the minimum structural signal.
        let lung = BASLungStateAccumulator.Snapshot(
            pressure: 0.2,
            turnCount: 1,
            lastTurnAt: t0,
            lastDecayAt: t0)
        let reading = BASThermalTwin.Reading(
            osState: .fair,
            thermalLevel: .warm,
            guardLevel: .nominal,
            accumulatedPressure: 0.2,
            observedAt: t0)
        let recorded = BASLeaseLifeCoordinator.TurnRecorded(
            lung: lung,
            thermal: reading,
            cancelledBreathIDs: [])
        return recorded.coverageSummary(
            turnID: turnID, sessionID: sessionID)
    }

    private func l2Summary() -> BASObservationCoverageSummary {
        // L2 — neural organ registry. Two-tier coverage (scout+core)
        // via the pure snapshot path.
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
            turnID: turnID,
            sessionID: sessionID,
            emittedAt: t0)
    }

    private func l3Summary() -> BASObservationCoverageSummary {
        // L3 — thought fold. Minimal healthy fold carries integrity
        // anchor + restore pointer and no degraded codes.
        let fold = BASThoughtFold(
            foldID: "fold-14",
            compactSlots: ["task": "scan"],
            candidateSignatures: ["cand-a"],
            hostEffectSummary: "neutral",
            restorePointer: "restore-14",
            checksum: "chk-14",
            organPackageRefs: ["pkg-a"])
        return fold.coverageSummary(
            turnID: turnID, sessionID: sessionID, emittedAt: t0)
    }

    private func l4Summary() -> BASObservationCoverageSummary {
        BASWorldPriorObservationBundle(
            turnID: turnID, sessionID: sessionID,
            observations: [
                BASWorldPriorObservation(
                    kind: .templateMatched, templateID: "tpl-a",
                    evidenceLevel: .plausible,
                    salience: 0.5, confidence: 0.5,
                    content: "x", observedAt: t0),
                BASWorldPriorObservation(
                    kind: .counterfactualSeeded, templateID: "tpl-a",
                    evidenceLevel: .plausible,
                    salience: 0.5, confidence: 0.5,
                    content: "x", observedAt: t0)
            ],
            emittedAt: t0).coverageSummary
    }

    private func l5Summary() -> BASObservationCoverageSummary {
        // L5 — host constitution pipeline. Pure path: just the
        // snapshot is enough.
        let snap = BASHostCandidatePipelineObservationSnapshot(
            activeVersionID: "host.v1",
            committedVersionIDs: ["host.v1"],
            pendingCandidateIDs: [],
            rejectedCandidateIDs: [],
            frozenVersionIDs: [])
        return BASHostCandidatePipeline.projectCoverage(
            from: snap,
            turnID: turnID,
            sessionID: sessionID,
            emittedAt: t0)
    }

    private func l6Summary() -> BASObservationCoverageSummary {
        BASPresenceObservationBundle(
            turnID: turnID, sessionID: sessionID,
            observations: [
                BASPresenceObservation(
                    channel: .task,
                    salience: 0.5, confidence: 0.5,
                    content: "x", observedAt: t0),
                BASPresenceObservation(
                    channel: .risk,
                    salience: 0.5, confidence: 0.5,
                    content: "x", observedAt: t0),
                BASPresenceObservation(
                    channel: .manipulation,
                    salience: 0.5, confidence: 0.5,
                    content: "x", observedAt: t0)
            ],
            emittedAt: t0).coverageSummary
    }

    private func l7Summary() -> BASObservationCoverageSummary {
        BASDecompositionObservationBundle(
            turnID: turnID, sessionID: sessionID,
            observations: [
                BASDecompositionObservation(
                    kind: .factShard,
                    salience: 0.5, confidence: 0.5,
                    content: "x", observedAt: t0),
                BASDecompositionObservation(
                    kind: .contradiction,
                    salience: 0.5, confidence: 0.5,
                    content: "x", observedAt: t0),
                BASDecompositionObservation(
                    kind: .mirrorDraft,
                    salience: 0.5, confidence: 0.5,
                    content: "x", observedAt: t0)
            ],
            emittedAt: t0).coverageSummary
    }

    private func l8Summary() async -> BASObservationCoverageSummary {
        // L8 — memory tiering. One profile through the reconciler
        // gives us one "hold" decision.
        let clockDate = t0
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
                observedAt: t0)
        ])
        return outcome.coverageSummary(
            turnID: turnID, sessionID: sessionID)
    }

    private func l9Summary() -> BASObservationCoverageSummary {
        BASCandidateObservationBundle(
            turnID: turnID, sessionID: sessionID,
            observations: [
                BASCandidateObservation(
                    kind: .candidate, candidateID: "c-a",
                    salience: 0.5, confidence: 0.5,
                    content: "x", observedAt: t0),
                BASCandidateObservation(
                    kind: .reversibilitySignal, candidateID: "c-a",
                    salience: 0.5, confidence: 0.5,
                    content: "x", observedAt: t0),
                BASCandidateObservation(
                    kind: .guardianBranch, candidateID: "c-a",
                    salience: 0.5, confidence: 0.5,
                    content: "x", observedAt: t0)
            ],
            emittedAt: t0).coverageSummary
    }

    private func l10Summary() -> BASObservationCoverageSummary {
        BASTribunalObservationBundle(
            turnID: turnID, sessionID: sessionID,
            observations: [
                BASTribunalObservation(
                    kind: .vote, voice: .baseSelf,
                    disposition: .affirm, subjectID: "sub",
                    salience: 0.5, confidence: 0.5,
                    content: "x", observedAt: t0),
                BASTribunalObservation(
                    kind: .vote, voice: .ruleSelf,
                    disposition: .affirm, subjectID: "sub",
                    salience: 0.5, confidence: 0.5,
                    content: "x", observedAt: t0),
                BASTribunalObservation(
                    kind: .vote, voice: .aspireSelf,
                    disposition: .affirm, subjectID: "sub",
                    salience: 0.5, confidence: 0.5,
                    content: "x", observedAt: t0),
                BASTribunalObservation(
                    kind: .convergence, voice: nil,
                    disposition: nil, subjectID: "sub",
                    salience: 0.5, confidence: 0.5,
                    content: "x", observedAt: t0)
            ],
            emittedAt: t0).coverageSummary
    }

    private func l11Summary() -> BASObservationCoverageSummary {
        BASRiskObservationBundle(
            turnID: turnID, sessionID: sessionID,
            observations: [
                BASRiskObservation(
                    kind: .hazardReading, intentID: "i",
                    salience: 0.5, confidence: 0.5,
                    content: "x", observedAt: t0),
                BASRiskObservation(
                    kind: .irreversibilityReading, intentID: "i",
                    salience: 0.5, confidence: 0.5,
                    content: "x", observedAt: t0),
                BASRiskObservation(
                    kind: .harmPotentialReading, intentID: "i",
                    salience: 0.5, confidence: 0.5,
                    content: "x", observedAt: t0)
            ],
            emittedAt: t0).coverageSummary
    }

    private func l12Summary() -> BASObservationCoverageSummary {
        BASSoftHandObservationBundle(
            turnID: turnID, sessionID: sessionID,
            observations: [
                BASSoftHandObservation(
                    kind: .selection, mode: .compare,
                    subjectID: "sub",
                    salience: 0.5, confidence: 0.5,
                    content: "x", observedAt: t0),
                BASSoftHandObservation(
                    kind: .render, mode: .compare,
                    subjectID: "sub",
                    salience: 0.5, confidence: 0.5,
                    content: "x", observedAt: t0)
            ],
            emittedAt: t0).coverageSummary
    }

    private func l13Summary() -> BASObservationCoverageSummary {
        BASShadowTrialObservationBundle(
            turnID: turnID, sessionID: sessionID,
            observations: [
                BASShadowTrialObservation(
                    kind: .ticketIssued, ticketID: "tk",
                    salience: 0.5, confidence: 0.5,
                    content: "x", observedAt: t0),
                BASShadowTrialObservation(
                    kind: .trialRun, ticketID: "tk",
                    salience: 0.5, confidence: 0.5,
                    content: "x", observedAt: t0),
                BASShadowTrialObservation(
                    kind: .parityVerified, ticketID: "tk",
                    salience: 0.5, confidence: 0.5,
                    content: "x", observedAt: t0)
            ],
            emittedAt: t0).coverageSummary
    }

    private func l14Summary() -> BASObservationCoverageSummary {
        // L14 — sovereign audit ledger. Use the pure projection path
        // so we don't have to spin up a full ledger actor.
        let entry = BASSovereignAuditEntry(
            auditID: "a-1",
            sessionID: sessionID,
            turnID: turnID,
            verdictRef: "v-1",
            ruleIDs: ["BR-001"],
            signalRefs: [],
            actionRefs: [],
            snapshotRef: "snap-1",
            actor: .system,
            signature: "",
            appendedAt: t0)
        let wrapped = BASSovereignAuditLedger.AppendedEntry(
            entry: entry,
            priorHash: "GENESIS",
            selfHash: "x")
        return BASSovereignAuditLedger.projectCoverage(
            from: [wrapped],
            turnID: turnID,
            sessionID: sessionID,
            emittedAt: t0)
    }

    // MARK: - The 14-layer wave-closing assertion

    func testFourteenLayerReconciliationAssemblesFullReport() async {
        // Build a summary for every cognitive layer, compose them
        // into one report, and assert the report is fully observed
        // against the complete `BASCognitiveLayer` enum.
        let summaries: [BASObservationCoverageSummary] = [
            l1Summary(),
            l2Summary(),
            l3Summary(),
            l4Summary(),
            l5Summary(),
            l6Summary(),
            l7Summary(),
            await l8Summary(),
            l9Summary(),
            l10Summary(),
            l11Summary(),
            l12Summary(),
            l13Summary(),
            l14Summary()
        ]
        XCTAssertEqual(
            summaries.count, 14,
            "must collect one summary per cognitive layer")

        var report = BASObservationReconciliationReport(
            turnID: turnID, sessionID: sessionID)
        for summary in summaries {
            report = report.appending(summary)
        }

        // Every layer is covered, in insertion order.
        XCTAssertEqual(report.coveredLayers.count, 14)
        XCTAssertEqual(
            Set(report.coveredLayers),
            Set(BASCognitiveLayer.allCases),
            "report covers every cognitive layer")

        // No layer is missing against the full enum set.
        XCTAssertTrue(
            report.missingLayers(
                expected: BASCognitiveLayer.allCases).isEmpty)

        // Every reporting layer carries core signal coverage — each
        // fixture above is minimally healthy by construction.
        XCTAssertTrue(
            report.layersWithoutCoreCoverage.isEmpty,
            "every layer's fixture is healthy; none degraded")

        // The wave-closing structural assertion.
        XCTAssertTrue(
            report.isFullyObserved(
                expected: BASCognitiveLayer.allCases),
            "14-of-14 fully observed against allCases")
    }

    // MARK: - Composition invariants

    func testReportTotalsSumAcrossAllFourteenLayers() async {
        let summaries: [BASObservationCoverageSummary] = [
            l1Summary(),
            l2Summary(),
            l3Summary(),
            l4Summary(),
            l5Summary(),
            l6Summary(),
            l7Summary(),
            await l8Summary(),
            l9Summary(),
            l10Summary(),
            l11Summary(),
            l12Summary(),
            l13Summary(),
            l14Summary()
        ]
        var report = BASObservationReconciliationReport(
            turnID: turnID, sessionID: sessionID)
        for s in summaries {
            report = report.appending(s)
        }
        let manualTotal = summaries.reduce(0) {
            $0 + $1.totalObservations
        }
        XCTAssertEqual(
            report.totalObservations, manualTotal,
            "report totals must equal the sum of per-layer totals")
        // Budget is clamped to [0, 1]; per-layer budgets are already
        // clamped. Assert the reducer holds the clamp and is within
        // bounds.
        XCTAssertGreaterThanOrEqual(report.totalBudgetCost, 0)
        XCTAssertLessThanOrEqual(report.totalBudgetCost, 1)
    }

    func testMissingLayersDetectedOnPartialCoverage() async {
        // Drop three layers to prove `missingLayers(expected:)` and
        // `isFullyObserved(expected:)` catch the hole correctly when
        // the L14 reconciler builds partial reports mid-turn.
        let summaries: [BASObservationCoverageSummary] = [
            l1Summary(),
            l2Summary(),
            l3Summary(),
            l4Summary(),
            // L5 missing
            l6Summary(),
            l7Summary(),
            await l8Summary(),
            l9Summary(),
            l10Summary(),
            // L11 missing
            l12Summary(),
            l13Summary()
            // L14 missing
        ]
        var report = BASObservationReconciliationReport(
            turnID: turnID, sessionID: sessionID)
        for s in summaries {
            report = report.appending(s)
        }
        let expected = BASCognitiveLayer.allCases
        let missing = report.missingLayers(expected: expected)
        XCTAssertEqual(
            Set(missing),
            Set([.hostConstitution, .riskClimate, .sovereign]),
            "partial coverage must name exactly the three absent layers")
        XCTAssertFalse(
            report.isFullyObserved(expected: expected))
    }

    func testSummariesWithMismatchedTurnAreSilentlyDropped() async {
        // `BASObservationReconciliationReport`'s invariant: summaries
        // whose turn/session disagree with the report's own
        // turn/session are dropped — they can never cross boundaries
        // in a single report.
        let stray = BASSoftHandObservationBundle(
            turnID: "other-turn", sessionID: "other-session",
            observations: [
                BASSoftHandObservation(
                    kind: .selection, mode: .compare,
                    subjectID: "sub",
                    salience: 0.5, confidence: 0.5,
                    content: "x", observedAt: t0)
            ],
            emittedAt: t0).coverageSummary

        var report = BASObservationReconciliationReport(
            turnID: turnID, sessionID: sessionID,
            summaries: [l3Summary()])
        report = report.appending(stray)
        XCTAssertEqual(report.coveredLayers, [.thoughtFold])
        XCTAssertNil(
            report.summary(forLayer: .gentleHand),
            "a cross-turn summary must never infect a report")
    }

    func testCognitiveLayerEnumHasExactlyFourteenCases() {
        // Structural guard: if someone adds a 15th layer, this test
        // becomes the loud signal — the M43 integration test needs a
        // matching fixture, and the claim "14-of-14 fully observed"
        // needs an audit.
        XCTAssertEqual(
            BASCognitiveLayer.allCases.count, 14,
            "cognitive-layer enum must stay at 14 cases; "
            + "add a matching fixture if this fails")
    }
}
