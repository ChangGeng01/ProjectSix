import XCTest
@testable import BASOrgan

/// Phase 1 (MLX decode efficiency, measure-first) — the BASOrganCompletionMetrics plumbing: the REAL
/// prefill/decode split + token counts that ride on BASOrganDraft. The actual MLX numbers are on-device-only
/// (the model can't run on the macOS host); these prove the carrier is correct + ADDITIVE (back-compat):
/// existing BASOrganDraft callers + serialized drafts are unaffected by the new optional field.
final class BASOrganCompletionMetricsTests: XCTestCase {

    private func draft(metrics: BASOrganCompletionMetrics?) -> BASOrganDraft {
        BASOrganDraft(
            requestID: "r", providerID: "p", role: .core, body: "hello",
            inputTokensEstimated: 3, outputTokensEstimated: 1,
            producedAt: Date(timeIntervalSinceReferenceDate: 0),
            traceID: "t", completionMetrics: metrics)
    }

    func testMetricsCodableRoundTrip() throws {
        let m = BASOrganCompletionMetrics(
            promptTokens: 134, generationTokens: 96,
            prefillMs: 420.0, decodeMs: 2160.0,
            prefillTokensPerSec: 319.0, decodeTokensPerSec: 44.4)
        let data = try JSONEncoder().encode(m)
        let back = try JSONDecoder().decode(BASOrganCompletionMetrics.self, from: data)
        XCTAssertEqual(m, back)
    }

    func testMetricsClampNegativesToZero() {
        let m = BASOrganCompletionMetrics(
            promptTokens: -5, generationTokens: -1,
            prefillMs: -10, decodeMs: -2,
            prefillTokensPerSec: -3, decodeTokensPerSec: -4)
        XCTAssertEqual(m.promptTokens, 0)
        XCTAssertEqual(m.generationTokens, 0)
        XCTAssertEqual(m.prefillMs, 0)
        XCTAssertEqual(m.decodeMs, 0)
        XCTAssertEqual(m.prefillTokensPerSec, 0)
        XCTAssertEqual(m.decodeTokensPerSec, 0)
    }

    func testDraftDefaultsToNilMetrics() {
        // The 8-arg init still compiles (back-compat) and yields nil metrics.
        let d = BASOrganDraft(
            requestID: "r", providerID: "p", role: .core, body: "b",
            inputTokensEstimated: 1, outputTokensEstimated: 1,
            producedAt: Date(), traceID: "t")
        XCTAssertNil(d.completionMetrics)
    }

    func testDraftWithMetricsRoundTrips() throws {
        let m = BASOrganCompletionMetrics(
            promptTokens: 10, generationTokens: 20,
            prefillMs: 1, decodeMs: 2, prefillTokensPerSec: 3, decodeTokensPerSec: 4)
        let d = draft(metrics: m)
        let back = try JSONDecoder().decode(
            BASOrganDraft.self, from: try JSONEncoder().encode(d))
        XCTAssertEqual(back.completionMetrics, m)
        XCTAssertEqual(back, d)
    }

    func testNilMetricsOmitsKeyAndOldJSONDecodesToNil() throws {
        // ADDITIVE/back-compat property: a nil optional OMITS its key on encode (encodeIfPresent), and an old
        // JSON missing the key decodes to nil (decodeIfPresent). So pre-existing serialized drafts are safe.
        let data = try JSONEncoder().encode(draft(metrics: nil))
        let json = String(data: data, encoding: .utf8) ?? ""
        XCTAssertFalse(json.contains("completionMetrics"),
            "a nil optional must not emit its key — old readers + stored drafts stay valid")
        let back = try JSONDecoder().decode(BASOrganDraft.self, from: data)
        XCTAssertNil(back.completionMetrics)
        XCTAssertEqual(back.body, "hello")
    }

    func testDeterministicAdapterLeavesMetricsNil() async throws {
        // The no-MLX deterministic adapter can't surface real metrics → nil (only MLX populates them).
        let adapter = BASOrganDeterministicAdapter()
        let req = BASOrganRequest(
            requestID: "c", role: .scout, preset: .scout,
            instruction: "summarize", context: [])
        let d = try await adapter.draft(req)
        XCTAssertNil(d.completionMetrics)
    }
}
