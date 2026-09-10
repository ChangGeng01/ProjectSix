import XCTest
@testable import BASOrchestration

/// M401 — schema parity tests for `BASKunlunProtocol.swift`. Pin
/// the 5 typed schemas + 5 protocol helpers + 4 helper enums
/// against the white paper's §4.1-§4.5 field lists.
///
/// What this file pins:
///
///   1. Each schema's Codable round-trip is byte-stable.
///   2. Each enum's raw values match white-paper canonical kebab-
///      case form.
///   3. Each enum's case count is fixed (drift detector).
///   4. Each protocol helper's pure-function output is correct
///      for canonical inputs.
///   5. Each schema clamps numeric fields to [0, 1] / [0, ∞)
///      where the white paper requires.
///   6. `isCanonicallySealed` / `isWellFormed` predicates honor
///      the four-canonical-doctrine / two-canonical-condition
///      pins.
final class BASKunlunProtocolTests: XCTestCase {

    // MARK: - 1. Enum cardinality + raw values

    func testJadeCanonObjectClassCardinalityAndRawValues() {
        XCTAssertEqual(
            BASJadeCanonObjectClass.allCases.count, 8,
            "white paper §4.2 lists 8 canonical object classes")
        XCTAssertEqual(
            BASJadeCanonObjectClass.actionPermit.rawValue,
            "action-permit")
        XCTAssertEqual(
            BASJadeCanonObjectClass.sovereignWarrant.rawValue,
            "sovereign-warrant")
        XCTAssertEqual(
            BASJadeCanonObjectClass.hostVersion.rawValue,
            "host-version")
        XCTAssertEqual(
            BASJadeCanonObjectClass.ruleCandidate.rawValue,
            "rule-candidate")
        XCTAssertEqual(
            BASJadeCanonObjectClass.rollbackWrit.rawValue,
            "rollback-writ")
        XCTAssertEqual(
            BASJadeCanonObjectClass.updateTicket.rawValue,
            "update-ticket")
        XCTAssertEqual(
            BASJadeCanonObjectClass.memoryAtom.rawValue,
            "memory-atom")
        XCTAssertEqual(
            BASJadeCanonObjectClass.forgetCascade.rawValue,
            "forget-cascade")
    }

    func testKunlunGateClassCardinality() {
        XCTAssertEqual(
            BASKunlunGateClass.allCases.count, 6,
            "white paper §4.3 lists 6 gate classes")
        let names = Set(
            BASKunlunGateClass.allCases.map(\.rawValue))
        XCTAssertEqual(names, [
            "cognitive", "memory", "tool",
            "host", "evolution", "public",
        ])
    }

    func testKunlunGateStateCardinality() {
        XCTAssertEqual(
            BASKunlunGateState.allCases.count, 4)
        XCTAssertEqual(
            Set(BASKunlunGateState.allCases.map(\.rawValue)),
            ["pending", "passed", "denied", "remanded"])
    }

    func testYaochiSanctumClassCardinality() {
        XCTAssertEqual(
            BASYaochiSanctumClass.allCases.count, 6,
            "white paper §4.4 lists 6 sanctum classes")
        XCTAssertTrue(
            BASYaochiSanctumClass.allCases
                .contains(.highWeightRelation))
        XCTAssertEqual(
            BASYaochiSanctumClass.highWeightRelation.rawValue,
            "high-weight-relation")
    }

    func testYaochiAccessPolicyCardinality() {
        XCTAssertEqual(
            BASYaochiAccessPolicy.allCases.count, 3)
        XCTAssertEqual(
            BASYaochiAccessPolicy.auditedOpen.rawValue,
            "audited-open")
    }

    // MARK: - 2. Schema Codable round-trips

    func testKunlunAxisCodableRoundTrip() throws {
        let original = BASKunlunAxis(
            axisID: "axis-host-A",
            hostRef: "host-A",
            sovereignRef: "sov-A",
            worldAnchorRef: "world-A",
            activeLayerRefs: ["L1", "L4", "L11", "L14"],
            agentSeatRefs: ["seat-scout", "seat-planner"],
            centerlineRules: [
                "respects-host-boundary",
                "honors-world-anchor",
            ],
            deviationThreshold: 0.7,
            lastAlignmentCheck: "audit-1")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASKunlunAxis.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testAxisAlignmentCodableRoundTrip() throws {
        let original = BASAxisAlignment(
            alignmentID: "align-1",
            targetRef: "candidate-1",
            axisRef: "axis-host-A",
            centerScore: 0.75,
            deviationCodes: ["misses-host-boundary"],
            correctionHint: "Re-anchor to host's stated value",
            requiresGate: true)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASAxisAlignment.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testJadeCanonSealCodableRoundTrip() throws {
        let original = BASJadeCanonSeal(
            sealID: "jade-1",
            targetRef: "permit-1",
            objectClass: .actionPermit,
            targetSchemaVersion: "2.0.0",
            provenanceRefs: ["src-1", "src-2"],
            integrityHash: "sha256:abc",
            signatureRef: "sig-ed25519-1",
            replayRequired: true,
            revocationPath: "rollback-1",
            sourceRiverRef: "river-1")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASJadeCanonSeal.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testHeavenGatePermitCodableRoundTrip() throws {
        let original = BASHeavenGatePermit(
            gateID: "gate-1",
            sourceRef: "draft-1",
            targetDomain: "external-surface",
            gateClass: .public,
            requiredSeals: ["jade-1", "jade-2"],
            actionPermitRef: "permit-1",
            sovereignWarrantRef: "warrant-1",
            secondCheckRequired: true,
            passState: .pending,
            returnPathRef: "rollback-1")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASHeavenGatePermit.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testYaochiSanctumEntryCodableRoundTrip() throws {
        let original = BASYaochiSanctumEntry(
            entryID: "yao-1",
            memoryRef: "mem-1",
            hostRef: "host-A",
            sanctumClass: .grief,
            accessPolicy: .conditional,
            revealConditions: [
                "host-explicit-recall",
                "anchor-tone-warm",
            ],
            coolingPeriod: 86400,
            humanAnchorRequired: true,
            lastRevealedAt: "audit-yao-1")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASYaochiSanctumEntry.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testRiverOriginTraceCodableRoundTrip() throws {
        let original = BASRiverOriginTrace(
            traceID: "river-1",
            rootSourceRefs: ["src-doc-1"],
            tributaryRefs: ["trib-1"],
            derivedObjectRefs: ["candidate-1", "rule-1"],
            transformationSteps: [
                "extract", "validate", "normalize",
            ],
            consentRefs: ["consent-1"],
            permitRefs: ["permit-1"],
            auditRefs: ["audit-1"],
            deletionDependents: ["mem-1"],
            lineageCutRefs: [])
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASRiverOriginTrace.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - 3. Schema field clamping

    func testKunlunAxisClampsDeviationThresholdTo01() {
        let lower = BASKunlunAxis(
            axisID: "a",
            hostRef: "h",
            sovereignRef: "s",
            worldAnchorRef: "w",
            activeLayerRefs: [],
            agentSeatRefs: [],
            centerlineRules: [],
            deviationThreshold: -0.5,
            lastAlignmentCheck: "")
        XCTAssertEqual(lower.deviationThreshold, 0.0)
        let upper = BASKunlunAxis(
            axisID: "a",
            hostRef: "h",
            sovereignRef: "s",
            worldAnchorRef: "w",
            activeLayerRefs: [],
            agentSeatRefs: [],
            centerlineRules: [],
            deviationThreshold: 5.0,
            lastAlignmentCheck: "")
        XCTAssertEqual(upper.deviationThreshold, 1.0)
    }

    func testAxisAlignmentClampsCenterScoreTo01() {
        let lower = BASAxisAlignment(
            alignmentID: "a",
            targetRef: "t",
            axisRef: "ax",
            centerScore: -2.0,
            deviationCodes: [],
            correctionHint: "",
            requiresGate: false)
        XCTAssertEqual(lower.centerScore, 0.0)
        let upper = BASAxisAlignment(
            alignmentID: "a",
            targetRef: "t",
            axisRef: "ax",
            centerScore: 9.9,
            deviationCodes: [],
            correctionHint: "",
            requiresGate: false)
        XCTAssertEqual(upper.centerScore, 1.0)
    }

    func testYaochiSanctumEntryClampsCoolingPeriodToNonNegative() {
        let entry = BASYaochiSanctumEntry(
            entryID: "y",
            memoryRef: "m",
            hostRef: "h",
            sanctumClass: .vow,
            accessPolicy: .sealed,
            revealConditions: [],
            coolingPeriod: -100,
            humanAnchorRequired: true,
            lastRevealedAt: "")
        XCTAssertEqual(entry.coolingPeriod, 0)
    }

    // MARK: - 4. JadeCanonSeal canonical-sealed predicate

    func testJadeCanonSealIsCanonicallySealedWhenAllFourPresent() {
        let canonical = BASJadeCanonSeal(
            sealID: "j",
            targetRef: "t",
            objectClass: .actionPermit,
            targetSchemaVersion: "1.0.0",
            provenanceRefs: ["src-1"],
            integrityHash: "hash-x",
            signatureRef: "sig-x",
            replayRequired: false,
            revocationPath: "rollback-x",
            sourceRiverRef: "river-x")
        XCTAssertTrue(canonical.isCanonicallySealed)
    }

    func testJadeCanonSealNotCanonicallySealedWhenAnyMissing() {
        let missingProv = BASJadeCanonSeal(
            sealID: "j",
            targetRef: "t",
            objectClass: .actionPermit,
            targetSchemaVersion: "1.0.0",
            provenanceRefs: [],
            integrityHash: "hash-x",
            signatureRef: "sig-x",
            replayRequired: false,
            revocationPath: "rollback-x",
            sourceRiverRef: "river-x")
        XCTAssertFalse(missingProv.isCanonicallySealed)

        let missingSig = BASJadeCanonSeal(
            sealID: "j",
            targetRef: "t",
            objectClass: .actionPermit,
            targetSchemaVersion: "1.0.0",
            provenanceRefs: ["src-1"],
            integrityHash: "hash-x",
            signatureRef: "",
            replayRequired: false,
            revocationPath: "rollback-x",
            sourceRiverRef: "river-x")
        XCTAssertFalse(missingSig.isCanonicallySealed)

        let missingRevoke = BASJadeCanonSeal(
            sealID: "j",
            targetRef: "t",
            objectClass: .actionPermit,
            targetSchemaVersion: "1.0.0",
            provenanceRefs: ["src-1"],
            integrityHash: "hash-x",
            signatureRef: "sig-x",
            replayRequired: false,
            revocationPath: "",
            sourceRiverRef: "river-x")
        XCTAssertFalse(missingRevoke.isCanonicallySealed)
    }

    // MARK: - 5. RiverOriginTrace well-formedness

    func testRiverOriginTraceIsWellFormedWhenRootAndAuditPresent() {
        let wellFormed = BASRiverOriginTrace(
            traceID: "r",
            rootSourceRefs: ["src-1"],
            tributaryRefs: [],
            derivedObjectRefs: [],
            transformationSteps: [],
            consentRefs: [],
            permitRefs: [],
            auditRefs: ["audit-1"],
            deletionDependents: [],
            lineageCutRefs: [])
        XCTAssertTrue(wellFormed.isWellFormed)
    }

    func testRiverOriginTraceNotWellFormedWhenRootEmpty() {
        let noRoot = BASRiverOriginTrace(
            traceID: "r",
            rootSourceRefs: [],
            tributaryRefs: ["trib-1"],
            derivedObjectRefs: [],
            transformationSteps: [],
            consentRefs: [],
            permitRefs: [],
            auditRefs: ["audit-1"],
            deletionDependents: [],
            lineageCutRefs: [])
        XCTAssertFalse(noRoot.isWellFormed)
    }

    func testRiverOriginTraceNotWellFormedWhenAuditEmpty() {
        let noAudit = BASRiverOriginTrace(
            traceID: "r",
            rootSourceRefs: ["src-1"],
            tributaryRefs: [],
            derivedObjectRefs: [],
            transformationSteps: [],
            consentRefs: [],
            permitRefs: [],
            auditRefs: [],
            deletionDependents: [],
            lineageCutRefs: [])
        XCTAssertFalse(noAudit.isWellFormed)
    }

    // MARK: - 6. Protocol helper: Axis Alignment

    func testComputeAlignmentFullySatisfiedReturnsCenterScore1() {
        let axis = BASKunlunAxis(
            axisID: "ax-1",
            hostRef: "h",
            sovereignRef: "s",
            worldAnchorRef: "w",
            activeLayerRefs: [],
            agentSeatRefs: [],
            centerlineRules: [
                "rule-A", "rule-B", "rule-C",
            ],
            deviationThreshold: 0.7,
            lastAlignmentCheck: "")
        let result = BASKunlunAxisProtocol.computeAlignment(
            alignmentID: "al-1",
            axis: axis,
            targetRef: "tgt-1",
            matchedRules: 3,
            deviationCodes: [])
        XCTAssertEqual(result.centerScore, 1.0)
        XCTAssertFalse(result.requiresGate,
                       "fully aligned target should not need gate")
        XCTAssertEqual(result.deviationCodes, [])
    }

    func testComputeAlignmentBelowThresholdRequiresGate() {
        let axis = BASKunlunAxis(
            axisID: "ax-1",
            hostRef: "h",
            sovereignRef: "s",
            worldAnchorRef: "w",
            activeLayerRefs: [],
            agentSeatRefs: [],
            centerlineRules: [
                "rule-A", "rule-B", "rule-C", "rule-D",
            ],
            deviationThreshold: 0.7,
            lastAlignmentCheck: "")
        // 2 of 4 = 0.5 score → below 0.7 threshold → gate.
        let result = BASKunlunAxisProtocol.computeAlignment(
            alignmentID: "al-1",
            axis: axis,
            targetRef: "tgt-1",
            matchedRules: 2,
            deviationCodes: ["misses-rule-C"])
        XCTAssertEqual(result.centerScore, 0.5)
        XCTAssertTrue(result.requiresGate)
        XCTAssertEqual(result.deviationCodes,
                       ["misses-rule-C"])
    }

    func testComputeAlignmentDeviationCodesAlwaysGate() {
        // Even with full match count, a non-empty deviation
        // code list forces requiresGate (red-tier deviation
        // semantics).
        let axis = BASKunlunAxis(
            axisID: "ax-1",
            hostRef: "h",
            sovereignRef: "s",
            worldAnchorRef: "w",
            activeLayerRefs: [],
            agentSeatRefs: [],
            centerlineRules: ["rule-A"],
            deviationThreshold: 0.7,
            lastAlignmentCheck: "")
        let result = BASKunlunAxisProtocol.computeAlignment(
            alignmentID: "al-1",
            axis: axis,
            targetRef: "tgt-1",
            matchedRules: 1,
            deviationCodes: ["red-tier-violation"])
        XCTAssertEqual(result.centerScore, 1.0)
        XCTAssertTrue(result.requiresGate,
                      "red-tier deviation must force gate even " +
                      "when score is 1.0")
    }

    // MARK: - 7. Protocol helper: Jade Canon

    func testJadeCanonVerifyCanonicalSealReturnsCanonical() {
        let seal = BASJadeCanonSeal(
            sealID: "j",
            targetRef: "t",
            objectClass: .hostVersion,
            targetSchemaVersion: "1.0.0",
            provenanceRefs: ["src-1"],
            integrityHash: "hash-x",
            signatureRef: "sig-x",
            replayRequired: true,
            revocationPath: "rollback-x",
            sourceRiverRef: "river-x")
        let v = BASKunlunJadeCanonProtocol.verifySeal(seal)
        XCTAssertTrue(v.isCanonical)
        XCTAssertEqual(v.missingRequirements, [])
    }

    func testJadeCanonVerifyAllFourMissingReportsAllFour() {
        let seal = BASJadeCanonSeal(
            sealID: "j",
            targetRef: "t",
            objectClass: .hostVersion,
            targetSchemaVersion: "1.0.0",
            provenanceRefs: [],
            integrityHash: "",
            signatureRef: "",
            replayRequired: false,
            revocationPath: "",
            sourceRiverRef: "")
        let v = BASKunlunJadeCanonProtocol.verifySeal(seal)
        XCTAssertFalse(v.isCanonical)
        XCTAssertEqual(v.missingRequirements.count, 4)
        XCTAssertTrue(v.missingRequirements.contains {
            $0.contains("provenance-empty")
        })
        XCTAssertTrue(v.missingRequirements.contains {
            $0.contains("signature-missing")
        })
        XCTAssertTrue(v.missingRequirements.contains {
            $0.contains("integrity-hash-missing")
        })
        XCTAssertTrue(v.missingRequirements.contains {
            $0.contains("revocation-path-missing")
        })
    }

    // MARK: - 8. Protocol helper: Heaven Gate

    func testHeavenGateLowStakesPassesWithoutWarrant() {
        let permit = BASHeavenGatePermit(
            gateID: "g",
            sourceRef: "s",
            targetDomain: "memory-cold",
            gateClass: .memory,
            requiredSeals: [],
            actionPermitRef: "permit-1",
            sovereignWarrantRef: "",
            secondCheckRequired: false,
            passState: .passed,
            returnPathRef: "")
        let r = BASKunlunHeavenGateProtocol
            .evaluateReadiness(permit)
        XCTAssertTrue(r.isReady)
        XCTAssertEqual(r.reasonCodes, [])
    }

    func testHeavenGateHighStakesNeedsWarrantAndSeals() {
        let permit = BASHeavenGatePermit(
            gateID: "g",
            sourceRef: "s",
            targetDomain: "host-version",
            gateClass: .host,
            requiredSeals: [],
            actionPermitRef: "permit-1",
            sovereignWarrantRef: "",
            secondCheckRequired: true,
            passState: .pending,
            returnPathRef: "")
        let r = BASKunlunHeavenGateProtocol
            .evaluateReadiness(permit)
        XCTAssertFalse(r.isReady)
        XCTAssertTrue(r.reasonCodes.contains(
            "kunlun.gate.high-stakes-needs-sovereign-warrant"))
        XCTAssertTrue(r.reasonCodes.contains(
            "kunlun.gate.high-stakes-needs-jade-seal"))
    }

    func testHeavenGateMissingActionPermitFails() {
        let permit = BASHeavenGatePermit(
            gateID: "g",
            sourceRef: "s",
            targetDomain: "tool-write",
            gateClass: .tool,
            requiredSeals: [],
            actionPermitRef: "",
            sovereignWarrantRef: "",
            secondCheckRequired: false,
            passState: .passed,
            returnPathRef: "")
        let r = BASKunlunHeavenGateProtocol
            .evaluateReadiness(permit)
        XCTAssertFalse(r.isReady)
        XCTAssertTrue(r.reasonCodes.contains(
            "kunlun.gate.missing-action-permit"))
    }

    func testHeavenGateDeniedAndRemandedReportFlags() {
        let denied = BASHeavenGatePermit(
            gateID: "g", sourceRef: "s",
            targetDomain: "x", gateClass: .cognitive,
            requiredSeals: [], actionPermitRef: "p",
            sovereignWarrantRef: "",
            secondCheckRequired: false,
            passState: .denied, returnPathRef: "")
        let r1 = BASKunlunHeavenGateProtocol
            .evaluateReadiness(denied)
        XCTAssertFalse(r1.isReady)
        XCTAssertTrue(r1.reasonCodes.contains(
            "kunlun.gate.already-denied"))

        let remanded = BASHeavenGatePermit(
            gateID: "g", sourceRef: "s",
            targetDomain: "x", gateClass: .cognitive,
            requiredSeals: [], actionPermitRef: "p",
            sovereignWarrantRef: "",
            secondCheckRequired: false,
            passState: .remanded, returnPathRef: "")
        let r2 = BASKunlunHeavenGateProtocol
            .evaluateReadiness(remanded)
        XCTAssertFalse(r2.isReady)
        XCTAssertTrue(r2.reasonCodes.contains(
            "kunlun.gate.remanded-needs-rework"))
    }

    // MARK: - 9. Protocol helper: Yaochi Sanctum

    func testYaochiSealedPolicyAlwaysDenies() {
        let entry = BASYaochiSanctumEntry(
            entryID: "y", memoryRef: "m", hostRef: "h",
            sanctumClass: .vow,
            accessPolicy: .sealed,
            revealConditions: [],
            coolingPeriod: 0,
            humanAnchorRequired: false,
            lastRevealedAt: "")
        let d = BASKunlunYaochiProtocol.evaluateAccess(
            entry: entry,
            hostAnchorPresent: true,
            matchedRevealConditions: [],
            secondsSinceLastReveal: 1_000_000)
        XCTAssertFalse(d.granted)
        XCTAssertTrue(d.reasonCodes.contains(
            "kunlun.yaochi.sealed-policy"))
    }

    func testYaochiConditionalRequiresMatchedConditions() {
        let entry = BASYaochiSanctumEntry(
            entryID: "y", memoryRef: "m", hostRef: "h",
            sanctumClass: .grief,
            accessPolicy: .conditional,
            revealConditions: ["host-explicit-recall"],
            coolingPeriod: 0,
            humanAnchorRequired: false,
            lastRevealedAt: "")
        // No match → denied.
        let d1 = BASKunlunYaochiProtocol.evaluateAccess(
            entry: entry,
            hostAnchorPresent: true,
            matchedRevealConditions: [],
            secondsSinceLastReveal: 100)
        XCTAssertFalse(d1.granted)
        XCTAssertTrue(d1.reasonCodes.contains(
            "kunlun.yaochi.no-matched-conditions"))
        // Match → granted.
        let d2 = BASKunlunYaochiProtocol.evaluateAccess(
            entry: entry,
            hostAnchorPresent: true,
            matchedRevealConditions: ["host-explicit-recall"],
            secondsSinceLastReveal: 100)
        XCTAssertTrue(d2.granted)
    }

    func testYaochiCoolingPeriodGate() {
        let entry = BASYaochiSanctumEntry(
            entryID: "y", memoryRef: "m", hostRef: "h",
            sanctumClass: .grief,
            accessPolicy: .auditedOpen,
            revealConditions: [],
            coolingPeriod: 3600,
            humanAnchorRequired: false,
            lastRevealedAt: "")
        // Inside cooling → denied.
        let d1 = BASKunlunYaochiProtocol.evaluateAccess(
            entry: entry,
            hostAnchorPresent: true,
            matchedRevealConditions: [],
            secondsSinceLastReveal: 1000)
        XCTAssertFalse(d1.granted)
        XCTAssertTrue(d1.reasonCodes.contains(
            "kunlun.yaochi.cooling-period-active"))
        // Beyond cooling → granted (audited-open).
        let d2 = BASKunlunYaochiProtocol.evaluateAccess(
            entry: entry,
            hostAnchorPresent: true,
            matchedRevealConditions: [],
            secondsSinceLastReveal: 7200)
        XCTAssertTrue(d2.granted)
    }

    func testYaochiHumanAnchorGateRedLine3() {
        // Red line #3: sanctum 不能被系统占有 — when
        // humanAnchorRequired is true, host MUST be present.
        let entry = BASYaochiSanctumEntry(
            entryID: "y", memoryRef: "m", hostRef: "h",
            sanctumClass: .vow,
            accessPolicy: .auditedOpen,
            revealConditions: [],
            coolingPeriod: 0,
            humanAnchorRequired: true,
            lastRevealedAt: "")
        let d1 = BASKunlunYaochiProtocol.evaluateAccess(
            entry: entry,
            hostAnchorPresent: false,
            matchedRevealConditions: [],
            secondsSinceLastReveal: 100)
        XCTAssertFalse(d1.granted)
        XCTAssertTrue(d1.reasonCodes.contains(
            "kunlun.yaochi.human-anchor-required"))
        let d2 = BASKunlunYaochiProtocol.evaluateAccess(
            entry: entry,
            hostAnchorPresent: true,
            matchedRevealConditions: [],
            secondsSinceLastReveal: 100)
        XCTAssertTrue(d2.granted)
    }

    // MARK: - 10. Protocol helper: River-Origin

    func testRiverOriginAnalyzeWellFormedTrace() {
        let trace = BASRiverOriginTrace(
            traceID: "r",
            rootSourceRefs: ["src-1", "src-2"],
            tributaryRefs: ["trib-1"],
            derivedObjectRefs: ["d-1"],
            transformationSteps: ["validate"],
            consentRefs: ["c-1"],
            permitRefs: ["p-1"],
            auditRefs: ["a-1"],
            deletionDependents: ["dep-1"],
            lineageCutRefs: [])
        let r = BASKunlunRiverOriginProtocol.analyze(trace)
        XCTAssertTrue(r.isWellFormed)
        XCTAssertEqual(r.upwardCount, 3)   // 2 root + 1 trib
        XCTAssertEqual(r.downwardCount, 1)
        XCTAssertFalse(r.hasLineageCut)
        XCTAssertTrue(r.warningCodes.isEmpty,
                      "well-formed full trace should have no warnings")
    }

    func testRiverOriginOrphanWarnings() {
        let orphan = BASRiverOriginTrace(
            traceID: "r",
            rootSourceRefs: [],
            tributaryRefs: [],
            derivedObjectRefs: [],
            transformationSteps: [],
            consentRefs: [],
            permitRefs: [],
            auditRefs: [],
            deletionDependents: [],
            lineageCutRefs: [])
        let r = BASKunlunRiverOriginProtocol.analyze(orphan)
        XCTAssertFalse(r.isWellFormed)
        XCTAssertTrue(r.warningCodes.contains(
            "kunlun.river.orphan:no-root-source"))
        XCTAssertTrue(r.warningCodes.contains(
            "kunlun.river.orphan:no-audit-trail"))
    }

    func testRiverOriginDerivedWithoutPermitWarning() {
        let trace = BASRiverOriginTrace(
            traceID: "r",
            rootSourceRefs: ["src-1"],
            tributaryRefs: [],
            derivedObjectRefs: ["d-1"],
            transformationSteps: [],
            consentRefs: ["c-1"],
            permitRefs: [],
            auditRefs: ["a-1"],
            deletionDependents: [],
            lineageCutRefs: [])
        let r = BASKunlunRiverOriginProtocol.analyze(trace)
        XCTAssertTrue(r.isWellFormed)
        XCTAssertTrue(r.warningCodes.contains(
            "kunlun.river.derived-without-permit"))
    }

    func testRiverOriginCascadeWithoutConsentWarning() {
        let trace = BASRiverOriginTrace(
            traceID: "r",
            rootSourceRefs: ["src-1"],
            tributaryRefs: [],
            derivedObjectRefs: [],
            transformationSteps: [],
            consentRefs: [],
            permitRefs: [],
            auditRefs: ["a-1"],
            deletionDependents: ["dep-1"],
            lineageCutRefs: [])
        let r = BASKunlunRiverOriginProtocol.analyze(trace)
        XCTAssertTrue(r.warningCodes.contains(
            "kunlun.river.cascade-without-consent"))
    }

    func testRiverOriginLineageCutDetected() {
        let trace = BASRiverOriginTrace(
            traceID: "r",
            rootSourceRefs: ["src-1"],
            tributaryRefs: [],
            derivedObjectRefs: [],
            transformationSteps: [],
            consentRefs: [],
            permitRefs: [],
            auditRefs: ["a-1"],
            deletionDependents: [],
            lineageCutRefs: ["cut-1"])
        let r = BASKunlunRiverOriginProtocol.analyze(trace)
        XCTAssertTrue(r.hasLineageCut)
    }
}
