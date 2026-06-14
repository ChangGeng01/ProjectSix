// MARK: - BASCoreAILayerSplitSession
//
// LAYER-SPLIT stateful CoreAI decode driving the Llama-3.2-1B as N entrypoint functions of ONE multi-function
// `.aimodel` (default stage0+stage1 = 8+8). The monolithic 16-layer graph SIGABRTs the A19 CoreAI-0.4.0 ANE
// compiler (per-asset LAYER-COUNT ceiling ~12–15; Track E audit), but each 8-layer FUNCTION compiles + decodes
// fine. Two SEPARATE assets is NOT an option — loading a 2nd `AIModel` into one process SIGSEGVs — so both chunks
// live in ONE asset: one `AIModel.load`, then `loadFunction("stage0")` + `loadFunction("stage1")`.
//
// Per step the residual stream is piped stage0 → stage1 → … → last, each function owning its OWN fused KV state
// (kv0, kv1, …):
//   stage0: input_id(int32) + rope/onehot/bias(fp16) + state kv0(fp16) → hidden(fp32)
//   middle: hidden(fp32)    + rope/onehot/bias(fp16) + state kvI(fp16) → hidden(fp32)
//   last:   hidden(fp32)    + rope/onehot/bias(fp16) + state kvN(fp16) → logits(fp32)
//
// The hidden hand-off + logits are **fp32**: an all-fp16 split is 0/24 — the layer-boundary residual carries
// outlier activations that fp16-rounding flips. Weights, RoPE/onehot/bias inputs, and the KV state stay fp16.
//
// `@unchecked Sendable`: single serialized executor (sequential function runs; `&kvs[i]` is one exclusive access
// at a time). `#if canImport(CoreAI)` + iOS/macOS 27.

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

    private let model: AIModel                  // ONE multi-function asset
    private let functions: [InferenceFunction]  // stage0, stage1, … in order
    private let stateNames: [String]            // each function's KV state name ("kv0", "kv1", …)
    private let outputNames: [String]           // "hidden" for non-last, "logits" for the last
    private var kvs: [NDArray]                   // one fused KV per function (fp16)
    private let maxSeq: Int
    private let headDim: Int
    private let neg: Float
    private let cosTable: [Float]
    private let sinTable: [Float]
    private let kvShapes: [[Int]]
    private let kvCounts: [Int]

    public private(set) var draftPos: Int = 0

    /// `chunkLayers` is the per-function layer count, in order (e.g. [8, 8]); it sizes each KV state.
    public init(
        assetURL: URL,
        chunkLayers: [Int],
        ropeCosURL: URL,
        ropeSinURL: URL,
        nKV: Int,
        headDim: Int,
        maxSeq: Int = 512,
        negInfinity: Float = -1e4,
        options: SpecializationOptions = .default
    ) async throws {
        guard !chunkLayers.isEmpty else { throw DecodeError.badConfig("empty chunkLayers") }
        self.maxSeq = maxSeq
        self.headDim = headDim
        self.neg = negInfinity

        let loaded: AIModel
        do {
            loaded = try await AIModel(contentsOf: assetURL, options: options)
        } catch {
            throw DecodeError.modelLoad("\(assetURL.lastPathComponent): \(error)")
        }
        self.model = loaded

        var fns: [InferenceFunction] = []
        var snames: [String] = []
        var onames: [String] = []
        var shapes: [[Int]] = []
        var counts: [Int] = []
        var states: [NDArray] = []
        for i in 0..<chunkLayers.count {
            let fname = "stage\(i)"
            guard let fn = try loaded.loadFunction(named: fname) else {
                throw DecodeError.modelLoad("no function \(fname) in \(assetURL.lastPathComponent)")
            }
            fns.append(fn)
            snames.append(fn.descriptor.stateNames.first ?? "kv\(i)")
            onames.append(fn.descriptor.outputNames.first ?? (i == chunkLayers.count - 1 ? "logits" : "hidden"))
            let shape = [2 * chunkLayers[i], 1, nKV, maxSeq, headDim]
            shapes.append(shape)
            let count = shape.reduce(1, *)
            counts.append(count)
            states.append(NDArray(scalars: [Float16](repeating: 0, count: count), shape: shape))
        }
        self.functions = fns
        self.stateNames = snames
        self.outputNames = onames
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

    /// One decode step across all functions. fp16 rope/onehot/bias built once and shared; the fp32 hidden is
    /// piped function→function; the last function yields fp32 logits → argmax.
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

        // stage0 takes the token id; produces the fp32 hidden residual.
        var carry = try await runStage(
            0,
            inputs: ["input_id": NDArray(scalars: [Int32(token)], shape: [1, 1]),
                     "rope_cos": cos, "rope_sin": sin, "write_onehot": onehotND, "attn_bias": biasND],
            kv: &kvs[0])
        var i = 1
        while i < functions.count {
            carry = try await runStage(
                i,
                inputs: ["hidden": carry, "rope_cos": cos, "rope_sin": sin,
                         "write_onehot": onehotND, "attn_bias": biasND],
                kv: &kvs[i])
            i += 1
        }
        return Self.argmaxF32(carry)   // last carry == fp32 logits
    }

    private func runStage(_ i: Int, inputs: [String: NDArray], kv: inout NDArray) async throws -> NDArray {
        var states = InferenceFunction.MutableViews()
        states.insert(&kv, for: stateNames[i])
        var outputs: InferenceFunction.Outputs
        do {
            outputs = try await functions[i].run(inputs: inputs, states: states)
        } catch {
            throw DecodeError.predict("stage \(i): \(error)")
        }
        guard let value = outputs.remove(outputNames[i]), let nd = value.ndArray else {
            throw DecodeError.noOutput("stage \(i): \(outputNames[i])")
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
