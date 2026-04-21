import Foundation
import BASOrgan

/// Internal endpoint that wraps a substrate-level organ registry so
/// the loop can drive it through the Qinao-public `QinaoOrganEndpoint`
/// protocol. Kept `internal` on purpose — the substrate type names
/// (`BASOrganRegistry`, `BASOrganRequest`, etc.) never surface in the
/// public symbol graph, which the redaction check enforces.
///
/// `adapterOverride` is an internal test hook: when present, it's
/// used instead of `registry.adapter(for:)` so tests can drive a
/// captured adapter without having to register+re-register. Hosts
/// use `registry` only.
struct BASOrganRegistryEndpoint: QinaoOrganEndpoint {
    let registry: BASOrganRegistry?
    let adapterOverride: (@Sendable (BASOrganRole) async throws -> any BASOrganAdapter)?
    let presetForRole: @Sendable (BASOrganRole) -> BASOrganPreset
    let nextRequestID: @Sendable () -> String

    init(
        registry: BASOrganRegistry? = nil,
        adapterOverride: (@Sendable (BASOrganRole) async throws -> any BASOrganAdapter)? = nil,
        presetForRole: @escaping @Sendable (BASOrganRole) -> BASOrganPreset = Self.defaultPreset,
        nextRequestID: @escaping @Sendable () -> String = { UUID().uuidString }
    ) {
        self.registry = registry
        self.adapterOverride = adapterOverride
        self.presetForRole = presetForRole
        self.nextRequestID = nextRequestID
    }

    func produceBody(
        prompt: String,
        context: [String],
        role: QinaoLoop.OrganRole,
        sessionID: String
    ) async throws -> QinaoLoop.OrganResponse {
        let internalRole = Self.toInternalRole(role)
        do {
            let adapter: any BASOrganAdapter
            if let override = adapterOverride {
                adapter = try await override(internalRole)
            } else if let registry = registry {
                adapter = try await registry.adapter(for: internalRole)
            } else {
                throw QinaoLoop.LoopError.organUnavailable(
                    reason: "no-endpoint-configured")
            }

            let preset = presetForRole(internalRole)
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
