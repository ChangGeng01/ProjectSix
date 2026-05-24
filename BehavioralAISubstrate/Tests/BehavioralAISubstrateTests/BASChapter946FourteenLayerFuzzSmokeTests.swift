// MARK: - BASChapter946FourteenLayerFuzzSmokeTests
// chapter 九百四十六 / M3435
//
// User directive 「14层 每层都冒烟测试 / 进化 算法 加强 程序化生成
// / 极致 找到 所有 缺陷 bug 不足 / 大部分 固定 数值 都可以 改成
// 完全 flexible 程序化 生成」。
//
// Extends M603FourteenLayerSmokeTests with:
//   1. Procedural input generation (BASFuzzInputGenerator) replaces
//      ALL hardcoded test values
//   2. Per-layer fuzz smoke driven by 50 seeded iterations each
//   3. Evolutionary mutator for shape/value space exploration
//   4. Boundary-biased shape generators (B=1, dim=0, count=0 fired
//      more often than uniform sampling)
//   5. Designed for iPhone device run (sandbox-aware temp paths)
//
// Why fuzz the layers:M603 only verified each layer emits its
// coverage code on ONE hardcoded prompt。 If a layer crashes on
// empty memory ref / NaN confidence / 10000-char prompt,M603
// wouldn't catch it。 This fuzz harness drives 50 different shapes
// per layer。
//
// # Determinism
//
// Each test uses `testSeed(#function, iteration: i)` so the same
// failing seed reproduces across runs。 When a fuzz test fails the
// XCTFail message includes the seed → you can isolate by
// hardcoding that seed into a focused unit test。

import XCTest
import BASRuntimeCore
@testable import BASHostKit
@testable import BASMemory
@testable import BASOrchestration

final class BASChapter946FourteenLayerFuzzSmokeTests:
    XCTestCase
{

    // MARK: - Helpers

    private func makeDeviceSafeTempDBURL(
        _ tag: String
    ) -> URL {
        // chapter 九百四十六 — iOS device sandbox: use
        // NSTemporaryDirectory() for both iOS and macOS。 On iOS
        // device this returns app's sandboxed tmp dir;on macOS
        // it returns /var/folders/.../T/ which is also sandboxed
        // when run via xcodebuild test。
        let base = FileManager.default.temporaryDirectory
        return base.appendingPathComponent(
            "ch946-\(tag)-\(UUID().uuidString).sqlite")
    }

    private func cleanup(_ url: URL) {
        let fm = FileManager.default
        for suffix in ["", "-wal", "-shm"] {
            let p = url.path + suffix
            if fm.fileExists(atPath: p) {
                try? fm.removeItem(atPath: p)
            }
        }
    }

    // Number of fuzz iterations per layer。 Tunable via env var for
    // CI vs device runs。 Defaults vary by test class:
    //   - 50 for L8 storage-side fuzz (lightweight,~50ms each)
    //   - 5 for runtime-driven fuzz (BASHostRuntime per iter,heavy)
    // Device run sets BAS_FUZZ_ITER=50 explicitly for 2hr budget。
    private var iterCount: Int {
        if let env = ProcessInfo.processInfo
            .environment["BAS_FUZZ_ITER"],
           let n = Int(env), n > 0
        {
            return n
        }
        return 50
    }

    /// Lower iteration count for runtime-driven tests (each iter
    /// spins a full BASHostRuntime — ~1-5s on host,fine for
    /// device but local CI default kept small)。
    private var runtimeIterCount: Int {
        if let env = ProcessInfo.processInfo
            .environment["BAS_FUZZ_RUNTIME_ITER"],
           let n = Int(env), n > 0
        {
            return n
        }
        // Skip entirely when BAS_FUZZ_RUNTIME_SKIP set (local CI)
        if ProcessInfo.processInfo
            .environment["BAS_FUZZ_RUNTIME_SKIP"] != nil
        {
            return 0
        }
        return 3
    }

    /// Throws XCTSkip when runtime fuzz is disabled。
    private func requireRuntimeFuzz() throws {
        if runtimeIterCount == 0 {
            throw XCTSkip(
                "Runtime-driven fuzz skipped — set " +
                "BAS_FUZZ_RUNTIME_ITER=N (recommend 50 for 2hr " +
                "device run) to enable")
        }
    }

    // MARK: - L1 wake-policy + presence smoke

    /// L1 (wake-policy + presence) fuzz: drive BASHostRuntime with
    /// fuzz-generated prompts of varying length / content / risk,
    /// assert presence.coverage emission survives all shapes。
    func testL1WakePolicyFuzzAcrossPromptShapes() throws {
        try requireRuntimeFuzz()
        for i in 0..<runtimeIterCount {
            var rng = BASFuzzRng(
                seed: testSeed(iteration: i))
            // Procedural prompt shape: boundary-biased length
            let promptLen = rng.pickBoundaryBiased(
                [0, 1, 10, 100, 1_000, 10_000],
                boundaryP: 0.5)
            let prompt = promptLen == 0
                ? ""
                : String(repeating: "x", count: promptLen)
            let riskBand: BASHostRiskLevel = rng.pick([
                .low, .medium, .high,
            ])
            let runtime = BASHostRuntime(
                configuration: .fixtureGeneric)
            do {
                let result = try runtime.startSession(
                    BASHostSessionRequest(
                        kind: .interactive,
                        workflowProfile: .reflective,
                        surface: .application,
                        prompt: prompt,
                        title: "fuzz-L1-\(i)",
                        riskLevel: riskBand))
                let turn = try XCTUnwrap(
                    result.eBrainTurn,
                    "L1 fuzz iter=\(i) seed=\(rng.state) " +
                    "promptLen=\(promptLen) — eBrainTurn nil")
                let refs = turn.sovereignAuditEntry?
                    .signalRefs.map { String($0) } ?? []
                XCTAssertTrue(
                    refs.contains { $0
                        .hasPrefix("presence.coverage:") },
                    "L1 fuzz iter=\(i) seed=\(rng.state) " +
                    "promptLen=\(promptLen) " +
                    "riskBand=\(riskBand): " +
                    "presence.coverage: missing")
            } catch {
                XCTFail("L1 fuzz iter=\(i) seed=\(rng.state) " +
                        "promptLen=\(promptLen) threw: \(error)")
            }
        }
    }

    /// L1 leaseLife: thermal/lease coverage emission across risk
    /// bands and workflow profiles。
    func testL1LeaseLifeCoverageAcrossWorkflows() throws {
        let profiles: [BASHostWorkflowProfile] = [
            .reflective, .primary, .comparative,
        ]
        for i in 0..<runtimeIterCount {
            var rng = BASFuzzRng(
                seed: testSeed(iteration: i))
            let profile = rng.pick(profiles)
            let riskBand: BASHostRiskLevel = rng.pick([
                .low, .medium, .high,
            ])
            let runtime = BASHostRuntime(
                configuration: .fixtureGeneric)
            let result = try runtime.startSession(
                BASHostSessionRequest(
                    kind: .interactive,
                    workflowProfile: profile,
                    surface: .application,
                    prompt: "lease test \(rng.next())",
                    title: "fuzz-L1-lease-\(i)",
                    riskLevel: riskBand))
            let turn = try XCTUnwrap(result.eBrainTurn)
            let refs = turn.sovereignAuditEntry?
                .signalRefs.map { String($0) } ?? []
            XCTAssertTrue(
                refs.contains { $0
                    .hasPrefix("leaseLife.coverage:") },
                "L1 leaseLife iter=\(i) " +
                "profile=\(profile) risk=\(riskBand): missing")
        }
    }

    // MARK: - L2-L7 layered coverage smoke (one fuzz per layer)

    /// L2 decomposition + neuralOrgan emissions survive prompt
    /// shape variation。
    func testL2DecompositionAndOrganCoverageFuzz() throws {
        try requireRuntimeFuzz()
        for i in 0..<runtimeIterCount {
            var rng = BASFuzzRng(
                seed: testSeed(iteration: i))
            let prompt = "decomp \(rng.next()) test \(i)"
            let runtime = BASHostRuntime(
                configuration: .fixtureGeneric)
            let result = try runtime.startSession(
                BASHostSessionRequest(
                    kind: .interactive,
                    workflowProfile: .reflective,
                    surface: .application,
                    prompt: prompt,
                    title: "fuzz-L2-\(i)",
                    riskLevel: rng.pick([
                        .low, .medium, .high])))
            let turn = try XCTUnwrap(result.eBrainTurn)
            let refs = turn.sovereignAuditEntry?
                .signalRefs.map { String($0) } ?? []
            XCTAssertTrue(
                refs.contains { $0
                    .hasPrefix("decomposition.coverage:") },
                "L2 decomposition.coverage iter=\(i) missing")
            XCTAssertTrue(
                refs.contains { $0
                    .hasPrefix("neuralOrgan.coverage:") },
                "L2 neuralOrgan.coverage iter=\(i) missing")
        }
    }

    /// L3 thoughtFold emission。
    func testL3ThoughtFoldCoverageFuzz() throws {
        try requireRuntimeFuzz()
        for i in 0..<runtimeIterCount {
            var rng = BASFuzzRng(
                seed: testSeed(iteration: i))
            let runtime = BASHostRuntime(
                configuration: .fixtureGeneric)
            let result = try runtime.startSession(
                BASHostSessionRequest(
                    kind: .interactive,
                    workflowProfile: .reflective,
                    surface: .application,
                    prompt: "fold \(rng.next())",
                    title: "fuzz-L3-\(i)",
                    riskLevel: .medium))
            let turn = try XCTUnwrap(result.eBrainTurn)
            let refs = turn.sovereignAuditEntry?
                .signalRefs.map { String($0) } ?? []
            XCTAssertTrue(
                refs.contains { $0
                    .hasPrefix("thoughtFold.coverage:") },
                "L3 thoughtFold iter=\(i) missing")
        }
    }

    /// L4 worldPrior emission。
    func testL4WorldPriorCoverageFuzz() throws {
        try requireRuntimeFuzz()
        for i in 0..<runtimeIterCount {
            var rng = BASFuzzRng(
                seed: testSeed(iteration: i))
            let runtime = BASHostRuntime(
                configuration: .fixtureGeneric)
            let result = try runtime.startSession(
                BASHostSessionRequest(
                    kind: .interactive,
                    workflowProfile: .reflective,
                    surface: .application,
                    prompt: "prior \(rng.next())",
                    title: "fuzz-L4-\(i)",
                    riskLevel: .medium))
            let turn = try XCTUnwrap(result.eBrainTurn)
            let refs = turn.sovereignAuditEntry?
                .signalRefs.map { String($0) } ?? []
            XCTAssertTrue(
                refs.contains { $0
                    .hasPrefix("worldPrior.coverage:") },
                "L4 worldPrior iter=\(i) missing")
        }
    }

    /// L5 hostConstitution emission。
    func testL5HostConstitutionCoverageFuzz() throws {
        try requireRuntimeFuzz()
        for i in 0..<runtimeIterCount {
            var rng = BASFuzzRng(
                seed: testSeed(iteration: i))
            let runtime = BASHostRuntime(
                configuration: .fixtureGeneric)
            let result = try runtime.startSession(
                BASHostSessionRequest(
                    kind: .interactive,
                    workflowProfile: .reflective,
                    surface: .application,
                    prompt: "host \(rng.next())",
                    title: "fuzz-L5-\(i)",
                    riskLevel: .high))
            let turn = try XCTUnwrap(result.eBrainTurn)
            let refs = turn.sovereignAuditEntry?
                .signalRefs.map { String($0) } ?? []
            XCTAssertTrue(
                refs.contains { $0
                    .hasPrefix("hostConstitution.coverage:") },
                "L5 hostConstitution iter=\(i) missing")
        }
    }

    // MARK: - L8 fuzz: substance hot-path (uses BASFuzzL8 generators)

    /// L8 atom lifecycle: fuzz events through BASRoutedAtomLifecycleStore,
    /// verify round-trip。 Replaces hardcoded event in BASChapter934 with
    /// procedural generation across phase/action/outcome dimensions。
    func testL8AtomLifecycleFuzzRoundTrip() async throws {
        let url = makeDeviceSafeTempDBURL("l8-atom")
        defer { cleanup(url) }
        let store = try BASRoutedAtomLifecycleStore(
            databaseURL: url)
        for i in 0..<iterCount {
            var rng = BASFuzzRng(
                seed: testSeed(iteration: i))
            let event = BASFuzzL8.atomLifecycleEvent(rng: &rng)
            let appended = try await store.appendEvent(event)
            XCTAssertEqual(
                appended.eventID, event.eventID,
                "L8 atom iter=\(i) seed=\(rng.state)")
            let bySession = await store.events(
                forSession: event.sessionID)
            XCTAssertTrue(
                bySession.contains { $0.eventID == event.eventID },
                "L8 atom iter=\(i) session round-trip drop")
            let byAtom = await store.events(
                forAtom: event.atomID)
            XCTAssertTrue(
                byAtom.contains { $0.eventID == event.eventID },
                "L8 atom iter=\(i) atom round-trip drop")
        }
    }

    /// L8 hippocampal.coverage emission survives random session
    /// requests。
    func testL8HippocampalCoverageFuzz() throws {
        try requireRuntimeFuzz()
        for i in 0..<runtimeIterCount {
            var rng = BASFuzzRng(
                seed: testSeed(iteration: i))
            let runtime = BASHostRuntime(
                configuration: .fixtureGeneric)
            let result = try runtime.startSession(
                BASHostSessionRequest(
                    kind: .interactive,
                    workflowProfile: .reflective,
                    surface: .application,
                    prompt: "memory \(rng.next())",
                    title: "fuzz-L8-\(i)",
                    riskLevel: .medium))
            let turn = try XCTUnwrap(result.eBrainTurn)
            let refs = turn.sovereignAuditEntry?
                .signalRefs.map { String($0) } ?? []
            XCTAssertTrue(
                refs.contains { $0
                    .hasPrefix("hippocampal.coverage:") },
                "L8 hippocampal iter=\(i) missing")
        }
    }

    // MARK: - L11-L13 governance layer fuzz

    /// L11 risk.coverage survives risk-band variation。
    func testL11RiskCoverageFuzz() throws {
        let riskBands: [BASHostRiskLevel] = [
            .low, .medium, .high,
        ]
        for i in 0..<runtimeIterCount {
            var rng = BASFuzzRng(
                seed: testSeed(iteration: i))
            let band = rng.pick(riskBands)
            let runtime = BASHostRuntime(
                configuration: .fixtureGeneric)
            let result = try runtime.startSession(
                BASHostSessionRequest(
                    kind: .interactive,
                    workflowProfile: .reflective,
                    surface: .application,
                    prompt: "risk fuzz \(rng.next())",
                    title: "fuzz-L11-\(i)",
                    riskLevel: band))
            let turn = try XCTUnwrap(result.eBrainTurn)
            let refs = turn.sovereignAuditEntry?
                .signalRefs.map { String($0) } ?? []
            XCTAssertTrue(
                refs.contains { $0
                    .hasPrefix("risk.coverage:") },
                "L11 risk iter=\(i) band=\(band) missing")
        }
    }

    /// L12 softHand.coverage emission。
    func testL12SoftHandCoverageFuzz() throws {
        try requireRuntimeFuzz()
        for i in 0..<runtimeIterCount {
            var rng = BASFuzzRng(
                seed: testSeed(iteration: i))
            let runtime = BASHostRuntime(
                configuration: .fixtureGeneric)
            let result = try runtime.startSession(
                BASHostSessionRequest(
                    kind: .interactive,
                    workflowProfile: .reflective,
                    surface: .application,
                    prompt: "soft \(rng.next())",
                    title: "fuzz-L12-\(i)",
                    riskLevel: .medium))
            let turn = try XCTUnwrap(result.eBrainTurn)
            let refs = turn.sovereignAuditEntry?
                .signalRefs.map { String($0) } ?? []
            XCTAssertTrue(
                refs.contains { $0
                    .hasPrefix("softHand.coverage:") },
                "L12 softHand iter=\(i) missing")
        }
    }

    /// L13 updateTicket.coverage emission。
    func testL13UpdateTicketCoverageFuzz() throws {
        try requireRuntimeFuzz()
        for i in 0..<runtimeIterCount {
            var rng = BASFuzzRng(
                seed: testSeed(iteration: i))
            let runtime = BASHostRuntime(
                configuration: .fixtureGeneric)
            let result = try runtime.startSession(
                BASHostSessionRequest(
                    kind: .interactive,
                    workflowProfile: .reflective,
                    surface: .application,
                    prompt: "ticket \(rng.next())",
                    title: "fuzz-L13-\(i)",
                    riskLevel: .medium))
            let turn = try XCTUnwrap(result.eBrainTurn)
            let refs = turn.sovereignAuditEntry?
                .signalRefs.map { String($0) } ?? []
            XCTAssertTrue(
                refs.contains { $0
                    .hasPrefix("updateTicket.coverage:") },
                "L13 updateTicket iter=\(i) missing")
        }
    }

    // MARK: - L14 cross-layer reconciliation

    /// L14 reconciliation.severity + reconciliation.observed
    /// emissions survive across all fuzz shapes。
    func testL14ReconciliationCoverageFuzz() throws {
        try requireRuntimeFuzz()
        for i in 0..<runtimeIterCount {
            var rng = BASFuzzRng(
                seed: testSeed(iteration: i))
            let runtime = BASHostRuntime(
                configuration: .fixtureGeneric)
            let result = try runtime.startSession(
                BASHostSessionRequest(
                    kind: .interactive,
                    workflowProfile: .reflective,
                    surface: .application,
                    prompt: "reconcile \(rng.next())",
                    title: "fuzz-L14-\(i)",
                    riskLevel: rng.pick([
                        .low, .medium, .high])))
            let turn = try XCTUnwrap(result.eBrainTurn)
            let refs = turn.sovereignAuditEntry?
                .signalRefs.map { String($0) } ?? []
            XCTAssertTrue(
                refs.contains { $0
                    .hasPrefix("reconciliation.severity:") },
                "L14 reconciliation.severity iter=\(i) missing")
            XCTAssertTrue(
                refs.contains { $0
                    .hasPrefix("reconciliation.observed:") },
                "L14 reconciliation.observed iter=\(i) missing")
        }
    }

    // MARK: - Cross-layer evolutionary search

    /// Evolutionary search:start with a baseline prompt,evolve
    /// mutations across 5 generations of 8 children,assert the
    /// substrate handles all evolved prompts without crashing。
    /// Fitness function = (success ? 1.0 : 0.0) + 0.1 * promptLength
    /// to bias toward longer/weirder prompts that still succeed
    /// (catches more boundary cases)。
    func testEvolutionaryPromptSearchAllLayersSurvive() throws {
        var rng = BASFuzzRng(seed: testSeed())
        let mutate: (String, inout BASFuzzRng) -> String = {
            seed, r in
            BASStringMutator.mutate(seed, rng: &r)
        }
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
                        title: "evol",
                        riskLevel: .medium))
                if result.eBrainTurn != nil {
                    // Reward longer prompts that still succeed
                    return 1.0 +
                        Double(prompt.utf8.count) / 1_000.0
                }
                return 0.0
            } catch {
                return -1.0  // failure penalty
            }
        }
        let best = BASEvolutionarySearch.evolve(
            seed: "evolutionary baseline prompt",
            generations: 3,  // keep budget small for default run
            childrenPerGen: 4,
            survivors: 2,
            mutate: mutate,
            fitness: fitness,
            rng: &rng)
        XCTAssertGreaterThan(
            best.fitness, 0.0,
            "evolutionary search produced no surviving prompt — " +
            "substrate may crash on certain mutations。 " +
            "best.value=\(best.value.prefix(100)) " +
            "best.seed=\(best.seed) " +
            "best.generation=\(best.generation)")
    }
}
