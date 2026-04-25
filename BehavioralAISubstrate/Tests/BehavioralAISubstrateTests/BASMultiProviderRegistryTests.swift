import XCTest
@testable import BASOrgan
@testable import BASChatCompletionsAdapter

/// M211 — multi-provider co-registration test.
///
/// ## What this proves
///
/// Pre-M211 every test registered exactly one provider into a
/// `BASOrganRegistry` (deterministic, OR Apple FM, OR
/// ChatCompletions). M208 added the third adapter
/// implementation, so the protocol-portability claim now has
/// three working clients. M211 closes the last open question:
/// can a host register ALL THREE simultaneously and rely on the
/// registry's "prefer most-recent on-device, then fall back" rule
/// to route correctly?
///
/// Specifically:
///   1. Register a remote (`runsOnDevice = false`) adapter +
///      a deterministic (`runsOnDevice = true`) adapter. Resolve
///      for `.scout` → registry must pick the deterministic
///      (on-device wins).
///   2. Unregister the on-device adapter. Resolve for `.scout` →
///      registry must fall through to the remote adapter.
///   3. Re-register the on-device adapter. Resolve again →
///      back to the on-device adapter.
///
/// All offline. No real Apple FM, no real network. The
/// deterministic adapter stands in for any on-device provider
/// (Apple FM in production); the ChatCompletions adapter (with
/// its remote endpoint not actually called) stands in for any
/// remote provider.
final class BASMultiProviderRegistryTests: XCTestCase {

    private let remoteEndpoint =
        BASChatCompletionsOrganAdapter.Endpoint(
            url: URL(string: "https://stub.example.com/v1/chat/completions")!,
            headers: ["Authorization": "Bearer test-key"],
            model: "test-model")

    private func makeRemote() -> BASChatCompletionsOrganAdapter {
        BASChatCompletionsOrganAdapter(
            endpoint: remoteEndpoint,
            providerID: "remote.openai-compat",
            providerName: "Remote (test)")
    }

    private func makeOnDevice()
        -> BASOrganDeterministicAdapter
    {
        BASOrganDeterministicAdapter(
            providerID: "ondevice.deterministic",
            providerName: "On-device (test)")
    }

    // MARK: - 1. Most-recent on-device wins

    func testRegistryPrefersOnDeviceWhenBothPresent() async throws {
        let registry = BASOrganRegistry()
        // Register remote first; on-device second.
        await registry.register(makeRemote())
        await registry.register(makeOnDevice())

        let resolved = try await registry.adapter(for: .scout)
        XCTAssertEqual(
            resolved.descriptor.providerID,
            "ondevice.deterministic",
            "on-device adapter MUST win when both providers " +
            "are registered. Got " +
            "\(resolved.descriptor.providerID)")
        XCTAssertTrue(resolved.descriptor.runsOnDevice)
    }

    /// Same as above but reversed registration order. The rule
    /// is "most-recent ON-DEVICE", not "most-recent overall".
    func testRegistryPrefersOnDeviceRegardlessOfRegistrationOrder()
        async throws
    {
        let registry = BASOrganRegistry()
        // On-device first; remote second.
        await registry.register(makeOnDevice())
        await registry.register(makeRemote())

        let resolved = try await registry.adapter(for: .scout)
        XCTAssertEqual(
            resolved.descriptor.providerID,
            "ondevice.deterministic",
            "even when remote registers later, on-device wins")
    }

    // MARK: - 2. Fallback to remote when on-device unregistered

    func testFallbackToRemoteWhenOnDeviceUnregistered()
        async throws
    {
        let registry = BASOrganRegistry()
        let onDevice = makeOnDevice()
        let remote = makeRemote()
        await registry.register(remote)
        await registry.register(onDevice)

        // Pre-unregister: on-device wins.
        let pre = try await registry.adapter(for: .scout)
        XCTAssertEqual(
            pre.descriptor.providerID,
            "ondevice.deterministic")

        // Unregister on-device.
        try await registry.unregister(
            providerID: "ondevice.deterministic")

        // Now remote wins (any-provider fallback).
        let post = try await registry.adapter(for: .scout)
        XCTAssertEqual(
            post.descriptor.providerID,
            "remote.openai-compat",
            "after on-device unregister, remote MUST be the " +
            "any-provider fallback")
        XCTAssertFalse(post.descriptor.runsOnDevice)
    }

    /// Re-register the on-device adapter — registry returns to
    /// the on-device-wins state.
    func testReRegisteringOnDeviceRestoresPreference()
        async throws
    {
        let registry = BASOrganRegistry()
        await registry.register(makeRemote())
        await registry.register(makeOnDevice())

        try await registry.unregister(
            providerID: "ondevice.deterministic")
        let afterUnregister = try await registry
            .adapter(for: .scout)
        XCTAssertEqual(
            afterUnregister.descriptor.providerID,
            "remote.openai-compat",
            "remote pickup confirmed before re-register")

        // Re-register on-device.
        await registry.register(makeOnDevice())

        let afterReRegister = try await registry
            .adapter(for: .scout)
        XCTAssertEqual(
            afterReRegister.descriptor.providerID,
            "ondevice.deterministic",
            "after on-device re-register, registry must return " +
            "to on-device preference")
    }

    // MARK: - 3. Per-role routing

    /// Register an on-device adapter that supports only scout
    /// + a remote adapter that supports both. For `.core` the
    /// registry can't pick the on-device one (role unsupported),
    /// so it must fall through to the remote.
    func testRegistryFallsThroughOnRoleMismatch() async throws {
        let registry = BASOrganRegistry()
        let scoutOnly = BASOrganDeterministicAdapter(
            providerID: "ondevice.scout-only",
            providerName: "Scout-only on-device",
            supportedRoles: [.scout])
        await registry.register(scoutOnly)
        await registry.register(makeRemote())

        // .scout → on-device wins (it supports it).
        let scoutResolved = try await registry.adapter(for: .scout)
        XCTAssertEqual(
            scoutResolved.descriptor.providerID,
            "ondevice.scout-only")

        // .core → on-device doesn't support it; remote wins.
        let coreResolved = try await registry.adapter(for: .core)
        XCTAssertEqual(
            coreResolved.descriptor.providerID,
            "remote.openai-compat",
            "for .core the on-device adapter doesn't qualify; " +
            "remote MUST win as any-provider fallback")
    }

    // MARK: - 4. End-to-end mixed routing through the resolved adapter

    /// Resolve through registry, drive the deterministic adapter
    /// to produce a draft, verify provenance flows through. The
    /// on-device adapter doesn't go to the network — proves the
    /// "prefer on-device" rule short-circuits the remote path.
    func testResolvedOnDeviceAdapterProducesDeterministicDraft()
        async throws
    {
        let registry = BASOrganRegistry()
        await registry.register(makeRemote())
        await registry.register(makeOnDevice())

        let resolved = try await registry.adapter(for: .scout)
        let draft = try await resolved.draft(
            BASOrganRequest(
                requestID: "multi-1",
                role: .scout,
                preset: .scout,
                instruction: "ping"))
        XCTAssertEqual(
            draft.providerID, "ondevice.deterministic",
            "draft.providerID must match the resolved adapter's " +
            "providerID — proves the registry didn't silently " +
            "route to the wrong adapter")
        XCTAssertFalse(draft.body.isEmpty)
    }

    // MARK: - 5. Empty registry → typed error

    func testEmptyRegistryThrowsNoAdapterForRole() async {
        let registry = BASOrganRegistry()
        do {
            _ = try await registry.adapter(for: .scout)
            XCTFail("expected noAdapterForRole")
        } catch BASOrganRegistry.RegistryError
            .noAdapterForRole(let r)
        {
            XCTAssertEqual(r, .scout)
        } catch {
            XCTFail("unexpected: \(error)")
        }
    }
}
