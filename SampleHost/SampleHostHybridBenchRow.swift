// MARK: - SampleHostHybridBenchRow
//
// chapter 二百十四 / M795 — extracted from SampleHostModel.swift.
//
// JSONL row schema for hybrid bench output. Single Codable struct
// with ~50 fields recording: substrate routing / router prediction /
// LLM execution / final outcome / 5-head CoreML predictions /
// pressure context / 14-layer smoke tag / safety-kit hints (row
// checksum / anomaly flags / pressure profile / mutator kind /
// drift sigma / pause skip).
//
// Pre-this-batch: ~187 LOC of schema buried in god file alongside
// orchestrator code. Field doc-comments span chapters 一百七十八
// → 一百九十二 (router / dispatch / closed-loop / pressure / safety
// kit) but the schema invariant is fragmented from its consumers.
//
// Post-this-batch: schema lives next to `SAMPLE_HOST_HYBRID_BENCH_-
// ROW_SCHEMA_VERSION` constant in dedicated file. Future schema
// bumps go to one file. Future field additions inherit the existing
// chapter-tagged doc-comment style. Decoder/encoder round-trip
// tests (chapter 一百八十五+) continue working byte-identical.
//
// Doctrine pins (chapter 二百九/二百十/二百十一/二百十二/二百十三
// architectural-deconstruction trajectory):
//   - Pure value-type carve-out, no behavioral change
//   - 不变量 #1-#3:                     ✓ schema is data only
//   - Red line 7 (HINT-ONLY):           ✓ row is observability,
//     not decision-making
//   - chapter 一百九十二 single-source-of-truth: schema invariant
//     owned by one file
//   - chapter 一百八十五 schema-version stamp doctrine: schema-
//     Version field optional; old rows decode as nil

import Foundation

/// M672 chapter 一百八十五 — explicit JSONL row schema version.
/// Bump on any breaking field change so downstream analyzers
/// can detect format upgrades. Optional decoding allows old rows
/// (without this field) to load as nil.
/// M712 chapter 一百九十一 bumped to "8" — added smoke-mode +
/// targetLayer fields enabling 14-layer per-layer coverage
/// analysis (user vision: "14层 每层都冒烟测试").
/// M716+M718-M720 chapter 一百九十二 bumped to "9" — added
/// rowChecksum (SHA-256 integrity), anomalyFlags (watcher hints),
/// pressureProfile (heavy-tailed mixer), adversarialKind (mutator
/// classification), driftSigma (length MAE drift), pauseSkipped
/// (thermal/battery gate trace).
let SAMPLE_HOST_HYBRID_BENCH_ROW_SCHEMA_VERSION = "9"

struct SampleHostHybridBenchRow: Codable, Sendable, Equatable {
    /// M672 chapter 一百八十五 — schema version stamp.
    /// Optional so old rows (M664-) decode as nil.
    var schemaVersion: String? = SAMPLE_HOST_HYBRID_BENCH_ROW_SCHEMA_VERSION
    let timestamp: String
    let iteration: Int
    let seed: Int
    let stride: Int
    let mutationSeed: Int
    let signature: SampleHostPromptSignature
    let prompt: String
    // Substrate routing
    let auditCodeCount: Int
    let permitMode: String
    // Router prediction
    let routerVersion: String  // "v0-rule-based-binary-LR"
    let routerPredictedRoute: String  // "afm" or "gemma"
    let routerProbability: Double  // afm_success_probability
    // Actual LLM execution
    let firstTriedLLM: String  // "afm" or "gemma"
    let firstTriedStatus: String  // "ok" / "afm-error" / "gemma-error"
    let firstTriedBody: String
    let firstTriedDurationMs: Double
    let fallbackTriedLLM: String?  // nil if first try succeeded
    let fallbackStatus: String?
    let fallbackBody: String?
    let fallbackDurationMs: Double?
    // Final outcome
    let actualRoute: String
    // "afm-predicted-ok" / "gemma-predicted-ok" /
    // "afm-fallback-to-gemma-ok" / "gemma-fallback-to-afm-ok" /
    // "both-failed" / "skipped-by-substrate-{block,delay,replace}"
    let routerHit: Bool
    let totalDurationSeconds: Double
    let errorMessage: String?
    // M628 chapter 一百七十八 — substrate→LLM dispatch coupling.
    // Records HOW substrate's permit mode shaped LLM dispatch.
    // - dispatchPolicy: the typed policy derived from permitMode
    //   (e.g. "skip-block" / "single-llm" / "both-llms" / etc.)
    // - dispatchTaken: actual execution path observed
    // - draftOnly: true if substrate marked output as draft-only
    // - llmSkipped: true if substrate prevented LLM call entirely
    let dispatchPolicy: String?
    let dispatchTaken: String?
    let draftOnly: Bool?
    let llmSkipped: Bool?
    // M630 chapter 一百七十八 — closed-loop observation.
    // After LLM responds, substrate observes the response.
    // If post-LLM permit mode differs from pre-LLM, we know the
    // generated body shifted substrate's verdict (e.g. content
    // would have been blocked if substrate saw it).
    let postLLMPermitMode: String?
    let postLLMAuditCodeCount: Int?
    let postLLMShifted: Bool?  // pre-LLM mode != post-LLM mode
    // M633-M635 chapter 一百七十九 — 2nd CoreML head:
    // ChengluPermitPredict predicts substrate's permit class from
    // signature features. Runs alongside substrate (red line:
    // never replaces). Records prediction-vs-actual agreement.
    // - permitPredictBlockProb: model output probability ∈ [0,1]
    // - permitPredictClass: "block" / "non-block" / nil if model
    //   unavailable
    // - permitPredictAgreement: nil if model unavailable;
    //   else true if predicted class matches substrate's actual
    //   permit-mode being .block (predicted=block && actual=block)
    //   or both non-block.
    let permitPredictBlockProb: Double?
    let permitPredictClass: String?
    let permitPredictAgreement: Bool?
    // M675 chapter 一百八十六 — B7 fix (HIGH):
    // permitPredictAgreement is binary (block / non-block) but
    // substrate has 9 actual permit modes. Pre-fix, a model
    // predicting "non-block" while substrate routed to .delay
    // counted as "agree" — losing 8-way semantic signal.
    // permitPredictDetailedAgreement records the 2-tuple
    // "predicted-class:actual-permit" so downstream analytics
    // can do 9-way confusion matrix without re-deriving from
    // separately-stored fields. Format: "block:block" /
    // "non-block:delay" / "non-block:answer" / etc.
    let permitPredictDetailedAgreement: String?
    // M666 chapter 一百八十五 — B1 fix (CRITICAL):
    // routerHit was contaminated by skip/bothLLMs/localOnly
    // branches where router prediction was OVERRIDDEN by
    // substrate. routerOverridden = true means substrate
    // bypassed router (skip-block / bothLLMs / localOnly),
    // so routerHit/Miss tally for this row is router-irrelevant.
    // Downstream analytics filtering on `routerOverridden ==
    // false` get the genuine router-accuracy signal.
    let routerOverridden: Bool?
    // M638-M641 chapter 一百八十 — 3rd + 4th CoreML heads:
    // ChengluLengthHead (regression on AFM body chars) +
    // ChengluLatencyHead (regression on AFM duration ms). Both
    // run before LLM call as UI pre-warm hints. Recorded for
    // empirical accuracy analysis: actualLength - predictedLength
    // is the residual error per row.
    // - lengthPredicted: predicted afmBodyLength chars (nil if
    //   model unavailable)
    // - lengthError: actual - predicted (nil if model or LLM
    //   unavailable)
    // - latencyPredictedMs: predicted afmDurationMs (nil if model
    //   unavailable)
    // - latencyErrorMs: actual - predicted (nil if model or LLM
    //   unavailable)
    let lengthPredicted: Double?
    let lengthError: Double?
    let latencyPredictedMs: Double?
    let latencyErrorMs: Double?
    // M661 chapter 一百八十三 — 5th CoreML head: verbosity_class
    // (binary, P(body > 1500 chars)). Demonstrates cheap head-add
    // via shared encoder. Value 0..1 from MultiHead's 5th output.
    // verbosityCorrect: nil if no LLM body or no MultiHead;
    //                   else true if predicted class
    //                   (verbosityProb >= 0.5) matches actual
    //                   (firstBody.count > 1500).
    let verbosityProbability: Double?
    let verbosityCorrect: Bool?
    // M703 chapter 一百九十 — pressure context (HIGH NEW value).
    // Captured per iter so future retrain pipeline (M704
    // bench_to_train.py) can stratify training by situation.
    // User's vision: "different scenarios / different pressures
    // / different assumptions all handled" — requires the row
    // to record the situation so retrain can learn the manifold.
    /// `ProcessInfo.thermalState` rawValue — "nominal" / "fair"
    /// / "serious" / "critical". Substrate behavior may shift
    /// under thermal pressure.
    let thermalState: String?
    /// `UIDevice.batteryLevel` clamped [0, 1]. -1 if unknown
    /// (e.g. battery monitoring disabled). Helps retrain learn
    /// low-battery / charging patterns.
    let batteryLevel: Double?
    /// `ProcessInfo.isLowPowerModeEnabled`. Low-power mode
    /// throttles CoreML / network / yields differently.
    let lowPowerMode: Bool?
    /// `Calendar.current.component(.hour, from: timestamp)`
    /// 0-23. Time-of-day patterns (user fatigue / context).
    let hourOfDay: Int?
    // M712 chapter 一百九十一 — 14-layer smoke coverage tags.
    // smokeMode: "canonical" or "14-layer-smoke" — lets replay
    // tool stratify analyses by mode.
    // targetLayer (1-14) populated when smokeMode is
    // "14-layer-smoke"; identifies which BAS substrate layer
    // this iter targeted via the FourteenLayerSmokeProfile.
    let smokeMode: String?
    let targetLayer: Int?
    let targetLayerName: String?
    // M716 chapter 一百九十二 — SHA-256 of canonical encoded row
    // (excluding this field). nil on legacy rows. Validator
    // recomputes; mismatch = corrupted line. Hex lowercase.
    var rowChecksum: String?
    // M718 chapter 一百九十二 — anomaly watcher hints. Empty when
    // healthy. Multi-flag possible. Examples:
    //   "substrate-stuck:answer" — same permitMode for 100 iters
    //   "llm-stuck:all-empty"    — empty body for 100 iters
    //   "nan-spike:3"            — 3 regression outputs were NaN
    //   "nan-cluster:35/100"     — 35% of last 100 iters had NaN
    //   "drift:length-mae:3.2-sigma" — Welford drift on length MAE
    let anomalyFlags: [String]?
    // M719 chapter 一百九十二 — pressure profile name when
    // smokeMode == "heavy-tailed". E.g. "heavy-tail-L11-risk-gate"
    // / "heavy-tail-L9-candidates". nil when smokeMode != heavy.
    let pressureProfile: String?
    // M720 chapter 一百九十二 — adversarial mutation kind applied
    // to this iter's prompt. nil when no mutation. Values:
    // empty / one-char / giant-10k / unicode-mixed / emoji-only /
    // control-chars / repeated-tokens / mixed-languages.
    let adversarialKind: String?
    // M721 chapter 一百九十二 — number of std-deviations the
    // length-MAE residual was above the running mean for this
    // iter. nil when monitor empty / regression unavailable.
    let driftSigma: Double?
    // M717 chapter 一百九十二 — true iff thermal/battery gate
    // paused this iter. When true, all LLM-execution fields are
    // canned (firstStatus="paused-by-thermal-gate" etc.).
    let pauseSkipped: Bool?
}
