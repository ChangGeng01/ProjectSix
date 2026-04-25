import XCTest
@testable import BASOrgan
@testable import BASMLXAdapter

/// M220 — coverage for `MLXOrganAdapter` scaffolding.
///
/// Real model loading + inference is M221. These tests pin the
/// shape of the M220 deliverable:
///
///   - descriptor matches the catalog entry's identity
///   - draft() honestly throws "not loaded yet" with a stable
///     reason code that downstream callers can pattern-match
///   - currentCapacity reports underPressure with a stable reason
///   - the catalog ships exactly the three default Gemma entries
///     hosts can rely on
final class MLXOrganAdapterTests: XCTestCase {

    // MARK: - 1. Descriptor

    func testDescriptorPicksUpCatalogIdentityByDefault() async {
        let adapter = MLXOrganAdapter(
            model: MLXModelCatalog.gemma3n_E4B_4bit)
        XCTAssertEqual(
            adapter.descriptor.providerID,
            "mlx.gemma3n.e4b.it.4bit")
        XCTAssertEqual(
            adapter.descriptor.providerName,
            "Gemma 3n E4B (MLX, 4-bit)")
        XCTAssertTrue(adapter.descriptor.runsOnDevice)
        XCTAssertTrue(adapter.descriptor.supportsStreaming)
        XCTAssertEqual(
            adapter.descriptor.supportedRoles,
            [.scout, .core])
    }

    func testDescriptorOverridesUseExplicitValues() async {
        let adapter = MLXOrganAdapter(
            model: MLXModelCatalog.gemma3_4B_it_4bit,
            providerID: "test.override.v1",
            providerName: "Test Override")
        XCTAssertEqual(
            adapter.descriptor.providerID,
            "test.override.v1")
        XCTAssertEqual(
            adapter.descriptor.providerName,
            "Test Override")
    }

    // MARK: - 2. Draft path is honestly unavailable in M220

    func testDraftThrowsProviderUnavailableWhenModelNotLoaded() async {
        let adapter = MLXOrganAdapter()
        let request = BASOrganRequest(
            requestID: "req-1",
            role: .core,
            preset: .core,
            instruction: "say hi",
            context: [])
        do {
            _ = try await adapter.draft(request)
            XCTFail(
                "fresh adapter must not produce a draft — " +
                "loadModel(progressHandler:) has not been called " +
                "so MLX has no ModelContainer to drive inference")
        } catch BASOrganError.providerUnavailable(let reason) {
            // Either the not-loaded path or the build-unavailable
            // path is acceptable; both are honest "we cannot serve
            // this request" responses.
            XCTAssertTrue(
                reason.contains("mlx-organ-adapter-not-loaded")
                    || reason.contains("MLXLLM framework"),
                "expected a stable not-loaded-or-build reason; " +
                "got: \(reason)")
        } catch {
            XCTFail(
                "expected providerUnavailable but got \(error)")
        }
    }

    func testDraftRejectsUnsupportedRole() async {
        let adapter = MLXOrganAdapter(
            model: MLXModelCatalog.gemma3_4B_it_4bit,
            supportedRoles: [.scout])
        let request = BASOrganRequest(
            requestID: "req-2",
            role: .core,  // not in supported set
            preset: .core,
            instruction: "say hi",
            context: [])
        do {
            _ = try await adapter.draft(request)
            XCTFail("expected unsupportedRole")
        } catch BASOrganError.unsupportedRole(let role) {
            XCTAssertEqual(role, .core)
        } catch {
            XCTFail("expected unsupportedRole but got \(error)")
        }
    }

    // MARK: - 3. Capacity

    func testCapacityReportsUnderPressureWithStableReason() async {
        let adapter = MLXOrganAdapter()
        let cap = await adapter.currentCapacity()
        XCTAssertTrue(cap.underPressure)
        XCTAssertEqual(cap.availableInputTokens, 0)
        XCTAssertEqual(cap.availableOutputTokens, 0)
        let valid = ["MLX_NOT_LOADED", "MLX_UNAVAILABLE_BUILD"]
        XCTAssertTrue(
            cap.reasonCodes.contains(where: { valid.contains($0) }),
            "expected one of \(valid); got \(cap.reasonCodes)")
    }

    // MARK: - 4. Catalog stability

    func testDefaultCatalogShipsExactlyThreeGemmaEntries() {
        let entries = MLXModelCatalog.defaultEntries
        XCTAssertEqual(entries.count, 3)
        let ids = Set(entries.map(\.id))
        XCTAssertEqual(ids, [
            "mlx-community/gemma-3-4b-it-4bit",
            "mlx-community/gemma-3n-E4B-it-lm-4bit",
            "mlx-community/gemma-3n-E2B-it-lm-4bit"
        ])
    }

    func testEachEntryDeclaresGemmaEndOfTurnTokenForCorrectStop() {
        for entry in MLXModelCatalog.defaultEntries {
            XCTAssertTrue(
                entry.extraEOSTokens.contains("<end_of_turn>"),
                "entry \(entry.id) must list <end_of_turn> as an " +
                "extra EOS token; otherwise generation runs past " +
                "the reply (Gemma 3 / 3n turn terminator)")
        }
    }

    func testCatalogProviderIDsAreUniqueAndStable() {
        let providers = MLXModelCatalog.defaultEntries
            .map(\.providerID)
        XCTAssertEqual(
            Set(providers).count, providers.count,
            "providerIDs must be unique across catalog entries " +
            "(audit logs rely on them as primary keys)")
    }

    // MARK: - 5. Default pick is the recommended one

    func testInitDefaultsToGemma3nE4Bit() async {
        // Recommended pick per M220 plan §3.1 — Gemma 3n e4b
        // gives Gemma-3-4B-class quality with lower runtime
        // memory and higher tok/s on Apple Silicon.
        let adapter = MLXOrganAdapter()
        XCTAssertEqual(
            adapter.model, MLXModelCatalog.gemma3n_E4B_4bit)
    }
}
