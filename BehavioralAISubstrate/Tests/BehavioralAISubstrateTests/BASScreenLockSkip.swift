import XCTest
#if os(macOS)
import CoreGraphics
#endif

/// Environmental gate for tests that READ BACK files after setting
/// `FileProtectionType.complete`: on the macOS 27 / Apple Silicon generation the protection
/// class is ENFORCED once the console locks (probe-proven 2026-07-12: write + set complete +
/// read-back fails EPERM while `CGSSessionScreenIsLocked` = true — outside any test harness).
/// Unlocked runs exercise the real assertions; locked runs skip LOUDLY instead of
/// red-by-environment.
///
/// CROSS-PLATFORM BY DESIGN (device-bundle lesson, 2026-07-12): the type always exists and
/// `skipIfScreenLocked()` is a NO-OP off macOS — call sites never need platform guards. (The
/// first cut gated the WHOLE FILE behind os(macOS); the un-guarded call sites then broke the
/// device test bundle at compile time — the same defect class the teeth audit caught in the
/// frame-budget lints. On iOS the device must be unlocked to host tests at all, and the
/// protection assertions are the REAL device behavior — no gate wanted.)
enum BASScreenLockSkip {
    /// Is the console explicitly reporting a locked screen?
    ///
    /// `CGSSessionScreenIsLocked` is only PRESENT while the screen is locked, so
    /// an absent key legitimately means "not locked by that signal" — but it is
    /// NOT the only state in which the protection class is enforced. See
    /// `consoleIsInactive`.
    static var screenIsLocked: Bool {
        #if os(macOS)
        guard let dict = CGSessionCopyCurrentDictionary() as? [String: Any] else { return false }
        return (dict["CGSSessionScreenIsLocked"] as? Bool) ?? false
        #else
        return false
        #endif
    }

    /// ⚠️ A `consoleIsInactive` arm was added here on 2026-07-14 and REVERTED the same
    /// day. Recorded so it is not re-derived from the same bad evidence.
    ///
    /// The reasoning was: BASSQLiteFileProtectionTests RED with the flip failing EBUSY
    /// while `CGSSessionScreenIsLocked` was absent, so the lock probe looked too narrow and
    /// `kCGSessionOnConsoleKey` being absent looked like a second enforcement state.
    ///
    /// It was a MISDIAGNOSIS. The failing runs coincided with the disk filling to 100%
    /// (ENOSPC); with the disk freed, the `.complete` -> `.completeUntilFirstUserAuthentication`
    /// flip SUCCEEDS under the identical signals (screenIsLocked=false,
    /// consoleIsInactive=true) that "proved" the widening. So console-inactivity does not
    /// predict enforcement — the widening only suppressed 6 real security tests that pass
    /// fine, which is precisely the permanently-dark gate this file's own self-check exists
    /// to catch. `testGatePremiseMatchesRealFilesystemBehavior` is what caught it.
    ///
    /// LESSON: an environmental gate must be justified by a probe that RE-RUNS, not by one
    /// observation. Co-occurrence is not causation, and a full disk perturbs filesystem
    /// behaviour in ways that mimic a policy gate.
    static var protectionClassIsEnforced: Bool { screenIsLocked }

    static func skipIfScreenLocked() throws {
        if screenIsLocked {
            throw XCTSkip("console is LOCKED — macOS 27 enforces NSFileProtectionComplete on "
                + "lock, so complete-class read-backs EPERM; unlock the screen to exercise "
                + "these assertions")
        }
    }
}
