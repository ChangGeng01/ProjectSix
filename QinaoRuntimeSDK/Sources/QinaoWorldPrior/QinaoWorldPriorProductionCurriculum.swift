import Foundation

// 五十八.3 — typed scaffold for M295.1+ authoritative
// production curriculum.
//
// ## Why this exists
//
// `BASWorldPriorStarterCurriculum` (M296.x) ship 50 条
// **illustrative** starter templates。production curriculum
// 等级 (`.domainExpertReviewed` 或更高) 是另一档：
// **必须由 domain expert 走 typed authoring track 升级**。
//
// `BASWorldPriorProductionCurriculum` ship typed entry point
// for production content — empty by default, expert content
// 加入时必须携带 typed `BASWorldPriorTemplateAuthoringSession`
// 证明已走 `.draft → .hostReviewed → .peerReview →
// .domainApproved` 全流程。
//
// ## Doctrine
//
// - **Empty by default.** 0 production templates ship 在
//   repo——这是 honest signal that production curriculum 仍未
//   有 domain experts 审过。
// - **Typed entry point.** 加入 production template 必须同时
//   提供 attestation：`BASWorldPriorTemplateAttestation`
//   binding envelope ↔ authoring session。`registerEntry`
//   refuses any envelope < `.domainExpertReviewed`。
// - **Audit-friendly.** Each registered entry exposes its
//   typed authoring session so audit code can verify the
//   stage walk + history.

/// One production curriculum entry — production-grade envelope
/// + the authoring session that lifted it through stages.
public struct BASWorldPriorProductionCurriculumEntry:
    Sendable, Equatable, Hashable, Codable
{
    public let envelope: BASWorldPriorTemplateEnvelope
    public let authoringSession:
        BASWorldPriorTemplateAuthoringSession

    public init(
        envelope: BASWorldPriorTemplateEnvelope,
        authoringSession:
            BASWorldPriorTemplateAuthoringSession
    ) {
        self.envelope = envelope
        self.authoringSession = authoringSession
    }

    /// True iff the entry's attestation binding holds AND the
    /// envelope's provenance is ≥ `.domainExpertReviewed`.
    public var isProductionGrade: Bool {
        guard envelope.provenance >= .domainExpertReviewed
        else { return false }
        let attestation = BASWorldPriorTemplateAttestation(
            envelope: envelope,
            authoringSession: authoringSession)
        return BASWorldPriorTemplateAttestationGate.isValid(
            attestation)
    }
}

/// Typed registry for production-grade L4 templates.
///
/// **Empty by default.** Production content requires domain
/// experts to walk templates through the typed authoring
/// track. This registry refuses any entry that doesn't pass
/// attestation + provenance floor.
public struct BASWorldPriorProductionCurriculum:
    Sendable, Equatable, Hashable, Codable
{
    /// All registered entries, in insertion order.
    public private(set) var entries: [
        BASWorldPriorProductionCurriculumEntry
    ]

    public init(
        entries: [BASWorldPriorProductionCurriculumEntry]
            = []
    ) {
        // Defensive: only keep production-grade entries.
        // A constructor that silently dropped non-grade
        // entries would mask bugs; instead, accept all and
        // let `isProductionGrade` answer per-entry. Filtering
        // is the registrant's job.
        self.entries = entries
    }

    /// Register a new entry. Returns the new curriculum if
    /// the entry is production-grade; nil if it fails the
    /// attestation gate or provenance floor.
    public func registering(
        _ entry: BASWorldPriorProductionCurriculumEntry
    ) -> BASWorldPriorProductionCurriculum? {
        guard entry.isProductionGrade else { return nil }
        var copy = self
        copy.entries.append(entry)
        return copy
    }

    /// Lookup by templateID.
    public func entry(
        for templateID: String
    ) -> BASWorldPriorProductionCurriculumEntry? {
        entries.first {
            $0.envelope.input.templateID == templateID
        }
    }

    /// Production envelopes only — convenience for callers
    /// that want the audit trail attached.
    public var productionEnvelopes: [
        BASWorldPriorTemplateEnvelope
    ] {
        entries
            .filter(\.isProductionGrade)
            .map(\.envelope)
    }

    /// Counts grouped by attained provenance.
    public var provenanceCounts: [
        BASWorldPriorTemplateProvenance: Int
    ] {
        var counts: [
            BASWorldPriorTemplateProvenance: Int
        ] = [:]
        for entry in entries
            where entry.isProductionGrade
        {
            counts[
                entry.envelope.provenance, default: 0
            ] += 1
        }
        return counts
    }

    /// Empty curriculum sentinel — explicit naming for
    /// "no production content yet" reads better than
    /// `BASWorldPriorProductionCurriculum()`.
    public static let empty:
        BASWorldPriorProductionCurriculum =
        BASWorldPriorProductionCurriculum(entries: [])
}

/// Walkthrough helper — produces the authoring session that
/// would result from a domain expert walking a draft through
/// the typed track to `.domainApproved`. Used by tests +
/// reference docs to demonstrate the lineage shape callers
/// must produce.
public enum BASWorldPriorProductionCurriculumWalkthrough {
    /// Walk a fresh session through hostAccept → peerReview
    /// → approveDomain. Returns nil if any transition is
    /// invalid (won't happen for a fresh session, but the
    /// optional return makes the contract honest).
    public static func walkToDomainApproved(
        templateID: String
    ) -> BASWorldPriorTemplateAuthoringSession? {
        var s = BASWorldPriorTemplateAuthoringSession(
            templateID: templateID)
        guard let s1 = s.applying(.hostAccept) else {
            return nil
        }
        s = s1
        guard let s2 = s.applying(
            .submitForPeerReview)
        else {
            return nil
        }
        s = s2
        guard let s3 = s.applying(.approveDomain) else {
            return nil
        }
        return s3
    }
}
