import XCTest
@testable import BASOrchestration

/// M53 — L6 presence-eye main-chain wiring.
///
/// The M22 per-channel observation primitives (shape covered by
/// `BASPresenceObservationTests`) were originally emitted only by
/// hand-crafted test helpers; the coordinator never produced a
/// bundle at all. These tests pin the main-chain behavior:
///
///   1. `BASPresenceObservationBundle.derive(from:turnID:sessionID:
///      emittedAt:)` emits a bundle whose contents deterministically
///      mirror the context frame's signals (same frame → same bundle
///      byte-for-byte).
///   2. Invariant channels `.task`, `.risk`, `.environment` are
///      always present. `.manipulation` is present iff a trace or
///      hints are attached. `.bodyRhythm` is present iff
///      `max(emotionalLoad, timePressure) > 0.3`.
///   3. Channel payloads (salience / confidence / content) are
///      computed from the frame — no magic constants smuggled in.
///   4. `BASContextFrame.withDerivedPresenceObservationBundle(...)`
///      returns a copy with the bundle attached and leaves every
///      other field untouched.
///   5. The bundle feeds the M32 `.presenceEye` coverage projection.
///   6. Budget stays clamped in [0, 1] under every realistic
///      context frame.
final class BASPresenceObservationDerivationTests: XCTestCase {

    // MARK: - Fixtures

    private let fixedDate = Date(timeIntervalSince1970: 1_000_000)

    /// Minimally-populated context frame. Defaults yield a clean
    /// chat turn with no manipulation signals and low body
    /// pressure, so the derivation emits .task + .risk +
    /// .environment only.
    private func frame(
        taskType: BASContextTaskType = .chat,
        sceneType: BASContextSceneType? = nil,
        emotionalLoad: Double = 0.1,
        timePressure: Double = 0.1,
        ambiguityScore: Double = 0.25,
        consequenceLevel: Double = 0.4,
        manipulationHints: [String] = [],
        manipulationTrace: BASManipulationTrace? = nil,
        consequenceHorizon: BASConsequenceHorizon? = nil
    ) -> BASContextFrame {
        BASContextFrame(
            utterance: "hello",
            taskType: taskType,
            sceneType: sceneType,
            emotionalLoad: emotionalLoad,
            timePressure: timePressure,
            relationPattern: "symmetric",
            ambiguityScore: ambiguityScore,
            consequenceLevel: consequenceLevel,
            manipulationHints: manipulationHints,
            hostRelevance: 0.5,
            consequenceHorizon: consequenceHorizon,
            manipulationTrace: manipulationTrace)
    }

    // MARK: - 1. Emission

    func testDeriveEmitsTaskRiskEnvironmentAlwaysOnCleanFrame() {
        let f = frame()
        let bundle = BASPresenceObservationBundle.derive(
            from: f,
            turnID: "t-1",
            sessionID: "s-1",
            emittedAt: fixedDate)

        let channels = Set(bundle.observations.map { $0.channel })
        XCTAssertTrue(channels.contains(.task))
        XCTAssertTrue(channels.contains(.risk))
        XCTAssertTrue(channels.contains(.environment))
        // Clean frame → no manipulation, no body rhythm.
        XCTAssertFalse(channels.contains(.manipulation))
        XCTAssertFalse(channels.contains(.bodyRhythm))
    }

    func testDeriveEmitsManipulationChannelWhenTracePresent() throws {
        let trace = BASManipulationTrace(
            gaslightPrecursor: true,
            shamePressure: 0.6,
            authorityMask: false,
            timeCoercion: 0.4,
            confidence: 0.8)
        let f = frame(manipulationTrace: trace)
        let bundle = BASPresenceObservationBundle.derive(
            from: f,
            turnID: "t",
            sessionID: "s",
            emittedAt: fixedDate)

        let manip = bundle.observations(for: .manipulation)
        XCTAssertEqual(manip.count, 1)
        let obs = try XCTUnwrap(manip.first)
        // intensity = shame*0.5 + timeCoercion*0.5
        //           = 0.6*0.5 + 0.4*0.5 = 0.5
        XCTAssertEqual(obs.salience, 0.5, accuracy: 1e-9)
        XCTAssertEqual(obs.confidence, 0.8, accuracy: 1e-9)
    }

    func testDeriveEmitsManipulationChannelWhenHintsPresent() throws {
        let f = frame(manipulationHints: ["a", "b", "c"])
        let bundle = BASPresenceObservationBundle.derive(
            from: f,
            turnID: "t",
            sessionID: "s",
            emittedAt: fixedDate)

        let manip = bundle.observations(for: .manipulation)
        XCTAssertEqual(manip.count, 1)
        let obs = try XCTUnwrap(manip.first)
        // salience = min(1, count * 0.2) = 0.6
        XCTAssertEqual(obs.salience, 0.6, accuracy: 1e-9)
        XCTAssertEqual(obs.confidence, 0.5, accuracy: 1e-9)
    }

    func testDeriveEmitsBodyRhythmWhenPressureElevated() throws {
        let hi = frame(emotionalLoad: 0.8, timePressure: 0.2)
        let hiBundle = BASPresenceObservationBundle.derive(
            from: hi,
            turnID: "t",
            sessionID: "s",
            emittedAt: fixedDate)
        let body = hiBundle.observations(for: .bodyRhythm)
        XCTAssertEqual(body.count, 1)
        let obs = try XCTUnwrap(body.first)
        XCTAssertEqual(obs.salience, 0.8, accuracy: 1e-9)
    }

    func testDeriveSkipsBodyRhythmWhenPressureLow() {
        // max(0.3, 0.3) = 0.3 — NOT strictly > 0.3, so skipped.
        let borderline = frame(emotionalLoad: 0.3, timePressure: 0.3)
        let bundle = BASPresenceObservationBundle.derive(
            from: borderline,
            turnID: "t",
            sessionID: "s",
            emittedAt: fixedDate)
        XCTAssertTrue(bundle.observations(for: .bodyRhythm).isEmpty)
    }

    // MARK: - 2. Determinism

    func testDeriveIsDeterministicForSameFrame() {
        let f = frame(
            ambiguityScore: 0.3,
            consequenceLevel: 0.5,
            manipulationHints: ["hint"])
        let a = BASPresenceObservationBundle.derive(
            from: f,
            turnID: "t",
            sessionID: "s",
            emittedAt: fixedDate)
        let b = BASPresenceObservationBundle.derive(
            from: f,
            turnID: "t",
            sessionID: "s",
            emittedAt: fixedDate)
        XCTAssertEqual(a, b)
    }

    // MARK: - 3. Payload fidelity

    func testTaskChannelConfidenceReflectsAmbiguity() throws {
        let f = frame(ambiguityScore: 0.2)
        let bundle = BASPresenceObservationBundle.derive(
            from: f,
            turnID: "t",
            sessionID: "s",
            emittedAt: fixedDate)
        let task = try XCTUnwrap(
            bundle.dominantObservation(for: .task))
        XCTAssertEqual(task.salience, 0.8, accuracy: 1e-9)
        XCTAssertEqual(task.confidence, 0.8, accuracy: 1e-9) // 1 - 0.2
    }

    func testRiskChannelSalienceEqualsConsequenceLevel() throws {
        let f = frame(consequenceLevel: 0.65)
        let bundle = BASPresenceObservationBundle.derive(
            from: f,
            turnID: "t",
            sessionID: "s",
            emittedAt: fixedDate)
        let risk = try XCTUnwrap(
            bundle.dominantObservation(for: .risk))
        XCTAssertEqual(risk.salience, 0.65, accuracy: 1e-9)
        // No horizon → confidence 0.5
        XCTAssertEqual(risk.confidence, 0.5, accuracy: 1e-9)
    }

    func testRiskChannelConfidenceRisesWithResolvedHorizon() throws {
        let horizon = BASConsequenceHorizon(
            impactScope: "personal",
            reversibility: 0.4,
            publicPrivateDomain: "private",
            shortTermRisk: 0.3,
            longTermTrace: 0.2)
        let f = frame(
            consequenceLevel: 0.5,
            consequenceHorizon: horizon)
        let bundle = BASPresenceObservationBundle.derive(
            from: f,
            turnID: "t",
            sessionID: "s",
            emittedAt: fixedDate)
        let risk = try XCTUnwrap(
            bundle.dominantObservation(for: .risk))
        XCTAssertEqual(risk.confidence, 1.0, accuracy: 1e-9)
    }

    func testEnvironmentChannelIsPeripheralAnchor() throws {
        let f = frame(taskType: .task)
        let bundle = BASPresenceObservationBundle.derive(
            from: f,
            turnID: "t",
            sessionID: "s",
            emittedAt: fixedDate)
        let env = try XCTUnwrap(
            bundle.dominantObservation(for: .environment))
        XCTAssertEqual(env.salience, 0.3, accuracy: 1e-9)
        XCTAssertEqual(env.confidence, 0.7, accuracy: 1e-9)
        XCTAssertEqual(env.content, "scene:task")
    }

    // MARK: - 4. Withhelper contract

    func testWithDerivedBundleAttachesBundleOnCopy() {
        let f = frame()
        let enriched = f.withDerivedPresenceObservationBundle(
            turnID: "t-2",
            sessionID: "s-2",
            emittedAt: fixedDate)

        XCTAssertNil(f.presenceObservationBundle)
        XCTAssertNotNil(enriched.presenceObservationBundle)
        XCTAssertEqual(
            enriched.presenceObservationBundle?.turnID, "t-2")
        XCTAssertEqual(
            enriched.presenceObservationBundle?.sessionID, "s-2")
    }

    func testWithDerivedBundlePreservesEveryOtherField() {
        let trace = BASManipulationTrace(
            shamePressure: 0.3,
            timeCoercion: 0.2,
            confidence: 0.6)
        let f = frame(
            taskType: .highConsequence,
            sceneType: .highConsequenceDecision,
            emotionalLoad: 0.5,
            timePressure: 0.4,
            ambiguityScore: 0.3,
            consequenceLevel: 0.9,
            manipulationHints: ["pressure"],
            manipulationTrace: trace)

        let enriched = f.withDerivedPresenceObservationBundle(
            turnID: "t",
            sessionID: "s",
            emittedAt: fixedDate)

        XCTAssertEqual(enriched.taskType, f.taskType)
        XCTAssertEqual(enriched.sceneType, f.sceneType)
        XCTAssertEqual(enriched.emotionalLoad, f.emotionalLoad)
        XCTAssertEqual(enriched.timePressure, f.timePressure)
        XCTAssertEqual(enriched.ambiguityScore, f.ambiguityScore)
        XCTAssertEqual(enriched.consequenceLevel, f.consequenceLevel)
        XCTAssertEqual(enriched.manipulationHints, f.manipulationHints)
        XCTAssertEqual(enriched.manipulationTrace, f.manipulationTrace)
        XCTAssertEqual(enriched.utterance, f.utterance)
    }

    // MARK: - 5. M32 coverage projection integration

    func testBundleFeedsM32PresenceEyeCoverageProjection() {
        let trace = BASManipulationTrace(
            shamePressure: 0.3,
            timeCoercion: 0.3,
            confidence: 0.6)
        let f = frame(
            emotionalLoad: 0.7,
            manipulationTrace: trace)
        let bundle = BASPresenceObservationBundle.derive(
            from: f,
            turnID: "turn-xyz",
            sessionID: "session-xyz",
            emittedAt: fixedDate)

        let summary = bundle.coverageSummary
        XCTAssertEqual(summary.layer, .presenceEye)
        XCTAssertEqual(summary.turnID, "turn-xyz")
        XCTAssertEqual(summary.sessionID, "session-xyz")
        // task + risk + manipulation + environment + bodyRhythm = 5
        XCTAssertEqual(summary.distinctSubjectCount, 5)
        XCTAssertTrue(summary.hasCoreSignalCoverage)
    }

    func testCleanFrameYieldsIncompleteCoreCoverage() {
        // No manipulation trace and no hints → core coverage false.
        let f = frame()
        let bundle = BASPresenceObservationBundle.derive(
            from: f,
            turnID: "t",
            sessionID: "s",
            emittedAt: fixedDate)
        let summary = bundle.coverageSummary
        XCTAssertFalse(summary.hasCoreSignalCoverage)
    }

    // MARK: - 6. Budget clamping

    func testBundleBudgetStaysClampedAcrossAllChannels() {
        let trace = BASManipulationTrace(
            shamePressure: 0.8,
            timeCoercion: 0.8,
            confidence: 0.9)
        let f = frame(
            emotionalLoad: 0.9,
            timePressure: 0.9,
            consequenceLevel: 0.9,
            manipulationTrace: trace)
        let bundle = BASPresenceObservationBundle.derive(
            from: f,
            turnID: "t",
            sessionID: "s",
            emittedAt: fixedDate)

        let cost = BASPresenceObservationBudget.totalCost(for: bundle)
        XCTAssertGreaterThanOrEqual(cost, 0)
        XCTAssertLessThanOrEqual(cost, 1)
    }

    // MARK: - 7. Backwards compatibility

    func testContextFrameNilBundleRoundTripsThroughCodable() throws {
        let f = frame()
        let data = try JSONEncoder().encode(f)
        let decoded = try JSONDecoder().decode(
            BASContextFrame.self, from: data)
        XCTAssertNil(decoded.presenceObservationBundle)
    }

    func testContextFrameWithBundleRoundTripsThroughCodable() throws {
        let enriched = frame()
            .withDerivedPresenceObservationBundle(
                turnID: "rt",
                sessionID: "rt-s",
                emittedAt: fixedDate)

        let data = try JSONEncoder().encode(enriched)
        let decoded = try JSONDecoder().decode(
            BASContextFrame.self, from: data)
        XCTAssertNotNil(decoded.presenceObservationBundle)
        XCTAssertEqual(
            decoded.presenceObservationBundle?.turnID, "rt")
        XCTAssertEqual(
            decoded.presenceObservationBundle?.observations.count,
            enriched.presenceObservationBundle?.observations.count)
    }

    func testLegacyJSONWithoutBundleFieldDecodesWithNilBundle()
        throws
    {
        // Simulates a persisted pre-M53 frame that lacks the new key.
        let legacy = """
        {
          "schemaVersion": "1.1.0",
          "utterance": "hi",
          "taskType": "chat",
          "sceneType": "chat",
          "emotionalLoad": 0.1,
          "timePressure": 0.1,
          "relationPattern": "symmetric",
          "ambiguityScore": 0.2,
          "consequenceLevel": 0.3,
          "manipulationHints": [],
          "hostRelevance": 0.5
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(
            BASContextFrame.self, from: legacy)
        XCTAssertNil(decoded.presenceObservationBundle)
        XCTAssertEqual(decoded.taskType, .chat)
    }
}
