from __future__ import annotations

import base64
import copy
import hashlib
import json
import sys
import unittest
from pathlib import Path

from scripts import check_qinao_owner_ledger as checker
from scripts import run_qinao_k4_ios27_platform_spike as k4
from scripts import run_qinao_wave_admission as wave
from scripts.test_check_qinao_owner_ledger import (
    _canonical_test_json,
    _test_ed25519_key,
    _test_ed25519_sign,
)


PROJECT_ROOT = Path(__file__).resolve().parents[1]
FIXTURE = (
    PROJECT_ROOT
    / "scripts/fixtures/qinao_admission_canonical_vectors_v1.json"
)
REPOSITORY_IDENTITY = "test-only/qinao-canonical-vectors"
ISSUED_AT = "2026-07-29T00:00:00Z"
EXPIRES_AT = "2035-01-01T00:00:00Z"
VECTOR_NAMES = (
    "bundle",
    "category",
    "design-edge",
    "k4-device-profile",
    "k4-platform-spike",
    "root",
    "runtime-chain",
    "source-selection",
    "wave-ordinary",
    "wave-w6",
)
TEST_SEEDS = {
    name: bytes([index]) * 32
    for index, name in enumerate(VECTOR_NAMES, start=1)
}
RUNTIME_RECEIPT_SEED = b"\x40" * 32


def _sha(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def _h(character: str) -> str:
    return character * 64


def _git(character: str) -> str:
    return character * 40


def _sign(unsigned: dict, seed: bytes) -> dict:
    document = copy.deepcopy(unsigned)
    preimage = hashlib.sha256(_canonical_test_json(unsigned)).digest()
    document["signature"] = base64.b64encode(
        _test_ed25519_sign(seed, preimage)
    ).decode("ascii")
    return document


def _signed_envelope(
    *,
    schema: str,
    role: str,
    signer: str,
    nonce: str,
) -> dict:
    return {
        "schema": schema,
        "repositoryIdentity": REPOSITORY_IDENTITY,
        "issuedAt": ISSUED_AT,
        "expiresAt": EXPIRES_AT,
        "nonce": nonce,
        "signer": signer,
        "role": role,
        "signatureAlgorithm": "Ed25519",
    }


def _frozen_schema(name: str) -> dict:
    schema = {
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "$id": f"qinao://schemas/{name}/1.0.0",
        "title": name,
        "type": "object",
        "properties": {"schema": {"const": f"{name}V1"}},
        "required": ["schema"],
        "additionalProperties": False,
    }
    return {
        "name": name,
        "version": "1.0.0",
        "jsonSchema": schema,
        "sha256": _sha(_canonical_test_json(schema)),
    }


def _frozen_rows(ordinal: int) -> list[dict]:
    if ordinal == 1:
        return []
    first = _frozen_schema("BASRuntimeAuditProjectionsBundle")
    if ordinal == 2:
        return [first]
    return [
        first,
        _frozen_schema("BASSameRunAuditOutcome"),
        _frozen_schema("BASTurnRuntimeAuditEnvelope"),
    ]


def _tool_blobs() -> dict:
    return {
        "bundleReviewSigningProvider": _h("1"),
        "externalVerifier": _h("2"),
        "ownerLedgerChecker": {
            "path": "scripts/check_qinao_owner_ledger.py",
            "blobDigest": _h("3"),
        },
        "repositoryRunner": {
            "path": "scripts/run_qinao_wave_admission.py",
            "blobDigest": _h("4"),
        },
        "waveAdmissionSigningProvider": _h("5"),
    }


def _verified_categories(marker: str = "6") -> dict:
    return {
        category: {
            "blobDigest": _h(marker),
            "reviewedRowsRoot": _sha(_canonical_test_json([])),
            "rowCount": 0,
            "status": "notApplicable",
        }
        for category in ("adapter", "create", "extension", "fixture")
    }


def _source_selection() -> dict:
    unsigned = {
        "schemaVersion": 1,
        "repositoryIdentity": REPOSITORY_IDENTITY,
        "selectedHEAD": _git("1"),
        "selectedTree": _git("2"),
        "approvedDesign": {
            "path": "README.md",
            "commit": _git("1"),
            "tree": _git("2"),
            "blob": _git("3"),
            "byteLength": 25,
            "sha256": _h("a"),
        },
        "candidateComparisons": [
            {
                "candidateID": "selected-test-candidate",
                "comparisonBaseHEAD": _git("1"),
                "head": _git("1"),
                "tree": _git("2"),
                "selected": True,
                "committedRows": [],
                "stagedRows": [],
                "unstagedRows": [],
                "untrackedRows": [],
            }
        ],
        "reviewerPrincipal": "test-only-source-selector",
        "reviewerRole": "source-selector",
        "issuedAt": ISSUED_AT,
        "expiresAt": EXPIRES_AT,
        "nonce": "canonical-source-selection",
        "signatureAlgorithm": "Ed25519",
    }
    return _sign(unsigned, TEST_SEEDS["source-selection"])


def _root_receipt(source: dict) -> dict:
    public_key = _test_ed25519_key(TEST_SEEDS["source-selection"])[0]
    unsigned = {
        **_signed_envelope(
            schema="QinaoRootAdmissionReceiptV1",
            role="root-admission-signer",
            signer="test-only-root-key",
            nonce="canonical-root",
        ),
        "sourceSelectionBlobDigest": _sha(
            _canonical_test_json(source) + b"\n"
        ),
        "trustRootBlobDigest": _h("b"),
        "toolBlobs": {
            "externalVerifier": _h("2"),
            "signingProvider": _h("7"),
        },
        "verifiedSelector": {
            "principalID": "test-only-source-selector",
            "keyID": "test-only-source-key",
            "role": "source-selector",
            "schemaScope": "QinaoDualSpaceSourceSelectionV1",
            "publicKeyFingerprintSHA256": _sha(public_key),
        },
        "verifiedHEAD": _git("1"),
        "verifiedTree": _git("2"),
        "verifiedAt": ISSUED_AT,
        "outcome": "accepted",
    }
    return _sign(unsigned, TEST_SEEDS["root"])


def _design_receipt(root: dict, source: dict) -> dict:
    unsigned = {
        **_signed_envelope(
            schema="QinaoDesignEdgeAdmissionReceiptV1",
            role="design-edge-admission-signer",
            signer="test-only-design-key",
            nonce="canonical-design-edge",
        ),
        "rootReceiptBlobDigest": _sha(
            _canonical_test_json(root) + b"\n"
        ),
        "baseCommit": _git("1"),
        "baseTree": _git("2"),
        "candidateTree": _git("4"),
        "approvedDesign": source["approvedDesign"],
        "toolBlobs": {
            "externalVerifier": _h("2"),
            "signingProvider": _h("8"),
        },
        "verifiedAt": ISSUED_AT,
        "outcome": "admitted",
    }
    return _sign(unsigned, TEST_SEEDS["design-edge"])


def _category() -> dict:
    unsigned = {
        **_signed_envelope(
            schema="QinaoWaveCategoryEvidenceV1",
            role="wave-bundle-reviewer",
            signer="test-only-category-key",
            nonce="canonical-category",
        ),
        "wave": "W0",
        "waveSliceID": "w0.gates",
        "sequenceOrdinal": 1,
        "category": "adapter",
        "status": "notApplicable",
        "baseTree": _git("4"),
        "approvedDesignBlob": _h("a"),
        "productionDiffRoot": _h("c"),
        "reviewedRows": [],
        "reviewedRowsRoot": _sha(_canonical_test_json([])),
        "anchors": [],
        "reason": "test-only canonical category",
    }
    return _sign(unsigned, TEST_SEEDS["category"])


def _bundle() -> dict:
    unsigned = {
        **_signed_envelope(
            schema="QinaoWaveBundleV1",
            role="wave-bundle-reviewer",
            signer="test-only-bundle-key",
            nonce="canonical-bundle",
        ),
        "wave": "W0",
        "waveSliceID": "w0.gates",
        "sequenceOrdinal": 1,
        "baseCommit": _git("1"),
        "baseTree": _git("4"),
        "requiredPredecessorReceiptBlob": _h("d"),
        "requiredPredecessorCandidateTree": _git("4"),
        "priorAdmissionReceipts": [],
        "pathList": {
            "path": "docs/evidence/paths.txt",
            "blobDigest": _h("e"),
            "root": _h("e"),
            "count": 6,
        },
        "ownerLedger": {
            "path": "docs/superpowers/specs/qinao-owner-ledger-v1.json",
            "blobDigest": _h("f"),
        },
        "categories": {
            category: {
                "path": f"docs/evidence/{category}.json",
                "blobDigest": _h("6"),
            }
            for category in ("adapter", "create", "extension", "fixture")
        },
        "approvedDesignBlob": _h("a"),
        "productionDiffRoot": _h("c"),
        "evidencePrerequisites": [],
        "externalPrerequisites": [],
        "frozenSchemaDigests": [],
        "toolBlobs": _tool_blobs(),
    }
    return _sign(unsigned, TEST_SEEDS["bundle"])


def _wave_receipt(
    *,
    wave_name: str,
    slice_id: str,
    ordinal: int,
    previous_digest: str,
    frozen_rows: list[dict],
    seed: bytes,
    nonce: str,
) -> dict:
    unsigned = {
        **_signed_envelope(
            schema="QinaoWaveAdmissionReceiptV1",
            role="wave-admission-signer",
            signer="test-only-wave-key",
            nonce=nonce,
        ),
        "wave": wave_name,
        "waveSliceID": slice_id,
        "sequenceOrdinal": ordinal,
        "baseCommit": _git("1"),
        "baseTree": _git("4"),
        "candidateTree": _git("4"),
        "bundleBlobDigest": _h("1"),
        "sourceSelectionBlobDigest": _h("2"),
        "trustRootBlobDigest": _h("3"),
        "previousReceiptBlobDigest": previous_digest,
        "approvedDesignBlob": _h("a"),
        "productionDiffRoot": _h("c"),
        "pathList": {"root": _h("e"), "count": 1},
        "ownerLedger": {
            "path": "docs/superpowers/specs/qinao-owner-ledger-v1.json",
            "blobDigest": _h("f"),
        },
        "categories": _verified_categories(),
        "evidencePrerequisites": [],
        "externalPrerequisites": [],
        "frozenSchemaDigests": copy.deepcopy(frozen_rows),
        "toolBlobs": _tool_blobs(),
        "verifiedAt": ISSUED_AT,
        "outcome": "admitted",
    }
    return _sign(unsigned, seed)


def _k4_documents() -> tuple[dict, dict]:
    framework_apis = [
        {
            "framework": "TestSecurity",
            "api": "TestCapability",
            "declarationRelativePath": (
                "System/Library/Frameworks/TestSecurity.framework/"
                "Modules/TestSecurity.swiftmodule/"
                "arm64-apple-ios.swiftinterface"
            ),
            "declarationToken": "TestCapability",
        }
    ]
    target = {
        "bundleIdentifierDigest": _h("1"),
        "extensionPoint": "com.example.test-only.extension",
        "processModel": "outOfProcessExtension",
    }
    sqlite = {"fileProtection": "passed", "open": "passed", "wal": "passed"}
    transport = {"feasibility": "passed", "kind": "XPC"}
    lifecycle = [
        {"event": event, "observation": "passed"}
        for event in k4.LIFECYCLE_EVENTS
    ]
    supported_profile_digest = k4.supported_profile_digest(
        framework_apis=framework_apis,
        target=target,
        required_entitlements=["com.example.test-only"],
        sqlite=sqlite,
        transport=transport,
        lifecycle=lifecycle,
    )
    matrix = {
        "schema": "QinaoK4DeviceProbeMatrixV1",
        "deviceIdentityDigest": _h("4"),
        "frameworkAPIs": framework_apis,
        "target": target,
        "requiredEntitlements": ["com.example.test-only"],
        "sqlite": sqlite,
        "transport": transport,
        "lifecycle": lifecycle,
        "resultBundleDigest": _h("5"),
        "supportedProfileDigest": supported_profile_digest,
        "status": "supportedExactProfile",
    }
    profile_unsigned = {
        **_signed_envelope(
            schema="QinaoK4PhysicalDeviceProfileV1",
            role="k4-evidence-signer",
            signer="test-only-k4-profile-key",
            nonce="canonical-k4-profile",
        ),
        "approvedDesignBlob": _h("a"),
        "candidateCommit": _git("1"),
        "candidateTree": _git("2"),
        "platform": "iOS",
        "environment": "physicalDevice",
        "deviceIdentityDigest": _h("4"),
        "osVersion": "27.0",
        "osBuild": "24A5355p",
        "xcodeVersion": "27.0",
        "xcodeBuild": "27A5194q",
        "sdkCanonicalName": "iphoneos27.0",
        "sdkVersion": "27.0",
        "sdkBuild": "24A5355p",
        "signingIdentityClass": "Apple Development",
        "entitlementInventory": ["com.example.test-only"],
        "probeMatrix": matrix,
    }
    profile = _sign(
        profile_unsigned,
        TEST_SEEDS["k4-device-profile"],
    )
    spike_unsigned = {
        **_signed_envelope(
            schema="QinaoK4IOS27PlatformSpikeV1",
            role="k4-evidence-signer",
            signer="test-only-k4-spike-key",
            nonce="canonical-k4-spike",
        ),
        "approvedDesignBlob": profile["approvedDesignBlob"],
        "candidateCommit": profile["candidateCommit"],
        "candidateTree": profile["candidateTree"],
        "platform": profile["platform"],
        "environment": profile["environment"],
        "deviceProfileDigest": _sha(
            _canonical_test_json(profile) + b"\n"
        ),
        "deviceIdentityDigest": profile["deviceIdentityDigest"],
        "probeDeviceIdentityDigest": matrix["deviceIdentityDigest"],
        "osVersion": profile["osVersion"],
        "osBuild": profile["osBuild"],
        "xcodeVersion": profile["xcodeVersion"],
        "xcodeBuild": profile["xcodeBuild"],
        "sdkCanonicalName": profile["sdkCanonicalName"],
        "sdkVersion": profile["sdkVersion"],
        "sdkBuild": profile["sdkBuild"],
        "sdkSettingsDigest": _h("6"),
        "sdkSystemVersionDigest": _h("7"),
        "frameworkAPIs": framework_apis,
        "frameworkAPIAvailability": [
            {
                "framework": "TestSecurity",
                "api": "TestCapability",
                "declarationDigest": _h("8"),
                "declarationPresence": "present",
                "processSupportInference": "notInferred",
                "entitlementSupportInference": "notInferred",
            }
        ],
        "target": target,
        "signingIdentityClass": profile["signingIdentityClass"],
        "entitlementInventory": profile["entitlementInventory"],
        "requiredEntitlements": matrix["requiredEntitlements"],
        "sqlite": sqlite,
        "transport": transport,
        "lifecycle": lifecycle,
        "probeMatrixDigest": _sha(_canonical_test_json(matrix)),
        "resultBundleDigest": matrix["resultBundleDigest"],
        "supportedProfileDigest": supported_profile_digest,
        "status": "supportedExactProfile",
    }
    spike = _sign(spike_unsigned, TEST_SEEDS["k4-platform-spike"])
    return profile, spike


def _runtime_chain() -> dict:
    slice_ids = (
        "w6.runtime.observation-values",
        "w6.semantic.audit-schema",
        "w6.runtime.audit-envelope-freeze",
        "w6.semantic.coordinator-behavior",
        "w6.runtime.integration-population",
        "w6.runtime.engine-cutover",
    )
    predecessor_digest = _h("9")
    receipts: list[dict] = []
    for ordinal, slice_id in enumerate(slice_ids, start=1):
        receipt = _wave_receipt(
            wave_name="W6",
            slice_id=slice_id,
            ordinal=ordinal,
            previous_digest=predecessor_digest,
            frozen_rows=_frozen_rows(ordinal),
            seed=RUNTIME_RECEIPT_SEED,
            nonce=f"canonical-runtime-receipt-{ordinal}",
        )
        receipts.append(receipt)
        predecessor_digest = _sha(_canonical_test_json(receipt) + b"\n")
    entries = [
        {
            "waveSliceID": receipt["waveSliceID"],
            "sequenceOrdinal": receipt["sequenceOrdinal"],
            "receiptDigest": _sha(_canonical_test_json(receipt)),
            "receipt": receipt,
        }
        for receipt in receipts
    ]
    unsigned = {
        **_signed_envelope(
            schema="QinaoW6RuntimeReceiptChainV1",
            role="runtime-chain-signer",
            signer="test-only-runtime-chain-key",
            nonce="canonical-runtime-chain",
        ),
        "entryPredecessorReceiptBlobDigest": _h("9"),
        "entryPredecessorCandidateTree": _git("4"),
        "entries": entries,
        "expectedHeadTree": receipts[-1]["candidateTree"],
        "toolBlobs": {
            "externalVerifier": _h("2"),
            "runtimeChainSigningProvider": _h("8"),
        },
        "verifiedAt": ISSUED_AT,
        "outcome": "accepted",
    }
    return _sign(unsigned, TEST_SEEDS["runtime-chain"])


def _full_documents() -> dict[str, dict]:
    source = _source_selection()
    root = _root_receipt(source)
    profile, spike = _k4_documents()
    return {
        "bundle": _bundle(),
        "category": _category(),
        "design-edge": _design_receipt(root, source),
        "k4-device-profile": profile,
        "k4-platform-spike": spike,
        "root": root,
        "runtime-chain": _runtime_chain(),
        "source-selection": source,
        "wave-ordinary": _wave_receipt(
            wave_name="W0",
            slice_id="w0.gates",
            ordinal=1,
            previous_digest=_h("d"),
            frozen_rows=[],
            seed=TEST_SEEDS["wave-ordinary"],
            nonce="canonical-wave-ordinary",
        ),
        "wave-w6": _wave_receipt(
            wave_name="W6",
            slice_id="w6.runtime.audit-envelope-freeze",
            ordinal=3,
            previous_digest=_h("e"),
            frozen_rows=_frozen_rows(3),
            seed=TEST_SEEDS["wave-w6"],
            nonce="canonical-wave-w6",
        ),
    }


def _schema_family(name: str, document: dict) -> str:
    if name == "source-selection":
        return "QinaoDualSpaceSourceSelectionV1"
    return document["schema"]


def _vector(name: str, document: dict) -> dict:
    unsigned = copy.deepcopy(document)
    signature_base64 = unsigned.pop("signature")
    canonical_unsigned = _canonical_test_json(unsigned)
    preimage = hashlib.sha256(canonical_unsigned).digest()
    canonical_full = _canonical_test_json(document)
    stored = canonical_full + b"\n"
    public_key = _test_ed25519_key(TEST_SEEDS[name])[0]
    return {
        "name": name,
        "schemaFamily": _schema_family(name, document),
        "publicKeyBase64": base64.b64encode(public_key).decode("ascii"),
        "fullDocument": document,
        "canonicalUnsignedBase64": base64.b64encode(
            canonical_unsigned
        ).decode("ascii"),
        "signaturePreimageSHA256": preimage.hex(),
        "signatureBase64": signature_base64,
        "canonicalFullBase64": base64.b64encode(canonical_full).decode("ascii"),
        "storedBytesBase64": base64.b64encode(stored).decode("ascii"),
        "storedBlobSHA256": _sha(stored),
        "canonicalObjectSHA256": _sha(canonical_full),
    }


def build_fixture() -> dict:
    documents = _full_documents()
    fixture = {
        "schema": "QinaoAdmissionCanonicalVectorSetV1",
        "canonicalization": "RFC8785",
        "signaturePreimage": (
            "SHA256(RFC8785(documentWithoutTopLevelSignature))"
        ),
        "storage": "RFC8785(fullDocument)+LF",
        "vectors": [
            _vector(name, documents[name])
            for name in VECTOR_NAMES
        ],
    }
    fixture["vectorSetSHA256"] = _sha(_canonical_test_json(fixture))
    return fixture


def fixture_bytes() -> bytes:
    return _canonical_test_json(build_fixture()) + b"\n"


class QinaoAdmissionCanonicalVectorTests(unittest.TestCase):
    def test_tracked_fixture_equals_deterministic_regeneration(self) -> None:
        self.assertEqual(FIXTURE.read_bytes(), fixture_bytes())

    def test_fixture_storage_is_closed_canonical_and_contains_no_seed(self) -> None:
        raw = FIXTURE.read_bytes()
        self.assertTrue(raw.endswith(b"}\n"))
        self.assertFalse(raw.endswith(b"\n\n"))
        document = json.loads(
            raw,
            object_pairs_hook=checker.reject_duplicate_json_keys,
        )
        self.assertEqual(raw, _canonical_test_json(document) + b"\n")
        lowered = raw.lower()
        self.assertNotIn(b"privatekey", lowered)
        self.assertNotIn(b"private_key", lowered)
        self.assertNotIn(b"private seed", lowered)
        self.assertNotIn(b"private_seed", lowered)
        self.assertNotIn(b'"seed"', lowered)

    def test_all_vector_bytes_digests_and_signatures_are_exact(self) -> None:
        fixture = json.loads(FIXTURE.read_bytes())
        self.assertEqual(
            set(fixture),
            {
                "schema",
                "canonicalization",
                "signaturePreimage",
                "storage",
                "vectors",
                "vectorSetSHA256",
            },
        )
        self.assertEqual(
            [row["name"] for row in fixture["vectors"]],
            list(VECTOR_NAMES),
        )
        without_set_digest = copy.deepcopy(fixture)
        set_digest = without_set_digest.pop("vectorSetSHA256")
        self.assertEqual(set_digest, _sha(_canonical_test_json(without_set_digest)))
        for row in fixture["vectors"]:
            with self.subTest(vector=row["name"]):
                self.assertEqual(
                    set(row),
                    {
                        "name",
                        "schemaFamily",
                        "publicKeyBase64",
                        "fullDocument",
                        "canonicalUnsignedBase64",
                        "signaturePreimageSHA256",
                        "signatureBase64",
                        "canonicalFullBase64",
                        "storedBytesBase64",
                        "storedBlobSHA256",
                        "canonicalObjectSHA256",
                    },
                )
                unsigned = copy.deepcopy(row["fullDocument"])
                signature = base64.b64decode(unsigned.pop("signature"))
                canonical_unsigned = _canonical_test_json(unsigned)
                canonical_full = _canonical_test_json(row["fullDocument"])
                stored = canonical_full + b"\n"
                preimage = hashlib.sha256(canonical_unsigned).digest()
                public_key = base64.b64decode(row["publicKeyBase64"])
                self.assertEqual(
                    base64.b64decode(row["canonicalUnsignedBase64"]),
                    canonical_unsigned,
                )
                self.assertEqual(row["signaturePreimageSHA256"], preimage.hex())
                self.assertEqual(base64.b64decode(row["signatureBase64"]), signature)
                self.assertEqual(
                    base64.b64decode(row["canonicalFullBase64"]),
                    canonical_full,
                )
                self.assertEqual(
                    base64.b64decode(row["storedBytesBase64"]),
                    stored,
                )
                self.assertEqual(row["storedBlobSHA256"], _sha(stored))
                self.assertEqual(
                    row["canonicalObjectSHA256"],
                    _sha(canonical_full),
                )
                self.assertTrue(
                    checker.verify_ed25519_signature(
                        public_key,
                        preimage,
                        signature,
                    )
                )
                self.assertFalse(
                    checker.verify_ed25519_signature(
                        public_key,
                        canonical_unsigned,
                        signature,
                    )
                )
                raw_json_preimage = hashlib.sha256(
                    b" " + canonical_unsigned
                ).digest()
                self.assertFalse(
                    checker.verify_ed25519_signature(
                        public_key,
                        raw_json_preimage,
                        signature,
                    )
                )

    def test_exact_document_shapes_and_receipt_digest_domains(self) -> None:
        documents = {
            row["name"]: row["fullDocument"]
            for row in build_fixture()["vectors"]
        }
        expected_fields = {
            "bundle": wave.BUNDLE_FIELDS,
            "category": checker.WAVE_CATEGORY_FIELDS,
            "design-edge": wave.DESIGN_RECEIPT_FIELDS,
            "k4-device-profile": k4.PROFILE_FIELDS,
            "k4-platform-spike": k4.EVIDENCE_FIELDS,
            "root": wave.ROOT_RECEIPT_FIELDS,
            "runtime-chain": wave.RUNTIME_CHAIN_FIELDS,
            "source-selection": checker.SOURCE_SELECTION_FIELDS,
            "wave-ordinary": wave.RUNTIME_RECEIPT_FIELDS,
            "wave-w6": wave.RUNTIME_RECEIPT_FIELDS,
        }
        for name, fields in expected_fields.items():
            with self.subTest(vector=name):
                self.assertEqual(set(documents[name]), set(fields))
        for name in (
            "root",
            "design-edge",
            "wave-ordinary",
            "wave-w6",
        ):
            canonical_digest = _sha(_canonical_test_json(documents[name]))
            stored_digest = _sha(
                _canonical_test_json(documents[name]) + b"\n"
            )
            self.assertNotEqual(canonical_digest, stored_digest)
        entries = documents["runtime-chain"]["entries"]
        self.assertEqual(len(entries), 6)
        for index, entry in enumerate(entries):
            receipt = entry["receipt"]
            self.assertEqual(set(receipt), wave.RUNTIME_RECEIPT_FIELDS)
            self.assertEqual(
                entry["receiptDigest"],
                _sha(_canonical_test_json(receipt)),
            )
            if index:
                self.assertEqual(
                    receipt["previousReceiptBlobDigest"],
                    _sha(
                        _canonical_test_json(entries[index - 1]["receipt"])
                        + b"\n"
                    ),
                )


if __name__ == "__main__":
    if sys.argv[1:] == ["--emit-fixture"]:
        sys.stdout.buffer.write(fixture_bytes())
    elif sys.argv[1:] == ["--write-fixture"]:
        FIXTURE.parent.mkdir(parents=True, exist_ok=True)
        FIXTURE.write_bytes(fixture_bytes())
    else:
        unittest.main()
