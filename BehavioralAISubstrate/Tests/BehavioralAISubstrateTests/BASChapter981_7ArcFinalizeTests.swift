// MARK: - BASChapter981_7ArcFinalizeTests
// chapter 九百八十一.7 / M3610.7 — ARC FINALIZE tests
//
// Closes the final 3 substrate-side deferred items per
// `Docs/ARC_SEAL_953_981.md`:
//   Item 1 — Round-table mode scaffold
//   Item 5 — Sovereign warrant chain for collaborator upgrade
//   Item 8 — escapeForJSON consolidation
//
// Items 2 / 4 / 6 remain explicitly out-of-scope (won't-ship +
// host-side)。

import XCTest
@testable import BASMemory

final class BASChapter981_7ArcFinalizeTests: XCTestCase {

    // MARK: - Item 1: Round-table mode

    func testRoundTable_ProposalCodableRoundTrip() throws {
        let p = BASRoundTableProposal(
            proposalID: "p1",
            proposingAgentID: "planner.1",
            summary: "draft v3",
            confidence: 0.85,
            sourceDeltaRef:
                "delta.t1.planner.1")
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        let data = try enc.encode(p)
        let back = try JSONDecoder().decode(
            BASRoundTableProposal.self, from: data)
        XCTAssertEqual(p, back)
    }

    func testRoundTable_VoteCodableRoundTrip() throws {
        let v = BASRoundTableVote(
            votingAgentID: "critic.1",
            proposalID: "p1",
            direction: .dissent,
            confidence: 0.75,
            reason: "factual concern at section 3")
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        let data = try enc.encode(v)
        let back = try JSONDecoder().decode(
            BASRoundTableVote.self, from: data)
        XCTAssertEqual(v, back)
    }

    func testRoundTable_VoteDirectionCountIs3() {
        XCTAssertEqual(
            BASRoundTableVote.Direction.allCases.count, 3,
            "ch 981.7 Item 1: 3 vote directions " +
            "(approve/dissent/abstain)")
    }

    func testRoundTable_QuorumSortsProposalsByID() {
        let quorum = BASRoundTableQuorum(
            turnID: "t1",
            proposals: [
                proposal(id: "p-z"),
                proposal(id: "p-a"),
            ])
        XCTAssertEqual(
            quorum.proposals.map { $0.proposalID },
            ["p-a", "p-z"],
            "ch 981.7 Item 1: quorum auto-sorts proposals")
    }

    func testRoundTable_QuorumClampsThreshold() {
        let high = BASRoundTableQuorum(
            turnID: "t1", quorumThreshold: 2.0)
        XCTAssertEqual(
            high.quorumThreshold, 1.0, accuracy: 0.0001,
            "ch 981.7 Item 1: threshold clamped to 1.0")
        let low = BASRoundTableQuorum(
            turnID: "t1", quorumThreshold: -1.0)
        XCTAssertEqual(
            low.quorumThreshold, 0.0, accuracy: 0.0001)
    }

    func testRoundTable_ConsensusSimpleMajority() {
        // 3 voters, 1 proposal, 2 approve at 0.9 each, 1 abstain
        // → approve-weight = 1.8, participants = 3
        // → score = 1.8/3 = 0.6 ≥ threshold 0.5 → winner
        let quorum = BASRoundTableQuorum(
            turnID: "t1",
            proposals: [proposal(id: "p1")],
            votes: [
                vote(voter: "a", prop: "p1",
                    direction: .approve, conf: 0.9),
                vote(voter: "b", prop: "p1",
                    direction: .approve, conf: 0.9),
                vote(voter: "c", prop: "p1",
                    direction: .abstain, conf: 0.5),
            ],
            quorumThreshold: 0.5)
        let consensus =
            BASRoundTableSession.consense(quorum)
        XCTAssertEqual(consensus.winnerProposalID, "p1")
        XCTAssertEqual(
            consensus.winnerScore, 0.6, accuracy: 0.0001)
        XCTAssertEqual(consensus.dissents.count, 0)
    }

    func testRoundTable_ConsensusNoQuorumBelowThreshold() {
        // 4 voters, 1 proposal, 1 approve → 1/4 = 0.25 < 0.5
        let quorum = BASRoundTableQuorum(
            turnID: "t1",
            proposals: [proposal(id: "p1")],
            votes: [
                vote(voter: "a", prop: "p1",
                    direction: .approve, conf: 1.0),
                vote(voter: "b", prop: "p1",
                    direction: .dissent, conf: 0.8),
                vote(voter: "c", prop: "p1",
                    direction: .dissent, conf: 0.7),
                vote(voter: "d", prop: "p1",
                    direction: .abstain, conf: 0.5),
            ],
            quorumThreshold: 0.5)
        let consensus =
            BASRoundTableSession.consense(quorum)
        XCTAssertNil(consensus.winnerProposalID,
            "ch 981.7 Item 1: below threshold → no winner")
        XCTAssertTrue(consensus.auditNotes.contains {
            $0.hasPrefix("roundTable.no-quorum")
        })
    }

    func testRoundTable_DissentRecordedAgainstWinner() {
        let quorum = BASRoundTableQuorum(
            turnID: "t1",
            proposals: [proposal(id: "p1")],
            votes: [
                vote(voter: "a", prop: "p1",
                    direction: .approve, conf: 0.9),
                vote(voter: "b", prop: "p1",
                    direction: .approve, conf: 0.9),
                vote(voter: "c", prop: "p1",
                    direction: .dissent, conf: 0.8,
                    reason: "factual error"),
            ],
            quorumThreshold: 0.5)
        let consensus =
            BASRoundTableSession.consense(quorum)
        XCTAssertEqual(consensus.winnerProposalID, "p1")
        XCTAssertEqual(consensus.dissents.count, 1)
        XCTAssertEqual(
            consensus.dissents[0].dissentingAgentID, "c")
        XCTAssertEqual(
            consensus.dissents[0].reason, "factual error")
    }

    func testRoundTable_EmptyQuorumProducesNoConsensus() {
        let quorum = BASRoundTableQuorum(turnID: "t1")
        let consensus =
            BASRoundTableSession.consense(quorum)
        XCTAssertNil(consensus.winnerProposalID)
        XCTAssertTrue(consensus.auditNotes.contains {
            $0.contains("no-participants")
        })
    }

    func testRoundTable_DeterministicAcrossRuns() {
        let quorum = BASRoundTableQuorum(
            turnID: "t1",
            proposals: [
                proposal(id: "p-1"),
                proposal(id: "p-2"),
            ],
            votes: [
                vote(voter: "a", prop: "p-1",
                    direction: .approve, conf: 0.7),
                vote(voter: "b", prop: "p-2",
                    direction: .approve, conf: 0.8),
            ])
        let r1 = BASRoundTableSession.consense(quorum)
        let r2 = BASRoundTableSession.consense(quorum)
        XCTAssertEqual(r1, r2,
            "ch 981.7 Item 1: consense MUST be deterministic " +
            "(trace replay invariant)")
    }

    func testRoundTable_TieBreakerLexicographicByID() {
        // Both proposals get same score (0.5) → lexicographic
        // tie-break picks proposalID first alphabetically
        let quorum = BASRoundTableQuorum(
            turnID: "t1",
            proposals: [
                proposal(id: "p-zz"),
                proposal(id: "p-aa"),
            ],
            votes: [
                vote(voter: "a", prop: "p-zz",
                    direction: .approve, conf: 1.0),
                vote(voter: "b", prop: "p-aa",
                    direction: .approve, conf: 1.0),
            ],
            quorumThreshold: 0.4)
        let consensus =
            BASRoundTableSession.consense(quorum)
        XCTAssertEqual(consensus.winnerProposalID, "p-aa",
            "ch 981.7 Item 1: tie-break MUST pick alphabetic " +
            "first proposalID")
    }

    // MARK: - Item 5: Sovereign warrant chain

    func testWarrantChain_ValidationGranted() {
        let chain = BASSovereignWarrantChain(
            hostRootWarrantID: "host-w-1",
            perAgentWarrantID: "agent-w-1",
            expiresAtNanos: 1_000_000_000_000,
            externalAgentID: "ext.a",
            reason: "trusted partner integration")
        let result =
            BASSovereignWarrantValidator.validate(
                chain: chain,
                forExternalAgentID: "ext.a",
                nowNanos: 500_000_000_000)
        XCTAssertTrue(result.valid)
        XCTAssertTrue(result.auditRefs.contains { ref in
            ref.hasPrefix("agentExternal.warrant:granted:")
        })
    }

    func testWarrantChain_RejectsEmptyHostRoot() {
        let chain = BASSovereignWarrantChain(
            hostRootWarrantID: "",
            perAgentWarrantID: "agent-w-1",
            expiresAtNanos: 1_000_000_000_000,
            externalAgentID: "ext.a")
        let result =
            BASSovereignWarrantValidator.validate(
                chain: chain,
                forExternalAgentID: "ext.a",
                nowNanos: 500_000_000_000)
        XCTAssertFalse(result.valid)
        XCTAssertTrue(result.auditRefs.contains { ref in
            ref.contains("empty-host-root")
        })
    }

    func testWarrantChain_RejectsEmptyPerAgent() {
        let chain = BASSovereignWarrantChain(
            hostRootWarrantID: "host-w-1",
            perAgentWarrantID: "",
            expiresAtNanos: 1_000_000_000_000,
            externalAgentID: "ext.a")
        let result =
            BASSovereignWarrantValidator.validate(
                chain: chain,
                forExternalAgentID: "ext.a",
                nowNanos: 500_000_000_000)
        XCTAssertFalse(result.valid)
        XCTAssertTrue(result.auditRefs.contains { ref in
            ref.contains("empty-per-agent")
        })
    }

    func testCRITICAL_WarrantChainRejectsIdentityMismatch() {
        // Attacker submits warrant for agent A alongside
        // proposal from agent B
        let chain = BASSovereignWarrantChain(
            hostRootWarrantID: "host-w-1",
            perAgentWarrantID: "agent-w-1",
            expiresAtNanos: 1_000_000_000_000,
            externalAgentID: "ext.A")
        let result =
            BASSovereignWarrantValidator.validate(
                chain: chain,
                forExternalAgentID: "ext.B",  // mismatched
                nowNanos: 500_000_000_000)
        XCTAssertFalse(result.valid,
            "ch 981.7 Item 5 CRITICAL: identity mismatch " +
            "(warrant for A used with proposal from B) MUST " +
            "be rejected")
        XCTAssertTrue(result.auditRefs.contains { ref in
            ref.contains("identity-mismatch")
        })
    }

    func testCRITICAL_WarrantChainRejectsExpired() {
        let chain = BASSovereignWarrantChain(
            hostRootWarrantID: "host-w-1",
            perAgentWarrantID: "agent-w-1",
            expiresAtNanos: 100,  // expired
            externalAgentID: "ext.a")
        let result =
            BASSovereignWarrantValidator.validate(
                chain: chain,
                forExternalAgentID: "ext.a",
                nowNanos: 200)  // past expiration
        XCTAssertFalse(result.valid,
            "ch 981.7 Item 5 CRITICAL: expired warrant MUST " +
            "be rejected (no perpetual warrants)")
        XCTAssertTrue(result.auditRefs.contains { ref in
            ref.contains("expired")
        })
    }

    func testCRITICAL_WarrantChainGatewayUpgrade() {
        // External ref declared collaborator + valid warrant
        // → effective tier IS collaborator (no auto-downgrade)
        let ref = BASExternalAgentRef(
            externalAgentID: "ext.a",
            protocolVersion: "v",
            sandboxTier: .collaborator,
            attestationToken: "sig")
        let chain = BASSovereignWarrantChain(
            hostRootWarrantID: "host-w-1",
            perAgentWarrantID: "agent-w-1",
            expiresAtNanos: 1_000_000_000_000,
            externalAgentID: "ext.a")
        let (tier, _) =
            BASExternalAgentGateway
                .effectiveTierWithWarrant(
                    for: ref,
                    warrantChain: chain,
                    nowNanos: 500_000_000_000)
        XCTAssertEqual(tier, .collaborator,
            "ch 981.7 Item 5: valid warrant chain MUST " +
            "honor declared .collaborator tier")
    }

    func testCRITICAL_WarrantChainNilFallsBackToDowngrade() {
        // No warrant supplied → falls back to existing
        // ch 977 downgrade (collaborator → advisor)
        let ref = BASExternalAgentRef(
            externalAgentID: "ext.a",
            protocolVersion: "v",
            sandboxTier: .collaborator,
            attestationToken: "sig")
        let (tier, result) =
            BASExternalAgentGateway
                .effectiveTierWithWarrant(
                    for: ref,
                    warrantChain: nil,
                    nowNanos: 500_000_000_000)
        XCTAssertEqual(tier, .advisor,
            "ch 981.7 Item 5: nil warrant chain MUST fall " +
            "back to ch 977 downgrade (.collaborator → " +
            ".advisor)")
        XCTAssertTrue(result.auditRefs.contains { ref in
            ref.contains("none-supplied")
        })
    }

    func testCRITICAL_WarrantChainExpiredFallsBackToDowngrade() {
        // Expired warrant → falls back to downgrade,not the
        // declared collaborator
        let ref = BASExternalAgentRef(
            externalAgentID: "ext.a",
            protocolVersion: "v",
            sandboxTier: .collaborator,
            attestationToken: "sig")
        let chain = BASSovereignWarrantChain(
            hostRootWarrantID: "host-w-1",
            perAgentWarrantID: "agent-w-1",
            expiresAtNanos: 100,
            externalAgentID: "ext.a")
        let (tier, _) =
            BASExternalAgentGateway
                .effectiveTierWithWarrant(
                    for: ref,
                    warrantChain: chain,
                    nowNanos: 1_000_000)
        XCTAssertEqual(tier, .advisor,
            "ch 981.7 Item 5 CRITICAL: expired warrant MUST " +
            "NOT honor collaborator tier (defense in depth)")
    }

    func testWarrantChain_HighTierUnaffectedByWarrant() {
        // .advisor tier doesn't need warrant — supplying one
        // is harmless but doesn't change outcome
        let ref = BASExternalAgentRef(
            externalAgentID: "ext.a",
            protocolVersion: "v",
            sandboxTier: .advisor,
            attestationToken: "sig")
        let chain = BASSovereignWarrantChain(
            hostRootWarrantID: "host-w-1",
            perAgentWarrantID: "agent-w-1",
            expiresAtNanos: 1_000_000_000_000,
            externalAgentID: "ext.a")
        let (tier, result) =
            BASExternalAgentGateway
                .effectiveTierWithWarrant(
                    for: ref,
                    warrantChain: chain,
                    nowNanos: 500_000_000_000)
        XCTAssertEqual(tier, .advisor,
            "ch 981.7 Item 5: declared .advisor tier " +
            "unchanged by warrant supply (no escalation)")
        // ch 981.8 USER-PASS-9 HIGH-3 fix:audit now
        // distinguishes between "no warrant supplied" and
        // "warrant supplied but tier is not collaborator"。
        // Previously both emitted "none-supplied" which lied
        // when warrant WAS supplied alongside .advisor。
        XCTAssertTrue(result.auditRefs.contains { ref in
            ref.contains("not-applicable:tier=advisor")
        }, "ch 981.8 HIGH-3: when warrant IS supplied but " +
           "tier is not collaborator,audit MUST emit " +
           "'not-applicable:tier=<tier>' not 'none-supplied'")
    }

    func testWarrantChain_CodableRoundTrip() throws {
        let chain = BASSovereignWarrantChain(
            hostRootWarrantID: "host-w-1",
            perAgentWarrantID: "agent-w-1",
            expiresAtNanos: 1_000_000_000_000,
            externalAgentID: "ext.a",
            reason: "test")
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        let data = try enc.encode(chain)
        let back = try JSONDecoder().decode(
            BASSovereignWarrantChain.self, from: data)
        XCTAssertEqual(chain, back)
    }

    // MARK: - Item 8: escapeForJSON consolidation

    func testEscapeJSON_BasicEscapes() {
        XCTAssertEqual(
            BASAgentFabricJSONEscape.escape("hello"),
            "hello")
        XCTAssertEqual(
            BASAgentFabricJSONEscape.escape("a\"b"),
            "a\\\"b")
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
    }

    func testEscapeJSON_EmptyStringPassesThrough() {
        XCTAssertEqual(
            BASAgentFabricJSONEscape.escape(""),
            "")
    }

    func testEscapeJSON_UnicodePassesThrough() {
        XCTAssertEqual(
            BASAgentFabricJSONEscape.escape("日本語"),
            "日本語")
        XCTAssertEqual(
            BASAgentFabricJSONEscape.escape("😀"),
            "😀")
    }

    func testEscapeJSON_CombinedCharacters() {
        let input = "Hello \"world\"\nnewline\\backslash"
        let expected =
            "Hello \\\"world\\\"\\nnewline\\\\backslash"
        XCTAssertEqual(
            BASAgentFabricJSONEscape.escape(input),
            expected)
    }

    func testEscapeJSON_Determinism() {
        let input = "test \"input\" \\with stuff"
        let r1 = BASAgentFabricJSONEscape.escape(input)
        let r2 = BASAgentFabricJSONEscape.escape(input)
        XCTAssertEqual(r1, r2,
            "ch 981.7 Item 8: escape MUST be deterministic")
    }

    // MARK: - ch 982.5 META-REVIEW C1:RFC 8259 control-char regression

    /// CRITICAL: chapter 982.5 META-REVIEW caught that the
    /// pre-meta `escape(_:)` PASSED U+001F (unit separator) THROUGH
    /// UNESCAPED — but ch 964.5 + ch 981.9 BOTH inject U+001F as
    /// a sentinel into ref strings (`\u{001F}TURN-LOCKDOWN` +
    /// `\u{001F}per-agent=...`)。 RFC 8259 §7 mandates ALL
    /// U+0000-U+001F control chars be escaped as `\uXXXX`,so
    /// the pre-meta output was malformed JSON。 This test pins
    /// the fix。
    func testCRITICAL_EscapeJSON_U001F_SeparatorIsEscaped() {
        // The exact sentinel pattern from ch 981.9 warrant ref:
        let input = "host-root=h1\u{001F}per-agent=a1"
        let result = BASAgentFabricJSONEscape.escape(input)
        XCTAssertEqual(result,
            "host-root=h1\\u001Fper-agent=a1",
            "ch 982.5 META-REVIEW C1 CRITICAL: U+001F unit " +
            "separator MUST escape to \\u001F per RFC 8259 §7")
    }

    /// CRITICAL: chapter 964.5 TURN-LOCKDOWN sentinel test。
    /// Same control-char issue — was producing malformed JSON
    /// for any audit trace event that carried the sentinel。
    func testCRITICAL_EscapeJSON_U001F_TurnLockdownSentinel() {
        let input = "\u{001F}TURN-LOCKDOWN"
        let result = BASAgentFabricJSONEscape.escape(input)
        XCTAssertEqual(result, "\\u001FTURN-LOCKDOWN",
            "ch 982.5 META-REVIEW C1 CRITICAL: ch 964.5 " +
            "TURN-LOCKDOWN sentinel MUST escape U+001F")
    }

    /// Sweep across ALL U+0000 - U+001F to guarantee RFC 8259
    /// compliance。 The 5 special-case escapes (\\ " \n \r \t)
    /// are routed first;every other code point < 0x20 falls
    /// through to the catch-all。 This test pins the catch-all
    /// covers ALL of them。
    func testCRITICAL_EscapeJSON_AllControlCharsBelow0x20() {
        for v in 0..<0x20 {
            let scalar = Unicode.Scalar(v)!
            let ch = Character(scalar)
            let input = "x\(ch)y"
            let result = BASAgentFabricJSONEscape.escape(input)
            // Special-cases — these have shorter escapes
            switch v {
            case 0x08: // backspace — not specially handled,
                       // catches the catch-all → 
                XCTAssertEqual(result, "x\\u0008y")
            case 0x09: // \t
                XCTAssertEqual(result, "x\\ty")
            case 0x0A: // \n
                XCTAssertEqual(result, "x\\ny")
            case 0x0C: // form feed — also catch-all →
                XCTAssertEqual(result, "x\\u000Cy")
            case 0x0D: // \r
                XCTAssertEqual(result, "x\\ry")
            default:
                // Everything else MUST hit the catch-all
                let hex = String(format: "%04X", v)
                XCTAssertEqual(result, "x\\u\(hex)y",
                    "ch 982.5 META-REVIEW C1: U+\(hex) MUST " +
                    "escape per RFC 8259")
            }
        }
    }

    /// Higher control range (DEL = U+007F + C1 controls
    /// U+0080-U+009F) — RFC 8259 does NOT require these to be
    /// escaped。 The fix targets ONLY U+0000-U+001F per RFC 8259
    /// §7 strict literal language。 This test pins the line so
    /// future "be safer escape EVERYTHING" temptations have to
    /// argue against documented scope。
    func testEscapeJSON_HighControlRange_NotEscaped() {
        let input = "x\u{007F}y\u{0080}z"
        let result = BASAgentFabricJSONEscape.escape(input)
        XCTAssertEqual(result, "x\u{007F}y\u{0080}z",
            "ch 982.5 META-REVIEW C1: U+007F+ outside RFC 8259 " +
            "mandatory-escape range — must pass through")
    }

    /// JSONSerialization round-trip — proves the fix produces
    /// JSON that ACTUALLY decodes per Foundation。 This is the
    /// strongest test:if any control char passes through
    /// unescaped,`JSONSerialization.jsonObject(with:)` rejects
    /// the input,so we'd see a throw here。
    func testCRITICAL_EscapeJSON_RFC8259Decodable() throws {
        let input =
            "host-root=h1\u{001F}per-agent=a1\u{0001}with-control"
        let escaped = BASAgentFabricJSONEscape.escape(input)
        let json = "{\"k\":\"\(escaped)\"}"
        let data = json.data(using: .utf8)!
        // If escape failed,JSONSerialization throws here
        let obj = try JSONSerialization.jsonObject(
            with: data, options: []) as? [String: Any]
        XCTAssertNotNil(obj,
            "ch 982.5 META-REVIEW C1 CRITICAL: escaped output " +
            "MUST round-trip through Foundation JSON decoder")
        XCTAssertEqual(obj?["k"] as? String, input,
            "ch 982.5 META-REVIEW C1: decoded value MUST equal " +
            "the original input string byte-for-byte")
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
