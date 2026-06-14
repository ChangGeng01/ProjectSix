// MARK: - BASCoreAIMambaSaguaroProbe — Track E: serial Saguaro on device (BAS_COREAI_SAGUARO_PROBE=1)
//
// THE end-to-end device measurement for 全面开发 Mamba: an MLX Llama-3.2-3B TARGET verifying a CoreAI Mamba
// (Llamba-1B) DRAFT via the serial BASSaguaroLoop. Answers the two open questions in one run:
//   • Q1 — does the 16-layer Mamba draft compile + decode on the A19 ANE at all (BAS_COREAI_SAGUARO_UNITS=ane)?
//     (the per-asset layer-count ceiling; crash-safe print() markers survive a SIGABRT.)
//   • serial Saguaro tok/s + speedup vs pure target greedy (the K=0 baseline), with the draft/target time split —
//     so we know whether the draft is fast enough for a sequential win, or whether overlap is required.
// Byte-identity (specTokens == baseTokens) must hold by construction.
//
// Stage BOTH artifacts to Documents: the Mamba .aimodel (BAS_COREAI_SAGUARO_ASSET, default Llamba1B_fp16.aimodel)
// + the MLX 3B (resolved by MLXModelCatalog). Launch BAS_ENDURANCE_AUTOSTART=1 BAS_COREAI_SAGUARO_PROBE=1.
// Env: BAS_COREAI_SAGUARO_UNITS=ane,gpu,cpu (draft placement), BAS_COREAI_SAGUARO_K, BAS_COREAI_SAGUARO_MAXTOK,
//      BAS_COREAI_MAMBA_CONV / BAS_COREAI_MAMBA_SSM (draft state shapes).

import Foundation
import BASOrgan
import BASMLXAdapter

#if canImport(CoreAI)
import CoreAI
import BASAppleAdapters   // BASCoreAIMambaSession, BASSaguaroSpeculator
#endif

enum BASCoreAIMambaSaguaroProbe {

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

    private static let workloads: [(name: String, prompt: String)] = [
        ("factual", "The capital of France is Paris. List three other European capital cities and their countries."),
        ("code", "Write a Swift function that returns the nth Fibonacci number using iteration."),
        ("narrative", "Once upon a time in a quiet seaside town, a lighthouse keeper discovered"),
    ]

    static func run() async {
        mark(String(format: "📊 saguaro START footprint0=%.0fMB (beat: pure-target greedy; byte-identity must hold)", footprintMB()))
        #if canImport(CoreAI)
        if #available(iOS 27, macOS 27, *) {
            let env = ProcessInfo.processInfo.environment
            let assetName = env["BAS_COREAI_SAGUARO_ASSET"] ?? "Llamba1B_fp16.aimodel"
            let convShape = (env["BAS_COREAI_MAMBA_CONV"] ?? "16,6144,4").split(separator: ",").compactMap { Int($0) }
            let ssmShape = (env["BAS_COREAI_MAMBA_SSM"] ?? "16,32,64,64").split(separator: ",").compactMap { Int($0) }
            let K = Int(env["BAS_COREAI_SAGUARO_K"] ?? "") ?? 4
            let maxTok = Int(env["BAS_COREAI_SAGUARO_MAXTOK"] ?? "") ?? 96
            let overlap = (env["BAS_COREAI_OVERLAP"] ?? "0") == "1"   // measure ANE-draft ∥ GPU-verify ρ
            let units = (env["BAS_COREAI_SAGUARO_UNITS"] ?? "ane")
                .split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }

            guard convShape.count == 3, ssmShape.count == 4,
                  let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                mark("📊 saguaro ERROR=bad-shapes-or-no-docs"); return
            }
            let asset = docs.appendingPathComponent(assetName)
            guard FileManager.default.fileExists(atPath: asset.path) else {
                mark("📊 saguaro ERROR=\(assetName) missing — stage it into Documents"); return
            }

            // Load the MLX 3B target ONCE (shared across draft-placement units).
            let adapter = MLXOrganAdapter(
                model: MLXModelCatalog.speculativeOptimalTarget, maxOutputTokens: maxTok, speculativeDecoding: .off)
            do {
                try await adapter.loadModel()
                mark(String(format: "📊 saguaro target(MLX 3B) loaded footprint=%.0fMB", footprintMB()))
            } catch {
                mark("📊 saguaro ERROR=target-load \(error)"); return
            }

            for u in units {
                let opts: SpecializationOptions
                switch u {
                case "cpu": opts = .cpuOnly
                case "gpu": opts = SpecializationOptions(preferredComputeUnitKind: .gpu)
                case "ane": opts = SpecializationOptions(preferredComputeUnitKind: .neuralEngine)
                default: mark("📊 saguaro unknown unit \(u)"); continue
                }
                mark("📊 saguaro draft loading unit=\(u) asset=\(assetName) conv\(convShape) ssm\(ssmShape)…")
                let session: BASCoreAIMambaSession
                do {
                    session = try await BASCoreAIMambaSession(
                        assetURL: asset, convShape: convShape, ssmShape: ssmShape, options: opts)
                    mark(String(format: "📊 saguaro draft loaded unit=%@ footprint=%.0fMB (Q1: 16L Mamba compiles on %@ ✅)",
                                u, footprintMB(), u))
                } catch {
                    mark("📊 saguaro draft ERROR unit=\(u) \(error)  (Q1: did NOT compile/run on \(u))"); continue
                }

                // Overlap mode: measure ANE-draft ∥ GPU-verify ρ instead of the serial workloads.
                if overlap {
                    await measureOverlap(adapter: adapter, session: session, unit: u, K: K)
                    continue
                }

                let speculator = BASSaguaroSpeculator(session: session)
                for w in workloads {
                    let request = BASOrganRequest(
                        requestID: "saguaro-\(u)-\(w.name)", role: .core,
                        preset: .greedyDeterministic, instruction: w.prompt, context: [])
                    do {
                        let ab = try await adapter.saguaroAB(for: request, draft: speculator, numDraftTokens: K)
                        let identical = ab.specTokens == ab.baseTokens
                        let speedup = ab.specMs > 0 ? ab.baseMs / ab.specMs : 0
                        let meanAcc = ab.rounds > 0 ? Double(ab.accepted) / Double(ab.rounds) : 0
                        let specTps = ab.specMs > 0 ? Double(ab.specTokens.count) * 1000.0 / ab.specMs : 0
                        let baseTps = ab.baseMs > 0 ? Double(ab.baseTokens.count) * 1000.0 / ab.baseMs : 0
                        mark(String(format:
                            "📊 saguaro unit=%@ workload=%@ tokens=%d rounds=%d mean_acc=%.2f/%d "
                            + "spec_tok/s=%.1f base_tok/s=%.1f speedup=%.2fx draft_ms=%.0f target_ms=%.0f "
                            + "peak_MB=%.0f byte_identical=%@",
                            u, w.name, ab.specTokens.count, ab.rounds, meanAcc, K,
                            specTps, baseTps, speedup, ab.draftMs, ab.targetMs, footprintMB(),
                            identical ? "YES" : "NO"))
                    } catch {
                        mark("📊 saguaro unit=\(u) workload=\(w.name) ERROR=\(error)")
                    }
                }
            }
            mark("📊 saguaro DONE — read: Q1 (draft compiles on ane?), spec tok/s vs base, draft_ms/target_ms split, byte_identical.")
        } else {
            mark("📊 saguaro SKIP — needs iOS 27 / macOS 27")
        }
        #else
        mark("📊 saguaro SKIP — CoreAI not in this build (default toolchain)")
        #endif
    }

    #if canImport(CoreAI)
    /// Measure the ANE-draft ∥ GPU-verify overlap factor ρ = serial_wall / concurrent_wall. R2: this is OS-scheduler
    /// concurrency of two independent tasks (the CoreAI executor running `session.step` ∥ the MLX container actor
    /// running target forwards), NOT two CoreAI `ComputeStream`s (which can't span MLX). ρ>1.3 ⇒ the two engines
    /// overlap → wire `overlap: .computeStream`; ρ≲1.1 ⇒ they contend on memory bandwidth → ship serial only. The
    /// Core ML answer was 0.34× (concurrent SLOWER); whether CoreAI flips it is THE open device question.
    @available(iOS 27, macOS 27, *)
    private static func measureOverlap(
        adapter: MLXOrganAdapter, session: BASCoreAIMambaSession, unit: String, K: Int
    ) async {
        let req = BASOrganRequest(
            requestID: "saguaro-overlap-\(unit)", role: .core,
            preset: .greedyDeterministic, instruction: "Describe the ocean in a few sentences.", context: [])
        let N = 8           // target verify forwards (GPU work unit)
        let M = K * N       // matched draft steps (ANE work — ~K draft steps per target forward)
        do {
            // Serial halves, each measured alone.
            let tMs = try await adapter.saguaroTargetForwardsMs(for: req, targetForwards: N)
            let dMs = await draftStepsMs(session, steps: M)
            let serialWall = tMs + dMs
            // Concurrent: ANE draft ∥ GPU target via two tasks.
            let c0 = DispatchTime.now().uptimeNanoseconds
            async let tC = adapter.saguaroTargetForwardsMs(for: req, targetForwards: N)
            async let dC = draftStepsMs(session, steps: M)
            _ = try await (tC, dC)
            let concWall = Double(DispatchTime.now().uptimeNanoseconds &- c0) / 1_000_000
            let rho = concWall > 0 ? serialWall / concWall : 0
            mark(String(format:
                "📊 saguaro OVERLAP unit=%@ target_ms=%.0f(×%d) draft_ms=%.0f(×%d) serial_ms=%.0f conc_ms=%.0f "
                + "rho=%.2f (ρ>1.3 ⇒ overlap pays; ρ≲1.1 ⇒ contention, serial only; Core ML was 0.34×)",
                unit, tMs, N, dMs, M, serialWall, concWall, rho))
        } catch {
            mark("📊 saguaro OVERLAP unit=\(unit) ERROR=\(error)")
        }
    }

    /// Wall-ms of `steps` raw CoreAI Mamba draft forwards (the ANE work unit).
    @available(iOS 27, macOS 27, *)
    private static func draftStepsMs(_ session: BASCoreAIMambaSession, steps: Int) async -> Double {
        let t0 = DispatchTime.now().uptimeNanoseconds
        var tok = 1
        var i = 0
        while i < steps { tok = (try? await session.step(token: max(0, tok))) ?? 1; i += 1 }
        return Double(DispatchTime.now().uptimeNanoseconds &- t0) / 1_000_000
    }
    #endif
}
