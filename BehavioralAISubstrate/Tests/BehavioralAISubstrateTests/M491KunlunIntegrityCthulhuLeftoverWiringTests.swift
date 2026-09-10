import XCTest
@testable import BASAdmin
@testable import BASHostKit
import BASOrchestration
import BASPolicy
import BASRuntimeCore

/// M491-M499 (chapter 一百二十七) — pin the final batch of
/// Kunlun L2/L5/L7 production wires + chapter 一百二十一 Cthulhu
/// leftover wires (organ alias / anchor profile / distortion map
/// / sealed memory) + hostFragility actual computation now flow
/// through `EBrainRuntimeCoordinator.runTurn` audit emission.
final class M491KunlunIntegrityCthulhuLeftoverWiringTests:
    XCTestCase
{
    private func makeRuntimePolicyLineage()
        -> BASRuntimePolicyLineage
    {
        BASRuntimePolicyLineage(
            bundleVersion: "test.m491.bundle.v1",
            providerRoutingRegistryVersion:
                "test.m491.routing-registry.v1",
            providerRoutingPolicyID:
                "test.m491.routing-policy.v1",
            runtimeTuningRegistryVersion:
                "test.m491.tuning-registry.v1",
            runtimeTuningPolicyID:
                "test.m491.tuning-policy.v1",
            resolutionSourceID: "test_bundle"
        )
    }

    private func makeTuning()
        -> BASEBrainRuntimeSynthesisPolicy
    {
        var tuning = BASEBrainRuntimeSynthesisPolicy.generic
            .withSchemaVersion(
                "host.runtime-synthesis.m491.v1")
        tuning.stateTransitions.runModeRules =
            tuning.stateTransitions
                .synthesizedRunModeRules(
                    wakeIntent: tuning.wakeIntent)
        return tuning
    }

    private func makeRuntime() -> BASHostRuntime {
        BASHostRuntime(
            configuration: BASHostConfiguration(
                runtimeProfileID: "host.m491",
                policyProfileID: "host.m491.policy",
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
                prompt: "Test the chapter 一百二十七 audit emission.",
                title: "M491 integrity wiring",
                riskLevel: .medium))
        return try XCTUnwrap(result.eBrainTurn)
    }

    // MARK: - 1. M491 kunlun.jade.fidelity always fires

    func testJadeFidelityAlwaysAppears() throws {
        let turn = try runTurn()
        let entry = try XCTUnwrap(turn.sovereignAuditEntry)
        let codes = entry.signalRefs.filter {
            $0.hasPrefix("kunlun.jade.fidelity:")
        }
        XCTAssertEqual(codes.count, 1,
                       "exactly 1 kunlun.jade.fidelity per turn")
        let suffix = codes[0].replacingOccurrences(
            of: "kunlun.jade.fidelity:", with: "")
        let validLevels: Set<String> = [
            "high", "standard", "partial", "contaminated",
        ]
        XCTAssertTrue(
            validLevels.contains(suffix),
            "fidelity level must be one of high/standard/partial/contaminated; got \(suffix)")
    }

    /// **§3.2 doctrine pin** — `.contaminated` fidelity MUST
    /// emit `kunlun.jade.audit-required:honored` (init-enforced
    /// invariant carried through audit emission).
    func testContaminatedFidelityHonorsAuditInvariant() throws {
        let turn = try runTurn()
        let entry = try XCTUnwrap(turn.sovereignAuditEntry)
        let fidelityCode = entry.signalRefs.first(where: {
            $0.hasPrefix("kunlun.jade.fidelity:")
        })
        guard fidelityCode == "kunlun.jade.fidelity:contaminated"
        else {
            // No contamination on this fixture — no audit-
            // required code should fire.
            let auditRequiredCode = entry.signalRefs.first(where: {
                $0.hasPrefix("kunlun.jade.audit-required:")
            })
            XCTAssertNil(auditRequiredCode,
                "audit-required code only fires on contaminated fidelity")
            return
        }
        let auditRequiredCode = entry.signalRefs.first(where: {
            $0.hasPrefix("kunlun.jade.audit-required:")
        })
        XCTAssertEqual(
            auditRequiredCode,
            "kunlun.jade.audit-required:honored",
            "contaminated fidelity must honor §3.2 audit invariant")
    }

    // MARK: - 2. M492 kunlun.host.register always fires

    func testHostJadeRegisterAlwaysAppears() throws {
        let turn = try runTurn()
        let entry = try XCTUnwrap(turn.sovereignAuditEntry)
        let codes = entry.signalRefs.filter {
            $0.hasPrefix("kunlun.host.register:")
        }
        XCTAssertEqual(codes.count, 1,
                       "exactly 1 kunlun.host.register per turn")
        XCTAssertEqual(
            codes[0], "kunlun.host.register:honored",
            "§5.5 provenance invariant must be honored by construction")
    }

    // MARK: - 3. M493 kunlun.jade.mirror always fires

    func testJadeMirrorDraftAlwaysAppears() throws {
        let turn = try runTurn()
        let entry = try XCTUnwrap(turn.sovereignAuditEntry)
        let codes = entry.signalRefs.filter {
            $0.hasPrefix("kunlun.jade.mirror:")
        }
        XCTAssertEqual(codes.count, 1,
                       "exactly 1 kunlun.jade.mirror per turn")
        XCTAssertEqual(
            codes[0], "kunlun.jade.mirror:honored",
            "§5.7 noInducement invariant must be honored by construction")
    }

    // MARK: - 4. M494 kunlun.unnamable.refCount conditionally

    func testUnnamableRefCountIsParseableInt() throws {
        let turn = try runTurn()
        let entry = try XCTUnwrap(turn.sovereignAuditEntry)
        let codes = entry.signalRefs.filter {
            $0.hasPrefix("kunlun.unnamable.refCount:")
        }
        // Optional emission — only when unknownRefs is non-
        // empty. On a clean fixture confidence is high so refs
        // may be empty → no code.
        if !codes.isEmpty {
            XCTAssertEqual(codes.count, 1,
                "at most 1 kunlun.unnamable.refCount per turn")
            let suffix = codes[0].replacingOccurrences(
                of: "kunlun.unnamable.refCount:", with: "")
            XCTAssertNotNil(Int(suffix),
                "refCount must be parseable Int")
        }
    }

    // MARK: - 5. M495 cthulhu.distortionMap conditionally

    func testDistortionMapCodesParseable() throws {
        let turn = try runTurn()
        let entry = try XCTUnwrap(turn.sovereignAuditEntry)
        let subjectsCodes = entry.signalRefs.filter {
            $0.hasPrefix("cthulhu.distortionMap.subjects:")
        }
        let dominantCodes = entry.signalRefs.filter {
            $0.hasPrefix("cthulhu.distortionMap.dominant:")
        }
        // Both fire together when distortion crosses threshold,
        // otherwise both elide.
        XCTAssertEqual(
            subjectsCodes.count, dominantCodes.count,
            "subjects + dominant codes must fire together")
        if !subjectsCodes.isEmpty {
            let suffix = subjectsCodes[0].replacingOccurrences(
                of: "cthulhu.distortionMap.subjects:",
                with: "")
            XCTAssertNotNil(Int(suffix),
                "subjects count must be parseable Int")
            let domSuffix = dominantCodes[0]
                .replacingOccurrences(
                    of: "cthulhu.distortionMap.dominant:",
                    with: "")
            XCTAssertTrue(
                domSuffix == "true" || domSuffix == "false",
                "dominant flag must be true|false")
        }
    }

    // MARK: - 6. M496 cthulhu.sealed.* conditionally

    func testSealedMemoryCodesPairTogether() throws {
        let turn = try runTurn()
        let entry = try XCTUnwrap(turn.sovereignAuditEntry)
        let classCodes = entry.signalRefs.filter {
            $0.hasPrefix("cthulhu.sealed.class:")
        }
        let disclosureCodes = entry.signalRefs.filter {
            $0.hasPrefix("cthulhu.sealed.disclosure:")
        }
        XCTAssertEqual(
            classCodes.count, disclosureCodes.count,
            "sealed.class + sealed.disclosure must fire together")
    }

    // MARK: - 7. M497 cthulhu.anchor.{dignity,guards} always

    func testHumanAnchorProfileAlwaysAppears() throws {
        let turn = try runTurn()
        let entry = try XCTUnwrap(turn.sovereignAuditEntry)
        let dignityCodes = entry.signalRefs.filter {
            $0.hasPrefix("cthulhu.anchor.dignity:")
        }
        let guardsCodes = entry.signalRefs.filter {
            $0.hasPrefix("cthulhu.anchor.guards:")
        }
        XCTAssertEqual(dignityCodes.count, 1,
            "exactly 1 cthulhu.anchor.dignity per turn")
        XCTAssertEqual(guardsCodes.count, 1,
            "exactly 1 cthulhu.anchor.guards per turn")
        // Default profile carries 3 dignity invariants + 2
        // exploitation guards.
        let dignitySuffix = dignityCodes[0]
            .replacingOccurrences(
                of: "cthulhu.anchor.dignity:", with: "")
        let guardsSuffix = guardsCodes[0]
            .replacingOccurrences(
                of: "cthulhu.anchor.guards:", with: "")
        XCTAssertEqual(dignitySuffix, "3",
            "default profile carries 3 dignity invariants")
        XCTAssertEqual(guardsSuffix, "2",
            "default profile carries 2 exploitation guards")
    }

    // MARK: - 8. M498 cthulhu.organ.alias always fires

    func testOrganAliasAlwaysAppears() throws {
        let turn = try runTurn()
        let entry = try XCTUnwrap(turn.sovereignAuditEntry)
        let codes = entry.signalRefs.filter {
            $0.hasPrefix("cthulhu.organ.alias:")
        }
        XCTAssertEqual(codes.count, 1,
            "exactly 1 cthulhu.organ.alias per turn")
        let suffix = codes[0].replacingOccurrences(
            of: "cthulhu.organ.alias:", with: "")
        let validAliases: Set<String> = [
            "main-core-cortex",
            "counterfactual-forge",
            "critique-blade-core",
            "risk-ridge",
            "old-seal-core",
            "minimal-resonance-core",
        ]
        XCTAssertTrue(
            validAliases.contains(suffix),
            "alias must be one of 6 stable kebab-case values; got \(suffix)")
    }

    // MARK: - 9. Single commit mouth pin

    func testPermitModeNotMutatedByChapter127Wires() throws {
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
            "single commit mouth — chapter 一百二十七 wires don't replace permit.mode")
    }

    // MARK: - 10. Determinism

    func testChapter127CodesAreDeterministic() throws {
        let turn1 = try runTurn()
        let turn2 = try runTurn()
        let e1 = try XCTUnwrap(turn1.sovereignAuditEntry)
        let e2 = try XCTUnwrap(turn2.sovereignAuditEntry)
        let codes1 = e1.signalRefs
            .filter { $0.hasPrefix("kunlun.jade.fidelity")
                || $0.hasPrefix("kunlun.host.register")
                || $0.hasPrefix("kunlun.jade.mirror")
                || $0.hasPrefix("kunlun.unnamable.")
                || $0.hasPrefix("cthulhu.distortionMap.")
                || $0.hasPrefix("cthulhu.sealed.")
                || $0.hasPrefix("cthulhu.anchor.")
                || $0.hasPrefix("cthulhu.organ.alias") }
            .sorted()
        let codes2 = e2.signalRefs
            .filter { $0.hasPrefix("kunlun.jade.fidelity")
                || $0.hasPrefix("kunlun.host.register")
                || $0.hasPrefix("kunlun.jade.mirror")
                || $0.hasPrefix("kunlun.unnamable.")
                || $0.hasPrefix("cthulhu.distortionMap.")
                || $0.hasPrefix("cthulhu.sealed.")
                || $0.hasPrefix("cthulhu.anchor.")
                || $0.hasPrefix("cthulhu.organ.alias") }
            .sorted()
        XCTAssertEqual(codes1, codes2,
            "chapter 一百二十七 codes deterministic across turns")
    }
}
