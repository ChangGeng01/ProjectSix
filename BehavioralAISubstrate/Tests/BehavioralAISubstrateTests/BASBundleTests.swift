// MARK: - BASBundleTests — chapter 四百三 / M960

import Foundation
import XCTest
@testable import BASRuntimeCore

final class BASBundleTests: XCTestCase {

    struct TestItem: Sendable, Equatable, Codable {
        let value: String
    }

    // MARK: - Basic instantiation

    func testInitWithDefaults() {
        let bundle = BASBundle<TestItem>(
            items: [TestItem(value: "a")])
        XCTAssertEqual(bundle.count, 1)
        XCTAssertEqual(
            bundle.schemaVersion,
            BASBundle<TestItem>.defaultSchemaVersion)
    }

    func testInitWithExplicitFields() {
        let date = Date(timeIntervalSinceReferenceDate: 100)
        let bundle = BASBundle<TestItem>(
            bundleID: "fixed-id",
            schemaVersion: "1.0.0",
            items: [TestItem(value: "a"),
                    TestItem(value: "b")],
            metadata: ["host": "alice"],
            recordedAt: date)
        XCTAssertEqual(bundle.bundleID, "fixed-id")
        XCTAssertEqual(bundle.count, 2)
        XCTAssertEqual(bundle.recordedAt, date)
        XCTAssertEqual(
            bundle.metadataValue(forKey: "host"), "alice")
    }

    // MARK: - Codable round-trip

    func testCodableRoundTrip() throws {
        let bundle = BASBundle<TestItem>(
            bundleID: "b1",
            schemaVersion: "1.0.0",
            items: [TestItem(value: "x")],
            metadata: ["k": "v"],
            recordedAt: Date(
                timeIntervalSinceReferenceDate: 0))
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(bundle)
        let decoded = try JSONDecoder().decode(
            BASBundle<TestItem>.self, from: data)
        XCTAssertEqual(decoded, bundle)
    }

    // MARK: - Pure functional updates

    func testAppendingItemReturnsFreshBundle() {
        let original = BASBundle<TestItem>(
            items: [TestItem(value: "a")])
        let new = original.appending(
            item: TestItem(value: "b"))
        XCTAssertEqual(original.count, 1,
            "M960:appending must NOT mutate original")
        XCTAssertEqual(new.count, 2)
        XCTAssertEqual(
            new.bundleID, original.bundleID,
            "appending preserves bundleID")
    }

    func testWithMetadataReturnsFreshBundle() {
        let original = BASBundle<TestItem>(
            items: [],
            metadata: ["a": "1"])
        let new = original.withMetadata("2", forKey: "a")
        XCTAssertEqual(
            original.metadataValue(forKey: "a"), "1",
            "M960:withMetadata must NOT mutate original")
        XCTAssertEqual(
            new.metadataValue(forKey: "a"), "2")
    }

    // MARK: - BASBundleProtocol conformance

    func testBundleConformsToBASBundleProtocol() {
        let bundle = BASBundle<TestItem>(items: [])
        let _: any BASBundleProtocol = bundle
        XCTAssertNotNil(bundle.bundleID)
    }

    // MARK: - Edge cases

    func testEmptyBundleIsEmpty() {
        let bundle = BASBundle<TestItem>(items: [])
        XCTAssertTrue(bundle.isEmpty)
        XCTAssertEqual(bundle.count, 0)
    }

    func testMetadataDefaultsToEmpty() {
        let bundle = BASBundle<TestItem>(items: [])
        XCTAssertTrue(bundle.metadata.isEmpty)
        XCTAssertNil(
            bundle.metadataValue(forKey: "missing"))
    }

    // MARK: - Replay determinism

    func testTwoBundlesWithSameInputsAreEqual() {
        let date = Date(timeIntervalSince1970: 0)
        let a = BASBundle<TestItem>(
            bundleID: "x", schemaVersion: "1.0.0",
            items: [TestItem(value: "y")],
            recordedAt: date)
        let b = BASBundle<TestItem>(
            bundleID: "x", schemaVersion: "1.0.0",
            items: [TestItem(value: "y")],
            recordedAt: date)
        XCTAssertEqual(a, b,
            "M960:same inputs → equal bundles (M892)")
    }

    func testEncodedJSONByteStable() throws {
        let bundle = BASBundle<TestItem>(
            bundleID: "x", schemaVersion: "1.0.0",
            items: [TestItem(value: "y")],
            recordedAt: Date(timeIntervalSince1970: 0))
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let d1 = try encoder.encode(bundle)
        let d2 = try encoder.encode(bundle)
        XCTAssertEqual(d1, d2)
    }
}
