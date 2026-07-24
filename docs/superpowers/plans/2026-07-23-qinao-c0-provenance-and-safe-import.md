# Qinao C0 Provenance and Safe Import Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Repair and preserve the adopted 22-commit clean-candidate lineage, then add a read-only, byte-exact provenance and reviewed-import mechanism that cannot mutate the dirty source or overwrite an intervening clean-candidate edit.

**Architecture:** C0 has two immutable roles. The dirty source worktree is evidence only: a stable double-read inventories its base, HEAD, index, worktree, untracked, deletion, mode, symlink, and non-UTF-8 path strata without invoking an object-writing command from the source root or changing its index, refs, worktree, or files. The adopted clean candidate is the only execution root: an exact root/branch/ancestry guard protects every mutating command, an all-`hold` import map requires an explicit source stratum for every imported row, and a separate ephemeral apply plan binds the destination HEAD/tree/index plus every touched preimage. Candidate-side temporary-index construction may add unreachable objects to the repository's shared common object store; those objects change no source identity and are explicitly outside the source-stability oracle. A durable per-worktree transaction journal is fsynced before `git apply --index`; restart classifies the exact preimage, staged postimage, committed postimage, or divergence, so a crash can resume or return the same receipt without reset or blind replay.

**Tech Stack:** Git object/index plumbing, Python 3 standard library only, `unittest`, canonical JSON, SHA-256, `os.lstat`/`O_NOFOLLOW`, temporary indexes, and Git binary patches.

## Global Constraints

- Approved design commit: `59c26f508262d7c25869faac0ec0abf968ec1e02`.
- Approved design path: `docs/superpowers/specs/2026-07-23-qinao-convergence-correction-and-clean-candidate-design.md`.
- Approved design SHA-256: `3af1067ad2c3d37c36d7613ad19d1dd035bb6f1c60f06b75d5d71de22874d1b4`.
- Approved dynamic-graph inventory input: commit `9d484befb4a4593d93789457ebddfd7cde358e3b`, path `docs/superpowers/specs/2026-07-24-qinao-dynamic-agent-graph-workflow-design.md`, blob `e2c59656f9eb184efc3ab933fe442c9dd0b7d507`, SHA-256 `5f36d0b04579f805a3a69254325e62e22625f4ddd31663e03cbf78b1a39460d5`.
- Preserved source root: `/Users/changgeng/Project/Project06/Project06/.worktrees/qinao-w0`.
- Preserved source branch: `codex/qinao-w1`.
- Adopted candidate root: `/Users/changgeng/.codex/worktrees/e4d7/Project06`.
- Adopted candidate branch: `codex/qinao-w1-clean-candidate`.
- Audited 22-commit candidate tip: `486e1ec5983ad4390c5b07f04607f1345b912c4c`.
- During C0, the audited tip is exactly 22 commits after the approved design commit and must remain an ancestor. Do not rebase, squash, amend, force-update, or reconstruct a second worktree while executing this plan. After C0 hands off, Bootstrap Task 10 is the sole authority allowed to replace that ancestry invariant: it first preserves the audited and final-preparation tips under the two specified create-once forensic refs, then creates a tree-identical single-parent `Pw` above `B0` and updates only the candidate branch by one expected-old-OID transaction.
- The existing uncommitted candidate delta is only `scripts/check_qinao_owner_ledger.py`; its pre-repair binary-patch SHA-256 is `ca122962ca9f198b8a951cd04696b0bdd7c780c8b7c190f922942826ef677f8d`.
- The dirty source is read-only. Do not run `git add`, `git reset`, `git clean`, `git checkout`, `git restore`, `git write-tree` against its real index/object environment, a formatter, or any file-writing command there.
- All implementation and commits execute from the adopted candidate root. A command run from the preserved source root must fail before mutation.
- Python dependencies are standard-library only. Tests run with `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest`; no `pytest`, package install, or network access is allowed.
- Git path identity is raw bytes encoded as canonical padded RFC 4648 Base64 in `path_b64`. `display_path` is diagnostic only and can never select a file.
- A deletion is an absent selected postimage with a present predecessor; it is never represented by an empty blob.
- Symlinks are inventoried as link-target bytes with mode `120000`; no code follows them. Absolute, escaping, or parent-component symlinks fail closed.
- Directories, FIFOs, sockets, devices, unresolved index stages, replace objects, grafts, and shallow ancestry fail closed.
- Inventory capture performs two complete equal reads. One unequal pair causes one full retry; a second unequal pair fails with `source_drift`.
- `candidate_base_commit` in the reviewed map equals
  `inventory.approved_base_commit` byte-for-byte, must reopen as a commit, and
  must be an ancestor of the guarded candidate `HEAD`. It records the
  immutable approved reconstruction base and is never a caller-selected
  substitute for the later destination CAS.
- Every apply operation first creates an ephemeral apply-plan JSON. That plan binds the current candidate HEAD, HEAD tree, index tree, clean-status digest, import-map digest, inventory digest, batch, selected rows, and exact destination preimages.
- Apply rejects a changed HEAD/tree/index/status, changed map/inventory, changed source byte/mode, missing or new destination path, destination symlink, or any unstaged/untracked/intervening edit.
- Apply uses a temporary index to construct a full-index binary patch and `git apply --index --binary`; it never copies a directory, chooses “latest,” follows a symlink, or overwrites a mismatched preimage.
- Apply holds a kernel-released `flock` and a canonical journal below the
  linked worktree's own Git directory. A process crash cannot leave a
  permanent existence lock. Exact preimage resumes, exact staged postimage
  returns the same deterministic receipt, exact committed postimage finalizes
  idempotently, and every other shape is quarantined without mutation.
- No C0 tool creates or changes B0/admission authority, controlled authority text, K4 evidence, Artifact Mesh, production code, a protected ref, or an external attestation.
- Stage exact paths only. Each commit step compares the staged path set before committing.

## Approved Dynamic Graph C0 Amendment

C0 receives the graph design only as held inventory/provenance input. It
changes no C0 schema, selector, import-map semantics, review protocol, batch
cardinality, or authority. The graph specification is not an import bypass.

The mandatory order is:

1. commit all six 2026-07-23 plan amendments, including this file, in the
   preserved source lineage;
2. capture C0 from that exact committed source state;
3. perform the sole fixed ten-row C1 context/review/apply ceremony already
   defined by Bootstrap and Authority.

Never add the graph design as an eleventh C1 row, change a frozen ten-row C1
context after review, or refreeze C1 because these plan amendments exist.
Inventory verifies the pinned graph commit/path/blob/SHA tuple; C1 continues
to select exactly its existing ten rows. Any mismatch is source drift, not
permission to regenerate a context or choose “latest.”

### Exact C0 task insertion and verification

No new file is created for this amendment. This plan consumes the
reconstruction master's graph order but owns only the source-inventory/
provenance handoff; it cannot advance a wave or reorder C1. Insert the
following assertions:

| Existing task | Added assertion |
|---|---|
| Task 3 | Keep the existing generic stable double-read inventory unchanged; it records the spec and six plan paths like every other source path |
| Task 4 | Keep the existing generic hold-by-default map unchanged; C0 adds no graph selector or batch semantics |
| Task 6 | After generic capture, use plan-level read-only assertions to prove the pinned spec plus six amended plan HEAD/index/worktree bytes are committed and clean; prove the actual map leaves every row `hold` and therefore has C1 count zero; `SourceProvenanceV1` binds that source HEAD/tree and inventory/map digests |
| Task 7 | Reopen proves the six amended plan paths and graph spec tuple remain exact, then hands the all-hold state to Bootstrap Task 1A; no C1 context exists yet and C0 cannot freeze or refreeze one |

The existing Task-3 source-drift tests and Task-4 canonical-all-hold tests
remain the mechanism tests; no graph-specific C0 API, CLI flag, fixture, or
import branch is added. Bootstrap Task 1A, not C0, owns the fixed ten-row C1
proposal/context, row-eleven rejection, and no-refreeze tests. Authority Task
2 consumes that one verified C1 record. This keeps C0 all-hold and prevents a
second C1 authority from appearing here.

Run after the six-plan amendment commit and before Bootstrap freezes C1:

```bash
set -euo pipefail
test "$(git rev-parse 9d484befb4a4593d93789457ebddfd7cde358e3b:docs/superpowers/specs/2026-07-24-qinao-dynamic-agent-graph-workflow-design.md)" = e2c59656f9eb184efc3ab933fe442c9dd0b7d507
test "$(git show 9d484befb4a4593d93789457ebddfd7cde358e3b:docs/superpowers/specs/2026-07-24-qinao-dynamic-agent-graph-workflow-design.md | shasum -a 256 | awk '{print $1}')" = 5f36d0b04579f805a3a69254325e62e22625f4ddd31663e03cbf78b1a39460d5
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v \
  scripts.test_capture_qinao_candidate_inventory \
  scripts.test_qinao_import_map \
  scripts.test_qinao_source_provenance_v1
```

Expected: both pin assertions exit 0, all three modules have positive
discovery, and all tests pass. C0 still has zero selected C1 rows. The
subsequent Bootstrap-owned external C1 review remains mandatory and has
exactly ten rows.

## File Responsibility Map

| Path | Responsibility |
|---|---|
| `scripts/check_qinao_owner_ledger.py` | Preserve distinct final-target and parent-component symlink diagnostics in the already-present candidate delta |
| `scripts/qinao_execution_root.py` | Permanent exact-root, branch, two-state lineage, Git-environment, cleanliness API, and canonical assertion CLI |
| `scripts/test_qinao_execution_root.py` | Root confusion, environment override, ancestry, wrong branch, dirty candidate, and source non-mutation tests |
| `scripts/capture_qinao_candidate_inventory.py` | Read-only raw-path inventory, canonical JSON, stable double-read, and source verification CLI |
| `scripts/test_capture_qinao_candidate_inventory.py` | All source strata, deletion, executable, symlink, special-file, non-UTF-8, drift, and non-mutation tests |
| `scripts/build_qinao_import_map.py` | Generate one exact row per inventory path, all rows defaulted to `hold` |
| `scripts/check_qinao_import_map.py` | Strict schema/exact-set/source-stratum/mode/hash/batch/privacy validation |
| `scripts/test_qinao_import_map.py` | Missing/extra/duplicate/implicit-latest/wrong-source/deletion/batch/private-class tests |
| `scripts/apply_qinao_import_map.py` | Prepare destination-CAS plan and apply only reviewed rows through a temporary index and binary patch |
| `scripts/test_apply_qinao_import_map.py` | Dry-run, exact import, deletion, executable, symlink, stale plan, source drift, and intervening-edit tests |
| `scripts/qinao_source_provenance_v1.py` | Build and reopen the durable canonical C0 handoff without self-reference |
| `scripts/test_qinao_source_provenance_v1.py` | Closed shape, parent/tree/diff, digest, dirty-state, and rebuild tests |
| `docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/source-inventory.json` | Canonical stable capture of the preserved source |
| `docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/import-map.json` | Canonical hold-by-default review ledger |
| `docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/source-provenance-v1.json` | One-path committed `SourceProvenanceV1` binding its sole parent candidate tip/tree and C0 pair |

---

### Task 1: Preserve the 22-Commit Tip and Repair the Existing Baseline

**Files:**
- Modify: `scripts/check_qinao_owner_ledger.py` at `validate_schema_v2_raw_document_digest`
- Test: `scripts/test_check_qinao_owner_ledger.py`

**Interfaces:**
- Consumes: exact audited tip `486e1ec5983ad4390c5b07f04607f1345b912c4c` and the one-file uncommitted delta whose binary-patch digest is frozen above.
- Produces: one normal child commit; the audited tip remains its first parent and ancestor.

- [ ] **Step 1: Prove the candidate identity and preserve the delta preimage**

Run from `/Users/changgeng/.codex/worktrees/e4d7/Project06`:

```bash
set -euo pipefail
test "$(pwd -P)" = /Users/changgeng/.codex/worktrees/e4d7/Project06
test "$(git branch --show-current)" = codex/qinao-w1-clean-candidate
test "$(git rev-parse HEAD)" = 486e1ec5983ad4390c5b07f04607f1345b912c4c
candidate_commit_count="$(
  git rev-list --count 59c26f508262d7c25869faac0ec0abf968ec1e02..HEAD
)"
test "$candidate_commit_count" = 22
candidate_status="$(git status --short)"
test "$candidate_status" = " M scripts/check_qinao_owner_ledger.py"
checker_diff_sha256="$(
  git diff --binary -- scripts/check_qinao_owner_ledger.py |
    shasum -a 256 |
    awk '{print $1}'
)"
test "$checker_diff_sha256" = ca122962ca9f198b8a951cd04696b0bdd7c780c8b7c190f922942826ef677f8d
```

Expected: every assertion exits 0. Any mismatch is a stop; do not “repair” it with reset, checkout, or force.

- [ ] **Step 2: Reproduce the one known RED and the green admission suite**

```bash
set -euo pipefail
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v \
  scripts.test_check_qinao_wave_admission
set +e
owner_ledger_diagnostic="$(
  PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v \
    scripts.test_check_qinao_owner_ledger 2>&1
)"
owner_ledger_rc=$?
set -euo pipefail
printf '%s\n' "$owner_ledger_diagnostic"
test "$owner_ledger_rc" -eq 1
test "${owner_ledger_diagnostic#*Ran }" != "$owner_ledger_diagnostic"
test "${owner_ledger_diagnostic#*Ran 0 tests}" = "$owner_ledger_diagnostic"
test "${owner_ledger_diagnostic#*FAILED (failures=1)}" != "$owner_ledger_diagnostic"
test "${owner_ledger_diagnostic#*test_schema_v2_digest_targets_reject_symlink_nonregular_and_unreadable}" != "$owner_ledger_diagnostic"
test "${owner_ledger_diagnostic#*target path must not contain symlink components}" != "$owner_ledger_diagnostic"
```

Expected: wave admission discovers at least 20 tests and passes. Owner Ledger discovers at least 101 tests and fails only the `symlink` subcase of `test_schema_v2_digest_targets_reject_symlink_nonregular_and_unreadable`; the actual diagnostic contains `target path must not contain symlink components`.

- [ ] **Step 3: Put the final-target check before parent-component traversal**

Replace the current loop over all `PurePosixPath(document_path).parts` with this exact block:

```text
    candidate = root / document_path
    if candidate.is_symlink():
        errors.append(f"{label} target must not be a symlink: {document_path}")
        return errors

    path_component = root
    for component in PurePosixPath(document_path).parts[:-1]:
        path_component /= component
        if path_component.is_symlink():
            errors.append(
                f"{label} target path must not contain symlink components: "
                f"{document_path}"
            )
            return errors
```

Keep the existing resolve/containment/regular-file/readability/digest checks after this block. Do not change the test contract: the final link reports `must not be a symlink`; a linked parent reports `target path must not contain symlink components`.

- [ ] **Step 4: Run both focused methods and the full baseline**

```bash
set -euo pipefail
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v \
  scripts.test_check_qinao_owner_ledger.QinaoOwnerLedgerCLITests.test_schema_v2_digest_targets_reject_symlink_nonregular_and_unreadable \
  scripts.test_check_qinao_owner_ledger.QinaoOwnerLedgerCLITests.test_schema_v2_digest_rejects_symlinked_parent_component
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v \
  scripts.test_check_qinao_wave_admission \
  scripts.test_check_qinao_owner_ledger
git diff --check
```

Expected: exactly two focused methods pass; every discovered full-suite test passes; `git diff --check` exits 0.

- [ ] **Step 5: Commit the existing checker slice without rewriting its parent**

```bash
set -euo pipefail
git add scripts/check_qinao_owner_ledger.py
staged_paths="$(git diff --cached --name-only)"
test "$staged_paths" = scripts/check_qinao_owner_ledger.py
git commit -m "fix(qinao): preserve owner ledger symlink diagnostics"
test "$(git rev-parse HEAD^)" = 486e1ec5983ad4390c5b07f04607f1345b912c4c
git merge-base --is-ancestor \
  486e1ec5983ad4390c5b07f04607f1345b912c4c HEAD
worktree_status="$(git status --porcelain=v1)"
test -z "$worktree_status"
```

Expected: one new commit with one path; the 22-commit tip remains the immediate parent and an ancestor.

---

### Task 2: Add the Permanent Execution-Root Guard

**Files:**
- Create: `scripts/qinao_execution_root.py`
- Create: `scripts/test_qinao_execution_root.py`

**Interfaces:**
- Produces:

```text
@dataclass(frozen=True)
class RootContract:
    candidate_root: Path
    candidate_branch: str
    source_root: Path
    source_branch: str
    approved_base_commit: str
    audited_candidate_tip: str
    original_forensic_ref: str
    preparation_forensic_prefix: str
    common_git_dir: Path

class CandidateLineage(Enum):
    PREBOOTSTRAP_PREPARATION = "prebootstrapPreparation"
    REPARENTED_PROGRAM = "reparentedProgram"

def candidate_lineage_for_import_batch(
    destination_batch: str,
) -> CandidateLineage

@dataclass(frozen=True)
class RootIdentity:
    root: Path
    branch: str
    head_commit: str
    head_tree: str
    absolute_git_dir: Path
    common_git_dir: Path
    status_bytes: bytes
    candidate_lineage: CandidateLineage | None

def require_candidate_root(
    root: Path,
    *,
    require_clean: bool,
    expected_lineage: CandidateLineage | None = None,
    require_current_working_directory: bool = True,
    contract: RootContract = DEFAULT_CONTRACT,
) -> RootIdentity

def require_source_root(
    root: Path,
    *,
    contract: RootContract = DEFAULT_CONTRACT,
) -> RootIdentity

def main(argv: Sequence[str] | None = None) -> int
```

- [ ] **Step 1: Create the typed RED seam and write guard tests**

First create `scripts/qinao_execution_root.py` with the exact public seam below. The functions intentionally raise a behavioral RED; the test module must import successfully.

```python
from __future__ import annotations

from dataclasses import dataclass, replace
from enum import Enum
from pathlib import Path


class RootGuardError(RuntimeError):
    pass


@dataclass(frozen=True)
class RootContract:
    candidate_root: Path
    candidate_branch: str
    source_root: Path
    source_branch: str
    approved_base_commit: str
    audited_candidate_tip: str
    original_forensic_ref: str
    preparation_forensic_prefix: str
    common_git_dir: Path


class CandidateLineage(Enum):
    PREBOOTSTRAP_PREPARATION = "prebootstrapPreparation"
    REPARENTED_PROGRAM = "reparentedProgram"


def candidate_lineage_for_import_batch(
    destination_batch: str,
) -> CandidateLineage:
    raise RootGuardError("RED: import batch lineage is not accepted")


@dataclass(frozen=True)
class RootIdentity:
    root: Path
    branch: str
    head_commit: str
    head_tree: str
    absolute_git_dir: Path
    common_git_dir: Path
    status_bytes: bytes
    candidate_lineage: CandidateLineage | None


DEFAULT_CONTRACT = RootContract(
    candidate_root=Path("/Users/changgeng/.codex/worktrees/e4d7/Project06"),
    candidate_branch="codex/qinao-w1-clean-candidate",
    source_root=Path(
        "/Users/changgeng/Project/Project06/Project06/.worktrees/qinao-w0"
    ),
    source_branch="codex/qinao-w1",
    approved_base_commit="59c26f508262d7c25869faac0ec0abf968ec1e02",
    audited_candidate_tip="486e1ec5983ad4390c5b07f04607f1345b912c4c",
    original_forensic_ref=(
        "refs/qinao-forensics/clean-candidate-22-commit-tip-20260723"
    ),
    preparation_forensic_prefix="refs/qinao-forensics/prew0-preparation",
    common_git_dir=Path("/Users/changgeng/Project/Project06/Project06/.git"),
)


def require_candidate_root(
    root: Path,
    *,
    require_clean: bool,
    expected_lineage: CandidateLineage | None = None,
    require_current_working_directory: bool = True,
    contract: RootContract = DEFAULT_CONTRACT,
) -> RootIdentity:
    raise RootGuardError("RED: candidate execution root is not accepted")


def require_source_root(
    root: Path,
    *,
    contract: RootContract = DEFAULT_CONTRACT,
) -> RootIdentity:
    raise RootGuardError("RED: preserved source root is not accepted")
```

Create `scripts/test_qinao_execution_root.py` with a temporary repository fixture that initializes one base commit, creates `source` and `candidate` worktrees, then tests these exact cases:

```python
class QinaoExecutionRootTests(unittest.TestCase):
    def test_candidate_guard_accepts_exact_clean_descendant(self) -> None:
        identity = guard.require_candidate_root(
            self.candidate,
            require_clean=True,
            require_current_working_directory=False,
            contract=self.contract,
        )
        self.assertEqual(identity.branch, "candidate")
        self.assertEqual(identity.status_bytes, b"")
        self.assertEqual(
            identity.candidate_lineage,
            guard.CandidateLineage.PREBOOTSTRAP_PREPARATION,
        )

    def test_candidate_guard_accepts_exact_reparented_program_lineage(self) -> None:
        self.fixture.apply_valid_reparent_transaction()
        self.fixture.commit_single_parent_program_child()
        identity = guard.require_candidate_root(
            self.candidate,
            require_clean=True,
            require_current_working_directory=False,
            contract=self.contract,
        )
        self.assertEqual(
            identity.candidate_lineage,
            guard.CandidateLineage.REPARENTED_PROGRAM,
        )

        for batch in ("C1", "C2"):
            self.assertEqual(
                guard.candidate_lineage_for_import_batch(batch),
                guard.CandidateLineage.PREBOOTSTRAP_PREPARATION,
            )
        for batch in ("C3", "C4"):
            self.assertEqual(
                guard.candidate_lineage_for_import_batch(batch),
                guard.CandidateLineage.REPARENTED_PROGRAM,
            )
        with self.assertRaisesRegex(
            guard.RootGuardError,
            "unknown import destination batch",
        ):
            guard.candidate_lineage_for_import_batch("C5")

    def test_candidate_guard_rejects_partial_or_forged_forensic_state(self) -> None:
        self.fixture.apply_valid_reparent_transaction()
        self.git(
            self.candidate,
            "update-ref",
            "-d",
            self.contract.original_forensic_ref,
        )
        with self.assertRaisesRegex(
            guard.RootGuardError, "reparented forensic lineage is incomplete"
        ):
            guard.require_candidate_root(
                self.candidate,
                require_clean=True,
                require_current_working_directory=False,
                contract=self.contract,
            )

    def test_candidate_guard_rejects_symbolic_original_forensic_ref(self) -> None:
        self.fixture.apply_valid_reparent_transaction()
        symbolic_target = "refs/qinao-test/original-tip-anchor"
        self.git(
            self.candidate,
            "update-ref",
            "-d",
            self.contract.original_forensic_ref,
        )
        self.git(
            self.candidate,
            "update-ref",
            symbolic_target,
            self.contract.audited_candidate_tip,
        )
        self.git(
            self.candidate,
            "symbolic-ref",
            self.contract.original_forensic_ref,
            symbolic_target,
        )
        with self.assertRaisesRegex(
            guard.RootGuardError,
            "symbolic forensic ref is forbidden",
        ):
            guard.require_candidate_root(
                self.candidate,
                require_clean=True,
                require_current_working_directory=False,
                contract=self.contract,
            )

    def test_candidate_guard_rejects_symbolic_preparation_forensic_ref(self) -> None:
        self.fixture.apply_valid_reparent_transaction()
        preparation_ref = self.fixture.preparation_forensic_ref
        preparation_tip = self.fixture.preparation_tip
        symbolic_target = "refs/qinao-test/preparation-tip-anchor"
        self.git(self.candidate, "update-ref", "-d", preparation_ref)
        self.git(
            self.candidate,
            "update-ref",
            symbolic_target,
            preparation_tip,
        )
        self.git(
            self.candidate,
            "symbolic-ref",
            preparation_ref,
            symbolic_target,
        )
        with self.assertRaisesRegex(
            guard.RootGuardError,
            "symbolic forensic ref is forbidden",
        ):
            guard.require_candidate_root(
                self.candidate,
                require_clean=True,
                require_current_working_directory=False,
                contract=self.contract,
            )

    def test_cli_requires_declared_lineage_and_emits_canonical_json(self) -> None:
        completed = self.run_guard_cli(
            "--root",
            str(self.candidate),
            "--expect-candidate-lineage",
            "prebootstrapPreparation",
            "--require-clean",
        )
        self.assertEqual(completed.returncode, 0, completed.stderr)
        parsed = json.loads(completed.stdout)
        self.assertEqual(
            parsed,
            {
                "candidate_lineage": "prebootstrapPreparation",
                "head_commit": self.candidate_head(),
                "head_tree": self.candidate_tree(),
                "schema_version": 1,
            },
        )
        self.assertEqual(
            completed.stdout,
            json.dumps(parsed, sort_keys=True, separators=(",", ":")) + "\n",
        )

    def test_cli_rejects_wrong_declared_lineage(self) -> None:
        completed = self.run_guard_cli(
            "--root",
            str(self.candidate),
            "--expect-candidate-lineage",
            "reparentedProgram",
            "--require-clean",
        )
        self.assertEqual(completed.returncode, 2)
        self.assertIn(
            "expected candidate lineage reparentedProgram",
            completed.stderr,
        )

    def test_candidate_guard_rejects_source_root(self) -> None:
        with self.assertRaisesRegex(guard.RootGuardError, "candidate root mismatch"):
            guard.require_candidate_root(
                self.source,
                require_clean=False,
                require_current_working_directory=False,
                contract=self.contract,
            )

    def test_candidate_guard_rejects_wrong_branch_and_missing_tip_ancestry(self) -> None:
        self.git(self.candidate, "switch", "-c", "wrong")
        with self.assertRaisesRegex(guard.RootGuardError, "candidate branch mismatch"):
            guard.require_candidate_root(
                self.candidate,
                require_clean=False,
                require_current_working_directory=False,
                contract=self.contract,
            )

    def test_candidate_guard_rejects_dirty_tree(self) -> None:
        (self.candidate / "tracked.txt").write_text("changed\n", encoding="utf-8")
        with self.assertRaisesRegex(guard.RootGuardError, "candidate is not clean"):
            guard.require_candidate_root(
                self.candidate,
                require_clean=True,
                require_current_working_directory=False,
                contract=self.contract,
            )

    def test_git_environment_overrides_are_ignored(self) -> None:
        with mock.patch.dict(
            os.environ,
            {
                "GIT_DIR": "/does/not/exist",
                "GIT_WORK_TREE": "/does/not/exist",
                "GIT_INDEX_FILE": "/does/not/exist",
                "GIT_OBJECT_DIRECTORY": "/does/not/exist",
            },
        ):
            identity = guard.require_source_root(
                self.source,
                contract=self.contract,
            )
        self.assertEqual(identity.branch, "source")

    def test_source_guard_does_not_change_head_index_status_or_files(self) -> None:
        before = self.source_probe()
        guard.require_source_root(self.source, contract=self.contract)
        after = self.source_probe()
        self.assertEqual(after, before)
```

The fixture methods are complete when they:

1. set `init.defaultBranch=main`, `user.name=Qinao Test`, and `user.email=qinao@example.invalid`;
2. create and commit `tracked.txt`;
3. create branches `source` and `candidate`;
4. add both as detached filesystem worktrees under the temporary directory;
5. commit one candidate child so `audited_candidate_tip` is real; and
6. construct `RootContract` from those exact temporary paths and OIDs;
7. implement `apply_valid_reparent_transaction()` by preserving the audited tip under the fixed original ref, preserving the final preparation tip under a ref whose final component is that full OID, creating a one-parent `B0` above the base, and creating a tree-identical one-parent `Pw` above `B0`; and
8. expose exact `preparation_forensic_ref` and `preparation_tip` fixture
   properties, implement `commit_single_parent_program_child`,
   `run_guard_cli`, `candidate_head`, and `candidate_tree`, import `json`, and
   add negative cases for symbolic original/preparation forensic refs, a mixed
   old-ancestry-plus-forensic state, wrong original-ref OID, zero/two
   preparation refs, suffix/OID mismatch, preparation tip not descended from
   the audited tip, no tree-identical `Pw` boundary, merge parents, and a
   boundary whose `B0` parent is not the approved base.

- [ ] **Step 2: Run the guard suite to verify RED**

```bash
set -euo pipefail
set +e
red_diagnostic="$(
  PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v \
    scripts.test_qinao_execution_root 2>&1
)"
red_rc=$?
set -euo pipefail
printf '%s\n' "$red_diagnostic"
test "$red_rc" -eq 1
test "${red_diagnostic#*Ran }" != "$red_diagnostic"
test "${red_diagnostic#*Ran 0 tests}" = "$red_diagnostic"
test "${red_diagnostic#*FAILED}" != "$red_diagnostic"
test "${red_diagnostic#*RED: candidate execution root is not accepted}" != "$red_diagnostic"
```

Expected: the module imports, all methods are discovered, and acceptance cases fail with one of the two exact typed RED messages defined above. A syntax error, import error, or zero discovery is not the required RED.

- [ ] **Step 3: Implement the root contract and sanitized Git runner**

Create `scripts/qinao_execution_root.py` with these exact constants and helpers:

```python
from __future__ import annotations

import argparse
from collections.abc import Sequence
from dataclasses import dataclass, replace
from enum import Enum
import json
import os
from pathlib import Path
import subprocess
import sys


class RootGuardError(RuntimeError):
    pass


@dataclass(frozen=True)
class RootContract:
    candidate_root: Path
    candidate_branch: str
    source_root: Path
    source_branch: str
    approved_base_commit: str
    audited_candidate_tip: str
    original_forensic_ref: str
    preparation_forensic_prefix: str
    common_git_dir: Path


class CandidateLineage(Enum):
    PREBOOTSTRAP_PREPARATION = "prebootstrapPreparation"
    REPARENTED_PROGRAM = "reparentedProgram"


def candidate_lineage_for_import_batch(
    destination_batch: str,
) -> CandidateLineage:
    if destination_batch in {"C1", "C2"}:
        return CandidateLineage.PREBOOTSTRAP_PREPARATION
    if destination_batch in {"C3", "C4"}:
        return CandidateLineage.REPARENTED_PROGRAM
    raise RootGuardError(
        f"unknown import destination batch: {destination_batch!r}"
    )


@dataclass(frozen=True)
class RootIdentity:
    root: Path
    branch: str
    head_commit: str
    head_tree: str
    absolute_git_dir: Path
    common_git_dir: Path
    status_bytes: bytes
    candidate_lineage: CandidateLineage | None


DEFAULT_CONTRACT = RootContract(
    candidate_root=Path("/Users/changgeng/.codex/worktrees/e4d7/Project06"),
    candidate_branch="codex/qinao-w1-clean-candidate",
    source_root=Path(
        "/Users/changgeng/Project/Project06/Project06/.worktrees/qinao-w0"
    ),
    source_branch="codex/qinao-w1",
    approved_base_commit="59c26f508262d7c25869faac0ec0abf968ec1e02",
    audited_candidate_tip="486e1ec5983ad4390c5b07f04607f1345b912c4c",
    original_forensic_ref=(
        "refs/qinao-forensics/clean-candidate-22-commit-tip-20260723"
    ),
    preparation_forensic_prefix="refs/qinao-forensics/prew0-preparation",
    common_git_dir=Path("/Users/changgeng/Project/Project06/Project06/.git"),
)


_GIT_ENVIRONMENT_KEYS = {
    "GIT_DIR",
    "GIT_WORK_TREE",
    "GIT_INDEX_FILE",
    "GIT_OBJECT_DIRECTORY",
    "GIT_ALTERNATE_OBJECT_DIRECTORIES",
    "GIT_COMMON_DIR",
    "GIT_NAMESPACE",
    "GIT_CEILING_DIRECTORIES",
}


def clean_git_environment() -> dict[str, str]:
    environment = {
        key: value
        for key, value in os.environ.items()
        if key not in _GIT_ENVIRONMENT_KEYS
        and not key.startswith("GIT_CONFIG_")
    }
    environment["GIT_NO_REPLACE_OBJECTS"] = "1"
    environment["GIT_OPTIONAL_LOCKS"] = "0"
    environment["GIT_CONFIG_NOSYSTEM"] = "1"
    environment["GIT_ATTR_NOSYSTEM"] = "1"
    environment["LC_ALL"] = "C"
    return environment


def run_git(
    root: Path,
    *arguments: str,
    check: bool = True,
    input_bytes: bytes | None = None,
    environment: dict[str, str] | None = None,
) -> subprocess.CompletedProcess[bytes]:
    command_environment = clean_git_environment()
    if environment is not None:
        command_environment.update(environment)
    completed = subprocess.run(
        ["git", "-C", str(root), *arguments],
        input=input_bytes,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
        env=command_environment,
    )
    if check and completed.returncode != 0:
        diagnostic = completed.stderr.decode("utf-8", "backslashreplace").strip()
        raise RootGuardError(
            f"git {' '.join(arguments)} failed with "
            f"{completed.returncode}: {diagnostic}"
        )
    return completed


def _one_line(root: Path, *arguments: str) -> str:
    raw = run_git(root, *arguments).stdout
    try:
        value = raw.decode("ascii").strip()
    except UnicodeDecodeError as error:
        raise RootGuardError(f"non-ASCII Git identity: {arguments!r}") from error
    if not value or "\n" in value:
        raise RootGuardError(f"invalid Git identity: {arguments!r}")
    return value


def _absolute_git_path(root: Path, *arguments: str) -> Path:
    value = Path(_one_line(root, *arguments))
    if not value.is_absolute():
        value = root / value
    return value.resolve(strict=True)


def _is_ancestor(root: Path, ancestor: str, descendant: str) -> bool:
    completed = run_git(
        root,
        "merge-base",
        "--is-ancestor",
        ancestor,
        descendant,
        check=False,
    )
    if completed.returncode not in {0, 1}:
        diagnostic = completed.stderr.decode("utf-8", "backslashreplace").strip()
        raise RootGuardError(f"ancestry check failed: {diagnostic}")
    return completed.returncode == 0


def _require_full_oid(raw: bytes, *, label: str, length: int) -> str:
    try:
        value = raw.decode("ascii").strip()
    except UnicodeDecodeError as error:
        raise RootGuardError(f"{label} is not ASCII") from error
    if (
        len(value) != length
        or value.lower() != value
        or any(character not in "0123456789abcdef" for character in value)
    ):
        raise RootGuardError(f"{label} is not one lowercase full OID")
    return value


def _optional_ref_oid(
    root: Path,
    ref_name: str,
    *,
    oid_length: int,
) -> str | None:
    raw = run_git(
        root,
        "for-each-ref",
        "--format=%(refname)%00%(objectname)%00%(symref)",
        ref_name,
    ).stdout
    records = raw.splitlines()
    if not records:
        return None
    if len(records) != 1:
        raise RootGuardError(f"invalid forensic ref enumeration: {ref_name}")
    fields = records[0].split(b"\x00")
    if len(fields) != 3:
        raise RootGuardError(f"invalid forensic ref record: {ref_name}")
    raw_name, raw_oid, raw_symref = fields
    try:
        actual_name = raw_name.decode("ascii")
        symref = raw_symref.decode("ascii")
    except UnicodeDecodeError as error:
        raise RootGuardError(f"non-ASCII forensic ref: {ref_name}") from error
    if actual_name != ref_name:
        raise RootGuardError(
            f"forensic ref lookup escaped exact name: {ref_name}"
        )
    if symref:
        raise RootGuardError(
            f"symbolic forensic ref is forbidden: {ref_name}"
        )
    return _require_full_oid(
        raw_oid,
        label=ref_name,
        length=oid_length,
    )


def _refs_below(
    root: Path,
    prefix: str,
    *,
    oid_length: int,
) -> tuple[tuple[str, str], ...]:
    canonical_prefix = prefix.rstrip("/") + "/"
    raw = run_git(
        root,
        "for-each-ref",
        "--format=%(refname)%00%(objectname)%00%(symref)",
        canonical_prefix,
    ).stdout
    rows: list[tuple[str, str]] = []
    for raw_line in raw.splitlines():
        fields = raw_line.split(b"\x00")
        if len(fields) != 3:
            raise RootGuardError("invalid forensic ref enumeration")
        raw_name, raw_oid, raw_symref = fields
        try:
            ref_name = raw_name.decode("ascii")
            symref = raw_symref.decode("ascii")
        except UnicodeDecodeError as error:
            raise RootGuardError("invalid forensic ref enumeration") from error
        if not ref_name.startswith(canonical_prefix):
            raise RootGuardError("forensic ref escaped its prefix")
        if symref:
            raise RootGuardError(
                f"symbolic forensic ref is forbidden: {ref_name}"
            )
        oid = _require_full_oid(
            raw_oid,
            label=ref_name,
            length=oid_length,
        )
        rows.append((ref_name, oid))
    return tuple(rows)


def _commit_parents(root: Path, commit_oid: str) -> tuple[str, ...]:
    fields = _one_line(
        root, "rev-list", "--parents", "--max-count=1", commit_oid
    ).split()
    if fields[0] != commit_oid:
        raise RootGuardError("Git returned a different commit identity")
    return tuple(fields[1:])


def _commit_tree(root: Path, commit_oid: str) -> str:
    return _one_line(root, "rev-parse", "--verify", f"{commit_oid}^{{tree}}")


def _ascii_lines(root: Path, *arguments: str) -> tuple[str, ...]:
    raw = run_git(root, *arguments).stdout
    try:
        lines = raw.decode("ascii").splitlines()
    except UnicodeDecodeError as error:
        raise RootGuardError(
            f"non-ASCII Git line set: {arguments!r}"
        ) from error
    if not lines or any(not line for line in lines):
        raise RootGuardError(f"invalid Git line set: {arguments!r}")
    return tuple(lines)


def _classify_candidate_lineage(
    identity: RootIdentity,
    contract: RootContract,
) -> CandidateLineage:
    oid_length = len(contract.approved_base_commit)
    original_ref_oid = _optional_ref_oid(
        identity.root,
        contract.original_forensic_ref,
        oid_length=oid_length,
    )
    preparation_refs = _refs_below(
        identity.root,
        contract.preparation_forensic_prefix,
        oid_length=oid_length,
    )
    audited_is_ancestor = _is_ancestor(
        identity.root,
        contract.audited_candidate_tip,
        identity.head_commit,
    )

    if audited_is_ancestor:
        if original_ref_oid is not None or preparation_refs:
            raise RootGuardError(
                "mixed prebootstrap ancestry and forensic lineage"
            )
        return CandidateLineage.PREBOOTSTRAP_PREPARATION

    if (
        original_ref_oid != contract.audited_candidate_tip
        or len(preparation_refs) != 1
    ):
        raise RootGuardError("reparented forensic lineage is incomplete")

    preparation_ref, preparation_tip = preparation_refs[0]
    expected_ref = (
        contract.preparation_forensic_prefix.rstrip("/")
        + "/"
        + preparation_tip
    )
    if preparation_ref != expected_ref:
        raise RootGuardError("preparation forensic ref suffix/OID mismatch")
    if not _is_ancestor(
        identity.root,
        contract.audited_candidate_tip,
        preparation_tip,
    ):
        raise RootGuardError(
            "preparation forensic tip does not descend from audited tip"
        )

    preparation_tree = _commit_tree(identity.root, preparation_tip)
    first_parent_chain = _ascii_lines(
        identity.root,
        "rev-list",
        "--first-parent",
        identity.head_commit,
    )
    boundary_candidates: list[str] = []
    for commit_oid in first_parent_chain:
        if commit_oid == contract.approved_base_commit:
            break
        parents = _commit_parents(identity.root, commit_oid)
        if len(parents) != 1:
            raise RootGuardError("merge parent in reparented program lineage")
        b0_oid = parents[0]
        if (
            _commit_parents(identity.root, b0_oid)
            == (contract.approved_base_commit,)
            and _commit_tree(identity.root, commit_oid) == preparation_tree
        ):
            boundary_candidates.append(commit_oid)
    if len(boundary_candidates) != 1:
        raise RootGuardError(
            "tree-identical B0-to-Pw reparent boundary is missing"
        )
    return CandidateLineage.REPARENTED_PROGRAM


def _inspect(root: Path) -> RootIdentity:
    resolved = root.resolve(strict=True)
    top_level = Path(_one_line(resolved, "rev-parse", "--show-toplevel")).resolve(
        strict=True
    )
    if top_level != resolved:
        raise RootGuardError(
            f"root is not the Git top level: root={resolved} top={top_level}"
        )
    branch = _one_line(resolved, "symbolic-ref", "--quiet", "--short", "HEAD")
    head_commit = _one_line(resolved, "rev-parse", "--verify", "HEAD^{commit}")
    head_tree = _one_line(resolved, "rev-parse", "--verify", "HEAD^{tree}")
    absolute_git_dir = _absolute_git_path(
        resolved, "rev-parse", "--absolute-git-dir"
    )
    common_git_dir = _absolute_git_path(resolved, "rev-parse", "--git-common-dir")
    status_bytes = run_git(
        resolved,
        "status",
        "--porcelain=v2",
        "-z",
        "--untracked-files=all",
    ).stdout
    replace_refs = run_git(
        resolved,
        "for-each-ref",
        "--format=%(refname)",
        "refs/replace/",
    ).stdout
    if replace_refs:
        raise RootGuardError("replace refs are forbidden")
    if (common_git_dir / "info" / "grafts").exists():
        raise RootGuardError("Git grafts are forbidden")
    if run_git(resolved, "rev-parse", "--is-shallow-repository").stdout.strip() != b"false":
        raise RootGuardError("shallow ancestry is forbidden")
    return RootIdentity(
        root=resolved,
        branch=branch,
        head_commit=head_commit,
        head_tree=head_tree,
        absolute_git_dir=absolute_git_dir,
        common_git_dir=common_git_dir,
        status_bytes=status_bytes,
        candidate_lineage=None,
    )


def require_candidate_root(
    root: Path,
    *,
    require_clean: bool,
    expected_lineage: CandidateLineage | None = None,
    require_current_working_directory: bool = True,
    contract: RootContract = DEFAULT_CONTRACT,
) -> RootIdentity:
    identity = _inspect(root)
    expected_root = contract.candidate_root.resolve(strict=True)
    if identity.root != expected_root:
        raise RootGuardError(
            f"candidate root mismatch: expected={expected_root} actual={identity.root}"
        )
    if require_current_working_directory and Path.cwd().resolve(strict=True) != expected_root:
        raise RootGuardError("current working directory is not the candidate root")
    if identity.branch != contract.candidate_branch:
        raise RootGuardError(
            f"candidate branch mismatch: expected={contract.candidate_branch} "
            f"actual={identity.branch}"
        )
    if identity.common_git_dir != contract.common_git_dir.resolve(strict=True):
        raise RootGuardError("candidate common Git directory mismatch")
    if not _is_ancestor(
        identity.root, contract.approved_base_commit, identity.head_commit
    ):
        raise RootGuardError("approved base is not an ancestor of candidate HEAD")
    lineage = _classify_candidate_lineage(identity, contract)
    if expected_lineage is not None and lineage is not expected_lineage:
        raise RootGuardError(
            f"expected candidate lineage {expected_lineage.value}; "
            f"actual={lineage.value}"
        )
    if require_clean and identity.status_bytes:
        raise RootGuardError("candidate is not clean")
    return replace(identity, candidate_lineage=lineage)


def require_source_root(
    root: Path,
    *,
    contract: RootContract = DEFAULT_CONTRACT,
) -> RootIdentity:
    identity = _inspect(root)
    expected_root = contract.source_root.resolve(strict=True)
    if identity.root != expected_root:
        raise RootGuardError(
            f"source root mismatch: expected={expected_root} actual={identity.root}"
        )
    if identity.root == contract.candidate_root.resolve(strict=True):
        raise RootGuardError("source root aliases the candidate root")
    if identity.branch != contract.source_branch:
        raise RootGuardError(
            f"source branch mismatch: expected={contract.source_branch} "
            f"actual={identity.branch}"
        )
    if identity.common_git_dir != contract.common_git_dir.resolve(strict=True):
        raise RootGuardError("source common Git directory mismatch")
    if not _is_ancestor(
        identity.root, contract.approved_base_commit, identity.head_commit
    ):
        raise RootGuardError("approved base is not an ancestor of source HEAD")
    return identity


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(allow_abbrev=False)
    parser.add_argument("--root", required=True)
    parser.add_argument(
        "--expect-candidate-lineage",
        required=True,
        choices=tuple(lineage.value for lineage in CandidateLineage),
    )
    parser.add_argument("--require-clean", action="store_true")
    arguments = parser.parse_args(argv)
    try:
        expected = CandidateLineage(arguments.expect_candidate_lineage)
        identity = require_candidate_root(
            Path(arguments.root),
            require_clean=arguments.require_clean,
            expected_lineage=expected,
        )
    except RootGuardError as error:
        print(f"qinao-execution-root: {error}", file=sys.stderr)
        return 2
    output = {
        "candidate_lineage": expected.value,
        "head_commit": identity.head_commit,
        "head_tree": identity.head_tree,
        "schema_version": 1,
    }
    print(json.dumps(output, sort_keys=True, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
```

- [ ] **Step 4: Run and commit the guard**

```bash
set -euo pipefail
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v \
  scripts.test_qinao_execution_root
PYTHONDONTWRITEBYTECODE=1 python3 scripts/qinao_execution_root.py \
  --root /Users/changgeng/.codex/worktrees/e4d7/Project06 \
  --expect-candidate-lineage prebootstrapPreparation \
  --require-clean
git diff --check
git add scripts/qinao_execution_root.py \
  scripts/test_qinao_execution_root.py
staged_paths="$(git diff --cached --name-only)"
expected_staged_paths="$(printf '%s\n' \
  scripts/qinao_execution_root.py \
  scripts/test_qinao_execution_root.py)"
test "$staged_paths" = "$expected_staged_paths"
git commit -m "build(qinao): guard clean candidate execution root"
worktree_status="$(git status --porcelain=v1)"
test -z "$worktree_status"
```

Expected: positive discovery, all tests pass, the CLI emits one canonical JSON line with exact keys `candidate_lineage,head_commit,head_tree,schema_version` and `candidate_lineage == "prebootstrapPreparation"`, and the commit contains exactly the two files. A lineage mismatch exits 2 with prefix `qinao-execution-root:`.

---

### Task 3: Capture a Stable, Read-Only Source Inventory

**Files:**
- Create: `scripts/capture_qinao_candidate_inventory.py`
- Create: `scripts/test_capture_qinao_candidate_inventory.py`

**Interfaces:**
- Consumes: the permanent root guard and preserved source root.
- Produces:

```text
def canonical_json_bytes(value: object) -> bytes

def capture_inventory(
    *,
    root: Path,
    approved_base_commit: str,
    capture_tool_commit: str,
    captured_at: str,
) -> dict[str, object]

def verify_inventory(*, root: Path, inventory: dict[str, object]) -> None
```

The top-level field set is exactly:

```text
schema_version
approved_base_commit
source_head_commit
source_head_tree
source_branch
source_index_tree
source_index_bytes_sha256
source_status_sha256
staged_patch_sha256
unstaged_patch_sha256
capture_tool_commit
captured_at
paths
```

Every sorted `paths[]` row is exactly:

```text
path_b64
display_path
base
head
index
worktree
untracked
status_xy
```

Git strata use exactly `{present, mode, git_oid, sha256}` except `index`, which adds `stage`. Filesystem strata use exactly `{present, kind, mode, size, sha256}`. Every field after `present` is `null` when absent.

- [ ] **Step 1: Create the typed RED seam and write inventory tests**

Create `scripts/capture_qinao_candidate_inventory.py` first:

```python
from __future__ import annotations

import json
from pathlib import Path


class SourceInventoryError(RuntimeError):
    pass


def canonical_json_bytes(value: object) -> bytes:
    return (
        json.dumps(
            value,
            ensure_ascii=True,
            sort_keys=True,
            separators=(",", ":"),
        ).encode("utf-8")
        + b"\n"
    )


def capture_inventory(
    *,
    root: Path,
    approved_base_commit: str,
    capture_tool_commit: str,
    captured_at: str,
) -> dict[str, object]:
    raise SourceInventoryError("RED: source inventory capture is unavailable")


def verify_inventory(*, root: Path, inventory: dict[str, object]) -> None:
    raise SourceInventoryError("RED: source inventory verification is unavailable")
```

Use `copy`, `unittest`, `tempfile`, `subprocess`, `os`, `stat`, and
`unittest.mock`. The test module must contain these methods with exact
assertions:

```python
import copy


class CaptureQinaoCandidateInventoryTests(unittest.TestCase):
    def test_capture_records_base_head_index_worktree_and_untracked_strata(self) -> None:
        inventory = self.capture()
        rows = {self.raw_path(row): row for row in inventory["paths"]}
        self.assertTrue(rows[b"committed.txt"]["base"]["present"])
        self.assertTrue(rows[b"committed.txt"]["head"]["present"])
        self.assertTrue(rows[b"staged.txt"]["index"]["present"])
        self.assertTrue(rows[b"staged.txt"]["worktree"]["present"])
        self.assertTrue(rows[b"mixed.txt"]["index"]["present"])
        self.assertNotEqual(
            rows[b"mixed.txt"]["index"]["sha256"],
            rows[b"mixed.txt"]["worktree"]["sha256"],
        )
        self.assertTrue(rows[b"untracked.txt"]["untracked"]["present"])

    def test_capture_preserves_empty_untracked_file_and_executable_mode(self) -> None:
        inventory = self.capture()
        rows = {self.raw_path(row): row for row in inventory["paths"]}
        self.assertEqual(rows[b"empty.bin"]["untracked"]["size"], 0)
        self.assertEqual(rows[b"empty.bin"]["untracked"]["sha256"], hashlib.sha256(b"").hexdigest())
        self.assertEqual(rows[b"executable.sh"]["worktree"]["mode"], "100755")

    def test_capture_uses_base64_for_non_utf8_git_paths(self) -> None:
        raw_path = b"non-utf8-\xff.bin"
        self.write_raw(raw_path, b"value")
        inventory = self.capture()
        row = next(row for row in inventory["paths"] if self.raw_path(row) == raw_path)
        self.assertEqual(base64.b64decode(row["path_b64"], validate=True), raw_path)
        self.assertIn("\\xff", row["display_path"])

    def test_capture_records_deletion_without_fabricating_empty_blob(self) -> None:
        inventory = self.capture()
        row = next(row for row in inventory["paths"] if self.raw_path(row) == b"deleted.txt")
        self.assertTrue(row["head"]["present"])
        self.assertFalse(row["index"]["present"])
        self.assertIsNone(row["index"]["sha256"])
        self.assertFalse(row["worktree"]["present"])

    def test_capture_records_safe_symlink_without_following_it(self) -> None:
        inventory = self.capture()
        row = next(row for row in inventory["paths"] if self.raw_path(row) == b"safe-link")
        self.assertEqual(row["untracked"]["kind"], "symlink")
        self.assertEqual(row["untracked"]["mode"], "120000")
        self.assertEqual(
            row["untracked"]["sha256"],
            hashlib.sha256(b"committed.txt").hexdigest(),
        )

    def test_capture_rejects_symlink_escape_and_special_file(self) -> None:
        (self.source / "escape").symlink_to("../outside")
        with self.assertRaisesRegex(inventory.SourceInventoryError, "escaping symlink"):
            self.capture()
        (self.source / "escape").unlink()
        os.mkfifo(self.source / "fifo")
        with self.assertRaisesRegex(inventory.SourceInventoryError, "special file"):
            self.capture()

    def test_capture_retries_once_then_fails_on_source_drift(self) -> None:
        stable = {"schema_version": 1, "paths": []}
        changed = {"schema_version": 1, "paths": [{"path_b64": "eA=="}]}
        with mock.patch.object(
            inventory,
            "_capture_once",
            side_effect=[stable, changed, stable, changed],
        ):
            with self.assertRaisesRegex(inventory.SourceInventoryError, "source_drift"):
                inventory.capture_inventory(
                    root=self.source,
                    approved_base_commit=self.base,
                    capture_tool_commit=self.candidate_head,
                    captured_at="2026-07-23T00:00:00Z",
                )

    def test_verify_rejects_boolean_or_float_schema_version(self) -> None:
        captured = self.capture()
        for invalid in (True, 1.0):
            with self.subTest(invalid=invalid):
                mutated = copy.deepcopy(captured)
                mutated["schema_version"] = invalid
                with self.assertRaisesRegex(
                    inventory.SourceInventoryError,
                    "top-level schema",
                ):
                    inventory.verify_inventory(root=self.source, inventory=mutated)

    def test_capture_does_not_change_head_index_status_or_worktree_bytes(self) -> None:
        before = self.source_probe()
        self.capture()
        after = self.source_probe()
        self.assertEqual(after, before)
```

The fixture creates: one base-only file, one HEAD commit, one staged add, one mixed staged/unstaged file, one index deletion, one empty untracked file, one executable, and one safe relative symlink. `source_probe()` returns the HEAD OID, raw index bytes, porcelain-v2 bytes, and SHA-256/mode tuples for every tracked and untracked path.

- [ ] **Step 2: Run RED**

```bash
set -euo pipefail
set +e
red_diagnostic="$(
  PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v \
    scripts.test_capture_qinao_candidate_inventory 2>&1
)"
red_rc=$?
set -euo pipefail
printf '%s\n' "$red_diagnostic"
test "$red_rc" -eq 1
test "${red_diagnostic#*Ran }" != "$red_diagnostic"
test "${red_diagnostic#*Ran 0 tests}" = "$red_diagnostic"
test "${red_diagnostic#*FAILED}" != "$red_diagnostic"
test "${red_diagnostic#*RED: source inventory capture is unavailable}" != "$red_diagnostic"
```

Expected: the module imports, every method is discovered, and capture cases fail with the typed `SourceInventoryError` RED. Syntax/import errors do not count as RED.

- [ ] **Step 3: Implement raw-path and no-follow filesystem primitives**

Create `scripts/capture_qinao_candidate_inventory.py` and add these exact primitives:

```python
from __future__ import annotations

import argparse
import base64
from contextlib import contextmanager
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import posixpath
import shutil
import stat
import tempfile
from typing import Callable, Iterator

from scripts.qinao_execution_root import (
    CandidateLineage,
    DEFAULT_CONTRACT,
    candidate_lineage_for_import_batch,
    require_candidate_root,
    require_source_root,
    run_git,
)


class SourceInventoryError(RuntimeError):
    pass


def canonical_json_bytes(value: object) -> bytes:
    return (
        json.dumps(
            value,
            ensure_ascii=True,
            sort_keys=True,
            separators=(",", ":"),
        ).encode("utf-8")
        + b"\n"
    )


def _sha256(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def _path_b64(path: bytes) -> str:
    return base64.b64encode(path).decode("ascii")


def _decode_path_b64(value: str) -> bytes:
    try:
        decoded = base64.b64decode(value, validate=True)
    except (ValueError, TypeError) as error:
        raise SourceInventoryError("path_b64 is not canonical Base64") from error
    if base64.b64encode(decoded).decode("ascii") != value:
        raise SourceInventoryError("path_b64 is not canonical Base64")
    _validate_raw_path(decoded)
    return decoded


def _display_path(path: bytes) -> str:
    return path.decode("utf-8", "backslashreplace")


def _validate_raw_path(path: bytes) -> None:
    if not path or b"\x00" in path or path.startswith(b"/"):
        raise SourceInventoryError("Git path must be non-empty, relative, and NUL-free")
    components = path.split(b"/")
    if any(component in {b"", b".", b".."} for component in components):
        raise SourceInventoryError("Git path contains a forbidden component")


@contextmanager
def open_parent_dirfd_no_follow(
    root: Path,
    path: bytes,
) -> Iterator[tuple[int, bytes]]:
    _validate_raw_path(path)
    components = path.split(b"/")
    flags = (
        os.O_RDONLY
        | getattr(os, "O_DIRECTORY", 0)
        | getattr(os, "O_NOFOLLOW", 0)
    )
    descriptor = os.open(os.fsencode(str(root)), flags)
    try:
        for component in components[:-1]:
            next_descriptor = os.open(
                component,
                flags,
                dir_fd=descriptor,
            )
            os.close(descriptor)
            descriptor = next_descriptor
        yield descriptor, components[-1]
    finally:
        os.close(descriptor)


_FIXED_CANDIDATE_JSON_PATHS = {
    b"docs/superpowers/evidence/qinao-clean-candidate/"
    b"2026-07-23-c0/source-inventory.json",
    b"docs/superpowers/evidence/qinao-clean-candidate/"
    b"2026-07-23-c0/import-map.json",
    b"docs/superpowers/evidence/qinao-clean-candidate/"
    b"2026-07-23-c0/source-provenance-v1.json",
}
MAX_GOVERNED_JSON_BYTES = 64 * 1024 * 1024


def _fixed_candidate_path_bytes(relative_path: Path) -> bytes:
    raw = os.fsencode(str(relative_path))
    _validate_raw_path(raw)
    if raw not in _FIXED_CANDIDATE_JSON_PATHS:
        raise SourceInventoryError("candidate JSON path is not a fixed output")
    return raw


@contextmanager
def _open_fixed_parent_for_install(
    candidate_root: Path,
    relative_path: Path,
) -> Iterator[tuple[int, bytes]]:
    raw = _fixed_candidate_path_bytes(relative_path)
    components = raw.split(b"/")
    flags = (
        os.O_RDONLY
        | getattr(os, "O_DIRECTORY", 0)
        | getattr(os, "O_NOFOLLOW", 0)
    )
    descriptor = os.open(os.fsencode(str(candidate_root)), flags)
    try:
        for component in components[:-1]:
            created = False
            try:
                next_descriptor = os.open(
                    component,
                    flags,
                    dir_fd=descriptor,
                )
            except FileNotFoundError:
                os.mkdir(component, 0o755, dir_fd=descriptor)
                created = True
                created_named = os.stat(
                    component,
                    dir_fd=descriptor,
                    follow_symlinks=False,
                )
            except PermissionError:
                created_named = os.stat(
                    component,
                    dir_fd=descriptor,
                    follow_symlinks=False,
                )
                if (
                    not stat.S_ISDIR(created_named.st_mode)
                    or created_named.st_uid != os.geteuid()
                    or stat.S_IMODE(created_named.st_mode) != 0
                ):
                    raise
                # Recover only the exact mode-000 residue that umask 0777 can
                # leave if a prior process dies immediately after mkdir.
                created = True
            if created:
                if (
                    not stat.S_ISDIR(created_named.st_mode)
                    or created_named.st_uid != os.geteuid()
                ):
                    raise SourceInventoryError(
                        "new fixed output parent identity/owner mismatch"
                    )
                # umask may have produced mode 000. Bootstrap only this pinned
                # inode to owner-searchable, then validate through a no-follow
                # descriptor before setting the governed final mode.
                os.chmod(
                    component,
                    0o755,
                    dir_fd=descriptor,
                    follow_symlinks=False,
                )
                next_descriptor = os.open(
                    component,
                    flags,
                    dir_fd=descriptor,
                )
                try:
                    bootstrap_opened = os.fstat(next_descriptor)
                    bootstrap_named = os.stat(
                        component,
                        dir_fd=descriptor,
                        follow_symlinks=False,
                    )
                    if (
                        not stat.S_ISDIR(bootstrap_opened.st_mode)
                        or bootstrap_opened.st_uid != os.geteuid()
                        or (bootstrap_opened.st_dev, bootstrap_opened.st_ino)
                        != (created_named.st_dev, created_named.st_ino)
                        or (bootstrap_opened.st_dev, bootstrap_opened.st_ino)
                        != (bootstrap_named.st_dev, bootstrap_named.st_ino)
                    ):
                        raise SourceInventoryError(
                            "new fixed output parent changed before fchmod"
                        )
                    os.fchmod(next_descriptor, 0o755)
                    os.fsync(next_descriptor)
                finally:
                    os.close(next_descriptor)
                next_descriptor = os.open(
                    component,
                    flags,
                    dir_fd=descriptor,
                )
            try:
                opened = os.fstat(next_descriptor)
                named = os.stat(
                    component,
                    dir_fd=descriptor,
                    follow_symlinks=False,
                )
                valid = (
                    stat.S_ISDIR(opened.st_mode)
                    and stat.S_ISDIR(named.st_mode)
                    and opened.st_uid == os.geteuid()
                    and not stat.S_IMODE(opened.st_mode) & 0o022
                    and (opened.st_dev, opened.st_ino)
                    == (named.st_dev, named.st_ino)
                    and (
                        not created
                        or stat.S_IMODE(opened.st_mode) == 0o755
                    )
                )
            except BaseException:
                os.close(next_descriptor)
                raise
            if not valid:
                os.close(next_descriptor)
                raise SourceInventoryError(
                    "fixed output parent identity/owner/mode mismatch"
                )
            if created:
                os.fsync(next_descriptor)
                os.fsync(descriptor)
            os.close(descriptor)
            descriptor = next_descriptor
        yield descriptor, components[-1]
    finally:
        os.close(descriptor)


def _read_regular_leaf(
    parent: int,
    leaf: bytes,
    *,
    allowed_modes: set[int],
    require_single_link: bool = False,
    fsync_after_read: bool = False,
) -> bytes:
    named_before = os.stat(leaf, dir_fd=parent, follow_symlinks=False)
    descriptor = os.open(
        leaf,
        os.O_RDONLY
        | getattr(os, "O_NOFOLLOW", 0)
        | getattr(os, "O_NONBLOCK", 0),
        dir_fd=parent,
    )
    try:
        opened = os.fstat(descriptor)
        if (
            not stat.S_ISREG(opened.st_mode)
            or opened.st_uid != os.geteuid()
            or stat.S_IMODE(opened.st_mode) not in allowed_modes
            or opened.st_size > MAX_GOVERNED_JSON_BYTES
            or (require_single_link and opened.st_nlink != 1)
            or (opened.st_dev, opened.st_ino)
            != (named_before.st_dev, named_before.st_ino)
        ):
            raise SourceInventoryError(
                "fixed JSON leaf identity/owner/mode mismatch"
            )
        chunks: list[bytes] = []
        total = 0
        while True:
            chunk = os.read(descriptor, 1024 * 1024)
            if not chunk:
                break
            total += len(chunk)
            if total > MAX_GOVERNED_JSON_BYTES:
                raise SourceInventoryError("fixed JSON leaf exceeds size limit")
            chunks.append(chunk)
        value = b"".join(chunks)
        named_after = os.stat(
            leaf,
            dir_fd=parent,
            follow_symlinks=False,
        )
        if (
            opened.st_dev,
            opened.st_ino,
            opened.st_size,
        ) != (
            named_after.st_dev,
            named_after.st_ino,
            named_after.st_size,
        ):
            raise SourceInventoryError("fixed JSON leaf changed while reading")
        if fsync_after_read:
            os.fsync(descriptor)
        return value
    finally:
        os.close(descriptor)


def _decode_canonical_json_object(value: bytes) -> dict[str, object]:
    try:
        decoded = json.loads(value.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        raise SourceInventoryError("fixed JSON is invalid") from error
    if not isinstance(decoded, dict) or canonical_json_bytes(decoded) != value:
        raise SourceInventoryError("fixed JSON is not canonical object bytes")
    return decoded


def _reject_other_fixed_json_temporaries(
    parent: int,
    leaf: bytes,
    expected_temporary: bytes,
) -> None:
    prefix = b"." + leaf + b".qinao-"
    suffix = b".tmp"
    lowercase_hex = frozenset(b"0123456789abcdef")
    for name in os.listdir(parent):
        raw = os.fsencode(name)
        if not raw.startswith(prefix) or not raw.endswith(suffix):
            continue
        digest = raw[len(prefix) : -len(suffix)]
        if len(digest) != 64 or any(byte not in lowercase_hex for byte in digest):
            raise SourceInventoryError(
                "fixed JSON temporary name is malformed"
            )
        if raw != expected_temporary:
            raise SourceInventoryError(
                "different fixed JSON install intent is present"
            )


def _load_fixed_candidate_json_no_follow(
    candidate_root: Path,
    relative_path: Path,
) -> dict[str, object]:
    raw = _fixed_candidate_path_bytes(relative_path)
    with open_parent_dirfd_no_follow(candidate_root, raw) as (parent, leaf):
        value = _read_regular_leaf(
            parent,
            leaf,
            allowed_modes={0o644},
        )
        decoded = _decode_canonical_json_object(value)
        digest = hashlib.sha256(value).hexdigest().encode("ascii")
        temporary = b"." + leaf + b".qinao-" + digest + b".tmp"
        _reject_other_fixed_json_temporaries(parent, leaf, temporary)
        try:
            stale = _read_regular_leaf(
                parent,
                temporary,
                allowed_modes={0o600, 0o644},
            )
        except FileNotFoundError:
            stale = None
        if stale is None:
            final_metadata = os.stat(
                leaf,
                dir_fd=parent,
                follow_symlinks=False,
            )
            if final_metadata.st_nlink != 1:
                raise SourceInventoryError(
                    "fixed JSON final has unexplained hard links"
                )
        else:
            final_metadata = os.stat(
                leaf,
                dir_fd=parent,
                follow_symlinks=False,
            )
            try:
                temporary_metadata = os.stat(
                    temporary,
                    dir_fd=parent,
                    follow_symlinks=False,
                )
            except FileNotFoundError:
                final_metadata = os.stat(
                    leaf,
                    dir_fd=parent,
                    follow_symlinks=False,
                )
                if final_metadata.st_nlink != 1:
                    raise SourceInventoryError(
                        "fixed JSON final has unexplained hard links"
                    )
            else:
                same_inode = (
                    final_metadata.st_dev,
                    final_metadata.st_ino,
                ) == (
                    temporary_metadata.st_dev,
                    temporary_metadata.st_ino,
                )
                if (
                    stale != value
                    or (
                        same_inode
                        and (
                            final_metadata.st_nlink != 2
                            or temporary_metadata.st_nlink != 2
                        )
                    )
                    or (
                        not same_inode
                        and (
                            final_metadata.st_nlink != 1
                            or temporary_metadata.st_nlink != 1
                        )
                    )
                ):
                    raise SourceInventoryError(
                        "fixed JSON recovery temporary is unsafe"
                    )
                try:
                    os.unlink(temporary, dir_fd=parent)
                except FileNotFoundError:
                    pass
                os.fsync(parent)
        reopened = _read_regular_leaf(
            parent,
            leaf,
            allowed_modes={0o644},
            require_single_link=True,
        )
        if reopened != value:
            raise SourceInventoryError(
                "fixed JSON changed during recovery reopen"
            )
    return decoded


def _install_fixed_candidate_json_no_replace(
    *,
    candidate_root: Path,
    source_root: Path,
    relative_path: Path,
    value: bytes,
    mode: int,
) -> None:
    raw = _fixed_candidate_path_bytes(relative_path)
    if mode != 0o644:
        raise SourceInventoryError("fixed candidate JSON mode must be 0644")
    if len(value) > MAX_GOVERNED_JSON_BYTES:
        raise SourceInventoryError(
            "fixed candidate JSON exceeds size limit before install"
        )
    _decode_canonical_json_object(value)
    candidate_stat = os.stat(candidate_root, follow_symlinks=False)
    source_stat = os.stat(source_root, follow_symlinks=False)
    candidate_real = candidate_root.resolve(strict=True)
    source_real = source_root.resolve(strict=True)
    common = Path(
        os.path.commonpath((str(candidate_real), str(source_real)))
    )
    if (
        not stat.S_ISDIR(candidate_stat.st_mode)
        or not stat.S_ISDIR(source_stat.st_mode)
        or (candidate_stat.st_dev, candidate_stat.st_ino)
        == (source_stat.st_dev, source_stat.st_ino)
        or common in {candidate_real, source_real}
    ):
        raise SourceInventoryError(
            "candidate/source roots are not distinct disjoint directories"
        )
    with _open_fixed_parent_for_install(
        candidate_root,
        relative_path,
    ) as (parent, leaf):
        digest = hashlib.sha256(value).hexdigest().encode("ascii")
        temporary = b"." + leaf + b".qinao-" + digest + b".tmp"
        _reject_other_fixed_json_temporaries(parent, leaf, temporary)
        try:
            existing = _read_regular_leaf(
                parent,
                leaf,
                allowed_modes={mode},
            )
        except FileNotFoundError:
            existing = None
        if existing is not None:
            if existing != value:
                raise SourceInventoryError(
                    "fixed candidate JSON already exists with different bytes"
                )
            if _load_fixed_candidate_json_no_follow(
                candidate_root,
                relative_path,
            ) != _decode_canonical_json_object(value):
                raise SourceInventoryError(
                    "fixed candidate JSON recovered-final mismatch"
                )
            return
        flags = (
            os.O_WRONLY
            | os.O_CREAT
            | os.O_EXCL
            | getattr(os, "O_NOFOLLOW", 0)
            | getattr(os, "O_NONBLOCK", 0)
        )
        try:
            descriptor = os.open(temporary, flags, 0o600, dir_fd=parent)
        except FileExistsError:
            stale = _read_regular_leaf(
                parent,
                temporary,
                allowed_modes={mode},
                require_single_link=True,
                fsync_after_read=True,
            )
            if stale != value:
                raise SourceInventoryError(
                    "fixed JSON deterministic temporary has different bytes"
                )
            descriptor = None
        if descriptor is not None:
            try:
                opened = os.fstat(descriptor)
                named = os.stat(
                    temporary,
                    dir_fd=parent,
                    follow_symlinks=False,
                )
                if (
                    not stat.S_ISREG(opened.st_mode)
                    or opened.st_uid != os.geteuid()
                    or opened.st_nlink != 1
                    or (opened.st_dev, opened.st_ino)
                    != (named.st_dev, named.st_ino)
                ):
                    raise SourceInventoryError(
                        "new fixed JSON temporary identity/owner mismatch"
                    )
                os.fchmod(descriptor, mode)
                governed = os.fstat(descriptor)
                named_after_fchmod = os.stat(
                    temporary,
                    dir_fd=parent,
                    follow_symlinks=False,
                )
                if (
                    not stat.S_ISREG(governed.st_mode)
                    or stat.S_IMODE(governed.st_mode) != mode
                    or governed.st_uid != os.geteuid()
                    or governed.st_nlink != 1
                    or (governed.st_dev, governed.st_ino)
                    != (opened.st_dev, opened.st_ino)
                    or (governed.st_dev, governed.st_ino)
                    != (
                        named_after_fchmod.st_dev,
                        named_after_fchmod.st_ino,
                    )
                ):
                    raise SourceInventoryError(
                        "new fixed JSON temporary changed during fchmod"
                    )
                offset = 0
                while offset < len(value):
                    written = os.write(descriptor, value[offset:])
                    if written <= 0:
                        raise SourceInventoryError(
                            "fixed JSON temporary write made no progress"
                        )
                    offset += written
                os.fsync(descriptor)
            finally:
                os.close(descriptor)
        try:
            os.link(
                temporary,
                leaf,
                src_dir_fd=parent,
                dst_dir_fd=parent,
                follow_symlinks=False,
            )
        except (FileExistsError, FileNotFoundError):
            pass
        os.fsync(parent)
    if _load_fixed_candidate_json_no_follow(
        candidate_root,
        relative_path,
    ) != _decode_canonical_json_object(value):
        raise SourceInventoryError("fixed candidate JSON postinstall mismatch")


def _safe_symlink_target(path: bytes, target: bytes) -> None:
    if target.startswith(b"/"):
        raise SourceInventoryError(
            f"absolute symlink is forbidden: {_display_path(path)}"
        )
    normalized = posixpath.normpath(posixpath.join(posixpath.dirname(path), target))
    if normalized == b".." or normalized.startswith(b"../"):
        raise SourceInventoryError(
            f"escaping symlink is forbidden: {_display_path(path)}"
        )


def _filesystem_entry(root: Path, path: bytes) -> dict[str, object]:
    try:
        with open_parent_dirfd_no_follow(root, path) as (parent, leaf):
            metadata = os.stat(
                leaf,
                dir_fd=parent,
                follow_symlinks=False,
            )
            if stat.S_ISLNK(metadata.st_mode):
                target = os.readlink(leaf, dir_fd=parent)
                if isinstance(target, str):
                    target = os.fsencode(target)
                closed_check = os.stat(
                    leaf,
                    dir_fd=parent,
                    follow_symlinks=False,
                )
                if (metadata.st_dev, metadata.st_ino) != (
                    closed_check.st_dev,
                    closed_check.st_ino,
                ):
                    raise SourceInventoryError(
                        f"symlink changed while reading: {_display_path(path)}"
                    )
                _safe_symlink_target(path, target)
                return {
                    "present": True,
                    "kind": "symlink",
                    "mode": "120000",
                    "size": len(target),
                    "sha256": _sha256(target),
                }
            if not stat.S_ISREG(metadata.st_mode):
                raise SourceInventoryError(
                    f"special file is forbidden: {_display_path(path)}"
                )
            descriptor = os.open(
                leaf,
                os.O_RDONLY
                | getattr(os, "O_NOFOLLOW", 0)
                | getattr(os, "O_NONBLOCK", 0),
                dir_fd=parent,
            )
            try:
                opened = os.fstat(descriptor)
                if not stat.S_ISREG(opened.st_mode):
                    raise SourceInventoryError(
                        f"file changed type while reading: {_display_path(path)}"
                    )
                if (metadata.st_dev, metadata.st_ino) != (
                    opened.st_dev,
                    opened.st_ino,
                ):
                    raise SourceInventoryError(
                        f"file changed before open: {_display_path(path)}"
                    )
                chunks: list[bytes] = []
                while True:
                    chunk = os.read(descriptor, 1024 * 1024)
                    if not chunk:
                        break
                    chunks.append(chunk)
                value = b"".join(chunks)
                closed_check = os.stat(
                    leaf,
                    dir_fd=parent,
                    follow_symlinks=False,
                )
                if (opened.st_dev, opened.st_ino, opened.st_size) != (
                    closed_check.st_dev,
                    closed_check.st_ino,
                    closed_check.st_size,
                ):
                    raise SourceInventoryError(
                        f"file changed while reading: {_display_path(path)}"
                    )
            finally:
                os.close(descriptor)
    except FileNotFoundError:
        return {
            "present": False,
            "kind": None,
            "mode": None,
            "size": None,
            "sha256": None,
        }
    except OSError as error:
        raise SourceInventoryError(
            f"descriptor-relative no-follow open failed: {_display_path(path)}"
        ) from error
    mode = "100755" if opened.st_mode & 0o111 else "100644"
    return {
        "present": True,
        "kind": "regular",
        "mode": mode,
        "size": len(value),
        "sha256": _sha256(value),
    }
```

All filesystem leaf access in inventory capture/reverification and apply
source reopening uses this one descriptor-relative primitive. Tests pause
after each parent component is opened, rename/swap the pathname to a symlink
or different directory, and resume. Capture, second-read verification, patch
construction, recovery, and lost-reply finalization must either read the
already pinned directory object and then detect whole-inventory drift or fail
closed; none may follow the replacement. Include intermediate-parent and
final-leaf symlink swaps, non-UTF-8 components, deletion during walk, and
regular↔symlink replacement, same-bytes mode replacement, and regular→FIFO
replacement. `O_NONBLOCK` plus `fstat` prevents a raced special-file open from
blocking the verifier.

- [ ] **Step 4: Implement Git tree/index/status capture without writing the source**

Add these exact operations:

```python
def _blob_bytes(root: Path, object_id: str) -> bytes:
    completed = run_git(root, "cat-file", "blob", object_id)
    return completed.stdout


def _git_stratum(mode: str, object_id: str, value: bytes) -> dict[str, object]:
    return {
        "present": True,
        "mode": mode,
        "git_oid": object_id,
        "sha256": _sha256(value),
    }


def _absent_git_stratum(*, index: bool = False) -> dict[str, object]:
    result: dict[str, object] = {
        "present": False,
        "mode": None,
        "git_oid": None,
        "sha256": None,
    }
    if index:
        result["stage"] = None
    return result


def _tree_entries(root: Path, revision: str) -> dict[bytes, dict[str, object]]:
    raw = run_git(root, "ls-tree", "-r", "-z", "--full-tree", revision).stdout
    entries: dict[bytes, dict[str, object]] = {}
    for record in raw.split(b"\x00"):
        if not record:
            continue
        header, path = record.split(b"\t", 1)
        mode_raw, kind, object_id_raw = header.split(b" ", 2)
        if kind != b"blob":
            raise SourceInventoryError(
                f"unsupported Git tree entry {kind!r}: {_display_path(path)}"
            )
        _validate_raw_path(path)
        mode = mode_raw.decode("ascii")
        object_id = object_id_raw.decode("ascii")
        entries[path] = _git_stratum(
            mode,
            object_id,
            _blob_bytes(root, object_id),
        )
    return entries


def _index_entries(root: Path) -> tuple[bytes, dict[bytes, dict[str, object]]]:
    raw = run_git(root, "ls-files", "--stage", "-z").stdout
    entries: dict[bytes, dict[str, object]] = {}
    for record in raw.split(b"\x00"):
        if not record:
            continue
        header, path = record.split(b"\t", 1)
        mode_raw, object_id_raw, stage_raw = header.split(b" ", 2)
        _validate_raw_path(path)
        stage = int(stage_raw)
        if stage != 0:
            raise SourceInventoryError(
                f"unresolved index stage {stage}: {_display_path(path)}"
            )
        if path in entries:
            raise SourceInventoryError(
                f"duplicate index path: {_display_path(path)}"
            )
        object_id = object_id_raw.decode("ascii")
        row = _git_stratum(
            mode_raw.decode("ascii"),
            object_id,
            _blob_bytes(root, object_id),
        )
        row["stage"] = 0
        entries[path] = row
    return raw, entries


def _index_tree_without_source_write(root: Path) -> tuple[str, str]:
    index_path_value = run_git(root, "rev-parse", "--git-path", "index").stdout
    index_path = Path(index_path_value.decode("utf-8").strip())
    if not index_path.is_absolute():
        index_path = root / index_path
    index_bytes = index_path.read_bytes()
    common_value = run_git(root, "rev-parse", "--git-common-dir").stdout
    common = Path(common_value.decode("utf-8").strip())
    if not common.is_absolute():
        common = root / common
    common = common.resolve(strict=True)
    with tempfile.TemporaryDirectory(prefix="qinao-index-tree-") as directory:
        temporary = Path(directory)
        copied_index = temporary / "index"
        copied_index.write_bytes(index_bytes)
        object_directory = temporary / "objects"
        object_directory.mkdir()
        environment = {
            "GIT_INDEX_FILE": str(copied_index),
            "GIT_OBJECT_DIRECTORY": str(object_directory),
            "GIT_ALTERNATE_OBJECT_DIRECTORIES": str(common / "objects"),
        }
        tree = run_git(
            root,
            "write-tree",
            environment=environment,
        ).stdout.decode("ascii").strip()
    if index_path.read_bytes() != index_bytes:
        raise SourceInventoryError("source index changed during temporary write-tree")
    return tree, _sha256(index_bytes)


def _status_map(raw: bytes) -> dict[bytes, str]:
    records = raw.split(b"\x00")
    result: dict[bytes, str] = {}
    index = 0
    while index < len(records):
        record = records[index]
        index += 1
        if not record:
            continue
        record_type = record[:1]
        if record_type == b"1":
            fields = record.split(b" ", 8)
            path = fields[8]
            xy = fields[1].decode("ascii")
        elif record_type == b"2":
            fields = record.split(b" ", 9)
            path = fields[9]
            xy = fields[1].decode("ascii")
            if index >= len(records):
                raise SourceInventoryError("rename status lacks original path")
            original = records[index]
            index += 1
            _validate_raw_path(original)
            result[original] = xy
        elif record_type == b"?":
            path = record[2:]
            xy = "??"
        elif record_type == b"!":
            continue
        elif record_type == b"u":
            raise SourceInventoryError("unmerged status is forbidden")
        else:
            raise SourceInventoryError(f"unknown porcelain-v2 record: {record!r}")
        _validate_raw_path(path)
        result[path] = xy
    return result
```

The temporary `write-tree` uses a copied index and temporary object directory whose alternate is the real common object store. Therefore it computes the real index-tree OID without updating the source index cache-tree or writing an object into the source object database.

- [ ] **Step 5: Implement one complete capture and the two-read retry**

Add:

```python
def _capture_once(
    *,
    root: Path,
    approved_base_commit: str,
    capture_tool_commit: str,
    captured_at: str,
) -> dict[str, object]:
    identity = require_source_root(root)
    if run_git(
        root,
        "merge-base",
        "--is-ancestor",
        approved_base_commit,
        identity.head_commit,
        check=False,
    ).returncode != 0:
        raise SourceInventoryError("approved base is not a source ancestor")
    head = _tree_entries(root, identity.head_commit)
    base = _tree_entries(root, approved_base_commit)
    index_raw, index_entries = _index_entries(root)
    index_tree, index_bytes_sha256 = _index_tree_without_source_write(root)
    status_raw = run_git(
        root,
        "status",
        "--porcelain=v2",
        "-z",
        "--untracked-files=all",
    ).stdout
    status = _status_map(status_raw)
    staged_patch = run_git(
        root,
        "diff",
        "--cached",
        "--binary",
        "--full-index",
        "--no-ext-diff",
        "--no-renames",
    ).stdout
    unstaged_patch = run_git(
        root,
        "diff",
        "--binary",
        "--full-index",
        "--no-ext-diff",
        "--no-renames",
    ).stdout
    untracked_raw = run_git(
        root,
        "ls-files",
        "--others",
        "--exclude-standard",
        "-z",
    ).stdout
    untracked_paths = {
        path for path in untracked_raw.split(b"\x00") if path
    }
    for path in untracked_paths:
        _validate_raw_path(path)

    changed_paths = {
        path
        for path in set(base) | set(head) | set(index_entries)
        if base.get(path) != head.get(path)
        or head.get(path) != index_entries.get(path)
    }
    changed_paths.update(status)
    changed_paths.update(untracked_paths)
    rows: list[dict[str, object]] = []
    for path in sorted(changed_paths):
        worktree = _filesystem_entry(root, path)
        untracked = (
            worktree
            if path in untracked_paths
            else {
                "present": False,
                "kind": None,
                "mode": None,
                "size": None,
                "sha256": None,
            }
        )
        rows.append(
            {
                "path_b64": _path_b64(path),
                "display_path": _display_path(path),
                "base": base.get(path, _absent_git_stratum()),
                "head": head.get(path, _absent_git_stratum()),
                "index": index_entries.get(
                    path,
                    _absent_git_stratum(index=True),
                ),
                "worktree": worktree,
                "untracked": untracked,
                "status_xy": status.get(path),
            }
        )
    return {
        "schema_version": 1,
        "approved_base_commit": approved_base_commit,
        "source_head_commit": identity.head_commit,
        "source_head_tree": identity.head_tree,
        "source_branch": identity.branch,
        "source_index_tree": index_tree,
        "source_index_bytes_sha256": index_bytes_sha256,
        "source_status_sha256": _sha256(status_raw),
        "staged_patch_sha256": _sha256(staged_patch),
        "unstaged_patch_sha256": _sha256(unstaged_patch),
        "capture_tool_commit": capture_tool_commit,
        "captured_at": captured_at,
        "paths": rows,
    }


def capture_inventory(
    *,
    root: Path,
    approved_base_commit: str,
    capture_tool_commit: str,
    captured_at: str,
) -> dict[str, object]:
    for attempt in range(2):
        first = _capture_once(
            root=root,
            approved_base_commit=approved_base_commit,
            capture_tool_commit=capture_tool_commit,
            captured_at=captured_at,
        )
        second = _capture_once(
            root=root,
            approved_base_commit=approved_base_commit,
            capture_tool_commit=capture_tool_commit,
            captured_at=captured_at,
        )
        if canonical_json_bytes(first) == canonical_json_bytes(second):
            return second
        if attempt == 1:
            break
    raise SourceInventoryError("source_drift after one complete retry")


def verify_inventory(*, root: Path, inventory: dict[str, object]) -> None:
    required = {
        "schema_version",
        "approved_base_commit",
        "source_head_commit",
        "source_head_tree",
        "source_branch",
        "source_index_tree",
        "source_index_bytes_sha256",
        "source_status_sha256",
        "staged_patch_sha256",
        "unstaged_patch_sha256",
        "capture_tool_commit",
        "captured_at",
        "paths",
    }
    schema_version = inventory.get("schema_version")
    if (
        set(inventory) != required
        or type(schema_version) is not int
        or schema_version != 1
    ):
        raise SourceInventoryError("inventory top-level schema mismatch")
    recaptured = capture_inventory(
        root=root,
        approved_base_commit=str(inventory["approved_base_commit"]),
        capture_tool_commit=str(inventory["capture_tool_commit"]),
        captured_at=str(inventory["captured_at"]),
    )
    if canonical_json_bytes(recaptured) != canonical_json_bytes(inventory):
        raise SourceInventoryError("source inventory no longer matches source bytes")
```

- [ ] **Step 6: Implement the capture/verify CLI**

The CLI must require candidate CWD, accept exactly one of `--output` or
`--verify`, and never write under the source root:

```python
def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--approved-base")
    parser.add_argument(
        "--operation-batch",
        choices=("C1", "C2", "C3", "C4"),
        required=True,
    )
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--output", type=Path)
    group.add_argument("--verify", type=Path)
    arguments = parser.parse_args()
    candidate = require_candidate_root(
        Path.cwd(),
        require_clean=False,
        expected_lineage=candidate_lineage_for_import_batch(
            arguments.operation_batch
        ),
    )
    if arguments.output is not None and arguments.operation_batch != "C1":
        parser.error("initial inventory capture is legal only for C1")
    fixed_inventory = Path(
        "docs/superpowers/evidence/qinao-clean-candidate/"
        "2026-07-23-c0/source-inventory.json"
    )
    if arguments.verify is not None:
        if arguments.verify != fixed_inventory:
            parser.error("--verify must name the fixed candidate inventory")
        value = _load_fixed_candidate_json_no_follow(
            candidate.root,
            fixed_inventory,
        )
        verify_inventory(root=arguments.root, inventory=value)
        print(
            f"inventory_status=complete paths={len(value['paths'])} "
            "source_unchanged=true"
        )
        return 0
    if arguments.approved_base is None:
        parser.error("--approved-base is required with --output")
    if arguments.output != fixed_inventory:
        parser.error("--output must name the fixed candidate inventory")
    try:
        existing = _load_fixed_candidate_json_no_follow(
            candidate.root,
            fixed_inventory,
        )
    except FileNotFoundError:
        existing = None
    if existing is not None:
        if (
            existing.get("approved_base_commit") != arguments.approved_base
            or existing.get("capture_tool_commit") != candidate.head_commit
        ):
            raise SourceInventoryError(
                "existing inventory belongs to a different capture intent"
            )
        verify_inventory(root=arguments.root, inventory=existing)
        print(
            f"inventory_status=complete paths={len(existing['paths'])} "
            "source_unchanged=true recovered_existing=true"
        )
        return 0
    source_identity = require_source_root(arguments.root)
    captured_at = (
        run_git(
            arguments.root,
            "show",
            "-s",
            "--format=%cI",
            source_identity.head_commit,
        )
        .stdout.decode("ascii")
        .strip()
    )
    if not captured_at:
        raise SourceInventoryError("source HEAD committer instant is empty")
    value = capture_inventory(
        root=arguments.root,
        approved_base_commit=arguments.approved_base,
        capture_tool_commit=candidate.head_commit,
        captured_at=captured_at,
    )
    _install_fixed_candidate_json_no_replace(
        candidate_root=candidate.root,
        source_root=arguments.root,
        relative_path=fixed_inventory,
        value=canonical_json_bytes(value),
        mode=0o644,
    )
    print(
        f"inventory_status=complete paths={len(value['paths'])} "
        "source_unchanged=true"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
```

The two fixed-candidate JSON helpers use the same descriptor-relative,
parent/final-no-follow, source-excluding, create-once-or-reopen-identical,
exact-mode, file/directory-`fsync` contract frozen for the import map.
`MAX_GOVERNED_JSON_BYTES == 64 * 1024 * 1024` is checked before any parent
creation, temporary creation, lock creation, or final-name mutation and while
streaming every reopen. An oversized value therefore leaves no directory,
temporary, final, lock, or journal residue.
`captured_at` is the exact source-HEAD committer instant (`%cI`), not a fresh
wall-clock sample, so an unchanged crash/retry reconstructs the same
inventory bytes and deterministic temporary name. If the final leaf already
exists, the CLI reopens and re-verifies that capture before sampling any new
time; it never manufactures a second intent. A linked or single-link owned
digest temporary left by a crash is validated, unlinked, and parent-`fsync`ed
before same-intent success; a foreign, multiply linked, substituted, or
different-byte temporary fails closed.
An exact complete single-link temporary is file-`fsync`ed and reused without
`ftruncate`, `write`, replacement, or mode repair. Two same-intent installers
may race only at the no-replace link and idempotent cleanup: neither ever
writes an inode after it can be linked as the final. New directories and
temporaries are tested under umask `0777`; identity/type/owner/link checks
precede descriptor `fchmod`, and exact governed mode plus pathname/inode
identity are revalidated after `fchmod` and reopen.
Verification requires a regular mode-`100644` canonical leaf and never
follows a symlink. Tests cover arbitrary/absolute/source-descendant paths,
parent/final symlinks, byte-identical lost-reply reopen,
preexisting-different bytes, restrictive umask, hard-linked temporary,
crash-before-link, crash-after-link-before-unlink, wrong mode, and failure
before any source or candidate mutation. They also cover missing-parent
creation under umask `0777`, process death immediately after `mkdir` followed
by recovery of only the exact owner/mode-`0000` residue, oversize preflight with zero residue,
different-byte deterministic-temp quarantine without unlink, exact-temp
reuse with mocked `ftruncate`/`write` forbidden, and two deliberately
interleaved same-intent installers that never expose partial final bytes.

- [ ] **Step 7: Run, inspect, and commit the inventory tool**

```bash
set -euo pipefail
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v \
  scripts.test_qinao_execution_root \
  scripts.test_capture_qinao_candidate_inventory
git diff --check
git add scripts/capture_qinao_candidate_inventory.py \
  scripts/test_capture_qinao_candidate_inventory.py
staged_paths="$(git diff --cached --name-only)"
expected_staged_paths="$(printf '%s\n' \
  scripts/capture_qinao_candidate_inventory.py \
  scripts/test_capture_qinao_candidate_inventory.py)"
test "$staged_paths" = "$expected_staged_paths"
git commit -m "build(qinao): capture stable source provenance"
worktree_status="$(git status --porcelain=v1)"
test -z "$worktree_status"
```

Expected: all tests pass and exactly two paths are committed.

---

### Task 4: Build and Validate the Hold-by-Default Import Map

**Files:**
- Create: `scripts/build_qinao_import_map.py`
- Create: `scripts/check_qinao_import_map.py`
- Create: `scripts/test_qinao_import_map.py`

**Interfaces:**
- Produces:

```text
def build_hold_map(
    inventory: dict[str, object],
    candidate_base_commit: str,
) -> dict[str, object]

def validate_import_map(
    inventory: dict[str, object],
    mapping: dict[str, object],
) -> list[str]
```

The map top-level field set is exactly:

```text
schema_version
inventory_sha256
approved_base_commit
source_head_commit
candidate_base_commit
rows
```

Every row is exactly:

```text
path_b64
display_path
decision
source_stratum
source_sha256
source_mode
destination_batch
rationale
review_record_digest
reviewer_identity_digest
reviewed_at
```

Closed values:

```text
decision = hold | omit | import
source_stratum = null | base | head | index | worktree | untracked | deletion
destination_batch = hold | C1 | C2 | C3 | C4
source_mode = null | 100644 | 100755 | 120000
review_record_digest = null | 64 lowercase hex
reviewer_identity_digest = null | 64 lowercase hex
reviewed_at = null | canonical UTC RFC 3339 timestamp ending in Z
```

`hold` rows carry all three review fields as `null`. Every `omit` or `import`
row must carry all three. `review_record_digest` binds the Bootstrap-verified,
externally signed `ImportReviewV1`; `reviewer_identity_digest` identifies its
authenticated human reviewer—not the implementation worker or model—and
`reviewed_at` equals that record's canonical time. Syntax alone never
authenticates review.

- [ ] **Step 1: Create typed RED seams and write exact-set/source-selection tests**

Create `scripts/build_qinao_import_map.py`:

```python
from __future__ import annotations


class ImportMapBuildError(RuntimeError):
    pass


def build_hold_map(
    inventory: dict[str, object],
    candidate_base_commit: str,
) -> dict[str, object]:
    raise ImportMapBuildError("RED: hold map builder is unavailable")
```

Create `scripts/check_qinao_import_map.py`:

```python
from __future__ import annotations


def validate_import_map(
    inventory: dict[str, object],
    mapping: dict[str, object],
) -> list[str]:
    return ["RED: import map validator is unavailable"]
```

Create these named tests:

```python
import copy


class QinaoImportMapTests(unittest.TestCase):
    def test_builder_emits_one_sorted_hold_row_per_inventory_path(self) -> None:
        mapping = builder.build_hold_map(self.inventory, self.approved_base)
        self.assertEqual(
            [
                base64.b64decode(row["path_b64"], validate=True)
                for row in mapping["rows"]
            ],
            sorted(
                base64.b64decode(row["path_b64"], validate=True)
                for row in self.inventory["paths"]
            ),
        )
        self.assertTrue(all(row["decision"] == "hold" for row in mapping["rows"]))
        self.assertTrue(all(row["source_stratum"] is None for row in mapping["rows"]))
        self.assertTrue(all(row["destination_batch"] == "hold" for row in mapping["rows"]))
        self.assertTrue(
            all(row["review_record_digest"] is None for row in mapping["rows"])
        )
        self.assertTrue(
            all(row["reviewer_identity_digest"] is None for row in mapping["rows"])
        )
        self.assertTrue(all(row["reviewed_at"] is None for row in mapping["rows"]))

    def test_validator_rejects_missing_extra_and_duplicate_paths(self) -> None:
        for mutation in ("missing", "extra", "duplicate"):
            with self.subTest(mutation=mutation):
                mapping = copy.deepcopy(self.mapping)
                self.apply_path_mutation(mapping, mutation)
                self.assertContainsError(mapping, "row path set")

    def test_validator_rejects_boolean_or_float_schema_version(self) -> None:
        for invalid in (True, 1.0):
            with self.subTest(invalid=invalid):
                mapping = copy.deepcopy(self.mapping)
                mapping["schema_version"] = invalid
                self.assertContainsError(mapping, "schema_version")

    def test_validator_rejects_implicit_latest_and_wrong_hash_or_mode(self) -> None:
        for field, value in (
            ("source_stratum", "latest"),
            ("source_sha256", "0" * 64),
            ("source_mode", "100755"),
        ):
            with self.subTest(field=field):
                mapping = self.import_row("worktree")
                mapping["rows"][0][field] = value
                self.assertContainsError(mapping, field)

    def test_validator_requires_authenticated_review_identity_and_time(self) -> None:
        for field, value in (
            ("review_record_digest", None),
            ("review_record_digest", "not-a-digest"),
            ("reviewer_identity_digest", None),
            ("reviewer_identity_digest", "not-a-digest"),
            ("reviewed_at", None),
            ("reviewed_at", "2026-07-23 00:00:00"),
        ):
            with self.subTest(field=field, value=value):
                mapping = self.import_row("worktree")
                mapping["rows"][0][field] = value
                self.assertContainsError(mapping, "review")

    def test_validator_requires_absent_postimage_for_deletion(self) -> None:
        mapping = self.import_row("deletion")
        self.inventory["paths"][0]["worktree"]["present"] = True
        self.assertContainsError(mapping, "deletion")

    def test_validator_rejects_production_bytes_before_c3(self) -> None:
        self.inventory["paths"][0]["path_b64"] = base64.b64encode(
            b"QinaoRuntimeSDK/Sources/QinaoRuntime/QinaoRuntime.swift"
        ).decode("ascii")
        self.mapping = builder.build_hold_map(self.inventory, self.approved_base)
        mapping = self.import_row("worktree", batch="C2")
        self.assertContainsError(mapping, "production path")

    def test_validator_rejects_raw_private_c4_classes(self) -> None:
        forbidden = (
            b"evidence/device.xcarchive",
            b"evidence/profile.mobileprovision",
            b"evidence/result.xcresult",
            b"evidence/store.sqlite-wal",
        )
        for path in forbidden:
            with self.subTest(path=path):
                inventory, mapping = self.with_path(path)
                mapping = self.select_import(inventory, mapping, "untracked", "C4")
                errors = checker.validate_import_map(inventory, mapping)
                self.assertTrue(any("raw private class" in error for error in errors))

    def test_validator_accepts_explicit_reviewed_regular_executable_symlink_and_deletion(self) -> None:
        inventory, mapping = self.four_kind_fixture()
        self.assertEqual(checker.validate_import_map(inventory, mapping), [])
```

The test-only `import_row`, `omit_row`, `select_import`, and
`four_kind_fixture` helpers install a fixed valid 64-hex reviewer identity
digest and `2026-07-23T00:00:00Z` before applying the one mutation under test.
Production tools expose no default reviewer or review time.

Add subtests that replace `candidate_base_commit` with another valid,
existing 40-hex commit, a nonexistent 40-hex value, a descendant candidate
tip, and a boolean/string lookalike. The pure validator rejects every
substitution that differs from `inventory.approved_base_commit`; the CLI also
requires that exact object to reopen as a commit and be an ancestor of the
guarded candidate `HEAD`. A syntactically valid arbitrary commit is never an
accepted reconstruction base. Run those Git checks only through the existing
sanitized `run_git`; hostile `GIT_DIR`, `GIT_WORK_TREE`,
`GIT_OBJECT_DIRECTORY`, alternates, replace refs, and graft environment
subtests must not redirect the lookup.

- [ ] **Step 2: Run RED**

```bash
set -euo pipefail
set +e
red_diagnostic="$(
  PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v \
    scripts.test_qinao_import_map 2>&1
)"
red_rc=$?
set -euo pipefail
printf '%s\n' "$red_diagnostic"
test "$red_rc" -eq 1
test "${red_diagnostic#*Ran }" != "$red_diagnostic"
test "${red_diagnostic#*Ran 0 tests}" = "$red_diagnostic"
test "${red_diagnostic#*FAILED}" != "$red_diagnostic"
test "${red_diagnostic#*RED: hold map builder is unavailable}" != "$red_diagnostic"
test "${red_diagnostic#*RED: import map validator is unavailable}" != "$red_diagnostic"
```

Expected: both modules import, every method is discovered, and assertions fail on the typed RED results. Syntax/import errors do not count as RED.

- [ ] **Step 3: Implement the all-hold builder**

Create `scripts/build_qinao_import_map.py`:

```python
from __future__ import annotations

import argparse
import base64
import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path

from scripts.capture_qinao_candidate_inventory import (
    _install_fixed_candidate_json_no_replace,
    _load_fixed_candidate_json_no_follow,
    canonical_json_bytes,
)
from scripts.qinao_execution_root import (
    CandidateLineage,
    DEFAULT_CONTRACT,
    require_candidate_root,
    run_git,
)


def build_hold_map(
    inventory: dict[str, object],
    candidate_base_commit: str,
) -> dict[str, object]:
    approved_base = inventory.get("approved_base_commit")
    if candidate_base_commit != approved_base:
        raise ValueError(
            "candidate_base_commit must equal inventory approved_base_commit"
        )
    rows = []
    for source in inventory["paths"]:
        rows.append(
            {
                "path_b64": source["path_b64"],
                "display_path": source["display_path"],
                "decision": "hold",
                "source_stratum": None,
                "source_sha256": None,
                "source_mode": None,
                "destination_batch": "hold",
                "rationale": "unreviewed",
                "review_record_digest": None,
                "reviewer_identity_digest": None,
                "reviewed_at": None,
            }
        )
    rows.sort(
        key=lambda row: base64.b64decode(
            row["path_b64"],
            validate=True,
        )
    )
    return {
        "schema_version": 1,
        "inventory_sha256": hashlib.sha256(
            canonical_json_bytes(inventory)
        ).hexdigest(),
        "approved_base_commit": inventory["approved_base_commit"],
        "source_head_commit": inventory["source_head_commit"],
        "candidate_base_commit": candidate_base_commit,
        "rows": rows,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--inventory", type=Path, required=True)
    parser.add_argument("--candidate-base", required=True)
    parser.add_argument("--output", type=Path, required=True)
    arguments = parser.parse_args()
    require_candidate_root(
        Path.cwd(),
        require_clean=False,
        expected_lineage=CandidateLineage.PREBOOTSTRAP_PREPARATION,
    )
    fixed_inventory = Path(
        "docs/superpowers/evidence/qinao-clean-candidate/"
        "2026-07-23-c0/source-inventory.json"
    )
    if arguments.inventory != fixed_inventory:
        parser.error("--inventory must name the fixed candidate inventory")
    inventory = _load_fixed_candidate_json_no_follow(
        Path.cwd(),
        fixed_inventory,
    )
    expected_base = str(inventory["approved_base_commit"])
    if arguments.candidate_base != expected_base:
        raise SystemExit(
            "candidate base does not equal inventory approved base"
        )
    run_git(Path.cwd(), "cat-file", "-e", f"{expected_base}^{{commit}}")
    run_git(Path.cwd(), "merge-base", "--is-ancestor", expected_base, "HEAD")
    mapping = build_hold_map(inventory, arguments.candidate_base)
    fixed_output = Path(
        "docs/superpowers/evidence/qinao-clean-candidate/"
        "2026-07-23-c0/import-map.json"
    )
    if arguments.output != fixed_output:
        raise SystemExit("import-map output path is not the fixed candidate path")
    _install_fixed_candidate_json_no_replace(
        candidate_root=Path.cwd(),
        source_root=DEFAULT_CONTRACT.source_root,
        relative_path=fixed_output,
        value=canonical_json_bytes(mapping),
        mode=0o644,
    )
    print(f"import_map_status=hold rows={len(mapping['rows'])}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
```

`_install_fixed_candidate_json_no_replace` accepts only the three literal
candidate outputs frozen by this plan (`source-inventory.json`,
`import-map.json`, and `source-provenance-v1.json`). It must therefore also
make a first clean-candidate capture possible when one or more literal parent
directories do not yet exist. Its parent-opening helper implements this exact
descriptor-relative protocol; a caller-selected path or a generic recursive
directory creator is forbidden:

1. open the already-guarded candidate root with
   `O_DIRECTORY|O_NOFOLLOW`;
2. walk each fixed literal parent component with `openat`;
3. on `ENOENT` only, call `mkdirat` for that exact component with requested
   mode `0755`, immediately reopen it with
   `O_DIRECTORY|O_NOFOLLOW`, descriptor-`fchmod` that newly created directory
   to exact `0755` (so a restrictive process umask cannot alter the durable
   contract), require owner `st_uid == geteuid()`, require exact mode `0755`,
   `fsync` the new directory and its parent, and continue from the held child
   descriptor;
4. for an existing parent, require a real directory owned by the effective
   user with no group/other write bit, but never chmod or otherwise mutate it;
5. after every create/open, compare the descriptor `fstat` identity with a
   fresh no-follow `statat` identity from the still-held parent; an
   identity/type/owner/mode change closes all descriptors and fails;
6. after the final leaf has been installed and file-`fsync`ed, `fsync` every
   created directory from leaf to root and the nearest pre-existing parent.

The digest-named temporary leaf—not the final name—is opened with
`O_CREAT|O_EXCL|O_NOFOLLOW|O_NONBLOCK`, descriptor-`fchmod`ed to the exact
requested file mode before any success observation, written as canonical
bytes, file-`fsync`ed, and linked without replacement to the final name before
the parent directory is `fsync`ed. Only newly created descriptors may be
`fchmod`ed; a pre-existing parent or final leaf is never repaired in place.
The helper treats a canonical byte-identical existing final leaf as
same-intent lost-reply recovery, cleans only its exact digest-named owned
temporary, and returns success without rewriting the final inode. It refuses
a divergent existing leaf, parent/leaf symlink, special file, wrong root,
source descendant, nonliteral output, ownership/mode drift, or rename
substitution and never truncates/replaces a final leaf. It never uses
`Path.mkdir(parents=True)`,
`os.makedirs`, a pathname-only precheck, or a process-global `chdir`.
Tests start from a candidate with the whole fixed evidence suffix absent and
prove successful first creation; single-mutation cases cover an absent
intermediate parent, preexisting safe parents, parent symlink/FIFO/file,
foreign owner, group/world-writable parent, wrong newly-created mode, and a
rename/symlink race at every component. A restrictive-umask subtest executes
the successful first capture under `umask 077` and still observes exact
directory `0755` and leaf `0644`. Every failure leaves the source unchanged
and leaves no leaf or partially trusted directory chain usable by a retry.

- [ ] **Step 4: Implement strict map validation**

Create `scripts/check_qinao_import_map.py` with exact structural rules:

```python
from __future__ import annotations

import argparse
import base64
import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path

from scripts.capture_qinao_candidate_inventory import (
    _load_fixed_candidate_json_no_follow,
    canonical_json_bytes,
)
from scripts.qinao_execution_root import (
    candidate_lineage_for_import_batch,
    require_candidate_root,
)


TOP_LEVEL_FIELDS = {
    "schema_version",
    "inventory_sha256",
    "approved_base_commit",
    "source_head_commit",
    "candidate_base_commit",
    "rows",
}
ROW_FIELDS = {
    "path_b64",
    "display_path",
    "decision",
    "source_stratum",
    "source_sha256",
    "source_mode",
    "destination_batch",
    "rationale",
    "review_record_digest",
    "reviewer_identity_digest",
    "reviewed_at",
}
SOURCE_STRATA = {"base", "head", "index", "worktree", "untracked"}
MODES = {"100644", "100755", "120000"}
BATCHES = {"C1", "C2", "C3", "C4"}
RAW_PRIVATE_SUFFIXES = (
    ".xcarchive",
    ".mobileprovision",
    ".p12",
    ".cer",
    ".key",
    ".ipa",
    ".xcresult",
    ".dsym",
    ".bcsymbolmap",
    ".sqlite",
    ".sqlite-wal",
    ".sqlite-shm",
    ".db",
    ".db-wal",
    ".db-shm",
    ".trace",
)

def parse_canonical_rfc3339_utc(value: str) -> datetime | None:
    try:
        parsed = datetime.strptime(value, "%Y-%m-%dT%H:%M:%SZ").replace(
            tzinfo=timezone.utc
        )
    except (TypeError, ValueError):
        return None
    return parsed if parsed.strftime("%Y-%m-%dT%H:%M:%SZ") == value else None


def _decode(value: object) -> bytes | None:
    if not isinstance(value, str):
        return None
    try:
        raw = base64.b64decode(value, validate=True)
    except ValueError:
        return None
    if base64.b64encode(raw).decode("ascii") != value:
        return None
    if not raw or raw.startswith(b"/") or b"\x00" in raw:
        return None
    if any(part in {b"", b".", b".."} for part in raw.split(b"/")):
        return None
    return raw


def _is_production_path(path: bytes) -> bool:
    parts = path.split(b"/")
    return b"Sources" in parts or (
        len(parts) >= 2
        and parts[0] in {b"SampleHost", b"Project06"}
        and path.endswith((b".swift", b".m", b".mm", b".c", b".cc", b".cpp"))
    )


def _is_raw_private_class(path: bytes) -> bool:
    lowered = path.decode("utf-8", "backslashreplace").lower()
    return lowered.endswith(RAW_PRIVATE_SUFFIXES)


def _selected_source(
    inventory_row: dict[str, object],
    stratum: str,
) -> dict[str, object] | None:
    value = inventory_row.get(stratum)
    return value if isinstance(value, dict) else None


def validate_import_map(
    inventory: dict[str, object],
    mapping: dict[str, object],
) -> list[str]:
    errors: list[str] = []
    if set(mapping) != TOP_LEVEL_FIELDS:
        errors.append("import map top-level field set mismatch")
    schema_version = mapping.get("schema_version")
    if type(schema_version) is not int or schema_version != 1:
        errors.append("schema_version must be integer 1")
    expected_inventory_digest = hashlib.sha256(
        canonical_json_bytes(inventory)
    ).hexdigest()
    if mapping.get("inventory_sha256") != expected_inventory_digest:
        errors.append("inventory_sha256 mismatch")
    for field in ("approved_base_commit", "source_head_commit"):
        if mapping.get(field) != inventory.get(field):
            errors.append(f"{field} mismatch")
    candidate_base = mapping.get("candidate_base_commit")
    if (
        not isinstance(candidate_base, str)
        or len(candidate_base) != 40
        or any(character not in "0123456789abcdef" for character in candidate_base)
    ):
        errors.append("candidate_base_commit must be 40 lowercase hex")
    if candidate_base != inventory.get("approved_base_commit"):
        errors.append(
            "candidate_base_commit must equal inventory approved_base_commit"
        )

    inventory_rows = inventory.get("paths")
    map_rows = mapping.get("rows")
    if not isinstance(inventory_rows, list) or not isinstance(map_rows, list):
        errors.append("paths and rows must be arrays")
        return errors
    inventory_by_path: dict[bytes, dict[str, object]] = {}
    for row in inventory_rows:
        raw = _decode(row.get("path_b64")) if isinstance(row, dict) else None
        if raw is None or raw in inventory_by_path:
            errors.append("inventory path identity is invalid or duplicate")
            continue
        inventory_by_path[raw] = row
    map_by_path: dict[bytes, dict[str, object]] = {}
    ordered_paths: list[bytes] = []
    for row in map_rows:
        if not isinstance(row, dict) or set(row) != ROW_FIELDS:
            errors.append("import row field set mismatch")
            continue
        raw = _decode(row.get("path_b64"))
        if raw is None or raw in map_by_path:
            errors.append("import row path identity is invalid or duplicate")
            continue
        map_by_path[raw] = row
        ordered_paths.append(raw)
    if set(inventory_by_path) != set(map_by_path):
        errors.append("import row path set does not equal inventory path set")
    if ordered_paths != sorted(ordered_paths):
        errors.append("import rows are not sorted by raw path bytes")

    for path in sorted(set(inventory_by_path) & set(map_by_path)):
        source = inventory_by_path[path]
        row = map_by_path[path]
        if row["display_path"] != source.get("display_path"):
            errors.append(f"display_path mismatch for {path!r}")
        decision = row["decision"]
        stratum = row["source_stratum"]
        digest = row["source_sha256"]
        mode = row["source_mode"]
        batch = row["destination_batch"]
        rationale = row["rationale"]
        review_record_digest = row["review_record_digest"]
        reviewer_identity_digest = row["reviewer_identity_digest"]
        reviewed_at = row["reviewed_at"]
        review_is_valid = (
            isinstance(review_record_digest, str)
            and len(review_record_digest) == 64
            and all(
                character in "0123456789abcdef"
                for character in review_record_digest
            )
            and isinstance(reviewer_identity_digest, str)
            and len(reviewer_identity_digest) == 64
            and all(
                character in "0123456789abcdef"
                for character in reviewer_identity_digest
            )
            and isinstance(reviewed_at, str)
            and reviewed_at.endswith("Z")
            and parse_canonical_rfc3339_utc(reviewed_at) is not None
        )
        if decision == "hold":
            if (
                stratum is not None
                or digest is not None
                or mode is not None
                or batch != "hold"
                or rationale != "unreviewed"
                or review_record_digest is not None
                or reviewer_identity_digest is not None
                or reviewed_at is not None
            ):
                errors.append(f"hold row is not canonical for {path!r}")
            continue
        if decision == "omit":
            if (
                stratum is not None
                or digest is not None
                or mode is not None
                or batch != "hold"
                or not isinstance(rationale, str)
                or not rationale.strip()
                or rationale == "unreviewed"
                or not review_is_valid
            ):
                errors.append(f"omit row is not explicitly reviewed for {path!r}")
            continue
        if decision != "import":
            errors.append(f"decision is invalid for {path!r}")
            continue
        if batch not in BATCHES:
            errors.append(f"destination_batch is invalid for {path!r}")
        if not isinstance(rationale, str) or not rationale.strip() or rationale == "unreviewed":
            errors.append(f"import rationale is missing for {path!r}")
        if not review_is_valid:
            errors.append(f"import review identity is missing for {path!r}")
        if _is_production_path(path) and batch in {"C1", "C2"}:
            errors.append(f"production path cannot enter before C3: {path!r}")
        if batch == "C4" and _is_raw_private_class(path):
            errors.append(f"raw private class cannot enter Git: {path!r}")
        if stratum == "deletion":
            if digest is not None or mode is not None:
                errors.append(f"deletion carries blob identity for {path!r}")
            if source["worktree"].get("present"):
                errors.append(f"deletion selected while postimage exists for {path!r}")
            if not any(source[name].get("present") for name in ("base", "head", "index")):
                errors.append(f"deletion lacks a present predecessor for {path!r}")
            continue
        if stratum not in SOURCE_STRATA:
            errors.append(f"source_stratum is invalid for {path!r}")
            continue
        selected = _selected_source(source, stratum)
        if selected is None or not selected.get("present"):
            errors.append(f"selected source stratum is absent for {path!r}")
            continue
        if digest != selected.get("sha256"):
            errors.append(f"source_sha256 mismatch for {path!r}")
        if mode != selected.get("mode") or mode not in MODES:
            errors.append(f"source_mode mismatch for {path!r}")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--inventory", type=Path, required=True)
    parser.add_argument("--map", type=Path, required=True)
    parser.add_argument(
        "--operation-batch",
        choices=("C1", "C2", "C3", "C4"),
        required=True,
    )
    arguments = parser.parse_args()
    candidate = require_candidate_root(
        Path.cwd(),
        require_clean=False,
        expected_lineage=candidate_lineage_for_import_batch(
            arguments.operation_batch
        ),
    )
    fixed_inventory = Path(
        "docs/superpowers/evidence/qinao-clean-candidate/"
        "2026-07-23-c0/source-inventory.json"
    )
    fixed_map = Path(
        "docs/superpowers/evidence/qinao-clean-candidate/"
        "2026-07-23-c0/import-map.json"
    )
    if arguments.inventory != fixed_inventory or arguments.map != fixed_map:
        parser.error("--inventory/--map must name the fixed candidate pair")
    inventory = _load_fixed_candidate_json_no_follow(
        candidate.root,
        fixed_inventory,
    )
    mapping = _load_fixed_candidate_json_no_follow(
        candidate.root,
        fixed_map,
    )
    errors = validate_import_map(inventory, mapping)
    if errors:
        for error in errors:
            print(f"ERROR: {error}")
        return 1
    decisions = {"hold": 0, "omit": 0, "import": 0}
    for row in mapping["rows"]:
        decisions[row["decision"]] += 1
    print(
        "import_map_status=valid "
        f"hold={decisions['hold']} omit={decisions['omit']} "
        f"import={decisions['import']}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
```

`--operation-batch` is a phase assertion, not a source-selection escape
hatch. The shared helper fixes `C1/C2 → prebootstrapPreparation` and
`C3/C4 → reparentedProgram`; the checker also requires the requested batch to
be present in the fixed reviewed-record groups once Bootstrap Task 1A installs
that verifier (the initial all-hold map is legal only as C1 preparation).
Tests run both lineages against both batch families and require wrong-phase
failure before map bytes are accepted.

- [ ] **Step 5: Run and commit the map tools**

```bash
set -euo pipefail
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v \
  scripts.test_qinao_import_map
git diff --check
git add scripts/build_qinao_import_map.py \
  scripts/check_qinao_import_map.py \
  scripts/test_qinao_import_map.py
staged_paths="$(git diff --cached --name-only)"
expected_staged_paths="$(printf '%s\n' \
  scripts/build_qinao_import_map.py \
  scripts/check_qinao_import_map.py \
  scripts/test_qinao_import_map.py)"
test "$staged_paths" = "$expected_staged_paths"
git commit -m "build(qinao): require reviewed source strata"
worktree_status="$(git status --porcelain=v1)"
test -z "$worktree_status"
```

Expected: all tests pass; exactly three files are committed.

---

### Task 5: Prepare and Apply a Destination-CAS Import Plan

**Files:**
- Create: `scripts/apply_qinao_import_map.py`
- Create: `scripts/test_apply_qinao_import_map.py`
- Create/reopen outside the worktree in its linked Git directory:
  `qinao-reviewed-import-transaction-v1.json` and
  `qinao-reviewed-import.lock`

**Interfaces:**
- Produces:

```text
@dataclass(frozen=True)
class ApplyPlan:
    schema_version: int
    inventory_sha256: str
    import_map_sha256: str
    candidate_head_commit: str
    candidate_head_tree: str
    candidate_index_tree: str
    candidate_status_sha256: str
    candidate_lineage: str
    destination_batch: str
    rows: tuple[dict[str, object], ...]

def prepare_apply_plan(
    *,
    candidate_root: Path,
    source_root: Path,
    inventory: dict[str, object],
    mapping: dict[str, object],
    destination_batch: str,
) -> ApplyPlan

def apply_reviewed_imports(
    *,
    candidate_root: Path,
    source_root: Path,
    inventory: dict[str, object],
    mapping: dict[str, object],
    plan: ApplyPlan,
) -> dict[str, object]

def recover_pending_import(
    *,
    candidate_root: Path,
    source_root: Path,
    inventory: dict[str, object],
    mapping: dict[str, object],
    destination_batch: str,
) -> dict[str, object]

def finalize_reviewed_import(
    *,
    candidate_root: Path,
    source_root: Path,
    inventory: dict[str, object],
    mapping: dict[str, object],
    plan: ApplyPlan,
) -> dict[str, object]
```

Each apply-plan row is exactly:

```text
path_b64
display_path
source_stratum
source_sha256
source_mode
destination_preimage {present, mode, git_oid, sha256}
```

The per-worktree journal has exactly:

```text
schema_version = 1
plan_sha256
apply_plan
patch_sha256
expected_post_index_tree
expected_paths_b64
```

`apply_plan` is the exact closed `_plan_to_json(plan)` object;
`expected_paths_b64` is its strictly raw-byte-sorted path projection. The
journal has no PID, timestamp, branch selector, success Boolean, or mutable
phase that could become recovery authority.

Every apply/recovery/finalize path returns the same closed
`ReviewedImportReceiptV1`:

```text
schema_version = 1
status = applied
destination_batch
plan_sha256
patch_sha256
candidate_preimage_commit
candidate_preimage_tree
expected_post_index_tree
expected_paths_b64
```

It deliberately contains no observed final commit OID, clock, PID, retry
count, or caller message; therefore the exact pre-commit apply, staged
recovery, and post-commit lost-reply finalization return byte-identical
canonical JSON.

- [ ] **Step 1: Create the typed RED seam and write apply tests**

Create `scripts/apply_qinao_import_map.py`:

```python
from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path


class SafeImportError(RuntimeError):
    pass


@dataclass(frozen=True)
class ApplyPlan:
    schema_version: int
    inventory_sha256: str
    import_map_sha256: str
    candidate_head_commit: str
    candidate_head_tree: str
    candidate_index_tree: str
    candidate_status_sha256: str
    candidate_lineage: str
    destination_batch: str
    rows: tuple[dict[str, object], ...]


def prepare_apply_plan(
    *,
    candidate_root: Path,
    source_root: Path,
    inventory: dict[str, object],
    mapping: dict[str, object],
    destination_batch: str,
) -> ApplyPlan:
    raise SafeImportError("RED: apply-plan preparation is unavailable")


def apply_reviewed_imports(
    *,
    candidate_root: Path,
    source_root: Path,
    inventory: dict[str, object],
    mapping: dict[str, object],
    plan: ApplyPlan,
) -> dict[str, object]:
    raise SafeImportError("RED: reviewed import apply is unavailable")


def recover_pending_import(
    *,
    candidate_root: Path,
    source_root: Path,
    inventory: dict[str, object],
    mapping: dict[str, object],
    destination_batch: str,
) -> dict[str, object]:
    raise SafeImportError("RED: reviewed import recovery is unavailable")


def finalize_reviewed_import(
    *,
    candidate_root: Path,
    source_root: Path,
    inventory: dict[str, object],
    mapping: dict[str, object],
    plan: ApplyPlan,
) -> dict[str, object]:
    raise SafeImportError("RED: reviewed import finalization is unavailable")
```

The test module creates a shared source/candidate repository, patches the root guard with a temporary `RootContract`, and includes:

```python
class ApplyQinaoImportMapTests(unittest.TestCase):
    def test_prepare_is_read_only_and_binds_head_tree_index_status_and_preimages(self) -> None:
        before = self.complete_probe()
        plan = self.prepare("C1")
        after = self.complete_probe()
        self.assertEqual(after, before)
        self.assertEqual(plan.candidate_head_commit, self.git("rev-parse", "HEAD"))
        self.assertEqual(plan.candidate_head_tree, self.git("rev-parse", "HEAD^{tree}"))
        self.assertEqual(len(plan.rows), 4)
        self.assertTrue(all("destination_preimage" in row for row in plan.rows))

    def test_apply_imports_regular_executable_symlink_and_deletion_exactly(self) -> None:
        plan = self.prepare("C1")
        receipt = self.apply(plan)
        self.assertEqual(receipt["status"], "applied")
        self.assertEqual((self.candidate / "regular.txt").read_bytes(), b"new regular\n")
        self.assertTrue(os.stat(self.candidate / "executable.sh").st_mode & 0o111)
        self.assertEqual(os.readlink(self.candidate / "safe-link"), "regular.txt")
        self.assertFalse((self.candidate / "deleted.txt").exists())
        self.assertEqual(
            self.git_bytes("diff", "--cached", "--name-only", "-z").split(b"\x00")[:-1],
            [b"deleted.txt", b"executable.sh", b"regular.txt", b"safe-link"],
        )

    def test_apply_rejects_changed_head_tree_or_map(self) -> None:
        plan = self.prepare("C1")
        (self.candidate / "unrelated.txt").write_text("new\n", encoding="utf-8")
        self.git("add", "unrelated.txt")
        self.git("commit", "-m", "intervening")
        with self.assertRaisesRegex(apply.SafeImportError, "destination CAS"):
            self.apply(plan)

    def test_apply_rejects_intervening_unstaged_or_untracked_edit(self) -> None:
        for path in ("regular.txt", "untracked-intervening.txt"):
            with self.subTest(path=path):
                self.restore_candidate()
                plan = self.prepare("C1")
                (self.candidate / path).write_text("intervening\n", encoding="utf-8")
                with self.assertRaisesRegex(apply.SafeImportError, "candidate is not clean"):
                    self.apply(plan)

    def test_apply_rejects_source_drift_after_plan(self) -> None:
        plan = self.prepare("C1")
        (self.source / "regular.txt").write_text("later source bytes\n", encoding="utf-8")
        with self.assertRaisesRegex(
            inventory.SourceInventoryError,
            "no longer matches",
        ):
            self.apply(plan)

    def test_apply_rejects_destination_symlink_substitution(self) -> None:
        plan = self.prepare("C1")
        (self.candidate / "regular.txt").unlink()
        (self.candidate / "regular.txt").symlink_to("../outside")
        with self.assertRaisesRegex(apply.SafeImportError, "candidate is not clean"):
            self.apply(plan)

    def test_apply_plan_rejects_boolean_or_float_schema_version(self) -> None:
        prepared = self.prepare("C1")
        for invalid in (True, 1.0):
            with self.subTest(invalid=invalid):
                value = apply._plan_to_json(prepared)
                value["schema_version"] = invalid
                with self.assertRaisesRegex(
                    apply.SafeImportError,
                    "apply plan schema",
                ):
                    apply._plan_from_json(value)
                with self.assertRaisesRegex(
                    apply.SafeImportError,
                    "apply plan schema",
                ):
                    self.apply(dataclasses.replace(prepared, schema_version=invalid))

    def test_apply_failure_leaves_no_partial_index_or_worktree_change(self) -> None:
        plan = self.prepare("C1")
        before = self.complete_probe()
        broken = dataclasses.replace(
            plan,
            rows=plan.rows + (dict(plan.rows[0], source_sha256="0" * 64),),
        )
        with self.assertRaises(apply.SafeImportError):
            self.apply(broken)
        self.assertEqual(self.complete_probe(), before)
```

Also add subprocess crash-cut tests at exactly:

```text
journalTemporaryFsyncedBeforeLink
journalLinkedAndDirectoryFsyncedBeforeTemporaryCleanup
journalTemporaryUnlinkedBeforeSecondDirectoryFsync
journalDurableBeforeApply
gitApplyReturnedBeforePostcheck
postcheckCompleteBeforeReceipt
receiptComputedBeforeCallerObserved
externalCommitCompleteBeforeFinalize
```

Each child process exits abruptly without running Python cleanup. For the
first three installer cuts, re-entry respectively reuses the exact
single-link temp without writing it, cleans the exact same-inode
`nlink == 2` residue to a freshly verified final `nlink == 1`, and reopens the
already-clean final. For the five transaction cuts, re-entry must prove: the
first resumes from the exact clean preimage; the middle three recognize the
exact staged postimage and return byte-identical receipts without a second
`git apply`; the final recognizes the exact single-parent committed postimage
and finalizes. Tests also cover a truncated
or symlink journal, a different-plan journal, missing/extra staged paths,
unstaged drift, post-tree drift, wrong commit parent/tree/mode, and a second
process holding the kernel lock. Every divergent case raises
`SafeImportError("reviewed import transaction diverged; quarantine")` and
leaves journal/index/worktree/HEAD untouched. No test repairs state with
reset, checkout, restore, or clean.

- [ ] **Step 2: Run RED**

```bash
set -euo pipefail
set +e
red_diagnostic="$(
  PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v \
    scripts.test_apply_qinao_import_map 2>&1
)"
red_rc=$?
set -euo pipefail
printf '%s\n' "$red_diagnostic"
test "$red_rc" -eq 1
test "${red_diagnostic#*Ran }" != "$red_diagnostic"
test "${red_diagnostic#*Ran 0 tests}" = "$red_diagnostic"
test "${red_diagnostic#*FAILED}" != "$red_diagnostic"
test "${red_diagnostic#*RED: apply-plan preparation is unavailable}" != "$red_diagnostic"
```

Expected: the module imports, every method is discovered, and assertions fail with the typed `SafeImportError` RED. Syntax/import errors do not count as RED.

- [ ] **Step 3: Implement immutable apply-plan encoding and destination preimages**

Create `scripts/apply_qinao_import_map.py`:

```python
from __future__ import annotations

import argparse
import base64
from contextlib import contextmanager
from dataclasses import asdict, dataclass
import fcntl
import hashlib
import json
import os
from pathlib import Path
import shutil
import stat
import tempfile
from typing import Iterator

from scripts.capture_qinao_candidate_inventory import (
    MAX_GOVERNED_JSON_BYTES,
    _index_tree_without_source_write,
    _load_fixed_candidate_json_no_follow,
    canonical_json_bytes,
    open_parent_dirfd_no_follow,
    verify_inventory,
)
from scripts.check_qinao_import_map import validate_import_map
from scripts.qinao_execution_root import (
    CandidateLineage,
    RootIdentity,
    RootGuardError,
    candidate_lineage_for_import_batch,
    require_candidate_root,
    require_source_root,
    run_git,
)


class SafeImportError(RuntimeError):
    pass


@dataclass(frozen=True)
class ApplyPlan:
    schema_version: int
    inventory_sha256: str
    import_map_sha256: str
    candidate_head_commit: str
    candidate_head_tree: str
    candidate_index_tree: str
    candidate_status_sha256: str
    candidate_lineage: str
    destination_batch: str
    rows: tuple[dict[str, object], ...]


def _sha256(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def _raw_path(value: str) -> bytes:
    try:
        raw = base64.b64decode(value, validate=True)
    except ValueError as error:
        raise SafeImportError("invalid path_b64") from error
    if base64.b64encode(raw).decode("ascii") != value:
        raise SafeImportError("non-canonical path_b64")
    if not raw or raw.startswith(b"/") or b"\x00" in raw:
        raise SafeImportError("unsafe raw path")
    if any(part in {b"", b".", b".."} for part in raw.split(b"/")):
        raise SafeImportError("unsafe raw path component")
    return raw


def _index_tree(root: Path) -> str:
    tree, unused_index_bytes_digest = _index_tree_without_source_write(root)
    if not unused_index_bytes_digest:
        raise SafeImportError("candidate index digest is empty")
    return tree


def _require_clean_candidate(
    root: Path,
    destination_batch: str,
) -> RootIdentity:
    try:
        return require_candidate_root(
            root,
            require_clean=True,
            expected_lineage=candidate_lineage_for_import_batch(
                destination_batch
            ),
        )
    except RootGuardError as error:
        raise SafeImportError(str(error)) from error


def _tree_entry(
    root: Path,
    commit: str,
    raw_path: bytes,
) -> dict[str, object]:
    path = os.fsdecode(raw_path)
    output = run_git(root, "ls-tree", "-z", commit, "--", path).stdout
    if not output:
        return {
            "present": False,
            "mode": None,
            "git_oid": None,
            "sha256": None,
        }
    records = [record for record in output.split(b"\x00") if record]
    if len(records) != 1:
        raise SafeImportError(f"destination preimage is ambiguous: {raw_path!r}")
    header, returned_path = records[0].split(b"\t", 1)
    if returned_path != raw_path:
        raise SafeImportError(f"destination path mismatch: {raw_path!r}")
    mode_raw, kind, object_id_raw = header.split(b" ", 2)
    if kind != b"blob":
        raise SafeImportError(f"destination is not a blob: {raw_path!r}")
    object_id = object_id_raw.decode("ascii")
    blob = run_git(root, "cat-file", "blob", object_id).stdout
    return {
        "present": True,
        "mode": mode_raw.decode("ascii"),
        "git_oid": object_id,
        "sha256": _sha256(blob),
    }


def prepare_apply_plan(
    *,
    candidate_root: Path,
    source_root: Path,
    inventory: dict[str, object],
    mapping: dict[str, object],
    destination_batch: str,
) -> ApplyPlan:
    candidate = _require_clean_candidate(candidate_root, destination_batch)
    require_source_root(source_root)
    verify_inventory(root=source_root, inventory=inventory)
    errors = validate_import_map(inventory, mapping)
    if errors:
        raise SafeImportError("invalid import map: " + "; ".join(errors))
    if destination_batch not in {"C1", "C2", "C3", "C4"}:
        raise SafeImportError("destination batch is invalid")
    rows: list[dict[str, object]] = []
    for row in mapping["rows"]:
        if row["decision"] != "import":
            continue
        if row["destination_batch"] != destination_batch:
            continue
        raw = _raw_path(row["path_b64"])
        rows.append(
            {
                "path_b64": row["path_b64"],
                "display_path": row["display_path"],
                "source_stratum": row["source_stratum"],
                "source_sha256": row["source_sha256"],
                "source_mode": row["source_mode"],
                "destination_preimage": _tree_entry(
                    candidate_root,
                    candidate.head_commit,
                    raw,
                ),
            }
        )
    rows.sort(key=lambda row: _raw_path(str(row["path_b64"])))
    if not rows:
        raise SafeImportError(f"batch {destination_batch} has zero reviewed imports")
    return ApplyPlan(
        schema_version=1,
        inventory_sha256=_sha256(canonical_json_bytes(inventory)),
        import_map_sha256=_sha256(canonical_json_bytes(mapping)),
        candidate_head_commit=candidate.head_commit,
        candidate_head_tree=candidate.head_tree,
        candidate_index_tree=_index_tree(candidate_root),
        candidate_status_sha256=_sha256(candidate.status_bytes),
        candidate_lineage=candidate.candidate_lineage.value,
        destination_batch=destination_batch,
        rows=tuple(rows),
    )
```

- [ ] **Step 4: Implement source reopening and exact destination CAS**

Add:

```python
def _inventory_rows(inventory: dict[str, object]) -> dict[bytes, dict[str, object]]:
    return {
        _raw_path(str(row["path_b64"])): row
        for row in inventory["paths"]
    }


def _read_filesystem_bytes(root: Path, raw_path: bytes, mode: str) -> bytes:
    try:
        with open_parent_dirfd_no_follow(root, raw_path) as (parent, leaf):
            metadata = os.stat(
                leaf,
                dir_fd=parent,
                follow_symlinks=False,
            )
            if mode == "120000":
                if not stat.S_ISLNK(metadata.st_mode):
                    raise SafeImportError(
                        f"source symlink changed type: {raw_path!r}"
                    )
                target = os.readlink(leaf, dir_fd=parent)
                value = (
                    target
                    if isinstance(target, bytes)
                    else os.fsencode(target)
                )
                closed_check = os.stat(
                    leaf,
                    dir_fd=parent,
                    follow_symlinks=False,
                )
                if (metadata.st_dev, metadata.st_ino) != (
                    closed_check.st_dev,
                    closed_check.st_ino,
                ):
                    raise SafeImportError(
                        f"source symlink changed while reading: {raw_path!r}"
                    )
                return value
            if not stat.S_ISREG(metadata.st_mode):
                raise SafeImportError(
                    f"source regular file changed type: {raw_path!r}"
                )
            actual_mode = "100755" if metadata.st_mode & 0o111 else "100644"
            if actual_mode != mode:
                raise SafeImportError(
                    f"source regular file changed mode: {raw_path!r}"
                )
            descriptor = os.open(
                leaf,
                os.O_RDONLY
                | getattr(os, "O_NOFOLLOW", 0)
                | getattr(os, "O_NONBLOCK", 0),
                dir_fd=parent,
            )
            try:
                opened = os.fstat(descriptor)
                if not stat.S_ISREG(opened.st_mode):
                    raise SafeImportError(
                        f"source regular file changed type: {raw_path!r}"
                    )
                if (metadata.st_dev, metadata.st_ino) != (
                    opened.st_dev,
                    opened.st_ino,
                ):
                    raise SafeImportError(
                        f"source regular file changed before open: {raw_path!r}"
                    )
                opened_mode = (
                    "100755" if opened.st_mode & 0o111 else "100644"
                )
                if opened_mode != mode:
                    raise SafeImportError(
                        f"source regular file changed mode: {raw_path!r}"
                    )
                chunks: list[bytes] = []
                while True:
                    chunk = os.read(descriptor, 1024 * 1024)
                    if not chunk:
                        break
                    chunks.append(chunk)
                closed_check = os.stat(
                    leaf,
                    dir_fd=parent,
                    follow_symlinks=False,
                )
                if (opened.st_dev, opened.st_ino, opened.st_size) != (
                    closed_check.st_dev,
                    closed_check.st_ino,
                    closed_check.st_size,
                ):
                    raise SafeImportError(
                        f"source file changed while reading: {raw_path!r}"
                    )
                return b"".join(chunks)
            finally:
                os.close(descriptor)
    except OSError as error:
        raise SafeImportError(
            f"descriptor-relative source reopen failed: {raw_path!r}"
        ) from error


def _selected_bytes(
    *,
    source_root: Path,
    inventory_row: dict[str, object],
    map_row: dict[str, object],
) -> bytes | None:
    stratum = map_row["source_stratum"]
    if stratum == "deletion":
        return None
    selected = inventory_row[stratum]
    if stratum in {"base", "head", "index"}:
        value = run_git(
            source_root,
            "cat-file",
            "blob",
            str(selected["git_oid"]),
        ).stdout
    else:
        value = _read_filesystem_bytes(
            source_root,
            _raw_path(str(map_row["path_b64"])),
            str(map_row["source_mode"]),
        )
    if _sha256(value) != map_row["source_sha256"]:
        raise SafeImportError(
            f"selected source bytes changed: {map_row['display_path']}"
        )
    if selected["mode"] != map_row["source_mode"]:
        raise SafeImportError(
            f"selected source mode changed: {map_row['display_path']}"
        )
    return value


def _assert_destination_cas(root: Path, plan: ApplyPlan) -> None:
    identity = _require_clean_candidate(root, plan.destination_batch)
    if identity.candidate_lineage.value != plan.candidate_lineage:
        raise SafeImportError("destination batch/lineage changed")
    current = (
        identity.head_commit,
        identity.head_tree,
        _index_tree(root),
        _sha256(identity.status_bytes),
    )
    expected = (
        plan.candidate_head_commit,
        plan.candidate_head_tree,
        plan.candidate_index_tree,
        plan.candidate_status_sha256,
    )
    if current != expected:
        raise SafeImportError(
            f"destination CAS mismatch: expected={expected!r} current={current!r}"
        )
    for row in plan.rows:
        current_preimage = _tree_entry(
            root,
            identity.head_commit,
            _raw_path(str(row["path_b64"])),
        )
        if current_preimage != row["destination_preimage"]:
            raise SafeImportError(
                f"destination preimage mismatch: {row['display_path']}"
            )


@contextmanager
def _import_lock(
    root: Path,
    destination_batch: str,
) -> Iterator[Path]:
    try:
        require_candidate_root(
            root,
            require_clean=False,
            expected_lineage=candidate_lineage_for_import_batch(
                destination_batch
            ),
        )
    except RootGuardError as error:
        raise SafeImportError(str(error)) from error
    git_dir = Path(
        run_git(root, "rev-parse", "--absolute-git-dir")
        .stdout.decode("utf-8")
        .strip()
    )
    lock = git_dir / "qinao-reviewed-import.lock"
    lock_flags = (
        os.O_RDWR
        | getattr(os, "O_NOFOLLOW", 0)
        | getattr(os, "O_NONBLOCK", 0)
    )
    try:
        descriptor = os.open(
            lock,
            lock_flags | os.O_CREAT | os.O_EXCL,
            0o600,
        )
        os.fchmod(descriptor, 0o600)
    except FileExistsError:
        descriptor = os.open(lock, lock_flags)
    try:
        metadata = os.fstat(descriptor)
        named = os.stat(lock, follow_symlinks=False)
        if (
            not stat.S_ISREG(metadata.st_mode)
            or stat.S_IMODE(metadata.st_mode) != 0o600
            or metadata.st_uid != os.getuid()
            or metadata.st_nlink != 1
            or (metadata.st_dev, metadata.st_ino)
            != (named.st_dev, named.st_ino)
        ):
            raise SafeImportError("reviewed-import lock ownership/mode mismatch")
        try:
            fcntl.flock(descriptor, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError as error:
            raise SafeImportError("reviewed-import transaction is active") from error
        yield git_dir
    finally:
        fcntl.flock(descriptor, fcntl.LOCK_UN)
        os.close(descriptor)
```

The regular owner-only, single-link mode-`0600` lock file may persist, but the
kernel lock never does: process exit releases it. A newly created descriptor
is `fchmod`ed before validation so any process umask produces the same
contract; a pre-existing inode is validated, never repaired. Never use file
existence, a PID, age, or manual unlink as liveness. Tests include umask
`0777`, symlink/FIFO/directory/hardlink substitution, two contenders, and
process death while holding the kernel lock.
The permanent Root Guard runs before `rev-parse`, `O_CREAT`, or any other
filesystem/Git write. Wrong root/branch/lineage therefore leaves no lock,
journal, object, index, or ref byte. `--recover-pending` carries the fixed
destination batch so this pre-write guard does not need to trust an unlocked
journal.

Under that lock, install the closed journal before `git apply`. Compute the
patch and `expected_post_index_tree` first; then canonicalize the exact journal
shape above. Reject canonical bytes larger than
`MAX_GOVERNED_JSON_BYTES` before creating a temporary, journal, or other
filesystem residue. Write it to a same-directory mode-`0600` temporary regular file
opened with `O_EXCL|O_NOFOLLOW`, `fsync` it, link it to the absent fixed
journal path without replacement, `fsync` the Git directory, unlink the
temporary name, and `fsync` the Git directory again. If the journal already
exists, reopen with `O_NOFOLLOW`,
require owner/mode/canonical field set, validate `plan_sha256`, and classify
state instead of replacing it.

A crash after the directory-fsynced link but before temporary cleanup leaves
one legal residue only: final and expected deterministic temporary are the
same `(st_dev, st_ino)`, both observations report `st_nlink == 2`, and both
reopen to the exact canonical journal bytes. The loader unlinks only that
temporary, fsyncs the Git directory, then requires a fresh final reopen with
`st_nlink == 1`. A separate inode, different bytes, another digest-temporary,
or any link count other than this exact `2 -> 1` transition quarantines
without cleanup. A complete single-link temporary with no final is fsynced
and reused without truncate/rewrite; a different or incomplete temporary is
never unlinked or repaired.

The classifier has exactly four outcomes:

```text
exactPreimage:
  HEAD/tree/index/status and every destination preimage equal apply_plan
exactStagedPostimage:
  HEAD remains candidate_head_commit; index tree equals
  expected_post_index_tree; staged raw-path set/modes/postimages are exact;
  unstaged and untracked sets are empty
exactCommittedPostimage:
  clean HEAD has exactly one parent candidate_head_commit; HEAD tree equals
  expected_post_index_tree; its raw-path/mode diff is exactly
  expected_paths_b64
divergent:
  every other state
```

`exactPreimage` may execute the already-bound patch once.
`exactStagedPostimage` never applies again and returns the same canonical
receipt. `exactCommittedPostimage` returns that receipt and may remove the
journal only after a file/directory-fsynced unlink. `divergent` returns the
typed quarantine error without writing. Receipt bytes are a pure function of
the journal/plan and expected post tree, so initial apply, recovery, and
finalization are byte-identical.

- [ ] **Step 5: Implement temporary-index patch creation and checked apply**

Add:

```python
def _patch_for_plan(
    *,
    candidate_root: Path,
    source_root: Path,
    inventory: dict[str, object],
    mapping: dict[str, object],
    plan: ApplyPlan,
) -> tuple[bytes, str]:
    inventory_by_path = _inventory_rows(inventory)
    mapping_by_path = {
        _raw_path(str(row["path_b64"])): row for row in mapping["rows"]
    }
    real_index_value = run_git(
        candidate_root,
        "rev-parse",
        "--git-path",
        "index",
    ).stdout.decode("utf-8").strip()
    real_index = Path(real_index_value)
    if not real_index.is_absolute():
        real_index = candidate_root / real_index
    with tempfile.TemporaryDirectory(prefix="qinao-import-index-") as directory:
        temporary_index = Path(directory) / "index"
        shutil.copyfile(real_index, temporary_index)
        environment = {"GIT_INDEX_FILE": str(temporary_index)}
        for plan_row in plan.rows:
            raw = _raw_path(str(plan_row["path_b64"]))
            map_row = mapping_by_path[raw]
            value = _selected_bytes(
                source_root=source_root,
                inventory_row=inventory_by_path[raw],
                map_row=map_row,
            )
            path = os.fsdecode(raw)
            if value is None:
                run_git(
                    candidate_root,
                    "update-index",
                    "--force-remove",
                    "--",
                    path,
                    environment=environment,
                )
                continue
            object_id = run_git(
                candidate_root,
                "hash-object",
                "-w",
                "--stdin",
                input_bytes=value,
            ).stdout.decode("ascii").strip()
            run_git(
                candidate_root,
                "update-index",
                "--add",
                "--cacheinfo",
                str(map_row["source_mode"]),
                object_id,
                path,
                environment=environment,
            )
        post_tree = run_git(
            candidate_root,
            "write-tree",
            environment=environment,
        ).stdout.decode("ascii").strip()
        patch = run_git(
            candidate_root,
            "diff",
            "--cached",
            "--binary",
            "--full-index",
            "--no-ext-diff",
            "--no-renames",
            plan.candidate_head_commit,
            environment=environment,
        ).stdout
    if not patch:
        raise SafeImportError("reviewed import produces an empty patch")
    return patch, post_tree


def _apply_reviewed_imports_locked(
    *,
    candidate_root: Path,
    source_root: Path,
    inventory: dict[str, object],
    mapping: dict[str, object],
    plan: ApplyPlan,
    git_dir: Path,
    transaction: dict[str, object] | None,
) -> dict[str, object]:
    if transaction is None:
        _assert_destination_cas(candidate_root, plan)
        expected_plan = prepare_apply_plan(
            candidate_root=candidate_root,
            source_root=source_root,
            inventory=inventory,
            mapping=mapping,
            destination_batch=plan.destination_batch,
        )
        if canonical_json_bytes(asdict(expected_plan)) != canonical_json_bytes(
            asdict(plan)
        ):
            raise SafeImportError(
                "apply plan does not equal freshly derived plan"
            )
        patch, expected_post_tree = _patch_for_plan(
            candidate_root=candidate_root,
            source_root=source_root,
            inventory=inventory,
            mapping=mapping,
            plan=plan,
        )
        transaction = _build_transaction(
            plan=plan,
            patch=patch,
            expected_post_index_tree=expected_post_tree,
        )
        _install_transaction_no_replace(git_dir, transaction)
    else:
        _validate_transaction_for_plan(transaction, plan)

    state = _classify_transaction_state(candidate_root, transaction)
    if state == "exactCommittedPostimage":
        return _receipt_for_transaction(transaction)
    if state == "exactStagedPostimage":
        return _receipt_for_transaction(transaction)
    if state != "exactPreimage":
        raise SafeImportError(
            "reviewed import transaction diverged; quarantine"
        )

    patch, expected_post_tree = _patch_for_plan(
        candidate_root=candidate_root,
        source_root=source_root,
        inventory=inventory,
        mapping=mapping,
        plan=plan,
    )
    if (
        _sha256(patch) != transaction["patch_sha256"]
        or expected_post_tree != transaction["expected_post_index_tree"]
    ):
        raise SafeImportError(
            "reviewed import transaction diverged; quarantine"
        )
    _assert_destination_cas(candidate_root, plan)
    completed = run_git(
        candidate_root,
        "apply",
        "--index",
        "--binary",
        "--whitespace=nowarn",
        check=False,
        input_bytes=patch,
    )
    if completed.returncode != 0:
        diagnostic = completed.stderr.decode(
            "utf-8", "backslashreplace"
        ).strip()
        if run_git(
            candidate_root,
            "status",
            "--porcelain=v2",
            "-z",
            "--untracked-files=all",
        ).stdout:
            raise SafeImportError(
                "git apply failed and candidate is unexpectedly dirty: "
                + diagnostic
            )
        raise SafeImportError("git apply rejected reviewed patch: " + diagnostic)
    if _classify_transaction_state(
        candidate_root,
        transaction,
    ) != "exactStagedPostimage":
        raise SafeImportError(
            "reviewed import transaction diverged; quarantine"
        )
    return _receipt_for_transaction(transaction)


def apply_reviewed_imports(
    *,
    candidate_root: Path,
    source_root: Path,
    inventory: dict[str, object],
    mapping: dict[str, object],
    plan: ApplyPlan,
) -> dict[str, object]:
    _preflight_plan_and_transaction_sizes_before_lock(plan)
    _validate_plan_review_basis(
        candidate_root=candidate_root,
        source_root=source_root,
        inventory=inventory,
        mapping=mapping,
        plan=plan,
    )
    with _import_lock(
        candidate_root,
        plan.destination_batch,
    ) as git_dir:
        return _apply_reviewed_imports_locked(
            candidate_root=candidate_root,
            source_root=source_root,
            inventory=inventory,
            mapping=mapping,
            plan=plan,
            git_dir=git_dir,
            transaction=_load_transaction_if_present(git_dir),
        )


def recover_pending_import(
    *,
    candidate_root: Path,
    source_root: Path,
    inventory: dict[str, object],
    mapping: dict[str, object],
    destination_batch: str,
) -> dict[str, object]:
    _preflight_transaction_file_before_lock(
        candidate_root,
        destination_batch,
    )
    with _import_lock(candidate_root, destination_batch) as git_dir:
        transaction = _require_transaction(git_dir)
        plan = _plan_from_json(transaction["apply_plan"])
        if plan.destination_batch != destination_batch:
            raise SafeImportError("recovery batch/journal mismatch")
        _validate_plan_review_basis(
            candidate_root=candidate_root,
            source_root=source_root,
            inventory=inventory,
            mapping=mapping,
            plan=plan,
        )
        return _apply_reviewed_imports_locked(
            candidate_root=candidate_root,
            source_root=source_root,
            inventory=inventory,
            mapping=mapping,
            plan=plan,
            git_dir=git_dir,
            transaction=transaction,
        )


def finalize_reviewed_import(
    *,
    candidate_root: Path,
    source_root: Path,
    inventory: dict[str, object],
    mapping: dict[str, object],
    plan: ApplyPlan,
) -> dict[str, object]:
    _preflight_plan_and_transaction_sizes_before_lock(plan)
    _validate_plan_review_basis(
        candidate_root=candidate_root,
        source_root=source_root,
        inventory=inventory,
        mapping=mapping,
        plan=plan,
    )
    with _import_lock(
        candidate_root,
        plan.destination_batch,
    ) as git_dir:
        transaction = _load_transaction_if_present(git_dir)
        if transaction is None:
            transaction = _transaction_from_plan_and_committed_postimage(
                candidate_root,
                plan,
            )
        else:
            _validate_transaction_for_plan(transaction, plan)
        if _classify_transaction_state(
            candidate_root,
            transaction,
        ) != "exactCommittedPostimage":
            raise SafeImportError(
                "reviewed import transaction diverged; quarantine"
            )
        receipt = _receipt_for_transaction(transaction)
        _unlink_transaction_and_fsync(git_dir)
        return receipt
```

Implement every underscored helper above in this same module with exactly this
private surface; no additional recovery selector or mutable phase field is
permitted:

```text
_build_transaction(*, plan: ApplyPlan, patch: bytes,
    expected_post_index_tree: str) -> dict[str, object]
_validate_transaction_for_plan(transaction: dict[str, object],
    plan: ApplyPlan) -> None
_install_transaction_no_replace(git_dir: Path,
    transaction: dict[str, object]) -> None
_load_transaction_if_present(git_dir: Path) -> dict[str, object] | None
_require_transaction(git_dir: Path) -> dict[str, object]
_classify_transaction_state(candidate_root: Path,
    transaction: dict[str, object]) ->
    Literal["exactPreimage", "exactStagedPostimage",
            "exactCommittedPostimage", "divergent"]
_receipt_for_transaction(transaction: dict[str, object]) ->
    dict[str, object]
_preflight_plan_and_transaction_sizes_before_lock(plan: ApplyPlan) -> None
_preflight_transaction_file_before_lock(candidate_root: Path,
    destination_batch: str) -> None
_validate_plan_review_basis(*, candidate_root: Path, source_root: Path,
    inventory: dict[str, object], mapping: dict[str, object],
    plan: ApplyPlan) -> None
_transaction_from_plan_and_committed_postimage(candidate_root: Path,
    plan: ApplyPlan) -> dict[str, object]
_unlink_transaction_and_fsync(git_dir: Path) -> None
_install_external_plan_no_replace(*, output_path: Path,
    candidate_root: Path, source_root: Path, value: bytes) -> None
_read_external_plan_no_follow(path: Path, *, candidate_root: Path,
    source_root: Path) -> dict[str, object]
```

`_build_transaction` emits exactly the six journal fields above, derives
`plan_sha256` from canonical `_plan_to_json(plan)`, derives
`expected_paths_b64` from the strict raw-byte sort, and accepts no
caller-supplied digest. `_validate_transaction_for_plan` rejects
missing/extra keys, bool-as-int schema values, noncanonical Base64,
unsorted/duplicate paths, any digest mismatch, and any transaction whose
embedded closed plan is not byte-identical to the argument.

`_preflight_plan_and_transaction_sizes_before_lock` is pure: it canonicalizes
the closed plan and a synthetic transaction with fixed-width SHA-256/tree
placeholders plus the plan's exact path projection, and rejects either value
above `MAX_GOVERNED_JSON_BYTES`. It performs no Git or filesystem operation.
`_preflight_transaction_file_before_lock` first runs the permanent Root Guard
for the supplied batch, resolves only the fixed per-worktree journal path,
and bounded-reads it with no-follow solely to reject missing/oversized input;
it returns no fields and grants no authority. The journal is independently
reopened and fully validated after `_import_lock`.

`_install_transaction_no_replace` and
`_load_transaction_if_present` operate only on
`<git-dir>/qinao-reviewed-import-transaction-v1.json`. Installation uses a
deterministic digest-named same-directory owner-only temporary, exact
mode-`0600` via descriptor `fchmod`, complete write/file-`fsync`,
`linkat`-without-replacement, directory-`fsync`, temporary unlink, and a
second directory-`fsync`; it never directly creates or replaces the final
name. Before any temporary, final, journal, directory, or lock mutation, the
shared atomic primitive rejects canonical bytes larger than
`MAX_GOVERNED_JSON_BYTES`; the reader enforces the same bound in 1 MiB
streaming chunks. A newly created inode is first checked only for
regular/type/owner/pathname identity and `st_nlink == 1`, then descriptor
`fchmod`ed and freshly revalidated for exact mode before its first write. An
existing exact complete temporary is fsynced and reused without
truncate/rewrite; different bytes or identity quarantine without unlink.

Reopen normally requires no-follow regular owner-only single-final identity,
bounded canonical bytes, and a fresh pathname/inode comparison. Its sole
pre-cleanup exception is the expected deterministic temporary and final
naming the same inode with both `st_nlink == 2`; after byte/identity
validation it unlinks the temporary, directory-fsyncs, and freshly requires
the final at `st_nlink == 1`. An exact existing journal is same-intent
recovery; a divergent, truncated, symlink, unexplained hard link,
different-digest temporary, or different-plan journal quarantines.

`_require_transaction` is the same loader plus a typed missing-journal error.
`_classify_transaction_state` is a read-only total function over the four
states frozen above and returns `divergent` for every Git error, extra status
row, mode mismatch, merge, missing object, or ambiguous relation.
`_receipt_for_transaction` derives exactly the nine receipt fields above and
first revalidates the complete journal; it reads no current clock or Git
state. `_unlink_transaction_and_fsync` reopens and validates the exact
journal inode/digest under the still-held import lock, uses descriptor-relative
`unlinkat`, and `fsync`s the Git directory; absence or substitution is not
success.

`_transaction_from_plan_and_committed_postimage` is legal only for lost reply
after an already-fsynced journal unlink. It derives the raw binary
parent-to-HEAD patch and post tree from the exact clean one-parent child,
reconstructs the journal through `_build_transaction`, then requires the
closed classifier to return `exactCommittedPostimage`. It accepts only the
expected parent, tree, raw-byte path set, modes, and selected source hashes;
unchanged unrelated bytes must remain equal. This makes
`journal absent + exact committed postimage` return the same receipt; every
near miss quarantines.

The two external-plan helpers implement the `/private/tmp` contract below and
share the same atomic installer/reader, not a second ad hoc pathname writer.
Each helper has one closed schema/state responsibility; none consults time,
PID, branch spelling, status prose, or caller success.

Every public apply/recover/finalize entry point performs a read-only
`MAX_GOVERNED_JSON_BYTES` preflight before `_import_lock` can create its
persistent lock inode. Apply/finalize preflight canonical plan bytes directly;
recovery performs a bounded no-follow preflight of the fixed journal without
using its fields as authority, then reopens and revalidates it under the
kernel lock. The new-transaction path computes a pure serialized-size upper
bound from the closed plan before locking and checks the exact transaction
bytes again under the lock before any journal temporary is created. Thus an
oversized input cannot leave even a lock-file residue, while no unlocked read
can authorize recovery.

`_validate_plan_review_basis` independently authenticates the inventory/map
canonical digests, runs `verify_inventory` and `validate_import_map`, enforces
the batch/lineage mapping, projects the exact reviewed rows for that batch,
reopens every selected source byte/mode/hash, and recomputes destination
preimages from `plan.candidate_head_commit`. Its projected rows must
byte-equal `plan.rows`. It runs before journal-absent reconstruction and
before any receipt is returned. `_apply_reviewed_imports_locked` is the exact
body of `apply_reviewed_imports` after lock acquisition; recovery calls it
while retaining the same kernel lock. It never releases and reacquires
between journal read, classification, patch validation, and apply.

Tests include wrong-root/branch/lineage non-mutation before lock `O_CREAT`,
two concurrent recoverers, recovery-vs-finalize contention, a forged plan
after an arbitrary one-parent commit, changed inventory/map/source after a
lost reply, and the positive crash after commit/journal unlink/stdout loss.
Only the last returns the original byte-identical receipt. Add three
subprocess journal-installer cuts at exactly
`journalTemporaryFsyncedBeforeLink`,
`journalLinkedAndDirectoryFsyncedBeforeTemporaryCleanup`, and
`journalTemporaryUnlinkedBeforeSecondDirectoryFsync`. The first reuses the
single-link exact temporary without rewriting by re-entering apply with the
same external plan; the latter two re-enter recovery. The second proves the legal
same-inode `nlink == 2` cleanup and final `nlink == 1`; the third proves the
already-clean final. Unrelated hard links, different bytes, and different
digest-temporaries quarantine in all three. Also require oversize journal
and external-plan preflight to leave no temporary, final, lock, journal, or
directory residue.

`hash-object -w` may add unreachable/reachable blob objects to the shared Git object database, but it does not mutate source refs, source index, source worktree, or source status. The stable source verification ignores unrelated object-database growth and reopens every selected source byte immediately before patch construction.

- [ ] **Step 6: Implement strict plan JSON and four-mode crash-safe CLI**

Add:

```python
def _plan_to_json(plan: ApplyPlan) -> dict[str, object]:
    value = asdict(plan)
    value["rows"] = list(plan.rows)
    return value


def _plan_from_json(value: dict[str, object]) -> ApplyPlan:
    expected = {
        "schema_version",
        "inventory_sha256",
        "import_map_sha256",
        "candidate_head_commit",
        "candidate_head_tree",
        "candidate_index_tree",
        "candidate_status_sha256",
        "candidate_lineage",
        "destination_batch",
        "rows",
    }
    if set(value) != expected or not isinstance(value["rows"], list):
        raise SafeImportError("apply plan field set mismatch")
    schema_version = value["schema_version"]
    if type(schema_version) is not int or schema_version != 1:
        raise SafeImportError("apply plan schema mismatch")
    expected_lineage = candidate_lineage_for_import_batch(
        value["destination_batch"]
    ).value
    if value["candidate_lineage"] != expected_lineage:
        raise SafeImportError("apply plan batch/lineage mismatch")
    return ApplyPlan(
        schema_version=schema_version,
        inventory_sha256=value["inventory_sha256"],
        import_map_sha256=value["import_map_sha256"],
        candidate_head_commit=value["candidate_head_commit"],
        candidate_head_tree=value["candidate_head_tree"],
        candidate_index_tree=value["candidate_index_tree"],
        candidate_status_sha256=value["candidate_status_sha256"],
        candidate_lineage=value["candidate_lineage"],
        destination_batch=value["destination_batch"],
        rows=tuple(value["rows"]),
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--candidate-root", type=Path, required=True)
    parser.add_argument("--source-root", type=Path, required=True)
    parser.add_argument("--inventory", type=Path, required=True)
    parser.add_argument("--map", type=Path, required=True)
    modes = parser.add_mutually_exclusive_group(required=True)
    modes.add_argument("--prepare-batch", choices=("C1", "C2", "C3", "C4"))
    modes.add_argument("--apply-plan", type=Path)
    modes.add_argument(
        "--recover-pending",
        choices=("C1", "C2", "C3", "C4"),
    )
    modes.add_argument("--finalize-plan", type=Path)
    parser.add_argument("--output-plan", type=Path)
    arguments = parser.parse_args()
    fixed_inventory = Path(
        "docs/superpowers/evidence/qinao-clean-candidate/"
        "2026-07-23-c0/source-inventory.json"
    )
    fixed_map = Path(
        "docs/superpowers/evidence/qinao-clean-candidate/"
        "2026-07-23-c0/import-map.json"
    )
    if arguments.inventory != fixed_inventory or arguments.map != fixed_map:
        parser.error("--inventory/--map must name the fixed candidate pair")
    inventory = _load_fixed_candidate_json_no_follow(
        arguments.candidate_root,
        fixed_inventory,
    )
    mapping = _load_fixed_candidate_json_no_follow(
        arguments.candidate_root,
        fixed_map,
    )
    if arguments.prepare_batch is not None:
        if arguments.output_plan is None:
            parser.error("--output-plan is required with --prepare-batch")
        plan = prepare_apply_plan(
            candidate_root=arguments.candidate_root,
            source_root=arguments.source_root,
            inventory=inventory,
            mapping=mapping,
            destination_batch=arguments.prepare_batch,
        )
        _install_external_plan_no_replace(
            output_path=arguments.output_plan,
            candidate_root=arguments.candidate_root,
            source_root=arguments.source_root,
            value=canonical_json_bytes(_plan_to_json(plan)),
        )
        print(
            f"apply_plan_status=prepared batch={plan.destination_batch} "
            f"paths={len(plan.rows)}"
        )
        return 0
    if arguments.output_plan is not None:
        parser.error("--output-plan is legal only with --prepare-batch")
    if arguments.recover_pending is not None:
        receipt = recover_pending_import(
            candidate_root=arguments.candidate_root,
            source_root=arguments.source_root,
            inventory=inventory,
            mapping=mapping,
            destination_batch=arguments.recover_pending,
        )
    else:
        plan_path = (
            arguments.apply_plan
            if arguments.apply_plan is not None
            else arguments.finalize_plan
        )
        plan_value = _read_external_plan_no_follow(
            plan_path,
            candidate_root=arguments.candidate_root,
            source_root=arguments.source_root,
        )
        plan = _plan_from_json(plan_value)
        if arguments.apply_plan is not None:
            receipt = apply_reviewed_imports(
                candidate_root=arguments.candidate_root,
                source_root=arguments.source_root,
                inventory=inventory,
                mapping=mapping,
                plan=plan,
            )
        else:
            receipt = finalize_reviewed_import(
                candidate_root=arguments.candidate_root,
                source_root=arguments.source_root,
                inventory=inventory,
                mapping=mapping,
                plan=plan,
            )
    print(canonical_json_bytes(receipt).decode("utf-8"), end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
```

`_install_external_plan_no_replace` permits only an absolute regular
mode-`0600` leaf directly beneath `/private/tmp`, with a basename matching
`qinao-[a-z0-9-]+-import-plan.json`. It proves the target is outside both
candidate and preserved-source roots and opens the existing `/private/tmp`
directory by descriptor with `O_DIRECTORY|O_NOFOLLOW`. It canonicalizes the
deterministic plan first and rejects it if its byte length exceeds
`MAX_GOVERNED_JSON_BYTES`, before opening `/private/tmp` or creating any
temporary/final/lock residue. It then installs it with the same code-owned atomic
primitive as the fixed candidate JSON: a digest-named same-directory
temporary opened `O_CREAT|O_EXCL|O_NOFOLLOW|O_NONBLOCK`, owner/single-link
identity validation, descriptor-`fchmod(0600)`, fresh exact-mode and
pathname/inode validation, complete write, file-`fsync`,
`linkat`-without-replacement to the final basename, parent-`fsync`, temporary
`unlinkat`, and a second parent-`fsync`. The final name is therefore never
partially visible. A canonical byte-identical final is same-intent
lost-reply success after safe temporary cleanup. An exact complete
single-link temporary is fsynced and reused without truncate/rewrite; two
same-intent installers can only race at no-replace link and idempotent
cleanup. Final plus deterministic temporary is legal only when both names
identify the same inode at `st_nlink == 2`; cleanup fsyncs the parent and
freshly proves final `st_nlink == 1`. A divergent final,
foreign/multiply-linked temporary, or different deterministic plan fails
closed. It never makes a caller-selected parent, directly opens the final
with `O_CREAT`, or overwrites an existing leaf.
`_read_external_plan_no_follow` enforces the same absolute path, owner,
single-final-inode, regular-file, exact mode, bounded streaming size,
no-follow, canonical-JSON, and root-exclusion contract before parsing. Tests
attempt source/candidate descendants, relative paths, nested temp paths,
parent/final symlinks, broad modes, restrictive umask, hard-linked
temporary, crash before link, crash after link before cleanup,
byte-identical retry, preexisting divergent bytes, invalid basenames,
oversize zero-residue preflight, exact-temp no-rewrite, and deliberately
interleaved same-intent installers;
every case leaves both repositories byte-identical.

- [ ] **Step 7: Run and commit the apply tool**

```bash
set -euo pipefail
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v \
  scripts.test_qinao_execution_root \
  scripts.test_capture_qinao_candidate_inventory \
  scripts.test_qinao_import_map \
  scripts.test_apply_qinao_import_map
git diff --check
git add scripts/apply_qinao_import_map.py \
  scripts/test_apply_qinao_import_map.py
staged_paths="$(git diff --cached --name-only)"
expected_staged_paths="$(printf '%s\n' \
  scripts/apply_qinao_import_map.py \
  scripts/test_apply_qinao_import_map.py)"
test "$staged_paths" = "$expected_staged_paths"
git commit -m "build(qinao): apply reviewed imports with destination CAS"
worktree_status="$(git status --porcelain=v1)"
test -z "$worktree_status"
```

Expected: all four modules have positive discovery and pass; exactly two files are committed.

---

### Task 6: Capture and Check In the C0 Provenance Pair

**Files:**
- Create: `scripts/qinao_source_provenance_v1.py`
- Create: `scripts/test_qinao_source_provenance_v1.py`
- Create: `docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/source-inventory.json`
- Create: `docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/import-map.json`

**Interfaces:**
- Consumes: committed C0 tools and the still-preserved dirty source.
- Produces: one canonical source snapshot, one canonical all-hold map, and the
  builder/verifier for the durable `SourceProvenanceV1` handoff committed by
  Task 7. This task imports zero source bytes.

- [ ] **Step 0: Implement and commit the closed provenance-handoff codec**

`scripts/qinao_source_provenance_v1.py` has only `build` and `verify`
subcommands. Its value has exactly the 12 master-owned fields:

```text
schema_version
approved_base_commit
source_head_commit
source_head_tree
source_index_tree
source_status_sha256
staged_patch_sha256
unstaged_patch_sha256
inventory_sha256
approved_import_map_sha256
candidate_destination_tip
candidate_destination_tree
```

`build` requires the permanent root guard, a clean candidate, canonical
inventory/map bytes, an exact-set-valid all-`hold` map, and the absent exact
repository-relative output
`docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/source-provenance-v1.json`.
Any other `--output` spelling is rejected before opening a file.
It copies the seven source identity/digest fields from the verified inventory,
computes the two file digests over their canonical bytes, and records fresh
candidate `HEAD/HEAD^{tree}`. It writes canonical sorted compact UTF-8 JSON
with one LF and no duplicate/unknown field through the same descriptor-walked
candidate-only, source-excluding, parent/final-no-follow,
digest-temporary/no-replace-link, mode-`100644`,
file/directory-`fsync` installer used for the fixed map. It never follows,
partially exposes, or replaces a final leaf.

`verify --handoff-commit <oid>` requires a regular mode-`100644` handoff at the
fixed Git path, exactly one parent equal to `candidate_destination_tip`, that
parent's tree equal to `candidate_destination_tree`, and an exact one-path
parent→commit diff. It reopens inventory/map bytes from that parent, validates
them, recomputes every field, and writes nothing.

Named tests cover closed shape, noncanonical bytes, wrong inventory/map
digest, dirty build, existing output, wrong parent/tree, extra diff, symlink,
mode drift, arbitrary/absolute/source-descendant output, parent-symlink
substitution, and byte-identical rebuild in two disposable repositories.

```bash
set -euo pipefail
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v \
  scripts.test_qinao_source_provenance_v1
git add scripts/qinao_source_provenance_v1.py \
  scripts/test_qinao_source_provenance_v1.py
staged_paths="$(git diff --cached --name-only)"
expected_staged_paths="$(printf '%s\n' \
  scripts/qinao_source_provenance_v1.py \
  scripts/test_qinao_source_provenance_v1.py)"
test "$staged_paths" = "$expected_staged_paths"
git commit -m "build(qinao): define source provenance handoff"
worktree_status="$(git status --porcelain=v1)"
test -z "$worktree_status"
```

Expected: positive test discovery, all cases pass, and exactly two tooling
paths are committed.

- [ ] **Step 1: Generate the canonical inventory at its exact evidence path**

```bash
set -euo pipefail
python3 scripts/capture_qinao_candidate_inventory.py \
  --operation-batch C1 \
  --root /Users/changgeng/Project/Project06/Project06/.worktrees/qinao-w0 \
  --approved-base 59c26f508262d7c25869faac0ec0abf968ec1e02 \
  --output docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/source-inventory.json
python3 scripts/capture_qinao_candidate_inventory.py \
  --operation-batch C1 \
  --root /Users/changgeng/Project/Project06/Project06/.worktrees/qinao-w0 \
  --verify docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/source-inventory.json
```

Expected: both commands print `inventory_status=complete`, `paths` is greater than zero, and `source_unchanged=true`.

- [ ] **Step 1A: Inspect the graph amendment through the generic inventory**

This is a plan-level read-only assertion over the existing inventory schema;
it adds no C0 selector, field, batch, or special import path:

```bash
set -euo pipefail
test "$(git -C /Users/changgeng/Project/Project06/Project06/.worktrees/qinao-w0 rev-parse 9d484befb4a4593d93789457ebddfd7cde358e3b:docs/superpowers/specs/2026-07-24-qinao-dynamic-agent-graph-workflow-design.md)" = e2c59656f9eb184efc3ab933fe442c9dd0b7d507
test "$(git -C /Users/changgeng/Project/Project06/Project06/.worktrees/qinao-w0 show 9d484befb4a4593d93789457ebddfd7cde358e3b:docs/superpowers/specs/2026-07-24-qinao-dynamic-agent-graph-workflow-design.md | shasum -a 256 | awk '{print $1}')" = 5f36d0b04579f805a3a69254325e62e22625f4ddd31663e03cbf78b1a39460d5
python3 - <<'PY'
import base64
import json
from pathlib import Path

inventory_path = Path(
    "docs/superpowers/evidence/qinao-clean-candidate/"
    "2026-07-23-c0/source-inventory.json"
)
inventory = json.loads(inventory_path.read_text(encoding="utf-8"))
required = (
    b"docs/superpowers/specs/2026-07-24-qinao-dynamic-agent-graph-workflow-design.md",
    b"docs/superpowers/plans/2026-07-23-qinao-artifact-mesh-w1-task0.md",
    b"docs/superpowers/plans/2026-07-23-qinao-authority-ledger-and-cw-evidence.md",
    b"docs/superpowers/plans/2026-07-23-qinao-bootstrap-verifier-and-admission-lineage.md",
    b"docs/superpowers/plans/2026-07-23-qinao-c0-provenance-and-safe-import.md",
    b"docs/superpowers/plans/2026-07-23-qinao-clean-candidate-reconstruction-and-controlled-convergence.md",
    b"docs/superpowers/plans/2026-07-23-qinao-w0-safety-and-k4-proof.md",
)
rows = {
    base64.b64decode(row["path_b64"], validate=True): row
    for row in inventory["paths"]
}
assert set(required) <= set(rows)
for raw_path in required:
    row = rows[raw_path]
    head = row["head"]
    index = row["index"]
    worktree = row["worktree"]
    assert head["present"] and head["mode"] == "100644"
    assert index["present"] and index["stage"] == 0 and index["mode"] == "100644"
    assert worktree["present"] and worktree["kind"] == "regular"
    assert worktree["mode"] == "100644"
    assert head["sha256"] == index["sha256"] == worktree["sha256"]
    assert row["status_xy"] in (None, "  ")
assert (
    rows[required[0]]["head"]["git_oid"]
    == "e2c59656f9eb184efc3ab933fe442c9dd0b7d507"
)
print("dynamic_graph_inventory_status=verified paths=7")
PY
```

Expected: both immutable spec-pin checks exit 0 and the generic inventory
assertion prints exactly
`dynamic_graph_inventory_status=verified paths=7`. A missing path, dirty
plan, wrong mode, spec substitution, or HEAD/index/worktree mismatch stops
C0. The generic stable-double-read test already proves that a byte changed
between captures is `source_drift`; no graph-specific production code is
added.

- [ ] **Step 2: Generate the initial map with no selected byte**

```bash
set -euo pipefail
python3 scripts/build_qinao_import_map.py \
  --inventory docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/source-inventory.json \
  --candidate-base 59c26f508262d7c25869faac0ec0abf968ec1e02 \
  --output docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/import-map.json
python3 scripts/check_qinao_import_map.py \
  --operation-batch C1 \
  --inventory docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/source-inventory.json \
  --map docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/import-map.json
python3 - <<'PY'
import base64
import json
from pathlib import Path

root = Path("docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0")
inventory = json.loads((root / "source-inventory.json").read_text(encoding="utf-8"))
mapping = json.loads((root / "import-map.json").read_text(encoding="utf-8"))
required = (
    b"docs/superpowers/specs/2026-07-24-qinao-dynamic-agent-graph-workflow-design.md",
    b"docs/superpowers/plans/2026-07-23-qinao-artifact-mesh-w1-task0.md",
    b"docs/superpowers/plans/2026-07-23-qinao-authority-ledger-and-cw-evidence.md",
    b"docs/superpowers/plans/2026-07-23-qinao-bootstrap-verifier-and-admission-lineage.md",
    b"docs/superpowers/plans/2026-07-23-qinao-c0-provenance-and-safe-import.md",
    b"docs/superpowers/plans/2026-07-23-qinao-clean-candidate-reconstruction-and-controlled-convergence.md",
    b"docs/superpowers/plans/2026-07-23-qinao-w0-safety-and-k4-proof.md",
)
inventory_rows = {
    base64.b64decode(row["path_b64"], validate=True): row
    for row in inventory["paths"]
}
map_rows = {
    base64.b64decode(row["path_b64"], validate=True): row
    for row in mapping["rows"]
}
assert set(required) <= set(inventory_rows) == set(map_rows)
for raw_path in required:
    source = inventory_rows[raw_path]
    assert source["head"]["present"] and source["head"]["mode"] == "100644"
    assert (
        source["index"]["present"]
        and source["index"]["stage"] == 0
        and source["index"]["mode"] == "100644"
    )
    assert (
        source["worktree"]["present"]
        and source["worktree"]["kind"] == "regular"
        and source["worktree"]["mode"] == "100644"
    )
    assert (
        source["head"]["sha256"]
        == source["index"]["sha256"]
        == source["worktree"]["sha256"]
    )
    assert source["status_xy"] in (None, "  ")
    assert map_rows[raw_path]["decision"] == "hold"
    assert map_rows[raw_path]["destination_batch"] == "hold"
assert (
    inventory_rows[required[0]]["head"]["git_oid"]
    == "e2c59656f9eb184efc3ab933fe442c9dd0b7d507"
)
assert all(row["decision"] == "hold" for row in mapping["rows"])
assert not any(row["destination_batch"] == "C1" for row in mapping["rows"])
print("dynamic_graph_c0_handoff_status=verified paths=7 c1=0")
PY
```

Expected: `import_map_status=valid`, `import=0`, `omit=0`, and `hold` equals the inventory path count.

- [ ] **Step 3: Re-open and verify both generated evidence files**

```bash
set -euo pipefail
python3 scripts/capture_qinao_candidate_inventory.py \
  --operation-batch C1 \
  --root /Users/changgeng/Project/Project06/Project06/.worktrees/qinao-w0 \
  --verify docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/source-inventory.json
python3 scripts/check_qinao_import_map.py \
  --operation-batch C1 \
  --inventory docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/source-inventory.json \
  --map docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/import-map.json
```

Expected: both checks pass. The two evidence files contain metadata/digests only; no raw source, secret, device identifier, archive, database, trace, or model package is embedded.

- [ ] **Step 4: Commit only the evidence pair**

```bash
set -euo pipefail
git add \
  docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/source-inventory.json \
  docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/import-map.json
staged_paths="$(git diff --cached --name-only)"
expected_staged_paths="$(printf '%s\n' \
  docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/import-map.json \
  docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/source-inventory.json)"
test "$staged_paths" = "$expected_staged_paths"
git commit -m "docs(qinao): bind c0 source provenance"
worktree_status="$(git status --porcelain=v1)"
test -z "$worktree_status"
```

Expected: exactly two files are committed and the candidate is clean.

---

### Task 7: Prove Hold-by-Default and Hand Off the Import Protocol

**Files:**
- Verify only: `docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/import-map.json`
- Create: `docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/source-provenance-v1.json`
- Create only outside Git during the negative probe: `/private/tmp/qinao-c0-empty-apply-plan.json`

**Interfaces:**
- Produces: a completed C0 mechanism with zero real source imports and one
  durable canonical `SourceProvenanceV1` handoff.
- Later owning plans may review rows and invoke the same tool; this C0 plan does not choose or import authority, production, K4, admission, or Artifact Mesh bytes.

- [ ] **Step 0: Reopen the exact committed graph source state**

```bash
set -euo pipefail
test "$(git -C /Users/changgeng/Project/Project06/Project06/.worktrees/qinao-w0 rev-parse 9d484befb4a4593d93789457ebddfd7cde358e3b:docs/superpowers/specs/2026-07-24-qinao-dynamic-agent-graph-workflow-design.md)" = e2c59656f9eb184efc3ab933fe442c9dd0b7d507
test "$(git -C /Users/changgeng/Project/Project06/Project06/.worktrees/qinao-w0 show 9d484befb4a4593d93789457ebddfd7cde358e3b:docs/superpowers/specs/2026-07-24-qinao-dynamic-agent-graph-workflow-design.md | shasum -a 256 | awk '{print $1}')" = 5f36d0b04579f805a3a69254325e62e22625f4ddd31663e03cbf78b1a39460d5
python3 scripts/capture_qinao_candidate_inventory.py \
  --operation-batch C1 \
  --root /Users/changgeng/Project/Project06/Project06/.worktrees/qinao-w0 \
  --verify docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/source-inventory.json
python3 scripts/check_qinao_import_map.py \
  --operation-batch C1 \
  --inventory docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/source-inventory.json \
  --map docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/import-map.json
python3 - <<'PY'
import base64
import json
from pathlib import Path

root = Path("docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0")
inventory = json.loads((root / "source-inventory.json").read_text(encoding="utf-8"))
mapping = json.loads((root / "import-map.json").read_text(encoding="utf-8"))
required = (
    b"docs/superpowers/specs/2026-07-24-qinao-dynamic-agent-graph-workflow-design.md",
    b"docs/superpowers/plans/2026-07-23-qinao-artifact-mesh-w1-task0.md",
    b"docs/superpowers/plans/2026-07-23-qinao-authority-ledger-and-cw-evidence.md",
    b"docs/superpowers/plans/2026-07-23-qinao-bootstrap-verifier-and-admission-lineage.md",
    b"docs/superpowers/plans/2026-07-23-qinao-c0-provenance-and-safe-import.md",
    b"docs/superpowers/plans/2026-07-23-qinao-clean-candidate-reconstruction-and-controlled-convergence.md",
    b"docs/superpowers/plans/2026-07-23-qinao-w0-safety-and-k4-proof.md",
)
inventory_rows = {
    base64.b64decode(row["path_b64"], validate=True): row
    for row in inventory["paths"]
}
map_rows = {
    base64.b64decode(row["path_b64"], validate=True): row
    for row in mapping["rows"]
}
assert set(required) <= set(inventory_rows) == set(map_rows)
for raw_path in required:
    source = inventory_rows[raw_path]
    assert source["head"]["present"] and source["head"]["mode"] == "100644"
    assert (
        source["index"]["present"]
        and source["index"]["stage"] == 0
        and source["index"]["mode"] == "100644"
    )
    assert (
        source["worktree"]["present"]
        and source["worktree"]["kind"] == "regular"
        and source["worktree"]["mode"] == "100644"
    )
    assert (
        source["head"]["sha256"]
        == source["index"]["sha256"]
        == source["worktree"]["sha256"]
    )
    assert source["status_xy"] in (None, "  ")
    assert map_rows[raw_path]["decision"] == "hold"
    assert map_rows[raw_path]["destination_batch"] == "hold"
assert (
    inventory_rows[required[0]]["head"]["git_oid"]
    == "e2c59656f9eb184efc3ab933fe442c9dd0b7d507"
)
assert all(row["decision"] == "hold" for row in mapping["rows"])
assert not any(row["destination_batch"] == "C1" for row in mapping["rows"])
print("dynamic_graph_c0_handoff_status=verified paths=7 c1=0")
PY
```

Expected: both independent spec-pin checks exit 0; inventory verification
positively discovers the six committed clean plan paths plus the spec; the
initial map reports `import=0`, `omit=0`, and no C1 row; the final assertion
prints `dynamic_graph_c0_handoff_status=verified paths=7 c1=0`. This is the
post-six-plan-amendment source state. A missing/dirty plan, changed spec,
selected graph row, or substituted pin stops C0 before handoff.

- [ ] **Step 1: Prove every initial decision remains canonical `hold`**

```bash
set -euo pipefail
python3 - <<'PY'
import json
from pathlib import Path

path = Path(
    "docs/superpowers/evidence/qinao-clean-candidate/"
    "2026-07-23-c0/import-map.json"
)
mapping = json.loads(path.read_text(encoding="utf-8"))
rows = mapping["rows"]
assert rows
assert all(
    row["decision"] == "hold"
    and row["source_stratum"] is None
    and row["source_sha256"] is None
    and row["source_mode"] is None
    and row["destination_batch"] == "hold"
    and row["rationale"] == "unreviewed"
    and row["review_record_digest"] is None
    and row["reviewer_identity_digest"] is None
    and row["reviewed_at"] is None
    for row in rows
)
print(f"hold_default_status=verified rows={len(rows)}")
PY
```

Expected: positive row count and `hold_default_status=verified`.

- [ ] **Step 2: Prove zero-row real batches fail without touching candidate state**

```bash
set -euo pipefail
worktree_status_before="$(git status --porcelain=v1)"
test -z "$worktree_status_before"
set +e
prepare_diagnostic="$(python3 scripts/apply_qinao_import_map.py \
  --candidate-root /Users/changgeng/.codex/worktrees/e4d7/Project06 \
  --source-root /Users/changgeng/Project/Project06/Project06/.worktrees/qinao-w0 \
  --inventory docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/source-inventory.json \
  --map docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/import-map.json \
  --prepare-batch C1 \
  --output-plan /private/tmp/qinao-c0-empty-apply-plan.json 2>&1)"
prepare_rc=$?
set -euo pipefail
test "$prepare_rc" -eq 1
case "$prepare_diagnostic" in
  *"batch C1 has zero reviewed imports"*) ;;
  *)
    printf '%s\n' "$prepare_diagnostic" >&2
    exit 1
    ;;
esac
test ! -e /private/tmp/qinao-c0-empty-apply-plan.json
worktree_status_after="$(git status --porcelain=v1)"
test -z "$worktree_status_after"
```

Expected: preparation exits non-zero with `batch C1 has zero reviewed imports`; no plan file, index change, worktree change, or source change exists.

- [ ] **Step 3: Run the positive import path only in disposable test repositories**

```bash
set -euo pipefail
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v \
  scripts.test_apply_qinao_import_map.ApplyQinaoImportMapTests.test_prepare_is_read_only_and_binds_head_tree_index_status_and_preimages \
  scripts.test_apply_qinao_import_map.ApplyQinaoImportMapTests.test_apply_imports_regular_executable_symlink_and_deletion_exactly \
  scripts.test_apply_qinao_import_map.ApplyQinaoImportMapTests.test_apply_rejects_changed_head_tree_or_map \
  scripts.test_apply_qinao_import_map.ApplyQinaoImportMapTests.test_apply_rejects_intervening_unstaged_or_untracked_edit \
  scripts.test_apply_qinao_import_map.ApplyQinaoImportMapTests.test_apply_rejects_source_drift_after_plan \
  scripts.test_apply_qinao_import_map.ApplyQinaoImportMapTests.test_apply_rejects_destination_symlink_substitution \
  scripts.test_apply_qinao_import_map.ApplyQinaoImportMapTests.test_apply_failure_leaves_no_partial_index_or_worktree_change
```

Expected: exactly seven requested methods run and pass. Their temporary repositories prove real regular/executable/symlink/deletion application and all stale-state failures without importing a byte into the adopted candidate.

- [ ] **Step 4: Freeze the later-plan handoff contract**

A later owning plan must perform these actions in order:

1. compare the exact selected source bytes from one frozen inventory stratum;
2. place only the owning plan's exact proposed `omit`/`import` decision rows
   in Bootstrap's fixed batch proposal cache; do not edit the map;
3. for a proposed import, copy `source_sha256` and `source_mode` from the
   selected stratum rather than typing them independently; for a proposed
   omit, require the canonical null source triple and `destination_batch =
   hold`;
4. after Bootstrap Task 1A exists, verify the code-owned fixed
   `ImportReviewV1` export for that exact batch against its external trust
   anchor, immutable reopen receipt, and review-preimage candidate context,
   yielding only the opaque `VerifiedImportReviewV1`;
5. invoke only Bootstrap's fixed-batch, no-path
   `--apply-fixed-map-postimage C1|C2|C3` materializer; it derives
   `review_record_digest`, `reviewer_identity_digest`, and `reviewed_at`
   inside the opaque verifier process and atomically writes only the uniquely
   signed map postimage—an agent, model, console transcript, or import tool
   cannot invent or copy any of those values;
6. run the Bootstrap-extended map checker in preapply mode, commit exactly the
   one map path as the immediate child of the bound context HEAD, and rerun
   the checker in postcommit/reopen mode to prove the unique earliest
   first-parent map-only introduction;
7. require the verified record and append-only reopen receipt still
   authenticate after that commit;
8. prepare a fresh ephemeral apply plan for one non-empty batch;
9. independently inspect its HEAD/tree/index/status and per-path preimages;
10. apply it before any intervening edit;
11. compare the staged path set with the decoded plan paths; and
12. commit only those exact paths; and
13. run `--finalize-plan` against that immutable plan, require the exact
    one-parent committed postimage, and reopen the byte-identical receipt
    before starting another batch.

If any row remains `hold`, no command may import it. Before a journal exists,
a stale plan is discarded and freshly prepared; it is never edited to match a
newer tree. After the journal is durable, the transaction must be recovered
or quarantined—never discarded, overwritten, or bypassed. A finalized batch
cannot block the next batch, and a crash after journal unlink but before
stdout still reopens the exact committed postimage and returns the same
receipt.

- [ ] **Step 5: Materialize and commit the exact C0 handoff**

Require a clean tree whose `HEAD` is the Task-6 evidence-pair commit, then run:

```bash
set -euo pipefail
worktree_status_before="$(git status --porcelain=v1)"
test -z "$worktree_status_before"
C0_DESTINATION_TIP="$(git rev-parse HEAD)"
C0_DESTINATION_TREE="$(git rev-parse HEAD^{tree})"
python3 scripts/qinao_source_provenance_v1.py build \
  --root /Users/changgeng/.codex/worktrees/e4d7/Project06 \
  --inventory docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/source-inventory.json \
  --map docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/import-map.json \
  --output docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/source-provenance-v1.json
git add docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/source-provenance-v1.json
staged_paths="$(git diff --cached --name-only)"
test "$staged_paths" = \
  docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/source-provenance-v1.json
git commit -m "docs(qinao): seal c0 source provenance handoff"
test "$(git rev-parse HEAD^)" = "$C0_DESTINATION_TIP"
test "$(git rev-parse HEAD^^{tree})" = "$C0_DESTINATION_TREE"
python3 scripts/qinao_source_provenance_v1.py verify \
  --root /Users/changgeng/.codex/worktrees/e4d7/Project06 \
  --handoff-commit "$(git rev-parse HEAD)"
worktree_status_after="$(git status --porcelain=v1)"
test -z "$worktree_status_after"
```

Expected: the final C0 commit changes exactly the one handoff path; its
canonical fields bind the exact source inventory, all-hold map, and sole
parent candidate tip/tree. It carries no raw source or admission claim.

---

## C0 Completion Gate

Run from `/Users/changgeng/.codex/worktrees/e4d7/Project06`:

```bash
set -euo pipefail
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v \
  scripts.test_qinao_execution_root \
  scripts.test_capture_qinao_candidate_inventory \
  scripts.test_qinao_import_map \
  scripts.test_apply_qinao_import_map \
  scripts.test_qinao_source_provenance_v1 \
  scripts.test_check_qinao_wave_admission \
  scripts.test_check_qinao_owner_ledger
python3 scripts/capture_qinao_candidate_inventory.py \
  --operation-batch C1 \
  --root /Users/changgeng/Project/Project06/Project06/.worktrees/qinao-w0 \
  --verify docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/source-inventory.json
python3 scripts/check_qinao_import_map.py \
  --operation-batch C1 \
  --inventory docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/source-inventory.json \
  --map docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/import-map.json
python3 scripts/qinao_source_provenance_v1.py verify \
  --root /Users/changgeng/.codex/worktrees/e4d7/Project06 \
  --handoff-commit "$(git rev-parse HEAD)"
git diff --check
worktree_status="$(git status --porcelain=v1)"
test -z "$worktree_status"
git merge-base --is-ancestor \
  59c26f508262d7c25869faac0ec0abf968ec1e02 HEAD
git merge-base --is-ancestor \
  486e1ec5983ad4390c5b07f04607f1345b912c4c HEAD
test "$(git -C /Users/changgeng/Project/Project06/Project06/.worktrees/qinao-w0 rev-parse 9d484befb4a4593d93789457ebddfd7cde358e3b:docs/superpowers/specs/2026-07-24-qinao-dynamic-agent-graph-workflow-design.md)" = e2c59656f9eb184efc3ab933fe442c9dd0b7d507
test "$(git -C /Users/changgeng/Project/Project06/Project06/.worktrees/qinao-w0 show 9d484befb4a4593d93789457ebddfd7cde358e3b:docs/superpowers/specs/2026-07-24-qinao-dynamic-agent-graph-workflow-design.md | shasum -a 256 | awk '{print $1}')" = 5f36d0b04579f805a3a69254325e62e22625f4ddd31663e03cbf78b1a39460d5
python3 - <<'PY'
import base64
import json
from pathlib import Path

root = Path("docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0")
inventory = json.loads((root / "source-inventory.json").read_text(encoding="utf-8"))
mapping = json.loads((root / "import-map.json").read_text(encoding="utf-8"))
required = (
    b"docs/superpowers/specs/2026-07-24-qinao-dynamic-agent-graph-workflow-design.md",
    b"docs/superpowers/plans/2026-07-23-qinao-artifact-mesh-w1-task0.md",
    b"docs/superpowers/plans/2026-07-23-qinao-authority-ledger-and-cw-evidence.md",
    b"docs/superpowers/plans/2026-07-23-qinao-bootstrap-verifier-and-admission-lineage.md",
    b"docs/superpowers/plans/2026-07-23-qinao-c0-provenance-and-safe-import.md",
    b"docs/superpowers/plans/2026-07-23-qinao-clean-candidate-reconstruction-and-controlled-convergence.md",
    b"docs/superpowers/plans/2026-07-23-qinao-w0-safety-and-k4-proof.md",
)
inventory_rows = {
    base64.b64decode(row["path_b64"], validate=True): row
    for row in inventory["paths"]
}
map_rows = {
    base64.b64decode(row["path_b64"], validate=True): row
    for row in mapping["rows"]
}
assert set(required) <= set(inventory_rows) == set(map_rows)
for raw_path in required:
    source = inventory_rows[raw_path]
    assert source["head"]["present"] and source["head"]["mode"] == "100644"
    assert (
        source["index"]["present"]
        and source["index"]["stage"] == 0
        and source["index"]["mode"] == "100644"
    )
    assert (
        source["worktree"]["present"]
        and source["worktree"]["kind"] == "regular"
        and source["worktree"]["mode"] == "100644"
    )
    assert (
        source["head"]["sha256"]
        == source["index"]["sha256"]
        == source["worktree"]["sha256"]
    )
    assert source["status_xy"] in (None, "  ")
    assert map_rows[raw_path]["decision"] == "hold"
    assert map_rows[raw_path]["destination_batch"] == "hold"
assert (
    inventory_rows[required[0]]["head"]["git_oid"]
    == "e2c59656f9eb184efc3ab933fe442c9dd0b7d507"
)
assert all(row["decision"] == "hold" for row in mapping["rows"])
assert not any(row["destination_batch"] == "C1" for row in mapping["rows"])
print("dynamic_graph_c0_completion_status=verified paths=7 c1=0")
PY
```

Expected:

- every test module has positive discovery and passes;
- source inventory still byte-matches the preserved source;
- import map is exact-set valid;
- all six amended plan HEAD rows are committed/clean, the pinned graph spec
  matches commit/blob/SHA-256, and the actual C0 map still has zero C1 rows;
- `SourceProvenanceV1` reopens from the final one-path C0 handoff commit and
  byte-matches its sole parent, inventory, and all-hold map;
- no unreviewed row was imported;
- no source HEAD/index/status/file byte changed;
- no candidate edit was overwritten;
- candidate status is empty after each committed slice;
- through the end of C0, the approved base and audited 22-commit tip remain ancestors; the later Bootstrap Task 10 reparent transaction may supersede only this phase-scoped ancestry condition after both create-once forensic refs exist;
- C0 makes no admission, authority, K4, Artifact Mesh, protected-ref, performance, or completion claim.

## Self-Review Results

- [x] The plan adopts the existing candidate and never creates a second worktree.
- [x] The exact root, branch, base, audited tip, existing dirty path, and pre-repair patch digest are frozen.
- [x] The baseline fix distinguishes a final symlink from a parent-component symlink.
- [x] Every mutating tool has a permanent candidate-root/branch/ancestry/CWD guard.
- [x] Git environment overrides, replace refs, grafts, shallow ancestry,
  symbolic forensic refs, wrong branch, and source/candidate confusion fail
  closed.
- [x] Source inventory is read-only and uses a copied index plus temporary object directory for `write-tree`.
- [x] Full stable double-read covers HEAD, tree, branch, index bytes/tree/entries, status, staged patch, unstaged patch, all selected Git blobs, and filesystem bytes/modes.
- [x] Plan-level read-only assertions reopen the generic stable inventory,
  bind the graph commit/path/blob/SHA-256, and require all six amended plan
  paths to be committed, clean, regular mode-`100644`
  HEAD/index/worktree peers without changing C0 semantics.
- [x] Base, HEAD, index, worktree, untracked, deletion, executable, safe symlink, special-file, and non-UTF-8 path behavior has named tests.
- [x] Raw path bytes, not lossy display strings, are the identity and sort key.
- [x] Every map row begins at `hold`; no tool chooses a source stratum, batch,
  rationale, reviewer identity, or review timestamp.
- [x] C0's actual map has zero selected C1 rows and keeps the graph spec plus
  six plans held; only Bootstrap Task 1A may later freeze the sole fixed
  ten-row C1 context, so C0 cannot create row eleven or refreeze C1.
- [x] Imported rows bind exact source digest/mode; deletion is a real absent postimage.
- [x] Raw private C4 classes and production-before-C3 selections fail.
- [x] The checked-in map avoids destination self-reference; the separate ephemeral apply plan binds the live destination HEAD/tree/index/status and per-path preimages.
- [x] `git apply --index --binary` verifies index/worktree preimages and stages only the exact reviewed set.
- [x] A kernel lock plus fsynced per-worktree journal makes preimage,
  staged-postimage, committed-postimage, lost-reply, and next-batch recovery
  deterministic; divergence never invokes reset or blind replay.
- [x] Source drift, destination drift, symlink substitution, stale map/plan, partial path set, and zero-row batch all fail.
- [x] Tooling, evidence, review decisions, and imported batches use isolated exact-path commits.
- [x] The final C0 handoff is durable canonical JSON whose one-path commit
  binds its sole parent candidate tip/tree without self-reference.
- [x] The plan uses only Python standard library and `unittest`.
- [x] B0/admission, authority convergence, K4, Artifact Mesh, and later-wave implementation remain outside this child plan.
