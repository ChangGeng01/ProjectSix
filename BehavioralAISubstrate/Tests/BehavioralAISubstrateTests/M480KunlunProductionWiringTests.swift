import XCTest
@testable import BASAdmin
@testable import BASHostKit
import BASOrchestration
import BASPolicy
import BASRuntimeCore

/// M480-M485 (chapter 一百二十五) — pin that the chapter
/// 一百二十二/三 Kunlun helpers are now consumed by
/// `EBrainRuntimeCoordinator.runTurn` and emit `kunlun.*`
/// reason codes through the L14 sovereign audit entry on
/// every turn.
///
/// Mirrors M448 chapter 一百十八 Cthulhu production wiring
/// pattern — same fixture, same path, just verifies Kunlun
/// codes appear.
final class M480KunlunProductionWiringTests: XCTestCase {

    // MARK: - Configuration helpers (mirror M303 / M448 pattern)

    private func makeRuntimePolicyLineage() -> BASRuntimePolicyLineage {
        BASRuntimePolicyLineage(
            bundleVersion: "test.m480.bundle.v1",
            providerRoutingRegistryVersion:
                "test.m480.routing-registry.v1",
            providerRoutingPolicyID:
                "test.m480.routing-policy.v1",
            runtimeTuningRegistryVersion:
                "test.m480.tuning-registry.v1",
            runtimeTuningPolicyID:
                "test.m480.tuning-policy.v1",
            resolutionSourceID: "test_bundle"
        )
    }

    private func makeTuning() -> BASEBrainRuntimeSynthesisPolicy {
        var tuning = BASEBrainRuntimeSynthesisPolicy.generic
            .withSchemaVersion(
                "host.runtime-synthesis.m480.v1")
        tuning.stateTransitions.runModeRules =
            tuning.stateTransitions
                .synthesizedRunModeRules(
                    wakeIntent: tuning.wakeIntent)
        return tuning
    }

    private func makeRuntime() -> BASHostRuntime {
        BASHostRuntime(
            configuration: BASHostConfiguration(
                runtimeProfileID: "host.m480",
                policyProfileID: "host.m480.policy",
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
        riskLevel: BASHostRiskLevel = .medium
    ) throws -> BASEBrainTurnResult {
        let runtime = makeRuntime()
        let result = try runtime.startSession(
            BASHostSessionRequest(
                kind: .interactive,
                workflowProfile: .reflective,
                surface: .application,
                prompt: prompt,
                title: "M480 kunlun wiring",
                riskLevel: riskLevel
            )
        )
        return try XCTUnwrap(result.eBrainTurn)
    }

    // MARK: - 1. kunlun.ascent.mode always emitted

    func testKunlunAscentModeAlwaysAppears() throws {
        let turn = try runTurn()
        let entry = try XCTUnwrap(turn.sovereignAuditEntry)
        let codes = entry.signalRefs.filter {
            $0.hasPrefix("kunlun.ascent.mode:")
        }
        XCTAssertEqual(codes.count, 1,
                       "exactly one kunlun.ascent.mode code per turn")
        let suffix = codes[0]
            .replacingOccurrences(
                of: "kunlun.ascent.mode:", with: "")
        let validRawValues: Set<String> = Set(
            BASAscentMode.allCases.map(\.rawValue))
        XCTAssertTrue(
            validRawValues.contains(suffix),
            "ascent mode suffix must be valid raw value")
    }

    func testKunlunAscentBudgetAppears() throws {
        let turn = try runTurn()
        let entry = try XCTUnwrap(turn.sovereignAuditEntry)
        let codes = entry.signalRefs.filter {
            $0.hasPrefix("kunlun.ascent.budget:")
        }
        XCTAssertEqual(codes.count, 1)
    }

    func testKunlunAscentReturnRequiredAlwaysFires() throws {
        let turn = try runTurn()
        let entry = try XCTUnwrap(turn.sovereignAuditEntry)
        // BASKunlunLayerProjections.AscentLease.derive sets
        // returnRequired=true (per §5.1 doctrine "每次登临都必
        // 须有回峰条件"); test pins this.
        let codes = entry.signalRefs.filter {
            $0 == "kunlun.ascent.return-required"
        }
        XCTAssertEqual(codes.count, 1,
                       "kunlun §5.1 doctrine: return-required " +
                       "always fires (回峰条件)")
    }

    // MARK: - 2. kunlun.axis.deviation always emitted

    func testKunlunAxisDeviationAppears() throws {
        let turn = try runTurn()
        let entry = try XCTUnwrap(turn.sovereignAuditEntry)
        let codes = entry.signalRefs.filter {
            $0.hasPrefix("kunlun.axis.deviationScore:")
        }
        XCTAssertEqual(codes.count, 1)
        let suffix = codes[0]
            .replacingOccurrences(
                of: "kunlun.axis.deviationScore:", with: "")
        guard let value = Double(suffix) else {
            XCTFail("deviation must be parseable Double")
            return
        }
        XCTAssertGreaterThanOrEqual(value, 0)
        XCTAssertLessThanOrEqual(value, 1)
    }

    // MARK: - 3. kunlun.gate.urgency always emitted

    func testKunlunGateUrgencyAppears() throws {
        let turn = try runTurn()
        let entry = try XCTUnwrap(turn.sovereignAuditEntry)
        let codes = entry.signalRefs.filter {
            $0.hasPrefix("kunlun.gate.urgency:")
        }
        XCTAssertEqual(codes.count, 1)
    }

    // MARK: - 4. kunlun.tianheng.center + dignity always emitted

    func testKunlunTianhengReadoutsAppear() throws {
        let turn = try runTurn()
        let entry = try XCTUnwrap(turn.sovereignAuditEntry)
        let centerCodes = entry.signalRefs.filter {
            $0.hasPrefix("kunlun.tianheng.center:")
        }
        XCTAssertEqual(centerCodes.count, 1)
        let dignityCodes = entry.signalRefs.filter {
            $0.hasPrefix("kunlun.tianheng.dignity:")
        }
        XCTAssertEqual(dignityCodes.count, 1)
    }

    // MARK: - 5. kunlun.permit.grade always emitted

    func testKunlunPermitGradeAppears() throws {
        let turn = try runTurn()
        let entry = try XCTUnwrap(turn.sovereignAuditEntry)
        let codes = entry.signalRefs.filter {
            $0.hasPrefix("kunlun.permit.grade:")
        }
        XCTAssertEqual(codes.count, 1)
        // Format: kunlun.permit.grade:<clarity>:<reversibility>:<provenance>
        let suffix = codes[0]
            .replacingOccurrences(
                of: "kunlun.permit.grade:", with: "")
        let parts = suffix.split(separator: ":")
        XCTAssertEqual(parts.count, 3,
                       "permit grade must have 3 score parts")
        for part in parts {
            XCTAssertNotNil(Double(part),
                            "each score part must be parseable Double")
        }
    }

    // MARK: - 6. Permit mode preserved (single commit mouth)

    /// **Doctrine pin** — chapter 一百二十五 wires must NEVER
    /// replace `permit.mode`. Single commit mouth stays at L11.
    /// Mirror of M448 chapter 一百十八 single-commit-mouth pin.
    func testPermitModeNotMutatedByKunlunWires() throws {
        let turn = try runTurn(riskLevel: .high)
        let entry = try XCTUnwrap(turn.sovereignAuditEntry)
        let permit = turn.actionPermit
        let permitCodes = entry.signalRefs.filter {
            $0.hasPrefix("permit:")
        }
        XCTAssertEqual(permitCodes.count, 1)
        let auditMode = permitCodes[0]
            .replacingOccurrences(of: "permit:", with: "")
        XCTAssertEqual(auditMode, permit.mode.rawValue,
                       "single commit mouth — permit.mode held " +
                       "by L11; chapter 一百二十五 Kunlun wires " +
                       "must not replace it")
    }

    // MARK: - 7. Determinism

    func testKunlunReasonCodesAreDeterministic() throws {
        let turn1 = try runTurn(prompt: "fixed prompt")
        let turn2 = try runTurn(prompt: "fixed prompt")
        let e1 = try XCTUnwrap(turn1.sovereignAuditEntry)
        let e2 = try XCTUnwrap(turn2.sovereignAuditEntry)
        let kunlun1 = e1.signalRefs
            .filter { $0.hasPrefix("kunlun.") }
            .sorted()
        let kunlun2 = e2.signalRefs
            .filter { $0.hasPrefix("kunlun.") }
            .sorted()
        XCTAssertEqual(kunlun1, kunlun2,
                       "kunlun.* codes must be deterministic " +
                       "for byte-equal turn inputs")
    }

    // MARK: - 8. Deviation parseable + bounded

    /// Pin: deviation score is parseable + in `[0, 1]` for any
    /// turn. Note: monotonicity-by-host-risk not asserted here
    /// because the substrate's risk-level normalization may
    /// override the host-passed level (M303 pattern).
    func testAxisDeviationIsParseableAndBounded() throws {
        for riskLevel: BASHostRiskLevel in [.low, .medium, .high] {
            let turn = try runTurn(riskLevel: riskLevel)
            guard let dev = parseDeviation(from: turn) else {
                XCTFail("axis deviation missing for risk \(riskLevel)")
                continue
            }
            XCTAssertGreaterThanOrEqual(dev, 0)
            XCTAssertLessThanOrEqual(dev, 1)
        }
    }

    private func parseDeviation(
        from turn: BASEBrainTurnResult
    ) -> Double? {
        guard let entry = turn.sovereignAuditEntry,
              let code = entry.signalRefs.first(where: {
                  $0.hasPrefix("kunlun.axis.deviationScore:")
              })
        else { return nil }
        let suffix = code.replacingOccurrences(
            of: "kunlun.axis.deviationScore:", with: "")
        return Double(suffix)
    }
}
