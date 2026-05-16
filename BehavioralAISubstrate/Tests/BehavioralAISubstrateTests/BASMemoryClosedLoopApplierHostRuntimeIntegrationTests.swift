import XCTest
@testable import BASMemory
@testable import BASHostKit

/// chapter 二百七十三 / M760 — `BASMemoryClosedLoopApplier`
/// integration test using `BASHostRuntime` as the substrate
/// session producer.
///
/// Closes self-assessment gap #4 (integration test depth):
/// chapter 二百五十三's applier had unit tests + 1 SQLite cross-
/// session test, but no test exercising the full pipeline with
/// real `BASHostRuntime` driving session creation. This suite
/// proves:
///
///   1. `BASHostRuntime.startSession(...)` produces session
///      refs the applier can consume
///   2. After N substrate-produced sessions + per-session
///      retrieval recording + applyImportanceReport call, the
///      atom store sees the correct tier mutations
///   3. Cross-session SQLite-backed store + tracker preserves
///      mutations + history for the next runtime session
///
/// This is the "host adopts the closed loop" pattern in test
/// form — exactly the integration shape future production
/// hosts will copy.
final class BASMemoryClosedLoopApplierHostRuntimeIntegrationTests:
    XCTestCase
{
    // MARK: - Fixtures

    private let referenceNow = Date(
        timeIntervalSince1970: 1_700_000_000)

    private func makeAtom(
        id: UUID = UUID(),
        tier: BASMemoryTier = .warm,
        content: String = "test atom"
    ) -> BASGovernedMemory {
        BASGovernedMemory(
            id: id,
            kind: .episodic,
            content: content,
            scope: .session,
            sensitivity: .low,
            tier: tier,
            confidence: 0.7,
            sourceType: "host-runtime-integration-test",
            governanceStatus: .governed,
            provenanceSummary: "test-fixture")
    }

    // MARK: - 1. Substrate runtime drives session production +
    //              applier consumes substrate-produced refs

    /// Demonstrates the canonical host pattern:
    ///   1. Host runs N substrate sessions via `BASHostRuntime
    ///      .startSession(...)`.
    ///   2. After each session, host records retrievals on the
    ///      applier with substrate-produced session/turn refs.
    ///   3. Periodically (per N turns or session-end), host
    ///      calls `applier.applyImportanceReport(atomTiers:)`
    ///      with the current store snapshot.
    ///   4. Atoms in the store mutate per scorer recommendations.
    ///
    /// Closes the self-assessment gap "infrastructure ready,
    /// no consumer wired" — this test IS the consumer.
    func testHostRuntimeDrivesClosedLoopWithRealSessions()
        throws
    {
        // M2159 — migrated to sync test + non-detached Task
        // (Diagnostic F pattern) to bypass SIGBUS bucket。
        let promoteAtom = makeAtom(
            tier: .cold, content: "important-cold-atom")
        let demoteAtom = makeAtom(
            tier: .hot, content: "stale-hot-atom")

        let store = BASInMemoryMemoryAtomStore(
            initial: [promoteAtom, demoteAtom])
        let tracker = BASMemoryUsageTracker()
        let scorer = BASMemoryImportanceScorer()
        let applier = BASMemoryClosedLoopApplier(
            store: store,
            tracker: tracker,
            scorer: scorer)

        let runtime = BASHostRuntime(
            configuration: .fixtureGeneric)

        // SYNC PART:run 5 sessions via startSession + extract
        // session/turn refs for actor calls in async Task。
        struct SessionRefs {
            let sessionRef: String
            let turnRef: String
            let permitMode: String
            let sessionIndex: Int
        }
        var allSessionRefs: [SessionRefs] = []
        for sessionIndex in 0..<5 {
            let request = BASHostSessionRequest(
                kind: .interactive,
                workflowProfile: .reflective,
                surface: .application,
                prompt: "session-\(sessionIndex) prompt",
                riskLevel: .medium)
            let result = try runtime.startSession(
                request,
                now: referenceNow.addingTimeInterval(
                    Double(sessionIndex * 60)))
            let sessionRef =
                result.eBrainTurn?.sovereignAuditEntry?
                    .sessionID
                ?? "session-\(sessionIndex)"
            let turnRef =
                result.eBrainTurn?.sovereignAuditEntry?.turnID
                ?? "turn-\(sessionIndex)"
            let permitMode =
                result.eBrainTurn?.actionPermit.mode.rawValue
                ?? "answer"
            allSessionRefs.append(SessionRefs(
                sessionRef: sessionRef,
                turnRef: turnRef,
                permitMode: permitMode,
                sessionIndex: sessionIndex))
        }

        let referenceNowCopy = referenceNow
        let promoteIDCopy = promoteAtom.id.uuidString
        let demoteIDCopy = demoteAtom.id.uuidString

        let exp = expectation(
            description: "BASMemoryClosedLoop-actor-flow")
        Task {
            do {
                for refs in allSessionRefs {
                    for _ in 0..<3 {
                        let recordID = try await applier
                            .recordRetrieval(
                                atomID: promoteIDCopy,
                                sessionRef: refs.sessionRef,
                                turnRef: refs.turnRef,
                                permitMode: refs.permitMode,
                                retrievedAt: referenceNowCopy
                                    .addingTimeInterval(
                                        Double(
                                            refs.sessionIndex
                                                * 60)))
                        try await applier.markHelped(
                            recordID: recordID, helped: true)
                    }
                    if refs.sessionIndex == 0 {
                        _ = try await applier
                            .recordRetrieval(
                                atomID: demoteIDCopy,
                                sessionRef: refs.sessionRef,
                                turnRef: refs.turnRef,
                                permitMode: refs.permitMode,
                                retrievedAt: referenceNowCopy
                                    .addingTimeInterval(
                                        -7 * 86_400))
                    }
                }

                let tierSnapshot: [String: BASMemoryTier] = [
                    promoteIDCopy: .cold,
                    demoteIDCopy: .hot
                ]
                let outcome = await applier
                    .applyImportanceReport(
                        atomTiers: tierSnapshot,
                        now: referenceNowCopy
                            .addingTimeInterval(60 * 5))

                XCTAssertEqual(
                    outcome.appliedMutations[promoteIDCopy],
                    .warm,
                    "promote atom should be tier-mutated to .warm")
                XCTAssertEqual(
                    outcome.appliedMutations[demoteIDCopy],
                    .warm,
                    "stale hot atom should be tier-mutated to .warm")

                let promoteAfter = await store.atom(
                    forID: promoteIDCopy)
                let demoteAfter = await store.atom(
                    forID: demoteIDCopy)
                XCTAssertEqual(
                    promoteAfter?.tier, .warm,
                    "store reflects promote mutation")
                XCTAssertEqual(
                    demoteAfter?.tier, .warm,
                    "store reflects demote mutation")
                exp.fulfill()
            } catch {
                XCTFail(
                    "BASMemoryClosedLoop flow failed: \(error)")
                exp.fulfill()
            }
        }
        wait(for: [exp], timeout: 10.0)
    }

    // MARK: - 2. Cross-session: SQLite store + tracker preserve
    //              mutations across runtime sessions

    /// Demonstrates that when the host uses SQLite-backed store
    /// + tracker (chapter 二百四十八 / 二百五十一) alongside
    /// `BASHostRuntime`, the closed-loop mutations applied in
    /// one runtime session persist to the next.
    func testSQLiteBackedClosedLoopSurvivesRuntimeRestart()
        throws
    {
        // M2159 — migrated to sync test + non-detached Task
        // (Diagnostic F pattern)。
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "applier-runtime-store-" +
                "\(UUID().uuidString).sqlite")
        let trackerURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "applier-runtime-tracker-" +
                "\(UUID().uuidString).sqlite")
        defer {
            for url in [storeURL, trackerURL] {
                try? FileManager.default.removeItem(at: url)
                try? FileManager.default.removeItem(
                    at: URL(fileURLWithPath:
                        url.path + "-wal"))
                try? FileManager.default.removeItem(
                    at: URL(fileURLWithPath:
                        url.path + "-shm"))
            }
        }

        let atom = makeAtom(
            tier: .cold,
            content: "cross-runtime-survives")
        let atomID = atom.id.uuidString

        // SYNC PART:run 3 substrate sessions + collect refs。
        struct SessionRef {
            let sessionRef: String
            let turnRef: String
            let index: Int
        }
        var sessionRefs: [SessionRef] = []
        let runtime = BASHostRuntime(
            configuration: .fixtureGeneric)
        for i in 0..<3 {
            let request = BASHostSessionRequest(
                kind: .interactive,
                workflowProfile: .reflective,
                surface: .application,
                prompt: "ssn-\(i)",
                riskLevel: .medium)
            let result = try runtime.startSession(
                request,
                now: referenceNow.addingTimeInterval(
                    Double(i * 30)))
            let sessionRef =
                result.eBrainTurn?.sovereignAuditEntry?
                    .sessionID ?? "s-\(i)"
            sessionRefs.append(SessionRef(
                sessionRef: sessionRef,
                turnRef: "t-\(i)",
                index: i))
        }

        let referenceNowCopy = referenceNow

        let exp = expectation(
            description: "BASMemoryClosedLoop-sqlite-flow")
        Task {
            do {
                // Runtime 1 — apply closed loop。 Scope braces
                // ensure store/tracker/applier go out of scope
                // (and SQLite handles released) before runtime
                // 2 reopens the same files。
                do {
                    let store =
                        try BASSQLiteMemoryAtomStore(
                            databaseURL: storeURL,
                            initial: [atom])
                    let tracker = try BASMemoryUsageTracker(
                        databaseURL: trackerURL)
                    let applier = BASMemoryClosedLoopApplier(
                        store: store, tracker: tracker)

                    for refs in sessionRefs {
                        for _ in 0..<10 {
                            let recordID = try await applier
                                .recordRetrieval(
                                    atomID: atomID,
                                    sessionRef:
                                        refs.sessionRef,
                                    turnRef: refs.turnRef,
                                    permitMode: "answer",
                                    retrievedAt:
                                        referenceNowCopy
                                            .addingTimeInterval(
                                                Double(
                                                    refs.index
                                                    * 30)))
                            try await applier.markHelped(
                                recordID: recordID,
                                helped: true)
                        }
                    }

                    let outcome = await applier
                        .applyImportanceReport(
                            atomTiers: [atomID: .cold],
                            now: referenceNowCopy
                                .addingTimeInterval(120))
                    XCTAssertEqual(
                        outcome.appliedMutations[atomID],
                        .warm)
                }

                // Runtime 2 — reopen + verify。 SQLite handles
                // from runtime 1 released at end of scope above。
                let store2 = try BASSQLiteMemoryAtomStore(
                    databaseURL: storeURL)
                let after = await store2.atom(
                    forID: atomID)
                XCTAssertEqual(
                    after?.tier, .warm,
                    "tier mutation persists across runtime restart")

                let tracker2 = try BASMemoryUsageTracker(
                    databaseURL: trackerURL)
                let usageCount = await tracker2
                    .usageCount(forAtomID: atomID)
                XCTAssertEqual(
                    usageCount, 30,
                    "tracker preserves all 30 retrieval events")
                exp.fulfill()
            } catch {
                XCTFail(
                    "SQLite closed-loop flow failed: \(error)")
                exp.fulfill()
            }
        }
        wait(for: [exp], timeout: 10.0)
    }

    // MARK: - 3. Empty session run leaves applier idle

    /// Sanity check: if the host never records retrievals, the
    /// applier's report has zero mutations even after multiple
    /// substrate sessions. The closed loop is observation-driven
    /// — silent sessions = silent loop.
    func testRuntimeWithoutRetrievalRecordingProducesNoMutations()
        throws
    {
        // M2159 — migrated to sync test + non-detached Task
        // (Diagnostic F pattern)。
        let atom = makeAtom(tier: .warm)
        let store = BASInMemoryMemoryAtomStore(
            initial: [atom])
        let tracker = BASMemoryUsageTracker()
        let applier = BASMemoryClosedLoopApplier(
            store: store, tracker: tracker)
        let runtime = BASHostRuntime(
            configuration: .fixtureGeneric)

        // SYNC PART:drive 3 sessions WITHOUT recording any
        // retrievals。
        for i in 0..<3 {
            let request = BASHostSessionRequest(
                kind: .interactive,
                workflowProfile: .reflective,
                surface: .application,
                prompt: "silent-\(i)",
                riskLevel: .medium)
            _ = try runtime.startSession(
                request, now: referenceNow)
        }

        let referenceNowCopy = referenceNow
        let atomIDCopy = atom.id.uuidString

        let exp = expectation(
            description: "BASMemoryClosedLoop-silent-sessions")
        Task {
            let outcome = await applier
                .applyImportanceReport(
                    atomTiers: [atomIDCopy: .warm],
                    now: referenceNowCopy)
            let trackerCount = await tracker.recordCount
            XCTAssertEqual(
                trackerCount, 0,
                "tracker has zero records when host doesn't call recordRetrieval")
            XCTAssertEqual(
                outcome.report.scores.count, 1,
                "scorer evaluates the warm atom even with zero retrieval history")
            exp.fulfill()
        }
        wait(for: [exp], timeout: 10.0)
    }
}
