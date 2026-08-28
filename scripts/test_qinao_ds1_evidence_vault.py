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
import os
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "scripts" / "qinao_ds1_evidence_vault.swift"
SWIFTC = Path("/usr/bin/swiftc")


class QinaoDS1EvidenceVaultTests(unittest.TestCase):
    maxDiff = None

    def compile_tool(self, directory: Path, *, testing: bool) -> Path:
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
        serialized = json.dumps(receipt, sort_keys=True)
        for forbidden in (
            "rawSQLiteSHA256",
            "rawRowRoot",
            "details_json",
            "remediation",
            "fixture secret finding body",
        ):
            self.assertNotIn(forbidden, serialized)

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


if __name__ == "__main__":
    unittest.main(verbosity=2)
