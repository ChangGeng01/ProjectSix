// MARK: - BASCoreAINDArrayBridge
//
// The marshaling boundary between a flat, row-major `[Float]` (+ shape) and Apple Core AI's `NDArray`
// (`CoreAIRuntime`). Core AI inference is tensor-level — `InferenceFunction.run(inputs: [String: NDArray])` —
// so every value crossing into / out of a Core AI model passes through this bridge.
//
// ## Two layers, on purpose
//
// 1. **Pure shape/stride/count math** (`elementCount`, `rowMajorStrides`, `validate`) — FRAMEWORK-FREE. It
//    compiles + RUNS under any toolchain, including the default Xcode 26.5 build where `canImport(CoreAI)` is
//    false. So the marshal logic carries real unit-test coverage TODAY (no Core AI runtime required).
// 2. **The actual `NDArray` construction / readback** (`makeNDArray`, `floats(from:)`) — `#if canImport(CoreAI)`
//    gated + `@available(iOS 27, macOS 27, *)`. It compiles only under Xcode 27 (compile-certified there) and
//    runs only on iOS 27 / macOS 27 (run-certified on the iOS 27 simulator + iPhone Air).
//
// ## Determinism boundary (红线 7)
//
// Core AI is reasoning-side / hint-only. Nothing here may feed the byte-deterministic Rust+SQL spine — the
// determinism-boundary tripwire bans `CoreAI*` / `BASCoreAI*` from spine sources.

import Foundation

#if canImport(CoreAI)
import CoreAI   // umbrella — @_exported re-exports CoreAIRuntime (NDArray) + CoreAIAsset + CoreAIDelegates.
#endif

// MARK: - Errors

/// Errors from the pure marshaling boundary between a flat `[Float]` (+ shape) and Core AI's `NDArray`.
public enum BASCoreAINDArrayBridgeError: Error, Equatable, Hashable, Sendable {
    /// `shape` was empty (rank-0). The small-head contract requires a ranked tensor (e.g. `[1, 256]`).
    case emptyShape
    /// A dimension was `< 1`. Core AI tensors require strictly-positive extents.
    case nonPositiveDimension(shape: [Int])
    /// `scalars.count` did not equal the product of `shape`.
    case scalarCountMismatch(shapeProduct: Int, scalarCount: Int, shape: [Int])
    /// The dimension product overflowed `Int` — a pathological shape can never validate (it could otherwise
    /// wrap to a small number and falsely match a tiny buffer).
    case shapeProductOverflow(shape: [Int])
}

// MARK: - Bridge

/// Pure + gated marshaling helpers between a flat row-major `[Float]` (+ shape) and Core AI's `NDArray`.
public enum BASCoreAINDArrayBridge {

    // MARK: Pure shape math (framework-free — run-tested under any toolchain)

    /// Number of scalars a row-major tensor of `shape` addresses — the product of its dimensions.
    /// An empty shape (rank-0) has the empty product `1`; callers should use `validate` to reject it for the
    /// ranked small-head contract.
    public static func elementCount(of shape: [Int]) -> Int {
        shape.reduce(1, *)
    }

    /// Row-major (C-contiguous) strides for `shape`. e.g. `[2, 3, 4]` → `[12, 4, 1]`.
    /// The last dimension is contiguous (stride `1`); each earlier stride is the product of all later dims.
    public static func rowMajorStrides(for shape: [Int]) -> [Int] {
        guard !shape.isEmpty else { return [] }
        var strides = Array(repeating: 1, count: shape.count)
        var accumulated = 1
        var index = shape.count - 1
        while index >= 0 {
            strides[index] = accumulated
            accumulated *= shape[index]
            index -= 1
        }
        return strides
    }

    /// Validate that a flat buffer of `scalarCount` scalars matches `shape` for the ranked small-head contract:
    /// a non-empty shape, every dimension `>= 1`, and `scalarCount == product(shape)`. Throws otherwise.
    /// The product is computed with CHECKED multiplication — a pathological shape whose product overflows `Int`
    /// throws `.shapeProductOverflow` instead of wrapping (a wrapped product could falsely match a tiny buffer).
    public static func validate(scalarCount: Int, shape: [Int]) throws {
        guard !shape.isEmpty else {
            throw BASCoreAINDArrayBridgeError.emptyShape
        }
        guard shape.allSatisfy({ $0 >= 1 }) else {
            throw BASCoreAINDArrayBridgeError.nonPositiveDimension(shape: shape)
        }
        var product = 1
        for dimension in shape {
            let (next, overflowed) = product.multipliedReportingOverflow(by: dimension)
            guard !overflowed else {
                throw BASCoreAINDArrayBridgeError.shapeProductOverflow(shape: shape)
            }
            product = next
        }
        guard product == scalarCount else {
            throw BASCoreAINDArrayBridgeError.scalarCountMismatch(
                shapeProduct: product, scalarCount: scalarCount, shape: shape)
        }
    }

    // MARK: Gated NDArray bridge (compile-cert Xcode 27, run-cert iOS 27)

    #if canImport(CoreAI)

    /// Build a Float32 `NDArray` from a validated flat row-major `[Float]` + `shape`.
    /// Throws `BASCoreAINDArrayBridgeError` if `scalars` does not match `shape` (fail-fast at the boundary).
    @available(iOS 27, macOS 27, *)
    public static func makeNDArray(scalars: [Float], shape: [Int]) throws -> NDArray {
        try validate(scalarCount: scalars.count, shape: shape)
        return NDArray(scalars: scalars, shape: shape)
    }

    /// Copy a Float32 `NDArray`'s scalars back into a flat row-major `[Float]`.
    ///
    /// Reads `product(shape)` contiguous elements via the borrowed `View<Float>` pointer — valid for the
    /// contiguous outputs the small-head models produce (e.g. `[1, 7]` logits). A non-contiguous output would
    /// require a strided gather; that is out of scope for the small-head lane and asserted via `isContiguous`.
    @available(iOS 27, macOS 27, *)
    public static func floats(from ndArray: NDArray) -> [Float] {
        let count = elementCount(of: ndArray.shape)
        var out = [Float]()
        out.reserveCapacity(count)
        // Inline the borrowed `~Escapable` View rather than binding it to a `let` (the borrow checker rejects
        // escaping a non-escapable view). Reads `count` contiguous Float32s — valid for small-head outputs.
        ndArray.view(as: Float.self).withUnsafePointer { pointer, _, _ in
            var i = 0
            while i < count {
                out.append(pointer[i])
                i += 1
            }
        }
        return out
    }

    #endif
}
