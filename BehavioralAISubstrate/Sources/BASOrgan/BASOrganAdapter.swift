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

    /// Default-OFF ACCELERATED draft: a host elects a turn (typically
    /// `BASDecodeLanePolicy.promptLookupEligible(for:)`, computed host-side) to engage a model-free
    /// speculative lane. The default impl IGNORES `electAccelerated` and calls `draft(_:)` — BYTE-EQUAL for
    /// every adapter (ADR-014: nothing changes until a host elects AND the adapter has a lane). Adapters with
    /// an accelerated lane (MLX prompt-lookup) override it; under greedy (temp 0) the emitted tokens are
    /// TOKEN-identical to `draft(_:)`, only faster. Declared as a protocol REQUIREMENT (not extension-only) so
    /// the override dispatches DYNAMICALLY through a protocol-typed `adapter`.
    func draft(_ request: BASOrganRequest, electAccelerated: Bool) async throws -> BASOrganDraft

    /// PURPOSE-based accelerated draft (DecodePlan S5 — the successor to the `electAccelerated` Bool). The host
    /// passes the turn's PURPOSE; an adapter with a decode planner (MLX) resolves it to the best lane
    /// (`BASDecodeLanePolicy.decodeStrategy`). The default impl IGNORES `purpose` and calls `draft(_:)` —
    /// BYTE-EQUAL for every adapter without a lane (ADR-014). This replaces the overloaded Bool: a Boolean can
    /// only say "accelerate or not", whereas a purpose lets the planner pick AMONG lanes (plain / draft-model /
    /// prompt-lookup / cross-turn / saguaro). The Bool overload above is RETAINED as a thin compatibility shim (not deleted).
    func draft(_ request: BASOrganRequest, purpose: BASDecodeLanePolicy.Purpose) async throws -> BASOrganDraft

    /// Announce how much work this provider is willing to take on
    /// right now. Adapters that observe device pressure (thermal,
    /// memory, battery) return a reduced capacity; adapters that
    /// don't care return `.unlimited`.
    func currentCapacity() async -> BASOrganCapacity
}

public extension BASOrganAdapter {
    /// Default accelerated draft: ignore the elect flag → byte-equal to `draft(_:)`. Adapters without an
    /// accelerated lane (deterministic, Apple, remote) inherit this unchanged (ADR-014 default-off).
    func draft(_ request: BASOrganRequest, electAccelerated: Bool) async throws -> BASOrganDraft {
        try await draft(request)
    }

    /// Default PURPOSE-based draft: ignore `purpose` → byte-equal to `draft(_:)`. No-lane adapters (deterministic,
    /// Apple, remote) inherit this unchanged; only adapters with a planner (MLX) override it.
    func draft(_ request: BASOrganRequest, purpose: BASDecodeLanePolicy.Purpose) async throws -> BASOrganDraft {
        try await draft(request)
    }
}

/// Describes what an organ provider is. Included in every draft so
/// the audit trail can prove which model produced which output.
/// The kind of neural backend a provider is — used by `BASNeuralProviderMatrix` to bias selection
/// (on-device-native vs open-weight vs deterministic vs remote). Observation-class metadata, never governance.
public enum BASProviderKind: String, Sendable, Equatable, Hashable, Codable, CaseIterable {
    case appleNative    // Apple FoundationModels / Core AI (built-in, ANE-accelerated)
    case mlx            // on-device MLX (open-weight LLM, downloaded weights)
    case deterministic  // in-memory deterministic fake (tests / fallback)
    case remote         // OpenAI-compatible HTTP provider (off-device)
}

/// How certified a provider is. `experimental` until measured on-device; the matrix may prefer `certified`.
public enum BASCertificationTier: String, Sendable, Equatable, Hashable, Codable, CaseIterable {
    case certified
    case experimental
}

public struct BASOrganDescriptor: Sendable, Equatable, Codable {
    public let providerID: String
    public let providerName: String
    public let supportsStreaming: Bool
    public let maxInputTokens: Int
    public let maxOutputTokens: Int
    public let runsOnDevice: Bool
    public let supportedRoles: Set<BASOrganRole>

    // ADR-041 §D — OPTIONAL provider metadata for BASNeuralProviderMatrix ranking (observation-class, never
    // governance). Default nil → Codable stays byte-equal (Swift synthesizes encodeIfPresent/decodeIfPresent
    // for optionals, so a nil-field descriptor serializes exactly as before) + existing Equatable holds for
    // nil-field descriptors. The matrix degrades gracefully (role-only ranking) when these are nil.
    public let providerKind: BASProviderKind?
    public let certificationTier: BASCertificationTier?
    /// Approximate parameter count (e.g. `2_000_000_000` = 2B), nil if unknown. NOT bytes, NOT a model name.
    public let modelSizeHint: Int?

    public init(
        providerID: String,
        providerName: String,
        supportsStreaming: Bool,
        maxInputTokens: Int,
        maxOutputTokens: Int,
        runsOnDevice: Bool,
        supportedRoles: Set<BASOrganRole>,
        providerKind: BASProviderKind? = nil,
        certificationTier: BASCertificationTier? = nil,
        modelSizeHint: Int? = nil
    ) {
        self.providerID = providerID
        self.providerName = providerName
        self.supportsStreaming = supportsStreaming
        self.maxInputTokens = max(0, maxInputTokens)
        self.maxOutputTokens = max(0, maxOutputTokens)
        self.runsOnDevice = runsOnDevice
        self.supportedRoles = supportedRoles
        self.providerKind = providerKind
        self.certificationTier = certificationTier
        self.modelSizeHint = modelSizeHint
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

public struct BASOrganRequest: Sendable, Equatable, Codable {
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

    // MARK: - P2 多agent复用 (SYSTEM_EFFICIENCY_CAMPAIGN) — seat identity on the REQUEST

    /// Optional AGENT-SEAT session key. nil (default) = the historical stateless turn (byte-equal,
    /// ADR-014). Non-nil = the adapter maintains per-(sessionID, role) conversation state (KV cache +
    /// history reuse — MLX: the M254 ChatSession pool). Carried on the REQUEST rather than the adapter
    /// protocol so every decorator (router / contract / adjudicator / counter) forwards it for free —
    /// the recon's gap #1/#2 closed with one field. Seat convention: "seat:<agentRole>" (e.g.
    /// "seat:planner"), but any stable string works.
    public let sessionID: String?

    /// Optional per-seat SYSTEM persona, consumed ONCE at session creation (sessions freeze their system
    /// prompt; later turns' values are ignored — pass the same persona every turn for clarity). nil =
    /// the adapter's role-derived default instructions. Enables the 8 generative seats to differ in voice
    /// while sharing ONE trunk (BASAgentPersonaRoleTemplates-shaped strings).
    public let personaInstructions: String?

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
        outputSchema: BASGuidedGenerationSchema? = nil,
        sessionID: String? = nil,
        personaInstructions: String? = nil
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
        self.sessionID = sessionID
        self.personaInstructions = personaInstructions
    }
}

/// REAL decode anatomy from the underlying LLM runtime (e.g. MLX `GenerateCompletionInfo`), split into the
/// two phases that matter for efficiency: PREFILL (processing the input prompt, O(prompt length)) vs DECODE
/// (generating the output tokens, O(output length)). Token counts here are the runtime's ACTUAL counts — NOT
/// the `outputTokensEstimated` chars/4 heuristic on `BASOrganDraft`. Optional: adapters that can't surface it
/// (the deterministic adapter; cloud adapters without timing) leave it `nil`.
public struct BASOrganCompletionMetrics: Sendable, Equatable, Codable {
    public let promptTokens: Int           // real prefill token count
    public let generationTokens: Int       // real decoded token count
    public let prefillMs: Double            // wall time to process the prompt (prefill)
    public let decodeMs: Double             // wall time to generate the output tokens (decode)
    public let prefillTokensPerSec: Double
    public let decodeTokensPerSec: Double

    public init(
        promptTokens: Int,
        generationTokens: Int,
        prefillMs: Double,
        decodeMs: Double,
        prefillTokensPerSec: Double,
        decodeTokensPerSec: Double
    ) {
        self.promptTokens = max(0, promptTokens)
        self.generationTokens = max(0, generationTokens)
        self.prefillMs = max(0, prefillMs)
        self.decodeMs = max(0, decodeMs)
        self.prefillTokensPerSec = max(0, prefillTokensPerSec)
        self.decodeTokensPerSec = max(0, decodeTokensPerSec)
    }
}

public struct BASOrganDraft: Sendable, Equatable, Codable {
    public let requestID: String
    public let providerID: String
    public let role: BASOrganRole
    public let body: String
    public let inputTokensEstimated: Int
    public let outputTokensEstimated: Int
    public let producedAt: Date
    public let traceID: String
    /// REAL prefill/decode anatomy when the adapter can surface it (e.g. MLX); `nil` otherwise. Additive +
    /// optional → existing callers + serialized drafts are unaffected (decodeIfPresent ⇒ nil for old JSON).
    public let completionMetrics: BASOrganCompletionMetrics?
    /// 可解释性① — THE turn line's carrier (planned vs executed lane, fail-close reason, B3
    /// trace-exit, B2 tri-state). Additive + optional, same contract as completionMetrics.
    public let decodeAttribution: BASDecodeAttribution?

    public init(
        requestID: String,
        providerID: String,
        role: BASOrganRole,
        body: String,
        inputTokensEstimated: Int,
        outputTokensEstimated: Int,
        producedAt: Date,
        traceID: String,
        completionMetrics: BASOrganCompletionMetrics? = nil,
        decodeAttribution: BASDecodeAttribution? = nil
    ) {
        self.requestID = requestID
        self.providerID = providerID
        self.role = role
        self.body = body
        self.inputTokensEstimated = max(0, inputTokensEstimated)
        self.outputTokensEstimated = max(0, outputTokensEstimated)
        self.producedAt = producedAt
        self.traceID = traceID
        self.completionMetrics = completionMetrics
        self.decodeAttribution = decodeAttribution
    }

    /// Immutable-update helper (coding-style rule: new copy, never mutate).
    public func withDecodeAttribution(_ a: BASDecodeAttribution?) -> BASOrganDraft {
        BASOrganDraft(
            requestID: requestID, providerID: providerID, role: role, body: body,
            inputTokensEstimated: inputTokensEstimated,
            outputTokensEstimated: outputTokensEstimated,
            producedAt: producedAt, traceID: traceID,
            completionMetrics: completionMetrics, decodeAttribution: a)
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

    /// Greedy-deterministic preset (temperature 0 → argmax decoding). ADDITIVE — no existing static is
    /// touched, so scout/core outputs are byte-unchanged. A host elects this to request greedy single-model
    /// decoding, and it is the lane the greedy speculative-decode path runs on: at temperature 0 the MLX
    /// speculative decoder's exact-equality acceptance is token-IDENTICAL to greedy target-only decoding
    /// (provable byte-identity + a latency win). See the spec-decode plan / `BASSpeculativeMode.greedy`.
    public static let greedyDeterministic = BASOrganPreset(
        name: "bas.greedy.v1",
        temperature: 0,
        topP: 1,
        maxOutputTokens: 1_024,
        deterministic: true)
}

public enum BASOrganError: Error, Equatable, Sendable {
    case unsupportedRole(BASOrganRole)
    case inputTooLong(limit: Int, actual: Int)
    case deadlineExpired
    case providerUnavailable(reason: String)
    case pressureRefusal(reason: String)
}
