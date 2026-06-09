import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Translates a BAS `BASGuidedGenerationSchema` (a JSON-Schema fragment string) into Apple FoundationModels'
/// runtime `GenerationSchema`, for NATIVE guided/structured output on iOS 26+.
///
/// Structured output is **side-effect-free** (pure constrained generation), so — unlike tool execution — it
/// does NOT touch the ADR-039 byte-deterministic governance wall. That is why it can be wired natively now,
/// independently of the tool-calling question.
///
/// Two layers, split for testability:
///   - `parse(propertiesJSON:schemaName:)` is PURE (no FoundationModels) → an intermediate `ParsedGuidedSchema`,
///     unit-testable on any host (the macOS test host can't construct real FoundationModels schema objects).
///   - `makeGenerationSchema(from:)` (iOS 26 gated) builds the real `GenerationSchema`.
///
/// CONSERVATIVE by design: only the common JSON-Schema shapes are mapped — an `object` with `string` /
/// `integer` / `number` / `boolean` properties, plus one-level `array`s of those, honoring `required`.
/// Anything else (nested objects, `anyOf`, `$ref`, an empty `{}`) returns `nil`, and the caller FALLS BACK to
/// plain generation + the audit trace. It never drops a field silently and never crashes on a malformed schema.
public enum BASGuidedSchemaTranslator {

    public indirect enum Kind: Equatable, Sendable {
        case string, integer, number, boolean
        case array(of: Kind)
    }

    public struct Property: Equatable, Sendable {
        public let name: String
        public let kind: Kind
        public let description: String?
        public let optional: Bool
    }

    public struct ParsedGuidedSchema: Equatable, Sendable {
        public let name: String
        public let properties: [Property]
    }

    /// PURE parse. Returns `nil` when the schema is not a mappable object-with-primitive(+array)-properties
    /// (the caller then falls back to plain generation). Deterministic: properties are sorted by key.
    public static func parse(propertiesJSON: String, schemaName: String) -> ParsedGuidedSchema? {
        guard let data = propertiesJSON.data(using: .utf8),
              let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        else { return nil }
        // If a top-level "type" is present it must be "object"; an explicit non-object is unmappable.
        if let type = obj["type"] as? String, type != "object" { return nil }
        guard let props = obj["properties"] as? [String: Any], !props.isEmpty else { return nil }
        let required = Set((obj["required"] as? [String]) ?? [])

        var parsed: [Property] = []
        for key in props.keys.sorted() {
            guard let spec = props[key] as? [String: Any],
                  let kind = parseKind(spec)
            else { return nil }   // any unmappable field ⇒ whole-schema fallback (never a silent partial map)
            parsed.append(Property(
                name: key,
                kind: kind,
                description: spec["description"] as? String,
                optional: !required.contains(key)))
        }
        let name = schemaName.isEmpty ? "output" : schemaName
        return ParsedGuidedSchema(name: name, properties: parsed)
    }

    private static func parseKind(_ spec: [String: Any]) -> Kind? {
        guard let type = spec["type"] as? String else { return nil }
        switch type {
        case "string":  return .string
        case "integer": return .integer
        case "number":  return .number
        case "boolean": return .boolean
        case "array":
            guard let items = spec["items"] as? [String: Any],
                  let itemKind = parseKind(items),
                  !isArray(itemKind)   // only arrays of primitives (one level deep)
            else { return nil }
            return .array(of: itemKind)
        default:
            return nil   // "object" / unknown ⇒ unmappable
        }
    }

    private static func isArray(_ kind: Kind) -> Bool {
        if case .array = kind { return true }
        return false
    }

    #if canImport(FoundationModels)
    @available(iOS 26, macOS 26, visionOS 26, *)
    public static func makeGenerationSchema(from parsed: ParsedGuidedSchema) throws -> GenerationSchema {
        let properties = parsed.properties.map { p in
            DynamicGenerationSchema.Property(
                name: p.name,
                description: p.description,
                schema: leafSchema(p.kind),
                isOptional: p.optional)
        }
        let root = DynamicGenerationSchema(name: parsed.name, properties: properties)
        return try GenerationSchema(root: root, dependencies: [])
    }

    @available(iOS 26, macOS 26, visionOS 26, *)
    private static func leafSchema(_ kind: Kind) -> DynamicGenerationSchema {
        switch kind {
        case .string:  return DynamicGenerationSchema(type: String.self)
        case .integer: return DynamicGenerationSchema(type: Int.self)
        case .number:  return DynamicGenerationSchema(type: Double.self)
        case .boolean: return DynamicGenerationSchema(type: Bool.self)
        case .array(let of): return DynamicGenerationSchema(arrayOf: leafSchema(of))
        }
    }
    #endif
}
