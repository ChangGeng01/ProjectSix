import CoreML
import Foundation

@available(macOS 14.4, *)
func deviceName(_ d: MLComputeDevice?) -> String {
    switch d {
    case .neuralEngine: return "ane"
    case .gpu: return "gpu"
    case .cpu: return "cpu"
    default: return "unknown"
    }
}

@available(macOS 14.4, *)
func walk(_ block: MLModelStructure.Program.Block, _ plan: MLComputePlan,
          _ hist: inout [String: Int], _ total: inout Int, _ aneCapable: inout Int) {
    for op in block.operations {
        if let usage = plan.deviceUsage(for: op) {
            hist[deviceName(usage.preferred), default: 0] += 1
            total += 1
            if usage.supported.contains(where: { if case .neuralEngine = $0 { return true }; return false }) {
                aneCapable += 1
            }
        }
        for nested in op.blocks { walk(nested, plan, &hist, &total, &aneCapable) }
    }
}

@available(macOS 14.4, *)
func run(_ path: String, _ units: MLComputeUnits, _ label: String) async {
    let url = URL(fileURLWithPath: path)
    let config = MLModelConfiguration()
    config.computeUnits = units
    do {
        let compiled = try await MLModel.compileModel(at: url)
        let plan = try await MLComputePlan.load(contentsOf: compiled, configuration: config)
        var hist: [String: Int] = [:]; var total = 0; var aneCapable = 0
        switch plan.modelStructure {
        case .program(let program):
            for (_, fn) in program.functions { walk(fn.block, plan, &hist, &total, &aneCapable) }
        default:
            print("\(label): unsupported structure"); return
        }
        let parts = hist.sorted { $0.value > $1.value }.map { "\($0.key)=\($0.value)" }.joined(separator: " ")
        print("📊 draft-ane-plan \(label) ops=\(total) \(parts) ane_capable=\(aneCapable)")
    } catch {
        print("\(label): error=\(error)")
    }
}

@available(macOS 14.4, *)
func latency(_ path: String, _ units: MLComputeUnits, _ label: String, iters: Int = 60) async {
    let url = URL(fileURLWithPath: path)
    let config = MLModelConfiguration()
    config.computeUnits = units
    do {
        let compiled = try await MLModel.compileModel(at: url)
        let model = try MLModel(contentsOf: compiled, configuration: config)
        let arr = try MLMultiArray(shape: [1, 1, 2048], dataType: .float32)
        for i in 0..<arr.count { arr[i] = NSNumber(value: Float.random(in: -1...1)) }
        let input = try MLDictionaryFeatureProvider(dictionary: ["hidden": arr])
        for _ in 0..<12 { _ = try await model.prediction(from: input) }   // warm
        var t = 0.0
        for _ in 0..<iters {
            let s = DispatchTime.now().uptimeNanoseconds
            _ = try await model.prediction(from: input)
            t += Double(DispatchTime.now().uptimeNanoseconds &- s) / 1e6
        }
        print("⏱ draft-latency \(label) mean_ms=\(String(format: "%.3f", t / Double(iters)))")
    } catch { print("\(label) latency error=\(error)") }
}

let sem = DispatchSemaphore(value: 0)
Task {
    if #available(macOS 14.4, *) {
        let base = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/tmp/draft/DraftBlock_fp16.mlpackage"
        await run(base, .all, "fp16/all")
        await run(base, .cpuAndNeuralEngine, "fp16/cpuAndANE")
        await run(base.replacingOccurrences(of: "fp16", with: "fp32"), .all, "fp32/all")
        await latency(base, .cpuOnly, "fp16/cpuOnly")
        await latency(base, .cpuAndGPU, "fp16/cpuAndGPU")
        await latency(base, .cpuAndNeuralEngine, "fp16/ANE")
        await latency(base, .all, "fp16/all")
    } else {
        print("need macOS 14.4+")
    }
    sem.signal()
}
sem.wait()
