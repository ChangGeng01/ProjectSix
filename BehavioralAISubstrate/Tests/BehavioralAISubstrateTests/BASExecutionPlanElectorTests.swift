// MARK: - BASExecutionPlanElectorTests — execution-path orchestrator Phase 1 spine
//
// Pins the census's hard-won constraints as executable, reversible rules: resident admission,
// spec-vs-RotatingKVCache, verified-only cache defaults, thermal net-negative, purpose election,
// and the deterministic fallback floor. Pure logic — runs under bare `swift test`.

import XCTest
@testable import BASOrgan

final class BASExecutionPlanElectorTests: XCTestCase {

    private let air = BASDeviceExecutionProfile.iPhoneAirA19
    private let qwen = BASModelManifestRegistry.qwen35_4B_4bit

    private func state(
        temp: Double = 0, throttled: Bool = false, headroom: Int? = nil
    ) -> BASExecutionPlanElector.RuntimeState {
        .init(temperature: temp, thermallyThrottled: throttled, memoryHeadroomBytes: headroom)
    }

    // MARK: manifest + profile facts

    func testQwen35ManifestIsGDNWithMTPHead() {
        XCTAssertEqual(qwen.architecture, .gdnHybrid)
        XCTAssertTrue(qwen.carriesMTPHead, "the typed replacement for id.contains(\"qwen3.5\")")
        XCTAssertTrue(qwen.requiresSnapshotRollback, "GDN ⇒ P1-b carry-forward, not KV-trim")
        XCTAssertEqual(BASModelManifestRegistry.productionDefault.modelID, qwen.modelID,
            "the chartered production default is Qwen3.5-4B")
    }

    func testAirProfileAdmitsQwen35UnderJetsam() {
        XCTAssertTrue(air.admitsResident(bytes: qwen.peakBytesEstimate),
            "3.1 GB peak fits under the 6.29 GB jetsam cap with headroom")
        // A 9B-class ~8.2 GB dual-residency must be refused (M5 deferral evidence).
        XCTAssertFalse(air.admitsResident(bytes: 8_200 * 1_048_576),
            "a footprint over the jetsam budget must be refused")
    }

    // MARK: draft-sibling dual-residency (why Gemma-E4B does NOT reach ~50 on the Air)

    func testGemmaE4BDraftSpeculationRefusedByJetsamOnAir() {
        let e4b = BASModelManifestRegistry.gemma4_E4B_4bit
        XCTAssertEqual(e4b.draftSiblingID, "mlx-community/gemma-4-e2b-it-4bit",
            "E4B's draft sibling is the nested MatFormer E2B (manifest correctness fix)")
        // E4B alone admits...
        XCTAssertTrue(air.admitsResident(bytes: e4b.peakBytesEstimate),
            "E4B alone (4314 MB) fits under the cap")
        // ...but E4B + E2B co-resident does NOT (4314 + 3114 = 7428 > 6290).
        let e2b = BASModelManifestRegistry.gemma4_E2B_4bit
        XCTAssertFalse(
            air.admitsResident(bytes: e4b.peakBytesEstimate + e2b.peakBytesEstimate),
            "the dual-residency draft plan must be refused — the memory reason E4B stays single-model")
        let plan = BASExecutionPlanElector.elect(
            modelID: e4b.modelID, manifest: e4b, device: air, state: state(temp: 0))
        XCTAssertFalse(plan.attestation.draftSpeculationViable,
            "the elector must attest the draft-spec lane is NOT viable on the Air (why not ~50)")
    }

    func testLlama3BDraftSpeculationViableUnderJetsam() {
        // Llama-3.2-3B (2542) + 1B draft (~800) DOES co-reside under the cap → draft plan viable.
        let llama = BASModelManifestRegistry.llama32_3B_4bit
        let plan = BASExecutionPlanElector.elect(
            modelID: llama.modelID, manifest: llama, device: air, state: state(temp: 0))
        XCTAssertTrue(plan.attestation.draftSpeculationViable,
            "Llama-3B + 1B draft co-reside under the cap ⇒ draft-spec lane is memory-viable")
    }

    // MARK: election rules

    func testGreedyAdmittedNominalElectsSpeculativeDeterministic() {
        let plan = BASExecutionPlanElector.elect(
            modelID: qwen.modelID, manifest: qwen, device: air, state: state(temp: 0))
        XCTAssertEqual(plan.decodePurpose, .deterministic,
            "greedy + admitted + nominal ⇒ speculative lanes eligible")
        XCTAssertTrue(plan.attestation.specCachePreserved)
        XCTAssertNil(plan.cache.maxKVSize,
            "spec wanted ⇒ maxKVSize MUST be nil (RotatingKVCache fail-closes every spec lane)")
        XCTAssertNil(plan.cache.kvBits, "fp16 is the only verified KV default")
        XCTAssertEqual(plan.fallbackChain.count, 2, "primary + plain-leaning thermal fallback")
        XCTAssertEqual(plan.fallbackChain.last?.decodePurpose, .scoutDefault,
            "the floor rung is always the byte-equal default")
    }

    func testSamplingRequestStaysByteEqualDefault() {
        let plan = BASExecutionPlanElector.elect(
            modelID: qwen.modelID, manifest: qwen, device: air, state: state(temp: 0.7))
        XCTAssertEqual(plan.decodePurpose, .scoutDefault,
            "a sampling request must not unlock argmax-accept speculative lanes")
        XCTAssertFalse(plan.attestation.specCachePreserved)
    }

    func testThrottledDeviceDropsToPlainEvenGreedy() {
        let plan = BASExecutionPlanElector.elect(
            modelID: qwen.modelID, manifest: qwen, device: air, state: state(temp: 0, throttled: true))
        XCTAssertEqual(plan.decodePurpose, .scoutDefault,
            "serious+ thermal ⇒ plain (MTP measured 0.52–0.62× net-negative under throttle)")
        XCTAssertEqual(plan.fallbackChain.count, 1)
    }

    func testUnmanifestedModelStaysConservative() {
        let plan = BASExecutionPlanElector.elect(
            modelID: "unknown/mystery-7b", manifest: nil, device: air, state: state(temp: 0))
        XCTAssertEqual(plan.decodePurpose, .scoutDefault,
            "an unmanifested model must not fail open into speculation")
        XCTAssertFalse(plan.load.residentAdmitted)
        XCTAssertTrue(plan.fallbackChain.first?.reason.contains("unadmitted/unmanifested") ?? false)
    }

    func testUnadmittedFootprintRefusesSpeculation() {
        // A model too big for the jetsam budget: manifest present but not admitted.
        let big = BASModelCapabilityManifest(
            modelID: "big/9b-4bit", architecture: .trimmableAttention, draft: .none,
            quantBits: 4, peakBytesEstimate: 8_200 * 1_048_576, contextCapTokens: 131_072)
        let plan = BASExecutionPlanElector.elect(
            modelID: big.modelID, manifest: big, device: air, state: state(temp: 0))
        XCTAssertFalse(plan.load.residentAdmitted)
        XCTAssertEqual(plan.decodePurpose, .scoutDefault,
            "over-budget resident ⇒ no speculation election (memory fail-closed)")
    }

    func testEnergyHonestlyUnmodeled() {
        let plan = BASExecutionPlanElector.elect(
            modelID: qwen.modelID, manifest: qwen, device: air, state: state(temp: 0))
        XCTAssertFalse(plan.attestation.energyModeled,
            "the plan must not claim an energy axis it has no runtime data for")
    }

    // MARK: manifest registry contract (the live MTP-head consumer relies on this)

    func testRegistryResolvesDefaultAndRejectsUnknown() {
        XCTAssertEqual(
            BASModelManifestRegistry.manifest(forModelID: "mlx-community/Qwen3.5-4B-4bit")?.carriesMTPHead,
            true, "the wired MTP-head consumer trusts this exact-id lookup")
        XCTAssertNil(BASModelManifestRegistry.manifest(forModelID: "unknown/x"),
            "an unknown model resolves to nil ⇒ the consumer falls back to the legacy probe")
        // Llama/Gemma are manifested but carry NO folded head — the consumer must not offer it.
        XCTAssertEqual(BASModelManifestRegistry.llama32_3B_4bit.carriesMTPHead, false)
        XCTAssertEqual(BASModelManifestRegistry.gemma4_E4B_4bit.carriesMTPHead, false)
    }

    func testElectionIsDeterministic() {
        let a = BASExecutionPlanElector.elect(
            modelID: qwen.modelID, manifest: qwen, device: air, state: state(temp: 0))
        let b = BASExecutionPlanElector.elect(
            modelID: qwen.modelID, manifest: qwen, device: air, state: state(temp: 0))
        XCTAssertEqual(a, b, "the elector is a pure function — same inputs, same plan")
    }
}
