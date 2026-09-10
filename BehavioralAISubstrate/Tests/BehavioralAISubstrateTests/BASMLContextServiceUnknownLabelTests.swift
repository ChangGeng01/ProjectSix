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

    // MARK: - Prod mapLabel: the unknown-label branch (REAL)

    // NOTE (2026-07-10 test↔prod re-verify): this file previously
    // defined a `MockUnknownLabelAdapter` that (a) was never
    // instantiated by ANY test — dead code — and (b) even if used,
    // conformed to the wrong seam (BASContextServicing, not the ML
    // adapter) and FABRICATED the hint string directly instead of
    // routing through prod. So the audit-hint branch it claimed to pin
    // had ZERO coverage. Replaced with tests that call the real prod
    // `BASMLContextService.mapLabel` (now internal static) — the exact
    // function whose `default:` case builds the hint.

    func testUnknownLabelMapsToChatWithRealAuditHint() {
        // The prod branch under test: an ML label outside the 7-class
        // set must fall back to .chat AND surface a typed audit hint —
        // NOT silently degrade (the old "deferred" TODO).
        let (taskType, hint) =
            BASMLContextService.mapLabel("nonsense_label_v999")
        XCTAssertEqual(taskType, .chat,
            "unknown label must fall back to .chat")
        XCTAssertEqual(
            hint,
            BASMLContextService.Placeholders
                .classifierUnknownLabelHintPrefix
                + "nonsense_label_v999",
            "unknown label must emit the typed audit hint from prod")
    }

    func testEmptyLabelAlsoSurfacesAuditHint() {
        // Degenerate empty label is still "unknown" — must hint, not
        // silently pass as a valid class.
        let (taskType, hint) = BASMLContextService.mapLabel("")
        XCTAssertEqual(taskType, .chat)
        XCTAssertEqual(
            hint,
            BASMLContextService.Placeholders
                .classifierUnknownLabelHintPrefix)
    }

    func testAllSevenValidLabelsMapWithNoHint() {
        // The 7 pinned classes map to their typed taskType with NO
        // audit hint. Drives the real prod switch, not the model.
        let expected: [(String, BASContextTaskType)] = [
            ("chat", .chat),
            ("task", .task),
            ("choice", .choice),
            ("conflict", .conflict),
            ("highPressure", .highPressure),
            ("manipulationRisk", .manipulationRisk),
            ("highConsequence", .highConsequence),
        ]
        for (label, type) in expected {
            let (mapped, hint) = BASMLContextService.mapLabel(label)
            XCTAssertEqual(mapped, type,
                "valid label '\(label)' must map to \(type)")
            XCTAssertNil(hint,
                "valid label '\(label)' must NOT emit an audit hint")
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
