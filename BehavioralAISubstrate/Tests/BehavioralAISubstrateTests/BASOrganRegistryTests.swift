import XCTest
@testable import BASRuntimeCore
@testable import BASOrgan

/// Tests for the organ registry's explicit provider-identity lookup.
final class BASOrganRegistryTests: XCTestCase {
    func testLookupUsesExplicitProviderIDRegardlessOfRegistrationOrder()
        async throws
    {
        for providerIDs in [["provider-a", "provider-b"], ["provider-b", "provider-a"]] {
            let registry = BASOrganRegistry()
            for providerID in providerIDs {
                await registry.register(
                    BASOrganDeterministicAdapter(providerID: providerID))
            }

            let selected = try await registry.adapter(providerID: "provider-a")
            XCTAssertEqual(selected.descriptor.providerID, "provider-a")
            let descriptor = try await registry.descriptor(providerID: "provider-a")
            XCTAssertEqual(descriptor.providerID, "provider-a")

            try await registry.unregister(providerID: "provider-a")
            do {
                _ = try await registry.adapter(providerID: "provider-a")
                XCTFail("missing selection must not fall back to provider-b")
            } catch BASOrganRegistry.RegistryError.unknownProvider(let id) {
                XCTAssertEqual(id, "provider-a")
            }
        }
    }

    func testDescriptorLookupThrowsForMissingProviderID() async {
        let registry = BASOrganRegistry()
        await registry.register(
            BASOrganDeterministicAdapter(providerID: "provider-b"))

        do {
            _ = try await registry.descriptor(providerID: "provider-a")
            XCTFail("missing descriptor must not fall back to provider-b")
        } catch BASOrganRegistry.RegistryError.unknownProvider(let id) {
            XCTAssertEqual(id, "provider-a")
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testReregisteringSameProviderIDOverwritesInOriginalOrder()
        async throws
    {
        let registry = BASOrganRegistry()
        await registry.register(BASOrganDeterministicAdapter(
            providerID: "provider-a", providerName: "First"))
        await registry.register(BASOrganDeterministicAdapter(
            providerID: "provider-b", providerName: "Second"))
        await registry.register(BASOrganDeterministicAdapter(
            providerID: "provider-a", providerName: "Replacement"))

        let count = await registry.count()
        XCTAssertEqual(count, 2)
        let descriptors = await registry.descriptors()
        XCTAssertEqual(descriptors.map(\.providerID), ["provider-a", "provider-b"])
        XCTAssertEqual(descriptors.map(\.providerName), ["Replacement", "Second"])
        let selected = try await registry.adapter(providerID: "provider-a")
        XCTAssertEqual(selected.descriptor.providerName, "Replacement")
    }

    func testUnregisterUnknownThrows() async {
        let registry = BASOrganRegistry()
        do {
            try await registry.unregister(providerID: "ghost")
            XCTFail("expected unknownProvider")
        } catch BASOrganRegistry.RegistryError.unknownProvider(let id) {
            XCTAssertEqual(id, "ghost")
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testHasRoleRemainsReadOnlyRegistrationObservation() async {
        let registry = BASOrganRegistry()
        await registry.register(BASOrganDeterministicAdapter(
            providerID: "scout-only", supportedRoles: [.scout]))

        let hasScout = await registry.hasRole(.scout)
        let hasCore = await registry.hasRole(.core)
        let count = await registry.count()
        XCTAssertTrue(hasScout)
        XCTAssertFalse(hasCore)
        XCTAssertEqual(count, 1)
    }

    func testLegacyNoAdapterForRoleErrorCodableRoundTrip() throws {
        let original = BASOrganRegistry.RegistryError.noAdapterForRole(.core)
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASOrganRegistry.RegistryError.self, from: encoded)
        XCTAssertEqual(decoded, original)
    }
}
