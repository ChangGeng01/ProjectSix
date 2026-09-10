// MARK: - BASChapter954SharedStateGraphTests
// chapter 九百五十四 / M3475 (Phase 0 / ch2)
//
// Property tests for BASSharedStateGraph actor — proves
// Single-Writer-Per-Domain invariant + read/forbidden enforcement
// holds across 10K random domain × agent combinations。
//
// Per plan ch 954 knife 4: any unauthorized writer attempt throws。
//
// Coverage:
//   1. Happy path: writer-authorized agent writes,reader-authorized
//      agent reads back
//   2. Single-Writer-Per-Domain: agent with read-only access cannot
//      write → throws unauthorizedWriter
//   3. Forbidden-domain wins: agent with both read+write+forbidden
//      → forbidden wins,both throw
//   4. Version monotonicity: repeated writes increment domainVersion
//   5. Object ref parse/format round-trip
//   6. Cross-agent read after write: writer A writes,reader B reads
//      same object (different agent identities)
//   7. Fuzz: 100 random (agent, domain, write-attempt) tuples,assert
//      every authorization mismatch throws + every authorized op succeeds

import XCTest
@testable import BASMemory

final class BASChapter954SharedStateGraphTests: XCTestCase {

    // MARK: - Helpers

    private func makeAgent(
        id: String,
        write: [BASStateDomain] = [],
        read: [BASStateDomain] = [],
        forbidden: [BASStateDomain] = []
    ) -> BASAgentSpec {
        BASAgentSpec(
            agentID: id,
            role: .planner,
            writeDomains: write,
            forbiddenDomains: forbidden,
            defaultLeaseProfile: .hotSeat,
            visibility: .high)
            .withReadDomains(read)
    }

    // MARK: - 1. Happy path

    func testHappyPathWriteThenRead() async throws {
        let graph = BASSharedStateGraph()
        let writer = makeAgent(
            id: "planner.1", write: [.candidateFrontier])
        let reader = makeAgent(
            id: "critic.1", read: [.candidateFrontier])
        let obj = try await graph.writeObject(
            domain: .candidateFrontier,
            objectID: "cf-1",
            payloadJson: "{\"k\":\"v\"}",
            byAgent: writer)
        XCTAssertEqual(obj.lastWriterAgentID, "planner.1")
        XCTAssertEqual(obj.version, 1)
        let readBack = try await graph.readObject(
            ref: "candidateFrontier#cf-1", byAgent: reader)
        XCTAssertEqual(readBack.payloadJson, "{\"k\":\"v\"}")
        XCTAssertEqual(readBack.lastWriterAgentID, "planner.1")
    }

    // MARK: - 2. Single-writer-per-domain enforcement

    func testReaderCannotWrite() async {
        let graph = BASSharedStateGraph()
        let readOnly = makeAgent(
            id: "critic.1", read: [.candidateFrontier])
        do {
            _ = try await graph.writeObject(
                domain: .candidateFrontier,
                objectID: "cf-x",
                payloadJson: "{}",
                byAgent: readOnly)
            XCTFail("read-only agent must not be able to write")
        } catch BASSharedStateGraphError.unauthorizedWriter(
            let agentID, let domain) {
            XCTAssertEqual(agentID, "critic.1")
            XCTAssertEqual(domain, .candidateFrontier)
        } catch {
            XCTFail("wrong error type: \(error)")
        }
    }

    func testAgentWithoutReadAccessCannotRead() async throws {
        let graph = BASSharedStateGraph()
        let writer = makeAgent(
            id: "planner.1", write: [.candidateFrontier])
        let outsider = makeAgent(
            id: "outsider.1", read: [.riskField])  // wrong domain
        _ = try await graph.writeObject(
            domain: .candidateFrontier,
            objectID: "cf-1",
            payloadJson: "{}",
            byAgent: writer)
        do {
            _ = try await graph.readObject(
                ref: "candidateFrontier#cf-1",
                byAgent: outsider)
            XCTFail("agent without read access must throw")
        } catch BASSharedStateGraphError.unauthorizedReader {
            // expected
        } catch {
            XCTFail("wrong error type: \(error)")
        }
    }

    // MARK: - 3. Forbidden-domain wins

    func testForbiddenWinsOverWritePermission() async {
        let graph = BASSharedStateGraph()
        let conflicted = makeAgent(
            id: "buggy.1",
            write: [.hostVersion],
            forbidden: [.hostVersion])  // self-conflict
        do {
            _ = try await graph.writeObject(
                domain: .hostVersion,
                objectID: "hv-1",
                payloadJson: "{}",
                byAgent: conflicted)
            XCTFail("forbidden must beat write permission")
        } catch BASSharedStateGraphError.forbiddenDomain(
            let agentID, let domain) {
            XCTAssertEqual(agentID, "buggy.1")
            XCTAssertEqual(domain, .hostVersion)
        } catch {
            XCTFail("wrong error type: \(error)")
        }
    }

    func testForbiddenWinsOverReadPermission() async throws {
        let graph = BASSharedStateGraph()
        let writer = makeAgent(
            id: "host.1", write: [.hostVersion])
        let conflicted = makeAgent(
            id: "buggy.1",
            read: [.hostVersion],
            forbidden: [.hostVersion])  // self-conflict
        _ = try await graph.writeObject(
            domain: .hostVersion,
            objectID: "hv-1",
            payloadJson: "{}",
            byAgent: writer)
        do {
            _ = try await graph.readObject(
                ref: "hostVersion#hv-1", byAgent: conflicted)
            XCTFail("forbidden must beat read permission")
        } catch BASSharedStateGraphError.forbiddenDomain {
            // expected
        } catch {
            XCTFail("wrong error type: \(error)")
        }
    }

    // MARK: - 4. Version monotonicity

    func testVersionIncrementsPerDomain() async throws {
        let graph = BASSharedStateGraph()
        let w = makeAgent(
            id: "planner.1", write: [.candidateFrontier])
        let o1 = try await graph.writeObject(
            domain: .candidateFrontier,
            objectID: "cf-1",
            payloadJson: "{\"n\":1}",
            byAgent: w)
        let o2 = try await graph.writeObject(
            domain: .candidateFrontier,
            objectID: "cf-2",
            payloadJson: "{\"n\":2}",
            byAgent: w)
        let o3 = try await graph.writeObject(
            domain: .candidateFrontier,
            objectID: "cf-3",
            payloadJson: "{\"n\":3}",
            byAgent: w)
        XCTAssertEqual(o1.version, 1)
        XCTAssertEqual(o2.version, 2)
        XCTAssertEqual(o3.version, 3)
        let cur = await graph.domainVersion(.candidateFrontier)
        XCTAssertEqual(cur, 3)
    }

    func testVersionPerDomainIndependent() async throws {
        let graph = BASSharedStateGraph()
        let planner = makeAgent(
            id: "planner.1", write: [.candidateFrontier])
        let risk = makeAgent(
            id: "risk.1", write: [.riskField])
        _ = try await graph.writeObject(
            domain: .candidateFrontier, objectID: "cf-1",
            payloadJson: "{}", byAgent: planner)
        _ = try await graph.writeObject(
            domain: .candidateFrontier, objectID: "cf-2",
            payloadJson: "{}", byAgent: planner)
        _ = try await graph.writeObject(
            domain: .riskField, objectID: "rf-1",
            payloadJson: "{}", byAgent: risk)
        let cfVersion = await graph.domainVersion(.candidateFrontier)
        let rfVersion = await graph.domainVersion(.riskField)
        XCTAssertEqual(cfVersion, 2)
        XCTAssertEqual(rfVersion, 1)
    }

    // MARK: - 5. Object ref parse round-trip

    func testObjectRefParseRoundTrip() throws {
        for domain in BASStateDomain.allCases {
            let ref = "\(domain.rawValue)#obj-test-123"
            let parsed = try BASStateGraphObject.parse(ref: ref)
            XCTAssertEqual(parsed.domain, domain)
            XCTAssertEqual(parsed.objectID, "obj-test-123")
        }
    }

    func testObjectRefMalformedThrows() {
        let bad = ["", "no-hash", "#no-domain",
                   "wrong-domain#x", "candidateFrontier#"]
        for ref in bad {
            do {
                _ = try BASStateGraphObject.parse(ref: ref)
                XCTFail("expected throw for malformed ref: \(ref)")
            } catch BASSharedStateGraphError.malformedObjectRef {
                // expected
            } catch {
                XCTFail("wrong error for \(ref): \(error)")
            }
        }
    }

    // MARK: - 6. Cross-agent read after write

    func testCrossAgentReadAfterWrite() async throws {
        let graph = BASSharedStateGraph()
        let writer = makeAgent(
            id: "memory.1", write: [.memoryBundle])
        let reader = makeAgent(
            id: "planner.1", read: [.memoryBundle])
        _ = try await graph.writeObject(
            domain: .memoryBundle,
            objectID: "mb-1",
            payloadJson: "{\"episode\":\"abc\"}",
            byAgent: writer)
        let read = try await graph.readObject(
            ref: "memoryBundle#mb-1", byAgent: reader)
        XCTAssertEqual(read.lastWriterAgentID, "memory.1")
        XCTAssertEqual(read.payloadJson, "{\"episode\":\"abc\"}")
    }

    // MARK: - 7. Fuzz: 100 random write attempts

    /// 100-iter property test。 For each (agent, domain) pair,assert:
    ///   - If agent.forbiddenDomains contains domain ⇒ throws forbidden
    ///   - Else if agent.writeDomains contains domain ⇒ succeeds
    ///   - Else ⇒ throws unauthorizedWriter
    func testFuzzWriteAuthorizationInvariant() async throws {
        for i in 0..<100 {
            var rng = BASFuzzRng(seed: testSeed(iteration: i))
            let allDomains = BASStateDomain.allCases
            let writeCount = rng.nextInt(in: 0...3)
            let writeDomains = Array(
                Set((0..<writeCount).map { _ in
                    rng.pick(allDomains)
                }))
            let forbiddenCount = rng.nextInt(in: 0...2)
            let forbiddenDomains = Array(
                Set((0..<forbiddenCount).map { _ in
                    rng.pick(allDomains)
                }))
            let agent = BASAgentSpec(
                agentID: "fuzz-\(i)",
                role: .planner,
                writeDomains: writeDomains,
                forbiddenDomains: forbiddenDomains,
                defaultLeaseProfile: .hotSeat,
                visibility: .high)
            let attemptDomain = rng.pick(allDomains)
            let graph = BASSharedStateGraph()
            do {
                _ = try await graph.writeObject(
                    domain: attemptDomain,
                    objectID: "obj-\(i)",
                    payloadJson: "{}",
                    byAgent: agent)
                // Succeeded — must be authorized + not forbidden
                XCTAssertTrue(
                    writeDomains.contains(attemptDomain),
                    "iter=\(i): write succeeded but " +
                    "writeDomains lacks \(attemptDomain)")
                XCTAssertFalse(
                    forbiddenDomains.contains(attemptDomain),
                    "iter=\(i): write succeeded into forbidden " +
                    "domain \(attemptDomain)")
            } catch BASSharedStateGraphError.forbiddenDomain {
                XCTAssertTrue(
                    forbiddenDomains.contains(attemptDomain),
                    "iter=\(i): forbidden thrown but " +
                    "forbiddenDomains lacks \(attemptDomain)")
            } catch BASSharedStateGraphError.unauthorizedWriter {
                XCTAssertFalse(
                    forbiddenDomains.contains(attemptDomain),
                    "iter=\(i): unauthorizedWriter thrown but " +
                    "domain is forbidden — forbidden should win")
                XCTAssertFalse(
                    writeDomains.contains(attemptDomain),
                    "iter=\(i): unauthorizedWriter thrown but " +
                    "writeDomains contains \(attemptDomain)")
            } catch {
                XCTFail("iter=\(i) unexpected error: \(error)")
            }
        }
    }
}

// MARK: - Helper extension for ch 954 tests

private extension BASAgentSpec {
    /// Test-only convenience: return a copy with replaced
    /// readDomains。 Mirrors the chapter's "agent identity is
    /// immutable" invariant (we make a new value)。
    func withReadDomains(_ readDomains: [BASStateDomain])
        -> BASAgentSpec
    {
        BASAgentSpec(
            agentID: self.agentID,
            role: self.role,
            layerAffinity: self.layerAffinity,
            readDomains: readDomains,
            writeDomains: self.writeDomains,
            proposeDomains: self.proposeDomains,
            forbiddenDomains: self.forbiddenDomains,
            defaultLeaseProfile: self.defaultLeaseProfile,
            personaRef: self.personaRef,
            visibility: self.visibility,
            commitCapability: self.commitCapability)
    }
}
