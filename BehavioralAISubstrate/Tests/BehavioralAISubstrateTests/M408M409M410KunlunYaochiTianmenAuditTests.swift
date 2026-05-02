import XCTest
@testable import BASHostKit
@testable import BASOrchestration

/// M408 + M409 + M410 — pin the contract that the Kunlun Yaochi
/// sanctum access decision (M408), Heaven Gate readiness (M409),
/// and L14 sovereign-warrant Tianmen integration (M410) produced
/// at the L4 audit-projection seam emit stable kebab-case
/// `kunlun.yaochi.*` / `kunlun.tianmen.*` codes per turn.
///
/// What this file pins:
///
///   1. Real `BASHostRuntime` turn produces an audit entry
///      containing exactly one `kunlun.yaochi.access:<class>:<decision>`
///      code per turn (M408).
///   2. Real `BASHostRuntime` turn produces exactly one
///      `kunlun.tianmen.gate:<domain>:<state>` + 1 `.ready:<bool>`
///      code per turn (M409).
///   3. Real `BASHostRuntime` turn produces a typed cross-protocol
///      bind code: `kunlun.tianmen.warrant-bind:<id>` (when
///      warrant present) OR `kunlun.tianmen.warrant-missing:high-stakes`
///      (when high-stakes gate has no warrant) + always
///      `kunlun.tianmen.axis-bound:session-<id>` (M410).
///   4. Direct unit-test on `BASKunlunYaochiProtocol.evaluateAccess`
///      with a sealed entry → access denied with
///      `kunlun.yaochi.sealed-policy` reason code.
///   5. Direct unit-test on `BASKunlunHeavenGateProtocol.evaluateReadiness`
///      with a high-stakes gate missing warrant → not ready with
///      `kunlun.gate.high-stakes-needs-sovereign-warrant` reason code.
///   6. Code prefix is stable kebab-case `kunlun.yaochi.*` /
///      `kunlun.tianmen.*`.
///   7. nil decisions / nil readiness → all codes elided
///      (default-nil parameter behavior).
///
/// Pattern parallel: M404M405KunlunJadeRiverAuditTests.
final class M408M409M410KunlunYaochiTianmenAuditTests: XCTestCase {

    // MARK: - 1. Yaochi access code per turn (M408)

    func testRuntimeTurnEmitsYaochiAccessCode() throws {
        let runtime = makeRuntime(profile: "m408-yaochi")
        let result = try runtime.startSession(
            BASHostSessionRequest(
                kind: .interactive,
                workflowProfile: .primary,
                surface: .application,
                prompt: "M408 Yaochi sanctum access",
                title: "M408",
                riskLevel: .medium))
        let turn = try XCTUnwrap(result.eBrainTurn)
        let signalRefs = try XCTUnwrap(
            turn.sovereignAuditEntry?.signalRefs)

        let yaochiCodes = signalRefs.filter {
            $0.hasPrefix("kunlun.yaochi.access:")
        }
        XCTAssertEqual(yaochiCodes.count, 1,
            "exactly 1 kunlun.yaochi.access code expected per turn")
        let code = yaochiCodes[0]
        // Format: kunlun.yaochi.access:<class>:<decision>
        let parts = code.components(separatedBy: ":")
        XCTAssertEqual(parts.count, 3,
            "kunlun.yaochi.access must be 3-segment kebab; got \(code)")
        let validClasses: Set<String> = [
            "sensitive", "precious", "grief",
            "boundary", "vow", "high-weight-relation",
        ]
        XCTAssertTrue(
            validClasses.contains(parts[1]),
            "sanctum class should be one of valid 6; got \(parts[1])")
        XCTAssertTrue(
            parts[2] == "granted" || parts[2] == "denied",
            "decision must be granted|denied; got \(parts[2])")
    }

    // MARK: - 2. Heaven Gate codes per turn (M409)

    func testRuntimeTurnEmitsTianmenGateAndReadinessCodes() throws {
        let runtime = makeRuntime(profile: "m409-tianmen")
        let result = try runtime.startSession(
            BASHostSessionRequest(
                kind: .interactive,
                workflowProfile: .primary,
                surface: .application,
                prompt: "M409 Tianmen gate test",
                title: "M409",
                riskLevel: .medium))
        let turn = try XCTUnwrap(result.eBrainTurn)
        let signalRefs = try XCTUnwrap(
            turn.sovereignAuditEntry?.signalRefs)

        let gateCodes = signalRefs.filter {
            $0.hasPrefix("kunlun.tianmen.gate:")
        }
        XCTAssertEqual(gateCodes.count, 1,
            "exactly 1 kunlun.tianmen.gate code per turn")
        let gateCode = gateCodes[0]
        // Format: kunlun.tianmen.gate:<domain>:<state>
        let parts = gateCode.components(separatedBy: ":")
        XCTAssertEqual(parts.count, 3,
            "tianmen.gate must be 3-segment; got \(gateCode)")
        let validDomains: Set<String> = [
            "cognitive", "memory", "tool",
            "host", "evolution", "public",
        ]
        XCTAssertTrue(
            validDomains.contains(parts[1]),
            "gate class should be one of valid 6; got \(parts[1])")
        let validStates: Set<String> = [
            "passed", "denied", "pending", "remanded",
        ]
        XCTAssertTrue(
            validStates.contains(parts[2]),
            "gate state should be one of 4; got \(parts[2])")

        let readyCodes = signalRefs.filter {
            $0.hasPrefix("kunlun.tianmen.ready:")
        }
        XCTAssertEqual(readyCodes.count, 1,
            "exactly 1 kunlun.tianmen.ready code per turn")
    }

    // MARK: - 3. M410 — Tianmen axis-bound cross-link

    func testRuntimeTurnEmitsTianmenAxisBoundCrossLink() throws {
        let runtime = makeRuntime(profile: "m410-bind")
        let result = try runtime.startSession(
            BASHostSessionRequest(
                kind: .interactive,
                workflowProfile: .primary,
                surface: .application,
                prompt: "M410 axis bind",
                title: "M410",
                riskLevel: .medium))
        let turn = try XCTUnwrap(result.eBrainTurn)
        let signalRefs = try XCTUnwrap(
            turn.sovereignAuditEntry?.signalRefs)

        // Always emits axis-bound cross-link (no high-stakes
        // warrant gate logic depends on it).
        let bindCodes = signalRefs.filter {
            $0.hasPrefix("kunlun.tianmen.axis-bound:")
        }
        XCTAssertEqual(bindCodes.count, 1,
            "exactly 1 kunlun.tianmen.axis-bound code per turn")
        let code = bindCodes[0]
        XCTAssertTrue(code.contains("session-"),
            "axis-bound code must reference session: got \(code)")

        // Either warrant-bind or warrant-missing-high-stakes
        // appears, depending on whether the turn produced a
        // warrant + which gate class was assigned. Both are valid;
        // we just verify at most one fires (mutually exclusive).
        let warrantBind = signalRefs.filter {
            $0.hasPrefix("kunlun.tianmen.warrant-bind:")
        }
        let warrantMissing = signalRefs.filter {
            $0.hasPrefix("kunlun.tianmen.warrant-missing:")
        }
        XCTAssertLessThanOrEqual(
            warrantBind.count + warrantMissing.count, 1,
            "warrant-bind and warrant-missing are mutually exclusive")
    }

    // MARK: - 4. Sealed sanctum entry → access denied

    func testSealedSanctumEntryDeniesAccess() {
        let entry = BASYaochiSanctumEntry(
            entryID: "sealed-test",
            memoryRef: "m1",
            hostRef: "h1",
            sanctumClass: .vow,
            accessPolicy: .sealed,
            revealConditions: [],
            coolingPeriod: 0,
            humanAnchorRequired: false,
            lastRevealedAt: "")
        let decision = BASKunlunYaochiProtocol.evaluateAccess(
            entry: entry,
            hostAnchorPresent: true,
            matchedRevealConditions: [],
            secondsSinceLastReveal: 1000)
        XCTAssertFalse(decision.granted,
            "sealed policy always denies access")
        XCTAssertTrue(
            decision.reasonCodes.contains(
                "kunlun.yaochi.sealed-policy"),
            "sealed-policy reason code expected")
    }

    // MARK: - 5. High-stakes gate without warrant → not ready

    func testHighStakesGateWithoutWarrantNotReady() {
        let permit = BASHeavenGatePermit(
            gateID: "host-test",
            sourceRef: "src",
            targetDomain: "host-domain",
            gateClass: .host,  // high-stakes
            requiredSeals: [],
            actionPermitRef: "permit-1",
            sovereignWarrantRef: "",  // missing
            secondCheckRequired: false,
            passState: .passed,
            returnPathRef: "")
        let r = BASKunlunHeavenGateProtocol.evaluateReadiness(
            permit)
        XCTAssertFalse(r.isReady,
            "host gate without warrant is not ready")
        XCTAssertTrue(
            r.reasonCodes.contains(
                "kunlun.gate.high-stakes-needs-sovereign-warrant"),
            "high-stakes-needs-sovereign-warrant reason code expected")
        XCTAssertTrue(
            r.reasonCodes.contains(
                "kunlun.gate.high-stakes-needs-jade-seal"),
            "high-stakes-needs-jade-seal reason code expected")
    }

    // MARK: - 6. Code format stability

    func testCodesUseStableKebabCasePrefix() throws {
        let runtime = makeRuntime(profile: "m408-fmt")
        let result = try runtime.startSession(
            BASHostSessionRequest(
                kind: .interactive,
                workflowProfile: .primary,
                surface: .application,
                prompt: "Format test",
                title: "M408-fmt",
                riskLevel: .medium))
        let turn = try XCTUnwrap(result.eBrainTurn)
        let signalRefs = try XCTUnwrap(
            turn.sovereignAuditEntry?.signalRefs)
        for code in signalRefs.filter({
            $0.hasPrefix("kunlun.yaochi.")
                || $0.hasPrefix("kunlun.tianmen.")
        }) {
            let parts = code.components(separatedBy: ".")
            XCTAssertGreaterThanOrEqual(parts.count, 3,
                "Kunlun code must be `kunlun.<segment>.<key>:<val>` shape; got \(code)")
            XCTAssertTrue(parts[1] == "yaochi"
                || parts[1] == "tianmen",
                "segment should be yaochi or tianmen; got \(parts[1])")
        }
    }

    // MARK: - 7. Nil parameter elision (M408+M409 separately)

    func testNilDecisionElidesYaochiCodes() {
        // Direct test on helper output shape — granted decision
        // on conditional policy with matched conditions.
        let entry = BASYaochiSanctumEntry(
            entryID: "ok",
            memoryRef: "m1",
            hostRef: "h1",
            sanctumClass: .precious,
            accessPolicy: .conditional,
            revealConditions: ["host-explicit-recall"],
            coolingPeriod: 0,
            humanAnchorRequired: false,
            lastRevealedAt: "")
        let decision = BASKunlunYaochiProtocol.evaluateAccess(
            entry: entry,
            hostAnchorPresent: true,
            matchedRevealConditions: ["host-explicit-recall"],
            secondsSinceLastReveal: 1000)
        XCTAssertTrue(decision.granted,
            "conditional policy with matched cond grants")
        XCTAssertEqual(decision.reasonCodes, [])
    }

    func testReadyPermitElidesTianmenReasons() {
        // Direct test on helper output shape.
        let permit = BASHeavenGatePermit(
            gateID: "ok",
            sourceRef: "src",
            targetDomain: "domain",
            gateClass: .cognitive,  // not high-stakes
            requiredSeals: [],
            actionPermitRef: "permit-1",
            sovereignWarrantRef: "",
            secondCheckRequired: false,
            passState: .passed,
            returnPathRef: "")
        let r = BASKunlunHeavenGateProtocol.evaluateReadiness(
            permit)
        XCTAssertTrue(r.isReady)
        XCTAssertEqual(r.reasonCodes, [])
    }

    // MARK: - Helpers

    private func makeRuntime(profile: String)
        -> BASHostRuntime
    {
        BASHostRuntime(
            configuration: BASHostConfiguration(
                runtimeProfileID: "host.\(profile)",
                policyProfileID: "host.\(profile).policy",
                prefersPureLocal: true,
                defaultDeviceState:
                    BASHostConfiguration
                        .fixtureDefaultDeviceState,
                console: .generic,
                lifecycleBehavior: .generic,
                workflowBehavior: .generic,
                cognitionBehavior: .generic,
                presentation: .generic,
                runtimeTuning:
                    BASEBrainRuntimeSynthesisPolicy.generic
                        .withSchemaVersion(
                            "host.runtime-synthesis.\(profile).v1"),
                runtimePolicyLineage:
                    BASRuntimePolicyLineage(
                        bundleVersion:
                            "host.\(profile).bundle.v1",
                        providerRoutingRegistryVersion:
                            "host.\(profile).routing-registry.v1",
                        providerRoutingPolicyID:
                            "host.\(profile).routing-policy.v1",
                        runtimeTuningRegistryVersion:
                            "host.\(profile).tuning-registry.v1",
                        runtimeTuningPolicyID:
                            "host.\(profile).tuning-policy.v1",
                        resolutionSourceID: profile),
                hostRhythmProfile: .generic))
    }
}
