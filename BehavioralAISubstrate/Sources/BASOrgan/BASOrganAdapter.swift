import Foundation
import BASRuntimeCore

/// L2/L3 neural-organ adapter contract.
///
/// ## Why this exists
///
/// The plan's §9.6 told the truth: "this block is the entire
/// complete-body only part Swift-only cannot fulfill all". Operator-
/// level ANE work isn't in scope for this repository. What *is* in
/// scope is the **adapter contract**: the interface the rest of the
/// system calls when it needs a neural organ to "draft", "score",
/// "evaluate", or "dream".
///
/// Concretely, `BASOrganAdapter` is the single protocol every
/// provider implements. Providers include:
///
/// - In-memory deterministic adapter (this library) — for tests;
///   outputs are a pure function of the request so every test in the
///   substrate can call through an organ without needing a real LLM.
/// - Apple FoundationModels adapter (`BASAppleAdapters`, iOS 18.1+)
///   — default on-device provider.
/// - MLX adapter (future) — for models that fall outside the
///   FoundationModels surface.
/// - Remote LLM adapter (future, opt-in) — for development /
///   benchmarking; production hosts should prefer on-device.
///
/// ## Scout vs Core
///
/// The substrate uses a "two-tier" organ metaphor. `BASOrganRole` is
/// how the caller states which tier they want:
///
/// - `.scout` — cheap, fast, shallow. Used by L1 wake arbitration,
///   L11 gate pre-filtering, L12 soft-surface draft rendering.
/// - `.core` — deeper, slower, more expensive. Used by L9/L10 when
///   a draft has been admitted for full consideration.
///
/// Adapters are free to realize "scout" and "core" as the same
/// underlying model with different sampling parameters, or as two
/// separate models. The presets (`BASOrganPreset.scout` /
/// `.core`) name the defaults the substrate assumes.
public protocol BASOrganAdapter: Sendable {
    var descriptor: BASOrganDescriptor { get }

    /// Produce a draft for the given request. Non-streaming — a
    /// complete response is returned, or an error is thrown. Streaming
    /// is a separate method (future work) so the simpler contract is
    /// available to every adapter without extra machinery.
    func draft(_ request: BASOrganRequest) async throws -> BASOrganDraft

    /// Announce how much work this provider is willing to take on
    /// right now. Adapters that observe device pressure (thermal,
    /// memory, battery) return a reduced capacity; adapters that
    /// don't care return `.unlimited`.
    func currentCapacity() async -> BASOrganCapacity
}

/// Describes what an organ provider is. Included in every draft so
/// the audit trail can prove which model produced which output.
public struct BASOrganDescriptor: Sendable, Equatable, Codable {
    public let providerID: String
    public let providerName: String
    public let supportsStreaming: Bool
    public let maxInputTokens: Int
    public let maxOutputTokens: Int
    public let runsOnDevice: Bool
    public let supportedRoles: Set<BASOrganRole>

    public init(
        providerID: String,
        providerName: String,
        supportsStreaming: Bool,
        maxInputTokens: Int,
        maxOutputTokens: Int,
        runsOnDevice: Bool,
        supportedRoles: Set<BASOrganRole>
    ) {
        self.providerID = providerID
        self.providerName = providerName
        self.supportsStreaming = supportsStreaming
        self.maxInputTokens = max(0, maxInputTokens)
        self.maxOutputTokens = max(0, maxOutputTokens)
        self.runsOnDevice = runsOnDevice
        self.supportedRoles = supportedRoles
    }
}

public enum BASOrganRole: String, Sendable, Equatable, Codable,
    CaseIterable, Hashable
{
    case scout
    case core
}

public struct BASOrganCapacity: Sendable, Equatable, Codable {
    public let availableInputTokens: Int
    public let availableOutputTokens: Int
    public let underPressure: Bool
    public let reasonCodes: [String]

    public init(
        availableInputTokens: Int,
        availableOutputTokens: Int,
        underPressure: Bool,
        reasonCodes: [String] = []
    ) {
        self.availableInputTokens = max(0, availableInputTokens)
        self.availableOutputTokens = max(0, availableOutputTokens)
        self.underPressure = underPressure
        self.reasonCodes = reasonCodes
    }

    public static let unlimited = BASOrganCapacity(
        availableInputTokens: .max,
        availableOutputTokens: .max,
        underPressure: false)
}

public struct BASOrganRequest: Sendable, Equatable {
    public let requestID: String
    public let role: BASOrganRole
    public let preset: BASOrganPreset
    /// Natural-language instruction. Adapters are free to wrap it
    /// in their own prompt scaffolding; the substrate does not
    /// prescribe a chat format here.
    public let instruction: String
    /// Optional prior context (e.g. L8 memory retrievals). Adapters
    /// append them verbatim; callers are responsible for redaction.
    public let context: [String]
    public let maxOutputTokens: Int?
    public let stopSequences: [String]
    public let deadline: Date?

    // MARK: - Chapter 三百六五 / M852 — G6 part 2: tool calling +
    // guided generation fields

    /// Optional tool descriptors the LLM may invoke。Adapters
    /// translate to their LLM's tool-call API format
    /// (AppleFoundation `LanguageModelSession.respond(to:tools:)`
    /// on iOS 26;OpenAI-compatible function calling on cloud
    /// adapters)。
    ///
    /// **Empty array (default)** = plain-text-only generation
    /// (zero behavior change for hosts that haven't opted in to
    /// tool calling — ADR-014 OPT-IN doctrine)。
    public let tools: [BASTool]

    /// Optional structured-output schema。When non-nil,LLM
    /// output is constrained to match the JSON Schema fragment
    /// in `outputSchema.propertiesJSON`。AFM iOS 26 maps to
    /// `Generable` typed output;cloud adapters map to OpenAI's
    /// `response_format: json_schema`。
    ///
    /// **nil (default)** = plain-text output (zero behavior
    /// change vs pre-M852)。
    public let outputSchema: BASGuidedGenerationSchema?

    public init(
        requestID: String,
        role: BASOrganRole,
        preset: BASOrganPreset,
        instruction: String,
        context: [String] = [],
        maxOutputTokens: Int? = nil,
        stopSequences: [String] = [],
        deadline: Date? = nil,
        tools: [BASTool] = [],
        outputSchema: BASGuidedGenerationSchema? = nil
    ) {
        self.requestID = requestID
        self.role = role
        self.preset = preset
        self.instruction = instruction
        self.context = context
        self.maxOutputTokens = maxOutputTokens.map { max(0, $0) }
        self.stopSequences = stopSequences
        self.deadline = deadline
        self.tools = tools
        self.outputSchema = outputSchema
    }
}

public struct BASOrganDraft: Sendable, Equatable {
    public let requestID: String
    public let providerID: String
    public let role: BASOrganRole
    public let body: String
    public let inputTokensEstimated: Int
    public let outputTokensEstimated: Int
    public let producedAt: Date
    public let traceID: String

    public init(
        requestID: String,
        providerID: String,
        role: BASOrganRole,
        body: String,
        inputTokensEstimated: Int,
        outputTokensEstimated: Int,
        producedAt: Date,
        traceID: String
    ) {
        self.requestID = requestID
        self.providerID = providerID
        self.role = role
        self.body = body
        self.inputTokensEstimated = max(0, inputTokensEstimated)
        self.outputTokensEstimated = max(0, outputTokensEstimated)
        self.producedAt = producedAt
        self.traceID = traceID
    }
}

/// Sampling/behavior preset. Adapters translate these into their own
/// native parameter space (e.g. Apple FoundationModels
/// `GenerationOptions`, OpenAI `temperature`/`top_p`).
public struct BASOrganPreset: Sendable, Equatable, Codable {
    public let name: String
    public let temperature: Double
    public let topP: Double
    public let maxOutputTokens: Int
    public let deterministic: Bool

    public init(
        name: String,
        temperature: Double,
        topP: Double,
        maxOutputTokens: Int,
        deterministic: Bool = false
    ) {
        self.name = name
        self.temperature = min(2, max(0, temperature))
        self.topP = min(1, max(0, topP))
        self.maxOutputTokens = max(1, maxOutputTokens)
        self.deterministic = deterministic
    }

    /// Scout default — low temperature, short output, determinism
    /// preferred when the adapter supports it.
    public static let scout = BASOrganPreset(
        name: "bas.scout.v1",
        temperature: 0.1,
        topP: 0.95,
        maxOutputTokens: 192,
        deterministic: true)

    /// Core default — mid temperature, longer output. Non-deterministic
    /// by design so L9 candidate exploration has variety.
    public static let core = BASOrganPreset(
        name: "bas.core.v1",
        temperature: 0.7,
        topP: 0.95,
        maxOutputTokens: 1_024,
        deterministic: false)
}

public enum BASOrganError: Error, Equatable, Sendable {
    case unsupportedRole(BASOrganRole)
    case inputTooLong(limit: Int, actual: Int)
    case deadlineExpired
    case providerUnavailable(reason: String)
    case pressureRefusal(reason: String)
}
