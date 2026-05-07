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
/// to Apple's on-device `FoundationModels` framework (iOS 18.1+ /
/// macOS 15.1+ / visionOS 2.1+). This file is the adapter that
/// fulfills that commitment: it implements `BASOrganAdapter` by
/// delegating to `LanguageModelSession`.
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

        // Chapter 三百八三 / M870 — A1 G6 AFM tool wire transparency:
        // pre-M870 this method silently dropped `request.tools[]` +
        // `request.outputSchema`。Post-M870 we still drop them at
        // the SDK call (the iOS 26 `respond(to:tools:)` real wire
        // ships when the FoundationModels Tool bridge stabilizes),
        // but we now emit a typed audit signal via the trace ID so
        // downstream observers can detect the gap。Hosts that need
        // tool calling today should route through a cloud adapter
        // (which honors `tools[]`) until this bridge activates。
        let toolGap =
            !request.tools.isEmpty
                || request.outputSchema != nil
        let prompt = Self.prompt(for: request)
        let response = try await session.respond(
            to: prompt,
            options: options)

        let body = response.content

        // Post-fix: build the trace ID with the tools-dropped
        // audit suffix when applicable (typed,grep-able)
        let baseTrace = BASOrganDeterministicAdapter.digest(
            for: request, providerID: descriptor.providerID)
        let traceID = toolGap
            ? "\(baseTrace)#afm-tools-dropped-no-sdk-bridge"
            : baseTrace

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
