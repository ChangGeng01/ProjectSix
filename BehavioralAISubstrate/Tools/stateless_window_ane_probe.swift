import CoreML
import Foundation

// B1'' — does the STATELESS windowed-recompute decoder plan onto the ANE (inheriting B0), unlike every
// stateful formulation (B1/B1' → 100% GPU)? Walks MLComputePlan placement + per-draft-token latency.

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

let WINDOW = 64
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
        print("📊 statelesswindow-plan ops=\(t) \(parts)")
    } catch { print("plan error=\(error)") }
}

@available(macOS 14.4, *)
func windowInput() throws -> MLFeatureProvider {
    let w = try MLMultiArray(shape: [1, NSNumber(value: WINDOW), NSNumber(value: HIDDEN)], dataType: .float32)
    for i in 0..<w.count { w[i] = NSNumber(value: Float.random(in: -1...1)) }
    return try MLDictionaryFeatureProvider(dictionary: ["hidden_window": w])
}

@available(macOS 15.0, *)
func latency(_ path: String, _ units: MLComputeUnits, _ label: String, steps: Int = 60) async {
    do {
        let compiled = try await MLModel.compileModel(at: URL(fileURLWithPath: path))
        let cfg = MLModelConfiguration(); cfg.computeUnits = units
        let model = try MLModel(contentsOf: compiled, configuration: cfg)
        for _ in 0..<8 { _ = try await model.prediction(from: windowInput()) }   // warm
        let s = DispatchTime.now().uptimeNanoseconds
        for _ in 0..<steps { _ = try await model.prediction(from: windowInput()) }
        let ms = Double(DispatchTime.now().uptimeNanoseconds &- s) / 1_000_000 / Double(steps)
        print(String(format: "⏱ statelesswindow-latency %@ mean_ms_per_draft_token=%.3f (recompute over W=%d)", label, ms, WINDOW))
    } catch { print("\(label) latency error=\(error)") }
}

let sem = DispatchSemaphore(value: 0)
Task {
    if #available(macOS 15.0, *) {
        let path = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/tmp/draft/StatelessWindow_fp16.mlpackage"
        await plan(path)
        await latency(path, .cpuAndNeuralEngine, "ANE")
        await latency(path, .cpuAndGPU, "GPU")
        await latency(path, .all, "ALL")
    } else { print("need macOS 15+") }
    sem.signal()
}
sem.wait()
