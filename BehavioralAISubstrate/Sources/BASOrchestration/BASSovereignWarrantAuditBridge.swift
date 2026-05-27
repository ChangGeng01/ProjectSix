// MARK: - BASSovereignWarrantAuditBridge
// chapter 九百八十三 / M3620 — Cross-Module Integration Arc ch1
//
// Closes ch 982.5 META-REVIEW cross-module Gap 7:**warrant
// validation audit refs are DEAD-LETTER**。
//
// ## The dead-letter condition
//
// `BASSovereignWarrantValidator.validate(...)` (BASMemory,
// ch 981.7 + 981.8 + 981.9 + 982 + 982.5 cascade) returns
// `BASWarrantValidationResult(valid: Bool,
// auditRefs: [String])`。 The auditRefs include refs like
// `agentExternal.warrant:granted:host-root=<id>\u{001F}per-agent=<id>`
// (with the U+001F unit-separator that ch 982.5 META-REVIEW C1
// carefully fixed to escape per RFC 8259 §7)。
//
// But NO in-substrate consumer pipes those refs into
// `BASSovereignAuditLedger`。 The refs are returned to the
// caller and discarded — the carefully-escaped sentinel
// characters,the identity-mismatch + expiration audit signals,
// the granted/rejected outcome — all produce NO audit trail
// in the live ledger。 Per ch 982.5 META-REVIEW honest
// disclosure,this was identified as the highest-value
// cross-module integration to close because:
//
//   1. The arc shipped 3 rounds of fixes (981.7 + 982 + 982.5)
//      to the U+001F separator handling that produces these
//      refs。 Without a consumer,those fixes solve a problem
//      that cannot manifest。
//   2. Per Root Law 7 (可回放),every warrant validation event
//      MUST be replayable from the audit ledger。 With no
//      append path,the validation outcome only exists in the
//      caller's stack frame — gone after the function returns。
//   3. Per the ch 977 defense-in-depth doctrine,the L14
//      sovereign ledger is the authoritative log for any
//      sovereign-significant decision。 Granting/rejecting a
//      collaborator-tier warrant IS a sovereign-significant
//      decision。 It MUST land in the ledger。
//
// ## Discipline
//
// Additive only (red-line 7)。 ADR-014 OPT-IN — callers MUST
// explicitly call `appendToLedger(...)` to wire validation →
// audit。 Existing callers of `BASSovereignWarrantValidator
// .validate(...)` are byte-equal unchanged — the dead-letter
// condition persists until they migrate。
//
// Pure-fn for `buildEntry(...)` (no I/O,deterministic byte-
// equal given same inputs)。 `appendToLedger(...)` is async
// because the ledger actor's `append(...)` is async。
//
// ## Audit entry shape
//
// Per `BASSovereignAuditEntry` schema in BASRuntimeCore:
//   - `auditID`:`agentExternal.warrant.audit.<turnID>
//     .<externalAgentID>.<outcome>` — uniquely identifies one
//     validation outcome within a (session,turn)
//   - `sessionID`:caller-supplied (matches the host's
//     session)
//   - `turnID`:caller-supplied (matches the per-turn ref
//     namespacing used throughout the fabric arc)
//   - `verdictRef`:`agentExternal.warrant:<outcome>
//     :<externalAgentID>` — verdictRef is a free-form ref;
//     prefix matches the reserved L14 prefix per ch 981.5 DH3
//     reserved-prefix discipline
//   - `ruleIDs`:empty (this is an observability entry — no
//     rule firings)
//   - `signalRefs`:`validationResult.auditRefs` verbatim
//     (this is the carefully-built ref string set with U+001F
//     sentinels per ch 981.9 + ch 982.5 C1 fixes)
//   - `actionRefs`:empty (warrant doesn't directly drive
//     actions)
//   - `snapshotRef`:empty (no upstream snapshot)
//   - `actor`:`.system` (substrate emits,not user)
//   - `signature`:empty — the ledger auto-signs per ch 716
//     第三刀 routed-seal discipline (line 392 of
//     BASSovereignAuditLedger.swift)
//   - `appendedAt`:caller-supplied (matches host's clock)

import Foundation
import BASMemory
import BASSovereign
import BASRuntimeCore

public enum BASSovereignWarrantAuditBridge {

    /// Build a sovereign audit entry from a warrant validation
    /// result。 Pure-fn — same inputs always produce byte-equal
    /// output (modulo the `now` parameter which the caller
    /// controls)。
    ///
    /// - Parameters:
    ///   - validationResult: from `BASSovereignWarrantValidator
    ///     .validate(...)` — carries `valid` flag + `auditRefs`
    ///     including the carefully-escaped U+001F sentinel refs
    ///   - sessionID: host session ID (REQUIRED — ledger rejects
    ///     empty)
    ///   - turnID: per-turn ID for ref namespacing
    ///   - externalAgentID: the external agent the warrant
    ///     authorized (or was rejected for)
    ///   - now: timestamp to stamp on the entry
    /// - Returns: an unsigned `BASSovereignAuditEntry` ready to
    ///   append to the ledger (the ledger's `append(...)` auto-
    ///   signs if `signature.isEmpty`)
    public static func buildEntry(
        validationResult: BASWarrantValidationResult,
        sessionID: String,
        turnID: String,
        externalAgentID: String,
        now: Date = Date()
    ) -> BASSovereignAuditEntry {
        let outcome = validationResult.valid ?
            "granted" : "rejected"
        // chapter 一千零十.6 / M3765 — Round-21 CRITICAL-3 fix:
        // separator-injection class hardening。 turnID +
        // externalAgentID are caller-supplied opaque strings —
        // externalAgentID legitimately contains `.` (convention
        // `<role>.<host>.v<N>`)。 Pre-fix `.` join → future
        // replay parser couldn't recover boundaries。 Post-fix
        // U+001F between fixed-prefix CLASS and caller-supplied
        // values。 Symmetric to Round-21 ch 1003 fix。
        let sep = "\u{001F}"
        let auditID =
            "agentExternal.warrant.audit\(sep)" +
            "\(turnID)\(sep)\(externalAgentID)\(sep)\(outcome)"
        let verdictRef =
            "agentExternal.warrant\(sep)\(outcome)\(sep)" +
            externalAgentID
        return BASSovereignAuditEntry(
            // chapter 九百九十三 / M3670 — opt into hardened
            // canonical-bytes format (U+001F inner / U+001E outer
            // separators) per cross-arc separator-class fix。
            // Warrant entries are the primary attack surface
            // flagged at ch 982 Round-8 since signalRefs include
            // caller-supplied opaque agentExternal.* strings that
            // could legitimately contain `,`。
            // ch 1011 / M3770 — Round-21 HIGH-1: shared constant
            schemaVersion: BASSovereignAuditEntry
                .hardenedSchemaVersion,
            auditID: auditID,
            sessionID: sessionID,
            turnID: turnID,
            verdictRef: verdictRef,
            ruleIDs: [],
            signalRefs: validationResult.auditRefs,
            actionRefs: [],
            snapshotRef: "",
            actor: .system,
            signature: "",
            appendedAt: now)
    }

    /// Append a warrant validation outcome to the L14 sovereign
    /// audit ledger。 **Closes ch 982.5 META-REVIEW Gap 7
    /// DEAD-LETTER condition** — the U+001F refs that ch 981.7
    /// + 982 + 982.5 carefully fixed now have an actual consumer
    /// piping them into the authoritative audit trail。
    ///
    /// Throws if the ledger rejects the entry — currently only
    /// when `sessionID` or `auditID` or `verdictRef` is empty
    /// (per `BASSovereignAuditLedger.append(...)` validation)。
    /// `buildEntry(...)` always produces non-empty `auditID` +
    /// `verdictRef`,so the only realistic throw path is empty
    /// `sessionID` — caller's responsibility per host contract。
    ///
    /// chapter 九百九十六.7 META-REVIEW Round-16 HIGH-1 doc-fix:
    /// `BASSovereignAuditLedger.append` is **actor-isolated
    /// synchronous-throw** (declared `throws -> ...` not `async
    /// throws`)。 From outside-the-actor callers it APPEARS async
    /// at the call site (actor hop adds implicit await),but the
    /// declaration itself isn't async。 Pre-fix this docstring
    /// said "async" which read as "uses cooperative suspension
    /// internally" — false。 No code change needed,just honest
    /// doc。
    @discardableResult
    public static func appendToLedger(
        validationResult: BASWarrantValidationResult,
        sessionID: String,
        turnID: String,
        externalAgentID: String,
        ledger: BASSovereignAuditLedger,
        now: Date = Date()
    ) async throws -> BASSovereignAuditLedger.AppendedEntry {
        let entry = buildEntry(
            validationResult: validationResult,
            sessionID: sessionID,
            turnID: turnID,
            externalAgentID: externalAgentID,
            now: now)
        return try await ledger.append(entry)
    }
}
