// MARK: - AppleFoundationErrorMappingTests
//
// Skip-triage follow-on (2026-07-14): AppleFoundationOrganAdapter honours its own
// BASOrganAdapter error contract, and — the load-bearing property — a model SAFETY
// REFUSAL is never laundered into a routable "outage".
//
// The OS floor was raised 26 -> 27 (operator decision) so there is exactly ONE error
// taxonomy to map (LanguageModelError). That is what makes these teeth real: the 26 arm
// would have been untestable here (no macOS 26 host), and untestable error-mapping code
// is exactly what rots into a lie.

import XCTest
@testable import BASOrgan
@testable import BASAppleAdapters
#if canImport(FoundationModels)
import FoundationModels
#endif

final class AppleFoundationErrorMappingTests: XCTestCase {

    /// ★ THE SAFETY TOOTH. guardrailViolation / refusal MUST NOT map to
    /// .providerUnavailable or .pressureRefusal — the only two cases
    /// BASRoutingOrganAdapter fails over on (three sites: :161/:163, :191/:193,
    /// :216/:218). A live Apple-primary + MLX-secondary router already ships
    /// (QinaoSampleHost/SampleHostRuntimeBenchExtensions.swift:71-74), so mapping a
    /// refusal onto either case would make it silently re-run the refused prompt on MLX
    /// until a model complies. Returning nil means "rethrow raw", which the router does
    /// not recognise and therefore propagates.
    ///
    /// This runs on every pass — no env gate, no model needed.
    /// ★ THE SAFETY TOOTH. `guardrailViolation` is the model's SAFETY DECISION — a
    /// RESULT, not an outage — and must never become a routable error.
    ///
    /// `BASRoutingOrganAdapter` fails over to its secondary on exactly
    /// `.providerUnavailable` and `.pressureRefusal` (three sites: :161/:163, :191/:193,
    /// :216/:218), and a LIVE Apple-primary + MLX-Gemma-secondary router already ships in
    /// QinaoSampleHost/SampleHostRuntimeBenchExtensions.swift:71-74. Mapping a refusal onto
    /// either case would make that router silently RE-RUN the refused prompt on MLX until a
    /// model complies. That bypass does NOT exist today, so a careless mapping would CREATE
    /// it. `nil` means "rethrow raw", which the router does not recognise and propagates.
    ///
    /// COVERAGE BOUND, stated honestly: `.refusal` shares this exact switch branch
    /// (`case .guardrailViolation, .refusal: return nil`) but is NOT exercised here —
    /// `LanguageModelError.Refusal(debugDescription:)` SEGVs on construction under this
    /// toolchain (measured 2026-07-14; GuardrailViolation constructs fine). So the branch is
    /// proven by its constructible member, and a source-pin below keeps `.refusal` in it.
    func testGuardrailViolationIsNeverMappedToARoutableOutage() throws {
        #if canImport(FoundationModels)
        guard #available(iOS 27, macOS 27, visionOS 27, *) else {
            throw XCTSkip("adapter floor is 27; nothing to map below it")
        }
        let mapped = AppleFoundationOrganAdapter.organError(
            for: .guardrailViolation(.init(debugDescription: "probe-guardrail")))
        XCTAssertNil(
            mapped,
            "a guardrail violation must rethrow RAW. Mapping it to .providerUnavailable or "
            + ".pressureRefusal would let BASRoutingOrganAdapter retry the refused prompt on "
            + "its secondary — laundering Apple's safety decision onto another model.")
        #endif
    }

    /// Source-pin for the arm that cannot be constructed: `.refusal` must stay in the
    /// nil-returning (rethrow-raw) branch alongside `.guardrailViolation`. Behavioural
    /// coverage is impossible here (see above), so this pins the shape instead — if someone
    /// moves `.refusal` to its own arm and maps it, this REDs and they must justify it.
    func testRefusalStaysInTheRethrowRawBranch() throws {
        let source = try Self.adapterSource()
        XCTAssertTrue(
            source.contains("case .guardrailViolation, .refusal:"),
            "the safety-refusal branch must keep BOTH cases returning nil (rethrow raw). "
            + "If .refusal was split out and mapped, a live Apple->MLX router would launder "
            + "it. Source-pinned because LanguageModelError.Refusal cannot be constructed "
            + "in-process on this toolchain.")
    }

    /// Infrastructure outages DO map, and their reason interpolates the underlying error.
    /// That interpolation is load-bearing, not cosmetic: reasonCode(for:) passes `reason`
    /// verbatim to the host, and the AFM test helper detects the foreground-cache-cold
    /// state by substring. Sanitising these would kill that detection.
    func testInfrastructureOutagesMapToProviderUnavailableAndKeepTheUnderlyingError() throws {
        #if canImport(FoundationModels)
        guard #available(iOS 27, macOS 27, visionOS 27, *) else {
            throw XCTSkip("adapter floor is 27")
        }
        let mapped = AppleFoundationOrganAdapter.organError(
            for: .timeout(.init(debugDescription: "probe")))
        guard case .providerUnavailable(let reason)? = mapped else {
            return XCTFail("timeout must map to .providerUnavailable; got \(String(describing: mapped))")
        }
        XCTAssertTrue(
            reason.contains("afm-timeout"),
            "reason must name the class; got \(reason)")
        XCTAssertTrue(
            reason.count > "afm-timeout: ".count,
            "the underlying error must be INTERPOLATED, not sanitised away — host-side "
            + "cold-cache detection greps this string. Got: \(reason)")
        #endif
    }

    /// A caller-input violation must stay a caller-input violation: the router propagates
    /// .inputTooLong rather than failing over, which is correct — a secondary would reject
    /// it too. Also pins that the host-facing numbers are the real ones, not placeholders.
    func testContextOverflowForwardsApplesRealNumbers() throws {
        #if canImport(FoundationModels)
        guard #available(iOS 27, macOS 27, visionOS 27, *) else {
            throw XCTSkip("adapter floor is 27")
        }
        // Apple's real payload: window 8192, request weighed 200_058 tokens.
        let mapped = AppleFoundationOrganAdapter.organError(
            for: .contextSizeExceeded(.init(
                contextSize: 8192, tokenCount: 200_058, debugDescription: "probe")))
        guard case .inputTooLong(let limit, let actual)? = mapped else {
            return XCTFail("contextSizeExceeded must map to .inputTooLong; got \(String(describing: mapped))")
        }
        XCTAssertEqual(limit, 8192, "must forward Apple's real context window")
        XCTAssertEqual(actual, 200_058, "must forward Apple's real token count, not an estimate")
        #endif
    }

    /// ★ END-TO-END, REAL ERROR (env-gated only because it needs the live model).
    /// Drives a genuine context overflow through the PUBLIC adapter surface and asserts a
    /// typed BASOrganError comes out — i.e. the contract holds on the live path, which is
    /// the thing the old bare `try await session.respond` violated. Measured: the real
    /// context window is 8192 tokens.
    func testRealContextOverflowSurfacesAsTypedBASOrganError() async throws {
        guard ProcessInfo.processInfo.environment["QINAO_FM_E2E"] == "1" else {
            throw XCTSkip("set QINAO_FM_E2E=1 to drive the real Apple model")
        }
        #if canImport(FoundationModels)
        guard #available(iOS 27, macOS 27, visionOS 27, *) else {
            throw XCTSkip("adapter floor is 27")
        }
        guard case .available = SystemLanguageModel.default.availability else {
            throw XCTSkip("Apple Intelligence is not available on this host")
        }
        let adapter = AppleFoundationOrganAdapter()
        let request = BASOrganRequest(
            requestID: "afm-overflow-1",
            role: .scout,
            preset: .scout,
            instruction: String(repeating: "lorem ipsum dolor sit amet ", count: 40_000))
        do {
            _ = try await adapter.draft(request)
            XCTFail("a 200k-token instruction must not succeed against an 8192-token window")
        } catch let e as BASOrganError {
            // The contract holds: a raw FoundationModels error no longer escapes.
            if case .inputTooLong = e { return }
            if case .providerUnavailable = e { return }
            XCTFail("unexpected BASOrganError case: \(e)")
        } catch {
            XCTFail(
                "a raw \(type(of: error)) escaped the BASOrganAdapter contract — this is "
                + "exactly the defect the mapping exists to close: \(error)")
        }
        #endif
    }

    // MARK: - Helpers

    /// Read the adapter source by walking up to the package root. A missing anchor must
    /// FAIL (P2-21: an anchor the tree no longer matches is a defect, not a skip).
    private static func adapterSource() throws -> String {
        var dir = URL(fileURLWithPath: #filePath)
        for _ in 0..<8 {
            dir.deleteLastPathComponent()
            let c = dir.appendingPathComponent(
                "Sources/BASAppleAdapters/AppleFoundationOrganAdapter.swift")
            if FileManager.default.fileExists(atPath: c.path) {
                return try String(contentsOf: c, encoding: .utf8)
            }
        }
        throw NSError(
            domain: "AppleFoundationErrorMappingTests", code: 1,
            userInfo: [NSLocalizedDescriptionKey:
                "AppleFoundationOrganAdapter.swift not found from \(#filePath) — anchor drift"])
    }
}
