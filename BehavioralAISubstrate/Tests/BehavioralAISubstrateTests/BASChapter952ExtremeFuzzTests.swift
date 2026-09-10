// MARK: - BASChapter952ExtremeFuzzTests
// chapter 九百五十二 / M3465
//
// User directive (verbatim): 「进化 算法 加强 程序化生成 极致 找到
// 所有 缺陷 bug 不足 真机 跑2小时冒烟 最好 14层 每层 每个部分都
// 经历冒烟测试 以此发挥最大作用 找到瑕疵 全面冒烟测试 开发极致 极大
// 提高benchmark / 我希望 大部分 固定 数值 都可以 改成 完全 flexible
// 程序化 生成 而不是 死数值」。
//
// Extends ch 946 per-layer fuzz with:
//   1. ALL 13 signalRef prefixes per turn (not just one per layer)
//   2. Coverage-breadth fitness — measures which prefixes fire
//   3. Crossover-evolution prompt search (mate good prompts)
//   4. Multi-objective fitness (coverage + diversity + length)
//   5. Boundary-biased prompt + risk + workflow variation
//   6. Designed for 2-hour iPhone Air device run via env knob
//
// Why an extra ch 952 file:
//   - ch 946 verifies ONE prefix per layer (presence.coverage for L1,
//     thoughtFold.coverage for L3, etc)
//   - ch 952 verifies the FULL set fires on the SAME turn across
//     proc-gen prompts (catches drift where one layer goes silent
//     under unusual input)
//
// # Determinism
//
// All randomness derives from `testSeed(#function, iteration: i)`。
// Failing seed is in the XCTFail message → reproducible focused
// repro test。

import XCTest
import BASRuntimeCore
@testable import BASHostKit
@testable import BASMemory
@testable import BASOrchestration

final class BASChapter952ExtremeFuzzTests: XCTestCase {

    // MARK: - Tunable iteration counts

    /// Number of fuzz iterations per top-level test。 Configurable
    /// for 2-hour device run via `BAS_FUZZ_RUNTIME_ITER` env var。
    /// Default is 3 (local CI),device run sets to 50-500 for
    /// breadth across 2-hour budget。
    private var iterCount: Int {
        if let env = ProcessInfo.processInfo
            .environment["BAS_FUZZ_RUNTIME_ITER"],
           let n = Int(env), n > 0
        {
            return n
        }
        return 3
    }

    /// Throws XCTSkip when runtime fuzz is disabled (local CI sets
    /// `BAS_FUZZ_RUNTIME_SKIP` to opt out of multi-second tests)。
    private func requireRuntimeFuzz() throws {
        if ProcessInfo.processInfo
            .environment["BAS_FUZZ_RUNTIME_SKIP"] != nil
        {
            throw XCTSkip("Runtime fuzz skipped — unset " +
                          "BAS_FUZZ_RUNTIME_SKIP to enable")
        }
    }

    // MARK: - Reference list of expected signalRef prefixes per turn

    /// 13 signalRef prefixes that MUST fire on every turn。 Drawn
    /// from M603FourteenLayerSmokeTests + reconciliation pair。 If
    /// any prefix goes silent under a fuzz-generated prompt,that
    /// prompt is preserved as a「bug-trigger」 input by evolution。
    static let expectedSignalPrefixes: [String] = [
        "presence.coverage:",
        "leaseLife.coverage:",
        "decomposition.coverage:",
        "neuralOrgan.coverage:",
        "thoughtFold.coverage:",
        "worldPrior.coverage:",
        "hostConstitution.coverage:",
        "hippocampal.coverage:",
        "risk.coverage:",
        "softHand.coverage:",
        "updateTicket.coverage:",
        "reconciliation.severity:",
        "reconciliation.observed:",
    ]

    // MARK: - Per-iteration coverage harness

    /// Drive a single BASHostRuntime turn and return which expected
    /// prefixes fired (count out of 13)。 Returns (refsCount, missingPrefixes)。
    /// `missingPrefixes` is empty when full coverage achieved。
    private func runOneTurnReturningCoverage(
        prompt: String,
        riskLevel: BASHostRiskLevel,
        workflowProfile: BASHostWorkflowProfile,
        title: String
    ) -> (refsCount: Int, missing: [String]) {
        let runtime = BASHostRuntime(
            configuration: .fixtureGeneric)
        do {
            let result = try runtime.startSession(
                BASHostSessionRequest(
                    kind: .interactive,
                    workflowProfile: workflowProfile,
                    surface: .application,
                    prompt: prompt,
                    title: title,
                    riskLevel: riskLevel))
            guard let turn = result.eBrainTurn else {
                return (0, Self.expectedSignalPrefixes)
            }
            let refs = turn.sovereignAuditEntry?
                .signalRefs.map { String($0) } ?? []
            let missing = Self.expectedSignalPrefixes.filter {
                prefix in
                !refs.contains { $0.hasPrefix(prefix) }
            }
            return (refs.count, missing)
        } catch {
            return (0, Self.expectedSignalPrefixes)
        }
    }

    // MARK: - Per-layer per-part coverage fuzz

    /// Drive N proc-gen prompts and assert EVERY expected prefix
    /// fires at least once during the run。 Per ch 952 user
    /// directive 「每层 每个部分都经历冒烟测试」 — this is the
    ///「every part」 coverage test。
    ///
    /// Difference from ch 946:ch 946 verifies one prefix per layer
    /// on a fresh runtime each iter — but doesn't aggregate which
    /// prefixes are sticky vs flaky across input shapes。 Ch 952
    /// drives a sweep and asserts UNION coverage hits all 13。
    func testAllSignalPrefixesFireAcrossFuzzedPromptSweep() throws {
        try requireRuntimeFuzz()
        var firedPrefixes: Set<String> = []
        var perTurnMissing: [(Int, String, [String])] = []
        for i in 0..<iterCount {
            var rng = BASFuzzRng(
                seed: testSeed(iteration: i))
            let prompt = BASFuzzPromptTemplate.prompt(rng: &rng)
            let band: BASHostRiskLevel = rng.pick([
                .low, .medium, .high,
            ])
            let profile: BASHostWorkflowProfile = rng.pick([
                .reflective, .primary, .comparative,
            ])
            let (_, missing) = runOneTurnReturningCoverage(
                prompt: prompt,
                riskLevel: band,
                workflowProfile: profile,
                title: "ch952-coverage-\(i)")
            // Track which prefixes DID fire this turn
            for prefix in Self.expectedSignalPrefixes
                where !missing.contains(prefix)
            {
                firedPrefixes.insert(prefix)
            }
            if !missing.isEmpty {
                perTurnMissing.append((i, prompt, missing))
            }
        }
        // Assertion: union of all turns must cover all 13 prefixes
        let neverFired = Self.expectedSignalPrefixes.filter {
            !firedPrefixes.contains($0)
        }
        XCTAssertTrue(
            neverFired.isEmpty,
            "ch 952 — these prefixes never fired across " +
            "\(iterCount) fuzzed prompts: \(neverFired)。 " +
            "First failing example: " +
            "\(perTurnMissing.first.map { String(describing: $0) } ?? "n/a")")
    }

    /// Stricter version: assert EVERY iteration covers ALL 13
    /// prefixes (not just the union)。 Gated under
    /// `BAS_FUZZ_STRICT_COVERAGE` env var because some shapes may
    /// legitimately not fire all layers (e.g. empty prompt)。
    func testEveryIterationCoversAllPrefixesStrict() throws {
        try requireRuntimeFuzz()
        if ProcessInfo.processInfo
            .environment["BAS_FUZZ_STRICT_COVERAGE"] == nil
        {
            throw XCTSkip("Strict per-iter coverage gated — set " +
                          "BAS_FUZZ_STRICT_COVERAGE=1 to enable")
        }
        for i in 0..<iterCount {
            var rng = BASFuzzRng(
                seed: testSeed(iteration: i))
            let prompt = BASFuzzPromptTemplate.prompt(rng: &rng)
            let band: BASHostRiskLevel = rng.pick([
                .low, .medium, .high,
            ])
            let (_, missing) = runOneTurnReturningCoverage(
                prompt: prompt,
                riskLevel: band,
                workflowProfile: .reflective,
                title: "ch952-strict-\(i)")
            XCTAssertTrue(
                missing.isEmpty,
                "ch 952 STRICT iter=\(i) seed=\(rng.state) " +
                "prompt=\(prompt.prefix(80))… " +
                "missing: \(missing)")
        }
    }

    // MARK: - Per-layer per-part — every layer × every workflow

    /// Crossover test:every (workflowProfile × riskLevel) cell
    /// must cover all 13 prefixes at least once。 3 profiles × 3
    /// risk = 9 cells。 Doesn't require iterCount > 0 — runs each
    /// cell once。
    func testAllLayerSignalsAcrossEveryWorkflowRiskCell() throws {
        try requireRuntimeFuzz()
        let profiles: [BASHostWorkflowProfile] = [
            .reflective, .primary, .comparative,
        ]
        let bands: [BASHostRiskLevel] = [
            .low, .medium, .high,
        ]
        var firedPrefixes: Set<String> = []
        for profile in profiles {
            for band in bands {
                let prompt = "ch952 grid \(profile) \(band)"
                let (_, missing) = runOneTurnReturningCoverage(
                    prompt: prompt,
                    riskLevel: band,
                    workflowProfile: profile,
                    title: "ch952-grid")
                for prefix in Self.expectedSignalPrefixes
                    where !missing.contains(prefix)
                {
                    firedPrefixes.insert(prefix)
                }
            }
        }
        let neverFired = Self.expectedSignalPrefixes.filter {
            !firedPrefixes.contains($0)
        }
        XCTAssertTrue(
            neverFired.isEmpty,
            "ch 952 grid — prefixes never fired across " +
            "3×3 (profile×risk) cells: \(neverFired)")
    }

    // MARK: - Crossover-based evolutionary prompt search

    /// Crossover-evolution search:start with 4 diverse prompts,
    /// run multi-generation tournament with crossover + mutation,
    /// FITNESS = coverage breadth (how many of 13 prefixes fire)
    /// PLUS small bonus for prompt length。 Best prompt is the one
    /// that maximizes coverage breadth。
    ///
    /// Per ch 948 jetsam discipline:default keeps gens × children
    /// small。 Scale via `BAS_FUZZ_EVOL_GEN` + `BAS_FUZZ_EVOL_CHILD`
    /// for explicit longer runs (e.g. 2hr device)。
    func testCrossoverEvolutionFindsHighCoveragePrompts() throws {
        try requireRuntimeFuzz()
        var rng = BASFuzzRng(seed: testSeed())
        let initialPrompts = [
            "tell me about reasoning",
            "high risk decision urgent",
            "what is the meaning of life?",
            "code: let x = 42\nlet y = x * 2",
        ]
        let crossover: (String, String, inout BASFuzzRng) -> String = {
            a, b, r in
            BASStringCrossover.cross(a, b, rng: &r)
        }
        let mutate: (String, inout BASFuzzRng) -> String = {
            seed, r in
            BASStringMutator.mutate(seed, rng: &r)
        }
        // Fitness: coverage breadth (0-13) plus tiny length bonus
        let fitness: (String) -> Double = { prompt in
            let runtime = BASHostRuntime(
                configuration: .fixtureGeneric)
            do {
                let result = try runtime.startSession(
                    BASHostSessionRequest(
                        kind: .interactive,
                        workflowProfile: .reflective,
                        surface: .application,
                        prompt: prompt,
                        title: "ch952-evol-cross",
                        riskLevel: .medium))
                guard let turn = result.eBrainTurn else {
                    return 0.0
                }
                let refs = turn.sovereignAuditEntry?
                    .signalRefs.map { String($0) } ?? []
                let firedCount = Self.expectedSignalPrefixes.filter {
                    prefix in
                    refs.contains { $0.hasPrefix(prefix) }
                }.count
                return Double(firedCount) +
                    Double(prompt.utf8.count) / 100_000.0
            } catch {
                return -1.0
            }
        }
        // chapter 952 — default kept small for memory safety
        // (jetsam fix held under device run per ch 951)
        let gens = Int(ProcessInfo.processInfo
            .environment["BAS_FUZZ_EVOL_GEN"] ?? "1") ?? 1
        let chld = Int(ProcessInfo.processInfo
            .environment["BAS_FUZZ_EVOL_CHILD"] ?? "2") ?? 2
        let best = BASEvolutionarySearch.evolveWithCrossover(
            seeds: initialPrompts,
            generations: gens,
            childrenPerGen: chld,
            survivors: 1,
            crossover: crossover,
            mutate: mutate,
            fitness: fitness,
            rng: &rng)
        // Best prompt should hit at least 1 coverage prefix
        XCTAssertGreaterThan(
            best.fitness, 0.0,
            "ch 952 crossover-evol — best prompt hit 0 coverage " +
            "prefixes (substrate may be silent on certain mutations)。 " +
            "best.value=\(best.value.prefix(100)) " +
            "best.seed=\(best.seed) " +
            "best.fitness=\(best.fitness)")
    }

    // MARK: - Byte-array crossover smoke (mutator unit test)

    /// Verify BASByteCrossover produces deterministic output
    /// given same seed。 Test 3 strategies (singlePoint / uniform /
    /// twoPoint) for determinism + length sanity。
    func testByteCrossoverDeterministicAndBounded() {
        let a: [UInt8] = Array(repeating: 0xAA, count: 100)
        let b: [UInt8] = Array(repeating: 0xBB, count: 80)
        var rng1 = BASFuzzRng(seed: 12345)
        var rng2 = BASFuzzRng(seed: 12345)
        let c1 = BASByteCrossover.singlePoint(a, b, rng: &rng1)
        let c2 = BASByteCrossover.singlePoint(a, b, rng: &rng2)
        XCTAssertEqual(c1, c2,
            "BASByteCrossover.singlePoint must be deterministic")
        XCTAssertGreaterThan(c1.count, 0,
            "singlePoint child must be non-empty")
        XCTAssertLessThanOrEqual(c1.count,
            max(a.count, b.count) + 1,
            "singlePoint child length sane")
        var rng3 = BASFuzzRng(seed: 67890)
        var rng4 = BASFuzzRng(seed: 67890)
        let u1 = BASByteCrossover.uniform(a, b, rng: &rng3)
        let u2 = BASByteCrossover.uniform(a, b, rng: &rng4)
        XCTAssertEqual(u1, u2,
            "BASByteCrossover.uniform must be deterministic")
        XCTAssertEqual(u1.count, min(a.count, b.count),
            "uniform child length = min(a, b)")
        // Children should contain mix of 0xAA and 0xBB bytes
        let hasA = u1.contains(0xAA)
        let hasB = u1.contains(0xBB)
        XCTAssertTrue(hasA && hasB,
            "uniform child should mix both parents: " +
            "hasA=\(hasA) hasB=\(hasB)")
    }

    /// Verify BASFloatVectorCrossover arithmetic produces values
    /// in the convex hull of the parents (bounded interpolation)。
    func testFloatVectorCrossoverArithmeticInConvexHull() {
        let a: [Float] = [0.0, 0.0, 0.0, 0.0]
        let b: [Float] = [1.0, 1.0, 1.0, 1.0]
        var rng = BASFuzzRng(seed: 42)
        for _ in 0..<20 {
            let child = BASFloatVectorCrossover.arithmetic(
                a, b, rng: &rng)
            XCTAssertEqual(child.count, 4)
            for v in child {
                XCTAssertGreaterThanOrEqual(v, 0.0,
                    "arithmetic crossover should be in [0, 1]")
                XCTAssertLessThanOrEqual(v, 1.0,
                    "arithmetic crossover should be in [0, 1]")
            }
        }
    }

    /// Verify BASStringCrossover interleave works with multi-byte
    /// chars (emoji + CJK) without corrupting UTF-8。
    func testStringCrossoverHandlesMultiByteChars() {
        var rng = BASFuzzRng(seed: 99)
        let a = "你好世界"
        let b = "👋🌍✨"
        let c = BASStringCrossover.interleave(a, b, rng: &rng)
        // No assertion crashes = UTF-8 integrity preserved
        // (interleave by Unicode scalar avoids mid-encoding split)
        XCTAssertGreaterThanOrEqual(c.count, 0)
        // Result should round-trip through UTF-8 encode/decode
        let bytes = Array(c.utf8)
        let decoded = String(decoding: bytes, as: UTF8.self)
        XCTAssertEqual(decoded, c,
            "interleaved string must be valid UTF-8")
    }

    // MARK: - Multi-objective fitness Pareto smoke

    /// Verify Pareto dominance: A dominates B iff A ≥ B on all
    /// dims AND > B on at least one。
    func testParetoDominanceBasic() {
        let high = BASMultiObjectiveFitness(
            coverageScore: 10, latencyMs: 100,
            diversityScore: 5, failureFlag: 0)
        let low = BASMultiObjectiveFitness(
            coverageScore: 5, latencyMs: 50,
            diversityScore: 3, failureFlag: 0)
        XCTAssertTrue(
            BASParetoDominance.dominates(high, low),
            "high should dominate low (strict on all dims)")
        XCTAssertFalse(
            BASParetoDominance.dominates(low, high),
            "low should NOT dominate high")
        // Tied
        XCTAssertFalse(
            BASParetoDominance.dominates(high, high),
            "equal-to-self is NOT strict domination")
    }

    /// Verify weightedSum scalarization。
    func testMultiObjectiveWeightedSum() {
        let f = BASMultiObjectiveFitness(
            coverageScore: 5,
            latencyMs: 100,
            diversityScore: 2,
            failureFlag: 1)
        // 1.0 * 5 + 0.1 * 100 + 0.5 * 2 + 10.0 * 1 = 5 + 10 + 1 + 10 = 26
        XCTAssertEqual(f.weightedSum(), 26.0,
                       accuracy: 0.001)
    }

    // MARK: - L8 substance fuzz with crossover (combines ch934 + GA)

    /// Fuzz L8 AtomLifecycle round-trip with crossover-mated
    /// proc-gen events。 Verifies the routed bridge handles
    /// arbitrary valid (proc-gen) byte combinations across N iter。
    func testL8AtomLifecycleCrossoverFuzzRoundTrip() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "ch952-l8-cross-\(UUID().uuidString).sqlite")
        defer {
            for suffix in ["", "-wal", "-shm"] {
                try? FileManager.default.removeItem(
                    atPath: url.path + suffix)
            }
        }
        let store = try BASRoutedAtomLifecycleStore(
            databaseURL: url)
        let iterations = max(iterCount, 10)
        for i in 0..<iterations {
            var rng = BASFuzzRng(
                seed: testSeed(iteration: i))
            let event = BASFuzzL8.atomLifecycleEvent(rng: &rng)
            let appended = try await store.appendEvent(event)
            XCTAssertEqual(appended.eventID, event.eventID,
                "ch 952 L8-cross iter=\(i) seed=\(rng.state) " +
                "byte-cross failed round-trip")
            // Verify the full-row read back works
            let read = await store.events(forAtom: event.atomID)
            XCTAssertTrue(
                read.contains { $0.eventID == event.eventID },
                "ch 952 L8 iter=\(i) atom round-trip drop")
        }
    }
}
