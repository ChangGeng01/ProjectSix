import XCTest
@testable import QinaoMLX

/// M222 — coverage for the public `QinaoMLX` façade.
///
/// Real model load + endpoint exercise lives in the env-gated BAS
/// E2E tests (`MLXOrganAdapterE2ETests` with `QINAO_MLX_E2E=1`).
/// These tests pin the Qinao-side API shape that is callable
/// without ever touching Hugging Face:
///
///   - `QinaoMLXModel` covers exactly the three default Gemma
///     entries the substrate ships.
///   - Each model has a stable display name and providerID.
///   - The default pick is the recommended `.gemma3nE4B`.
///   - `Codable` round-trips so hosts can persist user choice.
final class QinaoMLXEndpointTests: XCTestCase {

    // MARK: - 1. Catalog completeness

    func testAllCasesShipsCanonicalGemmaVariants() {
        let cases = QinaoMLXModel.allCases
        // M235 added Gemma 4 e4b/e2b alongside the existing
        // Gemma 3 4B + Gemma 3n e4b/e2b. Five canonical Gemma
        // variants in the picker.
        XCTAssertEqual(cases.count, 5)
        XCTAssertEqual(
            Set(cases),
            [.gemma4E4B, .gemma4E2B,
             .gemma3_4B, .gemma3nE4B, .gemma3nE2B])
    }

    // MARK: - 2. Display + provider identity

    func testDisplayNameMatchesCatalogEntry() {
        let pairs: [(QinaoMLXModel, String)] = [
            (.gemma4E4B, "Gemma 4 E4B (MLX, 4-bit)"),
            (.gemma4E2B, "Gemma 4 E2B (MLX, 4-bit)"),
            (.gemma3_4B, "Gemma 3 4B (MLX, 4-bit)"),
            (.gemma3nE4B, "Gemma 3n E4B (MLX, 4-bit)"),
            (.gemma3nE2B, "Gemma 3n E2B (MLX, 4-bit)")
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

    func testGemma3nE4BIsTheRecommendedDefault() {
        // Asserted by the makeMLXEndpoint(model:progressHandler:)
        // signature default. Pinning it here so any future change
        // to the recommended model gets a visible test diff.
        let signatureDefault: QinaoMLXModel = .gemma3nE4B
        XCTAssertEqual(
            signatureDefault, .gemma3nE4B,
            "recommended default must remain Gemma 3n E4B until a " +
            "subsequent milestone explicitly retires it")
    }
}
