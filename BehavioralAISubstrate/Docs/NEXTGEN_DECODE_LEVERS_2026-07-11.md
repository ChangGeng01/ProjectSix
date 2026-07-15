# Next-gen decode levers — Acceptance / KV / Prefix / Prefill (2026-07-11)

Operator: "现在杠杆太小 不够创新 不够颠覆 硬件限制 … Acceptance, kv cache, prefix, prefill 相关
所有指标都要上 next gen." A 5-innovator + cross-family-compounder design workflow (wf_0b64b4a1),
armed with the proven decode-spec death-list, adversarially refuted (20 proposed → 14 survived; one
refute agent hit the StructuredOutput retry cap and was recovered by hand — candidate[14]
"composite draft source" judged KILLED: the MTP head writes mtpK[pos] per position, so a corpus-hit
that skips the K MTP forwards leaves an unwritten KV gap; every fix re-pays the ~27ms×K it skipped —
the premise self-defeats).

## The honest headline (the disruptive thesis, deflated of hype)

**The next order of magnitude is NOT in decode.** Batch-1 free-form decode is bandwidth-walled;
the shipped fused-MTP lane (25.7 tok/s) already sits ABOVE the plain ceiling (25.0). Decode is a
low-single-digit-% game forever on A19 3-4B — the only residual is the kernel layer
(CoreAI-GPU/LiteRT, ~1.8× at zero quality cost) which is INCREMENTAL packaging, not disruptive.
**Disruptive decode headroom ≈ 0.**

**Every remaining multi-× lives in PREFILL/TTFT via avoided-compute KV reuse — restore-instead-of-
recompute — and it is entirely gated on workload RECURRENCE.** Genuine order-of-magnitude on
turn-1-after-relaunch, repeated system-preamble/RAG-context injection, and council fan-out; and
**exactly 1.0× on novel free-form chat.** There is no workload-independent speedup left to find;
the program's job is to FIRE the already-built reuse mechanisms and MEASURE the realized recurrence
fraction — never quote a peak.

★ Every pre-analysis absolute was internally inconsistent and must be device-remeasured, not
asserted: 45.7×/6ms restore (a cold flash-read of ~37MB + per-layer eval is tens of ms, not 6ms);
0.4s TTFT@512 (implies ~1400 tok/s vs the measured ~600); 140 tok/s prefill (wrong).

## The program (survivors, ranked)

**FIRST STRIKE — Cross-restart warm-seat wire** (KV persist/restore lifecycle): the purest
orphan-fire. The entire persist→restore→install path is ALREADY default-on + device-certified for
eviction spill; `snapshotWarmSeats()` (MLXOrganAdapter.swift:1972) has ONE caller today (the
endurance probe). The currently-ACTIVE seat — exactly the one a relaunch needs — is never evicted,
so never spilled. One app-lifecycle hook (scenePhase→.background) closes the loop with zero new
machinery; a restore-miss falls back to cold prefill, byte-identical.
- HONEST target: `spillRestoreCount` 0→1 on the first post-relaunch turn for the previously-active
  seat + byte-identical continuation (the live 48/48-exact contract) + a MEASURED turn-1 TTFT delta
  via completionMetrics (prefill/decode split). Real claim = "avoids a full cold re-prefill on
  immediate relaunch when the snapshot survives" — a device-MEASURED multi-× prefill/TTFT win on
  turn-1 only. DO NOT ship the 45.7× headline.

**FIRST STRIKE — Cross-turn suffix corpus wire** (C-PREFIX): thread the real sessionID into the
tool-loop/RAG callers to fire the orphaned BASCrossTurnDrafter (`.suffixLookup`), currently
unreachable because every production `draft(_:purpose:)` passes `sessionID:nil`.
- Target: ~1.1× sustained on genuinely repetitive tool-loop/RAG turns (1.07-1.41× only at heavy
  verbatim overlap), 1.0× byte-parity otherwise.

**FIRST STRIKE — Content-addressed shared-prefix KV** (RadixAttention-on-device): hash the
token-prefix, restore instead of re-prefill across sessions.
- Target: ~6-9× TTFT on the shared-prefix portion for repeated system-preamble/retrieved-context
  injection (ceiling = shared-prefix-tokens / total-prefill).

**HIGH — Prefill-once council fork** (persona-as-suffix reorder): N seats over a long shared
context pay ONE prefill (8-seat/1024-tok ≈ 7.4× prefill); end-to-end = prefill_fraction × N,
collapsing toward the prefill fraction for long generations.

**DEFERRED** — difficulty-gated draft WIDTH (the cross-turn EMA already banked the prose tax;
only the code→prose regime-boundary turn remains, plausibly below the thermal floor; "never below
K=1" safety claim is FALSE — needs a lower-only min(liveEMA, seed)); composite draft source (the
MTP-head KV-gap kill above).

## The honest ceiling

On the RIGHT workloads (agentic tool-loops, RAG re-injection, council fan-out, immediate relaunch)
the program delivers multi-× TTFT/prefill and ~1.1× decode. On recurrence-free chat: **1.0×.** The
order of magnitude is real but CONDITIONAL and saturates instantly when recurrence or prefill-
dominance ends. Correct deployment target is **The Ledger / agentic workloads where recurrence
actually exists** — ship the reuse levers there and report the realized fraction. This is the same
"上膛未击发 / needs a live recurrent consumer" pattern the whole campaign keeps meeting: the levers
are built and orphaned; the gating item is a real recurrent MLX workload, not more decode cleverness.


## First-strike status (2026-07-11 evening)

- **Mechanism DEVICE-PROVEN** (iPhone Air 9E9E, xcodebuild-test, 8.7s, PASSED): the active seat is
  snapshotted by snapshotWarmSeats(); a FRESH adapter (= a relaunch) drafts the same sessionID#role
  and takes the `_restoreFromSpill` branch (spillRestoreCount 0→1) instead of cold-prefilling;
  continuation non-empty. testCrossRestartWarmSeatRestoresNotColdPrefills. Fixes en route:
  addTrampoline (NSClassFromString doesn't resolve in the test bundle — device law) + _4bit_local
  model dir + MLX imports; caught a "Executed 0 tests" vacuous-pass (stale bundle) and the
  Device2HrFuzz test-PLAN restricting -only-testing.
- **TTFT number DEVICE-MEASURED** (9E9E, clean run, 6/6 class green): restore-turn prefillMs =
  **180.5ms**. HONEST reading — NOT a clean 279→180 delta: the 180.5ms restore turn still pays the
  INCREMENTAL prefill of the new user input; the F6-cert ~279ms is a FULL-history cold re-prefill.
  The avoided quantity = the whole conversation-history re-prefill that warm-restore skips (the
  restore turn pays only the marginal new-token prefill). A matched 3rd-adapter cold arm (co-resident
  4B to cold-prefill the same history) EXCEEDS the 12GB Air jetsam cap (6.29GB) → OOM, unrunnable — so
  the cold baseline is the documented F6 cert, not a same-run A/B. Real claim: warm-restore skips the
  full-history cold re-prefill; device-measured restore-turn prefill 180.5ms.
- **Harness laws banked** (2026-07-11): `-only-testing` at METHOD level yields 0 tests on this scheme
  (Device2HrFuzz default plan) — the CLASS-level `-only-testing:BASDeviceTests/BASSpillGCTests` is the
  working form; a copied `-xctestrun` breaks `__TESTROOT__` path resolution (keep it in Products/); and
  3× co-resident Qwen3.5-4B OOMs the 6.29GB jetsam cap (2 is the ceiling for A/B-in-one-test).
- **Product lifecycle wire: NOT built (honest)** — DeviceTestApp holds no long-lived adapter for a
  scene hook to snapshot; faking one would be a zero-byte loaded-gun toggle (3b trap). The real gate
  is the absence of a live recurrent MLX app — the same 上膛未击发 pattern; the deployment target is
  agentic/council workloads where recurrence exists, not more decode cleverness.
