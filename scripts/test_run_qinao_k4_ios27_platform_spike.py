from __future__ import annotations

import base64
import copy
import hashlib
import importlib.util
import json
import os
import plistlib
import stat
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from scripts.test_check_qinao_owner_ledger import (
    _canonical_test_json,
    _test_ed25519_key,
    _test_ed25519_sign,
)


PROJECT_ROOT = Path(__file__).resolve().parents[1]
RUNNER = PROJECT_ROOT / "scripts" / "run_qinao_k4_ios27_platform_spike.py"
TEST_SEED = bytes(range(32))
TEST_KEY_ID = "test-only-k4-key"
REPOSITORY_IDENTITY = "test-only/qinao-k4-platform-spike"
ISSUED_AT = "2026-07-29T00:00:00Z"
EXPIRES_AT = "2030-01-01T00:00:00Z"
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
        self.sdk = (
            self.developer
            / "Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS27.0.sdk"
        )
        interface = (
            self.sdk
            / "System/Library/Frameworks/TestSecurity.framework/Modules"
            / "TestSecurity.swiftmodule/arm64-apple-ios.swiftinterface"
        )
        interface.parent.mkdir(parents=True)
        interface.write_text(
            "public struct TestSecurityCapability {}\n",
            encoding="utf-8",
        )
        (self.sdk / "SDKSettings.json").write_bytes(
            _canonical_test_json(
                {
                    "CanonicalName": "iphoneos27.0",
                    "Version": "27.0",
                    "ProductBuildVersion": "24A100",
                }
            )
            + b"\n"
        )
        (contents / "version.plist").write_bytes(
            plistlib.dumps(
                {
                    "CFBundleShortVersionString": "27.0",
                    "CFBundleVersion": "27000",
                },
                fmt=plistlib.FMT_BINARY,
            )
        )

        public_key, _prefix, _scalar = _test_ed25519_key(TEST_SEED)
        self.trust_root = {
            "schema": "QinaoAdmissionTrustRootV1",
            "repositoryIdentity": REPOSITORY_IDENTITY,
            "issuedAt": ISSUED_AT,
            "expiresAt": EXPIRES_AT,
            "keys": [
                {
                    "keyID": TEST_KEY_ID,
                    "role": role,
                    "publicKey": base64.b64encode(public_key).decode("ascii"),
                }
                for role in (
                    "k4-device-profile-signer",
                    "k4-evidence-signer",
                )
            ],
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
        signed["signature"] = base64.b64encode(
            _test_ed25519_sign(TEST_SEED, _canonical_test_json(value))
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
            field: matrix[field]
            for field in (
                "target",
                "requiredEntitlements",
                "sqlite",
                "transport",
                "lifecycle",
            )
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
            "osBuild": "24A100",
            "xcodeVersion": "27.0",
            "xcodeBuild": "27000",
            "sdkCanonicalName": "iphoneos27.0",
            "sdkVersion": "27.0",
            "sdkBuild": "24A100",
            "signingIdentityClass": "Apple Development",
            "entitlementInventory": [ENTITLEMENT],
            "probeMatrix": self.probe_matrix(),
            "issuedAt": ISSUED_AT,
            "expiresAt": EXPIRES_AT,
            "nonce": "test-only-device-profile",
            "signer": TEST_KEY_ID,
            "role": "k4-device-profile-signer",
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
                "signer": TEST_KEY_ID,
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
        self.assertIn("supportedExactProfile", result.stderr)
        self.assertIn("entitlement", result.stderr)
        self.assertFalse(self.output.exists())

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
                "supportedExactProfile",
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
