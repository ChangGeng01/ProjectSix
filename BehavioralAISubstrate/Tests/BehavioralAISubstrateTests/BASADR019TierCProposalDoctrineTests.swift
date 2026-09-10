// MARK: - BASADR019TierCProposalDoctrineTests
// chapter 四百九十七 / M1365 — ADR-019 typed proposal tests

import XCTest
@testable import BASRuntimeCore

final class BASADR019TierCProposalDoctrineTests:
    XCTestCase
{

    // MARK: - 1) Proposal status pinned

    func testProposalStatusIsApproved() {
        XCTAssertEqual(
            BASADR019TierCProposalDoctrine
                .proposalStatus,
            "approved",
            "Chapter 507 / M1405 — user 全面 开发 tier" +
            " abc directive APPROVED proposal for" +
            " implementation;status flipped from" +
            " 'proposal-only' to 'approved'")
    }

    // MARK: - 2) Approval flag is TRUE post-M1405

    func testIsApprovedForImplementationIsTrue() {
        XCTAssertTrue(
            BASADR019TierCProposalDoctrine
                .isApprovedForImplementation,
            "Chapter 507 / M1405 — user approval" +
            " received,implementation work in progress")
    }

    // MARK: - 2a) Approval metadata typed correctly

    func testApprovalMetadataPinned() {
        XCTAssertEqual(
            BASADR019TierCProposalDoctrine
                .approvalChapter,
            "chapter 五百七")
        XCTAssertEqual(
            BASADR019TierCProposalDoctrine
                .approvalMNumber,
            1405)
        XCTAssertEqual(
            BASADR019TierCProposalDoctrine
                .approvalDirective,
            "全面 开发 tier abc")
    }

    // MARK: - 3) Candidate count matches plan

    func testCandidateCountMatchesPlan() {
        XCTAssertEqual(
            BASADR019TierCProposalDoctrine
                .candidateCount,
            4,
            "ADR-019 proposal targets 4 Tier C" +
            " domain-aggregate types (chapter 497" +
            " doctrine pin)")
    }

    // MARK: - 4) Candidates carry typed shape names

    func testAllCandidatesHaveTypedShapeNames() {
        for candidate in
            BASADR019TierCProposalDoctrine.candidates
        {
            XCTAssertFalse(
                candidate.typeName.isEmpty,
                "candidate must have typeName")
            XCTAssertFalse(
                candidate.currentShape.isEmpty,
                "candidate must have currentShape")
            XCTAssertFalse(
                candidate.proposedGenericShape.isEmpty,
                "candidate must have proposedGenericShape")
        }
    }

    // MARK: - 5) All migration risk levels are typed cases

    func testAllRiskLevelsAreTypedCases() {
        for candidate in
            BASADR019TierCProposalDoctrine.candidates
        {
            XCTAssertTrue(
                BASADR019MigrationRiskLevel.allCases
                    .contains(
                        candidate.migrationRiskLevel),
                "candidate \(candidate.typeName) risk" +
                " level must be a typed case")
        }
    }

    // MARK: - 6) totalConstructionSites aggregates

    func testTotalConstructionSitesAggregates() {
        let expected =
            BASADR019TierCProposalDoctrine.candidates
                .reduce(0) {
                    $0 + $1.approxConstructionSites
                }
        XCTAssertEqual(
            BASADR019TierCProposalDoctrine
                .totalConstructionSites,
            expected)
    }

    // MARK: - 7) Risk level enum coverage

    func testRiskLevelEnumHasThreeCases() {
        XCTAssertEqual(
            BASADR019MigrationRiskLevel.allCases.count,
            3)
        XCTAssertTrue(
            BASADR019MigrationRiskLevel.allCases
                .contains(.low))
        XCTAssertTrue(
            BASADR019MigrationRiskLevel.allCases
                .contains(.medium))
        XCTAssertTrue(
            BASADR019MigrationRiskLevel.allCases
                .contains(.high))
    }

    // MARK: - 8) Honest summary reflects approved status

    func testHonestSummaryReflectsApprovedStatus() {
        XCTAssertTrue(
            BASADR019TierCProposalDoctrine.honestSummary
                .contains("approved"))
    }

    // MARK: - 9) Candidate Codable round-trip

    func testCandidateCodableRoundTrip() throws {
        let original = BASADR019TierCCandidate(
            typeName: "BASTest",
            currentShape: "test-shape",
            proposedGenericShape:
                "BASTestFrame<Body>",
            approxConstructionSites: 7,
            migrationRiskLevel: .medium,
            blockerNotes: "test notes")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASADR019TierCCandidate.self, from: data)
        XCTAssertEqual(decoded, original)
    }
}
