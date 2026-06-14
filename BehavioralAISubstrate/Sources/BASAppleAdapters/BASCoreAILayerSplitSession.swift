// MARK: - BASCoreAILayerSplitSession
//
// LAYER-SPLIT stateful CoreAI decode: drives the Llama-3.2-1B as N separate `.aimodel` chunks (default 8+8)
// so each asset stays under the A19 CoreAI-0.4.0 ANE per-asset LAYER-COUNT compile ceiling (~12–15 layers; the
// monolithic 16-layer asset SIGABRTs, but ≤12-layer assets compile + decode on the ANE — Track E audit). Chained,
// the chunks are token-identical to the monolith (24/24 vs HF greedy, host-verified).
//
// Per step the residual stream is piped chunk0 → chunk1 → … → chunkLast, each chunk owning its OWN fused KV state:
//   chunk0:    input_id(int32) + rope/onehot/bias(fp16) + state kv(fp16) → hidden(fp32)
//   middle:    hidden(fp32)    + rope/onehot/bias(fp16) + state kv(fp16) → hidden(fp32)
//   last:      hidden(fp32)    + rope/onehot/bias(fp16) + state kv(fp16) → logits(fp32)
//
// The hidden hand-off + logits are **fp32**: an all-fp16 split is 0/24 — the layer-boundary residual carries
// outlier activations that fp16-rounding flips (the monolith never materializes that boundary tensor). Weights,
// matmuls, RoPE/onehot/bias inputs, and the KV state stay fp16.
//
// `@unchecked Sendable`: driven only on a single serialized executor (sequential chunk runs; `&kvs[i]` is one
// exclusive access at a time — never concurrent). `#if canImport(CoreAI)` + iOS/macOS 27.

import Foundation

#if canImport(CoreAI)
import CoreAI

@available(iOS 27, macOS 27, *)
public final class BASCoreAILayerSplitSession: @unchecked Sendable {

    public enum DecodeError: Error {
        case modelLoad(String)
        case ropeTable(String)
        case windowOverflow(pos: Int, maxSeq: Int)
        case predict(String)
        case noOutput(String)
        case badConfig(String)
    }

    private let models: [AIModel]              // retain the loaded models
    private let functions: [InferenceFunction]
    private let outputNames: [String]          // "hidden" for non-last chunks, "logits" for the last
    private var kvs: [NDArray]                  // one fused KV per chunk (fp16)
    private let maxSeq: Int
    private let headDim: Int
    private let neg: Float
    private let cosTable: [Float]
    private let sinTable: [Float]
    private let kvShapes: [[Int]]
    private let kvCounts: [Int]

    public private(set) var draftPos: Int = 0

    /// `chunkAssetURLs` / `chunkLayers` are parallel arrays (the per-chunk `.aimodel` and its layer count, in order).
    public init(
        chunkAssetURLs: [URL],
        chunkLayers: [Int],
        ropeCosURL: URL,
        ropeSinURL: URL,
        nKV: Int,
        headDim: Int,
        maxSeq: Int = 512,
        negInfinity: Float = -1e4,
        options: SpecializationOptions = .default
    ) async throws {
        guard chunkAssetURLs.count == chunkLayers.count, !chunkAssetURLs.isEmpty else {
            throw DecodeError.badConfig("chunkAssetURLs/chunkLayers mismatch or empty")
        }
        self.maxSeq = maxSeq
        self.headDim = headDim
        self.neg = negInfinity

        var loadedModels: [AIModel] = []
        var loadedFns: [InferenceFunction] = []
        var names: [String] = []
        var shapes: [[Int]] = []
        var counts: [Int] = []
        var states: [NDArray] = []
        for (i, url) in chunkAssetURLs.enumerated() {
            print("📊 split-init: chunk \(i) AIModel.load \(url.lastPathComponent)…"); fflush(stdout)
            do {
                let m = try await AIModel(contentsOf: url, options: options)
                print("📊 split-init: chunk \(i) loaded; loadFunction…"); fflush(stdout)
                guard let fname = m.functionNames.first, let fn = try m.loadFunction(named: fname) else {
                    throw DecodeError.modelLoad("no function in \(url.lastPathComponent)")
                }
                print("📊 split-init: chunk \(i) function=\(fname) ready"); fflush(stdout)
                loadedModels.append(m)
                loadedFns.append(fn)
            } catch let e as DecodeError {
                throw e
            } catch {
                throw DecodeError.modelLoad("\(url.lastPathComponent): \(error)")
            }
            names.append(i == chunkAssetURLs.count - 1 ? "logits" : "hidden")
            let shape = [2 * chunkLayers[i], 1, nKV, maxSeq, headDim]
            shapes.append(shape)
            let count = shape.reduce(1, *)
            counts.append(count)
            states.append(NDArray(scalars: [Float16](repeating: 0, count: count), shape: shape))
        }
        self.models = loadedModels
        self.functions = loadedFns
        self.outputNames = names
        self.kvShapes = shapes
        self.kvCounts = counts
        self.kvs = states
        self.cosTable = try Self.loadTable(ropeCosURL, count: maxSeq * headDim)
        self.sinTable = try Self.loadTable(ropeSinURL, count: maxSeq * headDim)
    }

    private static func loadTable(_ url: URL, count: Int) throws -> [Float] {
        guard let data = try? Data(contentsOf: url), data.count == count * MemoryLayout<Float>.size else {
            throw DecodeError.ropeTable("expected \(count) f32 at \(url.lastPathComponent)")
        }
        return data.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
    }

    /// One decode step across all chunks. fp16 rope/onehot/bias are built once and shared; the fp32 hidden is
    /// piped chunk→chunk; the last chunk yields fp32 logits → argmax.
    @discardableResult
    public func step(token: Int, pos: Int) async throws -> Int {
        guard pos < maxSeq else { throw DecodeError.windowOverflow(pos: pos, maxSeq: maxSeq) }
        let base = pos * headDim
        let cos = NDArray(scalars: cosTable[base..<base + headDim].map { Float16($0) }, shape: [headDim])
        let sin = NDArray(scalars: sinTable[base..<base + headDim].map { Float16($0) }, shape: [headDim])
        var onehot = [Float16](repeating: 0, count: maxSeq); onehot[pos] = 1
        var bias = [Float16](repeating: Float16(neg), count: maxSeq); for j in 0...pos { bias[j] = 0 }
        let onehotND = NDArray(scalars: onehot, shape: [maxSeq])
        let biasND = NDArray(scalars: bias, shape: [maxSeq])

        // chunk 0 takes the token id; produces the fp32 hidden residual.
        var carry = try await runChunk(
            0,
            inputs: ["input_id": NDArray(scalars: [Int32(token)], shape: [1, 1]),
                     "rope_cos": cos, "rope_sin": sin, "write_onehot": onehotND, "attn_bias": biasND],
            kv: &kvs[0])
        // middle + last chunks take the running hidden; the last yields logits.
        var i = 1
        while i < functions.count {
            carry = try await runChunk(
                i,
                inputs: ["hidden": carry, "rope_cos": cos, "rope_sin": sin,
                         "write_onehot": onehotND, "attn_bias": biasND],
                kv: &kvs[i])
            i += 1
        }
        return Self.argmaxF32(carry)   // last carry == fp32 logits
    }

    /// Insert the chunk's fused KV (inout — the access must span insert+run; a class stored property would
    /// "escape its scope") and run; return the chunk's declared output NDArray (hidden fp32, or logits fp32).
    private func runChunk(_ i: Int, inputs: [String: NDArray], kv: inout NDArray) async throws -> NDArray {
        var states = InferenceFunction.MutableViews()
        states.insert(&kv, for: "kv")
        var outputs: InferenceFunction.Outputs
        do {
            outputs = try await functions[i].run(inputs: inputs, states: states)
        } catch {
            throw DecodeError.predict("chunk \(i): \(error)")
        }
        guard let value = outputs.remove(outputNames[i]), let nd = value.ndArray else {
            throw DecodeError.noOutput("chunk \(i): \(outputNames[i])")
        }
        return nd
    }

    private static func argmaxF32(_ a: NDArray) -> Int {
        let count = a.shape.reduce(1, *)
        var best = 0
        var bestV = -Float.greatestFiniteMagnitude
        a.view(as: Float.self).withUnsafePointer { pointer, _, _ in   // logits are fp32
            var k = 0
            while k < count {
                if pointer[k] > bestV { bestV = pointer[k]; best = k }
                k += 1
            }
        }
        return best
    }

    // MARK: - Primitives (mirror BASCoreAIDecodeSession)

    public func reset() {
        for i in kvs.indices {
            kvs[i] = NDArray(scalars: [Float16](repeating: 0, count: kvCounts[i]), shape: kvShapes[i])
        }
        draftPos = 0
    }

    public func prefill(_ tokens: [Int]) async throws {
        guard tokens.count <= maxSeq else { throw DecodeError.windowOverflow(pos: tokens.count, maxSeq: maxSeq) }
        for (i, t) in tokens.enumerated() { _ = try await step(token: t, pos: i) }
        draftPos = tokens.count
    }

    public func remainingWindow() -> Int { maxSeq - draftPos }
    public var maxSeqCount: Int { maxSeq }
}

#endif
