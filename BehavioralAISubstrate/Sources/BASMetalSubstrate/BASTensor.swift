// MARK: - BASTensor — chapter 四百三十一 / M1096
// 系统熵 reduction
//
// RADICAL EVOLUTION SWEEP Phase E entry。 First substrate-
// level typed tensor primitive。
//
// ## Why this exists (system entropy framing)
//
// The user's M1080-era directive — "原生利用神经引擎" — is
// blocked at the substrate level by the absence of a typed
// tensor primitive。 Today every adapter (BASMLXAdapter,
// future BASCoreMLAdapter, BASMetalKernelRegistry) traffics
// in untyped `Any` / `AnyObject` / raw `Data`。 No compile-
// time dimension safety,no shared backing-kind language,
// no Sendable wire format。
//
// `BASTensor<Element, Shape>` ships:
//   - phantom-type rank evidence (`Shape`)
//   - phantom-type scalar evidence (`Element`)
//   - runtime backing kind discriminator
//   - opaque `AnyObject` payload for MLX/CoreML/Metal
//     handles (so this module stays MLX/CoreML-import-free)
//   - raw `Data` payload for CPU + simulator fallback
//   - Sendable `BASTensorDescriptor` envelope for crossing
//     actor + process boundaries
//
// Kernel registry (M1098) + adapter layers (BASMLXAdapter
// updated in Phase F) consume `BASTensor`'s descriptor +
// dispatch on `backingKind` to route to the right
// framework — without BASMetalSubstrate ever importing
// MLX or CoreML directly。
//
// ## What this ships (M1096)
//
//   - `@propertyWrapper public struct BASTensor<Element:
//     BASTensorScalar, Shape: BASTensorShape>`
//   - `BASTensorBacking` discriminated payload union
//     with 4 cases:`mlxArray(AnyObject)` /
//     `mlMultiArray(AnyObject)` / `metalBuffer(AnyObject)`
//     / `cpuBytes(Data)`。
//   - 4 typed factories:`mlx(_:descriptor:)` /
//     `coreML(_:descriptor:)` / `metal(_:descriptor:)` /
//     `cpu(_:descriptor:)`。
//   - `descriptor` accessor returning the Sendable
//     envelope for cross-actor / event-log replay。
//   - `wrappedValue` returning the discriminated backing
//     for kernel dispatch。
//   - `cpuBytesIfAvailable` accessor for the test path +
//     simulator builds。
//
// ## Doctrine pins held
//
//   - chapter 一百八十五 — anti-magic-number。 Backing,
//     dtype,rank are all typed enums / phantoms。
//   - chapter 二百一一 — single-source-of-truth。 The
//     descriptor is the one Sendable wire format。
//   - chapter 三百九二 — replay-determinism。 Descriptor
//     is byte-stable Codable,backing is reconstructed
//     from `cpuBytes` on the replay side (MLX/CoreML/Metal
//     handles are runtime-only,not replayed)。
//   - ADR-014 OPT-IN — purely additive。
//   - ADR-016 — chapter 四百三十一 v1 substrate completion。
//   - 不变量 #1/#2/#3 — V1 byte-equality preserved。
//   - 红线 7 — hint-only。
//
// ## Sendability discipline
//
// `BASTensor` is NOT marked `Sendable` because the opaque
// `AnyObject` payloads (MLXArray / MLMultiArray / MTLBuffer)
// are NOT thread-safe by themselves。 Cross-actor handoff
// is via the Sendable `BASTensorDescriptor` + a separate
// payload reference held inside the kernel registry actor。
// The `cpu(_:descriptor:)` variant carrying only `Data` IS
// Sendable through the descriptor。

import Foundation

// MARK: - Discriminated backing payload

/// Discriminated payload owned by a `BASTensor`。 Exactly
/// one variant carries live storage; the others are not
/// reachable for that tensor instance。
///
/// The opaque `AnyObject` cases let BASMetalSubstrate stay
/// import-free of MLX / CoreML / Metal — adapter layers
/// hold the typed handles + hand them to kernel registry
/// actors which know how to unwrap by `backingKind`。
public enum BASTensorBacking {

    /// `MLXArray` handle (Apple Silicon ARM64 only)。
    /// Opaque to BASMetalSubstrate — BASMLXAdapter unwraps
    /// at dispatch time。
    case mlxArray(AnyObject)

    /// `MLMultiArray` handle (CoreML)。 Opaque to
    /// BASMetalSubstrate — CoreML adapter unwraps at
    /// ANE-dispatch time。
    case mlMultiArray(AnyObject)

    /// `MTLBuffer` handle (raw Metal storage)。 Opaque to
    /// BASMetalSubstrate when carried alone — kernel
    /// registry holds + unwraps at MPSGraph build time。
    case metalBuffer(AnyObject)

    /// CPU-only host bytes (no GPU/ANE residence)。 Used
    /// for descriptor round-trip,simulator builds,and
    /// the unified event log replay path。
    case cpuBytes(Data)

    /// Backing kind discriminator matching the descriptor。
    public var kind: BASTensorBackingKind {
        switch self {
        case .mlxArray:      return .mlxArray
        case .mlMultiArray:  return .mlMultiArray
        case .metalBuffer:   return .metalBuffer
        case .cpuBytes:      return .cpuBytes
        }
    }
}

// MARK: - Typed property wrapper

/// Typed tensor primitive with phantom-type rank +
/// scalar evidence and discriminated runtime backing。
///
/// Usage as a property wrapper:
///
///     struct AttentionLayer {
///         @BASTensor<Float, _2D> var weights: BASTensorBacking
///     }
///
/// Usage as a struct value:
///
///     let t: BASTensor<Float, _2D> = .cpu(
///         Data(repeating: 0, count: 16),
///         descriptor: .contiguous(
///             shape: [2, 2],
///             dataType: .float32,
///             backingKind: .cpuBytes,
///             rankTag: _2D.rankTag))
///
/// The phantom `Element` + `Shape` parameters give compile-
/// time guards against dimension + dtype mismatches at
/// kernel-dispatch time。
@propertyWrapper
public struct BASTensor<
    Element: BASTensorScalar,
    Shape: BASTensorShape
> {

    /// Discriminated backing — the live storage handle。
    public var wrappedValue: BASTensorBacking

    /// Sendable descriptor envelope — shape + stride +
    /// dtype + backing kind。 Use this for cross-actor
    /// handoff and event-log replay。
    public let descriptor: BASTensorDescriptor

    /// Designated initializer。 The descriptor must agree
    /// with the phantom type evidence:
    ///
    ///   - `descriptor.dataType == Element.dataType`
    ///   - `descriptor.rankTag == Shape.rankTag`
    ///   - `descriptor.backingKind == wrappedValue.kind`
    ///
    /// Mismatch is a programmer error — preconditions
    /// catch at construction time before kernels see the
    /// tensor。
    public init(
        wrappedValue: BASTensorBacking,
        descriptor: BASTensorDescriptor
    ) {
        precondition(
            descriptor.dataType == Element.dataType,
            "BASTensor descriptor dataType " +
            "(\(descriptor.dataType.rawValue)) must match " +
            "phantom Element dataType " +
            "(\(Element.dataType.rawValue))")
        precondition(
            descriptor.rankTag == Shape.rankTag,
            "BASTensor descriptor rankTag " +
            "(\(descriptor.rankTag)) must match phantom " +
            "Shape rankTag (\(Shape.rankTag))")
        precondition(
            descriptor.backingKind == wrappedValue.kind,
            "BASTensor descriptor backingKind " +
            "(\(descriptor.backingKind.rawValue)) must " +
            "match runtime backing kind " +
            "(\(wrappedValue.kind.rawValue))")
        precondition(
            descriptor.shape.count == Shape.rank ||
                Shape.rank == -1,
            "BASTensor descriptor rank " +
            "(\(descriptor.shape.count)) must match " +
            "phantom Shape.rank (\(Shape.rank)) or use " +
            "_NDim for dynamic rank")
        self.wrappedValue = wrappedValue
        self.descriptor = descriptor
    }

    // MARK: - Typed factory constructors

    /// Build a tensor backed by an `MLXArray` handle。
    /// BASMLXAdapter passes its typed `MLXArray` as
    /// `AnyObject`; the adapter unwraps at kernel-dispatch
    /// time。
    public static func mlx(
        _ array: AnyObject,
        descriptor: BASTensorDescriptor
    ) -> BASTensor<Element, Shape> {
        return BASTensor(
            wrappedValue: .mlxArray(array),
            descriptor: descriptor)
    }

    /// Build a tensor backed by an `MLMultiArray` handle。
    /// CoreML adapter unwraps at ANE-dispatch time。
    public static func coreML(
        _ array: AnyObject,
        descriptor: BASTensorDescriptor
    ) -> BASTensor<Element, Shape> {
        return BASTensor(
            wrappedValue: .mlMultiArray(array),
            descriptor: descriptor)
    }

    /// Build a tensor backed by an `MTLBuffer` handle。
    /// Kernel registry unwraps at MPSGraph build time。
    public static func metal(
        _ buffer: AnyObject,
        descriptor: BASTensorDescriptor
    ) -> BASTensor<Element, Shape> {
        return BASTensor(
            wrappedValue: .metalBuffer(buffer),
            descriptor: descriptor)
    }

    /// Build a tensor backed by raw CPU bytes。 Used for
    /// descriptor round-trip,simulator builds,and the
    /// unified event log replay path。 Byte count must
    /// match `descriptor.byteCount` exactly。
    public static func cpu(
        _ bytes: Data,
        descriptor: BASTensorDescriptor
    ) -> BASTensor<Element, Shape> {
        precondition(
            bytes.count == descriptor.byteCount,
            "BASTensor.cpu byte count (\(bytes.count)) " +
            "must equal descriptor.byteCount " +
            "(\(descriptor.byteCount))")
        return BASTensor(
            wrappedValue: .cpuBytes(bytes),
            descriptor: descriptor)
    }

    // MARK: - Accessors

    /// Returns the raw bytes if this tensor is `cpuBytes`-
    /// backed,nil otherwise。 Used by tests + replay path
    /// + Sendable cross-actor reconstruction。
    public var cpuBytesIfAvailable: Data? {
        if case .cpuBytes(let data) = wrappedValue {
            return data
        }
        return nil
    }

    /// Total element count from descriptor (= product of
    /// shape entries)。
    public var elementCount: Int {
        return descriptor.elementCount
    }

    /// Total byte count from descriptor (= elementCount ×
    /// dtype byteWidth)。
    public var byteCount: Int {
        return descriptor.byteCount
    }
}
