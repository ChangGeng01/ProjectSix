import XCTest
import BASOrgan
@testable import BASMLXAdapter

/// Ship-cert E2E: the `.mtpSpec` lane through the REAL adapter pipeline (template → tokenize → MTP spec decode
/// with production EOS → detokenize → profiler fold). BAS_MTP_PIPE=1 (heavy — loads Qwen3.5-4B).
final class BASMTPAdapterPipelineTests: XCTestCase {

    func testMTPSpecPipelineEndToEnd() async throws {
        guard ProcessInfo.processInfo.environment["BAS_MTP_PIPE"] == "1" else {
            throw XCTSkip("set BAS_MTP_PIPE=1 (needs /tmp/gdn_coreai/qwen35_mtp_folded.safetensors)")
        }
        let organ = MLXOrganAdapter(
            model: MLXModelCatalog.qwen3_5_4B_4bit,
            mtpDrafterWeightsURL: URL(fileURLWithPath: "/tmp/gdn_coreai/qwen35_mtp_folded.safetensors"))
        try await organ.loadModel()
        await organ.setDecodePlannerAutoSelect(false)
        let req = BASOrganRequest(
            requestID: "mtp-pipe", role: .core, preset: .core,
            instruction: "Reply with exactly one short sentence: what is a lighthouse for?", context: [])

        // capabilities must offer the lane
        let caps = await organ._decodeCapabilities()
        XCTAssertTrue(caps.mtpHeadLoaded, "opt-in URL + loaded model must offer the lane")

        // plain baseline via the GDN-safe streaming path (executor .plain uses the trim-checked path, which
        // fails closed on GDN — the known Qwen3.5 production reality; streaming IS its plain lane)
        let t0 = Date()
        var plainBody = ""
        for try await c in organ.streamDraft(req) { plainBody = c.cumulativeBody }
        let plainSec = Date().timeIntervalSince(t0)
        let t1 = Date()
        let spec = try await organ._execute(.mtpSpec, for: req, purpose: .factual)
        let specSec = Date().timeIntervalSince(t1)

        print("=== PIPE plain (\(String(format: "%.1f", plainSec))s): \(String(plainBody.prefix(90))) ===")
        print("=== PIPE spec  (\(String(format: "%.1f", specSec))s): \(String(spec.body.prefix(90))) ===")
        XCTAssertFalse(spec.body.isEmpty, "spec pipeline must produce text")
        XCTAssertFalse(plainBody.isEmpty)
        // ADR-039 lossless: same greedy family — require substantial prefix agreement (tie-flips allowed)
        let pfx = zip(plainBody, spec.body).prefix(while: ==).count
        print("=== PIPE common prefix: \(pfx) chars | profiler stat: \(String(describing: await organ.mtpProfilerStat())) ===")
        XCTAssertGreaterThan(pfx, 10, "streams should share a long greedy prefix (lossless family)")
        // telemetry folded (trap #2)
        let stat = await organ.mtpProfilerStat()
        XCTAssertNotNil(stat, "acceptance telemetry must fold into the profiler on first use")
    }
}
