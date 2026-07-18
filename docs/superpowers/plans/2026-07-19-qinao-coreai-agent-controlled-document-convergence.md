# Qinao Core AI Agent Controlled-Document Convergence Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convert the approved Qinao Core AI/Agent/context/memory/RSI addendum into one non-vacuous W0 controlled-document and gate closure, so the existing W1–W6 domain plans can be executed without contradictory authority, wave, or release semantics.

**Architecture:** This is a W0 plan-of-plans, not a seventh domain implementation plan and not a production runtime change. It atomically reconciles the existing seven controlled documents, maps every adopted decision onto an existing Owner Ledger owner, and adds one thin wave-gate orchestrator that composes the repository's existing owner, review, non-empty Swift-filter, platform-proof, and static checkers. The six existing implementation-plan documents—one convergence master plus five domain plans—remain the only W1–W6 execution units.

**Tech Stack:** Markdown, canonical JSON, Python 3 standard library and `unittest`, Git candidate-index/tree plumbing, Swift Package Manager test discovery, Xcode 27/iOS 27 platform evidence.

## Global Constraints

- The minimum iOS deployment target is exactly `27.0` for every workspace-owned iOS package/app/extension slice; vendored package manifests remain upstream-owned.
- Architecture cardinality remains exactly `14 Semantic LayerCores / 4 Physical Kernels / 4 bounded ControlRings / 7 orthogonal planes`.
- The exact seven controlled documents are the architecture design, the convergence master, and five domain plans listed below. The 2026-07-19 addendum, the K3 addendum, the recovery companion, Xcode release-build policy, this plan, evidence, and gate manifests are inputs or proof surfaces—not additional architecture authorities.
- Qinao SDK remains model-neutral. Concrete Qwen, MiniCPM, Granite, Core AI, MLX, and FoundationModels packages stay outside the SDK and depend inward through value-only Provider/Proposal contracts.
- Core AI-only applies to the Qwen/MiniCPM/Granite portfolio after sealed W6 cutover; it does not force an evidence-losing migration of the allowlisted Core ML context-classifier microhead.
- The reviewed source candidates are full commits `Qwen/Qwen3.5-4B@851bf6e806efd8d0a36b00ddf55e13ccb7b8cd0a`, `openbmb/MiniCPM5-1B@4e9de7a0778dc1c362e983e6858f0e77542cbdca`, `openbmb/MiniCPM-V-4.6@8169864629825dc1d755a5aa1cd8b5935dcbc83f`, and `ibm-granite/granite-embedding-97m-multilingual-r2@835ad14087e140460703cf0fae09f97d469d65c2`; they are source candidates, not certification. W1 remains blocked until the exact selected files/LFS-or-Xet objects and digests are sealed. The initial Qwen variant is independently named `qwen3.5-4b-text-only/no-mtp-certified`: `vision=false` and `mtpEnabled=false` are certification flags, not claims that the source lacks vision/MTP material. Enabling either requires a distinct signed material/profile/StateABI/plan and independent certification.
- No task may introduce `ModelPromotionStore`, a second model registry, an asset/specialization/cache authority, a shared recovery authority/store, a second deployment state machine, or an independent `BASStateCommitStore`.
- `ModelMaterialManifestArtifactID` is the sole Core AI evolution of canonical `bundleDigest`; pointer paths, bookmarks, and caches never select model identity.
- W1 declares immutable model-neutral values only. W2 owns K3 durability and recovery. W3 remains pre-physical. W4 keeps the incumbent MLX path as the only production caller while Core AI/AFM remain shadow/device-validation. W5 keeps production publication disabled. W6 alone performs the two deployment joins.
- E4 is immutable candidate evidence, not deployment authority. Join 1 is `E4 + separately sealed canary tree/cohort -> canary deployment -> immutable E5`; Join 2 is `E5 + separately sealed full Release tree -> full production cutover`.
- Runtime revocation order is `L14 decision -> K3 RevocationFenceReceipt -> K4 revoke`; ingress, queue, chunk, claim, and seal revalidate the same revocation generation.
- A Provider call, publication, or effect that may have crossed its boundary is query/reconcile/seal-only. It is never reinvoked, republished, or redispatched.
- The current `coreai-torch 0.4.0` `.aimodel` outputs are denied historical evidence on iOS 27 beta 2 or later; exact compatible reconversion and full recertification are mandatory.
- Cold 40 token/s and sustained 30 token/s remain workload-qualified optional claims, never W6 architecture-completion gates or product promises.
- Every negative source scan first proves that every input exists and that its scan set is non-empty, then uses the runner's standard-library UTF-8/regex scanner over the admitted candidate bytes. A decode/read/regex error is a gate error, never “no match.” Legacy shell gates that still use `rg` must separately distinguish status `0` (match), `1` (no match), and `2+` (gate error).
- Every Swift test filter is executed through `scripts/run_nonempty_swift_filter.py` with explicit `--require-suite`; raw `swift test --filter` is not an acceptance gate.
- Python gate tests use `python3 -m unittest`; Qinao gates do not depend on a locally installed `pytest`.
- Every normative shell block is fail-fast: execute it under `set -euo pipefail` even where repeated boilerplate is omitted from a displayed snippet. An expected failure is always wrapped as `if command; then exit 1; fi`; no later successful command may mask an earlier failure.
- Every Python invocation in baseline/certification shells and CI uses `PYTHONDONTWRITEBYTECODE=1` (or `python3 -B`), every Swift gate uses its external private scratch path, and the candidate gate rejects even ignored untracked inputs. No checker may create an input under the candidate root while certifying it.
- This W0 plan changes no production Swift, Rust, C, C++, Metal, SQL schema, model asset, runtime default, or deployment route.
- The current shared worktree contains pre-existing staged, unstaged, and untracked W0 work. Execution must use an isolated clean worktree made from a reviewed committed descendant of `a82a7bb0b4e4f5680117df3b92593fa90c9d85a3`; never stage or commit unrelated work from the current dirty worktree.

---

## Controlled Document Inventory

The machine and human review inventory is exactly:

1. `docs/superpowers/specs/2026-07-14-iphone-air-future-apple-silicon-architecture-design.md`
2. `docs/superpowers/plans/2026-07-15-iphone-air-architecture-convergence-master.md`
3. `docs/superpowers/plans/2026-07-15-iphone-air-contracts-layercell.md`
4. `docs/superpowers/plans/2026-07-15-iphone-air-silicon-execution-spine.md`
5. `docs/superpowers/plans/2026-07-15-iphone-air-semantic-statelake-context.md`
6. `docs/superpowers/plans/2026-07-15-iphone-air-sovereign-release-effects.md`
7. `docs/superpowers/plans/2026-07-15-iphone-air-runtime-replay-certification.md`

`scripts/check_qinao_owner_ledger.py::EXPECTED_CONTROLLED_DOCUMENTS` is the executable mirror. The Owner Ledger remains exactly `29 owners / 14 M allowlist entries / 14 create permissions / 7 controlled documents` unless a separately reviewed CreateGate amendment proves a real missing production owner.

## File Responsibility Map

### Files created by this plan

- `scripts/check_qinao_preliminary_k4_source.py` and `scripts/test_check_qinao_preliminary_k4_source.py` — exact staged-blob privacy/inventory gate for the one-time preliminary-source extraction.
- `scripts/fixtures/qinao-k4-platform-probe/**` — privacy-clean isolated proof source migrated out of the immutable preliminary observation tree.
- `scripts/qinao_wave_gates_v1.json` — declarative, non-authoritative inventory of exact paths, static checkers, negative scans, and required Swift suites by introduction wave.
- `scripts/run_qinao_wave_gate.py` — thin allowlisted orchestrator; it validates the manifest and delegates to existing checkers without executing arbitrary manifest-provided shell.
- `scripts/test_run_qinao_wave_gate.py` — mutation tests for missing paths, empty globs, decode/read errors, deleted suites, unknown waves, command drift, index-flag/blob drift, and dirty/non-detached W6 candidates.
- `docs/superpowers/specs/qinao-apple27-release-platform-policy-v1.json` — closed-by-default reviewed allowlist for the exact official Xcode/device-iOS release-build pair; no filename alias is permitted.
- `scripts/capture_k4_platform_proof.py` and `scripts/test_capture_k4_platform_proof.py` — the sole deterministic producer and its failure/privacy/provenance tests for approved K4 evidence.
- `scripts/attest_k4_external_artifact.py` and `scripts/test_attest_k4_external_artifact.py` — independent, proof-only external signed-product/profile verifier; the repository checker remains read-only.

### Files modified by this plan

- `docs/superpowers/specs/2026-07-19-qinao-coreai-agent-context-memory-rsi-design.md` — correct the exact seven-document wording only; no architecture change.
- `docs/superpowers/specs/qinao-authority-corruption-recovery-v1.md` — make normativity conditional on the W0 owner map and eliminate any implication of a shared recovery authority/store.
- The exact seven controlled documents above — merge every adopted decision into its owning architecture/domain section.
- `docs/superpowers/specs/qinao-owner-ledger-v1.json` — update the existing owner rows, provenance base, work-package exit gates, and controlled-document required terms without changing owner cardinality.
- `scripts/check_qinao_owner_ledger.py` — update reviewed digests/term contracts and validate the recovery-owner map; reuse its current CreateGate and candidate-index binding.
- `scripts/test_check_qinao_owner_ledger.py` — mutation coverage for every new owner/wave/term invariant.
- `scripts/test_qinao_plan_remediation.py` — semantic cross-document tests for the four P0 contradictions and the exact seven-document inventory.
- `scripts/check_qinao_review_candidate.py` and `scripts/test_check_qinao_review_candidate.py` — bind the addenda, recovery contract, ledger, wave manifest/runner/tests, and seven controlled documents to unique regular stage-0 Git candidate blobs.
- `.github/workflows/test.yml` and `scripts/test_test_workflow_owner_ledger.py` — execute the wave gate continuously and prove its command/order cannot silently disappear.
- `scripts/run_nonempty_swift_filter.py` and `scripts/test_run_nonempty_swift_filter.py` — retain exact non-zero discovery/execution and add machine-readable listed/executed-count receipts.
- `scripts/check_k4_platform_proof.py` and `scripts/test_check_k4_platform_proof.py` — bind real release/profile/device/runtime provenance and reject beta self-labels, contradictory logs, or unbound identity projections.
- `scripts/fixtures/qinao-k4-platform-probe/{Host,Extension,Shared,...}` — privacy-clean, mutable-until-hardening isolated probe source; device-origin XPC and helper-private SQLite trace producer. It is tooling input, never production source or approved evidence.

### Existing production files referenced by the reconciled domain plans

No production file below is edited by this W0 plan. The controlled plans must name these incumbents rather than inventing substitutes:

| Responsibility | Existing/planned owner file | Planned wave |
|---|---|---|
| turn/branch/Provider/lease identities and strict ContextCapsule | `BehavioralAISubstrate/Sources/BASRuntimeCore/BASLowEntropyPrimitives.swift` | W1 |
| bounded RSI values, canonical progress, obligations, terminal receipt | `BehavioralAISubstrate/Sources/BASRuntimeCore/BASLayerCascadeRunner.swift` | W1/W2/W6 |
| model identity and material reference | `BehavioralAISubstrate/Sources/BASOrgan/BASModelCapabilityManifest.swift` | W1/W4 |
| per-call neural identity | `BehavioralAISubstrate/Sources/BASOrgan/BASLLMInvocationContract.swift` | W1/W4 |
| reasoning/StateLake value vocabulary | `BehavioralAISubstrate/Sources/BASRuntimeCore/BASSemanticStateLakeContracts.swift` | W1 planned CreateGate path |
| semantic DAG contract | `BehavioralAISubstrate/Sources/BASRuntimeCore/BASSemanticTurnDAG.swift` | W1 planned CreateGate path |
| K3 control nucleus | `BehavioralAISubstrate/Sources/BASRuntimeCore/BASSQLiteEventLogStorage.swift` | W2 |
| exact/FTS/dense/vector retrieval | `BASMemoryUsageTracker+ReplayAuditFTS.swift`, `BASRAGRetriever.swift`, `BASVectorIndex.swift`, `BASSQLiteVectorIndexStorage.swift` | W3 |
| context compiler | `BehavioralAISubstrate/Sources/BASOrchestration/ContextCompilerCore.swift` | W3 |
| sole embedding seam | `BehavioralAISubstrate/Sources/BASMemory/BASEmbeddingProvider.swift` | W3/W4 |
| execution plan/elector | `BehavioralAISubstrate/Sources/BASOrgan/BASExecutionPlan.swift`, `BASExecutionPlanElector.swift` | W4 |
| Core AI load/specialization/session mechanism | `BehavioralAISubstrate/Sources/BASAppleAdapters/BASCoreAIModelRunner.swift` and existing Core AI session files | W4 |
| AFM mechanism | `BASAppleAdapters/AppleFoundationOrganAdapter.swift` and `AppleFoundationOrganAdapter+Streaming.swift` | W4 |
| State/Processor ABI | `BehavioralAISubstrate/Sources/BASRuntimeCore/BASStateABI.swift` | W4 planned CreateGate path |
| one process memory/heavy owner | `BehavioralAISubstrate/Sources/BASLeaseLife/BASProcessMemoryLedger.swift` | W4 planned CreateGate path |
| response/publication/effect/K4 files | exact paths already enumerated in the sovereign plan's Tasks 1–6 | W5 |
| runtime DAG/replay/certification/cutover | exact paths already enumerated in the runtime plan's Tasks 1–7 | W6 |
| L12 NextQuestion value/selection | `BehavioralAISubstrate/Sources/BASOrchestration/EBrainL3L12RenderingCore.swift` | W1 value, W6 behavior |

The old `BASAgentRegistry`, `BASAgentRouter`, `BASAgentTurnDispatcher`, `BASAgentFabricRuntime`, `BASAgentRoundTable`, HostKit Agent Fabric pipeline, and `QinaoStateGraphBus` are migration/freeze inventory, not the new main/sub-Agent authority. `BASAppleAdapters/BASStateLakeReader.swift` is a neural-state reader, not SemanticStateLake.

---

### Task 0: Create a Clean, Isolated Execution Worktree

**Files:**
- Create: `scripts/check_qinao_preliminary_k4_source.py`
- Create: `scripts/test_check_qinao_preliminary_k4_source.py`
- Create by audited migration: `scripts/fixtures/qinao-k4-platform-probe/**`
- Sanitize/seal: `docs/superpowers/evidence/qinao-k4-platform-spike/{README.md,status.json}`
- Remove from the versioned candidate: `docs/superpowers/evidence/qinao-k4-platform-spike/spike/logs/**` and all private/generated raw observations named by Step 0.

**Interfaces:**
- Consumes: a reviewed committed descendant of `a82a7bb0b4e4f5680117df3b92593fa90c9d85a3` that contains this plan.
- Produces: one clean execution branch/worktree. All unrelated current dirty state remains byte-for-byte untouched; the only source-worktree exception is the separately reviewed, explicitly listed preliminary K4 evidence sanitation in Step 0.

- [ ] **Step 0: Seal a privacy-clean preliminary K4 source baseline**

The currently staged `docs/superpowers/evidence/qinao-k4-platform-spike/**` tree is not yet immutable evidence: it is absent from HEAD, several `spike/logs/**` files contain an absolute `/Users/...` workspace/account path, and a later log claims that such a path is absent. Do **not** commit or push that staged shape. Before creating the execution worktree, make one separately reviewed baseline commit that (a) migrates the reconstructible probe source/project/fixtures/template inputs into `scripts/fixtures/qinao-k4-platform-probe/**` with a source-tree digest/provenance record, and (b) retains under `docs/.../qinao-k4-platform-spike/` only a redacted structured preliminary summary plus non-secret digests. Exclude raw build/archive/install logs, provisioning/account diagnostics, embedded profiles, raw UUID/UDID/certificate data, and every self-contradictory redaction claim. The tooling fixture remains explicitly mutable through Task 3 hardening; the sealed preliminary observation summary is immutable and is never copied, renamed, or promoted as approved proof.

Create `scripts/check_qinao_preliminary_k4_source.py` and its standard-library mutation suite in the same baseline commit. It owns an exact tuple of every retained preliminary-summary path and every migrated fixture path, reads stage-0 index blobs with `git show :<path>`, rejects missing/extra/mode-other-than-`100644`/symlink/conflict/worktree drift, rejects all old `spike/logs/**`, and scans the actual staged bytes for `/Users/`, account-home paths, provisioning portal text, raw profile UUID/UDID/certificate bodies, and contradictions between summary claims and retained bytes. The tuple is globally sorted and byte-pinned by its test; no directory/glob is accepted as an inventory substitute. The review records only non-secret digests/counts and commits the checker, test, migrated fixture, and sanitized preliminary summary as one exact baseline unit. If safe source inputs cannot be separated from private observations, leave W0 BLOCKED and do not create the execution branch.

Do not use `git commit --only` in the dirty source worktree: pathspec commits reconstruct an index from worktree bytes and can bypass the exact candidate that was reviewed. Record hashes of the source worktree's staged diff, unstaged tracked diff, and unrelated-untracked `(path,NUL,content)` stream. From the committed plan HEAD, create a separate clean branch/worktree named `codex/qinao-coreai-k4-baseline-20260719` / `.worktrees/qinao-coreai-k4-baseline-sanitize`.

Before K4 sanitation, materialize from the source index and validate exactly the three already-staged stable Artifact Mesh Create receipts: `docs/superpowers/evidence/qinao-owner-create/artifact-mesh--{core,schema,sqlite-store}.json`. Their candidate paths must be exactly `BASArtifactMeshCore.swift`, `024_artifact_mesh_v1.sql`, and `BASArtifactSQLiteStore.swift` under their full committed paths, all added in `6703354b6..a82a7bb0b4e4f5680117df3b92593fa90c9d85a3`; no fourth production candidate or receipt is admitted. Stage only those three receipts, run candidate-receipt validation against the committed production blobs, machine-compare the exact cached tuple, record its index tree, make one unqualified `evidence: bind existing Artifact Mesh Create receipts` commit, and require commit-tree equality. This is retrospective evidence for already reviewed production additions, not authority creation.

Then an audited one-shot K4 migration reads only the exact source-index blobs and explicitly admitted source-worktree fixture inputs, writes the sanitized tuple into that same clean worktree, and emits a source-blob-to-output-digest map. It may not copy a directory recursively.

In the clean sanitation worktree, stage only the checker/test, exact migrated fixture tuple, exact retained summary tuple, and exact preliminary-tree deletions. Machine-compare NUL-delimited `git diff --cached --name-status --no-renames` with the reviewed `(status,path)` tuple, run the checker in `--index` mode, record `BASELINE_INDEX_TREE="$(git write-tree)"`, then use an unqualified `git commit -m "evidence: seal privacy-clean K4 probe baseline"`. Require the resulting commit tree to equal `BASELINE_INDEX_TREE` and its diff to contain nothing outside the tuple. Finally recompute the three source-worktree hashes and require exact equality. The summary contains only source-to-sanitized provenance/digests; it never embeds its own blob/commit identity. The checker source pins the reviewed summary blob unidirectionally, while the first-seal commit/tree is reconstructed from unique Git first-add history and archived externally. Only the fixture/tooling subtree remains mutable through Task 3.

- [ ] **Step 1: Prove the source commit contains the plan and the reviewed baseline**

Run from the current Qinao worktree, but select the reviewed sanitation branch rather than its dirty branch HEAD:

```bash
SOURCE_ROOT="$PWD"
BASELINE_BRANCH="codex/qinao-coreai-k4-baseline-20260719"
SOURCE_HEAD="$(git rev-parse "$BASELINE_BRANCH")"
COMMON_GIT_DIR="$(git rev-parse --path-format=absolute --git-common-dir)"
MAIN_ROOT="$(cd "$(dirname "$COMMON_GIT_DIR")" && pwd -P)"
BASELINE_ROOT="$MAIN_ROOT/.worktrees/qinao-coreai-k4-baseline-sanitize"
BASE_BRANCH="codex/qinao-coreai-convergence-base-20260719"
PLAN_PATH="docs/superpowers/plans/2026-07-19-qinao-coreai-agent-controlled-document-convergence.md"
test -z "$(git branch --list "$BASE_BRANCH")"
git merge-base --is-ancestor a82a7bb0b4e4f5680117df3b92593fa90c9d85a3 "$SOURCE_HEAD"
git cat-file -e "$SOURCE_HEAD:$PLAN_PATH"
for required in \
  docs/superpowers/specs/qinao-authority-corruption-recovery-v1.md \
  scripts/check_qinao_review_candidate.py \
  scripts/test_check_qinao_review_candidate.py \
  docs/superpowers/evidence/qinao-owner-create/artifact-mesh--core.json \
  docs/superpowers/evidence/qinao-owner-create/artifact-mesh--schema.json \
  docs/superpowers/evidence/qinao-owner-create/artifact-mesh--sqlite-store.json \
  scripts/check_k4_platform_proof.py \
  scripts/test_check_k4_platform_proof.py \
  scripts/run_nonempty_swift_filter.py \
  scripts/test_run_nonempty_swift_filter.py \
  docs/superpowers/evidence/qinao-k4-platform-spike/README.md \
  docs/superpowers/evidence/qinao-k4-platform-spike/status.json \
  scripts/check_qinao_preliminary_k4_source.py \
  scripts/test_check_qinao_preliminary_k4_source.py \
  scripts/fixtures/qinao-k4-platform-probe/Extension/K4SpikeExtension.swift \
  scripts/fixtures/qinao-k4-platform-probe/Host/K4SpikeHostApp.swift \
  scripts/fixtures/qinao-k4-platform-probe/Shared/SpikeMessages.swift \
  scripts/fixtures/qinao-k4-platform-probe/K4PlatformSpike.xcodeproj/project.pbxproj \
  scripts/fixtures/qinao-k4-platform-probe/fixtures/EnhancedSecurityInitializerShapes.swift \
  scripts/fixtures/qinao-k4-platform-probe/fixtures/XPCReplyShapes.swift \
  scripts/fixtures/qinao-k4-platform-probe/project.yml \
  BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASSyntheticExecutionReceiptFreezeTests.swift \
  QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoEffectFacadeFreezeTests.swift
do
  git cat-file -e "$SOURCE_HEAD:$required"
done
test -z "$(git ls-tree -r --name-only "$SOURCE_HEAD" -- docs/superpowers/evidence/qinao-k4-platform-spike/spike/logs)"
python3 -B "$BASELINE_ROOT/scripts/check_qinao_preliminary_k4_source.py" \
  --root "$BASELINE_ROOT" --index
test -z "$(git -C "$BASELINE_ROOT" status --porcelain=v1 --untracked-files=all)"
git status --short
```

Expected: every Git proof command exits `0`. If a required path exists only in the dirty index/worktree, first finish its existing review and commit it as its own W0 baseline unit; never smuggle it into this plan's commits. `git status` may still show unrelated pre-existing work; do not stage, clean, stash, reset, or commit it.

- [ ] **Step 2: Create the detached worktree, then the execution branch**

```bash
BASELINE_BRANCH="codex/qinao-coreai-k4-baseline-20260719"
SOURCE_HEAD="$(git rev-parse "$BASELINE_BRANCH")"
BASE_BRANCH="codex/qinao-coreai-convergence-base-20260719"
COMMON_GIT_DIR="$(git rev-parse --path-format=absolute --git-common-dir)"
MAIN_ROOT="$(cd "$(dirname "$COMMON_GIT_DIR")" && pwd -P)"
EXEC_ROOT="$MAIN_ROOT/.worktrees/qinao-coreai-convergence-exec"
BASELINE_ROOT="$MAIN_ROOT/.worktrees/qinao-coreai-k4-baseline-sanitize"
test "$(git -C "$BASELINE_ROOT" rev-parse HEAD)" = "$SOURCE_HEAD"
test ! -e "$EXEC_ROOT"
git branch "$BASE_BRANCH" "$SOURCE_HEAD"
git worktree add --detach "$EXEC_ROOT" "$SOURCE_HEAD"
git -C "$EXEC_ROOT" switch -c codex/qinao-coreai-convergence-exec-20260719
test -z "$(git -C "$EXEC_ROOT" status --porcelain=v1 --untracked-files=all)"
git -C "$EXEC_ROOT" rev-parse HEAD
```

Expected: the final status expansion is empty and the printed HEAD equals `SOURCE_HEAD`. The immutable base branch retains the execution base across shells. If the path, base branch, or execution branch already exists, stop and inspect it; do not delete or reuse it implicitly.

- [ ] **Step 3: Execute every remaining task only in the isolated root**

```bash
COMMON_GIT_DIR="$(git rev-parse --path-format=absolute --git-common-dir)"
MAIN_ROOT="$(cd "$(dirname "$COMMON_GIT_DIR")" && pwd -P)"
EXEC_ROOT="$MAIN_ROOT/.worktrees/qinao-coreai-convergence-exec"
cd "$EXEC_ROOT"
test "$PWD" = "$(git rev-parse --show-toplevel)"
```

Expected: PASS. In every later shell recover the base with `SOURCE_HEAD="$(git rev-parse codex/qinao-coreai-convergence-base-20260719)"`; no repository file is created for this control value.

### Task 1: Correct the Decision-Source and Recovery-Authority Preconditions

**Files:**
- Modify: `docs/superpowers/specs/2026-07-19-qinao-coreai-agent-context-memory-rsi-design.md:13`
- Modify: `docs/superpowers/specs/qinao-authority-corruption-recovery-v1.md:1-90`
- Modify: `scripts/test_qinao_plan_remediation.py`

**Interfaces:**
- Consumes: the exact controlled-document tuple exported by `scripts.check_qinao_owner_ledger.EXPECTED_CONTROLLED_DOCUMENTS`.
- Produces: an unambiguous seven-document source statement and a conditionally normative recovery contract whose lifecycle/floor/receipt records remain children of the existing K3, K4, publication, and Zone-C owners.

- [ ] **Step 1: Add failing inventory and recovery-owner tests**

Add these constants and tests to `scripts/test_qinao_plan_remediation.py`:

```python
ADDENDUM = (
    ROOT
    / "docs/superpowers/specs/"
    / "2026-07-19-qinao-coreai-agent-context-memory-rsi-design.md"
)
RECOVERY_CONTRACT = (
    ROOT
    / "docs/superpowers/specs/qinao-authority-corruption-recovery-v1.md"
)

def test_addendum_names_the_exact_seven_controlled_documents(self) -> None:
    contents = ADDENDUM.read_text(encoding="utf-8")
    self.assertIn(
        "architecture design, convergence master, and five domain plans",
        contents,
    )
    self.assertNotIn("six domain plans", contents)

def test_recovery_contract_has_no_unmapped_shared_authority(self) -> None:
    contents = RECOVERY_CONTRACT.read_text(encoding="utf-8")
    self.assertIn("Status: conditionally normative, fail-closed", contents)
    for owner_id in (
        "state.k3-control-nucleus",
        "sovereign.k4-durable-lifecycle",
        "release.spool-publication",
        "effect.zone-c-saga",
    ):
        self.assertIn(owner_id, contents)
    for forbidden in (
        "RecoveryAuthority",
        "RecoveryRegistry",
        "RecoveryStore",
        "shared recovery database",
    ):
        self.assertNotIn(forbidden, contents)
```

- [ ] **Step 2: Run the tests and verify that the current wording fails**

Run:

```bash
if python3 -m unittest \
  scripts.test_qinao_plan_remediation.QinaoPlanRemediationTests.test_addendum_names_the_exact_seven_controlled_documents \
  scripts.test_qinao_plan_remediation.QinaoPlanRemediationTests.test_recovery_contract_has_no_unmapped_shared_authority -v
then
  echo "unexpected pre-remediation success" >&2
  exit 1
fi
```

Expected: FAIL because the addendum says `six domain plans`, the recovery contract is unconditionally normative, and it does not name the four Owner Ledger owner IDs.

- [ ] **Step 3: Correct the addendum enumeration**

Replace the first sentence after the precedence paragraph with this exact wording:

```markdown
This is a normative design addendum, not an eighth Owner Ledger controlled document. Before W1, W0 must atomically merge every adopted decision into the architecture design, convergence master, and five domain plans; regenerate the Owner Ledger provenance, reviewed digests, and required terms; and run the non-empty owner/create/shape/iOS-floor gates.
```

Keep the existing following sentences about seven-document convergence and CreateGate unchanged.

- [ ] **Step 4: Make recovery normativity conditional and map physical ownership**

Replace the current status/owner preamble and the shared-record sentence in Section 2 with:

```markdown
Status: conditionally normative, fail-closed

Normativity condition: this contract becomes normative for a domain only when the W0 Owner Ledger gate maps that domain's lifecycle projection, external monotonic floor, recovery control record, operator-approval input, and signed recovery receipt to its existing physical/operator owner. An unmapped domain remains unavailable and this document cannot authorize a new writer, registry, database, or reactivation path.

Owner map:

- K3 lifecycle/floor/control/receipt projection: `state.k3-control-nucleus`.
- K4 lifecycle/floor/control/receipt projection: `sovereign.k4-durable-lifecycle` inside the Enhanced Security helper boundary.
- publication lifecycle/floor/control/receipt projection: `release.spool-publication`.
- Zone-C lifecycle/floor/control/receipt projection: `effect.zone-c-saga`.

The lifecycle projection and its immutable evidence are maintained separately by each existing domain owner, outside the database file family being repaired but inside that owner's already approved host/helper protection boundary. Artifact Mesh may retain immutable evidence references; it does not decide write eligibility. Operator approval is a signed L14/K4 input to the mapped owner, not a fifth recovery authority. There is no cross-domain recovery coordinator, registry, store, lease database, or mutable floor owner.
```

Also replace `surviving external recovery registry` in the delete-and-recreate exception with `the same mapped domain owner or an operator incident record`.

- [ ] **Step 5: Run the focused and complete remediation suites**

Run:

```bash
python3 -m unittest \
  scripts.test_qinao_plan_remediation.QinaoPlanRemediationTests.test_addendum_names_the_exact_seven_controlled_documents \
  scripts.test_qinao_plan_remediation.QinaoPlanRemediationTests.test_recovery_contract_has_no_unmapped_shared_authority -v
python3 -m unittest scripts.test_qinao_plan_remediation -v
```

Expected: both focused tests PASS; the complete remediation suite passes with zero failures.

- [ ] **Step 6: Commit only the source clarification**

```bash
git add \
  docs/superpowers/specs/2026-07-19-qinao-coreai-agent-context-memory-rsi-design.md \
  docs/superpowers/specs/qinao-authority-corruption-recovery-v1.md \
  scripts/test_qinao_plan_remediation.py
test "$(git diff --cached --name-only | wc -l | tr -d ' ')" = 3
CLARIFICATION_INDEX_TREE="$(git write-tree)"
git commit -m "docs: map Qinao recovery authority"
test "$(git rev-parse HEAD^{tree})" = "$CLARIFICATION_INDEX_TREE"
```

Expected: one documentation/test commit; no production source or controlled document changed yet.

### Task 2: Add One Non-Vacuous Cumulative Wave-Gate Orchestrator

**Files:**
- Create: `scripts/qinao_wave_gates_v1.json`
- Create: `scripts/run_qinao_wave_gate.py`
- Create: `scripts/test_run_qinao_wave_gate.py`
- Modify: `scripts/run_nonempty_swift_filter.py`
- Modify: `scripts/test_run_nonempty_swift_filter.py`
- Modify: `scripts/check_qinao_owner_ledger.py`
- Modify: `scripts/test_check_qinao_owner_ledger.py`
- Reuse: `scripts/check_qinao_review_candidate.py`
- Reuse: `scripts/check_k4_platform_proof.py`
- Reuse: `scripts/check_qinao_preliminary_k4_source.py`

**Interfaces:**
- Consumes: `run_nonempty_swift_filter.py --package-path --scratch-path --filter --require-suite...` and a small allowlist of repository checker IDs.
- Produces: `run_qinao_wave_gate.py --root <clean-root> --manifest <json> --through W0...W6 [--lane all|deterministic|platform] [--candidate-tree <tree>] --receipt <json>`.
- Lane contract: `all` is the local/release acceptance gate; CI may shard it into the closed, disjoint `deterministic` and `platform` lanes only when the workflow contract proves both jobs are enabled. `platform` contains only the real K4 proof checker; all source scans, structural checkers, and Swift suites are `deterministic`.
- Security boundary: the JSON may contain paths, regular expressions, suite names, and checker IDs; it may not contain shell commands, environment assignments, executable paths, or arguments for arbitrary subprocesses.
- Evidence boundary: every success or failure atomically writes a schema-1 receipt with exact candidate-index tree, HEAD tree, manifest SHA-256, toolchain, lane/waves, redacted argv commitments, required-path/candidate/glob/listed/executed counts, exit codes, and the K4 redacted device identity when the platform lane runs.
- Candidate boundary: every lane rejects tracked worktree/index drift, conflicts, every untracked path (including ignored paths), and `assume-unchanged`/`skip-worktree`/fsmonitor-valid index flags before reading repository inputs. It records the exact index tree, manifest blob, and per-path mode/blob tuple; after every gate and at final postflight it independently re-hashes every worktree path against its index blob and requires the snapshot unchanged. Staged additions/modifications are permitted through W5. W6 additionally requires the same clean detached HEAD tree throughout.
- Receipt boundary: `--receipt` must be an absent, non-symlink leaf outside the repository under an already existing real directory rooted at `/tmp` or `RUNNER_TEMP`. Children use a private temporary directory. The aggregate writer publishes complete canonical bytes with same-filesystem no-replace `os.link`; it never follows or overwrites a target.

- [ ] **Step 1: Write manifest-shape and anti-vacuity tests**

Create `scripts/test_run_qinao_wave_gate.py` with these core tests. Use `tempfile.TemporaryDirectory`, ordinary regular files, and injected subprocess results; do not invoke the real Swift compiler from unit tests.

```python
#!/usr/bin/env python3

import hashlib
import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

from scripts import run_qinao_wave_gate as gate


class QinaoWaveGateTests(unittest.TestCase):
    def write_manifest(self, root: Path, value: dict) -> Path:
        path = root / "manifest.json"
        path.write_text(json.dumps(value), encoding="utf-8")
        return path

    def minimal_manifest(self) -> dict:
        empty = {"required_paths": [], "negative_scans": [], "checkers": [], "swift": []}
        waves = {f"W{index}": dict(empty) for index in range(7)}
        waves["W0"] = {
            "required_paths": ["tracked.txt"],
            "negative_scans": [{
                "id": "no-forbidden",
                "roots": ["Sources"],
                "glob": "*.swift",
                "pattern": "ForbiddenAuthority",
                "minimum_files": 1,
            }],
            "checkers": ["xcode27"],
            "swift": [],
        }
        return {"schema_version": 1, "wave_order": [f"W{i}" for i in range(7)], "waves": waves}

    def make_root(self) -> tuple[tempfile.TemporaryDirectory, Path]:
        temporary = tempfile.TemporaryDirectory()
        root = Path(temporary.name)
        (root / "tracked.txt").write_text("bound", encoding="utf-8")
        (root / "Sources").mkdir()
        (root / "Sources/Allowed.swift").write_text("struct Allowed {}", encoding="utf-8")
        return temporary, root

    def test_missing_required_path_fails(self) -> None:
        temporary, root = self.make_root()
        self.addCleanup(temporary.cleanup)
        value = self.minimal_manifest()
        value["waves"]["W0"]["required_paths"] = ["missing.txt"]
        errors = gate.validate_manifest_and_inputs(root, value, through="W0")
        self.assertTrue(any("missing regular path" in item for item in errors), errors)

    def test_empty_glob_fails_before_scanning(self) -> None:
        temporary, root = self.make_root()
        self.addCleanup(temporary.cleanup)
        value = self.minimal_manifest()
        value["waves"]["W0"]["negative_scans"][0]["glob"] = "*.metal"
        errors = gate.validate_manifest_and_inputs(root, value, through="W0")
        self.assertTrue(any("matched 0 regular files" in item for item in errors), errors)

    def test_non_utf8_input_is_a_gate_error_not_no_match(self) -> None:
        temporary, root = self.make_root()
        self.addCleanup(temporary.cleanup)
        value = self.minimal_manifest()
        scan = value["waves"]["W0"]["negative_scans"][0]

        (root / "Sources/Allowed.swift").write_bytes(b"\xff")
        errors = gate.run_negative_scan(root, scan)
        self.assertTrue(any("unreadable UTF-8 input" in item for item in errors), errors)

    def test_match_is_violation_and_absence_passes(self) -> None:
        temporary, root = self.make_root()
        self.addCleanup(temporary.cleanup)
        scan = self.minimal_manifest()["waves"]["W0"]["negative_scans"][0]

        self.assertEqual(gate.run_negative_scan(root, scan), [])
        (root / "Sources/Allowed.swift").write_text(
            "struct ForbiddenAuthority {}", encoding="utf-8"
        )
        self.assertTrue(gate.run_negative_scan(root, scan))

    def test_scan_regex_can_match_across_lines(self) -> None:
        temporary, root = self.make_root()
        self.addCleanup(temporary.cleanup)
        scan = self.minimal_manifest()["waves"]["W0"]["negative_scans"][0]
        scan["pattern"] = r"actor\s+ForbiddenAuthority"
        (root / "Sources/Allowed.swift").write_text(
            "actor\nForbiddenAuthority {}", encoding="utf-8"
        )
        self.assertTrue(gate.run_negative_scan(root, scan))

    def test_unknown_wave_and_empty_wave_are_rejected(self) -> None:
        temporary, root = self.make_root()
        self.addCleanup(temporary.cleanup)
        value = self.minimal_manifest()
        self.assertTrue(gate.validate_manifest_and_inputs(root, value, through="W7"))
        value["waves"]["W0"] = {
            "required_paths": [], "negative_scans": [], "checkers": [], "swift": []
        }
        errors = gate.validate_manifest_and_inputs(root, value, through="W0")
        self.assertTrue(any("contains zero gates" in item for item in errors), errors)

    def test_deleted_required_suite_is_not_delegated_as_success(self) -> None:
        temporary, root = self.make_root()
        self.addCleanup(temporary.cleanup)
        spec = {
            "package_path": "BehavioralAISubstrate",
            "filter": "RequiredSuite",
            "required_suites": ["RequiredSuite"],
        }
        command = gate.swift_filter_command(
            root,
            root / "scratch",
            root / "swift-receipt.json",
            spec,
        )
        self.assertEqual(command.count("--require-suite"), 1)
        self.assertIn("RequiredSuite", command)
        self.assertIn("--receipt", command)

    def test_manifest_cannot_supply_an_arbitrary_command(self) -> None:
        temporary, root = self.make_root()
        self.addCleanup(temporary.cleanup)
        value = self.minimal_manifest()
        value["waves"]["W0"]["checkers"] = ["python3 -c arbitrary"]
        errors = gate.validate_manifest_and_inputs(root, value, through="W0")
        self.assertTrue(any("unknown checker ID" in item for item in errors), errors)

    def test_platform_lane_is_closed_and_disjoint(self) -> None:
        self.assertEqual(gate.PLATFORM_CHECKER_IDS, frozenset({"k4_platform_proof"}))
        self.assertNotIn("k4_platform_proof", gate.DETERMINISTIC_ONLY_CHECKER_IDS)
        deterministic, platform = gate.checker_phases(
            ["owner_ledger", "k4_platform_proof", "review_candidate"],
            lane="all",
        )
        self.assertEqual(deterministic, ("owner_ledger", "review_candidate"))
        self.assertEqual(platform, ("k4_platform_proof",))

    def test_platform_schema_preflight_does_not_touch_deterministic_inputs(self) -> None:
        temporary, root = self.make_root()
        self.addCleanup(temporary.cleanup)
        value = self.minimal_manifest()
        wave = value["waves"]["W0"]
        wave["required_paths"] = ["not-materialized-in-platform-job.txt"]
        wave["negative_scans"][0]["roots"] = ["not-materialized-scan-root"]
        wave["checkers"] = ["k4_platform_proof"]
        wave["swift"] = [{
            "package_path": "not-materialized-package",
            "filter": "RequiredSuite",
            "required_suites": ["RequiredSuite"],
        }]
        self.assertEqual(
            gate.validate_manifest_and_inputs(
                root, value, through="W0", lane="platform"
            ),
            [],
        )

    def test_repository_inputs_must_be_fully_staged_including_ignored_files(self) -> None:
        temporary, root = self.make_root()
        self.addCleanup(temporary.cleanup)
        subprocess.run(["git", "init", "-q"], cwd=root, check=True)
        (root / ".gitignore").write_text("ignored.bin\n", encoding="utf-8")
        subprocess.run(["git", "add", "."], cwd=root, check=True)
        subprocess.run(
            [
                "git", "-c", "user.name=Qinao Gate Test",
                "-c", "user.email=qinao-gate@example.invalid",
                "commit", "-q", "-m", "baseline",
            ],
            cwd=root,
            check=True,
        )
        _, errors = gate.candidate_index_snapshot(root)
        self.assertEqual(errors, [])
        (root / "tracked.txt").write_text("unstaged", encoding="utf-8")
        _, errors = gate.candidate_index_snapshot(root)
        self.assertTrue(errors)
        subprocess.run(["git", "add", "tracked.txt"], cwd=root, check=True)
        _, errors = gate.candidate_index_snapshot(root)
        self.assertEqual(errors, [])
        (root / "ignored.bin").write_bytes(b"not in candidate tree")
        _, errors = gate.candidate_index_snapshot(root)
        self.assertTrue(errors)

    def test_special_index_flags_cannot_hide_worktree_drift(self) -> None:
        temporary, root = self.make_root()
        self.addCleanup(temporary.cleanup)
        subprocess.run(["git", "init", "-q"], cwd=root, check=True)
        subprocess.run(["git", "add", "."], cwd=root, check=True)
        subprocess.run(["git", "update-index", "--assume-unchanged", "tracked.txt"], cwd=root, check=True)
        _, errors = gate.candidate_index_snapshot(root)
        self.assertTrue(any("assume-unchanged" in item for item in errors), errors)
        subprocess.run(["git", "update-index", "--no-assume-unchanged", "tracked.txt"], cwd=root, check=True)
        subprocess.run(["git", "update-index", "--skip-worktree", "tracked.txt"], cwd=root, check=True)
        _, errors = gate.candidate_index_snapshot(root)
        self.assertTrue(any("skip-worktree" in item for item in errors), errors)

    def test_manifest_requires_exact_lexical_canonical_path(self) -> None:
        self.assertTrue(gate.canonical_manifest_argument_errors(
            Path("scripts/qinao_wave_gates_v1.json"), Path("/repo")
        ))
        self.assertTrue(gate.canonical_manifest_argument_errors(
            Path("/outside/manifest-alias.json"), Path("/repo")
        ))

    def test_receipt_cannot_alias_or_overwrite_repository_state(self) -> None:
        self.assertTrue(gate.receipt_path_errors(Path("/repo/source.py"), Path("/repo")))
        self.assertTrue(gate.receipt_path_errors(Path("/repo/manifest.json"), Path("/repo")))

    def test_malformed_scan_and_swift_types_fail_without_throwing(self) -> None:
        temporary, root = self.make_root()
        self.addCleanup(temporary.cleanup)
        value = self.minimal_manifest()
        value["waves"]["W0"]["negative_scans"][0]["roots"] = "Sources"
        value["waves"]["W0"]["swift"] = [{
            "package_path": 7,
            "filter": [],
            "required_suites": "RequiredSuite",
        }]
        errors = gate.validate_manifest_and_inputs(root, value, through="W0")
        self.assertTrue(any("roots must be a non-empty unique list" in item for item in errors), errors)
        self.assertTrue(any("invalid Swift gate" in item for item in errors), errors)

    def test_symlinked_parent_cannot_escape_root(self) -> None:
        temporary, root = self.make_root()
        self.addCleanup(temporary.cleanup)
        outside = Path(temporary.name).parent / f"{root.name}-outside"
        outside.mkdir()
        self.addCleanup(lambda: outside.rmdir())
        (outside / "escaped.txt").write_text("escape", encoding="utf-8")
        self.addCleanup(lambda: (outside / "escaped.txt").unlink())
        os.symlink(outside, root / "escape")
        value = self.minimal_manifest()
        value["waves"]["W0"]["required_paths"] = ["escape/escaped.txt"]
        errors = gate.validate_manifest_and_inputs(root, value, through="W0")
        self.assertTrue(any("symlink component" in item for item in errors), errors)

    def test_duplicate_json_key_and_manifest_byte_drift_fail(self) -> None:
        temporary, root = self.make_root()
        self.addCleanup(temporary.cleanup)
        duplicate = root / "duplicate.json"
        duplicate.write_text('{"schema_version":1,"schema_version":1}', encoding="utf-8")
        with self.assertRaises(gate.DuplicateJSONKeyError):
            gate.load_manifest(duplicate)
        canonical = Path(gate.__file__).with_name("qinao_wave_gates_v1.json")
        self.assertEqual(
            hashlib.sha256(canonical.read_bytes()).hexdigest(),
            gate.EXPECTED_MANIFEST_SHA256,
        )

    def test_w6_candidate_must_be_clean_detached_and_exact_tree(self) -> None:
        self.assertIn("candidate_tree", gate.W6_REQUIRED_ARGUMENTS)

    def test_every_lane_is_candidate_bound_before_and_after_work(self) -> None:
        self.assertEqual(gate.CANDIDATE_PHASES, ("preflight", "after-each-gate", "postflight"))

    def test_w6_candidate_rejects_missing_wrong_dirty_and_attached_state(self) -> None:
        temporary, root = self.make_root()
        self.addCleanup(temporary.cleanup)
        subprocess.run(["git", "init", "-q"], cwd=root, check=True)
        subprocess.run(["git", "add", "."], cwd=root, check=True)
        subprocess.run(
            [
                "git", "-c", "user.name=Qinao Gate Test",
                "-c", "user.email=qinao-gate@example.invalid",
                "commit", "-q", "-m", "baseline",
            ],
            cwd=root,
            check=True,
        )
        tree = subprocess.run(
            ["git", "rev-parse", "HEAD^{tree}"],
            cwd=root,
            check=True,
            capture_output=True,
            text=True,
        ).stdout.strip()
        self.assertTrue(gate.w6_candidate_errors(root, None))
        self.assertTrue(gate.w6_candidate_errors(root, "0" * len(tree)))
        self.assertTrue(any("attached" in item for item in gate.w6_candidate_errors(root, tree)))
        subprocess.run(["git", "checkout", "--detach", "-q"], cwd=root, check=True)
        self.assertEqual(gate.w6_candidate_errors(root, tree), [])
        (root / "dirty.txt").write_text("dirty", encoding="utf-8")
        self.assertTrue(any("not clean" in item for item in gate.w6_candidate_errors(root, tree)))


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the new unit suite and verify the module is missing**

Run:

```bash
if python3 -m unittest scripts.test_run_qinao_wave_gate -v; then
  echo "unexpected wave-runner RED success" >&2
  exit 1
fi
```

Expected: FAIL with `ImportError` because `scripts/run_qinao_wave_gate.py` does not exist.

- [ ] **Step 3: Create the canonical manifest**

Create `scripts/qinao_wave_gates_v1.json`. Every wave is cumulative: `--through W4` executes W0, W1, W2, W3, and W4. Future-wave files and suites are ignored until their wave becomes active.

```json
{
  "schema_version": 1,
  "wave_order": ["W0", "W1", "W2", "W3", "W4", "W5", "W6"],
  "waves": {
    "W0": {
      "required_paths": [
        ".github/workflows/test.yml",
        "BehavioralAISubstrate/Package.swift",
        "BehavioralAISubstrate/scripts/check-ios27-floor.sh",
        "QinaoRuntimeSDK/Package.swift",
        "SampleHost/Package.swift",
        "docs/superpowers/plans/2026-07-19-qinao-coreai-agent-controlled-document-convergence.md",
        "docs/superpowers/specs/2026-07-14-iphone-air-future-apple-silicon-architecture-design.md",
        "docs/superpowers/specs/2026-07-17-k3-budget-provider-contract-addendum-design.md",
        "docs/superpowers/specs/2026-07-19-qinao-coreai-agent-context-memory-rsi-design.md",
        "docs/superpowers/specs/qinao-authority-corruption-recovery-v1.md",
        "docs/superpowers/specs/qinao-owner-ledger-v1.json",
        "scripts/check_k4_platform_proof.py",
        "scripts/check_qinao_owner_ledger.py",
        "scripts/check_qinao_preliminary_k4_source.py",
        "scripts/check_qinao_review_candidate.py",
        "scripts/check_w0_expected_open_set.py",
        "scripts/check_xcode27_toolchain.sh",
        "scripts/qinao_wave_gates_v1.json",
        "scripts/run_nonempty_swift_filter.py",
        "scripts/run_qinao_wave_gate.py",
        "scripts/test_check_qinao_preliminary_k4_source.py",
        "scripts/test_run_qinao_wave_gate.py"
      ],
      "negative_scans": [
        {
          "id": "no-independent-state-commit-owner",
          "roots": ["BehavioralAISubstrate/Sources"],
          "glob": "*.swift",
          "pattern": "\\b(?:actor|class)\\s+BASStateCommitStore\\b",
          "minimum_files": 1
        }
      ],
      "checkers": [
        "xcode27",
        "ios27_floor",
        "owner_ledger",
        "preliminary_k4_source",
        "review_candidate",
        "k4_platform_proof",
        "w0_silicon_open_set",
        "w0_runtime_open_set"
      ],
      "swift": [
        {
          "package_path": "BehavioralAISubstrate",
          "filter": "BASProviderBoundaryTests|BASSyntheticExecutionReceiptFreezeTests",
          "required_suites": ["BASProviderBoundaryTests", "BASSyntheticExecutionReceiptFreezeTests"]
        },
        {
          "package_path": "QinaoRuntimeSDK",
          "filter": "QinaoProviderBoundaryTests|QinaoEffectFacadeFreezeTests",
          "required_suites": ["QinaoProviderBoundaryTests", "QinaoEffectFacadeFreezeTests"]
        }
      ]
    },
    "W1": {
      "required_paths": [
        "BehavioralAISubstrate/Sources/BASRuntimeCore/BASArtifactMeshCore.swift",
        "BehavioralAISubstrate/Sources/BASRuntimeCore/BASLayerCascadeRunner.swift",
        "BehavioralAISubstrate/Sources/BASRuntimeCore/BASLowEntropyPrimitives.swift",
        "BehavioralAISubstrate/Sources/BASRuntimeCore/BASSemanticStateLakeContracts.swift",
        "BehavioralAISubstrate/Sources/BASRuntimeCore/BASSemanticTurnDAG.swift"
      ],
      "negative_scans": [
        {
          "id": "qinao-sdk-has-no-concrete-provider-import",
          "roots": ["QinaoRuntimeSDK/Sources"],
          "glob": "*.swift",
          "pattern": "\\b(import (CoreAI|FoundationModels|MLX)|Qwen3|MiniCPM|Granite)\\b",
          "minimum_files": 1
        }
      ],
      "checkers": ["organ_descriptor_constructors"],
      "swift": [
        {
          "package_path": "BehavioralAISubstrate",
          "filter": "BASSemanticArchitectureIDTests|BASArtifactMeshTests|BASCapabilityGrantAttenuationTests|BASLayerCellMembraneTests|BASTurnOperationRefTests|BASArchitectureContractClosureTests|BASContextCapsuleContractTests|BASAgentRoleContractTests|BASRSIContractTests|BASReasoningArtifactContractTests|BASNextQuestionContractTests",
          "required_suites": [
            "BASSemanticArchitectureIDTests",
            "BASArtifactMeshTests",
            "BASCapabilityGrantAttenuationTests",
            "BASLayerCellMembraneTests",
            "BASTurnOperationRefTests",
            "BASArchitectureContractClosureTests",
            "BASContextCapsuleContractTests",
            "BASAgentRoleContractTests",
            "BASRSIContractTests",
            "BASReasoningArtifactContractTests",
            "BASNextQuestionContractTests"
          ]
        }
      ]
    },
    "W2": {
      "required_paths": [
        "BehavioralAISubstrate/Sources/BASRuntimeCore/BASSQLiteEventLogStorage.swift",
        "QinaoRuntimeSDK/Sources/QinaoMemory/QinaoMemory.swift",
        "scripts/check_semantic_governed_codec_boundaries.py"
      ],
      "negative_scans": [],
      "checkers": ["semantic_governed_codec_boundaries"],
      "swift": [
        {
          "package_path": "BehavioralAISubstrate",
          "filter": "BASSQLiteStoreCrashRecoveryTests|BASSQLiteEventLogDualWriteInvariantTests|BASBudgetLeaseControlTests|BASStateCommitActivationTests|BASK3CorruptionRecoveryTests|BASMemoryErasureClosureTests|BASMemoryContentArtifactRecoveryTests",
          "required_suites": [
            "BASSQLiteStoreCrashRecoveryTests",
            "BASSQLiteEventLogDualWriteInvariantTests",
            "BASBudgetLeaseControlTests",
            "BASStateCommitActivationTests",
            "BASK3CorruptionRecoveryTests",
            "BASMemoryErasureClosureTests",
            "BASMemoryContentArtifactRecoveryTests"
          ]
        }
      ]
    },
    "W3": {
      "required_paths": [
        "BehavioralAISubstrate/Sources/BASMemory/BASSemanticSnapshotCoordinator.swift",
        "BehavioralAISubstrate/Sources/BASOrchestration/BASSemanticStateMarket.swift",
        "BehavioralAISubstrate/Sources/BASOrchestration/BASStateRequirementPlanner.swift",
        "BehavioralAISubstrate/Sources/BASOrchestration/ContextCompilerCore.swift"
      ],
      "negative_scans": [],
      "checkers": [],
      "swift": [
        {
          "package_path": "BehavioralAISubstrate",
          "filter": "BASSemanticStateLakeContractTests|BASSemanticSnapshotCoordinatorTests|BASSemanticStateLaneAdapterTests|BASGroundingProposalIntegrationTests|BASSemanticStateShadowIntegrationTests|BASSemanticStateMarketTests|BASExactContextCompilerOwnershipTests|BASCacheScopeContractTests|BASRetrievalGroundingOrderTests|BASStructuredProblemFlowTests",
          "required_suites": [
            "BASSemanticStateLakeContractTests",
            "BASSemanticSnapshotCoordinatorTests",
            "BASSemanticStateLaneAdapterTests",
            "BASGroundingProposalIntegrationTests",
            "BASSemanticStateShadowIntegrationTests",
            "BASSemanticStateMarketTests",
            "BASExactContextCompilerOwnershipTests",
            "BASCacheScopeContractTests",
            "BASRetrievalGroundingOrderTests",
            "BASStructuredProblemFlowTests"
          ]
        }
      ]
    },
    "W4": {
      "required_paths": [
        "BehavioralAISubstrate/Sources/BASLeaseLife/BASProcessMemoryLedger.swift",
        "BehavioralAISubstrate/Sources/BASRuntimeCore/BASStateABI.swift"
      ],
      "negative_scans": [],
      "checkers": [],
      "swift": [
        {
          "package_path": "BehavioralAISubstrate",
          "filter": "BASLLMInvocationContractTests|BASStateABITests|BASProcessorABITests|BASProcessMemoryLedgerTests|BASSiliconLeaseGatewayTests|BASMLXUnifiedLeaseTests|BASExecutionPlanActuationTests|BASCoreAIAssetLifecycleTests|BASFoundationModelsSessionOwnershipTests",
          "required_suites": [
            "BASLLMInvocationContractTests",
            "BASStateABITests",
            "BASProcessorABITests",
            "BASProcessMemoryLedgerTests",
            "BASSiliconLeaseGatewayTests",
            "BASMLXUnifiedLeaseTests",
            "BASExecutionPlanActuationTests",
            "BASCoreAIAssetLifecycleTests",
            "BASFoundationModelsSessionOwnershipTests"
          ]
        }
      ]
    },
    "W5": {
      "required_paths": [
        "BehavioralAISubstrate/Sources/BASHostKit/BASResponseReleaseCoordinator.swift",
        "BehavioralAISubstrate/Sources/BASMemory/BASPublicationJournalSQLiteStorage.swift"
      ],
      "negative_scans": [],
      "checkers": [],
      "swift": [
        {
          "package_path": "BehavioralAISubstrate",
          "filter": "BASResponseReleaseOrderingTests|BASProviderExecutionSpoolTests|BASK4AuthorizationLedgerTests|BASEffectSagaCrashMatrixTests|BASSovereignEffectEndToEndTests|BASSovereignEnhancedSecurityBoundaryTests",
          "required_suites": [
            "BASResponseReleaseOrderingTests",
            "BASProviderExecutionSpoolTests",
            "BASK4AuthorizationLedgerTests",
            "BASEffectSagaCrashMatrixTests",
            "BASSovereignEffectEndToEndTests",
            "BASSovereignEnhancedSecurityBoundaryTests"
          ]
        },
        {
          "package_path": "QinaoRuntimeSDK",
          "filter": "QinaoEffectFacadeFreezeTests|QinaoEffectFacadeBrokerTests",
          "required_suites": ["QinaoEffectFacadeFreezeTests", "QinaoEffectFacadeBrokerTests"]
        }
      ]
    },
    "W6": {
      "required_paths": [
        "BehavioralAISubstrate/Sources/BASEvaluation/BASAppleSiliconCertification.swift",
        "BehavioralAISubstrate/Sources/BASRuntimeCore/BASArchitectureReplayManifest.swift",
        "BehavioralAISubstrate/scripts/check-authoritative-entrypoints.sh"
      ],
      "negative_scans": [],
      "checkers": ["authoritative_entrypoints", "clean_detached_candidate"],
      "swift": [
        {
          "package_path": "BehavioralAISubstrate",
          "filter": "BASSemanticTurnDAGTests|BASSemanticDAGShadowParityTests|BASTurnOperationCutoverTests|BASSingleAuthoritativeResultTests|BASArchitectureReplayManifestTests|BASPrePublicationManifestBarrierTests|BASAuthoritativeSemanticRuntimeTests|BASAppleSiliconCertificationTests|BASAuthoritativeEntrypointTests|BASProcessMemoryLedgerTests|BASNextQuestionProjectionTests|BASDeploymentJoinTests|BASIndependentContextWindowStressTests|BASControlLoopReplayTests",
          "required_suites": [
            "BASSemanticTurnDAGTests",
            "BASSemanticDAGShadowParityTests",
            "BASTurnOperationCutoverTests",
            "BASSingleAuthoritativeResultTests",
            "BASArchitectureReplayManifestTests",
            "BASPrePublicationManifestBarrierTests",
            "BASAuthoritativeSemanticRuntimeTests",
            "BASAppleSiliconCertificationTests",
            "BASAuthoritativeEntrypointTests",
            "BASProcessMemoryLedgerTests",
            "BASNextQuestionProjectionTests",
            "BASDeploymentJoinTests",
            "BASIndependentContextWindowStressTests",
            "BASControlLoopReplayTests"
          ]
        }
      ]
    }
  }
}
```

The future suite names are contracts: the runner ignores them before their wave, then fails if the implementing wave omits or deletes them. If an implementing task legitimately renames a suite, the manifest, owning domain plan, owner-ledger required terms, and manifest mutation test change together in one reviewed commit.

- [ ] **Step 4: Implement the strict runner without a shell escape hatch**

Create `scripts/run_qinao_wave_gate.py` with these public seams and invariants:

Resolve executable provenance once before validation: Python is canonical `sys.executable`; Bash, Git, xcode-select, Xcodebuild, and xcrun are exact system or selected-Xcode paths whose canonical paths, SHA-256 values, signatures, and version observations are receipt-bound. Developer selection is deterministic: use explicit `BAS_XCODE_DEVELOPER_DIR` when supplied by physical certification; otherwise a non-empty `DEVELOPER_DIR`; otherwise the exact output of attested `/usr/bin/xcode-select -p`. Resolve it beneath one signed `Xcode.app/Contents/Developer`, reject beta/prerelease drift, and execute `$DEVELOPER_DIR/usr/bin/xcodebuild` plus `/usr/bin/xcrun` under that environment. Receipts normalize bundle-relative paths as `$XCODE/<relative>` and compare build/signature/tool digests, never capture-machine versus CI absolute `/Applications/...` strings. Negative scans use no external executable. All subprocesses receive a minimal allowlisted environment with `PYTHONDONTWRITEBYTECODE=1`, `GIT_CONFIG_NOSYSTEM=1`, `GIT_CONFIG_GLOBAL=/dev/null`, and fixed Git config disabling fsmonitor, external diff, textconv, and submodule omission. No command lookup uses caller `PATH`. Fake leading-path and altered xcode-select/DEVELOPER_DIR tests prove fail-closed selection.

```python
#!/usr/bin/env python3

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import stat
import subprocess
import sys
import tempfile
from pathlib import Path, PurePosixPath

WAVE_ORDER = tuple(f"W{index}" for index in range(7))
W6_REQUIRED_ARGUMENTS = ("candidate_tree",)
CANDIDATE_PHASES = ("preflight", "after-each-gate", "postflight")
MAX_MANIFEST_BYTES = 256 * 1024
EXPECTED_MANIFEST_SHA256 = "1f0a9353c9f78099714e3210ce57cc44a2264ca82de4ee2640290c88cb533699"
PYTHON = str(Path(sys.executable).resolve(strict=True))
BASH = "/bin/bash"
GIT = "/usr/bin/git"
ALLOWED_WAVE_FIELDS = {"required_paths", "negative_scans", "checkers", "swift"}
ALLOWED_SCAN_FIELDS = {"id", "roots", "glob", "pattern", "minimum_files"}
ALLOWED_SWIFT_FIELDS = {"package_path", "filter", "required_suites"}


class DuplicateJSONKeyError(ValueError):
    pass


def reject_duplicate_keys(pairs: list[tuple[str, object]]) -> dict:
    result: dict[str, object] = {}
    for key, value in pairs:
        if key in result:
            raise DuplicateJSONKeyError(f"duplicate JSON key: {key}")
        result[key] = value
    return result


def normalized_relative(value: object) -> bool:
    if not isinstance(value, str) or not value or "\\" in value:
        return False
    path = PurePosixPath(value)
    return not path.is_absolute() and ".." not in path.parts and path.as_posix() == value


def confined_path(
    root: Path,
    relative: str,
    *,
    kind: str,
) -> tuple[Path | None, str | None]:
    if not normalized_relative(relative):
        return None, f"invalid normalized path: {relative!r}"
    cursor = root
    for component in PurePosixPath(relative).parts:
        cursor = cursor / component
        if cursor.is_symlink():
            return None, f"path contains a symlink component: {relative}"
    try:
        resolved_root = root.resolve(strict=True)
        resolved = cursor.resolve(strict=True)
        resolved.relative_to(resolved_root)
    except (FileNotFoundError, OSError, ValueError) as error:
        return None, f"path is missing or escapes root: {relative}: {error}"
    if kind == "file" and not resolved.is_file():
        return None, f"path is not a regular file: {relative}"
    if kind == "directory" and not resolved.is_dir():
        return None, f"path is not a regular directory: {relative}"
    return resolved, None


def checker_command(root: Path, checker_id: str, candidate_tree: str | None) -> list[str]:
    commands = {
        "xcode27": [BASH, str(root / "scripts/check_xcode27_toolchain.sh")],
        "ios27_floor": [BASH, str(root / "BehavioralAISubstrate/scripts/check-ios27-floor.sh"), str(root)],
        "owner_ledger": [
            PYTHON, str(root / "scripts/check_qinao_owner_ledger.py"),
            "--root", str(root), "--ledger", str(root / "docs/superpowers/specs/qinao-owner-ledger-v1.json"),
        ],
        "preliminary_k4_source": [
            PYTHON, str(root / "scripts/check_qinao_preliminary_k4_source.py"),
            "--root", str(root), "--index",
        ],
        "review_candidate": [PYTHON, str(root / "scripts/check_qinao_review_candidate.py"), "--root", str(root)],
        "w0_silicon_open_set": [
            PYTHON, str(root / "scripts/check_w0_expected_open_set.py"), "--root", str(root),
            "--history-dir", str(root / "docs/superpowers/evidence"),
            "--latest-series", "qinao-silicon-w0-open-set-v1", "--use-receipt-task",
        ],
        "w0_runtime_open_set": [
            PYTHON, str(root / "scripts/check_w0_expected_open_set.py"), "--root", str(root),
            "--history-dir", str(root / "docs/superpowers/evidence"),
            "--latest-series", "qinao-runtime-w0-open-set-v1", "--use-receipt-task",
        ],
        "organ_descriptor_constructors": [
            PYTHON, str(root / "scripts/check_bas_organ_descriptor_constructors.py"), "--root", str(root)
        ],
        "semantic_governed_codec_boundaries": [
            PYTHON, str(root / "scripts/check_semantic_governed_codec_boundaries.py"), "--root", str(root)
        ],
        "authoritative_entrypoints": [
            BASH, str(root / "BehavioralAISubstrate/scripts/check-authoritative-entrypoints.sh"), str(root)
        ],
    }
    if checker_id == "k4_platform_proof":
        return [
            PYTHON, str(root / "scripts/check_k4_platform_proof.py"),
            "--root", str(root),
            "--evidence", str(root / "docs/superpowers/evidence/qinao-k4-platform-proof-approved"),
        ]
    if checker_id == "clean_detached_candidate":
        if candidate_tree is None or re.fullmatch(r"[0-9a-f]{40,64}", candidate_tree) is None:
            raise ValueError("--candidate-tree is required for W6")
        return [GIT, "rev-parse", "HEAD^{tree}"]
    try:
        return commands[checker_id]
    except KeyError as error:
        raise ValueError(f"unknown checker ID: {checker_id}") from error


KNOWN_CHECKER_IDS = {
    "xcode27", "ios27_floor", "owner_ledger", "preliminary_k4_source", "review_candidate",
    "k4_platform_proof", "w0_silicon_open_set", "w0_runtime_open_set",
    "organ_descriptor_constructors", "semantic_governed_codec_boundaries",
    "authoritative_entrypoints", "clean_detached_candidate",
}
PLATFORM_CHECKER_IDS = frozenset({"k4_platform_proof"})
DETERMINISTIC_ONLY_CHECKER_IDS = frozenset(KNOWN_CHECKER_IDS) - PLATFORM_CHECKER_IDS


def checker_phases(
    checker_ids: list[str],
    *,
    lane: str,
) -> tuple[tuple[str, ...], tuple[str, ...]]:
    deterministic = tuple(
        checker_id for checker_id in checker_ids
        if checker_id not in PLATFORM_CHECKER_IDS
    )
    platform = tuple(
        checker_id for checker_id in checker_ids
        if checker_id in PLATFORM_CHECKER_IDS
    )
    if lane == "deterministic":
        return deterministic, ()
    if lane == "platform":
        return (), platform
    if lane == "all":
        return deterministic, platform
    raise ValueError(f"unknown lane: {lane}")


def active_wave_ids(through: str) -> tuple[str, ...]:
    if through not in WAVE_ORDER:
        raise ValueError(f"unknown wave: {through}")
    return WAVE_ORDER[: WAVE_ORDER.index(through) + 1]


def regular_files_for_scan(root: Path, spec: dict) -> tuple[list[Path], list[str]]:
    errors: list[str] = []
    files: list[Path] = []
    for relative_root in spec["roots"]:
        candidate, path_error = confined_path(root, relative_root, kind="directory")
        if path_error is not None:
            errors.append(f"negative scan {spec['id']}: {path_error}")
            continue
        assert candidate is not None
        for path in candidate.rglob(spec["glob"]):
            if not path.is_file():
                continue
            relative = path.relative_to(root).as_posix()
            confined, nested_error = confined_path(root, relative, kind="file")
            if nested_error is not None:
                errors.append(f"negative scan {spec['id']}: {nested_error}")
            else:
                assert confined is not None
                files.append(confined)
    files = sorted(set(files))
    minimum = spec["minimum_files"]
    if len(files) < minimum:
        errors.append(
            f"negative scan {spec['id']}: matched {len(files)} regular files; required {minimum}"
        )
    return files, errors


def run_negative_scan(
    root: Path,
    spec: dict,
) -> list[str]:
    files, errors = regular_files_for_scan(root, spec)
    if errors:
        return errors
    pattern = re.compile(spec["pattern"])
    matches: list[str] = []
    for path in files:
        try:
            text = path.read_bytes().decode("utf-8", errors="strict")
        except (OSError, UnicodeDecodeError) as error:
            return [f"negative scan {spec['id']}: unreadable UTF-8 input: {path}: {error}"]
        for match in pattern.finditer(text):
            line_number = text.count("\n", 0, match.start()) + 1
            matches.append(f"{path.relative_to(root).as_posix()}:{line_number}")
    if matches:
        return [
            f"negative scan {spec['id']} matched forbidden text at: "
            + ", ".join(matches)
        ]
    return []


def swift_filter_command(
    root: Path,
    scratch: Path,
    receipt: Path,
    spec: dict,
) -> list[str]:
    command = [
        PYTHON, str(root / "scripts/run_nonempty_swift_filter.py"),
        "--package-path", str(root / spec["package_path"]),
        "--scratch-path", str(scratch),
        "--filter", spec["filter"],
        "--receipt", str(receipt),
    ]
    for suite in spec["required_suites"]:
        command.extend(["--require-suite", suite])
    return command
```

Complete the same file with:

```python
def valid_string_list(
    value: object,
    *,
    allow_empty: bool,
    normalized_paths: bool = False,
) -> bool:
    if not isinstance(value, list) or (not allow_empty and not value):
        return False
    if any(not isinstance(item, str) or not item for item in value):
        return False
    if len(value) != len(set(value)):
        return False
    if normalized_paths and any(not normalized_relative(item) for item in value):
        return False
    return True


def validate_manifest_and_inputs(
    root: Path,
    manifest: dict,
    *,
    through: str,
    lane: str = "all",
) -> list[str]:
    errors: list[str] = []
    if lane not in {"all", "deterministic", "platform"}:
        return [f"unknown lane: {lane}"]
    inspect_deterministic_inputs = lane != "platform"
    if set(manifest) != {"schema_version", "wave_order", "waves"}:
        errors.append("manifest fields must be exactly schema_version/wave_order/waves")
    if manifest.get("schema_version") != 1:
        errors.append("schema_version must be integer 1")
    if manifest.get("wave_order") != list(WAVE_ORDER):
        errors.append("wave_order must be exactly W0-W6")
    waves = manifest.get("waves")
    if not isinstance(waves, dict) or list(waves) != list(WAVE_ORDER):
        errors.append("waves must contain W0-W6 exactly once in order")
        return errors
    try:
        active = active_wave_ids(through)
    except ValueError as error:
        return [str(error)]
    for wave_id in active:
        wave = waves[wave_id]
        if not isinstance(wave, dict) or set(wave) != ALLOWED_WAVE_FIELDS:
            errors.append(f"{wave_id}: invalid wave fields")
            continue
        if any(not isinstance(wave[field], list) for field in ALLOWED_WAVE_FIELDS):
            errors.append(f"{wave_id}: every wave field must be a list")
            continue
        gate_count = sum(len(wave[field]) for field in ALLOWED_WAVE_FIELDS)
        if gate_count == 0:
            errors.append(f"{wave_id}: contains zero gates")
        if not valid_string_list(
            wave["required_paths"], allow_empty=True, normalized_paths=True
        ):
            errors.append(f"{wave_id}: required_paths must be a unique normalized list")
        elif wave["required_paths"] != sorted(wave["required_paths"]):
            errors.append(f"{wave_id}: required_paths must be lexically sorted")
        if not valid_string_list(wave["checkers"], allow_empty=True):
            errors.append(f"{wave_id}: checkers must be a unique string list")
        if inspect_deterministic_inputs:
            for relative in wave["required_paths"]:
                if not normalized_relative(relative):
                    continue
                _, path_error = confined_path(root, relative, kind="file")
                if path_error is not None:
                    errors.append(f"{wave_id}: missing regular path: {relative}: {path_error}")
        for checker_id in wave["checkers"]:
            if not isinstance(checker_id, str) or checker_id not in KNOWN_CHECKER_IDS:
                errors.append(f"{wave_id}: unknown checker ID: {checker_id}")
        for scan in wave["negative_scans"]:
            if not isinstance(scan, dict) or set(scan) != ALLOWED_SCAN_FIELDS:
                errors.append(f"{wave_id}: invalid negative scan")
                continue
            if (
                not isinstance(scan["id"], str)
                or re.fullmatch(r"[a-z0-9][a-z0-9-]*", scan["id"]) is None
                or not valid_string_list(
                    scan["roots"], allow_empty=False, normalized_paths=True
                )
            ):
                errors.append(
                    f"{wave_id}: negative scan roots must be a non-empty unique list"
                )
                continue
            if (
                not isinstance(scan["glob"], str)
                or not scan["glob"]
                or "/" in scan["glob"]
                or "\\" in scan["glob"]
                or not isinstance(scan["pattern"], str)
                or not scan["pattern"]
                or not isinstance(scan["minimum_files"], int)
                or isinstance(scan["minimum_files"], bool)
                or scan["minimum_files"] < 1
            ):
                errors.append(f"{wave_id}: invalid negative scan scalar fields")
                continue
            try:
                re.compile(scan["pattern"])
            except re.error as error:
                errors.append(f"{wave_id}: invalid negative scan regex: {error}")
                continue
            if inspect_deterministic_inputs:
                _, scan_errors = regular_files_for_scan(root, scan)
                errors.extend(scan_errors)
        for swift in wave["swift"]:
            if not isinstance(swift, dict) or set(swift) != ALLOWED_SWIFT_FIELDS:
                errors.append(f"{wave_id}: invalid Swift gate")
                continue
            if (
                not normalized_relative(swift["package_path"])
                or not isinstance(swift["filter"], str)
                or not swift["filter"]
                or not valid_string_list(swift["required_suites"], allow_empty=False)
                or any(
                    re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", suite) is None
                    for suite in swift["required_suites"]
                )
            ):
                errors.append(f"{wave_id}: invalid Swift gate")
                continue
            try:
                re.compile(swift["filter"])
            except re.error as error:
                errors.append(f"{wave_id}: invalid Swift filter regex: {error}")
                continue
            if inspect_deterministic_inputs:
                package, package_error = confined_path(
                    root, swift["package_path"], kind="directory"
                )
                if package_error is not None:
                    errors.append(f"{wave_id}: Swift package is missing: {swift['package_path']}")
                    continue
                assert package is not None
                package_manifest = (PurePosixPath(swift["package_path"]) / "Package.swift").as_posix()
                _, manifest_error = confined_path(root, package_manifest, kind="file")
                if manifest_error is not None:
                    errors.append(f"{wave_id}: Swift package manifest is missing: {package_manifest}")
    return errors


def load_manifest(path: Path) -> dict:
    payload = path.read_bytes()
    if len(payload) > MAX_MANIFEST_BYTES:
        raise ValueError(f"manifest exceeds {MAX_MANIFEST_BYTES} bytes")
    value = json.loads(
        payload.decode("utf-8", errors="strict"),
        object_pairs_hook=reject_duplicate_keys,
    )
    if not isinstance(value, dict):
        raise ValueError("manifest root must be an object")
    if hashlib.sha256(payload).hexdigest() != EXPECTED_MANIFEST_SHA256:
        raise ValueError("canonical manifest bytes differ from the reviewed SHA-256")
    return value


def canonical_manifest_argument_errors(argument: Path, root: Path) -> list[str]:
    expected = root / "scripts/qinao_wave_gates_v1.json"
    if not argument.is_absolute() or argument != expected:
        return ["manifest must be the exact absolute canonical repository path"]
    return []


def compare_every_index_blob_to_worktree(
    root: Path,
    stage_result: subprocess.CompletedProcess[str],
) -> tuple[list[dict], list[str]]:
    entries: list[dict] = []
    errors: list[str] = []
    if stage_result.returncode != 0:
        return entries, ["cannot enumerate candidate index"]
    for record in stage_result.stdout.split("\0"):
        if not record:
            continue
        metadata, separator, relative = record.partition("\t")
        fields = metadata.split(" ")
        if separator != "\t" or len(fields) != 3:
            errors.append("malformed candidate index record")
            continue
        mode, object_id, stage = fields
        if stage != "0" or mode not in {"100644", "100755"} or not normalized_relative(relative):
            errors.append(f"unsupported/non-stage-0 candidate entry: {relative!r}")
            continue
        path = root / relative
        try:
            metadata_on_disk = path.lstat()
            worktree_bytes = path.read_bytes()
        except OSError as error:
            errors.append(f"cannot read candidate worktree path {relative}: {error}")
            continue
        observed_mode = "100755" if stat.S_ISREG(metadata_on_disk.st_mode) and (
            metadata_on_disk.st_mode & 0o111
        ) else "100644" if stat.S_ISREG(metadata_on_disk.st_mode) else "unsupported"
        blob = subprocess.run(
            [GIT, "cat-file", "blob", object_id],
            cwd=root,
            capture_output=True,
            check=False,
        )
        if blob.returncode != 0 or observed_mode != mode or blob.stdout != worktree_bytes:
            errors.append(f"candidate index/worktree blob or mode differs: {relative}")
        entries.append({"mode": mode, "blob": object_id, "path": relative})
    return sorted(entries, key=lambda item: item["path"]), errors


def candidate_index_snapshot(root: Path) -> tuple[dict, list[str]]:
    """Bind stage 0, then compare every worktree byte without trusting diff/status."""
    commands = {
        "conflicts": [GIT, "ls-files", "-u"],
        "flags_assume_skip": [GIT, "ls-files", "-v", "-z"],
        "flags_fsmonitor": [GIT, "ls-files", "-f", "-z"],
        "stage": [GIT, "ls-files", "--stage", "-z"],
        "untracked": [
            GIT, "ls-files", "--others", "--directory", "--no-empty-directory"
        ],
        "index_tree": [GIT, "write-tree"],
        "manifest_blob": [GIT, "rev-parse", ":scripts/qinao_wave_gates_v1.json"],
    }
    results = {
        name: subprocess.run(
            command, cwd=root, text=True, capture_output=True, check=False
        )
        for name, command in commands.items()
    }
    errors: list[str] = []
    if results["conflicts"].returncode != 0 or results["conflicts"].stdout:
        errors.append("candidate index contains unresolved entries")
    if results["untracked"].returncode != 0 or results["untracked"].stdout:
        errors.append("candidate worktree contains untracked inputs, including ignored inputs")
    if results["flags_assume_skip"].returncode != 0 or any(
        entry[:1].islower() or entry.startswith("S ")
        for entry in results["flags_assume_skip"].stdout.split("\0") if entry
    ):
        errors.append("candidate index uses assume-unchanged or skip-worktree flags")
    if results["flags_fsmonitor"].returncode != 0 or any(
        entry[:1].islower()
        for entry in results["flags_fsmonitor"].stdout.split("\0") if entry
    ):
        errors.append("candidate index uses fsmonitor-valid flags")
    # Parse the NUL-delimited stage output and require exactly one stage-0 tuple
    # per tracked path. For every mode/blob/path, lstat without following links;
    # independently compare mode plus exact regular-file bytes or symlink-target
    # bytes with `git cat-file blob`. Never use `git diff` as the byte oracle.
    entries, entry_errors = compare_every_index_blob_to_worktree(root, results["stage"])
    errors.extend(entry_errors)
    snapshot = {
        "index_tree": results["index_tree"].stdout.strip(),
        "manifest_blob": results["manifest_blob"].stdout.strip(),
        "entries": entries,
    }
    for name, result in results.items():
        if result.returncode != 0:
            errors.append(f"candidate Git observation failed: {name}")
    return snapshot, errors


def candidate_postflight_errors(root: Path, expected: dict) -> list[str]:
    observed, errors = candidate_index_snapshot(root)
    if observed != expected:
        errors.append("candidate index/worktree/manifest snapshot changed during the gate")
    return errors


def receipt_path_errors(receipt: Path, root: Path) -> list[str]:
    """Require an absent external receipt leaf under /tmp or RUNNER_TEMP."""
    errors: list[str] = []
    if not receipt.is_absolute() or receipt != Path(os.path.normpath(str(receipt))):
        return ["receipt path must be absolute and lexically normalized"]
    if receipt.exists() or receipt.is_symlink():
        return ["receipt target must be an absent non-symlink leaf"]
    try:
        parent = receipt.parent.resolve(strict=True)
    except (FileNotFoundError, OSError) as error:
        return [f"receipt parent must already exist: {error}"]
    if not parent.is_dir():
        return ["receipt parent is not a directory"]
    trusted: list[Path] = [Path("/tmp")]
    runner_temp = os.environ.get("RUNNER_TEMP")
    if runner_temp:
        trusted.append(Path(runner_temp))
    admitted = False
    for lexical_base in trusted:
        if not lexical_base.is_absolute():
            continue
        try:
            relative = receipt.relative_to(lexical_base)
            resolved_base = lexical_base.resolve(strict=True)
            parent.relative_to(resolved_base)
        except (FileNotFoundError, OSError, ValueError):
            continue
        cursor = lexical_base
        has_nested_symlink = False
        for component in relative.parent.parts:
            cursor = cursor / component
            if cursor.is_symlink():
                has_nested_symlink = True
                break
        if not has_nested_symlink:
            admitted = True
            break
    if not admitted:
        errors.append("receipt must be confined beneath /tmp or RUNNER_TEMP without nested symlinks")
    candidate = parent / receipt.name
    try:
        candidate.relative_to(root.resolve(strict=True))
    except ValueError:
        pass
    else:
        errors.append("receipt must be outside the repository")
    return errors


def run_command(command: list[str], *, root: Path) -> int:
    return subprocess.run(command, cwd=root, check=False).returncode


def w6_candidate_errors(root: Path, candidate_tree: str | None) -> list[str]:
    if candidate_tree is None or re.fullmatch(r"[0-9a-f]{40,64}", candidate_tree) is None:
        return ["W6 requires a canonical candidate tree object ID"]
    commands = {
        "head_tree": [GIT, "rev-parse", "HEAD^{tree}"],
        "index_tree": [GIT, "write-tree"],
        "status": [GIT, "status", "--porcelain=v1", "--untracked-files=all"],
        "symbolic": [GIT, "symbolic-ref", "-q", "HEAD"],
    }
    results = {
        name: subprocess.run(
            command, cwd=root, text=True, capture_output=True, check=False
        )
        for name, command in commands.items()
    }
    errors: list[str] = []
    if results["head_tree"].returncode != 0:
        errors.append("W6 candidate HEAD tree cannot be resolved")
    elif results["head_tree"].stdout.strip() != candidate_tree:
        errors.append("W6 candidate HEAD tree differs from --candidate-tree")
    if results["index_tree"].returncode != 0:
        errors.append("W6 candidate index tree cannot be resolved")
    elif results["index_tree"].stdout.strip() != candidate_tree:
        errors.append("W6 candidate index tree differs from --candidate-tree")
    if results["status"].returncode != 0 or results["status"].stdout:
        errors.append("W6 candidate worktree is not clean")
    if results["symbolic"].returncode == 0:
        errors.append("W6 candidate HEAD is attached")
    elif results["symbolic"].returncode != 1:
        errors.append("W6 detached-HEAD state cannot be proven")
    return errors


def run_checker_id(root: Path, checker_id: str, candidate_tree: str | None) -> str | None:
    if checker_id == "clean_detached_candidate":
        errors = w6_candidate_errors(root, candidate_tree)
        return "; ".join(errors) if errors else None
    command = checker_command(root, checker_id, candidate_tree)
    if run_command(command, root=root) != 0:
        return f"checker failed: {checker_id}"
    return None


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", required=True, type=Path)
    parser.add_argument("--manifest", required=True, type=Path)
    parser.add_argument("--through", required=True, choices=WAVE_ORDER)
    parser.add_argument(
        "--lane", choices=("all", "deterministic", "platform"), default="all"
    )
    parser.add_argument("--candidate-tree")
    parser.add_argument("--receipt", required=True, type=Path)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    root = args.root.resolve(strict=True)
    receipt_errors = receipt_path_errors(args.receipt, root)
    if receipt_errors:
        for error in receipt_errors:
            print(f"qinao-wave-gate: ERROR: {error}", file=sys.stderr)
        return 1
    git_root = subprocess.run(
        [GIT, "rev-parse", "--show-toplevel"],
        cwd=root,
        text=True,
        capture_output=True,
        check=False,
    )
    if git_root.returncode != 0 or Path(git_root.stdout.strip()).resolve() != root:
        print("qinao-wave-gate: ERROR: --root must be the exact Git worktree root", file=sys.stderr)
        return 1
    candidate_snapshot, errors = candidate_index_snapshot(root)
    if args.candidate_tree is not None and (
        re.fullmatch(r"[0-9a-f]{40,64}", args.candidate_tree) is None
        or args.candidate_tree != candidate_snapshot.get("index_tree")
    ):
        errors.append("--candidate-tree differs from the admitted index tree")
    if errors:
        for error in errors:
            print(f"qinao-wave-gate: ERROR: {error}", file=sys.stderr)
        return 1
    manifest_argument_errors = canonical_manifest_argument_errors(args.manifest, root)
    if manifest_argument_errors:
        print(f"qinao-wave-gate: ERROR: {manifest_argument_errors[0]}", file=sys.stderr)
        return 1
    canonical_manifest, manifest_path_error = confined_path(
        root, "scripts/qinao_wave_gates_v1.json", kind="file"
    )
    if manifest_path_error is not None or canonical_manifest is None:
        print(f"qinao-wave-gate: ERROR: {manifest_path_error}", file=sys.stderr)
        return 1
    manifest = load_manifest(canonical_manifest)
    errors = validate_manifest_and_inputs(
        root, manifest, through=args.through, lane=args.lane
    )
    if args.through == "W6" and args.lane in {"all", "deterministic"}:
        errors.extend(w6_candidate_errors(root, args.candidate_tree))
    if errors:
        for error in errors:
            print(f"qinao-wave-gate: ERROR: {error}", file=sys.stderr)
        return 1
    with tempfile.TemporaryDirectory(prefix="qinao-wave-gate-") as temporary:
        scratch = Path(temporary)
        active_waves = active_wave_ids(args.through)
        # Phase A: all deterministic work for every active wave.
        for wave_id in active_waves:
            wave = manifest["waves"][wave_id]
            deterministic_checkers, platform_checkers = checker_phases(
                wave["checkers"], lane=args.lane
            )
            if args.lane != "platform":
                for scan in wave["negative_scans"]:
                    scan_errors = run_negative_scan(root, scan)
                    if scan_errors:
                        for error in scan_errors:
                            print(f"qinao-wave-gate: ERROR: {error}", file=sys.stderr)
                        return 1
                    if candidate_postflight_errors(root, candidate_snapshot):
                        print("qinao-wave-gate: ERROR: candidate changed after negative scan", file=sys.stderr)
                        return 1
            for checker_id in deterministic_checkers:
                checker_error = run_checker_id(root, checker_id, args.candidate_tree)
                if checker_error is not None:
                    print(f"qinao-wave-gate: ERROR: {checker_error}", file=sys.stderr)
                    return 1
                if candidate_postflight_errors(root, candidate_snapshot):
                    print("qinao-wave-gate: ERROR: candidate changed after checker", file=sys.stderr)
                    return 1
            if args.lane != "platform":
                for index, swift in enumerate(wave["swift"]):
                    command = swift_filter_command(
                        root,
                        scratch / f"{wave_id}-{index}",
                        scratch / f"{wave_id}-{index}-swift-receipt.json",
                        swift,
                    )
                    if run_command(command, root=root) != 0:
                        print(f"qinao-wave-gate: ERROR: Swift gate failed: {wave_id}/{index}", file=sys.stderr)
                        return 1
                    if candidate_postflight_errors(root, candidate_snapshot):
                        print("qinao-wave-gate: ERROR: candidate changed after Swift gate", file=sys.stderr)
                        return 1
        # Phase B: only after the entire deterministic phase succeeds, run the
        # globally ordered platform inventory for every active wave.
        for wave_id in active_waves:
            wave = manifest["waves"][wave_id]
            _, platform_checkers = checker_phases(wave["checkers"], lane=args.lane)
            for checker_id in platform_checkers:
                checker_error = run_checker_id(root, checker_id, args.candidate_tree)
                if checker_error is not None:
                    print(f"qinao-wave-gate: ERROR: {checker_error}", file=sys.stderr)
                    return 1
                if candidate_postflight_errors(root, candidate_snapshot):
                    print("qinao-wave-gate: ERROR: candidate changed after platform checker", file=sys.stderr)
                    return 1
    postflight_errors = candidate_postflight_errors(root, candidate_snapshot)
    if args.through == "W6" and args.lane in {"all", "deterministic"}:
        postflight_errors.extend(w6_candidate_errors(root, args.candidate_tree))
    if postflight_errors:
        for error in postflight_errors:
            print(f"qinao-wave-gate: ERROR: postflight: {error}", file=sys.stderr)
        return 1
    print(f"qinao-wave-gate: PASS through={args.through}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
```

The production implementation runs every `-z` Git observation as bytes, splits on NUL before strict UTF-8 decoding each field, and rejects undecodable, non-normalized, duplicate, case-colliding, or Unicode-normalization-colliding paths. The readable snippet above uses text only to keep the plan compact. A single `run_git` helper removes caller-controlled `GIT_DIR`, `GIT_WORK_TREE`, `GIT_INDEX_FILE`, config-injection, object-directory/alternate-object, namespace, and replace-ref variables; it supplies the fixed Git environment/config stated above. It opens the repository root and each component with pinned directory FDs and `O_NOFOLLOW`, compares pre/post `fstat`, and hashes the opened regular-file FD, so replacing an intermediate directory with a same-byte symlink cannot escape the root. All tracked candidate entries at this controlled boundary must be ordinary `100644`/`100755` files; symlinks and gitlinks are rejected. Mutation tests exercise newline/tab/non-UTF-8 names, non-zero Git exits, both special-index flag classes, executable-mode drift, hidden content drift, injected Git environment/config, and intermediate-directory replacement.

- [ ] **Step 5: Add exact child and aggregate gate receipts**

Extend `scripts/run_nonempty_swift_filter.py` with required `--receipt <path>`. The child receipt must use an absent path inside the wave runner's private `TemporaryDirectory`; it rejects symlinks and existing targets. On every exit after output admission it atomically writes schema-1 canonical JSON containing the exact list and execution argv arrays, listed identifiers/count, required suites, resolved execution filter, executed count parsed from the transcript, both exit codes, and `status`. A successful child receipt requires `listed_count == executed_count > 0`; a failure receipt never reports `pass`. Add tests for success, listing failure, zero-match success, count mismatch, unwritable/symlink/existing receipt path, and atomic no-partial-file behavior.

In the wave runner, replace the integer-only subprocess helper with an observation helper that tees stdout/stderr, records exact argv/exit code, and exposes allowlisted parsed counters. Write the aggregate receipt exactly once, by atomic temporary-file replacement, after validation succeeds or fails. Its top-level schema is:

```json
{
  "schema_version": 1,
  "status": "pass|fail",
  "failure_stage": null,
  "head_commit": "40-or-64-hex|null-on-unobserved-failure",
  "head_tree": "40-or-64-hex|null-on-unobserved-failure",
  "candidate_tree": "40-or-64-hex|null-on-unobserved-failure",
  "manifest_sha256": "64-hex|null-on-unobserved-failure",
  "through": "W0...W6",
  "lane": "all|deterministic|platform",
  "executables": {
    "python": {"path_redacted": "$PYTHON", "sha256": "64-hex", "version": "exact"},
    "bash": {"path_redacted": "/bin/bash", "sha256": "64-hex", "version": "exact"},
    "git": {"path_redacted": "/usr/bin/git", "sha256": "64-hex", "version": "exact"},
    "xcode_select": {"path_redacted": "/usr/bin/xcode-select", "sha256": "64-hex", "selected_developer_dir": "$XCODE/Contents/Developer"},
    "xcodebuild": {"path_redacted": "$XCODE/Contents/Developer/usr/bin/xcodebuild", "sha256": "64-hex", "version": "exact"},
    "xcrun": {"path_redacted": "/usr/bin/xcrun", "sha256": "64-hex", "version": "exact"},
    "resolved_swift": {"path_redacted": "$XCODE/<resolved-swift>", "sha256": "64-hex", "version": "exact"}
  },
  "toolchains": {
    "xcodebuild_version": ["exact output lines"],
    "swift_version": "exact first line",
    "iphoneos_sdk_version": "exact output"
  },
  "k4_attestation_match": true,
  "k4_predecessor": {
    "proof_commit": "40-or-64-hex",
    "proof_tree": "40-or-64-hex",
    "evidence_root_sha256": "64-hex",
    "policy_commit": "40-or-64-hex",
    "platform_policy_blob_sha256": "64-hex"
  },
  "waves": [
    {
      "wave": "W0",
      "required_path_count": 1,
      "negative_scans": [
        {"id": "scan-id", "scanner": "python-stdlib-regex-v1", "regular_file_count": 1, "match_count": 0}
      ],
      "checkers": [
        {"id": "checker-id", "argv_redacted": ["python3"], "argv_sha256": "64-hex", "candidate_count": 1, "receipt_count": 1, "exit_code": 0}
      ],
      "swift": [
        {"package_path": "relative/path", "required_suite_count": 1, "listed_test_count": 1, "executed_test_count": 1, "exit_code": 0}
      ]
    }
  ],
  "totals": {
    "required_path_count": 1,
    "review_path_count": 1,
    "candidate_count": 1,
    "owner_receipt_count": 1,
    "owner_count": 29,
    "m_allowlist_count": 14,
    "create_permission_count": 14,
    "controlled_document_count": 7,
    "glob_file_count": 1,
    "listed_test_count": 1,
    "executed_test_count": 1
  },
  "device": null,
  "exit_code": 0
}
```

The numeric values above show types, not fixed W0 counts; the unit test compares the real canonical manifest with an exact expected inventory and computes the exact receipt counts from it. The schema is closed: missing/extra fields, duplicate JSON keys, non-canonical serialization, malformed executable digests, and illegal lane-specific nulls fail. A central failure funnel owns the receipt state. On success, `failure_stage` and no observation are null. On failure, `failure_stage` is one closed enum (`git-root`, `candidate-index`, `manifest-path`, `manifest-bytes`, `manifest-schema`, `input-admission`, `toolchain`, `w6-preflight`, `negative-scan`, `checker`, `swift-list`, `swift-run`, `platform`, `candidate-postflight`, or `w6-postflight`), already observed values remain exact, and not-yet-observed values are JSON `null`; failure receipts never fabricate hashes, counts, device data, or toolchain output. The observation funnel always runs candidate postflight after an attempted negative scan/checker/Swift/platform command, even if that command failed, before choosing the final failure stage. Only CLI parse failure, invalid/unwritable receipt admission, process termination before Python control can begin, or the no-replace publication race described below may lack this invocation's own receipt. Tests force every early and late failure stage.

`candidate_tree` is always the candidate-index tree from `git write-tree`; `head_tree` is `HEAD^{tree}`. Before the manifest or any other repository input is read, all lanes reject conflicts, tracked unstaged bytes, special index flags, and untracked paths—including ignored paths—so every subsequently observed worktree byte belongs to that candidate index. Every lane repeats the full snapshot after each attempted gate and at final postflight. W0–W5 may validate a fully staged candidate whose index tree differs from HEAD. W6 `all`/`deterministic` additionally requires clean detached HEAD and exact equality among `--candidate-tree`, index tree, and HEAD tree throughout. `device` is `null` for deterministic-only runs. Platform/all reads the already validated K4 `status.json` and records only platform, OS version/build, hashed UDID, install/launch, and phase monitor counts.

The owner checker emits exactly `owner-ledger: PASS candidates=<n> receipts=<n> owners=29 m_allowlist=14 create_permissions=14 controlled_documents=7`; the review checker emits exactly `qinao-review-candidate: PASS paths=<n>`. The runner accepts no other success grammar. In `deterministic` and `all`, candidate/owner-receipt/review/cardinality values are mandatory, non-zero where applicable, and exactly `29/14/14/7`; in the disjoint `platform` receipt those non-executed fields are JSON `null`, never fabricated zeroes. Conversely, the deterministic receipt has `device: null`. Receipt validation tests assert these lane-specific shapes and the `all` receipt's exact union.

Implement that owner success grammar in this Task 2 commit, before the K4 predecessor can call the deterministic lane. Extend `scripts/test_check_qinao_owner_ledger.py` with exact stdout tests and zero/missing/non-decimal/duplicate/wrong-cardinality/legacy-grammar mutations. Later controlled-document edits may change validated digests and terms but must retain this machine interface unchanged.

For every command, compute `argv_sha256` over one exact byte grammar: unsigned 64-bit big-endian argument count, followed for each argument by unsigned 64-bit big-endian UTF-8 byte length and then those exact bytes. Then persist `argv_redacted`: paths inside the Git root become `$ROOT/<normalized-relative>`, private scratch/receipt paths become `$TMP/<typed-slot>`, the selected Xcode becomes `$XCODE/...`, and values after team/device/profile environment selectors, tokens, and future sensitive options become typed SHA-256 markers. Raw values live only long enough to hash in memory. Golden-vector tests cover zero arguments, an empty argument, `NUL` rejection, non-ASCII UTF-8, workspace paths, and temp paths. Stdout/stderr uses the same structured redaction before persistence; a whole-receipt byte scan rejects `/Users/`, runner account/home/workspace paths, raw env values, UUIDs, and UDIDs.

Toolchain observation is a shared preflight, not manifest-provided checker inventory. Every lane runs the selected `$DEVELOPER_DIR/usr/bin/xcodebuild -version`, fixed `/usr/bin/xcrun swift --version`, and `/usr/bin/xcrun --sdk iphoneos --show-sdk-version` exactly once, records the outputs, and binds the xcrun-resolved Swift executable path/digest. Before approved evidence exists, a deterministic-only development receipt records `k4_attestation_match: null`; after it exists, every lane records `true` only after all observations match K4 `toolchain-attestation.json`; `false` is never a passing value. Thus the two independent CI shards cannot both pass on a toolchain that would fail `all`. Workflow/runner tests prove the shared-preflight ordering and checker-lane partition.

`k4_predecessor` is non-null for `platform`/`all` success and for deterministic success after approved evidence exists. `proof_commit` is the unique latest commit whose diff touches the exact approved-evidence subtree; that commit must be proof-only, its `proof_tree` is bound, and no later commit may touch evidence or platform-policy paths—even if final bytes are restored. `policy_commit` is the unique reviewed policy-only ancestor and its exact blob digest is bound separately. These values are reconstructed from Git, never trusted from status text or `/tmp`; pre-proof deterministic receipts use `null`. Task 6 requires the final `all` object to match Git exactly and mutation-tests touch-then-revert history.

The aggregate `--receipt` contract is enforced before repository validation: absolute normalized path, absent non-symlink leaf, real parent, outside the Git root, confined under `/tmp` or `RUNNER_TEMP`, and no symlink below that trusted root. The writer opens the parent with `O_DIRECTORY|O_NOFOLLOW`, pins its device/inode by `fstat`, creates a mode-`0600` sibling through that directory FD, writes canonical bytes, flushes/file-`fsync`s, then uses dirfd-relative no-replace link publication, directory-`fsync`s the same pinned FD, and unlinks the sibling. `EEXIST` is a hard failure: incumbent bytes remain untouched and this invocation cannot publish a competing fail receipt, which is the sole admitted-output exception. Race tests replace the parent or create the final leaf between admission/publication and prove escape/overwrite is impossible.

Add mutation tests that corrupt each receipt counter/field, omit/add schema fields, suppress child receipt creation, reorder a platform checker ahead of deterministic/Swift work in `all`, replace/delete one manifest gate, supply a relative/canonical-symlink/`..` manifest alias, target an existing/repository/symlink receipt, introduce tracked-unstaged/untracked/special-flag input, mutate any W0–W6 lane during each gate kind, and force every subprocess failure. Each admitted-output case returns non-zero and writes `status=fail` with the failing exact command/exit except the proven no-replace race; every mutation is caught by postflight even when the mutating gate itself fails.

Add a mutually exclusive, read-only verification mode to the **same** runner so no unreviewed verifier file expands the surface:

```text
run_qinao_wave_gate.py
  --root <clean-candidate-root>
  --verify-receipt <external-receipt>
  --expected-head-commit <object-id>
  --expected-head-tree <object-id>
  --expected-manifest-sha256 <64-hex>
  --expected-review-path-count <integer>
  --expected-through <W0...W6>
  --expected-lane <all|deterministic|platform>
  [--expected-k4-predecessor-archive <canonical-archive>]
  [--external-k4-verification-receipt <fresh-attester-receipt>]

run_qinao_wave_gate.py
  --root <clean-candidate-root>
  --verify-w0-scope
  --source-commit <sealed-baseline-commit>
  --final-commit <candidate-commit>
```

`--verify-receipt` performs no gate and writes nothing. It rejects duplicate keys, non-canonical bytes, extra/missing fields, wrong lane nullability, and any expected-value mismatch; reopens the canonical manifest and derives the exact active waves/checkers/scans/Swift specs/suites/totals rather than trusting receipt counters; reruns candidate/Git predecessor reconstruction read-only; and validates executable/toolchain/device shapes. For final W0 it requires exact derived constants `required_paths=30`, `checkers=8` (`7 deterministic + 1 platform`), `negative_scans=1`, `swift_specs=2`, `required_suites=4`, `review_paths=52`, and owner shapes `29/14/14/7`. When a predecessor archive is supplied, it validates that archive's separate closed canonical schema and requires exact equality with `receipt.k4_predecessor`; when the external K4 verification receipt is supplied, it cross-binds that canonical receipt's digest, artifact digest, run/policy/projection identities, CDHashes, and verifier epoch. Add same-file unit mutations for every field, count, canonicalization rule, Git predecessor/archive, and external-receipt linkage.

`--verify-w0-scope` is also read-only. The same-file test pins the exact 32 static `(status,path)` changes enumerated in Task 6 plus the checker-emitted exact approved-evidence file tuple. It rejects merges, renames/copies, missing/extra/net-wrong changes, and any production Swift/Rust/C/C++/Metal/SQL path outside the three isolated fixture files. It additionally walks every commit on the single-parent ancestry path and checks each parent→commit touched tuple against that task's exact commit boundary, so an add/modify followed by restore/delete cannot disappear from the net diff. Mutations cover an extra production path, rename, delete, case/Unicode alias, merge, and touch-then-revert history.

The same module exposes `load_certification_run_state(path)`. It accepts only an owner-held mode-`0600` regular file beneath the private certification directory, opened through a pinned no-follow parent FD, with canonical schema `{schema_version,source_commit,final_commit,final_tree}` and exact object-ID grammar. It rejects duplicate/extra/missing keys, non-canonical bytes, symlink/hardlink/owner/mode drift, and a commit/tree mismatch. Every later Task 6 step re-runs `--verify-w0-scope`, so changing the state to a different otherwise valid object cannot self-authorize a new candidate.

- [ ] **Step 6: Run mutation tests and syntax validation**

Run:

```bash
python3 -m unittest scripts.test_run_qinao_wave_gate -v
python3 -m py_compile scripts/run_qinao_wave_gate.py scripts/test_run_qinao_wave_gate.py
RUN_DIR="$(mktemp -d "${RUNNER_TEMP:-/tmp}/qinao-w0-initial.XXXXXX")"
trap 'rm -rf "$RUN_DIR"' EXIT
if python3 scripts/run_qinao_wave_gate.py \
  --root "$PWD" \
  --manifest "$PWD/scripts/qinao_wave_gates_v1.json" \
  --through W0 \
  --lane all \
  --receipt "$RUN_DIR/receipt.json"
then
  echo "unexpected W0 success before approved K4 proof" >&2
  exit 1
fi
test -s "$RUN_DIR/receipt.json"
```

Expected: unit and syntax tests PASS. The real W0 invocation must fail closed until the candidate is clean/index-bound and `qinao-k4-platform-proof-approved` exists; it must not report `PASS` on the current dirty worktree.

- [ ] **Step 7: Commit the isolated tooling**

```bash
git add \
  scripts/qinao_wave_gates_v1.json \
  scripts/run_qinao_wave_gate.py \
  scripts/test_run_qinao_wave_gate.py \
  scripts/run_nonempty_swift_filter.py \
  scripts/test_run_nonempty_swift_filter.py \
  scripts/check_qinao_owner_ledger.py \
  scripts/test_check_qinao_owner_ledger.py
git commit -m "test: add cumulative Qinao wave gate"
```

Expected: one tooling-only commit. It adds no production authority and is not yet wired into CI.

### Task 3: Satisfy the Real K4 Hard Predecessor

**Files and exact implementation steps:** Appendix A, “Normative implementation steps for Task 3,” below.

**Interfaces:**
- Consumes: the privacy-clean probe-source baseline, Task 2 candidate-bound runner, an independently reviewed release Xcode/iOS build policy, explicit manual-signing profile selectors, and one physical target device.
- Produces: the hardening commit, a prior policy-only reviewed commit, then a proof-only commit containing one independently validated approved K4 evidence bundle.
- Ordering invariant: execute every Appendix A step now, through its proof-only commit, before entering Task 4. This is a hard W0 predecessor from approved addendum §10.4, not a later CI convenience. A beta/prerelease/unapproved toolchain or OS build, unavailable Enhanced Security entitlement, profile mismatch, install/launch/runtime failure, or missing physical device returns the architecture to review and leaves Task 4 forbidden.

- [ ] **Step 1: Execute Appendix A Steps 1–10 and record the three exact commits**

Expected commit order is: `(1) producer/checker/probe-source hardening`, `(2) reviewed release-policy only`, `(3) immutable approved evidence only`. Verify that the third commit is a descendant of the first two, that the platform receipt binds its index tree, and that no seven-document controlled merge exists in the range before the proof commit.

- [ ] **Step 2: Refuse the merge unless the predecessor is machine-green**

From the clean proof commit, create a fresh mode-`0700` run directory and absent receipt leaf, then run the direct checker and `--through W0 --lane platform`; both must pass. The authoritative predecessor identity is reconstructed from Git as `proof_commit` (the unique latest proof-only commit touching the exact approved subtree), `proof_tree`, committed evidence-root digest, `policy_commit`, and committed platform-policy blob digest. Require the later-history touched-path set for evidence/policy to be empty, not merely a clean net diff. Atomically create a mode-`0600`, no-replace predecessor archive inside that run directory with those fields plus the platform receipt SHA-256. Invoke the runner's `--verify-receipt` with `--expected-k4-predecessor-archive` so the platform receipt, archive, and live Git object agree exactly. Task 4 begins only from that exact commit. Never copy or relabel preliminary evidence to satisfy this step.

### Task 4: Atomically Merge the Addendum into the Seven Controlled Documents and Owner Ledger

**Files:**
- Modify: all seven paths in `Controlled Document Inventory`
- Modify: `docs/superpowers/specs/qinao-owner-ledger-v1.json`
- Modify: `scripts/check_qinao_owner_ledger.py`
- Modify: `scripts/test_check_qinao_owner_ledger.py`
- Modify: `scripts/test_qinao_plan_remediation.py`

**Interfaces:**
- Consumes: approved addendum commit `a82a7bb0b4e4f5680117df3b92593fa90c9d85a3`, the authoritative K3 addendum, the Task 1 recovery-owner map, the exact Owner Ledger cardinalities, and the reopened Task 3 K4 predecessor record.
- Produces: one atomic reviewed candidate in which all seven controlled documents, owner rows, work-package rows, reviewed digests, and required terms describe the same W0–W6 system.
- Atomicity rule: none of the seven controlled documents may be committed alone. The seven documents, ledger, checker constants, and their semantic tests are one commit and one review unit.

- [ ] **Step 0: Reopen and enforce the K4 predecessor before editing a controlled document**

Reconstruct the unique latest proof-only `proof_commit`/`proof_tree`, policy-only `policy_commit`/blob, and committed evidence/policy digests directly from Git, then optionally compare the archived predecessor record if present. Require current HEAD to equal `proof_commit` at Task 4 entry, recompute all digests, and rerun the K4 checker. If work resumed from a descendant, require `proof_commit` to be an ancestor and prove that neither the evidence/policy paths nor any of the exact seven controlled documents changed in the intervening range. The final aggregate receipt carries this immutable reconstructible predecessor object; an absent, non-unique, or drifting Git identity blocks the merge.

#### Canonical owner and interface map for the merge

| Adopted truth | Existing Owner Ledger owner | Exact interface/location |
|---|---|---|
| material manifest and canonical `bundleDigest` evolution | `model.manifest-invocation` | `ModelMaterialManifestArtifactID` is a `BASArtifactID` reference carried by the existing model manifest/invocation owner |
| selected material variant, `sourceSpecialization\|AOT`, options, fallback arms | `execution.plan-provider-router` | existing `BASExecutionPlan`/profile/binding artifacts; no specialization registry |
| private bytes/content directories/reader leases/bookmark/cache/pointer CAS | `provider.package-boundary` | concrete Provider package mechanism; pointer resolves an already selected digest and owns no route/default |
| K3 revocation fence and post-journal publication closure | `state.k3-control-nucleus` | same `BASSQLiteEventLogStorage` `WAL + synchronous=FULL` transaction owner |
| material authorization floor and actual revoke | `sovereign.k4-durable-lifecycle` | helper-private K4 lifecycle; invoked only after K3 fence |
| publication reserve/finalize/reconcile | `release.spool-publication` | independent publication journal plus `BASResponseReleaseCoordinator` |
| effect dispatch/reconcile | `effect.zone-c-saga` | independent Zone-C journal and one boundary anchor |
| exact candidate/path E4 and canary E5 verdicts | `runtime.certification` | immutable evidence only |
| canary/full deployment joins and rollback tree | `production.cutover` | build/deployment-time sealed-tree joins; no runtime state machine |
| Attempt-frozen Main Agent, role graph, delegation/capsule identity, and independent ContextWindow membership | `runtime.turn-operation` | immutable Attempt/operation values only; no model route, branch allocation, mutable session, or state write |
| sole bounded reasoning/RSI loop scheduler and proposal adoption sequence | `runtime.semantic-executor` | consumes immutable artifacts/receipts; K3 remains the only branch/budget/progress authority |

#### Canonical cross-plan value flow

```text
ModelMaterialManifestArtifactID
  -> exact selected variant digest
  -> BASSpecializationKey(material + variant + immutable URL + device/OS/runtime + options + namespace)
  -> BASCacheHandleReceipt(post-specialization policy/bookmark/state; bookmark is not identity)
  -> CertifiedBackendProfile(exact SKU/OS/path/options/evidence/verdict)
  -> BASExecutionPlan(exact independently certified arm)
  -> K1 reservation/HeavyPhase
  -> K2 immutable pin
  -> K3 allocation/claim/use lineage
```

```text
BASContextCapsule.attemptFrame
  = root + snapshot + generation vector + task + budget lease ref + grant ref

BASContextCapsule.providerStep
  = reopened K3 allocation receipt
  + one canonical BASProviderExecutionRef
  + exact role-specific R5 reservoir/grounding request OR R6 descriptor
  + exact BASExecutionPlan/profile/policy/receipt references
```

No optional all-fields capsule, predicted future ID, copied remaining budget, raw CoT, ambient tool/database handle, or cross-window mutable prompt is permitted.

- [ ] **Step 1: Add semantic tests for the four P0 contradictions and owner map**

Add these paths near the existing plan constants in `scripts/test_qinao_plan_remediation.py`:

```python
ARCHITECTURE = ROOT / "docs/superpowers/specs/2026-07-14-iphone-air-future-apple-silicon-architecture-design.md"
CONTRACTS = PLANS / "2026-07-15-iphone-air-contracts-layercell.md"
SILICON = PLANS / "2026-07-15-iphone-air-silicon-execution-spine.md"
SEMANTIC = PLANS / "2026-07-15-iphone-air-semantic-statelake-context.md"
SOVEREIGN = PLANS / "2026-07-15-iphone-air-sovereign-release-effects.md"
RUNTIME = PLANS / "2026-07-15-iphone-air-runtime-replay-certification.md"
```

Add the exact tests:

```python
def test_controlled_document_inventory_is_architecture_master_five_domains(self) -> None:
    from scripts import check_qinao_owner_ledger as checker

    expected = (
        "docs/superpowers/specs/2026-07-14-iphone-air-future-apple-silicon-architecture-design.md",
        "docs/superpowers/plans/2026-07-15-iphone-air-architecture-convergence-master.md",
        "docs/superpowers/plans/2026-07-15-iphone-air-contracts-layercell.md",
        "docs/superpowers/plans/2026-07-15-iphone-air-silicon-execution-spine.md",
        "docs/superpowers/plans/2026-07-15-iphone-air-semantic-statelake-context.md",
        "docs/superpowers/plans/2026-07-15-iphone-air-sovereign-release-effects.md",
        "docs/superpowers/plans/2026-07-15-iphone-air-runtime-replay-certification.md",
    )
    self.assertEqual(tuple(checker.EXPECTED_CONTROLLED_DOCUMENTS), expected)

def test_w4_keeps_coreai_and_afm_nonproduction(self) -> None:
    master = MASTER.read_text(encoding="utf-8")
    silicon = SILICON.read_text(encoding="utf-8")
    for contents in (master, silicon):
        self.assertIn("incumbent MLX", contents)
        self.assertIn("Core AI/AFM", contents)
        self.assertIn("shadow/device-validation", contents)
        self.assertIn("no Core AI production cutover in W4", contents)

def test_w5_keeps_production_publication_disabled(self) -> None:
    master = MASTER.read_text(encoding="utf-8")
    sovereign = SOVEREIGN.read_text(encoding="utf-8")
    for contents in (master, sovereign):
        self.assertIn("production publication remains disabled through W5", contents)
    self.assertIn("journal finalize -> K3 publication-boundary close", sovereign)

def test_runtime_has_two_separate_deployment_joins_after_e4(self) -> None:
    runtime = RUNTIME.read_text(encoding="utf-8")
    task7 = runtime.split("### Task 7 [W6]", 1)[1]
    self.assertIn("E4 produces evidence and performs no deployment", task7)
    self.assertIn("Join 1", task7)
    self.assertIn("immutable E5", task7)
    self.assertIn("Join 2", task7)
    self.assertLess(task7.index("Join 1"), task7.index("immutable E5"))
    self.assertLess(task7.index("immutable E5"), task7.index("Join 2"))
    self.assertNotIn("E4-certified tree directly becomes production", task7)

def test_existing_owners_cover_material_revoke_publication_and_cutover(self) -> None:
    ledger = json.loads(
        (ROOT / "docs/superpowers/specs/qinao-owner-ledger-v1.json").read_text(encoding="utf-8")
    )
    owners = {item["owner_id"]: item for item in ledger["owners"]}
    required = {
        "model.manifest-invocation": "ModelMaterialManifestArtifactID",
        "execution.plan-provider-router": "sourceSpecialization|AOT",
        "provider.package-boundary": "CacheHandleReceipt",
        "state.k3-control-nucleus": "RevocationFenceReceipt",
        "sovereign.k4-durable-lifecycle": "minimum material authorization epoch",
        "release.spool-publication": "journal finalize",
        "effect.zone-c-saga": "one boundary anchor",
        "runtime.certification": "immutable E5",
        "production.cutover": "Join 2",
        "runtime.turn-operation": "BASDelegationProposal",
        "runtime.semantic-executor": "convergedVerified",
    }
    positive_owner_fields = (
        "domain",
        "authority_owner",
        "mutable_state_owner",
        "storage_owner",
        "recovery_owner",
        "retirement_gate",
    )
    for owner_id, term in required.items():
        card = {field: owners[owner_id][field] for field in positive_owner_fields}
        self.assertIn(term, json.dumps(card, ensure_ascii=False))
        self.assertNotIn(
            term,
            json.dumps(owners[owner_id]["forbidden"], ensure_ascii=False),
            f"{owner_id} launders positive ownership through a prohibition",
        )

def test_encrypted_raw_content_is_approved_not_an_open_decision_gate(self) -> None:
    master = MASTER.read_text(encoding="utf-8")
    semantic = SEMANTIC.read_text(encoding="utf-8")
    task4a = semantic.split("### Task 4A:", 1)[1].split("### Task 4B:", 1)[0]
    for contents in (master, task4a):
        self.assertIn("encrypted content-addressed artifact", contents)
        self.assertIn("cold reopen", contents)
        self.assertIn("erase-together", contents)
    self.assertNotIn("Decision Gate", task4a)
    self.assertNotIn("disapproved branch", task4a)

def test_agent_context_and_rsi_values_have_one_w1_owner(self) -> None:
    contracts = CONTRACTS.read_text(encoding="utf-8")
    task2a = contracts.split("### Task 2A:", 1)[1].split("### Task 3:", 1)[0]
    for term in (
        "BASAgentRole",
        "BASDelegationProposal",
        "BASContextCapsule",
        "BASRSIContractTests",
        "convergedVerified",
        "repeated canonical digest",
        "zero raw CoT",
        "eight concurrent windows",
    ):
        self.assertIn(term, task2a)
    self.assertNotIn("BASAgentRegistry", task2a)
    self.assertNotIn("fifth control ring", task2a)

def test_k4_proof_has_an_honest_producer_and_semantic_entitlement_comparison(self) -> None:
    sovereign = SOVEREIGN.read_text(encoding="utf-8")
    for term in (
        "approved release-build allowlist",
        "proof-production runbook",
        "exact seven-key Enhanced Security projection",
        "signed team and application identifiers are public binary identity",
        "raw device UDID never enters repository evidence",
    ):
        self.assertIn(term, sovereign)
    self.assertNotIn(
        'cmp "$EVIDENCE/host-signed-entitlements.plist"',
        sovereign,
    )
    self.assertNotIn(
        'cmp "$EVIDENCE/extension-signed-entitlements.plist"',
        sovereign,
    )
```

In the same test file, add `CONTROLLED_DECISION_TRACE` as an exact tuple of `(document, section_start, section_end, required_terms, forbidden_terms)` records. It must cover at least these scoped records, and the test fails if a boundary is missing, a required term is absent/duplicated outside its owner scope, or a forbidden term remains:

| Scope | Required terms | Forbidden terms |
|---|---|---|
| Contracts Task 2A | `BASAgentRole`, `BASDelegationProposal`, `BASContextCapsule`, `BASRSIContractTests`, `eight concurrent windows`, `zero raw CoT` | `BASAgentRegistry`, `fifth control ring`, `shared mutable KV` |
| Semantic Task 1 | `ConstraintLedger`, `reversible source span`, `perspective`, `known\|unknown\|contradicted`, `progress/novelty/obligation` | `raw CoT payload`, `second solver authority` |
| Semantic Task 4A | `encrypted content-addressed artifact`, `cold reopen`, `erase-together` | `Decision Gate`, `disapproved branch`, `digest-only authoritative memory` |
| Semantic Tasks 5–7 | `hard eligibility`, `exact/FTS/BM25/temporal/entity/dense`, `qualifier/negation/coreference closure`, `final L7 State Market` | `physical lookup before eligibility`, `Granite Agent` |
| Silicon W0/Tasks 1/3/7 | `Qwen/Qwen3.5-4B@851bf6e806efd8d0a36b00ddf55e13ccb7b8cd0a`, `qwen3.5-4b-text-only/no-mtp-certified`, `ModelMaterialManifestArtifactID`, `sourceSpecialization\|AOT`, `ProcessorABI`, `CacheHandleReceipt`, `Core AI 0.4.0` | `Qwen vision inherited`, `MTP certification inherited`, `second model registry` |
| Sovereign Tasks 1/3/5/6 | `RevocationFenceReceipt`, `journal finalize -> K3 publication-boundary close`, `approved release-build allowlist`, `exact seven-key Enhanced Security projection` | whole-file entitlement `cmp`, `republish after possible success`, `same-process K4 fallback` |
| Runtime Tasks 1/2/4/6/7 | `NextQuestionProjection`, `eight-window stress`, `BASControlLoopReplayTests`, `E4 produces evidence and performs no deployment`, `Join 1`, `immutable E5`, `Join 2` | persisted question candidate text/score, direct E4 production, one tree satisfying both joins |

The test also asserts every suite in `scripts/qinao_wave_gates_v1.json` is either already named in its owning 2026-07-15 domain task or appears in the exact future-suite table added by Step 5. This prevents the manifest from inventing a suite that no implementation step creates.

- [ ] **Step 2: Run the focused semantic tests and observe real failures**

Run:

```bash
python3 -m unittest \
  scripts.test_qinao_plan_remediation.QinaoPlanRemediationTests.test_controlled_document_inventory_is_architecture_master_five_domains \
  scripts.test_qinao_plan_remediation.QinaoPlanRemediationTests.test_w4_keeps_coreai_and_afm_nonproduction \
  scripts.test_qinao_plan_remediation.QinaoPlanRemediationTests.test_w5_keeps_production_publication_disabled \
  scripts.test_qinao_plan_remediation.QinaoPlanRemediationTests.test_runtime_has_two_separate_deployment_joins_after_e4 \
  scripts.test_qinao_plan_remediation.QinaoPlanRemediationTests.test_existing_owners_cover_material_revoke_publication_and_cutover \
  scripts.test_qinao_plan_remediation.QinaoPlanRemediationTests.test_encrypted_raw_content_is_approved_not_an_open_decision_gate \
  scripts.test_qinao_plan_remediation.QinaoPlanRemediationTests.test_agent_context_and_rsi_values_have_one_w1_owner \
  scripts.test_qinao_plan_remediation.QinaoPlanRemediationTests.test_k4_proof_has_an_honest_producer_and_semantic_entitlement_comparison -v
```

Expected: the inventory test passes; the W4, W5, W6, K4-proof, and owner-row tests fail against the current controlled documents/ledger.

- [ ] **Step 3: Merge the target state into the architecture design**

Modify the architecture design in its existing sections; do not append an unowned alternative architecture:

| Architecture section | Exact adopted delta |
|---|---|
| §4.4 owner map/CreateGate | add the eleven-row owner map above; state explicitly that all are E/A extensions of existing owners |
| §10.1 SDK/Provider | external portfolio is pinned `Qwen/Qwen3.5-4B` with initial text-only/no-MTP certified variant, AFM, MiniCPM5-1B, MiniCPM-V 4.6, and Granite 97M; LLMs remain proposal-only outside SDK |
| §18.2, §20.1–20.2, §21.1 | add material/variant/path/options, specialization/cache identity, Core AI-only boundary, and allowlisted Core ML microhead exception |
| §23–§25 | add StateABI/ProcessorABI, single-driver mutable session, poison-on-partial-stage-fault, AFM opaque lease, and exact cancellation/quiescence rules |
| §26, §28–§30 | add publication finalize then K3 close, material authorization epoch/revoke, and the single-anchor K3/K4/Zone-C order |
| §32.2 | replay binds material/profile/plan/release-manifest references without copying Provider lineage |
| §33.7, §35, §37, §39, §41, §42 | add CoreAI 0.4.0 deny, two deployment joins, corrected W0–W6 wave boundaries, and optional 40/30 claims |

Use the exact phrases required by the semantic tests. Remove any statement that generative Core AI remains permanently research-only, that all learned microheads must become Core AI, or that an E4 verdict itself authorizes production. Normatively replace Architecture §20.1's legacy “Foundation Models sidecar/auxiliary only” rule: on iOS 27, AFM may be the sole Attempt-frozen Main Agent selected at admission, but never an implicit fallback or second sovereign path. A semantic test fails if the old sidecar-only sentence and AFM-Main admission coexist.

- [ ] **Step 4: Replace the master wave semantics and type graph**

In the convergence master:

1. Global Constraints must name the seven controlled documents, the conditional recovery contract, the four full 40-hex source candidates plus Qwen's initial text-only/no-MTP certified variant, the Core AI-only boundary, and the two deployment joins. Controlled source manifests forbid `main`, tags, short revisions, and angle-bracket placeholders.
2. Capability Ledger must extend existing rows for material, Provider package bytes, K3 revoke/publication close, K4 material floor, certification, and cutover. It must not add a tenth owner.
3. Canonical Cross-Plan Type Graph must contain the material-to-plan flow and strict ContextCapsule flow above, plus `DelegationProposal -> attenuated BASContextCapsule -> ProviderProposal -> verification/adoption receipt` and the receipt-driven RSI progress/terminal chain.
4. Replace W0–W6 rows with these exact boundaries:

```markdown
| **W0 — platform and normative convergence** | Complete the real K4 platform proof, freeze incompatible Core AI 0.4.0 assets, map recovery lifecycle/floors/receipts, then atomically merge the seven controlled documents and Owner Ledger. | No W1 production edit may begin while the W0 cumulative gate is red. |
| **W1 — immutable model-neutral contracts** | Declare Agent/ContextCapsule/reasoning/material-reference/RSI/DAG/NextQuestion values and Provider inversion only. | No install, specialization, cache, StateABI, branch actuation, or production activation. |
| **W2 — K3 and memory recovery** | One K3 FULL nucleus owns Attempt/branch/budget/state/revocation fence/publication-close truth and memory/erasure convergence. | No K4, publication-journal, Zone-C, or production Provider write. |
| **W3 — pre-physical semantic context** | Snapshot-bound eligibility/retrieval/grounding/State Market/context compiler. | Provider paths remain test-injected or shadow-only. |
| **W4 — admitted incumbent execution and Core AI shadow** | Make the unique physical claim/actuation seam authoritative; incumbent MLX remains the only production caller while Core AI/AFM material, plan, cache, session, and device evidence stay shadow/device-validation. | no Core AI production cutover in W4. |
| **W5 — dormant sovereign release/effect mechanism** | Implement/fault-test K4, publication journal, response coordinator, Zone C, material revoke, and exact boundary order. | production publication remains disabled through W5. |
| **W6 — replay, two deployment joins, and retirement** | Integrate the authoritative DAG, activate publication after replay manifest, earn E4, perform Join 1/canary/E5, then Join 2/full cutover, and retire the legacy route. | 40/30 claims are optional and workload-qualified. |
```

Any optional `cold40`/`sustained30` request names one exact target hardware profile, not merely “iPhone Air”: ProductType/SKU, SoC, GPU/ANE class, physical memory, OS release build, runtime, material/variant, quantization, StateABI/ProcessorABI, prompt/output lengths, sampler, power/ambient/thermal/cache state, and confidence method. Both independent device receipts must match that profile and have distinct hashed UDIDs. A faster Pro/other SKU cannot certify an Air claim; cross-SKU results are separately named profiles and never extrapolated.

5. Migration rules must quarantine Core AI 0.4.0 material, preserve reader leases across pointer CAS, require independently certified source-specialization fallback, and roll back only by deploying another certified sealed tree.
6. Resolve the old raw-content Decision Gate in favor of the approved encrypted content-addressed artifact path: canonical source bytes, reversible spans, provenance, scope key/DEK reference, deletion epoch, and Artifact ID persist together; digest-only records are insufficient for cold replay. Remove the disapproved branch and require erase-together closure across artifact, key, references, projections, caches, backups, quarantine, and Provider derivatives.
7. W1 explicitly owns main/sub role values, `DelegationProposal`, independent ContextCapsules, eight-window isolation, zero raw CoT, semantic-vs-transport status, bounded receipt-driven RSI values, and transient NextQuestion; no Agent registry, fifth control ring, or mutable cross-window scheduler is introduced.
8. Acceptance and Program Verification must call the cumulative wave gate and retain the three high-cost full-suite/device loops after it.

- [ ] **Step 5: Merge model-neutral W1 contracts into the owning plans**

Update the domain plans without duplicating declarations:

| Plan/task | Must own | Must explicitly not own |
|---|---|---|
| Contracts Task 2A | `BASAgentRole` main/sub/specialist values, `BASDelegationProposal`, strict tagged `BASContextCapsule`, minimum disclosure, one `BASProviderExecutionRef`, semantic-vs-transport status, independent-window identity, and the existing receipt-driven RSI envelope/progress/obligation/terminal value extensions | model selection, retrieval, execution, cache, mutable budget, Agent registry, fifth ring, raw CoT |
| Semantic Task 1 | raw-span-bound ConstraintLedger, reasoning candidates/critique/uncertainty/verification, temporal correction, retrieval/grounding/market value contracts | model bytes, Core AI, K4, publication, deployment |
| Silicon Task 1 | `ModelMaterialManifestArtifactID` as canonical bundle evolution, selected variant, `BASSpecializationKey`, path/options references, Qwen text-only capability denial | install/specialize/cache/session/StateABI before W4 |
| Runtime Task 1 Part A | immutable semantic DAG/join contract and transient `NextQuestionProjection` value/CAS identity | DAG execution, persistence of candidate text/scores, pre-tap work |

The contracts plan must continue to list Task 2A explicitly wherever W1 tasks are enumerated. Its presence matrices deny Granite as an Agent, deny MiniCPM-V on text-only work, deny a mid-turn main-model swap, deny mutable state/KV sharing across capsules, and permit collaboration only by immutable artifact/receipt ID. RSI adoption requires `converged + convergedVerified` plus the committed budget-use/progress receipt; budget exhaustion, repeated canonical digest, unmet fixed obligation, no-progress, cancellation, uncertainty, and verification failure remain typed non-authoritative terminal outcomes.

Main-Agent choice is exactly one admission-time capability value: the pinned Qwen text-only/no-MTP certified variant or AFM. It is frozen for the Attempt; failure cannot silently switch the main model mid-turn. MiniCPM5-1B is a bounded text-specialist proposal role, MiniCPM-V 4.6 is a visual-specialist proposal role requiring an eligible visual input/grant, and Granite 97M is reachable only through the retrieval embedding seam. None may commit state, allocate branches, publish, dispatch effects, or become an alternate scheduler.

The existing Agent Fabric is an incumbent migration source, not a second permanent nervous system. Add this exact retirement matrix to Contracts Task 2A and Runtime Tasks 1/2/7:

| Existing surface | W1–W5 classification | W6 disposition |
|---|---|---|
| `BASMemory/{BASAgentRegistry,BASAgentRouter,BASAgentTurnDispatcher,BASAgentFabricRuntime,BASAgentRoundTable,BASAgentLeaseManager,BASSharedStateGraph,BASSharedStateGraphStorage}.swift` | frozen incumbent authority; no new caller or schema; new Agent/RSI graph is shadow proposal-only | delete or make non-production test fixture; no public/link-reachable registry, scheduler, router, branch/state graph, or lease authority |
| `BASHostKit/BASAgentFabric{AuthoritativeTurn,FullTurnAdapter,HostOutcomeInspector,HostPipeline,MultiRoundLoop}.swift` and `EBrainRuntimeCoordinator.agentFabric` wiring | exact call-site inventory frozen | remove production composition; the sole `runtime.semantic-executor` consumes immutable proposals/receipts |
| `BASJournalCLI/Council.swift`, DeviceTest construction, and Qinao `QinaoStateGraphBus.swift` | diagnostic projection only; no new actuation | production/Release products cannot construct or import the old bus/fabric; test-only fixtures are compile-isolated |
| `BASOrgan/{BASLLMModelRouter,BASRoutingOrganAdapter}.swift`, `SampleHostBenchLLMDispatcher.swift`, and `QinaoSampleHost/SampleHostRuntimeBenchExtensions.swift` | incumbent MLX production arm may remain, but its exact callers are frozen and no new hidden retry/fallback enters | remove public multi-provider routing/fallback; `execution.plan-provider-router` is the only planner and the selected Provider receives one exact arm |
| value-only `BASAgentProposal`, observation/trace, role/spec projections that satisfy the new ABI | audited for authority-bearing fields | retain only immutable value projections, renamed/adapted if needed; no mutable singleton or callback can cross the membrane |

W1 `BASArchitectureContractClosureTests` pins that inventory and proves the new contracts cannot invoke it. W4 `BASExecutionPlanActuationTests` adds source/call-graph cases for `BASLLMModelRouter`, `BASRoutingOrganAdapter`, sample fallback code, static AFM `runsOnDevice/certified` priority, and every provider wrapper: exactly one admitted arm is callable; `.providerUnavailable`/pressure/cancellation returns a typed failure for the current Attempt and never tries AFM↔Qwen/Gemma. W6 `BASAuthoritativeEntrypointTests` and `BASSingleAuthoritativeResultTests` inspect source plus Release link images and fail if any retired registry/router/dispatcher/fabric/round-table/state-bus/host-pipeline symbol or multi-provider caller remains reachable. The new semantic executor cannot become authoritative until that same cutover commit retires the incumbent; there is never a Release tree with two active schedulers.

The semantic plan must state that `BASMemory.BASEmbeddingProvider` is the sole L8 seam and that the RuntimeCore homonym is compatibility-only. The silicon plan must state `BASModelCapabilityManifest` and `BASLLMInvocationContract` remain the identity owners; no parallel quality/model registry is created.

Semantic Task 1 additionally defines problem-shape values, not a second solver: multi-constraint ordering retains every constraint and reversible source span; long-text extraction retains byte/scalar ranges and loss/omission records; subjective prompts retain perspectives/evidence/uncertainty instead of collapsing to one induced stance; lateral puzzles retain `known|unknown|contradicted` epistemic modality; loop candidates carry progress/novelty/obligation deltas so repeated local thought terminates. Only concise reasoning artifacts, critiques, uncertainty, and verification evidence cross Agent boundaries—never private raw CoT.

Add these exact future-suite contracts to their owning plan tasks; each task names the production/test file, RED body, GREEN command, and commit boundary so the wave manifest never invents an undefined suite:

| Suite/file under `BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/` | Owning controlled-plan task |
|---|---|
| `BASContextCapsuleContractTests.swift` | Contracts Task 2A |
| `BASAgentRoleContractTests.swift` | Contracts Task 2A |
| `BASRSIContractTests.swift` | Contracts Task 2A |
| `BASReasoningArtifactContractTests.swift` | Semantic Task 1 |
| `BASStructuredProblemFlowTests.swift` | Semantic Task 1 |
| `BASNextQuestionContractTests.swift` | Runtime Task 1 Part A |
| `BASNextQuestionProjectionTests.swift` | Runtime Tasks 1 Part A and 6 |
| `BASK3CorruptionRecoveryTests.swift` | Semantic Task 2 |
| `BASMemoryContentArtifactRecoveryTests.swift` | Semantic Task 4A |
| `BASRetrievalGroundingOrderTests.swift` | Semantic Tasks 5–7 |
| `BASProcessorABITests.swift` | Silicon Task 3 |
| `BASCoreAIAssetLifecycleTests.swift` | Silicon Task 7 |
| `BASFoundationModelsSessionOwnershipTests.swift` | Silicon Task 7 |
| `BASIndependentContextWindowStressTests.swift` | Runtime Task 2 |
| `BASControlLoopReplayTests.swift` | Runtime Task 4 |
| `BASDeploymentJoinTests.swift` | Runtime Task 7 |

Add every suite used by its wave to `qinao_wave_gates_v1.json` in that same future task. W1 includes Agent/Context/RSI contract suites; W2 includes corruption/content recovery; W3 includes structured problem/retrieval order; W4 includes ABI/asset/session; W6 includes independent-window/control-loop/deployment suites.

- [ ] **Step 6: Merge W2–W5 authority/order into Semantic, Silicon, and Sovereign plans**

Apply these exact task deltas:

**Semantic Task 2 / K3 W2**

- add `RevocationFenceReceipt` generation/fence/descendant closure and publication-boundary close/reopen to the same FULL transaction owner;
- prove corruption/quarantine/cold-reopen/monotonic-floor behavior;
- keep K4, publication-journal, and Zone-C rows physically absent;
- remove `QinaoMemory` actor dictionary/receipt arrays as authority and preserve it only as a scoped projection.

**Semantic Task 4A / encrypted content W2**

- replace the unresolved operator `Decision Gate` with the approved encrypted content-addressed artifact path;
- persist canonical source bytes, reversible spans, provenance, scope/deletion epoch, DEK reference, and Artifact ID as one cold-reopenable contract while indexes retain references/watermarks only;
- keep plaintext transient only outside the encrypted content owner and never persist raw CoT;
- erase artifact/key/reference/projection/cache/backup/quarantine/Provider derivatives together and prove cold reopen plus key-destruction closure;
- remove the `disapproved branch` and any digest-only path that cannot reconstruct exact authorized content.

**Semantic Tasks 5–7 / W3**

- hard eligibility precedes every physical lookup;
- exact/FTS/BM25/temporal/entity/dense lanes feed L7 dedupe/source caps then a bounded fusion/coverage reservoir;
- Granite enters only through `BASMemory.BASEmbeddingProvider`;
- replace the free-form `providerVersion:String`/dimension-only vector compatibility with `BASEmbeddingIdentity = materialArtifactID + ProcessorABIArtifactID + tokenizer/preprocess/tensor ABI + dimension/dtype + pooling + normalization/epsilon + quantization + runtime/profile cohort`. Its digest is stored in every embedding row, SQLite/vector-index namespace, query receipt, and cache key. Different identities never mix even at the same dimension; upgrades re-embed into a new namespace and quarantine/GC legacy rows;
- make `BASEmbeddingProvider.embed` typed throwing/result-based. Missing model/tokenizer, Core AI failure, wrong shape, NaN/Inf, zero norm, or wrong normalized tolerance cannot insert, rank, or ground. Explicit empty-input policy returns “no embedding,” never a 384-dimensional zero vector. Retire `BASMiniLMEmbeddingProvider.embedSync`'s Core ML failure-to-zero fallback, and deny legacy MiniLM/NLEmbedding/stub vectors from the Granite namespace or Release fallback path;
- optional MiniCPM grounding receives the exact sentence plus qualifier/negation/coreference closure, returns unknown on ambiguity, and precedes the final L7 State Market;
- `BASContextCompiler` remains the sole tokenize/order/render/fingerprint owner.

**Silicon W0/W1/W4**

- W0 inventory denies Core AI 0.4.0 assets and records the 4.2 GB number only as package/file size. In particular, pin the exact digest of `BASAppleAdapters/Resources/BASContextClassifier.aimodel`, remove it from every Release/shadow resource copy in `BehavioralAISubstrate/Package.swift`, and make `BASCoreAIContextClassifierAdapter` reject it before load; the Core ML `.mlmodel` incumbent remains. Tests forbid `.inputNames.first`/`.outputNames.first` fallback and require exact signed tensor names;
- Task 1 declares material/key/path references only;
- Task 1 uses the four exact full 40-hex source candidates named in Global Constraints—not family nicknames, mutable `main`/tag/short refs, or placeholders. Before W1, selection binds every consumed file and LFS/Xet object ID plus content SHA-256; candidate identity alone never implies certification. AFM is the system FoundationModels arm and is never converted to Core AI;
- Tasks 1/3 bind for each open-weight material: source repository/commit/file digests; a tagged `LicenseEvidence` that uses an immutable repository license file when present or immutable model-card metadata plus a reviewed canonical license source when absent; an exact `noticeFiles[]` that may legitimately be empty only when upstream contents and obligations prove it; independent legal-review receipt; Qinao organizational signature over the package Merkle root; tokenizer/chat-template/processor files; function/custom-op digests; exact tensor ABI; minimum OS/runtime; and `sourceSpecialization|AOT` options. Upstream signatures are tagged present/absent rather than invented. Missing or drifting supply-chain fields are typed ineligible;
- Conversion is hermetic and split into an admitted download phase followed by an offline/no-network conversion phase. Its recipe binds OS/architecture/Python, coreai-torch full commit and wheel/sdist digest, PyTorch plus every transitive dependency hash, Xcode/CoreAI tool builds, custom-op source/compiler flags, complete argv/allowlisted environment, and calibration corpus provenance (`present` with source/license/consent/privacy/no-user-memory/samples/order/preprocessing/seeds, or `notApplicable` with reason and recipe digest). Two clean builds compare logical function/tensor/Merkle identity; any tool-produced nondeterministic fields are explicitly enumerated and independently attested, never ignored;
- Task 3 freezes per-model ProcessorABI. Qwen/MiniCPM pin tokenizer revision/files, normalizer/pretokenizer/postprocessor, Unicode policy, BOS/EOS/stop IDs, padding/truncation side and value, context limit, canonical chat template, decode-byte/UTF-8 policy, exact function/tensor names/dtypes/shapes, and initial thinking/MTP flags. MiniCPM-V additionally pins orientation/colorspace/crop/normalization/frame sampling, EXIF/location stripping, and visual compression variant. Any later thinking profile is distinct: thought tokens remain Provider-private transient, are stripped before any public chunk, and never enter capsule/artifact/log/telemetry/StateLake. MiniCPM-V tool-call markup is bounded proposal data or rejected. Granite pins tokenizer revision and full preprocessing, special IDs, max/chunk length, truncation/padding/mask, empty/oversize policy, exact function/input/output ABI, 384-dimensional CLS placement, dtype/precision, L2 epsilon, normalization, quantization, and non-finite/zero-norm policy. Any field change creates a new ProcessorABI, cache, and embedding namespace;
- Conversion/certification is a fail-closed ladder `Granite -> MiniCPM5 -> Qwen -> MiniCPM-V`: each rung has its own signed material/profile, conversion op-coverage/custom-op report, CPU/reference numerical parity, task-quality threshold, on-device install/specialize/load plus embedding/text/decode/vision smoke, peak disk/RSS/thermal receipt, and independent certified arm. A later rung never launders an earlier failure;
- Tasks 5/6 make K1 reserve full install/update/specialization peak disk and HeavyPhase, then K2 pin immutable URL/material/variant/key/cache receipt;
- Background Assets may download verified bytes only. The initial certified profile performs specialization/inference in foreground. Any later background ANE profile is distinct and must bind the exact `com.apple.developer.background-tasks.continued-processing.inference` entitlement, signed profile, compute device, lifecycle, and negative cases; GPU background access is separately certified. A background download callback never specializes, activates, or mutates the pointer;
- Task 7 extends `BASCoreAIModelRunner` for atomic install, content directories, reader leases, `CacheHandleReceipt`, bookmark invalidation, active-pointer CAS, single-driver state, and poison/rebuild behavior. It classifies `BASCoreAI{Decode,Prefill,HybridDecode,LayerSplit,Mamba,Mamba3,Mamba3Dual}Session`: variant-specific stateless drivers may remain internal/device-test-only, but exactly one production session actor owns per-Attempt mutable model/state/cache leases and selects a driver only from exact StateABI—never filename, first tensor, or family-name inference. Release call-graph/link tests prove one constructor;
- AFM admission replaces `AppleFoundationOrganAdapter`'s static `runsOnDevice=true`/`.certified` priority with a fresh exact `useCase + guardrails + capabilities + contextSize + supported language/locale + model-download/availability + device/OS build` observation frozen into the Attempt profile. Instructions, prompt, tools, schema, and generated tokens all debit the same measured context budget. W1/W4 retire Release construction, registry, and per-turn hot-swap through `AppleFoundationAdapterDescriptor`, `AppleFoundationAdapterRegistry`, and `.fmadapter`; iOS 27's obsolete adapter initializer remains only as migration decoder/audit tombstone. Unavailable or cohort drift is typed pre-allocation ineligibility and never activates another Main Agent. AFM certification separately covers logic ordering, long-text extraction fidelity, induced subjective prompts, loop termination, tools/guided output, cancellation, transcript isolation, quality, memory, energy, and thermal stability; framework tool calls remain proposal-only through Qinao gates;
- Before a custom Core AI executor is admitted, W0/W4 compiles the final public Xcode 27 plus an exact full-commit Core AI Models package spike for Apple's official `CoreAILanguageModel(resourcesAt:)` convenience path. If that path satisfies Qinao's material/StateABI/cache/cancellation/receipt contract, it is mandatory. A custom `LanguageModelExecutor` is allowed only for an enumerated API gap, under a separate signed profile and parity/lifecycle/call-graph proof. The two arms are mutually exclusive per profile and can never both own load, prefill, KV, or cancellation;
- System AFM is Attempt/ContextWindow-owned `LanguageModelSession`. Each window owns a distinct session, transcript, executor-store lookup, cancellation tree, and Heavy lease even when its configuration bytes match another window, because executor-store reuse within a session is mutable state sharing. Core AI `Configuration` binds exact material/variant/ProcessorABI/StateABI/cache-scope/profile digests. Exactly one production actor owns mutable NDArray/KV/session/cancellation state; existing `BASCoreAI*Session` types become pure stateless drivers or device-test-only helpers, with no stored mutable state or `@unchecked Sendable` owner. Function/tensor selection is exact ABI lookup—never `.first`, filename, family name, or substring inference. Eight-window stress and Release symbol/call-graph tests prove isolation. Windows may share only content-addressed immutable weights/compiled functions or an exact-scope prefix entry; mutable lease/pin tokens remain per window;
- `BASLLMInvocationContractTests` proves the base Qwen material can never select MTP. MTP requires a separate signed material/profile/plan, distinct cache namespace and StateABI, and independent decode-quality/cancellation certification; family naming or a checkpoint head is insufficient;
- W1/W4 removes `MLXOrganAdapter._resolveMTPWeightsURL()` substring/filename/Documents discovery and `MLXOrganAdapter+Streaming`'s environment-default thinking path. Same-name/wrong-digest MTP files are ineligible; raw `<think>` deltas are never emitted as `BASOrganDraftChunk.bodyDelta`. Mode, parser, and channel policy are Attempt-frozen values, not environment variables;
- `BASExecutionPlanActuationTests` distinguishes three sealed graphs: W4 incumbent open-weight Release admits MLX only; W6 open-weight Release admits independently certified Core AI and rejects MLX; AFM Release uses native FoundationModels and is never labeled a Core AI conversion. Qwen/MiniCPM/Granite Core AI caches, AFM sessions, and legacy MLX KV/session/cache identities are mutually incompatible and cannot cross-fallback or resume one another;
- Every Qwen, MiniCPM, and Granite Core AI profile carries a `knownIssueSetDigest` scoped to exact OS/runtime build and official release-note bytes/retrieval time, covering `169746264`, `174769929`, `175789258`, `176210080`, `176807213`, `177008303`, `177354777`, `177729331`, and `178056451`. Each profile records `resolved`, `workaround-certified`, `not-applicable-with-proof`, or `blocked` for every ID. W6 remains BLOCKED on any absent/stale/unproved disposition. A build with uncontrolled placement/background-GPU/cache/state/dynamic-output/AOT/control-flow/custom-kernel failure cannot earn production or `cold40`/`sustained30` certification;
- every W4 section contains `incumbent MLX`, `Core AI/AFM`, `shadow/device-validation`, and `no Core AI production cutover in W4`.

**Sovereign W2/W5**

- Task 1 fixes response order to `journal reserve -> K3/K4 release fence -> sink -> journal finalize -> K3 publication-boundary close`; lost replies only reopen/query/finalize;
- Task 3 adds K4 minimum material authorization epoch and revoke, consuming a prior K3 `RevocationFenceReceipt`;
- Task 4 consumes the K3 W2 ports and never declares another K3 row owner;
- Task 5 includes the complete single-anchor K3/K4/Zone-C transition oracle and query-only indeterminate recovery;
- Task 6 is formally W0-P0 platform evidence even though its production adapter remains W5;
- Task 6 begins with an explicit isolated proof-production runbook, admits only a build in a reviewed approved release-build allowlist, rejects any contradictory `FAIL`/`PASS` runtime log, and binds device install/launch JSON rather than trusting `status.json` labels;
- replace whole-file host/extension entitlement `cmp` with semantic validation of the exact seven-key Enhanced Security projection, explicit host absence, and separate team/profile/bundle checks because isolated and production bundle identifiers intentionally differ;
- signed team and application identifiers are public binary identity and remain in the actual `codesign` dumps; raw device UDID and personal provisioning material never enter repository evidence, while status carries their non-zero SHA-256 commitments;
- every W5 schedule/exit section contains `production publication remains disabled through W5`.

- [ ] **Step 7: Split Runtime W6 certification from both deployment joins**

Update Runtime Tasks 4–7:

- Task 1 Part A declares `NextQuestionProjection` as a transient finalized-response projection only: zero to five closed-source candidates; deterministic objective components, stable tie-break, confidence margin, and abstention; exactly one visible card only after final response plus eligibility/accessibility/render prerequisites. Its render CAS binds spool/workspace/completed Attempt/window/session/compartment plus model/material/snapshot/authority/revocation/deletion epochs. Any navigation, edit, newer final, epoch drift, lock/privacy change, session/window loss, or failed CAS discards it. Candidate text/score/dismissal never enters memory, StateLake, logs, analytics, notification surfaces, or durable personalization; dismissal is not learned. Dynamic Type, VoiceOver order/labels, reduced-motion behavior, and “no notification” are acceptance cases. A tap CAS starts a distinct new Attempt and cannot mutate the completed one; there is no pre-final computation or pre-tap work.
- Task 2 adds eight-window stress with distinct Attempt/branch/snapshot/budget/grant/Provider-step capsules and proves zero mutable state, KV, transcript/session, mutable cache lease/pin, cancellation, or raw-CoT leakage across windows. Windows may reference the same content-addressed immutable weight/compiled-function/prefix-entry ID only under exact material/tokenizer/template/StateABI/snapshot/authority/cache-scope equality; every mutable handle/token remains window-scoped and revocable.
- Task 4 replay manifest binds exact material/profile/plan/release-manifest refs.
- Task 4 reopens RSI envelope, fixed obligations, canonical visited digests, committed budget-use/progress witnesses, and terminal receipt; non-authoritative loop outcomes cannot be replayed as success.
- Task 5 may activate the W5 publication mechanism only after the complete manifest is stored/reopened; journal finalization is followed by K3 close.
- Task 6 produces immutable E4 candidate/path verdict and immutable E5 canary evidence; it does not deploy and it certifies independent-window/RSI/NextQuestion invariants, including `BASNextQuestionProjectionTests` for 0/1/5 candidates, tie/margin/abstain, the complete CAS vector, every discard trigger, accessibility, zero persistence/telemetry/notification, non-learning dismissal, and tap-to-new-Attempt.
- Replace Task 7's direct promotion step with six independently reviewable units in this exact order:

```text
1. E4 produces evidence and performs no deployment.
2. Seal a separate canary Release manifest/tree/cohort.
3. Join 1: exact E4 + sealed canary tree/cohort -> controlled canary deployment.
4. Observe the canary and produce immutable E5 evidence.
5. Seal a distinct full Release manifest/tree.
6. Join 2: exact E5 + sealed full Release tree -> full cutover and legacy retirement.
```

Each unit has its own RED/GREEN evidence and commit. Neither join may share a commit with the other. Rollback names and deploys another independently certified sealed tree. The status-document commit remains after the cutover and cannot mutate the certified production tree.

- [ ] **Step 8: Update the Owner Ledger without changing cardinality**

Set:

```json
"generated_from_head": "a82a7bb0b4e4f5680117df3b92593fa90c9d85a3"
```

Do not overwrite the prior provenance semantically. Add one append-only `baseline_history` transition whose prior generated anchor is `6703354b6`, prior ledger blob is `64834006f035a21300d64d0fc41b945f75b10c52`, and regenerated design anchor is `a82a7bb0b4e4f5680117df3b92593fa90c9d85a3`. Its candidate/receipt maps contain exactly the three Artifact Mesh pairs named in Task 0 and bind their committed production blobs plus stable receipt blobs; there is no cardinality change and no inferred authority. The checker reconstructs `6703354b6..a82a7bb0...`, proves those are the only newly added production Create candidates in the transition, proves the later baseline receipt commit is a descendant, and rejects missing/extra/reordered history, changed prior anchor/blob, or touch-then-revert. Thus `generated_from_head` advances without erasing the auditable earlier baseline.

Extend only the eleven owner rows in the canonical owner map. Their serialized cards must contain the exact tested phrases and these prohibitions:

| Owner | Additional forbidden invariant |
|---|---|
| `model.manifest-invocation` | a second bundle/material identity or Qwen vision/MTP inherited by family name |
| `execution.plan-provider-router` | silent AOT-to-source switch or copied certification verdict as route state |
| `provider.package-boundary` | bookmark/pointer selecting model/default, or partial install becoming active |
| `state.k3-control-nucleus` | K4/journal/Zone-C row, revocation after K4, or republish permit after uncertainty |
| `sovereign.k4-durable-lifecycle` | revoke without K3 fence or lowering material authorization epoch |
| `release.spool-publication` | K3/K4 mutation or resend after possible sink success |
| `effect.zone-c-saga` | second anchor or redispatch after possible send |
| `runtime.certification` | E4/E5 verdict mutating deployment state |
| `production.cutover` | E4-direct production, in-process rollback route, or one artifact satisfying both joins |
| `runtime.turn-operation` | mutable Agent registry/round table/state graph, mid-Attempt Main-Agent change, or cross-window session/KV/cancellation sharing |
| `runtime.semantic-executor` | second loop scheduler, self-reported progress without K3 receipt, raw CoT exchange, or adoption without verification |

Update every controlled-document `required_terms` list with only the terms owned by that document. At minimum, the architecture and master require all of:

```text
2026-07-19-qinao-coreai-agent-context-memory-rsi-design.md
Qwen/Qwen3.5-4B@851bf6e806efd8d0a36b00ddf55e13ccb7b8cd0a
qwen3.5-4b-text-only/no-mtp-certified
ModelMaterialManifestArtifactID
BASSpecializationKey
CacheHandleReceipt
ProcessorABI
BASContextCapsule
NextQuestionProjection
RevocationFenceReceipt
sourceSpecialization|AOT
production publication remains disabled through W5
Join 1
immutable E5
Join 2
```

Contracts require `BASContextCapsule`; Silicon requires material/key/cache/ProcessorABI and W4 shadow terms; Semantic requires the sole embedding seam and retrieval order; Sovereign requires fence/finalize/single-anchor/W5-disabled terms; Runtime requires E4/no-deploy and both joins.

Update these checker constants from the reviewed canonical bytes produced by the edited ledger/documents—never by weakening validation:

- `EXPECTED_WORK_PACKAGE_EXIT_GATE_DIGESTS`
- `EXPECTED_MASTER_WORK_PACKAGE_ROW_DIGESTS`
- `EXPECTED_OWNER_BOUNDARY_DIGESTS` for the eleven edited owners
- `MANDATORY_CONTROLLED_DOCUMENT_TERMS`
- `MANDATORY_DOCUMENT_SPECIFIC_TERMS`

Add a test that asserts the cardinalities remain unchanged:

```python
def test_coreai_convergence_does_not_create_owner_or_document_sprawl(self) -> None:
    data = json.loads(LEDGER.read_text(encoding="utf-8"))
    self.assertEqual(len(data["owners"]), 29)
    self.assertEqual(len(data["create_allowlist"]), 14)
    self.assertEqual(len(data["create_permissions"]), 14)
    self.assertEqual(len(data["controlled_documents"]), 7)
```

Retain the Task 2 checker's sole success line in this exact machine grammar, with no path-dependent prefix/suffix:

```text
owner-ledger: PASS candidates=<positive-int> receipts=<positive-int> owners=29 m_allowlist=14 create_permissions=14 controlled_documents=7
```

`candidates` is the union of actually discovered production CreateGate candidates, and `receipts` is the count of committed candidate manifests validated by `validate_candidate_tree_receipts`; neither may be replaced by proposals or a ledger-declared number. Add exact-output tests plus mutations for zero/missing/non-decimal/duplicate fields, wrong cardinalities, and the old parenthesized grammar. `run_qinao_wave_gate.py` parses only this anchored line and never searches arbitrary stdout for numbers.

- [ ] **Step 9: Run all semantic, ledger, and anti-vacuity tests before staging**

Run:

```bash
python3 -m unittest scripts.test_qinao_plan_remediation -v
python3 -m unittest scripts.test_check_qinao_owner_ledger -v
git diff --check -- \
  docs/superpowers/specs/2026-07-14-iphone-air-future-apple-silicon-architecture-design.md \
  docs/superpowers/plans/2026-07-15-iphone-air-architecture-convergence-master.md \
  docs/superpowers/plans/2026-07-15-iphone-air-contracts-layercell.md \
  docs/superpowers/plans/2026-07-15-iphone-air-silicon-execution-spine.md \
  docs/superpowers/plans/2026-07-15-iphone-air-semantic-statelake-context.md \
  docs/superpowers/plans/2026-07-15-iphone-air-sovereign-release-effects.md \
  docs/superpowers/plans/2026-07-15-iphone-air-runtime-replay-certification.md \
  docs/superpowers/specs/qinao-owner-ledger-v1.json \
  scripts/check_qinao_owner_ledger.py \
  scripts/test_check_qinao_owner_ledger.py \
  scripts/test_qinao_plan_remediation.py
```

Expected: semantic and ledger mutation tests PASS and diff check emits no output. The live owner checker is intentionally deferred until the exact eleven-path candidate is staged; running its index-bound mode here would validate the old index.

- [ ] **Step 10: Stage and commit the atomic controlled-document review unit**

```bash
git add \
  docs/superpowers/specs/2026-07-14-iphone-air-future-apple-silicon-architecture-design.md \
  docs/superpowers/plans/2026-07-15-iphone-air-architecture-convergence-master.md \
  docs/superpowers/plans/2026-07-15-iphone-air-contracts-layercell.md \
  docs/superpowers/plans/2026-07-15-iphone-air-silicon-execution-spine.md \
  docs/superpowers/plans/2026-07-15-iphone-air-semantic-statelake-context.md \
  docs/superpowers/plans/2026-07-15-iphone-air-sovereign-release-effects.md \
  docs/superpowers/plans/2026-07-15-iphone-air-runtime-replay-certification.md \
  docs/superpowers/specs/qinao-owner-ledger-v1.json \
  scripts/check_qinao_owner_ledger.py \
  scripts/test_check_qinao_owner_ledger.py \
  scripts/test_qinao_plan_remediation.py
RUN_DIR="$(mktemp -d "${RUNNER_TEMP:-/tmp}/qinao-controlled-merge.XXXXXX")"
trap 'rm -rf "$RUN_DIR"' EXIT
python3 -B -c 'import subprocess,sys; expected=sorted(sys.argv[1:]); raw=subprocess.check_output(["/usr/bin/git","diff","--cached","--name-only","-z"]); fields=raw.decode("utf-8","strict").split("\0"); assert fields.pop()==""; sys.exit(0 if fields==expected else 1)' \
  docs/superpowers/specs/2026-07-14-iphone-air-future-apple-silicon-architecture-design.md \
  docs/superpowers/plans/2026-07-15-iphone-air-architecture-convergence-master.md \
  docs/superpowers/plans/2026-07-15-iphone-air-contracts-layercell.md \
  docs/superpowers/plans/2026-07-15-iphone-air-runtime-replay-certification.md \
  docs/superpowers/plans/2026-07-15-iphone-air-semantic-statelake-context.md \
  docs/superpowers/plans/2026-07-15-iphone-air-silicon-execution-spine.md \
  docs/superpowers/plans/2026-07-15-iphone-air-sovereign-release-effects.md \
  docs/superpowers/specs/qinao-owner-ledger-v1.json \
  scripts/check_qinao_owner_ledger.py \
  scripts/test_check_qinao_owner_ledger.py \
  scripts/test_qinao_plan_remediation.py
python3 scripts/check_qinao_owner_ledger.py \
  --root "$PWD" \
  --ledger "$PWD/docs/superpowers/specs/qinao-owner-ledger-v1.json"
python3 scripts/check_qinao_review_candidate.py --root "$PWD"
python3 scripts/run_qinao_wave_gate.py \
  --root "$PWD" \
  --manifest "$PWD/scripts/qinao_wave_gates_v1.json" \
  --through W0 \
  --lane deterministic \
  --receipt "$RUN_DIR/deterministic.json"
CONTROLLED_INDEX_TREE="$(git write-tree)"
git commit -m "docs: converge Core AI agent execution plans"
test "$(git rev-parse HEAD^{tree})" = "$CONTROLLED_INDEX_TREE"
```

Expected: the staged-name output is exactly those eleven paths. If any path is absent, any extra path is present, or any one of the seven controlled documents remains unstaged, stop without committing.

### Task 5: Bind the Complete W0 Proof Surface and Both CI Lanes

**Files:**
- Reuse: `scripts/check_qinao_review_candidate.py`
- Reuse: `scripts/test_check_qinao_review_candidate.py`
- Modify: `.github/workflows/test.yml`
- Modify: `scripts/test_test_workflow_owner_ledger.py`

**Interfaces:**
- Consumes: the committed seven-document convergence unit and the canonical wave manifest/runner.
- Produces: one exact stage-0 regular-blob inventory plus two enabled, disjoint CI jobs whose union is identical to `--lane all`.
- CI boundary: preserve job IDs `owner-ledger` and `k4-platform-proof` **and** their current check-run display names `Qinao owner-ledger gate` and `Approved K4 physical-platform proof`; repository rules must require both exact check names. The deterministic job never needs Apple signing secrets, and a missing external K4 proof never suppresses deterministic results. Any future rename requires an atomic external branch-rule migration proved before the workflow rename lands.

- [ ] **Step 1: Verify Task 3 already bound the complete review surface**

Task 3 Appendix A adds the following twenty core/CI paths together with its eight proof-specific paths to both review inventories, maintaining global lexical sort and uniqueness:

```text
.gitattributes
BehavioralAISubstrate/scripts/check-ios27-floor.sh
BehavioralAISubstrate/scripts/test_check_ios27_floor.py
docs/superpowers/plans/2026-07-19-qinao-coreai-agent-controlled-document-convergence.md
docs/superpowers/specs/2026-07-14-iphone-air-future-apple-silicon-architecture-design.md
docs/superpowers/specs/2026-07-17-k3-budget-provider-contract-addendum-design.md
docs/superpowers/specs/2026-07-19-qinao-coreai-agent-context-memory-rsi-design.md
docs/superpowers/specs/qinao-authority-corruption-recovery-v1.md
docs/superpowers/specs/qinao-owner-ledger-v1.json
scripts/check_k4_platform_proof.py
scripts/check_qinao_preliminary_k4_source.py
scripts/check_w0_expected_open_set.py
scripts/check_xcode27_toolchain.sh
scripts/qinao_wave_gates_v1.json
scripts/run_qinao_wave_gate.py
scripts/test_check_k4_platform_proof.py
scripts/test_check_qinao_preliminary_k4_source.py
scripts/test_check_w0_expected_open_set.py
scripts/test_check_xcode27_toolchain.py
scripts/test_run_qinao_wave_gate.py
```

Starting from the existing 24 paths, the atomic Task 3 expansion adds exactly 28 distinct paths, so the resulting tuple contains exactly 52 paths. Its tests assert `len == 52`, lexical sort, uniqueness, and the exact tuple. Future-wave checkers must enter this inventory in the same commit that introduces them.

- [ ] **Step 2: Re-run the exact-inventory test before workflow edits**

```bash
python3 -m unittest \
  scripts.test_check_qinao_review_candidate.QinaoReviewCandidateTests.test_declared_review_surface_is_exact_and_cannot_shrink -v
```

Expected: PASS with exactly 52 paths. Any 24/30/42/46/48/50 count proves the hard-predecessor review surface was incomplete and blocks CI wiring.

- [ ] **Step 3: Retain adversarial index tests without mutating the inventory**

Do not add directories, globs, or digest recursion; K4 approved evidence is recursively bound by its own checker. Keep the existing regular mode-`100644`, unique stage-0, worktree-byte-equality, deletion, conflict, executable, and symlink tests.

Run:

```bash
python3 -m unittest scripts.test_check_qinao_review_candidate -v
```

Expected: all tests PASS and the exact inventory count is 52.

- [ ] **Step 4: Write RED workflow assertions for the disjoint lane pair**

Replace direct-checker assumptions in `scripts/test_test_workflow_owner_ledger.py` with these exact contracts:

1. `owner-ledger` and `k4-platform-proof` retain display names `Qinao owner-ledger gate` and `Approved K4 physical-platform proof`, both use `xcode-27`, use `actions/checkout@v4` with `fetch-depth: 0`, contain no job-level or validation-step `if`, and neither job has `needs` on the other. Only receipt-upload steps may use `if: always()`.
2. `owner-ledger` runs every checker unit suite before exactly one command:

```bash
export DEVELOPER_DIR="${DEVELOPER_DIR:-$(/usr/bin/xcode-select -p)}"
python3 scripts/run_qinao_wave_gate.py --root "$GITHUB_WORKSPACE" --manifest "$GITHUB_WORKSPACE/scripts/qinao_wave_gates_v1.json" --through W0 --lane deterministic --receipt "$RUNNER_TEMP/qinao-w0-deterministic.json"
```

3. `k4-platform-proof` reads the reviewed public Team ID from the candidate-index platform policy and runs exactly one live command:

```bash
export DEVELOPER_DIR="${DEVELOPER_DIR:-$(/usr/bin/xcode-select -p)}"
python3 scripts/run_qinao_wave_gate.py --root "$GITHUB_WORKSPACE" --manifest "$GITHUB_WORKSPACE/scripts/qinao_wave_gates_v1.json" --through W0 --lane platform --receipt "$RUNNER_TEMP/qinao-w0-platform.json"
```

4. Neither job directly executes `check_qinao_owner_ledger.py`, `check-ios27-floor.sh`, `check_w0_expected_open_set.py`, `check_qinao_review_candidate.py`, `check_k4_platform_proof.py`, or raw `swift test --filter`; the allowlisted runner is their only live entry point.
5. The test loads `scripts/qinao_wave_gates_v1.json`, proves `k4_platform_proof` is the sole platform checker, and proves the union of both lanes equals the W0 `all` gate inventory without overlap.
6. Both jobs run the runner's fixed local Xcode/Swift/iPhoneOS-SDK observation preflight and compare it to the same committed K4 toolchain attestation once approved evidence exists. These shared observations are not checker inventory and close cross-job image drift; either shard fails on mismatch.

Run:

```bash
if python3 -m unittest scripts.test_test_workflow_owner_ledger -v; then
  echo "unexpected workflow RED success" >&2
  exit 1
fi
```

Expected: FAIL against the current duplicated direct-command workflow.

- [ ] **Step 5: Wire the deterministic job**

Keep job ID `owner-ledger` and its required-check display name `Qinao owner-ledger gate`, retain `runs-on: xcode-27`, set `timeout-minutes: 60`, and retain full-history checkout. Its test step runs, in this order:

```yaml
- name: Test deterministic Qinao gate implementations
  env:
    PYTHONDONTWRITEBYTECODE: "1"
  run: |
    python3 -m unittest scripts.test_check_xcode27_toolchain
    python3 -m unittest BehavioralAISubstrate.scripts.test_check_ios27_floor
    python3 -m unittest scripts.test_check_qinao_owner_ledger
    python3 -m unittest scripts.test_check_w0_expected_open_set
    python3 -m unittest scripts.test_run_nonempty_swift_filter
    python3 -m unittest scripts.test_check_k4_platform_proof
    python3 -m unittest scripts.test_attest_k4_external_artifact
    python3 -m unittest scripts.test_capture_k4_platform_proof
    python3 -m unittest scripts.test_check_qinao_preliminary_k4_source
    python3 -m unittest scripts.test_check_bas_organ_descriptor_constructors
    python3 -m unittest scripts.test_qinao_plan_remediation
    python3 -m unittest scripts.test_check_qinao_review_candidate
    python3 -m unittest scripts.test_qinao_review_closure -v
    python3 -m unittest scripts.test_run_qinao_wave_gate
    python3 -m unittest scripts.test_test_workflow_owner_ledger
- name: Run deterministic Qinao W0 lane
  run: |
    export DEVELOPER_DIR="${DEVELOPER_DIR:-$(/usr/bin/xcode-select -p)}"
    python3 scripts/run_qinao_wave_gate.py --root "$GITHUB_WORKSPACE" --manifest "$GITHUB_WORKSPACE/scripts/qinao_wave_gates_v1.json" --through W0 --lane deterministic --receipt "$RUNNER_TEMP/qinao-w0-deterministic.json"
```

Set job-level `PYTHONDONTWRITEBYTECODE: "1"`. Upload the receipt with `actions/upload-artifact@v4`, `if: always()`, name `qinao-w0-deterministic-${{ github.sha }}`, and `if-no-files-found: error`. The `if: always()` exception is allowed only on receipt upload, never on a validation step.

- [ ] **Step 6: Wire the platform job without duplicating deterministic work**

Keep job ID `k4-platform-proof`, display name `Approved K4 physical-platform proof`, `runs-on: xcode-27`, `timeout-minutes: 15`, and full-history checkout. Replace the direct checker with:

```yaml
- name: Run Qinao W0 platform lane
  env:
    PYTHONDONTWRITEBYTECODE: "1"
  run: |
    export DEVELOPER_DIR="${DEVELOPER_DIR:-$(/usr/bin/xcode-select -p)}"
    python3 scripts/run_qinao_wave_gate.py --root "$GITHUB_WORKSPACE" --manifest "$GITHUB_WORKSPACE/scripts/qinao_wave_gates_v1.json" --through W0 --lane platform --receipt "$RUNNER_TEMP/qinao-w0-platform.json"
```

Upload the receipt with the same `always()`/missing-file policy and artifact name `qinao-w0-platform-${{ github.sha }}`. This job executes no source scan, Swift suite, or deterministic checker. Apple Team ID is a reviewed signing identity in the committed policy/evidence, not a CI secret; an optional repository variable may be compared for drift but can never be the sole required-check input.

- [ ] **Step 7: Run workflow and review-candidate unit tests**

```bash
python3 -m unittest \
  scripts.test_check_qinao_review_candidate \
  scripts.test_run_qinao_wave_gate \
  scripts.test_test_workflow_owner_ledger -v
```

Expected: all tests PASS. The workflow parser proves both stable job IDs are enabled and their lane union is closed/disjoint.

- [ ] **Step 8: Stage before running the real index-bound deterministic gate**

```bash
RUN_DIR="$(mktemp -d "${RUNNER_TEMP:-/tmp}/qinao-w0-ci.XXXXXX")"
trap 'rm -rf "$RUN_DIR"' EXIT
git add \
  .github/workflows/test.yml \
  scripts/test_test_workflow_owner_ledger.py
python3 -B -c 'import subprocess,sys; expected=[("M", ".github/workflows/test.yml"),("M", "scripts/test_test_workflow_owner_ledger.py")]; raw=subprocess.check_output(["/usr/bin/git","diff","--cached","--name-status","-z","--no-renames"]); fields=raw.decode("utf-8","strict").split("\0"); assert fields.pop()=="" and len(fields)%2==0; observed=list(zip(fields[0::2],fields[1::2])); sys.exit(0 if observed == expected else 1)'
python3 scripts/check_qinao_review_candidate.py --root "$PWD"
python3 scripts/run_qinao_wave_gate.py \
  --root "$PWD" \
  --manifest "$PWD/scripts/qinao_wave_gates_v1.json" \
  --through W0 \
  --lane deterministic \
  --receipt "$RUN_DIR/qinao-w0-deterministic.json"
```

Expected: `qinao-review-candidate: PASS paths=52`, then the deterministic W0 lane PASS with non-zero candidate, glob, and Swift test counts. Because approved evidence now exists, the lane also proves its fixed local Xcode/Swift/SDK observations equal the K4 attestation; it does not rerun device operations.

- [ ] **Step 9: Commit the CI/review closure**

```bash
CI_INDEX_TREE="$(git write-tree)"
git commit -m "ci: bind cumulative Qinao W0 gates"
test "$(git rev-parse HEAD^{tree})" = "$CI_INDEX_TREE"
```

Expected: one CI/proof-surface commit. An external repository-rule review then confirms that both stable job IDs are required checks; the workflow cannot prove deletion of its own jobs from inside itself.

### Appendix A — Normative implementation steps for Task 3: Harden and Produce the Real K4 Platform Proof

**Files:**
- Create: `docs/superpowers/specs/qinao-apple27-release-platform-policy-v1.json`
- Create: `scripts/capture_k4_platform_proof.py`
- Create: `scripts/test_capture_k4_platform_proof.py`
- Create: `scripts/attest_k4_external_artifact.py`
- Create: `scripts/test_attest_k4_external_artifact.py`
- Modify: `scripts/check_k4_platform_proof.py`
- Modify: `scripts/test_check_k4_platform_proof.py`
- Modify: `scripts/fixtures/qinao-k4-platform-probe/Host/K4SpikeHostApp.swift`
- Modify: `scripts/fixtures/qinao-k4-platform-probe/Extension/K4SpikeExtension.swift`
- Modify: `scripts/fixtures/qinao-k4-platform-probe/Shared/SpikeMessages.swift`
- Modify: `scripts/qinao_wave_gates_v1.json`
- Modify: `scripts/run_qinao_wave_gate.py`
- Modify: `scripts/test_run_qinao_wave_gate.py`
- Modify: `scripts/check_qinao_review_candidate.py`
- Modify: `scripts/test_check_qinao_review_candidate.py`
- Create only after a real pass: `docs/superpowers/evidence/qinao-k4-platform-proof-approved/**`

**Interfaces:**
- Consumes: selected release Xcode 27, iOS 27 SDK, intended Apple team, separate valid host/extension provisioning profiles with Enhanced Security on the extension, and one physical iOS 27 device.
- Produces: a deterministic approved proof assembled only by the capture tool, recursively stage-0/index-bound and independently revalidated by the checker.
- Current state: **BLOCKED**. The local Xcode is beta build `27A5194q`; no installed profile contains Enhanced Security; physical install failed `0xe8008015`; Monitor/launch/direct/async runtime did not run. The existing `qinao-k4-platform-spike` tree is preliminary evidence and must never be copied, renamed, or promoted.
- Privacy decision: actual signed entitlement dumps retain team and application identifiers because they are public binary signing identity required for independent verification. Raw device UDID, profile UUIDs, device lists, developer-certificate bodies, account data, and personal provisioning material never enter repository evidence; the approved schema retains non-zero SHA-256 commitments and reviewed non-sensitive projections.

- [ ] **Step 1: Add regression tests for every demonstrated checker bypass**

In `scripts/test_check_k4_platform_proof.py`, first extend `make_proof` to emit the new bound artifacts/status fields listed in Step 5, using only deterministic synthetic fixture values, then add these tests before changing the checker:

```python
def setUp(self) -> None:
    self.temporary_directory = tempfile.TemporaryDirectory()
    self.addCleanup(self.temporary_directory.cleanup)
    self.root = Path(self.temporary_directory.name)

def load_json(self, path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))

def load_status(self, evidence: Path) -> dict:
    return self.load_json(evidence / "status.json")

def write_status(self, evidence: Path, value: dict) -> None:
    (evidence / "status.json").write_text(
        json.dumps(value, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )

def rewrite_json_artifact(self, evidence: Path, name: str, value: dict) -> None:
    self.rewrite_artifact(
        evidence,
        name,
        (json.dumps(value, indent=2, sort_keys=True) + "\n").encode("utf-8"),
    )

def test_real_beta_xcode_cannot_self_label_as_release(self) -> None:
    evidence, team_id = self.make_proof(self.root)
    self.rewrite_artifact(
        evidence,
        "xcode-version.txt",
        b"Xcode 27.0\nBuild version 27A5194q\n",
    )
    status = self.load_status(evidence)
    status["toolchain"].update({
        "xcode_version": "27.0",
        "xcode_build": "27A5194q",
        "release_channel": "release",
    })
    self.write_status(evidence, status)
    self.assertIn("approved release-build allowlist", "\n".join(
        checker.validate_platform_proof(self.root, evidence, expected_team_id=team_id)
    ))

def test_zero_or_single_profile_commitment_cannot_pass(self) -> None:
    evidence, team_id = self.make_proof(self.root)
    status = self.load_status(evidence)
    status["signing"]["host_profile_uuid_sha256"] = "0" * 64
    status["signing"].pop("extension_profile_uuid_sha256")
    self.write_status(evidence, status)
    errors = checker.validate_platform_proof(self.root, evidence, expected_team_id=team_id)
    self.assertTrue(any("host and extension profile" in item for item in errors), errors)

def test_fail_and_pass_or_duplicate_runtime_events_are_rejected(self) -> None:
    evidence, team_id = self.make_proof(self.root)
    self.rewrite_artifact(
        evidence,
        "runtime-seed-events.jsonl",
        b'{"event":"fail","error":"send_failed"}\n{"event":"pass"}\n',
    )
    errors = checker.validate_platform_proof(self.root, evidence, expected_team_id=team_id)
    self.assertTrue(any("contradictory or duplicate runtime event" in item for item in errors), errors)

def test_runtime_trace_must_be_probe_written_and_device_copied(self) -> None:
    evidence, team_id = self.make_proof(self.root)
    attestation = self.load_json(evidence / "runtime-trace-attestation.json")
    attestation["source"] = "host_postprocessed_log"
    self.rewrite_json_artifact(evidence, "runtime-trace-attestation.json", attestation)
    errors = checker.validate_platform_proof(self.root, evidence, expected_team_id=team_id)
    self.assertTrue(any("device app container" in item for item in errors), errors)
```

Also add mutation tests for: presence of `BetaVersion.plist`; Xcode or device-OS build absent from policy; Xcode/Swift/SDK/signature/version-plist mismatch; fake PATH tool; identical host/extension profile commitment; signer leaf absent from its profile; wrong development class/team/App ID; raw UDID/workspace leakage; simulator/device-family spoof; install JSON failure; wrong/missing launch persistent identifier; stale run/source/build identity; launch/terminate/relaunch/copy failure; either phase monitor count other than one; unchanged helper PID; out-of-order/missing/repeated seed/reopen events; non-WAL/non-FULL pragma; missing commit/reopen/wrong HWM; host-access success; retained DB/WAL/SHM; non-zero pending/unexpected count; and a signed extension whose seven-key capability projection differs from the release template.

Run:

```bash
python3 -m unittest scripts.test_check_k4_platform_proof -v
```

Expected: the new tests FAIL against the current checker even though the existing tests pass.

- [ ] **Step 2: Add an intentionally closed release-build policy**

Create `docs/superpowers/specs/qinao-apple27-release-platform-policy-v1.json` with exact initial bytes:

```json
{
  "approved_platform_pairs": [],
  "denied_prerelease_builds": [
    {"build": "27A5194q", "kind": "xcode"}
  ],
  "expected_team_id": null,
  "ios_product_major": 27,
  "w0_evidence_attesters": [],
  "schema_version": 1,
  "status": "awaiting-reviewed-platform-pair",
  "xcode_product_major": 27
}
```

An empty allowlist and `expected_team_id: null` are intentional fail-closed state, not missing values. A separate policy-only commit later sets the exact public Apple Team ID and adds exactly one platform object containing `xcode_version`, `xcode_build`, `xcode_official_apple_url`, `xcode_source_sha256`, `ios_version`, `ios_build`, `ios_official_apple_url`, `ios_source_sha256`, and UTC `reviewed_at`, only after review against Apple's official release metadata. It also adds separate proof-only organizational reviewer signing and encryption certificate fingerprints/key IDs, algorithms, epochs, validity, usages, chain anchors, custody principals, and revocation state under `w0_evidence_attesters`. This is an exact certification allowlist under the existing K4/runtime-certification evidence boundary, not a production trust registry: it can verify only this W0 evidence domain and cannot authorize runtime state, publication, or effects. It uses the already available `/usr/bin/security cms` chain verifier/signer and does not depend on the W5 production trust implementation. Both builds must be public releases. The capture/checker never browse or infer release status at validation time.

- [ ] **Step 3: Make the device write the canonical runtime trace**

In the isolated fixture, add value-only `SpikeRunIdentity`/`SpikeRuntimeTrace` schema 1 values. The producer supplies a cryptographically random non-secret `runID`. `inputProbeDigest` is computed over the exact stage-0 committed fixture tree before injection; its domain excludes exactly one absent/generated filename, `Shared/GeneratedRunIdentity.swift`, and nothing else. The private build copy adds that file with `inputProbeDigest`, `runID`, and build nonce, then externally computes `builtProbeDigest` over the complete post-injection tree. Device messages/files bind only `inputProbeDigest + runID + buildNonce`; they never embed `builtProbeDigest`. Producer/attester evidence binds `builtProbeDigest -> input/run/nonce -> product CDHashes`. Mutation tests add/rename/exclude a file and prove there is no fixed-point/self-reference. Files are run-specific (`runtime-<runID>-seed.json`, `runtime-<runID>-reopen.json`, and `events-<runID>-<phase>.jsonl`), so a stale fixed-path success can never satisfy a new run.

The extension—not the host—opens a run-scoped database in its private Application Support container, reads back `journal_mode=WAL` and `synchronous=FULL`, commits a nonce/HWM marker in one transaction, closes, and reports structured values/path hash/helper-PID hash. The raw path exists only transiently in same-run XPC memory so the host can attempt one exact open and record denial; it is forbidden from every trace/log/receipt/evidence byte. Phase `seed` validates one Monitor plus direct/async reply, SQLite pragmas/commit, zero pending/unexpected, cleanup, and terminal pass, then atomically publishes its two files. The host cancels XPC, calls `AppExtensionProcess.invalidate()`, releases every strong connection/process reference, and proves old-helper PID absence with a bounded independent device-process observation; `onInterruption` is optional corroboration, not required for expected invalidation. Only then may the producer terminate the launched host, prove termination, relaunch the exact installed binary, and require different host/helper process identities. Phase `reopen` opens the existing extension-private database, reads the exact marker/HWM, proves the host denial, emits one phase Monitor, cleanup, and terminal pass, then atomically publishes. Reuse of the old helper PID blocks proof. No database/WAL/SHM bytes or private path enter evidence.

Add compile/source tests in `scripts/test_capture_k4_platform_proof.py` for run-specific paths, embedded source/build identity, same-directory temporary write plus rename, exact phase/event order, WAL/FULL read-back, close/reopen/HWM, host-access denial, and prohibition on deriving either trace/event log from console text. Detached launch stdout is never an evidence source. The spike first proves whether the Enhanced Security extension container is addressable; retrieval uses the exact `devicectl device copy from --domain-type appDataContainer --domain-identifier <extension-bundle-id> --source <run-relative-path> --json-output <private-path>` tuple. If the platform forbids direct extension-container copy, the extension relays only the same-run trace—not DB/path bytes—through the already authenticated, nonce/correlation-bound XPC channel into the host container; capture independently hashes both ends and the checker binds that route. Do not claim a separate runtime signature unless a future reviewed key lifecycle/schema is added.

- [ ] **Step 4: Implement one audited proof producer**

Create `scripts/capture_k4_platform_proof.py` using Python standard library only. Its exact CLI is:

```text
capture_k4_platform_proof.py
  capture
  --root <exact-git-root>
  --developer-dir <Xcode.app/Contents/Developer>
  --team-id-env BAS_DEVELOPMENT_TEAM
  --device-udid-env BAS_IOS27_DEVICE_UDID
  --host-profile-specifier-env BAS_K4_HOST_PROFILE_SPECIFIER
  --extension-profile-specifier-env BAS_K4_EXTENSION_PROFILE_SPECIFIER
  --source-probe scripts/fixtures/qinao-k4-platform-probe
  --private-artifact-output-env BAS_K4_PRIVATE_ARTIFACT_PATH
  --encryption-recipient-env BAS_K4_ENCRYPTION_RECIPIENT
  --projection-output <private-run-dir>/projection

capture_k4_platform_proof.py
  finalize
  --root <exact-git-root>
  --projection <private-run-dir>/projection
  --external-attestation <private-run-dir>/external-attestation.cms
  --output docs/superpowers/evidence/qinao-k4-platform-proof-approved
```

The producer must:

1. require exact Git root, normalized repository-relative source/output, no symlink component, and an absent output path;
2. require `developer-dir` to resolve beneath one Xcode app, require bundle ID `com.apple.dt.Xcode`, verify the Apple anchor/designated code requirement, reject `Contents/Resources/BetaVersion.plist`, bind `Contents/version.plist`, require its `ProductBuildVersion` to match `xcodebuild -version`, capture exact Xcode/Swift/iPhoneOS SDK outputs, and require the Xcode/device-OS pair in the reviewed allowlist;
3. copy only source/project/fixture inputs into a private temporary probe, replace every beta template snapshot/generated metadata/log with fresh release-Xcode outputs, and reject any beta/preliminary log in the candidate probe;
4. unsigned-build/typecheck the exact public shapes, then generate a private per-target xcconfig/project overlay mapping `K4SpikeHost` to the host profile and `K4SpikeExtension` to the extension profile under `CODE_SIGN_STYLE=Manual`. Parse `xcodebuild -showBuildSettings` separately for both targets and require distinct exact profile/team/bundle values before archive; swapped, collapsed, or one global selector fails. The proof tool never uses `-allowProvisioningUpdates` and never mutates Developer Portal state; profile creation/refresh is a separate explicitly authorized operator preflight;
5. find the ExtensionKit product under `Host.app/Extensions/`, strictly verify both signatures, decode both embedded **development** profiles only in the private temporary directory, validate separate non-zero/distinct profile UUID commitments, team, bundle IDs, App IDs, validity interval, and the extension's exact seven Enhanced Security keys, and prove each signed binary's leaf certificate is present in the corresponding profile `DeveloperCertificates` set;
6. retain actual signed entitlement plists, but never retain raw embedded profiles, device lists, certificates, raw profile UUIDs, raw UDID, or account paths;
7. use `devicectl --json-output` for detailed physical-device facts, install, detached launch, termination, relaunch, and app-container copy; reject simulator/platform drift and hash the raw UDID. Bind install `launchServicesIdentifier` into launch via `--launch-persistent-identifier`, use `--terminate-existing`, bind launch PID/result, never use blocking `--console`, and retrieve only files whose run/source/build identities match this invocation;
8. retrieve both app-written phase traces/event logs. Require seed order `monitor -> direct -> sqlite_pragmas -> sqlite_commit -> async -> cleanup -> pass` and reopen order `monitor -> sqlite_reopen -> host_access_denied -> cleanup -> pass`; require one of each phase event, exact correlations/routes/responder/delivery, WAL/FULL, exact marker/HWM, changed process identities, zero pending/unexpected replies, and no FAIL event anywhere;
9. `capture` serializes raw signed products/profiles/capture receipt into canonical `QINAO-K4-PRIVATE-CONTAINER-V1` bytes, CMS-encrypts that complete container to the policy-pinned encryption-only organizational recipient, publishes the ciphertext at the admitted private artifact path, writes a privacy-clean projection candidate under the private run directory, and deliberately does **not** create the canonical approved directory. A distinct reviewer runs `attest_k4_external_artifact.py --root ... --projection ... --external-artifact-env BAS_K4_PRIVATE_ARTIFACT_PATH --cms-decryption-identity-env BAS_K4_DECRYPTION_IDENTITY --cms-decryption-keychain-env BAS_K4_ATTESTER_KEYCHAIN_PATH --attestation-output ... --cms-signing-identity-env BAS_K4_ATTESTER_IDENTITY`; the attester is the only writer of the no-replace attestation, decrypts privately, redoes codesign/CMS/profile/leaf/source/build checks, and signs with a separate policy-pinned non-revoked organizational signing identity. Encryption and signing certificates/keys/usages are distinct and neither may be a product-signing leaf. `check_k4_platform_proof.py` remains side-effect-free and later verifies CMS chain/leaf/fingerprint/domain with `/usr/bin/security cms -D`;
10. `finalize` verifies the attestation signature/epoch/freshness and exact run/artifact/projection/policy digests, adds it to the projection, calls `validate_platform_proof(root, temporary_bundle, expected_team_id=policy.expected_team_id)`, scans every repository-output byte for forbidden raw profile/device/account/workspace values, and only then atomically publishes the canonical directory. Before capture, query/reconcile any installed probe and reject an unknown build/run. After success or failure, cancel/invalidate, terminate, uninstall the exact bundle, and verify app/container absence; cleanup is query/reconcile-only and never blindly repeats a possibly crossed operation. Cleanup failure is sealed in the private failure receipt and blocks approval. Preliminary evidence is untouched.

Subprocess execution uses verified absolute executables only: system `/usr/bin/{xcrun,codesign,security,plutil,git}` and `$DEVELOPER_DIR/usr/bin/xcodebuild` or another exact executable resolved inside the already verified Xcode bundle. The producer binds canonical path, digest, code-signature/version facts in the attestation, uses a minimal allowlisted environment with exact `DEVELOPER_DIR`, and clears toolchain override/injection variables. A fake leading `PATH` test proves no surrogate runs. No shell, manifest-provided command, `eval`, or user-provided executable is permitted.

The private artifact path contract is executable: absolute normalized path outside the repository, iCloud/Dropbox/CI-artifact roots, and backup-managed roots; no symlink component; caller-owned mode-`0700` parent on an approved encrypted local volume; absent leaf; mode-`0600` no-replace publication plus file/directory `fsync`; read-only verifier access; policy-bounded retention and crypto-erasure receipt. Raw temporary directories are `0700` and wiped on every exit. Plaintext container grammar is: fixed ASCII magic, uint64-BE entry count, then the domain-separated globally sorted path/mode/content-length/content records defined below; exact path tuple and maximum entry/container sizes are closed. Only the CMS EnvelopedData ciphertext is published. The attester decrypts to a private mode-`0600` FD, validates/re-packs to byte identity, and wipes it before exit. Tests cover truncated/extra/duplicate/path-alias/oversize containers, decrypt with wrong identity/keychain, signing key incorrectly reused for encryption, ciphertext tamper, nondeterministic repack, wrong owner/mode, existing/racing leaf, repo/cloud path, over-retention, and cleanup failure.

Define both logical external-artifact and repository-evidence root digests with the same domain-separated grammar: UTF-8 tag, uint64-BE entry count, then globally sorted normalized relative path; for each entry, uint64-BE path length/path bytes, fixed mode/type, uint64-BE content length, and exact content bytes. Only regular files with approved modes are permitted; directories are implicit; symlinks, hardlinks, xattrs, devices, duplicate/case-colliding/Unicode-alias paths, and extras fail. Capture, attester, checker, runner, and W6 use golden vectors and independently recompute the digest.

The attester is organizational and independent: its leaf/key and custody principal differ from producer and both host/extension signing leaves. CMS validation builds a private temporary keychain containing only policy-pinned chain material, decodes SignedData, then runs the fixed `security verify-cert` path at CMS signing time and compares leaf/anchor fingerprints/EKU/usage; it never trusts an arbitrary local Keychain. Mutations cover same leaf/key/custody, locally trusted but unpinned signer, pinned signer absent from the default keychain, and incomplete/wrong chain.

- [ ] **Step 5: Harden the checker/schema to verify producer output independently**

Update the status schema and bound root artifacts:

```text
status.json
archive-build-redacted.log
codesign-extension.log
codesign-host.log
device-info-redacted.json
device-install-redacted.json
device-launch-redacted.json
device-operations-redacted.jsonl
pre-w5-extension-signed-entitlements.plist
pre-w5-host-signed-entitlements.plist
provisioning-redacted.json
runtime-seed-trace.json
runtime-reopen-trace.json
runtime-seed-events.jsonl
runtime-reopen-events.jsonl
runtime-trace-attestation.json
sdk-version.txt
sqlite-reopen-attestation.json
swift-version.txt
toolchain-attestation.json
xcode-version.txt
signed-products-external-attestation.cms
probe/**
```

Replace `profile_uuid_sha256` with `host_profile_uuid_sha256` and `extension_profile_uuid_sha256`. All identity commitments must be lowercase SHA-256, non-zero, and semantically matched to their redacted projections. `toolchain-attestation.json` binds the combined Apple-platform policy digest, official source records, verified absolute tool paths/digests/signatures, Xcode bundle signature facts, `version.plist` digest, absence of beta marker, and exact Xcode/Swift/SDK output. The checker receives the candidate root explicitly, materializes the policy bytes from the candidate index, and rejects worktree-only or self-declared release status.

The real checker has no caller-supplied Team ID: it reads the exact public `expected_team_id` from the candidate-index policy blob and compares both signed products and retained projections. `validate_platform_proof(root, evidence, expected_team_id=...)` remains the pure semantic seam used by synthetic tests/finalize, but production CLI rejects any Team-ID override. This prevents CI secrets or caller environment from redefining signing identity.

Parse runtime event JSON structurally; console strings are non-evidence. Reject every `FAIL`, duplicate, missing, reordered, stale-run, wrong-source/build, or contradictory event. Verify the trace attestation says `device_app_container`, binds exact install persistent identifier/launch PIDs/termination/copy results, and binds both phase files. Verify `sqlite-reopen-attestation.json` proves extension-private WAL/FULL, transactional marker/HWM, changed helper process, reopen equality, and host denial; reject DB/WAL/SHM persistence.

Signed Host/Extension products and raw profiles remain in one access-controlled immutable external artifact because Mach-O CMS/profile payloads may contain personal certificate/device identity. A second independent verifier reruns `codesign --verify --strict`, compares CodeDirectory/CDHash, Info.plist, entitlements, source/build identity, Apple-signed profile CMS, and leaf-certificate membership, then emits `signed-products-external-attestation.cms` containing only the signed privacy-clean payload. The repository checker validates CMS chain/signature and all retained public semantics; full revalidation requires authorized retrieval of the external artifact. It never claims a redacted projection or digest is itself a CMS/binary verification.

Attestation body bytes are UTF-8 canonical JSON with sorted unique keys, compact separators, and no trailing LF. Compute `domain_sha256 = SHA256("QINAO-K4-EXTERNAL-ATTESTATION-V1\0" || uint64be(body-length) || body)`, then create the canonical wrapper `{"body":<body-object>,"domain_sha256":"..."}\n`; `/usr/bin/security cms -S -H SHA256 -u 6 -G` wraps that complete wrapper as CMS SignedData. Defaults, SHA-1, wrong cert usage, or missing signing time are rejected. The checker decodes/verifies the embedded dedicated non-personal organizational certificate chain, pins the policy leaf/anchor fingerprints and object-signer usage/epoch, recomputes the body commitment, and compares recovered wrapper bytes exactly without depending on local Keychain trust. Body fields bind run/input/built probe digests, product CDHashes, raw external artifact digest/retention-locator commitment, both profile commitments, platform-policy blob digest, source commit/tree, verifier key ID/epoch, and UTC verification time. Mutations cover unknown/self-injected/revoked/stale keys, old epoch, SHA-1/default/wrong usage, duplicate verifier, replayed run, altered locator/artifact/policy/product digest, non-canonical bytes, and expired retention.

The same attester implements a distinct read-only `verify-existing` subcommand with the exact arguments used in Task 6: `--root`, `--evidence`, `--external-artifact-env`, `--cms-decryption-identity-env`, `--cms-decryption-keychain-env`, and absent external `--verification-receipt`. It never signs, rewrites, or republishes an attestation and cannot mutate repository or ciphertext bytes. It decrypts privately, requires canonical-container byte identity, redoes codesign/profile/leaf/source/build checks, verifies the committed CMS/policy/retention, snapshots repository HEAD/tree before and after, and writes only one dirfd/no-replace/fsynced canonical receipt. Its closed schema binds `schema_version`, `status`, `head_commit`, `head_tree`, `run_id`, ciphertext/logical-artifact/projection/policy/CMS digests, host/extension CDHashes, both profile commitments, verifier key/epoch, `verified_at`, and retention state. Tests cover ciphertext/container/profile/product/policy/CDHash tamper, stale run/epoch/retention, wrong root/tree/identity/keychain, existing/racing output, repository/artifact mutation during verification, and any attempted signing or write outside the receipt.

For entitlements, compare semantic dictionaries, not plist bytes:

- host contains no `com.apple.security.hardened-process*` key;
- extension contains the exact seven-key release-template projection;
- host/extension team and application identifiers match the intended team and probe metadata;
- production Task 6 later repeats the same semantic projection check while separately validating its different production bundle IDs. It never whole-file `cmp`s isolated and production plists.

- [ ] **Step 6: Test hardening and prove the current environment remains blocked**

```bash
python3 -m unittest \
  scripts.test_attest_k4_external_artifact \
  scripts.test_capture_k4_platform_proof \
  scripts.test_check_k4_platform_proof -v
python3 -m py_compile \
  scripts/attest_k4_external_artifact.py \
  scripts/capture_k4_platform_proof.py \
  scripts/check_k4_platform_proof.py
test ! -e docs/superpowers/evidence/qinao-k4-platform-proof-approved
BETA_DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
export BAS_DEVELOPMENT_TEAM=TEST-NOT-A-REAL-TEAM
export BAS_IOS27_DEVICE_UDID=TEST-NOT-A-REAL-DEVICE
export BAS_K4_HOST_PROFILE_SPECIFIER=TEST-NOT-A-REAL-HOST-PROFILE
export BAS_K4_EXTENSION_PROFILE_SPECIFIER=TEST-NOT-A-REAL-EXTENSION-PROFILE
export BAS_K4_ENCRYPTION_RECIPIENT=TEST-NOT-A-REAL-RECIPIENT
TEST_RUN_DIR="$(mktemp -d "${RUNNER_TEMP:-/tmp}/qinao-k4-beta-negative.XXXXXX")"
trap 'rm -rf "$TEST_RUN_DIR"' EXIT
export BAS_K4_PRIVATE_ARTIFACT_PATH="$TEST_RUN_DIR/private-artifact.cms"
if python3 scripts/capture_k4_platform_proof.py \
  capture \
  --root "$PWD" \
  --developer-dir "$BETA_DEVELOPER_DIR" \
  --team-id-env BAS_DEVELOPMENT_TEAM \
  --device-udid-env BAS_IOS27_DEVICE_UDID \
  --host-profile-specifier-env BAS_K4_HOST_PROFILE_SPECIFIER \
  --extension-profile-specifier-env BAS_K4_EXTENSION_PROFILE_SPECIFIER \
  --source-probe scripts/fixtures/qinao-k4-platform-probe \
  --private-artifact-output-env BAS_K4_PRIVATE_ARTIFACT_PATH \
  --encryption-recipient-env BAS_K4_ENCRYPTION_RECIPIENT \
  --projection-output "$TEST_RUN_DIR/projection"
then
  exit 1
fi
test ! -e docs/superpowers/evidence/qinao-k4-platform-proof-approved
```

Expected: unit/syntax tests PASS; capture exits non-zero at the beta/allowlist preflight before signing/device access; the canonical approved directory remains absent. Test-only identifiers are never committed.

- [ ] **Step 7: Bind the new producer and policy before committing hardening**

Add these eight paths to the W0 `required_paths` manifest, in this exact global lexical order:

```text
docs/superpowers/specs/qinao-apple27-release-platform-policy-v1.json
scripts/attest_k4_external_artifact.py
scripts/capture_k4_platform_proof.py
scripts/fixtures/qinao-k4-platform-probe/Extension/K4SpikeExtension.swift
scripts/fixtures/qinao-k4-platform-probe/Host/K4SpikeHostApp.swift
scripts/fixtures/qinao-k4-platform-probe/Shared/SpikeMessages.swift
scripts/test_attest_k4_external_artifact.py
scripts/test_capture_k4_platform_proof.py
```

The base manifest bytes are pinned at `1f0a9353c9f78099714e3210ce57cc44a2264ca82de4ee2640290c88cb533699`; after exactly those eight insertions, the canonical SHA-256 is `98565901f5501514bc1462564fff8a052b2960124aa2429a2536accd52fd9ae1`. Update `EXPECTED_MANIFEST_SHA256` to the latter and assert the full bytes in the mutation suite.

In the same Task 3 hardening commit, expand both review-candidate tuples from 24 to exactly 52 by adding these eight paths **and** the exact twenty core/CI paths enumerated in Task 5 Step 1. Assert the entire sorted tuple, not arithmetic alone. This ensures the producer, attester, checker, runner, manifest, floor/toolchain gates, preliminary-source gate, plan/spec inputs, and tests are all stage-0/index-bound before the hard predecessor is accepted. Stage the changed hardening surface, run its unit tests plus `--lane deterministic`, then commit:

```bash
git add \
  scripts/attest_k4_external_artifact.py \
  scripts/test_attest_k4_external_artifact.py \
  scripts/fixtures/qinao-k4-platform-probe/Extension/K4SpikeExtension.swift \
  scripts/fixtures/qinao-k4-platform-probe/Host/K4SpikeHostApp.swift \
  scripts/fixtures/qinao-k4-platform-probe/Shared/SpikeMessages.swift \
  docs/superpowers/specs/qinao-apple27-release-platform-policy-v1.json \
  scripts/capture_k4_platform_proof.py \
  scripts/test_capture_k4_platform_proof.py \
  scripts/check_k4_platform_proof.py \
  scripts/test_check_k4_platform_proof.py \
  scripts/qinao_wave_gates_v1.json \
  scripts/run_qinao_wave_gate.py \
  scripts/test_run_qinao_wave_gate.py \
  scripts/check_qinao_review_candidate.py \
  scripts/test_check_qinao_review_candidate.py
RUN_DIR="$(mktemp -d "${RUNNER_TEMP:-/tmp}/qinao-k4-hardening.XXXXXX")"
trap 'rm -rf "$RUN_DIR"' EXIT
python3 -B -c 'import subprocess,sys; expected=sorted(sys.argv[1:]); raw=subprocess.check_output(["/usr/bin/git","diff","--cached","--name-only","-z"]); fields=raw.decode("utf-8","strict").split("\0"); assert fields.pop()==""; sys.exit(0 if fields==expected else 1)' \
  docs/superpowers/specs/qinao-apple27-release-platform-policy-v1.json \
  scripts/attest_k4_external_artifact.py \
  scripts/capture_k4_platform_proof.py \
  scripts/check_k4_platform_proof.py \
  scripts/check_qinao_review_candidate.py \
  scripts/fixtures/qinao-k4-platform-probe/Extension/K4SpikeExtension.swift \
  scripts/fixtures/qinao-k4-platform-probe/Host/K4SpikeHostApp.swift \
  scripts/fixtures/qinao-k4-platform-probe/Shared/SpikeMessages.swift \
  scripts/qinao_wave_gates_v1.json \
  scripts/run_qinao_wave_gate.py \
  scripts/test_attest_k4_external_artifact.py \
  scripts/test_capture_k4_platform_proof.py \
  scripts/test_check_k4_platform_proof.py \
  scripts/test_check_qinao_review_candidate.py \
  scripts/test_run_qinao_wave_gate.py
python3 scripts/check_qinao_review_candidate.py --root "$PWD"
python3 scripts/run_qinao_wave_gate.py \
  --root "$PWD" \
  --manifest "$PWD/scripts/qinao_wave_gates_v1.json" \
  --through W0 \
  --lane deterministic \
  --receipt "$RUN_DIR/qinao-w0-deterministic.json"
HARDENING_INDEX_TREE="$(git write-tree)"
git commit -m "test: harden K4 platform proof provenance"
test "$(git rev-parse HEAD^{tree})" = "$HARDENING_INDEX_TREE"
```

Expected: deterministic PASS and one tooling/evidence-source commit. `--lane platform` remains red because the release allowlist is empty and approved proof is absent.

- [ ] **Step 8: Stop at the external precondition until all real inputs exist**

The operator sets real values only in the execution environment:

```bash
: "${BAS_XCODE_DEVELOPER_DIR:?set release Xcode 27 Developer directory}"
: "${BAS_DEVELOPMENT_TEAM:?set intended Apple Development team}"
: "${BAS_IOS27_DEVICE_UDID:?set physical iOS 27 device UDID}"
: "${BAS_K4_HOST_PROFILE_SPECIFIER:?set exact host development profile}"
: "${BAS_K4_EXTENSION_PROFILE_SPECIFIER:?set exact Enhanced Security extension development profile}"
: "${BAS_K4_PRIVATE_ARTIFACT_PATH:?set absent access-controlled external artifact path}"
: "${BAS_K4_ATTESTER_IDENTITY:?set authorized independent verifier identity}"
: "${BAS_K4_ENCRYPTION_RECIPIENT:?set policy-pinned envelope recipient certificate}"
: "${BAS_K4_DECRYPTION_IDENTITY:?set the matching envelope private-key identity}"
: "${BAS_K4_ATTESTER_KEYCHAIN_PATH:?set private attester keychain path}"
export DEVELOPER_DIR="$BAS_XCODE_DEVELOPER_DIR"
XCODE_CONTENTS="$(cd "$DEVELOPER_DIR/.." && pwd -P)"
test ! -e "$XCODE_CONTENTS/Resources/BetaVersion.plist"
test "$(xcrun --sdk iphoneos --show-sdk-version | cut -d. -f1)" = 27
test ! -e "$BAS_K4_PRIVATE_ARTIFACT_PATH"
test -f "$BAS_K4_ATTESTER_KEYCHAIN_PATH"
```

Then update the Apple-platform policy exactly once: `approved_platform_pairs` becomes a sorted unique one-object list with the selected official Xcode **and physical device iOS** version/build plus both official Apple URLs, retrieved source digests, and review time; `expected_team_id` becomes the exact reviewed public Team ID; `status` becomes `reviewed-release-platform-pair`; and `denied_prerelease_builds` retains `27A5194q`. Pin exactly two proof identities: `attestation_signing_identity` and `artifact_envelope_identity`. The envelope recipient certificate and decrypting private-key identity must resolve to the same certificate fingerprint/public key/key ID; the attestation signing key must be distinct. Pin their usages, anchors, epochs, custody principals, validity, and revocation. The validator rejects duplicate keys/pairs/URLs, prerelease builds, source-digest drift, mutable URLs, envelope recipient/decrypt-key mismatch, signing/envelope key reuse, wrong EKU/usage, revoked/expired material, and placeholders. Commit this policy **alone** only after the policy-only machine gate and review approval. If any release/toolchain/profile/device/certificate/encrypted-volume prerequisite is absent, stop with W0 platform lane BLOCKED. Do not create approved evidence or begin Task 4.

```bash
git add -- docs/superpowers/specs/qinao-apple27-release-platform-policy-v1.json
test "$(git diff --cached --name-status --no-renames)" = $'M\tdocs/superpowers/specs/qinao-apple27-release-platform-policy-v1.json'
python3 -m unittest \
  scripts.test_check_k4_platform_proof.K4PlatformProofTests.test_release_policy_mutations_fail \
  scripts.test_attest_k4_external_artifact.K4ExternalAttesterTests.test_policy_identity_mutations_fail -v
python3 scripts/check_k4_platform_proof.py --root "$PWD" --policy-only
POLICY_INDEX_TREE="$(git write-tree)"
git commit -m "policy: approve exact Apple 27 platform pair"
test "$(git rev-parse HEAD^{tree})" = "$POLICY_INDEX_TREE"
```

- [ ] **Step 9: Capture once, stage, and independently verify the exact candidate**

Only after Step 8 passes:

```bash
K4_RUN_DIR="$(mktemp -d "${RUNNER_TEMP:-/tmp}/qinao-k4-capture.XXXXXX")"
chmod 700 "$K4_RUN_DIR"
trap 'rm -rf "$K4_RUN_DIR"' EXIT
PROJECTION="$K4_RUN_DIR/projection"
ATTESTATION="$K4_RUN_DIR/external-attestation.cms"
python3 scripts/capture_k4_platform_proof.py \
  capture \
  --root "$PWD" \
  --developer-dir "$BAS_XCODE_DEVELOPER_DIR" \
  --team-id-env BAS_DEVELOPMENT_TEAM \
  --device-udid-env BAS_IOS27_DEVICE_UDID \
  --host-profile-specifier-env BAS_K4_HOST_PROFILE_SPECIFIER \
  --extension-profile-specifier-env BAS_K4_EXTENSION_PROFILE_SPECIFIER \
  --source-probe scripts/fixtures/qinao-k4-platform-probe \
  --private-artifact-output-env BAS_K4_PRIVATE_ARTIFACT_PATH \
  --encryption-recipient-env BAS_K4_ENCRYPTION_RECIPIENT \
  --projection-output "$PROJECTION"
python3 scripts/attest_k4_external_artifact.py \
  --root "$PWD" \
  --projection "$PROJECTION" \
  --external-artifact-env BAS_K4_PRIVATE_ARTIFACT_PATH \
  --cms-decryption-identity-env BAS_K4_DECRYPTION_IDENTITY \
  --cms-decryption-keychain-env BAS_K4_ATTESTER_KEYCHAIN_PATH \
  --attestation-output "$ATTESTATION" \
  --cms-signing-identity-env BAS_K4_ATTESTER_IDENTITY
python3 scripts/capture_k4_platform_proof.py \
  finalize \
  --root "$PWD" \
  --projection "$PROJECTION" \
  --external-attestation "$ATTESTATION" \
  --output docs/superpowers/evidence/qinao-k4-platform-proof-approved
git add -- \
  docs/superpowers/evidence/qinao-k4-platform-proof-approved
git diff --cached --name-only -z -- \
  docs/superpowers/evidence/qinao-k4-platform-proof-approved \
  > "$K4_RUN_DIR/staged-evidence-paths.nul"
python3 scripts/check_qinao_review_candidate.py --root "$PWD"
python3 scripts/check_k4_platform_proof.py \
  --root "$PWD" \
  --evidence "$PWD/docs/superpowers/evidence/qinao-k4-platform-proof-approved"
python3 -B scripts/check_k4_platform_proof.py \
  --root "$PWD" \
  --evidence "$PWD/docs/superpowers/evidence/qinao-k4-platform-proof-approved" \
  --emit-index-paths "$K4_RUN_DIR/evidence-paths.nul"
cmp "$K4_RUN_DIR/evidence-paths.nul" "$K4_RUN_DIR/staged-evidence-paths.nul"
```

Expected: direct checker PASS; approved evidence contains only the exact bound root files and `probe/**`, every file is mode `100644` stage 0, no symlink or worktree/index drift exists, and raw device/profile secrets are absent. `staged-evidence-paths.nul` is generated immediately before this block from the NUL-delimited exact cached-name inventory; no platform lane runs before the proof commit.

- [ ] **Step 10: Commit the immutable platform proof separately**

```bash
PROOF_INDEX_TREE="$(git write-tree)"
git commit -m "evidence: approve K4 iOS 27 platform proof"
test "$(git rev-parse HEAD^{tree})" = "$PROOF_INDEX_TREE"
```

Expected: one proof-only commit. Any later Xcode/SDK/profile/capability/probe-tree change requires a fresh approved proof; preliminary beta evidence is never rewritten.

### Task 6: Certify the Final W0 Candidate and Hand Off the Exact W1 Base

**Files:** no new production or authority files.

**Interfaces:**
- Consumes: all Task 1–5 commits, real approved K4 proof, clean candidate index, and both CI lane contracts.
- Produces: one immutable external gate receipt bound to the final tree and one exact commit/tree pair that becomes the only W1 implementation base.

- [ ] **Step 1: Prove the execution branch is clean and scoped**

```bash
test -z "$(git status --porcelain=v1 --untracked-files=all)"
EXPECTED_FINAL_COMMIT="$(git rev-parse HEAD)"
EXPECTED_FINAL_TREE="$(git rev-parse "$EXPECTED_FINAL_COMMIT^{tree}")"
SEALED_SUMMARY=docs/superpowers/evidence/qinao-k4-platform-spike/README.md
SOURCE_HEAD="$(git log --diff-filter=A --format=%H "$EXPECTED_FINAL_COMMIT" -- "$SEALED_SUMMARY")"
test "$(printf '%s\n' "$SOURCE_HEAD" | sed '/^$/d' | wc -l | tr -d ' ')" = 1
test "$(git rev-parse codex/qinao-coreai-convergence-base-20260719)" = "$SOURCE_HEAD"
git merge-base --is-ancestor "$SOURCE_HEAD" "$EXPECTED_FINAL_COMMIT"
git diff --check "$SOURCE_HEAD..$EXPECTED_FINAL_COMMIT"
python3 scripts/run_qinao_wave_gate.py \
  --root "$PWD" \
  --verify-w0-scope \
  --source-commit "$SOURCE_HEAD" \
  --final-commit "$EXPECTED_FINAL_COMMIT"
CERT_RUN_DIR="$(mktemp -d "${RUNNER_TEMP:-/tmp}/qinao-w0-cert.XXXXXX")"
chmod 700 "$CERT_RUN_DIR"
export CERT_RUN_DIR
python3 -B - "$CERT_RUN_DIR/run-state.json" "$SOURCE_HEAD" "$EXPECTED_FINAL_COMMIT" "$EXPECTED_FINAL_TREE" <<'PY'
import json, os, sys
path, source, commit, tree = sys.argv[1:]
payload = json.dumps(
    {"final_commit": commit, "final_tree": tree, "schema_version": 1, "source_commit": source},
    sort_keys=True,
    separators=(",", ":"),
).encode() + b"\n"
fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
with os.fdopen(fd, "wb") as stream:
    stream.write(payload); stream.flush(); os.fsync(stream.fileno())
PY
```

The exact static scope tuple is: `.github/workflows/test.yml`; the six `2026-07-15-iphone-air-*` plans; the architecture design; the 2026-07-19 addendum, Apple-platform policy, recovery contract, and Owner Ledger; `scripts/{attest_k4_external_artifact.py,capture_k4_platform_proof.py,check_k4_platform_proof.py,check_qinao_owner_ledger.py,check_qinao_review_candidate.py,qinao_wave_gates_v1.json,run_nonempty_swift_filter.py,run_qinao_wave_gate.py,test_attest_k4_external_artifact.py,test_capture_k4_platform_proof.py,test_check_k4_platform_proof.py,test_check_qinao_owner_ledger.py,test_check_qinao_review_candidate.py,test_qinao_plan_remediation.py,test_run_nonempty_swift_filter.py,test_run_qinao_wave_gate.py,test_test_workflow_owner_ledger.py}`; and the three Host/Extension/Shared fixture Swift files. Policy, attester/test, capture/test, manifest/runner/test, and approved evidence are exact additions; the other static paths are exact modifications; evidence files are exact additions emitted recursively by the K4 checker. Expected: clean status, exact net tuple, exact per-commit task tuple, no merge/rename/touch-then-revert, and no production source outside the fixture.

- [ ] **Step 2: Run every gate implementation test**

```bash
python3 -m unittest \
  scripts.test_check_xcode27_toolchain \
  BehavioralAISubstrate.scripts.test_check_ios27_floor \
  scripts.test_check_qinao_owner_ledger \
  scripts.test_check_w0_expected_open_set \
  scripts.test_run_nonempty_swift_filter \
  scripts.test_check_k4_platform_proof \
  scripts.test_attest_k4_external_artifact \
  scripts.test_capture_k4_platform_proof \
  scripts.test_check_qinao_preliminary_k4_source \
  scripts.test_check_bas_organ_descriptor_constructors \
  scripts.test_qinao_plan_remediation \
  scripts.test_check_qinao_review_candidate \
  scripts.test_qinao_review_closure \
  scripts.test_run_qinao_wave_gate \
  scripts.test_test_workflow_owner_ledger -v
```

Expected: all suites PASS under Python standard-library `unittest`; no local `pytest` dependency exists.

- [ ] **Step 3: Re-materialize the candidate as a clean detached worktree**

```bash
: "${CERT_RUN_DIR:?retain the private Task 6 run directory}"
STATE="$CERT_RUN_DIR/run-state.json"
EXPECTED_FINAL_COMMIT="$(python3 -B -c 'from pathlib import Path; from scripts.run_qinao_wave_gate import load_certification_run_state; print(load_certification_run_state(Path(__import__("sys").argv[1]))["final_commit"])' "$STATE")"
EXPECTED_FINAL_TREE="$(python3 -B -c 'from pathlib import Path; from scripts.run_qinao_wave_gate import load_certification_run_state; print(load_certification_run_state(Path(__import__("sys").argv[1]))["final_tree"])' "$STATE")"
SOURCE_HEAD="$(python3 -B -c 'from pathlib import Path; from scripts.run_qinao_wave_gate import load_certification_run_state; print(load_certification_run_state(Path(__import__("sys").argv[1]))["source_commit"])' "$STATE")"
COMMON_GIT_DIR="$(git rev-parse --path-format=absolute --git-common-dir)"
MAIN_ROOT="$(cd "$(dirname "$COMMON_GIT_DIR")" && pwd -P)"
CERT_ROOT="$MAIN_ROOT/.worktrees/qinao-coreai-w0-certification"
test ! -e "$CERT_ROOT"
git worktree add --detach "$CERT_ROOT" "$EXPECTED_FINAL_COMMIT"
test -z "$(git -C "$CERT_ROOT" status --porcelain=v1 --untracked-files=all)"
test "$(git -C "$CERT_ROOT" rev-parse HEAD)" = "$EXPECTED_FINAL_COMMIT"
test "$(git -C "$CERT_ROOT" rev-parse HEAD^{tree})" = "$EXPECTED_FINAL_TREE"
python3 "$CERT_ROOT/scripts/run_qinao_wave_gate.py" \
  --root "$CERT_ROOT" --verify-w0-scope \
  --source-commit "$SOURCE_HEAD" --final-commit "$EXPECTED_FINAL_COMMIT"
```

`load_certification_run_state` rejects wrong owner/mode, symlink, duplicate keys, extra fields, non-canonical bytes, or malformed IDs. Expected: clean detached worktree at the exact fixed commit/tree. If the path exists, stop and inspect; do not delete it implicitly.

- [ ] **Step 4: Run the complete W0 gate, not either shard**

```bash
: "${CERT_RUN_DIR:?retain the private Task 6 run directory}"
COMMON_GIT_DIR="$(git rev-parse --path-format=absolute --git-common-dir)"
MAIN_ROOT="$(cd "$(dirname "$COMMON_GIT_DIR")" && pwd -P)"
CERT_ROOT="$MAIN_ROOT/.worktrees/qinao-coreai-w0-certification"
STATE="$CERT_RUN_DIR/run-state.json"
EXPECTED_FINAL_COMMIT="$(python3 -B -c 'from pathlib import Path; from scripts.run_qinao_wave_gate import load_certification_run_state; print(load_certification_run_state(Path(__import__("sys").argv[1]))["final_commit"])' "$STATE")"
EXPECTED_FINAL_TREE="$(python3 -B -c 'from pathlib import Path; from scripts.run_qinao_wave_gate import load_certification_run_state; print(load_certification_run_state(Path(__import__("sys").argv[1]))["final_tree"])' "$STATE")"
SOURCE_HEAD="$(python3 -B -c 'from pathlib import Path; from scripts.run_qinao_wave_gate import load_certification_run_state; print(load_certification_run_state(Path(__import__("sys").argv[1]))["source_commit"])' "$STATE")"
test "$(git -C "$CERT_ROOT" rev-parse HEAD)" = "$EXPECTED_FINAL_COMMIT"
test "$(git -C "$CERT_ROOT" rev-parse HEAD^{tree})" = "$EXPECTED_FINAL_TREE"
python3 "$CERT_ROOT/scripts/run_qinao_wave_gate.py" \
  --root "$CERT_ROOT" --verify-w0-scope \
  --source-commit "$SOURCE_HEAD" --final-commit "$EXPECTED_FINAL_COMMIT"
: "${BAS_XCODE_DEVELOPER_DIR:?set the exact release Xcode used by K4 proof}"
: "${BAS_K4_PRIVATE_ARTIFACT_PATH:?retain authorized encrypted K4 artifact}"
: "${BAS_K4_DECRYPTION_IDENTITY:?set the policy-matched envelope private-key identity}"
: "${BAS_K4_ATTESTER_KEYCHAIN_PATH:?set private attester keychain}"
export DEVELOPER_DIR="$BAS_XCODE_DEVELOPER_DIR"
K4_VERIFY_RECEIPT="$CERT_RUN_DIR/k4-verify-existing.json"
FINAL_RECEIPT="$CERT_RUN_DIR/final-all.json"
test ! -e "$K4_VERIFY_RECEIPT" && test ! -e "$FINAL_RECEIPT"
python3 "$CERT_ROOT/scripts/attest_k4_external_artifact.py" verify-existing \
  --root "$CERT_ROOT" \
  --evidence "$CERT_ROOT/docs/superpowers/evidence/qinao-k4-platform-proof-approved" \
  --external-artifact-env BAS_K4_PRIVATE_ARTIFACT_PATH \
  --cms-decryption-identity-env BAS_K4_DECRYPTION_IDENTITY \
  --cms-decryption-keychain-env BAS_K4_ATTESTER_KEYCHAIN_PATH \
  --verification-receipt "$K4_VERIFY_RECEIPT"
test "$(git -C "$CERT_ROOT" rev-parse HEAD)" = "$EXPECTED_FINAL_COMMIT"
test "$(git -C "$CERT_ROOT" rev-parse HEAD^{tree})" = "$EXPECTED_FINAL_TREE"
test -z "$(git -C "$CERT_ROOT" status --porcelain=v1 --untracked-files=all)"
python3 "$CERT_ROOT/scripts/run_qinao_wave_gate.py" \
  --root "$CERT_ROOT" \
  --manifest "$CERT_ROOT/scripts/qinao_wave_gates_v1.json" \
  --through W0 \
  --lane all \
  --candidate-tree "$EXPECTED_FINAL_TREE" \
  --receipt "$FINAL_RECEIPT"
```

Expected: full external-artifact revalidation PASS, then `all` PASS. The receipt records exact fixed commit/tree, manifest SHA `98565901f5501514bc1462564fff8a052b2960124aa2429a2536accd52fd9ae1`, 52 review paths, W0 manifest counts `30/8/1/2/4`, owner shapes `29/14/14/7`, non-zero owner candidates/receipts, four listed/executed Swift suites, exact K4 predecessor/toolchain/device projection, each command/exit, and `status=pass`.

- [ ] **Step 5: Independently verify structural invariants**

```bash
: "${CERT_RUN_DIR:?retain the private Task 6 run directory}"
COMMON_GIT_DIR="$(git rev-parse --path-format=absolute --git-common-dir)"
MAIN_ROOT="$(cd "$(dirname "$COMMON_GIT_DIR")" && pwd -P)"
CERT_ROOT="$MAIN_ROOT/.worktrees/qinao-coreai-w0-certification"
STATE="$CERT_RUN_DIR/run-state.json"
EXPECTED_FINAL_COMMIT="$(python3 -B -c 'from pathlib import Path; from scripts.run_qinao_wave_gate import load_certification_run_state; print(load_certification_run_state(Path(__import__("sys").argv[1]))["final_commit"])' "$STATE")"
EXPECTED_FINAL_TREE="$(python3 -B -c 'from pathlib import Path; from scripts.run_qinao_wave_gate import load_certification_run_state; print(load_certification_run_state(Path(__import__("sys").argv[1]))["final_tree"])' "$STATE")"
assert_cert_identity() {
  test -z "$(git -C "$CERT_ROOT" status --porcelain=v1 --untracked-files=all)"
  test "$(git -C "$CERT_ROOT" rev-parse HEAD)" = "$EXPECTED_FINAL_COMMIT"
  test "$(git -C "$CERT_ROOT" rev-parse HEAD^{tree})" = "$EXPECTED_FINAL_TREE"
}
assert_cert_identity
cd "$CERT_ROOT"
python3 "$CERT_ROOT/scripts/check_qinao_owner_ledger.py" \
  --root "$CERT_ROOT" \
  --ledger "$CERT_ROOT/docs/superpowers/specs/qinao-owner-ledger-v1.json"
assert_cert_identity
python3 "$CERT_ROOT/scripts/check_qinao_review_candidate.py" --root "$CERT_ROOT"
assert_cert_identity
python3 "$CERT_ROOT/scripts/check_k4_platform_proof.py" \
  --root "$CERT_ROOT" \
  --evidence "$CERT_ROOT/docs/superpowers/evidence/qinao-k4-platform-proof-approved"
assert_cert_identity
git -C "$CERT_ROOT" diff --check HEAD
```

Expected: all three checkers PASS, review path count is 52, owner cardinalities remain 29/14/14/7, every post-check identity assertion passes, and diff check emits no output.

- [ ] **Step 6: Verify receipt binding and record the W1 base out of band**

```bash
: "${CERT_RUN_DIR:?retain the private Task 6 run directory}"
COMMON_GIT_DIR="$(git rev-parse --path-format=absolute --git-common-dir)"
MAIN_ROOT="$(cd "$(dirname "$COMMON_GIT_DIR")" && pwd -P)"
CERT_ROOT="$MAIN_ROOT/.worktrees/qinao-coreai-w0-certification"
STATE="$CERT_RUN_DIR/run-state.json"
EXPECTED_FINAL_COMMIT="$(PYTHONPATH="$CERT_ROOT" python3 -B -c 'from pathlib import Path; from scripts.run_qinao_wave_gate import load_certification_run_state; print(load_certification_run_state(Path(__import__("sys").argv[1]))["final_commit"])' "$STATE")"
EXPECTED_FINAL_TREE="$(PYTHONPATH="$CERT_ROOT" python3 -B -c 'from pathlib import Path; from scripts.run_qinao_wave_gate import load_certification_run_state; print(load_certification_run_state(Path(__import__("sys").argv[1]))["final_tree"])' "$STATE")"
SOURCE_HEAD="$(PYTHONPATH="$CERT_ROOT" python3 -B -c 'from pathlib import Path; from scripts.run_qinao_wave_gate import load_certification_run_state; print(load_certification_run_state(Path(__import__("sys").argv[1]))["source_commit"])' "$STATE")"
MANIFEST_SHA256="98565901f5501514bc1462564fff8a052b2960124aa2429a2536accd52fd9ae1"
FINAL_RECEIPT="$CERT_RUN_DIR/final-all.json"
K4_VERIFY_RECEIPT="$CERT_RUN_DIR/k4-verify-existing.json"
python3 "$CERT_ROOT/scripts/run_qinao_wave_gate.py" \
  --root "$CERT_ROOT" --verify-w0-scope \
  --source-commit "$SOURCE_HEAD" --final-commit "$EXPECTED_FINAL_COMMIT"
python3 "$CERT_ROOT/scripts/run_qinao_wave_gate.py" \
  --root "$CERT_ROOT" \
  --verify-receipt "$FINAL_RECEIPT" \
  --expected-head-commit "$EXPECTED_FINAL_COMMIT" \
  --expected-head-tree "$EXPECTED_FINAL_TREE" \
  --expected-manifest-sha256 "$MANIFEST_SHA256" \
  --expected-review-path-count 52 \
  --expected-through W0 \
  --expected-lane all \
  --external-k4-verification-receipt "$K4_VERIFY_RECEIPT"
test "$(git -C "$CERT_ROOT" rev-parse HEAD)" = "$EXPECTED_FINAL_COMMIT"
test "$(git -C "$CERT_ROOT" rev-parse HEAD^{tree})" = "$EXPECTED_FINAL_TREE"
shasum -a 256 "$FINAL_RECEIPT" "$K4_VERIFY_RECEIPT" "$STATE"
```

Expected: the standard-library verifier derives and validates the complete schema/counts/Git predecessor/external-artifact binding; the fixed commit/tree remains unchanged. Archive the three external canonical files and SHA-256 values under the fixed commit identity. Do not commit a receipt that claims to certify its own containing tree—that would create a self-referential digest cycle.

The run-state's `final_commit`/`final_tree` pair is the sole W1 base. Branch names, the dirty source worktree, preliminary K4 evidence, and earlier receipts are not implementation bases.

---

## Spec-to-Plan Traceability Matrix

| Approved addendum decision | Controlled owner/task after Task 4 | Executable proof |
|---|---|---|
| main Qwen or AFM selection, no mid-turn model swap | Contracts Task 2A values; Silicon Tasks 1/3/7 execution identity | `BASContextCapsuleContractTests`, `BASLLMInvocationContractTests`, `BASExecutionPlanActuationTests` |
| MiniCPM5 text specialist, MiniCPM-V vision specialist, Granite retrieval-only/non-Agent | Architecture §10.1; Contracts role matrix; Semantic Tasks 1/5; Silicon Task 1 capability manifest | `BASAgentRoleContractTests`, `BASReasoningArtifactContractTests`, `BASRetrievalGroundingOrderTests` |
| independent ContextCapsules and no cross-window mutable state/KV | Contracts Task 2A; Runtime Task 2 DAG isolation | `BASContextCapsuleContractTests`, `BASIndependentContextWindowStressTests` with eight concurrent windows |
| zero raw CoT and artifact/receipt-only collaboration | Contracts Task 2A; Semantic Task 1; Runtime Task 4 replay | constructor/source bans plus `BASReasoningArtifactContractTests` and replay mutation tests |
| bounded RSI with receipt-driven progress, fixed obligations, no-progress/cycle termination | Contracts Task 2A value contracts; Semantic Task 2 K3 use rows; Runtime Tasks 1/4/6 replay/certification | `BASRSIContractTests`, `BASBudgetLeaseControlTests`, `BASControlLoopReplayTests` |
| canonical encrypted raw content is durable, not an unresolved digest-only decision | Master capability/migration rows; Semantic Task 4A W2 | cold reopen + erase-together `BASMemoryContentArtifactRecoveryTests`; relevant sections forbid `Decision Gate` and `disapproved branch` |
| hard eligibility before exact/FTS/BM25/temporal/entity/dense; optional grounding before final market | Semantic Tasks 5–7 W3 | `BASRetrievalGroundingOrderTests`, lane/fusion/market suites and physical-read counters |
| logic/extraction/subjective/lateral-puzzle flows preserve constraints/spans/perspectives/epistemic modality | Semantic Task 1 reasoning values and Tasks 6–7 fixtures | `BASReasoningArtifactContractTests`, `BASStructuredProblemFlowTests` |
| transient NextQuestion only after final authorization; no memory/telemetry/write side channel; tap CAS starts a new Attempt | Contracts value owner; Runtime Task 1 value and Task 7 projection | `BASNextQuestionContractTests`, `BASNextQuestionProjectionTests` |
| material manifest/variant/specialization/cache/StateABI/ProcessorABI are exact and model-neutral | Silicon Tasks 1/3/5–7 W1/W4 | material/cache/ABI/asset/session suites pinned by wave manifest |
| Core AI 0.4.0 material denied; pinned Qwen source has a separate initial text-only/no-MTP certified variant | Architecture and Silicon W0/Tasks 1/3 | inventory/capability mutation tests and per-variant device conversion evidence |
| one K3 revoke/publication-close authority; one K4 material floor; query-only uncertain recovery | Semantic Task 2; Sovereign Tasks 1/3/5 | corruption/revocation/publication/effect fault matrices |
| Core AI/AFM shadow in W4; publication disabled through W5 | Master/Silicon W4; Master/Sovereign W5 | semantic plan tests and release-path reachability gates |
| E4 evidence, separate canary seal/Join 1, immutable E5, separate full seal/Join 2 | Runtime Tasks 6–7; `runtime.certification` and `production.cutover` | `BASDeploymentJoinTests`, candidate/release tree mutation tests |
| real K4 release/profile/device/runtime proof precedes W1/W5 | Sovereign Task 6 and this plan Task 3 / Appendix A | hardened capture/checker tests, proof-only commit, then W0 platform/all receipts |

Every row is also represented in controlled-document required terms or a document-scoped semantic test. A new decision without a row, owner, wave, suite, and candidate-bound gate is not converged.

## Plan Self-Review and Completion Criteria

Run before handing this plan to an executor:

```bash
PLAN=docs/superpowers/plans/2026-07-19-qinao-coreai-agent-controlled-document-convergence.md
test -s "$PLAN"
python3 -B - "$PLAN" <<'PY'
import re, sys
from pathlib import Path
text = Path(sys.argv[1]).read_bytes().decode("utf-8", "strict")
assert len(re.findall(r"^### Task [0-6]:", text, re.MULTILINE)) == 7
fences = len(re.findall(r"^```", text, re.MULTILINE))
assert fences > 0 and fences % 2 == 0
bad = [
    "T" + "BD", "TO" + "DO", "FIX" + "ME", "implement la" + "ter",
    "fill in det" + "ails", "Similar t" + "o", "Add appropr" + "iate",
    "Write tests for the ab" + "ove",
]
assert not any(value in text for value in bad)
required = [
    "architecture design, convergence master, and five domain plans",
    "29 owners / 14 M allowlist entries / 14 create permissions / 7 controlled documents",
    "production publication remains disabled through W5",
    "Join 1", "immutable E5", "Join 2",
]
assert all(value in text for value in required)
assert all(line == line.rstrip(" \t") for line in text.splitlines())
PY
git diff --check -- "$PLAN"
```

The plan is complete only when:

- every adopted addendum decision has an existing owner, exact controlled-document task, wave, test suite, and gate;
- the canonical manifest is byte-pinned, candidate-index-bound, root-confined, cumulative, mutation-tested, and emits a structured receipt;
- review candidate and both CI lanes are enabled and non-duplicative;
- all seven controlled documents and ledger are atomically consistent at 29/14/14/7;
- the K4 proof is produced by the audited tool under release Xcode/profile/device inputs, committed as a proof-only tree, and only then passes the independent platform lane;
- final `--lane all` passes on a clean detached exact tree;
- no W1 production implementation begins while any W0 condition is red.
