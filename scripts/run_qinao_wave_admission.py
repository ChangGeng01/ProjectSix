#!/usr/bin/env python3
"""Derive an unsigned Qinao wave report and verify external receipts.

This repository-side program is intentionally verification-only.  It has no
signing operation and never represents a candidate as admitted.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import stat
import subprocess
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path, PurePosixPath

try:
    from check_qinao_owner_ledger import (
        DuplicateJSONKeyError,
        ORDERED_WAVE_SCHEDULE,
        WAVE_SCHEDULE,
        canonical_json_bytes,
        is_authority_diff_path,
        parse_utc_timestamp,
        reject_duplicate_json_keys,
        trusted_key,
        validate_signed_document,
        validate_source_selection,
        validate_trust_root,
    )
except ModuleNotFoundError:
    from scripts.check_qinao_owner_ledger import (
        DuplicateJSONKeyError,
        ORDERED_WAVE_SCHEDULE,
        WAVE_SCHEDULE,
        canonical_json_bytes,
        is_authority_diff_path,
        parse_utc_timestamp,
        reject_duplicate_json_keys,
        trusted_key,
        validate_signed_document,
        validate_source_selection,
        validate_trust_root,
    )

try:
    from run_qinao_k4_ios27_platform_spike import (
        EVIDENCE_FIELDS as K4_EVIDENCE_FIELDS,
        validate_evidence_bindings as validate_k4_evidence_bindings,
    )
except ModuleNotFoundError:
    from scripts.run_qinao_k4_ios27_platform_spike import (
        EVIDENCE_FIELDS as K4_EVIDENCE_FIELDS,
        validate_evidence_bindings as validate_k4_evidence_bindings,
    )


HEX_40 = re.compile(r"[0-9a-f]{40}")
HEX_64 = re.compile(r"[0-9a-f]{64}")
WAVES = {f"W{index}" for index in range(7)}
CATEGORIES = ("adapter", "create", "extension", "fixture")
BUNDLE_FIELDS = {
    "approvedDesignBlob",
    "baseCommit",
    "baseTree",
    "categories",
    "evidencePrerequisites",
    "expiresAt",
    "externalPrerequisites",
    "frozenSchemaDigests",
    "issuedAt",
    "nonce",
    "ownerLedger",
    "pathList",
    "productionDiffRoot",
    "priorAdmissionReceipts",
    "repositoryIdentity",
    "requiredPredecessorCandidateTree",
    "requiredPredecessorReceiptBlob",
    "role",
    "schema",
    "sequenceOrdinal",
    "signature",
    "signatureAlgorithm",
    "signer",
    "toolBlobs",
    "wave",
    "waveSliceID",
}
EXTERNAL_REQUIREMENT_FIELDS = {
    "blobDigest",
    "name",
    "requiredOutcome",
    "schema",
}
PRIOR_ADMISSION_REQUIREMENT_FIELDS = {
    "receiptBlobDigest",
    "sequenceOrdinal",
    "waveSliceID",
}
PRIOR_ADMISSION_OBSERVATION_FIELDS = (
    PRIOR_ADMISSION_REQUIREMENT_FIELDS
    | {
        "baseTree",
        "candidateTree",
        "outcome",
        "previousReceiptBlobDigest",
    }
)
RUNTIME_ENTRY_PREDECESSOR_FIELDS = {
    "blobDigest",
    "candidateTree",
    "outcome",
    "schema",
    "sequenceOrdinal",
    "wave",
    "waveSliceID",
}
RUNTIME_CHAIN_FIELDS = {
    "entryPredecessorCandidateTree",
    "entryPredecessorReceiptBlobDigest",
    "entries",
    "expectedHeadTree",
    "expiresAt",
    "issuedAt",
    "nonce",
    "outcome",
    "repositoryIdentity",
    "role",
    "schema",
    "signature",
    "signatureAlgorithm",
    "signer",
    "toolBlobs",
    "verifiedAt",
}
RUNTIME_RECEIPT_FIELDS = {
    "approvedDesignBlob",
    "baseCommit",
    "baseTree",
    "bundleBlobDigest",
    "candidateTree",
    "categories",
    "evidencePrerequisites",
    "expiresAt",
    "externalPrerequisites",
    "frozenSchemaDigests",
    "issuedAt",
    "nonce",
    "ownerLedger",
    "outcome",
    "pathList",
    "previousReceiptBlobDigest",
    "productionDiffRoot",
    "repositoryIdentity",
    "role",
    "schema",
    "sequenceOrdinal",
    "signature",
    "signatureAlgorithm",
    "signer",
    "toolBlobs",
    "trustRootBlobDigest",
    "sourceSelectionBlobDigest",
    "verifiedAt",
    "wave",
    "waveSliceID",
}
ROOT_RECEIPT_FIELDS = {
    "schema",
    "repositoryIdentity",
    "sourceSelectionBlobDigest",
    "trustRootBlobDigest",
    "toolBlobs",
    "verifiedSelector",
    "verifiedHEAD",
    "verifiedTree",
    "verifiedAt",
    "outcome",
    "issuedAt",
    "expiresAt",
    "nonce",
    "signer",
    "role",
    "signatureAlgorithm",
    "signature",
}
DESIGN_RECEIPT_FIELDS = {
    "schema",
    "repositoryIdentity",
    "rootReceiptBlobDigest",
    "baseCommit",
    "baseTree",
    "candidateTree",
    "approvedDesign",
    "toolBlobs",
    "verifiedAt",
    "outcome",
    "issuedAt",
    "expiresAt",
    "nonce",
    "signer",
    "role",
    "signatureAlgorithm",
    "signature",
}
OWNER_LEDGER_FIELDS = {"path", "blobDigest"}
LOCATED_TOOL_FIELDS = {"path", "blobDigest"}
TOOL_BLOBS_FIELDS = {
    "bundleReviewSigningProvider",
    "externalVerifier",
    "ownerLedgerChecker",
    "repositoryRunner",
    "waveAdmissionSigningProvider",
}
FROZEN_SCHEMA_FIELDS = {"name", "version", "jsonSchema", "sha256"}
JSON_SCHEMA_2020_12 = "https://json-schema.org/draft/2020-12/schema"
EVIDENCE_REQUIREMENT_FIELDS = {
    "name",
    "path",
    "schema",
    "blobDigest",
    "requiredStatus",
}
K4_EVIDENCE_REQUIREMENT_FIELDS = EVIDENCE_REQUIREMENT_FIELDS | {
    "requiredProfileDigest"
}
VERIFIED_EVIDENCE_FIELDS = EVIDENCE_REQUIREMENT_FIELDS | {"verifiedStatus"}
VERIFIED_K4_EVIDENCE_FIELDS = K4_EVIDENCE_REQUIREMENT_FIELDS | {
    "verifiedProfileDigest",
    "verifiedStatus",
}
VERIFIED_EXTERNAL_FIELDS = EXTERNAL_REQUIREMENT_FIELDS | {"verifiedOutcome"}
VERIFIED_CATEGORY_FIELDS = {
    "blobDigest",
    "reviewedRowsRoot",
    "rowCount",
    "status",
}
RUNTIME_SLICE_IDS = (
    "w6.runtime.observation-values",
    "w6.semantic.audit-schema",
    "w6.runtime.audit-envelope-freeze",
    "w6.semantic.coordinator-behavior",
    "w6.runtime.integration-population",
    "w6.runtime.engine-cutover",
)
GIT_TIMEOUT_SECONDS = 30
OWNER_LEDGER_CHECKER_TIMEOUT_SECONDS = 120
GIT_SUBPROCESS_ENVIRONMENT = {
    "GIT_CONFIG_GLOBAL": "/dev/null",
    "GIT_CONFIG_NOSYSTEM": "1",
    "GIT_TERMINAL_PROMPT": "0",
    "HOME": "/nonexistent",
    "LANG": "C",
    "LC_ALL": "C",
    "PATH": "/usr/bin:/bin",
}


class GateError(RuntimeError):
    """One fail-closed admission-gate diagnostic."""


def expected_predecessor_tuple(
    current_wave: str,
    current_slice: str,
    current_ordinal: int,
) -> tuple[str, str, int] | None:
    current = (current_wave, current_slice, current_ordinal)
    try:
        index = ORDERED_WAVE_SCHEDULE.index(current)
    except ValueError as error:
        raise ValueError("current tuple is not on the exact schedule") from error
    return None if index == 0 else ORDERED_WAVE_SCHEDULE[index - 1]


def validate_operation_nonce_collisions(
    signed_documents: list[tuple[str, dict]],
) -> None:
    seen: dict[tuple[str, str], tuple[str, str]] = {}
    for label, document in signed_documents:
        repository_identity = document.get("repositoryIdentity")
        nonce = document.get("nonce")
        if not isinstance(repository_identity, str) or not isinstance(nonce, str):
            fail(f"{label} is missing a signed-document nonce identity")
        unsigned = dict(document)
        unsigned.pop("signature", None)
        try:
            preimage_digest = sha256(canonical_json_bytes(unsigned))
        except ValueError as error:
            fail(f"{label} cannot be canonicalized for nonce identity: {error}")
        key = (repository_identity, nonce)
        identity = (preimage_digest, label)
        previous = seen.get(key)
        if previous is None:
            seen[key] = identity
            continue
        if previous[0] != identity[0]:
            fail(
                "signed document nonce collision between "
                f"{previous[1]} and {label}"
            )


def required_document_timestamp(
    document: dict,
    field: str,
    label: str,
) -> datetime:
    value, error = parse_utc_timestamp(
        document.get(field),
        f"{label} {field}",
    )
    if error is not None or value is None:
        fail(error or f"{label} {field} is invalid")
    return value


def validate_receipt_time_relationships(
    receipt: dict,
    *,
    label: str,
    trust_root: dict,
    inputs: list[tuple[str, dict]],
) -> None:
    verified_at = required_document_timestamp(
        receipt,
        "verifiedAt",
        label,
    )
    receipt_issued_at = required_document_timestamp(
        receipt,
        "issuedAt",
        label,
    )
    receipt_expires_at = required_document_timestamp(
        receipt,
        "expiresAt",
        label,
    )
    if not verified_at <= receipt_issued_at < receipt_expires_at:
        fail(
            f"{label} must satisfy verifiedAt <= issuedAt < expiresAt"
        )
    trust_issued_at = required_document_timestamp(
        trust_root,
        "issuedAt",
        "trust root",
    )
    trust_expires_at = required_document_timestamp(
        trust_root,
        "expiresAt",
        "trust root",
    )
    if not trust_issued_at <= verified_at < trust_expires_at:
        fail(f"{label} verifiedAt is outside the trust-root time window")

    for input_label, document in inputs:
        input_issued_at = required_document_timestamp(
            document,
            "issuedAt",
            input_label,
        )
        input_expires_at = required_document_timestamp(
            document,
            "expiresAt",
            input_label,
        )
        if not input_issued_at <= verified_at < input_expires_at:
            fail(
                f"{label} verifiedAt is outside {input_label} input "
                "time window"
            )
        is_source_selection = "schemaVersion" in document
        role = (
            document.get("reviewerRole")
            if is_source_selection
            else document.get("role")
        )
        schema_scope = (
            "QinaoDualSpaceSourceSelectionV1"
            if is_source_selection
            else document.get("schema")
        )
        resolved_key = trusted_key(
            trust_root,
            signer=None if is_source_selection else document.get("signer"),
            principal=(
                document.get("reviewerPrincipal")
                if is_source_selection
                else None
            ),
            role=role,
            schema_scope=schema_scope,
            issued_at=input_issued_at,
        )
        if resolved_key is None:
            fail(f"{input_label} signing key cannot be resolved")
        key, _public_key = resolved_key
        key_not_before = required_document_timestamp(
            key,
            "notBefore",
            f"{input_label} signing key",
        )
        key_not_after = required_document_timestamp(
            key,
            "notAfter",
            f"{input_label} signing key",
        )
        if not key_not_before <= verified_at < key_not_after:
            fail(
                f"{label} verifiedAt is outside {input_label} signing-key "
                "time window"
            )


def fail(message: str) -> None:
    raise GateError(message)


def add_common_arguments(parser: argparse.ArgumentParser) -> None:
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--bundle", type=Path, required=True)
    parser.add_argument("--source-selection", type=Path, required=True)
    parser.add_argument("--trust-root", type=Path, required=True)
    parser.add_argument("--previous-receipt", type=Path, required=True)
    parser.add_argument("--candidate-tree", required=True)
    parser.add_argument(
        "--external-prerequisite",
        action="append",
        default=[],
        metavar="NAME=PATH",
    )
    parser.add_argument(
        "--prior-admission-receipt",
        action="append",
        default=[],
        metavar="WAVE_SLICE_ID=PATH",
    )
    parser.add_argument("--runtime-entry-predecessor", type=Path)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="mode", required=True)
    report = subparsers.add_parser("report")
    add_common_arguments(report)
    report.add_argument("--unsigned-report", type=Path, required=True)
    verify = subparsers.add_parser("verify-receipt")
    add_common_arguments(verify)
    verify.add_argument("--receipt", type=Path, required=True)
    return parser.parse_args()


def run_git(
    root: Path,
    arguments: list[str],
    *,
    input_bytes: bytes | None = None,
) -> bytes:
    try:
        completed = subprocess.run(
            ["git", *arguments],
            cwd=root,
            input=input_bytes,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
            env=GIT_SUBPROCESS_ENVIRONMENT,
            timeout=GIT_TIMEOUT_SECONDS,
        )
    except (OSError, subprocess.TimeoutExpired):
        fail(f"Git command unavailable or timed out ({' '.join(arguments)})")
    if completed.returncode != 0:
        diagnostic = completed.stderr.decode("utf-8", errors="replace").strip()
        fail(
            f"Git command failed ({' '.join(arguments)}): "
            f"{diagnostic or f'exit {completed.returncode}'}"
        )
    return completed.stdout


def sha256(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def is_normalized_path(value: object) -> bool:
    if (
        not isinstance(value, str)
        or not value
        or "\\" in value
        or any(ord(character) < 0x20 for character in value)
    ):
        return False
    path = PurePosixPath(value)
    return (
        not path.is_absolute()
        and ".." not in path.parts
        and "." not in path.parts
        and str(path) == value
    )


def ensure_repository(root_argument: Path) -> Path:
    try:
        root = root_argument.resolve(strict=True)
    except OSError as error:
        fail(f"--root cannot be resolved: {error}")
    if not root.is_dir():
        fail("--root must be a directory")
    discovered = run_git(
        root,
        ["rev-parse", "--show-toplevel"],
    ).decode("utf-8", errors="strict").strip()
    try:
        discovered_root = Path(discovered).resolve(strict=True)
    except OSError as error:
        fail(f"Git repository root cannot be resolved: {error}")
    if discovered_root != root:
        fail("--root must name the exact Git worktree root")
    return root


def path_is_within(path: Path, root: Path) -> bool:
    try:
        path.relative_to(root)
    except ValueError:
        return False
    return True


def load_json_bytes(raw: bytes, label: str) -> dict:
    if not raw or len(raw) > 8 * 1024 * 1024:
        fail(f"{label} must be non-empty and at most 8 MiB")
    try:
        document = json.loads(
            raw,
            object_pairs_hook=reject_duplicate_json_keys,
        )
    except (
        UnicodeDecodeError,
        json.JSONDecodeError,
        DuplicateJSONKeyError,
        ValueError,
    ) as error:
        fail(f"{label} document is invalid: {error}")
    if not isinstance(document, dict):
        fail(f"{label} must be a JSON object")
    try:
        expected = canonical_json_bytes(document) + b"\n"
    except ValueError as error:
        fail(f"{label} cannot be canonicalized: {error}")
    if raw != expected:
        fail(f"{label} bytes must be canonical JSON followed by one newline")
    return document


def external_file_bytes(
    path_argument: Path,
    root: Path,
    label: str,
) -> tuple[Path, bytes, tuple[int, int]]:
    try:
        parent = path_argument.parent.resolve(strict=True)
    except OSError as error:
        fail(f"{label} parent cannot be resolved: {error}")
    path = parent / path_argument.name
    if path_is_within(path, root):
        fail(f"{label} must be outside the repository")
    if not hasattr(os, "O_NOFOLLOW"):
        fail(f"{label} cannot be opened safely: O_NOFOLLOW is unavailable")
    descriptor: int | None = None
    try:
        descriptor = os.open(
            path,
            os.O_RDONLY | os.O_CLOEXEC | os.O_NOFOLLOW,
        )
        before = os.fstat(descriptor)
        if not stat.S_ISREG(before.st_mode):
            fail(f"{label} must be a regular file, not a symlink")
        if stat.S_IMODE(before.st_mode) != 0o600:
            fail(f"{label} must have mode 0600")
        if before.st_nlink != 1:
            fail(f"{label} must have exactly one hard link")
        chunks: list[bytes] = []
        byte_count = 0
        while byte_count < before.st_size:
            chunk = os.pread(
                descriptor,
                min(64 * 1024, before.st_size - byte_count),
                byte_count,
            )
            if not chunk:
                break
            byte_count += len(chunk)
            if byte_count > 8 * 1024 * 1024:
                fail(f"{label} must be at most 8 MiB")
            chunks.append(chunk)
        after = os.fstat(descriptor)
        before_binding = (
            before.st_dev,
            before.st_ino,
            before.st_mode,
            before.st_nlink,
            before.st_size,
            before.st_mtime_ns,
            before.st_ctime_ns,
        )
        after_binding = (
            after.st_dev,
            after.st_ino,
            after.st_mode,
            after.st_nlink,
            after.st_size,
            after.st_mtime_ns,
            after.st_ctime_ns,
        )
        if before_binding != after_binding or byte_count != before.st_size:
            fail(f"{label} changed while its bound descriptor was read")
        return path, b"".join(chunks), (before.st_dev, before.st_ino)
    except OSError as error:
        fail(f"{label} cannot be read: {error}")
    finally:
        if descriptor is not None:
            os.close(descriptor)


def repository_file_path(path_argument: Path, root: Path, label: str) -> tuple[Path, str]:
    try:
        parent = path_argument.parent.resolve(strict=True)
    except OSError as error:
        fail(f"{label} parent cannot be resolved: {error}")
    path = parent / path_argument.name
    try:
        relative = path.relative_to(root).as_posix()
    except ValueError as error:
        fail(f"{label} must be inside the repository: {error}")
    if not is_normalized_path(relative):
        fail(f"{label} path is not normalized: {relative!r}")
    return path, relative


def open_bound_checker(
    path_argument: Path,
    label: str,
) -> tuple[int, bytes, tuple[int, ...]]:
    try:
        parent = path_argument.parent.resolve(strict=True)
    except OSError as error:
        fail(f"{label} parent cannot be resolved: {error}")
    path = parent / path_argument.name
    if not hasattr(os, "O_NOFOLLOW"):
        fail(f"{label} cannot be opened safely: O_NOFOLLOW is unavailable")
    descriptor: int | None = None
    try:
        descriptor = os.open(
            path,
            os.O_RDONLY | os.O_CLOEXEC | os.O_NOFOLLOW,
        )
        before = os.fstat(descriptor)
        if not stat.S_ISREG(before.st_mode):
            fail(f"{label} must be a regular non-symlink file")
        if before.st_nlink != 1:
            fail(f"{label} must have exactly one hard link")
        if stat.S_IMODE(before.st_mode) & 0o022:
            fail(f"{label} must not be group/world writable")
        chunks: list[bytes] = []
        byte_count = 0
        while byte_count < before.st_size:
            chunk = os.pread(
                descriptor,
                min(64 * 1024, before.st_size - byte_count),
                byte_count,
            )
            if not chunk:
                break
            byte_count += len(chunk)
            if byte_count > 8 * 1024 * 1024:
                fail(f"{label} must be at most 8 MiB")
            chunks.append(chunk)
        binding = (
            before.st_dev,
            before.st_ino,
            before.st_mode,
            before.st_nlink,
            before.st_size,
            before.st_mtime_ns,
            before.st_ctime_ns,
        )
        after = os.fstat(descriptor)
        if binding != (
            after.st_dev,
            after.st_ino,
            after.st_mode,
            after.st_nlink,
            after.st_size,
            after.st_mtime_ns,
            after.st_ctime_ns,
        ) or byte_count != before.st_size:
            fail(f"{label} changed while its bound descriptor was read")
        return descriptor, b"".join(chunks), binding
    except OSError as error:
        if descriptor is not None:
            os.close(descriptor)
        fail(f"{label} cannot be read safely: {error}")
    except GateError:
        if descriptor is not None:
            os.close(descriptor)
        raise


def read_only_snapshot_descriptor(raw: bytes, label: str) -> int:
    descriptor: int | None = None
    read_descriptor: int | None = None
    snapshot_path: str | None = None
    try:
        descriptor, snapshot_path = tempfile.mkstemp(
            prefix="qinao-bound-",
            suffix=".snapshot",
        )
        offset = 0
        while offset < len(raw):
            written = os.write(descriptor, raw[offset:])
            if written <= 0:
                raise OSError("short snapshot write")
            offset += written
        os.fsync(descriptor)
        os.close(descriptor)
        descriptor = None
        read_descriptor = os.open(
            snapshot_path,
            os.O_RDONLY | os.O_CLOEXEC | os.O_NOFOLLOW,
        )
        metadata = os.fstat(read_descriptor)
        if (
            not stat.S_ISREG(metadata.st_mode)
            or metadata.st_nlink != 1
            or metadata.st_size != len(raw)
        ):
            fail(f"{label} captured-byte snapshot binding is invalid")
        os.unlink(snapshot_path)
        snapshot_path = None
        return read_descriptor
    except OSError as error:
        if read_descriptor is not None:
            os.close(read_descriptor)
        fail(f"{label} captured-byte snapshot cannot be created: {error}")
    finally:
        if descriptor is not None:
            os.close(descriptor)
        if snapshot_path is not None:
            try:
                os.unlink(snapshot_path)
            except OSError:
                pass


def read_tree_file(
    root: Path,
    tree: str,
    relative_path: str,
    label: str,
    *,
    expected_mode: str | None = None,
) -> bytes:
    if not is_normalized_path(relative_path):
        fail(f"{label} path is not normalized: {relative_path!r}")
    listing = run_git(
        root,
        ["ls-tree", "-z", tree, "--", relative_path],
    )
    rows = [row for row in listing.split(b"\0") if row]
    if len(rows) != 1:
        fail(f"{label} is missing from candidate tree: {relative_path}")
    try:
        metadata, encoded_path = rows[0].split(b"\t", 1)
        mode, object_type, object_id = metadata.decode("ascii").split(" ")
        listed_path = encoded_path.decode("utf-8")
    except (ValueError, UnicodeDecodeError) as error:
        fail(f"{label} has invalid candidate-tree metadata: {error}")
    if listed_path != relative_path:
        fail(f"{label} candidate-tree lookup was ambiguous: {relative_path}")
    if (
        mode not in {"100644", "100755"}
        or object_type != "blob"
        or (expected_mode is not None and mode != expected_mode)
    ):
        fail(f"{label} must be a regular candidate-tree blob: {relative_path}")
    return run_git(root, ["cat-file", "blob", object_id])


def git_tree_blob_entry(
    root: Path,
    tree: object,
    relative_path: object,
    label: str,
) -> tuple[str, str] | None:
    if not isinstance(tree, str) or HEX_40.fullmatch(tree) is None:
        fail(f"{label} tree must be a Git object ID")
    if not is_normalized_path(relative_path):
        fail(f"{label} path is not normalized: {relative_path!r}")
    listing = run_git(
        root,
        ["ls-tree", "-z", tree, "--", relative_path],
    )
    rows = [row for row in listing.split(b"\0") if row]
    if not rows:
        return None
    if len(rows) != 1:
        fail(f"{label} tree lookup is ambiguous: {relative_path}")
    try:
        metadata, encoded_path = rows[0].split(b"\t", 1)
        mode, object_type, object_id = metadata.decode("ascii").split(" ")
        listed_path = encoded_path.decode("utf-8")
    except (ValueError, UnicodeDecodeError) as error:
        fail(f"{label} has invalid tree metadata: {error}")
    if listed_path != relative_path:
        fail(f"{label} tree lookup is ambiguous: {relative_path}")
    if (
        mode not in {"100644", "100755"}
        or object_type != "blob"
        or HEX_40.fullmatch(object_id) is None
    ):
        fail(f"{label} must be a regular Git blob")
    return mode, object_id


def git_tree_diff_entries(
    root: Path,
    base_tree: object,
    candidate_tree: object,
    label: str,
) -> list[dict[str, str]]:
    if (
        not isinstance(base_tree, str)
        or HEX_40.fullmatch(base_tree) is None
        or not isinstance(candidate_tree, str)
        or HEX_40.fullmatch(candidate_tree) is None
    ):
        fail(f"{label} tree IDs must be Git object IDs")
    raw = run_git(
        root,
        [
            "diff-tree",
            "--no-commit-id",
            "--no-renames",
            "--raw",
            "-r",
            "-z",
            base_tree,
            candidate_tree,
        ],
    )
    records = raw.split(b"\0")
    rows: list[dict[str, str]] = []
    index = 0
    while index < len(records):
        metadata = records[index]
        index += 1
        if not metadata:
            continue
        if not metadata.startswith(b":") or index >= len(records):
            fail(f"{label} Git tree diff is malformed")
        path_bytes = records[index]
        index += 1
        try:
            fields = metadata[1:].decode("ascii").split()
            path = path_bytes.decode("utf-8")
        except UnicodeError:
            fail(f"{label} Git tree diff is malformed")
        if len(fields) != 5:
            fail(f"{label} Git tree diff is malformed")
        old_mode, new_mode, old_blob, new_blob, status = fields
        if (
            status not in {"A", "D", "M", "T"}
            or not is_normalized_path(path)
            or re.fullmatch(r"[0-7]{6}", old_mode) is None
            or re.fullmatch(r"[0-7]{6}", new_mode) is None
            or HEX_40.fullmatch(old_blob) is None
            or HEX_40.fullmatch(new_blob) is None
        ):
            fail(f"{label} Git tree diff is malformed")
        rows.append(
            {
                "oldMode": old_mode,
                "newMode": new_mode,
                "oldBlob": old_blob,
                "newBlob": new_blob,
                "status": status,
                "path": path,
            }
        )
    return rows


def require_hex(value: object, label: str, pattern: re.Pattern[str] = HEX_64) -> str:
    if not isinstance(value, str) or pattern.fullmatch(value) is None:
        fail(f"{label} must be lowercase hexadecimal")
    return value


def validate_inline_json_schema(
    schema: object,
    *,
    name: str,
    version: str,
    label: str,
) -> dict:
    if not isinstance(schema, dict):
        fail(f"{label} jsonSchema must be an object")
    if schema.get("$schema") != JSON_SCHEMA_2020_12:
        fail(f"{label} jsonSchema $schema must select Draft 2020-12")
    if schema.get("$id") != f"qinao://schemas/{name}/{version}":
        fail(f"{label} jsonSchema $id mismatch")
    if schema.get("title") != name:
        fail(f"{label} jsonSchema title mismatch")

    def resolve_local_reference(reference: str) -> object:
        if reference == "#":
            return schema
        if not reference.startswith("#/"):
            fail(f"{label} jsonSchema contains a remote or non-local $ref")
        current: object = schema
        for encoded_part in reference[2:].split("/"):
            part = encoded_part.replace("~1", "/").replace("~0", "~")
            if not isinstance(current, dict) or part not in current:
                fail(f"{label} jsonSchema contains an unresolved local $ref")
            current = current[part]
        if not isinstance(current, (dict, bool)):
            fail(f"{label} jsonSchema $ref does not resolve to a schema")
        return current

    visited: set[int] = set()

    def walk(node: object, pointer: str) -> None:
        if isinstance(node, bool):
            return
        if not isinstance(node, dict):
            fail(f"{label} jsonSchema {pointer} must be an object or boolean")
        node_identity = id(node)
        if node_identity in visited:
            return
        visited.add(node_identity)

        reference = node.get("$ref")
        if reference is not None:
            if not isinstance(reference, str) or not reference:
                fail(f"{label} jsonSchema {pointer}/$ref must be non-empty")
            walk(resolve_local_reference(reference), f"{pointer}/$ref")

        schema_type = node.get("type")
        allowed_types = {
            "array",
            "boolean",
            "integer",
            "null",
            "number",
            "object",
            "string",
        }
        if schema_type is not None:
            if isinstance(schema_type, str):
                schema_types = [schema_type]
            elif (
                isinstance(schema_type, list)
                and schema_type
                and all(isinstance(value, str) for value in schema_type)
                and len(schema_type) == len(set(schema_type))
            ):
                schema_types = schema_type
            else:
                fail(f"{label} jsonSchema {pointer}/type is invalid")
            if not set(schema_types) <= allowed_types:
                fail(f"{label} jsonSchema {pointer}/type is invalid")

        properties = node.get("properties")
        required = node.get("required")
        object_branch = (
            schema_type == "object"
            or (
                isinstance(schema_type, list)
                and "object" in schema_type
            )
            or properties is not None
            or required is not None
        )
        if object_branch and not (
            node.get("additionalProperties") is False
            or node.get("unevaluatedProperties") is False
        ):
            fail(
                f"{label} jsonSchema {pointer} object branch must close "
                "additional or unevaluated properties"
            )
        if properties is not None:
            if not isinstance(properties, dict):
                fail(f"{label} jsonSchema {pointer}/properties must be an object")
            for property_name, child in properties.items():
                if not isinstance(property_name, str) or not property_name:
                    fail(
                        f"{label} jsonSchema {pointer}/properties has "
                        "an invalid name"
                    )
                walk(child, f"{pointer}/properties/{property_name}")
        if required is not None:
            if (
                not isinstance(required, list)
                or not required
                or not all(isinstance(value, str) and value for value in required)
                or len(required) != len(set(required))
            ):
                fail(f"{label} jsonSchema {pointer}/required is invalid")
            if isinstance(properties, dict) and not set(required) <= set(properties):
                fail(
                    f"{label} jsonSchema {pointer}/required names an "
                    "undefined property"
                )

        definitions = node.get("$defs")
        if definitions is not None:
            if not isinstance(definitions, dict):
                fail(f"{label} jsonSchema {pointer}/$defs must be an object")
            for definition_name, child in definitions.items():
                if not isinstance(definition_name, str) or not definition_name:
                    fail(f"{label} jsonSchema {pointer}/$defs name is invalid")
                walk(child, f"{pointer}/$defs/{definition_name}")

        for keyword in ("allOf", "anyOf", "oneOf", "prefixItems"):
            children = node.get(keyword)
            if children is None:
                continue
            if not isinstance(children, list) or not children:
                fail(f"{label} jsonSchema {pointer}/{keyword} must be non-empty")
            for index, child in enumerate(children):
                walk(child, f"{pointer}/{keyword}/{index}")
        for keyword in (
            "additionalProperties",
            "contains",
            "else",
            "if",
            "items",
            "not",
            "propertyNames",
            "then",
            "unevaluatedItems",
            "unevaluatedProperties",
        ):
            child = node.get(keyword)
            if child is not None:
                walk(child, f"{pointer}/{keyword}")
        for keyword in ("dependentSchemas", "patternProperties"):
            children = node.get(keyword)
            if children is None:
                continue
            if not isinstance(children, dict):
                fail(f"{label} jsonSchema {pointer}/{keyword} must be an object")
            for child_name, child in children.items():
                if not isinstance(child_name, str):
                    fail(f"{label} jsonSchema {pointer}/{keyword} name is invalid")
                walk(child, f"{pointer}/{keyword}/{child_name}")

    walk(schema, "#")
    return schema


def validate_frozen_schema_digests(
    value: object,
    *,
    wave: str,
    sequence_ordinal: int,
) -> None:
    if not isinstance(value, list):
        fail("bundle frozenSchemaDigests must be an array")
    expected_names: list[str]
    if wave != "W6" or sequence_ordinal == 1:
        expected_names = []
    elif sequence_ordinal == 2:
        expected_names = ["BASRuntimeAuditProjectionsBundle"]
    else:
        expected_names = [
            "BASRuntimeAuditProjectionsBundle",
            "BASSameRunAuditOutcome",
            "BASTurnRuntimeAuditEnvelope",
        ]
    if len(value) != len(expected_names):
        fail("bundle frozenSchemaDigests cardinality is not scheduled")
    names: list[str] = []
    for index, row in enumerate(value):
        if not isinstance(row, dict) or set(row) != FROZEN_SCHEMA_FIELDS:
            fail(f"bundle frozenSchemaDigests[{index}] fields mismatch")
        if row.get("name") not in expected_names:
            fail(f"bundle frozenSchemaDigests[{index}] name is not scheduled")
        if row.get("version") != "1.0.0":
            fail(f"bundle frozenSchemaDigests[{index}] version must be 1.0.0")
        expected_digest = require_hex(
            row.get("sha256"),
            f"bundle frozenSchemaDigests[{index}] sha256",
        )
        json_schema = validate_inline_json_schema(
            row.get("jsonSchema"),
            name=row["name"],
            version=row["version"],
            label=f"bundle frozenSchemaDigests[{index}]",
        )
        if sha256(canonical_json_bytes(json_schema)) != expected_digest:
            fail(f"bundle frozenSchemaDigests[{index}] sha256 mismatch")
        names.append(row["name"])
    if names != expected_names:
        fail("bundle frozenSchemaDigests order is not scheduled")


def validate_prior_admission_bindings(
    value: object,
    *,
    wave: str,
    sequence_ordinal: int,
) -> None:
    if not isinstance(value, list):
        fail("bundle priorAdmissionReceipts must be an array")
    if wave != "W6" or sequence_ordinal != 6:
        if value:
            fail("bundle priorAdmissionReceipts is forbidden for this slice")
        return
    if len(value) != 5:
        fail("W6.6 priorAdmissionReceipts must contain exactly receipts 01–05")
    for ordinal, row in enumerate(value, start=1):
        if (
            not isinstance(row, dict)
            or set(row) != PRIOR_ADMISSION_REQUIREMENT_FIELDS
        ):
            fail(f"W6.6 priorAdmissionReceipts[{ordinal - 1}] fields mismatch")
        if (
            row.get("waveSliceID") != RUNTIME_SLICE_IDS[ordinal - 1]
            or row.get("sequenceOrdinal") != ordinal
        ):
            fail("W6.6 priorAdmissionReceipts order/schedule mismatch")
        require_hex(
            row.get("receiptBlobDigest"),
            f"W6.6 priorAdmissionReceipts[{ordinal - 1}] receiptBlobDigest",
        )


def validate_evidence_requirements(
    value: object,
    *,
    wave: str,
    sequence_ordinal: int,
) -> None:
    if not isinstance(value, list):
        fail("bundle evidencePrerequisites must be an array")
    if wave == "W5" and sequence_ordinal == 1:
        if len(value) != 1:
            fail("W5 requires exactly one K4 evidence prerequisite")
        row = value[0]
        if not isinstance(row, dict) or set(row) != K4_EVIDENCE_REQUIREMENT_FIELDS:
            fail("W5 K4 evidence prerequisite fields mismatch")
        if (
            row.get("name") != "k4-ios27-platform-spike"
            or row.get("path")
            != "docs/superpowers/evidence/qinao-k4-ios27-platform-spike.json"
            or row.get("schema") != "QinaoK4IOS27PlatformSpikeV1"
            or row.get("requiredStatus") != "supportedExactProfile"
        ):
            fail("W5 K4 evidence prerequisite literals mismatch")
        require_hex(row.get("blobDigest"), "W5 evidence blobDigest")
        require_hex(
            row.get("requiredProfileDigest"),
            "W5 evidence requiredProfileDigest",
        )
        return
    if value:
        fail("bundle evidencePrerequisites is not scheduled for this slice")


def validate_external_requirements(
    value: object,
    *,
    wave: str,
    sequence_ordinal: int,
) -> None:
    if not isinstance(value, list):
        fail("bundle externalPrerequisites must be an array")
    if wave == "W6" and sequence_ordinal in {7, 8}:
        if len(value) != 1:
            fail("W6 Apple/certification requires one runtime-chain prerequisite")
        row = value[0]
        if not isinstance(row, dict) or set(row) != EXTERNAL_REQUIREMENT_FIELDS:
            fail("runtime-chain external prerequisite fields mismatch")
        if (
            row.get("name") != "runtime-receipt-chain"
            or row.get("schema") != "QinaoW6RuntimeReceiptChainV1"
            or row.get("requiredOutcome") != "accepted"
        ):
            fail("runtime-chain external prerequisite literals mismatch")
        require_hex(row.get("blobDigest"), "runtime-chain blobDigest")
        return
    if value:
        fail("bundle externalPrerequisites is not scheduled for this slice")


def validate_bundle(
    document: dict,
    trust_root: dict,
    *,
    verification_time: datetime,
) -> None:
    if set(document) != BUNDLE_FIELDS:
        fail(
            "bundle fields mismatch: "
            f"missing={sorted(BUNDLE_FIELDS - set(document))!r}, "
            f"extra={sorted(set(document) - BUNDLE_FIELDS)!r}"
        )
    if document.get("schema") != "QinaoWaveBundleV1":
        fail("bundle schema must be QinaoWaveBundleV1")
    if document.get("repositoryIdentity") != trust_root.get("repositoryIdentity"):
        fail("bundle repositoryIdentity does not match trust root")
    wave = document.get("wave")
    if wave not in WAVES:
        fail("bundle wave must be W0 through W6")
    if not isinstance(document.get("waveSliceID"), str) or not document["waveSliceID"]:
        fail("bundle waveSliceID must be non-empty")
    sequence_ordinal = document.get("sequenceOrdinal")
    if (
        type(sequence_ordinal) is not int
        or sequence_ordinal < 1
        or WAVE_SCHEDULE.get((wave, document.get("waveSliceID")))
        != sequence_ordinal
    ):
        fail("bundle waveSliceID/sequenceOrdinal is not on the exact schedule")
    require_hex(document.get("baseCommit"), "bundle baseCommit", HEX_40)
    require_hex(document.get("baseTree"), "bundle baseTree", HEX_40)
    require_hex(
        document.get("requiredPredecessorCandidateTree"),
        "bundle requiredPredecessorCandidateTree",
        HEX_40,
    )
    for field in (
        "approvedDesignBlob",
        "productionDiffRoot",
        "requiredPredecessorReceiptBlob",
    ):
        require_hex(document.get(field), f"bundle {field}")
    validate_prior_admission_bindings(
        document.get("priorAdmissionReceipts"),
        wave=wave,
        sequence_ordinal=sequence_ordinal,
    )
    validate_evidence_requirements(
        document.get("evidencePrerequisites"),
        wave=wave,
        sequence_ordinal=sequence_ordinal,
    )
    validate_external_requirements(
        document.get("externalPrerequisites"),
        wave=wave,
        sequence_ordinal=sequence_ordinal,
    )
    validate_frozen_schema_digests(
        document.get("frozenSchemaDigests"),
        wave=wave,
        sequence_ordinal=sequence_ordinal,
    )
    owner_ledger = document.get("ownerLedger")
    if (
        not isinstance(owner_ledger, dict)
        or set(owner_ledger) != OWNER_LEDGER_FIELDS
        or owner_ledger.get("path")
        != "docs/superpowers/specs/qinao-owner-ledger-v1.json"
    ):
        fail("bundle ownerLedger binding fields/path mismatch")
    require_hex(owner_ledger.get("blobDigest"), "bundle ownerLedger blobDigest")
    tool_blobs = document.get("toolBlobs")
    if not isinstance(tool_blobs, dict) or set(tool_blobs) != TOOL_BLOBS_FIELDS:
        fail("bundle toolBlobs fields mismatch")
    for field in (
        "bundleReviewSigningProvider",
        "externalVerifier",
        "waveAdmissionSigningProvider",
    ):
        require_hex(tool_blobs.get(field), f"bundle toolBlobs.{field}")
    for field, fixed_path in (
        ("ownerLedgerChecker", "scripts/check_qinao_owner_ledger.py"),
        ("repositoryRunner", "scripts/run_qinao_wave_admission.py"),
    ):
        binding = tool_blobs.get(field)
        if (
            not isinstance(binding, dict)
            or set(binding) != LOCATED_TOOL_FIELDS
            or binding.get("path") != fixed_path
        ):
            fail(f"bundle toolBlobs.{field} located binding mismatch")
        require_hex(
            binding.get("blobDigest"),
            f"bundle toolBlobs.{field}.blobDigest",
        )
    errors = validate_signed_document(
        document,
        trust_root,
        expected_role="wave-bundle-reviewer",
        label="bundle",
        verification_time=verification_time,
    )
    if errors:
        fail("; ".join(errors))


def validate_previous_receipt(
    document: dict,
    trust_root: dict,
    source_selection: dict,
    base_tree: str,
    *,
    root: Path,
    source_raw: bytes,
    trust_raw: bytes,
    current_wave: str,
    current_slice: str,
    current_ordinal: int,
    verification_time: datetime,
) -> None:
    schema = document.get("schema")
    try:
        expected_predecessor = expected_predecessor_tuple(
            current_wave,
            current_slice,
            current_ordinal,
        )
    except ValueError as error:
        fail(str(error))
    if expected_predecessor is not None:
        if schema != "QinaoWaveAdmissionReceiptV1":
            fail(
                "previous receipt must be the exact preceding schedule row"
            )
        expected_wave, expected_slice, expected_ordinal = expected_predecessor
        observed_predecessor = (
            document.get("wave"),
            document.get("waveSliceID"),
            document.get("sequenceOrdinal"),
        )
        if observed_predecessor != expected_predecessor:
            fail(
                "previous receipt does not equal the exact preceding "
                "schedule row"
            )
        validate_uniform_wave_receipt(
            document,
            label="previous wave admission receipt",
            trust_root=trust_root,
            source_raw=source_raw,
            trust_raw=trust_raw,
            expected_wave=expected_wave,
            expected_slice=expected_slice,
            expected_ordinal=expected_ordinal,
            verification_time=verification_time,
        )
        if document.get("candidateTree") != base_tree:
            fail(
                "previous wave receipt candidateTree does not equal "
                "bundle base tree"
            )
        validate_receipt_time_relationships(
            document,
            label="previous wave admission receipt",
            trust_root=trust_root,
            inputs=[("source selection", source_selection)],
        )
        return
    if schema == "QinaoWaveAdmissionReceiptV1":
        fail("W0.1 requires a root/design predecessor")
    approved_design = source_selection.get("approvedDesign")
    if not isinstance(approved_design, dict):
        fail("source selection approvedDesign binding is invalid")
    approved_path = approved_design.get("path")
    approved_entry = git_tree_blob_entry(
        root,
        approved_design.get("tree"),
        approved_path,
        "source selection approved design",
    )
    if (
        approved_entry is None
        or approved_entry[1] != approved_design.get("blob")
    ):
        fail("source selection approved design tree/blob binding mismatch")
    selected_entry = git_tree_blob_entry(
        root,
        source_selection.get("selectedTree"),
        approved_path,
        "source selection selected tree approved design",
    )
    exact_design_already_present = selected_entry == approved_entry
    if schema == "QinaoRootAdmissionReceiptV1":
        if set(document) != ROOT_RECEIPT_FIELDS:
            fail("root admission receipt fields mismatch")
        role = "root-admission-signer"
        if document.get("outcome") != "accepted":
            fail("root admission receipt outcome must be accepted")
        if document.get("verifiedHEAD") != source_selection.get("selectedHEAD"):
            fail("root admission receipt verifiedHEAD does not bind source selection")
        if document.get("verifiedTree") != source_selection.get("selectedTree"):
            fail("root admission receipt verifiedTree does not bind source selection")
        if document.get("verifiedTree") != base_tree:
            fail("root admission receipt verifiedTree does not equal bundle base tree")
        if document.get("sourceSelectionBlobDigest") != sha256(source_raw):
            fail("root admission receipt sourceSelectionBlobDigest mismatch")
        if document.get("trustRootBlobDigest") != sha256(trust_raw):
            fail("root admission receipt trustRootBlobDigest mismatch")
        tool_blobs = document.get("toolBlobs")
        if not isinstance(tool_blobs, dict) or set(tool_blobs) != {
            "externalVerifier",
            "signingProvider",
        }:
            fail("root admission receipt toolBlobs fields mismatch")
        require_hex(
            tool_blobs.get("externalVerifier"),
            "root admission receipt externalVerifier",
        )
        require_hex(
            tool_blobs.get("signingProvider"),
            "root admission receipt signingProvider",
        )
        if not exact_design_already_present:
            fail(
                "W0.1 root predecessor cannot skip the required "
                "design-edge receipt"
            )
        selector = document.get("verifiedSelector")
        if not isinstance(selector, dict) or set(selector) != {
            "principalID",
            "keyID",
            "role",
            "schemaScope",
            "publicKeyFingerprintSHA256",
        }:
            fail("root admission receipt verifiedSelector fields mismatch")
        source_issued_at, source_issued_at_error = parse_utc_timestamp(
            source_selection.get("issuedAt"),
            "source selection issuedAt",
        )
        if source_issued_at_error is not None or source_issued_at is None:
            fail(
                source_issued_at_error
                or "source selection issuedAt is invalid"
            )
        resolved_selector = trusted_key(
            trust_root,
            signer=None,
            principal=source_selection.get("reviewerPrincipal"),
            role="source-selector",
            schema_scope="QinaoDualSpaceSourceSelectionV1",
            issued_at=source_issued_at,
        )
        if resolved_selector is None:
            fail("root admission receipt cannot resolve exact source selector")
        key, _public_key = resolved_selector
        expected_selector = {
            "principalID": key["principalID"],
            "keyID": key["keyID"],
            "role": key["role"],
            "schemaScope": key["schemaScope"],
            "publicKeyFingerprintSHA256": key[
                "publicKeyFingerprintSHA256"
            ],
        }
        if selector != expected_selector:
            fail("root admission receipt verifiedSelector mismatch")
    elif schema == "QinaoDesignEdgeAdmissionReceiptV1":
        if set(document) != DESIGN_RECEIPT_FIELDS:
            fail("design-edge admission receipt fields mismatch")
        role = "design-edge-admission-signer"
        if document.get("outcome") != "admitted":
            fail("design-edge admission receipt outcome must be admitted")
        if exact_design_already_present:
            fail(
                "W0.1 design-edge receipt is forbidden when the exact "
                "approved design is already present"
            )
        if (
            document.get("baseCommit") != source_selection.get("selectedHEAD")
            or document.get("baseTree") != source_selection.get("selectedTree")
            or document.get("approvedDesign")
            != source_selection.get("approvedDesign")
        ):
            fail("design-edge admission receipt source/root binding mismatch")
        if document.get("candidateTree") != base_tree:
            fail("design-edge candidateTree does not equal bundle base tree")
        candidate_entry = git_tree_blob_entry(
            root,
            document.get("candidateTree"),
            approved_path,
            "design-edge candidate approved design",
        )
        design_diff = git_tree_diff_entries(
            root,
            document.get("baseTree"),
            document.get("candidateTree"),
            "design-edge",
        )
        if (
            candidate_entry != approved_entry
            or len(design_diff) != 1
            or design_diff[0]["path"] != approved_path
            or design_diff[0]["status"] not in {"A", "M", "T"}
            or design_diff[0]["newMode"] != approved_entry[0]
            or design_diff[0]["newBlob"] != approved_entry[1]
        ):
            fail(
                "design-edge candidateTree must differ only by placing "
                "the exact approved design path/blob/mode"
            )
        require_hex(
            document.get("rootReceiptBlobDigest"),
            "design-edge rootReceiptBlobDigest",
        )
        tool_blobs = document.get("toolBlobs")
        if not isinstance(tool_blobs, dict) or set(tool_blobs) != {
            "externalVerifier",
            "signingProvider",
        }:
            fail("design-edge admission receipt toolBlobs fields mismatch")
        require_hex(
            tool_blobs.get("externalVerifier"),
            "design-edge admission receipt externalVerifier",
        )
        require_hex(
            tool_blobs.get("signingProvider"),
            "design-edge admission receipt signingProvider",
        )
    else:
        fail("W0.1 requires a root/design predecessor")
    errors = validate_signed_document(
        document,
        trust_root,
        expected_role=role,
        label="previous receipt",
        verification_time=verification_time,
    )
    if errors:
        fail("; ".join(errors))
    if document.get("repositoryIdentity") != trust_root.get("repositoryIdentity"):
        fail("previous receipt repositoryIdentity does not match trust root")
    validate_receipt_time_relationships(
        document,
        label="previous receipt",
        trust_root=trust_root,
        inputs=[("source selection", source_selection)],
    )


def validate_uniform_wave_receipt(
    document: dict,
    *,
    label: str,
    trust_root: dict,
    source_raw: bytes,
    trust_raw: bytes,
    expected_wave: str,
    expected_slice: str,
    expected_ordinal: int,
    verification_time: datetime,
) -> None:
    if set(document) != RUNTIME_RECEIPT_FIELDS:
        fail(f"{label} fields mismatch")
    if (
        document.get("schema") != "QinaoWaveAdmissionReceiptV1"
        or document.get("repositoryIdentity")
        != trust_root.get("repositoryIdentity")
        or document.get("wave") != expected_wave
        or document.get("waveSliceID") != expected_slice
        or document.get("sequenceOrdinal") != expected_ordinal
        or WAVE_SCHEDULE.get((expected_wave, expected_slice))
        != expected_ordinal
        or document.get("outcome") != "admitted"
    ):
        fail(f"{label} identity/schedule/outcome mismatch")
    if document.get("sourceSelectionBlobDigest") != sha256(source_raw):
        fail(f"{label} sourceSelectionBlobDigest mismatch")
    if document.get("trustRootBlobDigest") != sha256(trust_raw):
        fail(f"{label} trustRootBlobDigest mismatch")
    for field in (
        "approvedDesignBlob",
        "bundleBlobDigest",
        "previousReceiptBlobDigest",
        "productionDiffRoot",
        "sourceSelectionBlobDigest",
        "trustRootBlobDigest",
    ):
        require_hex(document.get(field), f"{label} {field}")
    for field in ("baseCommit", "baseTree", "candidateTree"):
        require_hex(document.get(field), f"{label} {field}", HEX_40)

    path_list = document.get("pathList")
    if (
        not isinstance(path_list, dict)
        or set(path_list) != {"root", "count"}
        or type(path_list.get("count")) is not int
        or path_list["count"] < 1
    ):
        fail(f"{label} pathList fields/count mismatch")
    require_hex(path_list.get("root"), f"{label} pathList.root")

    owner_ledger = document.get("ownerLedger")
    if (
        not isinstance(owner_ledger, dict)
        or set(owner_ledger) != OWNER_LEDGER_FIELDS
        or owner_ledger.get("path")
        != "docs/superpowers/specs/qinao-owner-ledger-v1.json"
    ):
        fail(f"{label} ownerLedger binding mismatch")
    require_hex(owner_ledger.get("blobDigest"), f"{label} ownerLedger.blobDigest")

    categories = document.get("categories")
    if not isinstance(categories, dict) or set(categories) != set(CATEGORIES):
        fail(f"{label} categories fields mismatch")
    for category in CATEGORIES:
        row = categories[category]
        if (
            not isinstance(row, dict)
            or set(row) != VERIFIED_CATEGORY_FIELDS
            or type(row.get("rowCount")) is not int
            or row["rowCount"] < 0
            or row.get("status") not in {"present", "notApplicable"}
        ):
            fail(f"{label} {category} category observation mismatch")
        require_hex(row.get("blobDigest"), f"{label} {category} blobDigest")
        require_hex(
            row.get("reviewedRowsRoot"),
            f"{label} {category} reviewedRowsRoot",
        )

    evidence = document.get("evidencePrerequisites")
    if expected_wave == "W5" and expected_ordinal == 1:
        if (
            not isinstance(evidence, list)
            or len(evidence) != 1
            or not isinstance(evidence[0], dict)
            or set(evidence[0]) != VERIFIED_K4_EVIDENCE_FIELDS
        ):
            fail(f"{label} W5 K4 evidence observation mismatch")
        row = evidence[0]
        if (
            row.get("name") != "k4-ios27-platform-spike"
            or row.get("path")
            != "docs/superpowers/evidence/qinao-k4-ios27-platform-spike.json"
            or row.get("schema") != "QinaoK4IOS27PlatformSpikeV1"
            or row.get("requiredStatus") != "supportedExactProfile"
            or row.get("verifiedStatus") != row.get("requiredStatus")
            or row.get("verifiedProfileDigest")
            != row.get("requiredProfileDigest")
        ):
            fail(f"{label} W5 K4 evidence observation mismatch")
        for field in (
            "blobDigest",
            "requiredProfileDigest",
            "verifiedProfileDigest",
        ):
            require_hex(row.get(field), f"{label} W5 K4 {field}")
    elif evidence != []:
        fail(f"{label} evidencePrerequisites is not scheduled")

    external = document.get("externalPrerequisites")
    if expected_wave == "W6" and expected_ordinal in {7, 8}:
        if (
            not isinstance(external, list)
            or len(external) != 1
            or not isinstance(external[0], dict)
            or set(external[0]) != VERIFIED_EXTERNAL_FIELDS
        ):
            fail(f"{label} runtime-chain external observation mismatch")
        row = external[0]
        if (
            row.get("name") != "runtime-receipt-chain"
            or row.get("schema") != "QinaoW6RuntimeReceiptChainV1"
            or row.get("requiredOutcome") != "accepted"
            or row.get("verifiedOutcome") != "accepted"
        ):
            fail(f"{label} runtime-chain external observation mismatch")
        require_hex(
            row.get("blobDigest"),
            f"{label} runtime-chain blobDigest",
        )
    elif external != []:
        fail(f"{label} externalPrerequisites is not scheduled")
    validate_frozen_schema_digests(
        document.get("frozenSchemaDigests"),
        wave=expected_wave,
        sequence_ordinal=expected_ordinal,
    )

    tool_blobs = document.get("toolBlobs")
    if not isinstance(tool_blobs, dict) or set(tool_blobs) != TOOL_BLOBS_FIELDS:
        fail(f"{label} toolBlobs fields mismatch")
    for field in (
        "bundleReviewSigningProvider",
        "externalVerifier",
        "waveAdmissionSigningProvider",
    ):
        require_hex(tool_blobs.get(field), f"{label} toolBlobs.{field}")
    for field, fixed_path in (
        ("ownerLedgerChecker", "scripts/check_qinao_owner_ledger.py"),
        ("repositoryRunner", "scripts/run_qinao_wave_admission.py"),
    ):
        binding = tool_blobs.get(field)
        if (
            not isinstance(binding, dict)
            or set(binding) != LOCATED_TOOL_FIELDS
            or binding.get("path") != fixed_path
        ):
            fail(f"{label} toolBlobs.{field} binding mismatch")
        require_hex(binding.get("blobDigest"), f"{label} toolBlobs.{field}")

    errors = validate_signed_document(
        document,
        trust_root,
        expected_role="wave-admission-signer",
        expected_schema_scope="QinaoWaveAdmissionReceiptV1",
        label=label,
        verification_time=verification_time,
    )
    if errors:
        fail("; ".join(errors))
    validate_receipt_time_relationships(
        document,
        label=label,
        trust_root=trust_root,
        inputs=[],
    )


def validate_prior_admission_receipts(
    arguments: list[str],
    runtime_entry_argument: Path | None,
    bundle: dict,
    *,
    root: Path,
    reserved_bindings: list[tuple[Path, tuple[int, int]]],
    trust_root: dict,
    source_selection: dict,
    source_raw: bytes,
    trust_raw: bytes,
    previous_raw: bytes,
    signed_documents: list[tuple[str, dict]],
    verification_time: datetime,
) -> tuple[
    list[dict],
    list[dict],
    list[tuple[Path, tuple[int, int]]],
    tuple[bytes, dict] | None,
]:
    is_w6_6 = (
        bundle.get("wave") == "W6"
        and bundle.get("sequenceOrdinal") == 6
        and bundle.get("waveSliceID") == RUNTIME_SLICE_IDS[5]
    )
    is_w6_chain_consumer = (
        bundle.get("wave") == "W6"
        and bundle.get("sequenceOrdinal") in {7, 8}
        and bundle.get("waveSliceID")
        in {"w6.apple-lab", "w6.certification"}
    )
    if not is_w6_6 and not is_w6_chain_consumer:
        if arguments:
            fail("--prior-admission-receipt is forbidden outside W6.6")
        if runtime_entry_argument is not None:
            fail("--runtime-entry-predecessor is forbidden outside W6.6")
        return [], [], [], None
    if is_w6_chain_consumer and arguments:
        fail("--prior-admission-receipt is forbidden outside W6.6")
    if runtime_entry_argument is None:
        fail("W6.6/W6.7/W6.8 requires --runtime-entry-predecessor")

    parsed: dict[str, Path] = {}
    for argument in arguments:
        wave_slice_id, separator, path_value = argument.partition("=")
        if (
            not separator
            or wave_slice_id not in RUNTIME_SLICE_IDS[:5]
            or not path_value
            or wave_slice_id in parsed
        ):
            fail(
                "--prior-admission-receipt must provide each unique "
                "W6.1–W6.5 WAVE_SLICE_ID=PATH"
            )
        parsed[wave_slice_id] = Path(path_value)
    if is_w6_6 and list(sorted(parsed, key=RUNTIME_SLICE_IDS.index)) != list(
        RUNTIME_SLICE_IDS[:5]
    ):
        fail("W6.6 requires exactly the five W6.1–W6.5 prior receipts")
    if is_w6_chain_consumer and parsed:
        fail("--prior-admission-receipt is forbidden outside W6.6")

    observed_bindings: list[tuple[Path, tuple[int, int]]] = []

    def read_distinct(path_argument: Path, label: str) -> tuple[bytes, Path]:
        path, raw, identity = external_file_bytes(path_argument, root, label)
        if any(
            path == prior_path or identity == prior_identity
            for prior_path, prior_identity in [
                *reserved_bindings,
                *observed_bindings,
            ]
        ):
            fail("external input paths/device-inode pairs must be distinct")
        observed_bindings.append((path, identity))
        return raw, path

    entry_raw, _entry_path = read_distinct(
        runtime_entry_argument,
        "runtime entry predecessor",
    )
    entry_receipt = load_json_bytes(entry_raw, "runtime entry predecessor")
    validate_uniform_wave_receipt(
        entry_receipt,
        label="runtime entry predecessor",
        trust_root=trust_root,
        source_raw=source_raw,
        trust_raw=trust_raw,
        expected_wave="W5",
        expected_slice="w5.inspection-publication-apple",
        expected_ordinal=1,
        verification_time=verification_time,
    )
    validate_receipt_time_relationships(
        entry_receipt,
        label="runtime entry predecessor",
        trust_root=trust_root,
        inputs=[("source selection", source_selection)],
    )
    signed_documents.append(("runtime entry predecessor", entry_receipt))
    entry_observation = {
        "schema": entry_receipt["schema"],
        "blobDigest": sha256(entry_raw),
        "wave": entry_receipt["wave"],
        "waveSliceID": entry_receipt["waveSliceID"],
        "sequenceOrdinal": entry_receipt["sequenceOrdinal"],
        "candidateTree": entry_receipt["candidateTree"],
        "outcome": entry_receipt["outcome"],
    }
    if set(entry_observation) != RUNTIME_ENTRY_PREDECESSOR_FIELDS:
        fail("internal runtime entry predecessor observation drifted")
    if is_w6_chain_consumer:
        return [], [], observed_bindings, (entry_raw, entry_receipt)

    requirements = bundle["priorAdmissionReceipts"]
    observations: list[dict] = []
    prior_raws: list[bytes] = []
    prior_receipts: list[dict] = []
    for ordinal, requirement in enumerate(requirements, start=1):
        slice_id = RUNTIME_SLICE_IDS[ordinal - 1]
        raw, _path = read_distinct(
            parsed[slice_id],
            f"prior admission receipt {slice_id}",
        )
        receipt = load_json_bytes(raw, f"prior admission receipt {slice_id}")
        validate_uniform_wave_receipt(
            receipt,
            label=f"prior admission receipt {slice_id}",
            trust_root=trust_root,
            source_raw=source_raw,
            trust_raw=trust_raw,
            expected_wave="W6",
            expected_slice=slice_id,
            expected_ordinal=ordinal,
            verification_time=verification_time,
        )
        signed_documents.append(
            (f"prior admission receipt {slice_id}", receipt)
        )
        if sha256(raw) != requirement["receiptBlobDigest"]:
            fail(f"prior admission receipt {slice_id} blob digest mismatch")
        predecessor_raw = entry_raw if ordinal == 1 else prior_raws[-1]
        predecessor_receipt = (
            entry_receipt if ordinal == 1 else prior_receipts[-1]
        )
        if (
            receipt["previousReceiptBlobDigest"] != sha256(predecessor_raw)
            or receipt["baseTree"] != predecessor_receipt["candidateTree"]
        ):
            fail(f"prior admission receipt {slice_id} continuity mismatch")
        validate_receipt_time_relationships(
            receipt,
            label=f"prior admission receipt {slice_id}",
            trust_root=trust_root,
            inputs=[
                ("source selection", source_selection),
                (
                    "immediate predecessor",
                    predecessor_receipt,
                ),
            ],
        )
        observation = {
            **requirement,
            "baseTree": receipt["baseTree"],
            "candidateTree": receipt["candidateTree"],
            "previousReceiptBlobDigest": receipt[
                "previousReceiptBlobDigest"
            ],
            "outcome": receipt["outcome"],
        }
        if set(observation) != PRIOR_ADMISSION_OBSERVATION_FIELDS:
            fail("internal prior admission observation drifted")
        observations.append(observation)
        prior_raws.append(raw)
        prior_receipts.append(receipt)

    if previous_raw != prior_raws[-1]:
        fail("W6.6 immediate predecessor does not equal prior receipt 05")
    return (
        observations,
        [entry_observation],
        observed_bindings,
        (entry_raw, entry_receipt),
    )


def parse_path_list(raw: bytes) -> list[str]:
    try:
        contents = raw.decode("utf-8")
    except UnicodeDecodeError as error:
        fail(f"path list must be UTF-8: {error}")
    if not contents.endswith("\n"):
        fail("path list must end with one newline")
    paths = contents.splitlines()
    if not paths:
        fail("path list must be non-empty")
    if any(not is_normalized_path(path) for path in paths):
        fail("path list contains a non-normalized repository path")
    if paths != sorted(paths):
        fail("path list must be lexicographically sorted")
    if len(paths) != len(set(paths)):
        fail("path list contains a duplicate path")
    return paths


def index_diff_paths(root: Path, base_tree: str, candidate_tree: str) -> set[str]:
    raw = run_git(
        root,
        [
            "diff",
            "--name-only",
            "--no-renames",
            "-z",
            base_tree,
            candidate_tree,
            "--",
        ],
    )
    try:
        return {
            value.decode("utf-8")
            for value in raw.split(b"\0")
            if value
        }
    except UnicodeDecodeError as error:
        fail(f"Git diff contains a non-UTF-8 path: {error}")


def ensure_index_candidate(root: Path, candidate_tree: str) -> None:
    if HEX_40.fullmatch(candidate_tree) is None:
        fail("--candidate-tree must be a canonical Git tree ID")
    object_type = run_git(
        root,
        ["cat-file", "-t", candidate_tree],
    ).decode("ascii", errors="replace").strip()
    if object_type != "tree":
        fail("--candidate-tree must name a Git tree")
    if not run_git(root, ["ls-tree", "-r", "--name-only", candidate_tree]).strip():
        fail("candidate tree is empty")
    if run_git(root, ["ls-files", "-u", "-z"]):
        fail("index contains unresolved entries")
    index_tree = run_git(root, ["write-tree"]).decode("ascii").strip()
    if index_tree != candidate_tree:
        fail(
            "index tree does not equal --candidate-tree: "
            f"index={index_tree} candidate={candidate_tree}"
        )


def ensure_worktree_matches_candidate(
    root: Path,
    candidate_tree: str,
    paths: list[str],
) -> None:
    drift = run_git(root, ["diff", "--name-only", "-z", "--", *paths])
    if drift:
        names = [
            name.decode("utf-8", errors="replace")
            for name in drift.split(b"\0")
            if name
        ]
        fail(f"unstaged governed path drift: {names!r}")
    all_tracked_drift = run_git(
        root,
        ["diff", "--name-only", "--no-renames", "-z", "--"],
    )
    all_untracked = run_git(
        root,
        ["ls-files", "--others", "--exclude-standard", "-z", "--"],
    )
    outside_wave_production_drift: list[str] = []
    for encoded_path in {
        value
        for value in (*all_tracked_drift.split(b"\0"), *all_untracked.split(b"\0"))
        if value
    }:
        try:
            relative_path = encoded_path.decode("utf-8")
        except UnicodeDecodeError:
            fail("worktree drift contains a non-UTF-8 path")
        if (
            relative_path not in paths
            and is_normalized_path(relative_path)
            and is_authority_diff_path(relative_path)
        ):
            outside_wave_production_drift.append(relative_path)
    if outside_wave_production_drift:
        fail(
            "unstaged production drift outside wave path list: "
            f"{sorted(outside_wave_production_drift)!r}"
        )
    for relative_path in paths:
        path = root / relative_path
        try:
            metadata = path.lstat()
        except OSError as error:
            fail(f"governed worktree path is missing: {relative_path}: {error}")
        if stat.S_ISLNK(metadata.st_mode) or not stat.S_ISREG(metadata.st_mode):
            fail(f"governed worktree path is not regular: {relative_path}")
        candidate_bytes = read_tree_file(
            root,
            candidate_tree,
            relative_path,
            "governed path",
        )
        if path.read_bytes() != candidate_bytes:
            fail(f"unstaged governed path bytes differ: {relative_path}")


def validate_runtime_receipt_chain(
    chain: dict,
    *,
    chain_raw: bytes,
    trust_root: dict,
    previous_receipt: dict,
    previous_raw: bytes,
    base_tree: str,
    bundle: dict,
    runtime_entry_context: tuple[bytes, dict] | None,
    source_selection: dict,
    source_raw: bytes,
    trust_raw: bytes,
    signed_documents: list[tuple[str, dict]],
    verification_time: datetime,
) -> None:
    if set(chain) != RUNTIME_CHAIN_FIELDS:
        fail("runtime receipt chain fields mismatch")
    if chain.get("schema") != "QinaoW6RuntimeReceiptChainV1":
        fail("runtime receipt chain schema must be QinaoW6RuntimeReceiptChainV1")
    if chain.get("repositoryIdentity") != trust_root.get("repositoryIdentity"):
        fail("runtime receipt chain repositoryIdentity does not match trust root")
    if chain.get("outcome") != "accepted":
        fail("runtime receipt chain outcome must be accepted")
    if runtime_entry_context is None:
        fail("runtime receipt chain requires the external entry predecessor")
    entry_predecessor_raw, entry_predecessor = runtime_entry_context
    if (
        chain.get("entryPredecessorReceiptBlobDigest")
        != sha256(entry_predecessor_raw)
        or chain.get("entryPredecessorCandidateTree")
        != entry_predecessor.get("candidateTree")
    ):
        fail("runtime receipt chain entry predecessor binding mismatch")
    require_hex(
        chain.get("entryPredecessorReceiptBlobDigest"),
        "runtime receipt chain entryPredecessorReceiptBlobDigest",
    )
    require_hex(
        chain.get("entryPredecessorCandidateTree"),
        "runtime receipt chain entryPredecessorCandidateTree",
        HEX_40,
    )
    tool_blobs = chain.get("toolBlobs")
    if not isinstance(tool_blobs, dict) or set(tool_blobs) != {
        "externalVerifier",
        "runtimeChainSigningProvider",
    }:
        fail("runtime receipt chain toolBlobs fields mismatch")
    require_hex(
        tool_blobs.get("externalVerifier"),
        "runtime receipt chain externalVerifier",
    )
    require_hex(
        tool_blobs.get("runtimeChainSigningProvider"),
        "runtime receipt chain runtimeChainSigningProvider",
    )
    errors = validate_signed_document(
        chain,
        trust_root,
        expected_role="runtime-chain-signer",
        label="runtime receipt chain",
        verification_time=verification_time,
    )
    if errors:
        fail("; ".join(errors))
    signed_documents.append(("runtime receipt chain", chain))

    entries = chain.get("entries")
    if not isinstance(entries, list) or len(entries) != len(RUNTIME_SLICE_IDS):
        fail("runtime receipt chain must contain exactly six entries")
    previous_embedded: dict | None = None
    previous_embedded_stored: bytes | None = None
    embedded_receipts: list[dict] = []
    for index, (entry, expected_slice) in enumerate(
        zip(entries, RUNTIME_SLICE_IDS, strict=True),
        start=1,
    ):
        if not isinstance(entry, dict) or set(entry) != {
            "waveSliceID",
            "sequenceOrdinal",
            "receipt",
            "receiptDigest",
        }:
            fail(f"runtime receipt chain entry {index} fields mismatch")
        receipt = entry.get("receipt")
        if not isinstance(receipt, dict):
            fail(f"runtime receipt chain entry {index} receipt is not embedded")
        if set(receipt) != RUNTIME_RECEIPT_FIELDS:
            fail(
                f"runtime receipt chain entry {index} receipt fields mismatch"
            )
        canonical_receipt = canonical_json_bytes(receipt)
        if entry.get("receiptDigest") != sha256(canonical_receipt):
            fail(
                f"runtime receipt chain entry {index} receiptDigest mismatch"
            )
        if (
            entry.get("waveSliceID") != expected_slice
            or entry.get("sequenceOrdinal") != index
        ):
            fail(f"runtime receipt chain entry {index} ID/ordinal mismatch")
        validate_uniform_wave_receipt(
            receipt,
            label=f"runtime receipt chain entry {index} receipt",
            trust_root=trust_root,
            source_raw=source_raw,
            trust_raw=trust_raw,
            expected_wave="W6",
            expected_slice=expected_slice,
            expected_ordinal=index,
            verification_time=verification_time,
        )
        signed_documents.append(
            (f"runtime receipt chain entry {index} receipt", receipt)
        )
        if index == 1:
            if (
                receipt.get("baseTree")
                != chain.get("entryPredecessorCandidateTree")
                or receipt.get("previousReceiptBlobDigest")
                != chain.get("entryPredecessorReceiptBlobDigest")
            ):
                fail("runtime receipt chain entry 01 predecessor mismatch")
        elif previous_embedded is not None and previous_embedded_stored is not None:
            if receipt.get("baseTree") != previous_embedded.get("candidateTree"):
                fail(
                    "runtime receipt chain predecessor candidate-tree "
                    f"continuity failed at entry {index}"
                )
            expected_predecessor = sha256(
                previous_embedded_stored
            )
            if (
                receipt.get("previousReceiptBlobDigest")
                != expected_predecessor
            ):
                fail(
                    "runtime receipt chain predecessor receipt continuity "
                    f"failed at entry {index}"
                )
        immediate_predecessor = (
            entry_predecessor if index == 1 else previous_embedded
        )
        assert immediate_predecessor is not None
        validate_receipt_time_relationships(
            receipt,
            label=f"runtime receipt chain entry {index} receipt",
            trust_root=trust_root,
            inputs=[
                ("source selection", source_selection),
                ("immediate predecessor", immediate_predecessor),
            ],
        )
        embedded_receipts.append(receipt)
        previous_embedded = receipt
        previous_embedded_stored = canonical_receipt + b"\n"

    assert previous_embedded is not None
    validate_receipt_time_relationships(
        chain,
        label="runtime receipt chain",
        trust_root=trust_root,
        inputs=[
            ("source selection", source_selection),
            ("runtime entry predecessor", entry_predecessor),
            *[
                (f"embedded receipt {index}", receipt)
                for index, receipt in enumerate(
                    embedded_receipts,
                    start=1,
                )
            ],
        ],
    )
    expected_head = chain.get("expectedHeadTree")
    if expected_head != previous_embedded.get("candidateTree"):
        fail("runtime receipt chain expected head tree does not equal entry 06")
    current_ordinal = bundle.get("sequenceOrdinal")
    if current_ordinal == 7:
        if expected_head != base_tree:
            fail(
                "runtime receipt chain expected head tree does not equal "
                "W6.7 bundle base"
            )
        embedded_stored = canonical_json_bytes(previous_embedded) + b"\n"
        if embedded_stored != previous_raw:
            fail(
                "runtime receipt chain entry 06 stored bytes do not exactly "
                "equal the captured W6.7 predecessor"
            )
        if (
            chain["entries"][5]["receiptDigest"]
            != sha256(canonical_json_bytes(previous_embedded))
        ):
            fail("runtime receipt chain entry 06 receiptDigest mismatch")
    elif current_ordinal == 8:
        previous_runtime_rows = previous_receipt.get(
            "externalPrerequisites"
        )
        matching_previous_rows = [
            row
            for row in previous_runtime_rows
            if isinstance(row, dict)
            and row.get("name") == "runtime-receipt-chain"
        ] if isinstance(previous_runtime_rows, list) else []
        current_runtime_rows = [
            row
            for row in bundle.get("externalPrerequisites", [])
            if isinstance(row, dict)
            and row.get("name") == "runtime-receipt-chain"
        ]
        captured_chain_digest = sha256(chain_raw)
        if (
            len(matching_previous_rows) != 1
            or len(current_runtime_rows) != 1
            or matching_previous_rows[0].get("blobDigest")
            != captured_chain_digest
            or current_runtime_rows[0].get("blobDigest")
            != captured_chain_digest
            or previous_receipt.get("wave") != "W6"
            or previous_receipt.get("waveSliceID") != "w6.apple-lab"
            or previous_receipt.get("sequenceOrdinal") != 7
            or previous_receipt.get("baseTree") != expected_head
            or previous_receipt.get("previousReceiptBlobDigest")
            != sha256(canonical_json_bytes(previous_embedded) + b"\n")
            or previous_receipt.get("candidateTree") != base_tree
        ):
            fail("W6.8 runtime-chain/W6.7 continuity mismatch")
    else:
        fail("runtime receipt chain is only valid for W6.7/W6.8")


def validate_external_prerequisites(
    arguments: list[str],
    bundle: dict,
    *,
    root: Path,
    reserved_bindings: list[tuple[Path, tuple[int, int]]],
    trust_root: dict,
    previous_receipt: dict,
    previous_raw: bytes,
    base_tree: str,
    runtime_entry_context: tuple[bytes, dict] | None,
    source_selection: dict,
    source_raw: bytes,
    trust_raw: bytes,
    signed_documents: list[tuple[str, dict]],
    verification_time: datetime,
) -> tuple[list[dict], list[tuple[Path, tuple[int, int]]]]:
    parsed: list[tuple[str, Path]] = []
    names: list[str] = []
    for argument in arguments:
        name, separator, path_value = argument.partition("=")
        if (
            not separator
            or not name
            or not path_value
            or re.fullmatch(r"[a-z0-9][a-z0-9.-]*", name) is None
        ):
            fail("--external-prerequisite must be normalized NAME=PATH")
        if name in names:
            fail(f"duplicate external prerequisite name: {name}")
        names.append(name)
        parsed.append((name, Path(path_value)))

    requirements = bundle.get("externalPrerequisites")
    if not isinstance(requirements, list):
        fail("bundle externalPrerequisites must be an array")
    if any(
        not isinstance(row, dict)
        or set(row) != EXTERNAL_REQUIREMENT_FIELDS
        for row in requirements
    ):
        fail("bundle external prerequisite fields mismatch")
    expected_names = [row["name"] for row in requirements]
    if expected_names != sorted(expected_names) or len(expected_names) != len(
        set(expected_names)
    ):
        fail(
            "bundle external prerequisite names must be unique and "
            "lexicographically sorted"
        )
    if set(names) != set(expected_names):
        fail(
            "external prerequisite names mismatch: "
            f"expected={expected_names!r} actual={names!r}"
        )

    by_name = dict(parsed)
    resolved_bindings: list[tuple[Path, tuple[int, int]]] = []
    normalized: list[dict] = []
    for requirement in requirements:
        name = requirement["name"]
        path, raw, identity = external_file_bytes(
            by_name[name],
            root,
            f"external prerequisite {name}",
        )
        if any(
            path == prior_path or identity == prior_identity
            for prior_path, prior_identity in [
                *reserved_bindings,
                *resolved_bindings,
            ]
        ):
            fail("external input paths/device-inode pairs must be distinct")
        resolved_bindings.append((path, identity))
        if requirement.get("blobDigest") != sha256(raw):
            fail(
                f"external prerequisite blob digest mismatch: {name}"
            )
        if name != "runtime-receipt-chain":
            fail(f"unknown external prerequisite name: {name}")
        if requirement.get("schema") != "QinaoW6RuntimeReceiptChainV1":
            fail(
                "runtime receipt chain requirement schema must be "
                "QinaoW6RuntimeReceiptChainV1"
            )
        if requirement.get("requiredOutcome") != "accepted":
            fail(
                "runtime receipt chain requirement outcome must be accepted"
            )
        chain = load_json_bytes(raw, "runtime receipt chain")
        validate_runtime_receipt_chain(
            chain,
            chain_raw=raw,
            trust_root=trust_root,
            previous_receipt=previous_receipt,
            previous_raw=previous_raw,
            base_tree=base_tree,
            bundle=bundle,
            runtime_entry_context=runtime_entry_context,
            source_selection=source_selection,
            source_raw=source_raw,
            trust_raw=trust_raw,
            signed_documents=signed_documents,
            verification_time=verification_time,
        )
        normalized.append(
            {
                **requirement,
                "verifiedOutcome": chain["outcome"],
            }
        )
    return normalized, resolved_bindings


def validate_candidate_evidence_prerequisites(
    requirements: list[dict],
    *,
    root: Path,
    candidate_tree: str,
    trust_root: dict,
    signed_documents: list[tuple[str, dict]],
    verification_time: datetime,
) -> list[dict]:
    verified: list[dict] = []
    for requirement in requirements:
        path = requirement["path"]
        raw = read_tree_file(
            root,
            candidate_tree,
            path,
            f"evidence prerequisite {requirement['name']}",
        )
        if sha256(raw) != requirement["blobDigest"]:
            fail(
                f"evidence prerequisite blob digest mismatch: "
                f"{requirement['name']}"
            )
        evidence = load_json_bytes(
            raw,
            f"evidence prerequisite {requirement['name']}",
        )
        if requirement["schema"] != "QinaoK4IOS27PlatformSpikeV1":
            fail(f"unknown evidence prerequisite schema: {requirement['schema']}")
        if set(evidence) != K4_EVIDENCE_FIELDS:
            fail("K4 evidence prerequisite fields mismatch")
        signature_errors = validate_signed_document(
            evidence,
            trust_root,
            expected_role="k4-evidence-signer",
            expected_schema_scope="QinaoK4IOS27PlatformSpikeV1",
            label="K4 evidence prerequisite",
            verification_time=verification_time,
        )
        if signature_errors:
            fail("; ".join(signature_errors))
        validate_k4_evidence_bindings(
            evidence,
            root=root,
            trust_root=trust_root,
        )
        signed_documents.append(("K4 evidence prerequisite", evidence))
        required_status = requirement["requiredStatus"]
        required_profile_digest = requirement["requiredProfileDigest"]
        if evidence.get("status") != required_status:
            fail("K4 evidence verifiedStatus does not equal requiredStatus")
        if evidence.get("supportedProfileDigest") != required_profile_digest:
            fail(
                "K4 evidence verifiedProfileDigest does not equal "
                "requiredProfileDigest"
            )
        verified.append(
            {
                **requirement,
                "verifiedStatus": evidence["status"],
                "verifiedProfileDigest": evidence["supportedProfileDigest"],
            }
        )
    return verified


def derive_report(
    args: argparse.Namespace,
    *,
    verification_time: datetime,
    signed_documents: list[tuple[str, dict]] | None = None,
) -> tuple[Path, dict, dict, list[tuple[Path, tuple[int, int]]]]:
    operation_signed_documents = (
        [] if signed_documents is None else signed_documents
    )
    root = ensure_repository(args.root)
    ensure_index_candidate(root, args.candidate_tree)

    source_path, source_raw, source_identity = external_file_bytes(
        args.source_selection,
        root,
        "source selection",
    )
    trust_path, trust_raw, trust_identity = external_file_bytes(
        args.trust_root,
        root,
        "trust root",
    )
    previous_path, previous_raw, previous_identity = external_file_bytes(
        args.previous_receipt,
        root,
        "previous receipt",
    )
    input_bindings = [
        (source_path, source_identity),
        (trust_path, trust_identity),
        (previous_path, previous_identity),
    ]
    if len({path for path, _identity in input_bindings}) != len(
        input_bindings
    ) or len({identity for _path, identity in input_bindings}) != len(
        input_bindings
    ):
        fail("external input paths/device-inode pairs must be distinct")

    trust_root = load_json_bytes(trust_raw, "trust root")
    trust_errors = validate_trust_root(
        trust_root,
        verification_time=verification_time,
    )
    if trust_errors:
        fail("; ".join(trust_errors))
    source_selection = load_json_bytes(source_raw, "source selection")
    source_errors = validate_source_selection(
        source_selection,
        trust_root,
        root=root,
        verification_time=verification_time,
    )
    if source_errors:
        fail("; ".join(source_errors))
    operation_signed_documents.append(("source selection", source_selection))
    previous_receipt = load_json_bytes(previous_raw, "previous receipt")

    _bundle_path, bundle_relative = repository_file_path(
        args.bundle,
        root,
        "bundle",
    )
    bundle_raw = read_tree_file(
        root,
        args.candidate_tree,
        bundle_relative,
        "bundle",
    )
    bundle = load_json_bytes(bundle_raw, "bundle")
    validate_bundle(
        bundle,
        trust_root,
        verification_time=verification_time,
    )
    operation_signed_documents.append(("bundle", bundle))

    base_commit = bundle["baseCommit"]
    base_tree = bundle["baseTree"]
    if (
        run_git(root, ["cat-file", "-t", base_commit])
        .decode("ascii", errors="replace")
        .strip()
        != "commit"
    ):
        fail("bundle baseCommit must name a Git commit object")
    resolved_base = run_git(
        root,
        ["rev-parse", f"{base_commit}^{{tree}}"],
    ).decode("ascii").strip()
    if resolved_base != base_tree:
        fail("bundle baseCommit does not resolve to bundle baseTree")
    head_tree = run_git(
        root,
        ["rev-parse", "HEAD^{tree}"],
    ).decode("ascii").strip()
    if head_tree != base_tree:
        fail("current HEAD tree does not equal bundle base tree")
    if bundle["requiredPredecessorCandidateTree"] != base_tree:
        fail("bundle predecessor candidate tree does not equal bundle base tree")
    if bundle["requiredPredecessorReceiptBlob"] != sha256(previous_raw):
        fail("bundle predecessor receipt blob digest mismatch")
    approved_design = source_selection.get("approvedDesign")
    if (
        not isinstance(approved_design, dict)
        or bundle["approvedDesignBlob"] != approved_design.get("sha256")
    ):
        fail("bundle approvedDesignBlob does not match source selection")
    validate_previous_receipt(
        previous_receipt,
        trust_root,
        source_selection,
        base_tree,
        root=root,
        source_raw=source_raw,
        trust_raw=trust_raw,
        current_wave=bundle["wave"],
        current_slice=bundle["waveSliceID"],
        current_ordinal=bundle["sequenceOrdinal"],
        verification_time=verification_time,
    )
    operation_signed_documents.append(("previous receipt", previous_receipt))
    (
        prior_admission_receipts,
        runtime_entry_predecessors,
        prior_receipt_bindings,
        runtime_entry_context,
    ) = validate_prior_admission_receipts(
        args.prior_admission_receipt,
        args.runtime_entry_predecessor,
        bundle,
        root=root,
        reserved_bindings=input_bindings,
        trust_root=trust_root,
        source_selection=source_selection,
        source_raw=source_raw,
        trust_raw=trust_raw,
        previous_raw=previous_raw,
        signed_documents=operation_signed_documents,
        verification_time=verification_time,
    )

    path_list_binding = bundle.get("pathList")
    if not isinstance(path_list_binding, dict) or set(path_list_binding) != {
        "blobDigest",
        "count",
        "path",
        "root",
    }:
        fail("bundle pathList binding fields mismatch")
    path_list_relative = path_list_binding.get("path")
    path_list_raw = read_tree_file(
        root,
        args.candidate_tree,
        path_list_relative,
        "path list",
    )
    paths = parse_path_list(path_list_raw)
    diff_paths = index_diff_paths(root, base_tree, args.candidate_tree)
    listed_paths = set(paths)
    if listed_paths != diff_paths:
        fail(
            "path-list/index-diff mismatch: "
            f"missingFromList={sorted(diff_paths - listed_paths)!r}, "
            f"missingFromDiff={sorted(listed_paths - diff_paths)!r}"
        )
    if path_list_binding["blobDigest"] != sha256(path_list_raw):
        fail("path-list blob digest mismatch")
    if path_list_binding["root"] != sha256(path_list_raw):
        fail("path-list root mismatch")
    if path_list_binding["count"] != len(paths):
        fail("path-list count mismatch")

    owner_ledger_binding = bundle["ownerLedger"]
    owner_ledger_relative = owner_ledger_binding["path"]
    checker_binding = bundle["toolBlobs"]["ownerLedgerChecker"]
    checker_relative = checker_binding["path"]
    runner_binding = bundle["toolBlobs"]["repositoryRunner"]
    runner_relative = runner_binding["path"]
    required_paths = {
        bundle_relative,
        path_list_relative,
    }
    categories = bundle.get("categories")
    if not isinstance(categories, dict) or set(categories) != set(CATEGORIES):
        fail("bundle categories must contain adapter/create/extension/fixture")
    category_report: dict[str, dict] = {}
    category_paths: dict[str, str] = {}
    category_raws: dict[str, bytes] = {}
    for category in CATEGORIES:
        binding = categories[category]
        if not isinstance(binding, dict) or set(binding) != {"blobDigest", "path"}:
            fail(f"bundle {category} category binding fields mismatch")
        relative_path = binding.get("path")
        raw = read_tree_file(
            root,
            args.candidate_tree,
            relative_path,
            f"{category} category",
        )
        if binding.get("blobDigest") != sha256(raw):
            fail(f"{category} category blob digest mismatch")
        document = load_json_bytes(raw, f"{category} category")
        if set(document) != {
            "schema",
            "repositoryIdentity",
            "wave",
            "waveSliceID",
            "sequenceOrdinal",
            "category",
            "status",
            "baseTree",
            "approvedDesignBlob",
            "productionDiffRoot",
            "reviewedRows",
            "reviewedRowsRoot",
            "anchors",
            "reason",
            "issuedAt",
            "expiresAt",
            "nonce",
            "signer",
            "role",
            "signatureAlgorithm",
            "signature",
        }:
            fail(f"{category} category fields mismatch")
        if (
            document.get("schema") != "QinaoWaveCategoryEvidenceV1"
            or document.get("repositoryIdentity") != bundle["repositoryIdentity"]
            or document.get("wave") != bundle["wave"]
            or document.get("waveSliceID") != bundle["waveSliceID"]
            or document.get("sequenceOrdinal") != bundle["sequenceOrdinal"]
            or document.get("category") != category
            or document.get("baseTree") != base_tree
            or document.get("approvedDesignBlob") != bundle["approvedDesignBlob"]
            or document.get("productionDiffRoot") != bundle["productionDiffRoot"]
        ):
            fail(f"{category} category does not equal containing bundle")
        category_signature_errors = validate_signed_document(
            document,
            trust_root,
            expected_role="wave-bundle-reviewer",
            expected_schema_scope="QinaoWaveCategoryEvidenceV1",
            label=f"{category} category",
            verification_time=verification_time,
        )
        if category_signature_errors:
            fail("; ".join(category_signature_errors))
        operation_signed_documents.append(
            (f"{category} category", document)
        )
        reviewed_rows = document.get("reviewedRows", [])
        if not isinstance(reviewed_rows, list):
            fail(f"{category} category reviewedRows must be an array")
        expected_rows_root = sha256(
            canonical_json_bytes(
                sorted(reviewed_rows, key=canonical_json_bytes)
            )
        )
        if document.get("reviewedRowsRoot") != expected_rows_root:
            fail(f"{category} category reviewedRowsRoot mismatch")
        category_report[category] = {
            "blobDigest": sha256(raw),
            "reviewedRowsRoot": expected_rows_root,
            "rowCount": len(reviewed_rows),
            "status": document.get("status"),
        }
        category_paths[category] = relative_path
        category_raws[category] = raw
        required_paths.add(relative_path)
    for requirement in bundle["evidencePrerequisites"]:
        required_paths.add(requirement["path"])
    if not all(isinstance(path, str) for path in required_paths):
        fail("bundle contains a non-string required path")
    missing_required = sorted(required_paths - listed_paths)
    if missing_required:
        fail(f"required bundle paths are not named by path list: {missing_required!r}")

    checker_raw = read_tree_file(
        root,
        args.candidate_tree,
        checker_relative,
        "owner-ledger checker",
        expected_mode="100644",
    )
    runner_raw = read_tree_file(
        root,
        args.candidate_tree,
        runner_relative,
        "repository runner",
        expected_mode="100644",
    )
    owner_ledger_raw = read_tree_file(
        root,
        args.candidate_tree,
        owner_ledger_relative,
        "owner ledger",
        expected_mode="100644",
    )
    tool_blobs = bundle.get("toolBlobs")
    if checker_binding["blobDigest"] != sha256(checker_raw):
        fail("owner-ledger checker blob digest mismatch")
    if runner_binding["blobDigest"] != sha256(runner_raw):
        fail("repository runner blob digest mismatch")
    if owner_ledger_binding["blobDigest"] != sha256(owner_ledger_raw):
        fail("owner ledger blob digest mismatch")

    pinned_runner_value = os.environ.get("QINAO_PINNED_REPOSITORY_RUNNER")
    if not pinned_runner_value:
        fail("QINAO_PINNED_REPOSITORY_RUNNER is required")
    runner_descriptor, pinned_runner_bytes, _runner_file_binding = (
        open_bound_checker(
            Path(pinned_runner_value),
            "repository runner",
        )
    )
    try:
        if pinned_runner_bytes != runner_raw:
            fail(
                "pinned repository runner bytes do not equal the "
                "candidate-tree runner binding"
            )
    finally:
        os.close(runner_descriptor)

    checker_executable = root / checker_relative
    pinned_checker_value = os.environ.get("QINAO_PINNED_OWNER_LEDGER_CHECKER")
    if pinned_checker_value is not None:
        if not pinned_checker_value:
            fail("QINAO_PINNED_OWNER_LEDGER_CHECKER must not be empty")
        checker_executable = Path(pinned_checker_value)

    external_prerequisites, external_paths = validate_external_prerequisites(
        args.external_prerequisite,
        bundle,
        root=root,
        reserved_bindings=[*input_bindings, *prior_receipt_bindings],
        trust_root=trust_root,
        previous_receipt=previous_receipt,
        previous_raw=previous_raw,
        base_tree=base_tree,
        runtime_entry_context=runtime_entry_context,
        source_selection=source_selection,
        source_raw=source_raw,
        trust_raw=trust_raw,
        signed_documents=operation_signed_documents,
        verification_time=verification_time,
    )
    evidence_prerequisites = validate_candidate_evidence_prerequisites(
        bundle["evidencePrerequisites"],
        root=root,
        candidate_tree=args.candidate_tree,
        trust_root=trust_root,
        signed_documents=operation_signed_documents,
        verification_time=verification_time,
    )
    ensure_worktree_matches_candidate(root, args.candidate_tree, paths)

    checker_descriptor, checker_bytes, checker_binding = open_bound_checker(
        checker_executable,
        "owner-ledger checker",
    )
    if checker_bytes != checker_raw:
        os.close(checker_descriptor)
        fail(
            "pinned owner-ledger checker bytes do not equal the "
            "candidate-tree checker binding"
        )
    checker_input_descriptors = {
        "ledger": read_only_snapshot_descriptor(
            owner_ledger_raw,
            "owner ledger",
        ),
        "source": read_only_snapshot_descriptor(
            source_raw,
            "source selection",
        ),
        "trust": read_only_snapshot_descriptor(
            trust_raw,
            "trust root",
        ),
        **{
            category: read_only_snapshot_descriptor(
                category_raws[category],
                f"{category} category",
            )
            for category in CATEGORIES
        },
    }
    checker_command = [
        sys.executable,
        f"/dev/fd/{checker_descriptor}",
        "--root",
        str(root),
        "--ledger",
        f"/dev/fd/{checker_input_descriptors['ledger']}",
        "--source-selection",
        f"/dev/fd/{checker_input_descriptors['source']}",
        "--trust-root",
        f"/dev/fd/{checker_input_descriptors['trust']}",
        "--base-tree",
        base_tree,
        "--candidate-tree",
        args.candidate_tree,
        "--wave",
        bundle["wave"],
        "--wave-slice-id",
        bundle["waveSliceID"],
        "--sequence-ordinal",
        str(bundle["sequenceOrdinal"]),
        "--create-manifest-or-disposition",
        f"/dev/fd/{checker_input_descriptors['create']}",
        "--extension-manifest-or-disposition",
        f"/dev/fd/{checker_input_descriptors['extension']}",
        "--adapter-manifest-or-disposition",
        f"/dev/fd/{checker_input_descriptors['adapter']}",
        "--fixture-set-or-disposition",
        f"/dev/fd/{checker_input_descriptors['fixture']}",
    ]
    try:
        try:
            completed = subprocess.run(
                checker_command,
                cwd=root,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                check=False,
                timeout=OWNER_LEDGER_CHECKER_TIMEOUT_SECONDS,
                pass_fds=(
                    checker_descriptor,
                    *checker_input_descriptors.values(),
                ),
            )
        except (OSError, subprocess.TimeoutExpired):
            fail("owner-ledger subgate was unavailable or timed out")
        after_checker = os.fstat(checker_descriptor)
        if checker_binding != (
            after_checker.st_dev,
            after_checker.st_ino,
            after_checker.st_mode,
            after_checker.st_nlink,
            after_checker.st_size,
            after_checker.st_mtime_ns,
            after_checker.st_ctime_ns,
        ):
            fail("owner-ledger checker changed while its bound descriptor executed")
    finally:
        os.close(checker_descriptor)
        for input_descriptor in checker_input_descriptors.values():
            os.close(input_descriptor)
    if completed.returncode != 0:
        diagnostic = completed.stderr.strip() or completed.stdout.strip()
        fail(
            "owner-ledger subgate failed "
            f"with exit {completed.returncode}: {diagnostic}"
        )

    report = {
        "schema": "QinaoWaveCandidateReportV1",
        "repositoryIdentity": bundle["repositoryIdentity"],
        "wave": bundle["wave"],
        "waveSliceID": bundle["waveSliceID"],
        "sequenceOrdinal": bundle["sequenceOrdinal"],
        "baseCommit": base_commit,
        "baseTree": base_tree,
        "candidateTree": args.candidate_tree,
        "bundleBlobDigest": sha256(bundle_raw),
        "sourceSelectionBlobDigest": sha256(source_raw),
        "trustRootBlobDigest": sha256(trust_raw),
        "previousReceiptBlobDigest": sha256(previous_raw),
        "approvedDesignBlob": bundle["approvedDesignBlob"],
        "productionDiffRoot": bundle["productionDiffRoot"],
        "priorAdmissionReceipts": prior_admission_receipts,
        "runtimeEntryPredecessors": runtime_entry_predecessors,
        "pathList": {
            "root": path_list_binding["root"],
            "count": path_list_binding["count"],
        },
        "ownerLedger": owner_ledger_binding,
        "categories": category_report,
        "evidencePrerequisites": evidence_prerequisites,
        "externalPrerequisites": external_prerequisites,
        "frozenSchemaDigests": bundle["frozenSchemaDigests"],
        "toolBlobs": tool_blobs,
        "admissionStatus": "unadmitted",
    }
    validate_operation_nonce_collisions(operation_signed_documents)
    return root, report, trust_root, [
        *input_bindings,
        *prior_receipt_bindings,
        *external_paths,
    ]


def validate_output_path(path_argument: Path, root: Path) -> Path:
    try:
        path_argument.lstat()
    except FileNotFoundError:
        pass
    except OSError as error:
        fail(f"unsigned report path cannot be inspected: {error}")
    else:
        fail("unsigned report already exists")
    try:
        parent = path_argument.parent.resolve(strict=True)
    except OSError as error:
        fail(f"unsigned report parent cannot be resolved: {error}")
    if not parent.is_dir():
        fail("unsigned report parent must be a directory")
    path = parent / path_argument.name
    if path_is_within(path, root):
        fail("unsigned report must be outside the repository")
    return path


def write_exclusive_report(path: Path, document: dict) -> None:
    raw = canonical_json_bytes(document) + b"\n"
    descriptor: int | None = None
    created = False
    try:
        descriptor = os.open(
            path,
            os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW,
            0o600,
        )
        created = True
        offset = 0
        while offset < len(raw):
            written = os.write(descriptor, raw[offset:])
            if written <= 0:
                raise OSError("short write")
            offset += written
        os.fsync(descriptor)
        os.close(descriptor)
        descriptor = None
        directory_descriptor = os.open(path.parent, os.O_RDONLY)
        try:
            os.fsync(directory_descriptor)
        finally:
            os.close(directory_descriptor)
    except FileExistsError:
        fail("unsigned report already exists")
    except OSError as error:
        if descriptor is not None:
            os.close(descriptor)
        if created:
            try:
                path.unlink()
            except OSError:
                pass
        fail(f"unsigned report could not be written durably: {error}")


def verify_receipt(
    args: argparse.Namespace,
    *,
    root: Path,
    report: dict,
    trust_root: dict,
    reserved_paths: list[tuple[Path, tuple[int, int]]],
    verification_time: datetime,
    signed_documents: list[tuple[str, dict]] | None = None,
) -> None:
    operation_signed_documents = (
        [] if signed_documents is None else signed_documents
    )
    receipt_path, receipt_raw, receipt_identity = external_file_bytes(
        args.receipt,
        root,
        "receipt",
    )
    if any(
        receipt_path == path or receipt_identity == identity
        for path, identity in reserved_paths
    ):
        fail("external input paths/device-inode pairs must be distinct")
    receipt = load_json_bytes(receipt_raw, "receipt")
    if set(receipt) != RUNTIME_RECEIPT_FIELDS:
        fail(
            "receipt fields mismatch: "
            f"missing={sorted(RUNTIME_RECEIPT_FIELDS - set(receipt))!r}, "
            f"extra={sorted(set(receipt) - RUNTIME_RECEIPT_FIELDS)!r}"
        )
    if receipt.get("schema") != "QinaoWaveAdmissionReceiptV1":
        fail("receipt schema must be QinaoWaveAdmissionReceiptV1")
    if receipt.get("outcome") != "admitted":
        fail("receipt outcome must be admitted")
    errors = validate_signed_document(
        receipt,
        trust_root,
        expected_role="wave-admission-signer",
        label="receipt",
        verification_time=verification_time,
    )
    if errors:
        fail("; ".join(errors))
    binding_fields = (
        RUNTIME_RECEIPT_FIELDS
        - {
            "expiresAt",
            "issuedAt",
            "nonce",
            "outcome",
            "role",
            "schema",
            "signature",
            "signatureAlgorithm",
            "signer",
            "verifiedAt",
        }
    )
    for field in sorted(binding_fields):
        if receipt.get(field) != report.get(field):
            fail(f"receipt binding {field} does not match derived candidate")
    validate_receipt_time_relationships(
        receipt,
        label="receipt",
        trust_root=trust_root,
        inputs=operation_signed_documents,
    )
    operation_signed_documents.append(("receipt", receipt))
    validate_operation_nonce_collisions(operation_signed_documents)


def main() -> int:
    args = parse_args()
    verification_time = datetime.now(timezone.utc)
    try:
        signed_documents: list[tuple[str, dict]] = []
        root, report, trust_root, reserved_paths = derive_report(
            args,
            verification_time=verification_time,
            signed_documents=signed_documents,
        )
        if args.mode == "report":
            output = validate_output_path(args.unsigned_report, root)
            write_exclusive_report(output, report)
            message = "qinao wave candidate report: PASS (unsigned, unadmitted)"
        else:
            verify_receipt(
                args,
                root=root,
                report=report,
                trust_root=trust_root,
                reserved_paths=reserved_paths,
                verification_time=verification_time,
                signed_documents=signed_documents,
            )
            message = "qinao wave admission receipt: PASS (verified only)"
    except GateError as error:
        print(f"qinao wave admission gate failed: {error}", file=sys.stderr)
        return 1
    print(message)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
