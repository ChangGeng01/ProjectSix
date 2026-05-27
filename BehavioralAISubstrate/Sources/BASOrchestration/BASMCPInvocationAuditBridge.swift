// MARK: - BASMCPInvocationAuditBridge
// chapter 一千零三 / M3720 — closes `validateMCPInvocation`
// scaffold per `Docs/SCAFFOLD_VS_WIRED.md` forward-closure item #4
//
// ## The scaffold condition
//
// `BASAgentFabricAdapters.validateMCPInvocation(_:against:)`
// (BASOrchestration,ch 990) returns `(accepted: Bool,
// auditRefs: [String])` — the audit refs include things like
// `agentMCP.permit:granted:server=<id>:tool=<id>:scope=<scope>`
// and `agentMCP.permit:rejected:reason=blocked-mode:server=<id>`。
//
// But NO in-substrate consumer pipes those refs into the
// `BASSovereignAuditLedger`。 Same dead-letter shape as ch 983's
// pre-fix warrant-validation refs:the validation outcome only
// exists in the caller's stack frame and is discarded after the
// function returns。 Per Root Law 7 (可回放),every MCP-permit
// decision MUST be replayable from the audit ledger。
//
// `Docs/SCAFFOLD_VS_WIRED.md` ch 996 inventory listed this as
// forward-closure item #4:
//   > **`validateMCPInvocation`** → host pipeline calls it
//   > before any actual MCP tool dispatch + appends audit ref
//   > to the ledger。
//
// Ch 1003 ships exactly that — mirroring the ch 983
// `BASSovereignWarrantAuditBridge` shape verbatim。
//
// ## Discipline
//
// - Additive only (red-line 7)。 ADR-014 OPT-IN — callers MUST
//   explicitly call `appendToLedger(...)` to wire validation →
//   audit。 Existing callers of `validateMCPInvocation` are
//   byte-equal unchanged。
// - Pure-fn for `buildEntry(...)` (no I/O,deterministic
//   byte-equal given same inputs;`now` controlled by caller)。
// - `appendToLedger(...)` is async because the ledger's
//   `append(...)` lives behind an actor hop。
//
// ## Audit entry shape
//
// Per `BASSovereignAuditEntry` schema in BASRuntimeCore:
//   - `auditID`:`agentMCP.invocation.audit.<turnID>
//     .<serverID>.<toolID>.<outcome>` — uniquely identifies one
//     MCP-permit decision within a (session,turn,server,tool)
//   - `sessionID`:caller-supplied (matches host's session)
//   - `turnID`:caller-supplied (matches per-turn namespacing)
//   - `verdictRef`:`agentMCP.invocation:<outcome>
//     :<serverID>:<toolID>` — verdictRef is a free-form ref;
//     prefix matches the reserved L14 `agentMCP.` prefix per
//     ch 991 reserved-prefix discipline
//   - `ruleIDs`:empty (observability entry,no rule firings)
//   - `signalRefs`:the `auditRefs` from `validateMCPInvocation`
//     verbatim,carrying the gate's full granted/rejected
//     diagnostic
//   - `actionRefs`:empty (the MCP invocation itself drives the
//     action;this is the permit-gate decision,not the action
//     execution audit)
//   - `snapshotRef`:empty (no upstream snapshot)
//   - `actor`:`.system` (substrate emits,not user)
//   - `signature`:empty — ledger auto-signs per ch 716 第三刀
//     routed-seal discipline
//   - `appendedAt`:caller-supplied (matches host's clock)

import Foundation
import BASMemory
import BASPolicy
import BASSovereign
import BASRuntimeCore

public enum BASMCPInvocationAuditBridge {

    /// Build a sovereign audit entry from an MCP invocation
    /// permit decision。 Pure-fn — same inputs always produce
    /// byte-equal output (modulo the `now` parameter)。
    ///
    /// - Parameters:
    ///   - invocation: the MCP envelope the caller assembled
    ///   - permit: the live `BASActionPermit` used as the gate
    ///   - validation: the `(accepted, auditRefs)` output from
    ///     `BASAgentFabricAdapters.validateMCPInvocation(...)`
    ///   - sessionID: host session ID (REQUIRED — ledger rejects
    ///     empty;caller's responsibility)
    ///   - turnID: per-turn ID for ref namespacing
    ///   - now: timestamp to stamp on the entry
    /// - Returns: an unsigned `BASSovereignAuditEntry` ready to
    ///   append to the ledger
    public static func buildEntry(
        invocation: BASMCPInvocation,
        permit: BASActionPermit,
        validation: (accepted: Bool, auditRefs: [String]),
        sessionID: String,
        turnID: String,
        now: Date = Date()
    ) -> BASSovereignAuditEntry {
        let outcome = validation.accepted ?
            "granted" : "rejected"
        let auditID =
            "agentMCP.invocation.audit." +
            "\(turnID).\(invocation.mcpServerID)." +
            "\(invocation.toolID).\(outcome)"
        let verdictRef =
            "agentMCP.invocation:\(outcome):" +
            "\(invocation.mcpServerID):" +
            "\(invocation.toolID)"
        // chapter 一千零三 honest scope:`signalRefs` carries the
        // full gate diagnostic verbatim。 Some refs encode permit
        // metadata that downstream replay needs (e.g. permit
        // toolScope when scope-denied)。 We do NOT inject permit
        // fields directly — the gate already encodes the ones
        // that matter into its audit refs (`scope=<toolScope>` in
        // the granted/rejected refs)。 Adding permit.id again here
        // would create a duplication risk per ch 956.5 single-
        // source-of-truth discipline。
        let _ = permit  // intentionally unused — kept in signature
        // for caller-doc clarity (the permit is the GATE the
        // decision was made against),but its fields are already
        // in `validation.auditRefs` so we don't duplicate
        return BASSovereignAuditEntry(
            // ch 993 hardened canonical-bytes format — MCP refs
            // include `=` + `:` + caller-supplied opaque server /
            // tool IDs that could legitimately contain `,`。 Same
            // attack surface class as warrant entries。
            schemaVersion: "1.1.0",
            auditID: auditID,
            sessionID: sessionID,
            turnID: turnID,
            verdictRef: verdictRef,
            ruleIDs: [],
            signalRefs: validation.auditRefs,
            actionRefs: [],
            snapshotRef: "",
            actor: .system,
            signature: "",
            appendedAt: now)
    }

    /// Validate + append in one call。 Combines:
    ///   1. `BASAgentFabricAdapters.validateMCPInvocation(...)`
    ///   2. `buildEntry(...)`
    ///   3. `ledger.append(...)`
    ///
    /// CRITICAL:both granted AND rejected outcomes get
    /// appended to the ledger。 Denied calls are AS auditable
    /// as granted calls — a host pipeline that silently drops
    /// rejected invocations would lose attack-surface signal
    /// per ch 977 defense-in-depth doctrine。
    ///
    /// - Parameters: as `buildEntry(...)` plus the `ledger`
    /// - Returns: tuple of `(validation, appendedEntry)`。
    ///   `validation.accepted` tells caller whether to proceed
    ///   with the MCP call;`appendedEntry` is the ledger
    ///   receipt (includes signed hash) for downstream
    ///   verification。
    /// - Throws: `BASSovereignAuditLedger.LedgerError` when
    ///   sessionID is empty (caller contract violation)
    @discardableResult
    public static func validateAndAppend(
        invocation: BASMCPInvocation,
        permit: BASActionPermit,
        sessionID: String,
        turnID: String,
        ledger: BASSovereignAuditLedger,
        now: Date = Date()
    ) async throws -> (
        validation: (accepted: Bool, auditRefs: [String]),
        appendedEntry: BASSovereignAuditLedger.AppendedEntry
    ) {
        let validation = BASAgentFabricAdapters
            .validateMCPInvocation(invocation, against: permit)
        let entry = buildEntry(
            invocation: invocation,
            permit: permit,
            validation: validation,
            sessionID: sessionID,
            turnID: turnID,
            now: now)
        let appended = try await ledger.append(entry)
        return (validation: validation, appendedEntry: appended)
    }

    /// Append-only variant when the caller already has a
    /// validation result (e.g. from a prior call to
    /// `validateMCPInvocation`)。 Skips the validate step。
    /// Useful when multiple decisions get audited in a batch。
    @discardableResult
    public static func appendToLedger(
        invocation: BASMCPInvocation,
        permit: BASActionPermit,
        validation: (accepted: Bool, auditRefs: [String]),
        sessionID: String,
        turnID: String,
        ledger: BASSovereignAuditLedger,
        now: Date = Date()
    ) async throws -> BASSovereignAuditLedger.AppendedEntry {
        let entry = buildEntry(
            invocation: invocation,
            permit: permit,
            validation: validation,
            sessionID: sessionID,
            turnID: turnID,
            now: now)
        return try await ledger.append(entry)
    }
}
