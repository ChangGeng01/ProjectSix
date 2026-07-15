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
/// `@available(iOS 27, macOS 27, visionOS 27, *)` — that is the OS floor
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
            supportedRoles: supportedRoles,
            // ADR-041 §D — matrix metadata: Apple's built-in on-device LLM, on-device run-certified (#1 cert).
            providerKind: .appleNative,
            certificationTier: .certified)
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
        // OS floor RAISED 26 -> 27 (operator decision, 2026-07-14). Rationale, measured
        // not assumed: on 26 the framework throws `LanguageModelSession.GenerationError`;
        // on 27 it throws `LanguageModelError` — a DIFFERENT enum with a different case
        // set (probe on macOS 27: dynamicType = LanguageModelError, `error is
        // GenerationError` == false). `respond` is untyped-throws, so supporting both
        // floors means carrying two mapping arms, and the 26 arm is UNTESTABLE here (no
        // macOS 26 host) — untestable error-mapping code is exactly the kind that rots
        // into a lie. One floor, one arm, real-error teeth.
        if #available(iOS 27, macOS 27, visionOS 27, *) {
            return try await draftViaFoundation(request)
        }
        throw BASOrganError.providerUnavailable(
            reason: "FoundationModels LanguageModelSession requires iOS 27+ / macOS 27+ "
                + "(the 26 error taxonomy is not mapped — see the floor note above)")
        #else
        throw BASOrganError.providerUnavailable(
            reason:
                "FoundationModels framework unavailable in this build")
        #endif
    }

    public func currentCapacity() async -> BASOrganCapacity {
        #if canImport(FoundationModels)
        // Must track draft()'s floor: advertising capacity on an OS where draft()
        // unconditionally refuses would tell a router this organ is usable when it is not.
        if #available(iOS 27, macOS 27, visionOS 27, *) {
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

    // MARK: - Error mapping (FoundationModels -> BASOrganError)

    #if canImport(FoundationModels)
    /// Translate a `LanguageModelError` into this adapter's declared error contract.
    ///
    /// `BASOrganAdapter` says `draft(_:)` throws `BASOrganError`. Before this, both
    /// `session.respond` calls were bare `try await`, so raw FoundationModels errors
    /// escaped the contract untranslated — the M181 translation matrix never saw the live
    /// path, and hosts got an Apple type they were never told to expect.
    ///
    /// ## ★ The refusal class is deliberately NOT mapped
    ///
    /// `guardrailViolation` and `refusal` are the model's SAFETY DECISION — a RESULT, not
    /// an outage — and they are rethrown RAW on purpose.
    ///
    /// `BASRoutingOrganAdapter` fails over to its secondary on exactly
    /// `.providerUnavailable` and `.pressureRefusal` (three sites: :161/:163, :191/:193,
    /// :216/:218), and a LIVE Apple-primary + MLX-Gemma-secondary router already ships in
    /// QinaoSampleHost/SampleHostRuntimeBenchExtensions.swift:71-74. Mapping a refusal onto
    /// either case would make that router silently RE-RUN the refused prompt on MLX —
    /// laundering Apple's safety refusal into a second model until one complies. That
    /// bypass does NOT exist today (a raw error matches neither catch), so a careless
    /// mapping would CREATE it. No existing BASOrganError case means "the model refused
    /// as its result" — `inputTooLong` / `deadlineExpired` would be lies — and a
    /// `contentRefusal` case is deliberately out of scope (operator decision, 2026-07-14).
    /// Until such a case exists, raw propagation is the honest and SAFE behaviour: the
    /// router declines to handle what it does not recognise.
    ///
    /// Returns `nil` for the refusal class, meaning "rethrow unchanged".
    /// The OTHER enum. `SystemLanguageModel.Error` is separate from `LanguageModelError`
    /// and owns `assetsUnavailable` — the model-assets/cold-cache class, which is the most
    /// common real-world AFM failure (macOS releases assets when the caller is not
    /// foreground; `swift test` from a CLI hits it routinely, surfacing as
    /// `ModelManagerError Code=1026` nested in the underlying error).
    ///
    /// Missing this arm would leave exactly that class escaping the BASOrganAdapter
    /// contract — the mapping would be a half-truth for the failure it most needs to cover.
    /// It is an OUTAGE, so it maps to .providerUnavailable and a router MAY legitimately
    /// fail over to a secondary.
    ///
    /// The reason INTERPOLATES the underlying error on purpose: host-side cold-cache
    /// detection greps this string for "ModelManagerError Code=1026", and reasonCode(for:)
    /// passes `reason` through verbatim.
    @available(iOS 27, macOS 27, visionOS 27, *)
    static func organError(for error: SystemLanguageModel.Error) -> BASOrganError {
        switch error {
        case .assetsUnavailable:
            return .providerUnavailable(reason: "afm-assets-unavailable: \(error)")
        @unknown default:
            return .providerUnavailable(reason: "afm-system-model-unknown: \(error)")
        }
    }

    @available(iOS 27, macOS 27, visionOS 27, *)
    static func organError(for error: LanguageModelError) -> BASOrganError? {
        switch error {
        // ── Safety RESULTS — never mapped, never routed around. ──
        case .guardrailViolation, .refusal:
            return nil

        // ── Caller-input violation: a hard limit the secondary would also reject. The
        //    router propagates this class rather than failing over, which is correct.
        case .contextSizeExceeded(let ctx):
            // Apple hands us the GROUND TRUTH: `contextSize` is the model's real window
            // (probe on macOS 27: 8192) and `tokenCount` is what the request actually
            // weighed. Forward both rather than re-deriving a chars/4 estimate — the
            // host-facing code is `input-too-long:<actual>/<limit>`, and an estimate
            // there would be a fabricated number where a measured one is available.
            return .inputTooLong(limit: ctx.contextSize, actual: ctx.tokenCount)

        // ── Transient pressure: the secondary MAY succeed. Safe to fail over. ──
        case .rateLimited:
            return .pressureRefusal(reason: "afm-rate-limited: \(error)")

        // ── Infrastructure / capability outages: the secondary MAY succeed. ──
        // Interpolating the underlying error is LOAD-BEARING, not cosmetic:
        // BASOrganRegistryEndpoint.reasonCode(for:) passes `reason` VERBATIM into
        // LoopError.organUnavailable, and the AFM test helper detects the
        // foreground-cache-cold state by substring ("ModelManagerError Code=1026"). If
        // these reasons were sanitised English, that detection would die and the gated
        // suite would hard-fail on any cold CLI host.
        case .timeout:
            return .providerUnavailable(reason: "afm-timeout: \(error)")
        case .unsupportedCapability:
            return .providerUnavailable(reason: "afm-unsupported-capability: \(error)")
        case .unsupportedTranscriptContent:
            return .providerUnavailable(reason: "afm-unsupported-transcript: \(error)")
        case .unsupportedGenerationGuide:
            return .providerUnavailable(reason: "afm-unsupported-guide: \(error)")
        case .unsupportedLanguageOrLocale:
            return .providerUnavailable(reason: "afm-unsupported-language: \(error)")
        @unknown default:
            return .providerUnavailable(reason: "afm-unknown-case: \(error)")
        }
    }
    #endif

    // MARK: - FoundationModels delegation

    #if canImport(FoundationModels)
    @available(iOS 27, macOS 27, visionOS 27, *)
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
        do {
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
        } catch is CancellationError {
            // FIRST, and never mapped. BASOrganRegistryEndpoint cancels the pump when the
            // consumer breaks; mapping a cancellation into .providerUnavailable would make
            // BASRoutingOrganAdapter re-run the whole generation on its secondary after the
            // caller already walked away.
            throw CancellationError()
        } catch let afm as LanguageModelError {
            // Honour the BASOrganAdapter contract. `organError(for:)` returns nil for the
            // SAFETY-REFUSAL class (guardrailViolation / refusal) — those rethrow RAW so no
            // router can launder them onto a second model. See its doc comment.
            guard let mapped = Self.organError(for: afm) else { throw afm }
            throw mapped
        } catch let sys as SystemLanguageModel.Error {
            throw Self.organError(for: sys)
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
