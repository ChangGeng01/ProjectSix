import Foundation

// M295.2 — typed training-pipeline filter enforcing Doctrine A
// from honesty-board 四十五: 宿主私有经验 NEVER 直接进 L2 权重.
//
// ## Why this exists
//
// M295.1 ship 了 4 等级 provenance markers + envelope + gate, but
// the gate operates on "is this template usable in production curriculum".
// 训练管线（offline distillation / fine-tune that touches L2 weights）
// 是更严的信任边界——only content with **non-private + reviewed**
// provenance may flow in. M295.2 makes that boundary typed and
// auditable: pipelines call the filter; a non-nil rejection means
// "do not feed this into L2 training".
//
// ## Doctrine
//
// Doctrine A: 宿主私有经验 NEVER 直接进 L2 权重.
//
// Filter accepts iff:
// 1. provenance ≥ `.domainExpertReviewed` (peer-reviewed or
//    canonical) — `.illustrative` and `.hostReviewed` are
//    treated as private / un-vetted for the training boundary
// 2. M295.0 input acceptance passes
//
// Rejections are *typed* — pipelines branch on case.
//
// ## When this matters
//
// Training data ingestion code MUST call this filter before
// adding any envelope to its training set. Calling sites that
// skip the filter are auditable: search for envelopes flowing
// into training without `rejectionReason(for:)` upstream is the
// review query.

public enum BASWorldPriorTrainingPipelineFilter {

    /// Typed rejection reasons. Pipeline code should switch on
    /// case for stable logging / metrics.
    public enum Rejection:
        Sendable, Equatable, Hashable, Codable
    {
        /// Provenance is below the training threshold
        /// (`.domainExpertReviewed`). The actual provenance is
        /// included so audit can group rejections by level.
        case privateProvenance(
            BASWorldPriorTemplateProvenance)

        /// M295.0 input acceptance failed; one or more issues
        /// returned. Carries the issues for diagnostic logging.
        case unacceptableInput(
            [BASWorldPriorTemplateAcceptance.Issue])
    }

    /// Minimum provenance for training: peer-review or canonical.
    /// `.illustrative` (starter) and `.hostReviewed` (host-private,
    /// no external audit) are below the line.
    public static let trainingProvenanceFloor:
        BASWorldPriorTemplateProvenance = .domainExpertReviewed

    /// Returns nil if the envelope is permitted into training;
    /// otherwise returns the typed rejection reason. Pipeline
    /// callers branch on result.
    public static func rejectionReason(
        for envelope: BASWorldPriorTemplateEnvelope
    ) -> Rejection? {
        // Provenance check first — fast and doctrinally primary.
        if envelope.provenance < trainingProvenanceFloor {
            return .privateProvenance(envelope.provenance)
        }
        // Then M295.0 input shape check.
        let issues = BASWorldPriorTemplateAcceptance.validate(
            envelope.input)
        if !issues.isEmpty {
            return .unacceptableInput(issues)
        }
        return nil
    }

    /// Convenience — does this envelope pass the training filter?
    public static func isPermittedForTraining(
        _ envelope: BASWorldPriorTemplateEnvelope
    ) -> Bool {
        rejectionReason(for: envelope) == nil
    }

    /// Filter a batch of envelopes, returning only those
    /// permitted for training. Order preserved.
    public static func acceptedForTraining(
        _ envelopes: [BASWorldPriorTemplateEnvelope]
    ) -> [BASWorldPriorTemplateEnvelope] {
        envelopes.filter { isPermittedForTraining($0) }
    }
}
