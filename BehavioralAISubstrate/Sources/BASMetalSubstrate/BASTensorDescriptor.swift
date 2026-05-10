// MARK: - BASTensorDescriptor — chapter 四百三十一 / M1096
// 系统熵 reduction
//
// RADICAL EVOLUTION SWEEP Phase E entry。 Sendable
// shape/stride/dtype envelope for crossing actor + process
// boundaries。
//
// ## Why this exists (system entropy framing)
//
// `BASTensor` carries phantom-type rank + scalar evidence,
// but those phantoms vanish when crossing actor isolation
// boundaries (Sendable closures cannot carry phantom
// generics through erased payloads)。 Without a runtime
// descriptor,every actor boundary leaks shape info into
// untyped `[Int]` arrays + raw `Data` blobs — that's
// exactly the entropy this chapter targets。
//
// `BASTensorDescriptor` is the Sendable wire format:
// shape + stride + dtype + element-count + byte-count + a
// single-source-of-truth backing-kind tag。 Cross-actor
// receivers reconstruct the typed `BASTensor` from this
// envelope (with a guard that fails fast when phantom
// dtype mismatches the runtime dtype)。
//
// ## What this ships (M1096)
//
//   - `BASTensorDescriptor` struct — Sendable + Codable
//     envelope with shape / strides / dataType / backing
//     kind / element + byte counts。
//   - `BASTensorBackingKind` enum — discriminator for the
//     three native Apple Silicon storage kinds (MLX
//     ndarray / CoreML MLMultiArray / raw MTLBuffer)。
//     Carried in the descriptor so consumers know which
//     framework owns the bytes without unwrapping the
//     `BASTensor`。
//   - Shape computation helpers (`elementCount` /
//     `byteCount` / `defaultStrides`) computed from
//     stored shape + dtype with no platform calls。
//
// ## Doctrine pins held
//
//   - chapter 一百八十五 — anti-magic-number。 Backing kind
//     + dtype are typed enums,not raw `Int`/`String`。
//   - chapter 二百一一 — single-source-of-truth。 Every
//     descriptor consumer reads `byteWidth` from
//     `BASTensorDataType.byteWidth` (no duplicated table)。
//   - chapter 三百九二 — replay-determinism。 `Codable` via
//     `JSONEncoder.outputFormatting=[.sortedKeys]` keeps
//     the wire form byte-stable for the unified event log
//     (Phase B chapter 四百二十八)。
//   - ADR-014 OPT-IN — purely additive。
//   - 不变量 #1/#2/#3 — V1 byte-equality preserved。
//   - 红线 7 — hint-only。

import Foundation

// MARK: - Backing kind discriminator

/// Discriminator naming which native Apple Silicon storage
/// kind owns the underlying bytes。 Carried in the
/// `BASTensorDescriptor` so cross-actor consumers can route
/// to the right unpacker without unwrapping the typed
/// `BASTensor`。
public enum BASTensorBackingKind:
    String, Codable, Equatable, Hashable, Sendable, CaseIterable
{

    /// `MLXArray` (Apple Silicon ARM64 only,via
    /// `mlx-swift`)。 Preferred for on-device inference
    /// hot paths — already lives on the GPU/ANE。
    case mlxArray = "mlx-array"

    /// `MLMultiArray` (CoreML)。 Preferred for ANE
    /// dispatch via `MLComputeUnits.cpuAndNeuralEngine`。
    case mlMultiArray = "ml-multi-array"

    /// `MTLBuffer` (raw Metal storage)。 Preferred for
    /// custom MPSGraph kernels that bypass MLX/CoreML。
    case metalBuffer = "metal-buffer"

    /// CPU-only host bytes (no GPU/ANE residence)。 Used
    /// for descriptor round-trip + simulator builds where
    /// Metal is unavailable。
    case cpuBytes = "cpu-bytes"
}

// MARK: - Sendable descriptor

/// Sendable + Codable envelope describing a tensor's shape,
/// stride, dtype, and backing kind。 Used to cross actor
/// boundaries (where phantom-type evidence is erased) +
/// the unified event log (Phase B)。
///
/// The descriptor never carries the bytes themselves —
/// it's the metadata envelope only。 Consumers reconstruct
/// the typed `BASTensor` from this descriptor + a separate
/// payload reference (e.g. a `BASTensor` handle pulled
/// from the kernel registry)。
public struct BASTensorDescriptor:
    Equatable, Hashable, Codable, Sendable
{

    /// Shape of the tensor — one entry per rank axis。
    /// Empty for rank-0 scalars。 All entries must be > 0。
    public let shape: [Int]

    /// Strides of the tensor — bytes between successive
    /// elements along each axis。 Length must equal
    /// `shape.count`。 For row-major contiguous tensors
    /// the last axis is `dataType.byteWidth`。
    public let strides: [Int]

    /// Element type discriminator (mirrors phantom
    /// `BASTensorScalar.dataType`)。
    public let dataType: BASTensorDataType

    /// Storage discriminator (which native Apple Silicon
    /// framework owns the bytes)。
    public let backingKind: BASTensorBackingKind

    /// Pinned rank tag (mirrors phantom
    /// `BASTensorShape.rankTag`)。 Carried so receivers
    /// can validate the dynamic shape against the expected
    /// phantom rank before re-typing。
    public let rankTag: String

    public init(
        shape: [Int],
        strides: [Int],
        dataType: BASTensorDataType,
        backingKind: BASTensorBackingKind,
        rankTag: String
    ) {
        self.shape = shape
        self.strides = strides
        self.dataType = dataType
        self.backingKind = backingKind
        self.rankTag = rankTag
    }

    /// Total element count = product of shape entries。
    /// Defined as 1 for rank-0 scalars。
    public var elementCount: Int {
        if shape.isEmpty { return 1 }
        return shape.reduce(1, *)
    }

    /// Total byte count = elementCount × dtype.byteWidth。
    /// Read this for buffer-allocation sizing。
    public var byteCount: Int {
        return elementCount * dataType.byteWidth
    }

    /// Compile-time-evidenced rank (if matches a known
    /// phantom shape)。 Returns -1 for `_NDim` dynamic
    /// rank。
    public var rank: Int {
        return shape.count
    }

    // MARK: - Constructors

    /// Build a descriptor for a row-major contiguous
    /// tensor of the given shape + dtype + backing kind。
    /// Strides are computed automatically (last axis =
    /// dtype.byteWidth)。
    ///
    /// Use this for the common case where the tensor lives
    /// in contiguous memory with no transposition or view。
    public static func contiguous(
        shape: [Int],
        dataType: BASTensorDataType,
        backingKind: BASTensorBackingKind,
        rankTag: String
    ) -> BASTensorDescriptor {
        let strides = Self.defaultStrides(
            shape: shape,
            byteWidth: dataType.byteWidth)
        return BASTensorDescriptor(
            shape: shape,
            strides: strides,
            dataType: dataType,
            backingKind: backingKind,
            rankTag: rankTag)
    }

    /// Compute default row-major strides for the given
    /// shape + element byte width。 Last axis stride =
    /// byteWidth; each preceding axis = next axis stride
    /// × next axis size。
    public static func defaultStrides(
        shape: [Int],
        byteWidth: Int
    ) -> [Int] {
        guard !shape.isEmpty else { return [] }
        var strides: [Int] = Array(
            repeating: 0, count: shape.count)
        var running = byteWidth
        for axis in stride(
            from: shape.count - 1, through: 0, by: -1)
        {
            strides[axis] = running
            running *= shape[axis]
        }
        return strides
    }
}
