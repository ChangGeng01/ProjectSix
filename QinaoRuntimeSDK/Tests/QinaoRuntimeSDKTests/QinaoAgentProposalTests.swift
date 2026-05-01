import XCTest
@testable import QinaoSeats

/// 六十四.3 — propose / lease / commit gate tests.
final class QinaoAgentProposalTests: XCTestCase {

    // MARK: - Lease

    func test_leaseConstructionClampsNegatives() {
        let lease = QinaoAgentLease(
            agent: .planner,
            maxMs: -100,
            maxLoops: -2,
            maxWrites: -3,
            scope: [.candidateFrontier])
        XCTAssertEqual(lease.maxMs, 0)
        XCTAssertEqual(lease.maxLoops, 0)
        XCTAssertEqual(lease.maxWrites, 0)
    }

    func test_leaseCodable() throws {
        let lease = QinaoAgentLease(
            agent: .planner,
            maxMs: 120,
            maxLoops: 2,
            maxWrites: 3,
            scope: [
                .candidateFrontier, .projection,
            ])
        let data = try JSONEncoder().encode(lease)
        let decoded = try JSONDecoder().decode(
            QinaoAgentLease.self, from: data)
        XCTAssertEqual(decoded, lease)
    }

    // MARK: - Proposal validation: clean path

    func test_validProposalAcceptable() {
        let proposal = QinaoAgentProposal(
            agent: .planner,
            delta: QinaoAgentDelta(
                target: .candidateFrontier,
                payload: "{}"),
            leaseRef: "lease-x")
        XCTAssertTrue(
            QinaoAgentProposalGate.isAcceptable(
                proposal,
                capability: QinaoSeat.planner
                    .canonicalCapability))
    }

    // MARK: - Proposal validation: writeOutsideDomain

    func test_writeOutsideDomainRejected() {
        // Scout cannot write actionPermit (that's risk's
        // domain).
        let proposal = QinaoAgentProposal(
            agent: .scout,
            delta: QinaoAgentDelta(
                target: .actionPermit,
                payload: "{}"),
            leaseRef: nil)
        let issues =
            QinaoAgentProposalGate.validate(
                proposal,
                capability: QinaoSeat.scout
                    .canonicalCapability)
        XCTAssertTrue(
            issues.contains(
                .writeOutsideDomain(
                    agent: .scout,
                    target: .actionPermit)))
    }

    // MARK: - Proposal validation: lease missing

    func test_leaseMissingRejected() {
        // Planner requires lease.
        let proposal = QinaoAgentProposal(
            agent: .planner,
            delta: QinaoAgentDelta(
                target: .candidateFrontier,
                payload: "{}"),
            leaseRef: nil)
        let issues =
            QinaoAgentProposalGate.validate(
                proposal,
                capability: QinaoSeat.planner
                    .canonicalCapability)
        XCTAssertTrue(
            issues.contains(
                .leaseRequiredButMissing(
                    agent: .planner)))
    }

    // MARK: - Proposal validation: scout doesn't need lease

    func test_scoutDoesNotRequireLease() {
        let proposal = QinaoAgentProposal(
            agent: .scout,
            delta: QinaoAgentDelta(
                target: .situationField,
                payload: "{}"),
            leaseRef: nil)
        // Scout's canonical capability has requiresLease=false.
        XCTAssertTrue(
            QinaoAgentProposalGate.isAcceptable(
                proposal,
                capability: QinaoSeat.scout
                    .canonicalCapability))
    }

    // MARK: - Multiple issues accumulate

    func test_multipleIssuesAccumulate() {
        // Planner writing outside domain + missing lease.
        let proposal = QinaoAgentProposal(
            agent: .planner,
            delta: QinaoAgentDelta(
                target: .actionPermit,
                payload: "{}"),
            leaseRef: nil)
        let issues =
            QinaoAgentProposalGate.validate(
                proposal,
                capability: QinaoSeat.planner
                    .canonicalCapability)
        XCTAssertEqual(issues.count, 2)
    }

    // MARK: - Single Commit Gate

    func test_commitGateRequiresAllThree() {
        // Missing proposalRefs → reject
        XCTAssertFalse(
            QinaoAgentCommitGate.canCommit(
                proposalRefs: [],
                actionPermitRef: "permit-x",
                sovereignWarrantRef: "warrant-x"))

        // Missing actionPermit → reject
        XCTAssertFalse(
            QinaoAgentCommitGate.canCommit(
                proposalRefs: ["p1"],
                actionPermitRef: nil,
                sovereignWarrantRef: "warrant-x"))

        // Missing sovereignWarrant → reject
        XCTAssertFalse(
            QinaoAgentCommitGate.canCommit(
                proposalRefs: ["p1"],
                actionPermitRef: "permit-x",
                sovereignWarrantRef: nil))

        // Empty string also reject
        XCTAssertFalse(
            QinaoAgentCommitGate.canCommit(
                proposalRefs: ["p1"],
                actionPermitRef: "  ",
                sovereignWarrantRef: "warrant-x"))

        // All three present → accept
        XCTAssertTrue(
            QinaoAgentCommitGate.canCommit(
                proposalRefs: ["p1"],
                actionPermitRef: "permit-x",
                sovereignWarrantRef: "warrant-x"))
    }

    // MARK: - Codable round-trip

    func test_proposalCodable() throws {
        let proposal = QinaoAgentProposal(
            agent: .critic,
            delta: QinaoAgentDelta(
                target: .adversarialBrief,
                payload: "test"),
            leaseRef: "lease-1")
        let data = try JSONEncoder().encode(proposal)
        let decoded = try JSONDecoder().decode(
            QinaoAgentProposal.self, from: data)
        XCTAssertEqual(decoded, proposal)
    }

    func test_issueCodable() throws {
        let issues: [QinaoAgentProposalIssue] = [
            .writeOutsideDomain(
                agent: .scout,
                target: .actionPermit),
            .leaseRequiredButMissing(agent: .planner),
        ]
        for issue in issues {
            let data = try JSONEncoder().encode(issue)
            let decoded = try JSONDecoder().decode(
                QinaoAgentProposalIssue.self, from: data)
            XCTAssertEqual(decoded, issue)
        }
    }
}
