# Qinao P0 Execution Containment Implementation Plan

> **For Codex:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` to implement this plan task-by-task, with `superpowers:test-driven-development` for every production change and `superpowers:verification-before-completion` before any success claim.

**Goal:** Fail closed at the two currently reachable local-tool execution sinks identified by the replacement Deep Scan, without adding a new authority or persistence owner.

**Architecture:** Harden the existing deny-default HumanEval sandbox and connect its typed infrastructure outcome through denominator, side-file merge, and verdict semantics. Add a small standard-library checkpoint guard that stages authenticated bytes into an unlinked snapshot before a restricted PyTorch load, and make post-load trained-state validation optimization-proof. Keep Mamba imports candidate-local. This plan contains no gateway registry, K3 journal, sovereign ledger, provider inversion, or workflow mutation.

**Tech Stack:** Python 3 standard library, `unittest`, macOS seatbelt helper, SHA-256, unlinked temporary files, optional PyTorch integration test.

**Approved design:** `docs/superpowers/specs/2026-08-24-qinao-p0-execution-containment-design.md`

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

- [ ] **Step 1: Write the failing delegation test**

Add a test that replaces `run_sandboxed` with a recording fake, calls `execute_generated_program`, and proves the helper forwards the exact Python path, script path, and timeout. The test must also prove the returned object is propagated.

- [ ] **Step 2: Run RED**

```bash
PYTHONDONTWRITEBYTECODE=1 UV_CACHE_DIR=/tmp/qinao-uv-cache \
  uv run --with pytest pytest -q \
  BehavioralAISubstrate/Tools/test_qinao_humaneval_paired.py
```

Expected: two tests are discovered; the new test fails because
`execute_generated_program`/`run_sandboxed` does not exist. Zero discovered
tests is a harness failure, never a pass.

- [ ] **Step 3: Implement the smallest production change**

Import `run_sandboxed`, add the helper, and replace the raw `subprocess.run([PYBIN, "-I", path], ...)` call with the helper. Do not add a fallback.

- [ ] **Step 4: Run GREEN and sandbox behavior tests**

```bash
PYTHONDONTWRITEBYTECODE=1 UV_CACHE_DIR=/tmp/qinao-uv-cache \
  uv run --with pytest pytest -q \
  BehavioralAISubstrate/Tools/test_qinao_humaneval_paired.py

PYTHONDONTWRITEBYTECODE=1 python3 \
  BehavioralAISubstrate/Tools/qinao_local_eval/test_humaneval_sandbox.py
```

Expected: all paired-evaluator tests pass; on macOS all five seatbelt behavior tests pass. Sandbox absence is an infrastructure failure, never a permissive fallback.

- [ ] **Step 5: Commit exact paths**

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

- [ ] **Step 1: Write failing guard and integration tests**

Cover:

- missing/malformed digest rejects before any loader call;
- mismatched digest rejects before any loader call;
- symlink and oversize input reject;
- matching digest loads the snapshotted bytes with `map_location="cpu"` and `weights_only=True`;
- a non-mapping payload rejects;
- the deploy script contains no hard-coded `/Users/changgeng/...` import root and calls the verified guard;
- when PyTorch is installed, a checkpoint containing an execution gadget is rejected without creating its marker file.

- [ ] **Step 2: Run RED**

```bash
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v \
  BehavioralAISubstrate.Tools.test_qinao_checkpoint_guard
```

Expected: import fails because `qinao_checkpoint_guard.py` does not exist.

- [ ] **Step 3: Implement the guard**

Use only the standard library before the post-verification lazy PyTorch import. Hash and stage in one pass. Keep the staged file unlinked. Reject mutation observed during the source snapshot and reject all invalid configuration before deserialization.

- [ ] **Step 4: Integrate the deploy converter**

Resolve the tools directory from `Path(__file__).resolve().parent`; remove the hard-coded primary-checkout path. Require `CKPT_SHA256` for any trained checkpoint. Parse an explicit positive `CKPT_MAX_BYTES` or use the 16 GiB default. Convert guard failures into a concise `SystemExit` refusal. Keep `FORCE_RANDOM=1` checkpoint-free.

- [ ] **Step 5: Run GREEN**

```bash
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v \
  BehavioralAISubstrate.Tools.test_qinao_checkpoint_guard
```

Expected: all tests pass; the optional real-PyTorch exploit test either passes or reports a platform dependency skip.

- [ ] **Step 6: Commit exact paths**

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

- [ ] **Step 1: Run the complete focused suite**

```bash
PYTHONDONTWRITEBYTECODE=1 UV_CACHE_DIR=/tmp/qinao-uv-cache \
  uv run --with pytest pytest -q \
  BehavioralAISubstrate/Tools/test_qinao_humaneval_paired.py

PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v \
  BehavioralAISubstrate.Tools.test_qinao_checkpoint_guard

PYTHONDONTWRITEBYTECODE=1 python3 \
  BehavioralAISubstrate/Tools/qinao_local_eval/test_humaneval_sandbox.py
```

- [ ] **Step 2: Prove source-to-sink closure and clean patch shape**

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

- [ ] **Step 3: Independent review**

Run one specification-compliance review and one code-quality/security review. Any critical or important issue returns to the responsible task through a fresh RED test before correction.

- [ ] **Step 4: Record the next governed boundary**

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

- [ ] **Step 1: Write RED tests for typed sandbox activation**

Prove that launcher/profile failure raises `SandboxInfrastructureError`, while a
generated program that prints identical error text and exits nonzero returns a
model-attributable result. Do not inspect stderr to classify infrastructure.

- [ ] **Step 2: Write RED external lifecycle/confinement tests**

On macOS, prove: benign code runs; sensitive reads and network fail; the program
can write inside its private run directory; a sibling file under the same macOS
temporary root cannot be written; and delayed-marker/PID descendants using
redirected pipes plus `start_new_session=True` are absent after both normal
completion and timeout.

- [ ] **Step 3: Implement the smallest authenticated sandbox lifecycle**

Use a private run directory, trusted activation pipe, sanitized environment,
isolated Python, fork denial, a parent-owned session/process group, and cleanup on
every exit. Preserve `subprocess.TimeoutExpired` for genuine model timeouts. Never
fall back to raw execution.

- [ ] **Step 4: Write RED evidence-chain tests**

Create real base/tuned HumanEval side-files for all-infrastructure,
base-only-infrastructure, and tuned-only-infrastructure cases. Seed old metric
`30` and old computed provenance in both values dictionaries. Pass them through
`merge_known_sidefiles` and `build`; every affected gate must be `PENDING` or
`FAIL`, never `PASS` or `NOTE`, and stale values/provenance must be absent.

- [ ] **Step 5: Implement denominator, invalidation, and verdict semantics**

Both HumanEval writers omit metric `30` when `_N == 0` or any infrastructure
error occurred. Both HumanEval side-file prefixes use the shared validator before
metric `30` can be merged and stamped. An invalid present side-file explicitly
revokes existing metric/provenance; unreadable or non-object HumanEval JSON does
the same rather than preserving stale evidence.
Base-relative evaluation without a valid baseline is `PENDING`; verifiable
critical `NOTE` states also block `model_eval_ok` as a defense in depth.

- [ ] **Step 6: Run focused GREEN and commit exact paths**

Run the paired tests, merge tests, gate-integrity tests, and all expanded external
macOS sandbox tests with positive discovery counts. Commit only the ten listed
files after the complete chain is green.

---

### Task 5: Make Trained-State Refusal Optimization-Proof

**Files:**
- Modify: `BehavioralAISubstrate/Tools/mamba3_deploy.py`
- Modify: `BehavioralAISubstrate/Tools/test_qinao_checkpoint_guard.py`
- Modify: `BehavioralAISubstrate/Docs/RUNPOD_DISTILL.md`

- [ ] **Step 1: Write RED optimized-interpreter tests**

Exercise the real deploy control flow under `python -O` with faked conversion
dependencies. Missing trained keys and unexpected tensors must both terminate
before quantization, conversion, output deletion, or `save_asset`. Assert that no
output asset or save marker exists.

- [ ] **Step 2: Replace optimization-sensitive assertions**

Use explicit refusal branches for unexpected tensors and missing trained
parameters. Only decode-state buffers ending in `_all` may be absent. Preserve
the existing authenticated loader and `FORCE_RANDOM=1` behavior.

- [ ] **Step 3: Repair trusted-digest documentation**

Update the module usage and RunPod deploy runbook to require
`CKPT_SHA256=sha256:<trusted-release-digest>`. State that the digest must come
from an independently trusted training/release receipt; computing it from the
same untrusted checkpoint at deploy time is integrity checking, not provenance.

- [ ] **Step 4: Run GREEN and commit exact paths**

Run the dedicated `python -O` regression, the full system-Python checkpoint
suite, and the real-PyTorch exploit suite. Commit only the three listed files.

---

### Task 6: Repeat Whole-Range Adversarial Acceptance

**Files:**
- Verify only, except ignored SDD evidence under `.superpowers/sdd/...`.

- [ ] Re-run every Task 4 and Task 5 suite with positive discovery assertions.
- [ ] Re-run the checkpoint suite with an asserted positive discovery count (currently 23 tests) under real PyTorch, and the complete expanded external seatbelt suite.
- [ ] Run `git diff --check 4f0b9846c..HEAD` and audit every changed path in the full range.
- [ ] Regenerate the protected 33-path manifest and require an exact match with `protected-33-pre.tsv`.
- [ ] Obtain fresh specification and code-quality/security approval over the entire range. Any P1/P0 returns to RED; do not begin the next containment slice.
