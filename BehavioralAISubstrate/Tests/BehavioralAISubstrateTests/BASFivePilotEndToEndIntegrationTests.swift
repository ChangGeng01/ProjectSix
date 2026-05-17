// MARK: - BASFivePilotEndToEndIntegrationTests
// chapter 七百十四 / M2207 第一刀 — end-to-end
//                                   integration proof
//                                   that all 5 pilots
//                                   work TOGETHER in
//                                   the same test run。
//
// ## Why this exists
//
// Chapters 七百二-七百十三 produced 5 isolated pilot
// mechanisms,each with its own per-pilot test suite。
// Chapter 七百十三 added `makeWithDefaults()` convenience
// factories making host adoption 1-line per pilot。
//
// What was MISSING:proof that all 5 pilots compose
// correctly in a SINGLE test process。 This file fills
// that gap — one test that constructs all 5 via
// `makeWithDefaults()`,exercises each,and asserts the
// V2 paths are live。
//
// ## Why this matters for「全面 转向」 honesty
//
// chapter 七百十四 audit finding:**ZERO substrate-
// internal direct-init callers** exist for any of the
// 5 pilots。 The substrate is a library;pilots are
// host-facing surfaces。 Substrate cannot self-adopt。
//
// This integration test is the SUBSTRATE-INTERNAL
// EXERCISE that proves the chain works。 Without it,
// the 5 pilots are merely "tested in isolation";
// with it,they're "proven to compose"。 It's the
// closest substrate can come to「全面 转向」 without
// host adoption。
//
// ## Coverage (1 holistic test + 1 audit-finding test)
//
//   1. testAllFivePilotsComposeViaMakeWithDefaults
//      — constructs all 5,exercises each,asserts V2
//   2. testNoSubstrateInternalDirectInitCallersFinding
//      — pins the chapter 714 audit conclusion

import XCTest
@testable import BASRuntimeCore
@testable import BASMemory
@testable import BASMetalSubstrate
@testable import BASRustCoreBridge

final class BASFivePilotEndToEndIntegrationTests:
    XCTestCase
{

    // MARK: - Holistic composition test

    func testAllFivePilotsComposeViaMakeWithDefaults() async throws {
        // Construct all 5 pilots via the chapter 713
        // host adoption convenience factories。 Each
        // returns its V2 path because chapter 712 wired
        // all 5 flags to default-true。
        let dir = FileManager.default.temporaryDirectory
        let sqlURL = dir.appendingPathComponent(
            "bas_5pilot_e2e_" + UUID().uuidString
                + ".sqlite")
        defer {
            try? FileManager.default.removeItem(at: sqlURL)
        }

        // SQL pilot
        let tracker = try await BASMemoryUsageTracker
            .makeWithDefaults(databaseURL: sqlURL)

        // C pilot
        let nanos = await BASMonotonicNanos.makeWithDefaults()

        // Metal pilot
        let metal = await BASMetalKernelLibraryLoader
            .makeWithDefaults()

        // C++ pilot
        let cxx = await BASMPSGraphExecutableCacheCxxBridge
            .makeWithDefaults()
        defer {
            // Clear process-global cache so this test
            // doesn't pollute subsequent runs。
            Task { try? await cxx.clear() }
        }

        // Rust pilot
        let rust = try await BASRustMemoryUsageTrackerActor
            .makeWithDefaults()

        // Exercise each:
        //   SQL — record + count
        _ = try await tracker.record(
            atomID: "atom-e2e",
            sessionRef: "session-e2e",
            turnRef: "turn-e2e",
            permitMode: "allow")
        let sqlCount = await tracker.recordCount
        XCTAssertEqual(sqlCount, 1)

        //   C — read monotonic timestamp
        let t1 = try await nanos.current()
        XCTAssertGreaterThan(t1, 0)
        let isUsingC = await nanos.isUsingCBridge
        XCTAssertTrue(isUsingC,
            "chapter 七百十二 wire-in:cBridgeEnabled" +
            " default-true → C path active")

        //   Metal — check V2 mode
        let isUsingMetalV2 = await metal.isUsingV2
        XCTAssertTrue(isUsingMetalV2,
            "chapter 七百十二 wire-in:metalKernelV2" +
            "Enabled default-true → V2 loader active")

        //   C++ — insert + lookup
        try await cxx.insert(key: "e2e-key", value: "e2e-value")
        let cxxValue = try await cxx.lookup(key: "e2e-key")
        XCTAssertEqual(cxxValue, "e2e-value")
        let isUsingCxx = await cxx.isUsingCxxCache
        XCTAssertTrue(isUsingCxx,
            "chapter 七百十二 wire-in:cxxMpsCacheEnabled" +
            " default-true → C++ cache path active")

        //   Rust — record + recordCount
        _ = try await rust.record(
            atomID: "atom-rust-e2e",
            sessionRef: "s-rust",
            turnRef: "t-rust",
            permitMode: "allow")
        let rustCount = try await rust.recordCount()
        XCTAssertEqual(rustCount, 1)
        let isUsingRust = await rust.isUsingRustCore
        XCTAssertTrue(isUsingRust,
            "chapter 七百十二 wire-in:rustCoreEnabled" +
            " default-true → Rust path active")
    }

    // MARK: - Audit finding pin

    func testNoSubstrateInternalDirectInitCallersFinding() {
        // CRITICAL doctrine-review trigger:if a future
        // commit adds a substrate-internal direct-init
        // call site for ANY of the 5 pilots,this test
        // must be updated to reflect that fact。 Until
        // then,the chapter 七百十四 audit finding stands:
        // substrate has ZERO internal direct-init callers。
        //
        // The empirical method:
        //   grep -rn "BASMemoryUsageTracker(" Sources/
        //   grep -rn "BASMonotonicNanos(" Sources/
        //   grep -rn "BASMetalKernelLibraryLoader(" Sources/
        //   grep -rn "BASMPSGraphExecutableCacheCxxBridge(" Sources/
        //   grep -rn "BASRustMemoryUsageTrackerActor(" Sources/
        //
        // Result at chapter 714 / M2207:zero hits in
        // substrate Sources/ outside the pilots' own
        // files。 All references are doc-comments and
        // doctrine-record text。
        //
        // This pinned constant is the typed surface for
        // that audit finding。 Future contributor wanting
        // to know "did substrate ever adopt the pilots
        // internally?" gets the answer here without
        // re-running the audit。
        XCTAssertEqual(
            BASMultiLanguageScaffoldDoctrine
                .substrateInternalDirectInitCallSiteCount,
            0,
            "Chapter 714 audit:substrate has ZERO" +
            " internal direct-init call sites for any" +
            " of the 5 pilots。 Substrate is a library;" +
            " pilots are host-facing surfaces。 Further" +
            " adoption requires HOST code。")
    }
}
