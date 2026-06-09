import XCTest
@testable import BASOrgan

/// #1b (.runtimeSchema) — the PURE tool→prompt renderer + its bridge wiring. The renderer makes a model AWARE
/// of tools so it can emit a parseable tool-call; the HOST parses + gates + executes (the adapter runs nothing
/// — gate-before-execute preserved). These prove the rendered contract deterministically (no FoundationModels).
final class BASToolPromptRendererTests: XCTestCase {

    private func tool(_ name: String) -> BASTool {
        BASTool(
            name: name,
            description: "search the memory store",
            parameters: [
                BASToolParameter(
                    name: "query", description: "the search text",
                    type: .string, required: true, allowedValues: []),
                BASToolParameter(
                    name: "scope", description: "where to look",
                    type: .string, required: false, allowedValues: ["warm", "cold"])
            ])
    }

    func testEmptyToolsRenderEmptyBlock() {
        XCTAssertEqual(BASToolPromptRenderer.runtimeSchemaBlock(for: []), "",
            "no tools ⇒ empty block ⇒ the prompt is byte-equal to the no-tools path")
    }

    func testRenderedBlockDeclaresToolsParamsAndCallFormat() {
        let block = BASToolPromptRenderer.runtimeSchemaBlock(for: [tool("search_memory")])
        XCTAssertTrue(block.contains("search_memory"), "tool name must be declared")
        XCTAssertTrue(block.contains("search the memory store"), "tool description must be declared")
        XCTAssertTrue(block.contains("query"), "parameter name must be declared")
        XCTAssertTrue(block.contains("[required]"))
        XCTAssertTrue(block.contains("[optional]"))
        XCTAssertTrue(block.contains("one of: warm, cold"), "allowedValues must be surfaced")
        // The tool-call output contract the host parser targets must be present.
        XCTAssertTrue(block.contains("\"tool_call\""))
        XCTAssertTrue(block.contains(BASToolPromptRenderer.toolCallInstruction))
    }

    func testRenderIsDeterministic() {
        let tools = [tool("a"), tool("b")]
        XCTAssertEqual(
            BASToolPromptRenderer.runtimeSchemaBlock(for: tools),
            BASToolPromptRenderer.runtimeSchemaBlock(for: tools),
            "same tools ⇒ same block (no Date/UUID/order nondeterminism)")
    }

    // MARK: - Bridge wiring (the adapter now EXERCISES resolve(.runtimeSchema))

    func testRuntimeSchemaBridgesNonEmptyToolsAndIsDistinctFromDropped() {
        let status = BASFoundationModelsToolBridge.resolve(
            strategy: .runtimeSchema, tools: [tool("t")], baseTraceID: "base")
        XCTAssertTrue(status.didBridgeTools,
            ".runtimeSchema must BRIDGE non-empty tools (not drop them)")
        // The two markers are distinct strings so observers can tell prompt-bridged from dropped.
        XCTAssertNotEqual(
            BASFoundationModelsToolBridge.runtimeSchemaTraceSuffix,
            BASFoundationModelsToolBridge.auditTraceSuffix)
        XCTAssertEqual(
            BASFoundationModelsToolBridge.runtimeSchemaTraceSuffix,
            "#afm-tools-runtime-schema")
    }

    func testEmptyToolsResolveAsAuditedNotBridged() {
        let status = BASFoundationModelsToolBridge.resolve(
            strategy: .runtimeSchema, tools: [], baseTraceID: "base")
        XCTAssertFalse(status.didBridgeTools,
            "no tools ⇒ nothing to bridge")
    }

    // MARK: - The matched parser (the contract is no longer orphaned)

    func testParseToolCallExtractsNameAndJSONFragmentArgs() {
        let body = """
        {"tool_call": {"name": "search_memory", "arguments": {"query": "hello", "limit": 5, "deep": true}}}
        """
        let inv = BASToolPromptRenderer.parseToolCall(body)
        XCTAssertEqual(inv?.toolName, "search_memory")
        // arguments are JSON fragments (the BASToolInvocation contract — caller decodes per param type).
        XCTAssertEqual(inv?.arguments["query"], "\"hello\"")
        XCTAssertEqual(inv?.arguments["limit"], "5")
        XCTAssertEqual(inv?.arguments["deep"], "true")
    }

    func testParseToolCallIsLenientAboutSurroundingProse() {
        let body = """
        Sure, let me look that up.
        {"tool_call": {"name": "lookup", "arguments": {"q": "x"}}}
        """
        XCTAssertEqual(BASToolPromptRenderer.parseToolCall(body)?.toolName, "lookup")
    }

    func testParseNonToolBodyReturnsNil() {
        XCTAssertNil(BASToolPromptRenderer.parseToolCall("Just a plain answer, no tool."))
        XCTAssertNil(BASToolPromptRenderer.parseToolCall("{\"not_a_tool_call\": 1}"))
        XCTAssertNil(BASToolPromptRenderer.parseToolCall(""))
    }

    func testParseToolCallInvocationIDIsDeterministic() {
        let body = "{\"tool_call\": {\"name\": \"t\", \"arguments\": {\"a\": 1}}}"
        XCTAssertEqual(
            BASToolPromptRenderer.parseToolCall(body)?.invocationID,
            BASToolPromptRenderer.parseToolCall(body)?.invocationID,
            "same body ⇒ same invocationID (pure, no UUID/Date)")
    }

    func testEmitParseAreOneContract() {
        // The renderer's instruction documents the EXACT shape parseToolCall consumes — emit↔parse is one
        // contract (single-source-of-truth). A reply in that shape must parse to a usable invocation.
        let declared = BASToolPromptRenderer.toolCallInstruction
        XCTAssertTrue(declared.contains("\"tool_call\""))
        XCTAssertTrue(declared.contains("\"name\""))
        XCTAssertTrue(declared.contains("\"arguments\""))
        let inv = BASToolPromptRenderer.parseToolCall(
            "{\"tool_call\": {\"name\": \"do_it\", \"arguments\": {}}}")
        XCTAssertEqual(inv?.toolName, "do_it")
        XCTAssertEqual(inv?.arguments, [:])
    }
}
