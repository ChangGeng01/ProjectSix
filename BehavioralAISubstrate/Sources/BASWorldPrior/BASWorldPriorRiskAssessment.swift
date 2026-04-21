import Foundation

/// Structured assessment of an operation's world-prior risk, derived
/// from matching a proposed intent to one or more causal templates
/// in the vault.
///
/// This type is the contract by which L4 world knowledge is consumed
/// by upstream reasoners (L11 risk gate, L14 verdict engine,
/// L9 dream loop). Consumers read `irreversibleHarmScore` /
/// `requiresConsent` / `evidenceSufficient` to populate their own
/// decision surfaces without having to re-encode the "what does
/// reversibility mean" logic per call-site.
public struct BASWorldPriorRiskAssessment: Hashable, Codable, Sendable {
    /// Template that matched the proposed intent.
    public let matchedTemplateID: String
    /// Domain of the matched template.
    public let domain: BASWorldPriorDomain
    /// Reversibility category copied from the template.
    public let reversibility: BASWorldPriorCausalTemplate.Reversibility
    /// Evidence level copied from the template.
    public let evidenceLevel: BASWorldPriorEvidenceLevel
    /// Whether the matched template requires informed consent from
    /// another party (ethics-domain irreversible templates).
    public let requiresConsent: Bool
    /// Normalized [0.0, 1.0] score contributing to
    /// `SoftSignals.irreversibleHarm`. Derived from reversibility ×
    /// effectKind × domain weight. Pre-computed so consumers don't
    /// re-derive it.
    public let irreversibleHarmScore: Double
    /// Whether the template's evidence level is strong enough to
    /// support an irreversible operation without additional
    /// corroboration. Maps to VerdictContext.evidenceSufficient.
    public let evidenceSufficient: Bool

    public init(
        matchedTemplateID: String,
        domain: BASWorldPriorDomain,
        reversibility: BASWorldPriorCausalTemplate.Reversibility,
        evidenceLevel: BASWorldPriorEvidenceLevel,
        requiresConsent: Bool,
        irreversibleHarmScore: Double,
        evidenceSufficient: Bool
    ) {
        self.matchedTemplateID = matchedTemplateID
        self.domain = domain
        self.reversibility = reversibility
        self.evidenceLevel = evidenceLevel
        self.requiresConsent = requiresConsent
        self.irreversibleHarmScore =
            max(0.0, min(1.0, irreversibleHarmScore))
        self.evidenceSufficient = evidenceSufficient
    }
}

extension BASWorldPriorVault {

    /// Produce a structured risk assessment for the given template ID.
    /// Returns nil if the template is unknown.
    ///
    /// ## Score derivation
    ///
    /// `irreversibleHarmScore` = reversibility weight × effectKind
    /// weight × domain weight, clamped to `[0, 1]`:
    ///
    /// - reversibility: trivial = 0.05, bounded = 0.3, costly = 0.7,
    ///   irreversible = 1.0
    /// - effectKind: relationshipChange & valueTransfer = 1.0;
    ///   physicalChange = 0.9; stateTransition = 0.6;
    ///   informationShift = 0.4; skillGainOrLoss = 0.3
    /// - domain: ethics = 1.1 (upgrade), money/social = 1.0,
    ///   body/physics = 0.9, others = 0.7
    ///
    /// Ethics-domain irreversible templates additionally set
    /// `requiresConsent = true` — this is the L4 invariant that
    /// makes the "no irreversible harm without informed consent"
    /// spec rule enforceable.
    public func assessRisk(
        templateID: String
    ) -> BASWorldPriorRiskAssessment? {
        guard let t = template(id: templateID) else { return nil }
        let rev: Double = {
            switch t.reversibility {
            case .trivial: return 0.05
            case .bounded: return 0.30
            case .costly: return 0.70
            case .irreversible: return 1.00
            }
        }()
        let kind: Double = {
            switch t.effectKind {
            case .relationshipChange, .valueTransfer: return 1.0
            case .physicalChange: return 0.9
            case .stateTransition: return 0.6
            case .informationShift: return 0.4
            case .skillGainOrLoss: return 0.3
            }
        }()
        let domainWeight: Double = {
            switch t.domain {
            case .ethics: return 1.1
            case .money, .social: return 1.0
            case .body, .physics: return 0.9
            default: return 0.7
            }
        }()
        let raw = rev * kind * domainWeight
        let score = max(0.0, min(1.0, raw))

        let requiresConsent =
            t.domain == .ethics && t.reversibility == .irreversible

        // For irreversible operations we require wellSupported+ to
        // call the evidence sufficient. Weaker evidence on an
        // irreversible template means the verdict engine should
        // upgrade the floor (see VerdictEngine stage 3).
        let evidenceSufficient: Bool = {
            if t.reversibility == .irreversible {
                return t.evidence.rank
                    >= BASWorldPriorEvidenceLevel.wellSupported.rank
            }
            return true
        }()

        return BASWorldPriorRiskAssessment(
            matchedTemplateID: t.id,
            domain: t.domain,
            reversibility: t.reversibility,
            evidenceLevel: t.evidence,
            requiresConsent: requiresConsent,
            irreversibleHarmScore: score,
            evidenceSufficient: evidenceSufficient
        )
    }
}
