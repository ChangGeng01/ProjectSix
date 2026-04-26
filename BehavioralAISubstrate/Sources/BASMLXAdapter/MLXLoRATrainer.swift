import Foundation
import BASRuntimeCore
import BASOrgan
#if canImport(MLXLLM)
import MLXLLM
import MLXLMCommon
import MLXOptimizers
import MLXNN
import MLX
import MLXHuggingFace
import HuggingFace
import Tokenizers
#endif

/// M233 — T4 (multi-head supervised fine-tuning) scaffolding.
///
/// ## Why this exists
///
/// `EBRAIN_13L_EXECUTION_V12.md` §训练路线 lists T4 as
/// "多头监督微调" — fine-tuning the foundation model into
/// differentiated organs (Scout / Risk Spine / Permit Knot /
/// Memory Codec / Host Modulation Mesh). Real T4 needs
/// gradient-based weight updates.
///
/// `MLXLoRATrainer` is the BAS-shaped wrapper around the vendored
/// `MLXLLM.LoRATrain` + `MLXLMCommon.LoRAContainer` infrastructure.
/// It exposes a single public actor that hosts can drive without
/// importing any MLX type — substrate redaction (護欄 #2) stays
/// intact.
///
/// ## Scope of M233
///
/// This milestone ships:
///   1. The BAS-side public API (Configuration, TrainingProgress,
///      MLXLoRATrainer actor)
///   2. Loading a foundation model + converting it to LoRA-trainable
///   3. Driving `LoRATrain.train(...)` with caller-supplied corpora
///   4. Saving LoRA adapter weights to a URL
///   5. Default unit tests covering parameter validation + the
///      not-loaded path
///   6. Env-gated E2E test (`QINAO_MLX_LORA_E2E=1`) that does a
///      tiny real run against gemma3n_E2B (~5–15 min on Apple
///      Silicon, requires HF cache hit or 1.4 GB download)
///
/// ## What this is NOT
///
/// - NOT a real training pipeline. It's the wrapper that lets a
///   real corpus + real time produce a real LoRA adapter. The
///   corpus, the validation methodology, the curriculum design —
///   all caller-side.
/// - NOT the full T4. T4 also wants Scout vs Core vs Risk vs
///   Permit head differentiation; M233 just gives you ONE LoRA
///   adapter per call. Splitting into per-organ heads is M234+.
/// - NOT inference of the trained adapter. After saving the
///   adapter, hosts load it back via the existing inference path
///   (mlx-swift-lm's `LoRAContainer.load(into:)`); BAS will get
///   that inference seam in M234.
public actor MLXLoRATrainer {

    /// Caller-supplied training configuration. Mirrors the
    /// vendored `LoRATrain.Parameters` with sensible defaults
    /// suitable for a 5–15 minute smoke run on Apple Silicon.
    public struct Configuration: Sendable, Codable, Equatable {
        /// LoRA rank — higher = more parameters, more capacity,
        /// more memory. 8 is a reasonable default for 4-bit
        /// quantized foundation models.
        public var rank: Int

        /// LoRA scale (alpha / rank); controls how strongly the
        /// adapter modulates the base model.
        public var scale: Float

        /// Training batch size. Larger = better gradients but
        /// more peak memory. 4 is the safe Apple Silicon default.
        public var batchSize: Int

        /// Total training iterations (each iteration = one batch
        /// of `batchSize` examples).
        public var iterations: Int

        /// Adam optimizer learning rate.
        public var learningRate: Float

        /// How often to emit a `.trainStep` progress event with
        /// rolling loss + tokens/second.
        public var stepsPerReport: Int

        /// How often to run validation (in training steps).
        /// Validation emits a `.validation` progress event.
        public var stepsPerEval: Int

        /// How often to checkpoint the LoRA adapter (in steps).
        public var saveEvery: Int

        /// How many validation batches to run per validation pass.
        public var validationBatches: Int

        /// Disk URL where the LoRA adapter weights are checkpointed
        /// (if `saveEvery > 0`) and where `saveAdapter(to:)`
        /// writes the final weights. `nil` disables auto-checkpoint
        /// — caller must invoke `saveAdapter(to:)` explicitly.
        public var adapterURL: URL?

        public init(
            rank: Int = 8,
            scale: Float = 10.0,
            batchSize: Int = 4,
            iterations: Int = 100,
            learningRate: Float = 1e-5,
            stepsPerReport: Int = 10,
            stepsPerEval: Int = 100,
            saveEvery: Int = 100,
            validationBatches: Int = 10,
            adapterURL: URL? = nil
        ) {
            self.rank = rank
            self.scale = scale
            self.batchSize = batchSize
            self.iterations = iterations
            self.learningRate = learningRate
            self.stepsPerReport = stepsPerReport
            self.stepsPerEval = stepsPerEval
            self.saveEvery = saveEvery
            self.validationBatches = validationBatches
            self.adapterURL = adapterURL
        }
    }

    /// Progress events emitted during training. Mirrors
    /// `MLXLLM.LoRATrain.Progress` but is BAS-shaped (no MLX type
    /// names cross the substrate redaction boundary).
    public enum TrainingProgress: Sendable, Equatable {
        /// Per-step training event. `loss` is the rolling mean of
        /// the most recent `stepsPerReport` steps.
        case trainStep(
            iteration: Int,
            loss: Float,
            tokensPerSecond: Double)

        /// Validation pass result.
        case validation(iteration: Int, validationLoss: Float)

        /// Adapter weights checkpointed to disk.
        case saved(iteration: Int, adapterURL: URL)

        /// Training complete.
        case complete(totalIterations: Int)
    }

    /// Errors raised by the trainer. Public so hosts can
    /// pattern-match against typed cases.
    public enum TrainingError: LocalizedError, Equatable {
        case modelNotLoaded
        case emptyTrainingCorpus
        case underlying(reason: String)

        public var errorDescription: String? {
            switch self {
            case .modelNotLoaded:
                return "MLXLoRATrainer: loadModel(...) must be " +
                    "called before train(...)"
            case .emptyTrainingCorpus:
                return "MLXLoRATrainer: training corpus is empty"
            case .underlying(let reason):
                return "MLXLoRATrainer: underlying failure: " +
                    "\(reason)"
            }
        }
    }

    // MARK: - Stored state

    public nonisolated let model: MLXModelCatalog.Entry
    public nonisolated let configuration: Configuration

    #if canImport(MLXLLM)
    /// The loaded foundation model + tokenizer. `nil` until
    /// `loadModel(...)` has completed at least once.
    private var modelContext: ModelContext?
    /// Whether `LoRATrain.convert` has already mutated `modelContext`
    /// to add LoRA adapter layers. Idempotent — `train(...)` only
    /// converts once per actor instance.
    private var modelHasLoRAAdapters: Bool = false
    #endif

    public init(
        model: MLXModelCatalog.Entry = MLXModelCatalog.gemma3n_E2B_4bit,
        configuration: Configuration = Configuration()
    ) {
        self.model = model
        self.configuration = configuration
    }

    // MARK: - Load

    /// Download (or fetch from cache) the foundation model. Same
    /// path as `MLXOrganAdapter.loadModel` — uses the
    /// `huggingFaceLoadModel` macro from MLXHuggingFace, which
    /// returns a `ModelContext` (not just a container) so the
    /// trainer can access `model` + `tokenizer` directly.
    ///
    /// Renamed from `loadModel` to `loadFoundationModel` to avoid
    /// a name collision with the macro expansion's call to
    /// `loadModel(from:using:configuration:useLatest:progressHandler:)`
    /// — Swift's macro expander resolves the unqualified name
    /// against actor instance methods, which would shadow the
    /// MLXLMCommon global.
    public func loadFoundationModel(
        progressHandler: @Sendable @escaping (Progress) -> Void
            = { _ in }
    ) async throws {
        #if canImport(MLXLLM)
        if modelContext != nil { return }

        let modelConfiguration = ModelConfiguration(
            id: model.id,
            extraEOSTokens: Set(model.extraEOSTokens))

        let context = try await #huggingFaceLoadModel(
            configuration: modelConfiguration,
            progressHandler: progressHandler)
        self.modelContext = context
        #else
        throw TrainingError.underlying(
            reason: "MLXLLM framework unavailable in this build")
        #endif
    }

    public func isModelLoaded() -> Bool {
        #if canImport(MLXLLM)
        return modelContext != nil
        #else
        return false
        #endif
    }

    // MARK: - Train

    /// Drive a LoRA fine-tuning run against the loaded model.
    ///
    /// - Parameters:
    ///   - trainingCorpus: array of training-set strings (each
    ///     string is one training example, formatted however the
    ///     caller wants — the underlying `LoRABatchIterator`
    ///     tokenises with the loaded tokenizer).
    ///   - validationCorpus: array of validation-set strings.
    ///     Used at `stepsPerEval` cadence.
    ///   - progressHandler: receives `TrainingProgress` events.
    ///     Pass `{ _ in }` to ignore (the caller can read final
    ///     state via `isModelLoaded()` and the saved-adapter URL).
    public func train(
        trainingCorpus: [String],
        validationCorpus: [String],
        progressHandler: @Sendable @escaping (TrainingProgress) -> Void
            = { _ in }
    ) async throws {
        #if canImport(MLXLLM)
        guard let context = modelContext else {
            throw TrainingError.modelNotLoaded
        }
        guard !trainingCorpus.isEmpty else {
            throw TrainingError.emptyTrainingCorpus
        }

        // Convert the foundation model to LoRA-trainable form on
        // first train() call. Idempotent across re-invocations on
        // the same actor instance.
        let module: Module = context.model as Module
        if !modelHasLoRAAdapters {
            let loraParams = LoRAConfiguration.LoRAParameters(
                rank: configuration.rank,
                scale: configuration.scale,
                keys: nil)
            let loraConfig = LoRAConfiguration(
                numLayers: 4,
                fineTuneType: .lora,
                loraParameters: loraParams)
            do {
                _ = try LoRAContainer.from(
                    model: context.model,
                    configuration: loraConfig)
            } catch {
                throw TrainingError.underlying(
                    reason:
                        "LoRAContainer.from failed: \(error). " +
                        "model may not be LoRA-compatible " +
                        "(LoRAModel conformance required).")
            }
            modelHasLoRAAdapters = true
        }
        let trainableModule = module

        let optimizer = Adam(
            learningRate: configuration.learningRate)

        var loraParameters = LoRATrain.Parameters()
        loraParameters.batchSize = configuration.batchSize
        loraParameters.iterations = configuration.iterations
        loraParameters.stepsPerReport = configuration.stepsPerReport
        loraParameters.stepsPerEval = configuration.stepsPerEval
        loraParameters.validationBatches =
            configuration.validationBatches
        loraParameters.saveEvery = configuration.saveEvery
        loraParameters.adapterURL = configuration.adapterURL

        let totalIterations = configuration.iterations
        try LoRATrain.train(
            model: trainableModule,
            train: trainingCorpus,
            validate: validationCorpus,
            optimizer: optimizer,
            tokenizer: context.tokenizer,
            parameters: loraParameters,
            progress: { progress in
                let translated = Self.translate(progress)
                progressHandler(translated)
                return .more
            })
        progressHandler(.complete(totalIterations: totalIterations))
        #else
        throw TrainingError.underlying(
            reason: "MLXLLM framework unavailable in this build")
        #endif
    }

    /// Save the trained LoRA adapter weights to disk. Caller must
    /// have completed at least one `train(...)` invocation (the
    /// underlying model must have LoRA-adapter layers attached).
    public func saveAdapter(to url: URL) async throws {
        #if canImport(MLXLLM)
        guard let context = modelContext else {
            throw TrainingError.modelNotLoaded
        }
        let module: Module = context.model as Module
        do {
            try LoRATrain.saveLoRAWeights(model: module, url: url)
        } catch {
            throw TrainingError.underlying(
                reason:
                    "saveLoRAWeights failed: \(error)")
        }
        #else
        throw TrainingError.underlying(
            reason: "MLXLLM framework unavailable in this build")
        #endif
    }

    // MARK: - Translation

    #if canImport(MLXLLM)
    /// Translate a vendored `LoRATrain.Progress` event into the
    /// BAS-shaped `TrainingProgress`. Substrate redaction means
    /// the MLXLLM type never reaches the caller's progressHandler.
    private static func translate(
        _ progress: LoRATrain.Progress
    ) -> TrainingProgress {
        switch progress {
        case .train(let iteration, let trainingLoss,
                    let iterationsPerSecond, let tokensPerSecond):
            _ = iterationsPerSecond
            return .trainStep(
                iteration: iteration,
                loss: trainingLoss,
                tokensPerSecond: tokensPerSecond)
        case .validation(let iteration, let validationLoss,
                         let validationTime):
            _ = validationTime
            return .validation(
                iteration: iteration,
                validationLoss: validationLoss)
        case .save(let iteration, let url):
            return .saved(iteration: iteration, adapterURL: url)
        }
    }
    #endif
}
