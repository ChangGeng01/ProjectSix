// MARK: - BASEventLogFailureInjectionTests — chapter 三百九九 / M902
//
// Test coverage for the typed failure-injection primitive that
// synthesizes event sequences exercising graph extractor
// heuristics 3 / 4 / 5 / 6 / 7。

import XCTest
@testable import BASRuntimeCore

final class BASEventLogFailureInjectionTests: XCTestCase {

    // MARK: - Delays cycle

    func testDelaysCycleProducesRequestedRepetitions() {
        let events = BASEventLogFailureInjection.generate(
            scenario: .delaysCycle(
                action: "fetch-corpus",
                project: "P-test",
                repetitions: 5,
                intervalMs: 2_000),
            sessionID: "s-delays",
            startingAtMs: 1_700_000_000_000)

        XCTAssertEqual(events.count, 5)
        // M902 substrate-alignment fix:every event carries
        // BOTH the raw action AND `skip:<action>` so heuristic 5
        // fires。Tests pin BOTH actions present。
        XCTAssertTrue(events.allSatisfy {
            $0.actions.contains("fetch-corpus")
        })
        XCTAssertTrue(events.allSatisfy {
            $0.actions.contains("skip:fetch-corpus")
        })
        XCTAssertTrue(events.allSatisfy {
            $0.project == "P-test"
        })
        XCTAssertTrue(events.allSatisfy {
            $0.sessionID == "s-delays"
        })
    }

    func testDelaysCycleTimestampsMonotonic() {
        let events = BASEventLogFailureInjection.generate(
            scenario: .delaysCycle(
                action: "load-config",
                project: "P-mono",
                repetitions: 3,
                intervalMs: 5_000),
            sessionID: "s-mono",
            startingAtMs: 1_000_000)

        XCTAssertEqual(
            events.map(\.timestampMs),
            [1_000_000, 1_005_000, 1_010_000])
    }

    /// Pin: heuristic 3 fires when ≥ 3 repetitions of same
    /// action — default 4 satisfies that constraint。
    func testDelaysCycleDefaultRepetitionsExceedsHeuristicMin() {
        let def = BASEventLogFailureInjection
            .defaultDelaysCycleRepetitions
        XCTAssertGreaterThanOrEqual(def, 3,
            "Default repetitions must satisfy heuristic 3's " +
            "minimum (3+ identical-action events)")
    }

    // MARK: - Contradiction

    func testContradictionProducesPair() {
        let events = BASEventLogFailureInjection.generate(
            scenario: .contradiction(
                failedAction: "afm:respond",
                retryAction: "mlx:respond",
                project: "P-llm"),
            sessionID: "s-contra",
            startingAtMs: 1_700_000_000_000)

        XCTAssertEqual(events.count, 2)
        XCTAssertTrue(events[0].actions.contains("afm:respond"))
        XCTAssertTrue(events[0].actions.contains("outcome:fail"))
        XCTAssertTrue(events[1].actions.contains("mlx:respond"))
        XCTAssertTrue(events[1].actions.contains("outcome:retry"))
        XCTAssertEqual(events[0].riskBand, .high)
        XCTAssertEqual(events[1].riskBand, .medium)
        // Pin: retry must come strictly after failure
        XCTAssertGreaterThan(
            events[1].timestampMs,
            events[0].timestampMs)
    }

    // MARK: - Thermal spike

    func testThermalSpikeAllEventsCarryRequestedBand() {
        let events = BASEventLogFailureInjection.generate(
            scenario: .thermalSpike(
                eventCount: 7,
                thermalBand: .high,
                project: "P-thermal"),
            sessionID: "s-thermal",
            startingAtMs: 0)

        XCTAssertEqual(events.count, 7)
        XCTAssertTrue(events.allSatisfy {
            $0.riskBand == .high
        })
        XCTAssertTrue(events.allSatisfy {
            $0.actions.contains("thermal:high")
        })
    }

    func testThermalSpikeSupportsAllRiskBands() {
        for band in BASEventLogRiskBand.allCases {
            let events = BASEventLogFailureInjection.generate(
                scenario: .thermalSpike(
                    eventCount: 3,
                    thermalBand: band,
                    project: "P-band"),
                sessionID: "s-band-\(band.rawValue)",
                startingAtMs: 0)
            XCTAssertEqual(events.count, 3,
                "Thermal spike must work for band " +
                "\(band.rawValue)")
            XCTAssertTrue(events.allSatisfy {
                $0.riskBand == band
            })
        }
    }

    // MARK: - Complexity addiction loop

    func testComplexityLoopProducesThreeEventsPerCycle() {
        let events = BASEventLogFailureInjection.generate(
            scenario: .complexityAddictionLoop(
                project: "P-vision-10",
                techActions: ["framework:react",
                              "framework:vue"],
                cycleDepth: 3,
                intervalMs: 30_000),
            sessionID: "s-vision",
            startingAtMs: 0)

        XCTAssertEqual(events.count, 9,
            "3 cycles × 3 events per cycle = 9 events")

        // Per-cycle:anxiety / tech / delay
        for cycle in 0..<3 {
            let base = cycle * 3
            XCTAssertEqual(
                events[base].actions, ["affect:anxious"],
                "Cycle \(cycle) starts with anxiety event")
            XCTAssertTrue(
                events[base + 1].actions.first?
                    .hasPrefix("add-tech:") ?? false,
                "Cycle \(cycle) tech event has add-tech action")
            XCTAssertEqual(
                events[base + 2].actions, ["delay-marker"],
                "Cycle \(cycle) ends with delay marker")
        }
    }

    func testComplexityLoopRotatesTechActionsAcrossCycles() {
        let actions = ["framework:react",
                       "framework:vue",
                       "framework:angular"]
        let events = BASEventLogFailureInjection.generate(
            scenario: .complexityAddictionLoop(
                project: "P-rot",
                techActions: actions,
                cycleDepth: 5,
                intervalMs: 10_000),
            sessionID: "s-rot",
            startingAtMs: 0)

        // Tech events at positions 1, 4, 7, 10, 13
        let techActions = (0..<5).map { events[$0 * 3 + 1]
            .actions.first ?? "" }
        XCTAssertEqual(techActions, [
            "add-tech:framework:react",
            "add-tech:framework:vue",
            "add-tech:framework:angular",
            "add-tech:framework:react",
            "add-tech:framework:vue"
        ], "Tech actions must rotate by cycle index modulo " +
        "techActions.count")
    }

    // MARK: - Determinism

    /// chapter 三百九二 / M892 replay-determinism pin: same
    /// scenario + same session + same starting timestamp must
    /// produce identical event IDs across runs。
    func testGeneratorIsDeterministic() {
        let scenario = BASEventLogFailureInjectionScenario
            .delaysCycle(
                action: "deterministic-action",
                project: "P-det",
                repetitions: 3,
                intervalMs: 1_000)

        let run1 = BASEventLogFailureInjection.generate(
            scenario: scenario,
            sessionID: "s-det",
            startingAtMs: 100_000)
        let run2 = BASEventLogFailureInjection.generate(
            scenario: scenario,
            sessionID: "s-det",
            startingAtMs: 100_000)

        XCTAssertEqual(
            run1.map(\.eventID),
            run2.map(\.eventID),
            "Same scenario + session + starting must produce " +
            "identical event IDs across calls (M892 replay " +
            "determinism doctrine)")
    }

    /// Different sessions produce DIFFERENT event IDs even for
    /// the same scenario,so cross-session injection doesn't
    /// trigger spurious deduplication。
    func testDifferentSessionsProduceDifferentEventIDs() {
        let scenario = BASEventLogFailureInjectionScenario
            .delaysCycle(
                action: "shared-action",
                project: "P-shared",
                repetitions: 2,
                intervalMs: 1_000)

        let s1 = BASEventLogFailureInjection.generate(
            scenario: scenario,
            sessionID: "session-A",
            startingAtMs: 0)
        let s2 = BASEventLogFailureInjection.generate(
            scenario: scenario,
            sessionID: "session-B",
            startingAtMs: 0)

        XCTAssertNotEqual(
            s1.map(\.eventID), s2.map(\.eventID),
            "Different sessions must yield different IDs")
    }

    // MARK: - Source tag pin

    /// Pin: every injected event carries `source:
    /// fault-injection:*` so consumers can filter synthetic
    /// events from real ones for evaluation purposes。
    func testAllInjectedEventsTaggedWithFaultInjectionSource() {
        let scenarios: [BASEventLogFailureInjectionScenario] = [
            .delaysCycle(
                action: "a", project: "p",
                repetitions: 3, intervalMs: 1_000),
            .contradiction(
                failedAction: "f", retryAction: "r",
                project: "p"),
            .thermalSpike(
                eventCount: 3,
                thermalBand: .high, project: "p"),
            .complexityAddictionLoop(
                project: "p",
                techActions: ["a"],
                cycleDepth: 2,
                intervalMs: 1_000)
        ]
        for scenario in scenarios {
            let events = BASEventLogFailureInjection.generate(
                scenario: scenario,
                sessionID: "s-tag",
                startingAtMs: 0)
            XCTAssertTrue(events.allSatisfy {
                $0.source?.hasPrefix(
                    "fault-injection:") == true
            }, "All events must carry fault-injection source " +
            "tag for filtering")
        }
    }
}
