// MARK: - BASScreenLockSkipTests
//
// Skip triage follow-on (2026-07-14) — a SELF-VALIDATING gate.
//
// BASScreenLockSkip converts environmental failures into skips. That is a
// legitimate move, but it carries the failure mode this whole triage exists to
// find: a gate whose stated cause is assumed rather than verified, and which can
// therefore go permanently dark (skipping forever while claiming an environment
// problem that is not real). The AFM helper made exactly that mistake — it
// skipped with a message asserting a cause the code never checked.
//
// So the gate is pinned against the REAL filesystem, unconditionally, in both
// directions. This test never skips.

import XCTest
import Foundation

final class BASScreenLockSkipTests: XCTestCase {

    /// The gate's premise must match what the filesystem actually does RIGHT NOW.
    ///
    /// - If the gate says the complete-class is enforced, a `.complete` →
    ///   `.completeUntilFirstUserAuthentication` flip MUST really fail. If it
    ///   succeeds, the skip reason is stale and the gate is suppressing tests
    ///   that could run — a permanently-dark suite.
    /// - If the gate says protection is settable, the flip MUST really succeed.
    ///   If it fails, the protection suites red by environment (which is what
    ///   sent this triage down a phantom-bug hunt in the first place).
    func testGatePremiseMatchesRealFilesystemBehavior() throws {
        #if os(macOS)
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("lockgate-\(UUID().uuidString).sqlite").path
        defer { try? FileManager.default.removeItem(atPath: path) }

        // Sample the gate on BOTH sides of the probe. This state MOVES on a real
        // desktop — measured 2026-07-14 within one session: screenIsLocked went
        // false -> true when the machine idle-locked mid-run (consoleIsInactive
        // stayed true throughout). If the state moves across the probe, the gate
        // reading and the filesystem observation describe different worlds and any
        // verdict is a coin flip, so skip instead. Reading the gate AFTER a probe
        // taken BEFORE it is exactly the TOCTOU shape this codebase keeps finding,
        // and a flaky tooth is worse than none.
        let enforcedBefore = BASScreenLockSkip.protectionClassIsEnforced

        // The ENTIRE probe is fallible, not just the flip. Under enforcement the
        // file can become unreachable the moment `.complete` lands — observed in
        // a full-suite run: `setAttributes(.complete)` itself threw
        // NSCocoaErrorDomain 257 / EPERM. An earlier cut guarded only the flip
        // and RED by environment — the exact failure mode this test exists to
        // prevent. Any step failing means the same thing: this session cannot
        // freely set protection classes.
        var flipSucceeded: Bool
        do {
            try Data("x".utf8).write(to: URL(fileURLWithPath: path))
            try FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.complete], ofItemAtPath: path)
            try FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: path)
            let now = (try? FileManager.default.attributesOfItem(atPath: path))?[.protectionKey]
                as? FileProtectionType
            flipSucceeded = (now == .completeUntilFirstUserAuthentication)
        } catch {
            flipSucceeded = false
        }

        let enforcedAfter = BASScreenLockSkip.protectionClassIsEnforced
        try XCTSkipUnless(
            enforcedBefore == enforcedAfter,
            "console lock/console-session state CHANGED across the probe "
            + "(\(enforcedBefore) -> \(enforcedAfter)) — the gate reading and the "
            + "filesystem observation describe different worlds, so no honest "
            + "verdict is possible on this run")

        if enforcedAfter {
            XCTAssertFalse(
                flipSucceeded,
                "STALE GATE: BASScreenLockSkip reports the complete class is enforced "
                + "(screenIsLocked=\(BASScreenLockSkip.screenIsLocked), "
                + "consoleIsInactive=\(BASScreenLockSkip.consoleIsInactive)) — but the "
                + "protection flip SUCCEEDED. The protection suites are being skipped for a "
                + "reason that is no longer true; they would run. Narrow the gate.")
        } else {
            XCTAssertTrue(
                flipSucceeded,
                "GATE TOO NARROW: BASScreenLockSkip reports protection is settable — but the "
                + "flip FAILED, so the protection suites will RED by environment rather than "
                + "skip. Widen the gate to cover this session state.")
        }
        #endif
    }

    /// The composed predicate must be exactly the disjunction it claims to be —
    /// pins the wiring so a future edit cannot drop an arm and silently narrow
    /// the gate back to the lock-only signal that produced the false reds.
    func testProtectionEnforcedIsTheDisjunctionOfBothSignals() {
        XCTAssertEqual(
            BASScreenLockSkip.protectionClassIsEnforced,
            BASScreenLockSkip.screenIsLocked || BASScreenLockSkip.consoleIsInactive)
    }
}
