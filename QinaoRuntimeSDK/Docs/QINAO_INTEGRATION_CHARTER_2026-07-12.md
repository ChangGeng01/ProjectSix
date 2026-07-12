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

- **S0** ✅ This charter (`138bd8d12`).
- **S1** ✅ (`138bd8d12`) `memory` dead seam wired: `QinaoMemory.frontstageBundle` (mirror of
  the BASHostKit canonical governed→atom projection) + sendSession shadow-copy injection
  when the caller supplies no bundle. Explicit inputs win; empty memory = byte-equal
  pre-S1 semantics. Probe: expectedCoverageLayerIDs ["L8","L14"] missing-layer witness.
- **S2** ✅ (`17abc7a58`) `QinaoDefaults.makeSovereignHost` — QinaoRuntime's FIRST
  production construction path: host + memory + risk (M103 permit→audit wire) + sovereign
  (persistent keyed ledger when path given) + endpoint-less loop over seeded vault + full
  9-seat council + runtime. Boundary pinned mechanically (QinaoBoundaryPinTests parses
  Package.swift target blocks; reversal-proven). Adoption test: one turn composes
  A+K+M (keyed ledger reopened COLD verifies chain, >0 entries).
- **S3** ✅ (`7104f8974`) F2 discharged for warrant + proof: dead tokenSigningKey wired
  into a package tokenTagKey; HMAC-SHA256 over injective length-prefixed fields; warrant
  signed at mint, verified signature-first; SnapshotContinuityProof got its first
  production issuance path + full gate verification (signature + session + EXPIRY —
  pre-S3 the gate compared only intentDigest). Documented residual: risk permit stays
  field-binding (QinaoRisk holds no key by design) — sign before cross-process adoption.
- **S4** ✅ (inside S2/S3 teeth) T first fire: three-signature execute() runs a real tool
  on the assembled host with minted tokens; refuses swapped-tool (F1), hand-built proof,
  expired proof, cross-session proof, forged/tampered warrant.

**Convergence result (vs. the 2026-07-12 turn-path map):** the assembled host composes
A + K + T + M on one spine; L stays outside the boundary as data, by directive. Every
capability the map showed as "composed nowhere" (T) or "default-off everywhere" (K) is
now live-by-default on this path. Full SDK regression 1479/0.

- **Permit-signing** ✅ (`1ccc2b8fd`) the gate's LAST field-binding lane closed: ActionPermit
  HMAC-signed at mint (domain-labelled "qinao.permit.v1", reason-code arity bound), verified
  signature-first; QinaoRiskGate stays sovereign-free via an injected plain-CryptoKit
  permitTagKey (assembly derives it from the host secret). Cross-process proof: shared-key
  gate-A→gate-B verification passes, different-key gate refuses. **F2 fully discharged —
  all three tokens signed; cross-process adoption needs only key sharing.** SDK 1488/0.
- **Sample-upgrade** ✅ (`cd9d8e71c`) QinaoSample — the SDK's reference consumer — now
  TEACHES this posture instead of path B: endpoint stays on the sample's side, every
  finished exchange crosses as data (`SampleSession.recordTurn` → memory admission +
  audited turn + persistent keyed ledger under Application Support with a locally
  generated stored HMAC secret). Per-exchange sovereign line shown in the UI status bar.
  SDK 1483/0.

Out of scope (explicitly): any LLM-side work; The Ledger workload changes (separate operator
decision); making SampleHost adopt this (BAS-side host, separate spine).
