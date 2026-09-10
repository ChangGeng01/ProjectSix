// MARK: - BASChapter821ReviewRemediationTests
// chapter 八百二十一 / M2756-M2760
//
// Verifies the HIGH-severity findings from the 全量 审查 review
// have been addressed:
//
//   1. Shared `UnknownKind` enum + `parseUnknownText` is the
//      single source of truth for the "<kind>: <text>" prefix
//      encoding。 Used by recorder + replay + archive +
//      aggregation (no duplicate parsers)。
//   2. Codable conformance on SessionAuditTrail + ArchivedTurn
//      + ArchivedTrail + the 3 aggregation summaries enables
//      on-disk snapshot / export / cross-process diff。
//   3. The prefix-encoding lossy edge case is documented +
//      tested:user values starting with another kind's prefix
//      re-bucketize on replay。 This is by design (textual
//      encoding,non-escaping) but hosts must know about it。
//   4. Round-trip identity at PAYLOAD level (chapter 819
//      strengthened separately) verifies cold-restart preserves
//      every field byte-equivalent,not just the ID set。

import XCTest
@testable import BASMemory
@testable import BASSovereign
@testable import BASOrchestration

#if os(iOS) || os(macOS)

final class BASChapter821ReviewRemediationTests: XCTestCase {

    // MARK: - Shared UnknownKind parser

    func testUnknownKindAllCasesMatchSchema011() {
        let cases = BASRoutedMirrorBladeRecording.UnknownKind.allCases
        XCTAssertEqual(cases.map { $0.rawValue },
                       ["fact", "role", "constraint",
                        "permission", "ambiguity"])
        XCTAssertEqual(cases.map { $0.prefix },
                       ["fact: ", "role: ", "constraint: ",
                        "permission: ", "ambiguity: "])
    }

    func testParseUnknownTextRoundTripsAllKinds() {
        for kind in BASRoutedMirrorBladeRecording.UnknownKind.allCases {
            let body = "test body for \(kind.rawValue)"
            let encoded = "\(kind.prefix)\(body)"
            let parsed = BASRoutedMirrorBladeRecording
                .parseUnknownText(encoded)
            XCTAssertNotNil(parsed)
            XCTAssertEqual(parsed?.kind, kind)
            XCTAssertEqual(parsed?.body, body)
        }
    }

    func testParseUnknownTextReturnsNilOnUnrecognizedPrefix() {
        XCTAssertNil(BASRoutedMirrorBladeRecording
            .parseUnknownText("no-prefix-here"))
        XCTAssertNil(BASRoutedMirrorBladeRecording
            .parseUnknownText(""))
        XCTAssertNil(BASRoutedMirrorBladeRecording
            .parseUnknownText("almost-fact: body"))
    }

    func testUnknownKindIsCodable() throws {
        let kind = BASRoutedMirrorBladeRecording.UnknownKind.role
        let data = try JSONEncoder().encode(kind)
        let decoded = try JSONDecoder().decode(
            BASRoutedMirrorBladeRecording.UnknownKind.self,
            from: data)
        XCTAssertEqual(decoded, kind)
        XCTAssertEqual(String(decoding: data, as: UTF8.self),
                       "\"role\"")
    }

    // MARK: - Cross-module consistency:Archive + Aggregation
    // + reconstructUnknownSet all use the same parser

    func testArchiveUsesSharedParserForUnknownBucketing() {
        let trail = makeTrail(unknownTexts: [
            "fact: F1",
            "role: R1",
            "constraint: C1",
            "permission: P1",
            "ambiguity: A1",
            "no-prefix",          // unparseable → dropped
        ])
        let arch = BASAuditTrailArchive.archive(trail: trail)
        XCTAssertEqual(arch.turnCount, 1)
        let turn = arch.turns[0]
        XCTAssertEqual(turn.unknownFactCount, 1)
        XCTAssertEqual(turn.unknownRoleCount, 1)
        XCTAssertEqual(turn.unknownConstraintCount, 1)
        XCTAssertEqual(turn.unknownPermissionCount, 1)
        XCTAssertEqual(turn.unknownAmbiguityCount, 1)
    }

    func testAggregationUsesSharedParserForUnparseableCount() {
        let records = [
            makeUnknown(text: "fact: F"),
            makeUnknown(text: "no-prefix"),
            makeUnknown(text: "also-no-prefix"),
        ]
        let agg = BASRoutedAuditAggregation.aggregateUnknowns(
            records: records, sessionID: "s")
        XCTAssertEqual(agg.factCount, 1)
        XCTAssertEqual(agg.unparseableCount, 2)
    }

    // MARK: - Documented lossy edge case (HIGH severity acknowledged)

    func testDocumentedLossyEdgeCase_UserFactContainingRolePrefix() async throws {
        // KNOWN LIMITATION: if a user's missingFact starts with
        // "role: ", replay re-bucketizes it AS a missingRole。
        // This is documented in parseUnknownText doc comments
        // and accepted as a tradeoff for human-readable storage。
        let store = BASInMemoryUnknownLedgerStore()
        let originalSet = BASUnknownSet(
            missingFacts: [
                "role: missing actor for the task"  // LOOKS like a role!
            ])
        _ = try await BASRoutedMirrorBladeRecording.recordUnknownSet(
            originalSet,
            sessionID: "s", turnID: "t",
            store: store,
            eventIDPrefix: "lossy",
            nowMs: 0)
        // What the recorder writes:
        //   unknown_text = "fact: role: missing actor for the task"
        let stored = await store.records(forSession: "s")
        XCTAssertEqual(stored.count, 1)
        XCTAssertEqual(stored[0].unknownText,
            "fact: role: missing actor for the task",
            "Recorder writes the kind prefix verbatim;user content is untouched")

        // Parser correctly identifies the OUTER prefix as fact
        // (longest-match-from-start is automatic since fact's prefix
        // matches at position 0)
        let parsed = BASRoutedMirrorBladeRecording.parseUnknownText(
            stored[0].unknownText)
        XCTAssertEqual(parsed?.kind, .fact,
            "Outer fact: prefix wins;parser is non-greedy on first match")
        XCTAssertEqual(parsed?.body,
            "role: missing actor for the task",
            "Body preserves the inner text including the misleading role: prefix")

        // BUT — reconstruct() drops the outer "fact: " prefix,
        // leaving body = "role: missing actor..."。 The body is
        // restored intact as a missingFact entry (NOT re-bucketized)。
        let restored = BASRoutedMirrorBladeRecording
            .reconstructUnknownSet(from: stored)
        XCTAssertEqual(restored.missingFacts,
            ["role: missing actor for the task"],
            "Single-record reconstruction is round-trip safe — " +
            "the outer fact: prefix correctly identifies the fact bucket")
        XCTAssertTrue(restored.missingRoles.isEmpty,
            "User content containing 'role: ' does NOT leak to missingRoles")

        // The ACTUAL lossy case (currently not triggered by single-
        // record round-trip because the encoder always prefixes the
        // CORRECT kind):if a host DIRECTLY writes a raw record with
        // unknown_text = "role: foo" claiming it's a fact,replay
        // re-bucketizes it as a role。 This is the host's
        // responsibility — they must use recordUnknownSet which
        // ALWAYS prefixes correctly。
    }

    func testRawHostBypassRecorderIsLossy() async throws {
        // Demonstration:if a host BYPASSES recordUnknownSet and
        // writes raw records with malformed unknown_text values,
        // replay can't recover the original kind。 This is the
        // recorder's responsibility — hosts should not bypass it。
        let store = BASInMemoryUnknownLedgerStore()
        _ = try await store.appendRecord(BASUnknownLedgerRecord(
            eventID: "raw-bypass",
            sessionID: "s",
            turnID: "t",
            // Host wrote raw — no "fact: " prefix wrapping。
            // The string itself starts with "role: "。
            unknownText: "role: bypass payload",
            confidence: 1.0,
            discoveredAtMs: 0))
        let stored = await store.records(forSession: "s")
        let restored = BASRoutedMirrorBladeRecording
            .reconstructUnknownSet(from: stored)
        // The parser sees "role: " at position 0 and buckets to
        // missingRoles — no way to know the host MEANT it as a
        // fact (because the host didn't use the recorder)。
        XCTAssertEqual(restored.missingRoles, ["bypass payload"])
        XCTAssertTrue(restored.missingFacts.isEmpty,
            "Raw bypass loses original kind — use recordUnknownSet")
    }

    // MARK: - Codable conformance (Trail / Archive / Summaries)

    func testSessionAuditTrailIsCodable() throws {
        let trail = makeTrail(unknownTexts: ["fact: F1"])
        let data = try JSONEncoder().encode(trail)
        let decoded = try JSONDecoder().decode(
            BASAuditReplayEngine.SessionAuditTrail.self, from: data)
        XCTAssertEqual(decoded, trail)
    }

    func testArchivedTrailIsCodable() throws {
        let trail = makeTrail(unknownTexts: ["fact: F", "role: R"])
        let arch = BASAuditTrailArchive.archive(trail: trail)
        let data = try JSONEncoder().encode(arch)
        let decoded = try JSONDecoder().decode(
            BASAuditTrailArchive.ArchivedTrail.self, from: data)
        XCTAssertEqual(decoded, arch)
    }

    func testArchivedTurnIsCodable() throws {
        let trail = makeTrail(unknownTexts: ["fact: F"])
        let arch = BASAuditTrailArchive.archive(trail: trail)
        XCTAssertEqual(arch.turns.count, 1)
        let turn = arch.turns[0]
        let data = try JSONEncoder().encode(turn)
        let decoded = try JSONDecoder().decode(
            BASAuditTrailArchive.ArchivedTurn.self, from: data)
        XCTAssertEqual(decoded, turn)
    }

    func testAggregationSummariesAreCodable() throws {
        // Round-trip all three summary structs via JSON
        let presence = BASRoutedAuditAggregation
            .PresenceSessionSummary(
                sessionID: "s",
                totalObservations: 5,
                turnCount: 2,
                avgSalience: 0.5,
                avgConfidence: 0.7,
                observationCountByChannel: ["task": 3, "risk": 2])
        let unknownSum = BASRoutedAuditAggregation
            .UnknownSessionSummary(
                sessionID: "s",
                totalRecords: 3,
                turnCount: 1,
                factCount: 2,
                roleCount: 1,
                constraintCount: 0,
                permissionCount: 0,
                ambiguityCount: 0,
                unparseableCount: 0)
        let contradictionSum = BASRoutedAuditAggregation
            .ContradictionSessionSummary(
                sessionID: "s",
                totalRecords: 2,
                resolvedCount: 1,
                unresolvedCount: 1,
                maxSalience: 0.9,
                avgSalience: 0.65)

        let pData = try JSONEncoder().encode(presence)
        let uData = try JSONEncoder().encode(unknownSum)
        let cData = try JSONEncoder().encode(contradictionSum)
        let pDec = try JSONDecoder().decode(
            BASRoutedAuditAggregation.PresenceSessionSummary.self,
            from: pData)
        let uDec = try JSONDecoder().decode(
            BASRoutedAuditAggregation.UnknownSessionSummary.self,
            from: uData)
        let cDec = try JSONDecoder().decode(
            BASRoutedAuditAggregation.ContradictionSessionSummary.self,
            from: cData)
        XCTAssertEqual(pDec, presence)
        XCTAssertEqual(uDec, unknownSum)
        XCTAssertEqual(cDec, contradictionSum)
    }

    // MARK: - Helpers

    private func makeTrail(
        unknownTexts: [String]
    ) -> BASAuditReplayEngine.SessionAuditTrail {
        let records = unknownTexts.enumerated().map { idx, text in
            BASUnknownLedgerRecord(
                eventID: "u-\(idx)",
                sessionID: "s",
                turnID: "t",
                unknownText: text,
                confidence: 1.0,
                discoveredAtMs: Int64(idx))
        }
        return BASAuditReplayEngine.SessionAuditTrail(
            sessionID: "s",
            vaultID: nil,
            presence: [],
            unknowns: records,
            contradictions: [],
            atomEvents: [],
            versions: [])
    }

    private func makeUnknown(text: String) -> BASUnknownLedgerRecord {
        return BASUnknownLedgerRecord(
            eventID: UUID().uuidString,
            sessionID: "s",
            turnID: "t",
            unknownText: text,
            confidence: 1.0,
            discoveredAtMs: 0)
    }
}

#endif  // os(iOS) || os(macOS)
