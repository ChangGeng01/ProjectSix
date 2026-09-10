// MARK: - BASProvenanceRoutedDefaultPinTests
//
// Active regression pin for the PRODUCTION default
// `BASOrganTrainedWeightFilter.useRoutedFilter == true` (the Rust
// routed provenance filter), flipped ON at chapter 七百十七 第五刀 /
// M2260 (commit da2d5a168) on measurement-grounded evidence:
//   - 10/10 byte-equality variants (BASChapter717ProvenanceByte
//     EqualityTests): the routed path produces IDENTICAL `Rejection?`
//     values to the legacy Swift tree, so the flip changes no turn
//     bytes (ADR-014 byte-equal default flip);
//   - ~4.9× perf win (BASChapter717ProvenancePerfTests): Rust ~330–
//     400 ns vs Swift ~2000 ns, well above noise.
//
// WHY THIS FILE EXISTS: the ONLY assertion that pinned this default
// lived in BASChapter717MatrixScorecardTests.testPrintMatrixScorecard,
// which was deactivated at chapter 757 / M2438 via `#if false` (now
// in Archive/Deactivated/) under a note miscalling it "print-only …
// no real assertions" — it actually carried the flag pin。 A silent
// revert of the default would NOT fail CI today。 This mirrors the
// ACTIVE sibling pin on the OFF lane (BASChapter881ForgetCascade
// DeclineAuditTests.testProductionDefaultIsSwift)。
//
// If a future chapter wants to flip this back OFF, it must re-run the
// 717 byte-equality + perf suites, document the new measurement, and
// update this pin — same discipline ch881 enforces on the other lane。

import XCTest
@testable import BASOrgan

final class BASProvenanceRoutedDefaultPinTests: XCTestCase {

    func testProductionDefaultIsRoutedOn() {
        XCTAssertTrue(
            BASOrganTrainedWeightFilter.useRoutedFilter,
            "useRoutedFilter must default TRUE — flipped ON at " +
            "chapter 七百十七 第五刀 / M2260 (da2d5a168) on 10/10 " +
            "byte-equality (BASChapter717ProvenanceByteEqualityTests) " +
            "+ ~4.9× perf (BASChapter717ProvenancePerfTests)。 A flip " +
            "back to the Swift path requires re-running both suites + " +
            "citing the new measurement。")
    }
}
