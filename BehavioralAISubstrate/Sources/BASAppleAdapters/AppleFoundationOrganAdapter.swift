import Foundation
import BASRuntimeCore
import BASOrgan
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Apple FoundationModels organ adapter.
///
/// ## Why this exists
///
/// The plan (§9.6 and §9.9 Q1 = Y) locks the default neural provider
/// to Apple's on-device `FoundationModels` framework. This file is the
/// adapter that fulfills that commitment: it implements `BASOrganAdapter`
/// by delegating to `LanguageModelSession`.
///
/// NOTE (version honesty): the live delegation path is gated
/// `@available(iOS 26, macOS 26, visionOS 26, *)` — that is the OS floor
/// where Apple actually shipped the on-device `FoundationModels`
/// inference API this adapter calls. Earlier-OS builds (and non-Apple
/// platforms) fall through to the unavailability stub via
/// `currentCapacity()` (see below).
///
/// ## Availability
///
/// `FoundationModels` is an SDK-level framework — it can't be
/// imported on earlier OS versions, so the full implementation is
/// behind `#if canImport(FoundationModels)`. On platforms / OS
/// versions that don't have it, the adapter compiles as a stub that
/// reports unavailability through `currentCapacity()` — callers can
/// fall back to another registered provider.
///
/// ## Test coverage
///
/// - `AppleFoundationOrganAdapterTests` — descriptor, role
///   enforcement, stub-fallthrough on OS<26, pure prompt helpers.
///   Runs on every OS the test target can build for.
/// - `AppleFoundationE2ETests` (M177) — real `LanguageModelSession`
///   invocation through the `BASOrganAdapter` contract. Gated
///   behind `QINAO_FM_E2E=1` and macOS 26+ / iOS 26+ / visionOS 26+
///   so default `swift test` stays fast and offline.
public actor AppleFoundationOrganAdapter: BASOrganAdapter {
    public nonisolated let descriptor: BASOrganDescriptor

    /// M234 — opt-in T2 (Risk Spine) curriculum injection.
    /// Default `false` keeps the pre-M234 system prompt byte-equal
    /// for every existing audit ledger entry. When `true`, the
    /// adapter delegates to `BASOrganCurriculum` to append the
    /// Risk Spine block to the role base.
    public nonisolated let includeRiskCurriculum: Bool

    /// M234 — opt-in T3 (Permit Knot) curriculum injection.
    /// Same backward-compat semantics as `includeRiskCurriculum`.
    public nonisolated let includePermitCurriculum: Bool

    public init(
        providerID: String = "apple.foundation-models.v1",
        providerName: String = "Apple FoundationModels",
        supportsStreaming: Bool = true,
        maxInputTokens: Int = 4_096,
        maxOutputTokens: Int = 4_096,
        supportedRoles: Set<BASOrganRole> = [.scout, .core],
        includeRiskCurriculum: Bool = false,
        includePermitCurriculum: Bool = false
    ) {
        self.descriptor = BASOrganDescriptor(
            providerID: providerID,
            providerName: providerName,
            supportsStreaming: supportsStreaming,
            maxInputTokens: maxInputTokens,
            maxOutputTokens: maxOutputTokens,
            runsOnDevice: true,
            supportedRoles: supportedRoles)
        self.includeRiskCurriculum = includeRiskCurriculum
        self.includePermitCurriculum = includePermitCurriculum
    }

    public func draft(
        _ request: BASOrganRequest
    ) async throws -> BASOrganDraft {
        guard descriptor.supportedRoles.contains(request.role) else {
            throw BASOrganError.unsupportedRole(request.role)
        }

        #if canImport(FoundationModels)
        if #available(iOS 26, macOS 26, visionOS 26, *) {
            return try await draftViaFoundation(request)
        }
        throw BASOrganError.providerUnavailable(
            reason: "FoundationModels LanguageModelSession requires iOS 26+ / macOS 26+")
        #else
        throw BASOrganError.providerUnavailable(
            reason:
                "FoundationModels framework unavailable in this build")
        #endif
    }

    public func currentCapacity() async -> BASOrganCapacity {
        #if canImport(FoundationModels)
        if #available(iOS 26, macOS 26, visionOS 26, *) {
            return .unlimited
        }
        return BASOrganCapacity(
            availableInputTokens: 0,
            availableOutputTokens: 0,
            underPressure: true,
            reasonCodes: ["FOUNDATION_UNAVAILABLE_OS"])
        #else
        return BASOrganCapacity(
            availableInputTokens: 0,
            availableOutputTokens: 0,
            underPressure: true,
            reasonCodes: ["FOUNDATION_UNAVAILABLE_BUILD"])
        #endif
    }

    // MARK: - FoundationModels delegation

    #if canImport(FoundationModels)
    @available(iOS 26, macOS 26, visionOS 26, *)
    private func draftViaFoundation(
        _ request: BASOrganRequest
    ) async throws -> BASOrganDraft {
        // Build a session per request. Stateful multi-turn sessions
        // are outside M5 scope — the substrate's L8 memory layer is
        // responsible for cross-turn state; the organ stays
        // stateless.
        let session = LanguageModelSession(
            instructions: instructions(for: request))
        let options = GenerationOptions(
            temperature: request.preset.temperature)

        // `.runtimeSchema` tool bridging: DECLARE tools in the prompt so the model can emit a parseable
        // tool-call. The matched parser ships alongside (`BASToolPromptRenderer.parseToolCall`); a HOST opts it
        // into a `BASToolCallingPlanner` policy → the parsed call is gated (BASToolInvocationGate) + dispatched
        // (BASToolDispatcher). The adapter runs NOTHING (gate-before-execute / 红线 7 preserved) — the
        // governance-safe alternative to FoundationModels' native Tool auto-execution (which would run ungated
        // side-effects mid-generation). HONEST BOUND: emit+parse pair only; the host wires the policy and the
        // real-model round-trip is NOT yet exercised on-device. Empty tools → empty block → byte-equal to before.
        let toolBlock = BASToolPromptRenderer.runtimeSchemaBlock(for: request.tools)
        let prompt = toolBlock.isEmpty
            ? Self.prompt(for: request)
            : Self.prompt(for: request) + "\n\n" + toolBlock

        // `request.outputSchema` → FoundationModels guided generation (runtime DynamicGenerationSchema →
        // GenerationSchema → respond(to:schema:)). Structured output is SIDE-EFFECT-FREE, so it does NOT cross
        // the ADR-039 byte-deterministic governance wall — wired independently of tools. Falls back to plain
        // generation when the schema can't be mapped (BASGuidedSchemaTranslator returns nil) — never drops a
        // field silently, never crashes on a malformed schema.
        // HONEST BOUND (R1): compile-checked via `swift build`; the iOS-26 GenerationSchema/respond(to:schema:)
        // RUNTIME path is on-device-only and NOT yet exercised on hardware (the macOS host can't run the model).
        let body: String
        var schemaWired = false
        if let outputSchema = request.outputSchema,
           let parsed = BASGuidedSchemaTranslator.parse(
               propertiesJSON: outputSchema.propertiesJSON,
               schemaName: outputSchema.schemaName),
           let genSchema = try? BASGuidedSchemaTranslator.makeGenerationSchema(from: parsed) {
            let response = try await session.respond(
                to: prompt, schema: genSchema, options: options)
            body = response.content.jsonString
            schemaWired = true
        } else {
            let response = try await session.respond(to: prompt, options: options)
            body = response.content
        }

        // Trace markers (typed, grep-able) composed from the bridge taxonomy — the bridge is now EXERCISED in
        // the live path, not just typed surface:
        //   - tools present → bridged via `.runtimeSchema` (declared in prompt, host-executed; NOT dropped, NOT
        //     natively run) → `#afm-tools-runtime-schema`.
        //   - outputSchema present but unmappable → still degraded (plain generation) → the M870 dropped suffix.
        let baseTrace = BASOrganDeterministicAdapter.digest(
            for: request, providerID: descriptor.providerID)
        let toolBridge = BASFoundationModelsToolBridge.resolve(
            strategy: .runtimeSchema, tools: request.tools, baseTraceID: baseTrace)
        let schemaGap = (request.outputSchema != nil) && !schemaWired
        let traceID = Self.composeTraceID(
            base: baseTrace,
            toolsBridged: toolBridge.didBridgeTools,
            schemaGap: schemaGap)

        return BASOrganDraft(
            requestID: request.requestID,
            providerID: descriptor.providerID,
            role: request.role,
            body: body,
            inputTokensEstimated: BASOrganDeterministicAdapter
                .estimateTokens(
                    from: [request.instruction] + request.context),
            outputTokensEstimated: BASOrganDeterministicAdapter
                .estimateTokens(from: [body]),
            producedAt: Date(),
            traceID: traceID)
    }
    #endif

    // MARK: - Prompt helpers (pure)

    /// Compose the draft's traceID from the base digest + the two independent degradation/bridge facts. Pure +
    /// non-gated so it is host-testable (the live `draftViaFoundation` is iOS-26-only). Order matters: the
    /// runtime-schema marker (tools bridged) goes first, the M870 audit suffix (unmapped schema) LAST — so
    /// `BASFoundationModelsToolBridge.isAuditedTraceID`'s `hasSuffix(auditTraceSuffix)` still resolves.
    ///   - tools bridged via .runtimeSchema → append `#afm-tools-runtime-schema`
    ///   - outputSchema present but unmappable → append `#afm-tools-dropped-no-sdk-bridge`
    ///   - mapped schema + no tools → no suffix (fully honored)
    static func composeTraceID(base: String, toolsBridged: Bool, schemaGap: Bool) -> String {
        var traceID = base
        if toolsBridged {
            traceID += BASFoundationModelsToolBridge.runtimeSchemaTraceSuffix
        }
        if schemaGap {
            traceID += BASFoundationModelsToolBridge.auditTraceSuffix
        }
        return traceID
    }

    /// System-level instruction derived from role + preset. This is
    /// what we send to FoundationModels as the "instructions"
    /// parameter when opening a session.
    ///
    /// Pre-M234 this returned bare scout/core text. M234 makes it
    /// curriculum-aware: actor-instance method `instructions(for:)`
    /// honors the adapter's `includeRiskCurriculum` /
    /// `includePermitCurriculum` flags. The legacy `static func
    /// systemInstructions(for:)` is preserved for tests and
    /// backward-compatible call sites — it always returns the
    /// no-curriculum role base.
    public static func systemInstructions(
        for request: BASOrganRequest
    ) -> String {
        BASOrganCurriculum.composedSystemPrompt(
            role: request.role,
            includeRiskCurriculum: false,
            includePermitCurriculum: false)
    }

    /// M234 instance-method form of `systemInstructions` that
    /// honors the adapter's curriculum flags. `nonisolated` so
    /// streaming continuations (also nonisolated) can call it
    /// without actor hops; reads only `nonisolated let` flags.
    public nonisolated func instructions(
        for request: BASOrganRequest
    ) -> String {
        BASOrganCurriculum.composedSystemPrompt(
            role: request.role,
            includeRiskCurriculum: includeRiskCurriculum,
            includePermitCurriculum: includePermitCurriculum)
    }

    public static func prompt(for request: BASOrganRequest) -> String {
        var parts = ["Instruction:", request.instruction]
        if !request.context.isEmpty {
            parts.append("")
            parts.append("Context:")
            for (i, ctx) in request.context.enumerated() {
                parts.append("[\(i + 1)] \(ctx)")
            }
        }
        return parts.joined(separator: "\n")
    }
}
