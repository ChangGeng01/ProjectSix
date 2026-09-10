import BASOrgan

public enum QinaoEndpointPreset: Sendable {
    case roleDefaults
    case greedyDeterministic
}

extension QinaoLoop {
    /// Compose only the host-supplied adapter. This does not load or select a
    /// model. A missing selected identity refuses at invocation; it never
    /// falls back to the registered adapter. Streaming/routing refinements
    /// are preserved by the existing endpoint implementation.
    public static func makeOrganEndpoint(
        selectedProviderID: String,
        adapter: any BASOrganAdapter,
        preset: QinaoEndpointPreset = .roleDefaults
    ) async -> any QinaoOrganEndpoint {
        let registry = BASOrganRegistry()
        await registry.register(adapter)
        switch preset {
        case .roleDefaults:
            return BASOrganRegistryEndpoint(
                registry: registry, providerID: selectedProviderID)
        case .greedyDeterministic:
            return BASOrganRegistryEndpoint(
                registry: registry, providerID: selectedProviderID,
                presetForRole: { _ in .greedyDeterministic })
        }
    }
}
