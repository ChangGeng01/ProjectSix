import XCTest
@testable import BASAdmin
@testable import BASHostKit
import BASOrchestration
import BASPolicy
import BASRuntimeCore

/// M317 — pin that `BASAnomalyTrace.deriveOrNil(...)` is
/// consumed by the L14 sovereign audit entry, only when the
/// underlying `BASNarrativeDistortion` carries an axis above
/// `BASAnomalyWatchProtocol.defaultEmitThreshold` (0.4).
///
/// Pre-M317 the `BASAnomalyTrace` schema (white paper §7) was
/// produced only by `BASAnomalyWatchProtocol.trace(...)` in
/// tests + governance. M317 adds `BASAnomalyTrace.deriveOrNil`
/// (returns nil when no axis crosses the threshold) and wires
/// it into runTurn so audit signalRefs carry `anomaly.types` +
/// `anomaly.confidence` codes when a distortion shape is
/// detected.
///
/// Doctrine pinned:
/// - `nil` anomaly = no codes (audit elides cleanly)
/// - `anomaly.types` is sorted+joined for deterministic digest
/// - confidence reflects the underlying distortion confidence
final class M317AnomalyTraceConsumptionTests: XCTestCase {

    // MARK: - Pure derive tests

    /// 1. Zero-distortion → no axis above threshold →
    ///    `deriveOrNil` returns `nil`.
    func testDeriveOrNilReturnsNilForZeroDistortion() {
        let distortion = BASNarrativeDistortion.derive(
            distortionID: "low",
            riskLevel: .low,
            permitMode: .answer)
        XCTAssertFalse(distortion.isNonTrivial)
        let trace = BASAnomalyTrace.deriveOrNil(
            traceID: "trace-low",
            distortion: distortion,
            relationShift: "",
            sourceRefs: [])
        XCTAssertNil(trace,
                     "zero-axis distortion must produce nil " +
                     "anomaly trace")
    }

    /// 2. Block-permit distortion (forcedClosure 0.7) crosses
    ///    threshold → trace emitted with `.forcedClosure`
    ///    anomaly type.
    func testDeriveOrNilProducesTraceForBlockPermit() throws {
        let distortion = BASNarrativeDistortion.derive(
            distortionID: "block",
            riskLevel: .low,
            permitMode: .block)
        let trace = try XCTUnwrap(
            BASAnomalyTrace.deriveOrNil(
                traceID: "trace-block",
                distortion: distortion,
                relationShift: "",
                sourceRefs: ["source-1"]))
        XCTAssertTrue(
            trace.anomalyTypes.contains(.forcedClosure))
        XCTAssertEqual(trace.confidence, 0.5)
    }

    /// 3. Extreme + answer permit (urgencyMask 0.9) crosses
    ///    threshold → trace with `.falseUrgency` anomaly type.
    func testDeriveOrNilProducesTraceForExtremeAnswer() throws {
        let distortion = BASNarrativeDistortion.derive(
            distortionID: "extreme",
            riskLevel: .extreme,
            permitMode: .answer)
        let trace = try XCTUnwrap(
            BASAnomalyTrace.deriveOrNil(
                traceID: "trace-extreme",
                distortion: distortion,
                relationShift: "",
                sourceRefs: ["source-2"]))
        XCTAssertTrue(
            trace.anomalyTypes.contains(.falseUrgency))
    }

    /// 4. The default emit threshold is 0.4 — a 0.3 distortion
    ///    field (medium + answer permit's urgencyMask) does NOT
    ///    cross it → nil trace.
    func testThresholdElidesSubThresholdDistortion() {
        let distortion = BASNarrativeDistortion.derive(
            distortionID: "sub",
            riskLevel: .medium,
            permitMode: .answer)
        XCTAssertEqual(distortion.urgencyMask, 0.3)
        // 0.3 < 0.4 default threshold → nil.
        XCTAssertNil(
            BASAnomalyTrace.deriveOrNil(
                traceID: "trace-sub",
                distortion: distortion,
                relationShift: "",
                sourceRefs: []))
    }

    // MARK: - Runtime integration tests

    private func makeRuntimePolicyLineage() -> BASRuntimePolicyLineage {
        BASRuntimePolicyLineage(
            bundleVersion: "test.m317.bundle.v1",
            providerRoutingRegistryVersion:
                "test.m317.routing-registry.v1",
            providerRoutingPolicyID:
                "test.m317.routing-policy.v1",
            runtimeTuningRegistryVersion:
                "test.m317.tuning-registry.v1",
            runtimeTuningPolicyID:
                "test.m317.tuning-policy.v1",
            resolutionSourceID: "test_bundle"
        )
    }

    private func makeTuning() -> BASEBrainRuntimeSynthesisPolicy {
        var tuning = BASEBrainRuntimeSynthesisPolicy.generic
            .withSchemaVersion(
                "host.runtime-synthesis.m317.v1")
        tuning.stateTransitions.runModeRules =
            tuning.stateTransitions
                .synthesizedRunModeRules(
                    wakeIntent: tuning.wakeIntent)
        return tuning
    }

    private func makeRuntime() -> BASHostRuntime {
        BASHostRuntime(
            configuration: BASHostConfiguration(
                runtimeProfileID: "host.m317",
                policyProfileID: "host.m317.policy",
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

    /// 5. Runtime turn emits well-shaped anomaly codes (or
    ///    zero codes when distortion stays sub-threshold).
    ///    Default reflective turns frequently land permit at
    ///    `.delay` (forcedClosure 0.4 = exactly threshold), so
    ///    `forced-closure` anomaly typically fires; the audit
    ///    consumer emits exactly 2 codes (`anomaly.types` +
    ///    `anomaly.confidence`) when present.
    func testRuntimeTurnEmitsWellShapedAnomalyCodes() throws {
        let runtime = makeRuntime()
        let result = try runtime.startSession(
            BASHostSessionRequest(
                kind: .interactive,
                workflowProfile: .reflective,
                surface: .application,
                prompt: "M317 well-shaped turn",
                title: "M317 anomaly shape",
                riskLevel: .low))
        let turn = try XCTUnwrap(result.eBrainTurn)
        let auditEntry = try XCTUnwrap(
            turn.sovereignAuditEntry)
        let anomalyCodes = auditEntry.signalRefs.filter {
            $0.hasPrefix("anomaly.")
        }
        XCTAssertTrue(
            anomalyCodes.isEmpty
                || anomalyCodes.count == 2,
            "anomaly codes must be 0 or 2, got " +
            "\(anomalyCodes.count): \(anomalyCodes)")
        // If present, both codes should appear together —
        // never one without the other.
        if anomalyCodes.count == 2 {
            XCTAssertTrue(
                anomalyCodes.contains {
                    $0.hasPrefix("anomaly.types:")
                })
            XCTAssertTrue(
                anomalyCodes.contains {
                    $0.hasPrefix("anomaly.confidence:")
                })
        }
    }
}
