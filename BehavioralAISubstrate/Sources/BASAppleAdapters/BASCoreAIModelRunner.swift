// MARK: - BASCoreAIModelRunner
//
// The REAL Apple Core AI inference seam: load a `.aimodel` asset, specialize it to a compute unit, resolve an
// `InferenceFunction`, and run tensor inference — with a pure-Swift `[Float]` boundary so callers/tests never
// touch the bleeding-edge `NDArray` / `Span` types directly (marshaling goes through `BASCoreAINDArrayBridge`).
//
// ## Availability
//
// Entirely `#if canImport(CoreAI)` + `@available(iOS 27, macOS 27, *)`. Under the default Xcode 26.5 toolchain
// this type does not exist (nothing outside the adapter's gated branch references it). Compile-certified under
// Xcode 27; run-certified on the iOS 27 simulator + iPhone Air. This is the reasoning-side inference seam — it
// is hint-only and never enters the byte-deterministic spine (红线 7).

import Foundation

#if canImport(CoreAI)
import CoreAI   // umbrella: AIModel, AIModelAsset, InferenceFunction, NDArray, SpecializationOptions, ComputeUnitKind.
#endif

// MARK: - Errors (always available so callers can reference the typed failures)

public enum BASCoreAIModelRunnerError: Error, Equatable, Sendable {
    /// The Core AI framework is not present in this build (default toolchain).
    case coreAIUnavailable
    /// `AIModel(contentsOf:options:)` failed to load / specialize the asset.
    case assetLoadFailed(message: String)
    /// The model declared no inference functions.
    case noFunctions
    /// The requested (or first) function name did not resolve to an `InferenceFunction`.
    case functionNotFound(name: String)
    /// An input was supplied without a matching shape.
    case inputShapeMissing(name: String)
    /// A declared output was absent from the run result.
    case outputMissing(name: String)
    /// A declared output was present but did not carry an `NDArray` (e.g. a pixel buffer).
    case outputNotNDArray(name: String)
}

#if canImport(CoreAI)

/// Loads + specializes a Core AI `.aimodel` and runs an `InferenceFunction` with a pure-Swift tensor boundary.
/// An `actor` so concurrent callers serialize through one inference at a time (Core AI's per-call thread-safety
/// is not contractually guaranteed; serialization is the safe default, mirroring the substrate's other adapters).
@available(iOS 27, macOS 27, *)
public actor BASCoreAIModelRunner {

    private let model: AIModel
    private let function: InferenceFunction

    /// The resolved inference function name (the requested one, or the model's first).
    public nonisolated let functionName: String
    /// Input tensor names the resolved function declares (from its descriptor).
    public nonisolated let inputNames: [String]
    /// Output tensor names the resolved function declares (from its descriptor).
    public nonisolated let outputNames: [String]

    /// Load + specialize the `.aimodel` at `assetURL`, resolving `functionName` (default: the model's first
    /// function). `options` selects the preferred compute unit (`.default`, `.cpuOnly`, or an explicit kind).
    public init(
        assetURL: URL,
        functionName requestedFunction: String? = nil,
        options: SpecializationOptions = .default
    ) async throws {
        let loadedModel: AIModel
        do {
            loadedModel = try await AIModel(contentsOf: assetURL, options: options)
        } catch {
            throw BASCoreAIModelRunnerError.assetLoadFailed(message: "\(error)")
        }
        let availableFunctions = loadedModel.functionNames
        guard let resolved = requestedFunction ?? availableFunctions.first else {
            throw BASCoreAIModelRunnerError.noFunctions
        }
        guard let resolvedFunction = try loadedModel.loadFunction(named: resolved) else {
            throw BASCoreAIModelRunnerError.functionNotFound(name: resolved)
        }
        self.model = loadedModel
        self.function = resolvedFunction
        self.functionName = resolved
        self.inputNames = resolvedFunction.descriptor.inputNames
        self.outputNames = resolvedFunction.descriptor.outputNames
    }

    /// Run inference. `inputs` + `shapes` are keyed by the model's input tensor names; the result is keyed by
    /// the model's output tensor names. Each `[Float]` is marshaled to a Float32 `NDArray` (validated by the
    /// bridge) and each output `NDArray` is copied back to a flat row-major `[Float]`.
    public func run(
        inputs: [String: [Float]],
        shapes: [String: [Int]]
    ) async throws -> [String: [Float]] {
        var ndInputs: [String: NDArray] = [:]
        for (name, scalars) in inputs {
            guard let shape = shapes[name] else {
                throw BASCoreAIModelRunnerError.inputShapeMissing(name: name)
            }
            ndInputs[name] = try BASCoreAINDArrayBridge.makeNDArray(scalars: scalars, shape: shape)
        }

        var outputs = try await function.run(inputs: ndInputs)

        var result: [String: [Float]] = [:]
        for name in outputNames {
            guard let value = outputs.remove(name) else {
                throw BASCoreAIModelRunnerError.outputMissing(name: name)
            }
            guard let ndArray = value.ndArray else {
                throw BASCoreAIModelRunnerError.outputNotNDArray(name: name)
            }
            result[name] = BASCoreAINDArrayBridge.floats(from: ndArray)
        }
        return result
    }
}

#endif
