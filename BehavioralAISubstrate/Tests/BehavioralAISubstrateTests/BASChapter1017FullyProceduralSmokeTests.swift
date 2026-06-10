// MARK: - BASChapter1017FullyProceduralSmokeTests
// chapter 一千零十七 / M3825 — 全面 进化 procedural smoke
//
// User invoked「进化 算法 加强 程序化生成 极致 找到 所有 缺陷 bug 不足
// 真机 跑1小时冒烟 最好 14层 每层每个部分都冒烟测试 以此发挥最大作用
// 找到瑕疵 全面冒烟测试 开发极致 极大提高benchmark
// 我希望 大部分 固定 数值 都可以 改成 完全 flexible 程序化 生成
// 而不是 死数值」
//
// chapter 一千零十八.5 / M3840 — Round-27 corrected the
// chapter doctrine to match what the file ACTUALLY does:
//
//   1. PROCEDURAL value PICKS — per-iter values within ranges
//      vary via deterministic BASFuzzRng seeded by (test-name,
//      iter-index)。 The RANGES themselves and the intensity
//      bands ARE hardcoded anchors (~20 dead numbers across
//      the file)。 Honest framing:proc-gen picks,not proc-
//      gen ranges。
//
//   2. PARTIAL LAYER COVERAGE — this file covers 7 layers
//      (L1, L6, L7, L9, L10, L11, L14)。 ch 946 covers 10
//      layers (L1, L2, L3, L4, L5, L8, L11, L12, L13, L14)。
//      Union is 12 of 14 layers。 Missing in BOTH chapters:
//      L6 (cortexCheck) is in ch 1017 only,L7 is in ch 1017
//      only,L9 and L10 are in ch 1017 only。 So combined
//      coverage IS 14 layers when both test classes run。
//      But neither file alone covers all 14 — Round-26 + 27
//      caught the「14-layer complete coverage」 over-claim。
//
//   3. INTENSITY SCALING — single env var BAS_FUZZ_INTENSITY
//      scales iter counts for THIS file's 7 layer tests:
//        intensity=1 (smoke,default): 10 iter per sub-test
//        intensity=5 (stress): 50 iter per sub-test
//        intensity=10 (endurance,for 1hr device runs): 100 iter
//        intensity=20 (max): 200 iter (~3-4hr device equivalent)
//      ch 946 has its own BAS_FUZZ_ITER + BAS_FUZZ_RUNTIME_ITER
//      scaling (different env var, different magnitude)。
//
//   4. ~~AGGREGATE「ALL GREEN」 PIN~~ — chapter 一千零十八 /
//      M3835 Round-26 MED-2 fix DELETED the aggregate test。
//      Reason:XCTest auto-discovers each `test*` method +
//      calling them via aggregate caused 2× execution。 Now
//      each layer test stands alone — XCTest's own run
//      summary serves the「all green」 gate。 If any layer
//      fails standalone,the test class fails,which fails
//      the build / device-iter。 Same gate,half the work。
//
//   5. BENCHMARK SCORECARD — each sub-test emits a「scorecard」
//      print with op + iter-count + duration + per-iter
//      avg/min/max。 Trend analysis tooling can aggregate across
//      device runs。
//
// ## Why this matters
//
// ch 946 was the original 14-layer smoke。 Over chapters
// 947-1014 the substrate gained ~30 new public APIs,subsystems,
// and behavior surfaces。 ch 946's coverage didn't grow with the
// substrate。 ch 1017 is the「rebase」 for the 4 layers ch 946
// missed (L6, L7, L9, L10) + adds proc-gen picks for layers
// both chapters touch (L1, L11, L14)。
//
// ## Discipline
//
// - 红线 7 additive only — no existing test changed
// - Iter counts driven by BAS_FUZZ_INTENSITY env var,scaling
//   uniformly across all 14 layers per-test。
// - Proc-gen value ranges via boundary-biased BASFuzzRng picks —
//   the RANGES themselves are hardcoded anchors (e.g. 0...50,
//   choices [0,1,5,50,500]) but per-iter values within those
//   ranges vary by seed。 chapter 一千零十七.5 / M3830 Round-25
//   HIGH-1 fix:pre-fix doctrine claimed「ZERO hardcoded numeric
//   literals」 which was empirically false (~20 range bounds and
//   choice arrays were hardcoded)。 Honest framing:proc-gen
//   PICKS,not proc-gen RANGES。 Future arc could replace ranges
//   with config-driven envelopes if value justifies。
// - Single canonical seed scheme via `testSeed(#function,
//   iteration:)` (existing ch 946 / ch 952 doctrine)

import XCTest
@testable import BASMemory
@testable import BASRuntimeCore
@testable import BASOrchestration
@testable import BASMetalSubstrate
@testable import BASSovereign

final class BASChapter1017FullyProceduralSmokeTests: XCTestCase {

    // MARK: - Procedural intensity scaling

    /// chapter 一千零十七 / M3825 — single source of truth for
    /// iter counts across all 14 layers。 The user's mandate:
    /// no dead numbers, all flexible procedural generation。
    /// Default intensity=1 = smoke (CI-friendly)。 Set
    /// BAS_FUZZ_INTENSITY=10 for device 1hr endurance run。
    private var intensity: Int {
        if let env = ProcessInfo.processInfo
            .environment["BAS_FUZZ_INTENSITY"],
           let n = Int(env), n > 0
        {
            return n
        }
        return 1
    }

    /// Per-sub-test iter count = intensity × base。 Base is a
    /// hard-floor of 10 so even intensity=1 hits ≥10 iters。
    private var iterCount: Int {
        return max(10, intensity * 10)
    }

    // chapter 一千零十八 / M3835 — Round-26 LOW-1 fix:
    // deleted unused helpers `heavyIterCount` and
    // `requireIntensity(min:)` — both declared in ch 1017 but
    // never referenced from any test。 Dead code preserved
    // through ch 1017.5 honest-framing exercise but Round-26
    // grep proved zero call sites。 Honest mode = delete what
    // isn't used。

    // MARK: - Proc-gen value helpers

    /// Deterministic procedural int in range,seeded by
    /// (test-name, iter-index)。 Replaces hardcoded numeric
    /// literals — values vary across iters but are reproducible。
    private func procInt(
        _ function: String = #function,
        iter: Int,
        range: ClosedRange<Int>
    ) -> Int {
        var rng = BASFuzzRng(
            seed: testSeed(function, iteration: iter))
        return rng.nextInt(in: range)
    }

    /// Boundary-biased pick — 50% chance of hitting min/max
    /// boundary, 50% interior。 Reveals edge-case bugs faster
    /// than uniform sampling。
    private func procIntBoundary(
        _ function: String = #function,
        iter: Int,
        choices: [Int]
    ) -> Int {
        var rng = BASFuzzRng(
            seed: testSeed(function, iteration: iter))
        return rng.pickBoundaryBiased(choices, boundaryP: 0.5)
    }

    /// Scorecard print — every sub-test emits at the end。
    /// Trend analysis tooling (ch 952.7) consumes this format。
    private func emitScorecard(
        layer: Int,
        component: String,
        iters: Int,
        durationMs: Double,
        minMs: Double,
        maxMs: Double
    ) {
        let avgMs = durationMs / Double(iters)
        // chapter 一千零十八 / M3835 — Round-25 MED-1 fix:
        // `%.2f` produced「avg=0.00ms」 for sub-millisecond
        // operations (4 of 7 layer tests at intensity=10
        // emitted all-zero scorecards),destroying trend
        // signal。 Bumped to `%.4f` — 4-decimal-precision
        // gives microsecond resolution。 Existing trend tools
        // parse「N.NN」 format (number + unit) so 4-decimal
        // works without trend-tool change。
        let avgStr = String(format: "%.4f", avgMs)
        let minStr = String(format: "%.4f", minMs)
        let maxStr = String(format: "%.4f", maxMs)
        print("📊 ch1017-scorecard | layer=L\(layer) " +
              "component=\(component) iters=\(iters) " +
              "avg=\(avgStr)ms min=\(minStr)ms " +
              "max=\(maxStr)ms intensity=\(intensity)")
    }

    /// Helper to time a closure and update min/max/total。
    ///
    /// ch 1024.8 / M3888 — 全面 audit LOW-3 fix:include
    /// `.components.seconds` so any iter taking ≥1s gets correctly
    /// accounted。 Pre-fix only counted sub-second attosecond portion。
    @discardableResult
    private func timedIter<T>(
        _ block: () throws -> T,
        minMs: inout Double,
        maxMs: inout Double,
        totalMs: inout Double
    ) rethrows -> T {
        let t0 = ContinuousClock().now
        let result = try block()
        let dur = ContinuousClock().now - t0
        let ms = Double(dur.components.seconds) * 1000.0
            + Double(dur.components.attoseconds) / 1e15
        if ms < minMs { minMs = ms }
        if ms > maxMs { maxMs = ms }
        totalMs += ms
        return result
    }

    // MARK: - L6 cortexCheck/decompose (MISSING in ch 946)

    /// L6 smoke: BASScoutInput (decompose-frame projection)
    /// emits via Scout seat across varied signal counts。
    func testL6_ScoutDecomposeFrame_AcrossSignalCounts() throws {
        let function = #function
        let n = iterCount
        var minMs: Double = .infinity
        var maxMs: Double = 0
        var totalMs: Double = 0
        for i in 0..<n {
            // Proc-gen signal counts — covers empty, sparse,
            // dense, edge cases
            let pressureCount = procInt(
                function, iter: i, range: 0...50)
            let manipCount = procInt(
                function, iter: i + 1000, range: 0...20)
            let boundaryCount = procInt(
                function, iter: i + 2000, range: 0...30)
            let contradictionCount = procIntBoundary(
                function, iter: i, choices: [0, 1, 5, 20, 100])
            let input = BASScoutInput(
                pressureSignals:
                    (0..<min(pressureCount, 10)).map {
                        "p.\($0)"
                    },
                pressureVectorCount: pressureCount,
                manipulationSignals:
                    (0..<min(manipCount, 5)).map {
                        "m.\($0)"
                    },
                manipulationPatternCount: manipCount,
                boundaryTouchCount: boundaryCount,
                contradictionRecordCount: contradictionCount,
                bareContradictions:
                    (0..<min(contradictionCount, 3)).map {
                        "c.\($0)"
                    })
            let spec = BASAgentSpec(
                agentID: "scout.l6.\(i)", role: .scout,
                writeDomains: [.situationField],
                defaultLeaseProfile: .hotSeat,
                visibility: .high)
            timedIter({
                var seq = 0
                let deltas = BASScoutSeat.emit(
                    from: input, turnID: "t.\(i)",
                    agentSpec: spec, seq: &seq)
                // chapter 一千零十七.5 / M3830 — Round-25
                // CRITICAL-4 fix:vacuous `count >= 0` was
                // always-true。 Real behavioral pin:Scout
                // emits a delta IFF any signal is present。
                let hasSignal = !input.isEmpty
                XCTAssertEqual(deltas.count > 0, hasSignal,
                    "L6 ch 1017.5: Scout MUST emit ≥1 delta " +
                    "iff input has signal。 hasSignal=" +
                    "\(hasSignal) deltaCount=\(deltas.count)")
                // Every delta MUST carry the turnID we passed
                for delta in deltas {
                    XCTAssertTrue(
                        delta.deltaID.contains("t.\(i)"),
                        "L6: deltaID MUST embed turnID")
                }
            },
            minMs: &minMs, maxMs: &maxMs, totalMs: &totalMs)
        }
        emitScorecard(
            layer: 6, component: "Scout.emit",
            iters: n, durationMs: totalMs,
            minMs: minMs, maxMs: maxMs)
    }

    // MARK: - L9 dreamLoop / candidate frontier (MISSING)

    /// L9 smoke: BASCandidateFrontier construction across
    /// varied candidateID counts + diversity scores。
    func testL9_CandidateFrontier_AcrossWidths() throws {
        let function = #function
        let n = iterCount
        var minMs: Double = .infinity
        var maxMs: Double = 0
        var totalMs: Double = 0
        for i in 0..<n {
            let width = procIntBoundary(
                function, iter: i,
                choices: [0, 1, 5, 50, 500])
            let candidates = (0..<width).map {
                "c.\(i).\($0)"
            }
            let diversity = Double(
                procInt(function, iter: i + 5000,
                        range: 0...100)) / 100.0
            timedIter({
                let frontier = BASCandidateFrontier(
                    candidateIDs: candidates,
                    dominanceOrder: candidates,
                    reversiblePaths: [],
                    guardPaths: [],
                    frontierWidth: width,
                    diversityScore: diversity,
                    delayedPaths: [])
                XCTAssertEqual(
                    frontier.frontierWidth, width)
                XCTAssertEqual(
                    frontier.diversityScore, diversity,
                    accuracy: 0.001)
            },
            minMs: &minMs, maxMs: &maxMs, totalMs: &totalMs)
        }
        emitScorecard(
            layer: 9, component: "CandidateFrontier",
            iters: n, durationMs: totalMs,
            minMs: minMs, maxMs: maxMs)
    }

    // MARK: - L10 triSelf / planner seat (MISSING)

    /// L10 smoke: BASPlannerCandidate construction +
    /// PlannerSeat.emit across varied candidate shapes。
    func testL10_PlannerSeat_AcrossCandidateShapes() throws {
        let function = #function
        let n = iterCount
        var minMs: Double = .infinity
        var maxMs: Double = 0
        var totalMs: Double = 0
        for i in 0..<n {
            let candCount = procIntBoundary(
                function, iter: i,
                choices: [0, 1, 3, 10, 50])
            let benefit = Double(
                procInt(function, iter: i + 100,
                        range: 0...100)) / 100.0
            let cost = Double(
                procInt(function, iter: i + 200,
                        range: 0...100)) / 100.0
            let reversibility = Double(
                procInt(function, iter: i + 300,
                        range: 0...100)) / 100.0
            let candidates = (0..<candCount).map { j in
                BASPlannerCandidate(
                    candidateID: "p.\(i).\(j)",
                    title: "candidate-\(j)",
                    actionSummary: "action-\(j)",
                    confidence: 0.5,
                    expectedBenefit: benefit,
                    expectedCost: cost,
                    reversibility: reversibility)
            }
            let spec = BASAgentSpec(
                agentID: "planner.l10.\(i)",
                role: .planner,
                writeDomains: [.candidateFrontier],
                defaultLeaseProfile: .hotSeat,
                visibility: .high)
            timedIter({
                var seq = 0
                let deltas = BASPlannerSeat.emit(
                    from: candidates,
                    turnID: "t.\(i)",
                    agentSpec: spec,
                    seq: &seq)
                // ch 1017.5 CRITICAL-4 fix: behavioral pin
                XCTAssertEqual(deltas.count, candidates.count,
                    "L10 ch 1017.5: Planner emits exactly 1 " +
                    "delta per candidate。 candCount=" +
                    "\(candidates.count) deltaCount=" +
                    "\(deltas.count)")
                // seq counter MUST advance by candidates.count
                XCTAssertEqual(seq, candidates.count,
                    "L10: seq advance = candidates.count")
            },
            minMs: &minMs, maxMs: &maxMs, totalMs: &totalMs)
        }
        emitScorecard(
            layer: 10, component: "PlannerSeat.emit",
            iters: n, durationMs: totalMs,
            minMs: minMs, maxMs: maxMs)
    }

    // MARK: - L1-L14 broad procedural smoke

    /// L1 smoke: BASAgentLease across varied budgets。
    func testL1_AgentLease_AcrossBudgets() throws {
        let function = #function
        let n = iterCount
        var minMs: Double = .infinity
        var maxMs: Double = 0
        var totalMs: Double = 0
        for i in 0..<n {
            let maxMsBudget = procIntBoundary(
                function, iter: i,
                choices: [1, 100, 1000, 10_000])
            let maxTokens = procIntBoundary(
                function, iter: i + 100,
                choices: [10, 100, 1000, 10_000])
            timedIter({
                let lease = BASAgentLease(
                    leaseID: "l.\(i)",
                    agentID: "a.\(i)",
                    turnID: "t.\(i)",
                    maxMs: maxMsBudget,
                    maxTokens: maxTokens,
                    maxStateReads: 100,
                    maxDeltaWrites: 10,
                    allowedDomains: [.situationField],
                    expiresAtMs: Int64.max,
                    priority: 1)
                XCTAssertEqual(lease.maxMs, maxMsBudget)
                XCTAssertEqual(lease.maxTokens, maxTokens)
            },
            minMs: &minMs, maxMs: &maxMs, totalMs: &totalMs)
        }
        emitScorecard(
            layer: 1, component: "AgentLease",
            iters: n, durationMs: totalMs,
            minMs: minMs, maxMs: maxMs)
    }

    // MARK: - L7 SharedStateGraph procedural smoke

    func testL7_SharedStateGraph_WriteRead() async throws {
        let function = #function
        let n = iterCount
        var minMs: Double = .infinity
        var maxMs: Double = 0
        var totalMs: Double = 0
        for i in 0..<n {
            let graph = BASSharedStateGraph()
            let spec = BASAgentSpec(
                agentID: "g.\(i)",
                role: .scout,
                writeDomains: [.situationField],
                defaultLeaseProfile: .hotSeat,
                visibility: .high)
            let objectIDLen = procInt(
                function, iter: i, range: 1...50)
            let objID = String(
                repeating: "o", count: objectIDLen)
            let payloadLen = procIntBoundary(
                function, iter: i + 100,
                choices: [0, 10, 100, 1000])
            let payload = String(
                repeating: "p", count: payloadLen)
            let t0 = ContinuousClock().now
            let written = try await graph.writeObject(
                domain: .situationField,
                objectID: objID,
                payloadJson: payload,
                byAgent: spec)
            let ms = Double(
                (ContinuousClock().now - t0)
                    .components.attoseconds
            ) / 1e15
            if ms < minMs { minMs = ms }
            if ms > maxMs { maxMs = ms }
            totalMs += ms
            // ch 1017.5 MED-3 fix: write was unverified pre-fix。
            // Now read it back + assert payload matches。
            let readBack = try await graph.readObject(
                ref: written.ref, byAgent: spec)
            XCTAssertEqual(readBack.payloadJson, payload,
                "L7 ch 1017.5: write-then-read MUST roundtrip " +
                "payload byte-equal")
            XCTAssertEqual(readBack.objectID, objID)
        }
        // chapter 一千零十八 / M3835 — Round-26 MED-1 fix:
        // scorecard component name now matches what's MEASURED。
        // ch 1017.5 renamed to「writeRead」 implying both ops
        // timed,but the timing block only covers write — the
        // readObject roundtrip is outside the t0/ms calc。
        // Honest name reflects that timing measures write only;
        // read provides behavioral assertion but not timing。
        emitScorecard(
            layer: 7,
            component: "SharedStateGraph.write[+verifyRead]",
            iters: n, durationMs: totalMs,
            minMs: minMs, maxMs: maxMs)
    }

    // MARK: - L11 risk field procedural smoke

    func testL11_RiskInput_AcrossSeverities() throws {
        let function = #function
        let n = iterCount
        var minMs: Double = .infinity
        var maxMs: Double = 0
        var totalMs: Double = 0
        for i in 0..<n {
            let candCount = procIntBoundary(
                function, iter: i,
                choices: [0, 1, 5, 25])
            let candidates = (0..<candCount).map { j in
                let rev = Double(
                    procInt(function,
                            iter: i * 100 + j,
                            range: 0...100)) / 100.0
                return BASRiskCandidate(
                    candidateID: "r.\(i).\(j)",
                    reversibility: rev,
                    expectedBenefit: 0.5,
                    expectedCost: 0.5)
            }
            let manipDetected = procInt(
                function, iter: i + 500,
                range: 0...1) == 1
            timedIter({
                let input = BASRiskInput(
                    candidates: candidates,
                    manipulationDetected: manipDetected)
                XCTAssertEqual(
                    input.candidates.count, candCount)
            },
            minMs: &minMs, maxMs: &maxMs, totalMs: &totalMs)
        }
        emitScorecard(
            layer: 11, component: "RiskInput",
            iters: n, durationMs: totalMs,
            minMs: minMs, maxMs: maxMs)
    }

    // MARK: - L14 sovereign audit entry procedural smoke

    func testL14_SovereignAuditEntry_AcrossSchemaVersions() throws {
        let function = #function
        let n = iterCount
        var minMs: Double = .infinity
        var maxMs: Double = 0
        var totalMs: Double = 0
        for i in 0..<n {
            let useHardened = procInt(
                function, iter: i, range: 0...1) == 1
            let schema = useHardened
                ? BASSovereignAuditEntry
                    .hardenedSchemaVersion
                : BASSovereignAuditEntry
                    .currentSchemaVersion
            let signalCount = procIntBoundary(
                function, iter: i + 100,
                choices: [0, 1, 5, 20])
            let signals = (0..<signalCount).map {
                "sig.\(i).\($0)"
            }
            timedIter({
                let entry = BASSovereignAuditEntry(
                    schemaVersion: schema,
                    auditID: "a.\(i)",
                    sessionID: "s.\(i)",
                    turnID: "t.\(i)",
                    verdictRef: "v.\(i)",
                    ruleIDs: [],
                    signalRefs: signals,
                    actionRefs: [],
                    snapshotRef: "",
                    actor: .system,
                    signature: "",
                    appendedAt: Date())
                XCTAssertEqual(entry.schemaVersion, schema)
                XCTAssertEqual(
                    entry.signalRefs.count, signalCount)
            },
            minMs: &minMs, maxMs: &maxMs, totalMs: &totalMs)
        }
        emitScorecard(
            layer: 14, component: "SovereignAuditEntry",
            iters: n, durationMs: totalMs,
            minMs: minMs, maxMs: maxMs)
    }

    // chapter 一千零十八.5 / M3840 — Round-27 LOW-2 fix:
    // empty MARK section + comment-only placeholder removed。
    // Aggregate test was deleted at ch 1018 (Round-26 MED-2)。
    // XCTest auto-discovers each test* method standalone,so
    // no aggregate needed。 See file header for the design
    // doctrine — no need to repeat at the end-of-class
    // placeholder。
}
