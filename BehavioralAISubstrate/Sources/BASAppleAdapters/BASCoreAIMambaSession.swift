// MARK: - BASCoreAIMambaSession
//
// Stateful **Mamba-2 (SSD)** decode on iOS-27 CoreAI — the recurrent-state sibling of the transformer
// `BASCoreAIDecodeSession`. Drives a Llamba-1B-style discrete-Mamba-2 `.aimodel` (16 layers, Llama-3
// tokenizer, distilled from Llama-3.1-8B → a valid spec-decode DRAFT for a Llama-3.2-3B target).
//
// Why Mamba-2 fits the ANE decode lane better than a transformer (Track E): O(1) work per token, a
// FIXED-size recurrent state (no KV growth, no MAX_SEQ window), and NO softmax-over-history (the exact
// op the B-track showed the planner routes off-ANE). The decode step needs NO RoPE tables, NO write_onehot,
// NO attn_bias — just the token id and the persistent states.
//
// State = TWO fused buffers (the per-layer conv/ssm states are different shapes, so they can't fuse into
// one rectangular buffer like the homogeneous transformer KV; but 2 ≪ 32, so two `MutableViews.insert`s
// via a 2-inout helper is fine — a class stored property alone "escapes its scope", an inout parameter's
// access spans insert+run):
//   conv_all  fp16 [n_layer, conv_dim, d_conv]   (the short causal-conv rolling window, newest token last)
//   ssm_all   fp16 [n_layer, n_heads, d_head, d_state]   (the SSM hidden state)
// Both are mutated in place by `run`. Inputs/states/logits are fp16 (the device artifact is fp16-compute).
//
// `@unchecked Sendable`: single serialized executor. `#if canImport(CoreAI)` + iOS/macOS 27.

import Foundation

#if canImport(CoreAI)
import CoreAI

@available(iOS 27, macOS 27, *)
public final class BASCoreAIMambaSession: @unchecked Sendable {

    public enum DecodeError: Error {
        case modelLoad(String)
        case predict(String)
        case noLogits
        case badStates(String)
    }

    private let model: AIModel
    private let function: InferenceFunction
    private let convName: String
    private let ssmName: String
    private var convAll: NDArray
    #if DEBUG
    // audit x-concurrency §三① — enforces the `@unchecked Sendable` single-serialized-driver
    // contract at runtime (DEBUG only): a concurrent driver corrupts the in-place state.
    // Zero-cost in release; the utility is unit-tested in BASSingleDriverTripwireTests.
    private let driverTripwire = BASSingleDriverTripwire(label: "BASCoreAIMambaSession")
    #endif
    private var ssmAll: NDArray
    private let convShape: [Int]
    private let ssmShape: [Int]
    private let convCount: Int
    private let ssmCount: Int

    /// Tokens decoded so far (Mamba has no positional window — this is just a counter).
    public private(set) var pos: Int = 0

    /// `convShape`/`ssmShape` are the fused-state shapes (e.g. [16,6144,4] and [16,32,64,64]). The state
    /// NAMES are read from the function descriptor and matched by substring ("conv"/else), so exact naming
    /// can't silently misbind.
    public init(
        assetURL: URL,
        convShape: [Int],
        ssmShape: [Int],
        options: SpecializationOptions = .default
    ) async throws {
        self.convShape = convShape
        self.ssmShape = ssmShape
        self.convCount = convShape.reduce(1, *)
        self.ssmCount = ssmShape.reduce(1, *)
        let loaded: AIModel
        do {
            loaded = try await AIModel(contentsOf: assetURL, options: options)
        } catch {
            throw DecodeError.modelLoad("\(assetURL.lastPathComponent): \(error)")
        }
        guard let fname = loaded.functionNames.first, let fn = try loaded.loadFunction(named: fname) else {
            throw DecodeError.modelLoad("no function in \(assetURL.lastPathComponent)")
        }
        self.model = loaded
        self.function = fn
        let names = fn.descriptor.stateNames
        guard names.count == 2 else {
            throw DecodeError.badStates("expected 2 states (conv,ssm), got \(names)")
        }
        let conv = names.first(where: { $0.lowercased().contains("conv") }) ?? names[0]
        self.convName = conv
        self.ssmName = names.first(where: { $0 != conv }) ?? names[1]
        self.convAll = NDArray(scalars: [Float16](repeating: 0, count: convCount), shape: convShape)
        self.ssmAll = NDArray(scalars: [Float16](repeating: 0, count: ssmCount), shape: ssmShape)
    }

    /// One decode step: feed `token`, advance both recurrent states, return the argmax of the logits.
    @discardableResult
    public func step(token: Int) async throws -> Int {
        #if DEBUG
        driverTripwire.enter()   // audit x-concurrency §三①
        defer { driverTripwire.exit() }
        #endif
        let inputID = NDArray(scalars: [Int32(token)], shape: [1, 1])
        return try await runStep(inputID: inputID, conv: &convAll, ssm: &ssmAll)
    }

    /// Both fused states are `inout` so their exclusive access spans the two inserts + the consuming run.
    private func runStep(inputID: NDArray, conv: inout NDArray, ssm: inout NDArray) async throws -> Int {
        var states = InferenceFunction.MutableViews()
        states.insert(&conv, for: convName)
        states.insert(&ssm, for: ssmName)
        var outputs: InferenceFunction.Outputs
        do {
            outputs = try await function.run(inputs: ["input_id": inputID], states: states)
        } catch {
            throw DecodeError.predict("\(error)")
        }
        guard let value = outputs.remove("logits"), let logits = value.ndArray else {
            throw DecodeError.noLogits
        }
        pos += 1
        return Self.argmaxF16(logits)
    }

    private static func argmaxF16(_ a: NDArray) -> Int {
        let count = a.shape.reduce(1, *)
        var best = 0
        var bestV = -Float.greatestFiniteMagnitude
        a.view(as: Float16.self).withUnsafePointer { pointer, _, _ in   // logits fp16
            var k = 0
            while k < count {
                let v = Float(pointer[k])
                if v > bestV { bestV = v; best = k }
                k += 1
            }
        }
        return best
    }

    /// Fresh recurrent state for a new generation (Mamba has no KV/window to clear — just zero the states).
    public func reset() {
        convAll = NDArray(scalars: [Float16](repeating: 0, count: convCount), shape: convShape)
        ssmAll = NDArray(scalars: [Float16](repeating: 0, count: ssmCount), shape: ssmShape)
        pos = 0
    }

    // MARK: - Spec-decode state snapshot/restore (partial-accept rewind)
    //
    // A recurrent state can't "keep" only the accepted writes the way a position-addressed KV cache can (each
    // step advances the single fused state), so a speculator that proposes K tokens and gets only `acc` accepted
    // must REWIND: snapshot the frontier before proposing, then on commit restore + replay [seed, accepted…].
    // This is the exact pattern the Q4 host harness proved (Tools/llamba_q4_acceptance.py). The clone is DEEP
    // (read every Float16 scalar into a fresh NDArray) — a shallow `=` could alias the live state and silently
    // collapse acceptance to ~0 (the BASCoreMLDraftDecoder silent-corruption trap), so we never trust `=`.

    public struct Snapshot: @unchecked Sendable {
        fileprivate let conv: NDArray
        fileprivate let ssm: NDArray
    }

    /// Deep copy of both fused recurrent states at the current frontier.
    public func snapshot() -> Snapshot {
        Snapshot(conv: Self.cloneF16(convAll, count: convCount, shape: convShape),
                 ssm: Self.cloneF16(ssmAll, count: ssmCount, shape: ssmShape))
    }

    /// Restore both states from a snapshot (fresh deep copies — the snapshot stays pristine for reuse).
    public func restore(_ s: Snapshot) {
        convAll = Self.cloneF16(s.conv, count: convCount, shape: convShape)
        ssmAll = Self.cloneF16(s.ssm, count: ssmCount, shape: ssmShape)
    }

    private static func cloneF16(_ a: NDArray, count: Int, shape: [Int]) -> NDArray {
        var scalars = [Float16](repeating: 0, count: count)
        a.view(as: Float16.self).withUnsafePointer { pointer, _, _ in
            var i = 0
            while i < count { scalars[i] = pointer[i]; i += 1 }
        }
        return NDArray(scalars: scalars, shape: shape)
    }
}

#endif
