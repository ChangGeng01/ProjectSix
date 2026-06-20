// MARK: - BASLLMVerifierPipeline — chapter 四百一 / M935
//
// Phase B step 2 of the LLM Extraction Engine MVP per user
// vision §7 ("榨干验证能力"):typed multi-stage verifier with
// 4 stages,each backed by a separate `BASOrganAdapter` so
// hosts can wire 4 different LLMs to cross-audit one draft。
//
// User vision pin (§7):
//
// > 真正高级的不是每次都让 LLM 深度推理,而是让它互相榨:
// > 生成者 LLM → 审查者 LLM → 反方 LLM → 事实检查 LLM →
// > 压缩者 LLM
//
// ## Stages (per vision §7)
//
//   1. **Reviewer (审查者)**:second LLM checks generator
//      output for hallucination / inconsistency / missing
//      conditions
//   2. **RedTeam (反方)**:third LLM argues AGAINST the
//      conclusion — surfaces weaknesses,counter-arguments
//   3. **FactChecker (事实检查)**:fourth LLM verifies
//      factual claims (host wires this with tool access for
//      external verification, or with a knowledge-base
//      adapter)
//   4. **Compressor (压缩者)**:fifth LLM compresses the
//      review trail into a final user-friendly answer that
//      reflects all reviewer + redteam feedback
//
// ## Composition with M932 engine
//
// M932 engine accepts `BASLLMEngineVerifierCallback` typed
// closure。M935 ships a NEW actor whose `verify(...)` async
// method matches the callback signature shape:hosts wrap
// `BASLLMVerifierPipeline.verify(...)` in a closure and
// inject as the engine's verifier callback。
//
// Per-call flow inside the pipeline:
//   - Reviewer adapter receives draft + task package as a
//     prompt asking "find hallucinations,inconsistencies,
//     missing context";response goes to `reviewerOutcome`
//   - RedTeam adapter receives draft + reviewer output as
//     a prompt asking "argue why this answer is wrong";
//     response goes to `redTeamOutcome`
//   - FactChecker adapter receives draft + claims-to-check
//     as a prompt asking "verify these factual claims";
//     response goes to `factCheckerOutcome`
//   - Compressor adapter receives ALL prior outputs +
//     original task package + draft asking "compose final
//     answer reflecting all review";response is the
//     `finalRecommendedAnswer`
//
// Each stage is OPTIONAL — host can wire 1, 2, 3, or all 4
// adapters。Missing stages are gracefully skipped。
//
// ## Doctrine pins held
//
// - 不变量 #1/#2/#3 — pipeline is observation through
//   review;final permit synthesis still routes through L11
// - 红线 7 hint-only — pipeline output is HINT to the M932
//   engine + downstream gate
// - chapter 二百一一 single-source-of-truth — ONE typed
//   pipeline,vendor-agnostic via per-stage adapters
// - chapter 一百八十五 anti-magic-number — stage prompts +
//   defaults named typed constants
// - chapter 三百九二 (M892) replay-determinism — same
//   stage adapters + same input + same timestamp → same
//   report
// - ADR-014 OPT-IN — pipeline is opt-in;hosts that don't
//   wire it use M932 engine's existing optional-callback
//   verifier slot

import Foundation
import BASRuntimeCore

// MARK: - Stage enum

/// Typed enum naming the 4 stages of the multi-LLM verifier
/// pipeline。Raw values pinned for wire stability + grep。
public enum BASLLMVerifierStage:
    String, Codable, Equatable, Sendable, Hashable, CaseIterable
{
    case reviewer = "reviewer"
    case redTeam = "redTeam"
    case factChecker = "factChecker"
    case compressor = "compressor"
}

// MARK: - Per-stage outcome

/// Typed Codable result of one verifier stage running。
public struct BASLLMVerifierStageOutcome:
    Codable, Equatable, Sendable
{
    public let stage: BASLLMVerifierStage
    /// Raw LLM body returned from this stage's adapter。
    public let rawOutput: String
    /// Did the stage's LLM call complete without throwing?
    public let succeeded: Bool
    /// Error message when `succeeded == false`。Empty
    /// otherwise。
    public let errorMessage: String

    public init(
        stage: BASLLMVerifierStage,
        rawOutput: String,
        succeeded: Bool,
        errorMessage: String = ""
    ) {
        self.stage = stage
        self.rawOutput = rawOutput
        self.succeeded = succeeded
        self.errorMessage = errorMessage
    }
}

// MARK: - Report

/// Typed Codable report aggregating all stages' outcomes。
public struct BASLLMVerifierReport:
    Codable, Equatable, Sendable
{
    /// Per-stage outcomes (only stages that were wired +
    /// invoked appear here)。Indexed by stage enum。
    public let perStage: [BASLLMVerifierStage:
        BASLLMVerifierStageOutcome]

    /// Final recommended answer。Comes from the compressor
    /// stage when wired,else falls back to the original
    /// generator draft body。
    public let finalRecommendedAnswer: String

    /// Aggregate confidence (in [0, 1]) — defaults to 0.5
    /// when no stages produce explicit confidence;hosts
    /// inject custom logic by reading `perStage` directly。
    public let overallConfidence: Double

    /// Counter-arguments aggregated from the redTeam stage
    /// (split per line,trimmed,non-empty)。Mergeable into
    /// M932 verifier feedback's `counterArguments` field。
    public let aggregatedCounterArguments: [String]

    public init(
        perStage: [BASLLMVerifierStage:
            BASLLMVerifierStageOutcome],
        finalRecommendedAnswer: String,
        overallConfidence: Double,
        aggregatedCounterArguments: [String]
    ) {
        self.perStage = perStage
        self.finalRecommendedAnswer =
            finalRecommendedAnswer
        self.overallConfidence = overallConfidence
        self.aggregatedCounterArguments =
            aggregatedCounterArguments
    }
}

// MARK: - Pipeline

/// Actor that composes per-stage `BASOrganAdapter`s into a
/// 4-stage verifier。Hosts inject up to 4 adapters (any
/// subset)。
public actor BASLLMVerifierPipeline {

    /// chapter 一百八十五 anti-magic-number — typed stage
    /// instruction templates。Pinned strings the pipeline
    /// uses to prompt each stage's adapter。Hosts override
    /// per stage if they want vendor-specific phrasing。
    public static let defaultReviewerInstruction: String =
        "You are a careful reviewer。Examine the draft " +
        "below for hallucinations, factual errors, " +
        "inconsistencies, missing conditions。Report " +
        "specific issues found, one per line。If no issues, " +
        "respond with the single word \"PASS\"。"

    public static let defaultRedTeamInstruction: String =
        "You are arguing AGAINST the draft below。Find " +
        "weaknesses, counter-arguments, alternative " +
        "interpretations the original missed。Be specific。" +
        "One counter-argument per line。"

    public static let defaultFactCheckerInstruction: String =
        "Verify the factual claims in the draft below。For " +
        "each claim, mark TRUE / FALSE / UNVERIFIABLE with " +
        "a one-line justification。"

    public static let defaultCompressorInstruction: String =
        "You are the final composer。Given the original " +
        "draft + reviewer feedback + redteam counters + " +
        "fact-checker findings, write a final user-facing " +
        "answer that reflects all this review。Stay concise。"

    public static let defaultOverallConfidence: Double = 0.5

    // MARK: - Stage adapter map

    private let adapters:
        [BASLLMVerifierStage: any BASOrganAdapter]
    private let reviewerInstruction: String
    private let redTeamInstruction: String
    private let factCheckerInstruction: String
    private let compressorInstruction: String

    // MARK: - Telemetry

    private(set) var totalVerifyCalls: Int = 0
    private(set) var perStageCalls:
        [BASLLMVerifierStage: Int] = [:]
    private(set) var perStageFailures:
        [BASLLMVerifierStage: Int] = [:]

    public init(
        adapters: [BASLLMVerifierStage:
            any BASOrganAdapter],
        reviewerInstruction: String =
            BASLLMVerifierPipeline
                .defaultReviewerInstruction,
        redTeamInstruction: String =
            BASLLMVerifierPipeline
                .defaultRedTeamInstruction,
        factCheckerInstruction: String =
            BASLLMVerifierPipeline
                .defaultFactCheckerInstruction,
        compressorInstruction: String =
            BASLLMVerifierPipeline
                .defaultCompressorInstruction,
        contractInstall: BASLLMContractInstall? = .observeOnly(purpose: .verify),
        // Tranche A2 first production caller (2026-06-12) — the decode lane for verifier stages, resolved
        // through the single authority `BASDecodeLanePolicy`. nil (DEFAULT) → `lane(for: .scoutDefault)` →
        // `.scout` (temp 0.1) ⇒ byte-equal-off (ADR-014). `.greedy` (= `lane(for: .factual)`) →
        // `.greedyDeterministic` (temp 0) ⇒ ENGAGES the certified spec-decoder (1.34× device-confirmed, A1)
        // AND makes verification byte-REPRODUCIBLE. Flipping the DEFAULT to `.greedy` is the separate,
        // evidence-gated step (needs a verification-quality A/B — the first device run was DEFERRED, device
        // thermally cooked; see SPEC_DECODE_CERT_RESULTS.md §A2). The default now routes THROUGH the policy,
        // so the doctrine encoder has a real production caller instead of zero.
        decodeLane: BASDecodeLane? = nil
    ) {
        // §13 #12 opt-in: when an install is supplied, every stage adapter is contracted
        // (fail-closed) + traced; nil → adapters used unwrapped (byte-equal-off, R1).
        if let ci = contractInstall {
            self.adapters = adapters.mapValues { ci.wrap($0) as any BASOrganAdapter }
        } else {
            self.adapters = adapters
        }
        self.reviewerInstruction = reviewerInstruction
        self.redTeamInstruction = redTeamInstruction
        self.factCheckerInstruction =
            factCheckerInstruction
        self.compressorInstruction = compressorInstruction
        // DEFAULT (nil) resolves THROUGH the single doctrine authority: lane(for: .scoutDefault) → .scout
        // (byte-equal); a host-elected lane uses its own preset.
        self.stagePreset = (decodeLane ?? BASDecodeLanePolicy.lane(for: .scoutDefault)).preset
    }

    /// The preset every verifier stage decodes with (Tranche A2). Default `.scout` (byte-equal); a
    /// host electing `decodeLane: .greedy` gets `.greedyDeterministic` → spec-decode + reproducibility.
    private let stagePreset: BASOrganPreset

    // MARK: - Verify

    /// Run the wired stages on `draft`。Returns typed report。
    /// Stages without a wired adapter are SKIPPED (no entry
    /// in `perStage`)。
    public func verify(
        draft: BASOrganDraft,
        taskPackage: BASLLMTaskPackage
    ) async -> BASLLMVerifierReport {
        totalVerifyCalls += 1

        var outcomes: [BASLLMVerifierStage:
            BASLLMVerifierStageOutcome] = [:]

        // Stage 1:Reviewer
        if let reviewer = adapters[.reviewer] {
            outcomes[.reviewer] = await runStage(
                .reviewer,
                adapter: reviewer,
                instruction: reviewerInstruction,
                userPrompt: makeReviewerPrompt(
                    draft: draft,
                    taskPackage: taskPackage),
                taskPackage: taskPackage)
        }

        // Stage 2:RedTeam
        if let redTeam = adapters[.redTeam] {
            outcomes[.redTeam] = await runStage(
                .redTeam,
                adapter: redTeam,
                instruction: redTeamInstruction,
                userPrompt: makeRedTeamPrompt(
                    draft: draft,
                    reviewerOutput:
                        outcomes[.reviewer]?.rawOutput,
                    taskPackage: taskPackage),
                taskPackage: taskPackage)
        }

        // Stage 3:FactChecker
        if let factChecker = adapters[.factChecker] {
            outcomes[.factChecker] = await runStage(
                .factChecker,
                adapter: factChecker,
                instruction: factCheckerInstruction,
                userPrompt: makeFactCheckerPrompt(
                    draft: draft,
                    taskPackage: taskPackage),
                taskPackage: taskPackage)
        }

        // Stage 4:Compressor
        var finalAnswer = draft.body
        if let compressor = adapters[.compressor] {
            let outcome = await runStage(
                .compressor,
                adapter: compressor,
                instruction: compressorInstruction,
                userPrompt: makeCompressorPrompt(
                    draft: draft,
                    reviewerOutput:
                        outcomes[.reviewer]?.rawOutput,
                    redTeamOutput:
                        outcomes[.redTeam]?.rawOutput,
                    factCheckerOutput:
                        outcomes[.factChecker]?.rawOutput,
                    taskPackage: taskPackage),
                taskPackage: taskPackage)
            outcomes[.compressor] = outcome
            if outcome.succeeded {
                finalAnswer = outcome.rawOutput
            }
        }

        // Aggregate counter-arguments from redTeam stage
        let counterArgs: [String]
        if let redTeamOutcome = outcomes[.redTeam],
           redTeamOutcome.succeeded
        {
            counterArgs = Self.parseLines(
                redTeamOutcome.rawOutput)
        } else {
            counterArgs = []
        }

        return BASLLMVerifierReport(
            perStage: outcomes,
            finalRecommendedAnswer: finalAnswer,
            overallConfidence:
                Self.defaultOverallConfidence,
            aggregatedCounterArguments: counterArgs)
    }

    // MARK: - Stage runner

    private func runStage(
        _ stage: BASLLMVerifierStage,
        adapter: any BASOrganAdapter,
        instruction: String,
        userPrompt: String,
        taskPackage: BASLLMTaskPackage
    ) async -> BASLLMVerifierStageOutcome {
        perStageCalls[stage, default: 0] += 1
        let request = BASOrganRequest(
            requestID:
                "\(taskPackage.taskID)-\(stage.rawValue)",
            role: .scout,
            preset: stagePreset,   // Tranche A2: `.scout` default (byte-equal) or the elected greedy lane.
            instruction: instruction + "\n\n" + userPrompt)
        do {
            // P1: factual verification → elect prompt-lookup (TOKEN-identical under greedy; .scout/temp>0 stages
            // fail-close to draft(_:), byte-equal). S5: pass the purpose (.factual); the planner picks the lane.
            let draft = try await adapter.draft(request, purpose: .factual)
            return BASLLMVerifierStageOutcome(
                stage: stage,
                rawOutput: draft.body,
                succeeded: true)
        } catch {
            perStageFailures[stage, default: 0] += 1
            return BASLLMVerifierStageOutcome(
                stage: stage,
                rawOutput: "",
                succeeded: false,
                errorMessage: "\(error)")
        }
    }

    // MARK: - Prompt composers (pure)

    private nonisolated func makeReviewerPrompt(
        draft: BASOrganDraft,
        taskPackage: BASLLMTaskPackage
    ) -> String {
        return "ORIGINAL GOAL: \(taskPackage.goal)\n" +
            "DRAFT TO REVIEW:\n\(draft.body)"
    }

    private nonisolated func makeRedTeamPrompt(
        draft: BASOrganDraft,
        reviewerOutput: String?,
        taskPackage: BASLLMTaskPackage
    ) -> String {
        var lines: [String] = [
            "ORIGINAL GOAL: \(taskPackage.goal)",
            "DRAFT TO ATTACK:",
            draft.body
        ]
        if let r = reviewerOutput {
            lines.append("REVIEWER ALREADY FOUND:")
            lines.append(r)
        }
        return lines.joined(separator: "\n")
    }

    private nonisolated func makeFactCheckerPrompt(
        draft: BASOrganDraft,
        taskPackage: BASLLMTaskPackage
    ) -> String {
        return "DRAFT TO FACT-CHECK:\n\(draft.body)"
    }

    private nonisolated func makeCompressorPrompt(
        draft: BASOrganDraft,
        reviewerOutput: String?,
        redTeamOutput: String?,
        factCheckerOutput: String?,
        taskPackage: BASLLMTaskPackage
    ) -> String {
        var lines: [String] = [
            "ORIGINAL GOAL: \(taskPackage.goal)",
            "ORIGINAL DRAFT:",
            draft.body
        ]
        if let r = reviewerOutput {
            lines.append("REVIEWER FEEDBACK:")
            lines.append(r)
        }
        if let rt = redTeamOutput {
            lines.append("RED TEAM COUNTER-ARGS:")
            lines.append(rt)
        }
        if let fc = factCheckerOutput {
            lines.append("FACT CHECK:")
            lines.append(fc)
        }
        return lines.joined(separator: "\n")
    }

    /// Pure helper:split a multi-line LLM body into trimmed
    /// non-empty lines。Used for redTeam counter-argument
    /// extraction。
    private nonisolated static func parseLines(
        _ raw: String
    ) -> [String] {
        raw.split(
            separator: "\n",
            omittingEmptySubsequences: true)
            .map {
                $0.trimmingCharacters(
                    in: .whitespacesAndNewlines)
            }
            .filter { !$0.isEmpty }
    }
}

// MARK: - Engine integration helper

extension BASLLMVerifierPipeline {

    /// Produce a `BASLLMEngineVerifierCallback` suitable for
    /// injecting into the M932 engine's `verifier` slot。
    /// Maps the typed `BASLLMVerifierReport` onto M932's
    /// typed `BASLLMVerifierFeedback` shape。
    ///
    /// ## M940 audit fix:`approved` now reflects per-stage
    /// outcomes
    ///
    /// Pre-M940 `approved` was hardcoded `true` regardless
    /// of which stages failed。A pipeline where 3 of 4
    /// stages threw still reported "approved",hiding failure
    /// from downstream gates。Post-M940:
    ///   - approved = true iff every WIRED stage's
    ///     `succeeded == true`
    ///   - failure-stage names appended to counterArguments
    ///     as `"verifier-stage-failed:<stage>"` so downstream
    ///     consumers can grep
    public nonisolated func makeEngineVerifierCallback()
        -> BASLLMEngineVerifierCallback
    {
        return { [self] draft, taskPackage in
            let report = await verify(
                draft: draft,
                taskPackage: taskPackage)
            // M940:approved iff all wired stages succeeded
            let allSucceeded = report.perStage.values
                .allSatisfy { $0.succeeded }
            // M940:append failure-stage names so downstream
            // can detect partial failure even when other
            // stages produced output
            var counterArgs =
                report.aggregatedCounterArguments
            for (stage, outcome) in report.perStage {
                if !outcome.succeeded {
                    counterArgs.append(
                        "verifier-stage-failed:" +
                        stage.rawValue)
                }
            }
            return BASLLMVerifierFeedback(
                approved: allSucceeded,
                amendedAnswer:
                    report.finalRecommendedAnswer
                        != draft.body
                    ? report.finalRecommendedAnswer
                    : nil,
                counterArguments: counterArgs,
                confidenceScores: [
                    "overall": report.overallConfidence
                ])
        }
    }
}
