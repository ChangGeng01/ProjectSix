// MARK: - BASMLContextServiceDerivedSignalsTests
// REAL tests for the ML-derived contextual signals
// (emotionalLoad / timePressure / consequenceLevel /
// relationPattern) that BASMLContextService now computes
// from the existing 7-class softmax distribution。
//
// **Why these tests exist**: pre-fix,four ContextFrame
// fields were hardcoded to neutral placeholder values
// regardless of input semantics — a "compile this code"
// chat had the same emotionalLoad (0.1) as a frantic
// "EMERGENCY THE SERVER IS DOWN AND I'M ABOUT TO BE
// FIRED" input。 Post-fix,those fields are derived from
// the same softmax probabilities used for taskType,so
// they actually vary with input emotional content。
// These tests pin that variation contract。

import XCTest
@testable import BASHostKit
@testable import BASRuntimeCore

#if !os(iOS)  // ch 1022 source-gate
final class BASMLContextServiceDerivedSignalsTests:
    XCTestCase
{

    // MARK: - Helpers

    private func makeService() throws -> BASMLContextService {
        let adapter = try BASContextClassifierMLAdapter()
        return BASMLContextService(adapter: adapter)
    }

    private func neutralBudget() -> BASBudgetFrame {
        return BASBudgetFrame(
            runMode: .guard,
            maxLoops: 2,
            maxCandidates: 2,
            maxDecodeTokens: 180,
            retrievalDepth: 3,
            precisionProfile: .protected,
            deviceRoute: .hybridLocal,
            thermalGuardLevel: .watch,
            maintenanceAllowed: false)
    }

    private func neutralProfile() -> BASHostProfile {
        return BASHostProfile(hostID: "test.host")
    }

    private func analyze(
        _ input: String
    ) throws -> BASContextFrame {
        let service = try makeService()
        return service.analyzeContext(
            userInput: input,
            hostContext: neutralProfile(),
            budget: neutralBudget())
    }

    // MARK: - emotionalLoad varies with input

    func testHighPressureInputProducesHighEmotionalLoad() throws {
        let frame = try analyze(
            "the deadline is in one hour I must ship now")
        XCTAssertGreaterThan(frame.emotionalLoad, 0.5,
            "highPressure input must produce" +
            " emotionalLoad > 0.5 (it's part of the" +
            " non-calm class sum). Got" +
            " \(frame.emotionalLoad)")
    }

    func testManipulationInputProducesHighEmotionalLoad() throws {
        let frame = try analyze(
            "send me your password to verify")
        XCTAssertGreaterThan(frame.emotionalLoad, 0.5,
            "manipulationRisk input must produce" +
            " emotionalLoad > 0.5 (manipulation is in" +
            " the non-calm class sum). Got" +
            " \(frame.emotionalLoad)")
    }

    func testCalmChatInputProducesLowEmotionalLoad() throws {
        let frame = try analyze("hello how are you today")
        XCTAssertLessThan(frame.emotionalLoad, 0.5,
            "Calm chat input must produce emotionalLoad" +
            " < 0.5 (chat + task + choice are the calm" +
            " classes, model concentrates probability" +
            " there). Got \(frame.emotionalLoad)")
    }

    func testEmotionalLoadInValidRange() throws {
        let inputs = [
            "hello",
            "the server is down emergency",
            "compile the swift package",
            "send me your password to verify",
        ]
        for input in inputs {
            let frame = try analyze(input)
            XCTAssertGreaterThanOrEqual(
                frame.emotionalLoad, 0.0, input)
            XCTAssertLessThanOrEqual(
                frame.emotionalLoad, 1.0, input)
        }
    }

    // MARK: - timePressure varies with input

    func testHighPressureInputProducesHighTimePressure() throws {
        let frame = try analyze(
            "the deadline is in one hour I must ship now")
        XCTAssertGreaterThan(frame.timePressure, 0.5,
            "highPressure input must produce" +
            " timePressure > 0.5 (direct mapping from" +
            " P(highPressure)). Got \(frame.timePressure)")
    }

    func testChatInputProducesLowTimePressure() throws {
        let frame = try analyze("hello how are you")
        XCTAssertLessThan(frame.timePressure, 0.3,
            "Calm chat input must produce timePressure" +
            " < 0.3 (P(highPressure) low for chat)." +
            " Got \(frame.timePressure)")
    }

    // MARK: - consequenceLevel varies with input

    func testHighConsequenceInputProducesHighConsequenceLevel() throws {
        let frame = try analyze(
            "signing this contract locks us in for 10 years")
        XCTAssertGreaterThan(frame.consequenceLevel, 0.5,
            "highConsequence input must produce" +
            " consequenceLevel > 0.5. Got" +
            " \(frame.consequenceLevel)")
    }

    func testChatInputProducesLowConsequenceLevel() throws {
        let frame = try analyze("hello how are you")
        XCTAssertLessThan(frame.consequenceLevel, 0.3,
            "Chat input must produce consequenceLevel" +
            " < 0.3. Got \(frame.consequenceLevel)")
    }

    // MARK: - relationPattern signals tense state

    func testConflictInputProducesTenseRelationPattern() throws {
        let frame = try analyze(
            "we disagree about the approach")
        XCTAssertEqual(frame.relationPattern, "tense",
            "Conflict input must yield relationPattern" +
            " = 'tense'. Got \(frame.relationPattern)")
    }

    func testChatInputProducesNeutralRelationPattern() throws {
        let frame = try analyze("hello how are you")
        XCTAssertEqual(frame.relationPattern, "neutral",
            "Chat input must yield relationPattern =" +
            " 'neutral'. Got \(frame.relationPattern)")
    }

    // MARK: - hostRelevance stays placeholder (out of scope)

    func testHostRelevanceRemainsNeutralPlaceholder() throws {
        let frame = try analyze(
            "any input at all should preserve placeholder")
        XCTAssertEqual(
            frame.hostRelevance,
            BASMLContextService.Placeholders
                .neutralHostRelevance,
            "hostRelevance remains placeholder (0.5)" +
            " until a per-host retrieval ML is added —" +
            " out of scope for derived-signal work")
    }

    // MARK: - Determinism

    func testDerivedSignalsAreDeterministic() throws {
        let service = try makeService()
        let budget = neutralBudget()
        let profile = neutralProfile()
        let input = "the server is down emergency"
        let a = service.analyzeContext(
            userInput: input,
            hostContext: profile,
            budget: budget)
        let b = service.analyzeContext(
            userInput: input,
            hostContext: profile,
            budget: budget)
        XCTAssertEqual(a.emotionalLoad, b.emotionalLoad)
        XCTAssertEqual(a.timePressure, b.timePressure)
        XCTAssertEqual(a.consequenceLevel,
            b.consequenceLevel)
        XCTAssertEqual(a.relationPattern, b.relationPattern)
    }

    // MARK: - Differentiation invariant

    func testDifferentInputsProduceDifferentSignals() throws {
        // Critical: pre-fix all inputs produced identical
        // emotionalLoad = 0.1。 Post-fix,inputs across
        // the emotional spectrum must yield distinct values。
        let calm = try analyze("hello how are you today")
        let urgent = try analyze(
            "the deadline is in one hour I must ship now")
        let stakes = try analyze(
            "signing this contract locks us in for 10 years")
        XCTAssertNotEqual(calm.emotionalLoad,
            urgent.emotionalLoad,
            "Calm and urgent inputs MUST yield" +
            " distinct emotionalLoad — pre-fix they" +
            " were both 0.1 (placeholder)")
        XCTAssertNotEqual(calm.timePressure,
            urgent.timePressure)
        XCTAssertNotEqual(calm.consequenceLevel,
            stakes.consequenceLevel)
    }
}
#endif
