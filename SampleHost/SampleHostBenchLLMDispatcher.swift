// MARK: - SampleHostBenchLLMDispatcher
//
// chapter 二百四十四 / M826 — extracted from
// SampleHostHybridBenchEntry.swift bench loop body.
//
// The largest single-method extraction in the architectural arc.
// LLM dispatch logic for the hybrid bench loop — handles 6 dispatch
// policy branches × AFM/Gemma routing × confidence-aware uncertain
// zone × fallback safety net × generation-guard counter mutations.
//
// Pre-this-batch: ~340 LOC of inline switch-on-dispatchPolicy in
// SampleHostHybridBenchEntry.swift bench loop, with deep nesting
// across 4 branches:
//
//   1. `.skipsLLM` (block / replace / delay)   → canned response
//   2. `.bothLLMs` (compare / escalate)        → dual-LLM call
//   3. `.localOnly`                            → Gemma-only
//   4. `.singleLLM` / `.draftOnly`             → split into:
//      a. uncertain-zone: dual-call + longer-pick (chapter v0.2)
//      b. confident: chosen-LLM + fallback safety net
//
// Post-this-batch: typed `SampleHostBenchLLMDispatchResult` value
// bundle (15 fields) + `dispatchLLMs(...)` extension method. Bench
// loop calls one method, reads typed result.
//
// Doctrine pins (preserved verbatim from original — every chapter
// 178/185/187/188/195/198/207 doctrine):
//   - chapter 一百七十八 / M628: substrate-permit-shaped dispatch
//   - chapter 一百八十五 / M666 fix B1 (CRITICAL): routerOverridden
//     flag — substrate skip / bothLLMs / localOnly bypass router
//   - chapter 一百八十五 / M671 fix B11: skip-path duration = 0
//     (canned-string assignment latency is meaningless)
//   - chapter 一百八十七 / M685 fix B4: bothLLMs Gemma observable
//     when AFM empty
//   - chapter 一百九十五 / M735: timeout BAIL-OUT, not session-killer
//   - chapter 一百九十八 / M746: bothLLMs path also gets timeout
//   - chapter 二百七 / M779 + M780: stale-task counter safety via
//     applyIfActive(generation)
//   - 不变量 #1 (先醒再答): substrate routes BEFORE LLM
//   - 不变量 #2 (神经不掌权): substrate's permit single-mouth
//   - Red line 7 (HINT-ONLY): router prediction is observability,
//     never replaces substrate decision

import Foundation

/// Typed LLM dispatch result. 15 fields capture the actually-taken
/// dispatch path + counter routing for downstream JSONL row build.
struct SampleHostBenchLLMDispatchResult: Sendable {
    var firstTriedLLM: String
    var firstStatus: String
    var firstBody: String
    var firstDurationMs: Double
    var fallbackLLM: String?
    var fallbackStatus: String?
    var fallbackBody: String?
    var fallbackDurationMs: Double?
    var actualRoute: String
    var routerHit: Bool
    var routerOverridden: Bool
    var errorMessage: String?
    var dispatchTaken: String
    var llmSkipped: Bool
    var draftOnlyFlag: Bool
}

extension SampleHostModel {
    /// chapter 一百七十八 / M628 doctrine — dispatch LLM(s) per the
    /// substrate-derived dispatchPolicy. Returns typed result for
    /// row build + counter mutations wrapped in applyIfActive(generation).
    @MainActor
    func dispatchLLMs(
        dispatchPolicy: SampleHostHybridDispatchPolicy,
        routerRoute: ChengluPreflightDecision.Route,
        routerConfidence: ChengluPreflightDecision.Confidence,
        prompt: String,
        timeoutSeconds: Double,
        generation myGen: Int
    ) async -> SampleHostBenchLLMDispatchResult {
        var firstTriedLLM = routerRoute.rawValue
        var firstStatus = "ok"
        var firstBody = ""
        var firstDurationMs: Double = 0
        var fallbackLLM: String?
        var fallbackStatus: String?
        var fallbackBody: String?
        var fallbackDurationMs: Double?
        var actualRoute = ""
        var routerHit = true
        var routerOverridden: Bool = false
        var errorMessage: String?
        var dispatchTaken: String = dispatchPolicy.rawValue
        var llmSkipped: Bool = false
        var draftOnlyFlag: Bool = false

        let firstStart = Date()

        // M628 — substrate-skip path: when permit is .block /
        // .replace / .delay, do NOT call LLM. Return canned.
        if dispatchPolicy.skipsLLM {
            let canned = dispatchPolicy.cannedResponse ?? ""
            firstTriedLLM = "none-substrate-skip"
            firstBody = canned
            firstStatus = "ok-substrate-skip"
            // M671 chapter 一百八十五 — B11 fix: skip-path duration = 0
            firstDurationMs = 0
            actualRoute = "skipped-by-substrate-\(dispatchPolicy.rawValue.dropFirst("skip-".count))"
            llmSkipped = true
            dispatchTaken = dispatchPolicy.rawValue
            // M666 chapter 一百八十五 — B1 fix: routerOverridden = true
            routerOverridden = true
            switch dispatchPolicy {
            case .skipBlock:
                applyIfActive(myGen) { self.hybridBenchSubstrateSkipBlock += 1 }
            case .skipReplace:
                applyIfActive(myGen) { self.hybridBenchSubstrateSkipReplace += 1 }
            case .skipDelay:
                applyIfActive(myGen) { self.hybridBenchSubstrateSkipDelay += 1 }
            default: break
            }
        } else if dispatchPolicy == .bothLLMs {
            // M628 — substrate explicitly wants both LLMs (compare /
            // escalate). Force dual-call regardless of router prediction.
            var afmBodyMaybe: String?
            var gemmaBodyMaybe: String?
            var afmErr: Error?
            var gemmaErr: Error?
            let afmStart = Date()
            do {
                // M746 chapter 一百九十八 — bothLLMs path also gets
                // per-iter timeout protection.
                afmBodyMaybe = try await self.callAFMWithTimeout(
                    prompt: prompt, seconds: timeoutSeconds)
            } catch {
                afmErr = error
                self.recordTimeoutIfApplicable(error, generation: myGen)
            }
            let afmMs = Date().timeIntervalSince(afmStart) * 1000
            let gemmaStart = Date()
            do {
                gemmaBodyMaybe = try await self.callGemmaWithTimeout(
                    prompt: prompt, seconds: timeoutSeconds)
            } catch {
                gemmaErr = error
                self.recordTimeoutIfApplicable(error, generation: myGen)
            }
            let gemmaMs = Date().timeIntervalSince(gemmaStart) * 1000

            firstTriedLLM = "afm"
            firstBody = afmBodyMaybe ?? ""
            firstStatus = afmErr == nil ? "ok" : "afm-error"
            firstDurationMs = afmMs
            if let g = gemmaBodyMaybe {
                fallbackLLM = "gemma"
                fallbackBody = g
                fallbackStatus = gemmaErr == nil ? "ok-substrate-both" : "gemma-error"
            }
            fallbackDurationMs = gemmaMs
            let bothFailed = afmBodyMaybe == nil && gemmaBodyMaybe == nil
            actualRoute = bothFailed
                ? "substrate-both-failed"
                : "substrate-both-\(dispatchPolicy.rawValue)"
            if bothFailed {
                applyIfActive(myGen) { self.hybridBenchBothFailed += 1 }
                routerHit = false
            } else {
                if afmBodyMaybe != nil {
                    applyIfActive(myGen) { self.hybridBenchAFMOk += 1 }
                }
                if gemmaBodyMaybe != nil {
                    applyIfActive(myGen) { self.hybridBenchGemmaOk += 1 }
                }
            }
            if afmErr != nil { errorMessage = "afm: \(afmErr!)" }
            if gemmaErr != nil {
                errorMessage = (errorMessage ?? "") + " gemma: \(gemmaErr!)"
            }
            // M666 chapter 一百八十五 — B1: bothLLMs overrides router.
            routerOverridden = true
            applyIfActive(myGen) { self.hybridBenchSubstrateBothLLMs += 1 }
        } else if dispatchPolicy == .localOnly {
            // M628 — substrate flagged no-cloud. Force Gemma path.
            // M666 chapter 一百八十五 — B1: localOnly is substrate
            // override; don't tally routerHits/Misses.
            // M746 chapter 一百九十八 — apply timeout.
            do {
                firstBody = try await self.callGemmaWithTimeout(
                    prompt: prompt, seconds: timeoutSeconds)
                firstTriedLLM = "gemma"
                firstStatus = "ok-substrate-local-only"
                firstDurationMs = Date().timeIntervalSince(firstStart) * 1000
                actualRoute = "local-only-gemma-ok"
                applyIfActive(myGen) { self.hybridBenchGemmaOk += 1 }
            } catch {
                // M780 chapter 二百七 — record timeout count.
                self.recordTimeoutIfApplicable(error, generation: myGen)
                firstTriedLLM = "gemma"
                firstStatus = "gemma-error"
                firstDurationMs = Date().timeIntervalSince(firstStart) * 1000
                errorMessage = "gemma local-only: \(error)"
                actualRoute = "local-only-gemma-failed"
                applyIfActive(myGen) { self.hybridBenchBothFailed += 1 }
                routerHit = false
            }
            routerOverridden = true
            applyIfActive(myGen) { self.hybridBenchSubstrateLocalOnly += 1 }
        } else {
            // M628 — `.singleLLM` or `.draftOnly` falls through.
            if dispatchPolicy == .draftOnly {
                draftOnlyFlag = true
                applyIfActive(myGen) { self.hybridBenchSubstrateDraftOnly += 1 }
            }
            if routerConfidence == .uncertain {
                // v0.2 — uncertain zone: call BOTH LLMs, pick longer body.
                var afmBodyMaybe: String?
                var gemmaBodyMaybe: String?
                var afmErr: Error?
                var gemmaErr: Error?
                let afmStart = Date()
                do {
                    afmBodyMaybe = try await self.callAFMWithTimeout(
                        prompt: prompt, seconds: timeoutSeconds)
                } catch {
                    afmErr = error
                    self.recordTimeoutIfApplicable(error, generation: myGen)
                }
                let afmMs = Date().timeIntervalSince(afmStart) * 1000
                let gemmaStart = Date()
                do {
                    gemmaBodyMaybe = try await self.callGemmaWithTimeout(
                        prompt: prompt, seconds: timeoutSeconds)
                } catch {
                    gemmaErr = error
                    self.recordTimeoutIfApplicable(error, generation: myGen)
                }
                let gemmaMs = Date().timeIntervalSince(gemmaStart) * 1000

                let pickedAFM: Bool
                if let a = afmBodyMaybe, let g = gemmaBodyMaybe {
                    pickedAFM = a.count >= g.count
                } else if afmBodyMaybe != nil {
                    pickedAFM = true
                } else if gemmaBodyMaybe != nil {
                    pickedAFM = false
                } else {
                    pickedAFM = true  // both failed
                }
                if pickedAFM {
                    firstTriedLLM = "afm"
                    firstBody = afmBodyMaybe ?? ""
                    firstStatus = afmErr == nil ? "ok" : "afm-error"
                    firstDurationMs = afmMs
                    if let other = gemmaBodyMaybe {
                        fallbackLLM = "gemma"
                        fallbackBody = other
                        fallbackStatus = "ok-uncertain-side"
                    }
                    fallbackDurationMs = gemmaMs
                    actualRoute = "uncertain-both-pick-afm"
                } else {
                    firstTriedLLM = "gemma"
                    firstBody = gemmaBodyMaybe ?? ""
                    firstStatus = gemmaErr == nil ? "ok" : "gemma-error"
                    firstDurationMs = gemmaMs
                    if let other = afmBodyMaybe {
                        fallbackLLM = "afm"
                        fallbackBody = other
                        fallbackStatus = "ok-uncertain-side"
                    }
                    fallbackDurationMs = afmMs
                    actualRoute = "uncertain-both-pick-gemma"
                }
                let bothFailed = afmBodyMaybe == nil && gemmaBodyMaybe == nil
                if afmBodyMaybe != nil && gemmaBodyMaybe == nil {
                    applyIfActive(myGen) { self.hybridBenchAFMOk += 1 }
                } else if gemmaBodyMaybe != nil && afmBodyMaybe == nil {
                    applyIfActive(myGen) { self.hybridBenchGemmaOk += 1 }
                } else if bothFailed {
                    applyIfActive(myGen) { self.hybridBenchBothFailed += 1 }
                    // M627 review #6: actualRoute lied as "uncertain-both-pick-afm"
                    // when both bodies are empty. Correct semantic:
                    actualRoute = "uncertain-both-failed"
                } else {
                    if pickedAFM {
                        applyIfActive(myGen) { self.hybridBenchAFMOk += 1 }
                    } else {
                        applyIfActive(myGen) { self.hybridBenchGemmaOk += 1 }
                    }
                }
                if afmErr != nil { errorMessage = "afm: \(afmErr!)" }
                if gemmaErr != nil {
                    errorMessage = (errorMessage ?? "") + " gemma: \(gemmaErr!)"
                }
                // M627 review #5: only count router-hit when at least
                // one body returned. Both-failed → routerMisses.
                if bothFailed {
                    applyIfActive(myGen) { self.hybridBenchRouterMisses += 1 }
                    routerHit = false
                } else {
                    applyIfActive(myGen) { self.hybridBenchRouterHits += 1 }
                }
            } else {
                // Confident — original single-LLM-with-fallback path.
                // M735 chapter 一百九十五 — wrap with timeout.
                do {
                    if routerRoute == .afm {
                        firstBody = try await self.callAFMWithTimeout(
                            prompt: prompt, seconds: timeoutSeconds)
                    } else {
                        firstBody = try await self.callGemmaWithTimeout(
                            prompt: prompt, seconds: timeoutSeconds)
                    }
                    firstDurationMs = Date().timeIntervalSince(firstStart) * 1000
                    actualRoute = "\(routerRoute.rawValue)-predicted-ok"
                    if routerRoute == .afm {
                        applyIfActive(myGen) { self.hybridBenchAFMOk += 1 }
                    } else {
                        applyIfActive(myGen) { self.hybridBenchGemmaOk += 1 }
                    }
                    applyIfActive(myGen) { self.hybridBenchRouterHits += 1 }
                } catch {
                    // M780 chapter 二百七 — record timeout count.
                    self.recordTimeoutIfApplicable(error, generation: myGen)
                    firstStatus = "\(routerRoute.rawValue)-error"
                    firstDurationMs = Date().timeIntervalSince(firstStart) * 1000
                    errorMessage = "first: \(error)"
                    routerHit = false
                    applyIfActive(myGen) { self.hybridBenchRouterMisses += 1 }
                    let fbStart = Date()
                    do {
                        let other: String
                        if routerRoute == .afm {
                            other = try await self.callGemmaWithTimeout(
                                prompt: prompt, seconds: timeoutSeconds)
                            fallbackLLM = "gemma"
                            fallbackStatus = "ok"
                            fallbackBody = other
                            actualRoute = "afm-fallback-to-gemma-ok"
                            applyIfActive(myGen) { self.hybridBenchAFMFallbackToGemmaOk += 1 }
                        } else {
                            other = try await self.callAFMWithTimeout(
                                prompt: prompt, seconds: timeoutSeconds)
                            fallbackLLM = "afm"
                            fallbackStatus = "ok"
                            fallbackBody = other
                            actualRoute = "gemma-fallback-to-afm-ok"
                            applyIfActive(myGen) { self.hybridBenchGemmaFallbackToAFMOk += 1 }
                        }
                        fallbackDurationMs = Date().timeIntervalSince(fbStart) * 1000
                    } catch {
                        // M780 chapter 二百七 — fallback timeout
                        self.recordTimeoutIfApplicable(error, generation: myGen)
                        fallbackLLM = routerRoute == .afm ? "gemma" : "afm"
                        fallbackStatus = "error"
                        errorMessage = (errorMessage ?? "") + " fb: \(error)"
                        actualRoute = "both-failed"
                        applyIfActive(myGen) { self.hybridBenchBothFailed += 1 }
                        fallbackDurationMs = Date().timeIntervalSince(fbStart) * 1000
                    }
                }
            }
        }

        return SampleHostBenchLLMDispatchResult(
            firstTriedLLM: firstTriedLLM,
            firstStatus: firstStatus,
            firstBody: firstBody,
            firstDurationMs: firstDurationMs,
            fallbackLLM: fallbackLLM,
            fallbackStatus: fallbackStatus,
            fallbackBody: fallbackBody,
            fallbackDurationMs: fallbackDurationMs,
            actualRoute: actualRoute,
            routerHit: routerHit,
            routerOverridden: routerOverridden,
            errorMessage: errorMessage,
            dispatchTaken: dispatchTaken,
            llmSkipped: llmSkipped,
            draftOnlyFlag: draftOnlyFlag)
    }
}
