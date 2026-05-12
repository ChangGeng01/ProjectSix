// MARK: - BASConstitutionEnforcer — chapter 三百五六 / M843
//
// Phase P1 G3 第一刀: pure-function 3-layer constitution gate
// helpers。Closes the FULL three-layer scope of G3 from chapter
// 三百五三 / M840 roadmap (user-confirmed full scope on 2026-05-08
// vs minimal hardNoGo-only)。
//
// ## What this is
//
// **Pure-function helpers** that consume a `BASBoundaryVeil` (the
// constitutional boundary set already typed in
// `HostConstitutionCore.swift`) + an input value (text / body /
// memory candidate / tool name) and return a typed match result。
//
// **This is NOT**:
//   - The runtime gate itself (that lives in
//     `EBrainRuntimeCoordinator+Permit.swift` for L1, the post-LLM
//     observer path for L2, and `EBrainHostRuntime+MemoryService.
//     retrieve()` for L3 — companion modifications in M843)
//   - A decision-maker — these helpers return MATCH/NO-MATCH
//     observations; the caller (which IS the gate) decides what
//     to do with the match (route .skipBlock / escalate
//     .draftOnly / drop candidate / etc.)
//
// ## Three layers
//
//   L1 — `evaluateInputAgainstHardNoGo(input:veil:)` — returns
//        the matched pattern (if any) for routing to .skipBlock
//        permit. Used pre-LLM by the substrate permit gate.
//   L2 — `evaluateBodyAgainstSoftCaution(body:veil:)` — returns
//        the matched pattern (if any) for escalating to .draftOnly
//        permit. Used post-LLM before commit。
//   L3 — `filterMemoryDomain(_:against:)` /
//        `isToolDomainRestricted(_:against:)` — returns whether
//        a memory atom domain or tool name is blocked by
//        restrictedMemoryDomains[] / restrictedToolDomains[]。
//
// ## Match semantics
//
// All matchers use **case-insensitive substring containment**。
// The boundary veil entries are user-typed strings or admin-
// configured boundary patterns;they are NOT regex (per
// `BASBoundaryVeil.hardNoGo: [String]` shape — no regex parser
// in BASMemory module)。
//
// **Performance budget** (M843 chapter 三百五六 doctrine pin):
// each gate is sync regex/keyword match, ≤ 1ms per turn even at
// 100-entry boundary lists。Embedding-based similarity check (vs
// boundaryVeil entries) deferred to P1 once G4 vector RAG ships。
//
// ## Doctrine pins held
//
//   - 不变量 #1 / #2 / #3 全保 — enforcer is pure observation +
//     recommendation;substrate decisions made by L11 permit gate
//     using these recommendations as INPUT
//   - 不变量 #2 specifically — constitution feeds the gate, NEVER
//     bypasses it。If hardNoGo matches,enforcer returns the
//     match;permit gate consumes that to issue .skipBlock。
//     Constitution is INPUT to L11/L14, not a separate gate。
//   - 红线 7 hint-only when match returned;caller decides action
//   - 单提交口 (L11/L14) 不变 — single permit gate,enforcer feeds
//     it
//   - chapter 二百一一 single-source-of-truth — ONE enforcer
//     module across all 3 layers
//   - chapter 一百八十五 anti-magic-number — match thresholds +
//     reason code prefixes named typed constants
//   - ADR-014 OPT-IN → PROD — when host doesn't pass a
//     constitution,enforcer returns no-match (zero behavior
//     change for hosts pre-M843)

import Foundation
import BASRuntimeCore

// MARK: - Reason code prefix

/// Canonical reason-code prefix for constitution-driven gate
/// decisions。Mirrors existing `RiskService` constitution
/// reason-code idiom (chapter 一百八十五 anti-magic-number)。
public enum BASConstitutionReasonCode {
    public static let prefix: String = "constitution"

    /// Build a hardNoGo match reason code:
    /// `constitution.hardNoGo:<pattern>`
    public static func hardNoGo(pattern: String) -> String {
        "\(prefix).hardNoGo:\(pattern)"
    }

    /// Build a softCaution match reason code:
    /// `constitution.softCaution:<pattern>`
    public static func softCaution(pattern: String) -> String {
        "\(prefix).softCaution:\(pattern)"
    }

    /// Build a restrictedMemoryDomain reason code:
    /// `constitution.restrictedMemoryDomain:<pattern>`
    public static func restrictedMemoryDomain(
        pattern: String
    ) -> String {
        "\(prefix).restrictedMemoryDomain:\(pattern)"
    }

    /// Build a restrictedToolDomain reason code:
    /// `constitution.restrictedToolDomain:<pattern>`
    public static func restrictedToolDomain(
        pattern: String
    ) -> String {
        "\(prefix).restrictedToolDomain:\(pattern)"
    }
}

// MARK: - Match result

/// Typed result of a constitution boundary check。Caller (the
/// permit gate / post-LLM observer / memory filter) consumes
/// this to decide the next action。
public struct BASConstitutionMatch:
    Codable, Equatable, Sendable
{
    /// The constitutional pattern that matched (eg. an entry
    /// from `BASBoundaryVeil.hardNoGo`)。Empty string only when
    /// `isMatch == false`。
    public let pattern: String

    /// The substring / domain / tool name that triggered the
    /// match (caller-supplied input echoed back for audit)。
    public let matchedInput: String

    /// Convenience: true when the pattern is non-empty。
    public var isMatch: Bool { !pattern.isEmpty }

    public init(
        pattern: String,
        matchedInput: String
    ) {
        self.pattern = pattern
        self.matchedInput = matchedInput
    }

    /// No-match sentinel — used when no boundary entry matches。
    public static let none = BASConstitutionMatch(
        pattern: "", matchedInput: "")
}

// MARK: - Enforcer namespace

/// Pure-function constitution enforcement helpers。All methods
/// are deterministic and stateless — same input always produces
/// the same match result。
public enum BASConstitutionEnforcer {

    // MARK: - L1: hardNoGo (pre-LLM input gate)

    /// Check input string against `hardNoGo[]` patterns。Returns
    /// the FIRST matching pattern (case-insensitive substring),
    /// or `.none` if no entry matches。
    ///
    /// **Caller** (permit gate at L11):
    ///   - on match → route to `.skipBlock` permit + emit
    ///     `constitution.hardNoGo:<pattern>` reason code
    ///   - on no-match → continue normal substrate dispatch
    public static func evaluateInputAgainstHardNoGo(
        input: String,
        hardNoGo: [String]
    ) -> BASConstitutionMatch {
        firstMatchingPattern(
            input: input, patterns: hardNoGo)
    }

    // MARK: - L2: softCaution (post-LLM body gate)

    /// Check post-LLM response body against `softCaution[]`
    /// patterns。Returns the FIRST matching pattern,or `.none`
    /// if no entry matches。
    ///
    /// **Caller** (post-LLM observer / active verifier):
    ///   - on match → escalate to `.draftOnly` permit + emit
    ///     `constitution.softCaution:<pattern>` reason code,
    ///     output flagged for explicit user confirmation before
    ///     commit
    ///   - on no-match → continue normal commit
    public static func evaluateBodyAgainstSoftCaution(
        body: String,
        softCaution: [String]
    ) -> BASConstitutionMatch {
        firstMatchingPattern(
            input: body, patterns: softCaution)
    }

    // MARK: - L3: restrictedMemoryDomains (retrieval filter)

    /// Check whether the given memory atom's source domain is
    /// blocked by `restrictedMemoryDomains[]`。Returns the
    /// matched pattern,or `.none` if domain is allowed。
    ///
    /// **Match shape**: any boundary entry whose substring is
    /// contained in the candidate domain (case-insensitive)
    /// triggers the filter。
    ///
    /// **Caller** (`EBrainHostRuntime+MemoryService.retrieve()`):
    ///   - on match → drop the candidate from retrieval bundle +
    ///     emit `constitution.restrictedMemoryDomain:<pattern>`
    ///     reason code in retrievalTags
    ///   - on no-match → include the candidate
    public static func evaluateMemoryDomain(
        domain: String,
        restrictedMemoryDomains: [String]
    ) -> BASConstitutionMatch {
        firstMatchingPattern(
            input: domain,
            patterns: restrictedMemoryDomains)
    }

    /// Convenience: filter a sequence of (domain, payload) tuples
    /// by `restrictedMemoryDomains[]`,returning only the
    /// allowed payloads + a list of dropped domain patterns。
    public static func filterMemoryDomains<Payload>(
        _ entries: [(domain: String, payload: Payload)],
        restrictedMemoryDomains: [String]
    ) -> (allowed: [Payload], droppedReasonCodes: [String]) {
        guard !restrictedMemoryDomains.isEmpty else {
            return (entries.map { $0.payload }, [])
        }
        var allowed: [Payload] = []
        var dropped: [String] = []
        for entry in entries {
            let match = evaluateMemoryDomain(
                domain: entry.domain,
                restrictedMemoryDomains: restrictedMemoryDomains)
            if match.isMatch {
                dropped.append(
                    BASConstitutionReasonCode
                        .restrictedMemoryDomain(
                            pattern: match.pattern))
            } else {
                allowed.append(entry.payload)
            }
        }
        return (allowed, dropped)
    }

    // MARK: - L3: restrictedToolDomains (tool gate)

    /// Check whether the given tool name is blocked by
    /// `restrictedToolDomains[]`。Returns the matched pattern,
    /// or `.none` if tool is allowed。
    ///
    /// **Caller** (future P1 G6 AFM tool calling):
    ///   - on match → reject the tool invocation + emit
    ///     `constitution.restrictedToolDomain:<pattern>`
    ///   - on no-match → allow the tool call
    public static func evaluateToolDomain(
        toolName: String,
        restrictedToolDomains: [String]
    ) -> BASConstitutionMatch {
        firstMatchingPattern(
            input: toolName,
            patterns: restrictedToolDomains)
    }

    // MARK: - Shared matcher

    /// Return the first pattern in `patterns` that matches
    /// (case-insensitive substring) the input。Returns
    /// `BASConstitutionMatch.none` if no entry matches OR if
    /// patterns is empty。
    ///
    /// Empty pattern entries are skipped (defensive — no
    /// substring of any string equals empty,but we'd match
    /// every input which is wrong)。
    static func firstMatchingPattern(
        input: String,
        patterns: [String]
    ) -> BASConstitutionMatch {
        guard !patterns.isEmpty, !input.isEmpty else {
            return .none
        }
        let lowered = input.lowercased()
        for pattern in patterns {
            let trimmed = pattern.trimmingCharacters(
                in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            if lowered.contains(trimmed.lowercased()) {
                return BASConstitutionMatch(
                    pattern: trimmed,
                    matchedInput: input)
            }
        }
        return .none
    }
}
