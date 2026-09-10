# ADR-032 — Governance enablement: observe-mode ON by default (ch1059)

> **Status: ENABLED (the safe subset) + REFUSED (the unsafe subset), rigorously.** Response to the
> directive 「全面启用 能够启用的 最严谨」 — turn on the governance that *can* be enabled without changing
> sovereign behavior, refuse what can't, and verify with the full suite.

## What "能够启用的" means here
The whole project is ADR-014 opt-in / byte-equal-off / R1. So "what *can* be enabled" rigorously =
**governance that is output-byte-equal and blocks nothing**. That is **observe-mode**: contract every
LLM call + record a trace, but never reject. Anything that *blocks* a call or mutates a verdict needs
a deliberate host policy/keyring and is therefore **refused by default** (R1 / 亏的不要上).

## ENABLED by default (output byte-equal, proven)
- **`BASLLMContractInstall.observeOnly(purpose:agentRef:traceSink:)`** — empty `forbiddenContext` /
  `allowedContext` / `sovereignConstraints` and no `sovereignCheck`, so `BASContractedOrganGate.validate()`
  **cannot throw** → the model is always called → **drafted output byte-identical** to the unwrapped path.
  Default trace sink: `os_log` (`subsystem: bas.llm.contract`, `category: observe`) — refs only, no body.
- **Defaulted on at all three installable LLM call sites**:
  - `BASLLMNeuralCoreService.makeDefault(… contractInstall: = .observeOnly(.decompose))`
  - `BASLLMVerifierPipeline.init(… contractInstall: = .observeOnly(.verify))`
  - `BASToolCallingPlanner.init(… contractInstall: = .observeOnly(.plan))`
- **Effect**: §13 #12 (禁止随便问模型 → *every LLM call through these engines carries + records a contract*)
  is now satisfied **by default**, with **zero output change**. Enforcement remains a separate, opt-in layer.

## REFUSED by default (would change sovereign behavior — R1 / 亏的不要上)
| Item | Why not default-on |
|---|---|
| Contract **rejection** (forbidden-context / sovereign-constraint) | blocks calls; needs a deliberate per-purpose policy |
| Crypto commit-token verifier (#13) | needs the host keyring; gates/*blocks* real OS actuation |
| Dual-key boundary-weakening gate (#3) | needs the keyring; blocks operations |
| Fabric-authoritative multi-agent | a deep coordinator rewrite (codebase-deferred to ch961+) |
| Pre-work sovereign gate *deny conditions* | needs a real kill-switch / hardNoGo policy |

## Honest boundary
The **core-brain MLX path** (the L2 neural-organ inference inside the `runTurn` cascade) does **not**
route through these three engines, so this flip does **not** contract-wrap it. Contract-wrapping the
brain's own model call is a separate, careful integration — **not** a reflexive default-flip.

## Verification (the rigor gate)
- **Full suite: 14,894 tests** run. The default-flip caused **zero regressions** — every brain /
  verifier / extraction / planner test passed under the new observe-mode default.
- The *only* failure in the first full run was a **flawed new test** of mine (it reused one
  `BASOrganDeterministicAdapter`, whose per-instance call counter made `#1` vs `#2` differ for reasons
  unrelated to the gate) — fixed to use fresh instances; the byte-equality of observe-mode is now
  proven (`testObserveOnlyIsOutputByteEqual`, with deliberately forbidden-looking context).
- **R1 preserved**: observe-mode never blocks/mutates; the verifier's own `report.isAcceptable` and the
  sovereign verdict path are untouched.

## UPDATE (2026-06-08) — the crypto commit-verifier subset now has a LIVE host-side mechanism

ADR-032 above REFUSED the "unsafe subset" (crypto commit-verify / dual-key / deny) pending a host keyring
(R1). The crypto commit-verify part now has its mechanism, shipped this session:
- **ADR-025/026** built the primitives: deterministic Ed25519 mint, `BASSovereignCommitEnforcer`
  (register → authorize, fail-closed), and `BASSovereignGatedCommit` (the per-op gated-execution seam).
- **`BASSovereignGatedTurn`** (this session) is the turn-level host-side gate: given the turn's emitted
  commit tokens + the settled artifact + a keyring-backed enforcer, it authorizes each irreversible op
  (checkpointCommit / memoryWrite / renderHighRisk) against the ACTUAL artifact and runs the host's op
  ONLY on success — fail-closed on no-token / unsupported-scope / aliased-target / tampered-artifact /
  replay / TTL / invalid-sig. `BASSovereignTurnArtifactParts` is the SINGLE SOURCE OF TRUTH for the
  per-scope digest formula (the emitter `buildSovereignCommitTokens` + the gate share it → the recompute
  can't drift from the emit). 6 tests; the emitter refactor is byte-equal (determinism suite green).

**Architecture finding (why it's HOST-SIDE, not in `runTurn`):** `runTurn` is a PURE emit-only function —
it computes + emits the commit tokens; the HOST executes the irreversible ops (persist fold / apply
tickets / render). So a gate INSIDE `runTurn` is structurally impossible (nothing executes there). The
gate is host-side BY DESIGN — exactly where ADR-026's enforcer was always meant to sit.

**Still REFUSED / honest scope:** this is the MECHANISM, not a live-in-production gate. Going live needs a
host to (a) hold a keyring-backed `BASSovereignTokenAuthority` (the operator's key/policy decision — R1)
and (b) route its real fold-persist / ticket-apply / render through `BASSovereignGatedTurn.gate`. No
current host does (the endurance runner + fabric pipeline consume tokens but don't execute gated ops). The
dual-key + deny-condition subsets remain REFUSED pending their own host policy. OPT-IN / byte-equal-off:
the coordinator / `runTurn` is untouched; a host that never gates is byte-identical.
