// MARK: - BASCoreAIMamba3Session
//
// Stateful **Mamba-3** decode probe driver on iOS-27 CoreAI — the upgrade sibling of `BASCoreAIMambaSession`
// (Mamba-2/SSD). Mamba-3 (arXiv 2603.15569, ICLR 2026) generalizes Mamba-2 with trapezoidal discretization, a
// complex-valued state realized as REAL 2×2 rotations + data-dependent RoPE, and MIMO rank-R — all lowering to
// the same real primitives the Mamba-2 path proved. DEVICE-CERTIFIED on the A19 ANE (commit 5abc1d62b): the
// FAITHFUL trapezoid (learned A, 3-term recurrence, rotated kprev/vprev delay, RoPE, MIMO) compiles + decodes —
// L=2 clean 100%-ANE at 160.6 tok/s; L=16 decodes at 51.8 tok/s (one segment exceeds the per-asset compile
// ceiling and falls back → fixed by asset-splitting).
//
// GENERIC over the carried state count (1–4): the ANE-crash bisection settled it — a single flat fused state
// [L,S] sliced per layer SIGSEGVs the ANE segmenter at load; SEPARATE properly-shaped states registered
// angle-FIRST run clean. The 2-state layout (angle,ssm) is the Mamba-2-equivalent Euler path; the 4-state
// layout (angle,ssm,kprev,vprev) is the CERTIFIED faithful-trapezoid path — the "4 states hit the segmenter
// ordering bug" fear did NOT recur. Rather than rebuild the app per layout, this session reads the descriptor's
// stateNames and binds an NDArray per state, with shapes supplied (in descriptor order).
// All states are mutated in place by `run`. fp16 throughout (the device artifact is fp16-compute). This is a
// decode-SPEED/COMPILE probe driver (no spec-decode snapshot/restore — Saguaro is declined).
// `@unchecked Sendable`: single serialized executor. `#if canImport(CoreAI)` + iOS/macOS 27.

import Foundation

#if canImport(CoreAI)
import CoreAI

@available(iOS 27, macOS 27, *)
public final class BASCoreAIMamba3Session: @unchecked Sendable {

    public enum DecodeError: Error {
        case modelLoad(String)
        case predict(String)
        case noLogits
        case badStates(String)
    }

    private let model: AIModel
    private let function: InferenceFunction
    private let names: [String]               // descriptor order (count 1–4)
    private let count: Int
    private var state0: NDArray
    private var state1: NDArray                // dummy [1] when not used
    private var state2: NDArray
    private var state3: NDArray
    private let shapes: [[Int]]

    /// Tokens decoded so far (Mamba has no positional window — just a counter).
    public private(set) var pos: Int = 0

    /// `stateShapes` are the carried-state shapes in the SAME order the converter declared them (its
    /// `buffers_to_mutate` / registration order), angle-FIRST — e.g. `[[16,148480]]` (flat, ANE-crashes),
    /// `[[16,32,32],[16,32,64,64]]` (2-state angle,ssm — Euler), or the CERTIFIED faithful-trapezoid layout
    /// `[[L,32,32],[L,32,64,64],[L,32,4,64],[L,32,64,4]]` (4-state angle,ssm,kprev,vprev). Supports 1–4 states —
    /// `MutableViews` is lifetime-dependent, so each state is bound through an explicit `inout` (a stored
    /// property inserted directly "escapes its scope"), hence the explicit runStep1/2/3/4 rather than a loop.
    public init(
        assetURL: URL,
        stateShapes: [[Int]],
        options: SpecializationOptions = .default
    ) async throws {
        self.shapes = stateShapes
        self.count = stateShapes.count
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
        let descNames = fn.descriptor.stateNames
        guard descNames.count == stateShapes.count, (1...4).contains(descNames.count) else {
            throw DecodeError.badStates("descriptor has \(descNames.count) states \(descNames); supported: 1–4 with matching shapes (\(stateShapes.count) supplied)")
        }
        self.names = descNames
        func zeroed(_ s: [Int]) -> NDArray {
            NDArray(scalars: [Float16](repeating: 0, count: s.reduce(1, *)), shape: s)
        }
        let dummy = NDArray(scalars: [Float16(0)], shape: [1])
        self.state0 = zeroed(stateShapes[0])
        self.state1 = stateShapes.count >= 2 ? zeroed(stateShapes[1]) : dummy
        self.state2 = stateShapes.count >= 3 ? zeroed(stateShapes[2]) : dummy
        self.state3 = stateShapes.count >= 4 ? zeroed(stateShapes[3]) : dummy
    }

    /// One decode step: feed `token`, advance the carried state(s), return the argmax of the logits.
    @discardableResult
    public func step(token: Int) async throws -> Int {
        let inputID = NDArray(scalars: [Int32(token)], shape: [1, 1])
        switch count {
        case 4: return try await runStep4(inputID: inputID, s0: &state0, s1: &state1, s2: &state2, s3: &state3)
        case 3: return try await runStep3(inputID: inputID, s0: &state0, s1: &state1, s2: &state2)
        case 2: return try await runStep2(inputID: inputID, s0: &state0, s1: &state1)
        default: return try await runStep1(inputID: inputID, s0: &state0)
        }
    }

    private func runStep1(inputID: NDArray, s0: inout NDArray) async throws -> Int {
        var views = InferenceFunction.MutableViews()
        views.insert(&s0, for: names[0])
        var outputs: InferenceFunction.Outputs
        do {
            outputs = try await function.run(inputs: ["input_id": inputID], states: views)
        } catch {
            throw DecodeError.predict("\(error)")
        }
        guard let value = outputs.remove("logits"), let logits = value.ndArray else { throw DecodeError.noLogits }
        pos += 1
        return Self.argmaxF16(logits)
    }

    private func runStep2(inputID: NDArray, s0: inout NDArray, s1: inout NDArray) async throws -> Int {
        var views = InferenceFunction.MutableViews()
        views.insert(&s0, for: names[0])
        views.insert(&s1, for: names[1])
        var outputs: InferenceFunction.Outputs
        do {
            outputs = try await function.run(inputs: ["input_id": inputID], states: views)
        } catch {
            throw DecodeError.predict("\(error)")
        }
        guard let value = outputs.remove("logits"), let logits = value.ndArray else { throw DecodeError.noLogits }
        pos += 1
        return Self.argmaxF16(logits)
    }

    private func runStep3(inputID: NDArray, s0: inout NDArray, s1: inout NDArray, s2: inout NDArray) async throws -> Int {
        var views = InferenceFunction.MutableViews()
        views.insert(&s0, for: names[0]); views.insert(&s1, for: names[1]); views.insert(&s2, for: names[2])
        var outputs: InferenceFunction.Outputs
        do {
            outputs = try await function.run(inputs: ["input_id": inputID], states: views)
        } catch {
            throw DecodeError.predict("\(error)")
        }
        guard let value = outputs.remove("logits"), let logits = value.ndArray else { throw DecodeError.noLogits }
        pos += 1
        return Self.argmaxF16(logits)
    }

    private func runStep4(inputID: NDArray, s0: inout NDArray, s1: inout NDArray, s2: inout NDArray, s3: inout NDArray) async throws -> Int {
        var views = InferenceFunction.MutableViews()
        views.insert(&s0, for: names[0]); views.insert(&s1, for: names[1])
        views.insert(&s2, for: names[2]); views.insert(&s3, for: names[3])
        var outputs: InferenceFunction.Outputs
        do {
            outputs = try await function.run(inputs: ["input_id": inputID], states: views)
        } catch {
            throw DecodeError.predict("\(error)")
        }
        guard let value = outputs.remove("logits"), let logits = value.ndArray else { throw DecodeError.noLogits }
        pos += 1
        return Self.argmaxF16(logits)
    }

    private static func argmaxF16(_ a: NDArray) -> Int {
        let count = a.shape.reduce(1, *)
        var best = 0
        var bestV = -Float.greatestFiniteMagnitude
        a.view(as: Float16.self).withUnsafePointer { pointer, _, _ in
            var k = 0
            while k < count {
                let v = Float(pointer[k])
                if v > bestV { bestV = v; best = k }
                k += 1
            }
        }
        return best
    }

    /// Fresh recurrent state for a new generation (Mamba has no KV/window — just zero the states).
    public func reset() {
        func zeroed(_ s: [Int]) -> NDArray {
            NDArray(scalars: [Float16](repeating: 0, count: s.reduce(1, *)), shape: s)
        }
        state0 = zeroed(shapes[0])
        if count >= 2 { state1 = zeroed(shapes[1]) }
        if count >= 3 { state2 = zeroed(shapes[2]) }
        if count >= 4 { state3 = zeroed(shapes[3]) }
        pos = 0
    }
}

#endif
