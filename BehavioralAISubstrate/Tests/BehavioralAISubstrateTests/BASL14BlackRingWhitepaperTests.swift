import XCTest
@testable import BASRuntimeCore
@testable import BASAdmin

/// M119 — L14 `玄戒层 / Black Ring` whitepaper §5 closure tests.
///
/// **This is the final layer. 14/14 substrate whitepaper parity
/// milestone.**
///
/// L14 §5 lists 11 key objects. Pre-M119 substrate had 2 matching:
/// - `BASSovereignWarrant` (§5.7)
/// - `BASSovereignAuditEntry` (≈ §5.11 SovereignLedgerEntry, name
///   drift; distinct shape with actor/snapshotRef fields)
///
/// 9 gaps — all closed by M119:
/// 1. SovereignFrame — 17-field aggregator
/// 2. JurisdictionMap
/// 3. IntegrityWitness
/// 4. ContinuitySeal
/// 5. MutationPetition
/// 6. ContaminationLineage
/// 7. QuarantineMandate
/// 8. RollbackWrit
/// 9. DeadStopLatch
///
/// Plus 2 supporting enums: BASSovereignMutationType (4-case),
/// BASSovereignQuarantineZone (6-case).
///
/// Note: `BASSovereignAuditEntry` has extra substrate-runtime
/// fields (actor, snapshotRef) that whitepaper §5.11 doesn't
/// require — it's a richer implementation of the same semantic
/// audit-entry concept. M119 does NOT add a separate
/// BASSovereignLedgerEntry — the existing audit entry covers the
/// whitepaper intent.
final class BASL14BlackRingWhitepaperTests: XCTestCase {

    // MARK: - 1. All 9 new §5 types exist

    func testAllNineNewL14TypesSchemaVersionOneDotZero() {
        XCTAssertEqual(
            BASSovereignFrame.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(
            BASJurisdictionMap.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(
            BASIntegrityWitness.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(
            BASContinuitySeal.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(
            BASMutationPetition.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(
            BASContaminationLineage.currentSchemaVersion,
            "1.0.0")
        XCTAssertEqual(
            BASQuarantineMandate.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(
            BASRollbackWrit.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(
            BASDeadStopLatch.currentSchemaVersion, "1.0.0")
    }

    // MARK: - 2. Enum raw values

    func testMutationTypeHasFourWhitepaperCases() {
        let expected: Set<String> = [
            "host", "memory", "rule", "permission"
        ]
        XCTAssertEqual(
            Set(BASSovereignMutationType.allCases
                .map(\.rawValue)),
            expected)
    }

    func testQuarantineZoneHasSixWhitepaperCases() {
        let expected: Set<String> = [
            "session", "memory", "host",
            "tool", "cache", "deviceDomain"
        ]
        XCTAssertEqual(
            Set(BASSovereignQuarantineZone.allCases
                .map(\.rawValue)),
            expected)
    }

    // MARK: - 3. SovereignFrame 17-field aggregator

    func testSovereignFrameAllFieldsRoundTrip() {
        let f = BASSovereignFrame(
            frameID: "sf.1",
            sessionID: "sess.1",
            turnID: "t.1",
            deviceStateRef: "ds.1",
            hostVersionRef: "hv.1",
            continuityRef: "cs.1",
            thoughtFoldRef: "tf.1",
            riskCardRef: "rc.1",
            actionPermitRef: "ap.1",
            pendingActionDigest: "pa.1",
            pendingMutationDigest: "pm.1",
            pendingMemoryDigest: "pmem.1",
            jurisdictionRef: "jm.1",
            timeLockRef: "tl.1",
            contaminationRefs: ["cl.1"],
            policyHash: "sha256:abc")
        XCTAssertEqual(f.sessionID, "sess.1")
        XCTAssertEqual(f.turnID, "t.1")
        XCTAssertEqual(
            f.contaminationRefs, ["cl.1"])
        XCTAssertEqual(f.policyHash, "sha256:abc")
    }

    // MARK: - 4. MutationPetition with enum

    func testMutationPetitionHostType() {
        let p = BASMutationPetition(
            petitionID: "mp.1",
            mutationType: .host,
            proposedDelta: ["goals:add"],
            evidenceRefs: ["ev.1"],
            jurisdictionDomain: "host-constitution")
        XCTAssertEqual(p.mutationType, .host)
        XCTAssertEqual(
            p.proposedDelta, ["goals:add"])
        XCTAssertEqual(p.approvalState, "pending")
    }

    // MARK: - 5. QuarantineMandate with zone enum

    func testQuarantineMandateMemoryZone() {
        let m = BASQuarantineMandate(
            mandateID: "qm.1",
            zone: .memory,
            targetRefs: ["mem.alpha"],
            reasonCodes: ["poisoned-source"],
            releaseConditions: ["source-verified"])
        XCTAssertEqual(m.zone, .memory)
        XCTAssertEqual(m.targetRefs, ["mem.alpha"])
    }

    // MARK: - 6. IntegrityWitness confidence clamping

    func testIntegrityWitnessClampsConfidence() {
        let w = BASIntegrityWitness(
            witnessID: "iw.1",
            confidence: 1.5)
        XCTAssertEqual(w.confidence, 1.0)
    }

    // MARK: - 7. ContaminationLineage

    func testContaminationLineageDefaults() {
        let l = BASContaminationLineage(
            lineageID: "cl.1",
            rootRef: "root.1",
            contaminationType: "prompt-injection")
        XCTAssertFalse(l.cutRecommended)
        XCTAssertEqual(l.severity, 0)
        XCTAssertEqual(l.descendantRefs, [])
    }

    // MARK: - 8. RollbackWrit

    func testRollbackWritDefaults() {
        let w = BASRollbackWrit(
            writID: "rw.1",
            anchorRef: "anchor.1")
        XCTAssertEqual(w.rollbackScope, "session")
        XCTAssertEqual(w.rebuildMode, "safe")
    }

    // MARK: - 9. DeadStopLatch

    func testDeadStopLatchDefaults() {
        let l = BASDeadStopLatch(
            latchID: "dsl.1",
            scope: "session",
            reasonCodes: ["integrity-breach"])
        XCTAssertEqual(
            l.releaseAuthority, "sovereign")
    }

    // MARK: - 10. Codable round-trip (SovereignFrame)

    func testSovereignFrameCodableRoundTrip() throws {
        let orig = BASSovereignFrame(
            frameID: "rt",
            sessionID: "sess.rt",
            turnID: "t.rt",
            policyHash: "hash.rt")
        let data = try JSONEncoder().encode(orig)
        let decoded = try JSONDecoder().decode(
            BASSovereignFrame.self, from: data)
        XCTAssertEqual(decoded, orig)
    }

    // MARK: - 11. Registry membership

    func testAllNineNewL14TypesRegistered() {
        let ids = Set(
            BASEBrainSchemaGovernanceRegistry.governedSchemas
                .map(\.objectID))
        let l14Names: Set<String> = [
            "SovereignFrame", "JurisdictionMap",
            "IntegrityWitness", "ContinuitySeal",
            "MutationPetition", "ContaminationLineage",
            "QuarantineMandate", "RollbackWrit",
            "DeadStopLatch"
        ]
        let present = l14Names.intersection(ids)
        XCTAssertEqual(
            present.count, 9,
            "all 9 new L14 §5 types must be in governance")
    }

    // MARK: - 12. Pre-existing §5 types still present

    func testPreExistingL14TypesStillPresent() {
        // SovereignWarrant (§5.7) + SovereignAuditEntry
        // (≈§5.11 SovereignLedgerEntry name drift) remain
        // unchanged by M119. This locks that in.
        XCTAssertEqual(
            BASSovereignWarrant.currentSchemaVersion, "1.1.0")
        XCTAssertEqual(
            BASSovereignAuditEntry.currentSchemaVersion,
            "1.0.0")
    }
}
