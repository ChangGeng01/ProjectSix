// MARK: - BASTurnAuditProjectionsKunlunAxisProtocol
// chapter 四百九十三 / M1348 — Kunlun axis + alignment fold
//
// Folds 4 ForAudit declarations + heavy predicate logic that
// previously lived inline in EBrainRuntimeCoordinator.runTurn(_:)
// (chapter 一百五十七 M583 — see lines 1808-1908 in the V1
// monolith) into a single typed factory:
//
//   - kunlunAxisForAudit            (BASKunlunAxis)
//   - kunlunMatched: Int            (centerline rules satisfied)
//   - kunlunDeviationCodes: [String] (typed deviation reason codes)
//   - kunlunAxisAlignmentForAudit   (BASAxisAlignment)
//
// Doctrine: kunlun.axis.* codes are observability-only at this
// milestone — no decision influence yet. M583 (chapter 一百五十七)
// replaced the 4-valued risk-level lookup table with real per-turn
// predicate evaluation against substrate state;the predicate
// semantics are preserved 1:1 by this fold (byte-equality required).
//
// Predicate semantics (parity with M583):
// 1. respects-host-boundary → quarantineRecords empty AND
//    permit not in {.block, .replace}
// 2. honors-world-anchor    → anchor tone not .reserved AND
//    abyssalPressure has no escalation hint
// 3. permit-mode-<X>        → permit mode is "cooperative"
//    (one of: .answer, .mirror, .compare, .delay,
//    .draftOnly, .localOnly)
//
// V1 byte-equality: every emission downstream of these 4 fields
// (axisProtocolBundle.axis.axisID, axis.activeLayerRefs, etc.)
// MUST match V1 byte-for-byte。 Stress-sweep dual mode gates
// this fold per chapter 四百七十八 regression-guard contract。

import Foundation
import BASOrchestration
import BASPolicy

public struct BASTurnAuditProjectionsKunlunAxisProtocol: Sendable {

    // MARK: - Folded fields

    public let axis: BASKunlunAxis
    public let matched: Int
    public let deviationCodes: [String]
    public let alignment: BASAxisAlignment

    // MARK: - Factory

    /// Inputs are all turn-local primitives + the 3 fileprivate
    /// constants from EBrainRuntimeCoordinator (passed in to keep
    /// constant visibility unchanged).
    public static func compute(
        sessionID: String,
        hostID: String,
        permitMode: BASActionPermitMode,
        riskLevel: BASBrainRiskLevel,
        quarantineRecordsIsEmpty: Bool,
        humanAnchorRecommendedSurfaceTone:
            BASHumanAnchorTone,
        sovereignEscalationHint: String?,
        primaryCandidateID: String,
        kunlunActiveLayerRefs: [String],
        centerlineRules: [String],
        kunlunAxisDeviationThreshold: Double
    ) -> BASTurnAuditProjectionsKunlunAxisProtocol {

        // 1) Synthetic axis
        let axis = BASKunlunAxis(
            axisID: "axis-\(sessionID)",
            hostRef: hostID,
            sovereignRef: "sovereign-\(sessionID)",
            worldAnchorRef: "world-anchor-\(sessionID)",
            activeLayerRefs: kunlunActiveLayerRefs,
            agentSeatRefs: [],
            centerlineRules: centerlineRules,
            deviationThreshold: kunlunAxisDeviationThreshold,
            lastAlignmentCheck: "")

        // 2) Three predicates (M583 chapter 一百五十七 contract)
        let respectsHostBoundary: Bool =
            quarantineRecordsIsEmpty
            && permitMode != .block
            && permitMode != .replace
        let honorsWorldAnchor: Bool =
            humanAnchorRecommendedSurfaceTone != .reserved
            && sovereignEscalationHint == nil
        let permitModeCooperative: Bool = {
            switch permitMode {
            case .answer, .mirror, .compare,
                 .delay, .draftOnly, .localOnly:
                return true
            case .block, .replace, .escalate:
                return false
            }
        }()

        // 3) Matched count
        let matched: Int = (respectsHostBoundary ? 1 : 0)
            + (honorsWorldAnchor ? 1 : 0)
            + (permitModeCooperative ? 1 : 0)

        // 4) Typed deviation codes
        let deviationCodes: [String] = {
            var codes: [String] = []
            if !respectsHostBoundary {
                codes.append("host-boundary-not-respected")
            }
            if !honorsWorldAnchor {
                codes.append("world-anchor-not-honored")
            }
            if !permitModeCooperative {
                codes.append("permit-mode-non-cooperative")
            }
            // Risk-level signal preserved as additive context
            switch riskLevel {
            case .low: break
            case .medium:
                codes.append("risk-medium-needs-attention")
            case .high:
                codes.append("risk-high-narrows-axis")
            case .extreme:
                codes.append("risk-extreme-axis-overreach")
            }
            return codes
        }()

        // 5) Alignment computation
        let alignment = BASKunlunAxisProtocol.computeAlignment(
            alignmentID: "axis-align-\(sessionID)",
            axis: axis,
            targetRef: primaryCandidateID,
            matchedRules: matched,
            deviationCodes: deviationCodes,
            correctionHint: "")

        return BASTurnAuditProjectionsKunlunAxisProtocol(
            axis: axis,
            matched: matched,
            deviationCodes: deviationCodes,
            alignment: alignment)
    }
}
