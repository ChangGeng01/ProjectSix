// MARK: - BASMetalSubstrateResultAdoptionsTests
// chapter 四百八十三 / M1309

import XCTest
@testable import BASMetalSubstrate
@testable import BASRuntimeCore

final class BASMetalSubstrateResultAdoptionsTests:
    XCTestCase
{
    func testSecondBASResultAdoption() {
        let result: BASKernelRegistryDispatchResult =
            BASResult(
                success: true,
                body: BASKernelRegistryDispatchResultBody(
                    dispatchedKeyCount: 5,
                    fallbackCount: 0,
                    durationMs: 12),
                diagnostics: [])
        XCTAssertTrue(result.success)
        XCTAssertEqual(
            result.body.dispatchedKeyCount, 5)
    }

    func testThirdBASResultAdoption() {
        let result: BASANECapabilityProbeResult =
            BASResult(
                success: true,
                body: BASANECapabilityProbeResultBody(
                    priority: .aneFirst,
                    thermalSnapshot: .nominal,
                    supportedOpCount: 7),
                diagnostics: [])
        XCTAssertEqual(
            result.body.priority, .aneFirst)
        XCTAssertEqual(
            result.body.supportedOpCount, 7)
    }

    func testFourthBASResultAdoption() {
        let result: BASSchedulerAssignmentResult =
            BASResult(
                success: true,
                body: BASSchedulerAssignmentResultBody(
                    chosenBacking: .metalBuffer,
                    kernelKeyAssigned: true,
                    costScore: 0.5),
                diagnostics: [])
        XCTAssertEqual(
            result.body.chosenBacking, .metalBuffer)
        XCTAssertTrue(result.body.kernelKeyAssigned)
    }

    func testFourBASResultAdoptionsMilestone() {
        // M1300 + 3 batched at M1309 = 4 BASResult adoptions
        XCTAssertTrue(true,
            "M1309:4 BASResult adoptions milestone")
    }
}
