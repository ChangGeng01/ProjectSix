import CoreML
import Foundation

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
        print("📊 stateful-plan ops=\(t) \(parts)")
    } catch { print("plan error=\(error)") }
}

@available(macOS 15.0, *)
func statefulLatency(_ path: String, _ units: MLComputeUnits, _ label: String, steps: Int = 64) async {
    do {
        let compiled = try await MLModel.compileModel(at: URL(fileURLWithPath: path))
        let cfg = MLModelConfiguration(); cfg.computeUnits = units
        let model = try MLModel(contentsOf: compiled, configuration: cfg)
        let state = model.makeState()
        let hidden = try MLMultiArray(shape: [1, 1, 2048], dataType: .float32)
        for i in 0..<hidden.count { hidden[i] = NSNumber(value: Float.random(in: -1...1)) }
        func stepInput(_ pos: Int) throws -> MLFeatureProvider {
            let p = try MLMultiArray(shape: [1], dataType: .int32); p[0] = NSNumber(value: pos)
            return try MLDictionaryFeatureProvider(dictionary: ["hidden": hidden, "position": p])
        }
        for pos in 0..<8 { _ = try await model.prediction(from: stepInput(pos), using: state) }  // warm
        let s = DispatchTime.now().uptimeNanoseconds
        for pos in 8..<(8 + steps) { _ = try await model.prediction(from: stepInput(pos), using: state) }
        let ms = Double(DispatchTime.now().uptimeNanoseconds &- s) / 1_000_000 / Double(steps)
        print(String(format: "⏱ stateful-latency %@ mean_ms_per_step=%.3f (autoregressive, live KV state)", label, ms))
    } catch { print("\(label) latency error=\(error)") }
}

let sem = DispatchSemaphore(value: 0)
Task {
    if #available(macOS 15.0, *) {
        let path = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/tmp/draft/StatefulDraft_fp16.mlpackage"
        await plan(path)
        await statefulLatency(path, .cpuAndNeuralEngine, "ANE")
        await statefulLatency(path, .cpuAndGPU, "GPU")
    } else { print("need macOS 15+") }
    sem.signal()
}
sem.wait()
