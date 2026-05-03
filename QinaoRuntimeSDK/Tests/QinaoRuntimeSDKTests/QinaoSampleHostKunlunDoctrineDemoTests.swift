import XCTest
@testable import BASOrchestration
@testable import BASPolicy

/// M414 — pin the contract that the Kunlun doctrine demo's
/// underlying primitives (Kunlun protocol helpers + M406
/// escalation + M412 red-line typed pin) exist + can be exercised
/// in isolation.
///
/// Sample-host demo doesn't have testable executable target
/// symbols (executable target → test target imports fail to
/// link); follow the M333/M334/M335/M403 pattern where sample-
/// host demos pin their substrate primitives rather than re-
/// running the demo from xctest.
///
/// The demo banner output is verified by running
/// `swift run QinaoSampleHost --kunlun-doctrine-demo` (banner
/// content + format assertion is captured in the runtime's
/// stdout, with the final `allInvariantsHold = true` flag
/// verifying every fixture's expected shape).
///
/// What this file pins:
///
///   1. The 7 doctrine-wire primitives the demo banner exercises
///      are callable in isolation.
///   2. Each primitive's happy-path produces the expected output
///      shape.
///   3. The 8 doctrine red-line cases are stable + canonical.
final class QinaoSampleHostKunlunDoctrineDemoTests: XCTestCase {

    // MARK: - 1. M402 axis alignment helper

    func testM402AxisAlignmentCenteredAndOverreaching() {
        let axis = BASKunlunAxis(
            axisID: "ax", hostRef: "h",
            sovereignRef: "s", worldAnchorRef: "w",
            activeLayerRefs: [], agentSeatRefs: [],
            centerlineRules: ["r1", "r2", "r3"],
            deviationThreshold: 0.7,
            lastAlignmentCheck: "")
        let centered = BASKunlunAxisProtocol.computeAlignment(
            alignmentID: "a", axis: axis, targetRef: "t",
            matchedRules: 3, deviationCodes: [])
        XCTAssertEqual(centered.centerScore, 1.0)
        XCTAssertFalse(centered.requiresGate)

        let overreach = BASKunlunAxisProtocol.computeAlignment(
            alignmentID: "a", axis: axis, targetRef: "t",
            matchedRules: 1,
            deviationCodes: ["risk-high-narrows-axis"])
        XCTAssertLessThan(overreach.centerScore, 0.7)
        XCTAssertTrue(overreach.requiresGate)
    }

    // MARK: - 2. M404 jade canon verifier

    func testM404JadeCanonCanonicalAndDefective() {
        let canonical = BASJadeCanonSeal(
            sealID: "s", targetRef: "t",
            objectClass: .actionPermit,
            targetSchemaVersion: "1",
            provenanceRefs: ["src-1"],
            integrityHash: "abc",
            signatureRef: "sig",
            replayRequired: true,
            revocationPath: "rb",
            sourceRiverRef: "river-1")
        let v1 = BASKunlunJadeCanonProtocol.verifySeal(canonical)
        XCTAssertTrue(v1.isCanonical)
        XCTAssertEqual(v1.missingRequirements, [])

        let defective = BASJadeCanonSeal(
            sealID: "s", targetRef: "t",
            objectClass: .actionPermit,
            targetSchemaVersion: "1",
            provenanceRefs: [],
            integrityHash: "",
            signatureRef: "",
            replayRequired: false,
            revocationPath: "",
            sourceRiverRef: "")
        let v2 = BASKunlunJadeCanonProtocol.verifySeal(defective)
        XCTAssertFalse(v2.isCanonical)
        XCTAssertEqual(v2.missingRequirements.count, 4)
    }

    // MARK: - 3. M405 river-origin analyzer

    func testM405RiverOriginAnalyzerWellformedAndPartial() {
        let well = BASRiverOriginTrace(
            traceID: "rv",
            rootSourceRefs: ["root"],
            tributaryRefs: [],
            derivedObjectRefs: [],
            transformationSteps: [],
            consentRefs: [],
            permitRefs: [],
            auditRefs: ["audit"],
            deletionDependents: [],
            lineageCutRefs: [])
        let r1 = BASKunlunRiverOriginProtocol.analyze(well)
        XCTAssertTrue(r1.isWellFormed)

        let partial = BASRiverOriginTrace(
            traceID: "rv",
            rootSourceRefs: [],
            tributaryRefs: [],
            derivedObjectRefs: [],
            transformationSteps: [],
            consentRefs: [],
            permitRefs: [],
            auditRefs: [],
            deletionDependents: [],
            lineageCutRefs: [])
        let r2 = BASKunlunRiverOriginProtocol.analyze(partial)
        XCTAssertFalse(r2.isWellFormed)
        XCTAssertGreaterThanOrEqual(r2.warningCodes.count, 2)
    }

    // MARK: - 4. M406 permit escalation helper exists + works

    func testM406PermitEscalationCallable() {
        // Just smoke-test that the helper signature is callable
        // — full coverage is in M406KunlunPermitEscalationTests.
        let alignment = BASAxisAlignment(
            alignmentID: "a", targetRef: "t", axisRef: "ax",
            centerScore: 0.5,
            deviationCodes: ["risk-medium"],
            correctionHint: "", requiresGate: true)
        let decision = BASKunlunPermitEscalation.escalate(
            permit: BASActionPermit(mode: .answer),
            alignment: alignment,
            humanAnchor: nil)
        XCTAssertTrue(decision.triggered)
        XCTAssertFalse(decision.suppressedByHumanAnchor)
    }

    // MARK: - 5. M408 yaochi access helper

    func testM408YaochiAccessSealedAndConditional() {
        let sealed = BASYaochiSanctumEntry(
            entryID: "y", memoryRef: "m", hostRef: "h",
            sanctumClass: .vow,
            accessPolicy: .sealed,
            revealConditions: [], coolingPeriod: 0,
            humanAnchorRequired: false,
            lastRevealedAt: "")
        let d1 = BASKunlunYaochiProtocol.evaluateAccess(
            entry: sealed, hostAnchorPresent: true,
            matchedRevealConditions: [],
            secondsSinceLastReveal: 1000)
        XCTAssertFalse(d1.granted,
            "sealed policy always denies")

        let conditional = BASYaochiSanctumEntry(
            entryID: "y", memoryRef: "m", hostRef: "h",
            sanctumClass: .precious,
            accessPolicy: .conditional,
            revealConditions: ["host-explicit-recall"],
            coolingPeriod: 60,
            humanAnchorRequired: true,
            lastRevealedAt: "")
        let d2 = BASKunlunYaochiProtocol.evaluateAccess(
            entry: conditional, hostAnchorPresent: true,
            matchedRevealConditions: ["host-explicit-recall"],
            secondsSinceLastReveal: 1000)
        XCTAssertTrue(d2.granted,
            "conditional + matched cond + anchor → granted")
    }

    // MARK: - 6. M409 heaven-gate helper

    func testM409HeavenGateHighAndLowStakes() {
        let highStakes = BASHeavenGatePermit(
            gateID: "g", sourceRef: "s",
            targetDomain: "host-domain",
            gateClass: .host,
            requiredSeals: [],
            actionPermitRef: "permit-1",
            sovereignWarrantRef: "",
            secondCheckRequired: false,
            passState: .passed,
            returnPathRef: "")
        let r1 = BASKunlunHeavenGateProtocol.evaluateReadiness(
            highStakes)
        XCTAssertFalse(r1.isReady)

        let lowStakes = BASHeavenGatePermit(
            gateID: "g", sourceRef: "s",
            targetDomain: "cog-domain",
            gateClass: .cognitive,
            requiredSeals: [],
            actionPermitRef: "permit-1",
            sovereignWarrantRef: "",
            secondCheckRequired: false,
            passState: .passed,
            returnPathRef: "")
        let r2 = BASKunlunHeavenGateProtocol.evaluateReadiness(
            lowStakes)
        XCTAssertTrue(r2.isReady)
    }

    // MARK: - 7. M412 doctrine red-line cardinality

    func testM412DoctrineRedLineCardinalityAndStability() {
        let allCases = BASKunlunDoctrineRedLine.allCases
        XCTAssertEqual(allCases.count, 8)
        for redLine in allCases {
            XCTAssertFalse(redLine.rawValue.isEmpty)
            XCTAssertFalse(redLine.whitePaperRef.isEmpty)
            XCTAssertFalse(redLine.forbiddenSubstrings.isEmpty)
            // Raw values are kebab-case.
            XCTAssertEqual(redLine.rawValue,
                redLine.rawValue.lowercased())
            XCTAssertFalse(redLine.rawValue.contains("_"))
        }
    }

    // MARK: - 8. Cross-doctrine red-line cardinality is 8 + 10

    func testCrossDoctrineRedLineCardinalityIs18() {
        XCTAssertEqual(
            BASKunlunDoctrineRedLine.allCases.count
                + BASAbyssalDoctrineRedLine.allCases.count,
            18,
            "Kunlun (8) + Cthulhu (10) = 18 total doctrine red lines")
    }
}
