// MARK: - BASLLMTaskPackage — chapter 四百一 / M928
//
// Phase A step 1 of the LLM Extraction Engine MVP per user
// vision §18 ("LLM Extraction MVP"): typed task package
// representing a "compiled task" for the LLM。Output of M929
// `BASLLMPromptCompiler`,input to M932 `BASLLMExtractionEngine`。
//
// ## Why this exists
//
// User vision pin: "LLM 不直接统治系统;14层电子脑统治 LLM。"
// The substrate must compile raw user input into a STRUCTURED
// task package BEFORE the LLM sees it。Pre-M928 every host
// concatenated their own prompt strings inline。Post-M928 the
// substrate ships ONE typed package shape that:
//   - hosts populate from L7 decompose frame + L8 memory
//     recall + L11 risk frame + host constitution
//   - LLM adapters consume uniformly
//   - M898 replay runner can re-execute (deterministic)
//   - M903 training-data exporter can capture (M917 contract)
//
// ## What this ships
//
//   - `BASLLMRawInput` typed Codable wrapper for raw user
//     input + session/surface/kind metadata
//   - `BASLLMTaskPackage` typed Codable struct with the 11
//     fields from the plan
//   - `BASLLMTaskPackage.deterministicTaskID(for:compiledAtMs:)`
//     pure factory producing replay-deterministic task IDs
//
// ## Doctrine pins held
//
// - 不变量 #1/#2/#3 — package is observation-class,no
//   permit/verdict mutation
// - 红线 7 hint-only — package is HINT to the LLM,gate at
//   L11 still decides on the LLM's response
// - chapter 二百一一 single-source-of-truth — ONE typed
//   package shape across all hosts/adapters/replay paths
// - chapter 一百八十五 anti-magic-number — defaults named
//   typed constants
// - chapter 三百九二 (M892) replay-determinism — taskID is
//   deterministic from (rawInput, compiledAtMs)
// - ADR-014 OPT-IN — engine uses package only when caller
//   constructs;no auto-creation

import Foundation
import BASRuntimeCore

// MARK: - Raw input wrapper

/// Typed Codable wrapper around the raw user query + session
/// metadata。Hosts construct this from their UI / API entry
/// points and pass to M929 prompt compiler。
public struct BASLLMRawInput:
    Codable, Equatable, Sendable, Hashable
{
    /// Natural-language user query。
    public let prompt: String

    /// Stable session ID this query belongs to。Engine appends
    /// audit events to the event log under this session。
    public let sessionID: String

    /// Host surface name (e.g. `"chat"` / `"voice"` /
    /// `"widget"`)。String not enum to stay vendor-agnostic
    /// (different hosts have different surfaces)。
    public let surface: String

    /// Host-specific request-kind tag (e.g.
    /// `"ask"` / `"plan"` / `"summarize"`)。Default
    /// `"ask"`。
    public let kind: String

    public init(
        prompt: String,
        sessionID: String,
        surface: String =
            BASLLMTaskPackageDefaults.surface,
        kind: String =
            BASLLMTaskPackageDefaults.kind
    ) {
        self.prompt = prompt
        self.sessionID = sessionID
        self.surface = surface
        self.kind = kind
    }
}

// MARK: - Task package

/// Typed Codable bundle representing a "compiled task" for
/// the LLM。Output of M929 `BASLLMPromptCompiler`,input to
/// M932 `BASLLMExtractionEngine`。
public struct BASLLMTaskPackage:
    Codable, Equatable, Sendable
{
    /// Stable unique ID for this task package。M892 replay
    /// determinism doctrine:same `(rawInput, compiledAtMs)`
    /// → same `taskID`,so replays produce identical packages。
    /// Use `deterministicTaskID(for:compiledAtMs:)` factory。
    public let taskID: String

    /// Session ID inherited from the originating raw input。
    public let originSessionID: String

    /// Wall-clock timestamp at compile time (ms since UNIX
    /// epoch)。Caller-supplied for replay determinism;
    /// `BASLLMPromptCompiler` accepts an explicit override。
    public let compiledAtMs: Int64

    /// Intent label extracted from L7 decompose frame's
    /// `intentVectors.first` if available,else
    /// `BASLLMTaskPackageDefaults.intent`。
    public let intent: String

    /// Goal extracted from `BASHostConstitution.goalSpine
    /// .priorityOrder.first`,else empty string。
    public let goal: String

    /// Constraints from constitution boundaryVeil + L11 risk
    /// card red lines (deduped, order-stable)。
    public let constraints: [String]

    /// Formatted memory-recall results。Top-K bullets pulled
    /// from M850 `BASRAGResult.atoms[]` if available。
    public let contextBlobs: [String]

    /// Risk flags surfaced from L11 BASRiskCard。
    public let riskFlags: [String]

    /// Optional structured-output schema (M851 typed)。When
    /// non-nil,the LLM adapter is asked to constrain output。
    public let outputSchema: BASGuidedGenerationSchema?

    /// Tool descriptors the LLM may invoke (M851 typed)。
    /// Empty array = plain-text-only generation。
    public let toolHints: [BASTool]

    /// M915 planner max-iteration cap when tools are present。
    /// Default `BASLLMTaskPackageDefaults.maxIterations` (10)。
    public let maxIterations: Int

    public init(
        taskID: String,
        originSessionID: String,
        compiledAtMs: Int64,
        intent: String,
        goal: String,
        constraints: [String] = [],
        contextBlobs: [String] = [],
        riskFlags: [String] = [],
        outputSchema: BASGuidedGenerationSchema? = nil,
        toolHints: [BASTool] = [],
        maxIterations: Int =
            BASLLMTaskPackageDefaults.maxIterations
    ) {
        precondition(maxIterations > 0,
            "maxIterations must be > 0")
        self.taskID = taskID
        self.originSessionID = originSessionID
        self.compiledAtMs = compiledAtMs
        self.intent = intent
        self.goal = goal
        self.constraints = constraints
        self.contextBlobs = contextBlobs
        self.riskFlags = riskFlags
        self.outputSchema = outputSchema
        self.toolHints = toolHints
        self.maxIterations = maxIterations
    }

    /// Pure deterministic factory:given the same `rawInput`
    /// + same `compiledAtMs`,produce the same `taskID`。
    /// Uses FNV-1a length-prefixed encoding (mirrors M907
    /// fix to M892 replay-determinism doctrine — no
    /// pipe-injection collisions)。
    public static func deterministicTaskID(
        for rawInput: BASLLMRawInput,
        compiledAtMs: Int64
    ) -> String {
        let combined =
            "\(rawInput.prompt.utf8.count):\(rawInput.prompt)" +
            "\(rawInput.sessionID.utf8.count):\(rawInput.sessionID)" +
            "\(rawInput.surface.utf8.count):\(rawInput.surface)" +
            "\(rawInput.kind.utf8.count):\(rawInput.kind)" +
            "\(compiledAtMs)"
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in combined.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x100000001b3
        }
        return "task-\(String(hash, radix: 16))"
    }
}

// MARK: - Defaults

/// chapter 一百八十五 anti-magic-number — typed defaults
/// extracted as a public namespace so hosts and tests
/// reference the canonical values。
public enum BASLLMTaskPackageDefaults {
    public static let surface: String = "chat"
    public static let kind: String = "ask"
    public static let intent: String = "ask"
    public static let maxIterations: Int = 10
}
