// MARK: - BASCoreAIPrefillSession — DUET prefill asset (STEP 2 of the on-device DUET probe)
//
// The prefill half of the DUET is STATELESS-at-the-API-level: it consumes a whole [T,D] prompt-hidden in ONE call and
// emits the boundary handoff as plain OUTPUT tensors (Mamba 4-state angle/ssm/kprev/vprev, or the MLA latent cache) —
// NOT a resident mutable state like the decode `step_ref` session. So this session runs the function with EMPTY
// MutableViews and reads the named outputs. The boundary state is later serialized to the on-disk State-Cache and fed
// into the (separate) decode asset — the state-via-disk handoff that dodges the proven two-asset co-load SIGSEGV.
//
// fp16 throughout (the device artifact is fp16-compute). Compute unit is the caller's SpecializationOptions (prefill
// targets .gpu — the chunked-segsum + softmax graph is GPU-backed, sidestepping the ANE segmenter).

import Foundation

#if canImport(CoreAI)
import CoreAI

@available(iOS 27, macOS 27, *)
public final class BASCoreAIPrefillSession: @unchecked Sendable {
    public enum PrefillError: Error {
        case load(String)
        case noFunction
        case run(String)
    }

    private let model: AIModel
    private let function: InferenceFunction

    public init(assetURL: URL, options: SpecializationOptions = .default) async throws {
        let loaded: AIModel
        do {
            loaded = try await AIModel(contentsOf: assetURL, options: options)
        } catch {
            throw PrefillError.load("\(error)")
        }
        guard let fname = loaded.functionNames.first, let fn = try loaded.loadFunction(named: fname) else {
            throw PrefillError.noFunction
        }
        self.model = loaded
        self.function = fn
    }

    /// Run the prefill once: feed `input` under `inputName`, return the requested named outputs as NDArrays.
    /// `outputNames` are supplied by the caller (the converter's declared output names) — no resident state is bound.
    public func run(input: NDArray, inputName: String, outputNames: [String]) async throws -> [String: NDArray] {
        let views = InferenceFunction.MutableViews()                    // prefill has NO resident state
        var outputs: InferenceFunction.Outputs
        do {
            outputs = try await function.run(inputs: [inputName: input], states: views)
        } catch {
            throw PrefillError.run("\(error)")
        }
        var result: [String: NDArray] = [:]
        for name in outputNames {
            if let v = outputs.remove(name)?.ndArray {
                result[name] = v
            }
        }
        return result
    }
}

#endif
