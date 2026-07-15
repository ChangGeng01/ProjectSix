import XCTest
@testable import BASMemory

/// deep-audit MED: BASSQLiteAtomLifecycleStore must return events in INSERTION order — the protocol
/// contract that `reconstructCurrentPhaseByte` (takes the LAST advanced event's phase) relies on, and
/// which the in-memory reference conformer honors. Ordering by `recorded_at_ms` FIRST diverges whenever
/// caller-supplied / clock-skewed timestamps disagree with insertion order. `rowid ASC` = insertion order.
final class BASSQLiteAtomLifecycleOrderTests: XCTestCase {

    private func tmpURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("bas-atomlc-\(UUID().uuidString).sqlite")
    }
    private func cleanup(_ u: URL) {
        for s in ["", "-wal", "-shm"] { try? FileManager.default.removeItem(atPath: u.path + s) }
    }
    private func ev(_ id: String, to: UInt8, at ms: Int64) -> BASAtomLifecycleEvent {
        BASAtomLifecycleEvent(eventID: id, atomID: "A", sessionID: "s",
            fromPhaseByte: 0, toPhaseByte: to, actionByte: 0, outcome: 0, recordedAtMs: ms)
    }

    func testEventsReturnInsertionOrderNotTimestampOrder() async throws {
        let url = tmpURL(); defer { cleanup(url) }
        let sqlite = try BASSQLiteAtomLifecycleStore(databaseURL: url)
        let mem = BASInMemoryAtomLifecycleStore()

        // Insert e1 (LATER timestamp 200, advances to phase 3) BEFORE e2 (EARLIER timestamp 100, phase 4).
        _ = try await sqlite.appendEvent(ev("e1", to: 3, at: 200))
        _ = try await sqlite.appendEvent(ev("e2", to: 4, at: 100))
        _ = try await mem.appendEvent(ev("e1", to: 3, at: 200))
        _ = try await mem.appendEvent(ev("e2", to: 4, at: 100))

        let sqOrder = await sqlite.events(forAtom: "A").map(\.toPhaseByte)
        let memOrder = await mem.events(forAtom: "A").map(\.toPhaseByte)
        XCTAssertEqual(sqOrder, [3, 4], "SQLite returns INSERTION order (e1 then e2), not timestamp order")
        XCTAssertEqual(sqOrder, memOrder, "SQLite matches the in-memory reference conformer")

        // reconstruct = LAST advanced in insertion order = e2 (phase 4). Unfixed timestamp-order picks e1 (3).
        let sqPhase = await sqlite.reconstructCurrentPhaseByte(forAtom: "A")
        let memPhase = await mem.reconstructCurrentPhaseByte(forAtom: "A")
        XCTAssertEqual(sqPhase, 4, "current phase is the insertion-latest advanced event's toPhase")
        XCTAssertEqual(sqPhase, memPhase, "reconstruct agrees with the in-memory conformer")
    }
}
