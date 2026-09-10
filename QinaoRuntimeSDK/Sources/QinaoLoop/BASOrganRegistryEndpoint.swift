import Foundation
import BASOrgan

/// Internal endpoint that wraps a substrate-level organ registry so
/// the loop can drive it through the Qinao-public `QinaoOrganEndpoint`
/// protocol. Kept `internal` on purpose — the substrate type names
/// (`BASOrganRegistry`, `BASOrganRequest`, etc.) never surface in the
/// public symbol graph, which the redaction check enforces.
///
/// As of M77, this type also conforms to
/// `QinaoBudgetAwareOrganEndpoint` so `QinaoLoop` can hand it a
/// per-turn `QinaoOrganRoutingDecision` when a routed
/// `BASBudgetFrame` is available. When the decision route is taken,
/// the endpoint builds a one-off `BASOrganPreset` from the decision's
/// `(temperature, maxOutputTokens, deterministic)` triple instead of
/// calling `presetForRole`. The legacy role-only path
/// (`produceBody(prompt:context:role:sessionID:)`) is preserved
/// byte-compatible so endpoints built before M77 — or callers that
/// don't pass a budget — keep working unchanged.
///
/// Configured endpoints bind one explicit provider ID. Registry
/// registration order and descriptor ranking never choose an
/// invocation target. `adapterOverride` is an internal test hook
/// whose returned adapter must match the same expected identity.
package struct BASOrganRegistryEndpoint: QinaoBudgetAwareOrganEndpoint,
    QinaoStreamingOrganEndpoint
{
    package let registry: BASOrganRegistry?
    package let providerID: String?
    package let adapterOverride: (@Sendable (BASOrganRole) async throws -> any BASOrganAdapter)?
    package let presetForRole: @Sendable (BASOrganRole) -> BASOrganPreset
    package let nextRequestID: @Sendable () -> String

    /// Unconfigured endpoint retained solely for the typed negative path.
    package init() {
        registry = nil
        providerID = nil
        adapterOverride = nil
        presetForRole = Self.defaultPreset
        nextRequestID = { UUID().uuidString }
    }

    package init(
        registry: BASOrganRegistry,
        providerID: String,
        presetForRole: @escaping @Sendable (BASOrganRole) -> BASOrganPreset = Self.defaultPreset,
        nextRequestID: @escaping @Sendable () -> String = { UUID().uuidString }
    ) {
        self.registry = registry
        self.providerID = providerID
        self.adapterOverride = nil
        self.presetForRole = presetForRole
        self.nextRequestID = nextRequestID
    }

    package init(
        providerID: String,
        adapterOverride: @escaping @Sendable (BASOrganRole) async throws -> any BASOrganAdapter,
        presetForRole: @escaping @Sendable (BASOrganRole) -> BASOrganPreset = Self.defaultPreset,
        nextRequestID: @escaping @Sendable () -> String = { UUID().uuidString }
    ) {
        self.registry = nil
        self.providerID = providerID
        self.adapterOverride = adapterOverride
        self.presetForRole = presetForRole
        self.nextRequestID = nextRequestID
    }

    // MARK: - QinaoOrganEndpoint (legacy role-only path)

    package func produceBody(
        prompt: String,
        context: [String],
        role: QinaoLoop.OrganRole,
        sessionID: String
    ) async throws -> QinaoLoop.OrganResponse {
        let internalRole = Self.toInternalRole(role)
        return try await callAdapter(
            prompt: prompt,
            context: context,
            internalRole: internalRole,
            preset: presetForRole(internalRole))
    }

    // MARK: - QinaoBudgetAwareOrganEndpoint (M77 decision-aware path)

    package func produceBody(
        prompt: String,
        context: [String],
        sessionID: String,
        decision: QinaoLoop.QinaoOrganRoutingDecision
    ) async throws -> QinaoLoop.OrganResponse {
        let internalRole = Self.toInternalRole(decision.role)
        let preset = Self.preset(from: decision, internalRole: internalRole)
        return try await callAdapter(
            prompt: prompt,
            context: context,
            internalRole: internalRole,
            preset: preset)
    }

    // MARK: - QinaoStreamingOrganEndpoint (M188)

    /// Resolve the adapter, probe it for `BASStreamingOrganAdapter`,
    /// and translate `BASOrganDraftChunk` → `OrganResponseChunk`
    /// per chunk. If the resolved adapter doesn't conform to the
    /// streaming protocol, terminate the stream with
    /// `LoopError.organUnavailable(reason:"endpoint-not-streaming")`.
    package func streamBody(
        prompt: String,
        context: [String],
        role: QinaoLoop.OrganRole,
        sessionID: String
    ) -> AsyncThrowingStream<
        QinaoLoop.OrganResponseChunk, Error>
    {
        let internalRole = Self.toInternalRole(role)
        let preset = presetForRole(internalRole)
        let resolvedRequestID = nextRequestID()

        return AsyncThrowingStream { continuation in
            // audit F9 (2026-07-12): capture the pump Task + cancel on stream termination so a
            // consumer break propagates down to the inner streamDraft (the guarded GPU decode).
            let task = Task {
                do {
                    let adapter = try await resolveAdapter(
                        internalRole: internalRole)

                    guard
                        let streamingAdapter =
                            adapter as? BASStreamingOrganAdapter
                    else {
                        continuation.finish(
                            throwing: QinaoLoop.LoopError
                                .organUnavailable(
                                    reason: "endpoint-not-streaming"))
                        return
                    }

                    let request = BASOrganRequest(
                        requestID: resolvedRequestID,
                        role: internalRole,
                        preset: preset,
                        instruction: prompt,
                        context: context)
                    let stream = streamingAdapter
                        .streamDraft(request)
                    for try await chunk in stream {
                        try Task.checkCancellation()
                        continuation.yield(
                            QinaoLoop.OrganResponseChunk(
                                bodyDelta: chunk.bodyDelta,
                                cumulativeBody: chunk.cumulativeBody,
                                providerID: chunk.providerID))
                    }
                    continuation.finish()
                } catch let error as QinaoLoop.LoopError {
                    continuation.finish(throwing: error)
                } catch let error as BASOrganError {
                    continuation.finish(
                        throwing: QinaoLoop.LoopError
                            .organUnavailable(
                                reason: Self.reasonCode(
                                    for: error)))
                } catch let error
                    as BASOrganRegistry.RegistryError
                {
                    switch error {
                    case .noAdapterForRole(let r):
                        continuation.finish(
                            throwing: QinaoLoop.LoopError
                                .organUnavailable(
                                    reason:
                                        "no-adapter-for-role:" +
                                        r.rawValue))
                    case .unknownProvider(let id):
                        continuation.finish(
                            throwing: QinaoLoop.LoopError
                                .organUnavailable(
                                    reason:
                                        "unknown-provider:" + id))
                    }
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { @Sendable _ in task.cancel() }
        }
    }

    // MARK: - Shared adapter-call path

    /// Single dispatch path for both legacy and decision-aware
    /// produceBody methods. Both entry points resolve to an internal
    /// role + preset, then drive the same adapter lookup + error
    /// translation pipeline.
    private func callAdapter(
        prompt: String,
        context: [String],
        internalRole: BASOrganRole,
        preset: BASOrganPreset
    ) async throws -> QinaoLoop.OrganResponse {
        do {
            let adapter = try await resolveAdapter(
                internalRole: internalRole)

            let request = BASOrganRequest(
                requestID: nextRequestID(),
                role: internalRole,
                preset: preset,
                instruction: prompt,
                context: context)
            let draft = try await adapter.draft(request)
            return QinaoLoop.OrganResponse(
                body: draft.body,
                providerID: draft.providerID,
                traceID: draft.traceID)
        } catch let error as QinaoLoop.LoopError {
            throw error
        } catch let error as BASOrganError {
            throw QinaoLoop.LoopError.organUnavailable(
                reason: Self.reasonCode(for: error))
        } catch let error as BASOrganRegistry.RegistryError {
            switch error {
            case .noAdapterForRole(let r):
                throw QinaoLoop.LoopError.organUnavailable(
                    reason: "no-adapter-for-role:\(r.rawValue)")
            case .unknownProvider(let id):
                throw QinaoLoop.LoopError.organUnavailable(
                    reason: "unknown-provider:\(id)")
            }
        }
    }

    /// Shared identity and capability gate for eager and streaming calls.
    private func resolveAdapter(
        internalRole: BASOrganRole
    ) async throws -> any BASOrganAdapter {
        guard let providerID else {
            throw QinaoLoop.LoopError.organUnavailable(
                reason: "no-endpoint-configured")
        }

        let adapter: any BASOrganAdapter
        if let adapterOverride {
            adapter = try await adapterOverride(internalRole)
        } else if let registry {
            adapter = try await registry.adapter(providerID: providerID)
        } else {
            throw QinaoLoop.LoopError.organUnavailable(
                reason: "no-endpoint-configured")
        }

        guard adapter.descriptor.providerID == providerID else {
            throw QinaoLoop.LoopError.organUnavailable(
                reason: "provider-identity-mismatch")
        }
        guard adapter.descriptor.supportedRoles.contains(internalRole) else {
            throw BASOrganError.unsupportedRole(internalRole)
        }
        return adapter
    }

    // MARK: - Mapping helpers

    static func toInternalRole(_ role: QinaoLoop.OrganRole) -> BASOrganRole {
        switch role {
        case .scout: return .scout
        case .core:  return .core
        }
    }

    static func defaultPreset(for role: BASOrganRole) -> BASOrganPreset {
        switch role {
        case .scout: return .scout
        case .core:  return .core
        }
    }

    /// Build a `BASOrganPreset` from a `QinaoOrganRoutingDecision`.
    /// Preserves `topP = 0.95` (the substrate's canonical scout/core
    /// default) — the decision function deliberately doesn't expose
    /// `topP` as a policy knob because per-turn top-p tuning is a
    /// sampler-level concern that belongs to the adapter, not the
    /// router. `name` encodes the internal role so audit trails can
    /// tell M77-routed calls from pre-M77 calls.
    static func preset(
        from decision: QinaoLoop.QinaoOrganRoutingDecision,
        internalRole: BASOrganRole
    ) -> BASOrganPreset {
        BASOrganPreset(
            name: "qinao.m77.\(internalRole.rawValue).routed",
            temperature: decision.temperature,
            topP: 0.95,
            maxOutputTokens: decision.maxOutputTokens,
            deterministic: decision.deterministic)
    }

    private static func reasonCode(for error: BASOrganError) -> String {
        switch error {
        case .unsupportedRole(let role):
            return "unsupported-role:\(role.rawValue)"
        case .inputTooLong(let limit, let actual):
            return "input-too-long:\(actual)/\(limit)"
        case .deadlineExpired:
            return "deadline-expired"
        case .providerUnavailable(let reason):
            return "provider-unavailable:\(reason)"
        case .pressureRefusal(let reason):
            return "pressure-refusal:\(reason)"
        }
    }
}
