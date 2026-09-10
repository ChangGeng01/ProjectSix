# CONTRIBUTING.md — BehavioralAISubstrate

Operational guide for contributors / forks。 The substrate is private
+ pre-1.0; this file documents the discipline + tooling that the
trajectory has accumulated through chapters 一 → 八百二十九。

---

## TL;DR — what every commit must hold

1. **Build clean** (`swift build` returns ok, no warnings escalated)。
2. **Test sweep clean** (`swift test` — 13,400+ tests / 0 failures
   target on Apple Silicon)。
3. **3 CI gates pass** — install the pre-commit hook (one-line setup
   below) and they run automatically。
4. **Doctrine pins held** — see「Doctrine pins」 section。
5. **Conventional Commit body** — see「Commit format」 section。

---

## One-time setup

```bash
# Install the pre-commit hook (runs the 3 CI gates before each commit)
git config core.hooksPath .githooks
```

Skip (one-off): `git commit --no-verify`
Skip permanently: `git config core.hooksPath ""`

---

## 3 CI gates (chapter 八百二十三-八百二十九)

| Script | Enforces |
|---|---|
| `scripts/check_god_files.sh` | Per-file LOC ceilings (default warn 1500 / err 3000); pinned overrides for known structurally-large files (e.g. composition roots) |
| `scripts/check_sdk_import_boundaries.sh` | Substrate core modules (BASRuntimeCore/BASMemory/BASPolicy/etc.) MUST NOT import any SDK consumer module (BASHostKit/BASAppleAdapters/BASBrainCLI/etc.) |
| `scripts/check_substrate_residuals.sh` | TODO/FIXME/XXX/HACK marker density + `print()` in production (excluding legitimate CLI consumers) + force-unwrap density (informational) |

Run manually:

```bash
bash scripts/pre-commit-gates.sh    # all 3 chained
# or individually:
bash scripts/check_god_files.sh
bash scripts/check_sdk_import_boundaries.sh
bash scripts/check_substrate_residuals.sh
```

---

## Doctrine pins

| Pin | What it means |
|---|---|
| 不变量 #1 / #2 / #3 | Substrate-wide invariants that must hold every commit (see early chapters' commit bodies for derivation) |
| 红线 7 | Additive on destination; flag-gated at consumer |
| ADR-014 OPT-IN | New Rust/SQLite paths default OFF; hosts opt in via flags |
| 不要 删除 只能 comment | Never delete code; `// ` comment-out or wrap in `#if false` |
| 不要 的 部分 都 archive | Updated chapter 八百二十七: dormant blocks MOVE to `Archive/Deactivated/` as `.txt`, not just commented inside source |
| 不要 json 可以的话 就 sql | Typed SQL columns preferred over JSON blobs for any persistent data |
| 整体 性能 效果 一定要 更好 | Optimize the hot path (e.g. CryptoKit AMX SHA-256 default over Rust software SHA-256) |
| 亏的不要硬上 | Only flip a Rust path to default when 5-axis perf measurement justifies it; otherwise stay opt-in |
| 多做比较 | Always measure before deciding; 5-axis comparison framework lives in `BASCrossLanguagePerfHarness` (chapter 七百七十八) |

---

## Commit format

Conventional-Commit with chapter pin in subject + body details:

```
feat(chapter 八百##  / M####-M####): brief description (N knives batched)

Longer body explaining what the chapter ships, doctrine pins held,
verification (test counts, gates passed), and references to prior
chapters。

Co-Authored-By: ...
```

Subject types: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`, `perf`, `ci`。

---

## Archive discipline

When code becomes dormant (functionality removed but content preserved
for restoration):

1. **Don't delete from git history。** All previous code stays
   recoverable via `git log` + reverse-`git mv`。
2. **For inline blocks** (commented-out within a source file): if
   > 50 LOC, extract to `Archive/Deactivated/<rel_path>_LegacyBody.txt`
   with an explanatory header documenting where it came from and how
   to restore。 Leave a one-line pointer in the source file。
3. **For whole files**: `git mv` the file into `Archive/Deactivated/`。
4. **.txt extension** ensures Swift Package Manager does NOT compile
   archived content。

See chapters 八百二十七 + 八百二十八 for ~43K LOC of doctrine
archived via this pattern。

---

## Release process

1. Verify branch tip green: `swift test && cd Cargo && cargo test --workspace`
2. All 3 CI gates pass: `bash scripts/pre-commit-gates.sh`
3. CHANGELOG.md `[Unreleased]` section promoted to `[X.Y.Z]` with
   today's date
4. `git tag -a vX.Y.Z -m "release vX.Y.Z"` + `git push --tags`
5. Update `BRANCH_SUMMARY.md` with the new chapter range

---

## Naming conventions

- `BAS<Layer><Concept>` for substrate types (e.g。 `BASMemoryAtomStore`)
- `EBrain<Concept>` for HostKit composition types (e.g。
  `EBrainRuntimeCoordinator`)
- `BASRouted<Concept>` for opt-in routed seams (e.g。
  `BASRoutedPresenceFusion`)
- `BASInMemory<Concept>Store` + `BASSQLite<Concept>Store` for
  storage adapter pairs (chapter 七百九十五 pattern)
- `BASChapter###<Concept>Doctrine.swift` — historical chapter pin
  forwarders (chapter 466 era); new chapters do NOT add these
  files (registry is dormant per chapter 八百二十五 — substitute
  discipline is CHANGELOG + Conventional-Commit body + per-file
  MARK comments)

---

## Related docs

- `README.md` — substrate overview + integration
- `CHANGELOG.md` — release history
- `MIGRATING.md` — version-to-version migration notes
- `VERSIONING.md` — semver policy
- `INTEGRATION.md` — host integration guide
- `BRANCH_SUMMARY.md` — chapter trajectory (1 → 八百二十九)
- `Archive/README.md` — archive directory layout + restoration
