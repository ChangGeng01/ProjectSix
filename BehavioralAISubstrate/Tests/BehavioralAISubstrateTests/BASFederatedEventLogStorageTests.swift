// MARK: - BASFederatedEventLogStorageTests
// chapter 四百四十五 / M1157-M1158-M1159 — POST-RADICAL Wave 16

import XCTest
@testable import BASRuntimeCore
@testable import BASMemory
@testable import BASHostKit

/// Integration tests for the M1157
/// `BASFederatedEventLogStorage` actor wrapping N
/// `BASEventLogStorage` backends and presenting them as
/// ONE unified event log。
///
/// Coverage:
///   - Construction with 0 / 1 / N backends
///   - Append routes to primary backend (default + custom
///     index)
///   - Append throws .noBackends when constructed empty
///   - Reads aggregate from all backends with proper
///     global ordering (timestampMs ASC, sequenceNumber
///     ASC)
///   - sinceTimestampMs cutoff applied across all backends
///   - limit cap applied AFTER global sort
///   - totalCount sums across backends
///   - pruneEventsBefore propagates + sums removed counts
///   - Federated storage IS-A BASEventLogStorage —
///     projectAcrossAllSessions(from:) accepts it
final class BASFederatedEventLogStorageTests:
    XCTestCase
{

    // MARK: - Fixture builders

    private func makeMemoryAtomEntry(
        eventID: String,
        timestampMs: Int64,
        sessionID: String,
        atomID: String
    ) -> BASEventLogEntry {
        let payload = BASMemoryAtomEventPayload(
            op: .removed,
            atomID: atomID)
        return BASEventLogEntry.memoryAtomEvent(
            eventID: eventID,
            timestampMs: timestampMs,
            sessionID: sessionID,
            payload: payload)
    }

    // MARK: - Construction + backend count

    func testEmptyBackendsAllowedAtConstruction() async {
        let federated = BASFederatedEventLogStorage(
            backends: [])
        let count = await federated.backendCount
        XCTAssertEqual(count, 0,
            "empty backends array allowed at construction")
        XCTAssertEqual(
            federated.primaryBackendIndex, 0,
            "primary index defaults to 0 even with" +
            " empty backends")
    }

    func testSingleBackendFederation() async {
        let inner = BASInMemoryEventLogStorage()
        let federated = BASFederatedEventLogStorage(
            backends: [inner])
        let count = await federated.backendCount
        XCTAssertEqual(count, 1)
    }

    func testMultiBackendFederation() async {
        let a = BASInMemoryEventLogStorage()
        let b = BASInMemoryEventLogStorage()
        let c = BASInMemoryEventLogStorage()
        let federated = BASFederatedEventLogStorage(
            backends: [a, b, c])
        let count = await federated.backendCount
        XCTAssertEqual(count, 3)
    }

    func testPrimaryBackendIndexClampsToValidRange() async {
        let a = BASInMemoryEventLogStorage()
        let b = BASInMemoryEventLogStorage()
        let outOfBounds = BASFederatedEventLogStorage(
            backends: [a, b], primaryBackendIndex: 99)
        XCTAssertEqual(
            outOfBounds.primaryBackendIndex, 1,
            "primary clamped to valid range (n - 1)")
        let negative = BASFederatedEventLogStorage(
            backends: [a, b], primaryBackendIndex: -5)
        XCTAssertEqual(
            negative.primaryBackendIndex, 0,
            "negative primary clamped to 0")
    }

    // MARK: - Append routing

    func testAppendRoutesToPrimaryBackend() async throws {
        let primary = BASInMemoryEventLogStorage()
        let secondary = BASInMemoryEventLogStorage()
        let federated = BASFederatedEventLogStorage(
            backends: [primary, secondary])
        let entry = makeMemoryAtomEntry(
            eventID: "e1", timestampMs: 100,
            sessionID: "s", atomID: "a1")
        _ = try await federated.append(entry)
        let primaryCount = await primary.totalCount
        let secondaryCount = await secondary.totalCount
        XCTAssertEqual(primaryCount, 1,
            "default primary (idx 0) received the append")
        XCTAssertEqual(secondaryCount, 0,
            "secondary did NOT receive the append")
    }

    func testAppendRoutesToCustomPrimaryIndex() async throws {
        let primary = BASInMemoryEventLogStorage()
        let secondary = BASInMemoryEventLogStorage()
        let federated = BASFederatedEventLogStorage(
            backends: [primary, secondary],
            primaryBackendIndex: 1)
        let entry = makeMemoryAtomEntry(
            eventID: "e1", timestampMs: 100,
            sessionID: "s", atomID: "a1")
        _ = try await federated.append(entry)
        let primaryCount = await primary.totalCount
        let secondaryCount = await secondary.totalCount
        XCTAssertEqual(primaryCount, 0)
        XCTAssertEqual(secondaryCount, 1,
            "custom primaryBackendIndex 1 honored")
    }

    func testAppendThrowsNoBackendsWhenEmpty() async {
        let federated = BASFederatedEventLogStorage(
            backends: [])
        let entry = makeMemoryAtomEntry(
            eventID: "e1", timestampMs: 100,
            sessionID: "s", atomID: "a1")
        do {
            _ = try await federated.append(entry)
            XCTFail("expected .noBackends to throw")
        } catch let e as
            BASFederatedEventLogStorageError
        {
            XCTAssertEqual(e, .noBackends)
        } catch {
            XCTFail(
                "wrong error type: \(error)")
        }
    }

    // MARK: - Read aggregation

    func testEventsForSessionAggregatesAcrossBackends() async throws {
        let a = BASInMemoryEventLogStorage()
        let b = BASInMemoryEventLogStorage()
        // Pre-populate each backend
        _ = try await a.append(
            makeMemoryAtomEntry(
                eventID: "a1", timestampMs: 100,
                sessionID: "s", atomID: "atom-a1"))
        _ = try await b.append(
            makeMemoryAtomEntry(
                eventID: "b1", timestampMs: 110,
                sessionID: "s", atomID: "atom-b1"))
        let federated = BASFederatedEventLogStorage(
            backends: [a, b])
        let events = await federated.events(
            forSession: "s")
        XCTAssertEqual(events.count, 2,
            "events from both backends visible via" +
            " federated reader")
        XCTAssertEqual(
            Set(events.map { $0.eventID }),
            Set(["a1", "b1"]))
    }

    func testEventsSinceTimestampGloballyOrdered() async throws {
        let a = BASInMemoryEventLogStorage()
        let b = BASInMemoryEventLogStorage()
        // Append OUT-OF-ORDER across backends
        _ = try await b.append(
            makeMemoryAtomEntry(
                eventID: "later", timestampMs: 200,
                sessionID: "s", atomID: "later-atom"))
        _ = try await a.append(
            makeMemoryAtomEntry(
                eventID: "earlier", timestampMs: 100,
                sessionID: "s", atomID: "earlier-atom"))
        let federated = BASFederatedEventLogStorage(
            backends: [a, b])
        let events = await federated.events(
            sinceTimestampMs: 0,
            limit: 10)
        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(events[0].eventID, "earlier",
            "global timestamp order: 100ms first")
        XCTAssertEqual(events[1].eventID, "later",
            "global timestamp order: 200ms second")
    }

    func testEventsSinceTimestampRespectsCutoff() async throws {
        let a = BASInMemoryEventLogStorage()
        let b = BASInMemoryEventLogStorage()
        _ = try await a.append(
            makeMemoryAtomEntry(
                eventID: "old", timestampMs: 100,
                sessionID: "s", atomID: "old-atom"))
        _ = try await b.append(
            makeMemoryAtomEntry(
                eventID: "new", timestampMs: 500,
                sessionID: "s", atomID: "new-atom"))
        let federated = BASFederatedEventLogStorage(
            backends: [a, b])
        let recent = await federated.events(
            sinceTimestampMs: 200, limit: 10)
        XCTAssertEqual(recent.count, 1)
        XCTAssertEqual(recent.first?.eventID, "new",
            "cutoff filters older events across all" +
            " backends")
    }

    func testEventsSinceTimestampRespectsLimitAfterGlobalSort() async throws {
        let a = BASInMemoryEventLogStorage()
        let b = BASInMemoryEventLogStorage()
        for i in 0..<3 {
            _ = try await a.append(
                makeMemoryAtomEntry(
                    eventID: "a\(i)",
                    timestampMs: Int64(100 + i * 10),
                    sessionID: "s",
                    atomID: "atom-a\(i)"))
            _ = try await b.append(
                makeMemoryAtomEntry(
                    eventID: "b\(i)",
                    timestampMs: Int64(150 + i * 10),
                    sessionID: "s",
                    atomID: "atom-b\(i)"))
        }
        let federated = BASFederatedEventLogStorage(
            backends: [a, b])
        let capped = await federated.events(
            sinceTimestampMs: 0, limit: 4)
        XCTAssertEqual(capped.count, 4,
            "limit cap applied after global sort")
        XCTAssertEqual(
            capped.map { $0.eventID },
            ["a0", "a1", "a2", "b0"],
            "earliest 4 by timestamp:" +
            " a0=100, a1=110, a2=120, b0=150")
    }

    // MARK: - Aggregate counts

    func testTotalCountSumsAcrossBackends() async throws {
        let a = BASInMemoryEventLogStorage()
        let b = BASInMemoryEventLogStorage()
        _ = try await a.append(
            makeMemoryAtomEntry(
                eventID: "a1", timestampMs: 100,
                sessionID: "s", atomID: "x"))
        _ = try await a.append(
            makeMemoryAtomEntry(
                eventID: "a2", timestampMs: 110,
                sessionID: "s", atomID: "y"))
        _ = try await b.append(
            makeMemoryAtomEntry(
                eventID: "b1", timestampMs: 120,
                sessionID: "s", atomID: "z"))
        let federated = BASFederatedEventLogStorage(
            backends: [a, b])
        let total = await federated.totalCount
        XCTAssertEqual(total, 3,
            "totalCount sums across all backends")
    }

    // MARK: - Prune propagation

    func testPruneEventsBeforePropagatesToAllBackends() async throws {
        let a = BASInMemoryEventLogStorage()
        let b = BASInMemoryEventLogStorage()
        _ = try await a.append(
            makeMemoryAtomEntry(
                eventID: "a-old", timestampMs: 100,
                sessionID: "s", atomID: "x"))
        _ = try await b.append(
            makeMemoryAtomEntry(
                eventID: "b-old", timestampMs: 100,
                sessionID: "s", atomID: "y"))
        _ = try await a.append(
            makeMemoryAtomEntry(
                eventID: "a-new", timestampMs: 500,
                sessionID: "s", atomID: "z"))
        let federated = BASFederatedEventLogStorage(
            backends: [a, b])
        let removed = try await federated
            .pruneEventsBefore(timestampMs: 200)
        XCTAssertEqual(removed, 2,
            "2 events pruned across both backends" +
            " (a-old + b-old)")
        let remaining = await federated.totalCount
        XCTAssertEqual(remaining, 1,
            "only a-new survives")
    }

    // MARK: - Federated IS-A BASEventLogStorage

    func testFederatedConformsToProtocolForProjector() async throws {
        let a = BASInMemoryEventLogStorage()
        let b = BASInMemoryEventLogStorage()
        _ = try await a.append(
            makeMemoryAtomEntry(
                eventID: "a1", timestampMs: 100,
                sessionID: "s", atomID: "atom-from-a"))
        _ = try await b.append(
            makeMemoryAtomEntry(
                eventID: "b1", timestampMs: 200,
                sessionID: "s", atomID: "atom-from-b"))
        let federated = BASFederatedEventLogStorage(
            backends: [a, b])
        // Chapter 443's projectAcrossAllSessions(from:)
        // takes any BASEventLogStorage — federated MUST
        // be drop-in compatible
        let bundle = await BASEventLogProjectors
            .projectAcrossAllSessions(from: federated)
        XCTAssertEqual(
            bundle.memoryAtomEvents.count, 2,
            "chapter 443 cross-session factory accepts" +
            " federated storage as drop-in BASEventLog" +
            "Storage conformer")
        XCTAssertEqual(
            Set(bundle.memoryAtomEvents.map {
                $0.atomID }),
            Set(["atom-from-a", "atom-from-b"]))
    }

    // MARK: - Determinism

    func testReadsAreDeterministicForSameBackendState() async throws {
        let a = BASInMemoryEventLogStorage()
        _ = try await a.append(
            makeMemoryAtomEntry(
                eventID: "det", timestampMs: 100,
                sessionID: "s", atomID: "x"))
        let federated = BASFederatedEventLogStorage(
            backends: [a])
        let r1 = await federated.events(
            sinceTimestampMs: 0, limit: 100)
        let r2 = await federated.events(
            sinceTimestampMs: 0, limit: 100)
        XCTAssertEqual(
            r1.map { $0.eventID },
            r2.map { $0.eventID },
            "chapter 三百九二 — same backend state →" +
            " same federated read")
    }
}
