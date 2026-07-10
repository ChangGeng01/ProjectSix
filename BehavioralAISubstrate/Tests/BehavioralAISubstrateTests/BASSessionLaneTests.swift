import XCTest
@testable import BASMLXAdapter

/// 案3 gates — the pure session-lane elector, pinned over the exact shape matrix the audit's
/// composition bugs lived in (seam-1/4 class). Bodies stayed certified; this pins WHICH lane
/// every request shape rides.
final class BASSessionLaneTests: XCTestCase {

    private func lane(
        fused: Bool = false, capped: Bool = true, box: Bool = false,
        temp: Double = 0, cap: Int? = 48, weights: Bool = true, est: Int = 30
    ) -> MLXOrganAdapter.BASSessionLane {
        MLXOrganAdapter._sessionLane(
            fusedLaneEnabled: fused, cappedFusedEnabled: capped, hasLiveBox: box,
            temperature: temp, cap: cap, weightsAvailable: weights,
            estTokens: est, fusedMax: 250, cappedMax: 1024)
    }

    func testCappedFusedHappyPath() {
        XCTAssertEqual(lane(), .cappedFusedTranscript(transition: false))
    }

    func testSeamFourShapes_forcePooled() {
        XCTAssertEqual(lane(cap: nil), .pooled, "uncapped must ride pooled (the amnesia shape)")
        XCTAssertEqual(lane(cap: 385), .pooled, "cap>384 must ride pooled")
        XCTAssertEqual(lane(temp: 0.7), .pooled, "sampling must ride pooled")
    }

    func testLiveBoxAlwaysPools() {
        XCTAssertEqual(lane(box: true), .pooled)
        XCTAssertEqual(lane(fused: true, box: true), .pooled)
    }

    func testMissingWeightsPools() {
        XCTAssertEqual(lane(weights: false), .pooled)
        XCTAssertEqual(lane(fused: true, weights: false), .pooled)
    }

    func testHistoryOverflowTransitions() {
        XCTAssertEqual(lane(est: 1024), .cappedFusedTranscript(transition: true))
        XCTAssertEqual(lane(est: 1023), .cappedFusedTranscript(transition: false))
        XCTAssertEqual(lane(fused: true, est: 250), .fusedTranscript(transition: true))
        XCTAssertEqual(lane(fused: true, est: 249), .fusedTranscript(transition: false))
    }

    func testOptInFusedPrecedence() {
        // The opt-in lane ignores the cap and beats capped-fused — the certified guard order.
        XCTAssertEqual(lane(fused: true, cap: nil), .fusedTranscript(transition: false))
        XCTAssertEqual(lane(fused: true, cap: 48), .fusedTranscript(transition: false))
    }

    func testBothLanesOffPools() {
        XCTAssertEqual(lane(fused: false, capped: false), .pooled)
    }

    // audit mlx-decode LOW-1 / operator decision 6A: the world-writable /tmp MTP-weights candidate is
    // included ONLY when explicitly opted in (Mac-dev BAS_MTP_ALLOW_TMP_WEIGHTS=1), never by default.
    func testTmpWeightsCandidateGatedByOptIn() {
        let docs = URL(fileURLWithPath: "/Docs")
        let tmpPath = "/tmp/gdn_coreai/qwen35_mtp_folded.safetensors"
        let off = MLXOrganAdapter.mtpWeightsCandidates(
            documentsDir: docs, localDirName: nil, allowTmpDevCandidate: false)
        XCTAssertFalse(off.contains { $0.path == tmpPath },
            "the world-writable /tmp candidate must NOT be probed by default")
        let on = MLXOrganAdapter.mtpWeightsCandidates(
            documentsDir: docs, localDirName: nil, allowTmpDevCandidate: true)
        XCTAssertTrue(on.contains { $0.path == tmpPath },
            "with the opt-in, the /tmp dev candidate is included (last, after Documents)")
        XCTAssertEqual(on.last?.path, tmpPath, "the /tmp candidate is lowest-priority")
    }

    // audit mlx-adapter-core LOW-14: the transcript-seat eviction must drop the LEAST-recently-used
    // seat (front of the recency order), never an arbitrary dictionary key. Reversal (return
    // `order.last` — the MRU — or drop the `!= currentKey` skip) reds these.
    func testFusedTranscriptEvictionPicksLRU() {
        // Under cap ⇒ no eviction.
        XCTAssertNil(MLXOrganAdapter._fusedTranscriptEvictionVictim(
            order: ["a", "b", "c"], currentKey: "c", count: 3, cap: 3),
            "count <= cap must not evict")
        // Over cap ⇒ evict the oldest (front) that isn't the seat just written.
        XCTAssertEqual(MLXOrganAdapter._fusedTranscriptEvictionVictim(
            order: ["a", "b", "c", "d"], currentKey: "d", count: 4, cap: 3), "a",
            "over cap must evict the least-recently-used seat")
        // The current key is never evicted even if it is the oldest in the order.
        XCTAssertEqual(MLXOrganAdapter._fusedTranscriptEvictionVictim(
            order: ["cur", "b", "c", "d"], currentKey: "cur", count: 4, cap: 3), "b",
            "the just-written seat is skipped; the next-oldest is evicted")
        // No eligible victim (only the current key present) ⇒ nil.
        XCTAssertNil(MLXOrganAdapter._fusedTranscriptEvictionVictim(
            order: ["cur"], currentKey: "cur", count: 4, cap: 3),
            "no evictable seat other than the current key ⇒ nil")
    }

    // audit mlx-adapter-core LOW-15: BAS_MAX_LIVE_SESSIONS must clamp to a floor of 1 — a 0/negative
    // value would make _evictBeyondCap thrash (evict-everything / never-satisfiable cap).
    func testMaxLiveSessionsClampsToFloorOfOne() {
        XCTAssertEqual(MLXOrganAdapter.clampedMaxLiveSessions("0"), 1, "0 must clamp to 1")
        XCTAssertEqual(MLXOrganAdapter.clampedMaxLiveSessions("-5"), 1, "negative must clamp to 1")
        XCTAssertEqual(MLXOrganAdapter.clampedMaxLiveSessions("8"), 8, "a valid value passes through")
        XCTAssertEqual(MLXOrganAdapter.clampedMaxLiveSessions(nil), 16, "unset ⇒ default 16")
        XCTAssertEqual(MLXOrganAdapter.clampedMaxLiveSessions("nope"), 16, "non-numeric ⇒ default 16")
    }
}
