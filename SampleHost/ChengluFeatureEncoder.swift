// M652 chapter 一百八十二 — single-source 43-dim featurize.
//
// Eliminates the 4× duplication that existed pre-this-batch:
// - CoreMLPreflightInference.featurize
// - CoreMLPermitPredictInference.featurize
// - CoreMLRegressionHeads.featurize
// - CoreMLMultiHeadInference.featurize
//
// All 4 helpers had IDENTICAL alphabet arrays + identical loops.
// Now they all delegate to ChengluFeatureEncoder.encode(_:).
//
// Why a struct (not enum): Swift makes static computed lets
// trickier with enums; struct lets us namespace the constants
// cleanly without instantiation.
//
// Doctrine pin: this is the ONE place 43-dim feature schema is
// defined in the iOS app. Future shared-encoder retraining MUST
// update this single file (and the Python featurize_row stays
// in sync; chapter 一百八十二+ could ship a generator script).

import Foundation

/// Single-source 43-dim signature one-hot encoder.
///
/// Schema pinned to chapter 175/176 corpus signature space:
///   8 tone + 10 domain + 6 stake + 7 timeframe + 4 confidant +
///   3 askshape + 5 mutationSeed = 43 dims (bool-as-Float32).
///
/// Order MUST match Python `featurize_row` in
/// `scripts/train_chenglu_preflight_v0.py` so trained CoreML
/// models receive features in the exact training order.
public enum ChengluFeatureEncoder {
    public static let tones: [String] = [
        "anxious", "authoritative", "vulnerable", "agentic",
        "confused", "grieving", "curious", "angry"
    ]
    public static let domains: [String] = [
        "financial", "medical", "relational", "work", "parenting",
        "identity", "ethical", "existential", "trauma", "creative"
    ]
    public static let stakes: [String] = [
        "low", "modest", "high", "very-high",
        "irreversible", "non-reversible-after-act"
    ]
    public static let timeframes: [String] = [
        "minutes", "hours", "days", "weeks",
        "months", "lifetime", "past-unresolved"
    ]
    public static let confidants: [String] = [
        "friend", "expert", "stranger", "decision-system"
    ]
    public static let askShapes: [String] = [
        "narrative", "decision-tree", "single-action"
    ]
    public static let mutationSeedRange: Range<Int> = 0..<5

    /// Total feature dimensions. Hardcoded for compile-time
    /// safety; an internal test asserts this matches the sum
    /// of alphabet sizes.
    public static let featureCount: Int = 43

    /// Compute-time invariant check (called from a unit test).
    /// Returns true iff all alphabet sizes sum to featureCount.
    /// Used by SampleHostTests to catch alphabet drift.
    public static func dimensionsAreConsistent() -> Bool {
        return tones.count + domains.count + stakes.count
            + timeframes.count + confidants.count
            + askShapes.count + mutationSeedRange.count
            == featureCount
    }

    /// Encode a `ChengluPromptFeatures` into the canonical
    /// 43-dim Float32 one-hot vector. Order matches Python
    /// training featurize so CoreML models get features in
    /// exactly the dimensional layout they were trained on.
    public static func encode(
        _ features: ChengluPromptFeatures
    ) -> [Float] {
        var v: [Float] = []
        v.reserveCapacity(featureCount)
        for t in tones {
            v.append(features.tone == t ? 1.0 : 0.0)
        }
        for d in domains {
            v.append(features.domain == d ? 1.0 : 0.0)
        }
        for s in stakes {
            v.append(features.stake == s ? 1.0 : 0.0)
        }
        for t in timeframes {
            v.append(features.timeframe == t ? 1.0 : 0.0)
        }
        for c in confidants {
            v.append(features.confidant == c ? 1.0 : 0.0)
        }
        for a in askShapes {
            v.append(features.askShape == a ? 1.0 : 0.0)
        }
        for m in mutationSeedRange {
            v.append(features.mutationSeed == m ? 1.0 : 0.0)
        }
        return v
    }
}
