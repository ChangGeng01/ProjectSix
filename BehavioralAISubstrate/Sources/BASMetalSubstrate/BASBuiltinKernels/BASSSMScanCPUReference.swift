// MARK: - BASSSMScanCPUReference
// chapter 六百七十八 / M2090 第二刀 — pure-Swift CPU
//                                    reference implementation
//                                    of the chapter 677
//                                    M2085 MSL kernel for
//                                    cross-validation +
//                                    fallback on platforms
//                                    without Metal。
//
// ## Why this exists
//
// The chapter 六百七十八 / M2089 BASMetalSSMScanKernel
// dispatches on real Apple Silicon GPU。 To assert
// numerical correctness vs. an independent oracle,we
// need a CPU implementation of the SAME math。 BASSSM
// ScanCPUReference is that reference:
//
//   - Pure Swift,no Metal dependency
//   - Same recurrence formula + same sequential
//     reduction order as MSL
//   - Same row-major (B, L, D) indexing
//   - Float32 throughout
//
// The chapter 六百八十 / M2097-M2100 numerical PROOF
// tests will compare GPU output vs. CPU reference
// output on the same inputs + assert MAE ≤ 1e-5。
//
// ## Bonus:fallback path
//
// Platforms without Metal (e.g. Linux,watchOS) can use
// this CPU reference directly。 It's slower than GPU
// dispatch but produces the same numerical output and
// preserves the recurrence's mathematical correctness。
//
// ## Doctrine pins held
//
//   - chapter 一百八十五 — typed shape struct via
//     BASSSMScanShape;no magic literals
//   - chapter 二百一一 — single source-of-truth for the
//     mathematical recurrence (MSL kernel + this CPU
//     reference must agree byte-equal modulo FMA
//     reorder tolerance)
//   - chapter 三百九二 — replay-determinism (sequential
//     reduction over time,no parallelism,bit-stable
//     Float32 output)

import Foundation

/// Pure-Swift CPU implementation of the chapter 六百七十七
/// M2085 SSMScan MSL kernel。 Used for:
///
///   1. Numerical PROOF cross-validation vs. GPU output
///      (chapter 六百八十 / M2097-M2100)
///   2. Fallback dispatch on platforms without Metal
///   3. Reference implementation documenting the math in
///      Swift
public enum BASSSMScanCPUReference {

    /// Compute selective-scan output y on CPU。
    ///
    /// - Parameters:
    ///   - x:     (B, L, D) row-major float32 input
    ///   - delta: (B, L, D) row-major float32 time step
    ///   - A:     (D,)      float32 per-channel decay
    ///   - B:     (B, L, D) row-major float32 input proj
    ///   - C:     (B, L, D) row-major float32 output proj
    ///   - shape: (B, L, D) shape struct
    /// - Returns: (B, L, D) row-major float32 output y
    /// - Throws: BASSSMScanCPUReferenceError on payload
    ///           byte-count mismatch
    public static func scan(
        x: [Float],
        delta: [Float],
        A: [Float],
        B: [Float],
        C: [Float],
        shape: BASSSMScanShape
    ) throws -> [Float] {
        // Stateless entry point — byte-identical to before: a zero initial state, final state dropped.
        let bdCount = Int(shape.B) * Int(shape.D)
        return try scanWithState(
            x: x, delta: delta, A: A, B: B, C: C, shape: shape,
            initialState: [Float](repeating: 0.0, count: bdCount)).y
    }

    /// chapter 一百八十八 — cross-turn (TEMPORAL) variant. Seeds the per-(batch,channel) hidden state
    /// `h` from `initialState` (count == B*D, indexed `b*D + d`) and RETURNS the final per-(batch,channel)
    /// state, so a host can carry the recurrence across turns (the operator's state-space "memory").
    /// `scan(...)` is exactly this with a zero initial state and the final state dropped — byte-identical.
    /// Same recurrence / sequential reduction order / Float32 as the MSL twin (chapter 二百一一 / 三百九二).
    public static func scanWithState(
        x: [Float],
        delta: [Float],
        A: [Float],
        B: [Float],
        C: [Float],
        shape: BASSSMScanShape,
        initialState: [Float]
    ) throws -> (y: [Float], finalState: [Float]) {
        // Validate input lengths
        let bldCount = shape.elementCount
        let dCount = Int(shape.D)
        let bdCount = Int(shape.B) * dCount

        if x.count != bldCount {
            throw BASSSMScanCPUReferenceError
                .payloadCountMismatch(
                    name: "x",
                    expected: bldCount,
                    actual: x.count)
        }
        if delta.count != bldCount {
            throw BASSSMScanCPUReferenceError
                .payloadCountMismatch(
                    name: "delta",
                    expected: bldCount,
                    actual: delta.count)
        }
        if A.count != dCount {
            throw BASSSMScanCPUReferenceError
                .payloadCountMismatch(
                    name: "A",
                    expected: dCount,
                    actual: A.count)
        }
        if B.count != bldCount {
            throw BASSSMScanCPUReferenceError
                .payloadCountMismatch(
                    name: "B",
                    expected: bldCount,
                    actual: B.count)
        }
        if C.count != bldCount {
            throw BASSSMScanCPUReferenceError
                .payloadCountMismatch(
                    name: "C",
                    expected: bldCount,
                    actual: C.count)
        }
        if initialState.count != bdCount {
            throw BASSSMScanCPUReferenceError
                .payloadCountMismatch(
                    name: "initialState",
                    expected: bdCount,
                    actual: initialState.count)
        }

        var y = [Float](repeating: 0.0, count: bldCount)
        var finalState = [Float](repeating: 0.0, count: bdCount)

        let batchInt = Int(shape.B)
        let lengthInt = Int(shape.L)
        let channelsInt = Int(shape.D)

        // Outer loop:per (batch, channel) thread
        // Inner loop:sequential scan over time
        // Order matches MSL kernel exactly。
        for b in 0..<batchInt {
            for d in 0..<channelsInt {
                let A_d = A[d]
                // Seed the recurrence from the carried-in state (zero in the stateless path).
                var h: Float = initialState[b * channelsInt + d]

                for t in 0..<lengthInt {
                    let idx = shape.linearIndex(
                        b: b, t: t, d: d)
                    let x_t = x[idx]
                    let delta_t = delta[idx]
                    let B_t = B[idx]
                    let C_t = C[idx]

                    // Zero-order hold discretization
                    let A_bar = expf(delta_t * A_d)
                    let B_bar = delta_t * B_t

                    // Recurrence step
                    h = A_bar * h + B_bar * x_t

                    // Output projection
                    y[idx] = C_t * h
                }

                // Carry the final per-channel state out for the next turn.
                finalState[b * channelsInt + d] = h
            }
        }
        return (y, finalState)
    }

    /// Convenience overload accepting Data-encoded payloads
    /// (matches BASKernelInputs/Outputs pattern)。 Decodes
    /// Data bytes as little-endian float32 arrays,calls
    /// the array-based scan(), and re-encodes the output
    /// as Data。
    public static func scan(
        xData: Data,
        deltaData: Data,
        aData: Data,
        bData: Data,
        cData: Data,
        shape: BASSSMScanShape
    ) throws -> Data {
        let x = decodeFloats(xData)
        let delta = decodeFloats(deltaData)
        let A = decodeFloats(aData)
        let B = decodeFloats(bData)
        let C = decodeFloats(cData)

        let y = try scan(
            x: x, delta: delta, A: A, B: B, C: C,
            shape: shape)

        return y.withUnsafeBufferPointer { buf in
            Data(buffer: buf)
        }
    }

    // MARK: - Helpers

    private static func decodeFloats(
        _ data: Data
    ) -> [Float] {
        let count = data.count / 4
        return data.withUnsafeBytes { raw -> [Float] in
            let ptr = raw.bindMemory(to: Float.self)
            return Array(ptr[0..<count])
        }
    }
}

// MARK: - Typed error

/// Typed error for BASSSMScanCPUReference validation
/// failures。
public enum BASSSMScanCPUReferenceError:
    Error, Equatable, Sendable, Codable
{
    case payloadCountMismatch(
        name: String,
        expected: Int,
        actual: Int)
}
