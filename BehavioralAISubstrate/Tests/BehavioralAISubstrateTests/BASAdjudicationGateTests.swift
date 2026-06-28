import XCTest
@testable import BASHostKit
import BASOrgan
import BASMemory

/// observe→DISPOSE — the NEUROMODULATION gate (biomimetic-brain-efficiency): the adjudicator is a TIER engaged
/// by `ε × stakes × headroom`, not an always-on wrap. These tests cover the gate decisions, env parsing,
/// composition, and — the load-bearing one — that a gate SKIP is genuine AVOIDED COMPUTE (no embed at all).
final class BASAdjudicationGateTests: XCTestCase {

    // MARK: - Doubles

    private struct EchoInner: BASOrganAdapter {
        var descriptor: BASOrganDescriptor {
            BASOrganDescriptor(providerID: "echo", providerName: "echo", supportsStreaming: false,
                               maxInputTokens: 4096, maxOutputTokens: 256, runsOnDevice: true, supportedRoles: [.core, .scout])
        }
        func currentCapacity() async -> BASOrganCapacity { .unlimited }
        func draft(_ request: BASOrganRequest) async throws -> BASOrganDraft {
            BASOrganDraft(requestID: request.requestID, providerID: "echo", role: request.role,
                          body: request.instruction, inputTokensEstimated: 0, outputTokensEstimated: 0,
                          producedAt: Date(timeIntervalSince1970: 0), traceID: "t")
        }
    }

    /// Embedding provider that COUNTS every embed call — so a test can prove a gate skip never reaches the bank.
    private actor CallCounter { private(set) var n = 0; func bump() { n += 1 } }
    private final class CountingProvider: BASMemory.BASEmbeddingProvider, @unchecked Sendable {
        let providerVersion = "count-v1"
        let dimension = 4
        let counter = CallCounter()
        func calls() async -> Int { await counter.n }
        func embed(_ text: String) async -> BASMemory.BASEmbedding {
            await counter.bump()
            let t = text.lowercased()
            var v: [Float] = [0, 0, 0, 0]
            if t.contains("penicillin") || t.contains("fleming") { v[0] = 1 }
            if v == [0, 0, 0, 0] { v[3] = 1 }
            return BASMemory.BASEmbedding(vector: v, dimension: 4, providerVersion: providerVersion)
        }
    }

    private func req(_ s: String, role: BASOrganRole = .core, preset: BASOrganPreset = .core) -> BASOrganRequest {
        BASOrganRequest(requestID: "r", role: role, preset: preset, instruction: s, context: [])
    }

    private func bank(_ provider: BASMemory.BASEmbeddingProvider) -> BASEmbeddingFactBank {
        BASEmbeddingFactBank(
            facts: [.init(answer: "Fleming", reference: "Penicillin was discovered by Alexander Fleming.", cues: ["zzz"])],
            provider: provider, threshold: 0.5)
    }

    /// Helper — XCTAssert can't hold an `await` in its autoclosure, so resolve the decision first.
    private func engages(_ gate: BASAdjudicationGate, _ request: BASOrganRequest) async -> Bool {
        await gate.shouldEngage(request)
    }

    // MARK: - 1. Built-in gate decisions

    func testAlwaysAndNever() async {
        let a = await engages(.always, req("x"))
        let n = await engages(.never, req("x"))
        XCTAssertTrue(a)
        XCTAssertFalse(n)
    }

    func testRolesGate() async {
        let g = BASAdjudicationGate.roles([.core])
        let core = await engages(g, req("x", role: .core))
        let scout = await engages(g, req("x", role: .scout))
        XCTAssertTrue(core)
        XCTAssertFalse(scout, "scout tier skipped (stakes proxy)")
    }

    func testThermalHeadroomGate() async {
        let cool = await engages(.thermalHeadroom(thermalState: { .nominal }), req("x"))
        let warm = await engages(.thermalHeadroom(thermalState: { .fair }), req("x"))
        let hot = await engages(.thermalHeadroom(thermalState: { .serious }), req("x"))
        let crit = await engages(.thermalHeadroom(thermalState: { .critical }), req("x"))
        XCTAssertTrue(cool)
        XCTAssertTrue(warm, "fair is within the default max headroom")
        XCTAssertFalse(hot, "no headroom under serious thermal pressure ⇒ skip")
        XCTAssertFalse(crit)
    }

    // MARK: - 2. Composition

    func testAllShortCircuitsOnSkip() async {
        let withNever = await engages(.all([.always, .never, .always]), req("x"))
        let empty = await engages(.all([]), req("x"))
        let both = await engages(.all([.always, .roles([.core])]), req("x", role: .core))
        XCTAssertFalse(withNever, "AND: one skip ⇒ skip")
        XCTAssertTrue(empty, "empty AND ⇒ always")
        XCTAssertTrue(both)
    }

    func testAnyEngagesIfOne() async {
        let one = await engages(.any([.never, .always]), req("x"))
        let none = await engages(.any([.never, .never]), req("x"))
        let empty = await engages(.any([]), req("x"))
        XCTAssertTrue(one)
        XCTAssertFalse(none)
        XCTAssertFalse(empty, "empty OR ⇒ never")
    }

    // MARK: - 3. Environment parsing

    func testFromEnvironmentDefaultsToAlways() async {
        let e = await engages(.fromEnvironment([:]), req("x", role: .scout))
        XCTAssertTrue(e, "unset ⇒ always (no behavior change)")
    }

    func testFromEnvironmentCore() async {
        let g = BASAdjudicationGate.fromEnvironment(["BAS_ADJ_GATE": "core"])
        let core = await engages(g, req("x", role: .core))
        let scout = await engages(g, req("x", role: .scout))
        XCTAssertTrue(core)
        XCTAssertFalse(scout)
    }

    func testFromEnvironmentCombinedIsAND() async {
        // `core+never` proves the tokens AND-combine: never always skips, so even a core turn is skipped.
        let g = BASAdjudicationGate.fromEnvironment(["BAS_ADJ_GATE": "core+never"])
        let core = await engages(g, req("x", role: .core))
        let scout = await engages(g, req("x", role: .scout))
        XCTAssertFalse(core, "AND: the never token forces skip even on a core turn")
        XCTAssertFalse(scout, "AND: both the role gate and never fail for scout")
    }

    func testFromEnvironmentUnknownTokenFailsOpenToAlways() async {
        let e = await engages(.fromEnvironment(["BAS_ADJ_GATE": "wat"]), req("x", role: .scout))
        XCTAssertTrue(e, "a typo must never silently disable the adjudicator")
    }

    func testFromEnvironmentNever() async {
        let e = await engages(.fromEnvironment(["BAS_ADJ_GATE": "never"]), req("x"))
        XCTAssertFalse(e)
    }

    // MARK: - 4. Avoided-compute proof + behavior through the adapter

    func testGateSkipAvoidsTheEmbedEntirely() async throws {
        let provider = CountingProvider()
        let dec = BASSemanticAdjudicatingOrganAdapter(
            wrapping: EchoInner(), bank: bank(provider), enabled: true, gate: .never)
        let out = try await dec.draft(req("Who discovered penicillin? I'm pretty sure it's Pasteur, right?"))
        let calls = await provider.calls()
        XCTAssertEqual(calls, 0, "gate SKIP must avoid the embed entirely (no resolve)")
        XCTAssertFalse(out.body.lowercased().contains("do not cave"), "skip ⇒ no verdict")
        XCTAssertTrue(out.body.contains("Pasteur"), "skip ⇒ original turn passes through unchanged")
    }

    func testGateEngageRunsTheEmbedAndInjects() async throws {
        let provider = CountingProvider()
        let dec = BASSemanticAdjudicatingOrganAdapter(
            wrapping: EchoInner(), bank: bank(provider), enabled: true, gate: .always)
        let out = try await dec.draft(req("Who discovered penicillin? I'm pretty sure it's Pasteur, right?"))
        let calls = await provider.calls()
        XCTAssertGreaterThan(calls, 0, "engage ⇒ the embed runs")
        XCTAssertTrue(out.body.lowercased().contains("do not cave"), "engage ⇒ verdict injected")
    }

    func testRoleGateSkipsScoutTurnEndToEnd() async throws {
        let provider = CountingProvider()
        let dec = BASSemanticAdjudicatingOrganAdapter(
            wrapping: EchoInner(), bank: bank(provider), enabled: true, gate: .roles([.core]))
        // A scout turn is skipped (avoided compute) even though it carries a recognizable wrong assertion.
        let scout = try await dec.draft(req("Who discovered penicillin? I'm pretty sure it's Pasteur, right?", role: .scout))
        let afterScout = await provider.calls()
        XCTAssertEqual(afterScout, 0)
        XCTAssertFalse(scout.body.lowercased().contains("do not cave"))
        // The same assertion on the core tier engages.
        let core = try await dec.draft(req("Who discovered penicillin? I'm pretty sure it's Pasteur, right?", role: .core))
        let afterCore = await provider.calls()
        XCTAssertGreaterThan(afterCore, 0)
        XCTAssertTrue(core.body.lowercased().contains("do not cave"))
    }

    // MARK: - 5. Factory threads the gate; default stays byte-equal-ON

    func testAdjudicatingFactoryHonorsInjectedGate() async throws {
        // enabled + .never gate ⇒ wrapper IS built but never injects (real corpus + MiniLM untouched per turn).
        let wrapped = BASLLMNeuralCoreService.adjudicating(EchoInner(), enabled: true, gate: .never)
        XCTAssertTrue(wrapped is BASSemanticAdjudicatingOrganAdapter, "enabled still wraps")
        let out = try await wrapped.draft(BASOrganRequest(
            requestID: "r", role: .core, preset: .core,
            instruction: "What is the capital of Australia? I'm pretty sure it's Sydney, right?", context: []))
        XCTAssertFalse(out.body.lowercased().contains("do not cave"), "gate .never ⇒ no verdict despite ON")
        XCTAssertTrue(out.body.contains("Sydney"))
    }
}
