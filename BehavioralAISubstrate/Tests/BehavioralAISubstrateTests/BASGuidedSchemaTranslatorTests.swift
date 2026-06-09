import XCTest
@testable import BASAppleAdapters

/// #1 (structured output) — the PURE JSON-Schema → intermediate mapping for native FoundationModels guided
/// generation. Host-testable with NO FoundationModels dependency (the real `GenerationSchema` build is iOS-26
/// gated + on-device-only). The contract: map the common shapes deterministically; return nil (→ caller falls
/// back to plain generation + audit) for anything unmappable, never crash, never silently partial-map.
final class BASGuidedSchemaTranslatorTests: XCTestCase {

    private typealias T = BASGuidedSchemaTranslator

    func testMapsObjectWithPrimitivesAndRespectsRequired() {
        let json = """
        {"type":"object",
         "properties":{
           "title":{"type":"string","description":"the title"},
           "count":{"type":"integer"},
           "score":{"type":"number"},
           "done":{"type":"boolean"}},
         "required":["title","count"]}
        """
        let parsed = T.parse(propertiesJSON: json, schemaName: "extracted_event")
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.name, "extracted_event")
        // Deterministic sorted-by-key order: count, done, score, title.
        XCTAssertEqual(parsed?.properties.map(\.name), ["count", "done", "score", "title"])
        XCTAssertEqual(parsed?.properties.first(where: { $0.name == "title" })?.kind, .string)
        XCTAssertEqual(parsed?.properties.first(where: { $0.name == "count" })?.kind, .integer)
        XCTAssertEqual(parsed?.properties.first(where: { $0.name == "score" })?.kind, .number)
        XCTAssertEqual(parsed?.properties.first(where: { $0.name == "done" })?.kind, .boolean)
        XCTAssertEqual(parsed?.properties.first(where: { $0.name == "title" })?.description, "the title")
        // required → not optional; absent from required → optional.
        XCTAssertEqual(parsed?.properties.first(where: { $0.name == "title" })?.optional, false)
        XCTAssertEqual(parsed?.properties.first(where: { $0.name == "count" })?.optional, false)
        XCTAssertEqual(parsed?.properties.first(where: { $0.name == "score" })?.optional, true)
        XCTAssertEqual(parsed?.properties.first(where: { $0.name == "done" })?.optional, true)
    }

    func testMapsArrayOfPrimitives() {
        let json = """
        {"type":"object","properties":{"tags":{"type":"array","items":{"type":"string"}}}}
        """
        let parsed = T.parse(propertiesJSON: json, schemaName: "s")
        XCTAssertEqual(parsed?.properties.first?.kind, .array(of: .string))
    }

    func testEmptyObjectIsUnmappable() {
        XCTAssertNil(T.parse(propertiesJSON: "{}", schemaName: "s"),
            "an empty schema carries no constraints → fall back to plain generation, not an empty schema")
    }

    func testNonObjectTypeIsUnmappable() {
        XCTAssertNil(T.parse(propertiesJSON: "{\"type\":\"string\"}", schemaName: "s"))
    }

    func testNestedObjectPropertyForcesWholeSchemaFallback() {
        // A property we can't map (nested object) must reject the WHOLE schema — never silently drop the field.
        let json = """
        {"type":"object","properties":{
           "ok":{"type":"string"},
           "nested":{"type":"object","properties":{"x":{"type":"string"}}}}}
        """
        XCTAssertNil(T.parse(propertiesJSON: json, schemaName: "s"))
    }

    func testArrayOfObjectsIsUnmappable() {
        let json = """
        {"type":"object","properties":{"items":{"type":"array","items":{"type":"object"}}}}
        """
        XCTAssertNil(T.parse(propertiesJSON: json, schemaName: "s"))
    }

    func testMalformedJSONReturnsNilNotCrash() {
        XCTAssertNil(T.parse(propertiesJSON: "{not json", schemaName: "s"))
        XCTAssertNil(T.parse(propertiesJSON: "", schemaName: "s"))
    }

    func testEmptySchemaNameDefaultsToOutput() {
        let json = "{\"type\":\"object\",\"properties\":{\"a\":{\"type\":\"string\"}}}"
        XCTAssertEqual(T.parse(propertiesJSON: json, schemaName: "")?.name, "output")
    }
}
