import Foundation
import BASWorldPrior

/// QinaoWorldPrior — the L4 **world-prior** façade.
///
/// ## Role
///
/// This is the "懂世界" half of Invariant 2's "懂世界也懂宿主" pair.
/// `QinaoHost` already gives hosts a first-class surface for the L5
/// host constitution (the "懂宿主" half). Until M50 the L4 world
/// layer was only reachable indirectly — through `QinaoRisk`'s
/// permit gate — which made the invariant half-truthful at the SDK
/// boundary: hosts could not inspect what the second brain *knew*
/// about the world, only accept or reject its downstream risk
/// verdicts.
///
/// This module closes that gap by exposing the substrate's
/// `BASWorldPriorVault` as a Qinao-owned actor with Qinao-owned
/// mirror types. The actor is a thin translation over the vault:
/// every query is forwarded, every result is projected back through
/// a pure `QinaoWorldPriorProjection` helper, and every registration
/// is projected forward. No `BAS*` symbol crosses the public
/// surface — callers never need to import `BASWorldPrior` to use
/// the vault.
///
/// ## Bootstrap
///
/// Two init paths:
///
/// 1. `init()` — empty vault. Hosts register their own horizons,
///    templates, and bridges.
/// 2. `init(seedingBuiltIns:)` — seeds from
///    `BASWorldPriorBuiltInLibrary` so the vault starts with the
///    20-template × 8-domain × 8-bridge canonical library. This is
///    the right choice when the host wants "all of physics / body /
///    time / money / social / language / learning / ethics by
///    default" and only adds domain-specific templates on top.
///
/// ## Public API boundary
///
/// All public types live in `QinaoWorldPriorTypes.swift` and carry
/// the `QinaoWorldPrior*` prefix; they are value-type mirrors of the
/// substrate schemas. The actor's errors are a Qinao-owned
/// `VaultError` enum; the counterfactual seeder is composed in
/// internally so callers see a single surface.
public actor QinaoWorldPriorVault {

    /// Typed error codes the vault can surface. Stable reason codes
    /// suitable for host UI copy keys; translated from the
    /// substrate's own typed errors in `translate(_:)`.
    public enum VaultError: Error, Equatable, Sendable {
        case duplicateHorizonDomain(String)
        case duplicateTemplateID(String)
        case duplicateBridgeID(String)
        case duplicateAxiomID(String)
        case unknownTemplate(String)
        case unknownBridge(String)
        case axiomCollision(id: String, incoming: String, resident: String)
        case bridgeReferencesUnknownTemplate(
            bridgeID: String,
            templateID: String)
        /// The substrate surfaced an error that does not correspond
        /// to any of the enumerated cases above. Carries a stable
        /// reason string for debugging but should never be hit on
        /// supported paths; if you see it, the substrate's vault
        /// API grew a case we haven't mirrored yet.
        case substrateError(reason: String)
    }

    // MARK: - State

    private let vault: BASWorldPriorVault
    private let seeder: BASWorldPriorCounterfactualSeeder

    // MARK: - Initialisation

    /// Create an empty vault. Hosts grow the world layer themselves
    /// via `registerHorizon(_:)` / `registerTemplate(_:)` /
    /// `registerBridge(_:)`.
    public init() {
        self.vault = BASWorldPriorVault()
        self.seeder = BASWorldPriorCounterfactualSeeder(vault: self.vault)
    }

    /// Create a vault and optionally pre-load it with the canonical
    /// 20-template × 8-domain × 8-bridge library.
    ///
    /// - Parameters:
    ///   - seedingBuiltIns: if `true`, invokes
    ///     `BASWorldPriorBuiltInLibrary.bootstrap(into:)` during
    ///     construction so the vault starts with 8 horizons, 20+
    ///     causal templates, 8+ cross-domain bridges and all
    ///     boundary-bedrock axioms.
    public init(seedingBuiltIns: Bool) async throws {
        self.vault = BASWorldPriorVault()
        self.seeder = BASWorldPriorCounterfactualSeeder(vault: self.vault)
        if seedingBuiltIns {
            do {
                try await BASWorldPriorBuiltInLibrary.bootstrap(
                    into: self.vault)
            } catch let vaultError as BASWorldPriorVault.VaultError {
                throw Self.translate(vaultError)
            } catch {
                throw VaultError.substrateError(
                    reason: "bootstrap-failed:\(error)")
            }
        }
    }

    // MARK: - Registration (Qinao → BAS projection on the hot path)

    /// Register a single horizon. Forwarded atomically to the
    /// substrate vault; if any referenced template / bridge is
    /// duplicate or unknown, the whole registration is rejected
    /// and the vault is left unchanged.
    public func registerHorizon(
        _ horizon: QinaoWorldPriorHorizon
    ) async throws {
        do {
            try await vault.registerHorizon(
                QinaoWorldPriorProjection.toBAS(horizon))
        } catch let vaultError as BASWorldPriorVault.VaultError {
            throw Self.translate(vaultError)
        } catch {
            throw VaultError.substrateError(
                reason: "register-horizon-failed:\(error)")
        }
    }

    /// Register a single loose template. If the template's domain
    /// has no horizon yet, an empty horizon is materialised.
    public func registerTemplate(
        _ template: QinaoWorldPriorCausalTemplate
    ) async throws {
        do {
            try await vault.registerTemplate(
                QinaoWorldPriorProjection.toBAS(template))
        } catch let vaultError as BASWorldPriorVault.VaultError {
            throw Self.translate(vaultError)
        } catch {
            throw VaultError.substrateError(
                reason: "register-template-failed:\(error)")
        }
    }

    /// Register a cross-domain bridge. Both referenced template IDs
    /// must already exist in the vault.
    public func registerBridge(
        _ bridge: QinaoWorldPriorDomainBridge
    ) async throws {
        do {
            try await vault.registerBridge(
                QinaoWorldPriorProjection.toBAS(bridge))
        } catch let vaultError as BASWorldPriorVault.VaultError {
            throw Self.translate(vaultError)
        } catch {
            throw VaultError.substrateError(
                reason: "register-bridge-failed:\(error)")
        }
    }

    // MARK: - Queries

    /// All domains with at least one registered horizon, sorted
    /// lexicographically on `rawValue` for reproducibility.
    public func domains() async -> [QinaoWorldPriorDomain] {
        let bas = await vault.allDomains()
        return bas.map(QinaoWorldPriorProjection.fromBAS(_:))
    }

    /// Horizon for a domain. `nil` if the domain has never been
    /// registered.
    public func horizon(
        for domain: QinaoWorldPriorDomain
    ) async -> QinaoWorldPriorHorizon? {
        let basDomain = QinaoWorldPriorProjection.toBAS(domain)
        guard let basHorizon = await vault.horizon(for: basDomain)
        else { return nil }
        return QinaoWorldPriorProjection.fromBAS(basHorizon)
    }

    /// All templates in a domain, in registration order. Empty
    /// array if the domain has never been registered.
    public func templates(
        in domain: QinaoWorldPriorDomain
    ) async -> [QinaoWorldPriorCausalTemplate] {
        let basDomain = QinaoWorldPriorProjection.toBAS(domain)
        let bas = await vault.templates(in: basDomain)
        return bas.map(QinaoWorldPriorProjection.fromBAS(_:))
    }

    /// Template lookup by ID. `nil` if the ID is unknown.
    public func template(
        id: String
    ) async -> QinaoWorldPriorCausalTemplate? {
        guard let bas = await vault.template(id: id) else {
            return nil
        }
        return QinaoWorldPriorProjection.fromBAS(bas)
    }

    /// All axioms in a domain, in registration order. Empty array
    /// if the domain has never been registered.
    public func axioms(
        in domain: QinaoWorldPriorDomain
    ) async -> [QinaoWorldPriorAxiom] {
        let basDomain = QinaoWorldPriorProjection.toBAS(domain)
        let bas = await vault.axioms(in: basDomain)
        return bas.map(QinaoWorldPriorProjection.fromBAS(_:))
    }

    /// Axiom lookup by ID. `nil` if the ID is unknown.
    public func axiom(
        id: String
    ) async -> QinaoWorldPriorAxiom? {
        guard let bas = await vault.axiom(id: id) else {
            return nil
        }
        return QinaoWorldPriorProjection.fromBAS(bas)
    }

    /// Bridge lookup by ID. `nil` if the ID is unknown.
    public func bridge(
        id: String
    ) async -> QinaoWorldPriorDomainBridge? {
        guard let bas = await vault.bridge(id: id) else {
            return nil
        }
        return QinaoWorldPriorProjection.fromBAS(bas)
    }

    /// Outbound bridges from a domain. Empty array if the domain
    /// has never been registered or has no outbound bridges.
    public func bridgesOutbound(
        from domain: QinaoWorldPriorDomain
    ) async -> [QinaoWorldPriorDomainBridge] {
        let basDomain = QinaoWorldPriorProjection.toBAS(domain)
        let bas = await vault.outboundBridges(from: basDomain)
        return bas.map(QinaoWorldPriorProjection.fromBAS(_:))
    }

    /// Inbound bridges to a domain. Walks the registry; empty
    /// array if no bridge targets the domain.
    public func bridgesInbound(
        to domain: QinaoWorldPriorDomain
    ) async -> [QinaoWorldPriorDomainBridge] {
        let basDomain = QinaoWorldPriorProjection.toBAS(domain)
        let bas = await vault.inboundBridges(to: basDomain)
        return bas
            .map(QinaoWorldPriorProjection.fromBAS(_:))
            .sorted { $0.id < $1.id }
    }

    // MARK: - Counterfactual seeder

    /// Generate counterfactual branches for a template. Guarantees
    /// `count >= 3` per the substrate spec — see
    /// `BASWorldPriorCounterfactualSeeder.minBranches`.
    ///
    /// Throws `.unknownTemplate(id)` if the template ID is not
    /// registered in the vault.
    public func counterfactualBranches(
        for templateID: String,
        description: String = ""
    ) async throws -> [QinaoWorldPriorCounterfactualBranch] {
        do {
            let bas = try await seeder.generate(
                templateID: templateID,
                description: description)
            return bas.map(QinaoWorldPriorProjection.fromBAS(_:))
        } catch BASWorldPriorCounterfactualSeeder.SeederError
            .unknownTemplate(let id) {
            throw VaultError.unknownTemplate(id)
        } catch {
            throw VaultError.substrateError(
                reason: "seeder-failed:\(error)")
        }
    }

    // MARK: - Host override guard (BoundaryBedrock)

    /// Ask the vault whether the host is allowed to override a
    /// claim. See `QinaoWorldPriorOverrideOutcome` for the three
    /// possible results. Side-effect free.
    public func evaluateHostOverride(
        claimID: String,
        declaredEvidence: QinaoWorldPriorEvidenceLevel,
        statement: String
    ) async -> QinaoWorldPriorOverrideOutcome {
        let basOutcome = await vault.evaluateHostOverride(
            claimID: claimID,
            declaredEvidence: QinaoWorldPriorProjection
                .toBAS(declaredEvidence),
            statement: statement)
        return QinaoWorldPriorProjection.fromBAS(basOutcome)
    }

    // MARK: - Risk assessment (L4 → L11/L14 shared contract)

    /// Produce a structured world-prior risk assessment for the given
    /// template ID. Returns `nil` if the template is unknown.
    ///
    /// This is the method that lets one `QinaoWorldPriorVault`
    /// instance serve both the L9 loop (which reads `axioms` +
    /// `evaluateHostOverride` off the same vault) and the L11 risk
    /// gate (which needs `irreversibleHarmScore` / `requiresConsent`
    /// / `evidenceSufficient` to populate `SoftSignals` and the
    /// verdict-engine floor). Before M79 the gate could only reach
    /// the substrate vault via an internal adapter, so hosts had to
    /// either accept a hidden second vault or lose access to the
    /// Qinao-public vault's grow-path API.
    ///
    /// Score derivation is identical to the substrate's
    /// `BASWorldPriorVault.assessRisk(templateID:)` — see that
    /// method's doc-comment for the weight tables. The projection
    /// here is a pure field-by-field mirror translated through
    /// `QinaoWorldPriorProjection`.
    public func assessRisk(
        templateID: String
    ) async -> QinaoWorldPriorRiskAssessment? {
        guard let bas = await vault.assessRisk(templateID: templateID)
        else { return nil }
        return QinaoWorldPriorProjection.fromBAS(bas)
    }

    // MARK: - Diagnostics

    public func templateCount() async -> Int {
        await vault.registeredTemplateCount()
    }

    public func bridgeCount() async -> Int {
        await vault.registeredBridgeCount()
    }

    public func axiomCount() async -> Int {
        await vault.registeredAxiomCount()
    }

    public func horizonCount() async -> Int {
        await vault.registeredHorizonCount()
    }

    // MARK: - Error translation (internal)

    private static func translate(
        _ vaultError: BASWorldPriorVault.VaultError
    ) -> VaultError {
        switch vaultError {
        case .duplicateTemplateID(let id):
            return .duplicateTemplateID(id)
        case .duplicateBridgeID(let id):
            return .duplicateBridgeID(id)
        case .duplicateAxiomID(let id):
            return .duplicateAxiomID(id)
        case .duplicateHorizonDomain(let id):
            return .duplicateHorizonDomain(id)
        case .unknownTemplate(let id):
            return .unknownTemplate(id)
        case .unknownBridge(let id):
            return .unknownBridge(id)
        case .axiomCollision(let id, let incoming, let resident):
            return .axiomCollision(
                id: id,
                incoming: incoming,
                resident: resident)
        case .bridgeReferencesUnknownTemplate(
            let bridgeID, let templateID):
            return .bridgeReferencesUnknownTemplate(
                bridgeID: bridgeID,
                templateID: templateID)
        }
    }
}

// MARK: - Internal projection helpers

/// Pure conversion between Qinao-native mirror types and the
/// substrate's `BASWorldPrior*` schemas. Isolated in its own
/// namespace so the public actor stays readable and every
/// translation site is grep-able.
///
/// Internal — never exposed through the public API.
enum QinaoWorldPriorProjection {

    // MARK: - Evidence level

    static func toBAS(
        _ level: QinaoWorldPriorEvidenceLevel
    ) -> BASWorldPriorEvidenceLevel {
        switch level {
        case .axiomatic:     return .axiomatic
        case .wellSupported: return .wellSupported
        case .plausible:     return .plausible
        case .speculative:   return .speculative
        case .contested:     return .contested
        }
    }

    static func fromBAS(
        _ level: BASWorldPriorEvidenceLevel
    ) -> QinaoWorldPriorEvidenceLevel {
        switch level {
        case .axiomatic:     return .axiomatic
        case .wellSupported: return .wellSupported
        case .plausible:     return .plausible
        case .speculative:   return .speculative
        case .contested:     return .contested
        }
    }

    // MARK: - Domain

    static func toBAS(
        _ domain: QinaoWorldPriorDomain
    ) -> BASWorldPriorDomain {
        BASWorldPriorDomain(rawValue: domain.rawValue)
    }

    static func fromBAS(
        _ domain: BASWorldPriorDomain
    ) -> QinaoWorldPriorDomain {
        QinaoWorldPriorDomain(rawValue: domain.rawValue)
    }

    // MARK: - Axiom

    static func toBAS(
        _ axiom: QinaoWorldPriorAxiom
    ) -> BASWorldPriorAxiom {
        BASWorldPriorAxiom(
            id: axiom.id,
            domain: toBAS(axiom.domain),
            statement: axiom.statement,
            evidence: toBAS(axiom.evidence))
    }

    static func fromBAS(
        _ axiom: BASWorldPriorAxiom
    ) -> QinaoWorldPriorAxiom {
        QinaoWorldPriorAxiom(
            id: axiom.id,
            domain: fromBAS(axiom.domain),
            statement: axiom.statement,
            evidence: fromBAS(axiom.evidence))
    }

    // MARK: - Causal template

    static func toBAS(
        _ tmpl: QinaoWorldPriorCausalTemplate
    ) -> BASWorldPriorCausalTemplate {
        BASWorldPriorCausalTemplate(
            id: tmpl.id,
            domain: toBAS(tmpl.domain),
            preconditions: tmpl.preconditions,
            effect: tmpl.effect,
            effectKind: toBAS(tmpl.effectKind),
            blockers: tmpl.blockers,
            reversibility: toBAS(tmpl.reversibility),
            latency: toBAS(tmpl.latency),
            evidence: toBAS(tmpl.evidence))
    }

    static func fromBAS(
        _ tmpl: BASWorldPriorCausalTemplate
    ) -> QinaoWorldPriorCausalTemplate {
        QinaoWorldPriorCausalTemplate(
            id: tmpl.id,
            domain: fromBAS(tmpl.domain),
            preconditions: tmpl.preconditions,
            effect: tmpl.effect,
            effectKind: fromBAS(tmpl.effectKind),
            blockers: tmpl.blockers,
            reversibility: fromBAS(tmpl.reversibility),
            latency: fromBAS(tmpl.latency),
            evidence: fromBAS(tmpl.evidence))
    }

    // MARK: - Effect kind / reversibility / latency

    static func toBAS(
        _ kind: QinaoWorldPriorCausalTemplate.EffectKind
    ) -> BASWorldPriorCausalTemplate.EffectKind {
        switch kind {
        case .physicalChange:     return .physicalChange
        case .stateTransition:    return .stateTransition
        case .valueTransfer:      return .valueTransfer
        case .informationShift:   return .informationShift
        case .relationshipChange: return .relationshipChange
        case .skillGainOrLoss:    return .skillGainOrLoss
        }
    }

    static func fromBAS(
        _ kind: BASWorldPriorCausalTemplate.EffectKind
    ) -> QinaoWorldPriorCausalTemplate.EffectKind {
        switch kind {
        case .physicalChange:     return .physicalChange
        case .stateTransition:    return .stateTransition
        case .valueTransfer:      return .valueTransfer
        case .informationShift:   return .informationShift
        case .relationshipChange: return .relationshipChange
        case .skillGainOrLoss:    return .skillGainOrLoss
        }
    }

    static func toBAS(
        _ r: QinaoWorldPriorCausalTemplate.Reversibility
    ) -> BASWorldPriorCausalTemplate.Reversibility {
        switch r {
        case .trivial:      return .trivial
        case .bounded:      return .bounded
        case .costly:       return .costly
        case .irreversible: return .irreversible
        }
    }

    static func fromBAS(
        _ r: BASWorldPriorCausalTemplate.Reversibility
    ) -> QinaoWorldPriorCausalTemplate.Reversibility {
        switch r {
        case .trivial:      return .trivial
        case .bounded:      return .bounded
        case .costly:       return .costly
        case .irreversible: return .irreversible
        }
    }

    static func toBAS(
        _ l: QinaoWorldPriorCausalTemplate.LatencyCharacter
    ) -> BASWorldPriorCausalTemplate.LatencyCharacter {
        switch l {
        case .immediate:  return .immediate
        case .prompt:     return .prompt
        case .gradual:    return .gradual
        case .cumulative: return .cumulative
        }
    }

    static func fromBAS(
        _ l: BASWorldPriorCausalTemplate.LatencyCharacter
    ) -> QinaoWorldPriorCausalTemplate.LatencyCharacter {
        switch l {
        case .immediate:  return .immediate
        case .prompt:     return .prompt
        case .gradual:    return .gradual
        case .cumulative: return .cumulative
        }
    }

    // MARK: - Domain bridge

    static func toBAS(
        _ pair: QinaoWorldPriorDomainBridge.TemplatePair
    ) -> BASWorldPriorDomainBridge.TemplatePair {
        BASWorldPriorDomainBridge.TemplatePair(
            sourceTemplateID: pair.sourceTemplateID,
            targetTemplateID: pair.targetTemplateID)
    }

    static func fromBAS(
        _ pair: BASWorldPriorDomainBridge.TemplatePair
    ) -> QinaoWorldPriorDomainBridge.TemplatePair {
        QinaoWorldPriorDomainBridge.TemplatePair(
            sourceTemplateID: pair.sourceTemplateID,
            targetTemplateID: pair.targetTemplateID)
    }

    static func toBAS(
        _ bridge: QinaoWorldPriorDomainBridge
    ) -> BASWorldPriorDomainBridge {
        BASWorldPriorDomainBridge(
            id: bridge.id,
            sourceDomain: toBAS(bridge.sourceDomain),
            targetDomain: toBAS(bridge.targetDomain),
            analogy: bridge.analogy,
            templatePairings: bridge.templatePairings.map(toBAS(_:)),
            evidence: toBAS(bridge.evidence))
    }

    static func fromBAS(
        _ bridge: BASWorldPriorDomainBridge
    ) -> QinaoWorldPriorDomainBridge {
        QinaoWorldPriorDomainBridge(
            id: bridge.id,
            sourceDomain: fromBAS(bridge.sourceDomain),
            targetDomain: fromBAS(bridge.targetDomain),
            analogy: bridge.analogy,
            templatePairings: bridge.templatePairings.map(fromBAS(_:)),
            evidence: fromBAS(bridge.evidence))
    }

    // MARK: - Horizon

    static func toBAS(
        _ horizon: QinaoWorldPriorHorizon
    ) -> BASWorldPriorHorizon {
        BASWorldPriorHorizon(
            domain: toBAS(horizon.domain),
            axioms: horizon.axioms.map(toBAS(_:)),
            templates: horizon.templates.map(toBAS(_:)),
            bridgesOutbound: horizon.bridgesOutbound.map(toBAS(_:)))
    }

    static func fromBAS(
        _ horizon: BASWorldPriorHorizon
    ) -> QinaoWorldPriorHorizon {
        QinaoWorldPriorHorizon(
            domain: fromBAS(horizon.domain),
            axioms: horizon.axioms.map(fromBAS(_:)),
            templates: horizon.templates.map(fromBAS(_:)),
            bridgesOutbound: horizon.bridgesOutbound.map(fromBAS(_:)))
    }

    // MARK: - Counterfactual branch

    static func toBAS(
        _ kind: QinaoWorldPriorPerturbKind
    ) -> BASWorldPriorCounterfactualSeed.PerturbKind {
        switch kind {
        case .dropPrecondition: return .dropPrecondition
        case .introduceBlocker: return .introduceBlocker
        case .crossDomain:      return .crossDomain
        }
    }

    static func fromBAS(
        _ kind: BASWorldPriorCounterfactualSeed.PerturbKind
    ) -> QinaoWorldPriorPerturbKind {
        switch kind {
        case .dropPrecondition: return .dropPrecondition
        case .introduceBlocker: return .introduceBlocker
        case .crossDomain:      return .crossDomain
        }
    }

    static func fromBAS(
        _ branch: BASWorldPriorCounterfactualBranch
    ) -> QinaoWorldPriorCounterfactualBranch {
        QinaoWorldPriorCounterfactualBranch(
            seedTemplateID: branch.seedTemplateID,
            perturbKind: fromBAS(branch.perturbKind),
            description: branch.description,
            branchEvidence: fromBAS(branch.branchEvidence),
            bridgeID: branch.bridgeID)
    }

    // MARK: - Override outcome

    static func fromBAS(
        _ outcome: BASWorldPriorVault.OverrideOutcome
    ) -> QinaoWorldPriorOverrideOutcome {
        switch outcome {
        case .clean:
            return .clean
        case .demote(let axiom, let effective):
            return .demote(
                axiom: fromBAS(axiom),
                effective: fromBAS(effective))
        case .reject(let axiom):
            return .reject(axiom: fromBAS(axiom))
        }
    }

    // MARK: - Risk assessment

    /// Project a substrate `BASWorldPriorRiskAssessment` to the
    /// Qinao-owned mirror. All seven fields round-trip losslessly:
    /// numeric `irreversibleHarmScore` is re-clamped by the Qinao
    /// initializer (safe no-op when the substrate already clamped),
    /// and the enum fields walk the pure case-by-case translations
    /// above.
    static func fromBAS(
        _ assessment: BASWorldPriorRiskAssessment
    ) -> QinaoWorldPriorRiskAssessment {
        QinaoWorldPriorRiskAssessment(
            matchedTemplateID: assessment.matchedTemplateID,
            domain: fromBAS(assessment.domain),
            reversibility: fromBAS(assessment.reversibility),
            evidenceLevel: fromBAS(assessment.evidenceLevel),
            requiresConsent: assessment.requiresConsent,
            irreversibleHarmScore: assessment.irreversibleHarmScore,
            evidenceSufficient: assessment.evidenceSufficient)
    }
}
