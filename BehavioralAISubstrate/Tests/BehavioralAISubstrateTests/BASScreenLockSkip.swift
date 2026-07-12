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
    static var screenIsLocked: Bool {
        #if os(macOS)
        guard let dict = CGSessionCopyCurrentDictionary() as? [String: Any] else { return false }
        return (dict["CGSSessionScreenIsLocked"] as? Bool) ?? false
        #else
        return false
        #endif
    }

    static func skipIfScreenLocked() throws {
        if screenIsLocked {
            throw XCTSkip("console is LOCKED — macOS 27 enforces NSFileProtectionComplete on "
                + "lock, so complete-class read-backs EPERM; unlock the screen to exercise "
                + "these assertions")
        }
    }
}
