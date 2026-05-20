// MARK: - BASKVCacheFloat16Token
// chapter 七百三十三 第一刀 / M2336
//
// Float16-compressed counterpart to BASTransformerKVCacheToken。
// Closes the Plan-agent gap flagged in the original chapter
// 七百二十八 plan:
//
//   "Apple Silicon Float16 (fp16) native (Plan-agent gap flag):
//    cheaper accuracy trade than int8 for KV cache。 Not in
//    initial plan but flagged for follow-up arc。"
//
// ## When Float16 vs int8 vs Float32
//
// | Tier      | Memory shrink | Precision  | Best for                          |
// |-----------|---------------|------------|-----------------------------------|
// | Float32   | 1×            | 23-bit mantissa | replay-pinned audit corpora      |
// | Float16   | 2×            | 10-bit mantissa | accuracy-priority host workloads |
// | int8      | 4×            | ~7-bit effective | memory-priority host workloads   |
//
// Float16 sits BETWEEN Float32 and int8 — losing ~4 ulp of
// precision (representable values 2^-14 to 2^16) for half the
// storage。 int8 is more aggressive (quantize-with-scale,~7
// effective bits) for 4× shrink。
//
// ## Why Apple Silicon Float16 is fast
//
// Apple M1/M2/M3 silicon has native FP16 SIMD instructions via
// NEON。 Swift's Float16 (since Swift 5.3 on Apple platforms)
// maps directly to those instructions for arithmetic。 No
// emulation,no fallback — Apple Silicon executes FP16 at the
// same throughput as Float32 (sometimes faster due to memory
// bandwidth savings)。
//
// ## Public surface
//
//   struct BASKVCacheFloat16Token (Codable Sendable)
//   extension BASTransformerKVCacheToken { toFloat16Token() }
//   extension BASKVCacheFloat16Token { toFloat32Token() }
//   enum BASKVCacheFloat16 { useFloat16KVCache flag }

import Foundation

/// Float16-compressed KV cache token。 Stores key + value
/// tensors as Float16 + no per-tensor scale (Float16 is a
/// native floating-point type;no scale needed)。
public struct BASKVCacheFloat16Token:
    Equatable, Hashable, Codable, Sendable
{
    /// Float16 key tensor。 `keyFloat16.count` equals the
    /// original Float32 element count (1 Float16 per Float32
    /// source element)。 Stored as `Data` so the wire format
    /// is just raw little-endian Float16 bytes (2 bytes per
    /// element)。
    public let keyFloat16: Data

    /// Float16 value tensor。
    public let valueFloat16: Data

    /// Element count (preserved from the source Float32 token
    /// for byte-count cross-check)。
    public let elementCount: Int

    /// Schema version pin。 v1 = native Float16 (this struct's
    /// initial wire format)。
    public let schemaVersion: Int

    public init(
        keyFloat16: Data,
        valueFloat16: Data,
        elementCount: Int,
        schemaVersion: Int = 1
    ) {
        self.keyFloat16 = keyFloat16
        self.valueFloat16 = valueFloat16
        self.elementCount = elementCount
        self.schemaVersion = schemaVersion
    }

    /// Memory footprint in bytes (Codable wire format size)。
    public var byteSize: Int {
        return keyFloat16.count
            + valueFloat16.count
            + MemoryLayout<Int>.size      // elementCount
            + MemoryLayout<Int>.size      // schemaVersion
    }

    /// Theoretical Float32 byte size for comparison。 Each
    /// element is 4 bytes,key + value doubles。
    public var float32EquivalentByteSize: Int {
        return elementCount * 4 * 2
    }

    /// Memory shrink ratio vs Float32。 Approaches 2× for
    /// large elementCount (overhead amortizes)。
    public var memoryShrinkRatio: Double {
        return Double(float32EquivalentByteSize)
            / Double(byteSize)
    }

    /// Comparison ratio vs int8 (chapter 七百二十八)。 Float16
    /// is 2× the size of int8 but at higher precision。
    public static let memoryRatioVsInt8: Double = 2.0
}

// MARK: - chapter 七百三十三 第二刀 / M2337
//         Float16 quantize-on-write + dequantize-on-read

extension BASTransformerKVCacheToken {

    /// Convert this Float32 token to a Float16 token。 Uses
    /// Swift's native Float16 type → ARM NEON FP16 path on
    /// Apple Silicon for fast lane-wise conversion。
    public func toFloat16Token() -> BASKVCacheFloat16Token? {
        guard keyBytes.count % 4 == 0,
              valueBytes.count % 4 == 0
        else { return nil }
        let keyCount = keyBytes.count / 4
        let valueCount = valueBytes.count / 4
        guard keyCount == elementCount,
              valueCount == elementCount
        else { return nil }

        // Decode keyBytes / valueBytes as [Float]
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

        // Convert Float32 → Float16。 On Apple Silicon this
        // compiles to a single FCVT instruction per lane
        // (or 4-wide via NEON SIMD)。 No precision loss beyond
        // the inherent Float16 mantissa truncation。
        let keyF16: [Float16] = keyFloats.map { Float16($0) }
        let valueF16: [Float16] = valueFloats.map { Float16($0) }

        let keyData = keyF16.withUnsafeBufferPointer {
            Data(buffer: $0)
        }
        let valueData = valueF16.withUnsafeBufferPointer {
            Data(buffer: $0)
        }
        return BASKVCacheFloat16Token(
            keyFloat16: keyData,
            valueFloat16: valueData,
            elementCount: elementCount)
    }
}

extension BASKVCacheFloat16Token {

    /// Convert this Float16 token back to Float32。
    ///
    /// Float16 → Float32 is LOSSLESS in precision direction
    /// (every Float16 maps to a unique Float32 — except NaN/Inf
    /// edge cases which the substrate's L2-normalized inputs
    /// don't produce)。 The original Float32 precision IS lost
    /// (irrecoverable) but the value after round-trip is the
    /// closest Float32 representable of the stored Float16。
    public func toFloat32Token() ->
        BASTransformerKVCacheToken?
    {
        // Decode the Data as [Float16]
        guard keyFloat16.count == elementCount * 2,
              valueFloat16.count == elementCount * 2
        else { return nil }
        let keyF16: [Float16] = keyFloat16
            .withUnsafeBytes { rb in
                let p = rb.bindMemory(to: Float16.self)
                return Array(p)
            }
        let valueF16: [Float16] = valueFloat16
            .withUnsafeBytes { rb in
                let p = rb.bindMemory(to: Float16.self)
                return Array(p)
            }
        let keyFloats: [Float] = keyF16.map { Float($0) }
        let valueFloats: [Float] =
            valueF16.map { Float($0) }

        let keyData = keyFloats.withUnsafeBufferPointer {
            Data(buffer: $0)
        }
        let valueData = valueFloats.withUnsafeBufferPointer {
            Data(buffer: $0)
        }
        return BASTransformerKVCacheToken(
            keyBytes: keyData,
            valueBytes: valueData,
            elementCount: elementCount)
    }
}

// MARK: - Feature flag (chapter 七百三十三 第二刀 / M2337)

/// Process-wide feature flag for the Float16 KV cache code path。
/// Default OFF (per ADR-014 OPT-IN principle)。 Mirrors the chapter
/// 七百二十八 BASKVCacheQuantization pattern。
///
/// Hosts enabling this flag are expected to:
///   1. Quantize tokens via `BASTransformerKVCacheToken
///      .toFloat16Token()` before storing in the registry
///   2. Dequantize via `.toFloat32Token()` when reading
///
/// Mutually exclusive with `BASKVCacheQuantization.useQuantizedKVCache`
/// — pick the precision tier per workload:
///   - Float16 (this flag):  2× shrink,higher precision
///   - int8 (chapter 七百二十八): 4× shrink,lower precision
///   - Float32 (default):    1× (no shrink),full precision
public enum BASKVCacheFloat16 {

    public nonisolated(unsafe) static var
        useFloat16KVCache: Bool = false
}
