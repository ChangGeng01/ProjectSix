import Foundation

/// Abstract world-prior oracle that `QinaoRiskGate` consults when a
/// caller wants the L4 layer ("懂世界") folded into the permit
/// decision. Analogous to `QinaoOrganEndpoint` in `QinaoLoop`: the
/// public surface is a single protocol over Qinao-local value types;
/// the adapter that wraps the substrate's world-prior vault stays
/// internal so `BAS*` symbols never leak through the SDK.
///
/// ## Contract
///
/// 1. `assessRisk(templateID:)` returns a `WorldRiskAssessment` if
///    the caller's template ID is registered in the underlying
///    vault, otherwise `nil`. The endpoint must NOT throw for
///    "unknown template" — nil is the documented absence signal so
///    the gate can translate it into a typed `RiskError`.
/// 2. Implementations are expected to be `Sendable`, idempotent on
///    identical template IDs, and to surface side-channel errors
///    (network, storage, adapter) as Swift errors thrown from this
///    method.
/// 3. Hosts that already own a `BASWorldPriorVault` can use the
///    internal `BASWorldPriorEndpointAdapter` (bootstrapped by
///    `QinaoRiskGate.withWorldPriorVault(...)`); any other backend
///    — remote service, rule file, mock — just conforms directly.
public protocol QinaoWorldPriorEndpoint: Sendable {
    /// Ask the underlying world-prior vault for a structured risk
    /// assessment of the given template ID. Returns `nil` when the
    /// template is unknown (the gate translates nil → typed error).
    func assessRisk(
        templateID: String
    ) async throws -> QinaoRiskGate.WorldRiskAssessment?
}

extension QinaoRiskGate {

    /// Host-supplied context that pairs a proposed intent with the
    /// world-prior template the caller believes it matches. The
    /// tagging policy is up to the caller: L9 dream-loop projection
    /// produces the mapping upstream, rule-based routers can hard-
    /// code it, tests pass it explicitly.
    ///
    /// `consentAcknowledged` is only consulted when the matched
    /// template's `requiresConsent == true` (ethics-domain
    /// irreversible templates). Setting it `false` — the default —
    /// causes the gate to refuse the permit in `.replace` mode with
    /// a stable reason code, so the host can prompt the user for
    /// informed consent without guessing which intents need it.
    public struct WorldRiskContext: Sendable, Equatable {
        public let templateID: String
        public let consentAcknowledged: Bool

        public init(
            templateID: String,
            consentAcknowledged: Bool = false
        ) {
            self.templateID = templateID
            self.consentAcknowledged = consentAcknowledged
        }
    }

    /// Qinao-local projection of the substrate's world-prior risk
    /// assessment. Carries exactly the four fields the gate needs
    /// to merge into the permit decision — no domain enum, no
    /// template schema, no reversibility category — so upstream
    /// host code can write to this surface without importing BAS.
    public struct WorldRiskAssessment: Sendable, Equatable, Codable {
        /// Normalized [0, 1] irreversible-harm score. The gate folds
        /// this into `RiskSignals.irreversibility` via `max`.
        public let irreversibleHarmScore: Double
        /// Whether the matched template belongs to the ethics-domain
        /// irreversible tier, i.e. the host MUST obtain informed
        /// consent before the action can proceed.
        public let requiresConsent: Bool
        /// Whether the template's evidence level is strong enough
        /// to support an irreversible operation without additional
        /// corroboration.
        public let evidenceSufficient: Bool
        /// Template ID that produced this assessment, echoed back
        /// for audit-log cross-reference.
        public let matchedTemplateID: String

        public init(
            irreversibleHarmScore: Double,
            requiresConsent: Bool,
            evidenceSufficient: Bool,
            matchedTemplateID: String
        ) {
            self.irreversibleHarmScore =
                max(0.0, min(1.0, irreversibleHarmScore))
            self.requiresConsent = requiresConsent
            self.evidenceSufficient = evidenceSufficient
            self.matchedTemplateID = matchedTemplateID
        }
    }
}
