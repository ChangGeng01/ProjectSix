// MARK: - BASEvidenceMatcherTests
// ADR-020 Arc-2 Step 2a — DORMANT evidence-resolving deliberation types.
//
// Exercises the NEW, dormant value types (BASEvidenceContentType /
// BASEvidenceAtom / BASEvidenceLedger / BASEvidenceMatcher)。 These
// types are not yet wired into the runtime;these tests prove their
// pure behaviour in isolation:
//   - normalize is stable + idempotent,
//   - evidenceKey collapses equivalent content but separates types,
//   - resolution requires EXACT key equality (anti-"theater"),
//   - resolution is gated by the confidence floor,
//   - the ledger is immutable (appending returns a NEW copy),
//   - the ledger matches only key-equal + floor-passing atoms。

import Foundation
import XCTest
@testable import BASMemory

final class BASEvidenceMatcherTests: XCTestCase {

    // MARK: - normalize

    /// normalize collapses case / whitespace / punctuation + is
    /// idempotent:`normalize(normalize(x)) == normalize(x)`。
    func testNormalizeIsStableAndIdempotent() {
        let raw = "  The\tQUICK,  brown.. Fox!  "
        let once = BASEvidenceMatcher.normalize(raw)
        XCTAssertEqual(once, "the quick brown fox",
            "lowercased, punctuation stripped, whitespace collapsed + trimmed")

        let twice = BASEvidenceMatcher.normalize(once)
        XCTAssertEqual(twice, once,
            "normalize must be idempotent: normalize(normalize(x)) == normalize(x)")

        // Empty + whitespace-only inputs collapse to empty。
        XCTAssertEqual(BASEvidenceMatcher.normalize(""), "")
        XCTAssertEqual(BASEvidenceMatcher.normalize("   \n\t  "), "")
    }

    // MARK: - evidenceKey

    /// Equivalent content (modulo case / punctuation / whitespace)
    /// under the SAME content type yields the SAME key;the same
    /// content under a DIFFERENT content type yields a DIFFERENT key。
    func testEvidenceKeyEqualForEquivalentContent() {
        let a = BASEvidenceMatcher.evidenceKey(
            contentType: .fact, content: "The Budget Is $5.")
        let b = BASEvidenceMatcher.evidenceKey(
            contentType: .fact, content: " the budget is 5 ")
        XCTAssertEqual(a, b,
            "equivalent content under the same type → equal key")

        // The content-type tag must keep otherwise-equal content
        // apart across buckets。
        let asConstraint = BASEvidenceMatcher.evidenceKey(
            contentType: .constraint, content: "The Budget Is $5.")
        XCTAssertNotEqual(a, asConstraint,
            ".fact vs .constraint keys must differ even for equal content")
    }

    // MARK: - resolvedKeys

    /// A required key with NO exact-matching atom is NOT resolved。
    /// A near-miss prose atom (different normalized content) must not
    /// resolve it — the anti-"theater" guarantee。
    func testResolvedKeysRequiresExactKeyEquality() {
        let required = BASEvidenceMatcher.evidenceKey(
            contentType: .fact, content: "the deadline is friday")
        // A near-miss:same type, related-but-different prose →
        // different normalized key。
        let nearMiss = BASEvidenceAtom(
            evidenceID: "e1",
            evidenceKey: BASEvidenceMatcher.evidenceKey(
                contentType: .fact, content: "the deadline is friday afternoon"),
            content: "the deadline is friday afternoon",
            contentType: .fact,
            sourceTurnID: "t1",
            confidence: 0.9)
        let ledger = BASEvidenceLedger().appending(nearMiss)

        let resolved = BASEvidenceMatcher.resolvedKeys(
            requiredKeys: [required], in: ledger)
        XCTAssertTrue(resolved.isEmpty,
            "a near-miss prose atom must NOT resolve the required key")

        // Sanity: an EXACT-key atom DOES resolve it。
        let exact = BASEvidenceAtom(
            evidenceID: "e2",
            evidenceKey: required,
            content: "the deadline is friday",
            contentType: .fact,
            sourceTurnID: "t2",
            confidence: 0.9)
        let resolved2 = BASEvidenceMatcher.resolvedKeys(
            requiredKeys: [required], in: ledger.appending(exact))
        XCTAssertEqual(resolved2, [required],
            "an exact-key atom above the floor resolves the key")
    }

    /// An atom below the default relevance floor does NOT resolve its
    /// key,even with an exact key match。
    func testResolvedKeysGatedByConfidenceFloor() {
        let key = BASEvidenceMatcher.evidenceKey(
            contentType: .role, content: "the approver is alice")
        let belowFloor = BASEvidenceAtom(
            evidenceID: "e1",
            evidenceKey: key,
            content: "the approver is alice",
            contentType: .role,
            sourceTurnID: "t1",
            confidence: BASEvidenceMatcher.defaultRelevanceFloor - 0.01)
        let ledger = BASEvidenceLedger().appending(belowFloor)

        let resolved = BASEvidenceMatcher.resolvedKeys(
            requiredKeys: [key], in: ledger)
        XCTAssertTrue(resolved.isEmpty,
            "an atom below defaultRelevanceFloor must NOT resolve its key")

        // At exactly the floor it DOES resolve (>= comparison)。
        let atFloor = BASEvidenceAtom(
            evidenceID: "e2",
            evidenceKey: key,
            content: "the approver is alice",
            contentType: .role,
            sourceTurnID: "t2",
            confidence: BASEvidenceMatcher.defaultRelevanceFloor)
        let resolved2 = BASEvidenceMatcher.resolvedKeys(
            requiredKeys: [key], in: ledger.appending(atFloor))
        XCTAssertEqual(resolved2, [key],
            "an atom at exactly the floor resolves its key (>= comparison)")
    }

    // MARK: - ledger immutability + matching

    /// `appending` returns a NEW ledger;the original is unchanged。
    func testLedgerAppendingReturnsNewCopy() {
        let original = BASEvidenceLedger()
        XCTAssertEqual(original.atoms.count, 0)

        let atom = BASEvidenceAtom(
            evidenceID: "e1",
            evidenceKey: "fact:hello",
            content: "hello",
            contentType: .fact,
            sourceTurnID: "t1",
            confidence: 0.5)
        let appended = original.appending(atom)

        XCTAssertEqual(original.atoms.count, 0,
            "appending must NOT mutate the original ledger")
        XCTAssertEqual(appended.atoms.count, 1,
            "the returned ledger holds the appended atom")
        XCTAssertEqual(appended.atoms.first, atom)
    }

    /// `matches` returns only atoms that are BOTH key-equal AND at or
    /// above the floor。
    func testLedgerMatchesByKeyAndFloor() {
        let key = BASEvidenceMatcher.evidenceKey(
            contentType: .permission, content: "may write the file")
        let otherKey = BASEvidenceMatcher.evidenceKey(
            contentType: .permission, content: "may read the file")

        let keyEqualAbove = BASEvidenceAtom(
            evidenceID: "e1", evidenceKey: key, content: "may write the file",
            contentType: .permission, sourceTurnID: "t1", confidence: 0.8)
        let keyEqualBelow = BASEvidenceAtom(
            evidenceID: "e2", evidenceKey: key, content: "may write the file",
            contentType: .permission, sourceTurnID: "t2", confidence: 0.1)
        let differentKey = BASEvidenceAtom(
            evidenceID: "e3", evidenceKey: otherKey, content: "may read the file",
            contentType: .permission, sourceTurnID: "t3", confidence: 0.9)

        let ledger = BASEvidenceLedger()
            .appending(keyEqualAbove)
            .appending(keyEqualBelow)
            .appending(differentKey)

        let matches = ledger.matches(
            evidenceKey: key,
            relevanceFloor: BASEvidenceMatcher.defaultRelevanceFloor)
        XCTAssertEqual(matches, [keyEqualAbove],
            "matches returns only the key-equal, floor-passing atom")
    }
}
