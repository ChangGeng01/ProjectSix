# Archive/ — substrate file archive (not compiled)

This directory holds files that have been deactivated from the live substrate
compilation but preserved per the discipline **「依旧 不删除 只 comment」**
(never delete, only comment-out / archive).

## Why this directory exists

The earlier 「不删除 只 comment」 approach wrapped deactivated bodies in
`#if false ... #endif` inside the source tree。 That worked but left ~7,000 LOC
of dead-but-syntactically-valid Swift inside `Sources/` and `Tests/`, polluting
file listings, IDE search results, and grep。

User directive 2026-05-20「不要 删除。创建个 文件夹 把 不需要的文件 都转移
进 文件夹」 — move deactivated FILES (not just bodies) into this directory。
SPM's path-based discovery ignores anything outside the declared `Sources/<Target>`
and `Tests/<TestTarget>` paths, so files here are completely invisible to the
compiler。 No `#if false` wrapping needed once relocated。

## Directory layout

```
Archive/
└── Deactivated/
    ├── Tests/
    │   └── BehavioralAISubstrateTests/
    │       ├── BASChapter###MatrixScorecardTests.swift  (chapter 七百五十七)
    │       ├── BASChapter###DashboardTests.swift        (chapter 七百五十七)
    │       ├── BASChapter###EntropyDoctrineTests.swift  (chapter 七百五十二)
    │       └── BASChapter753BatchedReducerTests.swift   (chapter 七百五十七)
    └── Sources/
        └── BASRuntimeCore/
            └── BASChapter###EntropyDoctrine.swift       (chapter 七百五十二)
```

## File counts per archive wave

| Chapter | Wave | Files | Notes |
|---|---|---:|---|
| 七百五十二 第二刀 | doctrine reduction | 38 | Per-chapter doctrine test files |
| 七百五十二 第三刀 | doctrine reduction | 61 | Thin-forwarder doctrine types |
| 七百五十七 第一刀 | scorecard cleanup | 36 | Print-only matrix/dashboard tests |
| 七百五十七 第一刀 | L8 LOSS removal | 1 | Batched reducer test (0.82× regression) |
| **Total** | | **136** | |

## Restoration

A file under `Archive/Deactivated/Tests/...` can be restored by `git mv`-ing it
back to `Tests/BehavioralAISubstrateTests/`。 The compile-conditional `#if false`
wrapper inside the file body (if any) can be removed at the same time。

## What NOT to put here

- Files with ANY load-bearing code path active (use `#if false` wrap inside
  the file body for partial deactivation, not file relocation)
- Active doctrine pins still referenced by the registry
- Test files whose assertions are still meaningful for substrate invariants

## Discipline pins held

- **「依旧 不删除 只 comment」** — files preserved verbatim in repo history,
  recoverable via `git mv`
- **「不要 计算 commented 代码」** — files here are invisible to SPM and to
  the comment-aware LOC counter,reported truthfully as inactive
- **「不要 删除」** (chapter 七百五十七 第二刀) — relocation,not deletion
