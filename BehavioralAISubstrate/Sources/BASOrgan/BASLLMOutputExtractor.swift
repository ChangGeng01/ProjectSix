// MARK: - BASLLMOutputExtractor — chapter 四百一 / M931
//
// Phase A step 4 of the LLM Extraction Engine MVP per user
// vision §18: pure function converting `BASOrganDraft` +
// `BASLLMTaskPackage` → `BASLLMExtractionByproducts`(M930
// 9-field bundle)。
//
// ## Why a host-supplied parser policy
//
// Different LLM adapters return tool calls + structured
// output in different shapes:
//   - OpenAI cloud:JSON tool-call objects in the response
//   - Anthropic Claude:XML-tagged blocks
//   - AFM iOS 26:typed Generable
//   - M920 mock:`"TOOL_CALL:<name>:<json>"` text marker
//
// Pinning a single parser would couple the substrate to one
// vendor。Same substrate-doctrine choice as M915 planner:
// expose the EXTRACTION SHAPE,delegate the PARSING to a
// typed Sendable closure。Hosts implement per their adapter。
//
// ## Default policy
//
// `defaultPolicy` populates ONLY `finalAnswer = draft.body`
// + `extractedAtMs`。All other 8 byproducts are empty。This
// matches "text-only extraction" — what hosts get out of the
// box without a vendor-specific parser。Hosts opt in to
// structured parsing by injecting their own policy。
//
// ## Doctrine pins held
//
// - chapter 二百一一 single-source-of-truth — ONE extractor,
//   vendor-agnostic via injected policy
// - chapter 三百九二 (M892) replay-determinism — same draft
//   + same package + same policy + same `extractedAtMs` →
//   byte-identical byproducts
// - 不变量 #1/#2/#3 — extraction is observation
// - 红线 7 hint-only — byproducts are HINTS
// - ADR-014 OPT-IN — host injects policy or accepts default

import Foundation

// MARK: - Parser policy

/// Typed Sendable closure that hosts implement to PARSE one
/// `BASOrganDraft` into the 9-field byproducts bundle。
/// Default-arg-free because parsers are vendor-specific (the
/// substrate doesn't prescribe a universal one)。
///
/// Closure signature receives the draft + the task package
/// that produced it (so the parser can correlate request
/// state with the response,e.g. echoing taskID into eval
/// cases) + the extraction timestamp (caller-supplied for
/// replay determinism)。
public typealias BASLLMOutputParserPolicy =
    @Sendable (
        BASOrganDraft,
        BASLLMTaskPackage,
        Int64  // extractedAtMs
    ) -> BASLLMExtractionByproducts

// MARK: - Extractor namespace

public enum BASLLMOutputExtractor {

    /// Default policy:populate only `finalAnswer = draft.body`
    /// and `extractedAtMs`。All other 8 byproducts empty。
    /// Hosts that don't inject a vendor-specific parser get
    /// text-only extraction by default。
    public static let defaultPolicy:
        BASLLMOutputParserPolicy =
    { draft, _, extractedAtMs in
        BASLLMExtractionByproducts(
            finalAnswer: draft.body,
            extractedAtMs: extractedAtMs)
    }

    /// Pure entry point。Caller supplies the draft + the
    /// task package + the extraction timestamp + an optional
    /// custom policy。Returns the typed 9-field bundle。
    public static func extract(
        draft: BASOrganDraft,
        taskPackage: BASLLMTaskPackage,
        extractedAtMs: Int64,
        policy: BASLLMOutputParserPolicy = defaultPolicy
    ) -> BASLLMExtractionByproducts {
        policy(draft, taskPackage, extractedAtMs)
    }
}
