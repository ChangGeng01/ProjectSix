# Universal Draft Layer — architecture, status, and the device-run runbook

A training-free, **byte-identical**, on-device (iPhone A19 / MLX) speculative-decode substrate: a router over
pluggable model-free draft **sources**, an online acceptance **profiler**, and the certified greedy verify loop.
The universal part is the *system layer*, not any one model — the draft source is swappable, the verify contract
is fixed. Everything here is **host-verified to the local limit** (tens of thousands of pure-logic harness checks
across several runs + full `swift build` + **32 XCTests green** in their own bundle); the one open question — does
it net a speedup — is an **A19 measurement** (see the runbook below).

## Architecture

```
respondAccelerated(purpose) ─▶ BASDecodeLanePolicy.acceleratedChoice(temp, purpose, profiler)
                                  │  greedy-only gate (temp==0) ∘ source(for:profiler:)
                                  ▼
   ┌─ .none           → draft(_:)               plain AR @1×  (free-form / not worth speculating)
   ├─ .promptLookup   → BASPromptLookupDrafter   single-sequence n-gram
   └─ .suffixAutomaton→ BASCrossTurnDrafter       cross-turn (prior turns + current), O(1) index
                                  │
                                  ▼  (all model-free sources, byte-identical)
            BASPromptLookupDecoder.generate  ── verify/accept/trim UNCHANGED, emits ONLY target argmax
                                  │
                                  ▼
            draftProfiler.observing(sourceID, purpose, accepted/proposed/rounds)  ── online learning
```

**The load-bearing invariant:** the verify loop emits *only the target model's own argmax* (the
accept-longest-prefix `while` + the `for i in 0...acc` emit loop in `BASPromptLookupDecoder.generate`), so a draft
source changes only the **acceptance rate, never a byte** (ADR-039). Any source is therefore correctness-safe by
construction; the only question per source is whether it nets a speedup.

## Files

**Phase 1 (cross-turn source):**
- `Sources/BASOrgan/BASSuffixAutomaton.swift` — incremental hashed last-occurrence n-gram index over a bounded
  corpus; `propose` is parity-pinned equal to `BASPromptLookupDrafter.propose`; `proposeDistinct` = the tree feed.
- `Sources/BASOrgan/BASSessionTokenStore.swift` — per-conversation corpus, LRU-bounded session count.
- `Sources/BASMLXAdapter/BASCrossTurnDrafter.swift` — seeds the index with prior-turn tokens, folds this turn.

**Phase 2 (substrate):**
- `Sources/BASMLXAdapter/BASUniversalDraftSource.swift` — the pluggable source protocol (`sourceID`, `propose`,
  `proposeTree`).
- `Sources/BASOrgan/BASAcceptanceProfiler.swift` — online per-(source × purpose) EMA (immutable-update).
- `Sources/BASOrgan/BASDraftSourceRouter.swift` — `BASDraftSourceChoice` + `source(for:profiler:)` +
  `acceleratedChoice(temperature:purpose:profiler:)`.
- `Sources/BASMLXAdapter/MLXOrganAdapter+SuffixSpec.swift` — `respondAccelerated` (router-driven, learns online),
  `respondCrossTurnLookup`, the `crossTurnLookupAB` measurement harness, `crossTurnStore`/`draftProfiler` state.
- `DeviceTestApp/Sources/App/BASSuffixLookupProbe.swift` — the on-device promotion gate (`BAS_SUFFIX_PROBE=1`).

## Invariants (all preserved)

1. **Byte-identity** — structural (argmax-only emit); held by every source + the tree accept-walk.
2. **Fail-closed** — non-greedy preset (temp ≠ 0) or non-eligible purpose ⇒ `.none` ⇒ plain `draft(_:)`.
3. **Free-form fallback @1×** — `.creative`/`.scoutDefault` never speculate (the documented ~−8% n-gram-scan cost
   is lane-gated off).
4. **Bounded memory** — the corpus + profiler are plain RAM (no MLX residency), session-LRU + corpus-FIFO bounded,
   far under the 3376 MB jetsam cap.
5. **Tree-verify is OUT** — `proposeTree`/`proposeDistinct` are a *capability*; the router NEVER selects a tree
   (measured 0.76× loss; needs a cache-gather vendor patch that does not exist).

## The device run (the only remaining frontier)

**Turnkey** (builds + installs + runs the K=4 baseline and K=8 aggressive passes, prints each `PROMOTION_GATE`):
```sh
BUILD=1 bash scripts/run-suffix-probe.sh        # first run (build + install + both passes)
bash scripts/run-suffix-probe.sh                # re-run (app already installed)
K_VALUES="4 8 12" SLOOKUP_MODEL=llama_3b bash scripts/run-suffix-probe.sh   # custom sweep / model
```
Manual equivalent — launch the DeviceTestApp (`com.changgeng.basdevicetest`) with env:
```sh
BAS_ENDURANCE_AUTOSTART=1 BAS_SUFFIX_PROBE=1 BAS_SL_K=8    # aggressive (BAS_SL_K=4 = baseline)
# also: BAS_SL_NGRAM_MIN / BAS_SL_NGRAM_MAX / BAS_SL_CAP / BAS_SLOOKUP_MODEL (gemma_e2b|llama_3b|qwen_3b)
```
Reads `suffix-lookup-<stamp>.log` in the app's Documents container; the verdict line is `📊 suffix-lookup DONE …
PROMOTION_GATE=PASS|FAIL|INVALID`.

**Promotion gate ("实测胜出"), emitted as `PROMOTION_GATE=PASS|FAIL|INVALID`:** a **VALID** run (no errors, no
excluded zero-timing turns, both arms non-empty) AND **token-identical every turn** AND **later-turn reuse mean
> 1×** AND **control ≥ 0.90×** (the documented free-form band — control is NOT expected ≥1×). `INVALID` is emitted
on infra failure so an error is never mistaken for a measured FAIL/PASS.

**Scope caveat:** the probe's A/B holds prefill constant (both arms fresh-cache), so it isolates the *draft*
benefit. It is **not** a comparison against `draftMultiTurn`'s ChatSession KV-reuse — a >1× here is necessary but
not sufficient to swap cross-turn in for the production multi-turn path on long histories.

## Verdicts to date (adversarially reviewed)

- **KEEP (certified on-device):** greedy spec-decode with a same-tokenizer sibling (1.46×); prompt-lookup
  (1.58× repetitive, lane-gated). These are the net-positive wins the substrate routes over.
- **BUILD + MEASURE:** the cross-turn suffix source — built, host-verified, **net-positivity is the A19 question**
  above. It may be a loss (the growing-corpus scan is the free-form-penalty source); the gate decides.
- **CUT (would be a 亏):** warm-KV-cache fusion into the spec lane (the win already ships via `draftMultiTurn`
  KV-reuse; fusing is byte-unsafe + redundant); sampling spec-decode (0.77×); Mamba-as-draft (0.10–0.24×).
- **GATE OFF:** tree-verify (0.76× loss; no cache-gather patch); cross-tokenizer/model-draft on-device (HW-gated
  to desktop).

## Deferred (latent, documented)

- Cross-turn store re-appends the full re-rendered prompt → churn IF a host carries growing history in
  `request.context` (no production caller today; AB uses `context:[]`). Fix when wired: a store-level synced cursor
  (mirroring `BASCrossTurnDrafter.synced`); hosts should accumulate via `sessionID`, not re-send history.
- **`respondAccelerated` / `respondCrossTurnLookup` are NOT yet wired into the default production path** — those
  are Phase-1, host-electable, *measure-only* entries (no production caller; the live path is `respondPromptLookup`
  via `draft(_:electAccelerated:)`). So the router, the online profiler (`recommendedK` warm-start), and the
  cross-turn store accumulation run today only in unit tests + the device probe, not in production. Wiring them is
  gated on the device promotion gate (don't default-on a possibly-net-loss lane).

(Already hardened, not deferred: `proposeDistinct`'s backward walk is bounded by `maxScan` (default 512), capping
the low-entropy short-suffix worst case while preserving the branch-0==propose() invariant for realistic vocabularies.)

## Verification status

- **Host (done):** automaton parity/fuzz/eviction (22,293) + `proposeDistinct` branch-0 + batched-append parity
  (13,984) + store + cross-turn adapter (5,313) + profiler/router/acceleratedChoice (24) — overlapping harness runs,
  not an additive total; plus **32 XCTests green** (`BASUniversalDraftLayerTests`); full `swift build` +
  `swift build --build-tests` green. XCTest pins exist (`BASSuffixAutomatonTests`, `BASSessionTokenStoreTests`,
  `BASCrossTurnDrafterTests`, `BASDraftSourceRouterTests`) — they run once the pre-existing full-suite bundle
  SIGSEGV-on-load is resolved; their logic is harness-verified now.
- **Device (pending):** the run above. Net-positivity certifies only on the A19.
