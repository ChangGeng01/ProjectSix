// MARK: - BASMPSGraphExecutableCacheCxxBridgeTests
// chapter 七百五 / M2185 第三刀 — 25 anti-drift PROOF
//                                  tests for the chapter
//                                  七百五 C++ pilot
//                                  (M2183 C++ cache +
//                                  M2184 Swift bridge
//                                  actor)。
//
// ## Coverage matrix (25 tests)
//
// **C ABI surface**
//   1. cxxBridgeABIVersion constant == 1
//   2. live C-side bas_mps_cache_version == 1
//   3. cxxBridgeABIVersion equals liveCxxBridgeABIVersion
//
// **V1 path correctness (default-off)**
//   4. V1 isUsingCxxCache false
//   5. V1 insert throws unknownReturnCode(-99)
//   6. V1 lookup throws unknownReturnCode(-99)
//   7. V1 clear throws on V1 path? — actually V1 clear
//      is a NO-OP (does not throw,does not touch cache)
//   8. V1 size returns 0 without touching cache
//
// **V2 path correctness (opt-in)**
//   9. V2 isUsingCxxCache true
//  10. V2 insert + lookup round-trip preserves value
//  11. V2 lookup of absent key returns nil
//  12. V2 insert overwrite (same key,new value)
//  13. V2 size after 3 inserts equals 3
//  14. V2 size after clear equals 0
//  15. V2 clear is idempotent (call twice)
//
// **Process-global cache contract**
//  16. Two V2 bridge instances share backing store —
//      insert via A,lookup via B succeeds
//  17. clear via A clears bridge B's view
//
// **Error case typing**
//  18. nullPointer Codable round-trip
//  19. cxxInternalException Codable round-trip
//  20. unknownReturnCode(rc) preserves Int32 associated
//      value through Codable
//
// **Flag-aware factory**
//  21. make(flags:) default-off → V1 bridge
//  22. make(flags:) explicit-on → V2 bridge
//
// **Concurrency stress**
//  23. 20 concurrent inserts from a single bridge
//      complete without crash
//  24. 20 concurrent lookups from a single bridge
//      complete without crash
//  25. Concurrent insert + lookup workload completes
//      without crash (data-race smoke test)

import XCTest
@testable import BASMetalSubstrate
@testable import BASRuntimeCore

final class BASMPSGraphExecutableCacheCxxBridgeTests:
    XCTestCase
{

    /// Reset the process-global cache before every test
    /// so scenarios don't pollute each other。
    override func setUp() async throws {
        try await super.setUp()
        let cleaner = BASMPSGraphExecutableCacheCxxBridge(
            useCxxCache: true)
        try await cleaner.clear()
    }

    // MARK: - C ABI surface

    func testCxxBridgeABIVersionConstantIsOne() {
        XCTAssertEqual(
            BASMPSGraphExecutableCacheCxxBridge
                .cxxBridgeABIVersion, 1)
    }

    func testLiveCxxBridgeVersionIsOne() {
        XCTAssertEqual(
            BASMPSGraphExecutableCacheCxxBridge
                .liveCxxBridgeABIVersion(), 1)
    }

    func testCxxBridgeABIVersionEqualsLive() {
        XCTAssertEqual(
            BASMPSGraphExecutableCacheCxxBridge
                .cxxBridgeABIVersion,
            BASMPSGraphExecutableCacheCxxBridge
                .liveCxxBridgeABIVersion(),
            "Swift-side ABI pin must equal C-side live" +
            " bas_mps_cache_version。")
    }

    // MARK: - V1 path correctness

    func testV1IsUsingCxxCacheFalse() async {
        let bridge = BASMPSGraphExecutableCacheCxxBridge(
            useCxxCache: false)
        let using = await bridge.isUsingCxxCache
        XCTAssertFalse(using)
    }

    func testV1InsertThrowsMinusNinetyNine() async {
        let bridge = BASMPSGraphExecutableCacheCxxBridge(
            useCxxCache: false)
        do {
            try await bridge.insert(key: "k", value: "v")
            XCTFail("V1 path must throw to prevent" +
                    " accidental V2 cache mutation")
        } catch BASMPSGraphExecutableCacheCxxBridgeError
            .unknownReturnCode(let rc)
        {
            XCTAssertEqual(rc, -99)
        } catch {
            XCTFail("Wrong error:\(error)")
        }
    }

    func testV1LookupThrowsMinusNinetyNine() async {
        let bridge = BASMPSGraphExecutableCacheCxxBridge(
            useCxxCache: false)
        do {
            _ = try await bridge.lookup(key: "k")
            XCTFail("V1 must throw")
        } catch BASMPSGraphExecutableCacheCxxBridgeError
            .unknownReturnCode(let rc)
        {
            XCTAssertEqual(rc, -99)
        } catch {
            XCTFail("Wrong error:\(error)")
        }
    }

    func testV1ClearIsNoOpDoesNotThrow() async {
        let bridge = BASMPSGraphExecutableCacheCxxBridge(
            useCxxCache: false)
        do {
            try await bridge.clear()
        } catch {
            XCTFail("V1 clear should be a no-op,not" +
                    " throw:\(error)")
        }
    }

    func testV1SizeReturnsZero() async {
        // Even if cache has entries from V2-mode tests,
        // V1 size must return 0 (does not consult cache)。
        let v2 = BASMPSGraphExecutableCacheCxxBridge(
            useCxxCache: true)
        try? await v2.insert(key: "k", value: "v")
        let v1 = BASMPSGraphExecutableCacheCxxBridge(
            useCxxCache: false)
        let v1size = await v1.size()
        XCTAssertEqual(v1size, 0,
            "V1 size must return 0 without touching" +
            " the C++ side。")
    }

    // MARK: - V2 path correctness

    func testV2IsUsingCxxCacheTrue() async {
        let bridge = BASMPSGraphExecutableCacheCxxBridge(
            useCxxCache: true)
        let using = await bridge.isUsingCxxCache
        XCTAssertTrue(using)
    }

    func testV2InsertLookupRoundTrip() async throws {
        let bridge = BASMPSGraphExecutableCacheCxxBridge(
            useCxxCache: true)
        try await bridge.insert(
            key: "round-trip-key",
            value: "round-trip-value")
        let v = try await bridge.lookup(
            key: "round-trip-key")
        XCTAssertEqual(v, "round-trip-value")
    }

    func testV2LookupAbsentKeyReturnsNil() async throws {
        let bridge = BASMPSGraphExecutableCacheCxxBridge(
            useCxxCache: true)
        let v = try await bridge.lookup(
            key: "definitely-not-present")
        XCTAssertNil(v)
    }

    func testV2InsertOverwrite() async throws {
        let bridge = BASMPSGraphExecutableCacheCxxBridge(
            useCxxCache: true)
        try await bridge.insert(key: "k", value: "first")
        try await bridge.insert(key: "k", value: "second")
        let v = try await bridge.lookup(key: "k")
        XCTAssertEqual(v, "second")
    }

    func testV2SizeAfterThreeInserts() async throws {
        let bridge = BASMPSGraphExecutableCacheCxxBridge(
            useCxxCache: true)
        for i in 0..<3 {
            try await bridge.insert(
                key: "k\(i)", value: "v\(i)")
        }
        let s = await bridge.size()
        XCTAssertEqual(s, 3)
    }

    func testV2SizeAfterClearIsZero() async throws {
        let bridge = BASMPSGraphExecutableCacheCxxBridge(
            useCxxCache: true)
        try await bridge.insert(key: "a", value: "1")
        try await bridge.insert(key: "b", value: "2")
        try await bridge.clear()
        let s = await bridge.size()
        XCTAssertEqual(s, 0)
    }

    func testV2ClearIsIdempotent() async throws {
        let bridge = BASMPSGraphExecutableCacheCxxBridge(
            useCxxCache: true)
        try await bridge.clear()
        // Second call must not throw on empty cache。
        try await bridge.clear()
    }

    // MARK: - Process-global cache contract

    func testTwoV2BridgesShareBackingStore() async throws {
        let a = BASMPSGraphExecutableCacheCxxBridge(
            useCxxCache: true)
        let b = BASMPSGraphExecutableCacheCxxBridge(
            useCxxCache: true)
        try await a.insert(
            key: "shared-key", value: "shared-value")
        let v = try await b.lookup(key: "shared-key")
        XCTAssertEqual(v, "shared-value",
            "Cache is process-global singleton — bridge" +
            " B must see bridge A's insert。")
    }

    func testClearViaABridgeClearsAllBridgesView() async throws {
        let a = BASMPSGraphExecutableCacheCxxBridge(
            useCxxCache: true)
        let b = BASMPSGraphExecutableCacheCxxBridge(
            useCxxCache: true)
        try await a.insert(key: "x", value: "y")
        try await a.clear()
        let v = try await b.lookup(key: "x")
        XCTAssertNil(v,
            "Process-global clear via bridge A must" +
            " empty bridge B's view too。")
    }

    // MARK: - Error case typing

    func testErrorNullPointerCodableRoundTrip() throws {
        let original = BASMPSGraphExecutableCacheCxxBridgeError.nullPointer
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASMPSGraphExecutableCacheCxxBridgeError.self,
            from: data)
        XCTAssertEqual(decoded, original)
    }

    func testErrorCxxInternalExceptionCodableRoundTrip() throws {
        let original = BASMPSGraphExecutableCacheCxxBridgeError.cxxInternalException
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASMPSGraphExecutableCacheCxxBridgeError.self,
            from: data)
        XCTAssertEqual(decoded, original)
    }

    func testErrorUnknownReturnCodePreservesRc() throws {
        let original = BASMPSGraphExecutableCacheCxxBridgeError.unknownReturnCode(42)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASMPSGraphExecutableCacheCxxBridgeError.self,
            from: data)
        XCTAssertEqual(decoded, original)
        if case .unknownReturnCode(let rc) = decoded {
            XCTAssertEqual(rc, 42)
        } else {
            XCTFail("Wrong case")
        }
    }

    // MARK: - Flag-aware factory

    func testMakeFactoryDefaultChoosesV2AtChapter712() async {
        // M2203 chapter 七百十二 — cxxMpsCacheEnabled
        // flipped default-true。 Factory now picks V2。
        let flags = BASLanguageAugmentationFeatureFlags()
        let defaultValue = await flags.isEnabled(
            .cxxMpsCacheEnabled)
        XCTAssertTrue(defaultValue,
            "M2203 wire-in:cxxMpsCacheEnabled now" +
            " defaults TRUE")
        let bridge = await BASMPSGraphExecutableCacheCxxBridge.make(flags: flags)
        let using = await bridge.isUsingCxxCache
        XCTAssertTrue(using)
    }

    func testMakeFactoryExplicitlyOnChoosesV2() async {
        let flags = BASLanguageAugmentationFeatureFlags()
        await flags.setFlag(
            .cxxMpsCacheEnabled, to: true)
        let bridge = await BASMPSGraphExecutableCacheCxxBridge.make(flags: flags)
        let using = await bridge.isUsingCxxCache
        XCTAssertTrue(using)
    }

    // MARK: - Concurrency stress

    func testConcurrentInsertsCompleteWithoutCrash() async throws {
        let bridge = BASMPSGraphExecutableCacheCxxBridge(
            useCxxCache: true)
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<20 {
                group.addTask {
                    try? await bridge.insert(
                        key: "concurrent-\(i)",
                        value: "v\(i)")
                }
            }
        }
        let s = await bridge.size()
        XCTAssertEqual(s, 20,
            "All 20 concurrent inserts should land in" +
            " the cache without loss。")
    }

    func testConcurrentLookupsCompleteWithoutCrash() async throws {
        let bridge = BASMPSGraphExecutableCacheCxxBridge(
            useCxxCache: true)
        // Pre-fill。
        for i in 0..<5 {
            try await bridge.insert(
                key: "k\(i)", value: "v\(i)")
        }
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<20 {
                for i in 0..<5 {
                    group.addTask {
                        _ = try? await bridge.lookup(
                            key: "k\(i)")
                    }
                }
            }
        }
        // Cache size unchanged by lookups。
        let s = await bridge.size()
        XCTAssertEqual(s, 5)
    }

    func testConcurrentReadWriteWorkloadCompletes() async throws {
        let bridge = BASMPSGraphExecutableCacheCxxBridge(
            useCxxCache: true)
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<20 {
                group.addTask {
                    try? await bridge.insert(
                        key: "k\(i)", value: "v\(i)")
                    _ = try? await bridge.lookup(
                        key: "k\(i)")
                }
            }
        }
        // No crash + at least one entry landed (likely all
        // 20)。
        let s = await bridge.size()
        XCTAssertGreaterThan(s, 0)
    }
}
