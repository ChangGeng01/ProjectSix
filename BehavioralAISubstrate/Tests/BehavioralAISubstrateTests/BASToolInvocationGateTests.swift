// MARK: - BASToolInvocationGateTests — chapter 三百六六 / M853
//
// Test coverage for G6 part 3: tool-invocation gate that wires
// `BASToolInvocation` (M851) against `restrictedToolDomains[]`
// from `BASBoundaryVeil` (M843)。
//
// Tests verify:
//   - Empty restrictedToolDomains[] → .allow (ADR-014 OPT-IN)
//   - Empty toolName → .allow (defensive, no false positives)
//   - Substring match (case-insensitive) → .reject
//   - Whitespace-only patterns skipped
//   - First-match-wins on multi-pattern lists
//   - Reason codes carry pattern + anchor + toolName + invocationID
//   - partition() splits batch correctly into allowed + rejected
//   - Reason code prefix + anchor pinned

import XCTest
@testable import BASOrgan
@testable import BASRuntimeCore

final class BASToolInvocationGateTests: XCTestCase {

    // MARK: - Fixtures

    private func makeInvocation(
        invocationID: String = "inv-test",
        toolName: String,
        arguments: [String: String] = [:]
    ) -> BASToolInvocation {
        BASToolInvocation(
            invocationID: invocationID,
            toolName: toolName,
            arguments: arguments)
    }

    // MARK: - .allow cases

    func testEmptyRestrictedDomainsAllowsAll() {
        let inv = makeInvocation(
            toolName: "remote.send_email")
        let decision = BASToolInvocationGate.evaluate(
            invocation: inv,
            restrictedToolDomains: [])
        XCTAssertEqual(decision, .allow,
            "Empty boundary list → no restrictions (ADR-014 " +
            "OPT-IN doctrine)")
    }

    func testEmptyToolNameAllows() {
        let inv = makeInvocation(toolName: "")
        let decision = BASToolInvocationGate.evaluate(
            invocation: inv,
            restrictedToolDomains: ["remote.send"])
        XCTAssertEqual(decision, .allow,
            "Empty toolName → no false-positive match")
    }

    func testCleanToolPasses() {
        let inv = makeInvocation(
            toolName: "local.read_calendar")
        let decision = BASToolInvocationGate.evaluate(
            invocation: inv,
            restrictedToolDomains: ["remote.send"])
        XCTAssertEqual(decision, .allow,
            "Tool name not matching any restriction → .allow")
    }

    // MARK: - .reject cases

    func testRejectsOnSubstringMatch() {
        let inv = makeInvocation(
            invocationID: "i-1",
            toolName: "remote.send_email")
        let decision = BASToolInvocationGate.evaluate(
            invocation: inv,
            restrictedToolDomains: ["remote.send"])
        switch decision {
        case .allow:
            XCTFail("Expected .reject")
        case .reject(let codes):
            XCTAssertTrue(
                codes.contains(
                    "constitution.restrictedToolDomain:remote.send"))
            XCTAssertTrue(
                codes.contains(
                    BASToolInvocationGate
                        .rejectionAnchorCode))
            XCTAssertTrue(
                codes.contains(
                    "tool.invocation:remote.send_email"))
            XCTAssertTrue(
                codes.contains(
                    "tool.invocationID:i-1"))
        }
    }

    func testCaseInsensitiveMatch() {
        let inv = makeInvocation(
            toolName: "Remote.SEND_email")
        let decision = BASToolInvocationGate.evaluate(
            invocation: inv,
            restrictedToolDomains: ["remote.send"])
        switch decision {
        case .reject:
            // Expected — case-insensitive match
            break
        case .allow:
            XCTFail("Case-insensitive match must reject " +
                "Remote.SEND_email vs remote.send")
        }
    }

    func testFirstMatchWins() {
        let inv = makeInvocation(
            toolName: "alpha_beta_gamma_tool")
        let decision = BASToolInvocationGate.evaluate(
            invocation: inv,
            restrictedToolDomains: ["alpha", "beta"])
        switch decision {
        case .reject(let codes):
            XCTAssertTrue(
                codes.contains(
                    "constitution.restrictedToolDomain:alpha"),
                "First matching pattern in array order wins")
            XCTAssertFalse(
                codes.contains(
                    "constitution.restrictedToolDomain:beta"),
                "Subsequent patterns NOT also reported")
        case .allow:
            XCTFail("Expected .reject")
        }
    }

    func testWhitespaceOnlyPatternsSkipped() {
        let inv = makeInvocation(
            toolName: "any_tool_name")
        let decision = BASToolInvocationGate.evaluate(
            invocation: inv,
            restrictedToolDomains: ["", "  ", "\t", "no_match"])
        XCTAssertEqual(decision, .allow,
            "Whitespace-only patterns must NOT match every " +
            "input (defensive against config typos)")
    }

    func testWhitespaceTrimmedPatternMatches() {
        let inv = makeInvocation(
            toolName: "remote.send_email")
        let decision = BASToolInvocationGate.evaluate(
            invocation: inv,
            restrictedToolDomains: ["  remote.send  "])
        switch decision {
        case .reject(let codes):
            XCTAssertTrue(
                codes.contains(
                    "constitution.restrictedToolDomain:remote.send"),
                "Pattern is trimmed BEFORE substring match")
        case .allow:
            XCTFail("Trimmed pattern must still match")
        }
    }

    // MARK: - partition()

    func testPartitionSplitsAllowedAndRejected() {
        let invocations = [
            makeInvocation(
                invocationID: "i1",
                toolName: "local.read_calendar"),
            makeInvocation(
                invocationID: "i2",
                toolName: "remote.send_email"),
            makeInvocation(
                invocationID: "i3",
                toolName: "memory.search"),
            makeInvocation(
                invocationID: "i4",
                toolName: "remote.upload_file")
        ]
        let result = BASToolInvocationGate.partition(
            invocations: invocations,
            restrictedToolDomains: ["remote."])
        XCTAssertEqual(
            result.allowed.map { $0.invocationID },
            ["i1", "i3"])
        XCTAssertEqual(
            result.rejected.map { $0.invocation.invocationID },
            ["i2", "i4"])
        XCTAssertEqual(
            result.rejected.count, 2,
            "Both remote.* invocations rejected")
        // Each rejected invocation carries its own audit codes
        for (invocation, codes) in result.rejected {
            XCTAssertTrue(
                codes.contains(
                    "constitution.restrictedToolDomain:remote."))
            XCTAssertTrue(
                codes.contains(
                    "tool.invocationID:" +
                    invocation.invocationID))
        }
    }

    func testPartitionEmptyBatchReturnsEmpty() {
        let result = BASToolInvocationGate.partition(
            invocations: [],
            restrictedToolDomains: ["remote"])
        XCTAssertEqual(result.allowed, [])
        XCTAssertTrue(result.rejected.isEmpty)
    }

    func testPartitionNoRestrictionsReturnsAllAllowed() {
        let invocations = [
            makeInvocation(
                invocationID: "i1", toolName: "tool_a"),
            makeInvocation(
                invocationID: "i2", toolName: "tool_b")
        ]
        let result = BASToolInvocationGate.partition(
            invocations: invocations,
            restrictedToolDomains: [])
        XCTAssertEqual(
            result.allowed.count, 2)
        XCTAssertTrue(result.rejected.isEmpty)
    }

    // MARK: - Constants pin

    func testReasonCodePrefixPin() {
        XCTAssertEqual(
            BASToolInvocationGate.reasonCodePrefix,
            "constitution",
            "Cross-module convention: reason code prefix " +
            "matches BASConstitutionEnforcer (BASMemory) and " +
            "BASConstitutionalSoftCautionEvaluator " +
            "(BASEvaluation) for grep stability")
    }

    func testRejectionAnchorCodePin() {
        XCTAssertEqual(
            BASToolInvocationGate.rejectionAnchorCode,
            "constitution.restrictedToolDomain.match",
            "Rejection anchor code pin (chapter 八十七 raw " +
            "value stability — audit walkers grep this)")
    }
}
