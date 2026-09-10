import XCTest
@testable import BASAdmin
@testable import BASHostKit
import BASOrchestration
import BASPolicy
import BASRuntimeCore

/// M303 — pin that `BASAbyssalPressureBudget.derive(...)` (M287
/// Cthulhu/Abyssal protocol §5.1, schema-only since 2026-04-30)
/// is consumed by the L14 sovereign audit entry on every turn.
///
/// Pre-M303 the eight Cthulhu/Abyssal schemas had only one
/// reference each — the governance registry — and zero runtime
/// callers. After M303 `EBrainRuntimeCoordinator.runTurn`
/// derives a `BASAbyssalPressure` from existing risk +
/// uncertainty + evidence-debt state and pipes it into
/// `buildSovereignAuditEntry`, which appends three additive
/// signal codes:
///
///   - `abyssal.magnitude:<3-decimal>` — pure mean of the six
///     pressure dimensions (always present)
///   - `abyssal.modes:<N>` — recommended mode count per
///     `BASAbyssalPressureBudget.recommendedModes(for:)`
///   - `abyssal.escalation:elevated:<reasons>` — optional, only
///     when any dimension crosses the elevated 0.8 threshold
///
/// Hash chain semantics from M91/M283/M271 are preserved —
/// signature simply digests a longer ordered list. Doctrine red
/// line 7 ("watcher hints, not verdicts") is upheld: pressure
/// magnitude is metadata, not a verdict-escalation signal.
final class M303AbyssalPressureConsumptionTests: XCTestCase {

    // MARK: - Configuration helpers

    private func makeRuntimePolicyLineage() -> BASRuntimePolicyLineage {
        BASRuntimePolicyLineage(
            bundleVersion: "test.m303.bundle.v1",
            providerRoutingRegistryVersion:
                "test.m303.routing-registry.v1",
            providerRoutingPolicyID:
                "test.m303.routing-policy.v1",
            runtimeTuningRegistryVersion:
                "test.m303.tuning-registry.v1",
            runtimeTuningPolicyID:
                "test.m303.tuning-policy.v1",
            resolutionSourceID: "test_bundle"
        )
    }

    private func makeTuning() -> BASEBrainRuntimeSynthesisPolicy {
        var tuning = BASEBrainRuntimeSynthesisPolicy.generic
            .withSchemaVersion(
                "host.runtime-synthesis.m303.v1")
        tuning.stateTransitions.runModeRules =
            tuning.stateTransitions
                .synthesizedRunModeRules(
                    wakeIntent: tuning.wakeIntent)
        return tuning
    }

    private func makeRuntime() -> BASHostRuntime {
        BASHostRuntime(
            configuration: BASHostConfiguration(
                runtimeProfileID: "host.m303",
                policyProfileID: "host.m303.policy",
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
        prompt: String =
            "Help me weigh whether this is a safe step.",
        title: String = "M303 abyssal pressure",
        riskLevel: BASHostRiskLevel = .medium
    ) throws -> BASEBrainTurnResult {
        let runtime = makeRuntime()
        let result = try runtime.startSession(
            BASHostSessionRequest(
                kind: .interactive,
                workflowProfile: .reflective,
                surface: .application,
                prompt: prompt,
                title: title,
                riskLevel: riskLevel
            )
        )
        return try XCTUnwrap(result.eBrainTurn)
    }

    // MARK: - 1. abyssal.magnitude always emitted

    /// Every turn produces a pressure reading — even at
    /// minimum risk + zero evidence debt + maximum confidence,
    /// the magnitude is well-defined (the mean of zeros and a
    /// small consequence-radius scalar). Pin that this code
    /// always appears.
    func testAbyssalMagnitudeAlwaysAppearsInSignalRefs() throws {
        let turn = try runTurn()
        let auditEntry = try XCTUnwrap(turn.sovereignAuditEntry)

        let magnitudeCodes = auditEntry.signalRefs.filter {
            $0.hasPrefix("abyssal.magnitude:")
        }
        XCTAssertEqual(
            magnitudeCodes.count, 1,
            "exactly one abyssal magnitude code per turn")
        let suffix = magnitudeCodes[0]
            .replacingOccurrences(
                of: "abyssal.magnitude:", with: "")
        guard let value = Double(suffix) else {
            XCTFail(
                "abyssal.magnitude must be parseable Double " +
                "(was \"\(suffix)\")")
            return
        }
        XCTAssertGreaterThanOrEqual(value, 0)
        XCTAssertLessThanOrEqual(value, 1)
    }

    // MARK: - 2. abyssal.modes count is non-negative integer

    /// Mode count comes from
    /// `BASAbyssalPressureBudget.recommendedModes(for:)`; six
    /// dimensions × default 0.6 trigger means anywhere from 0
    /// to 6 modes. Pin parseable + bounded.
    func testAbyssalModesCountIsBoundedInteger() throws {
        let turn = try runTurn()
        let auditEntry = try XCTUnwrap(turn.sovereignAuditEntry)

        let modeCodes = auditEntry.signalRefs.filter {
            $0.hasPrefix("abyssal.modes:")
        }
        XCTAssertEqual(modeCodes.count, 1)
        let suffix = modeCodes[0]
            .replacingOccurrences(
                of: "abyssal.modes:", with: "")
        guard let count = Int(suffix) else {
            XCTFail(
                "abyssal.modes must be parseable Int (was " +
                "\"\(suffix)\")")
            return
        }
        XCTAssertGreaterThanOrEqual(count, 0)
        XCTAssertLessThanOrEqual(
            count, 6,
            "abyssal pressure has six dimensions; mode count " +
            "must be <= 6")
    }

    // MARK: - 3. derive() pure projection — magnitude is mean

    /// Direct unit test on the derive helper: the aggregate
    /// magnitude must equal the arithmetic mean of the six
    /// pressure dimensions. Pin so future refactors can't
    /// silently switch to a weighted formula.
    func testDeriveAggregateMagnitudeIsArithmeticMean() {
        let pressure = BASAbyssalPressureBudget.derive(
            turnID: "unit-test-m303",
            riskLevel: .high,
            uncertaintyLedger: nil,
            evidenceDebtCount: 5)
        let dimensions = [
            pressure.unknownLoad,
            pressure.consequenceRadius,
            pressure.evidenceDebt,
            pressure.ontologyDistortion,
            pressure.manipulationIndex,
            pressure.narrativePollution
        ]
        let manualMean = dimensions.reduce(0, +) / 6.0
        XCTAssertEqual(
            pressure.aggregateMagnitude,
            manualMean,
            accuracy: 0.0001)
    }

    // MARK: - 4. Risk level ordering preserved in
    //           consequenceRadius

    /// .low → 0.2, .medium → 0.45, .high → 0.7, .extreme → 1.0.
    /// Pin the strict ordering so consumers can rely on
    /// monotonicity (white-paper §5.1 "consequenceRadius
    /// reflects how far a decision reaches").
    func testConsequenceRadiusIsMonotoneInRiskLevel() {
        let pLow = BASAbyssalPressureBudget.derive(
            turnID: "t-low",
            riskLevel: .low,
            uncertaintyLedger: nil,
            evidenceDebtCount: 0)
        let pMedium = BASAbyssalPressureBudget.derive(
            turnID: "t-medium",
            riskLevel: .medium,
            uncertaintyLedger: nil,
            evidenceDebtCount: 0)
        let pHigh = BASAbyssalPressureBudget.derive(
            turnID: "t-high",
            riskLevel: .high,
            uncertaintyLedger: nil,
            evidenceDebtCount: 0)
        let pExtreme = BASAbyssalPressureBudget.derive(
            turnID: "t-extreme",
            riskLevel: .extreme,
            uncertaintyLedger: nil,
            evidenceDebtCount: 0)

        XCTAssertLessThan(
            pLow.consequenceRadius, pMedium.consequenceRadius)
        XCTAssertLessThan(
            pMedium.consequenceRadius, pHigh.consequenceRadius)
        XCTAssertLessThan(
            pHigh.consequenceRadius, pExtreme.consequenceRadius)
        XCTAssertEqual(
            pExtreme.consequenceRadius, 1.0, accuracy: 0.0001)
    }

    // MARK: - 5. Extreme risk triggers escalation hint;
    //           low risk does not

    /// .extreme risk → consequenceRadius = 1.0 ≥ 0.8 → emits
    /// `elevated:consequence-radius` hint. .low risk → 0.2 < 0.6
    /// → 0 modes triggered, no escalation hint.
    func testExtremeRiskEmitsEscalationHint() {
        let pExtreme = BASAbyssalPressureBudget.derive(
            turnID: "t-extreme",
            riskLevel: .extreme,
            uncertaintyLedger: nil,
            evidenceDebtCount: 0)
        XCTAssertNotNil(pExtreme.sovereignEscalationHint)
        let hint = pExtreme.sovereignEscalationHint ?? "nil"
        XCTAssertTrue(
            hint.contains("consequence-radius"),
            "extreme risk → consequence-radius elevated " +
            "(was \(hint))")

        let pLow = BASAbyssalPressureBudget.derive(
            turnID: "t-low",
            riskLevel: .low,
            uncertaintyLedger: nil,
            evidenceDebtCount: 0)
        XCTAssertNil(
            pLow.sovereignEscalationHint,
            "low risk + zero debt should not trigger elevated " +
            "escalation")
    }

    // MARK: - 6. Backward-compat: all M298-M302 codes still
    //           coexist with M303 codes.

    /// A reflective turn now emits codes from M298 deps + M299
    /// frontier + M300 tribunal + M303 abyssal. Pin that they
    /// all coexist — no replacement, only addition.
    func testAllMSeriesCodesCoexistOnSingleTurn() throws {
        let turn = try runTurn()
        let auditEntry = try XCTUnwrap(turn.sovereignAuditEntry)
        let signal = auditEntry.signalRefs

        // M299
        XCTAssertTrue(signal.contains {
            $0.hasPrefix("frontier.status:")
        }, "M299 frontier code missing")
        // M300
        XCTAssertTrue(signal.contains {
            $0.hasPrefix("tribunal.status:")
        }, "M300 tribunal code missing")
        // M303
        XCTAssertTrue(signal.contains {
            $0.hasPrefix("abyssal.magnitude:")
        }, "M303 abyssal magnitude code missing")
        XCTAssertTrue(signal.contains {
            $0.hasPrefix("abyssal.modes:")
        }, "M303 abyssal modes code missing")
        // Legacy
        XCTAssertTrue(signal.contains {
            $0.hasPrefix("risk:")
        })
        XCTAssertTrue(signal.contains {
            $0.hasPrefix("permit:")
        })
        XCTAssertTrue(signal.contains {
            $0.hasPrefix("fold:")
        })
    }

    // MARK: - 7. derive() is deterministic

    /// Same inputs produce same magnitude. Pin so the audit
    /// hash chain stays deterministic across two identical
    /// turns.
    func testDeriveDeterminism() {
        let p1 = BASAbyssalPressureBudget.derive(
            turnID: "t-1",
            riskLevel: .medium,
            uncertaintyLedger: nil,
            evidenceDebtCount: 3)
        let p2 = BASAbyssalPressureBudget.derive(
            turnID: "t-1",
            riskLevel: .medium,
            uncertaintyLedger: nil,
            evidenceDebtCount: 3)
        XCTAssertEqual(p1, p2)
    }
}
