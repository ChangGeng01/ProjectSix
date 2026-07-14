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

    /// Is this process running OUTSIDE an active console session (detached /
    /// headless / fast-user-switched away)?
    ///
    /// Probe-proven 2026-07-14, outside any test harness: with
    /// `kCGSessionOnConsoleKey` ABSENT and `CGSSessionScreenIsLocked` ALSO absent,
    /// writing a file, setting `.complete`, then flipping to
    /// `.completeUntilFirstUserAuthentication` throws NSCocoaErrorDomain 256 with
    /// underlying POSIX 16 (EBUSY). The kernel enforces the complete class exactly
    /// as it does under a locked screen — but the lock key never appears, so the
    /// screen-lock probe alone reports "unlocked" and the protection tests RED by
    /// environment instead of skipping. That is the inverse of the usual masking
    /// defect: a gate that fails to fire is a FALSE RED, and it makes a green
    /// full-suite run depend on who is sitting at the machine.
    static var consoleIsInactive: Bool {
        #if os(macOS)
        guard let dict = CGSessionCopyCurrentDictionary() as? [String: Any] else { return false }
        // Absent key ⇒ this session owns no active console.
        return !((dict["kCGSessionOnConsoleKey"] as? Bool) ?? false)
        #else
        return false
        #endif
    }

    /// True when the environment cannot honestly exercise complete-class
    /// protection assertions — either the screen is locked, or this session has
    /// no active console.
    static var protectionClassIsEnforced: Bool {
        screenIsLocked || consoleIsInactive
    }

    static func skipIfScreenLocked() throws {
        if screenIsLocked {
            throw XCTSkip("console is LOCKED — macOS 27 enforces NSFileProtectionComplete on "
                + "lock, so complete-class read-backs EPERM; unlock the screen to exercise "
                + "these assertions")
        }
        if consoleIsInactive {
            throw XCTSkip("no ACTIVE CONSOLE for this session (kCGSessionOnConsoleKey absent) "
                + "— macOS 27 enforces NSFileProtectionComplete just as it does on lock, so a "
                + "`.complete` → `.completeUntilFirstUserAuthentication` flip fails EBUSY "
                + "(probe-proven outside the harness). Run the suite from a logged-in, "
                + "on-console session to exercise these assertions.")
        }
    }
}
