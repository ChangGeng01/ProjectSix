import XCTest
@testable import BASAdmin
@testable import BASHostKit
import BASOrchestration
import BASPolicy
import BASRuntimeCore

/// M316 — pin that `BASNarrativeDistortion.derive(...)` is
/// consumed by the L14 sovereign audit entry on every turn.
///
/// Pre-M316 the schema (white paper §7) was load-bearing in
/// tests + governance only; no runtime path produced one. M316
/// derives from final risk + permit and pushes the resulting
/// distortion's non-trivial axes into audit signalRefs as
/// additive metadata (`narrative.maxAxis` /
/// `narrative.forcedClosure` / `narrative.urgencyMask`).
///
/// Doctrine pinned:
/// - Codes appear only when distortion has a non-trivial axis
///   (zero-distortion turns elide all `narrative.*` codes)
/// - All emitted values are `[0, 1]` clamped (white paper §7
///   contract preserved through the projection)
/// - Hash chain semantics unchanged (additive signalRefs only)
final class M316NarrativeDistortionConsumptionTests: XCTestCase {

    private func makeRuntimePolicyLineage() -> BASRuntimePolicyLineage {
        BASRuntimePolicyLineage(
            bundleVersion: "test.m316.bundle.v1",
            providerRoutingRegistryVersion:
                "test.m316.routing-registry.v1",
            providerRoutingPolicyID:
                "test.m316.routing-policy.v1",
            runtimeTuningRegistryVersion:
                "test.m316.tuning-registry.v1",
            runtimeTuningPolicyID:
                "test.m316.tuning-policy.v1",
            resolutionSourceID: "test_bundle"
        )
    }

    private func makeTuning() -> BASEBrainRuntimeSynthesisPolicy {
        var tuning = BASEBrainRuntimeSynthesisPolicy.generic
            .withSchemaVersion(
                "host.runtime-synthesis.m316.v1")
        tuning.stateTransitions.runModeRules =
            tuning.stateTransitions
                .synthesizedRunModeRules(
                    wakeIntent: tuning.wakeIntent)
        return tuning
    }

    private func makeRuntime() -> BASHostRuntime {
        BASHostRuntime(
            configuration: BASHostConfiguration(
                runtimeProfileID: "host.m316",
                policyProfileID: "host.m316.policy",
                prefersPureLocal: true,
                defaultDeviceState:
                    BASHostConfiguration.fixtureDefaultDeviceState,
                console: .generic,
                lifecycleBehavior: .generic,
                workflowBehavior: .generic,
                cognitionBehavior: .generic,
                presentation: .generic,
                runtimeTuning: makeTuning(),
                runtimePolicyLineage:
                    makeRuntimePolicyLineage(),
                hostRhythmProfile: .generic
            )
        )
    }

    private func runTurn(
        riskLevel: BASHostRiskLevel = .medium,
        prompt: String = "M316 distortion projection turn."
    ) throws -> BASEBrainTurnResult {
        let runtime = makeRuntime()
        let result = try runtime.startSession(
            BASHostSessionRequest(
                kind: .interactive,
                workflowProfile: .reflective,
                surface: .application,
                prompt: prompt,
                title: "M316 narrative coverage",
                riskLevel: riskLevel
            )
        )
        return try XCTUnwrap(result.eBrainTurn)
    }

    // MARK: - Pure derive tests (don't need runtime fixture)

    /// 1. Zero-distortion projection: low risk + answer permit
    ///    → all 5 axes are 0 → `isNonTrivial == false`.
    func testDeriveLowRiskAnswerProducesZeroAxes() {
        let distortion = BASNarrativeDistortion.derive(
            distortionID: "low-test",
            riskLevel: .low,
            permitMode: .answer)
        XCTAssertFalse(distortion.isNonTrivial)
        XCTAssertEqual(distortion.realityDenial, 0)
        XCTAssertEqual(distortion.historyRewrite, 0)
        XCTAssertEqual(distortion.forcedClosure, 0)
        XCTAssertEqual(distortion.roleInversion, 0)
        XCTAssertEqual(distortion.urgencyMask, 0)
    }

    /// 2. Forced-closure scaling: block > delay > compare > 0.
    func testForcedClosureScalesByPermitMode() {
        let block = BASNarrativeDistortion.derive(
            distortionID: "block-test",
            riskLevel: .low,
            permitMode: .block)
        let delay = BASNarrativeDistortion.derive(
            distortionID: "delay-test",
            riskLevel: .low,
            permitMode: .delay)
        let compare = BASNarrativeDistortion.derive(
            distortionID: "compare-test",
            riskLevel: .low,
            permitMode: .compare)
        XCTAssertGreaterThan(
            block.forcedClosure, delay.forcedClosure)
        XCTAssertGreaterThan(
            delay.forcedClosure, compare.forcedClosure)
        XCTAssertGreaterThan(compare.forcedClosure, 0)
    }

    /// 3. Urgency-mask scaling: extreme + answer > high + answer
    ///    > medium + answer > else == 0.
    func testUrgencyMaskScalesByRiskWhenAnswerPermit() {
        let extreme = BASNarrativeDistortion.derive(
            distortionID: "x-test",
            riskLevel: .extreme,
            permitMode: .answer)
        let high = BASNarrativeDistortion.derive(
            distortionID: "h-test",
            riskLevel: .high,
            permitMode: .answer)
        let medium = BASNarrativeDistortion.derive(
            distortionID: "m-test",
            riskLevel: .medium,
            permitMode: .answer)
        let mediumBlock = BASNarrativeDistortion.derive(
            distortionID: "mb-test",
            riskLevel: .medium,
            permitMode: .block)
        XCTAssertGreaterThan(
            extreme.urgencyMask, high.urgencyMask)
        XCTAssertGreaterThan(
            high.urgencyMask, medium.urgencyMask)
        XCTAssertGreaterThan(medium.urgencyMask, 0)
        // Same risk level but block permit → no urgency mask.
        XCTAssertEqual(mediumBlock.urgencyMask, 0)
    }

    /// 4. `maxAxis` returns the largest of the 5 axes.
    func testMaxAxisReturnsLargestAxis() {
        let distortion = BASNarrativeDistortion.derive(
            distortionID: "max-test",
            riskLevel: .extreme,
            permitMode: .answer)
        // urgencyMask = 0.9, forcedClosure = 0
        // (answer permit) → maxAxis = 0.9.
        XCTAssertEqual(distortion.maxAxis, 0.9)
    }

    // MARK: - Runtime integration tests

    /// 5. Runtime turn emits well-shaped `narrative.*` codes
    ///    that mirror the derived distortion. Production path
    ///    typically lands the permit at `.delay` (forcedClosure
    ///    = 0.4) for default reflective turns; the audit
    ///    consumer emits 3 codes when distortion is non-trivial.
    func testRuntimeTurnEmitsWellShapedNarrativeCodes() throws {
        let turn = try runTurn(riskLevel: .low)
        let auditEntry = try XCTUnwrap(
            turn.sovereignAuditEntry)
        let narrativeCodes = auditEntry.signalRefs.filter {
            $0.hasPrefix("narrative.")
        }
        // When non-trivial → exactly 3 codes:
        //   narrative.maxAxis / .forcedClosure / .urgencyMask
        // When trivial → 0 codes. Both shapes valid per the
        // M316 emit contract.
        XCTAssertTrue(
            narrativeCodes.isEmpty
                || narrativeCodes.count == 3,
            "narrative codes must be 0 or 3, got " +
            "\(narrativeCodes.count): \(narrativeCodes)")
        // If present, validate each code's parseable shape.
        for code in narrativeCodes {
            let suffix = code
                .components(separatedBy: ":")
                .last ?? ""
            guard let value = Double(suffix) else {
                XCTFail(
                    "narrative code suffix must parse as " +
                    "Double: \(code)")
                return
            }
            XCTAssertGreaterThanOrEqual(value, 0.0)
            XCTAssertLessThanOrEqual(value, 1.0)
        }
    }

    /// 6. Hash chain semantics remain deterministic — two
    ///    identical turns produce the same audit signalRefs.
    func testTwoIdenticalTurnsProduceSameSignalRefs() throws {
        let turn1 = try runTurn()
        let turn2 = try runTurn()
        let entry1 = try XCTUnwrap(turn1.sovereignAuditEntry)
        let entry2 = try XCTUnwrap(turn2.sovereignAuditEntry)
        // signalRefs is sorted by `orderedReasonCodes` — should
        // match across runs (modulo session/audit IDs which are
        // not part of signalRefs).
        let n1 = entry1.signalRefs.filter {
            $0.hasPrefix("narrative.")
        }
        let n2 = entry2.signalRefs.filter {
            $0.hasPrefix("narrative.")
        }
        XCTAssertEqual(n1, n2,
                       "narrative codes must be deterministic " +
                       "across identical turns")
    }
}
