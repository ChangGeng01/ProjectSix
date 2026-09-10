import XCTest
import CryptoKit
import BASRuntimeCore
import BASSovereign
@testable import QinaoSovereign

/// M168 — `warmCacheProcessedTurnsFromLedger()` seeds the M161/
/// M164 idempotency state from a persistent audit ledger so the
/// duplicate-turn guarantee survives process restarts.
///
/// The pre-M168 architecture was process-scoped: the
/// `processedTurnKeys` Set lived only in the actor's memory, so
/// after a restart a host re-submitting `(sessionID, turnID)`
/// would write a duplicate audit-chain entry. M168 closes that
/// gap by walking the ledger snapshot at startup and registering
/// every prior `(sessionID, turnID)` tuple into the FIFO.
///
/// Cross-process uniqueness is structurally enabled by this
/// commit but only practically enforced once the underlying
/// ledger persists (M91 SQLite or equivalent). The architecture
/// is the contract; the persistence is the substrate.
///
/// Pins:
///   1. Empty ledger → warm-cache returns 0; processedTurnCount
///      stays at 0.
///   2. Ledger with N entries → warm-cache returns N;
///      processedTurnCount = N.
///   3. Restart simulation: plane A processes turns; plane B
///      sharing A's ledger + warm-cache rejects the same turns.
///   4. Warm-cache respects FIFO cap; entries past the cap are
///      not seeded (but newest-first: oldest entries get evicted
///      so the most recent N seed).
///   5. Warm-cache is idempotent: calling it twice doesn't
///      double-count.
final class QinaoRuntimeM168WarmCacheTests: XCTestCase {

    /// Build a control plane that shares an existing ledger.
    /// Used to simulate "process restart" — plane A retires its
    /// state, plane B is the fresh process construction with the
    /// same persisted ledger underneath.
    private func makeSovereignSharing(
        ledger: BASSovereignAuditLedger,
        processedTurnCapacity: Int =
            QinaoSovereignControlPlane
                .defaultProcessedTurnCapacity,
        now: @escaping @Sendable () -> Date = { Date() }
    ) -> QinaoSovereignControlPlane {
        let snapshotManager = BASSovereignSnapshotManager(now: now)
        let versionTree = BASSovereignHostVersionTree(now: now)
        let coordinator = BASSovereignCleanRebootCoordinator(
            snapshotManager: snapshotManager,
            versionTree: versionTree,
            ledger: ledger,
            now: now)
        let tokenAuthority = BASSovereignTokenAuthority(now: now)
        let engine = BASSovereignVerdictEngine(
            ledger: ledger, now: now)
        let verifier = BASSovereignTurnVerifier(engine: engine)
        return QinaoSovereignControlPlane(
            coordinator: coordinator,
            tokenAuthority: tokenAuthority,
            turnVerifier: verifier,
            auditLedger: ledger,
            warrantTTLSeconds: 10,
            now: now,
            processedTurnCapacity: processedTurnCapacity)
    }

    // MARK: - 1. Empty ledger → seeds nothing

    func testEmptyLedgerSeedsZero() async {
        let ledger = BASSovereignAuditLedger(
            signingSecret: SymmetricKey(size: .bits256))
        let sov = makeSovereignSharing(ledger: ledger)
        let seeded = await sov.warmCacheProcessedTurnsFromLedger()
        XCTAssertEqual(seeded, 0)
        let count = await sov.processedTurnCount()
        XCTAssertEqual(count, 0)
    }

    // MARK: - 2. Pre-populated ledger → seeds matching count

    func testPrePopulatedLedgerSeedsAllEntries() async throws {
        let fxA = await QinaoTestFixture.make()
        // Run a few turns through plane A so the ledger fills up.
        for i in 0..<5 {
            _ = try await fxA.runtime.sendSession(
                QinaoSovereignControlPlane.TurnObservations(
                    sessionID: "sess.warm",
                    turnID: "turn.\(i)",
                    snapshotRef: "s",
                    policyHash: "p"),
                coordinatorSeverity: .pass)
        }
        // Plane B shares A's ledger (simulates restart).
        let sovB = makeSovereignSharing(ledger: fxA.ledger)
        let seeded = await sovB
            .warmCacheProcessedTurnsFromLedger()
        XCTAssertGreaterThanOrEqual(
            seeded, 5,
            "5 turns processed → ledger has ≥5 entries to seed")
        let count = await sovB.processedTurnCount()
        XCTAssertGreaterThanOrEqual(count, 5)
    }

    // MARK: - 3. Restart simulation: B rejects A's prior turns

    func testRestartSimulationRejectsDuplicates() async throws {
        let fxA = await QinaoTestFixture.make()
        _ = try await fxA.runtime.sendSession(
            QinaoSovereignControlPlane.TurnObservations(
                sessionID: "sess.restart",
                turnID: "turn.alpha",
                snapshotRef: "s",
                policyHash: "p"),
            coordinatorSeverity: .pass)

        // Plane B is fresh — same ledger, no in-memory state
        // beyond what warm-cache pulls.
        let sovB = makeSovereignSharing(ledger: fxA.ledger)
        let beforeWarm = await sovB.claimTurn(
            sessionID: "sess.restart", turnID: "turn.alpha")
        XCTAssertEqual(
            beforeWarm, .claimed,
            "Pre-warm-cache plane B has empty state; it would " +
            "have happily claimed and re-processed the same " +
            "turn — the duplicate-audit-entry bug.")
        // Release the test claim so warm-cache starts clean.
        await sovB.releaseTurnClaim(
            sessionID: "sess.restart", turnID: "turn.alpha")

        _ = await sovB.warmCacheProcessedTurnsFromLedger()

        let afterWarm = await sovB.claimTurn(
            sessionID: "sess.restart", turnID: "turn.alpha")
        XCTAssertEqual(
            afterWarm, .alreadyProcessed,
            "Post-warm-cache plane B sees A's prior turn and " +
            "rejects re-submission with .alreadyProcessed — " +
            "M161 idempotency now survives restart.")
    }

    // MARK: - 4. Warm-cache respects FIFO cap

    func testWarmCacheRespectsFIFOCap() async throws {
        let fxA = await QinaoTestFixture.make()
        // Process more turns than plane B's cap.
        for i in 0..<10 {
            _ = try await fxA.runtime.sendSession(
                QinaoSovereignControlPlane.TurnObservations(
                    sessionID: "sess.cap",
                    turnID: "turn.\(i)",
                    snapshotRef: "s",
                    policyHash: "p"),
                coordinatorSeverity: .pass)
        }
        // Plane B has a small cap — only the last `cap` ledger
        // entries should remain in the FIFO after eviction.
        let sovB = makeSovereignSharing(
            ledger: fxA.ledger, processedTurnCapacity: 3)
        _ = await sovB.warmCacheProcessedTurnsFromLedger()
        let count = await sovB.processedTurnCount()
        XCTAssertEqual(
            count, 3,
            "FIFO cap holds; older entries get evicted during " +
            "the warm-cache walk.")
    }

    // MARK: - 5. Idempotent — calling twice doesn't double-count

    func testWarmCacheIsIdempotent() async throws {
        let fxA = await QinaoTestFixture.make()
        for i in 0..<3 {
            _ = try await fxA.runtime.sendSession(
                QinaoSovereignControlPlane.TurnObservations(
                    sessionID: "sess.idem",
                    turnID: "turn.\(i)",
                    snapshotRef: "s",
                    policyHash: "p"),
                coordinatorSeverity: .pass)
        }
        let sovB = makeSovereignSharing(ledger: fxA.ledger)
        let firstSeeded = await sovB
            .warmCacheProcessedTurnsFromLedger()
        let countAfterFirst = await sovB.processedTurnCount()
        let secondSeeded = await sovB
            .warmCacheProcessedTurnsFromLedger()
        let countAfterSecond = await sovB.processedTurnCount()
        XCTAssertGreaterThanOrEqual(firstSeeded, 3)
        XCTAssertEqual(secondSeeded, 0,
            "Second warm-cache call must add nothing — every " +
            "ledger entry already exists in the FIFO.")
        XCTAssertEqual(countAfterFirst, countAfterSecond)
    }
}
