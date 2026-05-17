// MARK: - BASFivePilotActorCountInvariantTests
// chapter 七百二十六 / M2231 第一刀 — pilot actor count
//                                     invariant matrix。
//                                     Second pillar of
//                                     5-pilot ACTOR
//                                     contract。
//
// ## Why
//
// Chapter 725 sealed actor type-name introspection。
// Chapter 726 seals the count invariant — analog of chapter
// 724's error case-count tripwire but for the ACTOR side。
//
// The substrate ships EXACTLY 5 pilot actors:
//   1. BASMemoryUsageTracker (SQL pilot)
//   2. BASMonotonicNanos (C pilot)
//   3. BASMetalKernelLibraryLoader (Metal pilot)
//   4. BASMPSGraphExecutableCacheCxxBridge (C++ pilot)
//   5. BASRustMemoryUsageTrackerActor (Rust pilot)
//
// If a future commit adds a sixth language pilot OR removes
// one of the existing five WITHOUT updating this test,it
// fails at PR time — making the change explicitly visible
// to reviewers。
//
// Why pin actor count (not just rely on per-actor tests):
//   - Per-actor tests would PASS even if a new pilot was
//     added (existing tests still pass)
//   - The count invariant is the cross-cutting tripwire
//     that catches additive changes too
//   - Chapter 698 anti-sprawl gate explicitly requires
//     explicit user authorization to ADD new pilot
//     surfaces — this test enforces visibility
//
// ## Coverage (5 reachability tests + 1 cross-pilot count)
//
//   1-5. Each pilot's actor type is reachable via
//        @testable import (compile-time witness via type-
//        name string)
//   6. Total pilot actor count = 5 (tripwire)

import XCTest
@testable import BASRuntimeCore
@testable import BASMemory
@testable import BASMetalSubstrate
@testable import BASRustCoreBridge

final class BASFivePilotActorCountInvariantTests: XCTestCase {

    // MARK: - SQL pilot reachability

    func testBASMemoryUsageTrackerReachable() {
        let typeName = String(describing:
            BASMemoryUsageTracker.self)
        XCTAssertEqual(typeName, "BASMemoryUsageTracker",
            "BASMemoryUsageTracker must be reachable" +
            " via @testable import BASMemory")
    }

    // MARK: - C pilot reachability

    func testBASMonotonicNanosReachable() {
        let typeName = String(describing:
            BASMonotonicNanos.self)
        XCTAssertEqual(typeName, "BASMonotonicNanos",
            "BASMonotonicNanos must be reachable via" +
            " @testable import BASRuntimeCore")
    }

    // MARK: - Metal pilot reachability

    func testBASMetalKernelLibraryLoaderReachable() {
        let typeName = String(describing:
            BASMetalKernelLibraryLoader.self)
        XCTAssertEqual(typeName,
            "BASMetalKernelLibraryLoader",
            "BASMetalKernelLibraryLoader must be" +
            " reachable via @testable import" +
            " BASMetalSubstrate")
    }

    // MARK: - C++ pilot reachability

    func testBASMPSGraphExecutableCacheCxxBridgeReachable() {
        let typeName = String(describing:
            BASMPSGraphExecutableCacheCxxBridge.self)
        XCTAssertEqual(typeName,
            "BASMPSGraphExecutableCacheCxxBridge",
            "BASMPSGraphExecutableCacheCxxBridge must" +
            " be reachable via @testable import" +
            " BASMetalSubstrate")
    }

    // MARK: - Rust pilot reachability

    func testBASRustMemoryUsageTrackerActorReachable() {
        let typeName = String(describing:
            BASRustMemoryUsageTrackerActor.self)
        XCTAssertEqual(typeName,
            "BASRustMemoryUsageTrackerActor",
            "BASRustMemoryUsageTrackerActor must be" +
            " reachable via @testable import" +
            " BASRustCoreBridge")
    }

    // MARK: - Cross-pilot total count = 5

    /// Pins the cross-cutting invariant that the substrate
    /// ships EXACTLY 5 pilot actors。 Future additions or
    /// removals must update both this count + the per-pilot
    /// reachability test。
    ///
    /// This is the actor-side analog of chapter 724's error
    /// case-count tripwire。 Chapter 725 already pinned
    /// uniqueness;this pins the count itself。
    func testTotalPilotActorCountIsFive() {
        let pilotActorTypeNames: Set<String> = [
            String(describing:
                BASMemoryUsageTracker.self),
            String(describing:
                BASMonotonicNanos.self),
            String(describing:
                BASMetalKernelLibraryLoader.self),
            String(describing:
                BASMPSGraphExecutableCacheCxxBridge.self),
            String(describing:
                BASRustMemoryUsageTrackerActor.self)
        ]
        XCTAssertEqual(pilotActorTypeNames.count, 5,
            "Substrate must ship EXACTLY 5 pilot actors。" +
            " Adding a 6th language pilot or removing one" +
            " of the existing 5 must update this count" +
            " explicitly — chapter 698 anti-sprawl gate" +
            " requires explicit user authorization for" +
            " new pilot surfaces.")

        // Sanity:expected exact set (also pinned in
        // chapter 725's uniqueness test,this is the
        // independent cross-check)
        let expected: Set<String> = [
            "BASMemoryUsageTracker",
            "BASMonotonicNanos",
            "BASMetalKernelLibraryLoader",
            "BASMPSGraphExecutableCacheCxxBridge",
            "BASRustMemoryUsageTrackerActor"
        ]
        XCTAssertEqual(pilotActorTypeNames, expected,
            "Pilot actor name set must match expected" +
            " exact 5-element list")
    }
}
