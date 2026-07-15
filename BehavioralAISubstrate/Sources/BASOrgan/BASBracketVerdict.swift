import Foundation

/// The drift-refusing bracket promotion verdict, as a pure function.
///
/// device-recon id13: several on-device probes (BASQuantABProbe SPEED + KVQUANT,
/// BASSpecSpeedupProbe, the take-5 endurance bracket) measured a challenger
/// against a `pre → challenger → post` bracket of the SAME baseline (one model
/// resident at a time, so pre and post drift with thermal/warmup) and turned the
/// raw ms into a promote/decline decision INLINE with a hand-copied expression.
/// A copy that flipped `<` to `>`, dropped the drift band, or mis-averaged the
/// bracket would still print a plausible verdict. Extracting the one true rule
/// here makes it Mac-unit-testable and single-sourced.
///
/// Rule: the challenger WINS only if it is faster than the pre/post bracket by
/// MORE than the measurement drift `|post − pre|`. So a warm-vs-cold baseline
/// swing (pre ≠ post) can never be mistaken for a genuine speed win.
public enum BASBracketVerdict {

    public enum Outcome: String, Sendable, Equatable {
        case win = "SPEED-WIN"
        case inconclusiveWithinDrift = "SPEED-INCONCLUSIVE-WITHIN-DRIFT"
    }

    public struct Result: Sendable, Equatable {
        public let outcome: Outcome
        public let bracketMs: Double
        public let driftMs: Double
        /// bracket / challenger (0 when the challenger run failed, challenger ≤ 0).
        public let speedup: Double
        public var isWin: Bool { outcome == .win }
    }

    public static func classify(
        preMs: Double, challengerMs: Double, postMs: Double
    ) -> Result {
        let bracket = (preMs + postMs) / 2
        let drift = abs(postMs - preMs)
        let speedup = challengerMs > 0 ? bracket / challengerMs : 0
        let win = challengerMs > 0 && challengerMs < (bracket - drift)
        return Result(
            outcome: win ? .win : .inconclusiveWithinDrift,
            bracketMs: bracket, driftMs: drift, speedup: speedup)
    }
}
