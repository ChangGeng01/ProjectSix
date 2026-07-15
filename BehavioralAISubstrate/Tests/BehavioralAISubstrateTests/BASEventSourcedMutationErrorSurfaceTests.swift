import XCTest
import Foundation
@testable import BASMemory
@testable import BASRuntimeCore

/// An event log that delegates to in-memory but can be toggled to throw on append.
private actor FailableEventLog: BASEventLogStorage {
    private let inner = BASInMemoryEventLogStorage()
    private var fail = false
    struct Injected: Error {}
    func setFail(_ f: Bool) { fail = f }
    func append(_ entry: BASEventLogEntry) async throws -> (wasNew: Bool, assignedSequenceNumber: Int64) {
        if fail { throw Injected() }
        return try await inner.append(entry)
    }
    func events(forSession sessionID: String) async -> [BASEventLogEntry] {
        await inner.events(forSession: sessionID)
    }
    func events(sinceTimestampMs since: Int64, limit: Int) async -> [BASEventLogEntry] {
        await inner.events(sinceTimestampMs: since, limit: limit)
    }
    var totalCount: Int { get async { await inner.totalCount } }
    func pruneEventsBefore(timestampMs cutoff: Int64) async throws -> Int {
        try await inner.pruneEventsBefore(timestampMs: cutoff)
    }
}

private final class ErrorBox: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: Error?
    var error: Error? { lock.lock(); defer { lock.unlock() }; return stored }
    func set(_ e: Error) { lock.lock(); stored = e; lock.unlock() }
}

/// audit memory-b F4 — a store WRITE error on an EXISTING atom must be SURFACED,
/// not conflated with "atom not found" (both used to return false/nil silently,
/// which downstream counted as a benign not-found = fail-open).
final class BASEventSourcedMutationErrorSurfaceTests: XCTestCase {

    private func seed() -> BASGovernedMemory {
        BASGovernedMemory(
            id: UUID(), kind: .episodic, content: "c", scope: .session,
            sensitivity: .low, tier: .warm, confidence: 0.5, sourceType: "t",
            governanceStatus: .governed, provenanceSummary: "p")
    }

    func testWriteErrorOnExistingAtomIsSurfaced() async throws {
        let log = FailableEventLog()
        let store = BASEventSourcedMemoryAtomStore(eventLog: log, sessionID: "s")
        let atom = seed()
        _ = try await store.admit(atom)   // append succeeds — the atom now exists

        let box = ErrorBox()
        await store.setOnSilentFailure { box.set($0) }
        await log.setFail(true)           // force the next store write to error

        let ok = await store.updateTier(forID: atom.id.uuidString, to: .cold)
        XCTAssertFalse(ok, "the mutation returns false")
        XCTAssertNotNil(box.error,
            "a WRITE error on an EXISTING atom must be surfaced (was silent fail-open as not-found)")
    }

    func testNotFoundDoesNotSurfaceAnError() async throws {
        let log = FailableEventLog()
        let store = BASEventSourcedMemoryAtomStore(eventLog: log, sessionID: "s")
        let box = ErrorBox()
        await store.setOnSilentFailure { box.set($0) }

        let ok = await store.updateTier(forID: "does-not-exist", to: .cold)
        XCTAssertFalse(ok)
        XCTAssertNil(box.error,
            "a genuine not-found must NOT surface an error — that's the distinction F4 restores")
    }
}
