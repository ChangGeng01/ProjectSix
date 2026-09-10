// MARK: - BASChapter812AuditTimeWindowTests
// chapter 八百十二 / M2711-M2715
//
// Verifies the time-windowed audit query helpers (chapter 八百十二)。
// Half-open [startMs, endMs) convention pinned across all 6
// audit record types。
//
// Five invariants pinned:
//
//   1. Half-open semantic:startMs INCLUDED,endMs EXCLUDED。
//   2. `since(_:)` shortcut equals `[sinceMs, Int64.max)`。
//   3. Filtering preserves input insertion order (stable filter)。
//   4. L7 contradictions: resolved-time filter EXCLUDES rows
//      with nil resolvedAtMs;unresolvedOnly filter returns
//      only `!resolved` rows regardless of timestamps。
//   5. Every L6/L7/L8/L5 record type supports both `between` and
//      `since` filters。

import XCTest
@testable import BASOrchestration
@testable import BASMemory
@testable import BASSovereign

final class BASChapter812AuditTimeWindowTests: XCTestCase {

    // MARK: - Half-open invariant

    func testPresenceBetweenHalfOpenIncludesStartExcludesEnd() {
        let records = [
            makePresenceRecord(observedAtMs: 99),   // before
            makePresenceRecord(observedAtMs: 100),  // start INCLUDED
            makePresenceRecord(observedAtMs: 150),  // middle
            makePresenceRecord(observedAtMs: 199),  // last in-range
            makePresenceRecord(observedAtMs: 200),  // end EXCLUDED
            makePresenceRecord(observedAtMs: 250),  // after
        ]
        let window = BASRoutedAuditTimeWindow.presence(
            records, between: 100, and: 200)
        XCTAssertEqual(window.count, 3)
        XCTAssertEqual(window.map { $0.observedAtMs },
                       [100, 150, 199],
            "Half-open window includes startMs, excludes endMs")
    }

    func testPresenceSinceShortcutMatchesBetweenToMax() {
        let records = [
            makePresenceRecord(observedAtMs: 50),
            makePresenceRecord(observedAtMs: 100),
            makePresenceRecord(observedAtMs: Int64.max - 1),
        ]
        let viaSince = BASRoutedAuditTimeWindow.presence(
            records, since: 100)
        let viaBetween = BASRoutedAuditTimeWindow.presence(
            records, between: 100, and: .max)
        XCTAssertEqual(viaSince, viaBetween)
        XCTAssertEqual(viaSince.count, 2)
    }

    // MARK: - Stable filter

    func testPresenceFilterPreservesInsertionOrder() {
        let records = (0..<10).map {
            makePresenceRecord(observedAtMs: Int64($0))
        }
        let window = BASRoutedAuditTimeWindow.presence(
            records, since: 0)
        XCTAssertEqual(window, records,
            "Filter must be stable — preserves input order")
    }

    // MARK: - L7 unknown

    func testUnknownTimeWindow() {
        let records = [
            makeUnknownRecord(discoveredAtMs: 50),
            makeUnknownRecord(discoveredAtMs: 100),
            makeUnknownRecord(discoveredAtMs: 200),
        ]
        let mid = BASRoutedAuditTimeWindow.unknowns(
            records, between: 100, and: 200)
        XCTAssertEqual(mid.count, 1)
        XCTAssertEqual(mid[0].discoveredAtMs, 100)
        let late = BASRoutedAuditTimeWindow.unknowns(
            records, since: 200)
        XCTAssertEqual(late.count, 1)
        XCTAssertEqual(late[0].discoveredAtMs, 200)
    }

    // MARK: - L7 contradictions (nullable resolvedAtMs)

    func testContradictionsResolvedExcludesNilResolvedAtMs() {
        let records = [
            makeContradictionRecord(
                resolved: false, resolvedAtMs: nil),
            makeContradictionRecord(
                resolved: true, resolvedAtMs: 100),
            makeContradictionRecord(
                resolved: true, resolvedAtMs: 200),
            makeContradictionRecord(
                resolved: false, resolvedAtMs: nil),  // still open
        ]
        let inWindow = BASRoutedAuditTimeWindow
            .contradictionsResolved(
                records, between: 50, and: 250)
        XCTAssertEqual(inWindow.count, 2,
            "Unresolved rows excluded from resolved-time window")
        XCTAssertEqual(inWindow.map { $0.resolvedAtMs },
                       [100, 200])
    }

    func testContradictionsUnresolvedReturnsOnlyOpenRecords() {
        let records = [
            makeContradictionRecord(
                resolved: false, resolvedAtMs: nil),
            makeContradictionRecord(
                resolved: true, resolvedAtMs: 100),
            makeContradictionRecord(
                resolved: false, resolvedAtMs: nil),
        ]
        let open = BASRoutedAuditTimeWindow
            .contradictionsUnresolved(records)
        XCTAssertEqual(open.count, 2)
        for record in open {
            XCTAssertFalse(record.resolved)
            XCTAssertNil(record.resolvedAtMs)
        }
    }

    // MARK: - L5 version tree

    func testVersionTreeTimeWindow() {
        let records = [
            makeVersionRecord(createdAtMs: 10),
            makeVersionRecord(createdAtMs: 50),
            makeVersionRecord(createdAtMs: 100),
        ]
        let recent = BASRoutedAuditTimeWindow.versions(
            records, since: 50)
        XCTAssertEqual(recent.count, 2)
        XCTAssertEqual(recent.map { $0.createdAtMs }, [50, 100])
    }

    // MARK: - L5 deletion manifest

    func testDeletionManifestTimeWindow() {
        let records = [
            makeDeletionRecord(appliedAtMs: 5),
            makeDeletionRecord(appliedAtMs: 15),
            makeDeletionRecord(appliedAtMs: 25),
        ]
        let mid = BASRoutedAuditTimeWindow.deletions(
            records, between: 10, and: 20)
        XCTAssertEqual(mid.count, 1)
        XCTAssertEqual(mid[0].appliedAtMs, 15)
    }

    // MARK: - L8 atom lifecycle

    func testAtomEventsTimeWindow() {
        let events = [
            makeAtomEvent(recordedAtMs: 1),
            makeAtomEvent(recordedAtMs: 5),
            makeAtomEvent(recordedAtMs: 10),
        ]
        let window = BASRoutedAuditTimeWindow.atomEvents(
            events, between: 5, and: 10)
        XCTAssertEqual(window.count, 1,
            "endMs=10 excludes the row at 10 per half-open rule")
        XCTAssertEqual(window[0].recordedAtMs, 5)
    }

    func testEmptyInputReturnsEmptyForAllTypes() {
        XCTAssertEqual(BASRoutedAuditTimeWindow.presence(
            [], since: 0), [])
        XCTAssertEqual(BASRoutedAuditTimeWindow.unknowns(
            [], since: 0), [])
        XCTAssertEqual(BASRoutedAuditTimeWindow.contradictionsResolved(
            [], since: 0), [])
        XCTAssertEqual(BASRoutedAuditTimeWindow.contradictionsUnresolved(
            []), [])
        XCTAssertEqual(BASRoutedAuditTimeWindow.versions(
            [], since: 0), [])
        XCTAssertEqual(BASRoutedAuditTimeWindow.deletions(
            [], since: 0), [])
        XCTAssertEqual(BASRoutedAuditTimeWindow.atomEvents(
            [], since: 0), [])
    }

    // MARK: - Helpers

    private func makePresenceRecord(
        observedAtMs: Int64
    ) -> BASPresenceObservationRecord {
        return BASPresenceObservationRecord(
            eventID: UUID().uuidString,
            sessionID: "s", turnID: "t",
            channelKind: "task",
            salience: 0.5, confidence: 0.5,
            observedAtMs: observedAtMs)
    }

    private func makeUnknownRecord(
        discoveredAtMs: Int64
    ) -> BASUnknownLedgerRecord {
        return BASUnknownLedgerRecord(
            eventID: UUID().uuidString,
            sessionID: "s", turnID: "t",
            unknownText: "fact: x",
            confidence: 1.0,
            discoveredAtMs: discoveredAtMs)
    }

    private func makeContradictionRecord(
        resolved: Bool,
        resolvedAtMs: Int64?
    ) -> BASContradictionLedgerRecord {
        return BASContradictionLedgerRecord(
            eventID: UUID().uuidString,
            sessionID: "s", turnID: "t",
            contradictionText: "textual: x",
            salience: 0.5, confidence: 1.0,
            resolved: resolved,
            resolvedAtMs: resolvedAtMs)
    }

    private func makeVersionRecord(
        createdAtMs: Int64
    ) -> BASHostConstitutionVersionRecord {
        return BASHostConstitutionVersionRecord(
            versionID: UUID().uuidString,
            vaultID: "v",
            createdAtMs: createdAtMs,
            signatureHash: Data(count: 32))
    }

    private func makeDeletionRecord(
        appliedAtMs: Int64
    ) -> BASHostConstitutionDeletionRecord {
        return BASHostConstitutionDeletionRecord(
            manifestID: UUID().uuidString,
            vaultID: "v",
            targetRefsJson: "[]",
            deletionType: "selective",
            appliedAtMs: appliedAtMs)
    }

    private func makeAtomEvent(
        recordedAtMs: Int64
    ) -> BASAtomLifecycleEvent {
        return BASAtomLifecycleEvent(
            eventID: UUID().uuidString,
            atomID: "a",
            sessionID: "s",
            fromPhaseByte: 0,
            toPhaseByte: 1,
            actionByte: 0,
            outcome: 0,
            recordedAtMs: recordedAtMs)
    }
}
