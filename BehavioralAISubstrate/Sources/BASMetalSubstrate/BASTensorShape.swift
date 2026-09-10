// MARK: - BASTensorShape — chapter 四百三十一 / M1096
// 系统熵 reduction
//
// RADICAL EVOLUTION SWEEP Phase E entry。 First substrate-
// level type system for typed Apple Silicon tensors。
//
// ## Why this exists (system entropy framing)
//
// Today the substrate has 1,282 public `*Frame` + `*Bundle`
// types but ZERO typed tensor primitives。 Every adapter
// layer (BASMLXAdapter / BASChatCompletionsAdapter / future
// CoreML conformer) reinvents shape + dtype tracking with
// untyped `[Int]` arrays + raw bytes。 No phantom-type rank
// safety, no scalar-type guard at compile time, no shared
// language for "rank-2 Float16 matrix on ANE"。
//
// `BASTensorShape` ships compile-time rank evidence so
// that `BASTensor<Float32, _2D>` is a different type from
// `BASTensor<Float32, _3D>` — mismatched matmul / reshape /
// permute calls fail at compile time, not at MTLBuffer
// dispatch time when GPU command-buffers are already
// in-flight。
//
// ## What this ships (M1096)
//
//   - `BASTensorShape` marker protocol — phantom-type rank
//     evidence。 Conforming nominal types: `_0D` / `_1D` /
//     `_2D` / `_3D` / `_4D` / `_NDim`。
//   - `BASTensorScalar` marker protocol — element-type
//     evidence。 Conforming primitive types: Float16
//     (where supported) / Float32 / Int32 / UInt8 / Bool。
//   - `BASTensorDataType` enum — runtime discriminator
//     used by Sendable descriptors crossing actor
//     boundaries。 Maps 1:1 to `BASTensorScalar` conformers。
//
// ## Doctrine pins held
//
//   - chapter 一百八十五 — anti-magic-number。 Rank values
//     are typed phantoms, not raw `Int` literals。
//   - chapter 二百一一 — single source-of-truth。 Every
//     adapter layer that ships tensors imports BASTensorShape
//     instead of defining its own dtype enum。
//   - chapter 三百九二 — replay-determinism。 BASTensorDataType
//     is `String`-rawvalue Codable so byte-stable across
//     processes / log replays。
//   - ADR-014 OPT-IN — purely additive。 Existing untyped
//     adapter pathways unchanged。
//   - ADR-016 — chapter 四百三十一 v1 substrate completion。
//   - 不变量 #1/#2/#3 — V1 byte-equality preserved (no
//     existing call site touches BASTensorShape)。
//   - 红线 7 — hint-only。 Phantom-type evidence is purely
//     compile-time guidance; no commitment authority changes。

import Foundation

// MARK: - Rank evidence (phantom types)

/// Marker protocol carried by `BASTensor.Shape`。 Every
/// conforming nominal type encodes a tensor rank at the
/// type level so dimension-mismatched ops fail at compile
/// time instead of MTLBuffer-dispatch time。
public protocol BASTensorShape: Sendable {

    /// Compile-time pinned rank of this shape evidence。
    /// 0 for scalars,1 for vectors,2 for matrices,etc。
    static var rank: Int { get }

    /// Stable string identifier used in Sendable descriptors
    /// + replay logs。 Must be byte-stable across processes
    /// (chapter 三百九二)。
    static var rankTag: String { get }
}

/// Rank-0 scalar (single element)。
public enum _0D: BASTensorShape {
    public static let rank: Int = 0
    public static let rankTag: String = "rank-0"
}

/// Rank-1 vector (1 axis)。
public enum _1D: BASTensorShape {
    public static let rank: Int = 1
    public static let rankTag: String = "rank-1"
}

/// Rank-2 matrix (2 axes — rows × cols)。
public enum _2D: BASTensorShape {
    public static let rank: Int = 2
    public static let rankTag: String = "rank-2"
}

/// Rank-3 tensor (3 axes — typically channels × rows × cols
/// or batch × seq × hidden)。
public enum _3D: BASTensorShape {
    public static let rank: Int = 3
    public static let rankTag: String = "rank-3"
}

/// Rank-4 tensor (4 axes — typically batch × channels ×
/// rows × cols for image tensors,or batch × heads × seq ×
/// head-dim for attention)。
public enum _4D: BASTensorShape {
    public static let rank: Int = 4
    public static let rankTag: String = "rank-4"
}

/// Dynamic-rank fallback。 Used when the source data shape
/// is not known until runtime (e.g. parsed from a
/// HuggingFace safetensors header)。 Loses compile-time
/// dimension safety,so callers should funnel into a
/// statically-ranked `_1D` / `_2D` / etc once known。
public enum _NDim: BASTensorShape {
    public static let rank: Int = -1
    public static let rankTag: String = "rank-dynamic"
}

// MARK: - Builder-input rankTag convention (DELIBERATELY
//         distinct from the typed `_ND.rankTag` above)
//
// There are TWO independent-but-internally-consistent rankTag
// conventions in the substrate,and they are NOT meant to be
// unified:
//
//   1. TYPED / kernel-OUTPUT convention — `_2D.rankTag` ==
//      "rank-2",`_1D.rankTag` == "rank-1",etc。 Kernels
//      stamp their OUTPUT descriptors with these (see every
//      `BASBuiltinKernels/*Kernel.swift` output descriptor),
//      and `BASTensor.init` preconditions
//      `descriptor.rankTag == Shape.rankTag` against them when
//      re-typing a descriptor into a phantom-typed tensor。
//
//   2. BUILDER-INPUT convention — "rank-2-matrix" /
//      "rank-1-vector" / "rank-3-tensor" / "rank-4-tensor"。
//      `BASCanonicalKernelInputBuilders` stamps the kernel
//      INPUT descriptors it constructs with these richer,
//      human-readable tags。 Receiving kernels validate inputs
//      by `descriptor.shape.count` (rank arity),NEVER by
//      comparing the input `rankTag`,so the two conventions
//      never meet at a comparison site。 Tests assert these
//      exact strings (e.g. BASCanonicalKernelInputBuildersTests
//      + the *IntegrationTests),so the VALUES are load-
//      bearing and must not drift。
//
// These constants give the builder-input convention a single
// source per string (chapter 二百一一),replacing the inline
// literals previously hand-written at every descriptor site。
// They are intentionally NOT the same strings as `_ND.rankTag`。
public enum BASBuilderInputRankTag {

    /// Rank-1 input descriptor tag (vectors — e.g. rmsNorm /
    /// layerNorm gamma + beta weights)。 Distinct from
    /// `_1D.rankTag` ("rank-1") by design。
    public static let vector: String = "rank-1-vector"

    /// Rank-2 input descriptor tag (matrices — e.g. matMul
    /// operands,attention Q/K/V,rope tables)。 Distinct
    /// from `_2D.rankTag` ("rank-2") by design。
    public static let matrix: String = "rank-2-matrix"

    /// Rank-3 input descriptor tag (the multi-head rope input
    /// `[seq, heads, headDim]`)。 Distinct from `_3D.rankTag`
    /// ("rank-3") by design。
    public static let tensor3D: String = "rank-3-tensor"

    /// Rank-4 input descriptor tag (e.g. conv2d NCHW inputs)。
    /// Distinct from `_4D.rankTag` ("rank-4") by design。
    public static let tensor4D: String = "rank-4-tensor"
}

// MARK: - Scalar evidence (element type marker protocol)

/// Marker protocol carried by `BASTensor.Element`。 Every
/// conforming type pairs a Swift primitive with the matching
/// `BASTensorDataType` discriminator so cross-actor
/// descriptors stay byte-stable (chapter 三百九二)。
public protocol BASTensorScalar: Sendable {

    /// Pinned dtype enum case for this scalar primitive。
    static var dataType: BASTensorDataType { get }

    /// Bytes per element。 Used by descriptor stride math。
    static var byteWidth: Int { get }
}

extension Float: BASTensorScalar {
    public static let dataType: BASTensorDataType = .float32
    public static let byteWidth: Int = 4
}

extension Int32: BASTensorScalar {
    public static let dataType: BASTensorDataType = .int32
    public static let byteWidth: Int = 4
}

extension UInt8: BASTensorScalar {
    public static let dataType: BASTensorDataType = .uint8
    public static let byteWidth: Int = 1
}

extension Bool: BASTensorScalar {
    public static let dataType: BASTensorDataType = .bool
    public static let byteWidth: Int = 1
}

#if arch(arm64)
// Float16 is only available on ARM64 silicon (A11+ / M1+)
// where the hardware exposes IEEE half-precision natively。
// Intel x86_64 Macs lack the type at the language level,
// so the conformance is platform-gated。
extension Float16: BASTensorScalar {
    public static let dataType: BASTensorDataType = .float16
    public static let byteWidth: Int = 2
}
#endif

// MARK: - Data type discriminator (runtime crossing)

/// Runtime tensor dtype discriminator。 Used by Sendable
/// descriptors that cross actor boundaries — at the wire
/// level we can't carry phantom-type evidence,so this
/// `String`-rawvalue enum carries it instead。 Conversion
/// back to a phantom-typed `BASTensor` fails fast if the
/// dtype mismatches the target `Element`。
public enum BASTensorDataType:
    String, Codable, Equatable, Hashable, Sendable, CaseIterable
{

    /// IEEE 754 half-precision (16 bits)。 Native on ARM64
    /// (A11+ / M1+) — Apple silicon's preferred ANE format。
    case float16 = "float16"

    /// IEEE 754 single-precision (32 bits)。 CPU + GPU + ANE
    /// all support。 Default fallback dtype。
    case float32 = "float32"

    /// 32-bit signed integer。 Used for index tensors,
    /// classification labels,and embedding lookups。
    case int32 = "int32"

    /// 8-bit unsigned integer。 Used for quantized weights
    /// (Gemma 3 q8_0) + image bytes。
    case uint8 = "uint8"

    /// Boolean mask tensor。 Used for attention masks +
    /// padding indicators。 Stored as 1 byte per element。
    case bool = "bool"

    /// Bytes per element for this dtype。 Mirrors
    /// `BASTensorScalar.byteWidth` so descriptor + scalar
    /// surfaces stay in agreement (chapter 二百一一
    /// single-source-of-truth)。
    public var byteWidth: Int {
        switch self {
        case .float16: return 2
        case .float32: return 4
        case .int32:   return 4
        case .uint8:   return 1
        case .bool:    return 1
        }
    }
}
