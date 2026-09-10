import XCTest
import BASOrgan
@testable import BASMLXAdapter

/// 缝4/缝3b gates (BAS_ROUTE_MIGRATION_TEST=1, Mac, heavy — loads Qwen3.5-4B).
///
/// 缝4: a transcript-land seat whose next request fails the fused guards (here: UNCAPPED) must
/// MIGRATE its conversation into the pooled ChatSession — the audit found the fresh branch
/// dropped it silently (the endurance cert missed it because every cert seat had a fixed shape).
/// 缝3b: a corrupt spill snapshot must be CONSUMED by the failed restore, not retried forever.
final class BASRouteMigrationTests: XCTestCase {

    private func makeAdapter() async throws -> MLXOrganAdapter {
        let adapter = MLXOrganAdapter(model: MLXModelCatalog.qwen3_5_4B_4bit)
        try await adapter.loadModel()
        return adapter
    }

    private func turn(_ adapter: MLXOrganAdapter, _ sid: String, _ text: String,
                      cap: Int?) async throws -> String {
        try await adapter.draft(BASOrganRequest(
            requestID: "rm-\(abs(text.hashValue))", role: .core, preset: .greedyDeterministic,
            instruction: text, maxOutputTokens: cap, sessionID: sid)).body
    }

    func testRouteClassChangeMigratesTranscript() async throws {
        guard ProcessInfo.processInfo.environment["BAS_ROUTE_MIGRATION_TEST"] == "1" else {
            throw XCTSkip("set BAS_ROUTE_MIGRATION_TEST=1 (heavy)")
        }
        #if canImport(MLXLLM)
        guard MLXOrganAdapter.sessionCappedFusedEnabled else {
            throw XCTSkip("needs the capped-fused lane armed (default-on)")
        }
        let adapter = try await makeAdapter()
        let sid = "shape-shift"
        // Turn 1: capped → transcript-land (the default-on capped-fused route).
        let r1 = try await turn(adapter, sid, "The codeword is OBSIDIAN-4. Reply with just: OK.", cap: 64)
        XCTAssertFalse(r1.isEmpty)
        let inTranscriptLand = await adapter._transcriptSeatCount()
        XCTAssertEqual(inTranscriptLand, 1, "turn 1 did not land in transcript-land")
        // Turn 2: UNCAPPED → fails the capped guard → pooled branch. Pre-fix: persona-only fresh
        // session, total amnesia. Post-fix: init(history:) migration carries the codeword.
        let r2 = try await turn(adapter, sid, "What is the codeword? Answer with just the codeword.", cap: nil)
        XCTAssertTrue(r2.localizedCaseInsensitiveContains("OBSIDIAN"),
                      "route-class change lost the conversation: \(r2.prefix(120))")
        let pooled = await adapter.sessionCount()
        XCTAssertEqual(pooled, 1, "migration must land the seat in the pool")
        let leftover = await adapter._transcriptSeatCount()
        XCTAssertEqual(leftover, 0, "migrated transcript must be consumed")
        #else
        throw XCTSkip("MLXLLM unavailable")
        #endif
    }

    func testFailedSpillRestoreConsumesCorruptFile() async throws {
        guard ProcessInfo.processInfo.environment["BAS_ROUTE_MIGRATION_TEST"] == "1" else {
            throw XCTSkip("set BAS_ROUTE_MIGRATION_TEST=1 (heavy)")
        }
        #if canImport(MLXLLM)
        guard MLXOrganAdapter.sessionSpillEnabled else {
            throw XCTSkip("needs the spill lane armed (default-on)")
        }
        let adapter = try await makeAdapter()
        let key = "corrupt#\(BASOrganRole.core.rawValue)"
        let url = MLXOrganAdapter._spillURL(forKey: key)
        try Data("not-a-safetensors-file".utf8).write(to: url)
        // UNCAPPED turn → pooled path → restore attempt fails → file must be consumed, turn must
        // still succeed on a fresh seat.
        let r = try await turn(adapter, "corrupt", "Reply with just: OK.", cap: nil)
        XCTAssertFalse(r.isEmpty, "turn on a corrupt-spill seat failed entirely")
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path),
                       "corrupt snapshot survived the failed restore — every miss re-pays it")
        let fails = await adapter.spillRestoreFailCount
        XCTAssertEqual(fails, 1, "failed-restore telemetry did not count")
        #else
        throw XCTSkip("MLXLLM unavailable")
        #endif
    }
}
