// MARK: - BASCanonicalKernelInputBuilders
// chapter 四百七十五 / M1276 — REAL HOT-PATH ATTACK phase 2
//
// Closes the "EchoKernel placeholder" gap that chapter 474
// M1274 explicitly listed as a chapter-475+ planned-future-
// cut。 The chapter 474 end-to-end integration test used
// `EchoKernel` (a test-only stub that echoes inputs to
// outputs) to prove the routed-executor → registry →
// kernel-evaluate chain composed correctly。 But the REAL
// kernels (BASMPSGraphMatMulKernel etc.) had no helpers for
// constructing valid Float32 inputs from typed scalar
// arrays。 Hosts wanting to test the real MPSGraph kernels
// had to hand-build `Data` payloads + `BASTensorDescriptor`
// shapes — error-prone + duplicated across every test。
//
// `BASCanonicalKernelInputBuilders` ships typed helpers:
//
//   - `matMul(a:b:M:K:N:)` returns `BASKernelInputs` with
//     2 rank-2 Float32 descriptors + raw bytes
//   - `rmsNorm(input:gamma:hiddenDim:)` returns
//     `BASKernelInputs` with input + gamma weight descriptors
//   - `rotaryEmbedding(input:cosTable:sinTable:sequenceLength:
//     headDim:)` returns the 3 expected descriptors
//
// Each helper preconditions shape compatibility,packs
// Float values into Data via withUnsafeBytes for endian-
// safe transport,and produces metalBuffer-backed
// descriptors matching the MPSGraph kernel keys。
//
// ## Why this is real hot-path value
//
// Before M1276:zero substrate-side surface for constructing
// real kernel inputs — every test built Data payloads by
// hand。 After M1276:typed helpers + 1 line per input。
// M1277 uses these helpers to prove
// `BASMPSGraphMatMulKernel.evaluate` produces correct
// numerical output for `[[1,2],[3,4]] · [[5,6],[7,8]] =
// [[19,22],[43,50]]` — the FIRST test in the substrate
// where an MPSGraph kernel runs with real inputs。
//
// ## Doctrine pins held
//
//   - chapter 一百八十五 — typed helpers prevent magic
//     byte-counts + raw shape arrays
//   - chapter 二百一一 — single source-of-truth for
//     "how to build a matMul input bundle"
//   - chapter 三百九二 — replay-determinism (Float32
//     bit-exact packing via withUnsafeBytes)
//   - ADR-014 OPT-IN — additive only,no existing
//     surface mutated
//   - 红线 7 — hint-only (helpers produce input
//     envelopes;commitment authority unchanged)

import Foundation

/// Factory namespace producing typed `BASKernelInputs`
/// for the canonical MPSGraph kernels。
public enum BASCanonicalKernelInputBuilders {

    // MARK: - matMul input builder

    /// Build a 2-input bundle for matMul:
    ///   - A: rank-2 Float32 of shape `[M, K]`
    ///   - B: rank-2 Float32 of shape `[K, N]`
    /// Pre-conditions:
    ///   - `a.count == M*K`
    ///   - `b.count == K*N`
    ///   - All dimensions > 0
    public static func matMul(
        a: [Float],
        b: [Float],
        M: Int,
        K: Int,
        N: Int
    ) -> BASKernelInputs {
        precondition(M > 0 && K > 0 && N > 0,
            "matMul dims must be > 0")
        precondition(a.count == M * K,
            "matMul A array length must equal M*K" +
            " (got \(a.count), expected \(M * K))")
        precondition(b.count == K * N,
            "matMul B array length must equal K*N" +
            " (got \(b.count), expected \(K * N))")
        let descA = BASTensorDescriptor(
            shape: [M, K],
            strides: [K * MemoryLayout<Float>.stride,
                      MemoryLayout<Float>.stride],
            dataType: .float32,
            backingKind: .metalBuffer,
            rankTag: "rank-2-matrix")
        let descB = BASTensorDescriptor(
            shape: [K, N],
            strides: [N * MemoryLayout<Float>.stride,
                      MemoryLayout<Float>.stride],
            dataType: .float32,
            backingKind: .metalBuffer,
            rankTag: "rank-2-matrix")
        let dataA = floatArrayToData(a)
        let dataB = floatArrayToData(b)
        return BASKernelInputs(
            descriptors: [descA, descB],
            payloads: [dataA, dataB])
    }

    // MARK: - rmsNorm input builder

    /// Build a 2-input bundle for rmsNorm:
    ///   - input: rank-2 Float32 of shape
    ///     `[batchSeq, hiddenDim]`
    ///   - gamma: rank-1 Float32 of shape `[hiddenDim]`
    /// Pre-conditions:
    ///   - `input.count == batchSeq * hiddenDim`
    ///   - `gamma.count == hiddenDim`
    public static func rmsNorm(
        input: [Float],
        gamma: [Float],
        batchSeq: Int,
        hiddenDim: Int
    ) -> BASKernelInputs {
        precondition(batchSeq > 0 && hiddenDim > 0,
            "rmsNorm dims must be > 0")
        precondition(
            input.count == batchSeq * hiddenDim,
            "rmsNorm input array length must equal" +
            " batchSeq*hiddenDim (got \(input.count)," +
            " expected \(batchSeq * hiddenDim))")
        precondition(gamma.count == hiddenDim,
            "rmsNorm gamma array length must equal" +
            " hiddenDim (got \(gamma.count), expected" +
            " \(hiddenDim))")
        let descInput = BASTensorDescriptor(
            shape: [batchSeq, hiddenDim],
            strides: [hiddenDim * MemoryLayout<Float>.stride,
                      MemoryLayout<Float>.stride],
            dataType: .float32,
            backingKind: .metalBuffer,
            rankTag: "rank-2-matrix")
        let descGamma = BASTensorDescriptor(
            shape: [hiddenDim],
            strides: [MemoryLayout<Float>.stride],
            dataType: .float32,
            backingKind: .metalBuffer,
            rankTag: "rank-1-vector")
        return BASKernelInputs(
            descriptors: [descInput, descGamma],
            payloads: [
                floatArrayToData(input),
                floatArrayToData(gamma)
            ])
    }

    // MARK: - rotaryEmbedding input builder

    /// Build a 3-input bundle for rotaryEmbedding:
    ///   - input: rank-3 Float32 shape `[seq, heads, headDim]`
    ///   - cos: rank-2 Float32 shape `[seq, headDim/2]`
    ///   - sin: rank-2 Float32 shape `[seq, headDim/2]`
    /// Pre-conditions:
    ///   - `headDim` is even
    ///   - `input.count == seq * heads * headDim`
    ///   - `cos.count == sin.count == seq * (headDim/2)`
    public static func rotaryEmbedding(
        input: [Float],
        cosTable: [Float],
        sinTable: [Float],
        sequenceLength: Int,
        heads: Int,
        headDim: Int
    ) -> BASKernelInputs {
        precondition(
            sequenceLength > 0 && heads > 0 && headDim > 0,
            "rotaryEmbedding dims must be > 0")
        precondition(
            headDim % 2 == 0,
            "rotaryEmbedding headDim must be even" +
            " (got \(headDim))")
        let half = headDim / 2
        precondition(
            input.count ==
                sequenceLength * heads * headDim,
            "input array length must equal seq*heads*" +
            "headDim")
        precondition(cosTable.count == sequenceLength * half,
            "cosTable length must equal seq*headDim/2")
        precondition(sinTable.count == sequenceLength * half,
            "sinTable length must equal seq*headDim/2")
        let descInput = BASTensorDescriptor(
            shape: [sequenceLength, heads, headDim],
            strides: [
                heads * headDim * MemoryLayout<Float>.stride,
                headDim * MemoryLayout<Float>.stride,
                MemoryLayout<Float>.stride
            ],
            dataType: .float32,
            backingKind: .metalBuffer,
            rankTag: "rank-3-tensor")
        let descCos = BASTensorDescriptor(
            shape: [sequenceLength, half],
            strides: [half * MemoryLayout<Float>.stride,
                      MemoryLayout<Float>.stride],
            dataType: .float32,
            backingKind: .metalBuffer,
            rankTag: "rank-2-matrix")
        let descSin = BASTensorDescriptor(
            shape: [sequenceLength, half],
            strides: [half * MemoryLayout<Float>.stride,
                      MemoryLayout<Float>.stride],
            dataType: .float32,
            backingKind: .metalBuffer,
            rankTag: "rank-2-matrix")
        return BASKernelInputs(
            descriptors: [descInput, descCos, descSin],
            payloads: [
                floatArrayToData(input),
                floatArrayToData(cosTable),
                floatArrayToData(sinTable)
            ])
    }

    /// ch 1034.1 — RANK-2 RoPE input matching the SHIPPED
    /// `BASMPSGraphRotaryEmbeddingKernel` contract `[seq, headDim]`。
    ///
    /// The rank-3 `rotaryEmbedding(…)` above emits
    /// `[seq, heads, headDim]` for a hypothetical multi-head kernel
    /// that does NOT exist — the shipped kernel(M1190,8/8 native
    /// coverage,624-commit byte-equal)validates `rank == 2` and
    /// throws `shapeMismatch` on rank-3。 ch 1034's endurance probe
    /// was the first call site to feed builder→kernel and exposed the
    /// mismatch。 **Use THIS builder to feed the real kernel;the
    /// rank-3 form is retained only for a future multi-head kernel。**
    ///
    /// Pre-conditions:
    ///   - `headDim` is even
    ///   - `input.count == seq * headDim`
    ///   - `cos.count == sin.count == seq * (headDim/2)`
    public static func rotaryEmbeddingRank2(
        input: [Float],
        cosTable: [Float],
        sinTable: [Float],
        sequenceLength: Int,
        headDim: Int
    ) -> BASKernelInputs {
        precondition(
            sequenceLength > 0 && headDim > 0,
            "rotaryEmbeddingRank2 dims must be > 0")
        precondition(
            headDim % 2 == 0,
            "rotaryEmbeddingRank2 headDim must be even" +
            " (got \(headDim))")
        let half = headDim / 2
        precondition(
            input.count == sequenceLength * headDim,
            "input length must equal seq*headDim")
        precondition(cosTable.count == sequenceLength * half,
            "cosTable length must equal seq*headDim/2")
        precondition(sinTable.count == sequenceLength * half,
            "sinTable length must equal seq*headDim/2")
        let descInput = BASTensorDescriptor(
            shape: [sequenceLength, headDim],
            strides: [headDim * MemoryLayout<Float>.stride,
                      MemoryLayout<Float>.stride],
            dataType: .float32,
            backingKind: .metalBuffer,
            rankTag: "rank-2-matrix")
        let descCos = BASTensorDescriptor(
            shape: [sequenceLength, half],
            strides: [half * MemoryLayout<Float>.stride,
                      MemoryLayout<Float>.stride],
            dataType: .float32,
            backingKind: .metalBuffer,
            rankTag: "rank-2-matrix")
        let descSin = BASTensorDescriptor(
            shape: [sequenceLength, half],
            strides: [half * MemoryLayout<Float>.stride,
                      MemoryLayout<Float>.stride],
            dataType: .float32,
            backingKind: .metalBuffer,
            rankTag: "rank-2-matrix")
        return BASKernelInputs(
            descriptors: [descInput, descCos, descSin],
            payloads: [
                floatArrayToData(input),
                floatArrayToData(cosTable),
                floatArrayToData(sinTable)
            ])
    }

    // MARK: - attention input builder

    /// ch 1034.2 — Build a 3-input bundle for `BASMPSGraphAttentionKernel`:
    ///   - q: rank-2 Float32 `[seqQ, dim]`
    ///   - k: rank-2 Float32 `[seqK, dim]`
    ///   - v: rank-2 Float32 `[seqK, dim]`
    /// Completes the 5-kernel builder coverage(ch 1034.1 added rope;
    /// matMul/rmsNorm already had builders)。 Matches the kernel's
    /// rank-2 3-input contract(validation:descriptors.count==3,all
    /// shape.count==2,K/V share seqK + dim with Q)。
    /// Pre-conditions:
    ///   - all dims > 0
    ///   - `q.count == seqQ*dim`,`k.count == v.count == seqK*dim`
    public static func attention(
        q: [Float],
        k: [Float],
        v: [Float],
        seqQ: Int,
        seqK: Int,
        dim: Int
    ) -> BASKernelInputs {
        precondition(seqQ > 0 && seqK > 0 && dim > 0,
            "attention dims must be > 0")
        precondition(q.count == seqQ * dim,
            "attention Q length must equal seqQ*dim" +
            " (got \(q.count), expected \(seqQ * dim))")
        precondition(k.count == seqK * dim,
            "attention K length must equal seqK*dim" +
            " (got \(k.count), expected \(seqK * dim))")
        precondition(v.count == seqK * dim,
            "attention V length must equal seqK*dim" +
            " (got \(v.count), expected \(seqK * dim))")
        let descQ = BASTensorDescriptor(
            shape: [seqQ, dim],
            strides: [dim * MemoryLayout<Float>.stride,
                      MemoryLayout<Float>.stride],
            dataType: .float32,
            backingKind: .metalBuffer,
            rankTag: "rank-2-matrix")
        let descK = BASTensorDescriptor(
            shape: [seqK, dim],
            strides: [dim * MemoryLayout<Float>.stride,
                      MemoryLayout<Float>.stride],
            dataType: .float32,
            backingKind: .metalBuffer,
            rankTag: "rank-2-matrix")
        let descV = BASTensorDescriptor(
            shape: [seqK, dim],
            strides: [dim * MemoryLayout<Float>.stride,
                      MemoryLayout<Float>.stride],
            dataType: .float32,
            backingKind: .metalBuffer,
            rankTag: "rank-2-matrix")
        return BASKernelInputs(
            descriptors: [descQ, descK, descV],
            payloads: [
                floatArrayToData(q),
                floatArrayToData(k),
                floatArrayToData(v)
            ])
    }

    // MARK: - layerNorm input builder

    /// ch 1034.2 — Build a 3-input bundle for `BASMPSGraphLayerNormKernel`:
    ///   - x: rank-2 Float32 `[batch, hidden]`
    ///   - gamma: rank-1 Float32 `[hidden]`
    ///   - beta: rank-1 Float32 `[hidden]`
    /// Matches the kernel's contract(validation:descriptors.count==3,
    /// x rank-2,gamma+beta rank-1 of length hidden)。
    /// Pre-conditions:
    ///   - `batch > 0 && hidden > 0`
    ///   - `x.count == batch*hidden`
    ///   - `gamma.count == beta.count == hidden`
    public static func layerNorm(
        x: [Float],
        gamma: [Float],
        beta: [Float],
        batch: Int,
        hidden: Int
    ) -> BASKernelInputs {
        precondition(batch > 0 && hidden > 0,
            "layerNorm dims must be > 0")
        precondition(x.count == batch * hidden,
            "layerNorm x length must equal batch*hidden" +
            " (got \(x.count), expected \(batch * hidden))")
        precondition(gamma.count == hidden,
            "layerNorm gamma length must equal hidden" +
            " (got \(gamma.count), expected \(hidden))")
        precondition(beta.count == hidden,
            "layerNorm beta length must equal hidden" +
            " (got \(beta.count), expected \(hidden))")
        let descX = BASTensorDescriptor(
            shape: [batch, hidden],
            strides: [hidden * MemoryLayout<Float>.stride,
                      MemoryLayout<Float>.stride],
            dataType: .float32,
            backingKind: .metalBuffer,
            rankTag: "rank-2-matrix")
        let descGamma = BASTensorDescriptor(
            shape: [hidden],
            strides: [MemoryLayout<Float>.stride],
            dataType: .float32,
            backingKind: .metalBuffer,
            rankTag: "rank-1-vector")
        let descBeta = BASTensorDescriptor(
            shape: [hidden],
            strides: [MemoryLayout<Float>.stride],
            dataType: .float32,
            backingKind: .metalBuffer,
            rankTag: "rank-1-vector")
        return BASKernelInputs(
            descriptors: [descX, descGamma, descBeta],
            payloads: [
                floatArrayToData(x),
                floatArrayToData(gamma),
                floatArrayToData(beta)
            ])
    }

    // MARK: - Helpers

    /// Pack `[Float]` into `Data` via raw bytes for
    /// chapter 三百九二 replay-determinism (host-endian
    /// IEEE-754 layout matches GPU upload expectations on
    /// Apple Silicon)。
    public static func floatArrayToData(
        _ values: [Float]
    ) -> Data {
        return values.withUnsafeBufferPointer { buffer in
            Data(buffer: buffer)
        }
    }

    /// Inverse:unpack Float32 `Data` payload back into
    /// `[Float]`。 Length is derived from the descriptor's
    /// element count。
    public static func dataToFloatArray(
        _ data: Data,
        elementCount: Int
    ) -> [Float] {
        precondition(
            data.count == elementCount * MemoryLayout<Float>.stride,
            "data byte count must equal" +
            " elementCount * MemoryLayout<Float>.stride")
        return data.withUnsafeBytes { rawBuffer in
            let typedBuffer = rawBuffer
                .bindMemory(to: Float.self)
            return Array(typedBuffer)
        }
    }
}
