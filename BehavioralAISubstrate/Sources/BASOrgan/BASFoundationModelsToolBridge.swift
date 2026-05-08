// MARK: - BASFoundationModelsToolBridge — chapter 四百 / M916
//
// G6 收尾 substrate-side typed surface for the FoundationModels
// (iOS 26+) `Tool` protocol bridge。Pre-M916 the AFM organ
// adapter dropped tools[] silently with M870's audit-trace
// (`#afm-tools-dropped-no-sdk-bridge`),and there was NO typed
// place for future SDK-bridge work to slot in。Post-M916 the
// strategy taxonomy + audit-mode pin live here as a public
// substrate primitive,so the moment iOS 26's `Tool` protocol
// stabilizes,the bridge wire is a concrete swap-in,not a
// design exercise。
//
// ## Why this is hard (the type-system gap)
//
// The iOS 26 `FoundationModels.Tool` protocol requires a
// COMPILE-TIME associated `Arguments: Generable` type per
// conformer:
//
//   protocol Tool {
//       associatedtype Arguments: Generable
//       func call(arguments: Arguments) async throws -> ToolOutput
//   }
//
// The substrate's `BASTool` carries RUNTIME parameters
// (`[BASToolParameter]`)。These don't compose without code
// generation:there's no way to instantiate a single
// "generic FoundationModels.Tool conformer" that takes
// `BASTool.parameters` at runtime。Two strategies exist:
//
//   1. **runtimeSchema** (cloud-style) — pass JSON Schema to
//      the LLM,parse JSON tool-call response。Works TODAY for
//      `BASChatCompletionsOrganAdapter` + Anthropic / OpenAI
//      cloud APIs。No iOS 26 SDK dependency。
//
//   2. **compiledGenerable** (AFM iOS 26 native) — generate
//      one `FoundationModels.Tool` conformer per BASTool at
//      compile time (via macro / codegen)。Hosts declare tools
//      in source,not at runtime。Future work — needs SDK
//      stabilization + macro infrastructure decision。
//
//   3. **audit** (M870 pre-bridge state) — drop tools[] at
//      the SDK call site,emit typed audit trace
//      `#afm-tools-dropped-no-sdk-bridge` so observers can
//      detect the gap。Substrate-class observation,never
//      silent。Used by AppleFoundationOrganAdapter today。
//
// ## What this ships (M916)
//
//   - `BASFoundationModelsToolBridgeStrategy` typed enum
//     naming the 3 strategies above
//   - `BASFoundationModelsToolBridgeStatus` typed enum naming
//     the bridge's per-call resolution:
//       `.audited(traceID:)` (no bridge,M870 audit trace)
//       `.bridgedRuntimeSchema(toolCount:)` (cloud-style)
//       `.bridgedCompiledGenerable(toolCount:)` (future AFM)
//   - `BASFoundationModelsToolBridge` namespace with the
//     `resolve(forStrategy:tools:)` typed factory that returns
//     a status describing what the bridge will do for a
//     given tools[] array
//   - `auditTraceSuffix` constant pinning M870's exact
//     trace-id suffix for downstream parsers
//
// ## What this does NOT ship
//
//   - The actual SDK Tool conformer (deferred until iOS 26
//     `Tool` protocol stabilizes + we make the macro
//     decision)
//   - Tool-call response parsing for cloud adapters (already
//     lives in `BASChatCompletionsOrganAdapter`)
//   - Device exercise — the substrate primitives are pure
//     value-types,no I/O
//
// ## Doctrine pins held
//
// - 不变量 #1 / #2 / #3 全保 — bridge is observation-class:
//   resolves a status,does NOT mutate permits or commit
//   token
// - 红线 7 hint-only — bridge status is a HINT to the host's
//   observability stack,never a permit gate
// - chapter 二百一一 single-source-of-truth — ONE typed
//   strategy taxonomy for AFM tool bridging
// - chapter 一百八十五 anti-magic-number — audit suffix
//   string is a typed constant,grep-able + stable
// - ADR-014 OPT-IN → PROD — bridge stays in `.audit` mode
//   until host explicitly opts into a different strategy
// - ADR-016 (M872) substrate completion doctrine — G6's
//   `substrateClosedSDKBridgePending` status now points to
//   THIS file as the typed surface where the bridge lands

import Foundation
import BASRuntimeCore

// MARK: - Strategy

/// Typed enum naming the three strategies for bridging
/// `BASTool` runtime values to the LLM's tool-calling API。
public enum BASFoundationModelsToolBridgeStrategy:
    String, Sendable, Equatable, Hashable, CaseIterable,
    Codable
{
    /// Pass tool definitions to the LLM as JSON Schema in the
    /// prompt + parse the LLM's JSON tool-call response。Works
    /// TODAY with cloud adapters (OpenAI / Anthropic / generic
    /// HTTP function-calling)。Does NOT depend on iOS 26 SDK。
    case runtimeSchema = "runtimeSchema"

    /// Compile-time `FoundationModels.Tool` conformers per
    /// BASTool。Hosts declare tools in Swift source。Future
    /// work — needs SDK stabilization。Currently UNUSED;the
    /// taxonomy is exposed so future code has a typed slot。
    case compiledGenerable = "compiledGenerable"

    /// Drop tools[] at the SDK call site,emit M870 audit
    /// trace。Pre-bridge default for AppleFoundationOrganAdapter
    /// — substrate-class observation,never silent。
    case audit = "audit"
}

// MARK: - Status

/// Typed result of resolving the bridge for a specific
/// `BASOrganRequest`。Hosts emit this in observability for
/// later analysis (e.g. detecting that a session ran with
/// tools dropped before the SDK bridge activated)。
public enum BASFoundationModelsToolBridgeStatus:
    Sendable, Equatable, Hashable
{
    /// Bridge dropped tools[],M870 audit trace emitted。
    /// `traceID` is the full trace ID with the audit suffix
    /// appended,for grep correlation。
    case audited(traceID: String)

    /// Bridge resolved tools[] via runtime JSON Schema (cloud
    /// adapters)。`toolCount` is the number of tools attached
    /// to the request。
    case bridgedRuntimeSchema(toolCount: Int)

    /// Bridge resolved tools[] via compile-time Generable
    /// conformers (future AFM iOS 26 path)。Currently never
    /// emitted — primitive shipped for forward-compat。
    case bridgedCompiledGenerable(toolCount: Int)

    /// True iff the bridge actually attached tools[] to the
    /// LLM call (vs. M870 audit-mode drop)。
    public var didBridgeTools: Bool {
        switch self {
        case .audited:
            return false
        case .bridgedRuntimeSchema, .bridgedCompiledGenerable:
            return true
        }
    }
}

// MARK: - Bridge

/// Substrate-side typed namespace for resolving
/// `BASFoundationModelsToolBridgeStatus` per request。Keeps
/// the M870 audit-trace string in one place + provides the
/// typed factory for future bridge wires。
public enum BASFoundationModelsToolBridge {

    /// chapter 三百八三 / M870 audit-trace suffix appended to
    /// the trace ID when the AFM adapter drops tools[]。Pinned
    /// here as a public substrate constant so:
    ///   - downstream parsers can grep for this exact string
    ///     without depending on the private adapter file
    ///   - future code that introduces additional audit modes
    ///     extends this taxonomy explicitly,not inline
    public static let auditTraceSuffix: String =
        "#afm-tools-dropped-no-sdk-bridge"

    /// Resolve the bridge status for a given strategy + tool
    /// list + base trace ID。Pure function — caller composes
    /// with their adapter's I/O pipeline。
    ///
    /// - Parameters:
    ///   - strategy: caller's chosen bridge strategy
    ///   - tools: the request's tools[] array (may be empty)
    ///   - baseTraceID: the adapter's trace ID before any
    ///     audit suffix is applied
    /// - Returns: typed status describing what the bridge
    ///   would do
    public static func resolve(
        strategy: BASFoundationModelsToolBridgeStrategy,
        tools: [BASTool],
        baseTraceID: String
    ) -> BASFoundationModelsToolBridgeStatus {
        // Empty tools[] always resolves as audited with the
        // BASE trace ID (no audit suffix needed — there's
        // nothing to drop)。
        if tools.isEmpty {
            return .audited(traceID: baseTraceID)
        }
        switch strategy {
        case .audit:
            return .audited(
                traceID: baseTraceID + auditTraceSuffix)
        case .runtimeSchema:
            return .bridgedRuntimeSchema(
                toolCount: tools.count)
        case .compiledGenerable:
            return .bridgedCompiledGenerable(
                toolCount: tools.count)
        }
    }

    /// Convenience:detect whether a trace ID was produced by
    /// the audit-mode bridge by checking for the M870 suffix。
    /// Useful for downstream observability stacks parsing trace
    /// IDs from event logs。
    public static func isAuditedTraceID(
        _ traceID: String
    ) -> Bool {
        traceID.hasSuffix(auditTraceSuffix)
    }
}
