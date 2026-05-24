// MARK: - BASChapter936UserStateFullRowTests
// chapter 九百三十六 / M3385
//
// 3rd SUBSTANCE chapter post-USER-PASS (ch 933) — UserState
// bridge had state(forID:) + latestState(forSession:) as
// `return nil` stubs since chapter 898。
//
// Variation from ch 934/935 recipe:schema stores opaque
// payload_json (BASUserState already JSON-serialized at append
// time)。 FFI just returns the bytes — no per-column construction
// needed。 Swift JSONDecoder reconstructs BASUserState directly。

import XCTest
import BASRuntimeCore
@testable import BASMemory

final class BASChapter936UserStateFullRowTests: XCTestCase {

    private func makeTempDBURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "ch936-\(UUID().uuidString).sqlite")
    }

    private func cleanup(_ url: URL) {
        let fm = FileManager.default
        for suffix in ["", "-wal", "-shm"] {
            let p = url.path + suffix
            if fm.fileExists(atPath: p) {
                try? fm.removeItem(atPath: p)
            }
        }
    }

    private func makeState(
        _ stateID: String, generatedAtMs: Int64 = 1_000
    ) -> BASUserState {
        BASUserState(
            stateID: stateID,
            generatedAtMs: generatedAtMs,
            emotionalTrend: 0.5,
            projectMomentum: -0.3,
            memoryHeat: 0.8,
            riskTrend: 0.2,
            complexityAddictionScore: 0.1,
            agentRouteHistory: ["single-llm", "local-only"],
            lastNEventKinds: ["user.input", "agent.response"])
    }

    /// state(forID:) round-trip — if reverted to `return nil`,
    /// XCTAssertNotNil fails immediately。 chapter 九百四十一 /
    /// M3410 fix MED:added missing field assertions for
    /// generatedAtMs + riskTrend + complexityAddictionScore so
    /// a per-field decode regression surfaces here。
    func testStateForIDRoundTrip() async throws {
        let url = makeTempDBURL()
        defer { cleanup(url) }
        let store = try BASRoutedUserStateStore(
            databaseURL: url)
        let s = makeState("rt-1")
        _ = try await store.append(s, sessionID: "sess-1")
        let read = await store.state(forID: "rt-1")
        XCTAssertNotNil(read,
            "state(forID:) must return appended state " +
            "(REGRESSION:if nil, ch 936 fix reverted to stub)")
        XCTAssertEqual(read?.stateID, "rt-1")
        // chapter 九百四十一 / M3410 — backfilled missing fields
        XCTAssertEqual(read?.generatedAtMs, 1_000)
        XCTAssertEqual(read?.emotionalTrend, 0.5)
        XCTAssertEqual(read?.projectMomentum, -0.3)
        XCTAssertEqual(read?.memoryHeat, 0.8)
        XCTAssertEqual(read?.riskTrend, 0.2)
        XCTAssertEqual(read?.complexityAddictionScore, 0.1)
        XCTAssertEqual(read?.agentRouteHistory,
                       ["single-llm", "local-only"])
        XCTAssertEqual(read?.lastNEventKinds,
                       ["user.input", "agent.response"])
    }

    func testStateForIDNotFoundReturnsNil() async throws {
        let url = makeTempDBURL()
        defer { cleanup(url) }
        let store = try BASRoutedUserStateStore(
            databaseURL: url)
        let read = await store.state(forID: "no-such-id")
        XCTAssertNil(read,
            "unknown state_id must return nil,not error")
    }

    /// latestState(forSession:) — DESC by generated_at_ms,returns
    /// the most-recent state's payload
    func testLatestStateForSessionRoundTrip() async throws {
        let url = makeTempDBURL()
        defer { cleanup(url) }
        let store = try BASRoutedUserStateStore(
            databaseURL: url)

        let earlier = makeState("ls-1", generatedAtMs: 1_000)
        let later = BASUserState(
            stateID: "ls-2",
            generatedAtMs: 2_000,
            emotionalTrend: 0.9,
            projectMomentum: 0.7,
            memoryHeat: 0.5,
            riskTrend: 0.1,
            complexityAddictionScore: 0.2,
            agentRouteHistory: ["multi-llm"],
            lastNEventKinds: ["plan", "act"])

        _ = try await store.append(earlier, sessionID: "ls-sess")
        _ = try await store.append(later, sessionID: "ls-sess")

        let latest = await store.latestState(
            forSession: "ls-sess")
        XCTAssertNotNil(latest)
        XCTAssertEqual(latest?.stateID, "ls-2",
            "latestState must return ls-2 (generatedAtMs=2000) " +
            "not ls-1 (generatedAtMs=1000) per DESC ORDER")
        XCTAssertEqual(latest?.emotionalTrend, 0.9)
        XCTAssertEqual(latest?.agentRouteHistory, ["multi-llm"])
    }

    func testLatestStateForSessionEmptyReturnsNil() async throws {
        let url = makeTempDBURL()
        defer { cleanup(url) }
        let store = try BASRoutedUserStateStore(
            databaseURL: url)
        let read = await store.latestState(
            forSession: "no-such-sess")
        XCTAssertNil(read)
    }

    /// Session-isolation: latestState for one session doesn't
    /// see other sessions' states even if they're newer
    func testLatestStateSessionIsolation() async throws {
        let url = makeTempDBURL()
        defer { cleanup(url) }
        let store = try BASRoutedUserStateStore(
            databaseURL: url)
        // session-A: older
        _ = try await store.append(
            makeState("iso-A", generatedAtMs: 1_000),
            sessionID: "iso-sess-A")
        // session-B: newer
        _ = try await store.append(
            makeState("iso-B", generatedAtMs: 99_999),
            sessionID: "iso-sess-B")
        // latest for A should be iso-A even though iso-B is newer
        let latestA = await store.latestState(
            forSession: "iso-sess-A")
        XCTAssertEqual(latestA?.stateID, "iso-A")
        let latestB = await store.latestState(
            forSession: "iso-sess-B")
        XCTAssertEqual(latestB?.stateID, "iso-B")
    }
}
