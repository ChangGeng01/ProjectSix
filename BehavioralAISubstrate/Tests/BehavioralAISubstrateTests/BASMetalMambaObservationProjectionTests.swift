// Step 4 — proofs for the per-turn Metal/Mamba observation projection.
//
// Proves: project() is pure/deterministic and computes the right means + verdict; the
// observation path is byte-equal-OFF (nil harness OR nil sink ⇒ nothing runs, returns nil); and
// with a real harness + sink it emits exactly one observation carrying the turn identity.

import XCTest
import Foundation
@testable import BASHostKit
import BASMetalSubstrate

final class BASMetalMambaObservationProjectionTests: XCTestCase {

    private final class ObsBox: @unchecked Sendable {
        private let lock = NSLock()
        private var items: [BASMetalMambaObservation] = []
        func add(_ x: BASMetalMambaObservation) { lock.lock(); items.append(x); lock.unlock() }
        var all: [BASMetalMambaObservation] { lock.lock(); defer { lock.unlock() }; return items }
    }

    private func report(
        cpu: [Double], gpu: [Double], gpuAvailable: Bool
    ) -> BASMetalBenchmarkReport {
        BASMetalBenchmarkReport(
            shape: BASMetalBenchmarkShape(
                preDim: 16, postDim: 64, warmupIterations: 3, timedIterations: cpu.count),
            cpuMicrosecondsSamples: cpu,
            gpuMicrosecondsSamples: gpu,
            gpuAvailable: gpuAvailable)
    }

    // MARK: - pure projection

    func testProjectComputesMeansAndGpuVerdict() {
        let r = report(cpu: [10, 20, 30], gpu: [4, 6, 8], gpuAvailable: true)
        let obs = BASMetalMambaObservationProjection.project(
            sessionID: "s1", turnID: "t1", report: r)
        XCTAssertEqual(obs.mambaCPUMicrosecondsMean, 20, accuracy: 0.0001)
        XCTAssertEqual(obs.mambaGPUMicrosecondsMean, 6, accuracy: 0.0001)
        XCTAssertTrue(obs.gpuAvailable)
        XCTAssertEqual(obs.verdict, .gpuOK)
        XCTAssertEqual(obs.sessionID, "s1")
        XCTAssertEqual(obs.turnID, "t1")
    }

    func testProjectIsDeterministic() {
        let r = report(cpu: [11, 22], gpu: [3, 5], gpuAvailable: true)
        let a = BASMetalMambaObservationProjection.project(sessionID: "s", turnID: "t", report: r)
        let b = BASMetalMambaObservationProjection.project(sessionID: "s", turnID: "t", report: r)
        XCTAssertEqual(a, b)
    }

    func testProjectVerdictCpuOnlyWhenGpuUnavailable() {
        let r = report(cpu: [12, 18], gpu: [], gpuAvailable: false)
        let obs = BASMetalMambaObservationProjection.project(
            sessionID: "s", turnID: "t", report: r)
        XCTAssertEqual(obs.verdict, .cpuOnly)
        XCTAssertEqual(obs.mambaGPUMicrosecondsMean, 0, accuracy: 0.0001)
        XCTAssertFalse(obs.gpuAvailable)
    }

    // MARK: - byte-equal-off (nil harness or nil sink ⇒ nothing runs)

    func testRunShadowReturnsNilWhenHarnessNil() async {
        let box = ObsBox()
        let result = await BASMetalMambaObservationProjection.runShadowIfEnabled(
            sessionID: "s", turnID: "t", harness: nil, sink: { box.add($0) })
        XCTAssertNil(result)
        XCTAssertTrue(box.all.isEmpty, "no probe runs when harness is nil")
    }

    func testRunShadowReturnsNilWhenSinkNil() async {
        let result = await BASMetalMambaObservationProjection.runShadowIfEnabled(
            sessionID: "s", turnID: "t", harness: BASMetalBenchmarkHarness(), sink: nil)
        XCTAssertNil(result, "byte-equal path: nil sink ⇒ no probe, no observation")
    }

    // MARK: - emission with a real harness

    func testRunShadowEmitsObservationWhenEnabled() async {
        let box = ObsBox()
        let result = await BASMetalMambaObservationProjection.runShadowIfEnabled(
            sessionID: "sess-A", turnID: "turn-A",
            harness: BASMetalBenchmarkHarness(), sink: { box.add($0) })
        XCTAssertNotNil(result)
        XCTAssertEqual(box.all.count, 1, "exactly one observation emitted")
        XCTAssertEqual(result?.sessionID, "sess-A")
        XCTAssertEqual(result?.turnID, "turn-A")
        XCTAssertTrue([.gpuOK, .cpuOnly].contains(result?.verdict))
    }
}
