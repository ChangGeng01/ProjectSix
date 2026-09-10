// Concurrency/throughput arc — host-side (CI-able, no MLX) companion to the on-device concurrent-turns
// certification (Docs/CONCURRENCY_MEASUREMENT_FINDINGS.md #5, scripts/run-concurrent-turns-cert.sh).
//
// What this proves DETERMINISTICALLY, on the macOS test host, with NO real model:
//   1. The shared organ adapter is concurrency-SAFE + deterministic: N concurrent `draft()` calls all
//      return and yield a stable traceID (no hang, no torn state, no drop).
//   2. N concurrent `process()` turns on ONE shared brain are LIVE — they all complete within a deadline
//      (the regression tripwire for a future cross-actor await cycle / deadlock).
//
// What this does NOT claim (and why this file is named "Liveness", NOT "Serialization"): it does NOT assert
// the adapter ACTOR serializes decode. Swift actors are REENTRANT across `await`, so the adapter actor is not
// the serializer. The real serializer for the GPU decode is MLX's process-global `evalLock`
// (Vendor/mlx-swift/Source/MLX/Transforms+Eval.swift:9) held across the synchronous `mlx_eval` — which is why
// N concurrent turns yield no GPU-decode throughput gain. That SERIALIZATION is a hardware property, proven
// ON-DEVICE by the cert (scripts/run-concurrent-turns-cert.sh: wall_speedup ≈ 1.0; FINDINGS #5), NOT by a
// synthetic-lock unit test here. So this host file deliberately scopes to liveness + concurrency-safety only.

import XCTest
import Foundation
@testable import BASOrgan
@testable import BASHostKit
import BASRuntimeCore
#if (os(iOS) || os(macOS)) && DEBUG
@testable import BASMemory
#endif

final class BASConcurrentTurnLivenessTests: XCTestCase {

    // MARK: - Helpers

    private enum ProbeDeadline: Error { case exceeded }

    /// Run `work` (which returns a completed-count) racing a deadline. If the deadline wins, throw so the
    /// test FAILS with a clear message rather than hanging the whole suite (the no-deadlock guard).
    @discardableResult
    private func runWithinDeadline(
        _ seconds: Double,
        _ work: @escaping @Sendable () async -> Int
    ) async throws -> Int {
        try await withThrowingTaskGroup(of: Int.self) { group in
            group.addTask { await work() }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw ProbeDeadline.exceeded
            }
            defer { group.cancelAll() }
            guard let first = try await group.next() else { return 0 }
            return first
        }
    }

    private func request(_ id: String) -> BASOrganRequest {
        BASOrganRequest(
            requestID: id, role: .scout, preset: .scout,
            instruction: "summarize", context: [])
    }

    // MARK: - 1. Adapter is concurrency-safe + deterministic under load

    func testConcurrentDraftsAreLiveAndDeterministic() async throws {
        let adapter = BASOrganDeterministicAdapter()
        let n = 8
        let req = request("shared-req")
        let expectedTrace = BASOrganDeterministicAdapter.digest(
            for: req, providerID: adapter.descriptor.providerID)

        let traces = try await withThrowingTaskGroup(of: String.self) { group -> [String] in
            for _ in 0..<n {
                group.addTask { try await adapter.draft(req).traceID }
            }
            var out: [String] = []
            for try await t in group { out.append(t) }
            return out
        }

        XCTAssertEqual(traces.count, n,
            "all \(n) concurrent drafts must return — no hang, no drop")
        XCTAssertTrue(traces.allSatisfy { $0 == expectedTrace },
            "the deterministic adapter must yield a stable traceID under concurrency " +
            "(proves the shared adapter is concurrency-safe, not torn)")
    }

    // MARK: - 2. Concurrent turns on one brain complete (no deadlock)

    func testConcurrentProcessIsLiveAndDrainsWithinDeadline() async throws {
        #if (os(iOS) || os(macOS)) && DEBUG
        // Concurrent turns on ONE brain can race the nonisolated retrieve read against a memory write,
        // tripping BASRoutedVectorIndexStorage's DEBUG concurrency tripwire (assertionFailure by default).
        // That retrieve-read contract is single-stream-BY-DESIGN; swap the handler to RECORD so this liveness
        // probe can't crash, then assert the real property: all N process() calls COMPLETE (no deadlock).
        let originalHandler = BASRoutedVectorIndexStorage._concurrencyViolationHandler
        defer { BASRoutedVectorIndexStorage._concurrencyViolationHandler = originalHandler }
        let violations = ViolationCounter()
        BASRoutedVectorIndexStorage._concurrencyViolationHandler = { _ in violations.bump() }
        #endif

        let brain = try await BASCognitiveBrain.makeWithDefaults()
        let n = 4

        let completed = try await runWithinDeadline(30) { @Sendable in
            await withTaskGroup(of: Bool.self) { group -> Int in
                for k in 0..<n {
                    group.addTask {
                        let result = await brain.process("concurrent-turn-\(k)")
                        return !result.renderedOutput.headline.isEmpty
                    }
                }
                var ok = 0
                for await populated in group where populated { ok += 1 }
                return ok
            }
        }

        XCTAssertEqual(completed, n,
            "all \(n) concurrent process() turns must complete with a populated result — " +
            "no deadlock, no cross-actor await cycle")

        #if (os(iOS) || os(macOS)) && DEBUG
        // Surface (do NOT assert ==0) the recorded retrieve-read tripwire hits. Concurrent turns on ONE brain
        // can legitimately trip the single-stream `cosineTopKAtomIDsSync` contract (a read racing a write) —
        // that's expected here and is exactly WHY production serves one turn per brain. A non-zero count
        // documents that contract; the liveness assertion above is the real check.
        print("[BASConcurrentTurnLivenessTests] recorded \(violations.count) retrieve-read tripwire hit(s) " +
            "across \(n) concurrent turns (single-stream contract — observational, not a failure)")
        #endif
    }
}

// Thread-safe counter for recorded (non-fatal) concurrency-tripwire hits during the liveness probe.
private final class ViolationCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var n = 0
    func bump() { lock.lock(); n += 1; lock.unlock() }
    var count: Int { lock.lock(); defer { lock.unlock() }; return n }
}
