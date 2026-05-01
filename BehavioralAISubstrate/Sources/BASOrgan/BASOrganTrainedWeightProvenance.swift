import Foundation

/// M343 — typed provenance envelope for trained adapter weights.
/// Fills the **typed pin** leg of the v5 doctrine triple
/// (typed pin → measurement → regression gate) for the
/// `Adapter-trained L2` candidate parked in
/// `docs/QINAO_MANIFESTO_V5_DOCTRINE.md` appendix.
///
/// ## Why this exists
///
/// M67.4 / M295.2 ship `BASWorldPriorTrainingPipelineFilter` to gate
/// **curriculum content** at the training pipeline boundary —
/// only `.domainExpertReviewed` envelopes may flow into L2 training.
/// That gate protects what goes *in* to training.
///
/// Pre-M343 there was no mirrored gate for what comes *out* of
/// training: a third-party adapter, or a future in-house adapter,
/// could be plugged into `BASOrganRegistry` without any audit of
/// its training provenance. The runtime would happily route
/// requests to weights of unknown lineage.
///
/// M343 ships `BASOrganTrainedWeightProvenance` (the typed envelope
/// per adapter) plus `BASOrganTrainedWeightFilter` (the gate that
/// rejects weights below `.domainExpertReviewed`). The pair mirrors
/// the M295.2 shape so the curriculum-gate doctrine and the
/// trained-weight-gate doctrine compose cleanly.
///
/// ## Doctrine role
///
/// This is the **typed pin** for the v5 v6/v7 candidate "Adapter-
/// trained L2 doctrine". The candidate cannot be authored as v6
/// without this pin (per v5 §4: a doctrine claim with no typed
/// pin is forbidden). With this primitive in place, a future v6
/// authoring decision is unblocked.
///
/// What this primitive does NOT do:
///
/// - It does **not** verify the cryptographic signature on
///   `expertAttestationSignatureRef`. That's a downstream
///   verification step using existing `BASSovereignSignatureVerifier`
///   primitives.
/// - It does **not** measure the adapter's behavioural quality.
///   Quality is the AFM persona panel (M326) territory.
/// - It does **not** train anything. Training itself is EB-1
///   territory (`docs/QINAO_EXTERNAL_BOTTLENECKS_BACKLOG.md`).
public struct BASOrganTrainedWeightProvenance:
    Sendable, Equatable, Hashable, Codable
{

    // MARK: - Provenance tier (mirrors curriculum tier)

    /// Provenance tier ladder. Order matches
    /// `BASWorldPriorTemplateProvenance` so the two doctrines
    /// compose: only `.domainExpertReviewed` curriculum may train
    /// adapter weights, and only `.domainExpertReviewed` adapter
    /// weights may serve runtime requests.
    public enum Tier:
        String, Sendable, Equatable, Hashable, Codable,
        CaseIterable, Comparable
    {
        /// Adapter trained on illustrative content (e.g., M295.1
        /// Path A starter curriculum). Useful for scaffolding;
        /// MUST NOT serve production requests.
        case illustrative

        /// Adapter trained on AI-advisory content (e.g., M327
        /// 5-persona panel review output). Useful for review
        /// preparation; MUST NOT serve production requests.
        case aiAdvisory

        /// Adapter trained on peer-reviewed content (one human
        /// expert reviewed). Improvement over advisory; still
        /// below the production bar.
        case peerReviewed

        /// Adapter trained on content that passed full domain
        /// expert review with signed attestation. The only tier
        /// permitted to serve production runtime requests.
        case domainExpertReviewed

        public static func < (
            lhs: Tier, rhs: Tier
        ) -> Bool {
            lhs.ordinal < rhs.ordinal
        }

        private var ordinal: Int {
            switch self {
            case .illustrative: return 0
            case .aiAdvisory: return 1
            case .peerReviewed: return 2
            case .domainExpertReviewed: return 3
            }
        }
    }

    // MARK: - Fields

    /// Stable identifier of the trained adapter. Typically a
    /// SHA-256 prefix of the adapter weights file or a vendor
    /// product identifier (e.g., `"apple.foundation-models.v1.adapter.therapy.v1"`).
    public let adapterID: String

    /// Identifier of the base model these weights extend.
    /// Pattern: `"{vendor}.{model-family}.{version}"`.
    public let baseModelID: String

    /// Provenance tier per the ladder above.
    public let tier: Tier

    /// Reference to the curriculum corpus used for training.
    /// Typically a `BASWorldPriorTemplate` curriculum manifest hash
    /// or a `BASSovereignAuditEntry.auditID`.
    public let trainingCurriculumRef: String

    /// SHA-256 hex of the curriculum corpus bytes. 64 chars.
    /// Pin so a curriculum swap forces a provenance update.
    public let trainingCorpusHashHex: String

    /// SHA-256 hex of the trained weight bytes. 64 chars.
    /// Pin so a weight swap forces a provenance update.
    public let trainedWeightsHashHex: String

    /// Reference to the domain-expert attestation signature.
    /// Required when `tier == .domainExpertReviewed`; nil
    /// otherwise. Typically points to a `BASSovereignAuditEntry`
    /// carrying the expert's Ed25519 signature over
    /// `adapterID + trainedWeightsHashHex`.
    public let expertAttestationSignatureRef: String?

    /// Wall-clock timestamp the attestation was issued. Nil for
    /// non-attested tiers.
    public let attestationIssuedAt: Date?

    public init(
        adapterID: String,
        baseModelID: String,
        tier: Tier,
        trainingCurriculumRef: String,
        trainingCorpusHashHex: String,
        trainedWeightsHashHex: String,
        expertAttestationSignatureRef: String? = nil,
        attestationIssuedAt: Date? = nil
    ) {
        self.adapterID = adapterID
        self.baseModelID = baseModelID
        self.tier = tier
        self.trainingCurriculumRef = trainingCurriculumRef
        self.trainingCorpusHashHex = trainingCorpusHashHex
        self.trainedWeightsHashHex = trainedWeightsHashHex
        self.expertAttestationSignatureRef =
            expertAttestationSignatureRef
        self.attestationIssuedAt = attestationIssuedAt
    }

    // MARK: - Self-consistency

    /// Whether this envelope's fields are internally consistent.
    /// Production tier requires a non-nil attestation reference;
    /// non-production tiers must NOT carry one (otherwise it
    /// looks like a forged uplift).
    public var isStructurallyConsistent: Bool {
        let hashesAreCorrectLength =
            trainingCorpusHashHex.count == 64
            && trainedWeightsHashHex.count == 64
        let attestationConsistent: Bool
        switch tier {
        case .domainExpertReviewed:
            attestationConsistent =
                expertAttestationSignatureRef != nil
                && attestationIssuedAt != nil
        case .illustrative, .aiAdvisory, .peerReviewed:
            attestationConsistent =
                expertAttestationSignatureRef == nil
                && attestationIssuedAt == nil
        }
        return hashesAreCorrectLength
            && attestationConsistent
    }
}

/// M343 — typed gate analogous to `BASWorldPriorTrainingPipelineFilter`
/// but for trained adapter weights at the runtime registry boundary.
///
/// Doctrine: only `.domainExpertReviewed` adapter weights may be
/// loaded into a production `BASOrganRegistry`. Lower tiers may be
/// useful for in-development testing but MUST NOT be returned by
/// `adapter(for:role:)` in a production session.
///
/// A future v6 doctrine candidate "Adapter-trained L2 doctrine"
/// would use this gate as its enforcement primitive. v5 does not
/// yet author it; M343 ships the typed pin so the candidate becomes
/// authoring-ready.
public enum BASOrganTrainedWeightFilter {

    /// Typed rejection reasons. Calling sites switch on case for
    /// stable telemetry / audit reasons.
    public enum Rejection:
        Sendable, Equatable, Hashable, Codable
    {
        /// Provenance tier is below the runtime bar.
        case belowProductionTier(
            BASOrganTrainedWeightProvenance.Tier)

        /// Tier claims production but signature reference is
        /// missing or malformed (structurally inconsistent).
        case missingAttestationForProductionTier

        /// Hash field length is wrong (not 64 hex chars). The
        /// SHA-256 invariant is part of the typed pin.
        case malformedHash(field: String, length: Int)

        /// Non-production tier carries an attestation reference.
        /// This indicates a forged uplift attempt — the envelope
        /// is rejected even though the runtime would never have
        /// promoted it.
        case nonProductionTierCarriesAttestation
    }

    /// Minimum tier permitted to serve production runtime requests.
    /// Mirrors `BASWorldPriorTrainingPipelineFilter
    /// .trainingProvenanceFloor` so the curriculum-gate doctrine
    /// and the trained-weight-gate doctrine compose.
    public static let productionTierFloor:
        BASOrganTrainedWeightProvenance.Tier =
        .domainExpertReviewed

    /// Returns nil if the envelope is permitted into production
    /// runtime; otherwise returns the typed rejection reason.
    public static func rejectionReason(
        for provenance: BASOrganTrainedWeightProvenance
    ) -> Rejection? {
        // Hash length pin first — structural invariant.
        if provenance.trainingCorpusHashHex.count != 64 {
            return .malformedHash(
                field: "trainingCorpusHashHex",
                length: provenance.trainingCorpusHashHex.count)
        }
        if provenance.trainedWeightsHashHex.count != 64 {
            return .malformedHash(
                field: "trainedWeightsHashHex",
                length: provenance.trainedWeightsHashHex.count)
        }
        // Tier check.
        if provenance.tier < productionTierFloor {
            // If it claims a non-production tier but carries an
            // attestation, surface the forged-uplift signal
            // explicitly rather than the plain tier rejection.
            if provenance.expertAttestationSignatureRef != nil {
                return .nonProductionTierCarriesAttestation
            }
            return .belowProductionTier(provenance.tier)
        }
        // Production tier missing attestation.
        if provenance.expertAttestationSignatureRef == nil
            || provenance.attestationIssuedAt == nil
        {
            return .missingAttestationForProductionTier
        }
        return nil
    }

    /// Convenience — does this provenance envelope pass the
    /// production gate?
    public static func isPermittedForProduction(
        _ provenance: BASOrganTrainedWeightProvenance
    ) -> Bool {
        rejectionReason(for: provenance) == nil
    }

    /// Filter a batch of envelopes, returning only those permitted
    /// for production. Order preserved.
    public static func acceptedForProduction(
        _ provenances: [BASOrganTrainedWeightProvenance]
    ) -> [BASOrganTrainedWeightProvenance] {
        provenances.filter { isPermittedForProduction($0) }
    }
}
