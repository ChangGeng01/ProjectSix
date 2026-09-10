"""Fail-closed contract tests for the A0.2 provisional design-edge projection.

The subject's public API cannot express authority material.  The current code
path reports zero authority effects while reproducing the selected-development-
bootstrap byte projection, and remains non-authoritative until an external V1
transition-02 receipt is independently available to a different controller.

Run directly with:
    /usr/bin/python3 scripts/test_qinao_a02_provisional_design_edge.py
"""

from __future__ import annotations

import hashlib
import importlib.util
import inspect
import json
import os
import re
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path
from types import ModuleType
from typing import get_type_hints
from unittest import mock


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts" / "qinao_a02_provisional_design_edge.py"

SCHEMA = "qinao-a02-provisional-review-projection-v1"
SELECTED_DEVELOPMENT_BOOTSTRAP_COMMIT = (
    "7e4aa2d626e2c94b1b1f3405fb8454e73448514f"
)
SELECTED_DEVELOPMENT_BOOTSTRAP_TREE = (
    "47304602b7d1c1eba8eed571dbc65ee36c3a5f21"
)
PREDICTED_REVIEW_TREE_AFTER_0802 = (
    "4fd48205c1716f9ce23efd8885c94afdcdf70311"
)
PREDICTED_REVIEW_TREE_AFTER_0810 = (
    "0fa81fb9d1c3498fd8bb75d4c46a048f3b64260e"
)
P0_TREE = "1f1efdf28bd31bb8fd5ec043e1f4f44fa11f6d01"
PRESERVATION_TREE = "22382c1de6680a263ec4a2f4a6c989c0f0e6e220"
SOURCE_0802_COMMIT = "c8f80486895e12e26d567e610c35a6e2141b3489"
SOURCE_0802_TREE = "2f484874b8b6d49b8bcd595bf3a3ff6c835fb509"
SOURCE_0810_COMMIT = "4a9298db261bcfda97ea1748baad65649156ba66"

PATH_0802 = (
    "docs/superpowers/specs/"
    "2026-08-02-qinao-biomimetic-sovereign-agent-system-design.md"
)
PATH_0810 = (
    "docs/superpowers/specs/"
    "2026-08-10-qinao-global-invariant-firewall-and-recovery-design.md"
)
SOURCE_TUPLES = [
    {
        "path": PATH_0802,
        "gitMode": "100644",
        "gitBlob": "f3d4186769fd0119a418097fea8821d597770189",
        "byteLength": 81128,
        "sha256": (
            "40d322f052425a7e56f03b826922181047c30ac908c35c922a5481e4ddf29aa6"
        ),
    },
    {
        "path": PATH_0810,
        "gitMode": "100644",
        "gitBlob": "887c23a28fb9098d86d252aa8b6dc9153380738b",
        "byteLength": 233726,
        "sha256": (
            "4eb06cde16e0cf5985c7272147ced9274dd83648a098772c8b5a06f7b3ebeab6"
        ),
    },
]

BLOCKER = (
    "BLOCKED_V1_TRANSITION02_PREDECESSOR_EVIDENCE_"
    "UNAVAILABLE_TO_PROVISIONAL_CAPABILITY"
)
CASE_EXACT_0802_0810_ABSENT = "exact0802_0810Absent"
CASE_EXACT_PAIR_UNADMITTED = "exactPairUnadmittedOrNonmatchingV2Evidence"
CASE_INVALID_0802 = "invalid0802Predecessor"
CASE_FOREIGN_0810 = "foreign0810Identity"
RELATIONSHIP_AFTER_0802 = "matchesPredictedReviewTreeAfter0802"
RELATIONSHIP_AFTER_0810 = "matchesPredictedReviewTreeAfter0810"
RELATIONSHIP_DIVERGES = "divergesFromPredictedReviewTrees"
STOP_FOR_CONTROLLER = "stopForIncumbentAdmissionController"
QUARANTINE_REQUIRED = "quarantineRequired"
ZERO_AUTHORITY_SIDE_EFFECTS = {
    "authoritySignerCalls": 0,
    "authorityClaimCalls": 0,
    "authorityCommitCalls": 0,
    "authorityRefMutationCalls": 0,
}
FORBIDDEN_AUTHORITY_ARGUMENTS = {
    "receipt",
    "signer",
    "claim",
    "operation",
    "ref",
    "commit",
    "force",
    "install",
    "admit",
    "accept",
}


def load_subject() -> tuple[ModuleType | None, BaseException | None]:
    if not SCRIPT.is_file():
        return None, FileNotFoundError(SCRIPT)
    try:
        spec = importlib.util.spec_from_file_location(
            "scripts.qinao_a02_provisional_design_edge",
            SCRIPT,
        )
        if spec is None or spec.loader is None:
            raise ImportError(f"could not load {SCRIPT}")
        module = importlib.util.module_from_spec(spec)
        sys.modules[spec.name] = module
        spec.loader.exec_module(module)
        return module, None
    except BaseException as error:  # Convert import breakage into an intentional RED.
        return None, error


SUBJECT, SUBJECT_LOAD_ERROR = load_subject()


class TemporaryBareGit:
    """A ref-free object store that borrows only immutable source objects."""

    def __init__(self) -> None:
        self._temporary = tempfile.TemporaryDirectory(
            prefix="qinao-a02-provisional-test-"
        )
        self.root = Path(self._temporary.name)
        self.repository = self.root / "projection.git"
        subprocess.run(
            ["git", "init", "--bare", "--quiet", str(self.repository)],
            check=True,
            capture_output=True,
            text=True,
        )
        common_git_dir_text = subprocess.run(
            ["git", "rev-parse", "--git-common-dir"],
            cwd=ROOT,
            check=True,
            capture_output=True,
            text=True,
        ).stdout.strip()
        common_git_dir = Path(common_git_dir_text)
        if not common_git_dir.is_absolute():
            common_git_dir = ROOT / common_git_dir
        alternates = self.repository / "objects" / "info" / "alternates"
        alternates.write_text(
            f"{(common_git_dir.resolve() / 'objects').as_posix()}\n",
            encoding="utf-8",
        )
        self._index_ordinal = 0

    def close(self) -> None:
        self._temporary.cleanup()

    def git(
        self,
        *arguments: str,
        input_bytes: bytes | None = None,
        check: bool = True,
    ) -> subprocess.CompletedProcess[bytes]:
        return subprocess.run(
            ["git", f"--git-dir={self.repository}", *arguments],
            input=input_bytes,
            check=check,
            capture_output=True,
        )

    def text(self, *arguments: str) -> str:
        return self.git(*arguments).stdout.decode("utf-8").strip()

    def hash_blob(self, value: bytes) -> str:
        return self.git("hash-object", "-w", "--stdin", input_bytes=value).stdout.decode(
            "ascii"
        ).strip()

    def derive_tree(
        self,
        base_tree: str,
        entries: list[tuple[str, str, str]],
    ) -> str:
        self._index_ordinal += 1
        index = self.root / f"index-{self._index_ordinal:03d}"
        environment = {
            "GIT_DIR": str(self.repository),
            "GIT_INDEX_FILE": str(index),
        }
        subprocess.run(
            ["git", "read-tree", base_tree],
            env=environment,
            check=True,
            capture_output=True,
        )
        for mode, blob, path in entries:
            subprocess.run(
                [
                    "git",
                    "update-index",
                    "--add",
                    "--cacheinfo",
                    mode,
                    blob,
                    path,
                ],
                env=environment,
                check=True,
                capture_output=True,
            )
        return subprocess.run(
            ["git", "write-tree"],
            env=environment,
            check=True,
            capture_output=True,
            text=True,
        ).stdout.strip()

    def refs(self) -> list[str]:
        output = self.text("for-each-ref", "--format=%(refname):%(objectname)")
        return output.splitlines() if output else []

    def loose_objects(self) -> set[str]:
        result: set[str] = set()
        object_root = self.repository / "objects"
        for directory in object_root.iterdir():
            if not directory.is_dir() or not re.fullmatch(r"[0-9a-f]{2}", directory.name):
                continue
            for object_file in directory.iterdir():
                if re.fullmatch(r"[0-9a-f]{38}", object_file.name):
                    result.add(directory.name + object_file.name)
        return result


def recursive_keys(value: object) -> set[str]:
    if isinstance(value, dict):
        return set(value).union(
            *(recursive_keys(child) for child in value.values()),
        )
    if isinstance(value, list):
        return set().union(*(recursive_keys(child) for child in value))
    return set()


def recursive_strings(value: object) -> list[str]:
    if isinstance(value, dict):
        return [
            string
            for child in value.values()
            for string in recursive_strings(child)
        ]
    if isinstance(value, list):
        return [string for child in value for string in recursive_strings(child)]
    return [value] if isinstance(value, str) else []


class A02ProjectionAssertions:
    def assert_current_code_path_has_zero_authority_effects(
        self,
        document: dict,
    ) -> None:
        self.assertEqual(
            document["authorityGate"]["currentCodePathEffects"],
            ZERO_AUTHORITY_SIDE_EFFECTS,
        )

    def assert_v1_predecessor_evidence_is_a_typed_blocker(
        self,
        document: dict,
    ) -> None:
        gate = document["authorityGate"]
        self.assertEqual(gate["state"], "blocked")
        blockers = gate["blockers"]
        self.assertEqual([blocker["code"] for blocker in blockers], [BLOCKER])
        self.assertIs(blockers[0]["waivable"], False)
        self.assert_current_code_path_has_zero_authority_effects(document)


class A02TDDRedGate(unittest.TestCase):
    def test_provisional_projection_implementation_exists_and_imports(self) -> None:
        self.assertTrue(
            SCRIPT.is_file(),
            msg=f"TDD RED: missing implementation {SCRIPT}",
        )
        self.assertIsNone(
            SUBJECT_LOAD_ERROR,
            msg=f"TDD RED: implementation import failed: {SUBJECT_LOAD_ERROR!r}",
        )


@unittest.skipUnless(SUBJECT is not None, "TDD RED: implementation not written yet")
class A02ProvisionalDesignEdgeContractTests(
    A02ProjectionAssertions,
    unittest.TestCase,
):
    maxDiff = None

    def test_public_api_cannot_express_authority_material(self) -> None:
        expected = {
            "classify_presence": (["repository", "tree_oid"], [Path, str], dict),
            "prepare_provisional": (["repository"], [Path], dict),
        }
        for name, (parameter_names, parameter_types, return_type) in expected.items():
            with self.subTest(function=name):
                function = getattr(SUBJECT, name)
                signature = inspect.signature(function)
                self.assertEqual(list(signature.parameters), parameter_names)
                self.assertFalse(
                    any(
                        parameter.kind
                        in (parameter.VAR_POSITIONAL, parameter.VAR_KEYWORD)
                        for parameter in signature.parameters.values()
                    )
                )
                hints = get_type_hints(function)
                self.assertEqual(
                    [hints.get(parameter) for parameter in parameter_names],
                    parameter_types,
                )
                self.assertIs(hints.get("return"), return_type)
                lowered = str(signature).lower()
                for forbidden in FORBIDDEN_AUTHORITY_ARGUMENTS:
                    self.assertNotIn(forbidden, lowered)

    def test_authority_keywords_are_rejected_as_arguments_not_silently_ignored(self) -> None:
        calls = (
            (SUBJECT.prepare_provisional, (ROOT,)),
            (
                SUBJECT.classify_presence,
                (ROOT, PREDICTED_REVIEW_TREE_AFTER_0802),
            ),
        )
        for function, arguments in calls:
            for forbidden in FORBIDDEN_AUTHORITY_ARGUMENTS:
                with self.subTest(function=function.__name__, keyword=forbidden):
                    with self.assertRaises(TypeError):
                        function(*arguments, **{forbidden: object()})

    def test_full_commit_oid_is_rejected_instead_of_implicitly_peeled_to_tree(
        self,
    ) -> None:
        with self.assertRaises(SUBJECT.ProjectionError):
            SUBJECT.classify_presence(
                ROOT,
                SELECTED_DEVELOPMENT_BOOTSTRAP_COMMIT,
            )

    def test_parent_git_environment_cannot_redirect_object_or_repository_reads(
        self,
    ) -> None:
        poisoned = {
            "GIT_DIR": "/private/tmp/qinao-a02-forbidden-git-dir",
            "GIT_WORK_TREE": "/private/tmp/qinao-a02-forbidden-work-tree",
            "GIT_OBJECT_DIRECTORY": "/private/tmp/qinao-a02-forbidden-objects",
            "GIT_ALTERNATE_OBJECT_DIRECTORIES": (
                "/private/tmp/qinao-a02-forbidden-alternates"
            ),
            "GIT_INDEX_FILE": "/private/tmp/qinao-a02-forbidden-index",
            "GIT_COMMON_DIR": "/private/tmp/qinao-a02-forbidden-common-dir",
            "GIT_TEMPLATE_DIR": "/private/tmp/qinao-a02-forbidden-template",
            "GIT_CONFIG_COUNT": "1",
            "GIT_CONFIG_KEY_0": "core.hooksPath",
            "GIT_CONFIG_VALUE_0": "/private/tmp/qinao-a02-forbidden-hooks",
        }
        with mock.patch.dict(os.environ, poisoned, clear=False):
            projection = SUBJECT.prepare_provisional(ROOT)

        self.assertEqual(
            projection["presenceMatrix"]["case"],
            CASE_EXACT_0802_0810_ABSENT,
        )
        self.assert_v1_predecessor_evidence_is_a_typed_blocker(projection)

    def test_current_subprocess_closure_contains_only_review_object_commands(
        self,
    ) -> None:
        calls: list[list[str]] = []
        original = SUBJECT._run

        def recording_run(command: list[str], **keywords: object) -> bytes:
            calls.append(list(command))
            return original(command, **keywords)

        with mock.patch.object(SUBJECT, "_run", side_effect=recording_run):
            SUBJECT.prepare_provisional(ROOT)

        allowed = {
            "init",
            "rev-parse",
            "cat-file",
            "ls-tree",
            "read-tree",
            "update-index",
            "write-tree",
            "mktree",
            "diff-tree",
        }
        forbidden = {
            "update-ref",
            "symbolic-ref",
            "commit-tree",
            "hash-object",
            "replace",
            "checkout",
            "worktree",
            "push",
            "fetch",
        }
        observed: set[str] = set()
        for command in calls:
            self.assertEqual(command[0], "/usr/bin/git")
            if command[1] == "-C":
                subcommand = command[3]
            elif command[1].startswith("--git-dir="):
                subcommand = command[2]
            else:
                subcommand = command[1]
            observed.add(subcommand)
            self.assertIn(subcommand, allowed)
            self.assertTrue(forbidden.isdisjoint(command))
        self.assertTrue({"write-tree", "mktree", "diff-tree"}.issubset(observed))

    def test_ambient_temp_configuration_cannot_redirect_projection_scratch(
        self,
    ) -> None:
        forbidden = ROOT / ".git" / "objects" / "must-not-be-created-by-a02"
        self.assertFalse(forbidden.exists())

        with mock.patch.object(SUBJECT.tempfile, "tempdir", str(forbidden)):
            projection = SUBJECT.prepare_provisional(ROOT)

        self.assertFalse(forbidden.exists())
        self.assertEqual(
            projection["presenceMatrix"]["case"],
            CASE_EXACT_0802_0810_ABSENT,
        )
        self.assert_v1_predecessor_evidence_is_a_typed_blocker(projection)

    def test_forcibly_terminated_scratch_is_reaped_on_the_next_start(self) -> None:
        SUBJECT.prepare_provisional(ROOT)
        before = set(SUBJECT.RUNTIME_ROOT.glob("session-*"))
        child_environment = dict(os.environ)
        child_environment["PYTHONDONTWRITEBYTECODE"] = "1"
        child = subprocess.Popen(
            [
                sys.executable,
                "-c",
                (
                    "import signal, sys\n"
                    f"sys.path.insert(0, {str(ROOT)!r})\n"
                    "from scripts import qinao_a02_provisional_design_edge as s\n"
                    "with s._scratch_session(s.RUNTIME_ROOT):\n"
                    "    signal.pause()\n"
                ),
            ],
            cwd=ROOT,
            env=child_environment,
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.PIPE,
            text=True,
        )
        self.addCleanup(lambda: child.poll() is None and child.kill())
        assert child.stderr is not None
        self.addCleanup(child.stderr.close)

        deadline = time.monotonic() + 10.0
        orphan: Path | None = None
        while time.monotonic() < deadline:
            candidates = set(SUBJECT.RUNTIME_ROOT.glob("session-*")) - before
            if candidates:
                orphan = next(iter(candidates))
                break
            if child.poll() is not None:
                break
            time.sleep(0.01)
        if orphan is None:
            if child.poll() is None:
                child.kill()
            child.wait(timeout=5)
            self.fail(f"child did not acquire a scratch lease: {child.stderr.read()}")

        SUBJECT.prepare_provisional(ROOT)
        self.assertTrue(orphan.exists(), "an active leased session was reaped")

        child.kill()
        child.wait(timeout=5)
        self.assertTrue(orphan.exists())

        projection = SUBJECT.prepare_provisional(ROOT)

        self.assertFalse(orphan.exists())
        self.assertEqual(
            projection["runtimeScratch"]["interruptedSessionRecovery"][
                "trigger"
            ],
            "nextStart",
        )

    def test_concurrent_session_cleanup_and_janitor_walk_do_not_race(self) -> None:
        SUBJECT.prepare_provisional(ROOT)
        child_environment = dict(os.environ)
        child_environment["PYTHONDONTWRITEBYTECODE"] = "1"
        child_code = (
            "import sys, time\n"
            f"sys.path.insert(0, {str(ROOT)!r})\n"
            "from scripts import qinao_a02_provisional_design_edge as s\n"
            "for _ in range(60):\n"
            "    with s._scratch_session(s.RUNTIME_ROOT):\n"
            "        time.sleep(0.0005)\n"
        )
        children = [
            subprocess.Popen(
                [sys.executable, "-c", child_code],
                cwd=ROOT,
                env=child_environment,
                stdin=subprocess.DEVNULL,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.PIPE,
                text=True,
            )
            for _ in range(6)
        ]
        try:
            results = [child.communicate(timeout=30) for child in children]
        finally:
            for child in children:
                if child.poll() is None:
                    child.kill()
                    child.wait(timeout=5)

        failures = [
            (child.returncode, stderr)
            for child, (_, stderr) in zip(children, results)
            if child.returncode != 0
        ]
        self.assertEqual(failures, [])
        SUBJECT.prepare_provisional(ROOT)
        self.assertEqual(list(SUBJECT.RUNTIME_ROOT.glob("session-*")), [])

    def test_cleanup_lock_failure_releases_lease_for_next_start_reaping(
        self,
    ) -> None:
        SUBJECT.prepare_provisional(ROOT)
        real_open = SUBJECT._open_or_create_janitor_lock
        open_count = 0

        def fail_cleanup_open(runtime_root: Path) -> int:
            nonlocal open_count
            open_count += 1
            if open_count == 2:
                raise SUBJECT.ProjectionError("injected cleanup-lock failure")
            return real_open(runtime_root)

        orphan: Path | None = None
        with mock.patch.object(
            SUBJECT,
            "_open_or_create_janitor_lock",
            side_effect=fail_cleanup_open,
        ):
            with self.assertRaisesRegex(
                SUBJECT.ProjectionError,
                "injected cleanup-lock failure",
            ):
                with SUBJECT._scratch_session(SUBJECT.RUNTIME_ROOT) as session:
                    orphan = session

        assert orphan is not None
        self.assertTrue(orphan.exists())
        SUBJECT.prepare_provisional(ROOT)
        self.assertFalse(orphan.exists())

    def test_scratch_cleanup_unlinks_links_without_following_external_targets(
        self,
    ) -> None:
        SUBJECT.prepare_provisional(ROOT)
        with tempfile.TemporaryDirectory(prefix="qinao-a02-external-") as raw_temp:
            external = Path(raw_temp) / "must-survive"
            external.write_bytes(b"outside scratch\n")
            with SUBJECT._scratch_session(SUBJECT.RUNTIME_ROOT) as session:
                os.symlink(external, session / "external-symlink")
                os.link(external, session / "external-hardlink")

            self.assertEqual(external.read_bytes(), b"outside scratch\n")
            self.assertEqual(external.stat().st_nlink, 1)

    def test_session_rename_swap_fails_without_traversing_replacement(self) -> None:
        SUBJECT.prepare_provisional(ROOT)
        real_clear = SUBJECT._clear_private_directory_fd
        session: Path | None = None
        moved: Path | None = None
        replacement_sentinel: Path | None = None
        swapped = False

        def swap_after_anchored_clear(
            descriptor: int,
            *,
            root_device: int,
            budget: list[int],
            depth: int,
        ) -> None:
            nonlocal moved, replacement_sentinel, swapped
            real_clear(
                descriptor,
                root_device=root_device,
                budget=budget,
                depth=depth,
            )
            if depth == 0 and not swapped:
                assert session is not None
                swapped = True
                moved = session.with_name(session.name + "-moved")
                session.rename(moved)
                session.mkdir(mode=0o700)
                replacement_sentinel = session / "must-not-be-traversed"
                replacement_sentinel.write_bytes(b"replacement\n")

        with mock.patch.object(
            SUBJECT,
            "_clear_private_directory_fd",
            side_effect=swap_after_anchored_clear,
        ):
            with self.assertRaisesRegex(
                SUBJECT.ProjectionError,
                "scratch session identity changed",
            ):
                with SUBJECT._scratch_session(SUBJECT.RUNTIME_ROOT) as active:
                    session = active

        assert moved is not None
        assert replacement_sentinel is not None
        self.assertTrue(moved.exists())
        self.assertEqual(replacement_sentinel.read_bytes(), b"replacement\n")
        SUBJECT.prepare_provisional(ROOT)
        self.assertFalse(moved.exists())
        self.assertFalse(replacement_sentinel.exists())

    def test_prepare_reports_only_a_rebuildable_non_authoritative_projection(self) -> None:
        projection = SUBJECT.prepare_provisional(ROOT)

        self.assertEqual(projection["schema"], SCHEMA)
        self.assertEqual(
            projection["observedTree"],
            {
                "treeOid": PREDICTED_REVIEW_TREE_AFTER_0802,
                "design08_02": "exact",
                "design08_10": "absent",
            },
        )
        presence = projection["presenceMatrix"]
        self.assertEqual(presence["case"], CASE_EXACT_0802_0810_ABSENT)
        self.assertEqual(
            presence["projectionRelationship"],
            RELATIONSHIP_AFTER_0802,
        )
        self.assertEqual(
            presence["projectionDisposition"],
            "preparedNonAuthoritative",
        )
        self.assertEqual(presence["predecessorAuthority"], "unverified")
        self.assertEqual(presence["requiredDisposition"], STOP_FOR_CONTROLLER)
        deterministic = projection["deterministicProjection"]
        self.assertEqual(deterministic["kind"], "ephemeralIsolatedGitTrees")
        self.assertEqual(
            deterministic["reviewTreeAfter0802"],
            PREDICTED_REVIEW_TREE_AFTER_0802,
        )
        self.assertEqual(
            deterministic["projectedTreeOidEphemeral"],
            PREDICTED_REVIEW_TREE_AFTER_0810,
        )
        self.assertEqual(deterministic["changedEntryCount"], 1)
        self.assertEqual(deterministic["onlyChangedPath"], PATH_0810)
        self.assertIs(
            deterministic["nonTargetEntryGitObjectIdentitiesUnchanged"],
            True,
        )
        self.assertEqual(
            deterministic["onePathDeltaProof"],
            "exactGitTreeIdentityAndDiffTree",
        )
        self.assertEqual(
            deterministic["projectedPresenceCase"],
            CASE_EXACT_PAIR_UNADMITTED,
        )
        self.assertEqual(len(deterministic["algorithms"]), 2)
        self.assertEqual(len(set(deterministic["algorithms"])), 2)
        self.assertIs(deterministic["independentFailureDomains"], False)
        self.assertEqual(
            deterministic["agreementScope"],
            "distinctProceduresSharedGitImplementation",
        )
        self.assertEqual(deterministic["sharedObjectDatabaseWrites"], 0)
        self.assertEqual(
            deterministic["persistentGitObjectsRemainingAfterNormalCompletion"],
            0,
        )
        scratch = projection["runtimeScratch"]
        self.assertIs(
            scratch["pythonTempfileAmbientConfigurationIgnored"],
            True,
        )
        self.assertEqual(scratch["normalExitCleanup"], "synchronous")
        self.assertIs(
            scratch["forcedTerminationSynchronousCleanupGuaranteed"],
            False,
        )
        self.assertEqual(scratch["persistentControlFiles"], [".janitor.lock"])
        self.assertEqual(
            scratch["interruptedSessionRecovery"],
            {
                "trigger": "nextStart",
                "eligibleWhen": (
                    "leaseUnlockedAndPathOwnershipModeIdentityValid"
                ),
                "invalidStateDisposition": "failClosed",
            },
        )
        self.assertIs(
            scratch[
                "orphanSubprocessTerminationGuaranteedAfterParentSIGKILL"
            ],
            False,
        )
        self.assertEqual(
            scratch["sameUidNamespaceAdversaryResistance"],
            "fdAnchoredTraversalWithIdentityChecksNotCapabilityIsolation",
        )
        self.assertEqual(
            scratch["osResourceIsolation"],
            "wallClockAndPipeByteBudgetsOnly",
        )
        self.assert_v1_predecessor_evidence_is_a_typed_blocker(projection)
        self.assertEqual(projection["semanticAuthority"], "none")
        self.assertIs(projection["nonAuthoritative"], True)
        self.assertEqual(
            projection["rebuildability"],
            {
                "state": "conditional",
                "prerequisite": "fixedSourceObjectsRemainAvailableAndByteExact",
            },
        )
        self.assertIs(projection["installable"], False)
        source = projection["projectionSource"]
        self.assertIs(source["sourceObjectSnapshotIsolation"], False)
        self.assertEqual(source["sourceObjectEpochBinding"], "notProven")
        self.assertEqual(
            source["selectedDevelopmentBootstrapCommit"],
            SELECTED_DEVELOPMENT_BOOTSTRAP_COMMIT,
        )
        self.assertEqual(
            source["selectedDevelopmentBootstrapTree"],
            SELECTED_DEVELOPMENT_BOOTSTRAP_TREE,
        )
        self.assertEqual(source["orderedSourceTuples"], SOURCE_TUPLES)
        self.assertEqual(
            source["sourceObservations"],
            [
                {
                    "role": "design08_02ReviewSource",
                    "commitOid": SOURCE_0802_COMMIT,
                    "treeOid": SOURCE_0802_TREE,
                    "tuple": SOURCE_TUPLES[0],
                    "semanticAuthority": "none",
                },
                {
                    "role": "design08_10PreservationSource",
                    "commitOid": SOURCE_0810_COMMIT,
                    "treeOid": PRESERVATION_TREE,
                    "tuple": SOURCE_TUPLES[1],
                    "semanticAuthority": "none",
                },
            ],
        )
        without_digest = {
            key: value
            for key, value in projection.items()
            if key != "projectionDigest"
        }
        canonical = json.dumps(
            without_digest,
            ensure_ascii=False,
            sort_keys=True,
            separators=(",", ":"),
        ).encode("utf-8")
        expected_digest = hashlib.sha256(
            b"QINAO-A02-PROVISIONAL-REVIEW-PROJECTION-V1\0"
            + len(canonical).to_bytes(8, "big")
            + canonical
        ).hexdigest()
        self.assertEqual(projection["projectionDigest"], expected_digest)

        authority_result_key_fragments = {
            "operation",
            "receipt",
            "accepted",
            "alreadypresent",
        }
        actual_keys = {key.lower() for key in recursive_keys(projection)}
        for key in actual_keys:
            for forbidden in authority_result_key_fragments:
                self.assertNotIn(forbidden, key)
        for value in recursive_strings(projection):
            self.assertNotIn(value, {"accepted", "alreadyPresent"})
        self.assertNotIn(
            "alreadyPresent",
            json.dumps(projection, sort_keys=True, separators=(",", ":")),
        )

    def test_exact_pair_without_authority_is_quarantined_not_already_present(self) -> None:
        fixture = TemporaryBareGit()
        self.addCleanup(fixture.close)
        after_0802 = fixture.derive_tree(
            SELECTED_DEVELOPMENT_BOOTSTRAP_TREE,
            [("100644", SOURCE_TUPLES[0]["gitBlob"], PATH_0802)],
        )
        after_0810 = fixture.derive_tree(
            after_0802,
            [("100644", SOURCE_TUPLES[1]["gitBlob"], PATH_0810)],
        )
        result = SUBJECT.classify_presence(fixture.repository, after_0810)

        self.assertEqual(
            result["presenceMatrix"]["case"],
            CASE_EXACT_PAIR_UNADMITTED,
        )
        self.assertEqual(
            result["presenceMatrix"]["projectionRelationship"],
            RELATIONSHIP_AFTER_0810,
        )
        self.assertEqual(
            result["presenceMatrix"]["requiredDisposition"],
            QUARANTINE_REQUIRED,
        )
        self.assert_v1_predecessor_evidence_is_a_typed_blocker(result)
        self.assertNotIn("alreadyPresent", recursive_strings(result))

    def test_exact_review_base_is_a_non_authoritative_matching_projection(self) -> None:
        fixture = TemporaryBareGit()
        self.addCleanup(fixture.close)
        after_0802 = fixture.derive_tree(
            SELECTED_DEVELOPMENT_BOOTSTRAP_TREE,
            [("100644", SOURCE_TUPLES[0]["gitBlob"], PATH_0802)],
        )
        result = SUBJECT.classify_presence(fixture.repository, after_0802)

        self.assertEqual(
            result["observedTree"],
            {
                "treeOid": PREDICTED_REVIEW_TREE_AFTER_0802,
                "design08_02": "exact",
                "design08_10": "absent",
            },
        )
        presence = result["presenceMatrix"]
        self.assertEqual(presence["case"], CASE_EXACT_0802_0810_ABSENT)
        self.assertEqual(presence["projectionRelationship"], RELATIONSHIP_AFTER_0802)
        self.assertEqual(
            presence["projectionDisposition"],
            "preparedNonAuthoritative",
        )
        self.assertEqual(presence["predecessorAuthority"], "unverified")
        self.assertEqual(presence["requiredDisposition"], STOP_FOR_CONTROLLER)
        self.assert_v1_predecessor_evidence_is_a_typed_blocker(result)

    def test_p0_content_presence_does_not_become_predecessor_authority(self) -> None:
        p0 = SUBJECT.classify_presence(ROOT, P0_TREE)
        self.assertEqual(
            p0["observedTree"],
            {
                "treeOid": P0_TREE,
                "design08_02": "exact",
                "design08_10": "absent",
            },
        )
        presence = p0["presenceMatrix"]
        self.assertEqual(presence["case"], CASE_EXACT_0802_0810_ABSENT)
        self.assertEqual(presence["projectionRelationship"], RELATIONSHIP_DIVERGES)
        self.assertEqual(presence["predecessorAuthority"], "unverified")
        self.assertEqual(presence["requiredDisposition"], STOP_FOR_CONTROLLER)
        self.assertNotEqual(
            presence.get("projectionDisposition"),
            "preparedNonAuthoritative",
        )
        self.assert_v1_predecessor_evidence_is_a_typed_blocker(p0)

        preservation = SUBJECT.classify_presence(ROOT, PRESERVATION_TREE)
        self.assertEqual(
            preservation["presenceMatrix"]["case"],
            CASE_EXACT_PAIR_UNADMITTED,
        )
        self.assertEqual(
            preservation["presenceMatrix"]["projectionRelationship"],
            RELATIONSHIP_DIVERGES,
        )
        self.assertEqual(
            preservation["presenceMatrix"]["requiredDisposition"],
            QUARANTINE_REQUIRED,
        )
        self.assertNotIn("alreadyPresent", recursive_strings(preservation))

    def test_cli_projection_is_typed_blocked_even_when_projection_succeeds(self) -> None:
        completed = subprocess.run(
            [sys.executable, str(SCRIPT), "--repository", str(ROOT)],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )

        self.assertNotEqual(completed.returncode, 0)
        projection = json.loads(completed.stdout)
        self.assert_v1_predecessor_evidence_is_a_typed_blocker(projection)
        self.assertIs(projection["nonAuthoritative"], True)
        self.assertEqual(projection["rebuildability"]["state"], "conditional")
        self.assertIs(projection["installable"], False)

    def test_unreadable_tree_is_typed_unavailable_not_downgraded_to_absent(
        self,
    ) -> None:
        completed = subprocess.run(
            [
                sys.executable,
                str(SCRIPT),
                "--repository",
                str(ROOT),
                "--classify-tree",
                "0" * 40,
            ],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )

        self.assertNotEqual(completed.returncode, 0)
        self.assertEqual(completed.stdout, "")
        unavailable = json.loads(completed.stderr)
        self.assertEqual(unavailable["schema"], SCHEMA)
        self.assertEqual(
            unavailable["evaluationDisposition"],
            "evaluationUnavailable",
        )
        self.assertNotIn("observedTree", unavailable)
        self.assertEqual(unavailable["authorityGate"]["state"], "blocked")
        self.assertEqual(
            [
                blocker["code"]
                for blocker in unavailable["authorityGate"]["blockers"]
            ],
            ["BLOCKED_EVALUATION_UNAVAILABLE"],
        )
        self.assert_current_code_path_has_zero_authority_effects(unavailable)

    def test_internal_input_and_tree_entry_budgets_fail_closed(self) -> None:
        oversized_input = b"x" * (SUBJECT.MAX_COMMAND_INPUT_BYTES + 1)
        with self.assertRaises(SUBJECT.ProjectionError):
            SUBJECT._run(
                ["/usr/bin/git", "--version"],
                cwd=ROOT,
                input_bytes=oversized_input,
            )

        record = (
            b"100644 blob "
            + SOURCE_TUPLES[0]["gitBlob"].encode("ascii")
            + b"\tentry\0"
        )
        oversized_tree = record * (SUBJECT.MAX_TREE_ENTRIES + 1)
        with self.assertRaises(SUBJECT.ProjectionError):
            SUBJECT._parse_ls_tree(oversized_tree)

    def test_command_timeout_also_covers_a_child_that_does_not_read_input(
        self,
    ) -> None:
        started = time.monotonic()
        with mock.patch.object(SUBJECT, "COMMAND_TIMEOUT_SECONDS", 0.1):
            with self.assertRaisesRegex(
                SUBJECT.ProjectionError,
                "fixed time budget",
            ):
                SUBJECT._run(
                    [
                        sys.executable,
                        "-c",
                        "import time; time.sleep(5)",
                    ],
                    cwd=ROOT,
                    input_bytes=b"x" * (1024 * 1024),
                )
        self.assertLess(time.monotonic() - started, 2.0)

    def test_command_stdout_and_stderr_budgets_fail_closed(self) -> None:
        cases = [
            ("MAX_COMMAND_STDOUT_BYTES", 1),
            ("MAX_COMMAND_STDERR_BYTES", 2),
        ]
        for constant, descriptor in cases:
            with self.subTest(stream=constant):
                child_code = (
                    "import os; "
                    f"os.write({descriptor}, b'x' * 2048)"
                )
                with mock.patch.object(SUBJECT, constant, 1024):
                    with self.assertRaisesRegex(
                        SUBJECT.ProjectionError,
                        "fixed byte budget",
                    ):
                        SUBJECT._run(
                            [sys.executable, "-c", child_code],
                            cwd=ROOT,
                        )

    def test_timeout_kills_descendants_after_the_process_leader_exits(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory(prefix="qinao-a02-pid-") as raw_temp:
            pid_file = Path(raw_temp) / "descendant.pid"
            leader_code = (
                "import pathlib, subprocess, sys\n"
                "descendant = subprocess.Popen([\n"
                "    sys.argv[2], '-c', 'import time; time.sleep(30)'\n"
                "])\n"
                "pathlib.Path(sys.argv[1]).write_text(str(descendant.pid))\n"
            )
            descendant_pid: int | None = None
            try:
                with mock.patch.object(SUBJECT, "COMMAND_TIMEOUT_SECONDS", 0.2):
                    with self.assertRaisesRegex(
                        SUBJECT.ProjectionError,
                        "fixed time budget",
                    ):
                        SUBJECT._run(
                            [
                                sys.executable,
                                "-c",
                                leader_code,
                                str(pid_file),
                                sys.executable,
                            ],
                            cwd=ROOT,
                        )
                descendant_pid = int(pid_file.read_text(encoding="utf-8"))
                deadline = time.monotonic() + 2.0
                while time.monotonic() < deadline:
                    try:
                        os.kill(descendant_pid, 0)
                    except ProcessLookupError:
                        break
                    time.sleep(0.01)
                else:
                    self.fail("timed-out descendant process remained alive")
            finally:
                if descendant_pid is not None:
                    try:
                        os.kill(descendant_pid, 9)
                    except ProcessLookupError:
                        pass

    def test_cli_help_has_no_authority_bearing_surface(self) -> None:
        completed = subprocess.run(
            [sys.executable, str(SCRIPT), "--help"],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )

        self.assertEqual(completed.returncode, 0, msg=completed.stderr)
        help_text = f"{completed.stdout}\n{completed.stderr}".lower()
        self.assertIn("--repository", help_text)
        for forbidden in FORBIDDEN_AUTHORITY_ARGUMENTS:
            with self.subTest(forbidden=forbidden):
                self.assertIsNone(
                    re.search(rf"\b{re.escape(forbidden)}\b", help_text),
                    msg=f"authority word leaked into CLI help: {forbidden}",
                )


@unittest.skipUnless(SUBJECT is not None, "TDD RED: implementation not written yet")
class A02ProvisionalDesignEdgeBareGitTests(
    A02ProjectionAssertions,
    unittest.TestCase,
):
    maxDiff = None

    def setUp(self) -> None:
        self.fixture = TemporaryBareGit()
        self.addCleanup(self.fixture.close)

    def test_selected_bootstrap_projects_the_two_literal_review_trees(self) -> None:
        for source_tuple in SOURCE_TUPLES:
            with self.subTest(source=source_tuple["path"]):
                blob = self.fixture.git(
                    "cat-file",
                    "blob",
                    source_tuple["gitBlob"],
                ).stdout
                self.assertEqual(len(blob), source_tuple["byteLength"])
                self.assertEqual(
                    hashlib.sha256(blob).hexdigest(),
                    source_tuple["sha256"],
                )

        after_0802 = self.fixture.derive_tree(
            SELECTED_DEVELOPMENT_BOOTSTRAP_TREE,
            [("100644", SOURCE_TUPLES[0]["gitBlob"], PATH_0802)],
        )
        after_0810 = self.fixture.derive_tree(
            after_0802,
            [("100644", SOURCE_TUPLES[1]["gitBlob"], PATH_0810)],
        )

        self.assertEqual(after_0802, PREDICTED_REVIEW_TREE_AFTER_0802)
        self.assertEqual(after_0810, PREDICTED_REVIEW_TREE_AFTER_0810)
        diff = self.fixture.text(
            "diff-tree",
            "--no-commit-id",
            "--name-status",
            "-r",
            after_0802,
            after_0810,
        )
        self.assertEqual(diff, f"A\t{PATH_0810}")

    def test_prepare_uses_explicit_ref_free_repository_not_ambient_head(self) -> None:
        self.assertEqual(self.fixture.refs(), [])

    def test_source_object_directory_with_path_separator_is_not_reparsed(
        self,
    ) -> None:
        renamed = self.fixture.root / "projection:with-separator.git"
        self.fixture.repository.rename(renamed)
        self.fixture.repository = renamed

        projection = SUBJECT.prepare_provisional(self.fixture.repository)

        self.assertEqual(
            projection["deterministicProjection"]["reviewTreeAfter0802"],
            PREDICTED_REVIEW_TREE_AFTER_0802,
        )
        self.assertEqual(
            projection["deterministicProjection"]["projectedTreeOidEphemeral"],
            PREDICTED_REVIEW_TREE_AFTER_0810,
        )
        unresolved_head = self.fixture.git(
            "rev-parse",
            "--verify",
            "HEAD",
            check=False,
        )
        self.assertNotEqual(unresolved_head.returncode, 0)
        objects_before = self.fixture.loose_objects()

        projection = SUBJECT.prepare_provisional(self.fixture.repository)

        self.assertEqual(
            projection["presenceMatrix"]["case"],
            CASE_EXACT_0802_0810_ABSENT,
        )
        self.assertEqual(
            projection["presenceMatrix"]["projectionRelationship"],
            RELATIONSHIP_AFTER_0802,
        )
        self.assert_v1_predecessor_evidence_is_a_typed_blocker(projection)
        self.assertEqual(self.fixture.refs(), [])
        new_objects = self.fixture.loose_objects() - objects_before
        self.assertEqual(new_objects, set())
        new_types = {
            self.fixture.text("cat-file", "-t", object_id)
            for object_id in new_objects
        }
        self.assertNotIn("commit", new_types)
        self.assertNotIn("tag", new_types)

    def test_repository_replace_refs_cannot_rewrite_fixed_source_history(self) -> None:
        environment = dict(os.environ)
        environment.update(
            {
                "GIT_DIR": str(self.fixture.repository),
                "GIT_AUTHOR_NAME": "A0.2 adversary",
                "GIT_AUTHOR_EMAIL": "a02-adversary.invalid",
                "GIT_AUTHOR_DATE": "2000-01-01T00:00:00Z",
                "GIT_COMMITTER_NAME": "A0.2 adversary",
                "GIT_COMMITTER_EMAIL": "a02-adversary.invalid",
                "GIT_COMMITTER_DATE": "2000-01-01T00:00:00Z",
            }
        )
        replacement = subprocess.run(
            ["git", "commit-tree", SOURCE_0802_TREE],
            env=environment,
            input=b"malicious replacement\n",
            check=True,
            capture_output=True,
        ).stdout.decode("ascii").strip()
        self.fixture.git(
            "replace",
            SELECTED_DEVELOPMENT_BOOTSTRAP_COMMIT,
            replacement,
        )

        projection = SUBJECT.prepare_provisional(self.fixture.repository)

        self.assertEqual(
            projection["projectionSource"]["selectedDevelopmentBootstrapTree"],
            SELECTED_DEVELOPMENT_BOOTSTRAP_TREE,
        )
        self.assert_v1_predecessor_evidence_is_a_typed_blocker(projection)

    def test_prepare_is_byte_rebuildable_across_independent_ref_free_repositories(
        self,
    ) -> None:
        other = TemporaryBareGit()
        self.addCleanup(other.close)

        first = SUBJECT.prepare_provisional(self.fixture.repository)
        second = SUBJECT.prepare_provisional(other.repository)

        canonical_first = json.dumps(
            first,
            ensure_ascii=False,
            sort_keys=True,
            separators=(",", ":"),
        ).encode("utf-8")
        canonical_second = json.dumps(
            second,
            ensure_ascii=False,
            sort_keys=True,
            separators=(",", ":"),
        ).encode("utf-8")
        self.assertEqual(canonical_first, canonical_second)
        self.assertIs(first["nonAuthoritative"], True)
        self.assertEqual(first["rebuildability"]["state"], "conditional")
        self.assertIs(first["installable"], False)

    def test_missing_and_wrong_0802_fail_closed(self) -> None:
        wrong_blob = self.fixture.hash_blob(b"foreign 08-02 bytes\n")
        wrong_blob_tree = self.fixture.derive_tree(
            SELECTED_DEVELOPMENT_BOOTSTRAP_TREE,
            [("100644", wrong_blob, PATH_0802)],
        )
        wrong_mode_tree = self.fixture.derive_tree(
            SELECTED_DEVELOPMENT_BOOTSTRAP_TREE,
            [("100755", SOURCE_TUPLES[0]["gitBlob"], PATH_0802)],
        )
        cases = {
            "absent": SELECTED_DEVELOPMENT_BOOTSTRAP_TREE,
            "wrongBlobLengthAndSHA": wrong_blob_tree,
            "wrongMode": wrong_mode_tree,
        }

        for name, tree in cases.items():
            with self.subTest(case=name):
                result = SUBJECT.classify_presence(self.fixture.repository, tree)
                self.assertEqual(
                    result["presenceMatrix"]["case"],
                    CASE_INVALID_0802,
                )
                self.assertIn(
                    CASE_INVALID_0802,
                    {finding["code"] for finding in result["findings"]},
                )
                self.assertEqual(
                    result["presenceMatrix"]["predecessorAuthority"],
                    "unverified",
                )
                self.assert_v1_predecessor_evidence_is_a_typed_blocker(result)

    def test_exact_0802_in_nonprojected_trees_is_observed_but_not_authorized(
        self,
    ) -> None:
        for name, tree in {
            "sourceCommitTree": SOURCE_0802_TREE,
            "laterP0Tree": P0_TREE,
        }.items():
            with self.subTest(case=name):
                result = SUBJECT.classify_presence(self.fixture.repository, tree)
                self.assertEqual(result["observedTree"]["design08_02"], "exact")
                self.assertEqual(result["observedTree"]["design08_10"], "absent")
                presence = result["presenceMatrix"]
                self.assertEqual(presence["case"], CASE_EXACT_0802_0810_ABSENT)
                self.assertEqual(
                    presence["projectionRelationship"],
                    RELATIONSHIP_DIVERGES,
                )
                self.assertEqual(presence["predecessorAuthority"], "unverified")
                self.assertEqual(presence["requiredDisposition"], STOP_FOR_CONTROLLER)
                self.assertNotEqual(
                    presence.get("projectionDisposition"),
                    "preparedNonAuthoritative",
                )
                self.assert_v1_predecessor_evidence_is_a_typed_blocker(result)

    def test_foreign_0810_blob_mode_and_path_fail_closed(self) -> None:
        exact_0802_tree = self.fixture.derive_tree(
            SELECTED_DEVELOPMENT_BOOTSTRAP_TREE,
            [("100644", SOURCE_TUPLES[0]["gitBlob"], PATH_0802)],
        )
        self.assertEqual(exact_0802_tree, PREDICTED_REVIEW_TREE_AFTER_0802)
        wrong_blob = self.fixture.hash_blob(b"foreign 08-10 bytes\n")
        symlink_blob = self.fixture.hash_blob(b"foreign-target\n")
        wrong_path_tree = self.fixture.derive_tree(
            exact_0802_tree,
            [("100644", SOURCE_TUPLES[1]["gitBlob"], f"{PATH_0810}.foreign")],
        )
        cases = {
            "wrongBlobLengthAndSHA": self.fixture.derive_tree(
                exact_0802_tree,
                [("100644", wrong_blob, PATH_0810)],
            ),
            "wrongExecutableMode": self.fixture.derive_tree(
                exact_0802_tree,
                [("100755", SOURCE_TUPLES[1]["gitBlob"], PATH_0810)],
            ),
            "symlink": self.fixture.derive_tree(
                exact_0802_tree,
                [("120000", symlink_blob, PATH_0810)],
            ),
        }

        for name, tree in cases.items():
            with self.subTest(case=name):
                result = SUBJECT.classify_presence(self.fixture.repository, tree)
                self.assertEqual(
                    result["presenceMatrix"]["case"],
                    CASE_FOREIGN_0810,
                )
                self.assertIn(
                    CASE_FOREIGN_0810,
                    {finding["code"] for finding in result["findings"]},
                )
                self.assertEqual(
                    result["presenceMatrix"]["requiredDisposition"],
                    QUARANTINE_REQUIRED,
                )
                self.assertNotIn("alreadyPresent", recursive_strings(result))
                self.assert_v1_predecessor_evidence_is_a_typed_blocker(result)

        wrong_path = SUBJECT.classify_presence(
            self.fixture.repository,
            wrong_path_tree,
        )
        self.assertEqual(wrong_path["observedTree"]["design08_02"], "exact")
        self.assertEqual(wrong_path["observedTree"]["design08_10"], "absent")
        self.assertEqual(
            wrong_path["presenceMatrix"]["case"],
            CASE_FOREIGN_0810,
        )
        self.assertEqual(
            wrong_path["presenceMatrix"]["projectionRelationship"],
            RELATIONSHIP_DIVERGES,
        )
        self.assertEqual(
            wrong_path["presenceMatrix"]["requiredDisposition"],
            QUARANTINE_REQUIRED,
        )
        self.assertIn(
            "unexpected0810LikePath",
            {finding["code"] for finding in wrong_path["findings"]},
        )
        self.assert_v1_predecessor_evidence_is_a_typed_blocker(wrong_path)

    def test_0810_path_aliases_and_multiple_copies_require_quarantine(self) -> None:
        exact_0802_tree = self.fixture.derive_tree(
            SELECTED_DEVELOPMENT_BOOTSTRAP_TREE,
            [("100644", SOURCE_TUPLES[0]["gitBlob"], PATH_0802)],
        )
        wrong_alias_blob = self.fixture.hash_blob(b"wrong alias bytes\n")
        cases = {
            "casefoldWrongBlob": (PATH_0810.upper(), wrong_alias_blob),
            "trailingSpaceWrongBlob": (f"{PATH_0810} ", wrong_alias_blob),
            "suffixWrongBlob": (f"{PATH_0810}.bak", wrong_alias_blob),
            "sameNameWrongDirectory": (
                f"foreign/{Path(PATH_0810).name}",
                wrong_alias_blob,
            ),
            "sameBlobUnrelatedPath": (
                "foreign/copied-design-source.md",
                SOURCE_TUPLES[1]["gitBlob"],
            ),
        }
        for name, (alias, blob) in cases.items():
            with self.subTest(case=name):
                alias_tree = self.fixture.derive_tree(
                    exact_0802_tree,
                    [("100644", blob, alias)],
                )
                result = SUBJECT.classify_presence(
                    self.fixture.repository,
                    alias_tree,
                )

                self.assertEqual(result["observedTree"]["design08_10"], "absent")
                self.assertEqual(
                    result["presenceMatrix"]["case"],
                    CASE_FOREIGN_0810,
                )
                self.assertEqual(
                    result["presenceMatrix"]["requiredDisposition"],
                    QUARANTINE_REQUIRED,
                )
                self.assertIn(
                    "unexpected0810LikePath",
                    {finding["code"] for finding in result["findings"]},
                )
                self.assert_v1_predecessor_evidence_is_a_typed_blocker(result)

    def test_simultaneous_0802_and_0810_faults_keep_both_findings(self) -> None:
        wrong_0802 = self.fixture.hash_blob(b"wrong 08-02\n")
        wrong_0810 = self.fixture.hash_blob(b"wrong 08-10\n")
        tree = self.fixture.derive_tree(
            SELECTED_DEVELOPMENT_BOOTSTRAP_TREE,
            [
                ("100644", wrong_0802, PATH_0802),
                ("100644", wrong_0810, PATH_0810),
            ],
        )

        result = SUBJECT.classify_presence(self.fixture.repository, tree)

        self.assertEqual(result["presenceMatrix"]["case"], CASE_INVALID_0802)
        finding_codes = {finding["code"] for finding in result["findings"]}
        self.assertEqual(
            finding_codes,
            {CASE_INVALID_0802, CASE_FOREIGN_0810},
        )
        self.assertEqual(result["observedTree"]["design08_02"], "foreign")
        self.assertEqual(result["observedTree"]["design08_10"], "foreign")
        self.assert_v1_predecessor_evidence_is_a_typed_blocker(result)

    def test_exact_pair_and_preservation_pair_are_both_quarantined(self) -> None:
        exact_0802_tree = self.fixture.derive_tree(
            SELECTED_DEVELOPMENT_BOOTSTRAP_TREE,
            [("100644", SOURCE_TUPLES[0]["gitBlob"], PATH_0802)],
        )
        exact_pair_tree = self.fixture.derive_tree(
            exact_0802_tree,
            [("100644", SOURCE_TUPLES[1]["gitBlob"], PATH_0810)],
        )
        self.assertEqual(exact_pair_tree, PREDICTED_REVIEW_TREE_AFTER_0810)
        for name, tree in {
            "exactPairWithoutAuthority": exact_pair_tree,
            "preservationPairWithExtraPaths": PRESERVATION_TREE,
        }.items():
            with self.subTest(case=name):
                result = SUBJECT.classify_presence(self.fixture.repository, tree)
                self.assertEqual(
                    result["presenceMatrix"]["case"],
                    CASE_EXACT_PAIR_UNADMITTED,
                )
                self.assertEqual(
                    result["presenceMatrix"]["requiredDisposition"],
                    QUARANTINE_REQUIRED,
                )
                expected_relationship = (
                    RELATIONSHIP_AFTER_0810
                    if tree == exact_pair_tree
                    else RELATIONSHIP_DIVERGES
                )
                self.assertEqual(
                    result["presenceMatrix"]["projectionRelationship"],
                    expected_relationship,
                )
                self.assertNotIn("alreadyPresent", recursive_strings(result))
                self.assert_v1_predecessor_evidence_is_a_typed_blocker(result)

    def test_cli_uses_explicit_bare_repository_and_still_exits_blocked(self) -> None:
        completed = subprocess.run(
            [
                sys.executable,
                str(SCRIPT),
                "--repository",
                str(self.fixture.repository),
            ],
            cwd=self.fixture.root,
            capture_output=True,
            text=True,
            check=False,
        )

        self.assertNotEqual(completed.returncode, 0)
        projection = json.loads(completed.stdout)
        self.assertEqual(projection["schema"], SCHEMA)
        self.assert_v1_predecessor_evidence_is_a_typed_blocker(projection)
        self.assertEqual(self.fixture.refs(), [])


if __name__ == "__main__":
    unittest.main()
