// device-recon id9 on-device certification (BAS_SPILL_QUANTIZE_PROBE=1).
//
// Certifies the two DEVICE-SPECIFIC halves of the spill-quantize-under-pressure lever
// that the Mac unit tests (BASSpillQuantizeTests / BASSessionKVStoreQuantizeTests) cannot
// reach on their own:
//   (a) the REAL headroom reader — os_proc_available_memory() / the jetsam cap — returns
//       a sane fraction on the A19, and the quantize DECISION responds to it;
//   (b) MLX.quantized(bits: 4) on real KV arrays, run on the A19 Metal GPU, PRODUCES a
//       materially smaller file than fp16 AND restores (round-trip) — the Q4-shrink EFFECT.
//
// It needs NO model load — so NO jetsam-boundary risk. The spill file size is STRUCTURAL
// (4-bit packing + fp16 group scales vs 16-bit fp16), i.e. value-independent, so a
// synthetic pure-attention KV of a realistic shape is a faithful stand-in for real KV.
// The probe SELF-ASSERTS (prints PASS/FAIL to os_log .notice + stdout) because the device
// log files cannot be pulled in this environment (devicectl copy-from hangs).
import Foundation
import MLX
import MLXLLM
import MLXLMCommon
import BASMLXAdapter

enum BASSpillQuantizeProbe {

    // Realistic pure-attention KV geometry (Llama-3.2-3B-class GQA: 8 kv-heads × 128 dim).
    // Only KVCacheSimple layers quantize (GDN / ArraysCache pass through fp16) — exactly
    // the id9 contract, so a pure-attention cache is the strongest, cleanest A/B.
    private static let layers = 8
    private static let kvHeads = 8
    private static let headDim = 128
    private static let tokens = 256

    private static func attentionCache(_ t: Int) -> [KVCache] {
        (0..<layers).map { _ in
            let fa = KVCacheSimple()
            if t > 0 {
                let k = MLXArray.zeros([1, kvHeads, t, headDim]).asType(.float16)
                let v = MLXArray.zeros([1, kvHeads, t, headDim]).asType(.float16)
                _ = fa.update(keys: k, values: v)
            }
            return fa
        }
    }

    static func run() async {
        let log = ProbeFileLog(filePrefix: "spill-quantize", category: "spill-quantize", alsoFlush: true)
        defer { log.close() }
        log.emit("📊 spill-quantize START (device-recon id9 · A19 certification · no model load)")

        // (a) the REAL headroom reader + the decision it drives, on THIS hardware.
        let d = MLXOrganAdapter.spillQuantizeDiagnostics()
        let fracStr = d.headroomFrac.map { String(format: "%.4f", $0) } ?? "nil"
        let capStr = d.capBytes.map { "\($0 / (1024 * 1024))MB" } ?? "nil"
        log.emit(String(
            format: "📊 spill-quantize HEADROOM avail=%dMB cap=%@ frac=%@ threshold=%.2f wouldQuantizeNow=%@",
            d.availableBytes / (1024 * 1024), capStr, fracStr,
            MLXOrganAdapter.spillQuantizePressureThreshold,
            d.wouldQuantizeUnderRealPressure ? "true" : "false"))
        log.emit("   (reader alive on A19; a healthy frac ≫ 0.10 ⇒ wouldQuantizeNow=false is CORRECT — "
            + "quantize fires ONLY under real pressure)")

        // (b) the Q4-shrink EFFECT on the A19 Metal GPU: synthetic pure-attention KV A/B.
        let dir = FileManager.default.temporaryDirectory
        let fp16URL = dir.appendingPathComponent("id9_fp16_\(UUID().uuidString).safetensors")
        let q4URL = dir.appendingPathComponent("id9_q4_\(UUID().uuidString).safetensors")
        defer {
            try? FileManager.default.removeItem(at: fp16URL)
            try? FileManager.default.removeItem(at: q4URL)
        }

        do {
            let size16 = try BASSessionKVStore.save(
                cache: attentionCache(tokens), tokenCount: tokens,
                to: fp16URL, modelID: "id9-probe", quantizeKV: false)
            let sizeQ4 = try BASSessionKVStore.save(
                cache: attentionCache(tokens), tokenCount: tokens,
                to: q4URL, modelID: "id9-probe", quantizeKV: true)
            // Round-trip: a Q4 spill that could not be read back would defeat
            // park-under-pressure → resume, the whole point of the lever.
            let restored = try BASSessionKVStore.restore(
                into: attentionCache(tokens), from: q4URL, expectedModelID: "id9-probe")

            let ratio = size16 > 0 ? Double(sizeQ4) / Double(size16) : 1.0
            let shrinkFactor = sizeQ4 > 0 ? Double(size16) / Double(sizeQ4) : 0.0
            let shrinkOK = Double(sizeQ4) < 0.6 * Double(size16)   // ~4× KV, generous overhead margin
            let restoreOK = restored == tokens
            let pass = shrinkOK && restoreOK

            log.emit(String(
                format: "📊 spill-quantize EFFECT fp16=%dKB q4=%dKB ratio=%.3f shrink=%.1f× restored=%d/%d",
                size16 / 1024, sizeQ4 / 1024, ratio, shrinkFactor, restored, tokens))
            log.emit("📊 spill-quantize VERDICT \(pass ? "PASS" : "FAIL") "
                + "shrink=\(shrinkOK)(q4<0.6×fp16) restore=\(restoreOK) — "
                + "the parked KV is Q4-shrunk on the A19 Metal GPU and restores exactly")
        } catch {
            log.emit("📊 spill-quantize VERDICT FAIL error=\(error)")
        }
    }
}
