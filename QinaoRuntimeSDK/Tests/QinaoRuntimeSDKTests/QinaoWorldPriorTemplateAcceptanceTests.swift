import XCTest
@testable import QinaoWorldPrior

/// M295.0 — template acceptance validator contract tests.
///
/// Doctrine pinned:
/// - Acceptable input → empty issues
/// - templateID without `tmpl-` prefix → templateIDMissingPrefix
/// - `tmpl-` prefix but only one segment → templateIDMalformed
/// - Empty perturb kinds set → noPerturbKindsCovered
/// - Any rung < 0 or > 4 → branchEvidenceRungOutOfRange
/// - Empty description → descriptionEmpty
/// - description < 10 chars → descriptionTooShort
/// - Whitespace-only description → descriptionEmpty
final class QinaoWorldPriorTemplateAcceptanceTests: XCTestCase {

    private func goodInput()
        -> BASWorldPriorTemplateAcceptance.Input
    {
        BASWorldPriorTemplateAcceptance.Input(
            templateID: "tmpl-body-hydration",
            perturbKindsCovered: ["dropPrecondition"],
            branchEvidenceRungs: [2, 1, 1],
            description:
                "Drinking water keeps the body hydrated.")
    }

    // MARK: - Happy path

    func test_acceptableInput_returnsNoIssues() {
        let issues = BASWorldPriorTemplateAcceptance.validate(
            goodInput())
        XCTAssertEqual(issues, [])
        XCTAssertTrue(
            BASWorldPriorTemplateAcceptance
                .isAcceptable(goodInput()))
    }

    // MARK: - Template ID issues

    func test_missingTmplPrefix_flaggedAsMissingPrefix() {
        let input = BASWorldPriorTemplateAcceptance.Input(
            templateID: "body-hydration",
            perturbKindsCovered: ["dropPrecondition"],
            branchEvidenceRungs: [2],
            description: "valid description here")
        let issues = BASWorldPriorTemplateAcceptance.validate(
            input)
        XCTAssertTrue(
            issues.contains(.templateIDMissingPrefix))
        // When prefix missing, malformed not double-reported.
        XCTAssertFalse(
            issues.contains(.templateIDMalformed))
    }

    func test_tmplPrefixButOneSegment_flaggedAsMalformed() {
        let input = BASWorldPriorTemplateAcceptance.Input(
            templateID: "tmpl-foo",
            perturbKindsCovered: ["dropPrecondition"],
            branchEvidenceRungs: [2],
            description: "valid description here")
        let issues = BASWorldPriorTemplateAcceptance.validate(
            input)
        XCTAssertTrue(
            issues.contains(.templateIDMalformed))
    }

    func test_bareTmpl_flaggedAsMalformed() {
        let input = BASWorldPriorTemplateAcceptance.Input(
            templateID: "tmpl-",
            perturbKindsCovered: ["dropPrecondition"],
            branchEvidenceRungs: [2],
            description: "valid description here")
        let issues = BASWorldPriorTemplateAcceptance.validate(
            input)
        XCTAssertTrue(
            issues.contains(.templateIDMalformed))
    }

    // MARK: - Perturb kinds

    func test_emptyPerturbKinds_flagged() {
        let input = BASWorldPriorTemplateAcceptance.Input(
            templateID: "tmpl-body-hydration",
            perturbKindsCovered: [],
            branchEvidenceRungs: [2],
            description: "valid description here")
        let issues = BASWorldPriorTemplateAcceptance.validate(
            input)
        XCTAssertTrue(
            issues.contains(.noPerturbKindsCovered))
    }

    // MARK: - Evidence rungs

    func test_rungAboveFour_flagged() {
        let input = BASWorldPriorTemplateAcceptance.Input(
            templateID: "tmpl-body-hydration",
            perturbKindsCovered: ["dropPrecondition"],
            branchEvidenceRungs: [5],
            description: "valid description here")
        let issues = BASWorldPriorTemplateAcceptance.validate(
            input)
        XCTAssertTrue(
            issues.contains(
                .branchEvidenceRungOutOfRange))
    }

    func test_negativeRung_flagged() {
        let input = BASWorldPriorTemplateAcceptance.Input(
            templateID: "tmpl-body-hydration",
            perturbKindsCovered: ["dropPrecondition"],
            branchEvidenceRungs: [-1, 2],
            description: "valid description here")
        let issues = BASWorldPriorTemplateAcceptance.validate(
            input)
        XCTAssertTrue(
            issues.contains(
                .branchEvidenceRungOutOfRange))
    }

    func test_rungZeroAndFour_areInRange() {
        let input = BASWorldPriorTemplateAcceptance.Input(
            templateID: "tmpl-body-hydration",
            perturbKindsCovered: ["dropPrecondition"],
            branchEvidenceRungs: [0, 4, 2, 1, 3],
            description: "valid description here")
        let issues = BASWorldPriorTemplateAcceptance.validate(
            input)
        XCTAssertFalse(
            issues.contains(
                .branchEvidenceRungOutOfRange))
    }

    // MARK: - Description

    func test_emptyDescription_flagged() {
        let input = BASWorldPriorTemplateAcceptance.Input(
            templateID: "tmpl-body-hydration",
            perturbKindsCovered: ["dropPrecondition"],
            branchEvidenceRungs: [2],
            description: "")
        let issues = BASWorldPriorTemplateAcceptance.validate(
            input)
        XCTAssertTrue(issues.contains(.descriptionEmpty))
        // Don't double-report short.
        XCTAssertFalse(
            issues.contains(.descriptionTooShort))
    }

    func test_whitespaceOnlyDescription_treatedAsEmpty() {
        let input = BASWorldPriorTemplateAcceptance.Input(
            templateID: "tmpl-body-hydration",
            perturbKindsCovered: ["dropPrecondition"],
            branchEvidenceRungs: [2],
            description: "   \n\t  ")
        let issues = BASWorldPriorTemplateAcceptance.validate(
            input)
        XCTAssertTrue(issues.contains(.descriptionEmpty))
    }

    func test_shortDescription_flagged() {
        let input = BASWorldPriorTemplateAcceptance.Input(
            templateID: "tmpl-body-hydration",
            perturbKindsCovered: ["dropPrecondition"],
            branchEvidenceRungs: [2],
            description: "too short")  // 9 chars
        let issues = BASWorldPriorTemplateAcceptance.validate(
            input)
        XCTAssertTrue(
            issues.contains(.descriptionTooShort))
    }

    // MARK: - Multi-issue accumulation

    func test_multipleIssuesAllAccumulate() {
        let input = BASWorldPriorTemplateAcceptance.Input(
            templateID: "bad",
            perturbKindsCovered: [],
            branchEvidenceRungs: [9],
            description: "")
        let issues = BASWorldPriorTemplateAcceptance.validate(
            input)
        XCTAssertTrue(
            issues.contains(.templateIDMissingPrefix))
        XCTAssertTrue(
            issues.contains(.noPerturbKindsCovered))
        XCTAssertTrue(
            issues.contains(
                .branchEvidenceRungOutOfRange))
        XCTAssertTrue(issues.contains(.descriptionEmpty))
        XCTAssertEqual(issues.count, 4)
    }

    // MARK: - M295.0.x batch validator

    func test_batchValidate_emptyBatch_zeroes() {
        let report = BASWorldPriorTemplateAcceptance
            .batchValidate([])
        XCTAssertEqual(report.totalCount, 0)
        XCTAssertEqual(report.acceptableCount, 0)
        XCTAssertEqual(report.issueCounts, [:])
        XCTAssertEqual(report.acceptableFraction, 0)
        XCTAssertNil(report.mostCommonIssue)
    }

    func test_batchValidate_allAcceptable() {
        let inputs = [goodInput(), goodInput()]
        let report = BASWorldPriorTemplateAcceptance
            .batchValidate(inputs)
        XCTAssertEqual(report.totalCount, 2)
        XCTAssertEqual(report.acceptableCount, 2)
        XCTAssertEqual(report.acceptableFraction, 1.0)
        XCTAssertNil(report.mostCommonIssue)
    }

    func test_batchValidate_mixedAcceptableAndBad() {
        let bad1 = BASWorldPriorTemplateAcceptance.Input(
            templateID: "bad",
            perturbKindsCovered: [],
            branchEvidenceRungs: [],
            description: "valid description here")
        let bad2 = BASWorldPriorTemplateAcceptance.Input(
            templateID: "also-bad",
            perturbKindsCovered: [],
            branchEvidenceRungs: [],
            description: "valid description here")
        let report = BASWorldPriorTemplateAcceptance
            .batchValidate([goodInput(), bad1, bad2])
        XCTAssertEqual(report.totalCount, 3)
        XCTAssertEqual(report.acceptableCount, 1)
        XCTAssertEqual(
            report.acceptableFraction, 1.0 / 3.0,
            accuracy: 1e-9)
        // Each bad triggers both templateIDMissingPrefix and
        // noPerturbKindsCovered.
        XCTAssertEqual(
            report.issueCounts[.templateIDMissingPrefix], 2)
        XCTAssertEqual(
            report.issueCounts[.noPerturbKindsCovered], 2)
    }

    func test_mostCommonIssue_picksHighestCount() {
        let oneEmpty = BASWorldPriorTemplateAcceptance.Input(
            templateID: "tmpl-x-y",
            perturbKindsCovered: ["dropPrecondition"],
            branchEvidenceRungs: [2],
            description: "")
        let twoBadIDs = [
            BASWorldPriorTemplateAcceptance.Input(
                templateID: "noprefix-1",
                perturbKindsCovered: ["dropPrecondition"],
                branchEvidenceRungs: [2],
                description: "valid description here"),
            BASWorldPriorTemplateAcceptance.Input(
                templateID: "noprefix-2",
                perturbKindsCovered: ["dropPrecondition"],
                branchEvidenceRungs: [2],
                description: "valid description here"),
        ]
        let report = BASWorldPriorTemplateAcceptance
            .batchValidate([oneEmpty] + twoBadIDs)
        // missingPrefix appears 2x, descriptionEmpty appears 1x.
        XCTAssertEqual(
            report.mostCommonIssue, .templateIDMissingPrefix)
    }

    // MARK: - M295.0.x starter examples

    func test_allStarterExamplesAreAcceptable() {
        for example in BASWorldPriorTemplateAcceptance.Input
            .allStarterExamples
        {
            let issues = BASWorldPriorTemplateAcceptance
                .validate(example)
            XCTAssertEqual(
                issues, [],
                "starter example \(example.templateID) " +
                "must validate clean")
        }
    }

    func test_allStarterExamplesHaveDistinctTemplateIDs() {
        let ids = BASWorldPriorTemplateAcceptance.Input
            .allStarterExamples.map(\.templateID)
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    func test_starterExamplesBatchAllPass() {
        let report = BASWorldPriorTemplateAcceptance
            .batchValidate(
                BASWorldPriorTemplateAcceptance.Input
                    .allStarterExamples)
        XCTAssertEqual(report.acceptableFraction, 1.0)
        XCTAssertEqual(report.totalCount, 5)
        XCTAssertEqual(report.acceptableCount, 5)
    }
}
