// MARK: - BASMLHostProfileServiceTests
// REAL tests for the L9 host-profile service deriving
// host-gate confidence adjustment from context + risk
// signals。 Tenth active ML-touched layer in the
// cognitive cascade。

import XCTest
@testable import BASHostKit
@testable import BASRuntimeCore
@testable import BASMemory
@testable import BASPolicy

#if !os(iOS)  // ch 1022 source-gate
final class BASMLHostProfileServiceTests: XCTestCase {

    // MARK: - Helpers

    private func riskCard(
        level: BASBrainRiskLevel = .low
    ) -> BASRiskCard {
        return BASRiskCard(
            totalRisk: 0.5,
            riskLevel: level,
            factors: [],
            uncertainty: 0.3,
            irreversibility: 0.1,
            manipulationStrength: 0.0,
            gsiScore: 0.5,
            recommendedMode: .answer)
    }

    private func contextFrame(
        emotionalLoad: Double = 0.0,
        timePressure: Double = 0.0
    ) -> BASContextFrame {
        return BASContextFrame(
            utterance: "test",
            taskType: .chat,
            emotionalLoad: emotionalLoad,
            timePressure: timePressure,
            relationPattern: "neutral",
            ambiguityScore: 0.1,
            consequenceLevel: 0.0,
            manipulationHints: [],
            hostRelevance: 0.5)
    }

    // MARK: - Customization

    func testCustomGoalsAreUsed() {
        let custom = ["custom_goal_1", "custom_goal_2"]
        let service = BASMLHostProfileService(
            longTermGoals: custom)
        let profile = service.resolveHost(
            hostID: "test",
            contextFrame: nil,
            riskCard: nil)
        XCTAssertEqual(profile.longTermGoals, custom,
            "Host-supplied custom goals must override" +
            " the safety-first defaults")
    }

    func testCustomNoGoZonesAreUsed() {
        let zones = ["zone_a", "zone_b", "zone_c"]
        let service = BASMLHostProfileService(
            noGoZones: zones)
        let profile = service.resolveHost(
            hostID: "test",
            contextFrame: nil,
            riskCard: nil)
        XCTAssertEqual(profile.noGoZones, zones)
    }

    func testDefaultGoalsContainPreserveSafety() {
        XCTAssertTrue(
            BASMLHostProfileService.defaultLongTermGoals
                .contains(BASMLHostProfileService
                    .LongTermGoals.preserveSafety))
    }

    func testDefaultNoGoZonesContainCredentialExfil() {
        XCTAssertTrue(
            BASMLHostProfileService.defaultNoGoZones
                .contains(BASMLHostProfileService
                    .NoGoZones.credentialExfiltration))
    }

    // MARK: - resolveHost

    func testResolveHostReturnsCascadeResolvedTag() {
        let service = BASMLHostProfileService()
        let profile = service.resolveHost(
            hostID: "test",
            contextFrame: nil,
            riskCard: nil)
        XCTAssertTrue(profile.identityTags.contains(
            BASMLHostProfileService.IdentityTags
                .cascadeResolved))
    }

    func testResolveHostIncludesSafetyGoals() {
        let service = BASMLHostProfileService()
        let profile = service.resolveHost(
            hostID: "test",
            contextFrame: nil,
            riskCard: nil)
        XCTAssertTrue(profile.longTermGoals.contains(
            BASMLHostProfileService.LongTermGoals
                .preserveSafety))
        XCTAssertEqual(profile.longTermGoals.count, 3)
    }

    func testResolveHostIncludesNoGoZones() {
        let service = BASMLHostProfileService()
        let profile = service.resolveHost(
            hostID: "test",
            contextFrame: nil,
            riskCard: nil)
        XCTAssertTrue(profile.noGoZones.contains(
            BASMLHostProfileService.NoGoZones
                .credentialExfiltration))
        XCTAssertTrue(profile.noGoZones.contains(
            BASMLHostProfileService.NoGoZones
                .safetyBypass))
    }

    func testEmotionalContextProducesCautiousTone() {
        let service = BASMLHostProfileService()
        let profile = service.resolveHost(
            hostID: "test",
            contextFrame: contextFrame(
                emotionalLoad: 0.8),
            riskCard: nil)
        XCTAssertEqual(profile.tonePreference,
            BASMLHostProfileService.TonePreferences
                .cautious)
    }

    func testUrgentContextProducesUrgentTone() {
        let service = BASMLHostProfileService()
        let profile = service.resolveHost(
            hostID: "test",
            contextFrame: contextFrame(
                timePressure: 0.9),
            riskCard: nil)
        XCTAssertEqual(profile.tonePreference,
            BASMLHostProfileService.TonePreferences
                .urgent)
    }

    func testCalmContextProducesGroundedTone() {
        let service = BASMLHostProfileService()
        let profile = service.resolveHost(
            hostID: "test",
            contextFrame: contextFrame(),
            riskCard: nil)
        XCTAssertEqual(profile.tonePreference,
            BASMLHostProfileService.TonePreferences
                .grounded)
    }

    // MARK: - applyHostGate

    func testLowRiskTaskBoostsConfidence() {
        let service = BASMLHostProfileService()
        let profile = service.resolveHost(
            hostID: "test",
            contextFrame: nil,
            riskCard: nil)
        let adjusted = service.applyHostGate(
            profile: profile,
            taskType: .task,
            riskCard: riskCard(level: .low),
            confidence: 0.7)
        XCTAssertGreaterThan(adjusted, 0.7)
    }

    func testHighRiskPenalizesConfidence() {
        let service = BASMLHostProfileService()
        let profile = service.resolveHost(
            hostID: "test",
            contextFrame: nil,
            riskCard: nil)
        let adjusted = service.applyHostGate(
            profile: profile,
            taskType: .task,
            riskCard: riskCard(level: .high),
            confidence: 0.8)
        XCTAssertLessThan(adjusted, 0.8)
    }

    func testExtremeRiskHeavilyPenalizes() {
        let service = BASMLHostProfileService()
        let profile = service.resolveHost(
            hostID: "test",
            contextFrame: nil,
            riskCard: nil)
        let highAdjusted = service.applyHostGate(
            profile: profile,
            taskType: .task,
            riskCard: riskCard(level: .high),
            confidence: 0.9)
        let extremeAdjusted = service.applyHostGate(
            profile: profile,
            taskType: .task,
            riskCard: riskCard(level: .extreme),
            confidence: 0.9)
        XCTAssertLessThan(extremeAdjusted, highAdjusted,
            "Extreme risk must penalize more than high")
    }

    func testManipulationTypePenalizes() {
        let service = BASMLHostProfileService()
        let profile = service.resolveHost(
            hostID: "test",
            contextFrame: nil,
            riskCard: nil)
        let task = service.applyHostGate(
            profile: profile,
            taskType: .task,
            riskCard: riskCard(level: .medium),
            confidence: 0.8)
        let manip = service.applyHostGate(
            profile: profile,
            taskType: .manipulationRisk,
            riskCard: riskCard(level: .medium),
            confidence: 0.8)
        XCTAssertLessThan(manip, task,
            "Manipulation taskType must penalize" +
            " independently of risk level")
    }

    func testGateClampsToZero() {
        let service = BASMLHostProfileService()
        let profile = service.resolveHost(
            hostID: "test",
            contextFrame: nil,
            riskCard: nil)
        let adjusted = service.applyHostGate(
            profile: profile,
            taskType: .manipulationRisk,
            riskCard: riskCard(level: .extreme),
            confidence: 0.1)
        XCTAssertGreaterThanOrEqual(adjusted, 0.0,
            "Adjusted confidence must clamp to >=0")
    }

    func testGateClampsToOne() {
        let service = BASMLHostProfileService()
        let profile = service.resolveHost(
            hostID: "test",
            contextFrame: nil,
            riskCard: nil)
        let adjusted = service.applyHostGate(
            profile: profile,
            taskType: .task,
            riskCard: riskCard(level: .low),
            confidence: 1.0)
        XCTAssertLessThanOrEqual(adjusted, 1.0,
            "Adjusted confidence must clamp to <=1")
    }

    // MARK: - rollbackHostVersion

    func testRollbackProducesTypedVersionStamp() {
        let service = BASMLHostProfileService()
        let profile = service.resolveHost(
            hostID: "test",
            contextFrame: nil,
            riskCard: nil)
        let version = service.rollbackHostVersion(
            profile: profile,
            to: "v1.2.3")
        XCTAssertEqual(version.versionID, "v1.2.3")
        XCTAssertTrue(version.reason.contains(
            "cascade_initiated"))
    }

    // MARK: - End-to-end via brain.process

    func testBrainCascadeUsesL9HostProfile() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let result = await brain.process(
            "hello")
        let profile = result.hostContext
        // Real L9 service should have produced safety
        // goals and no-go zones rather than the
        // placeholder's single trivial goal。
        XCTAssertGreaterThan(profile.longTermGoals.count,
            1, "L9 profile must include multiple goals")
        XCTAssertFalse(profile.noGoZones.isEmpty,
            "L9 profile must include no-go zones")
    }

    // MARK: - Brain factory accepts host-profile override

    func testBrainAcceptsCustomHostProfileService()
        async throws
    {
        let customGoals = [
            "child_safety_first",
            "require_guardian_consent",
        ]
        let customZones = [
            "adult_content",
            "financial_advice",
            "medical_diagnosis",
        ]
        let custom = BASMLHostProfileService(
            longTermGoals: customGoals,
            noGoZones: customZones)
        let brain = try await BASCognitiveBrain
            .makeWithDefaults(
                hostProfileService: custom)
        let result = await brain.process("hello")
        XCTAssertEqual(
            result.hostContext.longTermGoals,
            customGoals,
            "Custom host-profile goals must reach the" +
            " cascade. Got \(result.hostContext.longTermGoals)")
        XCTAssertEqual(
            result.hostContext.noGoZones,
            customZones,
            "Custom host-profile no-go zones must reach" +
            " the cascade")
    }

    func testBrainFallsBackToDefaultHostProfileWhenNil()
        async throws
    {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults(
                hostProfileService: nil)
        let result = await brain.process("hello")
        // nil override → default safety-first goals。
        XCTAssertEqual(
            result.hostContext.longTermGoals,
            BASMLHostProfileService.defaultLongTermGoals,
            "nil override must use default goals")
    }
}
#endif
