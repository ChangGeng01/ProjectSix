import XCTest
import BASMemory
import BASOrchestration
import BASPolicy
import BASWorldPrior

/// M393 — pin the substrate contracts that
/// `QinaoSampleHost --cthulhu-doctrine-demo` relies on. Same
/// pattern as M313/M314/M322/M328/M329/M333/M334/M335: demo lives
/// in executable target, tests pin the BAS primitives that the
/// demo composes (which are exactly the M384-M389 wires, reused
/// with the demo's fixture inputs).
///
/// What this file pins:
///
///   1. `BASAbyssalPermitEscalation.escalate(...)` translates the
///      demo's high-pressure + warm-anchor inputs into a
///      `triggered + non-suppressed` decision with stackedModes
///      `[compare, delay, escalate]`.
///   2. The same escalator with a reserved-anchor input emits the
///      red-line-8 suppression code path.
///   3. `BASAssertionCeilingGate.cap(...)` against an active
///      reserve at confidence floor 0.45 (= `.qualified`) caps a
///      "default" permit to "qualified".
///   4. `BASForbiddenLifecycleGate.gate(...)` refuses
///      `.startShadowTrial` against a held-sovereign candidate.
///   5. `BASOldSealSealingProtocol.aggregate(...)` over a
///      4-element seal collection produces the histogram the demo
///      banner prints.
///   6. `BASNarrativeDistortion.dominantAxisName` names
///      `role-inversion` as the dominant axis when that axis is
///      0.8 and others are below 0.5.
///   7. `BASAbyssalDoctrineRedLine.allCases` carries 10 entries,
///      each with non-empty white-paper ref + non-empty forbidden
///      substrings.
final class QinaoSampleHostCthulhuDoctrineDemoTests: XCTestCase {

    // MARK: - 1. M384 warm anchor — escalation fires

    func testM384WarmAnchorEscalationMatchesDemoFixture() {
        let pressure = BASAbyssalPressure(
            pressureID: "p-demo-high",
            unknownLoad: 0.8,
            consequenceRadius: 0.7,
            evidenceDebt: 0.6,
            ontologyDistortion: 0.7,
            manipulationIndex: 0.6,
            narrativePollution: 0.6,
            recommendedModes: [
                .compare, .delay, .sovereignEscalate,
            ])
        let warm = BASHumanAnchorSignal(
            anchorID: "a-demo-warm",
            hostSummaryRef: "host:v1",
            agencyRisk: 0.2,
            alienationRisk: 0.1,
            dignityRisk: 0.3,
            overwhelmRisk: 0.3,
            recommendedSurfaceTone: .warm,
            requiredAgencyReservation: "")
        let decision = BASAbyssalPermitEscalation.escalate(
            permit: BASActionPermit(mode: .answer),
            pressure: pressure,
            humanAnchor: warm)
        XCTAssertTrue(decision.triggered)
        XCTAssertFalse(decision.suppressedByHumanAnchor)
        XCTAssertEqual(
            decision.permit.stackedModes,
            [.compare, .delay, .escalate])
        XCTAssertEqual(decision.reasonCodes, [
            "permit.escalated:abyssal:compare",
            "permit.escalated:abyssal:delay",
            "permit.escalated:abyssal:sovereign-escalate",
        ])
    }

    // MARK: - 2. M384 red-line 8 — reserved suppresses

    func testM384RedLine8ReservedAnchorMatchesDemoFixture() {
        let pressure = BASAbyssalPressure(
            pressureID: "p-demo-high",
            unknownLoad: 0.8,
            consequenceRadius: 0.7,
            evidenceDebt: 0.6,
            ontologyDistortion: 0.7,
            manipulationIndex: 0.6,
            narrativePollution: 0.6,
            recommendedModes: [
                .compare, .delay, .sovereignEscalate,
            ])
        let reserved = BASHumanAnchorSignal(
            anchorID: "a-demo-reserved",
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
        XCTAssertTrue(decision.triggered)
        XCTAssertTrue(decision.suppressedByHumanAnchor)
        XCTAssertTrue(decision.permit.stackedModes.isEmpty)
        XCTAssertTrue(decision.reasonCodes.contains(
            "permit.escalation-skipped:human-anchor-reserved"))
        XCTAssertTrue(decision.reasonCodes.contains(
            "permit.escalation-suppressed:abyssal:compare"))
        XCTAssertTrue(decision.reasonCodes.contains(
            "permit.escalation-suppressed:abyssal:delay"))
        XCTAssertTrue(decision.reasonCodes.contains(
            "permit.escalation-suppressed:abyssal:sovereign-escalate"))
    }

    // MARK: - 3. M385 — default → qualified cap

    func testM385CapDefaultToQualifiedMatchesDemoFixture() {
        let permit = BASActionPermit(
            mode: .answer,
            assertionCeiling: "default")
        let reserve = BASUnknownReserve.derive(
            reserveID: "r-demo",
            confidenceFloor: 0.45)
        let decision = BASAssertionCeilingGate.cap(
            permit: permit,
            reserve: reserve)
        XCTAssertTrue(decision.capped)
        XCTAssertEqual(
            decision.permit.assertionCeiling, "qualified")
        XCTAssertEqual(decision.reasonCodes, [
            "permit.assertion-ceiling:capped-from:default:to:qualified"
        ])
    }

    // MARK: - 4. M386 — held sovereign refuses startShadowTrial

    func testM386HeldSovereignRefusesMatchesDemoFixture() {
        let candidate = BASForbiddenKnowledgeCandidate(
            candidateID: "fk-demo",
            sourceRefs: ["src-1"],
            riskReasons: ["high-manipulation"],
            contaminationRefs: [],
            coolingPeriod: 60,
            shadowTrialPolicy: .standard,
            sovereignReviewState: .held)
        let decision = BASForbiddenLifecycleGate.gate(
            action: .startShadowTrial,
            candidate: candidate)
        XCTAssertTrue(decision.refused)
        XCTAssertNil(decision.action)
        XCTAssertEqual(decision.reasonCodes, [
            "lifecycle.gated:forbidden:sovereign-held:trial-start-refused"
        ])
    }

    // MARK: - 5. M387 — histogram counts buckets

    func testM387HistogramCountsBucketsMatchesDemoFixture() {
        let seals = [
            BASSealEnvelope(
                sealID: "s-1", targetRefs: ["t-1"],
                sealReason: "demo", accessPolicy: .forbidden,
                revealConditions: [], lineageCutRefs: [],
                auditRef: "a-1"),
            BASSealEnvelope(
                sealID: "s-2", targetRefs: ["t-2"],
                sealReason: "demo", accessPolicy: .sovereignOnly,
                revealConditions: [], lineageCutRefs: [],
                auditRef: "a-2"),
            BASSealEnvelope(
                sealID: "s-3", targetRefs: ["t-3"],
                sealReason: "demo", accessPolicy: .sovereignOnly,
                revealConditions: [], lineageCutRefs: [],
                auditRef: "a-3"),
            BASSealEnvelope(
                sealID: "s-4", targetRefs: ["t-4"],
                sealReason: "demo", accessPolicy: .auditedAccess,
                revealConditions: [], lineageCutRefs: [],
                auditRef: "a-4"),
        ]
        let aggregate = BASOldSealSealingProtocol.aggregate(seals)!
        XCTAssertEqual(aggregate.count, 4)
        XCTAssertEqual(aggregate.strictestPolicy, .forbidden)
        XCTAssertEqual(
            aggregate.policyHistogram[.forbidden], 1)
        XCTAssertEqual(
            aggregate.policyHistogram[.sovereignOnly], 2)
        XCTAssertEqual(
            aggregate.policyHistogram[.auditedAccess], 1)
        XCTAssertNil(aggregate.policyHistogram[.passive])
        XCTAssertNil(aggregate.policyHistogram[.hostExplicit])
    }

    // MARK: - 6. M388 — role-inversion is dominant axis

    func testM388RoleInversionDominantAxisMatchesDemoFixture() {
        let distortion = BASNarrativeDistortion(
            distortionID: "d-demo",
            realityDenial: 0.2,
            historyRewrite: 0.4,
            forcedClosure: 0.5,
            roleInversion: 0.8,
            urgencyMask: 0.3,
            confidence: 0.7)
        XCTAssertEqual(
            distortion.dominantAxisName, "role-inversion")
        XCTAssertEqual(
            distortion.maxAxis, 0.8, accuracy: 0.001)
        XCTAssertTrue(distortion.isNonTrivial)
    }

    // MARK: - 7. M389 — 10 doctrine red lines well-formed

    func testM389TenDoctrineRedLinesWellFormed() {
        let allCases = BASAbyssalDoctrineRedLine.allCases
        XCTAssertEqual(allCases.count, 10)
        for redLine in allCases {
            XCTAssertFalse(redLine.whitePaperRef.isEmpty)
            XCTAssertFalse(
                redLine.forbiddenSubstrings.isEmpty)
        }
    }
}
