// MARK: - BASKVCacheCompressedToken
// chapter 七百三十四 第一/二/三刀 / M2341-M2343
//
// Unified sum-type over the 3 KV cache precision tiers shipped
// across chapters 七百二十八 (int8),七百三十三 (Float16),and
// the Float32 baseline。 Closes the "host picks per-tier method"
// gap with a single typed Swift surface:
//
//   let compressed = token.compressed(tier: .float16)
//   // ... store ...
//   let recovered = compressed.decompressed()
//
// vs the prior per-tier API where the host had to know which
// method to call for which tier:
//
//   let f16 = token.toFloat16Token()           // for Float16
//   let i8  = token.toQuantizedInt8()           // for int8
//   // Float32 → use the raw BASTransformerKVCacheToken
//
// ## When to use the unified vs per-tier API
//
// - Use the unified sum-type when the tier is a RUNTIME choice
//   (e.g。 a memory-pressure auto-router picks the tier)
// - Use the per-tier helpers when the tier is COMPILE-TIME
//   known (slightly lower overhead,no enum dispatch)
//
// Both APIs share the same underlying storage helpers so they
// interop cleanly。
//
// ## Why an enum (sum type) vs a protocol
//
// - Codable Codable wire format is simpler with an enum (single
//   discriminant + typed payload per case)
// - Equatable / Hashable / Sendable auto-derive cleanly
// - Switch exhaustiveness gives a compile error when a future
//   chapter adds a 4th tier (forcing call sites to handle it)
// - No virtual dispatch overhead vs a protocol's existential

import Foundation

/// Typed precision tier identifier。 Mirrors the chapter 七百
/// 三十三 第五刀 decision tree。
public enum BASKVCachePrecisionTier:
    String, Codable, Equatable, Hashable, Sendable,
    CaseIterable
{
    /// Float32 baseline — no compression。 ~1× memory,full
    /// 23-bit mantissa。 Best for replay-pinned / audit corpora。
    case float32 = "float32"

    /// Float16 — 2× memory shrink,10-bit mantissa。
    /// 17.7× more precise than int8 per chapter 七百三十三 第三刀
    /// measurement。 Best for accuracy-priority hosts。
    case float16 = "float16"

    /// int8 symmetric quantize — 4× memory shrink,~7-bit
    /// effective。 Drift 0.0009 per chapter 七百二十八 第三刀。
    /// Best for memory-priority hosts。
    case int8 = "int8"

    /// Theoretical memory shrink ratio for this tier vs
    /// Float32 baseline。 Production ratios approach these
    /// asymptotic values at large element counts (small dim
    /// has per-token overhead that dilutes the ratio)。
    public var asymptoticShrinkRatio: Double {
        switch self {
        case .float32: return 1.0
        case .float16: return 2.0
        case .int8:    return 4.0
        }
    }

    /// Measured max cosine drift per chapter 七百三十三 第三刀
    /// 3-way comparison (100 turns × dim 128)。 Float32 is
    /// exactly 0 by construction;Float16 + int8 are
    /// empirically pinned at the chapter measurements。
    public var measuredMaxDrift: Double {
        switch self {
        case .float32: return 0.0
        case .float16: return 0.000051
        case .int8:    return 0.000879
        }
    }
}

/// Unified compressed KV cache token sum-type。 One of three
/// per-tier payloads (Float32 baseline / Float16 / int8)。
/// Codable wire format pins the tier discriminant + the
/// case-specific payload。
public enum BASKVCacheCompressedToken:
    Equatable, Hashable, Codable, Sendable
{
    /// Float32 baseline — wraps the raw token unchanged。
    case float32(BASTransformerKVCacheToken)

    /// Float16 — wraps the chapter 七百三十三 type。
    case float16(BASKVCacheFloat16Token)

    /// int8 — wraps the chapter 七百二十八 type。
    case int8(BASKVCacheQuantizedToken)

    /// Precision tier discriminant。 Constant-time lookup,no
    /// switch needed at call sites — `compressed.tier` is the
    /// canonical accessor。
    public var tier: BASKVCachePrecisionTier {
        switch self {
        case .float32: return .float32
        case .float16: return .float16
        case .int8:    return .int8
        }
    }

    /// Element count (preserved across all 3 tiers via the
    /// underlying token shape)。
    public var elementCount: Int {
        switch self {
        case .float32(let t): return t.elementCount
        case .float16(let t): return t.elementCount
        case .int8(let t):    return t.elementCount
        }
    }

    /// Memory footprint in bytes (Codable wire format size)。
    /// Float32 has no scale overhead;Float16 has the elementCount
    /// + version overhead;int8 has 2 scales + elementCount +
    /// version overhead。
    public var byteSize: Int {
        switch self {
        case .float32(let t):
            // Float32:keyBytes + valueBytes + elementCount Int
            return t.keyBytes.count
                + t.valueBytes.count
                + MemoryLayout<Int>.size
        case .float16(let t): return t.byteSize
        case .int8(let t):    return t.byteSize
        }
    }

    /// Theoretical Float32-equivalent byte size for comparison。
    public var float32EquivalentByteSize: Int {
        return elementCount * 4 * 2  // K + V Float32
    }

    /// Measured memory shrink ratio vs Float32。 1.0 for Float32,
    /// ~2× for Float16,~4× for int8 (asymptotic at large dim)。
    public var memoryShrinkRatio: Double {
        return Double(float32EquivalentByteSize)
            / Double(byteSize)
    }
}

// MARK: - chapter 七百三十四 第二/三刀 — compress / decompress

extension BASTransformerKVCacheToken {

    /// Compress this Float32 token to the requested precision
    /// tier。 Returns nil if the per-tier compressor fails
    /// (extremely unlikely from a well-formed Float32 source)。
    public func compressed(
        tier: BASKVCachePrecisionTier
    ) -> BASKVCacheCompressedToken? {
        switch tier {
        case .float32:
            return .float32(self)
        case .float16:
            guard let f16 = toFloat16Token()
            else { return nil }
            return .float16(f16)
        case .int8:
            guard let i8 = toQuantizedInt8()
            else { return nil }
            return .int8(i8)
        }
    }
}

extension BASKVCacheCompressedToken {

    /// Decompress back to the Float32 BASTransformerKVCacheToken。
    /// Returns nil if the per-tier decompressor fails (rare)。
    ///
    /// Note:Float32 → Float32 is identity (zero precision loss)。
    /// Float16 → Float32 recovers the closest Float32 to each
    /// stored Float16。 int8 → Float32 recovers the dequantized
    /// approximation within the quantization-error envelope。
    public func decompressed() ->
        BASTransformerKVCacheToken?
    {
        switch self {
        case .float32(let t): return t
        case .float16(let t): return t.toFloat32Token()
        case .int8(let t):    return t.toFloat32Token()
        }
    }
}
