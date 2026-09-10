// MARK: - BASMatMulKernel — chapter 四百三十一 / M1099
// 系统熵 reduction
//
// RADICAL EVOLUTION SWEEP Phase E close-out entry。 First
// reference kernel:CPU-only Float32 row-major matrix
// multiply。
//
// ## Why this exists (system entropy framing)
//
// The kernel registry (M1098) ships an empty dispatch
// table。 M1099 ships 3 reference kernels (matMul,
// rmsNorm,rotaryEmbedding) so the registry has its first
// real registrations + the test surface proves the
// dispatch contract end-to-end with actual numerical
// outputs (not just stub identity echoes)。
//
// `BASMatMulKernel` ships the Float32 row-major reference
// implementation:`(M × K) · (K × N) → (M × N)`。 Pure-CPU
// + scalar (no Accelerate / vDSP / MPS yet) so it runs
// identically on simulator + macOS + future watchOS。 The
// hot-path GPU/ANE matmul ships when kernel-replacement
// hooks land in chapter 四百三十二+ — those replacements
// register under the same `(matMul, float32, mlxArray)` /
// `(matMul, float32, metalBuffer)` keys via the registry,
// keeping the contract uniform。
//
// ## What this ships (M1099)
//
//   - `BASMatMulKernel` conforming to `BASMetalKernel`
//     - `key = (matMul, float32, cpuBytes)`
//     - 2 inputs:`A: (M × K)` + `B: (K × N)` — both
//       rank-2 Float32 cpuBytes
//     - 1 output:`C: (M × N)` — rank-2 Float32 cpuBytes
//     - Validates rank + dtype + axis-size compatibility
//     - Reports `executionNanos` from
//       `DispatchTime.now().uptimeNanoseconds`
//
// ## Doctrine pins held
//
//   - chapter 一百八十五 — anti-magic-number (typed key,
//     typed errors)
//   - chapter 二百一一 — single source-of-truth (one
//     matmul kernel under one key;GPU replacements use
//     the same key)
//   - chapter 三百九二 — replay-determinism (scalar Float32
//     IEEE arithmetic is bit-exact for the same inputs;
//     no parallel reduction reordering)
//   - ADR-014 OPT-IN — purely additive
//   - 红线 7 — hint-only

import Foundation

/// CPU-only Float32 row-major reference matrix multiply。
/// Registered under `(matMul, float32, cpuBytes)`。
public struct BASMatMulKernel: BASMetalKernel {

    public let key: BASKernelKey = BASKernelKey(
        operation: .matMul,
        dataType: .float32,
        backingKind: .cpuBytes)

    public init() {}

    public func evaluate(
        inputs: BASKernelInputs
    ) async throws -> BASKernelOutputs {
        // Validate input bundle shape
        guard inputs.descriptors.count == 2 else {
            throw BASKernelError.shapeMismatch(
                reason: "matMul expects exactly 2 inputs " +
                "(A, B);got \(inputs.descriptors.count)")
        }
        let descA = inputs.descriptors[0]
        let descB = inputs.descriptors[1]
        // Validate dtypes
        for d in inputs.descriptors {
            guard d.dataType == .float32 else {
                throw BASKernelError.dataTypeMismatch(
                    expected: .float32,
                    actual: d.dataType)
            }
        }
        // Validate ranks
        guard descA.shape.count == 2,
              descB.shape.count == 2
        else {
            throw BASKernelError.shapeMismatch(
                reason: "matMul expects rank-2 inputs;" +
                " got A.rank=\(descA.shape.count)," +
                " B.rank=\(descB.shape.count)")
        }
        let M = descA.shape[0]
        let K = descA.shape[1]
        let K2 = descB.shape[0]
        let N = descB.shape[1]
        guard K == K2 else {
            throw BASKernelError.shapeMismatch(
                reason: "matMul inner dims must match:" +
                " A is \(M)×\(K),B is \(K2)×\(N)")
        }

        let startTick = DispatchTime.now()
            .uptimeNanoseconds

        // Read inputs as Float32 arrays
        let aFloats = inputs.payloads[0]
            .toFloat32Array(elementCount: M * K)
        let bFloats = inputs.payloads[1]
            .toFloat32Array(elementCount: K * N)

        // Output buffer
        var cFloats: [Float] = Array(
            repeating: 0, count: M * N)
        for i in 0..<M {
            for j in 0..<N {
                var acc: Float = 0
                for k in 0..<K {
                    acc += aFloats[i * K + k]
                        * bFloats[k * N + j]
                }
                cFloats[i * N + j] = acc
            }
        }

        let endTick = DispatchTime.now()
            .uptimeNanoseconds
        let elapsed = endTick &- startTick

        // Build output bundle
        let outDesc = BASTensorDescriptor.contiguous(
            shape: [M, N],
            dataType: .float32,
            backingKind: .cpuBytes,
            rankTag: _2D.rankTag)
        let outBytes = cFloats.toFloat32Data()
        return BASKernelOutputs(
            descriptors: [outDesc],
            payloads: [outBytes],
            executionNanos: elapsed)
    }
}

// MARK: - Float32 ↔ Data helpers (file-scope)

extension Data {

    /// Decode `count` Float32 values from this Data。
    /// Precondition:`self.count == count * 4`。
    func toFloat32Array(elementCount count: Int) -> [Float] {
        precondition(
            self.count == count * 4,
            "Data byte count \(self.count) does not match " +
            "expected \(count * 4) for Float32 array")
        return self.withUnsafeBytes { rawBuffer -> [Float] in
            let typed = rawBuffer.bindMemory(to: Float.self)
            return Array(typed)
        }
    }
}

extension Array where Element == Float {

    /// Encode this Float array as Data (little-endian on
    /// all Apple Silicon — the only platform that ships
    /// this kernel today)。
    func toFloat32Data() -> Data {
        return self.withUnsafeBufferPointer { buf in
            return Data(buffer: buf)
        }
    }
}
