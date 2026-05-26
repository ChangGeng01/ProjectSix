// MARK: - BASChapter973SkillAgentTests
// chapter 九百七十三 / M3570 — Phase 6 ch1 tests:Skill agents
//
// Test scope:
//   1. BASSkillCapability pin (4 cases)
//   2. BASSkillAgentRegistry pin (4 agents, count, lookup)
//   3. BASSkillAgentDescriptor: domain lists auto-sorted in init
//   4. BASSkillAgentDescriptor: Codable round-trip preserves fields
//   5. Reference writing agent: shape + visibility + permits
//   6. Reference code agent: shape + critique read access
//   7. Reference research agent: shape + situation read access
//   8. Reference scheduling agent: MED visibility (delete is risky)
//   9. BASSkillAgentInvoker.invoke: clean writing invocation → success
//  10. BASSkillAgentInvoker.invoke: forbidden persona → fail clean
//  11. BASSkillAgentInvoker.invoke: empty agentID → fail with code
//  12. BASSkillAgentInvoker.invoke: empty turnID → fail with code
//  13. buildAgentSpec: writeDomains MUST be empty (read-only invariant)
//  14. buildAgentSpec: forbiddenDomains includes sovereign-adjacent
//  15. CRITICAL: skill agent cannot write .hostVersion (sovereign-locked)
//  16. CRITICAL: skill agent cannot write .sovereignVerdict
//  17. Persona resolution via Phase 4 SDK: roles routed correctly
//  18. Sovereign lockdown invocation: persona force-defaulted
//  19. Risk floor invocation: persona skepticism raised

import XCTest
@testable import BASMemory

final class BASChapter973SkillAgentTests: XCTestCase {

    // MARK: - 1. Capability enum pin

    func testSkillCapabilityCountIs4() {
        XCTAssertEqual(
            BASSkillCapability.allCases.count, 4,
            "ch 973: exactly 4 reference capabilities " +
            "(writing / code / research / scheduling)")
    }

    func testSkillCapabilityCodableRoundTrip() throws {
        for cap in BASSkillCapability.allCases {
            let data = try JSONEncoder().encode(cap)
            let back = try JSONDecoder().decode(
                BASSkillCapability.self, from: data)
            XCTAssertEqual(cap, back)
        }
    }

    // MARK: - 2. Registry pin

    func testRegistryAgentCountIs4() {
        XCTAssertEqual(
            BASSkillAgentRegistry.all.count, 4)
        XCTAssertEqual(
            BASSkillAgentRegistry.expectedAgentCount, 4)
    }

    func testRegistryLookupByCapability() {
        XCTAssertEqual(
            BASSkillAgentRegistry.referenceFor(
                capability: .writing)?.agentID,
            "skill.writing.reference.v1")
        XCTAssertEqual(
            BASSkillAgentRegistry.referenceFor(
                capability: .code)?.agentID,
            "skill.code.reference.v1")
        XCTAssertEqual(
            BASSkillAgentRegistry.referenceFor(
                capability: .research)?.agentID,
            "skill.research.reference.v1")
        XCTAssertEqual(
            BASSkillAgentRegistry.referenceFor(
                capability: .scheduling)?.agentID,
            "skill.scheduling.reference.v1")
    }

    // MARK: - 3. Descriptor init sorts domains

    func testDescriptorAutoSortsDomains() {
        let d = BASSkillAgentDescriptor(
            agentID: "a1",
            capability: .writing,
            allowedPermitDomains: ["z", "a", "m"],
            allowedReadDomains: [
                .renderFrame, .candidateFrontier,
                .memoryBundle],
            allowedToolDomains: ["zz", "aa"])
        XCTAssertEqual(
            d.allowedPermitDomains, ["a", "m", "z"],
            "ch 973: permit domains MUST be auto-sorted")
        XCTAssertEqual(
            d.allowedToolDomains, ["aa", "zz"])
        // Read domains sorted by rawValue
        let expectedRaw = ["candidateFrontier",
                            "memoryBundle", "renderFrame"]
        let actualRaw = d.allowedReadDomains.map {
            $0.rawValue
        }
        XCTAssertEqual(actualRaw, expectedRaw)
    }

    // MARK: - 4. Descriptor Codable round-trip

    func testDescriptorCodableRoundTrip() throws {
        let d = BASSkillAgentDescriptor(
            agentID: "skill.test.v1",
            capability: .code,
            allowedPermitDomains: ["code-write"],
            allowedReadDomains: [.candidateFrontier],
            allowedToolDomains: ["mcp.fs"],
            personaRef: "persona.skill.v1",
            visibility: .high,
            sdkVersion: "v2")
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        let data = try enc.encode(d)
        let back = try JSONDecoder().decode(
            BASSkillAgentDescriptor.self, from: data)
        XCTAssertEqual(d, back)
    }

    // MARK: - 5-8. Reference agent shapes

    func testWritingAgentShape() {
        let a = BASSkillAgentRegistry.writing
        XCTAssertEqual(a.capability, .writing)
        XCTAssertEqual(a.visibility, .high)
        XCTAssertTrue(a.allowedPermitDomains.contains(
            "draft-compose"))
        XCTAssertTrue(a.allowedReadDomains.contains(
            .candidateFrontier))
        XCTAssertTrue(a.allowedReadDomains.contains(
            .memoryBundle))
    }

    func testCodeAgentReadsCritique() {
        // Code agent SHOULD read .critiqueField (for review work)
        let a = BASSkillAgentRegistry.code
        XCTAssertTrue(a.allowedReadDomains.contains(
            .critiqueField),
            "ch 973: code skill agent MUST be able to read " +
            ".critiqueField for review/debugging work")
    }

    func testResearchAgentReadsSituationField() {
        let a = BASSkillAgentRegistry.research
        XCTAssertTrue(a.allowedReadDomains.contains(
            .situationField),
            "ch 973: research skill agent MUST be able to read " +
            ".situationField for context awareness")
    }

    func testSchedulingAgentMedVisibility() {
        // Scheduling = delete-risky → MED visibility (limited
        // persona customization)
        let a = BASSkillAgentRegistry.scheduling
        XCTAssertEqual(a.visibility, .medium,
            "ch 973: scheduling skill agent MUST be MED " +
            "visibility (delete is risky enough to limit " +
            "persona customization)")
        XCTAssertTrue(a.allowedPermitDomains.contains(
            "schedule-delete"))
    }

    // MARK: - 9. Invocation: clean writing → success

    func testInvocation_CleanWriting() {
        let invocation = BASSkillAgentInvocation(
            descriptor: BASSkillAgentRegistry.writing,
            turnID: "t1",
            personaID: "p.writing.1")
        let result = BASSkillAgentInvoker.invoke(invocation)
        XCTAssertTrue(result.success)
        XCTAssertNotNil(result.persona)
        XCTAssertNotNil(result.agentSpec)
        XCTAssertNil(result.error)
        XCTAssertEqual(
            result.agentSpec?.agentID,
            "skill.writing.reference.v1")
    }

    // MARK: - 10. Forbidden persona → fail

    func testInvocation_ForbiddenUserOverlayRejected() {
        let forbiddenUser = BASAgentPersonaSpec(
            personaID: "user-shame",
            agentID: "x",
            tone: "cool",
            warmth: 0.10,
            directness: 0.50,
            skepticism: 0.50,
            structureBias: 0.50,
            creativityBias: 0.50,
            challengeIntensity: 0.85,
            comparisonBias: 0.50,
            guardBias: 0.10,
            visibility: .high,
            hostConstraintsRef: "",
            riskConstraintsRef: "",
            sovereignConstraintsRef: "",
            versionRef: "")
        let invocation = BASSkillAgentInvocation(
            descriptor: BASSkillAgentRegistry.writing,
            turnID: "t1",
            userOverlay: forbiddenUser,
            personaID: "p")
        let result = BASSkillAgentInvoker.invoke(invocation)
        XCTAssertFalse(result.success,
            "ch 973: forbidden user overlay → invocation MUST fail")
        XCTAssertNil(result.persona)
        XCTAssertEqual(result.error,
            "invocation.persona-rejected")
        XCTAssertNotNil(result.personaResult,
            "ch 973: personaResult MUST be carried back for " +
            "audit ledger even on failure")
    }

    // MARK: - 11-12. Invalid envelopes

    func testInvocation_EmptyAgentIDFails() {
        let bad = BASSkillAgentDescriptor(
            agentID: "",
            capability: .writing)
        let invocation = BASSkillAgentInvocation(
            descriptor: bad,
            turnID: "t1",
            personaID: "p")
        let result = BASSkillAgentInvoker.invoke(invocation)
        XCTAssertFalse(result.success)
        XCTAssertEqual(result.error,
            "invocation.invalid-descriptor:empty-agent-id")
    }

    func testInvocation_EmptyTurnIDFails() {
        let invocation = BASSkillAgentInvocation(
            descriptor: BASSkillAgentRegistry.writing,
            turnID: "",
            personaID: "p")
        let result = BASSkillAgentInvoker.invoke(invocation)
        XCTAssertFalse(result.success)
        XCTAssertEqual(result.error,
            "invocation.invalid-envelope:empty-turn-id")
    }

    // MARK: - 13-14. AgentSpec build invariants

    func testBuildAgentSpec_WriteDomainsAlwaysEmpty() {
        for a in BASSkillAgentRegistry.all {
            let spec = BASSkillAgentInvoker
                .buildAgentSpec(from: a)
            XCTAssertTrue(spec.writeDomains.isEmpty,
                "ch 973 CRITICAL: skill agent writeDomains " +
                "MUST be empty for \(a.agentID) (skill " +
                "agents never own a domain per " +
                "Single-Writer-Per-Domain invariant)")
        }
    }

    func testBuildAgentSpec_ForbiddenIncludesSovereignAdjacent() {
        let spec = BASSkillAgentInvoker.buildAgentSpec(
            from: BASSkillAgentRegistry.writing)
        // All sovereign-adjacent domains forbidden
        for d in [BASStateDomain.hostVersion,
                   .sovereignVerdict,
                   .actionPermit,
                   .evolutionProposal]
        {
            XCTAssertTrue(spec.forbiddenDomains.contains(d),
                "ch 973 CRITICAL: skill agent MUST forbid " +
                "\(d) (Root Law 4 sovereign-locked)")
        }
    }

    // MARK: - 15-16. CRITICAL sovereign-lock invariants

    func testCRITICAL_SkillAgentCannotWriteHostVersion() async {
        let spec = BASSkillAgentInvoker.buildAgentSpec(
            from: BASSkillAgentRegistry.writing)
        let graph = BASSharedStateGraph()
        do {
            _ = try await graph.writeObject(
                domain: .hostVersion,
                objectID: "hv-skill-attempt",
                payloadJson: "{}",
                byAgent: spec)
            XCTFail("ch 973 CRITICAL: skill agent MUST NOT " +
                "write .hostVersion (sovereign-locked)")
        } catch is BASSharedStateGraphError {
            // expected — forbiddenDomain or unauthorizedWriter
        } catch {
            XCTFail("unexpected: \(error)")
        }
    }

    func testCRITICAL_SkillAgentCannotWriteSovereignVerdict() async {
        let spec = BASSkillAgentInvoker.buildAgentSpec(
            from: BASSkillAgentRegistry.code)
        let graph = BASSharedStateGraph()
        do {
            _ = try await graph.writeObject(
                domain: .sovereignVerdict,
                objectID: "sv-skill-attempt",
                payloadJson: "{}",
                byAgent: spec)
            XCTFail("ch 973 CRITICAL: skill agent MUST NOT " +
                "write .sovereignVerdict")
        } catch is BASSharedStateGraphError {
            // expected
        } catch {
            XCTFail("unexpected: \(error)")
        }
    }

    func testCRITICAL_SkillAgentCannotWriteEvolutionProposal() async {
        let spec = BASSkillAgentInvoker.buildAgentSpec(
            from: BASSkillAgentRegistry.research)
        let graph = BASSharedStateGraph()
        do {
            _ = try await graph.writeObject(
                domain: .evolutionProposal,
                objectID: "ep-skill-attempt",
                payloadJson: "{}",
                byAgent: spec)
            XCTFail("ch 973 CRITICAL: skill agent MUST NOT " +
                "write .evolutionProposal (EvolutionShadow " +
                "owns this exclusively per ch 965)")
        } catch is BASSharedStateGraphError {
            // expected
        } catch {
            XCTFail("unexpected: \(error)")
        }
    }

    // MARK: - 17. Persona routing

    func testInvocation_PersonaResolvesViaPhase4SDK() {
        // No user overlay → persona equals .compareModerator
        // role template default (which falls through to MED
        // fallback in BASAgentPersonaRoleTemplates per ch 966)
        let invocation = BASSkillAgentInvocation(
            descriptor: BASSkillAgentRegistry.writing,
            turnID: "t1",
            personaID: "p.writing.1")
        let result = BASSkillAgentInvoker.invoke(invocation)
        XCTAssertTrue(result.success)
        // Verify persona was resolved (not just nil-passed)
        XCTAssertNotNil(result.persona)
        XCTAssertEqual(
            result.persona?.personaID, "p.writing.1")
        // PersonaResult outcomes carry through
        XCTAssertNotNil(result.personaResult)
        XCTAssertFalse(
            result.personaResult?.rejected ?? true)
    }

    // MARK: - 18. Sovereign lockdown integration

    func testInvocation_SovereignLockdownAppliesToSkill() {
        let invocation = BASSkillAgentInvocation(
            descriptor: BASSkillAgentRegistry.writing,
            turnID: "t1",
            sovereign:
                BASAgentPersonaSovereignContext(
                    lockdownTurn: true),
            personaID: "p")
        let result = BASSkillAgentInvoker.invoke(invocation)
        XCTAssertTrue(result.success,
            "ch 973: lockdown does NOT reject — it force-" +
            "defaults the persona")
        XCTAssertNotNil(result.personaResult)
        XCTAssertTrue(
            result.personaResult?
                .sovereignClampOutcome.lockdownApplied
                ?? false,
            "ch 973: lockdown flag MUST propagate to persona " +
            "result")
    }

    // MARK: - 19. Risk floor integration

    func testInvocation_RiskFloorRaisesSkepticism() {
        let invocation = BASSkillAgentInvocation(
            descriptor: BASSkillAgentRegistry.writing,
            turnID: "t1",
            risk: BASAgentPersonaRiskContext(
                skepticismFloor: 0.8),
            personaID: "p")
        let result = BASSkillAgentInvoker.invoke(invocation)
        XCTAssertTrue(result.success)
        let skep = result.persona?.skepticism ?? -1
        XCTAssertEqual(
            skep, 0.8,
            accuracy: 0.0001,
            "ch 973: skill agent persona MUST respect risk " +
            "floor through full pipeline (Phase 4 + Phase 6)")
    }

    // MARK: - 20. Determinism

    func testInvocation_Deterministic() {
        let invocation = BASSkillAgentInvocation(
            descriptor: BASSkillAgentRegistry.code,
            turnID: "t1",
            personaID: "p")
        let r1 = BASSkillAgentInvoker.invoke(invocation)
        let r2 = BASSkillAgentInvoker.invoke(invocation)
        XCTAssertEqual(r1, r2,
            "ch 973: invocation MUST be deterministic for " +
            "same input (trace replay invariant)")
    }

    // MARK: - 21. ALL 4 reference agents resolve cleanly

    func testEveryReferenceAgentInvokesCleanly() {
        for descriptor in BASSkillAgentRegistry.all {
            let invocation = BASSkillAgentInvocation(
                descriptor: descriptor,
                turnID: "t1",
                personaID: "p.\(descriptor.agentID)")
            let result =
                BASSkillAgentInvoker.invoke(invocation)
            XCTAssertTrue(result.success,
                "ch 973: reference agent \(descriptor.agentID) " +
                "MUST invoke cleanly without overlay")
            XCTAssertNotNil(result.persona)
        }
    }
}
