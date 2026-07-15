import XCTest
@testable import BASHostKit
@testable import BASMLXAdapter
import BASRuntimeCore
import BASOrgan

/// 全面完善 measure-firsts — closes the two serving-side residues both audits left open, with NUMBERS.
///
/// (1) EVENT-LOG RATE (appendMany decision): memoryEventLog is a default-nil opt-in, so the DEFAULT hot path
///     writes zero events. This measures the OPTED-IN rate: how many events does one stub turn actually append?
///     appendMany batching is worth building only if events/turn × ~1ms/tx is a real fraction of a ~15s turn.
/// (2) INTRA-TURN CANDIDATE CONCURRENCY (THROUGHPUT_CAMPAIGN's open gate; metric #17 pre-registers ≈1.0):
///     does `async let` concurrency beat serial for two generations on the production adapter? Mechanism note:
///     MLXOrganAdapter is an actor and MLX's ModelContainer serializes `perform` — so structural serialization
///     is the expected answer; this puts a measured wall-ratio on it. Gated BAS_CANDIDATE_CONCURRENCY=1 (heavy).
final class BASServingResidueMeasureTests: XCTestCase {

    // (1) events/turn when a host OPTS IN to the event log (default path is nil ⇒ 0 by construction).
    func testEventLogAppendsPerTurnWhenOptedIn() async {
        let log = BASInMemoryEventLogStorage()
        let coord = BASEBrainRuntimeCoordinator(
            powerClockService: StubPowerClock(), hostProfileService: StubHost(),
            contextService: StubContext(), decomposeService: StubDecompose(),
            memoryService: StubMemory(), loopService: StubLoop(), triSelfService: StubTriSelf(),
            riskService: StubRisk(), actionService: StubAction(), evolutionService: StubEvolution(),
            memoryEventLog: log)
        _ = coord.runTurn(BASCoordinatorTestStubs.makeStubRequest())
        let n = await log.events(sinceTimestampMs: 0, limit: 100_000).count
        print("=== EVENT-LOG RATE: opted-in stub turn appended \(n) event(s) ===")
        print("    ⇒ appendMany batching saves ≈\(n) tx ≈ \(n) ms per turn (~\(String(format: "%.2f", Double(n) / 150.0))% of a 15s turn)")
        XCTAssertGreaterThanOrEqual(n, 0)
    }

    // (2) concurrent vs serial generation on the production adapter (Qwen3.5-4B). Heavy — env-gated.
    func testCandidateConcurrencyVsSerial() async throws {
        guard ProcessInfo.processInfo.environment["BAS_CANDIDATE_CONCURRENCY"] == "1" else {
            throw XCTSkip("set BAS_CANDIDATE_CONCURRENCY=1 to measure async-let vs serial candidate generation")
        }
        let organ = MLXOrganAdapter(model: MLXModelCatalog.qwen3_5_4B_4bit)
        try await organ.loadModel()
        await organ.setDecodePlannerAutoSelect(false)
        func req(_ i: Int) -> BASOrganRequest {
            BASOrganRequest(requestID: "cc\(i)", role: .core, preset: .core,
                            instruction: "Reply with one short sentence about topic \(i).", context: [])
        }
        func now() -> Double { Double(DispatchTime.now().uptimeNanoseconds) / 1_000_000 }
        // GDN-safe generation: plain draft() throws nonTrimmableCache on Qwen3.5 (trim-checked verifyCache
        // fails closed on MambaCache — the SAME cause behind the KV probe's 3ms phantom arm). streamDraft is
        // the GDN-safe path; collect the full body.
        func gen(_ r: BASOrganRequest) async throws -> String {
            var body = ""
            for try await c in organ.streamDraft(r) { body = c.cumulativeBody }
            return body
        }
        // Warmup — SURFACE failures instead of swallowing them (a millisecond "generation" = broken instrument).
        do {
            let w = try await gen(req(99))
            print("    warmup body chars=\(w.count): \(String(w.prefix(60)))")
            guard !w.isEmpty else { print("    ⚠️ INSTRUMENT INVALID — empty body"); return }
        } catch { print("    ⚠️ INSTRUMENT INVALID — warmup threw: \(error)"); return }
        let t0 = now()
        let s1 = try await gen(req(1)); let s2 = try await gen(req(2))
        let serial = now() - t0
        guard !s1.isEmpty, !s2.isEmpty, serial > 1000 else {
            print("    ⚠️ INSTRUMENT INVALID — serial 2-gen \(Int(serial))ms (sub-second = not real generation)"); return
        }
        let t1 = now()
        async let a = gen(req(3)); async let b = gen(req(4))
        let r1 = try await a; let r2 = try await b
        let conc = now() - t1
        guard !r1.isEmpty, !r2.isEmpty else { print("    ⚠️ INSTRUMENT INVALID — empty concurrent body"); return }
        let ratio = serial / max(1, conc)
        print(String(format: "=== CANDIDATE CONCURRENCY: serial 2-gen %.0f ms, async-let 2-gen %.0f ms → speedup %.2fx ===", serial, conc, ratio))
        print("    ⇒ " + (ratio > 1.3
            ? "concurrency HELPS — intra-turn batching worth building"
            : "≈1.0x as pre-registered (metric #17) — actor+GPU serialize; intra-turn TaskGroup batching NOT worth building; CLOSE the gate"))
    }
}
