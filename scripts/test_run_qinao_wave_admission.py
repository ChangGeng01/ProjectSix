from __future__ import annotations

import base64
import copy
import hashlib
import json
import os
import stat
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from scripts.test_check_qinao_owner_ledger import (
    _canonical_test_json,
    _test_ed25519_key,
    _test_ed25519_sign,
)


PROJECT_ROOT = Path(__file__).resolve().parents[1]
RUNNER = PROJECT_ROOT / "scripts" / "run_qinao_wave_admission.py"
TEST_SEED = bytes(reversed(range(32)))
TEST_KEY_ID = "test-only-wave-key"
REPOSITORY_IDENTITY = "test-only/qinao-wave-runner"
ISSUED_AT = "2026-07-29T00:00:00Z"
EXPIRES_AT = "2030-01-01T00:00:00Z"


FAKE_CHECKER = """#!/usr/bin/env python3
import os
import sys

print("test-only owner checker invoked")
raise SystemExit(int(os.environ.get("FAKE_CHECKER_EXIT", "0")))
"""


class WaveAdmissionRunnerTests(unittest.TestCase):
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
        self.write_repository("README.md", "test-only wave fixture\n")
        self.git("add", "README.md")
        self.git("commit", "-qm", "test-only base")
        self.base_commit = self.git("rev-parse", "HEAD")
        self.base_tree = self.git("rev-parse", "HEAD^{tree}")
        self.paths = [
            "docs/evidence/adapter.json",
            "docs/evidence/bundle.json",
            "docs/evidence/create.json",
            "docs/evidence/extension.json",
            "docs/evidence/fixture.json",
            "docs/evidence/paths.txt",
            "docs/specs/owner-ledger.json",
            "scripts/check_qinao_owner_ledger.py",
        ]
        for category in ("adapter", "create", "extension", "fixture"):
            self.write_repository(
                f"docs/evidence/{category}.json",
                _canonical_test_json(
                    {
                        "schema": "TestOnlyCategoryV1",
                        "category": category,
                        "status": "notApplicable",
                    }
                )
                + b"\n",
            )
        self.write_repository("docs/specs/owner-ledger.json", b"{}\n")
        self.write_repository(
            "scripts/check_qinao_owner_ledger.py",
            FAKE_CHECKER,
            mode=0o755,
        )
        self.path_list_bytes = (
            "".join(f"{path}\n" for path in self.paths).encode("utf-8")
        )
        self.write_repository(
            "docs/evidence/paths.txt",
            self.path_list_bytes,
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
                    "root-admission-signer",
                    "runtime-chain-signer",
                    "source-selector",
                    "wave-admission-signer",
                    "wave-bundle-reviewer",
                )
            ],
            "revokedNonces": [],
        }
        self.source_selection = self.signed(
            {
                "schema": "QinaoSourceSelectionV1",
                "repositoryIdentity": REPOSITORY_IDENTITY,
                "selectedCommit": self.base_commit,
                "selectedTree": self.base_tree,
                "approvedDesignBlob": "d" * 64,
                "externalVerifierSHA256": "e" * 64,
                "issuedAt": ISSUED_AT,
                "expiresAt": EXPIRES_AT,
                "nonce": "test-only-source-selection",
                "signer": TEST_KEY_ID,
                "role": "source-selector",
                "signatureAlgorithm": "Ed25519",
            }
        )
        self.previous_receipt = self.signed(
            {
                "schema": "QinaoRootAdmissionReceiptV1",
                "repositoryIdentity": REPOSITORY_IDENTITY,
                "selectedTree": self.base_tree,
                "candidateTree": self.base_tree,
                "wave": "root",
                "sequenceOrdinal": -1,
                "outcome": "admitted",
                "issuedAt": ISSUED_AT,
                "expiresAt": EXPIRES_AT,
                "nonce": "test-only-root-receipt",
                "signer": TEST_KEY_ID,
                "role": "root-admission-signer",
                "signatureAlgorithm": "Ed25519",
            }
        )
        self.trust_path = self.write_external("trust-root.json", self.trust_root)
        self.selection_path = self.write_external(
            "source-selection.json",
            self.source_selection,
        )
        self.previous_path = self.write_external(
            "previous-receipt.json",
            self.previous_receipt,
        )
        self.git(
            "add",
            *[
                path
                for path in self.paths
                if path != "docs/evidence/bundle.json"
            ],
        )
        self.bundle = self.bundle_document()
        self.write_repository(
            "docs/evidence/bundle.json",
            _canonical_test_json(self.bundle) + b"\n",
        )
        self.git("add", *self.paths)
        self.candidate_tree = self.git("write-tree")
        self.report_path = self.external / "candidate-report.json"

    def git(self, *arguments: str) -> str:
        return subprocess.run(
            ["git", *arguments],
            cwd=self.root,
            check=True,
            capture_output=True,
            text=True,
        ).stdout.strip()

    def write_repository(
        self,
        relative_path: str,
        contents: str | bytes,
        *,
        mode: int = 0o644,
    ) -> Path:
        path = self.root / relative_path
        path.parent.mkdir(parents=True, exist_ok=True)
        value = contents.encode("utf-8") if isinstance(contents, str) else contents
        path.write_bytes(value)
        path.chmod(mode)
        return path

    def write_external(self, name: str, value: object) -> Path:
        path = self.external / name
        path.write_bytes(_canonical_test_json(value) + b"\n")
        path.chmod(0o600)
        return path

    @staticmethod
    def signed(value: dict) -> dict:
        signed = copy.deepcopy(value)
        signed["signature"] = base64.b64encode(
            _test_ed25519_sign(TEST_SEED, _canonical_test_json(value))
        ).decode("ascii")
        return signed

    def staged_blob_sha256(self, path: str) -> str:
        value = subprocess.run(
            ["git", "show", f":{path}"],
            cwd=self.root,
            check=True,
            capture_output=True,
        ).stdout
        return hashlib.sha256(value).hexdigest()

    def bundle_document(self) -> dict:
        runner_bytes = RUNNER.read_bytes() if RUNNER.is_file() else b"missing"
        category_paths = {
            category: f"docs/evidence/{category}.json"
            for category in ("adapter", "create", "extension", "fixture")
        }
        return self.signed(
            {
                "schema": "QinaoWaveBundleV1",
                "repositoryIdentity": REPOSITORY_IDENTITY,
                "wave": "W0",
                "waveSliceID": "w0-gates",
                "sequenceOrdinal": 0,
                "baseCommit": self.base_commit,
                "baseTree": self.base_tree,
                "requiredPredecessorReceiptBlob": hashlib.sha256(
                    _canonical_test_json(self.previous_receipt) + b"\n"
                ).hexdigest(),
                "requiredPredecessorCandidateTree": self.base_tree,
                "pathList": {
                    "path": "docs/evidence/paths.txt",
                    "blobDigest": self.staged_blob_sha256(
                        "docs/evidence/paths.txt"
                    ),
                    "root": hashlib.sha256(self.path_list_bytes).hexdigest(),
                    "count": len(self.paths),
                },
                "ownerLedgerPath": "docs/specs/owner-ledger.json",
                "categories": {
                    category: {
                        "path": path,
                        "blobDigest": self.staged_blob_sha256(path),
                    }
                    for category, path in category_paths.items()
                },
                "approvedDesignBlob": "d" * 64,
                "productionDiffRoot": "f" * 64,
                "evidencePrerequisites": [],
                "externalPrerequisites": [],
                "toolBlobs": {
                    "externalVerifier": "e" * 64,
                    "ownerLedgerChecker": self.staged_blob_sha256(
                        "scripts/check_qinao_owner_ledger.py"
                    ),
                    "repositoryRunner": hashlib.sha256(runner_bytes).hexdigest(),
                },
                "issuedAt": ISSUED_AT,
                "expiresAt": EXPIRES_AT,
                "nonce": "test-only-wave-bundle",
                "signer": TEST_KEY_ID,
                "role": "wave-bundle-reviewer",
                "signatureAlgorithm": "Ed25519",
            }
        )

    def rewrite_bundle(self, mutation) -> None:
        bundle = copy.deepcopy(self.bundle)
        bundle.pop("signature")
        mutation(bundle)
        self.bundle = self.signed(bundle)
        self.write_repository(
            "docs/evidence/bundle.json",
            _canonical_test_json(self.bundle) + b"\n",
        )
        self.git("add", "docs/evidence/bundle.json")
        self.candidate_tree = self.git("write-tree")

    @staticmethod
    def blob_digest(path: Path) -> str:
        return hashlib.sha256(path.read_bytes()).hexdigest()

    def runtime_receipts(self) -> list[dict]:
        slice_ids = [
            "w6.runtime.observation-values",
            "w6.semantic.audit-schema",
            "w6.runtime.audit-envelope-freeze",
            "w6.semantic.coordinator-behavior",
            "w6.runtime.integration-population",
            "w6.runtime.engine-cutover",
        ]
        predecessor_digest = hashlib.sha256(
            _canonical_test_json(self.previous_receipt)
        ).hexdigest()
        receipts: list[dict] = []
        for ordinal, slice_id in enumerate(slice_ids, start=1):
            receipt = self.signed(
                {
                    "schema": "QinaoWaveAdmissionReceiptV1",
                    "repositoryIdentity": REPOSITORY_IDENTITY,
                    "wave": "W6",
                    "waveSliceID": slice_id,
                    "sequenceOrdinal": ordinal,
                    "baseCommit": self.base_commit,
                    "baseTree": self.base_tree,
                    "candidateTree": self.base_tree,
                    "previousReceiptBlobDigest": predecessor_digest,
                    "bundleBlobDigest": f"{ordinal:x}".zfill(64),
                    "productionDiffRoot": f"{ordinal + 8:x}".zfill(64),
                    "pathList": {
                        "root": f"{ordinal + 16:x}".zfill(64),
                        "count": 1,
                    },
                    "categories": {
                        category: {
                            "blobDigest": f"{ordinal + offset:x}".zfill(64),
                            "rowCount": 0,
                            "status": "notApplicable",
                        }
                        for offset, category in enumerate(
                            ("adapter", "create", "extension", "fixture"),
                            start=24,
                        )
                    },
                    "evidencePrerequisites": [],
                    "externalPrerequisites": [],
                    "frozenSchemaDigests": {
                        "test-only/schema": f"{ordinal + 32:x}".zfill(64)
                    },
                    "toolBlobs": {
                        "externalVerifier": "e" * 64,
                        "repositoryRunner": "a" * 64,
                    },
                    "outcome": "admitted",
                    "issuedAt": ISSUED_AT,
                    "expiresAt": EXPIRES_AT,
                    "nonce": f"test-only-runtime-receipt-{ordinal}",
                    "signer": TEST_KEY_ID,
                    "role": "wave-admission-signer",
                    "signatureAlgorithm": "Ed25519",
                }
            )
            receipts.append(receipt)
            predecessor_digest = hashlib.sha256(
                _canonical_test_json(receipt)
            ).hexdigest()
        return receipts

    def configure_runtime_chain(
        self,
        *,
        chain_mutation=None,
        entry_mutation=None,
        required_mutation=None,
    ) -> Path:
        receipts = self.runtime_receipts()
        if entry_mutation is not None:
            entry_mutation(receipts)
        entries = [
            {
                "receipt": receipt,
                "receiptDigest": hashlib.sha256(
                    _canonical_test_json(receipt)
                ).hexdigest(),
            }
            for receipt in receipts
        ]
        chain_unsigned = {
            "schema": "QinaoW6RuntimeReceiptChainV1",
            "repositoryIdentity": REPOSITORY_IDENTITY,
            "entries": entries,
            "expectedHeadTree": receipts[-1]["candidateTree"],
            "outcome": "accepted",
            "issuedAt": ISSUED_AT,
            "expiresAt": EXPIRES_AT,
            "nonce": "test-only-runtime-receipt-chain",
            "signer": TEST_KEY_ID,
            "role": "runtime-chain-signer",
            "signatureAlgorithm": "Ed25519",
        }
        if chain_mutation is not None:
            chain_mutation(chain_unsigned)
        chain = self.signed(chain_unsigned)
        chain_path = self.write_external("runtime-chain.json", chain)
        self.previous_receipt = receipts[-1]
        self.previous_path = self.write_external(
            "previous-receipt.json",
            self.previous_receipt,
        )
        requirement = {
            "name": "runtime-receipt-chain",
            "schema": "QinaoW6RuntimeReceiptChainV1",
            "blobDigest": self.blob_digest(chain_path),
            "requiredOutcome": "accepted",
        }
        if required_mutation is not None:
            required_mutation(requirement)
        def update_bundle(bundle: dict) -> None:
            bundle["wave"] = "W6"
            bundle["waveSliceID"] = "w6.apple.lab"
            bundle["sequenceOrdinal"] = 7
            bundle["requiredPredecessorReceiptBlob"] = self.blob_digest(
                self.previous_path
            )
            bundle["requiredPredecessorCandidateTree"] = self.base_tree
            bundle["externalPrerequisites"] = [requirement]

        self.rewrite_bundle(update_bundle)
        return chain_path

    def candidate_bindings(self) -> dict:
        category_bindings = {}
        for category, binding in self.bundle["categories"].items():
            category_bindings[category] = {
                "blobDigest": binding["blobDigest"],
                "rowCount": 0,
                "status": "notApplicable",
            }
        return {
            "repositoryIdentity": REPOSITORY_IDENTITY,
            "wave": self.bundle["wave"],
            "waveSliceID": self.bundle["waveSliceID"],
            "sequenceOrdinal": self.bundle["sequenceOrdinal"],
            "baseCommit": self.base_commit,
            "baseTree": self.base_tree,
            "candidateTree": self.candidate_tree,
            "bundleBlobDigest": self.staged_blob_sha256(
                "docs/evidence/bundle.json"
            ),
            "sourceSelectionBlobDigest": self.blob_digest(self.selection_path),
            "trustRootBlobDigest": self.blob_digest(self.trust_path),
            "previousReceiptBlobDigest": self.blob_digest(self.previous_path),
            "approvedDesignBlob": self.bundle["approvedDesignBlob"],
            "productionDiffRoot": self.bundle["productionDiffRoot"],
            "pathList": {
                "root": self.bundle["pathList"]["root"],
                "count": self.bundle["pathList"]["count"],
            },
            "categories": category_bindings,
            "evidencePrerequisites": self.bundle["evidencePrerequisites"],
            "externalPrerequisites": self.bundle["externalPrerequisites"],
            "toolBlobs": self.bundle["toolBlobs"],
        }

    def current_receipt(self) -> dict:
        return self.signed(
            {
                "schema": "QinaoWaveAdmissionReceiptV1",
                **self.candidate_bindings(),
                "outcome": "admitted",
                "issuedAt": ISSUED_AT,
                "expiresAt": EXPIRES_AT,
                "nonce": "test-only-current-wave-receipt",
                "signer": TEST_KEY_ID,
                "role": "wave-admission-signer",
                "signatureAlgorithm": "Ed25519",
            }
        )

    def rewrite_runtime_chain(
        self,
        chain_path: Path,
        chain: dict,
        *,
        resign: bool = True,
    ) -> dict:
        updated = copy.deepcopy(chain)
        updated.pop("signature", None)
        updated = self.signed(updated) if resign else {
            **updated,
            "signature": base64.b64encode(b"\0" * 64).decode("ascii"),
        }
        self.write_external(chain_path.name, updated)

        def update_requirement(bundle: dict) -> None:
            bundle["externalPrerequisites"][0]["blobDigest"] = self.blob_digest(
                chain_path
            )

        self.rewrite_bundle(update_requirement)
        return updated

    def command(
        self,
        mode: str = "report",
        *,
        external_prerequisites: list[tuple[str, Path]] | None = None,
        receipt_path: Path | None = None,
    ) -> list[str]:
        command = [
            sys.executable,
            str(RUNNER),
            mode,
            "--root",
            str(self.root),
            "--bundle",
            str(self.root / "docs/evidence/bundle.json"),
            "--source-selection",
            str(self.selection_path),
            "--trust-root",
            str(self.trust_path),
            "--previous-receipt",
            str(self.previous_path),
            "--candidate-tree",
            self.candidate_tree,
        ]
        for name, path in external_prerequisites or []:
            command.extend(["--external-prerequisite", f"{name}={path}"])
        if mode == "verify-receipt":
            command.extend(
                [
                    "--receipt",
                    str(receipt_path or self.external / "current-receipt.json"),
                ]
            )
        else:
            command.extend(["--unsigned-report", str(self.report_path)])
        return command

    def run_runner(
        self,
        command: list[str] | None = None,
        *,
        checker_exit: int = 0,
    ) -> subprocess.CompletedProcess[str]:
        environment = dict(os.environ)
        environment["FAKE_CHECKER_EXIT"] = str(checker_exit)
        return subprocess.run(
            self.command() if command is None else command,
            cwd=self.root,
            env=environment,
            capture_output=True,
            text=True,
            check=False,
        )

    def test_report_writes_only_canonical_unsigned_mode_0600_bytes(self) -> None:
        result = self.run_runner()

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(self.report_path.is_file())
        self.assertEqual(stat.S_IMODE(self.report_path.stat().st_mode), 0o600)
        raw = self.report_path.read_bytes()
        report = json.loads(raw)
        self.assertEqual(raw, _canonical_test_json(report) + b"\n")
        self.assertEqual(report["schema"], "QinaoWaveCandidateReportV1")
        self.assertEqual(report["candidateTree"], self.candidate_tree)
        self.assertEqual(report["admissionStatus"], "unadmitted")
        self.assertNotIn("signature", report)
        self.assertNotIn("admitted", report.get("outcome", ""))

    def test_candidate_tree_must_be_nonempty(self) -> None:
        empty_tree = subprocess.run(
            ["git", "mktree"],
            cwd=self.root,
            input=b"",
            check=True,
            capture_output=True,
        ).stdout.decode("ascii").strip()
        command = self.command()
        command[command.index("--candidate-tree") + 1] = empty_tree

        result = self.run_runner(command)

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("candidate tree is empty", result.stderr)
        self.assertFalse(self.report_path.exists())

    def test_missing_required_category_path_is_rejected(self) -> None:
        self.rewrite_bundle(
            lambda bundle: bundle["categories"]["extension"].__setitem__(
                "path",
                "docs/evidence/missing-extension.json",
            )
        )

        result = self.run_runner()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("missing-extension.json", result.stderr)
        self.assertIn("candidate tree", result.stderr)
        self.assertFalse(self.report_path.exists())

    def test_invalid_bundle_signature_is_rejected(self) -> None:
        self.bundle["signature"] = base64.b64encode(b"\0" * 64).decode("ascii")
        self.write_repository(
            "docs/evidence/bundle.json",
            _canonical_test_json(self.bundle) + b"\n",
        )
        self.git("add", "docs/evidence/bundle.json")
        self.candidate_tree = self.git("write-tree")

        result = self.run_runner()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("bundle signature", result.stderr)
        self.assertFalse(self.report_path.exists())

    def test_subgate_failure_is_propagated_and_report_is_not_written(self) -> None:
        result = self.run_runner(checker_exit=9)

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("owner-ledger subgate failed", result.stderr)
        self.assertIn("exit 9", result.stderr)
        self.assertFalse(self.report_path.exists())

    def test_unknown_mode_and_missing_required_parameter_fail_closed(self) -> None:
        unknown = self.run_runner(self.command(mode="admit-wave"))
        command = self.command()
        option_index = command.index("--candidate-tree")
        del command[option_index : option_index + 2]
        missing = self.run_runner(command)

        self.assertNotEqual(unknown.returncode, 0)
        self.assertIn("invalid choice", unknown.stderr)
        self.assertNotEqual(missing.returncode, 0)
        self.assertIn("--candidate-tree", missing.stderr)
        self.assertIn("required", missing.stderr)

    def test_index_tree_drift_is_rejected(self) -> None:
        command = self.command()
        command[command.index("--candidate-tree") + 1] = self.base_tree

        result = self.run_runner(command)

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("index tree", result.stderr)
        self.assertFalse(self.report_path.exists())

    def test_unstaged_governed_path_drift_is_rejected(self) -> None:
        with (self.root / "docs/evidence/create.json").open(
            "a",
            encoding="utf-8",
        ) as handle:
            handle.write("unstaged\n")

        result = self.run_runner()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("unstaged", result.stderr)
        self.assertIn("docs/evidence/create.json", result.stderr)
        self.assertFalse(self.report_path.exists())

    def test_path_list_and_index_diff_must_be_equal_both_directions(self) -> None:
        self.write_repository(
            "docs/evidence/paths.txt",
            self.path_list_bytes.replace(b"docs/specs/owner-ledger.json\n", b""),
        )
        self.git("add", "docs/evidence/paths.txt")
        self.candidate_tree = self.git("write-tree")

        result = self.run_runner()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("path-list/index-diff mismatch", result.stderr)
        self.assertIn("docs/specs/owner-ledger.json", result.stderr)
        self.assertFalse(self.report_path.exists())

    def test_path_list_equality_captures_rename_source_and_destination(self) -> None:
        self.git("mv", "README.md", "RENAMED.md")
        self.candidate_tree = self.git("write-tree")

        result = self.run_runner()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("path-list/index-diff mismatch", result.stderr)
        self.assertIn("README.md", result.stderr)
        self.assertIn("RENAMED.md", result.stderr)

    def test_path_list_equality_captures_deleted_paths(self) -> None:
        self.git("rm", "-q", "README.md")
        self.candidate_tree = self.git("write-tree")

        result = self.run_runner()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("path-list/index-diff mismatch", result.stderr)
        self.assertIn("README.md", result.stderr)

    def test_path_list_equality_rejects_untracked_candidate_claim(self) -> None:
        self.write_repository(
            "docs/evidence/untracked.json",
            b'{"schema":"TestOnlyUntrackedV1"}\n',
        )
        claimed = "".join(
            f"{path}\n"
            for path in sorted(
                [*self.paths, "docs/evidence/untracked.json"]
            )
        ).encode("utf-8")
        self.write_repository("docs/evidence/paths.txt", claimed)
        self.git("add", "docs/evidence/paths.txt")
        self.candidate_tree = self.git("write-tree")

        result = self.run_runner()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("path-list/index-diff mismatch", result.stderr)
        self.assertIn("docs/evidence/untracked.json", result.stderr)

    def test_verify_receipt_accepts_exact_signed_bindings_without_writing(self) -> None:
        receipt_path = self.write_external(
            "current-receipt.json",
            self.current_receipt(),
        )

        result = self.run_runner(
            self.command(
                mode="verify-receipt",
                receipt_path=receipt_path,
            )
        )

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(self.report_path.exists())
        self.assertEqual(
            receipt_path.read_bytes(),
            _canonical_test_json(self.current_receipt()) + b"\n",
        )

    def test_verify_receipt_rejects_wrong_role_signature_candidate_and_outcome(
        self,
    ) -> None:
        mutations = {
            "role": (
                lambda receipt: receipt.__setitem__(
                    "role",
                    "root-admission-signer",
                ),
                "receipt role",
            ),
            "signature": (
                lambda receipt: receipt.__setitem__(
                    "signature",
                    base64.b64encode(b"\0" * 64).decode("ascii"),
                ),
                "receipt signature",
            ),
            "candidate": (
                lambda receipt: receipt.__setitem__(
                    "candidateTree",
                    self.base_tree,
                ),
                "candidateTree",
            ),
            "outcome": (
                lambda receipt: receipt.__setitem__("outcome", "rejected"),
                "outcome",
            ),
        }
        for label, (mutation, diagnostic) in mutations.items():
            with self.subTest(label=label):
                receipt = self.current_receipt()
                receipt.pop("signature")
                mutation(receipt)
                if label != "signature":
                    receipt = self.signed(receipt)
                receipt_path = self.write_external(
                    f"current-receipt-{label}.json",
                    receipt,
                )

                result = self.run_runner(
                    self.command(
                        mode="verify-receipt",
                        receipt_path=receipt_path,
                    )
                )

                self.assertNotEqual(result.returncode, 0)
                self.assertIn(diagnostic, result.stderr)

    def test_runtime_receipt_chain_is_reverified_and_normalized(self) -> None:
        chain_path = self.configure_runtime_chain()

        result = self.run_runner(
            self.command(
                external_prerequisites=[
                    ("runtime-receipt-chain", chain_path),
                ]
            )
        )

        self.assertEqual(result.returncode, 0, result.stderr)
        report = json.loads(self.report_path.read_bytes())
        self.assertEqual(
            report["externalPrerequisites"],
            self.bundle["externalPrerequisites"],
        )

    def test_external_prerequisite_name_set_is_exact_and_unique(self) -> None:
        chain_path = self.configure_runtime_chain()
        cases = {
            "missing": (
                [],
                "external prerequisite names mismatch",
            ),
            "duplicate": (
                [
                    ("runtime-receipt-chain", chain_path),
                    ("runtime-receipt-chain", chain_path),
                ],
                "duplicate external prerequisite name",
            ),
            "additional": (
                [
                    ("runtime-receipt-chain", chain_path),
                    ("test-only-extra", self.trust_path),
                ],
                "external prerequisite names mismatch",
            ),
        }
        for label, (arguments, diagnostic) in cases.items():
            with self.subTest(label=label):
                result = self.run_runner(
                    self.command(external_prerequisites=arguments)
                )
                self.assertNotEqual(result.returncode, 0)
                self.assertIn(diagnostic, result.stderr)

    def test_external_prerequisite_path_is_external_distinct_regular_0600(
        self,
    ) -> None:
        chain_path = self.configure_runtime_chain()
        chain_bytes = chain_path.read_bytes()
        inside_path = self.write_repository(
            "runtime-chain.json",
            chain_bytes,
            mode=0o600,
        )
        wrong_mode_path = self.external / "runtime-chain-wrong-mode.json"
        wrong_mode_path.write_bytes(chain_bytes)
        wrong_mode_path.chmod(0o644)
        symlink_path = self.external / "runtime-chain-symlink.json"
        symlink_path.symlink_to(chain_path)
        cases = {
            "inside": (inside_path, "outside the repository"),
            "mode": (wrong_mode_path, "mode 0600"),
            "symlink": (symlink_path, "regular file"),
            "aliases-previous": (
                self.previous_path,
                "pairwise distinct",
            ),
        }
        for label, (path, diagnostic) in cases.items():
            with self.subTest(label=label):
                result = self.run_runner(
                    self.command(
                        external_prerequisites=[
                            ("runtime-receipt-chain", path),
                        ]
                    )
                )
                self.assertNotEqual(result.returncode, 0)
                self.assertIn(diagnostic, result.stderr)

    def test_external_prerequisite_digest_is_bound_by_bundle(self) -> None:
        chain_path = self.configure_runtime_chain(
            required_mutation=lambda requirement: requirement.__setitem__(
                "blobDigest",
                "0" * 64,
            )
        )

        result = self.run_runner(
            self.command(
                external_prerequisites=[
                    ("runtime-receipt-chain", chain_path),
                ]
            )
        )

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("external prerequisite blob digest", result.stderr)

    def test_runtime_chain_schema_role_signature_expiry_and_outcome_fail_closed(
        self,
    ) -> None:
        chain_path = self.configure_runtime_chain()
        original = json.loads(chain_path.read_bytes())
        cases = {
            "schema": (
                lambda chain: chain.__setitem__(
                    "schema",
                    "TestOnlyWrongChainV1",
                ),
                True,
                "runtime receipt chain schema",
            ),
            "role": (
                lambda chain: chain.__setitem__(
                    "role",
                    "wave-admission-signer",
                ),
                True,
                "runtime receipt chain role",
            ),
            "signature": (
                lambda _chain: None,
                False,
                "runtime receipt chain signature",
            ),
            "expiry": (
                lambda chain: chain.__setitem__(
                    "expiresAt",
                    "2020-01-01T00:00:00Z",
                ),
                True,
                "runtime receipt chain is expired",
            ),
            "outcome": (
                lambda chain: chain.__setitem__("outcome", "rejected"),
                True,
                "runtime receipt chain outcome",
            ),
        }
        for label, (mutation, resign, diagnostic) in cases.items():
            with self.subTest(label=label):
                chain = copy.deepcopy(original)
                chain.pop("signature")
                mutation(chain)
                self.rewrite_runtime_chain(
                    chain_path,
                    chain,
                    resign=resign,
                )
                result = self.run_runner(
                    self.command(
                        external_prerequisites=[
                            ("runtime-receipt-chain", chain_path),
                        ]
                    )
                )
                self.assertNotEqual(result.returncode, 0)
                self.assertIn(diagnostic, result.stderr)

    def test_runtime_chain_rejects_digest_ordinal_continuity_and_foreign_head(
        self,
    ) -> None:
        chain_path = self.configure_runtime_chain()
        original = json.loads(chain_path.read_bytes())

        def mutate_entry(
            chain: dict,
            index: int,
            field: str,
            value: object,
        ) -> None:
            receipt = copy.deepcopy(chain["entries"][index]["receipt"])
            receipt.pop("signature")
            receipt[field] = value
            receipt = self.signed(receipt)
            chain["entries"][index]["receipt"] = receipt
            chain["entries"][index]["receiptDigest"] = hashlib.sha256(
                _canonical_test_json(receipt)
            ).hexdigest()

        cases = {
            "digest": (
                lambda chain: chain["entries"][2].__setitem__(
                    "receiptDigest",
                    "0" * 64,
                ),
                "receiptDigest",
            ),
            "ordinal": (
                lambda chain: mutate_entry(
                    chain,
                    2,
                    "sequenceOrdinal",
                    99,
                ),
                "sequence ordinal",
            ),
            "continuity": (
                lambda chain: mutate_entry(
                    chain,
                    3,
                    "previousReceiptBlobDigest",
                    "1" * 64,
                ),
                "predecessor receipt continuity",
            ),
            "head": (
                lambda chain: chain.__setitem__(
                    "expectedHeadTree",
                    "2" * 40,
                ),
                "expected head tree",
            ),
            "foreign-six": (
                lambda chain: mutate_entry(
                    chain,
                    5,
                    "nonce",
                    "test-only-foreign-sixth-receipt",
                ),
                "previous receipt",
            ),
        }
        for label, (mutation, diagnostic) in cases.items():
            with self.subTest(label=label):
                chain = copy.deepcopy(original)
                chain.pop("signature")
                mutation(chain)
                self.rewrite_runtime_chain(chain_path, chain)
                result = self.run_runner(
                    self.command(
                        external_prerequisites=[
                            ("runtime-receipt-chain", chain_path),
                        ]
                    )
                )
                self.assertNotEqual(result.returncode, 0)
                self.assertIn(diagnostic, result.stderr)

    def test_report_output_must_be_absent_external_regular_path(self) -> None:
        existing = self.run_runner()
        self.assertEqual(existing.returncode, 0, existing.stderr)
        reused = self.run_runner()
        self.report_path.unlink()
        inside_command = self.command()
        inside_command[inside_command.index("--unsigned-report") + 1] = str(
            self.root / "report.json"
        )
        inside = self.run_runner(inside_command)

        self.assertNotEqual(reused.returncode, 0)
        self.assertIn("already exists", reused.stderr)
        self.assertNotEqual(inside.returncode, 0)
        self.assertIn("outside the repository", inside.stderr)


if __name__ == "__main__":
    unittest.main()
