import XCTest
@testable import BASRuntimeCore
@testable import BASMemory

final class BASEventLogIngestionRetentionTests: XCTestCase {
    private let floorMs: Int64 = 259_200_000
    private func backdatedEntry(_ id: String) -> BASEventLogEntry {
        BASEventLogEntry(
            eventID: id,
            timestampMs: 100,
            kind: .chat,
            sessionID: "ingestion-retention",
            sequenceNumber: 0)
    }

    func testInMemoryNonpositiveCutoffRetainsAgedNegativeTimestamp() async throws {
        let clock = BASEventLogTestClock(1_000)
        let store = BASInMemoryEventLogStorage(nowMs: clock.now)
        _ = try await store.append(BASEventLogEntry(
            eventID: "negative-sentinel-red",
            timestampMs: -2,
            kind: .chat,
            sessionID: "negative-sentinel",
            sequenceNumber: 0))
        clock.advance(by: floorMs + 1)

        let removed = try await store.pruneEventsBefore(timestampMs: 0)
        let remaining = await store.events(forSession: "negative-sentinel")

        XCTAssertEqual(removed, 0)
        XCTAssertEqual(remaining.map(\.eventID), ["negative-sentinel-red"])
    }

    func testNewlyIngestedBackdatedEventSurvivesInMemoryPrune() async throws {
        let clock = BASEventLogTestClock(1_000)
        let store = BASInMemoryEventLogStorage(nowMs: clock.now)
        _ = try await store.append(backdatedEntry("memory-new"))

        let before = await store.events(forSession: "ingestion-retention")
        XCTAssertEqual(before.map(\.eventID), ["memory-new"])

        let removed = try await store.pruneEventsBefore(timestampMs: 200)

        XCTAssertEqual(removed, 0)
        let after = await store.events(forSession: "ingestion-retention")
        XCTAssertEqual(after.map(\.eventID), ["memory-new"])
    }

    func testNewlyIngestedBackdatedEventSurvivesSQLitePrune() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("bas-ingestion-retention-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true)
        defer {
            XCTAssertNoThrow(try FileManager.default.removeItem(at: directory))
        }

        let clock = BASEventLogTestClock(1_000)
        let store = try BASSQLiteEventLogStorage(
            databaseURL: directory.appendingPathComponent("events.sqlite"),
            nowMs: clock.now)
        _ = try await store.append(backdatedEntry("sqlite-new"))

        let before = try await store.eventsOrThrow(
            forSession: "ingestion-retention")
        XCTAssertEqual(before.map(\.eventID), ["sqlite-new"])

        let removed = try await store.pruneEventsBefore(timestampMs: 200)

        XCTAssertEqual(removed, 0)
        let after = try await store.eventsOrThrow(
            forSession: "ingestion-retention")
        XCTAssertEqual(after.map(\.eventID), ["sqlite-new"])
    }

    func testStrictBoundaryDuplicateAndClockRegressionMatchAcrossBuiltIns() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("bas-ingestion-boundary-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { XCTAssertNoThrow(try FileManager.default.removeItem(at: directory)) }

        let clock = BASEventLogTestClock(10_000)
        let memory = BASInMemoryEventLogStorage(nowMs: clock.now)
        let sqlite = try BASSQLiteEventLogStorage(
            databaseURL: directory.appendingPathComponent("swift.sqlite"), nowMs: clock.now)
        let routed = try BASRoutedEventLogStorage(
            databaseURL: directory.appendingPathComponent("rust.sqlite"), nowMs: clock.now)
        let stores: [any BASEventLogStorage] = [memory, sqlite, routed]

        for (index, store) in stores.enumerated() {
            let original = BASEventLogEntry(
                eventID: "boundary-\(index)",
                timestampMs: 100,
                kind: .chat,
                sessionID: "ingestion-retention",
                sequenceNumber: 0,
                actions: ["original"],
                payloadJson: "{\"version\":1}")
            let first = try await store.append(original)
            clock.set(20_000)
            let duplicate = try await store.append(BASEventLogEntry(
                eventID: original.eventID,
                timestampMs: 999,
                kind: .toolInvocation,
                sessionID: original.sessionID,
                sequenceNumber: 99,
                actions: ["changed"],
                payloadJson: "{\"version\":2}"))
            clock.set(1)
            let regressed = try await store.append(BASEventLogEntry(
                eventID: "regressed-new-\(index)",
                timestampMs: 100,
                kind: .chat,
                sessionID: original.sessionID,
                sequenceNumber: 0,
                payloadJson: "{\"new\":true}"))
            XCTAssertTrue(first.wasNew)
            XCTAssertFalse(duplicate.wasNew)
            XCTAssertEqual(duplicate.assignedSequenceNumber, first.assignedSequenceNumber)
            XCTAssertTrue(regressed.wasNew)
            XCTAssertEqual(regressed.assignedSequenceNumber, first.assignedSequenceNumber + 1)
            let stored = await store.events(forSession: original.sessionID)
            XCTAssertEqual(stored.count, 2)
            XCTAssertEqual(stored[0].timestampMs, original.timestampMs)
            XCTAssertEqual(stored[0].kind, original.kind)
            XCTAssertEqual(stored[0].actions, original.actions)
            XCTAssertEqual(stored[0].payloadJson, original.payloadJson)
            XCTAssertEqual(stored[0].sequenceNumber, first.assignedSequenceNumber)

            clock.set(10_000 + floorMs)
            let removedAtBoundary = try await store.pruneEventsBefore(timestampMs: 200)
            XCTAssertEqual(removedAtBoundary, 0)
            clock.advance(by: 1)
            let removedAfterBoundary = try await store.pruneEventsBefore(timestampMs: 200)
            XCTAssertEqual(removedAfterBoundary, 2)
            clock.set(10_000)
        }
    }

    func testNonpositiveCutoffSentinelsRetainAcrossAllBuiltIns() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("bas-ingestion-sentinels-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { XCTAssertNoThrow(try FileManager.default.removeItem(at: directory)) }
        let clock = BASEventLogTestClock(1_000)
        let stores: [any BASEventLogStorage] = [
            BASInMemoryEventLogStorage(nowMs: clock.now),
            try BASSQLiteEventLogStorage(
                databaseURL: directory.appendingPathComponent("swift.sqlite"), nowMs: clock.now),
            try BASRoutedEventLogStorage(
                databaseURL: directory.appendingPathComponent("rust.sqlite"), nowMs: clock.now),
        ]
        for (index, store) in stores.enumerated() {
            _ = try await store.append(BASEventLogEntry(
                eventID: "sentinel-\(index)", timestampMs: -2, kind: .chat,
                sessionID: "sentinel", sequenceNumber: 0))
        }
        clock.advance(by: floorMs + 1)
        let policyCutoff = BASEventLogRetentionPolicy(maxAgeSec: Int64.max)
            .cutoff(nowMs: Int64.max)
        XCTAssertEqual(policyCutoff, 0)
        for store in stores {
            let directZero = try await store.pruneEventsBefore(timestampMs: 0)
            let directNegative = try await store.pruneEventsBefore(timestampMs: -1)
            let policyZero = try await store.pruneEventsBefore(timestampMs: policyCutoff)
            let retainedCount = await store.totalCount
            XCTAssertEqual(directZero, 0)
            XCTAssertEqual(directNegative, 0)
            XCTAssertEqual(policyZero, 0)
            XCTAssertEqual(retainedCount, 1)
            let positiveControl = try await store.pruneEventsBefore(timestampMs: 1)
            let finalCount = await store.totalCount
            XCTAssertEqual(positiveControl, 1)
            XCTAssertEqual(finalCount, 0)
        }
    }

    func testInvalidAndExtremeStorageClocksMatchAcrossAllBuiltIns() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("bas-ingestion-extreme-clock-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { XCTAssertNoThrow(try FileManager.default.removeItem(at: directory)) }
        let clock = BASEventLogTestClock(Int64.min)
        let stores: [any BASEventLogStorage] = [
            BASInMemoryEventLogStorage(nowMs: clock.now),
            try BASSQLiteEventLogStorage(
                databaseURL: directory.appendingPathComponent("swift.sqlite"), nowMs: clock.now),
            try BASRoutedEventLogStorage(
                databaseURL: directory.appendingPathComponent("rust.sqlite"), nowMs: clock.now),
        ]
        for (index, store) in stores.enumerated() {
            _ = try await store.append(BASEventLogEntry(
                eventID: "minimum-\(index)", timestampMs: -2, kind: .chat,
                sessionID: "extreme", sequenceNumber: 0))
        }
        for now in [Int64.min, floorMs] {
            clock.set(now)
            for store in stores {
                let removed = try await store.pruneEventsBefore(timestampMs: 1)
                XCTAssertEqual(removed, 0)
            }
        }
        clock.set(Int64.max)
        for store in stores {
            let removed = try await store.pruneEventsBefore(timestampMs: 1)
            XCTAssertEqual(removed, 1)
        }
        for (index, store) in stores.enumerated() {
            _ = try await store.append(BASEventLogEntry(
                eventID: "maximum-\(index)", timestampMs: -2, kind: .chat,
                sessionID: "extreme", sequenceNumber: 0))
            let removed = try await store.pruneEventsBefore(timestampMs: 1)
            let retainedCount = await store.totalCount
            XCTAssertEqual(removed, 0)
            XCTAssertEqual(retainedCount, 1)
        }
    }

    func testRetentionPolicyArithmeticFailsClosedAndKeepsPresetValues() {
        XCTAssertEqual(BASEventLogRetentionPolicy.last24Hours.maxAgeSec, 86_400)
        XCTAssertEqual(BASEventLogRetentionPolicy.last72Hours.maxAgeSec, 259_200)
        XCTAssertEqual(
            BASEventLogRetentionPolicy(maxAgeSec: Int64.max).cutoff(nowMs: Int64.max), 0)
        XCTAssertEqual(
            BASEventLogRetentionPolicy(maxAgeSec: 1).cutoff(nowMs: Int64.min), 0)
        XCTAssertEqual(
            BASEventLogRetentionPolicy(maxAgeSec: 1).cutoff(nowMs: 500), 0)
    }

    func testFederationPropagatesIngestionFloorAcrossAllBuiltInBackends() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("bas-ingestion-federation-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { XCTAssertNoThrow(try FileManager.default.removeItem(at: directory)) }
        let clock = BASEventLogTestClock(20_000)
        let memory = BASInMemoryEventLogStorage(nowMs: clock.now)
        let sqlite = try BASSQLiteEventLogStorage(
            databaseURL: directory.appendingPathComponent("swift.sqlite"), nowMs: clock.now)
        let routed = try BASRoutedEventLogStorage(
            databaseURL: directory.appendingPathComponent("rust.sqlite"), nowMs: clock.now)
        _ = try await memory.append(backdatedEntry("federated-memory"))
        _ = try await sqlite.append(backdatedEntry("federated-swift"))
        _ = try await routed.append(backdatedEntry("federated-rust"))
        let federated = BASFederatedEventLogStorage(backends: [memory, sqlite, routed])

        clock.set(20_000 + floorMs)
        let atBoundary = try await federated.pruneEventsBefore(timestampMs: 200)
        XCTAssertEqual(atBoundary, 0)
        clock.advance(by: 1)
        let afterBoundary = try await federated.pruneEventsBefore(timestampMs: 200)
        XCTAssertEqual(afterBoundary, 3)
        let remaining = await federated.totalCount
        XCTAssertEqual(remaining, 0)
    }
}
