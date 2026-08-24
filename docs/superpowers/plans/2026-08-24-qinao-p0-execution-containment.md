# Qinao P0 Execution Containment Implementation Plan

> **For Codex:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` to implement this plan task-by-task, with `superpowers:test-driven-development` for every production change and `superpowers:verification-before-completion` before any success claim.

**Goal:** Fail closed at the two currently reachable local-tool execution sinks identified by the replacement Deep Scan, without adding a new authority or persistence owner.

**Architecture:** Harden the existing deny-default HumanEval sandbox and connect its typed infrastructure outcome through denominator, side-file merge, and verdict semantics. Add a small standard-library checkpoint guard that stages authenticated bytes into an unlinked snapshot before a restricted PyTorch load, and make post-load trained-state validation optimization-proof. Keep Mamba imports candidate-local. This plan contains no gateway registry, K3 journal, sovereign ledger, provider inversion, or workflow mutation.

**Tech Stack:** Python 3 standard library, `unittest`, macOS seatbelt helper, SHA-256, unlinked temporary files, optional PyTorch integration test.

**Implementation design:** `docs/superpowers/specs/2026-08-24-qinao-p0-execution-containment-design.md`

## Durable Execution State (2026-08-24)

The implementation is persisted through `92519c935`; it is not relying on a
live agent session. Exact correction commits after the rejected `dbc24fe5f`
candidate are:

- `db1f73711` — reviewed deploy commit, self-contained object clone, private
  guard snapshot, isolated startup, and present decode-state zero validation;
- `f144c4057` — distinct sandbox activation/completion witnesses, bounded
  resources and captures, deterministic network denial, and total cleanup;
- `d0f5f6f07` — typed current-run HumanEval receipts, producer ownership,
  subject/harness/dataset/sample-set binding, crash invalidation, and atomic
  publication;
- `23d3254dd` — isolated P0 acceptance environments;
- `d35420278` — host-side sandbox CPU accounting outside model signal control;
- `212a253c3` — anonymous conversion source stream from an isolated temporary
  bare Git namespace;
- `92519c935` — durable HumanEval attempt transactions, ordered multi-tag
  observations, closed runtime types, and portable fd cleanup.

Evidence, sandbox, and deploy now have fresh component `ACCEPT` decisions. The
current gate is the single independent whole-range specification/quality/security
decision over the final committed P0 containment range beginning at
`4f0b9846c`, including this documentation status update. No next containment
slice is authorized until Task 10 is complete. The original 33 dirty paths
remain protected by the frozen manifest and must continue to match exactly.

## Global Constraints

- Preserve every pre-existing dirty path byte-for-byte and never stage it.
- Edit only the exact files named by a task.
- RED must fail for the intended missing security behavior before production code changes.
- No unsandboxed fallback, optional digest, unsafe pickle compatibility mode, hard-coded checkout, “latest” selection, or same-artifact self-attestation.
- Do not change `.github/workflows`, controlled-convergence plans, owner-ledger/admission scripts, Swift runtime code, provider manifests, or persistent stores.
- Each implementation task ends with an exact-path commit and a task-review pass.
- The adversarial-review repair is intentionally one closure bundle: sandbox execution, evidence aggregation, and verdict consumption may not be reviewed or declared complete independently.
- `.superpowers/sdd/2026-08-24-qinao-p0-execution-containment/protected-33-pre.tsv` is the frozen pre-repair manifest. A post-repair manifest must match its 33 path statuses, modes, sizes, and SHA-256 values exactly.

---

### Task 1: Make Paired HumanEval Sandbox-Mandatory

**Files:**
- Modify: `BehavioralAISubstrate/Tools/test_qinao_humaneval_paired.py`
- Modify: `BehavioralAISubstrate/Tools/qinao_local_eval/qinao_humaneval_paired.py`

**Interfaces:**
- Add `execute_generated_program(pybin: str, script_path: str, timeout: int = 15)`.
- Delegate only to `qinao_sandbox.run_sandboxed`.
- Preserve `subprocess.TimeoutExpired` classification and `counts_toward_denominator` behavior.

- [x] **Step 1: Write the failing delegation test**

Add a test that replaces `run_sandboxed` with a recording fake, calls `execute_generated_program`, and proves the helper forwards the exact Python path, script path, and timeout. The test must also prove the returned object is propagated.

- [x] **Step 2: Run RED**

```bash
PYTHONDONTWRITEBYTECODE=1 UV_CACHE_DIR=/tmp/qinao-uv-cache \
  uv run --with pytest pytest -q \
  BehavioralAISubstrate/Tools/test_qinao_humaneval_paired.py
```

Expected: at least two tests are discovered; the new test fails because
`execute_generated_program`/`run_sandboxed` does not exist. Zero discovered
tests is a harness failure, never a pass.

- [x] **Step 3: Implement the smallest production change**

Import `run_sandboxed`, add the helper, and replace the raw `subprocess.run([PYBIN, "-I", path], ...)` call with the helper. Do not add a fallback.

- [x] **Step 4: Run GREEN and sandbox behavior tests**

```bash
PYTHONDONTWRITEBYTECODE=1 UV_CACHE_DIR=/tmp/qinao-uv-cache \
  uv run --with pytest pytest -q \
  BehavioralAISubstrate/Tools/test_qinao_humaneval_paired.py

PYTHONDONTWRITEBYTECODE=1 python3 \
  BehavioralAISubstrate/Tools/qinao_local_eval/test_humaneval_sandbox.py
```

Expected: all paired-evaluator tests pass; on macOS all five seatbelt behavior tests pass. Sandbox absence is an infrastructure failure, never a permissive fallback.

- [x] **Step 5: Commit exact paths**

```bash
git add \
  BehavioralAISubstrate/Tools/test_qinao_humaneval_paired.py \
  BehavioralAISubstrate/Tools/qinao_local_eval/qinao_humaneval_paired.py
git commit -m "fix: sandbox paired model evaluation"
```

---

### Task 2: Authenticate and Restrict Mamba Checkpoint Loading

**Files:**
- Create: `BehavioralAISubstrate/Tools/qinao_checkpoint_guard.py`
- Create: `BehavioralAISubstrate/Tools/test_qinao_checkpoint_guard.py`
- Modify: `BehavioralAISubstrate/Tools/mamba3_deploy.py`

**Interfaces:**
- Add `CheckpointVerificationError`.
- Add `load_verified_weights_checkpoint(path, expected_digest, *, max_bytes=...) -> Mapping`.
- Accepted identity format is exactly `sha256:<64 lowercase hex>`.
- The guard performs `O_NOFOLLOW` regular-file open, bounded copy+hash to an unlinked snapshot, constant-time digest comparison, and `torch.load(snapshot, map_location="cpu", weights_only=True)` only after the match.

- [x] **Step 1: Write failing guard and integration tests**

Cover:

- missing/malformed digest rejects before any loader call;
- mismatched digest rejects before any loader call;
- symlink and oversize input reject;
- matching digest loads the snapshotted bytes with `map_location="cpu"` and `weights_only=True`;
- a non-mapping payload rejects;
- the deploy script contains no hard-coded `/Users/changgeng/...` import root and calls the verified guard;
- when PyTorch is installed, a checkpoint containing an execution gadget is rejected without creating its marker file.

- [x] **Step 2: Run RED**

```bash
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v \
  BehavioralAISubstrate.Tools.test_qinao_checkpoint_guard
```

Expected: import fails because `qinao_checkpoint_guard.py` does not exist.

- [x] **Step 3: Implement the guard**

Use only the standard library before the post-verification lazy PyTorch import. Hash and stage in one pass. Keep the staged file unlinked. Reject mutation observed during the source snapshot and reject all invalid configuration before deserialization.

- [x] **Step 4: Integrate the deploy converter**

Resolve the tools directory from `Path(os.path.abspath(__file__)).parent` so an
inherited `/dev/fd` ZIP import does not resolve back to a reusable source path;
remove the hard-coded primary-checkout path. Require `CKPT_SHA256` for any
trained checkpoint. Parse an explicit positive `CKPT_MAX_BYTES` or use the 16
GiB default. Convert guard failures into a concise `SystemExit` refusal. Keep
`FORCE_RANDOM=1` checkpoint-free.

- [x] **Step 5: Run GREEN**

```bash
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v \
  BehavioralAISubstrate.Tools.test_qinao_checkpoint_guard
```

Expected: all tests pass; the optional real-PyTorch exploit test either passes or reports a platform dependency skip.

- [x] **Step 6: Commit exact paths**

```bash
git add \
  BehavioralAISubstrate/Tools/qinao_checkpoint_guard.py \
  BehavioralAISubstrate/Tools/test_qinao_checkpoint_guard.py \
  BehavioralAISubstrate/Tools/mamba3_deploy.py
git commit -m "fix: authenticate deploy checkpoints"
```

---

### Task 3: Final Security Regression and Scope Audit

**Files:**
- Verify only; do not modify production or governance files.

- [x] **Step 1: Run the complete focused suite**

```bash
PYTHONDONTWRITEBYTECODE=1 UV_CACHE_DIR=/tmp/qinao-uv-cache \
  uv run --with pytest pytest -q \
  BehavioralAISubstrate/Tools/test_qinao_humaneval_paired.py

PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v \
  BehavioralAISubstrate.Tools.test_qinao_checkpoint_guard

PYTHONDONTWRITEBYTECODE=1 python3 \
  BehavioralAISubstrate/Tools/qinao_local_eval/test_humaneval_sandbox.py
```

- [x] **Step 2: Prove source-to-sink closure and clean patch shape**

```bash
rg -n 'subprocess\.run|run_sandboxed' \
  BehavioralAISubstrate/Tools/qinao_local_eval/qinao_humaneval_paired.py
rg -n 'torch\.load|weights_only|CKPT_SHA256|/Users/changgeng' \
  BehavioralAISubstrate/Tools/qinao_checkpoint_guard.py \
  BehavioralAISubstrate/Tools/mamba3_deploy.py
git diff --check 4f0b9846c..HEAD
git diff --name-only 4f0b9846c..HEAD
git status --short
```

Expected: paired evaluation has only mandatory sandbox delegation; the only checkpoint deserialization is post-verification and explicitly restricted; no hard-coded checkout remains; no whitespace errors; the complete implementation range is audited rather than a `HEAD~N` guess; pre-existing dirty paths remain present but unchanged by these commits.

- [x] **Step 3: Independent review**

Run one specification-compliance review and one code-quality/security review. Any critical or important issue returns to the responsible task through a fresh RED test before correction.

- [x] **Step 4: Record the next governed boundary**

Do not claim global recovery completion. The next implementation wave is W1 provider/operation convergence followed by K3/EventLog-backed transitions and sovereign-ledger halt epochs, using the incumbent owners named by the active controlled-convergence plan.

---

### Task 4: Close the Sandbox-to-Verdict Failure Chain

**Review amendment:** This task was added after the whole-range adversarial review
rejected Task 3. It supersedes Task 1's narrow delegation-only acceptance. The
files below are the explicit expansion of scope; none of the 33 protected paths
may be touched.

**Files:**
- Create: `BehavioralAISubstrate/Tools/qinao_local_eval/qinao_humaneval_evidence.py`
- Modify: `BehavioralAISubstrate/Tools/qinao_local_eval/qinao_sandbox.py`
- Modify: `BehavioralAISubstrate/Tools/qinao_local_eval/test_humaneval_sandbox.py`
- Modify: `BehavioralAISubstrate/Tools/qinao_local_eval/qinao_humaneval.py`
- Modify: `BehavioralAISubstrate/Tools/qinao_local_eval/qinao_humaneval_paired.py`
- Modify: `BehavioralAISubstrate/Tools/test_qinao_humaneval_paired.py`
- Modify: `BehavioralAISubstrate/Tools/qinao_local_eval/qinao_merge.py`
- Modify: `BehavioralAISubstrate/Tools/qinao_local_eval/test_merge_sidefile.py`
- Modify: `BehavioralAISubstrate/Tools/qinao_local_eval/build_verdict.py`
- Modify: `BehavioralAISubstrate/Tools/qinao_local_eval/test_gate_integrity.py`

**Interfaces and invariants:**
- Add `SandboxInfrastructureError`; only a private descriptor written by a trusted launcher after seatbelt activation distinguishes infrastructure from model execution.
- Run in a private mode-0700 directory with a minimal environment. Do not grant all of `/private/var/folders`. Permit writes only within the private run root and `/dev/null`.
- Deny generated process creation and own a new process session. Clean the process group after normal return, error, and timeout.
- Put HumanEval evidence construction and validation in one shared pure module; neither writer nor merge may maintain a private schema interpretation.
- Emit metric `30` only for a positive integer denominator, zero infrastructure errors, a finite score in `[0, 100]`, and (for paired evidence) a length/value/aggregate-consistent per-problem vector. Any partial-infrastructure run is unavailable evidence, not a score over a selectively reduced sample.
- When an invalid present HumanEval side-file is merged, remove stale `30` and `_prov["30"]`. Missing baseline evidence for a base-relative gate is `PENDING`; `NOTE` must also remain blocking for any verifiable critical gate.

- [x] **Step 1: Write RED tests for typed sandbox activation**

Prove that launcher/profile failure raises `SandboxInfrastructureError`, while a
generated program that prints identical error text and exits nonzero returns a
model-attributable result. Do not inspect stderr to classify infrastructure.

- [x] **Step 2: Write RED external lifecycle/confinement tests**

On macOS, prove: benign code runs; sensitive reads and network fail; the program
can write inside its private run directory; a sibling file under the same macOS
temporary root cannot be written; and delayed-marker/PID descendants using
redirected pipes plus `start_new_session=True` are absent after both normal
completion and timeout.

- [x] **Step 3: Implement the smallest authenticated sandbox lifecycle**

Use a private run directory, trusted activation pipe, sanitized environment,
isolated Python, fork denial, a parent-owned session/process group, and cleanup on
every exit. Preserve `subprocess.TimeoutExpired` for genuine model timeouts. Never
fall back to raw execution.

- [x] **Step 4: Write RED evidence-chain tests**

Create real base/tuned HumanEval side-files for all-infrastructure,
base-only-infrastructure, and tuned-only-infrastructure cases. Seed old metric
`30` and old computed provenance in both values dictionaries. Pass them through
`merge_known_sidefiles` and `build`; every affected gate must be `PENDING` or
`FAIL`, never `PASS` or `NOTE`, and stale values/provenance must be absent.

- [x] **Step 5: Implement denominator, invalidation, and verdict semantics**

Both HumanEval writers omit metric `30` when `_N == 0` or any infrastructure
error occurred. Both HumanEval side-file prefixes use the shared validator before
metric `30` can be merged and stamped. An invalid present side-file explicitly
revokes existing metric/provenance; unreadable or non-object HumanEval JSON does
the same rather than preserving stale evidence.
Base-relative evaluation without a valid baseline is `PENDING`; verifiable
critical `NOTE` states also block `model_eval_ok` as a defense in depth.

- [x] **Step 6: Run focused GREEN and commit exact paths**

Run the paired tests, merge tests, gate-integrity tests, and all expanded external
macOS sandbox tests with positive discovery counts. Commit only the ten listed
files after the complete chain is green.

---

### Task 5: Make Trained-State Refusal Optimization-Proof

**Files:**
- Modify: `BehavioralAISubstrate/Tools/mamba3_deploy.py`
- Modify: `BehavioralAISubstrate/Tools/test_qinao_checkpoint_guard.py`
- Modify: `BehavioralAISubstrate/Docs/RUNPOD_DISTILL.md`

- [x] **Step 1: Write RED optimized-interpreter tests**

Exercise the real deploy control flow under `python -O` with faked conversion
dependencies. Missing trained keys and unexpected tensors must both terminate
before quantization, conversion, output deletion, or `save_asset`. Assert that no
output asset or save marker exists.

- [x] **Step 2: Replace optimization-sensitive assertions**

Use explicit refusal branches for unexpected tensors and missing trained
parameters. Only the exact decode-state buffers registered by the selected
stack/separate mode may be absent. Suffix-shaped or unregistered names are
trained-state failures. A present registered decode-state tensor must be proven
zero before loading. Preserve the authenticated loader and `FORCE_RANDOM=1`.

- [x] **Step 3: Repair trusted-digest documentation**

Update the module usage and RunPod deploy runbook to require
`CKPT_SHA256=sha256:<trusted-release-digest>`. State that the digest must come
from an independently trusted training/release receipt; computing it from the
same untrusted checkpoint at deploy time is integrity checking, not provenance.

- [x] **Step 4: Run GREEN and commit exact paths**

Run the dedicated `python -O` regression, the full system-Python checkpoint
suite, and the real-PyTorch exploit suite. Commit only the three listed files.

---

### Task 6: Historical Whole-Range Acceptance Attempt — Executed and Rejected

**Files:**
- Verify only, except ignored SDD evidence under `.superpowers/sdd/...`.

- [x] Re-run Task 4 and Task 5 suites with positive discovery assertions for the
  then-current candidate.
- [x] Run the then-current real-PyTorch and external Seatbelt suites.
- [x] Audit the exact rejected range `4f0b9846c..dbc24fe5f` and compare the
  protected manifest 33/33.
- [ ] Obtain whole-range approval. This historical candidate was rejected; its
  failures led to Tasks 7–11 and cannot be retroactively called accepted.

---

### Task 7: Bind HumanEval Evidence to a Current Run Receipt

**Review amendment:** Fresh review rejected `dbc24fe5f` because filename-shaped
explicit inputs could mint producer identity, valid old files could be replayed,
and base/tuned aggregates did not prove the same task set.

**Files:** the ten paths committed in `d0f5f6f07`, including both writers, the
shared evidence module, merge/verdict, ladder/README, and their focused tests.

- [x] Add RED probes for HumanEval-looking explicit filenames and make arbitrary
  explicit paths permanently generic.
- [x] Require a typed producer and explicit current-run context containing a
  run-scoped directory, tag-specific external subject SHA-256 receipt, current
  harness digest, and expected materialized dataset fingerprint.
- [x] Compare the loaded dataset object's actual fingerprint with the receipt;
  bind canonical sample IDs/count/digest and strict passed/total arithmetic.
- [x] Require base/tuned run, producer, harness, dataset and task-set equality
  before metric 30 can be evaluated.
- [x] Revoke both standard and paired outputs before heavy imports/model load;
  publish only by same-directory atomic replacement; never existence-cache
  HumanEval in the ladder.
- [x] Make the ladder candidate-local through `BASH_SOURCE`, validate `N` in
  `1...164`, and keep standard/paired body-only assembly semantics identical.
- [x] Run 18 added RED->GREEN regressions, focused 75/75, complete local-eval
  145/145, lint/shell checks, and commit exact paths as `d0f5f6f07`.

### Task 8: Prove Normal Completion and Bound Sandbox Resources

**Review amendment:** A generated `SystemExit(0)`/`os._exit(0)` could terminate
before `check(...)` completed while the old harness counted process status zero
as PASS. Captured output, memory, threads and private-directory use were also
not quantitatively bounded.

- [x] Reproduce both early-zero-exit false PASS cases before production edits.
- [x] Keep activation and normal completion as distinct randomized out-of-band
  witnesses; only a trusted launcher's normal `runpy` return emits completion.
- [x] Preserve true wall timeout as `TimeoutExpired`; return a bounded nonzero
  model result after a resource-policy breach; keep activation, observability and
  cleanup failures as typed infrastructure errors.
- [x] Add CPU/FSIZE/NOFILE kernel backstops plus bounded capture and host-observed
  RSS/thread/directory-size/file-count monitoring with total teardown.
- [x] Add Darwin task-info/Mach-timebase live CPU accounting plus `wait4` exit
  accounting; handled or ignored `SIGXCPU` remains a CPU policy failure.
- [x] Snapshot generated source through one `O_NOFOLLOW` bounded FD and traverse
  quota directories by anchored no-follow descriptors.
- [x] Replace the non-deterministic public-IP network probe with a local listener
  proof and run the final real external macOS Seatbelt suite 43/43.
- [x] Commit only sandbox implementation/tests as `f144c4057`.
- [x] Commit host-side CPU accounting as `d35420278` and obtain fresh sandbox
  component `ACCEPT`.

### Task 9: Execute Only a Reviewed Source Snapshot

**Review amendment:** Git status trusted index flags, conversion still ran from a
mutable checkout after its last check, Python inherited startup injection, and a
checkpoint could carry present nonzero registered decode state while the tool
claimed zero initialization.

- [x] Reproduce skip-worktree/assume-unchanged, ambient Git/Python/uv injection,
  post-check mutation, symlink/gitlink and present-nonzero-state cases.
- [x] Clone a self-contained object store without checkout, verify the exact full
  commit and security floor, reject non-regular tree modes, and execute guards
  from a private commit-derived snapshot with fresh pre/post indices.
- [x] Export conversion bytes from a fresh isolated temporary bare namespace
  directly into an unlinked `TemporaryFile`; execute only that inherited fd.
- [x] Initialize the temporary namespace with `--template=`, exclude the object
  clone's local config, `refs/replace`, and `.git/info/attributes`, explicitly
  disable system/global configuration and attributes, and require
  `uv --no-config run --no-project`.
- [x] Build fresh indices from the reviewed tree for pre/post exact-snapshot
  checks; use environment whitelists, isolated Python, and `uv --no-config`.
- [x] Reject present nonzero registered decode-state tensors before quantization,
  conversion, output replacement or save; retain exact zero positive controls.
- [x] Run system 45 discovered tests (43 pass plus two honest dependency skips),
  real PyTorch 45/45, shell/diff checks, commit the reviewed-snapshot foundation
  as `db1f73711`, and commit the anonymous stream correction as `212a253c3`.
- [x] Obtain fresh deploy component `ACCEPT`.

### Task 10: Integrate and Re-Accept the Whole Range

- [x] Re-run non-sandbox HumanEval/local-eval 136/136, system checkpoint 45
  discovered with two honest dependency skips, real-PyTorch checkpoint 45/45,
  and external macOS Seatbelt 43/43.
- [x] Inspect the implementation range `4f0b9846c..92519c935` and require
  `git diff --check`; the final whole-range reviewer must additionally include
  this documentation status commit.
- [x] Require the protected manifest to remain exactly 33/33 and audit every
  changed path for forbidden owner/store/ledger/workflow/Swift scope expansion.
- [x] Obtain fresh component `ACCEPT` decisions for evidence, sandbox, and deploy.
- [x] Record accepted residual boundaries without upgrading them into guarantees.
- [ ] Obtain one independent whole-range specification/quality/security
  `ACCEPT`; only then may the design status be advanced. This plan does not by
  itself authorize W1, K3/EventLog, ledger, or global recovery work.

### Task 11: Make HumanEval Publication and Observation Transactional

**Files:** exactly the ten evidence paths committed in `92519c935`: README,
writers, shared evidence module, merge/verdict, ladder, and their three focused
test files.

- [x] Make ladder evidence directories fresh mode-0700 instances and validate
  the exact selector set before starting any producer.
- [x] Keep a unique fsynced incomplete-attempt marker visible for the full
  producer body; serialize same-tag writers with an exclusive lock and prune
  stale markers only while holding that lock.
- [x] Retain the exact published inode fd through normal commit; on commit
  failure prove a durable marker, exact-fd poison, or durable path invalidation.
- [x] Observe base/tuned under deterministically ordered shared locks and one
  anchored directory snapshot so the verdict cannot read a fractured pair.
- [x] Accept only exact internal observation runtime types; require active,
  complete lock state and revalidate directory plus lock path/fd identity.
- [x] Attempt every flock release before closing each detached fd exactly once;
  preserve an existing primary error and surface cleanup-only failures.
- [x] Bind metric-30 score/passed provenance and require distinct base/tuned tags
  and subjects.
- [x] Run RED-to-GREEN adversarial probes, focused transaction tests 107/107,
  complete non-sandbox HumanEval/local-eval 136/136, Ruff, shell, and diff checks.
- [x] Commit only the ten scoped paths as `92519c935` and obtain fresh evidence
  component `ACCEPT` with P0–P3 clear.
