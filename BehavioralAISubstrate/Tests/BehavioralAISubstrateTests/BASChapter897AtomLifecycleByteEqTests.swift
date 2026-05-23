// MARK: - BASChapter897AtomLifecycleByteEqTests
// chapter 八百九十七 / M3175 — MED-risk migration #2 byte-eq pin

import XCTest
import Foundation
@testable import BASMemory
#if os(iOS) || os(macOS)
import BASRustMemoryTrackerBinary
#endif

#if os(iOS) || os(macOS)
final class BASChapter897AtomLifecycleByteEqTests: XCTestCase {

    private func makeTempDBURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("ch897-\(UUID().uuidString).db")
    }

    private func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
        try? FileManager.default.removeItem(
            at: URL(fileURLWithPath: url.path + "-wal"))
        try? FileManager.default.removeItem(
            at: URL(fileURLWithPath: url.path + "-shm"))
    }

    private func event(
        id: String,
        atom: String,
        session: String = "sess-default",
        from: UInt8 = 0,
        to: UInt8 = 1,
        action: UInt8 = 0,
        outcome: Int32 = 0,
        at: Int64 = 1_700_000_000_000
    ) -> BASAtomLifecycleEvent {
        BASAtomLifecycleEvent(
            eventID: id, atomID: atom, sessionID: session,
            fromPhaseByte: from, toPhaseByte: to,
            actionByte: action, outcome: outcome,
            recordedAtMs: at, actorRef: nil)
    }

    func testRoutedActorBasicRoundTrip() async throws {
        let url = makeTempDBURL()
        defer { cleanup(url) }
        let routed = try BASRoutedAtomLifecycleStore(
            databaseURL: url)
        let initial = await routed.count()
        XCTAssertEqual(initial, 0)
        _ = try await routed.appendEvent(
            event(id: "e1", atom: "a1"))
        _ = try await routed.appendEvent(
            event(id: "e2", atom: "a1",
                from: 1, to: 2, action: 1))
        _ = try await routed.appendEvent(
            event(id: "e3", atom: "a2", session: "sess-B"))
        let total = await routed.count()
        XCTAssertEqual(total, 3)
        let cA1 = await routed.countForAtom("a1")
        let cA2 = await routed.countForAtom("a2")
        XCTAssertEqual(cA1, 2)
        XCTAssertEqual(cA2, 1)
        let cSDef = await routed.countForSession("sess-default")
        let cSB = await routed.countForSession("sess-B")
        XCTAssertEqual(cSDef, 2)
        XCTAssertEqual(cSB, 1)
    }

    func testRoutedActorRejectsDuplicateEventID() async throws {
        let url = makeTempDBURL()
        defer { cleanup(url) }
        let routed = try BASRoutedAtomLifecycleStore(
            databaseURL: url)
        _ = try await routed.appendEvent(
            event(id: "dup", atom: "x"))
        do {
            _ = try await routed.appendEvent(
                event(id: "dup", atom: "y"))
            XCTFail("Duplicate event_id must throw")
        } catch BASRoutedAtomLifecycleStore
            .StoreError.appendFailed(let code) {
            XCTAssertEqual(code, -2)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testInvalidPhaseByteRejected() async throws {
        let url = makeTempDBURL()
        defer { cleanup(url) }
        let routed = try BASRoutedAtomLifecycleStore(
            databaseURL: url)
        do {
            _ = try await routed.appendEvent(
                event(id: "bad", atom: "x",
                    from: 99, to: 0))  // invalid from_phase
            XCTFail("Invalid phase byte must throw")
        } catch BASRoutedAtomLifecycleStore
            .StoreError.appendFailed(let code) {
            XCTAssertEqual(code, -2)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    /// CRITICAL byte-eq pin: routed actor produces same count
    /// state as legacy SQLite actor for same input。
    func testByteEqAppendVsSwiftSQLite() async throws {
        let routedURL = makeTempDBURL()
        let swiftURL = makeTempDBURL()
        defer { cleanup(routedURL); cleanup(swiftURL) }
        let routed = try BASRoutedAtomLifecycleStore(
            databaseURL: routedURL)
        let swiftActor = try BASSQLiteAtomLifecycleStore(
            databaseURL: swiftURL)
        let events: [BASAtomLifecycleEvent] = [
            event(id: "be-1", atom: "a-X", session: "s-1",
                from: 0, to: 1, action: 0, outcome: 0, at: 100),
            event(id: "be-2", atom: "a-X", session: "s-1",
                from: 1, to: 2, action: 1, outcome: 0, at: 200),
            event(id: "be-3", atom: "a-Y", session: "s-2",
                from: 0, to: 1, action: 0, outcome: 0, at: 300),
            event(id: "be-4", atom: "a-Y", session: "s-2",
                from: 1, to: 3, action: 2, outcome: 0, at: 400),
            event(id: "be-5", atom: "a-Z", session: "s-1",
                from: 0, to: 4, action: 3, outcome: 2, at: 500),
        ]
        for e in events {
            _ = try await routed.appendEvent(e)
            _ = try await swiftActor.appendEvent(e)
        }
        let rCount = await routed.count()
        let sCount = await swiftActor.count()
        XCTAssertEqual(rCount, sCount,
            "Total count byte-equal vs SQLite actor")
        XCTAssertEqual(rCount, 5)
        // Per-atom byte-eq
        for atom in ["a-X", "a-Y", "a-Z", "a-missing"] {
            let r = await routed.countForAtom(atom)
            let sEvents = await swiftActor.events(
                forAtom: atom)
            XCTAssertEqual(r, sEvents.count,
                "Per-atom count byte-eq for atom=\(atom)")
        }
        // Per-session byte-eq
        for session in ["s-1", "s-2", "s-missing"] {
            let r = await routed.countForSession(session)
            let sEvents = await swiftActor.events(
                forSession: session)
            XCTAssertEqual(r, sEvents.count,
                "Per-session count byte-eq for session=" +
                session)
        }
    }
}
#endif
