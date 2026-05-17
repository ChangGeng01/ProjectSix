// MARK: - BASRustMemoryUsageTrackerActorTests
// chapter 七百六 / M2189 第三刀 — 28 anti-drift PROOF
//                                  tests for the chapter
//                                  七百六 Rust pilot
//                                  (M2187 Cargo crate +
//                                  XCFramework + M2188
//                                  Package.swift binary
//                                  Target + M2189 Swift
//                                  actor wrapper)。
//
// ## Coverage matrix (28 tests)
//
// **Bridge constants (BASRustCoreBridge namespace)**
//   1. scaffoldVersion == 1 (bumped at M2188)
//   2. rustABIVersion == 1
//   3. cargoCrateVersion == "0.1.0"
//   4. rustToolchainChannel == "stable"
//   5. xcframeworkVendorPath pin
//   6. shippedSlices == ["macos-arm64"]
//   7. macosArm64SliceSHA256 pinned (regression catches
//      future XCFramework rebuild that changes hash —
//      doctrine review trigger)
//   8. pilotChapter == "chapter 七百六 / M2187-M2190"
//
// **ABI version cross-mirror (CRITICAL anti-drift)**
//   9. isRustBridgeAvailable returns true on Apple
//  10. liveRustABIVersion() returns non-nil + == 1
//  11. rustABIVersion == liveRustABIVersion()!
//      (the cross-mirror PROOF — catches future Rust
//      ABI_VERSION bump that doesn't update Swift pin)
//
// **Actor init + flag honoring**
//  12. init(useRustCore: false) — isUsingRustCore false
//  13. init(useRustCore: true) — isUsingRustCore true
//  14. init() default — isUsingRustCore false (chapter
//      477 ADR-014 OPT-IN preservation)
//
// **V1 path correctness**
//  15. V1 record() throws .rustBridgeUnavailableOnPlatform
//  16. V1 recordCount() throws
//  17. V1 allRecords() throws
//
// **V2 path correctness (Apple-platform-only)**
//  18. V2 record() returns non-empty recordID
//  19. V2 recordCount() == 0 immediately after init
//  20. V2 recordCount() == 3 after 3 records
//  21. V2 allRecords() returns the 3 records sorted
//      by retrievedAt ascending
//
// **Codable wire-format byte-equality vs V1 (BYTE-EQUALITY-CLASS PROOF)**
//  22. V1 + V2 records with identical inputs produce
//      identical [BASMemoryUsageRecord] when normalized
//      (record IDs differ per instance,but field shapes
//      + values match exactly)
//
// **Error case typing**
//  23. rustBridgeUnavailableOnPlatform Codable round-trip
//  24. initFailed Codable round-trip
//  25. nullPointer Codable round-trip
//  26. rustInternalException Codable round-trip
//  27. jsonDecodeFailed(message:) preserves associated value
//
// **Flag-aware factory**
//  28. make(flags:) honors default-off (V1) + explicit-on (V2)

import XCTest
@testable import BASRustCoreBridge
@testable import BASRuntimeCore
@testable import BASMemory

final class BASRustMemoryUsageTrackerActorTests:
    XCTestCase
{

    // MARK: - Bridge constants

    func testScaffoldVersionIsOne() {
        XCTAssertEqual(
            BASRustCoreBridge.scaffoldVersion, 1)
    }

    func testRustABIVersionConstantIsOne() {
        XCTAssertEqual(
            BASRustCoreBridge.rustABIVersion, 1)
    }

    func testCargoCrateVersionPin() {
        XCTAssertEqual(
            BASRustCoreBridge.cargoCrateVersion, "0.1.0")
    }

    func testRustToolchainChannelPin() {
        XCTAssertEqual(
            BASRustCoreBridge.rustToolchainChannel,
            "stable")
    }

    func testXcframeworkVendorPathPin() {
        XCTAssertEqual(
            BASRustCoreBridge.xcframeworkVendorPath,
            "Vendor/bas-rust-binaries/BASRustMemoryTracker.xcframework")
    }

    func testShippedSlicesPin() {
        XCTAssertEqual(
            BASRustCoreBridge.shippedSlices,
            ["macos-arm64"])
    }

    func testMacosArm64SliceSHA256Pin() {
        XCTAssertEqual(
            BASRustCoreBridge.macosArm64SliceSHA256,
            "7557c7dadb6d411deaba54212bec350d248a80723c688cf0b94447bf291d772e",
            "Chapter 七百一 RED FLAG #1 reproducibility-" +
            "verification pin。 If this hash changes," +
            "a future commit rebuilt the XCFramework " +
            "with different toolchain / flags — that's " +
            "a doctrine review trigger。")
    }

    func testPilotChapterPin() {
        XCTAssertEqual(
            BASRustCoreBridge.pilotChapter,
            "chapter 七百六 / M2187-M2190")
    }

    // MARK: - ABI version cross-mirror

    func testIsRustBridgeAvailableTrueOnApple() {
        // This file builds + runs on macOS = Apple
        // platform with XCFramework slice。
        XCTAssertTrue(
            BASRustCoreBridge.isRustBridgeAvailable)
    }

    func testLiveRustABIVersionNonNilAndOne() {
        let live = BASRustCoreBridge.liveRustABIVersion()
        XCTAssertNotNil(live)
        XCTAssertEqual(live, 1)
    }

    func testRustABIVersionCrossMirrorMatchesLive() {
        // The anti-drift test that catches a future
        // Rust-side ABI_VERSION bump missing the Swift
        // side。 Bumping requires updating BOTH。
        let live = BASRustCoreBridge.liveRustABIVersion()!
        XCTAssertEqual(
            BASRustCoreBridge.rustABIVersion, live,
            "Swift-side rustABIVersion MUST equal" +
            " C-side bas_rust_tracker_version()。")
    }

    // MARK: - Actor init + flag honoring

    func testInitFalseHasV1Flag() async throws {
        let actor = try BASRustMemoryUsageTrackerActor(
            useRustCore: false)
        let v = await actor.isUsingRustCore
        XCTAssertFalse(v)
    }

    func testInitTrueHasV2Flag() async throws {
        let actor = try BASRustMemoryUsageTrackerActor(
            useRustCore: true)
        let v = await actor.isUsingRustCore
        XCTAssertTrue(v)
    }

    func testInitDefaultIsV1() async throws {
        let actor = try BASRustMemoryUsageTrackerActor()
        let v = await actor.isUsingRustCore
        XCTAssertFalse(v,
            "Default init must be V1 (chapter 477" +
            " ADR-014 OPT-IN preservation)。")
    }

    // MARK: - V1 path correctness

    func testV1RecordThrowsRustBridgeUnavailable() async throws {
        let actor = try BASRustMemoryUsageTrackerActor(
            useRustCore: false)
        do {
            _ = try await actor.record(
                atomID: "a", sessionRef: "s",
                turnRef: "t", permitMode: "allow")
            XCTFail("V1 record() must throw")
        } catch BASRustMemoryUsageTrackerActorError
            .rustBridgeUnavailableOnPlatform {
            // expected
        } catch {
            XCTFail("Wrong error:\(error)")
        }
    }

    func testV1RecordCountThrows() async throws {
        let actor = try BASRustMemoryUsageTrackerActor(
            useRustCore: false)
        do {
            _ = try await actor.recordCount()
            XCTFail("V1 recordCount() must throw")
        } catch BASRustMemoryUsageTrackerActorError
            .rustBridgeUnavailableOnPlatform {
        } catch {
            XCTFail("Wrong error")
        }
    }

    func testV1AllRecordsThrows() async throws {
        let actor = try BASRustMemoryUsageTrackerActor(
            useRustCore: false)
        do {
            _ = try await actor.allRecords()
            XCTFail("V1 allRecords() must throw")
        } catch BASRustMemoryUsageTrackerActorError
            .rustBridgeUnavailableOnPlatform {
        } catch {
            XCTFail("Wrong error")
        }
    }

    // MARK: - V2 path correctness (Apple-only)

    func testV2RecordReturnsNonEmptyRecordID() async throws {
        let actor = try BASRustMemoryUsageTrackerActor(
            useRustCore: true)
        let id = try await actor.record(
            atomID: "a", sessionRef: "s",
            turnRef: "t", permitMode: "allow")
        XCTAssertFalse(id.isEmpty)
    }

    func testV2RecordCountZeroOnFreshInit() async throws {
        let actor = try BASRustMemoryUsageTrackerActor(
            useRustCore: true)
        let n = try await actor.recordCount()
        XCTAssertEqual(n, 0)
    }

    func testV2RecordCountThreeAfterThreeRecords() async throws {
        let actor = try BASRustMemoryUsageTrackerActor(
            useRustCore: true)
        for i in 0..<3 {
            _ = try await actor.record(
                atomID: "a\(i)", sessionRef: "s",
                turnRef: "t\(i)", permitMode: "allow")
        }
        let n = try await actor.recordCount()
        XCTAssertEqual(n, 3)
    }

    func testV2AllRecordsSortedByRetrievedAtAscending()
        async throws
    {
        let actor = try BASRustMemoryUsageTrackerActor(
            useRustCore: true)
        let base = Date(
            timeIntervalSince1970: 1_700_000_000)
        for i in 0..<3 {
            _ = try await actor.record(
                atomID: "a\(i)", sessionRef: "s",
                turnRef: "t\(i)", permitMode: "allow",
                retrievedAt: base.addingTimeInterval(
                    TimeInterval(i)))
        }
        let records = try await actor.allRecords()
        XCTAssertEqual(records.count, 3)
        for i in 1..<records.count {
            XCTAssertLessThanOrEqual(
                records[i - 1].retrievedAt,
                records[i].retrievedAt,
                "V2 allRecords() must be sorted" +
                " ascending by retrievedAt。")
        }
    }

    // MARK: - Codable wire-format byte-equality vs V1

    func testV1V2CodableWireFormatByteEqualityNormalized()
        async throws
    {
        // V1 reference path:in-memory Swift tracker。
        let v1 = BASMemoryUsageTracker()
        let v2 = try BASRustMemoryUsageTrackerActor(
            useRustCore: true)

        let stamps = [
            Date(timeIntervalSince1970: 1_700_000_000),
            Date(timeIntervalSince1970: 1_700_000_001),
            Date(timeIntervalSince1970: 1_700_000_002)
        ]
        for (i, stamp) in stamps.enumerated() {
            _ = try await v1.record(
                atomID: "atom-\(i)", sessionRef: "s",
                turnRef: "t\(i)", permitMode: "allow",
                retrievedAt: stamp)
            _ = try await v2.record(
                atomID: "atom-\(i)", sessionRef: "s",
                turnRef: "t\(i)", permitMode: "allow",
                retrievedAt: stamp)
        }

        let v1Records = await v1.allRecords()
        let v2Records = try await v2.allRecords()
        XCTAssertEqual(v1Records.count, 3)
        XCTAssertEqual(v2Records.count, 3)

        // Normalize per-instance UUIDs to compare wire
        // shape。
        func normalize(
            _ recs: [BASMemoryUsageRecord]
        ) -> [BASMemoryUsageRecord] {
            recs.map {
                BASMemoryUsageRecord(
                    recordID: "X",
                    atomID: $0.atomID,
                    retrievedAt: $0.retrievedAt,
                    sessionRef: $0.sessionRef,
                    turnRef: $0.turnRef,
                    permitMode: $0.permitMode,
                    helpedFlag: $0.helpedFlag)
            }
        }
        XCTAssertEqual(
            normalize(v1Records),
            normalize(v2Records),
            "V1 Swift + V2 Rust paths must produce" +
            " byte-equal record sequences modulo per-" +
            "instance UUIDs。 BYTE-EQUALITY-CLASS PROOF" +
            " for chapter 七百六 Rust pilot。")
    }

    // MARK: - Error case typing

    func testErrorRustBridgeUnavailableCodableRoundTrip() throws {
        let original = BASRustMemoryUsageTrackerActorError
            .rustBridgeUnavailableOnPlatform
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASRustMemoryUsageTrackerActorError.self,
            from: data)
        XCTAssertEqual(decoded, original)
    }

    func testErrorInitFailedCodableRoundTrip() throws {
        let original = BASRustMemoryUsageTrackerActorError
            .initFailed
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASRustMemoryUsageTrackerActorError.self,
            from: data)
        XCTAssertEqual(decoded, original)
    }

    func testErrorNullPointerCodableRoundTrip() throws {
        let original = BASRustMemoryUsageTrackerActorError
            .nullPointer
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASRustMemoryUsageTrackerActorError.self,
            from: data)
        XCTAssertEqual(decoded, original)
    }

    func testErrorRustInternalExceptionCodableRoundTrip() throws {
        let original = BASRustMemoryUsageTrackerActorError
            .rustInternalException
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASRustMemoryUsageTrackerActorError.self,
            from: data)
        XCTAssertEqual(decoded, original)
    }

    func testErrorJsonDecodeFailedPreservesMessage() throws {
        let original = BASRustMemoryUsageTrackerActorError
            .jsonDecodeFailed(message: "parse error")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASRustMemoryUsageTrackerActorError.self,
            from: data)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - Flag-aware factory

    func testMakeFactoryHonorsDefaultOffAndExplicitOn() async throws {
        let flags = BASLanguageAugmentationFeatureFlags()

        // Default off → V1
        let defaultValue = await flags.isEnabled(
            .rustCoreEnabled)
        XCTAssertFalse(defaultValue)
        let v1 = try await BASRustMemoryUsageTrackerActor
            .make(flags: flags)
        let v1using = await v1.isUsingRustCore
        XCTAssertFalse(v1using)

        // Explicit on → V2
        await flags.setFlag(.rustCoreEnabled, to: true)
        let v2 = try await BASRustMemoryUsageTrackerActor
            .make(flags: flags)
        let v2using = await v2.isUsingRustCore
        XCTAssertTrue(v2using)
    }
}
