"""Contract tests for the non-authoritative A0.3a source-identity freeze."""

from __future__ import annotations

import builtins
import concurrent.futures
import hashlib
import importlib.util
import inspect
import json
import os
import subprocess
import sys
import tempfile
import threading
import unittest
from pathlib import Path
from types import ModuleType
from unittest import mock


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts" / "qinao_a03_design_source_identity.py"
FROZEN = (
    ROOT
    / "docs"
    / "superpowers"
    / "evidence"
    / "2026-08-29-qinao-a03-design-source-identity-freeze.json"
)
A02_FROZEN = (
    ROOT
    / "docs"
    / "superpowers"
    / "evidence"
    / "2026-08-29-qinao-a02-provisional-review-projection.json"
)
PREDECESSOR_OBSERVATION = (
    ROOT
    / "docs"
    / "superpowers"
    / "evidence"
    / "2026-08-29-qinao-a03-v1-predecessor-repository-observation.json"
)
CUSTODY_DIRECTORY = Path(
    os.environ.get(
        "QINAO_A03_CUSTODY_DIRECTORY",
        (
            "/Users/changgeng/Library/Application Support/Qinao/"
            "EvidenceVault/a0-2-provisional-projection"
        ),
    )
)

SCHEMA = "qinao-a03-design-source-identity-freeze-v1"
A02_SCHEMA = "qinao-a02-provisional-review-projection-v1"
A02_COMMIT = "bef9cea290d161da7510c6624bc676fd181cfd10"
A02_TREE = "26495bad43991149264c177fbb01212da952f464"
A02_PROJECTION_DIGEST = (
    "cf8290927c19deddc37938f7ded85a985a286923ab1501d5401879149fcb8298"
)
A02_FROZEN_SHA256 = (
    "cab70d307dd1e289850fe741b67ad64c9a252913ddccd9ba00c13d1b065f6f2b"
)
A03_FROZEN_SHA256 = (
    "1d0d81ef032b5babb9f954ce1f3a6d98bb56c120011ea4aaa136e16a41568f17"
)
BOOTSTRAP_COMMIT = "7e4aa2d626e2c94b1b1f3405fb8454e73448514f"
BOOTSTRAP_TREE = "47304602b7d1c1eba8eed571dbc65ee36c3a5f21"
REVIEW_BASE_TREE = "4fd48205c1716f9ce23efd8885c94afdcdf70311"
CANDIDATE_TREE = "0fa81fb9d1c3498fd8bb75d4c46a048f3b64260e"

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

CUSTODY_BUNDLE_SHA256 = (
    "3b29335f12ae680329e19723b1f292641a66358ae47a04a1ee996957b034b36f"
)
CUSTODY_MANIFEST_SHA256 = (
    "674cb04da3d5ab80d3f22cb6a52494f4a6e8c36947a0755faff1ddf2b718fd70"
)
CUSTODY_REVIEW_SHA256 = (
    "5b01e9705e54a46699f77efa9f0a5bfa064ed8358b15399dbcec9c50037a7371"
)

BLOCKERS = [
    "BLOCKED_GOVERNED_V1_TRANSITION02_PREDECESSOR_TERMINAL_NOT_BOUND",
    "BLOCKED_V1_TRANSITION02_PREDECESSOR_TERMINAL_SHAPE_REQUIRES_EXTERNAL_AMENDMENT",
    "BLOCKED_EXTERNALLY_GOVERNED_V2_DESIGN_EDGE_SCHEMA_SCOPE_NOT_BOUND",
    "BLOCKED_CONTROLLER_DURABLE_CLAIM_AND_PRIVATE_SOURCE_EPOCH_NOT_BOUND",
    "BLOCKED_SAME_UID_CAPABILITY_ISOLATION_NOT_PROVEN",
]

ZERO_EFFECTS = {
    "externalSignerCalls": 0,
    "externalReceiptAcceptanceCalls": 0,
    "controllerClaimCalls": 0,
    "authorityCommitCalls": 0,
    "protectedRefCASCalls": 0,
    "installCalls": 0,
}

EXPECTED_CUSTODY = {
    "classification": (
        "canonicalPathRepositoryExternalModeRestrictedCustodyObservation"
    ),
    "repositorySeparation": {
        "canonicalPathWorktreeDisjoint": True,
        "canonicalPathAllRegisteredWorktreesDisjoint": True,
        "canonicalPathGitDirectoryDisjoint": True,
        "canonicalPathGitCommonDirectoryDisjoint": True,
        "canonicalPathPrimaryObjectDatabaseDisjoint": True,
        "primaryObjectDatabaseAlternatesFile": "absent",
        "primaryObjectDatabaseHttpAlternatesFile": "absent",
        "environmentAlternateObjectDatabasesInherited": False,
        "mountAliasIsolation": "notProven",
    },
    "capsule": {
        "file": "qinao-a02-nonauthoritative-object-capsule.bundle",
        "bytes": 327689560,
        "sha256": CUSTODY_BUNDLE_SHA256,
    },
    "manifest": {
        "file": "MANIFEST.sha256",
        "sha256": CUSTODY_MANIFEST_SHA256,
        "targetCount": 3,
    },
    "postcommitReview": {
        "file": "qinao-a02-postcommit-custody-receipt.json",
        "sha256": CUSTODY_REVIEW_SHA256,
    },
    "recoveryGuide": {
        "file": "RECOVERY.md",
        "sha256": (
            "0d0d7f4d7cc5278e1f3e98d5be857edda6799aa09a3a0f8324656c7cd5337277"
        ),
    },
    "bundle": {
        "gitBundleVerify": "pass",
        "completeHistory": True,
        "objectFormat": "sha1",
        "refs": [
            {
                "ref": "refs/heads/codex/qinao-a02-provisional-verifier-20260828",
                "oid": A02_COMMIT,
            },
            {
                "ref": "refs/heads/codex/qinao-p0-preservation-20260828",
                "oid": "4a9298db261bcfda97ea1748baad65649156ba66",
            },
            {
                "ref": "refs/heads/codex/qinao-dual-space-design",
                "oid": BOOTSTRAP_COMMIT,
            },
        ],
    },
    "filesystem": {
        "currentUidOwned": True,
        "directoryPosixMode0700": True,
        "filesPosixMode0400": True,
        "filesSingleLink": True,
        "userImmutable": True,
        "symlinksAccepted": False,
        "aclIsolation": "notProven",
        "sameUidCapabilityIsolation": "notProven",
        "directoryFdAnchored": True,
        "allFileDescriptorsHeldAcrossObservation": True,
        "bundleGitVerificationInput": "sameOpenFileObjectAsDigest",
        "postGitContentRehash": True,
    },
    "selfContainedForA02RequiredGitObjects": True,
    "selfContainedForAllExternalGitLFSPayloads": False,
    "controllerDurableClaimBound": False,
    "incumbentArtifactMeshReceiptBound": False,
    "semanticAuthority": "none",
}

EXPECTED_EXECUTION_ISOLATION = {
    "writeCapableGitInput": (
        "ephemeralPrivateBareRepositoryFromHeldCustodyBundle"
    ),
    "bundleMaterialization": {
        "inputMechanism": "gitBundleUnbundleFromHeldDescriptor",
        "sourcePathReopenUsed": False,
        "ordinaryCopyFallbackUsed": False,
        "hardlinkFallbackUsed": False,
        "liveSourceObjectDatabaseFallbackUsed": False,
        "exactBundleHeadsMatched": True,
    },
    "sourceRepositoryObjectDatabaseObservation": (
        "boundedSelectedMetadataEndpointInventoryEqualBeforeAfter"
    ),
    "privateEphemeralObjectMetadataMayChange": True,
    "liveSourceObjectDatabaseUsedAsAlternate": False,
    "runtimeOwnershipProtocol": "singlePinnedA02ScratchLeaseProtocol",
    "nestedLeaseCount": 2,
    "runtimeRootReboundAndRestored": True,
}

FORBIDDEN_PUBLIC_ARGUMENT_WORDS = {
    "receipt",
    "signer",
    "claim",
    "operation",
    "controller",
    "trust",
    "ref",
    "commit",
    "install",
    "admit",
    "accept",
}


def git_observation(*arguments: str) -> bytes:
    environment = {
        key: value
        for key, value in os.environ.items()
        if not key.startswith("GIT_")
    }
    environment.update(
        {
            "GIT_CONFIG_NOSYSTEM": "1",
            "GIT_CONFIG_GLOBAL": "/dev/null",
            "GIT_OPTIONAL_LOCKS": "0",
            "GIT_PAGER": "cat",
            "GIT_TERMINAL_PROMPT": "0",
            "LC_ALL": "C",
            "PATH": "/usr/bin:/bin",
        }
    )
    return subprocess.run(
        [
            "/usr/bin/git",
            "-C",
            str(ROOT),
            "-c",
            "filter.lfs.process=",
            "-c",
            "filter.lfs.clean=",
            "-c",
            "filter.lfs.required=false",
            *arguments,
        ],
        cwd=ROOT,
        env=environment,
        capture_output=True,
        check=True,
    ).stdout


def repository_observation() -> dict[str, object]:
    index_path = Path(
        git_observation("rev-parse", "--path-format=absolute", "--git-path", "index")
        .decode("utf-8", "strict")
        .strip()
    )
    objects_path = Path(
        git_observation(
            "rev-parse",
            "--path-format=absolute",
            "--git-path",
            "objects",
        )
        .decode("utf-8", "strict")
        .strip()
    )
    object_inventory = []
    for path in sorted(objects_path.rglob("*")):
        if path.is_file():
            metadata = path.stat()
            object_inventory.append(
                (
                    str(path.relative_to(objects_path)),
                    metadata.st_size,
                    metadata.st_mtime_ns,
                )
            )
    return {
        "head": git_observation("rev-parse", "HEAD"),
        "symbolicHead": git_observation("symbolic-ref", "-q", "HEAD"),
        "refs": git_observation(
            "for-each-ref",
            "--format=%(refname)%00%(objectname)%00%(objecttype)",
        ),
        "indexSha256": hashlib.sha256(index_path.read_bytes()).hexdigest(),
        "status": git_observation(
            "status",
            "--porcelain=v2",
            "-z",
            "--untracked-files=all",
        ),
        "objectInventory": object_inventory,
    }


def repository_observation_for_path(repository: Path) -> dict[str, object]:
    environment = {
        key: value
        for key, value in os.environ.items()
        if not key.startswith("GIT_")
    }
    environment.update(
        {
            "GIT_CONFIG_NOSYSTEM": "1",
            "GIT_CONFIG_GLOBAL": "/dev/null",
            "GIT_OPTIONAL_LOCKS": "0",
            "GIT_PAGER": "cat",
            "GIT_TERMINAL_PROMPT": "0",
            "LC_ALL": "C",
            "PATH": "/usr/bin:/bin",
        }
    )

    def observe(*arguments: str) -> bytes:
        return subprocess.run(
            ["/usr/bin/git", "-C", str(repository), *arguments],
            cwd=repository,
            env=environment,
            capture_output=True,
            check=True,
        ).stdout

    index = Path(
        observe("rev-parse", "--path-format=absolute", "--git-path", "index")
        .decode("utf-8", "strict")
        .strip()
    )
    objects = Path(
        observe("rev-parse", "--path-format=absolute", "--git-path", "objects")
        .decode("utf-8", "strict")
        .strip()
    )
    inventory: list[tuple[object, ...]] = []
    for path in sorted(objects.rglob("*")):
        metadata = path.lstat()
        inventory.append(
            (
                str(path.relative_to(objects)),
                metadata.st_mode,
                metadata.st_ino,
                metadata.st_nlink,
                metadata.st_size,
                metadata.st_mtime_ns,
                metadata.st_ctime_ns,
                getattr(metadata, "st_flags", 0),
            )
        )
    return {
        "head": observe("rev-parse", "HEAD"),
        "refs": observe(
            "for-each-ref",
            "--format=%(refname)%00%(objectname)%00%(objecttype)",
        ),
        "indexSha256": hashlib.sha256(index.read_bytes()).hexdigest(),
        "status": observe("status", "--porcelain=v2", "-z", "--untracked-files=all"),
        "objectInventory": inventory,
    }


def load_subject() -> tuple[ModuleType | None, BaseException | None]:
    if not SCRIPT.is_file():
        return None, FileNotFoundError(SCRIPT)
    try:
        spec = importlib.util.spec_from_file_location(
            "scripts.qinao_a03_design_source_identity",
            SCRIPT,
        )
        if spec is None or spec.loader is None:
            raise ImportError(f"could not load {SCRIPT}")
        module = importlib.util.module_from_spec(spec)
        sys.modules[spec.name] = module
        spec.loader.exec_module(module)
        return module, None
    except BaseException as error:
        return None, error


SUBJECT, SUBJECT_LOAD_ERROR = load_subject()


def recursive_strings(value: object) -> list[str]:
    if isinstance(value, str):
        return [value]
    if isinstance(value, dict):
        result: list[str] = []
        for key, child in value.items():
            result.append(str(key))
            result.extend(recursive_strings(child))
        return result
    if isinstance(value, list):
        result = []
        for child in value:
            result.extend(recursive_strings(child))
        return result
    return []


class A03TDDRedGate(unittest.TestCase):
    def test_source_identity_implementation_exists_and_imports(self) -> None:
        self.assertTrue(SCRIPT.is_file(), f"missing implementation: {SCRIPT}")
        self.assertIsNone(SUBJECT_LOAD_ERROR)
        self.assertIsNotNone(SUBJECT)


@unittest.skipUnless(SUBJECT is not None, "A0.3a implementation is still RED")
class A03DesignSourceIdentityContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        assert SUBJECT is not None
        cls.subject = SUBJECT
        cls.historical_a02 = json.loads(A02_FROZEN.read_text(encoding="utf-8"))
        with mock.patch.object(
            SUBJECT,
            "_prepare_projection_and_observe_custody",
            return_value=(
                cls.historical_a02,
                EXPECTED_EXECUTION_ISOLATION,
                EXPECTED_CUSTODY,
            ),
        ):
            cls.result = SUBJECT.prepare_identity_freeze(ROOT, CUSTODY_DIRECTORY)

    def test_public_surface_cannot_express_authority_material(self) -> None:
        signature = inspect.signature(self.subject.prepare_identity_freeze)
        self.assertEqual(
            list(signature.parameters),
            ["repository", "custody_directory"],
        )
        for name in signature.parameters:
            lowered = name.lower()
            self.assertFalse(
                any(word in lowered for word in FORBIDDEN_PUBLIC_ARGUMENT_WORDS)
            )

        completed = subprocess.run(
            [sys.executable, str(SCRIPT), "--help"],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=True,
        )
        self.assertIn("--repository", completed.stdout)
        self.assertIn("--custody-directory", completed.stdout)
        for option in (
            "--receipt",
            "--signer",
            "--claim",
            "--operation",
            "--controller",
            "--trust-root",
            "--ref",
            "--commit",
            "--install",
            "--admit",
            "--accept",
        ):
            self.assertNotIn(option, completed.stdout)
        with self.assertRaises(TypeError):
            self.subject.prepare_identity_freeze(
                ROOT,
                CUSTODY_DIRECTORY,
                signer="forbidden",
            )

    def test_private_repo_unbundle_consumes_held_descriptor_after_path_move(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory(prefix="qinao-a03-held-unbundle-") as root:
            base = Path(root)
            repository = base / "repository"
            environment = self.subject._git_environment()

            def run_git(*arguments: str) -> bytes:
                return subprocess.run(
                    ["/usr/bin/git", *arguments],
                    cwd=base,
                    env=environment,
                    capture_output=True,
                    check=True,
                ).stdout

            run_git("init", str(repository))
            (repository / "README.md").write_text("fixture\n", encoding="utf-8")
            run_git("-C", str(repository), "add", "README.md")
            run_git(
                "-C",
                str(repository),
                "-c",
                "user.name=Qinao Test",
                "-c",
                "user.email=qinao-test@example.invalid",
                "commit",
                "-m",
                "fixture",
            )
            original = base / "original.bundle"
            moved = base / "moved-after-open.bundle"
            run_git("-C", str(repository), "bundle", "create", str(original), "--all")
            descriptor = os.open(original, os.O_RDONLY)
            original.rename(moved)
            bundle_before = os.fstat(descriptor)
            expected_heads = run_git("bundle", "list-heads", str(moved)).rstrip(b"\n")
            session = base / "session"
            session.mkdir(mode=0o700)
            try:
                private, observation = (
                    self.subject._materialize_private_repository_from_held_bundle(
                        session,
                        descriptor,
                        bundle_before,
                        expected_heads=expected_heads,
                    )
                )
                bundle_after = os.fstat(descriptor)
            finally:
                os.close(descriptor)
            self.assertEqual(
                self.subject._identity_tuple(bundle_after),
                self.subject._identity_tuple(bundle_before),
            )
            self.assertFalse(original.exists())
            run_git("-C", str(private), "fsck", "--full", "--strict")
            self.assertEqual(
                observation,
                {
                    "inputMechanism": "gitBundleUnbundleFromHeldDescriptor",
                    "sourcePathReopenUsed": False,
                    "ordinaryCopyFallbackUsed": False,
                    "hardlinkFallbackUsed": False,
                    "liveSourceObjectDatabaseFallbackUsed": False,
                    "exactBundleHeadsMatched": True,
                },
            )

    def test_invalid_held_bundle_fails_closed_without_source_fallback(self) -> None:
        with tempfile.TemporaryDirectory(prefix="qinao-a03-unbundle-fail-") as root:
            base = Path(root)
            source = base / "source.bundle"
            source.write_bytes(b"not a Git bundle\n")
            descriptor = os.open(source, os.O_RDONLY)
            before = os.fstat(descriptor)
            session = base / "session"
            session.mkdir(mode=0o700)
            try:
                with self.assertRaises(self.subject.SourceIsolationError):
                    self.subject._materialize_private_repository_from_held_bundle(
                        session,
                        descriptor,
                        before,
                        expected_heads=b"unreachable",
                    )
                after = os.fstat(descriptor)
            finally:
                os.close(descriptor)
            self.assertEqual(
                self.subject._identity_tuple(after),
                self.subject._identity_tuple(before),
            )
            self.assertFalse(
                (
                    session
                    / self.subject.PRIVATE_REPOSITORY_NAME
                    / "objects"
                    / "info"
                    / "alternates"
                ).exists()
            )

    def test_pinned_a02_executes_only_against_bundle_materialized_private_repo(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory(prefix="qinao-a03-private-a02-") as root:
            base = Path(root)
            repository = base / "repository"
            environment = self.subject._git_environment()

            def run_git(*arguments: str) -> bytes:
                return subprocess.run(
                    ["/usr/bin/git", *arguments],
                    cwd=base,
                    env=environment,
                    capture_output=True,
                    check=True,
                ).stdout

            run_git("init", str(repository))
            (repository / "README.md").write_text("fixture\n", encoding="utf-8")
            run_git("-C", str(repository), "add", "README.md")
            run_git(
                "-C",
                str(repository),
                "-c",
                "user.name=Qinao Test",
                "-c",
                "user.email=qinao-test@example.invalid",
                "commit",
                "-m",
                "fixture",
            )
            bundle = base / "fixture.bundle"
            run_git("-C", str(repository), "bundle", "create", str(bundle), "--all")
            expected_heads = run_git(
                "bundle",
                "list-heads",
                str(bundle),
            ).rstrip(b"\n")
            source_objects = repository / ".git" / "objects"
            source_before = repository_observation_for_path(repository)

            module = self.subject._load_pinned_a02_module()
            original_runtime_root = module.RUNTIME_ROOT
            observed: dict[str, object] = {}

            def fake_prepare(private_repository: Path) -> dict[str, object]:
                observed["repository"] = private_repository
                observed["runtimeRoot"] = module.RUNTIME_ROOT
                self.assertFalse(
                    (private_repository / "objects" / "info" / "alternates").exists()
                )
                self.assertFalse(
                    (private_repository / "objects" / "info" / "http-alternates").exists()
                )
                run_git("-C", str(private_repository), "fsck", "--full", "--strict")
                private_packs = list((private_repository / "objects" / "pack").glob("*.pack"))
                self.assertTrue(private_packs)
                old_ns = 1_600_000_000_000_000_000
                os.utime(private_packs[0], ns=(old_ns, old_ns))
                return {"projection": "sentinel"}

            module.prepare_provisional = fake_prepare
            descriptor = os.open(bundle, os.O_RDONLY)
            try:
                result, isolation = self.subject._execute_pinned_a02_from_bundle(
                    repository,
                    source_objects.resolve(strict=True),
                    descriptor,
                    os.fstat(descriptor),
                    module,
                    expected_heads=expected_heads,
                )
            finally:
                os.close(descriptor)

            self.assertEqual(result, {"projection": "sentinel"})
            self.assertEqual(module.RUNTIME_ROOT, original_runtime_root)
            self.assertEqual(
                isolation["writeCapableGitInput"],
                "ephemeralPrivateBareRepositoryFromHeldCustodyBundle",
            )
            self.assertEqual(
                source_before,
                repository_observation_for_path(repository),
            )
            self.assertFalse(Path(observed["repository"]).exists())
            self.assertEqual(
                Path(observed["runtimeRoot"]).name,
                "qinao-a02-provisional-runtime-v1",
            )

    def test_a02_loader_ignores_top_level_module_cache_pollution(self) -> None:
        fake = ModuleType("qinao_a02_provisional_design_edge")
        fake.GIT = Path("/usr/bin/false")
        fake.prepare_provisional = lambda _repository: {"attacker": True}
        previous = sys.modules.get("qinao_a02_provisional_design_edge")
        sys.modules["qinao_a02_provisional_design_edge"] = fake
        try:
            loaded = self.subject._load_pinned_a02_module()
        finally:
            if previous is None:
                sys.modules.pop("qinao_a02_provisional_design_edge", None)
            else:
                sys.modules["qinao_a02_provisional_design_edge"] = previous
        self.assertIsNot(loaded, fake)
        self.assertEqual(loaded.GIT, Path("/usr/bin/git"))
        self.assertEqual(
            hashlib.sha256(Path(loaded.__file__).read_bytes()).hexdigest(),
            self.subject.A02_SOURCE_SHA256,
        )

    def test_concurrent_a02_loads_restore_the_prior_private_module_mapping(
        self,
    ) -> None:
        private_name = self.subject.A02_PRIVATE_MODULE_NAME
        sentinel = ModuleType(private_name)
        previous = sys.modules.get(private_name)
        sys.modules[private_name] = sentinel
        try:
            with concurrent.futures.ThreadPoolExecutor(max_workers=8) as executor:
                loaded = list(
                    executor.map(
                        lambda _index: self.subject._load_pinned_a02_module(),
                        range(32),
                    )
                )
            self.assertIs(sys.modules.get(private_name), sentinel)
        finally:
            if previous is None:
                sys.modules.pop(private_name, None)
            else:
                sys.modules[private_name] = previous
        self.assertEqual(len({id(module) for module in loaded}), 32)
        self.assertTrue(
            all(module.RUNTIME_ROOT == self.subject.A02_RUNTIME_ROOT for module in loaded)
        )

    def test_aliased_a03_modules_share_the_process_loader_lock(self) -> None:
        aliases = (
            "scripts._qinao_a03_concurrency_alias_a",
            "scripts._qinao_a03_concurrency_alias_b",
        )
        previous_aliases = {name: sys.modules.get(name) for name in aliases}

        def load_alias(name: str) -> ModuleType:
            spec = importlib.util.spec_from_file_location(name, SCRIPT)
            if spec is None or spec.loader is None:
                raise ImportError(f"could not load alias {name}")
            module = importlib.util.module_from_spec(spec)
            sys.modules[name] = module
            spec.loader.exec_module(module)
            return module

        release_first = threading.Event()
        try:
            first = load_alias(aliases[0])
            second = load_alias(aliases[1])
            self.assertIs(
                first._PINNED_A02_PROCESS_LOCK,
                second._PINNED_A02_PROCESS_LOCK,
            )

            private_name = first.A02_PRIVATE_MODULE_NAME
            sentinel = ModuleType(private_name)
            previous_private = sys.modules.get(private_name)
            sys.modules[private_name] = sentinel
            real_compile = builtins.compile
            first_reached_compile = threading.Event()
            second_reached_compile = threading.Event()

            def slow_first_compile(*args: object, **kwargs: object) -> object:
                first_reached_compile.set()
                if not release_first.wait(5):
                    raise TimeoutError("first alias compile release timed out")
                return real_compile(*args, **kwargs)

            def observed_second_compile(*args: object, **kwargs: object) -> object:
                second_reached_compile.set()
                return real_compile(*args, **kwargs)

            first.compile = slow_first_compile
            second.compile = observed_second_compile
            try:
                with concurrent.futures.ThreadPoolExecutor(max_workers=2) as executor:
                    first_future = executor.submit(first._load_pinned_a02_module)
                    self.assertTrue(first_reached_compile.wait(5))
                    second_future = executor.submit(second._load_pinned_a02_module)
                    overlapped = second_reached_compile.wait(0.25)
                    release_first.set()
                    loaded = (first_future.result(), second_future.result())
                self.assertFalse(overlapped)
                self.assertTrue(second_reached_compile.is_set())
                self.assertIs(sys.modules.get(private_name), sentinel)
                self.assertIsNot(loaded[0], loaded[1])
            finally:
                release_first.set()
                if previous_private is None:
                    sys.modules.pop(private_name, None)
                else:
                    sys.modules[private_name] = previous_private
        finally:
            for name, previous in previous_aliases.items():
                if previous is None:
                    sys.modules.pop(name, None)
                else:
                    sys.modules[name] = previous

    def test_replaced_process_state_holder_fails_closed(self) -> None:
        state_name = self.subject._PROCESS_STATE_MODULE_NAME
        previous = sys.modules.get(state_name)
        self.assertIs(previous, self.subject._PROCESS_STATE_HOLDER)
        sys.modules[state_name] = ModuleType(state_name)
        try:
            with self.assertRaisesRegex(
                self.subject.PinnedA02Error,
                "process-state holder changed",
            ):
                self.subject._load_pinned_a02_module()
        finally:
            if previous is None:
                sys.modules.pop(state_name, None)
            else:
                sys.modules[state_name] = previous

    def test_a02_loader_rejects_same_length_source_byte_drift(self) -> None:
        source = SCRIPT.with_name("qinao_a02_provisional_design_edge.py").read_bytes()
        changed = bytearray(source)
        changed[len(changed) // 2] ^= 1
        with tempfile.TemporaryDirectory(prefix="qinao-a03-a02-source-") as root:
            candidate = Path(root) / "qinao_a02_provisional_design_edge.py"
            candidate.write_bytes(changed)
            candidate.chmod(0o644)
            with self.assertRaises(self.subject.PinnedA02Error):
                self.subject._verified_a02_source_bytes(candidate)

    def test_exact_ordered_design_source_identity_is_frozen_separately(self) -> None:
        identity = self.result["designSourceIdentity"]
        self.assertEqual(identity["orderedSourceTuples"], SOURCE_TUPLES)
        self.assertEqual(
            identity["sourceObservations"],
            [
                {
                    "role": "design08_02ReviewSource",
                    "commitOid": "c8f80486895e12e26d567e610c35a6e2141b3489",
                    "treeOid": "2f484874b8b6d49b8bcd595bf3a3ff6c835fb509",
                    "tuple": SOURCE_TUPLES[0],
                    "semanticAuthority": "none",
                },
                {
                    "role": "design08_10PreservationSource",
                    "commitOid": "4a9298db261bcfda97ea1748baad65649156ba66",
                    "treeOid": "22382c1de6680a263ec4a2f4a6c989c0f0e6e220",
                    "tuple": SOURCE_TUPLES[1],
                    "semanticAuthority": "none",
                },
            ],
        )
        self.assertEqual(identity["orderMeaning"], "08-02-then-08-10")

    def test_projection_identity_is_exact_and_not_the_preservation_tree(self) -> None:
        projection = self.result["designProjectionIdentity"]
        self.assertEqual(projection["a02Commit"], A02_COMMIT)
        self.assertEqual(projection["a02Tree"], A02_TREE)
        self.assertEqual(projection["a02ProjectionDigest"], A02_PROJECTION_DIGEST)
        self.assertEqual(projection["bootstrapCommit"], BOOTSTRAP_COMMIT)
        self.assertEqual(projection["bootstrapTree"], BOOTSTRAP_TREE)
        self.assertEqual(projection["reviewBaseTree"], REVIEW_BASE_TREE)
        self.assertEqual(projection["transitionCandidateTree"], CANDIDATE_TREE)
        self.assertEqual(projection["changedEntryCount"], 1)
        self.assertEqual(projection["onlyChangedPath"], PATH_0810)
        self.assertNotEqual(
            projection["transitionCandidateTree"],
            "22382c1de6680a263ec4a2f4a6c989c0f0e6e220",
        )

    def test_custody_epoch_is_content_addressed_but_explicitly_non_authoritative(
        self,
    ) -> None:
        custody = self.result["custodyEvidence"]
        self.assertEqual(custody, EXPECTED_CUSTODY)

    def test_authority_gate_is_closed_nonwaivable_and_effect_free(self) -> None:
        self.assertEqual(self.result["schema"], SCHEMA)
        self.assertEqual(self.result["semanticAuthority"], "none")
        self.assertTrue(self.result["nonAuthoritative"])
        self.assertFalse(self.result["installable"])
        self.assertFalse(self.result["a03Complete"])
        self.assertEqual(
            self.result["derivation"],
            {
                "derivationSource": "A0.2.prepare_provisional",
                "verificationInheritance": (
                    "fixedIdentityFactsOnlyWithBoundErratum"
                ),
                "independentFailureDomains": False,
                "sourceObjectEpochBinding": "notProven",
                "executionIsolation": EXPECTED_EXECUTION_ISOLATION,
                "historicalA02ClaimDisposition": {
                    "jsonPointer": (
                        "/deterministicProjection/sharedObjectDatabaseWrites"
                    ),
                    "historicalValue": 0,
                    "status": "supersededAsOverbroad",
                    "counterexample": (
                        "alternatePackedObjectMtimeFreshenObserved"
                    ),
                    "acceptedSemanticScope": "none",
                    "boundErratum": {
                        "relativePath": (
                            "docs/superpowers/evidence/"
                            "2026-08-29-qinao-a02-shared-object-database-"
                            "writes-erratum.json"
                        ),
                        "byteLength": 3446,
                        "sha256": (
                            "4e51270815584488bbd33054ff7b61f2c4f7ea9040f98ed5e"
                            "86aa1bf3ae8b93a"
                        ),
                        "schema": (
                            "qinao-a02-provisional-review-projection-v1-"
                            "erratum-v1"
                        ),
                    },
                },
                "a02Implementation": {
                    "relativePath": "scripts/qinao_a02_provisional_design_edge.py",
                    "byteLength": 51142,
                    "gitBlob": "75f7ef3a7a05b06d454d49ec407a14034bdfd9e6",
                    "sha256": (
                        "9229f962f9581f7f942b5f08838f0f9199810dc366e62b03"
                        "cc0206fe68f09f0d"
                    ),
                    "loadMethod": "verifiedBytesDirectExecPerInvocation",
                },
                "a02OutputValidation": "fullCanonicalBytesSha256",
            },
        )
        self.assertEqual(
            self.result["phase"],
            {
                "stage": "A0.3a",
                "completion": "partialBlocked",
                "opensA04": False,
            },
        )
        self.assertEqual(
            self.result["predecessorEvidence"],
            {
                "governedInputState": "notBound",
                "globalNonexistenceClaimed": False,
                "historicalV1TerminalVariants": [
                    "signedDesignEdgeReceipt",
                    "exactAlreadyPresentTerminal",
                ],
                "requiredShapeResolution": "externalAmendmentRequired",
            },
        )
        gate = self.result["authorityGate"]
        self.assertEqual(gate["state"], "blocked")
        self.assertEqual(
            gate["blockers"],
            [{"code": code, "waivable": False} for code in BLOCKERS],
        )
        self.assertEqual(gate["currentCodePathEffects"], ZERO_EFFECTS)

        terminal_values = {"admitted", "alreadyPresent", "accepted", "installed"}
        self.assertTrue(
            terminal_values.isdisjoint(set(recursive_strings(self.result)))
        )

    def test_identity_bytes_and_digest_are_deterministic_and_domain_separated(
        self,
    ) -> None:
        with mock.patch.object(
            self.subject,
            "_prepare_projection_and_observe_custody",
            return_value=(
                self.historical_a02,
                EXPECTED_EXECUTION_ISOLATION,
                EXPECTED_CUSTODY,
            ),
        ):
            second = self.subject.prepare_identity_freeze(ROOT, CUSTODY_DIRECTORY)
        self.assertEqual(self.result, second)
        digest = self.result["identityDigest"]
        unsigned = dict(self.result)
        unsigned.pop("identityDigest")
        canonical = json.dumps(
            unsigned,
            ensure_ascii=False,
            sort_keys=True,
            separators=(",", ":"),
        ).encode("utf-8")
        expected = hashlib.sha256(
            b"QINAO-A03-DESIGN-SOURCE-IDENTITY-FREEZE-V1\0"
            + len(canonical).to_bytes(8, "big")
            + canonical
        ).hexdigest()
        self.assertEqual(digest, expected)
        self.assertNotEqual(digest, A02_PROJECTION_DIGEST)

    def test_a02_drift_fails_closed_instead_of_freezing_a_new_identity(self) -> None:
        drifted = json.loads(json.dumps(self.historical_a02))
        drifted["projectionDigest"] = "0" * 64
        with mock.patch.object(
            self.subject,
            "_prepare_projection_and_observe_custody",
            return_value=(
                drifted,
                EXPECTED_EXECUTION_ISOLATION,
                EXPECTED_CUSTODY,
            ),
        ):
            with self.assertRaises(self.subject.SourceIdentityError):
                self.subject.prepare_identity_freeze(ROOT, CUSTODY_DIRECTORY)

    def test_full_a02_output_identity_rejects_effect_or_extra_field_drift(self) -> None:
        mutations = {
            "authority-effect": lambda value: value["authorityGate"][
                "currentCodePathEffects"
            ].__setitem__("authoritySignerCalls", 1),
            "extra-field": lambda value: value.__setitem__("unexpected", True),
            "wrong-blocker": lambda value: value["authorityGate"]["blockers"][
                0
            ].__setitem__("code", "BLOCKED_DIFFERENT"),
        }
        original = self.historical_a02
        for label, mutate in mutations.items():
            with self.subTest(label=label):
                changed = json.loads(json.dumps(original))
                mutate(changed)
                with mock.patch.object(
                    self.subject,
                    "_prepare_projection_and_observe_custody",
                    return_value=(
                        changed,
                        EXPECTED_EXECUTION_ISOLATION,
                        EXPECTED_CUSTODY,
                    ),
                ):
                    with self.assertRaises(self.subject.SourceIdentityError):
                        self.subject.prepare_identity_freeze(
                            ROOT,
                            CUSTODY_DIRECTORY,
                        )

    def test_custody_observation_failure_cannot_freeze_expected_constants(self) -> None:
        with mock.patch.object(
            self.subject,
            "_prepare_projection_and_observe_custody",
            side_effect=self.subject.CustodyError("tampered custody"),
        ):
            with self.assertRaises(self.subject.CustodyError):
                self.subject.prepare_identity_freeze(ROOT, CUSTODY_DIRECTORY)

    def test_custody_review_rejects_authority_scope_ref_and_ds3_drift(self) -> None:
        if not CUSTODY_DIRECTORY.is_dir():
            self.skipTest("bound repository-external custody is unavailable")
        raw = (CUSTODY_DIRECTORY / self.subject.CUSTODY_REVIEW_NAME).read_text(
            encoding="utf-8"
        )
        original = json.loads(raw)

        mutations = {
            "authority-upgrade": lambda value: value["authority"].__setitem__(
                "semanticAuthority", "local"
            ),
            "lfs-scope-upgrade": lambda value: value["capsule"]["scope"].__setitem__(
                "selfContainedForAllExternalGitLFSPayloads", True
            ),
            "bundle-ref-drift": lambda value: value["capsule"]["refs"][0].__setitem__(
                "oid", "0" * 40
            ),
            "ds3-boundary-drift": lambda value: value["hardGates"].__setitem__(
                "deepScan3", "authorized"
            ),
        }
        for label, mutate in mutations.items():
            with self.subTest(label=label):
                changed = json.loads(json.dumps(original))
                mutate(changed)
                with self.assertRaises(self.subject.CustodyError):
                    self.subject._validate_custody_review(changed)

    def test_all_linked_worktrees_git_storage_and_ancestor_custody_are_rejected(
        self,
    ) -> None:
        roots, _snapshot = self.subject._repository_storage_roots(ROOT)
        registered = {
            path
            for label, path in roots.items()
            if label.startswith("registeredWorktree[")
        }
        self.assertGreaterEqual(len(registered), 1)
        self.assertIn(ROOT, registered)
        candidates = set(roots.values())
        common_ancestor = Path(os.path.commonpath([str(path) for path in candidates]))
        candidates.add(common_ancestor.resolve(strict=True))
        for candidate in sorted(candidates):
            with self.subTest(candidate=str(candidate)):
                with self.assertRaises(self.subject.CustodyError):
                    self.subject._require_repository_external_custody(
                        ROOT,
                        candidate.resolve(strict=True),
                    )

    def test_temporary_second_linked_worktree_overlap_fails_closed(self) -> None:
        with tempfile.TemporaryDirectory(prefix="qinao-a03-linked-worktree-") as root:
            base = Path(root)
            repository = base / "repository"
            sibling = base / "sibling"
            environment = self.subject._git_environment()

            def run_git(*arguments: str) -> None:
                subprocess.run(
                    ["/usr/bin/git", *arguments],
                    cwd=base,
                    env=environment,
                    capture_output=True,
                    check=True,
                )

            run_git("init", str(repository))
            (repository / "README.md").write_text("base\n", encoding="utf-8")
            run_git("-C", str(repository), "add", "README.md")
            run_git(
                "-C",
                str(repository),
                "-c",
                "user.name=Qinao Test",
                "-c",
                "user.email=qinao-test@example.invalid",
                "commit",
                "-m",
                "base",
            )
            run_git(
                "-C",
                str(repository),
                "worktree",
                "add",
                "-b",
                "test-sibling",
                str(sibling),
            )
            roots, _snapshot = self.subject._repository_storage_roots(repository)
            registered = {
                path
                for label, path in roots.items()
                if label.startswith("registeredWorktree[")
            }
            self.assertEqual(registered, {repository.resolve(), sibling.resolve()})
            candidate = sibling / "custody"
            candidate.mkdir()
            with self.assertRaises(self.subject.CustodyError):
                self.subject._require_repository_external_custody(
                    repository,
                    candidate,
                )

    def test_shared_clone_alternate_object_database_fails_closed(self) -> None:
        with tempfile.TemporaryDirectory(prefix="qinao-a03-shared-clone-") as root:
            base = Path(root)
            source = base / "source.git"
            clone = base / "clone"
            subprocess.run(
                ["/usr/bin/git", "init", "--bare", str(source)],
                cwd=base,
                env=self.subject._git_environment(),
                capture_output=True,
                check=True,
            )
            subprocess.run(
                ["/usr/bin/git", "clone", "--shared", str(source), str(clone)],
                cwd=base,
                env=self.subject._git_environment(),
                capture_output=True,
                check=True,
            )
            alternates = clone / ".git" / "objects" / "info" / "alternates"
            self.assertTrue(alternates.is_file())
            alternate_database = Path(
                alternates.read_text(encoding="utf-8").strip()
            ).resolve(strict=True)
            candidate = alternate_database / "custody"
            candidate.mkdir()
            with self.assertRaises(self.subject.CustodyError):
                self.subject._require_repository_external_custody(
                    clone,
                    candidate,
                )

    def test_git_bundle_observation_consumes_the_held_descriptor(self) -> None:
        if not CUSTODY_DIRECTORY.is_dir():
            self.skipTest("bound repository-external custody is unavailable")
        descriptor = os.open(
            CUSTODY_DIRECTORY / self.subject.CUSTODY_BUNDLE_NAME,
            os.O_RDONLY | getattr(os, "O_CLOEXEC", 0),
        )
        try:
            observed = self.subject._run_bound_bundle_command(
                descriptor,
                "list-heads",
                ROOT,
            ).rstrip(b"\n")
        finally:
            os.close(descriptor)
        self.assertEqual(observed, self.subject._EXPECTED_LIST_HEADS)

    def test_bundle_git_environment_is_allowlisted_and_explicitly_limited(self) -> None:
        environment = self.subject._git_environment()
        self.assertEqual(
            set(environment),
            {
                "GIT_CONFIG_NOSYSTEM",
                "GIT_CONFIG_GLOBAL",
                "GIT_CONFIG_COUNT",
                "GIT_CONFIG_KEY_0",
                "GIT_CONFIG_VALUE_0",
                "GIT_CONFIG_KEY_1",
                "GIT_CONFIG_VALUE_1",
                "GIT_CONFIG_KEY_2",
                "GIT_CONFIG_VALUE_2",
                "GIT_NO_REPLACE_OBJECTS",
                "GIT_NO_LAZY_FETCH",
                "GIT_ATTR_NOSYSTEM",
                "GIT_OPTIONAL_LOCKS",
                "GIT_PAGER",
                "GIT_TERMINAL_PROMPT",
                "HOME",
                "LC_ALL",
                "PATH",
                "TMPDIR",
            },
        )
        self.assertNotIn("PYTHONPATH", environment)
        self.assertFalse(any(key.startswith("DYLD_") for key in environment))
        self.assertEqual(environment["GIT_CONFIG_GLOBAL"], "/dev/null")
        self.assertEqual(environment["PATH"], "/usr/bin:/bin")

    def test_final_symlink_hardlink_wrong_mode_and_missing_flag_fail_closed(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory(prefix="qinao-a03-file-shape-") as root:
            directory = Path(root)
            directory_descriptor = os.open(
                directory,
                os.O_RDONLY | getattr(os, "O_DIRECTORY", 0),
            )
            try:
                wrong_mode = directory / "wrong-mode"
                wrong_mode.write_bytes(b"x")
                wrong_mode.chmod(0o644)
                with self.assertRaises(self.subject.CustodyError):
                    self.subject._open_mode_restricted_file(
                        directory_descriptor,
                        wrong_mode.name,
                        1,
                    )

                missing_flag = directory / "missing-flag"
                missing_flag.write_bytes(b"x")
                missing_flag.chmod(0o400)
                with self.assertRaises(self.subject.CustodyError):
                    self.subject._open_mode_restricted_file(
                        directory_descriptor,
                        missing_flag.name,
                        1,
                    )

                hardlink = directory / "hardlink"
                hardlink_source = directory / "hardlink-source"
                hardlink_source.write_bytes(b"x")
                hardlink_source.chmod(0o400)
                os.link(hardlink_source, hardlink)
                with self.assertRaises(self.subject.CustodyError):
                    self.subject._open_mode_restricted_file(
                        directory_descriptor,
                        hardlink.name,
                        1,
                    )

                symlink = directory / "symlink"
                os.symlink(wrong_mode.name, symlink)
                with self.assertRaises(OSError):
                    self.subject._open_mode_restricted_file(
                        directory_descriptor,
                        symlink.name,
                        1,
                    )
            finally:
                os.close(directory_descriptor)

    def test_directory_generation_swap_fails_closed(self) -> None:
        with tempfile.TemporaryDirectory(prefix="qinao-a03-dir-generation-") as root:
            parent = Path(root)
            original = parent / "custody"
            original.mkdir(mode=0o700)
            for name in self.subject._EXPECTED_NAMES:
                (original / name).write_bytes(b"")
            directory_descriptor = os.open(
                original,
                os.O_RDONLY | getattr(os, "O_DIRECTORY", 0),
            )
            directory_before = os.fstat(directory_descriptor)
            files: dict[str, tuple[int, os.stat_result]] = {}
            try:
                for name in self.subject._EXPECTED_NAMES:
                    descriptor = os.open(
                        name,
                        os.O_RDONLY,
                        dir_fd=directory_descriptor,
                    )
                    files[name] = (descriptor, os.fstat(descriptor))
                moved = parent / "custody-old"
                original.rename(moved)
                original.mkdir(mode=0o700)
                for name in self.subject._EXPECTED_NAMES:
                    (original / name).write_bytes(b"")
                with self.assertRaises(self.subject.CustodyError):
                    self.subject._require_same_custody_generation(
                        original,
                        directory_descriptor,
                        directory_before,
                        files,
                    )
            finally:
                for descriptor, _metadata in files.values():
                    os.close(descriptor)
                os.close(directory_descriptor)

    def test_cli_is_byte_reproducible_and_always_exits_blocked(self) -> None:
        if not CUSTODY_DIRECTORY.is_dir():
            self.skipTest("bound repository-external custody is unavailable")
        commands = [
            sys.executable,
            str(SCRIPT),
            "--repository",
            str(ROOT),
            "--custody-directory",
            str(CUSTODY_DIRECTORY),
        ]
        first = subprocess.run(
            commands,
            cwd=ROOT,
            capture_output=True,
            check=False,
        )
        second = subprocess.run(
            commands,
            cwd=ROOT,
            capture_output=True,
            check=False,
        )
        expected = (
            json.dumps(
                self.result,
                ensure_ascii=False,
                sort_keys=True,
                separators=(",", ":"),
            ).encode("utf-8")
            + b"\n"
        )
        self.assertEqual(first.returncode, self.subject.EXIT_BLOCKED)
        self.assertEqual(second.returncode, self.subject.EXIT_BLOCKED)
        self.assertEqual(first.stdout, expected)
        self.assertEqual(second.stdout, expected)
        self.assertEqual(first.stderr, b"")
        self.assertEqual(second.stderr, b"")

    def test_cli_leaves_head_refs_index_status_and_object_inventory_unchanged(
        self,
    ) -> None:
        if not CUSTODY_DIRECTORY.is_dir():
            self.skipTest("bound repository-external custody is unavailable")
        before = repository_observation()
        completed = subprocess.run(
            [
                sys.executable,
                str(SCRIPT),
                "--repository",
                str(ROOT),
                "--custody-directory",
                str(CUSTODY_DIRECTORY),
            ],
            cwd=ROOT,
            capture_output=True,
            check=False,
        )
        after = repository_observation()
        self.assertEqual(completed.returncode, self.subject.EXIT_BLOCKED)
        self.assertEqual(completed.stderr, b"")
        self.assertEqual(after, before)

    def test_missing_repository_is_typed_evaluation_unavailable(self) -> None:
        with tempfile.TemporaryDirectory(prefix="qinao-a03-missing-") as root:
            missing = Path(root) / "does-not-exist"
            completed = subprocess.run(
                [
                    sys.executable,
                    str(SCRIPT),
                    "--repository",
                    str(missing),
                    "--custody-directory",
                    str(CUSTODY_DIRECTORY),
                ],
                cwd=ROOT,
                capture_output=True,
                text=True,
                check=False,
            )
        self.assertEqual(completed.returncode, self.subject.EXIT_UNAVAILABLE)
        self.assertEqual(completed.stdout, "")
        unavailable = json.loads(completed.stderr)
        self.assertEqual(unavailable["schema"], SCHEMA)
        self.assertEqual(
            unavailable["evaluationDisposition"],
            "evaluationUnavailable",
        )
        self.assertEqual(unavailable["semanticAuthority"], "none")
        self.assertTrue(unavailable["nonAuthoritative"])
        self.assertFalse(unavailable["installable"])
        self.assertFalse(unavailable["a03Complete"])
        self.assertEqual(
            unavailable["phase"],
            {
                "completion": "evaluationUnavailable",
                "opensA04": False,
            },
        )
        self.assertEqual(
            unavailable["deepScan3"],
            "notStartedAndNotAuthorized",
        )
        self.assertEqual(unavailable["authorityGate"]["state"], "blocked")
        self.assertEqual(
            unavailable["authorityGate"]["currentCodePathEffects"],
            ZERO_EFFECTS,
        )

    def test_custody_symlink_loop_is_typed_evaluation_unavailable(self) -> None:
        with tempfile.TemporaryDirectory(prefix="qinao-a03-symlink-loop-") as root:
            base = Path(root)
            first = base / "first"
            second = base / "second"
            first.symlink_to(second.name)
            second.symlink_to(first.name)
            completed = subprocess.run(
                [
                    sys.executable,
                    str(SCRIPT),
                    "--repository",
                    str(ROOT),
                    "--custody-directory",
                    str(first),
                ],
                cwd=ROOT,
                capture_output=True,
                text=True,
                check=False,
            )
        self.assertEqual(completed.returncode, self.subject.EXIT_UNAVAILABLE)
        self.assertEqual(completed.stdout, "")
        self.assertNotIn("Traceback", completed.stderr)
        unavailable = json.loads(completed.stderr)
        self.assertEqual(
            unavailable["evaluationDisposition"],
            "evaluationUnavailable",
        )

    def test_frozen_evidence_is_exact_cli_output(self) -> None:
        self.assertTrue(FROZEN.is_file(), f"missing frozen evidence: {FROZEN}")
        expected = (
            json.dumps(
                self.result,
                ensure_ascii=False,
                sort_keys=True,
                separators=(",", ":"),
            ).encode("utf-8")
            + b"\n"
        )
        self.assertEqual(FROZEN.read_bytes(), expected)
        self.assertEqual(
            hashlib.sha256(FROZEN.read_bytes()).hexdigest(),
            A03_FROZEN_SHA256,
            "replace the RED placeholder only after independently freezing A0.3",
        )

    def test_predecessor_search_evidence_is_capability_scoped_only(self) -> None:
        self.assertTrue(
            PREDECESSOR_OBSERVATION.is_file(),
            f"missing predecessor observation: {PREDECESSOR_OBSERVATION}",
        )
        observation = json.loads(PREDECESSOR_OBSERVATION.read_text(encoding="utf-8"))
        self.assertEqual(
            observation["schema"],
            "qinao.a03-v1-predecessor-repository-observation.v1",
        )
        self.assertEqual(observation["semanticAuthority"], "none")
        self.assertFalse(observation["globalNonexistenceClaimed"])
        self.assertFalse(
            observation["requiredPredecessor"]["satisfiedWithinObservedScope"]
        )
        self.assertTrue(
            observation["capabilityScopedConclusion"][
                "externalEvidenceMayExistOutsideObservedScope"
            ]
        )
        self.assertFalse(
            observation["capabilityScopedConclusion"]["waivableByLocalInference"]
        )
        self.assertEqual(
            observation["expectedRefObservation"]["expectedProtectedRef"],
            "refs/heads/codex/qinao-admitted-controlled-convergence",
        )
        self.assertFalse(
            observation["fixtureDisposition"]["independentAuthorityInputEligible"]
        )
        self.assertFalse(
            observation["protectedPolicyAmbiguity"][
                "implementationMayInferOrSynthesize"
            ]
        )


@unittest.skipUnless(
    SUBJECT is not None and CUSTODY_DIRECTORY.is_dir(),
    "implementation or bound repository-external custody is unavailable",
)
class A03OfficialCustodyIntegrationTests(unittest.TestCase):
    def test_bound_custody_is_rehashed_and_matches_closed_observation(self) -> None:
        assert SUBJECT is not None
        self.assertEqual(
            SUBJECT._observe_bound_custody(ROOT, CUSTODY_DIRECTORY),
            EXPECTED_CUSTODY,
        )


if __name__ == "__main__":
    unittest.main()
