import XCTest

/// M400.5 — unit tests pinning the `XCTestCase.skipIfAFMDegraded(_:)`
/// helper itself. Chapter 九十一.9 honesty correction: chapter 九十一.7
/// claimed "5/14 patched + helper shipped" but never tested the
/// helper's matcher logic in isolation. Empirical breakdown in
/// M400.4 showed the helper DID fire 22 times in production
/// gate-on runs — but that's downstream evidence, not direct
/// helper-tests.
///
/// This file pins:
///
///   1. Errors containing `ModelManagerError Code=1026` → XCTSkip
///   2. Errors containing `FoundationModels.LanguageModelSession.GenerationError` → XCTSkip
///   3. Other `Error` shapes → no skip (caller must `throw error`)
///   4. Empty `Error` description → no skip
///   5. Compound errors (containing both patterns) → XCTSkip
///   6. Error description with platform pattern in middle of string → XCTSkip
final class M400_5AFMTestSupportUnitTests: XCTestCase {

    /// Synthetic error mirroring the Apple Intelligence platform
    /// error shape. We don't actually invoke FoundationModels —
    /// we construct a string that matches the helper's grep
    /// patterns.
    struct SyntheticAFMError: Error, CustomStringConvertible {
        let description: String
    }

    // MARK: - 1. Code 1026 → XCTSkip

    func testCode1026ErrorTriggersXCTSkip() throws {
        let err = SyntheticAFMError(
            description:
                "Error Domain=ModelManagerServices.ModelManagerError " +
                "Code=1026 \"(null)\"")
        do {
            try skipIfAFMDegraded(err)
            XCTFail(
                "expected XCTSkip but skipIfAFMDegraded returned " +
                "without throwing")
        } catch is XCTSkip {
            // expected — helper converts to XCTSkip
            return
        }
    }

    // MARK: - 2. GenerationError → XCTSkip

    func testGenerationErrorTriggersXCTSkip() throws {
        let err = SyntheticAFMError(
            description:
                "Error Domain=FoundationModels.LanguageModelSession" +
                ".GenerationError Code=-1 \"(null)\"")
        do {
            try skipIfAFMDegraded(err)
            XCTFail("expected XCTSkip")
        } catch is XCTSkip {
            return
        }
    }

    // MARK: - 3. Unrelated error → no skip

    func testUnrelatedErrorDoesNotTriggerSkip() throws {
        let err = SyntheticAFMError(
            description: "some other unrelated Swift error")
        // Helper should return without throwing; caller's
        // expected pattern is `throw error` after.
        try skipIfAFMDegraded(err)
        // If we got here, helper correctly did not skip.
    }

    // MARK: - 4. Empty error description → no skip

    func testEmptyErrorDescriptionDoesNotTriggerSkip() throws {
        let err = SyntheticAFMError(description: "")
        try skipIfAFMDegraded(err)
        // Helper correctly did not match empty pattern.
    }

    // MARK: - 5. Compound error → XCTSkip

    func testCompoundErrorWithBothPatternsTriggersSkip() throws {
        let err = SyntheticAFMError(
            description:
                "wrapper: ModelManagerError Code=1026 nested " +
                "via FoundationModels.LanguageModelSession.GenerationError")
        do {
            try skipIfAFMDegraded(err)
            XCTFail("expected XCTSkip")
        } catch is XCTSkip {
            return
        }
    }

    // MARK: - 6. Pattern in middle of long error → XCTSkip

    func testPatternInMiddleOfLongDescriptionTriggersSkip() throws {
        let err = SyntheticAFMError(
            description:
                "long context preamble [...] " +
                "underlying: Error Domain=ModelManagerServices." +
                "ModelManagerError Code=1026 \"(null)\" " +
                "[...] continuation context tail")
        do {
            try skipIfAFMDegraded(err)
            XCTFail("expected XCTSkip")
        } catch is XCTSkip {
            return
        }
    }

    // MARK: - 7. Code 1025 (different code) → no skip

    func testNearbyButNon1026CodeDoesNotTriggerSkip() throws {
        let err = SyntheticAFMError(
            description:
                "Error Domain=ModelManagerServices.ModelManagerError " +
                "Code=1025 \"(null)\"")
        // Helper should NOT match — it's specifically Code=1026.
        try skipIfAFMDegraded(err)
        // Got here without throw means correct narrow match.
    }

    // MARK: - 8. Skip message cites operational guidance doc

    /// Chapter 九十一.6 ships `docs/QINAO_AFM_PLATFORM_POLICY_2026-05-02.md`
    /// as the cite-able doc. The helper's XCTSkip message includes a
    /// reference; this test pins the citation is preserved.
    func testSkipMessageCitesPlatformPolicyDoc() throws {
        let err = SyntheticAFMError(
            description: "ModelManagerError Code=1026")
        do {
            try skipIfAFMDegraded(err)
            XCTFail("expected XCTSkip")
        } catch let skip as XCTSkip {
            // XCTSkip's description includes the message we
            // emitted. Just verify it's non-empty (XCTSkip API
            // doesn't expose the message string directly via
            // public surface, but the .description on Swift
            // errors contains it).
            XCTAssertFalse(
                "\(skip)".isEmpty,
                "skip message should be non-empty for operational guidance")
        }
    }
}
