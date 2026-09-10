// MARK: - BASChapter990MCPPermitValidationTests
// chapter 九百九十 / M3655 — Cross-Module Integration Arc ch8 FINAL
//
// Closes ch 982.5 META-REVIEW cross-module Gap 2:
// BASMCPCapabilityGateway treated `permitID` as a free-form
// String — no validation against the live BASActionPermit from
// BASPolicy。 Defense-in-depth claim was false。
//
// Tests pin:
//   1. permit.mode == .block → reject
//   2. blockedDomains match → reject (priority over allowedDomains)
//   3. Non-empty allowedDomains acts as whitelist
//   4. Empty allowedDomains is permissive (anything not blocked)
//   5. toolScope == "denied" → reject
//   6. All rules pass → granted with descriptive audit ref
//   7. Audit refs follow reserved prefix `agentMCP.permit:`

import XCTest
@testable import BASOrchestration
@testable import BASMemory
@testable import BASPolicy

final class BASChapter990MCPPermitValidationTests: XCTestCase {

    // MARK: - Rule 1: blocked mode

    func testCRITICAL_BlockedMode_AlwaysRejected() {
        let invocation = sampleInvocation(server: "mcp.fs")
        let permit = BASActionPermit(
            mode: .block,
            allowedDomains: ["mcp.fs"])  // even with allow, block wins
        let (accepted, refs) = BASAgentFabricAdapters
            .validateMCPInvocation(invocation, against: permit)
        XCTAssertFalse(accepted,
            "ch 990 CRITICAL Gap 2: permit.mode==.block MUST " +
            "reject MCP invocation,even if allowedDomains " +
            "would have admitted")
        XCTAssertTrue(refs.contains {
            $0.contains("blocked-mode")
        })
    }

    // MARK: - Rule 2: blocklist

    func testCRITICAL_BlockedDomains_RejectsExplicitlyForbidden() {
        let invocation = sampleInvocation(server: "mcp.malicious")
        let permit = BASActionPermit(
            mode: .answer,
            allowedDomains: [],  // empty = permissive
            blockedDomains: ["mcp.malicious"])
        let (accepted, refs) = BASAgentFabricAdapters
            .validateMCPInvocation(invocation, against: permit)
        XCTAssertFalse(accepted,
            "ch 990 CRITICAL Gap 2: blockedDomains MUST reject " +
            "even when allowedDomains is permissive")
        XCTAssertTrue(refs.contains {
            $0.contains("in-blocked-domains")
        })
    }

    func testBlocklist_PrioritizedOverAllowlist() {
        // Server in BOTH lists → block wins (defense-in-depth)
        let invocation = sampleInvocation(server: "mcp.conflicted")
        let permit = BASActionPermit(
            mode: .answer,
            allowedDomains: ["mcp.conflicted"],
            blockedDomains: ["mcp.conflicted"])
        let (accepted, _) = BASAgentFabricAdapters
            .validateMCPInvocation(invocation, against: permit)
        XCTAssertFalse(accepted,
            "ch 990 Gap 2: blocklist > allowlist priority " +
            "(defense-in-depth)")
    }

    // MARK: - Rule 3: allowlist (whitelist)

    func testAllowlist_NonEmptyAsWhitelist() {
        let invocation = sampleInvocation(server: "mcp.stranger")
        let permit = BASActionPermit(
            mode: .answer,
            allowedDomains: ["mcp.fs", "mcp.calendar"])
        let (accepted, refs) = BASAgentFabricAdapters
            .validateMCPInvocation(invocation, against: permit)
        XCTAssertFalse(accepted,
            "ch 990 Gap 2: non-empty allowedDomains acts as " +
            "whitelist — non-matching server rejected")
        XCTAssertTrue(refs.contains {
            $0.contains("not-in-allowed-domains")
        })
    }

    func testAllowlist_EmptyIsPermissive() {
        let invocation = sampleInvocation(server: "mcp.anything")
        let permit = BASActionPermit(
            mode: .answer,
            allowedDomains: [],  // empty = permissive
            blockedDomains: [])
        let (accepted, _) = BASAgentFabricAdapters
            .validateMCPInvocation(invocation, against: permit)
        XCTAssertTrue(accepted,
            "ch 990 Gap 2: empty allowedDomains is permissive " +
            "(anything not blocked is allowed)")
    }

    func testAllowlist_MatchingServerAccepted() {
        let invocation = sampleInvocation(server: "mcp.fs")
        let permit = BASActionPermit(
            mode: .answer,
            allowedDomains: ["mcp.fs"])
        let (accepted, refs) = BASAgentFabricAdapters
            .validateMCPInvocation(invocation, against: permit)
        XCTAssertTrue(accepted)
        XCTAssertTrue(refs.contains {
            $0.hasPrefix("agentMCP.permit:granted:")
        })
    }

    // MARK: - Rule 4: toolScope

    func testCRITICAL_DeniedToolScope_Rejected() {
        let invocation = sampleInvocation(server: "mcp.fs")
        let permit = BASActionPermit(
            mode: .answer,
            allowedDomains: ["mcp.fs"],
            toolScope: "denied")
        let (accepted, refs) = BASAgentFabricAdapters
            .validateMCPInvocation(invocation, against: permit)
        XCTAssertFalse(accepted,
            "ch 990 CRITICAL Gap 2: toolScope='denied' MUST " +
            "reject even when allowedDomains admits")
        XCTAssertTrue(refs.contains {
            $0.contains("denied-tool-scope")
        })
    }

    // MARK: - chapter 九百九十一.5 META-REVIEW CRITICAL-1 fix

    /// CRITICAL-1 (Reviewer 1): ch 990 only matched literal
    /// "denied" but production code emits "none" (5 call sites
    /// in EBrainRuntimeCoordinator+Permit.swift +
    /// EBrainHostRuntime+RiskService.swift) and "blocked"
    /// (BASPolicy/EBrainRiskPlaneCore.swift:254)。 Real
    /// defense-in-depth bypass — every live deny-scope permit
    /// was being accepted。 This test pins the fix。
    func testCRITICAL_991_5_NoneScope_AlsoRejected() {
        let invocation = sampleInvocation(server: "mcp.fs")
        let permit = BASActionPermit(
            mode: .answer,
            allowedDomains: ["mcp.fs"],
            toolScope: "none")  // canonical production deny
        let (accepted, refs) = BASAgentFabricAdapters
            .validateMCPInvocation(invocation, against: permit)
        XCTAssertFalse(accepted,
            "ch 991.5 CRITICAL-1: toolScope='none' (canonical " +
            "production deny used by riskService) MUST reject。 " +
            "Pre-fix: ch 990 only checked 'denied' literal " +
            "which appears NOWHERE in production code — every " +
            "live deny-scope permit slipped through。")
        XCTAssertTrue(refs.contains {
            $0.contains("denied-tool-scope") &&
            $0.contains("scope=none")
        }, "ch 991.5 CRITICAL-1: audit ref MUST carry the " +
           "exact rejected scope value")
    }

    func testCRITICAL_991_5_BlockedScope_AlsoRejected() {
        let invocation = sampleInvocation(server: "mcp.fs")
        let permit = BASActionPermit(
            mode: .answer,
            allowedDomains: ["mcp.fs"],
            toolScope: "blocked")  // BASPolicy line 254 emits this
        let (accepted, _) = BASAgentFabricAdapters
            .validateMCPInvocation(invocation, against: permit)
        XCTAssertFalse(accepted,
            "ch 991.5 CRITICAL-1: toolScope='blocked' (BASPolicy " +
            ".BASActionPermit.protectiveBlock line 254 emits) " +
            "MUST reject")
    }

    func testToolScope_OtherValuesPermit() {
        // ch 991.5: updated permitted scopes list — only
        // "denied"/"none"/"blocked" are deny scopes; everything
        // else is a permit。
        for scope in ["bounded", "open", "restricted",
                      "elevated", "local_only", "standard"] {
            let invocation = sampleInvocation(server: "mcp.fs")
            let permit = BASActionPermit(
                mode: .answer,
                allowedDomains: ["mcp.fs"],
                toolScope: scope)
            let (accepted, _) = BASAgentFabricAdapters
                .validateMCPInvocation(
                    invocation, against: permit)
            XCTAssertTrue(accepted,
                "ch 990 Gap 2: toolScope='\(scope)' MUST permit " +
                "(only 'denied'/'none'/'blocked' reject)")
        }
    }

    /// GAP-2 (Reviewer 2): rule-priority ordering untested。
    /// A permit triggering ALL 4 deny rules MUST report Rule 1
    /// (blocked-mode) first per documented priority。 Re-ordering
    /// the source's early-return rules would otherwise slip
    /// past tests。
    func testCRITICAL_991_5_RulePriority_BlockedModeWinsAll() {
        let invocation = sampleInvocation(server: "mcp.malicious")
        let permit = BASActionPermit(
            mode: .block,  // Rule 1 trigger
            allowedDomains: ["mcp.different"],  // Rule 3 trigger
            blockedDomains: ["mcp.malicious"],  // Rule 2 trigger
            toolScope: "none")  // Rule 4 trigger
        let (accepted, refs) = BASAgentFabricAdapters
            .validateMCPInvocation(invocation, against: permit)
        XCTAssertFalse(accepted)
        XCTAssertEqual(refs.count, 1,
            "ch 991.5 GAP-2: validator emits exactly ONE audit " +
            "ref (early-return,first matching deny wins)")
        XCTAssertTrue(refs.first?.contains("blocked-mode") ?? false,
            "ch 991.5 GAP-2 CRITICAL: Rule 1 (blocked mode) " +
            "MUST fire FIRST + emit blocked-mode audit ref even " +
            "when Rules 2/3/4 would also trigger。 Mutation that " +
            "swaps rule order would otherwise pass all tests。")
    }

    // MARK: - Audit ref discipline

    func testAuditRefs_FollowReservedPrefix() {
        // Granted case
        let invocationA = sampleInvocation(server: "mcp.fs")
        let permitA = BASActionPermit(mode: .answer)
        let (_, refsA) = BASAgentFabricAdapters
            .validateMCPInvocation(invocationA, against: permitA)
        for ref in refsA {
            XCTAssertTrue(
                ref.hasPrefix("agentMCP.permit:"),
                "ch 990 Gap 2: all audit refs MUST use " +
                "reserved prefix 'agentMCP.permit:' for L14 " +
                "absorption (future-allocation per ch 981.5 DH3)")
        }
        // Rejected case
        let permitB = BASActionPermit(mode: .block)
        let (_, refsB) = BASAgentFabricAdapters
            .validateMCPInvocation(invocationA, against: permitB)
        for ref in refsB {
            XCTAssertTrue(
                ref.hasPrefix("agentMCP.permit:"),
                "ch 990: rejected refs ALSO use the prefix")
        }
    }

    func testAuditRefs_GrantedRefCarriesServerAndTool() {
        let invocation = sampleInvocation(
            server: "mcp.calendar",
            tool: "list-events")
        let permit = BASActionPermit(
            mode: .answer, toolScope: "bounded")
        let (accepted, refs) = BASAgentFabricAdapters
            .validateMCPInvocation(invocation, against: permit)
        XCTAssertTrue(accepted)
        let ref = refs.first ?? ""
        XCTAssertTrue(ref.contains("server=mcp.calendar"))
        XCTAssertTrue(ref.contains("tool=list-events"))
        XCTAssertTrue(ref.contains("scope=bounded"))
    }

    // MARK: - Determinism

    func testDeterminism() {
        let invocation = sampleInvocation(server: "mcp.fs")
        let permit = BASActionPermit(
            mode: .answer, allowedDomains: ["mcp.fs"])
        let r1 = BASAgentFabricAdapters
            .validateMCPInvocation(invocation, against: permit)
        let r2 = BASAgentFabricAdapters
            .validateMCPInvocation(invocation, against: permit)
        XCTAssertEqual(r1.accepted, r2.accepted)
        XCTAssertEqual(r1.auditRefs, r2.auditRefs,
            "ch 990 Gap 2: validation MUST be deterministic")
    }

    // MARK: - Helpers

    private func sampleInvocation(
        server: String,
        tool: String = "test-tool"
    ) -> BASMCPInvocation {
        BASMCPInvocation(
            mcpServerID: server,
            toolID: tool,
            invocationID: "inv.1",
            rawOutput: "test output",
            permitID: "p.1",
            allowedToolDomains: [server],
            nowNanos: 1_000_000)
    }
}
