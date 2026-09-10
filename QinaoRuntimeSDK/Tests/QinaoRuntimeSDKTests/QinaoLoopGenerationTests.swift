import XCTest
import BASOrgan
@testable import QinaoLoop

/// M10.1 — `QinaoLoop.generateCandidates(sessionID:seeds:)` drives a
/// live organ endpoint per seed and lands the output in the same
/// frontier / compare-panel / guardian-branch pipeline hosts already
/// use for pre-scored candidates.
///
/// These tests prove:
///   1. Default `QinaoLoop()` (no endpoint) refuses cleanly
///   2. A spy endpoint sees one call per seed, with the right
///      prompt / context / role / sessionID forwarded verbatim
///   3. Generated bodies land as the candidates' actionSummary
///   4. Provenance (`providerID`, `traceID`) survives the trip and
///      comes back on `GeneratedCandidate`
///   5. Downstream frontier / compare / guardian still work because
///      organ-generated candidates are indistinguishable from
///      host-supplied ones past the submit boundary
///   6. Intake validation (empty batch / empty ID / duplicate ID)
///      fires before any endpoint call (fail-fast)
///   7. Endpoint failures surface as typed `LoopError.organUnavailable`
///      with stable reason codes, and DON'T leave partial state in
///      the session
///   8. The `BASOrganRegistryEndpoint` internal adapter plugged
///      into a real `BASOrganDeterministicAdapter` end-to-end
///      yields the same traceID the adapter would produce
///      standalone — provenance is genuine, not synthesized
final class QinaoLoopGenerationTests: XCTestCase {

    // MARK: - Spy endpoint

    /// Records one call per seed and hands back a deterministic
    /// `OrganResponse` the tests can assert on.
    actor SpyEndpoint: QinaoOrganEndpoint {
        struct Call: Sendable, Equatable {
            let prompt: String
            let context: [String]
            let role: QinaoLoop.OrganRole
            let sessionID: String
        }
        private(set) var calls: [Call] = []
        private let providerID: String
        init(providerID: String = "spy.v1") {
            self.providerID = providerID
        }
        func produceBody(
            prompt: String,
            context: [String],
            role: QinaoLoop.OrganRole,
            sessionID: String
        ) async throws -> QinaoLoop.OrganResponse {
            let call = Call(prompt: prompt, context: context,
                            role: role, sessionID: sessionID)
            calls.append(call)
            return QinaoLoop.OrganResponse(
                body: "[\(role.rawValue)] \(prompt) | \(context.joined(separator: ";"))",
                providerID: providerID,
                traceID: "trace-\(calls.count)")
        }
        func observedCalls() -> [Call] { calls }
    }

    /// Always throws — used to prove failures surface typed and
    /// don't corrupt session state.
    struct FailingEndpoint: QinaoOrganEndpoint {
        let reason: String
        func produceBody(
            prompt: String,
            context: [String],
            role: QinaoLoop.OrganRole,
            sessionID: String
        ) async throws -> QinaoLoop.OrganResponse {
            throw QinaoLoop.LoopError.organUnavailable(reason: reason)
        }
    }

    // MARK: - Helpers

    private func makeSeed(
        _ id: String,
        prompt: String = "draft a plan",
        context: [String] = [],
        role: QinaoLoop.OrganRole = .core,
        benefit: Double = 0.5,
        cost: Double = 0.2,
        reversibility: Double = 0.5,
        confidence: Double = 0.5,
        manipulation: Double = 0,
        emotional: Double = 0,
        boundary: Double = 0
    ) -> QinaoLoop.CandidateSeed {
        QinaoLoop.CandidateSeed(
            candidateID: id,
            title: "title-\(id)",
            prompt: prompt,
            context: context,
            role: role,
            expectedBenefit: benefit,
            expectedCost: cost,
            reversibility: reversibility,
            confidence: confidence,
            manipulationRisk: manipulation,
            emotionalBias: emotional,
            boundaryConflict: boundary)
    }

    // MARK: - 1. Default loop refuses cleanly

    func testDefaultLoopWithoutEndpointRefusesGeneration() async throws {
        let loop = QinaoLoop()
        do {
            _ = try await loop.generateCandidates(
                sessionID: "s1",
                seeds: [makeSeed("c1")])
            XCTFail("default loop must refuse generation")
        } catch QinaoLoop.LoopError.organUnavailable(let reason) {
            XCTAssertEqual(reason, "no-endpoint-configured")
        }
    }

    // MARK: - 2+3+4. Spy proves forwarding + provenance

    func testSpyEndpointReceivesOneCallPerSeedInOrder() async throws {
        let spy = SpyEndpoint()
        let loop = QinaoLoop(organEndpoint: spy)
        _ = try await loop.generateCandidates(
            sessionID: "sess-a",
            seeds: [
                makeSeed("c1", prompt: "prompt-1",
                         context: ["ctx-a"], role: .scout),
                makeSeed("c2", prompt: "prompt-2",
                         context: ["ctx-b", "ctx-c"], role: .core)
            ])
        let calls = await spy.observedCalls()
        XCTAssertEqual(calls.count, 2)
        XCTAssertEqual(calls[0].prompt, "prompt-1")
        XCTAssertEqual(calls[0].context, ["ctx-a"])
        XCTAssertEqual(calls[0].role, .scout)
        XCTAssertEqual(calls[0].sessionID, "sess-a")
        XCTAssertEqual(calls[1].prompt, "prompt-2")
        XCTAssertEqual(calls[1].context, ["ctx-b", "ctx-c"])
        XCTAssertEqual(calls[1].role, .core)
    }

    func testGeneratedBodyLandsAsActionSummary() async throws {
        let spy = SpyEndpoint()
        let loop = QinaoLoop(organEndpoint: spy)
        let generated = try await loop.generateCandidates(
            sessionID: "s1",
            seeds: [makeSeed("c1", prompt: "make-calendar-event",
                             context: ["tue-3pm"], role: .scout)])
        XCTAssertEqual(generated.count, 1)
        XCTAssertEqual(generated[0].candidateID, "c1")
        XCTAssertTrue(generated[0].body.contains("make-calendar-event"))
        XCTAssertTrue(generated[0].body.contains("tue-3pm"))
        XCTAssertEqual(generated[0].providerID, "spy.v1")
        XCTAssertEqual(generated[0].traceID, "trace-1")

        // And the candidate lives in the session with that body.
        let frontier = try await loop.candidateFrontier(sessionID: "s1")
        XCTAssertEqual(frontier[0].candidateID, "c1")
        XCTAssertEqual(frontier[0].body, generated[0].body)
    }

    // MARK: - 5. Downstream pipeline unchanged

    func testGeneratedBatchParticipatesInFrontierRanking() async throws {
        let spy = SpyEndpoint()
        let loop = QinaoLoop(organEndpoint: spy)
        let gen = try await loop.generateCandidates(
            sessionID: "s1",
            seeds: [
                makeSeed("c-md", benefit: 0.5, cost: 0.3,
                         reversibility: 0.5, confidence: 0.5),
                makeSeed("c-hi", benefit: 0.9, cost: 0.1,
                         reversibility: 0.8, confidence: 0.9),
                makeSeed("c-lo", benefit: 0.2, cost: 0.2,
                         reversibility: 0.3, confidence: 0.2)
            ])
        // generateCandidates returns frontier-ordered output.
        XCTAssertEqual(gen.map(\.candidateID),
                       ["c-hi", "c-md", "c-lo"])
        XCTAssertGreaterThan(gen[0].score, gen[1].score)
        XCTAssertGreaterThan(gen[1].score, gen[2].score)

        // And candidateFrontier agrees.
        let frontier = try await loop.candidateFrontier(
            sessionID: "s1", topK: Int.max)
        XCTAssertEqual(frontier.map(\.candidateID),
                       gen.map(\.candidateID))
    }

    func testGuardianBranchFiresOnOrganGeneratedHighCritique() async throws {
        let spy = SpyEndpoint()
        let loop = QinaoLoop(organEndpoint: spy)
        _ = try await loop.generateCandidates(
            sessionID: "s1",
            seeds: [
                // critiqueStrength = 0.35·manip + 0.30·bound +
                //   0.20·emo + 0.15·evgap. manip=1.0 + bound=1.0 +
                //   emo=1.0 → 0.35 + 0.30 + 0.20 = 0.85 ≥ 0.7 so
                //   guardian fires. manipulation has highest weight
                //   tied-first so dissent = manipulation-risk.
                makeSeed("c-risky",
                         benefit: 0.5, cost: 0.2,
                         reversibility: 0.4, confidence: 0.5,
                         manipulation: 1.0,
                         emotional: 1.0,
                         boundary: 1.0),
                makeSeed("c-safe",
                         benefit: 0.6, cost: 0.2,
                         reversibility: 0.9, confidence: 0.7)
            ])
        let branch = try await loop.guardianBranch(sessionID: "s1")
        XCTAssertNotNil(branch)
        XCTAssertEqual(branch?.candidateID, "c-risky")
        XCTAssertEqual(branch?.alternative, "c-safe")
        XCTAssertEqual(branch?.dissent, "manipulation-risk")
    }

    // MARK: - 6. Intake validation fails fast

    func testEmptyBatchFailsBeforeAnyEndpointCall() async throws {
        let spy = SpyEndpoint()
        let loop = QinaoLoop(organEndpoint: spy)
        do {
            _ = try await loop.generateCandidates(
                sessionID: "s1", seeds: [])
            XCTFail("empty batch must throw")
        } catch QinaoLoop.LoopError.invalidCandidate(let reason) {
            XCTAssertEqual(reason, "empty-submission")
        }
        let calls = await spy.observedCalls()
        XCTAssertEqual(calls.count, 0,
            "endpoint must not be called when intake validation fails")
    }

    func testDuplicateSeedIDFailsBeforeAnyEndpointCall() async throws {
        let spy = SpyEndpoint()
        let loop = QinaoLoop(organEndpoint: spy)
        do {
            _ = try await loop.generateCandidates(
                sessionID: "s1",
                seeds: [makeSeed("c1"), makeSeed("c1")])
            XCTFail("duplicate ID must throw")
        } catch QinaoLoop.LoopError.invalidCandidate(let reason) {
            XCTAssertTrue(reason.hasPrefix("duplicate-candidate-id:"))
        }
        let calls = await spy.observedCalls()
        XCTAssertEqual(calls.count, 0)
    }

    func testEmptySeedIDFailsBeforeAnyEndpointCall() async throws {
        let spy = SpyEndpoint()
        let loop = QinaoLoop(organEndpoint: spy)
        do {
            _ = try await loop.generateCandidates(
                sessionID: "s1",
                seeds: [makeSeed("   ")])
            XCTFail("empty ID must throw")
        } catch QinaoLoop.LoopError.invalidCandidate(let reason) {
            XCTAssertEqual(reason, "empty-candidate-id")
        }
        let calls = await spy.observedCalls()
        XCTAssertEqual(calls.count, 0)
    }

    // MARK: - 7. Endpoint failures surface typed

    func testEndpointFailureSurfacesTypedOrganUnavailable() async throws {
        let loop = QinaoLoop(organEndpoint:
            FailingEndpoint(reason: "provider-unavailable:test-down"))
        do {
            _ = try await loop.generateCandidates(
                sessionID: "s1", seeds: [makeSeed("c1")])
            XCTFail("endpoint failure must throw")
        } catch QinaoLoop.LoopError.organUnavailable(let reason) {
            XCTAssertEqual(reason, "provider-unavailable:test-down")
        }
        // Session state must remain untouched — no half-written
        // candidate left behind.
        do {
            _ = try await loop.candidateFrontier(sessionID: "s1")
            XCTFail("no session should exist yet")
        } catch QinaoLoop.LoopError.sessionUnknown(let id) {
            XCTAssertEqual(id, "s1")
        }
    }

    // MARK: - 8. Real substrate adapter end-to-end

    /// Plumb the deterministic substrate adapter through the SDK's
    /// internal `BASOrganRegistryEndpoint` and prove the loop hands
    /// back the same `traceID` the adapter would produce on its own —
    /// proof the provenance chain is genuine, not synthesized.
    func testRealDeterministicAdapterEndToEnd() async throws {
        let clock: @Sendable () -> Date = {
            Date(timeIntervalSince1970: 1_700_000_000)
        }
        let adapter = BASOrganDeterministicAdapter(
            providerID: "bas.deterministic.v1",
            clock: clock)
        let endpoint = BASOrganRegistryEndpoint(
            providerID: adapter.descriptor.providerID,
            adapterOverride: { _ in adapter },
            nextRequestID: { "req.fixed" })
        let loop = QinaoLoop(privateEndpoint: endpoint)

        let seed = makeSeed("c1",
                            prompt: "summarise the meeting",
                            context: ["topic-A", "topic-B"],
                            role: .scout,
                            benefit: 0.7, cost: 0.2,
                            reversibility: 0.6, confidence: 0.8)
        let generated = try await loop.generateCandidates(
            sessionID: "s1", seeds: [seed])
        XCTAssertEqual(generated.count, 1)
        XCTAssertEqual(generated[0].providerID, "bas.deterministic.v1")

        // Compare against the adapter's own static digest helper
        // for the identical request. A match proves we didn't just
        // fabricate a traceID somewhere in the pipe.
        let expectedDigest = BASOrganDeterministicAdapter.digest(
            for: BASOrganRequest(
                requestID: "req.fixed",
                role: .scout,
                preset: .scout,
                instruction: "summarise the meeting",
                context: ["topic-A", "topic-B"]),
            providerID: "bas.deterministic.v1")
        XCTAssertEqual(generated[0].traceID, expectedDigest)

        // And the scoring pipeline ran on the organ-provided body.
        XCTAssertTrue(generated[0].body.contains("SCOUT"))
        XCTAssertTrue(generated[0].body.contains(
            "instruction: summarise the meeting"))
    }

    /// If the internal registry adapter has nothing registered,
    /// the endpoint must surface a typed refusal (not crash).
    func testEmptyRegistrySurfacesUnknownExplicitProvider() async throws {
        let clock: @Sendable () -> Date = { Date() }
        let registry = BASOrganRegistry(clock: clock)
        let endpoint = BASOrganRegistryEndpoint(
            registry: registry,
            providerID: "missing.provider",
            nextRequestID: { "req.test" })
        let loop = QinaoLoop(privateEndpoint: endpoint)
        do {
            _ = try await loop.generateCandidates(
                sessionID: "s1", seeds: [makeSeed("c1")])
            XCTFail("empty registry must refuse")
        } catch QinaoLoop.LoopError.organUnavailable(let reason) {
            XCTAssertEqual(reason, "unknown-provider:missing.provider")
        }
    }

    /// Regenerating a session replaces prior state, exactly like
    /// `submit` does.
    func testRegeneratingReplacesPriorSessionState() async throws {
        let spy = SpyEndpoint()
        let loop = QinaoLoop(organEndpoint: spy)
        _ = try await loop.generateCandidates(
            sessionID: "s1",
            seeds: [makeSeed("old", prompt: "round-1")])
        _ = try await loop.generateCandidates(
            sessionID: "s1",
            seeds: [makeSeed("new", prompt: "round-2")])
        let frontier = try await loop.candidateFrontier(sessionID: "s1")
        XCTAssertEqual(frontier.map(\.candidateID), ["new"])
    }
}
