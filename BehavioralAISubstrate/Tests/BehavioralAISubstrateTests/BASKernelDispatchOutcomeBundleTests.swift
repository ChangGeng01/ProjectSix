// MARK: - BASKernelDispatchOutcomeBundleTests
// chapter 四百七十六 / M1281
//
// PROOF that the FIRST real BASBundle<Item> typealias
// migration works end-to-end:
//   - typealias resolves to BASBundle<...>
//   - construction via items: [...] convention
//   - convenience accessors count + ratio correctly
//   - Codable round-trip stable
//   - chapter 三百九二 replay-determinism preserved

import XCTest
@testable import BASHostKit
@testable import BASRuntimeCore

final class BASKernelDispatchOutcomeBundleTests:
    XCTestCase
{

    // MARK: - Typealias resolves

    func testTypealiasResolvesToBASBundle() {
        let bundle: BASKernelDispatchOutcomeBundle =
            BASBundle(items: [])
        // Compile-time check + runtime sanity
        XCTAssertEqual(bundle.count, 0)
        XCTAssertTrue(bundle.isEmpty)
    }

    // MARK: - Construction + accessors

    func testBundleCountsDispatchedAndFallbacks() {
        let items: [
            BASKernelDispatchOutcomeBundleItem] = [
            .init(
                stageRawValue: "stage-a-power-clock",
                outcome: .dispatched,
                sequenceIndex: 0),
            .init(
                stageRawValue: "stage-c-decompose-l7-mirror",
                outcome: .dispatched,
                sequenceIndex: 1),
            .init(
                stageRawValue: "stage-h-risk-l11",
                outcome: .fallbackNoKey,
                sequenceIndex: 2),
            .init(
                stageRawValue: "stage-k-render-l12",
                outcome: .fallbackNoKernel,
                sequenceIndex: 3)
        ]
        let bundle = BASKernelDispatchOutcomeBundle(
            items: items)
        XCTAssertEqual(bundle.count, 4)
        XCTAssertEqual(bundle.dispatchedCount, 2)
        XCTAssertEqual(bundle.fallbackCount, 2)
        XCTAssertEqual(
            bundle.dispatchedRatio, 0.5,
            accuracy: 0.0001)
        XCTAssertEqual(
            bundle.count(of: .fallbackNoKey), 1)
        XCTAssertEqual(
            bundle.count(of: .fallbackNoKernel), 1)
        XCTAssertEqual(
            bundle.count(of: .fallbackKernelError), 0)
    }

    // MARK: - Empty bundle accessors

    func testEmptyBundleHasZeroRatio() {
        let bundle = BASKernelDispatchOutcomeBundle(
            items: [])
        XCTAssertEqual(bundle.dispatchedCount, 0)
        XCTAssertEqual(bundle.fallbackCount, 0)
        XCTAssertEqual(bundle.dispatchedRatio, 0,
            "empty bundle returns 0,not NaN")
    }

    // MARK: - Codable round trip

    func testBundleRoundTripsViaJSON() throws {
        let original = BASKernelDispatchOutcomeBundle(
            bundleID: "test-bundle",
            schemaVersion: "1.0.0",
            items: [
                .init(
                    stageRawValue: "stage-a",
                    outcome: .dispatched,
                    sequenceIndex: 0),
                .init(
                    stageRawValue: "stage-b",
                    outcome: .fallbackKernelError,
                    sequenceIndex: 1)
            ],
            metadata: ["turn-id": "abc-123"],
            recordedAt: Date(timeIntervalSince1970: 1000))
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(original)
        let decoded = try JSONDecoder().decode(
            BASKernelDispatchOutcomeBundle.self,
            from: data)
        XCTAssertEqual(decoded, original,
            "Codable round-trip must preserve all" +
            " fields (chapter 三百九二)")
    }

    // MARK: - Sequence ordering preserved

    func testItemSequenceIndicesPreservedAcrossAppend() {
        var bundle = BASKernelDispatchOutcomeBundle(
            items: [])
        for i in 0..<5 {
            bundle = bundle.appending(item: .init(
                stageRawValue: "stage-\(i)",
                outcome: .dispatched,
                sequenceIndex: i))
        }
        for (idx, item) in bundle.items.enumerated() {
            XCTAssertEqual(item.sequenceIndex, idx,
                "sequence indices must preserve order")
        }
    }
}
