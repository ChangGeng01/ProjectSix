// MARK: - BASDecodeLivenessMonitorTests — U3 gate
//
// Deterministic gate via injected monotonic clock (no sleeps, no
// device)。 Load-bearing claims: no stall ⇒ zero output;threshold
// crossing ⇒ exactly ONE verdict per episode;progress re-arms;
// endTurn silences;GPU probe runs at detection time and lands in
// the verdict + wedge-signature line。

import XCTest
@testable import BASMLXAdapter

final class BASDecodeLivenessMonitorTests: XCTestCase {

    /// Mutable fake clock + verdict collector (lock-guarded —
    /// callbacks are @Sendable)。
    private final class Harness: @unchecked Sendable {
        private let lock = NSLock()
        private var nowNs: UInt64 = 1_000_000_000
        private var verdictsStore: [BASDecodeStallVerdict] = []

        func advance(seconds: Double) {
            lock.lock(); defer { lock.unlock() }
            nowNs &+= UInt64(seconds * 1_000_000_000)
        }
        func now() -> UInt64 {
            lock.lock(); defer { lock.unlock() }
            return nowNs
        }
        func record(_ v: BASDecodeStallVerdict) {
            lock.lock(); defer { lock.unlock() }
            verdictsStore.append(v)
        }
        var verdicts: [BASDecodeStallVerdict] {
            lock.lock(); defer { lock.unlock() }
            return verdictsStore
        }
    }

    private func makeMonitor(
        harness: Harness,
        thresholdSec: Double = 30,
        gpuProbe: (@Sendable () -> Bool)? = nil
    ) -> BASDecodeLivenessMonitor {
        BASDecodeLivenessMonitor(
            stallThresholdSec: thresholdSec,
            gpuProbe: gpuProbe,
            clock: { harness.now() },
            onStall: { harness.record($0) })
    }

    // MARK: - No stall ⇒ zero output

    func testIdleMonitorNeverFires() async {
        let h = Harness()
        let m = makeMonitor(harness: h)
        h.advance(seconds: 3600)
        let v = await m.check()
        XCTAssertNil(v, "no turn in flight ⇒ no verdict, ever")
        XCTAssertTrue(h.verdicts.isEmpty)
    }

    func testProgressingTurnNeverFires() async {
        let h = Harness()
        let m = makeMonitor(harness: h, thresholdSec: 30)
        await m.beginTurn(id: "t1")
        for _ in 0..<10 {
            h.advance(seconds: 20)   // always under threshold
            await m.progress()
            let v = await m.check()
            XCTAssertNil(v, "progress within threshold ⇒ no verdict")
        }
        await m.endTurn()
        XCTAssertTrue(h.verdicts.isEmpty)
    }

    func testCompletedTurnNeverFires() async {
        let h = Harness()
        let m = makeMonitor(harness: h, thresholdSec: 30)
        await m.beginTurn(id: "t1")
        h.advance(seconds: 10)
        await m.endTurn()
        h.advance(seconds: 3600)
        let v = await m.check()
        XCTAssertNil(v, "a completed turn must never report a stall")
    }

    // MARK: - Stall detection

    func testStallFiresExactlyOncePerEpisode() async {
        let h = Harness()
        let m = makeMonitor(harness: h, thresholdSec: 30)
        await m.beginTurn(id: "wedged-turn")
        h.advance(seconds: 31)
        let v1 = await m.check()
        XCTAssertNotNil(v1, "31s > 30s threshold must fire")
        XCTAssertEqual(v1?.turnID, "wedged-turn")
        XCTAssertEqual(v1!.secondsSinceProgress, 31, accuracy: 0.01)
        // Subsequent checks in the SAME episode stay silent。
        h.advance(seconds: 60)
        let v2 = await m.check()
        XCTAssertNil(v2, "one verdict per stall episode")
        XCTAssertEqual(h.verdicts.count, 1)
    }

    func testProgressReArmsAfterReportedStall() async {
        let h = Harness()
        let m = makeMonitor(harness: h, thresholdSec: 30)
        await m.beginTurn(id: "t1")
        h.advance(seconds: 31)
        _ = await m.check()
        XCTAssertEqual(h.verdicts.count, 1)
        // A late token arrives (slow-but-alive decode) — re-arm。
        await m.progress()
        h.advance(seconds: 31)
        let v2 = await m.check()
        XCTAssertNotNil(v2, "a fresh 31s gap after re-arm must fire again")
        XCTAssertEqual(h.verdicts.count, 2)
    }

    func testUnderThresholdDoesNotFire() async {
        let h = Harness()
        let m = makeMonitor(harness: h, thresholdSec: 30)
        await m.beginTurn(id: "t1")
        h.advance(seconds: 29.5)
        let v = await m.check()
        XCTAssertNil(v, "under threshold must not fire")
    }

    // MARK: - GPU probe + wedge signature

    func testGpuProbeRunsAtDetectionAndLandsInVerdict() async {
        let h = Harness()
        let m = makeMonitor(harness: h, thresholdSec: 30,
                            gpuProbe: { true })
        await m.beginTurn(id: "t1")
        h.advance(seconds: 40)
        let v = await m.check()
        XCTAssertEqual(v?.gpuProbeHealthy, true)
        XCTAssertTrue(v!.verdictLine.contains("signature=mlx-process-local-wedge"),
            "healthy GPU + stalled decode = the measured ADR-038 wedge " +
            "signature (2026-06-09 on-device control)")
        XCTAssertTrue(v!.verdictLine.contains("turn=t1"))
    }

    func testNoProbeYieldsUnprobedStallSignature() async {
        let h = Harness()
        let m = makeMonitor(harness: h, thresholdSec: 30)
        await m.beginTurn(id: "t1")
        h.advance(seconds: 40)
        let v = await m.check()
        XCTAssertNil(v?.gpuProbeHealthy)
        XCTAssertTrue(v!.verdictLine.contains("gpu_probe=unprobed"))
        XCTAssertTrue(v!.verdictLine.contains("signature=stall"),
            "without a probe the line must claim only 'stall', never " +
            "the wedge signature (R1: no unverified claims)")
    }

    // MARK: - Threshold clamp

    func testNonPositiveThresholdClampsToOneSecond() async {
        let h = Harness()
        let m = makeMonitor(harness: h, thresholdSec: -5)
        await m.beginTurn(id: "t1")
        h.advance(seconds: 0.5)
        let early = await m.check()
        XCTAssertNil(early, "0.5s < 1s clamped floor must not fire")
        h.advance(seconds: 0.6)
        let fired = await m.check()
        XCTAssertNotNil(fired, "1.1s ≥ 1s clamped floor must fire")
    }
}
