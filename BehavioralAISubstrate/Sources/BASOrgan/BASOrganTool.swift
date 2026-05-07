// MARK: - BASOrganTool — chapter 三百六四 / M851
//
// Phase P1 G6 part 1: typed primitives for tool calling + guided
// generation。Closes the typed-shape piece of G6 from M840
// Cognitive OS roadmap。
//
// ## Why this exists
//
// Per chapter 三百五三 / M840 audit:
// > AFM **no tool calling, no guided generation** — only plain text
//
// Apple's iOS 26 `LanguageModelSession` API supports tool calling +
// guided generation。M851 ships the typed substrate-side primitives
// that abstract Apple's specific API surface,so:
//   - Hosts describe tools in `BASTool` value types (Codable +
//     Sendable + Equatable)
//   - Adapters (AppleFoundationOrganAdapter / MLX / future) translate
//     the typed primitives to their respective LLM call formats
//   - The substrate remains LLM-vendor-agnostic
//
// ## What this ships (M851 第一刀)
//
//   - `BASToolParameterType` typed enum (string / integer / number /
//     boolean / array / object / any)
//   - `BASToolParameter` typed value (name / description / type /
//     required / allowedValues for enum-like)
//   - `BASTool` typed value (name / description / parameters[])
//   - `BASToolInvocation` typed value (toolName / arguments /
//     invocationID)
//   - `BASToolResult` typed value (invocationID / success /
//     payload / errorMessage)
//   - `BASGuidedGenerationSchema` typed value for structured
//     output (schema name + JSON-Schema fragment + strict flag)
//
// Companion files in the same chapter:
//   - M852 will extend `BASOrganRequest` to take `tools: [BASTool]`
//     + `outputSchema: BASGuidedGenerationSchema?` fields
//   - M853+ will wire the AppleFoundationOrganAdapter to Apple's
//     `LanguageModelSession` tool calling API
//
// ## Doctrine pins held
//
//   - 不变量 #1 / #2 / #3 全保 — tools are typed surface,no permit/
//     verdict mutation,no runtime weight feed
//   - 红线 7 hint-only — tool invocations + results are observation-
//     class until host explicitly executes them via a registered
//     handler;the substrate gate still decides whether to honor
//     a tool-call response
//   - 单提交口 (L11/L14) 不变 — tool execution is a separate
//     primitive from permit synthesis;hosts compose
//   - chapter 二百一一 single-source-of-truth — ONE typed tool
//     primitive set,N adapters consume them
//   - chapter 一百八十五 anti-magic-number — parameter types +
//     defaults named typed constants
//   - chapter 三百五六 (M843) constitution composition —
//     `restrictedToolDomains[]` from BASBoundaryVeil composes with
//     this typed `BASTool.name`,enforcer call-site (future M854)
//     filters disallowed tools at invocation time
//   - ADR-014 OPT-IN → PROD — primitives are opt-in;hosts that
//     don't construct `BASTool` values continue to call LLMs in
//     plain-text mode (zero behavior change)

import Foundation
import BASRuntimeCore

// MARK: - Parameter type

/// Typed enum covering JSON Schema's primitive type keywords。
/// Mirrors Apple `LanguageModelSession` tool-parameter type
/// surface + OpenAI-compatible function calling conventions for
/// MLX / cloud LLM adapters。
public enum BASToolParameterType: String, Codable, Equatable,
    Sendable, CaseIterable
{
    case string
    case integer
    case number    // floating-point (JSON Schema "number")
    case boolean
    case array
    case object
    /// Permissive type — adapter chooses representation。Used
    /// when caller can't pin a specific shape (eg. opaque
    /// passthrough payloads)。
    case any
}

// MARK: - Tool parameter

/// Typed parameter spec for a `BASTool`。Mirrors JSON Schema
/// property shape sufficient for current tool-call adapters
/// (AFM / OpenAI function calling style)。
///
/// **Design**: keep the shape small + Codable;richer JSON Schema
/// (anyOf / oneOf / nested objects) deferred to a v2 schema bump
/// when concrete adapters need them。
public struct BASToolParameter: Codable, Equatable, Sendable {
    public let name: String
    public let description: String
    public let type: BASToolParameterType
    public let required: Bool
    /// For enum-like parameters: list of permitted string values。
    /// Empty array = no enum constraint。Adapters translate to
    /// JSON Schema `enum` keyword when non-empty。
    public let allowedValues: [String]

    public init(
        name: String,
        description: String,
        type: BASToolParameterType,
        required: Bool = false,
        allowedValues: [String] = []
    ) {
        // Trim name + description at boundary (chapter 一百八十五
        // anti-magic-number defensive normalization)
        self.name = name.trimmingCharacters(
            in: .whitespacesAndNewlines)
        self.description = description.trimmingCharacters(
            in: .whitespacesAndNewlines)
        self.type = type
        self.required = required
        self.allowedValues = allowedValues
            .map { $0.trimmingCharacters(
                in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

// MARK: - Tool

/// Typed tool descriptor。Hosts construct one per registered tool;
/// pass an array on `BASOrganRequest` (M852)。
///
/// **Naming convention** (chapter 一百八十五 anti-magic-number):
///   - lower_snake_case names (eg. "search_memory",
///     "get_calendar_events")
///   - hierarchical via dot (eg. "memory.search",
///     "calendar.events.get") for `restrictedToolDomains[]`
///     pattern matching (chapter 三百五六 G3 L3 composition)
public struct BASTool: Codable, Equatable, Sendable {
    /// Unique tool identifier。Adapters use this as the function
    /// name on the LLM side。
    public let name: String

    /// Plain-text description for the LLM to decide invocation。
    /// Should explain WHEN to call the tool,not just what it
    /// does。
    public let description: String

    /// Ordered parameter spec list。Order matters for adapters
    /// that emit positional argument formats;most LLM tool-call
    /// APIs treat the list as a set keyed by parameter name。
    public let parameters: [BASToolParameter]

    public init(
        name: String,
        description: String,
        parameters: [BASToolParameter] = []
    ) {
        self.name = name.trimmingCharacters(
            in: .whitespacesAndNewlines)
        self.description = description.trimmingCharacters(
            in: .whitespacesAndNewlines)
        self.parameters = parameters
    }

    /// Convenience: parameter names that are required。Used by
    /// adapter validators to verify LLM-emitted invocations
    /// include all required args。
    public var requiredParameterNames: [String] {
        parameters.filter { $0.required }.map { $0.name }
    }
}

// MARK: - Tool invocation

/// Typed tool-call request emitted by the LLM。Adapters parse
/// the LLM's structured output + populate this value type;
/// hosts route to registered handlers。
public struct BASToolInvocation: Codable, Equatable, Sendable {
    /// Stable unique identifier for this invocation。Used to
    /// correlate with the matching `BASToolResult` after
    /// execution。
    public let invocationID: String

    /// Name of the tool to invoke。Caller validates against
    /// the registered `BASTool` set。
    public let toolName: String

    /// String-keyed argument map。Values are JSON-encoded
    /// strings (caller decodes per the `BASToolParameter.type`
    /// of each arg)。Simplest typed shape that survives Codable
    /// + Sendable + cross-adapter portability。
    public let arguments: [String: String]

    public init(
        invocationID: String,
        toolName: String,
        arguments: [String: String]
    ) {
        self.invocationID = invocationID.trimmingCharacters(
            in: .whitespacesAndNewlines)
        self.toolName = toolName.trimmingCharacters(
            in: .whitespacesAndNewlines)
        self.arguments = arguments
    }
}

// MARK: - Tool result

/// Typed result from executing a `BASToolInvocation`。Hosts
/// pass back to the LLM via the adapter's continuation API。
public struct BASToolResult: Codable, Equatable, Sendable {
    /// Matches the originating `BASToolInvocation.invocationID`。
    public let invocationID: String

    /// True if the tool executed successfully。
    public let success: Bool

    /// JSON-encoded result payload (or empty string on failure)。
    public let payload: String

    /// Diagnostic error message on failure。Empty on success。
    public let errorMessage: String

    public init(
        invocationID: String,
        success: Bool,
        payload: String,
        errorMessage: String = ""
    ) {
        self.invocationID = invocationID.trimmingCharacters(
            in: .whitespacesAndNewlines)
        self.success = success
        self.payload = payload
        self.errorMessage = errorMessage.trimmingCharacters(
            in: .whitespacesAndNewlines)
    }

    /// Convenience: success result with payload。
    public static func ok(
        invocationID: String, payload: String
    ) -> BASToolResult {
        BASToolResult(
            invocationID: invocationID,
            success: true,
            payload: payload)
    }

    /// Convenience: failure result with diagnostic message。
    public static func failure(
        invocationID: String, message: String
    ) -> BASToolResult {
        BASToolResult(
            invocationID: invocationID,
            success: false,
            payload: "",
            errorMessage: message)
    }
}

// MARK: - Guided generation schema

/// Typed JSON Schema fragment for guided / structured output。
/// Hosts attach to `BASOrganRequest` (M852) to constrain LLM
/// output to a specific shape。
///
/// **Design**: ship the JSON-Schema as a String payload (the
/// caller's responsibility to produce valid JSON Schema)。This
/// avoids re-inventing a Codable JSON Schema type system in
/// Swift。Adapters parse + translate to their LLM's expected
/// guided-generation API。
public struct BASGuidedGenerationSchema: Codable, Equatable,
    Sendable
{
    /// Stable schema name — used by adapters as the "function
    /// name" or "output schema name" on the LLM side。Should
    /// follow the same naming convention as `BASTool.name`
    /// (lower_snake_case)。
    public let schemaName: String

    /// JSON Schema fragment as a string。Caller produces valid
    /// JSON Schema;adapter validates at translation time。
    public let propertiesJSON: String

    /// If true,LLM output MUST conform exactly。If false,
    /// schema is a soft suggestion (LLM may produce close
    /// matches with extra fields)。AFM's iOS 26 guided
    /// generation uses `strict=true` for typed `Generable`
    /// outputs。
    public let strict: Bool

    public init(
        schemaName: String,
        propertiesJSON: String,
        strict: Bool = true
    ) {
        self.schemaName = schemaName.trimmingCharacters(
            in: .whitespacesAndNewlines)
        self.propertiesJSON = propertiesJSON
        self.strict = strict
    }
}
