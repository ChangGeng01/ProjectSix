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

        final class Box: @unchecked Sendable { let lock = NSLock(); var count = 0 }
        let box = Box()
        BASRoutedVectorIndexStorage._concurrencyViolationHandler = { _ in
            box.lock.lock(); box.count += 1; box.lock.unlock()
        }

        let engine = try BASRoutedVectorIndexStorage(inMemory: ())
        for i in 0..<8 {
            _ = try await engine.upsert(entry("seed-\(i)", Float(i) / 8.0))
        }

        // Writer: hammer upsert (actor-isolated → holds the writeInFlight flag across its FFI). Inline the
        // entry construction so the detached task captures ONLY the Sendable `engine` (not `self`).
        let writer = Task.detached {
            for i in 0..<3000 {
                let e = BASVectorIndexEntry(
                    atomID: "seed-\(i % 8)",
                    normalizedEmbedding: BASEmbedding(
                        vector: [Float(i % 7) / 7.0, 1, 0, 0], dimension: 4,
                        providerVersion: "p").normalized,
                    domain: "g")
                _ = try? await engine.upsert(e)
            }
        }
        // Reader: hammer the nonisolated sync read on THIS thread, concurrent with the writer.
        for _ in 0..<3000 {
            _ = try? engine.cosineTopKAtomIDsSync(forDomain: "g", query: [1, 0, 0, 0], k: 3)
        }
        await writer.value

        // Writer + reader loops have both finished — no concurrent mutation remains, so read directly
        // (NSLock.lock() is unavailable from an async context, and unnecessary here).
        let fired = box.count
        XCTAssertGreaterThan(fired, 0,
            "the DEBUG concurrency tripwire must fire when an upsert races the nonisolated sync read " +
            "(if this is 0, the detector is broken — the safety net the contract relies on is absent)")
    }
}
#endif
