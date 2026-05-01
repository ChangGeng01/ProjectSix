import XCTest
@testable import BASRuntimeCore

/// 六十二.3 — four-kernel duty enum tests.
final class BASMotherboardKernelDutyTests: XCTestCase {

    func test_sovereignHasEightDuties() {
        XCTAssertEqual(
            BASMotherboardSovereignDuty.allCases.count, 8)
    }

    func test_lifeHasNineDuties() {
        XCTAssertEqual(
            BASMotherboardLifeDuty.allCases.count, 9)
    }

    func test_organHasEightDuties() {
        XCTAssertEqual(
            BASMotherboardOrganDuty.allCases.count, 8)
    }

    func test_stateGraphHasSixDuties() {
        XCTAssertEqual(
            BASMotherboardStateGraphDuty.allCases.count, 6)
    }

    func test_lifeEmissionHasTwoCases() {
        XCTAssertEqual(
            BASMotherboardLifeEmission.allCases.count, 2)
        XCTAssertEqual(
            Set(BASMotherboardLifeEmission.allCases),
            [.budgetFrame, .runLease])
    }

    func test_kernelDutyCounts() {
        XCTAssertEqual(
            BASMotherboardKernel
                .sovereignMicrokernel.dutyCount, 8)
        XCTAssertEqual(
            BASMotherboardKernel.leaseAndLife.dutyCount,
            9)
        XCTAssertEqual(
            BASMotherboardKernel
                .neuralOrganRuntime.dutyCount, 8)
        XCTAssertEqual(
            BASMotherboardKernel
                .stateAndEvolutionGraph.dutyCount, 6)
    }

    func test_sovereignDutiesContainEmergencyOps() {
        XCTAssertTrue(
            BASMotherboardSovereignDuty.allCases.contains(
                .emergencyOps))
        XCTAssertTrue(
            BASMotherboardSovereignDuty.allCases.contains(
                .auditLedger))
    }

    func test_lifeDutiesIncludeRunLease() {
        XCTAssertTrue(
            BASMotherboardLifeDuty.allCases.contains(
                .runLease))
        XCTAssertTrue(
            BASMotherboardLifeDuty.allCases.contains(
                .thermalProtection))
    }

    func test_organDutiesIncludeThoughtFold() {
        XCTAssertTrue(
            BASMotherboardOrganDuty.allCases.contains(
                .thoughtFold))
        XCTAssertTrue(
            BASMotherboardOrganDuty.allCases.contains(
                .checkpointResume))
    }

    func test_stateGraphIncludesShadowTrial() {
        XCTAssertTrue(
            BASMotherboardStateGraphDuty.allCases.contains(
                .shadowTrial))
        XCTAssertTrue(
            BASMotherboardStateGraphDuty.allCases.contains(
                .deletionCascade))
    }

    func test_dutyCardinalityTotalThirtyOne() {
        let total = BASMotherboardKernel.allCases.reduce(0) {
            $0 + $1.dutyCount
        }
        XCTAssertEqual(total, 31,
            "8 + 9 + 8 + 6 = 31 typed duties total")
    }

    func test_dutyCodableRoundTrips() throws {
        for duty in BASMotherboardSovereignDuty.allCases {
            let data = try JSONEncoder().encode(duty)
            let decoded = try JSONDecoder().decode(
                BASMotherboardSovereignDuty.self, from: data)
            XCTAssertEqual(decoded, duty)
        }
        for duty in BASMotherboardLifeDuty.allCases {
            let data = try JSONEncoder().encode(duty)
            let decoded = try JSONDecoder().decode(
                BASMotherboardLifeDuty.self, from: data)
            XCTAssertEqual(decoded, duty)
        }
        for duty in BASMotherboardOrganDuty.allCases {
            let data = try JSONEncoder().encode(duty)
            let decoded = try JSONDecoder().decode(
                BASMotherboardOrganDuty.self, from: data)
            XCTAssertEqual(decoded, duty)
        }
        for duty in BASMotherboardStateGraphDuty.allCases {
            let data = try JSONEncoder().encode(duty)
            let decoded = try JSONDecoder().decode(
                BASMotherboardStateGraphDuty.self, from: data)
            XCTAssertEqual(decoded, duty)
        }
    }
}
