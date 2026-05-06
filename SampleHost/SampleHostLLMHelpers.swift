// MARK: - SampleHostLLMHelpers
//
// chapter 二百三十三 / M815 — extracted from SampleHostModel.swift.
//
// 6 LLM adapter helpers + timeout wrappers + recovery extracted
// to dedicated extension file:
//
//   - callAFM(prompt:)               — Apple FoundationModels direct call
//   - callGemma(prompt:)             — MLX Gemma 4 E2B + LoRA M247 call
//   - ensureGemmaAdapter()           — singleton-load gate (chapter 一百
//                                      七十七 §177 deep-review #2 + #4)
//   - callAFMWithTimeout(...)        — chapter 一百九十五 / M735 wrapper
//   - callGemmaWithTimeout(...)      — chapter 一百九十五 / M735 wrapper
//   - recordTimeoutIfApplicable(_:)  — chapter 二百七 / M780 helper
//
// Pre-this-batch: ~188 LOC of `private` / `fileprivate` methods on
// SampleHostModel. Cross-file extension extraction was blocked by
// `private var gemmaAdapter` / `gemmaLoadInFlight` / `gemmaLoraLoaded`
// + `private(set) var hybridGemmaLoadStatus` / `hybridBenchLLMTimeout-
// Count` access barriers.
//
// Post-this-batch: dedicated extension file. Access barriers
// promoted in chapter 二百三十三 (M815 promotion) so extension can
// access state directly. Methods promoted from `private` /
// `fileprivate` to `internal func` for cross-file access.
//
// Doctrine pins:
//   - chapter 一百七十六 §176.13 / M609: AFM via FoundationModels
//     (foreground-only modelmanagerd policy on macOS 26 / iOS 26).
//   - chapter 一百七十七 §177 / M619: Gemma via MLX with LoRA M247
//     (chapter 176 §176.10 3.6× better convergence + learned
//     [RISK] / [NEEDS_PERMIT] markers).
//   - chapter 一百九十五 / M735: timeout is BAIL-OUT not session-
//     killer. Throws SampleHostBenchLLMTimeoutError so bench-loop
//     catch records clean failure.
//   - chapter 二百七 / M780: counter mutation is MainActor +
//     applyIfActive guard so stale-generation tasks don't pollute
//     post-Stop counters.
//   - chapter 二百三十三 single-source-of-truth: LLM-adapter
//     invocation invariant owned by one file.

import Foundation
import BASHostKit
#if canImport(BASOrgan)
import BASOrgan
#endif
#if canImport(BASMLXAdapter)
import BASMLXAdapter
#endif
#if canImport(FoundationModels)
import FoundationModels
#endif

extension SampleHostModel {
    /// M780 chapter 二百七 — DEEP-REVIEW FIX C2 helper.
    /// Increment timeoutCount via applyIfActive when error is a
    /// LLM-timeout. Stale-generation tasks see no-op. Called from
    /// every bench-loop catch where callAFMWithTimeout /
    /// callGemmaWithTimeout might have thrown.
    @MainActor
    func recordTimeoutIfApplicable(
        _ error: Error, generation: Int
    ) {
        if case SampleHostBenchLLMTimeoutError.timeoutExceeded = error {
            applyIfActive(generation) {
                self.hybridBenchLLMTimeoutCount += 1
            }
        }
    }

    /// M735 chapter 一百九十五 — wrap callAFM with per-iter
    /// timeout. Bench loop uses this in the .singleLLM confident
    /// path so a hung AFM call (~30s+) doesn't freeze the whole
    /// 10h run; it bails after `seconds` and lets the fallback
    /// path try Gemma.
    ///
    /// Doctrine: TIMEOUT IS BAIL-OUT, not session-killer. Throws
    /// `SampleHostBenchLLMTimeoutError.timeoutExceeded` so the
    /// bench-loop catch can record a clean failure. `hybridBenchLLMTimeoutCount`
    /// is incremented so the dashboard shows live timeout rate.
    @MainActor
    func callAFMWithTimeout(
        prompt: String, seconds: Double
    ) async throws -> String {
        let llmTask = Task { [weak self] () async throws -> String in
            guard let self else {
                throw NSError(domain: "model-deinit", code: -1)
            }
            return try await self.callAFM(prompt: prompt)
        }
        let timeoutTask = Task {
            try? await Task.sleep(
                nanoseconds: UInt64(max(0.001, seconds) * 1_000_000_000))
            llmTask.cancel()
        }
        do {
            let body = try await llmTask.value
            timeoutTask.cancel()
            return body
        } catch {
            timeoutTask.cancel()
            if llmTask.isCancelled {
                // M780 chapter 二百七 — DEEP-REVIEW FIX C2:
                // counter mutation moved to bench-loop catch
                // wrapped in applyIfActive(myGen). Helper is
                // pure error path; caller handles state.
                throw SampleHostBenchLLMTimeoutError
                    .timeoutExceeded(seconds: seconds)
            }
            throw error
        }
    }

    /// M735 chapter 一百九十五 — Gemma equivalent of
    /// `callAFMWithTimeout`. Same doctrine.
    @MainActor
    func callGemmaWithTimeout(
        prompt: String, seconds: Double
    ) async throws -> String {
        let llmTask = Task { [weak self] () async throws -> String in
            guard let self else {
                throw NSError(domain: "model-deinit", code: -1)
            }
            return try await self.callGemma(prompt: prompt)
        }
        let timeoutTask = Task {
            try? await Task.sleep(
                nanoseconds: UInt64(max(0.001, seconds) * 1_000_000_000))
            llmTask.cancel()
        }
        do {
            let body = try await llmTask.value
            timeoutTask.cancel()
            return body
        } catch {
            timeoutTask.cancel()
            if llmTask.isCancelled {
                // M780 chapter 二百七 — DEEP-REVIEW FIX C2:
                // counter mutation moved to bench-loop catch
                // wrapped in applyIfActive(myGen). Helper is
                // pure error path; caller handles state.
                throw SampleHostBenchLLMTimeoutError
                    .timeoutExceeded(seconds: seconds)
            }
            throw error
        }
    }

    /// Call AFM with a prompt. Throws on error/guardrail.
    func callAFM(prompt: String) async throws -> String {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            let session = LanguageModelSession()
            let response = try await session.respond(to: prompt)
            return response.content
        }
        #endif
        throw NSError(domain: "AFMUnavailable", code: -1)
    }

    /// Call Gemma 4 E2B (MLX) with a prompt. Lazy-loads on first
    /// call + applies LoRA M247 chat-template adapter (chapter 176
    /// §176.10 — 3.6× better convergence + learned [RISK]/[NEEDS_PERMIT]
    /// markers). Throws on error.
    ///
    /// M627 deep-review fix #2 + #4: load is gated through a single
    /// in-flight Task so concurrent callers share, and LoRA load
    /// status is tracked separately from adapter readiness so a
    /// failed LoRA doesn't poison subsequent retries.
    func callGemma(prompt: String) async throws -> String {
        #if canImport(BASMLXAdapter)
        let adapter = try await ensureGemmaAdapter()
        let request = BASOrganRequest(
            requestID: "hybrid-prompt",
            role: .scout,
            preset: .scout,
            instruction: prompt)
        let draft = try await adapter.draft(request)
        return draft.body
        #else
        throw NSError(
            domain: "GemmaUnavailable",
            code: -3,
            userInfo: [NSLocalizedDescriptionKey: "BASMLXAdapter not built"])
        #endif
    }

    #if canImport(BASMLXAdapter)
    /// Singleton-load gate — concurrent callers share one in-flight
    /// Task instead of racing on `if gemmaAdapter == nil` (review #2).
    func ensureGemmaAdapter() async throws -> MLXOrganAdapter {
        if let existing = gemmaAdapter { return existing }
        if let inFlight = gemmaLoadInFlight {
            return try await inFlight.value
        }
        let task = Task { [weak self] () throws -> MLXOrganAdapter in
            // Off-actor work — we don't capture self's actor here.
            let adapter = MLXOrganAdapter(
                model: MLXModelCatalog.gemma4_E2B_4bit)
            try await adapter.loadModel()
            await MainActor.run { [weak self] in
                self?.hybridGemmaLoadStatus = "model loaded, loading LoRA M247…"
            }
            // v0.3 — load LoRA M247 adapter from app bundle
            var loraOK = false
            if let loraURL = Bundle.main.url(
                forResource: "qinao_curriculum_lora_m247",
                withExtension: "safetensors")
            {
                do {
                    try await adapter.loadAdapter(from: loraURL)
                    loraOK = true
                } catch {
                    // Non-fatal — bare Gemma still works (review #4)
                    await MainActor.run { [weak self] in
                        self?.hybridGemmaLoadStatus =
                            "lora-load-failed: \(error)"
                    }
                }
            }
            try await adapter.prewarm()
            await MainActor.run { [weak self] in
                self?.gemmaLoraLoaded = loraOK
                self?.hybridGemmaLoadStatus = loraOK
                    ? "ready (with LoRA M247)"
                    : "ready (bare Gemma, NO LoRA)"
            }
            return adapter
        }
        gemmaLoadInFlight = task
        hybridGemmaLoadStatus = "loading model…"
        do {
            let adapter = try await task.value
            gemmaAdapter = adapter
            gemmaLoadInFlight = nil
            return adapter
        } catch {
            gemmaLoadInFlight = nil  // Allow retry next call
            throw error
        }
    }
    #endif
}
