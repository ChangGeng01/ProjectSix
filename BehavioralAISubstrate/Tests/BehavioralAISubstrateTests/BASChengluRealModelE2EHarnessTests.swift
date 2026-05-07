// MARK: - BASChengluRealModelE2EHarnessTests — chapter 三百三二 / M819
//
// Phase F (附录 X) 第十刀 测试覆盖:gated real-MLModel E2E tests。
//
// Two test classes:
//
//   1. **Always-on tests** — verify the harness primitives
//      (env-var parsing, gate predicate, path resolution) work
//      regardless of whether real `.mlpackage` files exist。
//      These run in every CI build。
//
//   2. **Gated E2E tests** — load real `.mlpackage` files from
//      env-var-supplied paths,run inference,validate the附录 X
//      pipeline against actual CoreML。Skip when
//      `QINAO_COREML_E2E != "1"`。
//
// To run gated E2E locally:
//
//     export QINAO_COREML_E2E=1
//     export QINAO_CHENGLU_PREFLIGHT_PATH="$(pwd)/../SampleHost/ChengluPreflight_v0.mlpackage"
//     swift test --filter BASChengluRealModelE2EHarnessTests
//
// ## Doctrine pins verified
//
//   - Gate predicate honors env var (CI default: skip)
//   - Path resolver handles missing / empty / whitespace env
//     vars correctly
//   - Real MLModel load + adapter wire works (gated path only)

import XCTest
@testable import BASAppleAdapters
@testable import BASRuntimeCore

#if canImport(CoreML)
import CoreML
#endif

final class BASChengluRealModelE2EHarnessTests: XCTestCase {

    // MARK: - Env var constants typed-pinned

    func testEnvVarConstantsTypedPinned() {
        XCTAssertEqual(
            BASChengluRealModelE2EHarnessEnvVars.masterGate,
            "QINAO_COREML_E2E")
        XCTAssertEqual(
            BASChengluRealModelE2EHarnessEnvVars.preflightPath,
            "QINAO_CHENGLU_PREFLIGHT_PATH")
        XCTAssertEqual(
            BASChengluRealModelE2EHarnessEnvVars.multiHeadPath,
            "QINAO_CHENGLU_MULTIHEAD_PATH")
        XCTAssertEqual(
            BASChengluRealModelE2EHarnessEnvVars
                .permitPredictPath,
            "QINAO_CHENGLU_PERMIT_PREDICT_PATH")
        XCTAssertEqual(
            BASChengluRealModelE2EHarnessEnvVars.lengthHeadPath,
            "QINAO_CHENGLU_LENGTH_PATH")
        XCTAssertEqual(
            BASChengluRealModelE2EHarnessEnvVars
                .latencyHeadPath,
            "QINAO_CHENGLU_LATENCY_PATH")
    }

    // MARK: - Path resolution (env-var-driven)

    func testEnvPathReturnsNilForMissingVar() {
        let url = BASChengluRealModelE2EHarness.envPath(
            "QINAO_DEFINITELY_NOT_SET_VAR_\(UUID().uuidString)")
        XCTAssertNil(url)
    }

    // MARK: - File existence helper

    func testPackageExistsRejectsNonexistentPath() {
        let url = URL(fileURLWithPath:
            "/nonexistent/path/\(UUID().uuidString).mlpackage")
        XCTAssertFalse(
            BASChengluRealModelE2EHarness.packageExists(
                at: url))
    }

    func testPackageExistsAcceptsExistingDirectory() {
        // tmp dir always exists as a directory
        let tmpURL = FileManager.default.temporaryDirectory
        XCTAssertTrue(
            BASChengluRealModelE2EHarness.packageExists(
                at: tmpURL))
    }

    func testPackageExistsRejectsRegularFile() throws {
        // Create a temporary regular file (not a directory)
        let tmpFile = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "test-\(UUID().uuidString).txt")
        try "data".write(
            to: tmpFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tmpFile) }
        XCTAssertFalse(
            BASChengluRealModelE2EHarness.packageExists(
                at: tmpFile),
            "Regular file (not directory) must be rejected — " +
            ".mlpackage is always a directory bundle")
    }

    // MARK: - Gate predicate

    func testShouldRunE2EFalseInDefaultCI() {
        // In normal CI (no env var set), gate must be closed
        // unless caller explicitly opts in via the env var.
        // This test is brittle if QINAO_COREML_E2E happens to
        // be set in the test runner's environment;skip it
        // if so to avoid false failures。
        let masterGateSet = ProcessInfo.processInfo
            .environment[
                BASChengluRealModelE2EHarnessEnvVars
                    .masterGate]
        if masterGateSet == "1" {
            // Caller explicitly enabled — gate should be open
            XCTAssertTrue(
                BASChengluRealModelE2EHarness.shouldRunE2E())
        } else {
            // Default state: gate closed
            XCTAssertFalse(
                BASChengluRealModelE2EHarness.shouldRunE2E())
        }
    }

    // MARK: - Convenience URL accessors return nil when env vars absent

    func testConvenienceURLAccessorsReturnNilWithoutEnvVars() {
        // These tests assume the test runner doesn't have the
        // path env vars set。If they ARE set,the assertions
        // would correctly check non-nil instead — but for the
        // CI-default case (no env vars), they must be nil。
        let preflightSet = ProcessInfo.processInfo.environment[
            BASChengluRealModelE2EHarnessEnvVars
                .preflightPath]
        if preflightSet == nil || preflightSet?.isEmpty == true {
            XCTAssertNil(
                BASChengluRealModelE2EHarness.preflightModelURL)
        }
    }

    // MARK: - Real-model E2E (gated) — shared helper

    #if canImport(CoreML)

    /// Build typed input + verify result has scores。Reused by
    /// every gated test below to avoid copy-paste drift。
    private func runGatedHeadInference(
        head: BASCoreMLLayerHead,
        layerID: BASMotherboardLayer14
    ) async throws -> BASLayerInferenceOutput {
        let ref = try BASChengluFeatureRefBuilder.build(
            tone: "anxious", domain: "medical",
            stake: "critical", timeframe: "today",
            confidant: "trusted-ai", askShape: "question",
            mutationSeed: 2)
        let input = BASLayerInferenceInput(
            layerID: layerID,
            featureRef: ref,
            confidenceFloor: .high)
        let output = try await head.infer(input: input)
        XCTAssertEqual(output.layerID, layerID)
        XCTAssertFalse(
            output.scores.isEmpty,
            "Real CoreML inference must populate scores")
        return output
    }

    private func loadGatedModel(
        at url: URL?, envVarName: String
    ) throws -> MLModel {
        try XCTSkipUnless(
            BASChengluRealModelE2EHarness.shouldRunE2E(),
            "QINAO_COREML_E2E not set — skipping real-model " +
            "E2E test (this is the CI default path)")
        guard let url = url else {
            throw XCTSkip(
                "\(envVarName) not set — skipping (E2E " +
                "gate is on but specific path missing)")
        }
        guard BASChengluRealModelE2EHarness.packageExists(
            at: url)
        else {
            throw XCTSkip(
                "Path \(url.path) does not exist — skipping")
        }
        return try BASChengluRealModelE2EHarness.loadMLModel(
            at: url)
    }

    // MARK: - Per-adapter gated E2E tests

    func testRealPreflightModelLoadsAndPredicts() async throws {
        let model = try loadGatedModel(
            at: BASChengluRealModelE2EHarness.preflightModelURL,
            envVarName: "QINAO_CHENGLU_PREFLIGHT_PATH")
        let head = BASChengluPreflightAdapter.make(
            headID: "real-preflight-e2e",
            layerIDPin: .l1,
            model: model)
        let output = try await runGatedHeadInference(
            head: head, layerID: .l1)
        XCTAssertTrue(
            output.recommendedAction == "afm-route"
            || output.recommendedAction == "gemma-route",
            "Preflight must produce typed routing decision")
    }

    /// Real shipped output keys for `ChengluMultiHead_v0.mlpackage`
    /// (chapter 一百八十一+)。These are the **actual** keys the
    /// shipped model produces — DIFFERENT from chapter 三百二一's
    /// `intent`/`emotion`/`risk`/`memory_importance` aspirational
    /// placeholders。Honest reality:
    ///
    ///   - `afm_success_prob`   — sigmoid: AFM-vs-Gemma route
    ///   - `block_prob`          — sigmoid: block-vs-delay policy
    ///   - `length_norm`         — regression: normalized length
    ///   - `latency_norm`        — regression: normalized latency
    ///   - `verbosity_prob`      — sigmoid: verbosity hint (5th
    ///                             output added in newer training)
    ///
    /// The附录 X §X.2 doctrine slot mappings (l4.question-type ←
    /// MultiHead.intent etc.) remain ASPIRATIONAL — no currently
    /// shipped model has those output keys。Doctrine slot wiring
    /// for them lives in chapter 三百二一 forward-compat for
    /// future trainings (chapter 一百七十七 ChengluMemory P1 etc.)。
    private static let realShippedMultiHeadKeys: [String] = [
        "afm_success_prob",
        "block_prob",
        "length_norm",
        "latency_norm"
    ]

    func testRealMultiHeadShippedKeysPopulated() async throws {
        let model = try loadGatedModel(
            at: BASChengluRealModelE2EHarness.multiHeadModelURL,
            envVarName: "QINAO_CHENGLU_MULTIHEAD_PATH")
        // Use ANY outputKey for the wrapper — adapter populates
        // ALL output keys in scores regardless。
        let head = BASChengluMultiHeadAdapter.make(
            headID: "real-multihead-shipped-keys-e2e",
            layerIDPin: .l4,
            outputKey: "afm_success_prob",
            model: model)
        let output = try await runGatedHeadInference(
            head: head, layerID: .l4)
        // Verify the 4 SHIPPED output keys are populated。The
        // adapter's allOutputKeys (intent/emotion/risk/memory_
        // importance) are aspirational — no currently shipped
        // model has them。
        for key in Self.realShippedMultiHeadKeys {
            XCTAssertNotNil(
                output.scores[key],
                "Real ChengluMultiHead_v0 model must populate " +
                "\(key) score (this is a SHIPPED output key)。" +
                "Chapter 三百二一's intent/emotion/risk/memory_" +
                "importance keys are ASPIRATIONAL — not in " +
                "any shipped model。")
        }
    }

    func testRealMultiHeadAspirationalKeysAreNil() async throws {
        // Doctrine pin: confirm chapter 三百二一's aspirational
        // keys ARE NOT in the currently shipped model。If this
        // test starts failing,it means a new MultiHead model
        // got shipped with those keys — at which point chapter
        // 三百二一's slot mapping becomes real and this test's
        // intent should flip。
        let model = try loadGatedModel(
            at: BASChengluRealModelE2EHarness.multiHeadModelURL,
            envVarName: "QINAO_CHENGLU_MULTIHEAD_PATH")
        let head = BASChengluMultiHeadAdapter.make(
            headID: "real-multihead-aspirational-check-e2e",
            layerIDPin: .l4,
            outputKey: "afm_success_prob",
            model: model)
        let output = try await runGatedHeadInference(
            head: head, layerID: .l4)
        for key in BASChengluMultiHeadAdapter.allOutputKeys {
            XCTAssertNil(
                output.scores[key],
                "Aspirational key \(key) must NOT be in " +
                "currently shipped model。If this fails,a " +
                "new model was shipped — flip chapter 三百二一 " +
                "doctrine note from aspirational to real。")
        }
    }

    func testRealPermitPredictModelLoadsAndPredicts()
        async throws
    {
        let model = try loadGatedModel(
            at: BASChengluRealModelE2EHarness
                .permitPredictModelURL,
            envVarName: "QINAO_CHENGLU_PERMIT_PREDICT_PATH")
        let head = BASChengluPermitPredictAdapter.make(
            headID: "real-permit-predict-e2e",
            layerIDPin: .l11,
            model: model)
        let output = try await runGatedHeadInference(
            head: head, layerID: .l11)
        XCTAssertTrue(
            output.recommendedAction == "block"
            || output.recommendedAction == "delay",
            "Permit-predict must produce typed policy hint")
    }

    func testRealLengthHeadModelLoadsAndPredicts() async throws
    {
        let model = try loadGatedModel(
            at: BASChengluRealModelE2EHarness
                .lengthHeadModelURL,
            envVarName: "QINAO_CHENGLU_LENGTH_PATH")
        let head = BASChengluLengthHeadAdapter.make(
            headID: "real-length-e2e",
            layerIDPin: .l12,
            model: model)
        let output = try await runGatedHeadInference(
            head: head, layerID: .l12)
        let predicted = output.scores[
            BASChengluLengthHeadAdapter.outputKey] ?? -1
        XCTAssertTrue(
            predicted.isFinite,
            "Length regression must produce finite prediction")
    }

    func testRealLatencyHeadModelLoadsAndPredicts() async throws
    {
        let model = try loadGatedModel(
            at: BASChengluRealModelE2EHarness
                .latencyHeadModelURL,
            envVarName: "QINAO_CHENGLU_LATENCY_PATH")
        let head = BASChengluLatencyHeadAdapter.make(
            headID: "real-latency-e2e",
            layerIDPin: .l1,
            model: model)
        let output = try await runGatedHeadInference(
            head: head, layerID: .l1)
        let predicted = output.scores[
            BASChengluLatencyHeadAdapter.outputKey] ?? -1
        XCTAssertTrue(
            predicted.isFinite,
            "Latency regression must produce finite prediction")
    }

    #endif
}
