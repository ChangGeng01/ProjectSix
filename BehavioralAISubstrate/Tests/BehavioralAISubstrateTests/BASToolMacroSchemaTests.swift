// MARK: - BASToolMacroSchemaTests — chapter 四百 / M919

import XCTest
@testable import BASOrgan
@testable import BASRuntimeCore

final class BASToolMacroSchemaTests: XCTestCase {

    // MARK: - Schema version

    func testSchemaVersionPinned() {
        XCTAssertEqual(
            BASToolMacroSchema.schemaVersion,
            "M919.1.0.0")
    }

    func testCanonicalCallSignaturePinned() {
        XCTAssertEqual(
            BASToolMacroSchema
                .canonicalCallMethodSignature,
            "func call(arguments: Arguments) async throws " +
            "-> ToolOutput")
    }

    // MARK: - Type name mapping

    func testSwiftTypeNameRequired() {
        XCTAssertEqual(
            BASToolMacroSchema.swiftTypeName(
                for: .string, required: true),
            "String")
        XCTAssertEqual(
            BASToolMacroSchema.swiftTypeName(
                for: .integer, required: true),
            "Int")
        XCTAssertEqual(
            BASToolMacroSchema.swiftTypeName(
                for: .number, required: true),
            "Double")
        XCTAssertEqual(
            BASToolMacroSchema.swiftTypeName(
                for: .boolean, required: true),
            "Bool")
        XCTAssertEqual(
            BASToolMacroSchema.swiftTypeName(
                for: .array, required: true),
            "[String]")
        XCTAssertEqual(
            BASToolMacroSchema.swiftTypeName(
                for: .object, required: true),
            "[String: String]")
        XCTAssertEqual(
            BASToolMacroSchema.swiftTypeName(
                for: .any, required: true),
            "String")
    }

    func testSwiftTypeNameOptionalSuffix() {
        XCTAssertEqual(
            BASToolMacroSchema.swiftTypeName(
                for: .string, required: false),
            "String?")
        XCTAssertEqual(
            BASToolMacroSchema.swiftTypeName(
                for: .integer, required: false),
            "Int?")
    }

    // MARK: - Property name camelCase

    func testCamelCaseFromSnakeCase() {
        let param = BASToolParameter(
            name: "search_query",
            description: "",
            type: .string)
        XCTAssertEqual(
            BASToolMacroSchema
                .expectedArgumentsPropertyName(
                    for: param),
            "searchQuery")
    }

    func testCamelCaseFromKebabCase() {
        let param = BASToolParameter(
            name: "max-results",
            description: "",
            type: .integer)
        XCTAssertEqual(
            BASToolMacroSchema
                .expectedArgumentsPropertyName(
                    for: param),
            "maxResults")
    }

    func testReservedWordSuffixed() {
        let param = BASToolParameter(
            name: "class",
            description: "",
            type: .string)
        XCTAssertEqual(
            BASToolMacroSchema
                .expectedArgumentsPropertyName(
                    for: param),
            "classValue")
    }

    func testEmptyNameFallback() {
        let param = BASToolParameter(
            name: "",
            description: "",
            type: .string)
        XCTAssertEqual(
            BASToolMacroSchema
                .expectedArgumentsPropertyName(
                    for: param),
            "unnamed")
    }

    // MARK: - Mapping factory

    func testMappingFactoryAllCases() {
        XCTAssertEqual(
            BASToolMacroSchema.mapping(for: .string),
            .stringToString)
        XCTAssertEqual(
            BASToolMacroSchema.mapping(for: .integer),
            .integerToInt)
        XCTAssertEqual(
            BASToolMacroSchema.mapping(for: .number),
            .numberToDouble)
        XCTAssertEqual(
            BASToolMacroSchema.mapping(for: .boolean),
            .booleanToBool)
        XCTAssertEqual(
            BASToolMacroSchema.mapping(for: .array),
            .arrayToStringArray)
        XCTAssertEqual(
            BASToolMacroSchema.mapping(for: .object),
            .objectToStringDict)
        XCTAssertEqual(
            BASToolMacroSchema.mapping(for: .any),
            .anyToString)
    }

    // MARK: - Expected output

    func testExpectedOutputForFullTool() {
        let tool = BASTool(
            name: "search_memory",
            description: "search the memory store",
            parameters: [
                BASToolParameter(
                    name: "query",
                    description: "search text",
                    type: .string,
                    required: true),
                BASToolParameter(
                    name: "max_results",
                    description: "cap on results",
                    type: .integer,
                    required: false)
            ])
        let input = BASToolMacroInput(
            tool: tool,
            argumentsTypeName: "SearchMemoryArguments",
            toolConformerTypeName:
                "SearchMemoryFoundationModelsTool",
            parameterMappings: [
                .stringToString,
                .integerToInt
            ])
        let output = BASToolMacroSchema.expectedOutput(
            for: input)

        XCTAssertEqual(output.argumentsProperties.count, 2)
        XCTAssertEqual(
            output.argumentsProperties[0].name, "query")
        XCTAssertEqual(
            output.argumentsProperties[0].swiftTypeName,
            "String")
        XCTAssertTrue(
            output.argumentsProperties[0].required)
        XCTAssertEqual(
            output.argumentsProperties[1].name,
            "maxResults")
        XCTAssertEqual(
            output.argumentsProperties[1].swiftTypeName,
            "Int?")
        XCTAssertFalse(
            output.argumentsProperties[1].required)
    }

    // MARK: - Round-trip

    func testInputCodableRoundTrip() throws {
        let tool = BASTool(
            name: "echo",
            description: "echoes",
            parameters: [
                BASToolParameter(
                    name: "msg",
                    description: "message",
                    type: .string,
                    required: true)
            ])
        let input = BASToolMacroInput(
            tool: tool,
            argumentsTypeName: "EchoArgs",
            toolConformerTypeName: "EchoTool",
            parameterMappings: [.stringToString])

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let decoder = JSONDecoder()
        let data = try encoder.encode(input)
        let decoded = try decoder.decode(
            BASToolMacroInput.self, from: data)
        XCTAssertEqual(decoded, input)
    }
}
