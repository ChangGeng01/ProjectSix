// MARK: - SampleHostBenchRiskDerivation
//
// chapter 二百二十一 / M802 — extracted from SampleHostModel.swift.
//
// Pure-function helper for deriving substrate `BASHostRiskLevel`
// from the bench's prompt signature. Pre-this-batch, the same
// `switch signature.stake { ... }` mapping appeared inline in 3
// separate bench paths:
//
//   - legacy bench (chapter 一百四十七 / M573 startBench)        line 885
//   - AFM bench    (chapter 一百七十六 / M610 startAFMBench)     line 1172
//   - hybrid bench (chapter 一百七十七 / M619 startHybridBench)  line 1885
//
// 3-site duplication is anti-doctrine. Adding a new stake case
// (or tweaking the bracket) would have to update all 3 places.
// Hybrid alone has the chapter 二百五 .benign override (forces
// `.low` regardless of stake) so the 3 sites had ALREADY drifted.
//
// Post-this-batch: one file, one function, one doctrine.
//
// Doctrine pins:
//   - Stake bracket (chapter 一百四十七 baseline):
//       low / modest                       → .low
//       high / very-high                   → .medium
//       irreversible / non-reversible-after-act → .high
//       (default / unknown)                → .medium
//   - chapter 二百五 .benign override (hybrid bench only):
//       smokeMode == .benign forces .low regardless of stake
//   - 不变量 #1-#3 + Red line 7: ✓ pure derive, no decision-making.
//   - chapter 二百十一 single-source-of-truth: stake-to-risk
//     invariant owned by one file.

import Foundation
import BASHostKit

enum SampleHostBenchRiskDerivation {
    /// Map a prompt signature's `stake` field to substrate risk level.
    /// Baseline mapping (chapter 一百四十七 / M573 doctrine), used by
    /// legacy bench and AFM bench paths that pre-date the `.benign`
    /// smokeMode override.
    static func riskLevel(signatureStake: String) -> BASHostRiskLevel {
        switch signatureStake {
        case "low", "modest":
            return .low
        case "high", "very-high":
            return .medium
        case "irreversible", "non-reversible-after-act":
            return .high
        default:
            return .medium
        }
    }

    /// Same as `riskLevel(signatureStake:)` plus chapter 二百五
    /// `.benign` override: `.benign` smokeMode forces `.low`
    /// regardless of stake. Used by hybrid bench path.
    ///
    /// Doctrine: even though benign signature has stake="low" already,
    /// the explicit override is doctrine-clearer + future-proof
    /// against signature drift (M774 chapter 二百五).
    static func riskLevel(
        signatureStake: String,
        smokeMode: HybridBenchConfig.SmokeMode
    ) -> BASHostRiskLevel {
        if smokeMode == .benign {
            return .low
        }
        return riskLevel(signatureStake: signatureStake)
    }
}
