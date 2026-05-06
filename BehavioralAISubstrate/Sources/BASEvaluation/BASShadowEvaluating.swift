// MARK: - BASShadowEvaluating — chapter 二百六十六 / M748
//
// Shadow-evaluator abstract protocol contract — Stage 5 Step 1 of 5.
//
// ## Why this exists
//
// 附录 V audit identified Gap "0/18 任 side ML heads" as the
// largest evaluator-side gap. SampleHost shipped a substrate-
// driven post-LLM observer (chapter 二百四十二 / M824) but no BAS-
// side protocol exists for the abstract "shadow evaluator"
// contract. Without the protocol, every host that wants a shadow
// evaluator builds the same shape ad-hoc with no shared type for
// composition / mocking / future-ML-backed swap-in.
//
// chapter 二百六十六 ships:
//   - `BASShadowEvaluationResult` — typed result of one evaluator
//     pass (`BASSchemaVersioned`-conformant Codable value type).
//   - `BASShadowEvaluating` — abstract protocol with one method:
//     `evaluate(prompt:body:prePermitMode:sessionRef:turnRef:) async`.
//   - `BASNoOpShadowEvaluator` — trivial conformer for tests +
//     ephemeral hosts; always returns `.skipped`. Production hosts
//     wire substrate-driven (chapter 二百六十七) or ML-backed
//     (chapter 二百六十八+) conformers.
//
// SampleHost's `SampleHostBenchPostLLMObservation` (chapter
// 二百四十二) is the prototype the BAS protocol generalizes —
// chapter 二百六十七 will refit SampleHost's observer to use this
// protocol so every host shares one contract.
//
// ## Doctrine pins
//
//   - 不变量 #1 / #2 / #3 unchanged: the protocol is observability.
//     Conformers MUST NOT mutate production state — they observe
//     a (prompt, body) pair and return a typed result.
//   - 红线 7 watcher-only-hint: results are HINTS. Hosts decide
//     whether to act on `shifted == true` (e.g. by elevating a
//     counter, refusing the body downstream, etc.); the evaluator
//     itself never decides.
//   - chapter 一百七十八 / M630 closed-loop substrate-is-arbiter
//     doctrine: the substrate-driven conformer (chapter 二百六十七)
//     re-runs the substrate against the LLM body. The protocol
//     itself is doctrine-agnostic; ML-backed conformers (chapter
//     二百六十八+) follow a different shape but expose the same
//     contract.
//   - chapter 二百十一 single-source-of-truth: protocol + result
//     type live in this one file. Conformers in their own files.

import Foundation
import BASRuntimeCore

// MARK: - BASShadowEvaluationResult

/// Typed result of one shadow-evaluator pass.
///
/// Implementations populate the result fields per their evaluation
/// strategy:
///   - `BASNoOpShadowEvaluator` returns `.skipped` (every field nil
///     / `false`).
///   - Substrate-driven conformer (chapter 二百六十七) populates
///     `postPermitMode` + `postAuditCodeCount` + `shifted` + a
///     "substrate-reaudit" reason code.
///   - ML-backed conformer (chapter 二百六十八+) populates
///     `shifted` based on a body-feature classifier + an
///     "ml-prediction:<probability>" reason code.
public struct BASShadowEvaluationResult:
    BASSchemaVersioned, Sendable, Equatable, Codable, Hashable
{
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String

    /// Permit mode raw value the evaluator's substrate would have
    /// emitted *for the body*. nil if no evaluation ran (skipped
    /// path) or if the evaluator strategy doesn't produce a permit
    /// mode (e.g. ML-backed binary classifier returns nil here).
    public let postPermitMode: String?

    /// Audit code count from the evaluator's substrate pass. nil
    /// for evaluators that don't run substrate.
    public let postAuditCodeCount: Int?

    /// True iff the evaluator says the LLM body would have shifted
    /// the permit decision (e.g. body content trips block where
    /// pre-LLM was answer). false on the skipped path.
    public let shifted: Bool

    /// Free-form audit codes the evaluator emits. Audit walkers
    /// grep for evaluator-specific tags here.
    public let reasonCodes: [String]

    /// Stable evaluator version identifier — e.g.
    /// `"substrate-reaudit-v1"`, `"ml-head-shadow-v0.1"`,
    /// `"noop"`. Audit walkers grep this to know which evaluator
    /// produced the result.
    public let evaluatorVersion: String

    /// Wall-clock at evaluation time. Recorded for forensic audit.
    public let evaluatedAt: Date

    public init(
        schemaVersion: String =
            BASShadowEvaluationResult.currentSchemaVersion,
        postPermitMode: String? = nil,
        postAuditCodeCount: Int? = nil,
        shifted: Bool = false,
        reasonCodes: [String] = [],
        evaluatorVersion: String,
        evaluatedAt: Date = Date()
    ) {
        self.schemaVersion = schemaVersion
        self.postPermitMode = postPermitMode?
            .trimmingCharacters(
                in: .whitespacesAndNewlines)
        self.postAuditCodeCount = postAuditCodeCount
        self.shifted = shifted
        self.reasonCodes = reasonCodes
            .map { $0.trimmingCharacters(
                in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        self.evaluatorVersion = evaluatorVersion
            .trimmingCharacters(
                in: .whitespacesAndNewlines)
        self.evaluatedAt = evaluatedAt
    }

    /// Skipped sentinel — no evaluation ran. Used for empty
    /// bodies / skipped iters / missing evaluator.
    public static func skipped(
        evaluatorVersion: String = "skipped",
        evaluatedAt: Date = Date()
    ) -> BASShadowEvaluationResult {
        BASShadowEvaluationResult(
            postPermitMode: nil,
            postAuditCodeCount: nil,
            shifted: false,
            reasonCodes: ["evaluator:skipped"],
            evaluatorVersion: evaluatorVersion,
            evaluatedAt: evaluatedAt)
    }
}

// MARK: - BASShadowEvaluating

/// Shadow-evaluator abstract contract.
///
/// Implementations evaluate a (prompt, body) pair after the LLM
/// has produced its body. The result is pure observability — the
/// host runtime decides whether to act on `shifted == true` (e.g.
/// elevate a "post-LLM-shifted" counter, refuse the body in
/// `.silent` mode, etc.).
///
/// ## Strategies (open set)
///
///   - **No-op** (this file): always returns `.skipped`. For
///     tests + ephemeral hosts.
///   - **Substrate-reaudit** (chapter 二百六十七): runs the host's
///     substrate runtime against the body, populates
///     `postPermitMode` + `shifted`. The "rules-lite default" per
///     plan §V.8.
///   - **ML-backed** (chapter 二百六十八+): runs a body-feature
///     classifier; `shifted` reflects the model's blocked-prob.
///     The first 任 side ML head.
///
/// ## Contract
///
///   - Implementations MUST NOT mutate production state.
///   - Implementations MUST be deterministic given (prompt, body,
///     prePermitMode) — even ML-backed conformers should have
///     reproducible inference paths.
///   - Implementations MAY be slow (e.g. ML inference); callers
///     should run them off-MainActor when bench-loop latency
///     matters.
///   - The `evaluate` method returns `.skipped` (NOT throws) on
///     skip paths so callers don't need to error-handle the
///     "skipped" case.
public protocol BASShadowEvaluating: Sendable {
    /// Stable evaluator version identifier. Surfaced in result's
    /// `evaluatorVersion` field.
    var evaluatorVersion: String { get }

    /// Evaluate one (prompt, body) pair against the
    /// pre-LLM permit mode. Returns a typed result; never
    /// throws (skipped paths return `.skipped`).
    ///
    /// - Parameters:
    ///   - prompt: the prompt text the LLM saw (NOT echoed in
    ///     the result; aggregator strips prompts per ADR-012).
    ///   - body: the LLM's response body (also NOT echoed).
    ///   - prePermitMode: substrate's permit-mode rawValue
    ///     pre-LLM. Used to detect `shifted`.
    ///   - sessionRef: optional session ref for forensic audit.
    ///     Implementations don't use this for evaluation logic.
    ///   - turnRef: optional turn ref, same forensics use.
    func evaluate(
        prompt: String,
        body: String,
        prePermitMode: String,
        sessionRef: String,
        turnRef: String
    ) async -> BASShadowEvaluationResult
}

// MARK: - BASNoOpShadowEvaluator

/// Trivial `BASShadowEvaluating` conformer that always returns
/// `.skipped`. For tests + ephemeral hosts that don't want to
/// wire a real evaluator yet. NEVER returns `shifted = true`.
public struct BASNoOpShadowEvaluator: BASShadowEvaluating {
    public let evaluatorVersion: String

    public init(
        evaluatorVersion: String = "noop-v1"
    ) {
        self.evaluatorVersion = evaluatorVersion
    }

    public func evaluate(
        prompt: String,
        body: String,
        prePermitMode: String,
        sessionRef: String,
        turnRef: String
    ) async -> BASShadowEvaluationResult {
        BASShadowEvaluationResult.skipped(
            evaluatorVersion: evaluatorVersion)
    }
}
