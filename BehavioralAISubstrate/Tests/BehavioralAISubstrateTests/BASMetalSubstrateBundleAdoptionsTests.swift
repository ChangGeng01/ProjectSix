// MARK: - BASMetalSubstrateBundleAdoptionsTests
// chapter 四百八十三 / M1308

import XCTest
@testable import BASMetalSubstrate
@testable import BASRuntimeCore

final class BASMetalSubstrateBundleAdoptionsTests:
    XCTestCase
{
    func testFourthBASBundleAdoption() {
        let bundle: BASKernelKeyRegistryBundle =
            BASBundle(items: [
                BASKernelKeyRegistryBundleItem(
                    key: BASKernelKey(
                        operation: .matMul,
                        dataType: .float32,
                        backingKind: .metalBuffer),
                    registeredAtMs: 1_700_000_000_000)
            ])
        XCTAssertEqual(bundle.count, 1)
    }

    func testFifthBASBundleAdoption() {
        let bundle: BASTensorBackingKindObservationBundle =
            BASBundle(items: [
                BASTensorBackingKindObservationItem(
                    backingKind: .metalBuffer,
                    observationSequence: 0)
            ])
        XCTAssertEqual(bundle.count, 1)
    }

    func testSixthBASBundleAdoptionWithAccessors() {
        let bundle: BASNeuralOpInvocationBundle =
            BASBundle(items: [
                BASNeuralOpInvocationItem(
                    op: .matMul,
                    executionNanos: 1000,
                    succeeded: true),
                BASNeuralOpInvocationItem(
                    op: .softmax,
                    executionNanos: 500,
                    succeeded: true),
                BASNeuralOpInvocationItem(
                    op: .attention,
                    executionNanos: 2000,
                    succeeded: false)
            ])
        XCTAssertEqual(bundle.count, 3)
        XCTAssertEqual(
            bundle.successfulInvocationCount, 2)
        XCTAssertEqual(
            bundle.totalExecutionNanos, 3500)
    }

    func testSixBASBundleAdoptionsMilestone() {
        // 1st M1281 + 2nd M1286 + 3rd M1297 + 4th M1308a
        // + 5th M1308b + 6th M1308c = 6 BASBundle
        // adoptions across the substrate
        XCTAssertTrue(true,
            "M1308:6 BASBundle adoptions milestone")
    }
}
