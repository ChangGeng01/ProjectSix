// MARK: - BASCoreAIStateLakeProbe — cross-launch StateLake persistence on the A19 (BAS_COREAI_STATELAKE_PROBE=1)
//
// Proves the device half of the StateLake: a state SERIALIZED TO DISK (.statelake, host-written) is rehydrated on the
// A19 and decodes — and a WRONG binding-key is rejected fail-closed. Reads Documents/decode_state.statelake → 6 decode
// states → BASCoreAIHybridDecodeSession → decode the deterministic continuation → DEV argmax (compare to the host
// HOSTREF_STATELAKE_ARGMAX). The expected binding-key is passed via BAS_COREAI_STATELAKE_BKEY (the host-computed key;
// production embeds it in the asset). Stage the .statelake + the decode .aimodel to Documents.

import Foundation

#if canImport(CoreAI)
import CoreAI
import BASAppleAdapters
#endif

enum BASCoreAIStateLakeProbe {
    static let VOCAB = 4096, PROMPT = 64, CONT = 32

    private static func mark(_ s: String) { print(s); fflush(stdout) }

    static func run() async {
        mark("🗄️ statelake START (cross-launch persistence: read a disk .statelake → decode on the A19)")
        #if canImport(CoreAI)
        if #available(iOS 27, macOS 27, *) {
            let env = ProcessInfo.processInfo.environment
            guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { mark("🗄️ ERROR=no-docs"); return }
            let lakeName = env["BAS_COREAI_STATELAKE_NAME"] ?? "decode_state.statelake"
            let decodeName = env["BAS_COREAI_STATELAKE_DECODE"] ?? "Mamba3HybridDecode_L24_M256.aimodel"
            let bkey = env["BAS_COREAI_STATELAKE_BKEY"] ?? ""
            let lake = docs.appendingPathComponent(lakeName)
            let asset = docs.appendingPathComponent(decodeName)
            for (n, u) in [(lakeName, lake), (decodeName, asset)] where !FileManager.default.fileExists(atPath: u.path) {
                mark("🗄️ ERROR=\(n) missing — stage it into Documents"); return
            }
            let order = ["angle_all", "ssm_all", "kprev_all", "vprev_all", "mla_kv", "mla_fill"]

            // (A) FAIL-CLOSED: a wrong binding-key MUST be rejected
            do {
                _ = try BASStateLakeReader.load(lake, expectedBindingKey: String(repeating: "de", count: 16), stateOrder: order)
                mark("🗄️ (A) fail-closed test: FAIL — accepted a stale binding-key!")
            } catch {
                mark("🗄️ (A) fail-closed test: PASS — rejected stale key (\(error))")
            }

            // (B) real load (fail-closed on the REAL expected key) + checksum verify
            let loaded: BASStateLakeReader.Loaded
            do {
                loaded = try BASStateLakeReader.load(lake, expectedBindingKey: bkey, stateOrder: order)
            } catch {
                mark("🗄️ (B) statelake LOAD ERROR (bkey=\(bkey.prefix(12))…) \(error)"); return
            }
            mark("🗄️ (B) statelake loaded: 6 states, promptLen=\(loaded.promptLen), binding-key + sha256 OK")

            // (C) decode from the rehydrated-from-DISK state
            let opts = SpecializationOptions(preferredComputeUnitKind: .gpu)
            let dec: BASCoreAIHybridDecodeSession
            do {
                dec = try await BASCoreAIHybridDecodeSession(assetURL: asset, initialStates: loaded.states, initialFill: loaded.promptLen, options: opts)
            } catch {
                mark("🗄️ (C) decode LOAD ERROR \(error)"); return
            }
            var arg: [Int] = []
            do {
                for j in 0..<CONT { arg.append(try await dec.step(token: ((PROMPT + j) * 17 + 5) % VOCAB)) }
            } catch {
                mark("🗄️ (C) decode ERROR after \(arg.count) steps \(error)"); return
            }
            mark("🗄️ DEV_CONT_ARGMAX=\(arg.map(String.init).joined(separator: ","))")
            mark("🗄️ statelake DONE — compare to host HOSTREF_STATELAKE_ARGMAX. Match ⇒ a disk-persisted neural state rehydrates + decodes on the A19 (cross-launch StateLake).")
        } else {
            mark("🗄️ SKIP — needs iOS 27")
        }
        #else
        mark("🗄️ SKIP — CoreAI not in this build")
        #endif
    }
}
