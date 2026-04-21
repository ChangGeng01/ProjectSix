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
/// The availability-guarded path is not exercised by `swift test` on
/// macOS 14 (CryptoKit-only). The stub path IS exercised so the
/// substrate can at minimum prove the integration is wired correctly
/// and adapters fall through gracefully when the framework is absent.
public actor AppleFoundationOrganAdapter: BASOrganAdapter {
    public nonisolated let descriptor: BASOrganDescriptor

    public init(
        providerID: String = "apple.foundation-models.v1",
        providerName: String = "Apple FoundationModels",
        supportsStreaming: Bool = true,
        maxInputTokens: Int = 4_096,
        maxOutputTokens: Int = 4_096,
        supportedRoles: Set<BASOrganRole> = [.scout, .core]
    ) {
        self.descriptor = BASOrganDescriptor(
            providerID: providerID,
            providerName: providerName,
            supportsStreaming: supportsStreaming,
            maxInputTokens: maxInputTokens,
            maxOutputTokens: maxOutputTokens,
            runsOnDevice: true,
            supportedRoles: supportedRoles)
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
            instructions: Self.systemInstructions(for: request))
        let options = GenerationOptions(
            temperature: request.preset.temperature)

        let prompt = Self.prompt(for: request)
        let response = try await session.respond(
            to: prompt,
            options: options)

        let body = response.content
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
            traceID: BASOrganDeterministicAdapter.digest(
                for: request, providerID: descriptor.providerID))
    }
    #endif

    // MARK: - Prompt helpers (pure)

    /// System-level instruction derived from role + preset. This is
    /// what we send to FoundationModels as the "instructions"
    /// parameter when opening a session.
    public static func systemInstructions(
        for request: BASOrganRequest
    ) -> String {
        switch request.role {
        case .scout:
            return """
            You are the Scout tier of a behavioural AI substrate.
            Keep answers short, structured, and low-commitment.
            Prefer identifying risks and candidate angles over
            producing final prose.
            """
        case .core:
            return """
            You are the Core tier of a behavioural AI substrate.
            Produce a considered response; you are being called
            because a draft has been admitted for full consideration.
            """
        }
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
