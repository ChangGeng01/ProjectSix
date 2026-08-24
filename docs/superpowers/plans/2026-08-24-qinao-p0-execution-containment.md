# Qinao P0 Execution Containment Implementation Plan

> **For Codex:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` to implement this plan task-by-task, with `superpowers:test-driven-development` for every production change and `superpowers:verification-before-completion` before any success claim.

**Goal:** Fail closed at the two currently reachable local-tool execution sinks identified by the replacement Deep Scan, without adding a new authority or persistence owner.

**Architecture:** Reuse the existing deny-default HumanEval sandbox. Add a small standard-library checkpoint guard that stages authenticated bytes into an unlinked snapshot before a restricted PyTorch load. Keep Mamba imports candidate-local. This plan contains no gateway registry, K3 journal, sovereign ledger, provider inversion, or workflow mutation.

**Tech Stack:** Python 3 standard library, `unittest`, macOS seatbelt helper, SHA-256, unlinked temporary files, optional PyTorch integration test.

**Approved design:** `docs/superpowers/specs/2026-08-24-qinao-p0-execution-containment-design.md`

## Global Constraints

- Preserve every pre-existing dirty path byte-for-byte and never stage it.
- Edit only the exact files named by a task.
- RED must fail for the intended missing security behavior before production code changes.
- No unsandboxed fallback, optional digest, unsafe pickle compatibility mode, hard-coded checkout, “latest” selection, or same-artifact self-attestation.
- Do not change `.github/workflows`, controlled-convergence plans, owner-ledger/admission scripts, Swift runtime code, provider manifests, or persistent stores.
- Each implementation task ends with an exact-path commit and a task-review pass.

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
git diff --check HEAD~2..HEAD
git status --short
```

Expected: paired evaluation has only mandatory sandbox delegation; the only checkpoint deserialization is post-verification and explicitly restricted; no hard-coded checkout remains; no whitespace errors; pre-existing dirty paths remain present but unchanged by these commits.

- [ ] **Step 3: Independent review**

Run one specification-compliance review and one code-quality/security review. Any critical or important issue returns to the responsible task through a fresh RED test before correction.

- [ ] **Step 4: Record the next governed boundary**

Do not claim global recovery completion. The next implementation wave is W1 provider/operation convergence followed by K3/EventLog-backed transitions and sovereign-ledger halt epochs, using the incumbent owners named by the active controlled-convergence plan.
