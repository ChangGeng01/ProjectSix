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

    func testM1110PostAuditStatusSplit() {
        // M1110 deep-review audit found Qinao SDK
        // imports BASChatCompletionsAdapter +
        // BASMLXAdapter directly,so those flipped to
        // .blocked。 leaseLife + worldPrior remain
        // .pendingMerge (merges are mechanical)。
        let chat = BASModuleConsolidationPolicy.entry(
            for: .chatCompletionsAdapter)
        XCTAssertEqual(chat?.status, .blocked,
            "Qinao SampleHost/main.swift imports it")
        XCTAssertNotNil(chat?.blockedReason)

        let mlx = BASModuleConsolidationPolicy.entry(
            for: .mlxAdapter)
        XCTAssertEqual(mlx?.status, .blocked,
            "8 Qinao SDK consumers")
        XCTAssertNotNil(mlx?.blockedReason)

        let lease = BASModuleConsolidationPolicy.entry(
            for: .leaseLife)
        XCTAssertEqual(lease?.status, .pendingMerge,
            "merge into BASAppleAdapters is mechanical")

        let world = BASModuleConsolidationPolicy.entry(
            for: .worldPrior)
        XCTAssertEqual(world?.status, .pendingMerge,
            "merge into BASRuntimeCore is mechanical")
    }

    func testEntryForChatCompletionsAdapter() {
        let entry = BASModuleConsolidationPolicy.entry(
            for: .chatCompletionsAdapter)
        XCTAssertNotNil(entry)
        XCTAssertEqual(entry?.status, .blocked,
            "M1110 audit flipped to blocked")
        XCTAssertNil(entry?.targetModule,
            "chatCompletionsAdapter is DROP target, not merge")
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

    func testTwoPendingAfterM1110AuditSplit() {
        let pending = BASModuleConsolidationPolicy
            .pendingMergeCandidates
        XCTAssertEqual(pending.count, 2,
            "M1110 audit:flipped chat + mlx to blocked;" +
            " 2 leaf module merges remain pending")
        XCTAssertTrue(pending.contains(.leaseLife))
        XCTAssertTrue(pending.contains(.worldPrior))
    }

    // MARK: - Cumulative LOC delta (post-M1110 audit)

    func testPendingLOCDeltaIsZero() {
        XCTAssertEqual(
            BASModuleConsolidationPolicy
                .pendingLOCDelta,
            0,
            "M1110 audit:after flipping chat + mlx to" +
            " .blocked,only the 2 leaf module merges" +
            " remain pending — both are MOVES not" +
            " deletions (delta=0)。 The -1,610 LOC drop" +
            " is now blocked behind Qinao migration")
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
