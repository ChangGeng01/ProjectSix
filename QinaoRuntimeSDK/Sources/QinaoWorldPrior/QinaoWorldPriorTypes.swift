import Foundation

/// Qinao-native mirror of `BASWorldPriorEvidenceLevel`. Mirrors the
/// substrate's five-step evidence ladder exactly (axiomatic >
/// wellSupported > plausible > speculative > contested) so that
/// downstream reasoning can propagate strength without importing any
/// `BAS*` symbol. The ordering is intentional — higher rank means
/// stronger support.
///
/// Use `rank` when you need a numeric sort key; use the `Comparable`
/// conformance when you want idiomatic Swift comparison (`<`, `<=`,
/// etc.). Two `.axiomatic` claims with conflicting statements are a
/// category error that the vault surfaces rather than silently
/// resolves — see `QinaoWorldPriorVault.evaluateHostOverride`.
public enum QinaoWorldPriorEvidenceLevel:
    String, Codable, CaseIterable, Sendable, Comparable {
    case axiomatic
    case wellSupported
    case plausible
    case speculative
    case contested

    public var rank: Int {
        switch self {
        case .axiomatic:     return 4
        case .wellSupported: return 3
        case .plausible:     return 2
        case .speculative:   return 1
        case .contested:     return 0
        }
    }

    public static func < (
        lhs: QinaoWorldPriorEvidenceLevel,
        rhs: QinaoWorldPriorEvidenceLevel
    ) -> Bool {
        lhs.rank < rhs.rank
    }
}

/// Qinao-native mirror of `BASWorldPriorDomain`. The eight canonical
/// built-in domains cover the slice of reality a single personal-
/// assistant-class brain is expected to reason across (physics /
/// body / time / money / social / language / learning / ethics).
/// Custom domains are created through `init(_ raw: String)`; the
/// raw value is lowercased on construction for canonical equality.
public struct QinaoWorldPriorDomain:
    RawRepresentable, Hashable, Codable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue.lowercased()
    }

    public init(_ raw: String) {
        self.init(rawValue: raw)
    }

    public static let physics  = QinaoWorldPriorDomain("physics")
    public static let body     = QinaoWorldPriorDomain("body")
    public static let time     = QinaoWorldPriorDomain("time")
    public static let money    = QinaoWorldPriorDomain("money")
    public static let social   = QinaoWorldPriorDomain("social")
    public static let language = QinaoWorldPriorDomain("language")
    public static let learning = QinaoWorldPriorDomain("learning")
    public static let ethics   = QinaoWorldPriorDomain("ethics")
}

/// Qinao-native mirror of `BASWorldPriorAxiom`. An axiom is a claim
/// the L5 Host Constitution is NOT allowed to override; the vault
/// treats any host override of an `.axiomatic` statement as either
/// a demotion or an outright rejection (see
/// `QinaoWorldPriorVault.evaluateHostOverride`).
public struct QinaoWorldPriorAxiom: Hashable, Codable, Sendable {
    public let id: String
    public let domain: QinaoWorldPriorDomain
    public let statement: String
    public let evidence: QinaoWorldPriorEvidenceLevel

    public init(
        id: String,
        domain: QinaoWorldPriorDomain,
        statement: String,
        evidence: QinaoWorldPriorEvidenceLevel = .axiomatic
    ) {
        self.id = id
        self.domain = domain
        self.statement = statement
        self.evidence = evidence
    }
}

/// Qinao-native mirror of `BASWorldPriorCausalTemplate`. A causal
/// template encodes "if `preconditions` hold, `effect` follows unless
/// `blockers` intervene", plus the reversibility, latency, and
/// evidence metadata downstream reasoning (L9 dream-loop, L11 risk
/// gate, L14 sovereign verdict) consumes.
public struct QinaoWorldPriorCausalTemplate:
    Hashable, Codable, Sendable {

    /// What flavour of change the effect represents. Mirrors the
    /// substrate's small grammar.
    public enum EffectKind:
        String, Hashable, Codable, Sendable, CaseIterable {
        case physicalChange
        case stateTransition
        case valueTransfer
        case informationShift
        case relationshipChange
        case skillGainOrLoss
    }

    /// How hard it is to put the effect back once it has fired.
    /// `.irreversible` is the marker L11 uses to force informed
    /// consent on ethics-domain templates.
    public enum Reversibility:
        String, Hashable, Codable, Sendable, CaseIterable {
        case trivial
        case bounded
        case costly
        case irreversible
    }

    /// How quickly the effect manifests after the preconditions
    /// fire. Used by L1 breath-scheduler and L11 delay-mode to
    /// reason about whether the action can be postponed safely.
    public enum LatencyCharacter:
        String, Hashable, Codable, Sendable, CaseIterable {
        case immediate
        case prompt
        case gradual
        case cumulative
    }

    public let id: String
    public let domain: QinaoWorldPriorDomain
    public let preconditions: [String]
    public let effect: String
    public let effectKind: EffectKind
    public let blockers: [String]
    public let reversibility: Reversibility
    public let latency: LatencyCharacter
    public let evidence: QinaoWorldPriorEvidenceLevel

    public init(
        id: String,
        domain: QinaoWorldPriorDomain,
        preconditions: [String],
        effect: String,
        effectKind: EffectKind,
        blockers: [String] = [],
        reversibility: Reversibility,
        latency: LatencyCharacter,
        evidence: QinaoWorldPriorEvidenceLevel
    ) {
        self.id = id
        self.domain = domain
        self.preconditions = preconditions
        self.effect = effect
        self.effectKind = effectKind
        self.blockers = blockers
        self.reversibility = reversibility
        self.latency = latency
        self.evidence = evidence
    }
}

/// Qinao-native mirror of `BASWorldPriorDomainBridge`. A bridge is a
/// named structural isomorphism between two domains. Bridges let the
/// dream-loop reason across slices of reality by analogy — "a budget
/// behaves like a battery", "a conversation backlog behaves like a
/// queue". Bridges are typed on *template IDs* rather than free text
/// so the vault can enforce referential integrity at registration.
public struct QinaoWorldPriorDomainBridge:
    Hashable, Codable, Sendable {

    public struct TemplatePair: Hashable, Codable, Sendable {
        public let sourceTemplateID: String
        public let targetTemplateID: String
        public init(
            sourceTemplateID: String,
            targetTemplateID: String
        ) {
            self.sourceTemplateID = sourceTemplateID
            self.targetTemplateID = targetTemplateID
        }
    }

    public let id: String
    public let sourceDomain: QinaoWorldPriorDomain
    public let targetDomain: QinaoWorldPriorDomain
    public let analogy: String
    public let templatePairings: [TemplatePair]
    public let evidence: QinaoWorldPriorEvidenceLevel

    public init(
        id: String,
        sourceDomain: QinaoWorldPriorDomain,
        targetDomain: QinaoWorldPriorDomain,
        analogy: String,
        templatePairings: [TemplatePair] = [],
        evidence: QinaoWorldPriorEvidenceLevel = .plausible
    ) {
        self.id = id
        self.sourceDomain = sourceDomain
        self.targetDomain = targetDomain
        self.analogy = analogy
        self.templatePairings = templatePairings
        self.evidence = evidence
    }
}

/// Qinao-native mirror of `BASWorldPriorHorizon`. A horizon is the
/// top-level per-domain container — axioms, templates, and bridges
/// outbound from a domain. Registering a horizon is the bulk-write
/// path; registering a template or bridge one at a time is the grow
/// path.
public struct QinaoWorldPriorHorizon: Hashable, Codable, Sendable {
    public let domain: QinaoWorldPriorDomain
    public let axioms: [QinaoWorldPriorAxiom]
    public let templates: [QinaoWorldPriorCausalTemplate]
    public let bridgesOutbound: [QinaoWorldPriorDomainBridge]

    public init(
        domain: QinaoWorldPriorDomain,
        axioms: [QinaoWorldPriorAxiom] = [],
        templates: [QinaoWorldPriorCausalTemplate] = [],
        bridgesOutbound: [QinaoWorldPriorDomainBridge] = []
    ) {
        self.domain = domain
        self.axioms = axioms
        self.templates = templates
        self.bridgesOutbound = bridgesOutbound
    }
}

/// Qinao-native mirror of `BASWorldPriorCounterfactualSeed.PerturbKind`.
/// Names one of three mechanical perturbations the counterfactual
/// seeder applies to a template to generate a branch.
public enum QinaoWorldPriorPerturbKind:
    String, Hashable, Codable, Sendable, CaseIterable {
    /// Remove one precondition and ask what the effect looks like.
    case dropPrecondition
    /// Introduce a known blocker and ask what suppresses the effect.
    case introduceBlocker
    /// Swap domain via a bridge and ask what the analogue would be.
    case crossDomain
}

/// Qinao-native mirror of `BASWorldPriorCounterfactualBranch`. Each
/// branch carries the perturbation kind, a natural-language
/// description, the evidence rung (demoted from the seed template
/// by the perturbation), and — for `.crossDomain` perturbations —
/// the bridge ID that was used.
public struct QinaoWorldPriorCounterfactualBranch:
    Hashable, Codable, Sendable {
    public let seedTemplateID: String
    public let perturbKind: QinaoWorldPriorPerturbKind
    public let description: String
    public let branchEvidence: QinaoWorldPriorEvidenceLevel
    public let bridgeID: String?

    public init(
        seedTemplateID: String,
        perturbKind: QinaoWorldPriorPerturbKind,
        description: String,
        branchEvidence: QinaoWorldPriorEvidenceLevel,
        bridgeID: String? = nil
    ) {
        self.seedTemplateID = seedTemplateID
        self.perturbKind = perturbKind
        self.description = description
        self.branchEvidence = branchEvidence
        self.bridgeID = bridgeID
    }
}

/// Qinao-native mirror of `BASWorldPriorVault.OverrideOutcome`. The
/// vault returns one of three outcomes when the host attempts to
/// override a claim that is (or may be) backed by an L4 axiom:
///
/// - `.clean` — no axiom matches the claim ID, or the host's
///   statement is byte-identical to the axiom's.
/// - `.demote(axiom:effective:)` — the host's declared evidence is
///   equal to or higher than the axiom's; the override survives at
///   reduced evidence (`.plausible`).
/// - `.reject(axiom:)` — the axiom strictly outranks the host's
///   declared evidence; the axiom wins outright.
///
/// Callers should read the outcome before committing the override
/// to their L5 host-constitution writeback path.
public enum QinaoWorldPriorOverrideOutcome: Equatable, Sendable {
    case clean
    case demote(
        axiom: QinaoWorldPriorAxiom,
        effective: QinaoWorldPriorEvidenceLevel)
    case reject(axiom: QinaoWorldPriorAxiom)
}

/// Qinao-native mirror of `BASWorldPriorRiskAssessment`.
///
/// The vault derives this from a matched causal template via the
/// canonical L4 score: `reversibility × effectKind × domain-weight`,
/// clamped to `[0.0, 1.0]`. The assessment is the shared contract by
/// which L4 world knowledge reaches upstream consumers (L11 risk
/// gate, L14 verdict engine, L9 dream loop) without any of them
/// having to re-derive "what does reversibility mean for money vs.
/// ethics vs. body". Two of its fields (`requiresConsent`,
/// `evidenceSufficient`) are load-bearing:
///
/// - `requiresConsent == true` iff the matched template is in the
///   `ethics` domain AND its `reversibility == .irreversible` — this
///   is the L4 invariant that makes "no irreversible harm without
///   informed consent" enforceable at the gate without re-encoding
///   the ethics rules at each call-site.
/// - `evidenceSufficient == false` iff the matched template is
///   irreversible but its evidence level is weaker than
///   `.wellSupported` — the gate / verdict engine reads this to
///   escalate the decision floor.
///
/// This type exists so a host can observe L4's risk view of a
/// template without importing `BASWorldPrior` or `QinaoRisk`. The
/// same 4 out of 7 fields (`irreversibleHarmScore`, `requiresConsent`,
/// `evidenceSufficient`, `matchedTemplateID`) are what the existing
/// `QinaoRiskGate.WorldRiskAssessment` surface exposes to the L11
/// gate — the runtime's internal bridge translates between the two
/// so that one `QinaoWorldPriorVault` instance can feed both the L9
/// loop (via `QinaoLoop(worldPrior:)`) and the L11 risk surface
/// (via an endpoint built from the vault).
public struct QinaoWorldPriorRiskAssessment:
    Hashable, Codable, Sendable {
    /// Template that matched the proposed intent.
    public let matchedTemplateID: String
    /// Domain of the matched template.
    public let domain: QinaoWorldPriorDomain
    /// Reversibility category copied from the template.
    public let reversibility: QinaoWorldPriorCausalTemplate.Reversibility
    /// Evidence level copied from the template.
    public let evidenceLevel: QinaoWorldPriorEvidenceLevel
    /// Whether the matched template requires informed consent from
    /// another party (ethics-domain irreversible templates).
    public let requiresConsent: Bool
    /// Normalized `[0.0, 1.0]` score feeding upstream risk signals.
    /// Clamped at construction; any value outside the unit interval
    /// collapses to the nearest bound.
    public let irreversibleHarmScore: Double
    /// Whether the template's evidence level is strong enough to
    /// support an irreversible operation without additional
    /// corroboration.
    public let evidenceSufficient: Bool

    public init(
        matchedTemplateID: String,
        domain: QinaoWorldPriorDomain,
        reversibility: QinaoWorldPriorCausalTemplate.Reversibility,
        evidenceLevel: QinaoWorldPriorEvidenceLevel,
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
