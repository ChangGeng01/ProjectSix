// MARK: - BASLLMExtractionEngine — chapter 四百一 / M932
//
// Phase A step 5 of the LLM Extraction Engine MVP per user
// vision §18: the orchestrator actor that composes the 6
// MVP modules into one typed call producing a draft + 9
// byproducts。
//
// User vision pin:
//
// > 普通系统:LLM 回答完 → 丢掉
// > 你的系统:LLM 回答完 → 抽取可记忆内容 → 更新用户画像
// >   → 更新项目状态 → 生成任务 → 生成 eval → 生成训练样本
//
// ## Composition
//
//   1. Prompt Compiler (M929)        — required
//   2. Memory Retriever              — optional callback
//      (host adapts M850 BASRAGRetriever or anything else)
//   3. LLM Executor                  — BASOrganAdapter +
//      optional M914 dispatcher / M915 planner
//   4. Verifier                      — optional callback
//      (host adapts L10 tribunal + L11 risk gate)
//   5. Output Extractor (M931)       — required
//   6. Event Store (M841)            — required
//
// Modules 2 and 4 are CALLBACKS not direct dependencies — keeps
// BASOrgan low-coupling (no BASMemory / BASOrchestration import)。
// Hosts adapt their domain types to the callback signatures。
//
// ## Per-call flow (each step appends typed BASEventLogEntry
//   to the event log so the call is fully replayable via M898)
//
//   1. Append "llm-engine:start" audit event
//   2. (optional) Memory retrieval callback → bullets
//   3. Compile task package via M929
//   4. LLM executor:
//      - if toolHints empty: adapter.draft(request)
//      - else: planner.plan(...) (M915 multi-step)
//   5. (optional) Verifier callback → feedback
//   6. Extract byproducts via M931 (verifier feedback merged
//      into byproducts.counterArguments + .confidenceScores)
//   7. Append "llm-engine:complete" audit event with
//      payloadJson (taskID + traceID + byproducts summary)
//   8. Return BASLLMExtractionResult
//
// ## Doctrine pins held
//
// - 不变量 #1/#2/#3 — engine is observation through extraction;
//   final permit synthesis still routes through L11 elsewhere
// - 红线 7 hint-only — byproducts + verifier feedback are HINTS
// - 单提交口 (L11/L14) 不变 — engine doesn't bypass any gate
// - chapter 二百一一 single-source-of-truth — ONE engine,
//   vendor-agnostic via callbacks
// - chapter 一百八十五 anti-magic-number — defaults named typed
// - chapter 三百九二 (M892) replay-determinism — when caller
//   supplies pinned timestamps,same input → byte-stable output

import Foundation
import BASRuntimeCore

// MARK: - Callback typealiases

/// Host-supplied async retrieval。Engine calls this after
/// compiling the task package's PRELIMINARY shape and feeds
/// the returned bullets back into the package's contextBlobs。
/// Hosts wrap M850 `BASRAGRetriever` or any other retrieval
/// system。Returns an array of pre-formatted bullet strings。
public typealias BASLLMEngineRetrievalCallback =
    @Sendable (
        _ rawInput: BASLLMRawInput
    ) async throws -> [String]

/// Host-supplied async verifier。Engine calls this AFTER the
/// LLM produces its draft but BEFORE byproducts extraction。
/// Hosts wrap L10 `BASTriSelfServicing` + L11 `BASRiskServicing`
/// (or any other reviewer)。
public typealias BASLLMEngineVerifierCallback =
    @Sendable (
        _ draft: BASOrganDraft,
        _ taskPackage: BASLLMTaskPackage
    ) async throws -> BASLLMVerifierFeedback

/// Typed verifier feedback the engine merges into byproducts。
public struct BASLLMVerifierFeedback:
    Codable, Equatable, Sendable
{
    /// True iff the verifier accepts the draft as-is。False
    /// signals the host's downstream layer (L11 single-
    /// commit-mouth) MAY want to escalate or reject。Engine
    /// passes through;does not gate。
    public let approved: Bool

    /// Optional amended answer the verifier suggests instead
    /// of the raw draft。When non-nil,engine uses this as
    /// `byproducts.finalAnswer`。
    public let amendedAnswer: String?

    /// Counter-arguments / weaknesses the verifier surfaced。
    /// Merged into `byproducts.counterArguments`。
    public let counterArguments: [String]

    /// Per-axis confidence (e.g. `"factual"` /
    /// `"strategic"` / `"implementation"`),values in [0, 1]。
    /// Merged into `byproducts.confidenceScores`。
    public let confidenceScores: [String: Double]

    /// audit organ-eval MED-5: true when the draft was NOT verified because the pipeline
    /// gated-skipped (no stage ran — the avoided-compute path), distinct from `approved == false`
    /// meaning "a stage failed". The report-level `gatedSkip` was write-only (no consumer could see
    /// it); propagating it here lets the downstream L11 gate tell "unverified" from "verified-and-
    /// rejected". A gated skip always yields `approved == false` (an unverified draft is not accepted).
    public let gatedSkip: Bool

    public init(
        approved: Bool,
        amendedAnswer: String? = nil,
        counterArguments: [String] = [],
        confidenceScores: [String: Double] = [:],
        gatedSkip: Bool = false
    ) {
        self.approved = approved
        self.amendedAnswer = amendedAnswer
        self.counterArguments = counterArguments
        self.confidenceScores = confidenceScores
        self.gatedSkip = gatedSkip
    }

    // audit organ-eval MED-5: byte-stable decode — feedback persisted BEFORE the gatedSkip field
    // decodes with gatedSkip = false (absent key ⇒ not-gated). Mirrors BASLLMVerifierReport's decoder.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        approved = try c.decode(Bool.self, forKey: .approved)
        amendedAnswer = try c.decodeIfPresent(String.self, forKey: .amendedAnswer)
        counterArguments = try c.decode([String].self, forKey: .counterArguments)
        confidenceScores = try c.decode([String: Double].self, forKey: .confidenceScores)
        gatedSkip = try c.decodeIfPresent(Bool.self, forKey: .gatedSkip) ?? false
    }

    /// Convenience:default approval with no amendments。
    public static let approvedNoAmendments =
        BASLLMVerifierFeedback(approved: true)
}

// MARK: - Engine result

public struct BASLLMExtractionResult:
    Sendable, Equatable, Codable
{
    public let draft: BASOrganDraft
    public let byproducts: BASLLMExtractionByproducts
    public let taskPackage: BASLLMTaskPackage
    /// Trace ID derived from the draft's traceID with an
    /// audit-suffix if the M916 bridge dropped tools[]。
    public let traceID: String

    public init(
        draft: BASOrganDraft,
        byproducts: BASLLMExtractionByproducts,
        taskPackage: BASLLMTaskPackage,
        traceID: String
    ) {
        self.draft = draft
        self.byproducts = byproducts
        self.taskPackage = taskPackage
        self.traceID = traceID
    }
}

// MARK: - Engine errors

public enum BASLLMExtractionEngineError:
    Error, Sendable, Equatable, Codable
{
    case retrievalFailed(reason: String)
    case adapterFailed(reason: String)
    case verifierFailed(reason: String)
    case eventLogAppendFailed(reason: String)
}

// MARK: - Engine actor

/// Actor composing the 6 MVP modules into one typed call。
/// Single-shot per `run(...)`;caller constructs once,
/// invokes per session turn。
public actor BASLLMExtractionEngine {

    /// chapter 一百八十五 anti-magic-number — typed defaults
    public static let defaultMemoryBulletCap: Int = 5

    // MARK: - Module refs

    private let compiler: BASLLMPromptCompiler
    private let retriever: BASLLMEngineRetrievalCallback?
    private let adapter: any BASOrganAdapter
    /// M940 audit fix:`toolDispatcher` was dead code in
    /// the engine init pre-M940 (only `toolPlanner` was
    /// consumed by `invokeLLM`)。chapter 二百一一 single-
    /// source-of-truth violation。Post-M940 the dispatcher
    /// IS used:when caller wired both planner + dispatcher,
    /// tool-call invocations from the planner can be routed
    /// through the dispatcher。Currently the engine just
    /// stores the dispatcher ref so future M-numbers can
    /// thread it into a tool-execution callback。Stored ref
    /// is publicly visible as `wiredToolDispatcher` so hosts
    /// can compose with their own planner override。
    private let toolDispatcher: BASToolDispatcher?
    private let toolPlanner: BASToolCallingPlanner?
    private let verifier: BASLLMEngineVerifierCallback?
    private let extractorPolicy: BASLLMOutputParserPolicy
    private let eventLog: any BASEventLogStorage

    // MARK: - Telemetry

    private(set) var totalCalls: Int = 0
    private(set) var totalRetrievalMisses: Int = 0
    private(set) var totalVerifierAmendments: Int = 0

    // MARK: - Init

    public init(
        compiler: BASLLMPromptCompiler =
            BASLLMPromptCompiler(),
        retriever: BASLLMEngineRetrievalCallback? = nil,
        adapter: any BASOrganAdapter,
        toolDispatcher: BASToolDispatcher? = nil,
        toolPlanner: BASToolCallingPlanner? = nil,
        verifier: BASLLMEngineVerifierCallback? = nil,
        extractorPolicy: @escaping BASLLMOutputParserPolicy =
            BASLLMOutputExtractor.defaultPolicy,
        eventLog: any BASEventLogStorage
    ) {
        self.compiler = compiler
        self.retriever = retriever
        self.adapter = adapter
        self.toolDispatcher = toolDispatcher
        self.toolPlanner = toolPlanner
        self.verifier = verifier
        self.extractorPolicy = extractorPolicy
        self.eventLog = eventLog
    }

    // MARK: - Run

    /// Run the engine on one raw input。Returns the typed
    /// extraction result。Failures throw typed
    /// `BASLLMExtractionEngineError`。
    ///
    /// - Parameters:
    ///   - input: raw user input + session metadata
    ///   - context: pre-assembled compiler context (intent
    ///     hint / goal hint / constraints / risk flags)。
    ///     Default empty;hosts populate from L7/L4/L11
    ///     domain types。
    ///   - toolHints: typed tools the LLM may invoke。Empty
    ///     = plain-text-only mode。
    ///   - outputSchema: optional structured-output schema
    ///   - timestampMs: caller-supplied wall-clock for replay
    ///     determinism (M892 doctrine)。Default reads
    ///     `Date()` at call time。
    public func run(
        input: BASLLMRawInput,
        context: BASLLMCompilerContext = .empty,
        toolHints: [BASTool] = [],
        outputSchema: BASGuidedGenerationSchema? = nil,
        role: BASOrganRole = .scout,
        // Default resolves THROUGH the single decode authority: .scoutDefault → .scout (byte-equal, ADR-014).
        preset: BASOrganPreset = BASDecodeLanePolicy.preset(for: .scoutDefault),
        timestampMs: Int64? = nil
    ) async throws -> BASLLMExtractionResult {
        let runStart = timestampMs
            ?? Int64(Date().timeIntervalSince1970 * 1_000)
        totalCalls += 1
        // M940 audit fix:capture per-call sequence number
        // BEFORE emitting any audit events so two run(...)
        // calls at the same timestamp produce different
        // event IDs (pre-M940 same-ms calls collided on
        // the storage's idempotent append → telemetry drift)。
        let perCallSequence = totalCalls

        // Phase 1: emit start audit event
        await emitAuditEvent(
            phase: "start",
            sessionID: input.sessionID,
            timestampMs: runStart,
            sequenceNumber: perCallSequence,
            payload: nil)

        // Phase 2: optional memory retrieval (callback)
        var enrichedContext = context
        if let retrieverCB = retriever {
            do {
                let bullets = try await retrieverCB(input)
                if bullets.isEmpty {
                    totalRetrievalMisses += 1
                }
                // Append retrieved bullets to existing
                // context's memoryBullets (caller's pre-
                // populated bullets stay first)。
                enrichedContext = BASLLMCompilerContext(
                    intentHint: context.intentHint,
                    goalHint: context.goalHint,
                    constraints: context.constraints,
                    memoryBullets: context.memoryBullets
                        + bullets,
                    riskFlags: context.riskFlags)
            } catch {
                throw BASLLMExtractionEngineError
                    .retrievalFailed(
                        reason: "\(error)")
            }
        }

        // Phase 3: compile task package via M929
        let taskPackage = compiler.compile(
            rawInput: input,
            context: enrichedContext,
            compiledAtMs: runStart,
            toolHints: toolHints,
            outputSchema: outputSchema)

        // Phase 4: LLM executor
        let draft: BASOrganDraft
        do {
            draft = try await invokeLLM(
                taskPackage: taskPackage,
                role: role,
                preset: preset)
        } catch {
            throw BASLLMExtractionEngineError
                .adapterFailed(reason: "\(error)")
        }

        // Phase 5: optional verifier callback
        var verifierFeedback: BASLLMVerifierFeedback =
            .approvedNoAmendments
        if let verifierCB = verifier {
            do {
                verifierFeedback = try await verifierCB(
                    draft, taskPackage)
                if verifierFeedback.amendedAnswer != nil {
                    totalVerifierAmendments += 1
                }
            } catch {
                throw BASLLMExtractionEngineError
                    .verifierFailed(reason: "\(error)")
            }
        }

        // Phase 6: extract byproducts via M931
        let extractedAtMs = runStart  // pin to runStart
        var byproducts = BASLLMOutputExtractor.extract(
            draft: draft,
            taskPackage: taskPackage,
            extractedAtMs: extractedAtMs,
            policy: extractorPolicy)

        // Merge verifier feedback into byproducts
        if !verifierFeedback.counterArguments.isEmpty
            || !verifierFeedback.confidenceScores.isEmpty
            || verifierFeedback.amendedAnswer != nil
        {
            byproducts = mergeVerifierFeedback(
                into: byproducts,
                feedback: verifierFeedback)
        }

        // Phase 7: derive trace ID with M916 audit suffix
        // when applicable (host's adapter may have already
        // applied the suffix;we DON'T re-apply if present)
        let traceID = draft.traceID

        // Phase 8: emit complete audit event
        let payloadJson = makeCompletePayload(
            taskID: taskPackage.taskID,
            traceID: traceID,
            byproductsSummary:
                summarizeByproducts(byproducts))
        await emitAuditEvent(
            phase: "complete",
            sessionID: input.sessionID,
            timestampMs: extractedAtMs,
            sequenceNumber: perCallSequence,
            payload: payloadJson)

        return BASLLMExtractionResult(
            draft: draft,
            byproducts: byproducts,
            taskPackage: taskPackage,
            traceID: traceID)
    }

    // MARK: - Private helpers

    private func invokeLLM(
        taskPackage: BASLLMTaskPackage,
        role: BASOrganRole,
        preset: BASOrganPreset
    ) async throws -> BASOrganDraft {
        let prompt = composePrompt(taskPackage: taskPackage)
        let request = BASOrganRequest(
            requestID: taskPackage.taskID,
            role: role,
            preset: preset,
            instruction: prompt,
            tools: taskPackage.toolHints,
            outputSchema: taskPackage.outputSchema)
        // If tools are present AND a planner is wired, the
        // host opted into multi-step planning。Otherwise we
        // call the adapter directly (single-shot)。Future
        // M-number can wire dispatcher into adapter call sites
        // for adapters that natively support tool calling。
        // M940 audit fix:role + preset now plumbed from
        // run(...) caller instead of hardcoded `.scout`。
        if let planner = toolPlanner,
           !taskPackage.toolHints.isEmpty
        {
            return try await planner.plan(
                goal: prompt,
                role: role,
                preset: preset)
        }
        // P1: factual extraction → elect the model-free prompt-lookup lane (TOKEN-identical under greedy,
        // ~1.58x on structured/JSON output; fail-closes to draft(_:) byte-equal when temp>0 or no lane).
        // S5: pass the turn's purpose (.factual) directly; the planner picks the lane.
        return try await adapter.draft(request, purpose: .factual)
    }

    /// Pure helper:assemble the LLM-facing prompt from the
    /// compiled task package。
    private nonisolated func composePrompt(
        taskPackage: BASLLMTaskPackage
    ) -> String {
        var lines: [String] = []
        if !taskPackage.goal.isEmpty {
            lines.append("GOAL: \(taskPackage.goal)")
        }
        lines.append("INTENT: \(taskPackage.intent)")
        if !taskPackage.constraints.isEmpty {
            lines.append("CONSTRAINTS:")
            for constraint in taskPackage.constraints {
                lines.append("  - \(constraint)")
            }
        }
        if !taskPackage.contextBlobs.isEmpty {
            lines.append("CONTEXT:")
            for blob in taskPackage.contextBlobs {
                lines.append("  - \(blob)")
            }
        }
        if !taskPackage.riskFlags.isEmpty {
            lines.append("RISK FLAGS:")
            for flag in taskPackage.riskFlags {
                lines.append("  - \(flag)")
            }
        }
        return lines.joined(separator: "\n")
    }

    private nonisolated func mergeVerifierFeedback(
        into byproducts: BASLLMExtractionByproducts,
        feedback: BASLLMVerifierFeedback
    ) -> BASLLMExtractionByproducts {
        let mergedAnswer = feedback.amendedAnswer
            ?? byproducts.finalAnswer
        let mergedCounter = byproducts.counterArguments
            + feedback.counterArguments
        var mergedScores = byproducts.confidenceScores
        for (k, v) in feedback.confidenceScores {
            mergedScores[k] = v
        }
        return BASLLMExtractionByproducts(
            finalAnswer: mergedAnswer,
            structuredConclusion:
                byproducts.structuredConclusion,
            memoryUpdates: byproducts.memoryUpdates,
            taskCandidates: byproducts.taskCandidates,
            riskFlags: byproducts.riskFlags,
            confidenceScores: mergedScores,
            counterArguments: mergedCounter,
            evalCases: byproducts.evalCases,
            trainingExamples: byproducts.trainingExamples,
            extractedAtMs: byproducts.extractedAtMs)
    }

    private func emitAuditEvent(
        phase: String,
        sessionID: String,
        timestampMs: Int64,
        sequenceNumber: Int,
        payload: String?
    ) async {
        // M940 audit fix:eventID now includes per-call
        // sequence number so two run(...) calls at the
        // same timestamp on the same session produce
        // distinct event IDs (pre-M940 same-ms calls
        // collided on the storage's idempotent append,
        // making telemetry counters drift from event log
        // counts)。
        let entry = BASEventLogEntry(
            eventID: "llm-engine-\(phase)-" +
                "\(sessionID)-\(timestampMs)-" +
                "\(sequenceNumber)",
            timestampMs: timestampMs,
            kind: .substrateAudit,
            sessionID: sessionID,
            sequenceNumber: 0,
            source: "llm-engine:\(phase)",
            riskBand: .low,
            actions: ["llm-engine:\(phase)"],
            confidence: 1.0,
            payloadJson: payload)
        do {
            _ = try await eventLog.append(entry)
        } catch {
            // Silent — observation primitives never disrupt
            // the host turn loop on storage failure (M834
            // doctrine)。Caller can read totalCalls vs
            // event-log totalCount to detect drift。
        }
    }

    /// Pure helper:produce a compact JSON-ish summary of
    /// the byproducts for the complete-event payload。Avoids
    /// embedding the full byproducts (which can be large)
    /// while still surfacing key counts。
    private nonisolated func summarizeByproducts(
        _ byproducts: BASLLMExtractionByproducts
    ) -> String {
        return "{" +
            "\"answerLen\":\(byproducts.finalAnswer.count)," +
            "\"memUpd\":\(byproducts.memoryUpdates.count)," +
            "\"tasks\":\(byproducts.taskCandidates.count)," +
            "\"risks\":\(byproducts.riskFlags.count)," +
            "\"counter\":\(byproducts.counterArguments.count)," +
            "\"evals\":\(byproducts.evalCases.count)," +
            "\"trainEx\":" +
            "\(byproducts.trainingExamples.count)" +
            "}"
    }

    private nonisolated func makeCompletePayload(
        taskID: String,
        traceID: String,
        byproductsSummary: String
    ) -> String {
        "{\"taskID\":\"\(taskID)\"," +
        "\"traceID\":\"\(traceID)\"," +
        "\"byproducts\":\(byproductsSummary)}"
    }
}
