import XCTest
@testable import BASMemory
@testable import BASOrchestration

/// M63 — L8 海马层 main-chain wiring.
///
/// Before M63 the memory bundle was retrieved / normalized per turn
/// and threaded into the trace + sovereign verdict, but its
/// structural content (per-atom promotion state, top-level conflict
/// refs, quarantine records, forget cascades) was never surfaced as
/// typed per-subject evidence on the main-chain thought frame.
/// These tests pin the M63 behavior:
///
///   1. `BASHippocampalMemoryObservationBundle.derive(
///        fromMemoryBundle:turnID:sessionID:emittedAt:)` emits a
///      bundle whose contents deterministically mirror the memory
///      bundle (same input → same bundle byte-for-byte).
///   2. The bundle-retrieved baseline always fires when a bundle is
///      present (coverage floor); nil bundle → empty observation
///      list.
///   3. Per-atom signals fire once per atom with precedence
///      `atomFrozen > atomAdmitted > atomCandidate > atomRetired`
///      on the `(frozen: Bool, promotionState)` pair.
///   4. `conflictFlagged` fires once per entry in `conflictRefs`.
///   5. `quarantineRecorded` fires once per entry in
///      `temporalField.quarantineRecords`.
///   6. `forgetCascadeBound` fires once per entry in
///      `temporalField.forgetCascades`.
///   7. Shape precedence: forgetting > quarantined > conflicted >
///      empty > quiet.
///   8. `BASThoughtFrame.withDerivedHippocampalMemoryObservationBundle(
///      memoryBundle:turnID:sessionID:emittedAt:)` returns a copy
///      with the bundle attached and leaves every other field
///      untouched.
///   9. Budget stays clamped in [0, 1] across realistic bundle
///      states.
final class BASHippocampalMemoryObservationDerivationTests:
    XCTestCase {

    // MARK: - Fixtures

    private let fixedDate = Date(timeIntervalSince1970: 2_300_000)
    private let turnID = "turn-l8-1"
    private let sessionID = "session-l8-1"

    /// Builds a `BASMemoryAtom`. Defaults produce a candidate,
    /// unfrozen hot atom.
    private func atom(
        id: String = "atom-1",
        type: BASMemoryAtomContentType = .hot,
        state: BASPromotionState = .candidate,
        frozen: Bool = false,
        confidence: Double = 0.7
    ) -> BASMemoryAtom {
        BASMemoryAtom(
            memoryID: id,
            summary: "summary-" + id,
            contentType: type,
            source: "src",
            confidence: confidence,
            conflictFingerprint: "fp-" + id,
            promotionState: state,
            frozen: frozen)
    }

    /// Builds a `BASMemoryQuarantineRecord` with a single memoryRef
    /// and reason codes.
    private func quarantine(
        id: String = "q-1",
        memoryRef: String = "m-q-1",
        reasons: [String] = ["contamination.drift"]
    ) -> BASMemoryQuarantineRecord {
        BASMemoryQuarantineRecord(
            quarantineID: id,
            memoryRef: memoryRef,
            reasonCodes: reasons)
    }

    /// Builds a `BASMemoryForgetCascade` with root targets.
    private func cascade(
        id: String = "c-1",
        roots: [String] = ["atom-root-1"],
        state: String = "in_progress"
    ) -> BASMemoryForgetCascade {
        BASMemoryForgetCascade(
            cascadeID: id,
            rootTargets: roots,
            executionState: state)
    }

    /// Builds a `BASMemoryBundle` with explicit knobs. Defaults
    /// produce an "empty" bundle (no atoms, no tags, no conflicts,
    /// no temporal field).
    private func bundle(
        atoms: [BASMemoryAtom] = [],
        retrievalTags: [String] = [],
        conflictRefs: [String] = [],
        activeHostVersion: String? = nil,
        quarantineRecords: [BASMemoryQuarantineRecord] = [],
        forgetCascades: [BASMemoryForgetCascade] = [],
        includeTemporalField: Bool = false
    ) -> BASMemoryBundle {
        let field: BASTemporalMemoryField?
        if includeTemporalField
            || !quarantineRecords.isEmpty
            || !forgetCascades.isEmpty {
            field = BASTemporalMemoryField(
                quarantineRecords: quarantineRecords,
                sanctumEntries: [],
                forgetCascades: forgetCascades)
        } else {
            field = nil
        }
        return BASMemoryBundle(
            atoms: atoms,
            retrievalTags: retrievalTags,
            conflictRefs: conflictRefs,
            retrievedAt: fixedDate,
            activeHostVersion: activeHostVersion,
            temporalField: field)
    }

    private func derive(
        _ b: BASMemoryBundle?
    ) -> BASHippocampalMemoryObservationBundle {
        BASHippocampalMemoryObservationBundle.derive(
            fromMemoryBundle: b,
            turnID: turnID,
            sessionID: sessionID,
            emittedAt: fixedDate)
    }

    // MARK: - Path 1: nil bundle → empty bundle

    func testNilBundleProducesEmptyObservationBundle() {
        let out = derive(nil)
        XCTAssertEqual(out.turnID, turnID)
        XCTAssertEqual(out.sessionID, sessionID)
        XCTAssertEqual(out.observations.count, 0)
        XCTAssertFalse(out.hasBundleRetrieval)
        XCTAssertFalse(out.hasCoreSignalCoverage)
    }

    // MARK: - Path 2: empty bundle → .empty shape + baseline only

    func testEmptyBundleEmitsOnlyBaselineWithEmptyShape() {
        let out = derive(bundle())
        XCTAssertEqual(out.observations.count, 1)
        XCTAssertTrue(out.hasBundleRetrieval)
        XCTAssertTrue(out.hasCoreSignalCoverage)
        XCTAssertFalse(out.hasAnyAtomSignal)
        XCTAssertFalse(out.hasAnyConflict)
        for obs in out.observations {
            XCTAssertEqual(obs.shape, .empty)
        }
        XCTAssertEqual(
            out.observations.first?.subjectID, "<unversioned>")
    }

    func testEmptyBundleWithHostVersionSurfacesItAsSubject() {
        let out = derive(bundle(activeHostVersion: "host-v3"))
        XCTAssertEqual(
            out.observations.first?.subjectID, "host-v3")
    }

    // MARK: - Path 3: quiet shape (atoms present, no concerns)

    func testAdmittedAtomsProduceQuietShape() {
        let out = derive(bundle(atoms: [
            atom(id: "a1", state: .admitted),
            atom(id: "a2", state: .admitted)
        ]))
        for obs in out.observations {
            XCTAssertEqual(obs.shape, .quiet)
        }
        let admitted = out.observations(of: .atomAdmitted)
        XCTAssertEqual(admitted.count, 2)
        XCTAssertEqual(admitted.map { $0.subjectID }, ["a1", "a2"])
    }

    func testCandidateAtomsEmitCandidateSignals() {
        let out = derive(bundle(atoms: [
            atom(id: "c1", state: .candidate)
        ]))
        let candidates = out.observations(of: .atomCandidate)
        XCTAssertEqual(candidates.count, 1)
        XCTAssertEqual(candidates.first?.subjectID, "c1")
    }

    func testRetiredAtomsEmitRetiredSignals() {
        let out = derive(bundle(atoms: [
            atom(id: "r1", state: .retired)
        ]))
        let retired = out.observations(of: .atomRetired)
        XCTAssertEqual(retired.count, 1)
        XCTAssertEqual(retired.first?.subjectID, "r1")
    }

    // MARK: - Path 4: atomFrozen precedence

    func testFrozenBoolFiresAtomFrozenEvenWhenAdmitted() {
        let out = derive(bundle(atoms: [
            atom(id: "f1", state: .admitted, frozen: true)
        ]))
        let frozen = out.observations(of: .atomFrozen)
        XCTAssertEqual(frozen.count, 1)
        XCTAssertEqual(frozen.first?.subjectID, "f1")
        XCTAssertTrue(out.hasAnyFrozenAtom)
        // And no atomAdmitted emitted for that atom.
        XCTAssertEqual(
            out.observations(of: .atomAdmitted).count, 0)
    }

    func testFrozenPromotionStateFiresAtomFrozen() {
        let out = derive(bundle(atoms: [
            atom(id: "f2", state: .frozen, frozen: false)
        ]))
        XCTAssertEqual(
            out.observations(of: .atomFrozen).count, 1)
    }

    // MARK: - Path 5: mixed atom states

    func testMixedAtomStatesProduceOneSignalPerAtom() {
        let out = derive(bundle(atoms: [
            atom(id: "a", state: .admitted),
            atom(id: "c", state: .candidate),
            atom(id: "f", state: .admitted, frozen: true),
            atom(id: "r", state: .retired)
        ]))
        XCTAssertEqual(
            out.observations(of: .atomAdmitted).count, 1)
        XCTAssertEqual(
            out.observations(of: .atomCandidate).count, 1)
        XCTAssertEqual(
            out.observations(of: .atomFrozen).count, 1)
        XCTAssertEqual(
            out.observations(of: .atomRetired).count, 1)
        // Total: baseline + 4 atoms = 5 observations.
        XCTAssertEqual(out.observations.count, 5)
    }

    // MARK: - Path 6: conflict refs → .conflicted shape

    func testConflictRefsTriggerConflictedShape() {
        let out = derive(bundle(
            atoms: [atom(id: "a1", state: .admitted)],
            conflictRefs: ["cnf-1", "cnf-2"]))
        for obs in out.observations {
            XCTAssertEqual(obs.shape, .conflicted)
        }
        XCTAssertTrue(out.hasAnyConflict)
        let flagged = out.observations(of: .conflictFlagged)
        XCTAssertEqual(flagged.map { $0.subjectID }, [
            "cnf-1", "cnf-2"
        ])
    }

    func testEmptyConflictRefsAreSkipped() {
        let out = derive(bundle(
            atoms: [atom(id: "a1", state: .admitted)],
            conflictRefs: ["", "   ", "cnf-real"]))
        let flagged = out.observations(of: .conflictFlagged)
        XCTAssertEqual(flagged.count, 1)
        XCTAssertEqual(flagged.first?.subjectID, "cnf-real")
    }

    // MARK: - Path 7: quarantine beats conflicted

    func testQuarantineRecordsTriggerQuarantinedShape() {
        let out = derive(bundle(
            atoms: [atom(id: "a1", state: .admitted)],
            conflictRefs: ["cnf-1"],
            quarantineRecords: [quarantine(id: "q1")]))
        for obs in out.observations {
            XCTAssertEqual(obs.shape, .quarantined)
        }
        XCTAssertTrue(out.hasAnyQuarantine)
        let recs = out.observations(of: .quarantineRecorded)
        XCTAssertEqual(recs.count, 1)
        XCTAssertEqual(recs.first?.subjectID, "q1")
    }

    func testMultipleQuarantineRecordsIterateInOrder() {
        let out = derive(bundle(
            quarantineRecords: [
                quarantine(id: "q1"),
                quarantine(id: "q2"),
                quarantine(id: "q3")
            ]))
        let recs = out.observations(of: .quarantineRecorded)
        XCTAssertEqual(recs.map { $0.subjectID }, [
            "q1", "q2", "q3"
        ])
    }

    // MARK: - Path 8: forget cascade beats quarantine

    func testForgetCascadeTriggersForgettingShape() {
        let out = derive(bundle(
            atoms: [atom(id: "a1", state: .admitted)],
            conflictRefs: ["cnf-1"],
            quarantineRecords: [quarantine(id: "q1")],
            forgetCascades: [cascade(id: "c1")]))
        for obs in out.observations {
            XCTAssertEqual(obs.shape, .forgetting)
        }
        XCTAssertTrue(out.hasAnyForgetCascade)
    }

    func testMultipleForgetCascadesIterateInOrder() {
        let out = derive(bundle(
            forgetCascades: [
                cascade(id: "c1"),
                cascade(id: "c2")
            ]))
        let cas = out.observations(of: .forgetCascadeBound)
        XCTAssertEqual(cas.map { $0.subjectID }, ["c1", "c2"])
    }

    // MARK: - Path 9: determinism

    func testDeterministicBundleForIdenticalInputs() {
        let b = bundle(
            atoms: [
                atom(id: "a1", state: .admitted),
                atom(id: "a2", state: .candidate, frozen: true)
            ],
            conflictRefs: ["cnf-1"],
            quarantineRecords: [quarantine(id: "q1")])
        XCTAssertEqual(derive(b), derive(b))
    }

    // MARK: - Path 10: withDerived helper preserves frame

    func testWithDerivedBundleAttachesAndPreservesFrame() {
        let frame = BASThoughtFrame(
            stepIndex: 8,
            decomposeRef: "dcm-l8",
            memoryRefs: ["m-a"],
            stabilityScore: 0.44)
        let withBundle = frame
            .withDerivedHippocampalMemoryObservationBundle(
                memoryBundle: bundle(atoms: [
                    atom(id: "a1", state: .admitted)
                ]),
                turnID: turnID,
                sessionID: sessionID,
                emittedAt: fixedDate)
        XCTAssertEqual(withBundle.stepIndex, 8)
        XCTAssertEqual(withBundle.decomposeRef, "dcm-l8")
        XCTAssertEqual(withBundle.memoryRefs, ["m-a"])
        XCTAssertEqual(withBundle.stabilityScore, 0.44)
        XCTAssertNotNil(
            withBundle.hippocampalMemoryObservationBundle)
        XCTAssertTrue(
            withBundle.hippocampalMemoryObservationBundle!
                .hasAnyAtomSignal)
    }

    func testWithDerivedHelperWithNilBundleEmitsEmpty() {
        let frame = BASThoughtFrame(
            stepIndex: 1, decomposeRef: "dcm")
        let withBundle = frame
            .withDerivedHippocampalMemoryObservationBundle(
                memoryBundle: nil,
                turnID: turnID,
                sessionID: sessionID,
                emittedAt: fixedDate)
        XCTAssertNotNil(
            withBundle.hippocampalMemoryObservationBundle)
        XCTAssertEqual(
            withBundle.hippocampalMemoryObservationBundle?
                .observations.count, 0)
    }

    // MARK: - Path 11: content fields encode payloads

    func testBaselineContentEncodesAtomAndTagCounts() {
        let out = derive(bundle(
            atoms: [
                atom(id: "a1", state: .admitted),
                atom(id: "a2", state: .candidate)
            ],
            retrievalTags: ["tag-1", "tag-2", "tag-3"],
            conflictRefs: ["cnf-1"]))
        let baseline = out.observations(
            of: .bundleRetrieved).first!
        XCTAssertTrue(baseline.content.contains(
            "l8.bundle.retrieved"))
        XCTAssertTrue(baseline.content.contains(".atoms:2"))
        XCTAssertTrue(baseline.content.contains(".tags:3"))
        XCTAssertTrue(baseline.content.contains(".conflicts:1"))
    }

    func testAtomContentEncodesTypeAndState() {
        let out = derive(bundle(atoms: [
            atom(id: "a-x", type: .warm,
                state: .admitted, frozen: false)
        ]))
        let ad = out.observations(of: .atomAdmitted).first!
        XCTAssertTrue(ad.content.contains("l8.atom.admitted:a-x"))
        XCTAssertTrue(ad.content.contains(".type:warm"))
        XCTAssertTrue(ad.content.contains(".state:admitted"))
        XCTAssertTrue(ad.content.contains(".frozen:false"))
    }

    func testQuarantineContentEncodesMemoryRefAndReasons() {
        let out = derive(bundle(
            quarantineRecords: [quarantine(
                id: "q-x",
                memoryRef: "m-targeted",
                reasons: ["poison.a", "poison.b"])]))
        let q = out.observations(of: .quarantineRecorded).first!
        XCTAssertTrue(q.content.contains(
            "l8.quarantine.recorded:q-x"))
        XCTAssertTrue(q.content.contains(".memoryRef:m-targeted"))
        XCTAssertTrue(q.content.contains(
            ".reasons:poison.a|poison.b"))
    }

    func testCascadeContentEncodesExecutionStateAndRootCount() {
        let out = derive(bundle(
            forgetCascades: [cascade(
                id: "c-x",
                roots: ["r1", "r2", "r3"],
                state: "completed")]))
        let c = out.observations(of: .forgetCascadeBound).first!
        XCTAssertTrue(c.content.contains(
            "l8.forget.cascade.bound:c-x"))
        XCTAssertTrue(c.content.contains(".state:completed"))
        XCTAssertTrue(c.content.contains(".roots:3"))
    }

    // MARK: - Path 12: budget cost totals + clamp

    func testBudgetCostSumsCorrectlyUnderRealisticLoad() {
        // baseline (0.02) + 1 admitted (0.04) + 1 candidate (0.04)
        //   + 1 frozen (0.08) + 1 retired (0.06) + 1 conflict (0.10)
        //   + 1 quarantine (0.15) + 1 cascade (0.20)
        //   = 0.69
        let out = derive(bundle(
            atoms: [
                atom(id: "a", state: .admitted),
                atom(id: "c", state: .candidate),
                atom(id: "f", state: .admitted, frozen: true),
                atom(id: "r", state: .retired)
            ],
            conflictRefs: ["cnf-1"],
            quarantineRecords: [quarantine(id: "q1")],
            forgetCascades: [cascade(id: "c1")]))
        let total = BASHippocampalMemorySignalBudget.totalCost(
            for: out)
        XCTAssertEqual(total, 0.69, accuracy: 0.0001)
        XCTAssertLessThanOrEqual(total, 1.0)
        XCTAssertGreaterThanOrEqual(total, 0.0)
    }

    func testBudgetClampsUnderHighVolumeCascades() {
        // Many cascades → 0.20 × N → should clamp to 1.0.
        let cascades = (0..<10).map { cascade(id: "c\($0)") }
        let out = derive(bundle(forgetCascades: cascades))
        let total = BASHippocampalMemorySignalBudget.totalCost(
            for: out)
        XCTAssertLessThanOrEqual(total, 1.0)
    }

    // MARK: - Path 13: Codable round trip

    func testBundleCodableRoundTripPreservesSignals() throws {
        let out = derive(bundle(
            atoms: [atom(id: "a1", state: .admitted)],
            conflictRefs: ["cnf-1"],
            quarantineRecords: [quarantine(id: "q1")]))
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(out)
        let decoder = JSONDecoder()
        let roundTrip = try decoder.decode(
            BASHippocampalMemoryObservationBundle.self, from: data)
        XCTAssertEqual(roundTrip, out)
    }

    func testThoughtFrameCodableRoundTripIncludesMemoryBundle()
    throws {
        var frame = BASThoughtFrame(
            stepIndex: 3,
            decomposeRef: "dcm-z",
            stabilityScore: 0.5)
        frame = frame
            .withDerivedHippocampalMemoryObservationBundle(
                memoryBundle: bundle(atoms: [
                    atom(id: "a1", state: .admitted)
                ]),
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
            roundTrip.hippocampalMemoryObservationBundle,
            frame.hippocampalMemoryObservationBundle)
    }

    // MARK: - Path 14: ledger

    func testLedgerRecordsBundleAndSnapshots() async {
        let ledger = BASHippocampalMemoryObservationLedger(
            capacity: 2)
        let a = derive(bundle(atoms: [
            atom(id: "a", state: .admitted)
        ]))
        let b = derive(bundle(atoms: [
            atom(id: "b", state: .admitted)
        ]))
        let c = derive(bundle(atoms: [
            atom(id: "c", state: .admitted)
        ]))
        await ledger.record(a)
        await ledger.record(b)
        await ledger.record(c)
        let snap = await ledger.snapshot()
        XCTAssertEqual(snap.count, 2)
        XCTAssertEqual(snap.first, b)
        XCTAssertEqual(snap.last, c)
    }

    func testLedgerFiltersBySessionAndTurn() async {
        let ledger = BASHippocampalMemoryObservationLedger()
        let a = BASHippocampalMemoryObservationBundle.derive(
            fromMemoryBundle: bundle(),
            turnID: "tA",
            sessionID: "sA",
            emittedAt: fixedDate)
        let b = BASHippocampalMemoryObservationBundle.derive(
            fromMemoryBundle: bundle(),
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

    // MARK: - Path 15: filter helpers

    func testObservationsForShapeFiltersBundle() {
        let out = derive(bundle(
            forgetCascades: [cascade(id: "c1")]))
        let forgetting = out.observations(
            forShape: .forgetting)
        XCTAssertEqual(forgetting.count, out.observations.count)
    }

    func testObservationsForSubjectFiltersBundle() {
        let out = derive(bundle(
            atoms: [atom(id: "atom-99", state: .admitted)],
            activeHostVersion: "host-v9"))
        let byAtom = out.observations(forSubject: "atom-99")
        XCTAssertEqual(byAtom.count, 1)
        XCTAssertEqual(byAtom.first?.kind, .atomAdmitted)
        let byHost = out.observations(forSubject: "host-v9")
        XCTAssertEqual(byHost.count, 1)
        XCTAssertEqual(byHost.first?.kind, .bundleRetrieved)
    }

    // MARK: - Path 16: subjectIDs preserve first-seen order

    func testSubjectIDsPreserveEmissionOrder() {
        let out = derive(bundle(
            atoms: [
                atom(id: "a1", state: .admitted),
                atom(id: "a2", state: .candidate)
            ],
            conflictRefs: ["cnf-1"],
            activeHostVersion: "host-v3",
            quarantineRecords: [quarantine(id: "q1")],
            forgetCascades: [cascade(id: "c1")]))
        XCTAssertEqual(out.subjectIDs, [
            "host-v3", "a1", "a2", "cnf-1", "q1", "c1"
        ])
    }
}
