// MARK: - BASMTL4QueueProbe — iOS 27 P1 (IOS27_PERF_ADOPTION_PLAN)
//
// A/B for the Metal-4 dispatch lane on the reasoning-side MPSGraph
// kernels:the 6 builtin kernels are MICROSECOND-scale graphs whose
// per-evaluate cost is dominated by CPU encode/commit overhead,not
// graph compute — exactly the overhead Metal 4 queues claim to cut。
// `MPSGraphExecutable.run(on: MTL4CommandQueue, …)` is ios(27.0)
// (MPSGraphExecutable.h:195);`makeMTL4CommandQueue` ios(26.0)
// (MTLDevice.h:1297)。
//
// The probe builds ONE representative executable (softmax [1,512]
// fp32 — the production kernel idiom, BASMPSGraphSoftmaxKernel) and
// measures best-of-3 × 200 evaluates per lane:
//   lane A: run(with: MTLCommandQueue)   — the shipping dispatch
//   lane B: run(on: MTL4CommandQueue)    — the candidate
// plus numerics equality between lanes (same executable, same
// inputs ⇒ same outputs expected;asserted, not assumed)。
//
// PROBE-ONLY (DeviceTestApp;27-SDK symbols never enter the SPM
// package)。 The production flip decision is a separate gated
// commit per 5-axis discipline:≥2× STRONG-FLIP / ≥1.2× MODEST /
// else TIE/LOSS ⇒ DECLINE。 The dispatch ROUTE is recorded in the
// decision spine,so any wiring must be ADR-014 default-off。

import Foundation
import os
import Metal
import MetalPerformanceShadersGraph

enum BASMTL4QueueProbe {

    private static let log = Logger(
        subsystem: "com.bas.devicetest", category: "mtl4-probe")

    private static func emit(_ line: String) {
        log.info("\(line, privacy: .public)")
        print(line)
    }

    static func run() async {
        emit("📊 mtl4-probe START softmax[1,512] evaluates=200 best-of-3")
        guard #available(iOS 27.0, *) else {
            emit("❌ mtl4-probe ABORT below iOS 27")
            return
        }
        guard let device = MTLCreateSystemDefaultDevice(),
              let classicQueue = device.makeCommandQueue(),
              let mtl4Queue = device.makeMTL4CommandQueue()
        else {
            emit("❌ mtl4-probe ABORT queue creation failed")
            return
        }

        // Representative executable (production softmax idiom)。
        let rows = 1, cols = 512
        let graph = MPSGraph()
        let x = graph.placeholder(
            shape: [NSNumber(value: rows), NSNumber(value: cols)],
            dataType: .float32, name: "x")
        let out = graph.softMax(with: x, axis: 1, name: "output")
        let executable = graph.compile(
            with: nil,
            feeds: [x: MPSGraphShapedType(
                shape: [NSNumber(value: rows), NSNumber(value: cols)],
                dataType: .float32)],
            targetTensors: [out],
            targetOperations: nil,
            compilationDescriptor: nil)

        var input = [Float](repeating: 0, count: rows * cols)
        for i in 0..<input.count { input[i] = Float(i % 97) / 97.0 }
        func tensorData() -> MPSGraphTensorData? {
            let bytes = input.count * MemoryLayout<Float>.stride
            guard let buf = device.makeBuffer(
                bytes: input, length: bytes,
                options: .storageModeShared) else { return nil }
            return MPSGraphTensorData(
                buf,
                shape: [NSNumber(value: rows), NSNumber(value: cols)],
                dataType: .float32)
        }
        guard let xDataA = tensorData(), let xDataB = tensorData()
        else {
            emit("❌ mtl4-probe ABORT tensor-data alloc failed")
            return
        }

        func floats(_ td: MPSGraphTensorData) -> [Float] {
            var v = [Float](repeating: 0, count: rows * cols)
            td.mpsndarray().readBytes(&v, strideBytes: nil)
            return v
        }

        // Numerics equality first (asserted, not assumed)。
        let outA = executable.run(
            with: classicQueue, inputs: [xDataA],
            results: nil, executionDescriptor: nil)
        let outB = executable.run(
            on: mtl4Queue, inputs: [xDataB],
            results: nil, executionDescriptor: nil)
        guard let firstA = outA.first, let firstB = outB.first else {
            emit("❌ mtl4-probe ABORT empty results")
            return
        }
        let va = floats(firstA), vb = floats(firstB)
        let maxDelta = zip(va, vb).map { abs($0 - $1) }.max() ?? -1
        // Audit fix (batch-audit MEDIUM): the delta is CHECKED, not
        // just logged — fp32 softmax across queues of the same
        // executable should agree to ~1e-5;a bigger delta means the
        // MTL4 lane changes numerics and the A/B verdict is void。
        let numericsTolerance: Float = 1e-5
        let numericsOK = maxDelta >= 0 && maxDelta <= numericsTolerance
        emit(String(format:
            "📊 mtl4-probe NUMERICS max_abs_delta=%.3e tol=%.0e %@",
            maxDelta, numericsTolerance,
            numericsOK ? "PASS" : "FAIL"))
        guard numericsOK else {
            emit("❌ mtl4-probe ABORT numerics mismatch — latency "
                + "A/B is meaningless across diverging lanes; "
                + "verdict=LANE-INVALID")
            return
        }

        // Best-of-3 × 200 per lane。
        func bestOf3(_ body: () -> Void) -> Double {
            var best = Double.greatestFiniteMagnitude
            for _ in 0..<3 {
                let t0 = DispatchTime.now().uptimeNanoseconds
                for _ in 0..<200 { body() }
                let t1 = DispatchTime.now().uptimeNanoseconds
                best = min(best, Double(t1 - t0) / 200 / 1e3)
            }
            return best  // µs per evaluate
        }
        let laneAUs = bestOf3 {
            _ = executable.run(
                with: classicQueue, inputs: [xDataA],
                results: nil, executionDescriptor: nil)
        }
        let laneBUs = bestOf3 {
            _ = executable.run(
                on: mtl4Queue, inputs: [xDataB],
                results: nil, executionDescriptor: nil)
        }
        let ratio = laneAUs / max(laneBUs, 0.001)
        let verdict: String
        switch ratio {
        case 2.0...: verdict = "STRONG-FLIP candidate (≥2x)"
        case 1.2..<2.0: verdict = "MODEST (≥1.2x) — flip needs the full 6-kernel sweep"
        default: verdict = "TIE/LOSS — DECLINE, incumbent dispatch stands (亏的不要)"
        }
        emit(String(format:
            "📊 mtl4-probe RESULT laneA(MTLCommandQueue)=%.1fµs "
            + "laneB(MTL4CommandQueue)=%.1fµs ratio=%.2fx verdict=%@ "
            + "— human reads; any wiring is ADR-014 default-off",
            laneAUs, laneBUs, ratio, verdict))
    }
}
