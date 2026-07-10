# Re-sweep remediation — operator decisions

The 2026-07-09 re-sweep's Mac-fixable, non-gated findings are all closed (47 findings, each with
teeth + reversal + individual push; see `MEGAAUDIT_RESWEEP_GAPS_2026-07-09.json`). What remains
needs **your call**, not more engineering — each item below is deferred *because* the honest fix
is a policy flip, a schema change to a safety-critical struct, a change to your experiment code,
a deletion, or a workflow change. Pick per item; I'll implement the choice with the usual rigor.

Legend: **R** = my recommendation. Cost = rough implementation + verification effort.

---

## 1. Thermal policy: does a `.guarded` turn keep its safety dials on the hottest device?
**Finding** runtimecore-a #7 · `BASEffortAllocator` · MED · *dormant* (the capped level isn't
consumed by `runTurn` yet, so nothing runs verification-free today).

Under critical thermal (headroom < 0.15) an explicit `.guarded` request is capped to `.fast`,
whose budget zeroes `criticStrength` and `toolVerificationStrength` — i.e. the highest-risk turn
would run with **zero verification** on a critically hot device. This is currently *documented*
(`BASEffortAllocator.swift:97-98`) and *test-pinned* (`testGuardedYieldsToCriticalThermal`).

- **(A)** Keep as-is — thermal-lease wins; a critically hot device sheds verification even on
  guarded turns. *(status quo; nothing to do.)*
- **(B, R)** Floor an explicit `.guarded` base so the thermal cap never drops it below `.guarded`
  (keeps the 3/3 safety dials), overriding thermal-lease for *deliberately-guarded* turns.
- **(C)** Strictest: `runTurn` **abstains/defers** the turn rather than run it verification-free
  on a critical device (lives in runTurn wiring, not the pure allocator).

Cost: B ≈ small (1-line floor + rewrite the one pinning test). C ≈ medium (runTurn wiring).
**Decide before this level is wired into runTurn.**

---

## 2. Sovereign execution receipts: stop presenting synthesized latency as measured?
**Finding** hostkit-spine F9 · `buildSovereignExecutionReceipts` · MED · schema-versioned,
safety-critical.

Every receipt is minted `status: .executed` with a **fabricated** `latencyMs = (index+1)*12`
and `executedAt = recordedAt + (index+1)*0.012s` — synthesized per-index numbers presented as if
measured. (No actual per-command execution timing exists at this build point.)

- **(A)** Keep — cosmetic; nothing consumes the latency as real. *(nothing to do.)*
- **(B, R)** Zero the fabricated latency (`latencyMs: 0` = unmeasured) + use the real
  `recordedAt` for all (no per-index stagger) + a comment. Keeps `.executed` + the schema, passes
  the existing pinning test. *Minimal honesty fix.*
- **(C)** Add an honest `.recorded` status to `BASSovereignExecutionStatus`, use it here, make
  `latencyMs` optional. *Truthful but a schema + enum change → rewrites the `.executed` pinning
  test and needs a sweep of receipt consumers.*

Cost: B ≈ small (low risk). C ≈ medium (schema change in a safety-critical versioned struct).

---

## 3. Release gate #95 "determinism": strengthen to byte-identical, or document letter-identical?
**Finding** x-test-integrity F8 · `qinao_eval.py` · MED · your eval harness.

The `#95 determinism` gate re-asks the neutral question and compares only the **letter**, but the
comment claims **byte-identical**. At temp=0 greedy a genuine model *is* byte-deterministic.

- **(A, R)** Strengthen the code to byte-identical (match the comment + the proper meaning of a
  determinism gate). Makes the CRITICAL gate stricter — it will now catch any non-determinism.
  *Changes your release-gate pass/fail semantics.*
- **(B)** Weaken the comment to "letter-identical" (document actual behavior; no gate change).

This is a **release-policy** call on your eval harness — hence deferred to you.
Cost: either ≈ small. (Teeth is blocked by un-importable model deps regardless.)

---

## 4. Package.swift manifest hygiene (needs xcodebuild verification)
**Findings** x-architecture LOW-4 (add `Vendor/mlx-swift` as a direct dep, mirroring the
swift-crypto precedent) + LOW-5 (remove phantom manifest edges: unimported
`BASOrchestration→BASLeaseLife`, `BASBrainCLI→BASMemory/BASPolicy`, the unused `Hub` product).

Both are manifest-only, but the standing rule (learned from the LiteRT inert-manifest incident) is
that **`swift build` masks xcodebuild breakage** — any Package.swift change must be verified with
`xcodebuild build-for-testing`, which I avoided to prevent DerivedData contention with your work.

- **(A, R for LOW-4)** Adopt the additive dep (lowest-risk category), verified with xcodebuild.
- **(caution for LOW-5)** Removing deps is the exact category that can break xcodebuild silently —
  adopt only with a full DeviceTestApp xcodebuild pass.

Cost: small edits, but each needs a real xcodebuild run (best done when you're not building).

---

## 5. Deletions (blocked by the consult-before-deleting hard rule)
**Findings** x-architecture LOW-6 (`git mv` 4 dead-code files → `Archive/Deactivated`) · rust
`verdict_decisions.rs` (2 dead lines: unused `c_char` import + its silencer) · rust
`assembler.rs` (change `pub mod` → `#[cfg(test)] mod` to compile-time-fence a legacy *forgeable*
canonical-bytes encoder outside tests).

All three are safe removals of genuinely-unreferenced code, but the rule is to **ask first**.

- **Authorize?** (Y/N per item). The rust `assembler.rs` cfg-fence is the highest-value (it makes
  a *forgeable* encoder unreachable in production); the others are pure hygiene.

Cost: trivial once authorized. (Rust changes need a `cargo check`; no XCFramework rebuild — the
committed binary is unchanged.)

---

## 6. MLX weights: gate the world-writable `/tmp` candidate behind an opt-in?
**Finding** mlx-decode LOW-1 · `MLXOrganAdapter._resolveMTPWeightsURL` · security hygiene.

The resolver unconditionally probes `/tmp/gdn_coreai/qwen35_mtp_folded.safetensors` — a
**world-writable** path a local attacker could plant weights into. It's a Mac-dev convenience
(iOS/device never uses it), but on Mac it loads by default.

- **(A, R)** `os(macOS)`-gate it **and** require `BAS_MTP_ALLOW_TMP_WEIGHTS=1`. Removes the
  default attack surface; your dev/staging runs set the env. *Changes your Mac-dev weight-staging
  workflow (one env var).*
- **(B)** Leave default-on (convenience > the local-attacker threat model on a dev machine).

Cost: small. Only matters if you stage MTP weights via `/tmp/gdn_coreai`.

---

## 7. Your experiment code: authorize hardening touches?
**Findings** tools-scripts — `b2_r2_pipeline.py` / `b2_refit_candidate.py` (assert-based sha
freeze-pins that vanish under `python -O`) · `eval_probe_ood.py` (cwd-relative WEIGHTS path +
magic 0.85) · `qinao_humaneval.py` (unsandboxed `subprocess.run` of model code + `except: pass`
that scores an infra failure as a wrong answer).

These live in your active b2/RSI experiment domain, so I left them alone.

- **Authorize?** The safe wins if you say yes: assert → `sys.exit` (survives `-O`, *strengthens*
  your freeze-clause reproducibility); resolve WEIGHTS relative to the file; surface (not swallow)
  a HumanEval infra failure; optional exec opt-in gate. None change your experiment *results*,
  only their robustness.

Cost: small per script. Skip if you'd rather keep the experiment tree frozen.

---

## Not decisions — just scheduling / hardware
- **hostkit-spine F7** — wire the (dormant) chapter-188 SSM cross-turn caution path; do it *when
  that feature is activated* (its teeth needs turn execution).
- **x-sovereignty #7** — SampleHost stress-runner: raw `identifierForVendor` → SHA (privacy). Low
  priority; separate demo package with CoreML deps.
- **Device-gated (need hardware):** devicetestapp ×7, sovereign LOW-8 (dual SHA impl),
  x-concurrency ×2 (Metal pipeline single-flight), mlx-adapter-core LOW-12/14. I can land these as
  fix-with-honest-note commits whenever you want; teeth is on-device.
