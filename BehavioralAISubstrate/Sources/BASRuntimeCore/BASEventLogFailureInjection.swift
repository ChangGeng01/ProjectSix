// MARK: - BASEventLogFailureInjection — chapter 三百九九 / M902
//
// Typed substrate primitive for synthesizing event sequences
// that exercise the cognitive OS DETECTION + REPAIR pathways
// (graph extractor heuristics 3/4/5/6/7) without needing a
// real-world failure to occur。
//
// ## Why this exists (10h iPhone run data drives this)
//
// The 10h chenglu mesh stress run completed 2,734,001
// iterations across 600 minutes with 0 failures。The cognitive
// OS observer captured all 2.73M events,but the knowledge
// graph extracted ZERO `delays` edges and ZERO `contradicts`
// edges — because the chenglu mesh was too reliable to actually
// trigger those heuristics in the wild。
//
// Result: a critical observability gap。The substrate has the
// detection plumbing (M857-M894 heuristics) but no real-world
// data exercises it。Same gap blocks future P3 G12 auto eval
// harness training data + ChengluMemory_v0 corpus generation
// (M903 will consume this primitive)。
//
// M902 closes the gap with a typed FIXTURE primitive that
// generates synthetic event sequences for each scenario:
//   - delays cycle (heuristic 3)
//   - contradiction pair (heuristic 4)
//   - thermal pressure spike (heuristic 5)
//   - complexity addiction loop (user vision §10 — composite
//     pattern combining 3 + 4 + 7)
//
// Hosts opt in to inject these for:
//   - integration tests that need realistic graph data
//   - training-data corpus generation (M903 export)
//   - smoke tests of the cognitive OS detection paths
//
// ## What this ships
//
//   - `BASEventLogFailureInjectionScenario` typed enum cataloguing
//     the available scenarios
//   - `BASEventLogFailureInjection` namespace with pure
//     `generate(scenario:sessionID:startingAtMs:)` factory
//     returning `[BASEventLogEntry]`
//   - Caller appends the result to their event log via the
//     existing `BASEventLogStorage.append(_:)` API
//
// ## Doctrine pins held
//
// - 不变量 #1 / #2 / #3 全保 — injection is observation;does NOT
//   mutate permits / verdicts / commit token
// - 红线 7 hint-only — synthesized events are HINTS to the
//   cognitive OS,not gating signals
// - chapter 二百一一 single-source-of-truth — ONE injection
//   primitive,all consumers route through this
// - chapter 一百八十五 anti-magic-number — every scenario param
//   typed,every default a named constant
// - ADR-014 OPT-IN — primitive only fires when caller invokes;
//   substrate behavior unchanged for hosts that don't use it
// - 单提交口 (L11/L14) 不变 — synthesized events feed gate, never
//   bypass

import Foundation

// MARK: - Scenarios

/// Typed catalog of failure-injection scenarios。Each scenario
/// targets a SPECIFIC graph extractor heuristic (M857-M894) so
/// callers can systematically exercise each detection path。
public enum BASEventLogFailureInjectionScenario:
    Sendable, Equatable, Codable
{
    /// Heuristic 3 (`action repeated → delays edge`)。
    /// Generates `repetitions` invocations of `action` spaced
    /// `intervalMs` apart on the same project。Default
    /// `repetitions = 4` exceeds the M857 minimum of 3。
    case delaysCycle(
        action: String,
        project: String,
        repetitions: Int,
        intervalMs: Int64)

    /// Heuristic 4 (`failed action → contradicts edge`)。
    /// Generates one failed-action event followed by a retry
    /// or alternative action,producing the contradicts edge
    /// from the first to the second。
    case contradiction(
        failedAction: String,
        retryAction: String,
        project: String)

    /// Heuristic 5 (`thermal-high event → causes thermal-pressure
    /// node`)。Generates `eventCount` events tagged with the
    /// requested risk band — feeds the M894 thermal pressure
    /// detection path that the 10h iPhone run revealed but
    /// reality-tested with `.serious` only,never `.critical`。
    case thermalSpike(
        eventCount: Int,
        thermalBand: BASEventLogRiskBand,
        project: String)

    /// Composite scenario approximating user vision §10
    /// "complexity addiction loop": anxiety → add tech (action) →
    /// delay → anxiety → add MORE tech ... → cycle detected。
    /// Combines heuristics 3 + 4 + 7 + cycle detection (M888)。
    /// Used by integration tests + M903 training corpus to
    /// produce realistic full-feedback-loop event sequences。
    case complexityAddictionLoop(
        project: String,
        techActions: [String],
        cycleDepth: Int,
        intervalMs: Int64)
}

// MARK: - Injection namespace

/// Pure typed factory for synthesizing event-log entries that
/// exercise the cognitive OS detection paths。Caller appends
/// the returned `[BASEventLogEntry]` to their event log via
/// the existing storage `append(_:)` API。
public enum BASEventLogFailureInjection {

    /// chapter 一百八十五 anti-magic-number — typed defaults
    public static let defaultDelaysCycleRepetitions: Int = 4
    public static let defaultDelaysCycleIntervalMs: Int64 = 5_000
    public static let defaultThermalSpikeEventCount: Int = 10
    public static let defaultComplexityCycleDepth: Int = 3
    public static let defaultComplexityIntervalMs: Int64 = 30_000

    /// Generate the synthetic events for `scenario`。
    ///
    /// All events share `sessionID` and start at `startingAtMs`
    /// monotonically increasing by 1ms or by the scenario's own
    /// interval (whichever is larger)。`sequenceNumber` is set
    /// to 0 — caller's storage layer assigns the real sequence
    /// at append time per M735 SQLite idiom。
    ///
    /// The generator is PURE — same scenario + same starting
    /// timestamp produces identical eventID sequences (using a
    /// deterministic pseudo-UUID from `(sessionID,scenarioTag,
    /// index)`)。This matches M898 replay-runner determinism
    /// contract:replays of the same injected sequence produce
    /// identical graph state。
    public static func generate(
        scenario: BASEventLogFailureInjectionScenario,
        sessionID: String,
        startingAtMs: Int64
    ) -> [BASEventLogEntry] {
        switch scenario {
        case .delaysCycle(let action, let project,
                          let repetitions, let intervalMs):
            return generateDelaysCycle(
                action: action,
                project: project,
                repetitions: repetitions,
                intervalMs: intervalMs,
                sessionID: sessionID,
                startingAtMs: startingAtMs)
        case .contradiction(let failed, let retry, let project):
            return generateContradiction(
                failedAction: failed,
                retryAction: retry,
                project: project,
                sessionID: sessionID,
                startingAtMs: startingAtMs)
        case .thermalSpike(let count, let band, let project):
            return generateThermalSpike(
                eventCount: count,
                thermalBand: band,
                project: project,
                sessionID: sessionID,
                startingAtMs: startingAtMs)
        case .complexityAddictionLoop(let project, let actions,
                                      let depth, let intervalMs):
            return generateComplexityLoop(
                project: project,
                techActions: actions,
                cycleDepth: depth,
                intervalMs: intervalMs,
                sessionID: sessionID,
                startingAtMs: startingAtMs)
        }
    }

    // MARK: - Per-scenario implementations

    private static func generateDelaysCycle(
        action: String,
        project: String,
        repetitions: Int,
        intervalMs: Int64,
        sessionID: String,
        startingAtMs: Int64
    ) -> [BASEventLogEntry] {
        precondition(repetitions >= 1,
            "delays cycle needs at least 1 repetition")
        var out: [BASEventLogEntry] = []
        out.reserveCapacity(repetitions)
        for i in 0..<repetitions {
            let ts = startingAtMs + Int64(i) * intervalMs
            // Substrate alignment (chapter 三百八〇 / M857
            // heuristic 5):the extractor synthesizes `.delays`
            // edges from events whose actions list a `skip:*`
            // entry。Without the prefix,heuristic 5 doesn't
            // fire and the scenario fails its purpose。Carry
            // both the raw action AND the `skip:` form so
            // downstream consumers can still see the action
            // intent。
            out.append(BASEventLogEntry(
                eventID: deterministicID(
                    sessionID: sessionID,
                    tag: "delays-\(action)",
                    index: i),
                timestampMs: ts,
                kind: .substrateAudit,
                sessionID: sessionID,
                sequenceNumber: 0,
                source: "fault-injection:delays-cycle",
                riskBand: .medium,
                project: project,
                actions: [action, "skip:\(action)"],
                confidence: 0.85))
        }
        return out
    }

    private static func generateContradiction(
        failedAction: String,
        retryAction: String,
        project: String,
        sessionID: String,
        startingAtMs: Int64
    ) -> [BASEventLogEntry] {
        // M907 fix:heuristic 6 in M857 graph extractor fires
        // `.contradicts` edges ONLY on actions that EXACTLY
        // equal `permit:block` or `permit:replace` (extractor
        // BASKnowledgeGraphEventExtractor.swift:392-394)。
        // Pre-M907 the failed event emitted `outcome:fail` which
        // matched no heuristic — scenario produced 0 contradicts
        // edges,exactly the data-poverty gap M902 was meant to
        // close。Post-M907 the failed event includes
        // `permit:block` (the canonical "blocked / contradicted"
        // action) so heuristic 6 fires。Caller's failedAction
        // is preserved as a separate action for trace context。
        let failed = BASEventLogEntry(
            eventID: deterministicID(
                sessionID: sessionID,
                tag: "contradiction-fail-\(failedAction)",
                index: 0),
            timestampMs: startingAtMs,
            kind: .substrateAudit,
            sessionID: sessionID,
            sequenceNumber: 0,
            source: "fault-injection:contradiction",
            riskBand: .high,
            project: project,
            actions: [failedAction,
                      "permit:block",
                      "outcome:fail"],
            confidence: 0.90)
        // M907:retry event uses `permit:replace` — also a valid
        // heuristic 6 trigger,representing the "alternative
        // permit was chosen instead" semantics that the user
        // vision §10 contradiction loop captures。
        let retry = BASEventLogEntry(
            eventID: deterministicID(
                sessionID: sessionID,
                tag: "contradiction-retry-\(retryAction)",
                index: 1),
            timestampMs: startingAtMs + 1_000,
            kind: .substrateAudit,
            sessionID: sessionID,
            sequenceNumber: 0,
            source: "fault-injection:contradiction",
            riskBand: .medium,
            project: project,
            actions: [retryAction,
                      "permit:replace",
                      "outcome:retry"],
            confidence: 0.75)
        return [failed, retry]
    }

    private static func generateThermalSpike(
        eventCount: Int,
        thermalBand: BASEventLogRiskBand,
        project: String,
        sessionID: String,
        startingAtMs: Int64
    ) -> [BASEventLogEntry] {
        precondition(eventCount > 0,
            "thermal spike must generate at least 1 event")
        var out: [BASEventLogEntry] = []
        out.reserveCapacity(eventCount)
        for i in 0..<eventCount {
            // M911 fix:pre-M911 the thermal-spike scenario
            // emitted actions `["thermal:\(band)", "iter:\(i)"]`
            // — neither matched ANY M857 graph-extractor
            // heuristic。The riskBand field was set on the
            // entry but the extractor doesn't read riskBand
            // for edge synthesis,so the scenario produced
            // ZERO heuristic-specific edges,reducing it to
            // generic event-stream filler。
            // Post-M911 every event also carries
            // `skip:thermal-throttle` so heuristic 5 fires
            // `.delays` edges。This makes the scenario actually
            // exercise a unique detection path,closing the
            // M902 audit-finding gap that M907 left open。
            out.append(BASEventLogEntry(
                eventID: deterministicID(
                    sessionID: sessionID,
                    tag: "thermal-spike-\(thermalBand.rawValue)",
                    index: i),
                timestampMs: startingAtMs + Int64(i) * 100,
                kind: .substrateAudit,
                sessionID: sessionID,
                sequenceNumber: 0,
                source: "fault-injection:thermal-spike",
                riskBand: thermalBand,
                project: project,
                actions: [
                    "thermal:\(thermalBand.rawValue)",
                    "skip:thermal-throttle",
                    "iter:\(i)"
                ],
                confidence: 0.95))
        }
        return out
    }

    private static func generateComplexityLoop(
        project: String,
        techActions: [String],
        cycleDepth: Int,
        intervalMs: Int64,
        sessionID: String,
        startingAtMs: Int64
    ) -> [BASEventLogEntry] {
        precondition(!techActions.isEmpty,
            "complexity loop needs at least 1 tech action")
        // M911 fix:cycleDepth must be >= 2 to actually
        // synthesize a closing edge via heuristic 7 (which
        // requires `closingEdgeDelaysThreshold = 2` distinct
        // delays edges per project)。Pre-M911 cycleDepth=1
        // silently produced ONE delays edge but no closing
        // edge → no cycle → the documented "cycle detected"
        // semantic was structurally false。Tightening the
        // precondition matches the documented intent。
        precondition(cycleDepth >= 2,
            "complexity cycle depth must be >= 2 to trigger " +
            "heuristic-7 closing-edge synthesis (threshold 2)")
        // M911 fix:replace silent `max(intervalMs, 3_000)`
        // clamp with explicit precondition。Pre-M911 a caller
        // passing intervalMs=100 silently got 3000,which
        // surprises tests verifying tight-spaced event
        // distributions。Fail-fast is friendlier。
        precondition(intervalMs >= 3_000,
            "intervalMs must be >= 3000 (inner-cycle 3s span);" +
            " caller passed \(intervalMs)")
        // Each cycle iteration:
        //   1. anxiety event (intent: "anxious")
        //   2. tech-add event (one of techActions,rotating)
        //   3. delay event (interval gap encoded as separate
        //      event so heuristic 3 has explicit fuel)
        // After `cycleDepth` iterations the closing event
        // synthesized by extractor heuristic 7 closes the loop。
        var out: [BASEventLogEntry] = []
        out.reserveCapacity(cycleDepth * 3)
        var ts = startingAtMs
        for cycle in 0..<cycleDepth {
            let action = techActions[cycle % techActions.count]
            // anxiety
            out.append(BASEventLogEntry(
                eventID: deterministicID(
                    sessionID: sessionID,
                    tag: "complexity-anxiety-\(cycle)",
                    index: 0),
                timestampMs: ts,
                kind: .substrateAudit,
                sessionID: sessionID,
                sequenceNumber: 0,
                source: "fault-injection:complexity-loop",
                emotion: "anxious",
                riskBand: .medium,
                project: project,
                actions: ["affect:anxious"],
                confidence: 0.80))
            ts += 1_000
            // tech add
            out.append(BASEventLogEntry(
                eventID: deterministicID(
                    sessionID: sessionID,
                    tag: "complexity-tech-\(cycle)-\(action)",
                    index: 0),
                timestampMs: ts,
                kind: .substrateAudit,
                sessionID: sessionID,
                sequenceNumber: 0,
                source: "fault-injection:complexity-loop",
                riskBand: .medium,
                project: project,
                actions: ["add-tech:\(action)"],
                confidence: 0.85))
            ts += 1_000
            // M907 fix:heuristic 5 fires `.delays` edges on
            // `skip:*` action prefixes (extractor
            // BASKnowledgeGraphEventExtractor.swift:357)。
            // Pre-M907 the action `["delay-marker"]` matched no
            // heuristic → zero `.delays` edges → heuristic 7
            // closing-edge synthesis never fired → cycle
            // detection never fired → the documented
            // "complexity addiction loop → cycle detected"
            // composition was structurally false。Post-M907 the
            // action `["skip:delay-marker"]` triggers heuristic 5
            // per cycle iteration → projectToDelaysCount accrues
            // → with cycleDepth >= 2,closingEdgeDelaysThreshold
            // (= 2) trips → heuristic 7 synthesizes closing edge
            // → cycle is detectable on extractor pass。
            out.append(BASEventLogEntry(
                eventID: deterministicID(
                    sessionID: sessionID,
                    tag: "complexity-delay-\(cycle)",
                    index: 0),
                timestampMs: ts,
                kind: .substrateAudit,
                sessionID: sessionID,
                sequenceNumber: 0,
                source: "fault-injection:complexity-loop",
                riskBand: .high,
                project: project,
                actions: ["skip:delay-marker",
                          "delay-marker"],
                confidence: 0.70))
            // M911:precondition above guarantees intervalMs
            // >= 3_000,so timestamps stay monotonic across
            // cycles without the silent `max` clamp。
            ts += intervalMs
        }
        return out
    }

    // MARK: - Helpers

    /// Produce a deterministic-but-unique event ID for the
    /// (sessionID,tag,index) triple。Hex-encodes a SHA-style
    /// counter so the same scenario+session yields identical
    /// IDs across runs (chapter 三百九二 / M892 replay
    /// determinism doctrine)。Output stays under 64 chars to
    /// stay friendly to UUID-shaped storage columns。
    ///
    /// ## M907 fix:length-prefixed encoding
    ///
    /// Pre-M907 used `"\(sessionID)|\(tag)|\(index)"` as the
    /// hash input。If `sessionID` or `tag` contained `|` (and
    /// `tag` does — line 210 embeds caller-supplied `action`),
    /// the input space could alias:
    ///   ("a|b","c",1) and ("a","b|c",1) → same hash → same
    ///   eventID → second `append` returns wasNew=false →
    ///   silent event loss。
    /// Post-M907 each component carries its UTF-8 byte length
    /// as a prefix,so two components cannot alias regardless
    /// of content。
    private static func deterministicID(
        sessionID: String,
        tag: String,
        index: Int
    ) -> String {
        // Length-prefixed encoding prevents `|`-injection
        // collisions:
        //   "12:sessionLikeID7:tag-foo:42"
        //   not    "sessionLikeID|tag-foo|42"
        let combined =
            "\(sessionID.utf8.count):\(sessionID)" +
            "\(tag.utf8.count):\(tag)" +
            "\(index)"
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in combined.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x100000001b3
        }
        return "fi-\(String(hash, radix: 16))-\(index)"
    }
}
