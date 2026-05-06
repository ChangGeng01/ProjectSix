import XCTest
@testable import BASMemory

/// chapter 二百五十三 / M740 — `BASMemoryClosedLoopApplier`
/// integration coverage.
///
/// Stage 1 Step 3 of 3 (Memory Importance Loop). The closed-loop
/// applier wires together:
///
///   - `BASMemoryAtomStore` (chapters 二百四十八 / M735, two
///      conformers: in-memory + SQLite-backed).
///   - `BASMemoryUsageTracker` (chapter 二百五十一 / M738).
///   - `BASMemoryImportanceScorer` (chapter 二百五十二 / M739).
///
/// This test suite verifies the **full closed loop**:
///
///   1. record retrieval events
///   2. mark some helped, some not
///   3. apply importance report
///   4. atoms have moved tier per the scorer's recommendations
///
/// Plus the dry-run + rejected-mutation paths.
final class BASMemoryClosedLoopApplierTests: XCTestCase {

    // MARK: - Fixtures

    private let referenceNow = Date(
        timeIntervalSince1970: 1_700_000_000)

    private func makeAtom(
        id: UUID = UUID(),
        tier: BASMemoryTier = .warm,
        content: String = "atom"
    ) -> BASGovernedMemory {
        BASGovernedMemory(
            id: id,
            kind: .episodic,
            content: content,
            scope: .session,
            sensitivity: .low,
            tier: tier,
            confidence: 0.7,
            sourceType: "test",
            governanceStatus: .governed,
            provenanceSummary: "test")
    }

    // MARK: - 1. Empty applier — no mutations on apply

    func testEmptyApplierAppliesNothing() async throws {
        let store = BASInMemoryMemoryAtomStore()
        let tracker = BASMemoryUsageTracker()
        let applier = BASMemoryClosedLoopApplier(
            store: store, tracker: tracker)
        let outcome = await applier.applyImportanceReport(
            atomTiers: [:],
            now: referenceNow)
        XCTAssertEqual(outcome.appliedMutations.count, 0)
        XCTAssertEqual(outcome.rejectedMutations.count, 0)
        XCTAssertEqual(outcome.report.scores.count, 0)
    }

    // MARK: - 2. Forwarding: recordRetrieval lands in tracker

    func testRecordRetrievalForwardsToTracker() async throws {
        let store = BASInMemoryMemoryAtomStore()
        let tracker = BASMemoryUsageTracker()
        let applier = BASMemoryClosedLoopApplier(
            store: store, tracker: tracker)
        _ = try await applier.recordRetrieval(
            atomID: "atom-1",
            sessionRef: "s",
            turnRef: "t",
            permitMode: "answer",
            retrievedAt: referenceNow)
        let count = await tracker.usageCount(forAtomID: "atom-1")
        XCTAssertEqual(count, 1)
    }

    // MARK: - 3. THE KEY TEST — full closed loop, hot atom promoted

    /// Cold atom + 30 helped retrievals in past hour →
    /// applier promotes atom to warm.
    func testFullClosedLoopColdAtomPromoted() async throws {
        let atom = makeAtom(tier: .cold, content: "important")
        let store = BASInMemoryMemoryAtomStore(initial: [atom])
        let tracker = BASMemoryUsageTracker()
        let scorer = BASMemoryImportanceScorer()
        let applier = BASMemoryClosedLoopApplier(
            store: store, tracker: tracker, scorer: scorer)

        // 1. Record 30 retrievals over past hour.
        for i in 0..<30 {
            let ts = referenceNow
                .addingTimeInterval(-Double(i * 60))
            let recordID = try await applier.recordRetrieval(
                atomID: atom.id.uuidString,
                sessionRef: "s",
                turnRef: "t",
                permitMode: "answer",
                retrievedAt: ts)
            // 2. Mark each as helped.
            try await applier.markHelped(
                recordID: recordID, helped: true)
        }

        // 3. Apply report.
        let outcome = await applier.applyImportanceReport(
            atomTiers: [atom.id.uuidString: .cold],
            now: referenceNow)

        // 4. Verify mutation applied: cold → warm.
        XCTAssertEqual(
            outcome.appliedMutations[atom.id.uuidString],
            .warm)
        XCTAssertEqual(outcome.rejectedMutations.count, 0)

        // Verify the store actually mutated the atom.
        let after = await store.atom(forID: atom.id.uuidString)
        XCTAssertEqual(after?.tier, .warm)
    }

    // MARK: - 4. Closed loop demotes stale hot atom

    func testFullClosedLoopHotAtomDemoted() async throws {
        let atom = makeAtom(tier: .hot, content: "stale")
        let store = BASInMemoryMemoryAtomStore(initial: [atom])
        let tracker = BASMemoryUsageTracker()
        let applier = BASMemoryClosedLoopApplier(
            store: store, tracker: tracker)

        // 1 retrieval, week-old, no helped flag = .unknown.
        let weekOld = referenceNow
            .addingTimeInterval(-7 * 86_400)
        _ = try await applier.recordRetrieval(
            atomID: atom.id.uuidString,
            sessionRef: "s", turnRef: "t",
            permitMode: "answer",
            retrievedAt: weekOld)

        let outcome = await applier.applyImportanceReport(
            atomTiers: [atom.id.uuidString: .hot],
            now: referenceNow)

        XCTAssertEqual(
            outcome.appliedMutations[atom.id.uuidString],
            .warm)
        let after = await store.atom(forID: atom.id.uuidString)
        XCTAssertEqual(after?.tier, .warm)
    }

    // MARK: - 5. Dry-run — report computed but no mutations applied

    func testDryRunComputesReportButAppliesNothing()
        async throws
    {
        let atom = makeAtom(tier: .cold)
        let store = BASInMemoryMemoryAtomStore(initial: [atom])
        let tracker = BASMemoryUsageTracker()
        let applier = BASMemoryClosedLoopApplier(
            store: store, tracker: tracker)

        for i in 0..<30 {
            let ts = referenceNow
                .addingTimeInterval(-Double(i * 60))
            let recordID = try await applier.recordRetrieval(
                atomID: atom.id.uuidString,
                sessionRef: "s", turnRef: "t",
                permitMode: "answer",
                retrievedAt: ts)
            try await applier.markHelped(
                recordID: recordID, helped: true)
        }

        let outcome = await applier.applyImportanceReport(
            atomTiers: [atom.id.uuidString: .cold],
            now: referenceNow,
            dryRun: true)

        XCTAssertTrue(outcome.dryRun)
        XCTAssertEqual(outcome.appliedMutations.count, 0)
        // Report still computed.
        XCTAssertGreaterThanOrEqual(
            outcome.report.promotionCount, 1)
        // Store NOT mutated.
        let after = await store.atom(forID: atom.id.uuidString)
        XCTAssertEqual(after?.tier, .cold)
    }

    // MARK: - 6. Hold path — neither promote nor demote

    func testHoldPathLeavesAtomUnchanged() async throws {
        let atom = makeAtom(tier: .warm)
        let store = BASInMemoryMemoryAtomStore(initial: [atom])
        let tracker = BASMemoryUsageTracker()
        let applier = BASMemoryClosedLoopApplier(
            store: store, tracker: tracker)

        // Moderate usage — between thresholds (single
        // retrieval at half-life-ago, helped).
        let halfLifeAgo = referenceNow
            .addingTimeInterval(
                -BASMemoryImportanceScorer
                    .defaultRecencyHalfLifeSeconds)
        let recordID = try await applier.recordRetrieval(
            atomID: atom.id.uuidString,
            sessionRef: "s", turnRef: "t",
            permitMode: "answer",
            retrievedAt: halfLifeAgo)
        try await applier.markHelped(
            recordID: recordID, helped: true)

        let outcome = await applier.applyImportanceReport(
            atomTiers: [atom.id.uuidString: .warm],
            now: referenceNow)

        // No mutation applied.
        XCTAssertEqual(outcome.appliedMutations.count, 0)
        let after = await store.atom(forID: atom.id.uuidString)
        XCTAssertEqual(after?.tier, .warm)
    }

    // MARK: - 7. Rejected mutation — atom dropped between
    //              scoring and apply

    func testMutationRejectedWhenAtomMissingFromStore()
        async throws
    {
        // Store does NOT contain the atom — only the tracker
        // has seen it.
        let store = BASInMemoryMemoryAtomStore()
        let tracker = BASMemoryUsageTracker()
        let applier = BASMemoryClosedLoopApplier(
            store: store, tracker: tracker)

        for i in 0..<30 {
            let ts = referenceNow
                .addingTimeInterval(-Double(i * 60))
            let recordID = try await applier.recordRetrieval(
                atomID: "atom-orphan",
                sessionRef: "s", turnRef: "t",
                permitMode: "answer",
                retrievedAt: ts)
            try await applier.markHelped(
                recordID: recordID, helped: true)
        }

        let outcome = await applier.applyImportanceReport(
            atomTiers: ["atom-orphan": .cold],
            now: referenceNow)

        XCTAssertEqual(outcome.appliedMutations.count, 0)
        XCTAssertEqual(
            outcome.rejectedMutations["atom-orphan"], .warm)
    }

    // MARK: - 8. purgeOldUsage forwarding

    func testPurgeOldUsageForwardsToTracker() async throws {
        let store = BASInMemoryMemoryAtomStore()
        let tracker = BASMemoryUsageTracker()
        let applier = BASMemoryClosedLoopApplier(
            store: store, tracker: tracker)

        let cutoff = referenceNow
            .addingTimeInterval(-3600)
        _ = try await applier.recordRetrieval(
            atomID: "atom-stale",
            sessionRef: "s", turnRef: "t",
            permitMode: "answer",
            retrievedAt: referenceNow
                .addingTimeInterval(-7200))
        _ = try await applier.recordRetrieval(
            atomID: "atom-fresh",
            sessionRef: "s", turnRef: "t",
            permitMode: "answer",
            retrievedAt: referenceNow)

        let purged = try await applier.purgeOldUsage(
            olderThan: cutoff)
        XCTAssertEqual(purged, 1)
        let total = await tracker.recordCount
        XCTAssertEqual(total, 1)
    }

    // MARK: - 9. SQLite-backed store + tracker — closed loop
    //              survives reopen

    /// Demonstrates that the closed loop works end-to-end with
    /// SQLite-backed store + tracker, AND the applied mutations
    /// persist across session restart.
    func testFullClosedLoopSqliteSurvivesReopen() async throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "applier-store-\(UUID().uuidString).sqlite")
        let trackerURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "applier-tracker-\(UUID().uuidString).sqlite")
        defer {
            for url in [storeURL, trackerURL] {
                try? FileManager.default.removeItem(at: url)
                try? FileManager.default.removeItem(
                    at: URL(fileURLWithPath: url.path + "-wal"))
                try? FileManager.default.removeItem(
                    at: URL(fileURLWithPath: url.path + "-shm"))
            }
        }

        let atom = makeAtom(tier: .cold)
        let atomID = atom.id.uuidString

        // Session 1 — record + apply.
        do {
            let store = try BASSQLiteMemoryAtomStore(
                databaseURL: storeURL,
                initial: [atom])
            let tracker = try BASMemoryUsageTracker(
                databaseURL: trackerURL)
            let applier = BASMemoryClosedLoopApplier(
                store: store, tracker: tracker)
            for i in 0..<30 {
                let recordID = try await applier.recordRetrieval(
                    atomID: atomID,
                    sessionRef: "s",
                    turnRef: "t",
                    permitMode: "answer",
                    retrievedAt: referenceNow
                        .addingTimeInterval(-Double(i * 60)))
                try await applier.markHelped(
                    recordID: recordID, helped: true)
            }
            let outcome = await applier.applyImportanceReport(
                atomTiers: [atomID: .cold],
                now: referenceNow)
            XCTAssertEqual(
                outcome.appliedMutations[atomID], .warm)
        }

        // Session 2 — reopen store + verify atom mutated.
        let store2 = try BASSQLiteMemoryAtomStore(
            databaseURL: storeURL)
        let after = await store2.atom(forID: atomID)
        XCTAssertEqual(after?.tier, .warm)
    }
}
