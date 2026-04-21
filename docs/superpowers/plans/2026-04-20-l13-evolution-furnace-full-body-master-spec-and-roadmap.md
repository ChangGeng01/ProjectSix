# L13 Evolution Furnace Full-Body Master Spec And Roadmap Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn `L13` from a `target-state whitepaper + Stage 1 spine` story into a formal repo-real program by adding the full-body master spec, adding the staged roadmap, and upgrading the repository entrypoints so `WP13` now points to the full-body program instead of only the Stage 1 governance spine.

**Architecture:** Keep the existing `v∞` whitepaper and `Stage 1` design/plan intact. Add a new `master spec` and a new `roadmap` as the repo-real authority bridge between the whitepaper and future stage designs. Then update `README`, the execution truth sources, the completion matrix, and the `WP13` blueprint wording so the repository consistently says: `Stage 1` is landed, `full body` is the formal next line, and `WP15` remains out of scope for this documentation pass.

**Tech Stack:** Markdown docs, Swift blueprint metadata in `BASAdmin`, Swift Testing/XCTest for blueprint verification, `rg`, `swift test`.

---

### Task 1: Publish The Full-Body Master Spec

**Files:**
- Source: `/Users/changgeng/Project/Project06/Project06/docs/superpowers/specs/2026-04-20-l13-evolution-furnace-full-body-master-design.md`
- Create: `/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_L13_EVOLUTION_FURNACE_FULL_BODY_MASTER_SPEC.md`

- [ ] **Step 1: Verify the destination file does not already exist**

Run:

```bash
test ! -f /Users/changgeng/Project/Project06/Project06/docs/EBRAIN_L13_EVOLUTION_FURNACE_FULL_BODY_MASTER_SPEC.md && echo "MISSING"
```

Expected:

```text
MISSING
```

- [ ] **Step 2: Draft the published master spec from the approved design**

Write the file with the same approved structure, but convert the title and opening status declaration into repo-facing language:

```md
# 第13层：蜕变炉｜完全体总设计 Master Spec

> 状态声明
>
> 本文是 `L13 蜕变炉` 的 repo-real `full-body master spec`。
>
> 它位于 [EBRAIN_L13_EVOLUTION_FURNACE_TARGET_VINF.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_L13_EVOLUTION_FURNACE_TARGET_VINF.md) 与具体 stage design / implementation plan 之间，负责定义：
>
> - `L13` 完全体的器官域
> - `L13` 与 `L8 / L9 / L10 / L11 / L12 / L14` 的升级接口
> - `Stage 1 -> Stage 5` 的 repo-real 演进骨架
>
> 本文不宣称当前仓库已经拥有 full-body runtime。当前已落地范围仍以 `Stage 1 governance spine` 为准。
```

Then carry over the approved sections from the design doc into repo-facing headings:

```md
## 1. 问题定义
## 2. 当前仓库真相
## 3. 完全体器官域
## 4. 候选家族模型
## 5. 跨层接口织体
## 6. 迁移策略
## 7. 操作面策略
## 8. 阶段总路线
## 9. repo 入口升级要求
## 10. 风险与边界
```

- [ ] **Step 3: Verify the published spec has the expected sections and status wording**

Run:

```bash
rg -n "^# |^## |状态声明|Stage 1 governance spine|WP15" /Users/changgeng/Project/Project06/Project06/docs/EBRAIN_L13_EVOLUTION_FURNACE_FULL_BODY_MASTER_SPEC.md
```

Expected:

```text
1:# 第13层：蜕变炉｜完全体总设计 Master Spec
3:> 状态声明
...
...:当前已落地范围仍以 `Stage 1 governance spine` 为准。
...:## 8. 阶段总路线
...:本文不覆盖：
...:- `WP15` ...
```

- [ ] **Step 4: Sanity-check for placeholders or scope drift**

Run:

```bash
rg -n "TODO|TBD|placeholder|待定|以后再说" /Users/changgeng/Project/Project06/Project06/docs/EBRAIN_L13_EVOLUTION_FURNACE_FULL_BODY_MASTER_SPEC.md
```

Expected:

```text
[no output]
```

- [ ] **Step 5: Commit the published master spec**

Run:

```bash
git add /Users/changgeng/Project/Project06/Project06/docs/EBRAIN_L13_EVOLUTION_FURNACE_FULL_BODY_MASTER_SPEC.md
git commit -m "docs: add l13 full-body master spec"
```

Expected:

```text
[branch-name ...] docs: add l13 full-body master spec
 1 file changed, ...
```

### Task 2: Publish The Full-Body Roadmap

**Files:**
- Source: `/Users/changgeng/Project/Project06/Project06/docs/superpowers/specs/2026-04-20-l13-evolution-furnace-full-body-master-design.md`
- Reference: `/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_L9_DREAM_LOOP_ROADMAP.md`
- Create: `/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_L13_EVOLUTION_FURNACE_FULL_BODY_ROADMAP.md`

- [ ] **Step 1: Verify the roadmap file does not already exist**

Run:

```bash
test ! -f /Users/changgeng/Project/Project06/Project06/docs/EBRAIN_L13_EVOLUTION_FURNACE_FULL_BODY_ROADMAP.md && echo "MISSING"
```

Expected:

```text
MISSING
```

- [ ] **Step 2: Write the roadmap in the same style as the other layer roadmaps**

Start with a status declaration like this:

```md
# 第13层：蜕变炉｜Full-Body Evolution Furnace 总路线

> 状态声明
>
> 本路线图描述的是 `L13 蜕变炉` 从当前仓库 `Stage 1 governance spine / Alpha evolution layer` 演进到 `full-body evolution furnace` 的 repo-real 路线。
>
> 当前仓库真相仍以 [EBRAIN_13L_EXECUTION_V12.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_13L_EXECUTION_V12.md)、[EBRAIN_13L_COMPLETION_MATRIX.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_13L_COMPLETION_MATRIX.md) 与 [EBRAIN_13L_APPENDICES_V12.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_13L_APPENDICES_V12.md) 为准。
>
> 本文不宣称当前仓库已经拥有 `Shadow Trial Theater`、`Version Arboretum`、`Retraction Furnace`、runtime `Workflow / Guard / Bias / Export` families 或完整 `L8-L14 evolution interface fabric`。
```

Then structure the roadmap around the five phases approved in the design:

```md
## 1. 这份路线图解决什么问题
## 2. 固定执行口径
## 3. 设计原则
## 4. 当前仓库锚点
## 5. 完全体器官域与当前主链的映射
## 6. Phase 1: Governance Spine
## 7. Phase 2: Candidate Nursery Activation
## 8. Phase 3: Shadow Trial Theater
## 9. Phase 4: Version Arboretum + Retraction Furnace
## 10. Phase 5: Cross-Layer Closure + Operator Surface
## 11. 执行红线
```

- [ ] **Step 3: Make the roadmap stages concrete and acceptance-oriented**

Each phase section should include:

```md
### 目标
- ...

### 当前与目标的差距
- ...

### 本阶段新增能力
- ...

### 验收信号
- ...
```

For `Phase 2`, explicitly name the candidate families:

```md
- `WorkflowCandidate`
- `GuardTemplateCandidate`
- `BiasRecord`
- `LearningExportBundle`
- `RiskPatternCandidate`
```

- [ ] **Step 4: Verify the roadmap exposes all five phases and preserves repo-real honesty**

Run:

```bash
rg -n "Phase 1|Phase 2|Phase 3|Phase 4|Phase 5|Alpha evolution layer|不宣称当前仓库已经拥有" /Users/changgeng/Project/Project06/Project06/docs/EBRAIN_L13_EVOLUTION_FURNACE_FULL_BODY_ROADMAP.md
```

Expected:

```text
...:Alpha evolution layer
...:## 6. Phase 1: Governance Spine
...:## 7. Phase 2: Candidate Nursery Activation
...:## 8. Phase 3: Shadow Trial Theater
...:## 9. Phase 4: Version Arboretum + Retraction Furnace
...:## 10. Phase 5: Cross-Layer Closure + Operator Surface
```

- [ ] **Step 5: Commit the roadmap**

Run:

```bash
git add /Users/changgeng/Project/Project06/Project06/docs/EBRAIN_L13_EVOLUTION_FURNACE_FULL_BODY_ROADMAP.md
git commit -m "docs: add l13 full-body roadmap"
```

Expected:

```text
[branch-name ...] docs: add l13 full-body roadmap
 1 file changed, ...
```

### Task 3: Upgrade The Repository Truth Sources

**Files:**
- Modify: `/Users/changgeng/Project/Project06/Project06/README.md`
- Modify: `/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_13L_EXECUTION_V12.md`
- Modify: `/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_13L_APPENDICES_V12.md`
- Modify: `/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_13L_COMPLETION_MATRIX.md`

- [ ] **Step 1: Capture the current L13 references before editing**

Run:

```bash
rg -n "L13|蜕变炉|governance spine|target-state whitepaper" \
  /Users/changgeng/Project/Project06/Project06/README.md \
  /Users/changgeng/Project/Project06/Project06/docs/EBRAIN_13L_EXECUTION_V12.md \
  /Users/changgeng/Project/Project06/Project06/docs/EBRAIN_13L_APPENDICES_V12.md \
  /Users/changgeng/Project/Project06/Project06/docs/EBRAIN_13L_COMPLETION_MATRIX.md
```

Expected:

```text
... current L13 references printed from all four files ...
```

- [ ] **Step 2: Expand the README note so it points to four L13 documents instead of only the whitepaper and Stage 1**

Replace the current `L13` bullet with wording in this shape:

```md
- The `L13` evolution-furnace documents now live in [docs/EBRAIN_L13_EVOLUTION_FURNACE_TARGET_VINF.md](...), [docs/EBRAIN_L13_EVOLUTION_FURNACE_FULL_BODY_MASTER_SPEC.md](...), [docs/EBRAIN_L13_EVOLUTION_FURNACE_FULL_BODY_ROADMAP.md](...), and [docs/superpowers/specs/2026-04-19-l13-evolution-governance-spine-stage-1-design.md](...). The first is the `target-state` whitepaper; the second is the repo-real `full-body master spec`; the third is the staged roadmap; the fourth captures the already-landed `Stage 1 governance spine`. None of them changes the current repository truth that `L13` remains an `Alpha` evolution layer whose only shipped runtime body today is the governed Stage 1 spine.
```

- [ ] **Step 3: Update the execution blueprint and appendices notes to distinguish whitepaper, master spec, roadmap, and Stage 1**

Insert wording in both docs that follows this pattern:

```md
若需查看 `L13 蜕变炉` 的理想完全体定义、repo-real 完全体总设计与阶段路线，请参考

- [EBRAIN_L13_EVOLUTION_FURNACE_TARGET_VINF.md](...)
- [EBRAIN_L13_EVOLUTION_FURNACE_FULL_BODY_MASTER_SPEC.md](...)
- [EBRAIN_L13_EVOLUTION_FURNACE_FULL_BODY_ROADMAP.md](...)

其中：

- `target_v∞` 只定义理想体
- `master spec` 定义 repo-real 完全体结构
- `roadmap` 定义 `Stage 1 -> Stage 5` 路线

这三者都不改变本文对当前 `L13 = Stage 1 governance spine + Alpha evolution layer` 的执行口径。
```

- [ ] **Step 4: Update the completion matrix intro and L13 row without overstating current runtime**

Keep the intro honest, but expand it to mention both new docs:

```md
`L13` 的目标态白皮书、repo-real 完全体总设计与阶段路线，现见

- [EBRAIN_L13_EVOLUTION_FURNACE_TARGET_VINF.md](...)
- [EBRAIN_L13_EVOLUTION_FURNACE_FULL_BODY_MASTER_SPEC.md](...)
- [EBRAIN_L13_EVOLUTION_FURNACE_FULL_BODY_ROADMAP.md](...)

它们不改变本矩阵对当前仓库现实状态的表述。
```

Then adjust the `仍缺的关键口` column for `L13` to end in the full-body language:

```md
专门 shadow-trial dashboard、`workflow / guard / bias / export / risk-pattern` 候选族的 runtime 行为化、`Version Arboretum / Retraction Furnace`、cross-layer `L8-L14 evolution interface fabric`、future furnace workbench、训练资产闭环
```

- [ ] **Step 5: Verify every truth source now references the master spec and roadmap**

Run:

```bash
rg -n "FULL_BODY_MASTER_SPEC|FULL_BODY_ROADMAP|Stage 1 governance spine|Alpha evolution layer" \
  /Users/changgeng/Project/Project06/Project06/README.md \
  /Users/changgeng/Project/Project06/Project06/docs/EBRAIN_13L_EXECUTION_V12.md \
  /Users/changgeng/Project/Project06/Project06/docs/EBRAIN_13L_APPENDICES_V12.md \
  /Users/changgeng/Project/Project06/Project06/docs/EBRAIN_13L_COMPLETION_MATRIX.md
```

Expected:

```text
... each file prints at least one `FULL_BODY_MASTER_SPEC` and one `FULL_BODY_ROADMAP` reference ...
... each file still contains `Stage 1 governance spine` or equivalent `Alpha evolution layer` honesty wording ...
```

- [ ] **Step 6: Commit the entrypoint updates**

Run:

```bash
git add \
  /Users/changgeng/Project/Project06/Project06/README.md \
  /Users/changgeng/Project/Project06/Project06/docs/EBRAIN_13L_EXECUTION_V12.md \
  /Users/changgeng/Project/Project06/Project06/docs/EBRAIN_13L_APPENDICES_V12.md \
  /Users/changgeng/Project/Project06/Project06/docs/EBRAIN_13L_COMPLETION_MATRIX.md
git commit -m "docs: wire l13 full-body docs into repo entrypoints"
```

Expected:

```text
[branch-name ...] docs: wire l13 full-body docs into repo entrypoints
 4 files changed, ...
```

### Task 4: Upgrade WP13 Blueprint Language And Coverage

**Files:**
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASAdmin/ThirteenLayerProgramBlueprintCore.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASEBrainProgramBlueprintTests.swift`

- [ ] **Step 1: Add a failing blueprint assertion for the new WP13 program wording**

Extend `BASEBrainProgramBlueprintTests.swift` with an assertion in the existing blueprint suite:

```swift
let wp13 = blueprint.workPackages.first(where: { $0.id == "WP13" })

#expect(wp13?.title == "蜕变炉")
#expect(wp13?.description.contains("full-body evolution furnace program") == true)
#expect(wp13?.description.contains("Stage 1 governance spine") == true)
```

Run:

```bash
swift test --package-path /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate --filter BASEBrainProgramBlueprintTests
```

Expected:

```text
FAIL ... missing "full-body evolution furnace program" wording for WP13
```

- [ ] **Step 2: Update the WP13 blueprint entry to describe the full-body program with staged rollout**

Replace the existing `wp("WP13", ...)` description with wording shaped like this:

```swift
wp(
    "WP13",
    "蜕变炉",
    "Implement the full-body evolution furnace program with staged rollout: keep the landed Stage 1 governed spine, then expand candidate nurseries, shadow-trial theater, version/retraction systems, and cross-layer L8-L14 evolution interfaces without breaking the current review-gated checkpoint chain.",
    [.evolution],
    .currentRepository,
    .second,
    ...
)
```

Also update the milestone / success wording so it no longer implies `Stage 1` is the end state:

```swift
["Stage 1 spine remains stable", "Full-body roadmap is the active next line", "Cold-memory writes and promotion stay blocked without review or seal"]
```

- [ ] **Step 3: Re-run the focused blueprint test until it passes**

Run:

```bash
swift test --package-path /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate --filter BASEBrainProgramBlueprintTests
```

Expected:

```text
... BASEBrainProgramBlueprintTests passed ...
```

- [ ] **Step 4: Commit the blueprint wording upgrade**

Run:

```bash
git add \
  /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASAdmin/ThirteenLayerProgramBlueprintCore.swift \
  /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASEBrainProgramBlueprintTests.swift
git commit -m "docs: upgrade wp13 blueprint to full-body program"
```

Expected:

```text
[branch-name ...] docs: upgrade wp13 blueprint to full-body program
 2 files changed, ...
```

### Task 5: Verification And Final Consistency Sweep

**Files:**
- No additional code changes expected.

- [ ] **Step 1: Run the focused package verification**

Run:

```bash
swift test --package-path /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate --filter 'BASEBrainProgramBlueprintTests|BASEBrainSchemaGovernanceRegistryTests'
```

Expected:

```text
... 0 failures ...
```

- [ ] **Step 2: Verify the new L13 document stack is wired everywhere**

Run:

```bash
rg -n "EBRAIN_L13_EVOLUTION_FURNACE_(TARGET_VINF|FULL_BODY_MASTER_SPEC|FULL_BODY_ROADMAP)" \
  /Users/changgeng/Project/Project06/Project06/README.md \
  /Users/changgeng/Project/Project06/Project06/docs/EBRAIN_13L_EXECUTION_V12.md \
  /Users/changgeng/Project/Project06/Project06/docs/EBRAIN_13L_APPENDICES_V12.md \
  /Users/changgeng/Project/Project06/Project06/docs/EBRAIN_13L_COMPLETION_MATRIX.md \
  /Users/changgeng/Project/Project06/Project06/docs/EBRAIN_L13_EVOLUTION_FURNACE_FULL_BODY_MASTER_SPEC.md \
  /Users/changgeng/Project/Project06/Project06/docs/EBRAIN_L13_EVOLUTION_FURNACE_FULL_BODY_ROADMAP.md
```

Expected:

```text
... all six files print matching references ...
```

- [ ] **Step 3: Review the final diff for scope discipline**

Run:

```bash
git diff -- \
  /Users/changgeng/Project/Project06/Project06/README.md \
  /Users/changgeng/Project/Project06/Project06/docs/EBRAIN_13L_EXECUTION_V12.md \
  /Users/changgeng/Project/Project06/Project06/docs/EBRAIN_13L_APPENDICES_V12.md \
  /Users/changgeng/Project/Project06/Project06/docs/EBRAIN_13L_COMPLETION_MATRIX.md \
  /Users/changgeng/Project/Project06/Project06/docs/EBRAIN_L13_EVOLUTION_FURNACE_FULL_BODY_MASTER_SPEC.md \
  /Users/changgeng/Project/Project06/Project06/docs/EBRAIN_L13_EVOLUTION_FURNACE_FULL_BODY_ROADMAP.md \
  /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASAdmin/ThirteenLayerProgramBlueprintCore.swift \
  /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASEBrainProgramBlueprintTests.swift
```

Expected:

```text
... only docs plus WP13 blueprint/test changes ...
```

- [ ] **Step 4: Write the execution handoff summary**

Record a short final summary in the implementation notes or commit message body with these points:

```text
- Added L13 full-body master spec
- Added L13 full-body roadmap
- Upgraded repo truth sources to reference the new docs
- Upgraded WP13 from Stage 1-only wording to full-body staged program wording
- Preserved current-repo honesty: Stage 1 landed, full-body not yet shipped
```
