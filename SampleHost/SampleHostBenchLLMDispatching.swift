// MARK: - SampleHostBenchLLMDispatching protocol
//
// chapter 二百四十五 / M827 — protocol contract for bench-loop LLM
// dispatch.
//
// Doctrine: chapter 二百四十四 (M826) shipped the dispatcher as an
// `extension SampleHostModel` method. This file extracts the
// contract as a typed protocol so future chapters can inject
// alternative dispatchers (e.g. MockLLMDispatcher for unit tests,
// LocalOnlyDispatcher for offline-only mode, RecordingDispatcher
// for replay-driven retests).
//
// Why protocol-marker without changing call sites: the bench loop
// currently calls `self.dispatchLLMs(...)` which resolves to the
// concrete extension method. Adding the protocol conformance
// (`extension SampleHostModel: SampleHostBenchLLMDispatching {}`)
// is doctrine-only — no behavior change, no test break. Future
// chapters that want injection can:
//   1. Add a `dispatcher: any SampleHostBenchLLMDispatching = self`
//      arg to the bench task.
//   2. Tests pass `MockLLMDispatcher()` which returns canned
//      `SampleHostBenchLLMDispatchResult` for known fixtures.
//
// Doctrine pins:
//   - 不变量 #1-#3 + Red line 7: ✓ protocol is contract only
//   - chapter 二百十一 single-source-of-truth: dispatch contract
//     owned by one file
//   - chapter 二百四十四 / M826: existing dispatcher extension
//     method satisfies this protocol verbatim

import Foundation

/// Protocol contract for LLM dispatch in the hybrid bench loop.
/// `SampleHostModel` is the production conformer (chapter 二百四十四
/// / M826 dispatcher extension method). Mock conformers for tests
/// can return canned `SampleHostBenchLLMDispatchResult` without
/// touching CoreML, AFM, or Gemma — useful for testing the bench
/// loop's row-build / counter / observation logic in isolation.
@MainActor
protocol SampleHostBenchLLMDispatching: AnyObject {
    /// chapter 一百七十八 / M628 doctrine — dispatch LLM(s) per the
    /// substrate-derived dispatchPolicy. Returns typed result for
    /// row build + counter mutations.
    func dispatchLLMs(
        dispatchPolicy: SampleHostHybridDispatchPolicy,
        routerRoute: ChengluPreflightDecision.Route,
        routerConfidence: ChengluPreflightDecision.Confidence,
        prompt: String,
        timeoutSeconds: Double,
        generation: Int
    ) async -> SampleHostBenchLLMDispatchResult
}

// SampleHostModel is the production conformer. Existing chapter
// 二百四十四 (M826) dispatcher extension method satisfies the
// protocol verbatim; this is a doctrine-only marker.
extension SampleHostModel: SampleHostBenchLLMDispatching {}
