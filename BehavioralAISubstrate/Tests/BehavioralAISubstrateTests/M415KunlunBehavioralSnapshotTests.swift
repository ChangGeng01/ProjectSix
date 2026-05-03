import XCTest
@testable import BASOrchestration
@testable import BASPolicy

/// M415 — behavioral regression gate for the Kunlun doctrine
/// wires.
///
/// Pattern parallel to M398 Cthulhu behavioral snapshots. The
/// existing M412 lint test catches drift in audit-emission
/// vocabulary; the existing M413 composability tests catch
/// drift in cross-doctrine composition. M415 catches the third
/// kind of drift: the per-wire output **byte-for-byte** when
/// fed deterministic inputs.
///
/// Each test:
///
///   1. Constructs a fixed, deterministic input.
///   2. Runs the wire's helper.
///   3. Snapshots every observable output field as a single
///      JSON-serialized string.
///   4. Asserts byte-equal against a pinned expected string.
///
/// Any future change that flips a translation, re-orders a rank,
/// or re-words a reason code will fail one of these tests with a
/// diff that names exactly which field drifted. This is the
/// behavioral gate that complements M412's vocabulary lint and
/// M413's composability fixtures.
///
/// 7 byte-equal snapshots cover the 7 milestones (M402 axis +
/// M404 jade + M405 river + M406 escalation + M408 yaochi + M409
/// tianmen + M412 doctrine red-line cardinality).
final class M415KunlunBehavioralSnapshotTests: XCTestCase {

    // MARK: - Helper

    private func snapshot(_ encodable: any Encodable) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(encodable)
        return String(data: data, encoding: .utf8) ?? ""
    }

    // MARK: - 1. M402 axis alignment snapshot

    /// Pin the full alignment shape for an overreaching axis.
    /// Drift in centerScore computation, deviation handling, or
    /// requiresGate threshold logic will fail this.
    func testM402AxisAlignmentByteEqualSnapshot() throws {
        let axis = BASKunlunAxis(
            axisID: "axis-snap",
            hostRef: "host-snap",
            sovereignRef: "sov-snap",
            worldAnchorRef: "world-snap",
            activeLayerRefs: ["L1", "L11", "L14"],
            agentSeatRefs: [],
            centerlineRules: ["r1", "r2", "r3"],
            deviationThreshold: 0.7,
            lastAlignmentCheck: "")
        let alignment = BASKunlunAxisProtocol.computeAlignment(
            alignmentID: "align-snap",
            axis: axis,
            targetRef: "target-snap",
            matchedRules: 1,
            deviationCodes: [
                "risk-high-narrows-axis",
                "alpha-deviation",
            ],
            correctionHint: "compare-with-host")
        struct Snap: Encodable {
            let alignmentID: String
            let centerScore: Double
            let correctionHint: String
            let deviationCodes: [String]
            let requiresGate: Bool
            let targetRef: String
        }
        let snap = Snap(
            alignmentID: alignment.alignmentID,
            centerScore: alignment.centerScore,
            correctionHint: alignment.correctionHint,
            deviationCodes: alignment.deviationCodes,
            requiresGate: alignment.requiresGate,
            targetRef: alignment.targetRef)
        let actual = try snapshot(snap)
        // matchedRules 1 / total 3 → centerScore = 0.333…
        let expected = #"""
            {"alignmentID":"align-snap","centerScore":0.3333333333333333,"correctionHint":"compare-with-host","deviationCodes":["risk-high-narrows-axis","alpha-deviation"],"requiresGate":true,"targetRef":"target-snap"}
            """#
            .trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertEqual(actual, expected,
            "M402 axis alignment snapshot drifted — centerScore math, deviation shape, or threshold logic changed.")
    }

    // MARK: - 2. M404 Jade Canon canonical-seal snapshot

    func testM404CanonicalSealByteEqualSnapshot() throws {
        let seal = BASJadeCanonSeal(
            sealID: "seal-snap-canonical",
            targetRef: "target-1",
            objectClass: .actionPermit,
            targetSchemaVersion: "1",
            provenanceRefs: ["src-1"],
            integrityHash: "abc123",
            signatureRef: "sig-1",
            replayRequired: true,
            revocationPath: "rb-1",
            sourceRiverRef: "river-1")
        let v = BASKunlunJadeCanonProtocol.verifySeal(seal)
        struct Snap: Encodable {
            let isCanonical: Bool
            let missingRequirements: [String]
        }
        let snap = Snap(
            isCanonical: v.isCanonical,
            missingRequirements: v.missingRequirements)
        let actual = try snapshot(snap)
        let expected = #"""
            {"isCanonical":true,"missingRequirements":[]}
            """#
            .trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertEqual(actual, expected,
            "M404 canonical seal snapshot drifted — verifier logic changed.")
    }

    // MARK: - 3. M404 Jade Canon defective-seal snapshot

    func testM404DefectiveSealByteEqualSnapshot() throws {
        let defective = BASJadeCanonSeal(
            sealID: "seal-snap-defective",
            targetRef: "target-1",
            objectClass: .actionPermit,
            targetSchemaVersion: "1",
            provenanceRefs: [],
            integrityHash: "",
            signatureRef: "",
            replayRequired: false,
            revocationPath: "",
            sourceRiverRef: "")
        let v = BASKunlunJadeCanonProtocol.verifySeal(defective)
        struct Snap: Encodable {
            let isCanonical: Bool
            let missingRequirements: [String]
        }
        let snap = Snap(
            isCanonical: v.isCanonical,
            missingRequirements: v.missingRequirements)
        let actual = try snapshot(snap)
        // The verifier's emission order is fixed: provenance →
        // signature → integrity hash → revocation path.
        let expected = #"""
            {"isCanonical":false,"missingRequirements":["无来源:provenance-empty","无签名:signature-missing","无哈希:integrity-hash-missing","无撤销路径:revocation-path-missing"]}
            """#
            .trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertEqual(actual, expected,
            "M404 defective seal snapshot drifted — verifier emission order or wording changed.")
    }

    // MARK: - 4. M405 River-Origin partial-trace snapshot

    func testM405PartialLineageByteEqualSnapshot() throws {
        let trace = BASRiverOriginTrace(
            traceID: "rv-snap-partial",
            rootSourceRefs: [],
            tributaryRefs: [],
            derivedObjectRefs: ["d1", "d2"],
            transformationSteps: [],
            consentRefs: [],
            permitRefs: [],
            auditRefs: [],
            deletionDependents: ["x1"],
            lineageCutRefs: ["cut-1"])
        let report = BASKunlunRiverOriginProtocol.analyze(trace)
        struct Snap: Encodable {
            let downwardCount: Int
            let hasLineageCut: Bool
            let isWellFormed: Bool
            let upwardCount: Int
            let warningCodes: [String]
        }
        let snap = Snap(
            downwardCount: report.downwardCount,
            hasLineageCut: report.hasLineageCut,
            isWellFormed: report.isWellFormed,
            upwardCount: report.upwardCount,
            warningCodes: report.warningCodes)
        let actual = try snapshot(snap)
        let expected = #"""
            {"downwardCount":2,"hasLineageCut":true,"isWellFormed":false,"upwardCount":0,"warningCodes":["kunlun.river.orphan:no-root-source","kunlun.river.orphan:no-audit-trail","kunlun.river.derived-without-permit","kunlun.river.cascade-without-consent"]}
            """#
            .trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertEqual(actual, expected,
            "M405 partial lineage snapshot drifted — analyzer warning order or wording changed.")
    }

    // MARK: - 5. M406 escalation snapshot

    /// Pin the full escalation decision shape for an overreaching
    /// axis with deep deviation. Drift in the deep-deviation
    /// ladder, the deviation-code emission order, or red-line-8
    /// suppression will fail this.
    func testM406EscalationByteEqualSnapshot() throws {
        let alignment = BASAxisAlignment(
            alignmentID: "align-snap-deep",
            targetRef: "target-snap",
            axisRef: "axis-snap",
            centerScore: 0.1,
            deviationCodes: ["zebra", "alpha", "mango"],
            correctionHint: "",
            requiresGate: true)
        let basePermit = BASActionPermit(
            mode: .answer, assertionCeiling: "default")
        let decision = BASKunlunPermitEscalation.escalate(
            permit: basePermit,
            alignment: alignment,
            humanAnchor: nil)
        struct Snap: Encodable {
            let triggered: Bool
            let suppressedByHumanAnchor: Bool
            let permitMode: String
            let permitStackedModes: [String]
            let permitReasonCodes: [String]
            let decisionReasonCodes: [String]
        }
        let snap = Snap(
            triggered: decision.triggered,
            suppressedByHumanAnchor:
                decision.suppressedByHumanAnchor,
            permitMode: decision.permit.mode.rawValue,
            permitStackedModes: decision.permit.stackedModes
                .map(\.rawValue),
            permitReasonCodes: decision.permit.reasonCodes,
            decisionReasonCodes: decision.reasonCodes)
        let actual = try snapshot(snap)
        // Deep deviation (centerScore 0.1 < 0.3) → both .compare
        // AND .escalate appended. Deviation codes sorted: alpha,
        // mango, zebra.
        let expected = #"""
            {"decisionReasonCodes":["permit.escalated:kunlun:requires-gate","permit.escalated:kunlun:compare","permit.escalated:kunlun:deviation:alpha","permit.escalated:kunlun:deviation:mango","permit.escalated:kunlun:deviation:zebra","permit.escalated:kunlun:escalate-deep-deviation"],"permitMode":"answer","permitReasonCodes":["permit.escalated:kunlun:requires-gate","permit.escalated:kunlun:compare","permit.escalated:kunlun:deviation:alpha","permit.escalated:kunlun:deviation:mango","permit.escalated:kunlun:deviation:zebra","permit.escalated:kunlun:escalate-deep-deviation"],"permitStackedModes":["compare","escalate"],"suppressedByHumanAnchor":false,"triggered":true}
            """#
            .trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertEqual(actual, expected,
            "M406 escalation snapshot drifted — translation, ladder, or sort order changed.")
    }

    // MARK: - 6. M408 Yaochi access snapshot — sealed denied

    func testM408SealedSanctumDeniedByteEqualSnapshot() throws {
        let entry = BASYaochiSanctumEntry(
            entryID: "yaochi-snap-sealed",
            memoryRef: "m1",
            hostRef: "host-1",
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
        struct Snap: Encodable {
            let granted: Bool
            let reasonCodes: [String]
        }
        let snap = Snap(
            granted: decision.granted,
            reasonCodes: decision.reasonCodes)
        let actual = try snapshot(snap)
        let expected = #"""
            {"granted":false,"reasonCodes":["kunlun.yaochi.sealed-policy"]}
            """#
            .trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertEqual(actual, expected,
            "M408 sealed-denied snapshot drifted — sealed policy code changed.")
    }

    // MARK: - 7. M409 Tianmen high-stakes-without-warrant snapshot

    func testM409HighStakesWithoutWarrantByteEqualSnapshot() throws {
        let permit = BASHeavenGatePermit(
            gateID: "tianmen-snap-host",
            sourceRef: "src-1",
            targetDomain: "host-domain",
            gateClass: .host,
            requiredSeals: [],
            actionPermitRef: "permit-1",
            sovereignWarrantRef: "",
            secondCheckRequired: false,
            passState: .passed,
            returnPathRef: "")
        let r = BASKunlunHeavenGateProtocol.evaluateReadiness(
            permit)
        struct Snap: Encodable {
            let isReady: Bool
            let reasonCodes: [String]
        }
        let snap = Snap(
            isReady: r.isReady,
            reasonCodes: r.reasonCodes)
        let actual = try snapshot(snap)
        let expected = #"""
            {"isReady":false,"reasonCodes":["kunlun.gate.high-stakes-needs-sovereign-warrant","kunlun.gate.high-stakes-needs-jade-seal"]}
            """#
            .trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertEqual(actual, expected,
            "M409 high-stakes-not-ready snapshot drifted — gate logic changed.")
    }

    // MARK: - 8. M412 doctrine red-line cardinality + naming snapshot

    /// Pin the full red-line enumeration ordering + raw values.
    /// Drift in case order, raw value text, or new/removed cases
    /// will fail this.
    func testM412DoctrineRedLineByteEqualSnapshot() throws {
        let cases = BASKunlunDoctrineRedLine.allCases
        struct Snap: Encodable {
            let count: Int
            let rawValues: [String]
        }
        let snap = Snap(
            count: cases.count,
            rawValues: cases.map(\.rawValue))
        let actual = try snapshot(snap)
        let expected = #"""
            {"count":8,"rawValues":["forbid-system-authority-via-kunlun","forbid-ascent-shaming-host","forbid-permanent-sanctum-occupation","forbid-jade-canon-black-box","forbid-tianmen-bypasses-host","forbid-river-origin-hidden-surveillance","forbid-single-culture-exclusivity","forbid-welcome-becomes-takeover"]}
            """#
            .trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertEqual(actual, expected,
            "M412 doctrine red-line snapshot drifted — case order, raw value, or cardinality changed.")
    }
}
