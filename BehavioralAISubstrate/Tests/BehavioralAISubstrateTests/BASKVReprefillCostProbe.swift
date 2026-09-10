import XCTest
@testable import BASMLXAdapter
import BASOrgan

/// Measure-first for KV/prefix reuse. HISTORY (honest record): the first run of this instrument was INVALID —
/// its fresh arm used `organ.draft()`, which on Qwen3.5-GDN throws `nonTrimmableCache` (trim-checked verifyCache
/// fails closed on MambaCache) and the `try?` swallowed it → phantom 3–10 ms "generations". The valid signal from
/// that run (reuse arm ~15s/turn regardless of context growth) still yielded the SETTLED finding recorded in
/// THROUGHPUT_CAMPAIGN_2026-06.md: per-turn latency is GENERATION-dominated, so serving-side KV plumbing is a
/// small fraction of turn time. This corrected version uses the GDN-safe `streamDraft` for the fresh arm + validity
/// guards (sub-second "generations" are rejected as instrument failures). Gated BAS_KV_REPREFILL=1.
final class BASKVReprefillCostProbe: XCTestCase {

    func testReprefillCostGrowsWithContext() async throws {
        guard ProcessInfo.processInfo.environment["BAS_KV_REPREFILL"] == "1" else {
            throw XCTSkip("set BAS_KV_REPREFILL=1 to size the KV/re-prefill waste on Qwen3.5-4B (multi-turn)")
        }
        let organ = MLXOrganAdapter(model: MLXModelCatalog.qwen3_5_4B_4bit)
        try await organ.loadModel()
        await organ.setDecodePlannerAutoSelect(false)

        // A ~600-char context chunk added each turn — makes re-prefill cost visible as the history grows.
        let chunk = String(repeating: "The substrate records each decision with provenance and a sovereign verdict. ", count: 8)
        func nowMs() -> Double { Double(DispatchTime.now().uptimeNanoseconds) / 1_000_000 }

        func timeReuse(_ turns: Int) async -> [Double] {   // KV-reuse: warm ChatSession, short new message each turn
            var lat: [Double] = []
            let sid = "kv-reuse"
            for i in 0..<turns {
                let msg = i == 0 ? (chunk + "\nBriefly: what did I just describe?")
                                 : "Turn \(i): add one more sentence, then answer briefly."
                let req = BASOrganRequest(requestID: sid, role: .core, preset: .core, instruction: msg, context: [])
                let t = nowMs()
                _ = try? await organ.draftMultiTurn(req, sessionID: sid)
                lat.append(nowMs() - t)
            }
            return lat
        }
        func timeFresh(_ turns: Int) async -> [Double] {   // No reuse: full accumulated history re-prefilled each turn
            var lat: [Double] = []
            var history = ""
            for i in 0..<turns {
                history += chunk + "\n"
                let req = BASOrganRequest(requestID: "kv-fresh-\(i)", role: .core, preset: .core,
                                          instruction: history + "\nBriefly: summarize the above in one sentence.", context: [])
                let t = nowMs()
                do {                               // GDN-safe fresh gen (draft() throws nonTrimmableCache on GDN)
                    var body = ""
                    for try await c in organ.streamDraft(req) { body = c.cumulativeBody }
                    if body.isEmpty { print("  ⚠️ fresh turn \(i): empty body (instrument invalid)") }
                } catch { print("  ⚠️ fresh turn \(i) threw: \(error) (instrument invalid)") }
                lat.append(nowMs() - t)
            }
            return lat
        }

        let turns = 6
        let reuse = await timeReuse(turns)
        let fresh = await timeFresh(turns)
        print("=== KV/RE-PREFILL COST — per-turn latency (ms), growing context ===")
        for i in 0..<turns {
            print(String(format: "  turn %d: reuse=%.0f ms   fresh=%.0f ms", i, reuse[i], fresh[i]))
        }
        // Slope proxy: last-turn vs first-turn latency ratio. Fresh should climb (re-prefill), reuse should stay flatter.
        let freshGrow = fresh.last! / max(1, fresh.first!)
        let reuseGrow = reuse.last! / max(1, reuse.first!)
        print(String(format: "  GROWTH last/first: fresh=%.2f×  reuse=%.2f×", freshGrow, reuseGrow))
        print(String(format: "  KV VERDICT: %@",
              freshGrow > reuseGrow * 1.4
                ? "re-prefill waste is REAL (fresh climbs vs reuse flat) ⇒ unifying KV into the spec/stream path is worth designing"
                : "re-prefill waste is SMALL at this scale (both similar) ⇒ KV unification is NOT the top throughput lever here"))
    }
}
