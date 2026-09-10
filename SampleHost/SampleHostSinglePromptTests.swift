// MARK: - SampleHostSinglePromptTests
//
// chapter 二百三十四 / M816 — extracted from SampleHostModel.swift.
//
// 3 single-prompt UI test methods (chapter 一百七十六 §176.13 +
// chapter 一百七十七 §177 — tap-once smoke probes that don't drive
// the long-running bench loop):
//
//   - runAFMTestNow()                — chapter 一百七十六 §176.13
//                                      AFM direct test, foreground-
//                                      policy-compliant
//   - updateAFMTestPrompt(_:)         — text-binding setter for
//                                      single-prompt UI panels
//   - runHybridSinglePrompt()        — chapter 一百七十七 §177 +
//                                      chapter 一百八十三 (M659)
//                                      hybrid router test with full
//                                      5-head meridian
//
// Pre-this-batch: ~120 LOC of inline methods on SampleHostModel
// using `@Published private(set) var` writes that were structural-
// barrier blockers for cross-file extension.
// Post-this-batch: dedicated extension file. Access barriers
// promoted in chapter 二百三十三 (M815) so extension can write
// view-state directly.
//
// Doctrine pins:
//   - Hardcoded ChengluPromptFeatures(tone: "agentic", ...) for
//     hybrid single-prompt is INTENTIONAL: it's a smoke test, not
//     signature-driven inference. Bench rows derive from actual
//     generated prompt's signature.
//   - chapter 一百八十三 (M659) doctrine: call ALL heads for the
//     single-prompt path so UI surfaces full meridian before LLM
//     fires (router is load-bearing; other 4 outputs are obs hints).
//   - 不变量 #1-#3 + Red line 7: ✓ pure UI test scaffolding,
//     no decision-making + no production permit influence.

import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

extension SampleHostModel {
    func runAFMTestNow() {
        guard !afmIsRunning else { return }
        afmIsRunning = true
        afmTestStatus = "starting…"
        afmTestOutput = ""
        afmTestDurationMs = 0
        let prompt = afmTestPrompt
        Task { @MainActor [weak self] in
            #if canImport(FoundationModels)
            if #available(iOS 26.0, macOS 26.0, *) {
                do {
                    let session = LanguageModelSession()
                    self?.afmTestStatus = "calling AFM…"
                    let started = Date()
                    let response = try await session.respond(to: prompt)
                    let elapsed = Date().timeIntervalSince(started)
                    self?.afmTestOutput = response.content
                    self?.afmTestDurationMs = elapsed * 1000
                    self?.afmTestStatus =
                        "ok — \(String(format: "%.0f", elapsed * 1000)) ms / \(response.content.count) chars"
                } catch {
                    self?.afmTestOutput = ""
                    self?.afmTestStatus = "error: \(error)"
                }
            } else {
                self?.afmTestStatus =
                    "AFM unavailable — needs iOS 26+ / macOS 26+"
            }
            #else
            self?.afmTestStatus =
                "AFM unavailable — FoundationModels framework not imported"
            #endif
            self?.afmIsRunning = false
        }
    }

    func updateAFMTestPrompt(_ newPrompt: String) {
        afmTestPrompt = newPrompt
    }

    /// Single-prompt hybrid test (UI panel). Predicts route via
    /// CoreML, calls chosen LLM, falls back to other on error.
    ///
    /// **M627 deep-review note #12** — by design this single-prompt
    /// path does NOT take the v0.2 confidence-aware uncertain-zone
    /// dual-LLM branch (chosen→fallback only). Rationale: the UI
    /// panel is a "tap once + see it work" smoke probe. Always
    /// calling both LLMs would double the latency that the user
    /// is staring at, for marginal benefit on a single sample.
    /// Bench path (`startHybridBench`) still uses dual-LLM voting
    /// in the uncertain zone for the real signal collection.
    /// Hardcoded features (agentic / creative / modest / …) are
    /// also intentional: it's a smoke test, not signature-driven
    /// inference. Bench rows derive features from the actual
    /// generated prompt's signature.
    func runHybridSinglePrompt() {
        let prompt = afmTestPrompt
        let features = ChengluPromptFeatures(
            tone: "agentic",
            domain: "creative",
            stake: "modest",
            timeframe: "minutes",
            confidant: "decision-system",
            askShape: "single-action",
            mutationSeed: 0)
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.hybridSinglePromptStatus = "predicting…"
            // M659 chapter 一百八十三 — call ALL heads for the
            // single-prompt path so UI surfaces full meridian
            // before LLM fires (router stays the load-bearing
            // decision; other 4 outputs are observability hints).
            let decision = ChengluPreflightInference.shared
                .predictOrNil(features: features)
            let multiHead = ChengluMultiHeadInference.shared
                .predictOrNil(features: features)
            // Reset previous inline values
            self.hybridSinglePromptBlockProb = nil
            self.hybridSinglePromptLengthChars = nil
            self.hybridSinglePromptLatencyMs = nil
            self.hybridSinglePromptVerbosityProb = nil
            if let mh = multiHead {
                self.hybridSinglePromptBlockProb = mh.blockProbability
                self.hybridSinglePromptLengthChars =
                    mh.predictedBodyLength
                self.hybridSinglePromptLatencyMs =
                    mh.predictedDurationMs
                self.hybridSinglePromptVerbosityProb =
                    mh.verbosityProbability
            }
            guard let d = decision else {
                self.hybridSinglePromptStatus = "router unavailable"
                return
            }
            self.hybridSinglePromptProb = d.afmSuccessProbability
            self.hybridSinglePromptRoute = d.route.rawValue
            self.hybridSinglePromptStatus =
                "router: \(d.route.rawValue) (prob \(String(format: "%.3f", d.afmSuccessProbability))) calling…"
            // Try chosen LLM
            do {
                if d.route == .afm {
                    let body = try await self.callAFM(prompt: prompt)
                    self.hybridSinglePromptOutput = body
                    self.hybridSinglePromptStatus =
                        "ok afm (predicted) \(body.count) chars"
                } else {
                    let body = try await self.callGemma(prompt: prompt)
                    self.hybridSinglePromptOutput = body
                    self.hybridSinglePromptStatus =
                        "ok gemma (predicted) \(body.count) chars"
                }
            } catch {
                // Fallback to the other LLM
                self.hybridSinglePromptStatus =
                    "first try failed (\(d.route.rawValue)), trying fallback…"
                do {
                    let body: String
                    if d.route == .afm {
                        body = try await self.callGemma(prompt: prompt)
                        self.hybridSinglePromptStatus =
                            "ok gemma fallback \(body.count) chars (router miss)"
                    } else {
                        body = try await self.callAFM(prompt: prompt)
                        self.hybridSinglePromptStatus =
                            "ok afm fallback \(body.count) chars (router miss)"
                    }
                    self.hybridSinglePromptOutput = body
                } catch {
                    self.hybridSinglePromptStatus =
                        "both failed: \(error)"
                    self.hybridSinglePromptOutput = ""
                }
            }
        }
    }
}
