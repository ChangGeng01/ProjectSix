// BASDifficultyProbe — B2 探针路由器 (FRONTIER_2026H2 B2; 2602.09924 / DiffAdapt ICLR-26):
// a linear head over the LAST-PROMPT-TOKEN hidden state predicts first-attempt failure BEFORE
// any token is generated. In our stack the "observation hook" is free — the fused lane's own
// prefill already holds hLast; scoring is one 4096-dot-product.
//
// The head is TRAINED OFFLINE on (hidden, pass/fail) pairs from THIS model
// (BASDifficultyProbeCollectTests → fit_probe.py → probe_weights.json). v1 domain = verifiable
// math/factual questions; broader traffic needs its own calibration pass (recorded follow-up).
// ADR-014: consumed only where explicitly armed; scoring is observation-only.
import Foundation

public struct BASDifficultyProbe: Sendable {
    public let w: [Float]
    public let b: Float
    public let mu: [Float]
    public let sd: [Float]
    /// Held-out AUC recorded at fit time (transparency: consumers can gate on it).
    public let heldoutAUC: Double

    public enum ProbeError: Error { case badFile(String), dimensionMismatch(Int, Int) }

    public init(weightsURL: URL) throws {
        let data = try Data(contentsOf: weightsURL)
        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let w = obj["w"] as? [Double], let b = obj["b"] as? Double,
              let mu = obj["mu"] as? [Double], let sd = obj["sd"] as? [Double] else {
            throw ProbeError.badFile(weightsURL.lastPathComponent)
        }
        guard w.count == mu.count, mu.count == sd.count else {
            throw ProbeError.dimensionMismatch(w.count, mu.count)
        }
        self.w = w.map(Float.init)
        self.b = Float(b)
        self.mu = mu.map(Float.init)
        self.sd = sd.map(Float.init)
        self.heldoutAUC = obj["heldout_auc"] as? Double ?? .nan
    }

    public init(w: [Float], b: Float, mu: [Float], sd: [Float], heldoutAUC: Double = .nan) {
        self.w = w
        self.b = b
        self.mu = mu
        self.sd = sd
        self.heldoutAUC = heldoutAUC
    }

    /// P(first-attempt SUCCESS) from the last-prompt-token hidden state. One dot product.
    public func successProbability(hidden: [Float]) throws -> Double {
        guard hidden.count == w.count else {
            throw ProbeError.dimensionMismatch(hidden.count, w.count)
        }
        var z = b
        for i in 0 ..< hidden.count {
            z += w[i] * (hidden[i] - mu[i]) / sd[i]
        }
        return 1.0 / (1.0 + exp(-Double(z)))
    }

    /// The DiffAdapt-style budget map: hard questions earn a bigger decode budget, easy ones a
    /// smaller one — bounded to ±1 tier around the effort loop's own dial so the probe REFINES
    /// the plan rather than overruling it. Tiers mirror BASEffortPlan.maxDecodeTokens.
    public func refinedBudget(planned: Int, pSuccess: Double,
                              hardBelow: Double = 0.35, easyAbove: Double = 0.85) -> Int {
        let tiers = [64, 160, 384, 1024]
        guard let idx = tiers.firstIndex(where: { $0 >= planned }) else { return planned }
        if pSuccess < hardBelow { return tiers[min(tiers.count - 1, idx + 1)] }
        if pSuccess > easyAbove { return tiers[max(0, idx - 1)] }
        return planned
    }
}
