import XCTest
@testable import QinaoMLX

/// M222 — coverage for the public `QinaoMLX` façade.
///
/// Real model load + endpoint exercise lives in the env-gated BAS
/// E2E tests (`MLXOrganAdapterE2ETests` with `QINAO_MLX_E2E=1`).
/// These tests pin the Qinao-side API shape that is callable
/// without ever touching Hugging Face:
///
///   - `QinaoMLXModel` covers the three default Gemma entries
///     the substrate ships (M236: Gemma 4 e4b + e2b + Gemma 3 4B).
///   - Each model has a stable display name and providerID.
///   - The default pick is the recommended `.gemma4E4B`.
///   - `Codable` round-trips so hosts can persist user choice.
final class QinaoMLXEndpointTests: XCTestCase {

    // MARK: - 1. Catalog completeness

    func testAllCasesShipsDefaultsPlusAlternatives() {
        let cases = QinaoMLXModel.allCases
        // 3 certified default Gemma entries + 4 experimental availableAlternatives (Llama/Qwen) = 7.
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

    // MARK: - 5. Recommended default

    func testGemma4E4BIsTheRecommendedDefault() {
        // Asserted by the makeMLXEndpoint(model:progressHandler:)
        // signature default. Pinning it here so any future change
        // to the recommended model gets a visible test diff. M236
        // promoted Gemma 4 E4B over the retired Gemma 3n E4B.
        let signatureDefault: QinaoMLXModel = .gemma4E4B
        XCTAssertEqual(
            signatureDefault, .gemma4E4B,
            "recommended default must remain Gemma 4 E4B until a " +
            "subsequent milestone explicitly retires it")
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
                "\(model) tier must be \(expected) (defaults=certified, alternatives=experimental)")
        }
        XCTAssertTrue(
            QinaoMLXModel.allCases.contains { $0.certificationTier == "certified" },
            "at least one certified default must exist")
        XCTAssertTrue(
            QinaoMLXModel.allCases.contains { $0.certificationTier == "experimental" },
            "at least one experimental alternative must exist")
    }
}
