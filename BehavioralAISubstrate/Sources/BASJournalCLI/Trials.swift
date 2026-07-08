// MARK: - Trials.swift — the "was I right?" ShadowTrial loop (increment 3)
//
// A journal DECISION is a bet. Increment 3 lets the operator OPEN a bet as a shadow trial, be
// re-surfaced its open bets each morning, and record the REAL outcome — fed back through the
// substrate's CORRECT public BASShadowTrialCoordinator.observe()/finalize() (NOT the private
// advanceOpenTrial), firing the H9-fixed optimistic-concurrency paths with real stakes and
// sealing every event into increment-2's Ed25519 sovereign ledger (the SAME ledger.sqlite).
//
//   swift run BASJournalCLI bet "DROP sampling-spec: 0.88x" -q "did latency actually regress?"
//   swift run BASJournalCLI review                # open bets, oldest first (morning surfacing)
//   swift run BASJournalCLI right <trial-prefix>  # the bet was right  → finalize .passed
//   swift run BASJournalCLI wrong <trial-prefix> [reason]  # was wrong → finalize .failed
//   swift run BASJournalCLI verdict <trial-prefix>         # the sovereign "was I right?" answer
//
// Cross-boot honesty (see TrialIndexStore): the coordinator is memory-only, so the CLI owns the
// open-trials index and RESUMES a persisted trial (coordinator.resumeTrial) before finalizing.
// The Ed25519 ledger remains the tamper-evident authority on what happened.
//
// Framing kept honest (mirror, not oracle): the substrate does NOT judge whether the bet was
// truly right — it has no window onto the real world. The OPERATOR records the outcome; the
// substrate faithfully records + gates it. promotionVerdict is a FAIL-CLOSED gate that follows
// deterministically from that recorded outcome (recorded-right ⇒ passed+sealed ⇒ allowed;
// recorded-wrong ⇒ failed+denied ⇒ denied). It reflects the operator's decision, never verifies it.

import Foundation
import BASMemory
import BASSovereign       // BASSovereignAuditLedger (the shared Ed25519 ledger reused for trials)
import BASOrchestration   // brings the BASSovereignAuditLedger→BASShadowTrialLedger bridge + factory

// MARK: - Wiring

private let trialIndexURL = journalDir.appendingPathComponent("trials_index.sqlite")
// Trials seal under the SAME session as the journal so `ledger` displays them and increment-2's
// truncation high-water check names a visible session (design §3).
private let betTrialScope = "qinao-journal.bet"

private func makeTrialCoordinator() throws -> BASShadowTrialCoordinator {
    // SAME Ed25519 ledger instance-builder as increment 2 → one shared, tamper-evident chain.
    let (coord, _) = try makeTrialCoordinatorAndLedger()
    return coord
}

/// Build the coordinator AND expose its ledger, so the resolve path can consult the authoritative
/// chain for idempotency (has this trial already been finalized?) before appending anything.
private func makeTrialCoordinatorAndLedger() throws
    -> (BASShadowTrialCoordinator, BASSovereignAuditLedger) {
    let ledger = try makeLedger()
    return (BASShadowTrialCoordinator.makeWithDefaultStateMachine(ledger: ledger), ledger)
}

private func makeTrialIndex() throws -> TrialIndexStore {
    try FileManager.default.createDirectory(at: journalDir, withIntermediateDirectories: true)
    return try TrialIndexStore(path: trialIndexURL.path)
}

/// If `trialID` already has a TERMINAL event on the authoritative ledger, return its outcome
/// ("passed"/"failed"/"blocked"); nil if not yet finalized. The ledger — not the sidecar — is the
/// source of truth for idempotency: a prior resolve's `finalize` may have sealed the terminal
/// event yet had its sidecar write-back fail, leaving the row stale-open. Re-finalizing would
/// double-seal the append-only chain, so the resolve path consults this first.
private func terminalLedgerOutcome(
    _ ledger: BASSovereignAuditLedger, trialID: String
) async -> String? {
    let vref = "shadow_trial\u{001F}\(trialID)"
    let terminal: [String: String] = [
        "L13.shadow_trial_passed": "passed",
        "L13.shadow_trial_failed": "failed",
        "L13.shadow_trial_blocked": "blocked"]
    for appended in await ledger.entries(forSession: journalSessionID)
        where appended.entry.verdictRef == vref {
        for rule in appended.entry.ruleIDs { if let o = terminal[rule] { return o } }
    }
    return nil
}

/// Strip the ASCII control separators the trial index uses to join list columns, so an operator
/// reason containing U+001F/U+001E cannot round-trip into phantom list elements (finding #8).
private func sanitizeListField(_ s: String) -> String {
    String(s.map { ($0 == "\u{001F}" || $0 == "\u{001E}") ? " " : $0 })
}

/// Deterministic candidate id from the decision atom, so the same decision always resolves to
/// the same candidate across process restarts.
private func candidateID(forAtom atomID: String) -> String { "cand-\(atomID)" }

private func makeCandidate(atomID: String, digest: String, summary: String) -> BASExperienceCandidate {
    BASExperienceCandidate(
        candidateID: candidateID(forAtom: atomID),
        sourceRefs: [digest],                    // ties the trial's cascade back to the decision
        candidateType: .rule,                    // a ship/drop bet is a governance rule
        summary: summary,
        stabilitySignal: 0.8,
        contaminationRisk: 0.1,
        hostScope: "qinao-journal",
        sovereignScope: "qinao-journal.bet.\(atomID)")
}

/// Rebuild the candidate + open record from a persisted index row so a later process can resume.
private func rebuild(from row: TrialIndexRow) -> (BASExperienceCandidate, BASShadowTrialRecord) {
    let candidate = makeCandidate(
        atomID: row.atomID, digest: row.decisionDigest, summary: row.decisionSummary)
    let record = BASShadowTrialRecord(
        trialID: row.trialID,
        candidateRef: row.candidateID,
        trialScope: row.trialScope,
        startAt: row.openedAt,
        observedEffects: row.observedEffects,
        failConditions: row.failConditions,
        completionState: row.state)
    return (candidate, record)
}

// MARK: - bet

func cmdBet(_ text: String, question: String?, deliberate: Bool = false) async throws {
    // Log + seal the decision exactly like `add` (reuses the increment-1/2/2b/3c path), then open a
    // trial on it. A fresh atom ⇒ a fresh candidate, so there is never a pre-existing open trial
    // to collide with.
    guard let atomID = try await logDecision(text, tag: "bet", deliberate: deliberate) else { return }
    let q = (question?.isEmpty == false) ? sanitizeListField(question!) : "was this decision right?"
    let digest = contentDigestHex(text)

    let coord = try makeTrialCoordinator()
    let candidate = makeCandidate(atomID: atomID.uuidString, digest: digest, summary: text)
    // The decision is already logged + sealed; if OPENING the trial fails, surface it distinctly
    // (partial success), don't let it read as a total failure of the whole `bet`.
    let record: BASShadowTrialRecord
    do {
        record = try await coord.submit(
            candidate: candidate,
            sessionID: journalSessionID,
            turnID: atomID.uuidString,
            trialScope: betTrialScope)
    } catch {
        FileHandle.standardError.write(Data(
            ("BET NOT OPENED — the decision is logged + sealed, but opening the shadow trial "
             + "failed: \(error)\n").utf8))
        exit(1)
    }

    // Index the open trial AFTER the ledger append succeeds (ledger is the durability anchor). If
    // the index write fails, the trial is genuinely OPEN + sealed on the authoritative ledger but
    // won't appear in `review` — surface that distinctly rather than swallowing it.
    do {
        try makeTrialIndex().insertOpen(TrialIndexRow(
            trialID: record.trialID,
            candidateID: candidate.candidateID,
            atomID: atomID.uuidString,
            decisionDigest: digest,
            decisionSummary: text,
            openQuestion: q,
            trialScope: betTrialScope,
            openedAt: record.startAt,
            state: record.completionState,
            observedEffects: [],
            failConditions: [],
            outcome: nil,
            closedAt: nil,
            verdictAllows: nil,
            verdictReasons: []))
    } catch {
        FileHandle.standardError.write(Data(
            ("BET SEALED BUT NOT INDEXED — the trial \(String(record.trialID.prefix(12))) is open "
             + "on the Ed25519 ledger, but the local review index write failed: \(error)\n"
             + "It will not appear in `review` until re-indexed.\n").utf8))
        exit(1)
    }

    let t = String(record.trialID.prefix(12))
    print("bet opened \(t)  ? \(q)")
    print("  resolve later:  right \(t)   |   wrong \(t) [reason]")
}

// MARK: - review (morning re-surfacing)

func cmdReview() async throws {
    let open = try makeTrialIndex().openRows()
    if open.isEmpty {
        print("no open bets — nothing to resolve. (open one with:  bet \"<decision>\" -q \"<question>\")")
        return
    }
    let iso = ISO8601DateFormatter(); iso.formatOptions = [.withFullDate]
    print("open bets — \(open.count) awaiting a real outcome:")
    for r in open {
        print("  \(String(r.trialID.prefix(12)))  opened \(iso.string(from: r.openedAt))")
        print("      decision: \(r.decisionSummary)")
        print("      ? \(r.openQuestion)")
        if !r.observedEffects.isEmpty {
            print("      notes: \(r.observedEffects.joined(separator: "; "))")
        }
    }
    print("resolve with:  right <id>   |   wrong <id> [reason]")
}

// MARK: - right / wrong (record the real outcome via the CORRECT public finalize())

/// Resolve an open bet with the operator's recorded outcome. `passed` = recorded right (seal
/// issued, no retraction); `!passed` = recorded wrong (seal denied, retraction queued).
///
/// ATOMICITY + IDEMPOTENCY (findings #0/#1/#2). The resolve is a SINGLE ledger operation —
/// finalize's own append-all-then-commit-all block (H9) — so a mid-sequence failure commits
/// nothing. The operator's `reason` is recorded in the sidecar (a readable note), NOT as a
/// separate `reportFailCondition` ledger append, so there is no two-phase window that a retry
/// could duplicate. And before finalizing we consult the AUTHORITATIVE ledger: if a prior
/// resolve already sealed a terminal event (its sidecar write-back may have failed, leaving the
/// row stale-open), we reconcile the sidecar instead of double-sealing the append-only chain.
private func resolveBet(prefix: String, passed: Bool, reason: String?) async throws {
    let index = try makeTrialIndex()
    let (rowOpt, count) = try index.resolve(prefix: prefix)
    guard let row = rowOpt else {
        print(count == 0
            ? "no bet with trial-id prefix \"\(prefix)\" (see `review`)"
            : "ambiguous: \(count) bets match \"\(prefix)\" — use more characters")
        return
    }
    guard row.isOpen else {
        print("that bet is already resolved (\(row.outcome ?? row.state)) — see `verdict \(prefix)`")
        return
    }

    let (candidate, record) = rebuild(from: row)
    let (coord, ledger) = try makeTrialCoordinatorAndLedger()

    // Idempotency guard: is this trial already finalized on the authoritative ledger? (A prior
    // resolve sealed it but its index write-back failed.) Reconcile the stale-open sidecar and
    // stop — re-finalizing would append a SECOND terminal seal for one trial.
    if let already = await terminalLedgerOutcome(ledger, trialID: record.trialID) {
        try index.close(
            trialID: record.trialID, outcome: already, closedAt: Date(),
            verdictAllows: already == "passed", verdictReasons: [],
            observedEffects: record.observedEffects, failConditions: record.failConditions)
        print("bet \(String(record.trialID.prefix(12))) was already resolved on the ledger "
            + "(\(already)) — reconciled the local index; nothing re-sealed")
        return
    }

    // Re-inject the persisted open trial (the coordinator is memory-only across boots), then
    // drive it with the substrate's real public finalize() — the ONE atomic append for a resolve.
    try await coord.resumeTrial(candidate: candidate, record: record)
    let done = try await coord.finalize(
        trialID: record.trialID,
        outcome: passed ? .passed : .failed,
        promotionRecommendation: passed ? "adopt" : "retract",
        sessionID: journalSessionID,
        turnID: row.atomID)

    // The operator's reason is a readable annotation kept in the sidecar (the ledger already
    // records the sovereign facts: the failed trial + denied seal + queued retraction).
    var fails = record.failConditions
    if !passed, let reason, !reason.isEmpty { fails.append(sanitizeListField(reason)) }

    let verdict = await coord.promotionVerdict(for: candidate.candidateID)
    try index.close(
        trialID: record.trialID,
        outcome: done.completionState,
        closedAt: done.endAt ?? Date(),
        verdictAllows: verdict.allowsPromotion,
        verdictReasons: verdict.reasonCodes,
        observedEffects: done.observedEffects,
        failConditions: fails)

    let t = String(record.trialID.prefix(12))
    print("recorded \(passed ? "RIGHT" : "WRONG") — bet \(t) finalized (\(done.completionState), "
        + "sealed to the Ed25519 ledger)")
    printVerdict(verdict, seal: await coord.seal(for: candidate.candidateID))
}

func cmdRight(_ prefix: String) async throws { try await resolveBet(prefix: prefix, passed: true, reason: nil) }
func cmdWrong(_ prefix: String, reason: String?) async throws {
    try await resolveBet(prefix: prefix, passed: false, reason: reason)
}

/// Deletion-doctrine hook (finding #9): `forget`ting a decision atom also secure-deletes any
/// trial-index rows for it, so a forgotten bet's operator-readable text is truly gone. No-op if
/// the trials index was never created. Best-effort: a purge failure is surfaced, not fatal — the
/// underlying journal entry is already tombstoned by the caller.
func purgeTrialsForAtom(_ atomID: UUID) {
    guard FileManager.default.fileExists(atPath: trialIndexURL.path) else { return }
    do {
        let removed = try makeTrialIndex().purge(atomID: atomID.uuidString)
        if removed > 0 { print("  also purged \(removed) trial-index row(s) for this decision") }
    } catch {
        FileHandle.standardError.write(Data(
            ("WARNING: could not purge trial-index rows for the forgotten decision: \(error)\n").utf8))
    }
}

// MARK: - verdict (the recorded outcome + promotion-gate result for a bet)
//
// Honest framing (findings #4/#5): the "verdict" is NOT an independent judgment of whether the
// bet was truly right — the substrate does not know the real world. It is the operator's own
// recorded outcome (right/wrong) plus the substrate's fail-closed PROMOTION-GATE decision, which
// deterministically follows from that recorded outcome (a recorded-right trial passes + seals ⇒
// promotion allowed; a recorded-wrong trial fails + denies ⇒ promotion denied). A mirror, not an
// oracle: it faithfully records + gates what the operator decided, it does not verify it.

func cmdVerdict(_ prefix: String) async throws {
    let (rowOpt, count) = try makeTrialIndex().resolve(prefix: prefix)
    guard let row = rowOpt else {
        print(count == 0
            ? "no bet with trial-id prefix \"\(prefix)\" (see `review`)"
            : "ambiguous: \(count) bets match \"\(prefix)\" — use more characters")
        return
    }
    let t = String(row.trialID.prefix(12))
    print("bet \(t)")
    print("  decision: \(row.decisionSummary)")
    print("  ? \(row.openQuestion)")
    if row.isOpen {
        print("  outcome: STILL OPEN — you haven't recorded a real outcome yet (right/wrong \(prefix))")
        return
    }
    print("  you recorded: \(row.outcome ?? row.state)  (closed"
        + (row.closedAt.map { " " + ISO8601DateFormatter().string(from: $0) } ?? "") + ")")
    if !row.failConditions.isEmpty { print("  your note: \(row.failConditions.joined(separator: "; "))") }
    // The fail-closed promotion gate that followed from the recorded outcome.
    if let allows = row.verdictAllows {
        print("  promotion gate: \(allows ? "ALLOWED (passed trial + approved seal)" : "DENIED")")
        if !row.verdictReasons.isEmpty {
            print("    reasons: \(row.verdictReasons.joined(separator: ", "))")
        }
    }
}

/// Print the fail-closed promotion-gate result that FOLLOWS FROM the operator's recorded outcome
/// — not an independent verdict on whether the bet was truly right.
private func printVerdict(_ v: BASEvolutionPromotionGateVerdict, seal: BASEvolutionSeal?) {
    let sealState = seal?.approvalState ?? "none"
    if v.allowsPromotion {
        print("  promotion gate: ALLOWED — recorded right ⇒ trial passed + seal issued (seal: \(sealState))")
    } else {
        print("  promotion gate: DENIED (seal: \(sealState)) — \(v.reasonCodes.joined(separator: ", "))")
    }
}
