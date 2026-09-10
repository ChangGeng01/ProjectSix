// MARK: - BASCoreAIPrefillProbe — STEP 2 of the on-device DUET probe (BAS_COREAI_PREFILL_PROBE=1)
//
// STEP 1 proved the prefill graph (cumsum + masked-exp-segsum + MLA softmax+triu) CONVERTS to CoreAI at the host level.
// This is the DEVICE gate the plan calls the real STEP-2 decision point: does the single-layer prefill asset LOAD + RUN
// on the A19 GPU, and does its boundary-state output NUMERICALLY MATCH the host (rel-err < 1e-2)? If yes, scaling to the
// full 24L hybrid prefill asset (STEP 3) is mechanical; if it faults/diverges, pivot to a per-token step_ref warm-up prefill.
//
// Input is the bit-reproducible det_input from Tools/mamba3_prefill_probe.py (xs[i] = Float16((i%97 - 48)/480)), so the
// device feeds the SAME input the host reference (HOSTREF lines) was computed on — no input staging needed. Stage the two
// L1 assets to Documents. Launch: BAS_ENDURANCE_AUTOSTART=1 BAS_COREAI_PREFILL_PROBE=1 [BAS_COREAI_PREFILL_UNIT=gpu|ane|cpu].

import Foundation

#if canImport(CoreAI)
import CoreAI
import BASAppleAdapters   // BASCoreAIPrefillSession
#endif

enum BASCoreAIPrefillProbe {

    private static func footprintMB() -> Double {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let kr = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        return kr == KERN_SUCCESS ? Double(info.phys_footprint) / 1_048_576 : -1
    }

    private static func mark(_ s: String) { print(s); fflush(stdout) }

    #if canImport(CoreAI)
    @available(iOS 27, macOS 27, *)
    private static func ndStats(_ a: NDArray) -> (norm: Double, sum: Double, head: [Float]) {
        let count = a.shape.reduce(1, *)
        var sumsq = 0.0
        var sum = 0.0
        var head: [Float] = []
        a.view(as: Float16.self).withUnsafePointer { pointer, _, _ in
            var k = 0
            while k < count {
                let v = Double(pointer[k])
                sumsq += v * v
                sum += v
                if head.count < 4 { head.append(Float(pointer[k])) }
                k += 1
            }
        }
        return (sumsq.squareRoot(), sum, head)
    }
    #endif

    static func run() async {
        mark(String(format: "🧩 prefill START footprint0=%.0fMB (STEP 2: does the prefill asset run+match on the A19 GPU?)", footprintMB()))
        #if canImport(CoreAI)
        if #available(iOS 27, macOS 27, *) {
            let env = ProcessInfo.processInfo.environment
            let unit = env["BAS_COREAI_PREFILL_UNIT"] ?? "gpu"
            let T = Int(env["BAS_COREAI_PREFILL_T"] ?? "64") ?? 64     // T>64 → the scan_chunked path (real-corpus prefill)
            let D = 1024
            var xs = [Float16](repeating: 0, count: T * D)            // det_input mirror — bit-identical to Python
            for i in 0..<(T * D) { xs[i] = Float16((Double(i % 97) - 48.0) / 480.0) }
            let x = NDArray(scalars: xs, shape: [T, D])

            guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                mark("🧩 prefill ERROR=no-docs"); return
            }
            let opts: SpecializationOptions
            switch unit {
            case "cpu": opts = .cpuOnly
            case "ane": opts = SpecializationOptions(preferredComputeUnitKind: .neuralEngine)
            default: opts = SpecializationOptions(preferredComputeUnitKind: .gpu)
            }
            mark("🧩 prefill availableComputeKinds=\(ComputeUnitKind.availableKinds) unit=\(unit)")

            var probes: [(tag: String, asset: String, input: String, outs: [String])] = [
                ("Hybrid", env["BAS_COREAI_PREFILL_HYBRID_ASSET"] ?? "Mamba3HybridPrefill_L24_T\(T).aimodel", "x_seq",
                 ["angle_all", "ssm_all", "kprev_all", "vprev_all", "mla_all"]),
            ]
            if T == 64 {                                              // the L1 single-layer probes are T=64-only assets
                probes.insert(("Mamba", env["BAS_COREAI_PREFILL_MAMBA_ASSET"] ?? "Mamba3MambaPrefill_L1_prefill.aimodel", "x_seq",
                               ["out_last", "angle", "ssm", "kprev", "vprev"]), at: 0)
                probes.insert(("MLA", env["BAS_COREAI_PREFILL_MLA_ASSET"] ?? "Mamba3MLAPrefill_L1_prefill.aimodel", "x_seq",
                               ["out_last", "c_kv"]), at: 1)
            }
            for p in probes {
                let asset = docs.appendingPathComponent(p.asset)
                guard FileManager.default.fileExists(atPath: asset.path) else {
                    mark("🧩 prefill \(p.tag) ERROR=\(p.asset) missing — stage it into Documents"); continue
                }
                let session: BASCoreAIPrefillSession
                let t0 = DispatchTime.now().uptimeNanoseconds
                do {
                    session = try await BASCoreAIPrefillSession(assetURL: asset, options: opts)
                } catch {
                    mark("🧩 prefill \(p.tag) LOAD ERROR unit=\(unit) \(error)  (did NOT compile/run on \(unit))"); continue
                }
                let loadMs = Double(DispatchTime.now().uptimeNanoseconds &- t0) / 1_000_000
                mark(String(format: "🧩 prefill %@ loaded unit=%@ load_ms=%.0f footprint=%.0fMB", p.tag, unit, loadMs, footprintMB()))

                var outMap: [String: NDArray] = [:]
                var firstMs = 0.0
                var bestMs = Double.greatestFiniteMagnitude
                do {
                    for r in 0..<4 {                                  // r0 = cold (incl. one-time GPU shader compile); r1-3 = warm compute
                        let r0 = DispatchTime.now().uptimeNanoseconds
                        outMap = try await session.run(input: x, inputName: p.input, outputNames: p.outs)
                        let ms = Double(DispatchTime.now().uptimeNanoseconds &- r0) / 1_000_000
                        if r == 0 { firstMs = ms } else { bestMs = min(bestMs, ms) }
                    }
                } catch {
                    mark("🧩 prefill \(p.tag) RUN ERROR unit=\(unit) \(error)"); continue
                }
                mark(String(format: "🧩 prefill %@ run_ms cold=%.1f warm_best=%.1f (cold-warm=%.0f ⇒ one-time compile) footprint=%.0fMB",
                            p.tag, firstMs, bestMs, firstMs - bestMs, footprintMB()))
                for name in p.outs {
                    guard let nd = outMap[name] else { mark("🧩 prefill \(p.tag).\(name) MISSING from outputs"); continue }
                    let s = ndStats(nd)
                    mark(String(format: "🧩 prefill DEV %@.%@ shape=%@ norm=%.4f sum=%.4f head=%@",
                                p.tag, name, "\(nd.shape)", s.norm, s.sum, "\(s.head)"))
                }
            }
            mark("🧩 prefill DONE — compare DEV norm/sum/head to the HOSTREF lines (rel-err<1e-2 ⇒ prefill runs + is numerically correct on the A19).")
        } else {
            mark("🧩 prefill SKIP — needs iOS 27 / macOS 27")
        }
        #else
        mark("🧩 prefill SKIP — CoreAI not in this build (default toolchain)")
        #endif
    }
}
