import Foundation
import BASRuntimeCore

// MARK: - Presence observation primitives
//
// M22 — L6 临在眼 Phase 1 seed: typed per-channel observation model.
//
// `BASContextFrame` (defined in EBrainCognitionPlaneCore) already
// captures a rich per-turn presence summary, but nothing in the
// codebase currently describes the *upstream* channel readings that
// feed into it. Before M22, channel-specific observations were ad-hoc
// tuples assembled inline in the coordinator. This file lands the
// typed primitives that an observer pipeline can emit per turn and
// that the ContextFrame builder will ultimately consume.
//
// The primitives are additive: `BASContextFrame` is unchanged, and
// no coordinator path is rewired in this commit. A later milestone
// will feed the bundle into `BASContextFrame` assembly + stamp the
// bundle onto the L14 audit surface.
//
// Design principles:
//   1. Immutability — every observation is a value; a bundle is a
//      frozen list once emitted.
//   2. Typed channels — no free-form strings for channel identity;
//      `BASPresenceChannel` is a sealed enum.
//   3. Budget-aware — `BASPresenceObservationBudget` returns the
//      L1 budget cost per channel so callers can decide, before
//      observation, whether they can afford to look.
//   4. Auditable — `BASPresenceObservationLedger` is an append-only
//      ring actor. The L14 surface can reconcile the ledger against
//      what the ContextFrame actually declared in the turn report.

/// Channels that an L6 observer pipeline can produce readings for.
/// The list is sealed so downstream consumers get a compile-time
/// switch-exhaustiveness guarantee. Adding a channel is an API
/// change that fans out to every consumer — by design.
public enum BASPresenceChannel: String, Sendable, Codable, CaseIterable {
    /// What the host appears to be trying to accomplish.
    case task
    /// Irreversibility, harm potential, consequence horizon.
    case risk
    /// Manipulation / social-engineering / gaslighting cues.
    case manipulation
    /// Physical environment signals (time of day, location class,
    /// device posture). Future consumer: L1 budget tuning.
    case environment
    /// Body-rhythm signals (host self-reported fatigue, sleep
    /// debt, HRV-style hints). Future consumer: L5 host
    /// constitution rhythm lane.
    case bodyRhythm
}

/// A single typed observation on one channel. Salience and
/// confidence are both in [0, 1]; content is opaque to the
/// transport but carries the channel-specific payload the
/// ContextFrame builder will consume.
public struct BASPresenceObservation: Sendable, Equatable, Codable {
    public let channel: BASPresenceChannel
    public let salience: Double
    public let confidence: Double
    public let content: String
    public let observedAt: Date

    public init(
        channel: BASPresenceChannel,
        salience: Double,
        confidence: Double,
        content: String,
        observedAt: Date
    ) {
        self.channel = channel
        self.salience = Self.clamp(salience)
        self.confidence = Self.clamp(confidence)
        self.content = content
        self.observedAt = observedAt
    }

    private static func clamp(_ value: Double) -> Double {
        min(1, max(0, value))
    }
}

/// A bundle of observations emitted in one turn, keyed by turn ID
/// so the L14 surface can later correlate the bundle with the turn
/// audit entry. The bundle is additive to the turn — callers may
/// emit zero observations on a light turn without breaking any
/// contract.
public struct BASPresenceObservationBundle: Sendable, Equatable, Codable
{
    public let turnID: String
    public let sessionID: String
    public let observations: [BASPresenceObservation]
    public let emittedAt: Date

    public init(
        turnID: String,
        sessionID: String,
        observations: [BASPresenceObservation],
        emittedAt: Date
    ) {
        self.turnID = turnID
        self.sessionID = sessionID
        self.observations = observations
        self.emittedAt = emittedAt
    }

    /// Observations for a given channel, in emission order.
    public func observations(
        for channel: BASPresenceChannel
    ) -> [BASPresenceObservation] {
        observations.filter { $0.channel == channel }
    }

    /// Highest-salience observation for a channel, or `nil` if the
    /// bundle carries no reading on that channel.
    public func dominantObservation(
        for channel: BASPresenceChannel
    ) -> BASPresenceObservation? {
        observations(for: channel)
            .max(by: { $0.salience < $1.salience })
    }

    /// True iff the bundle carries at least one observation on each
    /// of the three *core* channels (task / risk / manipulation).
    /// A bundle lacking any of these should trigger a degraded
    /// ContextFrame mode, not silent success.
    public var hasCoreChannelCoverage: Bool {
        let required: Set<BASPresenceChannel> = [
            .task, .risk, .manipulation]
        let covered = Set(observations.map { $0.channel })
        return required.isSubset(of: covered)
    }
}

// MARK: - Budget

/// Pure lookup: what does each channel cost the L1 wake budget?
/// The values here are additive to `BASBudgetFrame` — a later
/// milestone will fold `totalCost(for:)` into
/// `BASBudgetFrame.thermalGuardLevel` downgrade logic.
public enum BASPresenceObservationBudget {
    /// Per-channel cost in abstract budget units (0.0–1.0). These
    /// are not percentages of anything — they are weights that the
    /// budget frame maps to concrete CPU/time budget in a later
    /// wiring milestone.
    public static let channelCost:
        [BASPresenceChannel: Double] = [
            .task: 0.10,
            .risk: 0.25,
            .manipulation: 0.30,
            .environment: 0.05,
            .bodyRhythm: 0.05
        ]

    public static func cost(
        for channel: BASPresenceChannel
    ) -> Double {
        channelCost[channel] ?? 0
    }

    /// Total cost of a bundle — sum of per-observation costs.
    /// Clamped to [0, 1] so downstream consumers never see a
    /// pathological bundle that would drive a budget frame
    /// negative.
    public static func totalCost(
        for bundle: BASPresenceObservationBundle
    ) -> Double {
        let sum = bundle.observations.reduce(0.0) { acc, obs in
            acc + cost(for: obs.channel)
        }
        return min(1, max(0, sum))
    }
}

// MARK: - Ledger

/// Append-only ring actor that keeps recent bundles so the L14
/// audit surface (and integration tests) can inspect what L6
/// emitted across a session. 128 entries covers any realistic turn
/// stream without unbounded growth.
public actor BASPresenceObservationLedger {
    public static let defaultCapacity: Int = 128

    private let capacity: Int
    private var buffer: [BASPresenceObservationBundle] = []

    public init(
        capacity: Int =
            BASPresenceObservationLedger.defaultCapacity
    ) {
        self.capacity = max(1, capacity)
    }

    public func record(_ bundle: BASPresenceObservationBundle) {
        buffer.append(bundle)
        if buffer.count > capacity {
            buffer.removeFirst(buffer.count - capacity)
        }
    }

    public func snapshot() -> [BASPresenceObservationBundle] {
        buffer
    }

    public func count() -> Int { buffer.count }

    /// All bundles for a given session, most-recent-last.
    public func bundles(
        forSession sessionID: String
    ) -> [BASPresenceObservationBundle] {
        buffer.filter { $0.sessionID == sessionID }
    }

    /// The bundle with the given turn ID, or `nil` if no such
    /// bundle has been recorded (or it has aged out of the ring).
    public func bundle(
        forTurn turnID: String
    ) -> BASPresenceObservationBundle? {
        buffer.first { $0.turnID == turnID }
    }

    public func clear() { buffer.removeAll() }
}
