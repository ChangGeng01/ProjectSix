import XCTest
import BASOrgan
import MLX
@testable import BASHostKit
@testable import BASMLXAdapter
#if canImport(MLXLLM)
import MLXLMCommon
import MLXHuggingFace
import HuggingFace
import MLXLLM
import Tokenizers
#endif

/// B5 spill ENDURANCE CERT (TEST_RUNNER_BAS_SPILL_CERT=1 + TEST_RUNNER_BAS_SESSION_SPILL=1 +
/// TEST_RUNNER_BAS_MAX_LIVE_SESSIONS=4; device, ~8 min): 6 seats round-robin over a pool capped
/// at 4 — every cycle forces evict→spill→restore churn (the worst case). Each seat seeds a unique
/// codeword; the recall probes must hold **100%** across spill cycles (without the lane an evicted
/// seat is amnesiac by construction — retention IS the value). Watches: correctness, spill/restore
/// counts, per-minute turn latency (thermal drift visible), footprint stability.
final class BASSessionSpillEnduranceDeviceTests: XCTestCase {

    func testSpillEnduranceCert() async throws {
        guard ProcessInfo.processInfo.environment["BAS_SPILL_CERT"] == "1" else {
            throw XCTSkip("set TEST_RUNNER_BAS_SPILL_CERT=1 (+SPILL=1, MAX_LIVE_SESSIONS=4; ~8 min)")
        }
        #if canImport(MLXLLM)
        XCTAssertTrue(MLXOrganAdapter.sessionSpillEnabled, "runner must set BAS_SESSION_SPILL=1")
        XCTAssertEqual(MLXOrganAdapter.maxLiveSessions, 4, "runner must set BAS_MAX_LIVE_SESSIONS=4")
        ModelFactoryRegistry.shared.addTrampoline { LLMModelFactory.shared }
        MLX.GPU.set(cacheLimit: 512 * 1024 * 1024)
        let adapter = MLXOrganAdapter(model: MLXModelCatalog.qwen3_5_4B_4bit_local)
        try await adapter.loadModel()
        let codewords = ["lantern", "obsidian", "cascade", "juniper", "meridian", "tundra"]
        // Per-turn watchdog (take-1 hung >1h with zero diagnostics — suspected device-lock
        // suspension): NSLog marks are syslog-visible LIVE, and a 120s race fails fast with
        // the seat number instead of wedging the whole cert.
        func turn(_ seat: Int, _ text: String, cap: Int = 48) async throws -> String {
            NSLog("[spill-cert] turn seat%d begin", seat)
            let result = try await withThrowingTaskGroup(of: String?.self) { group in
                group.addTask {
                    try await adapter.draft(BASOrganRequest(
                        requestID: "sc-\(seat)-\(abs(text.hashValue))", role: .core,
                        preset: .greedyDeterministic, instruction: text, maxOutputTokens: cap,
                        sessionID: "seat\(seat)")).body
                }
                group.addTask {
                    try await Task.sleep(nanoseconds: 120_000_000_000)
                    return nil
                }
                defer { group.cancelAll() }
                guard let first = try await group.next(), let body = first else {
                    NSLog("[spill-cert] WATCHDOG seat%d 120s", seat)
                    throw NSError(domain: "spill-cert", code: 1,
                                  userInfo: [NSLocalizedDescriptionKey: "turn watchdog seat\(seat)"])
                }
                return body
            }
            NSLog("[spill-cert] turn seat%d done", seat)
            return result
        }
        // Seed all six codewords (pool cap 4 ⇒ the first spills happen during seeding already).
        for (i, w) in codewords.enumerated() {
            _ = try await turn(i, "My codeword is \(w). Remember it. Reply with just: OK.")
        }
        var asked = 0, correct = 0, turns = 6
        var minuteMs: [Int: (ms: Double, n: Int)] = [:]
        let t0 = Date()
        while Date().timeIntervalSince(t0) < 360 {
            let seat = turns % 6
            let g0 = Date()
            if turns % 5 == 0 {
                // cap 160: the pooled ChatSession lane has NO B3 trace-exit (structural gap,
                // recorded follow-up) — at cap 48 the thinking eats the budget and recall probes
                // fail with "Thinking Process:" truncations that are NOT spill defects (take-4).
                let a = try await turn(seat, "What is my codeword? Answer with the single word only.",
                                       cap: 160)
                asked += 1
                if a.localizedCaseInsensitiveContains(codewords[seat]) {
                    correct += 1
                } else {
                    print("[spill-cert] MISS seat\(seat) expected \(codewords[seat]) got: \(a.prefix(80))")
                }
            } else {
                _ = try await turn(seat, "Add one short sentence to our story about the sea.")
            }
            let minute = Int(Date().timeIntervalSince(t0) / 60)
            let prev = minuteMs[minute] ?? (0, 0)
            minuteMs[minute] = (prev.ms + Date().timeIntervalSince(g0) * 1000, prev.n + 1)
            turns += 1
        }
        let stats = await adapter.sessionSpillStats()
        for m in minuteMs.keys.sorted() {
            let v = minuteMs[m]!
            print(String(format: "[spill-cert] min=%02d turns=%d avg_turn_ms=%.0f thermal=%d",
                         m, v.n, v.ms / Double(v.n),
                         ProcessInfo.processInfo.thermalState.rawValue))
        }
        print("[spill-cert] VERDICT turns=\(turns) recall=\(correct)/\(asked) spilled=\(stats.spilled) restored=\(stats.restored)")
        XCTAssertEqual(correct, asked, "codeword recall must be 100% across spill cycles")
        XCTAssertGreaterThan(stats.spilled, 10, "cert must exercise real spill churn")
        XCTAssertGreaterThan(stats.restored, 10, "cert must exercise real restore churn")
        #else
        throw XCTSkip("MLXLLM unavailable")
        #endif
    }
}
