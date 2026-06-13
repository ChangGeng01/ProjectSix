import CoreML
import Foundation

// B1' — does the ANE-friendly FIXED-WINDOW stateful decoder keep its matmuls on the ANE (unlike naive B1,
// which fell 100% to the GPU)? Walks MLComputePlan per-op placement + an autoregressive MLState latency A/B,
// feeding host-precomputed write_onehot + attn_bias each step (no dynamic index/compare in the graph).

@available(macOS 14.4, *)
func deviceName(_ d: MLComputeDevice?) -> String {
    switch d { case .neuralEngine: return "ane"; case .gpu: return "gpu"; case .cpu: return "cpu"; default: return "unknown" }
}

@available(macOS 14.4, *)
func walk(_ b: MLModelStructure.Program.Block, _ p: MLComputePlan, _ h: inout [String: Int], _ t: inout Int) {
    for op in b.operations {
        if let u = p.deviceUsage(for: op) { h[deviceName(u.preferred), default: 0] += 1; t += 1 }
        for n in op.blocks { walk(n, p, &h, &t) }
    }
}

let MAX_SEQ = 256
let HIDDEN = 2048

@available(macOS 15.0, *)
func plan(_ path: String) async {
    do {
        let compiled = try await MLModel.compileModel(at: URL(fileURLWithPath: path))
        let cfg = MLModelConfiguration(); cfg.computeUnits = .all
        let plan = try await MLComputePlan.load(contentsOf: compiled, configuration: cfg)
        var h: [String: Int] = [:]; var t = 0
        if case .program(let prog) = plan.modelStructure {
            for (_, fn) in prog.functions { walk(fn.block, plan, &h, &t) }
        }
        let parts = h.sorted { $0.value > $1.value }.map { "\($0.key)=\($0.value)" }.joined(separator: " ")
        print("📊 fixedwindow-plan ops=\(t) \(parts)")
    } catch { print("plan error=\(error)") }
}

@available(macOS 15.0, *)
func stepInput(_ pos: Int, _ hidden: MLMultiArray) throws -> MLFeatureProvider {
    let oh = try MLMultiArray(shape: [NSNumber(value: MAX_SEQ)], dataType: .float32)
    let bias = try MLMultiArray(shape: [NSNumber(value: MAX_SEQ)], dataType: .float32)
    for i in 0..<MAX_SEQ {
        oh[i] = NSNumber(value: i == pos ? 1.0 : 0.0)
        bias[i] = NSNumber(value: i <= pos ? 0.0 : -1e4)   // host-computed causal mask
    }
    return try MLDictionaryFeatureProvider(
        dictionary: ["hidden": hidden, "write_onehot": oh, "attn_bias": bias])
}

@available(macOS 15.0, *)
func latency(_ path: String, _ units: MLComputeUnits, _ label: String, steps: Int = 64) async {
    do {
        let compiled = try await MLModel.compileModel(at: URL(fileURLWithPath: path))
        let cfg = MLModelConfiguration(); cfg.computeUnits = units
        let model = try MLModel(contentsOf: compiled, configuration: cfg)
        let state = model.makeState()
        let hidden = try MLMultiArray(shape: [1, 1, NSNumber(value: HIDDEN)], dataType: .float32)
        for i in 0..<hidden.count { hidden[i] = NSNumber(value: Float.random(in: -1...1)) }
        for pos in 0..<8 { _ = try await model.prediction(from: stepInput(pos, hidden), using: state) }  // warm
        let s = DispatchTime.now().uptimeNanoseconds
        for pos in 8..<(8 + steps) { _ = try await model.prediction(from: stepInput(pos, hidden), using: state) }
        let ms = Double(DispatchTime.now().uptimeNanoseconds &- s) / 1_000_000 / Double(steps)
        print(String(format: "⏱ fixedwindow-latency %@ mean_ms_per_step=%.3f (autoregressive, live KV state)", label, ms))
    } catch { print("\(label) latency error=\(error)") }
}

let sem = DispatchSemaphore(value: 0)
Task {
    if #available(macOS 15.0, *) {
        let path = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/tmp/draft/FixedWindowStateful_fp16.mlpackage"
        await plan(path)
        await latency(path, .cpuAndNeuralEngine, "ANE")
        await latency(path, .cpuAndGPU, "GPU")
        await latency(path, .all, "ALL")
    } else { print("need macOS 15+") }
    sem.signal()
}
sem.wait()
