// MARK: - BASToolMacroSchema — chapter 四百 / M919
//
// G6 收尾 step 2:typed schema for the future Swift macro that
// generates `FoundationModels.Tool` compile-time conformers
// from `BASTool` runtime values。Pre-M919 the M916 bridge had
// `.compiledGenerable` listed as a strategy with NO typed
// description of what the macro input/output should look like。
// Post-M919 the contract is pinned:macro author reads this,
// emits matching code,driver tests assert against the schema。
//
// ## Why a typed schema for an unwritten macro
//
// Same reasoning as M917 + M918:external work (here, Swift
// macro authoring) needs a typed substrate-side contract OR
// the macro author guesses what to emit。With a contract:
//   - macro reads BASTool runtime values + this schema
//   - emits matching `Generable` Arguments struct + `Tool`
//     conformer per tool
//   - substrate-side tests assert the EMITTED code conforms
//     to the schema (without invoking the iOS 26 SDK)
// Without:
//   - macro emits whatever the author dreamed up
//   - schema drift between macro output + substrate
//     expectations is a runtime crash
//
// ## What this ships (M919)
//
//   - `BASToolMacroInput` typed Codable struct: caller-side
//     description of what the macro receives (the BASTool
//     value + target Generable type name + typed parameter
//     mapping rules)
//   - `BASToolMacroParameterMapping` typed enum: how each
//     `BASToolParameterType` maps to a Generable property
//     type (`.string` → `String`, `.integer` → `Int`, etc.)
//   - `BASToolMacroOutput` typed Codable struct: expected
//     emitted code shape (Arguments struct properties +
//     Tool conformer method signature)
//   - `BASToolMacroSchema.expectedArgumentsPropertyName(for:)`
//     pure function: given a BASToolParameter, returns the
//     canonical Swift property name (snake_case → camelCase
//     translation, reserved-word handling)
//   - `BASToolMacroSchema.swiftTypeName(for:)` pure function:
//     maps `BASToolParameterType` to the Swift type name the
//     macro should emit
//
// ## What this does NOT ship
//
//   - The macro itself (genuine external work — needs
//     swift-syntax + macro target setup)
//   - Code that COMPILES the emitted Generable Tool
//     conformer (that's the macro's job)
//   - Runtime invocation of the emitted Tool (M916 bridge
//     handles that once the SDK is GA)
//
// ## Doctrine pins held
//
// - chapter 二百一一 single-source-of-truth — ONE typed
//   contract, macro author + substrate tests both consume it
// - chapter 一百八十五 anti-magic-number — type name strings
//   pinned as static constants
// - chapter 三百九二 (M892) replay determinism — same
//   BASTool input → same emitted code (no random naming)
// - ADR-014 OPT-IN — schema is queried only when the macro
//   strategy is selected;`.runtimeSchema` and `.audit`
//   strategies bypass it

import Foundation
import BASRuntimeCore

// MARK: - Parameter mapping

/// Typed mapping from a `BASToolParameterType` to the Swift
/// type the macro should emit。Generable requires concrete
/// Swift types — this enum pins the canonical mapping。
public enum BASToolMacroParameterMapping:
    String, Codable, Equatable, Sendable, Hashable, CaseIterable
{
    /// `.string` → `String`
    case stringToString = "string→String"
    /// `.integer` → `Int`
    case integerToInt = "integer→Int"
    /// `.number` → `Double`
    case numberToDouble = "number→Double"
    /// `.boolean` → `Bool`
    case booleanToBool = "boolean→Bool"
    /// `.array` → `[String]` (homogeneous string elements;
    /// nested arrays not supported in the v1 macro)
    case arrayToStringArray = "array→[String]"
    /// `.object` → `[String: String]` (string-keyed map;
    /// nested objects not supported in the v1 macro)
    case objectToStringDict = "object→[String:String]"
    /// `.any` → `String` (wide degenerate fallback;caller
    /// JSON-encodes whatever shape they want)
    case anyToString = "any→String"
}

// MARK: - Macro input

/// Typed Codable description of one macro invocation。Macro
/// author's tool reads this from a sidecar file (or in-source
/// `@BASGenerableTool(...)` attribute payload) + emits the
/// matching code。
public struct BASToolMacroInput:
    Codable, Equatable, Sendable
{
    /// The source `BASTool` value the macro is converting。
    public let tool: BASTool

    /// Target Swift type name for the generated Generable
    /// Arguments struct。Convention:
    /// `<ToolName>Arguments`(camelCased,reserved-word-safe)。
    /// Macro author overrides via the schema's typed helpers。
    public let argumentsTypeName: String

    /// Target Swift type name for the generated Tool
    /// conformer struct。Convention:
    /// `<ToolName>FoundationModelsTool`。
    public let toolConformerTypeName: String

    /// Per-parameter mapping decisions。Macro reads this to
    /// emit each property's type。Order matches
    /// `tool.parameters`。
    public let parameterMappings:
        [BASToolMacroParameterMapping]

    public init(
        tool: BASTool,
        argumentsTypeName: String,
        toolConformerTypeName: String,
        parameterMappings:
            [BASToolMacroParameterMapping]
    ) {
        precondition(
            parameterMappings.count
                == tool.parameters.count,
            "parameterMappings.count must match " +
            "tool.parameters.count")
        self.tool = tool
        self.argumentsTypeName = argumentsTypeName
        self.toolConformerTypeName = toolConformerTypeName
        self.parameterMappings = parameterMappings
    }
}

// MARK: - Macro output

/// Typed Codable description of the expected emitted code
/// shape。Substrate tests assert macro output conforms to
/// this without compiling the actual emitted code。
public struct BASToolMacroOutput:
    Codable, Equatable, Sendable, Hashable
{
    /// Generated Arguments struct property descriptors。Each
    /// element pairs the property name with its Swift type
    /// name + whether it's required (= non-Optional)。
    public let argumentsProperties: [Property]

    public struct Property:
        Codable, Equatable, Sendable, Hashable
    {
        public let name: String
        public let swiftTypeName: String
        public let required: Bool

        public init(
            name: String,
            swiftTypeName: String,
            required: Bool
        ) {
            self.name = name
            self.swiftTypeName = swiftTypeName
            self.required = required
        }
    }

    /// Expected method signature of the Tool conformer's
    /// `call(arguments:)` method。Pinned for cross-version
    /// stability — if Apple bumps the signature in iOS 27,
    /// this string changes + macro re-runs。
    public let callMethodSignature: String

    public init(
        argumentsProperties: [Property],
        callMethodSignature: String
    ) {
        self.argumentsProperties = argumentsProperties
        self.callMethodSignature = callMethodSignature
    }
}

// MARK: - Schema namespace

/// Substrate-side typed namespace pinning the macro contract。
/// Pure functions over Codable values。
public enum BASToolMacroSchema {

    /// Schema version。Bumped when ANY field shape in
    /// `BASToolMacroInput` / `BASToolMacroOutput` /
    /// `BASToolMacroParameterMapping` changes。
    public static let schemaVersion: String = "M919.1.0.0"

    /// Pinned `call(arguments:)` signature for iOS 26
    /// FoundationModels.Tool。Bumping requires migration of
    /// every emitted Tool conformer。
    public static let canonicalCallMethodSignature: String =
        "func call(arguments: Arguments) async throws " +
        "-> ToolOutput"

    /// chapter 一百八十五:Swift reserved words that need
    /// backtick-escaping if emitted as property names。
    /// Subset relevant to typical tool parameters。
    private static let swiftReservedWords: Set<String> = [
        "class", "struct", "enum", "protocol", "func",
        "var", "let", "if", "else", "for", "while",
        "switch", "case", "default", "return", "break",
        "continue", "true", "false", "nil", "self",
        "Self", "init", "deinit", "import", "associatedtype",
        "static", "final", "lazy", "weak", "unowned",
        "private", "public", "internal", "fileprivate",
        "open", "as", "is", "in", "throw", "throws",
        "rethrows", "try", "catch", "do", "where",
        "Type", "Any", "AnyObject", "guard", "defer",
        "operator", "subscript", "typealias", "extension",
        "inout", "indirect", "associatedtype",
    ]

    /// Map a `BASToolParameterType` to the canonical Swift
    /// type name the macro emits。Pure。
    public static func swiftTypeName(
        for type: BASToolParameterType,
        required: Bool
    ) -> String {
        let base: String
        switch type {
        case .string:
            base = "String"
        case .integer:
            base = "Int"
        case .number:
            base = "Double"
        case .boolean:
            base = "Bool"
        case .array:
            base = "[String]"
        case .object:
            base = "[String: String]"
        case .any:
            base = "String"
        }
        return required ? base : "\(base)?"
    }

    /// Map a `BASToolParameterType` to the typed enum
    /// `BASToolMacroParameterMapping` case。Pure。
    public static func mapping(
        for type: BASToolParameterType
    ) -> BASToolMacroParameterMapping {
        switch type {
        case .string: return .stringToString
        case .integer: return .integerToInt
        case .number: return .numberToDouble
        case .boolean: return .booleanToBool
        case .array: return .arrayToStringArray
        case .object: return .objectToStringDict
        case .any: return .anyToString
        }
    }

    /// Convert a snake_case or kebab-case parameter name into
    /// camelCase for use as a Swift property name。
    /// Reserved-word collisions get a trailing `Value`
    /// suffix (e.g. `class` → `classValue`)。Pure。
    public static func expectedArgumentsPropertyName(
        for parameter: BASToolParameter
    ) -> String {
        let raw = parameter.name
            .trimmingCharacters(
                in: .whitespacesAndNewlines)
        if raw.isEmpty {
            return "unnamed"
        }
        // Split on `_` or `-`,camelCase the parts
        let separated = raw.replacingOccurrences(
            of: "-", with: "_")
        let parts = separated.split(separator: "_")
            .map(String.init)
        guard let first = parts.first else {
            return "unnamed"
        }
        let head = first.lowercased()
        let tail = parts.dropFirst().map { part -> String in
            guard let firstChar = part.first else {
                return ""
            }
            return firstChar.uppercased()
                + part.dropFirst().lowercased()
        }
        let camel = ([head] + tail).joined()
        // Reserved-word handling
        if swiftReservedWords.contains(camel) {
            return camel + "Value"
        }
        return camel
    }

    /// Build the expected `BASToolMacroOutput` for a given
    /// `BASToolMacroInput`。Drivers + tests use this as the
    /// reference output the macro must produce。
    public static func expectedOutput(
        for input: BASToolMacroInput
    ) -> BASToolMacroOutput {
        let properties: [BASToolMacroOutput.Property] =
            input.tool.parameters.map { param in
                BASToolMacroOutput.Property(
                    name: expectedArgumentsPropertyName(
                        for: param),
                    swiftTypeName: swiftTypeName(
                        for: param.type,
                        required: param.required),
                    required: param.required)
            }
        return BASToolMacroOutput(
            argumentsProperties: properties,
            callMethodSignature:
                canonicalCallMethodSignature)
    }
}
