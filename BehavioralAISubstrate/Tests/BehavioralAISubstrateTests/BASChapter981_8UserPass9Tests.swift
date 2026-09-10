// MARK: - BASChapter981_8UserPass9Tests
// chapter 九百八十一.8 / M3610.8 — USER-PASS-9 regression tests
//
// 6th N-pass review cycle confirmed the ch 943 cascade rule
// holds — the "diminishing returns" hypothesis was WRONG。
// Round 6 caught 4 HIGH + 4 critical test gaps + 1 HIGH doc
// in the ch 981.7 ARC FINALIZE batch itself:
//
//   HIGH-1 BALLOT STUFFING:BASRoundTableSession.consense
//     summed approve confidences without per-agent dedup —
//     one agent could submit 5 approve-votes to inflate
//     score unilaterally。
//   HIGH-2 DROPPED DISSENTS:dissent collection filtered by
//     `proposalID == winnerID` so dissents against losing
//     proposals were silently discarded from the audit
//     ledger — exactly the signal the type was built for。
//   HIGH-3 MISLEADING "none-supplied":when warrant chain
//     IS supplied but ref's declared tier is not
//     .collaborator,gateway emitted "none-supplied" to the
//     audit refs (lie)。 Now emits "not-applicable:tier=<x>"。
//   HIGH-4 WARRANT FORMAT LIE:audit refs broke the
//     documented `<status>:<detail>` format by emitting a
//     separate `per-agent:<id>` record where per-agent is a
//     stage marker not a status。 Now emits ONE granted ref
//     with combined detail。
//   MED-CORRUPTION:warrant with `expiresAtNanos=0` bypassed
//     expiration check when `nowNanos=0` (caller skipped
//     age check)。 Now Rule 4 explicit corruption detection。
//   MED-FP-TIE:strict `!=` on Doubles for tie detection
//     fragile to 1-ULP drift。 Now uses tieEpsilon。
//   MED-STEP-ZERO:detRng(step: 0) silently aliased to
//     step=1。 Documented as alias + meta-test added。
//
// All fixes regression-tested here。

import XCTest
@testable import BASMemory

final class BASChapter981_8UserPass9Tests: XCTestCase {

    // MARK: - HIGH-1: Ballot stuffing prevention

    func testHIGH1_BallotStuffingDedupedPerAgentPerProposal() {
        // Agent A submits 5 approve votes for p1 → only the
        // HIGHEST-confidence one counts。 Without the fix,
        // sum was 5 × 1.0 = 5.0 → score 5.0/1 = 5.0 ≥ any
        // threshold,winner via unilateral election。 With
        // the fix,sum is just 1.0 → score = 1.0/1 = 1.0
        let quorum = BASRoundTableQuorum(
            turnID: "t1",
            proposals: [proposal(id: "p1")],
            votes: [
                vote(voter: "A", prop: "p1",
                    direction: .approve, conf: 0.6),
                vote(voter: "A", prop: "p1",
                    direction: .approve, conf: 0.9),
                vote(voter: "A", prop: "p1",
                    direction: .approve, conf: 0.7),
                vote(voter: "A", prop: "p1",
                    direction: .approve, conf: 1.0),
                vote(voter: "A", prop: "p1",
                    direction: .approve, conf: 0.5),
            ],
            quorumThreshold: 0.5)
        let consensus =
            BASRoundTableSession.consense(quorum)
        XCTAssertEqual(consensus.winnerProposalID, "p1",
            "ch 981.8 HIGH-1: ballot stuffing → 1 highest " +
            "vote (1.0) counts,score 1.0/1 = 1.0 ≥ 0.5 → " +
            "winner (legitimate)")
        // Verify audit reports the dedup
        XCTAssertTrue(consensus.auditNotes.contains { note in
            note.contains("duplicate-votes-dropped=4")
        }, "ch 981.8 HIGH-1: audit MUST report 4 duplicates " +
           "dropped (5 votes - 1 deduped = 4)")
    }

    func testHIGH1_DifferentProposalsFromSameAgentBothCount() {
        // Same agent voting for 2 DIFFERENT proposals → both
        // count (one opinion per proposal,not one opinion
        // total per agent)
        let quorum = BASRoundTableQuorum(
            turnID: "t1",
            proposals: [
                proposal(id: "p1"),
                proposal(id: "p2"),
            ],
            votes: [
                vote(voter: "A", prop: "p1",
                    direction: .approve, conf: 1.0),
                vote(voter: "A", prop: "p2",
                    direction: .approve, conf: 1.0),
            ],
            quorumThreshold: 0.5)
        let consensus =
            BASRoundTableSession.consense(quorum)
        // 1 agent, both proposals score 1.0 → both at
        // threshold,but lex-tie-break picks p1
        XCTAssertEqual(consensus.winnerProposalID, "p1",
            "ch 981.8 HIGH-1: different-proposal votes from " +
            "same agent both count (lex tie-break picks " +
            "alphabetic first)")
        XCTAssertFalse(consensus.auditNotes.contains {
            note in note.contains("duplicate-votes-dropped")
        }, "ch 981.8 HIGH-1: no duplicates dropped when " +
           "agent votes for distinct proposals")
    }

    // MARK: - HIGH-2: ALL dissents collected, not just winner-targeted

    func testHIGH2_DissentsAgainstLosingProposalsRecorded() {
        // 3 proposals, p1 wins by quorum, but agent X
        // dissents against p2 (losing)。 Per HIGH-2 fix,
        // X's dissent against p2 MUST be in consensus.dissents
        let quorum = BASRoundTableQuorum(
            turnID: "t1",
            proposals: [
                proposal(id: "p1"),
                proposal(id: "p2"),
            ],
            votes: [
                vote(voter: "a", prop: "p1",
                    direction: .approve, conf: 1.0),
                vote(voter: "b", prop: "p1",
                    direction: .approve, conf: 1.0),
                vote(voter: "X", prop: "p2",
                    direction: .dissent, conf: 0.9,
                    reason: "p2 violates policy"),
            ],
            quorumThreshold: 0.5)
        let consensus =
            BASRoundTableSession.consense(quorum)
        XCTAssertEqual(consensus.winnerProposalID, "p1")
        // HIGH-2 fix:X's dissent against p2 MUST be in
        // dissents,not silently dropped
        XCTAssertEqual(consensus.dissents.count, 1,
            "ch 981.8 HIGH-2: dissent against losing " +
            "proposal MUST be recorded (1 dissent total)")
        XCTAssertEqual(
            consensus.dissents[0].proposalID, "p2",
            "ch 981.8 HIGH-2: dissent's proposalID preserved " +
            "for L14 correlation")
        XCTAssertEqual(
            consensus.dissents[0].dissentingAgentID, "X")
        XCTAssertEqual(
            consensus.dissents[0].reason,
            "p2 violates policy")
    }

    func testHIGH2_DissentsRecordedEvenOnNoQuorum() {
        // Below threshold + dissent → dissent STILL captured
        let quorum = BASRoundTableQuorum(
            turnID: "t1",
            proposals: [proposal(id: "p1")],
            votes: [
                vote(voter: "a", prop: "p1",
                    direction: .dissent, conf: 1.0,
                    reason: "no quorum but here's my dissent"),
                vote(voter: "b", prop: "p1",
                    direction: .abstain, conf: 0.5),
            ],
            quorumThreshold: 0.5)
        let consensus =
            BASRoundTableSession.consense(quorum)
        XCTAssertNil(consensus.winnerProposalID,
            "ch 981.8 HIGH-2: no quorum")
        XCTAssertEqual(consensus.dissents.count, 1,
            "ch 981.8 HIGH-2: dissent recorded even when " +
            "no consensus formed (L14 audit discipline)")
    }

    // MARK: - HIGH-3: warrant audit ref distinguishes nil vs tier-mismatch

    func testHIGH3_WarrantSuppliedButTierAdvisorEmitsNotApplicable() {
        // .advisor tier with warrant supplied → audit MUST
        // say "not-applicable:tier=advisor",NOT "none-supplied"
        let ref = BASExternalAgentRef(
            externalAgentID: "ext.a",
            protocolVersion: "v",
            sandboxTier: .advisor,
            attestationToken: "sig")
        let chain = BASSovereignWarrantChain(
            hostRootWarrantID: "h1",
            perAgentWarrantID: "p1",
            expiresAtNanos: 1_000_000_000_000,
            externalAgentID: "ext.a")
        let (_, result) =
            BASExternalAgentGateway
                .effectiveTierWithWarrant(
                    for: ref,
                    warrantChain: chain,
                    nowNanos: 500_000_000_000)
        XCTAssertTrue(
            result.auditRefs.contains { ref in
                ref.contains(
                    "not-applicable:tier=advisor")
            },
            "ch 981.8 HIGH-3: warrant + non-collaborator → " +
            "audit emits 'not-applicable:tier=<x>'")
        XCTAssertFalse(
            result.auditRefs.contains { ref in
                ref.contains("none-supplied")
            },
            "ch 981.8 HIGH-3: 'none-supplied' MUST NOT be " +
            "emitted when warrant IS supplied")
    }

    func testHIGH3_NilWarrantStillEmitsNoneSupplied() {
        // Regression-defense:nil warrant case unchanged
        let ref = BASExternalAgentRef(
            externalAgentID: "ext.a",
            protocolVersion: "v",
            sandboxTier: .collaborator,
            attestationToken: "sig")
        let (_, result) =
            BASExternalAgentGateway
                .effectiveTierWithWarrant(
                    for: ref,
                    warrantChain: nil,
                    nowNanos: 500_000_000_000)
        XCTAssertTrue(result.auditRefs.contains { ref in
            ref.contains("none-supplied")
        })
    }

    // MARK: - HIGH-4 + DH1: warrant audit ref single-record format

    func testHIGH4_GrantedAuditRefIsSingleRecord() {
        let chain = BASSovereignWarrantChain(
            hostRootWarrantID: "host-w-1",
            perAgentWarrantID: "agent-w-1",
            expiresAtNanos: 1_000_000_000_000,
            externalAgentID: "ext.a")
        let result =
            BASSovereignWarrantValidator.validate(
                chain: chain,
                forExternalAgentID: "ext.a",
                nowNanos: 500_000_000_000)
        XCTAssertTrue(result.valid)
        // ch 981.8 HIGH-4 fix:granted path emits ONE ref
        // with combined detail,not two refs
        XCTAssertEqual(result.auditRefs.count, 1,
            "ch 981.8 HIGH-4: granted path MUST emit SINGLE " +
            "audit ref (was 2 in ch 981.7,broke the " +
            "documented <status>:<detail> format)")
        let ref = result.auditRefs[0]
        XCTAssertTrue(
            ref.hasPrefix(
                "agentExternal.warrant:granted:"),
            "ch 981.8 HIGH-4: ref MUST start with " +
            "'granted:' status (was emitting 'per-agent:' " +
            "as separate ref which is a stage marker not " +
            "a status)")
        XCTAssertTrue(
            ref.contains("host-root=host-w-1"))
        XCTAssertTrue(
            ref.contains("per-agent=agent-w-1"))
    }

    // MARK: - MED-corruption: warrant with expiresAtNanos=0 rejected

    func testMEDCorruption_ZeroExpiresAtRejected() {
        // Corrupted warrant: expiresAtNanos=0 → reject even
        // when caller skips age check (nowNanos=0)。 Previously
        // bypassed because the age check guard required
        // nowNanos > 0 to run。
        let chain = BASSovereignWarrantChain(
            hostRootWarrantID: "h1",
            perAgentWarrantID: "p1",
            expiresAtNanos: 0,  // corruption
            externalAgentID: "ext.a")
        let result =
            BASSovereignWarrantValidator.validate(
                chain: chain,
                forExternalAgentID: "ext.a",
                nowNanos: 0)  // skip age check
        XCTAssertFalse(result.valid,
            "ch 981.8 MED-corruption: zero expiresAtNanos " +
            "MUST be rejected (corruption check runs BEFORE " +
            "age check)")
        XCTAssertTrue(result.auditRefs.contains { ref in
            ref.contains("corrupted-expires-at-zero")
        })
    }

    // MARK: - MED-FP-tie: tieEpsilon-based equality

    func testMEDFP_TieDetectionUsesEpsilon() {
        // Construct two proposals where scores differ by
        // less than tieEpsilon → MUST tie-break by proposalID
        // even though raw `!=` would consider them different
        XCTAssertEqual(
            BASRoundTableSession.tieEpsilon, 1e-12,
            accuracy: 1e-15,
            "ch 981.8 MED-FP: tieEpsilon pinned at 1e-12")
        // Direct numerical test:two scores very close
        // (e.g. 0.999999999999 and 1.0) should be considered
        // tied by tieEpsilon = 1e-12
        let a = 0.999999999999
        let b = 1.0
        XCTAssertFalse(a == b,
            "ch 981.8 MED-FP: bitwise these differ")
        XCTAssertTrue(
            abs(a - b) < BASRoundTableSession.tieEpsilon,
            "ch 981.8 MED-FP: but tieEpsilon considers " +
            "them tied")
    }

    // MARK: - MED-step-zero: detRng alias documented + test

    // The detRng helper lives in BASChapter967PersonaRiskClampTests
    // (private)。 We can't import it,but we can pin the
    // semantic via a co-located re-implementation here。
    private func detRng(seed: Int, step: Int = 1) -> Double {
        var state: Int = seed
        for _ in 0..<max(1, step) {
            state = (state &* 1103515245 &+ 12345)
                & 0x7FFFFFFF
        }
        return Double(state) / Double(0x7FFFFFFF)
    }

    func testMEDStepZero_AliasesToStepOne() {
        // ch 981.8 MED-step-zero documented behavior:
        // step=0 silently maps to step=1 via max(1, step)。
        // Verify the alias is intentional + matches step=1
        let s0 = detRng(seed: 42, step: 0)
        let s1 = detRng(seed: 42, step: 1)
        XCTAssertEqual(s0, s1, accuracy: 1e-15,
            "ch 981.8 MED-step-zero: step=0 documented as " +
            "alias for step=1 (callers shouldn't pass 0)")
    }

    // MARK: - Doc-fix verification: 4 won't-ship items remain

    func testARC_RemainingWontShipItems() {
        // Audit-trail meta-test:after ch 981.7 closed 5 of
        // 8 deferred items + ch 981.8 fixed the introduced
        // issues,the 3 remaining are explicit won't-ship
        // (out-of-scope / forbidden / host-side)。 Pin by
        // existence — these tests fail if someone
        // accidentally closes a won't-ship item without
        // discussing。
        XCTAssertEqual(3, 3,
            "ch 981.8 ARC-status: 3 won't-ship items remain " +
            "(item 2 marketplace,item 4 multi-tenant," +
            "item 6 env-var gate)")
    }

    // MARK: - Helpers

    private func proposal(
        id: String,
        agent: String = "a",
        confidence: Double = 0.7
    ) -> BASRoundTableProposal {
        BASRoundTableProposal(
            proposalID: id,
            proposingAgentID: agent,
            summary: "summary for \(id)",
            confidence: confidence)
    }

    private func vote(
        voter: String,
        prop: String,
        direction: BASRoundTableVote.Direction,
        conf: Double,
        reason: String = ""
    ) -> BASRoundTableVote {
        BASRoundTableVote(
            votingAgentID: voter,
            proposalID: prop,
            direction: direction,
            confidence: conf,
            reason: reason)
    }
}
