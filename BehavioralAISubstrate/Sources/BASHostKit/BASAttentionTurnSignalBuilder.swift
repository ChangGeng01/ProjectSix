// ADR-039 Phase 5 — the attention operator's per-turn INPUT mapping (candidate-salience attention).
//
// Pure, fixed-feature, [0,1]-bounded, MODEL-FREE, deterministic Q/K/V from two live turn sources:
//   • L7 affect-layers  → the QUERY  (mean [intensity, volatility, spilloverRisk]) — "what the turn feels"
//   • L9 candidate paths → the KEYS=VALUES (rows [confidence, reversibility, expectedCost]) — "the options"
//
// attention(Q,K,V) = softmax(Q·Kᵀ/√D)·V yields a salience-weighted candidate profile — a NON-governance
// REASONING signal ("where the turn's affect attends among the candidates"). It feeds NO verdict/permit/
// commit/render/seal/replay (ADR-039 §10 — Metal eats only substrate-owned, non-governance hot paths).
//
// DETERMINISM (load-bearing): every mapping is pure + fixed-feature + bounded. The deterministic INPUT is
// what the coordinator emits on the sync turn thread; the Metal attention COMPUTE runs OFF-thread in the
// host (BASAttentionMetalReasoning), never on the value path.

import Foundation
import BASOrchestration

/// Named dimensions for the attention turn operator (no magic literals).
public enum BASAttentionOperatorShape {
    /// Feature width per row (the 3 features each source contributes). Q is 1×D, K=V are N×D.
    public static let featureDim: Int = 3
    /// Max candidate rows taken (older/overflow candidates dropped; keeps the shape bounded + the kernel
    /// cheap for chat-shaped turns).
    public static let maxCandidateRows: Int = 8
}

/// Fully-assembled, deterministic single-head attention input (ready for `BASMetalAttentionDispatcher`).
public struct BASAttentionTurnInput: Sendable, Equatable {
    public let q: [Float]            // (1, D) row-major — the query
    public let k: [Float]            // (N, D)
    public let v: [Float]            // (N, D)
    public let qRows: Int            // 1
    public let cols: Int             // D (used as both qCols and vCols here, since Dv == D)
    public let kRows: Int            // N
    public let candidateCount: Int
    public init(q: [Float], k: [Float], v: [Float], qRows: Int, cols: Int, kRows: Int, candidateCount: Int) {
        self.q = q; self.k = k; self.v = v
        self.qRows = qRows; self.cols = cols; self.kRows = kRows; self.candidateCount = candidateCount
    }
}

public enum BASAttentionTurnSignalBuilder {

    /// Deterministic clamp of a Double into a Float in [0, 1].
    static func clamp01(_ v: Double) -> Float {
        if v.isNaN { return 0 }
        return Float(min(1.0, max(0.0, v)))
    }

    /// Compose affect (→ Q) + candidates (→ K=V) into a fixed-feature attention input. Returns nil iff
    /// there are NO candidates (no keys ⇒ no attention — a clean per-turn no-op).
    public static func signal(
        affectLayers: [BASAffectLayer],
        candidates: [BASCandidatePath]
    ) -> BASAttentionTurnInput? {
        let D = BASAttentionOperatorShape.featureDim
        let taken = Array(candidates.prefix(BASAttentionOperatorShape.maxCandidateRows))
        guard !taken.isEmpty else { return nil }

        // K = V rows from candidates (each a bounded 3-feature row).
        var kv: [Float] = []
        kv.reserveCapacity(taken.count * D)
        for c in taken {
            kv.append(clamp01(c.confidence))
            kv.append(clamp01(c.reversibility))
            kv.append(clamp01(c.expectedCost))
        }
        // Q (1×D) = mean affect [intensity, volatility, spilloverRisk]; empty affect ⇒ zeros (⇒ uniform
        // attention over candidates — a well-defined neutral query).
        var q = [Float](repeating: 0, count: D)
        if !affectLayers.isEmpty {
            var s0 = 0.0, s1 = 0.0, s2 = 0.0
            for a in affectLayers { s0 += a.intensity; s1 += a.volatility; s2 += a.spilloverRisk }
            let n = Double(affectLayers.count)
            q[0] = clamp01(s0 / n); q[1] = clamp01(s1 / n); q[2] = clamp01(s2 / n)
        }
        return BASAttentionTurnInput(
            q: q, k: kv, v: kv, qRows: 1, cols: D, kRows: taken.count, candidateCount: taken.count)
    }
}
