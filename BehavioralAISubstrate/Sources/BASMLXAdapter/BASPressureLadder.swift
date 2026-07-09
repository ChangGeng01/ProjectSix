import Foundation

/// 案5 (2026-07-06 decode-OS audit) — the jetsam-aware pressure ladder: graduated, byte-safe
/// reclaim actions ordered by MEASURED reclaim cost, fired from between-turn samples of the
/// process memory headroom against the RESOLVED per-process cap (缝7 — not the stale constant).
///
/// PURE hysteresis state machine (host-unit-testable); the adapter owns the actuators:
///   rung 1 `parkColdSeats`   — warm-park every pooled seat except the current one through the
///                              seam-8a pending-spill eviction (KV→disk at the certified 122.9×
///                              warm restore = the cheapest MBs in the process, zero inline block)
///   rung 2 `dropSpecDecoder` — release the cached MTP decoder (~300MB; the spec lane lazily
///                              re-quantizes on the next MTP turn — a latency cost, never a
///                              correctness one)
///   rung 3 `clearAllSessions`— drop every seat + transcript + snapshot and shrink the MLX
///                              buffer pool: survival over warmth (the DFlash take-1/2 jetsam
///                              lesson — a dead process serves nobody)
///
/// Each rung LATCHES once fired and re-arms only after headroom recovers a full band above its
/// threshold — the anti-thrash guard (spill storms while hot were the U1 design's failure mode).
/// deliberately NOT built (per the audit's do-not-build list): a fused thermal+memory "pressure
/// score", in-decode sampling (between turns ONLY), predictive models, learned policy.
struct BASPressureLadder: Equatable {

    enum Rung: Int, CaseIterable, Comparable, Equatable {
        case parkColdSeats = 1, dropSpecDecoder = 2, clearAllSessions = 3
        static func < (a: Rung, b: Rung) -> Bool { a.rawValue < b.rawValue }
    }

    /// audit mlx-adapter-core MED-6 — the reclaim ACTIONS a fired deepest rung must execute.
    /// `advise` returns only the deepest newly-crossed rung, but a straight collapse latches the
    /// milder rungs at the same instant; executing ONLY the deepest left rung-2's ~300MB MTP
    /// decoder resident (clearAllSessions drops seats + shrinks the pool but never nulls the
    /// decoder box). So the deepest rung subsumes the milder rungs' DISTINCT actions:
    ///   • clearAllSessions ⊇ dropSpecDecoder (parkColdSeats is subsumed — clearing drops all seats)
    ///   • dropSpecDecoder ⊇ parkColdSeats (both latched below the drop threshold)
    /// Pure relation — the adapter drives its actuator off this so the switch cannot drift.
    static func reclaimActions(forDeepest deepest: Rung) -> [Rung] {
        switch deepest {
        case .parkColdSeats:    return [.parkColdSeats]
        case .dropSpecDecoder:  return [.parkColdSeats, .dropSpecDecoder]
        case .clearAllSessions: return [.dropSpecDecoder, .clearAllSessions]
        }
    }

    struct Config: Equatable {
        let capBytes: Int
        /// Headroom fractions of the resolved cap; descending severity.
        var parkBelow = 0.15
        var dropBelow = 0.10
        var clearBelow = 0.05
        /// Re-arm band: a rung un-latches only above (threshold + band).
        var rearmBand = 0.05
        init(capBytes: Int) { self.capBytes = max(1, capBytes) }
    }

    let config: Config
    private(set) var latched: Set<Rung> = []
    private(set) var firedHistory: [Rung] = []

    init(config: Config) { self.config = config }

    private func threshold(_ r: Rung) -> Double {
        switch r {
        case .parkColdSeats: return config.parkBelow
        case .dropSpecDecoder: return config.dropBelow
        case .clearAllSessions: return config.clearBelow
        }
    }

    /// Sample between turns. Returns the DEEPEST newly-crossed rung (worst-first — when memory
    /// collapses straight through two thresholds, act at the severe one; the milder rung latches
    /// too, so recovery re-arms them independently). nil = no action.
    mutating func advise(headroomBytes: Int) -> Rung? {
        let frac = Double(max(0, headroomBytes)) / Double(config.capBytes)
        for r in latched where frac > threshold(r) + config.rearmBand {
            latched.remove(r)
        }
        var fired: Rung? = nil
        for r in Rung.allCases.sorted(by: >) where frac <= threshold(r) && !latched.contains(r) {
            latched.insert(r)
            if fired == nil { fired = r }
        }
        if let fired { firedHistory.append(fired) }
        return fired
    }
}
