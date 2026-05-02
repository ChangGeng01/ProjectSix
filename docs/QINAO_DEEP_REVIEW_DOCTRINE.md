# Deep-Review Doctrine

> Chapter 67 → 八十一 → 九十一 → 九十一.5 → 九十一.6 → 九十一.9 condensed pattern.

This document codifies the deep-review process learned across four
honesty-board chapters. It is the answer to chapter 九十一.5's pattern
lesson: "future deep-reviews should explicitly enumerate review-surface
limitations so the next reviewer (human or agent) knows what wasn't
covered."

---

## 0. When to run a deep-review

After every batch of ≥ 5 milestones touching the substrate's load-bearing
paths (verdict / permit / lifecycle / audit / sovereign). Not after every
commit; not before every release. The goal is to catch the class of bugs
existing tests miss — concurrency, doctrine violations, edge cases — at
the resolution where a focused review can find them.

If the prior batch was purely additive (schemas / docs / tests), skip the
deep-review and rely on the existing gates. Deep-reviews are expensive
(~3 hours of agent + human time) and shouldn't be ritual.

---

## 1. The 5-step pattern

### Step 1 — Sweep (gate-off + gate-on + bench)

Required:

- 3 back-to-back full-suite gate-off runs to detect flakes
- 1 AFM gate-on full run (env-gated tests) — cite
  `docs/QINAO_AFM_PLATFORM_POLICY_2026-05-02.md` for `Code 1026`
  failures; treat them as platform foreground-only policy not regression
- 1 bench-suite regression run vs committed baselines (5/5 within tolerance)
- 4 boundary checks (qinao import / sovereign redaction / SDK / substrate
  residuals)

Output: a sweep summary table that lists pass/fail/flake/skip counts per
suite + per env-gate. **Always include the AFM gate-on row even if it
fails — distinguish platform from substrate.**

### Step 2 — Top-N file ranking

Pick the N source files with highest bug-prone score:

```
score(file) = LOC × concurrency_density × novel_logic_density
```

`concurrency_density` = fraction of `async` / `actor` / `Task` /
`@Sendable` per LOC. `novel_logic_density` = fraction of new code (last
N commits) per LOC.

Typical N = 9-12. **Always include**:

- The most-recently modified main coordinator file (e.g.
  `EBrainRuntimeCoordinator.swift`)
- Every actor extension method file
- Every typed-pin-introducing file
- Every audit-emission seam file

**Always exclude**:

- Pure test files (they're already the regression-gate; reviewing the
  reviewers is meta-overhead unless adding new test infrastructure)
- Pure schema files with `BASSchemaVersioned` only conformance and 0
  callers (M120 parity gate covers them)

### Step 3 — Agent code review

Spawn an Explore agent with this prompt template:

```
Deep code review on the M{N1}-M{N2} batch. Goal: find real bugs (race
conditions, off-by-one, doctrine violations, edge cases the existing
tests miss). Pattern follows the chapter 67 / chapter 八十一 deep-review;
~75-78% false-positive rate is the historical baseline so be specific
and grounded.

Top-{N} files to review (ranked by bug-proneness):
1. <path1> — <focus area>
2. <path2> — <focus area>
...

For each file, check:
- <file-specific concern 1>
- <file-specific concern 2>
- ...

Report findings as a table:
| # | Severity | File | Line | Claim | Reproduction step |

Severity: CRITICAL / HIGH / MEDIUM / LOW. Be specific — vague observations
don't count. Expected ~3-7 findings per file.

Do NOT fix anything — just report. Word budget: 1500 words.
```

### Step 4 — Human-grep verification

For every agent finding:

1. Open the cited file at the cited line
2. Read 20 lines around it
3. Cross-grep any referenced types / constants / helpers
4. Apply doctrine knowledge (red lines / single commit mouth / etc.)
5. Render verdict: REAL BUG / FALSE POSITIVE / TESTABLE NIT / STYLE NIT

**Calibration**: chapter 67 / 八十一 / 九十一 / 九十一.5 came in at 76% /
75% / 78% / 71% false-positive respectively. If your pass shows < 50%
FP, you may have under-prompted the agent (it's too lenient). If > 90%
FP, the agent is hallucinating; re-prompt with sharper file-specific
concerns.

### Step 5 — Fix verified bugs + write report

For each REAL BUG / TESTABLE NIT:

1. Apply the smallest fix that closes the bug
2. Add a fix-pin test that fails pre-fix and passes post-fix
3. Cite the chapter + finding number in the fix's commit message

Then write the report markdown:

```
docs/QINAO_M{N1}_TO_M{N2}_DEEP_REVIEW_<DATE>.md
```

with sections: doctrine pin / methodology / findings table / fix details
/ AFM environmental note / sweep summary.

---

## 2. The "review surface limitations" requirement (chapter 九十一.5 lesson)

**Every deep-review report MUST include a "what wasn't reviewed" section.**

Pre-chapter-九十一.5 reports said "deep-review pass closed" without
enumerating which files were skipped. Chapter 九十一.5 found that 4 files
in the batch (M388 dominantAxisName / M389 / M395 / M400) had been
skipped; one of them had a real bug (M398.7 watcher-permit pattern).

The required section template:

```markdown
## Items deliberately not reviewed in this pass

| File or Topic | Why deferred |
|---|---|
| <file path> | <reason — e.g. "schema-only, M120 parity gate covers"> |
| <topic> | <reason — e.g. "platform-level dependency, not substrate"> |
```

This section is the next reviewer's surface map. It tells them where to
look that this pass didn't.

---

## 3. The "honest meta-reflection" pattern (chapter 九十一.5 lesson)

When the user pushes back on a deep-review wrap with "你别骗我" or
similar, do NOT defend the wrap. Re-review for at least these honest
gaps:

1. **Incomplete fix**: did the fix touch all sister code paths? (M398.2
   missed `startTrialWithForbiddenGate`; M398.5 corrected.)
2. **Quick-dismissal of test failures**: did you label something
   "environmental" without root-cause investigation? (Chapter 九十一
   labeled 38+1 AFM failures "environmental"; chapter 九十一.6
   investigated and found macOS 26 foreground-only policy.)
3. **Incomplete review surface**: which files in the batch were not in
   top-N? (Chapter 九十一.5 found 4 skipped files via re-spawn agent.)
4. **Quick-dismissal of agent findings**: did you mark anything FALSE
   POSITIVE without verification? (Chapter 九十一 dismissed agent #10
   M395 silent-failure; chapter 九十一.5 admitted partial-truth and
   shipped stderr routing.)

**Pattern lesson formalized**: the chapter 67 / 八十一 75-78% FP baseline
is comfortable. Don't let it become a hiding place.

---

## 3.5 The "empirical evidence vs logically sound" rule (chapter 九十一.9 lesson)

**Logically-sound claims are still over-claims if they don't have
empirical fire-trace.** Chapter 九十一.8 wrap claimed "14/14 AFM
files defensive-XCTSkip" with bulk-test green, but several of the
new code paths had never actually fired in real conditions — the
test was passing because AFM was cache-warm at the time. User
pushed back; chapter 九十一.9 ran a skip-counter breakdown that
empirically counted **22 platform-degraded XCTSkips fired across
11 of 16 files** including the structurally-tricky Concurrency
`Error?` capture pattern firing 2 times.

For every claim in a deep-review wrap, decide which category:

1. **Empirical evidence**: an actual test run produced the
   expected behavior (skip fired / assertion held / bug
   reproduced before fix and resolved after). Cite the run +
   line of evidence.
2. **Static evidence**: a grep / type-check / structural
   analysis confirms the property without running. Cite the
   grep pattern + count.
3. **Unit-test evidence**: a synthetic input was constructed
   to exercise the path (e.g. M400.5's helper unit tests with
   synthetic AFM error strings). Cite the test name.
4. **Logically sound**: the code path is structurally correct
   by inspection. **NOT sufficient** for a "close" claim.
   Either upgrade to one of (1)-(3) or mark as "deferred,
   pending fire-trace".

When the only available category is (4), the wrap text MUST say
"logically sound but empirically unverified" rather than
"verified" or "tested". This prevents the over-claim pattern
that needs a "你别骗我" pushback to surface.

Calibration: chapter 九十一.9's M400.4 skip-counter is the
canonical example. It broke down 40 skips into 4 categories
(platform-degraded 22 / env-gated 1 / defensive coverage 1 /
OS-version + adapter-specific 16) and explicitly noted "5 files
didn't fire today because their AFM calls succeeded — wraps in
place but untriggered". That's empirical evidence + explicit
limitation, both sides of §1's category line.

---

## 4. AFM gate-on test handling (chapter 九十一.6 lesson)

When tests fail with `ModelManagerError Code=1026` or
`FoundationModels.LanguageModelSession.GenerationError`, cite
`docs/QINAO_AFM_PLATFORM_POLICY_2026-05-02.md` and treat them as
platform foreground-only policy, NOT substrate regression. Repository-
scope hardening (defensive `XCTSkip` per test) is the response.

Do NOT report "AFM gate-on green" without noting the cache-warm
dependency. Runs that pass during cache-warm windows are not
reproducible.

---

## 5. The deep-review wrap template

Every deep-review chapter wrap should produce:

1. `docs/QINAO_M{N1}_TO_M{N2}_DEEP_REVIEW_<DATE>.md` — the report
2. Honesty-board chapter `九十一` (or successor) covering: trigger /
   sweep / agent findings / verifications / fixes / test impact / red-
   line matrix / **review-surface limitations** / one-line summary
3. Changelog entry combining all M{X.Y} fixes into one chronological
   row
4. Per-fix commit with BEFORE/AFTER code + finding citation +
   fix-pin test name

---

## 6. The honest-meta-reflection template

If user pushes back with "你别骗我" or equivalent, the response template is:

```markdown
不是完全满意。具体讲：

**真正修了的 N 件**: <list with milestone numbers>

**仍然不完全满意的 (诚实承认)**:
- <gap 1 with specific reason>
- <gap 2 with specific reason>
- ...

**Empirical state**: <test counts + boundary status + bench status>

**Commits pushed**: <hashes + descriptions>

**我现在到底满意吗**: <three-tier honest assessment>
- Surgical level: <yes/no + reason>
- Doctrine level: <yes/no + reason>
- Honest meta level: <yes/no + reason>

如果你想更深推: <specific follow-up milestones>
```

This template was authored in chapter 九十一.5. It is the user's
preferred shape — they pushed for it explicitly and validated it twice.

---

## 7. References

- Chapter 67 — first deep-review pass (M298-M335 surface, 25 findings →
  6 real bugs, 76% FP)
- Chapter 八十一 — second deep-review pass (M336-M350 surface)
- Chapter 九十一 — third deep-review pass (M384-M400 surface, 10 findings
  → 2 real bugs + 1 testable nit, 78% FP)
- Chapter 九十一.5 — honesty correction admitting chapter 九十一 wrap
  was premature; 4 additional gaps closed
- Chapter 九十一.6 — chapter that ships this doctrine doc
- Chapter 九十一.7 — `仓库外 gap 先不管 一次性 解决掉 仓内 gap`
  batch (M400.1 AFM helper + 5 patches; M400.2 manifesto v8)
- Chapter 九十一.8 — `continue` batch (M400.3 14/14 AFM
  defensive XCTSkip 真完成; 38 → 0 failures empirically)
- Chapter 九十一.9 — `一次性 解决 所有 不满意` empirical close
  (M400.4 skip-counter breakdown / M400.5 helper unit tests +
  static grep / M400.6 v9 candidate audit). Codified the
  empirical-evidence-vs-logically-sound rule §3.5 above.
- `docs/QINAO_AFM_PLATFORM_POLICY_2026-05-02.md` — AFM cold-cache
  investigation
- `docs/QINAO_M298_TO_M335_DEEP_REVIEW_2026-05-02.md` — chapter 67's
  report (the report template these docs follow)
- `docs/QINAO_M384_TO_M400_DEEP_REVIEW_2026-05-02.md` — chapter 九十一's
  report
