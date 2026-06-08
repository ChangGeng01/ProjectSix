// 先稳 P1 — proves the DEBUG-only concurrency tripwire on
// `BASRoutedVectorIndexStorage.cosineTopKAtomIDsSync` actually FIRES when a concurrent upsert/remove races
// the nonisolated sync read (the contract that ADR-037 acknowledged in prose but never caught at runtime).
//
// The tripwire exists only in DEBUG (it compiles out in release — zero hot-path overhead), and the engine
// is the Rust core (Apple platforms only), so the whole file is double-gated. This is an INTENTIONAL race
// at high iteration count to trip the detector; in production the turn-phase-separation contract prevents
// the race — this test proves the SAFETY NET works.

import XCTest
import Foundation
@testable import BASMemory
import BASRuntimeCore

#if (os(iOS) || os(macOS)) && DEBUG
import BASRustMemoryTrackerBinary

final class BASRoutedVectorIndexStorageConcurrencyTripwireTests: XCTestCase {

    private func entry(_ atomID: String, _ x: Float) -> BASVectorIndexEntry {
        BASVectorIndexEntry(
            atomID: atomID,
            normalizedEmbedding: BASEmbedding(
                vector: [x, 1 - x, 0, 0], dimension: 4, providerVersion: "p").normalized,
            domain: "g")
    }

    func testTripwireFiresOnConcurrentWriteDuringSyncRead() async throws {
        // Save + restore the global handler so we don't abort the test (default is assertionFailure).
        let original = BASRoutedVectorIndexStorage._concurrencyViolationHandler
        defer { BASRoutedVectorIndexStorage._concurrencyViolationHandler = original }

        // Box with INTERNALLY-LOCKED sync accessors — NSLock.lock() is unavailable DIRECTLY in an async body,
        // but a sync getter that locks internally is fine to call from one.
        final class Box: @unchecked Sendable {
            private let lock = NSLock()
            private var _count = 0
            private var _stop = false
            func bump() { lock.lock(); _count += 1; lock.unlock() }
            var count: Int { lock.lock(); defer { lock.unlock() }; return _count }
            var stopped: Bool { lock.lock(); defer { lock.unlock() }; return _stop }
            func stop() { lock.lock(); _stop = true; lock.unlock() }
        }
        let box = Box()
        BASRoutedVectorIndexStorage._concurrencyViolationHandler = { _ in box.bump() }

        let engine = try BASRoutedVectorIndexStorage(inMemory: ())
        for i in 0..<8 {
            _ = try await engine.upsert(entry("seed-\(i)", Float(i) / 8.0))
        }

        // Writer runs CONTINUOUSLY (always a mutation in-flight to race) until told to stop — captures only
        // the Sendable engine + box (inline entry, no self).
        let writer = Task.detached {
            var i = 0
            while !box.stopped {
                let e = BASVectorIndexEntry(
                    atomID: "seed-\(i % 8)",
                    normalizedEmbedding: BASEmbedding(
                        vector: [Float(i % 7) / 7.0, 1, 0, 0], dimension: 4,
                        providerVersion: "p").normalized,
                    domain: "g")
                _ = try? await engine.upsert(e)
                i += 1
            }
        }
        // Reader hammers the nonisolated sync read until a race is DETECTED or a generous deadline — making
        // the catch scheduler-INDEPENDENT (was flaky: a one-shot reader loop could finish before the
        // detached writer ever got a time-slice → 0 detected races → false fail). Yield between batches so
        // the writer makes progress even on few-core / loaded machines. Deadline-with-0 ⇒ the detector is
        // genuinely broken (a real signal, not a scheduling fluke).
        let deadline = Date().addingTimeInterval(10)
        while box.count == 0 && Date() < deadline {
            for _ in 0..<200 {
                _ = try? engine.cosineTopKAtomIDsSync(forDomain: "g", query: [1, 0, 0, 0], k: 3)
                if box.count > 0 { break }
            }
            await Task.yield()
        }
        box.stop()
        await writer.value

        XCTAssertGreaterThan(box.count, 0,
            "the DEBUG concurrency tripwire must fire when an upsert races the nonisolated sync read " +
            "(deadline-bounded catch; 0 here ⇒ the detector is broken, not a scheduling fluke)")
    }
}
#endif
