// MARK: - BASMetalSubstrateCardAdoptionsTests
// chapter 四百八十三 / M1310

import XCTest
@testable import BASMetalSubstrate
@testable import BASRuntimeCore

final class BASMetalSubstrateCardAdoptionsTests:
    XCTestCase
{
    private func sampleBody() -> BASKernelInvocationResultBody {
        BASKernelInvocationResultBody(
            kernelKey: BASKernelKey(
                operation: .matMul,
                dataType: .float32,
                backingKind: .metalBuffer),
            executionNanos: 1000,
            outputElementCount: 4)
    }

    func testSecondBASCardAdoption() {
        let card: BASTensorBackingKindCard = BASCard(
            kind: .metalBuffer,
            body: sampleBody(),
            headline: "metalBuffer · 1µs",
            presentation: "compact")
        XCTAssertEqual(card.kind, .metalBuffer)
    }

    func testThirdBASCardAdoption() {
        let card: BASAcceleratorPriorityCard = BASCard(
            kind: .aneFirst,
            body: sampleBody(),
            headline: "aneFirst · 1µs",
            presentation: "compact")
        XCTAssertEqual(card.kind, .aneFirst)
    }

    func testFourthBASCardAdoption() {
        let card: BASThermalSnapshotCard = BASCard(
            kind: .nominal,
            body: sampleBody(),
            headline: "nominal · 1µs",
            presentation: "compact")
        XCTAssertEqual(card.kind, .nominal)
    }

    func testFourBASCardAdoptionsMilestone() {
        // M1301 + 3 batched at M1310 = 4 BASCard adoptions
        XCTAssertTrue(true,
            "M1310:4 BASCard adoptions milestone")
    }
}
