import XCTest
@testable import BASMLXAdapter

/// B2 — the pure probe head (no model): scoring math, dimension guards, budget refinement bounds.
final class BASDifficultyProbeTests: XCTestCase {

    /// deep-audit LOW (mirrors decision 6A): the world-writable /tmp probe-weights fallback must be
    /// gated to macOS + explicit opt-in, so a production (iOS) run never loads weights another process
    /// planted in /tmp. Unfixed (unconditional allow) → the no-opt-in assertion goes red.
    func testTmpDiffProbeCandidateGatedToMacOSAndOptIn() {
        XCTAssertFalse(MLXOrganAdapter._tmpDiffProbeAllowed(env: [:]),
            "no opt-in ⇒ the /tmp candidate is never used (production-safe default)")
        XCTAssertFalse(MLXOrganAdapter._tmpDiffProbeAllowed(
            env: ["BAS_DIFF_PROBE_ALLOW_TMP_WEIGHTS": "0"]))
        #if os(macOS)
        XCTAssertTrue(MLXOrganAdapter._tmpDiffProbeAllowed(
            env: ["BAS_DIFF_PROBE_ALLOW_TMP_WEIGHTS": "1"]),
            "macOS dev with explicit opt-in may use the /tmp staging candidate")
        #else
        XCTAssertFalse(MLXOrganAdapter._tmpDiffProbeAllowed(
            env: ["BAS_DIFF_PROBE_ALLOW_TMP_WEIGHTS": "1"]),
            "iOS never allows the /tmp candidate, even with the opt-in set")
        #endif
    }

    private var probe: BASDifficultyProbe {
        // 4 dims: w=[1,-1,0,0], identity standardization → z = h0 − h1 + b
        BASDifficultyProbe(w: [1, -1, 0, 0], b: 0,
                           mu: [0, 0, 0, 0], sd: [1, 1, 1, 1])
    }

    func testScoreIsCalibratedSigmoid() throws {
        XCTAssertEqual(try probe.successProbability(hidden: [0, 0, 0, 0]), 0.5, accuracy: 1e-9)
        XCTAssertGreaterThan(try probe.successProbability(hidden: [3, 0, 0, 0]), 0.95)
        XCTAssertLessThan(try probe.successProbability(hidden: [0, 3, 0, 0]), 0.05)
    }

    func testStandardizationApplied() throws {
        let p = BASDifficultyProbe(w: [1], b: 0, mu: [10], sd: [2])
        XCTAssertEqual(try p.successProbability(hidden: [10]), 0.5, accuracy: 1e-9)
        XCTAssertGreaterThan(try p.successProbability(hidden: [14]), 0.85)   // z = (14-10)/2 = 2
    }

    func testDimensionMismatchThrows() {
        XCTAssertThrowsError(try probe.successProbability(hidden: [1, 2, 3]))
    }

    func testRefinedBudgetBoundedToOneTier() {
        // hard → one tier UP, easy → one tier DOWN, mid band → unchanged; clamped at the ends.
        XCTAssertEqual(probe.refinedBudget(planned: 160, pSuccess: 0.10), 384)
        XCTAssertEqual(probe.refinedBudget(planned: 160, pSuccess: 0.95), 64)
        XCTAssertEqual(probe.refinedBudget(planned: 160, pSuccess: 0.60), 160)
        XCTAssertEqual(probe.refinedBudget(planned: 1024, pSuccess: 0.10), 1024, "top tier clamps")
        XCTAssertEqual(probe.refinedBudget(planned: 64, pSuccess: 0.95), 64, "bottom tier clamps")
    }

    func testWeightsRoundTripThroughJSON() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("probe_test_\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: dir) }
        let obj: [String: Any] = ["w": [0.5, -0.5], "b": 0.25, "mu": [1.0, 2.0],
                                  "sd": [1.0, 1.0], "heldout_auc": 0.9]
        try JSONSerialization.data(withJSONObject: obj).write(to: dir)
        let p = try BASDifficultyProbe(weightsURL: dir)
        XCTAssertEqual(p.w, [0.5, -0.5])
        XCTAssertEqual(p.heldoutAUC, 0.9)
        XCTAssertEqual(try p.successProbability(hidden: [1, 2]), 1 / (1 + exp(-0.25)), accuracy: 1e-6)
    }

    // audit mlx-decode LOW-3: a malformed weights file must FAIL CLOSED — a zero std-dev (division-
    // by-zero) or a non-finite coefficient (e.g. 1e400 → +inf on parse) would otherwise poison every
    // inference. Written as raw JSON text so the +inf literal survives (JSONSerialization won't emit it).
    func testMalformedWeightsFailClosed() throws {
        func writeRaw(_ json: String) throws -> URL {
            let u = FileManager.default.temporaryDirectory
                .appendingPathComponent("probe_bad_\(UUID().uuidString).json")
            try Data(json.utf8).write(to: u)
            return u
        }
        let zeroSD = try writeRaw(#"{"w":[0.5,0.5],"b":0.1,"mu":[0,0],"sd":[1,0]}"#)
        defer { try? FileManager.default.removeItem(at: zeroSD) }
        XCTAssertThrowsError(try BASDifficultyProbe(weightsURL: zeroSD),
            "a zero std-dev (division-by-zero) must fail closed")

        let infW = try writeRaw(#"{"w":[1e400,0.5],"b":0.1,"mu":[0,0],"sd":[1,1]}"#)
        defer { try? FileManager.default.removeItem(at: infW) }
        XCTAssertThrowsError(try BASDifficultyProbe(weightsURL: infW),
            "a +inf coefficient (1e400) must fail closed")
    }
}
