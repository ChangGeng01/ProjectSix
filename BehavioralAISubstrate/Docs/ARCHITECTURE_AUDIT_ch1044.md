# Foundational Architecture Audit — ch 1044

> Comprehensive read-only audit of the BAS substrate's **底层架构** (not just the
> ch1039→1044 arc). Conducted by 4 independent clean-context adversarial agents,
> each on a distinct dimension. HEAD `6c5654183`. 289,456 LOC / 1013 Swift files
> / 22 modules. **Findings only — nothing fixed in this pass** (most are
> pre-existing and several touch the sovereign/safety path → fresh-session work).

## Scope note (honesty)
The ch1039→1044 deliberation/evolution arc was separately audited clean the prior
turn (byte-equal holds, docs accurate, 14,703 tests / 0 real regressions). THIS
audit looks UNDER that arc at the foundation. Several findings are **pre-existing**
substrate issues, not introduced by the arc; they are recorded here honestly
rather than hidden.

---

## Severity-ranked findings

### HIGH-1 — Replay-determinism is VIOLATED on the core path (a real correctness bug)
`Sources/BASHostKit/EBrainRuntimeCoordinator+SovereignCommit.swift:125` —
`let nonce = "nonce.\(UUID().uuidString.lowercased())"` is an **inline, non-injected
`UUID()`** on the NON-opt-in path. `makeCommitToken` is invoked unconditionally
(`buildSovereignCommitTokens`, called at `RunTurn.swift:1173`), the nonce is a
stored Codable field (`BASSovereignCommitToken.nonce`, `EBrainControlPlaneCore.swift:688`)
and feeds the token signature, and the tokens land in the returned result
(`RunTurn.swift:1813/1838`). So **same input → different nonce → different
`BASEBrainTurnResult` bytes** whenever a non-quarantine verdict issues commit
tokens. The same file (`:129-135`) documents an M336 fix for the identical bug
class (a randomly-seeded `hashValue` tokenID) — but left the adjacent nonce raw.
**Bounded fix (future):** inject the nonce like the M336 tokenID fix
(deterministic from turn inputs / an injected factory). Masked today only because
the byte-equality harness (HIGH-2) can't see it.

### HIGH-2 — The byte-equality "red-line 7" harness is STUB-ONLY / vacuous / not in CI
红线 7 (additive byte-equal when opt-in is off) is the safety invariant the whole
arc rests on. It holds **by construction** (V2 re-dispatches to V1;
`EBrainHostRuntimeSynthesis.swift:148-158`), which is good — but the *regression
harness* that supposedly enforces it does not:
- `BASStressSweepCanonical60Driver.swift:39-62` ships **stub runners**; the real
  coordinator-driven runner is "Deferred to a follow-up chapter."
- `identityStubRunner()` (`:200-219`) **returns the same object for v1 and v2**, so
  the "0 divergences" test (`BASTurnRuntimeEngineRunWithPlanDualModeStressSweepTests.swift:60`)
  is **vacuous by construction** (its own comments admit it tests "the harness
  pipeline").
- The comparison unit `BASRuntimeAuditEmissionSummary` (`:63-140`) has **no
  nonce/token/signature fields** → even a real run would be **structurally blind**
  to the bytes that vary (incl. HIGH-1).
- Not in CI: `scripts/pre-commit-gates.sh` runs god-file / import-boundary /
  residual checks only — **nothing enforces byte-equality / red-line 7 / opt-in
  defaults**.
**Consequence:** the red-line is a disciplined *convention* held by code shape +
the fast per-suite witnesses (e.g. `BASChapter1039` on/off tests), NOT a real
substrate-wide automated guarantee.

### HIGH-3 — Sovereign cryptographic spine is DORMANT; production uses an unkeyed (forgeable) digest, and nothing verifies tokens before a write
- `BASSovereign/BASSovereignTokenAuthority.swift` (a complete Ed25519 double-key
  commit/warrant system with policyHash pin + nonce-replay + single-use) has
  **ZERO production callers** (every functional reference is in `Tests/`).
- Production `runTurn` "signs" commit tokens/warrants via `makeCommitToken`/
  `makeSovereignWarrant` whose signature is `sovereignDigestHex` = a plain
  **unkeyed `SHA256.hash`** (`+SovereignCommit.swift:1669`) — tamper-evident but
  **forgeable** (no secret key); the §10 "double-key unforgeability" the design
  advertises is not in force by default.
- The post-turn write gate (`BASObservability/.../approveForDistillation`) keys on
  a `sovereignVerdictRef` **string** non-empty check, **not** on a cryptographic
  token redemption.
**Caveat (not a bypass):** the INLINE gates (HIGH/MED below) hold independently,
so this is "advertised crypto assurance is aspirational," not "safety is
bypassable today."

### MED-HIGH-4 — Production L14 verdict is a hand-rolled parallel path; the BR-001..BR-012 parity engine is dormant
Production uses the hand-rolled `buildSovereignVerdict`/`computeVerdictDecision`
(`+SovereignVerdict.swift:22,103`). The real `BASSovereignVerdictEngine` + its
**fail-closed cross-engine parity check** (`coordinatorLaxer → halt`,
`BASSovereignTurnVerifier`) are **test-only** (`grep` in `Sources/` = 0). So there
is no runtime guarantee the two authorities agree. Mitigating: the hand-rolled
lattice only escalates (`>` comparison, monotonic `raise()`).

### MED-5 — ADR-014 (~1599 refs) and ADR-016 (~1791 refs) have NO defining document
Only `ADR_018/019/020` exist as files. The two most-cited doctrines in the entire
repo — ADR-014 (OPT-IN) and ADR-016 (milestone-advance) — are **referenced ~3,400
times but never written down** as ADRs (paraphrased in passing in L8_ROUTED /
ARC_SEAL / SCAFFOLD only). ADR-006/012/013 are likewise referenced-but-undefined
(ADR-012's doctrine lives only in inline comments in `BASRiskCalibrationBundle/
Gate.swift`). The canonical 不变量 #1/#2/#3 are defined in exactly one place
(`L8_ARC_SEAL.md:553-558`). This is the largest documentation-vs-reality gap.

### MED-6 — Cohesion: 48 files exceed the repo's own 800-LOC max
Led by `BASHostKit/BASCognitiveBrain.swift` **4134 LOC** (5.2×) and
`BASRuntimeCore/BASAutoRouteRanker.swift` **3802**. The coordinator-split
discipline (17 `+Extension` partials) is good but incomplete (RunTurn itself is
2015). `BASRuntimeCore` is an overweight "root" (70K LOC / 288 files) carrying ~30
commemorative `*Doctrine` literal-only files named after higher layers + runtime
logic (AutoRouteRanker, EBrainControlPlaneCore) that strains the schema-only-base
contract.

### MED-7 — SCAFFOLD_VS_WIRED.md headline overstates wired ratio; advanced cognition is mostly dormant
The core L0-L14 forward-pass spine genuinely **functions + decides** (risk
escalation, the Cthulhu/Kunlun permit-narrowing gate chain, tribunal veto,
sovereign verdict) — real, not theater. BUT the doc's "✅ WIRED ~68 (91%)" headline
counts **observability-wiring as WIRED** (its own Debt-2 admits ch1006-1009 flipped
flags to ✅ via audit emitters that don't change dispatch;
`BASAgentFabricRuntime.swift:79`: `.observationOnly` ≡ `.authoritative` byte-identical).
Honest ratio for the 9 named advanced subsystems: **0 live-by-default / 2 opt-in /
3 observation-only / ~5 pure-scaffold-never-instantiated** (deliberation loop +
evidence-withholding opt-in; fabric + shadow-trial-feedback + evolution-lifecycle
observation-only; dream-loop kernel + ShadowTrial actor + feedback→policy +
version-branch + ANE consult never-instantiated). The 12 `withDerived…Observation
Bundle` seams are write-once audit telemetry **no decision reads** (ADR-018 §3
"reservoir, no pump" — verified: L10 `veto.compensable` always false, L8
`promotionState` one-directional, L11 evidence-debt penalize-only, L5 boundaryVeil
add-only). The prose docs (ADR-018/019/020) are **brutally honest** about this; the
debt is in the headline numbers + the weak (string-presence-only) `BASChapter1005`
pin test.

### LOW-MED-8 — `BASHostKit` imports modules not in its declared deps
`import BASOrgan` (`BASLLMNeuralCoreService.swift:57`, `BASTrainingExampleSublimator.swift:72`)
+ `import BASRustMemoryTrackerBinary` (`BASCognitiveBrain.swift:68`) compile only
via SPM transitive-closure leniency. Latent fragility; one-line Package.swift fix.

---

## What is GENUINELY SOUND (audit-confirmed)
- **Dependency graph:** clean, acyclic (Kahn-verified, 9 depths), `BASRuntimeCore`
  truly root, no leaf→higher import, declared graph matches Package.swift.
- **Inline safety spine is non-bypassable** (the most important safety result):
  kill switches (`+Normalization.swift:22/37/253/493`), hard-no-go (`gateAction`
  short-circuits to `protectiveBlock` BEFORE the band→mode mapping,
  `+RiskService.swift:203-210`), the extreme/GSI redlines (`normalizeRiskDecision`),
  and the permit clamp all run **upstream of every tunable knob**. A direct grep of
  all opt-in flag/carrier identifiers against the verdict / kill-switch /
  hard-no-go enforcement files is **EMPTY** → no opt-in feature can relax a hard
  control.
- **不变量 #2 神经不掌权 is structurally enforced** (`BASSharedStateGraph.swift:373-393`
  write-domain + writer-registry rejection).
- **NEVER-EFFECTIVE-SAME-TURN is structurally enforced** (turn-phase ordering +
  the write-domain restriction).
- **Coordinator is a value-type struct** (cross-turn state host-held).
- **The ch1039→1044 arc never relaxes a hard control** — caution-only by
  construction (floored at 0, band-monotonic-up, permit never downgraded); the
  ADR-020 §9 sub-baseline scalar is an assessment-number artifact in the same band,
  read by NO hard gate (exhaustive grep: the only raw-`totalRisk>=` consumer is an
  erosion *metric*, not a gate).
- Sovereign/verdict/kill-switch/constitution/deliberation suites: **1320 XCTest /
  0 failures** this run; 0 of the 3 known infra flakes triggered.

---

## Recommendation
**Record-and-defer.** None of the HIGH findings is an active safety bypass (the
inline spine holds), so nothing demands an emergency fix at a long-session tail.
The highest-value follow-ups for a fresh, focused effort, in order:
1. **HIGH-1 nonce determinism** — bounded, clear fix (inject the nonce; mirror the
   M336 tokenID precedent in the same file). Smallest + most clearly-correct.
2. **HIGH-2 real byte-equality harness** — replace the stub Canonical60 runner with
   a real V1-vs-coordinator comparison whose summary includes the varying fields,
   and wire it into `pre-commit-gates.sh`. This is what would have caught HIGH-1.
3. **MED-5 write the missing ADR-014/016 charters** — pure docs; closes the biggest
   documentation gap.
4. **HIGH-3 / MED-HIGH-4** — wiring the Ed25519 authority + the parity-engine
   halt into production is a sovereign-path change → its own sovereign-reviewed arc
   (the same discipline that closed P4 / deferred P5).
5. **MED-6 god-file decomposition** (`BASCognitiveBrain.swift` 4134) + **LOW-8 deps
   hygiene** — mechanical, low-risk, any session.

---

## DEFERRED WORK REGISTER — the 4 findings NOT fixed in ch1044

The ch1044 fix pass closed the safe subset (HIGH-1 nonce determinism + the HIGH-2
regression guard + LOW-8 deps + MED-5 ADR charters + MED-7 SCAFFOLD honesty). The
following **4 findings are explicitly DEFERRED** — each is recorded here as a
self-contained work item so a future session need not re-derive scope from the
finding sections above. **None is an active safety bypass** (the inline safety
spine holds independently — see "GENUINELY SOUND" above); deferral is a
discipline choice (sovereign-path / large-refactor work must not start at a long
session tail), not a hidden gap.

### DEFER-1 — HIGH-3: wire the Ed25519 sovereign token authority into the commit path
- **Why deferred:** sovereign-path change that alters safety *semantics* (today
  production "signs" with an unkeyed, forgeable SHA256 digest and nothing
  redeems/verifies a token before a persistent write). Replacing that with the
  real `BASSovereignTokenAuthority` mint+verify is exactly the class of change
  the session-long discipline reserves for a fresh, **sovereign-reviewed** effort
  (same bar that closed P4 / deferred P5).
- **Blast radius:** the post-turn write/commit gate (BASObservability lifecycle) +
  every commit-token/warrant producer in `+SovereignCommit.swift`. HIGH.
- **Resume entry:** `Sources/BASSovereign/BASSovereignTokenAuthority.swift`
  (dormant, 0 prod callers — the mint/verify/policyHash-pin/single-use machinery
  already exists); the production digest seam `+SovereignCommit.swift:~1669`
  (`sovereignDigestHex`); the write gate `BASObservability/.../approveForDistillation`.
- **Precondition:** human sovereign review. Must stay byte-equal-off (opt-in) per
  ADR-014; must be reversible.

### DEFER-2 — MED-HIGH-4: wire the BR-001..BR-012 parity engine + fail-closed halt
- **Why deferred:** same sovereign-path class as DEFER-1. Production runs the
  hand-rolled `computeVerdictDecision`; the real `BASSovereignVerdictEngine` +
  its `coordinatorLaxer → halt` cross-check are test-only. Wiring the halt into
  the live turn changes the safety-decision authority → sovereign review required.
  (Mitigated today: the hand-rolled lattice only escalates, monotonic `raise()`.)
- **Blast radius:** the L14 verdict seam in `runTurn` + every verdict consumer. HIGH.
- **Resume entry:** `Sources/BASSovereign/BASSovereignVerdictEngine.swift` +
  `BASSovereignTurnVerifier.swift` (the dormant parity check);
  `+SovereignVerdict.swift` (`computeVerdictDecision`, the production path).
- **Precondition:** human sovereign review. Pairs naturally with DEFER-1 (one
  sovereign-spine arc).

### DEFER-3 — HIGH-2 (full harness): replace the stub Canonical60 runner + wire it into CI
- **Why deferred (partial — the GUARD shipped):** the ch1044 fix added a scoped
  replay-determinism regression test (`testSovereignCommitTokensAreReplay
  Deterministic`) that covers the most important regression (it would have caught
  HIGH-1). The *full* substrate-wide byte-equality harness — a real V1-vs-coordinator
  comparison whose summary includes the varying fields (nonce/token/signature),
  plus a `pre-commit-gates.sh` hook — is the larger remaining piece; the code
  itself says the real runner is "deferred to a follow-up chapter."
- **Blast radius:** test-infra + CI only (no production code). MED, low-risk —
  but sizable.
- **Resume entry:** `Sources/BASHostKit/BASStressSweepCanonical60Driver.swift:39-62`
  (the stub `identityStubRunner` to replace) + `:200-219`;
  `BASRuntimeAuditEmissionSummary.swift:63-140` (the comparison unit that needs
  nonce/token fields added); `scripts/pre-commit-gates.sh` (the CI hook).
- **Precondition:** none (test-only). Any focused session.

### DEFER-4 — MED-6: decompose the >800-LOC god-files
- **Why deferred:** `BASCognitiveBrain.swift` (4134 LOC) + `BASAutoRouteRanker.swift`
  (3802) + 46 other files over the repo's own 800-LOC max. Decomposing a
  byte-equality-sensitive 4134-LOC file is a real refactor needing its own focused
  effort with full byte-equal proof at each extraction (the coordinator's 17
  `+Extension` split is the proven pattern to follow).
- **Blast radius:** large file-count, but mechanical (pure code MOVE, no logic
  change), and byte-equal-verifiable per extraction. MED.
- **Resume entry:** `Sources/BASHostKit/BASCognitiveBrain.swift` (worst, 4134);
  `Sources/BASRuntimeCore/BASAutoRouteRanker.swift` (3802); follow the
  `EBrainRuntimeCoordinator+*.swift` extension-split precedent. Also fold in the
  ~30 commemorative `*Doctrine` literal-only files cluttering BASRuntimeCore.
- **Precondition:** none. Any session with byte-equal discipline; do per-file,
  not piecemeal-across-files.

**Suggested order (per the §recommendation above):** DEFER-3 (test harness, no
prod risk, and it guards everything else) → DEFER-1 + DEFER-2 (one
sovereign-reviewed spine arc) → DEFER-4 (mechanical, any time). LOW-8 + the
HIGH-1 guard are already done.

---

## ADR-ROADMAP NOT-YET-DEVELOPED REGISTER (ch1044 严查)

DEFER-1..4 above are the *audit-finding* deferrals. A separate 严查 (read-only,
code-verified) of the full ADR series (014/016/018/019/020) found the
**ADR-roadmap** not-yet-developed items below. The 严查's headline: **the ADRs are
honest — every "deferred/closed/infeasible" claim checks out against code, every
"LANDED" claim is backed by wired code; NO doc-says-done-but-isn't and NO
doc-says-deferred-but-built.** These items are all disclosed in ADR prose; this
consolidates them so none is lost. **All are deferred/closed — nothing is being
built in this pass.**

| ID | ADR/§ | Item | Status | Code-verified |
|---|---|---|---|---|
| **N1** | 018 §6 P6 | Genetic-algorithm evolution (population/fitness/selection/crossover) | **UNBUILT — far-future aspiration** | no GA machinery (`fitness/crossover/tournamentSelect` grep = only HW-perf hits) |
| **N2** | 018 §4 点1 / P1 | Dream-loop success-tally cost modulation (`candidateTypeSuccessTally` + bias `costs[]` before the FFI) — the ADR's *specific* 点1 | **UNBUILT** — P1 shipped a uniform `BASDeliberationBias` bump instead | `candidateTypeSuccessTally` grep EMPTY; `dreamLoopBatchScore` 0 prod callers |
| **N3** | 018 §6 P5 / §13 | Version-tree branch/merge (P5: branch reg / merge-promotion / multi-trial isolation / device-sync) | **DEFERRED — major multi-session sovereign arc** | `BASHostVersionBranchRecord` grep EMPTY; `parentVersionID` carried-but-unpopulated. (`merging()` + `BASSovereignTokenAuthority` exist dormant.) |
| **N4** | 018 §12 / 019 §4 / 014 §5 | Feedback→policy/threshold mutation (P4) | **CLOSED / NO-GO** (unsafe-by-construction; inverts ADR-012 不变量 #2) | `BASFeedbackEvent` dead-ends at advisory ticket; no threshold-mutation consumer |
| **N5** | 019 §14 / 020 §1 | P1.5b sovereign-gated caution REDUCTION (+ post-verdict re-raise) | **CLOSED — architecturally incompatible** (verdict-after-render circularity) | `cautionReduction/reRaiseVeto` grep EMPTY; only caution-UP + tilt exist |
| **N6** | 020 §1/§4 | Below-baseline / verdict-gated reduction ("Phase D") — needs render-and-verdict replay | **DEFERRED to a future sovereign ADR** | only floored `max(0, increment−credit)` exists; no replay machinery |
| **N7** | 019 §12 | Substantive per-pass refinement (passes that genuinely RESOLVE uncertainty) | **INFEASIBLE on this substrate** (deterministic loop + signal-count memory) | loop is budget-counter + bias/credit applicator; no cross-pass info source |
| **N8** | 018 §3 / MED-7 | World-A `BASShadowTrialCoordinator` actor — never instantiated in production | **UNBUILT (pure scaffold)** — P5.2 would activate it | constructed only in its own factory (`BASShadowTrialRustStateMachine.swift:134`), 0 prod callers |
| **N9** | 018 §7.3 | Direct async-surface XCTest of `buildCoordinator` loop activation | **DEFERRED — external TOOLCHAIN SIGBUS** (capability SHIPPED; only the direct test blocked) | threading wired (`EBrainHostRuntimeSynthesis.swift:121-165`); macOS-26 async-XCTest SIGBUS |
| **N10** | 018 §10 C3 | P2 trial-into-trace telemetry | **DEFERRED (deliberate — non-essential, avoids seal path)** | `evaluatedTrial.*trace` grep EMPTY; only `resolvedTrialSink` ships |
| **N11** | 019 §11 | Borderline-permit action-mode-flip fixture (prove caution-up flips a *non-block* action) | **DOC-GAP / test-not-built** (ADR notes it as follow-up) | P1.5a consequential at assessment level; mode-flip fixture not built |
| **N12** | 016 §5 / ADR_INDEX | ADR-006 + ADR-012 standalone charter docs | **DOC-GAP** | doctrine lives inline in `BASPolicy/BASRiskCalibration{Bundle,Gate,StratumSubModel}.swift`; ADR_INDEX makes it findable |

### Triage of the 12 (for a future effort — NOT this session)
- **Trivial doc tasks (any session):** N12 (ADR-006/012 charters), N11 (one fixture test).
- **External-blocked (wait for toolchain):** N9 (async SIGBUS).
- **Correctly CLOSED — keep closed (do NOT build):** N4 (feedback→policy), N5 (P1.5b reduction). N7 INFEASIBLE without a new knowledge-retrieval capability.
- **Major sovereign/multi-session arcs (fresh + sovereign-reviewed):** N3 (P5 version-tree, also = the DEFER-1/2 spine prerequisites), N8 (activate the ShadowTrial actor, part of P5.2), N6 (below-baseline reduction — a future sovereign ADR).
- **Deliberate non-builds:** N10 (trace telemetry — skipped for seal-path safety), N1/N2 (GA + the specific dream-loop lever — far-future / superseded by the shipped uniform bias).

**Net:** beyond DEFER-1..4, the only *low-cost* unregistered work is N11 + N12 (docs/test). Everything else is either correctly closed (keep closed), infeasible, external-blocked, or a major sovereign arc — none to be started at a session tail.
