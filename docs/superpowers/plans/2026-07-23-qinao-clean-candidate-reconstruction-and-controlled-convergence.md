# Qinao Clean Candidate Reconstruction and Controlled Convergence Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reconstruct the useful Qinao W0/W1 work into a clean, provenance-bound candidate; atomically converge the controlled documents and gates; then resume W1-W6 only from non-vacuous predecessor-authorized evidence.

**Architecture:** The implementation is split into reconstruction batches C0-C5 rather than another runtime architecture. C0 establishes an immutable base and externally reviewed admission bootstrap; C1/C2 atomically correct authority text, ledgers, contracts, checkers, provenance, and evidence; C3/C4 admit W0 freezes and real K4 platform proof; C5 resumes the existing domain waves in dependency order. Each wave uses the non-circular `Pw → Cw → Sw` lineage: payload, evidence-only child, receipt-only seal.

**Tech Stack:** Git worktrees and object database, Python 3 standard-library checkers/tests, Swift 6 and SwiftPM, Xcode 27/iOS 27, JSON Schema, SQLite, Rust/C/C++/Metal where already assigned by the controlled domain plans, GitHub Actions pinned by commit SHA, signed external evidence bundles.

## Global Constraints

- The authoritative semantic shape remains exactly fourteen LayerCores, four Physical Kernels, four bounded ControlRings, and seven orthogonal planes.
- Minimum deployment target is iOS 27 for packages, generated projects, build scripts, XCFramework slices, test hosts, and release artifacts.
- No new mutable owner, scheduler, store, compiler, State Market, EventLog, K3 WAL, K4 ledger, publication journal, recovery authority, release mouth, promotion mouth, or retry truth may be introduced.
- Models remain outside Qinao SDK behind value-only Provider/Proposal interfaces and cannot mutate authority state.
- Artifact Mesh, K3, K4, Zone C, publication, and StateLake retain the ownership boundaries fixed by the approved design.
- The exact two new immutable value-contract families are `BASContentIntakeProfilePayload`/`BASContentIntakeReceiptPayload` and `BASAuthorizedInputEffectPredecessorPayload`; neither creates an owner.
- V1 production visibility is exactly `bufferedUntilVerified`; incremental/provisional behavior remains V2-quarantined.
- Unknown external state is query/reconcile-only and is never blindly replayed.
- Raw secrets, raw device identifiers, archives, Mach-O files, signing material, profiles, model packages, link maps, build plans, and physical traces never enter Git.
- 40 cold tok/s and 30 sustained tok/s are optional measured targets, never unconditional completion gates.
- Candidate code, candidate tests, and candidate manifests cannot select or activate the verifier that admits their own wave.
- Preserve all existing dirty-tree bytes. Do not reset, overwrite, normalize, delete, or bulk-commit them.
- Every test filter must prove non-zero discovery before execution.
- Every named path gate must fail on a missing path before scanning its content.
- C1 and C2 form one indivisible authority payload; no C1-only tree is admissible.

---

## File Map

### Reconstruction and evidence

- Create: `scripts/capture_qinao_candidate_inventory.py` — captures HEAD/index/worktree/untracked strata without mutation.
- Create: `scripts/test_capture_qinao_candidate_inventory.py` — proves capture completeness and non-mutation.
- Create: `scripts/build_qinao_import_map.py` — produces one explicit source-stratum selection per dirty path.
- Create: `scripts/check_qinao_import_map.py` — proves inventory/map exact-set equality and legal batch assignment.
- Create: `docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/source-inventory.json` — immutable HEAD/index/worktree/untracked provenance.
- Create: `docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/import-map.json` — maps every imported blob to source stratum and destination commit.
- Create: `docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/payload-manifest.json` — exact `Pw` build/source identity.
- Create: `docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/evidence-manifest.json` — exact evidence-only `Cw` leaves.
- Create externally, never in Git: encrypted K4/release/device evidence bundle and destruction obligation.

### Admission bootstrap

- Create: `.github/workflows/qinao-wave-admission.yml`
- Create: `scripts/check_qinao_wave_admission.py`
- Create: `scripts/test_check_qinao_wave_admission.py`
- Create: `scripts/qinao_gate_modules/` — bootstrap-pinned preW0-through-W6 gate modules and contracts.
- Create: `scripts/qinao_gate_corpora/` — positive, negative, and mutation vectors for every gate module.

### Controlled authority and ledgers

- Modify: `docs/superpowers/specs/2026-07-14-iphone-air-future-apple-silicon-architecture-design.md`
- Modify: `docs/superpowers/specs/2026-07-17-k3-budget-provider-contract-addendum-design.md`
- Modify: `docs/superpowers/specs/2026-07-19-qinao-coreai-agent-context-memory-rsi-design.md`
- Modify: `docs/superpowers/specs/2026-07-22-qinao-model-independent-app-agent-self-design.md`
- Modify: `docs/superpowers/specs/2026-07-23-qinao-governed-learning-plane-data-flywheel-thinking-design.md`
- Modify: `docs/superpowers/plans/2026-07-15-iphone-air-architecture-convergence-master.md`
- Modify: `docs/superpowers/plans/2026-07-15-iphone-air-contracts-layercell.md`
- Modify: `docs/superpowers/plans/2026-07-15-iphone-air-runtime-replay-certification.md`
- Modify: `docs/superpowers/plans/2026-07-15-iphone-air-semantic-statelake-context.md`
- Modify: `docs/superpowers/plans/2026-07-15-iphone-air-silicon-execution-spine.md`
- Modify: `docs/superpowers/plans/2026-07-15-iphone-air-sovereign-release-effects.md`
- Modify: `docs/superpowers/specs/qinao-owner-ledger-v1.json`
- Modify: `docs/superpowers/specs/qinao-authority-corruption-recovery-v1.md`
- Modify: `docs/superpowers/plans/2026-07-19-qinao-coreai-agent-controlled-document-convergence.md`

### Contract and reachability verification

- Modify: `scripts/check_qinao_owner_ledger.py`
- Modify: `scripts/test_check_qinao_owner_ledger.py`
- Create: `docs/superpowers/specs/qinao-production-reachability-v1.schema.json`
- Create: `docs/superpowers/specs/qinao-architecture-closure-report-v1.schema.json`
- Create: `docs/superpowers/specs/qinao-v2-quarantine-v1.schema.json`
- Create: `docs/superpowers/specs/qinao-wave-admission-receipt-v1.schema.json`
- Create: `scripts/generate_qinao_production_reachability.py`
- Create: `scripts/check_qinao_production_reachability.py`
- Create: `scripts/test_check_qinao_production_reachability.py`
- Create: `scripts/generate_qinao_architecture_closure.py`
- Create: `scripts/check_qinao_architecture_closure.py`
- Create: `scripts/test_check_qinao_architecture_closure.py`

### Existing gate slice to import and repair

- Modify/import: `.github/workflows/test.yml`
- Modify/import: `scripts/check_qinao_review_candidate.py`
- Modify/import: `scripts/test_check_qinao_review_candidate.py`
- Modify/import: `scripts/test_qinao_review_closure.py`
- Modify/import: `scripts/check_w0_expected_open_set.py`
- Modify/import: `scripts/test_check_w0_expected_open_set.py`
- Modify/import: `scripts/check_k4_platform_proof.py`
- Modify/import: `scripts/test_check_k4_platform_proof.py`
- Modify/import: `scripts/check_xcode27_toolchain.sh`
- Modify/import: `scripts/test_check_xcode27_toolchain.py`
- Modify/import: `scripts/run_nonempty_swift_filter.py`
- Modify/import: `scripts/test_run_nonempty_swift_filter.py`
- Modify/import: `scripts/check_bas_organ_descriptor_constructors.py`
- Modify/import: `scripts/test_check_bas_organ_descriptor_constructors.py`

---

### Task 1: Freeze the forensic source inventory

**Files:**
- Create outside the dirty worktree first: `/private/tmp/qinao-clean-candidate-2026-07-23-c0/source-inventory.json`
- Create after C0 exists: `docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/source-inventory.json`

**Interfaces:**
- Consumes: dirty branch `codex/qinao-w1`, base commit `20fc52ea0e8a367dc4ebe4d73717a1e2e24fb9d0`.
- Produces: canonical inventory containing `head`, `index_tree`, staged/unstaged patch SHA-256, and sorted untracked blob identities.

- [ ] **Step 1: Assert the expected repository and base exist**

```bash
test "$(git rev-parse --show-toplevel)" = "/Users/changgeng/Project/Project06/Project06/.worktrees/qinao-w0"
git cat-file -e 20fc52ea0e8a367dc4ebe4d73717a1e2e24fb9d0^{commit}
```

Expected: both commands exit 0.

- [ ] **Step 2: Capture strata without changing the index or worktree**

```bash
python3 scripts/capture_qinao_candidate_inventory.py \
  --root . \
  --base 20fc52ea0e8a367dc4ebe4d73717a1e2e24fb9d0 \
  --output /private/tmp/qinao-clean-candidate-2026-07-23-c0/source-inventory.json
```

The implementation must use `git rev-parse HEAD`, `git write-tree`, `git diff --cached --binary`, `git diff --binary`, and `git ls-files --others --exclude-standard -z`. It hashes bytes but does not call `git add`, `git checkout`, `git reset`, or `git clean`.

Expected: `inventory_status=complete`, with non-negative counts for all four strata.

- [ ] **Step 3: Prove capture is non-mutating**

```bash
python3 scripts/capture_qinao_candidate_inventory.py \
  --root . \
  --base 20fc52ea0e8a367dc4ebe4d73717a1e2e24fb9d0 \
  --verify /private/tmp/qinao-clean-candidate-2026-07-23-c0/source-inventory.json
```

Expected: `inventory_match=true` and no changed status lines.

- [ ] **Step 4: Commit only the capture utility and its tests on the reconstruction branch**

```bash
python3 -m unittest -v scripts.test_capture_qinao_candidate_inventory
git add scripts/capture_qinao_candidate_inventory.py scripts/test_capture_qinao_candidate_inventory.py
git commit -m "build: capture qinao candidate provenance"
```

Expected: tests cover staged/worktree divergence, empty and non-empty untracked files, unusual filenames, missing base, and a mutation attempt; commit contains exactly two files.

---

### Task 2: Materialize C0 and bind the import map

**Files:**
- Create: clean worktree at `/Users/changgeng/Project/Project06/Project06/.worktrees/qinao-clean-candidate`
- Create: `docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/import-map.json`

**Interfaces:**
- Consumes: Task 1 inventory.
- Produces: zero-dirty C0 base plus a map whose rows are `{path, source_stratum, source_blob_sha256, destination_batch}`.

- [ ] **Step 1: Create a clean reconstruction branch from the approved base**

```bash
git worktree add -b codex/qinao-clean-candidate \
  /Users/changgeng/Project/Project06/Project06/.worktrees/qinao-clean-candidate \
  20fc52ea0e8a367dc4ebe4d73717a1e2e24fb9d0
```

Expected: new worktree HEAD equals the base commit.

- [ ] **Step 2: Prove C0 is clean**

```bash
git -C /Users/changgeng/Project/Project06/Project06/.worktrees/qinao-clean-candidate status --porcelain=v1
```

Expected: zero output.

- [ ] **Step 3: Generate the import map from the frozen inventory**

```bash
python3 scripts/build_qinao_import_map.py \
  --inventory /private/tmp/qinao-clean-candidate-2026-07-23-c0/source-inventory.json \
  --output /private/tmp/qinao-clean-candidate-2026-07-23-c0/import-map.json
```

Expected: every dirty/untracked path appears once; each row selects exactly one of `head`, `index`, `worktree`, or `untracked`; no row selects “latest” or an implicit filesystem value.

- [ ] **Step 4: Review classification before importing bytes**

```bash
python3 scripts/check_qinao_import_map.py \
  --inventory /private/tmp/qinao-clean-candidate-2026-07-23-c0/source-inventory.json \
  --map /private/tmp/qinao-clean-candidate-2026-07-23-c0/import-map.json \
  --allowed-batches C1,C2,C3,C4,hold
```

Expected: exact path-set equality, no duplicate destinations, and all production changes classified `hold` until an owning batch test names them.

---

### Task 3: Establish the externally anchored admission bootstrap

**Files:**
- Create: `.github/workflows/qinao-wave-admission.yml`
- Create: `scripts/check_qinao_wave_admission.py`
- Create: `scripts/test_check_qinao_wave_admission.py`
- Create: `scripts/qinao_gate_modules/**`
- Create: `scripts/qinao_gate_corpora/**`

**Interfaces:**
- Consumes: clean C0, complete gate catalog required from `preW0` through `W6`.
- Produces: bootstrap commit `B0`, external signed bootstrap attestation, and protected canonical-ref policy.

- [ ] **Step 1: Write failing unit tests for predecessor-only activation**

Tests must reject candidate-selected modules, current-wave modules, absent active-through-wave contracts, contract/module/corpus digest mismatch, missing or extra required gates, non-contiguous seals, and a receipt that does not bind exact `Pw` input and result.

```bash
python3 -m unittest -v scripts.test_check_qinao_wave_admission
```

Expected: FAIL because the checker/modules do not yet exist.

- [ ] **Step 2: Implement the minimal bootstrap verifier**

`check_qinao_wave_admission.py` must accept only:

```text
--bootstrap-attestation
--prior-seal
--candidate-payload-commit
--candidate-evidence-commit
--wave
--output-receipt
```

It must derive the active verifier and gate contracts from the bootstrap/prior seal, never from candidate bytes. It must validate the exact `required_gates_by_wave[{gate_id, gate_contract_digest}]` set and bind each result to contract, module, corpus, `Pw`, command identity, exit status, and canonical result digest.

- [ ] **Step 3: Run positive and mutation corpora**

```bash
python3 -m unittest -v scripts.test_check_qinao_wave_admission
python3 scripts/check_qinao_wave_admission.py --self-test-corpus scripts/qinao_gate_corpora
```

Expected: all positive cases pass; every mutation fails with a stable reason code.

- [ ] **Step 4: Pin workflow actions and least privilege**

The workflow must use full 40-hex Action SHAs, `permissions: contents: read`, no pull-request write token, no candidate-controlled `uses`, no mutable ref checkout for admission, and artifact upload only for privacy-clean receipts.

```bash
python3 scripts/check_qinao_wave_admission.py \
  --lint-workflow .github/workflows/qinao-wave-admission.yml
```

Expected: `workflow_policy=pass`.

- [ ] **Step 5: Commit bootstrap bytes alone**

```bash
git add .github/workflows/qinao-wave-admission.yml \
  scripts/check_qinao_wave_admission.py \
  scripts/test_check_qinao_wave_admission.py \
  scripts/qinao_gate_modules \
  scripts/qinao_gate_corpora
git commit -m "build: bootstrap qinao wave admission"
```

Expected: commit contains only the listed bootstrap paths.

- [ ] **Step 6: Complete the external bootstrap ceremony**

An independent reviewer must record the exact bootstrap commit/tree, verifier/module/corpus digests, repository/OIDC identity, protected canonical ref, required-status policy, and pinned Action SHAs in an external signed attestation. If protected-ref CAS or external attestation infrastructure is absent, record `BLOCKED_BOOTSTRAP`; do not self-host.

---

### Task 4: Atomically converge authority text and Owner Ledger schema v2

**Files:**
- Modify all four governing addenda, exact seven controlled documents, Owner Ledger, recovery companion, and non-authoritative CoreAI convergence plan listed in File Map.
- Modify: `scripts/check_qinao_owner_ledger.py`
- Modify: `scripts/test_check_qinao_owner_ledger.py`

**Interfaces:**
- Consumes: approved correction spec and predecessor-authorized bootstrap.
- Produces: one C1+C2 payload slice with seven controlled documents, four governing addenda, exact contract catalog, release profiles, wave admission policy, and 113 finding identities.

- [ ] **Step 1: Add RED tests for the controlled schema-v2 cardinalities**

Tests must assert:

```text
controlled_documents == 7
governing_addenda_v1 == 4
admitted_findings == 113
legacy_qrm_findings == 74
source_review_findings == 39
reported_external_count == 45
reported_external_identity == "unverified_external_identity"
```

They must also reject same-version contract mutation, missing reciprocal references, orphan catalog/profile rows, more than one active required profile version, and any attempt to count the external 45 inside `findings[]`.

```bash
python3 -m unittest -v scripts.test_check_qinao_owner_ledger
```

Expected: FAIL on schema v1.

- [ ] **Step 2: Apply the approved canonical wording atomically**

Update every affected authority with the identical:

```text
L7/R0 → L8 LaneQuery → R1-R4 → L8 LaneResult → R5 → R6
```

and the corrected ownership for K3 semantic currentness, coordinator publication handoff, Provider permit Artifact versus K3 boundary row, L1 consumption versus K1 observation, `BASContextCompiler`, `needs-confirmation`, idle/post-answer NextQuestion, root/Session CAS, recovery facets, one-call Provider branches, V1 buffered visibility, and signed raw-content Decision Gate.

- [ ] **Step 3: Demote the recovery companion**

`qinao-authority-corruption-recovery-v1.md` must state it is non-authoritative. Every adopted recovery rule must exist in an incumbent owner/domain document. No checker may count the companion as a controlled document or governing addendum.

- [ ] **Step 4: Add the exact contract/profile deltas**

Resolve existing `contract_id` values before writing vNext rows. Add one new stable ID for `BASAuthorizedInputEffectPredecessorPayload`; retain IDs and increment versions for affected StatePrepare/outbox and remote credential contracts. Add the content-intake profile/receipt family under existing E/A owners. Do not add a mutable owner.

- [ ] **Step 5: Run authority consistency and stale-language scans**

```bash
python3 -m unittest -v scripts.test_check_qinao_owner_ledger
python3 scripts/check_qinao_owner_ledger.py \
  --root . \
  --ledger docs/superpowers/specs/qinao-owner-ledger-v1.json \
  --candidate-manifest /private/tmp/qinao-clean-candidate-2026-07-23-c0/import-map.json
rg -n 'executeExactlyOnce|rg -L|QinaoRuntimeTests|Tools/mamba3_statelake.py|surviving external recovery registry' \
  docs/superpowers/specs docs/superpowers/plans
```

Expected: checker passes with non-zero candidates; stale scan returns zero.

- [ ] **Step 6: Commit the indivisible authority payload**

```bash
git add docs/superpowers/specs docs/superpowers/plans \
  scripts/check_qinao_owner_ledger.py \
  scripts/test_check_qinao_owner_ledger.py
git diff --cached --check
git commit -m "docs: converge qinao controlled authority"
```

Expected: no production source in the commit; controlled membership remains 7+4.

---

### Task 5: Make review, W0, iOS-floor, and CI gates non-vacuous

**Files:**
- Import/modify the existing gate slice listed in File Map.
- Modify: `.github/workflows/test.yml`

**Interfaces:**
- Consumes: frozen source strata and schema-v2 authority.
- Produces: executable checkers whose documented and CI calls exercise candidate creation, discovery, and tests.

- [ ] **Step 1: Add RED tests for every vacuity class**

Cover: omitted `--candidate-manifest`, zero candidates, zero Swift test matches, missing named files, glob matching zero files, `rg` exit 2, absent pytest dependency, checker absent from CI, renamed test target, and future-wave API referenced by an earlier-wave baseline.

- [ ] **Step 2: Repair documented and CI invocations**

The owner-ledger invocation must include the candidate manifest. CI must run all checker unit suites with `python3 -m unittest`; it must not require third-party `pytest`. Every Swift filter must run through `scripts/run_nonempty_swift_filter.py`.

- [ ] **Step 3: Replace unsafe content scans**

Before every `rg` scan, assert each named path exists. Replace `rg -L` misuse with an explicit per-file missing-match loop that distinguishes “no match” from read error. Replace `*LayerCore.swift` with a manifest-derived exact file set. Anchor model-boundary scans to imports/declarations rather than comments and string literals.

- [ ] **Step 4: Run the complete checker suite**

```bash
python3 -m unittest -v \
  scripts.test_check_qinao_owner_ledger \
  scripts.test_check_qinao_review_candidate \
  scripts.test_qinao_review_closure \
  scripts.test_check_w0_expected_open_set \
  scripts.test_check_k4_platform_proof \
  scripts.test_check_xcode27_toolchain \
  scripts.test_run_nonempty_swift_filter \
  scripts.test_check_bas_organ_descriptor_constructors \
  scripts.test_test_workflow_owner_ledger
```

Expected: all tests pass and output reports positive discovery counts.

- [ ] **Step 5: Commit gate repairs as a coherent candidate slice**

```bash
git add .github/workflows/test.yml scripts
git diff --cached --check
git commit -m "build: make qinao convergence gates non-vacuous"
```

Expected: no unrelated production source.

---

### Task 6: Add production reachability, closure report, and V2 quarantine

**Files:**
- Create the four schemas and six generator/checker/test files in File Map.

**Interfaces:**
- Consumes: schema-v2 Owner Ledger, exact release profiles, candidate-index tree.
- Produces: deterministic non-authoritative reachability and closure projections plus an exact seven-feature/21-rule V2 quarantine result.

- [ ] **Step 1: Write RED schema and mutation tests**

Tests must reject missing/renamed package/Xcode/XcodeGen roots, unclassified projects, caller-selected roots, stale generated projects, floating shipping dependencies, missing `Package.resolved`, unclassified flags/configurations/architectures, indirect factory edges, and candidate-generated expected output.

- [ ] **Step 2: Implement temporary-output generators**

Both generators must write to a temporary path, canonicalize there, and byte-compare to the candidate-index expected file. They must never overwrite the expected file before comparison.

- [ ] **Step 3: Encode exact governed roots**

The production graph begins with:

```text
BehavioralAISubstrate/Package.swift
QinaoRuntimeSDK/Package.swift
SampleHost/Package.swift
```

It must classify `BehavioralAISubstrate/DeviceTestApp/project.yml`, its `.xcodeproj`, every governed Xcode project/workspace/configuration/scheme, and the future ArtifactMeshDeviceLab as shipping, lab, or evidence with proof.

- [ ] **Step 4: Encode the exact V2 quarantine**

The manifest must contain exactly seven stable feature IDs and exactly 21 stable rule IDs from the approved design. Every predicate must execute, and direct, alias, indirect-link, conditional-compilation, and manifest-shrink mutations must fail.

- [ ] **Step 5: Run tests and deterministic compare**

```bash
python3 -m unittest -v \
  scripts.test_check_qinao_production_reachability \
  scripts.test_check_qinao_architecture_closure
python3 scripts/check_qinao_production_reachability.py --root . --compare-index
python3 scripts/check_qinao_architecture_closure.py --root . --compare-index
```

Expected: non-zero entrypoints and tests; complete exact-set equality; no report grants authority.

- [ ] **Step 6: Commit schemas and verifier code**

```bash
git add docs/superpowers/specs/qinao-*-v1.schema.json \
  scripts/generate_qinao_production_reachability.py \
  scripts/check_qinao_production_reachability.py \
  scripts/test_check_qinao_production_reachability.py \
  scripts/generate_qinao_architecture_closure.py \
  scripts/check_qinao_architecture_closure.py \
  scripts/test_check_qinao_architecture_closure.py
git commit -m "build: close qinao production reachability"
```

---

### Task 7: Form and admit the C1+C2 `Pw → Cw → Sw` chain

**Files:**
- Create: payload and evidence manifests under `docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/`.
- Create externally: signed wave seal and protected-ref CAS attestation.

**Interfaces:**
- Consumes: Tasks 3-6.
- Produces: exactly three commits: payload `Pw`, evidence-only child `Cw`, receipt-only seal `Sw`.

- [ ] **Step 1: Freeze `Pw`**

```bash
git status --porcelain=v1
git rev-parse HEAD
git rev-parse HEAD^{tree}
```

Expected: the clean candidate contains only reviewed C1+C2 commits; capture exact commit/tree/build identity.

- [ ] **Step 2: Run predecessor-authorized gates against `Pw`**

Use only the bootstrap-derived verifier/modules. Candidate-local checker execution is preflight, not admission.

Expected: each active gate yields a contract/module/corpus/input/result-bound receipt.

- [ ] **Step 3: Create evidence-only `Cw`**

Only schema-frozen privacy-clean evidence leaves and one manifest may change. Each leaf binds `Pw`; none may claim `Cw` itself.

```bash
git diff --name-only HEAD^..HEAD
python3 scripts/check_qinao_wave_admission.py \
  --bootstrap-attestation /private/tmp/qinao-bootstrap-attestation.json \
  --candidate-payload-commit Pw \
  --candidate-evidence-commit HEAD \
  --wave preW0 \
  --output-receipt /private/tmp/qinao-prew0-receipt.json
```

Expected: verifier proves `Cw = Pw + evidence-only diff`.

- [ ] **Step 4: Create receipt-only `Sw`**

`Sw` may contain only the signed admission receipt and manifest binding the already-existing `Cw` tree. It cannot change source, authority, tests, schemas, or gate code.

- [ ] **Step 5: CAS the protected canonical ref**

If live branch protection, external attestation, expected prior ref, or CAS fails, retain the commits as non-authoritative evidence and report `BLOCKED_ADMISSION`. Never force-update.

---

### Task 8: Admit C3 W0 freezes without later-wave dependencies

**Files:**
- Import only the W0 source/test slice selected by `import-map.json`.
- Test: `QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/QinaoEffectFacadeFreezeTests.swift`
- Test: W0 silicon/provider freeze tests in their existing declared test targets.

**Interfaces:**
- Consumes: admitted C1+C2 seal.
- Produces: W0 freeze payload that compiles using only APIs present at W0.

- [ ] **Step 1: Verify every filter discovers tests**

```bash
python3 scripts/run_nonempty_swift_filter.py \
  --package QinaoRuntimeSDK \
  --filter QinaoEffectFacadeFreezeTests
```

Expected: discovery count greater than zero.

- [ ] **Step 2: Remove future-wave dependencies from W0 baselines**

W0 tests may inspect current API shape and freeze prohibited paths. They must not call `adapter(providerID:)`, `operation.stream().final()`, spool fields, or any W1-W5 API not present in `Pw`.

- [ ] **Step 3: Verify the iOS 27 floor everywhere**

```bash
python3 -m unittest -v scripts.test_check_xcode27_toolchain
sh BehavioralAISubstrate/scripts/check-ios27-floor.sh
```

Expected: all Package.swift files, Xcode projects, scripts, and XCFramework build settings resolve to iOS 27 or later; `build-rust-xcframework.sh` contains no iOS 18 declaration/comment.

- [ ] **Step 4: Run package tests**

```bash
swift test --package-path QinaoRuntimeSDK
swift test --package-path BehavioralAISubstrate
```

Expected: all W0 suites compile and pass; zero-match filters are impossible.

- [ ] **Step 5: Admit C3 through a new `Pw/Cw/Sw` chain**

Use the preW0 seal to derive active W0 modules. Repeat Task 7 with `--wave W0`.

---

### Task 9: Complete C4 K4 platform proof or remain blocked

**Files:**
- Import/review: `docs/superpowers/evidence/qinao-k4-platform-spike/**`
- Modify only if evidence semantics require it: `scripts/check_k4_platform_proof.py`
- External only: archive/device/raw proof bundle.

**Interfaces:**
- Consumes: admitted W0 payload, actual signed archive, physical iOS 27 device, verifier challenge.
- Produces: privacy-clean K4 attestation or explicit blocked status.

- [ ] **Step 1: Preserve the checker unit baseline**

```bash
python3 -m unittest -v scripts.test_check_k4_platform_proof
```

Expected: 25 tests pass. This is checker validation, not K4 production proof.

- [ ] **Step 2: Run a verifier-driven physical-device proof**

The verifier—not the app or caller—must generate the fresh challenge and bind actual archive, Mach-O, CDHash, profile, entitlement, `Pw`, device pseudonym, and runtime result. Synthetic logs, source-shaped fixtures, and caller-supplied challenges fail.

- [ ] **Step 3: Store sensitive bytes externally**

Write the raw evidence only to the bootstrap-pinned encrypted immutable store. Git receives the signed privacy-clean attestation, Merkle root, coverage map, destruction-obligation ID, and verifier receipt.

- [ ] **Step 4: Reopen and independently verify**

Before retention expiry, obtain a purpose-bound short-lived grant, reopen exact object versions, recompute the Merkle root and semantic proof, and destroy temporary plaintext.

- [ ] **Step 5: Decide C4**

If any archive/device/external-storage/reopen/destruction field is missing, set `overall_gate=blocked` and do not admit C4. If all pass, form and admit a C4 `Pw/Cw/Sw` chain using predecessor-derived K4 modules.

---

### Task 10: Resume C5/W1-W6 in dependency order

**Files:**
- Execute the corrected convergence master and five domain plans.
- Do not import `hold` production bytes until their owning task is active.

**Interfaces:**
- Consumes: admitted C4 seal or an explicit policy proving a wave has no K4 dependency.
- Produces: one admitted `Pw/Cw/Sw` chain per W1-W6 wave.

- [ ] **Step 1: Start W1 with Artifact Mesh Task 0**

Run the exact non-empty Artifact Mesh store suite before any consumer. Prove first-create/reopen identity, FULL-equivalent durability, Keychain anchor/host assembly, floor state machine, DB/WAL/SHM quarantine, CAS/lost-reply/corruption recovery, and the exact 13-operation/14-fault/40-row matrix. If reboot-before-first-unlock proof is unavailable, Artifact Mesh remains blocked.

- [ ] **Step 2: Enforce dependency-valid wave tests**

No RED test may reference a later-wave type. The three-fixture rule applies only where real backward material exists; it must not violate exact migration/governed-object cardinalities. Every `--filter` is wrapped by the non-empty runner.

- [ ] **Step 3: Execute W1-W6 with predecessor gate activation**

For each wave:

```text
derive active contracts/modules from prior Sw
build Pw
run exact gates over Pw
build evidence-only Cw
verify Cw = Pw + allowlisted evidence
build receipt-only Sw
CAS protected canonical ref
record post-CAS attestation
```

- [ ] **Step 4: Keep structural and performance gates separate**

Architecture cutover may require the routing, lease, fairness, memory accounting, and measurement machinery. It must not require universal cold40/sustained30. Performance certification requires exact workload/archive/entitlement/two-device trace evidence and passes only for the certified profile.

- [ ] **Step 5: Run final release closure**

```bash
python3 scripts/check_qinao_owner_ledger.py \
  --root . \
  --ledger docs/superpowers/specs/qinao-owner-ledger-v1.json \
  --candidate-manifest docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/payload-manifest.json
python3 scripts/check_qinao_production_reachability.py --root . --compare-index
python3 scripts/check_qinao_architecture_closure.py --root . --compare-index
swift test --package-path BehavioralAISubstrate
swift test --package-path QinaoRuntimeSDK
swift test --package-path SampleHost
```

Expected: positive candidate, entrypoint, and test counts; exact owner/contract/profile/reachability equality; no unresolved known true finding; no shipping V2 reachability; all package tests pass.

- [ ] **Step 6: Finalize only from the W6 protected-ref CAS**

The final report must name exact `Pw`, `Cw`, `Sw`, protected ref, toolchain, archive/profile, active contract set, unresolved blocked optional claims, and external evidence expiry. A generated closure report is evidence projection, never authority.

---

## Plan Self-Review Checklist

- [ ] Every approved correction requirement maps to C1/C2, C3, C4, or C5.
- [ ] Exactly seven controlled documents and four governing addenda remain.
- [ ] Exactly two new immutable value-contract families are introduced.
- [ ] All 113 admitted findings and the non-counting external 45 are kept distinct.
- [ ] No task instructs an engineer to bulk-import the dirty tree.
- [ ] No current-wave candidate selects its own verifier or active gate module.
- [ ] Every filter and file scan has a non-vacuity rule.
- [ ] K4 cannot pass on synthetic or privacy-clean projection-only evidence.
- [ ] Artifact Mesh cannot become implemented without physical durability/recovery proof.
- [ ] 40/30 is never an unconditional architecture completion gate.
- [ ] V1 visibility remains buffered and one-invocation.
- [ ] Unknown external state remains query/reconcile-only.
- [ ] No placeholder implementation authority is hidden in this plan.
