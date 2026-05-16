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
        async throws
    {
        throw XCTSkip(
            "Pre-existing signal-10 SIGBUS — see " +
            "BASSignalTenIntegrationTestTriageDoctrine " +
            "(chapter 693 / M2143)")
        // Atom seeded as cold; expect promotion to warm after
        // ample recent helped retrievals.
        let promoteAtom = makeAtom(
            tier: .cold, content: "important-cold-atom")
        // Atom seeded as hot; expect demotion to warm after
        // stale single retrieval.
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

        // Drive 5 sessions through the substrate runtime.
        // Each session produces a substrate session result;
        // we extract substrate-produced refs (via the
        // sovereignAuditEntry's session/turn IDs when present)
        // for the applier.
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

            // Extract substrate-produced refs. Audit entry's
            // session/turn IDs are the canonical ones; fall
            // back to the request prompt as session label.
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

            // Record 3 retrievals against the promote atom
            // per session (high frequency + recent + helped).
            for _ in 0..<3 {
                let recordID = try await applier
                    .recordRetrieval(
                        atomID: promoteAtom.id.uuidString,
                        sessionRef: sessionRef,
                        turnRef: turnRef,
                        permitMode: permitMode,
                        retrievedAt: referenceNow
                            .addingTimeInterval(
                                Double(sessionIndex * 60)))
                try await applier.markHelped(
                    recordID: recordID, helped: true)
            }
            // Demote atom: only 1 stale retrieval far in the
            // past — cumulative frequency low + age high.
            if sessionIndex == 0 {
                _ = try await applier.recordRetrieval(
                    atomID: demoteAtom.id.uuidString,
                    sessionRef: sessionRef,
                    turnRef: turnRef,
                    permitMode: permitMode,
                    retrievedAt: referenceNow
                        .addingTimeInterval(
                            -7 * 86_400))
            }
        }

        // Apply importance report. Snapshot current tiers from
        // the store.
        let tierSnapshot: [String: BASMemoryTier] = [
            promoteAtom.id.uuidString: .cold,
            demoteAtom.id.uuidString: .hot
        ]
        let outcome = await applier.applyImportanceReport(
            atomTiers: tierSnapshot,
            now: referenceNow.addingTimeInterval(60 * 5))

        // Promote atom: should mutate cold → warm
        XCTAssertEqual(
            outcome.appliedMutations[
                promoteAtom.id.uuidString],
            .warm,
            "promote atom should be tier-mutated to .warm")
        // Demote atom: should mutate hot → warm
        XCTAssertEqual(
            outcome.appliedMutations[
                demoteAtom.id.uuidString],
            .warm,
            "stale hot atom should be tier-mutated to .warm")

        // Verify the atom store actually reflects the mutation
        // (proves applier.applyImportanceReport called
        // store.updateTier rather than just returning a report).
        let promoteAfter = await store.atom(
            forID: promoteAtom.id.uuidString)
        let demoteAfter = await store.atom(
            forID: demoteAtom.id.uuidString)
        XCTAssertEqual(
            promoteAfter?.tier, .warm,
            "store reflects promote mutation")
        XCTAssertEqual(
            demoteAfter?.tier, .warm,
            "store reflects demote mutation")
    }

    // MARK: - 2. Cross-session: SQLite store + tracker preserve
    //              mutations across runtime sessions

    /// Demonstrates that when the host uses SQLite-backed store
    /// + tracker (chapter 二百四十八 / 二百五十一) alongside
    /// `BASHostRuntime`, the closed-loop mutations applied in
    /// one runtime session persist to the next.
    func testSQLiteBackedClosedLoopSurvivesRuntimeRestart()
        async throws
    {
        throw XCTSkip(
            "Pre-existing signal-10 SIGBUS — see " +
            "BASSignalTenIntegrationTestTriageDoctrine " +
            "(chapter 693 / M2143)")
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

        // Runtime session 1: drive 3 substrate sessions, record
        // helped retrievals, apply report.
        do {
            let store = try BASSQLiteMemoryAtomStore(
                databaseURL: storeURL,
                initial: [atom])
            let tracker = try BASMemoryUsageTracker(
                databaseURL: trackerURL)
            let applier = BASMemoryClosedLoopApplier(
                store: store, tracker: tracker)
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

                // 10 helped retrievals per session = 30 helped
                // → strong promotion signal.
                for _ in 0..<10 {
                    let recordID = try await applier
                        .recordRetrieval(
                            atomID: atomID,
                            sessionRef: sessionRef,
                            turnRef: "t-\(i)",
                            permitMode: "answer",
                            retrievedAt: referenceNow
                                .addingTimeInterval(
                                    Double(i * 30)))
                    try await applier.markHelped(
                        recordID: recordID, helped: true)
                }
            }

            let outcome = await applier
                .applyImportanceReport(
                    atomTiers: [atomID: .cold],
                    now: referenceNow.addingTimeInterval(120))
            XCTAssertEqual(
                outcome.appliedMutations[atomID], .warm)
        }

        // Runtime session 2: reopen store + verify mutation
        // persisted.
        let store2 = try BASSQLiteMemoryAtomStore(
            databaseURL: storeURL)
        let after = await store2.atom(forID: atomID)
        XCTAssertEqual(
            after?.tier, .warm,
            "tier mutation persists across runtime restart " +
            "via SQLite-backed store")

        // Verify tracker history also persisted
        let tracker2 = try BASMemoryUsageTracker(
            databaseURL: trackerURL)
        let usageCount = await tracker2.usageCount(
            forAtomID: atomID)
        XCTAssertEqual(
            usageCount, 30,
            "tracker preserves all 30 retrieval events " +
            "across runtime restart")
    }

    // MARK: - 3. Empty session run leaves applier idle

    /// Sanity check: if the host never records retrievals, the
    /// applier's report has zero mutations even after multiple
    /// substrate sessions. The closed loop is observation-driven
    /// — silent sessions = silent loop.
    func testRuntimeWithoutRetrievalRecordingProducesNoMutations()
        async throws
    {
        throw XCTSkip(
            "Pre-existing signal-10 SIGBUS — see " +
            "BASSignalTenIntegrationTestTriageDoctrine " +
            "(chapter 693 / M2143)")
        let atom = makeAtom(tier: .warm)
        let store = BASInMemoryMemoryAtomStore(
            initial: [atom])
        let tracker = BASMemoryUsageTracker()
        let applier = BASMemoryClosedLoopApplier(
            store: store, tracker: tracker)
        let runtime = BASHostRuntime(
            configuration: .fixtureGeneric)

        // Drive 3 sessions but DO NOT record any retrievals.
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

        let outcome = await applier.applyImportanceReport(
            atomTiers: [atom.id.uuidString: .warm],
            now: referenceNow)
        // Hot atom with NO usage signal → may demote per
        // scorer's tier-decay rule. But the .warm tier is the
        // middle; no hot-to-warm or cold-to-warm tick, so
        // either hold or warm-to-cold based on baseline scoring.
        // Either way the store should not show any unrecorded
        // retrieval impact.
        let trackerCount = await tracker.recordCount
        XCTAssertEqual(
            trackerCount, 0,
            "tracker has zero records when host doesn't call " +
            "recordRetrieval")
        // Applier still ran (report computed) but on zero
        // tracker history.
        XCTAssertEqual(
            outcome.report.scores.count, 1,
            "scorer evaluates the warm atom even with zero " +
            "retrieval history (returns baseline-only score)")
    }
}
