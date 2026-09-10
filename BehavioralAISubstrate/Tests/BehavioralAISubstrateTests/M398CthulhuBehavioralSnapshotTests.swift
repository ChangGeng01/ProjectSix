import XCTest
@testable import BASMemory
@testable import BASOrchestration
@testable import BASPolicy
@testable import BASWorldPrior

/// M398 — behavioral regression gate for the Cthulhu doctrine
/// wires.
///
/// Why this file exists
/// --------------------
///
/// chapter 八十九 self-assessment flagged that the v5 doctrine
/// triple's "regression gate" leg for Cthulhu was M389 substrate-
/// vocabulary lint — it catches drift in audit-emission strings
/// (`watcher.permit:` etc.) but does NOT catch drift in BEHAVIOR
/// (e.g. the M384 translation table changing so `.compare` →
/// `.delay` instead of `.compare`, or the M385 strictness ranking
/// re-ordering, or the M386 gate flipping a refusal to allow). The
/// existing M384/M385/M386 fix-pin tests cover individual cases
/// but not the full per-wire output as a single byte-equal
/// snapshot.
///
/// M398 closes that gap. Each test:
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
/// behavioral gate that complements M389's vocabulary lint.
final class M398CthulhuBehavioralSnapshotTests: XCTestCase {

    // MARK: - Helper to render a snapshot deterministically

    private func snapshot(_ encodable: any Encodable) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(encodable)
        return String(data: data, encoding: .utf8) ?? ""
    }

    // MARK: - 1. M384 escalation snapshot

    /// Pin the full escalation decision shape for a fixed input.
    /// Drift in the translation table, the threshold, the
    /// red-line-8 lock, or the reason-code format will fail this.
    func testM384EscalationDecisionByteEqualSnapshot() throws {
        let pressure = BASAbyssalPressure(
            pressureID: "p-snap-1",
            unknownLoad: 0.7,
            consequenceRadius: 0.6,
            evidenceDebt: 0.6,
            ontologyDistortion: 0.6,
            manipulationIndex: 0.6,
            narrativePollution: 0.7,
            recommendedModes: [
                .compare, .delay, .sovereignEscalate, .localDraft,
                .guardianBranch, .humanAnchorCheck,
            ])
        let warm = BASHumanAnchorSignal(
            anchorID: "a-snap-1",
            hostSummaryRef: "host:v1",
            agencyRisk: 0.3,
            alienationRisk: 0.2,
            dignityRisk: 0.3,
            overwhelmRisk: 0.4,
            recommendedSurfaceTone: .warm,
            requiredAgencyReservation: "")
        let basePermit = BASActionPermit(
            mode: .answer, assertionCeiling: "default")
        let decision = BASAbyssalPermitEscalation.escalate(
            permit: basePermit,
            pressure: pressure,
            humanAnchor: warm)

        // Snapshot every observable: triggered + suppressed +
        // permit fields + reason codes.
        struct Snap: Encodable {
            let triggered: Bool
            let suppressedByHumanAnchor: Bool
            let permitMode: String
            let permitStackedModes: [String]
            let permitReasonCodes: [String]
            let permitAssertionCeiling: String
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
            permitAssertionCeiling:
                decision.permit.assertionCeiling,
            decisionReasonCodes: decision.reasonCodes)
        let actual = try snapshot(snap)
        let expected = #"""
            {"decisionReasonCodes":["permit.escalated:abyssal:compare","permit.escalated:abyssal:delay","permit.escalated:abyssal:sovereign-escalate","permit.escalated:abyssal:local-draft","permit.escalated:abyssal:guardian-branch","permit.escalated:abyssal:human-anchor-check"],"permitAssertionCeiling":"default","permitMode":"answer","permitReasonCodes":["permit.escalated:abyssal:compare","permit.escalated:abyssal:delay","permit.escalated:abyssal:sovereign-escalate","permit.escalated:abyssal:local-draft","permit.escalated:abyssal:guardian-branch","permit.escalated:abyssal:human-anchor-check"],"permitStackedModes":["compare","delay","escalate","local_only"],"suppressedByHumanAnchor":false,"triggered":true}
            """#
            .trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertEqual(actual, expected,
                       "M384 escalation snapshot drifted — " +
                       "translation table or reason-code format " +
                       "changed. Diff the JSON to find which field.")
    }

    // MARK: - 2. M384 red-line-8 reserved-anchor snapshot

    func testM384ReservedAnchorSuppressionByteEqualSnapshot() throws {
        let pressure = BASAbyssalPressure(
            pressureID: "p-snap-2",
            unknownLoad: 0.8,
            consequenceRadius: 0.7,
            evidenceDebt: 0.7,
            ontologyDistortion: 0.6,
            manipulationIndex: 0.6,
            narrativePollution: 0.6,
            recommendedModes: [.compare, .delay])
        let reserved = BASHumanAnchorSignal(
            anchorID: "a-snap-2",
            hostSummaryRef: "host:v1",
            agencyRisk: 0.3,
            alienationRisk: 0.7,
            dignityRisk: 0.5,
            overwhelmRisk: 0.4,
            recommendedSurfaceTone: .reserved,
            requiredAgencyReservation: "")
        let decision = BASAbyssalPermitEscalation.escalate(
            permit: BASActionPermit(mode: .answer),
            pressure: pressure,
            humanAnchor: reserved)
        struct Snap: Encodable {
            let triggered: Bool
            let suppressed: Bool
            let stackedModes: [String]
            let reasonCodes: [String]
        }
        let snap = Snap(
            triggered: decision.triggered,
            suppressed: decision.suppressedByHumanAnchor,
            stackedModes: decision.permit.stackedModes
                .map(\.rawValue),
            reasonCodes: decision.reasonCodes)
        let actual = try snapshot(snap)
        let expected = #"""
            {"reasonCodes":["permit.escalation-skipped:human-anchor-reserved","permit.escalation-suppressed:abyssal:compare","permit.escalation-suppressed:abyssal:delay"],"stackedModes":[],"suppressed":true,"triggered":true}
            """#
            .trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertEqual(actual, expected)
    }

    // MARK: - 3. M385 cap snapshot

    func testM385CapDecisionByteEqualSnapshot() throws {
        let permit = BASActionPermit(
            mode: .answer, assertionCeiling: "default")
        let reserve = BASUnknownReserve.derive(
            reserveID: "r-snap",
            confidenceFloor: 0.30)
        let decision = BASAssertionCeilingGate.cap(
            permit: permit, reserve: reserve)
        struct Snap: Encodable {
            let capped: Bool
            let permitAssertionCeiling: String
            let permitMode: String
            let reasonCodes: [String]
        }
        let snap = Snap(
            capped: decision.capped,
            permitAssertionCeiling:
                decision.permit.assertionCeiling,
            permitMode: decision.permit.mode.rawValue,
            reasonCodes: decision.reasonCodes)
        let actual = try snapshot(snap)
        // confidenceFloor 0.30 falls in [0.2, 0.4) → .metaOnly.
        let expected = #"""
            {"capped":true,"permitAssertionCeiling":"meta-only","permitMode":"answer","reasonCodes":["permit.assertion-ceiling:capped-from:default:to:meta-only"]}
            """#
            .trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertEqual(actual, expected)
    }

    // MARK: - 4. M386 gate snapshot — full sovereign × policy matrix

    /// Walks every (sovereignReviewState, shadowTrialPolicy) ×
    /// every action and captures the full refusal matrix as a
    /// single snapshot. Drift in any cell will be visible in the
    /// diff.
    func testM386GateMatrixByteEqualSnapshot() throws {
        struct Cell: Encodable {
            let action: String
            let state: String
            let policy: String
            let refused: Bool
            let resultAction: String?
            let reasonCodes: [String]
        }
        var cells: [Cell] = []
        let states: [BASSovereignReviewState] = [
            .notReferred, .pending, .held, .cleared, .rejected,
        ]
        let policies: [BASShadowTrialPolicy] = [
            .none, .manualOnly, .restricted, .standard, .escalated,
        ]
        let actions: [BASEvolutionLifecycleAction] = [
            .registerCandidate, .startShadowTrial,
            .finalizeTrial, .promote, .retract, .fail, .withdraw,
        ]
        for state in states {
            for policy in policies {
                for action in actions {
                    let candidate = BASForbiddenKnowledgeCandidate(
                        candidateID: "fk-matrix",
                        sourceRefs: ["src"],
                        riskReasons: ["risk"],
                        contaminationRefs: [],
                        coolingPeriod: 60,
                        shadowTrialPolicy: policy,
                        sovereignReviewState: state)
                    let decision = BASForbiddenLifecycleGate.gate(
                        action: action,
                        candidate: candidate)
                    cells.append(Cell(
                        action: String(describing: action),
                        state: state.rawValue,
                        policy: policy.rawValue,
                        refused: decision.refused,
                        resultAction: decision.action.map {
                            String(describing: $0)
                        },
                        reasonCodes: decision.reasonCodes))
                }
            }
        }
        let actual = try snapshot(cells)
        // 5 states × 5 policies × 7 actions = 175 cells. Pin a
        // structural fingerprint instead of the full string —
        // 175-cell JSON is too large for a single literal but the
        // refusal/allow count must stay invariant.
        //
        // Chapter 九十一 deep-review fix #2 changed `.retract` from
        // refused to allowed when sovereign-rejected. Updated cell
        // counts (post-M398.1 fix):
        //
        //   - rejected sovereign × every policy × 4 advance
        //     actions = 20 refusals (registerCandidate /
        //     startShadowTrial / finalizeTrial / promote;
        //     `.retract` removed)
        //   - rejected sovereign × every policy × 3 terminal
        //     actions = 15 allowed-with-reason (added `.retract`
        //     to the 10 prior `.withdraw` + `.fail` cells)
        //   - held sovereign × every policy × 1 action
        //     (startShadowTrial) = 5 refusals
        //   - other states × policy=.none × 1 action
        //     (startShadowTrial) = 3 refusals (notReferred /
        //     pending / cleared — 3 states × 1 action; held has
        //     its own bucket; rejected has its own bucket)
        // Total refusals = 20 + 5 + 3 = 28; pass-through-with-
        // codes = 15; clean = 175 - 28 - 15 = 132.
        let refusals = cells.filter(\.refused).count
        let passThroughClean = cells.filter {
            !$0.refused && $0.reasonCodes.isEmpty
        }.count
        let passThroughWithCodes = cells.filter {
            !$0.refused && !$0.reasonCodes.isEmpty
        }.count
        XCTAssertEqual(
            refusals, 28,
            "M386 gate refusal count drift: expected 28, got \(refusals)")
        XCTAssertEqual(
            passThroughClean, 132,
            "M386 gate clean-pass count drift: expected 132, got \(passThroughClean)")
        XCTAssertEqual(
            passThroughWithCodes, 15,
            "M386 gate pass-with-codes count drift: expected 15, got \(passThroughWithCodes)")
        // Also pin a sample full snapshot to catch reason-code
        // wording drift on a representative cell.
        let sample = cells.first {
            $0.state == "held"
                && $0.policy == "standard"
                && $0.action == "startShadowTrial"
        }
        XCTAssertEqual(sample?.refused, true)
        XCTAssertEqual(sample?.reasonCodes, [
            "lifecycle.gated:forbidden:sovereign-held:trial-start-refused"
        ])
        // Use the encoded length as a structural fingerprint to
        // detect any refactor of the snapshot shape itself.
        XCTAssertGreaterThan(actual.count, 10_000)
    }

    // MARK: - 5. M387 seal histogram snapshot

    func testM387SealHistogramByteEqualSnapshot() throws {
        let seals = [
            BASSealEnvelope(
                sealID: "s-1", targetRefs: ["t-1"],
                sealReason: "snap", accessPolicy: .forbidden,
                revealConditions: [], lineageCutRefs: [],
                auditRef: "a-1"),
            BASSealEnvelope(
                sealID: "s-2", targetRefs: ["t-2"],
                sealReason: "snap", accessPolicy: .forbidden,
                revealConditions: [], lineageCutRefs: [],
                auditRef: "a-2"),
            BASSealEnvelope(
                sealID: "s-3", targetRefs: ["t-3"],
                sealReason: "snap", accessPolicy: .sovereignOnly,
                revealConditions: [], lineageCutRefs: [],
                auditRef: "a-3"),
            BASSealEnvelope(
                sealID: "s-4", targetRefs: ["t-4"],
                sealReason: "snap", accessPolicy: .auditedAccess,
                revealConditions: [], lineageCutRefs: [],
                auditRef: "a-4"),
            BASSealEnvelope(
                sealID: "s-5", targetRefs: ["t-5"],
                sealReason: "snap", accessPolicy: .passive,
                revealConditions: [], lineageCutRefs: [],
                auditRef: "a-5"),
        ]
        let aggregate = BASOldSealSealingProtocol.aggregate(seals)!
        struct Snap: Encodable {
            let count: Int
            let strictest: String
            let histogram: [String: Int]
        }
        var histDict: [String: Int] = [:]
        for (k, v) in aggregate.policyHistogram {
            histDict[k.rawValue] = v
        }
        let snap = Snap(
            count: aggregate.count,
            strictest: aggregate.strictestPolicy.rawValue,
            histogram: histDict)
        let actual = try snapshot(snap)
        let expected = #"""
            {"count":5,"histogram":{"audited-access":1,"forbidden":2,"passive":1,"sovereign-only":1},"strictest":"forbidden"}
            """#
            .trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertEqual(actual, expected)
    }

    // MARK: - 6. M388 narrative dominant-axis snapshot

    func testM388NarrativeDominantAxisByteEqualSnapshot() throws {
        // Every axis at 0.6 except role-inversion at 0.9 →
        // dominant = role-inversion.
        let distortion = BASNarrativeDistortion(
            distortionID: "d-snap",
            realityDenial: 0.6,
            historyRewrite: 0.6,
            forcedClosure: 0.6,
            roleInversion: 0.9,
            urgencyMask: 0.6,
            confidence: 0.7)
        struct Snap: Encodable {
            let dominantAxisName: String
            let maxAxis: Double
            let isNonTrivial: Bool
        }
        let snap = Snap(
            dominantAxisName: distortion.dominantAxisName,
            maxAxis: distortion.maxAxis,
            isNonTrivial: distortion.isNonTrivial)
        let actual = try snapshot(snap)
        let expected = #"""
            {"dominantAxisName":"role-inversion","isNonTrivial":true,"maxAxis":0.9}
            """#
            .trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertEqual(actual, expected)

        // Also pin tie-break ordering. All-equal at 0.5 → reality-
        // denial wins (canonical order).
        let tied = BASNarrativeDistortion(
            distortionID: "d-tied",
            realityDenial: 0.5,
            historyRewrite: 0.5,
            forcedClosure: 0.5,
            roleInversion: 0.5,
            urgencyMask: 0.5,
            confidence: 0.7)
        XCTAssertEqual(tied.dominantAxisName, "reality-denial")
    }

    // MARK: - 7. M389 doctrine red-line snapshot

    func testM389DoctrineRedLineByteEqualSnapshot() throws {
        // Pin every red-line case's raw value + whitePaperRef +
        // forbiddenSubstrings count (full strings would be large
        // but the count + names is enough to detect renames /
        // reorders / additions / deletions).
        struct Snap: Encodable {
            let rawValues: [String]
            let whitePaperRefs: [String]
            let forbiddenSubstringCounts: [Int]
        }
        let snap = Snap(
            rawValues: BASAbyssalDoctrineRedLine.allCases
                .map(\.rawValue),
            whitePaperRefs: BASAbyssalDoctrineRedLine.allCases
                .map(\.whitePaperRef),
            forbiddenSubstringCounts:
                BASAbyssalDoctrineRedLine.allCases
                    .map { $0.forbiddenSubstrings.count })
        let actual = try snapshot(snap)
        let expected = #"""
            {"forbiddenSubstringCounts":[2,2,2,2,2,2,2,2,2,2],"rawValues":["forbid-shock-horror","forbid-oracular","forbid-erosion","forbid-mystical","main-brand-stays-professional","watcher-hints-never-decides","human-anchor-overrides-pressure","seals-have-audit-ref","silent-relic-leaves-residue","no-cosmic-scale-dilution"],"whitePaperRefs":["CTHULHU_SPEC_V1 §2.1","CTHULHU_SPEC_V1 §2.2 \/ ABYSSAL_VINF §8 RL2","CTHULHU_SPEC_V1 §2.3","CTHULHU_SPEC_V1 §2.4","ABYSSAL_VINF §2.7 \/ §8 RL10","ABYSSAL_VINF §5.4 \/ §8 RL7","ABYSSAL_VINF §8 RL8","ABYSSAL_VINF §8 RL9","CTHULHU_SPEC_V1 §5.14","CTHULHU_SPEC_V1 §1.1 \/ ABYSSAL_VINF §4.4"]}
            """#
            .trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertEqual(actual, expected)
    }
}
