// MARK: - BASLLMTaskPackageTests — chapter 四百一 / M928

import XCTest
@testable import BASOrgan
@testable import BASRuntimeCore

final class BASLLMTaskPackageTests: XCTestCase {

    // MARK: - Defaults

    func testDefaultsPinned() {
        XCTAssertEqual(
            BASLLMTaskPackageDefaults.surface, "chat")
        XCTAssertEqual(
            BASLLMTaskPackageDefaults.kind, "ask")
        XCTAssertEqual(
            BASLLMTaskPackageDefaults.intent, "ask")
        XCTAssertEqual(
            BASLLMTaskPackageDefaults.maxIterations, 10)
    }

    // MARK: - Raw input

    func testRawInputDefaults() {
        let input = BASLLMRawInput(
            prompt: "hi", sessionID: "s1")
        XCTAssertEqual(input.surface, "chat")
        XCTAssertEqual(input.kind, "ask")
    }

    func testRawInputCodableRoundTrip() throws {
        let input = BASLLMRawInput(
            prompt: "hello",
            sessionID: "s-rt",
            surface: "voice",
            kind: "plan")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(input)
        let decoded = try JSONDecoder().decode(
            BASLLMRawInput.self, from: data)
        XCTAssertEqual(decoded, input)
    }

    // MARK: - Task package

    func testTaskPackageInitMinimal() {
        let pkg = BASLLMTaskPackage(
            taskID: "t-1",
            originSessionID: "s-1",
            compiledAtMs: 1_000,
            intent: "ask",
            goal: "")
        XCTAssertEqual(pkg.taskID, "t-1")
        XCTAssertEqual(pkg.constraints, [])
        XCTAssertEqual(pkg.contextBlobs, [])
        XCTAssertEqual(pkg.riskFlags, [])
        XCTAssertNil(pkg.outputSchema)
        XCTAssertEqual(pkg.toolHints, [])
        XCTAssertEqual(pkg.maxIterations, 10)
    }

    func testTaskPackageCodableRoundTrip() throws {
        let pkg = BASLLMTaskPackage(
            taskID: "t-rt",
            originSessionID: "s-rt",
            compiledAtMs: 1_700_000_000_000,
            intent: "plan",
            goal: "ship MVP",
            constraints: ["no_scope_creep", "ship_in_2_weeks"],
            contextBlobs: ["mem-1", "mem-2"],
            riskFlags: ["irreversible"],
            outputSchema: nil,
            toolHints: [
                BASTool(name: "search", description: "x",
                    parameters: [])
            ],
            maxIterations: 5)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(pkg)
        let decoded = try JSONDecoder().decode(
            BASLLMTaskPackage.self, from: data)
        XCTAssertEqual(decoded, pkg)
    }

    // MARK: - Deterministic taskID

    func testDeterministicTaskID() {
        let input = BASLLMRawInput(
            prompt: "test", sessionID: "s")
        let id1 = BASLLMTaskPackage.deterministicTaskID(
            for: input, compiledAtMs: 1_000)
        let id2 = BASLLMTaskPackage.deterministicTaskID(
            for: input, compiledAtMs: 1_000)
        XCTAssertEqual(id1, id2,
            "Same input + same timestamp → same ID (M892)")
        XCTAssertTrue(id1.hasPrefix("task-"))
    }

    func testDifferentTimestampDifferentTaskID() {
        let input = BASLLMRawInput(
            prompt: "test", sessionID: "s")
        let id1 = BASLLMTaskPackage.deterministicTaskID(
            for: input, compiledAtMs: 1_000)
        let id2 = BASLLMTaskPackage.deterministicTaskID(
            for: input, compiledAtMs: 2_000)
        XCTAssertNotEqual(id1, id2)
    }

    func testDifferentInputDifferentTaskID() {
        let i1 = BASLLMRawInput(
            prompt: "a", sessionID: "s")
        let i2 = BASLLMRawInput(
            prompt: "b", sessionID: "s")
        XCTAssertNotEqual(
            BASLLMTaskPackage.deterministicTaskID(
                for: i1, compiledAtMs: 1_000),
            BASLLMTaskPackage.deterministicTaskID(
                for: i2, compiledAtMs: 1_000))
    }

    // M907 doctrine pin: length-prefixed encoding prevents
    // pipe-injection collisions
    func testPipeInjectionDoesNotCollide() {
        let i1 = BASLLMRawInput(
            prompt: "a|b", sessionID: "c")
        let i2 = BASLLMRawInput(
            prompt: "a", sessionID: "b|c")
        XCTAssertNotEqual(
            BASLLMTaskPackage.deterministicTaskID(
                for: i1, compiledAtMs: 1_000),
            BASLLMTaskPackage.deterministicTaskID(
                for: i2, compiledAtMs: 1_000),
            "Length-prefixed encoding prevents collision")
    }
}
