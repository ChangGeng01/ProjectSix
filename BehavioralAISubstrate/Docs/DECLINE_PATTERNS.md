# DECLINE Patterns — Substrate Migration Doctrine

Chapter 八百九十一 / M3145 (LOW-L1 + LOW-L2 fix from
doc-cohesion review): central doc explaining the two
DECLINE patterns the substrate has used 11+ times across
chapters 八百四十九 → 八百九十,plus the「string-FFI cost is
structural」 doctrine that chapters 八百八十一 + 八百九十 jointly
established。

---

## DECLINE-WITH-TRIGGER

**Definition**: a migration was considered + MEASURED + the
verdict was「Swift wins」 (or the cost of shipping exceeds the
measured benefit at current substrate workloads)。 The migration
DOES NOT ship。 The decline is pinned via an audit-test file with
3-4 trigger conditions that,if MEASURED,would re-open the
decision。

**Chapters using this pattern**:
- 八百四十九:Mamba flip-or-decline
- 八百五十六:Activation kernels DECLINED outright (per-pair
  work too small for rayon overhead)
- 八百五十七:Reduce/Conv kernels audit
- 八百八十一:Forget cascade decline (Swift Set 2-3× faster)
- 八百八十三:RAG MemoryService wiring decline (async/sync)
- 八百八十四:Gaps 1+4+5 decline (3 gaps × 3 triggers each)
- 八百九十:canonicalEncoding decline (string-FFI cost)

**Chapter 八百九十一.5 / M3146 HIGH fix from 18th-pass review**:
chapters 八百七十四 (RoPE) + 八百七十五 (RMSNorm) were previously
listed here AND in DECLINE-PENDING-CONSUMER below — incorrect
double-listing。 Both chapters SHIPPED the Rust/MPSGraph kernel
+ then declined wiring pending consumer pressure,so they
belong ONLY in DECLINE-PENDING-CONSUMER。 This was the
shoemaker's-children pattern recurring AGAIN — the doc
defining the patterns got the patterns wrong。 Chapter 891.5
fix removes the incorrect entries here。

**When to use**: the kernel WAS NOT written (or won't be
written),because measurement shows it can't win at any
plausible scale。 Trigger conditions specify the
workload/measurement that would re-open the decision。 Contrast
with DECLINE-PENDING-CONSUMER below where the kernel IS shipped
but waits for consumer pressure。

---

## DECLINE-PENDING-CONSUMER

**Definition**: the Rust kernel WAS shipped (crate-level + tests
+ byte-equality) but the Swift wiring is held back because NO
consumer in the substrate batches enough work to amortize the
FFI hop。 The Rust infrastructure is ready;the wiring waits for
a consumer to materialize。

**Chapters using this pattern**:
- 八百七十四:BASMPSGraphRotaryEmbedding (MPSGraph kernel exists,
  no consumer pressure to wire)
- 八百七十五:BASMPSGraphRMSNorm (MPSGraph kernel exists,no
  consumer pressure)
- 八百七十六:5 scaffolding `.metal` kernels + 2 unwired MPSGraph
  re-audited as still no consumer
- 八百八十五:Batched forget cascade (Rust rayon variant SHIPPED,
  awaits consumer batching ≥ 512 cascades per call)

**When to use**: measurement shows the kernel CAN win at scale,
but no consumer exercises that scale today。 Ship the Rust
infrastructure so it's ready when consumer pressure materializes;
don't wire the Swift bridge until the trigger fires。

---

## The「string-FFI cost is structural」 doctrine

**Established by**: chapter 八百八十一 (forget cascade decline) +
chapter 八百九十 (canonicalEncoding decline) — two independent
chapters declining different string-heavy migrations on the SAME
root cause。

**The rule**: before writing Rust for any Swift function that
operates on `[String]` or `[String:[String:...]]` inputs,
ESTIMATE the FFI ser cost from chapter 八百八十一's measurement
baseline。 If estimated FFI ser cost ≥ Swift's total measured
cost,DECLINE without writing the Rust kernel。 String FFI has
high fixed overhead (encode UTF-8 length-prefixed → Rust
re-decode + HashSet/HashMap rebuild + result string
materialization) that swift's native String/Set/Dictionary
don't pay。

**Heuristic** (chapter 八百九十一 honest correction:
EXTRAPOLATED from chapter 881 not directly measured — a future
chapter could run a per-string FFI bench to pin this):
- ~600 ns per round-trip string at typical 16-32 char keys
  (derived from chapter 881's 4.62 ms total for ~11K strings
  in the worst case;divided down + rounded conservatively)
- Multiply by 2N for nested-dict shapes (outer keys + inner
  keys + values)
- Compare to Swift's total measured cost

**Examples**:
- Forget cascade (chapter 881):Swift 1.5 μs/cascade。 Rust
  per-call work itself is faster but FFI ser of `[String]
  records` + `[String] targets` dominates。 DECLINE。
- canonicalEncoding (chapter 890):Swift 10-173 μs。 FFI ser
  estimated 15-230 μs — exceeds Swift total at every size。
  DECLINE。
- BadToneLinter (chapter 887-889):INPUTS to lint are
  `[String]` but the function returns Violations (small
  struct,low ser cost back)。 The big FFI ser cost
  going into Rust + low cost coming out + the Rust scanner
  doing real work (24 pattern matches per input × N inputs)
  → flip wins 7.4×。 FLIP。

**The pattern**: string-heavy INPUTS + complex per-row work in
Rust = potential flip。 String-heavy INPUTS + simple per-row
work (set/dict partition) = likely decline。

---

## Workflow

When considering a new Swift→Rust migration:

1. **Measure Swift baseline FIRST** (chapter 870 cycle-break
   discipline)。 No writing Rust until you have ns/call data。
2. **Estimate FFI cost** using the string-FFI doctrine above
   if inputs are string-heavy。
3. **Compare**: if FFI estimate > Swift total → DECLINE-WITH-
   TRIGGER (no Rust code written)。 If Swift total > FFI
   estimate + plausible Rust speedup → proceed to write Rust。
4. **If Rust wins measurably** → flip default (chapter 七百七十七
   precedent) + add LIVE perf assertion test (chapter 870
   discipline)。
5. **If Rust wins ONLY at scale beyond current consumers** →
   DECLINE-PENDING-CONSUMER (ship the Rust kernel + audit
   triggers + don't wire Swift bridge)。

This workflow is enforced by:
- Discovery agents recommending candidates
- Per-chapter baseline tests (skip-by-default after capture)
- N-pass review pattern catching missed measurements
- Tag-body cross-link integrity (LIVE measurement cited
  per flipped chapter)

---

## Cross-references

- chapter 870:cycle-break discipline (measure before flip)
- chapter 七百七十七:Product Rust flip precedent (33-67×)
- chapter 八百七十:MPSGraph attention flip precedent
- chapter 八百七十二:VectorIndex rayon flip precedent (3K rows
  breakeven)
- chapter 八百八十一 + 八百九十:string-FFI doctrine established
- chapter 八百九十一:this doctrine doc shipped (after 17-pass
  review caught the absence as LOW)
