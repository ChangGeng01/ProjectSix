// MARK: - BASOrganToolTests — chapter 三百六四 / M851
//
// Test coverage for G6 part 1 typed primitives:
//   - BASToolParameterType raw value stability
//   - BASToolParameter trimming + allowedValues filter
//   - BASTool requiredParameterNames convenience
//   - BASToolInvocation Codable round-trip
//   - BASToolResult ok / failure factories
//   - BASGuidedGenerationSchema construction + Codable

import XCTest
@testable import BASOrgan
@testable import BASRuntimeCore

final class BASOrganToolTests: XCTestCase {

    // MARK: - BASToolParameterType raw values

    func testParameterTypeRawValueStability() {
        // Pin: rawValues used by adapter translators (chapter 八十七
        // raw value stability doctrine — bumping requires migration)
        XCTAssertEqual(
            BASToolParameterType.string.rawValue, "string")
        XCTAssertEqual(
            BASToolParameterType.integer.rawValue, "integer")
        XCTAssertEqual(
            BASToolParameterType.number.rawValue, "number")
        XCTAssertEqual(
            BASToolParameterType.boolean.rawValue, "boolean")
        XCTAssertEqual(
            BASToolParameterType.array.rawValue, "array")
        XCTAssertEqual(
            BASToolParameterType.object.rawValue, "object")
        XCTAssertEqual(
            BASToolParameterType.any.rawValue, "any")
    }

    func testParameterTypeAllCasesCount() {
        XCTAssertEqual(
            BASToolParameterType.allCases.count, 7,
            "BASToolParameterType count pin: bumping requires " +
            "explicit adapter-translator review")
    }

    // MARK: - BASToolParameter

    func testParameterConstructionDefaults() {
        let p = BASToolParameter(
            name: "city",
            description: "City name to look up",
            type: .string)
        XCTAssertEqual(p.name, "city")
        XCTAssertFalse(p.required,
            "required defaults to false")
        XCTAssertEqual(p.allowedValues, [],
            "allowedValues defaults to empty")
    }

    func testParameterTrimsNameAndDescription() {
        let p = BASToolParameter(
            name: "  city  ",
            description: "  City name  ",
            type: .string)
        XCTAssertEqual(p.name, "city")
        XCTAssertEqual(p.description, "City name")
    }

    func testParameterFiltersWhitespaceOnlyAllowedValues() {
        let p = BASToolParameter(
            name: "tone",
            description: "tone selection",
            type: .string,
            allowedValues: [
                "neutral", "  formal  ", "", "  ", "casual"])
        XCTAssertEqual(
            p.allowedValues,
            ["neutral", "formal", "casual"],
            "Whitespace-only allowedValues entries dropped, " +
            "remaining trimmed")
    }

    func testParameterRequiredFlagPropagates() {
        let p = BASToolParameter(
            name: "amount",
            description: "amount to transfer",
            type: .number,
            required: true)
        XCTAssertTrue(p.required)
    }

    // MARK: - BASTool

    func testToolRequiredParameterNames() {
        let tool = BASTool(
            name: "search_memory",
            description: "Search L8 memory by query",
            parameters: [
                BASToolParameter(
                    name: "query",
                    description: "search query",
                    type: .string,
                    required: true),
                BASToolParameter(
                    name: "limit",
                    description: "max results",
                    type: .integer,
                    required: false),
                BASToolParameter(
                    name: "domain",
                    description: "memory domain",
                    type: .string,
                    required: true)
            ])
        XCTAssertEqual(
            Set(tool.requiredParameterNames),
            Set(["query", "domain"]))
    }

    func testToolTrimsNameAndDescription() {
        let tool = BASTool(
            name: "  search_memory  ",
            description: "  searches memory  ")
        XCTAssertEqual(tool.name, "search_memory")
        XCTAssertEqual(
            tool.description, "searches memory")
    }

    func testToolEmptyParameters() {
        let tool = BASTool(
            name: "ping",
            description: "no-op tool")
        XCTAssertEqual(tool.parameters, [])
        XCTAssertEqual(tool.requiredParameterNames, [])
    }

    // MARK: - BASToolInvocation

    func testInvocationCodableRoundTrip() throws {
        let invocation = BASToolInvocation(
            invocationID: "inv-1",
            toolName: "search_memory",
            arguments: [
                "query": "find atoms about cooking",
                "limit": "5"
            ])
        let data = try JSONEncoder().encode(invocation)
        let decoded = try JSONDecoder().decode(
            BASToolInvocation.self, from: data)
        XCTAssertEqual(decoded, invocation)
    }

    func testInvocationTrimsIDs() {
        let inv = BASToolInvocation(
            invocationID: "  inv-1  ",
            toolName: "  search  ",
            arguments: ["q": "hello"])
        XCTAssertEqual(inv.invocationID, "inv-1")
        XCTAssertEqual(inv.toolName, "search")
    }

    // MARK: - BASToolResult factories

    func testResultOkFactory() {
        let result = BASToolResult.ok(
            invocationID: "inv-x",
            payload: "{\"answer\": 42}")
        XCTAssertEqual(result.invocationID, "inv-x")
        XCTAssertTrue(result.success)
        XCTAssertEqual(
            result.payload, "{\"answer\": 42}")
        XCTAssertEqual(result.errorMessage, "")
    }

    func testResultFailureFactory() {
        let result = BASToolResult.failure(
            invocationID: "inv-y",
            message: "tool not found")
        XCTAssertEqual(result.invocationID, "inv-y")
        XCTAssertFalse(result.success)
        XCTAssertEqual(result.payload, "")
        XCTAssertEqual(
            result.errorMessage, "tool not found")
    }

    func testResultCodableRoundTrip() throws {
        let result = BASToolResult.ok(
            invocationID: "rt",
            payload: "[1,2,3]")
        let data = try JSONEncoder().encode(result)
        let decoded = try JSONDecoder().decode(
            BASToolResult.self, from: data)
        XCTAssertEqual(decoded, result)
    }

    // MARK: - BASGuidedGenerationSchema

    func testGuidedSchemaConstruction() {
        let schema = BASGuidedGenerationSchema(
            schemaName: "extracted_event",
            propertiesJSON: """
                {
                  "type": "object",
                  "properties": {
                    "title": {"type": "string"},
                    "date": {"type": "string"}
                  }
                }
                """,
            strict: true)
        XCTAssertEqual(
            schema.schemaName, "extracted_event")
        XCTAssertTrue(schema.strict)
        XCTAssertTrue(
            schema.propertiesJSON.contains("\"title\""))
    }

    func testGuidedSchemaDefaultsToStrict() {
        let schema = BASGuidedGenerationSchema(
            schemaName: "name",
            propertiesJSON: "{}")
        XCTAssertTrue(
            schema.strict,
            "AFM iOS 26 typed Generable defaults to strict;" +
            " mirror at the substrate primitive default")
    }

    func testGuidedSchemaCodableRoundTrip() throws {
        let schema = BASGuidedGenerationSchema(
            schemaName: "rt",
            propertiesJSON: "{\"x\":1}",
            strict: false)
        let data = try JSONEncoder().encode(schema)
        let decoded = try JSONDecoder().decode(
            BASGuidedGenerationSchema.self, from: data)
        XCTAssertEqual(decoded, schema)
    }

    // MARK: - End-to-end: Tool registration + invocation pattern

    /// Compositional pin: a host can declare a tool, build an
    /// invocation that targets it, and receive a typed result。
    /// This is the smoke test for the "tool ecosystem" surface
    /// the substrate provides。
    func testEndToEndToolRoundTrip() throws {
        let tool = BASTool(
            name: "search_memory",
            description: "Search L8 memory atoms",
            parameters: [
                BASToolParameter(
                    name: "query",
                    description: "search text",
                    type: .string,
                    required: true),
                BASToolParameter(
                    name: "k",
                    description: "max results",
                    type: .integer,
                    required: false)
            ])
        let invocation = BASToolInvocation(
            invocationID: "i-001",
            toolName: tool.name,
            arguments: ["query": "fruit", "k": "5"])
        // Validate args satisfy required params
        XCTAssertTrue(
            tool.requiredParameterNames.allSatisfy {
                invocation.arguments[$0] != nil
            },
            "Invocation arguments must include all required " +
            "parameter names")
        // Host produces result
        let result = BASToolResult.ok(
            invocationID: invocation.invocationID,
            payload: """
                [{"id":"a1"},{"id":"a2"}]
                """)
        XCTAssertEqual(
            result.invocationID, invocation.invocationID,
            "Result invocationID must correlate with the " +
            "originating invocation")
    }
}
