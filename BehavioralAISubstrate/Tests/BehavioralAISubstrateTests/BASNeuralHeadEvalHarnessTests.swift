import XCTest
@testable import BASOrgan
@testable import BASRuntimeCore

/// M105 — `BASNeuralHeadEvalHarness` contract tests.
///
/// Covered invariants:
///
/// 1. Expectation matching for each of the three cases
///    (`.contains`, `.doesNotContain`, `.nonEmpty`)
/// 2. Expectation Codable round-trip for all three cases
/// 3. Harness runs N prompts through any `BASOrganAdapter` and
///    produces N outcomes, one per prompt, preserving order
/// 4. Per-head pass-rate is computed correctly when prompts share
///    a head
/// 5. Adapter throw → outcome marked failed with errorMessage
///    populated; subsequent prompts still run (one bad prompt
///    does not abort the suite)
/// 6. Empty prompt list → empty outcomes array + passRate 0.0
/// 7. Report Codable round-trip (verify outcome-level serialization)
final class BASNeuralHeadEvalHarnessTests: XCTestCase {

    // MARK: - Helpers

    private func makeRequest(
        id: String,
        instruction: String,
        role: BASOrganRole = .scout
    ) -> BASOrganRequest {
        BASOrganRequest(
            requestID: id,
            role: role,
            preset: BASOrganPreset(
                name: "scout.v1",
                temperature: 0.0,
                topP: 1.0,
                maxOutputTokens: 100,
                deterministic: true),
            instruction: instruction)
    }

    // MARK: - 1. Expectation matching

    func testContainsMatches() {
        XCTAssertTrue(
            BASNeuralHeadEvalExpectation.contains("hello")
                .matches(body: "saying hello world"))
        XCTAssertFalse(
            BASNeuralHeadEvalExpectation.contains("hello")
                .matches(body: "saying goodbye"))
    }

    func testDoesNotContainMatches() {
        XCTAssertTrue(
            BASNeuralHeadEvalExpectation.doesNotContain("forbidden")
                .matches(body: "clean response"))
        XCTAssertFalse(
            BASNeuralHeadEvalExpectation.doesNotContain("forbidden")
                .matches(body: "contains forbidden phrase"))
    }

    func testNonEmptyMatches() {
        XCTAssertTrue(
            BASNeuralHeadEvalExpectation.nonEmpty
                .matches(body: "a"))
        XCTAssertFalse(
            BASNeuralHeadEvalExpectation.nonEmpty
                .matches(body: ""))
        XCTAssertFalse(
            BASNeuralHeadEvalExpectation.nonEmpty
                .matches(body: "   \n\t "),
            "whitespace-only body fails nonEmpty")
    }

    // MARK: - 2. Expectation Codable round-trip

    func testExpectationCodableContainsRoundTrips() throws {
        let orig: BASNeuralHeadEvalExpectation = .contains("x")
        let data = try JSONEncoder().encode(orig)
        let decoded = try JSONDecoder().decode(
            BASNeuralHeadEvalExpectation.self, from: data)
        XCTAssertEqual(orig, decoded)
    }

    func testExpectationCodableDoesNotContainRoundTrips() throws {
        let orig: BASNeuralHeadEvalExpectation =
            .doesNotContain("y")
        let data = try JSONEncoder().encode(orig)
        let decoded = try JSONDecoder().decode(
            BASNeuralHeadEvalExpectation.self, from: data)
        XCTAssertEqual(orig, decoded)
    }

    func testExpectationCodableNonEmptyRoundTrips() throws {
        let orig: BASNeuralHeadEvalExpectation = .nonEmpty
        let data = try JSONEncoder().encode(orig)
        let decoded = try JSONDecoder().decode(
            BASNeuralHeadEvalExpectation.self, from: data)
        XCTAssertEqual(orig, decoded)
    }

    // MARK: - 3. Harness runs prompts in order

    func testHarnessRunsPromptsAndPreservesOrder() async throws {
        let adapter = BASOrganDeterministicAdapter()
        let prompts = [
            BASNeuralHeadEvalPrompt(
                promptID: "p.1",
                head: "scout_strip",
                request: makeRequest(
                    id: "r.1", instruction: "hello"),
                expects: .nonEmpty),
            BASNeuralHeadEvalPrompt(
                promptID: "p.2",
                head: "core_cortex",
                request: makeRequest(
                    id: "r.2", instruction: "world",
                    role: .core),
                expects: .contains("CORE")),
            BASNeuralHeadEvalPrompt(
                promptID: "p.3",
                head: "scout_strip",
                request: makeRequest(
                    id: "r.3", instruction: "again"),
                expects: .nonEmpty),
        ]
        let harness = BASNeuralHeadEvalHarness()
        let report = await harness.run(
            prompts: prompts, adapter: adapter)

        XCTAssertEqual(report.outcomes.count, 3)
        XCTAssertEqual(
            report.outcomes.map(\.promptID),
            ["p.1", "p.2", "p.3"],
            "outcomes preserve prompt order")
        XCTAssertTrue(
            report.outcomes.allSatisfy(\.passed),
            "deterministic adapter satisfies all 3 expectations")
        XCTAssertEqual(report.passRate, 1.0, accuracy: 1e-9)
        XCTAssertEqual(report.passCount, 3)
    }

    // MARK: - 4. Per-head pass-rate

    func testPerHeadPassRateAggregation() async throws {
        let adapter = BASOrganDeterministicAdapter()
        let prompts = [
            BASNeuralHeadEvalPrompt(
                promptID: "s.1", head: "scout",
                request: makeRequest(
                    id: "r.1", instruction: "a"),
                expects: .nonEmpty),
            BASNeuralHeadEvalPrompt(
                promptID: "s.2", head: "scout",
                request: makeRequest(
                    id: "r.2", instruction: "b"),
                // This will fail — deterministic body won't
                // contain this canary.
                expects: .contains("<<NEVER-MATCHES>>")),
            BASNeuralHeadEvalPrompt(
                promptID: "c.1", head: "core",
                request: makeRequest(
                    id: "r.3", instruction: "c", role: .core),
                expects: .nonEmpty),
        ]
        let report = await BASNeuralHeadEvalHarness().run(
            prompts: prompts, adapter: adapter)
        let rates = report.passRateByHead()
        XCTAssertEqual(
            rates["scout"] ?? -1, 0.5, accuracy: 1e-9,
            "scout: 1 of 2 passed")
        XCTAssertEqual(
            rates["core"] ?? -1, 1.0, accuracy: 1e-9,
            "core: 1 of 1 passed")
    }

    // MARK: - 5. Adapter throw → outcome failed

    struct ThrowingAdapter: BASOrganAdapter {
        let descriptor = BASOrganDescriptor(
            providerID: "throw.v1",
            providerName: "throwing test adapter",
            supportsStreaming: false,
            maxInputTokens: 1000,
            maxOutputTokens: 100,
            runsOnDevice: true,
            supportedRoles: [.scout, .core])
        func draft(_ request: BASOrganRequest) async throws
            -> BASOrganDraft {
            throw BASOrganError.deadlineExpired
        }
        func currentCapacity() async -> BASOrganCapacity {
            .unlimited
        }
    }

    func testAdapterThrowFailsOutcomeButContinues() async throws {
        let throwing = ThrowingAdapter()
        let prompts = [
            BASNeuralHeadEvalPrompt(
                promptID: "t.1", head: "head.x",
                request: makeRequest(
                    id: "r.1", instruction: "fail this"),
                expects: .nonEmpty),
            BASNeuralHeadEvalPrompt(
                promptID: "t.2", head: "head.x",
                request: makeRequest(
                    id: "r.2", instruction: "fail this too"),
                expects: .nonEmpty),
        ]
        let report = await BASNeuralHeadEvalHarness().run(
            prompts: prompts, adapter: throwing)

        XCTAssertEqual(
            report.outcomes.count, 2,
            "second prompt runs even after first throws")
        XCTAssertFalse(report.outcomes[0].passed)
        XCTAssertNotNil(report.outcomes[0].errorMessage)
        XCTAssertFalse(report.outcomes[1].passed)
        XCTAssertNotNil(report.outcomes[1].errorMessage)
        XCTAssertEqual(report.passRate, 0.0, accuracy: 1e-9)
    }

    // MARK: - 6. Empty prompts → empty report

    func testEmptyPromptsProducesEmptyReport() async throws {
        let adapter = BASOrganDeterministicAdapter()
        let report = await BASNeuralHeadEvalHarness().run(
            prompts: [], adapter: adapter)
        XCTAssertEqual(report.outcomes.count, 0)
        XCTAssertEqual(report.passCount, 0)
        XCTAssertEqual(report.passRate, 0.0, accuracy: 1e-9)
        XCTAssertEqual(report.passRateByHead(), [:])
    }

    // MARK: - 7. Report Codable round-trip

    func testReportCodableRoundTripPreservesOutcomes() throws {
        let outcome = BASNeuralHeadEvalOutcome(
            promptID: "p.rt",
            head: "scout",
            passed: true,
            latencyMs: 12.5,
            body: "ok")
        let report = BASNeuralHeadEvalReport(
            outcomes: [outcome],
            startedAt: Date(timeIntervalSince1970: 1000),
            finishedAt: Date(timeIntervalSince1970: 1001))
        let data = try JSONEncoder().encode(report)
        let decoded = try JSONDecoder().decode(
            BASNeuralHeadEvalReport.self, from: data)
        XCTAssertEqual(decoded, report)
    }
}
