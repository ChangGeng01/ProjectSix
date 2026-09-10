import XCTest
@testable import BASObservability

/// audit M-c / policy-obs-misc MED-1 (flagged arguably-HIGH) — the ticket-lifecycle SQLite store
/// used DELETE-all + INSERT-all of the caller's whole snapshot, so a STALE coordinator committing
/// after another process advanced a ticket wiped the newer row and RESURRECTED the ticket at its
/// stale state, brushing invariant #3 (private host experience must not re-enter the distillation
/// pipeline). The fix: per-row upsert guarded by a monotonic `state_rank` + a terminal freeze.
/// Plus `persistQuietly` no longer silently swallows save failures.
final class BASUpdateTicketLifecycleResurrectionTests: XCTestCase {

    private var tempRoot: URL!

    override func setUpWithError() throws {
        tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("qinao-lifecycle-resurrect-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws {
        if let tempRoot { try? FileManager.default.removeItem(at: tempRoot) }
    }

    private func ticket(_ id: String) -> BASUpdateTicket {
        BASUpdateTicket(ticketID: id, sessionRef: "s", summary: "sum", confidence: 0.7)
    }
    private func entry(_ id: String, _ state: BASUpdateTicketLifecycleState) -> BASUpdateTicketLifecycleEntry {
        BASUpdateTicketLifecycleEntry(ticket: ticket(id), state: state)
    }
    private func store(_ name: String) throws -> BASUpdateTicketLifecycleSQLiteStorage {
        try BASUpdateTicketLifecycleSQLiteStorage(url: tempRoot.appendingPathComponent(name))
    }

    // MARK: - Terminal freeze (invariant #3)

    func testTerminalStateIsNotResurrectedByStaleWriter() async throws {
        let storage = try store("resurrect.sqlite")
        // A ticket reaches a terminal .rejected (coordinator B's decision).
        try await storage.save(["T": entry("T", .proposed)])
        try await storage.save(["T": entry("T", .rejected)])
        // A STALE writer (coordinator A holding a pre-rejection snapshot) tries to save it back at a
        // NON-terminal, distillation-eligible state — the exact resurrection the audit flagged.
        try await storage.save(["T": entry("T", .queuedForDistillation)])
        let loaded = try await storage.load()
        XCTAssertEqual(loaded["T"]?.state, .rejected,
            "a terminal (rejected) ticket must NOT resurrect to a distillation-eligible state")
    }

    func testTerminalDistilledIsAlsoFrozen() async throws {
        let storage = try store("distilled.sqlite")
        try await storage.save(["T": entry("T", .distilled)])
        try await storage.save(["T": entry("T", .trialPassed)])   // stale, distillation-eligible
        let loaded = try await storage.load()
        XCTAssertEqual(loaded["T"]?.state, .distilled, "a terminal distilled ticket must be frozen")
    }

    // MARK: - Rank monotonicity (no non-terminal regression)

    func testStaleLowerRankWriteIsRejected() async throws {
        let storage = try store("rank.sqlite")
        try await storage.save(["T": entry("T", .proposed)])
        try await storage.save(["T": entry("T", .queuedForDistillation)])   // rank 5
        try await storage.save(["T": entry("T", .proposed)])               // stale rank 0
        let loaded = try await storage.load()
        XCTAssertEqual(loaded["T"]?.state, .queuedForDistillation,
            "a stale lower-rank write must not regress a non-terminal ticket")
    }

    func testLegalForwardTransitionsPersist() async throws {
        let storage = try store("forward.sqlite")
        for s: BASUpdateTicketLifecycleState in [.proposed, .trialing, .trialPassed, .queuedForDistillation, .distilled] {
            try await storage.save(["T": entry("T", s)])
        }
        let loaded = try await storage.load()
        XCTAssertEqual(loaded["T"]?.state, .distilled, "legal forward progression must persist")
    }

    // MARK: - Per-row merge (no DELETE-all)

    func testGuardedMergeAccumulatesDistinctTickets() async throws {
        let storage = try store("merge.sqlite")
        try await storage.save(["a": entry("a", .proposed)])
        try await storage.save(["b": entry("b", .proposed)])   // no DELETE-all ⇒ both persist
        let loaded = try await storage.load()
        XCTAssertEqual(Set(loaded.keys), ["a", "b"],
            "per-row merge (no DELETE-all) must retain distinct tickets across saves")
    }

    // MARK: - persistQuietly is fail-closed-observable

    private struct FailingStorage: BASUpdateTicketLifecycleStorage {
        struct Boom: Error {}
        func load() async throws -> [String: BASUpdateTicketLifecycleEntry] { [:] }
        func save(_ entries: [String: BASUpdateTicketLifecycleEntry]) async throws { throw Boom() }
    }

    func testPersistFailureIsObservable() async throws {
        let coord = BASUpdateTicketLifecycleCoordinator(storage: FailingStorage())
        _ = try await coord.submit(ticket("T"))   // triggers persistQuietly → save throws
        await coord.drainPersistChain()
        let count = await coord.persistFailureCount
        let lastErr = await coord.lastPersistError
        XCTAssertGreaterThanOrEqual(count, 1,
            "a swallowed save failure must be observable, not silently absorbed (audit M-c)")
        XCTAssertNotNil(lastErr, "the last persist error must be recorded")
    }
}
