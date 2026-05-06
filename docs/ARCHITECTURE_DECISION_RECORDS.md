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

## ADR-009 (chapter 211) — Extract dispatch policy + single-source derive

### Context

Chapter 一百七十八 (M628) shipped `SampleHostHybridDispatchPolicy`
buried inside `SampleHostModel.swift` (~85 LOC of typed mapping
from substrate `permitMode` to LLM dispatch behavior, plus a
`SampleHostHybridDispatchCanned` companion enum for skip-policy
canned responses).

Chapter 二百八 (M784, ADR-006) added a `.rawLLM` smokeMode that
must force `.singleLLM` regardless of permitMode (bench
observability ONLY — bypasses substrate's protective `.delay`
permit so AFM/Gemma actually fire to accumulate training data).
The override was a 8-LOC inline if/else inside
`startHybridBench()` next to the dispatchPolicy decision site.

Two doctrine sites for the same invariant (permit-mode →
dispatch shape) is anti-doctrine. Future chapters adding new
overrides (e.g. a hypothetical `.shadowOnly` mode) would scatter
more inline branches.

### Decision

Extract `SampleHostHybridDispatchPolicy` + `SampleHostHybridDispatch-
Canned` to dedicated file `SampleHostHybridDispatchPolicy.swift`.
Add a single-source `derive(permitMode:forceSingleLLM:)` static
method that combines:
- chapter 一百七十八 baseline mapping (preserved as `from(permit-
  Mode:)` for backward compat)
- chapter 二百八 `.rawLLM` bypass (via `forceSingleLLM` flag)

Bench loop replaces the inline if/else with a one-line call:

```swift
let dispatchPolicy = SampleHostHybridDispatchPolicy.derive(
    permitMode: permitMode,
    forceSingleLLM: smokeMode == .rawLLM)
```

The doctrine of WHY `.rawLLM` forces `.singleLLM` is documented
in the policy file's `derive(...)` doc-comment with a link to
ADR-006. The flag name (`forceSingleLLM`) is descriptive on its
own; future overrides can add more flags or replace with an
opaque struct without touching the bench loop.

### Consequences

- `SampleHostModel.swift` drops from 4028 → 3942 LOC, **clearing
  the chapter 203 god-file 4K WARN threshold for the first time
  in 3 chapters of carve-outs**.
- Single source of truth for permit-mode → dispatch invariant.
- 5 chapter 211 tests pin: derive-default-matches-from /
  forceSingleLLM-overrides-all-permits / raw-values-stable /
  skipsLLM-partition / canned-responses-non-empty.
- Future smokeMode overrides go to one place. No more scatter.

### Doctrine pins

- 不变量 #1 (先醒再答): held — substrate decides FIRST. The
  `permitMode` arg to `derive(...)` is what substrate produced;
  we just map it.
- 不变量 #2 (神经不掌权): held — this enum doesn't produce
  permit decisions; it consumes them.
- 不变量 #3 (私有经验不进权重): held — no weight write.
- Red line 7 (HINT-ONLY observability): held — control-flow
  only.
- ADR-006 preserved: `.rawLLM` data is RECORDED but doctrine-
  REFUSED for production permit predictions.

### Future migration

If a chapter wants per-permit flex (e.g. `.delay` to actually
fire LLM in a debug-mode A/B), add a flag to `derive(...)`:
```swift
static func derive(
    permitMode: String,
    forceSingleLLM: Bool = false,
    forceFireOnDelay: Bool = false  // hypothetical
) -> Self
```
Document each flag with its ADR / doctrine source. Don't add
inline branches at the call site.

If the flag matrix grows past 3-4 booleans, replace with an
opaque `DispatchOverrides` struct. Stop adding flag args.

---

## ADR-010 (chapters 二百十二 → 二百三十八) — Architectural deconstruction wave: 30-chapter rebirth

### Context

Chapters 二百九 → 二百十一 shipped the first 3 architectural carve-
outs (cooldown / iter context / dispatch policy) per ADR-007 to ADR-
009 doctrine. After those landed, 27 more chapters (二百十二 → 二百三
十八) executed the same pattern systematically until SampleHost
target's two god files thinned dramatically.

Pre-arc state (chapter 二百八 末尾):
- `SampleHost/SampleHostModel.swift`: 4097 LOC
- `SampleHost/SampleHostView.swift`: 1146 LOC
- chapter 203 god-file guard: WARN on SampleHostModel ≥ 4K

Post-arc state (chapter 二百三十八 末尾):
- `SampleHost/SampleHostModel.swift`: 637 LOC (-3460, -84.5%)
- `SampleHost/SampleHostView.swift`: 101 LOC (-1045, -91.2%)
- chapter 203 god-file guard: CLEAR on both targets
- 28 new dedicated focused files

### Decision

Apply 5 systematic carve-out patterns over 30 chapters:

**Pattern 1: Pure value-type extraction**
Self-contained `enum` / `struct` / pure-derive helper → dedicated
file. Examples: cooldown ladder (chapter 二百九), iter context
(chapter 二百十), prompt catalog (chapter 二百十二), 14-layer profile
(chapter 二百十三), row schema (chapter 二百十四), bench config
(chapter 二百十五), legacy bench runner (chapter 二百十七), prompt
types (chapter 二百十八).

**Pattern 2: Single-source-of-truth consolidation**
Multi-site duplication → one canonical file with derive helper.
Examples: dispatch policy (chapter 二百十一: chapter 178+208 hack),
14-layer profile (chapter 二百十三: 3-site consolidation), risk
derivation (chapter 二百二十一: 3-site stake→risk), bench bounds
(chapter 二百二十二: 11 inline clamps → 10 named constants), AFM-
bench bounds (chapter 二百二十三: shared with hybrid).

**Pattern 3: Typed value-bundle factory**
Repetitive 50+-field constructions → typed factory function on the
schema struct. Examples: paused-row builder (chapter 二百二十).

**Pattern 4: Standalone SwiftUI struct from inline view block**
`private var fooPanel: some View` on parent View → standalone
`struct SampleHostFooPanel: View` taking `@ObservedObject var
model`. Examples: chapter 二百二十四 (test panels), chapter 二百二
十五 (AFM bench panel), chapter 二百二十六 (legacy bench panel),
chapter 二百二十七 (hybrid bench panel — 529 LOC), chapter 二百二十八
(resume banner), chapter 二百二十九 (13-layer turn detail), chapter
二百三十 (active-session panel), chapter 二百二十六 (status helpers
move-with-panel).

**Pattern 5: Extension-on-Model carve-out (after access promotion)**
`@Published private(set) var` → `@Published var` (chapter 二百三十
三 / M815) + `private func`/`fileprivate func` → `func` so cross-
file `extension SampleHostModel` files can write state.
Examples: LLM helpers (chapter 二百三十三), single-prompt tests
(chapter 二百三十四), checkpoint lifecycle (chapter 二百三十五),
legacy bench entry (chapter 二百三十六), AFM bench entry (chapter
二百三十七), hybrid bench entry (chapter 二百三十八 — 1172 LOC).

### Consequences

- **God-file guard**: Both SampleHost target files now well under
  4K WARN threshold (637 + 101 = 738 LOC total in the two original
  god files, vs 5243 LOC pre-arc).
- **28 single-responsibility files**: Each carve-out has one file,
  one doctrine, independent test surface. Future tuning goes to
  one place.
- **Pattern reuse**: 5 patterns above are templates for future
  carve-outs (ADR-013 candidate: same patterns applied to BAS-
  side god files HostKitCore / EBrainCognitionPlaneCore /
  MemoryCore — multi-day each).
- **0 regressions across 128 tests** during the entire 30-chapter
  arc. The disciplined "extract → test → commit" cadence held.
- **Access doctrine shift**: 70 `@Published private(set)` →
  `@Published` + 8 `private` → `internal` to enable cross-file
  extensions. View-reads-Model-writes convention preserved by
  doctrine + 24-chapter carve-out evidence (no carved file
  actually mutates model state via extension; only Model
  methods themselves now in extension files do).

### Doctrine pins (red-line preservation across all 30 chapters)

- 不变量 #1 (先醒再答): held — substrate decides FIRST in every
  carve-out.
- 不变量 #2 (神经不掌权): held — permit single-mouth at L11 / L14;
  no carve-out introduces a new commit path.
- 不变量 #3 (私有经验不进权重): held — bench data feeds offline
  retrain only.
- Red line 7 (HINT-ONLY observability): held — anomaly + drift
  watchers + cooldown + safety-kit never decide.
- chapter 二百八 / ADR-006 `.rawLLM` doctrine: held — bench-data-
  only path preserved, never feeds production permit decisions.
- chapter 一百九十二 single-source-of-truth: ✓ extended to 14+
  invariant domains (cooldown / iter context / dispatch policy /
  prompt catalog / 14-layer profile / row schema / bench config /
  JSONL runners / legacy bench / prompt types / foundation
  helpers / row builders / risk derivation / settings bounds /
  Cthulhu helpers via stable kebab-case raw values).

### Future migration

ADR-013+ candidates after this arc:

| Topic | Chapter |
|---|---|
| BenchEngine actor (true carve from `extension SampleHostModel` → standalone `actor SampleHostBenchEngine`) | tbd |
| SampleHostLLMDispatching protocol (DI for AFM/Gemma adapters; mockable for unit tests) | tbd |
| SampleHostBenchSink protocol (decouple JSONL persistence — chapter 一百四十九 `iterations.jsonl` writer becomes mockable) | tbd |
| MemoryCore submodule split (BAS substrate, multi-day) | tbd |
| EBrainCognitionPlaneCore subsystem extraction (BAS substrate, multi-day) | tbd |
| HostKitCore subsystem extraction (BAS substrate, multi-day) | tbd |
| Resume-from-iter mechanism (vs settings-only) | tbd |
| Production canary (shadow predict) | tbd |
| Per-pressure-stratum sub-models | tbd |
| Telemetry sink protocol | tbd |

### Lessons (for future architectural deconstruction waves)

1. **Pure value types extract cheapest**: enums + structs without
   I/O are 1-day chapters. Schema + helpers + presets bundles
   are predictable shape carve-outs.

2. **SwiftUI views extract cleanly via composition**: `@Observed-
   Object var model` + standalone struct preserves the live
   binding. View body becomes pure composer of N panels.

3. **Cross-file extension on `@Published private(set)` requires
   access promotion**: doctrine cost is loose encapsulation
   (any module-internal code COULD write); doctrine benefit is
   carve-out feasibility. The 24 carve-out chapters that
   completed without ANY external write to model state validates
   the convention is preserved by doctrine, not just by
   `private(set)` enforcement.

4. **The biggest function is movable but expensive**: the 1172-
   LOC `startHybridBench` body moved cleanly to a dedicated
   extension file (chapter 二百三十八). It's still 1172 LOC of
   complex async logic — but now isolated, regression-tested, and
   the path to converting it into a true `actor` is clear (next
   ADR candidate).

5. **30-chapter arcs sustained 0 regressions** because each
   chapter ships independently committed + tested + reverted-
   able. Disciplined incrementalism beats big-bang refactor.

---

## ADR-011 (chapters 二百四十 → 二百四十六) — Bench-loop body deconstruction + DI protocols

### Context

Post-ADR-010 (chapters 二百九 → 二百三十八) the SampleHost target had
both god files (Model + View) thinned to <1K LOC. The remaining
1223-LOC concentration was `SampleHostHybridBenchEntry.swift` — the
hybrid bench loop body lifted from `startHybridBench()` in
chapter 二百三十八.

Inside that 1223-LOC file: 4 coherent sections still inline (5-head
CoreML invocation / closed-loop substrate observation / regression
residuals / LLM dispatch), each a candidate for extraction into a
typed value bundle + extension method.

### Decision

7-chapter wave (二百四十 → 二百四十六) carving the bench loop body
into typed bundles + adding DI protocol contracts:

| Chapter | M    | Carve-out                                          | Lines saved |
|---------|------|----------------------------------------------------|-------------|
| 二百四十   | M822 | `SampleHostBenchCoreMLBundle` (5-head bundle)      | -42         |
| 二百四十一 | M823 | 9-way SafetyKit split                              | (cohesion)  |
| 二百四十二 | M824 | `SampleHostBenchPostLLMObserver` (closed-loop)      | -66         |
| 二百四十三 | M825 | `SampleHostBenchRegressionResiduals`                | -45         |
| 二百四十四 | M826 | `SampleHostBenchLLMDispatcher` (LARGEST: ~340 LOC)  | -308        |
| 二百四十五 | M827 | `SampleHostBenchLLMDispatching` protocol marker     | (DI)        |
| 二百四十六 | M828 | `SampleHostBenchSinking` protocol marker            | (DI)        |

Bench loop body trajectory: 1223 → 762 LOC (-461, -37.7%).

### Consequences

- **Bench loop is now declarative**: 4 typed bundle reads + 2 method
  calls + 4 sections of cohesive narrative (iter setup / substrate
  routing / row construction / iter postscript). Each section is
  ~50 LOC. Total < 800 LOC.

- **DI protocols enable test injection**: 2 protocol contracts
  (`SampleHostBenchLLMDispatching` + `SampleHostBenchSinking`)
  document the bench loop's external dependencies. Future test
  chapters can inject `MockLLMDispatcher` + `RecordingMockSink`
  to drive the bench loop deterministically without CoreML / AFM /
  Gemma / FS.

- **0 regressions across all 7 chapters**: 128 tests passing. The
  carve-out pattern (typed-bundle → extension method) is now
  fully validated for async + counter-mutating logic.

### Doctrine pins (red-line preservation across 38-chapter arc 二百九 → 二百四十六)

- 不变量 #1 (先醒再答): held — substrate decides FIRST in every
  carve-out
- 不变量 #2 (神经不掌权): held — permit single-mouth at L11 / L14
- 不变量 #3 (私有经验不进权重): held — bench data feeds offline
  retrain only
- Red line 7 (HINT-ONLY observability): held — anomaly + drift
  + cooldown + safety-kit never decide
- chapter 二百八 / ADR-006 `.rawLLM` doctrine: held
- chapter 一百九十二 single-source-of-truth: ✓ extended to 23+
  invariant domains

### Final state (post-ADR-011)

```
SampleHost target file structure:
  SampleHostModel.swift:           4097 →  637 LOC  (-84.5%)
  SampleHostView.swift:            1146 →  101 LOC  (-91.2%)
  SampleHostHybridBenchEntry.swift: N/A →  762 LOC  (largest carve)
  SampleHostBenchSafetyKit.swift:  727  → DELETED   (split into 9)

  Total .swift files: 8 → 49
  god-file 4K WARN guard: clear on all SampleHost files
  Tests: 113 → 128 / 0 failures across 38-chapter arc
  Commits: 38 (one per chapter, all pushed to origin)
```

---

## Honest backlog (post-ADR-011 — explicitly out of scope for SampleHost-side architectural deconstruction)

The following items remain as future architectural work but require
**multi-session arcs** (not single-chapter incrementally feasible):

### Multi-day BAS substrate carve-outs

| File | LOC | Top-level types | Estimated scope |
|---|---|---|---|
| `EBrainCognitionPlaneCore.swift` | 5347 | ~80 | 2-3 dedicated sessions; cross-module dep audit needed |
| `HostKitCore.swift` | 4770 | ~70 | 2-3 dedicated sessions; many module consumers |
| `MemoryCore.swift` | 3316 | ~49 | 1-2 dedicated sessions; cleanest of the three |

These BAS substrate god files are genuinely beyond surgical scope.
Each splits across multiple substrate modules + has many cross-
module consumers. Doctrine: surgical-incremental (chapter-per-day)
applies to SampleHost-target files; BAS substrate refactors need
multi-session bundling to track cross-module changes coherently.

### Multi-session SampleHost-side work (deferred but feasible)

| Topic | Estimated scope |
|---|---|
| SampleHostBenchEngine actor (true async actor, not just extension) | 1 session: redesign concurrency boundary with `actor` semantics |
| Concrete `MockLLMDispatcher` + `RecordingMockSink` test fixtures | 1 chapter each |
| Bench engine tests via DI mocks | 1 chapter |
| Resume-from-iter mechanism (vs settings-only) | 1 chapter |
| Production canary (shadow predict) | 1 chapter |
| Per-pressure-stratum sub-models | 1 chapter |
| Telemetry sink protocol | 1 chapter |
| Cross-process auto-restart | 1 chapter |

### What "完整 重生" means at this point

The SampleHost target is **structurally reborn**:
- 49 single-responsibility files (was 8)
- 38 chapters of disciplined incrementalism with 0 regressions
- 5 carve-out patterns documented as doctrine (ADR-007 → 011)
- 70 access-promoted `@Published private(set)` validated by 38
  chapters of "View reads, Model writes" convention
- 2 DI protocol contracts ready for future test injection

Further architectural work is **substrate-level / cross-module**
or **concurrency-redesign-level** — both qualitatively different
from the surgical SampleHost-side deconstruction completed in
chapters 二百九 → 二百四十六.
| Production canary (shadow predict) | tbd |
| Per-pressure-stratum sub-models | tbd |
| Telemetry sink protocol | tbd |
| Cross-process auto-restart | tbd |

Each candidate ADR becomes concrete when its chapter ships. Pre-ship
investigation should reference whether the pattern in question
contradicts existing ADRs (especially ADR-001 HINT-ONLY and ADR-002
BAIL-OUT-not-kill).

---

## ADR-012 (chapter 二百六十一) — Hybrid offline-pipeline doctrine: ADR-006 strict preserved + version-bumped bundle update for permit thresholds

### Context

附录 V (chapter 二百四十七) audited the substrate's closed-loop
state and identified Gap #1 as the largest remaining doctrine gap:
"Risk gate adaptive recalibration". The substrate's L11 risk gate
ships fixed thresholds (e.g. `mediumRiskThreshold`, `highRisk
Threshold`) that were tuned offline once. As more bench data
accumulates, the right thresholds drift — a tone signature that
empirically produces 90% block-or-delay should not still be using
the original threshold tuned at 50%.

ADR-006 (chapter 208) is strict: bench data is observability ONLY,
NEVER feeds production permit. That blocks naïve "self-tuning"
adaptive thresholds — exactly the right call for live mutation
of weights / permit logic. But it *also* would block "we ran a
month of benches, aggregated by stratum, found three thresholds
need a small tune, ship a new version of the bundle".

The user's plan-mode AskUserQuestion (附录 V context) explicitly
chose **Hybrid**: keep ADR-006 strict + permit a separate offline
pipeline that aggregates *generalized* (non-host-specific) signal
across many users / sessions, produces a versioned threshold
bundle, and ships via explicit bundle replacement. The bundle is a
typed value, signed by L14 sovereign warrant, deployed by operator
review — not a live mutation.

### Decision

ADR-006 strict preserved verbatim:
- Live bench data NEVER mutates production permit threshold.
- `.rawLLM` mode and every bench JSONL pipeline remain
  observability-only as far as the substrate's own permit logic
  is concerned.
- The substrate's L11 risk gate does not read from any bench-data
  store.

Newly permitted via ADR-012:
- A separate **offline aggregation pipeline** (Mac-side, distinct
  from substrate runtime) reads bench JSONL across many sessions,
  aggregates by stratum (e.g. tone × stake × confidant), strips
  host-specific identifiers, and produces a typed
  `BASRiskCalibrationBundle` with per-stratum threshold deltas.
- The bundle is **version-bumped** (`bundleVersion: String`) so
  every deployed version is auditable. `bundleVersion` strings
  follow `vN.M.P` format with a monotonic sequence.
- Each bundle carries an L14 **sovereignWarrant** ref —
  unsigned bundles are refused. The signing workflow is operator
  review, not auto-derive: operator inspects the offline pipeline's
  output, decides whether the deltas are reasonable, requests a
  warrant, ships the bundle.
- The substrate's L11 risk gate, on bundle replacement, applies
  the threshold deltas to its in-memory tunables. This is a
  **deploy-time mutation**, not a per-turn mutation. Two
  consecutive turns with the same bundle produce identical
  decisions.

### Boundary (what doctrine permits and what it forbids)

Permitted:
- Aggregating bench data offline by **stratum**, removing
  host-identifiers (chapter 一百零二 五级删除-aware: only data the
  user has not revoked is eligible).
- Producing a typed `BASRiskCalibrationBundle` with a versioned
  diff against the prior bundle.
- Operator-reviewed deployment (chapter 一百七十七 P0→P3
  staircase pattern: explicit canary + version bundle replacement).
- L14 sovereign warrant signing each bundle; ledger records
  every bundle replacement.

Forbidden (would require ADR-013+ to relax):
- Live mutation of any permit threshold from inside a turn.
- Per-host-specific threshold tuning (host-specific data must NOT
  enter the bundle — bundle is generalized signal only).
- Auto-deploy without operator review.
- Bundle replacement without L14 warrant ref.
- Hidden or implicit threshold changes (every change is explicit
  in `BASRiskCalibrationBundle.strataDeltas[]`).
- Bundle replacement during an active turn (replacement is
  between-turn only).

### Consequences

- ADR-006 ("bench JSONL is observability ONLY") remains the per-
  turn truth: live bench data never feeds live permit decision.
- ADR-012 introduces the **between-deploy** path: aggregated
  generalized signal → version-bumped bundle → operator review →
  L14 warrant → deploy → between-turn threshold mutation.
- Substrate's per-turn behavior is auditable: given a fixed
  bundle version, every turn with the same input produces the
  same decision. Bundles are immutable once shipped.
- Substrate exposes `bundleVersion` in audit emission (chapter
  二百六十四 will wire this) so audit walkers can grep "this turn
  ran under bundle vN.M.P".
- 不变量 #3 ("私有经验不进权重") is reinforced — host data is
  filtered OUT of the bundle's input pipeline. The bundle
  represents the signal pattern across a population of sessions,
  not any individual host's history.
- Red line 7 (HINT-ONLY observability) is held within each turn:
  no live observation feeds permit. The deploy step is operator
  decision, not observation feedback.

### Implementation (chapters 二百六十二 → 二百六十五)

| Chapter | Component | Module |
|---|---|---|
| 二百六十二 | `scripts/aggregate_risk_stratum.py` (Mac-side) | scripts/ |
| 二百六十三 | `BASRiskCalibrationBundle` typed value | BASPolicy |
| 二百六十四 | L11 risk gate accepts bundle replacement | BASPolicy |
| 二百六十五 | Per-stratum sub-models (deferred — needs real data) | BASPolicy |

Chapter 二百六十二 ships the offline aggregator. Chapter 二百六十三
ships the typed bundle schema. Chapter 二百六十四 wires bundle
replacement at the substrate side. Chapter 二百六十五 (per-stratum
sub-models) is deferred until enough real bench data exists to
justify per-stratum heads (附录 V noted this depends on Stage 3
real-bench output).

### Related red lines

- ADR-006 (`.rawLLM` observability-only): held — ADR-012 only
  allows between-deploy mutation, never per-turn.
- 不变量 #2 (神经不掌权): held — bundle deploy is operator-
  reviewed + L14-signed. Substrate logic doesn't auto-decide
  threshold drift.
- 不变量 #3 (私有经验不进权重): held — bundle is generalized
  signal (host data filtered out at aggregation step).
- 红线 7 (HINT-ONLY observability): held — every per-turn
  observation remains observation; deploy is a separate event
  outside the per-turn loop.

### Future migration

If a future chapter wants to:
- Auto-deploy bundles without operator review → contradicts
  ADR-012, must be a new ADR (ADR-013+) and probably should be
  refused (operator review is the trust boundary).
- Permit-host-specific tuning inside a bundle → contradicts
  不变量 #3, must be refused.
- Per-turn threshold mutation from observation data → contradicts
  ADR-006, must be refused.
- Multi-bundle composition (e.g. "host A uses bundle X, host B
  uses bundle Y") → likely permissible under ADR-012 but needs
  explicit clarification of how bundle selection happens (must
  not leak host-specific data).

The chapter 二百六十一 ship is the doctrine document only. Chapters
二百六十二-二百六十四 ship the typed pipeline + bundle + deploy
path. Chapter 二百六十五 awaits real bench data.

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
