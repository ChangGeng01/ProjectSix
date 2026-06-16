// MARK: - BASStateLakeReader — the on-device StateLake reader (cross-launch persistence)
//
// Reads a .statelake bundle (header.json + payload.bin) written by Tools/mamba3_statelake_device_prep.py into the decode
// session's initial NDArray states. FAIL-CLOSED: a binding-key mismatch (wrong model/precision/max_seq/version) or a
// payload sha256 mismatch raises — a stale/corrupt state is NEVER silently rehydrated (the audit's #1 danger, on device).
// This is the device half of the StateLake whose host put/get + binding-key is proven in Tools/mamba3_statelake.py.

import Foundation

#if canImport(CoreAI)
import CoreAI
import CryptoKit

@available(iOS 27, macOS 27, *)
public enum BASStateLakeReader {
    public enum Error: Swift.Error {
        case header(String)
        case bindingKey(String)
        case checksum(String)
        case missing(String)
    }

    public struct Loaded {
        public let states: [NDArray]      // in the requested stateOrder (the decode asset's declared stateNames order)
        public let promptLen: Int
    }

    /// FAIL-CLOSED load: verify binding-key then sha256(payload), then dequantize each tensor (int8·scale | fp16) into NDArrays.
    public static func load(_ dir: URL, expectedBindingKey: String, stateOrder: [String]) throws -> Loaded {
        let hdr = try Data(contentsOf: dir.appendingPathComponent("header.json"))
        guard let h = try JSONSerialization.jsonObject(with: hdr) as? [String: Any],
              let bkey = h["binding_key"] as? String,
              let recs = h["tensors"] as? [[String: Any]],
              let promptLen = h["prompt_len"] as? Int,
              let checksum = h["checksum"] as? String else {
            throw Error.header("malformed header.json")
        }
        guard bkey == expectedBindingKey else {
            throw Error.bindingKey("artifact \(bkey.prefix(12)) != expected \(expectedBindingKey.prefix(12)) — refusing stale state")
        }
        let payload = try Data(contentsOf: dir.appendingPathComponent("payload.bin"))
        let got = SHA256.hash(data: payload).map { String(format: "%02x", $0) }.joined()
        guard got == checksum else {
            throw Error.checksum("payload sha256 mismatch — corrupt .statelake")
        }

        var byName: [String: NDArray] = [:]
        for r in recs {
            guard let name = r["name"] as? String, let shape = r["shape"] as? [Int],
                  let dtype = r["dtype"] as? String, let start = r["start"] as? Int, let nbytes = r["nbytes"] as? Int else {
                throw Error.header("bad tensor record")
            }
            let scale = Float((r["scale"] as? NSNumber)?.doubleValue ?? 1.0)
            let n = shape.reduce(1, *)
            var f16 = [Float16](repeating: 0, count: n)
            let sub = payload.subdata(in: start..<(start + nbytes))
            if dtype == "int8" {
                sub.withUnsafeBytes { raw in
                    let q = raw.bindMemory(to: Int8.self)
                    for i in 0..<n { f16[i] = Float16(Float(q[i]) * scale) }
                }
            } else {                                                  // fp16 (mla_fill — the offset, stored exact)
                sub.withUnsafeBytes { raw in
                    let q = raw.bindMemory(to: Float16.self)
                    for i in 0..<n { f16[i] = q[i] }
                }
            }
            byName[name] = NDArray(scalars: f16, shape: shape)
        }
        let ordered = try stateOrder.map { name -> NDArray in
            guard let nd = byName[name] else { throw Error.missing("tensor \(name) absent from .statelake") }
            return nd
        }
        return Loaded(states: ordered, promptLen: promptLen)
    }
}

#endif
