import XCTest
@testable import BASOrchestration

/// M403 — pin the contract that the Kunlun schema demo's
/// underlying primitives (`BASKunlunProtocol.swift`) exist + can
/// be exercised in isolation. Sample-host demo doesn't have
/// testable executable target symbols (executable target → test
/// target imports fail to link); follow the M333/M334/M335
/// pattern where sample-host demos pin their substrate primitives
/// rather than re-running the demo from xctest.
///
/// The demo banner output is verified by running
/// `swift run QinaoSampleHost --kunlun-schema-demo` (banner
/// content + format assertion is captured in the runtime's
/// stdout, not in xctest).
///
/// What this file pins:
///
///   1. The 5 protocol-helper enums the demo banner names are
///      callable in isolation.
///   2. Each helper's happy-path returns an expected output
///      structure.
///   3. The schema types' raw values match the banner text
///      claims (kebab-case, white-paper-faithful).
final class QinaoSampleHostKunlunSchemaDemoTests: XCTestCase {

    // MARK: - 1. All 5 protocol helpers callable in isolation

    func testAllFiveProtocolHelpersCallable() {
        // Helper 1: Axis alignment
        let axis = BASKunlunAxis(
            axisID: "ax", hostRef: "h", sovereignRef: "s",
            worldAnchorRef: "w",
            activeLayerRefs: [], agentSeatRefs: [],
            centerlineRules: ["r1"],
            deviationThreshold: 0.5,
            lastAlignmentCheck: "")
        let alignment = BASKunlunAxisProtocol.computeAlignment(
            alignmentID: "a",
            axis: axis,
            targetRef: "t",
            matchedRules: 1,
            deviationCodes: [])
        XCTAssertEqual(alignment.centerScore, 1.0)

        // Helper 2: Jade Canon verification
        let seal = BASJadeCanonSeal(
            sealID: "j", targetRef: "t",
            objectClass: .actionPermit,
            targetSchemaVersion: "1",
            provenanceRefs: ["p"],
            integrityHash: "h",
            signatureRef: "s",
            replayRequired: false,
            revocationPath: "r",
            sourceRiverRef: "rv")
        let v = BASKunlunJadeCanonProtocol.verifySeal(seal)
        XCTAssertTrue(v.isCanonical)

        // Helper 3: Heaven Gate readiness
        let permit = BASHeavenGatePermit(
            gateID: "g", sourceRef: "s",
            targetDomain: "d", gateClass: .cognitive,
            requiredSeals: [], actionPermitRef: "p",
            sovereignWarrantRef: "",
            secondCheckRequired: false,
            passState: .passed,
            returnPathRef: "")
        let r = BASKunlunHeavenGateProtocol
            .evaluateReadiness(permit)
        XCTAssertTrue(r.isReady)

        // Helper 4: Yaochi access
        let entry = BASYaochiSanctumEntry(
            entryID: "y", memoryRef: "m", hostRef: "h",
            sanctumClass: .precious,
            accessPolicy: .auditedOpen,
            revealConditions: [],
            coolingPeriod: 0,
            humanAnchorRequired: false,
            lastRevealedAt: "")
        let d = BASKunlunYaochiProtocol.evaluateAccess(
            entry: entry,
            hostAnchorPresent: true,
            matchedRevealConditions: [],
            secondsSinceLastReveal: 100)
        XCTAssertTrue(d.granted)

        // Helper 5: River-Origin analyze
        let trace = BASRiverOriginTrace(
            traceID: "rv",
            rootSourceRefs: ["src-1"],
            tributaryRefs: [],
            derivedObjectRefs: [],
            transformationSteps: [],
            consentRefs: [],
            permitRefs: [],
            auditRefs: ["a-1"],
            deletionDependents: [],
            lineageCutRefs: [])
        let report = BASKunlunRiverOriginProtocol
            .analyze(trace)
        XCTAssertTrue(report.isWellFormed)
    }

    // MARK: - 2. White-paper-faithful kebab-case raw values

    func testWhitePaperFaithfulKebabCaseRawValues() {
        XCTAssertEqual(
            BASJadeCanonObjectClass.actionPermit.rawValue,
            "action-permit")
        XCTAssertEqual(
            BASYaochiAccessPolicy.auditedOpen.rawValue,
            "audited-open")
        XCTAssertEqual(
            BASYaochiSanctumClass.highWeightRelation.rawValue,
            "high-weight-relation")
    }

    // MARK: - 3. Schema versions are stable

    func testSchemaVersionsAreV1() {
        XCTAssertEqual(
            BASKunlunAxis.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(
            BASAxisAlignment.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(
            BASJadeCanonSeal.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(
            BASHeavenGatePermit.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(
            BASYaochiSanctumEntry.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(
            BASRiverOriginTrace.currentSchemaVersion, "1.0.0")
    }
}
