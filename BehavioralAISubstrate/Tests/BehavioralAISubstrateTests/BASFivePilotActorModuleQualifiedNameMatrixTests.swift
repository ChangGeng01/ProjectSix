// MARK: - BASFivePilotActorModuleQualifiedNameMatrixTests
// chapter 七百二十八 / M2235 第一刀 — pilot actor MODULE-
//                                     QUALIFIED type-name
//                                     introspection matrix。
//                                     Fourth pillar of
//                                     5-pilot ACTOR
//                                     contract。
//
// ## Why
//
// Chapter 725 pinned `String(describing: Actor.self)` —
// the BARE type name (e.g. "BASMemoryUsageTracker")。
// Chapter 728 pins the complement:`String(reflecting:
// Actor.self)` — the MODULE-QUALIFIED name (e.g.
// "BASMemory.BASMemoryUsageTracker")。
//
// Why both forms matter:
//   - Bare name (chapter 725):cheap to compute,UI-
//     friendly for log lines,unique within substrate
//   - Qualified name (this chapter):disambiguates if a
//     host app introduces a same-named type from another
//     module。 Critical for crash report symbolication
//     where two `MemoryTracker` types could exist (host
//     app's + substrate's)。
//
// String(reflecting:) reads the type's mangled metadata
// and synthesizes the dotted-path string。 The output is
// stable across builds of the same toolchain and module
// graph。
//
// ## Coverage (5 per-pilot tests + 1 cross-pilot module map)
//
//   1-5. Each pilot's actor:String(reflecting:) returns
//        expected "Module.TypeName" string
//   6. Cross-pilot module mapping pin:5 distinct module
//      prefixes (BASMemory, BASRuntimeCore,
//      BASMetalSubstrate ×2, BASRustCoreBridge)

import XCTest
@testable import BASRuntimeCore
@testable import BASMemory
@testable import BASMetalSubstrate
@testable import BASRustCoreBridge

final class BASFivePilotActorModuleQualifiedNameMatrixTests: XCTestCase {

    // MARK: - SQL pilot — BASMemory module

    func testBASMemoryUsageTrackerModuleQualifiedName() {
        let qualified = String(reflecting:
            BASMemoryUsageTracker.self)
        XCTAssertEqual(qualified,
            "BASMemory.BASMemoryUsageTracker",
            "SQL pilot must be qualified as" +
            " BASMemory.BASMemoryUsageTracker")
    }

    // MARK: - C pilot — BASRuntimeCore module

    func testBASMonotonicNanosModuleQualifiedName() {
        let qualified = String(reflecting:
            BASMonotonicNanos.self)
        XCTAssertEqual(qualified,
            "BASRuntimeCore.BASMonotonicNanos",
            "C pilot must be qualified as" +
            " BASRuntimeCore.BASMonotonicNanos")
    }

    // MARK: - Metal pilot — BASMetalSubstrate module

    func testBASMetalKernelLibraryLoaderModuleQualifiedName() {
        let qualified = String(reflecting:
            BASMetalKernelLibraryLoader.self)
        XCTAssertEqual(qualified,
            "BASMetalSubstrate.BASMetalKernelLibraryLoader",
            "Metal pilot must be qualified as" +
            " BASMetalSubstrate.BASMetalKernelLibraryLoader")
    }

    // MARK: - C++ pilot — BASMetalSubstrate module (shared with Metal)

    func testBASMPSGraphExecutableCacheCxxBridgeModuleQualifiedName() {
        let qualified = String(reflecting:
            BASMPSGraphExecutableCacheCxxBridge.self)
        XCTAssertEqual(qualified,
            "BASMetalSubstrate.BASMPSGraphExecutableCacheCxxBridge",
            "C++ pilot must be qualified as" +
            " BASMetalSubstrate." +
            "BASMPSGraphExecutableCacheCxxBridge")
    }

    // MARK: - Rust pilot — BASRustCoreBridge module

    func testBASRustMemoryUsageTrackerActorModuleQualifiedName() {
        let qualified = String(reflecting:
            BASRustMemoryUsageTrackerActor.self)
        XCTAssertEqual(qualified,
            "BASRustCoreBridge.BASRustMemoryUsageTrackerActor",
            "Rust pilot must be qualified as" +
            " BASRustCoreBridge.BASRustMemoryUsageTrackerActor")
    }

    // MARK: - Cross-pilot module mapping pin

    /// Pins the (pilotName → moduleName) mapping。 Shows
    /// the 5-pilot substrate decomposes into 4 modules
    /// (Metal pilot + C++ pilot share BASMetalSubstrate)。
    /// Future pilots that move between modules will fail
    /// this test at PR time。
    func testCrossPilotModuleMappingPin() {
        let actualMap: Set<PilotModuleEntry> = [
            entryFor(BASMemoryUsageTracker.self),
            entryFor(BASMonotonicNanos.self),
            entryFor(BASMetalKernelLibraryLoader.self),
            entryFor(BASMPSGraphExecutableCacheCxxBridge.self),
            entryFor(BASRustMemoryUsageTrackerActor.self)
        ]
        let expectedMap: Set<PilotModuleEntry> = [
            PilotModuleEntry(
                pilotTypeName: "BASMemoryUsageTracker",
                moduleName: "BASMemory"),
            PilotModuleEntry(
                pilotTypeName: "BASMonotonicNanos",
                moduleName: "BASRuntimeCore"),
            PilotModuleEntry(
                pilotTypeName: "BASMetalKernelLibraryLoader",
                moduleName: "BASMetalSubstrate"),
            PilotModuleEntry(
                pilotTypeName:
                    "BASMPSGraphExecutableCacheCxxBridge",
                moduleName: "BASMetalSubstrate"),
            PilotModuleEntry(
                pilotTypeName:
                    "BASRustMemoryUsageTrackerActor",
                moduleName: "BASRustCoreBridge")
        ]
        XCTAssertEqual(actualMap, expectedMap,
            "Pilot → module mapping drift detected:" +
            " expected \(expectedMap), got \(actualMap)")

        // The substrate decomposes into 4 distinct modules
        // across 5 pilots (Metal + C++ share BASMetal-
        // Substrate)。
        let distinctModules = Set(actualMap.map { $0.moduleName })
        XCTAssertEqual(distinctModules.count, 4,
            "5 pilots must decompose into exactly 4" +
            " modules (Metal + C++ share BASMetalSubstrate)")
    }

    private struct PilotModuleEntry: Hashable {
        let pilotTypeName: String
        let moduleName: String
    }

    /// Helper:build a (pilotTypeName, moduleName) entry
    /// from a type by splitting the qualified name on the
    /// first `.`。
    private func entryFor<T>(_: T.Type) -> PilotModuleEntry {
        let qualified = String(reflecting: T.self)
        // Format: "ModuleName.TypeName"
        guard let dotIndex = qualified.firstIndex(of: ".")
        else {
            return PilotModuleEntry(
                pilotTypeName: qualified,
                moduleName: "")
        }
        let module = String(qualified[..<dotIndex])
        let typeName = String(qualified[
            qualified.index(after: dotIndex)...])
        return PilotModuleEntry(
            pilotTypeName: typeName,
            moduleName: module)
    }
}
