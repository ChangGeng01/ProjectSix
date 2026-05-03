import XCTest
@testable import BASAdmin
@testable import BASHostKit
import BASOrchestration
import BASPolicy
import BASRuntimeCore

/// M486-M490 (chapter 一百二十六) — pin the L9 dream-loop
/// schemas + L3 jade-casket + L13 jade-refinement now flow
/// through `EBrainRuntimeCoordinator.runTurn` audit emission.
final class M486KunlunDreamLoopWiringTests: XCTestCase {

    private func makeRuntimePolicyLineage() -> BASRuntimePolicyLineage {
        BASRuntimePolicyLineage(
            bundleVersion: "test.m486.bundle.v1",
            providerRoutingRegistryVersion:
                "test.m486.routing-registry.v1",
            providerRoutingPolicyID:
                "test.m486.routing-policy.v1",
            runtimeTuningRegistryVersion:
                "test.m486.tuning-registry.v1",
            runtimeTuningPolicyID:
                "test.m486.tuning-policy.v1",
            resolutionSourceID: "test_bundle"
        )
    }

    private func makeTuning() -> BASEBrainRuntimeSynthesisPolicy {
        var tuning = BASEBrainRuntimeSynthesisPolicy.generic
            .withSchemaVersion(
                "host.runtime-synthesis.m486.v1")
        tuning.stateTransitions.runModeRules =
            tuning.stateTransitions
                .synthesizedRunModeRules(
                    wakeIntent: tuning.wakeIntent)
        return tuning
    }

    private func makeRuntime() -> BASHostRuntime {
        BASHostRuntime(
            configuration: BASHostConfiguration(
                runtimeProfileID: "host.m486",
                policyProfileID: "host.m486.policy",
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

    private func runTurn() throws -> BASEBrainTurnResult {
        let runtime = makeRuntime()
        let result = try runtime.startSession(
            BASHostSessionRequest(
                kind: .interactive,
                workflowProfile: .reflective,
                surface: .application,
                prompt: "Help me decide whether to take this irreversible step.",
                title: "M486 dream-loop wiring",
                riskLevel: .medium))
        return try XCTUnwrap(result.eBrainTurn)
    }

    // MARK: - 1. kunlun.jade.casket always fires

    func testJadeCasketAlwaysAppears() throws {
        let turn = try runTurn()
        let entry = try XCTUnwrap(turn.sovereignAuditEntry)
        let codes = entry.signalRefs.filter {
            $0.hasPrefix("kunlun.jade.casket:")
        }
        XCTAssertEqual(codes.count, 1,
                       "exactly one kunlun.jade.casket per turn")
        let suffix = codes[0]
            .replacingOccurrences(
                of: "kunlun.jade.casket:", with: "")
        XCTAssertTrue(suffix == "canonical" || suffix == "defective",
                      "casket verdict must be canonical or defective")
    }

    func testJadeCasketIsCanonicalByConstruction() throws {
        let turn = try runTurn()
        let entry = try XCTUnwrap(turn.sovereignAuditEntry)
        // Derive helper synthesizes all 4 ref fields, so the
        // casket should always pass §4.2 jade-canon doctrine.
        XCTAssertTrue(
            entry.signalRefs.contains("kunlun.jade.casket:canonical"),
            "derive helper must produce canonical casket per §4.2")
    }

    // MARK: - 2. ascent branches fire when candidates exist

    func testAscentBranchCountIsParseableInt() throws {
        let turn = try runTurn()
        let entry = try XCTUnwrap(turn.sovereignAuditEntry)
        let codes = entry.signalRefs.filter {
            $0.hasPrefix("kunlun.ascent.branchCount:")
        }
        // When candidates exist, branchCount fires; when 0 it
        // doesn't (per emission guard).
        if !codes.isEmpty {
            XCTAssertEqual(codes.count, 1)
            let suffix = codes[0]
                .replacingOccurrences(
                    of: "kunlun.ascent.branchCount:", with: "")
            XCTAssertNotNil(Int(suffix),
                            "branchCount must be parseable Int")
        }
    }

    /// **Doctrine pin** — every derived ascent branch carries
    /// non-empty returnPathRef (§5.9 dignity invariant).
    /// Test verifies no `kunlun.ascent.dignity-violation` code
    /// fires.
    func testAscentDignityInvariantNeverViolated() throws {
        let turn = try runTurn()
        let entry = try XCTUnwrap(turn.sovereignAuditEntry)
        let violations = entry.signalRefs.filter {
            $0.hasPrefix("kunlun.ascent.dignity-violation:")
        }
        XCTAssertTrue(violations.isEmpty,
                      "Kunlun §5.9 dignity invariant: derive helper must produce branches with return paths")
    }

    // MARK: - 3. return paths fire + dignity honored

    func testReturnPathDignityAlwaysHonoredWhenEmitted() throws {
        let turn = try runTurn()
        let entry = try XCTUnwrap(turn.sovereignAuditEntry)
        let countCodes = entry.signalRefs.filter {
            $0.hasPrefix("kunlun.return.pathCount:")
        }
        let dignityCodes = entry.signalRefs.filter {
            $0.hasPrefix("kunlun.return.dignityHonored:")
        }
        guard !countCodes.isEmpty else {
            return  // no candidates → no return paths emitted
        }
        XCTAssertEqual(countCodes.count, 1)
        XCTAssertEqual(dignityCodes.count, 1)
        // Per derive helper, dignityPreserved is always true.
        let pathSuffix = countCodes[0]
            .replacingOccurrences(
                of: "kunlun.return.pathCount:", with: "")
        let dignitySuffix = dignityCodes[0]
            .replacingOccurrences(
                of: "kunlun.return.dignityHonored:", with: "")
        XCTAssertEqual(pathSuffix, dignitySuffix,
                       "all return paths must honor dignity invariant")
    }

    // MARK: - 4. Single commit mouth pin

    func testPermitModeNotMutatedByDreamLoopWires() throws {
        let turn = try runTurn()
        let entry = try XCTUnwrap(turn.sovereignAuditEntry)
        let permit = turn.actionPermit
        let permitCodes = entry.signalRefs.filter {
            $0.hasPrefix("permit:")
        }
        XCTAssertEqual(permitCodes.count, 1)
        let auditMode = permitCodes[0]
            .replacingOccurrences(of: "permit:", with: "")
        XCTAssertEqual(auditMode, permit.mode.rawValue,
                       "single commit mouth — chapter 一百二十六 wires don't replace permit.mode")
    }

    // MARK: - 5. Determinism

    func testDreamLoopReasonCodesAreDeterministic() throws {
        let turn1 = try runTurn()
        let turn2 = try runTurn()
        let e1 = try XCTUnwrap(turn1.sovereignAuditEntry)
        let e2 = try XCTUnwrap(turn2.sovereignAuditEntry)
        let codes1 = e1.signalRefs
            .filter { $0.hasPrefix("kunlun.ascent.")
                || $0.hasPrefix("kunlun.rest.")
                || $0.hasPrefix("kunlun.return.")
                || $0.hasPrefix("kunlun.jade.casket")
                || $0.hasPrefix("kunlun.refinement.") }
            .sorted()
        let codes2 = e2.signalRefs
            .filter { $0.hasPrefix("kunlun.ascent.")
                || $0.hasPrefix("kunlun.rest.")
                || $0.hasPrefix("kunlun.return.")
                || $0.hasPrefix("kunlun.jade.casket")
                || $0.hasPrefix("kunlun.refinement.") }
            .sorted()
        XCTAssertEqual(codes1, codes2,
                       "chapter 一百二十六 codes deterministic")
    }
}
