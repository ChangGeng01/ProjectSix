// MARK: - BASLLMModelRouterTests — chapter 四百一 / M936

import XCTest
@testable import BASOrgan
@testable import BASRuntimeCore

final class BASLLMModelRouterTests: XCTestCase {

    private func makeMock(
        body: String = "x"
    ) -> BASFoundationModelsMockSession {
        BASFoundationModelsMockSession(
            scriptedResponses: [.text(body: body)])
    }

    private func makeTask(
        taskType: String = "chat",
        privacy: BASEventLogRiskBand = .low,
        risk: BASEventLogRiskBand = .low,
        latencyBudgetMs: Int = .max,
        qualityRequirement: String = "default",
        requiresTools: Bool = false
    ) -> BASLLMModelRoutingTask {
        BASLLMModelRoutingTask(
            taskType: taskType,
            privacy: privacy, risk: risk,
            latencyBudgetMs: latencyBudgetMs,
            qualityRequirement: qualityRequirement,
            requiresTools: requiresTools)
    }

    // MARK: - Enum surface

    func testModelClassAllCases() {
        XCTAssertEqual(
            BASLLMModelClass.allCases.count, 5)
    }

    func testReasoningLevelAllCases() {
        XCTAssertEqual(
            BASLLMReasoningLevel.allCases.count, 5)
    }

    // MARK: - Registry

    func testRegisterAdaptersAndPick() async throws {
        let small = makeMock(body: "small")
        let strong = makeMock(body: "strong")
        let router = BASLLMModelRouter(
            policy: BASLLMModelRouter.defaultPolicy)
        try await router.register(
            adapter: small, forClass: .small)
        try await router.register(
            adapter: strong, forClass: .strong)
        let classes = await router.registeredClasses
        XCTAssertEqual(classes,
            Set([.small, .strong]))
    }

    func testDuplicateRegistrationThrows() async {
        let router = BASLLMModelRouter(
            policy: BASLLMModelRouter.defaultPolicy)
        do {
            try await router.register(
                adapter: makeMock(),
                forClass: .small)
            try await router.register(
                adapter: makeMock(),
                forClass: .small)
            XCTFail("Must throw on duplicate")
        } catch BASLLMModelRouterError
            .duplicateAdapterRegistration(let cls)
        {
            XCTAssertEqual(cls, .small)
        } catch {
            XCTFail("Wrong error: \(error)")
        }
    }

    // MARK: - Default policy decisions

    func testDefaultPolicyToolsRequiredPrefersStrong() async
        throws
    {
        let router = BASLLMModelRouter(
            policy: BASLLMModelRouter.defaultPolicy)
        try await router.register(
            adapter: makeMock(), forClass: .small)
        try await router.register(
            adapter: makeMock(), forClass: .strong)
        let decision = await router.decide(
            for: makeTask(requiresTools: true))
        XCTAssertEqual(decision.chosenModelClass, .strong)
        XCTAssertEqual(decision.reasoningLevel, .high)
    }

    func testDefaultPolicyHighRiskGoesStrong() async throws
    {
        let router = BASLLMModelRouter(
            policy: BASLLMModelRouter.defaultPolicy)
        try await router.register(
            adapter: makeMock(), forClass: .strong)
        try await router.register(
            adapter: makeMock(), forClass: .medium)
        let decision = await router.decide(
            for: makeTask(risk: .high))
        XCTAssertEqual(decision.chosenModelClass, .strong)
    }

    func testDefaultPolicyHighPrivacyPrefersLocal() async
        throws
    {
        let router = BASLLMModelRouter(
            policy: BASLLMModelRouter.defaultPolicy)
        try await router.register(
            adapter: makeMock(), forClass: .local)
        try await router.register(
            adapter: makeMock(), forClass: .strong)
        let decision = await router.decide(
            for: makeTask(privacy: .high))
        XCTAssertEqual(decision.chosenModelClass, .local)
    }

    func testDefaultPolicyTightLatencyPrefersSmall() async
        throws
    {
        let router = BASLLMModelRouter(
            policy: BASLLMModelRouter.defaultPolicy)
        try await router.register(
            adapter: makeMock(), forClass: .small)
        try await router.register(
            adapter: makeMock(), forClass: .strong)
        let decision = await router.decide(
            for: makeTask(latencyBudgetMs: 500))
        XCTAssertEqual(decision.chosenModelClass, .small)
    }

    func testDefaultPolicyProductionQualityPrefersStrong()
        async throws
    {
        let router = BASLLMModelRouter(
            policy: BASLLMModelRouter.defaultPolicy)
        try await router.register(
            adapter: makeMock(), forClass: .strong)
        try await router.register(
            adapter: makeMock(), forClass: .medium)
        let decision = await router.decide(
            for: makeTask(qualityRequirement: "production"))
        XCTAssertEqual(decision.chosenModelClass, .strong)
    }

    // MARK: - PickAdapter telemetry

    func testPickAdapterIncrementsRoutingCounts() async
        throws
    {
        let router = BASLLMModelRouter(
            policy: BASLLMModelRouter.defaultPolicy)
        try await router.register(
            adapter: makeMock(), forClass: .medium)
        try await router.register(
            adapter: makeMock(), forClass: .strong)
        _ = try await router.pickAdapter(
            for: makeTask(qualityRequirement:
                "production"))
        _ = try await router.pickAdapter(
            for: makeTask(qualityRequirement:
                "production"))
        let counts = await router.routingCounts
        XCTAssertEqual(counts[.strong], 2)
    }

    // MARK: - Codable round-trip

    func testRoutingDecisionRoundTrip() throws {
        let dec = BASLLMModelRoutingDecision(
            chosenModelClass: .strong,
            reasoningLevel: .deep,
            fallbackModelClass: .medium,
            reasonCodes: ["test:reason"])
        let data = try JSONEncoder().encode(dec)
        let decoded = try JSONDecoder().decode(
            BASLLMModelRoutingDecision.self, from: data)
        XCTAssertEqual(decoded, dec)
    }
}
