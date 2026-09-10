from __future__ import annotations

import base64
import contextlib
import copy
import hashlib
import importlib.util
import io
import json
import os
import plistlib
import shutil
import signal
import stat
import subprocess
import sys
import tempfile
import time
import unittest
from datetime import datetime, timezone
from pathlib import Path
from types import SimpleNamespace
from unittest import mock

from scripts import run_qinao_k4_ios27_platform_spike as k4_runner
from scripts.test_check_qinao_owner_ledger import (
    _canonical_test_json,
    _test_complete_trust_keys,
    _test_ed25519_key,
    _test_ed25519_sign,
    _test_governance_signature_preimage,
)


PROJECT_ROOT = Path(__file__).resolve().parents[1]
RUNNER = PROJECT_ROOT / "scripts" / "run_qinao_k4_ios27_platform_spike.py"
K4_DEVICE_PROFILE_SEED = bytes(range(32))
K4_EVIDENCE_SEED = bytes(reversed(range(32)))
K4_DEVICE_PROFILE_KEY_ID = "test-only-k4-device-profile-key"
K4_EVIDENCE_KEY_ID = "test-only-k4-evidence-key"
REPOSITORY_IDENTITY = "test-only/qinao-k4-platform-spike"
ISSUED_AT = "2026-07-29T00:00:00Z"
EXPIRES_AT = "2030-01-01T00:00:00Z"
VERIFICATION_TIME = datetime(2026, 7, 30, tzinfo=timezone.utc)
DEVICE_DIGEST = "d" * 64
ENTITLEMENT = "com.example.test-only.enhanced-security"
LIFECYCLE_EVENTS = (
    "launch",
    "interruption",
    "termination",
    "reconnect",
    "keyAccess",
)


def _wait_for_pid_exit(pid: int, timeout_seconds: float = 2.0) -> bool:
    deadline = time.monotonic() + timeout_seconds
    while time.monotonic() < deadline:
        try:
            os.kill(pid, 0)
        except ProcessLookupError:
            return True
        except PermissionError:
            return False
        time.sleep(0.02)
    return False


class K4IOS27PlatformSpikeTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp_directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp_directory.cleanup)
        self.directory = Path(self.temp_directory.name)
        self.root = self.directory / "repository"
        self.root.mkdir()
        self.external = self.directory / "external"
        self.external.mkdir(mode=0o700)
        self.git("init", "-q")
        self.git("config", "user.email", "test-only@example.invalid")
        self.git("config", "user.name", "Qinao Test Only")
        (self.root / "README.md").write_text("test-only K4 fixture\n", encoding="utf-8")
        self.git("add", "README.md")
        self.git("commit", "-qm", "test-only K4 base")
        self.commit = self.git("rev-parse", "HEAD")
        self.tree = self.git("rev-parse", "HEAD^{tree}")

        contents = self.directory / "Xcode.app" / "Contents"
        self.developer = contents / "Developer"
        self.sdk_parent = self.developer / "Platforms/iPhoneOS.platform/Developer/SDKs"
        self.sdk = self.sdk_parent / "iPhoneOS.sdk"
        self.interface = (
            self.sdk
            / "System/Library/Frameworks/TestSecurity.framework/Modules"
            / "TestSecurity.swiftmodule/arm64-apple-ios.swiftinterface"
        )
        self.interface.parent.mkdir(parents=True)
        self.interface.write_text(
            "public struct TestSecurityCapability {}\n",
            encoding="utf-8",
        )
        (self.sdk / "SDKSettings.json").write_bytes(
            _canonical_test_json(
                {
                    "CanonicalName": "iphoneos27.0",
                    "Version": "27.0",
                }
            )
            + b"\n"
        )
        sdk_system_version = (
            self.sdk / "System/Library/CoreServices/SystemVersion.plist"
        )
        sdk_system_version.parent.mkdir(parents=True)
        sdk_system_version.write_bytes(
            plistlib.dumps(
                {
                    "ProductBuildVersion": "24A5355p",
                    "ProductVersion": "27.0",
                },
                fmt=plistlib.FMT_BINARY,
            )
        )
        (self.sdk_parent / "iPhoneOS27.0.sdk").symlink_to(self.sdk.name)
        (contents / "version.plist").write_bytes(
            plistlib.dumps(
                {
                    "ProductBuildVersion": "27A5194q",
                    "CFBundleShortVersionString": "27.0",
                    "CFBundleVersion": "25183.29.15",
                },
                fmt=plistlib.FMT_BINARY,
            )
        )
        self.xcodebuild = self.developer / "usr/bin/xcodebuild"
        self.xcodebuild.parent.mkdir(parents=True)
        self.xcodebuild.write_text(
            "#!/bin/sh\nexit 0\n",
            encoding="utf-8",
        )
        self.xcodebuild.chmod(0o755)
        self.real_run_stock_xcrun = getattr(
            k4_runner,
            "run_stock_xcrun",
            None,
        )
        stock_xcrun_patch = mock.patch.object(
            k4_runner,
            "run_stock_xcrun",
            side_effect=self.stock_xcrun,
            create=True,
        )
        stock_xcrun_patch.start()
        self.addCleanup(stock_xcrun_patch.stop)

        self.trust_root = {
            "schema": "QinaoAdmissionTrustRootV1",
            "repositoryIdentity": REPOSITORY_IDENTITY,
            "issuedAt": ISSUED_AT,
            "expiresAt": EXPIRES_AT,
            "keys": _test_complete_trust_keys(
                [
                    {
                        "keyID": key_id,
                        "principalID": key_id,
                        "role": "k4-evidence-signer",
                        "schemaScope": schema_scope,
                        "publicKey": base64.b64encode(public_key).decode("ascii"),
                        "publicKeyFingerprintSHA256": hashlib.sha256(
                            public_key
                        ).hexdigest(),
                        "notBefore": ISSUED_AT,
                        "notAfter": EXPIRES_AT,
                    }
                    for key_id, seed, schema_scope in (
                        (
                            K4_DEVICE_PROFILE_KEY_ID,
                            K4_DEVICE_PROFILE_SEED,
                            "QinaoK4PhysicalDeviceProfileV1",
                        ),
                        (
                            K4_EVIDENCE_KEY_ID,
                            K4_EVIDENCE_SEED,
                            "QinaoK4IOS27PlatformSpikeV1",
                        ),
                    )
                    for public_key in [_test_ed25519_key(seed)[0]]
                ],
            ),
            "revokedNonces": [],
        }
        self.trust_path = self.write_external("trust-root.json", self.trust_root)
        self.profile = self.signed(self.profile_document())
        self.profile_path = self.write_external(
            "device-profile.json",
            self.profile,
        )
        self.output = self.external / "unsigned-spike.json"

    def git(self, *arguments: str) -> str:
        return subprocess.run(
            ["git", *arguments],
            cwd=self.root,
            check=True,
            capture_output=True,
            text=True,
        ).stdout.strip()

    @staticmethod
    def signed(value: dict) -> dict:
        signed = copy.deepcopy(value)
        seeds = {
            K4_DEVICE_PROFILE_KEY_ID: K4_DEVICE_PROFILE_SEED,
            K4_EVIDENCE_KEY_ID: K4_EVIDENCE_SEED,
        }
        signer = signed.get("signer")
        if signer not in seeds:
            raise AssertionError(
                f"test fixture has no schema-specific K4 key for {signer!r}"
            )
        signed["signature"] = base64.b64encode(
            _test_ed25519_sign(
                seeds[signer],
                _test_governance_signature_preimage(value),
            )
        ).decode("ascii")
        return signed

    def write_external(self, name: str, value: object) -> Path:
        path = self.external / name
        path.write_bytes(_canonical_test_json(value) + b"\n")
        path.chmod(0o600)
        return path

    @staticmethod
    def supported_profile_digest(matrix: dict) -> str:
        contract = {
            "frameworkAPIs": matrix["frameworkAPIs"],
            "target": matrix["target"],
            "requiredEntitlements": matrix["requiredEntitlements"],
            "sqlite": matrix["sqlite"],
            "transport": matrix["transport"],
            "lifecycle": matrix["lifecycle"],
        }
        return hashlib.sha256(_canonical_test_json(contract)).hexdigest()

    def probe_matrix(self) -> dict:
        matrix = {
            "schema": "QinaoK4DeviceProbeMatrixV1",
            "deviceIdentityDigest": DEVICE_DIGEST,
            "target": {
                "extensionPoint": "com.example.test-only.security-extension",
                "processModel": "outOfProcessExtension",
                "bundleIdentifierDigest": "1" * 64,
            },
            "frameworkAPIs": [
                {
                    "framework": "TestSecurity",
                    "api": "TestSecurityCapability",
                    "declarationRelativePath": (
                        "System/Library/Frameworks/TestSecurity.framework/"
                        "Modules/TestSecurity.swiftmodule/"
                        "arm64-apple-ios.swiftinterface"
                    ),
                    "declarationToken": "TestSecurityCapability",
                }
            ],
            "requiredEntitlements": [ENTITLEMENT],
            "sqlite": {
                "open": "passed",
                "wal": "passed",
                "fileProtection": "passed",
            },
            "transport": {
                "kind": "XPC",
                "feasibility": "passed",
            },
            "lifecycle": [
                {"event": event, "observation": "passed"} for event in LIFECYCLE_EVENTS
            ],
            "resultBundleDigest": "2" * 64,
            "supportedProfileDigest": "",
            "status": "supportedExactProfile",
        }
        matrix["supportedProfileDigest"] = self.supported_profile_digest(matrix)
        return matrix

    def profile_document(self) -> dict:
        return {
            "schema": "QinaoK4PhysicalDeviceProfileV1",
            "repositoryIdentity": REPOSITORY_IDENTITY,
            "approvedDesignBlob": "a" * 64,
            "candidateCommit": self.commit,
            "candidateTree": self.tree,
            "platform": "iOS",
            "environment": "physicalDevice",
            "deviceIdentityDigest": DEVICE_DIGEST,
            "osVersion": "27.0",
            "osBuild": "24A5355p",
            "xcodeVersion": "27.0",
            "xcodeBuild": "27A5194q",
            "sdkCanonicalName": "iphoneos27.0",
            "sdkVersion": "27.0",
            "sdkBuild": "24A5355p",
            "signingIdentityClass": "Apple Development",
            "entitlementInventory": [ENTITLEMENT],
            "probeMatrix": self.probe_matrix(),
            "issuedAt": ISSUED_AT,
            "expiresAt": EXPIRES_AT,
            "nonce": "test-only-device-profile",
            "signer": K4_DEVICE_PROFILE_KEY_ID,
            "role": "k4-evidence-signer",
            "signatureAlgorithm": "Ed25519",
        }

    def rewrite_profile(
        self,
        mutation,
        *,
        resign: bool = True,
    ) -> None:
        profile = copy.deepcopy(self.profile)
        profile.pop("signature", None)
        mutation(profile)
        self.profile = self.signed(profile) if resign else profile
        self.profile_path.write_bytes(_canonical_test_json(self.profile) + b"\n")
        self.profile_path.chmod(0o600)

    def collect_command(self, output: Path | None = None) -> list[str]:
        return [
            sys.executable,
            str(RUNNER),
            "--root",
            str(self.root),
            "--device-profile",
            str(self.profile_path),
            "--trust-root",
            str(self.trust_path),
            "--xcode-developer-dir",
            str(self.developer),
            "--unsigned-output",
            str(output or self.output),
        ]

    def stock_xcrun(self, *arguments: str) -> str:
        if arguments == ("--find", "xcodebuild"):
            return str(self.xcodebuild)
        if arguments == ("--sdk", "iphoneos", "--show-sdk-path"):
            return str(self.sdk)
        raise AssertionError(f"unexpected stock xcrun arguments: {arguments!r}")

    def run_collect_command(
        self,
        command: list[str],
    ) -> subprocess.CompletedProcess[str]:
        stdout = io.StringIO()
        stderr = io.StringIO()
        with (
            mock.patch.object(
                sys,
                "argv",
                [str(RUNNER), *command[2:]],
            ),
            contextlib.redirect_stdout(stdout),
            contextlib.redirect_stderr(stderr),
        ):
            returncode = k4_runner.main()
        return subprocess.CompletedProcess(
            command,
            returncode,
            stdout.getvalue(),
            stderr.getvalue(),
        )

    def run_collect(
        self, output: Path | None = None
    ) -> subprocess.CompletedProcess[str]:
        return self.run_collect_command(self.collect_command(output))

    def collect_valid_report(self) -> dict:
        result = self.run_collect()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.last_collect_result = result
        return json.loads(self.output.read_text(encoding="utf-8"))

    def signed_evidence(self, report: dict) -> dict:
        evidence = copy.deepcopy(report)
        self.assertEqual(evidence.pop("collectionStatus"), "unsignedUnadmitted")
        self.assertFalse(evidence.pop("signaturePresent"))
        evidence["schema"] = "QinaoK4IOS27PlatformSpikeV1"
        evidence.update(
            {
                "issuedAt": ISSUED_AT,
                "expiresAt": EXPIRES_AT,
                "nonce": "test-only-k4-evidence",
                "signer": K4_EVIDENCE_KEY_ID,
                "role": "k4-evidence-signer",
                "signatureAlgorithm": "Ed25519",
            }
        )
        return self.signed(evidence)

    def run_verify(self, evidence_path: Path) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [
                sys.executable,
                str(RUNNER),
                "--root",
                str(self.root),
                "--verify",
                str(evidence_path),
                "--trust-root",
                str(self.trust_path),
            ],
            cwd=self.root,
            capture_output=True,
            text=True,
            check=False,
        )

    def test_collect_writes_canonical_unsigned_unadmitted_mode_0600_without_inference(
        self,
    ) -> None:
        report = self.collect_valid_report()
        self.assertEqual(
            self.output.read_bytes(),
            _canonical_test_json(report) + b"\n",
        )
        self.assertEqual(stat.S_IMODE(self.output.stat().st_mode), 0o600)
        self.assertEqual(report["schema"], "QinaoK4IOS27PlatformSpikeCandidateV1")
        self.assertEqual(report["collectionStatus"], "unsignedUnadmitted")
        self.assertFalse(report["signaturePresent"])
        self.assertNotIn("signature", report)
        self.assertEqual(report["status"], "supportedExactProfile")
        availability = report["frameworkAPIAvailability"]
        self.assertEqual(availability[0]["declarationPresence"], "present")
        self.assertEqual(availability[0]["processSupportInference"], "notInferred")
        self.assertEqual(
            availability[0]["entitlementSupportInference"],
            "notInferred",
        )
        self.assertIn("unsigned, unadmitted", self.last_collect_result.stdout)

    def test_k4_main_captures_one_verification_time_for_collection(
        self,
    ) -> None:
        class CountingDateTime(datetime):
            calls = 0

            @classmethod
            def now(cls, tz=None):
                cls.calls += 1
                return VERIFICATION_TIME

        command = self.collect_command()
        with (
            mock.patch.object(
                k4_runner,
                "datetime",
                CountingDateTime,
            ),
            mock.patch.object(
                sys,
                "argv",
                [str(RUNNER), *command[2:]],
            ),
        ):
            self.assertEqual(k4_runner.main(), 0)
        self.assertEqual(CountingDateTime.calls, 1)

    def test_k4_main_captures_one_verification_time_for_verification(
        self,
    ) -> None:
        report = self.collect_valid_report()
        evidence = self.signed_evidence(report)
        evidence_path = self.root / "docs/evidence/k4-platform-spike.json"
        evidence_path.parent.mkdir(parents=True)
        evidence_path.write_bytes(_canonical_test_json(evidence) + b"\n")
        self.git("add", evidence_path.relative_to(self.root).as_posix())
        self.git("commit", "-qm", "test-only K4 single-V evidence")

        class CountingDateTime(datetime):
            calls = 0

            @classmethod
            def now(cls, tz=None):
                cls.calls += 1
                return VERIFICATION_TIME

        command = [
            sys.executable,
            str(RUNNER),
            "--root",
            str(self.root),
            "--verify",
            str(evidence_path),
            "--trust-root",
            str(self.trust_path),
        ]
        with (
            mock.patch.object(
                k4_runner,
                "datetime",
                CountingDateTime,
            ),
            mock.patch.object(
                sys,
                "argv",
                [str(RUNNER), *command[2:]],
            ),
        ):
            self.assertEqual(k4_runner.main(), 0)
        self.assertEqual(CountingDateTime.calls, 1)

    def test_git_commands_ignore_attacker_controlled_repository_environment(
        self,
    ) -> None:
        poison = {
            "GIT_ALTERNATE_OBJECT_DIRECTORIES": str(
                self.directory / "attacker-objects"
            ),
            "GIT_DIR": str(self.directory / "attacker.git"),
            "GIT_INDEX_FILE": str(self.directory / "attacker-index"),
            "GIT_OBJECT_DIRECTORY": str(self.directory / "attacker-object-dir"),
            "GIT_WORK_TREE": str(self.directory / "attacker-worktree"),
        }

        with mock.patch.dict(os.environ, poison, clear=False):
            result = self.run_collect()

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(self.output.is_file())

    def test_git_environment_overrides_known_execution_affecting_config(
        self,
    ) -> None:
        expected_command_scope_config = (
            ("core.fsmonitor", "false"),
            ("core.hooksPath", "/dev/null"),
            ("diff.external", ""),
            ("core.pager", "cat"),
            ("submodule.recurse", "false"),
        )
        environment = k4_runner.GIT_SUBPROCESS_ENVIRONMENT
        self.assertEqual(
            environment.get("GIT_CONFIG_COUNT"),
            str(len(expected_command_scope_config)),
        )
        for index, (key, value) in enumerate(expected_command_scope_config):
            with self.subTest(config=key):
                self.assertEqual(environment.get(f"GIT_CONFIG_KEY_{index}"), key)
                self.assertEqual(
                    environment.get(f"GIT_CONFIG_VALUE_{index}"),
                    value,
                )
        self.assertEqual(environment.get("GIT_OPTIONAL_LOCKS"), "0")
        self.assertEqual(environment.get("GIT_NO_REPLACE_OBJECTS"), "1")
        self.assertEqual(environment.get("GIT_NO_LAZY_FETCH"), "1")
        self.assertEqual(environment.get("GIT_ATTR_NOSYSTEM"), "1")
        self.assertEqual(environment.get("GIT_LITERAL_PATHSPECS"), "1")
        self.assertEqual(environment.get("XDG_CONFIG_HOME"), "/nonexistent")
        self.assertEqual(environment.get("GIT_PAGER"), "cat")
        self.assertEqual(environment.get("PAGER"), "cat")
        self.assertNotIn("GIT_CONFIG_PARAMETERS", environment)

    def test_k4_git_snapshot_ignores_replacement_refs(self) -> None:
        original_commit = self.commit
        original_tree = self.tree
        (self.root / "replacement-only.txt").write_text(
            "replacement\n",
            encoding="utf-8",
        )
        self.git("add", "replacement-only.txt")
        self.git("commit", "-qm", "test-only replacement target")
        replacement_commit = self.git("rev-parse", "HEAD")
        self.assertNotEqual(
            self.git("rev-parse", f"{replacement_commit}^{{tree}}"),
            original_tree,
        )
        self.git("replace", original_commit, replacement_commit)

        self.assertEqual(
            k4_runner.run_git(
                self.root,
                "rev-parse",
                f"{original_commit}^{{tree}}",
            ),
            original_tree,
        )

    def test_actual_k4_git_commands_do_not_execute_repository_local_helpers(
        self,
    ) -> None:
        sentinel = self.directory / "repository-config-helper-ran"
        helper = self.directory / "repository-config-helper"
        helper.write_text(
            f"""#!{sys.executable}
from pathlib import Path
Path({str(sentinel)!r}).write_text("executed", encoding="utf-8")
""",
            encoding="utf-8",
        )
        helper.chmod(0o755)
        hooks = self.directory / "repository-hooks"
        hooks.mkdir()
        for hook_name in ("post-index-change", "reference-transaction"):
            hook = hooks / hook_name
            shutil.copyfile(helper, hook)
            hook.chmod(0o755)

        blob = self.git("rev-parse", "HEAD:README.md")
        self.git("config", "core.fsmonitor", str(helper))
        self.git("config", "core.hooksPath", str(hooks))
        self.git("config", "diff.external", str(helper))
        self.git("config", "core.pager", str(helper))
        sentinel.unlink(missing_ok=True)

        self.assertEqual(
            Path(
                k4_runner.run_git(
                    self.root,
                    "rev-parse",
                    "--show-toplevel",
                )
            ).resolve(),
            self.root.resolve(),
        )
        self.assertEqual(
            k4_runner.run_git(self.root, "rev-parse", "HEAD"),
            self.commit,
        )
        self.assertEqual(
            k4_runner.run_git(self.root, "rev-parse", "HEAD^{tree}"),
            self.tree,
        )
        self.assertEqual(
            k4_runner.run_git(self.root, "status", "--porcelain=v1"),
            "",
        )
        self.assertTrue(
            k4_runner.run_git_bytes(
                self.root,
                "ls-tree",
                "-z",
                self.tree,
                "--",
                "README.md",
            )
        )
        self.assertEqual(
            k4_runner.run_git_bytes(
                self.root,
                "cat-file",
                "blob",
                blob,
            ),
            b"test-only K4 fixture\n",
        )
        self.assertEqual(
            k4_runner.run_git(self.root, "cat-file", "-t", self.commit),
            "commit",
        )
        self.assertEqual(
            k4_runner.run_git(self.root, "cat-file", "-t", self.tree),
            "tree",
        )
        self.assertEqual(
            k4_runner.run_git(
                self.root,
                "rev-parse",
                f"{self.commit}^{{tree}}",
            ),
            self.tree,
        )
        self.assertFalse(
            sentinel.exists(),
            "an actual K4 Git command executed repository-local config",
        )

    def test_k4_cleanliness_never_uses_git_worktree_content_commands(
        self,
    ) -> None:
        with mock.patch.object(
            k4_runner,
            "run_git_bytes",
            wraps=k4_runner.run_git_bytes,
        ) as observed:
            k4_runner.ensure_repository(self.root, require_clean=True)

        commands = [call.args[1:] for call in observed.call_args_list]
        self.assertTrue(
            any(
                command and command[0] == "diff-index" and "--cached" in command
                for command in commands
            ),
            commands,
        )
        self.assertFalse(
            any(command and command[0] == "status" for command in commands),
            commands,
        )
        self.assertFalse(
            any(command and command[0] == "diff" for command in commands),
            commands,
        )
        self.assertFalse(
            any(command and command[0] == "hash-object" for command in commands),
            commands,
        )

    def test_k4_cleanliness_never_executes_clean_filter(self) -> None:
        sentinel = self.directory / "k4-clean-filter-ran"
        helper = self.directory / "k4-clean-filter"
        helper.write_text(
            f"""#!{sys.executable}
from pathlib import Path
import sys
Path({str(sentinel)!r}).write_text("executed", encoding="utf-8")
sys.stdout.buffer.write(sys.stdin.buffer.read())
""",
            encoding="utf-8",
        )
        helper.chmod(0o755)
        (self.root / ".gitattributes").write_text(
            "README.md filter=evil\n",
            encoding="utf-8",
        )
        self.git("add", ".gitattributes")
        self.git("commit", "-qm", "test-only filter attributes")
        self.git("config", "filter.evil.clean", str(helper))
        (self.root / "README.md").write_text(
            "unstaged filtered drift\n",
            encoding="utf-8",
        )

        with self.assertRaisesRegex(
            k4_runner.GateError,
            "repository must be clean",
        ):
            k4_runner.ensure_repository(self.root, require_clean=True)

        self.assertFalse(sentinel.exists())

    def test_k4_cleanliness_rejects_ignored_authority_drift(self) -> None:
        ignored_path = (
            self.root / "BehavioralAISubstrate/Sources/TestOnly/IgnoredAuthority.swift"
        )
        (self.root / ".gitignore").write_text(
            f"/{ignored_path.relative_to(self.root).as_posix()}\n",
            encoding="utf-8",
        )
        self.git("add", ".gitignore")
        self.git("commit", "-qm", "test-only ignored authority rule")
        ignored_path.parent.mkdir(parents=True)
        ignored_path.write_text(
            "public struct IgnoredAuthority {}\n",
            encoding="utf-8",
        )
        self.assertEqual(self.git("status", "--porcelain=v1"), "")

        with self.assertRaisesRegex(
            k4_runner.GateError,
            "repository must be clean.*IgnoredAuthority.swift",
        ):
            k4_runner.ensure_repository(self.root, require_clean=True)

    def test_k4_cleanliness_rejects_ignored_fourth_package_authority(
        self,
    ) -> None:
        relative_path = "FourthPackage/Tests/IgnoredTests.swift"
        (self.root / ".gitignore").write_text(
            f"/{relative_path}\n",
            encoding="utf-8",
        )
        self.git("add", ".gitignore")
        self.git("commit", "-qm", "test-only fourth package ignore")
        path = self.root / relative_path
        path.parent.mkdir(parents=True)
        path.write_text("struct IgnoredTests {}\n", encoding="utf-8")

        with self.assertRaisesRegex(
            k4_runner.GateError,
            "repository must be clean.*IgnoredTests.swift",
        ):
            k4_runner.ensure_repository(self.root, require_clean=True)

    def test_raw_authority_scanner_scope_equals_canonical_predicate(
        self,
    ) -> None:
        paths = (
            "FourthPackage/Package.swift",
            "FourthPackage/Sources/Core.swift",
            "FourthPackage/Tests/CoreTests.swift",
            "FourthPackage/Fixtures/state.json",
            "FourthPackage/README.md",
            "Vendor/FourthPackage/Tests/Vendored.swift",
            ".git/TestOnly/Tests/Hidden.swift",
        )
        for relative_path in paths:
            path = self.root / relative_path
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("test-only\n", encoding="utf-8")

        observed = k4_runner.scan_raw_authority_paths(self.root)
        expected = {path for path in paths if k4_runner.is_authority_diff_path(path)}

        self.assertEqual(observed & set(paths), expected)

    def test_raw_authority_scanner_governs_untracked_regular_topologies(
        self,
    ) -> None:
        paths = (
            "BehavioralAISubstrate/DeviceTestApp/Sources/Authority.swift",
            "BehavioralAISubstrate/DeviceTestApp/Resources/model.bin",
            "BehavioralAISubstrate/Plugins/BuildTool/plugin.swift",
            "BehavioralAISubstrate/Vendor/Runtime/runtime.h",
            (
                "BehavioralAISubstrate/Vendor/swift-transformers/"
                "Sources/Tokenizers/Tests/Evil.swift"
            ),
            (
                "BehavioralAISubstrate/Vendor/swift-transformers/"
                "Sources/Tokenizers/Fixtures/Evil.swift"
            ),
            (
                "BehavioralAISubstrate/Vendor/swift-transformers/"
                "Sources/Tokenizers/DerivedData/Evil.swift"
            ),
            (
                "BehavioralAISubstrate/Vendor/swift-transformers/"
                "Sources/Tokenizers/.build/Evil.swift"
            ),
            "BehavioralAISubstrate/Cargo/layercore/src/authority.rs",
            "BehavioralAISubstrate/Cargo/layercore/tests/integration.rs",
            "BehavioralAISubstrate/Cargo/layercore/benches/throughput",
            "SampleHost/Resources/Info.plist",
            "FourthPackage/Sources/ExtensionlessAuthority",
            "FourthPackage/Sources/Vendor/authority.cpp",
            "FourthPackage/Sources/.build/authority.metal",
        )
        for index, relative_path in enumerate(paths):
            path = self.root / relative_path
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("test-only untracked authority\n", encoding="utf-8")
            if index % 2:
                path.chmod(0o755)

        observed = k4_runner.scan_raw_authority_paths(self.root)

        self.assertTrue(set(paths).issubset(observed), observed)
        with self.assertRaisesRegex(
            k4_runner.GateError,
            "repository must be clean.*untracked or ignored authority",
        ):
            k4_runner.ensure_repository(self.root, require_clean=True)

    def test_raw_authority_scanner_excludes_components_before_source_root(
        self,
    ) -> None:
        paths = (
            "Vendor/FourthPackage/Sources/Authority.swift",
            ".build/FourthPackage/Sources/Authority.swift",
            ".swiftpm/FourthPackage/Sources/Authority.swift",
            "DerivedData/FourthPackage/Sources/Authority.swift",
            "FourthPackage/Vendor/Sources/Authority.swift",
            "FourthPackage/.build/Sources/Authority.swift",
            "FourthPackage/.swiftpm/Sources/Authority.swift",
            "FourthPackage/DerivedData/Sources/Authority.swift",
            "BehavioralAISubstrate/Cargo/.build/src/authority.rs",
            "BehavioralAISubstrate/Cargo/Vendor/src/authority.rs",
            "BehavioralAISubstrate/Cargo/DerivedData/tests/authority.rs",
            (
                "BehavioralAISubstrate/Vendor/swift-transformers/"
                ".build/Sources/Tokenizers/Evil.swift"
            ),
            (
                "BehavioralAISubstrate/Vendor/swift-transformers/"
                ".swiftpm/Sources/Tokenizers/Evil.swift"
            ),
            (
                "BehavioralAISubstrate/Vendor/swift-transformers/"
                "DerivedData/Sources/Tokenizers/Evil.swift"
            ),
            (
                "BehavioralAISubstrate/Vendor/swift-transformers/"
                "Vendor/Sources/Tokenizers/Evil.swift"
            ),
        )
        for relative_path in paths:
            path = self.root / relative_path
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("test-only excluded path\n", encoding="utf-8")

        observed = k4_runner.scan_raw_authority_paths(self.root)

        self.assertTrue(set(paths).isdisjoint(observed), observed)

    def test_raw_authority_scanner_rejects_extensionless_boundary_symlink(
        self,
    ) -> None:
        relative_paths = (
            "BehavioralAISubstrate/DeviceTestApp/Sources/DirectoryLink",
            "FourthPackage/Sources/Vendor/DirectoryLink",
            "FourthPackage/Sources/.build/DirectoryLink",
            "BehavioralAISubstrate/Cargo/layercore/src/GeneratedLink",
            (
                "BehavioralAISubstrate/Vendor/swift-transformers/"
                "Sources/Tokenizers/Tests/DirectoryLink"
            ),
        )
        for relative_path in relative_paths:
            with self.subTest(path=relative_path):
                path = self.root / relative_path
                path.parent.mkdir(parents=True, exist_ok=True)
                path.symlink_to("../Elsewhere")
                try:
                    with self.assertRaisesRegex(
                        k4_runner.RawWorktreeError,
                        "authority namespace.*regular tracked file",
                    ) as raised:
                        k4_runner.scan_raw_authority_paths(self.root)
                    self.assertIn(relative_path, str(raised.exception))
                finally:
                    path.unlink()

    def test_k4_cleanliness_rejects_tracked_authority_boundary_symlink(
        self,
    ) -> None:
        relative_path = "FourthPackage/Sources/Vendor/DirectoryLink"
        path = self.root / relative_path
        path.parent.mkdir(parents=True)
        path.symlink_to("../Elsewhere")
        self.git("add", relative_path)
        self.git("commit", "-qm", "test-only authority boundary symlink")

        with self.assertRaisesRegex(
            k4_runner.GateError,
            "authority namespace.*regular tracked file",
        ):
            k4_runner.ensure_repository(self.root, require_clean=True)

    def test_k4_cleanliness_accepts_an_exact_tracked_symlink(self) -> None:
        link = self.root / "README-link"
        link.symlink_to("README.md")
        self.git("add", "README-link")
        self.git("commit", "-qm", "test-only tracked symlink")

        root, commit, tree = k4_runner.ensure_repository(
            self.root,
            require_clean=True,
        )

        self.assertEqual(root, self.root.resolve())
        self.assertEqual(commit, self.git("rev-parse", "HEAD"))
        self.assertEqual(tree, self.git("rev-parse", "HEAD^{tree}"))

    def test_k4_cleanliness_accepts_a_missing_skip_worktree_entry(self) -> None:
        sparse = self.root / "sparse.txt"
        sparse.write_text("sparse bytes\n", encoding="utf-8")
        self.git("add", "sparse.txt")
        self.git("commit", "-qm", "test-only sparse entry")
        self.git("update-index", "--skip-worktree", "sparse.txt")
        sparse.unlink()

        k4_runner.ensure_repository(self.root, require_clean=True)

    def test_k4_cleanliness_rejects_a_gitlink_it_cannot_verify(self) -> None:
        self.git(
            "update-index",
            "--add",
            "--cacheinfo",
            f"160000,{self.commit},Vendor",
        )
        (self.root / "Vendor").mkdir()
        self.git("commit", "-qm", "test-only gitlink")

        with self.assertRaisesRegex(
            k4_runner.GateError,
            "gitlink.*cannot be verified",
        ):
            k4_runner.ensure_repository(self.root, require_clean=True)

    def test_k4_cleanliness_rejects_intent_to_add_index_entries(self) -> None:
        pending = self.root / "pending.txt"
        pending.write_text("pending\n", encoding="utf-8")
        self.git("add", "--intent-to-add", "pending.txt")

        with self.assertRaisesRegex(
            k4_runner.GateError,
            "index differs",
        ):
            k4_runner.ensure_repository(self.root, require_clean=True)

    def test_k4_cleanliness_enforces_single_file_byte_bound(self) -> None:
        with (
            mock.patch.object(
                k4_runner,
                "RAW_WORKTREE_SINGLE_FILE_BYTE_LIMIT",
                1,
            ),
            self.assertRaisesRegex(
                k4_runner.GateError,
                "single-file byte limit",
            ),
        ):
            k4_runner.ensure_repository(self.root, require_clean=True)

    def test_k4_cleanliness_enforces_file_count_bound(self) -> None:
        with (
            mock.patch.object(
                k4_runner,
                "RAW_WORKTREE_FILE_LIMIT",
                0,
            ),
            self.assertRaisesRegex(
                k4_runner.GateError,
                "file-count limit",
            ),
        ):
            k4_runner.ensure_repository(self.root, require_clean=True)

    def test_k4_cleanliness_rejects_a_file_changed_during_raw_read(
        self,
    ) -> None:
        tracked = (self.root / "README.md").stat()
        real_fstat = os.fstat
        observations = 0

        def unstable_fstat(descriptor: int):
            nonlocal observations
            metadata = real_fstat(descriptor)
            if (
                stat.S_ISREG(metadata.st_mode)
                and metadata.st_dev == tracked.st_dev
                and metadata.st_ino == tracked.st_ino
            ):
                observations += 1
                if observations >= 2:
                    return SimpleNamespace(
                        st_dev=metadata.st_dev,
                        st_ino=metadata.st_ino,
                        st_mode=metadata.st_mode,
                        st_nlink=metadata.st_nlink,
                        st_size=metadata.st_size,
                        st_mtime_ns=metadata.st_mtime_ns,
                        st_ctime_ns=metadata.st_ctime_ns + 1,
                    )
            return metadata

        with (
            mock.patch.object(
                k4_runner.os,
                "fstat",
                side_effect=unstable_fstat,
            ),
            self.assertRaisesRegex(
                k4_runner.GateError,
                "changed while being read",
            ),
        ):
            k4_runner.ensure_repository(self.root, require_clean=True)

    def test_k4_cleanliness_rejects_executable_bit_drift(self) -> None:
        (self.root / "README.md").chmod(0o755)

        with self.assertRaisesRegex(
            k4_runner.GateError,
            "executable mode differs",
        ):
            k4_runner.ensure_repository(self.root, require_clean=True)

    def test_k4_git_mode_uses_owner_execute_bit_matrix(self) -> None:
        cases = (
            (0o644, True),
            (0o645, True),
            (0o744, False),
            (0o755, False),
        )
        readme = self.root / "README.md"
        for mode, accepted in cases:
            with self.subTest(mode=oct(mode)):
                readme.chmod(mode)
                if accepted:
                    k4_runner.ensure_repository(self.root, require_clean=True)
                else:
                    with self.assertRaisesRegex(
                        k4_runner.GateError,
                        "executable mode differs",
                    ):
                        k4_runner.ensure_repository(
                            self.root,
                            require_clean=True,
                        )

    def test_git_timeout_and_spawn_errors_fail_closed(self) -> None:
        for error in (
            subprocess.TimeoutExpired(["git", "rev-parse"], 30),
            OSError("test-only spawn failure"),
        ):
            with self.subTest(error=type(error).__name__):
                with mock.patch.object(
                    k4_runner,
                    "run_bounded_process",
                    side_effect=error,
                ):
                    with self.assertRaisesRegex(
                        k4_runner.GateError,
                        "unavailable or timed out",
                    ):
                        k4_runner.run_git(self.root, "rev-parse", "HEAD")

    def test_bounded_subprocess_kills_pipe_holding_descendants(self) -> None:
        if not hasattr(os, "fork") or not hasattr(os, "killpg"):
            self.skipTest("process-group descendant test requires POSIX fork/killpg")
        tool = self.directory / "hanging-k4-tool"
        parent_pid_path = self.directory / "hanging-k4-parent.pid"
        child_pid_path = self.directory / "hanging-k4-child.pid"
        tool.write_text(
            f"""#!{sys.executable}
import os
from pathlib import Path
import signal
import time
parent_path = Path(os.environ["HANGING_PARENT_PID"])
child_path = Path(os.environ["HANGING_CHILD_PID"])
parent_path.write_text(str(os.getpid()), encoding="ascii")
child = os.fork()
if child == 0:
    signal.signal(signal.SIGTERM, signal.SIG_IGN)
    child_path.write_text(str(os.getpid()), encoding="ascii")
    while True:
        print("pipe held", flush=True)
        time.sleep(0.02)
while True:
    time.sleep(0.02)
""",
            encoding="utf-8",
        )
        tool.chmod(0o755)
        environment = {
            "PATH": "/usr/bin:/bin",
            "HANGING_PARENT_PID": str(parent_pid_path),
            "HANGING_CHILD_PID": str(child_pid_path),
        }

        def force_cleanup() -> None:
            if not parent_pid_path.exists():
                return
            try:
                os.killpg(
                    int(parent_pid_path.read_text(encoding="ascii")),
                    signal.SIGKILL,
                )
            except (ProcessLookupError, PermissionError, ValueError):
                pass

        self.addCleanup(force_cleanup)
        started = time.monotonic()
        with self.assertRaises(subprocess.TimeoutExpired):
            k4_runner.run_bounded_process(
                [str(tool)],
                cwd=self.directory,
                env=environment,
                timeout_seconds=1.0,
                termination_grace_seconds=0.10,
                stdout_limit_bytes=1024,
                stderr_limit_bytes=1024,
                text=True,
            )
        self.assertLess(time.monotonic() - started, 3.0)
        self.assertTrue(child_pid_path.is_file())
        child_pid = int(child_pid_path.read_text(encoding="ascii"))
        self.assertTrue(
            _wait_for_pid_exit(child_pid),
            "descendant remained after timeout",
        )

    def test_termination_never_reaps_leader_before_final_group_kill(
        self,
    ) -> None:
        events: list[object] = []

        class Stream:
            def close(self) -> None:
                events.append("close")

        class Process:
            pid = 424_243
            stdin = Stream()
            stdout = Stream()
            stderr = Stream()

            def wait(self, *, timeout: float) -> int:
                events.append(("wait", timeout))
                return 0

            def kill(self) -> None:
                events.append("kill")

        def observe_killpg(_pid: int, signal_value: int) -> None:
            events.append(("killpg", signal_value))

        with (
            mock.patch.object(
                k4_runner.os,
                "killpg",
                side_effect=observe_killpg,
            ),
            mock.patch.object(
                k4_runner.os,
                "waitid",
                create=True,
                return_value=object(),
            ),
            mock.patch.object(
                k4_runner.time,
                "sleep",
            ),
        ):
            k4_runner.terminate_process_group(Process(), grace_seconds=0.01)

        kill_index = events.index(("killpg", signal.SIGKILL))
        wait_index = next(
            index
            for index, event in enumerate(events)
            if isinstance(event, tuple) and event[0] == "wait"
        )
        self.assertLess(kill_index, wait_index, events)

    def test_bounded_subprocess_rejects_stdout_at_cap_plus_one(self) -> None:
        with self.assertRaises(k4_runner.ProcessOutputLimitExceeded):
            k4_runner.run_bounded_process(
                [
                    sys.executable,
                    "-c",
                    "import os; os.write(1, b'12345')",
                ],
                cwd=self.directory,
                env={"PATH": "/usr/bin:/bin"},
                timeout_seconds=5,
                stdout_limit_bytes=4,
                stderr_limit_bytes=1024,
                text=False,
            )

    def test_collect_accepts_stock_xcode_27_metadata_and_deduplicates_sdk_alias(
        self,
    ) -> None:
        report = self.collect_valid_report()
        self.assertEqual(report["xcodeVersion"], "27.0")
        self.assertEqual(report["xcodeBuild"], "27A5194q")
        self.assertEqual(report["sdkCanonicalName"], "iphoneos27.0")
        self.assertEqual(report["sdkVersion"], "27.0")
        self.assertEqual(report["sdkBuild"], "24A5355p")
        self.assertEqual(
            report["sdkSettingsDigest"],
            hashlib.sha256((self.sdk / "SDKSettings.json").read_bytes()).hexdigest(),
        )
        self.assertEqual(
            report["sdkSystemVersionDigest"],
            hashlib.sha256(
                (
                    self.sdk / "System/Library/CoreServices/SystemVersion.plist"
                ).read_bytes()
            ).hexdigest(),
        )

    def test_stock_xcrun_is_absolute_sanitized_and_timeout_bounded(
        self,
    ) -> None:
        runner = self.real_run_stock_xcrun
        if runner is None:

            def unavailable_stock_xcrun(*_arguments: str) -> str:
                return ""

            runner = unavailable_stock_xcrun
        completed = subprocess.CompletedProcess(
            ["/usr/bin/xcrun", "--sdk", "iphoneos", "--show-sdk-path"],
            0,
            f"{self.sdk}\n",
            "",
        )
        with mock.patch.object(
            k4_runner,
            "run_bounded_process",
            return_value=completed,
        ) as run:
            observed = runner("--sdk", "iphoneos", "--show-sdk-path")

        self.assertEqual(observed, str(self.sdk))
        arguments, keywords = run.call_args
        self.assertEqual(
            arguments[0],
            [
                "/usr/bin/xcrun",
                "--sdk",
                "iphoneos",
                "--show-sdk-path",
            ],
        )
        self.assertEqual(keywords["cwd"], "/")
        self.assertEqual(
            keywords["env"],
            {
                "LANG": "C",
                "LC_ALL": "C",
                "PATH": "/usr/bin:/bin:/usr/sbin:/sbin",
            },
        )
        self.assertGreater(keywords["timeout_seconds"], 0)
        self.assertTrue(keywords["text"])

    def test_collect_rejects_caller_developer_outside_active_xcrun(
        self,
    ) -> None:
        foreign_developer = self.directory / "ForeignXcode.app/Contents/Developer"
        foreign_xcodebuild = foreign_developer / "usr/bin/xcodebuild"
        foreign_xcodebuild.parent.mkdir(parents=True)
        foreign_xcodebuild.write_text("#!/bin/sh\nexit 0\n", encoding="utf-8")
        foreign_xcodebuild.chmod(0o755)

        def foreign_xcrun(*arguments: str) -> str:
            if arguments == ("--find", "xcodebuild"):
                return str(foreign_xcodebuild)
            if arguments == ("--sdk", "iphoneos", "--show-sdk-path"):
                return str(self.sdk)
            raise AssertionError(arguments)

        with mock.patch.object(
            k4_runner,
            "run_stock_xcrun",
            side_effect=foreign_xcrun,
        ):
            result = self.run_collect()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("active Xcode developer", result.stderr)
        self.assertFalse(self.output.exists())

    def test_collect_rejects_sdk_not_selected_by_stock_xcrun(self) -> None:
        foreign_sdk = self.sdk_parent / "iPhoneOSForeign.sdk"
        shutil.copytree(self.sdk, foreign_sdk)
        (foreign_sdk / "SDKSettings.json").write_bytes(
            _canonical_test_json(
                {
                    "CanonicalName": "iphoneos27.0-foreign",
                    "Version": "27.0",
                }
            )
            + b"\n"
        )

        def foreign_sdk_xcrun(*arguments: str) -> str:
            if arguments == ("--find", "xcodebuild"):
                return str(self.xcodebuild)
            if arguments == ("--sdk", "iphoneos", "--show-sdk-path"):
                return str(foreign_sdk)
            raise AssertionError(arguments)

        with mock.patch.object(
            k4_runner,
            "run_stock_xcrun",
            side_effect=foreign_sdk_xcrun,
        ):
            result = self.run_collect()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("stock xcrun SDK identity", result.stderr)
        self.assertFalse(self.output.exists())

    def test_profile_projection_rejects_unrelated_spike_field_substitution(
        self,
    ) -> None:
        report = self.collect_valid_report()
        report["target"] = {
            **report["target"],
            "processModel": "foreignProcessModel",
        }

        with self.assertRaisesRegex(
            k4_runner.GateError,
            "probeMatrix projection mismatch: target",
        ):
            k4_runner.validate_profile_to_spike_projection(
                report,
                profile=self.profile,
                profile_raw=self.profile_path.read_bytes(),
            )

    def test_framework_arrays_use_global_rfc8785_order_not_identity_order(
        self,
    ) -> None:
        identity_order = [
            {
                "framework": "AFramework",
                "api": "zCapability",
                "declarationRelativePath": "A/z.swiftinterface",
                "declarationToken": "zCapability",
            },
            {
                "framework": "BFramework",
                "api": "aCapability",
                "declarationRelativePath": "B/a.swiftinterface",
                "declarationToken": "aCapability",
            },
        ]
        canonical_order = sorted(identity_order, key=_canonical_test_json)
        self.assertNotEqual(identity_order, canonical_order)
        self.assertEqual(
            k4_runner.validate_framework_queries(canonical_order),
            canonical_order,
        )
        with self.assertRaisesRegex(
            k4_runner.GateError,
            "global RFC 8785 element order",
        ):
            k4_runner.validate_framework_queries(identity_order)

        observations = [
            {
                "framework": row["framework"],
                "api": row["api"],
                "declarationDigest": "a" * 64,
                "declarationPresence": "present",
                "processSupportInference": "notInferred",
                "entitlementSupportInference": "notInferred",
            }
            for row in identity_order
        ]
        canonical_observations = sorted(
            observations,
            key=_canonical_test_json,
        )
        self.assertEqual(
            k4_runner.validate_framework_observations(canonical_observations),
            canonical_observations,
        )
        with self.assertRaisesRegex(
            k4_runner.GateError,
            "global RFC 8785 element order",
        ):
            k4_runner.validate_framework_observations(observations)

    def test_collect_rejects_two_distinct_matching_sdk_identities(self) -> None:
        conflicting_sdk = self.sdk_parent / "iPhoneOS27.0-conflict.sdk"
        shutil.copytree(self.sdk, conflicting_sdk)
        result = self.run_collect()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("matched=2", result.stderr)
        self.assertFalse(self.output.exists())

    def test_absent_framework_observation_omits_declaration_digest(
        self,
    ) -> None:
        self.interface.write_text(
            "public struct DifferentCapability {}\n",
            encoding="utf-8",
        )

        _settings_digest, _system_digest, observations = (
            k4_runner.inspect_installed_sdk(self.developer, self.profile)
        )

        self.assertEqual(
            observations,
            [
                {
                    "framework": "TestSecurity",
                    "api": "TestSecurityCapability",
                    "declarationPresence": "absent",
                    "processSupportInference": "notInferred",
                    "entitlementSupportInference": "notInferred",
                }
            ],
        )

    def test_collect_derives_disabled_status_from_absent_installed_api(
        self,
    ) -> None:
        self.interface.write_text(
            "public struct DifferentCapability {}\n",
            encoding="utf-8",
        )

        result = self.run_collect()

        self.assertEqual(result.returncode, 0, result.stderr)
        report = json.loads(self.output.read_bytes())
        self.assertEqual(report["status"], "disabledMissingTarget")
        self.assertEqual(
            report["frameworkAPIAvailability"][0]["declarationPresence"],
            "absent",
        )
        self.assertNotIn(
            "declarationDigest",
            report["frameworkAPIAvailability"][0],
        )

    def test_verify_rejects_supported_profile_with_absent_framework_api(
        self,
    ) -> None:
        report = self.collect_valid_report()
        evidence = self.signed_evidence(report)
        evidence.pop("signature")
        observation = evidence["frameworkAPIAvailability"][0]
        observation.pop("declarationDigest")
        observation["declarationPresence"] = "absent"
        evidence = self.signed(evidence)
        evidence_path = self.write_external("absent-framework-api.json", evidence)
        result = self.run_verify(evidence_path)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("deterministic precedence", result.stderr)
        self.assertIn("disabledMissingTarget", result.stderr)

    def test_verify_accepts_absent_framework_union_with_precedence_status(
        self,
    ) -> None:
        report = self.collect_valid_report()
        evidence = self.signed_evidence(report)
        evidence.pop("signature")
        observation = evidence["frameworkAPIAvailability"][0]
        observation.pop("declarationDigest")
        observation["declarationPresence"] = "absent"
        evidence["status"] = "disabledMissingTarget"
        evidence = self.signed(evidence)
        evidence_path = self.write_external("absent-framework-union.json", evidence)

        result = self.run_verify(evidence_path)

        self.assertEqual(result.returncode, 0, result.stderr)

    def test_verify_rejects_framework_declaration_observation_identity_mismatch(
        self,
    ) -> None:
        report = self.collect_valid_report()
        evidence = self.signed_evidence(report)
        evidence.pop("signature")
        evidence["frameworkAPIs"][0]["api"] = "ForeignCapability"
        evidence["supportedProfileDigest"] = self.supported_profile_digest(evidence)
        evidence = self.signed(evidence)
        evidence_path = self.write_external(
            "mismatched-framework-identity.json",
            evidence,
        )

        result = self.run_verify(evidence_path)

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("framework/API identities", result.stderr)

    def test_simulator_profile_is_rejected(self) -> None:
        self.rewrite_profile(
            lambda profile: profile.__setitem__("environment", "simulator")
        )
        result = self.run_collect()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("physicalDevice", result.stderr)
        self.assertFalse(self.output.exists())

    def test_unsigned_device_profile_is_rejected(self) -> None:
        self.rewrite_profile(lambda _profile: None, resign=False)
        result = self.run_collect()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("device profile signature", result.stderr)
        self.assertFalse(self.output.exists())

    def test_probe_matrix_for_wrong_device_is_rejected(self) -> None:
        self.rewrite_profile(
            lambda profile: profile["probeMatrix"].__setitem__(
                "deviceIdentityDigest",
                "e" * 64,
            )
        )
        result = self.run_collect()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("deviceIdentityDigest", result.stderr)
        self.assertFalse(self.output.exists())

    def test_expired_device_profile_is_rejected(self) -> None:
        self.rewrite_profile(
            lambda profile: profile.__setitem__(
                "expiresAt",
                "2026-01-01T00:00:00Z",
            )
        )
        result = self.run_collect()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("device profile is expired", result.stderr)
        self.assertFalse(self.output.exists())

    def test_missing_lifecycle_observation_is_rejected(self) -> None:
        def mutate(profile: dict) -> None:
            profile["probeMatrix"]["lifecycle"].pop()
            profile["probeMatrix"]["supportedProfileDigest"] = (
                self.supported_profile_digest(profile["probeMatrix"])
            )

        self.rewrite_profile(mutate)
        result = self.run_collect()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("lifecycle events", result.stderr)
        self.assertFalse(self.output.exists())

    def test_impossible_entitlement_support_claim_is_rejected(self) -> None:
        self.rewrite_profile(
            lambda profile: profile.__setitem__("entitlementInventory", [])
        )
        result = self.run_collect()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("deterministic precedence", result.stderr)
        self.assertIn("disabledMissingEntitlement", result.stderr)
        self.assertFalse(self.output.exists())

        self.rewrite_profile(
            lambda profile: profile["probeMatrix"].__setitem__(
                "status",
                "disabledMissingEntitlement",
            )
        )
        result = self.run_collect()
        self.assertEqual(result.returncode, 0, result.stderr)
        report = json.loads(self.output.read_bytes())
        self.assertEqual(report["status"], "disabledMissingEntitlement")

    def test_output_must_be_external_absent_and_exclusively_created(self) -> None:
        inside = self.root / "unsigned-spike.json"
        inside_result = self.run_collect(inside)
        self.assertNotEqual(inside_result.returncode, 0)
        self.assertIn("outside the repository", inside_result.stderr)
        self.assertFalse(inside.exists())

        self.output.write_text("sentinel\n", encoding="utf-8")
        self.output.chmod(0o600)
        reused_result = self.run_collect()
        self.assertNotEqual(reused_result.returncode, 0)
        self.assertIn("already exists", reused_result.stderr)
        self.assertEqual(self.output.read_text(encoding="utf-8"), "sentinel\n")

    def test_external_inputs_reject_hardlink_aliases(self) -> None:
        profile_alias = self.external / "device-profile-hardlink.json"
        os.link(self.trust_path, profile_alias)
        command = self.collect_command()
        command[command.index("--device-profile") + 1] = str(profile_alias)

        result = self.run_collect_command(command)

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("hard link", result.stderr)
        self.assertFalse(self.output.exists())

    def test_attacker_addressable_bound_opener_is_nonblocking(self) -> None:
        def reject_after_flag_check(path, flags, *args, **kwargs):
            self.assertTrue(
                flags & os.O_NONBLOCK,
                f"bound opener omitted O_NONBLOCK for {path}",
            )
            raise OSError("test-only stop after flag inspection")

        with mock.patch.object(
            k4_runner.os,
            "open",
            side_effect=reject_after_flag_check,
        ):
            with self.assertRaises(k4_runner.GateError):
                k4_runner.read_bound_file(
                    self.profile_path,
                    label="test-only K4 profile",
                    require_mode_0600=True,
                )

    def test_external_input_path_swap_is_detected_on_the_open_descriptor(
        self,
    ) -> None:
        module_name = "qinao_k4_bound_reader_test"
        spec = importlib.util.spec_from_file_location(
            module_name,
            RUNNER,
        )
        self.assertIsNotNone(spec)
        assert spec is not None
        module = importlib.util.module_from_spec(spec)
        sys.modules[module_name] = module
        self.addCleanup(sys.modules.pop, module_name, None)
        self.assertIsNotNone(spec.loader)
        assert spec.loader is not None
        spec.loader.exec_module(module)
        path = self.external / "descriptor-bound.json"
        replacement = self.external / "descriptor-replacement.json"
        path.write_bytes(b'{"original":true}\n')
        path.chmod(0o600)
        replacement.write_bytes(b'{"replacement":true}\n')
        replacement.chmod(0o600)
        real_fstat = module.os.fstat
        swapped = False

        def swap_after_open(descriptor: int):
            nonlocal swapped
            metadata = real_fstat(descriptor)
            if not swapped:
                swapped = True
                os.replace(replacement, path)
            return metadata

        with self.assertRaisesRegex(
            module.GateError,
            "changed while.*bound descriptor",
        ):
            with mock.patch.object(
                module.os,
                "fstat",
                side_effect=swap_after_open,
            ):
                module.read_external_file(path, self.root, "bound fixture")
        self.assertTrue(swapped)

    def test_exclusive_writer_fsyncs_file_and_parent_directory(self) -> None:
        module_name = "qinao_k4_durable_writer_test"
        spec = importlib.util.spec_from_file_location(module_name, RUNNER)
        self.assertIsNotNone(spec)
        assert spec is not None
        module = importlib.util.module_from_spec(spec)
        sys.modules[module_name] = module
        self.addCleanup(sys.modules.pop, module_name, None)
        self.assertIsNotNone(spec.loader)
        assert spec.loader is not None
        spec.loader.exec_module(module)
        output = self.external / "durable.json"
        with mock.patch.object(module.os, "fsync", wraps=os.fsync) as fsync:
            module.write_exclusive_json(output, {"schema": "TestOnlyV1"})
        self.assertGreaterEqual(fsync.call_count, 2)
        self.assertEqual(stat.S_IMODE(output.stat().st_mode), 0o600)

    def test_verify_accepts_only_exact_externally_signed_evidence(self) -> None:
        report = self.collect_valid_report()
        evidence = self.signed_evidence(report)
        evidence_path = self.root / "docs/evidence/k4-platform-spike.json"
        evidence_path.parent.mkdir(parents=True)
        evidence_path.write_bytes(_canonical_test_json(evidence) + b"\n")
        evidence_path.chmod(0o644)
        self.git("add", evidence_path.relative_to(self.root).as_posix())
        self.git("commit", "-qm", "test-only signed K4 evidence")
        evidence_path.write_text(
            '{"liveWorktreeSubstitution":true}\n',
            encoding="utf-8",
        )
        result = self.run_verify(evidence_path)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("verified external signature only", result.stdout)

    def test_verify_rejects_altered_result_bundle_digest(self) -> None:
        report = self.collect_valid_report()
        evidence = self.signed_evidence(report)
        evidence["resultBundleDigest"] = "f" * 64
        evidence_path = self.write_external("altered-evidence.json", evidence)
        result = self.run_verify(evidence_path)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("evidence signature is invalid", result.stderr)

    def test_verify_rejects_resigned_wrong_device_and_impossible_entitlement(
        self,
    ) -> None:
        report = self.collect_valid_report()
        for label, mutation, diagnostic in (
            (
                "wrong-device",
                lambda evidence: evidence.__setitem__(
                    "probeDeviceIdentityDigest",
                    "e" * 64,
                ),
                "deviceIdentityDigest",
            ),
            (
                "impossible-entitlement",
                lambda evidence: evidence.__setitem__("entitlementInventory", []),
                "disabledMissingEntitlement",
            ),
        ):
            evidence = self.signed_evidence(report)
            evidence.pop("signature")
            mutation(evidence)
            evidence = self.signed(evidence)
            evidence_path = self.write_external(f"{label}.json", evidence)
            result = self.run_verify(evidence_path)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn(diagnostic, result.stderr)
            if label == "impossible-entitlement":
                self.assertIn("deterministic precedence", result.stderr)

        evidence = self.signed_evidence(report)
        evidence.pop("signature")
        evidence["entitlementInventory"] = []
        evidence["status"] = "disabledMissingEntitlement"
        evidence = self.signed(evidence)
        evidence_path = self.write_external(
            "missing-entitlement-disabled.json",
            evidence,
        )
        result = self.run_verify(evidence_path)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_repository_runner_exposes_no_signing_operation_or_private_key(
        self,
    ) -> None:
        help_result = subprocess.run(
            [sys.executable, str(RUNNER), "--help"],
            cwd=self.root,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(help_result.returncode, 0, help_result.stderr)
        self.assertNotIn("sign-evidence", help_result.stdout)
        source = RUNNER.read_text(encoding="utf-8")
        self.assertNotIn("privateKey", source)
        self.assertNotIn("sign_ed25519", source)
        self.assertNotIn("_test_ed25519_sign", source)


if __name__ == "__main__":
    unittest.main()
