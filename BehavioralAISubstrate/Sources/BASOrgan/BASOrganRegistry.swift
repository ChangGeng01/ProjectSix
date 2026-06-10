import Foundation
import BASRuntimeCore

/// Registry of installed organ adapters. Callers (L9/L10, L11
/// gate's prefilter, L12 soft-surface drafts) obtain the adapter
/// for a role via the registry rather than holding the adapter
/// directly. This keeps substitution cheap: swap `FoundationModels
/// → MLX` with a single `register(...)` call, no surgery in every
/// consumer.
///
/// ## Resolution rules
///
/// 1. When a consumer asks for an adapter by role, prefer the most
///    recently registered on-device provider that supports it.
/// 2. If no on-device provider supports it, fall back to any
///    registered provider.
/// 3. If nothing is registered, throw `noAdapterForRole`.
///
/// Registry is append-only in spirit — re-registering the same
/// providerID overwrites (so hot-reload in tests is sane) but
/// un-registration is explicit and logged at the call site.
public actor BASOrganRegistry {
    public enum RegistryError:
        Error, Equatable, Sendable, Codable
    {
        case noAdapterForRole(BASOrganRole)
        case unknownProvider(id: String)
    }

    public struct Entry: Sendable {
        public let descriptor: BASOrganDescriptor
        public let adapter: any BASOrganAdapter
        public let registeredAt: Date
    }

    private var entries: [String: Entry] = [:]
    private var registrationOrder: [String] = []
    private let clock: @Sendable () -> Date

    public init(clock: @escaping @Sendable () -> Date = { Date() }) {
        self.clock = clock
    }

    // MARK: - Registration

    public func register(_ adapter: any BASOrganAdapter) {
        let descriptor = adapter.descriptor
        if entries[descriptor.providerID] == nil {
            registrationOrder.append(descriptor.providerID)
        }
        entries[descriptor.providerID] = Entry(
            descriptor: descriptor,
            adapter: adapter,
            registeredAt: clock())
    }

    public func unregister(providerID: String) throws {
        guard entries[providerID] != nil else {
            throw RegistryError.unknownProvider(id: providerID)
        }
        entries[providerID] = nil
        registrationOrder.removeAll { $0 == providerID }
    }

    // MARK: - Resolution

    public func adapter(
        for role: BASOrganRole
    ) throws -> any BASOrganAdapter {
        // Prefer most-recently registered on-device adapters.
        let onDevice = registrationOrder.reversed().compactMap { id -> Entry? in
            guard let entry = entries[id] else { return nil }
            return entry.descriptor.runsOnDevice
                && entry.descriptor.supportedRoles.contains(role)
                ? entry : nil
        }
        if let chosen = onDevice.first { return chosen.adapter }

        // Fallback to any registered adapter supporting the role.
        let any = registrationOrder.reversed().compactMap { id -> Entry? in
            guard let entry = entries[id] else { return nil }
            return entry.descriptor.supportedRoles.contains(role)
                ? entry : nil
        }
        if let fallback = any.first { return fallback.adapter }
        throw RegistryError.noAdapterForRole(role)
    }

    /// 结构大重构 — Phase D: resolve an adapter for `role` under an explicit ROUTING policy.
    ///
    /// `.registryDefault` (the default) delegates to `adapter(for:)` → byte-identical to today. `.neuralMatrix`
    /// opts into the observation-class `BASNeuralProviderMatrix` ranking: it ranks the registry's role-eligible
    /// providers and resolves the chosen one. If the matrix selects nothing resolvable, it falls back to
    /// `.registryDefault` (never worse than today). Every existing caller uses the no-routing `adapter(for:)`
    /// overload and is unaffected (ADR-014 OPT-IN). The matrix is reasoning-side / hint-only — this resolution is
    /// not a spine operation.
    public func adapter(
        for role: BASOrganRole,
        routing: BASProviderRouting
    ) throws -> any BASOrganAdapter {
        switch routing {
        case .registryDefault:
            return try adapter(for: role)

        case let .neuralMatrix(preferCertified, preferSmallest):
            let selection = BASNeuralProviderMatrix.select(
                context: .init(
                    role: role,
                    preferCertified: preferCertified,
                    preferSmallest: preferSmallest),
                candidates: descriptors())
            guard let chosenID = selection.chosen?.providerID,
                  let entry = entries[chosenID] else {
                // Matrix chose nothing resolvable → registry default (fail-safe).
                return try adapter(for: role)
            }
            return entry.adapter
        }
    }

    public func descriptors() -> [BASOrganDescriptor] {
        registrationOrder.compactMap { entries[$0]?.descriptor }
    }

    public func count() -> Int { entries.count }

    public func hasRole(_ role: BASOrganRole) -> Bool {
        entries.values.contains { $0.descriptor.supportedRoles.contains(role) }
    }
}
