import Foundation
import BASOrgan

/// observe→DISPOSE (Line A) — the NEUROMODULATION gate for the factual-belief adjudicator.
///
/// ## Why this exists (biomimetic-brain-efficiency)
///
/// The adjudicator is a HONESTY organ, not a speed organ — but as first wired it was an UNCONDITIONAL
/// tier-1 cost: every assertion-bearing turn paid the MiniLM embed + 1131-fact retrieve (+ optional NLI),
/// blind to stakes / thermal headroom. That violates the substrate's own efficiency doctrine (avoided-compute):
/// expensive verification should be a TIER the effort plan ENGAGES, not a wrap that always fires.
///
/// This gate implements the `stakes` and `headroom` factors of the substrate's effort budget
/// (`energy ∝ ε × stakes × headroom`). It deliberately does NOT use the ε (surprise) factor: ε is a
/// COMPUTE-allocation throttle (high surprise ⇒ think harder) whose correct consumer is the effort/tier
/// allocator — for a HONESTY-verify decision ε is orthogonal-to-backwards (a LOW-ε, confident-on-distribution
/// assertion is exactly where a wrong belief slips through, so it needs MORE verification, not less). Stakes
/// (`does getting this right matter`) is the right verify signal, and is what `.stakesEstimated` implements.
///
/// `BASAdjudicationGate` is that engage/skip decision. It sits in `adjudicated(_:)` BEFORE the expensive
/// embed/retrieve, so a `false` decision is pure avoided-compute (no embed, no allocation). Gating high-stakes
/// turns ONLY is good for BOTH energy AND honesty: the adjudicator fires where correctness matters and stops
/// nagging low-stakes chit-chat (which also eases the over-correction / helpfulness tax).
///
/// ## What's wired vs. hooked
///
/// The L2 organ adapter sees only `BASOrganRequest` (role / preset / instruction). So:
///   - `.thermalHeadroom`, `.roles`, and `.stakesEstimated` work END-TO-END today (all from the L2
///     request / ambient state — `.stakesEstimated` runs a pure prompt heuristic, `BASStakesEstimator`).
///   - A host that holds a richer STAKES signal (e.g. an `BASEffortBudget` risk term computed upstream) can
///     inject it through the generic `.when(_:)` hook. NOTE: ε (`BASPredictiveCodingObservation.runningMSE`)
///     is intentionally NOT a consumer here — it gates COMPUTE/effort, not verify (see above); its home is the
///     effort/tier allocator, not this gate.
///
/// NB: there is deliberately NO preset-`deterministic`-based gate. In this substrate `deterministic` is a
/// decoding-REPRODUCIBILITY flag, not a stakes signal, and it is ANTI-correlated with the deep tier
/// (`.scout` is `deterministic: true`, `.core` is `deterministic: false` by design) — so gating on it would
/// engage the cheap prefilter and SKIP the live core chat. Use `.roles([.core])` for the stakes proxy.
///
/// All gates are pure + `Sendable`; the default everywhere is `.always` (byte-equal with the pre-gate ON
/// behavior). Default-OFF (`BAS_FACTUAL_ADJUDICATE` unset) never constructs the wrapper at all, so the gate is
/// moot there.
public struct BASAdjudicationGate: Sendable {

    /// Returns `true` to ENGAGE the expensive factual adjudication for this turn, `false` to SKIP it
    /// (avoided-compute). Must be cheap — it runs on every candidate turn before the embed.
    public let shouldEngage: @Sendable (BASOrganRequest) async -> Bool

    public init(_ shouldEngage: @escaping @Sendable (BASOrganRequest) async -> Bool) {
        self.shouldEngage = shouldEngage
    }

    // MARK: - Built-in gates

    /// Always engage — the byte-equal-with-pre-gate-ON default (current behavior).
    public static let always = BASAdjudicationGate { _ in true }

    /// Never engage — the adjudicator is dormant even when ON (useful for staged rollout / kill-switch).
    public static let never = BASAdjudicationGate { _ in false }

    /// Engage only for the given organ roles. Stakes proxy: `.core` is the deeper consideration tier (L9/L10),
    /// `.scout` is the cheap prefilter — gating to `[.core]` skips verification on the shallow tier.
    public static func roles(_ roles: Set<BASOrganRole>) -> BASAdjudicationGate {
        BASAdjudicationGate { roles.contains($0.role) }
    }

    /// Skip when the device has no thermal headroom. A dependency-free realization of the substrate's
    /// thermal-lease principle: don't pay the verify cost while throttling. Engages when the current thermal
    /// state is at or below `max` (default `.fair` ⇒ skip on `.serious` / `.critical`). `thermalState` is
    /// injectable so this is unit-testable without a real device under load.
    public static func thermalHeadroom(
        max allowed: ProcessInfo.ThermalState = .fair,
        thermalState: @escaping @Sendable () -> ProcessInfo.ThermalState =
            { ProcessInfo.processInfo.thermalState }
    ) -> BASAdjudicationGate {
        BASAdjudicationGate { _ in thermalState().rawValue <= allowed.rawValue }
    }

    /// Engage only when the turn's ESTIMATED stakes (`BASStakesEstimator`, a cheap pure prompt heuristic
    /// evaluated BEFORE the embed) is at least `threshold`. This is the gate's pre-generation stakes PRODUCER
    /// — the one signal genuinely available at L2 without upstream plumbing: high-stakes turns
    /// (health/legal/financial/safety, advice-seeking) always verify; clearly-casual turns skip; unknown turns
    /// default to engage (coverage-first). The estimator is injectable for tests / a richer host estimator.
    ///
    /// SHARP EDGE: coverage-first holds only at `threshold ≤ 0.6` (the unknown baseline). A higher threshold
    /// trades coverage for cost — a high-stakes turn the lexicon MISSES scores the 0.6 baseline and is skipped.
    /// See `BASStakesEstimator` LIMITATIONS.
    public static func stakesEstimated(
        atLeast threshold: Double,
        using estimate: @escaping @Sendable (String, [String]) -> Double = BASStakesEstimator.estimate
    ) -> BASAdjudicationGate {
        BASAdjudicationGate { estimate($0.instruction, $0.context) >= threshold }
    }

    /// P3 契合 — POSITIVE-casual skip via the L0 CoreML context classifier (a wired NON-LLM organ, ~ms
    /// per call). Coverage-first SURVIVES: a lexicon hit (stakes > the unknown baseline) always engages;
    /// an UNKNOWN classification still engages; ONLY a positive `.chat` classification with a clean
    /// stakes lexicon skips. This is the doctrine-compatible casual lever the raw threshold could never
    /// be (P1's T1 finding: casual turns all paid verify because unknown-baseline == threshold).
    public static func classifierCasualSkip(
        classify: @escaping @Sendable (String) async -> BASContextTaskType?,
        estimate: @escaping @Sendable (String, [String]) -> Double = BASStakesEstimator.estimate
    ) -> BASAdjudicationGate {
        BASAdjudicationGate { req in
            let stakes = estimate(req.instruction, req.context)
            if stakes > 0.6 { return true }                    // lexicon hit → always verify
            let kind = await classify(req.instruction)
            return kind != .chat                               // positive chat + clean lexicon → skip
        }
    }

    /// Host-supplied predicate — the integration point for stakes / ε / effort. NOTE: the predicate receives
    /// only `BASOrganRequest` (the L2 surface), which carries no ε/risk today; a host wires the governance
    /// signals by CAPTURING them in the closure (e.g. a session-scoped ε/risk holder it refreshes each turn).
    /// Plumbing predictive-coding ε / `BASEffortBudget` directly onto the request is the documented follow-up.
    public static func when(
        _ predicate: @escaping @Sendable (BASOrganRequest) async -> Bool
    ) -> BASAdjudicationGate {
        BASAdjudicationGate(predicate)
    }

    // MARK: - Composition

    /// Engage only if EVERY gate engages (AND). Short-circuits on the first skip. Empty ⇒ `.always`.
    public static func all(_ gates: [BASAdjudicationGate]) -> BASAdjudicationGate {
        BASAdjudicationGate { request in
            for gate in gates where await gate.shouldEngage(request) == false { return false }
            return true
        }
    }

    /// Engage if ANY gate engages (OR). Short-circuits on the first engage. Empty ⇒ `.never`.
    public static func any(_ gates: [BASAdjudicationGate]) -> BASAdjudicationGate {
        BASAdjudicationGate { request in
            for gate in gates where await gate.shouldEngage(request) { return true }
            return false
        }
    }

    // MARK: - Environment selection

    /// Build a gate from `BAS_ADJ_GATE` (default `always`). Tokens are `+`/`,`-joined and AND-combined:
    /// `always` · `thermal` (thermalHeadroom) · `core` (roles[.core]) · `stakes` / `stakes:N` (estimated stakes
    /// ≥ N, default 0.5) · `never` (kill-switch). Unknown tokens are ignored (fail-open toward `.always`), so a
    /// typo can never silently DISABLE the adjudicator. `env` is injectable for tests.
    public static func fromEnvironment(
        _ env: [String: String] = ProcessInfo.processInfo.environment
    ) -> BASAdjudicationGate {
        let spec = (env["BAS_ADJ_GATE"] ?? "always").lowercased()
        let tokens = spec.split { $0 == "+" || $0 == "," || $0 == " " }.map(String.init)
        var gates: [BASAdjudicationGate] = []
        for token in tokens {
            switch token {
            case "thermal": gates.append(.thermalHeadroom())
            case "core": gates.append(.roles([.core]))
            case "never": gates.append(.never)
            case "always", "": break
            case let t where t.hasPrefix("stakes"):
                gates.append(.stakesEstimated(atLeast: Self.parseStakesThreshold(t)))
            default: break // unknown ⇒ ignore (never narrows below the other named gates)
            }
        }
        return gates.isEmpty ? .always : .all(gates)
    }

    /// Parse the threshold from a `stakes` / `stakes:N` token. Missing / unparseable / OUT-OF-RANGE ⇒ 0.5.
    /// Out-of-range (e.g. `stakes:2`) is treated as a typo and falls back to the safe default rather than
    /// silently clamping to 1.0 (which would skip nearly every turn — a coverage-loss footgun).
    private static func parseStakesThreshold(_ token: String) -> Double {
        guard let colon = token.firstIndex(of: ":") else { return 0.5 }
        let raw = String(token[token.index(after: colon)...])
        guard let value = Double(raw), (0...1).contains(value) else { return 0.5 }
        return value
    }
}
