# Architecture Decision Records (ADR)

Cumulative architectural decisions made through chapter 一百九十二
onward. Each ADR records a specific decision, its context, and
its consequences (red lines, doctrine pins, future migration paths).

ADR format adapted from Michael Nygard's template, simplified for
this repo's chapter-based shipping cadence.

---

## ADR-001 (chapter 192) — HINT-ONLY observability separates from decision

### Context

Chapter 192 added thermal gate / anomaly watcher / drift monitor /
adversarial mutator / heavy-tailed pressure mixer / per-row checksum.
Each could plausibly take part in decision-making (e.g. block the
permit if anomaly fires).

### Decision

All chapter-192 SafetyKit components are HINT-ONLY (red line 7).
Flags appear in row's `anomalyFlags` field, sigma values appear in
`driftSigma`, but never trigger pause / abort / verdict-mode change.
Operator reads them post-hoc via replay tool.

### Consequences

- Bench loop never auto-stops based on anomaly hints
- Substrate L11 / L14 unchanged across all chapter 192-202 work
- Single commit mouth held: permit/warrant decisions stay at L11/L14
- Counterintuitive limit: even "thermal critical" is just an
  iter-level pause hint, not session-killer (red line: gates
  continue running across pauses)

### Future migration

If a future chapter ever wants anomaly to influence decision-making,
that requires a NEW protocol (e.g. `BASSovereignAnomalyVerdict`)
to be issued by L14 — not embedded in observability.

---

## ADR-002 (chapter 192) — Per-iter timeout is iter BAIL-OUT, not session-kill

### Context

Chapter 195 added LLM call timeout (`callAFMWithTimeout` /
`callGemmaWithTimeout`). When timeout fires, what should happen?

### Decision

Timeout throws `SampleHostBenchLLMTimeoutError.timeoutExceeded`
which the bench-loop catch handles as a "first-call error" → triggers
fallback path. Bench continues with next iter.

Timeout NEVER cancels the bench task itself.

### Consequences

- Hung LLM doesn't kill the 10h bench
- Repeated timeouts increment `hybridBenchLLMTimeoutCount` (visible
  in dashboard)
- Operator can adjust threshold ([5, 300] s) mid-bench via UI
  Stepper (chapter 197 M742)
- LLM hangs are recoverable failures, not fatal

### Future migration

If a future chapter wants a "kill switch" on N consecutive timeouts,
that's a new feature — must NOT be wired into the timeout helper
itself (which stays bail-out-only).

---

## ADR-003 (chapter 200) — Synthetic-trained .mlpackage REFUSED for prod

### Context

Chapter 200 added `synthesize_corpus.py` + `verify_v0_5_synthetic.py`
to validate the bench-to-train pipeline mechanics end-to-end without
real LLM data. The synthetic v0.5_synthetic.mlpackage emerges from
the same training pipeline as a real v0.5 would.

### Decision

Synthetic-trained `.mlpackage` is **doctrine-REFUSED** for production
bundle swap (`SampleHost/ChengluMultiHead_v0.mlpackage`). It exists
only for pipeline-mechanics validation.

### Consequences

- `verify_v0_5_synthetic.py` doesn't bundle anything
- `compare_mlpackages.py` synthetic-vs-prod returns "WIN" but
  operator must NOT ship based on synthetic eval
- Operator decision (chapter 201 calibration_check + chapter 202
  compare_mlpackages) requires REAL held-out eval corpus
- 不变量 #3 strengthened: synthetic data stays out of weights even
  via legitimate-looking pipeline path

### Future migration

If a future chapter ships a "synthetic-corpus-quality scorecard"
(e.g. measuring how close synthetic distribution is to real
distribution), that scorecard is OBSERVABILITY only — doesn't
unlock production bundle swap.

---

## ADR-004 (chapter 203) — Architectural guardrails over churn refactor

### Context

Chapter 一百九十五 honest assessment listed engineering health debt:
~30% code-org health, ~5% operational readiness. Top god-file:
`SampleHost/SampleHostModel.swift` at 3914 LOC. `BehavioralAISubstrate`
has 4 source files > 5K LOC.

Two paths forward:
- A) Big-bang refactor: extract bench engine actor + protocol-driven
  DI + module boundaries. ~10-15 hours work, high regression risk.
- B) Architectural guardrails: pin current state + prevent future
  growth + plan gradual extraction in subsequent chapters.

### Decision

**Path B**. Chapter 203 ships:

1. CI workflow (`.github/workflows/test.yml`) — runs BAS + Qinao
   + SampleHost + boundary scripts + parity gate + this guard on
   every push
2. God-file size guard (`scripts/check_god_files.sh`) — pin current
   legacy god-file ceiling; new files limited to 4K warn / 6K max
3. ADR document (this file) — codify decisions so future devs (and
   future me) don't repeat the same investigation

### Consequences

- Future chapters CANNOT silently grow god files (CI blocks)
- Existing god files (HostKitCore 4770 / EBrainCognitionPlaneCore
  5347 / MemoryCore 3316) are warned but not blocked — extraction
  is future chapter scope
- Extraction in subsequent chapter (204+) is now safer (CI catches
  regressions; ADR documents intent)
- Engineering health debt visible + tracked

### Future migration

- chapter 204 candidate: extract `SampleHostBenchEngine` actor
  from SampleHostModel hybrid extension (~1500 LOC carve-out)
- chapter 205 candidate: extract MemoryCore submodules
- chapter 206 candidate: extract HostKitCore subsystems

Each extraction = single chapter, all tests pass before/after.

---

## ADR-005 (chapter 一百八十一+) — Cross-language schema parity gate

### Context

Chapter 一百八十二 noticed Swift `ChengluFeatureEncoder` and Python
`chenglu_feature_schema.py` could drift — same alphabet defined
in two languages. Drift = trained `.mlpackage` predicts garbage.

### Decision

`scripts/check_chenglu_schema_parity.py` parses both Swift and
Python schemas via regex + exact equality check. Fails CI if
alphabets differ in count, order, or values.

### Consequences

- Swift `ChengluFeatureEncoder.tones` (8 entries) MUST match Python
  `TONES`
- Adding a new tone requires editing BOTH languages atomically
- Schema parity is a HARD gate, not soft warning
- Cross-build training never breaks at inference time silently

---

## ADR-006 (chapter 208) — `.rawLLM` bench mode bypasses substrate permit gate (observability ONLY)

### Context

Chapter 196+200+204+205+206 verified: substrate's `calibrateRisk()` (in `EBrainHostRuntime+RiskService.swift:134`) recomputes risk INTERNALLY from `contextFrame.emotionalLoad / timePressure / consequenceLevel`, `currentBrain.hostGuardrailPressure`, `constitutionSignals / courtSignals / presenceSignals`. The bench's `riskLevel` argument is IGNORED. On benign + low-stake + .primary workflow, substrate STILL routes 100% to `.delay` permit because internal accumulated risk pushes totalRisk above mediumThreshold by design.

This is correct production substrate behavior (不变量 #2 神经不掌权 + protective doctrine). But it makes training-data accumulation impossible via the substrate path. The router (ChengluPreflight: signature → AFM/Gemma) needs LLM-response data to train. Without LLM data, no v0.5 model.

### Decision

New `SmokeMode.rawLLM` case ("raw-llm" raw value):
- Substrate STILL runs (audit accumulates, contextFrame still built)
- `permitMode` STILL recorded in JSONL row (substrate's actual decision)
- BUT `dispatchPolicy` is FORCED to `.singleLLM` regardless of permitMode
- LLM (AFM via router preference + Gemma fallback) actually fires per iter
- Resulting JSONL is **OBSERVABILITY ONLY**

### Consequences

- ChengluPreflight router can train on signature → AFM-vs-Gemma success outcomes
- Training data NEVER drives production permit decisions (red line 7 held)
- 不变量 #2 held: substrate's production decisions UNCHANGED — `.rawLLM` only affects bench's dispatch, not substrate's internal logic
- Bench JSONL clearly labeled `smokeMode: "raw-llm"` so downstream tools can grep + filter
- ChengluPreflight router is metadata (not permit), so training on `.rawLLM` data is doctrine-aligned

### Future migration

If a future chapter wants to ALSO bypass substrate for production permit decisions, that's a NEW ADR (ADR-007+) and contradicts ADR-006's "observability only". Must be rejected.

If future training pipeline starts using `.rawLLM` data for permit-prediction model training, that's also a contradiction — `.rawLLM` data shows what AFM/Gemma produces under permissive dispatch, NOT what substrate would have permitted. PermitPredict head should train on full bench data including substrate-skip rows (chapter 208+ candidate).

### Related red lines

- Red line 7 (HINT-ONLY observability): held
- 不变量 #2 (神经不掌权): held — substrate internal logic unchanged
- 不变量 #3 (私有经验不进权重): held — `.rawLLM` data feeds offline retrain only

---

## ADR-007 (chapter 209) — Adaptive cooldown ladder over fixed sleep

### Context

Chapter 一百九十七 (M740) shipped `pauseOnSerious` so operators on
hot devices could let `.serious` thermal trip the gate in addition
to `.critical`. Pause path slept FIXED 30 seconds then re-checked.

Chapter 208 .rawLLM 2h iPhone 17e bench surfaced architectural
mismatch: iPhone 17e holds `.serious` thermal for minutes-to-hours
under sustained bench load (recovery requires ~5-10 min idle).
With fixed 30s sleep, gate fired 236 times in 2 hours (93%).
Net: 17 real-LLM rows in 2h. Bench was effectively a polling loop
that woke up every 30s, found device still hot, slept again, while
the wakes themselves added enough work to keep heat from radiating.

### Decision

Replace fixed 30s sleep with explicit ladder bounded at 5 minutes:

| pauseStreak | sleep |
|---|---|
| 0 | 0 (gate said .run) |
| 1 | 30s (chapter 一百九十七 baseline preserved) |
| 2 | 60s |
| 3 | 120s |
| ≥ 4 | 300s (5-min ceiling) |

Streak resets to 0 on first `.run` decision. Logic lives in
`SampleHost/SampleHostThermalCooldown.swift` as a pure value type
(no @Published, no actor, no I/O); `SampleHostModel`'s bench loop
holds one instance per Run/Stop cycle.

The 5-min ceiling is the OUTER bound — deliberately not "sleep
forever". Stuck-hot device still emits one paused-row every 5 min
(JSONL replay sees the gap), and a cooled ambient unlocks the
bench within reasonable latency.

### Consequences

- iPhone 17e sustained `.serious` no longer wastes 30s polling.
  Cooldown widens automatically; device gets uninterrupted
  windows to radiate heat.
- JSONL paused-rows tagged with `cooldown:<label>` +
  `cooldown-streak:<n>` so downstream replay can reconstruct
  thermal trajectory.
- Pure value type co-exists with chapter 一百九十二 SafetyKit
  pattern (single-source-of-truth: this file owns the
  adaptive-cooldown invariant; SampleHostModel calls in).
- 7 unit tests pin ladder constants — re-tuning the schedule
  requires updating both source AND tests (deliberate friction).
- First file extracted out of `SampleHostModel`'s bench-loop body
  per ADR-004 future migration list. Sets the pattern for
  upcoming chapter 210 SampleHostBenchEngine actor extraction.

### Doctrine pins (red-line preservation)

- Red line 7 (HINT-ONLY observability): held — cooldown is
  local control-flow, doesn't affect substrate decision /
  permit / verdict. Substrate's `calibrateRisk()` still owns risk.
- 不变量 #1 (先醒再答): held — wake path unchanged.
- 不变量 #2 (神经不掌权): held — permit single-mouth stays at
  L11 / L14. Cooldown only paces the bench iter loop.
- 不变量 #3 (私有经验不进权重): held — no weight write.

### Future migration

If a future chapter wants per-thermal-state cooldown (e.g. shorter
ladder for `.fair` flapping vs longer for sustained `.critical`),
extend `SampleHostThermalCooldown` with a per-state streak, NOT
add another sleep call site. Single-source-of-truth principle
must hold.

If 5-min ceiling proves insufficient on iPhone Pro Max sustained
load, the ceiling constant is the only knob to tune — keep the
ladder shape, raise the ceiling. Don't add more rungs (4-rung
ladder is the doctrine; longer ladders are easier to mis-read).

---

## ADR-008 (chapter 210) — Per-iter context derive as pure value type

### Context

Chapter 二百九 carved out thermal cooldown into `SampleHostThermal-
Cooldown.swift`. Bench loop body was still ~95 LOC of inline pure-
derive logic (stride rotation / mutation seed / smokeMode-conditional
layer profile / heavy-tailed pressure mixer / adversarial mutator /
prompt catalog selection / final signature derivation) inlined inside
the iter loop in `SampleHostModel.startHybridBench()`.

This made the iter loop hard to:
- Unit-test in isolation (would need a fake bench Task, mocked
  @Published state, etc.)
- Replay deterministically for a single iter (couldn't construct
  the same context outside a running bench)
- Reason about (mixed pure derive + I/O + @Published mutation)

### Decision

Extract per-iter derive into `SampleHostBenchIterContext`, a pure
value type with a single `derive(...)` static factory.

Inputs (all per-iter or per-bench-config, no @Published, no I/O):
- iter / rotationPeriod / strideRotation / mutationCount /
  smokeMode / mutationProbability

Outputs (typed value bundle):
- chosenStride / mutationSeed / layerProfile / pressureProfile /
  adversarialKind / prompt / signature

Bench loop replaces 95 LOC of inline derive with 12 LOC of typed
read-back, shrinking SampleHostModel.swift from 4097 → 4028 LOC.

### Consequences

- Bench iter context is now independently unit-testable. 9 chapter
  210 tests pin: deterministic-by-iter / stride rotation schedule /
  mutationSeed modulo / canonical-mode no-overrides / fourteenLayer
  populates profile / benign pins low-risk / rawLLM no-override /
  heavyTailed pressure mix / defenses against zero divisors.
- Replay tools can construct the exact same context for any (iter,
  config) tuple — useful when reconstructing a row's signature
  during JSONL post-processing without spinning up a bench task.
- Sets the typed-value-bundle pattern for chapter 二百十一 +
  二百十二 carve-outs (LLM dispatcher / sink protocols will consume
  this struct as input).
- `FourteenLayerSmokeProfile.Profile` gained an `Equatable`
  conformance (added in the carve-out file, not pushed back into
  the god file).

### Doctrine pins

- Red line 7 (HINT-ONLY observability): held — context is pure
  derive, no decision-making. Substrate's `calibrateRisk()` etc
  remain authoritative.
- 不变量 #1-#3: held — no wake / permit / weight changes.
- chapter 一百九十二 single-source-of-truth: this file owns the
  per-iter-input → prompt+signature derive invariant. Bench loop
  calls in via `derive(...)`.

### Future migration

Future smokeMode additions (e.g. a hypothetical `.systematicReversal`
mode that flips signature semantics) modify `derive(...)` here —
NOT scatter another switch into the bench loop. The "single derive
function" invariant is the doctrine; once you have two switches in
two places they will drift.

---

## Future ADR candidates

| Topic | Chapter |
|---|---|
| SampleHostBenchEngine actor (carve out iter loop body to actor) | 211 |
| SampleHostLLMDispatching protocol (DI for AFM/Gemma adapters) | 212 |
| SampleHostBenchSink protocol (decouple JSONL persistence) | 213 |
| MemoryCore submodule split | 214 |
| EBrainCognitionPlaneCore subsystem extraction | 215 |
| HostKitCore subsystem extraction | 216 |
| Resume-from-iter mechanism (vs settings-only) | tbd |
| Production canary (shadow predict) | tbd |
| Per-pressure-stratum sub-models | tbd |
| Telemetry sink protocol | tbd |
| Cross-process auto-restart | tbd |

Each candidate ADR becomes concrete when its chapter ships. Pre-ship
investigation should reference whether the pattern in question
contradicts existing ADRs (especially ADR-001 HINT-ONLY and ADR-002
BAIL-OUT-not-kill).

---

## Doctrine summary (red lines that must hold across all chapters)

| Red line | Doctrine | First defined |
|---|---|---|
| 红线 7 | Watcher hints only — never decides | chapter 191 |
| 红线 10 | Internal vocabulary (sovereign, verdict, etc) doesn't leak to public API | chapter 一百二十一 |
| 不变量 #1 | 先醒再答 (substrate wakes first, then answers) | base substrate |
| 不变量 #2 | 神经不掌权 (neural networks don't take power) | base substrate |
| 不变量 #3 | 私有经验不进权重 (private experience doesn't enter weights) | base substrate |
| Single commit mouth | L11 (permit) / L14 (warrant) own all production decisions | chapter 一百八十九 |
| Anti-magic-number | All thresholds + bounds in named typed constants | chapter 一百八十五 |
| Anti-drift 3-site | Schema bumps synced across struct + tests + governance | chapter 一百九十二 |

These cannot be relaxed by future chapters. ADR-NNN that
proposes to relax must be explicitly rejected.
