import CoreML
import Foundation

// Generic, input-agnostic MLComputePlan placement walk: prints `ops=N ane=.. gpu=.. cpu=..` for any .mlpackage.
// Used to map the ANE/GPU boundary (attention-light heads vs a seq-length self-attention sweep).

@available(macOS 14.4, *)
func deviceName(_ d: MLComputeDevice?) -> String {
    switch d { case .neuralEngine: return "ane"; case .gpu: return "gpu"; case .cpu: return "cpu"; default: return "unknown" }
}

@available(macOS 14.4, *)
func walk(_ b: MLModelStructure.Program.Block, _ p: MLComputePlan, _ h: inout [String: Int], _ t: inout Int, _ cap: inout Int) {
    for op in b.operations {
        if let u = p.deviceUsage(for: op) {
            h[deviceName(u.preferred), default: 0] += 1; t += 1
            if u.supported.contains(where: { if case .neuralEngine = $0 { return true }; return false }) { cap += 1 }
        }
        for n in op.blocks { walk(n, p, &h, &t, &cap) }
    }
}

@available(macOS 15.0, *)
func plan(_ path: String) async {
    do {
        let compiled = try await MLModel.compileModel(at: URL(fileURLWithPath: path))
        let cfg = MLModelConfiguration(); cfg.computeUnits = .all
        let plan = try await MLComputePlan.load(contentsOf: compiled, configuration: cfg)
        var h: [String: Int] = [:]; var t = 0; var cap = 0
        if case .program(let prog) = plan.modelStructure {
            for (_, fn) in prog.functions { walk(fn.block, plan, &h, &t, &cap) }
        }
        let parts = h.sorted { $0.value > $1.value }.map { "\($0.key)=\($0.value)" }.joined(separator: " ")
        let name = (path as NSString).lastPathComponent
        print("📊 placement \(name) ops=\(t) \(parts) ane_capable=\(cap)")
    } catch { print("📊 placement error=\(error)") }
}

let sem = DispatchSemaphore(value: 0)
Task {
    if #available(macOS 15.0, *) {
        let path = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ""
        await plan(path)
    } else { print("need macOS 15+") }
    sem.signal()
}
sem.wait()
