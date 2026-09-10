// MARK: - BASChapter898UserStateByteEqTests
// chapter 八百九十八 / M3180 — MED-risk migration #3 byte-eq pin

import XCTest
import Foundation
@testable import BASMemory
@testable import BASRuntimeCore
#if os(iOS) || os(macOS)
import BASRustMemoryTrackerBinary
#endif

#if os(iOS) || os(macOS)
final class BASChapter898UserStateByteEqTests: XCTestCase {

    private func makeTempDBURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("ch898-\(UUID().uuidString).db")
    }

    private func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
        try? FileManager.default.removeItem(
            at: URL(fileURLWithPath: url.path + "-wal"))
        try? FileManager.default.removeItem(
            at: URL(fileURLWithPath: url.path + "-shm"))
    }

    private func state(
        id: String,
        at: Int64 = 1_700_000_000_000
    ) -> BASUserState {
        BASUserState(
            stateID: id,
            generatedAtMs: at,
            emotionalTrend: 0.3,
            projectMomentum: 0.5,
            memoryHeat: 0.4,
            riskTrend: -0.2,
            complexityAddictionScore: 0.1,
            agentRouteHistory: ["intent", "search"],
            lastNEventKinds: ["click", "scroll"])
    }

    func testRoutedActorBasicRoundTrip() async throws {
        let url = makeTempDBURL()
        defer { cleanup(url) }
        let routed = try BASRoutedUserStateStore(
            databaseURL: url)
        let total0 = await routed.totalCount
        XCTAssertEqual(total0, 0)
        let r1 = try await routed.append(
            state(id: "s-r1", at: 100), sessionID: "sess-A")
        XCTAssertTrue(r1, "First append returns true")
        let r2 = try await routed.append(
            state(id: "s-r1", at: 200), sessionID: "sess-A")
        XCTAssertFalse(r2,
            "Duplicate state_id append returns false " +
            "(idempotent)")
        let total1 = await routed.totalCount
        XCTAssertEqual(total1, 1,
            "Duplicate did NOT insert second row")
        _ = try await routed.append(
            state(id: "s-r2", at: 300), sessionID: "sess-A")
        _ = try await routed.append(
            state(id: "s-r3", at: 400), sessionID: "sess-B")
        let total2 = await routed.totalCount
        XCTAssertEqual(total2, 3)
        let cA = await routed.countForSession("sess-A")
        let cB = await routed.countForSession("sess-B")
        XCTAssertEqual(cA, 2)
        XCTAssertEqual(cB, 1)
        let latestA = await routed.latestGeneratedAtMs(
            forSession: "sess-A")
        XCTAssertEqual(latestA, 300,
            "Latest generated_at_ms for sess-A is 300 " +
            "(ORDER BY DESC LIMIT 1)")
        let latestMissing = await routed.latestGeneratedAtMs(
            forSession: "sess-missing")
        XCTAssertEqual(latestMissing, -1)
    }

    /// CRITICAL byte-eq vs legacy SQLite actor
    func testByteEqAppendVsSwiftSQLite() async throws {
        let routedURL = makeTempDBURL()
        let swiftURL = makeTempDBURL()
        defer { cleanup(routedURL); cleanup(swiftURL) }
        let routed = try BASRoutedUserStateStore(
            databaseURL: routedURL)
        let swiftActor = try BASSQLiteUserStateStorage(
            databaseURL: swiftURL)
        let states: [(BASUserState, String)] = [
            (state(id: "be-1", at: 100), "s-X"),
            (state(id: "be-2", at: 200), "s-X"),
            (state(id: "be-3", at: 150), "s-X"),
            (state(id: "be-4", at: 500), "s-Y"),
            (state(id: "be-5", at: 400), "s-Y"),
        ]
        for (st, sess) in states {
            let r = try await routed.append(st, sessionID: sess)
            let s = try await swiftActor.append(
                st, sessionID: sess)
            XCTAssertEqual(r, s,
                "append return value byte-eq for " +
                "stateID=\(st.stateID)")
        }
        // Duplicate insert should also byte-equal
        let dupR = try await routed.append(
            state(id: "be-1", at: 999), sessionID: "s-X")
        let dupS = try await swiftActor.append(
            state(id: "be-1", at: 999), sessionID: "s-X")
        XCTAssertEqual(dupR, dupS,
            "Duplicate-insert return value byte-eq")
        XCTAssertFalse(dupR)
        // Counts byte-eq
        let rTotal = await routed.totalCount
        let sTotal = await swiftActor.totalCount
        XCTAssertEqual(rTotal, sTotal)
        XCTAssertEqual(rTotal, 5)
        // Per-session counts via routed.countForSession vs
        // Swift's manifests count via latestState presence
        // (Swift doesn't expose per-session count directly,
        // but routed.countForSession can be compared to
        // routed.totalCount minus other sessions)
        let rCountX = await routed.countForSession("s-X")
        let rCountY = await routed.countForSession("s-Y")
        XCTAssertEqual(rCountX, 3)
        XCTAssertEqual(rCountY, 2)
        // Latest-time byte-eq
        let rLatestX = await routed.latestGeneratedAtMs(
            forSession: "s-X")
        let sLatestX = await swiftActor.latestState(
            forSession: "s-X")?.generatedAtMs
        XCTAssertEqual(rLatestX, sLatestX,
            "Latest generated_at for s-X byte-eq")
        XCTAssertEqual(rLatestX, 200)
    }
}
#endif
