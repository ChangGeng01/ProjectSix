// MARK: - BASMambaTurnSignalBuilder — the SSM operator's per-turn INPUT mapping
//
// Makes the Mamba/SSM scan a CORE per-turn operator by feeding it REAL per-turn data. Composes ALL
// THREE live sources into ONE fixed-shape, [0,1]-bounded, MODEL-FREE, deterministic sequence:
//   • L7 affect-layers   → rows [intensity, volatility, spilloverRisk]   (already clamped [0,1])
//   • turn/summary history → rows [tokenCountNorm, charCountNorm, fnvHashUnit]  (model-free text→float)
//   • L9 candidate paths  → rows [confidence, reversibility, expectedCost]  (clamped [0,1])
//
// DETERMINISM (load-bearing): every mapping is pure + fixed-shape + bounded. Bounded inputs keep the
// SSM recurrence stable; the fixed sequence length (capped + zero-padded per source) removes any
// shape-driven nondeterminism. The history text→float uses simple counts + a fixed FNV-1a unit scalar
// — NO embedding model (keeps the determinism surface tiny + no CoreML on the value path). The scan
// itself runs via `BASSSMScanCPUReference` (sync, pure-Swift, deterministic) — never the GPU on the
// value path. Empty across all three sources ⇒ returns nil ⇒ the caller cleanly no-ops that turn.

import Foundation
import BASOrchestration
import BASMetalSubstrate

/// Named dimensions for the SSM turn operator (chapter 一百八十五 — no magic literals).
public enum BASMambaTurnOperatorShape {
    /// One independent SSM state per turn.
    public static let batch: Int = 1
    /// Feature width per sequence row (the 3 features each source contributes).
    public static let hiddenDim: Int = 3
    /// Max rows taken from each source (older/overflow rows are dropped; short sources zero-pad).
    public static let maxAffectRows: Int = 8
    public static let maxHistoryRows: Int = 8
    public static let maxCandidateRows: Int = 8
    /// Total (fixed) sequence length = the three capped sub-lengths concatenated.
    public static var sequenceLength: Int {
        maxAffectRows + maxHistoryRows + maxCandidateRows
    }
    /// Fixed scan constants (mirror `BASMetalBenchmarkHarness` defaults so the recurrence is stable):
    /// Δ small (gentle state change), A<0 (decay in (0,1)), B/C modest projections.
    public static let deltaConstant: Float = 0.1
    public static let aConstant: Float = -1.0
    public static let bConstant: Float = 0.2
    public static let cConstant: Float = 0.3
    /// History feature caps for normalization.
    public static let historyTokenCap: Double = 64.0
    public static let historyCharCap: Double = 512.0
}

/// Fully-assembled, deterministic per-channel SSM scan input (ready for `BASSSMScanCPUReference.scan`).
public struct BASMambaTurnScanInput: Sendable, Equatable {
    public let x: [Float]        // (B, L, D) row-major
    public let delta: [Float]    // (B, L, D)
    public let a: [Float]        // (D,)
    public let b: [Float]        // (B, L, D)
    public let c: [Float]        // (B, L, D)
    public let shape: BASSSMScanShape
    public let affectCount: Int
    public let historyCount: Int
    public let candidateCount: Int
}

public enum BASMambaTurnSignalBuilder {

    /// Deterministic clamp of a Double into a Float in [0, 1].
    static func clamp01(_ v: Double) -> Float {
        if v.isNaN { return 0 }
        return Float(min(1.0, max(0.0, v)))
    }

    /// Model-free, deterministic text → 3 bounded features: token-count-norm, char-count-norm, and a
    /// fixed FNV-1a unit scalar (so distinct texts get distinct-but-bounded signatures, no model).
    static func historyRow(_ text: String) -> [Float] {
        let tokens = text.split { !$0.isLetter && !$0.isNumber }.count
        let tokenNorm = clamp01(Double(tokens) / BASMambaTurnOperatorShape.historyTokenCap)
        let charNorm = clamp01(Double(text.count) / BASMambaTurnOperatorShape.historyCharCap)
        var hash: UInt64 = 1_469_598_103_934_665_603        // FNV-1a offset basis
        for byte in text.utf8 { hash ^= UInt64(byte); hash = hash &* 1_099_511_628_211 }
        let fnvUnit = Float(hash % 1000) / 1000.0           // deterministic [0, 1)
        return [tokenNorm, charNorm, fnvUnit]
    }

    /// Append up to `cap` rows (each D-wide) from `rows`, then zero-pad to exactly `cap` rows.
    private static func appendCapped(_ rows: [[Float]], cap: Int, into x: inout [Float]) -> Int {
        let taken = min(rows.count, cap)
        for i in 0..<taken { x.append(contentsOf: rows[i]) }
        let padRows = cap - taken
        if padRows > 0 {
            x.append(contentsOf: [Float](
                repeating: 0, count: padRows * BASMambaTurnOperatorShape.hiddenDim))
        }
        return taken
    }

    /// Compose all three sources into a fixed-shape per-channel SSM scan input. Returns nil iff all
    /// three sources are empty (clean per-turn no-op).
    public static func scanInput(
        affectLayers: [BASAffectLayer],
        turnHistory: [String],
        candidates: [BASCandidatePath]
    ) -> BASMambaTurnScanInput? {
        if affectLayers.isEmpty, turnHistory.isEmpty, candidates.isEmpty { return nil }

        let D = BASMambaTurnOperatorShape.hiddenDim
        let L = BASMambaTurnOperatorShape.sequenceLength
        let B = BASMambaTurnOperatorShape.batch

        let affectRows = affectLayers.map {
            [clamp01($0.intensity), clamp01($0.volatility), clamp01($0.spilloverRisk)]
        }
        let historyRows = turnHistory.map { historyRow($0) }
        let candidateRows = candidates.map {
            [clamp01($0.confidence), clamp01($0.reversibility), clamp01($0.expectedCost)]
        }

        var x: [Float] = []
        x.reserveCapacity(B * L * D)
        let aCount = appendCapped(affectRows, cap: BASMambaTurnOperatorShape.maxAffectRows, into: &x)
        let hCount = appendCapped(historyRows, cap: BASMambaTurnOperatorShape.maxHistoryRows, into: &x)
        let cCount = appendCapped(candidateRows, cap: BASMambaTurnOperatorShape.maxCandidateRows, into: &x)

        let blD = B * L * D
        return BASMambaTurnScanInput(
            x: x,
            delta: [Float](repeating: BASMambaTurnOperatorShape.deltaConstant, count: blD),
            a: [Float](repeating: BASMambaTurnOperatorShape.aConstant, count: D),
            b: [Float](repeating: BASMambaTurnOperatorShape.bConstant, count: blD),
            c: [Float](repeating: BASMambaTurnOperatorShape.cConstant, count: blD),
            shape: BASSSMScanShape(B: UInt32(B), L: UInt32(L), D: UInt32(D)),
            affectCount: aCount,
            historyCount: hCount,
            candidateCount: cCount)
    }
}
