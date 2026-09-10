// MARK: - Council.swift — fire the multi-agent deliberation fabric (increment 5)
//
// The Ledger's prior increments fired the memory / audit-ledger / shadow-trial / L1–L14-spine
// paths. This one fires a substrate subsystem NO daily-use workload has touched before: the
// multi-agent STATE FABRIC (BASAgentFabricRuntime → BASAgentTurnDispatcher → the single-writer
// BASSharedStateGraph, via BASAgentMergeEngine + BASAgentMergeApplier). The mega-audit's dominant
// risk shape was "loaded gun" — HIGH-severity paths with NO production caller (dormant ≠ safe under
// ADR-014). This convenes a 4-of-9 mandatory-seat deliberation over a journaled decision, which:
//   • fires the JUST-HARDENED H8 single-writer-per-domain path TWICE — wireRosterToGraph →
//     registerWriterBatch (reserve-then-persist) AND per-accepted-delta writeObject auto-claim;
//   • fires the H17 duplicate-key uniquing guard in BASAgentMergeApplier;
//   • runtime-truth-checks the L-layer seat organs (audit blind-spot ③ — only concurrency-scanned).
//
// Mac-autonomous: every node on this path is Foundation-only pure compute — the seats' emit() are
// pure functions over slim value DTOs, the merge/apply are pure + one in-memory actor. NO 4B, NO
// GPU/Metal, NO organ. (Verified: 23 live fabric tests pass on this Mac; the whole path imports
// only Foundation; BASJournalCLI has no MLX/Metal/CoreML dependency.)
//
// ── MIRROR, not oracle (the honesty that governs this file) ───────────────────────────────────
// The fabric produces a DELIBERATED multi-seat view — what each sovereign seat SURFACED about the
// decision (scout: pressure; planner: a framed candidate; risk: reversibility; surface: a
// disposition) plus the merge's arbitration. It is NEVER a judgment that the logged decision is
// RIGHT: there is zero factual adjudication here. The surface seat's mode (answer / silentStub /
// block / delay) is a DISPOSITION toward rendering, not a correctness verdict.
//
// ── ANTI-VACUITY (the 3b lesson) ──────────────────────────────────────────────────────────────
// Increment 3b was judged vacuous and NOT shipped because it wired a dormant flag that changed
// nothing. This fire is load-bearing on PURPOSE: it FAILS CLOSED unless the fabric actually ran
// real deltas through the state graph — every accepted delta must have APPLIED, and the written
// refs must be DISTINCT (a silent writerIdentityMismatch or a same-ref collapse must NOT seal as a
// genuine fire). The durable, cross-boot proof is the SEAL: the folded deliberation is signed into
// the persistent Ed25519 ledger, verifiable later via `ledger`. The in-memory state graph is
// intentionally ephemeral — what survives is the sealed summary, so the fabricRef says the fabric
// RAN N real deltas, never that the graph state persists. The fabric MODE flag is deliberately
// unused: observationOnly and authoritative are byte-identical no-ops in the substrate, so relying
// on it would be exactly 3b's trap.

import Foundation
import BASMemory

/// The honest, injective-safe summary of one fabric deliberation, sealed as the ledger verdictRef.
struct CouncilOutcome: Sendable {
    /// `council|4of9|emitted:N|accepted:N|applied:N|domains:a+b+c|surface:<mode>` — sealed verbatim.
    let fabricRef: String
    let emittedCount: Int
    let acceptedCount: Int
    let appliedCount: Int
    let distinctDomains: [String]
    let surfaceMode: String
    let traceEventCount: Int
    /// Human-readable per-seat lines for the terminal view.
    let lines: [String]
}

enum CouncilError: Error, Equatable {
    /// The fabric did not produce a genuine multi-domain write — refuse to seal (fail-closed).
    case fireIncomplete(String)
}

/// Deterministic candidate ID from the decision text — FNV-1a over the bytes, NOT `hashValue`
/// (which is per-process seeded and would make the sealed fabricRef non-reproducible across runs).
private func councilCandidateID(_ decision: String) -> String {
    var h: UInt64 = 0xcbf2_9ce4_8422_2325
    for b in decision.utf8 { h = (h ^ UInt64(b)) &* 0x0000_0100_0000_01b3 }
    return "cand-" + String(h, radix: 16)
}

/// The renderFrame delta's disposition mode, read from the surface seat's emitted patch (never
/// assumed). Honest fallback to nil if the encoding shape changes — we surface "unknown", we do
/// not fabricate a mode.
private func councilSurfaceMode(_ deltas: [BASAgentDelta]) -> String? {
    guard let surface = deltas.first(where: { $0.targetObjectRef.hasPrefix("renderFrame#") })
    else { return nil }
    guard let r = surface.patchJson.range(of: "\"mode\":\"") else { return nil }
    let tail = surface.patchJson[r.upperBound...]
    let mode = tail.prefix(while: { $0 != "\"" })
    return mode.isEmpty ? nil : String(mode)
}

/// The write-domain of a state-graph object ref (`<domain>#<objectID>` → `<domain>`).
private func councilDomain(ofRef ref: String) -> String {
    String(ref.prefix(while: { $0 != "#" }))
}

/// Fire the 4-of-9 mandatory-seat deliberation fabric over one decision string and fold the result
/// into an honest, injective-safe fabricRef. Mac-autonomous; deterministic (pinned clock).
///
/// Throws `CouncilError.fireIncomplete` if the fire was not genuine (some accepted delta did not
/// apply, or the written refs collapsed) — the caller must NOT seal a non-fire.
func fireCouncil(on decision: String) async throws -> CouncilOutcome {
    let cand = councilCandidateID(decision)
    func seat(_ id: String, _ role: BASAgentRole, _ dom: BASStateDomain) -> BASAgentSpec {
        BASAgentSpec(agentID: id, role: role, writeDomains: [dom],
                     defaultLeaseProfile: .hotSeat, visibility: .high)
    }
    let riskAgentID = "risk.ledger.v1"
    // Each of the 4 mandatory seats claims exactly ONE distinct write-domain — overlapping domains
    // would throw domainAlreadyClaimed at wire time (that is the SWPD invariant, working as intended).
    let roster = BASAgentTurnRoster(
        scout:   seat("scout.ledger.v1",   .scout,   .situationField),
        planner: seat("planner.ledger.v1", .planner, .candidateFrontier),
        risk:    seat(riskAgentID,         .risk,    .riskField),
        surface: seat("surface.ledger.v1", .surface, .renderFrame))

    // Structured input derived from the decision string with NO model. Populate all four mandatory
    // seats so each emits a real delta (an empty input would emit only the surface silentStub — a
    // degenerate, near-vacuous fire).
    let input = BASAgentTurnInput(
        turnID: "ledger.council." + cand,
        scout: BASScoutInput(pressureSignals: [decision]),
        plannerCandidates: [BASPlannerCandidate(
            candidateID: cand,
            title: String(decision.prefix(60)),
            actionSummary: decision,
            confidence: 0.5)],
        risk: BASRiskInput(candidates: [BASRiskCandidate(candidateID: cand, reversibility: 0.5)]),
        surface: BASSurfaceInput(acceptedCandidateID: cand),
        priorityContext: BASMergePriorityContext(
            riskAgentIDs: [riskAgentID], evidenceConfidenceFloor: 0.5),
        nowNanos: 0)   // PINNED — the sealed fabricRef must be a reproducible function of the text.

    let graph = BASSharedStateGraph()            // in-memory; the durable record is the SEAL.
    let trace = BASAgentTraceLog()
    let runtime = BASAgentFabricRuntime(roster: roster, graph: graph, traceLog: trace)
    try await runtime.wireRosterToGraph()        // fires H8 registerWriterBatch (reserve-then-persist)
    let result = await runtime.dispatchTurn(input: input)   // fires H8 writeObject + H17 merge applier

    // ── Anti-vacuity fail-closed proof (refute-panel hardening #1) ──
    guard !result.applyOutcomes.isEmpty else {
        throw CouncilError.fireIncomplete("no deltas applied — the fabric produced nothing to record")
    }
    let notApplied = result.applyOutcomes.filter { !$0.applied }
    guard notApplied.isEmpty else {
        let why = notApplied.map { "\($0.deltaID):\($0.errorReason)" }.joined(separator: ",")
        throw CouncilError.fireIncomplete("an accepted delta did not apply (\(why))")
    }
    let writtenRefs = result.applyOutcomes.map { $0.writtenRef }
    guard Set(writtenRefs).count == writtenRefs.count else {
        throw CouncilError.fireIncomplete("written refs collapsed to the same object — not a genuine multi-domain fire")
    }
    // Cross-check the actor graph actually holds one object per distinct written ref.
    let graphCount = await graph.objectCount()
    guard graphCount == Set(writtenRefs).count else {
        throw CouncilError.fireIncomplete("state-graph object count (\(graphCount)) != distinct writes (\(Set(writtenRefs).count))")
    }

    let distinctDomains = Set(writtenRefs.map(councilDomain(ofRef:))).sorted()
    let surfaceMode = councilSurfaceMode(result.emittedDeltas) ?? "unknown"
    let traceCount = await trace.events(forTurn: input.turnID).count

    let fabricRef = "council|4of9"
        + "|emitted:\(result.emittedDeltas.count)"
        + "|accepted:\(result.mergeResult.acceptedDeltaIDs.count)"
        + "|applied:\(result.applyOutcomes.count)"
        + "|domains:\(distinctDomains.joined(separator: "+"))"
        + "|surface:\(surfaceMode)"

    let lines: [String] = [
        "  scout    → situationField    (pressure signals surfaced)",
        "  planner  → candidateFrontier (1 candidate framed)",
        "  risk     → riskField         (reversibility assessed)",
        "  surface  → renderFrame        disposition:\(surfaceMode)",
    ]
    return CouncilOutcome(
        fabricRef: fabricRef,
        emittedCount: result.emittedDeltas.count,
        acceptedCount: result.mergeResult.acceptedDeltaIDs.count,
        appliedCount: result.applyOutcomes.count,
        distinctDomains: distinctDomains,
        surfaceMode: surfaceMode,
        traceEventCount: traceCount,
        lines: lines)
}
