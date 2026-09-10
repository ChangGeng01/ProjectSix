import Foundation
import BASRuntimeCore

/// `L4` WorldPriorVault — the registry actor for world-knowledge
/// priors (horizons, axioms, causal templates, domain bridges).
///
/// ## Role
///
/// This is the "懂世界" (understands the world) half of Invariant 2's
/// "懂世界也懂宿主" pair. `BASMemory/HostConstitutionCore` already
/// covered "懂宿主" (understands the host) — but until now there was
/// no domain-independent world layer at all, which made the
/// invariant half-truthful. The vault closes that gap by maintaining
/// a typed, queryable library of:
///
/// - per-domain `BASWorldPriorHorizon`s (root)
/// - `BASWorldPriorAxiom`s (boundary bedrock — L5 cannot override)
/// - `BASWorldPriorCausalTemplate`s (if-then with evidence and
///   reversibility)
/// - `BASWorldPriorDomainBridge`s (cross-domain analogies)
///
/// Queries are side-effect free; mutations are append-only (registry
/// does not support "delete this template" in the normal API because
/// a world prior being forgotten mid-session is a category error —
/// use a fresh vault for a clean world).
public actor BASWorldPriorVault {
    public enum VaultError:
        Error, Equatable, Sendable, Codable
    {
        case duplicateTemplateID(String)
        case duplicateBridgeID(String)
        case duplicateAxiomID(String)
        case duplicateHorizonDomain(String)
        case unknownTemplate(String)
        case unknownBridge(String)
        case axiomCollision(id: String, incoming: String, resident: String)
        case bridgeReferencesUnknownTemplate(bridgeID: String, templateID: String)
        /// audit policy-obs-misc LOW-8 — a bridge whose sourceDomain has no registered horizon would
        /// half-register (findable by id, absent from any horizon's bridgesOutbound = unroutable).
        case bridgeReferencesUnknownDomain(bridgeID: String, domain: String)
    }

    // MARK: - State

    private var horizons: [BASWorldPriorDomain: BASWorldPriorHorizon] = [:]
    private var templatesByID: [String: BASWorldPriorCausalTemplate] = [:]
    private var bridgesByID: [String: BASWorldPriorDomainBridge] = [:]
    private var axiomsByID: [String: BASWorldPriorAxiom] = [:]

    public init() {}

    // MARK: - Registration

    /// Register a horizon for a domain. Fails if the domain already
    /// has one — the vault is meant to be a single source of truth
    /// for each domain's axioms and templates.
    public func registerHorizon(_ horizon: BASWorldPriorHorizon) throws {
        if horizons[horizon.domain] != nil {
            throw VaultError.duplicateHorizonDomain(horizon.domain.rawValue)
        }
        // Check template uniqueness before any insertion so we don't
        // leave the vault in a half-applied state.
        for tmpl in horizon.templates where templatesByID[tmpl.id] != nil {
            throw VaultError.duplicateTemplateID(tmpl.id)
        }
        for ax in horizon.axioms {
            if let resident = axiomsByID[ax.id] {
                if resident.statement != ax.statement {
                    throw VaultError.axiomCollision(
                        id: ax.id,
                        incoming: ax.statement,
                        resident: resident.statement
                    )
                } else {
                    throw VaultError.duplicateAxiomID(ax.id)
                }
            }
        }
        for br in horizon.bridgesOutbound where bridgesByID[br.id] != nil {
            throw VaultError.duplicateBridgeID(br.id)
        }
        // Bridges outbound must point to templates we recognise.
        // Templates on *this* horizon count as known too, so validate
        // against the merged set.
        let incomingTemplateIDs = Set(horizon.templates.map(\.id))
        for br in horizon.bridgesOutbound {
            for pair in br.templatePairings {
                let srcKnown = templatesByID[pair.sourceTemplateID] != nil
                    || incomingTemplateIDs.contains(pair.sourceTemplateID)
                let dstKnown = templatesByID[pair.targetTemplateID] != nil
                    || incomingTemplateIDs.contains(pair.targetTemplateID)
                if !srcKnown {
                    throw VaultError.bridgeReferencesUnknownTemplate(
                        bridgeID: br.id,
                        templateID: pair.sourceTemplateID
                    )
                }
                if !dstKnown {
                    throw VaultError.bridgeReferencesUnknownTemplate(
                        bridgeID: br.id,
                        templateID: pair.targetTemplateID
                    )
                }
            }
        }

        // Commit.
        horizons[horizon.domain] = horizon
        for tmpl in horizon.templates {
            templatesByID[tmpl.id] = tmpl
        }
        for ax in horizon.axioms {
            axiomsByID[ax.id] = ax
        }
        for br in horizon.bridgesOutbound {
            bridgesByID[br.id] = br
        }
    }

    /// Register a single loose template into an existing horizon.
    /// Used when a horizon is bootstrapped empty and grown.
    public func registerTemplate(
        _ template: BASWorldPriorCausalTemplate
    ) throws {
        if templatesByID[template.id] != nil {
            throw VaultError.duplicateTemplateID(template.id)
        }
        templatesByID[template.id] = template
        if var horizon = horizons[template.domain] {
            var merged = horizon.templates
            merged.append(template)
            horizon = BASWorldPriorHorizon(
                domain: horizon.domain,
                axioms: horizon.axioms,
                templates: merged,
                bridgesOutbound: horizon.bridgesOutbound
            )
            horizons[template.domain] = horizon
        } else {
            horizons[template.domain] = BASWorldPriorHorizon(
                domain: template.domain,
                templates: [template]
            )
        }
    }

    /// Register a cross-domain bridge after the fact. Both referenced
    /// templates must exist.
    public func registerBridge(
        _ bridge: BASWorldPriorDomainBridge
    ) throws {
        if bridgesByID[bridge.id] != nil {
            throw VaultError.duplicateBridgeID(bridge.id)
        }
        for pair in bridge.templatePairings {
            if templatesByID[pair.sourceTemplateID] == nil {
                throw VaultError.bridgeReferencesUnknownTemplate(
                    bridgeID: bridge.id,
                    templateID: pair.sourceTemplateID
                )
            }
            if templatesByID[pair.targetTemplateID] == nil {
                throw VaultError.bridgeReferencesUnknownTemplate(
                    bridgeID: bridge.id,
                    templateID: pair.targetTemplateID
                )
            }
        }
        // audit policy-obs-misc LOW-8: fail closed when the sourceDomain has no registered horizon —
        // otherwise the bridge lands in bridgesByID but never in any horizon's bridgesOutbound, so it
        // is findable by id yet UNROUTABLE (outboundBridges(from:) returns []). Mirrors the existing
        // bridgeReferencesUnknownTemplate validation above.
        guard var horizon = horizons[bridge.sourceDomain] else {
            throw VaultError.bridgeReferencesUnknownDomain(
                bridgeID: bridge.id, domain: bridge.sourceDomain.rawValue)
        }
        bridgesByID[bridge.id] = bridge
        var merged = horizon.bridgesOutbound
        merged.append(bridge)
        horizon = BASWorldPriorHorizon(
            domain: horizon.domain,
            axioms: horizon.axioms,
            templates: horizon.templates,
            bridgesOutbound: merged
        )
        horizons[bridge.sourceDomain] = horizon
    }

    // MARK: - Queries

    public func horizon(for domain: BASWorldPriorDomain) -> BASWorldPriorHorizon? {
        horizons[domain]
    }

    public func template(id: String) -> BASWorldPriorCausalTemplate? {
        templatesByID[id]
    }

    public func bridge(id: String) -> BASWorldPriorDomainBridge? {
        bridgesByID[id]
    }

    public func axiom(id: String) -> BASWorldPriorAxiom? {
        axiomsByID[id]
    }

    public func templates(in domain: BASWorldPriorDomain) -> [BASWorldPriorCausalTemplate] {
        horizons[domain]?.templates ?? []
    }

    public func axioms(in domain: BASWorldPriorDomain) -> [BASWorldPriorAxiom] {
        horizons[domain]?.axioms ?? []
    }

    /// Bridges that lead out of `domain`.
    public func outboundBridges(from domain: BASWorldPriorDomain) -> [BASWorldPriorDomainBridge] {
        horizons[domain]?.bridgesOutbound ?? []
    }

    /// Bridges that land in `domain` (walking the registry).
    public func inboundBridges(to domain: BASWorldPriorDomain) -> [BASWorldPriorDomainBridge] {
        bridgesByID.values.filter { $0.targetDomain == domain }
    }

    // MARK: - L5 override guard (BoundaryBedrock)

    /// Evaluate an incoming host-layer override against the vault's
    /// axioms. The spec requires that L5 cannot override L4 axioms:
    /// if the host declares a conflict with an `.axiomatic` claim,
    /// the override is demoted to `.plausible` *from the caller's
    /// perspective* — i.e. the host still gets to record its
    /// preference, but the vault reports back that the axiom wins.
    ///
    /// - Returns: `.clean` if no conflict, `.demote(...)` if the
    ///   override survives but at reduced evidence, `.reject(...)`
    ///   if the axiom strictly wins.
    public func evaluateHostOverride(
        claimID: String,
        declaredEvidence: BASWorldPriorEvidenceLevel,
        statement: String
    ) -> OverrideOutcome {
        guard let ax = axiomsByID[claimID] else {
            return .clean
        }
        if ax.statement == statement {
            return .clean
        }
        // Collision. Axiom wins iff evidence strictly greater;
        // otherwise demoted coexistence.
        if ax.evidence > declaredEvidence {
            return .reject(axiom: ax)
        } else {
            return .demote(axiom: ax, effective: .plausible)
        }
    }

    public enum OverrideOutcome: Equatable, Sendable {
        case clean
        case demote(axiom: BASWorldPriorAxiom, effective: BASWorldPriorEvidenceLevel)
        case reject(axiom: BASWorldPriorAxiom)
    }

    // MARK: - Diagnostics

    public func registeredTemplateCount() -> Int { templatesByID.count }
    public func registeredBridgeCount() -> Int { bridgesByID.count }
    public func registeredAxiomCount() -> Int { axiomsByID.count }
    public func registeredHorizonCount() -> Int { horizons.count }

    public func allDomains() -> [BASWorldPriorDomain] {
        Array(horizons.keys).sorted { $0.rawValue < $1.rawValue }
    }
}
