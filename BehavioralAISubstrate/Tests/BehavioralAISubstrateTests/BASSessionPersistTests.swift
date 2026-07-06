import XCTest
import BASOrgan
@testable import BASMLXAdapter

/// B5 pool-level gate (BAS_SESSION_PERSIST_TEST=1, Mac, heavy): persist a pooled seat session,
/// drop it, warm-restore it, and prove the restored KV carries the conversation WITHOUT any
/// re-prefill — the cross-session warm-start contract. (Decoder-level fidelity/TTFT = F6:
/// fp16 48/48 exact, 45.7×.)
final class BASSessionPersistTests: XCTestCase {

    func testPersistRestoreCarriesContext() async throws {
        guard ProcessInfo.processInfo.environment["BAS_SESSION_PERSIST_TEST"] == "1" else {
            throw XCTSkip("set BAS_SESSION_PERSIST_TEST=1 (heavy — loads Qwen3.5-4B)")
        }
        #if canImport(MLXLLM)
        print("[persist] loading model…"); 
        guard !MLXOrganAdapter.sessionCappedFusedEnabled else {
            throw XCTSkip("persist/spill tests need BAS_SESSION_CAPPED_FUSED=0 — capped turns live in transcript-land otherwise")
        }
        let adapter = MLXOrganAdapter(model: MLXModelCatalog.qwen3_5_4B_4bit)
        try await adapter.loadModel()
        print("[persist] model loaded, turn 1…")
        let sid = "persist-gate"
        func turn(_ text: String) async throws -> String {
            try await adapter.draft(BASOrganRequest(
                requestID: "sp-\(abs(text.hashValue))", role: .core, preset: .greedyDeterministic,
                instruction: text, maxOutputTokens: 64, sessionID: sid)).body
        }
        // Seed a fact into the session, then snapshot it.
        let r1 = try await turn("My name is Zebulon and I collect meteorites. Reply with just: OK.")
        print("[persist] turn1 done body=\(r1.prefix(60))")
        XCTAssertFalse(r1.isEmpty)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("bas_session_persist_\(UUID().uuidString).safetensors")
        defer { try? FileManager.default.removeItem(at: url) }
        let bytes = try await adapter.persistSession(sessionID: sid, to: url)
        print("[persist] snapshot bytes=\(bytes)")
        XCTAssertGreaterThan(bytes, 1_000_000, "snapshot suspiciously small")

        // Drop the live session entirely, then warm-restore from disk.
        await adapter.clearSession(sessionID: sid)
        try await adapter.restoreSession(sessionID: sid, from: url)

        // The restored KV must carry the seeded fact — no transcript, no re-prefill.
        let r2 = try await turn("What is my name? One word.")
        print("[persist] post-restore answer: \(r2.prefix(120))")
        XCTAssertTrue(r2.localizedCaseInsensitiveContains("Zebulon"),
                      "restored session lost the conversation context")
        #else
        throw XCTSkip("MLXLLM unavailable")
        #endif
    }

    /// B5 promotion — the LRU-SPILL lane e2e (BAS_SESSION_SPILL_TEST=1; requires the env seams
    /// BAS_SESSION_SPILL=1 and BAS_MAX_LIVE_SESSIONS=1 set by the runner): seat A seeds a fact,
    /// seat B evicts A (cap 1 ⇒ spill to Caches), seat A returns and must remember the fact via
    /// the spill warm-restore — no transcript, no re-prefill.
    func testLRUSpillRoundtrip() async throws {
        guard ProcessInfo.processInfo.environment["BAS_SESSION_SPILL_TEST"] == "1" else {
            throw XCTSkip("set BAS_SESSION_SPILL_TEST=1 BAS_SESSION_SPILL=1 BAS_MAX_LIVE_SESSIONS=1")
        }
        #if canImport(MLXLLM)
        XCTAssertEqual(MLXOrganAdapter.maxLiveSessions, 1, "runner must set BAS_MAX_LIVE_SESSIONS=1")
        XCTAssertTrue(MLXOrganAdapter.sessionSpillEnabled, "runner must set BAS_SESSION_SPILL=1")
        guard !MLXOrganAdapter.sessionCappedFusedEnabled else {
            throw XCTSkip("persist/spill tests need BAS_SESSION_CAPPED_FUSED=0 — capped turns live in transcript-land otherwise")
        }
        let adapter = MLXOrganAdapter(model: MLXModelCatalog.qwen3_5_4B_4bit)
        try await adapter.loadModel()
        func turn(_ sid: String, _ text: String) async throws -> String {
            try await adapter.draft(BASOrganRequest(
                requestID: "spill-\(abs(text.hashValue))", role: .core, preset: .greedyDeterministic,
                instruction: text, maxOutputTokens: 64, sessionID: sid)).body
        }
        print("[spill] model loaded, turn A…"); fflush(stdout)
        _ = try await turn("seatA", "My name is Quilliam and I breed axolotls. Reply with just: OK.")
        print("[spill] turn A done, turn B (evicts A)…"); fflush(stdout)
        _ = try await turn("seatB", "Say hello in three words.")     // evicts A → spill
        print("[spill] turn B done"); fflush(stdout)
        let spillURL = MLXOrganAdapter._spillURL(forKey: "seatA#core")
        XCTAssertTrue(FileManager.default.fileExists(atPath: spillURL.path),
                      "eviction must have spilled seat A")
        print("[spill] spill file present, seat A returns…"); fflush(stdout)
        let back = try await turn("seatA", "What is my name? One word.")
        print("[spill] seat A returns: \(back.prefix(100))")
        XCTAssertTrue(back.localizedCaseInsensitiveContains("Quilliam"),
                      "spill warm-restore lost the context")
        XCTAssertFalse(FileManager.default.fileExists(atPath: spillURL.path),
                       "spill file must be consumed on restore")
        #else
        throw XCTSkip("MLXLLM unavailable")
        #endif
    }
}
