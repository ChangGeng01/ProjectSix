// MARK: - BASTurnAuditProjectionsKunlunTianmenTrio
// chapter 四百九十四 / M1353 — Tianmen trio fold
//
// Folds 3 ForAudit declarations + their inline constructions
// (lines 1979-2030 in V1 monolith pre-fold,~56 LOC of inline
// construction logic) into a single typed factory:
//
//   - kunlunAxisViewForAudit         (BASKunlunAxisView)
//   - kunlunTianmenWarrantForAudit?  (BASKunlunTianmenWarrant?)
//   - kunlunGateDenialWritForAudit?  (BASKunlunGateDenialWrit?)
//
// M424 (chapter 一百一) wired the 3 typed chapter 九十九 schemas
// into runtime so they're not just "typed-surface-only"。 Each
// schema derives from existing audit-projection state (zero new
// substrate dependencies)。 V1 byte-equality required;stress-
// sweep dual mode regression-guards every fold per chapter
// 四百七十八 contract。
//
// Doctrine pin (该断时断 — when warranted, deny):
//   - tianmenWarrant minted ONLY when readiness is true AND a
//     sovereign warrant exists (L14 substrate produced the
//     actual authorization);otherwise nil。
//   - gateDenialWrit minted ONLY when readiness is FALSE AND
//     reason codes are non-empty (a denial absent reason codes
//     is doctrinally forbidden)。
//
// These are mutually exclusive by construction:exactly one of
// (warrant, denial) is non-nil per turn — or both nil when the
// system is in an indeterminate / "warming up" state。
//
// HONEST ACCOUNTING:this fold replaces 3 inline-construction
// declarations with 4 alias bindings (1 bundle + 3 aliases)。
// `let xForAudit` declaration count rises by 1 per fold,but
// inline-construction LOC drops by ~52 lines。 Chapter 四百九十二
// scope correction acknowledged this measurement asymmetry;
// the TRUE measure is inline-construction-LOC,not declaration
// count。

import Foundation
import BASOrchestration
import BASPolicy

public struct BASTurnAuditProjectionsKunlunTianmenTrio: Sendable {

    // MARK: - Folded fields

    public let axisView: BASKunlunAxisView
    public let tianmenWarrant: BASKunlunTianmenWarrant?
    public let gateDenialWrit: BASKunlunGateDenialWrit?

    // MARK: - Factory

    public static func compute(
        sessionID: String,
        permitMode: BASActionPermitMode,
        primaryCandidateID: String,
        worldAnchorRef: String,
        centerlineRules: [String],
        deviationCodes: [String],
        heavenGateID: String,
        heavenGateIsReady: Bool,
        heavenGateReasonCodes: [String],
        firstSovereignWarrantID: String?,
        jadeCanonSealRef: String,
        riverOriginRef: String
    ) -> BASTurnAuditProjectionsKunlunTianmenTrio {

        // 1) BASKunlunAxisView (§5.4) — derived from existing
        //    axis state + deviation codes。
        let axisView = BASKunlunAxisView(
            worldRef: worldAnchorRef,
            centerlinePriors: centerlineRules,
            deviationPatterns: deviationCodes,
            scaleLadders: ["personal", "civilizational"],
            orderConstraints: centerlineRules)

        // 2) BASKunlunTianmenWarrant (§5.14) — only when
        //    readiness is true AND a sovereign warrant exists。
        let tianmenWarrant: BASKunlunTianmenWarrant? = {
            guard heavenGateIsReady,
                let firstWarrantID = firstSovereignWarrantID
            else { return nil }
            return BASKunlunTianmenWarrant(
                warrantID: "tianmen-warrant-\(firstWarrantID)",
                actionRef: "permit-\(permitMode.rawValue)",
                gateRef: heavenGateID,
                sovereignBasis: firstWarrantID,
                jadeCanonSealRef: jadeCanonSealRef,
                riverOriginRef: riverOriginRef,
                passScope: .scoped,
                expiry: "")
        }()

        // 3) BASKunlunGateDenialWrit (§5.14) — only when
        //    readiness is FALSE AND reason codes are non-empty
        //    (该断时断 — denials must carry typed reason codes)。
        let gateDenialWrit: BASKunlunGateDenialWrit? = {
            guard !heavenGateIsReady,
                !heavenGateReasonCodes.isEmpty
            else { return nil }
            return BASKunlunGateDenialWrit(
                writID: "tianmen-writ-\(sessionID)",
                sourceRef: primaryCandidateID,
                deniedDomain:
                    "domain-\(permitMode.rawValue)",
                reasonCodes: heavenGateReasonCodes,
                returnPathRef: "rollback-\(sessionID)",
                humanExplanationStub: "")
        }()

        return BASTurnAuditProjectionsKunlunTianmenTrio(
            axisView: axisView,
            tianmenWarrant: tianmenWarrant,
            gateDenialWrit: gateDenialWrit)
    }
}
