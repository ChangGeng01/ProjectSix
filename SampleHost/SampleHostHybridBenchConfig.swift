// MARK: - SampleHostHybridBenchConfig (HybridBenchConfig + HybridBenchTuning)
//
// chapter 二百十五 / M796 — extracted from SampleHostModel.swift.
//
// Per-bench typed config + 4 doctrinal-default tuning constants
// + 5-case SmokeMode enum + 3 named presets (default / 2h-14-layer /
// 10h-heavy-tailed). All previously buried in the god file at
// lines ~1556-1705 (~150 LOC).
//
// Pre-this-batch: HybridBenchTuning + HybridBenchConfig + SmokeMode
// + presets all inline in SampleHostModel.swift.
// Post-this-batch: dedicated file owns the bench-config invariant.
//
// Doctrine pins:
//   - M710 chapter 一百九十一 user vision: "大部分 固定 数值 都可以
//     改成 完全 flexible 程序化 生成". Every parameter that used
//     to be a magic number is in this struct, defaults from
//     `HybridBenchTuning`, can be overridden at runtime.
//   - 5 SmokeMode cases preserve chapter 178 → 208 trajectory:
//     canonical / 14-layer-smoke / heavy-tailed / benign / raw-llm
//   - 3 named presets pin user-vision smoke configs (default 8h /
//     2h fourteen-layer / 10h heavy-tailed)
//   - 不变量 #1-#3 + Red line 7: ✓ pure config, no decision
//   - chapter 一百九十二 single-source-of-truth: bench-config
//     invariant owned by one file

import Foundation

/// M672 chapter 一百八十五 — typed bench tuning constants.
/// M710 chapter 一百九十一 — these become DEFAULTS for the
/// procedural `HybridBenchConfig` struct. The bench loop now
/// reads from a per-run config, not these constants. Kept
/// here as the doctrinal-default reference, used as initial
/// values when the user has not customized.
enum HybridBenchTuning {
    /// Verbosity classification threshold (chars). Must match
    /// Python `VERBOSITY_THRESHOLD_CHARS` in chenglu_feature_schema.
    static let verbosityThresholdChars: Int = 1500
    /// Sigmoid → class threshold (binary heads).
    static let sigmoidClassThreshold: Double = 0.5
    /// `Task.yield()` cadence — every Nth iter.
    static let yieldEveryNIters: Int = 1
    /// Truncation cap on LLM body for substrate post-LLM
    /// observation (chars).
    static let postLLMBodyTruncationChars: Int = 4000
}

/// M710 chapter 一百九十一 — procedural bench config replacing
/// scattered hardcoded values. User vision: "大部分 固定 数值
/// 都可以 改成 完全 flexible 程序化 生成". Every parameter that
/// used to be a magic number / `let` constant is now in this
/// struct, defaults from `HybridBenchTuning`, can be overridden
/// at runtime.
///
/// Smoke modes (M711):
///  - `.canonical`: chapter 178+ default — coprime stride rotation
///    over 40,320-combination signature catalog
///  - `.fourteenLayer`: bench cycles through 14 distinct
///    `(signature, risk, workflow)` profiles, each targeting a
///    specific BAS substrate layer's behavior, so a 2h smoke
///    exercises every layer ~equally
struct HybridBenchConfig: Codable, Sendable, Equatable {
    enum SmokeMode: String, Codable, CaseIterable, Sendable {
        case canonical = "canonical"
        case fourteenLayer = "14-layer-smoke"
        /// M719 chapter 一百九十二 — production-realistic heavy-tailed
        /// layer distribution. Per-iter: weighted-random layer pick
        /// from `SampleHostBenchPressureMixer.layerWeights` (L11
        /// 25% / L9 18% / L8 12% / etc). Adversarial mutator
        /// (M720) is ALSO active in this mode, layered on top of
        /// the catalog prompt at ~5% probability.
        case heavyTailed = "heavy-tailed"
        /// M772 chapter 二百五 — benign prompt catalog mode.
        /// chapter 196+200+204 finding: chapter-173+ adversarial
        /// catalog produces 100% substrate-skip across all
        /// workflowProfiles. For training-data accumulation we
        /// need substrate's ENGAGE path — `.benign` mode swaps
        /// in `SampleHostBenignPromptCatalog` (80 factual /
        /// translation / math / cooking / programming queries
        /// designed so substrate's L7+L11 evaluation routes to
        /// `.answer` permit). Risk forced to `.low`.
        case benign = "benign"
        /// M783 chapter 二百八 — bench-data-only mode (ADR-006).
        /// chapter 207 verified substrate's calibrateRisk()
        /// internally recomputes risk from contextFrame +
        /// thoughtFrame + host state, IGNORING the bench's
        /// riskLevel argument. Even on .benign + .primary +
        /// pinned-low signature, substrate routes 100% to
        /// `.delay` permit because hostGuardrailPressure +
        /// constitutionSignals + courtSignals push totalRisk
        /// above mediumThreshold by design.
        ///
        /// Doctrine pin (ADR-006): `.rawLLM` bench mode is
        /// OBSERVABILITY ONLY:
        ///   - substrate STILL runs (audit accumulates)
        ///   - permitMode STILL recorded in row
        ///   - BUT dispatchPolicy is FORCED to .singleLLM
        ///     bypassing substrate's permit gate
        ///   - LLM (AFM/Gemma) actually fires per iter
        ///   - Resulting data is NEVER used for production
        ///     permit decisions — only for training the
        ///     ChengluPreflight router (signature → AFM/Gemma)
        ///   - Red line 7 (HINT-ONLY observability) held
        ///   - 不变量 #2 (神经不掌权) held — substrate's
        ///     production decisions unchanged
        case rawLLM = "raw-llm"
    }
    var durationHours: Double
    var strideRotationCSV: String
    var rotationPeriodIter: Int
    var mutationSeedCount: Int
    var jsonlRotationMB: Int
    // M710 — was hardcoded HybridBenchTuning; now flex.
    var verbosityThresholdChars: Int
    var sigmoidClassThreshold: Double
    var yieldEveryNIters: Int
    var postLLMBodyTruncationChars: Int
    // M711 — smoke profile selector
    var smokeMode: SmokeMode

    static let `default` = HybridBenchConfig(
        durationHours: 8.0,
        strideRotationCSV: "5041,5039,5051,5077,7919",
        rotationPeriodIter: 11_300,
        mutationSeedCount: 5,
        jsonlRotationMB: 15,
        verbosityThresholdChars:
            HybridBenchTuning.verbosityThresholdChars,
        sigmoidClassThreshold:
            HybridBenchTuning.sigmoidClassThreshold,
        yieldEveryNIters:
            HybridBenchTuning.yieldEveryNIters,
        postLLMBodyTruncationChars:
            HybridBenchTuning.postLLMBodyTruncationChars,
        smokeMode: .canonical)

    /// 2h smoke preset — chapter 一百九十一 user vision:
    /// "真机 跑2小时冒烟 最好 14层 每层都冒烟测试".
    static let twoHourFourteenLayerSmoke = HybridBenchConfig(
        durationHours: 2.0,
        strideRotationCSV: "5041,5039,5051,5077,7919",
        rotationPeriodIter: 11_300,
        mutationSeedCount: 5,
        jsonlRotationMB: 15,
        verbosityThresholdChars:
            HybridBenchTuning.verbosityThresholdChars,
        sigmoidClassThreshold:
            HybridBenchTuning.sigmoidClassThreshold,
        yieldEveryNIters:
            HybridBenchTuning.yieldEveryNIters,
        postLLMBodyTruncationChars:
            HybridBenchTuning.postLLMBodyTruncationChars,
        smokeMode: .fourteenLayer)

    /// 10h smoke preset — chapter 一百九十二 user vision:
    /// "全面进化 满意之后 跑 10小时 冒烟 最学习". Heavy-tailed
    /// pressure mixer + adversarial mutator (5%) for max signal
    /// per minute. JSONL rotation bumped to 25 MB / shard so 10h
    /// at ~5 iter/s lands ~7-9 shards. Crash checkpoints every
    /// 1000 iters; thermal/battery gate auto-pauses on critical.
    static let tenHourHeavyTailed = HybridBenchConfig(
        durationHours: 10.0,
        strideRotationCSV: "5041,5039,5051,5077,7919",
        rotationPeriodIter: 11_300,
        mutationSeedCount: 5,
        jsonlRotationMB: 25,
        verbosityThresholdChars:
            HybridBenchTuning.verbosityThresholdChars,
        sigmoidClassThreshold:
            HybridBenchTuning.sigmoidClassThreshold,
        yieldEveryNIters:
            HybridBenchTuning.yieldEveryNIters,
        postLLMBodyTruncationChars:
            HybridBenchTuning.postLLMBodyTruncationChars,
        smokeMode: .heavyTailed)
}
