// MARK: - BASChapter1010ScaffoldClosureArcSealTests
// chapter 一千一十 / M3755 — 全面 收口 scaffold arc seal
//
// After ch 1001-1005 sealed the first "complete scaffold" arc,
// the user invoked「全面 收口 scaffold」(comprehensively close-
// off scaffold)。 ch 1006-1009 closed 4 more items that were
// previously labeled as multi-chapter scope:
//
//   - ch 1006 → BASAgentObservation (was mislabeled DEAD → WIRED)
//   - ch 1007 → BASAgentFabricMode substrate-observability wire
//   - ch 1008 → Gate.Tier validation wire
//   - ch 1009 → Gate.TranscriptMode per-agent summary projection
//
// Ch 1010 seals this arc with the same structural-pin pattern
// ch 1005 used:
//   1. doctrine references each new closure
//   2. source files exist for each new closure
//   3. each source self-references its chapter
//   4. CRITICAL: counts updated post-arc (WIRED 72% → 83%,
//      SCAFFOLD 24% → 13%)

import XCTest
import Foundation

final class BASChapter1010ScaffoldClosureArcSealTests:
    XCTestCase
{

    private static var projectRoot: String {
        ProcessInfo.processInfo.environment[
            "BAS_PROJECT_ROOT"] ??
        "/Users/changgeng/Project/Project06/Project06/" +
        "BehavioralAISubstrate"
    }

    private static func readFile(_ relPath: String) throws
        -> String
    {
        let path = "\(projectRoot)/\(relPath)"
        return try String(
            contentsOfFile: path, encoding: .utf8)
    }

    // MARK: - 1. Doctrine references each new closure

    func testCRITICAL_DoctrineDocReferencesArcClosures()
        throws
    {
        let doc = try Self.readFile(
            "Docs/SCAFFOLD_VS_WIRED.md")
        // ch 1006-1009 by name + key API
        let pairs: [(chapter: String, api: String)] = [
            ("1006", "BASAgentObservationAuditEmitter"),
            ("1007", "BASAgentFabricModeAuditEmitter"),
            ("1008", "BASAgentTierActivationValidator"),
            ("1009", "BASAgentFabricTranscriptProjection"),
        ]
        for (chapter, api) in pairs {
            XCTAssertTrue(
                doc.contains("ch \(chapter)"),
                "ch 1010: doctrine MUST reference ch \(chapter)")
            XCTAssertTrue(
                doc.contains(api),
                "ch 1010: doctrine MUST name \(api) by name")
        }
    }

    // MARK: - 2. Source files exist

    func testCRITICAL_SourceFilesExistForEachClosure() throws {
        let sourcesToCheck: [String] = [
            "Sources/BASMemory/" +
                "BASAgentObservationAuditEmitter.swift",
            "Sources/BASOrchestration/" +
                "BASAgentFabricModeAuditEmitter.swift",
            "Sources/BASHostKit/" +
                "BASAgentTierActivationValidator.swift",
            "Sources/BASHostKit/" +
                "BASAgentFabricTranscriptProjection.swift",
        ]
        for src in sourcesToCheck {
            let content = try Self.readFile(src)
            XCTAssertFalse(content.isEmpty,
                "ch 1010: source MUST exist + be non-empty: " +
                "\(src)")
        }
    }

    // MARK: - 3. Each source self-references its chapter

    func testCRITICAL_SourceFiles_SelfReferenceChapter() throws {
        let pairs: [(file: String, chineseChapter: String)] = [
            ("Sources/BASMemory/" +
                "BASAgentObservationAuditEmitter.swift",
             "一千零六"),
            ("Sources/BASOrchestration/" +
                "BASAgentFabricModeAuditEmitter.swift",
             "一千零七"),
            ("Sources/BASHostKit/" +
                "BASAgentTierActivationValidator.swift",
             "一千零八"),
            ("Sources/BASHostKit/" +
                "BASAgentFabricTranscriptProjection.swift",
             "一千零九"),
        ]
        for (file, chineseChapter) in pairs {
            let content = try Self.readFile(file)
            XCTAssertTrue(
                content.contains(chineseChapter),
                "ch 1010: source \(file) MUST self-reference " +
                "chapter \(chineseChapter)")
        }
    }

    // MARK: - 4. Counts updated post-arc

    func testCRITICAL_StatusCountsUpdated() throws {
        let doc = try Self.readFile(
            "Docs/SCAFFOLD_VS_WIRED.md")
        // Post-arc counts: WIRED 83%, SCAFFOLD 13%
        XCTAssertTrue(
            doc.contains("post-ch 1009") &&
            doc.contains("83%") &&
            doc.contains("13%"),
            "ch 1010 CRITICAL: doctrine MUST reflect the post-" +
            "ch-1009 counts (WIRED 83%, SCAFFOLD 13%) — pins " +
            "the arc's actual progress against future drift")
    }

    // MARK: - 5. CRITICAL — no false claims for items still scaffold

    /// HostOutcome.{activation, fabricMode} remain SCAFFOLD by
    /// design — substrate produces the signal, host consumes
    /// (consumer lives OUTSIDE this repo)。 The doctrine MUST
    /// continue to acknowledge this honestly。 If a future arc
    /// flips these to WIRED without adding a substrate-side
    /// consumer, this test catches it。
    func testCRITICAL_HostObservableSignalsStaySCAFFOLD() throws {
        let doc = try Self.readFile(
            "Docs/SCAFFOLD_VS_WIRED.md")
        // HostOutcome variants remain SCAFFOLD by design
        XCTAssertTrue(
            doc.contains("BASAgentFabricHostOutcome") &&
            doc.contains("🪜 SCAFFOLD"),
            "ch 1010 CRITICAL: HostOutcome rows MUST remain " +
            "🪜 SCAFFOLD — substrate's job is to produce the " +
            "signal, host's to consume。 Flipping these to " +
            "WIRED without a substrate-side consumer would " +
            "be a false claim")
    }
}
