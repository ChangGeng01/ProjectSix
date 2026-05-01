import XCTest
@testable import BASAppleAdapters

/// 五十八.4 — Apple Foundation Models adapter descriptor tests.
///
/// Doctrine pinned:
/// - Descriptor is pure value type, Codable
/// - Binding state lifecycle: notLoaded / loaded / replaced /
///   unloaded
/// - `isAdapterActive` true only during loaded/replaced
/// - `activeAdapterID` returns current adapter id correctly
/// - Registry registering / removing immutable, lookup works
final class AppleFoundationAdapterDescriptorTests:
    XCTestCase
{

    // MARK: - Descriptor construction + Codable

    func test_descriptorConstructsWithAllFields() {
        let url = URL(
            fileURLWithPath:
                "/tmp/acme.boundary-language.v1.fmadapter")
        let descriptor =
            AppleFoundationAdapterDescriptor(
                adapterID:
                    "acme.boundary-language.v1",
                url: url,
                version: "v1",
                trainingProvenanceHash:
                    "sha256:abc123",
                purpose:
                    "Boundary-language specialization for " +
                    "host hostA")
        XCTAssertEqual(
            descriptor.adapterID,
            "acme.boundary-language.v1")
        XCTAssertEqual(descriptor.url, url)
        XCTAssertEqual(descriptor.version, "v1")
        XCTAssertEqual(
            descriptor.trainingProvenanceHash,
            "sha256:abc123")
    }

    func test_descriptorCodableRoundTrip() throws {
        let descriptor =
            AppleFoundationAdapterDescriptor(
                adapterID: "test.v1",
                url: URL(fileURLWithPath: "/tmp/x"),
                version: "v1",
                trainingProvenanceHash: "sha256:zzz",
                purpose: "test")
        let data = try JSONEncoder().encode(descriptor)
        let decoded = try JSONDecoder().decode(
            AppleFoundationAdapterDescriptor.self,
            from: data)
        XCTAssertEqual(decoded, descriptor)
    }

    // MARK: - Binding state lifecycle

    func test_notLoadedIsInactive() {
        let state =
            AppleFoundationAdapterBindingState.notLoaded
        XCTAssertFalse(state.isAdapterActive)
        XCTAssertNil(state.activeAdapterID)
    }

    func test_loadedIsActiveWithID() {
        let state =
            AppleFoundationAdapterBindingState.loaded(
                descriptorID: "test.v1")
        XCTAssertTrue(state.isAdapterActive)
        XCTAssertEqual(
            state.activeAdapterID, "test.v1")
    }

    func test_replacedIsActiveWithCurrentID() {
        let state =
            AppleFoundationAdapterBindingState.replaced(
                previous: "test.v1",
                current: "test.v2")
        XCTAssertTrue(state.isAdapterActive)
        XCTAssertEqual(
            state.activeAdapterID, "test.v2")
    }

    func test_unloadedIsInactive() {
        let state =
            AppleFoundationAdapterBindingState.unloaded(
                previous: "test.v1")
        XCTAssertFalse(state.isAdapterActive)
        XCTAssertNil(state.activeAdapterID)
    }

    // MARK: - Binding state Codable

    func test_bindingStateCodableRoundTrip() throws {
        let states: [AppleFoundationAdapterBindingState] =
            [
                .notLoaded,
                .loaded(descriptorID: "a"),
                .replaced(previous: "a", current: "b"),
                .unloaded(previous: "a"),
            ]
        for state in states {
            let data = try JSONEncoder().encode(state)
            let decoded = try JSONDecoder().decode(
                AppleFoundationAdapterBindingState.self,
                from: data)
            XCTAssertEqual(decoded, state)
        }
    }

    // MARK: - Registry

    func test_emptyRegistry() {
        let registry =
            AppleFoundationAdapterRegistry()
        XCTAssertEqual(registry.count, 0)
        XCTAssertNil(
            registry.descriptor(for: "anything"))
    }

    func test_registerDescriptorImmutable() {
        let registry =
            AppleFoundationAdapterRegistry()
        let descriptor =
            AppleFoundationAdapterDescriptor(
                adapterID: "test.v1",
                version: "v1",
                trainingProvenanceHash: "sha256:zzz",
                purpose: "test")
        let updated = registry.registering(descriptor)
        // Original registry unchanged.
        XCTAssertEqual(registry.count, 0)
        // Updated has the descriptor.
        XCTAssertEqual(updated.count, 1)
        XCTAssertEqual(
            updated.descriptor(for: "test.v1"),
            descriptor)
    }

    func test_registerDuplicateReplaces() {
        let registry =
            AppleFoundationAdapterRegistry()
        let v1 = AppleFoundationAdapterDescriptor(
            adapterID: "test.v1",
            version: "v1",
            trainingProvenanceHash: "sha256:aaa",
            purpose: "v1")
        let v1Updated =
            AppleFoundationAdapterDescriptor(
                adapterID: "test.v1",
                version: "v1.1",
                trainingProvenanceHash: "sha256:bbb",
                purpose: "v1.1")
        let updated = registry
            .registering(v1)
            .registering(v1Updated)
        XCTAssertEqual(updated.count, 1)
        XCTAssertEqual(
            updated.descriptor(for: "test.v1")?.version,
            "v1.1")
    }

    func test_removingDescriptorImmutable() {
        let descriptor =
            AppleFoundationAdapterDescriptor(
                adapterID: "test.v1",
                version: "v1",
                trainingProvenanceHash: "sha256:zzz",
                purpose: "test")
        let registry =
            AppleFoundationAdapterRegistry(
                descriptors: [descriptor])
        let updated = registry.removing(
            adapterID: "test.v1")
        XCTAssertEqual(registry.count, 1)
        XCTAssertEqual(updated.count, 0)
        XCTAssertNil(
            updated.descriptor(for: "test.v1"))
    }

    func test_removingMissingIsNoOp() {
        let registry =
            AppleFoundationAdapterRegistry()
        let updated = registry.removing(
            adapterID: "ghost")
        XCTAssertEqual(updated.count, 0)
    }

    // MARK: - Registry Codable

    func test_registryCodableRoundTrip() throws {
        let descriptor =
            AppleFoundationAdapterDescriptor(
                adapterID: "test.v1",
                version: "v1",
                trainingProvenanceHash: "sha256:zzz",
                purpose: "test")
        let registry =
            AppleFoundationAdapterRegistry(
                descriptors: [descriptor])
        let data = try JSONEncoder().encode(registry)
        let decoded = try JSONDecoder().decode(
            AppleFoundationAdapterRegistry.self,
            from: data)
        XCTAssertEqual(decoded, registry)
    }
}
