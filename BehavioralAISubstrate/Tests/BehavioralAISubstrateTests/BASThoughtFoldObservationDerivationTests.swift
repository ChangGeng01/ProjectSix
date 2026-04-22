import XCTest
@testable import BASOrchestration

/// M62 — L3 思纹层 main-chain wiring.
///
/// Before M62 the thought fold was produced per turn and threaded
/// into the trace + sovereign verdict, but its structural anchors
/// (snapshot / rollback / resume / integrity / organ packages /
/// degradation) were never surfaced as typed per-subject evidence
/// on the main-chain thought frame. These tests pin the M62
/// behavior:
///
///   1. `BASThoughtFoldObservationBundle.derive(
///        fromThoughtFold:turnID:sessionID:emittedAt:)` emits a
///      bundle whose contents deterministically mirror the fold
///      (same fold → same bundle byte-for-byte).
///   2. The fold-sealed baseline always fires (coverage floor).
///   3. Snapshot / rollback / resume / integrity gates fire exactly
///      when their ref field is present + non-empty.
///   4. `organPackageBound` fires once per entry in
///      `organPackageRefs` (in array order).
///   5. `degradationFlagged` fires once per entry in
///      `degradedReasonCodes` (in array order).
///   6. Shape precedence: degraded > orphan > integrityBound >
///      snapshotted > quiet.
///   7. `BASThoughtFrame.withDerivedThoughtFoldObservationBundle(
///      fold:turnID:sessionID:emittedAt:)` returns a copy with the
///      bundle attached and leaves every other field untouched.
///   8. Budget stays clamped in [0, 1] across realistic fold
///      states.
final class BASThoughtFoldObservationDerivationTests: XCTestCase {

    // MARK: - Fixtures

    private let fixedDate = Date(timeIntervalSince1970: 2_200_000)
    private let turnID = "turn-l3-1"
    private let sessionID = "session-l3-1"

    /// Builds a `BASThoughtFold` with explicit knobs for every
    /// field that derivation reads. Defaults produce an "orphan"
    /// fold (sealed but no ark/integrity refs, no degradation) so
    /// individual paths can opt in.
    private func fold(
        foldID: String = "fold-1",
        checksum: String = "ck-1",
        restorePointer: String = "restore-1",
        snapshotRef: String? = nil,
        rollbackAnchorRef: String? = nil,
        resumeFrameRef: String? = nil,
        integrityWeaveRef: String? = nil,
        organPackageRefs: [String] = [],
        degradedReasonCodes: [String] = []
    ) -> BASThoughtFold {
        BASThoughtFold(
            foldID: foldID,
            compactSlots: [:],
            candidateSignatures: [],
            riskSnapshot: nil,
            hostEffectSummary: "eff-1",
            restorePointer: restorePointer,
            checksum: checksum,
            degradedReasonCodes: degradedReasonCodes,
            snapshotRef: snapshotRef,
            resumeFrameRef: resumeFrameRef,
            rollbackAnchorRef: rollbackAnchorRef,
            integrityWeaveRef: integrityWeaveRef,
            organPackageRefs: organPackageRefs)
    }

    private func derive(
        _ f: BASThoughtFold
    ) -> BASThoughtFoldObservationBundle {
        BASThoughtFoldObservationBundle.derive(
            fromThoughtFold: f,
            turnID: turnID,
            sessionID: sessionID,
            emittedAt: fixedDate)
    }

    // MARK: - Path 1: baseline (orphan fold — sealed, no refs)

    func testOrphanFoldEmitsOnlyFoldSealed() {
        let bundle = derive(fold())
        XCTAssertEqual(bundle.turnID, turnID)
        XCTAssertEqual(bundle.sessionID, sessionID)
        XCTAssertEqual(bundle.emittedAt, fixedDate)
        XCTAssertEqual(bundle.observations.count, 1)
        XCTAssertTrue(bundle.hasFoldSeal)
        XCTAssertTrue(bundle.hasCoreSignalCoverage)
        XCTAssertFalse(bundle.hasAnyArkAnchor)
        XCTAssertFalse(bundle.hasIntegrityBinding)
        XCTAssertFalse(bundle.hasAnyDegradation)
        for obs in bundle.observations {
            XCTAssertEqual(obs.shape, .orphan)
        }
        XCTAssertEqual(
            bundle.observations.first?.subjectID, "fold-1")
    }

    // MARK: - Path 2: snapshotted shape (snapshot ref only)

    func testSnapshotRefTriggersSnapshottedShape() {
        let bundle = derive(fold(snapshotRef: "snap-1"))
        for obs in bundle.observations {
            XCTAssertEqual(obs.shape, .snapshotted)
        }
        XCTAssertTrue(bundle.hasAnyArkAnchor)
        let snap = bundle.observations(of: .snapshotAnchored).first
        XCTAssertEqual(snap?.subjectID, "snap-1")
    }

    func testRollbackRefTriggersSnapshottedShape() {
        let bundle = derive(fold(rollbackAnchorRef: "rb-1"))
        for obs in bundle.observations {
            XCTAssertEqual(obs.shape, .snapshotted)
        }
        let rb = bundle.observations(of: .rollbackAnchored).first
        XCTAssertEqual(rb?.subjectID, "rb-1")
    }

    func testResumeRefTriggersSnapshottedShape() {
        let bundle = derive(fold(resumeFrameRef: "resume-1"))
        for obs in bundle.observations {
            XCTAssertEqual(obs.shape, .snapshotted)
        }
        let r = bundle.observations(of: .resumeAnchored).first
        XCTAssertEqual(r?.subjectID, "resume-1")
    }

    func testAllArkRefsEmitCombinedSnapshottedShape() {
        let bundle = derive(fold(
            snapshotRef: "snap-1",
            rollbackAnchorRef: "rb-1",
            resumeFrameRef: "resume-1"))
        XCTAssertEqual(bundle.observations.count, 4)
        for obs in bundle.observations {
            XCTAssertEqual(obs.shape, .snapshotted)
        }
    }

    // MARK: - Path 3: integrityBound beats snapshotted

    func testIntegrityRefTriggersIntegrityBoundShape() {
        let bundle = derive(fold(
            snapshotRef: "snap-1",
            integrityWeaveRef: "integrity-1"))
        for obs in bundle.observations {
            XCTAssertEqual(obs.shape, .integrityBound)
        }
        XCTAssertTrue(bundle.hasIntegrityBinding)
        let integ = bundle.observations(of: .integrityBound).first
        XCTAssertEqual(integ?.subjectID, "integrity-1")
    }

    // MARK: - Path 4: degraded beats everything

    func testDegradationFlagTriggersDegradedShape() {
        let bundle = derive(fold(
            snapshotRef: "snap-1",
            integrityWeaveRef: "integrity-1",
            degradedReasonCodes: ["budget.overflow"]))
        for obs in bundle.observations {
            XCTAssertEqual(obs.shape, .degraded)
        }
        XCTAssertTrue(bundle.hasAnyDegradation)
    }

    func testMultipleDegradationReasonsAllFire() {
        let bundle = derive(fold(
            degradedReasonCodes: [
                "budget.overflow",
                "risk.unconverged",
                "integrity.checksum.mismatch"
            ]))
        let deg = bundle.observations(of: .degradationFlagged)
        XCTAssertEqual(deg.count, 3)
        XCTAssertEqual(
            deg.map { $0.subjectID },
            [
                "budget.overflow",
                "risk.unconverged",
                "integrity.checksum.mismatch"
            ])
    }

    // MARK: - Path 5: organ package iteration

    func testOrganPackageRefsEmitOneSignalPerEntry() {
        let bundle = derive(fold(
            snapshotRef: "snap-1",
            organPackageRefs: ["pkg-a", "pkg-b", "pkg-c"]))
        let pkg = bundle.observations(of: .organPackageBound)
        XCTAssertEqual(pkg.count, 3)
        XCTAssertEqual(
            pkg.map { $0.subjectID }, ["pkg-a", "pkg-b", "pkg-c"])
        XCTAssertTrue(bundle.hasAnyOrganPackageBinding)
    }

    // MARK: - Path 6: empty-string ref behaves as absent

    func testEmptyStringRefsDoNotEmit() {
        let bundle = derive(fold(
            snapshotRef: "",
            rollbackAnchorRef: "   ",
            resumeFrameRef: "",
            integrityWeaveRef: ""))
        // Fold init itself trims refs → nil, so nothing except
        // foldSealed fires, and shape is orphan.
        XCTAssertEqual(bundle.observations.count, 1)
        for obs in bundle.observations {
            XCTAssertEqual(obs.shape, .orphan)
        }
    }

    // MARK: - Path 7: determinism

    func testDeterministicBundleForIdenticalInputs() {
        let f = fold(
            snapshotRef: "snap-1",
            organPackageRefs: ["pkg-a"],
            degradedReasonCodes: ["d1"])
        let first = derive(f)
        let second = derive(f)
        XCTAssertEqual(first, second)
    }

    // MARK: - Path 8: withDerived helper preserves rest of frame

    func testWithDerivedFoldBundleAttachesAndPreservesFrame() {
        let frame = BASThoughtFrame(
            stepIndex: 11,
            decomposeRef: "dcm-l3",
            memoryRefs: ["m-a", "m-b"],
            stabilityScore: 0.66)
        let withBundle = frame
            .withDerivedThoughtFoldObservationBundle(
                fold: fold(
                    snapshotRef: "snap-1",
                    integrityWeaveRef: "integrity-1"),
                turnID: turnID,
                sessionID: sessionID,
                emittedAt: fixedDate)
        XCTAssertEqual(withBundle.stepIndex, 11)
        XCTAssertEqual(withBundle.decomposeRef, "dcm-l3")
        XCTAssertEqual(withBundle.memoryRefs, ["m-a", "m-b"])
        XCTAssertEqual(withBundle.stabilityScore, 0.66)
        XCTAssertNotNil(withBundle.thoughtFoldObservationBundle)
        XCTAssertTrue(
            withBundle.thoughtFoldObservationBundle!
                .hasIntegrityBinding)
    }

    func testWithDerivedHelperIsDeterministic() {
        let frame = BASThoughtFrame(
            stepIndex: 1,
            decomposeRef: "dcm-x")
        let f = fold(snapshotRef: "snap-1")
        let first = frame
            .withDerivedThoughtFoldObservationBundle(
                fold: f,
                turnID: turnID,
                sessionID: sessionID,
                emittedAt: fixedDate)
        let second = frame
            .withDerivedThoughtFoldObservationBundle(
                fold: f,
                turnID: turnID,
                sessionID: sessionID,
                emittedAt: fixedDate)
        XCTAssertEqual(
            first.thoughtFoldObservationBundle,
            second.thoughtFoldObservationBundle)
    }

    // MARK: - Path 9: content fields encode ref payloads

    func testFoldSealedContentEncodesChecksumAndRestorePointer() {
        let bundle = derive(fold(
            foldID: "fold-7",
            checksum: "ck-abc",
            restorePointer: "restore-xyz"))
        let sealed = bundle.observations(of: .foldSealed).first!
        XCTAssertTrue(sealed.content.contains(
            "l3.fold.sealed:fold-7"))
        XCTAssertTrue(sealed.content.contains(".checksum:ck-abc"))
        XCTAssertTrue(sealed.content.contains(
            ".restorePointer:restore-xyz"))
    }

    func testIntegrityContentEncodesRef() {
        let bundle = derive(fold(
            integrityWeaveRef: "integrity-7"))
        let integ = bundle.observations(
            of: .integrityBound).first!
        XCTAssertTrue(integ.content.contains(
            "l3.integrity.bound:integrity-7"))
        XCTAssertEqual(integ.subjectID, "integrity-7")
    }

    // MARK: - Path 10: budget cost total

    func testBudgetCostSumsCorrectlyUnderRealisticLoad() {
        // fold-sealed (0.05) + snapshot (0.08) + rollback (0.08)
        //   + resume (0.05) + integrity (0.12) + 2 pkgs (0.06)
        //   + 1 degradation (0.20) = 0.64
        let bundle = derive(fold(
            snapshotRef: "snap-1",
            rollbackAnchorRef: "rb-1",
            resumeFrameRef: "resume-1",
            integrityWeaveRef: "integrity-1",
            organPackageRefs: ["pkg-a", "pkg-b"],
            degradedReasonCodes: ["d1"]))
        let total = BASThoughtFoldSignalBudget.totalCost(
            for: bundle)
        XCTAssertEqual(total, 0.64, accuracy: 0.0001)
        XCTAssertLessThanOrEqual(total, 1.0)
        XCTAssertGreaterThanOrEqual(total, 0.0)
    }

    func testBudgetClampsUnderHighVolumeDegradation() {
        // 10 degradation reasons → 2.0 raw → should clamp to 1.0.
        let codes = (0..<10).map { "deg-\($0)" }
        let bundle = derive(fold(degradedReasonCodes: codes))
        let total = BASThoughtFoldSignalBudget.totalCost(
            for: bundle)
        XCTAssertLessThanOrEqual(total, 1.0)
    }

    // MARK: - Path 11: Codable round trip

    func testBundleCodableRoundTripPreservesSignals() throws {
        let bundle = derive(fold(
            snapshotRef: "snap-1",
            integrityWeaveRef: "integrity-1",
            organPackageRefs: ["pkg-a"],
            degradedReasonCodes: ["d1"]))
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(bundle)
        let decoder = JSONDecoder()
        let roundTrip = try decoder.decode(
            BASThoughtFoldObservationBundle.self, from: data)
        XCTAssertEqual(roundTrip, bundle)
    }

    func testThoughtFrameCodableRoundTripIncludesFoldBundle()
    throws {
        var frame = BASThoughtFrame(
            stepIndex: 2,
            decomposeRef: "dcm-y",
            stabilityScore: 0.5)
        frame = frame
            .withDerivedThoughtFoldObservationBundle(
                fold: fold(snapshotRef: "snap-1"),
                turnID: "t",
                sessionID: "s",
                emittedAt: fixedDate)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(frame)
        let decoder = JSONDecoder()
        let roundTrip = try decoder.decode(
            BASThoughtFrame.self, from: data)
        XCTAssertEqual(
            roundTrip.thoughtFoldObservationBundle,
            frame.thoughtFoldObservationBundle)
    }

    // MARK: - Path 12: ledger

    func testLedgerRecordsBundleAndSnapshots() async {
        let ledger = BASThoughtFoldObservationLedger(capacity: 2)
        let a = derive(fold(foldID: "fold-a"))
        let b = derive(fold(foldID: "fold-b"))
        let c = derive(fold(foldID: "fold-c"))
        await ledger.record(a)
        await ledger.record(b)
        await ledger.record(c)
        let snap = await ledger.snapshot()
        XCTAssertEqual(snap.count, 2)
        XCTAssertEqual(snap.first, b)
        XCTAssertEqual(snap.last, c)
    }

    func testLedgerFiltersBySessionAndTurn() async {
        let ledger = BASThoughtFoldObservationLedger()
        let a = BASThoughtFoldObservationBundle.derive(
            fromThoughtFold: fold(),
            turnID: "tA",
            sessionID: "sA",
            emittedAt: fixedDate)
        let b = BASThoughtFoldObservationBundle.derive(
            fromThoughtFold: fold(),
            turnID: "tB",
            sessionID: "sB",
            emittedAt: fixedDate)
        await ledger.record(a)
        await ledger.record(b)
        let bySession = await ledger.bundles(forSession: "sA")
        XCTAssertEqual(bySession.count, 1)
        XCTAssertEqual(bySession.first?.turnID, "tA")
        let byTurn = await ledger.bundle(forTurn: "tB")
        XCTAssertEqual(byTurn?.sessionID, "sB")
    }

    // MARK: - Path 13: filter helpers

    func testObservationsForShapeFiltersBundle() {
        let bundle = derive(fold(
            integrityWeaveRef: "integrity-1"))
        let integ = bundle.observations(
            forShape: .integrityBound)
        XCTAssertEqual(integ.count, bundle.observations.count)
    }

    func testObservationsForSubjectFiltersBundle() {
        let bundle = derive(fold(
            foldID: "fold-99",
            snapshotRef: "snap-99"))
        let byFold = bundle.observations(
            forSubject: "fold-99")
        XCTAssertEqual(byFold.count, 1)
        XCTAssertEqual(byFold.first?.kind, .foldSealed)
        let bySnap = bundle.observations(
            forSubject: "snap-99")
        XCTAssertEqual(bySnap.count, 1)
        XCTAssertEqual(bySnap.first?.kind, .snapshotAnchored)
    }

    // MARK: - Path 14: subjectIDs preserve first-seen order

    func testSubjectIDsPreserveEmissionOrder() {
        let bundle = derive(fold(
            foldID: "fold-1",
            snapshotRef: "snap-1",
            integrityWeaveRef: "integrity-1",
            organPackageRefs: ["pkg-a"]))
        let subjects = bundle.subjectIDs
        XCTAssertEqual(subjects, [
            "fold-1", "snap-1", "integrity-1", "pkg-a"
        ])
    }
}
