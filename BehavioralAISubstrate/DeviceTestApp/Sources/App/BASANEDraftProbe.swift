// MARK: - BASANEDraftProbe — Track B B0 on the REAL iPhone A19 (BAS_ANE_DRAFT_PROBE=1)
//
// B0 cleared on the Mac (fp16 transformer decode → 100% ANE placement; ANE 2.5× slower/token than GPU). This
// is the AUTHORITATIVE measurement on the iPhone Air's A19 ANE (different ANE/GPU ratio — the operator's target):
// does the converted fp16 decoder block's ops land on the A19 ANE, and is the ANE per-token latency competitive
// (which decides whether an ANE-draft ∥ GPU-verify hybrid can win)?
//
// Stage the converted model first:
//   xcrun devicectl device copy to --device <udid> --domain-type appDataContainer \
//     --domain-identifier com.changgeng.basdevicetest \
//     --source /tmp/draft/DraftBlock_fp16.mlpackage --destination Documents/DraftBlock_fp16.mlpackage
// (and the fp32 control). Then launch with BAS_ANE_DRAFT_PROBE=1.

import Foundation
import os
import CoreML

enum BASANEDraftProbe {

    private static let log = Logger(subsystem: "com.bas.devicetest", category: "ane-draft")

    private final class FileLog: @unchecked Sendable {
        private let handle: FileHandle?
        private let lock = NSLock()
        init() {
            let f = DateFormatter()
            f.dateFormat = "yyyyMMdd-HHmmss"; f.locale = Locale(identifier: "en_US_POSIX")
            let stamp = f.string(from: Date())
            guard let docs = FileManager.default.urls(
                for: .documentDirectory, in: .userDomainMask).first else { handle = nil; return }
            let url = docs.appendingPathComponent("ane-draft-\(stamp).log")
            FileManager.default.createFile(atPath: url.path, contents: nil)
            handle = try? FileHandle(forWritingTo: url)
        }
        func emit(_ line: String) {
            BASANEDraftProbe.log.info("\(line, privacy: .public)")
            guard let data = (line + "\n").data(using: .utf8) else { return }
            lock.lock(); defer { lock.unlock() }
            try? handle?.write(contentsOf: data)
        }
        func close() { lock.lock(); defer { lock.unlock() }; try? handle?.close() }
    }

    static func run() async {
        let fileLog = FileLog()
        defer { fileLog.close() }
        fileLog.emit("📊 ane-draft START — A19 ANE placement + latency for the converted fp16 decoder block")

        guard let docs = FileManager.default.urls(
            for: .documentDirectory, in: .userDomainMask).first else {
            fileLog.emit("📊 ane-draft ERROR=no-documents-dir"); return
        }
        let fp16 = docs.appendingPathComponent("DraftBlock_fp16.mlpackage")
        let fp32 = docs.appendingPathComponent("DraftBlock_fp32.mlpackage")

        guard FileManager.default.fileExists(atPath: fp16.path) else {
            fileLog.emit("📊 ane-draft ERROR=DraftBlock_fp16.mlpackage missing — stage it into Documents first")
            return
        }

        if #available(iOS 17.4, *) {
            await plan(fp16, units: .all, label: "fp16/all", fileLog: fileLog)
            await plan(fp16, units: .cpuAndNeuralEngine, label: "fp16/cpuAndANE", fileLog: fileLog)
            if FileManager.default.fileExists(atPath: fp32.path) {
                await plan(fp32, units: .all, label: "fp32/all", fileLog: fileLog)
            }
        } else {
            fileLog.emit("📊 ane-draft plan SKIPPED (needs iOS 17.4+)")
        }

        await latency(fp16, units: .cpuOnly, label: "fp16/cpuOnly", fileLog: fileLog)
        await latency(fp16, units: .cpuAndGPU, label: "fp16/cpuAndGPU", fileLog: fileLog)
        await latency(fp16, units: .cpuAndNeuralEngine, label: "fp16/ANE", fileLog: fileLog)
        await latency(fp16, units: .all, label: "fp16/all", fileLog: fileLog)

        // A19 confirmation of the attention-over-history wall (Mac said: seq=1→ANE, seq=W & stateful→GPU). Same
        // device, side-by-side. Placement is input-agnostic (plan walk only); latency where feasible.
        await confirmAttentionWall(docs: docs, fileLog: fileLog)

        fileLog.emit("📊 ane-draft DONE — human-read: ane=N in the histogram ⇒ A19 runs decode on the ANE; "
            + "compare fp16/ANE vs fp16/cpuAndGPU latency for the parallel-draft viability.")
    }

    // MARK: - A19 attention-over-history wall confirmation (B1''/B1' on the real A19)

    private static func confirmAttentionWall(docs: URL, fileLog: FileLog) async {
        // B1'' — STATELESS windowed recompute (seq=W=64, no MLState). Mac: 100% GPU. Decisive A19 placement.
        let window = docs.appendingPathComponent("StatelessWindow_fp16.mlpackage")
        if FileManager.default.fileExists(atPath: window.path) {
            if #available(iOS 17.4, *) {
                await plan(window, units: .all, label: "statelessWindow/all", fileLog: fileLog)
                await plan(window, units: .cpuAndNeuralEngine, label: "statelessWindow/cpuAndANE", fileLog: fileLog)
            }
            await latencyWindow(window, units: .cpuAndGPU, label: "statelessWindow/cpuAndGPU", fileLog: fileLog)
            await latencyWindow(window, units: .cpuAndNeuralEngine, label: "statelessWindow/ANE", fileLog: fileLog)
            await latencyWindow(window, units: .all, label: "statelessWindow/all", fileLog: fileLog)
        } else {
            fileLog.emit("📊 ane-draft statelessWindow SKIPPED — StatelessWindow_fp16.mlpackage not staged")
        }

        // B2 — the REAL Llama-3.2-1B stateful draft (16 layers, 128k-vocab embed gather + GQA repeat). Decisive:
        // does the real draft (much bigger than the synthetic) still A19-ANE-place? Placement is input-agnostic.
        let realDraft = docs.appendingPathComponent("LlamaDraft1B_fp16.mlpackage")
        if FileManager.default.fileExists(atPath: realDraft.path) {
            if #available(iOS 17.4, *) {
                await plan(realDraft, units: .all, label: "llamaDraft1B/all", fileLog: fileLog)
                await plan(realDraft, units: .cpuAndNeuralEngine, label: "llamaDraft1B/cpuAndANE", fileLog: fileLog)
            }
        } else {
            fileLog.emit("📊 ane-draft llamaDraft1B SKIPPED — LlamaDraft1B_fp16.mlpackage not staged")
        }

        // B1' — fixed-window STATEFUL (elementwise one-hot write + additive mask). Mac: 100% GPU. A19 placement.
        let stateful = docs.appendingPathComponent("FixedWindowStateful_fp16.mlpackage")
        if FileManager.default.fileExists(atPath: stateful.path) {
            if #available(iOS 17.4, *) {
                await plan(stateful, units: .all, label: "fixedWindowStateful/all", fileLog: fileLog)
                await plan(stateful, units: .cpuAndNeuralEngine, label: "fixedWindowStateful/cpuAndANE", fileLog: fileLog)
            }
            if #available(iOS 18.0, *) {
                await latencyStateful(stateful, units: .cpuAndGPU, label: "fixedWindowStateful/cpuAndGPU", fileLog: fileLog)
                await latencyStateful(stateful, units: .cpuAndNeuralEngine, label: "fixedWindowStateful/ANE", fileLog: fileLog)
                await latencyStateful(stateful, units: .all, label: "fixedWindowStateful/all", fileLog: fileLog)
            }
        } else {
            fileLog.emit("📊 ane-draft fixedWindowStateful SKIPPED — FixedWindowStateful_fp16.mlpackage not staged")
        }
    }

    /// Latency for the stateless windowed model: input `hidden_window` [1, 64, 2048], no state.
    private static func latencyWindow(_ url: URL, units: MLComputeUnits, label: String, fileLog: FileLog) async {
        do {
            let compiled = try await MLModel.compileModel(at: url)
            let config = MLModelConfiguration(); config.computeUnits = units
            let model = try MLModel(contentsOf: compiled, configuration: config)
            let arr = try MLMultiArray(shape: [1, 64, 2048], dataType: .float32)
            for i in 0..<arr.count { arr[i] = NSNumber(value: Float.random(in: -1...1)) }
            let input = try MLDictionaryFeatureProvider(dictionary: ["hidden_window": arr])
            for _ in 0..<8 { _ = try await model.prediction(from: input) }
            var t = 0.0; let iters = 60
            for _ in 0..<iters {
                let s = DispatchTime.now().uptimeNanoseconds
                _ = try await model.prediction(from: input)
                t += Double(DispatchTime.now().uptimeNanoseconds &- s) / 1_000_000
            }
            fileLog.emit(String(format: "📊 ane-draft latency %@ mean_ms_per_draft_token=%.3f", label, t / Double(iters)))
        } catch {
            fileLog.emit("📊 ane-draft latency \(label) error=\(error)")
        }
    }

    /// Latency for the fixed-window stateful model: hidden [1,1,2048] + host-fed write_onehot/attn_bias [256] + KV state.
    @available(iOS 18.0, *)
    private static func latencyStateful(_ url: URL, units: MLComputeUnits, label: String, fileLog: FileLog) async {
        do {
            let compiled = try await MLModel.compileModel(at: url)
            let config = MLModelConfiguration(); config.computeUnits = units
            let model = try MLModel(contentsOf: compiled, configuration: config)
            let state = model.makeState()
            let hidden = try MLMultiArray(shape: [1, 1, 2048], dataType: .float32)
            for i in 0..<hidden.count { hidden[i] = NSNumber(value: Float.random(in: -1...1)) }
            func stepInput(_ pos: Int) throws -> MLFeatureProvider {
                let oh = try MLMultiArray(shape: [256], dataType: .float32)
                let bias = try MLMultiArray(shape: [256], dataType: .float32)
                for i in 0..<256 {
                    oh[i] = NSNumber(value: i == pos ? 1.0 : 0.0)
                    bias[i] = NSNumber(value: i <= pos ? 0.0 : -1e4)
                }
                return try MLDictionaryFeatureProvider(
                    dictionary: ["hidden": hidden, "write_onehot": oh, "attn_bias": bias])
            }
            for pos in 0..<8 { _ = try await model.prediction(from: stepInput(pos), using: state) }
            var t = 0.0; let steps = 60
            for pos in 8..<(8 + steps) {
                let s = DispatchTime.now().uptimeNanoseconds
                _ = try await model.prediction(from: stepInput(pos), using: state)
                t += Double(DispatchTime.now().uptimeNanoseconds &- s) / 1_000_000
            }
            fileLog.emit(String(format: "📊 ane-draft latency %@ mean_ms_per_step=%.3f", label, t / Double(steps)))
        } catch {
            fileLog.emit("📊 ane-draft latency \(label) error=\(error)")
        }
    }

    // MARK: - MLComputePlan histogram

    @available(iOS 17.4, *)
    private static func plan(_ url: URL, units: MLComputeUnits, label: String, fileLog: FileLog) async {
        do {
            let compiled = try await MLModel.compileModel(at: url)
            let config = MLModelConfiguration()
            config.computeUnits = units
            let plan = try await MLComputePlan.load(contentsOf: compiled, configuration: config)
            var hist: [String: Int] = [:]; var total = 0; var aneCapable = 0
            switch plan.modelStructure {
            case .program(let program):
                for (_, fn) in program.functions {
                    walk(fn.block, plan, &hist, &total, &aneCapable)
                }
            default:
                fileLog.emit("📊 ane-draft plan \(label) structure=unsupported"); return
            }
            let parts = hist.sorted { $0.value > $1.value }.map { "\($0.key)=\($0.value)" }.joined(separator: " ")
            fileLog.emit("📊 ane-draft plan \(label) ops=\(total) \(parts) ane_capable=\(aneCapable)")
        } catch {
            fileLog.emit("📊 ane-draft plan \(label) error=\(error)")
        }
    }

    @available(iOS 17.4, *)
    private static func walk(
        _ block: MLModelStructure.Program.Block, _ plan: MLComputePlan,
        _ hist: inout [String: Int], _ total: inout Int, _ aneCapable: inout Int
    ) {
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

    @available(iOS 17.4, *)
    private static func deviceName(_ d: MLComputeDevice?) -> String {
        switch d {
        case .neuralEngine: return "ane"
        case .gpu: return "gpu"
        case .cpu: return "cpu"
        default: return "unknown"
        }
    }

    // MARK: - Latency A/B

    private static func latency(_ url: URL, units: MLComputeUnits, label: String, fileLog: FileLog) async {
        do {
            let compiled = try await MLModel.compileModel(at: url)
            let config = MLModelConfiguration()
            config.computeUnits = units
            let model = try MLModel(contentsOf: compiled, configuration: config)
            let arr = try MLMultiArray(shape: [1, 1, 2048], dataType: .float32)
            for i in 0..<arr.count { arr[i] = NSNumber(value: Float.random(in: -1...1)) }
            let input = try MLDictionaryFeatureProvider(dictionary: ["hidden": arr])
            for _ in 0..<12 { _ = try await model.prediction(from: input) }   // warm
            var t = 0.0
            let iters = 60
            for _ in 0..<iters {
                let s = DispatchTime.now().uptimeNanoseconds
                _ = try await model.prediction(from: input)
                t += Double(DispatchTime.now().uptimeNanoseconds &- s) / 1_000_000
            }
            fileLog.emit(String(format: "📊 ane-draft latency %@ mean_ms=%.3f", label, t / Double(iters)))
        } catch {
            fileLog.emit("📊 ane-draft latency \(label) error=\(error)")
        }
    }
}
