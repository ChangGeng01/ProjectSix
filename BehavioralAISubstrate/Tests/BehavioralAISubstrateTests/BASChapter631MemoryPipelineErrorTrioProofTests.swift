// MARK: - BASChapter631MemoryPipelineErrorTrioProofTests
// chapter 六百三十一 / M1902 — PROOF tests for the M1901
//                              BASMemory pipeline error
//                              trio Codable extension
//                              (3rd post-hexa-#3 gap-
//                              fill)
//
// ## Coverage (3 compile-time conformance tests)
//
// BASMemory pipeline error trio gap-fill — 3 nested-
// in-actor Error enums:
//
//   - BASSQLiteVectorIndexStorage.StorageError
//   - BASMemoryUsageTracker.TrackerError
//   - BASHostCandidatePipeline.PipelineError
//
// THIRD post-hexa-#3 gap-fill chapter (629 + 630 +
// 631)。 NEW kind 'memory-pipeline-error-trio'。
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:test-only additions
//   - chapter 三百九二:replay-determinism extends
//   - chapter 628 hexa #3 + 629 prior post-hexa-#3
//     precedents
//   - ADR-014 OPT-IN preserved
//   - ADR-016 advances M1901 → M1902

import XCTest
@testable import BASMemory

final class BASChapter631MemoryPipelineErrorTrioProofTests:
    XCTestCase
{

    private func assertCodable<T: Codable>(_ type: T.Type) {
        XCTAssertEqual(
            String(describing: type),
            String(describing: type))
    }

    func testBASSQLiteVectorIndexStorageErrorConformsToCodable() {
        assertCodable(
            BASSQLiteVectorIndexStorage.StorageError.self)
    }

    func testBASMemoryUsageTrackerErrorConformsToCodable() {
        assertCodable(
            BASMemoryUsageTracker.TrackerError.self)
    }

    func testBASHostCandidatePipelineErrorConformsToCodable() {
        assertCodable(
            BASHostCandidatePipeline.PipelineError.self)
    }
}
