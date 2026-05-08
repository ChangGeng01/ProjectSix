// MARK: - BASLLMPromptCompiler — chapter 四百一 / M929
//
// Phase A step 2 of the LLM Extraction Engine MVP per user
// vision §18: pure-function compiler converting raw user
// input + neutral-typed context bundle into M928
// `BASLLMTaskPackage`。Vendor-agnostic — hosts populate the
// `BASLLMCompilerContext` from whatever domain types they
// have (BASDecomposeFrame from L7, BASRAGResult from M850,
// BASRiskCard from L11, BASHostConstitution from L4) but
// the compiler ITSELF only sees neutral strings/lists,
// keeping the BASOrgan target dependency graph minimal。
//
// ## Why neutral-typed context vs. direct domain-frame consumption
//
// Pre-M929 design considered direct consumption of
// `BASDecomposeFrame` / `BASRAGResult` / `BASRiskCard` /
// `BASHostConstitution`。But:
//   - Those types live in BASOrchestration / BASMemory /
//     BASPolicy。BASOrgan would need to import 3 modules,
//     bloating the dep graph for a primitive that only
//     reads a handful of strings from each。
//   - chapter 二百一一 single-source-of-truth doctrine
//     prefers VENDOR-AGNOSTIC compilation surface — different
//     hosts may not even HAVE a BASDecomposeFrame (e.g. a
//     bare CLI host that just feeds prompt + memory).
//   - Tests stay simple — no need to construct full
//     orchestration frames for compiler tests.
//
// Post-M929 design:
//   - `BASLLMCompilerContext` typed Codable bundle is the
//     sole compiler input
//   - hosts construct it from their domain types (one-liner
//     factory pattern they already use)
//   - compiler is pure-function over the neutral struct
//
// ## Doctrine pins held
//
// - chapter 二百一一 single-source-of-truth — ONE compiler,
//   neutral-typed input, all hosts route through it
// - chapter 一百八十五 anti-magic-number — defaults named
//   typed constants
// - chapter 三百九二 (M892) replay-determinism — same context
//   + same compileTimestamp → identical task package
// - 不变量 #1/#2/#3 — compilation is observation,no permit
//   mutation
// - ADR-014 OPT-IN — caller invokes;substrate doesn't
//   auto-compile

import Foundation
import BASRuntimeCore

// MARK: - Compiler context

/// Typed Codable bundle of neutral-typed inputs the compiler
/// reads。Hosts construct from their domain types。
public struct BASLLMCompilerContext:
    Codable, Equatable, Sendable
{
    /// Optional intent label extracted by the host (e.g. from
    /// L7 decompose frame's intent vector or its own
    /// classifier)。Compiler falls back to
    /// `BASLLMTaskPackageDefaults.intent` when nil。
    public let intentHint: String?

    /// Optional goal extracted by the host (e.g. from
    /// constitution's goalSpine.priorityOrder.first)。Compiler
    /// falls back to empty string when nil。
    public let goalHint: String?

    /// Caller-supplied constraints (e.g. constitution
    /// boundaryVeil hardNoGo + softCaution + confirmRequired)。
    /// Compiler dedups + preserves order。
    public let constraints: [String]

    /// Caller-supplied formatted memory bullets。Convention:
    /// short top-K summaries (e.g. M850 `BASRAGResult.atoms`
    /// mapped to `summary` strings)。Compiler passes through
    /// to `BASLLMTaskPackage.contextBlobs`。
    public let memoryBullets: [String]

    /// Caller-supplied risk flags (e.g. L11 BASRiskCard
    /// factors)。Compiler dedups + preserves order。
    public let riskFlags: [String]

    public init(
        intentHint: String? = nil,
        goalHint: String? = nil,
        constraints: [String] = [],
        memoryBullets: [String] = [],
        riskFlags: [String] = []
    ) {
        self.intentHint = intentHint
        self.goalHint = goalHint
        self.constraints = constraints
        self.memoryBullets = memoryBullets
        self.riskFlags = riskFlags
    }

    /// Convenience:empty context for hosts that haven't yet
    /// wired any of L7/L8/L11/L4。
    public static let empty = BASLLMCompilerContext()
}

// MARK: - Compiler

/// Pure-function struct converting `BASLLMRawInput` +
/// `BASLLMCompilerContext` → `BASLLMTaskPackage`。Hosts hold
/// one of these per session OR construct on demand。
public struct BASLLMPromptCompiler: Sendable {

    /// chapter 一百八十五 anti-magic-number — top-K cap on
    /// memory bullets carried into the package。Default 5
    /// matches typical RAG K and fits within typical LLM
    /// context budgets。
    public static let defaultMemoryBulletCap: Int = 5

    /// Cap on the number of memory bullets carried into the
    /// task package。Hosts override per host config。
    public let memoryBulletCap: Int

    public init(
        memoryBulletCap: Int =
            BASLLMPromptCompiler.defaultMemoryBulletCap
    ) {
        precondition(memoryBulletCap > 0,
            "memoryBulletCap must be > 0")
        self.memoryBulletCap = memoryBulletCap
    }

    /// Compile a task package from raw input + context。Pure
    /// function。Replay-deterministic given the same
    /// `compiledAtMs`。
    public func compile(
        rawInput: BASLLMRawInput,
        context: BASLLMCompilerContext = .empty,
        compiledAtMs: Int64,
        toolHints: [BASTool] = [],
        outputSchema: BASGuidedGenerationSchema? = nil,
        maxIterations: Int =
            BASLLMTaskPackageDefaults.maxIterations
    ) -> BASLLMTaskPackage {
        // Intent: caller hint > default
        let intent = context.intentHint
            .flatMap { $0.isEmpty ? nil : $0 }
            ?? BASLLMTaskPackageDefaults.intent

        // Goal: caller hint > empty
        let goal = context.goalHint ?? ""

        // Constraints: dedup + preserve order
        let dedupedConstraints =
            Self.dedupPreservingOrder(context.constraints)

        // Memory bullets: cap top-K
        let cappedBullets = Array(
            context.memoryBullets.prefix(memoryBulletCap))

        // Risk flags: dedup + preserve order
        let dedupedRiskFlags =
            Self.dedupPreservingOrder(context.riskFlags)

        // Deterministic taskID from raw input + timestamp
        let taskID = BASLLMTaskPackage.deterministicTaskID(
            for: rawInput,
            compiledAtMs: compiledAtMs)

        return BASLLMTaskPackage(
            taskID: taskID,
            originSessionID: rawInput.sessionID,
            compiledAtMs: compiledAtMs,
            intent: intent,
            goal: goal,
            constraints: dedupedConstraints,
            contextBlobs: cappedBullets,
            riskFlags: dedupedRiskFlags,
            outputSchema: outputSchema,
            toolHints: toolHints,
            maxIterations: maxIterations)
    }

    /// Pure helper:dedupe a string list while preserving
    /// the input's first-occurrence order。
    private static func dedupPreservingOrder(
        _ items: [String]
    ) -> [String] {
        var seen: Set<String> = []
        var result: [String] = []
        result.reserveCapacity(items.count)
        for item in items {
            let trimmed = item.trimmingCharacters(
                in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            if seen.insert(trimmed).inserted {
                result.append(trimmed)
            }
        }
        return result
    }
}
