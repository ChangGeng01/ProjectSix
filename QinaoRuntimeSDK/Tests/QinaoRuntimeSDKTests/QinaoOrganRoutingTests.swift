import XCTest
import BASRuntimeCore
import BASOrgan
@testable import QinaoLoop

/// M77 — per-turn organ routing tests.
///
/// Three layers of coverage:
///
/// 1. **Decision function** — `QinaoOrganRouting.decide(...)` is a
///    pure `(budget, seedRole, policy) → decision` mapping. One test
///    per decision branch + a few combinations + Codable round-trip.
/// 2. **Endpoint conformance** — `BASOrganRegistryEndpoint` conforms
///    to `QinaoBudgetAwareOrganEndpoint`; a decision-driven call
///    reaches the underlying `BASOrganAdapter` with a preset built
///    from the decision (name / temp / tokens / determinism all
///    match).
/// 3. **Loop integration** — `generateCandidates(sessionID:seeds:
///    routedBudget:routingPolicy:)` computes a decision per seed and
///    dispatches via `as? QinaoBudgetAwareOrganEndpoint`; legacy
///    non-conforming endpoints see the resolved role only (thermal
///    downgrade still enforced); non-routed overload still works.
///
/// Together these prove the M77 claim: "when L1 says it's hot,
/// QinaoLoop actually backs off, instead of ignoring the budget like
/// pre-M77 code did."
final class QinaoOrganRoutingTests: XCTestCase {

    // MARK: - Helpers

    private func makeBudget(
        precision: BASRuntimePrecisionProfile = .protected,
        thermal: BASThermalGuardLevel = .nominal
    ) -> BASBudgetFrame {
        BASBudgetFrame(
            runMode: .engage,
            maxLoops: 1,
            maxCandidates: 2,
            maxDecodeTokens: 512,
            retrievalDepth: 2,
            precisionProfile: precision,
            deviceRoute: .hybridLocal,
            thermalGuardLevel: thermal,
            maintenanceAllowed: false)
    }

    // MARK: - 1. Decision function: budget-absent path

    func testNilBudgetReturnsDefaultsForScout() throws {
        let d = QinaoLoop.QinaoOrganRouting.decide(
            budget: nil,
            seedRole: .scout)
        XCTAssertEqual(d.role, .scout)
        XCTAssertEqual(d.temperature, 0.1, accuracy: 1e-9)
        XCTAssertEqual(d.maxOutputTokens, 192)
        XCTAssertTrue(d.deterministic)
        XCTAssertEqual(d.reasonCodes, ["budget-absent"])
    }

    func testNilBudgetReturnsDefaultsForCore() throws {
        let d = QinaoLoop.QinaoOrganRouting.decide(
            budget: nil,
            seedRole: .core)
        XCTAssertEqual(d.role, .core)
        XCTAssertEqual(d.temperature, 0.7, accuracy: 1e-9)
        XCTAssertEqual(d.maxOutputTokens, 1024)
        XCTAssertFalse(d.deterministic)
        XCTAssertEqual(d.reasonCodes, ["budget-absent"])
    }

    // MARK: - 2. Nominal thermal: seed role preserved

    func testNominalThermalPreservesScoutRole() throws {
        let b = makeBudget(precision: .protected, thermal: .nominal)
        let d = QinaoLoop.QinaoOrganRouting.decide(
            budget: b, seedRole: .scout)
        XCTAssertEqual(d.role, .scout)
        XCTAssertEqual(d.temperature, 0.1, accuracy: 1e-9)
        XCTAssertEqual(d.maxOutputTokens, 192)
        XCTAssertTrue(d.deterministic)
        XCTAssertEqual(d.reasonCodes, ["seed-role-preserved"])
    }

    func testNominalThermalPreservesCoreRole() throws {
        let b = makeBudget(precision: .balanced, thermal: .nominal)
        let d = QinaoLoop.QinaoOrganRouting.decide(
            budget: b, seedRole: .core)
        XCTAssertEqual(d.role, .core)
        XCTAssertEqual(d.temperature, 0.7, accuracy: 1e-9)
        XCTAssertEqual(d.maxOutputTokens, 1024)
        XCTAssertFalse(d.deterministic)
        XCTAssertEqual(d.reasonCodes, ["seed-role-preserved"])
    }

    // MARK: - 3. Thermal emergency forces scout + cools temperature

    func testEmergencyForcesCoreSeedToScout() throws {
        let b = makeBudget(thermal: .emergency)
        let d = QinaoLoop.QinaoOrganRouting.decide(
            budget: b, seedRole: .core)
        XCTAssertEqual(d.role, .scout,
            "emergency must downgrade core to scout")
        // Scout base 0.1 - 0.20 cooling = -0.10, clamped to 0.
        XCTAssertEqual(d.temperature, 0.0, accuracy: 1e-9)
        XCTAssertTrue(d.deterministic,
            "scout-resolved role is always deterministic")
        XCTAssertTrue(
            d.reasonCodes.contains("thermal-emergency-forces-scout"))
        XCTAssertTrue(
            d.reasonCodes.contains("thermal-emergency-cools-temperature"))
        XCTAssertFalse(
            d.reasonCodes.contains("seed-role-preserved"),
            "role was downgraded, so seed-role-preserved must NOT fire")
    }

    func testEmergencyKeepsScoutSeedAsScoutAndCools() throws {
        let b = makeBudget(thermal: .emergency)
        let d = QinaoLoop.QinaoOrganRouting.decide(
            budget: b, seedRole: .scout)
        XCTAssertEqual(d.role, .scout)
        XCTAssertEqual(d.temperature, 0.0, accuracy: 1e-9)
        // Role was preserved (scout → scout), so emergency downgrade
        // code does NOT fire but cool-temp and preserved-role do.
        XCTAssertFalse(
            d.reasonCodes.contains("thermal-emergency-forces-scout"))
        XCTAssertTrue(
            d.reasonCodes.contains("thermal-emergency-cools-temperature"))
        XCTAssertTrue(
            d.reasonCodes.contains("seed-role-preserved"))
    }

    func testEmergencyWithForceScoutDisabledKeepsCore() throws {
        var policy = QinaoLoop.QinaoOrganRoutingPolicy.default
        policy = QinaoLoop.QinaoOrganRoutingPolicy(
            scoutBaseTemperature: policy.scoutBaseTemperature,
            coreBaseTemperature: policy.coreBaseTemperature,
            scoutMaxOutputTokens: policy.scoutMaxOutputTokens,
            coreMaxOutputTokens: policy.coreMaxOutputTokens,
            forceScoutUnderEmergency: false,
            forceDeterministicUnderThrottle:
                policy.forceDeterministicUnderThrottle,
            emergencyTemperatureDelta:
                policy.emergencyTemperatureDelta,
            minimalPrecisionTokenFraction:
                policy.minimalPrecisionTokenFraction)
        let b = makeBudget(thermal: .emergency)
        let d = QinaoLoop.QinaoOrganRouting.decide(
            budget: b, seedRole: .core, policy: policy)
        XCTAssertEqual(d.role, .core,
            "policy opts out of forced downgrade; core must stay core")
        // 0.7 - 0.20 = 0.5
        XCTAssertEqual(d.temperature, 0.5, accuracy: 1e-9)
        XCTAssertFalse(d.deterministic,
            "core role on emergency w/o throttle stays non-deterministic")
        XCTAssertFalse(
            d.reasonCodes.contains("thermal-emergency-forces-scout"))
        XCTAssertTrue(
            d.reasonCodes.contains("thermal-emergency-cools-temperature"))
    }

    // MARK: - 4. Thermal throttle pins deterministic on core

    func testThrottlePinsCoreDeterministic() throws {
        let b = makeBudget(thermal: .throttle)
        let d = QinaoLoop.QinaoOrganRouting.decide(
            budget: b, seedRole: .core)
        XCTAssertEqual(d.role, .core,
            "throttle is not an emergency — role not downgraded")
        XCTAssertEqual(d.temperature, 0.7, accuracy: 1e-9,
            "throttle doesn't cool temperature, only emergency does")
        XCTAssertTrue(d.deterministic,
            "throttle + core + pin policy → deterministic")
        XCTAssertTrue(
            d.reasonCodes.contains(
                "thermal-throttle-forces-deterministic"))
        XCTAssertTrue(
            d.reasonCodes.contains("seed-role-preserved"))
    }

    func testThrottleOnScoutIsNoop() throws {
        let b = makeBudget(thermal: .throttle)
        let d = QinaoLoop.QinaoOrganRouting.decide(
            budget: b, seedRole: .scout)
        // Scout is already deterministic by default; the throttle
        // pin is a no-op because the branch only fires on core.
        XCTAssertEqual(d.role, .scout)
        XCTAssertTrue(d.deterministic)
        XCTAssertFalse(
            d.reasonCodes.contains(
                "thermal-throttle-forces-deterministic"),
            "the pin reason should only fire when it matters (core)")
        XCTAssertTrue(
            d.reasonCodes.contains("seed-role-preserved"))
    }

    // MARK: - 5. Precision.minimal reduces token budget

    func testMinimalPrecisionHalvesCoreTokens() throws {
        let b = makeBudget(precision: .minimal, thermal: .nominal)
        let d = QinaoLoop.QinaoOrganRouting.decide(
            budget: b, seedRole: .core)
        XCTAssertEqual(d.maxOutputTokens, 512,
            "default fraction 0.5 * 1024 = 512")
        XCTAssertTrue(
            d.reasonCodes.contains(
                "precision-minimal-reduces-tokens"))
    }

    func testMinimalPrecisionHalvesScoutTokens() throws {
        let b = makeBudget(precision: .minimal, thermal: .nominal)
        let d = QinaoLoop.QinaoOrganRouting.decide(
            budget: b, seedRole: .scout)
        XCTAssertEqual(d.maxOutputTokens, 96,
            "default fraction 0.5 * 192 = 96")
        XCTAssertTrue(
            d.reasonCodes.contains(
                "precision-minimal-reduces-tokens"))
    }

    func testMinimalPrecisionFloorsAtThirtyTwo() throws {
        // A fraction that would drop below 32 still yields >= 32
        // because the decision function clamps.
        let policy = QinaoLoop.QinaoOrganRoutingPolicy(
            scoutBaseTemperature: 0.1,
            coreBaseTemperature: 0.7,
            scoutMaxOutputTokens: 64,  // 64 * 0.1 = 6.4 → clamped to 32
            coreMaxOutputTokens: 1024,
            forceScoutUnderEmergency: true,
            forceDeterministicUnderThrottle: true,
            emergencyTemperatureDelta: -0.20,
            minimalPrecisionTokenFraction: 0.01)  // would be clamped to 0.1
        let b = makeBudget(precision: .minimal, thermal: .nominal)
        let d = QinaoLoop.QinaoOrganRouting.decide(
            budget: b, seedRole: .scout, policy: policy)
        XCTAssertGreaterThanOrEqual(d.maxOutputTokens, 32,
            "floor-of-32 invariant must hold")
    }

    // MARK: - 6. Combined emergency + minimal precision

    func testEmergencyPlusMinimalStacksReasonCodes() throws {
        let b = makeBudget(precision: .minimal, thermal: .emergency)
        let d = QinaoLoop.QinaoOrganRouting.decide(
            budget: b, seedRole: .core)
        // Emergency forces scout; scout tokens = 192; minimal halves.
        XCTAssertEqual(d.role, .scout)
        XCTAssertEqual(d.maxOutputTokens, 96)
        XCTAssertEqual(d.temperature, 0.0, accuracy: 1e-9)
        XCTAssertTrue(d.deterministic)
        XCTAssertTrue(
            d.reasonCodes.contains("thermal-emergency-forces-scout"))
        XCTAssertTrue(
            d.reasonCodes.contains("thermal-emergency-cools-temperature"))
        XCTAssertTrue(
            d.reasonCodes.contains("precision-minimal-reduces-tokens"))
    }

    // MARK: - 7. Codable round-trip for decision + policy

    func testDecisionCodableRoundTrip() throws {
        let original = QinaoLoop.QinaoOrganRoutingDecision(
            role: .scout,
            temperature: 0.15,
            maxOutputTokens: 128,
            deterministic: true,
            reasonCodes: [
                "thermal-emergency-forces-scout",
                "precision-minimal-reduces-tokens"])
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            QinaoLoop.QinaoOrganRoutingDecision.self, from: encoded)
        XCTAssertEqual(decoded, original)
    }

    func testPolicyCodableRoundTrip() throws {
        let original = QinaoLoop.QinaoOrganRoutingPolicy.default
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            QinaoLoop.QinaoOrganRoutingPolicy.self, from: encoded)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - 8. Endpoint conformance — preset built from decision

    /// Spy adapter that captures every `draft(_:)` call so we can
    /// assert the preset carried by the request matches the decision.
    actor SpyAdapter: BASOrganAdapter {
        nonisolated let descriptor: BASOrganDescriptor
        private var seen: [BASOrganRequest] = []
        init(providerID: String) {
            self.descriptor = BASOrganDescriptor(
                providerID: providerID,
                providerName: "M77 Routing Spy",
                supportsStreaming: false,
                maxInputTokens: 1024,
                maxOutputTokens: 1024,
                runsOnDevice: false,
                supportedRoles: [.scout, .core])
        }
        func draft(_ request: BASOrganRequest) async throws -> BASOrganDraft {
            seen.append(request)
            return BASOrganDraft(
                requestID: request.requestID,
                providerID: descriptor.providerID,
                role: request.role,
                body: "body-\(request.requestID)",
                inputTokensEstimated: 0,
                outputTokensEstimated: 0,
                producedAt: Date(),
                traceID: "trace-\(seen.count)")
        }
        func currentCapacity() async -> BASOrganCapacity { .unlimited }
        func observedRequests() -> [BASOrganRequest] { seen }
    }

    func testRegistryEndpointHonorsDecisionPreset() async throws {
        let adapter = SpyAdapter(providerID: "spy.scout.v1")
        let endpoint = BASOrganRegistryEndpoint(
            adapterOverride: { _ in adapter },
            nextRequestID: { "req-1" })
        let decision = QinaoLoop.QinaoOrganRoutingDecision(
            role: .scout,
            temperature: 0.05,
            maxOutputTokens: 96,
            deterministic: true,
            reasonCodes: ["thermal-emergency-cools-temperature"])
        let response = try await endpoint.produceBody(
            prompt: "p",
            context: ["ctx"],
            sessionID: "s",
            decision: decision)
        XCTAssertEqual(response.body, "body-req-1")
        XCTAssertEqual(response.providerID, "spy.scout.v1")
        XCTAssertEqual(response.traceID, "trace-1")

        let requests = await adapter.observedRequests()
        XCTAssertEqual(requests.count, 1)
        let preset = requests[0].preset
        XCTAssertEqual(preset.name, "qinao.m77.scout.routed")
        XCTAssertEqual(preset.temperature, 0.05, accuracy: 1e-9)
        XCTAssertEqual(preset.maxOutputTokens, 96)
        XCTAssertTrue(preset.deterministic)
        // topP stays at the substrate's canonical 0.95
        XCTAssertEqual(preset.topP, 0.95, accuracy: 1e-9)
    }

    // MARK: - 9. Loop integration: budget-aware path

    /// Dual-purpose spy: conforms to QinaoBudgetAwareOrganEndpoint
    /// and captures every call so the loop-integration tests can
    /// assert the decision actually reached the endpoint.
    actor BudgetAwareSpyEndpoint: QinaoBudgetAwareOrganEndpoint {
        struct RoutedCall: Sendable, Equatable {
            let prompt: String
            let context: [String]
            let sessionID: String
            let decision: QinaoLoop.QinaoOrganRoutingDecision
        }
        struct LegacyCall: Sendable, Equatable {
            let prompt: String
            let context: [String]
            let role: QinaoLoop.OrganRole
            let sessionID: String
        }
        private(set) var routedCalls: [RoutedCall] = []
        private(set) var legacyCalls: [LegacyCall] = []
        private let providerID: String
        init(providerID: String = "spy.budget-aware.v1") {
            self.providerID = providerID
        }
        func produceBody(
            prompt: String,
            context: [String],
            role: QinaoLoop.OrganRole,
            sessionID: String
        ) async throws -> QinaoLoop.OrganResponse {
            legacyCalls.append(LegacyCall(
                prompt: prompt, context: context,
                role: role, sessionID: sessionID))
            return QinaoLoop.OrganResponse(
                body: "[legacy:\(role.rawValue)] \(prompt)",
                providerID: providerID,
                traceID: "legacy-\(legacyCalls.count)")
        }
        func produceBody(
            prompt: String,
            context: [String],
            sessionID: String,
            decision: QinaoLoop.QinaoOrganRoutingDecision
        ) async throws -> QinaoLoop.OrganResponse {
            routedCalls.append(RoutedCall(
                prompt: prompt, context: context,
                sessionID: sessionID, decision: decision))
            return QinaoLoop.OrganResponse(
                body: "[routed:\(decision.role.rawValue)/t=\(decision.temperature)] \(prompt)",
                providerID: providerID,
                traceID: "routed-\(routedCalls.count)")
        }
        func observedRoutedCalls() -> [RoutedCall] { routedCalls }
        func observedLegacyCalls() -> [LegacyCall] { legacyCalls }
    }

    /// Plain legacy endpoint that only implements the role-only path.
    /// Used to prove the fallback dispatch in QinaoLoop works.
    actor LegacyOnlySpyEndpoint: QinaoOrganEndpoint {
        struct Call: Sendable, Equatable {
            let role: QinaoLoop.OrganRole
            let prompt: String
        }
        private(set) var calls: [Call] = []
        func produceBody(
            prompt: String,
            context: [String],
            role: QinaoLoop.OrganRole,
            sessionID: String
        ) async throws -> QinaoLoop.OrganResponse {
            calls.append(Call(role: role, prompt: prompt))
            return QinaoLoop.OrganResponse(
                body: "legacy-\(role.rawValue)",
                providerID: "legacy.v1",
                traceID: "t-\(calls.count)")
        }
        func observedCalls() -> [Call] { calls }
    }

    private func makeSeed(
        _ id: String,
        role: QinaoLoop.OrganRole
    ) -> QinaoLoop.CandidateSeed {
        QinaoLoop.CandidateSeed(
            candidateID: id,
            title: "t-\(id)",
            prompt: "p-\(id)",
            context: [],
            role: role,
            expectedBenefit: 0.5,
            expectedCost: 0.2,
            reversibility: 0.5,
            confidence: 0.5)
    }

    func testLoopEmergencyRoutesCoreSeedToScoutViaDecision() async throws {
        let endpoint = BudgetAwareSpyEndpoint()
        let loop = QinaoLoop(organEndpoint: endpoint)
        let budget = makeBudget(thermal: .emergency)
        _ = try await loop.generateCandidates(
            sessionID: "s1",
            seeds: [makeSeed("c1", role: .core)],
            routedBudget: budget)

        let routed = await endpoint.observedRoutedCalls()
        let legacy = await endpoint.observedLegacyCalls()
        XCTAssertEqual(routed.count, 1,
            "budget-aware endpoint must receive the routed call")
        XCTAssertEqual(legacy.count, 0,
            "legacy path must not fire when routed path is available")
        XCTAssertEqual(routed[0].decision.role, .scout,
            "thermal emergency must downgrade core to scout")
        XCTAssertTrue(routed[0].decision.reasonCodes.contains(
            "thermal-emergency-forces-scout"))
    }

    func testLoopLegacyEndpointStillGetsDowngradedRole() async throws {
        // Legacy endpoint can't honor temperature/tokens, but the
        // loop still forwards the resolved (possibly downgraded) role
        // so the thermal protection still applies.
        let endpoint = LegacyOnlySpyEndpoint()
        let loop = QinaoLoop(organEndpoint: endpoint)
        let budget = makeBudget(thermal: .emergency)
        _ = try await loop.generateCandidates(
            sessionID: "s2",
            seeds: [makeSeed("c1", role: .core)],
            routedBudget: budget)
        let calls = await endpoint.observedCalls()
        XCTAssertEqual(calls.count, 1)
        XCTAssertEqual(calls[0].role, .scout,
            "legacy endpoint must see the DOWNGRADED role")
    }

    func testLoopWithNilBudgetRoutesWithDefaults() async throws {
        let endpoint = BudgetAwareSpyEndpoint()
        let loop = QinaoLoop(organEndpoint: endpoint)
        _ = try await loop.generateCandidates(
            sessionID: "s3",
            seeds: [makeSeed("c1", role: .core)],
            routedBudget: nil)
        let routed = await endpoint.observedRoutedCalls()
        XCTAssertEqual(routed.count, 1)
        XCTAssertEqual(routed[0].decision.role, .core)
        XCTAssertEqual(routed[0].decision.reasonCodes,
            ["budget-absent"])
    }

    // MARK: - 10. Non-routed overload byte-compatible

    func testNonRoutedOverloadStillHitsLegacyPath() async throws {
        // Existing `generateCandidates(sessionID:seeds:)` overload
        // MUST still call the legacy `produceBody(...role:sessionID:)`
        // path even on a budget-aware endpoint — no decision work
        // happens when the caller didn't opt in.
        let endpoint = BudgetAwareSpyEndpoint()
        let loop = QinaoLoop(organEndpoint: endpoint)
        _ = try await loop.generateCandidates(
            sessionID: "s4",
            seeds: [makeSeed("c1", role: .core)])
        let routed = await endpoint.observedRoutedCalls()
        let legacy = await endpoint.observedLegacyCalls()
        XCTAssertEqual(routed.count, 0,
            "non-routed overload must not compute a decision")
        XCTAssertEqual(legacy.count, 1,
            "non-routed overload must call the legacy path")
        XCTAssertEqual(legacy[0].role, .core,
            "non-routed overload forwards the seed role verbatim")
    }

    // MARK: - 11. Loop dispatches per-seed decisions independently

    func testLoopMultiSeedDispatchesIndependentDecisions() async throws {
        let endpoint = BudgetAwareSpyEndpoint()
        let loop = QinaoLoop(organEndpoint: endpoint)
        // throttle + core → deterministic pin; scout seed unaffected.
        let budget = makeBudget(thermal: .throttle)
        _ = try await loop.generateCandidates(
            sessionID: "s5",
            seeds: [
                makeSeed("c1", role: .scout),
                makeSeed("c2", role: .core),
            ],
            routedBudget: budget)
        let routed = await endpoint.observedRoutedCalls()
        XCTAssertEqual(routed.count, 2)
        // Seed order preserved.
        XCTAssertEqual(routed[0].decision.role, .scout)
        XCTAssertTrue(routed[0].decision.deterministic)
        XCTAssertFalse(
            routed[0].decision.reasonCodes.contains(
                "thermal-throttle-forces-deterministic"),
            "pin doesn't fire on scout")
        XCTAssertEqual(routed[1].decision.role, .core)
        XCTAssertTrue(routed[1].decision.deterministic,
            "core under throttle is pinned deterministic")
        XCTAssertTrue(
            routed[1].decision.reasonCodes.contains(
                "thermal-throttle-forces-deterministic"))
    }
}
