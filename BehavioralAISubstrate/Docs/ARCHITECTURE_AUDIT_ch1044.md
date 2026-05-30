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
