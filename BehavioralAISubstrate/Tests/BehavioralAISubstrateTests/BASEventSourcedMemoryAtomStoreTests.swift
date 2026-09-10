// MARK: - BASEventSourcedMemoryAtomStoreTests — chapter 四百二 / M943
//
// Test coverage for Phase 1 第三刀:event-sourced atom store。
//
// Targets per the M943 plan spec (32 tests):
//   - basic admit/update/remove via in-memory event log (8)
//   - actor-restart projection fidelity (5)
//   - cachePolicy lazy vs warmAtInit parity (5)
//   - idempotent retry on duplicate eventID (3)
//   - parity vs BASInMemoryMemoryAtomStore (5)
//   - SQLite event log round-trip (3)
//   - lastReplayedSequenceNumber monotonicity (3)

// chapter 九百四十七 / M3440 — Foundation.Process unavailable on iOS
#if os(macOS)
import Foundation
import XCTest
@testable import BASMemory
@testable import BASRuntimeCore

final class BASEventSourcedMemoryAtomStoreTests: XCTestCase {

    // MARK: - Fixtures

    private func makeAtom(
        idString: String = "00000000-0000-4000-8000-000000000001",
        content: String = "real-content",
        kind: BASMemoryKind = .semantic,
        scope: BASMemoryScope = .user,
        sensitivity: BASMemorySensitivity = .low,
        tier: BASMemoryTier = .warm,
        confidence: Double = 0.7,
        sourceType: String = "test-src",
        governanceStatus: BASMemoryGovernanceStatus = .governed,
        provenanceSummary: String = "test-prov"
    ) -> BASGovernedMemory {
        BASGovernedMemory(
            id: UUID(uuidString: idString)!,
            kind: kind,
            content: content,
            scope: scope,
            sensitivity: sensitivity,
            tier: tier,
            confidence: confidence,
            sourceType: sourceType,
            lastConfirmedAt: nil,
            decayScore: 0.0,
            governanceStatus: governanceStatus,
            provenanceSummary: provenanceSummary)
    }

    private func makeStore(
        eventLog: any BASEventLogStorage =
            BASInMemoryEventLogStorage(),
        sessionID: String = "sess",
        cachePolicy:
            BASEventSourcedMemoryAtomStoreCachePolicy = .lazy,
        idCounter: ManagedIDCounter = ManagedIDCounter()
    ) -> BASEventSourcedMemoryAtomStore {
        BASEventSourcedMemoryAtomStore(
            eventLog: eventLog,
            sessionID: sessionID,
            eventIDFactory: { idCounter.next() },
            clockMs: { 1_700_000_000_000 },
            source: "test",
            cachePolicy: cachePolicy)
    }

    /// Deterministic eventID factory for replay-determinism tests
    final class ManagedIDCounter: @unchecked Sendable {
        private var n: Int = 0
        private let lock = NSLock()
        func next() -> String {
            lock.lock(); defer { lock.unlock() }
            n += 1
            return "evt-\(n)"
        }
    }

    // MARK: - Basic admit/update/remove (8)

    func testAdmitNewAtomInsertsViaEventLog() async throws {
        let log = BASInMemoryEventLogStorage()
        let store = makeStore(eventLog: log)
        let atom = makeAtom()
        let admitted = try await store.admit(atom)
        XCTAssertTrue(admitted)
        let count = await store.count
        XCTAssertEqual(count, 1)
        let events = await log.events(forSession: "sess")
        XCTAssertEqual(events.count, 1)
    }

    func testAdmitPreservesContentInProcess() async throws {
        let store = makeStore()
        let atom = makeAtom(content: "alpha")
        try await store.admit(atom)
        let fetched = await store.atom(forID: atom.id.uuidString)
        XCTAssertEqual(fetched?.content, "alpha",
            "M943:in-process content fidelity via content cache")
    }

    func testUpdateTierAppendsEventAndProjects() async throws {
        let store = makeStore()
        let atom = makeAtom()
        try await store.admit(atom)
        let ok = await store.updateTier(
            forID: atom.id.uuidString, to: .hot)
        XCTAssertTrue(ok)
        let fetched = await store.atom(forID: atom.id.uuidString)
        XCTAssertEqual(fetched?.tier, .hot)
    }

    func testUpdateTierOnUnknownAtomReturnsFalse() async {
        let store = makeStore()
        let ok = await store.updateTier(
            forID: "missing", to: .hot)
        XCTAssertFalse(ok)
    }

    func testUpdateGovernanceStatus() async throws {
        let store = makeStore()
        let atom = makeAtom()
        try await store.admit(atom)
        let ok = await store.updateGovernanceStatus(
            forID: atom.id.uuidString, to: .quarantined)
        XCTAssertTrue(ok)
        let fetched = await store.atom(forID: atom.id.uuidString)
        XCTAssertEqual(fetched?.governanceStatus, .quarantined)
    }

    func testUpdateGovernanceOnUnknownReturnsFalse() async {
        let store = makeStore()
        let ok = await store.updateGovernanceStatus(
            forID: "missing", to: .archived)
        XCTAssertFalse(ok)
    }

    func testRemoveAtomReturnsRemovedValue() async throws {
        let store = makeStore()
        let atom = makeAtom()
        try await store.admit(atom)
        let removed = await store.remove(
            forID: atom.id.uuidString)
        XCTAssertNotNil(removed)
        XCTAssertEqual(removed?.content, atom.content)
        let count = await store.count
        XCTAssertEqual(count, 0)
    }

    func testRemoveOnUnknownReturnsNil() async {
        let store = makeStore()
        let removed = await store.remove(forID: "no-such")
        XCTAssertNil(removed)
    }

    // audit memory-b F11: a constant eventID makes the remove event DEDUPE against the admit event
    // (wasNew=false), so it never appends. remove() must report nothing removed + keep the content
    // cache — not claim a removal that didn't land.
    func testRemoveDedupedByEventIDIsANoOp() async throws {
        let store = BASEventSourcedMemoryAtomStore(
            eventLog: BASInMemoryEventLogStorage(),
            sessionID: "s",
            eventIDFactory: { "dup" },
            clockMs: { 1_700_000_000_000 },
            source: "test")
        let atom = makeAtom()
        _ = try await store.admit(atom)
        let removed = await store.remove(forID: atom.id.uuidString)
        XCTAssertNil(removed, "a deduped (never-appended) remove must report nothing removed")
        let still = await store.atom(forID: atom.id.uuidString)
        XCTAssertEqual(still?.content, atom.content,
            "the atom + its cached content survive a no-op remove (the remove event never appended)")
    }

    // MARK: - Actor-restart projection fidelity (5)

    func testProjectionRebuildsAfterStoreRestart() async throws {
        let log = BASInMemoryEventLogStorage()
        let counter = ManagedIDCounter()
        let s1 = makeStore(
            eventLog: log, idCounter: counter)
        try await s1.admit(makeAtom())
        // New store on same event log
        let s2 = makeStore(eventLog: log)
        let count = await s2.count
        XCTAssertEqual(count, 1,
            "M943:new actor over same log → same projection")
    }

    func testRestartReplaysTierChanges() async throws {
        let log = BASInMemoryEventLogStorage()
        let atom = makeAtom()
        let counter = ManagedIDCounter()
        let s1 = makeStore(
            eventLog: log, idCounter: counter)
        try await s1.admit(atom)
        _ = await s1.updateTier(
            forID: atom.id.uuidString,
            to: BASMemoryTier.hot)
        let s2 = makeStore(eventLog: log)
        let fetched = await s2.atom(
            forID: atom.id.uuidString)
        XCTAssertEqual(fetched?.tier, .hot)
    }

    func testRestartReplaysGovernanceChanges() async throws {
        let log = BASInMemoryEventLogStorage()
        let atom = makeAtom()
        let s1 = makeStore(eventLog: log)
        try await s1.admit(atom)
        _ = await s1.updateGovernanceStatus(
            forID: atom.id.uuidString,
            to: BASMemoryGovernanceStatus.archived)
        let s2 = makeStore(eventLog: log)
        let fetched = await s2.atom(
            forID: atom.id.uuidString)
        XCTAssertEqual(fetched?.governanceStatus, .archived)
    }

    func testRestartReplaysRemoval() async throws {
        let log = BASInMemoryEventLogStorage()
        let atom = makeAtom()
        let s1 = makeStore(eventLog: log)
        try await s1.admit(atom)
        _ = await s1.remove(forID: atom.id.uuidString)
        let s2 = makeStore(eventLog: log)
        let count = await s2.count
        XCTAssertEqual(count, 0)
    }

    func testRestartHasEmptyContentCacheButAtomsProjectionLives()
        async throws
    {
        // Privacy doctrine:cross-process replay produces atoms
        // with empty content (content was never in event log)。
        let log = BASInMemoryEventLogStorage()
        let atom = makeAtom(content: "secret")
        let s1 = makeStore(eventLog: log)
        try await s1.admit(atom)
        let s2 = makeStore(eventLog: log)
        let fetched = await s2.atom(
            forID: atom.id.uuidString)
        XCTAssertEqual(fetched?.content, "",
            "M943:cross-actor replay → empty content (privacy)")
        XCTAssertEqual(fetched?.tier, atom.tier,
            "But all metadata fields project correctly")
    }

    // MARK: - cachePolicy parity (5)

    func testLazyAndWarmAtInitProduceSameAtoms() async throws {
        let log = BASInMemoryEventLogStorage()
        let lazy = makeStore(
            eventLog: log,
            sessionID: "share",
            cachePolicy: .lazy)
        let warm = makeStore(
            eventLog: log,
            sessionID: "share",
            cachePolicy: .warmAtInit)
        // Note: separate stores share the eventLog but each does
        // its own appends; we go through the lazy one to keep the
        // eventLog as the only source of truth.
        let atom = makeAtom()
        try await lazy.admit(atom)
        // Warm store hasn't seen the admit through its own writes,
        // so its cache won't auto-update — but currentProjection
        // re-projects from the event log。Let's force it via a read
        let warmCount = await warm.count
        // warm.count's path triggers warmCacheIfNeeded which
        // projects on first read → 1
        XCTAssertEqual(warmCount, 1)
        let lazyCount = await lazy.count
        XCTAssertEqual(lazyCount, 1)
    }

    func testWarmAtInitReturnsBytesEqualForRepeatedReads()
        async throws
    {
        let store = makeStore(cachePolicy: .warmAtInit)
        try await store.admit(makeAtom())
        let r1 = await store.projectAll()
        let r2 = await store.projectAll()
        XCTAssertEqual(r1, r2)
    }

    func testLazyReturnsBytesEqualForRepeatedReads()
        async throws
    {
        let store = makeStore(cachePolicy: .lazy)
        try await store.admit(makeAtom())
        let r1 = await store.projectAll()
        let r2 = await store.projectAll()
        XCTAssertEqual(r1, r2)
    }

    func testCachedWithTTLBehavesLikeWarmForNow() async throws {
        let store = makeStore(
            cachePolicy: .cachedWithTTL(seconds: 60))
        try await store.admit(makeAtom())
        let count = await store.count
        XCTAssertEqual(count, 1,
            "M943:cachedWithTTL slot is forward-compat;behaves like warmAtInit")
    }

    func testWriteThroughCacheUpdatesOnTierChange() async throws {
        let store = makeStore(cachePolicy: .warmAtInit)
        let atom = makeAtom(tier: .warm)
        try await store.admit(atom)
        _ = await store.updateTier(
            forID: atom.id.uuidString, to: .cold)
        let fetched = await store.atom(
            forID: atom.id.uuidString)
        XCTAssertEqual(fetched?.tier, .cold,
            "M943:warm cache mutates synchronously on append")
    }

    // MARK: - Idempotent eventID retry (3)

    func testDuplicateEventIDDoesNotDoubleApply() async throws {
        let log = BASInMemoryEventLogStorage()
        // Static factory returns the same eventID every call
        let store = BASEventSourcedMemoryAtomStore(
            eventLog: log,
            sessionID: "dup",
            eventIDFactory: { "dup-evt-1" },
            clockMs: { 1 },
            source: "test")
        let atom1 = makeAtom(idString:
            "00000000-0000-4000-8000-000000000010")
        let admitted1 = try await store.admit(atom1)
        XCTAssertTrue(admitted1)
        // 2nd admit with same factory eventID — log returns
        // wasNew=false → admit returns false
        let atom2 = makeAtom(idString:
            "00000000-0000-4000-8000-000000000020")
        let admitted2 = try await store.admit(atom2)
        XCTAssertFalse(admitted2,
            "M943:duplicate eventID must NOT append second event")
    }

    func testIdempotentRetryDoesNotMutateState() async throws {
        let log = BASInMemoryEventLogStorage()
        let store = BASEventSourcedMemoryAtomStore(
            eventLog: log,
            sessionID: "i",
            eventIDFactory: { "fixed" },
            clockMs: { 0 })
        try await store.admit(makeAtom())
        let countBefore = await store.count
        try await store.admit(makeAtom(idString:
            "00000000-0000-4000-8000-000000000777"))
        let countAfter = await store.count
        XCTAssertEqual(countBefore, countAfter)
    }

    func testIdempotentEventLogCountRemainsOne() async throws {
        let log = BASInMemoryEventLogStorage()
        let store = BASEventSourcedMemoryAtomStore(
            eventLog: log,
            sessionID: "k",
            eventIDFactory: { "same" },
            clockMs: { 0 })
        try await store.admit(makeAtom())
        try await store.admit(makeAtom())
        let events = await log.events(forSession: "k")
        XCTAssertEqual(events.count, 1)
    }

    // MARK: - Parity vs BASInMemoryMemoryAtomStore (5)

    func testParityCountAfterAdmits() async throws {
        let log = BASInMemoryEventLogStorage()
        let event = makeStore(eventLog: log)
        let inMem = BASInMemoryMemoryAtomStore()
        let atoms = (0..<5).map { i in
            makeAtom(idString:
                "00000000-0000-4000-8000-\(String(format: "%012d", i))")
        }
        for a in atoms {
            try await event.admit(a)
            // BASInMemoryMemoryAtomStore.admit() doesn't exist
            // on protocol — use direct insertion via init
        }
        let inMem2 = BASInMemoryMemoryAtomStore(initial: atoms)
        let eventCount = await event.count
        let inMemCount = await inMem2.count
        XCTAssertEqual(eventCount, inMemCount)
        _ = inMem  // suppress unused warning
    }

    func testParityTierUpdate() async throws {
        let atom = makeAtom()
        let event = makeStore()
        try await event.admit(atom)
        let inMem = BASInMemoryMemoryAtomStore(initial: [atom])
        _ = await event.updateTier(
            forID: atom.id.uuidString, to: .hot)
        _ = await inMem.updateTier(
            forID: atom.id.uuidString, to: .hot)
        let eventTier =
            await event.atom(forID: atom.id.uuidString)?.tier
        let inMemTier =
            await inMem.atom(forID: atom.id.uuidString)?.tier
        XCTAssertEqual(eventTier, inMemTier)
    }

    func testParityGovernanceUpdate() async throws {
        let atom = makeAtom()
        let event = makeStore()
        try await event.admit(atom)
        let inMem = BASInMemoryMemoryAtomStore(initial: [atom])
        _ = await event.updateGovernanceStatus(
            forID: atom.id.uuidString, to: .quarantined)
        _ = await inMem.updateGovernanceStatus(
            forID: atom.id.uuidString, to: .quarantined)
        let eventStatus =
            await event.atom(forID: atom.id.uuidString)?
            .governanceStatus
        let inMemStatus =
            await inMem.atom(forID: atom.id.uuidString)?
            .governanceStatus
        XCTAssertEqual(eventStatus, inMemStatus)
    }

    func testParityRemove() async throws {
        let atom = makeAtom()
        let event = makeStore()
        try await event.admit(atom)
        let inMem = BASInMemoryMemoryAtomStore(initial: [atom])
        let eventRm = await event.remove(
            forID: atom.id.uuidString)
        let inMemRm = await inMem.remove(
            forID: atom.id.uuidString)
        XCTAssertEqual(eventRm?.id, inMemRm?.id)
        XCTAssertEqual(eventRm?.tier, inMemRm?.tier)
    }

    func testParityUnknownIDReturnsNil() async {
        let event = makeStore()
        let inMem = BASInMemoryMemoryAtomStore()
        let eventA = await event.atom(forID: "no-such")
        let inMemA = await inMem.atom(forID: "no-such")
        XCTAssertNil(eventA)
        XCTAssertNil(inMemA)
    }

    // MARK: - SQLite event log round-trip (3)

    func testSQLiteBackedRoundTrip() async throws {
        let tempURL = FileManager.default
            .temporaryDirectory
            .appendingPathComponent(
                "qinao-m943-\(UUID().uuidString).sqlite")
        defer {
            try? FileManager.default.removeItem(at: tempURL)
            try? FileManager.default.removeItem(
                at: URL(fileURLWithPath: tempURL.path + "-wal"))
            try? FileManager.default.removeItem(
                at: URL(fileURLWithPath: tempURL.path + "-shm"))
        }
        let sqliteLog = try BASSQLiteEventLogStorage(
            databaseURL: tempURL)
        let atom = makeAtom()
        let s1 = makeStore(eventLog: sqliteLog)
        try await s1.admit(atom)
        _ = await s1.updateTier(
            forID: atom.id.uuidString,
            to: BASMemoryTier.hot)
        // New actor on same SQLite log
        let s2 = makeStore(eventLog: sqliteLog)
        let fetched = await s2.atom(
            forID: atom.id.uuidString)
        XCTAssertEqual(fetched?.tier, .hot,
            "M943:SQLite round-trip preserves projection")
    }

    func testSQLiteCountMatchesEventCount() async throws {
        let tempURL = FileManager.default
            .temporaryDirectory
            .appendingPathComponent(
                "qinao-m943-\(UUID().uuidString).sqlite")
        defer {
            try? FileManager.default.removeItem(at: tempURL)
            try? FileManager.default.removeItem(
                at: URL(fileURLWithPath: tempURL.path + "-wal"))
            try? FileManager.default.removeItem(
                at: URL(fileURLWithPath: tempURL.path + "-shm"))
        }
        let sqliteLog = try BASSQLiteEventLogStorage(
            databaseURL: tempURL)
        let s = makeStore(eventLog: sqliteLog)
        for i in 0..<3 {
            try await s.admit(makeAtom(idString:
                "00000000-0000-4000-8000-\(String(format: "%012d", i))"))
        }
        let count = await s.count
        XCTAssertEqual(count, 3)
    }

    func testSQLiteRemovedAtomNotInProjection() async throws {
        let tempURL = FileManager.default
            .temporaryDirectory
            .appendingPathComponent(
                "qinao-m943-\(UUID().uuidString).sqlite")
        defer {
            try? FileManager.default.removeItem(at: tempURL)
            try? FileManager.default.removeItem(
                at: URL(fileURLWithPath: tempURL.path + "-wal"))
            try? FileManager.default.removeItem(
                at: URL(fileURLWithPath: tempURL.path + "-shm"))
        }
        let sqliteLog = try BASSQLiteEventLogStorage(
            databaseURL: tempURL)
        let atom = makeAtom()
        let s = makeStore(eventLog: sqliteLog)
        try await s.admit(atom)
        _ = await s.remove(forID: atom.id.uuidString)
        let s2 = makeStore(eventLog: sqliteLog)
        let count = await s2.count
        XCTAssertEqual(count, 0)
    }

    // MARK: - lastReplayedSequenceNumber monotonicity (3)

    func testLastSeqNilBeforeFirstWrite() async {
        let store = makeStore()
        let seq = await store.lastReplayedSequenceNumber
        XCTAssertNil(seq)
    }

    func testLastSeqMonotonicAfterEachWrite() async throws {
        let store = makeStore()
        try await store.admit(makeAtom())
        let s1 = await store.lastReplayedSequenceNumber
        let atom2 = makeAtom(idString:
            "00000000-0000-4000-8000-000000000099")
        try await store.admit(atom2)
        let s2 = await store.lastReplayedSequenceNumber
        XCTAssertNotNil(s1)
        XCTAssertNotNil(s2)
        XCTAssertGreaterThan(s2!, s1!,
            "M943:sequence number must monotonically increase")
    }

    func testLastSeqIncrementsOnUpdateAndRemove() async throws {
        let store = makeStore()
        let atom = makeAtom()
        try await store.admit(atom)
        let s1 = await store.lastReplayedSequenceNumber
        _ = await store.updateTier(
            forID: atom.id.uuidString, to: .hot)
        let s2 = await store.lastReplayedSequenceNumber
        _ = await store.remove(forID: atom.id.uuidString)
        let s3 = await store.lastReplayedSequenceNumber
        XCTAssertGreaterThan(s2!, s1!)
        XCTAssertGreaterThan(s3!, s2!)
    }
}

#endif