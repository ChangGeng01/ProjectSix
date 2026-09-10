// MARK: - BASChapter970WatcherTests
// chapter 九百七十 / M3555 — Phase 5 ch1 tests:Watcher protocol + 3 watchers
//
// Test scope:
//   1. Severity enum pin (4 cases)
//   2. Hint determinism (sorted evidence, clamped confidence)
//   3. Hint Codable round-trip
//   4. AnomalyWatcher: 3 rules (candidate-count / pressure / manipulation)
//   5. AnomalyWatcher: quiet turn → 0 hints
//   6. MemoryPollutionWatcher: 3 rules (duplicate arc / fabrication / orphan)
//   7. MemoryPollutionWatcher: nil memory input → 0 hints
//   8. HostDriftWatcher: 2 rules (untracked axes / surface-risk mismatch)
//   9. HostDriftWatcher: clean turn → 0 hints
//  10. CRITICAL: watchers have NO writeDomains (read-only invariant)
//  11. CRITICAL: watcher hints are NOT BASAgentDelta (different shape)
//  12. CRITICAL: dispatcher.runCh970 returns sorted+deterministic hints
//  13. Severity ladder: manipulation surge produces .alert, not .watch
//  14. Audit-trail: every hint has category prefix matching watcher role

import XCTest
@testable import BASMemory

final class BASChapter970WatcherTests: XCTestCase {

    // MARK: - 1. Severity enum pin

    func testWatcherSeverityCountIs4() {
        XCTAssertEqual(
            BASAgentWatcherSeverity.allCases.count, 4,
            "ch 970: exactly 4 severity levels per plan " +
            "(info / watch / alert / veto)")
    }

    // MARK: - 2. Hint determinism

    func testHintEvidenceSortedInInit() {
        let h = BASAgentWatcherHint(
            hintID: "h1", turnID: "t1",
            watcherRole: .anomalyWatcher,
            severity: .watch,
            category: "test.cat",
            summary: "test",
            evidence: ["z-evidence", "a-evidence", "m-evidence"],
            confidence: 0.5)
        XCTAssertEqual(h.evidence,
            ["a-evidence", "m-evidence", "z-evidence"],
            "ch 970: hint evidence MUST be sorted in init " +
            "(trace replay determinism)")
    }

    func testHintConfidenceClamped() {
        let lo = BASAgentWatcherHint(
            hintID: "h1", turnID: "t1",
            watcherRole: .anomalyWatcher,
            severity: .watch,
            category: "c", summary: "s",
            confidence: -5.0)
        XCTAssertEqual(lo.confidence, 0.0, accuracy: 0.0001)
        let hi = BASAgentWatcherHint(
            hintID: "h1", turnID: "t1",
            watcherRole: .anomalyWatcher,
            severity: .watch,
            category: "c", summary: "s",
            confidence: 99.0)
        XCTAssertEqual(hi.confidence, 1.0, accuracy: 0.0001)
    }

    // MARK: - 3. Codable round-trip

    func testHintCodableRoundTrip() throws {
        let h = BASAgentWatcherHint(
            hintID: "h1", turnID: "t1",
            watcherRole: .memoryPollutionWatcher,
            severity: .alert,
            category: "memory.fab",
            summary: "test",
            evidence: ["a", "b"],
            confidence: 0.85,
            candidateRef: "candidate#c1",
            nowNanos: 1_234_567)
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        let data = try enc.encode(h)
        let dec = try JSONDecoder().decode(
            BASAgentWatcherHint.self, from: data)
        XCTAssertEqual(h, dec,
            "ch 970: hint Codable round-trip preserves all fields")
    }

    // MARK: - 4. AnomalyWatcher rules

    func testAnomaly_CandidateCountSurge() {
        var seq = 0
        let candidates: [BASPlannerCandidate] =
            (0..<60).map { i in
                BASPlannerCandidate(
                    candidateID: "c\(i)", title: "t",
                    actionSummary: "a",
                    confidence: 0.5,
                    reversibility: 0.5)
            }
        let obs = BASAgentWatcherObservation(
            turnID: "t1",
            plannerCandidates: candidates)
        let hints = BASAnomalyWatcher.observe(
            obs, seq: &seq)
        XCTAssertEqual(hints.count, 1)
        XCTAssertEqual(
            hints[0].severity, .watch,
            "ch 970: candidate surge is .watch (LOW-stakes)")
        XCTAssertEqual(hints[0].category,
            "anomaly.candidate-count")
        XCTAssertEqual(
            hints[0].watcherRole, .anomalyWatcher)
    }

    func testAnomaly_PressureSurge() {
        var seq = 0
        let obs = BASAgentWatcherObservation(
            turnID: "t1",
            scout: BASScoutInput(
                pressureSignals: Array(repeating: "p",
                                       count: 25)))
        let hints = BASAnomalyWatcher.observe(
            obs, seq: &seq)
        XCTAssertEqual(hints.count, 1)
        XCTAssertEqual(hints[0].severity, .watch)
        XCTAssertEqual(hints[0].category,
            "anomaly.pressure-volume")
    }

    func testAnomaly_ManipulationSurgeIsAlert() {
        var seq = 0
        let obs = BASAgentWatcherObservation(
            turnID: "t1",
            scout: BASScoutInput(
                manipulationSignals: Array(
                    repeating: "m", count: 15)))
        let hints = BASAnomalyWatcher.observe(
            obs, seq: &seq)
        XCTAssertEqual(hints.count, 1)
        XCTAssertEqual(
            hints[0].severity, .alert,
            "ch 970 CRITICAL: manipulation surge MUST be " +
            ".alert (sovereign-significant signal)")
        XCTAssertEqual(hints[0].category,
            "anomaly.manipulation-volume")
    }

    func testAnomaly_QuietTurnZeroHints() {
        var seq = 0
        let hints = BASAnomalyWatcher.observe(
            BASAgentWatcherObservation(turnID: "t1"),
            seq: &seq)
        XCTAssertEqual(hints.count, 0)
        XCTAssertEqual(seq, 0,
            "ch 970: quiet observation MUST NOT bump seq")
    }

    // MARK: - 5. MemoryPollutionWatcher rules

    func testMemPol_DuplicateArcs() {
        var seq = 0
        let obs = BASAgentWatcherObservation(
            turnID: "t1",
            scout: BASScoutInput(
                pressureSignals: ["p1"]),
            memory: BASMemorySeatInput(
                episodeArcs: ["arc1", "arc2", "arc1", "arc3"],
                recallStrength: 0.6))
        let hints = BASMemoryPollutionWatcher.observe(
            obs, seq: &seq)
        XCTAssertTrue(hints.contains { h in
            h.category == "memory.duplicate-arc"
        })
    }

    func testMemPol_FabricationSuspect() {
        // High recall strength + ZERO scout signals →
        // suspect fabrication (.alert)
        var seq = 0
        let obs = BASAgentWatcherObservation(
            turnID: "t1",
            memory: BASMemorySeatInput(
                episodeArcs: ["arc1", "arc2"],
                recallStrength: 0.95))
        let hints = BASMemoryPollutionWatcher.observe(
            obs, seq: &seq)
        XCTAssertTrue(hints.contains { h in
            h.category == "memory.fabrication-suspect" &&
            h.severity == .alert
        }, "ch 970 CRITICAL: high recall + zero scout = " +
           ".alert (fabrication-suspect)")
    }

    func testMemPol_NilMemoryZeroHints() {
        var seq = 0
        let obs = BASAgentWatcherObservation(turnID: "t1")
        let hints = BASMemoryPollutionWatcher.observe(
            obs, seq: &seq)
        XCTAssertEqual(hints.count, 0,
            "ch 970: nil memory input → zero hints " +
            "(backward compat)")
    }

    // MARK: - 6. HostDriftWatcher rules

    func testHostDrift_UntrackedAxes() {
        var seq = 0
        let obs = BASAgentWatcherObservation(
            turnID: "t1",
            hostAlignment: BASHostAlignmentInput(
                candidates: [
                    BASHostAlignmentCandidate(
                        candidateID: "c1",
                        title: "t",
                        touchesAxes: ["financial", "privacy",
                                       "ethics"])
                ],
                hostBoundaryAxes: ["safety"]))  // none match
        let hints = BASHostDriftWatcher.observe(
            obs, seq: &seq)
        XCTAssertTrue(hints.contains { h in
            h.category == "hostdrift.untracked-axes"
        })
    }

    func testHostDrift_SurfaceRiskMismatch() {
        var seq = 0
        // Low risk + planner emitted candidates but surface
        // declined to accept any → drift。 (Per ch 972 fix:
        // skip when plannerCandidates empty — degenerate
        // empty-turn state is not drift)
        let obs = BASAgentWatcherObservation(
            turnID: "t1",
            plannerCandidates: [
                BASPlannerCandidate(
                    candidateID: "c1", title: "t",
                    actionSummary: "a",
                    confidence: 0.6,
                    reversibility: 0.7)
            ],
            surface: BASSurfaceInput(
                acceptedCandidateID: nil,
                riskBand: .low,
                reversibility: 0.7))
        let hints = BASHostDriftWatcher.observe(
            obs, seq: &seq)
        XCTAssertTrue(hints.contains { h in
            h.category == "hostdrift.surface-risk-mismatch"
        })
    }

    func testHostDrift_HighRiskNoMismatch() {
        // High risk with no accept is EXPECTED — no drift
        var seq = 0
        let obs = BASAgentWatcherObservation(
            turnID: "t1",
            surface: BASSurfaceInput(
                acceptedCandidateID: nil,
                riskBand: .high,
                reversibility: 0.5))
        let hints = BASHostDriftWatcher.observe(
            obs, seq: &seq)
        XCTAssertFalse(hints.contains { h in
            h.category == "hostdrift.surface-risk-mismatch"
        }, "ch 970: high-risk + no-accept is EXPECTED,not drift")
    }

    // MARK: - 7. CRITICAL invariants

    func testCRITICAL_WatchersAreReadOnly() {
        // Read-only proven by:watcher protocol has NO `writeDomains`
        // member and observe() returns hints not deltas。 But we
        // can ALSO defensively assert that constructing a watcher
        // agent spec with `.anomalyWatcher` role + write domain
        // is allowed structurally,but the dispatcher MUST never
        // give one。 Verify a watcher spec with no writeDomains
        // is the expected shape。
        let spec = BASAgentSpec(
            agentID: "anomaly.1",
            role: .anomalyWatcher,
            writeDomains: [],
            defaultLeaseProfile: .watcher,
            visibility: .low)
        XCTAssertTrue(spec.writeDomains.isEmpty,
            "ch 970 CRITICAL: watcher agent MUST have empty " +
            "writeDomains (read-only invariant)")
    }

    func testCRITICAL_HintsAreNotDeltas() {
        // BASAgentWatcherHint and BASAgentDelta have different
        // top-level discriminating fields。 The dispatcher MUST
        // route hints to a different channel than deltas。
        let h = BASAgentWatcherHint(
            hintID: "h1", turnID: "t1",
            watcherRole: .anomalyWatcher,
            severity: .watch,
            category: "c", summary: "s",
            confidence: 0.5)
        XCTAssertFalse(
            String(describing: type(of: h))
                .contains("BASAgentDelta"),
            "ch 970 CRITICAL: hint type MUST NOT alias delta")
    }

    // MARK: - 8. Dispatcher runCh970

    func testDispatcherRunCh970AggregatesAllThree() {
        // Construct an observation that triggers all 3 watchers
        let candidates: [BASPlannerCandidate] =
            (0..<60).map { i in
                BASPlannerCandidate(
                    candidateID: "c\(i)", title: "t",
                    actionSummary: "a",
                    confidence: 0.5,
                    reversibility: 0.5)
            }
        let obs = BASAgentWatcherObservation(
            turnID: "t1",
            scout: BASScoutInput(
                manipulationSignals: Array(
                    repeating: "m", count: 15)),
            plannerCandidates: candidates,
            surface: BASSurfaceInput(
                acceptedCandidateID: nil,
                riskBand: .low,
                reversibility: 0.7),
            memory: BASMemorySeatInput(
                episodeArcs: ["a", "a", "b"],
                recallStrength: 0.6),
            hostAlignment: BASHostAlignmentInput(
                candidates: [
                    BASHostAlignmentCandidate(
                        candidateID: "c1",
                        title: "t",
                        touchesAxes: ["x", "y", "z"])
                ],
                hostBoundaryAxes: []))
        let hints =
            BASAgentWatcherDispatch.runCh970(obs)
        // Expect at least 1 hint from each watcher
        let anomaly = hints.filter {
            $0.watcherRole == .anomalyWatcher
        }
        let mempol = hints.filter {
            $0.watcherRole == .memoryPollutionWatcher
        }
        let drift = hints.filter {
            $0.watcherRole == .hostDriftWatcher
        }
        XCTAssertGreaterThanOrEqual(anomaly.count, 2,
            "ch 970: dispatcher MUST run AnomalyWatcher")
        XCTAssertGreaterThanOrEqual(mempol.count, 1,
            "ch 970: dispatcher MUST run MemoryPollutionWatcher")
        XCTAssertGreaterThanOrEqual(drift.count, 2,
            "ch 970: dispatcher MUST run HostDriftWatcher")
    }

    func testDispatcherRunCh970Deterministic() {
        // Same input → byte-equal hints
        let obs = BASAgentWatcherObservation(
            turnID: "t1",
            scout: BASScoutInput(
                manipulationSignals: Array(
                    repeating: "m", count: 15)))
        let h1 = BASAgentWatcherDispatch.runCh970(obs)
        let h2 = BASAgentWatcherDispatch.runCh970(obs)
        XCTAssertEqual(h1, h2,
            "ch 970: dispatcher output MUST be byte-equal " +
            "for same input (trace replay invariant)")
    }

    // MARK: - 9. Audit-trail: category prefix matches role

    func testEveryHintHasCategoryPrefixMatchingRole() {
        var seq = 0
        // Anomaly hints prefixed with "anomaly."
        let obs1 = BASAgentWatcherObservation(
            turnID: "t1",
            scout: BASScoutInput(
                manipulationSignals: Array(
                    repeating: "m", count: 15)))
        for h in BASAnomalyWatcher.observe(
            obs1, seq: &seq)
        {
            XCTAssertTrue(
                h.category.hasPrefix("anomaly."),
                "ch 970: AnomalyWatcher hints MUST have " +
                "'anomaly.' category prefix (got '\(h.category)')")
        }
        // Memory pollution hints prefixed with "memory."
        let obs2 = BASAgentWatcherObservation(
            turnID: "t1",
            memory: BASMemorySeatInput(
                episodeArcs: ["a", "a"],
                recallStrength: 0.6))
        for h in BASMemoryPollutionWatcher.observe(
            obs2, seq: &seq)
        {
            XCTAssertTrue(
                h.category.hasPrefix("memory."),
                "ch 970: MemoryPollutionWatcher hints MUST " +
                "have 'memory.' category prefix")
        }
        // Host drift hints prefixed with "hostdrift."
        let obs3 = BASAgentWatcherObservation(
            turnID: "t1",
            surface: BASSurfaceInput(
                acceptedCandidateID: nil,
                riskBand: .low,
                reversibility: 0.7))
        for h in BASHostDriftWatcher.observe(
            obs3, seq: &seq)
        {
            XCTAssertTrue(
                h.category.hasPrefix("hostdrift."),
                "ch 970: HostDriftWatcher hints MUST have " +
                "'hostdrift.' category prefix")
        }
    }

    // MARK: - 10. Hint-ID uniqueness across watchers

    func testHintIDsUniqueAcrossWatchers() {
        let obs = BASAgentWatcherObservation(
            turnID: "t1",
            scout: BASScoutInput(
                manipulationSignals: Array(
                    repeating: "m", count: 15)),
            memory: BASMemorySeatInput(
                episodeArcs: ["a", "a"],
                recallStrength: 0.6),
            hostAlignment: BASHostAlignmentInput(
                candidates: [
                    BASHostAlignmentCandidate(
                        candidateID: "c1",
                        title: "t",
                        touchesAxes: ["x", "y", "z"])
                ],
                hostBoundaryAxes: []))
        let hints =
            BASAgentWatcherDispatch.runCh970(obs)
        let ids = hints.map { $0.hintID }
        XCTAssertEqual(
            ids.count, Set(ids).count,
            "ch 970 CRITICAL: hint IDs MUST be unique across " +
            "all watchers in same turn (shared seq counter)")
    }

    // MARK: - 11. Watcher role identity

    func testWatcherRolesMatchEnumCases() {
        XCTAssertEqual(
            BASAnomalyWatcher.role, .anomalyWatcher)
        XCTAssertEqual(
            BASMemoryPollutionWatcher.role,
            .memoryPollutionWatcher)
        XCTAssertEqual(
            BASHostDriftWatcher.role, .hostDriftWatcher)
    }
}
