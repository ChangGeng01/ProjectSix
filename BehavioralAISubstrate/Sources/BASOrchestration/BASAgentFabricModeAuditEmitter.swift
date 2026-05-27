// MARK: - BASAgentFabricModeAuditEmitter
// chapter 一千零七 / M3740 — wires `BASAgentFabricMode` from
// 🪜 SCAFFOLD → ✅ SUBSTRATE-OBSERVABLE (substrate-side wire)
//
// ## The scaffold condition
//
// Per `Docs/SCAFFOLD_VS_WIRED.md` ch 996:
//   > `BASAgentFabricMode` enum | 🪜 SCAFFOLD | stored on
//   > runtime,surfaced in outcome,but NO Sources/ branches
//   > on it。 Substrate doesn't switch behavior between
//   > `.observationOnly` and `.authoritative`。
//
// The mode signal was host-observable only — no substrate-side
// consumer made the signal substrate-observable for replay /
// audit。 A host running with `mode == .authoritative` left no
// substrate-side artifact distinguishing the turn from a
// `.observationOnly` turn。
//
// ## What ch 1007 ships
//
// `BASAgentFabricModeAuditEmitter` — pure-fn + ledger-bound
// helper that emits a per-turn audit entry capturing the mode
// flag。 Substrate-side consumer that converts the
// host-observable signal into a substrate-observable audit
// trail。
//
// The substrate's BEHAVIOR remains unchanged (per ch 994
// doctrine — `.authoritative` and `.observationOnly` still
// produce byte-equal dispatcher / merge / apply output)。 The
// CHANGE is that the mode flag now has a canonical audit
// representation that replay tooling can read。
//
// ## Audit entry shape
//
//   - `auditID`: `agentFabricMode.audit.<turnID>.<mode>`
//   - `verdictRef`: `agentFabricMode:<mode>`
//   - `signalRefs`: `["agentFabric.mode=<mode>"]` (single ref,
//     matches the reserved `agentFabric.*` prefix per ch 991
//     reserved-prefix discipline)
//   - `ruleIDs / actionRefs`: empty (observability entry)
//   - `actor`: `.system`
//
// ## Discipline
//
// - Additive only (red-line 7) — no existing API surface
//   touched
// - ADR-014 OPT-IN — callers must explicitly invoke
// - Pure-fn `buildEntry(...)` — deterministic byte-equal for
//   same inputs (modulo caller-supplied `now`)
// - `appendToLedger(...)` is async due to the ledger actor

import Foundation
import BASMemory
import BASSovereign
import BASRuntimeCore

public enum BASAgentFabricModeAuditEmitter {

    /// Build a sovereign audit entry capturing the per-turn
    /// fabric mode。 Pure-fn — same inputs always produce
    /// byte-equal output (modulo the `now` parameter)。
    ///
    /// - Parameters:
    ///   - mode: the BASAgentFabricMode flag for this turn
    ///   - sessionID: host session ID (REQUIRED — ledger
    ///     rejects empty)
    ///   - turnID: per-turn ID for ref namespacing
    ///   - now: timestamp to stamp on the entry
    /// - Returns: an unsigned `BASSovereignAuditEntry` ready to
    ///   append。 Caller's responsibility to call
    ///   `ledger.append(...)` if persisting。
    public static func buildEntry(
        mode: BASAgentFabricMode,
        sessionID: String,
        turnID: String,
        now: Date = Date()
    ) -> BASSovereignAuditEntry {
        let modeStr = mode.rawValue
        // chapter 一千零十.6 / M3765 — Round-21 CRITICAL-4 fix:
        // separator-injection class。 turnID is caller-supplied
        // (convention varies)。 Pre-fix `.` join → future
        // replay parser couldn't recover boundaries when turnID
        // contains `.`。 Post-fix U+001F between fixed-prefix
        // CLASS and caller-supplied turnID + modeStr (modeStr
        // is enum-constrained so safe,but symmetric format)。
        //
        // chapter 一千零十四 / M3785 — Round-21 LOW-2 fix:
        // explicit defense commentary。 Mirrors ch 983
        // `BASSovereignWarrantAuditBridge.buildEntry`
        // doctrine at lines 119-127 (ch 993 hardened canonical-
        // bytes opt-in disclosure)。 The two safe inputs here
        // are:
        //   - `modeStr`: ENUM-CONSTRAINED — safe from injection
        //     since `BASAgentFabricMode.rawValue` is fixed-set
        //     `observationOnly` or `authoritative`
        //   - `turnID`: CALLER-SUPPLIED — could legitimately
        //     contain `.` (host convention varies)。 Protected
        //     by U+001F boundary discipline below
        let sep = "\u{001F}"
        let auditID =
            "agentFabricMode.audit\(sep)\(turnID)\(sep)\(modeStr)"
        let verdictRef =
            "agentFabricMode\(sep)\(modeStr)"
        let signalRefs = [
            "agentFabric.mode=\(modeStr)",
        ]
        return BASSovereignAuditEntry(
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

    /// Append a per-turn fabric-mode audit entry to the L14
    /// sovereign audit ledger。 **Closes the
    /// `BASAgentFabricMode` substrate-observability gap** —
    /// turns running in `.authoritative` mode now leave a
    /// signed,hash-chained audit trail that replay tooling
    /// can read。
    ///
    /// Both `.observationOnly` and `.authoritative` modes are
    /// audited (with different verdictRef values) — symmetric
    /// per ch 977 defense-in-depth (host claiming
    /// observation-only after-the-fact has no audit support
    /// for that claim,a class of gap the L14 ledger
    /// explicitly closes)。
    ///
    /// - Throws: `BASSovereignAuditLedger.LedgerError` when
    ///   sessionID is empty (caller contract)
    @discardableResult
    public static func appendToLedger(
        mode: BASAgentFabricMode,
        sessionID: String,
        turnID: String,
        ledger: BASSovereignAuditLedger,
        now: Date = Date()
    ) async throws -> BASSovereignAuditLedger.AppendedEntry {
        let entry = buildEntry(
            mode: mode,
            sessionID: sessionID,
            turnID: turnID,
            now: now)
        return try await ledger.append(entry)
    }
}
