# MLX lever adoption seam — device-proven, adoption-ready, NOT live (2026-07-11)

The honest close of the root disease (design workflow wf_49e1a3cf, adversary-confirmed): the four
MLX-island decode levers — cross-restart warm-seat KV reuse, cross-turn suffix corpus (1.07-1.41×),
per-seat council fan-out, tier-0-via-MLX — are **device-proven and adoption-ready, but NOT live**.
A real consumer cannot be manufactured from the assistant's keyboard: a consumer differs from the
DeviceTestApp probe harness on the one axis code cannot fabricate — **organic, recurrent, unscripted
use for the answer's own sake**. Building a self-run reference executable would be "another target,"
not "firing the gun into a real workload" — the exact 3b/上膛未击发 trap in fresh clothes. So this
is an OPERATOR PRODUCT DECISION, and the code half is already done: the seam is clean and frozen here.

## The adoption seam (already built — a host adopts, does not rebuild)

1. **Dependency injection**: `BASLLMNeuralCoreService` consumes the `BASOrganAdapter` protocol via
   ADR-014 opt-in DI (`makeEngine(adapter:)`, BASLLMNeuralCoreService.swift:121). `MLXOrganAdapter`
   conforms. A host injects the MLX adapter; every decorator forwards transparently.

2. **The one plumbing contract (the footgun)**: the cross-turn win is gated on
   `request.sessionID != nil`. `draft(_:purpose:)` (MLXOrganAdapter+PromptLookup.swift:157) routes to
   `draftMultiTurn` IFF sessionID is set; **every current production caller passes nil**, so the
   corpus store is empty = plain prompt-lookup = the 1.07-1.41× is unreachable. To adopt:
   - pass ONE stable non-nil `sessionID` per conversation across turns;
   - do NOT also re-send chat history in `request.context` (the re-rendered prompt would re-contain
     prior turns → duplicate corpus appends + premature FIFO eviction);
   - `clearSession(sessionID:)` resets the corpus.

3. **Warm-seat cross-restart** (device-proven, spillRestoreCount 0→1, restore-turn prefill 180.5ms):
   a host app calls `snapshotWarmSeats()` on scenePhase→background; a relaunch's first same-seat turn
   restores instead of cold-prefilling. Default-on spill lane; restore-miss falls back to cold prefill,
   byte-identical. Needs a host that holds a long-lived adapter across an app lifecycle.

## What is NOT this seam (rejected as category errors)

- **Routing The Ledger through the 4B**: NO. `Verdict.swift` seals a byte-identical DETERMINISTIC
  verdict; `BASJournalCLI` has ZERO MLX dependency BY DESIGN. Bolting a stochastic 4B on breaks
  determinism and imports the documented sub-7B factual-sycophancy weakness — bending a correct
  workload to feed an orphaned lever is the fake-consumer trap inverted.
- **A self-run reference `bas-chat` executable**: NO. An executable only the builder/test-suite runs
  is a harness by definition, regardless of how real the 4B call is; its telos is to make the lever
  fire, not to consume the output. Non-vacuity is organic recurrent use that accrues after the
  assistant is gone — no code manufactures it.

## Honest status

The spine levers (ε→effort→tier, tier-0-via-spine, grounding) HAVE a real low-flow consumer — The
Ledger — that is genuine, not theater; leave them. The four MLX-island levers wait on exactly one
thing code cannot provide: a human or host that lives in the output daily. The operator's choice:
**(A)** commit to daily-dogfooding a minimal session-holding MLX surface (then the assistant builds
the smallest honest version, non-vacuous ONLY after weeks of real use) — or **(B)** ratify the
substrate as a library whose levers fire when a host product adopts them, and accept none exists yet.
