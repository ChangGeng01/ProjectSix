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
from pathlib import Path, PurePosixPath

from check_qinao_owner_ledger import (
    DuplicateJSONKeyError,
    canonical_json_bytes,
    reject_duplicate_json_keys,
    validate_signed_document,
    validate_source_selection,
    validate_trust_root,
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
    "issuedAt",
    "nonce",
    "ownerLedgerPath",
    "pathList",
    "productionDiffRoot",
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
RUNTIME_CHAIN_FIELDS = {
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
}
RUNTIME_RECEIPT_FIELDS = {
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
    "wave",
    "waveSliceID",
}
RUNTIME_SLICE_IDS = (
    "w6.runtime.observation-values",
    "w6.semantic.audit-schema",
    "w6.runtime.audit-envelope-freeze",
    "w6.semantic.coordinator-behavior",
    "w6.runtime.integration-population",
    "w6.runtime.engine-cutover",
)


class GateError(RuntimeError):
    """One fail-closed admission-gate diagnostic."""


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
    completed = subprocess.run(
        ["git", *arguments],
        cwd=root,
        input=input_bytes,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
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


def external_file_bytes(path_argument: Path, root: Path, label: str) -> tuple[Path, bytes]:
    try:
        metadata = path_argument.lstat()
    except OSError as error:
        fail(f"{label} does not exist: {error}")
    if stat.S_ISLNK(metadata.st_mode) or not stat.S_ISREG(metadata.st_mode):
        fail(f"{label} must be a regular file, not a symlink")
    if stat.S_IMODE(metadata.st_mode) != 0o600:
        fail(f"{label} must have mode 0600")
    try:
        path = path_argument.resolve(strict=True)
    except OSError as error:
        fail(f"{label} cannot be resolved: {error}")
    if path_is_within(path, root):
        fail(f"{label} must be outside the repository")
    try:
        return path, path.read_bytes()
    except OSError as error:
        fail(f"{label} cannot be read: {error}")


def repository_file_path(path_argument: Path, root: Path, label: str) -> tuple[Path, str]:
    try:
        metadata = path_argument.lstat()
    except OSError as error:
        fail(f"{label} does not exist: {error}")
    if stat.S_ISLNK(metadata.st_mode) or not stat.S_ISREG(metadata.st_mode):
        fail(f"{label} must be a regular repository file")
    try:
        path = path_argument.resolve(strict=True)
        relative = path.relative_to(root).as_posix()
    except (OSError, ValueError) as error:
        fail(f"{label} must be inside the repository: {error}")
    if not is_normalized_path(relative):
        fail(f"{label} path is not normalized: {relative!r}")
    return path, relative


def read_tree_file(root: Path, tree: str, relative_path: str, label: str) -> bytes:
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
    if mode not in {"100644", "100755"} or object_type != "blob":
        fail(f"{label} must be a regular candidate-tree blob: {relative_path}")
    return run_git(root, ["cat-file", "blob", object_id])


def require_hex(value: object, label: str, pattern: re.Pattern[str] = HEX_64) -> str:
    if not isinstance(value, str) or pattern.fullmatch(value) is None:
        fail(f"{label} must be lowercase hexadecimal")
    return value


def validate_bundle(document: dict, trust_root: dict) -> None:
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
    if document.get("wave") not in WAVES:
        fail("bundle wave must be W0 through W6")
    if not isinstance(document.get("waveSliceID"), str) or not document["waveSliceID"]:
        fail("bundle waveSliceID must be non-empty")
    if (
        not isinstance(document.get("sequenceOrdinal"), int)
        or isinstance(document.get("sequenceOrdinal"), bool)
        or document["sequenceOrdinal"] < 0
    ):
        fail("bundle sequenceOrdinal must be a non-negative integer")
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
    for field in ("evidencePrerequisites", "externalPrerequisites"):
        if not isinstance(document.get(field), list):
            fail(f"bundle {field} must be an array")
    errors = validate_signed_document(
        document,
        trust_root,
        expected_role="wave-bundle-reviewer",
        label="bundle",
    )
    if errors:
        fail("; ".join(errors))


def validate_previous_receipt(
    document: dict,
    trust_root: dict,
    source_selection: dict,
    base_tree: str,
) -> None:
    schema = document.get("schema")
    if schema == "QinaoRootAdmissionReceiptV1":
        role = "root-admission-signer"
        if document.get("selectedTree") != source_selection.get("selectedTree"):
            fail("root admission receipt selectedTree does not bind source selection")
    elif schema == "QinaoWaveAdmissionReceiptV1":
        role = "wave-admission-signer"
    else:
        fail("previous receipt schema is not admitted")
    errors = validate_signed_document(
        document,
        trust_root,
        expected_role=role,
        label="previous receipt",
    )
    if errors:
        fail("; ".join(errors))
    if document.get("repositoryIdentity") != trust_root.get("repositoryIdentity"):
        fail("previous receipt repositoryIdentity does not match trust root")
    if document.get("outcome") != "admitted":
        fail("previous receipt outcome must be admitted")
    if document.get("candidateTree") != base_tree:
        fail("previous receipt candidateTree does not equal bundle base tree")


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
    trust_root: dict,
    previous_receipt: dict,
    base_tree: str,
) -> None:
    if set(chain) != RUNTIME_CHAIN_FIELDS:
        fail("runtime receipt chain fields mismatch")
    if chain.get("schema") != "QinaoW6RuntimeReceiptChainV1":
        fail("runtime receipt chain schema must be QinaoW6RuntimeReceiptChainV1")
    if chain.get("repositoryIdentity") != trust_root.get("repositoryIdentity"):
        fail("runtime receipt chain repositoryIdentity does not match trust root")
    if chain.get("outcome") != "accepted":
        fail("runtime receipt chain outcome must be accepted")
    errors = validate_signed_document(
        chain,
        trust_root,
        expected_role="runtime-chain-signer",
        label="runtime receipt chain",
    )
    if errors:
        fail("; ".join(errors))

    entries = chain.get("entries")
    if not isinstance(entries, list) or len(entries) != len(RUNTIME_SLICE_IDS):
        fail("runtime receipt chain must contain exactly six entries")
    previous_embedded: dict | None = None
    for index, (entry, expected_slice) in enumerate(
        zip(entries, RUNTIME_SLICE_IDS, strict=True),
        start=1,
    ):
        if not isinstance(entry, dict) or set(entry) != {
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
        if receipt.get("schema") != "QinaoWaveAdmissionReceiptV1":
            fail(
                f"runtime receipt chain entry {index} receipt schema mismatch"
            )
        if receipt.get("repositoryIdentity") != trust_root.get(
            "repositoryIdentity"
        ):
            fail(
                f"runtime receipt chain entry {index} repositoryIdentity mismatch"
            )
        if receipt.get("wave") != "W6":
            fail(f"runtime receipt chain entry {index} wave must be W6")
        if receipt.get("waveSliceID") != expected_slice:
            fail(
                f"runtime receipt chain entry {index} slice ID mismatch"
            )
        if receipt.get("sequenceOrdinal") != index:
            fail(
                f"runtime receipt chain entry {index} sequence ordinal mismatch"
            )
        if receipt.get("outcome") != "admitted":
            fail(
                f"runtime receipt chain entry {index} outcome must be admitted"
            )
        errors = validate_signed_document(
            receipt,
            trust_root,
            expected_role="wave-admission-signer",
            label=f"runtime receipt chain entry {index} receipt",
        )
        if errors:
            fail("; ".join(errors))
        require_hex(
            receipt.get("baseTree"),
            f"runtime receipt chain entry {index} baseTree",
            HEX_40,
        )
        require_hex(
            receipt.get("candidateTree"),
            f"runtime receipt chain entry {index} candidateTree",
            HEX_40,
        )
        if previous_embedded is not None:
            if receipt.get("baseTree") != previous_embedded.get("candidateTree"):
                fail(
                    "runtime receipt chain predecessor candidate-tree "
                    f"continuity failed at entry {index}"
                )
            expected_predecessor = sha256(
                canonical_json_bytes(previous_embedded)
            )
            if (
                receipt.get("previousReceiptBlobDigest")
                != expected_predecessor
            ):
                fail(
                    "runtime receipt chain predecessor receipt continuity "
                    f"failed at entry {index}"
                )
        previous_embedded = receipt

    assert previous_embedded is not None
    expected_head = chain.get("expectedHeadTree")
    if expected_head != previous_embedded.get("candidateTree"):
        fail("runtime receipt chain expected head tree does not equal entry 06")
    if expected_head != base_tree:
        fail("runtime receipt chain expected head tree does not equal bundle base")
    if canonical_json_bytes(previous_embedded) != canonical_json_bytes(
        previous_receipt
    ):
        fail(
            "runtime receipt chain entry 06 does not equal previous receipt"
        )


def validate_external_prerequisites(
    arguments: list[str],
    bundle: dict,
    *,
    root: Path,
    reserved_paths: list[Path],
    trust_root: dict,
    previous_receipt: dict,
    base_tree: str,
) -> tuple[list[dict], list[Path]]:
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
    resolved_paths: list[Path] = []
    normalized: list[dict] = []
    for requirement in requirements:
        name = requirement["name"]
        path, raw = external_file_bytes(
            by_name[name],
            root,
            f"external prerequisite {name}",
        )
        if path in reserved_paths or path in resolved_paths:
            fail("external input paths must be pairwise distinct")
        resolved_paths.append(path)
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
            trust_root=trust_root,
            previous_receipt=previous_receipt,
            base_tree=base_tree,
        )
        normalized.append(dict(requirement))
    return normalized, resolved_paths


def derive_report(
    args: argparse.Namespace,
) -> tuple[Path, dict, dict, list[Path]]:
    root = ensure_repository(args.root)
    ensure_index_candidate(root, args.candidate_tree)

    source_path, source_raw = external_file_bytes(
        args.source_selection,
        root,
        "source selection",
    )
    trust_path, trust_raw = external_file_bytes(
        args.trust_root,
        root,
        "trust root",
    )
    previous_path, previous_raw = external_file_bytes(
        args.previous_receipt,
        root,
        "previous receipt",
    )
    input_paths = [source_path, trust_path, previous_path]
    if len(input_paths) != len(set(input_paths)):
        fail("external input paths must be pairwise distinct")

    trust_root = load_json_bytes(trust_raw, "trust root")
    trust_errors = validate_trust_root(trust_root)
    if trust_errors:
        fail("; ".join(trust_errors))
    source_selection = load_json_bytes(source_raw, "source selection")
    source_errors = validate_source_selection(
        source_selection,
        trust_root,
        root=root,
    )
    if source_errors:
        fail("; ".join(source_errors))
    previous_receipt = load_json_bytes(previous_raw, "previous receipt")

    bundle_path, bundle_relative = repository_file_path(
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
    if bundle_path.read_bytes() != bundle_raw:
        fail("bundle worktree bytes differ from candidate tree")
    bundle = load_json_bytes(bundle_raw, "bundle")
    validate_bundle(bundle, trust_root)

    base_commit = bundle["baseCommit"]
    base_tree = bundle["baseTree"]
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
    if source_selection.get("selectedTree") != base_tree:
        fail("source selection selectedTree does not equal bundle base tree")
    if bundle["requiredPredecessorCandidateTree"] != base_tree:
        fail("bundle predecessor candidate tree does not equal bundle base tree")
    if bundle["requiredPredecessorReceiptBlob"] != sha256(previous_raw):
        fail("bundle predecessor receipt blob digest mismatch")
    if bundle["approvedDesignBlob"] != source_selection.get("approvedDesignBlob"):
        fail("bundle approvedDesignBlob does not match source selection")
    external_verifier = bundle.get("toolBlobs", {}).get("externalVerifier")
    if external_verifier != source_selection.get("externalVerifierSHA256"):
        fail("bundle external verifier digest does not match source selection")
    validate_previous_receipt(
        previous_receipt,
        trust_root,
        source_selection,
        base_tree,
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

    owner_ledger_relative = bundle.get("ownerLedgerPath")
    checker_relative = "scripts/check_qinao_owner_ledger.py"
    required_paths = {
        bundle_relative,
        path_list_relative,
        owner_ledger_relative,
        checker_relative,
    }
    categories = bundle.get("categories")
    if not isinstance(categories, dict) or set(categories) != set(CATEGORIES):
        fail("bundle categories must contain adapter/create/extension/fixture")
    category_report: dict[str, dict] = {}
    category_paths: dict[str, str] = {}
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
        reviewed_rows = document.get("reviewedRows", [])
        if not isinstance(reviewed_rows, list):
            fail(f"{category} category reviewedRows must be an array")
        category_report[category] = {
            "blobDigest": sha256(raw),
            "rowCount": len(reviewed_rows),
            "status": document.get("status"),
        }
        category_paths[category] = relative_path
        required_paths.add(relative_path)
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
    )
    tool_blobs = bundle.get("toolBlobs")
    if not isinstance(tool_blobs, dict):
        fail("bundle toolBlobs must be an object")
    if tool_blobs.get("ownerLedgerChecker") != sha256(checker_raw):
        fail("owner-ledger checker blob digest mismatch")
    if tool_blobs.get("repositoryRunner") != sha256(Path(__file__).read_bytes()):
        fail("repository runner blob digest mismatch")

    external_prerequisites, external_paths = validate_external_prerequisites(
        args.external_prerequisite,
        bundle,
        root=root,
        reserved_paths=input_paths,
        trust_root=trust_root,
        previous_receipt=previous_receipt,
        base_tree=base_tree,
    )
    ensure_worktree_matches_candidate(root, args.candidate_tree, paths)

    checker_command = [
        sys.executable,
        str(root / checker_relative),
        "--root",
        str(root),
        "--ledger",
        str(root / owner_ledger_relative),
        "--source-selection",
        str(source_path),
        "--trust-root",
        str(trust_path),
        "--base-tree",
        base_tree,
        "--candidate-tree",
        args.candidate_tree,
        "--wave",
        bundle["wave"],
        "--create-manifest-or-disposition",
        str(root / category_paths["create"]),
        "--extension-manifest-or-disposition",
        str(root / category_paths["extension"]),
        "--adapter-manifest-or-disposition",
        str(root / category_paths["adapter"]),
        "--fixture-set-or-disposition",
        str(root / category_paths["fixture"]),
    ]
    completed = subprocess.run(
        checker_command,
        cwd=root,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
    )
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
        "pathList": {
            "root": path_list_binding["root"],
            "count": path_list_binding["count"],
        },
        "categories": category_report,
        "evidencePrerequisites": bundle["evidencePrerequisites"],
        "externalPrerequisites": external_prerequisites,
        "toolBlobs": tool_blobs,
        "admissionStatus": "unadmitted",
    }
    return root, report, trust_root, [*input_paths, *external_paths]


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
    reserved_paths: list[Path],
) -> None:
    receipt_path, receipt_raw = external_file_bytes(
        args.receipt,
        root,
        "receipt",
    )
    if receipt_path in reserved_paths:
        fail("external input paths must be pairwise distinct")
    receipt = load_json_bytes(receipt_raw, "receipt")
    binding_fields = set(report) - {"admissionStatus", "schema"}
    metadata_fields = {
        "expiresAt",
        "issuedAt",
        "nonce",
        "outcome",
        "role",
        "schema",
        "signature",
        "signatureAlgorithm",
        "signer",
    }
    expected_fields = binding_fields | metadata_fields
    if set(receipt) != expected_fields:
        fail(
            "receipt fields mismatch: "
            f"missing={sorted(expected_fields - set(receipt))!r}, "
            f"extra={sorted(set(receipt) - expected_fields)!r}"
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
    )
    if errors:
        fail("; ".join(errors))
    for field in sorted(binding_fields):
        if receipt.get(field) != report.get(field):
            fail(f"receipt binding {field} does not match derived candidate")


def main() -> int:
    args = parse_args()
    try:
        root, report, trust_root, reserved_paths = derive_report(args)
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
            )
            message = "qinao wave admission receipt: PASS (verified only)"
    except GateError as error:
        print(f"qinao wave admission gate failed: {error}", file=sys.stderr)
        return 1
    print(message)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
