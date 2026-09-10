// MARK: - BASCoreAIMamba3DualProbe — Asymmetric-Duo switch probe (BAS_COREAI_DUAL_PROBE=1)
//
// Answers the operator's open questions on the A19 ANE, in one run:
//   Q1 — does the [1,K] conv-mode VERIFY graph compile + run on the ANE at all? (the unmeasured risk; the
//        recurrent [1,1] decode is already proven, the multi-token verify is NOT.)
//   Q2 — verify[1,K] latency vs decode[1,1] latency (is one verify cheaper than K recurrent steps?).
//   Q3 — the decode↔verify SWITCH overhead (both functions in ONE asset sharing state → should be ~free).
// Random-weight asset → compile + speed only. Stage Mamba3dual_L{L}_K{K}_int4.aimodel to Documents.
// Env: BAS_COREAI_DUAL_ASSET, BAS_COREAI_DUAL_ANGLE/SSM (state shapes), BAS_COREAI_DUAL_K, BAS_COREAI_DUAL_UNITS,
//      BAS_COREAI_DUAL_STEPS.

import Foundation

#if canImport(CoreAI)
import CoreAI
import BASAppleAdapters
#endif

enum BASCoreAIMamba3DualProbe {

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
    private static func ms(_ t0: UInt64) -> Double { Double(DispatchTime.now().uptimeNanoseconds &- t0) / 1_000_000 }

    static func run() async {
        mark(String(format: "🔀 dual START footprint0=%.0fMB", footprintMB()))
        #if canImport(CoreAI)
        if #available(iOS 27, macOS 27, *) {
            let env = ProcessInfo.processInfo.environment
            let assetName = env["BAS_COREAI_DUAL_ASSET"] ?? "Mamba3dual_L8_K4_int4.aimodel"
            func shape(_ k: String, _ d: String) -> [Int] { (env[k] ?? d).split(separator: ",").compactMap { Int($0) } }
            let angleShape = shape("BAS_COREAI_DUAL_ANGLE", "8,32,32")
            let ssmShape = shape("BAS_COREAI_DUAL_SSM", "8,32,64,64")
            let K = Int(env["BAS_COREAI_DUAL_K"] ?? "") ?? 4
            let steps = Int(env["BAS_COREAI_DUAL_STEPS"] ?? "") ?? 64
            let vocab = 128256
            let units = (env["BAS_COREAI_DUAL_UNITS"] ?? "ane").split(separator: ",").map {
                String($0).trimmingCharacters(in: .whitespaces)
            }
            guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                mark("🔀 dual ERROR=no-docs"); return
            }
            let asset = docs.appendingPathComponent(assetName)
            guard FileManager.default.fileExists(atPath: asset.path) else {
                mark("🔀 dual ERROR=\(assetName) missing — stage it into Documents"); return
            }

            for u in units {
                let opts: SpecializationOptions
                switch u {
                case "cpu": opts = .cpuOnly
                case "gpu": opts = SpecializationOptions(preferredComputeUnitKind: .gpu)
                case "ane": opts = SpecializationOptions(preferredComputeUnitKind: .neuralEngine)
                default: mark("🔀 dual unknown unit \(u)"); continue
                }
                mark("🔀 dual loading unit=\(u) asset=\(assetName) angle\(angleShape) ssm\(ssmShape) K=\(K)…")
                let t0 = DispatchTime.now().uptimeNanoseconds
                let session: BASCoreAIMamba3DualSession
                do {
                    session = try await BASCoreAIMamba3DualSession(
                        assetURL: asset, angleShape: angleShape, ssmShape: ssmShape,
                        vocab: vocab, k: K, options: opts)
                    mark(String(format: "🔀 dual loaded unit=%@ load_ms=%.0f footprint=%.0fMB (decode+verify both compiled on %@ ✅)",
                                u, ms(t0), footprintMB(), u))
                } catch {
                    mark("🔀 dual ERROR unit=\(u) \(error)  (did NOT compile — likely the [1,K] verify graph)"); continue
                }

                // WARMUP each function once (one-time per-launch ANE program load).
                do {
                    _ = try await session.decodeStep(token: 1)
                    _ = try await session.verifyChunk(tokens: Array(repeating: 1, count: K))
                } catch {
                    mark("🔀 dual unit=\(u) WARMUP ERROR=\(error)"); continue
                }

                // Q2a — decode[1,1] latency.
                var tok = 1
                let d0 = DispatchTime.now().uptimeNanoseconds
                do { for _ in 0..<steps { tok = try await session.decodeStep(token: max(0, tok)) } }
                catch { mark("🔀 dual unit=\(u) DECODE ERROR=\(error)"); continue }
                let decMs = ms(d0) / Double(steps)

                // Q2b — verify[1,K] latency (per chunk + per token).
                let chunks = max(1, steps / K)
                let v0 = DispatchTime.now().uptimeNanoseconds
                var lastV = [Int]()
                do { for _ in 0..<chunks { lastV = try await session.verifyChunk(tokens: Array(repeating: max(0, tok), count: K)) } }
                catch { mark("🔀 dual unit=\(u) VERIFY ERROR=\(error)  (the [1,\(K)] conv graph failed on \(u))"); continue }
                let verChunkMs = ms(v0) / Double(chunks)

                // Q3 — switch overhead: alternate decode/verify, compare to pure-decode + pure-verify sum.
                let sw0 = DispatchTime.now().uptimeNanoseconds
                let rounds = max(1, steps / (K + 1))
                do {
                    for _ in 0..<rounds {
                        _ = try await session.verifyChunk(tokens: Array(repeating: max(0, tok), count: K))
                        tok = try await session.decodeStep(token: max(0, tok))
                    }
                } catch { mark("🔀 dual unit=\(u) SWITCH ERROR=\(error)"); continue }
                let swRoundMs = ms(sw0) / Double(rounds)
                let expectedRoundMs = verChunkMs + decMs           // if switch were free
                let switchOverheadMs = swRoundMs - expectedRoundMs

                mark(String(format:
                    "🔀 dual unit=%@ decode_ms=%.2f (%.1f tok/s) | verify_ms=%.2f/chunk = %.2f/tok (K=%d) | "
                    + "verify-vs-Kdecode=%.2fx | switch_round_ms=%.2f expected=%.2f overhead=%.2fms | peak_MB=%.0f lastV=%@",
                    u, decMs, 1000.0/max(0.001,decMs), verChunkMs, verChunkMs/Double(K), K,
                    (Double(K)*decMs)/max(0.001,verChunkMs), swRoundMs, expectedRoundMs, switchOverheadMs,
                    footprintMB(), "\(lastV.prefix(4))"))
            }
            mark("🔀 dual DONE — read: Q1 verify[1,K] compiles on ane?, Q2 verify/tok vs decode, Q3 switch overhead (~0 if shared asset).")
        } else {
            mark("🔀 dual SKIP — needs iOS 27 / macOS 27")
        }
        #else
        mark("🔀 dual SKIP — CoreAI not in this build")
        #endif
    }
}
