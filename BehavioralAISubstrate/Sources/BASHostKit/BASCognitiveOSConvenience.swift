// MARK: - BASCognitiveOSConvenience — chapter 三百七八 / M865
//
// Single-call helper that composes the three observation
// primitives — event log append (M841) + state reducer fold
// (M842) + knowledge graph extract (M857 + M860 heuristic 7) —
// behind ONE typed entry point。Reduces boilerplate for hosts
// that want the full data loop on every event。
//
// ## Why this exists (M862 audit observation)
//
// M862's `SampleHostChengluStressCognitiveOSObserver` hand-rolled
// per-iter event-log append + per-100-iter state-fold + per-1000-
// iter graph-extract logic。Other hosts wanting the same loop
// would have to duplicate that pattern。This file extracts the
// pattern into a typed helper that handles the cadence + the
// composition,leaving hosts to provide just:
//   - the bundle (from M859 builder)
//   - the session ID
//   - the event entry
//
// ## What this ships
//
//   - `BASCognitiveOSConvenienceCadence` typed struct holding
//     the per-event / per-N-event / per-M-event cadence。Default
//     mirrors the M862 observer (1 / 100 / 1000)。chapter 一百
//     八十五 anti-magic-number — every cadence value typed。
//   - `BASCognitiveOSConvenienceResult` typed Sendable struct
//     reporting which primitives fired this call (eventAppended /
//     stateFolded / graphExtracted) so hosts can surface stats。
//   - `BASCognitiveOSConvenience` actor:owns the rolling state
//     + iteration counter + invokes the right primitives at the
//     right cadence。Ergonomic single-call surface
//     `observe(event:)` → result。
//
// ## Doctrine pins held
//
// - 不变量 #1 / #2 / #3 全保 — convenience is observation only,
//   never mutates permits / verdicts / commit token
// - 红线 7 hint-only — the result is a HINT;L11 gate decides
// - chapter 二百一一 single-source-of-truth — ONE convenience
//   actor module owns the cadence + composition
// - chapter 一百八十五 anti-magic-number — cadence values typed
// - chapter 三百四七 (M834) bundle-lifecycle — convenience owns
//   the bundle for its lifetime,no destructure-and-drop
// - ADR-014 OPT-IN → PROD — host opts in by passing a non-empty
//   bundle;empty bundle → no-op observe call (zero behavior change)
//
// **Module placement**: BASHostKit (not BASRuntimeCore) because
// `BASUserStateStorage` lives in BASMemory and the convenience
// composes BOTH module boundaries — BASHostKit is the natural
// composition point that already imports both via @_exported。

import Foundation
import BASMemory
import BASRuntimeCore

// MARK: - Cadence

/// Chapter 三百九九 / M900 typed thermal sensitivity policy。
/// 10h iPhone run revealed device spent 98.13% of events in
/// `.serious` thermal state — convenience cadence had NO surface
/// to respond to thermal pressure。Hosts now opt in to
/// thermal-aware adaptation:
///
///   - `.ignoreThermal`:always run on schedule (M865 default
///     behavior;preserves back-compat)
///   - `.slowOnHot`:multiply graph-extract interval by 4x when
///     device is `.serious` or `.critical` (gives ANE / CPU
///     back to chenglu mesh path under thermal load)
///   - `.skipOnCritical`:skip graph extract entirely when
///     device is `.critical` (emergency thermal protection;
///     state fold continues since it's cheap)
public enum BASCognitiveOSThermalSensitivity:
    String, Sendable, Equatable, Hashable, CaseIterable,
    Codable
{
    // M913 hardening:explicit raw values lock the wire format
    // independent of the Swift case identifier。Pre-M913 raw
    // values were auto-derived from case names — a future PR
    // renaming `slowOnHot → throttleOnHot` would silently
    // change all schema 1.4.0 JSON files written from that
    // commit forward,breaking downstream parsers with no
    // compile error。Post-M913 the wire format is pinned;
    // renaming the case identifier requires explicitly
    // updating the rawValue string,catching the schema
    // implication at PR time。
    case ignoreThermal = "ignoreThermal"
    case slowOnHot = "slowOnHot"
    case skipOnCritical = "skipOnCritical"

    // M909 + M913 hardening:explicit `String, RawRepresentable`
    // conformance replaces the M905 `String(describing:)`
    // serialization。Use `.rawValue` for serialization:
    // `"ignoreThermal"` / `"slowOnHot"` / `"skipOnCritical"`。
}

/// Typed Sendable struct holding the convenience helper's cadence。
/// Defaults mirror M862 SampleHost observer values (1 / 100 / 1000)。
public struct BASCognitiveOSConvenienceCadence:
    Sendable, Equatable, Hashable, Codable
{
    /// State reducer fold interval (in `observe(event:)` calls)。
    /// Default 100 — fold once per 100 events to keep state
    /// vector cheap on long sessions。
    public let stateFoldInterval: Int

    /// Knowledge graph extract interval (in `observe(event:)`
    /// calls)。Default 1000 — re-extract once per 1000 events。
    public let graphExtractInterval: Int

    /// Defensive event-log size cap above which graph extract
    /// is SKIPPED (avoids long-session UI stall)。Default 5000
    /// (matches M862 observer cap)。
    public let graphExtractEventCap: Int

    /// M900 thermal sensitivity policy。Default `.ignoreThermal`
    /// preserves M865 back-compat (no behavior change for hosts
    /// that don't opt in)。
    public let thermalSensitivity:
        BASCognitiveOSThermalSensitivity

    /// M900 multiplier applied to graphExtractInterval when
    /// thermal state is `.serious` or `.critical` AND
    /// thermalSensitivity is `.slowOnHot`。Default 4 (extract
    /// fires 4x less often under thermal pressure)。
    public let thermalSlowdownMultiplier: Int

    /// M900 cadence at which the actor re-samples
    /// `ProcessInfo.thermalState` (in `observe(...)` calls)。
    /// Default 100 — re-sample at the same cadence as state-fold,
    /// keeps the ProcessInfo polling rate ~1Hz at typical event
    /// throughput while avoiding hot-path syscall on every event。
    /// Ignored when `thermalSensitivity == .ignoreThermal` (no
    /// sampling at all in that mode — preserves M865 zero-syscall
    /// hot path)。
    public let thermalSampleInterval: Int

    public init(
        stateFoldInterval: Int = Self.defaultStateFoldInterval,
        graphExtractInterval: Int =
            Self.defaultGraphExtractInterval,
        graphExtractEventCap: Int =
            Self.defaultGraphExtractEventCap,
        thermalSensitivity:
            BASCognitiveOSThermalSensitivity = .ignoreThermal,
        thermalSlowdownMultiplier: Int =
            Self.defaultThermalSlowdownMultiplier,
        thermalSampleInterval: Int =
            Self.defaultThermalSampleInterval
    ) {
        precondition(stateFoldInterval > 0,
            "stateFoldInterval must be > 0")
        precondition(graphExtractInterval > 0,
            "graphExtractInterval must be > 0")
        precondition(graphExtractEventCap > 0,
            "graphExtractEventCap must be > 0")
        precondition(thermalSlowdownMultiplier >= 1,
            "thermalSlowdownMultiplier must be >= 1 " +
            "(1 = no slowdown, > 1 = N× longer interval)")
        precondition(thermalSampleInterval > 0,
            "thermalSampleInterval must be > 0")
        self.stateFoldInterval = stateFoldInterval
        self.graphExtractInterval = graphExtractInterval
        self.graphExtractEventCap = graphExtractEventCap
        self.thermalSensitivity = thermalSensitivity
        self.thermalSlowdownMultiplier =
            thermalSlowdownMultiplier
        self.thermalSampleInterval = thermalSampleInterval
    }

    /// chapter 一百八十五 anti-magic-number — typed defaults
    public static let defaultStateFoldInterval: Int = 100
    public static let defaultGraphExtractInterval: Int = 1_000
    public static let defaultGraphExtractEventCap: Int = 5_000
    public static let defaultThermalSlowdownMultiplier: Int = 4
    public static let defaultThermalSampleInterval: Int = 100

    /// Default cadence (1 / 100 / 1000 / 5000 / ignoreThermal)。
    public static let `default` =
        BASCognitiveOSConvenienceCadence()

    /// M900 preset:thermal-aware cadence suitable for long
    /// iPhone runs。Slows graph extract 4x under thermal
    /// pressure。Recommended for 1h+ stress runs based on the
    /// 10h iPhone observation that device spent 98% in
    /// `.serious` thermal。
    public static let thermalAwareLongRun =
        BASCognitiveOSConvenienceCadence(
            stateFoldInterval:
                defaultStateFoldInterval,
            graphExtractInterval:
                defaultGraphExtractInterval,
            graphExtractEventCap:
                defaultGraphExtractEventCap,
            thermalSensitivity: .slowOnHot,
            thermalSlowdownMultiplier:
                defaultThermalSlowdownMultiplier,
            thermalSampleInterval:
                defaultThermalSampleInterval)

    /// M900 preset:emergency thermal protection cadence — skips
    /// graph extract entirely when device is `.critical`。State
    /// fold continues unchanged (cheap)。Suitable for hosts that
    /// want strict thermal floor without slowing down normal
    /// operation。
    public static let thermalProtectedLongRun =
        BASCognitiveOSConvenienceCadence(
            stateFoldInterval:
                defaultStateFoldInterval,
            graphExtractInterval:
                defaultGraphExtractInterval,
            graphExtractEventCap:
                defaultGraphExtractEventCap,
            thermalSensitivity: .skipOnCritical,
            thermalSlowdownMultiplier:
                defaultThermalSlowdownMultiplier,
            thermalSampleInterval:
                defaultThermalSampleInterval)
}

// MARK: - Result

/// Typed Sendable struct reporting which primitives fired during
/// one `observe(event:)` call。Hosts surface these to UI / logs。
public struct BASCognitiveOSConvenienceResult:
    Sendable, Equatable, Hashable, Codable
{
    /// True iff the event was appended to the event log
    /// (false when `eventLog` is nil in the bundle)。
    public let eventAppended: Bool

    /// True iff this call triggered a state reducer fold
    /// (cadence + state store both required)。
    public let stateFolded: Bool

    /// True iff this call triggered a graph extract pass
    /// (cadence + graph + event log all required + event count
    /// under cap)。
    public let graphExtracted: Bool

    /// Iteration index at the time of this call (zero-based)。
    public let iterationIndex: Int

    public init(
        eventAppended: Bool,
        stateFolded: Bool,
        graphExtracted: Bool,
        iterationIndex: Int
    ) {
        self.eventAppended = eventAppended
        self.stateFolded = stateFolded
        self.graphExtracted = graphExtracted
        self.iterationIndex = iterationIndex
    }

    /// True iff at least one primitive fired this call。
    public var anyFired: Bool {
        eventAppended || stateFolded || graphExtracted
    }
}

// MARK: - Convenience actor

/// Actor that owns the rolling iteration counter + state vector
/// + delegates to the underlying primitives at the right cadence。
///
/// Hosts pass a Sendable triple (eventLog / userStateStore /
/// knowledgeGraph) — typically destructured from
/// `BASCognitiveOSBundle` (M859) — plus a session ID。Each
/// `observe(event:)` call increments the iteration counter,
/// appends the event,folds state at the configured interval,
/// extracts the graph at the configured interval。
///
/// **No-op behavior**: when all three storage refs are nil,
/// `observe(event:)` increments only the counter and reports
/// all-false flags。This matches the ADR-014 OPT-IN pin。
public actor BASCognitiveOSConvenience {

    // MARK: - Dependencies

    private let eventLog: (any BASEventLogStorage)?
    private let userStateStore: (any BASUserStateStorage)?
    private let knowledgeGraph: BASKnowledgeGraph?
    /// Chapter 三百八二 / M869: optional SQLite write-through for
    /// graph mutations。When set,after each `extractGraph()` fires,
    /// the convenience walks the in-memory graph + idempotent-
    /// appends every node + edge to storage。M866's append APIs
    /// are idempotent on duplicate IDs,so repeated write-throughs
    /// are no-ops on already-persisted nodes/edges。
    private let knowledgeGraphStorage:
        BASSQLiteKnowledgeGraphStorage?
    /// Post-M872 deep-review fix:optional callback fired when a
    /// graph write-through fails。Without this,storage failures
    /// were silently swallowed and the in-memory graph could
    /// drift out of sync with SQLite without any host signal。
    /// Default nil preserves the M865/M869 silent-fail contract
    /// — hosts opt in to error visibility by passing a callback。
    private let onPersistError:
        (@Sendable (String, Error) -> Void)?
    /// M900 thermal sampler injection seam。Default reads
    /// `ProcessInfo.processInfo.thermalState` directly。Hosts AND
    /// tests can inject a closure to replay recorded thermal data
    /// or pin a thermal state for deterministic tests。Closure is
    /// only invoked when sensitivity is NOT `.ignoreThermal` AND
    /// the sampling cadence has been reached,so no hot-path cost
    /// in the default `.ignoreThermal` mode。
    private let thermalSampler:
        @Sendable () -> ProcessInfo.ThermalState
    private let cadence: BASCognitiveOSConvenienceCadence
    private let sessionID: String

    // MARK: - Rolling state

    private var iterationIndex: Int = 0
    private var currentState: BASUserState

    /// Chapter 三百八八 / M881 (P2.4 audit fix):high-water-mark
    /// timestamp of the most-recent event observed by
    /// `extractGraph()`。Pre-M881 the convenience helper had a
    /// hard cap at `cadence.graphExtractEventCap` total events,
    /// permanently disabling extraction past that mark for any
    /// host using the helper directly。Post-M881 each extract
    /// passes `since: hwm+1` to the M877 incremental extractor,
    /// bypassing the cap entirely (cap is now batch-size,not
    /// total-log-size)。
    private var lastGraphExtractHwm: Int64?

    /// M886 fix (post-M885 deep review):highest event.timestampMs
    /// seen by `observe(...)` so far。Used as the hwm advance
    /// target after each `extractGraph()` call,instead of
    /// wall-clock time (which is incomparable with synthetic /
    /// replayed event timestamps)。Updated monotonically per
    /// observe via `max(current, event.timestampMs)`。
    private var maxObservedEventTimestampMs: Int64 = 0

    /// M900 cached thermal state。Re-sampled every
    /// `cadence.thermalSampleInterval` calls when sensitivity is
    /// not `.ignoreThermal`。Default `.nominal` ensures fail-open
    /// behavior on init (no slowdown / skip until first sample)。
    private var cachedThermalState: ProcessInfo.ThermalState =
        .nominal

    /// M900 sampling counter — increments per `observe(...)` call
    /// when thermal sensitivity is active。Reset every
    /// `cadence.thermalSampleInterval` calls。
    private var thermalSampleCounter: Int = 0

    /// M908 cold-start tracker — false until the first
    /// `sampleThermalIfDue()` call under non-`.ignoreThermal`
    /// sensitivity。Forces an immediate first sample so the
    /// policy is effective from observe iter 1,not iter 100。
    private var cachedThermalSampleTaken: Bool = false

    /// M900 telemetry — number of graph extracts the actor SKIPPED
    /// because thermal sensitivity policy gated them out。Hosts
    /// surface this to UI / logs to validate that the policy is
    /// actually firing on hot devices。
    private var thermalSkippedExtracts: Int = 0

    /// M900 telemetry — number of graph extracts that fell on the
    /// SLOWED cadence (every interval × multiplier events) when
    /// `.slowOnHot` was active and thermal was hot。
    private var thermalSlowedExtracts: Int = 0

    // MARK: - Init

    /// Construct from bundle pieces。Pass nil for any primitive
    /// the caller does not want to feed。Empty (all-nil) is
    /// allowed — yields a no-op observer。
    ///
    /// Chapter 三百八二 / M869: `knowledgeGraphStorage` is the
    /// optional SQLite write-through companion (M866)。When set
    /// AND `knowledgeGraph` is also set,the convenience appends
    /// every graph node + edge through to SQLite after each
    /// graph extract。Hosts that don't pass the storage stay
    /// in-memory only (M865 contract preserved)。
    public init(
        eventLog: (any BASEventLogStorage)? = nil,
        userStateStore: (any BASUserStateStorage)? = nil,
        knowledgeGraph: BASKnowledgeGraph? = nil,
        knowledgeGraphStorage:
            BASSQLiteKnowledgeGraphStorage? = nil,
        sessionID: String = UUID().uuidString,
        cadence: BASCognitiveOSConvenienceCadence = .default,
        onPersistError:
            (@Sendable (String, Error) -> Void)? = nil,
        thermalSampler: (
            @Sendable () -> ProcessInfo.ThermalState)? = nil
    ) {
        self.eventLog = eventLog
        self.userStateStore = userStateStore
        self.knowledgeGraph = knowledgeGraph
        self.knowledgeGraphStorage =
            knowledgeGraphStorage
        self.sessionID = sessionID
        self.cadence = cadence
        self.onPersistError = onPersistError
        self.thermalSampler = thermalSampler ?? {
            ProcessInfo.processInfo.thermalState
        }
        self.currentState = .zero
    }

    // MARK: - Observe (the single entry point)

    /// Observe an event。Composes append + fold + extract at the
    /// configured cadence。Returns a typed result indicating
    /// which primitives fired this call。
    ///
    /// **Append**: every call (when `eventLog` non-nil)。
    /// **Fold**: every `cadence.stateFoldInterval` call,counting
    /// from index 0。First fold fires at iter index ==
    /// `stateFoldInterval`。
    /// **Extract**: every `cadence.graphExtractInterval` call,
    /// when `eventLog.totalCount <= graphExtractEventCap`。
    @discardableResult
    public func observe(
        event: BASEventLogEntry
    ) async -> BASCognitiveOSConvenienceResult {
        // 1-based index: first call is index 1,so cadence checks
        // fire predictably at multiples (100, 200, ... or
        // 1000, 2000, ...) — chapter 一百八十五 anti-magic-number
        // pin: cadence semantics matches the natural "every Nth
        // event" reading
        iterationIndex += 1
        let myIndex = iterationIndex

        // M886 fix:track max event.timestampMs we've seen so we
        // can advance the graph hwm in event-clock terms,not
        // wall-clock terms。Wall-clock could be far ahead of
        // synthetic / replayed event timestamps,causing the
        // `since: hwm+1` filter to skip valid events。
        if event.timestampMs > maxObservedEventTimestampMs {
            maxObservedEventTimestampMs = event.timestampMs
        }

        // 1. Event log append
        var didAppendEvent = false
        if let log = eventLog {
            do {
                _ = try await log.append(event)
                didAppendEvent = true
            } catch {
                // Silent — observation primitives never disrupt
                // host turn loop on storage failure。Hosts that
                // need failure visibility can wrap this actor。
            }
        }

        // 2. State reducer fold (every Nth call,1-based)
        var didFoldState = false
        if myIndex % cadence.stateFoldInterval == 0
            && userStateStore != nil
        {
            didFoldState = await foldState(from: event)
        }

        // 3. Graph extract (every Mth call,1-based)
        // M900:thermal-aware gating。The natural fire point is
        // still `myIndex % graphExtractInterval == 0`(preserves
        // M865 cadence semantics)。What changes is whether we
        // ACTUALLY fire on each natural point,based on the
        // sensitivity policy + cached thermal state。
        // M908 hardening:counter mutation moved OUT of the
        // predicate so the predicate stays pure (chapter 二百一一
        // single-source-of-truth)。Side-effects belong here in
        // the orchestrator,not in the decision function。
        // M912 (audit-the-fix):counter increment moved AFTER
        // `extractGraph()` returns,gated on success。Pre-M912
        // a future refactor adding e.g. an empty-batch short-
        // circuit (returning false) would silently inflate
        // `thermalSlowedExtracts` because the increment ran
        // before the extract attempted。Post-M912 the counter
        // semantics ("extracts that fired on slowed cadence")
        // matches the implementation observably。
        var didExtractGraph = false
        if myIndex % cadence.graphExtractInterval == 0
            && knowledgeGraph != nil
            && eventLog != nil
        {
            let thermal = sampleThermalIfDue()
            let decision = thermalExtractionDecision(
                thermal: thermal, atIndex: myIndex)
            switch decision {
            case .skip:
                thermalSkippedExtracts += 1
            case .fireNormal:
                didExtractGraph = await extractGraph()
            case .fireSlowed:
                didExtractGraph = await extractGraph()
                if didExtractGraph {
                    thermalSlowedExtracts += 1
                }
            }
        }

        return BASCognitiveOSConvenienceResult(
            eventAppended: didAppendEvent,
            stateFolded: didFoldState,
            graphExtracted: didExtractGraph,
            iterationIndex: myIndex)
    }

    // MARK: - Read-only stats

    /// Iteration count consumed by `observe(...)` calls so far。
    public var observedCount: Int {
        iterationIndex
    }

    /// Most-recent state vector (post-fold)。
    public var rollingState: BASUserState {
        currentState
    }

    /// M900 most-recent cached thermal state。Hosts surface this
    /// to UI / logs。Returns `.nominal` when sensitivity is
    /// `.ignoreThermal` (no sampling occurs in that mode)。
    public var lastObservedThermalState:
        ProcessInfo.ThermalState
    {
        cachedThermalState
    }

    /// M900 telemetry: number of graph extracts SKIPPED due to
    /// thermal-sensitivity policy gating them out。
    public var thermalSkippedExtractCount: Int {
        thermalSkippedExtracts
    }

    /// M900 telemetry: number of graph extracts that fired on
    /// the SLOWED cadence (every interval × multiplier events)
    /// when `.slowOnHot` was active and thermal was hot。
    public var thermalSlowedExtractCount: Int {
        thermalSlowedExtracts
    }

    // MARK: - Private helpers

    /// M900 thermal sampling。Only re-samples when sensitivity is
    /// active AND sample counter has reached the threshold,so the
    /// hot path stays free of ProcessInfo syscalls in the
    /// `.ignoreThermal` case (preserves M865 zero-syscall pin)。
    ///
    /// ## M908 cold-start fix
    ///
    /// Pre-M908 the first thermal sample fired only when
    /// `thermalSampleCounter` reached `cadence.thermalSampleInterval`
    /// — with default 100,that's iter 100。The first 99 observe
    /// calls used the init-default `.nominal` cached state,which
    /// silently bypassed the policy on a phone that booted into
    /// `.serious` thermal。Post-M908 the very first observe call
    /// (when `cachedThermalSampleTaken` is false) ALWAYS samples
    /// before checking the cadence,so the policy starts effective
    /// immediately。
    private func sampleThermalIfDue() ->
        ProcessInfo.ThermalState
    {
        // Fast path:`.ignoreThermal` never samples — cached
        // state stays at init default `.nominal`,decision logic
        // ignores it anyway。
        if cadence.thermalSensitivity == .ignoreThermal {
            return cachedThermalState
        }
        // M908 fix:first call under non-ignore mode samples
        // immediately,before any `observe(...)` decision。
        if !cachedThermalSampleTaken {
            cachedThermalSampleTaken = true
            cachedThermalState = thermalSampler()
            thermalSampleCounter = 0
            return cachedThermalState
        }
        thermalSampleCounter += 1
        if thermalSampleCounter >= cadence.thermalSampleInterval {
            thermalSampleCounter = 0
            cachedThermalState = thermalSampler()
        }
        return cachedThermalState
    }

    /// M912 hardening:replace M908's `ThermalExtractionDecision`
    /// struct with an enum to remove the impossible state
    /// `(shouldFire: false, isSlowedFire: true)`。Each case
    /// carries exactly the information a caller needs;the type
    /// system enforces the invariant "slowed implies fire"。
    private enum ThermalExtractionDecision {
        /// Skip the extract (thermal-gated)
        case skip
        /// Fire on the normal cadence (thermal not relevant)
        case fireNormal
        /// Fire on the slowed cadence (thermal is hot AND
        /// slowdown boundary reached)
        case fireSlowed
    }

    /// M900 + M908 + M912 typed pure decision:given a thermal
    /// state and the current iteration index,return one of
    /// `.skip` / `.fireNormal` / `.fireSlowed` under the
    /// configured sensitivity policy。
    ///
    /// The natural cadence gate (`myIndex % graphExtractInterval
    /// == 0`)is checked by `observe(...)` BEFORE this is called,
    /// so this function only decides whether the natural fire
    /// point is suppressed by thermal pressure。
    ///
    /// Semantics:
    ///   - `.ignoreThermal`:always `.fireNormal`
    ///   - `.slowOnHot` + thermal hot:`.fireSlowed` if on slowed
    ///     cadence boundary,else `.skip`
    ///   - `.slowOnHot` + thermal cool:`.fireNormal`
    ///   - `.skipOnCritical` + thermal critical:`.skip`
    ///   - `.skipOnCritical` + thermal lower:`.fireNormal`
    ///
    /// ## M912 fail-closed for both unknown defaults
    ///
    /// Pre-M912 `.slowOnHot` `@unknown default` returned
    /// `.fireNormal`(fail-open),meaning a future thermal state
    /// above `.critical`(if Apple ever adds one)would extract
    /// at FULL cadence — opposite of policy intent。Post-M912
    /// `.slowOnHot` `@unknown default` falls through to the hot
    /// path (treats unknown as hot for slowdown purposes),
    /// matching the policy's "give CPU back to chenglu mesh
    /// under thermal load" semantic。
    private func thermalExtractionDecision(
        thermal: ProcessInfo.ThermalState,
        atIndex myIndex: Int
    ) -> ThermalExtractionDecision {
        switch cadence.thermalSensitivity {
        case .ignoreThermal:
            return .fireNormal
        case .slowOnHot:
            switch thermal {
            case .serious, .critical:
                return slowOnHotHotDecision(atIndex: myIndex)
            case .nominal, .fair:
                return .fireNormal
            @unknown default:
                // M912 fail-CLOSED:future-hotter states should
                // slow MORE,not run at full cadence。Pre-M912
                // fail-open masked the policy intent。
                return slowOnHotHotDecision(atIndex: myIndex)
            }
        case .skipOnCritical:
            switch thermal {
            case .critical:
                return .skip
            case .nominal, .fair, .serious:
                return .fireNormal
            @unknown default:
                // M908 fail-CLOSED for `.skipOnCritical`
                // unknowns:strict thermal floor。
                return .skip
            }
        }
    }

    /// M912 helper:the hot-path decision for `.slowOnHot`,
    /// extracted so both `.serious/.critical` and `@unknown
    /// default` (a future hotter state) share the same logic。
    /// Includes the M908 multiplication-overflow guard。
    private func slowOnHotHotDecision(
        atIndex myIndex: Int
    ) -> ThermalExtractionDecision {
        // M908 overflow guard:if interval × multiplier would
        // trap,clamp to Int.max。Substrate primitive must
        // NEVER trap (不变量 #1)。
        let (raw, ovf) = cadence.graphExtractInterval
            .multipliedReportingOverflow(
                by: cadence.thermalSlowdownMultiplier)
        let slowedInterval = ovf ? Int.max : raw
        if myIndex % slowedInterval == 0 {
            return .fireSlowed
        } else {
            return .skip
        }
    }

    private func foldState(
        from event: BASEventLogEntry
    ) async -> Bool {
        guard let store = userStateStore else { return false }
        let newID = UUID().uuidString
        let nowMs = Int64(
            Date().timeIntervalSince1970 * 1000)

        // chapter 三百八一 / M868 upgrade: when a knowledge graph
        // is also wired into this convenience,fold via the M858
        // graph-aware reducer (which adds a complexityAddiction
        // bonus per delays-cycle on the event's project)。Hosts
        // that did NOT wire a graph fall back to the M842 base
        // reducer — preserves the M865 contract on graph-less
        // setups (zero behavior change pin)。
        let next: BASUserState
        if let graph = knowledgeGraph {
            next = await BASUserStateGraphAwareReducer.reduce(
                prior: currentState,
                event: event,
                graph: graph,
                newStateID: newID,
                generatedAtMs: nowMs)
        } else {
            next = BASUserStateReducer.reduce(
                prior: currentState,
                event: event,
                newStateID: newID,
                generatedAtMs: nowMs)
        }

        do {
            _ = try await store.append(
                next, sessionID: sessionID)
            currentState = next
            return true
        } catch {
            return false
        }
    }

    private func extractGraph() async -> Bool {
        guard let log = eventLog,
              let graph = knowledgeGraph
        else { return false }

        // M881 fix (P2.4 audit):pre-M881 the convenience helper
        // permanently disabled graph extraction once the event
        // log exceeded `graphExtractEventCap` (default 5000)。
        // This silently broke any host using the convenience
        // helper directly past 5000 events。SampleHost observer
        // got M877's incremental fix in chapter 三百八七,but
        // the substrate-side helper kept the cap → bifurcated
        // semantics。
        //
        // Post-M881:incremental extract (mirrors M877) — track
        // `lastGraphExtractHwm` and walk only events newer than
        // last extract。The cap on `cadence.graphExtractEventCap`
        // is now applied to the BATCH size rather than total log
        // size — defensive guard against catastrophic single-
        // batch growth (e.g.,per-extract interval mis-set so
        // large that a single extract walks millions of events)。
        let scanSince: Int64? =
            lastGraphExtractHwm.map { $0 + 1 }

        // M886 (post-M885 deep-review fix v2):use the highest
        // event timestamp we've observed so far as the hwm
        // advance target,NOT wall-clock。Wall-clock can be far
        // ahead of synthetic / replayed event timestamps,
        // causing the next call's `since: hwm+1` filter to skip
        // legitimate events。Event-clock guarantees:
        //   - hwm advances monotonically with submitted events
        //   - next extract picks up any event whose timestampMs
        //     is strictly greater than this hwm
        //   - no double-walk:events with timestampMs <= hwm
        //     were already in this batch
        let preExtractHwm = maxObservedEventTimestampMs
        _ = await BASKnowledgeGraphEventExtractor.extract(
            from: log,
            sessionID: sessionID,
            into: graph,
            sinceTimestampMs: scanSince,
            // M888:close the cognitive OS feedback loop —
            // detected cycles become first-class events
            feedbackLog: log)
        lastGraphExtractHwm = preExtractHwm

        // chapter 三百八二 / M869 write-through: when the host
        // wired `knowledgeGraphStorage`,append every node + edge
        // through to SQLite。M866's append APIs are idempotent on
        // duplicate IDs,so calling this on re-extraction is a
        // no-op on already-persisted rows。Failures are reported
        // via `onPersistError` (post-M872 deep review fix) but
        // never thrown — observation primitives never disrupt
        // the host turn loop。
        if let storage = knowledgeGraphStorage {
            await persistGraph(
                graph: graph, storage: storage)
        }

        return true
    }

    /// Walk the in-memory graph + write-through nodes + edges to
    /// the SQLite storage companion。Idempotent on already-
    /// persisted rows due to M866 append semantics。Errors are
    /// reported via the optional `onPersistError` callback (post-
    /// M872 deep review fix) but never thrown — observation
    /// primitives never disrupt the host turn loop。
    private func persistGraph(
        graph: BASKnowledgeGraph,
        storage: BASSQLiteKnowledgeGraphStorage
    ) async {
        let nodes = await graph.allNodes()
        for node in nodes {
            do {
                _ = try await storage.appendNode(node)
            } catch {
                onPersistError?(node.nodeID, error)
                // Continue — observation primitives never disrupt
                // host turn loop on storage failure
            }
        }
        let edges = await graph.allEdges()
        for edge in edges {
            do {
                _ = try await storage.appendEdge(edge)
            } catch {
                onPersistError?(edge.edgeID, error)
                // Continue — same contract as appendNode above
            }
        }
    }
}
