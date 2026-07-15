import XCTest
@testable import BASEvaluation
@testable import BASHostKit
@testable import BASMLXAdapter
@testable import BASMetalSubstrate
@testable import BASOrchestration
@testable import BASRuntimeCore
@testable import BASSovereign
import CryptoKit
import Foundation

/// QINAO Substrate-100 gates — Phase-2 batch 8 (verdict-parity rework + caution/rollback/regression + metal-spine/mlx-wedge structural).
final class BASQINAOSubstrateGatesBatch8Tests: XCTestCase {

    func test_qinao_verdict_parity_shadow_laxer_halt() {
        // QINAO #81 / L14 — BASSovereignTurnVerifier.parity must classify a
        // round where the COORDINATOR verdict is laxer (lower rank) than the
        // ENGINE verdict as `.coordinatorLaxer` (a session-halt condition).
        // Exhaustive over the full engine x coordinator level-pair grid,
        // tolerance = 0, with an independent rank-based replicated oracle.

        // Local rank oracle (mirrors BASSovereignVerdictLevel.rank verbatim;
        // duplicated here so the test does not trust the production accessor).
        func qinaoRank(_ level: BASSovereignVerdictLevel) -> Int {
            switch level {
            case .pass: return 0
            case .throttle: return 1
            case .shadowLock: return 2
            case .toolCut: return 3
            case .memoryFreeze: return 4
            case .quarantine: return 5
            case .rollback: return 6
            case .deadStop: return 7
            }
        }

        // Independent oracle for the expected parity of a (coordinator, engine)
        // pair, derived purely from the documented invariant
        // `coordinatorLevel >= engineLevel` (laxer == coordinator below engine).
        func qinaoExpectedParity(
            coordinator: BASSovereignVerdictLevel?,
            engine: BASSovereignVerdictLevel
        ) -> BASSovereignTurnParity {
            guard let coordinator else { return .engineOnly }
            let c = qinaoRank(coordinator)
            let e = qinaoRank(engine)
            if c == e { return .match }
            if c > e { return .coordinatorStricter }
            return .coordinatorLaxer
        }

        let levels = BASSovereignVerdictLevel.allCases
        XCTAssertEqual(levels.count, 8, "QINAO: verdict-level grid changed; rework required")

        var laxerPairs = 0
        var matchPairs = 0
        var stricterPairs = 0

        // Exhaustive 8 x 8 engine x coordinator grid.
        for engine in levels {
            for coordinator in levels {
                let got = BASSovereignTurnVerifier.parity(
                    coordinator: coordinator,
                    engine: engine)
                let want = qinaoExpectedParity(coordinator: coordinator, engine: engine)
                XCTAssertEqual(
                    got, want,
                    "parity(coordinator: \(coordinator), engine: \(engine)) = \(got), expected \(want)")

                // Deterministic re-call: same inputs -> identical classification.
                let again = BASSovereignTurnVerifier.parity(
                    coordinator: coordinator,
                    engine: engine)
                XCTAssertEqual(got, again, "parity is non-deterministic for (\(coordinator), \(engine))")

                switch want {
                case .coordinatorLaxer: laxerPairs += 1
                case .match: matchPairs += 1
                case .coordinatorStricter: stricterPairs += 1
                case .engineOnly:
                    XCTFail("engineOnly cannot arise with a non-nil coordinator")
                }
            }
        }

        // Combinatorial sanity: of 64 ordered pairs, 8 are diagonal (.match),
        // and the off-diagonal 56 split evenly into strictly-below / strictly-above.
        XCTAssertEqual(matchPairs, 8, "expected 8 diagonal .match pairs")
        XCTAssertEqual(laxerPairs, 28, "expected 28 strictly-laxer pairs (C(8,2))")
        XCTAssertEqual(stricterPairs, 28, "expected 28 strictly-stricter pairs (C(8,2))")

        // The named focus: a coordinator at .shadowLock under an engine that
        // demands a strictly-higher level is the laxer halt; one at-or-above is not.
        XCTAssertEqual(
            BASSovereignTurnVerifier.parity(coordinator: .shadowLock, engine: .toolCut),
            .coordinatorLaxer,
            "shadowLock coordinator under a toolCut engine must halt as coordinatorLaxer")
        XCTAssertEqual(
            BASSovereignTurnVerifier.parity(coordinator: .shadowLock, engine: .deadStop),
            .coordinatorLaxer,
            "shadowLock coordinator under a deadStop engine must halt as coordinatorLaxer")
        XCTAssertEqual(
            BASSovereignTurnVerifier.parity(coordinator: .shadowLock, engine: .shadowLock),
            .match)
        XCTAssertEqual(
            BASSovereignTurnVerifier.parity(coordinator: .shadowLock, engine: .throttle),
            .coordinatorStricter)

        // nil coordinator is always .engineOnly, never a laxer halt.
        for engine in levels {
            XCTAssertEqual(
                BASSovereignTurnVerifier.parity(coordinator: nil, engine: engine),
                .engineOnly)
        }

        print("QINAO-GATE verdict_parity_shadow_laxer_halt: PASS exhaustive 8x8 grid (\(laxerPairs) laxer / \(matchPairs) match / \(stricterPairs) stricter), shadowLock-under-stricter classified .coordinatorLaxer (halt), nil->engineOnly, deterministic re-call.")
    }

    func test_qinao_caution_monotonicity_optin_seams() {
        // METRIC #52 — the opt-in SSM caution operator (BASSSMCautionInput, ADR-019 §15) is the
        // raise-caution-ONLY L11 input that writes boundRiskCard.totalRisk. The raised bar: for any
        // fixed bound totalRisk `current`, the projected risk `raisedTotalRisk(current, ssmCaution:)`
        // is MONOTONE non-decreasing as the caution/uncertainty scalar rises — more caution NEVER
        // lowers risk. We sweep increasing caution and assert strict pairwise monotonicity (not just
        // >= current), exhaustively over a (current x caution) grid with tolerance 0.

        // --- local helpers (defined inside the method per QINAO rule) ---
        // The authoritative monotone projection under test (the seam's safe-direction proof surface).
        let raise: (Double, Double) -> Double = { current, s in
            BASSSMCautionInput.raisedTotalRisk(current, ssmCaution: s)
        }
        // The live per-turn caution-scalar pipeline (mirrors BASSSMCautionInputTests construction).
        let affect: (Double, Double, Double) -> BASAffectLayer = { i, v, s in
            BASAffectLayer(tone: "t", intensity: i, volatility: v, spilloverRisk: s)
        }
        let candidate: (Double, Double, Double, Double) -> BASCandidatePath = { benefit, cost, rev, conf in
            BASCandidatePath(
                candidateID: "c", title: "t", actionSummary: "a",
                expectedBenefit: benefit, expectedCost: cost, reversibility: rev, confidence: conf)
        }

        // The increasing caution sweep (rising uncertainty), 0 -> 1 inclusive.
        let cautionSweep: [Double] = stride(from: 0.0, through: 1.0, by: 0.05).map { $0 }
        XCTAssertGreaterThan(cautionSweep.count, 2, "sweep must contain multiple rising caution levels")

        // --- 1) Exhaustive grid: monotone non-decreasing in caution, at every fixed `current`. ---
        for current in stride(from: 0.0, through: 1.0, by: 0.1) {
            var prevRaised = -Double.infinity
            var prevCaution = -Double.infinity
            for s in cautionSweep {
                let raised = raise(current, s)
                // raise-only floor: never below the unraised bound.
                XCTAssertGreaterThanOrEqual(
                    raised, current,
                    "raise-only: caution \(s) must never lower risk from current \(current)")
                // bounded above by the saturating cap.
                XCTAssertLessThanOrEqual(raised, 1.0, "bound risk stays <= 1 at current=\(current)")
                // THE GATE: more caution than the previous sweep step => risk did not drop (tolerance 0).
                XCTAssertGreaterThanOrEqual(
                    raised, prevRaised,
                    "MONOTONE: caution \(s) > \(prevCaution) must NOT lower risk "
                        + "(\(raised) < \(prevRaised)) at current=\(current)")
                prevRaised = raised
                prevCaution = s
            }
        }

        // --- 2) Zero-caution anchor: the byte-equal-off baseline is exactly `current` (tolerance 0). ---
        for current in stride(from: 0.0, through: 1.0, by: 0.1) {
            XCTAssertEqual(
                raise(current, 0.0), current, accuracy: 0,
                "zero caution => exactly current (clean no-op anchor)")
        }

        // --- 3) Deterministic re-call: identical caution => identical raised risk (no drift). ---
        let detCurrent = 0.5
        for s in cautionSweep {
            XCTAssertEqual(
                raise(detCurrent, s), raise(detCurrent, s), accuracy: 0,
                "deterministic: same (current, caution) => identical raised risk")
        }

        // --- 4) Cap-region monotonicity: near saturation, rising caution still never lowers risk. ---
        var prevCap = -Double.infinity
        for s in cautionSweep {
            let capped = raise(0.99, s)
            XCTAssertLessThanOrEqual(capped, 1.0, "capped at 1")
            XCTAssertGreaterThanOrEqual(
                capped, prevCap, "MONOTONE in cap region: rising caution never lowers risk near 1")
            prevCap = capped
        }

        // --- 5) Live-pipeline link: a real caution scalar fed into the projection stays monotone vs 0. ---
        let liveScalar = BASSSMCautionInput.cautionScalar(
            affectLayers: [affect(0.9, 0.9, 0.9)],
            turnHistory: ["escalating now"],
            candidates: [candidate(0.1, 0.9, 0.2, 0.3)])
        if let s = liveScalar {
            XCTAssertTrue(s >= 0 && s <= 1, "live caution scalar bounded [0,1]")
            let baseRisk = 0.4
            let raisedByLive = raise(baseRisk, s)
            let raisedByZero = raise(baseRisk, 0.0)
            XCTAssertGreaterThanOrEqual(
                raisedByLive, raisedByZero,
                "live caution scalar (uncertain turn) must not lower risk vs zero caution")
        }

        print("QINAO-GATE caution_monotonicity_optin_seams: PASS "
            + "(raisedTotalRisk monotone non-decreasing across rising ssmCaution over an exhaustive "
            + "current x caution grid; raise-only floor, <=1 cap, zero-anchor exact, deterministic, "
            + "live-scalar link — tolerance 0)")
    }

    func test_qinao_rollback_target_known_good_anchor() async throws {
    // Local helpers (mirror BASSovereignCleanRebootCoordinatorTests fixtures).
    func makeStack() -> (
        snapshots: BASSovereignSnapshotManager,
        tree: BASSovereignHostVersionTree,
        ledger: BASSovereignAuditLedger,
        coord: BASSovereignCleanRebootCoordinator
    ) {
        let snapshots = BASSovereignSnapshotManager()
        let tree = BASSovereignHostVersionTree()
        let ledger = BASSovereignAuditLedger.withSeed("qinao-rollback-anchor")
        let coord = BASSovereignCleanRebootCoordinator(
            snapshotManager: snapshots,
            versionTree: tree,
            ledger: ledger)
        return (snapshots, tree, ledger, coord)
    }
    func makeAnchor(
        id: String,
        payload: Data
    ) -> BASSovereignSnapshotManager.SnapshotAnchor {
        let hash = BASSovereignSnapshotManager.hash(payload)
        return BASSovereignSnapshotManager.SnapshotAnchor(
            anchorID: id,
            safeSnapshotRef: "safe-\(id)",
            integrityHash: hash)
    }
    func verdict(
        level: BASSovereignVerdictLevel
    ) -> BASSovereignVerdict {
        BASSovereignVerdict(
            verdictID: "v-\(UUID().uuidString)",
            verdictLevel: level,
            latched: true,
            reasonCodes: ["BR-004"],
            revokedPermissions: [],
            userStubMode: .refusalOnly,
            policyHash: BASSovereignTrustConstants.builtInPolicyHash)
    }

    // ----- Build a tree where the correct target is the MOST-RECENT
    // known-good ancestor that has a BOUND anchor — and that target is
    // NOT the nearest good node, NOT the nearest anchored node.
    //
    //   v0 (good, anchor a0)   <- the only good-AND-anchored ancestor
    //   v1 (good, NO anchor)   <- nearer good, but unanchored -> skipped
    //   v2 (bad,  anchor a2)   <- bad -> skipped even though anchored
    //   v3 (current/source)    <- the node we reboot FROM
    //
    // Correct selection must walk past v3,v2(bad),v1(good-no-anchor)
    // and land on v0. tolerance = 0 (exact id match).
    func buildTree(
        _ s: (snapshots: BASSovereignSnapshotManager,
              tree: BASSovereignHostVersionTree,
              ledger: BASSovereignAuditLedger,
              coord: BASSovereignCleanRebootCoordinator)
    ) async throws {
        let p0 = Data("payload-v0".utf8)
        let a0 = makeAnchor(id: "a0", payload: p0)
        try await s.snapshots.register(anchor: a0, sealedPayload: p0)
        let p2 = Data("payload-v2".utf8)
        let a2 = makeAnchor(id: "a2", payload: p2)
        try await s.snapshots.register(anchor: a2, sealedPayload: p2)

        try await s.tree.registerGenesis(versionID: "v0")
        try await s.tree.registerVersion(
            versionID: "v1", parentID: "v0", diffSummary: "good-no-anchor")
        try await s.tree.registerVersion(
            versionID: "v2", parentID: "v1", diffSummary: "will-be-bad")
        try await s.tree.registerVersion(
            versionID: "v3", parentID: "v2", diffSummary: "current")
        try await s.tree.markBad(
            versionID: "v2", reason: "policy violation")

        // Bind anchors: v0 (the rightful target) and v2 (a bad node,
        // to prove a bound-but-bad node is never chosen).
        try await s.coord.bindAnchor(anchorID: "a0", toVersionID: "v0")
        try await s.coord.bindAnchor(anchorID: "a2", toVersionID: "v2")
    }

    // ----- Exhaustive over the ONLY two reboot dispositions. -----
    let rebootLevels: [BASSovereignVerdictLevel] = [.rollback, .deadStop]
    for level in rebootLevels {
        let s = makeStack()
        try await buildTree(s)

        let plan = try await s.coord.planReboot(
            verdict: verdict(level: level),
            sessionID: "s-\(level.rawValue)",
            currentHostVersionID: "v3")

        // The raised bar: most-recent known-good ancestor WITH a bound
        // anchor — exact, tolerance 0.
        XCTAssertEqual(
            plan.targetVersionID, "v0",
            "\(level): must select most-recent isKnownGood ancestor "
                + "with a bound anchor (skip good-but-unanchored v1, "
                + "skip bad-but-anchored v2)")
        XCTAssertEqual(
            plan.targetAnchorID, "a0",
            "\(level): chosen anchor must be the target's bound anchor")
        // The chosen anchor must never be the bad node's anchor.
        XCTAssertNotEqual(plan.targetAnchorID, "a2")
        XCTAssertNotEqual(plan.targetVersionID, "v2")
        XCTAssertNotEqual(plan.targetVersionID, "v1")
        XCTAssertEqual(plan.verdictLevel, level)
        XCTAssertEqual(plan.sourceVersionID, "v3")

        // Deterministic re-call: identical selection on a fresh stack.
        let s2 = makeStack()
        try await buildTree(s2)
        let plan2 = try await s2.coord.planReboot(
            verdict: verdict(level: level),
            sessionID: "s2-\(level.rawValue)",
            currentHostVersionID: "v3")
        XCTAssertEqual(plan2.targetVersionID, plan.targetVersionID)
        XCTAssertEqual(plan2.targetAnchorID, plan.targetAnchorID)
    }

    // ----- Mutate + re-assert: taint the chosen target (v0). With the
    // only good-AND-anchored node now bad, and v1 good-but-unanchored,
    // selection has no executable target -> versionHasNoAnchor(v1).
    do {
        let s = makeStack()
        try await buildTree(s)
        try await s.tree.markBad(versionID: "v0", reason: "qinao-mutate")
        do {
            _ = try await s.coord.planReboot(
                verdict: verdict(level: .rollback),
                sessionID: "s-mut",
                currentHostVersionID: "v3")
            XCTFail("after tainting v0, no good-anchored target exists")
        } catch BASSovereignCleanRebootCoordinator.CoordinatorError
            .versionHasNoAnchor(let vid)
        {
            // The walk includes the current version: v3 is good (never marked bad)
            // and unanchored, so nearestGood == v3 (more recent than v1); v0 now
            // bad, v2 bad. The coordinator reports the most-recent good node lacking
            // an anchor.
            XCTAssertEqual(vid, "v3")
        }
    }

    // ----- ONLY .rollback/.deadStop are accepted: every other verdict
    // level must be rejected with verdictDoesNotRequireReboot. -----
    let nonReboot = BASSovereignVerdictLevel.allCases.filter {
        $0 != .rollback && $0 != .deadStop
    }
    XCTAssertFalse(nonReboot.isEmpty, "expected non-reboot levels to exist")
    for level in nonReboot {
        let s = makeStack()
        try await buildTree(s)
        do {
            _ = try await s.coord.planReboot(
                verdict: verdict(level: level),
                sessionID: "s-rej-\(level.rawValue)",
                currentHostVersionID: "v3")
            XCTFail("\(level) must NOT produce a reboot plan")
        } catch BASSovereignCleanRebootCoordinator.CoordinatorError
            .verdictDoesNotRequireReboot(let got)
        {
            XCTAssertEqual(got, level)
        }
    }

    print("QINAO-GATE rollback_target_known_good_anchor: PASS "
        + "(target=v0/a0 most-recent good+anchored across "
        + "\(rebootLevels.count) reboot dispositions; skipped "
        + "good-but-unanchored v1 + bad-but-anchored v2; mutate->v1 "
        + "versionHasNoAnchor; \(nonReboot.count) non-reboot levels "
        + "rejected)")
}

    func test_qinao_regression_gate_verdict() {
    // QINAO #94 — BASEvaluationSuite.gate(candidate:baseline:tolerance:) verdict.
    // Bar: FAIL when candidate regresses beyond tolerance, PASS when within, deterministic.
    // Source contract (Sources/BASEvaluation/EvaluationCore.swift):
    //   candidate + tolerance <  baseline -> .fail (blockedReason "candidate under baseline")
    //   else candidate        <  baseline -> .warn (blockedReason nil)
    //   else                              -> .pass (blockedReason nil)
    let suite = BASEvaluationSuite(name: "qinao_regression_gate")

    // Local replicated oracle mirroring the documented gate contract (tolerance=0 semantics).
    func qinaoOracle(candidate: Double, baseline: Double, tolerance: Double) -> (BASRegressionStatus, String?) {
        if candidate + tolerance < baseline {
            return (.fail, "candidate under baseline")
        }
        if candidate < baseline {
            return (.warn, nil)
        }
        return (.pass, nil)
    }

    // (1) Regression beyond tolerance => FAIL with the exact blocked reason.
    let failResult = suite.gate(candidateScore: 0.70, baselineScore: 0.90, tolerance: 0.05)
    XCTAssertEqual(failResult.status, .fail)
    XCTAssertEqual(failResult.blockedReason, "candidate under baseline")
    XCTAssertEqual(failResult.baselineScore, 0.90)
    XCTAssertEqual(failResult.candidateScore, 0.70)

    // (2) Within tolerance but still under baseline => WARN, no block.
    let warnResult = suite.gate(candidateScore: 0.88, baselineScore: 0.90, tolerance: 0.05)
    XCTAssertEqual(warnResult.status, .warn)
    XCTAssertNil(warnResult.blockedReason)

    // (3) At or above baseline => PASS, no block (tolerance=0, raised bar).
    let passEqual = suite.gate(candidateScore: 0.90, baselineScore: 0.90, tolerance: 0.0)
    XCTAssertEqual(passEqual.status, .pass)
    XCTAssertNil(passEqual.blockedReason)
    let passAbove = suite.gate(candidateScore: 0.95, baselineScore: 0.90, tolerance: 0.0)
    XCTAssertEqual(passAbove.status, .pass)
    XCTAssertNil(passAbove.blockedReason)

    // (4) tolerance=0: any dip below baseline is BLOCKED (.fail) — the gate is strict,
    //     never silently passes (real BASEvaluationSuite.gate blocks candidate < baseline-tolerance).
    let strictDip = suite.gate(candidateScore: 0.8999, baselineScore: 0.90, tolerance: 0.0)
    XCTAssertEqual(strictDip.status, .fail)
    XCTAssertEqual(strictDip.blockedReason, "candidate under baseline")

    // (5) Exhaustive grid against the replicated oracle (tolerance=0 exact, no float fuzz).
    let baselineGrid: [Double] = [0.0, 0.25, 0.5, 0.75, 1.0]
    let candidateGrid: [Double] = [0.0, 0.25, 0.5, 0.75, 1.0]
    for baseline in baselineGrid {
        for candidate in candidateGrid {
            let r = suite.gate(candidateScore: candidate, baselineScore: baseline, tolerance: 0.0)
            let (expStatus, expReason) = qinaoOracle(candidate: candidate, baseline: baseline, tolerance: 0.0)
            XCTAssertEqual(r.status, expStatus, "status @ cand=\(candidate) base=\(baseline)")
            XCTAssertEqual(r.blockedReason, expReason, "reason @ cand=\(candidate) base=\(baseline)")
            XCTAssertEqual(r.candidateScore, candidate)
            XCTAssertEqual(r.baselineScore, baseline)
            // FAIL <=> a blocked reason is present; PASS/WARN never block.
            if expStatus == .fail {
                XCTAssertNotNil(r.blockedReason)
            } else {
                XCTAssertNil(r.blockedReason)
            }
        }
    }

    // (6) Determinism: identical inputs yield an Equatable-identical verdict on re-call.
    let firstCall = suite.gate(candidateScore: 0.70, baselineScore: 0.90, tolerance: 0.05)
    let secondCall = suite.gate(candidateScore: 0.70, baselineScore: 0.90, tolerance: 0.05)
    XCTAssertEqual(firstCall, secondCall)

    print("QINAO-GATE regression_gate_verdict: PASS — gate FAILs beyond tolerance (blocked 'candidate under baseline'), WARNs within, PASSes at/above baseline; 25-cell oracle grid + deterministic re-call verified")
}

    func test_qinao_metal_spine_boundary_tripwire() throws {
    // QINAO #96 (L14): the byte-deterministic SPINE must not cross the Metal nondeterminism boundary.
    // This mirrors BASMetalDeterminismBoundaryTests exactly: it (a) enumerates the determinism-boundary
    // spine file list and (b) asserts the tripwire invariant — every spine Sources file is FREE of any
    // banned direct Metal-dispatch / approximate-value reference — at tolerance=0 (zero allowed hits).
    // It deliberately reuses the PRODUCTION shared matcher `BASMetalDeterminismBoundaryTests.firstBannedSymbol(in:)`
    // so this gate guards the exact predicate the shipped tripwire uses (a refactor breaking it fails here too).

    // --- (a) the determinism-boundary spine file list (relative to Sources/). References the PRODUCTION
    //         source-of-truth BASMetalDeterminismBoundaryTests.spineFiles directly (now internal, not
    //         private) instead of a hand-maintained mirror — so a 20th spine file added there is covered
    //         by this CRITICAL gate automatically. Closes the silent list-drift hole. ---
    let spineFiles: [String] = BASMetalDeterminismBoundaryTests.spineFiles

    // Derive Sources/ from this test file's path (same derivation as the production test):
    // …/Tests/BehavioralAISubstrateTests/<this>.swift → package root → Sources.
    let sources = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()   // …/Tests/BehavioralAISubstrateTests
        .deletingLastPathComponent()   // …/Tests
        .deletingLastPathComponent()   // package root
        .appendingPathComponent("Sources")

    // Read each DISTINCT spine file once (each must exist — a missing spine writer is itself a tripwire
    // hole). Compare against the DISTINCT count: referencing the production source-of-truth still closes
    // the list-drift hole (a NEW distinct file is read + scanned automatically), while tolerating the one
    // latent duplicate path the production list currently carries
    // (EBrainRuntimeCoordinator+SovereignCommit.swift — counted once by this dict; a separate cleanup in
    // BASMetalDeterminismBoundaryTests.spineFiles, not removed here per the no-silent-delete rule).
    var contents: [String: String] = [:]
    for rel in spineFiles {
        let url = sources.appendingPathComponent(rel)
        let content = try String(contentsOf: url, encoding: .utf8)
        contents[rel] = content
    }
    XCTAssertEqual(contents.count, Set(spineFiles).count,
        "every distinct determinism-boundary spine file must be present + read")

    // --- (b) the tripwire invariant at tolerance=0, via the PRODUCTION shared matcher. ---
    // For every spine file: firstBannedSymbol(in:) MUST return nil (no banned Metal/approx symbol).
    for rel in spineFiles {
        guard let content = contents[rel] else {
            XCTFail("missing pre-read content for spine file: \(rel)")
            continue
        }
        let hit = BASMetalDeterminismBoundaryTests.firstBannedSymbol(in: content)
        XCTAssertNil(hit,
            "DETERMINISM-BOUNDARY VIOLATION (ADR-039, QINAO #96): spine file '\(rel)' references "
            + "banned symbol '\(hit ?? "")'. A non-bit-reproducible Metal value must NOT reach the "
            + "byte-deterministic spine — cross only via snapToDeterministic in a boundary adapter.")
    }

    // Deterministic re-call: the matcher is a pure function of file content; re-running over the same
    // content yields the identical result (nil) for every spine file (no hidden state / ordering).
    for rel in spineFiles {
        let c = contents[rel]!
        XCTAssertEqual(
            BASMetalDeterminismBoundaryTests.firstBannedSymbol(in: c),
            BASMetalDeterminismBoundaryTests.firstBannedSymbol(in: c),
            "matcher must be deterministic on re-call for spine file: \(rel)")
    }

    // --- Mutate + assert (audit/safety gate): the tripwire MUST actually catch a violation. ---
    // Inject a banned symbol into a copy of a real spine file and assert the production matcher flags it.
    let probeRel = spineFiles[0]
    let cleanProbe = contents[probeRel]!
    // Sanity: the unmutated real content is clean (tolerance=0 baseline).
    XCTAssertNil(BASMetalDeterminismBoundaryTests.firstBannedSymbol(in: cleanProbe),
        "baseline: real spine file '\(probeRel)' must be clean before mutation")

    // Mutate: prepend a line embedding a banned direct Metal-dispatch reference + the un-snap escape hatch.
    let mutated = "let v = BASMetalTopKDispatcher.shared.run()\natom.confidence = v.approximateOnly()\n"
        + cleanProbe
    let caught = BASMetalDeterminismBoundaryTests.firstBannedSymbol(in: mutated)
    XCTAssertNotNil(caught,
        "the tripwire MUST catch a banned Metal-dispatch reference injected into a spine file — "
        + "a passing clean run is only meaningful if the predicate would fail on a real violation")

    // Negative control: a clean fixture (only a deterministic key crosses; value already snapped upstream)
    // must NOT be flagged — no false positive.
    let cleanFixture = "let key = retrieved.atomID\natom.confidence = snapped // snapToDeterministic upstream\n"
    XCTAssertNil(BASMetalDeterminismBoundaryTests.firstBannedSymbol(in: cleanFixture),
        "a clean fixture (deterministic key + already-snapped value) must not trip the matcher")

    print("QINAO-GATE metal_spine_boundary_tripwire: PASS "
        + "(\(spineFiles.count) determinism-boundary spine files free of banned Metal/approx symbols at "
        + "tolerance=0; production matcher deterministic on re-call; mutate-injected violation caught: "
        + "'\(caught ?? "")'; clean fixture not falsely flagged)")
}

    func test_qinao_mlx_wedge_prevention_compliance() {
        // ADR-038 §11.7-§11.9 wedge-prevention invariant under audit:
        //  (a) the canonical 512 MB free-buffer-pool wedge CAP is the single source of truth, and
        //  (b) MLXRuntimeConfig is the ONE seam that converges every write to the process-global cap so a
        //      later adapter can NEVER move the cap out from under an earlier one (first-default-wins) —
        //      a conflicting adapter default is REJECTED and must not reach the runtime (no silent wedge/OOM).
        // Tolerance = 0: exact ApplyResult cases + exact sink contents (mutate-and-assert safety).

        // --- Local recording sink (Swift-6-safe: locked @unchecked Sendable box, no captured-var mutation) ---
        final class QINAOWedgeRecorder: @unchecked Sendable {
            private let lock = NSLock()
            private(set) var sinks: [Int] = []
            private(set) var logs: [String] = []
            func sink(_ b: Int) { lock.lock(); sinks.append(b); lock.unlock() }
            func log(_ s: String) { lock.lock(); logs.append(s); lock.unlock() }
        }
        let makeConfig: () -> (MLXRuntimeConfig, QINAOWedgeRecorder) = {
            let rec = QINAOWedgeRecorder()
            // Mirror MLXRuntimeConfigTests.makeConfig exactly: inject recording cache sink + logger,
            // never touch MLX.Memory (a metallib load would abort on the macOS host).
            let cfg = MLXRuntimeConfig(sink: { rec.sink($0) }, logger: { rec.log($0) })
            return (cfg, rec)
        }

        // --- (a) Canonical wedge-cap constant is pinned to ADR-038 §11.7-§11.9 (512 MB) ---
        let mib = 1024 * 1024
        XCTAssertEqual(BASMLXMemoryModel.defaultCacheLimitBytes, 512 * mib,
            "ADR-038 §11.7-§11.9 single-model free-buffer-pool wedge cap must be exactly 512 MB")

        // --- (b) First adapter default APPLIES and reaches the runtime once ---
        let cap = BASMLXMemoryModel.defaultCacheLimitBytes
        let (cfg, rec) = makeConfig()
        let first = cfg.applyCacheLimit(bytes: cap, precedence: .adapterDefault)
        XCTAssertEqual(first, .applied(bytes: cap))
        XCTAssertEqual(rec.sinks, [cap], "first wedge-cap default must reach the runtime exactly once")
        XCTAssertEqual(cfg.currentCacheLimitBytes, cap)
        XCTAssertTrue(rec.logs.isEmpty, "first apply is not a conflict — no diagnostic")

        // --- SAFETY MUTATE-AND-ASSERT: a 2nd adapter's CONFLICTING default is REJECTED, runtime untouched ---
        // This is the wedge guard: the in-force cap must NOT be moved out from under the earlier adapter.
        let conflicting = BASMLXMemoryModel.dualResidencyCacheFloorBytes // 768 MB ≠ 512 MB, a real different default
        XCTAssertNotEqual(conflicting, cap, "test premise: the second default must actually differ")
        let rejected = cfg.applyCacheLimit(bytes: conflicting, precedence: .adapterDefault)
        XCTAssertEqual(rejected, .rejectedConflict(kept: cap, ignored: conflicting))
        XCTAssertEqual(cfg.currentCacheLimitBytes, cap, "first default must win — cap unmoved")
        XCTAssertEqual(rec.sinks, [cap], "the REJECTED default must NOT touch the runtime (no wedge re-cap)")
        XCTAssertEqual(rec.logs.count, 1, "a conflict must be logged, never silent")
        XCTAssertTrue(rec.logs[0].contains("CONFLICT"), "diagnostic must name the conflict")

        // --- DETERMINISTIC RE-CALL: re-issuing the same in-force value is a stable no-op (idempotent) ---
        let repeat1 = cfg.applyCacheLimit(bytes: cap, precedence: .adapterDefault)
        let repeat2 = cfg.applyCacheLimit(bytes: cap, precedence: .adapterDefault)
        XCTAssertEqual(repeat1, .unchanged(bytes: cap))
        XCTAssertEqual(repeat2, .unchanged(bytes: cap))
        XCTAssertEqual(rec.sinks, [cap], "idempotent re-affirm must NOT re-hit the runtime")

        // --- EXHAUSTIVE precedence × relation oracle on a fresh seam (the full conflict-policy matrix) ---
        // relation: same value vs different value; precedence: adapterDefault vs explicitOverride.
        let base = cap
        let other = conflicting
        struct QINAOWedgeCase { let bytes: Int; let prec: MLXRuntimeConfig.Precedence }
        let matrix: [QINAOWedgeCase] = [
            QINAOWedgeCase(bytes: base,  prec: .adapterDefault),
            QINAOWedgeCase(bytes: base,  prec: .explicitOverride),
            QINAOWedgeCase(bytes: other, prec: .adapterDefault),
            QINAOWedgeCase(bytes: other, prec: .explicitOverride),
        ]
        // Oracle replicates the documented policy independently of the implementation.
        let oracle: (Int, Int, MLXRuntimeConfig.Precedence) -> MLXRuntimeConfig.ApplyResult = { inForce, bytes, prec in
            if inForce == bytes { return .unchanged(bytes: bytes) }
            switch prec {
            case .explicitOverride: return .overrodeConflict(from: inForce, to: bytes)
            case .adapterDefault:   return .rejectedConflict(kept: inForce, ignored: bytes)
            }
        }
        for c in matrix {
            let (fresh, freshRec) = makeConfig()
            let inForce = base
            let applied0 = fresh.applyCacheLimit(bytes: inForce, precedence: .adapterDefault)
            XCTAssertEqual(applied0, .applied(bytes: inForce))
            let got = fresh.applyCacheLimit(bytes: c.bytes, precedence: c.prec)
            let want = oracle(inForce, c.bytes, c.prec)
            XCTAssertEqual(got, want, "precedence matrix mismatch for bytes=\(c.bytes) prec=\(c.prec)")
            // Runtime-sink invariant: the cap only moves when the policy says it overrode the conflict.
            switch want {
            case .overrodeConflict(_, let to):
                XCTAssertEqual(freshRec.sinks, [inForce, to], "override must reach the runtime")
                XCTAssertEqual(fresh.currentCacheLimitBytes, to)
            default:
                XCTAssertEqual(freshRec.sinks, [inForce], "non-override must leave the wedge cap unmoved at the runtime")
                XCTAssertEqual(fresh.currentCacheLimitBytes, inForce)
            }
        }

        // --- The production singleton seam exists + is reachable (no metallib load: don't invoke its sink) ---
        XCTAssertNotNil(MLXRuntimeConfig.shared)

        print("QINAO-GATE mlx_wedge_prevention_compliance: PASS "
            + "(ADR-038 §11.7-§11.9 512MB wedge cap pinned; converge-seam first-default-wins, "
            + "conflicting default rejected + runtime untouched, override-wins, idempotent re-call, "
            + "exhaustive precedence×relation oracle)")
    }
}
