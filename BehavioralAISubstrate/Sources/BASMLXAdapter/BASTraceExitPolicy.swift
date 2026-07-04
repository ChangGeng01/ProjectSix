// BASTraceExitPolicy — B3 轨迹熵早退: a training-free stop rule for the THINKING trace
// (FRONTIER_2026H2_EVOLUTION.md B3; EntroCut/DEER/EAT lineage, 25-50% trace-token cuts at small scale).
//
// Two triggers, both marker-gated (no `<think>` in the stream ⇒ zero intervention):
//   • ENTROPY CONVERGENCE — a sliding window of the trunk's own next-token distribution entropy stays
//     below τ for a full window ⇒ the model is re-treading converged ground; close at the next boundary
//     token (paragraph/newline — the DEER "reasoning transition point" discipline). The literature TRAP
//     this shape avoids: raw answer-confidence exits fire prematurely on overconfident reasoning models
//     — we demand a SUSTAINED window, a minimum trace length, and a boundary.
//   • BUDGET GUARD — deterministic: when the emitted count crosses maxTokens − answerReserve while still
//     thinking, close NOW (boundary not required). This is the structural fix for the measured co-gate
//     artifact where a 96-token cap was consumed entirely by `<think>` and no answer was ever emitted.
//
// ADR-014: the policy only exists when a config is passed (production default nil = lane untouched).
// NOT ADR-039-lossless BY DESIGN: firing truncates thinking — an opt-in intervention whose quality cost
// is judged on device (the B3 gate), not assumed. One intervention per generation (one-shot disarm).
import Foundation

/// Tunables for the trace early-exit stop rule. Token ids are model-specific and resolved by the
/// adapter from the live tokenizer (Qwen3.5 family: `<think>`=248068, `</think>`=248069, `\n`=198,
/// `\n\n`=271 — hard defaults exist at the adapter, not here).
public struct BASTraceExitConfig: Sendable {
    public var thinkOpenToken: Int
    public var thinkCloseToken: Int
    /// Injected verbatim on fire (e.g. "\n</think>\n\n") — must contain thinkCloseToken.
    public var closeSequence: [Int]
    /// Tokens that count as a safe truncation seam (newline-class) for the entropy rule.
    public var boundaryTokens: Set<Int>
    /// Entropy rule arms only after this many think tokens (early exploration is high-value).
    public var minThinkTokens: Int
    /// Window length (in entropy-bearing think tokens) that must sit below τ.
    public var entropyWindow: Int
    /// τ in millinats; nil disables the entropy rule entirely (budget guard remains).
    public var entropyThresholdMillinats: Int?
    /// Budget guard: fire when outCount ≥ maxTokens − answerReserveTokens while thinking.
    public var answerReserveTokens: Int

    public init(
        thinkOpenToken: Int, thinkCloseToken: Int, closeSequence: [Int], boundaryTokens: Set<Int>,
        minThinkTokens: Int = 24, entropyWindow: Int = 8, entropyThresholdMillinats: Int? = 300,
        answerReserveTokens: Int = 32
    ) {
        self.thinkOpenToken = thinkOpenToken
        self.thinkCloseToken = thinkCloseToken
        self.closeSequence = closeSequence
        self.boundaryTokens = boundaryTokens
        self.minThinkTokens = minThinkTokens
        self.entropyWindow = entropyWindow
        self.entropyThresholdMillinats = entropyThresholdMillinats
        self.answerReserveTokens = answerReserveTokens
    }
}

/// What the lane reports after a run (folded into `Run.traceExit`).
public struct BASTraceExitTelemetry: Sendable {
    public let reason: BASTraceExitPolicy.Reason
    public let thinkTokensAtExit: Int
    public let outCountAtExit: Int
}

/// Per-generation state machine. A value type owned by the decode loop; `observe` is called once per
/// emitted token IN ORDER. Entropy is optional per token (refeed-path tokens carry no packed signal
/// and must be transparent to the window).
public struct BASTraceExitPolicy {
    public enum Reason: String, Sendable { case entropy, budget }
    public enum Verdict { case none, close(Reason) }

    public let config: BASTraceExitConfig
    public private(set) var inThink: Bool
    /// One-shot latch: set on the model's own `</think>` or by `markForcedClose()`.
    public private(set) var closed = false
    public private(set) var thinkTokens = 0
    private var window: [Int] = []

    public init(config: BASTraceExitConfig, primedInThink: Bool = false) {
        self.config = config
        self.inThink = primedInThink
    }

    /// The loop injected `closeSequence` — disarm for the rest of the generation.
    public mutating func markForcedClose() {
        inThink = false
        closed = true
    }

    public mutating func observe(
        token: Int, entropyMillinats: Int?, outCount: Int, maxTokens: Int
    ) -> Verdict {
        guard !closed else { return .none }
        if token == config.thinkOpenToken {
            inThink = true
            thinkTokens = 0
            window = []
            return .none
        }
        if token == config.thinkCloseToken {
            inThink = false
            closed = true                      // the model closed its own trace — never touch the answer
            return .none
        }
        guard inThink else { return .none }
        thinkTokens += 1
        if let ent = entropyMillinats {
            window.append(ent)
            if window.count > config.entropyWindow { window.removeFirst() }
        }
        // Budget guard first — deterministic, boundary-free (the answer tail MUST survive).
        if outCount >= maxTokens - config.answerReserveTokens { return .close(.budget) }
        if let tau = config.entropyThresholdMillinats,
           thinkTokens >= config.minThinkTokens,
           window.count == config.entropyWindow,
           config.boundaryTokens.contains(token),
           window.max().map({ $0 <= tau }) == true {
            return .close(.entropy)
        }
        return .none
    }
}
