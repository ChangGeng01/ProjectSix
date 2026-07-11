#if os(macOS)
import CoreGraphics
import XCTest

/// Environmental gate for tests that READ BACK files after setting
/// `FileProtectionType.complete`: on this macOS 27 / Apple Silicon generation the protection
/// class is ENFORCED once the console locks (probe-proven 2026-07-12: write + set complete +
/// read-back fails EPERM "Operation not permitted" while `CGSSessionScreenIsLocked` = true —
/// outside any test harness). The earlier "stored but inert on macOS" behavior is obsolete
/// here. Unlocked runs exercise the real assertions; locked runs skip LOUDLY instead of
/// red-by-environment.
enum BASScreenLockSkip {
    static var screenIsLocked: Bool {
        guard let dict = CGSessionCopyCurrentDictionary() as? [String: Any] else { return false }
        return (dict["CGSSessionScreenIsLocked"] as? Bool) ?? false
    }

    static func skipIfScreenLocked() throws {
        if screenIsLocked {
            throw XCTSkip("console is LOCKED — macOS 27 enforces NSFileProtectionComplete on "
                + "lock, so complete-class read-backs EPERM; unlock the screen to exercise "
                + "these assertions")
        }
    }
}
#endif
