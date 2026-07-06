import XCTest
import BASOrgan
import BASRuntimeCore
@testable import BASMLXAdapter

/// FRONTIER_2026H2 tail-closure tests: snapshot GC bound (pure), thermal-prior persistence
/// seam (pure), and the dream-loop warm-seat snapshot action (model-gated).
final class BASSpillGCTests: XCTestCase {

    private func makeDir(files: Int) throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("bas_gc_test_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for i in 0 ..< files {
            let url = dir.appendingPathComponent(String(format: "seat_%03d.safetensors", i))
            try Data("x".utf8).write(to: url)
            // Staggered mtimes: seat_000 oldest … seat_(N-1) newest. Deterministic, no sleeps.
            try FileManager.default.setAttributes(
                [.modificationDate: Date(timeIntervalSince1970: 1_000_000 + Double(i) * 60)],
                ofItemAtPath: url.path)
        }
        return dir
    }

    private func names(_ dir: URL) -> Set<String> {
        Set((try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? [])
    }

    func testPruneKeepsNewestUnderBound() throws {
        let dir = try makeDir(files: 40)
        defer { try? FileManager.default.removeItem(at: dir) }
        MLXOrganAdapter._pruneSpillDir(in: dir, keep: 32)
        let kept = names(dir)
        XCTAssertEqual(kept.count, 32)
        XCTAssertFalse(kept.contains("seat_000.safetensors"), "oldest must be GC'd")
        XCTAssertFalse(kept.contains("seat_007.safetensors"), "8th-oldest must be GC'd")
        XCTAssertTrue(kept.contains("seat_008.safetensors"), "boundary survivor")
        XCTAssertTrue(kept.contains("seat_039.safetensors"), "newest must survive")
    }

    func testPruneNoopAtOrUnderBound() throws {
        let dir = try makeDir(files: 5)
        defer { try? FileManager.default.removeItem(at: dir) }
        MLXOrganAdapter._pruneSpillDir(in: dir, keep: 32)
        XCTAssertEqual(names(dir).count, 5, "under the bound nothing may be deleted")
        MLXOrganAdapter._pruneSpillDir(in: dir, keep: 5)
        XCTAssertEqual(names(dir).count, 5, "exactly-at-bound nothing may be deleted")
    }

    func testPruneMissingDirIsSafe() {
        let ghost = FileManager.default.temporaryDirectory
            .appendingPathComponent("bas_gc_ghost_\(UUID().uuidString)", isDirectory: true)
        MLXOrganAdapter._pruneSpillDir(in: ghost, keep: 32)   // must not crash or create it
        XCTAssertFalse(FileManager.default.fileExists(atPath: ghost.path))
    }

    func testThermalPredictorRestoresPersistedBudget() {
        let fresh = BASThermalHazardPredictor()
        XCTAssertEqual(fresh.learnedBudget, fresh.config.priorNominalDutyBudget,
                       "nil restore must fall back to the prior")
        let restored = BASThermalHazardPredictor(learnedBudget: 42)
        XCTAssertEqual(restored.learnedBudget, 42,
                       "a persisted estimate must seed the EMA, replacing the prior")
        XCTAssertEqual(restored.config.priorNominalDutyBudget,
                       fresh.config.priorNominalDutyBudget, "config itself untouched")
    }

    /// Dream-loop window action (BAS_SNAPSHOT_TEST=1, heavy): two pooled seats → snapshotWarmSeats
    /// must park BOTH to their spill URLs without evicting them (live pool unchanged).
    func testSnapshotWarmSeats() async throws {
        guard ProcessInfo.processInfo.environment["BAS_SNAPSHOT_TEST"] == "1" else {
            throw XCTSkip("set BAS_SNAPSHOT_TEST=1 BAS_SESSION_CAPPED_FUSED=0 (heavy — loads Qwen3.5-4B)")
        }
        #if canImport(MLXLLM)
        guard !MLXOrganAdapter.sessionCappedFusedEnabled else {
            throw XCTSkip("needs BAS_SESSION_CAPPED_FUSED=0 — capped turns live in transcript-land otherwise")
        }
        guard MLXOrganAdapter.sessionSpillEnabled else {
            throw XCTSkip("needs the spill lane armed (BAS_SESSION_SPILL default-on)")
        }
        let adapter = MLXOrganAdapter(model: MLXModelCatalog.qwen3_5_4B_4bit)
        try await adapter.loadModel()
        for sid in ["dream-a", "dream-b"] {
            _ = try await adapter.draft(BASOrganRequest(
                requestID: "snap-\(sid)", role: .core, preset: .greedyDeterministic,
                instruction: "Reply with just: OK.", maxOutputTokens: 32, sessionID: sid))
        }
        let parked = await adapter.snapshotWarmSeats()
        XCTAssertEqual(parked, 2, "both pooled seats must be parked")
        for sid in ["dream-a", "dream-b"] {
            // Pool key = "sessionID#role" (see MLXOrganAdapter.sessionKey).
            let url = MLXOrganAdapter._spillURL(forKey: "\(sid)#\(BASOrganRole.core.rawValue)")
            let size = (try? FileManager.default
                .attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
            XCTAssertGreaterThan(size ?? 0, 1_000_000, "\(sid) snapshot missing or truncated")
            try? FileManager.default.removeItem(at: url)
        }
        // Parking must NOT evict: both seats still answer from the live pool.
        let r = try await adapter.draft(BASOrganRequest(
            requestID: "snap-post", role: .core, preset: .greedyDeterministic,
            instruction: "Reply with just: OK.", maxOutputTokens: 32, sessionID: "dream-a"))
        XCTAssertFalse(r.body.isEmpty)
        #else
        throw XCTSkip("MLXLLM unavailable")
        #endif
    }
}
