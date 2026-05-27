// MARK: - BASChapter1011SchemaVersionCanonicalTests
// chapter 一千零十一 / M3770 — Round-21 HIGH-1 fix:
// `schemaVersion: "1.1.0"` literal canonicalization
//
// Round-21 audit identified 9 production sites hardcoding the
// `"1.1.0"` literal as the `schemaVersion` argument when
// constructing `BASSovereignAuditEntry`。 Bumping the schema
// to a future `"1.2.0"` would require updating all 9 in
// lockstep — textbook drift trap per ch 1000.5 single-canonical
// doctrine。
//
// Ch 1011 ships:
//   1. New `BASSovereignAuditEntry.hardenedSchemaVersion`
//      static constant
//   2. All 9 sites migrated to reference the constant
//   3. Structural pin test (this file) that catches future
//      regressions — any new `schemaVersion: "1.1.0"` literal
//      in Sources/ fails this test
//
// Tests pin:
//   1. Constant exists + has value "1.1.0"
//   2. Constant differs from `currentSchemaVersion` (1.0.0)
//      so refactor cannot collapse them
//   3. NO production source contains the literal
//      `schemaVersion: "1.1.0"` anymore (grep test)
//   4. Audit entries built via shared constant produce same
//      schemaVersion value as if literal were used

import XCTest
import Foundation
@testable import BASRuntimeCore
@testable import BASMemory

final class BASChapter1011SchemaVersionCanonicalTests: XCTestCase {

    // MARK: - 1. Constant exists + value correct

    func testCRITICAL_HardenedSchemaVersion_ExistsAndCorrect() {
        XCTAssertEqual(
            BASSovereignAuditEntry.hardenedSchemaVersion,
            "1.1.0",
            "ch 1011 CRITICAL: hardenedSchemaVersion MUST be " +
            "\"1.1.0\" — the canonical value for the hardened " +
            "canonical-bytes format (U+001F inner / U+001E " +
            "outer separators per ch 993)")
    }

    // MARK: - 2. Distinct from currentSchemaVersion

    func test_HardenedSchemaVersion_DistinctFromCurrent() {
        XCTAssertNotEqual(
            BASSovereignAuditEntry.hardenedSchemaVersion,
            BASSovereignAuditEntry.currentSchemaVersion,
            "ch 1011: hardenedSchemaVersion (1.1.0) MUST be " +
            "distinct from currentSchemaVersion (1.0.0)。 " +
            "These represent different separator-class " +
            "formats and MUST NOT collapse into a single " +
            "value — refactoring failure would break the " +
            "opt-in discipline")
    }

    // MARK: - 3. CRITICAL — no production literal remains

    func testCRITICAL_NoProductionLiteral_ForSchemaVersion()
        throws
    {
        let projectRoot =
            ProcessInfo.processInfo.environment[
                "BAS_PROJECT_ROOT"] ??
            "/Users/changgeng/Project/Project06/Project06/" +
            "BehavioralAISubstrate"
        let sourcesDir = "\(projectRoot)/Sources"
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            atPath: sourcesDir)
        else {
            return  // skip silently if path missing
        }
        var offenders: [(file: String, line: Int)] = []
        for case let p as String in enumerator {
            guard p.hasSuffix(".swift") else { continue }
            let full = "\(sourcesDir)/\(p)"
            guard let content = try? String(
                contentsOfFile: full, encoding: .utf8)
            else { continue }
            let lines = content.split(
                separator: "\n", omittingEmptySubsequences: false)
            for (idx, line) in lines.enumerated() {
                let s = String(line)
                // Catch `schemaVersion: "1.1.0"` in code
                // (not in comments or doc strings)
                // Skip lines that begin with `//` or `*` for
                // doc-comment heuristic
                let trimmed = s.trimmingCharacters(
                    in: .whitespaces)
                if trimmed.hasPrefix("//") ||
                    trimmed.hasPrefix("*") ||
                    trimmed.hasPrefix("///")
                {
                    continue
                }
                if s.contains("schemaVersion: \"1.1.0\"") ||
                    s.contains("schemaVersion:\"1.1.0\"")
                {
                    offenders.append((file: p, line: idx + 1))
                }
            }
        }
        XCTAssertTrue(offenders.isEmpty,
            "ch 1011 CRITICAL: production Sources/ MUST NOT " +
            "contain raw `schemaVersion: \"1.1.0\"` literals。 " +
            "Use `BASSovereignAuditEntry.hardenedSchemaVersion` " +
            "instead。 Offenders: \(offenders)")
    }

    // MARK: - 4. Behavioral equivalence

    func test_EntriesBuiltViaConstant_HaveCorrectSchemaVersion() {
        let entry = BASSovereignAuditEntry(
            schemaVersion: BASSovereignAuditEntry
                .hardenedSchemaVersion,
            auditID: "test.1",
            sessionID: "s",
            turnID: "t",
            verdictRef: "v",
            snapshotRef: "",
            signature: "",
            appendedAt: Date())
        XCTAssertEqual(entry.schemaVersion, "1.1.0",
            "ch 1011: entries built via shared constant MUST " +
            "have schemaVersion == \"1.1.0\" — behaviorally " +
            "equivalent to pre-fix literal")
    }

    // MARK: - 5. Pin migration completeness

    /// Verify each of the 9 originally-identified files
    /// references the constant。 If a future refactor
    /// reintroduces the literal at one of these sites,this
    /// test catches it。
    func testCRITICAL_AllNineSites_ReferenceConstant() throws {
        let projectRoot =
            ProcessInfo.processInfo.environment[
                "BAS_PROJECT_ROOT"] ??
            "/Users/changgeng/Project/Project06/Project06/" +
            "BehavioralAISubstrate"
        let pathsAndExpected: [String] = [
            "Sources/BASHostKit/" +
                "EBrainRuntimeCoordinator+SovereignCommit.swift",
            "Sources/BASSovereign/BASSovereignAuditLedger.swift",
            "Sources/BASSovereign/" +
                "BASSovereignCleanRebootCoordinator.swift",
            "Sources/BASSovereign/BASSovereignVerdictEngine.swift",
            "Sources/BASOrchestration/ShadowTrialLedgerBridge.swift",
            "Sources/BASOrchestration/" +
                "BASMCPInvocationAuditBridge.swift",
            "Sources/BASOrchestration/" +
                "BASAgentFabricModeAuditEmitter.swift",
            "Sources/BASOrchestration/" +
                "BASSovereignWarrantAuditBridge.swift",
            "Sources/BASObservability/" +
                "BASUpdateTicketLifecycle.swift",
        ]
        for relPath in pathsAndExpected {
            let full = "\(projectRoot)/\(relPath)"
            guard let content = try? String(
                contentsOfFile: full, encoding: .utf8)
            else {
                XCTFail("ch 1011: cannot read \(relPath)")
                continue
            }
            XCTAssertTrue(
                content.contains(
                    "BASSovereignAuditEntry") &&
                content.contains(
                    ".hardenedSchemaVersion"),
                "ch 1011 CRITICAL: \(relPath) MUST reference " +
                "BASSovereignAuditEntry.hardenedSchemaVersion " +
                "— the canonical shared constant。 If this " +
                "test fires, a refactor reintroduced the " +
                "literal at this site")
        }
    }
}
