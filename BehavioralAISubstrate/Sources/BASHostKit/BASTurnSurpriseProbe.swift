import Foundation
import BASMemory
import BASMetalSubstrate
import BASAppleAdapters

/// observe→DISPOSE (biomimetic-brain-efficiency) — the LIVE ε feed: a per-session probe that turns each chat
/// turn into a real prediction-error signal (surprise) the `BASEffortGovernor` consumes.
///
/// ## How ε becomes real here
///
/// Predictive coding needs an OBSERVATION vector + a running PREDICTION; the error between them is ε. The
/// host-available, cheap observation for a chat turn is its SEMANTIC EMBEDDING (the same on-device MiniLM the
/// adjudicator already uses). Feeding the turn embedding to `BASPredictiveCodingProbe` makes its prediction μ
/// track the RECENT conversation (μ ← μ + α·ε), so the per-turn error is ADAPTIVE: high on a cold start or a
/// topic shift (off-distribution), low on a continuation. That is exactly "surprise" — not a fixed-reference
/// distance but a deviation from what the conversation has been about.
///
/// `observe(turn:)` returns the instantaneous prediction-error ENERGY ‖ε‖² for THIS turn (sharper per-turn
/// than the probe's smoothed `runningMSE`). Feed it to `BASEffortGovernor.plan(runningMSE:)`; `nil` (embedding
/// unavailable) ⇒ the governor falls back to its neutral cold-start surprise. Pure on-device, ~one MiniLM
/// embed + a vector subtraction per turn.
public actor BASTurnSurpriseProbe {

    private let provider: BASMemory.BASEmbeddingProvider
    private let probe: BASPredictiveCodingProbe
    private let dim: Int

    /// - provider: the embedding source (inject MiniLM in production, a stub in tests).
    /// - dim: prediction/observation dimension (must match the provider; embeddings are fit defensively).
    /// - learningRate: α for μ ← μ + α·ε. Higher ⇒ the prediction tracks recent turns faster (more forgiving of
    ///   drift, sharper topic-shift detection); 0.2 is a stable default.
    public init(provider: BASMemory.BASEmbeddingProvider, dim: Int = 384, learningRate: Float = 0.2) {
        let d = max(1, dim)
        self.provider = provider
        self.dim = d
        self.probe = BASPredictiveCodingProbe(
            shape: BASPredictiveCodingProbeShape(dim: d, learningRate: learningRate))
    }

    /// Convenience: drive the live on-device MiniLM provider, matching `dim` to it. `nil` when MiniLM is
    /// unavailable (the host then leaves ε to the governor's neutral cold-start default).
    public init?(learningRate: Float = 0.2) {
        guard let provider = BASMiniLMEmbeddingProvider() else { return nil }
        self.init(provider: provider, dim: provider.dimension, learningRate: learningRate)
    }

    /// Embed the turn + feed predictive coding; return the instantaneous prediction-error energy ‖ε‖² (≥0) for
    /// this turn — the live surprise signal. `nil` only if the observe step fails (never on a normal embed).
    public func observe(turn: String) async -> Double? {
        let raw = await provider.embed(turn).normalized.vector
        let v = Self.fit(raw, to: dim)
        guard let observation = try? await probe.observe(v) else { return nil }
        return Self.errorEnergy(observation.error)
    }

    /// Reset the running prediction (e.g. on a new session / explicit topic boundary).
    public func reset() async { await probe.reset() }

    /// Smoothed running MSE across the session (the probe's adaptation signal) — exposed for observability.
    public func runningMSE() async -> Double { Double(await probe.runningMSE()) }

    // MARK: - Pure helpers

    /// Match an embedding to the probe dimension (truncate / zero-pad) so a provider/probe mismatch can't throw.
    static func fit(_ v: [Float], to dim: Int) -> [Float] {
        if v.count == dim { return v }
        if v.count > dim { return Array(v.prefix(dim)) }
        return v + Array(repeating: 0, count: dim - v.count)
    }

    /// ‖ε‖² — sum of squared per-dimension prediction errors (the prediction-error energy).
    static func errorEnergy(_ error: [Float]) -> Double {
        Double(error.reduce(0) { $0 + $1 * $1 })
    }
}
