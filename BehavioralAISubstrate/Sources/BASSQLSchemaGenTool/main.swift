// MARK: - BASSQLSchemaGenTool — main.swift
// chapter 七百二 / M2171 第一刀
//
// Thin executable wrapper around `BASSQLSchemaGenCore`。
// Parses argv,reads input file,calls
// `BASSQLSchemaGenCore.schemaName(fromBaseName:)` to derive
// the enum prefix,calls `BASSQLSchemaGenCore.generateSwift
// (from:schemaName:sourceFileName:)`,writes output file。
//
// All naming + codegen logic lives in the core library so
// tests can validate them without spawning this process。
//
// Argv contract (positional):
//   [1] input  .sql path           (absolute or relative)
//   [2] output .swift path         (created or overwritten)
//   [3] baseName                   (file basename WITHOUT .sql)
//   [4] sourceFileName             (basename WITH .sql,
//                                    for the GENERATED header)
//
// Exit codes:
//   0  success
//   2  wrong argv count
//   3  input file unreadable
//   4  output file write failed

import Foundation
import BASSQLSchemaGenCore

enum BASSQLSchemaGenToolExitCode: Int32 {
    case success = 0
    case wrongArgvCount = 2
    case inputUnreadable = 3
    case outputWriteFailed = 4
}

func main() -> Int32 {
    let args = CommandLine.arguments
    guard args.count == 5 else {
        FileHandle.standardError.write(Data(
            ("BASSQLSchemaGenTool:expected 4 args"
             + " (input、output、baseName、sourceFileName);"
             + "got \(args.count - 1)\n").utf8))
        return BASSQLSchemaGenToolExitCode
            .wrongArgvCount.rawValue
    }
    let inputPath = args[1]
    let outputPath = args[2]
    let baseName = args[3]
    let sourceFileName = args[4]

    let inputURL = URL(fileURLWithPath: inputPath)
    let sqlContent: String
    do {
        sqlContent = try String(
            contentsOf: inputURL, encoding: .utf8)
    } catch {
        FileHandle.standardError.write(Data(
            "BASSQLSchemaGenTool:cannot read \(inputPath):\(error)\n"
                .utf8))
        return BASSQLSchemaGenToolExitCode
            .inputUnreadable.rawValue
    }

    let schemaName = BASSQLSchemaGenCore.schemaName(
        fromBaseName: baseName)
    let generated = BASSQLSchemaGenCore.generateSwift(
        from: sqlContent,
        schemaName: schemaName,
        sourceFileName: sourceFileName)

    let outputURL = URL(fileURLWithPath: outputPath)
    do {
        try generated.write(
            to: outputURL, atomically: true, encoding: .utf8)
    } catch {
        FileHandle.standardError.write(Data(
            "BASSQLSchemaGenTool:cannot write \(outputPath):\(error)\n"
                .utf8))
        return BASSQLSchemaGenToolExitCode
            .outputWriteFailed.rawValue
    }
    return BASSQLSchemaGenToolExitCode.success.rawValue
}

exit(main())
