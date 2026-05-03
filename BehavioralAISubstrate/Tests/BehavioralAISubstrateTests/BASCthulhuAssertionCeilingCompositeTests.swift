import XCTest
@testable import BASOrchestration
@testable import BASPolicy
@testable import BASWorldPrior

/// M445 (chapter 一百十七) — assertion-ceiling cap tests for L4
/// fog + L9 retention loop composite gate.
final class BASCthulhuAssertionCeilingCompositeTests: XCTestCase {

    // MARK: - Mapping helpers

    func testFogQualityToCeilingMapping() {
        XCTAssertEqual(
            BASCthulhuAssertionCeilingGate.fogQualityToCeiling(.partialGrasp),
            .provisional)
        XCTAssertEqual(
            BASCthulhuAssertionCeilingGate.fogQualityToCeiling(.provisionalNaming),
            .qualified)
        XCTAssertEqual(
            BASCthulhuAssertionCeilingGate.fogQualityToCeiling(.unnameable),
            .none)
    }

    func testRetentionLoopToCeilingMapping() {
        XCTAssertEqual(
            BASCthulhuAssertionCeilingGate.retentionLoopToCeiling(0.0),
            .none)
        XCTAssertEqual(
            BASCthulhuAssertionCeilingGate.retentionLoopToCeiling(0.25),
            .none)
        XCTAssertEqual(
            BASCthulhuAssertionCeilingGate.retentionLoopToCeiling(0.4),
            .metaOnly)
        XCTAssertEqual(
            BASCthulhuAssertionCeilingGate.retentionLoopToCeiling(0.5),
            .metaOnly)
        XCTAssertEqual(
            BASCthulhuAssertionCeilingGate.retentionLoopToCeiling(0.7),
            .qualified)
        XCTAssertEqual(
            BASCthulhuAssertionCeilingGate.retentionLoopToCeiling(0.75),
            .qualified)
        XCTAssertEqual(
            BASCthulhuAssertionCeilingGate.retentionLoopToCeiling(0.9),
            .provisional)
    }

    // MARK: - Cap behavior

    func testNoSourcesNoCap() {
        let permit = makePermit(assertionCeiling: "default")
        let decision = BASCthulhuAssertionCeilingGate.cap(
            permit: permit,
            ontologyFog: nil,
            retentionLoop: nil)
        XCTAssertFalse(decision.capped)
        XCTAssertEqual(decision.reasonCodes, [])
        XCTAssertFalse(decision.firedFog)
        XCTAssertFalse(decision.firedRetentionLoop)
        XCTAssertEqual(decision.permit, permit)
    }

    func testFogUnnameableCapsToNone() {
        let permit = makePermit(assertionCeiling: "default")
        let fog = BASOntologyFog(
            fogID: "fog-1",
            fogRegions: ["x"],
            nameableAnchors: [],
            unnameableMarks: ["x"],
            partialGraspQuality: .unnameable)
        let decision = BASCthulhuAssertionCeilingGate.cap(
            permit: permit,
            ontologyFog: fog,
            retentionLoop: nil)
        XCTAssertTrue(decision.capped)
        XCTAssertTrue(decision.firedFog)
        XCTAssertEqual(decision.permit.assertionCeiling, "none")
        XCTAssertTrue(decision.reasonCodes.contains {
            $0.contains("cthulhu-fog") && $0.contains(":to:none")
        })
    }

    func testRetentionLoopActiveCapsToMetaOnly() {
        let permit = makePermit(assertionCeiling: "default")
        let loop = BASUnknownRetentionLoop(
            loopID: "loop-1",
            preservedUnknownRefs: ["u1"],
            coolingPeriodSeconds: 60,
            safeAssertionCeiling: 0.4,
            reExamineTriggers: [])
        let decision = BASCthulhuAssertionCeilingGate.cap(
            permit: permit,
            ontologyFog: nil,
            retentionLoop: loop)
        XCTAssertTrue(decision.capped)
        XCTAssertTrue(decision.firedRetentionLoop)
        XCTAssertEqual(
            decision.permit.assertionCeiling,
            BASUnknownAssertionCeiling.metaOnly.rawValue,
            "raw value pin — kebab-case 'meta-only' from white paper")
    }

    func testEmptyRetentionLoopDoesNotFire() {
        let permit = makePermit(assertionCeiling: "default")
        let loop = BASUnknownRetentionLoop(
            loopID: "loop-empty",
            preservedUnknownRefs: [],
            coolingPeriodSeconds: 60,
            safeAssertionCeiling: 0.0,
            reExamineTriggers: [])
        let decision = BASCthulhuAssertionCeilingGate.cap(
            permit: permit,
            ontologyFog: nil,
            retentionLoop: loop)
        XCTAssertFalse(decision.capped,
                       "empty preservedUnknownRefs should not fire")
        XCTAssertFalse(decision.firedRetentionLoop)
    }

    func testStrictestSourceWinsWhenBothFire() {
        let permit = makePermit(assertionCeiling: "default")
        let fog = BASOntologyFog(
            fogID: "fog-2",
            fogRegions: ["x"],
            nameableAnchors: [],
            unnameableMarks: [],
            partialGraspQuality: .provisionalNaming)  // → qualified
        let loop = BASUnknownRetentionLoop(
            loopID: "loop-2",
            preservedUnknownRefs: ["y"],
            coolingPeriodSeconds: 60,
            safeAssertionCeiling: 0.1,  // → none (strictest)
            reExamineTriggers: [])
        let decision = BASCthulhuAssertionCeilingGate.cap(
            permit: permit,
            ontologyFog: fog,
            retentionLoop: loop)
        XCTAssertTrue(decision.capped)
        XCTAssertTrue(decision.firedFog)
        XCTAssertTrue(decision.firedRetentionLoop)
        XCTAssertEqual(decision.permit.assertionCeiling, "none",
                       "strictest source (none) should win")
    }

    func testMonotonicNarrowingNoOverwrite() {
        let permit = makePermit(assertionCeiling: "minimal")
        let fog = BASOntologyFog(
            fogID: "fog-3",
            fogRegions: ["x"],
            nameableAnchors: [],
            unnameableMarks: [],
            partialGraspQuality: .partialGrasp)  // → provisional (less strict)
        let decision = BASCthulhuAssertionCeilingGate.cap(
            permit: permit,
            ontologyFog: fog,
            retentionLoop: nil)
        XCTAssertFalse(decision.capped,
                       "permit already strictest should not narrow")
        XCTAssertEqual(decision.permit.assertionCeiling, "minimal",
                       "monotonic narrowing — input ceiling preserved")
    }

    // MARK: - Anti-magic-number named-constant pins

    func testNamedConstantsStable() {
        XCTAssertEqual(
            BASCthulhuAssertionCeilingGate.retentionLoopNoneThreshold,
            0.25, accuracy: 0.001)
        XCTAssertEqual(
            BASCthulhuAssertionCeilingGate.retentionLoopMetaOnlyThreshold,
            0.5, accuracy: 0.001)
        XCTAssertEqual(
            BASCthulhuAssertionCeilingGate.retentionLoopQualifiedThreshold,
            0.75, accuracy: 0.001)
    }

    // MARK: - Helpers

    private func makePermit(assertionCeiling: String) -> BASActionPermit {
        BASActionPermit(
            mode: .answer,
            assertionCeiling: assertionCeiling)
    }
}
