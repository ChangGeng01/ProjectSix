// MARK: - SampleHostThermalCooldown
//
// chapter 二百九 / M790 — adaptive thermal cooldown ladder.
//
// Context (why this exists):
//   chapter 一百九十七 (M740) shipped opt-in `pauseOnSerious` so
//   operators on hot devices could let `.serious` thermal trip the
//   gate in addition to `.critical`. The pause path slept a FIXED
//   30 seconds then re-checked.
//
//   chapter 二百八 (.rawLLM) 2h iPhone 17e bench surfaced the
//   architectural mismatch: iPhone 17e holds `.serious` thermal for
//   minutes-to-hours under sustained bench load (recovery requires
//   ~5-10 min of idle). With a fixed 30s sleep the gate fired 236
//   times in 2 hours (93%) — every 30s the device came back, was
//   still hot, slept again. Net result: 17 real-LLM rows in 2h.
//
// Decision (chapter 二百九 doctrine):
//   Replace fixed 30s with an exponential cooldown ladder bounded
//   at 5 minutes. First pause: 30s (preserve chapter-197 baseline
//   for short hot-spikes). Sustained pauses widen the gap between
//   thermal re-checks so the device actually radiates heat.
//
//   pauseStreak == 0 → 0s     (not in cooldown — gate said .run)
//   pauseStreak == 1 → 30s    (chapter 一百九十七 baseline)
//   pauseStreak == 2 → 60s
//   pauseStreak == 3 → 120s
//   pauseStreak >= 4 → 300s   (5 min ceiling)
//
//   The 5 min ceiling is the OUTER bound — deliberately NOT
//   "sleep forever". A ceiling lets a stuck-hot device still emit
//   one paused-row every 5 min so JSONL replay sees the gap, and
//   gives a periodic re-check window in case ambient temp drops.
//
// Architecture (chapter 二百九 deconstruction step):
//   This is the FIRST file extracted out of `SampleHostModel`'s
//   bench-loop body per ADR-004 future migration list. Pure value
//   type, no I/O, no @Published, no actor. Lifetime is one bench
//   task; a fresh instance per Run/Stop cycle.
//
// Doctrine pins (red-line preservation):
//   - Red line 7 (HINT-ONLY observability):   ✓ cooldown is local
//     control-flow, doesn't affect substrate decision / permit /
//     verdict. Substrate's `calibrateRisk()` still owns risk.
//   - 不变量 #1 (先醒再答):                     ✓ wake path unchanged.
//   - 不变量 #2 (神经不掌权):                   ✓ permit single-mouth
//     stays at L11 / L14. Cooldown only paces the bench iter loop.
//   - 不变量 #3 (私有经验不进权重):             ✓ no weight write.
//   - chapter 一百九十二 single-source-of-truth: this file owns the
//     adaptive-cooldown invariant; `SampleHostModel` calls into it.

import Foundation

/// Adaptive thermal cooldown — pure value type tracking how many
/// consecutive bench iters were paused by `SampleHostBenchThermalGate`.
/// Reset to zero on the first non-pause iter.
///
/// Sleep duration grows along an explicit ladder (30s → 60s → 120s →
/// 300s cap). The cap is intentional: a hot-stuck device should still
/// re-check thermal every 5 min so a cooled ambient unlocks the bench
/// promptly, and so JSONL still emits a paused-row at a regular cadence
/// (downstream replay can grep the cadence to detect long thermal
/// stalls).
struct SampleHostThermalCooldown: Equatable, Sendable {

    // MARK: Ladder constants
    //
    // Doctrine: explicit table beats power-of-two formula. The table
    // is grep-able + obviously testable; readers see the intended
    // schedule at a glance instead of inferring it from `pow(2, n)`.

    /// Sleep duration at `pauseStreak == 1`. Preserves chapter 一百
    /// 九十七 baseline (M740 shipped 30s).
    static let firstSleepSeconds: Double = 30

    /// Sleep duration at `pauseStreak == 2`.
    static let secondSleepSeconds: Double = 60

    /// Sleep duration at `pauseStreak == 3`.
    static let thirdSleepSeconds: Double = 120

    /// Sleep ceiling at `pauseStreak >= 4`.
    /// Doctrine: 5 minutes. Long enough for a hot iPhone to dissipate
    /// meaningfully (chapter 一百九十六 smoke showed iPhone 17e dropping
    /// from `.serious` to `.fair` in ~3-4 min of substrate idle).
    /// Short enough that operators don't perceive the bench as wedged.
    static let ceilingSleepSeconds: Double = 300

    /// Saturation cap on the streak counter. Prevents overflow on a
    /// bench task that runs for years (well beyond practical 10h
    /// horizon). Chosen so any value >= cap collapses into the same
    /// "ceiling" bucket — the streak counter becomes a fixed-point.
    static let pauseStreakSaturation: Int = 1000

    // MARK: State

    /// Consecutive `.pause` decisions observed since the last `.run`.
    /// Public read-only so callers (e.g. dashboards, tests) can
    /// inspect; mutation goes only through `observe(decision:)`.
    private(set) var pauseStreak: Int

    init() {
        self.pauseStreak = 0
    }

    // MARK: Mutation

    /// Advance the streak based on the gate's decision for the
    /// current iter. `.pause` increments; `.run` resets to zero.
    /// Saturates at `pauseStreakSaturation` to avoid overflow.
    mutating func observe(
        decision: SampleHostBenchThermalDecision
    ) {
        switch decision {
        case .pause:
            let next = pauseStreak &+ 1
            if next < 0 || next > Self.pauseStreakSaturation {
                pauseStreak = Self.pauseStreakSaturation
            } else {
                pauseStreak = next
            }
        case .run:
            pauseStreak = 0
        }
    }

    // MARK: Query

    /// Sleep duration for the current streak, in seconds.
    /// `pauseStreak == 0` → `0` (gate decided `.run`, no cooldown).
    /// `pauseStreak == 1..3` → ladder values.
    /// `pauseStreak >= 4` → ceiling.
    func sleepSeconds() -> Double {
        switch pauseStreak {
        case ..<1: return 0
        case 1: return Self.firstSleepSeconds
        case 2: return Self.secondSleepSeconds
        case 3: return Self.thirdSleepSeconds
        default: return Self.ceilingSleepSeconds
        }
    }

    /// Convenience for `Task.sleep(nanoseconds:)`. Truncates to
    /// `UInt64` (no fractional nanoseconds at our timescales).
    func sleepNanoseconds() -> UInt64 {
        UInt64(sleepSeconds() * 1_000_000_000)
    }

    /// Human-readable label for dashboards / row anomaly tags.
    /// Stable strings so JSONL grep / replay tools can match.
    func ladderLabel() -> String {
        switch pauseStreak {
        case ..<1: return "cooldown-idle"
        case 1: return "cooldown-30s"
        case 2: return "cooldown-60s"
        case 3: return "cooldown-120s"
        default: return "cooldown-300s-ceiling"
        }
    }
}
