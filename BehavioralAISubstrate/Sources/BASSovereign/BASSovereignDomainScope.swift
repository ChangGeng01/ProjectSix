// SPDX-License-Identifier: Apache-2.0
// M517 (chapter 一百三十) — Sovereign Domain Scope typed pin per
// user 8-point audit Point 5 (chapter 一百三十 Appendix P.5).
//
// ## Why this exists
//
// L14 sovereign layer is doctrinally powerful but easy to creep:
//
//   1. 误触发 — over-sensitive triggers make the system unusable
//      (constant ToolCut / MemoryFreeze / Rollback / DeadStop)
//   2. 不可解释 — opaque rules make development teams afraid of
//      L14
//   3. 权力蔓延 — anything difficult-to-classify gets stuffed into
//      L14, turning it from "main sovereignty" into "万能否决层"
//
// User audit doctrine: "L14 必须像核按钮，不是总控台。" — L14 must
// be a nuclear button, not a master control panel.
//
// L14 emissions MUST be limited to 6 sovereign domains:
//
//   1. 合法性 (legitimacy) — does this action have proper authorization?
//   2. 删除/回滚 (delete-rollback) — irreversible state changes
//   3. 越权 (privilege-escalation) — boundary-crossing attempts
//   4. 工件完整性 (artifact-integrity) — checksum / signature / replay
//   5. 污染谱系 (lineage-pollution) — tainted derivation chains
//   6. 高后果提交资格 (high-consequence-commit) — irreversible high-impact decisions
//
// Anything outside these 6 scopes does NOT belong in L14:
// - 普通风险 → L11
// - 产品体验 → L12
// - 风格偏好 → L5
// - 多数业务逻辑 → L1-L13
//
// ## Doctrine pins
//
// - **BR-014 typed pin** (new red line, chapter 一百三十):
//   L14 emissions ONLY emit reason codes mappable to one of 6
//   sovereign-domain scopes. Lint test enforces.
// - **Stable kebab-case raw values** for cross-module audit-walker
//   grep.
// - **Anti-drift**: 6-case `CaseIterable` enum; future additions
//   require explicit doctrine review.
//
// ## DAG discipline
//
// Imports `Foundation` only. Pure value type. Lives in
// `BASSovereign` (L14's home library).

import Foundation

// MARK: - BASSovereignDomainScope

/// 6 typed scopes per audit Point 5 doctrine. L14 emissions
/// (sovereign verdict, warrant, commit token, audit signalRefs
/// with `sovereign.*` prefix) MUST be classified under exactly
/// one of these scopes.
public enum BASSovereignDomainScope:
    String, Sendable, Equatable, Codable, Hashable, CaseIterable
{
    /// 合法性 — has the action been properly authorized? E.g.
    /// missing permit, missing warrant, expired token, untrusted
    /// origin.
    case legitimacy = "legitimacy"
    /// 删除 / 回滚 — irreversible state changes. E.g. memory
    /// purge, host version rollback, lineage cut.
    case deleteRollback = "delete-rollback"
    /// 越权 — boundary-crossing attempts. E.g. tool write outside
    /// permit-allowed domain, host-version write without sovereign
    /// warrant.
    case privilegeEscalation = "privilege-escalation"
    /// 工件完整性 — checksum / signature / replay verification
    /// failures. E.g. snapshot integrity hash mismatch, audit
    /// ledger chain break, fold checksum drift.
    case artifactIntegrity = "artifact-integrity"
    /// 污染谱系 — tainted derivation chains. E.g. ForbiddenZone
    /// candidate accidentally re-entering selection, contaminated
    /// memory atom in retrieval, training-export sample with
    /// unauthorized lineage.
    case lineagePollution = "lineage-pollution"
    /// 高后果提交资格 — irreversible high-impact decisions
    /// requiring sovereign sign-off. E.g. tool write of high-
    /// risk class, host-version migration commit, sovereign-only
    /// memory reveal.
    case highConsequenceCommit = "high-consequence-commit"

    /// Whitepaper reference per audit Point 5 + chapter 一百三十
    /// Appendix P.5.
    public var whitePaperRef: String {
        switch self {
        case .legitimacy:
            return "Audit Point 5 (chapter 一百三十 P.5) — sovereign-only legitimacy domain"
        case .deleteRollback:
            return "Audit Point 5 (chapter 一百三十 P.5) — irreversible state-change domain"
        case .privilegeEscalation:
            return "Audit Point 5 (chapter 一百三十 P.5) — boundary-crossing domain"
        case .artifactIntegrity:
            return "Audit Point 5 (chapter 一百三十 P.5) — checksum/signature/replay domain"
        case .lineagePollution:
            return "Audit Point 5 (chapter 一百三十 P.5) — tainted-derivation-chain domain"
        case .highConsequenceCommit:
            return "Audit Point 5 (chapter 一百三十 P.5) — irreversible high-impact-decision domain"
        }
    }

    /// Stable kebab-case substrings that, when present in an L14
    /// emission's reason code, signal scope creep beyond the
    /// 6 sovereign domains. Lint test asserts no L14 emission
    /// reason code contains any of these substrings.
    ///
    /// These cover BR-010 主品牌不默认恐怖化 + product-tier
    /// product-experience / style-preference / business-logic
    /// surface concepts that shouldn't bubble up to L14.
    public static let forbiddenSubstrings: [String] = [
        "style-preference",   // L5 host constitution domain
        "product-experience", // L12 surface domain
        "casual-risk",        // L11 risk gate domain
        "tool-routine",       // L11/L13 normal-flow domain
        "ux-polish",          // L12 surface polish
        "compare-mode-pick",  // L11/L12 routine surface decision
    ]

    /// Brief policy description per scope for governance
    /// documentation.
    public var policyDescription: String {
        switch self {
        case .legitimacy:
            return "Sovereign-only verdict on whether action carries proper authorization (permit + warrant + token chain)."
        case .deleteRollback:
            return "Sovereign-only verdict on irreversible state changes; routes through audit ledger + lineage tracing."
        case .privilegeEscalation:
            return "Sovereign-only verdict on boundary-crossing attempts beyond permit-allowed domain."
        case .artifactIntegrity:
            return "Sovereign-only verdict on checksum / signature / replay verification failures."
        case .lineagePollution:
            return "Sovereign-only verdict on tainted derivation chains; routes through ForbiddenZone + quarantine."
        case .highConsequenceCommit:
            return "Sovereign-only verdict on irreversible high-impact decisions requiring explicit sovereign sign-off."
        }
    }
}

// MARK: - BASSovereignDomainScopeLinter

/// Static linter checking that a given audit reason-code string
/// stays within sovereign-domain bounds (BR-014 typed pin).
public enum BASSovereignDomainScopeLinter {

    /// Returns the list of forbidden substring violations found
    /// in `reasonCode`. Empty result means the reason code is
    /// scope-clean (no creep beyond 6 sovereign domains).
    public static func violations(
        in reasonCode: String
    ) -> [String] {
        let lowered = reasonCode.lowercased()
        return BASSovereignDomainScope.forbiddenSubstrings.filter {
            lowered.contains($0)
        }
    }

    /// Convenience: `true` when the reason code is scope-clean.
    public static func isWithinSovereignScope(
        _ reasonCode: String
    ) -> Bool {
        violations(in: reasonCode).isEmpty
    }
}
