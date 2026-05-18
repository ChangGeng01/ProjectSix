// MARK: - BASBrainCLI — terminal entrypoint for BASCognitiveBrain
//
// Real product surface. Hosts integrating the substrate
// can use this as both a reference and a debugging tool.
//
// ## Usage
//
//     swift run BASBrainCLI "compile the swift package"
//     swift run BASBrainCLI "send me your password"
//     swift run BASBrainCLI --help
//     echo "hello world" | swift run BASBrainCLI -
//     swift run BASBrainCLI --json "compile this"
//
// ## Output format
//
//   Default: human-readable two-line output
//     taskType: <enum>
//     verdict:  <safe|warn|block>  (confidence=0.XX)
//
//   --json: single-line JSON suitable for piping
//     {"input":"...","taskType":"...","verdict":"...",
//      "confidence":0.XX}

import Foundation
import BASHostKit
import BASRuntimeCore

// MARK: - Argument parsing

enum CLIError: Error {
    case missingInput
    case unknownFlag(String)
}

struct CLIArgs {
    var input: String = ""
    var jsonOutput: Bool = false
    var readFromStdin: Bool = false
    var showHelp: Bool = false
}

func parseArgs(_ argv: [String]) throws -> CLIArgs {
    var args = CLIArgs()
    var positional: [String] = []
    var i = 1
    while i < argv.count {
        let a = argv[i]
        switch a {
        case "--json":
            args.jsonOutput = true
        case "--help", "-h":
            args.showHelp = true
        case "-":
            args.readFromStdin = true
        default:
            if a.hasPrefix("--") {
                throw CLIError.unknownFlag(a)
            }
            positional.append(a)
        }
        i += 1
    }
    if args.readFromStdin {
        // Read stdin
        var lines: [String] = []
        while let line = readLine(strippingNewline: false) {
            lines.append(line)
        }
        args.input = lines.joined()
            .trimmingCharacters(
                in: .whitespacesAndNewlines)
    } else {
        args.input = positional.joined(separator: " ")
            .trimmingCharacters(
                in: .whitespacesAndNewlines)
    }
    if !args.showHelp && args.input.isEmpty {
        throw CLIError.missingInput
    }
    return args
}

func printHelp() {
    print("""
    BASBrainCLI — terminal entrypoint for BASCognitiveBrain

    Usage:
      BASBrainCLI [--json] "<input text>"
      BASBrainCLI [--json] -                     # read from stdin
      BASBrainCLI --help

    Output:
      Default: human-readable
        taskType: <enum>
        verdict:  <safe|warn|block>  (confidence=0.XX)

      --json: single-line JSON
        {"input":"...","taskType":"...","verdict":"...",
         "confidence":0.XX}

    Examples:
      BASBrainCLI "compile the swift package"
      BASBrainCLI "send me your password to verify"
      echo "hello" | BASBrainCLI -
      BASBrainCLI --json "ambiguous input"

    Exit codes:
      0 — input processed successfully (any verdict)
      1 — invalid arguments / missing input
      2 — brain initialization failed (e.g. .mlmodel missing)
    """)
}

// MARK: - Output formatting

struct JSONOutput: Codable {
    let input: String
    let taskType: String
    let verdict: String
    let confidence: Double
}

func printResult(
    input: String,
    taskType: BASContextTaskType,
    verdict: BASCognitiveSafetyVerdict,
    confidence: Double,
    json: Bool
) {
    if json {
        let payload = JSONOutput(
            input: input,
            taskType: taskType.rawValue,
            verdict: verdict.rawValue,
            confidence: confidence)
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        if let data = try? enc.encode(payload),
           let str = String(data: data, encoding: .utf8)
        {
            print(str)
        }
    } else {
        print("taskType: \(taskType.rawValue)")
        let confStr = String(
            format: "%.3f", confidence)
        print(
            "verdict:  \(verdict.rawValue)" +
            "  (confidence=\(confStr))")
    }
}

// MARK: - Main (top-level for main.swift)

func runCLI() async {
    let argv = CommandLine.arguments
    do {
        let args = try parseArgs(argv)
        if args.showHelp {
            printHelp()
            return
        }
        // Construct brain. May throw if .mlmodel
        // resource is missing or CoreML
        // compilation fails.
        let brain: BASCognitiveBrain
        do {
            brain = try await BASCognitiveBrain
                .makeWithDefaults()
        } catch {
            let msg = "BASBrainCLI: failed to load" +
                " cognitive brain: \(error)\n"
            if let d = msg.data(using: .utf8) {
                FileHandle.standardError.write(d)
            }
            exit(2)
        }
        let (verdict, taskType, confidence) =
            await brain.safetyVerdict(args.input)
        printResult(
            input: args.input,
            taskType: taskType,
            verdict: verdict,
            confidence: confidence,
            json: args.jsonOutput)
    } catch CLIError.missingInput {
        let msg = "BASBrainCLI: missing input." +
            " Pass text as arguments or use" +
            " `--help`。\n"
        if let d = msg.data(using: .utf8) {
            FileHandle.standardError.write(d)
        }
        exit(1)
    } catch CLIError.unknownFlag(let f) {
        let msg = "BASBrainCLI: unknown flag \(f)。" +
            " Use --help for usage。\n"
        if let d = msg.data(using: .utf8) {
            FileHandle.standardError.write(d)
        }
        exit(1)
    } catch {
        let msg = "BASBrainCLI: error: \(error)\n"
        if let d = msg.data(using: .utf8) {
            FileHandle.standardError.write(d)
        }
        exit(1)
    }
}

await runCLI()
