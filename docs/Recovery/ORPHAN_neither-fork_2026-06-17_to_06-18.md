# 孤儿段 — fork55 与 fork56 都没有、只在 3a011899(147MB)里的对话

**这是被 fork 塌缩遗漏的那一整段**,从原始 transcript `3a011899-…jsonl` 按 uuid 集合 (3a011899 − fork55 − fork56) 抽出。
- 范围:`2026-06-17T22:47:13Z` → `2026-06-18T13:18:00Z`(约 14.5 小时,紧接 fork55 的最后一句『好』之后)
- 内容:**操作者 16 条 + Claude 70 条**,逐轮全文,未截断
- 主题:06-17 RunPod 蒸馏日收尾 → Universal Assisted Generation / 通用 draft substrate / Universal Draft Layer 的诞生讨论

---

## 🟦 [2026-06-17 22:47:13] 操作者

查看 当前 已知 全面优化

## ⬜ [2026-06-17 22:47:54] Claude

You want the full map of every optimization we know about — implemented and pending. Let me pull the authoritative list straight from the committed code so it's accurate, not from memory:

## ⬜ [2026-06-17 22:48:54] Claude

这是当前**全部已知优化**的全景图,直接从已提交代码(`5802fdc42`)拉的权威清单,按"已落地 / 待落地 / 关键教训"分组:

## A. 已落地 — 核心阅读修复(add.50–54,本 session)
| 优化 | 杠杆/默认 | 作用 |
|---|---|---|
| **CF 反事实强制阅读** | `CF_FRAC=0`(opt-in) `CF_WARM=0.15` `CF_CE_W=0.5` | make-or-break:换金标事实→随机替身、纯CE无KD→损失只有读文档才能降 |
| **regime-aware verdict** | `CF_LIFT_MIN=0.30` `READING_SLOPE_MARGIN=0.02` | GO=学(E1降)**且**读;杀掉"只看E1降"的鹦鹉假阳性 |
| **genuine 错配对照** | `CF_GENUINE_MIN=0.20` | matched−mismatched,挡住"复制显眼新词"的伪阅读 |
| **recall 守卫** | `RECALL_LOW=0.15` `RECALL_DROP_MIN=0.05` | 对非记忆者(recall~0)放宽,免误杀 |
| **best-ckpt 按 cf_lift 选** | `CTX_W=0.5` | slope 对 CF 失明,改用因果信号选 ckpt |

## B. 已落地 — 训练/数据/数值/eval/运维
| 类 | 优化 |
|---|---|
| **省钱/提速** | 缓存 top-K logit-KD(`CACHE=1 KD_K=64`,老师只跑一次)· `KD_EXACT_TAIL`(精确top-K+尾,logZ已缓存=0成本)· 难度课程(`USE_SCHEDULER` `PACE_T_FRAC=0.5`)· **WSD 调度**(`DECAY=wsd`,救回 cosine 浪费的后半程≈1.7×有效LR)· **in-loop `MAX_SEC` 时墙**(add.55) |
| **数据/数值** | gold-survival 文档选取 · `TRAIN_SPLIT=train`(90k唯一)· `FP32_MASTER`+永远autocast(修了17% bf16-scan偏差)· `RAFT_NOGOLD_CE` |
| **诚实 eval** | 8门 claim_card · 冻结 eval 集 + `data_fp` 指纹 · E4 反事实 + 错配探针 |
| **运维** | 原子 ckpt/resume · 熔断器(3次零进展中止)· 程序化 GO/NO-GO verdict.json |

## C. 已识别 — 待落地(预算研究给的,**尚未做**)
1. **吞吐 rewrite ⭐最高杠杆** — batched scan + grad-checkpoint + torch.compile → **4-8×**(实测 MFU 只有 3-6%,余量巨大)。是长跑/放大模型的真正前提。
2. **≤10h Run-1 质量跑** — 配方定稿(24L不变、`DECAY=wsd`、`N_ROWS=45000`、`KD_EXACT_TAIL=1`、**`STEPS=120000 EVAL_EVERY=2500`** ←对抗审查修正,130k+eval会超10h)。**配方就绪,跑还没跑。**
3. **模型放大(≤2GB)** — 仅当 Run-1 出现容量平台才做(双门),否则别动(现在是 token 饿,不是容量墙)。
4. **warm-start** — 从 `~/cf_preserve/parrot/ckpt_best.pt` 热启,省~20k流畅度bootstrap。就绪。

## D. 关键教训 — 哪些"优化"其实**有害/失明**(反直觉)
- ❌ **`KD_ANSWER_W=2` 反而强化鹦鹉**(加倍蒸馏记忆答案)→ 用回 `1.0`。
- ❌ **轻量 levers(`KD_ANSWER_W`/`NOGOLD_CE`)治不了 reading** —— 信息论死结,必须上 CF。
- ❌ **un-swapped `Δ(E3−E1)` slope 对 CF 结构性失明**(E1/E3 同目标)→ 用 `counterfactual_lift`。
- ❌ **teacher-forced `swap_follow` 能被复制刷高** → 必须配 genuine 错配对照。
- ⚠️ **ckpt 必须写本地盘**(今天 volume 满了把网盘写卡死的教训)。

---
**一句话状态:** 阅读修复 + 度量机器 + 训练配方 **全部落地+提交+409测试绿**;真正没做的是 **(1) 吞吐rewrite** 和 **(2) 在干净 pod 上把 CF 跑出"会不会读"的答案** → 然后才是 ≤10h Run-1。

要不要我把 **C 区**(待落地)排个优先级 + 给每项一个"下次开工"的具体命令/任务清单?

## 🟦 [2026-06-17 22:49:16] 操作者

你看看 已有结果 做 相应 优化

## 🟦 [2026-06-17 22:49:18] 操作者

[Request interrupted by user]

## 🟦 [2026-06-17 22:49:26] 操作者

好
然后 你看看 已有结果 做 相应 优化

## ⬜ [2026-06-17 22:52:49] Claude

Let me look at the actual results, then make the optimizations they motivate. Most results-driven optimizations are already in (CF, WSD, KD_EXACT_TAIL), but a careful re-mine of the parrot baseline may surface more. Let me pull the precise numbers and run a rigorous results-mining pass — each lens proposes optimizations from the data, every proposal adversarially verified — then I implement the confirmed-safe ones:

## ⬜ [2026-06-17 22:53:23] Claude

Numbers in hand. Now the results-mining workflow — 5 optimization lenses read the full parrot results + current recipe and propose result-motivated changes, each adversarially verified for "real, safe, and not-already-done," then synthesized into an implementable list:

## ⬜ [2026-06-17 22:54:45] Claude

The results are clear, and they point at a few candidate optimizations beyond what's already done. The mining workflow (`woqt2iplo`) is now checking each against the actual code (real? safe? not-already-done?) before I implement.

**What the parrot results show + the candidate optimizations being vetted:**

| Result | Candidate optimization |
|---|---|
| **CE=0.000 on ~20% no-gold steps** (teacher still emits memorized answer → KD distills "answer without evidence") | down-weight KD on no-gold (a *secondary* parrot channel, separate from what CF fixes) |
| **EM=0 / F1=0.02** but teacher-forced acc 17.7% (can't generate) | CE_W up for the answer span? EOS/answer-end signal? or pure undertraining |
| **gnorm 102→3-8, never diverged** (big stability headroom) | higher peak LR (3e-4 → 4-6e-4) for faster convergence |
| **argmax-agreement 0.21, KD plateau ~3.0** (far from teacher) | KD-fidelity tweaks (TAU, per-token teacher-confidence weighting) |
| **~1 epoch, contamination caveat** | extractive-answer data filter (only keep rows where reading is *possible*) |

Most of the obvious result-driven optimizations are **already in** (CF reading-force, WSD, KD_EXACT_TAIL, cf_lift selection) — this pass finds **what's left**, and verifies each is safe + not-already-done before I touch code.

When it lands (~10 min) I'll **implement the confirmed-safe ones, test, and commit** — same discipline as add.50–55 (opt-in defaults, tests green). I'll report the implemented set. Standing by.

## 🟦 [2026-06-17 22:56:03] 操作者

模型放大(≤1GB)

我觉得 还是 小于 1gb 比较好 或者 说 2gb 后 再 做量化

## ⬜ [2026-06-17 22:57:24] Claude

Good refinement — that tightens the (deferred, gated) scaling ceiling. Let me lay out the deploy math, since it's all about the **int8 on-device footprint**:

| params | fp16 (train/store) | **int8 (deploy)** | int4 |
|---|---|---|---|
| **544M (now)** | 1.1 GB | **0.54 GB** ✓ | 0.27 GB |
| 741M | 1.5 GB | **0.74 GB** ✓ | 0.37 GB |
| 895M | 1.8 GB | **0.90 GB** ✓ | 0.45 GB |
| ~1.0B | 2.0 GB | **1.0 GB** (the line) | 0.50 GB |
| ~1.5B | 3.0 GB | 1.5 GB ✗ | **0.75 GB** ✓ |

**Your two phrasings reconcile cleanly** — deploy is int8, so:
- **"<1 GB is better"** → cap params at **~1 B** (int8 = 1.0 GB). The budget research's escalation targets (**741M / 895M = 0.74 / 0.90 GB int8**) already sit comfortably under 1 GB. The current 544M is 0.54 GB.
- **"2 GB then quantize"** → that *is* the standard path: a ~1B model is **2 GB fp16 → int8 → ~1 GB**. For headroom under 1 GB (or to push past 1B params), **int4** (e.g. 1.5B int4 = 0.75 GB).

So the refined rule: **on-device int8 < 1 GB → ~1B param ceiling** (down from the ~2B the old ≤2GB-int8 allowed). This actually *confirms* the research's modest-growth direction (741–895M) and just caps the top tighter.

**One honesty flag:** int8 is **quant-safe** for this arch (the convertibility memory: Mamba-3 converts as cleanly as Mamba-2). **int4 is not yet validated** — the quant-fidelity gate is still a stub. So if a future model needs int4 to fit <1GB, that gate must be measured first. Recommendation: stay on the **int8 path, ≤~895M–1B params** (0.9–1.0 GB) — no int4 risk, fits <1GB.

**No change to the immediate plan:** Run-1 stays 544M (token-starved, not capacity-bound); scaling is still double-gated (rewrite lands AND Run-1 plateaus). I'll bank this refined ceiling in the plan. The results-mining workflow (`woqt2iplo`) is still running — I'll implement its confirmed optimizations when it lands.

Let me update the plan memory with the refined target:

## ⬜ [2026-06-17 22:57:41] Claude

Banked — the plan now reads **on-device int8 < 1 GB → ~1B param ceiling**, int8-only (int4 unvalidated). 

Nothing else changes right now: Run-1 stays 544M, scaling stays gated. I'm waiting on the results-mining workflow (`woqt2iplo`) — when it lands I'll implement the confirmed result-driven optimizations (the no-gold-KD parrot channel, possible CE_W/LR tweaks, extractive-answer filter — whichever survive verification), test, and commit. Will report then.

## 🟦 [2026-06-17 23:01:12] 操作者

继续 优化

## ⬜ [2026-06-17 23:01:26] Claude

Let me check the results-mining workflow — it should have the confirmed optimizations to implement:

## ⬜ [2026-06-17 23:02:05] Claude

Output's still empty — the workflow is mid-run. Let me check its progress:

## ⬜ [2026-06-17 23:02:34] Claude

The workflow is in its **final phase** — 20 agents done (5 lenses + 15 verify skeptics), latest activity this minute, synthesis running. It'll land momentarily. Let me re-check for the result:

## ⬜ [2026-06-17 23:02:42] Claude

Foreground sleep is blocked — the workflow notifies on completion anyway. Let me just check now:

## ⬜ [2026-06-17 23:03:04] Claude

The workflow is synthesizing (last step) — it'll fire its completion notification any moment. I'm holding to implement the instant it lands, rather than pre-empt the verification I commissioned (some candidates may get rejected as already-done or unsafe).

The moment it returns I'll **implement the confirmed-safe optimizations → test → commit** in one pass — no further back-and-forth. My highest-confidence candidate going in is the **no-gold-KD parrot channel** (`KD_NOGOLD_W` to down-weight KD on the ~20% no-gold steps where the teacher emits its memorized answer — a secondary parrot channel CF doesn't cover); the workflow is confirming whether that + CE_W/LR/extractive-filter survive. Back with the implemented set shortly.

## ⬜ [2026-06-17 23:05:02] Claude

Excellent, concrete results. Let me read the full synthesis (the truncated part — defer list + summary) before implementing:

## ⬜ [2026-06-17 23:05:36] Claude

Full list in hand — 8 optimizations, all byte-identical-by-default + A/B-safe. Let me implement the code ones (the env/doc ones I'll document):

**Code:** #1 RAFT_EOS (the structural EM=0 fix), #3 GRAD_CLIP knob (the clip throttles ~100% of back-half steps), #4 KD_NOGOLD_W (the secondary parrot channel), #6 genuine_reading claim_card gate, #8 LR floor. Let me get the anchors:

## ⬜ [2026-06-17 23:06:07] Claude

All anchors found. Let me implement them one by one. **#3 GRAD_CLIP** — the clip throttled ~100% of back-half steps (median pre-clip gnorm 4.96 ≫ the hardcoded 1.0) during the still-descending phase:

## ⬜ [2026-06-17 23:06:28] Claude

**#4 KD_NOGOLD_W** — the secondary parrot channel (no-gold steps distill the teacher's evidence-free memorized answer). Let me read `kd_ce` to place it:

## ⬜ [2026-06-17 23:07:00] Claude

Now add both to the config print for observability:

## ⬜ [2026-06-17 23:07:20] Claude

Now **#1 RAFT_EOS** — the structural EM=0 fix (the model is never taught to stop). Let me read `to_ids`:

## ⬜ [2026-06-17 23:08:02] Claude

**#6 genuine_reading claim_card gate** — the genuine metric is computed but never gated. Let me read `claim_card`:

## ⬜ [2026-06-17 23:08:18] Claude

Let me find the eval-module thresholds to add a `CF_GENUINE_GATE`:

## ⬜ [2026-06-17 23:09:23] Claude

Now let me compile-check the edits, then add tests for the testable changes (RAFT_EOS + the genuine_reading gate):

## ⬜ [2026-06-17 23:09:39] Claude

The `test_claim_card_exactly_eight_gate_keys` test will interact with my present-only gate. Let me check `_passing_res()`:

## ⬜ [2026-06-17 23:09:50] Claude

`_passing_res()` has no counterfactual → the 8-gate test stays green (present-only works). Let me read the full `_passing_res` to write the new gate test:

## ⬜ [2026-06-17 23:10:11] Claude

Now the two tests. First the genuine_reading gate test in test_eval_gates.py:

## ⬜ [2026-06-17 23:10:23] Claude

Now the RAFT_EOS test in test_big_levers.py:

## ⬜ [2026-06-17 23:11:02] Claude

3/3 new tests pass (genuine gate, RAFT_EOS, and the 8-gate test still holds — present-only works). Now let me wire the new levers into the runbook. Let me find the CF launch command:

## ⬜ [2026-06-17 23:11:34] Claude

Now the full suite, then commit:

## ⬜ [2026-06-17 23:11:59] Claude

add.56 implemented — the result-driven optimizations from the mining pass. Here's what landed:

## Implemented (code, all default-off / byte-identical)
| # | Optimization | What the result showed → the fix |
|---|---|---|
| **1** ⭐ | **`RAFT_EOS`** (raft.py) | EM=0 was **structural** — `eos` was in *no* training target, so generation never stops. Append EOS to the answer span → it learns to STOP. |
| **3** | **`GRAD_CLIP`** knob (cloud_distill.py) | The clip was hardcoded 1.0, but back-half pre-clip gnorm median = 4.96 → it throttled **~100% of back-half steps 3-18×** during the still-descending phase. Now a knob (try 5.0). |
| **4** | **`KD_NOGOLD_W`** (cloud_distill.py) | On ~20% no-gold steps the teacher emits its *memorized* answer → a **2nd parrot channel** CF doesn't cover. Down-weight KD there (try 0.3); stacks with CF. |
| **6** | **`genuine_reading` claim_card gate** (eval.py) | The genuine metric I built was computed but never *gated* — now a **present-only gate** (credits causal reading the blind slope can't). |

Plus **doc**: the new levers wired into the CF launch command + `CE_W=1.0` as an env-A/B + `KD_EXACT_TAIL=1` turned on (was built but never enabled).

## Skipped (honestly)
- **#8 LR floor 0.07→0.10** — WSD (already built) is the strictly-better lever for the same dynamic, and changing the default breaks parrot-baseline comparability.
- **#7 cache-coverage diagnostic** — a useful pre-run audit but a *diagnostic*, not a capability change; deferred to keep this batch focused.
- **Peak-LR bump** — correctly rejected: it's a silent no-op while the clip re-normalizes every step (GRAD_CLIP must come first, which it now does).

**3 new tests pass** (RAFT_EOS appends+supervises EOS, KD_NOGOLD/genuine gate present-only + thresholds, 8-gate test still holds). Full suite verifying now — I'll **commit + push** the moment it's green. Then the result-driven optimization pass is complete and banked.

## ⬜ [2026-06-17 23:16:24] Claude

**412 passed** (409 + 3 new), exit 0. Committing + pushing add.56:

## ⬜ [2026-06-17 23:17:22] Claude

Committed `1e18670a0` + pushed. Let me bank the new levers in the resume memory so next session's CF run uses them:

## ⬜ [2026-06-17 23:17:54] Claude

Done — the result-driven optimization pass is complete, committed (`1e18670a0`), pushed, and banked.

## ✅ add.56 shipped (412 tests green)
Mined the parrot baseline → 4 code optimizations + doc, every one adversarially verified before implementing:

1. **`RAFT_EOS`** ⭐ — the standout find: **EM=0 was structural, not just undertraining**. No training target ever contained EOS, so generation literally couldn't stop. This was a hidden bug masquerading as "needs more training."
2. **`GRAD_CLIP` knob** — the hardcoded clip=1.0 was silently throttling ~100% of back-half updates 3-18× during the *still-productive* phase.
3. **`KD_NOGOLD_W`** — closes a *second* parrot channel (no-gold KD of the teacher's memorized answer) that CF doesn't cover; they stack.
4. **`genuine_reading` claim_card gate** — the causal reading metric I built (add.54) is now an actual gate, not just a printout.

Plus the doc's CF command now carries all of them + `KD_EXACT_TAIL=1` (built but never enabled) + `CE_W=1.0` A/B.

## Honest scope
- **Skipped** #8 (WSD supersedes it) and the peak-LR bump (a no-op until GRAD_CLIP existed — now it does).
- **Deferred** #7 (cache gold-token-coverage diagnostic) — noted in memory for next session.

## Where we are now
The **result-driven recipe optimization is essentially exhausted** — everything the parrot data motivates is implemented (CF, the metric machinery, WSD, EOS, the clip, the no-gold channel, KD_EXACT_TAIL). The next CF run command (with all levers) is banked in memory + the runbook.

The two things genuinely **left** both need resources we don't have right now: the **throughput rewrite** (a major build) and the **actual CF run on a fresh healthy pod** (which answers "does it read" + then unlocks the ≤10h Run-1). When you spin up a clean pod, it's one command — and this time it'll terminate cleanly *and* run a much better-optimized recipe.

## 🟦 [2026-06-18 11:35:44] 操作者

目前怎么样了

## ⬜ [2026-06-18 11:36:06] Claude

Let me check for any lingering processes and confirm the committed state:

## ⬜ [2026-06-18 11:36:40] Claude

一切已稳定落定,**没有任何在跑的任务**(pod 已终止,本地也无活动)。当前状态:

## ✅ 全部已提交 + 备份
| 项 | 状态 |
|---|---|
| **代码** | `1e18670a0`(add.56 结果驱动优化)+ `5802fdc42`(add.50-55 CF+度量),**已推 GitHub,工作区干净,412 测试绿** |
| **parrot warm-start 模型** | `~/cf_preserve/parrot/ckpt_best.pt`(6.5GB,md5 校验过)✓ |
| **结果 + resume 计划** | `~/cf_preserve/` + memory(`cf-run-resume-state` 含下次 CF 命令)✓ |

## 这个 session 的净产出
1. **阅读修复 + 度量机器**(CF 强制阅读、genuine 错配判据、regime-aware verdict)—— 落地。
2. **结果驱动优化 6 项**(add.56)—— 最关键发现:**EM=0 是结构性 bug(训练目标里从没 EOS,模型根本不会停)**,不只是欠训练;外加 GRAD_CLIP(后半程被卡死)、KD_NOGOLD_W(第二条鹦鹉通道)、genuine 门。
3. **≤10h 训练计划 + ≤1GB 尺寸约束** —— 研究+定稿。
4. **诚实结论**:parrot 基线确认不读(lift=−0.007);今天的 CF 跑挂**纯属 RunPod volume 满+坏**,不是 recipe。

## 还剩什么(都需要资源,现在做不了)
- **真正跑 CF**(答"会不会读")—— 需要一个**干净的新 pod**;命令已备好(含 add.56 全部杠杆,ckpt 写本地盘的教训也记下了)。
- **≤10h Run-1 质量跑** —— CF 出正信号后。
- **吞吐 rewrite(4-8×)** —— 一个较大的工程,长跑的前提。

## 一件你要做的
**轮换 HF token**(`hf_kEwDog…`,在 pod 命令+聊天里出现过)。

**一句话:这个 session 能在本地/已有数据上做的优化基本做尽了,全部银行入账;真正的下一步是开个新 pod 把 CF 跑出阅读答案。** 你随时开 pod,我接着上。

## 🟦 [2026-06-18 11:37:05] 操作者

全面 audit

## ⬜ [2026-06-18 11:37:55] Claude

A comprehensive audit of the full session's work (add.50–56) — that's a substantive, multi-dimensional review and exactly what a fan-out audit is for. Let me run it: 7 audit dimensions over the actual committed code, each finding adversarially verified, then synthesized into an overall verdict + must-fix list.

## ⬜ [2026-06-18 11:39:22] Claude

全面 audit 已启动(`wx4q6avrm`)—— 对本 session 全部提交代码(add.50–56)的 7 维深度审查,每条发现都经对抗验证,最后汇总成总体裁决 + must-fix 清单。覆盖面:

| 维度 | 审什么 |
|---|---|
| **reading-science** | CF 到底强不强制阅读 + genuine 判据是否真有效(能不能被刷/有没有第4种失败模式)—— make-or-break,审最狠 |
| **verdict-and-gates** | p0_verdict 的 regime 分支 + NaN 处理 + claim_card 新 present-only genuine 门,有无误GO/误NO-GO |
| **add56-levers** | RAFT_EOS(EOS在监督span?截断?data_fp?)、GRAD_CLIP、KD_NOGOLD_W 的正确性 + **组合安全**(互相会不会冲突) |
| **data-cache-integrity** | gold-survival 截断、cache 指纹是否覆盖 RAFT_EOS/KD_K、E4 对齐、污染 |
| **train-loop-numerics** | 损失组合(CF分支 kd=0、no-gold权重)、autocast/fp32策略、resume、MAX_SEC break |
| **test-coverage** | 412 测试是否真护住关键路径(KD_NOGOLD_W 闭包没单测?)、有无 tautology 测试 |
| **deploy-scale-honesty** | resolve_ckpt fail-closed、int8/≤1GB、吞吐数字是否诚实标注未实测、有无 over-claim |

跑完(~10-15min)我把**总体裁决(SOUND / SOUND_WITH_FIXES / NOT_READY)+ must-fix 清单**给你,并**立即实现验证后的修复**(同 add.50-56 的纪律:opt-in、测试绿、提交)。这是新 CF run 花钱前的最后一道关。待结果。

## ⬜ [2026-06-18 11:58:43] Claude

The audit caught real bugs — including two in my own add.55/56 work. Verdict: **SOUND_WITH_FIXES**, 4 HIGH must-fixes. Let me read the complete result before implementing:

## ⬜ [2026-06-18 11:59:47] Claude

Comprehensive audit: **SOUND_WITH_FIXES**, 4 must-fixes (2 are bugs in my own add.55/56), plus high-value hardening + test gaps. Let me implement them all. Starting with **#3 word-boundary fact-swap** (str.replace corrupts substrings like "Ann"/"US"/"19", distorting the make-or-break metric). Let me read the swap sites:

## ⬜ [2026-06-18 12:00:18] Claude

`re` isn't imported. Let me add it + word-boundary helpers, then fix both swap sites (#3):

## ⬜ [2026-06-18 12:01:08] Claude

Now the CF-train-pool swap site (#3 cont.):

## ⬜ [2026-06-18 12:01:26] Claude

**#1 RAFT_EOS eval symmetry** — gold is decoded with the EOS literal but pred isn't → EM→0 (the lever defeats itself). Let me read `generate_and_score`:

## ⬜ [2026-06-18 12:01:40] Claude

The cleanest tokenizer-agnostic fix (works with the StubTok too): strip the trailing EOS from the gold span before decoding, so it's symmetric with pred (which stops *before* EOS):

## ⬜ [2026-06-18 12:02:12] Claude

**#2 MAX_SEC hit_wall** — the wall-break ckpt is clobbered by the unconditional final save (step=STEPS) → resume thinks it's done. Let me find the break + final-save block:

## ⬜ [2026-06-18 12:03:06] Claude

**#4 offline EVAL_CKPT genuine gate** — the offline path builds only matched E4, dropping the genuine gate (exactly the pod-death recovery scenario). Let me unify both paths via a shared helper. Let me read the offline path + eval.py imports:

## ⬜ [2026-06-18 12:04:11] Claude

eval.py imports RAFT. Let me add the shared `eval_counterfactual_full` helper after `eval_counterfactual`:

## ⬜ [2026-06-18 12:04:35] Claude

Now wire the offline path to use it (#4 + #8 contamination fail-closed):

## ⬜ [2026-06-18 12:05:03] Claude

Now route the in-training final card through the same shared helper:

## ⬜ [2026-06-18 12:05:22] Claude

Now the claim_card fail-closed (#4 + #5 — a *run* probe with missing/NaN genuine must fail, not silently waive):

## ⬜ [2026-06-18 12:05:44] Claude

Now update the genuine-gate test for the new fail-closed semantic (a *run* probe with NaN/missing genuine → gate False, not absent):

## ⬜ [2026-06-18 12:06:09] Claude

Now **#6 GRAD_CLIP≤0 guard** (`GRAD_CLIP=0` would zero all grads → silent no-train). Treat ≤0 as no-clipping:

## ⬜ [2026-06-18 12:06:23] Claude

**#7 threshold operator unify** — p0_verdict uses `>`, claim_card uses `>=` for the same genuine threshold. Align to `>=`:

## ⬜ [2026-06-18 12:06:54] Claude

**#9 test gap** — the no-gold KD knobs (`KD_NOGOLD_W`, `RAFT_NOGOLD_CE`) live in the `kd_ce` closure with zero coverage. Let me extract them into pure, testable helpers. Let me find the helper area:

## ⬜ [2026-06-18 12:07:14] Claude

Now use the helpers in `kd_ce`:

## ⬜ [2026-06-18 12:08:08] Claude

Now compile-check the source edits, then add the test-gap tests (#9, #10, #11):

## ⬜ [2026-06-18 12:08:48] Claude

Now the #10 RAFT_EOS eval-symmetry test (the gold trailing-EOS strip). Let me check test_eval_gates.py imports + a spot:

## ⬜ [2026-06-18 12:09:54] Claude

11/11 new tests pass. Now the full suite to confirm no regression across the audit fixes:

## ⬜ [2026-06-18 12:10:38] Claude

While the suite verifies, here's the audit outcome + what I fixed:

## Audit verdict: **SOUND_WITH_FIXES** (51 agents, 39 real findings, 6 flagged blocking)
No catastrophic defect — a default-config CF run isn't doomed — but real bugs that would mislead the next run, **including two in my own add.55/56 work**. All must-fixes + key hardening now implemented (add.57):

### ✅ 4 must-fixes
| # | Bug | Fix |
|---|---|---|
| 1 | **Offline `EVAL_CKPT` dropped the genuine gate** → a CF ckpt could grade 成了 without the reading test (the *exact* pod-death recovery path) | shared `eval_counterfactual_full` helper used by **both** paths + claim_card **fail-closed** |
| 2 | **`RAFT_EOS` corrupted EM/F1** (my add.56) — gold kept the EOS literal, pred didn't → EM≈0, the lever self-defeating | strip the trailing EOS from gold in `generate_and_score` |
| 3 | **`str.replace` fact-swap** mangled substrings ("Ann"→inside "Announcement") → biased the make-or-break metric | word-boundary `_swap_fact`/`_has_word` at both swap sites + gates |
| 4 | **`MAX_SEC` wall-ckpt clobbered** by the final save (my add.55) → resume thought a partial run was DONE | `hit_wall` sentinel guards the final save + DONE + stamps `partial_run` |

### ✅ Hardening + test gaps closed
- claim_card **fail-closed** on a run-but-unmeasured genuine (empty-mismatch silent-waive) · `GRAD_CLIP≤0` no-train footgun guarded · `p0_verdict` `>`→`>=` (matches claim_card) · offline `contamination_ok` fail-closed.
- **no-gold KD/CE knobs extracted to pure helpers + tested** (were zero-coverage) · word-boundary test · RAFT_EOS EM-symmetry test. **11 new tests, all green.**

### Deferred (real but non-catastrophic — noted for next session)
genuine on first-token rate (vs span-averaged) · verdict reads last-eval but ships `ckpt_best` (persist genuine into `best_meta`) · pin `HOTPOT_REVISION` in the launcher · deploy-runbook routes hybrid→wrong converter (+ guard) · on-device size/throughput caveat (VOCAB=4096 probe numbers) · non-finite-skip wipes the accum window · full loss-composition integration test.

Full suite verifying now — **commit + push when green.** Then I can knock out the cheap deferred ones (deploy-guard, HOTPOT pin, size caveat) if you want. Will report.

## 🟦 [2026-06-18 12:10:51] 操作者

目前 可以 给 local llm 做 加速器吗 我本来想做 提高 tokens/s
小模型给大模型打工来加速解码 但是 所有 模型 通用

## ⬜ [2026-06-18 12:12:57] Claude

先说明:add.57(审计修复)的全测试还在后台跑,绿了我就提交——不打断你这个问题。

你描述的就是 **speculative decoding(投机解码)**:小模型(draft)给大模型(target)打工,draft 先猜 N 个 token、target 一次性验证 → 接受的就省掉了 N 次串行前向。这是真实有效的加速器。但你加的那个约束 **"所有模型通用"** 恰恰是最难的点,它把答案劈成两半:

## ① "一个小模型加速所有大模型" —— 做不到(词表耦合)
标准 spec-decode 的 draft **必须和 target 共享 tokenizer/词表**(draft 要在 target 的词表里出 token)。所以一个 Llama-draft 不能给 Qwen-target 用。**"一个通用 draft 模型加速任意大模型"在标准 spec-decode 下不成立。**
- 唯一绕过:**cross-tokenizer / HF Universal Assisted Generation**(跨词表重编码)—— 能"任意 draft 配任意 target",但有损(接受率掉)+ 复杂 + 端上开销大。

## ② 真正"通用"的 = 无模型 drafting(这才是你要的)
不需要 draft 模型,**任何模型零配置都能用**:
- **prompt-lookup / n-gram**:从上下文抄 n-gram 当草稿。**你项目已经上线了**(1.58× 重复场景)。
- **lookahead decoding(Jacobi)**:比 prompt-lookup 覆盖更广,仍然无模型 → 通用。这是 prompt-lookup 的自然升级。

## ③ 端上现实检查(你自己测过的,关键)
A19 是**带宽瓶颈**(ρ=0.83);你之前 Saguaro/采样 spec-decode 收益不行(0.77×),原因是 **draft 模型自己也要读权重** —— draft 不够便宜就白搭。
> **反转结论:无模型 drafting 反而是端上最优** —— 零 draft 权重成本,只把 target 的"一次权重读"摊到多个被接受的 token 上,正好对症带宽瓶颈。之前 spec-decode 失败是因为用了**真模型当 draft**;换成无模型就绕开了这个坑。

## 诚实总结
| 路线 | 通用性 | 端上 | 代价 |
|---|---|---|---|
| **无模型 lookahead/prompt-lookup** | ✅ 所有模型 | ✅ 带宽友好 | 自由散文≈1×,重复/代码/JSON/RAG-引用/编辑 才大涨 |
| 词表匹配 spec-decode(已认证 1.459×) | ❌ 每个模型一个 draft | ⚠️ 带宽封顶 | 不通用 |
| cross-tokenizer UAG | ⚠️ 较通用 | ⚠️ 开销 | 有损+复杂 |
| Medusa/EAGLE 自投机头 | ❌ 每个 target 要训练 | — | 不通用 |

**一句话:你要的"通用加速器"= 无模型 drafting(lookahead)** —— 任何模型、零配置、带宽友好;"一个小模型加速所有大模型"被词表卡死(只能 UAG 有损绕)。而端上最大的**通用** tokens/s 提升其实不全在 spec-decode(带宽封顶),还在**量化 + KV-cache + 模型选型**。

要不要我做一次**深度调研**:lookahead / UAG / n-gram-retrieval 的最新方法 + A19 带宽实测可行性 + 能不能直接在你现有 MLX 栈上 build 一个**通用、training-free** 的加速器(目标:不止重复场景,自由文本也能 1.3-1.5×)?给你一条能落地的路线。你拍板方向我就开。

## ⬜ [2026-06-18 12:14:10] Claude

add.57 suite finished — let me confirm green and commit the audit fixes:

## ⬜ [2026-06-18 12:14:28] Claude

**415 passed** (+3 audit-fix tests), exit 0. Committing add.57:

## ⬜ [2026-06-18 12:15:15] Claude

add.57 committed (`0e7674ac5`) + pushed — **the full audit is closed**: SOUND_WITH_FIXES, all 4 must-fixes + hardening + the worst test gaps done, 415 tests green. Let me update the resume memory, then back to your accelerator question:

## ⬜ [2026-06-18 12:15:52] Claude

Memory updated — the audit is fully banked. Now, back to your universal-accelerator question. The analysis stands: **the truly "all-models" accelerator is model-free drafting (lookahead decoding)** — a single small model for all targets is blocked by tokenizer/vocab coupling, and on the bandwidth-bound A19 the model-free path is actually *optimal* (no draft weight cost). How do you want to proceed?

## ⬜ [2026-06-18 12:17:15] Claude

**先深度调研.** Launching a deep-research workflow on the universal training-free accelerator — 5 angles (lookahead decoding, retrieval/n-gram drafting, cross-tokenizer UAG, the A19/MLX bandwidth viability, and build-feasibility), each web-searching the latest methods + measured numbers AND grounding in your project's measured on-device constraints, then adversarially verified and synthesized into a concrete build plan:

## ⬜ [2026-06-18 12:18:25] Claude

Deep research launched (`wxcbjz41p`) — 5 angles in flight, each web-searching the latest methods + measured numbers and grounding in your A19/MLX measurements, then adversarially verified (to catch over-optimistic benchmark numbers that won't survive the bandwidth ceiling), and synthesized into a build decision.

**What it'll deliver (~10-15 min):**
- **Verdict**: BUILD_IT / BUILD_WITH_CAVEATS / NOT_WORTH_IT.
- **Recommended technique** (likely lookahead decoding vs retrieval-n-gram vs cross-tokenizer UAG).
- **Honest tokens/s by workload** — the key question is whether it beats ~1× on *free-form* prose (not just repetitive/code/JSON/RAG), given the A19 is bandwidth-bound.
- **Concrete MLX build plan** — what to reuse from your shipped prompt-lookup + certified spec-decode, the primitives lookahead needs (the Jacobi attention mask / batched verify), and the effort/risk.
- **The honest ceiling** — where the bandwidth wall stops it helping.

The sharp question it's testing: *does model-free drafting actually win on a bandwidth-bound phone* (the amortized-weight-read hypothesis — which would explain why your model-based spec-decode declined but a model-free one might not). I'll bring you the verdict + plan when it lands.

(add.57 audit fixes are committed `0e7674ac5` + pushed — that thread is fully closed.)

## 🟦 [2026-06-18 12:26:33] 操作者

能不能设计一个通用 draft substrate，让不同小模型、缓存、lookup、tokenizer bridge、在线适配共同服务不同大模型？

## ⬜ [2026-06-18 12:28:20] Claude

是的——而且这其实是**比"选一个技术"更对的答案**。单一技术(lookahead / spec-decode / prompt-lookup)各有各的舒适区;你说的这个 **通用 draft substrate** 把它们变成可插拔的"草稿源",上面套一层**路由 + 在线适配** —— substrate 本身是通用层,各 source 是插件。这正是"所有模型通用"该有的形态。让我把架构和硬约束都讲清楚。

## 架构:一个 draft-side 的路由/集成层
target 的解码循环每步调 `substrate.draft(ctx, target) → candidates`,target 一次前向验证,再 `substrate.observe(accepted)` 反馈。六层:

1. **Source 接口** `propose(ctx, target_vocab) → 候选 + 置信`(可插拔):
   - **n-gram / 后缀自动机**(=你已上线的 prompt-lookup):零成本,重复/结构化场景。
   - **retrieval / datastore**(REST 式):从语料抽 n-gram,拓宽到开放域。
   - **vocab-matched 小模型**:自由文本质量高,但绑定 target 词表族。
   - **bridged 外来小模型**(经 tokenizer bridge):任意小模型→任意 target,通用但有损。
   - **self-draft**(target 自己的 Medusa/EAGLE 头或 early-exit,如果暴露)。
2. **Tokenizer Bridge** — 把外来草稿的**文本**重编码进 target 词表(处理半 token 边界)。这是"一个小模型服务多 target"唯一的通道,也是最弱的一环(重编码掉接受率)。
3. **Router/Scheduler** — 每个 (target, 工作负载) 一个**在线 bandit**:跟踪各 source 最近的**接受长度**,把下一份草稿路由给最优 source(或合成一棵候选**树**),并自适应草稿长度 k。**纯运行时统计,不训练任何模型**。
4. **Tree Verifier** — target 用**一次前向 + 树注意力掩码**(SpecInfer/Medusa 式)验证多源候选树,取最长被接受路径。这是通用的那部分(任意 target 的前向)。
5. **共享缓存** — 后缀自动机、retrieval datastore、投机窗口的 KV、各 source 的接受率统计。
6. **在线适配** — bandit 从 `observe` 更新;可选一个**会话内自增长的 n-gram 缓存**(用 target 自己的输出喂回去 → n-gram source 随会话越用越准,等于在线自蒸馏 target 的风格)。

## 为什么这是"通用"的正解
substrate 是通用层、source 是插件、router **运行时**学每个 target/负载该用谁(零 per-target 训练)、在各技术的优势区取最优 —— 正好是你说的"共同服务不同大模型"。

## 诚实的硬约束(必须认)
1. **天花板还是 target 的那次前向。** substrate 在**草稿侧**优化接受率,改不了验证成本。增益 ≈ E[每次验证接受的 token 数] − 开销。
2. **端上(A19 带宽瓶颈):模型类 source 会多读一次草稿权重 → 常常净负**(就是你之前 spec-decode 被否的原因)。所以**端上配置 = 以无模型 source 为主(n-gram + retrieval + self-draft)+ router**;模型草稿留给桌面/高带宽。端上 substrate 的价值在:**路由 + 在线自适应把无模型草稿的胜场从"重复"拓到"自由文本" + 树验证摊销**。
3. **tokenizer bridge 有损** —— 跨词表通用性的代价。
4. **树注意力掩码是要在 MLX 上 build 的关键 kernel。**

## 不是凭空 —— 有据可循 + 哪里是新的
拼图都有先例:**SpecInfer**(树式多草稿一次验证)、**HF assisted-generation + UAG**(框架 + 跨词表)、**REST**(检索草稿)、**Medusa/lookahead**。**新**的是:把异构 source + tokenizer bridge + **在线自适应路由** 统一成一个**面向端上**的 substrate —— 据我所知没有现成的这种"自适应异构投机底座"。

## 路径
正在跑的深度调研(`wxcbjz41p`)给的就是各 source 的**实测证据**(lookahead/UAG/retrieval 的真实 × + 端上可行性)—— 那是这个 substrate 的选型输入。等它落地,我建议**再跑一个架构设计 workflow**:把上面的草图变成**可 build 的具体 spec**(source 接口、router 策略、端上 MVP 配置、树验证 kernel、复用你已上线的 prompt-lookup/spec-decode),并**对抗式批判**(哪里会塌、bridge 损多少、bandit 收敛多快、MVP 最小能跑出多少)。

要不要我等调研回来后,**直接把这个 substrate 设计成一份正式 spec(含 MVP 落地路线)**?还是你想先看调研结果再定 substrate 的范围?

## ⬜ [2026-06-18 12:29:41] Claude

调研回来了,而且**直接回答了你的 substrate 问题**——它就是 substrate 各 source 的实测证据。结论:**BUILD_WITH_CAVEATS**,但实测把"通用 substrate"在端上的形态狠狠收窄了。

## 关键实测(A19/MLX,带宽瓶颈 ρ≈0.83)
| source | 实测 × | 端上判定 |
|---|---|---|
| **无模型 n-gram(prompt-lookup,已上线)** | RAG-quote **2.05×**、JSON 1.58×、code 1.46×、verify 1.23× | ✅ 唯一通用且端上正收益 |
| 自由散文(任何无模型草稿) | **0.92×(−8%)**,hit_rate 0.05 | ❌ 结构性 ~1× 墙,只能 lane-gate 关掉 |
| **lookahead / Jacobi / tree-spec** | **0.76×(净亏)** | ❌ "额外FLOP免费"在 A100 成立,A19 算力太小不成立 |
| **cross-tokenizer UAG(词表桥)** | ≤**1.06×**,自由文本 sub-1× | ❌ 多一条权重流 + 重编码损耗 |
| **独立 draft 模型 / ANE-draft** | **0.34×** | ❌ 双带宽流争用 |

baseline Llama-3.2-3B ≈ 32.5 tok/s;prompt-lookup lane-gated 后重复场景均值 1.58× → ~51 tok/s。

## 这对你的 substrate 意味着什么(诚实)
**架构是对的,但端上的"可插拔 source"几乎全被带宽墙打成净负** —— 除了无模型那一类。所以:

1. **你其实已经建好了 substrate 的骨架** —— `BASPromptLookupDrafter`(source)+ `BASDecodeLanePolicy`(router)+ adaptive-K(在线适配)就是一个**原始 substrate**:源 + 路由 + 适配。
2. **端上版 substrate = 只装无模型 source 的 lane-router**。你列的"不同小模型 / tokenizer bridge / 在线模型适配"在 A19 上**实测都是负的**(0.34× / ≤1.06× / 0.76×)—— 装上去反而更慢。**亏的不要装。**
3. **唯一值得新建的 source:cross-turn 后缀自动机**(SuffixDecoding 式)—— 把现在 O(n) 的单序列回扫,换成跨整段对话(prompt + 所有历史轮)增量构建的后缀自动机。模型无关、通用、几十 MB、O(log n)。projected **比 plain prompt-lookup 在多轮 agentic/重复上下文再快 1.3-3×**(未端上实测)。**这是这次唯一的真增量,~2-4 天,低风险(验证路径不变 → 仍 byte-identical)。**

## 两层 substrate 才是完整答案
- **端上(A19,~70 GB/s)**:model-free source router + cross-turn 后缀自动机。富集成(多模型/桥/树)在这里**净负**。
- **桌面/服务器(HBM ~1.5 TB/s)**:这里带宽够,你说的**完整异构 substrate(不同小模型 + tokenizer bridge + tree-verify)才兑现 1.5-2.5×** —— 调研里"datacenter one-draft-for-many"的数就是这个档。

→ 所以正解:**把 substrate 设计成统一抽象(source 接口 + router + verifier),但端上只填无模型 source;富 source 是桌面档的插件。** 一套抽象、两档配置。

## 硬墙(认了它)
**单轮·真·自由散文 = 所有 training-free 技术都 ~1×**,这是结构性的(无 n-gram 可抄 → 空草稿),adaptive-K 已被端上**证伪**。任何加第二条带宽流的做法都亏。

## 建议下一步(三选一)
1. **直接 build 那个真增量**:cross-turn 后缀自动机 source(~2-4 天,实测胜出门槛:token-identical 且自由文本对照 ≥1×)。
2. **先把 substrate 写成正式 spec**(统一 source/router/verifier 抽象 + 端上 MVP=后缀自动机+lane-router + 桌面档的富 source 插件位)+ 对抗式批判,再 build。
3. 两者都要:先 spec(1)再 build。

我倾向 **2 再 1**(先把抽象定死,后缀自动机就是抽象的第一个新 source,顺手为桌面档留好插槽)。你定。

## 🟦 [2026-06-18 12:29:44] 操作者

单独一个小模型，不加系统层，很难真正服务所有大模型。

## ⬜ [2026-06-18 12:31:07] Claude

完全正确——而且这正是关键的设计法则:**通用性是系统层的属性,不是模型的属性。**

## 为什么一个裸小模型"不可能"通用
它被锁了两次:
1. **词表锁**:draft 必须说 target 的 token,换个 target(不同词表)就废 —— cross-tokenizer 桥能解但有损(端上 ≤1.06×)。
2. **负载/领域锁**:它的草稿分布只在和 target 匹配的地方有用,换领域就掉。

**系统层把这两把锁都化掉**:它在 **target 自己的 token 空间**里出草稿(构造上就词表通用),并**跨源路由**(负载通用)。于是——

> **"小模型"退化成一个可换的 source,而不是底座本身。端上最优的那个 source 甚至根本不是模型(是无模型 n-gram/suffix)。**

## 该投资 / 该拥有的是系统层契约
substrate 真正的资产是这几样,和具体 draft 来源解耦:
- **source 接口**(`propose(ctx, target_vocab) → 候选`)—— 任何来源都套进来。
- **router**(per-target/负载 的在线 bandit:谁接受率高用谁)。
- **verify/accept 契约**(一次前向 + 树掩码,**byte-identical** —— 这是正确性的根)。
- **在线适配 + 共享缓存**(会话自增长的 n-gram、retrieval datastore、KV 窗、接受率统计)。
- draft 源(n-gram / 后缀自动机 / 小模型 / 桥)= **按硬件 + 负载门控的插件**。端上只开无模型源;桌面才开模型/桥/树源。

## 诚实的边界(系统层也搬不动的)
系统层给你的是**「任意模型 + 更广负载」**,不是「更快的物理」。**自由散文的 ~1× 墙 + 带宽天花板在 substrate 之下** —— 路由再聪明,没东西可抄就是空草稿。所以 substrate 的承诺要诚实地写成:*universal across models, broad across workloads,但 free-form 单轮 ≈1×*。

## 落地
你这句话其实就是在拍板**"投系统层、不投单模型"**的方向。我建议把它固化成**一份正式 substrate spec**:
- 统一抽象(source 接口 / router / verify 契约 / 在线适配)。
- **端上 MVP**:复用已上线的 prompt-lookup+lane-policy,第一个新 source = cross-turn 后缀自动机。
- **桌面档插槽**:模型源 / tokenizer-bridge / tree-verify(带宽够才兑现 1.5-2.5×)。
- 实测胜出门槛(token-identical 且自由文本对照 ≥1×)写进契约。
- 然后**对抗式批判**这份 spec(bridge 损多少、bandit 收敛、byte-identity 边界、MVP 最小能跑出多少)。

要我**现在就把这份 spec 写出来**吗(我直接写 + 跑一轮对抗批判)?还是你想先把范围圈一下(只端上 MVP / 还是连桌面档一起设计)?

## 🟦 [2026-06-18 12:31:07] 操作者

TokenTiming 如何 看待

## ⬜ [2026-06-18 12:31:38] Claude

I shouldn't answer from memory here — "TokenTiming" is a specific technique and I want the actual method + measured numbers, not a guess. Let me look it up:

## ⬜ [2026-06-18 12:32:20] Claude

TokenTiming is a real, recent method (arXiv 2510.15545, Oct 2025) — DTW-based cross-tokenizer alignment for *universal* spec-decode. This hits exactly the weak link I flagged (the tokenizer bridge). Let me pull the specifics — speedup, hardware, overhead, lossless-vs-sampling — to assess whether it changes the on-device verdict:

## ⬜ [2026-06-18 12:33:26] Claude

Looked it up — **TokenTiming** (arXiv 2510.15545, Oct 2025) is a real, strong piece of work, and it lands squarely on the weak link I flagged in your substrate (the tokenizer bridge). My honest take:

## What it is
DTW-style (Dynamic Time Warping) **cross-tokenizer alignment**: it re-encodes the draft's token sequence into the target's vocab and uses DTW to transfer the probability distributions → **any off-the-shelf draft for any target, no retraining, no shared vocab**. Key properties:
- **Provably lossless** (distribution-preserving via speculative *sampling* — accept iff `r < min(1, q/p)` → exact target distribution).
- **1.57× general, 2.27× on 33B targets** — measured on **2× H100 80GB HBM3** (~2 TB/s + compute-bound regime).
- DTW overhead **663 μs/cycle (~0.1-0.5%)** — cheap. Draft 68M-350M, target 14B-70B. **No edge/bandwidth discussion.**

## How I'd weigh it for your substrate
**It validates your original vision** — "one small model serves *any* big model" is now real *and lossless*, no per-target draft training. It's the **SOTA upgrade for the substrate's tokenizer-bridge source** (replaces the lossy UAG path: ≤1.06× → lossless 1.5-2.3×).

**BUT — and this is the load-bearing point — it solves the *tokenizer*, not the *bandwidth*.** It still uses a separate draft **model** = a second weight stream. On your bandwidth-bound A19 (ρ=0.83, ~70 GB/s) that's exactly the regime your own measurements killed: model-draft **0.34×**, UAG **≤1.06×**. TokenTiming's 1.5-2.3× is on 2× H100 where the draft's weight-read is cheap relative to the target — the compute-bound regime the A19 *isn't* in. The 663 μs DTW is fine; the draft-weight read is the killer on-device.

| Tier | TokenTiming verdict |
|---|---|
| **Desktop / HBM (≥1 TB/s)** | ✅ **Adopt it** — the lossless, universal bridge source. This is where "one small draft for all targets" finally pays off (1.5-2.3×). |
| **On-device A19** | ❌ Doesn't move the needle — still a draft model = 2nd bandwidth stream → the 0.34× wall. On-device stays **model-free** (n-gram/suffix). |

## Two nuances worth banking
1. **It's sampling-lossless (distribution-matching), not greedy-byte-identical.** Your shipped on-device spec-decode is *greedy* token-identical (ADR-039). TokenTiming's guarantee is a *different mode* — fine for sampling decode, but the substrate's verify contract should carry **both** modes explicitly (greedy-byte-identical AND sampling-distribution-lossless).
2. **It sharpens, doesn't overturn, your own conclusion** ("一个小模型不加系统层很难服务所有大模型"): TokenTiming is precisely the *system-layer* component that makes the bridge work — but only where bandwidth allows. So it slots into the substrate's **desktop-tier bridge slot** as a concrete, named, SOTA source, while the on-device tier remains model-free. The two-tier design holds and gains a real building block.

**Net:** TokenTiming is the best answer yet for the cross-tokenizer source — adopt it for the desktop tier of the substrate, don't expect it to break the on-device bandwidth wall. Want me to fold it into the substrate spec as the named desktop bridge source (with the greedy-vs-sampling verify-contract split), when I write that spec?

Sources: [TokenTiming (arXiv 2510.15545)](https://arxiv.org/abs/2510.15545) · [HTML](https://arxiv.org/html/2510.15545v1)

## 🟦 [2026-06-18 12:35:33] 操作者

Universal Draft Layer
 ├─ Prompt Lookup Drafter
 ├─ N-gram Cache Drafter
 ├─ Small Mamba Drafter
 ├─ Tokenizer Bridge
 ├─ Target Adapter
 ├─ Acceptance Profiler
 ├─ Online User Adaptation
 └─ Fallback Controller

## ⬜ [2026-06-18 12:37:19] Claude

This is a solid decomposition — it's the substrate spec taking shape. Let me give you a component-by-component verdict (grounded in the research), flag what's **missing**, and hand back a refined tree.

## Per-component verdict
| 组件 | 角色 | 实测判定 |
|---|---|---|
| **Prompt Lookup Drafter** | 当前序列 n-gram | ✅ 已上线·model-free·端上 always-on(重复 1.58×) |
| **N-gram Cache Drafter** | 应是**跨轮后缀自动机**(session-scoped,横跨 prompt+所有历史轮) | ✅ 新建·model-free·端上 always-on(多轮 agentic +1.3-3×) |
| **Small Mamba Drafter** | 小 Mamba 草稿模型 | ⚠️ **最聪明的一招,但要门控**:模型源=第二带宽流(端上 0.34× 墙)。**Mamba 的 O(1) state(无 KV 增长)让它在长上下文是端上最有希望的模型源** —— 但仍读权重 → 必须够小(~50-150M)+ 实测≥1× 才上;桌面稳 |
| **Tokenizer Bridge** | = **TokenTiming**(DTW 跨词表,无损-采样) | 桥本身便宜(663μs);但它**服务的是模型源** → 价值随模型源的硬件档。桌面兑现,端上不破带宽墙 |
| **Target Adapter** | 接任意大模型(词表/前向/KV) | ✅ 必需 —— "服务不同大模型"的插口 |
| **Acceptance Profiler** | per-源/target/负载 接受率 | ✅ 路由 + 门控 + 实测胜出的测量底座 |
| **Online User Adaptation** | bandit 路由 + session 自增长缓存 | ✅ 在线适配层(顺手把 N-gram Cache 越用越准) |
| **Fallback Controller** | 无信号→退回纯自回归 @1.0× | ✅ **关键** —— free-form 靠 adaptive-K 已被证伪,只能门控保住 1× |

## 缺的 4 块(必须补,否则不完整)
1. **Verifier / Verify-Contract ⭐核心** —— target 一次前向 + **树注意力**验证 + accept/trim。**双模契约**:greedy **byte-identical**(你已认证的 ADR-039)*或* sampling **distribution-lossless**(TokenTiming 那种)。这是**正确性的根**,也是通用性的机制(在 target 自己的 token 空间里验证)。你的树里只有 Target Adapter,但 Verifier 是心脏,得单列。
2. **Router / Scheduler** —— per-step 决定**用哪些源 + 草稿长度 k + 是否合成候选树**。Profiler/Adaptation 是它的输入,它才是决策点。
3. **HW-Tier Gate** —— 按**硬件带宽**准入源:瓶颈设备**根本不实例化**模型源(除非实测≥1×)。一套抽象、两档(端上/桌面)。
4. **Candidate Tree Merge** —— 多源候选合成**一棵树**,一次前向验证(SpecInfer 式),而不是串行试每个源。

## 重整后的分层树
```
Universal Draft Layer
 ├─ Sources (pluggable · HW/workload-gated)
 │   ├─ Prompt Lookup Drafter      [model-free · on-device ✅]
 │   ├─ N-gram/Suffix Cache Drafter [model-free · cross-turn ✅]
 │   └─ Small Mamba Drafter         [model · desktop ✅ / on-device gated+measured ⚠️]
 ├─ Tokenizer Bridge (= TokenTiming) [cross-vocab for model sources · desktop tier]
 ├─ Router / Scheduler               [picks sources + k + tree]
 │   ├─ Acceptance Profiler          [per source/target/workload]
 │   ├─ Online User Adaptation       [bandit + session-growing cache]
 │   └─ HW-Tier Gate                 [admit sources by bandwidth]
 ├─ Candidate Tree Merge             [multi-source → one tree]
 ├─ Verifier / Verify-Contract  ⭐    [target 1-fwd + tree-attn; greedy byte-id OR sampling-lossless]
 ├─ Target Adapter                   [any big model: tokenizer/forward/KV]
 └─ Fallback Controller              [no signal → plain AR @ 1.0×]
```

## 一句话定性
你的 8 个组件**全部成立**,只是要补上 **Verifier(心脏)、Router(决策点)、HW-Tier-Gate(两档现实)、Tree-Merge(多源合一验证)**。最妙的是 **Small Mamba Drafter** —— 它把你的 Mamba 积累接进了加速器,而且 Mamba 的 O(1) state 让它成为**端上最有希望的那个模型源**(但仍要实测过带宽门)。

要我把这棵重整后的树写成**正式 substrate spec** 吗?—— 含:每个组件的接口签名、Router 的 bandit 策略、Verify-Contract 的双模(greedy/sampling)定义、HW-Tier-Gate 的准入规则、端上 MVP(prompt-lookup + 后缀自动机 + fallback)、桌面档(+Small Mamba + TokenTiming)、以及对抗式批判(bridge 损耗、bandit 收敛、tree-verify kernel 在 MLX 的可行性)。写完直接是可 build 的蓝图。

## 🟦 [2026-06-18 12:40:14] 操作者

plan 一下 三思

## 🟦 [2026-06-18 13:17:55] 操作者

先 完成 plan 吧 我来想想办法

## 🟦 [2026-06-18 13:18:00] 操作者

[Request interrupted by user]
