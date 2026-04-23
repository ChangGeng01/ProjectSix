import XCTest
import CryptoKit
@testable import BASRuntimeCore
@testable import BASSovereign

/// M83 — ledger rotation and LINEAGE_CUT semantics.
///
/// These tests pin down the chain-preservation invariant that makes
/// rotation BR-012-safe: closing a segment does NOT touch any prior
/// entry's `priorHash` / `selfHash` / `signature`, and the new
/// segment's `startAnchor` equals the closed segment's `tailHash`.
/// Traversal and protected-rule bail-out are exercised against an
/// in-memory fixture so the cascade semantics are observable without
/// any runtime plumbing.
final class BASSovereignAuditLedgerRotationTests: XCTestCase {

    // MARK: - Fixtures

    private func makeLedger(
        seed: String = "m83-rotation-seed"
    ) -> BASSovereignAuditLedger {
        BASSovereignAuditLedger.withSeed(seed)
    }

    private func makeEntry(
        auditID: String,
        session: String = "session-A",
        turn: String = "turn-1",
        verdict: String = "verdict-xyz",
        ruleIDs: [String] = ["BR-001"],
        signalRefs: [String] = [],
        actionRefs: [String] = [],
        snapshotRef: String = "snap-1",
        at: Date = Date(timeIntervalSince1970: 1_700_000_000)
    ) -> BASSovereignAuditEntry {
        BASSovereignAuditEntry(
            auditID: auditID,
            sessionID: session,
            turnID: turn,
            verdictRef: verdict,
            ruleIDs: ruleIDs,
            signalRefs: signalRefs,
            actionRefs: actionRefs,
            snapshotRef: snapshotRef,
            actor: .system,
            signature: "",
            appendedAt: at)
    }

    private func rotationPlan(
        rotationID: String = "rot-1",
        session: String = "session-A",
        reason: BASSovereignLedgerRotationReason = .scheduledRotation,
        at: Date = Date(timeIntervalSince1970: 1_700_000_500)
    ) -> BASSovereignLedgerRotationPlan {
        BASSovereignLedgerRotationPlan(
            rotationID: rotationID,
            sessionID: session,
            beforeTurnID: nil,
            reason: reason,
            requestedAt: at)
    }

    private func cutRequest(
        cutID: String = "cut-1",
        session: String = "session-A",
        root: String = "a-root",
        depth: BASSovereignLineageCutDepth = .entireLineage,
        protected: Set<String> = [],
        reason: String = "privacy-scrub",
        at: Date = Date(timeIntervalSince1970: 1_700_000_900)
    ) -> BASSovereignLineageCutRequest {
        BASSovereignLineageCutRequest(
            cutID: cutID,
            sessionID: session,
            rootAuditID: root,
            depth: depth,
            reason: reason,
            protectedRuleIDs: protected,
            requestedAt: at)
    }

    // MARK: - Rotation: opening segments

    func testFirstAppendLazilyOpensSegmentWithGenesisAnchor() async throws {
        let ledger = makeLedger()
        _ = try await ledger.append(makeEntry(auditID: "a-1"))

        let current = await ledger.currentSegment(forSession: "session-A")
        XCTAssertNotNil(current, "first append must open a segment")
        XCTAssertEqual(current?.segmentIndex, 0)
        XCTAssertEqual(current?.startAnchor, "GENESIS",
                       "segment-0 anchors to the genesis sentinel")
        XCTAssertEqual(current?.entryCount, 1)
        XCTAssertNil(current?.closedAt)
        XCTAssertNil(current?.tailHash,
                     "open segment has no tailHash yet")
    }

    func testRotateClosesSegmentAndStampsTailWithLastSelfHash() async throws {
        let ledger = makeLedger()
        let first = try await ledger.append(makeEntry(auditID: "a-1"))
        let second = try await ledger.append(
            makeEntry(auditID: "a-2", turn: "turn-2"))

        let closed = try await ledger.rotate(plan: rotationPlan())
        XCTAssertEqual(closed.entryCount, 2)
        XCTAssertEqual(closed.tailHash, second.selfHash,
                       "closed segment tail = last entry's selfHash")
        XCTAssertEqual(closed.closedBy, .scheduledRotation)
        XCTAssertEqual(closed.closingRotationID, "rot-1")
        XCTAssertNotNil(closed.closedAt)

        // Prior entries are untouched.
        let firstReread = try await ledger.query(byAuditRef: "a-1")
        XCTAssertEqual(firstReread.selfHash, first.selfHash)
        XCTAssertEqual(firstReread.priorHash, first.priorHash)
    }

    func testRotateOnEmptySessionThrowsNoOpenSegment() async {
        let ledger = makeLedger()
        do {
            _ = try await ledger.rotate(plan: rotationPlan())
            XCTFail("rotation without open segment must throw")
        } catch BASSovereignAuditLedger.LedgerError.noOpenSegment(
            let session)
        {
            XCTAssertEqual(session, "session-A")
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testRotateTwiceInARowThrowsOnSecondInvocation() async throws {
        let ledger = makeLedger()
        _ = try await ledger.append(makeEntry(auditID: "a-1"))
        _ = try await ledger.rotate(plan: rotationPlan())
        do {
            _ = try await ledger.rotate(plan: rotationPlan(
                rotationID: "rot-2"))
            XCTFail("second rotation without intervening append must throw")
        } catch BASSovereignAuditLedger.LedgerError.noOpenSegment {
            // expected
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testAppendAfterRotateOpensNewSegmentAnchoredToPriorTail() async throws {
        let ledger = makeLedger()
        _ = try await ledger.append(makeEntry(auditID: "a-1"))
        let closed = try await ledger.rotate(plan: rotationPlan())

        _ = try await ledger.append(
            makeEntry(auditID: "a-2", turn: "turn-2"))
        let current = await ledger.currentSegment(forSession: "session-A")
        XCTAssertNotNil(current)
        XCTAssertEqual(current?.segmentIndex, 1)
        XCTAssertEqual(current?.startAnchor, closed.tailHash,
                       "new segment anchors to closed segment's tail hash")
        XCTAssertEqual(current?.entryCount, 1)
    }

    // MARK: - Chain integrity across rotation

    func testChainStillVerifiesAcrossSegmentBoundary() async throws {
        let ledger = makeLedger()
        _ = try await ledger.append(makeEntry(auditID: "a-1"))
        _ = try await ledger.append(
            makeEntry(auditID: "a-2", turn: "turn-2"))
        _ = try await ledger.rotate(plan: rotationPlan())
        _ = try await ledger.append(
            makeEntry(auditID: "a-3", turn: "turn-3"))
        _ = try await ledger.append(
            makeEntry(auditID: "a-4", turn: "turn-4"))

        // BR-012 — integrity verification MUST still pass end-to-end
        // across a segment boundary. The whole chain is one continuous
        // hash-chained run; segments are bookkeeping only.
        try await ledger.verifyChainIntegrity()
    }

    func testAcrossRotationNeighborsPreserveHashChainLinks() async throws {
        let ledger = makeLedger()
        _ = try await ledger.append(makeEntry(auditID: "a-1"))
        let last = try await ledger.append(
            makeEntry(auditID: "a-2", turn: "turn-2"))
        _ = try await ledger.rotate(plan: rotationPlan())
        let afterRotate = try await ledger.append(
            makeEntry(auditID: "a-3", turn: "turn-3"))

        XCTAssertEqual(afterRotate.priorHash, last.selfHash,
                       "neighbor entries across rotation must remain linked")
    }

    // MARK: - Segments query

    func testSegmentsForSessionReturnsCreationOrder() async throws {
        let ledger = makeLedger()
        _ = try await ledger.append(makeEntry(auditID: "a-1"))
        _ = try await ledger.rotate(plan: rotationPlan(
            rotationID: "rot-A"))
        _ = try await ledger.append(
            makeEntry(auditID: "a-2", turn: "turn-2"))
        _ = try await ledger.rotate(plan: rotationPlan(
            rotationID: "rot-B"))
        _ = try await ledger.append(
            makeEntry(auditID: "a-3", turn: "turn-3"))

        let all = await ledger.segments(forSession: "session-A")
        XCTAssertEqual(all.map(\.segmentIndex), [0, 1, 2])
        XCTAssertEqual(all[0].closingRotationID, "rot-A")
        XCTAssertEqual(all[1].closingRotationID, "rot-B")
        XCTAssertNil(all[2].closedAt, "last segment is still open")
    }

    func testSegmentsAreIndependentPerSession() async throws {
        let ledger = makeLedger()
        let firstInS1 = try await ledger.append(
            makeEntry(auditID: "a-1", session: "S1"))
        _ = try await ledger.append(
            makeEntry(auditID: "a-2", session: "S2"))

        let s1 = await ledger.segments(forSession: "S1")
        let s2 = await ledger.segments(forSession: "S2")
        XCTAssertEqual(s1.count, 1)
        XCTAssertEqual(s2.count, 1)
        // The audit chain is global — S2's first entry anchors to
        // whatever the last appended entry's selfHash was (i.e.
        // S1's `a-1`). Only the genesis of the WHOLE ledger is
        // anchored to the "GENESIS" sentinel. Segments are per-
        // session bookkeeping on top of a global chain.
        XCTAssertEqual(s1.first?.startAnchor, "GENESIS")
        XCTAssertEqual(s2.first?.startAnchor, firstInS1.selfHash,
                       "per-session segment anchors to whatever the global chain's tail was")
        XCTAssertNotEqual(s1.first?.segmentID, s2.first?.segmentID)
    }

    // MARK: - LINEAGE_CUT semantics

    func testLineageCutUnknownRootThrows() async {
        let ledger = makeLedger()
        do {
            _ = try await ledger.lineageCut(request: cutRequest(
                root: "never-appended"))
            XCTFail("unknown root must throw")
        } catch BASSovereignAuditLedger.LedgerError.lineageRootNotFound(
            let id)
        {
            XCTAssertEqual(id, "never-appended")
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testLineageCutRootOnlyCutsSingleAudit() async throws {
        let ledger = makeLedger()
        _ = try await ledger.append(makeEntry(auditID: "a-root"))
        _ = try await ledger.append(makeEntry(
            auditID: "a-child", turn: "turn-2",
            signalRefs: ["a-root"]))

        let outcome = try await ledger.lineageCut(
            request: cutRequest(depth: .root))
        XCTAssertEqual(outcome.affectedAuditIDs, ["a-root"])
        XCTAssertTrue(outcome.protectedAuditIDs.isEmpty)
    }

    func testLineageCutBoundedHopsRespectsDepthBoundary() async throws {
        // Graph: root ← child (signalRef=root) ← grandchild (signalRef=child)
        let ledger = makeLedger()
        _ = try await ledger.append(makeEntry(auditID: "a-root"))
        _ = try await ledger.append(makeEntry(
            auditID: "a-child", turn: "turn-2",
            signalRefs: ["a-root"]))
        _ = try await ledger.append(makeEntry(
            auditID: "a-grandchild", turn: "turn-3",
            signalRefs: ["a-child"]))

        let outcome = try await ledger.lineageCut(
            request: cutRequest(depth: .bounded(hops: 1)))
        XCTAssertEqual(Set(outcome.affectedAuditIDs),
                       Set(["a-root", "a-child"]),
                       "one hop cuts root + direct reference descendants")
        XCTAssertFalse(
            outcome.affectedAuditIDs.contains("a-grandchild"),
            "bounded(hops=1) must not reach the grandchild")
    }

    func testLineageCutEntireLineageCascadesToFixpoint() async throws {
        let ledger = makeLedger()
        _ = try await ledger.append(makeEntry(auditID: "a-root"))
        _ = try await ledger.append(makeEntry(
            auditID: "a-1", turn: "t2", signalRefs: ["a-root"]))
        _ = try await ledger.append(makeEntry(
            auditID: "a-2", turn: "t3", signalRefs: ["a-1"]))
        _ = try await ledger.append(makeEntry(
            auditID: "a-3", turn: "t4", signalRefs: ["a-2"]))
        _ = try await ledger.append(makeEntry(
            auditID: "unrelated", turn: "t5"))

        let outcome = try await ledger.lineageCut(request: cutRequest())
        XCTAssertEqual(Set(outcome.affectedAuditIDs),
                       Set(["a-root", "a-1", "a-2", "a-3"]))
        XCTAssertFalse(
            outcome.affectedAuditIDs.contains("unrelated"),
            "unrelated entry must not be reached")
    }

    func testLineageCutProtectedRulesExcludeAndHaltCascade() async throws {
        // Graph: root → guarded → beyond
        // `guarded` carries a protected rule, so cascade stops at it.
        let ledger = makeLedger()
        _ = try await ledger.append(makeEntry(auditID: "a-root"))
        _ = try await ledger.append(makeEntry(
            auditID: "a-guarded", turn: "t2",
            ruleIDs: ["BR-004"],
            signalRefs: ["a-root"]))
        _ = try await ledger.append(makeEntry(
            auditID: "a-beyond", turn: "t3",
            signalRefs: ["a-guarded"]))

        let outcome = try await ledger.lineageCut(
            request: cutRequest(protected: ["BR-004"]))
        XCTAssertEqual(outcome.affectedAuditIDs, ["a-root"])
        XCTAssertEqual(outcome.protectedAuditIDs, ["a-guarded"])
        XCTAssertFalse(
            outcome.affectedAuditIDs.contains("a-beyond"),
            "cascade must not descend past a protected node")
        XCTAssertFalse(
            outcome.protectedAuditIDs.contains("a-beyond"),
            "unreached entries must not surface in protected list either")
    }

    // MARK: - LINEAGE_CUT side effects on the ledger

    func testLineageCutWritesMarkerEntryAndTriggersRotation() async throws {
        let ledger = makeLedger()
        _ = try await ledger.append(makeEntry(auditID: "a-root"))
        let outcome = try await ledger.lineageCut(request: cutRequest())

        // 1. Marker entry lives in the chain.
        let marker = try await ledger.query(
            byAuditRef: outcome.markerAuditID)
        XCTAssertEqual(marker.entry.verdictRef, "lineage-cut:cut-1")
        XCTAssertEqual(marker.entry.ruleIDs, ["LINEAGE-CUT"])
        XCTAssertEqual(Set(marker.entry.signalRefs),
                       Set(outcome.affectedAuditIDs))

        // 2. Rotation bounded the cut: current segment is fresh/empty,
        //    and the closed one carries the marker as its tail.
        let current = await ledger.currentSegment(forSession: "session-A")
        XCTAssertNil(current,
            "immediately after a cut, no open segment for the session")
        let segs = await ledger.segments(forSession: "session-A")
        XCTAssertEqual(segs.count, 1, "exactly one segment exists")
        XCTAssertEqual(segs.last?.tailHash, marker.selfHash,
            "cut marker is the closing tail of the segment")
        XCTAssertEqual(segs.last?.closedBy, .lineageCut)
    }

    func testLineageCutOutcomeIsQueryableByMarker() async throws {
        let ledger = makeLedger()
        _ = try await ledger.append(makeEntry(auditID: "a-root"))
        let outcome = try await ledger.lineageCut(request: cutRequest())

        let fetched = await ledger.lineageCutOutcome(
            markerAuditID: outcome.markerAuditID)
        XCTAssertEqual(fetched?.cutID, outcome.cutID)
        XCTAssertEqual(fetched?.affectedAuditIDs,
                       outcome.affectedAuditIDs)
    }

    func testChainIntegrityHoldsAcrossLineageCutMarker() async throws {
        let ledger = makeLedger()
        _ = try await ledger.append(makeEntry(auditID: "a-root"))
        _ = try await ledger.append(makeEntry(
            auditID: "a-child", turn: "t2", signalRefs: ["a-root"]))
        _ = try await ledger.lineageCut(request: cutRequest())
        _ = try await ledger.append(makeEntry(
            auditID: "a-postcut", turn: "t3"))

        // The whole chain — including the synthetic cut marker — must
        // still pass end-to-end integrity verification.
        try await ledger.verifyChainIntegrity()
    }

    // MARK: - Validation

    func testLineageCutEmptyCutIDRejected() async {
        let ledger = makeLedger()
        do {
            _ = try await ledger.append(makeEntry(auditID: "a-root"))
            _ = try await ledger.lineageCut(
                request: cutRequest(cutID: ""))
            XCTFail("empty cutID must be rejected")
        } catch BASSovereignAuditLedger.LedgerError.invalidEntry {
            // expected
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }
}
