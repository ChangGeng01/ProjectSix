import Foundation
import BASRuntimeCore

// MARK: - Soft-hand observation primitives
//
// M27 — L12 柔手 Phase 1 seed: typed per-mode render observation
// model.
//
// L12 is the UI surface — five protection modes that the system
// can render on any given turn:
//   - compare    (比较板)       — side-by-side alternatives
//   - draft      (草稿壳)       — deferred draft with no side effects
//   - delay      (延迟包)       — packet deferred to a later window
//   - boundary   (边界脚本)     — explicit "this crosses your boundary"
//   - silentStub (静默桩)       — minimal safe placeholder
//
// Upstream observations describe how the hand behaved this turn:
// which modes were suggested, which was selected, whether the
// selection rendered, whether it was deferred, downgraded to a
// safer mode, or escalated to a stricter one. Before M27 those
// transitions were implicit. This file lands the additive
// primitives so an observer pipeline can emit typed per-mode
// signals that the L14 surface can reconcile with whatever the
// final render surface actually produced.
//
// Design mirrors M22/M23/M24/M25/M26 on purpose: the L14
// reconciler reads one shape across L6/L7/L9/L10/L11/L12.
//
// Design principles:
//   1. Immutability — every reading is a value; a bundle is
//      frozen once emitted.
//   2. Typed mode + kind — no free-form strings; two sealed
//      enums.
//   3. Subject-addressable — every observation carries a
//      subjectID (the turn artifact the mode acts on) so the L14
//      surface can group signals per subject.
//   4. Budget-aware — per-signal L1 cost with clamped totalCost.
//      Escalation (to a stricter mode) costs more than routine
//      selection.
//   5. Auditable — append-only ring actor ledger keyed by turn
//      and session.

/// The six UI render modes L12 can emit (M291 added `.localOnly`).
public enum BASSoftHandMode:
    String, Sendable, Codable, CaseIterable
{
    /// 比较板 — side-by-side alternatives for the host to pick.
    case compare
    /// 草稿壳 — deferred draft, no side effects until confirmed.
    case draft
    /// 延迟包 — wait until a later window to act.
    case delay
    /// 边界脚本 — explicit "this crosses your boundary".
    case boundary
    /// 静默桩 — minimal safe placeholder; renders nothing
    /// actionable.
    case silentStub
    /// 本地簿 — host-private surface that **does not transmit**.
    /// Resulting artifact is captured into the host's local-only
    /// store (journal / private notes / ephemeral scratch) so the
    /// reasoning persists for the host but no external recipient
    /// is involved. M291 lifts manifest v2's 6th surface from
    /// permit-mode-only to a first-class soft-hand mode.
    case localOnly

    /// M281 — stable component identifier matching the
    /// `QinaoUI.ComponentID` namespace. Hosts call
    /// `selectMode(...)` (M280) to pick a mode, then use
    /// `componentIdentifier` to look up the right view in
    /// `QinaoUI`. Bridge stays a stable string so neither side
    /// has to import the other's module.
    ///
    /// | mode       | identifier         |
    /// |------------|--------------------|
    /// | compare    | "compare-panel"    |
    /// | draft      | "draft-shell"      |
    /// | delay      | "delay-packet"     |
    /// | boundary   | "boundary-script"  |
    /// | silentStub | "silent-stub"      |
    /// | localOnly  | "local-only-sheet" |
    public var componentIdentifier: String {
        switch self {
        case .compare: return "compare-panel"
        case .draft: return "draft-shell"
        case .delay: return "delay-packet"
        case .boundary: return "boundary-script"
        case .silentStub: return "silent-stub"
        case .localOnly: return "local-only-sheet"
        }
    }
}

/// The six upstream signals a soft-hand observer pipeline can
/// emit. Each pertains to exactly one mode (the `mode` field on
/// the observation).
public enum BASSoftHandSignalKind:
    String, Sendable, Codable, CaseIterable
{
    /// A suggestion from a picker that this mode should fire.
    case suggestion
    /// The picker locked in this mode as the one to render.
    case selection
    /// This mode rendered successfully this turn.
    case render
    /// This mode was deferred — pushed to a later turn without
    /// rendering.
    case deferral
    /// The active mode was downgraded to a safer one (e.g.
    /// compare → silentStub) — the `mode` field carries the
    /// target mode.
    case downgrade
    /// The active mode was escalated to a stricter one (e.g.
    /// draft → boundary) — the `mode` field carries the target
    /// mode.
    case escalation
}

/// A single typed soft-hand observation. Salience and confidence
/// are in [0, 1]; content is opaque to the transport but carries
/// the signal-specific payload (mode rationale, downgrade
/// reason). `subjectID` identifies the turn artifact (candidate /
/// intent / decision) the mode acts on; multiple observations
/// may share a subjectID.
public struct BASSoftHandObservation:
    Sendable, Equatable, Codable
{
    public let kind: BASSoftHandSignalKind
    public let mode: BASSoftHandMode
    public let subjectID: String
    public let salience: Double
    public let confidence: Double
    public let content: String
    public let observedAt: Date

    public init(
        kind: BASSoftHandSignalKind,
        mode: BASSoftHandMode,
        subjectID: String,
        salience: Double,
        confidence: Double,
        content: String,
        observedAt: Date
    ) {
        self.kind = kind
        self.mode = mode
        self.subjectID = subjectID
        self.salience = Self.clamp(salience)
        self.confidence = Self.clamp(confidence)
        self.content = content
        self.observedAt = observedAt
    }

    private static func clamp(_ value: Double) -> Double {
        min(1, max(0, value))
    }
}

/// A bundle of soft-hand observations emitted in one turn.
public struct BASSoftHandObservationBundle:
    Sendable, Equatable, Codable
{
    public let turnID: String
    public let sessionID: String
    public let observations: [BASSoftHandObservation]
    public let emittedAt: Date

    public init(
        turnID: String,
        sessionID: String,
        observations: [BASSoftHandObservation],
        emittedAt: Date
    ) {
        self.turnID = turnID
        self.sessionID = sessionID
        self.observations = observations
        self.emittedAt = emittedAt
    }

    /// Observations of a given kind, in emission order.
    public func observations(
        of kind: BASSoftHandSignalKind
    ) -> [BASSoftHandObservation] {
        observations.filter { $0.kind == kind }
    }

    /// Observations for a given mode, across all kinds, in
    /// emission order.
    public func observations(
        forMode mode: BASSoftHandMode
    ) -> [BASSoftHandObservation] {
        observations.filter { $0.mode == mode }
    }

    /// Observations for a given subject, across all modes and
    /// kinds, in emission order.
    public func observations(
        forSubject subjectID: String
    ) -> [BASSoftHandObservation] {
        observations.filter { $0.subjectID == subjectID }
    }

    /// The mode that was actually selected this turn, or `nil` if
    /// no selection was recorded. If multiple selections were
    /// emitted (which should not happen), returns the latest.
    public var selectedMode: BASSoftHandMode? {
        observations.last { $0.kind == .selection }?.mode
    }

    /// True iff at least one `render` observation was emitted for
    /// the selected mode. A turn that selects but never renders
    /// represents a hand failure and should be audited.
    public var renderedAsSelected: Bool {
        guard let selected = selectedMode else { return false }
        return observations.contains {
            $0.kind == .render && $0.mode == selected
        }
    }

    /// True iff the bundle carries at least a selection and a
    /// render — the minimum signal set that proves the hand
    /// actually acted this turn.
    public var hasCoreSignalCoverage: Bool {
        let covered = Set(observations.map { $0.kind })
        return covered.contains(.selection)
            && covered.contains(.render)
    }

    /// Distinct subject IDs that appear anywhere in the bundle,
    /// first-seen order preserved.
    public var subjectIDs: [String] {
        var seen = Set<String>()
        var ordered: [String] = []
        for obs in observations
        where seen.insert(obs.subjectID).inserted {
            ordered.append(obs.subjectID)
        }
        return ordered
    }
}

// MARK: - Budget

/// Pure lookup: what does each soft-hand signal cost the L1 wake
/// budget? Values are weights in abstract budget units (0.0–1.0).
/// Escalation (to a stricter mode) is the most expensive — it
/// requires re-evaluating the subject under a tighter policy.
public enum BASSoftHandObservationBudget {
    public static let signalCost:
        [BASSoftHandSignalKind: Double] = [
            .suggestion: 0.10,
            .selection: 0.10,
            .render: 0.15,
            .deferral: 0.10,
            .downgrade: 0.20,
            .escalation: 0.25
        ]

    public static func cost(
        for kind: BASSoftHandSignalKind
    ) -> Double {
        signalCost[kind] ?? 0
    }

    public static func totalCost(
        for bundle: BASSoftHandObservationBundle
    ) -> Double {
        let sum = bundle.observations.reduce(0.0) { acc, obs in
            acc + cost(for: obs.kind)
        }
        return min(1, max(0, sum))
    }
}

// MARK: - Ledger

/// Append-only ring actor that keeps recent soft-hand observation
/// bundles so the L14 audit surface (and integration tests) can
/// inspect what L12 emitted across a session. 128 entries covers
/// any realistic turn stream without unbounded growth.
public actor BASSoftHandObservationLedger {
    public static let defaultCapacity: Int = 128

    private let capacity: Int
    private var buffer: [BASSoftHandObservationBundle] = []

    public init(
        capacity: Int =
            BASSoftHandObservationLedger.defaultCapacity
    ) {
        self.capacity = max(1, capacity)
    }

    public func record(
        _ bundle: BASSoftHandObservationBundle
    ) {
        buffer.append(bundle)
        if buffer.count > capacity {
            buffer.removeFirst(buffer.count - capacity)
        }
    }

    public func snapshot() -> [BASSoftHandObservationBundle] {
        buffer
    }

    public func count() -> Int { buffer.count }

    public func bundles(
        forSession sessionID: String
    ) -> [BASSoftHandObservationBundle] {
        buffer.filter { $0.sessionID == sessionID }
    }

    public func bundle(
        forTurn turnID: String
    ) -> BASSoftHandObservationBundle? {
        buffer.first { $0.turnID == turnID }
    }

    public func clear() { buffer.removeAll() }
}
