// MARK: - BASTurnAuditProjectionsKunlunSealRiver
// chapter 四百九十三 / M1350 — Kunlun jade seal + river origin fold
//
// Folds 4 ForAudit declarations (lines 1920-1992 in V1 monolith
// pre-fold) into a single typed factory:
//
//   - kunlunJadeSealForAudit         (BASJadeCanonSeal)
//   - kunlunJadeVerificationForAudit (BASKunlunJadeCanonProtocol.Verification)
//   - kunlunRiverTraceForAudit       (BASRiverOriginTrace)
//   - kunlunRiverLineageForAudit     (BASKunlunRiverOriginProtocol.LineageReport)
//
// Doctrine §4.2 (jade canon) + §4.5 (river origin):
//   无来源不成玉 / 无签名不进门 / 无回放不升格 /
//   无撤销路径不得长期生效  (jade canon)
//   没有源流就没有可信成长。(river origin)
//
// Audit-only emission — actual seal-driven gating is M413+
// composability work (chapter 九十五)。 V1 byte-equality required;
// stress-sweep dual mode regression-guards every fold per chapter
// 四百七十八。

import Foundation
import BASOrchestration
import BASPolicy

public struct BASTurnAuditProjectionsKunlunSealRiver:
    Codable, Equatable, Sendable
{

    // MARK: - Folded fields

    public let seal: BASJadeCanonSeal
    public let verification:
        BASKunlunJadeCanonProtocol.Verification
    public let trace: BASRiverOriginTrace
    public let lineage:
        BASKunlunRiverOriginProtocol.LineageReport

    // MARK: - Factory

    public static func compute(
        sessionID: String,
        permitMode: BASActionPermitMode,
        requireMirror: Bool,
        requireCompare: Bool,
        requireSecondCheck: Bool,
        verdictID: String,
        verdictLevel: String,
        warrantIDs: [String],
        candidateIDs: [String],
        quarantineIDs: [String],
        thoughtFoldID: String,
        thoughtFoldChecksum: String,
        riverOriginTransformationSteps: [String]
    ) -> BASTurnAuditProjectionsKunlunSealRiver {

        // 1) Jade canon seal — §4.2 doctrine。 Class always
        // .actionPermit since the permit IS the high-integrity
        // object being sealed at L11。
        let seal = BASJadeCanonSeal(
            sealID: "jade-permit-\(sessionID)",
            targetRef: "permit-\(permitMode.rawValue)",
            objectClass: .actionPermit,
            targetSchemaVersion:
                BASActionPermit.currentSchemaVersion,
            provenanceRefs: {
                var refs: [String] = []
                refs.append("verdict-\(verdictID)")
                refs.append(contentsOf: warrantIDs)
                if !thoughtFoldID.isEmpty {
                    refs.append("fold-\(thoughtFoldID)")
                }
                return refs
            }(),
            integrityHash: thoughtFoldChecksum,
            signatureRef: verdictID,
            replayRequired: requireMirror
                || requireCompare
                || requireSecondCheck,
            revocationPath: "rollback-\(sessionID)",
            sourceRiverRef: "river-\(sessionID)")
        let verification = BASKunlunJadeCanonProtocol
            .verifySeal(seal)

        // 2) River origin trace — §4.5 doctrine。 Roots from
        // session ref + verdict ref;tributaries from candidate
        // IDs;derived from permit + warrants;transformations
        // from the pipeline stages we observably ran;consents
        // from quarantine records;permits from bound permit;
        // audit refs from the about-to-be-emitted audit entry's
        // stable prefix。
        let trace = BASRiverOriginTrace(
            traceID: "river-\(sessionID)",
            rootSourceRefs: [
                "session-\(sessionID)",
                "verdict-\(verdictID)",
            ],
            tributaryRefs: candidateIDs,
            derivedObjectRefs: {
                var refs: [String] = []
                refs.append("permit-\(permitMode.rawValue)")
                refs.append(contentsOf: warrantIDs)
                return refs
            }(),
            transformationSteps:
                riverOriginTransformationSteps,
            consentRefs: quarantineIDs,
            permitRefs: ["permit-\(permitMode.rawValue)"],
            auditRefs: [
                "audit.\(sessionID).\(verdictLevel)",
            ],
            deletionDependents: [],
            lineageCutRefs: [])
        let lineage = BASKunlunRiverOriginProtocol
            .analyze(trace)

        return BASTurnAuditProjectionsKunlunSealRiver(
            seal: seal,
            verification: verification,
            trace: trace,
            lineage: lineage)
    }
}
