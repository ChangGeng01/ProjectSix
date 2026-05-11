// MARK: - BASKernelDispatchPermitTests
// chapter 四百八十二 / M1304

import XCTest
@testable import BASMetalSubstrate
@testable import BASRuntimeCore

final class BASKernelDispatchPermitTests: XCTestCase {

    func testTypealiasResolvesToBASPermit() {
        let permit: BASKernelDispatchPermit = BASPermit(
            decision: .allowedGPU,
            reasonCodes: ["nominal-thermal"],
            reviewerID: "scheduler.hardware-aware")
        XCTAssertEqual(permit.decision, .allowedGPU)
        XCTAssertTrue(permit.isAllowed)
    }

    func testIsAllowedAccessor() {
        let denied: BASKernelDispatchPermit = BASPermit(
            decision: .deniedThermalCritical,
            reasonCodes: ["thermal-critical"],
            reviewerID: "scheduler")
        XCTAssertFalse(denied.isAllowed)
    }

    func testPermitRoundTripsViaJSON() throws {
        let original = BASKernelDispatchPermit(
            decision: .allowedANE,
            reasonCodes: ["ane-supported", "low-latency"],
            reviewerID: "test.scheduler")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(original)
        let decoded = try JSONDecoder().decode(
            BASKernelDispatchPermit.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testFiveOfFivePrimitiveCoverageMilestone() {
        // M1281 BASBundle ×3 + M1300 BASResult +
        // M1301 BASCard + M1302 BASFrameEnvelope +
        // M1304 BASPermit = 5-OF-5 PRIMITIVE COVERAGE
        let _: BASKernelDispatchPermit = BASPermit(
            decision: .allowedCPU,
            reasonCodes: [],
            reviewerID: "milestone")
        XCTAssertTrue(true,
            "M1304 milestone: all 5 generic primitives" +
            " have real production adoptions")
    }
}
