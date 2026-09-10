import XCTest
import BASCSystemBridge

/// audit M-e #4 — `bas_thermal_probe` is an HONEST unsupported stub. Apple
/// platforms expose NO thermal-state sysctl; the real source is
/// `ProcessInfo.thermalState` (read by `BASSystemProbe`). The old code ran a
/// fake `hw.thermal_state` sysctl dance behind a comment claiming it read the
/// thermal state — it always returned -1. These guards catch a future "fix"
/// that makes the C probe fake-succeed (return 0 / .nominal) and be mistaken
/// for a genuine cool-device reading (fail-open on a hot device).
final class BASThermalProbeHonestyTests: XCTestCase {

    func testThermalProbeIsHonestlyUnsupported() {
        var state: Int32 = 99
        let rc = bas_thermal_probe(&state)
        XCTAssertLessThan(rc, 0,
            "no thermal sysctl exists on Apple ⇒ the probe must report failure, never success")
        XCTAssertNotEqual(state, 0,
            "must NEVER present as bucket-0 / .nominal — that would be fail-open on a hot device")
        XCTAssertEqual(state, -1, "the honest unsupported sentinel")
    }

    /// The bucket helper propagates the unsupported failure (never nominal).
    func testThermalBucketIsUnsupportedNotNominal() {
        var bucket: Int32 = 99
        let rc = bas_thermal_bucket(&bucket)
        XCTAssertNotEqual(rc, 0, "an unsupported probe ⇒ the bucket read must fail")
        XCTAssertNotEqual(bucket, 0,
            "the bucket must not fall to nominal(0) on an unsupported probe")
    }
}
