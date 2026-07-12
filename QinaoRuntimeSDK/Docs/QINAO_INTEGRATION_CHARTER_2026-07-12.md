# Qinao Integration Charter — LLM-free sovereign SDK host (2026-07-12)

Operator directive (verbatim intent): **所有 Qinao 组成整合成 SDK host,不包括 LLM;边界需要干净。**
All Qinao components compose into ONE integrated SDK host assembly. The LLM sits OUTSIDE a
clean boundary and crosses it only as data.

This discharges the "three non-converging paths" finding (2026-07-12 turn-path verification:
A=deterministic-no-brain, B=brain-no-audit, C=full-gate-no-body) by firing path C — giving
QinaoRuntime its first production assembly — WITHOUT pulling the LLM inside the audited core.
Doctrinal frame: propose/dispose. L2 proposes (fallible drafts as DATA); the integrated
sovereign machine disposes (audit, coverage, halt, permit, warrant, ledger, memory).

## Boundary definition

**IN (the integrated assembly composes all of these):**
- QinaoHost (host constitution / version tree)
- QinaoMemory (L8 governed memory) — the dead `memory` seam gets WIRED, not decorative
- QinaoRisk (permit gate)
- QinaoSovereign (control plane; bootstrap with **persistent keyed ledger ON** by default in
  the integrated assembly — an L14 entry that dies unsigned in a result struct is the disease)
- QinaoLoop (dream/tribunal/frontier machinery — endpoint-LESS; generation paths give the
  existing typed refusal `organUnavailable("no-endpoint-configured")`)
- QinaoSeats (9-seat council, proposal registry, lease enforcer)
- QinaoWorldPrior (axiom vault)
- QinaoRuntime (the façade: P0–P9 sendSession, coverage, halt, three-signature execute)

**OUT (never linked by the integrated assembly):**
- QinaoAppleFoundation, QinaoMLX — the two LLM endpoint modules
- Any `BASOrganAdapter` construction; any model weights, decode, or streaming

**Crossing rules (the clean boundary):**
1. LLM output enters ONLY as value-typed data: `TurnInputs` observations, `CandidateInput`,
   memory admission payloads. Never as an awaited dependency of the audited core.
2. The single structural seam is `QinaoLoop.organEndpoint` (protocol, host-injectable). The
   integrated assembly leaves it nil. A host that wants generation attaches an endpoint ON ITS
   OWN SIDE of the boundary and feeds results back as data.
3. Boundary is MECHANICALLY PINNED: a test asserts the integrated targets' Package.swift
   dependency lists exclude the OUT modules (fossil-guard style — structure probed, not
   comments trusted).
4. Tool side-effects are IN-boundary and go through the three-signature `execute()` gate —
   tools are deterministic host capabilities, not LLM property. The LLM may PROPOSE a tool
   intent (as data); only the gate fires it.

## Stages (each: TDD teeth + reversal + individual commit + regression)

- **S0** This charter.
- **S1** Wire the `memory` dead seam: `sendSession` derives the L8 bundle from
  `runtime.memory` when the caller supplies none (explicit inputs still win). Kills the
  stored-but-unused property finding.
- **S2** The assembly: one production constructor (QinaoDefaults family) that composes ALL
  IN-modules — sovereign bootstrapped with ledgerDatabasePath (persistent keyed ledger),
  risk, host, memory, endpoint-less loop, 9 seats, world prior, toolExecutor seam → returns a
  ready QinaoRuntime. First production caller + boundary-pin test + adoption test proving one
  sendSession turn engages audit + keyed-ledger append + memory in a single path.
- **S3** Discharge F2 for the integrated gate: mint/verify real signatures on
  warrant (+ permit + snapshot proof) via the already-held token authority; unsigned tokens
  fail closed. Update the honest-scope docstrings to the new true state.
- **S4** T first fire: adoption test drives a real (test-double) tool through
  three-signature `execute()` on the integrated assembly.

Out of scope (explicitly): any LLM-side work; The Ledger workload changes (separate operator
decision); making SampleHost adopt this (BAS-side host, separate spine).
