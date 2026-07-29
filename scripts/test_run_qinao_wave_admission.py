from __future__ import annotations

import argparse
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
from datetime import datetime, timezone
from pathlib import Path
from unittest import mock

from scripts import run_qinao_k4_ios27_platform_spike as k4_runner
from scripts import run_qinao_wave_admission as admission_runner
from scripts.test_check_qinao_owner_ledger import (
    _canonical_test_json,
    _test_complete_trust_keys,
    _test_ed25519_key,
    _test_scoped_trust_key,
    _test_ed25519_sign,
    _test_governance_signature_preimage,
)


PROJECT_ROOT = Path(__file__).resolve().parents[1]
RUNNER = PROJECT_ROOT / "scripts" / "run_qinao_wave_admission.py"
SCOPE_SEEDS = {
    "QinaoRootAdmissionReceiptV1": b"\x10" * 32,
    "QinaoW6RuntimeReceiptChainV1": b"\x20" * 32,
    "QinaoDualSpaceSourceSelectionV1": b"\x30" * 32,
    "QinaoWaveAdmissionReceiptV1": b"\x40" * 32,
    "QinaoWaveBundleV1": b"\x50" * 32,
    "QinaoWaveCategoryEvidenceV1": b"\x60" * 32,
    "QinaoK4IOS27PlatformSpikeV1": b"\x70" * 32,
    "QinaoDesignEdgeAdmissionReceiptV1": b"\x80" * 32,
}
SCOPE_ROLES = {
    "QinaoRootAdmissionReceiptV1": "root-admission-signer",
    "QinaoW6RuntimeReceiptChainV1": "runtime-chain-signer",
    "QinaoDualSpaceSourceSelectionV1": "source-selector",
    "QinaoWaveAdmissionReceiptV1": "wave-admission-signer",
    "QinaoWaveBundleV1": "wave-bundle-reviewer",
    "QinaoWaveCategoryEvidenceV1": "wave-bundle-reviewer",
    "QinaoK4IOS27PlatformSpikeV1": "k4-evidence-signer",
    "QinaoDesignEdgeAdmissionReceiptV1": "design-edge-admission-signer",
}
SCOPE_KEY_IDS = {
    scope: f"test-only-{scope}-key"
    for scope in SCOPE_SEEDS
}
ROLE_KEY_IDS = {
    role: SCOPE_KEY_IDS[scope]
    for scope, role in SCOPE_ROLES.items()
}
REPOSITORY_IDENTITY = "test-only/qinao-wave-runner"
ISSUED_AT = "2026-07-29T00:00:00Z"
EXPIRES_AT = "2030-01-01T00:00:00Z"
VERIFICATION_TIME = datetime(2026, 7, 30, tzinfo=timezone.utc)


FAKE_CHECKER = """#!/usr/bin/env python3
import json
import os
import sys

argument_capture = os.environ.get("FAKE_CHECKER_ARGUMENT_CAPTURE")
if argument_capture:
    with open(argument_capture, "w", encoding="utf-8") as stream:
        json.dump(sys.argv[1:], stream)
print("test-only owner checker invoked")
raise SystemExit(int(os.environ.get("FAKE_CHECKER_EXIT", "0")))
"""


class WaveAdmissionRunnerTests(unittest.TestCase):
    def setUp(self) -> None:
        environment_patch = mock.patch.dict(
            os.environ,
            {"QINAO_PINNED_REPOSITORY_RUNNER": str(RUNNER)},
            clear=False,
        )
        environment_patch.start()
        self.addCleanup(environment_patch.stop)
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
            "docs/superpowers/specs/qinao-owner-ledger-v1.json",
            "scripts/check_qinao_owner_ledger.py",
            "scripts/run_qinao_wave_admission.py",
        ]
        self.approved_design_bytes = b"test-only wave fixture\n"
        self.approved_design_sha256 = hashlib.sha256(
            self.approved_design_bytes
        ).hexdigest()
        for category in ("adapter", "create", "extension", "fixture"):
            self.write_repository(
                f"docs/evidence/{category}.json",
                _canonical_test_json(
                    self.signed(
                        {
                            "schema": "QinaoWaveCategoryEvidenceV1",
                            "repositoryIdentity": REPOSITORY_IDENTITY,
                            "wave": "W0",
                            "waveSliceID": "w0.gates",
                            "sequenceOrdinal": 1,
                            "category": category,
                            "status": "notApplicable",
                            "baseTree": self.base_tree,
                            "approvedDesignBlob": self.approved_design_sha256,
                            "productionDiffRoot": "f" * 64,
                            "reviewedRows": [],
                            "reviewedRowsRoot": hashlib.sha256(
                                _canonical_test_json([])
                            ).hexdigest(),
                            "anchors": [],
                            "reason": "test-only category has no production row",
                            "issuedAt": ISSUED_AT,
                            "expiresAt": EXPIRES_AT,
                            "nonce": f"test-only-{category}-category",
                            "signer": SCOPE_KEY_IDS[
                                "QinaoWaveCategoryEvidenceV1"
                            ],
                            "role": "wave-bundle-reviewer",
                            "signatureAlgorithm": "Ed25519",
                        }
                    )
                )
                + b"\n",
            )
        self.write_repository(
            "docs/superpowers/specs/qinao-owner-ledger-v1.json",
            b"{}\n",
        )
        self.write_repository(
            "scripts/check_qinao_owner_ledger.py",
            FAKE_CHECKER,
            mode=0o644,
        )
        self.write_repository(
            "scripts/run_qinao_wave_admission.py",
            RUNNER.read_bytes(),
            mode=0o644,
        )
        self.path_list_bytes = (
            "".join(f"{path}\n" for path in self.paths).encode("utf-8")
        )
        self.write_repository(
            "docs/evidence/paths.txt",
            self.path_list_bytes,
        )
        self.trust_root = {
            "schema": "QinaoAdmissionTrustRootV1",
            "repositoryIdentity": REPOSITORY_IDENTITY,
            "issuedAt": ISSUED_AT,
            "expiresAt": EXPIRES_AT,
            "keys": _test_complete_trust_keys(
                [
                    _test_scoped_trust_key(
                        seed,
                        SCOPE_KEY_IDS[scope],
                        SCOPE_ROLES[scope],
                        scope,
                    )
                    for scope, seed in SCOPE_SEEDS.items()
                ]
            ),
            "revokedNonces": [],
        }
        approved_design_blob = self.git("rev-parse", "HEAD:README.md")
        self.source_selection = self.signed(
            {
                "schemaVersion": 1,
                "repositoryIdentity": REPOSITORY_IDENTITY,
                "selectedHEAD": self.base_commit,
                "selectedTree": self.base_tree,
                "approvedDesign": {
                    "path": "README.md",
                    "commit": self.base_commit,
                    "tree": self.base_tree,
                    "blob": approved_design_blob,
                    "byteLength": len(self.approved_design_bytes),
                    "sha256": self.approved_design_sha256,
                },
                "candidateComparisons": [
                    {
                        "candidateID": "selected-test-worktree",
                        "comparisonBaseHEAD": self.base_commit,
                        "head": self.base_commit,
                        "tree": self.base_tree,
                        "selected": True,
                        "committedRows": [],
                        "stagedRows": [],
                        "unstagedRows": [],
                        "untrackedRows": [],
                    }
                ],
                "reviewerPrincipal": SCOPE_KEY_IDS[
                    "QinaoDualSpaceSourceSelectionV1"
                ],
                "reviewerRole": "source-selector",
                "issuedAt": ISSUED_AT,
                "expiresAt": EXPIRES_AT,
                "nonce": "test-only-source-selection",
                "signatureAlgorithm": "Ed25519",
            }
        )
        source_key = next(
            row
            for row in self.trust_root["keys"]
            if row["schemaScope"] == "QinaoDualSpaceSourceSelectionV1"
        )
        self.previous_receipt = self.signed(
            {
                "schema": "QinaoRootAdmissionReceiptV1",
                "repositoryIdentity": REPOSITORY_IDENTITY,
                "sourceSelectionBlobDigest": hashlib.sha256(
                    _canonical_test_json(self.source_selection) + b"\n"
                ).hexdigest(),
                "trustRootBlobDigest": hashlib.sha256(
                    _canonical_test_json(self.trust_root) + b"\n"
                ).hexdigest(),
                "toolBlobs": {
                    "externalVerifier": "e" * 64,
                    "signingProvider": "1" * 64,
                },
                "verifiedSelector": {
                    "principalID": source_key["principalID"],
                    "keyID": source_key["keyID"],
                    "role": source_key["role"],
                    "schemaScope": source_key["schemaScope"],
                    "publicKeyFingerprintSHA256": source_key[
                        "publicKeyFingerprintSHA256"
                    ],
                },
                "verifiedHEAD": self.base_commit,
                "verifiedTree": self.base_tree,
                "verifiedAt": ISSUED_AT,
                "outcome": "accepted",
                "issuedAt": ISSUED_AT,
                "expiresAt": EXPIRES_AT,
                "nonce": "test-only-root-receipt",
                "signer": SCOPE_KEY_IDS["QinaoRootAdmissionReceiptV1"],
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
        scope = (
            "QinaoDualSpaceSourceSelectionV1"
            if "schemaVersion" in signed
            else signed.get("schema")
        )
        if scope not in SCOPE_SEEDS:
            raise AssertionError(
                f"test fixture has no independent key for scope {scope!r}"
            )
        signed["signature"] = base64.b64encode(
            _test_ed25519_sign(
                SCOPE_SEEDS[scope],
                _test_governance_signature_preimage(value),
            )
        ).decode("ascii")
        return signed

    def make_tree(self, rows: list[tuple[str, str, str]]) -> str:
        tree_input = "".join(
            f"{mode} blob {blob}\t{path}\n"
            for mode, blob, path in rows
        )
        return subprocess.run(
            ["git", "mktree"],
            cwd=self.root,
            input=tree_input,
            check=True,
            capture_output=True,
            text=True,
        ).stdout.strip()

    def write_git_blob(self, contents: str) -> str:
        return subprocess.run(
            ["git", "hash-object", "-w", "--stdin"],
            cwd=self.root,
            input=contents,
            check=True,
            capture_output=True,
            text=True,
        ).stdout.strip()

    def source_selection_for_tree(self, commit: str, tree: str) -> dict:
        source_selection = copy.deepcopy(self.source_selection)
        source_selection.pop("signature")
        source_selection["selectedHEAD"] = commit
        source_selection["selectedTree"] = tree
        selected = source_selection["candidateComparisons"][0]
        selected["comparisonBaseHEAD"] = commit
        selected["head"] = commit
        selected["tree"] = tree
        return self.signed(source_selection)

    def root_receipt_for_source(
        self,
        source_selection: dict,
        trust_root: dict | None = None,
        *,
        source_key_id: str | None = None,
    ) -> dict:
        effective_trust_root = trust_root or self.trust_root
        effective_source_key_id = (
            source_key_id
            or SCOPE_KEY_IDS["QinaoDualSpaceSourceSelectionV1"]
        )
        source_key = next(
            row
            for row in effective_trust_root["keys"]
            if row["keyID"] == effective_source_key_id
        )
        root_receipt = copy.deepcopy(self.previous_receipt)
        root_receipt.pop("signature")
        root_receipt.update(
            {
                "sourceSelectionBlobDigest": hashlib.sha256(
                    _canonical_test_json(source_selection) + b"\n"
                ).hexdigest(),
                "trustRootBlobDigest": hashlib.sha256(
                    _canonical_test_json(effective_trust_root) + b"\n"
                ).hexdigest(),
                "verifiedSelector": {
                    "principalID": source_key["principalID"],
                    "keyID": source_key["keyID"],
                    "role": source_key["role"],
                    "schemaScope": source_key["schemaScope"],
                    "publicKeyFingerprintSHA256": source_key[
                        "publicKeyFingerprintSHA256"
                    ],
                },
                "verifiedHEAD": source_selection["selectedHEAD"],
                "verifiedTree": source_selection["selectedTree"],
            }
        )
        return self.signed(root_receipt)

    def design_edge_receipt(
        self,
        source_selection: dict,
        root_receipt: dict,
        candidate_tree: str,
    ) -> dict:
        return self.signed(
            {
                "schema": "QinaoDesignEdgeAdmissionReceiptV1",
                "repositoryIdentity": REPOSITORY_IDENTITY,
                "rootReceiptBlobDigest": hashlib.sha256(
                    _canonical_test_json(root_receipt) + b"\n"
                ).hexdigest(),
                "baseCommit": source_selection["selectedHEAD"],
                "baseTree": source_selection["selectedTree"],
                "candidateTree": candidate_tree,
                "approvedDesign": copy.deepcopy(
                    source_selection["approvedDesign"]
                ),
                "toolBlobs": {
                    "externalVerifier": "e" * 64,
                    "signingProvider": "1" * 64,
                },
                "verifiedAt": ISSUED_AT,
                "outcome": "admitted",
                "issuedAt": ISSUED_AT,
                "expiresAt": EXPIRES_AT,
                "nonce": "test-only-design-edge-receipt",
                "signer": SCOPE_KEY_IDS[
                    "QinaoDesignEdgeAdmissionReceiptV1"
                ],
                "role": "design-edge-admission-signer",
                "signatureAlgorithm": "Ed25519",
            }
        )

    def trust_root_with_rotated_source_selector(self) -> tuple[dict, dict]:
        trust_root = copy.deepcopy(self.trust_root)
        source_key = next(
            row
            for row in trust_root["keys"]
            if row["keyID"]
            == SCOPE_KEY_IDS["QinaoDualSpaceSourceSelectionV1"]
        )
        source_key["notAfter"] = "2027-01-01T00:00:00Z"
        rotated_key = _test_scoped_trust_key(
            b"\x81" * 32,
            "test-only-rotated-source-selector-key",
            "source-selector",
            "QinaoDualSpaceSourceSelectionV1",
            principal_id=source_key["principalID"],
            issued_at="2027-01-01T00:00:00Z",
            expires_at=EXPIRES_AT,
        )
        trust_root["keys"].append(rotated_key)
        trust_root["keys"] = sorted(
            trust_root["keys"],
            key=_canonical_test_json,
        )
        return trust_root, rotated_key

    def validate_w0_1_predecessor(
        self,
        receipt: dict,
        source_selection: dict,
        base_tree: str,
        *,
        trust_root: dict | None = None,
        verification_time: datetime = VERIFICATION_TIME,
    ) -> None:
        effective_trust_root = trust_root or self.trust_root
        admission_runner.validate_previous_receipt(
            receipt,
            effective_trust_root,
            source_selection,
            base_tree,
            root=self.root,
            source_raw=_canonical_test_json(source_selection) + b"\n",
            trust_raw=_canonical_test_json(effective_trust_root) + b"\n",
            current_wave="W0",
            current_slice="w0.gates",
            current_ordinal=1,
            verification_time=verification_time,
        )

    def staged_blob_sha256(self, path: str) -> str:
        value = subprocess.run(
            ["git", "show", f":{path}"],
            cwd=self.root,
            check=True,
            capture_output=True,
        ).stdout
        return hashlib.sha256(value).hexdigest()

    def bundle_document(self) -> dict:
        category_paths = {
            category: f"docs/evidence/{category}.json"
            for category in ("adapter", "create", "extension", "fixture")
        }
        return self.signed(
            {
                "schema": "QinaoWaveBundleV1",
                "repositoryIdentity": REPOSITORY_IDENTITY,
                "wave": "W0",
                "waveSliceID": "w0.gates",
                "sequenceOrdinal": 1,
                "baseCommit": self.base_commit,
                "baseTree": self.base_tree,
                "requiredPredecessorReceiptBlob": hashlib.sha256(
                    _canonical_test_json(self.previous_receipt) + b"\n"
                ).hexdigest(),
                "requiredPredecessorCandidateTree": self.base_tree,
                "priorAdmissionReceipts": [],
                "pathList": {
                    "path": "docs/evidence/paths.txt",
                    "blobDigest": self.staged_blob_sha256(
                        "docs/evidence/paths.txt"
                    ),
                    "root": hashlib.sha256(self.path_list_bytes).hexdigest(),
                    "count": len(self.paths),
                },
                "ownerLedger": {
                    "path": (
                        "docs/superpowers/specs/qinao-owner-ledger-v1.json"
                    ),
                    "blobDigest": self.staged_blob_sha256(
                        "docs/superpowers/specs/qinao-owner-ledger-v1.json"
                    ),
                },
                "categories": {
                    category: {
                        "path": path,
                        "blobDigest": self.staged_blob_sha256(path),
                    }
                    for category, path in category_paths.items()
                },
                "approvedDesignBlob": self.approved_design_sha256,
                "productionDiffRoot": "f" * 64,
                "evidencePrerequisites": [],
                "externalPrerequisites": [],
                "frozenSchemaDigests": [],
                "toolBlobs": {
                    "bundleReviewSigningProvider": "2" * 64,
                    "externalVerifier": "e" * 64,
                    "ownerLedgerChecker": {
                        "path": "scripts/check_qinao_owner_ledger.py",
                        "blobDigest": self.staged_blob_sha256(
                            "scripts/check_qinao_owner_ledger.py"
                        ),
                    },
                    "repositoryRunner": {
                        "path": "scripts/run_qinao_wave_admission.py",
                        "blobDigest": self.staged_blob_sha256(
                            "scripts/run_qinao_wave_admission.py"
                        ),
                    },
                    "waveAdmissionSigningProvider": "3" * 64,
                },
                "issuedAt": ISSUED_AT,
                "expiresAt": EXPIRES_AT,
                "nonce": "test-only-wave-bundle",
                "signer": SCOPE_KEY_IDS["QinaoWaveBundleV1"],
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

    @staticmethod
    def frozen_schema_row(name: str) -> dict:
        schema = {
            "$schema": "https://json-schema.org/draft/2020-12/schema",
            "$id": f"qinao://schemas/{name}/1.0.0",
            "title": name,
            "type": "object",
            "properties": {
                "schema": {"const": f"{name}V1"},
            },
            "required": ["schema"],
            "additionalProperties": False,
        }
        return {
            "name": name,
            "version": "1.0.0",
            "jsonSchema": schema,
            "sha256": hashlib.sha256(_canonical_test_json(schema)).hexdigest(),
        }

    def scheduled_frozen_schemas(self, ordinal: int) -> list[dict]:
        if ordinal == 1:
            return []
        first = self.frozen_schema_row("BASRuntimeAuditProjectionsBundle")
        if ordinal == 2:
            return [first]
        return [
            first,
            self.frozen_schema_row("BASSameRunAuditOutcome"),
            self.frozen_schema_row("BASTurnRuntimeAuditEnvelope"),
        ]

    def uniform_wave_receipt(
        self,
        *,
        wave: str,
        wave_slice_id: str,
        sequence_ordinal: int,
        previous_digest: str,
        frozen_schemas: list[dict],
    ) -> dict:
        evidence: list[dict] = []
        if wave == "W5":
            evidence = [
                {
                    "name": "k4-ios27-platform-spike",
                    "path": (
                        "docs/superpowers/evidence/"
                        "qinao-k4-ios27-platform-spike.json"
                    ),
                    "schema": "QinaoK4IOS27PlatformSpikeV1",
                    "blobDigest": "5" * 64,
                    "requiredStatus": "supportedExactProfile",
                    "verifiedStatus": "supportedExactProfile",
                    "requiredProfileDigest": "6" * 64,
                    "verifiedProfileDigest": "6" * 64,
                }
            ]
        return self.signed(
            {
                "schema": "QinaoWaveAdmissionReceiptV1",
                "repositoryIdentity": REPOSITORY_IDENTITY,
                "wave": wave,
                "waveSliceID": wave_slice_id,
                "sequenceOrdinal": sequence_ordinal,
                "baseCommit": self.base_commit,
                "baseTree": self.base_tree,
                "candidateTree": self.base_tree,
                "bundleBlobDigest": f"{sequence_ordinal + 1:x}".zfill(64),
                "sourceSelectionBlobDigest": self.blob_digest(
                    self.selection_path
                ),
                "trustRootBlobDigest": self.blob_digest(self.trust_path),
                "previousReceiptBlobDigest": previous_digest,
                "approvedDesignBlob": self.approved_design_sha256,
                "productionDiffRoot": f"{sequence_ordinal + 16:x}".zfill(64),
                "pathList": {"root": "7" * 64, "count": 1},
                "ownerLedger": copy.deepcopy(self.bundle["ownerLedger"]),
                "categories": {
                    category: {
                        "blobDigest": f"{sequence_ordinal + offset:x}".zfill(64),
                        "reviewedRowsRoot": hashlib.sha256(
                            _canonical_test_json([])
                        ).hexdigest(),
                        "rowCount": 0,
                        "status": "notApplicable",
                    }
                    for offset, category in enumerate(
                        ("adapter", "create", "extension", "fixture"),
                        start=24,
                    )
                },
                "evidencePrerequisites": evidence,
                "externalPrerequisites": [],
                "frozenSchemaDigests": copy.deepcopy(frozen_schemas),
                "toolBlobs": copy.deepcopy(self.bundle["toolBlobs"]),
                "verifiedAt": ISSUED_AT,
                "outcome": "admitted",
                "issuedAt": ISSUED_AT,
                "expiresAt": EXPIRES_AT,
                "nonce": (
                    f"test-only-{wave.lower()}-{sequence_ordinal}-receipt"
                ),
                "signer": SCOPE_KEY_IDS["QinaoWaveAdmissionReceiptV1"],
                "role": "wave-admission-signer",
                "signatureAlgorithm": "Ed25519",
            }
        )

    def configure_w6_6_prefix(
        self,
    ) -> tuple[list[tuple[str, Path]], Path]:
        entry = self.uniform_wave_receipt(
            wave="W5",
            wave_slice_id="w5.inspection-publication-apple",
            sequence_ordinal=1,
            previous_digest="9" * 64,
            frozen_schemas=[],
        )
        entry_path = self.write_external("runtime-entry-predecessor.json", entry)
        predecessor_raw = entry_path.read_bytes()
        prior_receipts: list[dict] = []
        prior_paths: list[tuple[str, Path]] = []
        for ordinal, slice_id in enumerate(
            (
                "w6.runtime.observation-values",
                "w6.semantic.audit-schema",
                "w6.runtime.audit-envelope-freeze",
                "w6.semantic.coordinator-behavior",
                "w6.runtime.integration-population",
            ),
            start=1,
        ):
            receipt = self.uniform_wave_receipt(
                wave="W6",
                wave_slice_id=slice_id,
                sequence_ordinal=ordinal,
                previous_digest=hashlib.sha256(predecessor_raw).hexdigest(),
                frozen_schemas=self.scheduled_frozen_schemas(ordinal),
            )
            path = self.write_external(f"prior-receipt-{ordinal:02d}.json", receipt)
            prior_receipts.append(receipt)
            prior_paths.append((slice_id, path))
            predecessor_raw = path.read_bytes()

        self.previous_receipt = prior_receipts[-1]
        self.previous_path = self.write_external(
            "previous-receipt-w6-05-copy.json",
            self.previous_receipt,
        )
        for category in ("adapter", "create", "extension", "fixture"):
            path = f"docs/evidence/{category}.json"
            document = json.loads((self.root / path).read_bytes())
            document.pop("signature")
            document.update(
                {
                    "wave": "W6",
                    "waveSliceID": "w6.runtime.engine-cutover",
                    "sequenceOrdinal": 6,
                    "nonce": f"test-only-w6-6-{category}-category",
                }
            )
            self.write_repository(
                path,
                _canonical_test_json(self.signed(document)) + b"\n",
            )
            self.git("add", path)

        def update_bundle(bundle: dict) -> None:
            bundle.update(
                {
                    "wave": "W6",
                    "waveSliceID": "w6.runtime.engine-cutover",
                    "sequenceOrdinal": 6,
                    "requiredPredecessorReceiptBlob": self.blob_digest(
                        self.previous_path
                    ),
                    "priorAdmissionReceipts": [
                        {
                            "waveSliceID": slice_id,
                            "sequenceOrdinal": ordinal,
                            "receiptBlobDigest": self.blob_digest(path),
                        }
                        for ordinal, (slice_id, path) in enumerate(
                            prior_paths,
                            start=1,
                        )
                    ],
                    "frozenSchemaDigests": self.scheduled_frozen_schemas(6),
                    "nonce": "test-only-w6-6-wave-bundle",
                }
            )
            for category, binding in bundle["categories"].items():
                binding["blobDigest"] = self.staged_blob_sha256(
                    f"docs/evidence/{category}.json"
                )

        self.rewrite_bundle(update_bundle)
        return prior_paths, entry_path

    def runtime_receipts(self) -> tuple[list[dict], Path]:
        entry = self.uniform_wave_receipt(
            wave="W5",
            wave_slice_id="w5.inspection-publication-apple",
            sequence_ordinal=1,
            previous_digest="9" * 64,
            frozen_schemas=[],
        )
        entry_path = self.write_external("runtime-entry-predecessor.json", entry)
        predecessor_raw = entry_path.read_bytes()
        receipts: list[dict] = []
        for ordinal, slice_id in enumerate(
            (
                "w6.runtime.observation-values",
                "w6.semantic.audit-schema",
                "w6.runtime.audit-envelope-freeze",
                "w6.semantic.coordinator-behavior",
                "w6.runtime.integration-population",
                "w6.runtime.engine-cutover",
            ),
            start=1,
        ):
            receipt = self.uniform_wave_receipt(
                wave="W6",
                wave_slice_id=slice_id,
                sequence_ordinal=ordinal,
                previous_digest=hashlib.sha256(predecessor_raw).hexdigest(),
                frozen_schemas=self.scheduled_frozen_schemas(ordinal),
            )
            receipts.append(receipt)
            predecessor_raw = _canonical_test_json(receipt) + b"\n"
        return receipts, entry_path

    def configure_runtime_chain(
        self,
        *,
        chain_mutation=None,
        entry_mutation=None,
        required_mutation=None,
    ) -> Path:
        receipts, entry_path = self.runtime_receipts()
        self.runtime_entry_path = entry_path
        if entry_mutation is not None:
            entry_mutation(receipts)
        entries = [
            {
                "waveSliceID": receipt["waveSliceID"],
                "sequenceOrdinal": receipt["sequenceOrdinal"],
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
            "entryPredecessorReceiptBlobDigest": self.blob_digest(entry_path),
            "entryPredecessorCandidateTree": self.base_tree,
            "entries": entries,
            "expectedHeadTree": receipts[-1]["candidateTree"],
            "toolBlobs": {
                "externalVerifier": "e" * 64,
                "runtimeChainSigningProvider": "8" * 64,
            },
            "verifiedAt": ISSUED_AT,
            "outcome": "accepted",
            "issuedAt": ISSUED_AT,
            "expiresAt": EXPIRES_AT,
            "nonce": "test-only-runtime-receipt-chain",
            "signer": ROLE_KEY_IDS["runtime-chain-signer"],
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

        for category in ("adapter", "create", "extension", "fixture"):
            category_path = f"docs/evidence/{category}.json"
            document = json.loads((self.root / category_path).read_bytes())
            document.pop("signature")
            document.update(
                {
                    "wave": "W6",
                    "waveSliceID": "w6.apple-lab",
                    "sequenceOrdinal": 7,
                    "nonce": f"test-only-w6-7-{category}-category",
                }
            )
            self.write_repository(
                category_path,
                _canonical_test_json(self.signed(document)) + b"\n",
            )
            self.git("add", category_path)

        def update_bundle(bundle: dict) -> None:
            bundle["wave"] = "W6"
            bundle["waveSliceID"] = "w6.apple-lab"
            bundle["sequenceOrdinal"] = 7
            bundle["requiredPredecessorReceiptBlob"] = self.blob_digest(
                self.previous_path
            )
            bundle["requiredPredecessorCandidateTree"] = self.base_tree
            bundle["priorAdmissionReceipts"] = []
            bundle["externalPrerequisites"] = [requirement]
            bundle["frozenSchemaDigests"] = self.scheduled_frozen_schemas(7)
            bundle["nonce"] = "test-only-w6-7-wave-bundle"
            for category, binding in bundle["categories"].items():
                binding["blobDigest"] = self.staged_blob_sha256(
                    f"docs/evidence/{category}.json"
                )

        self.rewrite_bundle(update_bundle)
        return chain_path

    def configure_w6_8_runtime_chain(self) -> Path:
        chain_path = self.configure_runtime_chain()
        w6_7_receipt = self.current_receipt()
        self.previous_receipt = w6_7_receipt
        self.previous_path = self.write_external(
            "previous-receipt-w6-7.json",
            w6_7_receipt,
        )

        self.git("commit", "-qm", "test-only admitted W6.7 candidate")
        self.base_commit = self.git("rev-parse", "HEAD")
        self.base_tree = self.git("rev-parse", "HEAD^{tree}")
        self.paths = sorted(
            [
                "docs/evidence/adapter.json",
                "docs/evidence/bundle.json",
                "docs/evidence/create.json",
                "docs/evidence/extension.json",
                "docs/evidence/fixture.json",
                "docs/evidence/paths.txt",
            ]
        )

        for category in ("adapter", "create", "extension", "fixture"):
            category_path = f"docs/evidence/{category}.json"
            document = json.loads((self.root / category_path).read_bytes())
            document.pop("signature")
            document.update(
                {
                    "waveSliceID": "w6.certification",
                    "sequenceOrdinal": 8,
                    "baseTree": self.base_tree,
                    "nonce": f"test-only-w6-8-{category}-category",
                }
            )
            self.write_repository(
                category_path,
                _canonical_test_json(self.signed(document)) + b"\n",
            )
            self.git("add", category_path)

        self.path_list_bytes = (
            "".join(f"{path}\n" for path in self.paths).encode("utf-8")
        )
        self.write_repository("docs/evidence/paths.txt", self.path_list_bytes)
        self.git("add", "docs/evidence/paths.txt")

        def update_bundle(bundle: dict) -> None:
            bundle.update(
                {
                    "waveSliceID": "w6.certification",
                    "sequenceOrdinal": 8,
                    "baseCommit": self.base_commit,
                    "baseTree": self.base_tree,
                    "requiredPredecessorReceiptBlob": self.blob_digest(
                        self.previous_path
                    ),
                    "requiredPredecessorCandidateTree": self.base_tree,
                    "priorAdmissionReceipts": [],
                    "frozenSchemaDigests": self.scheduled_frozen_schemas(8),
                    "nonce": "test-only-w6-8-wave-bundle",
                }
            )
            bundle["pathList"] = {
                "path": "docs/evidence/paths.txt",
                "blobDigest": self.staged_blob_sha256(
                    "docs/evidence/paths.txt"
                ),
                "root": hashlib.sha256(self.path_list_bytes).hexdigest(),
                "count": len(self.paths),
            }
            for category, binding in bundle["categories"].items():
                binding["blobDigest"] = self.staged_blob_sha256(
                    f"docs/evidence/{category}.json"
                )

        self.rewrite_bundle(update_bundle)
        return chain_path

    def candidate_bindings(self) -> dict:
        category_bindings = {}
        for category, binding in self.bundle["categories"].items():
            category_document = json.loads(
                (self.root / binding["path"]).read_bytes()
            )
            category_bindings[category] = {
                "blobDigest": binding["blobDigest"],
                "reviewedRowsRoot": category_document["reviewedRowsRoot"],
                "rowCount": 0,
                "status": "notApplicable",
            }
        external_prerequisites = [
            {
                **row,
                "verifiedOutcome": row["requiredOutcome"],
            }
            for row in self.bundle["externalPrerequisites"]
        ]
        evidence_prerequisites = [
            {
                **row,
                "verifiedStatus": row["requiredStatus"],
                "verifiedProfileDigest": row["requiredProfileDigest"],
            }
            for row in self.bundle["evidencePrerequisites"]
        ]
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
            "ownerLedger": self.bundle["ownerLedger"],
            "categories": category_bindings,
            "evidencePrerequisites": evidence_prerequisites,
            "externalPrerequisites": external_prerequisites,
            "frozenSchemaDigests": self.bundle["frozenSchemaDigests"],
            "toolBlobs": self.bundle["toolBlobs"],
        }

    def current_receipt(self) -> dict:
        receipt_nonce = (
            f"test-only-{self.bundle['wave'].lower()}-"
            f"{self.bundle['waveSliceID']}-"
            f"{self.bundle['sequenceOrdinal']}-receipt"
        )
        return self.signed(
            {
                "schema": "QinaoWaveAdmissionReceiptV1",
                **self.candidate_bindings(),
                "verifiedAt": ISSUED_AT,
                "outcome": "admitted",
                "issuedAt": ISSUED_AT,
                "expiresAt": EXPIRES_AT,
                "nonce": receipt_nonce,
                "signer": SCOPE_KEY_IDS["QinaoWaveAdmissionReceiptV1"],
                "role": "wave-admission-signer",
                "signatureAlgorithm": "Ed25519",
            }
        )

    def commit_current_candidate_as_predecessor(self, name: str) -> dict:
        receipt = self.current_receipt()
        self.git("commit", "-qm", f"test-only admitted {name}")
        self.base_commit = self.git("rev-parse", "HEAD")
        self.base_tree = self.git("rev-parse", "HEAD^{tree}")
        self.assertEqual(receipt["candidateTree"], self.base_tree)
        self.previous_receipt = receipt
        self.previous_path = self.write_external(
            f"previous-{name}-receipt.json",
            receipt,
        )
        return receipt

    def configure_ordinary_wave_candidate(
        self,
        *,
        wave: str,
        wave_slice_id: str,
        sequence_ordinal: int,
        marker_name: str,
    ) -> None:
        marker_path = f"docs/evidence/{marker_name}.txt"
        self.paths = sorted(
            [
                "docs/evidence/adapter.json",
                "docs/evidence/bundle.json",
                "docs/evidence/create.json",
                "docs/evidence/extension.json",
                "docs/evidence/fixture.json",
                "docs/evidence/paths.txt",
                marker_path,
                "docs/superpowers/specs/qinao-owner-ledger-v1.json",
                "scripts/check_qinao_owner_ledger.py",
            ]
        )
        self.write_repository(
            marker_path,
            f"test-only distinct {wave_slice_id} candidate\n",
        )
        for category in ("adapter", "create", "extension", "fixture"):
            category_path = f"docs/evidence/{category}.json"
            document = json.loads((self.root / category_path).read_bytes())
            document.pop("signature")
            document.update(
                {
                    "wave": wave,
                    "waveSliceID": wave_slice_id,
                    "sequenceOrdinal": sequence_ordinal,
                    "baseTree": self.base_tree,
                    "nonce": (
                        f"test-only-{wave_slice_id}-{category}-category"
                    ),
                }
            )
            self.write_repository(
                category_path,
                _canonical_test_json(self.signed(document)) + b"\n",
            )
        self.write_repository(
            "docs/superpowers/specs/qinao-owner-ledger-v1.json",
            _canonical_test_json(
                {"wave": wave, "waveSliceID": wave_slice_id}
            )
            + b"\n",
        )
        self.write_repository(
            "scripts/check_qinao_owner_ledger.py",
            FAKE_CHECKER + f"\n# test-only {wave_slice_id} checker binding\n",
            mode=0o644,
        )
        self.path_list_bytes = (
            "".join(f"{path}\n" for path in self.paths).encode("utf-8")
        )
        self.write_repository("docs/evidence/paths.txt", self.path_list_bytes)
        self.git(
            "add",
            *[
                path
                for path in self.paths
                if path != "docs/evidence/bundle.json"
            ],
        )
        unsigned_bundle = self.bundle_document()
        unsigned_bundle.pop("signature")
        unsigned_bundle.update(
            {
                "wave": wave,
                "waveSliceID": wave_slice_id,
                "sequenceOrdinal": sequence_ordinal,
                "nonce": f"test-only-{wave_slice_id}-wave-bundle",
            }
        )
        self.bundle = self.signed(unsigned_bundle)
        self.write_repository(
            "docs/evidence/bundle.json",
            _canonical_test_json(self.bundle) + b"\n",
        )
        self.git("add", "docs/evidence/bundle.json")
        self.candidate_tree = self.git("write-tree")

    def k4_evidence_document(self, *, nonce: str) -> dict:
        framework_apis = [
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
        ]
        target = {
            "bundleIdentifierDigest": "1" * 64,
            "extensionPoint": "com.example.test-only.security-extension",
            "processModel": "outOfProcessExtension",
        }
        required_entitlements = [
            "com.example.test-only.enhanced-security"
        ]
        sqlite = {
            "fileProtection": "passed",
            "open": "passed",
            "wal": "passed",
        }
        transport = {"feasibility": "passed", "kind": "XPC"}
        lifecycle = [
            {"event": event, "observation": "passed"}
            for event in (
                "launch",
                "interruption",
                "termination",
                "reconnect",
                "keyAccess",
            )
        ]
        supported_profile_digest = k4_runner.supported_profile_digest(
            framework_apis=framework_apis,
            target=target,
            required_entitlements=required_entitlements,
            sqlite=sqlite,
            transport=transport,
            lifecycle=lifecycle,
        )
        return self.signed(
            {
                "schema": "QinaoK4IOS27PlatformSpikeV1",
                "repositoryIdentity": REPOSITORY_IDENTITY,
                "approvedDesignBlob": self.approved_design_sha256,
                "candidateCommit": self.base_commit,
                "candidateTree": self.base_tree,
                "deviceProfileDigest": "3" * 64,
                "deviceIdentityDigest": "4" * 64,
                "probeDeviceIdentityDigest": "4" * 64,
                "platform": "iOS",
                "environment": "physicalDevice",
                "osVersion": "27.0",
                "osBuild": "24A5355p",
                "xcodeVersion": "27.0",
                "xcodeBuild": "27A5194q",
                "sdkCanonicalName": "iphoneos27.0",
                "sdkVersion": "27.0",
                "sdkBuild": "24A5355p",
                "sdkSettingsDigest": "5" * 64,
                "sdkSystemVersionDigest": "6" * 64,
                "frameworkAPIs": framework_apis,
                "frameworkAPIAvailability": [
                    {
                        "framework": "TestSecurity",
                        "api": "TestSecurityCapability",
                        "declarationPresence": "present",
                        "declarationDigest": "7" * 64,
                        "processSupportInference": "notInferred",
                        "entitlementSupportInference": "notInferred",
                    }
                ],
                "target": target,
                "signingIdentityClass": "Apple Development",
                "entitlementInventory": required_entitlements,
                "requiredEntitlements": required_entitlements,
                "sqlite": sqlite,
                "transport": transport,
                "lifecycle": lifecycle,
                "probeMatrixDigest": "8" * 64,
                "resultBundleDigest": "9" * 64,
                "supportedProfileDigest": supported_profile_digest,
                "status": "supportedExactProfile",
                "issuedAt": ISSUED_AT,
                "expiresAt": EXPIRES_AT,
                "nonce": nonce,
                "signer": SCOPE_KEY_IDS[
                    "QinaoK4IOS27PlatformSpikeV1"
                ],
                "role": "k4-evidence-signer",
                "signatureAlgorithm": "Ed25519",
            }
        )

    def configure_w5_candidate_with_k4_evidence(
        self,
        *,
        evidence_nonce: str,
    ) -> None:
        predecessor = self.uniform_wave_receipt(
            wave="W4",
            wave_slice_id="w4.model-execution",
            sequence_ordinal=1,
            previous_digest="9" * 64,
            frozen_schemas=[],
        )
        self.previous_receipt = predecessor
        self.previous_path = self.write_external(
            "w4-predecessor.json",
            predecessor,
        )
        evidence_path = (
            "docs/superpowers/evidence/"
            "qinao-k4-ios27-platform-spike.json"
        )
        evidence = self.k4_evidence_document(nonce=evidence_nonce)
        self.write_repository(
            evidence_path,
            _canonical_test_json(evidence) + b"\n",
        )
        for category in ("adapter", "create", "extension", "fixture"):
            category_path = f"docs/evidence/{category}.json"
            document = json.loads((self.root / category_path).read_bytes())
            document.pop("signature")
            document.update(
                {
                    "wave": "W5",
                    "waveSliceID": "w5.inspection-publication-apple",
                    "sequenceOrdinal": 1,
                    "baseTree": self.base_tree,
                    "nonce": f"test-only-w5-{category}-category",
                }
            )
            self.write_repository(
                category_path,
                _canonical_test_json(self.signed(document)) + b"\n",
            )
        self.paths = sorted([*self.paths, evidence_path])
        self.path_list_bytes = (
            "".join(f"{path}\n" for path in self.paths).encode("utf-8")
        )
        self.write_repository("docs/evidence/paths.txt", self.path_list_bytes)
        self.git(
            "add",
            *[
                path
                for path in self.paths
                if path != "docs/evidence/bundle.json"
            ],
        )
        unsigned_bundle = self.bundle_document()
        unsigned_bundle.pop("signature")
        unsigned_bundle.update(
            {
                "wave": "W5",
                "waveSliceID": "w5.inspection-publication-apple",
                "sequenceOrdinal": 1,
                "evidencePrerequisites": [
                    {
                        "name": "k4-ios27-platform-spike",
                        "path": evidence_path,
                        "schema": "QinaoK4IOS27PlatformSpikeV1",
                        "blobDigest": self.staged_blob_sha256(
                            evidence_path
                        ),
                        "requiredStatus": "supportedExactProfile",
                        "requiredProfileDigest": evidence[
                            "supportedProfileDigest"
                        ],
                    }
                ],
                "nonce": "test-only-w5-wave-bundle",
            }
        )
        self.bundle = self.signed(unsigned_bundle)
        self.write_repository(
            "docs/evidence/bundle.json",
            _canonical_test_json(self.bundle) + b"\n",
        )
        self.git("add", "docs/evidence/bundle.json")
        self.candidate_tree = self.git("write-tree")

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
        prior_admission_receipts: list[tuple[str, Path]] | None = None,
        runtime_entry_predecessor: Path | None = None,
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
        for wave_slice_id, path in prior_admission_receipts or []:
            command.extend(
                [
                    "--prior-admission-receipt",
                    f"{wave_slice_id}={path}",
                ]
            )
        effective_runtime_entry = runtime_entry_predecessor
        if effective_runtime_entry is None:
            effective_runtime_entry = getattr(self, "runtime_entry_path", None)
        if effective_runtime_entry is not None:
            command.extend(
                [
                    "--runtime-entry-predecessor",
                    str(effective_runtime_entry),
                ]
            )
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

    def derive_arguments(
        self,
        *,
        external_prerequisites: list[tuple[str, Path]] | None = None,
        prior_admission_receipts: list[tuple[str, Path]] | None = None,
        runtime_entry_predecessor: Path | None = None,
    ) -> argparse.Namespace:
        return argparse.Namespace(
            root=self.root,
            bundle=self.root / "docs/evidence/bundle.json",
            source_selection=self.selection_path,
            trust_root=self.trust_path,
            previous_receipt=self.previous_path,
            candidate_tree=self.candidate_tree,
            external_prerequisite=[
                f"{name}={path}"
                for name, path in external_prerequisites or []
            ],
            prior_admission_receipt=[
                f"{wave_slice_id}={path}"
                for wave_slice_id, path in prior_admission_receipts or []
            ],
            runtime_entry_predecessor=runtime_entry_predecessor,
        )

    def run_runner(
        self,
        command: list[str] | None = None,
        *,
        checker_exit: int = 0,
        pinned_checker: Path | None = None,
    ) -> subprocess.CompletedProcess[str]:
        environment = dict(os.environ)
        environment["FAKE_CHECKER_EXIT"] = str(checker_exit)
        if pinned_checker is not None:
            environment["QINAO_PINNED_OWNER_LEDGER_CHECKER"] = str(
                pinned_checker
            )
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
        self.assertEqual(
            set(report),
            {
                "schema",
                "repositoryIdentity",
                "wave",
                "waveSliceID",
                "sequenceOrdinal",
                "baseCommit",
                "baseTree",
                "candidateTree",
                "bundleBlobDigest",
                "sourceSelectionBlobDigest",
                "trustRootBlobDigest",
                "previousReceiptBlobDigest",
                "approvedDesignBlob",
                "productionDiffRoot",
                "priorAdmissionReceipts",
                "runtimeEntryPredecessors",
                "pathList",
                "ownerLedger",
                "categories",
                "evidencePrerequisites",
                "externalPrerequisites",
                "frozenSchemaDigests",
                "toolBlobs",
                "admissionStatus",
            },
        )
        self.assertEqual(report["schema"], "QinaoWaveCandidateReportV1")
        self.assertEqual(report["candidateTree"], self.candidate_tree)
        self.assertEqual(report["admissionStatus"], "unadmitted")
        self.assertEqual(report["priorAdmissionReceipts"], [])
        self.assertEqual(report["runtimeEntryPredecessors"], [])
        self.assertNotIn("signature", report)
        self.assertNotIn("admitted", report.get("outcome", ""))

    def test_frozen_schema_rows_bind_closed_inline_draft_2020_12_schema(
        self,
    ) -> None:
        schema = {
            "$schema": "https://json-schema.org/draft/2020-12/schema",
            "$id": (
                "qinao://schemas/"
                "BASRuntimeAuditProjectionsBundle/1.0.0"
            ),
            "title": "BASRuntimeAuditProjectionsBundle",
            "type": "object",
            "properties": {
                "schema": {
                    "const": "BASRuntimeAuditProjectionsBundleV1",
                },
            },
            "required": ["schema"],
            "additionalProperties": False,
        }
        row = {
            "name": "BASRuntimeAuditProjectionsBundle",
            "version": "1.0.0",
            "jsonSchema": schema,
            "sha256": hashlib.sha256(_canonical_test_json(schema)).hexdigest(),
        }

        admission_runner.validate_frozen_schema_digests(
            [row],
            wave="W6",
            sequence_ordinal=2,
        )

        cases = {
            "wrong digest": lambda value: value.__setitem__("sha256", "0" * 64),
            "open object": lambda value: value["jsonSchema"].pop(
                "additionalProperties"
            ),
            "remote ref": lambda value: value["jsonSchema"].__setitem__(
                "$ref",
                "https://attacker.invalid/schema.json",
            ),
        }
        for label, mutation in cases.items():
            with self.subTest(label=label):
                altered = copy.deepcopy(row)
                mutation(altered)
                with self.assertRaises(admission_runner.GateError):
                    admission_runner.validate_frozen_schema_digests(
                        [altered],
                        wave="W6",
                        sequence_ordinal=2,
                    )

    def test_w6_6_report_reverifies_prior_prefix_and_entry_predecessor(
        self,
    ) -> None:
        prior_receipts, entry_predecessor = self.configure_w6_6_prefix()

        result = self.run_runner(
            self.command(
                prior_admission_receipts=prior_receipts,
                runtime_entry_predecessor=entry_predecessor,
            )
        )

        self.assertEqual(result.returncode, 0, result.stderr)
        report = json.loads(self.report_path.read_bytes())
        self.assertEqual(
            [row["sequenceOrdinal"] for row in report["priorAdmissionReceipts"]],
            [1, 2, 3, 4, 5],
        )
        self.assertEqual(
            report["runtimeEntryPredecessors"],
            [
                {
                    "schema": "QinaoWaveAdmissionReceiptV1",
                    "blobDigest": self.blob_digest(entry_predecessor),
                    "wave": "W5",
                    "waveSliceID": "w5.inspection-publication-apple",
                    "sequenceOrdinal": 1,
                    "candidateTree": self.base_tree,
                    "outcome": "admitted",
                }
            ],
        )

    def test_w6_6_requires_complete_prefix_and_rejects_foreign_entry(
        self,
    ) -> None:
        prior_receipts, entry_predecessor = self.configure_w6_6_prefix()
        missing = self.run_runner(
            self.command(
                prior_admission_receipts=prior_receipts[:-1],
                runtime_entry_predecessor=entry_predecessor,
            )
        )
        self.assertNotEqual(missing.returncode, 0)
        self.assertIn("exactly the five", missing.stderr)

        foreign = copy.deepcopy(
            json.loads(entry_predecessor.read_text(encoding="utf-8"))
        )
        foreign.pop("signature")
        foreign["candidateTree"] = "a" * 40
        foreign = self.signed(foreign)
        self.write_external(entry_predecessor.name, foreign)
        result = self.run_runner(
            self.command(
                prior_admission_receipts=prior_receipts,
                runtime_entry_predecessor=entry_predecessor,
            )
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("continuity", result.stderr)

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
            result = self.run_runner()

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(self.report_path.is_file())

    def test_git_timeout_and_spawn_errors_fail_closed(self) -> None:
        for error in (
            subprocess.TimeoutExpired(["git", "rev-parse"], 30),
            OSError("test-only spawn failure"),
        ):
            with self.subTest(error=type(error).__name__):
                with mock.patch.object(
                    admission_runner.subprocess,
                    "run",
                    side_effect=error,
                ):
                    with self.assertRaisesRegex(
                        admission_runner.GateError,
                        "unavailable or timed out",
                    ):
                        admission_runner.run_git(
                            self.root,
                            ["rev-parse", "HEAD"],
                        )

    def test_root_to_w0_to_w1_advances_from_previous_receipt_not_selection(
        self,
    ) -> None:
        root_tree = self.source_selection["selectedTree"]
        self.commit_current_candidate_as_predecessor("w0-1")
        self.assertNotEqual(self.base_tree, root_tree)
        self.configure_ordinary_wave_candidate(
            wave="W0",
            wave_slice_id="w0.controlled",
            sequence_ordinal=2,
            marker_name="w0-controlled-change",
        )
        self.commit_current_candidate_as_predecessor("w0-2")
        self.configure_ordinary_wave_candidate(
            wave="W1",
            wave_slice_id="w1.dual-space",
            sequence_ordinal=1,
            marker_name="w1-change",
        )

        result = self.run_runner()

        self.assertEqual(result.returncode, 0, result.stderr)
        report = json.loads(self.report_path.read_bytes())
        self.assertEqual(report["baseTree"], self.base_tree)
        self.assertEqual(report["candidateTree"], self.candidate_tree)
        self.assertEqual(report["wave"], "W1")

    def test_runner_forwards_exact_bundle_schedule_tuple_to_checker(
        self,
    ) -> None:
        self.commit_current_candidate_as_predecessor("w0-1-checker-spy")
        self.configure_ordinary_wave_candidate(
            wave="W0",
            wave_slice_id="w0.controlled",
            sequence_ordinal=2,
            marker_name="w0-controlled-checker-spy",
        )
        capture = self.external / "checker-arguments.json"

        with mock.patch.dict(
            os.environ,
            {"FAKE_CHECKER_ARGUMENT_CAPTURE": str(capture)},
            clear=False,
        ):
            result = self.run_runner()

        self.assertEqual(result.returncode, 0, result.stderr)
        arguments = json.loads(capture.read_text(encoding="utf-8"))
        observed = tuple(
            arguments[arguments.index(option) + 1]
            for option in (
                "--wave",
                "--wave-slice-id",
                "--sequence-ordinal",
            )
        )
        self.assertEqual(observed, ("W0", "w0.controlled", "2"))

    def test_signed_skipped_schedule_predecessor_is_rejected(self) -> None:
        self.commit_current_candidate_as_predecessor("w0-1-skipped")
        self.configure_ordinary_wave_candidate(
            wave="W1",
            wave_slice_id="w1.dual-space",
            sequence_ordinal=1,
            marker_name="w1-skipped-predecessor",
        )

        result = self.run_runner()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("exact preceding schedule row", result.stderr)
        self.assertFalse(self.report_path.exists())

    def test_signed_reordered_schedule_predecessor_is_rejected(self) -> None:
        reordered = self.uniform_wave_receipt(
            wave="W1",
            wave_slice_id="w1.dual-space",
            sequence_ordinal=1,
            previous_digest="9" * 64,
            frozen_schemas=[],
        )
        self.previous_receipt = reordered
        self.previous_path = self.write_external(
            "reordered-w1-predecessor.json",
            reordered,
        )
        self.rewrite_bundle(
            lambda bundle: bundle.__setitem__(
                "requiredPredecessorReceiptBlob",
                self.blob_digest(self.previous_path),
            )
        )

        result = self.run_runner()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("root/design predecessor", result.stderr)
        self.assertFalse(self.report_path.exists())

    def test_w0_1_root_cannot_skip_required_design_edge(self) -> None:
        empty_tree = self.make_tree([])
        selected_commit = self.git(
            "commit-tree",
            empty_tree,
            "-m",
            "test-only selected tree without approved design",
        )
        source_selection = self.source_selection_for_tree(
            selected_commit,
            empty_tree,
        )
        root_receipt = self.root_receipt_for_source(source_selection)

        with self.assertRaisesRegex(
            admission_runner.GateError,
            "design-edge",
        ):
            self.validate_w0_1_predecessor(
                root_receipt,
                source_selection,
                empty_tree,
            )

    def test_w0_1_design_edge_candidate_may_only_place_approved_design(
        self,
    ) -> None:
        empty_tree = self.make_tree([])
        selected_commit = self.git(
            "commit-tree",
            empty_tree,
            "-m",
            "test-only selected tree requiring design edge",
        )
        source_selection = self.source_selection_for_tree(
            selected_commit,
            empty_tree,
        )
        root_receipt = self.root_receipt_for_source(source_selection)
        approved_blob = source_selection["approvedDesign"]["blob"]
        extra_blob = self.write_git_blob("test-only unauthorized extra\n")
        candidate_tree = self.make_tree(
            [
                ("100644", extra_blob, "EXTRA.txt"),
                ("100644", approved_blob, "README.md"),
            ]
        )
        design_receipt = self.design_edge_receipt(
            source_selection,
            root_receipt,
            candidate_tree,
        )

        with self.assertRaisesRegex(
            admission_runner.GateError,
            "only.*approved design|exact.*design",
        ):
            self.validate_w0_1_predecessor(
                design_receipt,
                source_selection,
                candidate_tree,
            )

    def test_w0_1_design_edge_tool_digests_must_be_hex(self) -> None:
        empty_tree = self.make_tree([])
        selected_commit = self.git(
            "commit-tree",
            empty_tree,
            "-m",
            "test-only selected tree requiring design edge",
        )
        source_selection = self.source_selection_for_tree(
            selected_commit,
            empty_tree,
        )
        root_receipt = self.root_receipt_for_source(source_selection)
        candidate_tree = self.make_tree(
            [
                (
                    "100644",
                    source_selection["approvedDesign"]["blob"],
                    "README.md",
                )
            ]
        )
        design_receipt = self.design_edge_receipt(
            source_selection,
            root_receipt,
            candidate_tree,
        )
        design_receipt.pop("signature")
        design_receipt["toolBlobs"]["externalVerifier"] = "not-hex"
        design_receipt = self.signed(design_receipt)

        with self.assertRaisesRegex(
            admission_runner.GateError,
            "externalVerifier.*lowercase hexadecimal",
        ):
            self.validate_w0_1_predecessor(
                design_receipt,
                source_selection,
                candidate_tree,
            )

    def test_w0_1_root_or_exact_design_edge_is_selected_from_tree_state(
        self,
    ) -> None:
        self.validate_w0_1_predecessor(
            self.previous_receipt,
            self.source_selection,
            self.base_tree,
        )

        empty_tree = self.make_tree([])
        selected_commit = self.git(
            "commit-tree",
            empty_tree,
            "-m",
            "test-only selected tree requiring exact design edge",
        )
        source_selection = self.source_selection_for_tree(
            selected_commit,
            empty_tree,
        )
        root_receipt = self.root_receipt_for_source(source_selection)
        exact_candidate_tree = self.make_tree(
            [
                (
                    "100644",
                    source_selection["approvedDesign"]["blob"],
                    "README.md",
                )
            ]
        )
        exact_design_receipt = self.design_edge_receipt(
            source_selection,
            root_receipt,
            exact_candidate_tree,
        )

        self.validate_w0_1_predecessor(
            exact_design_receipt,
            source_selection,
            exact_candidate_tree,
        )

        redundant_design_receipt = self.design_edge_receipt(
            self.source_selection,
            self.previous_receipt,
            self.base_tree,
        )
        with self.assertRaisesRegex(
            admission_runner.GateError,
            "already present",
        ):
            self.validate_w0_1_predecessor(
                redundant_design_receipt,
                self.source_selection,
                self.base_tree,
            )

    def test_w0_1_design_edge_rejects_wrong_approved_mode_or_blob(
        self,
    ) -> None:
        empty_tree = self.make_tree([])
        selected_commit = self.git(
            "commit-tree",
            empty_tree,
            "-m",
            "test-only selected tree requiring exact design edge",
        )
        source_selection = self.source_selection_for_tree(
            selected_commit,
            empty_tree,
        )
        root_receipt = self.root_receipt_for_source(source_selection)
        wrong_blob = self.write_git_blob("test-only wrong design blob\n")
        cases = {
            "wrong mode": self.make_tree(
                [
                    (
                        "100755",
                        source_selection["approvedDesign"]["blob"],
                        "README.md",
                    )
                ]
            ),
            "wrong blob": self.make_tree(
                [("100644", wrong_blob, "README.md")]
            ),
        }
        for label, candidate_tree in cases.items():
            with self.subTest(label=label):
                design_receipt = self.design_edge_receipt(
                    source_selection,
                    root_receipt,
                    candidate_tree,
                )
                with self.assertRaisesRegex(
                    admission_runner.GateError,
                    "exact approved design path/blob/mode",
                ):
                    self.validate_w0_1_predecessor(
                        design_receipt,
                        source_selection,
                        candidate_tree,
                    )

    def test_root_selector_resolves_nonoverlapping_rotated_key_at_source_issue(
        self,
    ) -> None:
        trust_root, _rotated_key = (
            self.trust_root_with_rotated_source_selector()
        )
        root_receipt = self.root_receipt_for_source(
            self.source_selection,
            trust_root,
        )

        self.validate_w0_1_predecessor(
            root_receipt,
            self.source_selection,
            self.base_tree,
            trust_root=trust_root,
        )

    def test_root_selector_binds_second_rotation_window_and_rejects_wrong_key(
        self,
    ) -> None:
        trust_root, rotated_key = (
            self.trust_root_with_rotated_source_selector()
        )
        second_window_issued_at = "2027-07-01T00:00:00Z"
        source_selection = copy.deepcopy(self.source_selection)
        source_selection.pop("signature")
        source_selection.update(
            {
                "issuedAt": second_window_issued_at,
                "nonce": "test-only-second-window-source-selection",
            }
        )
        source_selection["signature"] = base64.b64encode(
            _test_ed25519_sign(
                b"\x81" * 32,
                _test_governance_signature_preimage(source_selection),
            )
        ).decode("ascii")
        second_window_verification_time = datetime(
            2027,
            7,
            2,
            tzinfo=timezone.utc,
        )
        self.assertEqual(
            admission_runner.validate_source_selection(
                source_selection,
                trust_root,
                root=self.root,
                verification_time=second_window_verification_time,
            ),
            [],
        )
        root_receipt = self.root_receipt_for_source(
            source_selection,
            trust_root,
            source_key_id=rotated_key["keyID"],
        )
        root_receipt.pop("signature")
        root_receipt.update(
            {
                "verifiedAt": second_window_issued_at,
                "issuedAt": second_window_issued_at,
                "nonce": "test-only-second-window-root-receipt",
            }
        )
        root_receipt = self.signed(root_receipt)

        self.validate_w0_1_predecessor(
            root_receipt,
            source_selection,
            self.base_tree,
            trust_root=trust_root,
            verification_time=second_window_verification_time,
        )

        wrong_selector = copy.deepcopy(root_receipt)
        wrong_selector.pop("signature")
        original_key = next(
            row
            for row in trust_root["keys"]
            if row["keyID"]
            == SCOPE_KEY_IDS["QinaoDualSpaceSourceSelectionV1"]
        )
        wrong_selector["verifiedSelector"] = {
            "principalID": original_key["principalID"],
            "keyID": original_key["keyID"],
            "role": original_key["role"],
            "schemaScope": original_key["schemaScope"],
            "publicKeyFingerprintSHA256": original_key[
                "publicKeyFingerprintSHA256"
            ],
        }
        wrong_selector = self.signed(wrong_selector)
        with self.assertRaisesRegex(
            admission_runner.GateError,
            "verifiedSelector mismatch",
        ):
            self.validate_w0_1_predecessor(
                wrong_selector,
                source_selection,
                self.base_tree,
                trust_root=trust_root,
                verification_time=second_window_verification_time,
            )

    def test_category_and_bundle_nonce_collision_is_rejected(self) -> None:
        category_path = self.root / "docs/evidence/create.json"
        category = json.loads(category_path.read_bytes())
        category.pop("signature")
        category["nonce"] = self.bundle["nonce"]
        self.write_repository(
            "docs/evidence/create.json",
            _canonical_test_json(self.signed(category)) + b"\n",
        )
        self.git("add", "docs/evidence/create.json")
        self.rewrite_bundle(
            lambda bundle: bundle["categories"]["create"].__setitem__(
                "blobDigest",
                self.staged_blob_sha256("docs/evidence/create.json"),
            )
        )

        result = self.run_runner()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("signed document nonce collision", result.stderr)
        self.assertFalse(self.report_path.exists())

    def test_previous_and_bundle_nonce_collision_is_rejected(self) -> None:
        self.rewrite_bundle(
            lambda bundle: bundle.__setitem__(
                "nonce",
                self.previous_receipt["nonce"],
            )
        )

        result = self.run_runner()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("signed document nonce collision", result.stderr)
        self.assertFalse(self.report_path.exists())

    def test_runtime_chain_wrapper_and_embedded_nonce_collision_is_rejected(
        self,
    ) -> None:
        chain_path = self.configure_runtime_chain(
            chain_mutation=lambda chain: chain.__setitem__(
                "nonce",
                "test-only-w6-1-receipt",
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
        self.assertIn("signed document nonce collision", result.stderr)
        self.assertFalse(self.report_path.exists())

    def test_w5_k4_and_current_receipt_nonce_collision_is_rejected(
        self,
    ) -> None:
        receipt_nonce = (
            "test-only-w5-w5.inspection-publication-apple-1-receipt"
        )
        self.configure_w5_candidate_with_k4_evidence(
            evidence_nonce=receipt_nonce,
        )
        receipt_path = self.write_external(
            "w5-current-receipt.json",
            self.current_receipt(),
        )

        result = self.run_runner(
            self.command(
                mode="verify-receipt",
                receipt_path=receipt_path,
            )
        )

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("signed document nonce collision", result.stderr)

    def test_w5_k4_and_current_receipt_distinct_nonces_are_accepted(
        self,
    ) -> None:
        self.configure_w5_candidate_with_k4_evidence(
            evidence_nonce="test-only-distinct-k4-evidence",
        )
        receipt_path = self.write_external(
            "w5-current-receipt.json",
            self.current_receipt(),
        )

        result = self.run_runner(
            self.command(
                mode="verify-receipt",
                receipt_path=receipt_path,
            )
        )

        self.assertEqual(result.returncode, 0, result.stderr)

    def test_w6_6_previous_and_prior_05_identical_alias_is_registered(
        self,
    ) -> None:
        prior_receipts, entry_predecessor = self.configure_w6_6_prefix()
        captured: list[tuple[str, dict]] = []
        real_validator = admission_runner.validate_operation_nonce_collisions

        def capture_then_validate(documents):
            captured.extend(documents)
            real_validator(documents)

        with mock.patch.object(
            admission_runner,
            "validate_operation_nonce_collisions",
            side_effect=capture_then_validate,
        ):
            admission_runner.derive_report(
                self.derive_arguments(
                    prior_admission_receipts=prior_receipts,
                    runtime_entry_predecessor=entry_predecessor,
                ),
                verification_time=VERIFICATION_TIME,
            )

        by_label = dict(captured)
        self.assertEqual(
            by_label["previous receipt"],
            by_label[
                "prior admission receipt "
                "w6.runtime.integration-population"
            ],
        )

    def test_w6_7_previous_and_embedded_06_identical_alias_is_registered(
        self,
    ) -> None:
        chain_path = self.configure_runtime_chain()
        captured: list[tuple[str, dict]] = []
        real_validator = admission_runner.validate_operation_nonce_collisions

        def capture_then_validate(documents):
            captured.extend(documents)
            real_validator(documents)

        with mock.patch.object(
            admission_runner,
            "validate_operation_nonce_collisions",
            side_effect=capture_then_validate,
        ):
            admission_runner.derive_report(
                self.derive_arguments(
                    external_prerequisites=[
                        ("runtime-receipt-chain", chain_path)
                    ],
                    runtime_entry_predecessor=self.runtime_entry_path,
                ),
                verification_time=VERIFICATION_TIME,
            )

        by_label = dict(captured)
        self.assertEqual(
            by_label["previous receipt"],
            by_label["runtime receipt chain entry 6 receipt"],
        )

    def test_current_receipt_verified_at_after_issued_at_is_rejected(
        self,
    ) -> None:
        receipt = self.current_receipt()
        receipt.pop("signature")
        receipt["verifiedAt"] = "2026-07-29T00:00:01Z"
        receipt = self.signed(receipt)
        receipt_path = self.write_external(
            "receipt-verified-after-issued.json",
            receipt,
        )

        result = self.run_runner(
            self.command(
                mode="verify-receipt",
                receipt_path=receipt_path,
            )
        )

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("verifiedAt", result.stderr)

    def test_current_receipt_verified_at_before_input_issuance_is_rejected(
        self,
    ) -> None:
        self.rewrite_bundle(
            lambda bundle: bundle.__setitem__(
                "issuedAt",
                "2026-07-29T00:00:01Z",
            )
        )
        receipt_path = self.write_external(
            "receipt-verified-before-input.json",
            self.current_receipt(),
        )

        result = self.run_runner(
            self.command(
                mode="verify-receipt",
                receipt_path=receipt_path,
            )
        )

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("input time window", result.stderr)

    def test_historical_root_verified_at_after_issued_at_is_rejected(
        self,
    ) -> None:
        previous = copy.deepcopy(self.previous_receipt)
        previous.pop("signature")
        previous["verifiedAt"] = "2026-07-29T00:00:01Z"
        self.previous_receipt = self.signed(previous)
        self.write_external(self.previous_path.name, self.previous_receipt)
        self.rewrite_bundle(
            lambda bundle: bundle.__setitem__(
                "requiredPredecessorReceiptBlob",
                self.blob_digest(self.previous_path),
            )
        )

        result = self.run_runner()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("verifiedAt", result.stderr)

    def test_current_receipt_malformed_verified_at_is_rejected(self) -> None:
        receipt = self.current_receipt()
        receipt.pop("signature")
        receipt["verifiedAt"] = "not-a-timestamp"
        receipt = self.signed(receipt)
        receipt_path = self.write_external(
            "receipt-malformed-verified-at.json",
            receipt,
        )

        result = self.run_runner(
            self.command(
                mode="verify-receipt",
                receipt_path=receipt_path,
            )
        )

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("verifiedAt", result.stderr)

    def test_receipt_verified_at_equal_input_expiry_is_rejected(self) -> None:
        receipt = self.current_receipt()
        input_document = {
            "issuedAt": "2026-07-28T00:00:00Z",
            "expiresAt": receipt["verifiedAt"],
        }

        with self.assertRaisesRegex(
            admission_runner.GateError,
            "input time window",
        ):
            admission_runner.validate_receipt_time_relationships(
                receipt,
                label="receipt",
                trust_root=self.trust_root,
                inputs=[("boundary input", input_document)],
            )

    def test_current_receipt_before_category_issuance_is_rejected(
        self,
    ) -> None:
        category_path = "docs/evidence/create.json"
        category = json.loads((self.root / category_path).read_bytes())
        category.pop("signature")
        category["issuedAt"] = "2026-07-29T00:00:01Z"
        self.write_repository(
            category_path,
            _canonical_test_json(self.signed(category)) + b"\n",
        )
        self.git("add", category_path)
        self.rewrite_bundle(
            lambda bundle: bundle["categories"]["create"].__setitem__(
                "blobDigest",
                self.staged_blob_sha256(category_path),
            )
        )
        receipt_path = self.write_external(
            "receipt-before-category.json",
            self.current_receipt(),
        )

        result = self.run_runner(
            self.command(
                mode="verify-receipt",
                receipt_path=receipt_path,
            )
        )

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("create category input time window", result.stderr)

    def test_current_receipt_before_k4_issuance_is_rejected(self) -> None:
        self.configure_w5_candidate_with_k4_evidence(
            evidence_nonce="test-only-time-k4-evidence",
        )
        evidence_path = (
            "docs/superpowers/evidence/"
            "qinao-k4-ios27-platform-spike.json"
        )
        evidence = json.loads((self.root / evidence_path).read_bytes())
        evidence.pop("signature")
        evidence["issuedAt"] = "2026-07-29T00:00:01Z"
        self.write_repository(
            evidence_path,
            _canonical_test_json(self.signed(evidence)) + b"\n",
        )
        self.git("add", evidence_path)
        self.rewrite_bundle(
            lambda bundle: bundle["evidencePrerequisites"][0].__setitem__(
                "blobDigest",
                self.staged_blob_sha256(evidence_path),
            )
        )
        receipt_path = self.write_external(
            "receipt-before-k4.json",
            self.current_receipt(),
        )

        result = self.run_runner(
            self.command(
                mode="verify-receipt",
                receipt_path=receipt_path,
            )
        )

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("K4 evidence prerequisite input time window", result.stderr)

    def test_runtime_chain_verified_at_before_embedded_issuance_is_rejected(
        self,
    ) -> None:
        def move_embedded_issuance_after_chain(chain: dict) -> None:
            previous_stored: bytes | None = None
            for index, entry in enumerate(chain["entries"]):
                receipt = entry["receipt"]
                receipt.pop("signature")
                receipt["verifiedAt"] = "2026-07-29T00:00:01Z"
                receipt["issuedAt"] = "2026-07-29T00:00:01Z"
                if index > 0:
                    assert previous_stored is not None
                    receipt["previousReceiptBlobDigest"] = hashlib.sha256(
                        previous_stored
                    ).hexdigest()
                resigned = self.signed(receipt)
                receipt.clear()
                receipt.update(resigned)
                canonical = _canonical_test_json(receipt)
                entry["receiptDigest"] = hashlib.sha256(canonical).hexdigest()
                previous_stored = canonical + b"\n"

        chain_path = self.configure_runtime_chain(
            chain_mutation=move_embedded_issuance_after_chain,
        )

        result = self.run_runner(
            self.command(
                external_prerequisites=[
                    ("runtime-receipt-chain", chain_path),
                ]
            )
        )

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("embedded receipt 1 input time window", result.stderr)

    def test_wave_main_captures_one_verification_time_per_mode(self) -> None:
        class CountingDateTime(datetime):
            calls = 0

            @classmethod
            def now(cls, tz=None):
                cls.calls += 1
                return VERIFICATION_TIME

        report_command = self.command()
        with mock.patch.object(
            admission_runner,
            "datetime",
            CountingDateTime,
        ), mock.patch.object(
            sys,
            "argv",
            [str(RUNNER), *report_command[2:]],
        ):
            self.assertEqual(admission_runner.main(), 0)
        self.assertEqual(CountingDateTime.calls, 1)

        receipt_path = self.write_external(
            "single-v-current-receipt.json",
            self.current_receipt(),
        )
        verify_command = self.command(
            mode="verify-receipt",
            receipt_path=receipt_path,
        )
        CountingDateTime.calls = 0
        with mock.patch.object(
            admission_runner,
            "datetime",
            CountingDateTime,
        ), mock.patch.object(
            sys,
            "argv",
            [str(RUNNER), *verify_command[2:]],
        ):
            self.assertEqual(admission_runner.main(), 0)
        self.assertEqual(CountingDateTime.calls, 1)

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

    def test_tree_object_cannot_masquerade_as_bundle_base_commit(self) -> None:
        self.rewrite_bundle(
            lambda bundle: bundle.__setitem__(
                "baseCommit",
                self.base_tree,
            )
        )

        result = self.run_runner()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("baseCommit", result.stderr)
        self.assertIn("commit", result.stderr)
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

    def test_pinned_checker_bytes_execute_outside_candidate_tree(self) -> None:
        path_sensitive_checker = """#!/usr/bin/env python3
from pathlib import Path
import sys

candidate_root = Path.cwd().resolve()
checker = Path(__file__).resolve()
bound_flags = {
    "--ledger",
    "--source-selection",
    "--trust-root",
    "--create-manifest-or-disposition",
    "--extension-manifest-or-disposition",
    "--adapter-manifest-or-disposition",
    "--fixture-set-or-disposition",
}
bound_values = [
    sys.argv[index + 1]
    for index, value in enumerate(sys.argv[:-1])
    if value in bound_flags
]
raise SystemExit(
    91
    if checker.is_relative_to(candidate_root)
    or len(bound_values) != len(bound_flags)
    or any(not value.startswith("/dev/fd/") for value in bound_values)
    else 0
)
"""
        self.write_repository(
            "scripts/check_qinao_owner_ledger.py",
            path_sensitive_checker,
            mode=0o644,
        )
        self.git("add", "scripts/check_qinao_owner_ledger.py")
        trusted_checker = self.external / "pinned-owner-ledger-checker.py"
        trusted_checker.write_text(
            path_sensitive_checker,
            encoding="utf-8",
        )
        trusted_checker.chmod(0o700)

        self.rewrite_bundle(
            lambda bundle: bundle["toolBlobs"]["ownerLedgerChecker"].__setitem__(
                "blobDigest",
                self.staged_blob_sha256(
                    "scripts/check_qinao_owner_ledger.py"
                ),
            )
        )

        result = self.run_runner(pinned_checker=trusted_checker)

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(self.report_path.is_file())

    def test_pinned_checker_must_equal_candidate_tree_binding(self) -> None:
        pinned_checker = self.external / "pinned-owner-ledger-checker.py"
        pinned_checker.write_text(
            "#!/usr/bin/env python3\nraise SystemExit(0)\n",
            encoding="utf-8",
        )
        pinned_checker.chmod(0o700)

        result = self.run_runner(pinned_checker=pinned_checker)

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("pinned owner-ledger checker bytes", result.stderr)
        self.assertFalse(self.report_path.exists())

    def test_external_inputs_reject_hardlinks_even_at_distinct_paths(
        self,
    ) -> None:
        selection_alias = self.external / "source-selection-hardlink.json"
        os.link(self.trust_path, selection_alias)
        command = self.command()
        command[command.index("--source-selection") + 1] = str(
            selection_alias
        )

        result = self.run_runner(command)

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("hard link", result.stderr)
        self.assertFalse(self.report_path.exists())

    def test_external_input_path_swap_reads_only_the_open_descriptor(
        self,
    ) -> None:
        path = self.external / "descriptor-bound.json"
        original = b'{"original":true}\n'
        replacement = self.external / "replacement.json"
        path.write_bytes(original)
        path.chmod(0o600)
        replacement.write_bytes(b'{"replacement":true}\n')
        replacement.chmod(0o600)
        real_fstat = admission_runner.os.fstat
        swapped = False

        def swap_after_open(descriptor: int):
            nonlocal swapped
            metadata = real_fstat(descriptor)
            if not swapped:
                swapped = True
                os.replace(replacement, path)
            return metadata

        with self.assertRaisesRegex(
            admission_runner.GateError,
            "changed while.*bound descriptor",
        ):
            with mock.patch.object(
                admission_runner.os,
                "fstat",
                side_effect=swap_after_open,
            ):
                admission_runner.external_file_bytes(
                    path,
                    self.root,
                    "descriptor-bound fixture",
                )

        self.assertTrue(swapped)
        self.assertNotEqual(path.read_bytes(), original)

    def test_source_trust_and_predecessor_consumers_use_captured_bytes(
        self,
    ) -> None:
        cases = (
            ("source selection", self.selection_path),
            ("trust root", self.trust_path),
            ("previous receipt", self.previous_path),
        )
        real_external_file_bytes = admission_runner.external_file_bytes
        for target_label, target_path in cases:
            with self.subTest(target=target_label):
                original = target_path.read_bytes()
                replacement = self.external / (
                    f"replacement-{target_label.replace(' ', '-')}.json"
                )
                replacement.write_bytes(b'{"attacker":true}\n')
                replacement.chmod(0o600)
                swapped = False

                def capture_then_swap(path, root, label):
                    nonlocal swapped
                    result = real_external_file_bytes(path, root, label)
                    if label == target_label:
                        os.replace(replacement, target_path)
                        swapped = True
                    return result

                try:
                    with mock.patch.object(
                        admission_runner,
                        "external_file_bytes",
                        side_effect=capture_then_swap,
                    ):
                        _root, report, _trust, _reserved = (
                            admission_runner.derive_report(
                                self.derive_arguments(),
                                verification_time=VERIFICATION_TIME,
                            )
                        )
                    self.assertTrue(swapped)
                    self.assertEqual(report["admissionStatus"], "unadmitted")
                finally:
                    target_path.write_bytes(original)
                    target_path.chmod(0o600)

    def test_current_receipt_consumer_uses_captured_bytes_after_path_swap(
        self,
    ) -> None:
        root, report, trust_root, reserved = admission_runner.derive_report(
            self.derive_arguments(),
            verification_time=VERIFICATION_TIME,
        )
        receipt_path = self.write_external(
            "current-receipt-bound.json",
            self.current_receipt(),
        )
        replacement = self.external / "replacement-current-receipt.json"
        replacement.write_bytes(b'{"attacker":true}\n')
        replacement.chmod(0o600)
        real_external_file_bytes = admission_runner.external_file_bytes

        def capture_then_swap(path, repository_root, label):
            result = real_external_file_bytes(path, repository_root, label)
            if label == "receipt":
                os.replace(replacement, receipt_path)
            return result

        with mock.patch.object(
            admission_runner,
            "external_file_bytes",
            side_effect=capture_then_swap,
        ):
            admission_runner.verify_receipt(
                argparse.Namespace(receipt=receipt_path),
                root=root,
                report=report,
                trust_root=trust_root,
                reserved_paths=reserved,
                verification_time=VERIFICATION_TIME,
            )
        self.assertEqual(receipt_path.read_bytes(), b'{"attacker":true}\n')

    def test_pinned_checker_swap_cannot_execute_replacement_path(
        self,
    ) -> None:
        pinned_checker = self.external / "pinned-owner-ledger-checker.py"
        pinned_checker.write_text(FAKE_CHECKER, encoding="utf-8")
        pinned_checker.chmod(0o700)
        marker = self.external / "replacement-executed"
        replacement = self.external / "replacement-checker.py"
        replacement.write_text(
            (
                "from pathlib import Path\n"
                f"Path({str(marker)!r}).write_text('executed')\n"
            ),
            encoding="utf-8",
        )
        replacement.chmod(0o700)
        real_open_bound_checker = admission_runner.open_bound_checker
        swap_count = 0

        def open_then_swap(path, label):
            nonlocal swap_count
            result = real_open_bound_checker(path, label)
            if label == "owner-ledger checker":
                os.replace(replacement, pinned_checker)
                swap_count += 1
            return result

        with mock.patch.dict(
            os.environ,
            {"QINAO_PINNED_OWNER_LEDGER_CHECKER": str(pinned_checker)},
            clear=False,
        ):
            with mock.patch.object(
                admission_runner,
                "open_bound_checker",
                side_effect=open_then_swap,
            ):
                with self.assertRaisesRegex(
                    admission_runner.GateError,
                    "changed while its bound descriptor executed",
                ):
                    admission_runner.derive_report(
                        self.derive_arguments(),
                        verification_time=VERIFICATION_TIME,
                    )
        self.assertEqual(swap_count, 1)
        self.assertFalse(marker.exists())

    def test_prior_and_entry_predecessor_consumers_use_captured_bytes(
        self,
    ) -> None:
        prior_receipts, entry_predecessor = self.configure_w6_6_prefix()
        cases = (
            (
                "prior admission receipt w6.runtime.observation-values",
                prior_receipts[0][1],
            ),
            ("runtime entry predecessor", entry_predecessor),
        )
        real_external_file_bytes = admission_runner.external_file_bytes
        for target_label, target_path in cases:
            with self.subTest(target=target_label):
                original = target_path.read_bytes()
                replacement = self.external / (
                    f"replacement-{target_label.replace(' ', '-')}.json"
                )
                replacement.write_bytes(b'{"attacker":true}\n')
                replacement.chmod(0o600)

                def capture_then_swap(path, root, label):
                    result = real_external_file_bytes(path, root, label)
                    if label == target_label:
                        os.replace(replacement, target_path)
                    return result

                try:
                    with mock.patch.object(
                        admission_runner,
                        "external_file_bytes",
                        side_effect=capture_then_swap,
                    ):
                        _root, report, _trust, _reserved = (
                            admission_runner.derive_report(
                                self.derive_arguments(
                                    prior_admission_receipts=prior_receipts,
                                    runtime_entry_predecessor=entry_predecessor,
                                ),
                                verification_time=VERIFICATION_TIME,
                            )
                        )
                    self.assertEqual(
                        len(report["priorAdmissionReceipts"]),
                        5,
                    )
                finally:
                    target_path.write_bytes(original)
                    target_path.chmod(0o600)

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

    def test_unstaged_production_path_outside_wave_list_is_rejected(self) -> None:
        self.write_repository(
            "BehavioralAISubstrate/Sources/TestOnly/OutsideWave.swift",
            "public struct OutsideWave {}\n",
        )

        result = self.run_runner()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("unstaged production drift outside wave", result.stderr)
        self.assertIn("OutsideWave.swift", result.stderr)
        self.assertFalse(self.report_path.exists())

    def test_path_list_and_index_diff_must_be_equal_both_directions(self) -> None:
        removed_path = (
            b"docs/superpowers/specs/qinao-owner-ledger-v1.json\n"
        )
        self.assertIn(removed_path, self.path_list_bytes)
        mutated_path_list = self.path_list_bytes.replace(removed_path, b"")
        self.assertNotEqual(mutated_path_list, self.path_list_bytes)
        self.write_repository(
            "docs/evidence/paths.txt",
            mutated_path_list,
        )
        self.git("add", "docs/evidence/paths.txt")
        self.candidate_tree = self.git("write-tree")

        result = self.run_runner()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("path-list/index-diff mismatch", result.stderr)
        self.assertIn(
            "docs/superpowers/specs/qinao-owner-ledger-v1.json",
            result.stderr,
        )
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
            [
                {
                    **self.bundle["externalPrerequisites"][0],
                    "verifiedOutcome": "accepted",
                }
            ],
        )

    def test_w6_8_reverifies_same_stored_chain_digest_across_both_receipts(
        self,
    ) -> None:
        chain_path = self.configure_w6_8_runtime_chain()

        result = self.run_runner(
            self.command(
                external_prerequisites=[
                    ("runtime-receipt-chain", chain_path),
                ]
            )
        )

        self.assertEqual(result.returncode, 0, result.stderr)
        report = json.loads(self.report_path.read_bytes())
        self.assertEqual(report["waveSliceID"], "w6.certification")
        self.assertEqual(
            report["externalPrerequisites"][0]["blobDigest"],
            self.blob_digest(chain_path),
        )

    def test_w6_8_rejects_malformed_w6_7_external_observation(self) -> None:
        chain_path = self.configure_w6_8_runtime_chain()
        previous = copy.deepcopy(self.previous_receipt)
        previous.pop("signature")
        previous["externalPrerequisites"][0]["verifiedOutcome"] = "rejected"
        self.previous_receipt = self.signed(previous)
        self.write_external(self.previous_path.name, self.previous_receipt)
        self.rewrite_bundle(
            lambda bundle: bundle.__setitem__(
                "requiredPredecessorReceiptBlob",
                self.blob_digest(self.previous_path),
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
        self.assertIn(
            "runtime-chain external observation mismatch",
            result.stderr,
        )
        self.assertFalse(self.report_path.exists())

    def test_w6_8_rejects_chain_digest_not_bound_by_w6_7_receipt(
        self,
    ) -> None:
        chain_path = self.configure_w6_8_runtime_chain()
        previous = copy.deepcopy(self.previous_receipt)
        previous.pop("signature")
        previous["externalPrerequisites"][0]["blobDigest"] = "0" * 64
        self.previous_receipt = self.signed(previous)
        self.write_external(self.previous_path.name, self.previous_receipt)
        self.rewrite_bundle(
            lambda bundle: bundle.__setitem__(
                "requiredPredecessorReceiptBlob",
                self.blob_digest(self.previous_path),
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
        self.assertIn("W6.8 runtime-chain/W6.7 continuity", result.stderr)

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
            "inside": (inside_path, ("outside the repository",)),
            "mode": (wrong_mode_path, ("mode 0600",)),
            "symlink": (
                symlink_path,
                ("external prerequisite", "cannot be read"),
            ),
            "aliases-previous": (
                self.previous_path,
                ("device-inode", "distinct"),
            ),
        }
        for label, (path, diagnostics) in cases.items():
            with self.subTest(label=label):
                result = self.run_runner(
                    self.command(
                        external_prerequisites=[
                            ("runtime-receipt-chain", path),
                        ]
                    )
                )
                self.assertNotEqual(result.returncode, 0)
                for diagnostic in diagnostics:
                    self.assertIn(diagnostic, result.stderr)
                self.assertFalse(self.report_path.exists())

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
                False,
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
                "identity/schedule",
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
                "stored bytes",
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
