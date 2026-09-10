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
//   - `auditID`:`agentMCP.invocation.audit\u{001F}<turnID>
//     \u{001F}<serverID>\u{001F}<toolID>\u{001F}<outcome>` —
//     uniquely identifies one MCP-permit decision within a
//     (session,turn,server,tool)。 chapter 一千零十五 /
//     M3800 — Round-24 MED-2 fix:header doc was showing
//     pre-Round-21 `.` separator format which contradicted
//     the actual post-Round-21 U+001F format。 Doc now matches
//     code at lines 108-115。
//   - `sessionID`:caller-supplied (matches host's session)
//   - `turnID`:caller-supplied (matches per-turn namespacing)
//   - `verdictRef`:`agentMCP.invocation\u{001F}<outcome>
//     \u{001F}<serverID>\u{001F}<toolID>` — verdictRef is a
//     free-form ref;prefix matches the reserved L14
//     `agentMCP.` prefix per ch 991 reserved-prefix
//     discipline + Round-21 CRITICAL-1/2 separator hardening
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
        // chapter 一千零十.6 / M3765 — Round-21 CRITICAL-1 fix:
        // separator-injection class。 mcpServerID legitimately
        // contains `.` (e.g. "mcp.filesystem") — pre-fix
        // auditID joined fields with `.` so a future replay
        // parser could not recover boundaries。 Post-fix U+001F
        // between fixed-prefix and caller-supplied values。 Same
        // discipline as ch 982.5 + Round-20 ch 1006/1008 fixes,
        // now applied uniformly to auditID + verdictRef across
        // all 3 audit-bridge sites (ch 983, ch 1003, ch 1007)。
        let sep = "\u{001F}"
        let auditID =
            "agentMCP.invocation.audit\(sep)" +
            "\(turnID)\(sep)\(invocation.mcpServerID)\(sep)" +
            "\(invocation.toolID)\(sep)\(outcome)"
        let verdictRef =
            "agentMCP.invocation\(sep)\(outcome)\(sep)" +
            "\(invocation.mcpServerID)\(sep)" +
            "\(invocation.toolID)"
        // chapter 一千零三 honest scope:`signalRefs` carries the
        // full gate diagnostic verbatim。 Permit metadata that
        // matters (e.g. toolScope when scope-denied) is encoded
        // BY THE GATE into `validation.auditRefs` — we don't
        // re-inject。 Single-source-of-truth (ch 956.5 + ch
        // 1010.5 single-canonical doctrine)。
        //
        // chapter 一千零十.6 / M3765 — Round-21 MED-5 fix:
        // pre-fix `let _ = permit` documented the parameter as
        // intentionally-unused-but-kept-for-caller-doc。 Round-21
        // audit flagged this as dead-code surface that's
        // divergence-prone (declared-but-not-used)。 We RESPECT
        // the original doctrine (permit IS the gate context,
        // matters for caller clarity) by adding a structural
        // assertion that the permit-derived auditRefs in
        // `validation` are non-empty when permit allows tools。
        // This makes the parameter behaviorally-checked rather
        // than syntactically-discarded。
        // audit M-l / orchestration MED-1: this used to `precondition(accepted → !auditRefs.empty)`
        // — a feedable PROCESS CRASH on a caller-supplied validation tuple. An audit bridge must
        // NEVER take down the sovereign process on a downstream gate bug; the fail-safe is to
        // RECORD the anomaly in the (tamper-evident) audit trail, not lose the whole process. Byte-
        // equal for every normal case (accepted-with-refs / rejected); only the anomalous
        // accepted-with-empty-refs case changes from a trap to a recorded diagnostic signalRef.
        let signalRefs: [String]
        if validation.accepted && validation.auditRefs.isEmpty {
            signalRefs = ["anomaly\(sep)accepted-with-empty-auditRefs\(sep)gate-internal-bug"]
        } else {
            signalRefs = validation.auditRefs
        }
        _ = permit  // intentionally unused — kept in signature
        // for caller-doc clarity (the permit IS the gate the
        // decision was made against);its fields are already
        // in validation.auditRefs by gate construction
        return BASSovereignAuditEntry(
            // ch 993 hardened canonical-bytes format — MCP refs
            // include `=` + `:` + caller-supplied opaque server /
            // tool IDs that could legitimately contain `,`。 Same
            // attack surface class as warrant entries。
            // ch 1011 / M3770 — Round-21 HIGH-1: shared constant
            schemaVersion: BASSovereignAuditEntry
                .hardenedSchemaVersion,
            auditID: auditID,
            sessionID: sessionID,
            turnID: turnID,
            verdictRef: verdictRef,
            ruleIDs: [],
            signalRefs: signalRefs,
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
