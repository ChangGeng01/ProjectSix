// MARK: - BASLLMPromptCompilerTests — chapter 四百一 / M929

import XCTest
@testable import BASOrgan
@testable import BASRuntimeCore

final class BASLLMPromptCompilerTests: XCTestCase {

    private let compiler = BASLLMPromptCompiler()
    private let baseInput = BASLLMRawInput(
        prompt: "test prompt", sessionID: "s-1")

    func testCompileEmptyContextProducesMinimalPackage() {
        let pkg = compiler.compile(
            rawInput: baseInput,
            compiledAtMs: 1_000)
        XCTAssertEqual(pkg.intent, "ask")
        XCTAssertEqual(pkg.goal, "")
        XCTAssertEqual(pkg.constraints, [])
        XCTAssertEqual(pkg.contextBlobs, [])
        XCTAssertEqual(pkg.riskFlags, [])
        XCTAssertEqual(pkg.toolHints, [])
        XCTAssertEqual(pkg.originSessionID, "s-1")
    }

    func testCompileFullContextPopulatesPackage() {
        let context = BASLLMCompilerContext(
            intentHint: "plan",
            goalHint: "ship MVP",
            constraints: ["no scope creep", "stay focused"],
            memoryBullets: [
                "User prefers minimal tech",
                "Budget: 2 weeks"
            ],
            riskFlags: ["scope_creep"])
        let tools = [
            BASTool(
                name: "search",
                description: "search",
                parameters: [])
        ]
        let pkg = compiler.compile(
            rawInput: baseInput,
            context: context,
            compiledAtMs: 2_000,
            toolHints: tools)
        XCTAssertEqual(pkg.intent, "plan")
        XCTAssertEqual(pkg.goal, "ship MVP")
        XCTAssertEqual(pkg.constraints,
            ["no scope creep", "stay focused"])
        XCTAssertEqual(pkg.contextBlobs.count, 2)
        XCTAssertEqual(pkg.riskFlags, ["scope_creep"])
        XCTAssertEqual(pkg.toolHints.count, 1)
    }

    func testEmptyIntentHintFallsBackToDefault() {
        let context = BASLLMCompilerContext(
            intentHint: "")
        let pkg = compiler.compile(
            rawInput: baseInput,
            context: context,
            compiledAtMs: 1_000)
        XCTAssertEqual(pkg.intent, "ask",
            "Empty intentHint falls back to default")
    }

    func testConstraintsDeduplicatedPreservingOrder() {
        let context = BASLLMCompilerContext(
            constraints: ["a", "b", "a", "c", "  b  ", "a"])
        let pkg = compiler.compile(
            rawInput: baseInput,
            context: context,
            compiledAtMs: 1_000)
        XCTAssertEqual(pkg.constraints, ["a", "b", "c"])
    }

    func testRiskFlagsDeduplicated() {
        let context = BASLLMCompilerContext(
            riskFlags: ["risk1", "risk1", "risk2"])
        let pkg = compiler.compile(
            rawInput: baseInput,
            context: context,
            compiledAtMs: 1_000)
        XCTAssertEqual(pkg.riskFlags, ["risk1", "risk2"])
    }

    func testEmptyConstraintsAreFiltered() {
        let context = BASLLMCompilerContext(
            constraints: ["valid", "", "  ", "another"])
        let pkg = compiler.compile(
            rawInput: baseInput,
            context: context,
            compiledAtMs: 1_000)
        XCTAssertEqual(pkg.constraints, ["valid", "another"])
    }

    func testMemoryBulletsCappedAtLimit() {
        let bullets = (0..<20).map { "bullet-\($0)" }
        let context = BASLLMCompilerContext(
            memoryBullets: bullets)
        let pkg = compiler.compile(
            rawInput: baseInput,
            context: context,
            compiledAtMs: 1_000)
        XCTAssertEqual(pkg.contextBlobs.count, 5,
            "Default cap is 5")
        XCTAssertEqual(pkg.contextBlobs.first,
            "bullet-0",
            "Order preserved (top-K)")
    }

    func testCustomMemoryBulletCap() {
        let compiler = BASLLMPromptCompiler(
            memoryBulletCap: 3)
        let context = BASLLMCompilerContext(
            memoryBullets: ["a", "b", "c", "d", "e"])
        let pkg = compiler.compile(
            rawInput: baseInput,
            context: context,
            compiledAtMs: 1_000)
        XCTAssertEqual(pkg.contextBlobs, ["a", "b", "c"])
    }

    func testCompilationDeterministic() {
        let context = BASLLMCompilerContext(
            intentHint: "plan",
            constraints: ["a"])
        let pkg1 = compiler.compile(
            rawInput: baseInput,
            context: context,
            compiledAtMs: 1_000)
        let pkg2 = compiler.compile(
            rawInput: baseInput,
            context: context,
            compiledAtMs: 1_000)
        XCTAssertEqual(pkg1, pkg2,
            "M892 replay determinism: same inputs → same package")
    }

    func testTaskIDInheritedFromDeterministicFactory() {
        let pkg = compiler.compile(
            rawInput: baseInput,
            compiledAtMs: 1_000)
        let expected = BASLLMTaskPackage
            .deterministicTaskID(
                for: baseInput, compiledAtMs: 1_000)
        XCTAssertEqual(pkg.taskID, expected)
    }
}
