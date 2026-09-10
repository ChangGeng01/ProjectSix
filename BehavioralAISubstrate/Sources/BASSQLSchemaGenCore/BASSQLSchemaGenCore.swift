// MARK: - BASSQLSchemaGenCore
// chapter 七百二 / M2171 — pure-Swift codegen function shared
//                          by `BASSQLSchemaGenTool` (executable)
//                          + `BehavioralAISubstrateTests`。
//
// ## Why a separate library target
//
// The MULTI-LANGUAGE AUGMENTATION ARC plan (chapter 七百一)
// pins the SQL pilot at chapter 七百二 with a build plugin
// that scans target `SQL/` subdirectories and emits one
// `<Name>Schema.generated.swift` per `.sql` file。
//
// Three separation rationales:
//
//   - **Plugin** (`Plugins/BASSQLSchemaGen/Plugin.swift`)
//     declares the build commands and tells SPM which
//     executable to invoke per input file。 The plugin
//     itself runs at build-PLANNING time;the executable
//     runs at build-EXECUTION time per command。
//
//   - **Tool** (`Sources/BASSQLSchemaGenTool/main.swift`)
//     is the executable the plugin invokes。 It takes
//     CLI arguments (input .sql path,output .swift path,
//     schema name) and produces one file。 Thin wrapper:
//     parses argv,reads the SQL file,calls into THIS
//     core library,writes the output file。
//
//   - **Core** (THIS FILE) is a pure function
//     `BASSQLSchemaGenCore.generateSwift(from:schemaName:)`
//     with no I/O。 Lives in its own target so tests can
//     `import BASSQLSchemaGenCore` and assert on the
//     generated string directly,without spawning the
//     tool subprocess。
//
// ## Output contract
//
// For a SQL file containing N statements,emit:
//
//   ```swift
//   // GENERATED — do not edit。 chapter 七百二 / M2171。
//   // Source:<input filename>
//
//   public enum <SchemaName>Schema {
//
//       /// Concatenated SQL of every statement in the input file,
//       /// joined with single newlines。 Preserves statement order
//       /// + comments + indentation。
//       public static let allStatementsSQL: String = """
//           <verbatim file content>
//           """
//
//       /// Number of `;`-terminated statements in the input。
//       public static let statementCount: Int = N
//   }
//   ```
//
// Anti-magic-number doctrine (chapter 一百八十五) honored:
// `statementCount` derives from the input — future readers
// see the count justified by the source。
//
// ## Determinism
//
// `generateSwift` is pure。 Same input → same output bytes。
// Validated by `testTwoInvocationsProduceByteEqualOutput`。
// Critical for the V1 byte-equality invariant (752 clean
// commits at chapter 七百一 close-out)。
//
// ## Doctrine pins
//
//   - 不变量 #1 / #2 / #3 — codegen is observability:produces
//     STRING constants,never mutates host state,never
//     short-circuits permits or watcher gates。
//   - 红线 7 — codegen is build-time scaffolding;runtime
//     consumers (e.g.,BASMemoryUsageTracker)switch between
//     the inline string + the generated enum by feature flag
//     (`BASLanguageAugmentationFeatureFlags.sqlMigrator
//     Enabled`),so default behavior is the V1 inline path。
//   - chapter 477 ADR-014 OPT-IN — codegen is purely additive
//     (the .generated.swift is a NEW typed surface;no V1 file
//     is replaced or deleted until the consumer wires the
//     enum,which happens at M2173 第三刀 behind the
//     `sqlMigratorEnabled` feature flag)。

import Foundation

/// Public namespace for the SQL → Swift schema codegen
/// function。 No actor;codegen is a pure function with
/// no shared state。
public enum BASSQLSchemaGenCore {

    /// Generate one Swift source file content from one
    /// SQL file content。
    ///
    /// - Parameters:
    ///   - sqlContent:UTF-8 verbatim contents of the
    ///     `.sql` file (preserves whitespace + comments)。
    ///   - schemaName:CamelCase identifier used as the
    ///     enum prefix。 Caller-supplied so two `.sql`
    ///     files with conflicting basenames in different
    ///     targets cannot collide。
    ///   - sourceFileName:basename (no path) of the input
    ///     file。 Emitted as a comment header so a reader
    ///     can trace the generated file back to its
    ///     source。
    ///
    /// - Returns:UTF-8 Swift source code as a String。
    ///   Always ends with a single trailing newline (one
    ///   of the rare Swift conventions that affects diff
    ///   noise across editors)。
    ///
    /// - Discussion:**Pure function**。 No file I/O,no
    ///   environment access,no current-date stamping。
    ///   Two calls with the same arguments produce
    ///   byte-identical output。 This is what lets the
    ///   M2173 byte-equality test prove the generated
    ///   `allStatementsSQL` matches the inline literal
    ///   in `BASMemoryUsageTracker.swift`。
    public static func generateSwift(
        from sqlContent: String,
        schemaName: String,
        sourceFileName: String
    ) -> String {
        let stmtCount = countStatements(in: sqlContent)
        var output = ""
        output += "// GENERATED — do not edit。"
        output += " chapter 七百二 / M2171。\n"
        output += "// Source:\(sourceFileName)\n"
        output += "\n"
        output += "public enum \(schemaName)Schema {\n"
        output += "\n"
        output += "    /// Concatenated SQL of every statement in"
        output += " the input file,joined verbatim。\n"
        output += "    public static let allStatementsSQL:"
        output += " String = \"\"\"\n"
        // Each line of SQL gets a 4-space indent matching the
        // triple-quoted string convention。 Trailing newlines
        // in input collapse to a single newline before the
        // closing `"""`。
        let lines = sqlContent
            .split(separator: "\n", omittingEmptySubsequences: false)
        for line in lines {
            output += "    \(line)\n"
        }
        output += "    \"\"\"\n"
        output += "\n"
        output += "    /// Number of `;`-terminated statements in"
        output += " the input。\n"
        output += "    public static let statementCount:"
        output += " Int = \(stmtCount)\n"
        output += "}\n"
        return output
    }

    /// Count `;`-terminated statements。 Conservative
    /// approximation:counts unescaped `;` characters
    /// outside of `--` line comments + `/* */` block
    /// comments。
    ///
    /// **Limitations**:does not handle `;` inside string
    /// literals。 For the M2171 SQL pilot scope (DDL only:
    /// CREATE TABLE / CREATE INDEX with no string literals)
    /// this is sufficient。 Future pilots that need DML
    /// with string literals should extend the parser。
    public static func countStatements(in sqlContent: String) -> Int {
        var count = 0
        var inLineComment = false
        var inBlockComment = false
        let chars = Array(sqlContent)
        var index = 0
        while index < chars.count {
            let c = chars[index]
            if inLineComment {
                if c == "\n" { inLineComment = false }
                index += 1
                continue
            }
            if inBlockComment {
                if c == "*",
                   index + 1 < chars.count,
                   chars[index + 1] == "/" {
                    inBlockComment = false
                    index += 2
                    continue
                }
                index += 1
                continue
            }
            if c == "-",
               index + 1 < chars.count,
               chars[index + 1] == "-" {
                inLineComment = true
                index += 2
                continue
            }
            if c == "/",
               index + 1 < chars.count,
               chars[index + 1] == "*" {
                inBlockComment = true
                index += 2
                continue
            }
            if c == ";" { count += 1 }
            index += 1
        }
        return count
    }

    /// Derivation pin:codegen contract version。 Bumping
    /// this constant signals a generated-file format
    /// change that consumers (or downstream byte-equality
    /// tests) need to re-validate。
    public static let codegenContractVersion: Int = 1

    /// Sentinel header prefix every generated file carries。
    /// Tests pin on this so a regression that drops the
    /// "GENERATED" warning header is caught immediately。
    public static let generatedHeaderPrefix: String =
        "// GENERATED — do not edit。"

    /// Derive a CamelCase schema name from a SQL file's
    /// basename (without the `.sql` extension)。
    ///
    /// Convention:`<digits>_<lowercase_underscore_name>`
    /// → `CamelCaseName`。
    ///
    /// Examples:
    ///   - `001_memory_usage_records` → `MemoryUsageRecords`
    ///   - `42_atom_store` → `AtomStore`
    ///   - `policy_catalog` → `PolicyCatalog`
    ///   - `0001_x` → `X`
    ///   - empty / all-strippable → `"Schema"` fallback
    ///
    /// Pure function。 Lives in the core library so the
    /// plugin's behavior is independently testable
    /// without spawning the plugin。
    public static func schemaName(
        fromBaseName baseName: String
    ) -> String {
        var stripped = baseName
        var prefixEnd = stripped.startIndex
        while prefixEnd < stripped.endIndex,
              stripped[prefixEnd].isNumber {
            prefixEnd = stripped.index(after: prefixEnd)
        }
        if prefixEnd < stripped.endIndex,
           stripped[prefixEnd] == "_",
           prefixEnd != stripped.startIndex {
            stripped = String(stripped[
                stripped.index(after: prefixEnd)...])
        }
        let parts = stripped.split(separator: "_")
        var camel = ""
        for part in parts {
            guard let first = part.first else { continue }
            camel += String(first).uppercased()
                + part.dropFirst()
        }
        return camel.isEmpty ? "Schema" : camel
    }
}
