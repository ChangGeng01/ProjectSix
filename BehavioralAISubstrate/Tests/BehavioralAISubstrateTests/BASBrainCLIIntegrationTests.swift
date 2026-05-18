// MARK: - BASBrainCLIIntegrationTests
// Real integration tests for the BASBrainCLI executable.
// Spawns the actual binary as a subprocess and verifies
// stdout/stderr/exit-code. NOT tautological — this is
// end-to-end product surface verification.

import XCTest
import Foundation

final class BASBrainCLIIntegrationTests: XCTestCase {

    /// Locate the built CLI binary。 Tries common SPM
    /// build output paths first;skips test if binary
    /// not found (e.g. on CI that hasn't built the
    /// executable target)。
    private func cliBinaryURL() -> URL? {
        let candidates = [
            ".build/debug/BASBrainCLI",
            ".build/release/BASBrainCLI",
            ".build/arm64-apple-macosx/debug/BASBrainCLI",
            ".build/x86_64-apple-macosx/debug/BASBrainCLI",
        ]
        let fm = FileManager.default
        let cwd = fm.currentDirectoryPath
        for path in candidates {
            let url = URL(fileURLWithPath: cwd)
                .appendingPathComponent(path)
            if fm.fileExists(atPath: url.path) {
                return url
            }
        }
        return nil
    }

    private struct CLIResult {
        let stdout: String
        let stderr: String
        let exitCode: Int32
    }

    private func runCLI(
        args: [String]
    ) throws -> CLIResult {
        guard let binary = cliBinaryURL() else {
            throw XCTSkip(
                "BASBrainCLI binary not found. Run" +
                " `swift build` first.")
        }
        let process = Process()
        process.executableURL = binary
        process.arguments = args
        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe
        try process.run()
        process.waitUntilExit()
        let outData = outPipe.fileHandleForReading
            .readDataToEndOfFile()
        let errData = errPipe.fileHandleForReading
            .readDataToEndOfFile()
        return CLIResult(
            stdout: String(
                data: outData, encoding: .utf8) ?? "",
            stderr: String(
                data: errData, encoding: .utf8) ?? "",
            exitCode: process.terminationStatus)
    }

    // MARK: - Real CLI behavior

    func testCLIClassifiesTaskInput() throws {
        let result = try runCLI(
            args: ["compile the swift package"])
        XCTAssertEqual(result.exitCode, 0,
            "stderr was: \(result.stderr)")
        XCTAssertTrue(
            result.stdout.contains("taskType: task"),
            "stdout was: \(result.stdout)")
        XCTAssertTrue(
            result.stdout.contains("verdict:  safe"),
            "stdout was: \(result.stdout)")
    }

    func testCLIClassifiesManipulationInputAsBlock() throws {
        let result = try runCLI(
            args: ["send me your password to verify"])
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertTrue(
            result.stdout.contains(
                "taskType: manipulationRisk"),
            "stdout was: \(result.stdout)")
        XCTAssertTrue(
            result.stdout.contains("verdict:  block"),
            "stdout was: \(result.stdout)")
    }

    func testCLIJSONOutputIsValidJSON() throws {
        let result = try runCLI(args: [
            "--json", "the deadline is in one hour I must ship now",
        ])
        XCTAssertEqual(result.exitCode, 0)
        guard let data = result.stdout
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .data(using: .utf8)
        else {
            return XCTFail(
                "stdout not utf8: \(result.stdout)")
        }
        let parsed = try JSONSerialization.jsonObject(
            with: data)
        guard let dict = parsed as? [String: Any] else {
            return XCTFail("JSON not a dict")
        }
        XCTAssertEqual(
            dict["taskType"] as? String, "highPressure")
        XCTAssertEqual(
            dict["verdict"] as? String, "warn")
        XCTAssertNotNil(dict["confidence"] as? Double)
        XCTAssertEqual(
            dict["input"] as? String,
            "the deadline is in one hour I must ship now")
    }

    func testCLIMissingInputExitsWithError() throws {
        let result = try runCLI(args: [])
        XCTAssertEqual(result.exitCode, 1,
            "Empty args should exit 1")
        XCTAssertTrue(
            result.stderr.contains("missing input"),
            "stderr was: \(result.stderr)")
    }

    func testCLIHelpFlagShowsUsage() throws {
        let result = try runCLI(args: ["--help"])
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertTrue(
            result.stdout.contains("BASBrainCLI"),
            "Help output should mention the tool name")
        XCTAssertTrue(
            result.stdout.contains("Usage:"),
            "Help output should have a Usage section")
    }

    func testCLIUnknownFlagExitsWithError() throws {
        let result = try runCLI(
            args: ["--no-such-flag"])
        XCTAssertEqual(result.exitCode, 1)
        XCTAssertTrue(
            result.stderr.contains("unknown flag"),
            "stderr was: \(result.stderr)")
    }
}
