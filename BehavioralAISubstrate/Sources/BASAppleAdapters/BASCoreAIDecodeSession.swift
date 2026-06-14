// MARK: - BASCoreAIDecodeSession
//
// The stateful **Core AI** autoregressive decode driver — the CoreAI sibling of the Core ML
// `BASCoreMLDraftSession`. Wraps a stateful `.aimodel` (built by `Tools/llama_to_coreai.py`):
// ONE fused per-layer KV cache (`state "kv"`, slots [k0,v0,k1,v1,…]) written by a host-supplied
// one-hot positional selector, driven by host-supplied RoPE cos/sin + an additive causal bias —
// the exact contract the converter traced. Owns the KV frontier (`draftPos`) and the
// prefill/step/propose/commit primitives a decoder composes; it makes NO accept/emit decision
// (that is the TARGET's job, so byte-identity is the target's argmax by construction — 红线 7 /
// ADR-039: this is the reasoning-side observation lane, never the deterministic spine).
//
// ## Why ONE fused KV state
//
// A 16-layer model has 32 per-layer K/V caches. Core AI's `run(inputs:states:)` takes a
// `~Copyable, ~Escapable MutableViews` whose inserted views are lifetime-bound to their NDArrays —
// 32 simultaneous mutable borrows is intractable. Fusing all slots into ONE `kv` state buffer
// (one `insert(&kv,…)`) sidesteps that entirely (and is the contiguous layout Phase-1 zero-copy
// wants). Within a decode step each layer touches only its own slot, so the graph reads all slots
// from the unmodified buffer and writes the whole thing back once (one `write_handle`).
//
// ## Availability
//
// `#if canImport(CoreAI)` + `@available(iOS 27, macOS 27, *)`. Under the default Xcode 26.5
// toolchain this type does not exist. Compile-certified under Xcode 27; the stateful-run ownership
// pattern (`MutableViews.insert(&kv,…)` held into the consuming `async run`) was `swiftc -typecheck`
// validated against the iPhoneOS27 SDK before wiring.
//
// `@unchecked Sendable`: driven ONLY on a single serialized executor (never concurrently), despite
// the mutable `draftPos` / `kv` NDArray — same soundness argument as `BASCoreMLDraftSession`.

import Foundation

#if canImport(CoreAI)
import CoreAI   // umbrella: AIModel, InferenceFunction, NDArray, SpecializationOptions.

@available(iOS 27, macOS 27, *)
public final class BASCoreAIDecodeSession: @unchecked Sendable {

    public enum DecodeError: Error {
        case modelLoad(String)
        case ropeTable(String)
        case windowOverflow(pos: Int, maxSeq: Int)
        case predict(String)
        case noLogits
    }

    private let model: AIModel
    private let function: InferenceFunction
    private let maxSeq: Int
    private let headDim: Int
    private let nLayers: Int
    private let nKV: Int
    private let neg: Float

    // RoPE tables [maxSeq * headDim] row-major float32 (Tools/emit_rope_tables.py — exact llama3 scaling).
    private let cosTable: [Float]
    private let sinTable: [Float]

    // The ONE fused KV state: [2*nLayers, 1, nKV, maxSeq, headDim] float32. Mutated in place by `run`.
    private var kv: NDArray
    private let kvShape: [Int]
    private let kvCount: Int

    /// Number of COMMITTED tokens; the next committed slot. KV at logical positions `0..<draftPos`
    /// holds the committed sequence; the last committed token's K/V is at position `draftPos - 1`.
    public private(set) var draftPos: Int = 0

    /// Load + specialize the stateful `.aimodel`. `nLayers`/`nKV`/`headDim` describe the fused KV
    /// state shape (must match the converter: 1B = 16/8/64). `options` selects the compute unit.
    public init(
        assetURL: URL,
        ropeCosURL: URL,
        ropeSinURL: URL,
        nLayers: Int,
        nKV: Int,
        headDim: Int,
        maxSeq: Int = 512,
        negInfinity: Float = -1e4,
        options: SpecializationOptions = .default
    ) async throws {
        self.maxSeq = maxSeq
        self.headDim = headDim
        self.nLayers = nLayers
        self.nKV = nKV
        self.neg = negInfinity
        do {
            let loaded = try await AIModel(contentsOf: assetURL, options: options)
            guard let name = loaded.functionNames.first,
                  let fn = try loaded.loadFunction(named: name) else {
                throw DecodeError.modelLoad("no inference function in \(assetURL.lastPathComponent)")
            }
            self.model = loaded
            self.function = fn
        } catch let error as DecodeError {
            throw error
        } catch {
            throw DecodeError.modelLoad("\(error)")
        }
        self.cosTable = try Self.loadTable(ropeCosURL, count: maxSeq * headDim)
        self.sinTable = try Self.loadTable(ropeSinURL, count: maxSeq * headDim)
        self.kvShape = [2 * nLayers, 1, nKV, maxSeq, headDim]
        self.kvCount = kvShape.reduce(1, *)
        self.kv = NDArray(scalars: [Float](repeating: 0, count: kvCount), shape: kvShape)
    }

    private static func loadTable(_ url: URL, count: Int) throws -> [Float] {
        guard let data = try? Data(contentsOf: url), data.count == count * MemoryLayout<Float>.size else {
            throw DecodeError.ropeTable(
                "expected \(count) f32 at \(url.lastPathComponent), got \(((try? Data(contentsOf: url))?.count ?? -1)) bytes")
        }
        return data.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
    }

    // MARK: - One forward (writes K/V at `pos` via the fused state, returns argmax of next-token logits)

    /// Feed `token` at absolute position `pos`: the model writes the token's K/V into KV slot `pos`
    /// (one-hot) and returns the argmax over the output logits (the prediction of the NEXT token).
    @discardableResult
    public func step(token: Int, pos: Int) async throws -> Int {
        guard pos < maxSeq else { throw DecodeError.windowOverflow(pos: pos, maxSeq: maxSeq) }
        let base = pos * headDim
        let inputID = NDArray(scalars: [Int32(token)], shape: [1, 1])
        let cos = NDArray(scalars: Array(cosTable[base..<base + headDim]), shape: [headDim])
        let sin = NDArray(scalars: Array(sinTable[base..<base + headDim]), shape: [headDim])
        var onehot = [Float](repeating: 0, count: maxSeq)
        onehot[pos] = 1
        var bias = [Float](repeating: neg, count: maxSeq)
        for j in 0...pos { bias[j] = 0 }
        let inputs: [String: NDArray] = [
            "input_id": inputID, "rope_cos": cos, "rope_sin": sin,
            "write_onehot": NDArray(scalars: onehot, shape: [maxSeq]),
            "attn_bias": NDArray(scalars: bias, shape: [maxSeq]),
        ]
        // The fused KV `state` is passed as `inout` so its exclusive access spans BOTH the
        // MutableViews.insert AND the consuming async `run`. Borrowing the class stored property
        // `self.kv` directly into a `~Escapable MutableViews` fails ("escapes its scope") because a
        // stored-property access ends per-statement; an inout parameter's access covers the whole call.
        return try await runForward(inputs: inputs, kv: &kv)
    }

    /// Build the one-state `MutableViews` and run one forward, returning the argmax of `logits`.
    private func runForward(inputs: [String: NDArray], kv: inout NDArray) async throws -> Int {
        var states = InferenceFunction.MutableViews()
        states.insert(&kv, for: "kv")   // ONE fused state; mutated in place by run
        var outputs: InferenceFunction.Outputs
        do {
            outputs = try await function.run(inputs: inputs, states: states)
        } catch {
            throw DecodeError.predict("\(error)")
        }
        guard let value = outputs.remove("logits"), let logits = value.ndArray else {
            throw DecodeError.noLogits
        }
        return Self.argmax(logits)
    }

    private static func argmax(_ a: NDArray) -> Int {
        let count = a.shape.reduce(1, *)
        var best = 0
        var bestV = -Float.greatestFiniteMagnitude
        a.view(as: Float.self).withUnsafePointer { pointer, _, _ in
            var i = 0
            while i < count {
                if pointer[i] > bestV { bestV = pointer[i]; best = i }
                i += 1
            }
        }
        return best
    }

    // MARK: - Primitives the decoder composes (mirror BASCoreMLDraftSession)

    /// Fresh KV + frontier for a new generation (reuse the loaded model without reloading).
    public func reset() {
        self.kv = NDArray(scalars: [Float](repeating: 0, count: kvCount), shape: kvShape)
        draftPos = 0
    }

    /// Sync the KV to a committed prefix: feed each token at its position. Sets `draftPos = tokens.count`.
    public func prefill(_ tokens: [Int]) async throws {
        guard tokens.count <= maxSeq else { throw DecodeError.windowOverflow(pos: tokens.count, maxSeq: maxSeq) }
        for (i, t) in tokens.enumerated() { _ = try await step(token: t, pos: i) }
        draftPos = tokens.count
    }

    /// Propose K continuation tokens from the committed frontier (K+1 forwards so every proposal's
    /// K/V is written at its slot). Does NOT advance `draftPos`. Returns `[d_0 … d_{K-1}]`.
    public func propose(seed: Int, k: Int) async throws -> [Int] {
        guard k > 0 else { return [] }
        guard draftPos - 1 + k < maxSeq else { throw DecodeError.windowOverflow(pos: draftPos - 1 + k, maxSeq: maxSeq) }
        var proposals: [Int] = []
        var input = seed
        var pos = draftPos - 1
        for i in 0...k {
            let out = try await step(token: input, pos: pos)
            if i < k { proposals.append(out) }
            input = out
            pos += 1
        }
        return proposals
    }

    /// Commit the accepted prefix length `acc` plus the target's `correction` token. Advances `draftPos`.
    public func commit(acc: Int, correction: Int) async throws {
        let cPos = draftPos + acc
        guard cPos < maxSeq else { throw DecodeError.windowOverflow(pos: cPos, maxSeq: maxSeq) }
        _ = try await step(token: correction, pos: cPos)
        draftPos += acc + 1
    }

    public func remainingWindow() -> Int { maxSeq - draftPos }
    public var maxSeqCount: Int { maxSeq }
}

#endif
