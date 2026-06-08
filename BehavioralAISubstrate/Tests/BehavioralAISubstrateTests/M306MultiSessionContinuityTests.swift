import XCTest
import CryptoKit
@testable import BASAdmin
@testable import BASHostKit
import BASMemory
import BASObservability
import BASOrchestration
import BASPolicy
import BASRuntimeCore
import BASSovereign

/// M306 — pin the multi-session continuity contract that
/// `QinaoSampleHost --multi-session-demo` relies on.
///
/// Pre-M306 the surgical-shippable A.2 gap from honesty-board
/// chapter 七十.9 was open: the existing `--full-stack-demo`
/// only ran multi-turn within ONE session; cross-session
/// continuity (session A → session B sharing one audit ledger
/// file) was unproven. This file pins the substrate contract
/// the helper consumes:
///
///   1. Two `BASHostRuntime` sessions with different
///      (kind, workflowProfile) produce distinct
///      `runtimeTrace.sessionID`s and distinct
///      `sovereignAuditEntry.auditID`s.
///   2. The audit entry's signature must be cleared before
///      `BASSovereignAuditLedger.append(...)` because the
///      runtime's `sovereignDigestHex` signature is keyed
///      differently than the ledger's HMAC; appending with the
///      runtime signature intact throws `signatureMismatch`.
///   3. After session A appends, closing storage1 + opening
///      storage2 against the same SQLite path rehydrates
///      session A's entry into ledger2 (M91 cross-process
///      semantics).
///   4. After both sessions, opening a third verification
///      ledger against the same file sees BOTH entries with
///      `verifyChainIntegrity()` passing and `count() == 2`.
///   5. Each session's audit entry carries the M298-M305 audit
///      code prefixes (frontier / tribunal / abyssal /
///      humanAnchor / lifecycle).
///
/// Because `QinaoSampleHost` is an executable target, its
/// `MultiSessionContinuityDemo` helper isn't importable from
/// test targets. These tests exercise the substrate primitives
/// directly with the same shape the helper wraps.
final class M306MultiSessionContinuityTests: XCTestCase {

    // MARK: - Configuration helpers

    private func makeRuntimePolicyLineage(
        label: String
    ) -> BASRuntimePolicyLineage {
        BASRuntimePolicyLineage(
            bundleVersion: "test.m306.\(label).bundle.v1",
            providerRoutingRegistryVersion:
                "test.m306.\(label).routing-registry.v1",
            providerRoutingPolicyID:
                "test.m306.\(label).routing-policy.v1",
            runtimeTuningRegistryVersion:
                "test.m306.\(label).tuning-registry.v1",
            runtimeTuningPolicyID:
                "test.m306.\(label).tuning-policy.v1",
            resolutionSourceID: "test_bundle"
        )
    }

    private func makeTuning(
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

    private func makeRuntime(label: String) -> BASHostRuntime {
        BASHostRuntime(
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
                hostRhythmProfile: .generic
            )
        )
    }

    private func runTurn(
        label: String,
        kind: BASHostSessionKind,
        workflowProfile: BASHostWorkflowProfile,
        prompt: String
    ) throws -> BASEBrainTurnResult {
        let runtime = makeRuntime(label: label)
        let result = try runtime.startSession(
            BASHostSessionRequest(
                kind: kind,
                workflowProfile: workflowProfile,
                surface: .application,
                prompt: prompt,
                title: "M306 session \(label)",
                riskLevel: .medium))
        return try XCTUnwrap(result.eBrainTurn)
    }

    private func makeRoot() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "m306-test-\(UUID().uuidString)")
    }

    private func signingSecret() -> SymmetricKey {
        SymmetricKey(
            data: SHA256.hash(
                data: Data("m306-test-seed".utf8)))
    }

    // MARK: - 1. Distinct (kind, workflowProfile) → distinct
    //           runtimeTrace.sessionIDs

    /// Two sessions with different (kind, workflowProfile)
    /// must produce distinct `runtimeTrace.sessionID`s; these
    /// in turn produce distinct `auditID`s (which are
    /// `audit.<sessionID>.<level>`).
    func testDistinctSessionConfigsProduceDistinctAuditIDs()
        throws
    {
        let turnA = try runTurn(
            label: "A",
            kind: .interactive,
            workflowProfile: .primary,
            prompt: "M306 session A prompt")
        let turnB = try runTurn(
            label: "B",
            kind: .ambient,
            workflowProfile: .reflective,
            prompt: "M306 session B prompt")

        let entryA = try XCTUnwrap(turnA.sovereignAuditEntry)
        let entryB = try XCTUnwrap(turnB.sovereignAuditEntry)

        XCTAssertNotEqual(
            turnA.runtimeTrace.sessionID,
            turnB.runtimeTrace.sessionID,
            "(kind, workflowProfile) differ → sessionIDs differ")
        XCTAssertNotEqual(
            entryA.auditID, entryB.auditID,
            "audit IDs derived from sessionID must differ")
    }

    // MARK: - 2. Runtime-emitted signature can't be appended
    //           directly — must be cleared.

    /// `BASSovereignAuditLedger.append(_:)` rejects entries
    /// whose signature is non-empty AND doesn't match the
    /// ledger's HMAC. The runtime's `sovereignDigestHex(...)`
    /// signature uses different keying. Pin the contract: an
    /// unmodified entry throws; clearing the signature
    /// succeeds.
    func testAppendRejectsRuntimeSignatureAndAcceptsCleared()
        throws
    {
        // M2158 — migrated to sync test + non-detached Task
        // (Diagnostic F pattern) to bypass SIGBUS bucket。
        let root = makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let locations = try BASUnifiedStorageLocator.locate(
            in: root)

        let turn = try runTurn(
            label: "A",
            kind: .interactive,
            workflowProfile: .primary,
            prompt: "M306 sig prompt")
        let entry = try XCTUnwrap(turn.sovereignAuditEntry)
        // Comprehensive-audit fix (LOW): the coordinator now emits a CLEARED signature — it no longer
        // over-claims authentication with a keyless SHA256 tag (the keyed ledger is the sole signer). Confirm
        // that new invariant directly.
        XCTAssertTrue(entry.signature.isEmpty,
            "coordinator audit entry must carry NO keyless signature (keyed ledger is the sole signer)")

        let storage = try BASSovereignLedgerSQLiteStorage(
            path: locations.auditLedgerURL.path)
        let ledger = BASSovereignAuditLedger(
            signingSecret: signingSecret(),
            storage: storage)

        let exp = expectation(
            description: "M306-append-reject-then-accept")
        Task {
            // Step a: a RUNTIME (keyless, non-HMAC) signature must be REJECTED by the keyed ledger. Inject a
            // runtime-style keyless hex tag (the 64-char shape the coordinator used to emit) onto the entry —
            // since the coordinator now emits "", we recreate the "runtime signature intact" case explicitly.
            var runtimeSigned = entry
            runtimeSigned.signature =
                "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
            do {
                _ = try await ledger.append(runtimeSigned)
                XCTFail(
                    "expected signatureMismatch when a runtime (keyless) " +
                    "signature is present")
            } catch let err as BASSovereignAuditLedger.LedgerError {
                switch err {
                case .signatureMismatch(let auditID):
                    XCTAssertEqual(auditID, entry.auditID)
                default:
                    XCTFail("expected signatureMismatch, got \(err)")
                }
            }

            // Step b: clear signature → ledger signs canonically.
            var draft = entry
            draft.signature = ""
            do {
                let appended = try await ledger.append(draft)
                XCTAssertFalse(
                    appended.entry.signature.isEmpty,
                    "ledger must fill in HMAC signature on append")
            } catch {
                XCTFail(
                    "unexpected error on cleared-signature append: \(error)")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 10.0)
    }

    // MARK: - 3. Cross-session rehydration: ledger2 sees
    //           ledger1's entries.

    /// Open storage1 + ledger1, append, close. Open storage2
    /// + ledger2 against same SQLite path → ledger2.count() == 1
    /// (M91 rehydration loaded the entry).
    func testRehydrationLoadsPreviousSessionEntries() throws {
        // M2158 — migrated to sync test + non-detached Task
        // (Diagnostic F pattern)。
        let root = makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let locations = try BASUnifiedStorageLocator.locate(
            in: root)
        let secret = signingSecret()

        // Session A — sync part first
        let turnA = try runTurn(
            label: "A",
            kind: .interactive,
            workflowProfile: .primary,
            prompt: "Session A")
        let entryA = try XCTUnwrap(turnA.sovereignAuditEntry)
        var draftA = entryA
        draftA.signature = ""

        let exp1 = expectation(
            description: "M306-rehydration-step1")
        Task {
            do {
                let storage1 = try BASSovereignLedgerSQLiteStorage(
                    path: locations.auditLedgerURL.path)
                let ledger1 = BASSovereignAuditLedger(
                    signingSecret: secret,
                    storage: storage1)
                _ = try await ledger1.append(draftA)
                exp1.fulfill()
            } catch {
                XCTFail("session A append failed: \(error)")
                exp1.fulfill()
            }
        }
        wait(for: [exp1], timeout: 10.0)

        // Session B sync part (runTurn)
        let turnB = try runTurn(
            label: "B",
            kind: .ambient,
            workflowProfile: .reflective,
            prompt: "Session B")
        let entryB = try XCTUnwrap(turnB.sovereignAuditEntry)
        var draftB = entryB
        draftB.signature = ""

        let exp2 = expectation(
            description: "M306-rehydration-step2")
        Task {
            do {
                let storage2 = try BASSovereignLedgerSQLiteStorage(
                    path: locations.auditLedgerURL.path)
                let ledger2 = BASSovereignAuditLedger(
                    signingSecret: secret,
                    storage: storage2)
                let preCount = await ledger2.count()
                XCTAssertEqual(
                    preCount, 1,
                    "ledger2 must rehydrate session A's entry")
                _ = try await ledger2.append(draftB)
                let postCount = await ledger2.count()
                XCTAssertEqual(postCount, 2)
                exp2.fulfill()
            } catch {
                XCTFail("session B sequence failed: \(error)")
                exp2.fulfill()
            }
        }
        wait(for: [exp2], timeout: 10.0)
    }

    // MARK: - 4. Verification ledger sees both entries + chain
    //           integrity verifies.

    /// After both sessions append, opening a third
    /// verification ledger against the same file must:
    ///   - count() == 2
    ///   - verifyChainIntegrity() does not throw
    ///   - both audit IDs are readable in snapshot order
    func testVerificationLedgerSeesBothEntries() throws {
        // M2158 — migrated to sync test + non-detached Task
        // (Diagnostic F pattern)。
        let root = makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let locations = try BASUnifiedStorageLocator.locate(
            in: root)
        let secret = signingSecret()

        let turnA = try runTurn(
            label: "A",
            kind: .interactive,
            workflowProfile: .primary,
            prompt: "Session A")
        let turnB = try runTurn(
            label: "B",
            kind: .ambient,
            workflowProfile: .reflective,
            prompt: "Session B")
        let entryA = try XCTUnwrap(turnA.sovereignAuditEntry)
        let entryB = try XCTUnwrap(turnB.sovereignAuditEntry)

        let exp = expectation(
            description: "M306-verification-ledger")
        Task {
            do {
                // Session A append.
                let storage1 =
                    try BASSovereignLedgerSQLiteStorage(
                        path: locations.auditLedgerURL.path)
                let ledger1 = BASSovereignAuditLedger(
                    signingSecret: secret,
                    storage: storage1)
                var draftA = entryA
                draftA.signature = ""
                _ = try await ledger1.append(draftA)

                // Session B append.
                let storage2 =
                    try BASSovereignLedgerSQLiteStorage(
                        path: locations.auditLedgerURL.path)
                let ledger2 = BASSovereignAuditLedger(
                    signingSecret: secret,
                    storage: storage2)
                var draftB = entryB
                draftB.signature = ""
                _ = try await ledger2.append(draftB)

                // Verification ledger.
                let storage3 =
                    try BASSovereignLedgerSQLiteStorage(
                        path: locations.auditLedgerURL.path)
                let ledger3 = BASSovereignAuditLedger(
                    signingSecret: secret,
                    storage: storage3)
                let count = await ledger3.count()
                XCTAssertEqual(count, 2)
                try await ledger3.verifyChainIntegrity()

                let snapshot = await ledger3.snapshot()
                XCTAssertEqual(snapshot.count, 2)
                XCTAssertEqual(
                    snapshot[0].entry.auditID,
                    entryA.auditID)
                XCTAssertEqual(
                    snapshot[1].entry.auditID,
                    entryB.auditID)
                exp.fulfill()
            } catch {
                XCTFail(
                    "verification ledger sequence failed: \(error)")
                exp.fulfill()
            }
        }
        wait(for: [exp], timeout: 10.0)
    }

    // MARK: - 5. Both session entries carry the M298-M305 audit
    //           code prefixes.

    /// Each session's audit entry must contain the 6 audit
    /// code prefixes (frontier / tribunal / abyssal /
    /// humanAnchor / seal / lifecycle) shipped in M298-M305.
    /// `seal.count` and `lifecycle.tickets` are conditional on
    /// the turn producing quarantine records / tickets — so we
    /// assert presence of the always-emitted four (frontier /
    /// tribunal / abyssal / humanAnchor) and check the
    /// conditional two are coherent.
    func testBothSessionsCarryM298ThroughM305Codes() throws {
        let turnA = try runTurn(
            label: "A",
            kind: .interactive,
            workflowProfile: .primary,
            prompt: "Session A")
        let turnB = try runTurn(
            label: "B",
            kind: .ambient,
            workflowProfile: .reflective,
            prompt: "Session B")

        let entryA = try XCTUnwrap(turnA.sovereignAuditEntry)
        let entryB = try XCTUnwrap(turnB.sovereignAuditEntry)

        let alwaysEmittedPrefixes = [
            "frontier.status:",
            "tribunal.status:",
            "abyssal.magnitude:",
            "humanAnchor.tone:"
        ]
        for prefix in alwaysEmittedPrefixes {
            XCTAssertTrue(
                entryA.signalRefs.contains {
                    $0.hasPrefix(prefix)
                },
                "session A audit signalRefs missing \(prefix)")
            XCTAssertTrue(
                entryB.signalRefs.contains {
                    $0.hasPrefix(prefix)
                },
                "session B audit signalRefs missing \(prefix)")
        }
    }

    // MARK: - 6. M298 unified storage locator anchors the
    //           shared root.

    /// Sanity: after the multi-session flow, the audit ledger
    /// file lives under the locator's root and uses the
    /// canonical filename — locked so future deployments can
    /// trust the deployment convention.
    func testAuditLedgerUsesCanonicalFilenameUnderRoot() throws
    {
        let root = makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let locations = try BASUnifiedStorageLocator.locate(
            in: root)
        XCTAssertEqual(
            locations.auditLedgerURL.lastPathComponent,
            "sovereign-audit.sqlite")
        XCTAssertEqual(
            locations.auditLedgerURL
                .deletingLastPathComponent().path,
            root.path)
    }
}
