// MARK: - BASCoreAIHybridDecodeSession — DUET decode asset (STEP 6): 24L hybrid, 6 resident states
//
// The decode half: 20 Mamba angle-first 4-state (stacked angle_all/ssm_all/kprev_all/vprev_all) + 4 MLA fixed-buffer
// (mla_kv[n_mla,MAX_SEQ,128] + mla_fill[n_mla,1]) = SIX resident states, all mutated in place by `run`. Initialized from
// the prefill handoff (the State-Cache). fp16. Compute unit is the caller's options (24L > 8L ANE ceiling → GPU-backed).
//
// MutableViews is lifetime-dependent (Track G crash-bisection lesson) → each state is bound through an EXPLICIT inout on a
// STORED property (state0…state5), never an array subscript. State order MUST match the converter's declared stateNames.

import Foundation

#if canImport(CoreAI)
import CoreAI

@available(iOS 27, macOS 27, *)
public final class BASCoreAIHybridDecodeSession: @unchecked Sendable {
    public enum DecodeError: Error {
        case load(String)
        case noFunction
        case badStates(String)
        case run(String)
        case noLogits
    }

    private let model: AIModel
    private let function: InferenceFunction
    private let names: [String]
    private var state0: NDArray
    private var state1: NDArray
    private var state2: NDArray
    private var state3: NDArray
    private var state4: NDArray
    private var state5: NDArray

    /// `initialStates` in the converter's declared stateNames order (angle_all, ssm_all, kprev_all, vprev_all, mla_kv, mla_fill).
    public init(assetURL: URL, initialStates: [NDArray], options: SpecializationOptions = .default) async throws {
        let loaded: AIModel
        do {
            loaded = try await AIModel(contentsOf: assetURL, options: options)
        } catch {
            throw DecodeError.load("\(error)")
        }
        guard let fname = loaded.functionNames.first, let fn = try loaded.loadFunction(named: fname) else {
            throw DecodeError.noFunction
        }
        self.model = loaded
        self.function = fn
        self.names = fn.descriptor.stateNames
        guard names.count == 6, initialStates.count == 6 else {
            throw DecodeError.badStates("descriptor has \(names.count) states \(names); supplied \(initialStates.count) (need 6)")
        }
        self.state0 = initialStates[0]
        self.state1 = initialStates[1]
        self.state2 = initialStates[2]
        self.state3 = initialStates[3]
        self.state4 = initialStates[4]
        self.state5 = initialStates[5]
    }

    /// One decode step: feed `token`, advance all 6 states in place, return the argmax of the logits. (Returns the argmax
    /// Int, NOT the NDArray — the logits are lifetime-bound to the MutableViews and must be consumed inside the call.)
    public func step(token: Int) async throws -> Int {
        let inputID = NDArray(scalars: [Int32(token)], shape: [1, 1])
        // States bound through inout PARAMETERS (not `&self.stateN`): MutableViews is lifetime-dependent and a
        // stored-property borrow would escape across the `await` (the proven BASCoreAIMamba3Session pattern).
        return try await run6(inputID, &state0, &state1, &state2, &state3, &state4, &state5)
    }

    private func run6(_ inputID: NDArray, _ s0: inout NDArray, _ s1: inout NDArray, _ s2: inout NDArray,
                      _ s3: inout NDArray, _ s4: inout NDArray, _ s5: inout NDArray) async throws -> Int {
        var views = InferenceFunction.MutableViews()
        views.insert(&s0, for: names[0])
        views.insert(&s1, for: names[1])
        views.insert(&s2, for: names[2])
        views.insert(&s3, for: names[3])
        views.insert(&s4, for: names[4])
        views.insert(&s5, for: names[5])
        var outputs: InferenceFunction.Outputs
        do {
            outputs = try await function.run(inputs: ["input_id": inputID], states: views)
        } catch {
            throw DecodeError.run("\(error)")
        }
        guard let value = outputs.remove("logits"), let logits = value.ndArray else { throw DecodeError.noLogits }
        return Self.argmaxF16(logits)
    }

    private static func argmaxF16(_ a: NDArray) -> Int {
        let count = a.shape.reduce(1, *)
        var best = 0, bestV = -Float.greatestFiniteMagnitude
        a.view(as: Float16.self).withUnsafePointer { pointer, _, _ in
            var k = 0
            while k < count { let v = Float(pointer[k]); if v > bestV { bestV = v; best = k }; k += 1 }
        }
        return best
    }

    public var stateNames: [String] { names }
}

#endif
