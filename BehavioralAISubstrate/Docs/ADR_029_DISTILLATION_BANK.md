# ADR-029 — DistillationBank (L13 蒸馏池)

> **Status: BUILT + TESTED (ch1047, opt-in / byte-equal-off).** Closes gap-audit item L13 #17 — the
> one genuinely-absent capstone capability. Per ADR-014 it is additive and byte-equal when unused.

## 1. The gap

The v1.0 thesis is "别榨答案,榨能力 … 把一次次调用榨成未来小器官" (§15): every governed LLM call should
leave a reusable distillation asset, and the high-quality ones accumulate into a pool that later
trains small on-device organs (roadmap WP15 训练与蒸馏平台). The gap audit found the *export path*
already built (`BASLearningExportBundle`, `QinaoLearningExporter`, the evolution-governance furnace)
but the persistent *pool/bank* — §6 step 19 "高质量 trace 进入蒸馏池" — MISSING: only a `distillTeacherRef`
field and the WP15 roadmap entry existed.

## 2. What was built

- **`BASDistillationBank`** (`Sources/BASMemory/`, deps BASRuntimeCore) — the pool. A `BASSchemaVersioned`
  immutable value type: `ingesting(_:)` returns a NEW bank + an admission verdict; `top(_:)` ranks by
  composite score; `entries(forPurpose:)` / `entries(ofKind:)` query; `exportManifest(bundleID:top:)`
  emits a `BASLearningExportBundle` (the bridge to the WP15 trainer). The host persists the bank via
  Codable — same "types + host owns storage" pattern as the vaults.
- **`BASDistillationEntry`** — one pooled asset, holding REFS only (`sourceRef` = traceID/bundleID),
  a `sourceKind`, an opaque `purposeTag`, `BASDistillationQuality`, the three safety flags, and
  `producedAt`. **No raw prompt/response body** (红线).
- **`BASDistillationAdmissionPolicy`** — fail-closed `evaluate(_:)`: scrub → privacy → sovereign
  (the three red-line gates, ALWAYS enforced regardless of policy) → optional verifier requirement →
  quality floor. Plus dedup by `sourceRef`.
- **Adapters** — `BASDistillationEntry.from(learningExportBundle:…)` (BASMemory) and
  `BASDistillationEntry.from(processTrace:…)` (BASOrchestration — the only module importing both
  BASMemory + BASOrgan). The ProcessTrace adapter returns nil for a *rejected* trace (no output to
  distill), tying this session's `BASProcessTrace` to the pool.

## 3. Why this is sound

The three safety gates are enforced at admission independent of the policy fields, so an unsafe asset
can never enter the pool even with a permissive policy (proven: `testRejectsUnsafeFailClosed`). The
pool holds refs + governance metadata only — never a body — so it cannot leak hidden reasoning or
high-sensitivity content (§13.1). Ingest is immutable (`testIngestIsImmutable`): the original bank is
never mutated, matching the codebase immutability rule and making concurrent reads safe.

## 4. Opt-in / byte-equal (ADR-014)

Purely additive — two new source files + a test, **no existing file modified** beyond an import. No
existing code references the bank, so behavior is byte-identical until a host adopts it. Verified: 10
bank tests + full build green.

## 5. Honest layer-2 + roadmap

The pool is *available*, not auto-fed. Wiring the turn pipeline to ingest high-quality `ProcessTrace`
/ `LearningExportBundle` assets after each turn (and choosing the admission policy) is the host's
deliberate step. Follow-on: SQLite-backed persistence for very large pools; the WP15 trainer
consuming `exportManifest(...)`.
