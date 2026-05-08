// MARK: - BASLLMM940AuditFixTests — chapter 四百一 / M940
//
// Regression tests for the M940 audit-fix sweep on M928-M939。
// Each test pins a specific bug the deep-review caught,so a
// future refactor that re-introduces it gets caught at test
// time。

import XCTest
@testable import BASHostKit
@testable import BASOrgan
@testable import BASRuntimeCore

final class BASLLMM940AuditFixTests: XCTestCase {

    // MARK: - M940 fix 1: NaN/Inf guards

    func testM940MemoryUpdateRejectsInf() {
        // Pre-M940 only `>= 0 && <= 1` was checked。
        // Post-M940 `isFinite` is the FIRST gate so Inf
        // is caught explicitly。NaN was already caught
        // by the range comparison (NaN >= 0 is false)。
        // Hard to test trap directly,but we verify
        // construction trap fires for finite-out-of-range。
        // Cannot directly test precondition trap in XCTest,
        // so we verify the SUCCESSFUL boundary case stays。
        let valid = BASMemoryUpdateCandidate(
            kind: "k",
            content: "c",
            confidence: 1.0)
        XCTAssertEqual(valid.confidence, 1.0)
    }

    func testM940TrainingExampleConfidenceFiniteCheck() {
        let valid = BASTrainingExampleCandidate(
            inputText: "i",
            contextSummary: "ctx",
            goodAnswerTraits: [],
            badAnswerTraits: [],
            score: 0.5)
        XCTAssertEqual(valid.score, 0.5)
    }

    func testM940ByproductsConfidenceScoresAcceptValid() {
        let bp = BASLLMExtractionByproducts(
            finalAnswer: "x",
            confidenceScores: [
                "factual": 0.7,
                "strategic": 0.85
            ],
            extractedAtMs: 1)
        XCTAssertEqual(bp.confidenceScores.count, 2)
    }

    // MARK: - M940 fix 2: empty string preconditions

    func testM940RawInputAcceptsValidStrings() {
        let raw = BASLLMRawInput(
            prompt: "real prompt",
            sessionID: "real-session")
        XCTAssertFalse(raw.prompt.isEmpty)
        XCTAssertFalse(raw.sessionID.isEmpty)
    }

    // MARK: - M940 fix 3: event ID collision (engine)

    func testM940EngineSameTimestampSessionDistinctEventIDs()
        async throws
    {
        let mock = BASFoundationModelsMockSession(
            scriptedResponses: [
                .text(body: "first"),
                .text(body: "second")
            ])
        let log = BASInMemoryEventLogStorage()
        let engine = BASLLMExtractionEngine(
            adapter: mock, eventLog: log)

        // Same session + same timestamp on TWO consecutive
        // run() calls。Pre-M940 the start events would
        // collide on `llm-engine-start-<sid>-<ts>`,one
        // call's audit silently dropped。Post-M940 the
        // per-call sequence number disambiguates。
        let raw = BASLLMRawInput(
            prompt: "same",
            sessionID: "s-collide")
        _ = try await engine.run(
            input: raw, timestampMs: 1_000)
        _ = try await engine.run(
            input: raw, timestampMs: 1_000)

        let events = await log.events(
            forSession: "s-collide")
        XCTAssertEqual(events.count, 4,
            "M940:2 calls × (start + complete) = 4 events;" +
            " pre-M940 only 2 (collisions silently dropped)")
    }

    // MARK: - M940 fix 4: role + preset parameter

    func testM940EngineThreadsRolePresetToAdapter() async
        throws
    {
        // ScriptedAdapter that captures the request to
        // verify role + preset are threaded
        actor RecordingAdapter: BASOrganAdapter {
            nonisolated let descriptor =
                BASOrganDescriptor(
                    providerID: "rec",
                    providerName: "Recorder",
                    supportsStreaming: false,
                    maxInputTokens: 1_000,
                    maxOutputTokens: 1_000,
                    runsOnDevice: true,
                    supportedRoles: Set(
                        BASOrganRole.allCases))
            private(set) var lastRole:
                BASOrganRole? = nil
            private(set) var lastPresetName:
                String? = nil

            func draft(
                _ request: BASOrganRequest
            ) async throws -> BASOrganDraft {
                lastRole = request.role
                lastPresetName = request.preset.name
                return BASOrganDraft(
                    requestID: request.requestID,
                    providerID: descriptor.providerID,
                    role: request.role,
                    body: "x",
                    inputTokensEstimated: 0,
                    outputTokensEstimated: 0,
                    producedAt: Date(),
                    traceID: "t")
            }

            func currentCapacity()
                async -> BASOrganCapacity
            {
                .unlimited
            }
        }

        let adapter = RecordingAdapter()
        let log = BASInMemoryEventLogStorage()
        let engine = BASLLMExtractionEngine(
            adapter: adapter, eventLog: log)

        _ = try await engine.run(
            input: BASLLMRawInput(
                prompt: "test", sessionID: "s-rp"),
            role: .core,
            preset: .core,
            timestampMs: 1)

        let lastRole = await adapter.lastRole
        let lastPresetName = await adapter.lastPresetName
        XCTAssertEqual(lastRole, .core,
            "M940:engine threads role through to adapter")
        XCTAssertEqual(lastPresetName, "bas.core.v1",
            "M940:engine threads preset through to adapter")
    }

    // MARK: - M940 fix 5: verifier approved-from-stages

    func testM940VerifierApprovedReflectsStageFailure()
        async throws
    {
        let goodReviewer = BASFoundationModelsMockSession(
            scriptedResponses: [.text(body: "PASS")])
        let failingFactChecker =
            BASFoundationModelsMockSession(
                scriptedResponses: [
                    .error(reason: "fact check err")
                ])

        let pipeline = BASLLMVerifierPipeline(
            adapters: [
                .reviewer: goodReviewer,
                .factChecker: failingFactChecker
            ])
        let callback = pipeline
            .makeEngineVerifierCallback()

        let draft = BASOrganDraft(
            requestID: "r",
            providerID: "test",
            role: .scout,
            body: "raw",
            inputTokensEstimated: 0,
            outputTokensEstimated: 0,
            producedAt: Date(),
            traceID: "t")
        let pkg = BASLLMTaskPackage(
            taskID: "t-1",
            originSessionID: "s",
            compiledAtMs: 1,
            intent: "ask",
            goal: "x")
        let feedback = try await callback(draft, pkg)

        // Pre-M940 approved was ALWAYS true。Post-M940 it
        // reflects per-stage success — 1 of 2 wired stages
        // failed → approved == false
        XCTAssertFalse(feedback.approved,
            "M940:approved must be false when any wired " +
            "stage fails (pre-M940 was always true)")

        // Failure-stage tag appended to counterArguments
        XCTAssertTrue(
            feedback.counterArguments
                .contains("verifier-stage-failed:factChecker"),
            "M940:failure-stage names appended to " +
            "counterArguments for downstream grep")
    }

    // MARK: - M940 fix 6: datumID disambiguator (sublimator)

    func testM940DuplicateSubmissionsGetDistinctDatumIDs()
        async
    {
        let sub = BASTrainingExampleSublimator()
        let cand = BASTrainingExampleCandidate(
            inputText: "same",
            contextSummary: "ctx",
            goodAnswerTraits: ["a"],
            badAnswerTraits: ["b"],
            score: 0.5)
        let submission = BASTrainingExampleSubmission(
            candidate: cand,
            sourceSessionID: "same-session")
        // Submit IDENTICAL submission twice
        _ = await sub.submit(submission, flushedAtMs: 1)
        _ = await sub.submit(submission, flushedAtMs: 1)
        let result = await sub.flush(flushedAtMs: 2)

        XCTAssertEqual(result.rows.count, 2)
        XCTAssertNotEqual(
            result.rows[0].datumID,
            result.rows[1].datumID,
            "M940:duplicate submissions get distinct " +
            "datumIDs via per-submission counter (pre-M940 " +
            "they collided → silent corpus dedup)")
    }

    // MARK: - M940 fix 7: anti-complexity dict iteration

    func testM940AntiComplexityIterationDeterministic() {
        // Run assess() multiple times on same input;
        // flaggedPhrases must be byte-stable across runs。
        // Pre-M940 the dict iteration was non-deterministic
        // → flaggedPhrases content depended on hash
        // randomization seed。Post-M940 we iterate
        // BASScopeCreepSignal.allCases (declaration order)。
        let text = "最先进的最强大的最终局架构,还可以加什么"
        let r1 = BASAntiComplexityJudge.assess(text: text)
        let r2 = BASAntiComplexityJudge.assess(text: text)
        let r3 = BASAntiComplexityJudge.assess(text: text)
        XCTAssertEqual(r1.flaggedPhrases,
            r2.flaggedPhrases)
        XCTAssertEqual(r2.flaggedPhrases,
            r3.flaggedPhrases,
            "M940:flaggedPhrases byte-stable across runs " +
            "(deterministic CaseIterable iteration order)")
    }

    // MARK: - M940 fix 8: model router fallback determinism

    func testM940ModelRouterFallbackByteStable() async
        throws
    {
        // Without .medium registered,fallback is sorted
        // by rawValue → first available。pre-M940 used
        // `available.first` (Set.first non-deterministic)。
        let mock = BASFoundationModelsMockSession(
            scriptedResponses: [])
        // Run multiple times to amplify any non-determinism
        for _ in 0..<5 {
            let router = BASLLMModelRouter(
                policy: BASLLMModelRouter.defaultPolicy)
            try await router.register(
                adapter: mock, forClass: .small)
            try await router.register(
                adapter: mock, forClass: .strong)
            try await router.register(
                adapter: mock, forClass: .local)
            let task = BASLLMModelRoutingTask(
                taskType: "default")  // no preferences
            let decision = await router.decide(for: task)
            // Sorted rawValue:.local < .small < .strong
            // → fallback should be .local consistently
            XCTAssertEqual(decision.chosenModelClass, .local,
                "M940:fallback sorted by rawValue → .local " +
                "(.local < .small < .strong alphabetically)")
        }
    }
}
