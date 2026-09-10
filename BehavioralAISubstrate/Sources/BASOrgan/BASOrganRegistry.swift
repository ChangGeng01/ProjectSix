import Foundation
import BASRuntimeCore

/// Registry of installed organ adapters. Invocation owners bind an
/// explicit provider ID and use the registry only to look up that
/// provider. Registration order and provider metadata never elect an
/// execution target.
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

    public func adapter(providerID: String) throws -> any BASOrganAdapter {
        guard let entry = entries[providerID] else {
            throw RegistryError.unknownProvider(id: providerID)
        }
        return entry.adapter
    }

    public func descriptor(providerID: String) throws -> BASOrganDescriptor {
        guard let entry = entries[providerID] else {
            throw RegistryError.unknownProvider(id: providerID)
        }
        return entry.descriptor
    }

    public func descriptors() -> [BASOrganDescriptor] {
        registrationOrder.compactMap { entries[$0]?.descriptor }
    }

    public func count() -> Int { entries.count }

    public func hasRole(_ role: BASOrganRole) -> Bool {
        entries.values.contains { $0.descriptor.supportedRoles.contains(role) }
    }
}
