# Qinao C0 Provenance and Safe Import Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Repair and preserve the adopted 22-commit clean-candidate lineage, then add a read-only, byte-exact provenance and reviewed-import mechanism that cannot mutate the dirty source or overwrite an intervening clean-candidate edit.

**Architecture:** C0 has two immutable roles. The dirty source worktree is evidence only: a stable double-read inventories its base, HEAD, index, worktree, untracked, deletion, mode, symlink, and non-UTF-8 path strata without writing its index, refs, object database, or files. The adopted clean candidate is the only execution root: an exact root/branch/ancestry guard protects every mutating command, an all-`hold` import map requires an explicit source stratum for every imported row, and a separate ephemeral apply plan binds the destination HEAD/tree/index plus every touched preimage before `git apply --index` performs the reviewed change.

**Tech Stack:** Git object/index plumbing, Python 3 standard library only, `unittest`, canonical JSON, SHA-256, `os.lstat`/`O_NOFOLLOW`, temporary indexes, and Git binary patches.

## Global Constraints

- Approved design commit: `59c26f508262d7c25869faac0ec0abf968ec1e02`.
- Approved design path: `docs/superpowers/specs/2026-07-23-qinao-convergence-correction-and-clean-candidate-design.md`.
- Approved design SHA-256: `3af1067ad2c3d37c36d7613ad19d1dd035bb6f1c60f06b75d5d71de22874d1b4`.
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
- `candidate_base_commit` in the reviewed map records the immutable approved reconstruction base. It does not pretend to be the later destination CAS.
- Every apply operation first creates an ephemeral apply-plan JSON. That plan binds the current candidate HEAD, HEAD tree, index tree, clean-status digest, import-map digest, inventory digest, batch, selected rows, and exact destination preimages.
- Apply rejects a changed HEAD/tree/index/status, changed map/inventory, changed source byte/mode, missing or new destination path, destination symlink, or any unstaged/untracked/intervening edit.
- Apply uses a temporary index to construct a full-index binary patch and `git apply --index --binary`; it never copies a directory, chooses “latest,” follows a symlink, or overwrites a mismatched preimage.
- No C0 tool creates or changes B0/admission authority, controlled authority text, K4 evidence, Artifact Mesh, production code, a protected ref, or an external attestation.
- Stage exact paths only. Each commit step compares the staged path set before committing.

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
test "$(pwd -P)" = /Users/changgeng/.codex/worktrees/e4d7/Project06
test "$(git branch --show-current)" = codex/qinao-w1-clean-candidate
test "$(git rev-parse HEAD)" = 486e1ec5983ad4390c5b07f04607f1345b912c4c
test "$(git rev-list --count 59c26f508262d7c25869faac0ec0abf968ec1e02..HEAD)" = 22
test "$(git status --short)" = " M scripts/check_qinao_owner_ledger.py"
test "$(git diff --binary -- scripts/check_qinao_owner_ledger.py | shasum -a 256 | awk '{print $1}')" = ca122962ca9f198b8a951cd04696b0bdd7c780c8b7c190f922942826ef677f8d
```

Expected: every assertion exits 0. Any mismatch is a stop; do not “repair” it with reset, checkout, or force.

- [ ] **Step 2: Reproduce the one known RED and the green admission suite**

```bash
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v \
  scripts.test_check_qinao_wave_admission
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v \
  scripts.test_check_qinao_owner_ledger
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
git add scripts/check_qinao_owner_ledger.py
test "$(git diff --cached --name-only)" = scripts/check_qinao_owner_ledger.py
git commit -m "fix(qinao): preserve owner ledger symlink diagnostics"
test "$(git rev-parse HEAD^)" = 486e1ec5983ad4390c5b07f04607f1345b912c4c
git merge-base --is-ancestor \
  486e1ec5983ad4390c5b07f04607f1345b912c4c HEAD
test -z "$(git status --porcelain=v1)"
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
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v \
  scripts.test_qinao_execution_root
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
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v \
  scripts.test_qinao_execution_root
PYTHONDONTWRITEBYTECODE=1 python3 scripts/qinao_execution_root.py \
  --root /Users/changgeng/.codex/worktrees/e4d7/Project06 \
  --expect-candidate-lineage prebootstrapPreparation \
  --require-clean
git diff --check
git add scripts/qinao_execution_root.py \
  scripts/test_qinao_execution_root.py
test "$(git diff --cached --name-only)" = "$(printf '%s\n' \
  scripts/qinao_execution_root.py \
  scripts/test_qinao_execution_root.py)"
git commit -m "build(qinao): guard clean candidate execution root"
test -z "$(git status --porcelain=v1)"
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
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v \
  scripts.test_capture_qinao_candidate_inventory
```

Expected: the module imports, every method is discovered, and capture cases fail with the typed `SourceInventoryError` RED. Syntax/import errors do not count as RED.

- [ ] **Step 3: Implement raw-path and no-follow filesystem primitives**

Create `scripts/capture_qinao_candidate_inventory.py` and add these exact primitives:

```python
from __future__ import annotations

import argparse
import base64
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import posixpath
import shutil
import stat
import tempfile
from typing import Callable

from scripts.qinao_execution_root import (
    CandidateLineage,
    DEFAULT_CONTRACT,
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


def _abs_bytes(root: Path, path: bytes) -> bytes:
    _validate_raw_path(path)
    return os.path.join(os.fsencode(str(root)), *path.split(b"/"))


def _check_parent_components(root: Path, path: bytes) -> None:
    current = os.fsencode(str(root))
    for component in path.split(b"/")[:-1]:
        current = os.path.join(current, component)
        try:
            mode = os.lstat(current).st_mode
        except FileNotFoundError:
            return
        if stat.S_ISLNK(mode):
            raise SourceInventoryError(
                f"parent-component symlink is forbidden: {_display_path(path)}"
            )


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
    _check_parent_components(root, path)
    absolute = _abs_bytes(root, path)
    try:
        metadata = os.lstat(absolute)
    except FileNotFoundError:
        return {
            "present": False,
            "kind": None,
            "mode": None,
            "size": None,
            "sha256": None,
        }
    if stat.S_ISLNK(metadata.st_mode):
        target = os.readlink(absolute)
        if isinstance(target, str):
            target = os.fsencode(target)
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
    descriptor = os.open(absolute, os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0))
    try:
        opened = os.fstat(descriptor)
        if not stat.S_ISREG(opened.st_mode):
            raise SourceInventoryError(
                f"file changed type while reading: {_display_path(path)}"
            )
        chunks: list[bytes] = []
        while True:
            chunk = os.read(descriptor, 1024 * 1024)
            if not chunk:
                break
            chunks.append(chunk)
        value = b"".join(chunks)
        closed_check = os.lstat(absolute)
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
    mode = "100755" if opened.st_mode & 0o111 else "100644"
    return {
        "present": True,
        "kind": "regular",
        "mode": mode,
        "size": len(value),
        "sha256": _sha256(value),
    }
```

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

The CLI must require candidate CWD, accept exactly one of `--output` or `--verify`, and never write under the source root:

```python
def _load_json(path: Path) -> dict[str, object]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise SourceInventoryError("inventory JSON must be an object")
    return value


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--approved-base")
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--output", type=Path)
    group.add_argument("--verify", type=Path)
    arguments = parser.parse_args()
    candidate = require_candidate_root(
        Path.cwd(),
        require_clean=False,
        expected_lineage=CandidateLineage.PREBOOTSTRAP_PREPARATION,
    )
    if arguments.verify is not None:
        value = _load_json(arguments.verify)
        verify_inventory(root=arguments.root, inventory=value)
        print(
            f"inventory_status=complete paths={len(value['paths'])} "
            "source_unchanged=true"
        )
        return 0
    if arguments.approved_base is None:
        parser.error("--approved-base is required with --output")
    captured_at = (
        datetime.now(timezone.utc)
        .replace(microsecond=0)
        .isoformat()
        .replace("+00:00", "Z")
    )
    value = capture_inventory(
        root=arguments.root,
        approved_base_commit=arguments.approved_base,
        capture_tool_commit=candidate.head_commit,
        captured_at=captured_at,
    )
    output = arguments.output.resolve(strict=False)
    source = arguments.root.resolve(strict=True)
    if output == source or source in output.parents:
        raise SourceInventoryError("inventory output cannot be inside source root")
    output.parent.mkdir(parents=True, exist_ok=True)
    temporary = output.with_name(f".{output.name}.tmp-{os.getpid()}")
    temporary.write_bytes(canonical_json_bytes(value))
    os.replace(temporary, output)
    print(
        f"inventory_status=complete paths={len(value['paths'])} "
        "source_unchanged=true"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
```

- [ ] **Step 7: Run, inspect, and commit the inventory tool**

```bash
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v \
  scripts.test_qinao_execution_root \
  scripts.test_capture_qinao_candidate_inventory
git diff --check
git add scripts/capture_qinao_candidate_inventory.py \
  scripts/test_capture_qinao_candidate_inventory.py
test "$(git diff --cached --name-only)" = "$(printf '%s\n' \
  scripts/capture_qinao_candidate_inventory.py \
  scripts/test_capture_qinao_candidate_inventory.py)"
git commit -m "build(qinao): capture stable source provenance"
test -z "$(git status --porcelain=v1)"
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

- [ ] **Step 2: Run RED**

```bash
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v \
  scripts.test_qinao_import_map
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

from scripts.capture_qinao_candidate_inventory import canonical_json_bytes
from scripts.qinao_execution_root import CandidateLineage, require_candidate_root


def build_hold_map(
    inventory: dict[str, object],
    candidate_base_commit: str,
) -> dict[str, object]:
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
    inventory = json.loads(arguments.inventory.read_text(encoding="utf-8"))
    mapping = build_hold_map(inventory, arguments.candidate_base)
    arguments.output.write_bytes(canonical_json_bytes(mapping))
    print(f"import_map_status=hold rows={len(mapping['rows'])}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
```

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

from scripts.capture_qinao_candidate_inventory import canonical_json_bytes
from scripts.qinao_execution_root import CandidateLineage, require_candidate_root


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
    arguments = parser.parse_args()
    require_candidate_root(
        Path.cwd(),
        require_clean=False,
        expected_lineage=CandidateLineage.PREBOOTSTRAP_PREPARATION,
    )
    inventory = json.loads(arguments.inventory.read_text(encoding="utf-8"))
    mapping = json.loads(arguments.map.read_text(encoding="utf-8"))
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

- [ ] **Step 5: Run and commit the map tools**

```bash
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v \
  scripts.test_qinao_import_map
git diff --check
git add scripts/build_qinao_import_map.py \
  scripts/check_qinao_import_map.py \
  scripts/test_qinao_import_map.py
test "$(git diff --cached --name-only)" = "$(printf '%s\n' \
  scripts/build_qinao_import_map.py \
  scripts/check_qinao_import_map.py \
  scripts/test_qinao_import_map.py)"
git commit -m "build(qinao): require reviewed source strata"
test -z "$(git status --porcelain=v1)"
```

Expected: all tests pass; exactly three files are committed.

---

### Task 5: Prepare and Apply a Destination-CAS Import Plan

**Files:**
- Create: `scripts/apply_qinao_import_map.py`
- Create: `scripts/test_apply_qinao_import_map.py`

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

- [ ] **Step 2: Run RED**

```bash
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v \
  scripts.test_apply_qinao_import_map
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
import hashlib
import json
import os
from pathlib import Path
import shutil
import stat
import tempfile
from typing import Iterator

from scripts.capture_qinao_candidate_inventory import (
    _index_tree_without_source_write,
    canonical_json_bytes,
    verify_inventory,
)
from scripts.check_qinao_import_map import validate_import_map
from scripts.qinao_execution_root import (
    CandidateLineage,
    RootIdentity,
    RootGuardError,
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


def _require_clean_candidate(root: Path) -> RootIdentity:
    try:
        return require_candidate_root(
            root,
            require_clean=True,
            expected_lineage=CandidateLineage.PREBOOTSTRAP_PREPARATION,
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
    candidate = _require_clean_candidate(candidate_root)
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
    absolute = os.path.join(os.fsencode(str(root)), *raw_path.split(b"/"))
    metadata = os.lstat(absolute)
    if mode == "120000":
        if not stat.S_ISLNK(metadata.st_mode):
            raise SafeImportError(f"source symlink changed type: {raw_path!r}")
        target = os.readlink(absolute)
        return target if isinstance(target, bytes) else os.fsencode(target)
    if not stat.S_ISREG(metadata.st_mode):
        raise SafeImportError(f"source regular file changed type: {raw_path!r}")
    descriptor = os.open(absolute, os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0))
    try:
        chunks: list[bytes] = []
        while True:
            chunk = os.read(descriptor, 1024 * 1024)
            if not chunk:
                break
            chunks.append(chunk)
        return b"".join(chunks)
    finally:
        os.close(descriptor)


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
    identity = _require_clean_candidate(root)
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
def _import_lock(root: Path, plan: ApplyPlan) -> Iterator[None]:
    git_dir = Path(
        run_git(root, "rev-parse", "--absolute-git-dir")
        .stdout.decode("utf-8")
        .strip()
    )
    lock = git_dir / "qinao-reviewed-import.lock"
    try:
        descriptor = os.open(
            lock,
            os.O_WRONLY | os.O_CREAT | os.O_EXCL,
            0o600,
        )
    except FileExistsError as error:
        raise SafeImportError(
            f"reviewed-import lock already exists: {lock}"
        ) from error
    try:
        os.write(
            descriptor,
            canonical_json_bytes(
                {
                    "candidate_head_commit": plan.candidate_head_commit,
                    "candidate_head_tree": plan.candidate_head_tree,
                    "import_map_sha256": plan.import_map_sha256,
                    "destination_batch": plan.destination_batch,
                }
            ),
        )
        os.fsync(descriptor)
        yield
    finally:
        os.close(descriptor)
        lock.unlink(missing_ok=True)
```

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


def apply_reviewed_imports(
    *,
    candidate_root: Path,
    source_root: Path,
    inventory: dict[str, object],
    mapping: dict[str, object],
    plan: ApplyPlan,
) -> dict[str, object]:
    errors = validate_import_map(inventory, mapping)
    if errors:
        raise SafeImportError("invalid import map: " + "; ".join(errors))
    if type(plan.schema_version) is not int or plan.schema_version != 1:
        raise SafeImportError("apply plan schema mismatch")
    if plan.inventory_sha256 != _sha256(canonical_json_bytes(inventory)):
        raise SafeImportError("apply plan inventory digest mismatch")
    if plan.import_map_sha256 != _sha256(canonical_json_bytes(mapping)):
        raise SafeImportError("apply plan import-map digest mismatch")
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
        raise SafeImportError("apply plan does not equal freshly derived plan")
    with _import_lock(candidate_root, plan):
        _assert_destination_cas(candidate_root, plan)
        patch, expected_post_tree = _patch_for_plan(
            candidate_root=candidate_root,
            source_root=source_root,
            inventory=inventory,
            mapping=mapping,
            plan=plan,
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
        actual_paths = [
            path
            for path in run_git(
                candidate_root,
                "diff",
                "--cached",
                "--name-only",
                "-z",
            ).stdout.split(b"\x00")
            if path
        ]
        expected_paths = sorted(
            _raw_path(str(row["path_b64"])) for row in plan.rows
        )
        if actual_paths != expected_paths:
            raise SafeImportError(
                f"staged path set mismatch: expected={expected_paths!r} "
                f"actual={actual_paths!r}"
            )
        if run_git(candidate_root, "diff", "--name-only", "-z").stdout:
            raise SafeImportError("apply left unstaged changes")
        actual_post_tree = _index_tree(candidate_root)
        if actual_post_tree != expected_post_tree:
            raise SafeImportError("post-apply index tree mismatch")
    return {
        "status": "applied",
        "destination_batch": plan.destination_batch,
        "candidate_parent_commit": plan.candidate_head_commit,
        "candidate_parent_tree": plan.candidate_head_tree,
        "post_index_tree": expected_post_tree,
        "import_map_sha256": plan.import_map_sha256,
        "paths": [
            {
                "path_b64": row["path_b64"],
                "source_sha256": row["source_sha256"],
                "source_mode": row["source_mode"],
            }
            for row in plan.rows
        ],
    }
```

`hash-object -w` may add unreachable/reachable blob objects to the shared Git object database, but it does not mutate source refs, source index, source worktree, or source status. The stable source verification ignores unrelated object-database growth and reopens every selected source byte immediately before patch construction.

- [ ] **Step 6: Implement strict plan JSON and two-mode CLI**

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
        "destination_batch",
        "rows",
    }
    if set(value) != expected or not isinstance(value["rows"], list):
        raise SafeImportError("apply plan field set mismatch")
    schema_version = value["schema_version"]
    if type(schema_version) is not int or schema_version != 1:
        raise SafeImportError("apply plan schema mismatch")
    return ApplyPlan(
        schema_version=schema_version,
        inventory_sha256=value["inventory_sha256"],
        import_map_sha256=value["import_map_sha256"],
        candidate_head_commit=value["candidate_head_commit"],
        candidate_head_tree=value["candidate_head_tree"],
        candidate_index_tree=value["candidate_index_tree"],
        candidate_status_sha256=value["candidate_status_sha256"],
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
    parser.add_argument("--output-plan", type=Path)
    arguments = parser.parse_args()
    inventory = json.loads(arguments.inventory.read_text(encoding="utf-8"))
    mapping = json.loads(arguments.map.read_text(encoding="utf-8"))
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
        arguments.output_plan.write_bytes(
            canonical_json_bytes(_plan_to_json(plan))
        )
        print(
            f"apply_plan_status=prepared batch={plan.destination_batch} "
            f"paths={len(plan.rows)}"
        )
        return 0
    if arguments.output_plan is not None:
        parser.error("--output-plan is legal only with --prepare-batch")
    plan_value = json.loads(arguments.apply_plan.read_text(encoding="utf-8"))
    plan = _plan_from_json(plan_value)
    receipt = apply_reviewed_imports(
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

- [ ] **Step 7: Run and commit the apply tool**

```bash
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v \
  scripts.test_qinao_execution_root \
  scripts.test_capture_qinao_candidate_inventory \
  scripts.test_qinao_import_map \
  scripts.test_apply_qinao_import_map
git diff --check
git add scripts/apply_qinao_import_map.py \
  scripts/test_apply_qinao_import_map.py
test "$(git diff --cached --name-only)" = "$(printf '%s\n' \
  scripts/apply_qinao_import_map.py \
  scripts/test_apply_qinao_import_map.py)"
git commit -m "build(qinao): apply reviewed imports with destination CAS"
test -z "$(git status --porcelain=v1)"
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
inventory/map bytes, an exact-set-valid all-`hold` map, and an absent output.
It copies the seven source identity/digest fields from the verified inventory,
computes the two file digests over their canonical bytes, and records fresh
candidate `HEAD/HEAD^{tree}`. It writes canonical sorted compact UTF-8 JSON
with one LF and no duplicate/unknown field.

`verify --handoff-commit <oid>` requires a regular mode-`100644` handoff at the
fixed Git path, exactly one parent equal to `candidate_destination_tip`, that
parent's tree equal to `candidate_destination_tree`, and an exact one-path
parent→commit diff. It reopens inventory/map bytes from that parent, validates
them, recomputes every field, and writes nothing.

Named tests cover closed shape, noncanonical bytes, wrong inventory/map
digest, dirty build, existing output, wrong parent/tree, extra diff, symlink,
mode drift, and byte-identical rebuild in two disposable repositories.

```bash
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v \
  scripts.test_qinao_source_provenance_v1
git add scripts/qinao_source_provenance_v1.py \
  scripts/test_qinao_source_provenance_v1.py
test "$(git diff --cached --name-only)" = "$(printf '%s\n' \
  scripts/qinao_source_provenance_v1.py \
  scripts/test_qinao_source_provenance_v1.py)"
git commit -m "build(qinao): define source provenance handoff"
test -z "$(git status --porcelain=v1)"
```

Expected: positive test discovery, all cases pass, and exactly two tooling
paths are committed.

- [ ] **Step 1: Generate the canonical inventory at its exact evidence path**

```bash
python3 scripts/capture_qinao_candidate_inventory.py \
  --root /Users/changgeng/Project/Project06/Project06/.worktrees/qinao-w0 \
  --approved-base 59c26f508262d7c25869faac0ec0abf968ec1e02 \
  --output docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/source-inventory.json
python3 scripts/capture_qinao_candidate_inventory.py \
  --root /Users/changgeng/Project/Project06/Project06/.worktrees/qinao-w0 \
  --verify docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/source-inventory.json
```

Expected: both commands print `inventory_status=complete`, `paths` is greater than zero, and `source_unchanged=true`.

- [ ] **Step 2: Generate the initial map with no selected byte**

```bash
python3 scripts/build_qinao_import_map.py \
  --inventory docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/source-inventory.json \
  --candidate-base 59c26f508262d7c25869faac0ec0abf968ec1e02 \
  --output docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/import-map.json
python3 scripts/check_qinao_import_map.py \
  --inventory docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/source-inventory.json \
  --map docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/import-map.json
```

Expected: `import_map_status=valid`, `import=0`, `omit=0`, and `hold` equals the inventory path count.

- [ ] **Step 3: Re-open and verify both generated evidence files**

```bash
python3 scripts/capture_qinao_candidate_inventory.py \
  --root /Users/changgeng/Project/Project06/Project06/.worktrees/qinao-w0 \
  --verify docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/source-inventory.json
python3 scripts/check_qinao_import_map.py \
  --inventory docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/source-inventory.json \
  --map docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/import-map.json
```

Expected: both checks pass. The two evidence files contain metadata/digests only; no raw source, secret, device identifier, archive, database, trace, or model package is embedded.

- [ ] **Step 4: Commit only the evidence pair**

```bash
git add \
  docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/source-inventory.json \
  docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/import-map.json
test "$(git diff --cached --name-only)" = "$(printf '%s\n' \
  docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/import-map.json \
  docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/source-inventory.json)"
git commit -m "docs(qinao): bind c0 source provenance"
test -z "$(git status --porcelain=v1)"
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

- [ ] **Step 1: Prove every initial decision remains canonical `hold`**

```bash
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
test -z "$(git status --porcelain=v1)"
if python3 scripts/apply_qinao_import_map.py \
  --candidate-root /Users/changgeng/.codex/worktrees/e4d7/Project06 \
  --source-root /Users/changgeng/Project/Project06/Project06/.worktrees/qinao-w0 \
  --inventory docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/source-inventory.json \
  --map docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/import-map.json \
  --prepare-batch C1 \
  --output-plan /private/tmp/qinao-c0-empty-apply-plan.json
then
  exit 1
fi
test ! -e /private/tmp/qinao-c0-empty-apply-plan.json
test -z "$(git status --porcelain=v1)"
```

Expected: preparation exits non-zero with `batch C1 has zero reviewed imports`; no plan file, index change, worktree change, or source change exists.

- [ ] **Step 3: Run the positive import path only in disposable test repositories**

```bash
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
12. commit only those exact paths.

If any row remains `hold`, no command may import it. If the plan becomes stale, it is discarded and freshly prepared; it is never edited to match a newer tree.

- [ ] **Step 5: Materialize and commit the exact C0 handoff**

Require a clean tree whose `HEAD` is the Task-6 evidence-pair commit, then run:

```bash
test -z "$(git status --porcelain=v1)"
C0_DESTINATION_TIP="$(git rev-parse HEAD)"
C0_DESTINATION_TREE="$(git rev-parse HEAD^{tree})"
python3 scripts/qinao_source_provenance_v1.py build \
  --root /Users/changgeng/.codex/worktrees/e4d7/Project06 \
  --inventory docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/source-inventory.json \
  --map docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/import-map.json \
  --output docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/source-provenance-v1.json
git add docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/source-provenance-v1.json
test "$(git diff --cached --name-only)" = \
  docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/source-provenance-v1.json
git commit -m "docs(qinao): seal c0 source provenance handoff"
test "$(git rev-parse HEAD^)" = "$C0_DESTINATION_TIP"
test "$(git rev-parse HEAD^^{tree})" = "$C0_DESTINATION_TREE"
python3 scripts/qinao_source_provenance_v1.py verify \
  --root /Users/changgeng/.codex/worktrees/e4d7/Project06 \
  --handoff-commit "$(git rev-parse HEAD)"
test -z "$(git status --porcelain=v1)"
```

Expected: the final C0 commit changes exactly the one handoff path; its
canonical fields bind the exact source inventory, all-hold map, and sole
parent candidate tip/tree. It carries no raw source or admission claim.

---

## C0 Completion Gate

Run from `/Users/changgeng/.codex/worktrees/e4d7/Project06`:

```bash
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v \
  scripts.test_qinao_execution_root \
  scripts.test_capture_qinao_candidate_inventory \
  scripts.test_qinao_import_map \
  scripts.test_apply_qinao_import_map \
  scripts.test_qinao_source_provenance_v1 \
  scripts.test_check_qinao_wave_admission \
  scripts.test_check_qinao_owner_ledger
python3 scripts/capture_qinao_candidate_inventory.py \
  --root /Users/changgeng/Project/Project06/Project06/.worktrees/qinao-w0 \
  --verify docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/source-inventory.json
python3 scripts/check_qinao_import_map.py \
  --inventory docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/source-inventory.json \
  --map docs/superpowers/evidence/qinao-clean-candidate/2026-07-23-c0/import-map.json
python3 scripts/qinao_source_provenance_v1.py verify \
  --root /Users/changgeng/.codex/worktrees/e4d7/Project06 \
  --handoff-commit "$(git rev-parse HEAD)"
git diff --check
test -z "$(git status --porcelain=v1)"
git merge-base --is-ancestor \
  59c26f508262d7c25869faac0ec0abf968ec1e02 HEAD
git merge-base --is-ancestor \
  486e1ec5983ad4390c5b07f04607f1345b912c4c HEAD
```

Expected:

- every test module has positive discovery and passes;
- source inventory still byte-matches the preserved source;
- import map is exact-set valid;
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
- [x] Base, HEAD, index, worktree, untracked, deletion, executable, safe symlink, special-file, and non-UTF-8 path behavior has named tests.
- [x] Raw path bytes, not lossy display strings, are the identity and sort key.
- [x] Every map row begins at `hold`; no tool chooses a source stratum, batch,
  rationale, reviewer identity, or review timestamp.
- [x] Imported rows bind exact source digest/mode; deletion is a real absent postimage.
- [x] Raw private C4 classes and production-before-C3 selections fail.
- [x] The checked-in map avoids destination self-reference; the separate ephemeral apply plan binds the live destination HEAD/tree/index/status and per-path preimages.
- [x] `git apply --index --binary` verifies index/worktree preimages and stages only the exact reviewed set.
- [x] Source drift, destination drift, symlink substitution, stale map/plan, partial path set, and zero-row batch all fail.
- [x] Tooling, evidence, review decisions, and imported batches use isolated exact-path commits.
- [x] The final C0 handoff is durable canonical JSON whose one-path commit
  binds its sole parent candidate tip/tree without self-reference.
- [x] The plan uses only Python standard library and `unittest`.
- [x] B0/admission, authority convergence, K4, Artifact Mesh, and later-wave implementation remain outside this child plan.
