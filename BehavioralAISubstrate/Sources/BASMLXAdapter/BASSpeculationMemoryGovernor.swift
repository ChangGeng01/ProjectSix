// MARK: - BASSpeculationMemoryGovernor — U1 跨 turn 压力响应投机调速器 (2026-06-12)
//
// Closes the runtime blind spot the boundary-verdict adjudication
// confirmed (Docs/BOUNDARY_OVERHEAD_AND_HALT_VERDICT.md §D2):
// `BASMLXMemoryBudget.dualResidencyFits` runs ONCE at load time;
// nothing responds when the process footprint drifts toward the
// jetsam ceiling (measured ActiveHard 3376 MB) or the device enters
// thermal/memory pressure mid-session — every observation surface
// (`bas_task_phys_footprint`, `BASSystemProbe.isUnderPressure`) was
// built but drove no decision。
//
// ## Shape: pure ADVISORY state machine (no probes, no actuation)
//
// The governor is deliberately probe-agnostic:the HOST samples the
// observation surfaces between turns and feeds plain values;the
// governor returns an advice (`dropDraft` / `restoreDraft` / `hold`)
// plus its successor state。 The host executes advice via
// `MLXOrganAdapter.unloadDraftModel(reason:)` / `loadDraftModel()`。
// Pure + immutable ⇒ deterministic unit tests, no device needed。
//
// ## Why dropping the draft is the ONE byte-safe actuator
//
// Greedy speculative decoding is TOKEN-IDENTICAL to target-only
// decoding by construction (exact-equality acceptance at argmax —
// see BASSpeculativeMode docs + the dual-device cert)。 The draft
// model's presence changes LATENCY only, never output bits — so the
// governor can drop/restore it freely across turns with ZERO byte
// risk (ADR-014)。 It must only ever act BETWEEN turns (never while
// a decode is in flight);the host owns that scheduling。
//
// ## Hysteresis (no flapping)
//
// DROP needs `strikesToDrop` CONSECUTIVE bad samples (footprint over
// the high water OR host-reported pressure)。 RESTORE needs
// `cleanSamplesToRestore` CONSECUTIVE clean samples AND footprint
// below the LOW water (high × lowWaterRatio) — restoring near the
// ceiling would immediately re-drop。 Any opposite sample resets the
// counter on either side。

import Foundation

/// Advisory governor for speculative-decode draft residency under
/// memory pressure。 Immutable value type:`evaluating(_:)` returns
/// the successor state + the advice for this sample。
public struct BASSpeculationMemoryGovernor: Sendable, Equatable {

    // MARK: Configuration

    public struct Configuration: Sendable, Equatable {
        /// Footprint above this (bytes) counts as a bad sample。
        /// Default = fit budget × 0.9 — the same conservative budget
        /// that gates the load (3000 MB), sampled at runtime。
        public let highWaterBytes: UInt64
        /// Restore only when footprint is BELOW this (hysteresis)。
        public let lowWaterBytes: UInt64
        /// Consecutive bad samples required to advise `dropDraft`。
        public let strikesToDrop: Int
        /// Consecutive clean samples required to advise `restoreDraft`。
        public let cleanSamplesToRestore: Int

        public init(
            highWaterBytes: UInt64,
            lowWaterBytes: UInt64? = nil,
            strikesToDrop: Int = 2,
            cleanSamplesToRestore: Int = 3
        ) {
            // Validate at the boundary — a zero/negative threshold or
            // an inverted water mark is a host bug; clamp to sane
            // floors rather than trusting garbage。
            self.highWaterBytes = max(1, highWaterBytes)
            let defaultLow = UInt64(
                (Double(self.highWaterBytes) * 0.8).rounded(.down))
            let low = lowWaterBytes ?? defaultLow
            self.lowWaterBytes = min(max(1, low), self.highWaterBytes)
            self.strikesToDrop = max(1, strikesToDrop)
            self.cleanSamplesToRestore = max(1, cleanSamplesToRestore)
        }

        /// Default watermarks derived from the speculative fit budget
        /// (`BASMLXMemoryBudget.defaultSpeculativeFitBudgetBytes`,
        /// 3000 MB): high = 90% (2700 MB), low = 80% of high。
        public static func fromFitBudget(
            _ budgetBytes: Int = BASMLXMemoryBudget
                .defaultSpeculativeFitBudgetBytes
        ) -> Configuration {
            Configuration(
                highWaterBytes: UInt64(
                    (Double(max(1, budgetBytes)) * 0.9).rounded(.down)))
        }
    }

    // MARK: Sample + advice

    /// One between-turns observation,host-sampled。
    public struct Sample: Sendable, Equatable {
        /// `bas_task_phys_footprint` / BASTaskVmInfoProbe value;nil
        /// when the probe failed (treated as CLEAN — a dead probe
        /// must not thrash the draft;pressure still counts)。
        public let footprintBytes: UInt64?
        /// `BASSystemProbe.isUnderPressure()` (thermal ≥ serious OR
        /// memory > 80%)。
        public let underPressure: Bool

        public init(footprintBytes: UInt64?, underPressure: Bool) {
            self.footprintBytes = footprintBytes
            self.underPressure = underPressure
        }
    }

    public enum Advice: Sendable, Equatable {
        /// No change this sample。
        case hold
        /// Unload the draft (host calls `unloadDraftModel(reason:)`)。
        case dropDraft(reason: String)
        /// Reload the draft (host calls `loadDraftModel()`)。
        case restoreDraft(reason: String)
    }

    /// Where the governor believes the draft currently is。 Advisory
    /// mirror only — the adapter's `isSpeculationActive` is truth;
    /// the host should re-seed a fresh governor if they diverge。
    public enum Residency: Sendable, Equatable {
        case draftResident
        case draftDropped
    }

    // MARK: State (immutable)

    public let configuration: Configuration
    public let residency: Residency
    /// Consecutive bad samples while resident。
    public let strikes: Int
    /// Consecutive clean samples while dropped。
    public let cleanSamples: Int

    public init(
        configuration: Configuration,
        residency: Residency = .draftResident,
        strikes: Int = 0,
        cleanSamples: Int = 0
    ) {
        self.configuration = configuration
        self.residency = residency
        self.strikes = strikes
        self.cleanSamples = cleanSamples
    }

    // MARK: Evaluation (pure)

    /// Evaluate one sample;returns the successor governor + advice。
    /// Call ONLY between turns — never while a decode is in flight。
    public func evaluating(
        _ sample: Sample
    ) -> (next: BASSpeculationMemoryGovernor, advice: Advice) {
        let overHighWater = sample.footprintBytes.map {
            $0 > configuration.highWaterBytes
        } ?? false
        let belowLowWater = sample.footprintBytes.map {
            $0 < configuration.lowWaterBytes
        } ?? true  // dead probe: pressure alone decides restore-block
        let bad = overHighWater || sample.underPressure

        switch residency {
        case .draftResident:
            guard bad else {
                // Clean while resident — reset strikes。
                return (Self.with(self, strikes: 0), .hold)
            }
            let nextStrikes = strikes + 1
            guard nextStrikes >= configuration.strikesToDrop else {
                return (Self.with(self, strikes: nextStrikes), .hold)
            }
            let reason = "memory governor: "
                + (overHighWater
                    ? "footprint \(sample.footprintBytes ?? 0)B > "
                      + "high water \(configuration.highWaterBytes)B"
                    : "system pressure")
                + " for \(nextStrikes) consecutive samples"
            return (
                Self.with(self, residency: .draftDropped,
                          strikes: 0, cleanSamples: 0),
                .dropDraft(reason: reason))

        case .draftDropped:
            guard !bad, belowLowWater else {
                // Still bad (or not yet under the low water) — reset。
                return (Self.with(self, cleanSamples: 0), .hold)
            }
            let nextClean = cleanSamples + 1
            guard nextClean >= configuration.cleanSamplesToRestore else {
                return (Self.with(self, cleanSamples: nextClean), .hold)
            }
            let reason = "memory governor: \(nextClean) consecutive "
                + "clean samples below low water "
                + "\(configuration.lowWaterBytes)B"
            return (
                Self.with(self, residency: .draftResident,
                          strikes: 0, cleanSamples: 0),
                .restoreDraft(reason: reason))
        }
    }

    /// Immutable field update (no mutation — coding-style doctrine)。
    private static func with(
        _ base: BASSpeculationMemoryGovernor,
        residency: Residency? = nil,
        strikes: Int? = nil,
        cleanSamples: Int? = nil
    ) -> BASSpeculationMemoryGovernor {
        BASSpeculationMemoryGovernor(
            configuration: base.configuration,
            residency: residency ?? base.residency,
            strikes: strikes ?? base.strikes,
            cleanSamples: cleanSamples ?? base.cleanSamples)
    }
}
