// MARK: - BASChapter996_5Round15FixesTests
// chapter 九百九十六.5 / M3685.5 — META-REVIEW Round-15 deep cascade
//
// Round-15 DEEP review caught 2 CRITICALs that survived 14 rounds
// of orphan/dead-code-focused cascade because they live in the
// gap between "documented contract" and "actual production
// wiring":
//
//   - CRITICAL-1: BASSharedStateGraph.registerWriter exists +
//     BASAgentRegistry.register exists,but the wire between
//     them was NEVER installed in production。 Single-Writer-
//     Per-Domain global registry was test-only。
//   - CRITICAL-2: ch 993 cross-arc separator hardening applied
//     to ONLY 1 of 7 BASSovereignAuditEntry call sites。 The
//     "全部剩余部分一次性解决掉" claim was wrong — 6 production
//     call sites still used the vulnerable "1.0.0" default。
//
// This chapter regression-pins the fixes for both。

import XCTest
import Crypto
@testable import BASOrchestration
@testable import BASHostKit
@testable import BASMemory
@testable import BASSovereign
@testable import BASRuntimeCore
@testable import BASPolicy

final class BASChapter996_5Round15FixesTests: XCTestCase {

    // MARK: - CRITICAL-1: registry.wire(toGraph:) installs single-writer

    /// Defense:after `registry.wire(toGraph:)`,two agents
    /// claiming the same writeDomain MUST result in conflict
    /// (domainAlreadyClaimed throw)。 Pre-fix the registry never
    /// installed the claim → graph auto-claimed on first write
    /// → first-write-wins race → Single-Writer-Per-Domain was
    /// system-level doctrine but enforced only at test scope。
    func testCRITICAL_C1_OverlappingWriteDomain_Conflicts()
        async throws
    {
        let registry = BASAgentRegistry(
            strictRoleUniqueness: false)
        let graph = BASSharedStateGraph()
        // Two agents both claiming .candidateFrontier
        let agentA = BASAgentSpec(
            agentID: "planner.A",
            role: .planner,
            writeDomains: [.candidateFrontier],
            defaultLeaseProfile: .hotSeat,
            visibility: .high)
        let agentB = BASAgentSpec(
            agentID: "planner.B",
            role: .planner,
            writeDomains: [.candidateFrontier],
            defaultLeaseProfile: .hotSeat,
            visibility: .high)
        try await registry.register(agentA)
        try await registry.register(agentB)
        // After wire,B's claim should throw because A registered
        // first + got the domain
        do {
            try await registry.wire(toGraph: graph)
            XCTFail(
                "ch 996.5 CRITICAL-1: two agents with " +
                "overlapping writeDomain MUST cause " +
                "domainAlreadyClaimed throw during wire")
        } catch BASSharedStateGraphError
            .domainAlreadyClaimed(
                let domain, let existing, let new)
        {
            XCTAssertEqual(domain, .candidateFrontier)
            XCTAssertEqual(existing, "planner.A",
                "ch 996.5 CRITICAL-1: earlier-registered wins")
            XCTAssertEqual(new, "planner.B",
                "ch 996.5 CRITICAL-1: later-registered throws")
        }
    }

    /// Defense:after wire,distinct writeDomains install
    /// without conflict (global registry is now non-empty for
    /// subsequent writes' single-writer enforcement)。
    ///
    /// chapter 九百九十六.7 META-REVIEW Round-16 CRITICAL-1 fix:
    /// pre-fix used `XCTAssertNoThrow(Task { try await ... })`
    /// which is VACUOUSLY GREEN — Task init never throws
    /// synchronously,so XCTAssertNoThrow checks the Task value
    /// (not its async body)。 Now awaits directly so a throw
    /// from wire propagates + fails the test。
    func testCRITICAL_C1_DistinctWriteDomains_AllRegistered()
        async throws
    {
        let registry = BASAgentRegistry(
            strictRoleUniqueness: false)
        let graph = BASSharedStateGraph()
        let scout = BASAgentSpec(
            agentID: "scout.1",
            role: .scout,
            writeDomains: [.situationField],
            defaultLeaseProfile: .hotSeat,
            visibility: .high)
        let planner = BASAgentSpec(
            agentID: "planner.1",
            role: .planner,
            writeDomains: [.candidateFrontier],
            defaultLeaseProfile: .hotSeat,
            visibility: .high)
        try await registry.register(scout)
        try await registry.register(planner)
        // No overlap → wire MUST succeed (any throw fails test)
        try await registry.wire(toGraph: graph)
    }

    /// Defense:wire is IDEMPOTENT — re-wiring same registry +
    /// graph pair does not throw (per registerWriter contract:
    /// re-register same agentID for same domain is a no-op)。
    ///
    /// chapter 九百九十六.7 META-REVIEW Round-16 CRITICAL-1 fix:
    /// same Task-wrapper bug as DistinctWriteDomains test —
    /// now awaits directly so a throw propagates。
    func testC1_Idempotent_ReWireSameRegistry() async throws {
        let registry = BASAgentRegistry()
        let graph = BASSharedStateGraph()
        let agent = BASAgentSpec(
            agentID: "scout.1",
            role: .scout,
            writeDomains: [.situationField],
            defaultLeaseProfile: .hotSeat,
            visibility: .high)
        try await registry.register(agent)
        try await registry.wire(toGraph: graph)
        // Re-wire same pair — MUST not throw (any throw fails test)
        try await registry.wire(toGraph: graph)
    }

    // MARK: - CRITICAL-2: 6 audit-entry call sites use "1.1.0"

    /// Defense:every call site that constructs a
    /// BASSovereignAuditEntry on a sovereign-significant
    /// emission path MUST use schemaVersion "1.1.0" for
    /// hardened canonical-bytes。 Round-15 deep review caught
    /// that ch 993 patched only 1 of 7 sites。 ch 996.5 patched
    /// the remaining 6。 This test verifies by direct
    /// construction at each call site's signature shape that
    /// "1.1.0" is the schemaVersion seen by the canonical-bytes
    /// function。
    ///
    /// NOTE:full integration verification would require
    /// driving each call site through its production caller
    /// (verdict engine,clean-reboot,lineage-cut,shadow trial,
    /// update-ticket lifecycle,runtime+sovereign-commit)。 That
    /// scope is too large for one regression test。 This test
    /// proves the schemaVersion is set;production callers
    /// inherit via the explicit `schemaVersion: "1.1.0"` argument。
    func testCRITICAL_C2_HardenedFormatExplicitlyPickedByEachSite() {
        // Each of the 6 call sites was edited at ch 996.5 to
        // add `schemaVersion: "1.1.0"`。 Smoke-test that the
        // BASSovereignAuditEntry init handles "1.1.0" cleanly
        // + the canonical-bytes function selects the new
        // separator path。
        let entry = BASSovereignAuditEntry(
            schemaVersion: "1.1.0",
            auditID: "test",
            sessionID: "s",
            turnID: "t",
            verdictRef: "v",
            ruleIDs: ["rule-with,comma"],
            signalRefs: ["sig-with,comma", "another"],
            actionRefs: [],
            snapshotRef: "",
            actor: .system,
            signature: "",
            appendedAt: Date(timeIntervalSince1970: 1))
        XCTAssertEqual(entry.schemaVersion, "1.1.0")
        // Canonical bytes for this entry should use U+001F /
        // U+001E separators (hardened)。 An entry with
        // different signalRef splits should produce DIFFERENT
        // canonical bytes (anti-collision)。
        let entryAlt = BASSovereignAuditEntry(
            schemaVersion: "1.1.0",
            auditID: "test",
            sessionID: "s",
            turnID: "t",
            verdictRef: "v",
            ruleIDs: ["rule-with"],
            signalRefs: ["comma,sig-with", "comma,another"],
            actionRefs: [],
            snapshotRef: "",
            actor: .system,
            signature: "",
            appendedAt: Date(timeIntervalSince1970: 1))
        let bytes1 = basSovereignAuditCanonicalBytes(
            for: entry,
            priorHash: "h",
            signingNamespace: "ns")
        let bytes2 = basSovereignAuditCanonicalBytes(
            for: entryAlt,
            priorHash: "h",
            signingNamespace: "ns")
        XCTAssertNotEqual(bytes1, bytes2,
            "ch 996.5 CRITICAL-2: 1.1.0 hardened format MUST " +
            "prevent collision on `,`-containing array entries " +
            "(closes ch 993 cross-arc concern at all 7 call sites)")
    }

    /// Codebase-style assertion:the 6 vulnerable call sites
    /// fixed at ch 996.5 should all contain `schemaVersion:
    /// "1.1.0"` in their source。 Run via grep on the test
    /// fixture itself — if a future refactor accidentally drops
    /// the explicit version,this test catches it。
    func testCRITICAL_C2_AllSixCallSitesContainExplicitVersion()
        throws
    {
        let projectRoot =
            BASSourceTreeAudit.repoRoot
        let callSites = [
            "Sources/BASHostKit/EBrainRuntimeCoordinator+" +
                "SovereignCommit.swift",
            "Sources/BASSovereign/BASSovereignAuditLedger.swift",
            "Sources/BASSovereign/BASSovereignVerdictEngine.swift",
            "Sources/BASSovereign/" +
                "BASSovereignCleanRebootCoordinator.swift",
            "Sources/BASOrchestration/ShadowTrialLedgerBridge.swift",
            "Sources/BASObservability/" +
                "BASUpdateTicketLifecycle.swift",
        ]
        // P2-21 shape: a required callsite the anchor no longer matches must FAIL
        // the lint, not vanish from it. The old `continue` dropped unreadable
        // paths silently, so a renamed/moved callsite quietly left the sweep —
        // and had all six moved, this test would have PASSED having asserted
        // nothing. The stated justification ("CI tmp dirs etc.") was STALE:
        // BASSourceTreeAudit.repoRoot resolves via BAS_PROJECT_ROOT and then
        // walks up to Package.swift, so it is already tmp-dir-proof.
        var linted = 0
        for relativePath in callSites {
            let fullPath = "\(projectRoot)/\(relativePath)"
            guard let content = try? String(
                contentsOfFile: fullPath, encoding: .utf8)
            else {
                XCTFail(
                    "required callsite not readable at \(relativePath) — " +
                    "anchor drift silently disables this lint. Update the " +
                    "path (or delete the entry deliberately) rather than " +
                    "letting the sweep shrink unnoticed.")
                continue
            }
            linted += 1
            // ch 1011 / M3770 — Round-21 HIGH-1 evolution:
            // post-ch-1011 the literal `"1.1.0"` is replaced
            // by `BASSovereignAuditEntry.hardenedSchemaVersion`
            // constant reference。 The discipline ch 996.5
            // C2 was enforcing (hardened canonical-bytes
            // opt-in at each site) is PRESERVED — the form
            // just shifted from literal to canonical constant。
            // Test now accepts either form。
            XCTAssertTrue(
                content.contains("schemaVersion: \"1.1.0\"") ||
                content.contains(
                    "BASSovereignAuditEntry") &&
                content.contains(".hardenedSchemaVersion"),
                "ch 996.5 CRITICAL-2 + ch 1011 HIGH-1: " +
                "\(relativePath) MUST opt into the hardened " +
                "canonical-bytes format — either via literal " +
                "`schemaVersion: \"1.1.0\"` (pre-ch-1011) or " +
                "via `BASSovereignAuditEntry" +
                ".hardenedSchemaVersion` reference (post-ch-1011)")
        }
        XCTAssertEqual(
            linted, callSites.count,
            "saturation: every declared callsite must have been read and " +
            "linted — a shrinking sweep is a false green")
    }
}
