import XCTest
@testable import BASSovereign

/// Grounding increment 1 (The Ledger) — the git-self-grounding fact bank. The operator's own git log
/// is the deterministic fact source ("the git log IS the fact source"); a journal claim that CITES a
/// commit (a commit-qualified SHA token) or a marker (#N / H\d+ / M\d+ / ch\d+) is resolved by pure
/// Set-membership against the ingested log — the model is NEVER asked "is this true" (the 4B hard
/// lesson). Doctrine bias: abstain-over-adjudicate — record-miss (.contradicts) is reserved for the
/// high-confidence fabricated-SHA case; unmatched markers and unqualified hex ABSTAIN.
final class BASGitFactBankTests: XCTestCase {

    // Two realistic fixture commits (40-hex sha \t subject), mirroring this repo's convention.
    private let fixtureLog = """
    a1b2c3d4e5f60718293a4b5c6d7e8f9012345678\tfix(cue-precision MED): whole-word cues #20 H9
    0123456789abcdef0123456789abcdef01234567\tdocs(ledger): record the first real run ch1044
    """

    private var facts: BASGitFactBank.GitFacts { BASGitFactBank.ingest(gitLog: fixtureLog) }

    // MARK: - ingest (pure parse; no Process spawn)

    func testIngestParsesPrefixesMarkersAndSubjects() {
        let f = facts
        XCTAssertTrue(f.prefixes7.contains("a1b2c3d"))
        XCTAssertTrue(f.prefixes8.contains("a1b2c3d4"))
        XCTAssertTrue(f.prefixes7.contains("0123456"))
        // markers extracted from subjects, lowercased
        XCTAssertTrue(f.markers.contains("#20"))
        XCTAssertTrue(f.markers.contains("h9"))
        XCTAssertTrue(f.markers.contains("ch1044"))
        XCTAssertFalse(f.markers.contains("#999"))
        // subject lookup by canonical sha8
        XCTAssertEqual(f.subjectBySha8["a1b2c3d4"],
                       "fix(cue-precision MED): whole-word cues #20 H9")
    }

    func testIngestSkipsMalformedLines() {
        let f = BASGitFactBank.ingest(gitLog: "not-a-sha\tsubject\n\ntrailing junk")
        XCTAssertTrue(f.prefixes7.isEmpty)
        XCTAssertTrue(f.markers.isEmpty)
    }

    // MARK: - resolve: SHA-prefix membership (the primary, contradicts-capable signal)

    func testCitedRealCommitResolvesRecordMatch() {
        let r = BASGitFactBank.resolve(
            claim: "shipped the whole-word cue fix in commit a1b2c3d", facts: facts)
        XCTAssertEqual(r?.truth, .agrees)
        XCTAssertEqual(r?.sha8, "a1b2c3d4", "canonical 8-char prefix of the matched commit")
    }

    func testCitedFabricatedShaResolvesRecordMiss() {
        // SHA-shaped + commit-qualified + prefix of NO commit ⇒ the fabricated-citation catch.
        let r = BASGitFactBank.resolve(
            claim: "shipped the redis cache in commit deadbeef1", facts: facts)
        XCTAssertEqual(r?.truth, .contradicts)
        XCTAssertEqual(r?.token, "deadbeef1")
    }

    func testLongerCitedPrefixOfRealCommitMatches() {
        let r = BASGitFactBank.resolve(
            claim: "merged 0123456789abcdef yesterday", facts: facts)
        XCTAssertEqual(r?.truth, .agrees)
        XCTAssertEqual(r?.sha8, "01234567")
    }

    // MARK: - resolve: abstain bias (nil, never a false adjudication)

    func testPlainOpinionNoteAbstains() {
        XCTAssertNil(BASGitFactBank.resolve(
            claim: "had coffee and reviewed the morning plan", facts: facts))
    }

    func testUnqualifiedHexAbstains() {
        // hex-shaped but NOT commit-qualified (preceding word is not a context word, not parenthesized)
        XCTAssertNil(BASGitFactBank.resolve(
            claim: "the badge color deadbee1 looks fine", facts: facts))
    }

    func testDigitlessHexWordAbstains() {
        // "defaced" is 7 hex letters — an English word, no digit ⇒ abstain even when qualified.
        XCTAssertNil(BASGitFactBank.resolve(
            claim: "shipped defaced banner cleanup", facts: facts))
    }

    // MARK: - resolve: markers are AGREES-ONLY

    func testMarkerPresentInSubjectsResolvesRecordMatch() {
        let r = BASGitFactBank.resolve(claim: "closed H9 today for good", facts: facts)
        XCTAssertEqual(r?.truth, .agrees)
        XCTAssertEqual(r?.token, "h9")
        XCTAssertNil(r?.sha8, "a marker match names no single commit")
    }

    func testUnmatchedMarkerAbstainsNeverContradicts() {
        // an issue can be legitimately discussed before its commit exists ⇒ abstain, NOT record-miss
        XCTAssertNil(BASGitFactBank.resolve(
            claim: "planning #999 for next week", facts: facts))
    }

    // MARK: - fail-closed priority: a fabricated SHA outranks a real marker in the same claim

    func testFabricatedShaOutranksRealMarkerInSameClaim() {
        let r = BASGitFactBank.resolve(
            claim: "closed H9 in commit deadbeef1", facts: facts)
        XCTAssertEqual(r?.truth, .contradicts,
            "surfacing the fabricated citation is the protective outcome")
    }
}
