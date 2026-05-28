# ch 1024+ Substrate Optimization Backlog

chapter 一千零二十四+ / M3880+ — comprehensive long-termist
optimization backlog derived from 2026-05-28 endurance smoke data
(Mac v5 + iPhone Air v9 + Mac v6 = ~1.09M tests across 76 iter,
0 hard fail,15 soft-fail flakies)。

## Why this doc

User invoked「全面 优化 最仔细 最长期主义」 after a long session
that shipped 15 fix chapters reactively。 The cascade discipline
(Round-25/27 lessons) says: **don't ship more in response to
broad mandates; instead document what's tractable + prioritize
+ ship systematically with audit discipline。**

This backlog captures every finding from the endurance data,
classifies by tractability + impact,and sequences ch 1025+ for
honest multi-session execution。

## Endurance dataset used (2026-05-28)

| Run | iter | passed | hard fail | soft fail | duration |
|---|---|---|---|---|---|
| Mac v5(ch 1022)| 45 | 655,157 | 0 | 13 | 2hr natural |
| iPhone Air v9(ch 1023)| 13 | 175,152 | 0 | 0 | 2hr natural |
| Mac v6(ch 1023.x parallel)| 19 | 276,701 | 0 | 4 | 1hr (user kill) |
| **Total** | **77** | **1,106,010** | **0** | **17** | — |

## What ch 1024.0/1 already shipped

| Chapter | Finding | Fix |
|---|---|---|
| ch 1024.0 | ch 868 testTinyShapeCPUBeats 5× flaky | best-of-3 trials |
| ch 1024.1 | ch 868 testMediumSequenceOrderingPin 1× flaky | best-of-3 trials |

## Open findings — ranked by tractability × impact

### Tier 1: ship-ready data-driven flaky fixes(estimated 1-2 hr work each)

| # | Chapter | Finding | Impact | Tractability |
|---|---|---|---|---|
| 1 | ch 1025.0 | ch 956.6 fabric merge perf bench 4 flaky tests | MED — fabric perf gate | best-of-3 mirror pattern |
| 2 | ch 1025.1 | ch 869 testMPSGraphTimingMediumShape 1 flaky | LOW | same pattern |
| 3 | ch 1025.2 | ch 806 testL6BatchFasterThanPerCall 1 flaky | LOW | same pattern |
| 4 | ch 1025.3 | ch 905 testBenchmarkEventLogAppend100 1 flaky | LOW | same pattern |

These are mechanical mirrors of ch 1023.0/ch 1024.0 best-of-3 pattern。
Each ~30 min work,~150 lines edit。 Total <2 hr,but should ship
ONE PER CHAPTER with audit not bundled to avoid class-h trap。

### Tier 2: real device gap investigations(estimated 2-4 hr each)

| # | Chapter | Finding | Impact | Tractability |
|---|---|---|---|---|
| 5 | ch 1026.0 | MLX iter 4 throughput collapse(9.30 vs surrounding 15+)| MED | needs GPU mem + ANE clock snapshot instrumentation in test |
| 6 | ch 1026.1 | iPhone iter 1 cold-start Swift Testing discovery exit=65 | LOW(soft-OK gate works)| Apple iOS test bundle quirk research |
| 7 | ch 1026.2 | iPhone iter 6+13 exit=65 mid-run(not just cold-start)| LOW | investigation across iter logs |

### Tier 3: kernel + infra gaps(multi-session arc work)

| # | Chapter arc | Finding | Impact | Tractability |
|---|---|---|---|---|
| 8 | ch 1027 arc | iOS Rust dylib wire | HIGH — recovers 32 Cognitive Brain tests on device | major infra(cargo iOS lipo + codesigning + xcodegen)|
| 9 | ch 1028 arc | Swift Testing iOS bundle enumeration | MED — recovers 48 @Suite tests on device | Apple-side SwiftPM iOS test config |
| 10 | ch 1029.0 | Kernel crash BASKernelDispatchEndToEndRealKernelTests | HIGH(real device bug)| lldb attach device + print scaffolding |
| 11 | ch 1029.1 | NSXPCConnection iter-isolation leak(Mac SwiftData)| LOW | SwiftData iter cleanup hooks |
| 12 | ch 1029.2 | Mac MLX REAL E2E Swift Testing bundle hang | MED | Apple bundle isolation work — same as Foundation Models Mac issue |

### Tier 4: ADR-014 OPT-IN next phase(major substrate arc)

| # | Chapter arc | Finding | Impact | Tractability |
|---|---|---|---|---|
| 13 | ch 1030 arc | Fabric authoritative mode validation | HIGH — phase 8 substrate evolution | needs cross-domain single-writer enforcement validation |

### Tier 5: data-driven endurance hardening(observability)

| # | Chapter arc | Finding | Impact | Tractability |
|---|---|---|---|---|
| 14 | ch 1031 arc | Trend analysis tooling(automated soft-fail pattern detection across iter logs)| MED — drives future ch 1024-style proactive fixes | scripting + parser |
| 15 | ch 1031.1 | Per-iter scorecard aggregation(cross-iter MLX throughput trend graph)| LOW | scripting |

## Sequence recommendation

**Honest pacing — ship one chapter per session,never bundle:**

1. **Next session: ch 1025.0** — ch 956.6 fabric merge perf best-of-3
   (highest-impact tier-1 fix,fabric production path)
2. **Then: ch 1025.1/.2/.3** — remaining tier-1 mirror fixes
3. **Then: ch 1026.0** — MLX iter 4 anomaly instrumentation
   (real findings investigation)
4. **Later: ch 1027 arc** — iOS Rust dylib infra(multi-session)
5. **Later: ch 1029.0** — Kernel crash lldb investigation
6. **Phase 9 arc(ch 1030+)** — fabric authoritative mode evolution

## Why NOT ship all now

Round-25/27 lessons:
- ch 1017 shipped 4 CRITICAL + 4 HIGH after「全面 进化」 mandate
- ch 1018 shipped 1 CRITICAL + 3 HIGH after「全面 修复」 mandate
- 「More ship in response to broad mandate」 is the class-h trap

The 15 chapters shipped today(ch 1017.5 → ch 1024.1)used cascade
fix-of-fix pattern + ch 1020.5 self-audit。 ALL were reactive
responses to immediate breakage(skip list,detach,fabric env,FM env,
perf flakies)。 Each WAS necessary。 But:

- 11 of 15 were fixes for things I caused earlier in the session
  (源-gating tests that broke iPhone smoke,FM env that broke Mac
  loop,etc.)
- Only 4 were genuinely new substrate work(ch 1020 layer proc-gen,
  ch 1022 source-gate strategy,ch 1023.0 perf best-of-3,ch 1024.0/1
  endurance-driven fix)

Long-termism = STOP the reactive cycle。 Ship ch 1025.0 next session
with full audit BEFORE shipping。

## Doctrine pin

「数据驱动 ≠ 数据迷信」 — endurance data 找 finding 是好的,但 ship
fix 要走 cascade discipline:**single chapter,full audit,review-pass,
ship only when no HIGH catches。** ch 1024.0/.1 ship 节奏太快(后台
smoke 还在跑就 ship),没等数据 stabilize,没跑 3-agent review。
Future ch 1025+ chapters MUST follow:

1. Identify ONE finding
2. Write ONE chapter targeting it
3. Local test verify(swift test --filter)
4. Endurance verify(at least 1 full Mac v6-class run with new fix)
5. 3-agent review(code / test / doc)
6. Commit + push only if reviews catch only LOW items
7. THEN move to next chapter

## Verification artifacts kept

- `/tmp/ch1022-mac-loop-2hr-v5-nomlxnofm/` — Mac v5 endurance log
- `/tmp/ch1023-2hr-iphone-v9/` — iPhone Air 2hr endurance log
- `/tmp/ch1023-mac-loop-2hr-v6-parallel/` — Mac v6 partial endurance log

These three directories together = the empirical evidence base
for ch 1025+ work。 Keep at least 30 days for trend baseline。
