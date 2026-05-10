// MARK: - BASModuleConsolidationPolicyTests — chapter 四百三十 / M1093

import XCTest
@testable import BASRuntimeCore

final class BASModuleConsolidationPolicyTests: XCTestCase {

    // MARK: - 4 candidates shipped

    func testFourConsolidationCandidates() {
        XCTAssertEqual(
            BASModuleConsolidationCandidate
                .allCases.count, 4,
            "M1093 ships 4 consolidation candidates: " +
            "chatCompletionsAdapter / mlxAdapter / " +
            "leaseLife / worldPrior")
    }

    func testCandidateRawValuesMatchModuleNames() {
        XCTAssertEqual(
            BASModuleConsolidationCandidate
                .chatCompletionsAdapter.rawValue,
            "BASChatCompletionsAdapter")
        XCTAssertEqual(
            BASModuleConsolidationCandidate
                .mlxAdapter.rawValue,
            "BASMLXAdapter")
        XCTAssertEqual(
            BASModuleConsolidationCandidate
                .leaseLife.rawValue,
            "BASLeaseLife")
        XCTAssertEqual(
            BASModuleConsolidationCandidate
                .worldPrior.rawValue,
            "BASWorldPrior")
    }

    // MARK: - Status enum

    func testThreeConsolidationStatuses() {
        XCTAssertEqual(
            BASModuleConsolidationStatus
                .allCases.count, 3)
        XCTAssertEqual(
            BASModuleConsolidationStatus
                .pendingMerge.rawValue,
            "pending-merge")
        XCTAssertEqual(
            BASModuleConsolidationStatus
                .merged.rawValue, "merged")
        XCTAssertEqual(
            BASModuleConsolidationStatus
                .blocked.rawValue, "blocked")
    }

    // MARK: - Policy entries

    func testFourPolicyEntries() {
        XCTAssertEqual(
            BASModuleConsolidationPolicy
                .entryCount, 4)
    }

    func testAllPendingMergeAtM1093() {
        for entry in BASModuleConsolidationPolicy
            .entries
        {
            XCTAssertEqual(
                entry.status, .pendingMerge,
                "All 4 candidates must be in" +
                " .pendingMerge state at M1093 — actual" +
                " merges are deferred to follow-up" +
                " chapters under explicit user control")
        }
    }

    func testEntryForChatCompletionsAdapter() {
        let entry = BASModuleConsolidationPolicy.entry(
            for: .chatCompletionsAdapter)
        XCTAssertNotNil(entry)
        XCTAssertEqual(entry?.status, .pendingMerge)
        XCTAssertNil(entry?.targetModule,
            "chatCompletionsAdapter is DROPPED, not" +
            " merged into a target module")
        XCTAssertEqual(
            entry?.estimatedLOCDelta, -486)
    }

    func testEntryForLeaseLife() {
        let entry = BASModuleConsolidationPolicy.entry(
            for: .leaseLife)
        XCTAssertEqual(
            entry?.targetModule, "BASAppleAdapters",
            "leaseLife merges INTO BASAppleAdapters")
        XCTAssertEqual(
            entry?.estimatedLOCDelta, 0,
            "leaseLife is MOVED, not deleted (delta=0)")
    }

    func testEntryForWorldPrior() {
        let entry = BASModuleConsolidationPolicy.entry(
            for: .worldPrior)
        XCTAssertEqual(
            entry?.targetModule, "BASRuntimeCore",
            "worldPrior merges INTO BASRuntimeCore")
        XCTAssertEqual(
            entry?.estimatedLOCDelta, 0,
            "worldPrior is MOVED, not deleted")
    }

    // MARK: - Pending merge candidates

    func testAllFourPendingAtM1093() {
        let pending = BASModuleConsolidationPolicy
            .pendingMergeCandidates
        XCTAssertEqual(pending.count, 4)
    }

    // MARK: - Cumulative LOC delta

    func testPendingLOCDeltaIsMinus1610() {
        XCTAssertEqual(
            BASModuleConsolidationPolicy
                .pendingLOCDelta,
            -1610,
            "Pending merges sum to -1,610 LOC: " +
            "-486 (chatCompletions) + -1124 (mlx) + " +
            "0 (leaseLife move) + 0 (worldPrior move)")
    }

    // MARK: - Codable round-trip

    func testEntryCodableRoundTrip() throws {
        let original = BASModuleConsolidationPolicy
            .entries.first!
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(original)
        let decoded = try JSONDecoder()
            .decode(
                BASModuleConsolidationEntry.self,
                from: data)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - Determinism

    func testPolicyIsDeterministic() {
        let a = BASModuleConsolidationPolicy.entries
        let b = BASModuleConsolidationPolicy.entries
        XCTAssertEqual(a, b)
    }
}
