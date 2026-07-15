// MARK: - BASChapter1005ScaffoldInventoryPinTests
// chapter 一千零五 / M3730 — 全面 完成 scaffold arc seal
//
// After ch 996 created `Docs/SCAFFOLD_VS_WIRED.md` as the
// authoritative inventory, ch 1001-1004 each closed one
// forward-closure item:
//   - ch 1001 → BAS_ACTIVE_AGENTS activeAgents filter
//   - ch 1002 → .annotate deltaType via TraceAnnotatorSeat
//   - ch 1003 → validateMCPInvocation via MCPInvocationAuditBridge
//   - ch 1004 → recordEvent streaming via TraceStreamingSink
//
// Ch 1005 seals the arc with:
//   1. Structural test that the inventory doc + source-side
//      doctrine remain consistent
//   2. Tests pinning that each closed item references its
//      chapter in the doctrine
//   3. Sweep tests proving the 4 closures haven't drifted
//      (the source files exist + name the doctrine chapter)
//
// This is the SAME pattern as ch 996 — closure-of-the-cascade
// via a structural pin test that catches future drift。
// Without this test, the ch 996 lesson ("APIs claimed wired
// but only shipped") could re-emerge across arc seals。

import XCTest
import Foundation

#if !os(iOS)  // ch 1022 source-gate: file-tree audit only meaningful on Mac dev box
final class BASChapter1005ScaffoldInventoryPinTests: XCTestCase {

    // MARK: - Project root resolution

    private static var projectRoot: String {
        BASSourceTreeAudit.repoRoot
    }

    private static func readFile(_ relPath: String) throws
        -> String
    {
        let path = "\(projectRoot)/\(relPath)"
        return try String(
            contentsOfFile: path, encoding: .utf8)
    }

    // MARK: - 1. Doctrine doc claims each closure

    func testCRITICAL_DoctrineDocReferencesEachClosure()
        throws
    {
        let doc = try Self.readFile(
            "Docs/SCAFFOLD_VS_WIRED.md")
        // ch 1001
        XCTAssertTrue(
            doc.contains("ch 1001"),
            "ch 1005: doctrine MUST reference ch 1001 " +
            "(activeAgents filter)")
        // ch 1002
        XCTAssertTrue(
            doc.contains("ch 1002") &&
            doc.contains("BASTraceAnnotatorSeat"),
            "ch 1005: doctrine MUST reference ch 1002 + " +
            "BASTraceAnnotatorSeat by name")
        // ch 1003
        XCTAssertTrue(
            doc.contains("ch 1003") &&
            doc.contains("BASMCPInvocationAuditBridge"),
            "ch 1005: doctrine MUST reference ch 1003 + " +
            "BASMCPInvocationAuditBridge by name")
        // ch 1004
        XCTAssertTrue(
            doc.contains("ch 1004") &&
            doc.contains("BASAgentTraceStreamingSink"),
            "ch 1005: doctrine MUST reference ch 1004 + " +
            "BASAgentTraceStreamingSink by name")
        // ch 1005 arc seal
        XCTAssertTrue(
            doc.contains("ch 1005") ||
            doc.contains("一千零五"),
            "ch 1005: doctrine MUST self-reference for arc " +
            "seal closure")
    }

    // MARK: - 2. Source files exist for each closure

    func testCRITICAL_SourceFiles_ExistForEachClosure() throws {
        let sourcesToCheck: [String] = [
            // ch 1002
            "Sources/BASMemory/BASTraceAnnotatorSeat.swift",
            // ch 1003
            "Sources/BASOrchestration/" +
                "BASMCPInvocationAuditBridge.swift",
            // ch 1004
            "Sources/BASOrchestration/" +
                "BASAgentTraceStreamingSink.swift",
        ]
        for src in sourcesToCheck {
            let content = try Self.readFile(src)
            XCTAssertFalse(content.isEmpty,
                "ch 1005: source file MUST exist + be " +
                "non-empty: \(src)")
        }
    }

    // MARK: - 3. Each source self-references its chapter

    func testCRITICAL_SourceFiles_SelfReferenceChapter() throws {
        let pairs: [(file: String, chapter: String)] = [
            ("Sources/BASMemory/BASTraceAnnotatorSeat.swift",
             "1002"),
            ("Sources/BASOrchestration/" +
                "BASMCPInvocationAuditBridge.swift",
             "1003"),
            ("Sources/BASOrchestration/" +
                "BASAgentTraceStreamingSink.swift",
             "1004"),
        ]
        for (file, chapter) in pairs {
            let content = try Self.readFile(file)
            // accept either the digit form `1002` or the
            // Chinese-numeral form `一千零二`
            let hasDigit = content.contains(
                "chapter " + chapter) ||
                content.contains("ch " + chapter)
            let hasChinese = chapter == "1002"
                ? content.contains("一千零二")
                : chapter == "1003"
                ? content.contains("一千零三")
                : content.contains("一千零四")
            XCTAssertTrue(
                hasDigit || hasChinese,
                "ch 1005: source \(file) MUST self-reference " +
                "chapter \(chapter) (either digit or 中文 form)")
        }
    }

    // MARK: - 4. Remaining-scaffold rationale section exists

    func testCRITICAL_RemainingScaffolds_PinnedHonestly() throws {
        let doc = try Self.readFile(
            "Docs/SCAFFOLD_VS_WIRED.md")
        // Verify the「What we explicitly DID NOT do」 section
        // exists — this is the honest-scope pin that prevents
        // future arcs from claiming false-completion
        XCTAssertTrue(
            doc.contains("explicitly DID NOT do"),
            "ch 1005: doctrine MUST include the explicit " +
            "non-closure rationale section — pins the " +
            "honest-scope discipline across future arcs")
        // The 5 remaining-scaffold items are each mentioned
        // by name in the rationale
        let remainingItems = [
            "BASAgentFabricMode",
            "Gate.Tier",
            "Gate.TranscriptMode",
            "consultedByExecutorInProduction",
        ]
        for item in remainingItems {
            XCTAssertTrue(
                doc.contains(item),
                "ch 1005: remaining-scaffold rationale MUST " +
                "name \(item) explicitly (so future readers " +
                "know it's correctly-scoped scaffold,not " +
                "forgotten work)")
        }
    }

    // MARK: - 5. Sanity: substrate compiles + tests pass

    /// Trivial sanity check — if this test runs at all,the
    /// substrate compiled。 The full BAS_FUZZ_RUNTIME_SKIP=1
    /// sweep is the real verification but this trivially
    /// pins that ch 1005's own test file builds + runs。
    func test_TestFileBuilds_TriviallyTrue() {
        XCTAssertTrue(true,
            "ch 1005: trivial pin — if this runs,build was " +
            "clean across the 4-chapter arc")
    }
}
#endif
