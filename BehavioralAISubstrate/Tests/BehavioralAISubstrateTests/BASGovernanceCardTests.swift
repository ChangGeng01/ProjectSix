// MARK: - BASGovernanceCardTests
// chapter 五百八 / M1410 — 4th Tier C primitive tests

import XCTest
@testable import BASRuntimeCore

private enum SampleAuthority:
    String, Equatable, Hashable, Codable, Sendable,
    CaseIterable
{
    case constitutionalVault
    case hostDeclared
    case sovereignOverride
}

private enum SampleDecision:
    String, Equatable, Hashable, Codable, Sendable,
    CaseIterable
{
    case allow
    case deny
    case escalate
}

final class BASGovernanceCardTests: XCTestCase {

    private func sampleCard(
        authority: SampleAuthority = .hostDeclared,
        decision: SampleDecision = .allow,
        rationale: [String] = ["test-reason"],
        effectiveAtMs: Int64 = 1_000
    ) -> BASGovernanceCard<SampleAuthority,
                           SampleDecision>
    {
        return BASGovernanceCard(
            governanceID: "GOV-1",
            schemaVersion: "1.0.0",
            authority: authority,
            decision: decision,
            sourceRefs: ["vault-1"],
            effectiveAtMs: effectiveAtMs,
            rationale: rationale)
    }

    // MARK: - 1) Construction holds all fields

    func testConstructionHoldsAllFields() {
        let card = sampleCard()
        XCTAssertEqual(card.governanceID, "GOV-1")
        XCTAssertEqual(card.schemaVersion, "1.0.0")
        XCTAssertEqual(card.authority, .hostDeclared)
        XCTAssertEqual(card.decision, .allow)
        XCTAssertEqual(card.sourceRefs, ["vault-1"])
        XCTAssertEqual(card.effectiveAtMs, 1_000)
        XCTAssertEqual(card.rationale,
                       ["test-reason"])
    }

    // MARK: - 2) Two-parameter typing prevents mismatch

    func testTwoParameterTypingProvidesCompileTimeSafety() {
        // Verify that the cards with different Authority/
        // Decision types are DIFFERENT compile-time types
        // (this test won't compile if the types collapse)
        let card1 = sampleCard(
            authority: .constitutionalVault,
            decision: .deny)
        let card2 = sampleCard(
            authority: .sovereignOverride,
            decision: .escalate)
        XCTAssertNotEqual(card1.authority,
                          card2.authority)
        XCTAssertNotEqual(card1.decision,
                          card2.decision)
    }

    // MARK: - 3) isJustified requires rationale entry

    func testIsJustifiedWhenRationalePresent() {
        let card = sampleCard(rationale: ["reason-a"])
        XCTAssertTrue(card.isJustified)
    }

    func testNotJustifiedWhenRationaleEmpty() {
        let card = sampleCard(rationale: [])
        XCTAssertFalse(card.isJustified)
    }

    // MARK: - 4) distinctSourceCount dedups

    func testDistinctSourceCountDedups() {
        let card = BASGovernanceCard(
            governanceID: "G",
            schemaVersion: "1.0.0",
            authority: SampleAuthority.hostDeclared,
            decision: SampleDecision.allow,
            sourceRefs: [
                "vault-1", "vault-2", "vault-1",
                "vault-3", "vault-2"
            ],
            effectiveAtMs: 0,
            rationale: [])
        XCTAssertEqual(card.distinctSourceCount, 3)
    }

    // MARK: - 5) isActive at/before clock

    func testIsActiveAtOrAfterEffective() {
        let card = sampleCard(effectiveAtMs: 1_000)
        XCTAssertFalse(card.isActive(atMs: 500),
            "card NOT active before effective time")
        XCTAssertTrue(card.isActive(atMs: 1_000),
            "card active exactly at effective time")
        XCTAssertTrue(card.isActive(atMs: 2_000),
            "card active after effective time")
    }

    // MARK: - 6) Codable round-trip preserves both
    //             parameter types

    func testCodableRoundTrip() throws {
        let original = sampleCard(
            authority: .sovereignOverride,
            decision: .escalate,
            rationale: ["r1", "r2"])
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASGovernanceCard<SampleAuthority,
                              SampleDecision>.self,
            from: data)
        XCTAssertEqual(decoded, original)
        XCTAssertEqual(decoded.authority,
                       .sovereignOverride)
        XCTAssertEqual(decoded.decision, .escalate)
    }

    // MARK: - 7) Hashable

    func testHashable() {
        let c1 = sampleCard()
        let c2 = sampleCard()
        XCTAssertEqual(c1.hashValue, c2.hashValue)
        var seen = Set<
            BASGovernanceCard<SampleAuthority,
                              SampleDecision>>()
        seen.insert(c1)
        seen.insert(c2)
        XCTAssertEqual(seen.count, 1)
    }

    // MARK: - 8) Sendable

    func testSendable() async {
        let card = sampleCard()
        let captured = card
        let task = Task {
            captured.isJustified
        }
        let result = await task.value
        XCTAssertTrue(result)
    }

    // MARK: - 9) Different cards distinct

    func testDifferentCardsDistinct() {
        let allow = sampleCard(decision: .allow)
        let deny = sampleCard(decision: .deny)
        XCTAssertNotEqual(allow, deny)
        XCTAssertNotEqual(allow.hashValue,
                          deny.hashValue)
    }
}
