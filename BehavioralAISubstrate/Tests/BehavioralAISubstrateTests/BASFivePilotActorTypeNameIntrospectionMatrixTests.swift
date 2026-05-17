// MARK: - BASFivePilotActorTypeNameIntrospectionMatrixTests
// chapter 七百二十五 / M2229 第一刀 — pilot ACTOR type-name
//                                     introspection matrix。
//                                     PIVOT from per-pilot
//                                     ERROR contract to per-
//                                     pilot ACTOR contract。
//
// ## Why
//
// Chapters 717-724 sealed 8 pillars of the 5-pilot ERROR
// typed contract。 With error contract thoroughly pinned,
// chapter 725 PIVOTS to the corresponding 5-pilot ACTOR
// contract — starting with the simplest:type-name
// introspection。
//
// Each pilot ships an actor type (BASMemoryUsageTracker,
// BASMonotonicNanos, BASMetalKernelLibraryLoader,
// BASMPSGraphExecutableCacheCxxBridge,
// BASRustMemoryUsageTrackerActor)。 String(describing:
// PilotActor.self) returns the type name — useful for:
//   - Crash reports identifying which actor produced an
//     error
//   - Log lines tagged with actor source
//   - Migration scripts that select pilot by type name
//
// This file pins:
//   1. Each actor's type-name string is non-empty
//   2. Each type name matches expected exact string
//   3. The 5 type names are globally unique
//
// ## Coverage (5 per-actor tests + 1 global uniqueness)
//
//   1-5. Each pilot's actor type:String(describing:
//        Actor.self) returns expected name
//   6. Cross-pilot uniqueness:5 distinct actor type names

import XCTest
@testable import BASRuntimeCore
@testable import BASMemory
@testable import BASMetalSubstrate
@testable import BASRustCoreBridge

final class BASFivePilotActorTypeNameIntrospectionMatrixTests: XCTestCase {

    // MARK: - SQL pilot — BASMemoryUsageTracker

    func testBASMemoryUsageTrackerActorTypeName() {
        let typeName = String(describing:
            BASMemoryUsageTracker.self)
        XCTAssertEqual(typeName, "BASMemoryUsageTracker",
            "SQL pilot actor type name must be exactly" +
            " 'BASMemoryUsageTracker' (no module prefix" +
            " in default String(describing:) output)")
        XCTAssertFalse(typeName.isEmpty)
    }

    // MARK: - C pilot — BASMonotonicNanos

    func testBASMonotonicNanosActorTypeName() {
        let typeName = String(describing:
            BASMonotonicNanos.self)
        XCTAssertEqual(typeName, "BASMonotonicNanos",
            "C pilot actor type name must be exactly" +
            " 'BASMonotonicNanos'")
        XCTAssertFalse(typeName.isEmpty)
    }

    // MARK: - Metal pilot — BASMetalKernelLibraryLoader

    func testBASMetalKernelLibraryLoaderActorTypeName() {
        let typeName = String(describing:
            BASMetalKernelLibraryLoader.self)
        XCTAssertEqual(typeName,
            "BASMetalKernelLibraryLoader",
            "Metal pilot actor type name must be exactly" +
            " 'BASMetalKernelLibraryLoader'")
        XCTAssertFalse(typeName.isEmpty)
    }

    // MARK: - C++ pilot — BASMPSGraphExecutableCacheCxxBridge

    func testBASMPSGraphExecutableCacheCxxBridgeActorTypeName() {
        let typeName = String(describing:
            BASMPSGraphExecutableCacheCxxBridge.self)
        XCTAssertEqual(typeName,
            "BASMPSGraphExecutableCacheCxxBridge",
            "C++ pilot actor type name must be exactly" +
            " 'BASMPSGraphExecutableCacheCxxBridge'")
        XCTAssertFalse(typeName.isEmpty)
    }

    // MARK: - Rust pilot — BASRustMemoryUsageTrackerActor

    func testBASRustMemoryUsageTrackerActorTypeName() {
        let typeName = String(describing:
            BASRustMemoryUsageTrackerActor.self)
        XCTAssertEqual(typeName,
            "BASRustMemoryUsageTrackerActor",
            "Rust pilot actor type name must be exactly" +
            " 'BASRustMemoryUsageTrackerActor'")
        XCTAssertFalse(typeName.isEmpty)
    }

    // MARK: - Cross-pilot global uniqueness

    /// Pins that all 5 pilot actor type names are
    /// globally unique — no two pilots share an actor
    /// type name。 Telemetry / crash reports / log
    /// aggregators can use the actor type name as a
    /// stable per-pilot identifier without disambiguation。
    func testAllFivePilotActorTypeNamesGloballyUnique() {
        let typeNames: Set<String> = [
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
        XCTAssertEqual(typeNames.count, 5,
            "All 5 pilot actor type names must be globally" +
            " unique. Got \(typeNames.count) distinct names.")
        // Sanity:expected exact set
        let expected: Set<String> = [
            "BASMemoryUsageTracker",
            "BASMonotonicNanos",
            "BASMetalKernelLibraryLoader",
            "BASMPSGraphExecutableCacheCxxBridge",
            "BASRustMemoryUsageTrackerActor"
        ]
        XCTAssertEqual(typeNames, expected,
            "Actor type name set must match expected" +
            " exact 5-element list")
    }
}
