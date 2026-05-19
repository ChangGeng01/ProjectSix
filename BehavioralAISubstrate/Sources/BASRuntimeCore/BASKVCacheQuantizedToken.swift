// MARK: - BASKVCacheQuantizedToken
// chapter 七百二十八 第一刀 / M2311
//
// int8-quantized counterpart to BASTransformerKVCacheToken。
// Stores key + value tensors as int8 + per-tensor scale,
// achieving ~4× memory shrink for the KV cache。
//
// Per the chapter 七百二十一-七百三十 aggressive evolution
// plan,this is the **HIGHEST ACCURACY RISK** chapter in the
// arc。 Plan-agent expects:
//   "Quality eval: 100-turn replay with each turn's KV cache
//    quantized → output sequence cosine-drift ≤ 0.01 vs
//    Float32 reference。 Likely FLIP-OFF since cosine-drift
//    may exceed 0.01 in some sessions"。
//
// Chapter 七百二十八 第三刀 will run the drift gate;Knife 5
// honestly reports whether the default flip ships ON or OFF。

import Foundation

/// int8-quantized KV cache token。 Counterpart to the Float32
/// `BASTransformerKVCacheToken`。 Per-tensor (not per-channel)
/// quantization keeps the wire format compact;per-channel
/// would improve precision at the cost of 4× more scales。
public struct BASKVCacheQuantizedToken:
    Equatable, Hashable, Codable, Sendable
{
    /// int8-quantized key tensor。 `keyInt8.count` equals the
    /// original Float32 key element count。
    public let keyInt8: Data

    /// Symmetric scale used to quantize the key tensor。
    public let keyScale: Float

    /// int8-quantized value tensor。
    public let valueInt8: Data

    /// Symmetric scale used to quantize the value tensor。
    public let valueScale: Float

    /// Element count (preserved from the source Float32 token
    /// for byte-count cross-check)。
    public let elementCount: Int

    /// Schema version for forward-compat (v1 = symmetric per-
    /// tensor int8 with two scales)。
    public let schemaVersion: Int

    public init(
        keyInt8: Data,
        keyScale: Float,
        valueInt8: Data,
        valueScale: Float,
        elementCount: Int,
        schemaVersion: Int = 1
    ) {
        self.keyInt8 = keyInt8
        self.keyScale = keyScale
        self.valueInt8 = valueInt8
        self.valueScale = valueScale
        self.elementCount = elementCount
        self.schemaVersion = schemaVersion
    }

    /// Memory footprint in bytes (Codable wire format size)。
    /// Compares against the Float32 equivalent for the
    /// shrink ratio。
    public var byteSize: Int {
        return keyInt8.count
            + valueInt8.count
            + MemoryLayout<Float>.size * 2   // two scales
            + MemoryLayout<Int>.size         // elementCount
            + MemoryLayout<Int>.size         // schemaVersion
    }

    /// Theoretical Float32 byte size for comparison。 Each
    /// element is 4 bytes,key + value doubles。
    public var float32EquivalentByteSize: Int {
        return elementCount * 4 * 2
    }

    /// Memory shrink ratio。 Approaches 4× for large
    /// elementCount (the two scales + element count + version
    /// overhead amortize away)。
    public var memoryShrinkRatio: Double {
        return Double(float32EquivalentByteSize)
            / Double(byteSize)
    }
}

// MARK: - chapter 七百二十八 第二刀 / M2312
//         Quantize-on-write + dequantize-on-read helpers
//
// Standalone helpers (NOT injected into BASKVCacheRegistry —
// preserves the chapter 482 / M1306 actor's existing wire
// contract)。 Hosts that opt in:
//   1. Convert Float32 BASTransformerKVCacheToken values to
//      BASKVCacheQuantizedToken via `quantize(from:)` before
//      caching
//   2. Convert back via `dequantize()` when reading
//
// This decoupling means the registry doesn't need any code
// changes for hosts to use int8 KV — they manage the
// conversion at the application boundary。

extension BASTransformerKVCacheToken {

    /// chapter 七百二十八 第二刀 — quantize this Float32 token
    /// to an int8 BASKVCacheQuantizedToken。 Returns nil if the
    /// key/value byte layout isn't Float32-aligned or quant
    /// FFI fails。
    public func toQuantizedInt8() -> BASKVCacheQuantizedToken? {
        // Decode keyBytes / valueBytes as [Float]
        guard keyBytes.count % 4 == 0,
              valueBytes.count % 4 == 0
        else { return nil }
        let keyCount = keyBytes.count / 4
        let valueCount = valueBytes.count / 4
        guard keyCount == elementCount,
              valueCount == elementCount
        else { return nil }
        let keyFloats: [Float] = keyBytes
            .withUnsafeBytes { rb in
                let p = rb.bindMemory(to: Float.self)
                return Array(p)
            }
        let valueFloats: [Float] = valueBytes
            .withUnsafeBytes { rb in
                let p = rb.bindMemory(to: Float.self)
                return Array(p)
            }
        guard let qK = BASAutoRouteRanker.quantizeInt8(
            keyFloats),
              let qV = BASAutoRouteRanker.quantizeInt8(
                valueFloats)
        else { return nil }
        // Convert [Int8] → Data
        let keyData = qK.quantized
            .withUnsafeBufferPointer { Data(buffer: $0) }
        let valueData = qV.quantized
            .withUnsafeBufferPointer { Data(buffer: $0) }
        return BASKVCacheQuantizedToken(
            keyInt8: keyData,
            keyScale: qK.scale,
            valueInt8: valueData,
            valueScale: qV.scale,
            elementCount: elementCount)
    }
}

extension BASKVCacheQuantizedToken {

    /// chapter 七百二十八 第二刀 — dequantize this int8 token
    /// back to a Float32 BASTransformerKVCacheToken。 Returns
    /// nil if the FFI fails (extremely unlikely)。
    ///
    /// The dequantized values approximate the original Float32
    /// inputs within the per-element quantization error bound
    /// (~scale / 254 per element)。 For attention pooling +
    /// score-based dispatch this is typically well below the
    /// downstream output drift threshold;chapter 七百二十八
    /// 第三刀 quality eval pins the actual envelope。
    public func toFloat32Token() ->
        BASTransformerKVCacheToken?
    {
        let keyInt8Array: [Int8] = keyInt8
            .withUnsafeBytes { rb in
                let p = rb.bindMemory(to: Int8.self)
                return Array(p)
            }
        let valueInt8Array: [Int8] = valueInt8
            .withUnsafeBytes { rb in
                let p = rb.bindMemory(to: Int8.self)
                return Array(p)
            }
        guard let kF = BASAutoRouteRanker.dequantizeInt8(
            keyInt8Array, scale: keyScale),
              let vF = BASAutoRouteRanker.dequantizeInt8(
                valueInt8Array, scale: valueScale)
        else { return nil }
        let kBytes = kF.withUnsafeBufferPointer {
            Data(buffer: $0)
        }
        let vBytes = vF.withUnsafeBufferPointer {
            Data(buffer: $0)
        }
        return BASTransformerKVCacheToken(
            keyBytes: kBytes,
            valueBytes: vBytes,
            elementCount: elementCount)
    }
}

// MARK: - Feature flag (chapter 七百二十八 第二刀 / M2312)

/// Top-level feature flag controlling whether hosts opt into
/// the int8 KV cache code path。 Default OFF (per plan-agent's
/// honest expectation that long-context drift may exceed 0.01)。
///
/// Hosts that enable the flag are expected to:
///   1. Quantize tokens via `BASTransformerKVCacheToken
///      .toQuantizedInt8()` before storing in the registry
///   2. Dequantize via `.toFloat32Token()` when reading
///
/// Chapter 七百二十八 第三刀 quality eval pins the drift
/// envelope。 Final decision (default ON or OFF) lands in
/// Knife 5 close-out。
public enum BASKVCacheQuantization {

    /// nonisolated(unsafe) for process-wide static flag,
    /// matching the chapter 七百十六 / 七百十八 / 七百二十七
    /// feature-flag pattern。
    public nonisolated(unsafe) static var
        useQuantizedKVCache: Bool = false
}
