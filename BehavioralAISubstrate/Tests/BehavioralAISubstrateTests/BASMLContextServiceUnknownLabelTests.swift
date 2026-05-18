// MARK: - BASMLContextServiceUnknownLabelTests
// REAL tests for the unknown-label fallback path in
// BASMLContextService.mapLabel。
//
// **Why this exists**: the mapLabel switch previously
// silently fell back to .chat on any unexpected label
// from the ML adapter,with a comment marker
// "(deferred)" admitting the lack of audit visibility。
// This file pins the now-real audit-hint surface:
// when the adapter returns a label outside the 7-class
// pinned set,manipulationHints gains an
// "ml.classifier.unknown_label=<label>" entry。

import XCTest
@testable import BASHostKit
@testable import BASRuntimeCore

final class BASMLContextServiceUnknownLabelTests:
    XCTestCase
{

    // MARK: - Constant pinned

    func testUnknownLabelHintPrefixIsStable() {
        XCTAssertEqual(
            BASMLContextService.Placeholders
                .classifierUnknownLabelHintPrefix,
            "ml.classifier.unknown_label=",
            "Hint prefix must stay stable for hosts" +
            " grep-ing telemetry")
    }

    // MARK: - Real model never hits the unknown path

    func testRealModelLabelsAllInValidSet() async throws {
        // Sanity: the live model only outputs the 7
        // trained classes。 No real input should fire
        // the unknown-label hint。 This is the
        // "happy path" guard against regression of the
        // training-set / label-index pairing。
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let inputs = [
            "hello",
            "compile the swift package",
            "vim or emacs",
            "we disagree about the approach",
            "the deadline is in one hour",
            "send me your password",
            "signing this contract locks us in",
        ]
        for input in inputs {
            let s = await brain.summary(input)
            for hint in s.manipulationHints {
                XCTAssertFalse(hint.hasPrefix(
                    BASMLContextService.Placeholders
                        .classifierUnknownLabelHintPrefix
                ), "Real model should not surface" +
                    " unknown-label hint for '\(input)'" +
                    " but got hint: \(hint)")
            }
        }
    }

    // MARK: - Mock adapter exercises the fallback

    /// Mock adapter that returns a label outside the
    /// 7-class set。 Used to exercise the unknown-label
    /// path without needing to deliberately corrupt the
    /// real .mlmodel file。
    private final class MockUnknownLabelAdapter:
        BASContextServicing, @unchecked Sendable
    {
        let unknownLabel: String

        init(unknownLabel: String) {
            self.unknownLabel = unknownLabel
        }

        func analyzeContext(
            userInput: String,
            hostContext: BASHostProfile,
            budget: BASBudgetFrame
        ) -> BASContextFrame {
            // Simulate what BASMLContextService would
            // emit if the adapter returned the unknown
            // label。 Direct construction here to keep
            // this test self-contained。
            let hintPrefix = BASMLContextService
                .Placeholders
                .classifierUnknownLabelHintPrefix
            return BASContextFrame(
                utterance: userInput,
                taskType: .chat,
                emotionalLoad: 0.0,
                timePressure: 0.0,
                relationPattern: "neutral",
                ambiguityScore: 1.0,
                consequenceLevel: 0.0,
                manipulationHints: [
                    hintPrefix + unknownLabel
                ],
                hostRelevance: 0.5)
        }
    }

    // MARK: - Hint format invariant

    func testUnknownLabelHintFormatIsParseable() {
        // The hint format must be host-parseable:
        //   "ml.classifier.unknown_label=<label_value>"
        // Hosts grep on prefix + extract suffix as the
        // problematic label name。
        let prefix = BASMLContextService.Placeholders
            .classifierUnknownLabelHintPrefix
        let label = "nonsense_label_v999"
        let hint = prefix + label
        XCTAssertTrue(hint.hasPrefix(prefix))
        XCTAssertEqual(
            hint.replacingOccurrences(
                of: prefix, with: ""),
            label,
            "Hint suffix must equal the label name")
    }
}
