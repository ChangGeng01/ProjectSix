// MARK: - BASFivePilotActorDistinctInstanceSeparationMatrixTests
// chapter 七百二十九 / M2237 第一刀 — pilot actor DISTINCT-
//                                     INSTANCE SEPARATION
//                                     matrix。 Fifth pillar
//                                     of 5-pilot ACTOR
//                                     contract。
//
// ## Why
//
// Chapter 727 sealed actor IDENTITY PRESERVATION across a
// `Task { }.value` boundary (=== before == after)。
// Chapter 729 seals the COMPLEMENT contract:two
// separately-constructed actor instances of the same
// pilot type MUST be distinct references (=== returns
// false)。
//
// Why this matters:
//   - Host code that creates two pilot actor instances
//     for distinct purposes (e.g. one for read,one for
//     write) must trust they are independent
//   - A future commit that accidentally introduces a
//     singleton-style cache returning the same instance
//     to every constructor call would silently break
//     callers expecting independent state
//   - The actor-keyword does NOT guarantee distinct
//     identity by default;Swift could theoretically
//     emit cache-on-init optimizations,but it does not
//     (each `actor.init()` returns a fresh allocation)
//
// This file pins the runtime contract that each pilot's
// `Actor()` call returns a distinct allocation。
//
// ## Coverage (5 per-pilot tests + 1 cross-actor distinct)
//
//   1-5. Each pilot:two `init()` calls return distinct
//        references (=== returns false)
//   6. Cross-pilot:5 actor instances all mutually
//      distinct (any two are === false)

import XCTest
@testable import BASRuntimeCore
@testable import BASMemory
@testable import BASMetalSubstrate
@testable import BASRustCoreBridge

final class BASFivePilotActorDistinctInstanceSeparationMatrixTests: XCTestCase {

    /// Helper:assert two references of the same type are
    /// DISTINCT instances (=== returns false)。 Pure
    /// reference-identity check independent of any
    /// Equatable conformance。
    private func assertDistinctInstances<T: AnyObject>(
        _ a: T,
        _ b: T,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        XCTAssertFalse(a === b,
            "Two separately-constructed instances must" +
            " be distinct references (=== false)。 If" +
            " this fails,a singleton-cache regression" +
            " has been introduced。",
            file: file, line: line)
    }

    // MARK: - SQL pilot — BASMemoryUsageTracker

    func testBASMemoryUsageTrackerDistinctInstances() {
        let a = BASMemoryUsageTracker()
        let b = BASMemoryUsageTracker()
        assertDistinctInstances(a, b)
    }

    // MARK: - C pilot — BASMonotonicNanos

    func testBASMonotonicNanosDistinctInstances() {
        let a = BASMonotonicNanos()
        let b = BASMonotonicNanos()
        assertDistinctInstances(a, b)
    }

    // MARK: - Metal pilot — BASMetalKernelLibraryLoader

    func testBASMetalKernelLibraryLoaderDistinctInstances() {
        let a = BASMetalKernelLibraryLoader()
        let b = BASMetalKernelLibraryLoader()
        assertDistinctInstances(a, b)
    }

    // MARK: - C++ pilot — BASMPSGraphExecutableCacheCxxBridge

    func testBASMPSGraphExecutableCacheCxxBridgeDistinctInstances() {
        let a = BASMPSGraphExecutableCacheCxxBridge()
        let b = BASMPSGraphExecutableCacheCxxBridge()
        assertDistinctInstances(a, b)
    }

    // MARK: - Rust pilot — BASRustMemoryUsageTrackerActor

    func testBASRustMemoryUsageTrackerActorDistinctInstances() throws {
        let a = try BASRustMemoryUsageTrackerActor()
        let b = try BASRustMemoryUsageTrackerActor()
        assertDistinctInstances(a, b)
    }

    // MARK: - Cross-pilot distinct-instance matrix

    /// Pins that all 5 pilot actor instances are mutually
    /// distinct references。 Even though they're different
    /// types,this serves as a sanity smoke test:no host
    /// code that holds a `[AnyObject]` collection of all
    /// 5 pilots should accidentally collapse them via
    /// === aliasing。
    func testAllFivePilotsHaveMutuallyDistinctReferences() throws {
        let sql = BASMemoryUsageTracker()
        let c = BASMonotonicNanos()
        let metal = BASMetalKernelLibraryLoader()
        let cxx = BASMPSGraphExecutableCacheCxxBridge()
        let rust = try BASRustMemoryUsageTrackerActor()
        let actors: [AnyObject] = [
            sql, c, metal, cxx, rust]
        // For all (i, j) where i != j,actors[i] ===
        // actors[j] must be false。
        for i in 0..<actors.count {
            for j in 0..<actors.count where j != i {
                XCTAssertFalse(actors[i] === actors[j],
                    "Pilot actor at index \(i) must NOT" +
                    " be === to pilot at index \(j) —" +
                    " cross-pilot reference aliasing" +
                    " regression detected.")
            }
        }
        XCTAssertEqual(actors.count, 5,
            "Test must cover all 5 pilots")
    }
}
