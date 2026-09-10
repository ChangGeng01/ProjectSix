"""Black-box gates for the repository-external Deep Scan #1 evidence vault.

The production tool is a single auditable Swift source file.  These tests compile
it twice:

* a production build, whose public CLI must not admit raw key material; and
* a test build, whose in-process self-test exercises SQLite backup/serialization,
  authenticated encryption, tamper rejection, wrong-key rejection, and public
  receipt redaction without creating a Keychain item or persistent snapshot.

Run directly with:
    /usr/bin/python3 scripts/test_qinao_ds1_evidence_vault.py
"""

from __future__ import annotations

import json
import hashlib
import os
import sqlite3
import stat
import subprocess
import tempfile
import unittest
import uuid
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "scripts" / "qinao_ds1_evidence_vault.swift"
SWIFTC = Path("/usr/bin/swiftc")
SCAN_ID = "bcffa52e-53cf-4407-b216-14288ae07061"
TARGET_REVISION = "c8f80486895e12e26d567e610c35a6e2141b3489"
SENSITIVE_SENTINEL = "fixture-sensitive-title-summary-remediation"


def make_details_json(byte_length: int) -> str:
    prefix = '{"p":"'
    suffix = '"}'
    fill = byte_length - len(prefix.encode()) - len(suffix.encode())
    if fill < 0:
        raise ValueError("details length is too small")
    value = prefix + ("x" * fill) + suffix
    assert len(value.encode()) == byte_length
    return value


def build_ds1_fixture(path: Path, *, fix_progress_in_wal: bool = True) -> sqlite3.Connection:
    connection = sqlite3.connect(path)
    connection.execute("PRAGMA foreign_keys=ON")
    connection.execute("PRAGMA journal_mode=WAL")
    connection.executescript(
        """
        CREATE TABLE scans (
          id TEXT PRIMARY KEY, workspace_id TEXT, target_path TEXT,
          target_revision TEXT, target_snapshot_digest TEXT, scope TEXT,
          mode TEXT, user_context TEXT, diff_target_kind TEXT,
          diff_base_revision TEXT, diff_head_revision TEXT,
          diff_content_digest TEXT, scan_dir TEXT, status TEXT, phase TEXT,
          handoff_status TEXT, failure_message TEXT, started_at TEXT,
          completed_at TEXT, created_at TEXT, updated_at TEXT,
          handoff_claimed_at TEXT, handoff_claim_token TEXT,
          seal_manifest_digest TEXT, target_device INTEGER,
          target_inode INTEGER, canceled_at TEXT,
          deep_scan_owner_thread_id TEXT, continuation_thread_id TEXT,
          target_id TEXT, target_summary TEXT, recipe_json TEXT,
          parent_scan_id TEXT, cost_json TEXT, model TEXT,
          reasoning_effort TEXT, completion_warnings_json TEXT,
          retained_source_digests_json TEXT
        );
        CREATE TABLE scan_progress (
          scan_id TEXT PRIMARY KEY, review_items_total INTEGER,
          review_items_completed INTEGER, reportable_findings_count INTEGER,
          deep_review_pass INTEGER, updated_at TEXT, scope_file_count INTEGER,
          phase_items_total INTEGER, phase_items_completed INTEGER,
          phase_progress_unit TEXT, preflight_issues_json TEXT,
          preflight_checks_total INTEGER, preflight_checks_completed INTEGER
        );
        CREATE TABLE findings (
          id TEXT PRIMARY KEY, fingerprint TEXT, rule_id TEXT,
          identity_anchor TEXT, identity_instance TEXT,
          created_at TEXT, updated_at TEXT
        );
        CREATE TABLE finding_occurrences (
          id TEXT PRIMARY KEY, finding_id TEXT NOT NULL REFERENCES findings(id),
          scan_id TEXT NOT NULL REFERENCES scans(id), title TEXT NOT NULL,
          summary TEXT NOT NULL, severity TEXT NOT NULL, confidence TEXT NOT NULL,
          remediation TEXT NOT NULL, created_at TEXT NOT NULL,
          details_json TEXT NOT NULL
        );
        CREATE TABLE finding_locations (
          id INTEGER PRIMARY KEY, occurrence_id TEXT NOT NULL
            REFERENCES finding_occurrences(id), relative_path TEXT NOT NULL,
          start_line INTEGER NOT NULL, end_line INTEGER NOT NULL,
          role TEXT, sort_order INTEGER NOT NULL
        );
        CREATE TABLE scan_artifacts (
          scan_id TEXT NOT NULL REFERENCES scans(id), kind TEXT NOT NULL,
          path TEXT NOT NULL, created_at TEXT NOT NULL,
          PRIMARY KEY(scan_id, kind)
        );
        """
    )
    now = "2026-08-28T00:00:00Z"
    scan_values = (
        SCAN_ID, "workspace", "/fixture/target", TARGET_REVISION, None,
        "repository", "deep", None, None, None, None, None,
        str(path.parent / "dead-artifacts"), "complete", "reporting", "delivered",
        None, now, now, now, now, None, None,
        "sha256:fd5df1a1157bfceab6e3d38a73e771f50f5ddb4041780d50f95bacc2a80e79be",
        None, None, None, None, None, None, None, "{}", None, "{}",
        "fixture-model", "high", "[]", None,
    )
    assert len(scan_values) == 38
    connection.execute(
        "INSERT INTO scans VALUES (" + ",".join("?" for _ in scan_values) + ")",
        scan_values,
    )
    connection.execute(
        "INSERT INTO scan_progress VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)",
        (SCAN_ID, 0, 0, 110, 35, now, 10388, 4, 4, "report_artifacts", "[]", 0, 0),
    )

    detail_lengths = [2351, 703607] + ([52726] * 108) + [52739]
    assert len(detail_lengths) == 111
    assert sum(detail_lengths) == 6453105
    location_id = 1
    for ordinal in range(111):
        finding_id = f"finding-{ordinal:03d}"
        occurrence_id = f"occurrence-{ordinal:03d}"
        connection.execute(
            "INSERT INTO findings VALUES (?,?,?,?,?,?,?)",
            (finding_id, f"fingerprint-{ordinal:03d}", "fixture-rule", "anchor", str(ordinal), now, now),
        )
        if ordinal < 30:
            severity = "high"
        elif ordinal < 95:
            severity = "medium"
        else:
            severity = "low"
        if ordinal == 110:
            severity = "placeholder"
        connection.execute(
            "INSERT INTO finding_occurrences VALUES (?,?,?,?,?,?,?,?,?,?)",
            (
                occurrence_id, finding_id, SCAN_ID, SENSITIVE_SENTINEL,
                SENSITIVE_SENTINEL, severity, "high", SENSITIVE_SENTINEL,
                now, make_details_json(detail_lengths[ordinal]),
            ),
        )
        count = 25 if ordinal < 52 else 24
        for sort_order in range(count):
            connection.execute(
                "INSERT INTO finding_locations VALUES (?,?,?,?,?,?,?)",
                (
                    location_id, occurrence_id,
                    f"{SENSITIVE_SENTINEL}/path-{ordinal:03d}-{sort_order:02d}",
                    1, 1, "primary", sort_order,
                ),
            )
            location_id += 1
    assert location_id - 1 == 2716
    dead_root = path.parent / "dead-artifacts"
    artifacts = (
        ("coverage", "coverage.json"),
        ("findings", "findings.json"),
        ("manifest", "scan-manifest.json"),
        ("markdownReport", "report.md"),
    )
    for kind, filename in artifacts:
        connection.execute(
            "INSERT INTO scan_artifacts VALUES (?,?,?,?)",
            (SCAN_ID, kind, str(dead_root / filename), now),
        )
    connection.commit()
    connection.execute("PRAGMA wal_checkpoint(TRUNCATE)")
    if fix_progress_in_wal:
        connection.execute(
            "UPDATE scan_progress SET reportable_findings_count=111 WHERE scan_id=?",
            (SCAN_ID,),
        )
        connection.execute(
            "UPDATE finding_occurrences SET severity='low' WHERE id='occurrence-110'"
        )
        connection.commit()
    return connection


class QinaoDS1EvidenceVaultTests(unittest.TestCase):
    maxDiff = None

    def compile_tool(
        self,
        directory: Path,
        *,
        testing: bool,
        integration_testing: bool = False,
    ) -> Path:
        binary = directory / ("qinao-ds1-vault-test" if testing else "qinao-ds1-vault")
        cache = directory / "module-cache"
        command = [
            str(SWIFTC),
            "-module-cache-path",
            str(cache),
            "-O",
        ]
        if testing:
            command.extend(["-D", "QINAO_TESTING"])
        if integration_testing:
            command.extend(["-D", "QINAO_INTEGRATION_TESTING"])
        command.extend([str(SOURCE), "-o", str(binary)])
        completed = subprocess.run(
            command,
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
            env={
                **os.environ,
                "CLANG_MODULE_CACHE_PATH": str(cache),
                "SWIFT_MODULECACHE_PATH": str(cache),
            },
        )
        self.assertEqual(
            completed.returncode,
            0,
            msg=f"stdout:\n{completed.stdout}\nstderr:\n{completed.stderr}",
        )
        return binary

    def run_tool(self, binary: Path, *arguments: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [str(binary), *arguments],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )

    def test_production_cli_has_no_raw_secret_input_surface(self) -> None:
        with tempfile.TemporaryDirectory(prefix="qinao-ds1-vault-test-") as raw:
            binary = self.compile_tool(Path(raw), testing=False)
            completed = self.run_tool(binary, "help")

        self.assertEqual(completed.returncode, 0, msg=completed.stderr)
        help_text = completed.stdout.lower()
        for forbidden in (
            "--password",
            "--passphrase",
            "--key-hex",
            "--key-file",
            "--secret",
        ):
            self.assertNotIn(forbidden, help_text)
        self.assertIn("freeze", help_text)
        self.assertIn("verify", help_text)
        self.assertIn("recover-receipt", help_text)

    def test_production_build_rejects_test_only_self_test(self) -> None:
        with tempfile.TemporaryDirectory(prefix="qinao-ds1-vault-test-") as raw:
            binary = self.compile_tool(Path(raw), testing=False)
            completed = self.run_tool(binary, "self-test")

        self.assertNotEqual(completed.returncode, 0)
        self.assertNotIn("rawSQLiteSHA256", completed.stdout)
        self.assertNotIn("rawRowRoot", completed.stdout)

    def test_in_process_security_and_recovery_contract(self) -> None:
        with tempfile.TemporaryDirectory(prefix="qinao-ds1-vault-test-") as raw:
            binary = self.compile_tool(Path(raw), testing=True)
            completed = self.run_tool(binary, "self-test")

        self.assertEqual(
            completed.returncode,
            0,
            msg=f"stdout:\n{completed.stdout}\nstderr:\n{completed.stderr}",
        )
        receipt = json.loads(completed.stdout)
        self.assertEqual(receipt["schema"], "qinao.ds1-vault-self-test.v1")
        self.assertEqual(receipt["status"], "pass")
        self.assertGreaterEqual(receipt["checksPassed"], 12)
        self.assertTrue(receipt["sqliteBackupRoundTrip"])
        self.assertTrue(receipt["walRowsIncluded"])
        self.assertTrue(receipt["deterministicRowEncoding"])
        self.assertTrue(receipt["tamperRejected"])
        self.assertTrue(receipt["wrongKeyRejected"])
        self.assertTrue(receipt["headerTamperRejected"])
        self.assertTrue(receipt["truncationRejected"])
        self.assertTrue(receipt["publicReceiptRedacted"])
        self.assertTrue(receipt["noPlaintextFileCreated"])
        self.assertTrue(receipt["privateManifestDriftRejected"])
        self.assertTrue(receipt["nonCanonicalReceiptBytesRejected"])
        self.assertTrue(receipt["relativeCustodyRejected"])
        self.assertTrue(receipt["symlinkCustodyRejected"])
        self.assertTrue(receipt["repositoryCustodyRejected"])
        self.assertTrue(receipt["oversizedLengthRejected"])
        self.assertTrue(receipt["staleAtomicTemporaryRecovered"])
        self.assertRegex(receipt["executableBinarySHA256"], r"^[0-9a-f]{64}$")
        self.assertEqual(
            receipt["publicReceiptV1GoldenSHA256"],
            "368d6d696dc778753930be828f62df04297e15683eb192b3a5b5b4538e3cc1f6",
        )
        serialized = json.dumps(receipt, sort_keys=True)
        for forbidden in (
            "rawSQLiteSHA256",
            "rawRowRoot",
            "details_json",
            "remediation",
            "fixture secret finding body",
        ):
            self.assertNotIn(forbidden, serialized)

    def test_executable_digest_ignores_spoofed_argv_zero(self) -> None:
        with tempfile.TemporaryDirectory(prefix="qinao-ds1-argv0-test-") as raw:
            binary = self.compile_tool(Path(raw), testing=True)
            completed = subprocess.run(
                ["/etc/hosts", "self-test"],
                executable=str(binary),
                cwd=ROOT,
                capture_output=True,
                text=True,
                check=False,
            )
            expected = hashlib.sha256(binary.read_bytes()).hexdigest()

        self.assertEqual(
            completed.returncode,
            0,
            msg=f"stdout:\n{completed.stdout}\nstderr:\n{completed.stderr}",
        )
        self.assertEqual(json.loads(completed.stdout)["executableBinarySHA256"], expected)

    def test_source_uses_backup_api_keychain_and_authenticated_encryption(self) -> None:
        text = SOURCE.read_text(encoding="utf-8")
        required = (
            "sqlite3_backup_init",
            "sqlite3_backup_step",
            "sqlite3_serialize",
            "AES.GCM.seal",
            "AES.GCM.open",
            "SecItemCopyMatching",
            "SecItemAdd",
            "kSecAttrSynchronizable",
            "kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly",
        )
        for needle in required:
            self.assertIn(needle, text)
        forbidden = (
            "security add-generic-password",
            "security find-generic-password",
            "hdiutil",
        )
        for needle in forbidden:
            self.assertNotIn(needle, text)

    @unittest.skipUnless(
        os.environ.get("QINAO_RUN_KEYCHAIN_INTEGRATION") == "1",
        "set QINAO_RUN_KEYCHAIN_INTEGRATION=1 for real production/Keychain gates",
    )
    def test_production_freeze_verify_mutation_and_custody_contract(self) -> None:
        with tempfile.TemporaryDirectory(prefix="qinao-ds1-production-gate-") as raw:
            directory = Path(raw).resolve()
            os.chmod(directory, 0o700)
            binary = self.compile_tool(
                directory,
                testing=False,
                integration_testing=True,
            )
            source = directory / "source.sqlite3"
            source_connection = build_ds1_fixture(source)
            snapshot = directory / "snapshot.qds1"
            receipt = directory / "snapshot.capture-receipt.json"
            verification = directory / "verification-receipt.json"
            epoch = "test-" + uuid.uuid4().hex
            erasure_scope = "test-only"
            source_sha = hashlib.sha256(SOURCE.read_bytes()).hexdigest()

            def freeze_command(
                source_path: Path,
                destination_path: Path,
                receipt_path: Path,
                *,
                key_epoch: str = epoch,
                failpoint: str | None = None,
            ) -> subprocess.CompletedProcess[str]:
                arguments = [
                    "freeze",
                    "--source",
                    str(source_path),
                    "--destination",
                    str(destination_path),
                    "--receipt",
                    str(receipt_path),
                    "--scan-id",
                    SCAN_ID,
                    "--target-revision",
                    TARGET_REVISION,
                    "--key-epoch",
                    key_epoch,
                    "--erasure-scope",
                    erasure_scope,
                    "--tool-source-sha256",
                    source_sha,
                ]
                if failpoint is not None:
                    arguments.extend(["--test-failpoint", failpoint])
                return self.run_tool(binary, *arguments)

            def verify_command(
                snapshot_path: Path,
                receipt_path: Path,
                verification_path: Path,
                *,
                key_epoch: str = epoch,
            ) -> subprocess.CompletedProcess[str]:
                return self.run_tool(
                    binary,
                    "verify",
                    "--snapshot",
                    str(snapshot_path),
                    "--receipt",
                    str(receipt_path),
                    "--verification-receipt",
                    str(verification_path),
                    "--scan-id",
                    SCAN_ID,
                    "--target-revision",
                    TARGET_REVISION,
                    "--key-epoch",
                    key_epoch,
                    "--erasure-scope",
                    erasure_scope,
                )

            def recover_command(
                snapshot_path: Path,
                receipt_path: Path,
                *,
                key_epoch: str = epoch,
            ) -> subprocess.CompletedProcess[str]:
                return self.run_tool(
                    binary,
                    "recover-receipt",
                    "--snapshot",
                    str(snapshot_path),
                    "--receipt",
                    str(receipt_path),
                    "--scan-id",
                    SCAN_ID,
                    "--target-revision",
                    TARGET_REVISION,
                    "--key-epoch",
                    key_epoch,
                    "--erasure-scope",
                    erasure_scope,
                )

            try:
                frozen = freeze_command(source, snapshot, receipt)
                self.assertEqual(
                    frozen.returncode,
                    0,
                    msg=f"stdout:\n{frozen.stdout}\nstderr:\n{frozen.stderr}",
                )
                reopened = verify_command(snapshot, receipt, verification)
                self.assertEqual(
                    reopened.returncode,
                    0,
                    msg=f"stdout:\n{reopened.stdout}\nstderr:\n{reopened.stderr}",
                )
                verification_object = json.loads(reopened.stdout)
                self.assertEqual(
                    verification_object["schema"],
                    "qinao.ds1-independent-reopen-receipt.v2",
                )
                self.assertTrue(verification_object["privateManifestAuthenticated"])
                self.assertTrue(verification_object["privateManifestScanBindingChecked"])
                self.assertTrue(verification_object["privateManifestAuditFragmentRecomputed"])
                self.assertTrue(verification_object["publicReceiptExactBytes"])
                for artifact in (snapshot, receipt, verification):
                    info = artifact.stat()
                    self.assertTrue(stat.S_ISREG(info.st_mode))
                    self.assertEqual(stat.S_IMODE(info.st_mode), 0o400)
                    self.assertEqual(info.st_nlink, 1)
                    self.assertEqual(info.st_uid, os.getuid())
                public_text = frozen.stdout + frozen.stderr + reopened.stdout + reopened.stderr
                public_text += receipt.read_text(encoding="utf-8")
                public_text += verification.read_text(encoding="utf-8")
                self.assertNotIn(SENSITIVE_SENTINEL, public_text)
                self.assertNotIn("rawSQLiteSHA256", public_text)
                self.assertNotIn("aggregateRawRowRootSHA256", public_text)

                original_snapshot_bytes = snapshot.read_bytes()
                tampered_bytes = bytearray(original_snapshot_bytes)
                tampered_bytes[-5] ^= 1
                os.chmod(snapshot, 0o600)
                snapshot.write_bytes(tampered_bytes)
                os.chmod(snapshot, 0o400)
                tampered_result = verify_command(
                    snapshot,
                    receipt,
                    directory / "tampered-verification.json",
                )
                self.assertNotEqual(tampered_result.returncode, 0)
                self.assertFalse((directory / "tampered-verification.json").exists())
                os.chmod(snapshot, 0o600)
                snapshot.write_bytes(original_snapshot_bytes)
                os.chmod(snapshot, 0o400)

                original_receipt_bytes = receipt.read_bytes()
                os.chmod(receipt, 0o600)
                receipt.write_bytes(original_receipt_bytes + b"\n")
                os.chmod(receipt, 0o400)
                noncanonical_result = verify_command(
                    snapshot,
                    receipt,
                    directory / "noncanonical-verification.json",
                )
                self.assertNotEqual(noncanonical_result.returncode, 0)
                self.assertFalse((directory / "noncanonical-verification.json").exists())
                os.chmod(receipt, 0o600)
                receipt.write_bytes(original_receipt_bytes)
                os.chmod(receipt, 0o400)

                wrong_epoch_result = verify_command(
                    snapshot,
                    receipt,
                    directory / "wrong-epoch-verification.json",
                    key_epoch="test-missing-" + uuid.uuid4().hex,
                )
                self.assertNotEqual(wrong_epoch_result.returncode, 0)
                self.assertFalse((directory / "wrong-epoch-verification.json").exists())

                symlink_target = directory / "symlink-target.qds1"
                symlink_target.write_bytes(original_snapshot_bytes)
                os.chmod(symlink_target, 0o400)
                snapshot.unlink()
                snapshot.symlink_to(symlink_target)
                symlink_result = verify_command(
                    snapshot,
                    receipt,
                    directory / "symlink-verification.json",
                )
                self.assertNotEqual(symlink_result.returncode, 0)
                snapshot.unlink()
                snapshot.write_bytes(original_snapshot_bytes)
                os.chmod(snapshot, 0o400)

                hardlink_source = directory / "hardlink-source.qds1"
                os.link(snapshot, hardlink_source)
                hardlink_result = verify_command(
                    snapshot,
                    receipt,
                    directory / "hardlink-verification.json",
                )
                self.assertNotEqual(hardlink_result.returncode, 0)
                hardlink_source.unlink()

                drift_source = directory / "drift.sqlite3"
                drift_connection = build_ds1_fixture(
                    drift_source,
                    fix_progress_in_wal=False,
                )
                try:
                    drift_result = freeze_command(
                        drift_source,
                        directory / "drift.qds1",
                        directory / "drift.capture-receipt.json",
                    )
                finally:
                    drift_connection.close()
                self.assertNotEqual(drift_result.returncode, 0)
                self.assertFalse((directory / "drift.qds1").exists())
                self.assertFalse((directory / "drift.capture-receipt.json").exists())

                relative_result = freeze_command(
                    source,
                    Path("relative.qds1"),
                    Path("relative.capture-receipt.json"),
                )
                self.assertNotEqual(relative_result.returncode, 0)
                self.assertFalse((ROOT / "relative.qds1").exists())
                self.assertFalse((ROOT / "relative.capture-receipt.json").exists())

                collision = directory / "collision.capture-receipt.json"
                collision.write_text("existing", encoding="utf-8")
                os.chmod(collision, 0o400)
                collision_result = freeze_command(
                    source,
                    directory / "collision.qds1",
                    collision,
                )
                self.assertNotEqual(collision_result.returncode, 0)
                self.assertFalse((directory / "collision.qds1").exists())
                self.assertEqual(collision.read_text(encoding="utf-8"), "existing")

                same_path = directory / "same-output"
                same_path_result = freeze_command(source, same_path, same_path)
                self.assertNotEqual(same_path_result.returncode, 0)
                self.assertFalse(same_path.exists())

                interrupted_snapshot = directory / "interrupted.qds1"
                recovered_receipt = directory / "interrupted.capture-receipt.json"
                interrupted = freeze_command(
                    source,
                    interrupted_snapshot,
                    recovered_receipt,
                    failpoint="after-snapshot-publish",
                )
                self.assertNotEqual(interrupted.returncode, 0)
                self.assertTrue(interrupted_snapshot.exists())
                self.assertFalse(recovered_receipt.exists())
                dead_artifacts = directory / "dead-artifacts"
                dead_artifacts.mkdir()
                for name in ("coverage.json", "findings.json", "scan-manifest.json", "report.md"):
                    (dead_artifacts / name).write_text(SENSITIVE_SENTINEL, encoding="utf-8")
                recovered = recover_command(interrupted_snapshot, recovered_receipt)
                self.assertEqual(
                    recovered.returncode,
                    0,
                    msg=f"stdout:\n{recovered.stdout}\nstderr:\n{recovered.stderr}",
                )
                recovered_object = json.loads(recovered.stdout)
                self.assertEqual(recovered_object["status"], "recovered")
                self.assertTrue(recovered_object["publicReceiptExactBytesRebuilt"])
                recovered_verification = directory / "interrupted-verification.json"
                recovered_reopen = verify_command(
                    interrupted_snapshot,
                    recovered_receipt,
                    recovered_verification,
                )
                self.assertEqual(
                    recovered_reopen.returncode,
                    0,
                    msg=(
                        f"stdout:\n{recovered_reopen.stdout}\n"
                        f"stderr:\n{recovered_reopen.stderr}"
                    ),
                )
                self.assertTrue(
                    json.loads(recovered_reopen.stdout)["deadLocatorLiveReprobe"].startswith("drift:")
                )
                receipt_before_duplicate = recovered_receipt.stat()
                duplicate_recovery = recover_command(interrupted_snapshot, recovered_receipt)
                self.assertEqual(
                    duplicate_recovery.returncode,
                    0,
                    msg=(
                        f"stdout:\n{duplicate_recovery.stdout}\n"
                        f"stderr:\n{duplicate_recovery.stderr}"
                    ),
                )
                self.assertEqual(
                    json.loads(duplicate_recovery.stdout)["status"],
                    "already-present-exact",
                )
                receipt_after_duplicate = recovered_receipt.stat()
                self.assertEqual(receipt_before_duplicate.st_ino, receipt_after_duplicate.st_ino)
                self.assertEqual(receipt_before_duplicate.st_mtime_ns, receipt_after_duplicate.st_mtime_ns)
                self.assertEqual(
                    recovered_receipt.read_bytes(),
                    json.dumps(
                        json.loads(recovered_receipt.read_text(encoding="utf-8")),
                        sort_keys=True,
                        separators=(",", ":"),
                    ).encode(),
                )
                self.assertFalse(
                    any(path.name.startswith(".qinao-vault-") for path in directory.iterdir())
                )
            finally:
                source_connection.close()
                erased = self.run_tool(
                    binary,
                    "purge-test-key-epoch",
                    "--key-epoch",
                    epoch,
                    "--confirm",
                    "TEST-ONLY-ERASURE",
                )
                self.assertEqual(
                    erased.returncode,
                    0,
                    msg=f"stdout:\n{erased.stdout}\nstderr:\n{erased.stderr}",
                )


if __name__ == "__main__":
    unittest.main(verbosity=2)
