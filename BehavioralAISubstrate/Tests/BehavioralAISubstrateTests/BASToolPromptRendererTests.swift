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
}
