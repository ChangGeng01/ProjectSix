// MARK: - BASEventLogCrossSessionReplayTests
// chapter 四百四十三 / M1149-M1150-M1151 — POST-RADICAL Wave 14

import XCTest
@testable import BASHostKit
@testable import BASRuntimeCore
@testable import BASMemory
@testable import BASPolicy

/// Cross-session replay assembly integration tests for
/// M1149's two new entry-points:
///
///   1. `BASEventLogReplayBundle.merging(_:)` instance
///      method + `.combining(_:)` static factory —
///      typed value-level composition for accumulating
///      bundles
///
///   2. `BASEventLogProjectors.projectAcrossAllSessions(
///      from:sinceTimestampMs:limit:)` async factory —
///      pulls events across ALL sessions from a
///      `BASEventLogStorage` and returns the 6-kind
///      bundle
///
/// Coverage:
///   - merging(_:) instance method preserves per-kind
///     concatenation in input order
///   - combining(_:) static factory is equivalent to
///     reduce-merging
///   - empty inputs → empty bundle (both factories)
///   - projectAcrossAllSessions returns events from
///     multiple sessions in storage's globally-time-
///     ordered output
///   - projectAcrossAllSessions with sinceTimestampMs
///     cutoff filters older events
///   - projectAcrossAllSessions with limit caps result
///   - Determinism:same inputs → same output
final class BASEventLogCrossSessionReplayTests:
    XCTestCase
{

    // MARK: - Fixture builders

    private func makeMemoryAtomPayload(
        atomID: String
    ) -> BASMemoryAtomEventPayload {
        return BASMemoryAtomEventPayload(
            op: .removed,
            atomID: atomID)
    }

    private func makeTurnLifecyclePayload(
        turnID: String
    ) -> BASTurnLifecycleEventPayload {
        return BASTurnLifecycleEventPayload(
            phase: .start,
            turnID: turnID,
            sessionID: "ignored",
            sequenceNumber: 0)
    }

    private func makePlanAssignmentPayload(
        turnID: String
    ) -> BASTurnRuntimePlanAssignmentEventPayload {
        return BASTurnRuntimePlanAssignmentEventPayload(
            turnID: turnID,
            records: [],
            recordCount: 0,
            acceleratedRecordCount: 0,
            uniqueStageCount: 0)
    }

    // MARK: - merging(_:) instance method

    func testMergingPreservesPerKindConcatenation() {
        let bundleA = BASEventLogReplayBundle(
            memoryAtomEvents: [
                makeMemoryAtomPayload(atomID: "a1"),
                makeMemoryAtomPayload(atomID: "a2")
            ],
            turnLifecycleEvents: [
                makeTurnLifecyclePayload(turnID: "tA")
            ],
            parallelStageEvents: [],
            permitEscalationEvents: [],
            nativeStageDispatchEvents: [],
            planAssignmentEvents: [])
        let bundleB = BASEventLogReplayBundle(
            memoryAtomEvents: [
                makeMemoryAtomPayload(atomID: "b1")
            ],
            turnLifecycleEvents: [],
            parallelStageEvents: [],
            permitEscalationEvents: [],
            nativeStageDispatchEvents: [],
            planAssignmentEvents: [
                makePlanAssignmentPayload(turnID: "tB")
            ])
        let merged = bundleA.merging(bundleB)
        XCTAssertEqual(
            merged.memoryAtomEvents.map { $0.atomID },
            ["a1", "a2", "b1"],
            "merging concatenates per-kind in input order")
        XCTAssertEqual(
            merged.turnLifecycleEvents.count, 1)
        XCTAssertEqual(
            merged.planAssignmentEvents.count, 1)
        XCTAssertEqual(merged.totalEventCount, 5)
    }

    func testMergingWithEmptyIsIdentity() {
        let bundle = BASEventLogReplayBundle(
            memoryAtomEvents: [
                makeMemoryAtomPayload(atomID: "a1")
            ],
            turnLifecycleEvents: [],
            parallelStageEvents: [],
            permitEscalationEvents: [],
            nativeStageDispatchEvents: [],
            planAssignmentEvents: [])
        XCTAssertEqual(
            bundle.merging(.empty), bundle,
            "merging with .empty preserves the bundle")
        XCTAssertEqual(
            BASEventLogReplayBundle.empty.merging(bundle),
            bundle,
            ".empty merged with bundle equals bundle")
    }

    func testMergingDoesNotMutateOperands() {
        let original = BASEventLogReplayBundle(
            memoryAtomEvents: [
                makeMemoryAtomPayload(atomID: "x")
            ],
            turnLifecycleEvents: [],
            parallelStageEvents: [],
            permitEscalationEvents: [],
            nativeStageDispatchEvents: [],
            planAssignmentEvents: [])
        let snapshot = original
        _ = original.merging(.empty)
        XCTAssertEqual(original, snapshot,
            "merging is immutable — original unchanged")
    }

    // MARK: - combining(_:) static factory

    func testCombiningEmptyArrayYieldsEmpty() {
        let bundle = BASEventLogReplayBundle.combining([])
        XCTAssertEqual(bundle, BASEventLogReplayBundle.empty)
    }

    func testCombiningSingleElementYieldsSameValue() {
        let single = BASEventLogReplayBundle(
            memoryAtomEvents: [
                makeMemoryAtomPayload(atomID: "solo")
            ],
            turnLifecycleEvents: [],
            parallelStageEvents: [],
            permitEscalationEvents: [],
            nativeStageDispatchEvents: [],
            planAssignmentEvents: [])
        XCTAssertEqual(
            BASEventLogReplayBundle.combining([single]),
            single)
    }

    func testCombiningMultipleEquivalentToFold() {
        let a = BASEventLogReplayBundle(
            memoryAtomEvents: [
                makeMemoryAtomPayload(atomID: "a")
            ],
            turnLifecycleEvents: [],
            parallelStageEvents: [],
            permitEscalationEvents: [],
            nativeStageDispatchEvents: [],
            planAssignmentEvents: [])
        let b = BASEventLogReplayBundle(
            memoryAtomEvents: [
                makeMemoryAtomPayload(atomID: "b")
            ],
            turnLifecycleEvents: [],
            parallelStageEvents: [],
            permitEscalationEvents: [],
            nativeStageDispatchEvents: [],
            planAssignmentEvents: [])
        let c = BASEventLogReplayBundle(
            memoryAtomEvents: [
                makeMemoryAtomPayload(atomID: "c")
            ],
            turnLifecycleEvents: [],
            parallelStageEvents: [],
            permitEscalationEvents: [],
            nativeStageDispatchEvents: [],
            planAssignmentEvents: [])
        let combined = BASEventLogReplayBundle.combining(
            [a, b, c])
        let folded = a.merging(b).merging(c)
        XCTAssertEqual(combined, folded,
            "combining([a,b,c]) is reduce-merging")
        XCTAssertEqual(
            combined.memoryAtomEvents.map { $0.atomID },
            ["a", "b", "c"])
    }

    // MARK: - projectAcrossAllSessions: multi-session

    func testProjectAcrossAllSessionsReturnsEventsFromAllSessions() async throws {
        let storage = BASInMemoryEventLogStorage()
        // Append 1 event for each of 3 different sessions
        _ = try await storage.append(
            BASEventLogEntry.memoryAtomEvent(
                eventID: "e-s1",
                timestampMs: 100,
                sessionID: "session-A",
                payload: makeMemoryAtomPayload(
                    atomID: "atom-A")))
        _ = try await storage.append(
            BASEventLogEntry.memoryAtomEvent(
                eventID: "e-s2",
                timestampMs: 200,
                sessionID: "session-B",
                payload: makeMemoryAtomPayload(
                    atomID: "atom-B")))
        _ = try await storage.append(
            BASEventLogEntry.memoryAtomEvent(
                eventID: "e-s3",
                timestampMs: 300,
                sessionID: "session-C",
                payload: makeMemoryAtomPayload(
                    atomID: "atom-C")))
        let bundle = await BASEventLogProjectors
            .projectAcrossAllSessions(from: storage)
        XCTAssertEqual(
            bundle.memoryAtomEvents.count, 3,
            "all 3 sessions' events flow into one bundle")
        XCTAssertEqual(
            bundle.memoryAtomEvents.map { $0.atomID },
            ["atom-A", "atom-B", "atom-C"],
            "globally time-ordered: 100ms < 200ms < 300ms")
    }

    func testProjectAcrossAllSessionsRespectsSinceTimestampMs() async throws {
        let storage = BASInMemoryEventLogStorage()
        _ = try await storage.append(
            BASEventLogEntry.memoryAtomEvent(
                eventID: "old",
                timestampMs: 100,
                sessionID: "session-A",
                payload: makeMemoryAtomPayload(
                    atomID: "old-atom")))
        _ = try await storage.append(
            BASEventLogEntry.memoryAtomEvent(
                eventID: "new",
                timestampMs: 500,
                sessionID: "session-B",
                payload: makeMemoryAtomPayload(
                    atomID: "new-atom")))
        // since: 200 → only "new" survives
        let recent = await BASEventLogProjectors
            .projectAcrossAllSessions(
                from: storage,
                sinceTimestampMs: 200)
        XCTAssertEqual(
            recent.memoryAtomEvents.map { $0.atomID },
            ["new-atom"],
            "since: cutoff filters out older events")
        // since: 0 (default) → all
        let all = await BASEventLogProjectors
            .projectAcrossAllSessions(from: storage)
        XCTAssertEqual(
            all.memoryAtomEvents.count, 2,
            "default sinceTimestampMs: 0 returns all")
    }

    func testProjectAcrossAllSessionsRespectsLimit() async throws {
        let storage = BASInMemoryEventLogStorage()
        for i in 0..<5 {
            _ = try await storage.append(
                BASEventLogEntry.memoryAtomEvent(
                    eventID: "e\(i)",
                    timestampMs: Int64(100 + i),
                    sessionID: "session-X",
                    payload: makeMemoryAtomPayload(
                        atomID: "a\(i)")))
        }
        let capped = await BASEventLogProjectors
            .projectAcrossAllSessions(
                from: storage,
                limit: 3)
        XCTAssertEqual(
            capped.memoryAtomEvents.count, 3,
            "limit: 3 caps result at 3 events" +
            " (first 3 by global time order)")
        XCTAssertEqual(
            capped.memoryAtomEvents.map { $0.atomID },
            ["a0", "a1", "a2"],
            "earliest-first cap")
    }

    func testProjectAcrossAllSessionsAggregatesAllKinds() async throws {
        let storage = BASInMemoryEventLogStorage()
        // 1 of each kind across 2 sessions
        _ = try await storage.append(
            BASEventLogEntry.memoryAtomEvent(
                eventID: "k1",
                timestampMs: 100,
                sessionID: "s1",
                payload: makeMemoryAtomPayload(
                    atomID: "atom-x")))
        _ = try await storage.append(
            BASEventLogEntry.turnLifecycleEvent(
                eventID: "k2",
                timestampMs: 110,
                sessionID: "s2",
                payload: makeTurnLifecyclePayload(
                    turnID: "t-x")))
        _ = try await storage.append(
            BASEventLogEntry.planAssignmentEvent(
                eventID: "k3",
                timestampMs: 120,
                sessionID: "s1",
                payload: makePlanAssignmentPayload(
                    turnID: "t-y")))
        let bundle = await BASEventLogProjectors
            .projectAcrossAllSessions(from: storage)
        XCTAssertEqual(
            bundle.memoryAtomEvents.count, 1)
        XCTAssertEqual(
            bundle.turnLifecycleEvents.count, 1)
        XCTAssertEqual(
            bundle.planAssignmentEvents.count, 1)
        XCTAssertEqual(bundle.totalEventCount, 3,
            "cross-session bundle aggregates 3 events" +
            " across 2 sessions across 3 payload kinds")
    }

    func testProjectAcrossAllSessionsEmptyStorageYieldsEmpty() async {
        let storage = BASInMemoryEventLogStorage()
        let bundle = await BASEventLogProjectors
            .projectAcrossAllSessions(from: storage)
        XCTAssertEqual(bundle, .empty,
            "empty storage → empty bundle")
    }

    // MARK: - Composition with merging

    func testProjectPerSessionThenMergingIsConsistent() async throws {
        // Build storage with events in 2 sessions,then
        // verify per-session-project+merge produces the
        // same kinds/counts as cross-session-project (the
        // ordering may differ across sessions because of
        // session vs global ordering,but per-kind
        // counts must be identical)。
        let storage = BASInMemoryEventLogStorage()
        _ = try await storage.append(
            BASEventLogEntry.memoryAtomEvent(
                eventID: "e1",
                timestampMs: 100,
                sessionID: "sX",
                payload: makeMemoryAtomPayload(
                    atomID: "x1")))
        _ = try await storage.append(
            BASEventLogEntry.memoryAtomEvent(
                eventID: "e2",
                timestampMs: 200,
                sessionID: "sY",
                payload: makeMemoryAtomPayload(
                    atomID: "y1")))
        let perSessionX = await storage
            .events(forSession: "sX")
        let perSessionY = await storage
            .events(forSession: "sY")
        let bundleX = BASEventLogProjectors
            .projectAllPayloadKinds(perSessionX)
        let bundleY = BASEventLogProjectors
            .projectAllPayloadKinds(perSessionY)
        let merged = bundleX.merging(bundleY)
        let crossSession = await BASEventLogProjectors
            .projectAcrossAllSessions(from: storage)
        XCTAssertEqual(
            merged.totalEventCount,
            crossSession.totalEventCount,
            "per-session-project+merge same total count" +
            " as cross-session-project")
        XCTAssertEqual(
            Set(merged.memoryAtomEvents.map {
                $0.atomID }),
            Set(crossSession.memoryAtomEvents.map {
                $0.atomID }),
            "per-session-project+merge same atom set")
    }

    // MARK: - Determinism

    func testProjectAcrossAllSessionsIsDeterministic() async throws {
        let storage = BASInMemoryEventLogStorage()
        _ = try await storage.append(
            BASEventLogEntry.memoryAtomEvent(
                eventID: "det",
                timestampMs: 100,
                sessionID: "s",
                payload: makeMemoryAtomPayload(
                    atomID: "a")))
        let b1 = await BASEventLogProjectors
            .projectAcrossAllSessions(from: storage)
        let b2 = await BASEventLogProjectors
            .projectAcrossAllSessions(from: storage)
        XCTAssertEqual(b1, b2,
            "chapter 三百九二 — same storage state → same" +
            " bundle")
    }

    func testCombiningIsDeterministic() {
        let a = BASEventLogReplayBundle(
            memoryAtomEvents: [
                makeMemoryAtomPayload(atomID: "a")
            ],
            turnLifecycleEvents: [],
            parallelStageEvents: [],
            permitEscalationEvents: [],
            nativeStageDispatchEvents: [],
            planAssignmentEvents: [])
        let r1 = BASEventLogReplayBundle.combining(
            [a, .empty, a])
        let r2 = BASEventLogReplayBundle.combining(
            [a, .empty, a])
        XCTAssertEqual(r1, r2)
        XCTAssertEqual(r1.memoryAtomEvents.count, 2,
            "combining preserves duplicates per input")
    }
}
