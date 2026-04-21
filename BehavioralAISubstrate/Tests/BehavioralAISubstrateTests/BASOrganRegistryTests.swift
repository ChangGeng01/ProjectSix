import XCTest
@testable import BASRuntimeCore
@testable import BASOrgan

/// Tests for the organ registry's resolution rules.
///
/// Registry rules (see `BASOrganRegistry`):
///   1. Prefer most-recently-registered on-device adapter for the role.
///   2. Fall back to any registered adapter supporting the role.
///   3. If nothing supports the role, throw `noAdapterForRole`.
///
/// These tests pin all three paths plus the re-registration
/// semantics (same providerID overwrites, order preserved).
final class BASOrganRegistryTests: XCTestCase {

    func testResolvesMostRecentOnDeviceAdapter() async throws {
        let registry = BASOrganRegistry()

        let older = BASOrganDeterministicAdapter(
            providerID: "p.older",
            providerName: "Older")
        let newer = BASOrganDeterministicAdapter(
            providerID: "p.newer",
            providerName: "Newer")

        await registry.register(older)
        await registry.register(newer)

        let chosen = try await registry.adapter(for: .scout)
        XCTAssertEqual(chosen.descriptor.providerID, "p.newer")
    }

    func testFallsBackToNonOnDeviceAdapterWhenNeeded() async throws {
        let registry = BASOrganRegistry()
        let remote = RemoteStubAdapter(
            providerID: "remote.llm.v1",
            supportedRoles: [.scout, .core])
        await registry.register(remote)

        let chosen = try await registry.adapter(for: .core)
        XCTAssertEqual(chosen.descriptor.providerID, "remote.llm.v1")
        XCTAssertFalse(chosen.descriptor.runsOnDevice)
    }

    func testPrefersOnDeviceOverRemoteEvenIfRemoteIsNewer() async throws {
        let registry = BASOrganRegistry()
        let onDevice = BASOrganDeterministicAdapter(
            providerID: "local.v1")
        let remote = RemoteStubAdapter(
            providerID: "remote.v1",
            supportedRoles: [.scout, .core])

        await registry.register(onDevice)
        await registry.register(remote) // newer, but not on-device

        let chosen = try await registry.adapter(for: .scout)
        XCTAssertEqual(chosen.descriptor.providerID, "local.v1")
    }

    func testThrowsWhenNoAdapterSupportsRole() async {
        let registry = BASOrganRegistry()
        let scoutOnly = BASOrganDeterministicAdapter(
            providerID: "scout.only",
            supportedRoles: [.scout])
        await registry.register(scoutOnly)

        do {
            _ = try await registry.adapter(for: .core)
            XCTFail("expected noAdapterForRole")
        } catch BASOrganRegistry.RegistryError.noAdapterForRole(let r) {
            XCTAssertEqual(r, .core)
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testReregisteringSameProviderIDOverwrites() async throws {
        let registry = BASOrganRegistry()
        let first = BASOrganDeterministicAdapter(
            providerID: "hot.v1",
            providerName: "First",
            supportedRoles: [.scout])
        let second = BASOrganDeterministicAdapter(
            providerID: "hot.v1",
            providerName: "Second",
            supportedRoles: [.scout, .core])

        await registry.register(first)
        await registry.register(second)

        let count = await registry.count()
        XCTAssertEqual(count, 1)
        let descs = await registry.descriptors()
        XCTAssertEqual(descs.first?.providerName, "Second")
    }

    func testUnregisterRemovesEntry() async throws {
        let registry = BASOrganRegistry()
        let adapter = BASOrganDeterministicAdapter(providerID: "going")
        await registry.register(adapter)

        try await registry.unregister(providerID: "going")

        let count = await registry.count()
        XCTAssertEqual(count, 0)
        do {
            _ = try await registry.adapter(for: .scout)
            XCTFail("expected noAdapterForRole")
        } catch BASOrganRegistry.RegistryError.noAdapterForRole {
            // ok
        } catch {
            XCTFail("unexpected error: \(error)")
        }
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

    func testHasRoleIsAwareOfRegistrations() async {
        let registry = BASOrganRegistry()
        let scoutOnly = BASOrganDeterministicAdapter(
            providerID: "s", supportedRoles: [.scout])
        await registry.register(scoutOnly)
        let hasScout = await registry.hasRole(.scout)
        let hasCore = await registry.hasRole(.core)
        XCTAssertTrue(hasScout)
        XCTAssertFalse(hasCore)
    }
}

// MARK: - Remote stub (runsOnDevice = false)

/// A tiny adapter that claims to be off-device — used only to
/// exercise the registry's "prefer on-device" rule. It returns a
/// constant body; no cryptography, no state.
private actor RemoteStubAdapter: BASOrganAdapter {
    nonisolated let descriptor: BASOrganDescriptor

    init(
        providerID: String,
        supportedRoles: Set<BASOrganRole>
    ) {
        self.descriptor = BASOrganDescriptor(
            providerID: providerID,
            providerName: "Remote Stub",
            supportsStreaming: false,
            maxInputTokens: 1024,
            maxOutputTokens: 1024,
            runsOnDevice: false,
            supportedRoles: supportedRoles)
    }

    func draft(_ request: BASOrganRequest) async throws -> BASOrganDraft {
        BASOrganDraft(
            requestID: request.requestID,
            providerID: descriptor.providerID,
            role: request.role,
            body: "remote-stub",
            inputTokensEstimated: 0,
            outputTokensEstimated: 0,
            producedAt: Date(),
            traceID: "remote-stub")
    }

    func currentCapacity() async -> BASOrganCapacity { .unlimited }
}
