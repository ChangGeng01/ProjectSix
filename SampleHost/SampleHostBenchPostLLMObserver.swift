// MARK: - SampleHostBenchPostLLMObserver
//
// chapter 二百四十二 / M824 — extracted from
// SampleHostHybridBenchEntry.swift bench loop body.
//
// chapter 二百六十九 / M750 — refactored to delegate to a
// `BASHostShadowEvaluator` conformer (BAS-side protocol shipped in
// chapter 二百六十六 / M748; substrate-driven default conformer in
// chapter 二百六十七 / M749). Default behaviour byte-equal to
// pre-chapter-二百六十九 path; hosts can swap evaluators via
// `observePostLLMViaEvaluator(...)` for tests / experiments.
//
// Closed-loop post-LLM substrate observation (chapter 一百七十八 /
// M630 doctrine): after LLM responds (or substrate skip-canned), run
// substrate observation pass on the response body. If substrate's
// permit shifts (e.g. body would have been blocked), the iter row
// records postLLMShifted = true for downstream training-data
// stratification.
//
// Doctrine pin: substrate is THE arbiter — even its own LLM's body
// is subject to substrate re-audit. This is "shadow evaluator lite":
// ShadowEvaluator full ML model lives in chapter 一百八十+; this one
// is single substrate-pass.
//
// Pre-this-batch: ~83 LOC of inline closed-loop logic in
// SampleHostHybridBenchEntry.swift bench loop body, mixing
// observation logic + counter mutations + body truncation + prompt
// injection guard.
//
// Post-chapter-二百四十二: typed `SampleHostBenchPostLLMObservation`
// struct + extension method on SampleHostModel. Bench loop calls
// `observePostLLM(...)` and reads typed result.
//
// Post-chapter-二百六十九: `observePostLLM(...)` constructs a
// `BASSubstrateReauditShadowEvaluator` internally + delegates.
// `observePostLLMViaEvaluator(_:...)` accepts any
// `BASHostShadowEvaluator` conformer for hosts that want to inject
// (tests, A/B experiments, future ML-backed evaluators per
// chapter 二百六十八+). Default arg threads through so existing
// call sites (chapter 二百四十二 line 445 in SampleHostHybridBenchEntry)
// keep working byte-equal.
//
// Doctrine pins (preserved verbatim):
//   - chapter 一百七十八 / M630: closed-loop observation doctrine
//   - chapter 一百八十五 / M676 fix B6: 4K-char cap on body for
//     substrate eval (avoid pathological 20K-char Gemma outputs +
//     mitigate prompt-injection where LLM body could be misread
//     as user intent)
//   - chapter 一百八十七 / M685 fix B4: also observe bothLLMs
//     Gemma body when AFM errored (servedBody = whichever body
//     actually has content)
//   - chapter 一百八十八 / M691: post-LLM substrate observation
//     runs off-MainActor via Task.detached
//   - chapter 二百四 / M767: workflowProfile from @Published flex
//   - chapter 二百六十六 / M748: BAS-side BASHostShadowEvaluator
//     protocol — observability-only contract
//   - chapter 二百六十七 / M749: BASSubstrateReauditShadowEvaluator
//     production conformer
//   - chapter 二百六十九 / M750: bench loop delegates to protocol;
//     side-effect (counter mutation) stays SampleHost-side
//   - 不变量 #1-#3 + Red line 7: ✓ pure observation, no decision

import Foundation
import BASHostKit
// chapter 三百四〇 / M827 — `BASEvaluation` symbols
// (`BASHostShadowEvaluator` / `BASHostShadowEvaluation` etc) are
// re-exported by `BASHostKit` via `@_exported`,so a separate
// `import BASEvaluation` here violates the host import boundary
// without adding any reachable symbols。Removed per
// `scripts/check_qinao_import_boundaries.sh` doctrine。

/// Typed post-LLM observation result.
struct SampleHostBenchPostLLMObservation: Sendable, Equatable {
    /// Substrate's post-LLM permit-mode rawValue. nil when no
    /// observation ran (LLM skipped or body empty).
    let postLLMPermitMode: String?

    /// Substrate's post-LLM audit-code count. nil when no
    /// observation ran.
    let postLLMAuditCount: Int?

    /// True iff post-LLM permit mode differs from pre-LLM permit
    /// mode (substrate would have stopped this LLM body). nil when
    /// no observation ran.
    let postLLMShifted: Bool?

    static let skipped = SampleHostBenchPostLLMObservation(
        postLLMPermitMode: nil,
        postLLMAuditCount: nil,
        postLLMShifted: nil)

    /// chapter 二百六十九 / M750 — translate a BAS-side
    /// `BASHostShadowEvaluation` into the SampleHost-side
    /// observation shape. The wrapper preserves byte-equal
    /// semantics with the pre-chapter-二百六十九 path:
    ///
    ///   - `.skipped` evaluator result → `.skipped` observation
    ///   - non-skip result → fields populated from evaluator
    ///
    /// This is the protocol-seam translation layer; SampleHost's
    /// counter-mutation side effect (`hybridBenchPostLLMShifted`)
    /// is applied separately by the caller (preserves the
    /// observability-only contract on the BAS-side evaluator).
    static func from(
        _ result: BASHostShadowEvaluation,
        prePermitMode: String
    ) -> SampleHostBenchPostLLMObservation {
        // Skipped evaluator results map to skipped observation.
        // The signal: postLLMPermitMode == nil indicates "no
        // re-audit ran" — same as the legacy guard pattern at
        // line 99-101 (empty body / llmSkipped).
        guard result.postPermitMode != nil else {
            return .skipped
        }
        return SampleHostBenchPostLLMObservation(
            postLLMPermitMode: result.postPermitMode,
            postLLMAuditCount: result.postAuditCodeCount,
            postLLMShifted: result.shifted)
    }
}

extension SampleHostModel {
    /// chapter 一百七十八 / M630 doctrine — substrate observation
    /// pass on LLM response body. Increments the shifted-count
    /// counter via `applyIfActive(generation)` when permit shifted.
    @MainActor
    func observePostLLM(
        runtime: BASHostRuntime,
        workflowProfile: BASHostWorkflowProfile,
        riskLevel: BASHostRiskLevel,
        prompt: String,
        firstBody: String,
        fallbackBody: String?,
        llmSkipped: Bool,
        prePermitMode: String,
        bodyTruncationChars: Int,
        generation: Int
    ) async -> SampleHostBenchPostLLMObservation {
        // M685 chapter 一百八十七 — B4 (MEDIUM) fix:
        // also observe `bothLLMs` Gemma body if AFM
        // returned empty / errored. servedBody (defined
        // below as the actually-rendered body for
        // residuals) IS the right input for substrate
        // post-LLM observation. Pre-fix: AFM-empty +
        // Gemma-success in `.bothLLMs` branch left
        // postLLMShifted = nil (skipped) even though
        // Gemma's body was substrate-relevant.
        //
        // Skip iters (llmSkipped) still skip — substrate
        // already gave canned response, no LLM speech to
        // re-audit.
        let observableBody: String = {
            if !firstBody.isEmpty { return firstBody }
            return fallbackBody ?? ""
        }()
        guard !observableBody.isEmpty, !llmSkipped else {
            return .skipped
        }

        // M676 chapter 一百八十五 — B6 (HIGH): cap
        // body at HybridBenchTuning.postLLMBody...
        // chars to avoid pathological substrate eval
        // on Gemma's occasional 20K-char outputs +
        // mitigate prompt-injection risk where LLM
        // body could contain text substrate
        // misinterprets as user intent.
        // M710 chapter 一百九十一 — read from
        // @Published so user can adjust live.
        let cap = bodyTruncationChars
        let truncatedBody: String
        if observableBody.count > cap {
            truncatedBody =
                String(observableBody.prefix(cap))
                + "...[truncated]"
        } else {
            truncatedBody = observableBody
        }
        let observeText =
            "Original: \(prompt)\n\nResponse: \(truncatedBody)"
        // M691 chapter 一百八十八 — B3-extended:
        // post-LLM substrate observation also off-main.
        // M767 chapter 二百四 — workflowProfile from flex.
        let observeRequest = BASHostSessionRequest(
            kind: .interactive,
            workflowProfile: workflowProfile,
            surface: .application,
            prompt: observeText,
            riskLevel: riskLevel)
        let observedResult: BASHostSessionResult? =
            try? await Task.detached(
                priority: .userInitiated
            ) {
                try runtime.startSession(observeRequest)
            }.value
        guard let observed = observedResult?.eBrainTurn else {
            return .skipped
        }

        let postLLMPermitMode = observed.actionPermit.mode.rawValue
        let postLLMAuditCount = observed
            .sovereignAuditEntry?.signalRefs.count ?? 0
        let postLLMShifted = postLLMPermitMode != prePermitMode
        if postLLMShifted {
            applyIfActive(generation) {
                self.hybridBenchPostLLMShifted += 1
            }
        }
        return SampleHostBenchPostLLMObservation(
            postLLMPermitMode: postLLMPermitMode,
            postLLMAuditCount: postLLMAuditCount,
            postLLMShifted: postLLMShifted)
    }

    /// chapter 二百六十九 / M750 — protocol-driven post-LLM
    /// observation. Accepts any `BASHostShadowEvaluator` conformer
    /// — the substrate-driven default (chapter 二百六十七), the
    /// no-op test conformer (chapter 二百六十六), a future ML-
    /// backed evaluator (chapter 二百六十八+), or a host-supplied
    /// experiment variant.
    ///
    /// Behaviour parity with the pre-chapter-二百六十九 hardcoded
    /// path:
    ///   - empty body / llmSkipped → returns `.skipped` without
    ///     calling the evaluator
    ///   - non-empty body → invokes `evaluator.evaluate(...)`,
    ///     translates the result, and applies the
    ///     `hybridBenchPostLLMShifted` counter-mutation side
    ///     effect (preserves the observability-only contract on
    ///     the BAS-side evaluator)
    @MainActor
    func observePostLLMViaEvaluator(
        evaluator: any BASHostShadowEvaluator,
        prompt: String,
        firstBody: String,
        fallbackBody: String?,
        llmSkipped: Bool,
        prePermitMode: String,
        sessionRef: String = "",
        turnRef: String = "",
        generation: Int
    ) async -> SampleHostBenchPostLLMObservation {
        // Body-resolution rule preserved from chapter 一百八十七 /
        // M685 fix B4 — observe whichever body has content.
        let observableBody: String = {
            if !firstBody.isEmpty { return firstBody }
            return fallbackBody ?? ""
        }()
        guard !observableBody.isEmpty, !llmSkipped else {
            return .skipped
        }

        let evaluation = await evaluator.evaluate(
            prompt: prompt,
            body: observableBody,
            prePermitMode: prePermitMode,
            sessionRef: sessionRef,
            turnRef: turnRef)

        let observation = SampleHostBenchPostLLMObservation.from(
            evaluation, prePermitMode: prePermitMode)

        // Counter-mutation side effect — chapter 一百七十八 / M630
        // doctrine: bench-loop counter increments on shifted
        // observations so downstream training-data stratification
        // can distinguish bench iters where substrate would have
        // stopped the LLM body. The BAS-side evaluator is
        // observability-only; this counter-mutation is SampleHost-
        // side and remains safely behind `applyIfActive`.
        if observation.postLLMShifted == true {
            applyIfActive(generation) {
                self.hybridBenchPostLLMShifted += 1
            }
        }

        return observation
    }
}
