import Foundation
import CryptoKit
import BASAdmin
import BASHostKit
import BASMemory
import BASObservability
import BASPolicy
import BASRuntimeCore
import BASSovereign

/// M306 — multi-session continuity demo.
///
/// Drives **two sequential `BASHostRuntime` sessions** that share
/// one SQLite-backed `BASSovereignAuditLedger` file, demonstrating:
///
///   1. The two sessions produce distinct `sessionID`s.
///   2. Each session emits an audit entry containing the M298-M305
///      audit-signal-code prefixes (frontier / tribunal / abyssal
///      / humanAnchor / lifecycle).
///   3. Closing the storage between sessions is safe — the second
///      session sees a fresh in-process ledger that rehydrates
///      previous entries from disk.
///   4. After both sessions finish, opening a third (verification-
///      only) ledger against the same SQLite file reads back BOTH
///      entries, in chronological order, with `verifyChainIntegrity()`
///      passing.
///
/// This is the surgical "A.2" item from honesty-board chapter 七十.9
/// — the existing `--full-stack-demo` only ran multi-turn within
/// one session. This helper proves cross-session ledger continuity
/// without inventing a new audit pipeline (M298 storage locator +
/// M91 SQLite ledger storage + chapter 六十八-七十 audit codes are
/// all reused).
///
/// ## Doctrine
///
/// - **Single audit ledger file**, shared across both sessions
///   via `BASUnifiedStorageLocator` (M298). The locator's root is
///   the deployment convention; both sessions plug into the
///   canonical `sovereign-audit.sqlite` URL.
/// - **No verdict escalation, no permit mutation, no weight
///   write**. Sessions read existing host fixtures; their audit
///   entries land in the shared ledger as additive metadata only.
/// - **Cross-session = same file, different ledgers**. We
///   intentionally close + reopen `BASSovereignLedgerSQLiteStorage`
///   between sessions to prove the M91 cross-process semantics
///   work for in-process repetition too.
public struct MultiSessionContinuityDemo {

    /// One session's observable result. Used by tests + the
    /// runtime banner. All fields are pure read-only mirrors of
    /// what the demo printed.
    public struct SessionRecord: Sendable, Equatable {
        public let sessionID: String
        public let auditID: String
        public let signalRefs: [String]
        public let m298ThroughM305CodePrefixes: [String]

        public init(
            sessionID: String,
            auditID: String,
            signalRefs: [String],
            m298ThroughM305CodePrefixes: [String]
        ) {
            self.sessionID = sessionID
            self.auditID = auditID
            self.signalRefs = signalRefs
            self.m298ThroughM305CodePrefixes =
                m298ThroughM305CodePrefixes
        }
    }

    /// End-to-end demo result. `sessionA` and `sessionB` carry the
    /// per-session observable; `ledgerEntryCount` is how many
    /// audit entries the rehydrated verification ledger sees;
    /// `chainIntegrityVerified` is true iff
    /// `verifyChainIntegrity()` did not throw.
    public struct Outcome: Sendable, Equatable {
        public let unifiedRoot: URL
        public let auditLedgerURL: URL
        public let sessionA: SessionRecord
        public let sessionB: SessionRecord
        public let ledgerEntryCount: Int
        public let chainIntegrityVerified: Bool

        public init(
            unifiedRoot: URL,
            auditLedgerURL: URL,
            sessionA: SessionRecord,
            sessionB: SessionRecord,
            ledgerEntryCount: Int,
            chainIntegrityVerified: Bool
        ) {
            self.unifiedRoot = unifiedRoot
            self.auditLedgerURL = auditLedgerURL
            self.sessionA = sessionA
            self.sessionB = sessionB
            self.ledgerEntryCount = ledgerEntryCount
            self.chainIntegrityVerified = chainIntegrityVerified
        }
    }

    public enum DemoError: Error, Equatable {
        case sessionTurnMissing
        case sessionAuditEntryMissing
    }

    /// The 6 audit-signal-code prefixes the M298-M305 batch ships.
    /// Order matches chapter 六十八-七十 narrative (frontier first
    /// because M299 was the first batch).
    public static let auditCodePrefixes: [String] = [
        "frontier.status:",   // M299
        "tribunal.status:",   // M300
        "abyssal.magnitude:", // M303
        "humanAnchor.tone:",  // M304
        "seal.count:",        // M304 (only when ≥1 quarantine)
        "lifecycle.tickets:"  // M305 (only when ≥1 ticket)
    ]

    /// Run the demo end to end. The caller owns the lifetime of
    /// the demo root; pass a fresh tmp directory to avoid
    /// colliding with concurrent demo runs.
    public static func run(
        rootDirectory demoRoot: URL,
        signingSecretSeed: String =
            "qinao-multi-session-demo-seed"
    ) async throws -> Outcome {
        // Step 1 — derive shared canonical paths via M298 locator.
        let locations = try BASUnifiedStorageLocator.locate(
            in: demoRoot)
        let signingSecret = SymmetricKey(
            data: SHA256.hash(
                data: Data(signingSecretSeed.utf8)))

        // Step 2 — Session A: build storage1 + ledger1, drive
        // turn through fresh BASHostRuntime, append entry.
        // Use `.interactive` + `.primary` so the runtime-trace
        // sessionID has a distinct shape from session B.
        let recordA = try await Self.runSession(
            label: "A",
            ledgerPath: locations.auditLedgerURL.path,
            signingSecret: signingSecret,
            kind: .interactive,
            workflowProfile: .primary,
            prompt:
                "Help me weigh whether to commit to a new habit.",
            title: "Multi-session demo · session A")

        // Step 3 — Session B: build storage2 + ledger2 against
        // SAME file path. M91 rehydration loads session A's
        // entry into ledger2 automatically. Use `.ambient` +
        // `.reflective` so the trace sessionID is distinct from
        // session A — `runtimeTrace.sessionID` derives from
        // (kind, workflowProfile, surface, riskLevel) so making
        // any one of those differ produces distinct IDs and
        // distinct auditIDs (`audit.<sessionID>.<level>`).
        let recordB = try await Self.runSession(
            label: "B",
            ledgerPath: locations.auditLedgerURL.path,
            signingSecret: signingSecret,
            kind: .ambient,
            workflowProfile: .reflective,
            prompt:
                "Now help me weigh which habit to drop instead.",
            title: "Multi-session demo · session B")

        // Step 4 — Continuity proof: open a third storage +
        // ledger against the same file; verify chain + count.
        let storage3 = try BASSovereignLedgerSQLiteStorage(
            path: locations.auditLedgerURL.path)
        let ledger3 = BASSovereignAuditLedger(
            signingSecret: signingSecret,
            storage: storage3)
        let chainOK: Bool
        do {
            try await ledger3.verifyChainIntegrity()
            chainOK = true
        } catch {
            chainOK = false
        }
        let count = await ledger3.count()

        return Outcome(
            unifiedRoot: locations.root,
            auditLedgerURL: locations.auditLedgerURL,
            sessionA: recordA,
            sessionB: recordB,
            ledgerEntryCount: count,
            chainIntegrityVerified: chainOK)
    }

    // MARK: - Internal — run one session

    private static func runSession(
        label: String,
        ledgerPath: String,
        signingSecret: SymmetricKey,
        kind: BASHostSessionKind,
        workflowProfile: BASHostWorkflowProfile,
        prompt: String,
        title: String
    ) async throws -> SessionRecord {
        // Per-session: fresh storage handle (M91 SQLite) +
        // fresh ledger actor. Both close when this method
        // returns.
        let storage = try BASSovereignLedgerSQLiteStorage(
            path: ledgerPath)
        let ledger = BASSovereignAuditLedger(
            signingSecret: signingSecret,
            storage: storage)

        let runtime = BASHostRuntime(
            configuration: BASHostConfiguration(
                runtimeProfileID: "host.m306.\(label)",
                policyProfileID: "host.m306.\(label).policy",
                prefersPureLocal: true,
                defaultDeviceState:
                    BASHostConfiguration.fixtureDefaultDeviceState,
                console: .generic,
                lifecycleBehavior: .generic,
                workflowBehavior: .generic,
                cognitionBehavior: .generic,
                presentation: .generic,
                runtimeTuning: makeTuning(label: label),
                runtimePolicyLineage:
                    makeRuntimePolicyLineage(label: label),
                hostRhythmProfile: .generic))

        let result = try runtime.startSession(
            BASHostSessionRequest(
                kind: kind,
                workflowProfile: workflowProfile,
                surface: .application,
                prompt: prompt,
                title: title,
                riskLevel: .medium))

        guard let turn = result.eBrainTurn else {
            throw DemoError.sessionTurnMissing
        }
        guard let auditEntry = turn.sovereignAuditEntry else {
            throw DemoError.sessionAuditEntryMissing
        }

        // Strip the runtime-emitted signature before appending.
        // `BASSovereignAuditLedger.append` requires either an
        // empty signature (it fills its own HMAC) or a
        // pre-computed signature that already matches the
        // ledger's signing secret. The runtime's
        // `sovereignDigestHex(...)` is a per-turn integrity
        // check that is *not* keyed to the ledger's secret, so
        // we must clear it and let the ledger sign canonically.
        var draft = auditEntry
        draft.signature = ""
        _ = try await ledger.append(draft)

        let prefixesSeen = Self.auditCodePrefixes.filter {
            prefix in
            auditEntry.signalRefs.contains { code in
                code.hasPrefix(prefix)
            }
        }

        return SessionRecord(
            sessionID: turn.runtimeTrace.sessionID,
            auditID: auditEntry.auditID,
            signalRefs: auditEntry.signalRefs,
            m298ThroughM305CodePrefixes: prefixesSeen)
    }

    // MARK: - Internal — fixtures

    private static func makeRuntimePolicyLineage(
        label: String
    ) -> BASRuntimePolicyLineage {
        BASRuntimePolicyLineage(
            bundleVersion: "host.m306.\(label).bundle.v1",
            providerRoutingRegistryVersion:
                "host.m306.\(label).routing-registry.v1",
            providerRoutingPolicyID:
                "host.m306.\(label).routing-policy.v1",
            runtimeTuningRegistryVersion:
                "host.m306.\(label).tuning-registry.v1",
            runtimeTuningPolicyID:
                "host.m306.\(label).tuning-policy.v1",
            resolutionSourceID: "m306_demo")
    }

    private static func makeTuning(
        label: String
    ) -> BASEBrainRuntimeSynthesisPolicy {
        var tuning = BASEBrainRuntimeSynthesisPolicy.generic
            .withSchemaVersion(
                "host.runtime-synthesis.m306.\(label).v1")
        tuning.stateTransitions.runModeRules =
            tuning.stateTransitions
                .synthesizedRunModeRules(
                    wakeIntent: tuning.wakeIntent)
        return tuning
    }
}
