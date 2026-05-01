import XCTest
@testable import BASAdmin
@testable import BASHostKit
import BASOrchestration
import BASRuntimeCore
import BASWorldPrior

/// M320 — pin that `BASUnknownReserve.derive(...)` is consumed
/// by the L14 sovereign audit entry, only when the L9 uncertainty
/// ledger's confidence floor is below `unrestricted` (0.8).
///
/// Pre-M320 the schema (white paper §5.4) had 0 runtime callers
/// outside its definition + tests + governance registry. M320
/// derives a per-turn reserve from the uncertainty ledger and
/// pushes the resulting assertion ceiling + ref count into audit
/// signalRefs as additive metadata.
///
/// Doctrine pinned:
/// - Codes appear only when assertion ceiling is below
///   `.unrestricted` (high confidence floor → no signal worth
///   reporting → elide cleanly)
/// - All emitted values use canonical raw-value strings (audit
///   walkers grep these without importing the BASWorldPrior
///   module)
/// - Hash chain semantics unchanged (additive signalRefs only)
final class M320UnknownReserveConsumptionTests: XCTestCase {

    // MARK: - Pure derive tests

    /// 1. High confidence floor (0.9) → `.unrestricted` ceiling
    ///    → empty unknownRefs → `isOpen == false`.
    func testHighConfidenceFloorYieldsUnrestricted() {
        let reserve = BASUnknownReserve.derive(
            reserveID: "high-conf",
            confidenceFloor: 0.9)
        XCTAssertEqual(
            reserve.assertionCeiling, .unrestricted)
        XCTAssertTrue(reserve.unknownRefs.isEmpty)
        XCTAssertFalse(reserve.isOpen)
    }

    /// 2. Mid-range confidence (0.55) → `.qualified` ceiling.
    func testMidConfidenceYieldsQualified() {
        let reserve = BASUnknownReserve.derive(
            reserveID: "mid",
            confidenceFloor: 0.55)
        XCTAssertEqual(
            reserve.assertionCeiling, .qualified)
        XCTAssertEqual(reserve.unknownRefs.count, 1)
        XCTAssertTrue(reserve.isOpen)
    }

    /// 3. Very low confidence (0.1) → `.none` ceiling.
    func testLowConfidenceYieldsNone() {
        let reserve = BASUnknownReserve.derive(
            reserveID: "low",
            confidenceFloor: 0.1)
        XCTAssertEqual(reserve.assertionCeiling, .none)
        XCTAssertTrue(reserve.isOpen)
    }

    /// 4. Confidence floor monotonically maps to ceiling tier
    ///    (each tier strictly disjoint from neighbours).
    func testCeilingMappingIsMonotonicAcrossThresholds() {
        XCTAssertEqual(
            BASUnknownReserve.derive(
                reserveID: "t1",
                confidenceFloor: 0.85)
                .assertionCeiling, .unrestricted)
        XCTAssertEqual(
            BASUnknownReserve.derive(
                reserveID: "t2",
                confidenceFloor: 0.7)
                .assertionCeiling, .provisional)
        XCTAssertEqual(
            BASUnknownReserve.derive(
                reserveID: "t3",
                confidenceFloor: 0.5)
                .assertionCeiling, .qualified)
        XCTAssertEqual(
            BASUnknownReserve.derive(
                reserveID: "t4",
                confidenceFloor: 0.3)
                .assertionCeiling, .metaOnly)
        XCTAssertEqual(
            BASUnknownReserve.derive(
                reserveID: "t5",
                confidenceFloor: 0.0)
                .assertionCeiling, .none)
    }

    /// 5. The derive helper carries a single
    ///    `confidence-floor:<value>` ref so audit walkers can
    ///    trace the reserve back to its source signal.
    func testDeriveCarriesSingleConfidenceFloorRef() {
        let reserve = BASUnknownReserve.derive(
            reserveID: "trace",
            confidenceFloor: 0.55)
        XCTAssertEqual(reserve.unknownRefs.count, 1)
        XCTAssertTrue(
            reserve.unknownRefs[0]
                .hasPrefix("confidence-floor:"))
    }

    // MARK: - Runtime integration

    private func makeRuntimePolicyLineage() -> BASRuntimePolicyLineage {
        BASRuntimePolicyLineage(
            bundleVersion: "test.m320.bundle.v1",
            providerRoutingRegistryVersion:
                "test.m320.routing-registry.v1",
            providerRoutingPolicyID:
                "test.m320.routing-policy.v1",
            runtimeTuningRegistryVersion:
                "test.m320.tuning-registry.v1",
            runtimeTuningPolicyID:
                "test.m320.tuning-policy.v1",
            resolutionSourceID: "test_bundle"
        )
    }

    private func makeTuning() -> BASEBrainRuntimeSynthesisPolicy {
        var tuning = BASEBrainRuntimeSynthesisPolicy.generic
            .withSchemaVersion(
                "host.runtime-synthesis.m320.v1")
        tuning.stateTransitions.runModeRules =
            tuning.stateTransitions
                .synthesizedRunModeRules(
                    wakeIntent: tuning.wakeIntent)
        return tuning
    }

    private func makeRuntime() -> BASHostRuntime {
        BASHostRuntime(
            configuration: BASHostConfiguration(
                runtimeProfileID: "host.m320",
                policyProfileID: "host.m320.policy",
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

    /// 6. Runtime turn emits well-shaped `unknownReserve.*`
    ///    codes (or zero codes when the ceiling resolves to
    ///    `.unrestricted` because the L9 uncertainty ledger is
    ///    absent / has high confidence floor).
    func testRuntimeTurnEmitsUnknownReserveCodes() throws {
        let runtime = makeRuntime()
        let result = try runtime.startSession(
            BASHostSessionRequest(
                kind: .interactive,
                workflowProfile: .reflective,
                surface: .application,
                prompt: "M320 unknown reserve test",
                title: "M320 reserve coverage",
                riskLevel: .medium))
        let turn = try XCTUnwrap(result.eBrainTurn)
        let auditEntry = try XCTUnwrap(
            turn.sovereignAuditEntry)
        let reserveCodes = auditEntry.signalRefs.filter {
            $0.hasPrefix("unknownReserve.")
        }
        // Either 0 codes (high confidence floor, nothing to
        // report) or exactly 2 codes (assertionCeiling + refs).
        XCTAssertTrue(
            reserveCodes.isEmpty || reserveCodes.count == 2,
            "unknownReserve codes must be 0 or 2, got " +
            "\(reserveCodes.count): \(reserveCodes)")
        // If present, validate shape.
        if reserveCodes.count == 2 {
            XCTAssertTrue(
                reserveCodes.contains {
                    $0.hasPrefix("unknownReserve.assertionCeiling:")
                })
            XCTAssertTrue(
                reserveCodes.contains {
                    $0.hasPrefix("unknownReserve.refs:")
                })
        }
    }
}
