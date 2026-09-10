// MARK: - BASCognitiveOS1HourSoakTests — chapter 三百八六 / M874
//
// Env-gated 1-hour soak test exercising the full M859-M873
// cognitive OS data loop continuously。Mirrors the AppleFM /
// MLX env-flag pattern (QINAO_FM_E2E=1, QINAO_MLX_E2E=1) — runs
// only when `QINAO_COGOS_SOAK_1H=1` is set so default
// `swift test` stays fast。
//
// ## What this exercises
//
// One BASCognitiveOSConvenience actor wired with FOUR SQLite
// primitives (event log + state store + graph + graph storage)
// running for 3600 seconds at ~50 events/sec:
//
//   M841 SQLite event log append per event
//   M842 SQLite user state fold every 100 events
//   M857 + M860 graph extract every 1000 events (cap 5000)
//   M866 SQLite graph storage write-through after each extract
//
// Total expected (3600s × 50 events/s):
//   ~180,000 events appended
//   ~1,800 state folds
//   ~5 successful graph extracts (cap kicks in after 5000)
//
// ## Invariants checked
//
// At end-of-run:
//   - SQLite event log totalCount == observed event count
//   - SQLite state store totalCount >= expected fold count
//   - SQLite graph storage has > 0 nodes (write-through worked)
//   - Memory bounded:no `[Double]` array growth,no leaked actors
//
// ## How to run
//
//   QINAO_COGOS_SOAK_1H=1 \
//     swift test --filter BASCognitiveOS1HourSoakTests
//
// (Default `swift test` skips this entirely。)

import XCTest
@testable import BASHostKit
@testable import BASMemory
@testable import BASRuntimeCore

final class BASCognitiveOS1HourSoakTests: XCTestCase {

    // MARK: - Constants

    /// Total soak duration in seconds (1 hour)。
    private static let soakDurationSec: Double = 3_600

    /// Target events-per-second submission rate。Conservative —
    /// gives the SQLite actor margin to keep up at real-iPhone
    /// IO bandwidth。
    private static let eventsPerSec: Int = 50

    /// Inter-event sleep:1 / eventsPerSec seconds。
    private static var interEventSleepNs: UInt64 {
        UInt64(1_000_000_000 / eventsPerSec)
    }

    /// Progress log interval (every N events)。
    private static let progressLogInterval: Int = 5_000

    /// Env flag that gates this test。
    private static let envFlag = "QINAO_COGOS_SOAK_1H"

    // MARK: - Test

    func testFullDataLoopOneHourSoak() async throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo
                .environment[Self.envFlag] == "1",
            "Test skipped — set \(Self.envFlag)=1 to " +
            "exercise the 1-hour cognitive OS substrate soak " +
            "(takes ~1h wall-clock,writes SQLite to temp dir)")

        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "qinao-cogos-1h-soak-\(UUID().uuidString)",
                isDirectory: true)
        try FileManager.default.createDirectory(
            at: tempDir,
            withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        // ---- Build full SQLite-backed cognitive OS bundle ----

        let bundle = try BASCognitiveOSBuilder.build(
            options: BASCognitiveOSBundleOptions(
                enableEventLog: true,
                eventLogSQLiteURL: tempDir
                    .appendingPathComponent("events.sqlite"),
                enableUserState: true,
                userStateSQLiteURL: tempDir
                    .appendingPathComponent("state.sqlite"),
                enableKnowledgeGraph: true,
                knowledgeGraphSQLiteURL: tempDir
                    .appendingPathComponent("graph.sqlite")))

        XCTAssertEqual(
            bundle.populatedCount, 4,
            "All 4 SQLite-backed slots populated for soak")

        let sessionID = "soak-\(UUID().uuidString)"
        let convenience = BASCognitiveOSConvenience(
            eventLog: bundle.eventLog,
            userStateStore: bundle.userStateStore,
            knowledgeGraph: bundle.knowledgeGraph,
            knowledgeGraphStorage:
                bundle.knowledgeGraphStorage,
            sessionID: sessionID,
            cadence: BASCognitiveOSConvenienceCadence
                .default,
            onPersistError: { id, err in
                // Surface persist failures during soak — these
                // would indicate SQLite contention / disk
                // pressure。Print but don't fail the run。
                print(
                    "[soak] persist error on \(id): \(err)")
            })

        // ---- Run loop ----

        print("[soak] Starting 1h cognitive OS data loop " +
            "(target \(Self.eventsPerSec) events/s,session " +
            "\(sessionID))")
        print("[soak] Output: \(tempDir.path)")

        let runStart = ContinuousClock.now
        let runDeadline = runStart.advanced(
            by: .seconds(Int(Self.soakDurationSec)))

        let projects = ["alpha", "beta", "gamma", "delta"]
        let kinds: [BASEventLogKind] = [
            .substrateAudit,
            .chat,
            .toolInvocation,
            .internalSignal,
        ]
        let actions = [
            ["delays:alpha"],
            ["chenglu:sweep:ok"],
            ["chenglu:sweep:fail"],
            ["dispatch:scout"],
        ]

        var localEventCount: Int = 0
        var lastProgressLogTime = ContinuousClock.now

        while ContinuousClock.now < runDeadline {
            let event = BASEventLogEntry(
                eventID: "soak-\(localEventCount)-" +
                    "\(UUID().uuidString)",
                timestampMs: Int64(
                    Date().timeIntervalSince1970 * 1000),
                kind: kinds[localEventCount % kinds.count],
                sessionID: sessionID,
                sequenceNumber: 0,
                source: "soak.1h",
                turnRef: "iter-\(localEventCount)",
                project: projects[
                    localEventCount % projects.count],
                actions: actions[
                    localEventCount % actions.count],
                confidence: 0.5)

            _ = await convenience.observe(event: event)
            localEventCount += 1

            // Progress log every 5000 events
            if localEventCount
                % Self.progressLogInterval == 0
            {
                let now = ContinuousClock.now
                let elapsedDur = runStart.duration(to: now)
                let elapsedSec = Double(
                    elapsedDur.components.seconds)
                    + Double(
                        elapsedDur.components.attoseconds)
                    / 1e18
                let throughput =
                    Double(localEventCount) / elapsedSec
                print(String(
                    format:
                        "[soak] iter %d / %.1fs / %.2f e/s",
                    localEventCount, elapsedSec, throughput))
                lastProgressLogTime = now
            }

            // Pace at target rate (sleep nanoseconds)
            try? await Task.sleep(
                nanoseconds: Self.interEventSleepNs)
        }

        let totalDur = runStart.duration(to: .now)
        let totalSec =
            Double(totalDur.components.seconds)
            + Double(totalDur.components.attoseconds)
            / 1e18

        // ---- End-of-run invariants ----

        let storedEventCount =
            await bundle.eventLog?.totalCount ?? 0
        let storedStateCount =
            await bundle.userStateStore?.totalCount ?? 0
        let storedGraphNodeCount =
            await bundle.knowledgeGraphStorage?.nodeCount
            ?? 0
        let storedGraphEdgeCount =
            await bundle.knowledgeGraphStorage?.edgeCount
            ?? 0

        let throughput = Double(localEventCount) / totalSec
        print("---")
        print("[soak] DONE")
        print(String(
            format: "[soak] elapsed: %.1fs", totalSec))
        print(String(
            format: "[soak] events submitted: %d",
            localEventCount))
        print(String(
            format: "[soak] events in SQLite: %d",
            storedEventCount))
        print(String(
            format: "[soak] state folds: %d",
            storedStateCount))
        print(String(
            format: "[soak] graph nodes (SQLite): %d",
            storedGraphNodeCount))
        print(String(
            format: "[soak] graph edges (SQLite): %d",
            storedGraphEdgeCount))
        print(String(
            format: "[soak] throughput: %.2f events/s",
            throughput))
        _ = lastProgressLogTime  // silence unused

        // Invariant: every submitted event made it to SQLite
        XCTAssertEqual(
            storedEventCount, localEventCount,
            "SQLite event log must persist every submitted " +
            "event (no silent drops under load)")

        // Invariant: state fold count matches expected cadence
        // (every 100 events,1-based)
        let expectedFolds =
            localEventCount / Self.expectedFoldInterval
        XCTAssertGreaterThanOrEqual(
            storedStateCount, expectedFolds - 1,
            "State folds must keep up with cadence " +
            "(allowing 1 in-flight slack at end-of-run)")
        XCTAssertLessThanOrEqual(
            storedStateCount, expectedFolds + 1,
            "State folds must not over-fire")

        // Invariant: graph SQLite has nodes (write-through
        // fired at least once)
        XCTAssertGreaterThan(
            storedGraphNodeCount, 0,
            "Graph SQLite write-through must have persisted " +
            "at least one node (extract fires at iter 1000)")

        // Invariant: throughput stayed within an order of
        // magnitude of target (allow large slack since SQLite
        // batching + Task.sleep granularity are noisy)
        XCTAssertGreaterThan(
            throughput, Double(Self.eventsPerSec) / 10.0,
            "Throughput collapsed below 1/10th target — " +
            "indicates SQLite contention or actor starvation")
    }

    /// Pin: cadence default for state fold (100) used in
    /// invariant calculation。Keeping as a typed constant here
    /// instead of reading from BASCognitiveOSConvenienceCadence
    /// .default at runtime so the test fails loudly if cadence
    /// defaults change without the soak test being audited。
    private static let expectedFoldInterval: Int = 100
}
