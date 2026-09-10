import XCTest
@testable import BASRuntimeCore
@testable import BASOrgan
@testable import BASAppleAdapters
#if canImport(FoundationModels)
import FoundationModels
#endif

/// M177 — real-path E2E coverage for `AppleFoundationOrganAdapter`.
///
/// ## Why this is a separate suite
///
/// `AppleFoundationOrganAdapterTests` covers descriptor + role + the
/// stub-fallthrough path that runs even when `FoundationModels` is
/// not importable / OS guard fails. It pins the contract.
///
/// THIS suite proves the adapter can actually drive a real on-device
/// `LanguageModelSession` end-to-end through the `BASOrganAdapter`
/// contract — body comes back non-empty, provider ID matches, the
/// `BASOrganDraft` shape is populated correctly. Without this suite
/// the substrate's "default neural provider = Apple FoundationModels"
/// (plan §9.6 / §9.10 Q1) would be a wiring claim with no executed
/// proof.
///
/// ## Why it's env-gated
///
/// 1. Real `LanguageModelSession.respond(to:)` adds 0.5–3s per call;
///    `swift test` should stay fast by default.
/// 2. Apple Intelligence may be disabled in System Settings on the
///    box running tests — the assertion would flake.
/// 3. `FoundationModels` is only available on iOS 26+ / macOS 26+;
///    older OS test boxes never enter the real path.
///
/// To run on a macOS 26+ dev box with Apple Intelligence enabled:
/// ```
/// QINAO_FM_E2E=1 swift test --filter AppleFoundationE2ETests
/// ```
final class AppleFoundationE2ETests: XCTestCase {

    private static let envFlag = "QINAO_FM_E2E"

    /// Skip unless we're on a `FoundationModels`-capable OS AND the
    /// human running the suite has opted in via `QINAO_FM_E2E=1`. Both
    /// conditions are required.
    private func skipUnlessReady() throws {
        guard ProcessInfo.processInfo.environment[Self.envFlag] == "1" else {
            throw XCTSkip(
                "set \(Self.envFlag)=1 to exercise real Apple " +
                "FoundationModels invocation")
        }
        if #available(iOS 26, macOS 26, visionOS 26, *) {
            return
        }
        throw XCTSkip(
            "FoundationModels requires iOS 26+ / macOS 26+ / " +
            "visionOS 26+; current OS does not satisfy the guard")
    }

    // MARK: - Real LanguageModelSession invocation

    func testRealScoutDraftReturnsNonEmptyBody() async throws {
        try skipUnlessReady()

        let adapter = AppleFoundationOrganAdapter()
        let request = BASOrganRequest(
            requestID: "e2e-scout-1",
            role: .scout,
            preset: .scout,
            instruction: "Reply with a single short sentence.")

        let draft = try await adapter.draft(request)

        XCTAssertEqual(
            draft.providerID,
            "apple.foundation-models.v1")
        XCTAssertEqual(draft.role, .scout)
        XCTAssertEqual(draft.requestID, "e2e-scout-1")
        XCTAssertFalse(
            draft.body
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty,
            "scout draft body must be non-empty real LLM output")
        XCTAssertGreaterThan(
            draft.outputTokensEstimated, 0,
            "estimated output tokens must reflect non-empty body")
        XCTAssertFalse(
            draft.traceID.isEmpty,
            "trace ID must be populated so audit can correlate")
    }

    func testRealCoreDraftReturnsNonEmptyBody() async throws {
        try skipUnlessReady()

        let adapter = AppleFoundationOrganAdapter()
        let request = BASOrganRequest(
            requestID: "e2e-core-1",
            role: .core,
            preset: .core,
            instruction:
                "In one or two sentences, name a benefit of running an " +
                "LLM on-device versus calling a remote API.")

        let draft = try await adapter.draft(request)

        XCTAssertEqual(
            draft.providerID,
            "apple.foundation-models.v1")
        XCTAssertEqual(draft.role, .core)
        XCTAssertFalse(
            draft.body
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty,
            "core draft body must be non-empty real LLM output")
        XCTAssertGreaterThan(draft.outputTokensEstimated, 0)
    }

    // MARK: - Capacity reflects real availability

    func testRealCapacityIsUnlimitedWhenAvailable() async throws {
        try skipUnlessReady()

        let adapter = AppleFoundationOrganAdapter()
        let cap = await adapter.currentCapacity()

        XCTAssertFalse(
            cap.underPressure,
            "capacity must NOT report underPressure when " +
            "FoundationModels is available")
        XCTAssertEqual(
            cap.availableInputTokens, .max,
            ".unlimited capacity reports Int.max input tokens")
        XCTAssertEqual(
            cap.availableOutputTokens, .max,
            ".unlimited capacity reports Int.max output tokens")
    }

    // MARK: - End-to-end through BASOrganRegistry

    /// Proves the full lookup chain — `BASOrganRegistry` resolves to
    /// `AppleFoundationOrganAdapter` (the only registered on-device
    /// adapter) and the resolved adapter produces a real LLM draft.
    /// This is the path `QinaoLoop`'s built-in
    /// `BASOrganRegistryEndpoint` walks per-turn.
    func testRealDraftThroughRegistry() async throws {
        try skipUnlessReady()

        let registry = BASOrganRegistry()
        let apple = AppleFoundationOrganAdapter()
        await registry.register(apple)

        let adapter = try await registry.adapter(
            providerID: apple.descriptor.providerID)
        XCTAssertEqual(
            adapter.descriptor.providerID,
            "apple.foundation-models.v1",
            "registry must resolve to Apple FM (the registered " +
            "on-device adapter)")

        let draft = try await adapter.draft(BASOrganRequest(
            requestID: "e2e-registry-1",
            role: .scout,
            preset: .scout,
            instruction: "Reply with one short word."))

        XCTAssertEqual(draft.providerID, "apple.foundation-models.v1")
        XCTAssertFalse(
            draft.body
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty)
    }

    /// Proves an explicit Apple provider ID is stable when another
    /// on-device adapter is co-registered.
    func testRegistryLooksUpAppleFMWhenBothPresent()
        async throws
    {
        try skipUnlessReady()

        let registry = BASOrganRegistry()
        await registry.register(BASOrganDeterministicAdapter())
        let apple = AppleFoundationOrganAdapter()
        await registry.register(apple)

        let adapter = try await registry.adapter(
            providerID: apple.descriptor.providerID)
        XCTAssertEqual(
            adapter.descriptor.providerID,
            "apple.foundation-models.v1",
            "explicit Apple provider lookup must not select the " +
            "co-registered deterministic adapter")
    }

    // MARK: - #1 native wires runtime cert (structured output + tool bridge)

    /// Tighter gate for the #1 wires: in addition to the env flag + OS guard, require Apple Intelligence to be
    /// actually AVAILABLE (model downloaded + enabled) so the suite SKIPS cleanly on a box where AI is off,
    /// rather than failing inside `respond(...)`.
    private func skipUnlessModelAvailable() throws {
        try skipUnlessReady()
        #if canImport(FoundationModels)
        if #available(iOS 26, macOS 26, visionOS 26, *) {
            let availability = SystemLanguageModel.default.availability
            guard case .available = availability else {
                throw XCTSkip(
                    "Apple Intelligence model not available (\(availability)) — enable Apple Intelligence "
                    + "+ let the on-device model finish downloading, then re-run")
            }
        }
        #endif
    }

    /// #1a — `outputSchema` → NATIVE FoundationModels guided generation yields SCHEMA-CONSTRAINED JSON (not the
    /// old audit-trace downgrade). Proves the BASGuidedSchemaTranslator → GenerationSchema → respond(to:schema:)
    /// runtime path actually constrains the real model. (Compile-only before this; now runtime-exercised.)
    func testRealOutputSchemaProducesStructuredJSON() async throws {
        try skipUnlessModelAvailable()

        let adapter = AppleFoundationOrganAdapter()
        let schema = BASGuidedGenerationSchema(
            schemaName: "city_fact",
            propertiesJSON: """
            {"type":"object","properties":{
              "city":{"type":"string","description":"a city name"},
              "population":{"type":"integer","description":"approximate population"}}}
            """)
        let draft = try await adapter.draft(BASOrganRequest(
            requestID: "e2e-schema-1", role: .core, preset: .core,
            instruction: "Give a city and its approximate population.",
            outputSchema: schema))

        // The native schema path returns GeneratedContent.jsonString → the body MUST parse as a JSON object
        // carrying the schema-constrained keys.
        let data = try XCTUnwrap(draft.body.data(using: .utf8), "body must be UTF-8")
        let obj = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any],
            "outputSchema path must return a JSON object — got: \(draft.body)")
        XCTAssertNotNil(obj["city"], "schema-constrained field `city` must be present")
        XCTAssertNotNil(obj["population"], "schema-constrained field `population` must be present")
        // Schema mapped + honored ⇒ NO `#afm-tools-dropped` suffix.
        XCTAssertFalse(
            BASFoundationModelsToolBridge.isAuditedTraceID(draft.traceID),
            "a mapped+honored schema (no tools) must NOT carry the dropped-suffix")
    }

    /// #1b — `tools[]` are BRIDGED via `.runtimeSchema` (declared in prompt; host parses + gates + executes)
    /// on the real model: the trace carries the runtime-schema marker (NOT dropped), and IF the model emits the
    /// tool-call contract, the matched parser round-trips it. The adapter still runs NO tool (gate-before-execute).
    func testRealToolsBridgeAndParseRoundTrip() async throws {
        try skipUnlessModelAvailable()

        let adapter = AppleFoundationOrganAdapter()
        let tool = BASTool(
            name: "get_weather",
            description: "Get the current weather for a city.",
            parameters: [BASToolParameter(
                name: "city", description: "the city name",
                type: .string, required: true, allowedValues: [])])
        let draft = try await adapter.draft(BASOrganRequest(
            requestID: "e2e-tools-1", role: .core, preset: .core,
            instruction: "What is the weather in Paris? Use the get_weather tool.",
            tools: [tool]))

        // Tools present ⇒ bridged via .runtimeSchema (deterministic, regardless of the model's output).
        XCTAssertTrue(
            draft.traceID.contains(BASFoundationModelsToolBridge.runtimeSchemaTraceSuffix),
            "tools must be bridged via .runtimeSchema (#afm-tools-runtime-schema marker)")
        XCTAssertFalse(
            BASFoundationModelsToolBridge.isAuditedTraceID(draft.traceID),
            "bridged tools are NOT dropped")
        // If the model emitted the tool-call contract, the matched parser must round-trip it (no crash; right name).
        if let invocation = BASToolPromptRenderer.parseToolCall(draft.body) {
            XCTAssertEqual(invocation.toolName, "get_weather",
                "a parsed tool-call must name the declared tool")
        }
    }
}
