import XCTest
@testable import BASOrchestration

/// M417.7 — chapter 九十七 deep-review L5 fix-pin.
///
/// `EBrainRuntimeCoordinator+SovereignCommit.swift` strips the
/// known prefix (`kunlun.yaochi.` for Yaochi; `kunlun.gate.` for
/// Tianmen) from `evaluateAccess` / `evaluateReadiness` reason
/// codes before re-joining them under outer keys
/// `kunlun.yaochi.reasons:` / `kunlun.tianmen.reasons:`.
///
/// The strip-and-rejoin logic depends on an implicit prefix
/// contract between the protocol helpers (`BASKunlunYaochiProtocol`,
/// `BASKunlunHeavenGateProtocol`) and their consumers. If a future
/// helper case grows a different prefix (e.g. `kunlun.sanctum.` or
/// no prefix), the strip-and-rejoin silently fails — the consumer
/// passes through the un-prefixed code, breaking audit-walker
/// grep on the outer `kunlun.yaochi.reasons:` key.
///
/// This test pins the prefix contract so future drift fails
/// loudly rather than silently corrupts the audit-emission
/// concatenation.
final class M417_7KunlunHelperPrefixContractTests: XCTestCase {

    // MARK: - 1. BASKunlunYaochiProtocol prefix contract

    /// Every reason code emitted by `BASKunlunYaochiProtocol
    /// .evaluateAccess` MUST start with `kunlun.yaochi.`. The
    /// audit emission's strip step (in `buildSovereignAuditEntry`)
    /// depends on this; drift would silently break.
    func testYaochiAccessHelperEmitsKunlunYaochiPrefixedCodes() {
        // Sweep multiple input combos to exercise every code
        // path in `evaluateAccess`.
        struct Fixture {
            let entry: BASYaochiSanctumEntry
            let hostAnchorPresent: Bool
            let matchedRevealConditions: [String]
            let secondsSinceLastReveal: TimeInterval
            let label: String
        }
        let fixtures: [Fixture] = [
            // sealed policy — emits sealed-policy
            Fixture(
                entry: BASYaochiSanctumEntry(
                    entryID: "y1", memoryRef: "m", hostRef: "h",
                    sanctumClass: .vow,
                    accessPolicy: .sealed,
                    revealConditions: [],
                    coolingPeriod: 0,
                    humanAnchorRequired: false,
                    lastRevealedAt: ""),
                hostAnchorPresent: true,
                matchedRevealConditions: [],
                secondsSinceLastReveal: 1000,
                label: "sealed"),
            // conditional + no matched cond — emits no-matched
            Fixture(
                entry: BASYaochiSanctumEntry(
                    entryID: "y2", memoryRef: "m", hostRef: "h",
                    sanctumClass: .precious,
                    accessPolicy: .conditional,
                    revealConditions: ["host-explicit-recall"],
                    coolingPeriod: 0,
                    humanAnchorRequired: false,
                    lastRevealedAt: ""),
                hostAnchorPresent: true,
                matchedRevealConditions: [],
                secondsSinceLastReveal: 1000,
                label: "no-match"),
            // cooling-period active — emits cooling-period-active
            Fixture(
                entry: BASYaochiSanctumEntry(
                    entryID: "y3", memoryRef: "m", hostRef: "h",
                    sanctumClass: .grief,
                    accessPolicy: .auditedOpen,
                    revealConditions: [],
                    coolingPeriod: 100,
                    humanAnchorRequired: false,
                    lastRevealedAt: ""),
                hostAnchorPresent: true,
                matchedRevealConditions: [],
                secondsSinceLastReveal: 50,
                label: "cooling"),
            // human-anchor required + absent — emits human-anchor-
            // required
            Fixture(
                entry: BASYaochiSanctumEntry(
                    entryID: "y4", memoryRef: "m", hostRef: "h",
                    sanctumClass: .boundary,
                    accessPolicy: .auditedOpen,
                    revealConditions: [],
                    coolingPeriod: 0,
                    humanAnchorRequired: true,
                    lastRevealedAt: ""),
                hostAnchorPresent: false,
                matchedRevealConditions: [],
                secondsSinceLastReveal: 1000,
                label: "anchor-required"),
            // multiple denial reasons compose
            Fixture(
                entry: BASYaochiSanctumEntry(
                    entryID: "y5", memoryRef: "m", hostRef: "h",
                    sanctumClass: .highWeightRelation,
                    accessPolicy: .sealed,
                    revealConditions: [],
                    coolingPeriod: 100,
                    humanAnchorRequired: true,
                    lastRevealedAt: ""),
                hostAnchorPresent: false,
                matchedRevealConditions: [],
                secondsSinceLastReveal: 50,
                label: "compound"),
        ]

        let kunlunYaochiPrefix = "kunlun.yaochi."
        for fixture in fixtures {
            let decision = BASKunlunYaochiProtocol
                .evaluateAccess(
                    entry: fixture.entry,
                    hostAnchorPresent: fixture.hostAnchorPresent,
                    matchedRevealConditions:
                        fixture.matchedRevealConditions,
                    secondsSinceLastReveal:
                        fixture.secondsSinceLastReveal)
            // When access denied, every reason code must carry
            // the contract prefix. (Granted access yields empty
            // reasonCodes, which trivially satisfies.)
            for code in decision.reasonCodes {
                XCTAssertTrue(
                    code.hasPrefix(kunlunYaochiPrefix),
                    "Yaochi reason code must start with \(kunlunYaochiPrefix); got '\(code)' from fixture '\(fixture.label)'")
            }
        }
    }

    // MARK: - 2. BASKunlunHeavenGateProtocol prefix contract

    /// Every reason code emitted by `BASKunlunHeavenGateProtocol
    /// .evaluateReadiness` MUST start with `kunlun.gate.`. The
    /// audit emission's strip step depends on this; drift would
    /// silently break the `kunlun.tianmen.reasons:` outer key.
    func testHeavenGateHelperEmitsKunlunGatePrefixedCodes() {
        struct Fixture {
            let permit: BASHeavenGatePermit
            let label: String
        }
        let fixtures: [Fixture] = [
            // missing action permit — emits missing-action-permit
            Fixture(
                permit: BASHeavenGatePermit(
                    gateID: "g1", sourceRef: "s",
                    targetDomain: "d",
                    gateClass: .cognitive,
                    requiredSeals: [],
                    actionPermitRef: "",
                    sovereignWarrantRef: "",
                    secondCheckRequired: false,
                    passState: .pending,
                    returnPathRef: ""),
                label: "missing-permit"),
            // high-stakes without warrant — emits high-stakes-
            // needs-sovereign-warrant + high-stakes-needs-jade-seal
            Fixture(
                permit: BASHeavenGatePermit(
                    gateID: "g2", sourceRef: "s",
                    targetDomain: "host-domain",
                    gateClass: .host,
                    requiredSeals: [],
                    actionPermitRef: "permit-1",
                    sovereignWarrantRef: "",
                    secondCheckRequired: false,
                    passState: .passed,
                    returnPathRef: ""),
                label: "host-no-warrant"),
            Fixture(
                permit: BASHeavenGatePermit(
                    gateID: "g3", sourceRef: "s",
                    targetDomain: "evolution-domain",
                    gateClass: .evolution,
                    requiredSeals: [],
                    actionPermitRef: "permit-1",
                    sovereignWarrantRef: "",
                    secondCheckRequired: false,
                    passState: .passed,
                    returnPathRef: ""),
                label: "evolution-no-warrant"),
            Fixture(
                permit: BASHeavenGatePermit(
                    gateID: "g4", sourceRef: "s",
                    targetDomain: "public-domain",
                    gateClass: .public,
                    requiredSeals: [],
                    actionPermitRef: "permit-1",
                    sovereignWarrantRef: "",
                    secondCheckRequired: false,
                    passState: .passed,
                    returnPathRef: ""),
                label: "public-no-warrant"),
            // already-denied — emits already-denied
            Fixture(
                permit: BASHeavenGatePermit(
                    gateID: "g5", sourceRef: "s",
                    targetDomain: "d",
                    gateClass: .cognitive,
                    requiredSeals: [],
                    actionPermitRef: "permit-1",
                    sovereignWarrantRef: "",
                    secondCheckRequired: false,
                    passState: .denied,
                    returnPathRef: ""),
                label: "denied"),
            // remanded — emits remanded-needs-rework
            Fixture(
                permit: BASHeavenGatePermit(
                    gateID: "g6", sourceRef: "s",
                    targetDomain: "d",
                    gateClass: .cognitive,
                    requiredSeals: [],
                    actionPermitRef: "permit-1",
                    sovereignWarrantRef: "",
                    secondCheckRequired: false,
                    passState: .remanded,
                    returnPathRef: ""),
                label: "remanded"),
            // pending — fires implicit "not passed" path
            Fixture(
                permit: BASHeavenGatePermit(
                    gateID: "g7", sourceRef: "s",
                    targetDomain: "d",
                    gateClass: .cognitive,
                    requiredSeals: [],
                    actionPermitRef: "permit-1",
                    sovereignWarrantRef: "",
                    secondCheckRequired: false,
                    passState: .pending,
                    returnPathRef: ""),
                label: "pending"),
        ]

        let kunlunGatePrefix = "kunlun.gate."
        for fixture in fixtures {
            let readiness = BASKunlunHeavenGateProtocol
                .evaluateReadiness(fixture.permit)
            for code in readiness.reasonCodes {
                XCTAssertTrue(
                    code.hasPrefix(kunlunGatePrefix),
                    "Heaven Gate reason code must start with \(kunlunGatePrefix); got '\(code)' from fixture '\(fixture.label)'")
            }
        }
    }

    // MARK: - 3. River-Origin warning prefix contract

    /// `BASKunlunRiverOriginProtocol.analyze` emits warning codes
    /// with prefix `kunlun.river.`. The audit emission emits them
    /// directly under `kunlun.river.warnings:` outer key (no
    /// prefix-stripping). But still — pinning the prefix
    /// contract here so future drift fails loudly.
    func testRiverOriginAnalyzerEmitsKunlunRiverPrefixedWarnings() {
        let prefix = "kunlun.river."
        // Trace with all 4 warning conditions firing.
        let trace = BASRiverOriginTrace(
            traceID: "test",
            rootSourceRefs: [],
            tributaryRefs: [],
            derivedObjectRefs: ["d1"],
            transformationSteps: [],
            consentRefs: [],
            permitRefs: [],
            auditRefs: [],
            deletionDependents: ["x"],
            lineageCutRefs: [])
        let report = BASKunlunRiverOriginProtocol.analyze(trace)
        XCTAssertGreaterThanOrEqual(report.warningCodes.count, 4,
            "all 4 warning conditions should fire")
        for code in report.warningCodes {
            XCTAssertTrue(
                code.hasPrefix(prefix),
                "River-Origin warning must start with \(prefix); got '\(code)'")
        }
    }
}
