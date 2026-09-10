// SPDX-License-Identifier: Apache-2.0
// M393 — sample-host demo exercising every wire shipped in M384-M389
// + the M391/M392 landing primitives. Pure-function calls — no
// `BASHostRuntime`, no actor, no IO. The demo's job is to make all
// six Cthulhu doctrine surfaces visible in one run so a host
// implementor can see exactly what each helper takes in and what it
// emits.

import Foundation
import BASMemory
import BASOrchestration
import BASPolicy
import BASWorldPrior

/// Per-wire outcome record. Each step holds the inputs that drove
/// the helper, the typed output, and the audit-emittable reason
/// codes the helper produced.
public struct CthulhuDoctrineWireOutcome: Sendable {
    public let stepName: String
    public let summary: String
    public let reasonCodes: [String]
}

/// Top-level demo outcome carrying one record per wire in canonical
/// presentation order.
public struct CthulhuDoctrineDemoOutcome: Sendable {
    public let m384HighPressureWarmAnchor: CthulhuDoctrineWireOutcome
    public let m384RedLine8ReservedAnchor: CthulhuDoctrineWireOutcome
    public let m385ActiveReserveCap: CthulhuDoctrineWireOutcome
    public let m386ForbiddenGateRefusal: CthulhuDoctrineWireOutcome
    public let m387SealHistogramShape: CthulhuDoctrineWireOutcome
    public let m388NarrativeDominantAxis: CthulhuDoctrineWireOutcome
    public let m389DoctrineRedLineCardinality: CthulhuDoctrineWireOutcome
    /// True iff every wire produced its expected shape — the
    /// banner caller renders this as the demo's final invariant
    /// pin.
    public let allInvariantsHold: Bool
}

/// **M393** — Cthulhu doctrine wire demo. Pure-function. Exercises
/// each of M384, M385, M386, M387, M388, M389 in isolation against
/// hand-built fixture inputs designed to trigger the wire's
/// non-trivial path.
public enum CthulhuDoctrineDemo {

    public static func run() -> CthulhuDoctrineDemoOutcome {
        // ── M384 step 1: high pressure + warm anchor → escalation
        // fires, stackedModes grow, reasonCodes emit.
        let highPressure = BASAbyssalPressure(
            pressureID: "p-demo-high",
            unknownLoad: 0.8,
            consequenceRadius: 0.7,
            evidenceDebt: 0.6,
            ontologyDistortion: 0.7,
            manipulationIndex: 0.6,
            narrativePollution: 0.6,
            recommendedModes: [.compare, .delay, .sovereignEscalate])
        let warmAnchor = BASHumanAnchorSignal(
            anchorID: "a-demo-warm",
            hostSummaryRef: "host:v1",
            agencyRisk: 0.2,
            alienationRisk: 0.1,
            dignityRisk: 0.3,
            overwhelmRisk: 0.3,
            recommendedSurfaceTone: .warm,
            requiredAgencyReservation: "")
        let basePermit = BASActionPermit(mode: .answer)
        let warmDecision = BASAbyssalPermitEscalation.escalate(
            permit: basePermit,
            pressure: highPressure,
            humanAnchor: warmAnchor)
        let m384HighPressureWarmAnchor = CthulhuDoctrineWireOutcome(
            stepName: "M384 high-pressure + warm-anchor",
            summary: "permit.mode=\(warmDecision.permit.mode.rawValue) "
                + "stackedModes="
                + warmDecision.permit.stackedModes
                    .map(\.rawValue)
                    .joined(separator: "+")
                + " triggered=\(warmDecision.triggered)"
                + " suppressed=\(warmDecision.suppressedByHumanAnchor)",
            reasonCodes: warmDecision.reasonCodes)

        // ── M384 step 2: red-line 8 — reserved anchor suppresses
        // escalation despite high pressure.
        let reservedAnchor = BASHumanAnchorSignal(
            anchorID: "a-demo-reserved",
            hostSummaryRef: "host:v1",
            agencyRisk: 0.3,
            alienationRisk: 0.7,
            dignityRisk: 0.5,
            overwhelmRisk: 0.4,
            recommendedSurfaceTone: .reserved,
            requiredAgencyReservation: "")
        let reservedDecision = BASAbyssalPermitEscalation.escalate(
            permit: basePermit,
            pressure: highPressure,
            humanAnchor: reservedAnchor)
        let m384RedLine8 = CthulhuDoctrineWireOutcome(
            stepName: "M384 red-line-8 reserved-anchor suppression",
            summary: "permit.mode=\(reservedDecision.permit.mode.rawValue) "
                + "stackedModes="
                + (reservedDecision.permit.stackedModes.isEmpty
                    ? "(empty)"
                    : reservedDecision.permit.stackedModes
                        .map(\.rawValue)
                        .joined(separator: "+"))
                + " triggered=\(reservedDecision.triggered)"
                + " suppressed=\(reservedDecision.suppressedByHumanAnchor)",
            reasonCodes: reservedDecision.reasonCodes)

        // ── M385: active reserve caps a less-strict permit
        // ceiling (default → qualified).
        let defaultPermit = BASActionPermit(
            mode: .answer,
            assertionCeiling: "default")
        let activeReserve = BASUnknownReserve.derive(
            reserveID: "r-demo",
            confidenceFloor: 0.45)
        let capDecision = BASAssertionCeilingGate.cap(
            permit: defaultPermit,
            reserve: activeReserve)
        let m385Cap = CthulhuDoctrineWireOutcome(
            stepName: "M385 reserve-driven assertion-ceiling cap",
            summary: "before=\(defaultPermit.assertionCeiling)"
                + " after=\(capDecision.permit.assertionCeiling)"
                + " capped=\(capDecision.capped)",
            reasonCodes: capDecision.reasonCodes)

        // ── M386: forbidden candidate refuses startShadowTrial.
        let heldCandidate = BASForbiddenKnowledgeCandidate(
            candidateID: "fk-demo",
            sourceRefs: ["src-1"],
            riskReasons: ["high-manipulation"],
            contaminationRefs: [],
            coolingPeriod: 60,
            shadowTrialPolicy: .standard,
            sovereignReviewState: .held)
        let gateDecision = BASForbiddenLifecycleGate.gate(
            action: .startShadowTrial,
            candidate: heldCandidate)
        let m386Refusal = CthulhuDoctrineWireOutcome(
            stepName: "M386 forbidden-lifecycle gate refusal",
            summary: "input action=startShadowTrial"
                + " sovereignReview=\(heldCandidate.sovereignReviewState.rawValue)"
                + " refused=\(gateDecision.refused)"
                + " gated action="
                + (gateDecision.action.map { String(describing: $0) }
                    ?? "nil"),
            reasonCodes: gateDecision.reasonCodes)

        // ── M387: per-policy histogram on a mixed seal collection.
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
        let canonical: [BASSealAccessPolicy] = [
            .forbidden, .sovereignOnly, .hostExplicit,
            .auditedAccess, .passive,
        ]
        var histogramSummary: [String] = []
        var histogramCodes: [String] = []
        for policy in canonical {
            if let n = aggregate.policyHistogram[policy], n > 0 {
                histogramSummary.append("\(policy.rawValue):\(n)")
                histogramCodes.append(
                    "seal.scope:\(policy.rawValue):\(n)")
            }
        }
        let m387Histogram = CthulhuDoctrineWireOutcome(
            stepName: "M387 seal accessPolicy histogram",
            summary: "count=\(aggregate.count)"
                + " strictest=\(aggregate.strictestPolicy.rawValue)"
                + " histogram=\(histogramSummary.joined(separator: ","))",
            reasonCodes: histogramCodes)

        // ── M388: narrative-distortion dominant-axis name +
        // red-line-7 hint pin (presence in audit codes does NOT
        // change permit/verdict).
        let distortion = BASNarrativeDistortion(
            distortionID: "d-demo",
            realityDenial: 0.2,
            historyRewrite: 0.4,
            forcedClosure: 0.5,
            roleInversion: 0.8,
            urgencyMask: 0.3,
            confidence: 0.7)
        let dominantAxis = distortion.dominantAxisName
        let m388Dominant = CthulhuDoctrineWireOutcome(
            stepName: "M388 narrative dominant-axis",
            summary: "maxAxis="
                + String(format: "%.3f", distortion.maxAxis)
                + " dominantAxis=\(dominantAxis)"
                + " isNonTrivial=\(distortion.isNonTrivial)",
            reasonCodes: [
                "narrative.maxAxis:"
                    + String(format: "%.3f", distortion.maxAxis),
                "narrative.dominantAxis:\(dominantAxis)",
            ])

        // ── M389: doctrine red-line cardinality + canonical naming
        // pin (10 cases, kebab-case, every case carries a
        // white-paper ref + non-empty forbidden-substring list).
        let allRedLines = BASAbyssalDoctrineRedLine.allCases
        var allWellFormed = true
        for r in allRedLines {
            if r.whitePaperRef.isEmpty
                || r.forbiddenSubstrings.isEmpty
            {
                allWellFormed = false
                break
            }
        }
        let m389Cardinality = CthulhuDoctrineWireOutcome(
            stepName: "M389 doctrine red-line cardinality",
            summary: "redLineCount=\(allRedLines.count)"
                + " allWellFormed=\(allWellFormed)"
                + " names="
                + allRedLines.map(\.rawValue)
                    .joined(separator: ","),
            reasonCodes: [])

        // Invariant pins: every wire returned its expected shape.
        let invariants =
            warmDecision.triggered
            && !warmDecision.suppressedByHumanAnchor
            && warmDecision.permit.stackedModes.contains(.compare)
            && reservedDecision.triggered
            && reservedDecision.suppressedByHumanAnchor
            && reservedDecision.permit.stackedModes.isEmpty
            && capDecision.capped
            && capDecision.permit.assertionCeiling == "qualified"
            && gateDecision.refused
            && gateDecision.action == nil
            && aggregate.count == 4
            && aggregate.strictestPolicy == .forbidden
            && aggregate.policyHistogram[.forbidden] == 1
            && aggregate.policyHistogram[.sovereignOnly] == 2
            && aggregate.policyHistogram[.auditedAccess] == 1
            && distortion.dominantAxisName == "role-inversion"
            && distortion.maxAxis == 0.8
            && allRedLines.count == 10
            && allWellFormed

        return CthulhuDoctrineDemoOutcome(
            m384HighPressureWarmAnchor: m384HighPressureWarmAnchor,
            m384RedLine8ReservedAnchor: m384RedLine8,
            m385ActiveReserveCap: m385Cap,
            m386ForbiddenGateRefusal: m386Refusal,
            m387SealHistogramShape: m387Histogram,
            m388NarrativeDominantAxis: m388Dominant,
            m389DoctrineRedLineCardinality: m389Cardinality,
            allInvariantsHold: invariants)
    }
}
