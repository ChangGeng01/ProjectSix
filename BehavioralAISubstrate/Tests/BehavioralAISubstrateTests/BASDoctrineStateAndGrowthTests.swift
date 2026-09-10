// chapter 九百四十七 / M3440 — Foundation.Process unavailable on iOS
#if os(macOS)
import XCTest
@testable import BASRuntimeCore

/// 四十八 — Doctrine B (频率论) + C (双速成长) typed reference
/// tests.
///
/// Doctrine pinned:
/// - 4 state update scopes (parameter / process / individual /
///   device) matching honesty-board 四十五.3 Doctrine B
/// - 5 growth velocities (immediate / fast / medium / slow /
///   veryLow) Comparable by rank
/// - Each `BASActor` maps to canonical scope (Doctrine B × D)
/// - Each scope maps to canonical velocity (Doctrine C)
/// - **Doctrine C invariant**: parameter-scope changes MUST
///   carry `.veryLow` exactly
final class BASDoctrineStateAndGrowthTests: XCTestCase {

    // MARK: - Cardinality

    func test_fourStateUpdateScopes() {
        XCTAssertEqual(
            BASStateUpdateScope.allCases.count, 4)
    }

    func test_fiveGrowthVelocities() {
        XCTAssertEqual(
            BASGrowthVelocity.allCases.count, 5)
    }

    // MARK: - Raw values

    func test_scopeRawValuesPinned() {
        XCTAssertEqual(
            BASStateUpdateScope.parameter.rawValue,
            "parameter")
        XCTAssertEqual(
            BASStateUpdateScope.process.rawValue, "process")
        XCTAssertEqual(
            BASStateUpdateScope.individual.rawValue,
            "individual")
        XCTAssertEqual(
            BASStateUpdateScope.device.rawValue, "device")
    }

    func test_velocityRawValuesPinned() {
        XCTAssertEqual(
            BASGrowthVelocity.immediate.rawValue, "immediate")
        XCTAssertEqual(
            BASGrowthVelocity.fast.rawValue, "fast")
        XCTAssertEqual(
            BASGrowthVelocity.medium.rawValue, "medium")
        XCTAssertEqual(
            BASGrowthVelocity.slow.rawValue, "slow")
        XCTAssertEqual(
            BASGrowthVelocity.veryLow.rawValue, "veryLow")
    }

    // MARK: - Velocity Comparable

    func test_velocityComparableByRank() {
        XCTAssertLessThan(
            BASGrowthVelocity.veryLow,
            BASGrowthVelocity.slow)
        XCTAssertLessThan(
            BASGrowthVelocity.slow,
            BASGrowthVelocity.medium)
        XCTAssertLessThan(
            BASGrowthVelocity.medium,
            BASGrowthVelocity.fast)
        XCTAssertLessThan(
            BASGrowthVelocity.fast,
            BASGrowthVelocity.immediate)
    }

    func test_velocityRanksPinned() {
        XCTAssertEqual(
            BASGrowthVelocity.veryLow.rank, 0)
        XCTAssertEqual(
            BASGrowthVelocity.immediate.rank, 4)
    }

    // MARK: - Actor → scope (Doctrine B × D)

    func test_neuralNetworkUpdateScopeIsParameter() {
        XCTAssertEqual(
            BASActor.neuralNetwork.canonicalUpdateScope,
            .parameter)
    }

    func test_secondBrainUpdateScopeIsProcess() {
        XCTAssertEqual(
            BASActor.secondBrain.canonicalUpdateScope,
            .process)
    }

    func test_hostUpdateScopeIsIndividual() {
        XCTAssertEqual(
            BASActor.host.canonicalUpdateScope,
            .individual)
    }

    func test_sdkUpdateScopeIsDevice() {
        XCTAssertEqual(
            BASActor.sdk.canonicalUpdateScope, .device)
    }

    func test_eachActorMapsToDistinctScope() {
        let scopes = BASActor.allCases.map(
            \.canonicalUpdateScope)
        XCTAssertEqual(Set(scopes).count, scopes.count)
    }

    // MARK: - Scope → velocity (Doctrine C)

    func test_parameterScopeFloorIsVeryLow() {
        XCTAssertEqual(
            BASStateUpdateScope.parameter
                .canonicalVelocity,
            .veryLow)
    }

    func test_processScopeFloorIsMedium() {
        XCTAssertEqual(
            BASStateUpdateScope.process.canonicalVelocity,
            .medium)
    }

    func test_individualScopeFloorIsFast() {
        XCTAssertEqual(
            BASStateUpdateScope.individual
                .canonicalVelocity,
            .fast)
    }

    func test_deviceScopeFloorIsImmediate() {
        XCTAssertEqual(
            BASStateUpdateScope.device.canonicalVelocity,
            .immediate)
    }

    // MARK: - Actor → velocity (composed)

    func test_neuralNetworkVelocityIsVeryLow() {
        XCTAssertEqual(
            BASActor.neuralNetwork.canonicalGrowthVelocity,
            .veryLow)
    }

    func test_hostVelocityIsFast() {
        XCTAssertEqual(
            BASActor.host.canonicalGrowthVelocity, .fast)
    }

    // MARK: - Doctrine C invariant — L2 changes MUST .veryLow

    func test_parameterScopeRequiresVeryLowExactly() {
        XCTAssertTrue(
            BASDoctrineCInvariant.permits(
                velocity: .veryLow, at: .parameter))
        // Anything faster than .veryLow at .parameter scope
        // violates Doctrine C — L2 weights cannot change at
        // immediate / fast / medium / slow tiers.
        for v in BASGrowthVelocity.allCases
            where v != .veryLow
        {
            XCTAssertFalse(
                BASDoctrineCInvariant.permits(
                    velocity: v, at: .parameter),
                "Doctrine C: parameter (L2) must require .veryLow exactly, but \(v.rawValue) was permitted")
        }
    }

    func test_processScopePermitsAnyVelocityAtOrBelowMedium() {
        // Process-scope changes can run at any velocity at or
        // below .medium (the canonical floor for process).
        XCTAssertTrue(
            BASDoctrineCInvariant.permits(
                velocity: .veryLow, at: .process))
        XCTAssertTrue(
            BASDoctrineCInvariant.permits(
                velocity: .slow, at: .process))
        XCTAssertTrue(
            BASDoctrineCInvariant.permits(
                velocity: .medium, at: .process))
        // Faster than canonical floor → violates.
        XCTAssertFalse(
            BASDoctrineCInvariant.permits(
                velocity: .fast, at: .process))
        XCTAssertFalse(
            BASDoctrineCInvariant.permits(
                velocity: .immediate, at: .process))
    }

    func test_deviceScopePermitsAnyVelocity() {
        // Device scope's floor is .immediate (the highest), so
        // everything at or below permits.
        for v in BASGrowthVelocity.allCases {
            XCTAssertTrue(
                BASDoctrineCInvariant.permits(
                    velocity: v, at: .device))
        }
    }

    // MARK: - Codable round-trip

    func test_scopeCodableRoundTrip() throws {
        for scope in BASStateUpdateScope.allCases {
            let data = try JSONEncoder().encode(scope)
            let decoded = try JSONDecoder().decode(
                BASStateUpdateScope.self, from: data)
            XCTAssertEqual(decoded, scope)
        }
    }

    func test_velocityCodableRoundTrip() throws {
        for v in BASGrowthVelocity.allCases {
            let data = try JSONEncoder().encode(v)
            let decoded = try JSONDecoder().decode(
                BASGrowthVelocity.self, from: data)
            XCTAssertEqual(decoded, v)
        }
    }
}

#endif