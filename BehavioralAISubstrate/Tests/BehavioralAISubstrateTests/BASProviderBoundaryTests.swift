import BASMLXAdapter
import BASOrgan
import XCTest

private enum SiliconW0RegistryProbeError: Error {
    case missingExplicitProviderIDLookup
    case missingLegacyRoleLookup
}

private protocol SiliconW0ExplicitProviderIDLookupProbe: Actor {
    func adapter(providerID: String) async throws -> any BASOrganAdapter
}

private extension SiliconW0ExplicitProviderIDLookupProbe {
    func adapter(providerID: String) async throws -> any BASOrganAdapter {
        throw SiliconW0RegistryProbeError.missingExplicitProviderIDLookup
    }
}

extension BASOrganRegistry: SiliconW0ExplicitProviderIDLookupProbe {}

private protocol SiliconW0LegacyRoleLookupProbe: Actor {
    func adapter(for role: BASOrganRole) async throws -> any BASOrganAdapter
}

private extension SiliconW0LegacyRoleLookupProbe {
    func adapter(for role: BASOrganRole) async throws -> any BASOrganAdapter {
        throw SiliconW0RegistryProbeError.missingLegacyRoleLookup
    }
}

extension BASOrganRegistry: SiliconW0LegacyRoleLookupProbe {}

/// Silicon W0 freeze for registry routing and model-default ownership.
final class BASProviderBoundaryTests: XCTestCase {
    func testRegistryResolvesOnlyAnExplicitProviderID() async {
        var violations: [String] = []
        let registry = BASOrganRegistry()
        await registry.register(BASOrganDeterministicAdapter(providerID: "provider-a"))
        await registry.register(BASOrganDeterministicAdapter(providerID: "provider-b"))

        let explicit = registry as any SiliconW0ExplicitProviderIDLookupProbe
        do {
            let selected = try await explicit.adapter(providerID: "provider-a")
            if selected.descriptor.providerID != "provider-a" {
                violations.append("execution.plan-provider-router.explicit-provider-id-mismatch")
            }
            do {
                _ = try await explicit.adapter(providerID: "missing")
                violations.append("execution.plan-provider-router.explicit-provider-id-accepted-missing")
            } catch BASOrganRegistry.RegistryError.unknownProvider(let id) {
                if id != "missing" {
                    violations.append("execution.plan-provider-router.explicit-provider-id-wrong-error")
                }
            } catch {
                violations.append("execution.plan-provider-router.explicit-provider-id-wrong-error")
            }
        } catch SiliconW0RegistryProbeError.missingExplicitProviderIDLookup {
            violations.append("execution.plan-provider-router.missing-explicit-provider-id")
        } catch {
            violations.append("execution.plan-provider-router.explicit-provider-id-wrong-error")
        }

        let forward = BASOrganRegistry()
        await forward.register(BASOrganDeterministicAdapter(providerID: "provider-a"))
        await forward.register(BASOrganDeterministicAdapter(providerID: "provider-b"))
        let reverse = BASOrganRegistry()
        await reverse.register(BASOrganDeterministicAdapter(providerID: "provider-b"))
        await reverse.register(BASOrganDeterministicAdapter(providerID: "provider-a"))

        do {
            let lhs = try await (forward as any SiliconW0LegacyRoleLookupProbe)
                .adapter(for: .scout)
            let rhs = try await (reverse as any SiliconW0LegacyRoleLookupProbe)
                .adapter(for: .scout)
            violations.append("execution.plan-provider-router.role-ranking")
            if lhs.descriptor.providerID != rhs.descriptor.providerID {
                violations.append("execution.plan-provider-router.lifo-registry")
            }
        } catch SiliconW0RegistryProbeError.missingLegacyRoleLookup {
            // Desired final surface: no role-selected registry API.
        } catch {
            violations.append("execution.plan-provider-router.role-ranking")
        }

        XCTAssertTrue(
            violations.isEmpty,
            "SILICON-W0-VIOLATIONS \(violations.sorted())")
    }

    func testProductionDefaultComesFromManifestOnly() {
        let manifestDefaultID = BASModelManifestRegistry.productionDefault.modelID
        XCTAssertEqual(
            manifestDefaultID,
            BASModelManifestRegistry.qwen35_4B_4bit.modelID)

        let catalogDefaultIDs = MLXModelCatalog.defaultEntries.map(\.id)
        let catalogRecommendationID = MLXModelCatalog.recommendedDefault(
            forActiveHardCapBytes: Int.max
        ).id

        var violations: [String] = []
        if catalogDefaultIDs != [manifestDefaultID] {
            violations.append("model.manifest-invocation.catalog-default")
        }
        if catalogRecommendationID != manifestDefaultID {
            violations.append("model.manifest-invocation.competing-recommendation")
        }

        XCTAssertTrue(
            violations.isEmpty,
            "SILICON-W0-VIOLATIONS \(violations.sorted())")
    }
}
