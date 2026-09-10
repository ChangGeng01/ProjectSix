import Foundation
import BASRuntimeCore

// MARK: - Uncertainty grammar (shared across all world-prior types)

/// Five-step evidence ladder. The spec calls this the "uncertainty
/// grammar": every world-prior claim declares how strong its support
/// is, and downstream reasoning must propagate that strength.
///
/// Ordering is intentional — `.axiomatic > .wellSupported > .plausible
/// > .speculative > .contested`. When two claims collide the higher
/// level wins unless both sides are `.axiomatic` (in which case the
/// collision is a contradiction the brain must surface, not silently
/// resolve).
public enum BASWorldPriorEvidenceLevel: String, Codable, CaseIterable, Sendable, Comparable {
    /// Boundary bedrock / physical invariants. Cannot be overridden
    /// by the host layer. Example: "objects fall under gravity".
    case axiomatic
    /// Strong empirical or consensus support; multiple independent
    /// sources agree. Example: "sleep debt impairs reaction time".
    case wellSupported
    /// Domain-typical pattern with known exceptions. Example:
    /// "exercise elevates mood short-term".
    case plausible
    /// Hypothesis-level. Used for counterfactual seeds and
    /// exploratory bridges. Example: "music preference correlates
    /// with focus style".
    case speculative
    /// Actively contested in the source domain. Example: "cold
    /// exposure longevity effect". Usable but must be flagged in
    /// any output.
    case contested

    /// Numeric rank (higher = stronger). The public API uses
    /// `Comparable`; this is the basis.
    public var rank: Int {
        switch self {
        case .axiomatic:    return 4
        case .wellSupported: return 3
        case .plausible:    return 2
        case .speculative:  return 1
        case .contested:    return 0
        }
    }

    public static func < (lhs: BASWorldPriorEvidenceLevel, rhs: BASWorldPriorEvidenceLevel) -> Bool {
        lhs.rank < rhs.rank
    }
}

// MARK: - Domain identifier

/// Canonical domain tag. Domains are the coarse "which slice of the
/// world are we in" knob used to route priors, bridges and
/// counterfactual seeds. The built-in set reflects §9.3's 8-domain
/// bridge target; callers may also register custom domains at runtime.
public struct BASWorldPriorDomain: RawRepresentable, Hashable, Codable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue.lowercased() }
    public init(_ raw: String) { self.init(rawValue: raw) }

    // The 8 built-in domains required by §9.3. Chosen so a single
    // personal-assistant-class brain can reason across work, health,
    // money, relationships, learning, time, and body.
    public static let physics      = BASWorldPriorDomain("physics")
    public static let body         = BASWorldPriorDomain("body")
    public static let time         = BASWorldPriorDomain("time")
    public static let money        = BASWorldPriorDomain("money")
    public static let social       = BASWorldPriorDomain("social")
    public static let language     = BASWorldPriorDomain("language")
    public static let learning     = BASWorldPriorDomain("learning")
    public static let ethics       = BASWorldPriorDomain("ethics")
}

// MARK: - Boundary axiom

/// An invariant that the L5 Host Constitution is *not* allowed to
/// override. The spec calls this "BoundaryBedrock": the thin layer
/// of claims that sit beneath host preference. If the host tries to
/// override an axiomatic claim the override is silently demoted to
/// `.plausible` — the axiom wins.
public struct BASWorldPriorAxiom: Hashable, Codable, Sendable {
    public let id: String
    public let domain: BASWorldPriorDomain
    public let statement: String
    public let evidence: BASWorldPriorEvidenceLevel

    public init(
        id: String,
        domain: BASWorldPriorDomain,
        statement: String,
        evidence: BASWorldPriorEvidenceLevel = .axiomatic
    ) {
        self.id = id
        self.domain = domain
        self.statement = statement
        self.evidence = evidence
    }
}

// MARK: - Causal template

/// The workhorse of L4. A causal template encodes "if condition X
/// holds, effect Y typically follows, unless blocker Z intervenes",
/// together with metadata that downstream reasoning uses:
///
/// - `preconditions`: a list of structured predicates that must hold
///   for the rule to fire.
/// - `effect`: the consequence, expressed as one of a small grammar
///   of effect kinds.
/// - `blockers`: named conditions that nullify the effect even if
///   preconditions hold.
/// - `reversibility`: whether the effect can be undone. Consumed by
///   L11 risk-gate for GSI computation.
/// - `evidence`: confidence per the five-step ladder.
/// - `latencyCharacter`: rough timescale of the effect.
public struct BASWorldPriorCausalTemplate: Hashable, Codable, Sendable {
    public enum EffectKind: String, Hashable, Codable, Sendable, CaseIterable {
        case physicalChange
        case stateTransition
        case valueTransfer
        case informationShift
        case relationshipChange
        case skillGainOrLoss
    }

    public enum Reversibility: String, Hashable, Codable, Sendable, CaseIterable {
        case trivial        // can be undone within seconds
        case bounded        // undoable with effort / cost
        case costly         // undoable only at significant cost
        case irreversible   // cannot be meaningfully undone
    }

    public enum LatencyCharacter: String, Hashable, Codable, Sendable, CaseIterable {
        case immediate      // milliseconds
        case prompt         // seconds to minutes
        case gradual        // hours to days
        case cumulative     // weeks+
    }

    public let id: String
    public let domain: BASWorldPriorDomain
    public let preconditions: [String]
    public let effect: String
    public let effectKind: EffectKind
    public let blockers: [String]
    public let reversibility: Reversibility
    public let latency: LatencyCharacter
    public let evidence: BASWorldPriorEvidenceLevel

    public init(
        id: String,
        domain: BASWorldPriorDomain,
        preconditions: [String],
        effect: String,
        effectKind: EffectKind,
        blockers: [String] = [],
        reversibility: Reversibility,
        latency: LatencyCharacter,
        evidence: BASWorldPriorEvidenceLevel
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

// MARK: - Domain bridge

/// Named structural isomorphism between two domains. The bridge is
/// the mechanism by which knowledge in one domain becomes usable as
/// heuristic in another — e.g. "a budget behaves like a battery" or
/// "a conversation backlog behaves like a queue".
///
/// Bridges are typed on *template IDs* rather than free text so the
/// vault can enforce that both ends actually exist.
public struct BASWorldPriorDomainBridge: Hashable, Codable, Sendable {
    public let id: String
    public let sourceDomain: BASWorldPriorDomain
    public let targetDomain: BASWorldPriorDomain
    /// Natural-language description of the analogy.
    public let analogy: String
    /// Causal-template ID pairs that are claimed to be isomorphic.
    /// `(sourceID, targetID)`.
    public let templatePairings: [TemplatePair]
    public let evidence: BASWorldPriorEvidenceLevel

    public struct TemplatePair: Hashable, Codable, Sendable {
        public let sourceTemplateID: String
        public let targetTemplateID: String

        public init(sourceTemplateID: String, targetTemplateID: String) {
            self.sourceTemplateID = sourceTemplateID
            self.targetTemplateID = targetTemplateID
        }
    }

    public init(
        id: String,
        sourceDomain: BASWorldPriorDomain,
        targetDomain: BASWorldPriorDomain,
        analogy: String,
        templatePairings: [TemplatePair] = [],
        evidence: BASWorldPriorEvidenceLevel = .plausible
    ) {
        self.id = id
        self.sourceDomain = sourceDomain
        self.targetDomain = targetDomain
        self.analogy = analogy
        self.templatePairings = templatePairings
        self.evidence = evidence
    }
}

// MARK: - HorizonPrior (root container per domain)

/// The top-level per-domain container. A HorizonPrior holds the
/// axioms, causal templates, and bridges-out-of this domain. The
/// vault indexes all HorizonPriors together.
public struct BASWorldPriorHorizon: Hashable, Codable, Sendable {
    public let domain: BASWorldPriorDomain
    public let axioms: [BASWorldPriorAxiom]
    public let templates: [BASWorldPriorCausalTemplate]
    public let bridgesOutbound: [BASWorldPriorDomainBridge]

    public init(
        domain: BASWorldPriorDomain,
        axioms: [BASWorldPriorAxiom] = [],
        templates: [BASWorldPriorCausalTemplate] = [],
        bridgesOutbound: [BASWorldPriorDomainBridge] = []
    ) {
        self.domain = domain
        self.axioms = axioms
        self.templates = templates
        self.bridgesOutbound = bridgesOutbound
    }
}

// MARK: - Counterfactual seed

/// A seed from which the counterfactual engine fans out branches.
/// Each branch represents "what else could happen, given this
/// starting point, if we perturb exactly one factor?"
///
/// The engine returns at least 3 branches per seed (§9.3
/// "给定一个 MemoryAtom，能生成 ≥3 条反事实分支").
public struct BASWorldPriorCounterfactualSeed: Hashable, Codable, Sendable {
    public enum PerturbKind: String, Hashable, Codable, Sendable, CaseIterable {
        /// Remove one precondition and ask what the effect looks like.
        case dropPrecondition
        /// Introduce a blocker and ask what suppresses the effect.
        case introduceBlocker
        /// Swap domain via bridge and ask what the analogue would be.
        case crossDomain
    }

    public let templateID: String
    public let seedDescription: String

    public init(templateID: String, seedDescription: String) {
        self.templateID = templateID
        self.seedDescription = seedDescription
    }
}

public struct BASWorldPriorCounterfactualBranch: Hashable, Codable, Sendable {
    public let seedTemplateID: String
    public let perturbKind: BASWorldPriorCounterfactualSeed.PerturbKind
    public let description: String
    /// Downstream risk / uncertainty for this branch. Composed from
    /// the seed template evidence and an additional speculative
    /// penalty for the perturbation itself.
    public let branchEvidence: BASWorldPriorEvidenceLevel
    /// For `crossDomain` branches, which bridge was used.
    public let bridgeID: String?

    public init(
        seedTemplateID: String,
        perturbKind: BASWorldPriorCounterfactualSeed.PerturbKind,
        description: String,
        branchEvidence: BASWorldPriorEvidenceLevel,
        bridgeID: String? = nil
    ) {
        self.seedTemplateID = seedTemplateID
        self.perturbKind = perturbKind
        self.description = description
        self.branchEvidence = branchEvidence
        self.bridgeID = bridgeID
    }
}
