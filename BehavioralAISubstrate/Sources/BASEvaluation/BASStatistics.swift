import Foundation

/// P1(RSI 章程 2026-07-07)——全仓第一份统计函数(盘点实锤:grep wilson 全仓为零;
/// eval-rigor 硬教训要求报 CI 与配对显著性,此前全靠散文)。纯函数、零依赖。
public enum BASStatistics {

    /// Wilson score interval for a binomial proportion (default z = 1.96 ≈ 95%).
    /// Returns nil for trials ≤ 0. The eval-rigor lesson this encodes: N~57 ⇒ ±13pp —
    /// "not significant" ≠ equivalence; always LOOK at the width.
    public static func wilsonInterval(
        successes: Int, trials: Int, z: Double = 1.96
    ) -> (low: Double, high: Double)? {
        guard trials > 0, successes >= 0, successes <= trials, z > 0 else { return nil }
        let n = Double(trials)
        let p = Double(successes) / n
        let z2 = z * z
        let denom = 1 + z2 / n
        let center = (p + z2 / (2 * n)) / denom
        let half = (z / denom) * (p * (1 - p) / n + z2 / (4 * n * n)).squareRoot()
        return (max(0, center - half), min(1, center + half))
    }

    /// Exact McNemar two-sided p-value on paired binary outcomes (the v12 audit's settle tool:
    /// "HumanEval +5.5 above noise" died by this test). `b`/`c` = the discordant pair counts
    /// (A-only-pass / B-only-pass). p = P(X ≤ min(b,c)) + P(X ≥ max(b,c)), X ~ Binomial(b+c, ½);
    /// n = 0 ⇒ 1.0 (no evidence either way).
    public static func mcNemarExactP(b: Int, c: Int) -> Double {
        precondition(b >= 0 && c >= 0)
        let n = b + c
        guard n > 0 else { return 1.0 }
        let k = min(b, c)
        var tail = 0.0
        for i in 0...k { tail += binomialPMF(n: n, k: i, p: 0.5) }
        // two-sided for the symmetric p=0.5 null: double the smaller tail, cap at 1.
        return min(1.0, 2 * tail - (b == c ? binomialPMF(n: n, k: k, p: 0.5) : 0))
    }

    /// Binomial PMF via log-gamma (stable for the n≤~10⁴ eval scales here).
    public static func binomialPMF(n: Int, k: Int, p: Double) -> Double {
        guard n >= 0, k >= 0, k <= n, p >= 0, p <= 1 else { return 0 }
        if p == 0 { return k == 0 ? 1 : 0 }
        if p == 1 { return k == n ? 1 : 0 }
        let logC = lgamma(Double(n + 1)) - lgamma(Double(k + 1)) - lgamma(Double(n - k + 1))
        return exp(logC + Double(k) * log(p) + Double(n - k) * log(1 - p))
    }
}
