// MARK: - BASCoreAIMamba3Session
//
// Stateful **Mamba-3** decode on iOS-27 CoreAI — the upgrade sibling of `BASCoreAIMambaSession` (Mamba-2/SSD).
// Mamba-3 (arXiv 2603.15569, ICLR 2026) generalizes Mamba-2 with: (1) trapezoidal 2nd-order discretization →
// a 3-term recurrence (which subsumes & REMOVES the short conv1d); (2) complex-valued state realized as REAL
// 2×2 rotation blocks + data-dependent RoPE (no complex dtype/exp/phase at runtime); (3) MIMO rank-R (raises
// arithmetic intensity at fixed decode latency — state bytes/step unchanged). All of it lowers to the same
// real primitives the Mamba-2 path already proved on the A19 ANE (host convertibility GREEN, L=16 int8 = 1.04 GB).
//
// State = TWO PROPERLY-SHAPED buffers (the Mamba-2 pattern the A19 ANE proved):
//   ssm_all   fp16 [L, H, P, N]    the SSM hidden state H_t
//   angle_all fp16 [L, H, N//2]    cumulative data-dependent RoPE angle
// WHY exactly two, properly-shaped: device bisection showed the on-device segmenter SIGSEGVs both alternatives —
// (a) >2 properly-shaped states reorder token-OUTPUTS vs handle-INPUTS ("order of token outputs does not match
// order of handle inputs" → CPU error, ANE SIGSEGV); (b) a single FLAT fused state [L,S] crashes the ANE compiler
// on its slice/reshape (even a Mamba-2-style op body). Two properly-shaped states is the landed Llamba Mamba-2
// pattern that compiles + runs on ANE. To stay at two we set λ=1 (Euler) and drop the trapezoidal 1-step delay
// state — that removes only a delay buffer + two muls (no new op-type), so the marquee Mamba-3 ops (data-dependent
// RoPE rotation + MIMO rank-R einsums) are exercised faithfully. fp16 throughout (the device artifact is fp16).
//
// Decode-SPEED probe driver (no spec-decode snapshot/restore — Saguaro is declined; this measures the standalone
// Mamba-3 ANE lane: tok/s, peak MB, and whether the rank-R MIMO matmul lowers to efficient ANE MACs).
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
    private let ssmName: String
    private let angleName: String
    private var ssmAll: NDArray
    private var angleAll: NDArray
    private let ssmShape: [Int]
    private let angleShape: [Int]
    private let ssmCount: Int
    private let angleCount: Int

    /// Tokens decoded so far (Mamba has no positional window — just a counter).
    public private(set) var pos: Int = 0

    /// `ssmShape`/`angleShape` are the two properly-shaped state shapes, e.g. [16,32,64,64] and [16,32,32]. The
    /// state NAMES are read from the descriptor and matched by substring (ssm / angle).
    public init(
        assetURL: URL,
        ssmShape: [Int],
        angleShape: [Int],
        options: SpecializationOptions = .default
    ) async throws {
        self.ssmShape = ssmShape
        self.angleShape = angleShape
        self.ssmCount = ssmShape.reduce(1, *)
        self.angleCount = angleShape.reduce(1, *)
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
        guard descNames.count == 2 else {
            throw DecodeError.badStates("expected 2 states (ssm, angle), got \(descNames)")
        }
        let angle = descNames.first(where: { $0.lowercased().contains("angle") }) ?? descNames[1]
        self.angleName = angle
        self.ssmName = descNames.first(where: { $0 != angle }) ?? descNames[0]
        self.ssmAll = NDArray(scalars: [Float16](repeating: 0, count: ssmCount), shape: ssmShape)
        self.angleAll = NDArray(scalars: [Float16](repeating: 0, count: angleCount), shape: angleShape)
    }

    /// One decode step: feed `token`, advance both recurrent states, return the argmax of the logits.
    @discardableResult
    public func step(token: Int) async throws -> Int {
        let inputID = NDArray(scalars: [Int32(token)], shape: [1, 1])
        return try await runStep(inputID: inputID, ssm: &ssmAll, angle: &angleAll)
    }

    /// Both states are `inout` so their exclusive access spans the inserts + the consuming run.
    private func runStep(inputID: NDArray, ssm: inout NDArray, angle: inout NDArray) async throws -> Int {
        var states = InferenceFunction.MutableViews()
        states.insert(&ssm, for: ssmName)
        states.insert(&angle, for: angleName)
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
        ssmAll = NDArray(scalars: [Float16](repeating: 0, count: ssmCount), shape: ssmShape)
        angleAll = NDArray(scalars: [Float16](repeating: 0, count: angleCount), shape: angleShape)
        pos = 0
    }
}

#endif
