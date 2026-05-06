// MARK: - SampleHostBenchCoreMLBundle
//
// chapter 二百四十 / M822 — extracted from
// SampleHostHybridBenchEntry.swift bench loop body.
//
// Typed value-bundle for the 5 CoreML heads invoked per bench iter:
//
//   1. ChengluPreflight (chapter 一百七十七 §177 / M619) — router
//      AFM-vs-Gemma binary classifier
//   2. ChengluMultiHead (chapter 一百八十一 / M649) — single-call
//      4-output (block_prob / length / latency / verbosity)
//   3. ChengluPermitPredict (chapter 一百七十九 / M635) — fallback
//      when MultiHead unavailable (block-vs-non-block)
//   4. ChengluRegressionHead.length (chapter 一百八十 / M638-M641)
//      — fallback when MultiHead unavailable (predicted body chars)
//   5. ChengluRegressionHead.latency (chapter 一百八十 / M638-M641)
//      — fallback when MultiHead unavailable (predicted duration ms)
//
// Pre-this-batch: ~100 LOC of inline 5-head invocation + agreement
// derive in `SampleHostHybridBenchEntry.swift` bench loop body.
// Permit-predict agreement was computed via two `let X: Type? = {...}()`
// closures inline.
//
// Post-this-batch: dedicated value type. Bench loop calls
// `SampleHostBenchCoreMLBundle.predict(features:)` once and reads
// typed fields. Agreement helper `permitPredictAgreement(actual-
// PermitMode:)` and `permitPredictDetailedAgreement(...)` provide
// chapter 一百七十九 / M635 + chapter 一百八十六 / M675 agreement
// derivation as pure functions on the bundle.
//
// Doctrine pins:
//   - MultiHead-FIRST then per-head fallback (chapter 一百八十一
//     / M649 doctrine: 1 inference call beats 4 inference calls
//     when MultiHead is loaded).
//   - Agreement is BINARY (block vs non-block) but row also records
//     9-way DetailedAgreement (chapter 一百八十六 / M675 fix B7).
//   - Pure derive: bundle has no @Published, no actor, no I/O.
//     Bench loop owns the increment of hits/misses counters
//     separately via applyIfActive(myGen).
//   - 不变量 #1-#3 + Red line 7: ✓ pure inference + derive.
//   - chapter 二百十一 single-source-of-truth: 5-head invocation
//     invariant owned by one file.

import Foundation

struct SampleHostBenchCoreMLBundle: Sendable {
    /// chapter 一百七十七 §177 — router decision (nil if model
    /// unavailable; bench loop falls back to default afm + 0.5).
    let routerDecision: ChengluPreflightDecision?

    /// chapter 一百八十一 / M649 — 4-output multi-head inference
    /// (nil if model unavailable).
    let multiHead: ChengluMultiHeadPrediction?

    /// chapter 一百七十九 / M635 — substrate permit predict (block
    /// probability ∈ [0,1]). When `multiHead` is non-nil, this is
    /// `multiHead.blockProbability`. Else falls back to the
    /// standalone PermitPredict head. nil if both unavailable.
    let permitPredictBlockProb: Double?

    /// chapter 一百七十九 / M635 — "block" / "non-block" classification.
    /// nil if both MultiHead AND PermitPredict are unavailable.
    let permitPredictClass: String?

    /// chapter 一百八十 / M638 — predicted AFM body chars
    /// (nil if both MultiHead AND LengthHead unavailable).
    let lengthPredicted: Double?

    /// chapter 一百八十 / M641 — predicted AFM duration ms
    /// (nil if both MultiHead AND LatencyHead unavailable).
    let latencyPredictedMs: Double?

    /// chapter 一百八十三 / M661 — 5th head: predicted P(body > 1500
    /// chars). Source: MultiHead's verbosityProbability output. nil
    /// when MultiHead unavailable.
    let verbosityProbability: Double?

    // MARK: - Computed defaults (chapter 一百七十七 §177 doctrine)

    /// Default to .afm route when router unavailable.
    var routerRoute: ChengluPreflightDecision.Route {
        routerDecision?.route ?? .afm
    }

    /// Default to 0.5 (uncertain) when router unavailable.
    var routerProb: Double {
        routerDecision?.afmSuccessProbability ?? 0.5
    }

    /// "missing" sentinel when router unavailable.
    var routerVersion: String {
        routerDecision?.modelVersion ?? "missing"
    }

    /// Default to .high (no v0.2 dual-LLM uncertain-zone trigger)
    /// when router unavailable.
    var routerConfidence: ChengluPreflightDecision.Confidence {
        routerDecision?.confidence ?? .high
    }

    // MARK: - Predict factory

    /// chapter 一百八十一 / M649 doctrine: try MultiHead FIRST (1
    /// inference call, 4 outputs). Fall back to separate per-head
    /// models if MultiHead missing. chapter 一百七十七 §177 router
    /// runs unconditionally (it's the load-bearing decision).
    ///
    /// `@MainActor`: the underlying CoreML `.shared` singletons are
    /// MainActor-isolated for thread-safety on the inference cache.
    @MainActor
    static func predict(
        features: ChengluPromptFeatures
    ) -> SampleHostBenchCoreMLBundle {
        let routerDecision = ChengluPreflightInference.shared
            .predictOrNil(features: features)
        let multiHead = ChengluMultiHeadInference.shared
            .predictOrNil(features: features)

        // chapter 一百七十九 / M635 — 2nd head (PermitPredict).
        let permitPredictBlockProb: Double?
        let permitPredictClass: String?
        if let mh = multiHead {
            permitPredictBlockProb = mh.blockProbability
            permitPredictClass = mh.blockProbability >= 0.5
                ? "block" : "non-block"
        } else {
            let permitDecision = ChengluPermitPredictInference
                .shared.predictOrNil(features: features)
            permitPredictBlockProb =
                permitDecision?.blockProbability
            permitPredictClass =
                permitDecision?.predictedClass.rawValue
        }

        // chapter 一百八十 / M638-M641 — 3rd + 4th heads
        // (LengthHead + LatencyHead).
        let lengthPredicted: Double?
        let latencyPredictedMs: Double?
        if let mh = multiHead {
            lengthPredicted = mh.predictedBodyLength
            latencyPredictedMs = mh.predictedDurationMs
        } else {
            let lengthDecision = ChengluRegressionHeadInference
                .lengthHead.predictOrNil(features: features)
            let latencyDecision = ChengluRegressionHeadInference
                .latencyHead.predictOrNil(features: features)
            lengthPredicted = lengthDecision?.predicted
            latencyPredictedMs = latencyDecision?.predicted
        }

        return SampleHostBenchCoreMLBundle(
            routerDecision: routerDecision,
            multiHead: multiHead,
            permitPredictBlockProb: permitPredictBlockProb,
            permitPredictClass: permitPredictClass,
            lengthPredicted: lengthPredicted,
            latencyPredictedMs: latencyPredictedMs,
            verbosityProbability: multiHead?.verbosityProbability)
    }

    // MARK: - Agreement derivations

    /// chapter 一百七十九 / M635 — agreement: predicted class
    /// matches substrate's actual .block decision. Returns nil when
    /// model unavailable (no class to compare).
    func permitPredictAgreement(
        actualPermitMode: String
    ) -> Bool? {
        guard let cls = permitPredictClass else { return nil }
        let actualIsBlock = (actualPermitMode == "block")
        let predictedIsBlock = (cls == "block")
        return actualIsBlock == predictedIsBlock
    }

    /// chapter 一百八十六 / M675 — B7 fix (HIGH): record the 2-tuple
    /// "predicted-class:actual-permit" so analyses get the 9-way
    /// confusion matrix info. Format examples: "block:block" /
    /// "non-block:delay" / "non-block:answer" / "block:replace".
    /// nil when model unavailable.
    func permitPredictDetailedAgreement(
        actualPermitMode: String
    ) -> String? {
        guard let cls = permitPredictClass else { return nil }
        return "\(cls):\(actualPermitMode)"
    }
}
