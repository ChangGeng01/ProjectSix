import Foundation
import BASRuntimeCore

// MARK: - M109 L4 地平线层 whitepaper §5 key-object closure
//
// L4 whitepaper §5 ("关键对象族") lists 10 core objects. Pre-M109
// the BASWorldPrior module had 4 that semantically matched:
//   - BASWorldPriorCausalTemplate → §5.3 CausalTemplate
//   - BASWorldPriorCounterfactualSeed → §5.4 CounterfactualSeed
//   - BASWorldPriorDomainBridge → §5.8 DomainBridge
//   - BASWorldPriorHorizon (aggregator per-domain; NOT the whitepaper
//     §5.1 HorizonPrior which is a per-prior record; see below)
//
// M109 lands the remaining 7 whitepaper-named types as pure-value
// schemas. The naming convention uses the whitepaper-literal names
// (`BASHorizonPrior`, `BASWorldFrame`, …) rather than the
// `BASWorldPrior*` prefix because these are the exact concept names
// the whitepaper uses and cross-layer consumers (L1 / L2 / L11 /
// L14) will reference them by that name. Co-existence with the
// existing `BASWorldPrior*` types is intentional — they are
// distinct containers:
//
//   BASHorizonPrior (§5.1) = per-prior record
//   BASWorldPriorHorizon   = per-domain aggregator
//
// Both ship. No rename. No removal. The whitepaper-literal types
// are pure-value, Codable, Hashable, Sendable, and conform to
// BASSchemaVersioned so the registry can audit them alongside
// the other governed schemas.

// MARK: - 5.1 HorizonPrior

/// The kind of prior this `HorizonPrior` instance carries — one of
/// six whitepaper-specified classes. Stable raw values for
/// cross-layer consumers.
public enum BASHorizonPriorType:
    String, Codable, Sendable, Equatable, Hashable, CaseIterable
{
    /// Semantic ocean prior — vocabulary, word-sense, relation
    /// mapping (§4.1).
    case semantic
    /// Causal loom prior — preconditions, effects, blockers
    /// (§4.3).
    case causal
    /// Boundary bedrock prior — hard stops, red lines (§4.7).
    case boundary
    /// Uncertainty mist prior — evidence gradient metadata
    /// (§4.6).
    case uncertainty
    /// Ontology atlas prior — entity/relation taxonomy (§4.2).
    case ontology
    /// Domain bridge prior — cross-domain transfer structure
    /// (§4.8).
    case domainBridge
}

/// Three-tier time-stability classification for priors — invariant
/// / semi-stable / volatile. The temporal stratifier (§4.9) keys
/// on this to decide when a prior must refresh.
public enum BASHorizonStabilityTier:
    String, Codable, Sendable, Equatable, Hashable, CaseIterable
{
    /// Near-immutable knowledge (laws of physics, basic arithmetic,
    /// common-sense ontology).
    case invariant
    /// Slowly-evolving (profession norms, geopolitical maps,
    /// scientific consensus on non-frontier topics).
    case semiStable
    /// High-time-variance (news, markets, personal schedule, weather).
    case volatile
}

/// Per-prior record matching L4 whitepaper §5.1 `HorizonPrior`.
/// Six whitepaper fields plus `schemaVersion`.
public struct BASHorizonPrior:
    BASSchemaVersioned, Hashable, Sendable
{
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var priorID: String
    public var priorType: BASHorizonPriorType
    public var stabilityTier: BASHorizonStabilityTier
    public var scope: String
    public var confidence: Double
    public var sourceClass: String

    public init(
        schemaVersion: String = BASHorizonPrior.currentSchemaVersion,
        priorID: String,
        priorType: BASHorizonPriorType,
        stabilityTier: BASHorizonStabilityTier,
        scope: String,
        confidence: Double,
        sourceClass: String
    ) {
        self.schemaVersion = schemaVersion
        self.priorID = priorID
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.priorType = priorType
        self.stabilityTier = stabilityTier
        self.scope = scope
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.confidence = min(1, max(0, confidence))
        self.sourceClass = sourceClass
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - 5.2 WorldFrame

/// Per-turn world-frame snapshot matching L4 whitepaper §5.2.
/// Captures the entities / relations / events / roles / constraints
/// and temporal ordering of a world slice the turn is operating on.
public struct BASWorldFrame:
    BASSchemaVersioned, Hashable, Sendable
{
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var entities: [String]
    public var relations: [String]
    public var events: [String]
    public var roles: [String]
    public var constraints: [String]
    public var temporalOrder: String

    public init(
        schemaVersion: String = BASWorldFrame.currentSchemaVersion,
        entities: [String] = [],
        relations: [String] = [],
        events: [String] = [],
        roles: [String] = [],
        constraints: [String] = [],
        temporalOrder: String = ""
    ) {
        self.schemaVersion = schemaVersion
        self.entities = entities
        self.relations = relations
        self.events = events
        self.roles = roles
        self.constraints = constraints
        self.temporalOrder = temporalOrder
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Empty baseline — no entities / no relations / no events.
    /// Useful for turns that have not yet instantiated a world
    /// frame.
    public static let empty = BASWorldFrame()
}

// MARK: - 5.5 AbstractionMap

/// Four-level abstraction ladder mapping for one concept, matching
/// L4 whitepaper §5.5. The levels are not hierarchical reductions
/// — they are co-existing views the caller can pick based on the
/// turn's abstraction need (rapid pattern match vs principle
/// derivation vs executable plan).
public struct BASAbstractionMap:
    BASSchemaVersioned, Hashable, Sendable
{
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    /// Concrete view — specific named instance ("this specific
    /// email from Alice").
    public var concreteView: String
    /// Pattern view — the class of instances ("emails that request
    /// an urgent reply").
    public var patternView: String
    /// Principle view — the underlying rule ("urgency claims
    /// without deadlines are frequent manipulation markers").
    public var principleView: String
    /// Executable view — the action template derived from the
    /// principle ("if urgency + no deadline, defer + ask for
    /// deadline").
    public var executableView: String

    public init(
        schemaVersion: String = BASAbstractionMap.currentSchemaVersion,
        concreteView: String = "",
        patternView: String = "",
        principleView: String = "",
        executableView: String = ""
    ) {
        self.schemaVersion = schemaVersion
        self.concreteView = concreteView
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.patternView = patternView
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.principleView = principleView
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.executableView = executableView
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static let empty = BASAbstractionMap()
}

// MARK: - 5.6 UncertaintyMap

/// Caution mode enum for `UncertaintyMap.caution_mode`. Not
/// whitepaper-named explicitly but the spec refers to "谨慎模式"
/// as a categorical slot.
public enum BASUncertaintyCautionMode:
    String, Codable, Sendable, Equatable, Hashable, CaseIterable
{
    /// Normal confidence — no extra caveats.
    case nominal
    /// Suggest hedging language ("probably", "in most cases").
    case hedging
    /// Require explicit uncertainty disclosure.
    case disclosureRequired
    /// Refuse without additional evidence.
    case refuseWithoutEvidence
}

/// Per-claim uncertainty portrait matching L4 whitepaper §5.6.
/// Captures the evidence strength + temporal sensitivity +
/// inference distance + confidence band + caution mode the L11
/// risk gate / L12 soft-hand / L10 tri-self use to decide how to
/// phrase a response.
public struct BASUncertaintyMap:
    BASSchemaVersioned, Hashable, Sendable
{
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    /// Evidence strength [0, 1]: 0 = no evidence, 1 = strong
    /// independent corroboration.
    public var evidenceStrength: Double
    /// Temporal sensitivity [0, 1]: 0 = claim is time-invariant,
    /// 1 = claim is only valid in a short window.
    public var temporalSensitivity: Double
    /// Inference span [0, 1]: 0 = direct retrieval, 1 = many
    /// inferential hops from source data.
    public var inferenceSpan: Double
    /// Confidence band width [0, 1]: 0 = point estimate, 1 =
    /// wide interval.
    public var confidenceBand: Double
    public var cautionMode: BASUncertaintyCautionMode

    public init(
        schemaVersion: String = BASUncertaintyMap.currentSchemaVersion,
        evidenceStrength: Double,
        temporalSensitivity: Double,
        inferenceSpan: Double,
        confidenceBand: Double,
        cautionMode: BASUncertaintyCautionMode
    ) {
        self.schemaVersion = schemaVersion
        self.evidenceStrength = min(1, max(0, evidenceStrength))
        self.temporalSensitivity = min(1, max(0, temporalSensitivity))
        self.inferenceSpan = min(1, max(0, inferenceSpan))
        self.confidenceBand = min(1, max(0, confidenceBand))
        self.cautionMode = cautionMode
    }
}

// MARK: - 5.7 BoundaryPrior

/// Severity tier for a boundary prior — hard-coded three levels
/// (advisory / strict / absolute) to avoid proliferation of
/// free-text severity codes.
public enum BASBoundaryPriorSeverity:
    String, Codable, Sendable, Equatable, Hashable, CaseIterable
{
    /// Soft boundary — advisory only (nudge, not block).
    case advisory
    /// Firm boundary — blocks without escalation capability.
    case strict
    /// Absolute boundary — cannot be overridden; hard red line.
    case absolute
}

/// Per-boundary prior matching L4 whitepaper §5.7. Six fields
/// mapping the boundary identity + domain + severity + hard-stop
/// flag + safe alternatives + escalation rule.
public struct BASBoundaryPrior:
    BASSchemaVersioned, Hashable, Sendable
{
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var boundaryID: String
    public var domain: String
    public var severity: BASBoundaryPriorSeverity
    public var hardStop: Bool
    public var safeAlternatives: [String]
    public var escalationRule: String

    public init(
        schemaVersion: String = BASBoundaryPrior.currentSchemaVersion,
        boundaryID: String,
        domain: String,
        severity: BASBoundaryPriorSeverity,
        hardStop: Bool,
        safeAlternatives: [String] = [],
        escalationRule: String = ""
    ) {
        self.schemaVersion = schemaVersion
        self.boundaryID = boundaryID
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.domain = domain
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.severity = severity
        self.hardStop = hardStop
        self.safeAlternatives = safeAlternatives
        self.escalationRule = escalationRule
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - 5.9 TemporalKnowledgeTier

/// Per-knowledge-item tiering matching L4 whitepaper §5.9. The
/// tier comes from the same vocabulary as `BASHorizonStabilityTier`
/// (invariant / semi-stable / volatile). This struct binds a
/// specific knowledge item to its tier + refresh policy.
public struct BASTemporalKnowledgeTier:
    BASSchemaVersioned, Hashable, Sendable
{
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var knowledgeID: String
    public var tier: BASHorizonStabilityTier
    public var refreshRequirement: String
    public var decayPolicy: String
    public var timeScope: String

    public init(
        schemaVersion: String = BASTemporalKnowledgeTier.currentSchemaVersion,
        knowledgeID: String,
        tier: BASHorizonStabilityTier,
        refreshRequirement: String = "",
        decayPolicy: String = "",
        timeScope: String = ""
    ) {
        self.schemaVersion = schemaVersion
        self.knowledgeID = knowledgeID
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.tier = tier
        self.refreshRequirement = refreshRequirement
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.decayPolicy = decayPolicy
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.timeScope = timeScope
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - 5.10 EvidenceGradient

/// Per-claim evidence gradient matching L4 whitepaper §5.10. Four
/// whitepaper fields mapping claim class + support level +
/// contestability + required caveat.
public struct BASEvidenceGradient:
    BASSchemaVersioned, Hashable, Sendable
{
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var claimType: String
    /// Support level [0, 1]: 0 = unsupported, 1 = strong
    /// multi-source support.
    public var supportLevel: Double
    /// Contestability [0, 1]: 0 = uncontested consensus, 1 =
    /// actively contested.
    public var contestability: Double
    public var requiredCaveat: String

    public init(
        schemaVersion: String = BASEvidenceGradient.currentSchemaVersion,
        claimType: String,
        supportLevel: Double,
        contestability: Double,
        requiredCaveat: String = ""
    ) {
        self.schemaVersion = schemaVersion
        self.claimType = claimType
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.supportLevel = min(1, max(0, supportLevel))
        self.contestability = min(1, max(0, contestability))
        self.requiredCaveat = requiredCaveat
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
