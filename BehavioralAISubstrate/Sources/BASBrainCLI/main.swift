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

// MARK: - Exit codes (named, not magic)

enum CLIExitCode {
    /// 0 — input processed successfully (any verdict
    ///     unless --fail-on-block was passed)
    static let success: Int32 = 0
    /// 1 — invalid arguments / missing input
    static let invalidArguments: Int32 = 1
    /// 2 — brain initialization failed (e.g. .mlmodel missing)
    static let brainInitFailed: Int32 = 2
    /// 3 — verdict was .block AND --fail-on-block was set
    static let verdictBlocked: Int32 = 3
}

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
    /// Per-invocation safety threshold override
    /// (nil → use brain's default 0.6)。 Clamped to
    /// [0, 1] by the brain。 Useful for CLI users
    /// exploring different sensitivity profiles。
    var safetyThreshold: Double? = nil
    /// When true,exit with code 3 if the verdict is
    /// .block。 Useful in shell pipelines:
    /// `set -e; BASBrainCLI --fail-on-block "..." || handle`
    var failOnBlock: Bool = false
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
        case "--fail-on-block":
            args.failOnBlock = true
        case "--threshold":
            i += 1
            guard i < argv.count else {
                throw CLIError.unknownFlag(
                    "--threshold (missing value)")
            }
            guard let v = Double(argv[i]) else {
                throw CLIError.unknownFlag(
                    "--threshold (invalid number" +
                    " '\(argv[i])')")
            }
            args.safetyThreshold = v
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
      BASBrainCLI [options] "<input text>"
      BASBrainCLI [options] -                    # read from stdin
      BASBrainCLI --help

    Options:
      --json                Single-line JSON output (default
                            human-readable)
      --threshold <value>   Override safety confidence threshold
                            (default 0.6). Range [0, 1] —
                            out-of-range values clamp to the
                            nearest boundary. NaN falls back to
                            the default.
      --fail-on-block       Exit with code 3 if verdict is .block.
                            Useful for shell pipelines that want
                            to halt on detected manipulation.

    Output:
      Default: human-readable
        taskType: <enum>
        verdict:  <safe|warn|block>  (confidence=0.XX)

      --json: single-line JSON
        {"input":"...","taskType":"...","verdict":"...",
         "confidence":0.XX,"latencyNanos":NNN}

    Examples:
      BASBrainCLI "compile the swift package"
      BASBrainCLI "send me your password to verify"
      echo "hello" | BASBrainCLI -
      BASBrainCLI --json "ambiguous input"
      BASBrainCLI --threshold 0.4 "soft manipulation"
      BASBrainCLI --fail-on-block "harmful input" || \\
        echo "blocked"

    Exit codes:
      0 — input processed successfully (any verdict)
      1 — invalid arguments / missing input
      2 — brain initialization failed (e.g. .mlmodel missing)
      3 — verdict was .block AND --fail-on-block was set
    """)
}

// MARK: - Output formatting

struct JSONOutput: Codable {
    let input: String
    let taskType: String
    let verdict: String
    let confidence: Double
    let latencyNanos: UInt64
}

func printResult(
    input: String,
    taskType: BASContextTaskType,
    verdict: BASCognitiveSafetyVerdict,
    confidence: Double,
    latencyNanos: UInt64,
    json: Bool
) {
    if json {
        let payload = JSONOutput(
            input: input,
            taskType: taskType.rawValue,
            verdict: verdict.rawValue,
            confidence: confidence,
            latencyNanos: latencyNanos)
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
        let latencyMs =
            Double(latencyNanos) / 1_000_000.0
        let latencyStr = String(
            format: "%.2f", latencyMs)
        print(
            "verdict:  \(verdict.rawValue)" +
            "  (confidence=\(confStr)," +
            " latency=\(latencyStr)ms)")
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
            if let threshold = args.safetyThreshold {
                brain = try await BASCognitiveBrain
                    .makeWithDefaults(
                        safetyConfidenceThreshold:
                            threshold)
            } else {
                brain = try await BASCognitiveBrain
                    .makeWithDefaults()
            }
        } catch {
            let msg = "BASBrainCLI: failed to load" +
                " cognitive brain: \(error)\n"
            if let d = msg.data(using: .utf8) {
                FileHandle.standardError.write(d)
            }
            exit(CLIExitCode.brainInitFailed)
        }
        // Use brain.summary() to capture latency too
        let summary = await brain.summary(args.input)
        printResult(
            input: args.input,
            taskType: summary.taskType,
            verdict: summary.safetyVerdict,
            confidence: summary.confidence,
            latencyNanos: summary.latencyNanos,
            json: args.jsonOutput)
        // --fail-on-block:exit code 3 when verdict
        // is .block。 Allows shell pipelines to halt
        // on detected manipulation。
        if args.failOnBlock
            && summary.safetyVerdict == .block
        {
            exit(CLIExitCode.verdictBlocked)
        }
    } catch CLIError.missingInput {
        let msg = "BASBrainCLI: missing input." +
            " Pass text as arguments or use" +
            " `--help`。\n"
        if let d = msg.data(using: .utf8) {
            FileHandle.standardError.write(d)
        }
        exit(CLIExitCode.invalidArguments)
    } catch CLIError.unknownFlag(let f) {
        let msg = "BASBrainCLI: unknown flag \(f)。" +
            " Use --help for usage。\n"
        if let d = msg.data(using: .utf8) {
            FileHandle.standardError.write(d)
        }
        exit(CLIExitCode.invalidArguments)
    } catch {
        let msg = "BASBrainCLI: error: \(error)\n"
        if let d = msg.data(using: .utf8) {
            FileHandle.standardError.write(d)
        }
        exit(CLIExitCode.invalidArguments)
    }
}

await runCLI()
