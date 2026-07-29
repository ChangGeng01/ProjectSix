#!/usr/bin/env python3
"""Collect unsigned iOS 27 K4 facts and verify externally signed evidence.

Collection is deliberately non-authoritative.  It combines read-only facts
from one installed iPhoneOS SDK with one externally signed physical-device
profile whose signature covers the explicit probe matrix.  SDK declaration
presence is recorded only as an observation; it never establishes entitlement
or process-model support.

This repository-side program has no signing or admission operation.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import plistlib
import re
import stat
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path, PurePosixPath

try:
    from check_qinao_owner_ledger import (
        DuplicateJSONKeyError,
        canonical_json_bytes,
        reject_duplicate_json_keys,
        validate_signed_document,
        validate_trust_root,
    )
except ModuleNotFoundError:
    from scripts.check_qinao_owner_ledger import (
        DuplicateJSONKeyError,
        canonical_json_bytes,
        reject_duplicate_json_keys,
        validate_signed_document,
        validate_trust_root,
    )


HEX_64 = re.compile(r"[0-9a-f]{64}")
GIT_ID = re.compile(r"(?:[0-9a-f]{40}|[0-9a-f]{64})")
IOS_27 = re.compile(r"27(?:\.|$)")
ALLOWED_STATUSES = {
    "supportedExactProfile",
    "disabledMissingTarget",
    "disabledMissingEntitlement",
    "disabledMissingDeviceProof",
}
PROFILE_TOP_LEVEL_PROJECTION_FIELDS = (
    "repositoryIdentity",
    "approvedDesignBlob",
    "candidateCommit",
    "candidateTree",
    "platform",
    "environment",
    "deviceIdentityDigest",
    "osVersion",
    "osBuild",
    "xcodeVersion",
    "xcodeBuild",
    "sdkCanonicalName",
    "sdkVersion",
    "sdkBuild",
    "signingIdentityClass",
    "entitlementInventory",
)
PROFILE_MATRIX_PROJECTION_FIELDS = (
    ("probeDeviceIdentityDigest", "deviceIdentityDigest"),
    ("frameworkAPIs", "frameworkAPIs"),
    ("target", "target"),
    ("requiredEntitlements", "requiredEntitlements"),
    ("sqlite", "sqlite"),
    ("transport", "transport"),
    ("lifecycle", "lifecycle"),
    ("resultBundleDigest", "resultBundleDigest"),
    ("supportedProfileDigest", "supportedProfileDigest"),
)
LIFECYCLE_EVENTS = (
    "launch",
    "interruption",
    "termination",
    "reconnect",
    "keyAccess",
)
PROFILE_FIELDS = {
    "approvedDesignBlob",
    "candidateCommit",
    "candidateTree",
    "deviceIdentityDigest",
    "entitlementInventory",
    "environment",
    "expiresAt",
    "issuedAt",
    "nonce",
    "osBuild",
    "osVersion",
    "platform",
    "probeMatrix",
    "repositoryIdentity",
    "role",
    "schema",
    "sdkBuild",
    "sdkCanonicalName",
    "sdkVersion",
    "signature",
    "signatureAlgorithm",
    "signer",
    "signingIdentityClass",
    "xcodeBuild",
    "xcodeVersion",
}
PROBE_MATRIX_FIELDS = {
    "deviceIdentityDigest",
    "frameworkAPIs",
    "lifecycle",
    "requiredEntitlements",
    "resultBundleDigest",
    "schema",
    "sqlite",
    "status",
    "supportedProfileDigest",
    "target",
    "transport",
}
TARGET_FIELDS = {
    "bundleIdentifierDigest",
    "extensionPoint",
    "processModel",
}
FRAMEWORK_QUERY_FIELDS = {
    "api",
    "declarationRelativePath",
    "declarationToken",
    "framework",
}
FRAMEWORK_OBSERVATION_COMMON_FIELDS = {
    "api",
    "declarationPresence",
    "entitlementSupportInference",
    "framework",
    "processSupportInference",
}
FRAMEWORK_PRESENT_OBSERVATION_FIELDS = (
    FRAMEWORK_OBSERVATION_COMMON_FIELDS | {"declarationDigest"}
)
FRAMEWORK_ABSENT_OBSERVATION_FIELDS = FRAMEWORK_OBSERVATION_COMMON_FIELDS
SQLITE_FIELDS = {"fileProtection", "open", "wal"}
TRANSPORT_FIELDS = {"feasibility", "kind"}
LIFECYCLE_FIELDS = {"event", "observation"}
COLLECTION_ONLY_FIELDS = {
    "collectionStatus",
    "signaturePresent",
}
SIGNATURE_METADATA_FIELDS = {
    "expiresAt",
    "issuedAt",
    "nonce",
    "role",
    "signature",
    "signatureAlgorithm",
    "signer",
}
COLLECTION_REPORT_FIELDS = {
    "approvedDesignBlob",
    "candidateCommit",
    "candidateTree",
    "collectionStatus",
    "deviceIdentityDigest",
    "deviceProfileDigest",
    "entitlementInventory",
    "environment",
    "frameworkAPIs",
    "frameworkAPIAvailability",
    "lifecycle",
    "osBuild",
    "osVersion",
    "platform",
    "probeDeviceIdentityDigest",
    "probeMatrixDigest",
    "repositoryIdentity",
    "requiredEntitlements",
    "resultBundleDigest",
    "schema",
    "sdkBuild",
    "sdkCanonicalName",
    "sdkSettingsDigest",
    "sdkSystemVersionDigest",
    "sdkVersion",
    "signaturePresent",
    "signingIdentityClass",
    "sqlite",
    "status",
    "supportedProfileDigest",
    "target",
    "transport",
    "xcodeBuild",
    "xcodeVersion",
}
EVIDENCE_FIELDS = (
    COLLECTION_REPORT_FIELDS - COLLECTION_ONLY_FIELDS
) | SIGNATURE_METADATA_FIELDS
GIT_TIMEOUT_SECONDS = 30
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
    """A fail-closed K4 gate diagnostic."""


def fail(message: str) -> None:
    raise GateError(message)


def sha256(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def is_nonempty_string(value: object) -> bool:
    return isinstance(value, str) and bool(value)


def path_is_within(path: Path, root: Path) -> bool:
    try:
        path.relative_to(root)
    except ValueError:
        return False
    return True


def run_git(root: Path, *arguments: str) -> str:
    return run_git_bytes(root, *arguments).decode(
        "utf-8",
        errors="strict",
    ).strip()


def run_git_bytes(root: Path, *arguments: str) -> bytes:
    try:
        completed = subprocess.run(
            ["git", *arguments],
            cwd=root,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
            env=GIT_SUBPROCESS_ENVIRONMENT,
            timeout=GIT_TIMEOUT_SECONDS,
        )
    except (OSError, subprocess.TimeoutExpired):
        fail(f"Git command unavailable or timed out ({' '.join(arguments)})")
    if completed.returncode != 0:
        diagnostic = completed.stderr.decode(
            "utf-8",
            errors="replace",
        ).strip()
        fail(
            f"Git command failed ({' '.join(arguments)}): "
            f"{diagnostic or f'exit {completed.returncode}'}"
        )
    return completed.stdout


def ensure_repository(
    root_argument: Path,
    *,
    require_clean: bool,
) -> tuple[Path, str, str]:
    try:
        root = root_argument.resolve(strict=True)
    except OSError as error:
        fail(f"repository root cannot be resolved: {error}")
    if not root.is_dir():
        fail("repository root must be a directory")
    discovered = Path(run_git(root, "rev-parse", "--show-toplevel")).resolve(
        strict=True
    )
    if discovered != root:
        fail("--root must name the exact Git repository root")
    commit = run_git(root, "rev-parse", "HEAD")
    tree = run_git(root, "rev-parse", "HEAD^{tree}")
    if GIT_ID.fullmatch(commit) is None or GIT_ID.fullmatch(tree) is None:
        fail("repository HEAD commit/tree is not a canonical Git object ID")
    if require_clean and run_git(root, "status", "--porcelain=v1"):
        fail("repository must be clean before K4 collection")
    return root, commit, tree


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


def read_external_file(
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
    return read_bound_file(path, label=label, require_mode_0600=True)


def read_bound_file(
    path: Path,
    *,
    label: str,
    require_mode_0600: bool,
) -> tuple[Path, bytes, tuple[int, int]]:
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
        if require_mode_0600 and stat.S_IMODE(before.st_mode) != 0o600:
            fail(f"{label} must have mode 0600")
        if before.st_nlink != 1:
            fail(f"{label} must have exactly one hard link")
        chunks: list[bytes] = []
        byte_count = 0
        while True:
            chunk = os.read(descriptor, 64 * 1024)
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


def read_evidence_file(
    path_argument: Path,
    root: Path,
) -> tuple[Path, bytes, tuple[object, object]]:
    return read_evidence_file_from_tree(
        path_argument,
        root,
        run_git(root, "rev-parse", "HEAD^{tree}"),
    )


def read_evidence_file_from_tree(
    path_argument: Path,
    root: Path,
    repository_tree: str,
) -> tuple[Path, bytes, tuple[object, object]]:
    try:
        parent = path_argument.parent.resolve(strict=True)
    except OSError as error:
        fail(f"evidence parent cannot be resolved: {error}")
    absolute = parent / path_argument.name
    try:
        relative = absolute.relative_to(root).as_posix()
    except ValueError:
        return read_external_file(path_argument, root, "evidence")
    if (
        not relative
        or not path_is_within(absolute, root)
        or PurePosixPath(relative).is_absolute()
        or ".." in PurePosixPath(relative).parts
        or "\\" in relative
    ):
        fail("repository evidence path must be normalized and workspace-relative")
    listing = run_git_bytes(
        root,
        "ls-tree",
        "-z",
        repository_tree,
        "--",
        relative,
    )
    rows = [row for row in listing.split(b"\0") if row]
    if len(rows) != 1:
        fail(f"evidence is missing from repository tree: {relative}")
    try:
        metadata, encoded_path = rows[0].split(b"\t", 1)
        mode, object_type, object_id = metadata.decode("ascii").split(" ")
        listed_path = encoded_path.decode("utf-8")
    except (ValueError, UnicodeDecodeError) as error:
        fail(f"evidence has invalid repository-tree metadata: {error}")
    if (
        listed_path != relative
        or mode not in {"100644", "100755"}
        or object_type != "blob"
        or GIT_ID.fullmatch(object_id) is None
    ):
        fail("evidence must be one unambiguous regular repository-tree blob")
    raw = run_git_bytes(root, "cat-file", "blob", object_id)
    return absolute, raw, ("git-blob", object_id)
    try:
        parent = path_argument.parent.resolve(strict=True)
    except OSError as error:
        fail(f"evidence parent cannot be resolved: {error}")
    path = parent / path_argument.name
    return read_bound_file(
        path,
        label="evidence",
        require_mode_0600=not path_is_within(path, root),
    )


def require_exact_fields(document: dict, expected: set[str], label: str) -> None:
    if set(document) != expected:
        fail(
            f"{label} fields mismatch: "
            f"missing={sorted(expected - set(document))!r}, "
            f"extra={sorted(set(document) - expected)!r}"
        )


def require_hex(value: object, label: str) -> str:
    if not isinstance(value, str) or HEX_64.fullmatch(value) is None:
        fail(f"{label} must be 64 lowercase hexadecimal characters")
    return value


def require_git_id(value: object, label: str) -> str:
    if not isinstance(value, str) or GIT_ID.fullmatch(value) is None:
        fail(f"{label} must be a canonical Git object ID")
    return value


def require_sorted_unique_strings(
    value: object,
    label: str,
) -> list[str]:
    if not isinstance(value, list) or any(
        not is_nonempty_string(item) for item in value
    ):
        fail(f"{label} must be a string list")
    strings = list(value)
    if strings != sorted(set(strings)):
        fail(f"{label} must be sorted and unique")
    return strings


def validate_target(target: object, label: str) -> dict:
    if not isinstance(target, dict):
        fail(f"{label} must be an object")
    require_exact_fields(target, TARGET_FIELDS, label)
    require_hex(target.get("bundleIdentifierDigest"), f"{label} bundleIdentifierDigest")
    for field in ("extensionPoint", "processModel"):
        if not is_nonempty_string(target.get(field)):
            fail(f"{label} {field} must be non-empty")
    return target


def normalized_sdk_relative_path(value: object, label: str) -> str:
    if not is_nonempty_string(value):
        fail(f"{label} must be non-empty")
    path = PurePosixPath(value)
    if (
        path.is_absolute()
        or str(path) != value
        or "." in path.parts
        or ".." in path.parts
    ):
        fail(f"{label} must be a normalized relative SDK path")
    return value


def validate_framework_queries(value: object) -> list[dict]:
    if not isinstance(value, list) or not value:
        fail("probe matrix frameworkAPIs must be a non-empty list")
    result: list[dict] = []
    identities: list[tuple[str, str]] = []
    for index, query in enumerate(value):
        label = f"probe matrix frameworkAPIs[{index}]"
        if not isinstance(query, dict):
            fail(f"{label} must be an object")
        require_exact_fields(query, FRAMEWORK_QUERY_FIELDS, label)
        for field in ("framework", "api", "declarationToken"):
            if not is_nonempty_string(query.get(field)):
                fail(f"{label} {field} must be non-empty")
        normalized_sdk_relative_path(
            query.get("declarationRelativePath"),
            f"{label} declarationRelativePath",
        )
        identities.append((query["framework"], query["api"]))
        result.append(query)
    if len(identities) != len(set(identities)):
        fail("probe matrix frameworkAPIs must be unique by framework/API")
    if result != sorted(result, key=canonical_json_bytes):
        fail("probe matrix frameworkAPIs must use global RFC 8785 element order")
    return result


def validate_lifecycle(value: object, label: str = "probe matrix lifecycle") -> list[dict]:
    if not isinstance(value, list):
        fail(f"{label} must be a list")
    rows: list[dict] = []
    for index, row in enumerate(value):
        if not isinstance(row, dict):
            fail(f"{label}[{index}] must be an object")
        require_exact_fields(row, LIFECYCLE_FIELDS, f"{label}[{index}]")
        if row.get("observation") not in {"passed", "failed", "notObserved"}:
            fail(f"{label}[{index}] observation is invalid")
        rows.append(row)
    events = tuple(row.get("event") for row in rows)
    if events != LIFECYCLE_EVENTS:
        fail(f"{label} events must be exactly {list(LIFECYCLE_EVENTS)!r}")
    return rows


def validate_sqlite(value: object, label: str = "probe matrix sqlite") -> dict:
    if not isinstance(value, dict):
        fail(f"{label} must be an object")
    require_exact_fields(value, SQLITE_FIELDS, label)
    for field in sorted(SQLITE_FIELDS):
        if value.get(field) not in {"passed", "failed", "notObserved"}:
            fail(f"{label} {field} observation is invalid")
    return value


def validate_transport(
    value: object,
    label: str = "probe matrix transport",
) -> dict:
    if not isinstance(value, dict):
        fail(f"{label} must be an object")
    require_exact_fields(value, TRANSPORT_FIELDS, label)
    if not is_nonempty_string(value.get("kind")):
        fail(f"{label} kind must be non-empty")
    if value.get("feasibility") not in {"passed", "failed", "notObserved"}:
        fail(f"{label} feasibility observation is invalid")
    return value


def supported_profile_digest(
    *,
    framework_apis: list[dict],
    target: dict,
    required_entitlements: list[str],
    sqlite: dict,
    transport: dict,
    lifecycle: list[dict],
) -> str:
    return sha256(
        canonical_json_bytes(
            {
                "frameworkAPIs": framework_apis,
                "target": target,
                "requiredEntitlements": required_entitlements,
                "sqlite": sqlite,
                "transport": transport,
                "lifecycle": lifecycle,
            }
        )
    )


def validate_status_derivation(
    *,
    status_value: object,
    target: dict,
    entitlement_inventory: list[str],
    required_entitlements: list[str],
    sqlite: dict,
    transport: dict,
    lifecycle: list[dict],
    framework_observations: list[dict] | None = None,
    label: str,
) -> str:
    if status_value not in ALLOWED_STATUSES:
        fail(f"{label} status is invalid")
    status = str(status_value)
    missing_entitlements = sorted(
        set(required_entitlements) - set(entitlement_inventory)
    )
    target_missing = target["processModel"] == "missing"
    framework_missing = framework_observations is not None and any(
        row["declarationPresence"] == "absent"
        for row in framework_observations
    )
    device_proof_missing = (
        any(row["observation"] != "passed" for row in lifecycle)
        or any(sqlite[field] != "passed" for field in SQLITE_FIELDS)
        or transport["feasibility"] != "passed"
    )
    if target_missing or framework_missing:
        expected = "disabledMissingTarget"
    elif missing_entitlements:
        expected = "disabledMissingEntitlement"
    elif device_proof_missing:
        expected = "disabledMissingDeviceProof"
    else:
        expected = "supportedExactProfile"
    if status != expected:
        fail(
            f"{label} status does not follow deterministic precedence: "
            f"expected {expected}"
        )
    return status


def validate_probe_matrix(
    matrix: object,
    *,
    device_identity_digest: str,
    entitlement_inventory: list[str],
) -> dict:
    if not isinstance(matrix, dict):
        fail("device profile probeMatrix must be an object")
    require_exact_fields(matrix, PROBE_MATRIX_FIELDS, "probe matrix")
    if matrix.get("schema") != "QinaoK4DeviceProbeMatrixV1":
        fail("probe matrix schema must be QinaoK4DeviceProbeMatrixV1")
    probe_device = require_hex(
        matrix.get("deviceIdentityDigest"),
        "probe matrix deviceIdentityDigest",
    )
    if probe_device != device_identity_digest:
        fail(
            "probe matrix deviceIdentityDigest does not match signed device "
            "profile deviceIdentityDigest"
        )
    target = validate_target(matrix.get("target"), "probe matrix target")
    framework_apis = validate_framework_queries(matrix.get("frameworkAPIs"))
    required_entitlements = require_sorted_unique_strings(
        matrix.get("requiredEntitlements"),
        "probe matrix requiredEntitlements",
    )
    sqlite = validate_sqlite(matrix.get("sqlite"))
    transport = validate_transport(matrix.get("transport"))
    lifecycle = validate_lifecycle(matrix.get("lifecycle"))
    require_hex(matrix.get("resultBundleDigest"), "probe matrix resultBundleDigest")
    claimed_profile_digest = require_hex(
        matrix.get("supportedProfileDigest"),
        "probe matrix supportedProfileDigest",
    )
    derived_profile_digest = supported_profile_digest(
        framework_apis=framework_apis,
        target=target,
        required_entitlements=required_entitlements,
        sqlite=sqlite,
        transport=transport,
        lifecycle=lifecycle,
    )
    if claimed_profile_digest != derived_profile_digest:
        fail(
            "probe matrix supportedProfileDigest does not include the exact "
            "framework/API declarations"
        )
    validate_status_derivation(
        status_value=matrix.get("status"),
        target=target,
        entitlement_inventory=entitlement_inventory,
        required_entitlements=required_entitlements,
        sqlite=sqlite,
        transport=transport,
        lifecycle=lifecycle,
        label="probe matrix",
    )
    return matrix


def load_trust_root(
    path_argument: Path,
    root: Path,
    *,
    verification_time: datetime,
) -> tuple[Path, bytes, dict, tuple[int, int]]:
    path, raw, identity = read_external_file(
        path_argument,
        root,
        "trust root",
    )
    document = load_json_bytes(raw, "trust root")
    errors = validate_trust_root(
        document,
        verification_time=verification_time,
    )
    if errors:
        fail("; ".join(errors))
    return path, raw, document, identity


def load_device_profile(
    path_argument: Path,
    *,
    root: Path,
    trust_root: dict,
    commit: str,
    tree: str,
    verification_time: datetime,
) -> tuple[Path, bytes, dict, tuple[int, int]]:
    path, raw, identity = read_external_file(
        path_argument,
        root,
        "device profile",
    )
    profile = load_json_bytes(raw, "device profile")
    if "signature" not in profile:
        fail("device profile signature is required")
    require_exact_fields(profile, PROFILE_FIELDS, "device profile")
    if profile.get("schema") != "QinaoK4PhysicalDeviceProfileV1":
        fail("device profile schema must be QinaoK4PhysicalDeviceProfileV1")
    if profile.get("repositoryIdentity") != trust_root.get("repositoryIdentity"):
        fail("device profile repositoryIdentity does not match trust root")
    errors = validate_signed_document(
        profile,
        trust_root,
        expected_role="k4-evidence-signer",
        label="device profile",
        verification_time=verification_time,
    )
    if errors:
        fail("; ".join(errors))
    require_hex(profile.get("approvedDesignBlob"), "device profile approvedDesignBlob")
    if require_git_id(
        profile.get("candidateCommit"),
        "device profile candidateCommit",
    ) != commit:
        fail("device profile candidateCommit does not match repository HEAD")
    if require_git_id(
        profile.get("candidateTree"),
        "device profile candidateTree",
    ) != tree:
        fail("device profile candidateTree does not match repository HEAD tree")
    if profile.get("platform") != "iOS":
        fail("device profile platform must be iOS")
    if profile.get("environment") != "physicalDevice":
        fail("device profile environment must be physicalDevice, never simulator")
    device_digest = require_hex(
        profile.get("deviceIdentityDigest"),
        "device profile deviceIdentityDigest",
    )
    for field in ("osVersion", "xcodeVersion", "sdkVersion"):
        value = profile.get(field)
        if not isinstance(value, str) or IOS_27.match(value) is None:
            fail(f"device profile {field} must have major version 27")
    for field in (
        "osBuild",
        "xcodeBuild",
        "sdkBuild",
        "sdkCanonicalName",
        "signingIdentityClass",
    ):
        if not is_nonempty_string(profile.get(field)):
            fail(f"device profile {field} must be non-empty")
    inventory = require_sorted_unique_strings(
        profile.get("entitlementInventory"),
        "device profile entitlementInventory",
    )
    validate_probe_matrix(
        profile.get("probeMatrix"),
        device_identity_digest=device_digest,
        entitlement_inventory=inventory,
    )
    return path, raw, profile, identity


def inspect_installed_sdk(
    developer_argument: Path,
    profile: dict,
) -> tuple[str, str, list[dict]]:
    try:
        developer = developer_argument.resolve(strict=True)
    except OSError as error:
        fail(f"Xcode developer directory cannot be resolved: {error}")
    if not developer.is_dir():
        fail("Xcode developer directory must be a directory")
    version_path = developer.parent / "version.plist"
    try:
        version_raw = version_path.read_bytes()
        version = plistlib.loads(version_raw)
    except (OSError, plistlib.InvalidFileException, ValueError) as error:
        fail(f"installed Xcode version.plist cannot be inspected: {error}")
    if not isinstance(version, dict):
        fail("installed Xcode version.plist must contain a dictionary")
    if version.get("CFBundleShortVersionString") != profile["xcodeVersion"]:
        fail("installed Xcode version does not match signed device profile")
    if version.get("ProductBuildVersion") != profile["xcodeBuild"]:
        fail("installed Xcode build does not match signed device profile")

    sdk_parent = (
        developer
        / "Platforms/iPhoneOS.platform/Developer/SDKs"
    )
    try:
        sdk_candidates = sorted(sdk_parent.glob("*.sdk"))
    except OSError as error:
        fail(f"installed iPhoneOS SDKs cannot be enumerated: {error}")
    resolved_sdks: dict[Path, Path] = {}
    for candidate in sdk_candidates:
        try:
            sdk = candidate.resolve(strict=True)
            sdk.relative_to(developer)
            if not sdk.is_dir():
                continue
        except (OSError, ValueError):
            continue
        resolved_sdks.setdefault(sdk, candidate)

    matches: list[tuple[Path, bytes, bytes]] = []
    for sdk in sorted(resolved_sdks):
        try:
            settings_path = sdk / "SDKSettings.json"
            settings_raw = settings_path.read_bytes()
            settings = json.loads(settings_raw)
            system_version_raw = (
                sdk
                / "System/Library/CoreServices/SystemVersion.plist"
            ).read_bytes()
            system_version = plistlib.loads(system_version_raw)
        except (
            OSError,
            ValueError,
            json.JSONDecodeError,
            plistlib.InvalidFileException,
        ):
            continue
        if not isinstance(settings, dict) or not isinstance(system_version, dict):
            continue
        if (
            settings.get("CanonicalName") == profile["sdkCanonicalName"]
            and settings.get("Version") == profile["sdkVersion"]
            and system_version.get("ProductVersion") == profile["sdkVersion"]
            and system_version.get("ProductBuildVersion") == profile["sdkBuild"]
        ):
            matches.append((sdk, settings_raw, system_version_raw))
    if len(matches) != 1:
        fail(
            "signed device profile must match exactly one installed iPhoneOS SDK; "
            f"matched={len(matches)}"
        )
    sdk, settings_raw, system_version_raw = matches[0]
    observations: list[dict] = []
    for query in profile["probeMatrix"]["frameworkAPIs"]:
        relative = normalized_sdk_relative_path(
            query["declarationRelativePath"],
            "framework API declarationRelativePath",
        )
        declaration = sdk.joinpath(*PurePosixPath(relative).parts)
        try:
            resolved = declaration.resolve(strict=True)
            resolved.relative_to(sdk)
            if not resolved.is_file():
                raise OSError("declaration is not a regular file")
            raw = resolved.read_bytes()
        except (FileNotFoundError, OSError, ValueError):
            digest: str | None = None
            presence = "absent"
        else:
            digest = sha256(raw)
            token = query["declarationToken"].encode("utf-8")
            presence = "present" if token in raw else "absent"
        observation = {
            "framework": query["framework"],
            "api": query["api"],
            "declarationPresence": presence,
            "processSupportInference": "notInferred",
            "entitlementSupportInference": "notInferred",
        }
        if digest is not None:
            observation["declarationDigest"] = digest
        observations.append(observation)
    return (
        sha256(settings_raw),
        sha256(system_version_raw),
        sorted(observations, key=canonical_json_bytes),
    )


def validate_profile_to_spike_projection(
    report: dict,
    *,
    profile: dict,
    profile_raw: bytes,
) -> None:
    matrix = profile["probeMatrix"]
    for field in PROFILE_TOP_LEVEL_PROJECTION_FIELDS:
        if report.get(field) != profile.get(field):
            fail(f"collection report profile projection mismatch: {field}")
    for spike_field, matrix_field in PROFILE_MATRIX_PROJECTION_FIELDS:
        if report.get(spike_field) != matrix.get(matrix_field):
            fail(
                "collection report probeMatrix projection mismatch: "
                f"{spike_field}"
            )
    if report.get("deviceProfileDigest") != sha256(profile_raw):
        fail("collection report deviceProfileDigest mismatch")
    if report.get("probeMatrixDigest") != sha256(canonical_json_bytes(matrix)):
        fail("collection report probeMatrixDigest mismatch")

    projected_fields = set(PROFILE_TOP_LEVEL_PROJECTION_FIELDS) | {
        spike_field
        for spike_field, _matrix_field in PROFILE_MATRIX_PROJECTION_FIELDS
    }
    only_derived_or_envelope_fields = {
        "collectionStatus",
        "deviceProfileDigest",
        "frameworkAPIAvailability",
        "probeMatrixDigest",
        "schema",
        "sdkSettingsDigest",
        "sdkSystemVersionDigest",
        "signaturePresent",
        "status",
    }
    if (
        set(report) - projected_fields
        != only_derived_or_envelope_fields
    ):
        fail("collection report only-derived field whitelist mismatch")


def derive_collection_report(
    *,
    commit: str,
    tree: str,
    profile_raw: bytes,
    profile: dict,
    sdk_settings_digest: str,
    sdk_system_version_digest: str,
    framework_observations: list[dict],
) -> dict:
    matrix = profile["probeMatrix"]
    validate_status_derivation(
        status_value=matrix["status"],
        target=matrix["target"],
        entitlement_inventory=profile["entitlementInventory"],
        required_entitlements=matrix["requiredEntitlements"],
        sqlite=matrix["sqlite"],
        transport=matrix["transport"],
        lifecycle=matrix["lifecycle"],
        framework_observations=framework_observations,
        label="probe matrix",
    )
    derived_profile_digest = supported_profile_digest(
        framework_apis=matrix["frameworkAPIs"],
        target=matrix["target"],
        required_entitlements=matrix["requiredEntitlements"],
        sqlite=matrix["sqlite"],
        transport=matrix["transport"],
        lifecycle=matrix["lifecycle"],
    )
    if matrix["supportedProfileDigest"] != derived_profile_digest:
        fail(
            "probe matrix supportedProfileDigest does not include the exact "
            "framework/API declarations"
        )
    report = {
        "schema": "QinaoK4IOS27PlatformSpikeCandidateV1",
        "collectionStatus": "unsignedUnadmitted",
        "signaturePresent": False,
        "repositoryIdentity": profile["repositoryIdentity"],
        "approvedDesignBlob": profile["approvedDesignBlob"],
        "candidateCommit": commit,
        "candidateTree": tree,
        "platform": profile["platform"],
        "environment": profile["environment"],
        "deviceProfileDigest": sha256(profile_raw),
        "deviceIdentityDigest": profile["deviceIdentityDigest"],
        "probeDeviceIdentityDigest": matrix["deviceIdentityDigest"],
        "osVersion": profile["osVersion"],
        "osBuild": profile["osBuild"],
        "xcodeVersion": profile["xcodeVersion"],
        "xcodeBuild": profile["xcodeBuild"],
        "sdkCanonicalName": profile["sdkCanonicalName"],
        "sdkVersion": profile["sdkVersion"],
        "sdkBuild": profile["sdkBuild"],
        "sdkSettingsDigest": sdk_settings_digest,
        "sdkSystemVersionDigest": sdk_system_version_digest,
        "frameworkAPIs": matrix["frameworkAPIs"],
        "frameworkAPIAvailability": framework_observations,
        "target": matrix["target"],
        "signingIdentityClass": profile["signingIdentityClass"],
        "entitlementInventory": profile["entitlementInventory"],
        "requiredEntitlements": matrix["requiredEntitlements"],
        "sqlite": matrix["sqlite"],
        "transport": matrix["transport"],
        "lifecycle": matrix["lifecycle"],
        "probeMatrixDigest": sha256(canonical_json_bytes(matrix)),
        "resultBundleDigest": matrix["resultBundleDigest"],
        "supportedProfileDigest": matrix["supportedProfileDigest"],
        "status": matrix["status"],
    }
    if set(report) != COLLECTION_REPORT_FIELDS:
        fail("internal collection report field contract drifted")
    validate_profile_to_spike_projection(
        report,
        profile=profile,
        profile_raw=profile_raw,
    )
    return report


def validate_output_path(path_argument: Path, root: Path) -> Path:
    try:
        path_argument.lstat()
    except FileNotFoundError:
        pass
    except OSError as error:
        fail(f"unsigned output path cannot be inspected: {error}")
    else:
        fail("unsigned output already exists")
    try:
        parent = path_argument.parent.resolve(strict=True)
    except OSError as error:
        fail(f"unsigned output parent cannot be resolved: {error}")
    if not parent.is_dir():
        fail("unsigned output parent must be a directory")
    path = parent / path_argument.name
    if path_is_within(path, root):
        fail("unsigned output must be outside the repository")
    return path


def write_exclusive_json(path: Path, document: dict) -> None:
    raw = canonical_json_bytes(document) + b"\n"
    descriptor: int | None = None
    created = False
    try:
        descriptor = os.open(
            path,
            os.O_WRONLY
            | os.O_CREAT
            | os.O_EXCL
            | getattr(os, "O_NOFOLLOW", 0),
            0o600,
        )
        created = True
        os.fchmod(descriptor, 0o600)
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
        fail("unsigned output already exists")
    except OSError as error:
        if descriptor is not None:
            os.close(descriptor)
        if created:
            try:
                path.unlink()
            except OSError:
                pass
        fail(f"unsigned output could not be written durably: {error}")


def validate_framework_observations(value: object) -> list[dict]:
    if not isinstance(value, list) or not value:
        fail("evidence frameworkAPIAvailability must be a non-empty list")
    rows: list[dict] = []
    identities: list[tuple[str, str]] = []
    for index, row in enumerate(value):
        label = f"evidence frameworkAPIAvailability[{index}]"
        if not isinstance(row, dict):
            fail(f"{label} must be an object")
        for field in ("framework", "api"):
            if not is_nonempty_string(row.get(field)):
                fail(f"{label} {field} must be non-empty")
        presence = row.get("declarationPresence")
        if presence not in {"present", "absent"}:
            fail(f"{label} declarationPresence is invalid")
        if presence == "present":
            require_exact_fields(
                row,
                FRAMEWORK_PRESENT_OBSERVATION_FIELDS,
                label,
            )
            require_hex(row.get("declarationDigest"), f"{label} declarationDigest")
        else:
            require_exact_fields(
                row,
                FRAMEWORK_ABSENT_OBSERVATION_FIELDS,
                label,
            )
        if (
            row.get("processSupportInference") != "notInferred"
            or row.get("entitlementSupportInference") != "notInferred"
        ):
            fail(
                f"{label} cannot infer process or entitlement support from "
                "SDK declaration presence"
            )
        identities.append((row["framework"], row["api"]))
        rows.append(row)
    if len(identities) != len(set(identities)):
        fail("evidence frameworkAPIAvailability identities must be unique")
    if rows != sorted(rows, key=canonical_json_bytes):
        fail(
            "evidence frameworkAPIAvailability must use global RFC 8785 "
            "element order"
        )
    return rows


def validate_supported_framework_facts(
    *,
    status_value: object,
    observations: list[dict],
    label: str,
) -> None:
    if status_value != "supportedExactProfile":
        return
    absent = [
        f"{row['framework']}/{row['api']}"
        for row in observations
        if row["declarationPresence"] != "present"
    ]
    if absent:
        fail(
            f"{label} supportedExactProfile requires every declared framework "
            f"API fact to be present; absent={absent!r}"
        )


def validate_evidence_bindings(
    evidence: dict,
    *,
    root: Path,
    trust_root: dict,
) -> None:
    if evidence.get("schema") != "QinaoK4IOS27PlatformSpikeV1":
        fail("evidence schema must be QinaoK4IOS27PlatformSpikeV1")
    if evidence.get("repositoryIdentity") != trust_root.get("repositoryIdentity"):
        fail("evidence repositoryIdentity does not match trust root")
    candidate_commit = require_git_id(
        evidence.get("candidateCommit"),
        "evidence candidateCommit",
    )
    candidate_tree = require_git_id(
        evidence.get("candidateTree"),
        "evidence candidateTree",
    )
    if run_git(root, "cat-file", "-t", candidate_commit) != "commit":
        fail("evidence candidateCommit must name a repository commit")
    if run_git(root, "cat-file", "-t", candidate_tree) != "tree":
        fail("evidence candidateTree must name a repository tree")
    if run_git(root, "rev-parse", f"{candidate_commit}^{{tree}}") != candidate_tree:
        fail("evidence candidateCommit does not bind candidateTree")
    require_hex(evidence.get("approvedDesignBlob"), "evidence approvedDesignBlob")
    for field in (
        "deviceProfileDigest",
        "deviceIdentityDigest",
        "probeDeviceIdentityDigest",
        "sdkSettingsDigest",
        "sdkSystemVersionDigest",
        "probeMatrixDigest",
        "resultBundleDigest",
        "supportedProfileDigest",
    ):
        require_hex(evidence.get(field), f"evidence {field}")
    if evidence["probeDeviceIdentityDigest"] != evidence["deviceIdentityDigest"]:
        fail(
            "evidence probe deviceIdentityDigest does not match physical "
            "deviceIdentityDigest"
        )
    if evidence.get("platform") != "iOS":
        fail("evidence platform must be iOS")
    if evidence.get("environment") != "physicalDevice":
        fail("evidence environment must be physicalDevice, never simulator")
    for field in ("osVersion", "xcodeVersion", "sdkVersion"):
        value = evidence.get(field)
        if not isinstance(value, str) or IOS_27.match(value) is None:
            fail(f"evidence {field} must have major version 27")
    for field in (
        "osBuild",
        "xcodeBuild",
        "sdkBuild",
        "sdkCanonicalName",
        "signingIdentityClass",
    ):
        if not is_nonempty_string(evidence.get(field)):
            fail(f"evidence {field} must be non-empty")
    framework_observations = validate_framework_observations(
        evidence.get("frameworkAPIAvailability")
    )
    framework_apis = validate_framework_queries(evidence.get("frameworkAPIs"))
    declared_identities = [
        (row["framework"], row["api"]) for row in framework_apis
    ]
    observed_identities = [
        (row["framework"], row["api"]) for row in framework_observations
    ]
    if set(observed_identities) != set(declared_identities):
        fail(
            "evidence framework/API identities are not a bijection with "
            "the declared profile"
        )
    target = validate_target(evidence.get("target"), "evidence target")
    inventory = require_sorted_unique_strings(
        evidence.get("entitlementInventory"),
        "evidence entitlementInventory",
    )
    required = require_sorted_unique_strings(
        evidence.get("requiredEntitlements"),
        "evidence requiredEntitlements",
    )
    sqlite = validate_sqlite(evidence.get("sqlite"), "evidence sqlite")
    transport = validate_transport(evidence.get("transport"), "evidence transport")
    lifecycle = validate_lifecycle(evidence.get("lifecycle"), "evidence lifecycle")
    exact_profile_digest = supported_profile_digest(
        framework_apis=framework_apis,
        target=target,
        required_entitlements=required,
        sqlite=sqlite,
        transport=transport,
        lifecycle=lifecycle,
    )
    if evidence["supportedProfileDigest"] != exact_profile_digest:
        fail("evidence supportedProfileDigest does not match exact profile")
    validate_status_derivation(
        status_value=evidence.get("status"),
        target=target,
        entitlement_inventory=inventory,
        required_entitlements=required,
        sqlite=sqlite,
        transport=transport,
        lifecycle=lifecycle,
        framework_observations=framework_observations,
        label="evidence",
    )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path.cwd())
    parser.add_argument("--trust-root", type=Path, required=True)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--unsigned-output", type=Path)
    mode.add_argument("--verify", type=Path)
    parser.add_argument("--device-profile", type=Path)
    parser.add_argument("--xcode-developer-dir", type=Path)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    verification_time = datetime.now(timezone.utc)
    try:
        collecting = args.unsigned_output is not None
        root, commit, tree = ensure_repository(
            args.root,
            require_clean=collecting,
        )
        trust_path, _trust_raw, trust_root, trust_identity = load_trust_root(
            args.trust_root,
            root,
            verification_time=verification_time,
        )
        if args.unsigned_output is not None:
            if args.device_profile is None or args.xcode_developer_dir is None:
                fail(
                    "collection requires --device-profile and "
                    "--xcode-developer-dir"
                )
            profile_path, profile_raw, profile, profile_identity = load_device_profile(
                args.device_profile,
                root=root,
                trust_root=trust_root,
                commit=commit,
                tree=tree,
                verification_time=verification_time,
            )
            if (
                profile_path == trust_path
                or profile_identity == trust_identity
            ):
                fail(
                    "trust root and device profile path/device-inode "
                    "bindings must be distinct"
                )
            (
                sdk_settings_digest,
                sdk_system_version_digest,
                framework_observations,
            ) = inspect_installed_sdk(
                args.xcode_developer_dir,
                profile,
            )
            report = derive_collection_report(
                commit=commit,
                tree=tree,
                profile_raw=profile_raw,
                profile=profile,
                sdk_settings_digest=sdk_settings_digest,
                sdk_system_version_digest=sdk_system_version_digest,
                framework_observations=framework_observations,
            )
            output = validate_output_path(args.unsigned_output, root)
            if output in {trust_path, profile_path}:
                fail("external input and output paths must be distinct")
            write_exclusive_json(output, report)
            print("qinao K4 platform spike: PASS (unsigned, unadmitted)")
        else:
            if args.device_profile is not None or args.xcode_developer_dir is not None:
                fail(
                    "verification accepts only --verify, --trust-root, and "
                    "the repository binding"
                )
            evidence_path, evidence_raw, evidence_identity = (
                read_evidence_file_from_tree(
                    args.verify,
                    root,
                    tree,
                )
            )
            if (
                evidence_path == trust_path
                or evidence_identity == trust_identity
            ):
                fail(
                    "trust root and evidence path/device-inode bindings "
                    "must be distinct"
                )
            evidence = load_json_bytes(evidence_raw, "evidence")
            require_exact_fields(evidence, EVIDENCE_FIELDS, "evidence")
            errors = validate_signed_document(
                evidence,
                trust_root,
                expected_role="k4-evidence-signer",
                label="evidence",
                verification_time=verification_time,
            )
            if errors:
                fail("; ".join(errors))
            validate_evidence_bindings(
                evidence,
                root=root,
                trust_root=trust_root,
            )
            print(
                "qinao K4 platform spike: PASS "
                "(verified external signature only)"
            )
    except GateError as error:
        print(f"qinao K4 platform spike gate failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
