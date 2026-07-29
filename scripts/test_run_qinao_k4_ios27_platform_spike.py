from __future__ import annotations

import base64
import copy
import hashlib
import importlib.util
import json
import os
import plistlib
import shutil
import stat
import subprocess
import sys
import tempfile
import unittest
from datetime import datetime, timezone
from pathlib import Path
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
        self.sdk_parent = (
            self.developer / "Platforms/iPhoneOS.platform/Developer/SDKs"
        )
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
                        "publicKey": base64.b64encode(public_key).decode(
                            "ascii"
                        ),
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
                {"event": event, "observation": "passed"}
                for event in LIFECYCLE_EVENTS
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

    def run_collect(self, output: Path | None = None) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            self.collect_command(output),
            cwd=self.root,
            capture_output=True,
            text=True,
            check=False,
        )

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
        with mock.patch.object(
            k4_runner,
            "datetime",
            CountingDateTime,
        ), mock.patch.object(
            sys,
            "argv",
            [str(RUNNER), *command[2:]],
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
        with mock.patch.object(
            k4_runner,
            "datetime",
            CountingDateTime,
        ), mock.patch.object(
            sys,
            "argv",
            [str(RUNNER), *command[2:]],
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

    def test_git_timeout_and_spawn_errors_fail_closed(self) -> None:
        for error in (
            subprocess.TimeoutExpired(["git", "rev-parse"], 30),
            OSError("test-only spawn failure"),
        ):
            with self.subTest(error=type(error).__name__):
                with mock.patch.object(
                    k4_runner.subprocess,
                    "run",
                    side_effect=error,
                ):
                    with self.assertRaisesRegex(
                        k4_runner.GateError,
                        "unavailable or timed out",
                    ):
                        k4_runner.run_git(self.root, "rev-parse", "HEAD")

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
                    self.sdk
                    / "System/Library/CoreServices/SystemVersion.plist"
                ).read_bytes()
            ).hexdigest(),
        )

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
            k4_runner.validate_framework_observations(
                canonical_observations
            ),
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

    def test_supported_exact_profile_rejects_absent_declared_framework_api(
        self,
    ) -> None:
        self.interface.write_text(
            "public struct DifferentCapability {}\n",
            encoding="utf-8",
        )
        result = self.run_collect()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("deterministic precedence", result.stderr)
        self.assertIn("disabledMissingTarget", result.stderr)
        self.assertFalse(self.output.exists())

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

        result = subprocess.run(
            command,
            cwd=self.root,
            capture_output=True,
            text=True,
            check=False,
        )

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("hard link", result.stderr)
        self.assertFalse(self.output.exists())

    def test_external_input_path_swap_is_detected_on_the_open_descriptor(
        self,
    ) -> None:
        spec = importlib.util.spec_from_file_location(
            "qinao_k4_bound_reader",
            RUNNER,
        )
        self.assertIsNotNone(spec)
        assert spec is not None
        module = importlib.util.module_from_spec(spec)
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
        spec = importlib.util.spec_from_file_location("qinao_k4_runner", RUNNER)
        self.assertIsNotNone(spec)
        assert spec is not None
        module = importlib.util.module_from_spec(spec)
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

    def test_repository_runner_exposes_no_signing_operation_or_private_key(self) -> None:
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
