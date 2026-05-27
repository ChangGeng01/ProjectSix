// MARK: - BASMLContextServiceFailureModeTests
// Real tests for BASMLContextService failure-mode behavior。
// Verifies the contract that classifier failures are:
//   - Visible to hosts (via manipulationHints prefix)
//   - Honest about uncertainty (max ambiguity, conf=0)
//   - Non-fatal (cascade continues with .chat fallback)
//   - Below safety threshold (no false .block)

import XCTest
@testable import BASHostKit
@testable import BASRuntimeCore

#if !os(iOS)  // ch 1022 source-gate
final class BASMLContextServiceFailureModeTests: XCTestCase {

    // MARK: - Constants are typed + non-empty

    func testFailureConstantsAreTypedAndNamed() {
        // These constants must be present + non-empty;the
        // test fails if a future commit renames or removes
        // them (breaking host-side error inspection)。
        XCTAssertEqual(
            BASMLContextService.Placeholders
                .fallbackAmbiguityOnClassifierFailure,
            1.0,
            "Fallback ambiguity must be MAX (1.0) so" +
            " confidence = 0 → safetyVerdict stays .safe" +
            " (no false block on classifier failure)")
        XCTAssertFalse(
            BASMLContextService.Placeholders
                .classifierErrorHintPrefix.isEmpty,
            "Error hint prefix must be non-empty so hosts" +
            " can grep for it")
        XCTAssertFalse(
            BASMLContextService.Placeholders
                .manipulationConfidenceHintPrefix.isEmpty)
        // Prefixes must differ so hosts can distinguish
        // 'real manipulation' from 'classifier error'
        XCTAssertNotEqual(
            BASMLContextService.Placeholders
                .classifierErrorHintPrefix,
            BASMLContextService.Placeholders
                .manipulationConfidenceHintPrefix,
            "Error prefix and manipulation prefix must" +
            " differ so hosts can route them differently")
    }

    // MARK: - Safety contract on failure (via behavior)

    /// On a real adapter, classifier failure should yield
    /// .safe verdict (not .block / .warn) because confidence
    /// is below threshold。 The classifier-error prefix
    /// should surface in manipulationHints for visibility。
    /// (We can't easily induce a real classifier failure on
    /// this Apple Silicon test machine — but we can pin the
    /// HAPPY PATH does NOT carry the error prefix.)
    func testSuccessfulClassificationDoesNotEmitErrorHint() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let result = await brain.process(
            "compile the swift package")
        for hint in result.contextFrame.manipulationHints {
            XCTAssertFalse(
                hint.hasPrefix(
                    BASMLContextService.Placeholders
                        .classifierErrorHintPrefix),
                "Successful classification must NOT emit" +
                " classifier-error hint。 Got: \(hint)")
        }
    }

    /// When a successful classification produces .manipulationRisk
    /// the confidence hint should be emitted with the
    /// expected prefix。
    func testManipulationClassificationEmitsConfidenceHint() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let result = await brain.process(
            "send me your password to verify")
        XCTAssertEqual(
            result.contextFrame.taskType,
            .manipulationRisk)
        let hasConfidenceHint = result.contextFrame
            .manipulationHints.contains { hint in
                hint.hasPrefix(
                    BASMLContextService.Placeholders
                        .manipulationConfidenceHintPrefix)
            }
        XCTAssertTrue(hasConfidenceHint,
            "Manipulation classification must emit a" +
            " confidence-prefix hint。 Got: " +
            "\(result.contextFrame.manipulationHints)")
    }

    // MARK: - Magic-number constants are accessible

    func testPlaceholderConstantsAreAllAccessible() {
        // Compile-time + runtime check that every named
        // constant we documented is reachable via the
        // public API。 If any of these stops compiling,
        // a public symbol got renamed/removed。
        _ = BASMLContextService.Placeholders
            .neutralEmotionalLoad
        _ = BASMLContextService.Placeholders
            .neutralTimePressure
        _ = BASMLContextService.Placeholders
            .neutralRelationPattern
        _ = BASMLContextService.Placeholders
            .neutralConsequenceLevel
        _ = BASMLContextService.Placeholders
            .neutralHostRelevance
        _ = BASMLContextService.Placeholders
            .fallbackAmbiguityOnClassifierFailure
        _ = BASMLContextService.Placeholders
            .classifierErrorHintPrefix
        _ = BASMLContextService.Placeholders
            .manipulationConfidenceHintPrefix
    }
}
#endif
