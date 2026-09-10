// MARK: - BASLLMExtractionByproducts — chapter 四百一 / M930
//
// Phase A step 3 of the LLM Extraction Engine MVP per user
// vision §19: typed 9-field Codable bundle of byproducts
// produced from EVERY LLM call。
//
// User vision pin (§19):
//
// > 普通人花一次 token,只买了答案。你花一次 token,
// > 要买 9 样东西:
// >   1. 用户答案
// >   2. 结构化结论
// >   3. 记忆更新
// >   4. 下一步任务
// >   5. 风险标记
// >   6. 置信度评分
// >   7. 反方意见
// >   8. eval 测试样本
// >   9. 小模型训练数据
//
// This file ships the 9 typed candidates + the bundle that
// holds them。M931 extractor produces;M932 engine returns;
// hosts consume per their downstream pipelines。
//
// ## Why TYPED candidates (not just dictionaries)
//
// Each downstream consumer needs a specific shape:
//   - L13 蜕变炉 (training data sublimation) needs
//     `inputText` + `goodAnswerTraits` + `score` for the
//     M917 corpus
//   - Task systems need `title` + `priority` + `deadline`
//   - L12 BASEvalRun (M861) needs `inputText` +
//     `expectedBehavior` + `scoringMethod`
//   - L8 memory writers need `kind` + `content` + `confidence`
// String-typed-key dictionaries would lose all this。Typed
// candidates make the pipeline compile-time correct end-to-end。
//
// ## Doctrine pins held
//
// - 不变量 #1/#2/#3 — byproducts are observation,not gating
// - 红线 7 hint-only — byproducts are HINTS for downstream
//   consumers;gate at L11 still decides
// - chapter 二百一一 single-source-of-truth — ONE typed
//   shape across all hosts/extractors
// - chapter 一百八十五 anti-magic-number — priority/kind
//   raw values pinned
// - chapter 三百九二 (M892) replay-determinism — same draft
//   + same task package + same parser policy + same
//   `extractedAtMs` → byte-identical byproducts JSON
// - ADR-014 OPT-IN — extractor only fires when caller invokes

import Foundation

// MARK: - Memory update candidate (byproduct 3)

/// Typed Codable suggestion that the L8 memory layer
/// CONSIDER appending an atom。Host's memory writer decides
/// whether to actually persist (red 线 7 hint-only)。
public struct BASMemoryUpdateCandidate:
    Codable, Equatable, Sendable, Hashable
{
    /// Typed kind of update。Pinned strings for canonical
    /// memory taxonomy (chapter 一百八十五)。
    public let kind: String
    /// The content text the memory writer would persist。
    public let content: String
    /// Confidence the LLM (or the parser) attaches to this
    /// suggestion,in [0, 1]。
    public let confidence: Double

    public init(
        kind: String,
        content: String,
        confidence: Double
    ) {
        // M940 audit fix:NaN comparisons return false →
        // `confidence >= 0` would trip the precondition
        // anyway,but Inf would silently slip。Pin
        // explicitly to finite + [0,1]。
        precondition(confidence.isFinite,
            "confidence must be finite (no NaN/Inf)")
        precondition(confidence >= 0 && confidence <= 1,
            "confidence must be in [0, 1]")
        self.kind = kind
        self.content = content
        self.confidence = confidence
    }
}

// MARK: - Task candidate (byproduct 4)

public struct BASTaskCandidate:
    Codable, Equatable, Sendable, Hashable
{
    /// Typed priority enum。Raw values pinned for wire
    /// stability。
    public enum Priority:
        String, Codable, Equatable, Sendable, Hashable,
        CaseIterable
    {
        case low = "low"
        case medium = "medium"
        case high = "high"
    }

    public let title: String
    public let priority: Priority
    /// Optional deadline (millis since UNIX epoch)。Nil =
    /// no deadline (task runs at host discretion)。
    public let deadlineMs: Int64?
    /// Session ID this task descends from (for traceability)。
    public let parentSessionID: String

    public init(
        title: String,
        priority: Priority = .medium,
        deadlineMs: Int64? = nil,
        parentSessionID: String
    ) {
        self.title = title
        self.priority = priority
        self.deadlineMs = deadlineMs
        self.parentSessionID = parentSessionID
    }
}

// MARK: - Eval case candidate (byproduct 8)

public struct BASEvalCaseCandidate:
    Codable, Equatable, Sendable, Hashable
{
    /// Typed scoring-method enum。
    public enum ScoringMethod:
        String, Codable, Equatable, Sendable, Hashable,
        CaseIterable
    {
        case stringExactMatch = "stringExactMatch"
        case regexMatch = "regexMatch"
        case semanticSimilarity = "semanticSimilarity"
        case humanReview = "humanReview"
    }

    /// Input that should be fed to the LLM under test。
    public let inputText: String
    /// Plain-language description of expected good behavior。
    public let expectedBehavior: String
    /// How a future test runner should score。
    public let scoringMethod: ScoringMethod

    public init(
        inputText: String,
        expectedBehavior: String,
        scoringMethod: ScoringMethod
    ) {
        self.inputText = inputText
        self.expectedBehavior = expectedBehavior
        self.scoringMethod = scoringMethod
    }
}

// MARK: - Training example candidate (byproduct 9)

public struct BASTrainingExampleCandidate:
    Codable, Equatable, Sendable, Hashable
{
    /// Input the model should learn to handle。
    public let inputText: String
    /// Compressed summary of the context (memory hits,
    /// constraints) the model had access to。
    public let contextSummary: String
    /// Traits a good answer should have。
    public let goodAnswerTraits: [String]
    /// Traits a bad answer would have (anti-pattern signal)。
    public let badAnswerTraits: [String]
    /// Score this example carries when added to the corpus,
    /// in [0, 1]。Used for training-data weighting。
    public let score: Double

    public init(
        inputText: String,
        contextSummary: String,
        goodAnswerTraits: [String],
        badAnswerTraits: [String],
        score: Double
    ) {
        // M940 audit fix:NaN/Inf guard before range check
        precondition(score.isFinite,
            "score must be finite (no NaN/Inf)")
        precondition(score >= 0 && score <= 1,
            "score must be in [0, 1]")
        self.inputText = inputText
        self.contextSummary = contextSummary
        self.goodAnswerTraits = goodAnswerTraits
        self.badAnswerTraits = badAnswerTraits
        self.score = score
    }
}

// MARK: - 9-field bundle

/// Typed Codable bundle of all 9 byproducts produced from
/// one LLM call per user vision §19。
public struct BASLLMExtractionByproducts:
    Codable, Equatable, Sendable
{
    /// 1. The user-facing answer (free-form natural language)。
    public let finalAnswer: String

    /// 2. Optional structured conclusion (e.g. JSON / decision
    /// label) extracted by the parser。Nil when the policy
    /// doesn't extract structure。
    public let structuredConclusion: String?

    /// 3. Suggested memory updates (host's memory writer
    /// decides whether to persist)。
    public let memoryUpdates: [BASMemoryUpdateCandidate]

    /// 4. Suggested follow-up tasks (host's task system
    /// decides whether to schedule)。
    public let taskCandidates: [BASTaskCandidate]

    /// 5. Risk flags surfaced by the LLM (e.g. "scope_creep" /
    /// "hallucination_risk")。
    public let riskFlags: [String]

    /// 6. Confidence scores keyed by axis (e.g.
    /// "factual" / "strategic" / "implementation"),values
    /// in [0, 1]。
    public let confidenceScores: [String: Double]

    /// 7. Counter-arguments / weaknesses the LLM (or its
    /// reviewer) found。
    public let counterArguments: [String]

    /// 8. Eval-case candidates this turn produced (for
    /// future regression test seeding)。
    public let evalCases: [BASEvalCaseCandidate]

    /// 9. Training-example candidates (for future Mamba /
    /// ChengluMemory pre-training corpus per M917 contract)。
    public let trainingExamples:
        [BASTrainingExampleCandidate]

    /// Wall-clock timestamp at extraction time (ms since
    /// UNIX epoch)。Caller-supplied for replay determinism。
    public let extractedAtMs: Int64

    public init(
        finalAnswer: String,
        structuredConclusion: String? = nil,
        memoryUpdates: [BASMemoryUpdateCandidate] = [],
        taskCandidates: [BASTaskCandidate] = [],
        riskFlags: [String] = [],
        confidenceScores: [String: Double] = [:],
        counterArguments: [String] = [],
        evalCases: [BASEvalCaseCandidate] = [],
        trainingExamples: [BASTrainingExampleCandidate] = [],
        extractedAtMs: Int64
    ) {
        // M940 audit fix:bulk NaN/Inf + range guard on
        // confidenceScores values (parser policies that
        // pipe raw LLM JSON could leak NaN otherwise)。
        for (_, value) in confidenceScores {
            precondition(value.isFinite,
                "confidenceScores value must be finite")
            precondition(value >= 0 && value <= 1,
                "confidenceScores value must be in [0, 1]")
        }
        self.finalAnswer = finalAnswer
        self.structuredConclusion = structuredConclusion
        self.memoryUpdates = memoryUpdates
        self.taskCandidates = taskCandidates
        self.riskFlags = riskFlags
        self.confidenceScores = confidenceScores
        self.counterArguments = counterArguments
        self.evalCases = evalCases
        self.trainingExamples = trainingExamples
        self.extractedAtMs = extractedAtMs
    }

    /// True iff the bundle has only `finalAnswer` populated
    /// (other 8 fields empty)。Useful for hosts that want to
    /// detect "default text-only extraction" vs. richly-parsed
    /// bundles。
    public var isTextOnly: Bool {
        structuredConclusion == nil
            && memoryUpdates.isEmpty
            && taskCandidates.isEmpty
            && riskFlags.isEmpty
            && confidenceScores.isEmpty
            && counterArguments.isEmpty
            && evalCases.isEmpty
            && trainingExamples.isEmpty
    }
}
