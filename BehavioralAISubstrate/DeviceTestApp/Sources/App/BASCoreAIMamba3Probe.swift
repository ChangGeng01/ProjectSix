// MARK: - BASCoreAIMamba3Probe — Track E: standalone Mamba-3 ANE decode (BAS_COREAI_MAMBA3_PROBE=1)
//
// The weights-free Mamba-3 device gate. Host convertibility is GREEN (the trapezoidal 3-term recurrence, the
// real 2×2-rotation / data-dependent RoPE, AND the MIMO rank-R einsums all lowered through coreai_torch 0.4.0;
// L=16 int8 = 1.04 GB, under the ~2 GB asset-load wall). This run answers the two on-device unknowns the paper
// cannot:
//   • Q1 — does the 16-layer Mamba-3 (4 fused states: ssm/kprev/vprev/angle) COMPILE + decode on the A19 ANE?
//     (the per-asset layer-count ceiling + the new op mix; crash-safe print() markers survive a SIGABRT.)
//   • Q2 — tok/s + peak MB, and how the rank-R MIMO matmul fares — compare to the landed Mamba-2 (39 tok/s,
//     77 MB on ANE). MIMO raises arithmetic intensity at unchanged state bytes/step → on a bandwidth-bound
//     engine it should be ≈ Mamba-2 speed (not slower); a big slowdown ⇒ the rank-R matmul SERIALIZES on ANE.
// Random weights — numerics are meaningless; this measures OP-graph compile + speed/footprint only.
//
// Stage the asset to Documents (BAS_COREAI_MAMBA3_ASSET, default Mamba3_L16_int8.aimodel). Launch
// BAS_ENDURANCE_AUTOSTART=1 BAS_COREAI_MAMBA3_PROBE=1. Env: BAS_COREAI_MAMBA3_UNITS=ane,gpu,cpu,
// BAS_COREAI_MAMBA3_STEPS, and the four state shapes BAS_COREAI_MAMBA3_{SSM,KPREV,VPREV,ANGLE}.

import Foundation

#if canImport(CoreAI)
import CoreAI
import BASAppleAdapters   // BASCoreAIMamba3Session
#endif

enum BASCoreAIMamba3Probe {

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

    /// print() survives a SIGABRT (unlike buffered os_log) and is captured by `devicectl … --console`.
    private static func mark(_ s: String) { print(s); fflush(stdout) }

    static func run() async {
        mark(String(format: "🐍 mamba3 START footprint0=%.0fMB (beat: nothing — weights-free compile+speed gate)", footprintMB()))
        #if canImport(CoreAI)
        if #available(iOS 27, macOS 27, *) {
            let env = ProcessInfo.processInfo.environment
            let assetName = env["BAS_COREAI_MAMBA3_ASSET"] ?? "Mamba3_L16_int8.aimodel"
            // Carried-state shapes in the converter's declared order — semicolon-separates shapes, comma within.
            // Flat probe: "16,148480". 2-state (ssm;angle): "16,32,64,64;16,32,32".
            let stateShapes = (env["BAS_COREAI_MAMBA3_STATES"] ?? "16,148480")
                .split(separator: ";").map { $0.split(separator: ",").compactMap { Int($0) } }
            let steps = Int(env["BAS_COREAI_MAMBA3_STEPS"] ?? "") ?? 128
            let units = (env["BAS_COREAI_MAMBA3_UNITS"] ?? "ane")
                .split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }

            guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                mark("🐍 mamba3 ERROR=no-docs"); return
            }
            let asset = docs.appendingPathComponent(assetName)
            guard FileManager.default.fileExists(atPath: asset.path) else {
                mark("🐍 mamba3 ERROR=\(assetName) missing — stage it into Documents"); return
            }

            for u in units {
                let opts: SpecializationOptions
                switch u {
                case "cpu": opts = .cpuOnly
                case "gpu": opts = SpecializationOptions(preferredComputeUnitKind: .gpu)
                case "ane": opts = SpecializationOptions(preferredComputeUnitKind: .neuralEngine)
                default: mark("🐍 mamba3 unknown unit \(u)"); continue
                }
                mark("🐍 mamba3 loading unit=\(u) asset=\(assetName) states\(stateShapes)…")
                let t0 = DispatchTime.now().uptimeNanoseconds
                let session: BASCoreAIMamba3Session
                do {
                    session = try await BASCoreAIMamba3Session(
                        assetURL: asset, stateShapes: stateShapes, options: opts)
                    let loadMs = Double(DispatchTime.now().uptimeNanoseconds &- t0) / 1_000_000
                    mark(String(format: "🐍 mamba3 loaded unit=%@ load_ms=%.0f footprint=%.0fMB (Q1: 16L Mamba-3 compiles on %@ ✅)",
                                u, loadMs, footprintMB(), u))
                } catch {
                    mark("🐍 mamba3 ERROR unit=\(u) \(error)  (Q1: did NOT compile/run on \(u))"); continue
                }

                // WARMUP: discard the first few steps (one-time per-launch ANE program load lands on step 1).
                do {
                    var tok = 1
                    for _ in 0..<4 { tok = try await session.step(token: tok) }
                } catch {
                    mark("🐍 mamba3 unit=\(u) WARMUP ERROR=\(error)"); continue
                }

                // TIMED decode loop (greedy argmax feedback — exercises the full step incl. argmax read-back).
                let pre = footprintMB()
                let s0 = DispatchTime.now().uptimeNanoseconds
                var tok = 1
                var ok = 0
                do {
                    for _ in 0..<steps { tok = try await session.step(token: tok); ok += 1 }
                } catch {
                    mark("🐍 mamba3 unit=\(u) DECODE ERROR after \(ok) steps=\(error)"); continue
                }
                let ms = Double(DispatchTime.now().uptimeNanoseconds &- s0) / 1_000_000
                let tps = ms > 0 ? Double(ok) * 1000.0 / ms : 0
                mark(String(format:
                    "🐍 mamba3 unit=%@ steps=%d wall_ms=%.0f tok/s=%.1f peak_MB=%.0f (Mamba-2 ref: 39 tok/s, 77MB on ANE) "
                    + "last_tok=%d",
                    u, ok, ms, tps, footprintMB(), tok))
                _ = pre
            }
            mark("🐍 mamba3 DONE — read: Q1 (compiles on ane?), tok/s vs Mamba-2 39, peak_MB vs 77 (MIMO efficient if ≈, serialized if ≪).")
        } else {
            mark("🐍 mamba3 SKIP — needs iOS 27 / macOS 27")
        }
        #else
        mark("🐍 mamba3 SKIP — CoreAI not in this build (default toolchain)")
        #endif
    }
}
