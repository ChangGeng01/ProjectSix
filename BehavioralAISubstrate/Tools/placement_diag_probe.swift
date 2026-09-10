import CoreML
import Foundation

// Per-op-TYPE placement diagnostic: which MIL op types are NOT ANE-capable, and where each is placed.
// Pinpoints the capability-breaker in a model the aggregate histogram only summarizes.

@available(macOS 14.4, *)
func dev(_ d: MLComputeDevice?) -> String {
    switch d { case .neuralEngine: return "ane"; case .gpu: return "gpu"; case .cpu: return "cpu"; default: return "?" }
}

@available(macOS 14.4, *)
final class Agg { var total = 0; var capable = 0; var pref: [String: Int] = [:] }

@available(macOS 14.4, *)
func walk(_ b: MLModelStructure.Program.Block, _ p: MLComputePlan, _ m: inout [String: Agg]) {
    for op in b.operations {
        let t = op.operatorName
        if let u = p.deviceUsage(for: op) {
            let a = m[t] ?? Agg(); m[t] = a
            a.total += 1
            a.pref[dev(u.preferred), default: 0] += 1
            if u.supported.contains(where: { if case .neuralEngine = $0 { return true }; return false }) { a.capable += 1 }
        }
        for n in op.blocks { walk(n, p, &m) }
    }
}

@available(macOS 15.0, *)
func diag(_ path: String) async {
    do {
        let compiled = try await MLModel.compileModel(at: URL(fileURLWithPath: path))
        let cfg = MLModelConfiguration(); cfg.computeUnits = .all
        let plan = try await MLComputePlan.load(contentsOf: compiled, configuration: cfg)
        var m: [String: Agg] = [:]
        if case .program(let prog) = plan.modelStructure {
            for (_, fn) in prog.functions { walk(fn.block, plan, &m) }
        }
        print("📊 per-op-type placement for \((path as NSString).lastPathComponent):")
        for (t, a) in m.sorted(by: { $0.value.total > $1.value.total }) {
            let pref = a.pref.sorted { $0.value > $1.value }.map { "\($0.key)=\($0.value)" }.joined(separator: ",")
            let flag = a.capable == 0 ? "  <-- 0 ANE-capable" : (a.capable < a.total ? "  (partial)" : "")
            print(String(format: "  %-22@ n=%-4d ane_capable=%-4d pref[%@]%@", t as NSString, a.total, a.capable, pref, flag))
        }
    } catch { print("diag error=\(error)") }
}

let sem = DispatchSemaphore(value: 0)
Task {
    if #available(macOS 15.0, *) {
        await diag(CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "")
    } else { print("need macOS 15+") }
    sem.signal()
}
sem.wait()
