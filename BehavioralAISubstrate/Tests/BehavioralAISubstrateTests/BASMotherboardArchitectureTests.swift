import XCTest
@testable import BASRuntimeCore

/// 五十五 — motherboard architecture typed reference tests.
///
/// Doctrine pinned (manifesto v3 「底层母板」):
/// - 5 principles / 3 planes / 4 kernels / 8 buses / 3 vaults /
///   4 SDK APIs (cardinality typed)
/// - All cases distinct, raw values pinned
/// - Codable round-trip for every enum
/// - Plane assignment: each kernel belongs to exactly one plane;
///   4 kernels span all 3 planes
/// - Bus 跨 kernel: 至少 4 root bus 跨 ≥ 2 kernel (the
///   "八总线把这些内核连成一张网" doctrine)
/// - Vault planes cover sovereign + state (snapshot ark in
///   sovereign, two vaults in state)
/// - SDK API exposure: union over 4 APIs covers all 4 kernels
final class BASMotherboardArchitectureTests: XCTestCase {

    // MARK: - Cardinality

    func test_principleHasFiveCases() {
        XCTAssertEqual(
            BASMotherboardPrinciple.allCases.count, 5)
    }

    func test_planeHasThreeCases() {
        XCTAssertEqual(
            BASMotherboardPlane.allCases.count, 3)
    }

    func test_kernelHasFourCases() {
        XCTAssertEqual(
            BASMotherboardKernel.allCases.count, 4)
    }

    func test_busHasEightCases() {
        XCTAssertEqual(
            BASMotherboardBus.allCases.count, 8)
    }

    func test_vaultHasThreeCases() {
        XCTAssertEqual(
            BASMotherboardVault.allCases.count, 3)
    }

    func test_sdkAPIHasFourCases() {
        XCTAssertEqual(
            BASMotherboardSDKAPI.allCases.count, 4)
    }

    // MARK: - Distinctness

    func test_allEnumCasesAreDistinct() {
        XCTAssertEqual(
            Set(
                BASMotherboardPrinciple.allCases.map(
                    \.rawValue)
            ).count,
            BASMotherboardPrinciple.allCases.count)
        XCTAssertEqual(
            Set(
                BASMotherboardPlane.allCases.map(\.rawValue)
            ).count,
            BASMotherboardPlane.allCases.count)
        XCTAssertEqual(
            Set(
                BASMotherboardKernel.allCases.map(\.rawValue)
            ).count,
            BASMotherboardKernel.allCases.count)
        XCTAssertEqual(
            Set(
                BASMotherboardBus.allCases.map(\.rawValue)
            ).count,
            BASMotherboardBus.allCases.count)
        XCTAssertEqual(
            Set(
                BASMotherboardVault.allCases.map(\.rawValue)
            ).count,
            BASMotherboardVault.allCases.count)
        XCTAssertEqual(
            Set(
                BASMotherboardSDKAPI.allCases.map(\.rawValue)
            ).count,
            BASMotherboardSDKAPI.allCases.count)
    }

    // MARK: - Raw value stability

    func test_principleRawValuesPinned() {
        XCTAssertEqual(
            BASMotherboardPrinciple
                .sovereigntyOverComputation.rawValue,
            "sovereigntyOverComputation")
        XCTAssertEqual(
            BASMotherboardPrinciple
                .typedStateOverPrompt.rawValue,
            "typedStateOverPrompt")
        XCTAssertEqual(
            BASMotherboardPrinciple
                .eventSourcingDefault.rawValue,
            "eventSourcingDefault")
        XCTAssertEqual(
            BASMotherboardPrinciple.capabilityTokens.rawValue,
            "capabilityTokens")
        XCTAssertEqual(
            BASMotherboardPrinciple
                .deleteRollbackRebootFirstClass.rawValue,
            "deleteRollbackRebootFirstClass")
    }

    func test_planeRawValuesPinned() {
        XCTAssertEqual(
            BASMotherboardPlane.sovereign.rawValue,
            "sovereign")
        XCTAssertEqual(
            BASMotherboardPlane.state.rawValue, "state")
        XCTAssertEqual(
            BASMotherboardPlane.compute.rawValue, "compute")
    }

    func test_kernelRawValuesPinned() {
        XCTAssertEqual(
            BASMotherboardKernel.sovereignMicrokernel.rawValue,
            "sovereignMicrokernel")
        XCTAssertEqual(
            BASMotherboardKernel.leaseAndLife.rawValue,
            "leaseAndLife")
        XCTAssertEqual(
            BASMotherboardKernel.neuralOrganRuntime.rawValue,
            "neuralOrganRuntime")
        XCTAssertEqual(
            BASMotherboardKernel
                .stateAndEvolutionGraph.rawValue,
            "stateAndEvolutionGraph")
    }

    func test_busRawValuesPinned() {
        XCTAssertEqual(
            BASMotherboardBus.lease.rawValue, "lease")
        XCTAssertEqual(
            BASMotherboardBus.worldHost.rawValue, "worldHost")
        XCTAssertEqual(
            BASMotherboardBus.situation.rawValue, "situation")
        XCTAssertEqual(
            BASMotherboardBus.cognitiveFrame.rawValue,
            "cognitiveFrame")
        XCTAssertEqual(
            BASMotherboardBus.memory.rawValue, "memory")
        XCTAssertEqual(
            BASMotherboardBus.frontier.rawValue, "frontier")
        XCTAssertEqual(
            BASMotherboardBus.riskPermit.rawValue,
            "riskPermit")
        XCTAssertEqual(
            BASMotherboardBus.versionAudit.rawValue,
            "versionAudit")
    }

    func test_vaultRawValuesPinned() {
        XCTAssertEqual(
            BASMotherboardVault.worldPriorVault.rawValue,
            "worldPriorVault")
        XCTAssertEqual(
            BASMotherboardVault.hostConstitutionVault.rawValue,
            "hostConstitutionVault")
        XCTAssertEqual(
            BASMotherboardVault.snapshotArk.rawValue,
            "snapshotArk")
    }

    func test_sdkAPIRawValuesPinned() {
        XCTAssertEqual(
            BASMotherboardSDKAPI.runtime.rawValue, "runtime")
        XCTAssertEqual(
            BASMotherboardSDKAPI.host.rawValue, "host")
        XCTAssertEqual(
            BASMotherboardSDKAPI.capability.rawValue,
            "capability")
        XCTAssertEqual(
            BASMotherboardSDKAPI.auditAndVersion.rawValue,
            "auditAndVersion")
    }

    // MARK: - Codable round-trip

    func test_principleCodableRoundTrip() throws {
        for value in BASMotherboardPrinciple.allCases {
            let data = try JSONEncoder().encode(value)
            let decoded = try JSONDecoder().decode(
                BASMotherboardPrinciple.self, from: data)
            XCTAssertEqual(decoded, value)
        }
    }

    func test_planeCodableRoundTrip() throws {
        for value in BASMotherboardPlane.allCases {
            let data = try JSONEncoder().encode(value)
            let decoded = try JSONDecoder().decode(
                BASMotherboardPlane.self, from: data)
            XCTAssertEqual(decoded, value)
        }
    }

    func test_kernelCodableRoundTrip() throws {
        for value in BASMotherboardKernel.allCases {
            let data = try JSONEncoder().encode(value)
            let decoded = try JSONDecoder().decode(
                BASMotherboardKernel.self, from: data)
            XCTAssertEqual(decoded, value)
        }
    }

    func test_busCodableRoundTrip() throws {
        for value in BASMotherboardBus.allCases {
            let data = try JSONEncoder().encode(value)
            let decoded = try JSONDecoder().decode(
                BASMotherboardBus.self, from: data)
            XCTAssertEqual(decoded, value)
        }
    }

    func test_vaultCodableRoundTrip() throws {
        for value in BASMotherboardVault.allCases {
            let data = try JSONEncoder().encode(value)
            let decoded = try JSONDecoder().decode(
                BASMotherboardVault.self, from: data)
            XCTAssertEqual(decoded, value)
        }
    }

    func test_sdkAPICodableRoundTrip() throws {
        for value in BASMotherboardSDKAPI.allCases {
            let data = try JSONEncoder().encode(value)
            let decoded = try JSONDecoder().decode(
                BASMotherboardSDKAPI.self, from: data)
            XCTAssertEqual(decoded, value)
        }
    }

    // MARK: - Plane assignment

    func test_eachKernelBelongsToOnePlane() {
        // Function: every kernel produces exactly one plane.
        // (Tested by virtue of `containingPlane` being non-
        // optional; here we assert the partition is exhaustive.)
        var byPlane: [BASMotherboardPlane: Int] = [:]
        for kernel in BASMotherboardKernel.allCases {
            byPlane[
                kernel.containingPlane, default: 0
            ] += 1
        }
        XCTAssertEqual(byPlane[.sovereign], 1)
        XCTAssertEqual(byPlane[.state], 1)
        XCTAssertEqual(byPlane[.compute], 2)
    }

    func test_fourKernelsCoverAllThreePlanes() {
        let coveredPlanes = Set(
            BASMotherboardKernel.allCases.map(
                \.containingPlane))
        XCTAssertEqual(
            coveredPlanes,
            Set(BASMotherboardPlane.allCases))
    }

    func test_planeKernelInverseIsConsistent() {
        for plane in BASMotherboardPlane.allCases {
            for kernel in plane.kernels {
                XCTAssertEqual(
                    kernel.containingPlane, plane,
                    "plane.kernels must invert " +
                    "kernel.containingPlane")
            }
        }
        // Total kernel count via inverse aggregation = 4.
        let total = BASMotherboardPlane.allCases.reduce(0) {
            $0 + $1.kernels.count
        }
        XCTAssertEqual(
            total, BASMotherboardKernel.allCases.count)
    }

    // MARK: - Bus → kernel network

    func test_everyBusCrossesAtLeastOneKernel() {
        for bus in BASMotherboardBus.allCases {
            XCTAssertFalse(
                bus.crossingKernels.isEmpty,
                "bus \(bus.rawValue) must cross ≥ 1 kernel")
        }
    }

    func test_atLeastFourBusesCrossTwoOrMoreKernels() {
        // Doctrine: 八总线把这些内核连成一张网. Most buses
        // are connective tissue between kernels (≥ 2). Pin a
        // floor of 4 of 8 to ensure the network metaphor is
        // physically expressed.
        let crossKernel = BASMotherboardBus.allCases.filter {
            $0.crossingKernels.count >= 2
        }
        XCTAssertGreaterThanOrEqual(
            crossKernel.count, 4,
            "at least 4 of 8 buses must cross ≥ 2 kernels " +
            "(network doctrine)")
    }

    func test_busKernelUnionCoversAllFourKernels() {
        // Every kernel must be reachable through some bus —
        // otherwise there's an island.
        var union: Set<BASMotherboardKernel> = []
        for bus in BASMotherboardBus.allCases {
            union.formUnion(bus.crossingKernels)
        }
        XCTAssertEqual(
            union, Set(BASMotherboardKernel.allCases))
    }

    // MARK: - Vaults

    func test_vaultPlanesCoverSovereignAndState() {
        let planes = Set(
            BASMotherboardVault.allCases.map(
                \.containingPlane))
        XCTAssertTrue(planes.contains(.sovereign))
        XCTAssertTrue(planes.contains(.state))
        // Compute plane has no vault — vaults are persistent
        // typed objects, not compute infrastructure.
        XCTAssertFalse(planes.contains(.compute))
    }

    func test_snapshotArkIsSovereign() {
        XCTAssertEqual(
            BASMotherboardVault.snapshotArk
                .containingPlane, .sovereign)
    }

    func test_worldPriorAndHostConstitutionAreState() {
        XCTAssertEqual(
            BASMotherboardVault.worldPriorVault
                .containingPlane, .state)
        XCTAssertEqual(
            BASMotherboardVault.hostConstitutionVault
                .containingPlane, .state)
    }

    // MARK: - SDK API exposure

    func test_sdkAPIUnionExposesAllKernels() {
        // Union over 4 SDK APIs MUST cover all 4 kernels
        // (every kernel is reachable from outside the SDK).
        var union: Set<BASMotherboardKernel> = []
        for api in BASMotherboardSDKAPI.allCases {
            union.formUnion(api.exposedKernels)
        }
        XCTAssertEqual(
            union, Set(BASMotherboardKernel.allCases))
    }

    func test_capabilityAPIIsSovereignOnly() {
        // Capability tokens are issued by sovereign only.
        XCTAssertEqual(
            BASMotherboardSDKAPI.capability.exposedKernels,
            [.sovereignMicrokernel])
    }

    func test_runtimeAPIDrivesComputeAndState() {
        // Turn execution drives lease + organ + state.
        let exposed = BASMotherboardSDKAPI.runtime
            .exposedKernels
        XCTAssertTrue(exposed.contains(.leaseAndLife))
        XCTAssertTrue(exposed.contains(.neuralOrganRuntime))
        XCTAssertTrue(
            exposed.contains(.stateAndEvolutionGraph))
    }
}
