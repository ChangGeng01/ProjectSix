# Qinao Review Methodology Lessons

A living record of what worked and what didn't across the deep-review
passes (chapter 67 / chapter 七十八.5 / future). Captures patterns
that repeat so the next reviewer doesn't re-discover them by trial.

**Status**: methodology document, not doctrine. Authored 2026-05-02
(M348) consolidating chapter 67 (M298-pre baseline) + chapter 78
(M298–M335 surface) experience. Gets updated whenever a new deep-review
pass surfaces a new pattern.

---

## Lesson 1 — Agent surface-scan false-positive rate

### What happened

| Pass | Surface | Findings | Real bugs | False-positive rate |
|---|---|---|---|---|
| Chapter 67 | pre-M298 codebase | 25 | 6 | 76% |
| Chapter 78.5 | M298–M335 surface | 9 | 1 | 89% |

The chapter 78.5 rate was higher because the surface was mostly
schema-additive + sample-host demos — territory where structural
review misses semantic bugs less often than in actor + verdict-engine
territory (which chapter 67 covered).

### What we learned

1. **Agent code-review on schema-additive surface has poor signal-
   to-noise.** Default to ≥75% false-positive rate; budget for it.
2. **Human grep cross-check is mandatory.** Every agent finding must
   be grep-verified against the actual file before any fix lands.
   Agents hallucinate plausible-sounding bugs (e.g., "actor lock not
   held across calls" when actor isolation already serializes).
3. **Real bugs cluster around novelty.** The one real bug in M298–M335
   was the `hashValue` non-determinism — a function that had been in
   the codebase before but became load-bearing for M306 multi-session
   continuity. Look for old code newly load-bearing in new contexts.
4. **Top-N file selection beats blanket sweep.** Chapter 78.5 picked
   the top-10 files by LOC × concurrency × novelty heuristic and got
   the same yield as a 30-file blanket sweep would have.

### Recommendations for next deep-review pass

- Run agent on top-10 (not top-30) bug-prone files only.
- For each agent finding, write the grep verification command first;
  if you can't formulate a concrete grep, the finding is too vague.
- Look for "old code, new load-bearing role" patterns specifically.
- Skip blanket schema-additive surfaces; focus on behaviour-changing
  PRs.
- Budget 1 hour per agent finding for grep verification + fix
  evaluation. With 10 findings, that's 1 day of review work.

---

## Lesson 2 — Framing axis vs capability axis distinction

### What happened

Manifesto v5 ("Performance is Doctrine") was authored as a *framing
axis*, not a *capability axis*. v1–v4 each introduced new typed
capabilities (invariants / 14 layers / typed motherboard / agent
fabric); v5 introduced no new capability — it added a *rule for
authoring future axes* (every doctrine claim must be typed +
measurable + regression-gated).

In conversation after authoring v5, I self-critiqued this as
"v5 manifesto is framing not capability". The framing was correct
per design, but the critique exposed a real gap: framing axes do
not move the substrate forward by themselves. They move it forward
*indirectly* by making future capability axes authoring-ready or
authoring-blocked.

### What we learned

1. **Framing axes are legitimate doctrine** — but they must
   demonstrate their value by being *applied* to subsequent
   authoring decisions. v5's value was demonstrated by M341 / M342 /
   M343 unblocking v6 / v7 / v1 #3 strengthening respectively.
2. **A framing axis has a half-life.** If v5 had not led to M341–
   M343 within the same session, it would have remained "v5
   exists" without "v5 has shaped the codebase". Framing axes
   must be paid off promptly.
3. **The triple itself (typed pin → measurement → regression gate)
   is a reusable pattern** — not just for v5/v6/v7. Future axes
   in any domain (memory pressure / sync convergence / risk
   uplift / persona projection) can apply the same triple.
4. **v5 §4 prohibitions are testable** — a future PR that tries
   to author a doctrine without one of the three legs can be
   blocked with a doctrine-review checklist:
   - "What's the typed pin?"
   - "What's the measurement primitive?"
   - "What's the regression gate that fires when the claim breaks?"

### Recommendations for next axis authoring

- **Framing axes only when justified.** If the proposed doctrine
  doesn't clarify how *future* axes get authored, it's probably
  better as a methodology document (like this one) than a manifesto.
- **Pay off framing axes within one batch.** v5 paid off via
  M341–M343 in the same session. If you author a framing axis
  and don't immediately ship the typed primitives that exercise
  it, the axis decays.
- **Include "what does NOT count as this axis" in every authoring**
  — both framing and capability axes. v6 §4, v7 §4, v5 §4 each
  list explicit exclusions. Excluding wrong things is half the
  doctrine work.

---

## Lesson 3 — Stale-claim correction pattern

### What happened

Multiple chapter-end "all close" claims have turned out to be stale:
- Chapter 76.4 "surgical scope all close" was matched by a chronic
  boundary-check failure (chapter 七十七).
- Chapter 78.10 "external bottlenecks unchanged" was an informal
  label upgraded to typed backlog by M339.
- Chapter 78.11 "v6/v7 candidates parked due to missing leg" was
  unblocked by M341–M343 within the same session.

### What we learned

1. **"All close" claims should always carry a "what's not closed"
   table.** Chapter 79.10/79.11 model is the right shape: explicit
   table of "what we said vs what we ship".
2. **Chapter wraps are a good time for stale-claim sweeps.** Run a
   quick `grep "all close\|fully shipped\|完整闭环"` against the
   honesty board and verify each is still accurate after the new
   batch.
3. **Self-critique is a doctrine-quality signal.** Chapter 78
   ended with "三分保留" (3 reservations); each reservation was
   then closed by M340–M341 in chapter 79. This pattern works:
   author critically, ship the fix in the next batch.

### Recommendations for next chapter

- Always include a stale-claim correction subsection (`X.N stale-
  claim correction`) when the new batch invalidates a prior chapter
  claim.
- After chapter authoring, grep the honesty board for "全 close"
  / "完整" / "all shipped" patterns and verify each.
- Self-critique at chapter end is fine; don't paper over the
  reservations. The next chapter's job is to close them.

---

## Lesson 4 — Repository-side preparation vs external bottleneck

### What happened

Pre-M339 the items "L4 training" / "authoritative curriculum" /
"W1-W5" were tracked as informal "外部资源" labels. The labels
implicitly said "we can't fix this with code" but didn't *enforce*
that distinction. M339 promoted them to typed entries with three
explicit sections each:

1. What is missing
2. Verifiable unblock condition (not "more work")
3. Repository-side preparation (fair game)

The third section is the trap door — it lists what the substrate
*can* do to make the eventual unblock cheaper. The trap is that
"prep" can masquerade as "progress on the bottleneck itself" if
not labeled.

### What we learned

1. **External bottlenecks need verifiable unblock conditions.**
   "More work" is not a condition; "$N compute available" or
   "expert Y signs through attestation Z" is.
2. **Repository-side preparation must be labeled as such.** Even
   useful prep work does not move the unblock indicator until the
   external resource arrives.
3. **The recording rules at the bottom of `EXTERNAL_BOTTLENECKS_BACKLOG`
   are doctrine-strength.** They prevent items from drifting
   between "external" and "in-repo" classifications during the
   life of the project.

### Recommendations

- Whenever a new bottleneck item is added, write its unblock
  condition first; if you can't, the item is too vague.
- Audit the prep section — if it starts to look like a checklist
  for "we did all the prep, now we're done", relabel: prep is
  always preparation, never completion.

---

## Lesson 5 — Authoring v6/v7+ requires triple-completion

### What happened

v5 explicitly said: "you cannot author v6+ without typed pin +
measurement + regression gate". M341–M343 supplied the missing
legs for three parked candidates; M345 (v6) and M346 (v7) then
authored the substantive doctrines.

The order matters: triple-completion *first*, authoring *second*.
Authoring without triple-completion would be doctrine creep.

### What we learned

1. **Triple-completion is the gate.** No exceptions, even for
   "obviously true" claims. v6's "lifecycle is structurally pinned"
   sounds obvious; M341 made it falsifiable.
2. **Per-candidate triple completion is the surgical unit.** Each
   v6/v7+ candidate gets its own triple-completion milestone (M341
   for v6, M342 for v7, M343 for v1 strengthening). Bundling
   would obscure which candidate is ready.
3. **Authoring is a discrete decision separate from triple-completion.**
   M341–M343 made the candidates authoring-ready; M345–M347 made
   the authoring decisions. The two-step rhythm prevents
   accidental authoring.

### Recommendations

- For every parked candidate in a manifesto's "candidates" appendix,
  the next batch's surgical work should aim at filling the missing
  triple leg.
- Resist authoring until the triple is actually complete. v5's
  authoring rule is the doctrine; ignoring it weakens v5 itself.

---

## Cross-references

- Chapter 67 (deep review pre-M298 baseline)
- Chapter 七十八.5 (M298–M335 deep review)
- `docs/QINAO_M298_TO_M335_DEEP_REVIEW_2026-05-02.md` (full review report)
- `docs/QINAO_MANIFESTO_V5_DOCTRINE.md` (framing axis + triple)
- `docs/QINAO_MANIFESTO_V6_DOCTRINE.md` (capability axis using triple)
- `docs/QINAO_MANIFESTO_V7_DOCTRINE.md` (capability axis using triple)
- `docs/QINAO_EXTERNAL_BOTTLENECKS_BACKLOG.md` (typed external items)

---

*Authored 2026-05-02 as M348 — direction "剩下的 一次性 解决" of the
内部加强完善 batch closure. Lives as methodology document (not
manifesto axis) per Lesson 2's "framing axes only when justified"
recommendation.*
