import XCTest
import BASMLXAdapter

/// audit devicetestapp MED-5 — the fused-asset state-row width, now Mac-pinned.
/// The M3 chain-fidelity probe reused the M1 toy-probe width (524_288 = GDN state
/// only) instead of the fused row (524_288 + 24_576 = 548_864 = GDN state + conv
/// band), so it allocated a state buffer 24_576 columns short. This pins the single
/// source of truth to the value the generating tool (Tools/qwen35_3asset_fused.py,
/// ROW = GDN_S + GDN_C) actually produces, and reds if the toy-probe width is reused.
final class BASQwen35FusedStateGeometryTests: XCTestCase {

    func testFusedStateRowMatchesGeneratingTool() {
        // The independent ground-truth literal from Tools/qwen35_3asset_fused.py.
        XCTAssertEqual(BASQwen35FusedStateGeometry.row, 548_864,
            "fused ROW must equal Tools/qwen35_3asset_fused.py's GDN_S+GDN_C")
        XCTAssertEqual(BASQwen35FusedStateGeometry.row,
                       BASQwen35FusedStateGeometry.gdnState + BASQwen35FusedStateGeometry.gdnConv,
            "row is the recurrent state PLUS the conv band")
    }

    func testFusedRowIsNotTheToyProbeWidth() {
        // The exact M3 regression: reusing the GDN-only toy-probe width for the
        // fused chain drops the 24_576-wide conv band.
        XCTAssertNotEqual(BASQwen35FusedStateGeometry.row, BASQwen35FusedStateGeometry.gdnState,
            "the fused row must NOT collapse to the M1 toy-probe GDN-only width (524_288)")
        XCTAssertEqual(BASQwen35FusedStateGeometry.gdnConv, 24_576,
            "the dropped conv band is 3·8192")
    }
}
