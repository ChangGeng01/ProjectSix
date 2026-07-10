import XCTest
@testable import BASMLXAdapter

/// device-recon id9: Mac teeth for the spill-quantize-under-pressure DECISION —
/// the one Mac-side lever that bounds LOW-16's transient. Quantize the parked KV
/// to int8 only when spilling under real memory pressure (headroom ≤ 0.10 of the
/// cap); keep fp16 exactness on the idle (nil-headroom) dream-loop path. The
/// memory/quality EFFECT is device-verified; the decision is pinned here.
final class BASSpillQuantizeTests: XCTestCase {

    func testQuantizesOnlyUnderPressure() {
        XCTAssertTrue(MLXOrganAdapter._spillQuantizeUnderPressure(headroomFrac: 0.08),
            "8% headroom is under pressure ⇒ quantize (halve the transient)")
        XCTAssertTrue(MLXOrganAdapter._spillQuantizeUnderPressure(headroomFrac: 0.10),
            "the 0.10 threshold is inclusive (<=)")
        XCTAssertFalse(MLXOrganAdapter._spillQuantizeUnderPressure(headroomFrac: 0.30),
            "30% headroom is fine ⇒ keep fp16 exactness")
        XCTAssertFalse(MLXOrganAdapter._spillQuantizeUnderPressure(headroomFrac: nil),
            "the idle dream-loop path (nil headroom) always keeps fp16")
    }

    func testKillSwitchForcesFp16() {
        setenv("BAS_SPILL_QUANTIZE_UNDER_PRESSURE", "0", 1)
        defer { unsetenv("BAS_SPILL_QUANTIZE_UNDER_PRESSURE") }
        XCTAssertFalse(MLXOrganAdapter._spillQuantizeUnderPressureEnabled)
        XCTAssertFalse(MLXOrganAdapter._spillQuantizeUnderPressure(headroomFrac: 0.05),
            "kill-switch ⇒ always fp16 even under pressure")
    }
}
