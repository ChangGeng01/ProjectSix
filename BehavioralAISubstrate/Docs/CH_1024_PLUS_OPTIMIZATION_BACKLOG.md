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

chapter 一千零二十四.5 / M3885 — 全面 audit HIGH-1 fix:pre-fix
this table claimed「1.09M tests / 0 hard fail」 as headline。
Audit caught:Mac iter logs have ZERO `✔ Test` (Swift Testing)
completion lines — Swift Testing tests crashed via SIGBUS
(`swiftpm-testing-helper exited with signal code 10`) every Mac
iter,but the crash output went to `detach-bootstrap.log` instead
of `iter-NNN.log` because of `swift test 2>&1 > "$LOG_FILE"`
redirect-order bug (CRITICAL-1 fixed in this chapter)。

Honest XCTest-only count (Mac Swift Testing all crashed):

| Run | XCTest passed | Swift Testing | iter | hard fail | soft fail | duration |
|---|---|---|---|---|---|---|
| Mac v5(ch 1022)| 655,157 | **CRASH SIGBUS each iter** | 45 | 0 | 13 | 2hr natural |
| iPhone Air v9(ch 1023)| 175,152 | ✓ ran(157 ✔ Test/iter)| 13 | 0 | 0 | 2hr natural |
| Mac v6(ch 1023.x parallel)| 276,701 | **CRASH SIGBUS each iter** | 20 | 0 | 4 | 1hr user-killed |
| **Total XCTest** | **1,107,010** | — | **78** | **0** | **17** | — |

Real total when Mac Swift Testing SIGBUS is root-caused should
add ~150K-300K(Mac has ~330 `@Suite` struct tests via swift-testing
vs iPhone's ~165;Mac Swift Testing crashed 100% of iter)。

ch 1024.5 fixed the Mac loop redirect-order bug。 ch 1025.x+ will
investigate SIGBUS root cause once a clean iter log captures the
full stderr。 The「0 hard fail」 claim stays valid for XCTest portion
but SHOULD be qualified as「XCTest-only — Mac Swift Testing portion
deferred to ch 1025+ root-cause investigation」。

## What ch 1024.0/1 + ch 1025.4 + ch 1025.5 + ch 1025.5.0 + ch 1025.5.5 + ch 1025.7 already shipped

| Chapter | Finding | Fix |
|---|---|---|
| ch 1024.0 | ch 868 testTinyShapeCPUBeats 5× flaky | best-of-3 trials |
| ch 1024.1 | ch 868 testMediumSequenceOrderingPin 1× flaky | best-of-3 trials |
| **ch 1025.4 / M3899** | **ch 1025 v4 killed by competing xcodebuild — XCTest architecture can't survive concurrent xcodebuild sessions on one Mac** | **In-app endurance entry: `BASEnduranceAppRunner.swift` (480 lines) + `BAS_ENDURANCE_AUTOSTART=1` env var read by App init + os.Logger emit for idevicesyslog visibility + Documents/ log file dual-write + UIApplication.isIdleTimerDisabled。 Launch via `xcrun devicectl device process launch -e '{"BAS_ENDURANCE_AUTOSTART":"1",...}' com.changgeng.basdevicetest` — Mac side can disconnect entirely without affecting the iPhone-side run。 Verified 02:13 AEST May 29: MLX load 2.9s,iter 1 prompt 1 tokens=1208 tok_per_s=32.28,full ch1025 stream visible via `idevicesyslog -u <UDID> \| grep ch1025`。 Closes Tier 3 entry #16 conceptually (script-level lockout no longer needed for in-app mode — but xcodebuild test mode still vulnerable so #16 remains for that path)。** |
| **ch 1025.5.0 / M3899** | **Substrate adapter `.mlmodelc` resource-lookup gap discovered while shipping ch 1025.5** — `BASContextClassifierMLAdapter.init()` previously only looked for raw `.mlmodel` via `Bundle.module.url(forResource:"BASContextClassifier", withExtension:"mlmodel")`。 SPM `swift test` ships raw `.mlmodel` per Resources rule,but Xcode iOS app builds pre-compile to `.mlmodelc` AND strip the raw source。 Production-path bug:any iOS app using `BASCognitiveBrain.makeWithDefaults()` would throw `modelResourceMissing` because the raw .mlmodel was stripped。 Audit HIGH-2(architecture)flagged this as warranting a sibling chapter rather than co-shipping in ch 1025.5。 Documented separately here for clean commit-history attribution。 | `Sources/BASRuntimeCore/BASContextClassifierMLAdapter.swift:248-293` — dual-lookup path: prefer pre-compiled `.mlmodelc`(Xcode iOS app bundle path),fall back to raw `.mlmodel` + runtime compile via `MLModel.compileModel`(SPM `swift test` path)。 Both branches exhaustive within init,no shared mutable state,Mac swift test unaffected。 Verified 02:39 AEST May 29:Brain.makeWithDefaults() load_ms=14 in app process,brain.process() emits taskType+riskLevel+candidateCount per prompt。 |
| **ch 1025.5 / M3899** | **「fabric 真参与」 — endurance loop was MLX-only(`adapter.draft()` directly,bypassing host pipeline + fabric)** | **`BASEnduranceAppRunner.swift` — each prompt now invokes `brain.process(prompt)` BEFORE `adapter.draft(request)`。 brain.process exercises L1-L14 substrate classifier + verdict-ref cascade(context → decompose → memory → loop → triSelf → risk → action render → evolution synthesis)。 Verified: different prompts produce different taskType(highPressure / chat / manipulationRisk),different riskLevel(low / medium / high),different candidate counts(1-3)— substrate is doing intelligent work,not no-op。 Brain overhead: ~20ms cold,2-12ms warm = <0.1% of MLX per-prompt time(MLX ~30-90s)。 **Full `BASAgentFabricHostPipeline.runTurn()` integration deferred to ch 1025.6** — requires substrate-side `BASAgentFabricHostPipeline.makeMinimalForEndurance(brain:adapter:)` factory that doesn't currently exist (app target lacks zero-config fabric assembly entry,needs coordinator + roster + state-graph build ~200 LOC)。** |
| **ch 1025.5.5 / M3899** | **3-agent N-pass audit catch on ch 1025.5: HIGH-1(UI honesty), HIGH-2(sibling-chapter discipline), MED-2(conf=0.00 misleading)** | (1) **HIGH-1 UI honesty fix** — runner now emits `🪧 ch1025 fabric_activation=bypassed iter=N prompt=M reason=no_pipeline_in_runner defer_to=ch_1025.6` per prompt so the syslog truthfully reflects that fabric.runTurn() does NOT fire(even though UI badge shows "Fabric: enabled (all)" because env var is set)。 (2) **HIGH-2 sibling chapter discipline** — substrate adapter fix promoted to ch 1025.5.0(see row above);BACKLOG now lists them as 3 distinct shipped sub-chapters。 (3) **MED-2 conf=n/a fix** — brain confidence band now renders `conf=n/a` when nil instead of `conf=0.00`(BASMLContextService.swift never sets confidenceBand → always nil in brain.process path → previously implied broken classifier)。 (4) **MED runner header stale** — fixed,header now lists all three chapters(1025.4 + 1025.5 + 1025.5.5)。 Code review verdict: SHIP(no CRITICAL/HIGH from code path itself)。 |
| **ch 1025.7 / M3899** | **User mandate「最最 严苛 全面 — 所有 组件 数据 都要记录」**。 ch 1025.5 only logged 4 fields from BASEBrainTurnResult(task / conf / risk / candidates count)。 30+ fields available were unsurfaced。 | Added `emitBrainDetail(turnResult:iter:prompt:)` helper that emits 8 sub-category log lines per prompt: `ctx`(L6 full signal panel — emotionalLoad / timePressure / ambiguityScore / consequenceLevel / manipulationHints.count / sceneType / hostRelevance),`decompose`(L7 — facts/goals/emotions/unknowns/contradictions/pressureSignals/manipulationSignals/factShards/claimShards counts),`risk`(L11 scalars — totalRisk/uncertainty/irreversibility/manipulationStrength/gsiScore/factors/recommendedMode/stackedModes),`permit`(L11 — mode/stackedModes/reasonCodes/allowed/blocked domains/toolScope/memoryScope/requireMirror),`mem`(L8 — atoms/tags/conflicts),`render`(L12 — headline_len/body_len/alts/explanationCodes — body is rule-template not MLX tokens),`triself`(L10 — per-candidate id/ego/super/merged/veto preview),`candidates`(L9 — per-path benefit/cost/reversibility/confidence),`host_gate`(L13 — value/sovereignVerdict_present/warrants/commit_tokens/update_tickets)。 Plus per-MLX: `mlx-detail` with sessionCount + currentCapacity from adapter。 Plus one-time boot: `📊 ch1025 inventory exercised=... nyi=...` explicit coverage manifest so future operators reading syslog know exactly what's tested。 Verified 03:06 AEST May 29: PID 950 launch,9 detail lines emitted in first 30s,`sovereign_present=true` confirms L14 actually fires per turn,`scene=highPressureConflict` confirms L6 classifier actually classifies(not just returns default)。 Pure additive logging,no path change,LOW risk。 **✅ COMPLETED 10-HOUR RUN(03:06→13:10 AEST May 29):100/100 iters,247,133 tokens,0 hard fail,0 leak(net RSS −1461 MB),L14 sovereign 300/300=100%,0 competing-xcodebuild kills。 Full analysis → `Docs/CH_1025_7_ENDURANCE_FINAL_REPORT.md`。 Archive → `/Users/changgeng/ch1025-endurance-archives/`(912K extracted from 4.6GB raw)。 Key thermal finding:iPhone Air recovers serious→nominal ONLY at cooldown ≥180s — direct ch 1026 thermal-policy design input。** |

## ch 1025 v4 internal-loop smoke — premature termination diagnosis(2026-05-29 added)

**Run**:`run-iphone-air-internal-loop-10hr.sh` v4 launched 01:16:50 AEST May 29,
xcodebuild PID 73350 detached via python3 fork+setsid;target iter=100 internal-loop。

**Outcome**:died at 01:38:35(~20m 44s in)during **iter 6/100 cooldown** with
bash-reported `exit=137`(SIGKILL)。 6 iters of clean trajectory captured before death:
~14,851 cumul tokens × 18 MLX inferences,RSS stable 2911-2912 MB(no leak),
thermal cycling nominal↔serious↔fair as designed,adaptive cooldown
60→60→90→90→90→180s working per schedule。

**Initial hypothesis**:iOS jetsam OOM kill(iter 6 `avail_mb=266` + thermal serious)。

**Diagnosis(user-elected option C — pull crash log + Mac unified log)**:

| Evidence source | Finding |
|---|---|
| `idevicecrashreport` from iPhone Air UDID 00008150-00163C6A3E38401C | NO JetsamEvent newer than 2026-05-12;most recent BASDeviceTestApp ips files from 04:xx UTC May 28(before this run);**no crash report generated for 01:38 UTC+10 = 15:38 UTC May 28** |
| Mac unified log `01:38:00-01:39:00` | 73350 `runningboardd: termination reported by proc_exit` at 01:38:35.251;**no `memorystatus` SIGKILL against 73350**;only SIGKILL log was launchd cleaning up 73350's own child KeychainService 73396 "during teardown of process-scoped services after host exited"(consequence,not cause)|
| Timeline reconstruction | 01:38:31 — competing xcodebuild **PID 79959** launched(target = simulator DA99B4D8,scheme ProjectEleven UITests);01:38:35.197 — 79959 disconnects SimLaunchHost(amfid rejected `ProjectElevenUITests-Runner: adhoc signed`);01:38:35.233 — 73350 disconnects(**36ms after 79959**);01:38:35.251 — 73350 proc_exit |

**Root cause**:**Xcode CoreDevice/testmanagerd does not allow two concurrent
xcodebuild test sessions on one Mac**,even when targeting different devices
(73350 → iPhone Air real device 9E9E3DEB,79959 → simulator DA99B4D8)。 The
competing xcodebuild start triggered test orchestration cleanup of the running
session → ch 1025 v4 was collateral damage of an unrelated ProjectEleven UITest
launch(likely user cmd-U in Xcode IDE or other script trigger)。

**What this is NOT**:not jetsam,not iPhone OOM,not Mac OOM,not thermal kill,
not memory leak。 The physical resource trajectory was healthy;the wrapper was killed
at the OS test-orchestration layer。

**Counter-evidence for jetsam hypothesis**(burnt down so future sessions don't
chase the wrong root cause):
- iPhone Air RSS held 2911-2912 MB constant across 6 iters(Δ < 1MB)
- iPhone available_mb 266 IS low but iOS jetsam normally generates a
  `JetsamEvent-*.ips` report;none was created
- Mac `runningboardd:jetsam` log entries during the death window were
  unrelated lmstudio process complaints,not BAS

**Captured data still useful for ch 1026 thermal-policy wire-in**:
- iter 1 cold-start 72s(2336 tokens)vs iter 2+ steady-state 90-140s
  (~2100-3200 tokens)— MLX model cache validated
- iter 4 prompt 3 lowest tok/s 13.36 vs iter 1 prompt 1 best 48.34
  = **3.6× thermal throttle observed at iPhone Air dim**
- adaptive cooldown schedule 60→60→90→90→90→180 confirmed working

## ch 1025.5 endurance coverage audit — what's actually tested vs what isn't(2026-05-29 added)

**Why this section**:user asked「所有 数值 例如 ane 多线程 mamba 神经网络 正常工作吗」 during ch 1025.5 run。 The naive answer "endurance is healthy" is misleading because endurance covers a NARROW slice of substrate components。 Future operators reading a successful 7-hour run should NOT infer that "all substrate works" — they should know exactly which components were exercised vs untested。

### ✓ ACTUALLY exercised in ch 1025.5 endurance(per-prompt path)

| Component | Mode | Frequency | Per-prompt evidence in syslog |
|---|---|---|---|
| **CoreML `BASContextClassifier`** | tiny 2-layer MLP ~18K params, 7-class softmax | every prompt | `task=<7-class>` in ch1025 brain log line |
| **MLX Gemma 4 E2B 4-bit transformer** | full LLM inference,GPU(Metal) | every prompt | `tokens=N latency_ms=M tok_per_s=X` in ch1025 mlx log line |
| **L1-L14 substrate cascade** | rule-based signal derivation through 9 BASML* services | every prompt | brain `latency_ms` + `risk=<low/medium/high>` + `candidates=<1-3>` |
| **L8 bounded LRU caches** | classifier cache(256)+ brain summary history(bounded) | passive | RSS stable 2871-2872 MB across iters → no leak |

### ✗ NOT exercised in ch 1025.5 endurance(architectural gaps)

| Component | Status | Where it lives | Why endurance doesn't touch it |
|---|---|---|---|
| **🔴 Mamba SSM(`runMambaScan`)** | bundled but never invoked | `Sources/BASMetalSubstrate/BASMambaSSMState.swift` + `BASMetalLinearAlgebraDispatchers.runMambaScan` + `BASBiomimeticTurnObserver.mambaInputs` | Mamba is biomimetic state-space probe path,parallel to standard transformer。 Neither `brain.process()` nor `adapter.draft()` invokes it。 0 mamba calls during the entire 7-hour run。 |
| **🔴 Apple Neural Engine direct invocation** | telemetry only | `BASMetalSubstrate/BASANEKernelEligibilityClassifier.swift` + `BASANELiveReader.swift` exist for ANE usage analysis but don't drive ANE | ANE only used indirectly via CoreML auto-select(iOS decides per-model)。 MLX framework is GPU-only(Metal),never ANE。 The 18K-param classifier may or may not actually use ANE depending on iOS scheduler — endurance doesn't probe which compute unit was selected。 |
| **🔴 Rust crates(rayon multi-threaded)** | not on iOS | `Cargo/bas-retrieval-ranker`,`bas-audit-aggregator`,`bas-red-team-bench` etc. | iOS dylib infra not yet built — verified no `.dylib` in app bundle。 Entire iOS app can't reach Rust crates。 **This is ch 1027 arc deferred work**(Tier 3 #8)。 Mac swift test exercises Rust;iOS endurance does not。 |
| **🟡 MPSGraph kernels(MatMul,Attention,RMSNorm,RotaryEmbedding,Conv,LayerNorm,Softmax)** | substrate has them,endurance bypasses | `Sources/BASMetalSubstrate/BASMPSGraph*Kernel.swift`(ch 870/871 wires) + `BASMetalLinearAlgebraDispatchers` | MLX framework calls Metal directly,not through substrate's MPSGraph layer。 The substrate-level kernel dispatcher infrastructure is untouched by ch 1025.5 endurance。 |
| **🟡 Substrate cascade parallelism** | single-threaded | `BASCognitiveBrain.process()` runs L1-L14 sequentially,no `TaskGroup` / `async let` | Cascade is BY DESIGN sequential per turn(later layers depend on earlier outputs)。 MLX internally multi-threaded for GPU dispatch,but substrate this layer is not parallel。 If user wants parallel-substrate test,that's a different chapter。 |
| **🟡 Multi-organ rotation** | 1 model only | substrate supports many organ adapters(`BASOrganAdapter` protocol with Foundation Models / MLX / Chat Completions / others) | ch 1025 endurance only invokes Gemma 4 E2B + 1 classifier。 No Foundation Models,no Chat Completions,no second MLX model,no organ-switching mid-run。 |

### Honest interpretation framework

When you see「ch 1025.5 7hr endurance complete,0 hard fail」 you should read:
- **Verified stable under sustained load**: MLX Gemma 4 E2B on iPhone Air GPU,L1-L14 rule cascade,L8 LRU caches,thermal-aware adaptive cooldown schedule,fabric env-var gate read (not run),idleTimer-disabled app-process model
- **NOT verified**: Mamba SSM kernel,direct ANE usage,Rust ranker concurrency,MPSGraph kernel pool,multi-organ switching,substrate parallelism,fabric runTurn() actual execution

Both are valid。 Don't conflate。

### Future arcs to widen coverage(speculative chapter numbering)

- **ch 1027 arc** — iOS Rust dylib wire(unlocks Rust + rayon on device) — see Tier 3 #8
- **ch 1028.x** — Mamba SSM endurance path(invoke `runMambaScan` per N iters in endurance loop)
- **ch 1029.x** — ANE saturation test(rotate 3-5 CoreML models per iter to force ANE scheduling)
- **ch 1030.x** — MPSGraph kernel diversity(rotate MatMul/Attention/RMSNorm/RoPE per iter)
- **ch 1031.x** — Multi-organ rotation(Gemma 4 E2B / Foundation Models / Chat Completions in same run)

These are NOT priority over the existing Tier 1-3 work — they're added here for transparency about substrate scope vs current endurance scope。

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
| 8 | ch 1027 arc | iOS Rust dylib wire | HIGH — recovers 32 Cognitive Brain tests on device | ✅ **DONE ch1027(2026-05-29)** — audit found already-built(ios-arm64 slice committed since ch707/M2191);`nm` confirms debug.dylib has all `bas_*` symbols(`T` defined,not `U`,no SPM dead-strip);on-device `BASRustVerifyProbe` VERDICT **all_ok=true**(0 audit mismatches incl bundle 24-crate count + 8/8 namespace ABI match + fnv1a64 real-compute `0x2f41f83720730719` ≠ offset basis)。 Was verify-only ~150 LOC single-session,NOT the multi-session infra this row assumed。 NOTE:proves Rust RUNTIME resolves + executes;the "32 Cognitive Brain tests" recovery ADDITIONALLY needs ch 1028 Swift-Testing iOS bundle enumeration to actually run them via xcodebuild test。|
| 9 | ch 1028 arc | Swift Testing iOS bundle enumeration | MED — recovers 48 @Suite tests on device | Apple-side SwiftPM iOS test config |
| 10 | ch 1029.0 | Kernel crash BASKernelDispatchEndToEndRealKernelTests | HIGH(real device bug)| lldb attach device + print scaffolding |
| 11 | ch 1029.1 | NSXPCConnection iter-isolation leak(Mac SwiftData)| LOW | SwiftData iter cleanup hooks |
| 12 | ch 1029.2 | Mac MLX REAL E2E Swift Testing bundle hang | MED | Apple bundle isolation work — same as Foundation Models Mac issue |
| 16 | ch 1032.0 | Smoke script lacks competing-xcodebuild lockout(ch 1025 v4 lost to ProjectEleven UITest launch — see「ch 1025 v4 premature termination」section above)| HIGH for endurance discipline — without this,any concurrent xcodebuild on the Mac silently kills the running smoke | `/tmp/ch1025.lock` PID file + pre-launch `pgrep -f "xcodebuild test"` abort + post-launch ping watchdog |
| 17 | ch 1025.6 | **Substrate API gap discovered via ch 1025.5 architecture audit:no public helper to assemble a `BASAgentFabricHostPipeline` from an app target without `@testable` imports**。 ch 1025.5 wanted to invoke `pipeline.runTurn()` per prompt(true fabric participation),but app target cannot construct the dependency chain(coordinator + fabric runtime + roster + state graph + 11 ML services)without `@testable import BASHostKit / BASMemory` — which the app target can't use。 Result:ch 1025.5 shipped brain.process()-only(substrate cascade)with `fabric_activation=bypassed` honesty marker。 | HIGH — unblocks app-target fabric integration generally,not just endurance。 Also relevant to any external SDK consumer wanting fabric semantics | Ship `BASAgentFabricHostPipeline.makeMinimalForEndurance(brain:adapter:sessionID:envOverride:)` public factory in `Sources/BASHostKit/BASAgentFabricHostPipeline.swift` that builds + returns a pipeline ready for `runTurn(prompt:)` callers,with minimal default coordinator + fabric runtime + roster + state graph。 Then update `BASEnduranceAppRunner` per-prompt path to call it。 Est ~150 LOC substrate + ~30 LOC runner integration |

### Tier 4: ADR-014 OPT-IN next phase(major substrate arc)

| # | Chapter arc | Finding | Impact | Tractability |
|---|---|---|---|---|
| 13 | ch 1030 arc | Fabric authoritative mode validation | HIGH — phase 8 substrate evolution | needs cross-domain single-writer enforcement validation |

### Tier 5: data-driven endurance hardening(observability)

| # | Chapter arc | Finding | Impact | Tractability |
|---|---|---|---|---|
| 14 | ch 1031 arc | Trend analysis tooling(automated soft-fail pattern detection across iter logs)| MED — drives future ch 1024-style proactive fixes | scripting + parser |
| 15 | ch 1031.1 | Per-iter scorecard aggregation(cross-iter MLX throughput trend graph)| LOW | scripting |
| 18 | ch 1028 arc | **Mamba SSM endurance invocation** — `BASMetalLinearAlgebraDispatchers.runMambaScan` exists in `Sources/BASMetalSubstrate/` but ch 1025 path never calls it。 endurance does not exercise the biomimetic state-space layer。 | MED — substrate has Mamba code,untested under sustained load | Add `runMambaScan(syntheticInputs)` call per N iters in endurance loop;log `BASMambaSSMScanOutputs` summary。 Est ~50 LOC runner + 0 substrate change(API already public)。 Run requires synthetic input shape build,~1 hr 实现 + smoke verify。 |
| 19 | ch 1029 arc | **ANE direct invocation / multi-CoreML rotation** — ch 1025 uses 1 CoreML model(BASContextClassifier 18K params)which MAY auto-select ANE(iOS decides per-call,not visible in log)。 No way to verify ANE actually engages,no saturation test。 | MED — ANE telemetry exists(`BASANELiveReader`,`BASANEKernelEligibilityClassifier`)but unused | (1) Wire `BASANELiveReader` snapshot into per-iter log(ANE utilization %)。 (2) Add second CoreML model(small task-type variant)to rotate across iters,forcing ANE scheduling pressure。 Est ~100 LOC + 1 new .mlmodel resource + ~2 hr。 |
| 20 | ch 1030 arc | **MPSGraph kernel rotation** — substrate has 5+ MPSGraph kernel wires(ch 870/871: MatMul / Attention / RMSNorm / RotaryEmbedding / LayerNorm)but MLX framework bypasses substrate's dispatcher,calling Metal directly。 Endurance never exercises substrate-side `BASMetalLinearAlgebraDispatchers` kernel pool。 | MED — substrate has the wires,untested in app context | ✅ **DONE ch1034(2026-05-29,renumbered from 1030)** — `BASMPSGraphProbe.swift`(independent boot probe,onAppear Task,serial → no MLX GPU contention)。 3 kernels with canonical builders verified on iPhone Air A19,VERDICT **3/3 all_ok=true**。 **MPSGraph executable cache amortization実証(cold→warm):matmul 9.3ms→0.2ms(45×),rmsnorm 5.7ms→0.3ms(17×),rope 65ms→0.16ms(413×)** — first build compiles the graph,repeats reuse it。 This is the substrate layer MLX never touches。 attention + layerNorm deferred(need hand-rolled rank-2 descriptors,no canonical builder)。 |
| 20.1 | ch 1034.1 | **FINDING(ch 1034 discovered):`BASCanonicalKernelInputBuilders.rotaryEmbedding` emits RANK-3 `[seq,heads,headDim]` but `BASMPSGraphRotaryEmbeddingKernel.evaluate` REQUIRES RANK-2 `[seq,headDim]`**(kernel validation line 205-207)。 The builder + kernel each have their own unit tests(`BASCanonicalKernelInputBuildersTests` + `BASMPSGraphRotaryEmbeddingKernelTests`)but were NEVER co-tested — ch 1034's probe is the first call site to feed builder→kernel,exposing the mismatch immediately(`shapeMismatch: "rotaryEmbedding expects rank-2 inputs"`)。 ch 1034 worked around it by hand-rolling the rank-2 input the kernel wants。 | MED — latent substrate integration gap;any caller using the canonical builder for the rotaryEmbedding kernel hits it。 matMul + rmsNorm builders DO match their kernels(verified 3/3)— only rotaryEmbedding is mismatched | Fix options:(a)change `BASCanonicalKernelInputBuilders.rotaryEmbedding` to emit rank-2(if kernel's rank-2 `[seq,headDim]` is the intended contract — likely,since heads fold into seq),OR(b)add a `rotaryEmbeddingRank2(...)` builder + deprecate the rank-3 one,OR(c)make the kernel accept rank-3 + internally reshape。 Add a builder→kernel integration test for ALL 5 kernels to catch sibling mismatches。 Est ~30 LOC + 1 integration test,~1-2 hr。 |
| 21 | ch 1031.x arc | **Multi-organ rotation** — endurance uses MLXOrganAdapter(Gemma 4 E2B)only。 Substrate supports Foundation Models / Chat Completions / external adapters via `BASOrganAdapter` protocol。 Endurance never switches organs mid-run。 | LOW — single-organ stability already validated;multi-organ adds breadth not depth | Per N iters,call an alternate `BASOrganAdapter` if available(Foundation Models on iOS 26+ or Chat Completions if API key set)。 Log organ provider + draft outputs。 Est ~150 LOC + 4-6 hr(needs FM model availability check + Chat Completions API key handling)。 |

## Pre-ship audit findings — ch 1027 / MPSGraph / ANE(2026-05-29)

After the 10-hour ch 1025.7 endurance completed,3 parallel read-only
audits摸排 the coverage-widening candidates BEFORE committing ship order
(user mandate「先 audit 不盲目 ship」)。 **All 3 overturned the BACKLOG's
original estimates。** This section is AUTHORITATIVE;Tier 3 #8 + Tier 5
#18-21 rows are kept for history but their estimates are SUPERSEDED here。

### Chapter-number collision fix

Coverage-widening entries(Tier 5 #18-21)reused chapter numbers already
claimed by Tier 3 #8-12 / Tier 4 #13 / Tier 5 #14-15。 Renumbered:

| Coverage-widening work | OLD(collided)| NEW |
|---|---|---|
| Mamba SSM endurance | ch 1028(=Swift Testing bundle #9)| **ch 1033** |
| MPSGraph kernel rotation | ch 1030(=Fabric authoritative #13)| **ch 1034** |
| ANE rescoped | ch 1029(=kernel crash #10)| **ch 1035** |
| Multi-organ rotation | ch 1031(=trend tooling #14)| **ch 1036** |

### Audit 1 — ch 1027 iOS Rust:ALREADY DONE(verify-only)

Tier 3 #8 said HIGH/multi-session/"major infra"。 **FALSE。** iOS arm64
Rust slice already built,git-committed,wired:
- `Vendor/bas-rust-binaries/BASRustMemoryTracker.xcframework/ios-arm64/libbas_memory_usage_tracker.a`(21.6 MB)committed,exports 250 `bas_` symbols(= macOS slice count)
- `scripts/build-rust-xcframework.sh` TARGETS already includes `aarch64-apple-ios` + `-sim`
- rayon/rusqlite cross-compile cleanly;no tokio/openssl/bindgen
- "no .dylib in bundle" was a MISDIAGNOSIS — ships as static `.a` linked into the app's own Mach-O(correct iOS pattern,no embedded-dylib codesigning)
- DeviceTestApp → BASRuntimeCore → transitively pulls XCFramework
- Infra shipped at ch 707 / M2191,not pending

**Revised:~0-50 LOC,2-5 hr,LOW risk,single session,verify-and-document。** Only unknown:SPM dead-strip of unreferenced static-archive symbols(`-force_load` mitigates;`force_link.rs` exists Rust-side)。

### Audit 2 — ch 1034 MPSGraph kernel rotation:LOW risk,straightforward

Tier 5 #20 conflated two layers。 `BASMetalLinearAlgebraDispatchers` is
raw-MSL(only MatMul + RMSNorm)— NOT the MPSGraph cache the chapter names。
The real ch 870/871 wires are 5 public actors in
`Sources/BASMetalSubstrate/BASBuiltinKernels/`(`BASMPSGraph{MatMul,
Attention,RMSNorm,RotaryEmbedding,LayerNorm}Kernel`),uniform
`evaluate(inputs:) async throws -> BASKernelOutputs`。
- Reuse template:`Tests/.../BASMPSGraphDispatchLatencyBenchmark.swift`
- Public factory `BASCanonicalKernelInputBuilders`(matMul/rmsNorm/rotaryEmbedding have builders;attention + layerNorm need ~15 LOC hand-rolled descriptors each)
- **GPU contention = LOW**:MPSGraph kernels share the singleton A19 MTLDevice with MLX but use own command queues — Metal's standard multi-queue model,no crash risk。 Contention is performance-only,sidestepped by SERIAL invocation in the existing sequential await loop(never concurrent with MLX draft)。
- @testable NOT required(BASHostKit already plain-imports BASMetalSubstrate);needs 1-line project.yml dep + xcodegen regen
- Warm-cache:pass shared `BASMPSGraphExecutableCache` or hoist kernels outside loop

**Revised:~180-230 LOC,3-5 hr,LOW risk,0 substrate source change。**

### Audit 3 — ch 1035 ANE utilization%:iOS sandbox DEAD-END

Tier 5 #19 promised "per-iter ANE utilization %"。 **Impossible on
non-jailbroken iOS。** ANE perf counters live behind private
`H11ANE`/`AppleNeuralEngine` IOKit,gated by private entitlements Apple
grants only to its own processes。 No public iOS API surfaces ANE busy-time。
- `BASANELiveReader` reads NOTHING live — only `MLComputeDevice.allComputeDevices` static enumeration + hardcoded heuristic constants
- `BASANEKernelEligibilityClassifier` is a static compile-time predictor,self-declares `consultedByExecutorInProduction=false`
- No `MLModelConfiguration` constructed → CoreML defaults `.all`,but 18K-param MLP so small the scheduler likely keeps it on CPU/GPU(dispatch overhead > compute)
- Only 1 real `.mlmodel`(two byte-identical copies);rotation needs net-new trained models

**Rescoped ch 1035 = "multi-CoreML rotation + `.cpuAndNeuralEngine` REQUEST logging(request,NOT confirmation)+ static BASANELiveReader snapshot"。 ANE utilization% = WONT-DO(iOS sandbox),same honesty pattern as `consultedByExecutorInProduction=false`。 Realistic:~150-190 LOC + 2-4 trained models + 6-8 hr,HIGH/partially-blocked。**

### Data-driven ship order(supersedes the generic Sequence list below)

1. **ch 1027**(Rust verify)— cheapest,LOW,single-session,pure verify-and-document。 Ship first。
2. **ch 1026**(thermal policy wire)— now has the 10hr ≥180s-recovery baseline as design input。 SCAFFOLD→WIRED,MED risk,ADR-014 OPT-IN default OFF,needs 5-axis perf at .nominal。
3. **ch 1034**(MPSGraph rotation)— LOW risk,template exists,serial-loop sidesteps GPU contention。
4. **ch 1033**(Mamba SSM)— confirm API first(`runMambaScan` lives in `BASMambaSSMState.swift`,NOT the dispatchers — Tier 5 #18 misattributed)。
5. **ch 1035**(ANE rescoped)— rotation + request-log only;utilization% DECLINE-WITH-TRIGGER(revisit if Apple exposes public ANE counters)。
6. **ch 1036**(multi-organ)— LOW priority,breadth not depth。

## ch 1025.8 bug hunt findings — 4-agent adversarial(2026-05-29)

User mandate「全面 寻找 bug 最最严苛」。 4 parallel read-only review agents
(concurrency/Sendable · substrate-impact · error/edge · correctness-silent-data)
swept this session's diff(99f56f66f..HEAD)。 **11 verified findings;substrate
PRODUCTION code(the `.mlmodelc` adapter change)audited CLEAN(byte-equal raw
path,no macOS regression)— every finding is in the DeviceTestApp probes/runner。**
HIGH-1 + HIGH-2 adversarially re-verified(token source confirmed chars/4;this
run's RSS trajectory confirmed step-down,not a hidden leak)。

### ✅ Fixed this batch(ch 1025.8,device-verified)

| # | Sev | Finding | Fix |
|---|---|---|---|
| C1 | **CRITICAL** | `for iter in 1...totalIters` ClosedRange traps(hard crash)when `BAS_INTERNAL_ITER_COUNT=0`/negative — no clamp | `max(1, …)` on totalIters + mlxPrompts。 Device-verified:launched with iters=0 → clamped to 1 → FINAL emitted,NO crash,app alive |
| C2 | HIGH | C1's trap skipped `closeLogFile()` + `isIdleTimerDisabled=false`(log leak + screen pinned) | Resolved by C1 clamp(loop no longer traps) |
| HIGH-1 | HIGH | `tokens`/`tok_per_s` were `(body.count+3)/4` char-estimates(`BASOrganDeterministicAdapter.estimateTokens`),mislabeled as real decode tokens — "247K tokens" headline was chars/4 | Renamed `est_tokens`/`est_tok_per_s`/`est_cumul_tokens`/`est_total_tokens`/`est_tokens_per_iter` across mlx line + scorecard + FINAL。 Device-verified `est_tokens=75 est_tok_per_s=49.69` |
| HIGH-3 | HIGH | per-prompt `rss_delta_mb` bracketed only `adapter.draft()`(mlxPreSnap taken AFTER brain.process + emitBrainDetail)→ excluded substrate-cascade alloc,mislabeled as total per-prompt | Renamed `mlx_rss_delta_mb`(scopes it MLX-draft-only)。 Device-verified |

### 🔧 Deferred to next batch(ch 1025.9 — verified real,fix designed,not yet applied)

Deferred to avoid a fix-of-fix bundle(cascade discipline)— all in DeviceTestApp,
none touch shipped substrate。

| # | Sev | Finding | Fix design |
|---|---|---|---|
| HIGH-2 | HIGH | `total_rss_growth_mb = last − first`(2-point endpoint)hides intra-run leaks — a peak@iter40 + low@iter100 reports negative "growth" while a real leak was reclaimed late。 This run was step-down(verified no real leak),but method is fragile for future runs | FINAL also compute `rss_max`,`rss_peak_vs_first`,linear regression slope over `iterRssAfter`;keep last−first but label it `endpoint_delta` |
| #4 | HIGH | `Task.detached { await self?.runEndurance() }` but `runEndurance` is `@MainActor`(method inheritance)→ the multi-hour loop is MainActor-pinned with 300s sleeps;intent ≠ behavior。 10hr run completed(await yields main frequently)so impact LOW,but the detached design is illusory | Make `runEndurance` nonisolated;keep @State writes inside the existing `MainActor.run` blocks(they already wrap status/log). Requires full re-review of every self.state access — moderate risk,LOW impact,hence batched separately |
| MED-1 | MED | percentile bias:`p50 = sorted[count/2]`(n=100 → index 50 = 51st = ~p51);`p99 = sorted[min(count-1, Int(count*0.99))]`(n=100 → index 99 = MAX,not p99)。 Tail consistently overstated | nearest-rank:`index = clamp(ceil(p*N)-1, 0, N-1)`。 p50→idx49,p99→idx98 for N=100 |
| MED-mono | MED | all latency/duration use wall-clock `Date().timeIntervalSince`;`monotonicNs` is captured in every snapshot but ONLY logged,never used for deltas → NTP step/DST on a 10hr run injects silent error into every latency + p50/p99/avg | Derive elapsed from `DispatchTime.now().uptimeNanoseconds` deltas(brainMs/mlxMs/iterMs/elapsedSec/totalSec/cognitiveBrainMs/brainLoadMs);keep `Date()` only for wall-clock timestamps。 Mechanical but multi-site |
| #5 | MED | SwiftUI `onAppear` can fire repeatedly(re-appear/backgrounding)→ `rustVerify` re-runs + MPSGraph Task re-spawns → two `BASMPSGraphProbe.run()` can overlap GPU dispatch。 `autostartIfEnabled` is guarded by `started`;the probes are not | Add a `probesRan` guard flag(like `started`)so ch 1027/1034 probes run once per process |
| L1 | LOW | `snapshot()` labels `info.virtual_size` as `footprint_mb` — virtual size ≠ phys_footprint。 10hr report's footprint column is mislabeled(virtual,which is huge ~404 GB-range, obviously not footprint) | Either relabel `vsize_mb`,or switch to `task_vm_info`'s `phys_footprint`(the real footprint metric) |
| LOW-2 | LOW | ch 1027 fnv `non_constant = probeHash != offsetBasis` is a WEAK proof of "real compute"(a stub returning any fixed non-basis constant passes)。 Verdict is still SOUND because `emptyOK`(known offset basis)+ 8/8 ABI gate it,but the per-line comment overstates what that one check proves | Assert `probeHash == <precomputed FNV-1a of "ch1027-rust-verify">`(known-good value),matching the rigor of the empty-input check |

### Honest note on the 10hr endurance report

`Docs/CH_1025_7_ENDURANCE_FINAL_REPORT.md` headline "247,133 tokens" is
chars/4 estimates(HIGH-1),and its p99 latencies are biased high by one rank
(MED-1)。 The "0 leak(net RSS −1461)" conclusion is CORRECT for that run
(trajectory verified step-down)but rests on the fragile endpoint method
(HIGH-2)。 The report should be annotated with these caveats when ch 1025.9
lands the fixes。

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

- `/tmp/ch1023-mac-loop-2hr-v5-nomlxnofm/` — Mac v5 endurance log
- `/tmp/ch1023-2hr-iphone-v9/` — iPhone Air 2hr endurance log
- `/tmp/ch1023-mac-loop-2hr-v6-parallel/` — Mac v6 partial endurance log

These three directories together = the empirical evidence base
for ch 1025+ work。 Keep at least 30 days for trend baseline。
