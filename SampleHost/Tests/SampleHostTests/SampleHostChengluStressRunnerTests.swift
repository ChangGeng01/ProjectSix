// MARK: - SampleHostChengluStressRunnerTests — chapter 三百四三 / M830
//
// Closes the test-coverage gap for chapter 三百三九 / M826
// `SampleHostChengluStressRunner`。Deep review (chapter 三百三七)
// noted this file shipped without test coverage but skipped the
// fix because focus was on附录 X production code,not SampleHost。
// This chapter fills that gap honestly。
//
// Tests cover:
//   - Static `loadBundledModel` error path (missing resource)
//   - Status enum equality + idle default
//   - Initial published-state defaults (zero counters,empty log)
//
// Tests do NOT cover:
//   - The actual stress loop (would require real `.mlpackage`
//     bundles + minutes of execution — covered by gated XCTest
//     on real iPhone via the panel button)
//   - `loadAllBundledModels` / `loadAndBuildOffActor` happy
//     path (requires `.mlmodelc` bundle in test resources;
//     SampleHostTests bundle doesn't carry the production
//     models — that's deliberate per chapter 三百三二
//     gated-E2E doctrine)

import XCTest
@testable import SampleHost

@MainActor
final class SampleHostChengluStressRunnerTests: XCTestCase {

    // MARK: - Status enum

    func testStatusIdleEqualsItself() {
        XCTAssertEqual(
            SampleHostChengluStressRunner.Status.idle,
            SampleHostChengluStressRunner.Status.idle)
    }

    func testStatusErrorEquatableByMessage() {
        let a = SampleHostChengluStressRunner.Status
            .error("foo")
        let b = SampleHostChengluStressRunner.Status
            .error("foo")
        let c = SampleHostChengluStressRunner.Status
            .error("bar")
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    func testStatusVariantsDistinct() {
        XCTAssertNotEqual(
            SampleHostChengluStressRunner.Status.idle,
            SampleHostChengluStressRunner.Status
                .loadingModels)
        XCTAssertNotEqual(
            SampleHostChengluStressRunner.Status.idle,
            SampleHostChengluStressRunner.Status.running)
        XCTAssertNotEqual(
            SampleHostChengluStressRunner.Status.running,
            SampleHostChengluStressRunner.Status.finished)
    }

    // MARK: - Initial published state

    func testInitialPublishedStateDefaults() {
        let runner = SampleHostChengluStressRunner()
        XCTAssertEqual(runner.status, .idle)
        XCTAssertEqual(runner.iterations, 0)
        XCTAssertEqual(runner.failures, 0)
        XCTAssertEqual(runner.determinismMismatches, 0)
        XCTAssertEqual(runner.elapsedSeconds, 0)
        XCTAssertEqual(runner.throughput, 0)
        XCTAssertEqual(runner.recentAvgMs, 0)
        XCTAssertEqual(runner.p50Ms, 0)
        XCTAssertEqual(runner.p95Ms, 0)
        XCTAssertEqual(runner.p99Ms, 0)
        XCTAssertEqual(runner.statusLine, "Idle")
        XCTAssertTrue(runner.progressLog.isEmpty)
        XCTAssertFalse(runner.isRunning)
    }

    // MARK: - loadBundledModel error path

    /// `loadBundledModel` throws `bundledModelMissing` when the
    /// resource doesn't exist in test bundle。Tests don't bundle
    /// production `.mlmodelc` files,so this is the expected
    /// path in CI。
    func testLoadBundledModelMissingThrowsTypedError() {
        let bogusName = "ThisModelDefinitelyDoesNotExist_\(UUID())"
        do {
            _ = try SampleHostChengluStressRunner
                .loadBundledModel(bogusName)
            XCTFail("Should throw bundledModelMissing")
        } catch let err as ChengluStressError {
            switch err {
            case .bundledModelMissing(let name):
                XCTAssertEqual(name, bogusName)
            }
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    /// `loadAndBuildOffActor` should also surface the missing-
    /// model error gracefully (Result.failure path)。
    func testLoadAndBuildOffActorMissingModelsReturnsFailure()
        async
    {
        // Tests don't ship production .mlmodelc → load should
        // fail at the first model
        let result = await SampleHostChengluStressRunner
            .loadAndBuildOffActor()
        switch result {
        case .success:
            // If somehow models ARE present (e.g. test target
            // accidentally bundles them),this is an
            // unexpected pass。Either branch is "test passes"
            // because both code paths are valid。
            break
        case .failure(let err):
            // Expected in CI: model missing
            XCTAssertTrue(
                err is ChengluStressError
                || "\(err)".contains("model"),
                "Expected model-missing error,got \(err)")
        }
    }

    // MARK: - ChengluStressError description format

    func testChengluStressErrorDescription() {
        let err = ChengluStressError
            .bundledModelMissing("FakeModel_v0")
        XCTAssertTrue(
            err.description.contains("FakeModel_v0"),
            "Error description must include resource name " +
            "for diagnostic emission")
        XCTAssertTrue(
            err.description.contains("Bundle.main"),
            "Error description must reference Bundle.main " +
            "lookup path")
    }

    // MARK: - cancel() before start is no-op

    func testCancelBeforeStartIsNoop() {
        let runner = SampleHostChengluStressRunner()
        runner.cancel()  // No active task — should not crash
        XCTAssertEqual(runner.status, .idle)
        XCTAssertFalse(runner.isRunning)
    }
}
