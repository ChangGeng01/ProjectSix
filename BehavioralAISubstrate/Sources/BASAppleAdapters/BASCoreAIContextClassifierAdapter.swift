// MARK: - BASCoreAIContextClassifierAdapter
//
// A Core AI-backed twin of the CoreML `BASContextClassifierMLAdapter` (BASRuntimeCore). It runs the SAME
// context-classifier head — same 256-bucket input encoding, same 7 labels in the same order — on Apple Core AI
// instead of CoreML, so its logits are directly comparable to the incumbent's for a shadow parity trial
// (`BASCoreAIShadowComparison`). This is the operator's "migrate CoreML → Core AI only if it wins
// parity + latency + memory" gate, made concrete.
//
// ## Availability + honesty
//
// The real path is `#if canImport(CoreAI)` + `@available(iOS 27, macOS 27, *)`; under the default Xcode 26.5
// toolchain the adapter compiles to a fallback whose every method throws `.coreAIUnavailable`. So the substrate
// never silently claims a Core AI classification it cannot run. Run-cert requires the `.aimodel` asset (C0) +
// an iOS 27 runtime (sim / iPhone Air). Candidate output is observation-only — it never feeds the turn or any
// governance verdict.

import Foundation
import BASRuntimeCore   // BASContextClassifierMLAdapter.labels + BASContextClassifierInputEncoder (shared featurization)

#if canImport(CoreAI)
import CoreAI
#endif

// MARK: - Errors (always available)

public enum BASCoreAIContextClassifierError: Error, Equatable, Sendable {
    /// Core AI framework absent in this build (default toolchain) — the adapter is a no-op fallback.
    case coreAIUnavailable
    /// The bundled `BASContextClassifier.aimodel` resource was not found (asset not yet produced — see C0).
    case assetResourceMissing
    /// Loading / specializing the Core AI model failed.
    case modelLoadFailed(message: String)
    /// The model's logits output didn't match the expected label count.
    case unexpectedOutputShape(message: String)
}

// MARK: - Pure label math (framework-free — testable under any toolchain)

/// Pure argmax + numerically-stable softmax over a logits vector → `(label, confidence)`. Mirrors the CoreML
/// incumbent's confidence math (subtract-max-before-exp) so the two adapters agree on labeling given equal
/// logits. Ungated so it carries real test coverage without the Core AI framework.
public enum BASCoreAIContextClassifierMath {
    public static func argmaxSoftmax(
        labels: [String], logits: [Float]
    ) -> (label: String, confidence: Double) {
        guard !logits.isEmpty else { return (labels.first ?? "", 0) }
        let argmax = logits.indices.max(by: { logits[$0] < logits[$1] }) ?? 0
        let maxLogit = logits.max() ?? 0
        var expSum: Double = 0
        var expArgmax: Double = 0
        for (i, l) in logits.enumerated() {
            let e = exp(Double(l - maxLogit))
            expSum += e
            if i == argmax { expArgmax = e }
        }
        let confidence = expSum > 0 ? expArgmax / expSum : 1.0 / Double(logits.count)
        let label = argmax < labels.count ? labels[argmax] : (labels.last ?? "")
        return (label, confidence)
    }
}

// MARK: - Honest provider metadata (ungated, discoverable)

/// Discoverable, honest metadata for the Core AI context-classifier provider. Kept ungated + framework-free so
/// the tier is assertable without the Core AI runtime. The tier is `experimental` until the candidate wins
/// parity + latency + memory against the CoreML incumbent on real iOS 27 hardware (operator's migration gate) —
/// only then does it earn `certified`. The CoreML incumbent is NOT replaced before that.
public enum BASCoreAIClassifierMetadata {
    public static let providerKind = "coreAI"
    public static let certificationTier = "experimental"
    public static let candidateRef = "coreai.context-classifier.v1"
}

#if canImport(CoreAI)

/// Core AI-backed context classifier. Holds a `BASCoreAIModelRunner` over the bundled `.aimodel`.
@available(iOS 27, macOS 27, *)
public final class BASCoreAIContextClassifierAdapter: @unchecked Sendable {

    /// The 7 labels in the SAME order as the CoreML incumbent — so logits line up index-for-index for parity.
    public static let labels: [String] = BASContextClassifierMLAdapter.labels

    /// Conventional input tensor name when the asset's function descriptor declares none.
    public static let defaultInputTensorName = "bag_of_buckets"

    private let runner: BASCoreAIModelRunner
    private let inputTensorName: String
    private let outputTensorName: String

    /// Load + specialize the bundled `BASContextClassifier.aimodel` (or `assetURL` if given). `options` selects
    /// the preferred compute unit (`.default` lets Core AI choose; `.cpuOnly` pins CPU for sim parity).
    ///
    /// NOTE (API asymmetry, deliberate): `options` exists ONLY in this gated branch — `SpecializationOptions`
    /// is a Core AI type that does not exist under the default (no-CoreAI) toolchain, so the fallback init
    /// cannot mirror it. Cross-toolchain callers must construct without `options` (or gate the call site).
    public init(
        assetURL: URL? = nil,
        options: SpecializationOptions = .default
    ) async throws {
        let url: URL
        if let assetURL {
            url = assetURL
        } else if let bundled = Bundle.module.url(
            forResource: "BASContextClassifier", withExtension: "aimodel") {
            url = bundled
        } else {
            throw BASCoreAIContextClassifierError.assetResourceMissing
        }
        do {
            self.runner = try await BASCoreAIModelRunner(assetURL: url, options: options)
        } catch {
            throw BASCoreAIContextClassifierError.modelLoadFailed(message: "\(error)")
        }
        // Prefer the function descriptor's declared names; fall back to conventional names.
        self.inputTensorName = runner.inputNames.first ?? Self.defaultInputTensorName
        self.outputTensorName = runner.outputNames.first ?? "logits"
    }

    /// Classify `text` → `(label, confidence, logits)` — the SAME contract the CoreML incumbent exposes.
    public func classify(
        text: String
    ) async throws -> (label: String, confidence: Double, logits: [Float]) {
        // Same 256-bucket bag-of-tokens encoding as the incumbent (shared encoder from BASRuntimeCore).
        let bag = BASContextClassifierInputEncoder.encode(text)
        // Fail-fast on the ENCODER contract (mirrors the incumbent's hardcoded [1, numBuckets] MLMultiArray):
        // the shape is pinned to the declared constant, so an encoder regression surfaces as a clear error
        // here — never as a silently mis-shaped tensor fed to the model.
        let numBuckets = BASContextClassifierInputEncoder.numBuckets
        guard bag.count == numBuckets else {
            throw BASCoreAIContextClassifierError.unexpectedOutputShape(
                message: "encoder produced \(bag.count) buckets, contract is \(numBuckets)")
        }
        let outputs = try await runner.run(
            inputs: [inputTensorName: bag],
            shapes: [inputTensorName: [1, numBuckets]])
        guard let logits = outputs[outputTensorName],
              logits.count == Self.labels.count else {
            throw BASCoreAIContextClassifierError.unexpectedOutputShape(
                message: "expected \(Self.labels.count) logits from output '\(outputTensorName)', "
                    + "got \(outputs[outputTensorName]?.count ?? -1)")
        }
        let decided = BASCoreAIContextClassifierMath.argmaxSoftmax(
            labels: Self.labels, logits: logits)
        return (decided.label, decided.confidence, logits)
    }
}

#else

/// Fallback when Core AI is absent (default Xcode 26.5 toolchain). Same public surface; every entry throws
/// `.coreAIUnavailable` so a host can detect the gated state instead of silently degrading.
public final class BASCoreAIContextClassifierAdapter: @unchecked Sendable {

    public static let labels: [String] = BASContextClassifierMLAdapter.labels
    public static let defaultInputTensorName = "bag_of_buckets"

    public init(assetURL: URL? = nil) async throws {
        throw BASCoreAIContextClassifierError.coreAIUnavailable
    }

    public func classify(
        text: String
    ) async throws -> (label: String, confidence: Double, logits: [Float]) {
        throw BASCoreAIContextClassifierError.coreAIUnavailable
    }
}

#endif
