// MARK: - BASOrganRequestM852Tests — chapter 三百六五 / M852
//
// Test coverage for G6 part 2: BASOrganRequest extended with
// tools[] + outputSchema fields。Verifies:
//   - Backwards-compat default values (empty tools[] +
//     nil outputSchema)
//   - Both fields propagate via init
//   - Equatable conformance includes new fields
//   - Existing init call sites continue to compile
//   - tools[] preserved via construction (no ordering loss)

import XCTest
@testable import BASOrgan
@testable import BASRuntimeCore

final class BASOrganRequestM852Tests: XCTestCase {

    // MARK: - Backwards-compat defaults

    func testRequestDefaultToolsIsEmpty() {
        let request = BASOrganRequest(
            requestID: "r-1",
            role: .scout,
            preset: .scout,
            instruction: "Hello")
        XCTAssertEqual(
            request.tools, [],
            "Default tools[] must be empty for ADR-014 OPT-IN " +
            "compatibility (pre-M852 hosts see zero behavior " +
            "change)")
    }

    func testRequestDefaultOutputSchemaIsNil() {
        let request = BASOrganRequest(
            requestID: "r-2",
            role: .scout,
            preset: .scout,
            instruction: "Hello")
        XCTAssertNil(
            request.outputSchema,
            "Default outputSchema must be nil for ADR-014 " +
            "OPT-IN compatibility")
    }

    // MARK: - Field propagation

    func testRequestPropagatesToolsField() {
        let tool = BASTool(
            name: "search_memory",
            description: "Search L8 atoms",
            parameters: [
                BASToolParameter(
                    name: "query",
                    description: "search text",
                    type: .string,
                    required: true)
            ])
        let request = BASOrganRequest(
            requestID: "r-3",
            role: .scout,
            preset: .scout,
            instruction: "Hello",
            tools: [tool])
        XCTAssertEqual(request.tools.count, 1)
        XCTAssertEqual(
            request.tools.first?.name, "search_memory")
        XCTAssertEqual(
            request.tools.first?.requiredParameterNames,
            ["query"])
    }

    func testRequestPropagatesOutputSchemaField() {
        let schema = BASGuidedGenerationSchema(
            schemaName: "extracted_event",
            propertiesJSON: """
                {"type":"object",
                 "properties":{"title":{"type":"string"}}}
                """,
            strict: true)
        let request = BASOrganRequest(
            requestID: "r-4",
            role: .scout,
            preset: .scout,
            instruction: "Extract event from this text",
            outputSchema: schema)
        XCTAssertNotNil(request.outputSchema)
        XCTAssertEqual(
            request.outputSchema?.schemaName,
            "extracted_event")
        XCTAssertTrue(
            request.outputSchema?.strict ?? false)
    }

    // MARK: - Equatable

    func testRequestEquatableIncludesToolsField() {
        let tool = BASTool(
            name: "tool_x",
            description: "test tool")
        let a = BASOrganRequest(
            requestID: "r",
            role: .scout,
            preset: .scout,
            instruction: "x",
            tools: [tool])
        let b = BASOrganRequest(
            requestID: "r",
            role: .scout,
            preset: .scout,
            instruction: "x",
            tools: [tool])
        let c = BASOrganRequest(
            requestID: "r",
            role: .scout,
            preset: .scout,
            instruction: "x",
            tools: [])
        XCTAssertEqual(a, b,
            "Same tools[] → equal")
        XCTAssertNotEqual(a, c,
            "Different tools[] → distinct")
    }

    func testRequestEquatableIncludesOutputSchemaField() {
        let schema1 = BASGuidedGenerationSchema(
            schemaName: "s1", propertiesJSON: "{}")
        let schema2 = BASGuidedGenerationSchema(
            schemaName: "s2", propertiesJSON: "{}")
        let withS1 = BASOrganRequest(
            requestID: "r", role: .scout, preset: .scout,
            instruction: "x", outputSchema: schema1)
        let withS1Again = BASOrganRequest(
            requestID: "r", role: .scout, preset: .scout,
            instruction: "x", outputSchema: schema1)
        let withS2 = BASOrganRequest(
            requestID: "r", role: .scout, preset: .scout,
            instruction: "x", outputSchema: schema2)
        let withNil = BASOrganRequest(
            requestID: "r", role: .scout, preset: .scout,
            instruction: "x")
        XCTAssertEqual(withS1, withS1Again)
        XCTAssertNotEqual(withS1, withS2)
        XCTAssertNotEqual(withS1, withNil)
    }

    // MARK: - Backwards-compat call site

    /// Pre-M852 callers should continue to compile + produce
    /// the same BASOrganRequest values (modulo the new optional
    /// fields defaulting to empty/nil)。
    func testPreM852CallSiteStillCompiles() {
        // This is the canonical pre-M852 init shape — must
        // still compile + run without source change
        let request = BASOrganRequest(
            requestID: "legacy-call",
            role: .scout,
            preset: .scout,
            instruction: "Pre-M852 caller still works",
            context: ["prior context"],
            maxOutputTokens: 256,
            stopSequences: ["END"],
            deadline: nil)
        // M852 adds these defaults
        XCTAssertEqual(request.tools, [])
        XCTAssertNil(request.outputSchema)
        // Pre-M852 fields preserved
        XCTAssertEqual(request.requestID, "legacy-call")
        XCTAssertEqual(request.context, ["prior context"])
        XCTAssertEqual(request.maxOutputTokens, 256)
        XCTAssertEqual(request.stopSequences, ["END"])
    }

    // MARK: - Multiple tools order preservation

    func testRequestPreservesToolsOrder() {
        let tools = [
            BASTool(name: "a", description: "first"),
            BASTool(name: "b", description: "second"),
            BASTool(name: "c", description: "third")
        ]
        let request = BASOrganRequest(
            requestID: "r",
            role: .scout,
            preset: .scout,
            instruction: "x",
            tools: tools)
        XCTAssertEqual(
            request.tools.map { $0.name },
            ["a", "b", "c"],
            "Tool order must be preserved (some adapters " +
            "use list order for fallback / priority)")
    }
}
