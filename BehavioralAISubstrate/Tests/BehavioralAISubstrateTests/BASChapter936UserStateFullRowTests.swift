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

    /// chapter 九百四十二 / M3415 (14P-H3 + 14P-H4) — shared helper
    /// asserting ALL 10 BASUserState Codable fields against the
    /// `makeState(_:generatedAtMs:)` factory's output。 Previously
    /// (ch 941) the 9-field set was inline + only in
    /// testStateForIDRoundTrip — sister tests testLatestState* +
    /// testLatestStateSessionIsolation went unchecked,and
    /// schemaVersion (the 10th persisted field per
    /// `Sources/BASRuntimeCore/BASUserState.swift:89`) was never
    /// asserted in any of the 3 tests。
    private func assertMakeStateRoundTripEquals(
        _ read: BASUserState?,
        stateID expectedID: String,
        generatedAtMs expectedTs: Int64,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertNotNil(read, "state must round-trip", file: file, line: line)
        XCTAssertEqual(read?.stateID, expectedID, file: file, line: line)
        XCTAssertEqual(read?.generatedAtMs, expectedTs, file: file, line: line)
        XCTAssertEqual(read?.schemaVersion,
                       BASUserState.currentSchemaVersion,
                       file: file, line: line)
        XCTAssertEqual(read?.emotionalTrend, 0.5, file: file, line: line)
        XCTAssertEqual(read?.projectMomentum, -0.3, file: file, line: line)
        XCTAssertEqual(read?.memoryHeat, 0.8, file: file, line: line)
        XCTAssertEqual(read?.riskTrend, 0.2, file: file, line: line)
        XCTAssertEqual(read?.complexityAddictionScore, 0.1,
                       file: file, line: line)
        XCTAssertEqual(read?.agentRouteHistory,
                       ["single-llm", "local-only"],
                       file: file, line: line)
        XCTAssertEqual(read?.lastNEventKinds,
                       ["user.input", "agent.response"],
                       file: file, line: line)
    }

    /// state(forID:) round-trip — if reverted to `return nil`,
    /// XCTAssertNotNil fails immediately。 chapter 九百四十一 /
    /// M3410 fix MED:added missing field assertions for
    /// generatedAtMs + riskTrend + complexityAddictionScore so
    /// a per-field decode regression surfaces here。 chapter 九百
    /// 四十二 / M3415 (14P-H3) — added schemaVersion + extracted
    /// `assertMakeStateRoundTripEquals` helper for sister tests。
    func testStateForIDRoundTrip() async throws {
        let url = makeTempDBURL()
        defer { cleanup(url) }
        let store = try BASRoutedUserStateStore(
            databaseURL: url)
        let s = makeState("rt-1")
        _ = try await store.append(s, sessionID: "sess-1")
        let read = await store.state(forID: "rt-1")
        assertMakeStateRoundTripEquals(
            read,
            stateID: "rt-1",
            generatedAtMs: 1_000)
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
    /// the most-recent state's payload。 chapter 九百四十二 / M3415
    /// (14P-H4) — backfilled missing field assertions on `later`
    /// (was only stateID + emotionalTrend + agentRouteHistory;
    /// missing 7 fields including schemaVersion)。
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
        // chapter 九百四十二 / M3415 (14P-H4) — full 10-field check
        XCTAssertEqual(latest?.generatedAtMs, 2_000)
        XCTAssertEqual(latest?.schemaVersion,
                       BASUserState.currentSchemaVersion)
        XCTAssertEqual(latest?.emotionalTrend, 0.9)
        XCTAssertEqual(latest?.projectMomentum, 0.7)
        XCTAssertEqual(latest?.memoryHeat, 0.5)
        XCTAssertEqual(latest?.riskTrend, 0.1)
        XCTAssertEqual(latest?.complexityAddictionScore, 0.2)
        XCTAssertEqual(latest?.agentRouteHistory, ["multi-llm"])
        XCTAssertEqual(latest?.lastNEventKinds, ["plan", "act"])
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
    /// see other sessions' states even if they're newer。 chapter
    /// 九百四十二 / M3415 (14P-H4) — uses shared helper to assert
    /// all 10 fields per state,not just stateID。
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
        assertMakeStateRoundTripEquals(
            latestA, stateID: "iso-A", generatedAtMs: 1_000)
        let latestB = await store.latestState(
            forSession: "iso-sess-B")
        assertMakeStateRoundTripEquals(
            latestB, stateID: "iso-B", generatedAtMs: 99_999)
    }
}
