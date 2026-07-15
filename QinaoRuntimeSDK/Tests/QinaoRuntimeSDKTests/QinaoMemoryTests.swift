import XCTest
import BASMemory
@testable import QinaoMemory

/// M7.4 — QinaoMemory façade over `BASMemoryGovernance` +
/// `BASMemoryTierFilter`.
///
/// The substrate primitives are exhaustively tested in the BAS suite;
/// this file only proves the *façade* behavior:
///
/// 1. Admission runs through the real governance gate (confidence
///    floor enforced; on-floor accepts, below-floor rejects).
/// 2. Recall honours scope / sensitivity / tier filters using the
///    substrate's canonical ordering.
/// 3. Frontstage recall drops cold-tier entries (L8 rule).
/// 4. Cascade deletes actually clear every matching memory across
///    all tiers — not just one.
/// 5. Targeted `forget(id:)` surfaces `MemoryError.notFound` for
///    unknown IDs.
final class QinaoMemoryTests: XCTestCase {

    private func makeMemory(
        minimumConfidence: Double = 0.6
    ) -> QinaoMemory {
        QinaoMemory(
            minimumConfidence: minimumConfidence,
            now: { Date(timeIntervalSince1970: 1_700_000_000) })
    }

    private func admitRequest(
        kind: BASMemoryKind = .episodic,
        content: String = "default content",
        scope: BASMemoryScope = .session,
        sensitivity: BASMemorySensitivity = .low,
        confidence: Double = 0.8,
        preferredTier: BASMemoryTier = .warm
    ) -> QinaoMemory.AdmitRequest {
        QinaoMemory.AdmitRequest(
            kind: kind,
            content: content,
            scope: scope,
            sensitivity: sensitivity,
            confidence: confidence,
            preferredTier: preferredTier)
    }

    /// deep-audit P1-7 (2026-07-13): the blind `admit(_:)` now HOLDS as `.candidate`
    /// (a constitution-less host has no promotion authority — see
    /// QinaoMemoryConstitutionGateTests.testBlindAdmitHoldsAsCandidate…). This façade
    /// suite pins recall/tier/cascade behaviour, which requires GOVERNED memory, so it
    /// admits through a permissive constitution — the real path a host with promotion
    /// authority uses. The governance-authority semantics themselves live in the gate suite.
    private static let permissive: BASHostConstitution = {
        var c = BASHostConstitution(hostID: "facade-host", activeVersion: "v1")
        c.consentLattice.memoryWriteScope = "all"
        c.consentLattice.memoryPromotionScope = "auto"
        return c
    }()

    @discardableResult
    private func admitGoverned(
        _ m: QinaoMemory, _ req: QinaoMemory.AdmitRequest
    ) async throws -> BASGovernedMemory {
        try await m.admit(req, under: Self.permissive)
    }

    // MARK: - Admission

    func testAdmitPromotesCandidateAboveConfidenceFloor() async throws {
        let memory = makeMemory(minimumConfidence: 0.6)
        let governed = try await admitGoverned(memory,
            admitRequest(confidence: 0.75))
        XCTAssertEqual(governed.governanceStatus, .governed)
        XCTAssertEqual(governed.content, "default content")
        let count = await memory.count()
        XCTAssertEqual(count, 1)
    }

    func testAdmitRejectsCandidateBelowConfidenceFloor() async throws {
        let memory = makeMemory(minimumConfidence: 0.6)
        do {
            _ = try await admitGoverned(memory,admitRequest(confidence: 0.4))
            XCTFail("admit should reject below-floor candidate")
        } catch QinaoMemory.MemoryError.rejectedByGovernance(let reason) {
            XCTAssertEqual(reason, "confidence-below-floor")
        }
        let count = await memory.count()
        XCTAssertEqual(count, 0,
            "rejected admission must not mutate the store")
    }

    // MARK: - Recall: scope / sensitivity / tier filters

    func testRecallHonoursScopeFilter() async throws {
        let memory = makeMemory()
        _ = try await admitGoverned(memory,
            admitRequest(content: "a", scope: .session))
        _ = try await admitGoverned(memory,
            admitRequest(content: "b", scope: .user))
        _ = try await admitGoverned(memory,
            admitRequest(content: "c", scope: .device))
        let sessionOnly = await memory.recall(scope: .session)
        XCTAssertEqual(sessionOnly.map(\.content), ["a"])
    }

    func testRecallHonoursTierFilter() async throws {
        let memory = makeMemory()
        _ = try await admitGoverned(memory,
            admitRequest(content: "hot", preferredTier: .hot))
        _ = try await admitGoverned(memory,
            admitRequest(content: "warm", preferredTier: .warm))
        _ = try await admitGoverned(memory,
            admitRequest(content: "cold", preferredTier: .cold))
        let hotOnly = await memory.recall(tiers: [.hot])
        XCTAssertEqual(hotOnly.map(\.content), ["hot"])
        let hotOrWarm = await memory.recall(tiers: [.hot, .warm])
        XCTAssertEqual(Set(hotOrWarm.map(\.content)), ["hot", "warm"])
    }

    func testRecallOrdersByTierThenConfidence() async throws {
        let memory = makeMemory()
        _ = try await admitGoverned(memory,
            admitRequest(
                content: "warm-lo",
                confidence: 0.7,
                preferredTier: .warm))
        _ = try await admitGoverned(memory,
            admitRequest(
                content: "hot-lo",
                confidence: 0.65,
                preferredTier: .hot))
        _ = try await admitGoverned(memory,
            admitRequest(
                content: "hot-hi",
                confidence: 0.95,
                preferredTier: .hot))

        // Expected substrate ordering: tier desc, then confidence desc.
        let recalled = await memory.recall()
        XCTAssertEqual(
            recalled.map(\.content),
            ["hot-hi", "hot-lo", "warm-lo"])
    }

    // MARK: - Frontstage recall

    func testFrontstageRecallDropsColdTier() async throws {
        let memory = makeMemory()
        _ = try await admitGoverned(memory,
            admitRequest(content: "hot-trace", preferredTier: .hot))
        _ = try await admitGoverned(memory,
            admitRequest(content: "warm-thread", preferredTier: .warm))
        _ = try await admitGoverned(memory,
            admitRequest(content: "cold-prior", preferredTier: .cold))

        let front = await memory.recallFrontstage()
        XCTAssertEqual(
            Set(front.map(\.content)),
            ["hot-trace", "warm-thread"])
        XCTAssertFalse(front.map(\.content).contains("cold-prior"))
    }

    // MARK: - Forget (cascade semantics)

    func testForgetByScopeRemovesAllMatches() async throws {
        let memory = makeMemory()
        _ = try await admitGoverned(memory,
            admitRequest(content: "a", scope: .session))
        _ = try await admitGoverned(memory,
            admitRequest(content: "b", scope: .session))
        _ = try await admitGoverned(memory,
            admitRequest(content: "keep", scope: .user))

        let removed = await memory.forget(scope: .session)
        XCTAssertEqual(removed.count, 2)
        let remaining = await memory.recall()
        XCTAssertEqual(remaining.map(\.content), ["keep"])
    }

    func testForgetBySensitivityRemovesAllMatches() async throws {
        let memory = makeMemory()
        _ = try await admitGoverned(memory,
            admitRequest(content: "low-1", sensitivity: .low))
        _ = try await admitGoverned(memory,
            admitRequest(content: "high-1", sensitivity: .high))
        _ = try await admitGoverned(memory,
            admitRequest(content: "high-2", sensitivity: .high))

        let removed = await memory.forget(sensitivity: .high)
        XCTAssertEqual(removed.count, 2)
        let remaining = await memory.recall()
        XCTAssertEqual(remaining.map(\.content), ["low-1"])
    }

    func testForgetByIDRemovesExactlyOne() async throws {
        let memory = makeMemory()
        let a = try await admitGoverned(memory,admitRequest(content: "a"))
        _ = try await admitGoverned(memory,admitRequest(content: "b"))

        let removed = try await memory.forget(id: a.id)
        XCTAssertEqual(removed.content, "a")
        let remaining = await memory.recall()
        XCTAssertEqual(remaining.map(\.content), ["b"])
    }

    func testForgetByIDNotFoundSurfacesTypedError() async throws {
        let memory = makeMemory()
        let ghost = UUID()
        do {
            _ = try await memory.forget(id: ghost)
            XCTFail("expected notFound")
        } catch QinaoMemory.MemoryError.notFound(let id) {
            XCTAssertEqual(id, ghost)
        }
    }

    func testForgetAllWipesEveryTier() async throws {
        let memory = makeMemory()
        _ = try await admitGoverned(memory,
            admitRequest(preferredTier: .hot))
        _ = try await admitGoverned(memory,
            admitRequest(preferredTier: .warm))
        _ = try await admitGoverned(memory,
            admitRequest(preferredTier: .cold))

        let removed = await memory.forgetAll()
        XCTAssertEqual(removed, 3)
        let count = await memory.count()
        XCTAssertEqual(count, 0)
    }

    // MARK: - M73 cascade-receipt semantics

    /// Deterministic cascade-ID factory keyed on a lock-guarded counter
    /// so every receipt gets a stable, spec-able identifier. The factory
    /// itself is a synchronous `() -> String` closure, so we cannot
    /// suspend into an actor — a class + NSLock keeps the synchronous
    /// contract while remaining Sendable-safe.
    private final class CascadeIDSequence: @unchecked Sendable {
        private var nextID = 0
        private let lock = NSLock()
        func next() -> String {
            lock.lock()
            defer { lock.unlock() }
            let id = String(format: "cid-%03d", nextID)
            nextID += 1
            return id
        }
    }

    private func makeMemoryWithDeterministicCascadeIDs(
        minimumConfidence: Double = 0.6,
        timestamp: Date = Date(timeIntervalSince1970: 1_700_000_000),
        sequence: CascadeIDSequence
    ) -> QinaoMemory {
        QinaoMemory(
            minimumConfidence: minimumConfidence,
            now: { timestamp },
            cascadeIDFactory: { sequence.next() })
    }

    /// Every `forget(id:)` — even one that finds a match — produces
    /// exactly one receipt, and that receipt lists the removed ID
    /// plus the default cache refs that downstream projections must
    /// invalidate.
    func testForgetByIDProducesReceiptWithRemovedIDAndCacheRefs() async throws {
        let sequence = CascadeIDSequence()
        let memory = makeMemoryWithDeterministicCascadeIDs(sequence: sequence)
        let governed = try await admitGoverned(memory,admitRequest(content: "bye"))

        _ = try await memory.forget(id: governed.id)

        let receipts = await memory.cascadeLedger()
        XCTAssertEqual(receipts.count, 1)
        let receipt = receipts[0]
        XCTAssertEqual(receipt.cascadeID, "cid-000")
        XCTAssertEqual(receipt.trigger, .singleID)
        XCTAssertEqual(receipt.rootTargets, [governed.id.uuidString])
        XCTAssertEqual(receipt.removedMemoryIDs, [governed.id])
        XCTAssertEqual(receipt.executionState, .completed)
        XCTAssertTrue(receipt.cacheRefsInvalidated.contains(
            "qinao.memory.recall-frontstage"))
        XCTAssertEqual(
            receipt.executedAt,
            Date(timeIntervalSince1970: 1_700_000_000))
        XCTAssertTrue(receipt.summary.hasPrefix("forget(id:)"))
    }

    /// A `forget(id:)` against a non-existent UUID still produces a
    /// receipt with `.empty` state and zero cache-ref invalidation —
    /// the paper trail stays complete even for refused deletes.
    func testForgetByIDNotFoundProducesEmptyReceipt() async throws {
        let sequence = CascadeIDSequence()
        let memory = makeMemoryWithDeterministicCascadeIDs(sequence: sequence)
        let ghost = UUID()

        do {
            _ = try await memory.forget(id: ghost)
            XCTFail("expected notFound")
        } catch QinaoMemory.MemoryError.notFound { /* expected */ }

        let receipts = await memory.cascadeLedger()
        XCTAssertEqual(receipts.count, 1)
        let receipt = receipts[0]
        XCTAssertEqual(receipt.trigger, .singleID)
        XCTAssertEqual(receipt.rootTargets, [ghost.uuidString])
        XCTAssertTrue(receipt.removedMemoryIDs.isEmpty)
        XCTAssertEqual(receipt.executionState, .empty)
        XCTAssertTrue(receipt.cacheRefsInvalidated.isEmpty)
    }

    /// A sensitivity-wide forget captures every removed ID in the
    /// receipt, in a stable lexicographic order, and records the
    /// trigger as `.sensitivity`.
    func testForgetBySensitivityReceiptCapturesEveryRemovedID() async throws {
        let sequence = CascadeIDSequence()
        let memory = makeMemoryWithDeterministicCascadeIDs(sequence: sequence)
        _ = try await admitGoverned(memory,admitRequest(content: "low", sensitivity: .low))
        let h1 = try await admitGoverned(memory,admitRequest(content: "h1", sensitivity: .high))
        let h2 = try await admitGoverned(memory,admitRequest(content: "h2", sensitivity: .high))

        _ = await memory.forget(sensitivity: .high)

        let receipts = await memory.cascadeLedger()
        XCTAssertEqual(receipts.count, 1)
        let receipt = receipts[0]
        XCTAssertEqual(receipt.trigger, .sensitivity)
        XCTAssertEqual(receipt.rootTargets, ["high"])
        XCTAssertEqual(receipt.executionState, .completed)
        XCTAssertEqual(
            Set(receipt.removedMemoryIDs),
            Set([h1.id, h2.id]),
            "cascade must log every matched row")
        XCTAssertEqual(
            receipt.removedMemoryIDs.map(\.uuidString),
            receipt.removedMemoryIDs.map(\.uuidString).sorted(),
            "cascade IDs must be lexicographically ordered for stable audit")
    }

    /// A `forgetAll` wipe captures every ID and emits a receipt whose
    /// trigger is `.all` and root targets are empty — the "no
    /// root target, match everything live" shape.
    func testForgetAllReceiptShapeWithEmptyRoots() async throws {
        let sequence = CascadeIDSequence()
        let memory = makeMemoryWithDeterministicCascadeIDs(sequence: sequence)
        _ = try await admitGoverned(memory,admitRequest(content: "a"))
        _ = try await admitGoverned(memory,admitRequest(content: "b"))

        _ = await memory.forgetAll()

        let receipts = await memory.cascadeLedger()
        XCTAssertEqual(receipts.count, 1)
        let receipt = receipts[0]
        XCTAssertEqual(receipt.trigger, .all)
        XCTAssertTrue(receipt.rootTargets.isEmpty)
        XCTAssertEqual(receipt.removedMemoryIDs.count, 2)
        XCTAssertEqual(receipt.executionState, .completed)
        XCTAssertTrue(receipt.summary.hasPrefix("forgetAll"))
    }

    /// The ledger is append-only: multiple forget() calls in
    /// sequence each produce their own receipt, in execution order.
    func testCascadeLedgerAccumulatesAcrossCalls() async throws {
        let sequence = CascadeIDSequence()
        let memory = makeMemoryWithDeterministicCascadeIDs(sequence: sequence)
        let a = try await admitGoverned(memory,admitRequest(content: "a", scope: .session))
        _ = try await admitGoverned(memory,admitRequest(content: "b", scope: .user))

        _ = try await memory.forget(id: a.id)              // cid-000
        _ = await memory.forget(scope: .user)              // cid-001
        _ = await memory.forgetAll()                       // cid-002 (empty)

        let receipts = await memory.cascadeLedger()
        XCTAssertEqual(receipts.map(\.cascadeID),
                       ["cid-000", "cid-001", "cid-002"])
        XCTAssertEqual(receipts.map(\.trigger),
                       [.singleID, .scope, .all])
        XCTAssertEqual(receipts[0].executionState, .completed)
        XCTAssertEqual(receipts[1].executionState, .completed)
        XCTAssertEqual(receipts[2].executionState, .empty,
            "forgetAll over empty store must record .empty")
    }

    /// `recentCascadeReceipts(limit:)` returns the tail of the
    /// ledger newest-last, bounded by the given limit, without
    /// mutating the ledger.
    func testRecentCascadeReceiptsReturnsTailSlice() async throws {
        let sequence = CascadeIDSequence()
        let memory = makeMemoryWithDeterministicCascadeIDs(sequence: sequence)
        _ = try await admitGoverned(memory,admitRequest(content: "a"))
        _ = try await admitGoverned(memory,admitRequest(content: "b"))
        _ = try await admitGoverned(memory,admitRequest(content: "c"))

        _ = await memory.forget(scope: .user)              // cid-000 empty
        _ = await memory.forget(scope: .session)           // cid-001 completed
        _ = await memory.forgetAll()                       // cid-002 empty

        let lastTwo = await memory.recentCascadeReceipts(limit: 2)
        XCTAssertEqual(lastTwo.map(\.cascadeID),
                       ["cid-001", "cid-002"])
        let zero = await memory.recentCascadeReceipts(limit: 0)
        XCTAssertTrue(zero.isEmpty)
        let full = await memory.cascadeLedger()
        XCTAssertEqual(full.count, 3,
            "recent-receipts query must not mutate the ledger")
    }
}
