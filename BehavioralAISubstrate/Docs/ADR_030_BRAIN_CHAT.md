# ADR-030 — BASBrainChat (§11 governed top-level entry)

> **Status: BUILT + TESTED (ch1048, opt-in / byte-equal-off).** Closes gap-audit slice 5 #20
> (PARTIAL → composed). Per ADR-014 it is additive and byte-equal when unused.

## 1. The gap

The outline's §11 developer API is `brain.chat({hostId, message, effort, transcript, activeAgents,
memoryScope, toolScope}) → {surface, effortReceipt, processTraceRef, actionPermit, sovereignStatus,
updateTickets}`. The gap audit found every underlying piece BUILT — the `runTurn` pipeline chains
L6→L14; `BASEBrainTurnResult` carries actionPermit / sovereignVerdict / updateTickets — but no single
governed entry of that shape: `BASEBrainTurnRequest` omits the effort/transcript/agents/scope inputs,
and the result is a 52-field internal bundle, not the curated 6-field developer response.

## 2. What was built (`Sources/BASHostKit/BASBrainChat.swift`)

- **`BASBrainChatRequest`** — the §11 inputs (hostID, message, effort, transcript, activeAgents,
  memoryScope, toolScope) + `deviceState` (a pipeline necessity beyond the simplified spec).
  `toTurnRequest()` maps onto the existing `BASEBrainTurnRequest`.
- **`BASBrainChatResponse`** — the §11 outputs: `surface` (the permit-selected L12 kind),
  `effortReceipt` (`BASEffortPlan`), `processTraceRef`, `actionPermit`, `sovereignVerdict` (with a
  `sovereignStatus` level summary), `updateTickets`, and `transcriptLines` (rendered per the request's
  transcript mode). `from(result:request:processTraces:)` curates a rich turn result into this shape.
- **`BASBrainChat`** — the facade: composes a host-injected `executor` (the host's real `runTurn`)
  and an optional `traceProvider`. `chat(_:)` runs the executor once and curates the result.

## 3. Why this is a FACADE, not a rewrite (honesty)

The 2000-line coordinator is neither modified nor reconstructed. The facade:
- honors `effort` (→ `effortReceipt`, via the pure rule `effortReceipt(requested:leaseGranted:)`:
  lease granted → applied = requested; else downgraded to `.guarded` reason `no_run_lease`) and
  `transcript` (→ `BASTranscriptView`-rendered lines) at the facade boundary;
- hands the FULL request to the host's executor, which threads `effort`/`activeAgents`/`memoryScope`/
  `toolScope` into its own `runTurn` AS IT WIRES SUPPORT — the current pipeline does not yet consume
  those inputs, so they are honestly "carried, host-threaded" rather than silently no-op;
- represents `surface` as the permit-selected KIND (`BASActionPermitMode`); the full visual surface
  is the QinaoUI presentation projection's job;
- populates `processTraceRef` from host-supplied traces (nil until the host wires contract-enforced
  calls).

## 4. Proven

`BASBrainChatTests` (5): the facade curates a REAL stub-coordinator turn into the response (surface =
permit mode, actionPermit/updateTickets/sovereignVerdict pass through, effortReceipt.requested honored,
no-traces → nil ref + `.off` → empty view); transcript + traceRef honored when traces are supplied;
the effort rule (granted/downgraded); request mapping; executor runs exactly once per chat. Full build
green.

## 5. Opt-in / byte-equal + honest layer-2

Additive — one new file + a test, no existing file modified. The existing `runTurn` /
`BASEBrainTurnRequest` paths are byte-identical. Adopting `brain.chat` (and threading its
effort/agents/scope inputs into the pipeline) is the host's deliberate step. Follow-on: thread
`activeAgents` (via `BASAgentLLMPurposeMap`) + `memoryScope`/`toolScope` into `runTurn`; surface the
QinaoUI projection for the full visual surface; package as the SDK `Qinao Runtime` `brain.chat`.
