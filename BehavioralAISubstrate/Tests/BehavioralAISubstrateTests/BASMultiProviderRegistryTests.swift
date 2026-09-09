import XCTest
@testable import BASOrgan
@testable import BASChatCompletionsAdapter

/// Multi-provider registration remains storage; execution requires an exact ID.
final class BASMultiProviderRegistryTests: XCTestCase {
    private let remoteEndpoint = BASChatCompletionsOrganAdapter.Endpoint(
        url: URL(string: "https://stub.example.com/v1/chat/completions")!,
        headers: ["Authorization": "Bearer test-key"],
        model: "test-model")

    private func makeRemote() -> BASChatCompletionsOrganAdapter {
        BASChatCompletionsOrganAdapter(
            endpoint: remoteEndpoint,
            providerID: "remote.openai-compat",
            providerName: "Remote (test)")
    }

    private func makeOnDevice() -> BASOrganDeterministicAdapter {
        BASOrganDeterministicAdapter(
            providerID: "ondevice.deterministic",
            providerName: "On-device (test)")
    }

    func testCoRegisteredProvidersResolveOnlyByExactID() async throws {
        for reverse in [false, true] {
            let registry = BASOrganRegistry()
            let adapters: [any BASOrganAdapter] = reverse
                ? [makeOnDevice(), makeRemote()]
                : [makeRemote(), makeOnDevice()]
            for adapter in adapters { await registry.register(adapter) }

            let local = try await registry.adapter(
                providerID: "ondevice.deterministic")
            let remote = try await registry.adapter(
                providerID: "remote.openai-compat")
            XCTAssertEqual(local.descriptor.providerID, "ondevice.deterministic")
            XCTAssertEqual(remote.descriptor.providerID, "remote.openai-compat")
            XCTAssertTrue(local.descriptor.runsOnDevice)
            XCTAssertFalse(remote.descriptor.runsOnDevice)
        }
    }

    func testRemovingSelectedProviderDoesNotFallBack() async throws {
        let registry = BASOrganRegistry()
        await registry.register(makeRemote())
        await registry.register(makeOnDevice())
        try await registry.unregister(providerID: "ondevice.deterministic")

        do {
            _ = try await registry.adapter(providerID: "ondevice.deterministic")
            XCTFail("removed provider must not fall back to remote")
        } catch BASOrganRegistry.RegistryError.unknownProvider(let id) {
            XCTAssertEqual(id, "ondevice.deterministic")
        }
        let remote = try await registry.adapter(providerID: "remote.openai-compat")
        XCTAssertEqual(remote.descriptor.providerID, "remote.openai-compat")
    }

    func testExactProviderRoleCapabilityIsObservedWithoutElection()
        async throws
    {
        let registry = BASOrganRegistry()
        await registry.register(BASOrganDeterministicAdapter(
            providerID: "ondevice.scout-only",
            providerName: "Scout-only on-device",
            supportedRoles: [.scout]))
        await registry.register(makeRemote())

        let scoutOnly = try await registry.adapter(
            providerID: "ondevice.scout-only")
        XCTAssertEqual(scoutOnly.descriptor.supportedRoles, [.scout])
        let remote = try await registry.adapter(
            providerID: "remote.openai-compat")
        XCTAssertEqual(remote.descriptor.supportedRoles, [.scout, .core])
    }

    func testExactOnDeviceAdapterProducesDeterministicDraft() async throws {
        let registry = BASOrganRegistry()
        await registry.register(makeRemote())
        await registry.register(makeOnDevice())

        let adapter = try await registry.adapter(
            providerID: "ondevice.deterministic")
        let draft = try await adapter.draft(BASOrganRequest(
            requestID: "multi-1",
            role: .scout,
            preset: .scout,
            instruction: "ping"))
        XCTAssertEqual(draft.providerID, "ondevice.deterministic")
        XCTAssertFalse(draft.body.isEmpty)
    }
}
