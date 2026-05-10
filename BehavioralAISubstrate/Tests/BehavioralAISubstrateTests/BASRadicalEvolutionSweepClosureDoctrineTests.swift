// MARK: - BASRadicalEvolutionSweepClosureDoctrineTests
// chapter 四百三十三 / M1106

import XCTest
@testable import BASRuntimeCore

final class BASRadicalEvolutionSweepClosureDoctrineTests:
    XCTestCase
{

    // MARK: - Phase enum

    func testSixPhasesShipped() {
        XCTAssertEqual(
            BASRadicalEvolutionSweepPhase
                .allCases.count, 6,
            "RADICAL EVOLUTION SWEEP shipped 6 phase" +
            " chapters: A/B/C/D/E/F")
    }

    func testPhaseRawValuesAreChapterTags() {
        XCTAssertEqual(
            BASRadicalEvolutionSweepPhase.phaseA.rawValue,
            "chapter 四百二十七")
        XCTAssertEqual(
            BASRadicalEvolutionSweepPhase.phaseF.rawValue,
            "chapter 四百三十二")
    }

    func testChapterTagAccessor() {
        XCTAssertEqual(
            BASRadicalEvolutionSweepPhase.phaseE
                .chapterTag,
            "chapter 四百三十一")
    }

    // MARK: - Sweep boundaries

    func testSweepEntryMNumberIs1080() {
        XCTAssertEqual(
            BASRadicalEvolutionSweepClosureDoctrine
                .sweepEntryMNumber, 1080)
    }

    func testSweepCloseOutMNumberIs1109() {
        XCTAssertEqual(
            BASRadicalEvolutionSweepClosureDoctrine
                .sweepCloseOutMNumber, 1109,
            "M1109 deep-review remediation round 2:" +
            " bumped from 1107 to 1109 (chapter 433" +
            " self-extension covers M1108 + M1109)")
    }

    // MARK: - Sweep directive pin

    func testSweepDirectivePinned() {
        let directive =
            BASRadicalEvolutionSweepClosureDoctrine
                .sweepDirective
        XCTAssertTrue(
            directive.contains("原生利用神经引擎"),
            "directive must include the user's" +
            " '原生利用神经引擎' phrase")
        XCTAssertTrue(
            directive.contains("低熵复杂系统"))
    }

    // MARK: - 6 phase entries

    func testSixPhaseEntries() {
        XCTAssertEqual(
            BASRadicalEvolutionSweepClosureDoctrine
                .phaseEntries.count, 6)
    }

    func testPhaseEntriesChronologicalOrder() {
        let entries =
            BASRadicalEvolutionSweepClosureDoctrine
                .phaseEntries
        for i in 1..<entries.count {
            XCTAssertGreaterThan(
                entries[i].mNumberFirst,
                entries[i-1].mNumberLast,
                "phase entries must be in chronological" +
                " order by M-number")
        }
    }

    func testPhaseAEntryIsFirst() {
        let first =
            BASRadicalEvolutionSweepClosureDoctrine
                .phaseEntries.first
        XCTAssertEqual(first?.phase, .phaseA)
        XCTAssertEqual(first?.mNumberFirst, 1080)
        XCTAssertEqual(first?.mNumberLast, 1083)
    }

    func testPhaseFEntryIsLast() {
        let last =
            BASRadicalEvolutionSweepClosureDoctrine
                .phaseEntries.last
        XCTAssertEqual(last?.phase, .phaseF)
        XCTAssertEqual(last?.mNumberFirst, 1100)
        XCTAssertEqual(last?.mNumberLast, 1103)
    }

    // MARK: - Cumulative metrics

    func testCumulativeCommitsCountIs30() {
        XCTAssertEqual(
            BASRadicalEvolutionSweepClosureDoctrine
                .cumulativeCommitsCount, 30,
            "6 phase chapters × 4 + chapter 433's 6 cuts" +
            " (4 original + 2 deep-review remediations" +
            " M1108 + M1109) = 30。 M1109 self-extension" +
            " bumped from 28 to 30")
    }

    func testCumulativeTestCountApprox() {
        XCTAssertGreaterThan(
            BASRadicalEvolutionSweepClosureDoctrine
                .cumulativeTestCountApprox, 5000,
            "approximate test count must reflect the" +
            " sweep's net additions")
    }

    // MARK: - Deferred operations

    func testElevenDeferredOperations() {
        XCTAssertEqual(
            BASRadicalEvolutionSweepClosureDoctrine
                .deferredOperationCount, 11,
            "11 destructive operations explicitly" +
            " deferred under user control")
    }

    func testDeferredOperationsContainModuleDrops() {
        let ops =
            BASRadicalEvolutionSweepClosureDoctrine
                .deferredOperations
        XCTAssertTrue(
            ops.contains {
                $0.contains("BASChatCompletionsAdapter")
            })
        XCTAssertTrue(
            ops.contains {
                $0.contains("BASMLXAdapter")
            })
    }

    func testDeferredOperationsContainMerges() {
        let ops =
            BASRadicalEvolutionSweepClosureDoctrine
                .deferredOperations
        XCTAssertTrue(
            ops.contains {
                $0.contains("BASLeaseLife") &&
                    $0.contains("BASAppleAdapters")
            })
        XCTAssertTrue(
            ops.contains {
                $0.contains("BASWorldPrior") &&
                    $0.contains("BASRuntimeCore")
            })
    }

    func testDeferredOperationsContainV2DefaultFlip() {
        XCTAssertTrue(
            BASRadicalEvolutionSweepClosureDoctrine
                .deferredOperations
                .contains {
                    $0.contains(".v1ByteEqual") &&
                        $0.contains(".nativeV2")
                })
    }

    // MARK: - Codable round-trip per entry

    func testEntryCodableRoundTrip() throws {
        let original =
            BASRadicalEvolutionSweepClosureDoctrine
                .phaseEntries.first!
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(original)
        let decoded = try JSONDecoder()
            .decode(
                BASRadicalEvolutionSweepEntry.self,
                from: data)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - Cumulative summary populated

    func testCumulativeSummaryNonEmpty() {
        let summary =
            BASRadicalEvolutionSweepClosureDoctrine
                .cumulativeSummary
        XCTAssertFalse(summary.isEmpty)
        XCTAssertTrue(
            summary.contains("M1109"),
            "summary must reference the sweep's" +
            " final close-out M-number (bumped from" +
            " M1107 to M1109 by deep-review remediation" +
            " round 2)")
        XCTAssertTrue(
            summary.contains(
                "NATIVE APPLE SILICON FOUNDATION"),
            "summary must reference Phase E milestone")
    }

    // MARK: - Determinism

    func testDoctrineIsDeterministic() {
        let e1 =
            BASRadicalEvolutionSweepClosureDoctrine
                .phaseEntries
        let e2 =
            BASRadicalEvolutionSweepClosureDoctrine
                .phaseEntries
        XCTAssertEqual(e1, e2)
    }
}
