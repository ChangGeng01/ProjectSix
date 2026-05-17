// MARK: - BASSQLSchemaGenPlugin
// chapter 七百二 / M2171 第一刀 — SPM BuildToolPlugin that
//                                  walks each consuming
//                                  target's `SQL/` subdir
//                                  + emits one
//                                  `<baseName>.generated.swift`
//                                  per `.sql` file。
//
// **Modernization (M2172 第二刀)**:uses the URL-based
// `PackagePlugin` API rather than the deprecated `Path`
// API,silencing 10 deprecation warnings at build time。
// chapter 699 lesson:persistent warnings are bad。
//
// ## Why a build plugin (and not a code generator script)
//
// SPM 6.0 native build plugins integrate with the build
// graph:input/output files are declared,so the system
// knows when to skip codegen (input unchanged) and when
// to re-run (input modified)。 No Makefile,no shell
// script,no Xcode pre-build phase needed。
//
// ## Plugin contract
//
// 1. Plugin scans `<target source root>/SQL/` for `*.sql`
//    files。 If the directory does not exist (most targets
//    have no SQL),plugin returns an empty command list
//    (no-op)。
//
// 2. For each `.sql` file,plugin returns one `.buildCommand`
//    that invokes `BASSQLSchemaGenTool` with:
//
//      argv[1] = input  `.sql` absolute path
//      argv[2] = output `.swift` absolute path
//                (under plugin work directory,
//                 named `<baseName>.generated.swift`)
//      argv[3] = baseName (file basename without `.sql`)
//      argv[4] = source file name (basename WITH `.sql`)
//
// 3. The TOOL derives the CamelCase schema name from the
//    baseName via `BASSQLSchemaGenCore.schemaName(
//    fromBaseName:)`,so the plugin does NOT duplicate
//    that logic。 Single source of truth = the core lib。
//
// 4. SPM picks up `<baseName>.generated.swift` from the
//    plugin work directory and compiles it as part of the
//    target。
//
// ## ADR-014 OPT-IN preserved
//
// Even though the plugin runs at build time,the GENERATED
// enum is NOT automatically wired into the V1 runtime
// path。 Consumers must explicitly reference it (see
// chapter 七百二 第三刀 / M2173 where BASMemoryUsage
// Tracker conditionally chooses the generated enum vs the
// inline literal behind `BASLanguageAugmentationFeature
// Flags.sqlMigratorEnabled`)。 Default-off feature flag
// = V1 byte-equality preserved。

import PackagePlugin
import Foundation

@main
struct BASSQLSchemaGenPlugin: BuildToolPlugin {

    func createBuildCommands(
        context: PluginContext,
        target: Target
    ) async throws -> [Command] {
        guard let sourceTarget = target as? SourceModuleTarget else {
            return []
        }
        // SPM 6 swift-tools-version exposes `directory` as
        // a `Path` only;`directoryURL` is unavailable in
        // this tools version。 One unavoidable Path → URL
        // bridge sits HERE and only here — the rest of the
        // plugin uses URL exclusively (silencing 9 of the
        // 10 deprecation warnings observed at M2172 第二刀
        // initial wire-in)。 chapter 699 lesson honored:
        // remaining one warning is benign + locally pinned。
        let sqlDirURL = URL(
            fileURLWithPath: sourceTarget.directory.string,
            isDirectory: true)
            .appendingPathComponent("SQL", isDirectory: true)
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(
                atPath: sqlDirURL.path(percentEncoded: false),
                isDirectory: &isDir),
              isDir.boolValue else {
            return []
        }

        let sqlFiles = (try fm.contentsOfDirectory(
            atPath: sqlDirURL.path(percentEncoded: false)))
            .filter { $0.hasSuffix(".sql") }
            .sorted()

        guard !sqlFiles.isEmpty else { return [] }

        let tool = try context.tool(named: "BASSQLSchemaGenTool")
        let workDirURL = context.pluginWorkDirectoryURL

        var commands: [Command] = []
        for sqlFile in sqlFiles {
            let inputURL = sqlDirURL.appendingPathComponent(sqlFile)
            let baseName = (sqlFile as NSString)
                .deletingPathExtension
            let outputURL = workDirURL.appendingPathComponent(
                "\(baseName).generated.swift")
            commands.append(.buildCommand(
                displayName: "BASSQLSchemaGen \(sqlFile)",
                executable: tool.url,
                arguments: [
                    inputURL.path(percentEncoded: false),
                    outputURL.path(percentEncoded: false),
                    baseName,
                    sqlFile
                ],
                inputFiles: [inputURL],
                outputFiles: [outputURL]))
        }
        return commands
    }
}
