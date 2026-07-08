// MARK: - Verdict.swift — the L1–L14 governance verdict on a journal entry (increment 2b)
//
// Increment 2 sealed each add with the hardcoded string "admit:governed" — an ASSERTION that
// the entry was governed, with nothing behind it. Increment 2b actually RUNS the entry through
// the substrate's L1–L14 spine (BASCognitiveBrain.process → EBrainRuntimeCoordinator.runTurn) and
// folds the resulting sovereign GOVERNANCE verdict into the seal's verdictRef. So "governed" is
// no longer a claim — it is an earned, tamper-evidently proven disposition.
//
// This is fully Mac-runnable: runTurn's synchronous spine touches only the small in-tree 68 KB
// BASContextClassifier.mlmodel — never the 4B MLX model. The sealed verdict is byte-identical
// whether computed on this Mac or on device (a device's neural core feeds prose/organ artifacts
// only, never the risk→permit→verdict lattice), so there is nothing device-gated to defer.
//
// ── MIRROR, not oracle (the honesty that governs every string here) ──────────────────────────
// gov2:<level> is the sovereign GOVERNANCE verdict — the L1–L14 lattice's disposition toward this
// write (pass / throttle / shadowLock / … / deadStop). It is a pure function of the entry text +
// fixed caller metadata + runtime mode. It is NOT a grounded judgment that the logged decision is
// *right*: there is zero factual adjudication on this path (the 4B abstains, the FactBank empty).
//
// OBSERVED REALITY (verified by running it, not just reading it — the comment must not lie):
// for a private journal write the sovereign lattice does NOT rubber-stamp. A benign entry seals
// `gov2:shadowLock | permit:answer | risk:low | abstain` — the substrate abstains by default
// because it cannot sovereignly GROUND an ungrounded private write; it effectively never returns
// pass/allow here. A manipulation-cued entry ("must … immediately … everyone says …") ESCALATES
// to `gov2:memoryFreeze | permit:delay | risk:high | abstain`. So the useful, honest signal is the
// ESCALATION BAND (benign shadowLock/low vs risky memoryFreeze+/high), NOT a green light. The
// value over the old hardcoded "admit:governed": that string ASSERTED governance with nothing
// behind it; gov2:<level> is the lattice's real, deterministic, tamper-evidently-sealed
// disposition. gov2:unavailable marks that the spine could not run at all. (The `allow` branch
// below is kept correct-if-reached, but is effectively unreachable for journal writes today.)

import Foundation
import BASHostKit
import BASRuntimeCore
import BASPolicy

/// A calm, FIXED device frame. A journal add is a private local write, not a live device turn, so
/// we pin the device state to a constant: the verdict is then a function of the ENTRY TEXT + fixed
/// metadata only. Sampling real battery/thermal would let the same entry seal two different
/// verdictRefs across runs, muddying the tamper-evident record — so this must stay constant.
private func ledgerDeviceState() -> BASDeviceState {
    BASDeviceState(
        batteryLevel: 1.0, thermalLevel: .nominal, memoryFreeMB: 4096,
        networkState: .online, foregroundState: .foreground,
        cpuLoad: 0, gpuLoad: 0, npuAvailable: true, latencyBudgetMs: 1500)
}

/// One cognitive brain per process. Construction compiles the small .mlmodelc, so we build it at
/// most once and reuse across a batch of adds in the same invocation. Returns nil (never throws)
/// if the brain can't construct (model missing / non-Apple host) — the caller degrades honestly.
private actor BrainBox {
    private var brain: BASCognitiveBrain?
    private var inFlight: Task<BASCognitiveBrain?, Never>?

    func get() async -> BASCognitiveBrain? {
        if let brain { return brain }
        // Share a single in-flight construction: a second caller arriving DURING the await must
        // await the same task, not see a half-set flag and early-return nil (actor reentrancy).
        // The completed task is retained so a failed construct (nil) is not retried.
        if let inFlight { return await inFlight.value }
        // makeWithDefaults is enough for the verdict; makeWithAllPilots only wires native perf
        // pilots (none change the verdict) and pulls a Rust XCFramework that throws off-Apple.
        let task = Task { try? await BASCognitiveBrain.makeWithDefaults() }
        inFlight = task
        let made = await task.value
        brain = made
        return made
    }
}
private let brainBox = BrainBox()

/// Run the entry text through the L1–L14 spine and return an HONEST governance verdictRef, or nil
/// if the brain cannot construct (caller degrades to a labeled "gov2:unavailable" fallback).
func governanceVerdictRef(action: String, for text: String) async -> String? {
    guard let brain = await brainBox.get() else { return nil }
    let result = await brain.process(text, deviceState: ledgerDeviceState(), hostID: "ledger.host")
    return honestVerdictRef(action: action, result: result)
}

/// Fold the sovereign verdict + permit + risk into a single printable, injective-safe verdictRef.
/// Format: `<action>|gov2:<level>|permit:<mode>|risk:<risk>|<allow|abstain>`. All fields use stable
/// `.rawValue`s; the "|"/":" delimiters are safe under the seal's hardened 1.2.0 canonical form
/// (length-prefixed, injective) and print cleanly in `ledger`.
func honestVerdictRef(action: String, result: BASEBrainTurnResult) -> String {
    let permit = result.actionPermit.mode.rawValue
    let risk = result.riskCard.riskLevel.rawValue
    guard let v = result.sovereignVerdict else {
        // Fail-closed: an absent sovereign verdict is NOT a pass.
        return "\(action)|gov2:absent|permit:\(permit)|risk:\(risk)|abstain"
    }
    // Structural abstention — there is no single "abstain" Bool; it is any of: a verdict above
    // pass, a refusal-only user stub, or a WITHHELD/guarded permit mode. Classify the permit off
    // the substrate's own `isProtective` (delay/draftOnly/localOnly/block/replace/escalate) so this
    // can't drift from the substrate — a hand-maintained set had omitted draftOnly/localOnly.
    let abstaining = v.verdictLevel > .pass
        || v.userStubMode == .refusalOnly
        || result.actionPermit.mode.isProtective
    let disposition = abstaining ? "abstain" : "allow"
    return "\(action)|gov2:\(v.verdictLevel.rawValue)|permit:\(permit)|risk:\(risk)|\(disposition)"
}
