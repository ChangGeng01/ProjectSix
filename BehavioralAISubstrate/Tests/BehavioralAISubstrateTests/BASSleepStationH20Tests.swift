import XCTest
@testable import BASEvaluation

/// audit H20 (2026-07-07) — the sleep-station timeout path only killed the direct `swift`
/// driver, so the grandchild `xctest` binary (the process that actually hangs at full load)
/// survived, and the station proceeded to the NEXT suite → two heavy processes → the machine
/// froze and had to be restarted.
///
/// The full fix (process-group SIGKILL + halt-the-station) spawns real subprocesses in
/// `runIfPermitted`, which is exactly the heavy work the one-task-at-a-time iron law forbids
/// from a unit test. So the two SAFETY-CRITICAL decisions are extracted as pure functions and
/// pinned here deterministically:
///   1. `killTargetForTimeout` — must NEVER select a group-kill that would SIGKILL the station's
///      own process group (self-protection); only group-kill a child that genuinely detached.
///   2. `suitesToSkipAfterHalt` — after a timeout the station halts, so every remaining suite is
///      reported SKIPPED (never silently dropped, never run as a pile-on).
#if os(macOS)
final class BASSleepStationH20Tests: XCTestCase {

    // MARK: - killTargetForTimeout — self-protection

    func testGroupKillWhenChildIsOwnGroupLeader() {
        // Child detached into its own group (childPgid == pid), distinct from the station's group.
        let t = BASSleepMeasurementStation.killTargetForTimeout(
            pid: 4242, childPgid: 4242, ownPgid: 999)
        XCTAssertEqual(t, .group(4242),
            "a child that is its own group leader must be reaped by group-kill (grandchild included)")
    }

    func testSingleKillWhenChildSharesStationGroup() {
        // setpgid raced the exec → child stayed in the station's group. Group-kill would
        // SIGKILL the station itself. MUST fall back to single-pid.
        let t = BASSleepMeasurementStation.killTargetForTimeout(
            pid: 4242, childPgid: 999, ownPgid: 999)
        XCTAssertEqual(t, .single(4242),
            "must NOT group-kill when the child shares the station's group (would kill ourselves)")
    }

    func testSingleKillWhenChildPgidEqualsOwnPgidEvenIfLeader() {
        // Degenerate guard: childPgid == pid == ownPgid → still single (never -pgid our own group).
        let t = BASSleepMeasurementStation.killTargetForTimeout(
            pid: 999, childPgid: 999, ownPgid: 999)
        XCTAssertEqual(t, .single(999),
            "self-protection wins even if the child's pid coincides with the station's group")
    }

    func testSingleKillWhenChildNotAGroupLeader() {
        // childPgid != pid (some other group) → not a clean leader → single-pid, don't group-kill
        // a group we don't own.
        let t = BASSleepMeasurementStation.killTargetForTimeout(
            pid: 4242, childPgid: 7777, ownPgid: 999)
        XCTAssertEqual(t, .single(4242))
    }

    // MARK: - suitesToSkipAfterHalt

    func testHaltSkipsAllRemainingSuites() {
        let all = ["A", "B", "C", "D"]
        XCTAssertEqual(
            BASSleepMeasurementStation.suitesToSkipAfterHalt(all: all, haltedIndex: 1),
            ["C", "D"],
            "timeout on suite B halts the station — C and D must be skipped, never run")
    }

    func testHaltOnLastSuiteSkipsNothing() {
        let all = ["A", "B", "C"]
        XCTAssertEqual(
            BASSleepMeasurementStation.suitesToSkipAfterHalt(all: all, haltedIndex: 2),
            [],
            "timeout on the final suite leaves nothing to skip")
    }

    func testHaltOnFirstSuiteSkipsRest() {
        let all = ["A", "B", "C"]
        XCTAssertEqual(
            BASSleepMeasurementStation.suitesToSkipAfterHalt(all: all, haltedIndex: 0),
            ["B", "C"])
    }

    func testHaltIndexOutOfRangeIsSafe() {
        XCTAssertEqual(
            BASSleepMeasurementStation.suitesToSkipAfterHalt(all: ["A"], haltedIndex: 5), [])
        XCTAssertEqual(
            BASSleepMeasurementStation.suitesToSkipAfterHalt(all: [], haltedIndex: 0), [])
    }
}
#endif
