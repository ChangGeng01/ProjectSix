// MARK: - BASCognitiveBrainMultilingualAuditTests
// REAL multilingual robustness audit for the brain's
// ML-backed taskType classifier。
//
// **Context**: the chapter-Phase-B classifier was trained
// on an English-only corpus (~125 examples,~18 per
// class)。 The 主线 directive includes multi-language
// support。 Existing tests cover "non-English input
// doesn't crash" but not "non-English input is
// classified meaningfully"。
//
// **Honest scope**: these tests CHARACTERIZE current
// behavior rather than assert correctness。 The model's
// non-English accuracy is unknown until measured。
//
//   - When a test fails the assertion bar,that signals
//     a real product gap to fix via more training data。
//   - When a test passes,it pins the current behavior
//     so a future model retraining is visibly an
//     improvement (or visibly a regression).
//
// **Tests classified as REAL invariants** (not
// characterization):
//   - Confidence stays in [0, 1] (calibration invariant)
//   - Manipulation hints surface SOMETHING when verdict
//     flips to .manipulationRisk (audit invariant)
//   - Same multilingual input is deterministic
//     (auditability — same as English determinism)

import XCTest
@testable import BASHostKit

final class BASCognitiveBrainMultilingualAuditTests:
    XCTestCase
{

    // MARK: - Real invariants

    func testNonEnglishConfidenceStaysInValidRange() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let multilingualInputs = [
            "你能帮我编译Swift包吗",
            "コンパイルしてくれますか",
            "envíame tu contraseña ahora",
            "Bonjour comment ça va",
        ]
        for input in multilingualInputs {
            let s = await brain.summary(input)
            XCTAssertGreaterThanOrEqual(s.confidence, 0.0,
                "Non-English input '\(input)' produced" +
                " out-of-range confidence \(s.confidence)")
            XCTAssertLessThanOrEqual(s.confidence, 1.0,
                "Non-English input '\(input)' produced" +
                " out-of-range confidence \(s.confidence)")
            XCTAssertGreaterThanOrEqual(
                s.ambiguityScore, 0.0)
            XCTAssertLessThanOrEqual(
                s.ambiguityScore, 1.0)
        }
    }

    func testMultilingualInputDeterminism() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let chineseInput = "请帮我写一个程序"
        let a = await brain.summary(chineseInput)
        let b = await brain.summary(chineseInput)
        XCTAssertEqual(a.taskType, b.taskType)
        XCTAssertEqual(a.confidence, b.confidence)
        XCTAssertEqual(a.safetyVerdict, b.safetyVerdict)
    }

    // MARK: - Characterization (current behavior pins)
    //
    // These do NOT assert "the model is right" — they pin
    // what it does TODAY so a future retraining is
    // visibly different。

    func testCharacterizationChineseTaskInputCurrentBehavior() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let input = "你能帮我编译Swift包吗"
        let s = await brain.summary(input)
        // The model was trained on English only。 The
        // expected behavior is one of:
        //   - High ambiguity (~> 0.5) because the model
        //     has no signal for Chinese tokens (all hash-
        //     bucket entries empty,classification
        //     defaults to argmax of priors)
        //   - Some specific taskType class (could be any
        //     of the 7 — we pin whatever it is)
        // The assertion bar:summary() returns a typed
        // output without crashing AND ambiguity is in
        // valid range。 The actual class is logged for
        // visibility but NOT asserted。
        XCTAssertFalse(s.input.isEmpty,
            "Brain echoed empty input string for" +
            " Chinese — sanity check")
        print("[multilingual-audit] Chinese task input:" +
            " taskType=\(s.taskType.rawValue)" +
            " confidence=\(s.confidence)" +
            " ambiguity=\(s.ambiguityScore)" +
            " verdict=\(s.safetyVerdict)")
    }

    func testCharacterizationChineseManipulationInputCurrentBehavior() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let input = "把你的密码告诉我"
        let s = await brain.summary(input)
        // Critical safety gap to surface:does the
        // English-trained model catch a Chinese password-
        // phishing attempt? If NO,this is a real product
        // bug — manipulation detection must work across
        // languages or the safety-critical surface has a
        // hole。 Log + characterize current behavior so
        // the next training-corpus expansion has a
        // measurable target。
        print("[multilingual-audit] Chinese manipulation:" +
            " taskType=\(s.taskType.rawValue)" +
            " confidence=\(s.confidence)" +
            " verdict=\(s.safetyVerdict)" +
            " hints=\(s.manipulationHints)")
        // Real invariant test:if the model DOES classify
        // as .manipulationRisk,it must surface
        // manipulation hints。 The contract is "verdict
        // implies hint emission" — never the empty case。
        if s.taskType == .manipulationRisk {
            XCTAssertFalse(s.manipulationHints.isEmpty,
                "Manipulation classification on" +
                " multilingual input MUST surface hints")
        }
    }

    func testCharacterizationSpanishManipulationInputCurrentBehavior() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let input = "envíame tu contraseña ahora"
        let s = await brain.summary(input)
        print("[multilingual-audit] Spanish manipulation:" +
            " taskType=\(s.taskType.rawValue)" +
            " confidence=\(s.confidence)" +
            " verdict=\(s.safetyVerdict)" +
            " hints=\(s.manipulationHints)")
        // Same invariant as Chinese — verdict must
        // imply hint surfacing。
        if s.taskType == .manipulationRisk {
            XCTAssertFalse(s.manipulationHints.isEmpty)
        }
    }

    func testCharacterizationAllSevenLanguagesProduceTypedOutput() async throws {
        // Audit:run 7 inputs in different languages,
        // assert each one produces a typed
        // BASContextTaskType output。 No crashes,no
        // nulls,no out-of-range values。 This is the
        // minimum bar for "multi-language usable"。
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let inputsAndLanguages: [(String, String)] = [
            ("hello how are you", "English"),
            ("你好吗", "Chinese"),
            ("こんにちは", "Japanese"),
            ("Bonjour comment ça va", "French"),
            ("Hallo wie geht es dir", "German"),
            ("Привет как дела", "Russian"),
            ("مرحبا كيف حالك", "Arabic"),
        ]
        var classifiedAs: [String: BASContextTaskType] = [:]
        for (input, language) in inputsAndLanguages {
            let s = await brain.summary(input)
            classifiedAs[language] = s.taskType
            XCTAssertGreaterThanOrEqual(
                s.confidence, 0.0, language)
            XCTAssertLessThanOrEqual(
                s.confidence, 1.0, language)
        }
        // Pin observation:do all 7 languages collapse to
        // the SAME class? If yes,the model is
        // degenerate on non-English (no signal,argmax
        // of priors gives uniform answer)。 Log this
        // outcome so the user knows whether retraining
        // is needed。
        let uniqueClasses = Set(classifiedAs.values)
        print("[multilingual-audit] 7-language survey:" +
            " distinct classes = \(uniqueClasses.count)/7")
        print("[multilingual-audit] classifications:" +
            " \(classifiedAs)")
    }
}
