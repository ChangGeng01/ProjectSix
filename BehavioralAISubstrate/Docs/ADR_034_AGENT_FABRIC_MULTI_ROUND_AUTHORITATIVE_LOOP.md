# ADR-034 — Agent Fabric multi-round AUTHORITATIVE loop

## Status

Shipped. Builds directly on **ADR-033 §Step-5** (the single-shot authoritative feed-forward
projection), which closed with: *"Deeper integration … multi-turn authoritative loops remains a future
arc."* This ADR is that arc — and records two real bugs it surfaced.

## Context

ADR-033 Step 5 shipped `BASAgentFabricAuthoritativeProjection`: turn N's merge-accepted fabric deltas
→ a typed `BASAgentFabricAuthoritativeInput` (a labeled `contextBlock`) → folded into turn N+1's
`userInput` (`enrichedRequest`), which the verdict-gated cascade processes as INPUT (红线 7; 不变量 #2;
the sovereign verdict + single-commit gate stay the sole authority). Additive, opt-in (`mode ==
.authoritative`), byte-equal-off.

What was missing: (a) a **multi-round LOOP** that iterates the fabric to convergence (refining the
conclusions across rounds), and (b) a **host-callable composition** so a real host can actually go
`turnResult → authoritative input → enriched next turn` (the projection had **zero `Sources/`
consumers** — a tested-but-unused scaffold). This arc adds both, and wiring the loop to the REAL fabric
(not stubs) exposed two latent bugs the stub fixtures had masked.

## What landed

- **`BASAgentFabricMultiRoundLoop`** (Sources/BASHostKit) — iterates the fabric: each round builds a
  per-round `BASAgentTurnInput`, dispatches, projects the merge-accepted deltas, and (unless converged)
  threads the projection into the next round's input via an injectable `refine` closure. Convergence:
  **content-digest fixpoint**, **digest-cycle** detection (a finite oscillation stops cleanly, not at
  the cap), **nil-projection** early stop, and a hard **`maxRounds`** budget cap (terminates regardless).
  Two overloads: injectable-`dispatch` (stub-testable) + live-`runtime` (binds `dispatchTurn`, one-time
  `wireRosterToGraph`). Opt-in: `mode != .authoritative` ⇒ inert before any dispatch ⇒ byte-equal-off.
  Deterministic (pure dispatch + pure digest; pinned `nowNanos`; per-round turnID a pure function of
  base+index; sequential `await`).
- **`BASAgentFabricAuthoritativeTurn`** (Sources/BASHostKit) — the host wiring: `loopResult(decompose +
  candidates → BASAgentFabricAdapters.turnInput → loop)` + `enrichedNextRequest(...)` (folds the
  converged `finalProjection` into the next request via `enrichedRequest`, or returns it UNCHANGED when
  inert → byte-equal-off). The host runs the enriched request through the normal verdict-gated turn.

## The two real-fabric bugs (honest — the bare-ID stub fixtures masked both)

1. **The projection was DEAD with the real fabric.** `project(...)` filtered `emittedDeltas` by
   `mergeResult.acceptedDeltaIDs`, but the merge reports those in the dependency-REF format
   `delta:<deltaID>` — so they never matched the raw emitted `deltaID`s ⇒ `project` ALWAYS returned nil
   with the real fabric ⇒ the ADR-033 Step-5 feed-forward had been inert end-to-end since it shipped.
   The stub fixtures used bare matching IDs, hiding it. **Fix:** normalize the `delta:` prefix in
   `project` before matching (bare IDs unaffected → stub/legacy callers byte-equal). Regression test in
   the real `delta:<id>` format.
2. **The loop never converged with the real fabric.** It converged on the projection's full `digest`,
   which includes the turnID-stamped `deltaID`; the real seats stamp the per-round turnID into every
   `deltaID`, so each round's digest was unique ⇒ no fixpoint ⇒ ran to the budget cap (the "multi-round"
   was hollow — N rounds of identical-MEANING conclusions). **Fix:**
   `BASAgentFabricAuthoritativeProjection.contentDigest(of:)` — a digest over each conclusion's MEANING
   (domain, deltaType, confidence, summary, reasonCodes) EXCLUDING the turnID-stamped `deltaID` (the seat
   payloads + reasonCodes are turnID-independent — only `deltaID` carries it). The loop converges on the
   content digest ⇒ reaches a fixpoint at round 2 when the meaning is stable. The full `digest` remains
   the provenance/replay identity.

## Safety envelope (unchanged from ADR-033 §Step-5)

Additive (no `runTurn` / verdict / coordinator change); opt-in / byte-equal-off (inert when
`mode != .authoritative` OR no accepted deltas ⇒ the next request is returned UNCHANGED);
INPUT-class (the converged conclusions enter via `userInput`; the sovereign verdict + single-commit
gate gate them exactly as any input — 不变量 #2 神经不掌权; 红线 7); deterministic + replay-stable;
ch883 (the loop is host-side async; `runTurn` is untouched + sync).

## Verification

`swift test` — `BASAgentFabricMultiRoundLoopTests` (inert/byte-equal-off, determinism, content-digest
fixpoint, digest-cycle, budget-cap, nil-projection), `BASAgentFabricAuthoritativeTurnTests` (real-fabric
loopResult CONVERGES at round 2 + non-nil projection; enrichedNextRequest folds; observation-only →
byte-equal-off; end-to-end — the enriched turn changes a real brain's `decomposeFrame` AND its
sovereign verdict still runs), `BASAgentFabricAuthoritativeProjectionTests` (incl. the `delta:`-prefix
regression). Full XCTest suite green; canonical60 byte-equal (no sovereign-path file touched).

## Honest scope / follow-ups

- **Ships:** the loop + host wiring, functional + converging with the real fabric, opt-in, byte-equal-off.
- **`refine` is identity by default** — multi-round adds value only with a host-supplied `refine` that
  evolves the input across rounds; with identity the content is stable from round 0 (converges at round
  2). Genuine cross-round refinement (re-querying / adapting candidates between rounds) is host policy.
- **Does NOT:** wire the loop into the live DeviceTestApp endurance host (device-deploy follow-up);
  consume structured deltas beyond `userInput`; make the GPU/fabric authoritative without a determinism
  story. Live LLM-seat determinism remains the host's responsibility (per doctrine).
