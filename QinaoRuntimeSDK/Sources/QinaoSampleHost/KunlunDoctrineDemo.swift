// SPDX-License-Identifier: Apache-2.0
// M414 — sample-host demo exercising every wire shipped in M404-M412
// + the M402 audit projection. Pure-function calls — no
// `BASHostRuntime`, no actor, no IO. The demo's job is to make all
// six Kunlun doctrine surfaces visible in one run so a host
// implementor can see exactly what each helper takes in and what it
// emits.
//
// Pattern parallel: `CthulhuDoctrineDemo.swift` (M393).

import Foundation
import BASOrchestration
import BASPolicy

/// Per-wire outcome record. Each step holds the inputs that drove
/// the helper, the typed output, and the audit-emittable reason
/// codes the helper produced.
public struct KunlunDoctrineWireOutcome: Sendable {
    public let stepName: String
    public let summary: String
    public let reasonCodes: [String]
}

/// Top-level demo outcome carrying one record per wire in canonical
/// presentation order.
public struct KunlunDoctrineDemoOutcome: Sendable {
    public let m402AxisAlignmentCentered: KunlunDoctrineWireOutcome
    public let m402AxisAlignmentOverreaching: KunlunDoctrineWireOutcome
    public let m404JadeCanonCanonicalSeal: KunlunDoctrineWireOutcome
    public let m404JadeCanonDefectiveSeal: KunlunDoctrineWireOutcome
    public let m405RiverOriginWellformed: KunlunDoctrineWireOutcome
    public let m405RiverOriginPartial: KunlunDoctrineWireOutcome
    public let m406PermitEscalationOverreaching: KunlunDoctrineWireOutcome
    public let m406PermitEscalationReserved: KunlunDoctrineWireOutcome
    public let m408YaochiSealedDenied: KunlunDoctrineWireOutcome
    public let m408YaochiConditionalGranted: KunlunDoctrineWireOutcome
    public let m409TianmenHighStakesNotReady: KunlunDoctrineWireOutcome
    public let m409TianmenLowStakesReady: KunlunDoctrineWireOutcome
    public let m412DoctrineRedLineCardinality: KunlunDoctrineWireOutcome
    /// True iff every wire produced its expected shape — the
    /// banner caller renders this as the demo's final invariant
    /// pin.
    public let allInvariantsHold: Bool
}

/// **M414** — Kunlun doctrine wire demo. Pure-function. Exercises
/// each of M402, M404, M405, M406, M408, M409, M412 in isolation
/// against hand-built fixture inputs designed to trigger the
/// wire's non-trivial path.
public enum KunlunDoctrineDemo {

    public static func run() -> KunlunDoctrineDemoOutcome {
        // ── M402 step 1: centered axis → no gate required.
        let axis = BASKunlunAxis(
            axisID: "axis-demo",
            hostRef: "host-demo",
            sovereignRef: "sov-demo",
            worldAnchorRef: "world-demo",
            activeLayerRefs: ["L1", "L4", "L11", "L14"],
            agentSeatRefs: [],
            centerlineRules: [
                "respects-host-boundary",
                "honors-world-anchor",
                "permit-mode-answer",
            ],
            deviationThreshold: 0.7,
            lastAlignmentCheck: "")
        let centeredAlignment = BASKunlunAxisProtocol
            .computeAlignment(
                alignmentID: "align-centered",
                axis: axis,
                targetRef: "target-1",
                matchedRules: 3,
                deviationCodes: [],
                correctionHint: "")
        let m402Centered = KunlunDoctrineWireOutcome(
            stepName: "M402 axis centered",
            summary: "centerScore="
                + String(format: "%.3f",
                    centeredAlignment.centerScore)
                + " requiresGate=\(centeredAlignment.requiresGate)"
                + " deviations="
                + centeredAlignment.deviationCodes
                    .joined(separator: ","),
            reasonCodes: [
                "kunlun.axis.center:"
                    + String(format: "%.3f",
                        centeredAlignment.centerScore),
            ])

        // ── M402 step 2: overreaching axis → gate required.
        let overreachAlignment = BASKunlunAxisProtocol
            .computeAlignment(
                alignmentID: "align-overreach",
                axis: axis,
                targetRef: "target-2",
                matchedRules: 1,
                deviationCodes: [
                    "risk-high-narrows-axis",
                ],
                correctionHint: "compare-with-host")
        let m402Overreaching = KunlunDoctrineWireOutcome(
            stepName: "M402 axis overreaching",
            summary: "centerScore="
                + String(format: "%.3f",
                    overreachAlignment.centerScore)
                + " requiresGate=\(overreachAlignment.requiresGate)"
                + " deviations="
                + overreachAlignment.deviationCodes
                    .joined(separator: ","),
            reasonCodes: [
                "kunlun.axis.center:"
                    + String(format: "%.3f",
                        overreachAlignment.centerScore),
                "kunlun.axis.deviation:"
                    + overreachAlignment.deviationCodes
                        .sorted()
                        .joined(separator: "+"),
                "kunlun.axis.requires-gate:true",
            ])

        // ── M404 step 1: canonical seal — all four canonical
        // requirements satisfied.
        let canonicalSeal = BASJadeCanonSeal(
            sealID: "seal-canonical",
            targetRef: "permit-1",
            objectClass: .actionPermit,
            targetSchemaVersion: "1",
            provenanceRefs: ["src-1"],
            integrityHash: "abc123",
            signatureRef: "sig-1",
            replayRequired: true,
            revocationPath: "rb-1",
            sourceRiverRef: "river-1")
        let canonicalVerification = BASKunlunJadeCanonProtocol
            .verifySeal(canonicalSeal)
        let m404Canonical = KunlunDoctrineWireOutcome(
            stepName: "M404 canonical seal",
            summary: "isCanonical=\(canonicalVerification.isCanonical)"
                + " missing="
                + canonicalVerification.missingRequirements
                    .joined(separator: ","),
            reasonCodes: [
                "kunlun.jade.seal:action-permit:canonical",
            ])

        // ── M404 step 2: defective seal — all four canonical
        // requirements missing.
        let defectiveSeal = BASJadeCanonSeal(
            sealID: "seal-defective",
            targetRef: "permit-1",
            objectClass: .actionPermit,
            targetSchemaVersion: "1",
            provenanceRefs: [],
            integrityHash: "",
            signatureRef: "",
            replayRequired: false,
            revocationPath: "",
            sourceRiverRef: "")
        let defectiveVerification = BASKunlunJadeCanonProtocol
            .verifySeal(defectiveSeal)
        let m404Defective = KunlunDoctrineWireOutcome(
            stepName: "M404 defective seal",
            summary: "isCanonical=\(defectiveVerification.isCanonical)"
                + " missing="
                + defectiveVerification.missingRequirements
                    .joined(separator: ","),
            reasonCodes: [
                "kunlun.jade.seal:action-permit:defective",
                "kunlun.jade.missing:"
                    + "\(defectiveVerification.missingRequirements.count)",
                "kunlun.jade.defects:"
                    + defectiveVerification.missingRequirements
                        .sorted()
                        .joined(separator: "+"),
            ])

        // ── M405 step 1: well-formed lineage trace.
        let wellformedTrace = BASRiverOriginTrace(
            traceID: "river-wellformed",
            rootSourceRefs: ["root-1"],
            tributaryRefs: ["trib-1"],
            derivedObjectRefs: ["derived-1"],
            transformationSteps: ["risk.bind", "permit.synthesize"],
            consentRefs: ["consent-1"],
            permitRefs: ["permit-1"],
            auditRefs: ["audit-1"],
            deletionDependents: [],
            lineageCutRefs: [])
        let wellformedReport = BASKunlunRiverOriginProtocol
            .analyze(wellformedTrace)
        let m405Wellformed = KunlunDoctrineWireOutcome(
            stepName: "M405 wellformed lineage",
            summary: "isWellFormed=\(wellformedReport.isWellFormed)"
                + " upward=\(wellformedReport.upwardCount)"
                + " downward=\(wellformedReport.downwardCount)"
                + " warnings="
                + wellformedReport.warningCodes
                    .joined(separator: ","),
            reasonCodes: [
                "kunlun.river.lineage:wellformed",
                "kunlun.river.upward:\(wellformedReport.upwardCount)",
                "kunlun.river.downward:\(wellformedReport.downwardCount)",
            ])

        // ── M405 step 2: partial trace — orphan trace, no audit.
        let partialTrace = BASRiverOriginTrace(
            traceID: "river-partial",
            rootSourceRefs: [],
            tributaryRefs: [],
            derivedObjectRefs: ["d1", "d2"],
            transformationSteps: [],
            consentRefs: [],
            permitRefs: [],
            auditRefs: [],
            deletionDependents: ["x"],
            lineageCutRefs: [])
        let partialReport = BASKunlunRiverOriginProtocol
            .analyze(partialTrace)
        let m405Partial = KunlunDoctrineWireOutcome(
            stepName: "M405 partial lineage",
            summary: "isWellFormed=\(partialReport.isWellFormed)"
                + " warnings="
                + partialReport.warningCodes
                    .sorted()
                    .joined(separator: ","),
            reasonCodes: [
                "kunlun.river.lineage:partial",
                "kunlun.river.warnings:"
                    + partialReport.warningCodes
                        .sorted()
                        .joined(separator: "+"),
            ])

        // ── M406 step 1: overreaching axis → permit escalates.
        let basePermit = BASActionPermit(mode: .answer)
        let overreachDecision = BASKunlunPermitEscalation
            .escalate(
                permit: basePermit,
                alignment: overreachAlignment,
                humanAnchor: nil)
        let m406Overreaching = KunlunDoctrineWireOutcome(
            stepName: "M406 permit escalation overreaching",
            summary: "triggered=\(overreachDecision.triggered)"
                + " suppressed=\(overreachDecision.suppressedByHumanAnchor)"
                + " stackedModes="
                + overreachDecision.permit.stackedModes
                    .map(\.rawValue)
                    .joined(separator: "+"),
            reasonCodes: overreachDecision.reasonCodes)

        // ── M406 step 2: red-line 8 — reserved anchor suppresses.
        let reservedAnchor = BASHumanAnchorSignal(
            anchorID: "anchor-reserved",
            hostSummaryRef: "host:v1",
            agencyRisk: 0.5,
            alienationRisk: 0.5,
            dignityRisk: 0.5,
            overwhelmRisk: 0.5,
            recommendedSurfaceTone: .reserved,
            requiredAgencyReservation: "preserve-distance")
        let reservedDecision = BASKunlunPermitEscalation
            .escalate(
                permit: basePermit,
                alignment: overreachAlignment,
                humanAnchor: reservedAnchor)
        let m406Reserved = KunlunDoctrineWireOutcome(
            stepName: "M406 red-line-8 reserved-anchor suppression",
            summary: "triggered=\(reservedDecision.triggered)"
                + " suppressed=\(reservedDecision.suppressedByHumanAnchor)"
                + " stackedModes="
                + reservedDecision.permit.stackedModes
                    .map(\.rawValue)
                    .joined(separator: "+"),
            reasonCodes: reservedDecision.reasonCodes)

        // ── M408 step 1: sealed sanctum entry → access denied.
        let sealedEntry = BASYaochiSanctumEntry(
            entryID: "yaochi-sealed",
            memoryRef: "m1",
            hostRef: "host-1",
            sanctumClass: .vow,
            accessPolicy: .sealed,
            revealConditions: [],
            coolingPeriod: 0,
            humanAnchorRequired: false,
            lastRevealedAt: "")
        let sealedDecision = BASKunlunYaochiProtocol
            .evaluateAccess(
                entry: sealedEntry,
                hostAnchorPresent: true,
                matchedRevealConditions: [],
                secondsSinceLastReveal: 1000)
        let m408Sealed = KunlunDoctrineWireOutcome(
            stepName: "M408 sealed sanctum denied",
            summary: "granted=\(sealedDecision.granted)"
                + " reasons="
                + sealedDecision.reasonCodes
                    .joined(separator: ","),
            reasonCodes: [
                "kunlun.yaochi.access:vow:denied",
                "kunlun.yaochi.reasons:sealed-policy",
            ])

        // ── M408 step 2: conditional + matched + anchor present
        // → access granted.
        let conditionalEntry = BASYaochiSanctumEntry(
            entryID: "yaochi-conditional",
            memoryRef: "m2",
            hostRef: "host-1",
            sanctumClass: .precious,
            accessPolicy: .conditional,
            revealConditions: ["host-explicit-recall"],
            coolingPeriod: 60,
            humanAnchorRequired: true,
            lastRevealedAt: "")
        let conditionalDecision = BASKunlunYaochiProtocol
            .evaluateAccess(
                entry: conditionalEntry,
                hostAnchorPresent: true,
                matchedRevealConditions: ["host-explicit-recall"],
                secondsSinceLastReveal: 1000)
        let m408Conditional = KunlunDoctrineWireOutcome(
            stepName: "M408 conditional sanctum granted",
            summary: "granted=\(conditionalDecision.granted)"
                + " reasons="
                + conditionalDecision.reasonCodes
                    .joined(separator: ","),
            reasonCodes: [
                "kunlun.yaochi.access:precious:granted",
            ])

        // ── M409 step 1: high-stakes gate without warrant
        // → not ready (RL5 typed-pin).
        let highStakesGate = BASHeavenGatePermit(
            gateID: "tianmen-host",
            sourceRef: "src-1",
            targetDomain: "host-domain",
            gateClass: .host,
            requiredSeals: [],
            actionPermitRef: "permit-1",
            sovereignWarrantRef: "",
            secondCheckRequired: false,
            passState: .passed,
            returnPathRef: "")
        let highStakesReadiness = BASKunlunHeavenGateProtocol
            .evaluateReadiness(highStakesGate)
        let m409HighStakes = KunlunDoctrineWireOutcome(
            stepName: "M409 high-stakes gate not ready",
            summary: "isReady=\(highStakesReadiness.isReady)"
                + " reasons="
                + highStakesReadiness.reasonCodes
                    .joined(separator: ","),
            reasonCodes: [
                "kunlun.tianmen.gate:host:passed",
                "kunlun.tianmen.ready:false",
                "kunlun.tianmen.warrant-missing:high-stakes",
            ])

        // ── M409 step 2: low-stakes gate with permit + passed
        // state → ready.
        let lowStakesGate = BASHeavenGatePermit(
            gateID: "tianmen-cognitive",
            sourceRef: "src-2",
            targetDomain: "cognitive-domain",
            gateClass: .cognitive,
            requiredSeals: [],
            actionPermitRef: "permit-1",
            sovereignWarrantRef: "",
            secondCheckRequired: false,
            passState: .passed,
            returnPathRef: "")
        let lowStakesReadiness = BASKunlunHeavenGateProtocol
            .evaluateReadiness(lowStakesGate)
        let m409LowStakes = KunlunDoctrineWireOutcome(
            stepName: "M409 low-stakes gate ready",
            summary: "isReady=\(lowStakesReadiness.isReady)",
            reasonCodes: [
                "kunlun.tianmen.gate:cognitive:passed",
                "kunlun.tianmen.ready:true",
            ])

        // ── M412: doctrine red-line cardinality + canonical
        // naming pin (8 cases, kebab-case, every case carries a
        // white-paper ref + non-empty forbidden-substring list).
        let allRedLines = BASKunlunDoctrineRedLine.allCases
        var allWellFormed = true
        for r in allRedLines {
            if r.whitePaperRef.isEmpty
                || r.forbiddenSubstrings.isEmpty
            {
                allWellFormed = false
                break
            }
        }
        let m412Cardinality = KunlunDoctrineWireOutcome(
            stepName: "M412 doctrine red-line cardinality",
            summary: "redLineCount=\(allRedLines.count)"
                + " allWellFormed=\(allWellFormed)"
                + " names="
                + allRedLines.map(\.rawValue)
                    .joined(separator: ","),
            reasonCodes: [])

        // Invariant pins: every wire returned its expected shape.
        let invariants =
            // M402
            !centeredAlignment.requiresGate
            && centeredAlignment.centerScore == 1.0
            && overreachAlignment.requiresGate
            && overreachAlignment.centerScore < 0.7
            // M404
            && canonicalVerification.isCanonical
            && canonicalVerification.missingRequirements.isEmpty
            && !defectiveVerification.isCanonical
            && defectiveVerification.missingRequirements.count == 4
            // M405
            && wellformedReport.isWellFormed
            && wellformedReport.warningCodes.isEmpty
            && !partialReport.isWellFormed
            && partialReport.warningCodes.count >= 2
            // M406
            && overreachDecision.triggered
            && !overreachDecision.suppressedByHumanAnchor
            && overreachDecision.permit.stackedModes
                .contains(.compare)
            && reservedDecision.triggered
            && reservedDecision.suppressedByHumanAnchor
            && reservedDecision.permit.stackedModes.isEmpty
            // M408
            && !sealedDecision.granted
            && conditionalDecision.granted
            // M409
            && !highStakesReadiness.isReady
            && lowStakesReadiness.isReady
            // M412
            && allRedLines.count == 8
            && allWellFormed

        return KunlunDoctrineDemoOutcome(
            m402AxisAlignmentCentered: m402Centered,
            m402AxisAlignmentOverreaching: m402Overreaching,
            m404JadeCanonCanonicalSeal: m404Canonical,
            m404JadeCanonDefectiveSeal: m404Defective,
            m405RiverOriginWellformed: m405Wellformed,
            m405RiverOriginPartial: m405Partial,
            m406PermitEscalationOverreaching: m406Overreaching,
            m406PermitEscalationReserved: m406Reserved,
            m408YaochiSealedDenied: m408Sealed,
            m408YaochiConditionalGranted: m408Conditional,
            m409TianmenHighStakesNotReady: m409HighStakes,
            m409TianmenLowStakesReady: m409LowStakes,
            m412DoctrineRedLineCardinality: m412Cardinality,
            allInvariantsHold: invariants)
    }
}
