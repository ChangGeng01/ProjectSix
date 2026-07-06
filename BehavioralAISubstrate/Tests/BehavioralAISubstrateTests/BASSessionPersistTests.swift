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
}
