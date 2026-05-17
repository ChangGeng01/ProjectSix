// MARK: - BASFivePilotActorSendableTransferMatrixTests
// chapter 七百二十七 / M2233 第一刀 — pilot ACTOR Sendable
//                                     cross-Task transfer
//                                     matrix。 Third pillar
//                                     of 5-pilot ACTOR
//                                     contract。
//
// ## Why
//
// Chapter 719 sealed Sendable cross-Task transfer for the
// 5 pilot ERROR enums (value-type transfer)。 Chapter 727
// is the corresponding ACTOR-side pillar:proves that
// pilot actor INSTANCES (reference-type Sendable) can be
// transferred across `Task { }.value` boundaries without
// identity loss。
//
// Swift actors are auto-Sendable by the `actor` keyword,
// so this is a runtime witness test for the contract:
//   1. Construct each pilot actor (in-memory mode for
//      pilots that have config branching)
//   2. Capture the actor reference in a child Task closure
//      (compiler-enforces Sendable at capture site)
//   3. Inside the Task,observe the actor + return it
//   4. Await `.value` to receive the actor back in parent
//   5. Verify the returned reference IS THE SAME instance
//      (=== identity check) — actor identity must survive
//      the boundary
//
// If a future commit introduces non-Sendable state into
// any pilot actor (e.g. captures a non-Sendable closure),
// this test fails at compile time。
//
// ## Coverage (5 per-pilot tests + 1 cross-pilot mixed)
//
//   1-5. Each pilot's actor:single-instance transfer
//        across Task boundary preserves === identity
//   6. Mixed-pilot transfer:tuple of (any-Sendable) refs
//        crossing one Task boundary all preserve identity

import XCTest
@testable import BASRuntimeCore
@testable import BASMemory
@testable import BASMetalSubstrate
@testable import BASRustCoreBridge

final class BASFivePilotActorSendableTransferMatrixTests: XCTestCase {

    /// Helper:transfer a Sendable actor reference through
    /// a child Task + verify identity preservation。 The
    /// `===` check confirms reference identity survives the
    /// boundary (Sendable contract for reference types)。
    private func assertActorSendableTransferPreservesIdentity<T: AnyObject & Sendable>(
        _ actor: T,
        file: StaticString = #file,
        line: UInt = #line
    ) async {
        let received: T = await Task {
            return actor
        }.value
        XCTAssertTrue(received === actor,
            "Sendable actor cross-Task transfer must" +
            " preserve === identity (actor reference" +
            " contract)",
            file: file, line: line)
    }

    // MARK: - SQL pilot — BASMemoryUsageTracker

    func testBASMemoryUsageTrackerActorSendableTransfer() async {
        // In-memory mode (no databaseURL) avoids SQLite
        // disk I/O。
        let tracker = BASMemoryUsageTracker()
        await assertActorSendableTransferPreservesIdentity(
            tracker)
    }

    // MARK: - C pilot — BASMonotonicNanos

    func testBASMonotonicNanosActorSendableTransfer() async {
        // V1 mode (cBridgeEnabled defaults FALSE — uses
        // DispatchTime fallback,no C bridge required)。
        let monotonic = BASMonotonicNanos()
        await assertActorSendableTransferPreservesIdentity(
            monotonic)
    }

    // MARK: - Metal pilot — BASMetalKernelLibraryLoader

    func testBASMetalKernelLibraryLoaderActorSendableTransfer() async {
        // V1 mode (metalKernelV2Enabled defaults FALSE —
        // .metalUnavailableOnPlatform thrown lazily on
        // library() call,no GPU spinup at construction)。
        let loader = BASMetalKernelLibraryLoader()
        await assertActorSendableTransferPreservesIdentity(
            loader)
    }

    // MARK: - C++ pilot — BASMPSGraphExecutableCacheCxxBridge

    func testBASMPSGraphExecutableCacheCxxBridgeActorSendableTransfer() async {
        // V1 mode (cxxMpsCacheEnabled defaults FALSE —
        // throws unknownReturnCode(-99) on cache ops,no
        // C++ singleton touched at construction)。
        let bridge = BASMPSGraphExecutableCacheCxxBridge()
        await assertActorSendableTransferPreservesIdentity(
            bridge)
    }

    // MARK: - Rust pilot — BASRustMemoryUsageTrackerActor

    func testBASRustMemoryUsageTrackerActorSendableTransfer() async throws {
        // V1 mode (useRustCore defaults FALSE — throws
        // rustBridgeUnavailableOnPlatform lazily,no Rust
        // XCFramework symbols touched)。
        let rust = try BASRustMemoryUsageTrackerActor()
        await assertActorSendableTransferPreservesIdentity(
            rust)
    }

    // MARK: - Mixed-pilot cross-Task transfer

    /// Construct all 5 pilot actors,pack them into a
    /// Sendable tuple struct,transfer through one Task
    /// boundary,verify all 5 reference identities are
    /// preserved on the other side。 Proves the substrate
    /// can ship multi-pilot actor handles across async
    /// boundaries (e.g. for a unified pilot-host that
    /// dispatches work to all 5 in parallel)。
    func testMixedFivePilotActorSendableTransfer() async throws {
        struct FivePilotActorBundle: Sendable {
            let sql: BASMemoryUsageTracker
            let c: BASMonotonicNanos
            let metal: BASMetalKernelLibraryLoader
            let cxx: BASMPSGraphExecutableCacheCxxBridge
            let rust: BASRustMemoryUsageTrackerActor
        }
        let bundle = FivePilotActorBundle(
            sql: BASMemoryUsageTracker(),
            c: BASMonotonicNanos(),
            metal: BASMetalKernelLibraryLoader(),
            cxx: BASMPSGraphExecutableCacheCxxBridge(),
            rust: try BASRustMemoryUsageTrackerActor())
        let received: FivePilotActorBundle = await Task {
            return bundle
        }.value
        XCTAssertTrue(received.sql === bundle.sql,
            "SQL actor identity must survive transfer")
        XCTAssertTrue(received.c === bundle.c,
            "C actor identity must survive transfer")
        XCTAssertTrue(received.metal === bundle.metal,
            "Metal actor identity must survive transfer")
        XCTAssertTrue(received.cxx === bundle.cxx,
            "C++ actor identity must survive transfer")
        XCTAssertTrue(received.rust === bundle.rust,
            "Rust actor identity must survive transfer")
    }
}
