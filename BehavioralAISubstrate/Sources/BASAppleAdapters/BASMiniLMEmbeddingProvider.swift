// MARK: - BASMiniLMEmbeddingProvider — on-device MiniLM-L6-v2 sentence embedder (CoreML)
//
// The free, on-device, $0 semantic embedder for the L8 routed memory backend. Wraps the bundled
// `MiniLM.mlmodelc` (sentence-transformers/all-MiniLM-L6-v2, converted to CoreML fp32 with
// mean-pooling + L2-normalization baked in — validated CoreML-vs-PyTorch cosine == 1.0;
// cos(car, automobile)=0.86 vs cos(car, banana)=0.39) + the BERT WordPiece tokenizer.
//
// ## Why this exists
//
// `BASNLEmbeddingProvider` (Apple NLEmbedding word-average) is a moderate baseline; this is the
// strong, transformer-quality semantic embedder the routed memory backend flips onto by default.
// `embedSync(_:)` is SYNCHRONOUS (CoreML prediction is sync), which is exactly what
// `BASL8RoutedMemoryService`'s sync `retrieve()` hot path needs (ch883 — no async in retrieve).
//
// Apple-platform only (`#if canImport(CoreML)`); Linux / cross-platform uses the stub / lexical
// embedder. Model + vocab ship as `BASAppleAdapters` resources (`Bundle.module`).

import Foundation

#if canImport(CoreML)
import CoreML
import BASMemory

public final class BASMiniLMEmbeddingProvider: BASEmbeddingProvider, @unchecked Sendable {

    /// chapter 一百八十五 — pinned dims (the converted model is fixed at these).
    public static let embeddingDim = 384
    public static let sequenceLength = 128
    public static let inputIDsName = "input_ids"
    public static let attentionMaskName = "attention_mask"
    public static let outputName = "embedding"

    public var providerVersion: String { "MiniLM-L6-v2-coreml-fp32-v1" }
    public var dimension: Int { Self.embeddingDim }

    private let model: MLModel
    private let tokenizer: BASBertWordPieceTokenizer

    /// Load the bundled CoreML model + vocab. Returns `nil` if either resource is missing or the
    /// model fails to load (host should fall back to NLEmbedding / lexical).
    public init?() {
        guard let modelURL = Bundle.module.url(
                forResource: "MiniLM", withExtension: "mlmodelc"),
              let vocabURL = Bundle.module.url(
                forResource: "vocab", withExtension: "txt"),
              let tok = BASBertWordPieceTokenizer(
                vocabURL: vocabURL, maxLength: Self.sequenceLength)
        else { return nil }
        let config = MLModelConfiguration()
        // CPU-only: matches the fp32-CPU conversion (deterministic; the ANE/GPU fp16 path is what
        // produced NaN at conversion time).
        config.computeUnits = .cpuOnly
        guard let m = try? MLModel(contentsOf: modelURL, configuration: config) else { return nil }
        self.model = m
        self.tokenizer = tok
    }

    /// SYNC embedding: text → 384-dim L2-normalized sentence vector. Returns a zero vector on any
    /// CoreML failure (never throws into the turn hot path).
    public func embedSync(_ text: String) -> [Float] {
        let zero = [Float](repeating: 0, count: Self.embeddingDim)
        let (ids, mask) = tokenizer.encode(text)
        guard let inputIDs = try? MLMultiArray(
                shape: [1, NSNumber(value: Self.sequenceLength)], dataType: .int32),
              let attMask = try? MLMultiArray(
                shape: [1, NSNumber(value: Self.sequenceLength)], dataType: .int32)
        else { return zero }
        for i in 0..<Self.sequenceLength {
            inputIDs[i] = NSNumber(value: ids[i])
            attMask[i] = NSNumber(value: mask[i])
        }
        guard let inputs = try? MLDictionaryFeatureProvider(dictionary: [
                Self.inputIDsName: MLFeatureValue(multiArray: inputIDs),
                Self.attentionMaskName: MLFeatureValue(multiArray: attMask),
              ]),
              let out = try? model.prediction(from: inputs),
              let emb = out.featureValue(for: Self.outputName)?.multiArrayValue,
              emb.count >= Self.embeddingDim
        else { return zero }
        var vec = [Float](repeating: 0, count: Self.embeddingDim)
        for i in 0..<Self.embeddingDim { vec[i] = emb[i].floatValue }
        return vec
    }

    /// `BASEmbeddingProvider` (async) conformance — wraps the sync path.
    public func embed(_ text: String) async -> BASEmbedding {
        BASEmbedding(
            vector: embedSync(text),
            dimension: Self.embeddingDim,
            providerVersion: providerVersion)
    }

    /// A `@Sendable` sync-embed closure for `BASL8RoutedMemoryService.SyncEmbed`.
    public func syncEmbedClosure() -> @Sendable (String) -> [Float] {
        let provider = self
        return { provider.embedSync($0) }
    }
}
#endif
