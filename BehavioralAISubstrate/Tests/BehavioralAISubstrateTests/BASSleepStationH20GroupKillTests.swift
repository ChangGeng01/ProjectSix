#if os(macOS)
import XCTest
import Foundation
@testable import BASEvaluation

/// audit H20 — the MECHANISM test that closes the false-green.
///
/// The existing BASSleepStationH20Tests only pin the pure DECISION function
/// (`killTargetForTimeout` — which target to pick). Nothing exercised the actual
/// mechanism `kill(-pgid, SIGKILL)` reaping the detached GRANDCHILD (the hung
/// xctest binary), which is the whole point of the H20 fix. This spawns a
/// trivial IDLE group-leader + idle grandchild (honoring the one-heavy-task iron
/// law — `sleep` is not a heavy suite), runs the real decision, dispatches it
/// exactly as production, and asserts the grandchild is actually reaped.
final class BASSleepStationH20GroupKillTests: XCTestCase {

    /// perl makes ITSELF a group leader (setpgrp before fork) so the grandchild
    /// `sleep` is deterministically inside perl's group — no dependence on the
    /// parent's best-effort setpgid race. Prints the grandchild pid, then idles.
    private func spawnGroupLeaderWithIdleGrandchild() throws -> (proc: Process, leaderPid: pid_t, grandPid: pid_t) {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        proc.arguments = ["-e",
            #"setpgrp(0,0); my $g=fork; if(!$g){exec "sleep","600"} $|=1; print "$g\n"; while(1){sleep 1}"#]
        let pipe = Pipe()
        proc.standardOutput = pipe
        try proc.run()
        let leaderPid = proc.processIdentifier
        // Read the first line (the grandchild pid) — perl prints it right after fork.
        let handle = pipe.fileHandleForReading
        var buf = Data()
        let readDeadline = Date().addingTimeInterval(5)
        while Date() < readDeadline, !buf.contains(0x0A) {
            let chunk = handle.availableData
            if chunk.isEmpty { break }   // EOF
            buf.append(chunk)
        }
        guard let nl = buf.firstIndex(of: 0x0A),
              let line = String(data: buf[..<nl], encoding: .utf8),
              let grandPid = pid_t(line.trimmingCharacters(in: .whitespaces)) else {
            proc.terminate()
            throw XCTSkip("could not read grandchild pid from perl harness")
        }
        return (proc, leaderPid, grandPid)
    }

    private func isAlive(_ pid: pid_t) -> Bool { kill(pid, 0) == 0 }

    /// THE MECHANISM: group-kill must reap the GRANDCHILD, not just the leader.
    func testGroupKillReapsIdleGrandchild() throws {
        let (proc, leaderPid, grandPid) = try spawnGroupLeaderWithIdleGrandchild()
        defer { kill(grandPid, SIGKILL); kill(leaderPid, SIGKILL); proc.waitUntilExit() }

        let childPgid = getpgid(leaderPid)
        XCTAssertEqual(childPgid, leaderPid, "perl must be its own group leader (pgid == pid)")
        XCTAssertTrue(isAlive(grandPid), "grandchild sleep must be alive before the kill")

        // The real decision, then dispatch EXACTLY as production does.
        let target = BASSleepMeasurementStation.killTargetForTimeout(
            pid: leaderPid, childPgid: childPgid, ownPgid: getpgrp())
        XCTAssertEqual(target, .group(leaderPid),
            "own-group-leader child (≠ station group) must route to a group-kill")
        switch target {
        case .group(let p):  kill(-p, SIGKILL)
        case .single(let p): kill(p, SIGKILL)
        }

        // Poll: the grandchild must be gone (ESRCH) — the assertion the pure test cannot make.
        var reaped = false
        let deadline = Date().addingTimeInterval(2)
        while Date() < deadline {
            if kill(grandPid, 0) == -1 && errno == ESRCH { reaped = true; break }
            usleep(20_000)
        }
        XCTAssertTrue(reaped,
            "the group-kill must reap the detached GRANDCHILD (sleep 600), not just the leader")
    }

    /// Positive documentation of WHY group-kill is mandatory: a single-pid kill
    /// of the leader leaves the reparented grandchild ALIVE — the exact bug H20 fixed.
    func testSingleKillLeavesGrandchildAlive() throws {
        let (proc, leaderPid, grandPid) = try spawnGroupLeaderWithIdleGrandchild()
        defer { kill(grandPid, SIGKILL); kill(leaderPid, SIGKILL); proc.waitUntilExit() }

        XCTAssertTrue(isAlive(grandPid), "grandchild must be alive before the single-pid kill")
        kill(leaderPid, SIGKILL)   // kill ONLY the leader — NOT the group
        proc.waitUntilExit()
        Thread.sleep(forTimeInterval: 0.3)  // let reparenting settle
        XCTAssertTrue(isAlive(grandPid),
            "a single-pid kill of the leader leaves the reparented grandchild ALIVE "
            + "— this is precisely why the timeout path must group-kill")
    }
}
#endif
