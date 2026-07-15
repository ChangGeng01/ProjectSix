// MARK: - BASCoreAIMamba3DualSession
//
// The "Asymmetric Duo" target driver: ONE Mamba-3 CoreAI asset exposing TWO functions sharing the SAME fused
// state (angle/ssm) —
//   decode  [1,1]  — recurrent-mode single-token generation (what the standalone lane uses).
//   verify  [1,K]  — multi-token "conv-mode" verification (K draft tokens in one call → K logits), the verifier
//                    half of spec-decode where Mamba-3 is the TARGET (rewind-free: the target only forward-scans).
// Both functions are loaded from the same AIModel and bound to the SAME state NDArrays, so switching modes is a
// function dispatch on an already-resident asset — no recompile, no weight reload, no cross-engine state copy.
//
// This is a PROBE driver to measure, on the A19 ANE: (1) does the [1,K] conv-verify graph compile + run at all?
// (2) verify[1,K] vs decode[1,1] latency; (3) the decode↔verify switch overhead. Random-weight asset → compile +
// speed only. `@unchecked Sendable`; `#if canImport(CoreAI)` + iOS/macOS 27.

import Foundation

#if canImport(CoreAI)
import CoreAI

@available(iOS 27, macOS 27, *)
public final class BASCoreAIMamba3DualSession: @unchecked Sendable {

    public enum DecodeError: Error {
        case modelLoad(String)
        case predict(String)
        case noLogits
        case badStates(String)
    }

    private let model: AIModel
    private let decodeFn: InferenceFunction
    private let verifyFn: InferenceFunction
    private let angleName: String
    private let ssmName: String
    private var angle: NDArray
    private var ssm: NDArray
    #if DEBUG
    // audit x-concurrency §三① — enforces the `@unchecked Sendable` single-serialized-driver
    // contract at runtime (DEBUG only): a concurrent driver corrupts the in-place state.
    // Zero-cost in release; the utility is unit-tested in BASSingleDriverTripwireTests.
    private let driverTripwire = BASSingleDriverTripwire(label: "BASCoreAIMamba3DualSession")
    #endif
    private let angleShape: [Int]
    private let ssmShape: [Int]
    private let vocab: Int
    private let k: Int

    public private(set) var pos: Int = 0

    public init(
        assetURL: URL,
        angleShape: [Int],
        ssmShape: [Int],
        vocab: Int,
        k: Int,
        options: SpecializationOptions = .default
    ) async throws {
        self.angleShape = angleShape
        self.ssmShape = ssmShape
        self.vocab = vocab
        self.k = k
        let loaded: AIModel
        do {
            loaded = try await AIModel(contentsOf: assetURL, options: options)
        } catch {
            throw DecodeError.modelLoad("\(assetURL.lastPathComponent): \(error)")
        }
        self.model = loaded
        let names = loaded.functionNames
        guard names.contains("decode"), names.contains("verify"),
              let d = try loaded.loadFunction(named: "decode"),
              let v = try loaded.loadFunction(named: "verify") else {
            throw DecodeError.modelLoad("need functions [decode, verify], got \(names)")
        }
        self.decodeFn = d
        self.verifyFn = v
        // Both functions declare the same 2 states; match by substring (names may carry a "c." prefix).
        let sn = d.descriptor.stateNames
        guard sn.count == 2 else { throw DecodeError.badStates("decode expects 2 states, got \(sn)") }
        guard let a = sn.first(where: { $0.lowercased().contains("angle") }),
              let s = sn.first(where: { $0.lowercased().contains("ssm") }) else {
            throw DecodeError.badStates("can't find angle/ssm in \(sn)")
        }
        self.angleName = a
        self.ssmName = s
        self.angle = NDArray(scalars: [Float16](repeating: 0, count: angleShape.reduce(1, *)), shape: angleShape)
        self.ssm = NDArray(scalars: [Float16](repeating: 0, count: ssmShape.reduce(1, *)), shape: ssmShape)
    }

    /// Recurrent single-token decode (mode 1).
    @discardableResult
    public func decodeStep(token: Int) async throws -> Int {
        #if DEBUG
        driverTripwire.enter()   // audit x-concurrency §三①
        defer { driverTripwire.exit() }
        #endif
        let inputID = NDArray(scalars: [Int32(token)], shape: [1, 1])
        return try await runDecode(inputID: inputID, a: &angle, s: &ssm)
    }

    /// Conv-mode verify of K draft tokens (mode 2) → the K argmax tokens. Advances state over all K.
    public func verifyChunk(tokens: [Int]) async throws -> [Int] {
        precondition(tokens.count == k, "verify expects exactly K=\(k) tokens")
        let ids = NDArray(scalars: tokens.map { Int32($0) }, shape: [1, k])
        return try await runVerify(inputIDs: ids, a: &angle, s: &ssm)
    }

    private func runDecode(inputID: NDArray, a: inout NDArray, s: inout NDArray) async throws -> Int {
        var views = InferenceFunction.MutableViews()
        views.insert(&a, for: angleName)
        views.insert(&s, for: ssmName)
        var outputs: InferenceFunction.Outputs
        do {
            outputs = try await decodeFn.run(inputs: ["input_id": inputID], states: views)
        } catch {
            throw DecodeError.predict("decode: \(error)")
        }
        guard let v = outputs.remove("logits"), let logits = v.ndArray else { throw DecodeError.noLogits }
        pos += 1
        return Self.argmaxRow(logits, row: 0, vocab: vocab)
    }

    private func runVerify(inputIDs: NDArray, a: inout NDArray, s: inout NDArray) async throws -> [Int] {
        var views = InferenceFunction.MutableViews()
        views.insert(&a, for: angleName)
        views.insert(&s, for: ssmName)
        var outputs: InferenceFunction.Outputs
        do {
            outputs = try await verifyFn.run(inputs: ["input_ids": inputIDs], states: views)
        } catch {
            throw DecodeError.predict("verify: \(error)")
        }
        guard let v = outputs.remove("logits"), let logits = v.ndArray else { throw DecodeError.noLogits }
        pos += k
        return (0..<k).map { Self.argmaxRow(logits, row: $0, vocab: vocab) }
    }

    /// Argmax over `vocab` of row `row` in a [rows, vocab] fp16 logits buffer.
    private static func argmaxRow(_ logitsND: NDArray, row: Int, vocab: Int) -> Int {
        var best = 0
        var bestV = -Float.greatestFiniteMagnitude
        logitsND.view(as: Float16.self).withUnsafePointer { pointer, _, _ in
            let base = row * vocab
            var j = 0
            while j < vocab {
                let val = Float(pointer[base + j])
                if val > bestV { bestV = val; best = j }
                j += 1
            }
        }
        return best
    }

    public func reset() {
        angle = NDArray(scalars: [Float16](repeating: 0, count: angleShape.reduce(1, *)), shape: angleShape)
        ssm = NDArray(scalars: [Float16](repeating: 0, count: ssmShape.reduce(1, *)), shape: ssmShape)
        pos = 0
    }
}

#endif
