// MARK: - BASAgentFabricColdRestart
// chapter 九百八十一.5 / M3610.5 — USER-PASS-7 deferred item DI3
//
// Per `Docs/ARC_SEAL_953_981.md` deferred item #3:app-suspension
// state persistence。 When iOS suspends + relaunches the host
// app,this module provides the Codable wire-format for the
// substrate's per-session agent fabric state so the host can
// restore the in-flight session cleanly。
//
// ## What this module DOES NOT do
//
// - DOES NOT touch the state graph itself (that's the host's
//   responsibility via the existing `BASSharedStateGraphSQLiteStorage`
//   from ch 956.7)
// - DOES NOT serialize the encoded latent spine (encoder
//   output is too large + ephemeral;cold-restart rebuilds it)
// - DOES NOT serialize trace log events (those go to the
//   existing `BASRoutedEventLogStorage` event-sourced channel)
//
// ## What this module DOES do
//
// Provides a `BASAgentFabricSessionSnapshot` Codable record that:
//   - Captures the per-session AGENT ROSTER (which agents the
//     host registered + their specs)
//   - Captures the active PERSONA OVERLAYS (user + host)
//   - Captures the active SOVEREIGN WARRANTS (if any host
//     warrants are issued during the session)
//   - Captures the WATCHER HINT TOTALS (counter state — not
//     individual hints,which live in event log)
//
// The host serializes this snapshot when the app is
// backgrounded and deserializes when relaunched。 Substrate-
// side helpers verify the deserialized snapshot is still
// valid (e.g. agent IDs not stale,personas pass forbidden
// detector,warrant IDs are recognizable formats)。
//
// ## Pure-fn discipline
//
// Same as ch 957-981 — pure functions,no actor,no I/O。
// Caller (host's app-lifecycle code) manages the actual
// persist + restore I/O。 This module just provides the
// Codable + validation。

import Foundation

// MARK: - Session snapshot

/// Slim Codable record of one agent fabric session's persistent
/// state for app-suspend/resume。 Host serializes this when iOS
/// backgrounds the app and deserializes when relaunched。 Per
/// ch 981.6 USER-PASS-8 doc fix:public type now has per-field
/// doc comments matching the rest of the substrate's discipline。
public struct BASAgentFabricSessionSnapshot:
    Sendable, Equatable, Hashable, Codable
{
    /// Unique snapshot ID (caller-supplied)。 Suggested format:
    /// `snap.<sessionID>.<turnCount>.<nanos>`。
    public let snapshotID: String
    /// Session this snapshot belongs to。 Used during restore
    /// to ensure we're restoring into the right session
    /// context。
    public let sessionID: String
    /// SDK version this snapshot was created under。 Caller
    /// (host) compares against current SDK version on restore
    /// to detect mismatch + trigger v1→v2 migration if needed。
    public let sdkVersion: String
    /// Roster of agents active in the session,sorted by
    /// agentID。
    public let agentRoster: [BASAgentSpec]
    /// Active persona overlays (user-supplied),sorted by
    /// personaID。
    public let userPersonas: [BASAgentPersonaSpec]
    /// Active persona overlays (host-supplied),sorted by
    /// personaID。
    public let hostPersonas: [BASAgentPersonaSpec]
    /// Active sovereign warrants,sorted by warrantID。
    public let warrants: [BASAgentPersonaSovereignWarrant]
    /// Watcher hint counter (per role × severity)。 Keyed by
    /// `"<role>.<severity>"` for stable Codable round-trip。
    public let watcherCounters: [String: Int]
    /// Monotonic timestamp at snapshot creation。 Used by
    /// restore validation to reject stale snapshots (e.g.
    /// older than 7 days) at host's discretion。
    public let createdAtNanos: Int64

    public init(
        snapshotID: String,
        sessionID: String,
        sdkVersion: String = "v1",
        agentRoster: [BASAgentSpec] = [],
        userPersonas: [BASAgentPersonaSpec] = [],
        hostPersonas: [BASAgentPersonaSpec] = [],
        warrants: [BASAgentPersonaSovereignWarrant] = [],
        watcherCounters: [String: Int] = [:],
        createdAtNanos: Int64 = 0
    ) {
        self.snapshotID = snapshotID
        self.sessionID = sessionID
        self.sdkVersion = sdkVersion
        // Sort by agentID
        self.agentRoster = agentRoster.sorted {
            $0.agentID < $1.agentID
        }
        self.userPersonas = userPersonas.sorted {
            $0.personaID < $1.personaID
        }
        self.hostPersonas = hostPersonas.sorted {
            $0.personaID < $1.personaID
        }
        self.warrants = warrants.sorted {
            $0.warrantID < $1.warrantID
        }
        // Stable Dictionary serialization via sorted keys is
        // handled by JSONEncoder.outputFormatting=[.sortedKeys]
        // at caller side。 We don't need to do anything here。
        self.watcherCounters = watcherCounters
        self.createdAtNanos = createdAtNanos
    }
}

// MARK: - Restore validation

/// Result of validating a deserialized snapshot before
/// restoring。 Returned by `BASAgentFabricColdRestart
/// .validate(...)` — caller uses `valid` to decide whether
/// to restore at all,`rejectedPersonaIDs` to drop forbidden
/// personas on restore,and `findings` for the L14 audit
/// ledger。
public struct BASColdRestartValidationResult:
    Sendable, Equatable, Hashable, Codable
{
    public let valid: Bool
    /// Per-validation-rule findings,sorted。 Empty when valid。
    public let findings: [String]
    /// Personas filtered out by forbidden detector — caller
    /// (host) MUST drop these on restore + may want to surface
    /// to the user (e.g. "your saved persona was rejected for
    /// safety reasons")。
    public let rejectedPersonaIDs: [String]

    public init(
        valid: Bool,
        findings: [String] = [],
        rejectedPersonaIDs: [String] = []
    ) {
        self.valid = valid
        self.findings = findings.sorted()
        self.rejectedPersonaIDs =
            rejectedPersonaIDs.sorted()
    }
}

/// Namespace for cold-restart pure-fn surface。 All static
/// members — caller does not instantiate。 The actual
/// persistence I/O (write/read snapshot bytes to disk /
/// keychain) is OUTSIDE this layer's scope — host's
/// app-lifecycle code handles I/O,this layer just provides
/// the Codable type + validation logic。
public enum BASAgentFabricColdRestart {

    /// Maximum allowed snapshot age in nanoseconds。 Default
    /// 7 days (host may override per session policy)。
    public static let defaultMaxAgeNanos: Int64 =
        7 * 24 * 60 * 60 * 1_000_000_000

    /// Validate a deserialized snapshot before restoring。
    /// Pure function。 Returns finding list + rejected persona
    /// IDs (forbidden patterns) for caller to act on。
    ///
    /// Validation checks:
    ///   1. SDK version compatibility (v1 only in current build)
    ///   2. Snapshot age ≤ maxAgeNanos (caller-supplied default)
    ///   3. All personas pass the forbidden detector — any
    ///      forbidden persona is dropped + reported in
    ///      `rejectedPersonaIDs`
    ///   4. Warrant IDs are non-empty (defensive against
    ///      corrupted snapshots)
    ///   5. Agent roster non-empty if session had personas
    ///      (orphan personas without agent refs)
    public static func validate(
        _ snapshot: BASAgentFabricSessionSnapshot,
        currentNanos: Int64 = 0,
        maxAgeNanos: Int64 = defaultMaxAgeNanos,
        sdkVersion: String = "v1"
    ) -> BASColdRestartValidationResult {
        var findings: [String] = []
        var rejected: [String] = []
        var valid = true

        // Rule 1:SDK version compatibility
        if snapshot.sdkVersion != sdkVersion {
            findings.append(
                "coldRestart.sdk-mismatch:snapshot=" +
                "\(snapshot.sdkVersion):current=\(sdkVersion)")
            valid = false
        }

        // Rule 2:age check (skip when currentNanos = 0,
        // meaning caller wants to skip age check)。
        // chapter 九百八十一.6 USER-PASS-8 MED-future-date fix:
        // also catch future-dated snapshots (createdAtNanos
        // > currentNanos)。 A negative-age computation would
        // silently bypass the age check before — could indicate
        // clock skew or tampering。
        if currentNanos > 0 &&
           snapshot.createdAtNanos > 0
        {
            if snapshot.createdAtNanos > currentNanos {
                findings.append(
                    "coldRestart.snapshot-future-dated:" +
                    "snapshot-nanos=" +
                    "\(snapshot.createdAtNanos):" +
                    "current-nanos=\(currentNanos)")
                valid = false
            } else {
                let age = currentNanos
                    - snapshot.createdAtNanos
                if age > maxAgeNanos {
                    findings.append(
                        "coldRestart.snapshot-too-old:" +
                        "age-nanos=\(age):" +
                        "max-nanos=\(maxAgeNanos)")
                    valid = false
                }
            }
        }

        // Rule 3:forbidden detector sweep across all personas
        for persona in snapshot.userPersonas +
            snapshot.hostPersonas
        {
            let f = BASAgentPersonaForbiddenDetector.scan(
                persona)
            if !f.isEmpty {
                rejected.append(persona.personaID)
                let patternList = f.map {
                    $0.pattern.rawValue
                }.sorted().joined(separator: ",")
                findings.append(
                    "coldRestart.forbidden-persona:" +
                    "\(persona.personaID):" +
                    "patterns=\(patternList)")
                // Doesn't fail validation — just drops the
                // persona (host can still restore the session
                // with non-forbidden personas)
            }
        }

        // Rule 4:warrant ID non-empty
        for w in snapshot.warrants
            where w.warrantID.isEmpty
        {
            findings.append(
                "coldRestart.warrant-corrupted:empty-id")
            valid = false
            break
        }

        // Rule 5:orphan-persona check (if personas reference
        // agentIDs not in roster)
        let rosterIDs = Set(snapshot.agentRoster.map {
            $0.agentID
        })
        for persona in snapshot.userPersonas +
            snapshot.hostPersonas
        {
            if !rejected.contains(persona.personaID) &&
               !rosterIDs.contains(persona.agentID)
            {
                findings.append(
                    "coldRestart.orphan-persona:" +
                    "\(persona.personaID):" +
                    "missing-agent=\(persona.agentID)")
                // Doesn't fail validation — host may restore
                // partially
            }
        }

        return BASColdRestartValidationResult(
            valid: valid,
            findings: findings,
            rejectedPersonaIDs: rejected)
    }
}
