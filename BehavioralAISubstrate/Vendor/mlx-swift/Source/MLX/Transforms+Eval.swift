// Copyright © 2024 Apple Inc.

import Cmlx
import Foundation

/// lock to be held while doing any eval or asyncEval.  This is
/// a recursive lock to handle any cases where a closure might
/// call back into eval.
let evalLock = NSRecursiveLock()

/// BAS/ADR-038 §11.4 — the binding previously DISCARDED `mlx_eval`/`mlx_async_eval`'s `int` return code
/// (`_ = ... mlx_eval(...)`). This surfaces a non-zero code to stderr instead of dropping it. SCOPE (honest):
/// MLX's C++ wrapper catches the exception and routes the message to the *installed* mlx error handler before
/// returning non-zero — and mlx-swift's default handler trampoline calls `fatalError`, which aborts the process
/// FIRST, so on the default path this stderr line is effectively unreachable (the abort wins). It becomes the
/// actual surfacing point only when a NON-aborting error handler is installed (e.g. for diagnostics). So this is
/// a belt-and-suspenders guard against a *future* silent-drop regression, not protection on the default config.
/// No-op on the success path (ret == 0) → the normal path is byte/behavior-identical. (A fuller fix — making
/// `eval` throwing — is an API change left as a follow-up.)
@inline(__always)
private func basSurfaceEvalError(_ ret: Int32, _ op: String) {
    if ret != 0 {
        FileHandle.standardError.write(Data("[BAS][\(op)] non-zero return=\(ret)\n".utf8))
    }
}

/// Evaluate one or more `MLXArray`
///
/// ### See Also
/// - <doc:lazy-evaluation>
public func eval(_ arrays: MLXArray...) {
    let vector_array = new_mlx_vector_array(arrays)
    let ret = evalLock.withLock {
        mlx_eval(vector_array)
    }
    mlx_vector_array_free(vector_array)
    basSurfaceEvalError(ret, "mlx_eval")
}

/// Evaluate one or more `MLXArray`
///
/// ### See Also
/// - <doc:lazy-evaluation>
public func eval(_ arrays: some Collection<MLXArray>) {
    let vector_array = new_mlx_vector_array(arrays)
    let ret = evalLock.withLock {
        mlx_eval(vector_array)
    }
    mlx_vector_array_free(vector_array)
    basSurfaceEvalError(ret, "mlx_eval")
}

/// Evaluate one or more `MLXArray` asynchronously.
///
/// ### See Also
/// - <doc:lazy-evaluation>
/// - ``asyncEval(_:)-(Collection<MLXArray>)``
public func asyncEval(_ arrays: some Collection<MLXArray>) {
    let vector_array = new_mlx_vector_array(arrays)
    let ret = evalLock.withLock {
        mlx_async_eval(vector_array)
    }
    mlx_vector_array_free(vector_array)
    basSurfaceEvalError(ret, "mlx_async_eval")
}

/// Evaluate one or more `MLXArray`.
///
/// This variant allows several structured types:
///
/// ```swift
/// let a: MLXArray
/// let b: [MLXArray]
/// let c: [String:MLXArray]
/// let d: [String:[MLXArray]]
/// let e: (MLXArray, MLXArray)
/// let f: [(String, MLXArray)]
/// let nested: [(MLXArray, [MLXArray])]
///
/// eval(a, b, c, d, e, f)
/// ```
///
/// Other structured types may be supported -- check the implementation.
///
/// ### See Also
/// - <doc:lazy-evaluation>
/// - ``asyncEval(_:)-(Collection<MLXArray>)``
public func eval(_ values: Any...) {
    var arrays = [MLXArray]()

    for item in values {
        collect(item, into: &arrays)
    }

    eval(arrays)
}

/// Evaluate one or more `MLXArray`.
///
/// See ``eval(_:)``
public func eval(_ values: some Sequence<Any>) {
    var arrays = [MLXArray]()

    for item in values {
        collect(item, into: &arrays)
    }

    eval(arrays)
}

/// Variant of ``eval(_:)-(Collection<MLXArray>)`` that checks for errors in MLX and throws.
///
/// ### See Also
/// - <doc:lazy-evaluation>
public func checkedEval(_ values: Any...) throws {
    var arrays = [MLXArray]()

    for item in values {
        collect(item, into: &arrays)
    }

    try withError {
        eval(arrays)
    }
}

/// Variant of ``eval(_:)-(MLXArray...)`` that checks for errors in MLX and throws.
///
/// ### See Also
/// - <doc:lazy-evaluation>
public func checkedEval(_ values: some Sequence<Any>) throws {
    var arrays = [MLXArray]()

    for item in values {
        collect(item, into: &arrays)
    }

    try withError {
        eval(arrays)
    }
}

/// Evaluate one or more `MLXArray` asynchronously.
///
/// This variant allows several structured types:
///
/// ```swift
/// let a: MLXArray
/// let b: [MLXArray]
/// let c: [String:MLXArray]
/// let d: [String:[MLXArray]]
/// let e: (MLXArray, MLXArray)
/// let f: [(String, MLXArray)]
/// let nested: [(MLXArray, [MLXArray])]
///
/// asyncEval(a, b, c, d, e, f)
/// ```
///
/// Other structured types may be supported -- check the implementation.
///
/// ### See Also
/// - <doc:lazy-evaluation>
public func asyncEval(_ values: Any...) {
    var arrays = [MLXArray]()

    for item in values {
        collect(item, into: &arrays)
    }

    asyncEval(arrays)
}

/// Evaluate one or more `MLXArray` asynchronously.
///
/// See ``asyncEval(_:)-(Collection<MLXArray>)``
public func asyncEval(_ values: some Sequence<Any>) {
    var arrays = [MLXArray]()

    for item in values {
        collect(item, into: &arrays)
    }

    asyncEval(arrays)
}

private func collect(_ item: Any, into arrays: inout [MLXArray]) {
    switch item {
    case let v as Evaluatable:
        arrays.append(contentsOf: v.innerState())

    case let v as NestedDictionary<String, MLXArray>:
        arrays.append(contentsOf: v.flattened().map { $0.1 })

    case let v as MLXArray:
        arrays.append(v)
    case let v as [MLXArray]:
        arrays.append(contentsOf: v)
    case let v as [Any]:
        for item in v {
            collect(item, into: &arrays)
        }
    case let v as [AnyHashable: Any]:
        for item in v.values {
            collect(item, into: &arrays)
        }
    case let v as (Any, Any):
        collect(v.0, into: &arrays)
        collect(v.1, into: &arrays)
    case let v as (Any, Any, Any):
        collect(v.0, into: &arrays)
        collect(v.1, into: &arrays)
        collect(v.2, into: &arrays)
    case let v as (Any, Any, Any, Any):
        collect(v.0, into: &arrays)
        collect(v.1, into: &arrays)
        collect(v.2, into: &arrays)
        collect(v.3, into: &arrays)
    case let v as (Any, Any, Any, Any, Any):
        collect(v.0, into: &arrays)
        collect(v.1, into: &arrays)
        collect(v.2, into: &arrays)
        collect(v.3, into: &arrays)
        collect(v.4, into: &arrays)
    case is String, is any BinaryInteger, is any BinaryFloatingPoint:
        // ignore, e.g. (String, MLXArray)
        break
    default:
        fatalError("Unable to extract MLXArray from \(item)")
    }
}
