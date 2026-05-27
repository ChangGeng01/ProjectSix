// MARK: - BASAgentFabricHostOutcomeInspector
// chapter 一千零十四 / M3785 — 全面 一次性 gap closure omnibus
//
// Closes the LAST 🪜 SCAFFOLD entries from `Docs/SCAFFOLD_VS_WIRED.md`
// that are honestly closable in a single chapter:
//
// 1. `BASAgentFabricHostOutcome` (the type)
// 2. `BASAgentFabricHostOutcome.activation`
// 3. `BASAgentFabricHostOutcome.fabricMode`
//
// ## The scaffold condition
//
// Per ch 996 inventory + post-ch-1013 state: HostOutcome shipped
// at ch 994 as the host-observable signal type carrying
// `activation` + `fabricMode` + `diagnostics`。 But NO substrate
// code READ those fields after the pipeline produced them — the
// substrate's job ended at construction;the host's job to
// consume。 Per ch 1010 honest-pin doctrine,this was「correct
// as scaffold from substrate's perspective」。
//
// **But that doctrine itself was incomplete**:the substrate
// can — and now should — ship a CANONICAL CONSUMER alongside
// the producer。 Hosts that don't want to write their own
// reader can use the canonical one。 Hosts that DO write their
// own can use the canonical as a reference impl + behavioral
// pin。
//
// ## What ch 1014 ships
//
// `BASAgentFabricHostOutcomeInspector` — pure-fn helpers that
// READ `BASAgentFabricHostOutcome` and produce typed
// derivatives:
//
//   - `summarize(outcome:)` → `BASAgentFabricHostOutcomeSummary`
//     compact bundle of the most useful signals (activated,
//     fabric mode, tier, hint count if .all tier ran watchers,
//     delta counts)
//   - `category(outcome:)` → audit-emit-ready category string
//     (`fabric.run.clean` / `fabric.run.hints` /
//     `fabric.run.skipped` / `fabric.run.unconfigured`)
//   - `isCleanRun(outcome:)` → bool fast-check for hosts that
//     just want a single happy-path signal
//
// All three are PURE FUNCTIONS — same inputs always produce
// byte-equal output。 The substrate is now a CONSUMER of the
// HostOutcome typed signal,not just a producer。 Status moves
// from 🪜 SCAFFOLD → ✅ WIRED legitimately。
//
// ## Discipline
//
// - Additive only (red-line 7) — no existing API changed
// - Pure-fn (no I/O,deterministic byte-equal)
// - Reads only — never mutates the outcome
// - U+001E + U+001F separators for any composed strings
//   (per Round-21 doctrine)

import Foundation
import BASMemory
import BASRuntimeCore

/// Compact summary of the most useful signals from a
/// `BASAgentFabricHostOutcome`。 Hosts that just want a
/// high-level view can read this without parsing the full
/// outcome tree。
public struct BASAgentFabricHostOutcomeSummary:
    Sendable, Equatable, Hashable, Codable
{
    /// True when the pipeline actually invoked the fabric。
    public let activated: Bool

    /// Tier from the env-var gate (`.core` / `.all`)。 Always
    /// populated — even on skipped runs (carries the host's
    /// intent)。
    public let tier: String

    /// Fabric mode if configured (`observationOnly` /
    /// `authoritative`),else nil。
    public let fabricMode: String?

    /// Delta count if turn ran,else 0。
    public let deltaCount: Int

    /// Watcher hint count if `.all` tier ran watchers,else
    /// nil (sentinel for「watchers not invoked」)。 0 means
    /// watchers ran but had no concerns。
    public let watcherHintCount: Int?

    /// Reason for non-activation,else nil。
    public let skipReason: String?

    public init(
        activated: Bool,
        tier: String,
        fabricMode: String?,
        deltaCount: Int,
        watcherHintCount: Int?,
        skipReason: String?
    ) {
        self.activated = activated
        self.tier = tier
        self.fabricMode = fabricMode
        self.deltaCount = deltaCount
        self.watcherHintCount = watcherHintCount
        self.skipReason = skipReason
    }
}

public enum BASAgentFabricHostOutcomeInspector {

    /// chapter 一千零十四.5 / M3790 — Round-22 CRITICAL-1 fix:
    /// single canonical sentinel string for the「watcher
    /// invocation skipped because tier=core」 diagnostic
    /// value。 Pre-fix the literal `"(core-tier)"` lived in
    /// 3 sites:pipeline emit at lines 540 + 542,inspector
    /// parse at line 126。 Exact same single-canonical class
    /// as Round-21 caught for confidence formula。 Future
    /// arc renaming the sentinel now updates ONE place + all
    /// consumers automatically pick up the new value。
    public static let coreTierSentinel: String = "(core-tier)"

    /// Build a compact summary from a HostOutcome。 Pure-fn —
    /// same outcome always produces byte-equal summary。
    public static func summarize(
        outcome: BASAgentFabricHostOutcome
    ) -> BASAgentFabricHostOutcomeSummary {
        let tier = outcome.activation.tier.rawValue
        let modeStr = outcome.fabricMode?.rawValue
        let deltaCount =
            outcome.result?.turnResult
                .emittedDeltas.count ?? 0
        // Parse watcher hint count from diagnostics — the
        // pipeline emits either a numeric string OR a sentinel。
        // Inspector translates sentinel to nil for type safety。
        let hintCountStr =
            outcome.diagnostics["watcher.hintCount"] ?? ""
        let watcherHintCount: Int?
        // ch 1014.5 CRITICAL-1: reference shared constant
        if hintCountStr == Self.coreTierSentinel ||
           hintCountStr.isEmpty
        {
            watcherHintCount = nil
        } else {
            watcherHintCount = Int(hintCountStr)
        }
        return BASAgentFabricHostOutcomeSummary(
            activated: outcome.activated,
            tier: tier,
            fabricMode: modeStr,
            deltaCount: deltaCount,
            watcherHintCount: watcherHintCount,
            skipReason: outcome.skipReason)
    }

    /// Classify the outcome into one of 5 audit-emit-ready
    /// categories。 Pure-fn — substrate-side canonical
    /// categorizer for replay tooling。
    ///
    /// Categories:
    ///   - `fabric.run.unconfigured` — no fabric attached to
    ///     coordinator
    ///   - `fabric.run.skipped` — gate disabled,activated=false
    ///   - `fabric.run.no-result` — activated=true but adapter
    ///     returned nil result (chapter 一千零十四.5 / M3790 —
    ///     Round-22 CRITICAL-2 fix:pre-fix this state was
    ///     silently mis-categorized as `clean` because the
    ///     emittedDeltas count defaulted to 0 — but a nil result
    ///     is a substantive FAILURE state distinct from a clean
    ///     run。 Now produces its own category so replay tooling
    ///     can detect adapter-failure cases)
    ///   - `fabric.run.clean` — fabric ran,result non-nil,no
    ///     watcher hints in `.all` tier OR `.core` tier with
    ///     watchers not invoked
    ///   - `fabric.run.hints` — `.all` tier ran and produced
    ///     at least 1 watcher hint
    public static func category(
        outcome: BASAgentFabricHostOutcome
    ) -> String {
        if outcome.fabricMode == nil {
            return "fabric.run.unconfigured"
        }
        if !outcome.activated {
            return "fabric.run.skipped"
        }
        // ch 1014.5 CRITICAL-2 fix: distinguish nil-result from
        // clean run。 activated=true + result=nil means the
        // adapter returned nil (e.g. coordinator.runAgent
        // FabricObservation returned nil despite agentFabric
        // being non-nil)。 NOT the same as a clean run。
        if outcome.result == nil {
            return "fabric.run.no-result"
        }
        let summary = summarize(outcome: outcome)
        if let count = summary.watcherHintCount, count > 0 {
            return "fabric.run.hints"
        }
        return "fabric.run.clean"
    }

    /// True if the outcome represents a clean fabric run。
    /// Convenience for hosts that just want a happy-path
    /// signal。 Equivalent to
    /// `category(outcome:) == "fabric.run.clean"`。
    public static func isCleanRun(
        outcome: BASAgentFabricHostOutcome
    ) -> Bool {
        return category(outcome: outcome) ==
            "fabric.run.clean"
    }
}
