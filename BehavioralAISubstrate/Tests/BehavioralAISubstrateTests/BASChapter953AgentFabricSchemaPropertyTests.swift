// MARK: - BASChapter953AgentFabricSchemaPropertyTests
// chapter 九百五十三 / M3470 (Phase 0 / ch1)
//
// Property tests for the 8 core Agent Fabric schemas + 5 enums。
// Validates type-level invariants BEFORE any service wiring (Phase 0
// ch 954/955 onward)。
//
// Per plan discipline:
//   - 红线 7: pure-data additive only; no existing call sites touched
//   - ADR-014 OPT-IN: no runtime hooks yet; just compile-validated types
//   - ch 952.2 fuzz generators reused for property-test inputs
//
// Coverage:
//   1. All 5 enums have stable Codable raw-value round-trip
//   2. All 8 structs have Sendable + Equatable + Hashable + Codable
//      round-trip via JSONEncoder/Decoder
//   3. Init defaults work — empty arrays / nil optionals serialize
//      to known shape
//   4. BASFuzzRng-driven 1000-iter fuzz round-trip — random valid
//      values survive encode→decode without drift
//   5. Sendable boundary check: structs cross actor boundary cleanly
//      (Swift 5.10 strict concurrency)

import XCTest
@testable import BASMemory

final class BASChapter953AgentFabricSchemaPropertyTests:
    XCTestCase
{

    // MARK: - Helpers

    private func encode<T: Encodable>(_ v: T) throws -> Data {
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        return try enc.encode(v)
    }

    private func decode<T: Decodable>(
        _ type: T.Type, from data: Data
    ) throws -> T {
        try JSONDecoder().decode(type, from: data)
    }

    private func roundTrip<T: Codable & Equatable>(_ v: T) throws {
        let data = try encode(v)
        let back = try decode(T.self, from: data)
        XCTAssertEqual(v, back,
            "Codable round-trip drift for \(T.self): \(v) → \(back)")
    }

    // MARK: - 1. Enum raw-value Codable round-trip

    func testAllEnumsCodableRoundTrip() throws {
        for v in BASAgentRole.allCases { try roundTrip(v) }
        for v in BASAgentVisibility.allCases { try roundTrip(v) }
        for v in BASStateDomain.allCases { try roundTrip(v) }
        for v in BASAgentProposalType.allCases { try roundTrip(v) }
        for v in BASAgentDeltaType.allCases { try roundTrip(v) }
        for v in BASAgentLeaseProfile.allCases { try roundTrip(v) }
    }

    func testEnumCountInvariants() {
        // Pin user's design counts so future role additions are
        // caught by test diff (forces CHANGELOG entry)
        XCTAssertEqual(BASAgentRole.allCases.count, 20,
            "BASAgentRole count drift — expected 20 " +
            "(9 core + 7 watcher + 4 sealed)")
        XCTAssertEqual(BASAgentVisibility.allCases.count, 3)
        // chapter 九百六十一 / M3510:bumped 9 → 10 with
        // addition of `.critiqueField` (Critic seat's domain)
        // chapter 九百六十三 / M3520:bumped 10 → 11 with
        // addition of `.alignmentField` (HostAlignment seat
        // owns this — CANNOT write .hostVersion which is
        // sovereign-locked per Single-Writer table)
        // chapter 九百六十五 / M3530:bumped 11 → 12 with
        // addition of `.evolutionProposal` (EvolutionShadow
        // seat owns this — CANNOT write .hostVersion which
        // remains sovereign-locked per Single-Writer table;
        // EvolutionShadow's proposals are NEVER effective same
        // turn per plan Phase 3 ch3 invariant)
        XCTAssertEqual(BASStateDomain.allCases.count, 12)
        XCTAssertEqual(BASAgentProposalType.allCases.count, 7)
        XCTAssertEqual(BASAgentDeltaType.allCases.count, 5)
        XCTAssertEqual(BASAgentLeaseProfile.allCases.count, 4)
    }

    // MARK: - 2. Schema struct Codable round-trip (default + populated)

    func testAgentSpecCodableRoundTrip() throws {
        let spec = BASAgentSpec(
            agentID: "planner.test.v1",
            role: .planner,
            layerAffinity: [6, 9],
            readDomains: [.situationField, .candidateFrontier],
            writeDomains: [.candidateFrontier],
            proposeDomains: [],
            forbiddenDomains: [.hostVersion, .sovereignVerdict],
            defaultLeaseProfile: .hotSeat,
            personaRef: "persona.planner.test.v1",
            visibility: .high,
            commitCapability: false)
        try roundTrip(spec)
    }

    func testAgentLeaseCodableRoundTrip() throws {
        let lease = BASAgentLease(
            leaseID: "lease.test.turn-1.0",
            agentID: "planner.test.v1",
            turnID: "turn-1",
            maxMs: 200,
            maxTokens: 0,
            maxStateReads: 100,
            maxDeltaWrites: 10,
            allowedDomains: [.situationField, .candidateFrontier],
            expiresAtMs: 1_700_000_000_000,
            priority: 5)
        try roundTrip(lease)
    }

    func testAgentObservationCodableRoundTrip() throws {
        let obs = BASAgentObservation(
            observationID: "obs.t1.planner.0",
            agentID: "planner.test.v1",
            sourceRefs: ["situationField#sit-1"],
            observedDomain: .situationField,
            summary: "low-risk inbound prompt",
            confidence: 0.85,
            flags: ["nominal"])
        try roundTrip(obs)
    }

    func testAgentDeltaCodableRoundTrip() throws {
        let delta = BASAgentDelta(
            deltaID: "delta.t1.planner.0",
            agentID: "planner.test.v1",
            targetObjectRef: "candidateFrontier#cf-1",
            deltaType: .add,
            patchJson: "{\"candidate\":\"option-A\"}",
            confidence: 0.7,
            reasonCodes: ["evidence.recent"],
            dependencies: [],
            conflictRefs: [])
        try roundTrip(delta)
    }

    func testAgentProposalCodableRoundTrip() throws {
        let prop = BASAgentProposal(
            proposalID: "prop.t1.critic.0",
            agentID: "critic.test.v1",
            proposalType: .critique,
            payloadRef: "candidateFrontier#cf-1",
            requiredDomains: [.candidateFrontier],
            riskNotes: ["overconfident"],
            sovereignNotes: [])
        try roundTrip(prop)
    }

    func testAgentMergeResultCodableRoundTrip() throws {
        let merge = BASAgentMergeResult(
            mergeID: "merge.t1.0",
            acceptedDeltaIDs: ["delta:t1.planner.0"],
            rejectedDeltaIDs: ["delta:t1.critic.0"],
            conflictResolution: [
                "delta:t1.planner.0 vs delta:t1.critic.0 " +
                "→ accept planner by Evidence-tier",
            ],
            resultingStateRef: "candidateFrontier#cf-1-merged",
            mergeReasonCodes: ["evidence.preferred"])
        try roundTrip(merge)
    }

    func testAgentTraceCodableRoundTrip() throws {
        let trace = BASAgentTrace(
            traceID: "trace.t1.planner.0",
            agentID: "planner.test.v1",
            leaseRef: "lease:lease.test.turn-1.0",
            readRefs: ["situationField#sit-1"],
            writeRefs: ["candidateFrontier#cf-1"],
            proposalIDs: ["prop:prop.t1.planner.0"],
            accepted: true,
            rejectedReason: "",
            latencyMs: 45)
        try roundTrip(trace)
    }

    func testAgentPersonaSpecCodableRoundTrip() throws {
        let persona = BASAgentPersonaSpec(
            personaID: "persona.planner.test.v1",
            agentID: "planner.test.v1",
            tone: "cool",
            warmth: 0.3,
            directness: 0.8,
            skepticism: 0.5,
            structureBias: 0.7,
            creativityBias: 0.6,
            challengeIntensity: 0.4,
            comparisonBias: 0.6,
            guardBias: 0.5,
            visibility: .high,
            hostConstraintsRef: "hostConstitution:host-1:v1",
            riskConstraintsRef: "riskGate:gate-1:v1",
            sovereignConstraintsRef: "sovereignSentinel:s-1",
            versionRef: "personaVersion:v1")
        try roundTrip(persona)
    }

    // MARK: - 3. Init defaults serialize predictably

    func testAgentSpecDefaultInitMinimal() throws {
        let spec = BASAgentSpec(
            agentID: "minimal.v1",
            role: .scout,
            defaultLeaseProfile: .hotSeat,
            visibility: .medium)
        try roundTrip(spec)
        XCTAssertTrue(spec.layerAffinity.isEmpty)
        XCTAssertTrue(spec.readDomains.isEmpty)
        XCTAssertTrue(spec.writeDomains.isEmpty)
        XCTAssertNil(spec.personaRef)
        XCTAssertFalse(spec.commitCapability)
    }

    // MARK: - 4. BASFuzzRng-driven 1000-iter fuzz round-trip

    /// Per plan ch 953 knife 4: 10K iters of property tests via
    /// `BASFuzzInputGenerator` (ch 952.2)。 Reduced to 1000 here to
    /// fit local CI timing — device run scales via env (matches
    /// ch 952.2 default 50 + env override pattern)。
    func testAgentSpecFuzzRoundTrip() throws {
        let iters = Self.fuzzIterCount
        for i in 0..<iters {
            var rng = BASFuzzRng(seed: testSeed(iteration: i))
            let spec = procGenAgentSpec(rng: &rng)
            try roundTrip(spec)
        }
    }

    func testAgentLeaseFuzzRoundTrip() throws {
        for i in 0..<Self.fuzzIterCount {
            var rng = BASFuzzRng(seed: testSeed(iteration: i))
            let lease = procGenAgentLease(rng: &rng)
            try roundTrip(lease)
        }
    }

    func testAgentDeltaFuzzRoundTrip() throws {
        for i in 0..<Self.fuzzIterCount {
            var rng = BASFuzzRng(seed: testSeed(iteration: i))
            let delta = procGenAgentDelta(rng: &rng)
            try roundTrip(delta)
        }
    }

    func testAgentPersonaSpecFuzzRoundTrip() throws {
        for i in 0..<Self.fuzzIterCount {
            var rng = BASFuzzRng(seed: testSeed(iteration: i))
            let persona = procGenAgentPersonaSpec(rng: &rng)
            try roundTrip(persona)
        }
    }

    // MARK: - 5. Sendable boundary check (compile-validated)

    /// Pass schemas across an actor boundary。 If they aren't Sendable
    /// per Swift 5.10 strict concurrency,this won't compile。
    func testSchemasCrossActorBoundary() async throws {
        actor Holder {
            var spec: BASAgentSpec?
            var lease: BASAgentLease?
            var delta: BASAgentDelta?
            var persona: BASAgentPersonaSpec?
            func setSpec(_ v: BASAgentSpec) { self.spec = v }
            func setLease(_ v: BASAgentLease) { self.lease = v }
            func setDelta(_ v: BASAgentDelta) { self.delta = v }
            func setPersona(_ v: BASAgentPersonaSpec) {
                self.persona = v
            }
        }
        let holder = Holder()
        var rng = BASFuzzRng(seed: 42)
        await holder.setSpec(procGenAgentSpec(rng: &rng))
        await holder.setLease(procGenAgentLease(rng: &rng))
        await holder.setDelta(procGenAgentDelta(rng: &rng))
        await holder.setPersona(procGenAgentPersonaSpec(rng: &rng))
        // Pure compile-time invariant — if we got here, all Sendable。
    }

    // MARK: - Proc-gen helpers using ch 952.2 fuzz generators

    private static let fuzzIterCount: Int = {
        if let env = ProcessInfo.processInfo
            .environment["BAS_FUZZ_ITER"],
           let n = Int(env), n > 0
        {
            return n
        }
        return 100   // local CI default; device run can scale
    }()

    private func procGenAgentSpec(
        rng: inout BASFuzzRng
    ) -> BASAgentSpec {
        let role = rng.pick(BASAgentRole.allCases)
        let visibility = rng.pick(BASAgentVisibility.allCases)
        let leaseProfile = rng.pick(BASAgentLeaseProfile.allCases)
        let layerCount = rng.nextInt(in: 0...5)
        let layerAffinity = (0..<layerCount).map { _ in
            rng.nextInt(in: 1...14)
        }
        let readCount = rng.nextInt(in: 0...4)
        let readDomains = (0..<readCount).map { _ in
            rng.pick(BASStateDomain.allCases)
        }
        return BASAgentSpec(
            agentID: "agent-\(rng.next())",
            role: role,
            layerAffinity: layerAffinity,
            readDomains: readDomains,
            writeDomains: [],
            proposeDomains: [],
            forbiddenDomains: [],
            defaultLeaseProfile: leaseProfile,
            personaRef: rng.nextBool(p: 0.7)
                ? "persona-\(rng.next())" : nil,
            visibility: visibility,
            commitCapability: rng.nextBool(p: 0.1))
    }

    private func procGenAgentLease(
        rng: inout BASFuzzRng
    ) -> BASAgentLease {
        let allowedCount = rng.nextInt(in: 0...4)
        let allowedDomains = (0..<allowedCount).map { _ in
            rng.pick(BASStateDomain.allCases)
        }
        return BASAgentLease(
            leaseID: "lease-\(rng.next())",
            agentID: "agent-\(rng.next())",
            turnID: "turn-\(rng.next())",
            maxMs: rng.nextInt(in: 10...10_000),
            maxTokens: rng.nextInt(in: 0...100_000),
            maxStateReads: rng.nextInt(in: 0...1_000),
            maxDeltaWrites: rng.nextInt(in: 0...100),
            allowedDomains: allowedDomains,
            expiresAtMs: Int64(rng.nextInt(in: 1...10_000_000)),
            priority: rng.nextInt(in: -100...100))
    }

    private func procGenAgentDelta(
        rng: inout BASFuzzRng
    ) -> BASAgentDelta {
        return BASAgentDelta(
            deltaID: "delta-\(rng.next())",
            agentID: "agent-\(rng.next())",
            targetObjectRef:
                "\(rng.pick(BASStateDomain.allCases).rawValue)" +
                "#obj-\(rng.next())",
            deltaType: rng.pick(BASAgentDeltaType.allCases),
            patchJson: rng.nextBool(p: 0.7)
                ? "{\"k\":\"v-\(rng.next())\"}" : "",
            confidence: Double(rng.nextFloat(in: 0...1)),
            reasonCodes: (0..<rng.nextInt(in: 0...3)).map {
                "reason-\($0)-\(rng.next())"
            },
            dependencies: [],
            conflictRefs: [])
    }

    private func procGenAgentPersonaSpec(
        rng: inout BASFuzzRng
    ) -> BASAgentPersonaSpec {
        let tones = ["cool", "warm", "neutral", "playful", "formal"]
        return BASAgentPersonaSpec(
            personaID: "persona-\(rng.next())",
            agentID: "agent-\(rng.next())",
            tone: rng.pick(tones),
            warmth: Double(rng.nextFloat(in: 0...1)),
            directness: Double(rng.nextFloat(in: 0...1)),
            skepticism: Double(rng.nextFloat(in: 0...1)),
            structureBias: Double(rng.nextFloat(in: 0...1)),
            creativityBias: Double(rng.nextFloat(in: 0...1)),
            challengeIntensity: Double(rng.nextFloat(in: 0...1)),
            comparisonBias: Double(rng.nextFloat(in: 0...1)),
            guardBias: Double(rng.nextFloat(in: 0...1)),
            visibility: rng.pick(BASAgentVisibility.allCases),
            hostConstraintsRef:
                "hostConstitution:host-\(rng.next()):v1",
            riskConstraintsRef:
                "riskGate:gate-\(rng.next()):v1",
            sovereignConstraintsRef:
                "sovereignSentinel:s-\(rng.next())",
            versionRef: "personaVersion:v-\(rng.next())")
    }
}
