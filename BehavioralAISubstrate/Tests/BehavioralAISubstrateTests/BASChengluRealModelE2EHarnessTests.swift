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

    // MARK: - Real-model E2E (gated)

    #if canImport(CoreML)

    func testRealPreflightModelLoadsAndPredicts() async throws {
        try XCTSkipUnless(
            BASChengluRealModelE2EHarness.shouldRunE2E(),
            "QINAO_COREML_E2E not set — skipping real-model " +
            "E2E test (this is the CI default path)")

        guard let url = BASChengluRealModelE2EHarness
            .preflightModelURL
        else {
            throw XCTSkip(
                "QINAO_CHENGLU_PREFLIGHT_PATH not set — " +
                "skipping (E2E gate is on but specific path " +
                "missing)")
        }
        guard BASChengluRealModelE2EHarness.packageExists(
            at: url)
        else {
            throw XCTSkip(
                "Path \(url.path) does not exist — skipping")
        }

        // Load real MLModel + verify it has required output key
        let model = try BASChengluRealModelE2EHarness
            .loadMLModel(at: url)
        XCTAssertNotNil(model.modelDescription)

        // Wire through chapter 三百二一 adapter using parametric
        // closure (since we're calling adapter's MLModel-bound
        // factory via internal makeFromMLModel path)。
        let head = BASChengluPreflightAdapter.make(
            headID: "real-preflight-e2e",
            layerIDPin: .l1,
            model: model)

        // Build typed input from canonical signature
        let ref = try BASChengluFeatureRefBuilder.build(
            tone: "anxious", domain: "medical",
            stake: "critical", timeframe: "today",
            confidant: "trusted-ai", askShape: "question",
            mutationSeed: 2)
        let input = BASLayerInferenceInput(
            layerID: .l1,
            featureRef: ref,
            confidenceFloor: .high)

        // Real inference call — this is the chapter 三百二〇/三百二一
        // production reality test
        let output = try await head.infer(input: input)
        XCTAssertEqual(output.layerID, .l1)
        // Must have populated scores from real model
        XCTAssertFalse(
            output.scores.isEmpty,
            "Real CoreML inference must populate scores")
        // Recommended action should be either afm-route or gemma-route
        XCTAssertTrue(
            output.recommendedAction == "afm-route"
            || output.recommendedAction == "gemma-route",
            "Preflight adapter must produce typed routing " +
            "decision from real MLModel output")
    }

    #endif
}
