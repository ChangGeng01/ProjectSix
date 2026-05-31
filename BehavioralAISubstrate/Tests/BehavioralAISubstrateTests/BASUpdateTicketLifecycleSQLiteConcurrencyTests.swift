// ch1044 D6 — the off-actor SQLite transaction race.
//
// `save`/`checkpoint`/`load` are `nonisolated async` on a Sendable class, so awaited
// calls run on the GLOBAL concurrent executor (the owner's `persistQuietly()`
// dispatches writes in an unstructured Task). Before the ioLock, two `BEGIN…COMMIT`
// transactions could overlap on the one connection → spurious "transaction within a
// transaction" throws or a DELETE landing inside another save's INSERT loop. The
// internal lock serializes them; this test fires many concurrent ops and asserts
// none throws and the final state is a complete, decodable set.

import XCTest
@testable import BASObservability
@testable import BASRuntimeCore

final class BASUpdateTicketLifecycleSQLiteConcurrencyTests: XCTestCase {

    private var tempRoot: URL!

    override func setUpWithError() throws {
        tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("qinao-lifecycle-concurrency-\(UUID().uuidString)",
                                    isDirectory: true)
        try FileManager.default.createDirectory(
            at: tempRoot, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempRoot { try? FileManager.default.removeItem(at: tempRoot) }
    }

    func testConcurrentSavesAndLoadsDoNotRaceTransactions() async throws {
        let url = tempRoot.appendingPathComponent("concurrency.sqlite")
        let storage = try BASUpdateTicketLifecycleSQLiteStorage(
            url: url, autoCheckpointEvery: 2)  // small threshold → exercise checkpoint too

        // 40 concurrent saves (each DELETE-ALL + INSERT one entry) interleaved with
        // 40 concurrent loads, all on the one connection. The task group rethrows if
        // ANY op throws — which is exactly the spurious transaction race the lock fixes.
        try await withThrowingTaskGroup(of: Void.self) { group in
            for i in 0..<40 {
                group.addTask {
                    let ticket = BASUpdateTicket(
                        ticketID: "t\(i)", sessionRef: "s\(i)",
                        summary: "concurrent \(i)", confidence: 0.7)
                    try await storage.save(
                        ["t\(i)": BASUpdateTicketLifecycleEntry(ticket: ticket)])
                }
                group.addTask { _ = try await storage.load() }
            }
            try await group.waitForAll()
        }

        // Each save replaces the whole table, so the final state is exactly one
        // complete, decodable entry (the last writer) — never a half-written mix.
        let final = try await storage.load()
        XCTAssertEqual(final.count, 1)
        XCTAssertTrue(final.keys.first?.hasPrefix("t") ?? false)
    }
}
