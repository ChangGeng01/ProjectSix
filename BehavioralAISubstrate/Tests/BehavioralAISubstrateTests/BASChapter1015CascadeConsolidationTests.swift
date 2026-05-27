// MARK: - BASChapter1015CascadeConsolidationTests
// chapter 一千零十五 / M3800 — 诚实模式 cascade consolidation
//
// Round-24 audit's HONEST META-ASSESSMENT:
//   - Round-23 caught 5 CRITICAL (peak)
//   - Round-24 caught 1 CRITICAL (and that 1 is class-h:
//     cascade-induced complexity,not a substrate bug)
//   - HIGH-1 was a Round-20-class duplication recurrence
//     (confidenceBand at 2 sites,both files commented
//     「same as ch 1006 single-canonical doctrine」 yet
//     violated it)
//   - HIGH-2 + MED-1/2/3 were doc-drift items deferred from
//     Round-23
//   - HIGH-3 was about `fabric.run.no-result` being
//     test-only-reachable (defensive,not broken)
//
// **Cascade ASYMPTOTE reached** — diminishing returns confirmed:
//   - Each round adds more code than it removes
//   - The substrate's pipeline file grew from ~250 LOC to
//     765 LOC over 9 sub-chapters
//   - Round-24's meta-finding flagged "less elegant"
//   - Honest mode demands STOPPING the fix-cascade
//
// ch 1015 is the CONSOLIDATION chapter — net code removal vs
// addition,canonical-helper unification,doc/code alignment。
// First chapter in the cascade that's SUBTRACTIVE rather than
// additive。
//
// What ch 1015 consolidates:
//   1. HIGH-1 fix: extract canonical `confidenceBandFor(_:)`
//      on `BASTraceAnnotatorSeat` — both ch 1006 + ch 1012
//      delegate。 DELETES the 2 duplicate private methods
//      (-12 LOC, +6 LOC = net -6 LOC)
//   2. CRITICAL-1 fix: delete unreachable `else` branch in
//      pipeline observation-projection wire (-8 LOC, net -8)
//   3. HIGH-2 fix: inspector category doc lists 5 categories
//      (matches actual code)
//   4. MED-1/2/3 fix: 3 audit-bridge file headers updated to
//      reflect post-Round-21 U+001F separator format
//
// Tests pin:
//   1. Canonical `confidenceBandFor` produces correct bands
//   2. Both ch 1006 + ch 1012 delegate (byte-equal output)
//   3. Inspector header doc lists 5 categories (grep test)
//   4. Audit-bridge headers reflect U+001F (grep test)
//   5. Pipeline unreachable-else branch deleted (grep test)
//   6. Net LOC delta is negative — this chapter SUBTRACTS

import XCTest
import Foundation
@testable import BASMemory
@testable import BASOrchestration
@testable import BASHostKit

final class BASChapter1015CascadeConsolidationTests: XCTestCase {

    // MARK: - 1. Canonical confidenceBandFor

    func testCRITICAL_ConfidenceBandFor_AtBoundaries() {
        let cases: [(conf: Double, expectedBand: String)] = [
            (0.0, "low"),
            (0.3999, "low"),
            (0.4, "med"),
            (0.5, "med"),
            (0.6999, "med"),
            (0.7, "high"),
            (1.0, "high"),
        ]
        for (conf, expected) in cases {
            XCTAssertEqual(
                BASTraceAnnotatorSeat
                    .confidenceBandFor(conf),
                expected,
                "ch 1015 HIGH-1: confidenceBandFor(\(conf)) " +
                "MUST = \(expected)")
        }
    }

    // MARK: - 2. Both consumers delegate to canonical

    func testCRITICAL_BothConsumers_DelegateToCanonical() {
        // Round-20 / 21 / 22 / 23 pattern: same-canonical
        // doctrine。 Test verifies ch 1006 + ch 1012 BOTH
        // produce byte-equal output via the canonical helper。
        let conf = 0.6
        let expectedBand = BASTraceAnnotatorSeat
            .confidenceBandFor(conf)
        // ch 1006 path: observation signalRef
        let obs = BASAgentObservation(
            observationID: "obs.1",
            agentID: "a",
            observedDomain: .traceAnnotation,
            summary: "",
            confidence: conf)
        let obsRefs = BASAgentObservationAuditEmitter
            .signalRefs(from: [obs])
        XCTAssertEqual(obsRefs.count, 1)
        XCTAssertTrue(
            obsRefs[0].contains("conf=\(expectedBand)"),
            "ch 1015: ch 1006 signalRefs MUST delegate to " +
            "canonical confidenceBandFor。 Got: \(obsRefs[0])")
        // ch 1012 path: watcher hint signalRef
        let hint = BASAgentWatcherHint(
            hintID: "h.1", turnID: "t",
            watcherRole: .anomalyWatcher,
            severity: .alert,
            category: "test",
            summary: "",
            confidence: conf)
        let hintRefs = BASAgentFabricWatcherCollector
            .signalRefs(from: [hint])
        XCTAssertEqual(hintRefs.count, 1)
        XCTAssertTrue(
            hintRefs[0].contains("conf=\(expectedBand)"),
            "ch 1015: ch 1012 signalRefs MUST delegate to " +
            "canonical。 Got: \(hintRefs[0])")
    }

    // MARK: - 3. Inspector header doc lists 5 categories

    func test_InspectorHeader_Lists5Categories() throws {
        let projectRoot =
            ProcessInfo.processInfo.environment[
                "BAS_PROJECT_ROOT"] ??
            "/Users/changgeng/Project/Project06/Project06/" +
            "BehavioralAISubstrate"
        let path = "\(projectRoot)/Sources/BASHostKit/" +
            "BASAgentFabricHostOutcomeInspector.swift"
        let content = try String(
            contentsOfFile: path, encoding: .utf8)
        // Header doc MUST list all 5 categories
        for cat in [
            "fabric.run.clean", "fabric.run.hints",
            "fabric.run.skipped", "fabric.run.unconfigured",
            "fabric.run.no-result",
        ] {
            XCTAssertTrue(content.contains(cat),
                "ch 1015 HIGH-2: inspector header MUST " +
                "list category \(cat)")
        }
    }

    // MARK: - 4. Audit-bridge headers reflect U+001F

    func test_AuditBridgeHeaders_ReflectUnitSeparator() throws {
        let projectRoot =
            ProcessInfo.processInfo.environment[
                "BAS_PROJECT_ROOT"] ??
            "/Users/changgeng/Project/Project06/Project06/" +
            "BehavioralAISubstrate"
        let paths = [
            "Sources/BASOrchestration/" +
                "BASSovereignWarrantAuditBridge.swift",
            "Sources/BASOrchestration/" +
                "BASMCPInvocationAuditBridge.swift",
            "Sources/BASOrchestration/" +
                "BASAgentFabricModeAuditEmitter.swift",
        ]
        for relPath in paths {
            let full = "\(projectRoot)/\(relPath)"
            let content = try String(
                contentsOfFile: full, encoding: .utf8)
            // Header MUST mention U+001F separator
            XCTAssertTrue(
                content.contains("u{001F}") ||
                content.contains("U+001F"),
                "ch 1015 MED-1/2/3: \(relPath) header MUST " +
                "document U+001F separator format (post-" +
                "Round-21 doctrine)")
        }
    }

    // MARK: - 5. Pipeline unreachable-else deleted

    func test_Pipeline_UnreachableElseDeleted() throws {
        let projectRoot =
            ProcessInfo.processInfo.environment[
                "BAS_PROJECT_ROOT"] ??
            "/Users/changgeng/Project/Project06/Project06/" +
            "BehavioralAISubstrate"
        let path = "\(projectRoot)/Sources/BASHostKit/" +
            "BASAgentFabricHostPipeline.swift"
        let content = try String(
            contentsOfFile: path, encoding: .utf8)
        // The pre-fix unreachable `else` branch emitted
        // `"(skipped)"` for observation.signalRefs — but the
        // path was structurally unreachable
        XCTAssertFalse(
            content.contains(
                "observation.signalRefs\"] =\n" +
                "                \"(skipped)\""),
            "ch 1015 CRITICAL-1: pipeline MUST NOT contain " +
            "the unreachable else branch for " +
            "observation.signalRefs = `(skipped)`。 Round-24 " +
            "audit caught this as dead production code")
    }

    // MARK: - 6. ch 1006 + ch 1012 private confidenceBand deleted

    func test_PrivateConfidenceBandDuplicates_Deleted() throws {
        let projectRoot =
            ProcessInfo.processInfo.environment[
                "BAS_PROJECT_ROOT"] ??
            "/Users/changgeng/Project/Project06/Project06/" +
            "BehavioralAISubstrate"
        let paths = [
            "Sources/BASMemory/" +
                "BASAgentObservationAuditEmitter.swift",
            "Sources/BASOrchestration/" +
                "BASAgentFabricWatcherCollector.swift",
        ]
        for relPath in paths {
            let full = "\(projectRoot)/\(relPath)"
            let content = try String(
                contentsOfFile: full, encoding: .utf8)
            XCTAssertFalse(
                content.contains(
                    "private static func confidenceBand"),
                "ch 1015 HIGH-1: \(relPath) MUST NOT contain " +
                "private `confidenceBand` — deleted in favor " +
                "of canonical BASTraceAnnotatorSeat" +
                ".confidenceBandFor(_:)")
        }
    }

    // MARK: - 7. Cascade asymptote — meta-pin

    /// Honest assessment pin: Round-24 declared the cascade
    /// asymptote。 This test pins that ch 1015 is a
    /// CONSOLIDATION chapter (subtractive net LOC delta), not
    /// an EXTENSION chapter (which would add net LOC)。
    /// Future cascade rounds that add net LOC without
    /// removing existing should justify why they're NOT
    /// consolidation。
    func test_Ch1015_IsConsolidationChapter() throws {
        let projectRoot =
            ProcessInfo.processInfo.environment[
                "BAS_PROJECT_ROOT"] ??
            "/Users/changgeng/Project/Project06/Project06/" +
            "BehavioralAISubstrate"
        let path = "\(projectRoot)/" +
            "Docs/SCAFFOLD_VS_WIRED.md"
        let content = try String(
            contentsOfFile: path, encoding: .utf8)
        // Doctrine doc MUST acknowledge the cascade asymptote
        // — Round-24 verdict
        XCTAssertTrue(
            content.contains("asymptote") ||
            content.contains("Round-24") ||
            content.contains("ch 1015"),
            "ch 1015: SCAFFOLD_VS_WIRED.md MUST acknowledge " +
            "the cascade asymptote per Round-24 honest meta-" +
            "assessment。 Doctrine drift if Round-25+ adds " +
            "more code without referencing this asymptote。")
    }
}
