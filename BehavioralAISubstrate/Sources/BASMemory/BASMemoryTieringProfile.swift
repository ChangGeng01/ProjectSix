import Foundation
import BASRuntimeCore

// MARK: - Temperature profile
//
// M20 — L8 Phase 1 seed: Temporal Memory Field primitives.
//
// Before today, `BASMemoryTier` was a static string (`hot / warm /
// cold`) stored on an atom at admission time. Nothing computed whether
// an atom *should* be promoted or demoted based on age, access
// patterns, sensitivity drift, or world-context changes. Tier was a
// label, not a decision.
//
// This file lands the typed primitives that describe a memory atom's
// *thermal profile* and the pure policy that turns a profile into a
// `BASMemoryTierTransition`. No mutation of existing atoms happens in
// this commit — the primitives are additive. A later milestone
// (Phase 1 wiring) will introduce the reconciliation pass that reads
// profiles and actually promotes/demotes atoms in `MemoryCore`.
//
// Design principles followed:
//   1. Immutability — `BASMemoryTieringProfile` is a value type;
//      any change produces a new profile.
//   2. Purity — `BASMemoryTemperaturePolicy.recommendTransition(...)`
//      is a `Sendable` static function. Same input → same output.
//   3. Audit — `BASMemoryTierTransitionLog` (below) is an actor that
//      captures every suggested transition in an append-only ring,
//      so downstream L14 can reconcile against the ledger.

/// Thermal signal for a single memory atom. Captures the four inputs
/// that drive the hot/warm/cold transition decision:
///
/// - **recencyScore**: 1.0 = just accessed, 0.0 = never / long-ago
/// - **accessFrequency**: normalized access rate, 0.0–1.0
/// - **sensitivityDrift**: 0.0 = stable, 1.0 = sensitivity escalated
///   since admission (e.g., host raised its classification)
/// - **worldContextStaleness**: 0.0 = world priors still agree,
///   1.0 = world priors have shifted enough that this atom's causal
///   backing is questioned
public struct BASMemoryTieringProfile: Sendable, Equatable, Codable {
    /// **M600 chapter 一百七十一 — anti-magic-number** (chapter 一百六十六
    /// §166.5 backlog 4 of 6): composite heat score weights for
    /// `compositeHeat` formula at line ~80.
    ///
    /// Doctrine: heat is dominated by recency (substrate memory
    /// is inherently recency-biased), boosted by access frequency
    /// (repeated probes = relevance), penalized by staleness
    /// (drifted atoms cooler even if recently touched).
    ///
    /// Pre-fix these 3 values were inline at line ~76-77:
    ///   `let positive = 0.55 * recencyScore + 0.35 * accessFrequency`
    ///   `let penalty = 0.10 * worldContextStaleness`
    ///
    /// **Tier ordering**: recency (0.55, dominant) > access (0.35,
    /// secondary) > staleness (0.10, penalty). The 3 weights sum
    /// 0.55 + 0.35 + 0.10 = 1.00 (sum-to-one fraction-family).
    public static let
        compositeHeatRecencyWeight: Double = 0.55
    public static let
        compositeHeatAccessWeight: Double = 0.35
    public static let
        compositeHeatStalenessPenaltyWeight: Double = 0.10

    public let atomID: String
    public let currentTier: BASMemoryTier
    public let recencyScore: Double
    public let accessFrequency: Double
    public let sensitivityDrift: Double
    public let worldContextStaleness: Double
    public let observedAt: Date

    public init(
        atomID: String,
        currentTier: BASMemoryTier,
        recencyScore: Double,
        accessFrequency: Double,
        sensitivityDrift: Double,
        worldContextStaleness: Double,
        observedAt: Date
    ) {
        self.atomID = atomID
        self.currentTier = currentTier
        self.recencyScore = Self.clamp(recencyScore)
        self.accessFrequency = Self.clamp(accessFrequency)
        self.sensitivityDrift = Self.clamp(sensitivityDrift)
        self.worldContextStaleness = Self.clamp(worldContextStaleness)
        self.observedAt = observedAt
    }

    /// Normalized composite heat score in [0, 1]. Higher means the
    /// atom should trend toward `.hot`. Policy may override via
    /// sensitivity-drift or staleness short-circuits.
    public var compositeHeat: Double {
        // M600 chapter 一百七十一 — anti-magic-number: weights
        // sourced from named static properties with doc-comment
        // tier ordering. Doctrine: recency dominates → access
        // boosts → staleness penalizes.
        let positive = Self.compositeHeatRecencyWeight
            * recencyScore
            + Self.compositeHeatAccessWeight
            * accessFrequency
        let penalty = Self.compositeHeatStalenessPenaltyWeight
            * worldContextStaleness
        return max(0, min(1, positive - penalty))
    }

    private static func clamp(_ value: Double) -> Double {
        min(1, max(0, value))
    }
}

// MARK: - Tier transitions

/// Typed suggestion for what should happen to an atom next. The
/// policy emits exactly one `BASMemoryTierTransition` per profile
/// evaluation; nothing here mutates memory directly — the enum is a
/// recommendation that the reconciliation pass acts on.
public enum BASMemoryTierTransition: Sendable, Equatable, Codable {
    /// The atom's tier is correct; leave it alone.
    case hold(tier: BASMemoryTier, reason: BASMemoryTierHoldReason)

    /// Move the atom one tier warmer (cold → warm, or warm → hot).
    case promote(
        from: BASMemoryTier,
        to: BASMemoryTier,
        reason: BASMemoryTierPromoteReason
    )

    /// Move the atom one tier cooler (hot → warm, or warm → cold).
    case demote(
        from: BASMemoryTier,
        to: BASMemoryTier,
        reason: BASMemoryTierDemoteReason
    )

    /// The atom has drifted into sensitivity or contamination
    /// territory; the reconciliation pass should hand it to the
    /// quarantine path instead of moving it along the normal tier
    /// ladder.
    case quarantineSuggest(
        from: BASMemoryTier,
        reason: BASMemoryQuarantineReason
    )

    /// The atom is cold, not accessed, not sensitive — the
    /// reconciliation pass should evict it on the next governance
    /// sweep. Eviction itself still flows through the existing
    /// forget-cascade surface.
    case evictSuggest(from: BASMemoryTier, reason: BASMemoryEvictReason)
}

public enum BASMemoryTierHoldReason: String, Sendable, Codable {
    case withinThresholds
    case recentlyTransitioned
    case lockedByHost
}

public enum BASMemoryTierPromoteReason: String, Sendable, Codable {
    case highRecency
    case highAccessFrequency
    case compositeHeatAboveUpperBand
}

public enum BASMemoryTierDemoteReason: String, Sendable, Codable {
    case lowRecency
    case lowAccessFrequency
    case compositeHeatBelowLowerBand
    case worldContextStale
}

public enum BASMemoryQuarantineReason: String, Sendable, Codable {
    case sensitivityEscalated
    case worldContextContaminated
}

public enum BASMemoryEvictReason: String, Sendable, Codable {
    case coldStaleUnused
    case worldContextStaleAndCold
}

// MARK: - Temperature policy

/// Pure policy: given a `BASMemoryTieringProfile`, return the
/// recommended `BASMemoryTierTransition`. No side effects; same
/// input always returns same output.
///
/// Band structure:
///
///   hot upper band:    compositeHeat >= 0.70
///   warm band:         0.35 ≤ compositeHeat < 0.70
///   cold band:         compositeHeat < 0.35
///
/// Sensitivity and world-context escalations short-circuit the band
/// ladder (quarantine before tier).
public enum BASMemoryTemperaturePolicy {
    public static let hotUpperBand: Double = 0.70
    public static let warmLowerBand: Double = 0.35
    public static let quarantineSensitivityThreshold: Double = 0.75
    public static let quarantineContaminationThreshold: Double = 0.75
    /// Staleness at or above this value (AND below the
    /// `quarantineContaminationThreshold`) means the atom's world
    /// backing is shaky enough to evict if it's already cold, but
    /// not escalated enough to quarantine. Must stay below the
    /// quarantine threshold so the bands don't collide.
    public static let evictStalenessThreshold: Double = 0.50

    public static func recommendTransition(
        for profile: BASMemoryTieringProfile
    ) -> BASMemoryTierTransition {
        // Rule 1: sensitivity escalation beats everything. An atom
        // that drifted past the sensitivity line goes to quarantine
        // regardless of tier.
        if profile.sensitivityDrift >= quarantineSensitivityThreshold {
            return .quarantineSuggest(
                from: profile.currentTier,
                reason: .sensitivityEscalated)
        }

        // Rule 2: world-context contamination beats tier laddering.
        if profile.worldContextStaleness
            >= quarantineContaminationThreshold
        {
            return .quarantineSuggest(
                from: profile.currentTier,
                reason: .worldContextContaminated)
        }

        let heat = profile.compositeHeat

        // Rule 3: band-based promote / demote / hold.
        switch profile.currentTier {
        case .hot:
            if heat < warmLowerBand {
                return .demote(
                    from: .hot,
                    to: .warm,
                    reason: .compositeHeatBelowLowerBand)
            }
            return .hold(tier: .hot, reason: .withinThresholds)

        case .warm:
            if heat >= hotUpperBand {
                return .promote(
                    from: .warm,
                    to: .hot,
                    reason: .compositeHeatAboveUpperBand)
            }
            if heat < warmLowerBand {
                return .demote(
                    from: .warm,
                    to: .cold,
                    reason: .compositeHeatBelowLowerBand)
            }
            return .hold(tier: .warm, reason: .withinThresholds)

        case .cold:
            if heat >= warmLowerBand {
                return .promote(
                    from: .cold,
                    to: .warm,
                    reason: .compositeHeatAboveUpperBand)
            }
            // Rule 4: eviction suggestion when cold + very stale
            // world context.
            if profile.worldContextStaleness >= evictStalenessThreshold {
                return .evictSuggest(
                    from: .cold,
                    reason: .worldContextStaleAndCold)
            }
            // Rule 5: eviction suggestion when cold + totally unused.
            if profile.recencyScore == 0
                && profile.accessFrequency == 0
            {
                return .evictSuggest(
                    from: .cold,
                    reason: .coldStaleUnused)
            }
            return .hold(tier: .cold, reason: .withinThresholds)
        }
    }
}

// MARK: - Audit log

/// Append-only ring buffer of transition suggestions. The
/// reconciliation pass writes every decision here so L14's audit
/// ledger can reconcile against a tamper-evident trail of what the
/// policy recommended (independent of what the reconciliation pass
/// actually applied). 256 entries is enough to cover any one
/// governance sweep without unbounded growth.
public actor BASMemoryTierTransitionLog {
    public struct Entry: Sendable, Equatable, Codable {
        public let profile: BASMemoryTieringProfile
        public let transition: BASMemoryTierTransition
        public let recordedAt: Date

        public init(
            profile: BASMemoryTieringProfile,
            transition: BASMemoryTierTransition,
            recordedAt: Date
        ) {
            self.profile = profile
            self.transition = transition
            self.recordedAt = recordedAt
        }
    }

    public static let defaultCapacity: Int = 256

    private let capacity: Int
    private let clock: @Sendable () -> Date
    private var buffer: [Entry] = []

    public init(
        capacity: Int = BASMemoryTierTransitionLog.defaultCapacity,
        clock: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.capacity = max(1, capacity)
        self.clock = clock
    }

    /// Record a recommended transition for a profile. Returns the
    /// newly written entry so callers can correlate log lines.
    @discardableResult
    public func record(
        profile: BASMemoryTieringProfile,
        transition: BASMemoryTierTransition
    ) -> Entry {
        let entry = Entry(
            profile: profile,
            transition: transition,
            recordedAt: clock())
        buffer.append(entry)
        if buffer.count > capacity {
            buffer.removeFirst(buffer.count - capacity)
        }
        return entry
    }

    public func snapshot() -> [Entry] { buffer }

    public func count() -> Int { buffer.count }

    public func clear() { buffer.removeAll() }
}
