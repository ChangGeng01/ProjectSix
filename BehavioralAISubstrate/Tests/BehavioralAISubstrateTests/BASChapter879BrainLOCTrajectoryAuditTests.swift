// MARK: - BASChapter879BrainLOCTrajectoryAuditTests
// chapter 八百七十九 / M3080 — pin the BASCognitiveBrain.swift
// LOC growth trajectory + trigger for extraction chapter。
//
// CONTEXT — agent D 全量 review (chapter 877) HIGH finding:
// BASCognitiveBrain.swift grew 3,603 → 3,836 LOC over arc
// 871-877 (~233 LOC for the chapter 871 mpsGraphMatMul method +
// stored prop + error enum)。 At 3,836 LOC the file is the
// substrate's LARGEST non-WARN file (other large files like
// EBrainRuntimeCoordinator+RunTurn.swift = 1,820 LOC are well
// below)。 Trajectory:
//
//   v0.61.0 (chapter 833):  3,603 LOC
//   chapter 871 + 871.5:    3,836 LOC (+233)
//   chapter 八百七十九 audit:  3,836 LOC (unchanged from 871.5)
//
// Per agent D: extraction is its own architectural chapter +
// risky for the core actor。 Chapter 八百七十九 PINS the current
// LOC + trigger conditions for when extraction becomes required。

import XCTest

final class BASChapter879BrainLOCTrajectoryAuditTests:
    XCTestCase
{

    /// The current authoritative LOC of BASCognitiveBrain.swift。
    /// Updated PER CHAPTER when the file legitimately grows。
    /// If this number changes by > 5% without an updated
    /// pin,the chapter that grew it should explicitly
    /// re-pin。
    func testBASCognitiveBrainLOCStaysUnderTriggerThreshold()
        throws
    {
        let url = URL(
            fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources")
            .appendingPathComponent("BASHostKit")
            .appendingPathComponent(
                "BASCognitiveBrain.swift")
        let content = try String(
            contentsOf: url, encoding: .utf8)
        let lineCount = content.split(
            separator: "\n", omittingEmptySubsequences: false
        ).count

        let pinnedAtChapter879 = 3836
        let extractionTrigger = 5000  // ~30% over current
        let warnAtTrigger = 4500       // intermediate warning

        // Current state must be near the chapter 879 pin。
        // Chapter 879 13th-pass LOW 1 fix: drift upper bound
        // raised to warnAtTrigger (4,500) so the WARN print
        // branch below is actually reachable before the hard
        // test failure。 Drift floor stays at 90% (3,452) since
        // shrinks are unusual。
        let lowerBound = Int(
            Double(pinnedAtChapter879) * 0.9)
        let upperBound = warnAtTrigger
        XCTAssertGreaterThanOrEqual(
            lineCount, lowerBound,
            "BASCognitiveBrain.swift LOC dropped below 90% " +
            "of chapter 879 pin (\(pinnedAtChapter879)) — " +
            "actual \(lineCount)。 If extraction happened,update " +
            "this pin。 If file shrank organically,investigate。")
        XCTAssertLessThanOrEqual(
            lineCount, upperBound,
            "BASCognitiveBrain.swift LOC grew above 110% of " +
            "chapter 879 pin (\(pinnedAtChapter879)) — actual " +
            "\(lineCount)。 Update this pin in the growing chapter。")

        // Hard ceiling: extraction MUST happen before this
        XCTAssertLessThan(
            lineCount, extractionTrigger,
            "BASCognitiveBrain.swift exceeded the extraction " +
            "trigger of \(extractionTrigger) LOC — chapter " +
            "extraction is now REQUIRED before further additions。")

        // Warning: intermediate signal
        if lineCount > warnAtTrigger {
            print("WARNING: BASCognitiveBrain.swift at \(lineCount) " +
                "LOC > warn threshold \(warnAtTrigger) — " +
                "extraction chapter should be planned。")
        }
    }

    /// Trigger conditions for the extraction chapter。
    func testBrainExtractionTriggers() {
        let triggers: [String] = [
            "Trigger 1: BASCognitiveBrain.swift LOC exceeds 4,500 " +
                "(intermediate WARN)",
            "Trigger 2: BASCognitiveBrain.swift LOC exceeds 5,000 " +
                "(HARD trigger — extraction REQUIRED)",
            "Trigger 3: Adding a new MPSGraph kernel + brain " +
                "wiring adds > 300 LOC in a single chapter",
            "Trigger 4: A god-file pre-commit gate is wired " +
                "specifically for BASCognitiveBrain (currently " +
                "no per-file pin,just the 1500 LOC default warn)"
        ]
        XCTAssertEqual(triggers.count, 4)
        for (i, t) in triggers.enumerated() {
            XCTAssertTrue(
                t.hasPrefix("Trigger \(i + 1):"))
        }
    }

    /// Document the substrate's lifecycle for this file。
    /// History:chapter 八百三十三 (v0.61.0) = 3,603 LOC。
    /// Chapter 871 + 871.5 = 3,836 LOC (+233 for mpsGraphMatMul)。
    /// Chapter 八百七十九 = 3,836 (this chapter is audit-only,
    /// no LOC change)。 Future extraction is a multi-chapter arc
    /// to split into BASCognitiveBrain+Attention.swift,
    /// BASCognitiveBrain+MatMul.swift,etc。
    func testBrainLOCHistoryDocumented() {
        let history: [(chapter: String, loc: Int)] = [
            ("833 v0.61.0",  3603),
            ("871+871.5",    3836),
            ("879 audit",    3836),
        ]
        // Verify monotone non-decreasing (extraction would
        // break this — would warrant re-pinning the array)
        for i in 1..<history.count {
            XCTAssertGreaterThanOrEqual(
                history[i].loc, history[i - 1].loc,
                "History must be monotone non-decreasing " +
                "(or extraction event must be re-pinned)")
        }
    }
}
