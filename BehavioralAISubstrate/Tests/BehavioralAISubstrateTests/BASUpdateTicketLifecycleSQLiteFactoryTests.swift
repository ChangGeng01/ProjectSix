import XCTest
@testable import BASHostKit
@testable import BASObservability
@testable import BASMemory
@testable import BASRuntimeCore

/// chapter 二百五十 / M737 — production-wire factory coverage for
/// `BASUpdateTicketLifecycleCoordinator.sqliteBacked(...)`.
///
/// 附录 V Stage 0 Step 3 of 3: storage primitive shipped already
/// (chapter 二百六十八 / M270), but production has had to write
/// the same 4-line SQLite-backed coordinator construction every
/// time. chapter 二百五十 collapses that into a single static
/// factory; this suite verifies:
///
///   1. Factory pre-loads on-disk state via `restore()` inline so
///      the returned coordinator immediately reflects every prior
///      ticket without manual intervention.
///   2. Cross-session round-trip — submit + advance tickets in
///      session A, drop coordinator, build a fresh factory at the
///      same storage root in session B, and the tickets are
///      back at their advanced state. THE KEY TEST.
///   3. Both factory variants (storageRoot-based unified-locator
///      layout and explicit-URL escape hatch) work identically.
///   4. Optional `auditSink:` and `clock:` seams reach through to
///      the underlying coordinator.
///   5. Unified-locator layout places the file at the canonical
///      `<root>/lifecycle.sqlite` path.
final class BASUpdateTicketLifecycleSQLiteFactoryTests: XCTestCase {

    // MARK: - Fixtures

    private var tempRoot: URL!

    override func setUpWithError() throws {
        tempRoot = FileManager.default
            .temporaryDirectory
            .appendingPathComponent(
                "qinao-lifecycle-factory-test-\(UUID().uuidString)",
                isDirectory: true)
    }

    override func tearDownWithError() throws {
        if let tempRoot {
            try? FileManager.default.removeItem(at: tempRoot)
        }
    }

    private func makeTicket(id: String) -> BASUpdateTicket {
        BASUpdateTicket(
            ticketID: id,
            sessionRef: "sess-\(id)",
            summary: "test ticket \(id)",
            confidence: 0.7)
    }

    // MARK: - 1. Factory restores empty state cleanly

    func testFactoryFromFreshRootReturnsEmptyCoordinator()
        async throws
    {
        let coord = try await BASUpdateTicketLifecycleCoordinator
            .sqliteBacked(storageRoot: tempRoot)
        let count = await coord.count()
        XCTAssertEqual(count, 0)
    }

    // MARK: - 2. THE KEY TEST — cross-session ticket survival

    func testFactoryCrossSessionTicketContinuitySurvivesReopen()
        async throws
    {
        // Session A — submit + advance 2 tickets.
        do {
            let coordA = try await
                BASUpdateTicketLifecycleCoordinator.sqliteBacked(
                    storageRoot: tempRoot)
            _ = try await coordA.submit(makeTicket(id: "t-1"))
            try await coordA.startTrial(
                ticketID: "t-1", trialRecordRef: "tr-1")
            try await coordA.markTrialOutcome(
                ticketID: "t-1",
                outcome: .passed(reasonCodes: ["clean"]))
            try await coordA.approveForDistillation(
                ticketID: "t-1", sovereignVerdictRef: "vr-1")
            _ = try await coordA.submit(makeTicket(id: "t-2"))
            await coordA.drainPersistChain()
        }

        // Session B — independent factory call, same root.
        let coordB = try await BASUpdateTicketLifecycleCoordinator
            .sqliteBacked(storageRoot: tempRoot)
        let count = await coordB.count()
        XCTAssertEqual(count, 2)

        let entry1 = await coordB.entry(ticketID: "t-1")
        XCTAssertEqual(
            entry1?.state,
            .queuedForDistillation)
        XCTAssertEqual(
            entry1?.sovereignVerdictRef, "vr-1")
        XCTAssertGreaterThanOrEqual(
            entry1?.history.count ?? 0, 3)

        let entry2 = await coordB.entry(ticketID: "t-2")
        XCTAssertEqual(entry2?.state, .proposed)
    }

    // MARK: - 3. Explicit databaseURL overload behaves the same

    func testFactoryFromExplicitURLPersistsAndRestores()
        async throws
    {
        try BASUnifiedStorageLocator.ensureRootDirectory(
            at: tempRoot)
        let dbURL = tempRoot
            .appendingPathComponent("custom.sqlite")

        do {
            let coordA = try await
                BASUpdateTicketLifecycleCoordinator.sqliteBacked(
                    databaseURL: dbURL)
            _ = try await coordA.submit(makeTicket(id: "explicit-1"))
            await coordA.drainPersistChain()
        }

        let coordB = try await BASUpdateTicketLifecycleCoordinator
            .sqliteBacked(databaseURL: dbURL)
        let count = await coordB.count()
        XCTAssertEqual(count, 1)
        let entry = await coordB.entry(ticketID: "explicit-1")
        XCTAssertEqual(entry?.state, .proposed)
    }

    // MARK: - 4. Custom clock seam respected

    func testFactoryUsesProvidedClock() async throws {
        let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)
        let coord = try await BASUpdateTicketLifecycleCoordinator
            .sqliteBacked(
                storageRoot: tempRoot,
                clock: { fixedDate })
        _ = try await coord.submit(makeTicket(id: "ck-1"))
        // submit() doesn't record a transition (proposed is initial
        // state). The clock surfaces on the FIRST real transition
        // — startTrial moves proposed → trialing and stamps `at`.
        try await coord.startTrial(
            ticketID: "ck-1", trialRecordRef: "tr-ck")
        let entry = await coord.entry(ticketID: "ck-1")
        XCTAssertEqual(entry?.history.first?.at, fixedDate)
    }

    // MARK: - 5. Audit sink invoked on terminal transitions

    /// Promotion to `.distilled` is the canonical terminal
    /// transition that surfaces the M265 audit hook. The factory
    /// must thread `auditSink:` through unchanged.
    func testFactoryAuditSinkReceivesTerminalTransitions()
        async throws
    {
        actor AuditCollector {
            private(set) var entries: [BASSovereignAuditEntry] = []
            func record(_ e: BASSovereignAuditEntry) {
                entries.append(e)
            }
            func snapshot() -> [BASSovereignAuditEntry] {
                entries
            }
        }
        let collector = AuditCollector()

        let coord = try await BASUpdateTicketLifecycleCoordinator
            .sqliteBacked(
                storageRoot: tempRoot,
                auditSink: { entry in
                    await collector.record(entry)
                })
        _ = try await coord.submit(makeTicket(id: "audit-1"))
        try await coord.startTrial(
            ticketID: "audit-1", trialRecordRef: "tr-a")
        try await coord.markTrialOutcome(
            ticketID: "audit-1",
            outcome: .passed(reasonCodes: []))
        try await coord.approveForDistillation(
            ticketID: "audit-1",
            sovereignVerdictRef: "vr-a")
        try await coord.markDistilled(
            ticketID: "audit-1",
            reasonCodes: ["distilled.via.test"])

        let snapshot = await collector.snapshot()
        XCTAssertGreaterThanOrEqual(snapshot.count, 1)
    }

    // MARK: - 6. Unified-locator places file at canonical path

    func testFactoryFromStorageRootPlacesLifecycleFile()
        async throws
    {
        _ = try await BASUpdateTicketLifecycleCoordinator
            .sqliteBacked(storageRoot: tempRoot)
        let expected = tempRoot
            .appendingPathComponent(
                BASUnifiedStorageLocator.lifecycleFilename)
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: expected.path),
            "factory must use unified-locator layout — expected " +
            "lifecycle.sqlite at \(expected.path)")
    }

    // MARK: - 7. ensureRootDirectory side effect

    /// The factory's storageRoot variant must auto-create the root
    /// directory. Tests pass an absent path and expect it to come
    /// into existence.
    func testFactoryFromStorageRootCreatesRootDirectory()
        async throws
    {
        let nestedRoot = tempRoot
            .appendingPathComponent("a/b/c", isDirectory: true)
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: nestedRoot.path))
        _ = try await BASUpdateTicketLifecycleCoordinator
            .sqliteBacked(storageRoot: nestedRoot)
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(
            atPath: nestedRoot.path, isDirectory: &isDir)
        XCTAssertTrue(exists)
        XCTAssertTrue(isDir.boolValue)
    }
}
