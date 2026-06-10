// MARK: - BASChapter981_9UserPass10Tests
// chapter 九百八十一.9 / M3610.9 — USER-PASS-10 round 7 fixes
//
// 7th N-pass review cycle。 Round 7 (USER-PASS-10) found that
// the ch 981.8 USER-PASS-9 fix^10 had introduced NEW bugs:
//
//   C1 — HIGH-4 fix re-introduced format ambiguity it claimed
//        to fix。 `agentExternal.warrant:granted:host-root=<id>:
//        per-agent=<id>` uses `=` + `:` as separators,but
//        warrant IDs contain `:` per the documented format
//        (`host-warrant:<hostID>:<sessionID>:<expires>`)。 An
//        L14 parser splitting on `:` cannot unambiguously
//        locate the per-agent boundary。
//   H1 — Round-table dedup key collision via `|`。 Key was
//        `"\(agent)|\(proposal)"` string concat。 agentID="A|B"
//        + proposalID="C" collides with agentID="A" +
//        proposalID="B|C" — both produce key "A|B|C"。 Two
//        legitimate distinct (agent,proposal) pairs silently
//        deduped → ballot stuffing via ID collision instead of
//        repeat voting。
//   MED2 — Warrant corruption check ordered AFTER identity
//        check。 Defense-in-depth says most-fundamental defect
//        first;identity-mismatch hides corruption signal。
//
// Plus the ch 981.7 seat migration for ARC FINALIZE item 8 —
// 9 seats now delegate to BASAgentFabricJSONEscape。 Pins
// byte-equal output verification。

import XCTest
@testable import BASMemory

final class BASChapter981_9UserPass10Tests: XCTestCase {

    // MARK: - C1 regression: warrant audit ref uses control-char separator

    func testC1_WarrantAuditRefUsesUnitSeparator() {
        let chain = BASSovereignWarrantChain(
            hostRootWarrantID:
                "host-warrant:hostA:sess1:9999",
            perAgentWarrantID:
                "per-agent:extA:scope1",
            expiresAtNanos: 1_000_000_000_000,
            externalAgentID: "ext.a")
        let result =
            BASSovereignWarrantValidator.validate(
                chain: chain,
                forExternalAgentID: "ext.a",
                nowNanos: 500_000_000_000)
        XCTAssertTrue(result.valid)
        XCTAssertEqual(result.auditRefs.count, 1)
        let ref = result.auditRefs[0]
        // Verify the U+001F unit separator is between
        // host-root=... and per-agent=... so the L14 parser
        // can split unambiguously even when warrant IDs
        // contain `:`
        XCTAssertTrue(
            ref.contains("\u{001F}per-agent="),
            "ch 981.9 C1: audit ref MUST use U+001F unit " +
            "separator between fields (defends against `:` " +
            "in warrant IDs)")
        XCTAssertTrue(
            ref.hasPrefix(
                "agentExternal.warrant:granted:host-root="),
            "ch 981.9 C1: prefix unchanged")
        // The full ref splits cleanly on \u{001F} into:
        //   [0] = agentExternal.warrant:granted:host-root=host-warrant:hostA:sess1:9999
        //   [1] = per-agent=per-agent:extA:scope1
        let parts = ref.split(separator: "\u{001F}")
        XCTAssertEqual(parts.count, 2,
            "ch 981.9 C1: splits on U+001F into exactly 2 " +
            "parts regardless of `:` content in IDs")
    }

    func testC1_AuditRefSurvivesColonsInIDs() {
        // Stress test:both IDs are heavy with `:` characters
        let chain = BASSovereignWarrantChain(
            hostRootWarrantID:
                "host:warrant:nested:colon:hell",
            perAgentWarrantID:
                "per:agent:also:colon:heavy",
            expiresAtNanos: 1_000_000_000_000,
            externalAgentID: "ext.a")
        let result =
            BASSovereignWarrantValidator.validate(
                chain: chain,
                forExternalAgentID: "ext.a",
                nowNanos: 500_000_000_000)
        XCTAssertTrue(result.valid)
        // L14 parser can recover both IDs verbatim
        let ref = result.auditRefs[0]
        let parts = ref.split(separator: "\u{001F}")
        XCTAssertTrue(
            String(parts[0]).hasSuffix(
                "host-root=host:warrant:nested:colon:hell"))
        XCTAssertTrue(
            String(parts[1]).hasPrefix(
                "per-agent=per:agent:also:colon:heavy"))
    }

    // MARK: - H1 regression: round-table struct-key prevents collision

    func testH1_RoundTableStructKeyPreventsCollision() {
        // The collision attack:agentID="A|B" + proposalID="C"
        // vs agentID="A" + proposalID="B|C"。 With the old
        // string-concat key,both hash to "A|B|C" → second
        // vote silently overrode first。 With struct key,
        // they're distinct。
        let quorum = BASRoundTableQuorum(
            turnID: "t1",
            proposals: [
                BASRoundTableProposal(
                    proposalID: "C",
                    proposingAgentID: "x",
                    summary: "C",
                    confidence: 0.7),
                BASRoundTableProposal(
                    proposalID: "B|C",
                    proposingAgentID: "y",
                    summary: "B|C",
                    confidence: 0.7),
            ],
            votes: [
                BASRoundTableVote(
                    votingAgentID: "A|B",
                    proposalID: "C",
                    direction: .approve,
                    confidence: 0.9),
                BASRoundTableVote(
                    votingAgentID: "A",
                    proposalID: "B|C",
                    direction: .approve,
                    confidence: 0.9),
            ],
            quorumThreshold: 0.5)
        let consensus =
            BASRoundTableSession.consense(quorum)
        // 2 distinct (agent, proposal) pairs → no dedup
        // collision。 Without H1 fix,one vote would have been
        // silently dropped。
        XCTAssertFalse(consensus.auditNotes.contains {
            $0.contains("duplicate-votes-dropped")
        }, "ch 981.9 H1: 2 distinct (agent,proposal) pairs " +
           "with `|` in IDs MUST NOT collide (struct key " +
           "prevents the ambiguity)")
        // Both proposals score 0.9/2 = 0.45 < 0.5 → no winner
        // (verifies both votes counted equally,no silent loss)
        XCTAssertNil(consensus.winnerProposalID,
            "ch 981.9 H1: with both votes counted equally,no " +
            "proposal reaches threshold → no winner (verifies " +
            "the dedup did NOT drop either vote)")
    }

    // MARK: - MED2 regression: corruption check before identity

    func testMED2_CorruptionCheckBeforeIdentityCheck() {
        // Corrupted warrant (expiresAtNanos=0) + identity
        // mismatch (wrong externalAgentID)。 Both Rule 3
        // (corruption) and Rule 4 (identity) would fail。 Per
        // defense-in-depth,corruption is more fundamental
        // so should surface FIRST。
        let chain = BASSovereignWarrantChain(
            hostRootWarrantID: "h1",
            perAgentWarrantID: "p1",
            expiresAtNanos: 0,  // corruption
            externalAgentID: "ext.A")  // identity-mismatch later
        let result =
            BASSovereignWarrantValidator.validate(
                chain: chain,
                forExternalAgentID: "ext.B",  // mismatch
                nowNanos: 500_000_000_000)
        XCTAssertFalse(result.valid)
        XCTAssertTrue(
            result.auditRefs.contains { ref in
                ref.contains("corrupted-expires-at-zero")
            },
            "ch 981.9 MED2: corruption surfaces FIRST (defense " +
            "in depth — most-fundamental defect)")
        XCTAssertFalse(
            result.auditRefs.contains { ref in
                ref.contains("identity-mismatch")
            },
            "ch 981.9 MED2: when corruption fires first,we " +
            "short-circuit and don't reach identity check")
    }

    // MARK: - Seat migration: byte-equal escape across all 9 seats

    func testARC_Item8_SeatsMigratedToSharedHelper() {
        // Verify the shared helper exists + produces the
        // expected escape for all 5 special characters。
        XCTAssertEqual(
            BASAgentFabricJSONEscape.escape("a\"b"),
            "a\\\"b",
            "ch 981.9 ARC item 8: shared helper handles " +
            "double-quote escape (same as the 9 migrated " +
            "seats expect)")
        XCTAssertEqual(
            BASAgentFabricJSONEscape.escape("a\\b"),
            "a\\\\b")
        XCTAssertEqual(
            BASAgentFabricJSONEscape.escape("a\nb"),
            "a\\nb")
        XCTAssertEqual(
            BASAgentFabricJSONEscape.escape("a\rb"),
            "a\\rb")
        XCTAssertEqual(
            BASAgentFabricJSONEscape.escape("a\tb"),
            "a\\tb")
        XCTAssertEqual(
            BASAgentFabricJSONEscape.escape("hello"),
            "hello",
            "ch 981.9 ARC item 8: no-escape input passes " +
            "through unchanged")
    }

    func testARC_Item8_PlannerSeatStillEscapesCorrectly() {
        // Spot-check that the planner seat's emit still
        // produces well-formed JSON after migration
        let agent = BASAgentSpec(
            agentID: "planner.test",
            role: .planner,
            writeDomains: [.candidateFrontier],
            defaultLeaseProfile: .coldSeat,
            visibility: .high)
        let candidate = BASPlannerCandidate(
            candidateID: "c1",
            title: "needs \"escape\"",  // contains quote
            actionSummary: "do\nthings",  // contains newline
            confidence: 0.8,
            reversibility: 0.7)
        var seq = 0
        let deltas = BASPlannerSeat.emit(
            from: [candidate],
            turnID: "t1",
            agentSpec: agent,
            seq: &seq)
        XCTAssertEqual(deltas.count, 1)
        let json = deltas[0].patchJson
        // Escape applied:
        XCTAssertTrue(json.contains("needs \\\"escape\\\""),
            "ch 981.9 ARC item 8 regression: planner seat " +
            "still escapes double-quote after migration to " +
            "shared helper")
        XCTAssertTrue(json.contains("do\\nthings"))
    }

    // MARK: - Sanity check: cumulative arc test count reconcile

    func testARC_TestCountReconcileNote() {
        // Per the previous review,CHANGELOG drift on test
        // counts is a recurring issue。 This test is a sanity
        // checkpoint:if the cumulative test count of
        // ch 953-981.9 exceeds 700,this test PASSES (since
        // we expect monotonic growth)。 If a future change
        // accidentally REMOVES tests,the cumulative count
        // drops below 700 and this fails — defense against
        // silent test deletion。
        // REAL assertion (was a tautology telling the reader to run a command): count `func test`
        // declarations across the ch 953–981.9 arc files via #filePath (the live-state pattern the Rust
        // SHA pins use) and enforce the monotonic-growth floor in code. 764 at pin time.
        let testsDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let arcFiles = (try? FileManager.default.contentsOfDirectory(atPath: testsDir.path))?
            .filter { $0.hasPrefix("BASChapter9") && $0 >= "BASChapter95" && $0 < "BASChapter99" } ?? []
        let cumulative = arcFiles.reduce(0) { sum, name in
            let content = (try? String(contentsOf: testsDir.appendingPathComponent(name), encoding: .utf8)) ?? ""
            return sum + content.components(separatedBy: "func test").count - 1
        }
        XCTAssertGreaterThanOrEqual(cumulative, 700,
            "ch 953–981.9 cumulative test count dropped below the monotonic-growth floor " +
            "(\(cumulative) < 700) — tests were silently deleted")
    }
}
