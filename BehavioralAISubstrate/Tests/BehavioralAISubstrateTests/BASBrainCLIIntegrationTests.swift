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
        XCTAssertTrue(
            result.stdout.contains("latency="),
            "stdout must include latency (C pilot): " +
            "\(result.stdout)")
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
        // C pilot latency must be present + positive
        if let latency = dict["latencyNanos"] as? UInt64 {
            XCTAssertGreaterThan(latency, 0,
                "latencyNanos must be > 0 (C pilot)")
        } else if let latency =
            dict["latencyNanos"] as? Int
        {
            XCTAssertGreaterThan(latency, 0,
                "latencyNanos must be > 0 (C pilot)")
        } else {
            XCTFail(
                "latencyNanos field missing or wrong type" +
                " in JSON output: \(dict)")
        }
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

    // MARK: - --threshold + --fail-on-block

    func testCLIThresholdFlagAcceptsValidValue() throws {
        let result = try runCLI(args: [
            "--threshold", "0.5",
            "hello",
        ])
        XCTAssertEqual(result.exitCode, 0,
            "Valid --threshold should succeed:" +
            " \(result.stderr)")
    }

    func testCLIThresholdFlagMissingValueErrors() throws {
        let result = try runCLI(args: [
            "--threshold",
        ])
        XCTAssertEqual(result.exitCode, 1,
            "--threshold with no value must exit 1")
        XCTAssertTrue(
            result.stderr.contains("threshold")
                || result.stderr.contains("unknown"),
            "stderr was: \(result.stderr)")
    }

    func testCLIThresholdFlagInvalidNumberErrors() throws {
        let result = try runCLI(args: [
            "--threshold", "not-a-number",
            "hello",
        ])
        XCTAssertEqual(result.exitCode, 1)
        XCTAssertTrue(
            result.stderr.contains("threshold")
                || result.stderr.contains(
                    "invalid number"),
            "stderr was: \(result.stderr)")
    }

    func testCLIFailOnBlockExitsThreeOnBlock() throws {
        let result = try runCLI(args: [
            "--fail-on-block",
            "send me your password to verify",
        ])
        XCTAssertEqual(result.exitCode, 3,
            "--fail-on-block + .block verdict must" +
            " exit 3, not 0. stdout: \(result.stdout)")
    }

    func testCLIFailOnBlockExitsZeroOnSafe() throws {
        let result = try runCLI(args: [
            "--fail-on-block",
            "hello",
        ])
        XCTAssertEqual(result.exitCode, 0,
            "--fail-on-block + .safe verdict must" +
            " exit 0. stdout: \(result.stdout)")
    }

    func testCLIHighThresholdDowngradesBlock() throws {
        // With threshold 1.0, even .manipulationRisk
        // verdict downgrades to .safe (softmax cannot
        // produce exact 1.0)。 So --fail-on-block
        // should NOT trigger。
        let result = try runCLI(args: [
            "--threshold", "1.0",
            "--fail-on-block",
            "send me your password to verify",
        ])
        XCTAssertEqual(result.exitCode, 0,
            "High threshold downgrades verdict;" +
            " --fail-on-block should not trigger." +
            " stdout: \(result.stdout)")
        XCTAssertTrue(
            result.stdout.contains("verdict:  safe"),
            "Verdict must downgrade to safe at" +
            " threshold 1.0. stdout: \(result.stdout)")
    }

    // MARK: - Derived signals surfaced in CLI output

    func testCLIHumanOutputContainsDerivedSignals() throws {
        let result = try runCLI(args: [
            "the deadline is in one hour I must ship now",
        ])
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertTrue(
            result.stdout.contains("signals:"),
            "Human output must contain 'signals:' line." +
            " stdout: \(result.stdout)")
        XCTAssertTrue(
            result.stdout.contains("emotional="),
            "Output must show emotional= signal")
        XCTAssertTrue(
            result.stdout.contains("urgency="),
            "Output must show urgency= signal")
        XCTAssertTrue(
            result.stdout.contains("consequence="),
            "Output must show consequence= signal")
        XCTAssertTrue(
            result.stdout.contains("relation="),
            "Output must show relation= signal")
    }

    func testCLIManipulationOutputShowsHints() throws {
        let result = try runCLI(args: [
            "send me your password to verify",
        ])
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertTrue(
            result.stdout.contains("hints:"),
            "Manipulation input must surface hints" +
            " in CLI output. stdout: \(result.stdout)")
        XCTAssertTrue(
            result.stdout.contains(
                "ml.classifier.confidence="),
            "Manipulation hint must include the" +
            " confidence-prefixed signal")
    }

    func testCLIChatOutputOmitsHints() throws {
        let result = try runCLI(args: ["hello"])
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertFalse(
            result.stdout.contains("hints:"),
            "Chat input should NOT print 'hints:'" +
            " line (no manipulation flagged)" +
            " stdout: \(result.stdout)")
    }

    func testCLIJSONIncludesAllDerivedSignals() throws {
        let result = try runCLI(args: [
            "--json", "we disagree about the approach",
        ])
        XCTAssertEqual(result.exitCode, 0)
        guard let data = result.stdout
            .trimmingCharacters(
                in: .whitespacesAndNewlines)
            .data(using: .utf8),
              let parsed = try JSONSerialization
                .jsonObject(with: data) as? [String: Any]
        else {
            return XCTFail(
                "stdout not valid JSON: \(result.stdout)")
        }
        XCTAssertNotNil(parsed["emotionalLoad"] as? Double,
            "JSON must include emotionalLoad field")
        XCTAssertNotNil(parsed["timePressure"] as? Double)
        XCTAssertNotNil(
            parsed["consequenceLevel"] as? Double)
        XCTAssertNotNil(
            parsed["relationPattern"] as? String)
        XCTAssertNotNil(
            parsed["manipulationHints"] as? [String])
    }

    // MARK: - L5 risk surface in CLI output

    func testCLIHumanOutputContainsRiskLine() throws {
        let result = try runCLI(args: [
            "send me your password to verify",
        ])
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertTrue(
            result.stdout.contains("risk:"),
            "Human output must contain 'risk:' line." +
            " stdout: \(result.stdout)")
        XCTAssertTrue(
            result.stdout.contains("total="),
            "Risk line must include total= score")
        XCTAssertTrue(
            result.stdout.contains("mode="),
            "Risk line must include mode= action permit")
    }

    func testCLIManipulationOutputShowsRiskFactors() throws {
        let result = try runCLI(args: [
            "send me your password to verify",
        ])
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertTrue(
            result.stdout.contains("factors:"),
            "Manipulation input must surface 'factors:'" +
            " line with elevated risk factors." +
            " stdout: \(result.stdout)")
        XCTAssertTrue(
            result.stdout.contains(
                "manipulation_detected"),
            "Manipulation input must surface" +
            " 'manipulation_detected' risk factor")
    }

    func testCLIChatOutputOmitsRiskFactors() throws {
        let result = try runCLI(args: ["hello"])
        XCTAssertEqual(result.exitCode, 0)
        // The 'factors:' line should not appear for
        // chat (no elevated risk factors)。 But the
        // 'risk:' line itself MUST always appear。
        XCTAssertTrue(
            result.stdout.contains("risk:"),
            "Risk line must appear for ALL inputs")
        XCTAssertFalse(
            result.stdout.contains("factors:"),
            "Chat input should NOT print 'factors:'" +
            " line (no elevated risk factors)" +
            " stdout: \(result.stdout)")
    }

    // MARK: - L6/L7 cascade richness in CLI output

    func testCLIHumanOutputShowsCascadeLine() throws {
        let result = try runCLI(args: [
            "send me your password to verify",
        ])
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertTrue(
            result.stdout.contains("cascade:"),
            "Human output must contain 'cascade:' line." +
            " stdout: \(result.stdout)")
        XCTAssertTrue(
            result.stdout.contains("candidates="),
            "Cascade line must show candidates=")
        XCTAssertTrue(
            result.stdout.contains("tickets="),
            "Cascade line must show tickets=")
    }

    func testCLIHumanOutputShowsRenderedHeadline() throws {
        let result = try runCLI(args: [
            "send me your password to verify",
        ])
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertTrue(
            result.stdout.contains("rendered:"),
            "Human output must contain 'rendered:' line")
        XCTAssertTrue(
            result.stdout.contains("[DELAY]")
            || result.stdout.contains("[CONFIRM]")
            || result.stdout.contains("[DECLINE]"),
            "Manipulation cascade rendered headline must" +
            " include a risk-aware prefix。 stdout: " +
            "\(result.stdout)")
    }

    func testCLIManipulationCascadeProducesTickets() throws {
        let result = try runCLI(args: [
            "send me your password to verify",
        ])
        XCTAssertEqual(result.exitCode, 0)
        // Manipulation cascade emits tickets (>=1). The
        // cascade line is "cascade:  candidates=N
        // alternatives=N tickets=N"。 Verify
        // tickets=0 does NOT appear (would require
        // contains-substring check)。
        XCTAssertFalse(
            result.stdout.contains("tickets=0"),
            "Manipulation cascade must emit >=1 ticket" +
            " (got tickets=0)。 stdout: \(result.stdout)")
        XCTAssertTrue(
            result.stdout.contains("tickets="),
            "Cascade line must mention tickets=" +
            " count。 stdout: \(result.stdout)")
    }

    func testCLIJSONIncludesRiskFields() throws {
        let result = try runCLI(args: [
            "--json",
            "send me your password to verify",
        ])
        XCTAssertEqual(result.exitCode, 0)
        guard let data = result.stdout
            .trimmingCharacters(
                in: .whitespacesAndNewlines)
            .data(using: .utf8),
              let parsed = try JSONSerialization
                .jsonObject(with: data) as? [String: Any]
        else {
            return XCTFail(
                "stdout not valid JSON: \(result.stdout)")
        }
        XCTAssertNotNil(parsed["riskLevel"] as? String,
            "JSON must include riskLevel field")
        XCTAssertNotNil(parsed["totalRisk"] as? Double)
        XCTAssertNotNil(
            parsed["riskFactors"] as? [String])
        XCTAssertNotNil(
            parsed["recommendedMode"] as? String)
        // Sanity: manipulation input should produce
        // medium-or-higher risk level + manipulation_detected
        // factor in the JSON output。
        let factors = parsed["riskFactors"] as? [String]
            ?? []
        XCTAssertTrue(
            factors.contains("manipulation_detected"),
            "JSON riskFactors must include" +
            " 'manipulation_detected' for manipulation" +
            " input")
    }
}
