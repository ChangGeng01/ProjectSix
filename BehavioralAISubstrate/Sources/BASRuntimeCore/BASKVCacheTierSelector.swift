// MARK: - BASKVCacheTierSelector
// chapter 七百三十五 第一/二/三刀 / M2346-M2348
//
// Memory-pressure-aware auto-router that picks the cheapest
// `BASKVCachePrecisionTier` (chapter 七百三十四) meeting both:
//   (a) the host's memory budget AND
//   (b) the host's accuracy requirement。
//
// Pure-Swift utility — no FFI,no Rust dependency。 Host passes in
// the budget + priority signals (which they query from os APIs
// or their own observability layer);substrate maps those to a
// tier choice。
//
// ## Why a pure utility,not an actor
//
// Tier selection is a deterministic pure function of its inputs。
// No mutable state to protect。 Making it a free-standing struct
// makes it trivial to inline at startup,unit-test exhaustively,
// and audit for invariants。
//
// ## The decision tree codified
//
// Per chapter 七百三十三 第五刀 + 七百三十四:
//
//   1. If host requires EXACT precision (e.g。 audit-pinned
//      replay corpora) → float32 unconditionally
//   2. Else compute the memory budget at each tier
//   3. Pick the highest-precision tier that fits the budget
//   4. If even int8 doesn't fit → return .int8 anyway and
//      let the host decide whether to reject sessions or
//      accept OOM risk

import Foundation

/// Host-declared accuracy priority。 Hint to the selector
/// about what tradeoff the host prefers when memory is
/// constrained。
public enum BASKVCacheAccuracyPriority:
    String, Codable, Equatable, Hashable, Sendable,
    CaseIterable
{
    /// Replay-pinned / audit-locked corpora — never compress。
    case exact = "exact"

    /// Accuracy-priority hosts — prefer Float16 over int8
    /// when both fit the budget。
    case accuracyFirst = "accuracy-first"

    /// Memory-priority hosts — prefer the most aggressive
    /// compression (int8) that meets the budget。
    case memoryFirst = "memory-first"
}

/// Per-session byte estimate at each tier。 Used by the
/// selector to decide which tier meets the host's budget。
public struct BASKVCacheBudgetEstimate:
    Codable, Equatable, Hashable, Sendable
{
    public let float32BytesPerSession: Int
    public let float16BytesPerSession: Int
    public let int8BytesPerSession: Int

    public init(
        float32BytesPerSession: Int,
        float16BytesPerSession: Int,
        int8BytesPerSession: Int
    ) {
        self.float32BytesPerSession =
            float32BytesPerSession
        self.float16BytesPerSession =
            float16BytesPerSession
        self.int8BytesPerSession =
            int8BytesPerSession
    }

    /// Total bytes across N sessions at the named tier。
    public func totalBytes(
        sessionCount: Int,
        tier: BASKVCachePrecisionTier
    ) -> Int {
        switch tier {
        case .float32:
            return sessionCount * float32BytesPerSession
        case .float16:
            return sessionCount * float16BytesPerSession
        case .int8:
            return sessionCount * int8BytesPerSession
        }
    }
}

// MARK: - chapter 七百三十五 第二刀 / M2347
//         BASKVCacheBudgetEstimator

public enum BASKVCacheBudgetEstimator {

    /// Estimate per-session bytes across the 3 tiers for a
    /// session with (turn,layer,dim) shape。 Pure math,no
    /// allocation:multiplies Float32 baseline by the
    /// chapter 七百三十四 asymptoticShrinkRatio values。
    ///
    /// Real footprints include per-token codec overhead (2
    /// scales for int8,version + count Ints for both
    /// compressed forms)。 The estimator returns the asymptotic
    /// value which approaches truth at typical dims (≥ 64)。
    public static func estimate(
        turnsPerSession: Int,
        layersPerToken: Int,
        elementsPerTensor: Int
    ) -> BASKVCacheBudgetEstimate {
        // Per-token Float32 bytes:K + V tensors × 4 bytes
        let bytesPerTokenFloat32 =
            elementsPerTensor * 4 * 2
        let bytesPerSessionFloat32 =
            turnsPerSession
            * layersPerToken
            * bytesPerTokenFloat32
        // Float16 is half;int8 is quarter (asymptotic)
        let float16Bytes = bytesPerSessionFloat32 / 2
        let int8Bytes = bytesPerSessionFloat32 / 4
        return BASKVCacheBudgetEstimate(
            float32BytesPerSession: bytesPerSessionFloat32,
            float16BytesPerSession: float16Bytes,
            int8BytesPerSession: int8Bytes)
    }
}

// MARK: - chapter 七百三十五 第三刀 / M2348
//         BASKVCacheTierSelector

/// Host-facing tier selector。 Picks the best
/// `BASKVCachePrecisionTier` for a session shape given the
/// host's memory budget + accuracy priority。
public enum BASKVCacheTierSelector {

    /// Pick the cheapest tier meeting both the budget and the
    /// accuracy priority。 Returns the tier choice + the bytes
    /// the chosen tier consumes at the given sessionCount。
    ///
    /// Decision logic:
    ///   - `.exact`         → always .float32 (regardless of budget)
    ///   - `.accuracyFirst` → prefer Float16,fall back to int8
    ///                       if Float16 OOM,fall back to int8
    ///                       even if it OOMs (host's problem)
    ///   - `.memoryFirst`   → prefer int8 always,but if Float32
    ///                       fits the budget by a wide margin AND
    ///                       int8 doesn't save meaningful memory
    ///                       (sessionCount × shrink savings <
    ///                       1 MB),stay on Float32 to keep
    ///                       maximum precision
    public static func select(
        estimate: BASKVCacheBudgetEstimate,
        sessionCount: Int,
        memoryBudgetBytes: Int,
        accuracyPriority:
            BASKVCacheAccuracyPriority
    ) -> Selection {
        let f32Total = estimate.totalBytes(
            sessionCount: sessionCount,
            tier: .float32)
        let f16Total = estimate.totalBytes(
            sessionCount: sessionCount,
            tier: .float16)
        let i8Total = estimate.totalBytes(
            sessionCount: sessionCount,
            tier: .int8)

        switch accuracyPriority {

        case .exact:
            // Audit-pinned hosts get Float32 regardless of budget
            return Selection(
                tier: .float32,
                bytesUsed: f32Total,
                fitsInBudget: f32Total <= memoryBudgetBytes,
                reason: "exact priority — Float32 always")

        case .accuracyFirst:
            // Prefer Float32 if it fits;else Float16;else int8
            if f32Total <= memoryBudgetBytes {
                return Selection(
                    tier: .float32,
                    bytesUsed: f32Total,
                    fitsInBudget: true,
                    reason: "Float32 fits the budget")
            }
            if f16Total <= memoryBudgetBytes {
                return Selection(
                    tier: .float16,
                    bytesUsed: f16Total,
                    fitsInBudget: true,
                    reason:
                        "Float32 over budget,Float16 fits")
            }
            // Even Float16 doesn't fit — fall to int8 + flag
            return Selection(
                tier: .int8,
                bytesUsed: i8Total,
                fitsInBudget:
                    i8Total <= memoryBudgetBytes,
                reason:
                    "neither Float32 nor Float16 fit,using int8")

        case .memoryFirst:
            // Compute the memory savings of int8 vs Float32
            let int8Savings = f32Total - i8Total
            // If Float32 fits AND int8 saves < 1 MB,stay on
            // Float32 for max precision (the savings aren't
            // meaningful enough to justify the precision loss)
            if f32Total <= memoryBudgetBytes
               && int8Savings < 1_048_576
            {
                return Selection(
                    tier: .float32,
                    bytesUsed: f32Total,
                    fitsInBudget: true,
                    reason:
                        "Float32 fits + int8 savings < 1 MB")
            }
            return Selection(
                tier: .int8,
                bytesUsed: i8Total,
                fitsInBudget:
                    i8Total <= memoryBudgetBytes,
                reason: "memory-first → int8")
        }
    }

    /// Selection result。 Carries the chosen tier + observability
    /// info (bytes consumed,whether the chosen tier fits the
    /// budget,human-readable reason for the choice)。
    public struct Selection:
        Equatable, Hashable, Sendable
    {
        public let tier: BASKVCachePrecisionTier
        public let bytesUsed: Int
        public let fitsInBudget: Bool
        public let reason: String

        public init(
            tier: BASKVCachePrecisionTier,
            bytesUsed: Int,
            fitsInBudget: Bool,
            reason: String
        ) {
            self.tier = tier
            self.bytesUsed = bytesUsed
            self.fitsInBudget = fitsInBudget
            self.reason = reason
        }
    }
}
