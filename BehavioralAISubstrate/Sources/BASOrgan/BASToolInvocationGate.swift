// MARK: - BASToolInvocationGate — chapter 三百六六 / M853
//
// Phase P1 G6 part 3: typed tool-invocation gate that composes
// the M851 `BASToolInvocation` type with the chapter 三百五六 / M843
// `BASConstitutionEnforcer.evaluateToolDomain` matching doctrine。
//
// Closes the "L3 restrictedToolDomains" wire-up promised in M843
// commit message:
//
// > L3 (restrictedDomains): tool-calling gate — when G6 (AFM tool
// >   calling) lands in P1, restrictedToolDomains[] +
// >   restrictedMemoryDomains[] block tool invocations matching
// >   domain.
//
// G6 part 1 (M851) shipped `BASTool` + `BASToolInvocation` typed
// primitives;G6 part 2 (M852) wired tools[] into BASOrganRequest;
// this commit (M853) ships the constitution-driven gate that
// rejects invocations whose toolName matches any
// `restrictedToolDomains[]` boundary entry。
//
// ## Module-boundary design
//
// The gate helper lives in BASOrgan (where `BASToolInvocation`
// lives) and takes `[String] restrictedToolDomains` directly,NOT
// a `BASBoundaryVeil` (which lives in BASMemory)。This keeps
// BASOrgan independent of BASMemory and lets ANY caller
// (BASHostKit / SampleHost / future agentic-flow) compose by
// projecting from their constitution source。
//
// ## Doctrine pins held
//
//   - 不变量 #1 / #2 / #3 全保 — gate is a pure decision helper,
//     no permit/verdict mutation,no side effects
//   - 红线 7 hint-only — gate decision is INPUT to the caller's
//     tool-execution path;substrate gate at L11 still decides
//     whether to commit the LLM's tool-call response
//   - 单提交口 (L11/L14) 不变 — tool gate is a separate primitive
//     from permit synthesis;hosts compose
//   - chapter 二百一一 single-source-of-truth — ONE tool
//     invocation gate;BASMemory side has the matching helper
//     `BASConstitutionEnforcer.evaluateToolDomain` for
//     module-internal use,this gate adds the typed decision
//     wrapper for tool-flow consumers
//   - chapter 一百八十五 anti-magic-number — reason code prefix
//     mirror BASConstitutionEnforcer's "constitution.*" prefix
//     (cross-module convention)
//   - ADR-014 OPT-IN → PROD — empty restrictedToolDomains[] =
//     pass-through,zero behavior change for unwired hosts

import Foundation

// MARK: - Decision

/// Typed gate decision returned by `BASToolInvocationGate.evaluate(...)`。
public enum BASToolInvocationDecision: Equatable, Sendable {
    /// Tool may execute。Caller proceeds with handler dispatch。
    case allow

    /// Tool execution is REJECTED by constitution boundary。
    /// Caller MUST NOT execute the handler。`reasonCodes`
    /// carries the matched pattern + audit anchor for emission
    /// to the host's audit ledger。
    case reject(reasonCodes: [String])
}

// MARK: - Gate namespace

/// Pure-function gate that consumes a `BASToolInvocation` + a
/// list of `restrictedToolDomains` patterns and produces a typed
/// decision (`.allow` or `.reject`)。
public enum BASToolInvocationGate {

    /// Reason code prefix。Mirrors the "constitution.*" prefix
    /// from BASConstitutionEnforcer for grep stability across
    /// module boundaries (chapter 二百一一 single-source-of-truth)。
    public static let reasonCodePrefix: String = "constitution"

    /// Audit anchor reason code emitted on every rejection。
    /// Audit walkers grep this to count gate firings。
    public static let rejectionAnchorCode: String =
        "constitution.restrictedToolDomain.match"

    /// Evaluate a tool invocation against a restricted-tool-
    /// domain pattern list。
    ///
    /// **Match shape**: case-insensitive substring containment of
    /// any boundary entry in the invocation's `toolName`。Whitespace-
    /// only patterns are skipped (defensive)。Mirrors
    /// `BASConstitutionEnforcer.evaluateToolDomain` doctrine
    /// (BASMemory module) — see M843 chapter 三百五六。
    ///
    /// - Parameters:
    ///   - invocation: the tool invocation to gate
    ///   - restrictedToolDomains: boundary entries from the host's
    ///     `BASBoundaryVeil.restrictedToolDomains`。Empty array =
    ///     no restrictions,returns `.allow` (ADR-014 OPT-IN)
    /// - Returns: `.allow` if no pattern matches the toolName;
    ///   `.reject(reasonCodes:)` with the matched pattern,the
    ///   anchor code,and the toolName for audit context
    public static func evaluate(
        invocation: BASToolInvocation,
        restrictedToolDomains: [String]
    ) -> BASToolInvocationDecision {
        guard !restrictedToolDomains.isEmpty,
              !invocation.toolName.isEmpty
        else {
            return .allow
        }
        let lowered = invocation.toolName.lowercased()
        for pattern in restrictedToolDomains {
            let trimmed = pattern.trimmingCharacters(
                in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            if lowered.contains(trimmed.lowercased()) {
                let codes: [String] = [
                    "\(reasonCodePrefix)" +
                    ".restrictedToolDomain:\(trimmed)",
                    rejectionAnchorCode,
                    "tool.invocation:\(invocation.toolName)",
                    "tool.invocationID:\(invocation.invocationID)"
                ]
                return .reject(reasonCodes: codes)
            }
        }
        return .allow
    }

    /// Convenience: evaluate a batch of invocations and split
    /// into (allowed, rejected)。Useful when an LLM emits multiple
    /// tool calls in a single response (Apple `LanguageModelSession`
    /// supports parallel tool invocations)。
    public static func partition(
        invocations: [BASToolInvocation],
        restrictedToolDomains: [String]
    ) -> (
        allowed: [BASToolInvocation],
        rejected: [(invocation: BASToolInvocation,
                    reasonCodes: [String])]
    ) {
        var allowed: [BASToolInvocation] = []
        var rejected: [(BASToolInvocation, [String])] = []
        for invocation in invocations {
            switch evaluate(
                invocation: invocation,
                restrictedToolDomains: restrictedToolDomains)
            {
            case .allow:
                allowed.append(invocation)
            case .reject(let codes):
                rejected.append((invocation, codes))
            }
        }
        return (allowed, rejected)
    }
}
