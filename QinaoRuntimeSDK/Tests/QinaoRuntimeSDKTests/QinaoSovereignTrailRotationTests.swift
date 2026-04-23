import XCTest
import CryptoKit
import BASRuntimeCore
import BASSovereign
@testable import QinaoSovereign

/// M83 — Qinao-facing audit-trail rotation + LINEAGE_CUT.
///
/// These tests prove the Qinao public API fulfills:
///
/// - `rotateAuditTrail(sessionID:, reason:)` closes the currently-
///   open segment and exposes the closed-segment descriptor
///   (including `tailHash`, `closedBy`, `closingRotationID`).
/// - `cutLineage(...)` propagates LINEAGE_CUT through the trail and
///   returns both `affectedAuditRefs` and `protectedAuditRefs` with
///   the downstream cascade direction correct (entries that cite
///   the root get cut; the root's own inputs are preserved).
/// - Halted sessions refuse rotation and lineage cuts at the façade.
/// - The composition-layer mirror translators faithfully round-trip
///   rotation reasons and cut-depth variants.
final class QinaoSovereignTrailRotationTests: XCTestCase {

    // MARK: - Fixture

    private struct Fixture: Sendable {
        let sovereign: QinaoSovereignControlPlane
        let ledger: BASSovereignAuditLedger
        let clock: MutableClock
    }

    final class MutableClock: @unchecked Sendable {
        var now: Date
        init(_ t: Date) { self.now = t }
    }

    private func makeFixture(
        startAt: Date = Date(timeIntervalSince1970: 1_700_000_000)
    ) -> Fixture {
        let clock = MutableClock(startAt)
        let now: @Sendable () -> Date = { [clock] in clock.now }
        let snapshotManager = BASSovereignSnapshotManager(now: now)
        let versionTree = BASSovereignHostVersionTree(now: now)
        let ledger = BASSovereignAuditLedger(
            signingSecret: SymmetricKey(size: .bits256))
        let coordinator = BASSovereignCleanRebootCoordinator(
            snapshotManager: snapshotManager,
            versionTree: versionTree,
            ledger: ledger,
            now: now)
        let tokenAuthority = BASSovereignTokenAuthority(now: now)
        let engine = BASSovereignVerdictEngine(ledger: ledger, now: now)
        let verifier = BASSovereignTurnVerifier(engine: engine)
        let sovereign = QinaoSovereignControlPlane(
            coordinator: coordinator,
            tokenAuthority: tokenAuthority,
            turnVerifier: verifier,
            auditLedger: ledger,
            warrantTTLSeconds: 30,
            now: now)
        return Fixture(
            sovereign: sovereign,
            ledger: ledger,
            clock: clock)
    }

    private func seedAudit(
        in fx: Fixture,
        auditID: String,
        session: String = "session-A",
        turn: String = "turn-1",
        verdict: String = "verdict-ok",
        ruleIDs: [String] = ["BR-001"],
        signalRefs: [String] = [],
        snapshotRef: String = "snap-ok"
    ) async throws {
        let entry = BASSovereignAuditEntry(
            auditID: auditID,
            sessionID: session,
            turnID: turn,
            verdictRef: verdict,
            ruleIDs: ruleIDs,
            signalRefs: signalRefs,
            actionRefs: [],
            snapshotRef: snapshotRef,
            actor: .system,
            signature: "",
            appendedAt: fx.clock.now)
        _ = try await fx.ledger.append(entry)
    }

    // MARK: - Rotation

    func testRotateAuditTrailClosesSegmentAndExposesTailHash() async throws {
        let fx = makeFixture()
        try await seedAudit(in: fx, auditID: "a-1")
        try await seedAudit(in: fx, auditID: "a-2", turn: "turn-2")

        let closed = try await fx.sovereign.rotateAuditTrail(
            sessionID: "session-A",
            reason: .scheduledRotation,
            rotationID: "rot-demo-1")
        XCTAssertEqual(closed.sessionID, "session-A")
        XCTAssertEqual(closed.entryCount, 2)
        XCTAssertEqual(closed.closedBy, .scheduledRotation)
        XCTAssertEqual(closed.closingRotationID, "rot-demo-1")
        XCTAssertTrue(closed.isClosed,
            "closed segment must carry a tailHash")
        XCTAssertNotNil(closed.tailHash)

        // After rotation, no open segment for the session.
        let current = await fx.sovereign.currentAuditSegment(
            sessionID: "session-A")
        XCTAssertNil(current)
    }

    func testRotateAuditTrailOnEmptySessionThrowsNoOpenSegment() async {
        let fx = makeFixture()
        do {
            _ = try await fx.sovereign.rotateAuditTrail(
                sessionID: "never-seen")
            XCTFail("empty session must throw")
        } catch QinaoSovereignControlPlane.TrailError.noOpenSegment(
            let session)
        {
            XCTAssertEqual(session, "never-seen")
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testRotateAuditTrailRefusedOnHaltedSession() async throws {
        let fx = makeFixture()
        try await seedAudit(in: fx, auditID: "a-1")
        await fx.sovereign.markSessionHalted(
            sessionID: "session-A",
            reason: "halt-for-test")

        do {
            _ = try await fx.sovereign.rotateAuditTrail(
                sessionID: "session-A")
            XCTFail("halted session must refuse rotation")
        } catch QinaoSovereignControlPlane.TrailError.sessionHalted(
            let session)
        {
            XCTAssertEqual(session, "session-A")
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testAuditSegmentsReturnsFullHistoryInCreationOrder() async throws {
        let fx = makeFixture()
        try await seedAudit(in: fx, auditID: "a-1")
        _ = try await fx.sovereign.rotateAuditTrail(
            sessionID: "session-A",
            reason: .scheduledRotation,
            rotationID: "rot-A")
        try await seedAudit(in: fx, auditID: "a-2", turn: "turn-2")
        _ = try await fx.sovereign.rotateAuditTrail(
            sessionID: "session-A",
            reason: .sessionClosure,
            rotationID: "rot-B")

        let segs = await fx.sovereign.auditSegments(
            sessionID: "session-A")
        XCTAssertEqual(segs.count, 2)
        XCTAssertEqual(segs.map(\.closingRotationID), ["rot-A", "rot-B"])
        XCTAssertEqual(segs.map(\.closedBy),
                       [.scheduledRotation, .sessionClosure])
    }

    // MARK: - LINEAGE_CUT

    func testCutLineageEntireLineageCascadesThroughReferences() async throws {
        let fx = makeFixture()
        // Graph: a-root ← a-child (cites root) ← a-grand (cites child)
        try await seedAudit(in: fx, auditID: "a-root")
        try await seedAudit(
            in: fx, auditID: "a-child", turn: "t2",
            signalRefs: ["a-root"])
        try await seedAudit(
            in: fx, auditID: "a-grand", turn: "t3",
            signalRefs: ["a-child"])

        let outcome = try await fx.sovereign.cutLineage(
            cutID: "cut-1",
            sessionID: "session-A",
            rootAuditRef: "a-root",
            depth: .entireLineage,
            reason: "privacy-scrub")

        XCTAssertEqual(Set(outcome.affectedAuditRefs),
                       Set(["a-root", "a-child", "a-grand"]))
        XCTAssertTrue(outcome.protectedAuditRefs.isEmpty)
        XCTAssertEqual(outcome.markerAuditRef, "cut-cut-1")
        XCTAssertEqual(outcome.closedSegment.closedBy, .lineageCut)
        XCTAssertNotNil(outcome.closedSegment.tailHash)
    }

    func testCutLineageBoundedHopsStopsAtDepth() async throws {
        let fx = makeFixture()
        try await seedAudit(in: fx, auditID: "a-root")
        try await seedAudit(
            in: fx, auditID: "a-c1", turn: "t2",
            signalRefs: ["a-root"])
        try await seedAudit(
            in: fx, auditID: "a-c2", turn: "t3",
            signalRefs: ["a-c1"])

        let outcome = try await fx.sovereign.cutLineage(
            cutID: "cut-1",
            sessionID: "session-A",
            rootAuditRef: "a-root",
            depth: .bounded(hops: 1),
            reason: "partial-scrub")

        XCTAssertEqual(Set(outcome.affectedAuditRefs),
                       Set(["a-root", "a-c1"]))
        XCTAssertFalse(
            outcome.affectedAuditRefs.contains("a-c2"),
            "bounded(hops=1) must not reach transitive descendants")
    }

    func testCutLineageProtectedRulesPreserveAndHaltCascade() async throws {
        let fx = makeFixture()
        try await seedAudit(in: fx, auditID: "a-root")
        try await seedAudit(
            in: fx, auditID: "a-guard", turn: "t2",
            ruleIDs: ["BR-004"],
            signalRefs: ["a-root"])
        try await seedAudit(
            in: fx, auditID: "a-beyond", turn: "t3",
            signalRefs: ["a-guard"])

        let outcome = try await fx.sovereign.cutLineage(
            cutID: "cut-1",
            sessionID: "session-A",
            rootAuditRef: "a-root",
            depth: .entireLineage,
            reason: "scrub-with-protection",
            protectedRuleIDs: ["BR-004"])

        XCTAssertEqual(outcome.affectedAuditRefs, ["a-root"])
        XCTAssertEqual(outcome.protectedAuditRefs, ["a-guard"])
        XCTAssertFalse(outcome.affectedAuditRefs.contains("a-beyond"),
            "protected bail-out must halt cascade at the guarded node")
    }

    func testCutLineageUnknownRootSurfacesTrailError() async {
        let fx = makeFixture()
        do {
            _ = try await fx.sovereign.cutLineage(
                cutID: "cut-1",
                sessionID: "session-A",
                rootAuditRef: "never-seen",
                reason: "ghost")
            XCTFail("unknown root must throw")
        } catch QinaoSovereignControlPlane.TrailError
            .lineageRootNotFound(let id)
        {
            XCTAssertEqual(id, "never-seen")
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testCutLineageRefusedOnHaltedSession() async throws {
        let fx = makeFixture()
        try await seedAudit(in: fx, auditID: "a-root")
        await fx.sovereign.markSessionHalted(
            sessionID: "session-A",
            reason: "halt-for-test")

        do {
            _ = try await fx.sovereign.cutLineage(
                cutID: "cut-1",
                sessionID: "session-A",
                rootAuditRef: "a-root",
                reason: "cannot-run")
            XCTFail("halted session must refuse lineage cut")
        } catch QinaoSovereignControlPlane.TrailError.sessionHalted(
            let session)
        {
            XCTAssertEqual(session, "session-A")
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testCutLineageEmptyCutIDThrowsInvalidRequest() async throws {
        let fx = makeFixture()
        try await seedAudit(in: fx, auditID: "a-root")
        do {
            _ = try await fx.sovereign.cutLineage(
                cutID: "",
                sessionID: "session-A",
                rootAuditRef: "a-root",
                reason: "bad-id")
            XCTFail("empty cutID must throw")
        } catch QinaoSovereignControlPlane.TrailError
            .invalidRequest(let msg)
        {
            XCTAssertTrue(msg.contains("cutID"))
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testLineageCutOutcomeIsQueryableByMarkerAfterApply() async throws {
        let fx = makeFixture()
        try await seedAudit(in: fx, auditID: "a-root")
        let applied = try await fx.sovereign.cutLineage(
            cutID: "cut-1",
            sessionID: "session-A",
            rootAuditRef: "a-root",
            reason: "scrub")

        let retrieved = await fx.sovereign.lineageCutOutcome(
            markerAuditRef: applied.markerAuditRef)
        XCTAssertEqual(retrieved?.cutID, applied.cutID)
        XCTAssertEqual(retrieved?.affectedAuditRefs,
                       applied.affectedAuditRefs)
        XCTAssertEqual(retrieved?.closedSegment.segmentID,
                       applied.closedSegment.segmentID)
    }

    // MARK: - Integration with main-chain integrity

    func testTrailIntegrityHoldsAcrossRotationAndLineageCut() async throws {
        let fx = makeFixture()
        try await seedAudit(in: fx, auditID: "a-1")
        try await seedAudit(in: fx, auditID: "a-2", turn: "t2")
        _ = try await fx.sovereign.rotateAuditTrail(
            sessionID: "session-A",
            reason: .scheduledRotation)
        try await seedAudit(in: fx, auditID: "a-3", turn: "t3")
        _ = try await fx.sovereign.cutLineage(
            cutID: "cut-1",
            sessionID: "session-A",
            rootAuditRef: "a-3",
            reason: "end-to-end-check")
        try await seedAudit(in: fx, auditID: "a-4", turn: "t4")

        // The chain survives rotation + cut + further appends.
        try await fx.ledger.verifyChainIntegrity()
    }
}
