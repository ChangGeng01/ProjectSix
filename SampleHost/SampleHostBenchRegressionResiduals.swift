// MARK: - SampleHostBenchRegressionResiduals
//
// chapter 二百四十三 / M825 — extracted from
// SampleHostHybridBenchEntry.swift bench loop body.
//
// Per-iter regression residual computation (chapter 一百八十 / M642
// + chapter 一百八十三 / M661): given the actually-served LLM body,
// compute residual error against CoreML head predictions.
//
//   - Length residual: actual body chars - predicted (chapter
//     一百八十 / M638)
//   - Latency residual: actual duration ms - predicted (chapter
//     一百八十 / M641)
//   - Verbosity correctness: actual long/short matches predicted
//     class (chapter 一百八十三 / M661 — binary 5th head)
//
// Plus Welford running-mean updates (chapter 一百八十五 / M669 +
// chapter 一百八十八 / M689 — numerically stable over 144K samples).
//
// Pre-this-batch: ~72 LOC of inline residual math + Welford updates +
// counter increments in SampleHostHybridBenchEntry.swift bench loop.
//
// Post-this-batch: typed `SampleHostBenchRegressionResiduals` value
// bundle + extension method on SampleHostModel. Bench loop calls
// one method, reads typed result. Welford accumulation + correctness
// counters wrapped in applyIfActive(generation) for chapter 二百七
// / M779 stale-task safety.
//
// Doctrine pins:
//   - chapter 一百八十 / M642: residual computation skipped on
//     llmSkipped iters (no real LLM body to compare).
//   - chapter 一百八十五 / M670 fix B9: use servedBody (firstBody
//     if non-empty else fallbackBody) for residuals — bothLLMs
//     branch with empty AFM body uses Gemma's body.
//   - chapter 一百八十五 / M669 + chapter 一百八十八 / M689 Welford
//     B8: numerically stable running mean recurrence
//     M_n = M_{n-1} + (x_n - M_{n-1}) / n.
//   - chapter 一百九十一 / M710: thresholds read live from
//     @Published flex (verbosityThresholdChars / sigmoidThreshold).
//   - chapter 二百七 / M779 + chapter 一百八十九 / M696: Welford
//     recurrence wrapped in applyIfActive so stale-generation
//     tasks don't pollute counters.
//   - 不变量 #1-#3 + Red line 7: ✓ pure derive + observability.

import Foundation

/// Typed regression residual result.
struct SampleHostBenchRegressionResiduals: Sendable, Equatable {
    let lengthError: Double?
    let latencyErrorMs: Double?
    let verbosityCorrect: Bool?

    static let skipped = SampleHostBenchRegressionResiduals(
        lengthError: nil,
        latencyErrorMs: nil,
        verbosityCorrect: nil)
}

extension SampleHostModel {
    /// chapter 一百八十 / M642 + chapter 一百八十三 / M661 doctrine
    /// — compute regression residuals against actual LLM outputs +
    /// update Welford running means + verbosity correctness counter.
    /// Skipped iters (`llmSkipped`) or empty served body short-circuit.
    @MainActor
    func computeRegressionResiduals(
        llmSkipped: Bool,
        servedBody: String,
        firstDurationMs: Double,
        lengthPredicted: Double?,
        latencyPredictedMs: Double?,
        verbosityProbability: Double?,
        verbosityThresholdChars: Int,
        sigmoidClassThreshold: Double,
        generation: Int
    ) -> SampleHostBenchRegressionResiduals {
        guard !llmSkipped, !servedBody.isEmpty else {
            return .skipped
        }

        var lengthError: Double? = nil
        var latencyErrorMs: Double? = nil
        var verbosityCorrect: Bool? = nil

        if let pred = lengthPredicted {
            let actual = Double(servedBody.count)
            let err = actual - pred
            lengthError = err
            // chapter 一百八十五 / M669 Welford running mean (numerically
            // stable over 144K samples). chapter 一百八十八 / M689 B8
            // retire: only Count + Running. chapter 一百八十九 / M696
            // wrap recurrence in applyIfActive too.
            applyIfActive(generation) {
                self.hybridBenchLengthMAECount += 1
                let n = Double(self.hybridBenchLengthMAECount)
                self.hybridBenchLengthMAERunning +=
                    (abs(err) - self.hybridBenchLengthMAERunning) / n
            }
        }

        if let pred = latencyPredictedMs {
            let err = firstDurationMs - pred
            latencyErrorMs = err
            applyIfActive(generation) {
                self.hybridBenchLatencyMAECount += 1
                let n = Double(self.hybridBenchLatencyMAECount)
                self.hybridBenchLatencyMAERunningMs +=
                    (abs(err) - self.hybridBenchLatencyMAERunningMs) / n
            }
        }

        if let prob = verbosityProbability {
            // chapter 一百九十一 / M710 — read live config
            let actualLong = servedBody.count > verbosityThresholdChars
            let predictedLong = prob >= sigmoidClassThreshold
            let correct = actualLong == predictedLong
            verbosityCorrect = correct
            if correct {
                applyIfActive(generation) {
                    self.hybridBenchVerbosityCorrect += 1
                }
            } else {
                applyIfActive(generation) {
                    self.hybridBenchVerbosityWrong += 1
                }
            }
        }

        return SampleHostBenchRegressionResiduals(
            lengthError: lengthError,
            latencyErrorMs: latencyErrorMs,
            verbosityCorrect: verbosityCorrect)
    }
}
