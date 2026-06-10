import XCTest
@testable import BASOrgan
import BASRuntimeCore

/// 结构大重构 — Phase D: the OPT-IN provider-matrix routing seam on `BASOrganRegistry`.
///
/// `.registryDefault` must be byte-identical to the pre-existing `adapter(for:)`; `.neuralMatrix` opts into the
/// observation-class `BASNeuralProviderMatrix` ranking and can therefore differ from LIFO; and the opt-in must
/// fail SAFE (never resolve to less than the default would).
final class BASProviderRoutingTests: XCTestCase {

    /// A stub adapter with a fully-configurable descriptor (the deterministic adapter fixes kind/tier).
    private struct StubAdapter: BASOrganAdapter {
        let descriptor: BASOrganDescriptor
        func draft(_ request: BASOrganRequest) async throws -> BASOrganDraft {
            throw BASOrganError.unsupportedRole(request.role)   // resolution-only stub
        }
        func currentCapacity() async -> BASOrganCapacity { .unlimited }
    }

    private func stub(
        _ providerID: String,
        onDevice: Bool = true,
        roles: Set<BASOrganRole> = [.scout, .core],
        tier: BASCertificationTier? = nil,
        kind: BASProviderKind? = .mlx
    ) -> StubAdapter {
        StubAdapter(descriptor: BASOrganDescriptor(
            providerID: providerID,
            providerName: providerID,
            supportsStreaming: false,
            maxInputTokens: 4096,
            maxOutputTokens: 4096,
            runsOnDevice: onDevice,
            supportedRoles: roles,
            providerKind: kind,
            certificationTier: tier))
    }

    // MARK: - 1. registryDefault == plain resolution (byte-identical)

    func testRegistryDefaultRoutingMatchesPlainResolution() async throws {
        let registry = BASOrganRegistry()
        await registry.register(stub("a.v1"))
        await registry.register(stub("b.v1"))   // most-recent on-device → LIFO winner

        let plain = try await registry.adapter(for: .core)
        let routed = try await registry.adapter(for: .core, routing: .registryDefault)
        XCTAssertEqual(plain.descriptor.providerID, routed.descriptor.providerID,
            ".registryDefault must resolve identically to adapter(for:) — byte-identical default")
        XCTAssertEqual(routed.descriptor.providerID, "b.v1", "LIFO picks the most-recent on-device")
    }

    // MARK: - 2. neuralMatrix can OVERRIDE LIFO (the whole point of the opt-in)

    func testNeuralMatrixPreferCertifiedOverridesLIFO() async throws {
        let registry = BASOrganRegistry()
        // Certified registered FIRST, experimental registered LAST → LIFO would pick the experimental.
        await registry.register(stub("certified.v1", tier: .certified))
        await registry.register(stub("experimental.v1", tier: .experimental))

        let lifo = try await registry.adapter(for: .core)
        XCTAssertEqual(lifo.descriptor.providerID, "experimental.v1",
            "the default LIFO resolution picks the most-recently-registered (experimental)")

        let routed = try await registry.adapter(
            for: .core, routing: .neuralMatrix(preferCertified: true))
        XCTAssertEqual(routed.descriptor.providerID, "certified.v1",
            ".neuralMatrix(preferCertified:) overrides LIFO and resolves the certified provider")
    }

    func testNeuralMatrixPrefersOnDeviceOverOffDevice() async throws {
        let registry = BASOrganRegistry()
        await registry.register(stub("local.v1", onDevice: true))
        await registry.register(stub("remote.v1", onDevice: false, kind: .remote))

        let routed = try await registry.adapter(for: .core, routing: .neuralMatrix())
        XCTAssertEqual(routed.descriptor.providerID, "local.v1",
            "the matrix's dominant on-device factor (+1000) resolves the local provider")
        XCTAssertTrue(routed.descriptor.runsOnDevice)
    }

    // MARK: - 3. Fail-safe — opt-in never resolves to less than the default

    func testNeuralMatrixThrowsWhenNoCandidateSupportsRole() async {
        let registry = BASOrganRegistry()
        await registry.register(stub("scout.only", roles: [.scout]))
        do {
            _ = try await registry.adapter(for: .core, routing: .neuralMatrix())
            XCTFail("expected noAdapterForRole (fail-safe to default behaviour)")
        } catch BASOrganRegistry.RegistryError.noAdapterForRole(let r) {
            XCTAssertEqual(r, .core)
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }
}
