import XCTest
@testable import BASLeaseLife
@testable import BASRuntimeCore

/// M218 — coverage for `BASDeviceRouting.recommend(...)`.
final class BASDeviceRoutingTests: XCTestCase {

    private typealias Capability = BASDeviceRouting.Capability
    private typealias Role = BASDeviceRouting.Role

    private func recommend(
        role: Role = .scout,
        thermal: BASThermalGuardLevel = .nominal,
        precision: BASRuntimePrecisionProfile = .balanced,
        available: Set<Capability> = [.cpu, .gpu, .ane]
    ) -> BASDeviceRoute {
        BASDeviceRouting.recommend(
            role: role,
            thermalGuard: thermal,
            precisionProfile: precision,
            available: available)
    }

    // MARK: - 1. Thermal emergency forces CPU regardless

    func testEmergencyThermalForcesCPUForScout() {
        XCTAssertEqual(
            recommend(role: .scout, thermal: .emergency),
            .scoutCPU)
    }

    func testEmergencyThermalForcesCPUForCore() {
        // Even with NPU available + .full precision, emergency
        // wins.
        XCTAssertEqual(
            recommend(
                role: .core,
                thermal: .emergency,
                precision: .full,
                available: [.cpu, .gpu, .ane]),
            .scoutCPU,
            "emergency thermal MUST force scoutCPU even on core " +
            "+ ANE + full precision")
    }

    // MARK: - 2. Throttle thermal disables NPU

    func testThrottleThermalDisablesNPU() {
        // Even with ANE + protected, throttle must not pick NPU.
        let route = recommend(
            role: .core,
            thermal: .throttle,
            precision: .protected,
            available: [.cpu, .gpu, .ane])
        XCTAssertNotEqual(
            route, .coreNPU,
            "throttle thermal MUST NOT pick NPU; got \(route)")
    }

    func testThrottleThermalAllowsGPU() {
        // Core + throttle + GPU available → coreGPU.
        XCTAssertEqual(
            recommend(
                role: .core,
                thermal: .throttle,
                precision: .balanced,
                available: [.cpu, .gpu]),
            .coreGPU)
    }

    // MARK: - 3. Hardware availability constrains choice

    func testNoGPUNoNPUForcesCPUForScout() {
        XCTAssertEqual(
            recommend(
                role: .scout,
                thermal: .nominal,
                precision: .balanced,
                available: [.cpu]),
            .scoutCPU)
    }

    func testNoNPUWithGPUFallsToGPU() {
        XCTAssertEqual(
            recommend(
                role: .scout,
                thermal: .nominal,
                precision: .protected,  // would normally prefer NPU
                available: [.cpu, .gpu]),
            .scoutGPU,
            "no ANE → protected scout falls to GPU")
    }

    func testCoreWithoutGPUNorNPUFallsToHybridLocal() {
        // Core can't run on CPU usefully; degrade to hybridLocal
        // marker so the loop's L11 downgrade logic kicks in.
        XCTAssertEqual(
            recommend(
                role: .core,
                thermal: .nominal,
                precision: .balanced,
                available: [.cpu]),
            .hybridLocal)
    }

    // MARK: - 4. Precision floor + role

    func testProtectedCoreOnANEPicksCoreNPU() {
        XCTAssertEqual(
            recommend(
                role: .core,
                thermal: .nominal,
                precision: .protected,
                available: [.cpu, .gpu, .ane]),
            .coreNPU)
    }

    func testFullCoreOnANEPicksCoreNPU() {
        XCTAssertEqual(
            recommend(
                role: .core,
                thermal: .nominal,
                precision: .full,
                available: [.cpu, .gpu, .ane]),
            .coreNPU)
    }

    func testBalancedScoutOnANEPicksScoutNPU() {
        XCTAssertEqual(
            recommend(
                role: .scout,
                thermal: .nominal,
                precision: .balanced,
                available: [.cpu, .gpu, .ane]),
            .scoutNPU)
    }

    func testMinimalScoutPrefersGPUOverNPU() {
        // Minimal precision is fine on GPU; no need to spin up
        // ANE for low-quality output.
        XCTAssertEqual(
            recommend(
                role: .scout,
                thermal: .nominal,
                precision: .minimal,
                available: [.cpu, .gpu, .ane]),
            .scoutGPU)
    }

    // MARK: - 5. Watch thermal still allows full hardware

    func testWatchThermalAllowsNPUWithProtected() {
        // Watch is the second-lightest thermal level (between
        // nominal and throttle); NPU still allowed.
        XCTAssertEqual(
            recommend(
                role: .core,
                thermal: .watch,
                precision: .protected,
                available: [.cpu, .gpu, .ane]),
            .coreNPU)
    }

    // MARK: - 6. Determinism: identical inputs → identical output

    func testRecommendIsDeterministic() {
        let inputs: [
            (Role, BASThermalGuardLevel,
             BASRuntimePrecisionProfile, Set<Capability>)
        ] = [
            (.scout, .nominal, .balanced, [.cpu, .gpu, .ane]),
            (.core, .throttle, .protected, [.cpu, .gpu]),
            (.scout, .emergency, .full, [.cpu, .gpu, .ane])
        ]
        for (role, thermal, precision, avail) in inputs {
            let r1 = BASDeviceRouting.recommend(
                role: role,
                thermalGuard: thermal,
                precisionProfile: precision,
                available: avail)
            let r2 = BASDeviceRouting.recommend(
                role: role,
                thermalGuard: thermal,
                precisionProfile: precision,
                available: avail)
            XCTAssertEqual(
                r1, r2,
                "deterministic for input (\(role), \(thermal), " +
                "\(precision), \(avail))")
        }
    }

    // MARK: - 7. Full matrix sanity sweep

    /// Sweep every combination of role × thermalGuard ×
    /// precisionProfile × capability-set and ensure
    /// `recommend(...)` never crashes and always returns a valid
    /// BASDeviceRoute. This is a structural smoke test —
    /// pinning the per-cell semantics is covered by the targeted
    /// tests above.
    func testFullMatrixSweepNeverCrashesAndReturnsValidRoute() {
        let validCases = Set(BASDeviceRoute.allCases)
        let roles: [Role] = [.scout, .core]
        let thermals: [BASThermalGuardLevel] =
            BASThermalGuardLevel.allCases
        let precisions: [BASRuntimePrecisionProfile] =
            BASRuntimePrecisionProfile.allCases
        let capabilitySets: [Set<Capability>] = [
            [.cpu],
            [.cpu, .gpu],
            [.cpu, .ane],
            [.cpu, .gpu, .ane]
        ]

        var coverage = Set<BASDeviceRoute>()
        for role in roles {
            for thermal in thermals {
                for precision in precisions {
                    for caps in capabilitySets {
                        let route = BASDeviceRouting.recommend(
                            role: role,
                            thermalGuard: thermal,
                            precisionProfile: precision,
                            available: caps)
                        XCTAssertTrue(
                            validCases.contains(route),
                            "route \(route) not in allCases for " +
                            "(\(role), \(thermal), \(precision), " +
                            "\(caps))")
                        coverage.insert(route)
                    }
                }
            }
        }
        // The sweep should cover at least 4 distinct routes
        // (CPU + GPU/NPU per role + hybridLocal degenerate path).
        XCTAssertGreaterThanOrEqual(
            coverage.count, 4,
            "matrix sweep should reach ≥ 4 distinct routes; " +
            "got \(coverage)")
    }
}
