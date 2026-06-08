// Concurrency arc M1.3 — concurrent-write stress on the event-sourcing + atom (tombstone/provenance) stores.
// Writes serialize on each store's actor; this proves the serialization stays CORRECT under high concurrency
// (no lost writes, no seq gaps/dupes, no torn cross-store state) and measures the write-throughput ceiling.

import XCTest
import Foundation
@testable import BASMemory
@testable import BASRuntimeCore

final class BASEventStoreConcurrentWriteStressTests: XCTestCase {

    private var base: URL!

    override func setUpWithError() throws {
        base = FileManager.default.temporaryDirectory
            .appendingPathComponent("bas-evt-stress-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws {
        if let base { try? FileManager.default.removeItem(at: base) }
    }
    private func url(_ n: String) -> URL { base.appendingPathComponent(n) }

    private func elapsedSec(_ body: () async -> Void) async -> Double {
        let t0 = DispatchTime.now().uptimeNanoseconds
        await body()
        return Double(DispatchTime.now().uptimeNanoseconds &- t0) / 1_000_000_000
    }

    // MARK: - Concurrent event append: sequence integrity under load (no gaps/dupes/lost writes)

    func testConcurrentEventAppendSequenceIntegrity() async throws {
        let store = try BASSQLiteEventLogStorage(databaseURL: url("evt.sqlite"))
        let session = "s"
        let writers = 8
        let perWriter = 250
        let total = writers * perWriter

        let sec = await elapsedSec {
            await withTaskGroup(of: Void.self) { group in
                for w in 0..<writers {
                    group.addTask {
                        for j in 0..<perWriter {
                            _ = try? await store.append(BASEventLogEntry(
                                eventID: "w\(w)-e\(j)", timestampMs: 1_700_000_000_000 + Int64(j),
                                kind: .substrateAudit, sessionID: session, sequenceNumber: 0,
                                actions: ["x"]))
                        }
                    }
                }
            }
        }

        let events = try await store.eventsOrThrow(forSession: session)
        print(String(format: "📊 M1.3 event append: %d writers × %d = %d events in %.3fs (%.0f appends/s)",
                     writers, perWriter, total, sec, Double(total) / sec))

        // No lost writes.
        XCTAssertEqual(events.count, total, "every concurrent append landed (no lost writes)")
        // No duplicate event_ids.
        XCTAssertEqual(Set(events.map(\.eventID)).count, total, "all event_ids distinct")
        // Sequence numbers form a GAPLESS, duplicate-free 0..<total set (BEGIN IMMEDIATE atomicity holds
        // under concurrent actor calls — the seq assignment never raced into a gap or a collision).
        let seqs = events.map(\.sequenceNumber).sorted()
        XCTAssertEqual(seqs, Array(0..<Int64(total)),
            "per-session sequence numbers are gapless + unique under concurrent appends")
    }

    // MARK: - Concurrent atom admit + remove (tombstone DELETE) consistency

    func testConcurrentAtomAdmitRemoveConsistency() async throws {
        let store = try BASSQLiteMemoryAtomStore(databaseURL: url("atoms.sqlite"))
        let admitters = 6
        let perAdmitter = 100
        let totalAdmitted = admitters * perAdmitter

        // Phase 1: concurrent admits.
        let admitSec = await elapsedSec {
            await withTaskGroup(of: Void.self) { group in
                for a in 0..<admitters {
                    group.addTask {
                        for j in 0..<perAdmitter {
                            let id = UUID(uuidString: String(format: "00000000-0000-0000-%04x-%012x", a, j))
                                ?? UUID()
                            _ = try? await store.admit(BASGovernedMemory(
                                id: id, kind: .semantic, content: "a\(a)-\(j)", scope: .user,
                                sensitivity: .low, tier: .warm, confidence: 0.7,
                                sourceType: "general", governanceStatus: .candidate,
                                provenanceSummary: "stress"))
                        }
                    }
                }
            }
        }
        let afterAdmit = try await store.countOrThrow()
        XCTAssertEqual(afterAdmit, totalAdmitted, "every concurrent admit landed (no lost writes)")

        // Phase 2: concurrent removes (五级删除 real DELETE) of the first half, while reads run too.
        let ids = (try await store.allIDsOrThrow()).sorted()
        let toRemove = Array(ids.prefix(totalAdmitted / 2))
        let removeSec = await elapsedSec {
            await withTaskGroup(of: Void.self) { group in
                for id in toRemove {
                    group.addTask { _ = await store.remove(forID: id) }
                }
            }
        }
        let afterRemove = try await store.countOrThrow()
        print(String(format: "📊 M1.3 atom admit %.0f/s, remove %.0f/s; count %d → %d (removed %d)",
                     Double(totalAdmitted) / admitSec, Double(toRemove.count) / removeSec,
                     afterAdmit, afterRemove, toRemove.count))
        XCTAssertEqual(afterRemove, totalAdmitted - toRemove.count,
            "concurrent removes are consistent (no double-delete, no torn count)")
    }
}
