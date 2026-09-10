// MARK: - BASCoreAIDuetProbe — STEP 5/6/7: the full on-device DUET E2E (BAS_COREAI_DUET_PROBE=1)
//
// Orchestrates the in-memory STATE-VALUE handoff in ONE process via SEQUENTIAL-LOAD (no disk yet; no co-residency): load
// prefill → run prompt → COPY the 5 boundary-state tensors out into Swift memory → DEINIT the prefill AIModel → load decode
// (2nd AIModel.load). NOTE: the Track E co-load SIGSEGV was ANE-specific; this runs on GPU and does NOT attempt a co-load,
// so it shows sequential-load WORKS on GPU — it does not re-demonstrate (or need) dodging the ANE co-load wall. init the 6
// decode states from the handoff (4 Mamba stacked
// direct + mla_kv = prompt latents scattered into [0:promptLen] + mla_fill=promptLen) → teacher-forced decode of the
// continuation → DEV_CONT_ARGMAX. Compare to the host MODE=ref HOSTREF_CONT_ARGMAX: identical ⇒ the DUET reproduces the
// monolithic decode on the A19, end-to-end.
//
// Deterministic tokens tok[i]=(i*17+5)%VOCAB (mirrors mamba3_hybrid_decode_deploy.ref_e2e). Stage both assets to Documents.

import Foundation

#if canImport(CoreAI)
import CoreAI
import BASAppleAdapters
#endif

enum BASCoreAIDuetProbe {
    static let VOCAB = 4096, PROMPT = 64, CONT = 32, MAX_SEQ = 256, N_MLA = 4, DC = 128

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
    private static func copyF16(_ a: NDArray) -> [Float16] {
        let n = a.shape.reduce(1, *)
        var out = [Float16](repeating: 0, count: n)
        a.view(as: Float16.self).withUnsafePointer { p, _, _ in for k in 0..<n { out[k] = p[k] } }
        return out
    }
    #endif

    static func run() async {
        mark(String(format: "🎻 duet START footprint0=%.0fMB (STEP 5/6/7: does the device DUET reproduce the host decode?)", footprintMB()))
        #if canImport(CoreAI)
        if #available(iOS 27, macOS 27, *) {
            let env = ProcessInfo.processInfo.environment
            let unit = env["BAS_COREAI_DUET_UNIT"] ?? "gpu"
            let opts: SpecializationOptions = unit == "cpu" ? .cpuOnly
                : unit == "ane" ? SpecializationOptions(preferredComputeUnitKind: .neuralEngine)
                : SpecializationOptions(preferredComputeUnitKind: .gpu)
            guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { mark("🎻 duet ERROR=no-docs"); return }
            let prefillName = env["BAS_COREAI_DUET_PREFILL"] ?? "Mamba3HybridPrefill_L24_T64_tok.aimodel"
            let decodeName = env["BAS_COREAI_DUET_DECODE"] ?? "Mamba3HybridDecode_L24_M256.aimodel"
            let prefillAsset = docs.appendingPathComponent(prefillName)
            let decodeAsset = docs.appendingPathComponent(decodeName)
            for (n, u) in [(prefillName, prefillAsset), (decodeName, decodeAsset)] where !FileManager.default.fileExists(atPath: u.path) {
                mark("🎻 duet ERROR=\(n) missing — stage it into Documents"); return
            }

            let tok = (0..<(PROMPT + CONT)).map { ($0 * 17 + 5) % VOCAB }   // deterministic, mirrors ref_e2e

            // ---- PHASE 1: prefill the prompt, copy the handoff state OUT, then RELEASE the prefill model ----
            var handoff: [String: [Float16]] = [:]
            do {
                var pf: BASCoreAIPrefillSession? = try await BASCoreAIPrefillSession(assetURL: prefillAsset, options: opts)
                let promptIDs = NDArray(scalars: (0..<PROMPT).map { Int32(tok[$0]) }, shape: [PROMPT])
                let names = ["angle_all", "ssm_all", "kprev_all", "vprev_all", "mla_all"]
                let out = try await pf!.run(input: promptIDs, inputName: "input_ids", outputNames: names)
                for n in names { guard let nd = out[n] else { mark("🎻 duet prefill missing \(n)"); return }; handoff[n] = copyF16(nd) }
                mark(String(format: "🎻 duet prefill done footprint=%.0fMB (states copied out)", footprintMB()))
                pf = nil                                                   // release the prefill AIModel BEFORE the decode load
            } catch { mark("🎻 duet PREFILL ERROR \(error)"); return }
            await Task.yield()
            mark(String(format: "🎻 duet prefill released footprint=%.0fMB (phys_footprint only — mmap'd weights not counted; loading decode sequentially)", footprintMB()))

            // ---- PHASE 2: build the 6 decode init states from the handoff ----
            func nd(_ key: String, _ shape: [Int]) -> NDArray { NDArray(scalars: handoff[key]!, shape: shape) }
            var mlaKv = [Float16](repeating: 0, count: N_MLA * MAX_SEQ * DC)   // [4,256,128]; prompt latents in [:, 0:PROMPT, :]
            let mlaAll = handoff["mla_all"]!                                  // [4,64,128] flat
            for l in 0..<N_MLA { for t in 0..<PROMPT { for d in 0..<DC {
                mlaKv[(l * MAX_SEQ + t) * DC + d] = mlaAll[(l * PROMPT + t) * DC + d]
            }}}
            let inits: [NDArray] = [
                nd("angle_all", [20, 16, 32]), nd("ssm_all", [20, 16, 64, 64]),
                nd("kprev_all", [20, 16, 4, 64]), nd("vprev_all", [20, 16, 64, 4]),
                NDArray(scalars: mlaKv, shape: [N_MLA, MAX_SEQ, DC]),
                NDArray(scalars: [Float16](repeating: Float16(PROMPT), count: N_MLA), shape: [N_MLA, 1]),
            ]

            // ---- PHASE 3: load decode (2nd AIModel.load), teacher-forced decode of the continuation ----
            let dec: BASCoreAIHybridDecodeSession
            do {
                dec = try await BASCoreAIHybridDecodeSession(assetURL: decodeAsset, initialStates: inits, initialFill: PROMPT, options: opts)
            } catch { mark("🎻 duet DECODE-LOAD ERROR (sequential-load on GPU) \(error)"); return }
            mark(String(format: "🎻 duet decode loaded footprint=%.0fMB states=%@ (sequential-load on GPU OK)", footprintMB(), "\(dec.stateNames)"))

            var argmax: [Int] = []
            let s0 = DispatchTime.now().uptimeNanoseconds
            do {
                for j in 0..<CONT { argmax.append(try await dec.step(token: tok[PROMPT + j])) }
            } catch { mark("🎻 duet DECODE ERROR after \(argmax.count) steps \(error)"); return }
            let ms = Double(DispatchTime.now().uptimeNanoseconds &- s0) / 1_000_000
            mark(String(format: "🎻 duet decode %d steps wall_ms=%.0f tok/s=%.1f footprint=%.0fMB", argmax.count, ms,
                        ms > 0 ? Double(argmax.count) * 1000 / ms : 0, footprintMB()))
            mark("🎻 duet DEV_CONT_ARGMAX=\(argmax.map(String.init).joined(separator: ","))")
            mark("🎻 duet DONE — compare DEV_CONT_ARGMAX to host MODE=ref HOSTREF_CONT_ARGMAX. Identical ⇒ device DUET == host monolithic.")
        } else { mark("🎻 duet SKIP — needs iOS 27") }
        #else
        mark("🎻 duet SKIP — CoreAI not in this build")
        #endif
    }
}
