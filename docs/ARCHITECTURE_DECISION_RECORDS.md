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

## Future ADR candidates

| Topic | Chapter |
|---|---|
| Bench engine actor extraction | 204 |
| Resume-from-iter mechanism (vs settings-only) | 205 |
| Production canary (shadow predict) | 206 |
| Per-pressure-stratum sub-models | 207 |
| Telemetry sink protocol | 208 |
| Cross-process auto-restart | 209 |

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
