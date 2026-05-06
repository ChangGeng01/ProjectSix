// MARK: - BASSubstrateReauditShadowEvaluator — chapter 二百六十七 / M749
//
// Substrate-driven `BASShadowEvaluating` conformer — Stage 5
// Step 2 of 5.
//
// ## Why this exists
//
// chapter 二百六十六 / M748 shipped the abstract
// `BASShadowEvaluating` protocol + `BASNoOpShadowEvaluator`. What
// was missing: the production conformer that actually does
// substrate-re-audit on the LLM body.
//
// SampleHost shipped the prototype (`SampleHostBenchPostLLMObservation`,
// chapter 二百四十二 / M824) but it lives in the SampleHost target,
// uses SampleHost-specific `@MainActor`/`SampleHostModel` plumbing,
// and embeds counter-mutation side effects. Other hosts can't
// reuse it. chapter 二百六十七 ships the BAS-side equivalent:
// pure-Sendable substrate-reaudit evaluator that any host wires
// in via `BASShadowEvaluating` protocol contract — observability
// only, no side effects.
//
// ## Design
//
//   - `BASSubstrateReauditShadowEvaluator: BASShadowEvaluating`
//     wraps a `BASHostRuntime` + workflowProfile + riskLevel +
//     body-truncation cap.
//   - `evaluate(prompt:body:prePermitMode:sessionRef:turnRef:)`:
//     1. Skip path: empty body → `.skipped`.
//     2. Truncate body at `bodyTruncationChars` (chapter 一百八十五
//        / M676 doctrine — 4K-char default cap defends against
//        pathological 20K-char Gemma outputs + mitigates prompt-
//        injection where LLM body could be misread as user intent).
//     3. Build a `BASHostSessionRequest` with concatenated
//        `"Original: <prompt>\n\nResponse: <body>"` text.
//     4. Run `runtime.startSession(...)` inside `Task.detached`
//        (chapter 一百八十八 / M691 — substrate eval off-main).
//     5. Compare post-LLM permit-mode rawValue vs `prePermitMode`;
//        emit typed result with `shifted`, `postPermitMode`,
//        `postAuditCodeCount`, audit reason codes.
//
// ## Doctrine pins
//
//   - 不变量 #1 / #2 / #3: evaluator is observability — runs the
//     substrate against the body but never mutates production
//     state. The result is HINT for the host to act on (or not).
//   - 红线 7 watcher-only-hint: this evaluator is exactly the
//     "watcher" doctrine references. It produces a `shifted: Bool`
//     hint; the host runtime decides whether to respond.
//   - chapter 一百七十八 / M630 closed-loop substrate-is-arbiter
//     doctrine: substrate is THE arbiter — even its own LLM's body
//     is subject to substrate re-audit. This evaluator is the
//     production realization.
//   - chapter 一百八十五 / M676 fix B6: 4K-char body cap.
//     Configurable via init for hosts wanting tighter or looser
//     caps; defaults to 4096.
//   - chapter 一百八十八 / M691 fix B3-extended: substrate eval
//     off-MainActor via `Task.detached`.
//   - chapter 二百十一 single-source-of-truth: the protocol is
//     defined in `BASShadowEvaluating.swift`; this file is one
//     conformer.

import Foundation
import BASRuntimeCore
import BASEvaluation

/// Substrate-driven shadow evaluator. Re-runs the substrate
/// against the LLM's response body and reports whether the
/// substrate's permit decision shifts. Pure observability — never
/// mutates production state.
public struct BASSubstrateReauditShadowEvaluator:
    BASShadowEvaluating
{
    /// Default body truncation cap (chapter 一百八十五 / M676 fix
    /// B6 doctrine). 4 KB strikes a balance between giving the
    /// substrate enough context to evaluate vs avoiding
    /// pathological 20K-char LLM outputs + prompt-injection
    /// surface.
    public static let defaultBodyTruncationChars: Int = 4096

    /// Stable evaluator version identifier.
    public static let version = "substrate-reaudit-v1"

    public let evaluatorVersion: String

    private let runtime: BASHostRuntime
    private let workflowProfile: BASHostWorkflowProfile
    private let riskLevel: BASHostRiskLevel
    private let surface: BASHostSurface
    private let bodyTruncationChars: Int

    /// Build a substrate-reaudit evaluator.
    ///
    /// - Parameters:
    ///   - runtime: the `BASHostRuntime` instance that will be
    ///     used for re-audit. Hosts typically pass the same
    ///     runtime they use for primary turn handling.
    ///   - workflowProfile: profile to use for re-audit sessions.
    ///     Defaults to `.reflective` (substrate is most
    ///     conservative).
    ///   - riskLevel: risk level to advertise to substrate during
    ///     re-audit. Defaults to `.medium`.
    ///   - surface: session surface label. Defaults to
    ///     `.application`.
    ///   - bodyTruncationChars: cap on body length passed to
    ///     substrate. Defaults to `defaultBodyTruncationChars`
    ///     (4096).
    ///   - evaluatorVersion: override version identifier (e.g.
    ///     for A/B comparisons). Defaults to `version`.
    public init(
        runtime: BASHostRuntime,
        workflowProfile: BASHostWorkflowProfile = .reflective,
        riskLevel: BASHostRiskLevel = .medium,
        surface: BASHostSurface = .application,
        bodyTruncationChars: Int =
            BASSubstrateReauditShadowEvaluator
                .defaultBodyTruncationChars,
        evaluatorVersion: String =
            BASSubstrateReauditShadowEvaluator.version
    ) {
        self.runtime = runtime
        self.workflowProfile = workflowProfile
        self.riskLevel = riskLevel
        self.surface = surface
        self.bodyTruncationChars = max(64, bodyTruncationChars)
        self.evaluatorVersion = evaluatorVersion
    }

    public func evaluate(
        prompt: String,
        body: String,
        prePermitMode: String,
        sessionRef: String,
        turnRef: String
    ) async -> BASShadowEvaluationResult {
        // Skip path — empty body has nothing to re-audit.
        guard !body.isEmpty else {
            return BASShadowEvaluationResult.skipped(
                evaluatorVersion: evaluatorVersion)
        }

        // Truncate body at cap (chapter 一百八十五 / M676 doctrine).
        let truncatedBody: String
        if body.count > bodyTruncationChars {
            truncatedBody =
                String(body.prefix(bodyTruncationChars))
                + "...[truncated]"
        } else {
            truncatedBody = body
        }

        let observeText = "Original: \(prompt)\n\nResponse: \(truncatedBody)"
        let request = BASHostSessionRequest(
            kind: .interactive,
            workflowProfile: workflowProfile,
            surface: surface,
            prompt: observeText,
            riskLevel: riskLevel)

        // Off-MainActor substrate eval (chapter 一百八十八 / M691).
        // Closure absorbs the `try` via `try?` so the detached
        // Task is non-throwing; outer `.value` is therefore non-
        // throwing async.
        let runtime = self.runtime
        let observedResult: BASHostSessionResult? =
            await Task.detached(
                priority: .userInitiated
            ) { () -> BASHostSessionResult? in
                try? runtime.startSession(request)
            }.value

        guard let observed = observedResult?.eBrainTurn else {
            return BASShadowEvaluationResult(
                postPermitMode: nil,
                postAuditCodeCount: nil,
                shifted: false,
                reasonCodes: [
                    "evaluator:substrate-reaudit-failed"
                ],
                evaluatorVersion: evaluatorVersion)
        }

        let postPermitMode = observed.actionPermit.mode.rawValue
        let postAuditCount = observed
            .sovereignAuditEntry?.signalRefs.count ?? 0
        let shifted = postPermitMode != prePermitMode

        var reasonCodes: [String] = [
            "evaluator:substrate-reaudit"
        ]
        if shifted {
            reasonCodes.append(
                "shadow:permit-shifted:" +
                "from-\(prePermitMode):to-\(postPermitMode)")
        }
        if body.count > bodyTruncationChars {
            reasonCodes.append("shadow:body-truncated")
        }

        return BASShadowEvaluationResult(
            postPermitMode: postPermitMode,
            postAuditCodeCount: postAuditCount,
            shifted: shifted,
            reasonCodes: reasonCodes,
            evaluatorVersion: evaluatorVersion)
    }
}
