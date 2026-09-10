import XCTest
import BASOrgan
import BASMLXAdapter
@testable import QinaoMLX
@testable import QinaoLoop

/// M222 — coverage for the public `QinaoMLX` façade.
///
/// Real model load + endpoint exercise lives in the env-gated BAS
/// E2E tests (`MLXOrganAdapterE2ETests` with `QINAO_MLX_E2E=1`).
/// These tests pin the Qinao-side API shape that is callable
/// without ever touching Hugging Face:
///
///   - `QinaoMLXModel` covers the three certified Gemma entries
///     the substrate ships (M236: Gemma 4 e4b + e2b + Gemma 3 4B).
///   - Each model has a stable display name and providerID.
///   - The no-model factory follows the BAS production manifest.
///   - `Codable` round-trips so hosts can persist user choice.
final class QinaoMLXEndpointTests: XCTestCase {

    private actor LoadSpy {
        struct Call: Sendable, Equatable {
            let modelID: String
            let providerID: String
            let enforcesAdmission: Bool
            let activeHardCapBytes: Int?
        }

        private(set) var calls: [Call] = []

        func record(
            modelID: String,
            providerID: String,
            enforcesAdmission: Bool,
            activeHardCapBytes: Int?
        ) {
            calls.append(.init(
                modelID: modelID,
                providerID: providerID,
                enforcesAdmission: enforcesAdmission,
                activeHardCapBytes: activeHardCapBytes))
        }
    }

    private enum InjectedLoadError: Error, Equatable {
        case failed
    }

    private func endpointProviderID(
        _ endpoint: any QinaoOrganEndpoint
    ) throws -> String {
        let registryEndpoint = try XCTUnwrap(
            endpoint as? BASOrganRegistryEndpoint)
        return try XCTUnwrap(
            registryEndpoint.providerID,
            "constructed registry endpoint must bind a provider ID")
    }

    // MARK: - 1. Catalog completeness

    func testAllCasesShipsCertifiedChoicesPlusAlternatives() {
        let cases = QinaoMLXModel.allCases
        // 3 certified Gemma entries + 4 experimental availableAlternatives (Llama/Qwen) = 7.
        XCTAssertEqual(cases.count, 7)
        XCTAssertEqual(
            Set(cases),
            [.gemma4E4B, .gemma4E2B, .gemma3_4B,
             .llama3_2_3B, .qwen2_5_3B, .llama3_2_1B, .qwen2_5_1_5B])
    }

    // MARK: - 2. Display + provider identity

    func testDisplayNameMatchesCatalogEntry() {
        let pairs: [(QinaoMLXModel, String)] = [
            (.gemma4E4B, "Gemma 4 E4B (MLX, 4-bit)"),
            (.gemma4E2B, "Gemma 4 E2B (MLX, 4-bit)"),
            (.gemma3_4B, "Gemma 3 4B (MLX, 4-bit)"),
            (.llama3_2_3B, "Llama 3.2 3B (MLX, 4-bit)"),
            (.qwen2_5_3B, "Qwen2.5 3B (MLX, 4-bit)"),
            (.llama3_2_1B, "Llama 3.2 1B (MLX, 4-bit)"),
            (.qwen2_5_1_5B, "Qwen2.5 1.5B (MLX, 4-bit)")
        ]
        for (model, expected) in pairs {
            XCTAssertEqual(
                model.displayName, expected,
                "display name must match catalog for \(model)")
        }
    }

    func testProviderIDsAreUniqueAndStable() {
        let ids = QinaoMLXModel.allCases.map(\.providerID)
        XCTAssertEqual(
            Set(ids).count, ids.count,
            "providerIDs must be unique across QinaoMLXModel cases")
        for id in ids {
            XCTAssertFalse(
                id.isEmpty,
                "providerID must be non-empty (audit logs use it " +
                "as a primary key)")
            XCTAssertTrue(
                id.hasPrefix("mlx."),
                "providerID must carry the mlx. prefix; got \(id)")
        }
    }

    // MARK: - 3. Identifiable + raw values

    func testIdentifiableConformanceMatchesRawValue() {
        for model in QinaoMLXModel.allCases {
            XCTAssertEqual(
                model.id, model.rawValue,
                "id must mirror rawValue for picker stability")
        }
    }

    // MARK: - 4. Codable round-trip

    func testCodableRoundTripPreservesIdentity() throws {
        for model in QinaoMLXModel.allCases {
            let data = try JSONEncoder().encode(model)
            let decoded = try JSONDecoder().decode(
                QinaoMLXModel.self, from: data)
            XCTAssertEqual(
                decoded, model,
                "Codable round-trip must preserve identity for " +
                "\(model)")
        }
    }

    // MARK: - 5. Manifest-selected construction

    func testManifestFactoryLoadsOnlyQwenAndBindsItsProviderIdentity() async throws {
        let manifest = BASModelManifestRegistry.productionDefault
        let spy = LoadSpy()

        let endpoint = try await QinaoLoop._makeMLXEndpoint(
            activeHardCapBytes: manifest.peakBytesEstimate,
            loadModel: { adapter, _ in
                await spy.record(
                    modelID: adapter.model.id,
                    providerID: adapter.model.providerID,
                    enforcesAdmission: adapter.memoryPolicy.enforceMemoryAdmission,
                    activeHardCapBytes: adapter.memoryPolicy.activeHardCapBytes)
            })

        let calls = await spy.calls
        XCTAssertEqual(calls, [.init(
            modelID: "mlx-community/Qwen3.5-4B-4bit",
            providerID: "mlx.qwen3_5.4b.4bit",
            enforcesAdmission: true,
            activeHardCapBytes: manifest.peakBytesEstimate)])
        XCTAssertEqual(try endpointProviderID(endpoint), "mlx.qwen3_5.4b.4bit")
    }

    func testExplicitGemmaFactoryStaysExplicitAndLoadsOnlyOnce() async throws {
        let spy = LoadSpy()

        let endpoint = try await QinaoLoop._makeMLXEndpoint(
            selection: .explicit(.gemma4E4B),
            loadModel: { adapter, _ in
                await spy.record(
                    modelID: adapter.model.id,
                    providerID: adapter.model.providerID,
                    enforcesAdmission: adapter.memoryPolicy.enforceMemoryAdmission,
                    activeHardCapBytes: adapter.memoryPolicy.activeHardCapBytes)
            })

        let calls = await spy.calls
        XCTAssertEqual(calls, [.init(
            modelID: "mlx-community/gemma-4-e4b-it-4bit",
            providerID: "mlx.gemma4.e4b.it.4bit",
            enforcesAdmission: false,
            activeHardCapBytes: nil)])
        XCTAssertEqual(try endpointProviderID(endpoint), "mlx.gemma4.e4b.it.4bit")
    }

    func testManifestFactoryCapBoundaryRejectsBeforeLoadWithoutFallback() async throws {
        let manifest = BASModelManifestRegistry.productionDefault
        let acceptingSpy = LoadSpy()
        _ = try await QinaoLoop._makeMLXEndpoint(
            selection: .manifest(manifest, capBytes: manifest.peakBytesEstimate),
            loadModel: { adapter, _ in
                await acceptingSpy.record(
                    modelID: adapter.model.id,
                    providerID: adapter.model.providerID,
                    enforcesAdmission: adapter.memoryPolicy.enforceMemoryAdmission,
                    activeHardCapBytes: adapter.memoryPolicy.activeHardCapBytes)
            })
        let acceptedCalls = await acceptingSpy.calls
        XCTAssertEqual(acceptedCalls.count, 1)

        for cap in [manifest.peakBytesEstimate - 1, 0, -1] {
            let refusingSpy = LoadSpy()
            do {
                _ = try await QinaoLoop._makeMLXEndpoint(
                    selection: .manifest(manifest, capBytes: cap),
                    loadModel: { adapter, _ in
                        await refusingSpy.record(
                            modelID: adapter.model.id,
                            providerID: adapter.model.providerID,
                            enforcesAdmission: adapter.memoryPolicy.enforceMemoryAdmission,
                            activeHardCapBytes: adapter.memoryPolicy.activeHardCapBytes)
                    })
                XCTFail("cap \(cap) must refuse the manifest model")
            } catch BASOrganError.providerUnavailable(let reason) {
                XCTAssertEqual(reason, "manifest-model-exceeds-active-cap")
            } catch {
                XCTFail("expected providerUnavailable for cap \(cap), got \(error)")
            }
            let refusedCalls = await refusingSpy.calls
            XCTAssertTrue(refusedCalls.isEmpty)
        }
    }

    func testUnknownManifestRejectsBeforeLoadWithoutFallback() async {
        let manifest = BASModelCapabilityManifest(
            modelID: "mlx-community/unknown-task6-model",
            architecture: .trimmableAttention,
            draft: .none,
            quantBits: 4,
            peakBytesEstimate: 1,
            contextCapTokens: 1)
        let spy = LoadSpy()

        do {
            _ = try await QinaoLoop._makeMLXEndpoint(
                selection: .manifest(manifest, capBytes: 1),
                loadModel: { adapter, _ in
                    await spy.record(
                        modelID: adapter.model.id,
                        providerID: adapter.model.providerID,
                        enforcesAdmission: adapter.memoryPolicy.enforceMemoryAdmission,
                        activeHardCapBytes: adapter.memoryPolicy.activeHardCapBytes)
                })
            XCTFail("an unknown manifest model must be refused")
        } catch let error as MLXModelCatalog.LookupError {
            XCTAssertEqual(
                error,
                .unknownModelID("mlx-community/unknown-task6-model"))
        } catch {
            XCTFail("expected unknown-model lookup error, got \(error)")
        }
        let calls = await spy.calls
        XCTAssertTrue(calls.isEmpty)
    }

    func testInjectedLoadErrorPropagatesWithoutSecondLoad() async {
        let manifest = BASModelManifestRegistry.productionDefault
        let spy = LoadSpy()

        do {
            _ = try await QinaoLoop._makeMLXEndpoint(
                selection: .manifest(manifest, capBytes: manifest.peakBytesEstimate),
                loadModel: { adapter, _ in
                    await spy.record(
                        modelID: adapter.model.id,
                        providerID: adapter.model.providerID,
                        enforcesAdmission: adapter.memoryPolicy.enforceMemoryAdmission,
                        activeHardCapBytes: adapter.memoryPolicy.activeHardCapBytes)
                    throw InjectedLoadError.failed
                })
            XCTFail("the injected load error must propagate")
        } catch let error as InjectedLoadError {
            XCTAssertEqual(error, .failed)
        } catch {
            XCTFail("expected injected load error, got \(error)")
        }
        let calls = await spy.calls
        XCTAssertEqual(calls.count, 1)
    }

    func testMaxThroughputModelIsSpeculativeOptimal() {
        XCTAssertEqual(QinaoMLXModel.speculativeOptimal, .llama3_2_3B)
        XCTAssertEqual(
            QinaoMLXModel.speculativeOptimal.speculativeDraft,
            .llama3_2_1B,
            "max-throughput endpoint must target the certified " +
            "Llama 3B to 1B speculative lane")
    }

    // MARK: - 6. Certification tier (B — defaults certified, alternatives experimental)

    func testCertificationTierMatchesCatalogTiering() {
        let certified: Set<QinaoMLXModel> = [.gemma4E4B, .gemma4E2B, .gemma3_4B]
        for model in QinaoMLXModel.allCases {
            let expected = certified.contains(model) ? "certified" : "experimental"
            XCTAssertEqual(
                model.certificationTier, expected,
                "\(model) tier must be \(expected) (certified entries vs experimental alternatives)")
        }
        XCTAssertTrue(
            QinaoMLXModel.allCases.contains { $0.certificationTier == "certified" },
            "at least one certified model must exist")
        XCTAssertTrue(
            QinaoMLXModel.allCases.contains { $0.certificationTier == "experimental" },
            "at least one experimental alternative must exist")
    }
}
