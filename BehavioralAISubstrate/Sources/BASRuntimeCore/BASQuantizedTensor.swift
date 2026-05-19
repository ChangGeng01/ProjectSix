// MARK: - BASQuantizedTensor
// chapter 七百二十六 第四刀 / M2304
//
// Typed Swift wrapper for int8-quantized tensors。 Replaces the
// (Int8 buffer + Float scale + Int shape) tuple-passing with a
// Codable Sendable Hashable struct so hosts can store / pass /
// persist quantized tensors with full type safety。
//
// Foundation for chapters 七百二十七 (int8 vector storage) +
// 七百二十八 (int8 KV cache):both wrap their data payload in
// `BASQuantizedTensor` values。
//
// ## Wire format (Codable)
//
//   {
//       "shape":   [Int...],       (1+ dimensions)
//       "data":    Data (base64),  (int8 bytes — Data Codable
//                                   encodes as base64 in JSON)
//       "scale":   Double,         (quantization scale)
//       "version": 1               (schema pin)
//   }
//
// Shape is stored as `[Int]` so 1D (vectors) and 2D (matrices)
// share the same type。 `data.count` must equal product of
// `shape` — checked via `validate()`。

import Foundation

public struct BASQuantizedTensor: Codable, Sendable, Hashable {

    public static let schemaVersion: Int = 1

    /// Shape in row-major order。 For a vector this is [N];for
    /// a matrix [M, N]。 Higher dimensions allowed but unused
    /// in the current arc (chapters 七百二十七 / 七百二十八
    /// stick to 1D + 2D)。
    public let shape: [Int]

    /// Quantized payload。 Stored as `Data` (not [Int8])so
    /// JSONEncoder produces base64 — compact wire bytes that
    /// reflect the underlying memory savings。 `Data` count
    /// always equals `shape.reduce(1, *)` — checked at init。
    public let data: Data

    /// Float32 scale used during quantization。 Multiply int8
    /// values by this to dequantize。
    public let scale: Float

    /// Codable schema version for forward-compat。 Bump when the
    /// wire format changes (e.g。 asymmetric quantization,
    /// per-channel scales,etc)。
    public let version: Int

    public enum BASQuantizedTensorError: Error, Equatable {
        case shapeMismatch(
            expected: Int, actual: Int)
        case unsupportedSchemaVersion(Int)
    }

    /// Construct from already-quantized buffer + scale。 Throws
    /// `.shapeMismatch` if `quantized.count != shape.reduce(1, *)`。
    public init(
        shape: [Int],
        quantized: [Int8],
        scale: Float,
        version: Int = BASQuantizedTensor.schemaVersion
    ) throws {
        let expected = shape.reduce(1, *)
        guard quantized.count == expected else {
            throw BASQuantizedTensorError.shapeMismatch(
                expected: expected,
                actual: quantized.count)
        }
        self.shape = shape
        // Convert [Int8] → Data via raw byte reinterpretation
        self.data = quantized.withUnsafeBufferPointer { bp in
            return Data(buffer: bp)
        }
        self.scale = scale
        self.version = version
    }

    /// Construct from a Float32 array + shape。 Quantizes via
    /// chapter 七百二十六 第二刀 `BASAutoRouteRanker.quantizeInt8`,
    /// then wraps the result。
    public init?(
        floatValues: [Float],
        shape: [Int]
    ) {
        let expected = shape.reduce(1, *)
        guard floatValues.count == expected else {
            return nil
        }
        guard let qr = BASAutoRouteRanker.quantizeInt8(
            floatValues)
        else { return nil }
        do {
            try self.init(
                shape: shape,
                quantized: qr.quantized,
                scale: qr.scale)
        } catch {
            return nil
        }
    }

    /// Number of int8 values stored。 Equal to `shape.reduce(1, *)`。
    public var count: Int {
        return shape.reduce(1, *)
    }

    /// Memory size in bytes (data + scale + shape ints)。 Used by
    /// chapter 七百二十七 BASVectorIndex to budget RAM。
    public var byteSize: Int {
        return data.count
            + MemoryLayout<Float>.size
            + shape.count * MemoryLayout<Int>.size
    }

    /// Theoretical Float32 byte size for comparison。
    public var float32EquivalentByteSize: Int {
        return count * MemoryLayout<Float>.size
    }

    /// Memory shrink ratio。 Typical value ~4× (substract the
    /// tiny scale + shape overhead → just under 4)。
    public var memoryShrinkRatio: Double {
        return Double(float32EquivalentByteSize)
            / Double(byteSize)
    }

    /// Extract the int8 buffer as a typed `[Int8]`。 Cost is
    /// one `Data → [Int8]` conversion — O(N) but cache-friendly。
    public func toInt8Array() -> [Int8] {
        return data.withUnsafeBytes { rawBuf in
            let p = rawBuf.bindMemory(to: Int8.self)
            return Array(p)
        }
    }

    /// Dequantize back to Float32。 Returns nil if the FFI fails
    /// (extremely unlikely from a valid tensor)。
    public func dequantizeToFloat32() -> [Float]? {
        return BASAutoRouteRanker.dequantizeInt8(
            toInt8Array(), scale: scale)
    }
}
