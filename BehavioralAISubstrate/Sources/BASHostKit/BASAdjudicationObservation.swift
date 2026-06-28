import Foundation
import os
import BASOrgan

/// observe→DISPOSE — measurability for the neuromodulation gate. Mirrors `BASModelHonestyObservation`
/// (BASSovereign) exactly: a typed per-turn `Record` + an in-memory actor store + an opt-in, default-OFF
/// recording seam. You cannot TUNE a gate you cannot SEE — once the adjudicator skips turns
/// (`BAS_ADJ_GATE`), an operator needs the per-turn breakdown (skipped / injected / abstained) to judge
/// whether the gate is dropping turns that mattered. This is the OBSERVE lane: it records, it never gates,
/// and it never touches the sovereign byte-parity verdict.
///
/// Default-OFF: with no observer wired (and `BAS_ADJ_OBSERVE` unset) the adapter is a byte-equal no-op —
/// `observer?(…)` is `nil`, so nothing is emitted and the turn path is identical to not observing.

// MARK: - Record

public struct BASAdjudicationObservationRecord: Sendable, Equatable, Codable {

    /// What the adjudicator did with this turn — the four mutually-exclusive exits of `adjudicated(_:)`.
    public enum Outcome: String, Sendable, Equatable, Codable, CaseIterable {
        /// The neuromodulation gate skipped the turn (avoided compute — no parse, no embed).
        case gateSkipped
        /// Gate engaged but no belief-assertion was parsed from the turn.
        case noAssertion
        /// Assertion parsed but the fact bank's cosine was below threshold (abstain).
        case belowThreshold
        /// A verdict was injected into the turn.
        case injected
    }

    public let requestID: String
    public let role: BASOrganRole
    public let outcome: Outcome

    public init(requestID: String, role: BASOrganRole, outcome: Outcome) {
        self.requestID = requestID
        self.role = role
        self.outcome = outcome
    }
}

/// The per-turn observation hook the adapter calls at each `adjudicated(_:)` exit. Default `nil` ⇒ no-op.
public typealias BASAdjudicationObserver =
    @Sendable (BASAdjudicationObservationRecord) async -> Void

// MARK: - Store protocol + in-memory reference impl (mirrors BASInMemoryModelHonestyObservationStore)

public protocol BASAdjudicationObservationStore: Sendable {
    func append(_ record: BASAdjudicationObservationRecord) async
    func records() async -> [BASAdjudicationObservationRecord]
    func count(of outcome: BASAdjudicationObservationRecord.Outcome) async -> Int
}

public actor BASInMemoryAdjudicationObservationStore: BASAdjudicationObservationStore {
    private var stored: [BASAdjudicationObservationRecord] = []
    public init() {}
    public func append(_ record: BASAdjudicationObservationRecord) async { stored.append(record) }
    public func records() async -> [BASAdjudicationObservationRecord] { stored }
    public func count(of outcome: BASAdjudicationObservationRecord.Outcome) async -> Int {
        stored.lazy.filter { $0.outcome == outcome }.count
    }
    /// Fraction of ALL observed turns the neuromodulation gate skipped (`gateSkipped / total`) — the gate's
    /// avoided-compute ratio. Returns 0 when nothing has been observed.
    public func skipRate() async -> Double {
        guard !stored.isEmpty else { return 0 }
        let skipped = stored.lazy.filter { $0.outcome == .gateSkipped }.count
        return Double(skipped) / Double(stored.count)
    }

    /// Of the turns the gate ENGAGED (`total − gateSkipped`), the fraction that actually injected a verdict
    /// (`injected / engaged`). Paired with `skipRate()` this is the tuning surface: a high skip-rate WITH a
    /// high inject-rate-among-engaged means the gate is cheap AND well-aimed; a high skip-rate that drops
    /// would-be injections is the danger. Returns 0 when no turn engaged.
    public func injectRateAmongEngaged() async -> Double {
        let engaged = stored.lazy.filter { $0.outcome != .gateSkipped }.count
        guard engaged > 0 else { return 0 }
        let injected = stored.lazy.filter { $0.outcome == .injected }.count
        return Double(injected) / Double(engaged)
    }
}

// MARK: - Opt-in, default-OFF default observer

public enum BASAdjudicationObservation {

    /// Opt-in gate. Default OFF ⇒ no default observer. `env` injectable for tests.
    public static func isEnabled(
        _ env: [String: String] = ProcessInfo.processInfo.environment
    ) -> Bool {
        env["BAS_ADJ_OBSERVE"] == "1"
    }

    /// A ready-made `os.Logger` observer when `BAS_ADJ_OBSERVE=1`, else `nil`. Lets an operator measure the
    /// gate's per-turn behavior on-device with ZERO host code — the records surface in the unified log under
    /// subsystem `bas.adjudicator`, category `gate`, line `ADJ_GATE|<outcome>|<role>|<requestID>`. Wiring a
    /// store-backed observer instead is the host's option (inject it into `adjudicating(_:observer:)`).
    public static func defaultObserverIfEnabled(
        enabled: Bool = BASAdjudicationObservation.isEnabled()
    ) -> BASAdjudicationObserver? {
        guard enabled else { return nil }
        let logger = Logger(subsystem: "bas.adjudicator", category: "gate")
        return { record in
            logger.log("ADJ_GATE|\(record.outcome.rawValue, privacy: .public)|\(record.role.rawValue, privacy: .public)|\(record.requestID, privacy: .public)")
        }
    }
}
