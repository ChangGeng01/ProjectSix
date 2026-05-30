import XCTest
@testable import BASHostKit
import BASMemory
import BASOrchestration

// chapter 一千零四十二 / ADR-020 Step 4 — Commit 1 tests for the PURE
// resolution-credit helper `BASDeliberationResolutionCredit`。
//
// These exercise the typed-key mapping, the floored caution credit,
// and the [0, increment] withheld-increment contract — the math the
// Commit-2 seam will use to WITHHOLD a fraction of the loop's own
// added caution when stored evidence resolves a turn's typed
// unknowns (never below the loop-off baseline)。
//
// The helper is DORMANT in Commit 1: it is referenced ONLY by this
// file (no `runTurn` path calls it), so the full sweep stays
// byte-equal (red-line 7)。
//
// `increment` is fixed at `BASDeliberationCaution
// .uncertainDeliberationRiskIncrement` (0.06) throughout — the loop's
// added-caution magnitude (no magic number)。
final class BASDeliberationResolutionCreditTests: XCTestCase {
    /// The loop's added-caution magnitude (ADR-019 §11). Pinned to the
    /// production constant so these tests track the real value。
    private let increment =
        BASDeliberationCaution.uncertainDeliberationRiskIncrement

    // MARK: - Construction helpers (immutable, exact-key by construction)

    /// A typed unknown record carrying `summary` under `kind`。 The
    /// non-matching fields (`unknownID` / `sourceKind` / `blocking`) are
    /// irrelevant to the helper-under-test (it reads only `kind` +
    /// `summary`), so they take fixed placeholder values。
    private func unknown(
        _ kind: BASUnknownKind,
        _ summary: String
    ) -> BASUnknownRecord {
        BASUnknownRecord(
            unknownID: "u-\(summary)",
            kind: kind,
            summary: summary,
            sourceKind: .currentInput,
            blocking: false)
    }

    /// An evidence atom whose `evidenceKey` is derived from
    /// `(contentType, content)` via the SAME `BASEvidenceMatcher
    /// .evidenceKey` the helper uses — this is what makes an exact-key
    /// match possible (the ledger filters on `evidenceKey` equality)。
    /// `confidence` defaults above `defaultRelevanceFloor` (0.3) so the
    /// atom counts as resolving evidence。
    private func atom(
        _ contentType: BASEvidenceContentType,
        _ content: String,
        confidence: Double = 0.9
    ) -> BASEvidenceAtom {
        BASEvidenceAtom(
            evidenceID: "e-\(content)",
            evidenceKey: BASEvidenceMatcher.evidenceKey(
                contentType: contentType, content: content),
            content: content,
            contentType: contentType,
            sourceTurnID: "t-test",
            confidence: confidence)
    }

    // MARK: - contentType(for:) — exhaustive typed mapping

    func testContentTypeMappingExhaustive() {
        XCTAssertEqual(
            BASDeliberationResolutionCredit.contentType(for: .missingFact),
            .fact)
        XCTAssertEqual(
            BASDeliberationResolutionCredit.contentType(
                for: .missingConstraint),
            .constraint)
        XCTAssertEqual(
            BASDeliberationResolutionCredit.contentType(for: .missingRole),
            .role)
        XCTAssertEqual(
            BASDeliberationResolutionCredit.contentType(
                for: .unresolvedPermission),
            .permission)
        XCTAssertNil(
            BASDeliberationResolutionCredit.contentType(for: .ambiguity))

        // Belt-and-braces: iterate every case so a future added kind
        // forces a decision here (CaseIterable)。
        for kind in BASUnknownKind.allCases {
            let mapped =
                BASDeliberationResolutionCredit.contentType(for: kind)
            if kind == .ambiguity {
                XCTAssertNil(mapped)
            } else {
                XCTAssertNotNil(mapped)
            }
        }
    }

    // MARK: - requiredEvidenceKeys — typed, ambiguity-dropped, deduped

    func testRequiredEvidenceKeysTypedAndDeduped() {
        let records = [
            unknown(.missingFact, "Alpha Fact"),
            unknown(.missingRole, "Owner Role"),
            unknown(.ambiguity, "Vague phrasing"),
            // Duplicate of the first (same kind + summary) — collapses.
            unknown(.missingFact, "Alpha Fact"),
            // Normalization-equal duplicate (different casing/whitespace)
            // — collapses on the normalized key。
            unknown(.missingFact, "  alpha   fact "),
            unknown(.unresolvedPermission, "Write Access"),
            unknown(.missingConstraint, "Budget Limit")
        ]

        let keys = BASDeliberationResolutionCredit.requiredEvidenceKeys(
            unknownRecords: records)

        // Each produced key equals the matcher's exact typed key。
        let factKey = BASEvidenceMatcher.evidenceKey(
            contentType: .fact, content: "Alpha Fact")
        let roleKey = BASEvidenceMatcher.evidenceKey(
            contentType: .role, content: "Owner Role")
        let permissionKey = BASEvidenceMatcher.evidenceKey(
            contentType: .permission, content: "Write Access")
        let constraintKey = BASEvidenceMatcher.evidenceKey(
            contentType: .constraint, content: "Budget Limit")

        // Ambiguity dropped; the two fact duplicates collapse to one →
        // exactly four distinct keys, in first-seen order。
        XCTAssertEqual(
            keys, [factKey, roleKey, permissionKey, constraintKey])

        // No ambiguity-derived key leaked in。
        let ambiguityKeyFact = BASEvidenceMatcher.evidenceKey(
            contentType: .fact, content: "Vague phrasing")
        XCTAssertFalse(keys.contains(ambiguityKeyFact))
    }

    // MARK: - resolutionCredit — zero cases

    func testResolutionCreditZeroWhenNilOrEmptyOrNoMatch() {
        let keys = BASDeliberationResolutionCredit.requiredEvidenceKeys(
            unknownRecords: [unknown(.missingFact, "Alpha")])
        XCTAssertEqual(keys.count, 1)

        // nil ledger → 0 (nothing to resolve against)。
        XCTAssertEqual(
            BASDeliberationResolutionCredit.resolutionCredit(
                requiredKeys: keys, ledger: nil, increment: increment),
            0,
            accuracy: 0)

        // empty required keys → 0 (nothing to resolve)。
        let nonEmptyLedger = BASEvidenceLedger(atoms: [
            atom(.fact, "Alpha")
        ])
        XCTAssertEqual(
            BASDeliberationResolutionCredit.resolutionCredit(
                requiredKeys: [],
                ledger: nonEmptyLedger,
                increment: increment),
            0,
            accuracy: 0)

        // ledger present but holds only NON-matching atoms → 0。
        let nonMatchingLedger = BASEvidenceLedger(atoms: [
            atom(.fact, "Beta"),
            atom(.role, "Alpha")
        ])
        XCTAssertEqual(
            BASDeliberationResolutionCredit.resolutionCredit(
                requiredKeys: keys,
                ledger: nonMatchingLedger,
                increment: increment),
            0,
            accuracy: 0)
        // Withheld stays the full increment when nothing resolves。
        XCTAssertEqual(
            BASDeliberationResolutionCredit.withheldIncrement(
                requiredKeys: keys,
                ledger: nonMatchingLedger,
                increment: increment),
            increment,
            accuracy: 1e-12)
    }

    // MARK: - resolutionCredit — full resolution

    func testResolutionCreditFullWhenAllResolved() {
        let records = [
            unknown(.missingFact, "Alpha Fact"),
            unknown(.missingRole, "Owner Role"),
            unknown(.unresolvedPermission, "Write Access")
        ]
        let keys = BASDeliberationResolutionCredit.requiredEvidenceKeys(
            unknownRecords: records)
        XCTAssertEqual(keys.count, 3)

        // A ledger with an exact-key atom for EVERY required key,
        // built via the SAME content the records carry → all resolve。
        let ledger = BASEvidenceLedger(atoms: [
            atom(.fact, "Alpha Fact"),
            atom(.role, "Owner Role"),
            atom(.permission, "Write Access")
        ])

        let credit = BASDeliberationResolutionCredit.resolutionCredit(
            requiredKeys: keys, ledger: ledger, increment: increment)
        XCTAssertEqual(credit, increment, accuracy: 1e-12)

        let withheld =
            BASDeliberationResolutionCredit.withheldIncrement(
                requiredKeys: keys, ledger: ledger, increment: increment)
        XCTAssertEqual(withheld, 0, accuracy: 1e-12)
    }

    // MARK: - withheldIncrement — floored in [0, increment]

    func testWithheldIncrementFlooredInRange() {
        // Two required keys; resolve exactly one → fraction 0.5。
        let records = [
            unknown(.missingFact, "Alpha Fact"),
            unknown(.missingRole, "Owner Role")
        ]
        let keys = BASDeliberationResolutionCredit.requiredEvidenceKeys(
            unknownRecords: records)
        XCTAssertEqual(keys.count, 2)

        let ledger = BASEvidenceLedger(atoms: [
            atom(.fact, "Alpha Fact")
        ])

        let credit = BASDeliberationResolutionCredit.resolutionCredit(
            requiredKeys: keys, ledger: ledger, increment: increment)
        let withheld =
            BASDeliberationResolutionCredit.withheldIncrement(
                requiredKeys: keys, ledger: ledger, increment: increment)

        // Half-resolution: credit == withheld == increment / 2。
        XCTAssertEqual(credit, increment / 2, accuracy: 1e-12)
        XCTAssertEqual(withheld, increment / 2, accuracy: 1e-12)

        // In range, strictly between the bounds for partial resolution。
        XCTAssertGreaterThan(withheld, 0)
        XCTAssertLessThan(withheld, increment)

        // Conservation: credit + withheld == increment exactly。
        XCTAssertEqual(credit + withheld, increment, accuracy: 1e-12)
    }

    // MARK: - anti-"theater" — a near-miss must NOT resolve

    func testAntiTheaterNearMissDoesNotResolve() {
        let records = [
            unknown(.missingFact, "The deploy window is Friday")
        ]
        let keys = BASDeliberationResolutionCredit.requiredEvidenceKeys(
            unknownRecords: records)
        XCTAssertEqual(keys.count, 1)

        // A near-miss: same TYPE, semantically related, but DIFFERENT
        // normalized text (a real different fact, not a formatting
        // variant) → the exact-key contract must NOT count it。
        let nearMissLedger = BASEvidenceLedger(atoms: [
            atom(.fact, "The deploy window is Thursday")
        ])

        let credit = BASDeliberationResolutionCredit.resolutionCredit(
            requiredKeys: keys,
            ledger: nearMissLedger,
            increment: increment)
        XCTAssertEqual(credit, 0, accuracy: 0)

        // And the loop withholds nothing — full caution stands。
        let withheld =
            BASDeliberationResolutionCredit.withheldIncrement(
                requiredKeys: keys,
                ledger: nearMissLedger,
                increment: increment)
        XCTAssertEqual(withheld, increment, accuracy: 1e-12)

        // Sanity: a TYPE mismatch on the same text also does not
        // resolve (the key includes the content-type prefix)。
        let typeMismatchLedger = BASEvidenceLedger(atoms: [
            atom(.constraint, "The deploy window is Friday")
        ])
        XCTAssertEqual(
            BASDeliberationResolutionCredit.resolutionCredit(
                requiredKeys: keys,
                ledger: typeMismatchLedger,
                increment: increment),
            0,
            accuracy: 0)
    }
}
