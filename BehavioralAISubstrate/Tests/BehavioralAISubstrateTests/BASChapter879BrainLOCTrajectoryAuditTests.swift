// MARK: - BASChapter879BrainLOCTrajectoryAuditTests
// chapter 八百七十九 / M3080 — pin the BASCognitiveBrain.swift
// LOC growth trajectory + trigger for extraction chapter。
// chapter 一千二十四 — extraction landed; this audit now pins
// the facade file and the extracted BASCognitiveBrain file family。
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

#if !os(iOS)  // ch 1022 source-gate: file-tree audit only meaningful on Mac dev box
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
        let hostKitURL = URL(
            fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources")
            .appendingPathComponent("BASHostKit")
        let url = hostKitURL
            .appendingPathComponent(
                "BASCognitiveBrain.swift")
        let content = try String(
            contentsOf: url, encoding: .utf8)
        let lineCount = content.split(
            separator: "\n", omittingEmptySubsequences: false
        ).count

        let pinnedFacadeAfterExtraction = 635
        let facadeLowerBound = 450
        let facadeWarnAt = 900
        let facadeHardCeiling = 1200

        let familyURLs = try FileManager.default
            .contentsOfDirectory(
                at: hostKitURL,
                includingPropertiesForKeys: nil)
            .filter {
                $0.lastPathComponent.hasPrefix("BASCognitiveBrain")
                    && $0.pathExtension == "swift"
            }
        let familyLineCount = try familyURLs.reduce(0) { total, url in
            let source = try String(contentsOf: url, encoding: .utf8)
            return total + source.split(
                separator: "\n",
                omittingEmptySubsequences: false
            ).count
        }
        let pinnedFamilyAfterExtraction = 4913
        let familyUpperBound = 5600

        XCTAssertGreaterThanOrEqual(
            lineCount, facadeLowerBound,
            "BASCognitiveBrain.swift facade LOC dropped below " +
            "\(facadeLowerBound) — actual \(lineCount)。 If another " +
            "extraction happened,update this post-extraction pin。")
        XCTAssertLessThanOrEqual(
            lineCount, facadeWarnAt,
            "BASCognitiveBrain.swift facade LOC grew above warn " +
            "threshold (\(facadeWarnAt),from post-extraction pin " +
            "\(pinnedFacadeAfterExtraction)) — actual \(lineCount)。")

        XCTAssertLessThan(
            lineCount, facadeHardCeiling,
            "BASCognitiveBrain.swift facade exceeded hard ceiling " +
            "\(facadeHardCeiling) LOC — another extraction pass is " +
            "required before further additions。")

        XCTAssertGreaterThanOrEqual(
            familyLineCount, pinnedFamilyAfterExtraction,
            "BASCognitiveBrain extracted family unexpectedly shrank " +
            "below post-extraction pin \(pinnedFamilyAfterExtraction) " +
            "— actual \(familyLineCount)。 If cleanup happened,repin " +
            "the family trajectory explicitly。")
        XCTAssertLessThanOrEqual(
            familyLineCount, familyUpperBound,
            "BASCognitiveBrain extracted family grew above " +
            "\(familyUpperBound) LOC — actual \(familyLineCount)。 " +
            "Plan a second extraction or repin with justification。")
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
#endif
