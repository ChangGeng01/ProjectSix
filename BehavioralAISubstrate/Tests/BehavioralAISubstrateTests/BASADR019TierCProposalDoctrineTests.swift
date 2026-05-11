// MARK: - BASADR019TierCProposalDoctrineTests
// chapter 四百九十七 / M1365 — ADR-019 typed proposal tests

import XCTest
@testable import BASRuntimeCore

final class BASADR019TierCProposalDoctrineTests:
    XCTestCase
{

    // MARK: - 1) Proposal status pinned

    func testProposalStatusIsProposalOnly() {
        XCTAssertEqual(
            BASADR019TierCProposalDoctrine
                .proposalStatus,
            "proposal-only",
            "Chapter 497 close-out:proposal MUST be" +
            " status 'proposal-only' until explicit user" +
            " approval shifts it to 'approved'")
    }

    // MARK: - 2) Approval flag is FALSE

    func testIsApprovedForImplementationIsFalse() {
        XCTAssertFalse(
            BASADR019TierCProposalDoctrine
                .isApprovedForImplementation,
            "Implementation work BLOCKED until user" +
            " approval — flag is false at chapter 497")
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

    // MARK: - 8) Honest summary mentions proposal-only

    func testHonestSummaryMentionsProposalOnly() {
        XCTAssertTrue(
            BASADR019TierCProposalDoctrine.honestSummary
                .contains("proposal-only"))
        XCTAssertTrue(
            BASADR019TierCProposalDoctrine.honestSummary
                .contains("REQUIRES user approval"))
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
