import Foundation

/// ②-observe (durable sink) — a per-turn record of the substrate's model-honesty observation.
///
/// Mirrors `BASPresenceObservationStore` exactly (typed record + protocol + in-memory actor). It lets the
/// substrate DURABLY record what `BASModelHonestySignal` produces for each turn, closing the
/// "structurally invisible" gap — WITHOUT ever touching the byte-parity sovereign verdict. This is the
/// OBSERVE lane: it records; it never gates. The honesty signal must NEVER reach `evaluateLevel()` (the
/// verdict consumes exactly 7 f64, byte-identical Swift↔Rust; feeding it model content is the one
/// irreversible, against-the-grain change — see the evolution audit's "biggest trap").
///
/// Wiring is opt-in + default-OFF: `isObservationEnabled` reads `BAS_HONESTY_OBSERVE` (default false), so
/// a host that does not opt in is a byte-equal no-op — the project's own proven shadow-seam pattern.
/// Timestamps are caller-supplied (`observedAtMs`) so the record stays deterministic for replay.

// MARK: - Record

public struct BASModelHonestyObservationRecord: Sendable, Equatable, Codable {
    public let eventID: String
    public let sessionID: String
    public let turnID: String
    public let flattery: Double
    public let hedging: Double
    public let overclaim: Double
    public let flatteryBand: BASModelHonestySignal.Band
    public let hedgingBand: BASModelHonestySignal.Band
    public let overclaimBand: BASModelHonestySignal.Band
    public let observedAtMs: Int64
    /// 触发器①: whether the English lexicons could honestly read the scored body (false on
    /// CJK-dominant turns — consumers MUST render n/a(zh), never a false-green "ok").
    /// Additive: old serialized records decode as `true` (they predate the flag).
    public let lexiconApplicable: Bool

    public init(
        eventID: String,
        sessionID: String,
        turnID: String,
        axes: BASModelHonestySignal.Axes,
        observedAtMs: Int64,
        lexiconApplicable: Bool = true
    ) {
        self.eventID = eventID
        self.sessionID = sessionID
        self.turnID = turnID
        self.flattery = axes.flattery
        self.hedging = axes.hedging
        self.overclaim = axes.overclaim
        self.flatteryBand = axes.flatteryBand
        self.hedgingBand = axes.hedgingBand
        self.overclaimBand = axes.overclaimBand
        self.observedAtMs = observedAtMs
        self.lexiconApplicable = lexiconApplicable
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        eventID = try c.decode(String.self, forKey: .eventID)
        sessionID = try c.decode(String.self, forKey: .sessionID)
        turnID = try c.decode(String.self, forKey: .turnID)
        flattery = try c.decode(Double.self, forKey: .flattery)
        hedging = try c.decode(Double.self, forKey: .hedging)
        overclaim = try c.decode(Double.self, forKey: .overclaim)
        flatteryBand = try c.decode(BASModelHonestySignal.Band.self, forKey: .flatteryBand)
        hedgingBand = try c.decode(BASModelHonestySignal.Band.self, forKey: .hedgingBand)
        overclaimBand = try c.decode(BASModelHonestySignal.Band.self, forKey: .overclaimBand)
        observedAtMs = try c.decode(Int64.self, forKey: .observedAtMs)
        lexiconApplicable = try c.decodeIfPresent(Bool.self, forKey: .lexiconApplicable) ?? true
    }

    /// 触发器①的署名消费者面 — THE per-turn honesty line (one line, grep-friendly, zero disk;
    /// the operator's log stream is the reader). n/a(zh) keeps the gauge honest on turns the
    /// English lexicons cannot read.
    public var summaryLine: String {
        func render(_ band: BASModelHonestySignal.Band) -> String {
            // false = kana/hangul-dominant since 章程 Z2 (zh is READABLE now) — label honestly.
            lexiconApplicable ? band.rawValue : "n/a(script)"
        }
        return "🪞 honesty id=\(sessionID)#\(turnID) flattery=\(render(flatteryBand)) "
            + "hedging=\(render(hedgingBand)) overclaim=\(render(overclaimBand))"
    }
}

// MARK: - Store protocol

public protocol BASModelHonestyObservationStore: Sendable {
    func appendRecord(_ record: BASModelHonestyObservationRecord) async throws -> BASModelHonestyObservationRecord
    func records(forSession sessionID: String) async -> [BASModelHonestyObservationRecord]
    func count() async -> Int
}

// MARK: - In-memory reference impl (mirrors BASInMemoryPresenceObservationStore)

public actor BASInMemoryModelHonestyObservationStore: BASModelHonestyObservationStore {
    public enum StoreError: Error, Equatable, Sendable {
        case duplicateEventID(String)
    }

    private var records: [BASModelHonestyObservationRecord] = []
    private var indexByEventID: [String: Int] = [:]

    public init() {}

    public func appendRecord(
        _ record: BASModelHonestyObservationRecord
    ) async throws -> BASModelHonestyObservationRecord {
        if indexByEventID[record.eventID] != nil {
            throw StoreError.duplicateEventID(record.eventID)
        }
        indexByEventID[record.eventID] = records.count
        records.append(record)
        return record
    }

    public func records(forSession sessionID: String) async -> [BASModelHonestyObservationRecord] {
        records.filter { $0.sessionID == sessionID }
    }

    public func count() async -> Int { records.count }
}

// MARK: - Opt-in, default-OFF recording seam

public enum BASModelHonestyObservation {

    /// The opt-in gate. Default OFF ⇒ a host that does not set `BAS_HONESTY_OBSERVE=1` is a byte-equal
    /// no-op. `env` is injectable so this is unit-testable without mutating the process environment.
    public static func isObservationEnabled(
        _ env: [String: String] = ProcessInfo.processInfo.environment
    ) -> Bool {
        env["BAS_HONESTY_OBSERVE"] == "1"
    }

    /// Score `body` and record an observation IFF observation is enabled. When disabled, this is a pure
    /// no-op (returns nil, never touches the store) — the host turn path is byte-identical to not calling it.
    /// Never gates, halts, or feeds the sovereign verdict.
    @discardableResult
    public static func recordIfEnabled(
        body: String,
        sessionID: String,
        turnID: String,
        eventID: String,
        observedAtMs: Int64,
        into store: BASModelHonestyObservationStore,
        enabled: Bool = BASModelHonestyObservation.isObservationEnabled()
    ) async -> BASModelHonestyObservationRecord? {
        guard enabled else { return nil }
        let record = BASModelHonestyObservationRecord(
            eventID: eventID,
            sessionID: sessionID,
            turnID: turnID,
            axes: BASModelHonestySignal.axes(body),
            observedAtMs: observedAtMs)
        return try? await store.appendRecord(record)
    }
}
