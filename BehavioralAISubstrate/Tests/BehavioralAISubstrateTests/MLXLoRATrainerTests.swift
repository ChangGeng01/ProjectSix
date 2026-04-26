import XCTest
@testable import BASMLXAdapter

/// M233 — coverage for `MLXLoRATrainer` scaffolding.
///
/// Real LoRA training takes 5–60 minutes on Apple Silicon and
/// requires either a HF cache hit (~1.4 GB Gemma 3n E2B) or a
/// network download. Default unit tests cover only the typed
/// validation paths; the env-gated `MLXLoRATrainerE2ETests` (M234+)
/// exercises a real one-iteration round-trip.
final class MLXLoRATrainerTests: XCTestCase {

    // MARK: - 1. Configuration defaults

    func testConfigurationDefaultsAreSensible() {
        let cfg = MLXLoRATrainer.Configuration()
        XCTAssertEqual(cfg.rank, 8)
        XCTAssertEqual(cfg.scale, 10.0)
        XCTAssertEqual(cfg.batchSize, 4)
        XCTAssertEqual(cfg.iterations, 100)
        XCTAssertEqual(cfg.learningRate, 1e-5)
        XCTAssertEqual(cfg.stepsPerReport, 10)
        XCTAssertEqual(cfg.stepsPerEval, 100)
        XCTAssertEqual(cfg.saveEvery, 100)
        XCTAssertEqual(cfg.validationBatches, 10)
        XCTAssertNil(cfg.adapterURL)
    }

    func testConfigurationCodableRoundTrip() throws {
        let original = MLXLoRATrainer.Configuration(
            rank: 16,
            scale: 20.0,
            batchSize: 2,
            iterations: 200,
            learningRate: 5e-5,
            stepsPerReport: 5,
            stepsPerEval: 50,
            saveEvery: 50,
            validationBatches: 5,
            adapterURL: URL(fileURLWithPath: "/tmp/adapter.safetensors"))
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            MLXLoRATrainer.Configuration.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - 2. Default model + configuration init

    func testDefaultInitUsesGemma3nE2B() async {
        let trainer = MLXLoRATrainer()
        // gemma3n_E2B_4bit is the smallest Gemma → fastest soak +
        // E2E run + smallest disk + memory footprint, the right
        // default for "first-run feels reasonable on Apple
        // Silicon".
        XCTAssertEqual(
            trainer.model, MLXModelCatalog.gemma3n_E2B_4bit)
        let cfg = trainer.configuration
        XCTAssertEqual(cfg.rank, 8)
        XCTAssertEqual(cfg.iterations, 100)
    }

    // MARK: - 3. Not-loaded path

    func testTrainThrowsWhenModelNotLoaded() async {
        let trainer = MLXLoRATrainer()
        do {
            try await trainer.train(
                trainingCorpus: ["hello world"],
                validationCorpus: ["sample text"])
            XCTFail(
                "train(...) must throw modelNotLoaded when " +
                "loadFoundationModel(...) hasn't run")
        } catch MLXLoRATrainer.TrainingError.modelNotLoaded {
            // expected
        } catch {
            XCTFail(
                "expected .modelNotLoaded but got \(error)")
        }
    }

    func testSaveAdapterThrowsWhenModelNotLoaded() async {
        let trainer = MLXLoRATrainer()
        let url = URL(fileURLWithPath: "/tmp/test-adapter.safetensors")
        do {
            try await trainer.saveAdapter(to: url)
            XCTFail("expected modelNotLoaded")
        } catch MLXLoRATrainer.TrainingError.modelNotLoaded {
            // expected
        } catch {
            XCTFail(
                "expected .modelNotLoaded but got \(error)")
        }
    }

    func testIsModelLoadedFalseInitially() async {
        let trainer = MLXLoRATrainer()
        let loaded = await trainer.isModelLoaded()
        XCTAssertFalse(
            loaded,
            "fresh trainer must report unloaded; loadModel call " +
            "is required before train")
    }

    // MARK: - 4. Empty corpus rejection

    func testTrainRejectsEmptyTrainingCorpus() async {
        // We can't actually reach the empty-corpus check without
        // a loaded model (modelNotLoaded fires first). This test
        // documents the precedence: not-loaded > empty-corpus.
        let trainer = MLXLoRATrainer()
        do {
            try await trainer.train(
                trainingCorpus: [],
                validationCorpus: [])
            XCTFail("expected modelNotLoaded (precedes empty)")
        } catch MLXLoRATrainer.TrainingError.modelNotLoaded {
            // expected — modelNotLoaded short-circuits
        } catch MLXLoRATrainer.TrainingError.emptyTrainingCorpus {
            XCTFail(
                "modelNotLoaded must precede emptyTrainingCorpus " +
                "in error precedence — caller's load problem is " +
                "more actionable than corpus problem")
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    // MARK: - 5. Error taxonomy

    func testTrainingErrorCasesAreEquatable() {
        XCTAssertEqual(
            MLXLoRATrainer.TrainingError.modelNotLoaded,
            MLXLoRATrainer.TrainingError.modelNotLoaded)
        XCTAssertEqual(
            MLXLoRATrainer.TrainingError.emptyTrainingCorpus,
            MLXLoRATrainer.TrainingError.emptyTrainingCorpus)
        XCTAssertEqual(
            MLXLoRATrainer.TrainingError.underlying(reason: "x"),
            MLXLoRATrainer.TrainingError.underlying(reason: "x"))
        XCTAssertNotEqual(
            MLXLoRATrainer.TrainingError.modelNotLoaded,
            MLXLoRATrainer.TrainingError.emptyTrainingCorpus)
        XCTAssertNotEqual(
            MLXLoRATrainer.TrainingError.underlying(reason: "x"),
            MLXLoRATrainer.TrainingError.underlying(reason: "y"))
    }

    func testTrainingErrorHasLocalizedDescription() {
        XCTAssertNotNil(
            MLXLoRATrainer.TrainingError.modelNotLoaded
                .errorDescription)
        XCTAssertNotNil(
            MLXLoRATrainer.TrainingError.emptyTrainingCorpus
                .errorDescription)
        let underlying = MLXLoRATrainer.TrainingError
            .underlying(reason: "test reason")
            .errorDescription ?? ""
        XCTAssertTrue(
            underlying.contains("test reason"),
            "underlying description must include the wrapped reason")
    }

    // MARK: - 6. Progress event identity

    func testTrainingProgressCasesAreEquatable() {
        let url = URL(fileURLWithPath: "/tmp/foo")
        XCTAssertEqual(
            MLXLoRATrainer.TrainingProgress.trainStep(
                iteration: 1, loss: 0.5, tokensPerSecond: 100),
            MLXLoRATrainer.TrainingProgress.trainStep(
                iteration: 1, loss: 0.5, tokensPerSecond: 100))
        XCTAssertEqual(
            MLXLoRATrainer.TrainingProgress.validation(
                iteration: 50, validationLoss: 0.3),
            MLXLoRATrainer.TrainingProgress.validation(
                iteration: 50, validationLoss: 0.3))
        XCTAssertEqual(
            MLXLoRATrainer.TrainingProgress.saved(
                iteration: 100, adapterURL: url),
            MLXLoRATrainer.TrainingProgress.saved(
                iteration: 100, adapterURL: url))
        XCTAssertEqual(
            MLXLoRATrainer.TrainingProgress.complete(
                totalIterations: 100),
            MLXLoRATrainer.TrainingProgress.complete(
                totalIterations: 100))
    }
}
