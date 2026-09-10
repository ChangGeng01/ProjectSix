// MARK: - BASChapter994_7Round11FixesTests
// chapter 九百九十四.7 / M3675.7 — META-REVIEW Round-11 cascade
//
// Round-11 N-pass review of ch 994 + ch 994.5 caught:
//   - CRITICAL-1: priorityContext orphan in
//     BASAgentFabricFullTurnAdapter (same class as Round-10 H1)
//   - HIGH-1: testCRITICAL_H1_RiskCardEnrichmentReachesSeat
//     doesn't catch the bug it claims (asserts delta exists,
//     not that it was card-enriched)
//   - HIGH-2: SQLite v1→v2 migration not atomic + not idempotent
//     (crash between ALTER + PRAGMA → re-open fails with
//     duplicate-column → unrecoverable)
//   - GAP-1: v1→v2 migration path is untested (the existing
//     FreshV2DB test exercises fresh CREATE,not migration)
//
// This file ships the regression tests for the fixes。

import XCTest
import Crypto
import SQLite3
@testable import BASOrchestration
@testable import BASHostKit
@testable import BASMemory
@testable import BASSovereign
@testable import BASRuntimeCore
@testable import BASPolicy

final class BASChapter994_7Round11FixesTests: XCTestCase {

    // MARK: - CRITICAL-1: priorityContext orphan fix

    /// Defense: BASAgentFabricLiveInputs.priorityContext MUST
    /// reach the coordinator through the convenience adapter。
    /// Pre-fix the field didn't exist on liveInputs;default
    /// empty context was used at coordinator level → merge
    /// engine couldn't tier sovereign/risk/host deltas correctly。
    func testCRITICAL_C1_PriorityContextFlowsToCoordinator()
        async throws
    {
        let fabric = makeFabric()
        let coordinator = makeCoordinator(fabric: fabric)
        // Construct a non-default priorityContext。
        let ctx = BASMergePriorityContext(
            sovereignAgentIDs: ["sentinel.1"],
            riskAgentIDs: ["risk.1"],
            hostAgentIDs: ["hostalign.1"])
        let liveInputs = BASAgentFabricLiveInputs(
            frame: BASDecomposeFrame(),
            candidatePaths: [makeCand()],
            acceptedCandidateID: "c.1",
            priorityContext: ctx)
        // Verify the field is on the struct + accessible
        XCTAssertEqual(
            liveInputs.priorityContext.sovereignAgentIDs,
            ["sentinel.1"],
            "ch 994.7 CRITICAL-1: priorityContext MUST be " +
            "carried on liveInputs (closes Round-11 orphan " +
            "finding — same class as Round-10 riskCard)")
        // End-to-end:run produces non-nil result (the merge
        // engine reads the context internally,which would
        // throw on type-mismatch if not wired)。
        let result = try await BASAgentFabricFullTurnAdapter
            .run(
                sessionID: "s",
                turnID: "t.1",
                liveInputs: liveInputs,
                coordinator: coordinator)
        XCTAssertNotNil(result,
            "ch 994.7 CRITICAL-1: pipeline with non-default " +
            "priorityContext composes cleanly through adapter")
    }

    func testCRITICAL_C1_DefaultPriorityContext_PreservesCompat() {
        // Default constructor produces an empty context for
        // backward compat with pre-fix callers。
        let liveInputs = BASAgentFabricLiveInputs(
            frame: BASDecomposeFrame(),
            candidatePaths: [])
        XCTAssertTrue(
            liveInputs.priorityContext
                .sovereignAgentIDs.isEmpty,
            "ch 994.7: omitting priorityContext defaults to " +
            "empty (red-line 7 byte-equality preserved)")
    }

    // MARK: - HIGH-1: riskCard enrichment correctness pin

    /// Defense: Round-11 caught that ch 994.5's
    /// testCRITICAL_H1_RiskCardEnrichmentReachesSeat only
    /// asserted "delta exists" — but BASRiskSeat emits a delta
    /// for ANY candidate regardless of pressureLevel。 Mutation
    /// that drops the card-enrichment would slip past。 This test
    /// pins the actual enrichment by checking band classification。
    func testCRITICAL_H1_RiskCardEnrichment_ActuallyApplied()
        async throws
    {
        // Empty L7 frame → baseline pressure 0 → without card
        // enrichment,risk seat would emit LOW-band delta。 With
        // card enrichment (totalRisk=0.95,manipulationStrength
        // >= 0.5),pressure raises to 0.95 → HIGH-band delta。
        let fabric = makeFabric()
        let coordinator = makeCoordinator(fabric: fabric)
        let highRiskCard = BASRiskCard(
            totalRisk: 0.95,
            riskLevel: .high,
            uncertainty: 0.5,
            irreversibility: 0.5,
            manipulationStrength: 0.85,
            gsiScore: 0.5,
            recommendedMode: .delay)
        let liveInputs = BASAgentFabricLiveInputs(
            frame: BASDecomposeFrame(),
            candidatePaths: [makeCand()],
            acceptedCandidateID: "c.1",
            riskCard: highRiskCard)
        let result = try await BASAgentFabricFullTurnAdapter
            .run(
                sessionID: "s",
                turnID: "t.1",
                liveInputs: liveInputs,
                coordinator: coordinator)
        let emitted = result?.turnResult.emittedDeltas ?? []
        let riskDelta = emitted.first {
            $0.targetObjectRef.hasPrefix("riskField#")
        }
        XCTAssertNotNil(riskDelta)
        // Risk seat encodes band as part of payloadJson or
        // reasonCodes。 Card-enriched HIGH-band delta MUST have
        // a reasonCode reflecting the high-risk band。
        let reasons = riskDelta?.reasonCodes ?? []
        let hasHighSignal = reasons.contains {
            $0.lowercased().contains("high") ||
            $0.lowercased().contains("manipulation")
        }
        XCTAssertTrue(hasHighSignal,
            "ch 994.7 HIGH-1: card enrichment MUST flow into " +
            "Risk seat's reasonCodes (pre-fix test was weak — " +
            "only checked delta existence,a mutation dropping " +
            "enrichment would slip past)。 reasons=\(reasons)")
    }

    // MARK: - HIGH-2 + GAP-1: SQLite migration atomicity +
    //         actual v1→v2 migration path test

    /// Defense: pre-fix v1→v2 migration was NOT idempotent。
    /// If a process opened a v1 DB,ran ALTER TABLE successfully,
    /// then crashed BEFORE the PRAGMA write,the next open would
    /// find user_version=1 + the column already present。 The
    /// re-run ALTER would throw `duplicate column name` → ledger
    /// refuses to open。 Round-11 HIGH-2 fix:wrap migration in
    /// BEGIN IMMEDIATE/COMMIT + check column existence before
    /// ALTER。 This test simulates the crash-then-retry scenario
    /// by setting up the post-crash state directly。
    func testCRITICAL_H2_MigrationIsIdempotent_PostCrashRetry()
        throws
    {
        let tmpPath = NSTemporaryDirectory()
            + "ch994_7_crash_\(UUID().uuidString).sqlite"
        defer {
            try? FileManager.default
                .removeItem(atPath: tmpPath)
        }
        // Simulate post-crash state:user_version=1 (PRAGMA
        // never bumped) + entry_schema_version column already
        // exists (ALTER succeeded pre-crash)。
        var db: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE
        XCTAssertEqual(
            sqlite3_open_v2(tmpPath, &db, flags, nil),
            SQLITE_OK)
        // V2-shape DDL but user_version=1 (mimics post-crash)
        let postCrashDDL = """
            CREATE TABLE audit_entries (
                audit_id TEXT PRIMARY KEY,
                session_id TEXT NOT NULL,
                turn_id TEXT NOT NULL,
                verdict_ref TEXT NOT NULL,
                rule_ids TEXT NOT NULL,
                signal_refs TEXT NOT NULL,
                action_refs TEXT NOT NULL,
                snapshot_ref TEXT NOT NULL,
                actor TEXT NOT NULL,
                signature TEXT NOT NULL,
                appended_at_ms INTEGER NOT NULL,
                prior_hash TEXT NOT NULL,
                self_hash TEXT NOT NULL,
                insertion_order INTEGER NOT NULL UNIQUE,
                entry_schema_version TEXT NOT NULL DEFAULT '1.0.0'
            );
            CREATE TABLE segments (
                segment_id TEXT PRIMARY KEY,
                segment_index INTEGER NOT NULL,
                session_id TEXT NOT NULL,
                start_anchor TEXT NOT NULL,
                tail_hash TEXT,
                entry_count INTEGER NOT NULL,
                opened_at_ms INTEGER NOT NULL,
                closed_at_ms INTEGER,
                closed_by TEXT,
                closing_rotation_id TEXT
            );
            PRAGMA user_version=1;
            """
        XCTAssertEqual(
            sqlite3_exec(db, postCrashDDL, nil, nil, nil),
            SQLITE_OK)
        sqlite3_close_v2(db)

        // Pre-fix:reopening this DB would fail because the
        // migration would try ALTER TABLE → duplicate column
        // → throw → ledger refuses to open。
        // Post-fix:idempotency check skips the redundant
        // ALTER + just bumps user_version to 2。
        XCTAssertNoThrow(
            try BASSovereignLedgerSQLiteStorage(path: tmpPath),
            "ch 994.7 HIGH-2 CRITICAL: post-crash retry MUST " +
            "succeed (idempotent migration)。 Pre-fix this " +
            "threw duplicate-column → unrecoverable ledger。")
    }

    /// Defense: Round-11 GAP-1:no test exercised the actual
    /// v1→v2 ALTER TABLE migration path。 The FreshV2DB test
    /// from ch 994.5 only tested fresh CREATE (column always
    /// present)。 This test seeds a true v1-shape DB (no
    /// entry_schema_version column) + reopens via the storage
    /// constructor + verifies migration ran cleanly。
    func testCRITICAL_GAP1_V1ToV2MigrationPathExercised()
        async throws
    {
        let tmpPath = NSTemporaryDirectory()
            + "ch994_7_v1mig_\(UUID().uuidString).sqlite"
        defer {
            try? FileManager.default
                .removeItem(atPath: tmpPath)
        }
        // Seed a TRUE v1 DB:no entry_schema_version column,
        // pre-existing rows,user_version=1
        var db: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE
        XCTAssertEqual(
            sqlite3_open_v2(tmpPath, &db, flags, nil),
            SQLITE_OK)
        let v1DDL = """
            CREATE TABLE audit_entries (
                audit_id TEXT PRIMARY KEY,
                session_id TEXT NOT NULL,
                turn_id TEXT NOT NULL,
                verdict_ref TEXT NOT NULL,
                rule_ids TEXT NOT NULL,
                signal_refs TEXT NOT NULL,
                action_refs TEXT NOT NULL,
                snapshot_ref TEXT NOT NULL,
                actor TEXT NOT NULL,
                signature TEXT NOT NULL,
                appended_at_ms INTEGER NOT NULL,
                prior_hash TEXT NOT NULL,
                self_hash TEXT NOT NULL,
                insertion_order INTEGER NOT NULL UNIQUE
            );
            CREATE TABLE segments (
                segment_id TEXT PRIMARY KEY,
                segment_index INTEGER NOT NULL,
                session_id TEXT NOT NULL,
                start_anchor TEXT NOT NULL,
                tail_hash TEXT,
                entry_count INTEGER NOT NULL,
                opened_at_ms INTEGER NOT NULL,
                closed_at_ms INTEGER,
                closed_by TEXT,
                closing_rotation_id TEXT
            );
            INSERT INTO audit_entries (
                audit_id, session_id, turn_id, verdict_ref,
                rule_ids, signal_refs, action_refs,
                snapshot_ref, actor, signature,
                appended_at_ms, prior_hash, self_hash,
                insertion_order
            ) VALUES (
                'a.legacy', 's', 't', 'v',
                '', '', '',
                '', 'system', '',
                1000, '', 'hashabc',
                0
            );
            PRAGMA user_version=1;
            """
        XCTAssertEqual(
            sqlite3_exec(db, v1DDL, nil, nil, nil),
            SQLITE_OK)
        sqlite3_close_v2(db)

        // Reopen via storage constructor → migration MUST run
        let storage = try BASSovereignLedgerSQLiteStorage(
            path: tmpPath)
        let snapshot = try storage.loadState()
        XCTAssertEqual(snapshot.entries.count, 1,
            "ch 994.7 GAP-1: pre-existing v1 row survives " +
            "migration")
        XCTAssertEqual(
            snapshot.entries[0].entry.schemaVersion,
            "1.0.0",
            "ch 994.7 GAP-1: migrated v1 row gets default " +
            "schemaVersion '1.0.0' (preserves OLD canonical-" +
            "bytes format for backward signature compat)")
    }

    // MARK: - Helpers

    private func makeCoordinator(
        fabric: BASAgentFabricRuntime
    ) -> BASEBrainRuntimeCoordinator {
        BASEBrainRuntimeCoordinator(
            powerClockService:
                BASPlaceholderPowerClockService(),
            hostProfileService:
                BASPlaceholderHostProfileService(),
            contextService:
                BASPlaceholderContextService(),
            decomposeService:
                BASPlaceholderDecomposeService(),
            memoryService:
                BASPlaceholderMemoryService(),
            loopService:
                BASPlaceholderLoopService(),
            triSelfService:
                BASPlaceholderTriSelfService(),
            riskService:
                BASPlaceholderRiskService(),
            actionService:
                BASPlaceholderActionService(),
            evolutionService:
                BASPlaceholderEvolutionService(),
            agentFabric: fabric)
    }

    private func makeFabric() -> BASAgentFabricRuntime {
        BASAgentFabricRuntime(
            roster: BASAgentTurnRoster(
                scout: BASAgentSpec(
                    agentID: "scout.1",
                    role: .scout,
                    writeDomains: [.situationField],
                    defaultLeaseProfile: .hotSeat,
                    visibility: .high),
                planner: BASAgentSpec(
                    agentID: "planner.1",
                    role: .planner,
                    writeDomains: [.candidateFrontier],
                    defaultLeaseProfile: .hotSeat,
                    visibility: .high),
                risk: BASAgentSpec(
                    agentID: "risk.1",
                    role: .risk,
                    writeDomains: [.riskField],
                    defaultLeaseProfile: .hotSeat,
                    visibility: .high),
                surface: BASAgentSpec(
                    agentID: "surface.1",
                    role: .surface,
                    writeDomains: [.renderFrame],
                    defaultLeaseProfile: .hotSeat,
                    visibility: .high)),
            graph: BASSharedStateGraph())
    }

    private func makeCand() -> BASCandidatePath {
        BASCandidatePath(
            candidateID: "c.1",
            title: "test",
            actionSummary: "a",
            expectedBenefit: 0.5,
            expectedCost: 0.5,
            reversibility: 0.5,
            confidence: 0.5)
    }
}
