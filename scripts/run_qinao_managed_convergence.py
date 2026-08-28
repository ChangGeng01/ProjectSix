#!/usr/bin/python3
"""Resume the closed Qinao convergence series without holding authority.

The coordinator is deliberately a small outer dispatcher.  It selects no
operation, risk tier, Wave, receipt, ref, claim, or retry policy.  It executes
only digest-bound endpoint argv templates and treats endpoint observations as
untrusted until their closed identity and observation root are rederived.
"""

from __future__ import annotations

import argparse
import fcntl
import hashlib
import json
import os
import re
import selectors
import signal
import stat
import subprocess
import time
from contextlib import contextmanager, nullcontext
from dataclasses import dataclass
from pathlib import Path
from typing import Callable, Dict, List, Mapping, Optional, Sequence, Tuple


HEX_40 = re.compile(r"[0-9a-f]{40}\Z")
HEX_64 = re.compile(r"[0-9a-f]{64}\Z")
PLACEHOLDER = re.compile(r"\$\{([A-Za-z][A-Za-z0-9]*(?::[a-z0-9][a-z0-9.-]*)?)\}")

ENDPOINT_TIMEOUT_SECONDS = 300.0
ENDPOINT_STREAM_LIMIT_BYTES = 1024 * 1024
PROCESS_GROUP_TERM_GRACE_SECONDS = 1.0
PROCESS_GROUP_KILL_GRACE_SECONDS = 1.0
TRANSITION_LOCK_TIMEOUT_SECONDS = 30.0
TRANSITION_LOCK_POLL_SECONDS = 0.02


class ManagedConvergenceError(Exception):
    """Base class for fail-closed dispatcher errors."""


class ContractError(ManagedConvergenceError):
    """A closed manifest, template, or observation contract is invalid."""


class SourceDriftError(ManagedConvergenceError):
    """The frozen review source changed during dispatch."""


class EndpointUnknownOutcome(ManagedConvergenceError):
    """An endpoint call may have crossed an external boundary."""


class BlockedCondition(ManagedConvergenceError):
    """A required external fact or role is unavailable."""

    def __init__(self, code: str, message: str):
        super().__init__(message)
        self.code = code


@dataclass(frozen=True)
class TransitionSpec:
    transition_id: str
    operation_id: str
    machine: str


TRANSITIONS: Tuple[TransitionSpec, ...] = (
    TransitionSpec("01", "root.admission", "rootAdmission"),
    TransitionSpec("02", "design.edge", "designEdge"),
    TransitionSpec("03", "w0.gates", "historicalWaveV1"),
    TransitionSpec("04", "bootstrap.ledger-v2-migration", "ledgerMigration"),
    TransitionSpec("05", "w1.artifact-mesh-contract-freeze", "steadyStateWaveV2"),
    TransitionSpec("06", "w2.state-and-retention", "steadyStateWaveV2"),
    TransitionSpec("07", "w3.state-projections", "steadyStateWaveV2"),
    TransitionSpec("08", "w3.context-convergence", "steadyStateWaveV2"),
    TransitionSpec("09", "w4.model-adaptive-context", "steadyStateWaveV2"),
    TransitionSpec("10", "w5.automation-apple-effects", "steadyStateWaveV2"),
    TransitionSpec("11", "w6.runtime.observation-values", "steadyStateWaveV2"),
    TransitionSpec("12", "w6.semantic.audit-schema", "steadyStateWaveV2"),
    TransitionSpec("13", "w6.runtime.audit-envelope-freeze", "steadyStateWaveV2"),
    TransitionSpec("14", "w6.semantic.coordinator-behavior", "steadyStateWaveV2"),
    TransitionSpec("15", "w6.runtime.integration-population", "steadyStateWaveV2"),
    TransitionSpec("16", "w6.runtime.engine-cutover", "steadyStateWaveV2"),
    TransitionSpec("17", "w6.runtime-receipt-chain", "runtimeChain"),
    TransitionSpec("18", "w6.apple-lab", "steadyStateWaveV2"),
    TransitionSpec("19", "w6.certification", "steadyStateWaveV2"),
)

MACHINE_STATES: Mapping[str, Tuple[str, ...]] = {
    "rootAdmission": (
        "absent",
        "signingInFlight",
        "receiptPublished",
        "replayRefBound",
        "replayWorkspaceAttached",
        "verified",
    ),
    "designEdge": (
        "candidatePrepared",
        "receiptPublished",
        "exactCommitInstalled",
    ),
    "historicalWaveV1": (
        "categoryDraft",
        "categoryReviewed",
        "categoryImported",
        "provisionalIndex",
        "bundleReviewed",
        "finalTree",
        "reportPublished",
        "receiptPublished",
        "exactLocalCommitInstalled",
    ),
    "ledgerMigration": (
        "k4Absent",
        "k4Collected",
        "k4Signing",
        "k4Signed",
        "k4Verified",
        "k4Imported",
        "candidatePrepared",
        "controllerInFlight",
        "targetInstalled",
        "terminalPublished",
        "verified",
    ),
    "steadyStateWaveV2": (
        "categoryDraft",
        "categoryReviewed",
        "categoryImported",
        "finalTree",
        "candidatePrepared",
        "bundleReviewed",
        "reportPublished",
        "controllerInFlight",
        "targetInstalled",
        "receiptPublished",
        "verified",
    ),
    "runtimeChain": ("absent", "signingInFlight", "published", "verified"),
}

DESIGN_ALREADY_PRESENT = "alreadyPresent"
VERIFY_STATES: Mapping[str, Tuple[str, ...]] = {
    "rootAdmission": ("replayWorkspaceAttached",),
    "designEdge": (DESIGN_ALREADY_PRESENT, "exactCommitInstalled"),
    "historicalWaveV1": ("exactLocalCommitInstalled",),
    "ledgerMigration": ("terminalPublished",),
    "steadyStateWaveV2": ("receiptPublished",),
    "runtimeChain": ("published",),
}
FINAL_STATES: Mapping[str, Tuple[str, ...]] = {
    "rootAdmission": ("verified",),
    "designEdge": (DESIGN_ALREADY_PRESENT, "exactCommitInstalled"),
    "historicalWaveV1": ("exactLocalCommitInstalled",),
    "ledgerMigration": ("verified",),
    "steadyStateWaveV2": ("verified",),
    "runtimeChain": ("verified",),
}

CLOSED_ACTIONS = frozenset(("queryExisting", "invokeOnce", "verifyExisting"))
CLOSED_DISPOSITIONS = frozenset(
    (
        "eligibleFresh",
        "resumeExisting",
        "queryOnly",
        "blocked",
        "quarantined",
        "verified",
    )
)
CLOSED_OUTCOMES = frozenset(("pending", "passed", "unknown", "blocked", "quarantined"))
ALLOWED_PLACEHOLDERS = frozenset(
    (
        "root",
        "sourceSelection",
        "trustRoot",
        "artifactRoot",
        "bootstrapManifest",
        "transitionDirectory",
        "transitionID",
        "operationID",
        "machine",
        "reviewCandidateID",
        "comparisonBaseHEAD",
        "reviewSourceHead",
        "reviewSourceTree",
        "expectedState",
        "expectedObservationRoot",
        "claimKey",
    )
)


@dataclass(frozen=True)
class ReviewSource:
    candidate_id: str
    comparison_base_head: str
    head: str
    tree: str

    def as_dict(self) -> Dict[str, str]:
        return {
            "candidateID": self.candidate_id,
            "comparisonBaseHEAD": self.comparison_base_head,
            "head": self.head,
            "tree": self.tree,
        }


@dataclass(frozen=True)
class FrozenSourceSelection:
    repository_identity: str
    selected_head: str
    selected_tree: str
    review_sources: Mapping[str, ReviewSource]


@dataclass(frozen=True)
class BootstrapToolRow:
    transition_ids: Tuple[str, ...]
    name: str
    sha256: str
    role: str
    endpoint_kind: str


@dataclass(frozen=True)
class BootstrapInputRow:
    transition_id: str
    name: str
    schema: str
    sha256: str
    required_role: str
    device_profile_digest: Optional[str]


@dataclass(frozen=True)
class BootstrapManifest:
    repository_identity: str
    active_plan_path: str
    active_plan_sha256: str
    coordinator_sha256: str
    artifact_root_identity: Mapping[str, object]
    transition_range: Tuple[int, int]
    tool_rows: Mapping[str, BootstrapToolRow]
    input_rows: Mapping[str, BootstrapInputRow]


@dataclass(frozen=True)
class BoundTool:
    path: Path
    sha256: str
    endpoint_kind: str


@dataclass(frozen=True)
class LaunchContext:
    root: Path
    source_selection_path: Path
    trust_root_path: Path
    artifact_root: Path
    bootstrap_manifest_path: Path
    bootstrap_manifest_sha256: str
    selection: FrozenSourceSelection
    manifest: BootstrapManifest
    tools: Mapping[str, BoundTool]
    inputs: Mapping[str, Path]
    contracts: Mapping[str, TransitionContract]
    immutable_files: Mapping[Path, str]


@dataclass(frozen=True)
class AdmittedPolicyProjection:
    """Read-only execution projection derived from the admitted V1 policy."""

    path: Path
    sha256: str
    contracts: Mapping[str, TransitionContract]
    tools: Mapping[str, BoundTool]
    endpoint_rows: Tuple[Mapping[str, object], ...]
    immutable_files: Mapping[Path, str]


@dataclass(frozen=True)
class ActionTemplate:
    action: str
    tool_name: str
    endpoint_kind: str
    argv: Tuple[str, ...]


@dataclass(frozen=True)
class TransitionContract:
    transition: TransitionSpec
    review_source: ReviewSource
    actions: Mapping[str, ActionTemplate]


@dataclass(frozen=True)
class Observation:
    schema: str
    repository_identity: str
    transition_id: str
    operation_id: str
    machine: str
    state: str
    disposition: str
    claim_key: Optional[str]
    outcome: str
    review_source: ReviewSource
    observation_root: str


@dataclass(frozen=True)
class Decision:
    action: str
    code: str


@dataclass(frozen=True)
class DispatchResult:
    status: str
    code: str
    transition_id: str
    operation_id: str
    state: str
    observation_root: str
    claim_key: Optional[str] = None


def canonical_json_bytes(value: object) -> bytes:
    return (
        json.dumps(
            value,
            ensure_ascii=False,
            sort_keys=True,
            separators=(",", ":"),
            allow_nan=False,
        )
        + "\n"
    ).encode("utf-8")


def observation_root(value: Mapping[str, object]) -> str:
    payload = dict(value)
    payload.pop("observationRoot", None)
    return hashlib.sha256(
        b"QINAO-MANAGED-TRANSITION-OBSERVATION-V1\0" + canonical_json_bytes(payload)
    ).hexdigest()


def policy_array_root(name: str, rows: object) -> str:
    """Derive one closed, domain-separated protected-policy array root."""

    if not isinstance(name, str) or not re.fullmatch(r"[A-Za-z][A-Za-z0-9]*", name):
        raise ContractError("protected-policy array root name is invalid")
    if not isinstance(rows, list):
        raise ContractError("protected-policy rooted value must be an array")
    return hashlib.sha256(
        b"QINAO-PROTECTED-COMMAND-POLICY-V1\0"
        + name.encode("ascii")
        + b"\0"
        + canonical_json_bytes(rows)
    ).hexdigest()


def _require_exact_keys(
    value: Mapping[str, object], expected: frozenset, label: str
) -> None:
    actual = frozenset(value)
    if actual != expected:
        missing = sorted(expected - actual)
        extra = sorted(actual - expected)
        raise ContractError(
            f"{label} keys mismatch: missing={missing!r} extra={extra!r}"
        )


def _parse_review_source(value: object) -> ReviewSource:
    if not isinstance(value, dict):
        raise ContractError("reviewSource must be an object")
    _require_exact_keys(
        value,
        frozenset(("candidateID", "comparisonBaseHEAD", "head", "tree")),
        "reviewSource",
    )
    fields = tuple(
        value[name] for name in ("candidateID", "comparisonBaseHEAD", "head", "tree")
    )
    if not all(isinstance(item, str) for item in fields):
        raise ContractError("reviewSource fields must be strings")
    candidate_id, comparison_base_head, head, tree = fields
    if not re.fullmatch(r"(?:0[1-9]|1[0-9])", candidate_id):
        raise ContractError("reviewSource candidateID must be 01 through 19")
    for name, digest in (
        ("comparisonBaseHEAD", comparison_base_head),
        ("head", head),
        ("tree", tree),
    ):
        if HEX_40.fullmatch(digest) is None:
            raise ContractError(f"reviewSource {name} must be full lowercase Git OID")
    return ReviewSource(candidate_id, comparison_base_head, head, tree)


SOURCE_SELECTION_FIELDS = frozenset(
    (
        "schemaVersion",
        "repositoryIdentity",
        "selectedHEAD",
        "selectedTree",
        "approvedDesign",
        "candidateComparisons",
        "reviewerPrincipal",
        "reviewerRole",
        "issuedAt",
        "expiresAt",
        "nonce",
        "signatureAlgorithm",
        "signature",
    )
)
SOURCE_COMPARISON_FIELDS = frozenset(
    (
        "candidateID",
        "comparisonBaseHEAD",
        "head",
        "tree",
        "selected",
        "committedRows",
        "stagedRows",
        "unstagedRows",
        "untrackedRows",
    )
)
APPROVED_DESIGN_FIELDS = frozenset(
    ("path", "commit", "tree", "blob", "byteLength", "sha256")
)


def parse_source_selection(value: Mapping[str, object]) -> FrozenSourceSelection:
    if not isinstance(value, dict):
        raise ContractError("source selection must be an object")
    _require_exact_keys(value, SOURCE_SELECTION_FIELDS, "source selection")
    if value["schemaVersion"] != "QinaoDualSpaceSourceSelectionV1":
        raise ContractError("source selection schemaVersion mismatch")
    repository_identity = value["repositoryIdentity"]
    selected_head = value["selectedHEAD"]
    selected_tree = value["selectedTree"]
    if not isinstance(repository_identity, str) or not repository_identity:
        raise ContractError("source selection repositoryIdentity is invalid")
    if not isinstance(selected_head, str) or HEX_40.fullmatch(selected_head) is None:
        raise ContractError("source selection selectedHEAD must be a full Git OID")
    if not isinstance(selected_tree, str) or HEX_40.fullmatch(selected_tree) is None:
        raise ContractError("source selection selectedTree must be a full Git OID")
    approved_design = value["approvedDesign"]
    if not isinstance(approved_design, dict):
        raise ContractError("source selection approvedDesign must be an object")
    _require_exact_keys(approved_design, APPROVED_DESIGN_FIELDS, "approvedDesign")
    for key in ("path", "commit", "tree", "blob", "sha256"):
        if not isinstance(approved_design[key], str) or not approved_design[key]:
            raise ContractError(f"approvedDesign {key} is invalid")
    if any(
        HEX_40.fullmatch(approved_design[key]) is None
        for key in ("commit", "tree", "blob")
    ):
        raise ContractError("approvedDesign Git identities must be full lowercase OIDs")
    if HEX_64.fullmatch(approved_design["sha256"]) is None:
        raise ContractError("approvedDesign sha256 is invalid")
    if (
        not isinstance(approved_design["byteLength"], int)
        or approved_design["byteLength"] <= 0
    ):
        raise ContractError("approvedDesign byteLength must be positive")
    comparisons = value["candidateComparisons"]
    if not isinstance(comparisons, list) or len(comparisons) != len(TRANSITIONS):
        raise ContractError(
            "source selection must contain exactly nineteen comparisons"
        )
    review_sources: Dict[str, ReviewSource] = {}
    selected_count = 0
    previous_head: Optional[str] = None
    for index, raw_row in enumerate(comparisons, start=1):
        if not isinstance(raw_row, dict):
            raise ContractError("source selection comparison must be an object")
        _require_exact_keys(raw_row, SOURCE_COMPARISON_FIELDS, "source comparison")
        review = _parse_review_source(
            {
                name: raw_row[name]
                for name in ("candidateID", "comparisonBaseHEAD", "head", "tree")
            }
        )
        expected_id = f"{index:02d}"
        if review.candidate_id != expected_id:
            raise ContractError(
                "source selection comparison rows are reordered or missing"
            )
        selected = raw_row["selected"]
        if not isinstance(selected, bool):
            raise ContractError("source comparison selected must be boolean")
        selected_count += int(selected)
        if selected != (index == 1):
            raise ContractError("source comparison row 01 alone must be selected")
        for name in ("committedRows", "stagedRows", "unstagedRows", "untrackedRows"):
            rows = raw_row[name]
            if not isinstance(rows, list):
                raise ContractError(f"source comparison {name} must be an array")
            if name != "committedRows" and rows:
                raise ContractError(f"source comparison {name} must be empty")
        if index == 1:
            if (
                review.comparison_base_head != review.head
                or review.head != selected_head
                or review.tree != selected_tree
                or raw_row["committedRows"]
            ):
                raise ContractError(
                    "source comparison row 01 does not bind the selected base"
                )
        elif review.comparison_base_head != previous_head:
            raise ContractError(
                "source comparison rows do not form one exact HEAD chain"
            )
        previous_head = review.head
        review_sources[expected_id] = review
    if selected_count != 1:
        raise ContractError("source selection must have exactly one selected row")
    return FrozenSourceSelection(
        repository_identity=repository_identity,
        selected_head=selected_head,
        selected_tree=selected_tree,
        review_sources=review_sources,
    )


BOOTSTRAP_MANIFEST_FIELDS = frozenset(
    (
        "schema",
        "repositoryIdentity",
        "activePlan",
        "coordinator",
        "artifactRootIdentity",
        "transitionRange",
        "toolRows",
        "inputRows",
    )
)
BOOTSTRAP_TOOL_FIELDS = frozenset(
    ("transitionIDs", "name", "sha256", "role", "endpointKind")
)
BOOTSTRAP_INPUT_FIELDS = frozenset(
    ("transitionID", "name", "schema", "sha256", "requiredRole")
)
BOOTSTRAP_INPUT_DEVICE_FIELDS = BOOTSTRAP_INPUT_FIELDS | frozenset(
    ("deviceProfileDigest",)
)
BINDING_NAME = re.compile(r"[a-z0-9][a-z0-9.-]*\Z")


def _require_nonempty_string(value: object, label: str) -> str:
    if not isinstance(value, str) or not value:
        raise ContractError(f"{label} must be a non-empty string")
    return value


def parse_bootstrap_manifest(value: Mapping[str, object]) -> BootstrapManifest:
    if not isinstance(value, dict):
        raise ContractError("bootstrap launch manifest must be an object")
    _require_exact_keys(value, BOOTSTRAP_MANIFEST_FIELDS, "bootstrap launch manifest")
    if value["schema"] != "QinaoConvergenceBootstrapLaunchManifestV1":
        raise ContractError("bootstrap launch manifest schema mismatch")
    repository_identity = _require_nonempty_string(
        value["repositoryIdentity"], "bootstrap repositoryIdentity"
    )
    active_plan = value["activePlan"]
    coordinator = value["coordinator"]
    transition_range = value["transitionRange"]
    artifact_identity = value["artifactRootIdentity"]
    for item, expected, label in (
        (active_plan, frozenset(("path", "sha256")), "activePlan"),
        (coordinator, frozenset(("sha256",)), "coordinator"),
        (transition_range, frozenset(("first", "last")), "transitionRange"),
        (
            artifact_identity,
            frozenset(
                (
                    "realPathDigest",
                    "fileSystemID",
                    "directoryFileID",
                    "ownerID",
                    "mode",
                )
            ),
            "artifactRootIdentity",
        ),
    ):
        if not isinstance(item, dict):
            raise ContractError(f"bootstrap {label} must be an object")
        _require_exact_keys(item, expected, f"bootstrap {label}")
    active_plan_path = _require_nonempty_string(active_plan["path"], "activePlan.path")
    if (
        active_plan_path.startswith("/")
        or "\\" in active_plan_path
        or any(part in ("", ".", "..") for part in active_plan_path.split("/"))
    ):
        raise ContractError(
            "activePlan.path must be normalized and repository-relative"
        )
    active_plan_sha = _require_nonempty_string(
        active_plan["sha256"], "activePlan.sha256"
    )
    coordinator_sha = _require_nonempty_string(
        coordinator["sha256"], "coordinator.sha256"
    )
    if (
        HEX_64.fullmatch(active_plan_sha) is None
        or HEX_64.fullmatch(coordinator_sha) is None
    ):
        raise ContractError("bootstrap active-plan/coordinator digests must be SHA-256")
    if transition_range != {"first": 1, "last": 4}:
        raise ContractError("bootstrap transitionRange must be exactly 1 through 4")
    if artifact_identity["mode"] != "0700":
        raise ContractError("artifact root identity mode must be 0700")
    if (
        HEX_64.fullmatch(
            _require_nonempty_string(
                artifact_identity["realPathDigest"],
                "artifactRootIdentity.realPathDigest",
            )
        )
        is None
    ):
        raise ContractError("artifact root realPathDigest must be SHA-256")
    for name in ("fileSystemID", "directoryFileID", "ownerID"):
        if not isinstance(artifact_identity[name], int) or artifact_identity[name] < 0:
            raise ContractError(
                f"artifact root identity {name} must be nonnegative integer"
            )
    raw_tools = value["toolRows"]
    if not isinstance(raw_tools, list) or not raw_tools:
        raise ContractError("bootstrap toolRows must be a non-empty array")
    tool_rows: Dict[str, BootstrapToolRow] = {}
    for raw in raw_tools:
        if not isinstance(raw, dict):
            raise ContractError("bootstrap tool row must be an object")
        _require_exact_keys(raw, BOOTSTRAP_TOOL_FIELDS, "bootstrap tool row")
        name = _require_nonempty_string(raw["name"], "bootstrap tool name")
        if BINDING_NAME.fullmatch(name) is None or name in tool_rows:
            raise ContractError("bootstrap tool name is invalid or duplicate")
        transition_ids = raw["transitionIDs"]
        if (
            not isinstance(transition_ids, list)
            or not transition_ids
            or not all(isinstance(item, str) for item in transition_ids)
            or transition_ids != sorted(set(transition_ids))
            or any(item not in ("01", "02", "03", "04") for item in transition_ids)
        ):
            raise ContractError(
                "bootstrap tool transitionIDs must be a closed 01-04 set"
            )
        digest = _require_nonempty_string(raw["sha256"], "bootstrap tool sha256")
        if HEX_64.fullmatch(digest) is None:
            raise ContractError("bootstrap tool sha256 is invalid")
        role = _require_nonempty_string(raw["role"], "bootstrap tool role")
        endpoint_kind = _require_nonempty_string(
            raw["endpointKind"], "bootstrap endpointKind"
        )
        tool_rows[name] = BootstrapToolRow(
            tuple(transition_ids), name, digest, role, endpoint_kind
        )
    raw_inputs = value["inputRows"]
    if not isinstance(raw_inputs, list) or not raw_inputs:
        raise ContractError("bootstrap inputRows must be a non-empty array")
    input_rows: Dict[str, BootstrapInputRow] = {}
    for raw in raw_inputs:
        if not isinstance(raw, dict):
            raise ContractError("bootstrap input row must be an object")
        actual_fields = frozenset(raw)
        if actual_fields not in (BOOTSTRAP_INPUT_FIELDS, BOOTSTRAP_INPUT_DEVICE_FIELDS):
            raise ContractError("bootstrap input row has an unclosed field set")
        transition_id = _require_nonempty_string(
            raw["transitionID"], "bootstrap input transitionID"
        )
        if transition_id not in ("01", "02", "03", "04"):
            raise ContractError("bootstrap input transitionID must be 01 through 04")
        name = _require_nonempty_string(raw["name"], "bootstrap input name")
        if BINDING_NAME.fullmatch(name) is None or name in input_rows:
            raise ContractError("bootstrap input name is invalid or duplicate")
        schema = _require_nonempty_string(raw["schema"], "bootstrap input schema")
        digest = _require_nonempty_string(raw["sha256"], "bootstrap input sha256")
        if HEX_64.fullmatch(digest) is None:
            raise ContractError("bootstrap input sha256 is invalid")
        required_role = _require_nonempty_string(
            raw["requiredRole"], "bootstrap input requiredRole"
        )
        device_digest = raw.get("deviceProfileDigest")
        if device_digest is not None:
            if (
                transition_id != "04"
                or not isinstance(device_digest, str)
                or HEX_64.fullmatch(device_digest) is None
            ):
                raise ContractError(
                    "deviceProfileDigest is legal only for transition 04"
                )
        input_rows[name] = BootstrapInputRow(
            transition_id, name, schema, digest, required_role, device_digest
        )
    return BootstrapManifest(
        repository_identity=repository_identity,
        active_plan_path=active_plan_path,
        active_plan_sha256=active_plan_sha,
        coordinator_sha256=coordinator_sha,
        artifact_root_identity=dict(artifact_identity),
        transition_range=(1, 4),
        tool_rows=tool_rows,
        input_rows=input_rows,
    )


def parse_bindings(rows: Sequence[str]) -> Dict[str, Path]:
    result: Dict[str, Path] = {}
    for row in rows:
        if not isinstance(row, str) or row.count("=") != 1:
            raise ContractError("binding must be exactly CLOSED_NAME=ABSOLUTE_PATH")
        name, raw_path = row.split("=", 1)
        if BINDING_NAME.fullmatch(name) is None or name in result:
            raise ContractError("binding name is invalid or duplicate")
        path = Path(raw_path)
        if not path.is_absolute():
            raise ContractError("binding path must be absolute")
        result[name] = path
    return result


def resolve_tool_bindings(
    manifest: BootstrapManifest, supplied: Mapping[str, Path]
) -> Mapping[str, Path]:
    expected = frozenset(manifest.tool_rows)
    actual = frozenset(supplied)
    missing = sorted(expected - actual)
    extra = sorted(actual - expected)
    if missing:
        raise BlockedCondition(
            "BLOCKED_MISSING_TOOL_BINDING", f"missing pinned tool bindings: {missing!r}"
        )
    if extra:
        raise ContractError(f"extra caller tool bindings are forbidden: {extra!r}")
    return dict(supplied)


def _is_within(path: Path, parent: Path) -> bool:
    try:
        path.relative_to(parent)
    except ValueError:
        return False
    return True


def _require_canonical_path(path: Path, *, directory: bool = False) -> Path:
    if not path.is_absolute():
        raise ContractError("launch paths must be absolute")
    try:
        resolved = path.resolve(strict=True)
        metadata = path.lstat()
    except FileNotFoundError as error:
        raise BlockedCondition(
            "BLOCKED_LAUNCH_INPUT_UNAVAILABLE", "launch path is absent"
        ) from error
    if resolved != path:
        raise ContractError("launch path must be canonical and contain no symlink")
    if stat.S_ISLNK(metadata.st_mode):
        raise ContractError("launch path cannot be a symlink")
    if directory:
        if not stat.S_ISDIR(metadata.st_mode):
            raise ContractError("launch directory path is not a directory")
    elif not stat.S_ISREG(metadata.st_mode):
        raise ContractError("launch input path is not a regular file")
    return resolved


def _read_canonical_external_json(
    path: Path,
    *,
    repository_root: Path,
    expected_digest: Optional[str] = None,
) -> Tuple[Mapping[str, object], str]:
    path = _require_canonical_path(path)
    if _is_within(path, repository_root):
        raise ContractError("external launch input cannot be repository-local")
    if stat.S_IMODE(path.stat().st_mode) != 0o600:
        raise ContractError("external launch input mode must be 0600")
    digest = _sha256_path(path)
    if expected_digest is not None and digest != expected_digest:
        raise SourceDriftError("external launch input digest mismatch")
    raw = path.read_bytes()
    if hashlib.sha256(raw).hexdigest() != digest:
        raise SourceDriftError("external launch input changed after stable-open")
    return _json_no_duplicates(raw), digest


def load_launch_context(
    *,
    root: Path,
    source_selection: Path,
    trust_root: Path,
    artifact_root: Path,
    bootstrap_manifest: Path,
    expected_bootstrap_manifest_sha256: str,
    expected_coordinator_sha256: str,
    tool_bindings: Mapping[str, Path],
    input_bindings: Mapping[str, Path],
    coordinator_path: Path,
) -> LaunchContext:
    if HEX_64.fullmatch(expected_bootstrap_manifest_sha256) is None:
        raise ContractError("expected bootstrap-manifest digest must be SHA-256")
    if HEX_64.fullmatch(expected_coordinator_sha256) is None:
        raise ContractError("expected coordinator digest must be SHA-256")
    root = _require_canonical_path(root, directory=True)
    artifact_root = _require_canonical_path(artifact_root, directory=True)
    if _is_within(artifact_root, root):
        raise ContractError("artifact root must be repository-external")
    artifact_stat = artifact_root.stat()
    if stat.S_IMODE(artifact_stat.st_mode) != 0o700:
        raise ContractError("artifact root mode must be 0700")
    manifest_value, manifest_digest = _read_canonical_external_json(
        bootstrap_manifest,
        repository_root=root,
        expected_digest=expected_bootstrap_manifest_sha256,
    )
    manifest = parse_bootstrap_manifest(manifest_value)
    coordinator_path = _require_canonical_path(coordinator_path)
    actual_coordinator_digest = _sha256_path(coordinator_path)
    if (
        actual_coordinator_digest != expected_coordinator_sha256
        or manifest.coordinator_sha256 != expected_coordinator_sha256
    ):
        raise SourceDriftError("executing coordinator digest is not the bootstrap pin")
    active_plan = _require_canonical_path(root / manifest.active_plan_path)
    if not _is_within(active_plan, root):
        raise ContractError("active plan escaped the repository")
    active_plan_digest = _sha256_path(active_plan)
    if active_plan_digest != manifest.active_plan_sha256:
        raise SourceDriftError("active plan bytes drifted from bootstrap manifest")
    expected_artifact_identity = {
        "realPathDigest": hashlib.sha256(
            str(artifact_root).encode("utf-8")
        ).hexdigest(),
        "fileSystemID": artifact_stat.st_dev,
        "directoryFileID": artifact_stat.st_ino,
        "ownerID": artifact_stat.st_uid,
        "mode": "0700",
    }
    if dict(manifest.artifact_root_identity) != expected_artifact_identity:
        raise SourceDriftError(
            "artifact root stable identity differs from bootstrap manifest"
        )
    selection_value, selection_digest = _read_canonical_external_json(
        source_selection, repository_root=root
    )
    selection = parse_source_selection(selection_value)
    if selection.repository_identity != manifest.repository_identity:
        raise SourceDriftError("selection and bootstrap repository identities differ")
    trust_value, trust_digest = _read_canonical_external_json(
        trust_root, repository_root=root
    )
    if trust_value.get("schema") != "QinaoAdmissionTrustRootV1":
        raise ContractError("trust-root schema mismatch")
    try:
        selection_row = manifest.input_rows["source-selection"]
        trust_row = manifest.input_rows["trust-root"]
    except KeyError as error:
        raise BlockedCondition(
            "BLOCKED_MISSING_BOOTSTRAP_INPUT_BINDING",
            "bootstrap manifest does not bind source selection and trust root",
        ) from error
    if (
        selection_row.schema != "QinaoDualSpaceSourceSelectionV1"
        or selection_row.sha256 != selection_digest
        or trust_row.schema != "QinaoAdmissionTrustRootV1"
        or trust_row.sha256 != trust_digest
    ):
        raise SourceDriftError(
            "source-selection or trust-root binding digest/schema drift"
        )
    resolved_tool_paths = resolve_tool_bindings(manifest, tool_bindings)
    tools: Dict[str, BoundTool] = {}
    for name, path in resolved_tool_paths.items():
        path = _require_canonical_path(path)
        if _is_within(path, root):
            raise ContractError("bootstrap endpoint must be repository-external")
        row = manifest.tool_rows[name]
        digest = _sha256_path(path, executable=True)
        if digest != row.sha256:
            raise SourceDriftError("bootstrap endpoint digest differs from tool row")
        tools[name] = BoundTool(path, digest, row.endpoint_kind)
    special_inputs = frozenset(("source-selection", "trust-root"))
    expected_supplied_inputs = frozenset(manifest.input_rows) - special_inputs
    actual_supplied_inputs = frozenset(input_bindings)
    missing_inputs = sorted(expected_supplied_inputs - actual_supplied_inputs)
    extra_inputs = sorted(actual_supplied_inputs - expected_supplied_inputs)
    if missing_inputs:
        raise BlockedCondition(
            "BLOCKED_MISSING_BOOTSTRAP_INPUT_BINDING",
            f"missing pinned bootstrap input bindings: {missing_inputs!r}",
        )
    if extra_inputs:
        raise ContractError(
            f"extra caller input bindings are forbidden: {extra_inputs!r}"
        )
    inputs: Dict[str, Path] = {
        "source-selection": source_selection,
        "trust-root": trust_root,
    }
    immutable: Dict[Path, str] = {
        bootstrap_manifest: manifest_digest,
        source_selection: selection_digest,
        trust_root: trust_digest,
        active_plan: active_plan_digest,
    }
    contract_values: Dict[str, Tuple[Mapping[str, object], BootstrapInputRow]] = {}
    for name in sorted(expected_supplied_inputs):
        row = manifest.input_rows[name]
        path = input_bindings[name]
        value, digest = _read_canonical_external_json(
            path, repository_root=root, expected_digest=row.sha256
        )
        inputs[name] = path
        immutable[path] = digest
        if row.schema == "QinaoManagedTransitionEndpointContractV1":
            if row.transition_id in contract_values:
                raise ContractError(
                    "bootstrap transition has duplicate endpoint contracts"
                )
            contract_values[row.transition_id] = (value, row)
    contracts: Dict[str, TransitionContract] = {}
    tool_kinds = {name: row.endpoint_kind for name, row in manifest.tool_rows.items()}
    for row in TRANSITIONS[:4]:
        pair = contract_values.get(row.transition_id)
        if pair is None:
            raise BlockedCondition(
                "BLOCKED_MISSING_BOOTSTRAP_ENDPOINT_TEMPLATE",
                f"transition {row.transition_id} has no exact endpoint template",
            )
        value, _ = pair
        contract = parse_transition_contract(
            value,
            expected=row,
            repository_identity=selection.repository_identity,
            review_source=selection.review_sources[row.transition_id],
            tool_endpoint_kinds=tool_kinds,
            available_bindings=frozenset(manifest.input_rows)
            | frozenset(manifest.tool_rows),
        )
        for template in contract.actions.values():
            tool_row = manifest.tool_rows[template.tool_name]
            if row.transition_id not in tool_row.transition_ids:
                raise ContractError(
                    "endpoint template uses a tool outside its transition set"
                )
        contracts[row.transition_id] = contract
    unused_contracts = sorted(frozenset(contract_values) - frozenset(contracts))
    if unused_contracts:
        raise ContractError(
            "bootstrap manifest contains post-migration endpoint contracts"
        )
    return LaunchContext(
        root=root,
        source_selection_path=source_selection,
        trust_root_path=trust_root,
        artifact_root=artifact_root,
        bootstrap_manifest_path=bootstrap_manifest,
        bootstrap_manifest_sha256=manifest_digest,
        selection=selection,
        manifest=manifest,
        tools=tools,
        inputs=inputs,
        contracts=contracts,
        immutable_files=immutable,
    )


CONTRACT_FIELDS = frozenset(
    (
        "schema",
        "repositoryIdentity",
        "transitionID",
        "operationID",
        "machine",
        "reviewSource",
        "actions",
    )
)
ACTION_TEMPLATE_FIELDS = frozenset(("action", "toolName", "endpointKind", "argv"))
FORBIDDEN_ENDPOINT_KIND_FRAGMENTS = (
    "genericshell",
    "genericcommand",
    "privatekey",
    "signingprovider",
)


def _template_placeholders(template: ActionTemplate) -> frozenset:
    names = set()
    for token in template.argv:
        names.update(PLACEHOLDER.findall(token))
    return frozenset(names)


def parse_transition_contract(
    value: Mapping[str, object],
    *,
    expected: TransitionSpec,
    repository_identity: str,
    review_source: ReviewSource,
    tool_endpoint_kinds: Mapping[str, str],
    available_bindings: frozenset,
) -> TransitionContract:
    if not isinstance(value, dict):
        raise ContractError("transition endpoint contract must be an object")
    _require_exact_keys(value, CONTRACT_FIELDS, "transition endpoint contract")
    if value["schema"] != "QinaoManagedTransitionEndpointContractV1":
        raise ContractError("transition endpoint contract schema mismatch")
    if value["repositoryIdentity"] != repository_identity:
        raise SourceDriftError("transition endpoint contract repository drift")
    if value["transitionID"] != expected.transition_id:
        raise SourceDriftError("transition endpoint contract transition drift")
    if value["operationID"] != expected.operation_id:
        raise SourceDriftError("transition endpoint contract operation drift")
    if value["machine"] != expected.machine:
        raise SourceDriftError("transition endpoint contract machine drift")
    if _parse_review_source(value["reviewSource"]) != review_source:
        raise SourceDriftError("transition endpoint contract review-source drift")
    raw_actions = value["actions"]
    if not isinstance(raw_actions, dict):
        raise ContractError("transition endpoint actions must be an object")
    if frozenset(raw_actions) != CLOSED_ACTIONS:
        raise ContractError(
            "transition endpoint actions must be the exact closed action set"
        )
    parsed_actions: Dict[str, ActionTemplate] = {}
    common_required = frozenset(
        (
            "transitionID",
            "operationID",
            "sourceSelection",
            "trustRoot",
            "reviewSourceHead",
            "reviewSourceTree",
        )
    )
    dynamic_required = frozenset(
        ("expectedState", "expectedObservationRoot", "claimKey")
    )
    if not {"source-selection", "trust-root"}.issubset(available_bindings):
        raise ContractError("source-selection and trust-root bindings are mandatory")
    for action in sorted(CLOSED_ACTIONS):
        raw_template = raw_actions[action]
        if not isinstance(raw_template, dict):
            raise ContractError(f"{action} template must be an object")
        _require_exact_keys(raw_template, ACTION_TEMPLATE_FIELDS, f"{action} template")
        if raw_template["action"] != action:
            raise ContractError(f"{action} template action mismatch")
        tool_name = raw_template["toolName"]
        endpoint_kind = raw_template["endpointKind"]
        argv = raw_template["argv"]
        if not isinstance(tool_name, str) or not isinstance(endpoint_kind, str):
            raise ContractError(
                f"{action} tool and endpoint identities must be strings"
            )
        if tool_endpoint_kinds.get(tool_name) != endpoint_kind:
            raise ContractError(f"{action} endpoint differs from the pinned tool row")
        folded_kind = endpoint_kind.casefold().replace("-", "").replace("_", "")
        if any(
            fragment in folded_kind for fragment in FORBIDDEN_ENDPOINT_KIND_FRAGMENTS
        ):
            raise ContractError(
                f"{action} cannot call a generic shell or provider endpoint"
            )
        if not isinstance(argv, list) or not all(
            isinstance(item, str) for item in argv
        ):
            raise ContractError(f"{action} argv must be a string array")
        template = ActionTemplate(action, tool_name, endpoint_kind, tuple(argv))
        validate_template(template)
        placeholders = _template_placeholders(template)
        for placeholder in placeholders:
            if placeholder.startswith("tool:") or placeholder.startswith("input:"):
                _, binding_name = placeholder.split(":", 1)
                if binding_name not in available_bindings:
                    raise ContractError(
                        f"{action} references an unbound endpoint/input {binding_name}"
                    )
        required = common_required
        if expected.transition_id == "04":
            required = required | frozenset(("transitionDirectory",))
        if action != "queryExisting":
            required = required | dynamic_required
        if not required.issubset(placeholders):
            raise ContractError(f"{action} template omits frozen identity placeholders")
        if action == "queryExisting" and placeholders & dynamic_required:
            raise ContractError(
                "queryExisting cannot depend on a prior local observation"
            )
        parsed_actions[action] = template
    return TransitionContract(expected, review_source, parsed_actions)


POLICY_ARRAY_ROOT_FIELDS: Mapping[str, str] = {
    "operationBindings": "operationBindingsRoot",
    "evidenceRetentionPolicyRows": "evidenceRetentionPolicyRowsRoot",
    "descendantProfiles": "descendantProfilesRoot",
    "executableRows": "executableRowsRoot",
    "invocationTemplates": "invocationTemplatesRoot",
    "toolRows": "toolRowsRoot",
    "commandRows": "commandRowsRoot",
    "externalInputRequirements": "externalInputRequirementRowsRoot",
    "assertionRows": "assertionRowsRoot",
    "operationCoverageRows": "operationCoverageRowsRoot",
    "managedTransitionEndpointRows": "managedTransitionEndpointRowsRoot",
}
POLICY_ROW_ID_FIELDS: Mapping[str, str] = {
    "operationBindings": "operationID",
    "evidenceRetentionPolicyRows": "policyID",
    "descendantProfiles": "profileID",
    "executableRows": "executableID",
    "invocationTemplates": "invocationTemplateID",
    "toolRows": "toolID",
    "commandRows": "commandID",
    "externalInputRequirements": "inputID",
    "assertionRows": "assertionID",
    "operationCoverageRows": "operationID",
    "managedTransitionEndpointRows": "endpointRowID",
}
POLICY_ROW_FIELDS: Mapping[str, frozenset] = {
    "operationBindings": frozenset(
        (
            "operationID",
            "admissionKind",
            "waveSliceID",
            "entrypointID",
            "waveAdmissionEligible",
            "stateMutationEligible",
        )
    ),
    "evidenceRetentionPolicyRows": frozenset(
        (
            "policyID",
            "durationSeconds",
            "startEvent",
            "custodyClass",
            "cleanupReceiptRequired",
        )
    ),
    "descendantProfiles": frozenset(
        (
            "profileID",
            "parentProfileID",
            "executableIDs",
            "invocationTemplateIDs",
            "workingTreeMode",
            "environmentRows",
            "mountRows",
            "fileDescriptorRows",
            "networkMode",
            "maxProcessCount",
            "dynamicLoaderPolicy",
        )
    ),
    "executableRows": frozenset(
        (
            "executableID",
            "toolID",
            "absolutePath",
            "codeIdentityDigest",
            "allowedInvocationTemplateIDs",
        )
    ),
    "invocationTemplates": frozenset(
        (
            "invocationTemplateID",
            "executableID",
            "interpreterScriptToolID",
            "argvGrammar",
            "permitsShell",
            "permitsPATHLookup",
        )
    ),
    "toolRows": frozenset(
        ("toolID", "sourceKind", "path", "gitBlobOID", "mode", "byteLength", "sha256")
    ),
    "commandRows": frozenset(
        (
            "commandID",
            "executableToolID",
            "argv",
            "invocationTemplate",
            "workingTree",
            "authorizedOperationIDs",
            "ordinaryEligible",
            "descendantProfileID",
            "timeoutMilliseconds",
            "cpuSeconds",
            "maxSampledPhysicalFootprint",
            "maxStdoutBytes",
            "maxStderrBytes",
            "resultKind",
            "resultAuthority",
            "resultDigestDomain",
            "resultRelativePath",
            "maxResultBytes",
            "expectedExternalInputIDs",
            "expectedAssertionIDs",
        )
    ),
    "externalInputRequirements": frozenset(
        (
            "inputID",
            "kind",
            "bindingSource",
            "representationKind",
            "manifestSchema",
            "digestDomain",
            "maximumManifestBytes",
            "maximumMembers",
            "maximumRegularBytes",
            "maximumDepth",
            "maximumPathUTF8Bytes",
        )
    ),
    "assertionRows": frozenset(
        (
            "assertionID",
            "commandID",
            "kind",
            "baselineLocator",
            "baselineDigest",
            "mutationLocator",
            "mutationDigest",
            "expectedOutcome",
            "expectedReasonCode",
        )
    ),
    "operationCoverageRows": frozenset(
        (
            "operationID",
            "commandIDs",
            "assertionIDs",
            "externalInputIDs",
            "toolIDs",
            "descendantProfileIDs",
            "executableIDs",
            "invocationTemplateIDs",
            "evidenceRetentionPolicyID",
            "commandRowsRoot",
            "assertionRowsRoot",
            "externalInputRequirementRowsRoot",
            "toolRowsRoot",
            "descendantProfilesRoot",
            "executableRowsRoot",
            "invocationTemplatesRoot",
            "managedTransitionEndpointRowIDs",
            "managedTransitionEndpointRowsRoot",
        )
    ),
    "managedTransitionEndpointRows": frozenset(
        (
            "endpointRowID",
            "transitionID",
            "operationID",
            "action",
            "toolID",
            "executableID",
            "invocationTemplateID",
            "endpointKind",
            "argvTemplate",
            "allowedPlaceholderNames",
            "resultSchema",
        )
    ),
}
POLICY_FIELDS = frozenset(
    ("schema", "policyID", "policyVersion")
    + tuple(POLICY_ARRAY_ROOT_FIELDS)
    + tuple(POLICY_ARRAY_ROOT_FIELDS.values())
)
ENVIRONMENT_ROW_FIELDS = frozenset(
    ("name", "valueKind", "literalValue", "externalInputID")
)
MOUNT_ROW_FIELDS = frozenset(
    ("mountID", "sourceKind", "externalInputID", "destination", "access", "executable")
)
FILE_DESCRIPTOR_ROW_FIELDS = frozenset(("descriptor", "disposition", "capabilityKind"))
POLICY_CLAIM = re.compile(r"qinao-protected-policy-v1:([0-9a-f]{64})\Z")


def _closed_id_array(value: object, label: str) -> Tuple[str, ...]:
    if not isinstance(value, list) or not all(
        isinstance(item, str) and item for item in value
    ):
        raise ContractError(f"{label} must be an array of non-empty strings")
    if value != sorted(value) or len(value) != len(set(value)):
        raise ContractError(f"{label} must be unique and canonically sorted")
    return tuple(value)


def _read_fixed_policy(
    path: Path, expected_digest: str
) -> Tuple[Mapping[str, object], str]:
    """Stable-open the one fixed policy projection with no caller-selected path."""

    try:
        before = path.lstat()
    except FileNotFoundError as error:
        raise BlockedCondition(
            "BLOCKED_MISSING_ADMITTED_POLICY_PROJECTION",
            "the admitted protected-policy projection is absent",
        ) from error
    if stat.S_ISLNK(before.st_mode) or not stat.S_ISREG(before.st_mode):
        raise ContractError(
            "protected-policy projection must be a regular non-symlink file"
        )
    if stat.S_IMODE(before.st_mode) != 0o600:
        raise ContractError("protected-policy projection mode must be 0600")
    if before.st_size <= 0 or before.st_size > 4 * 1024 * 1024:
        raise ContractError(
            "protected-policy projection exceeds its closed size boundary"
        )
    flags = os.O_RDONLY
    if hasattr(os, "O_NOFOLLOW"):
        flags |= os.O_NOFOLLOW
    descriptor = os.open(str(path), flags)
    try:
        opened = os.fstat(descriptor)
        if (opened.st_dev, opened.st_ino) != (before.st_dev, before.st_ino):
            raise SourceDriftError("protected-policy projection changed while opening")
        chunks = []
        total = 0
        while True:
            chunk = os.read(descriptor, 1024 * 1024)
            if not chunk:
                break
            chunks.append(chunk)
            total += len(chunk)
            if total > 4 * 1024 * 1024:
                raise ContractError(
                    "protected-policy projection exceeds its closed size boundary"
                )
        after = os.fstat(descriptor)
        if (
            after.st_dev,
            after.st_ino,
            after.st_size,
            after.st_mtime_ns,
        ) != (before.st_dev, before.st_ino, before.st_size, before.st_mtime_ns):
            raise SourceDriftError(
                "protected-policy projection changed during stable-open"
            )
    finally:
        os.close(descriptor)
    raw = b"".join(chunks)
    digest = hashlib.sha256(raw).hexdigest()
    if digest != expected_digest:
        raise SourceDriftError(
            "protected-policy bytes do not match the terminal claim key"
        )
    return _json_no_duplicates(raw), digest


def _parse_policy_arrays(
    value: Mapping[str, object],
) -> Dict[str, List[Mapping[str, object]]]:
    _require_exact_keys(value, POLICY_FIELDS, "protected-command policy")
    if (
        value["schema"] != "QinaoProtectedCommandPolicyV1"
        or value["policyID"] != "qinao.protected-command-policy.v1"
        or value["policyVersion"] != 1
    ):
        raise ContractError("protected-command policy identity/version mismatch")
    arrays: Dict[str, List[Mapping[str, object]]] = {}
    for array_name, root_name in POLICY_ARRAY_ROOT_FIELDS.items():
        raw_rows = value[array_name]
        if not isinstance(raw_rows, list):
            raise ContractError(f"protected policy {array_name} must be an array")
        rows: List[Mapping[str, object]] = []
        identifiers = []
        id_field = POLICY_ROW_ID_FIELDS[array_name]
        fields = POLICY_ROW_FIELDS[array_name]
        for index, raw_row in enumerate(raw_rows):
            if not isinstance(raw_row, dict):
                raise ContractError(
                    f"protected policy {array_name}[{index}] must be an object"
                )
            _require_exact_keys(
                raw_row, fields, f"protected policy {array_name}[{index}]"
            )
            identifier = raw_row[id_field]
            if not isinstance(identifier, str) or not identifier:
                raise ContractError(
                    f"protected policy {array_name} has an invalid primary ID"
                )
            rows.append(raw_row)
            identifiers.append(identifier)
        if identifiers != sorted(identifiers) or len(identifiers) != len(
            set(identifiers)
        ):
            raise ContractError(
                f"protected policy {array_name} is not uniquely ID-sorted"
            )
        declared_root = value[root_name]
        if (
            not isinstance(declared_root, str)
            or HEX_64.fullmatch(declared_root) is None
        ):
            raise ContractError(f"protected policy {root_name} must be SHA-256")
        if declared_root != policy_array_root(array_name, raw_rows):
            raise ContractError(f"protected policy {root_name} mismatch")
        arrays[array_name] = rows
    return arrays


def _rows_by_id(
    arrays: Mapping[str, List[Mapping[str, object]]], array_name: str
) -> Dict[str, Mapping[str, object]]:
    id_field = POLICY_ROW_ID_FIELDS[array_name]
    return {str(row[id_field]): row for row in arrays[array_name]}


def _validate_profile_rows(arrays: Mapping[str, List[Mapping[str, object]]]) -> None:
    profiles = _rows_by_id(arrays, "descendantProfiles")
    executable_ids = frozenset(_rows_by_id(arrays, "executableRows"))
    template_ids = frozenset(_rows_by_id(arrays, "invocationTemplates"))
    external_input_ids = frozenset(_rows_by_id(arrays, "externalInputRequirements"))
    for profile_id, row in profiles.items():
        parent = row["parentProfileID"]
        if parent is not None and (
            not isinstance(parent, str) or parent not in profiles
        ):
            raise ContractError(f"profile {profile_id} has an unknown parent")
        if not set(
            _closed_id_array(row["executableIDs"], "profile executableIDs")
        ).issubset(executable_ids):
            raise ContractError(
                f"profile {profile_id} references an unknown executable"
            )
        if not set(
            _closed_id_array(
                row["invocationTemplateIDs"], "profile invocationTemplateIDs"
            )
        ).issubset(template_ids):
            raise ContractError(
                f"profile {profile_id} references an unknown invocation template"
            )
        environment_rows = row["environmentRows"]
        mount_rows = row["mountRows"]
        descriptor_rows = row["fileDescriptorRows"]
        if (
            not isinstance(environment_rows, list)
            or not isinstance(mount_rows, list)
            or not isinstance(descriptor_rows, list)
        ):
            raise ContractError(f"profile {profile_id} nested rows must be arrays")
        environment_names = []
        for nested in environment_rows:
            if not isinstance(nested, dict):
                raise ContractError("profile environment row must be an object")
            _require_exact_keys(
                nested, ENVIRONMENT_ROW_FIELDS, "profile environment row"
            )
            name = nested["name"]
            if not isinstance(name, str) or not name:
                raise ContractError("profile environment name must be non-empty")
            environment_names.append(name)
            external_input_id = nested["externalInputID"]
            if (
                external_input_id is not None
                and external_input_id not in external_input_ids
            ):
                raise ContractError(
                    "profile environment row references an unknown external input"
                )
        if environment_names != sorted(environment_names) or len(
            environment_names
        ) != len(set(environment_names)):
            raise ContractError("profile environment rows must be uniquely name-sorted")
        for nested in mount_rows:
            if not isinstance(nested, dict):
                raise ContractError("profile mount row must be an object")
            _require_exact_keys(nested, MOUNT_ROW_FIELDS, "profile mount row")
            external_input_id = nested["externalInputID"]
            if (
                external_input_id is not None
                and external_input_id not in external_input_ids
            ):
                raise ContractError(
                    "profile mount row references an unknown external input"
                )
        for nested in descriptor_rows:
            if not isinstance(nested, dict):
                raise ContractError("profile file-descriptor row must be an object")
            _require_exact_keys(
                nested, FILE_DESCRIPTOR_ROW_FIELDS, "profile file-descriptor row"
            )
        if (
            not isinstance(row["maxProcessCount"], int)
            or isinstance(row["maxProcessCount"], bool)
            or row["maxProcessCount"] <= 0
        ):
            raise ContractError(
                f"profile {profile_id} maxProcessCount must be positive"
            )
        cursor = parent
        visited = {profile_id}
        while cursor is not None:
            if cursor in visited:
                raise ContractError("descendant profile parent graph contains a cycle")
            visited.add(cursor)
            cursor = profiles[cursor]["parentProfileID"]  # type: ignore[assignment]


def _validate_policy_tools(
    launch: LaunchContext,
    arrays: Mapping[str, List[Mapping[str, object]]],
    endpoint_tool_ids: frozenset,
) -> Tuple[Dict[str, BoundTool], Dict[Path, str]]:
    tool_rows = _rows_by_id(arrays, "toolRows")
    executable_rows = _rows_by_id(arrays, "executableRows")
    template_rows = _rows_by_id(arrays, "invocationTemplates")
    tools: Dict[str, BoundTool] = {}
    immutable: Dict[Path, str] = {}
    for tool_id, row in tool_rows.items():
        for name in ("sourceKind", "path", "mode", "sha256"):
            if not isinstance(row[name], str) or not row[name]:
                raise ContractError(f"policy tool {tool_id} {name} must be non-empty")
        mode = row["mode"]
        if re.fullmatch(r"0[0-7]{3}", str(mode)) is None:
            raise ContractError("policy tool mode is not closed octal text")
        if (
            not isinstance(row["byteLength"], int)
            or isinstance(row["byteLength"], bool)
            or row["byteLength"] < 0
        ):
            raise ContractError("policy tool byteLength must be an integer")
        if (
            not isinstance(row["gitBlobOID"], str)
            or HEX_40.fullmatch(row["gitBlobOID"]) is None
        ):
            raise ContractError("policy tool gitBlobOID must be a lowercase full OID")
        digest = row["sha256"]
        if HEX_64.fullmatch(str(digest)) is None:
            raise ContractError("policy tool sha256 must be lowercase SHA-256")
        if tool_id not in endpoint_tool_ids:
            # Candidate/toolchain rows remain policy data. The unprivileged
            # coordinator must never reopen or execute them merely because
            # they share the sole protected policy with dispatcher endpoints.
            continue
        path = _require_canonical_path(Path(str(row["path"])))
        if _is_within(path, launch.root):
            raise ContractError("policy execution tool cannot be repository-local")
        metadata = path.stat()
        if stat.S_IMODE(metadata.st_mode) != int(str(mode), 8):
            raise SourceDriftError("policy tool mode differs from the admitted row")
        if metadata.st_size != row["byteLength"]:
            raise SourceDriftError("policy tool length differs from the admitted row")
        if _sha256_path(path, executable=True) != digest:
            raise SourceDriftError("policy tool bytes differ from the admitted row")
        tools[tool_id] = BoundTool(path, str(digest), "")
        immutable[path] = str(digest)
    for executable_id, row in executable_rows.items():
        tool_id = row["toolID"]
        if not isinstance(tool_id, str) or tool_id not in tool_rows:
            raise ContractError(
                f"policy executable {executable_id} references an unknown tool"
            )
        absolute_path = row["absolutePath"]
        if not isinstance(absolute_path, str) or not Path(absolute_path).is_absolute():
            raise ContractError("policy executable absolutePath must be absolute")
        if row["codeIdentityDigest"] != tool_rows[tool_id]["sha256"]:
            raise SourceDriftError(
                "policy executable code identity differs from its tool row"
            )
        if tool_id in endpoint_tool_ids and absolute_path != str(tools[tool_id].path):
            raise SourceDriftError(
                "policy executable absolutePath differs from its tool row"
            )
        allowed = _closed_id_array(
            row["allowedInvocationTemplateIDs"], "allowedInvocationTemplateIDs"
        )
        if not set(allowed).issubset(template_rows):
            raise ContractError(
                "policy executable allows an unknown invocation template"
            )
    for template_id, row in template_rows.items():
        executable_id = row["executableID"]
        if not isinstance(executable_id, str) or executable_id not in executable_rows:
            raise ContractError(
                f"policy template {template_id} references an unknown executable"
            )
        if row["permitsShell"] is not False or row["permitsPATHLookup"] is not False:
            raise ContractError(
                "managed endpoint invocation cannot permit shell or PATH lookup"
            )
        script_tool = row["interpreterScriptToolID"]
        if script_tool is not None and script_tool not in tool_rows:
            raise ContractError(
                "policy invocation template references an unknown script tool"
            )
        allowed = executable_rows[executable_id]["allowedInvocationTemplateIDs"]
        if template_id not in allowed:
            raise ContractError("invocation template is not admitted by its executable")
    return tools, immutable


def load_admitted_policy_projection(
    launch: LaunchContext, migration_result: DispatchResult
) -> AdmittedPolicyProjection:
    """Reopen the t04-produced policy and derive all t05--t19 calls from it."""

    if (
        migration_result.status != "complete"
        or migration_result.transition_id != "04"
        or migration_result.operation_id != "bootstrap.ledger-v2-migration"
        or migration_result.state != "verified"
    ):
        raise BlockedCondition(
            "BLOCKED_ADMITTED_POLICY_WITHOUT_VERIFIED_MIGRATION",
            "the ledger migration is not terminally verified",
        )
    match = POLICY_CLAIM.fullmatch(migration_result.claim_key or "")
    if match is None:
        raise BlockedCondition(
            "BLOCKED_MISSING_ADMITTED_POLICY_CLAIM",
            "the verified migration did not publish the protected-policy claim key",
        )
    path = transition_directory(launch, "04") / "protected-command-policy-v1.json"
    value, digest = _read_fixed_policy(path, match.group(1))
    arrays = _parse_policy_arrays(value)
    _validate_profile_rows(arrays)
    endpoint_tool_ids = set()
    for row in arrays["managedTransitionEndpointRows"]:
        tool_id = row["toolID"]
        if not isinstance(tool_id, str) or not tool_id:
            raise ContractError("managed endpoint toolID must be a non-empty string")
        endpoint_tool_ids.add(tool_id)
    tools, tool_immutable = _validate_policy_tools(
        launch, arrays, frozenset(endpoint_tool_ids)
    )

    transitions = {row.transition_id: row for row in TRANSITIONS[4:]}
    operations = {row.operation_id: row for row in TRANSITIONS[4:]}
    bindings = _rows_by_id(arrays, "operationBindings")
    coverage = _rows_by_id(arrays, "operationCoverageRows")
    endpoint_rows = _rows_by_id(arrays, "managedTransitionEndpointRows")
    expected_operations = frozenset(operations)
    missing_bindings = expected_operations - frozenset(bindings)
    if missing_bindings:
        raise BlockedCondition(
            "BLOCKED_INCOMPLETE_ADMITTED_POLICY_BINDINGS",
            f"managed operation bindings are missing: {sorted(missing_bindings)!r}",
        )
    missing_coverage = expected_operations - frozenset(coverage)
    if missing_coverage:
        raise BlockedCondition(
            "BLOCKED_INCOMPLETE_ADMITTED_POLICY_COVERAGE",
            f"managed operation coverage is missing: {sorted(missing_coverage)!r}",
        )
    binding_ids = frozenset(bindings)
    coverage_ids = frozenset(coverage)
    if binding_ids - coverage_ids:
        raise BlockedCondition(
            "BLOCKED_INCOMPLETE_ADMITTED_POLICY_COVERAGE",
            "one or more protected operation bindings lack coverage rows",
        )
    if coverage_ids - binding_ids:
        raise ContractError(
            "protected policy coverage has no matching operation binding"
        )
    expected_endpoint_ids = frozenset(
        f"managed.{transition.transition_id}.{action}"
        for transition in TRANSITIONS[4:]
        for action in CLOSED_ACTIONS
    )
    missing_endpoint_ids = expected_endpoint_ids - frozenset(endpoint_rows)
    if missing_endpoint_ids:
        raise BlockedCondition(
            "BLOCKED_INCOMPLETE_ADMITTED_POLICY_ENDPOINTS",
            f"managed endpoint rows are missing: {sorted(missing_endpoint_ids)!r}",
        )
    if frozenset(endpoint_rows) != expected_endpoint_ids:
        raise ContractError(
            "managed endpoint rows must be the exact 15 by 3 closed set"
        )
    for operation_id in sorted(coverage_ids - expected_operations):
        nonmanaged = coverage[operation_id]
        if _closed_id_array(
            nonmanaged["managedTransitionEndpointRowIDs"],
            "nonmanaged managedTransitionEndpointRowIDs",
        ):
            raise ContractError(
                "a nonmanaged operation cannot claim managed endpoint rows"
            )
        if nonmanaged["managedTransitionEndpointRowsRoot"] != policy_array_root(
            "managedTransitionEndpointRows", []
        ):
            raise ContractError(
                "a nonmanaged operation must bind the empty managed endpoint root"
            )

    supporting_ids = {
        "commandIDs": frozenset(_rows_by_id(arrays, "commandRows")),
        "assertionIDs": frozenset(_rows_by_id(arrays, "assertionRows")),
        "externalInputIDs": frozenset(_rows_by_id(arrays, "externalInputRequirements")),
        "toolIDs": frozenset(_rows_by_id(arrays, "toolRows")),
        "descendantProfileIDs": frozenset(_rows_by_id(arrays, "descendantProfiles")),
        "executableIDs": frozenset(_rows_by_id(arrays, "executableRows")),
        "invocationTemplateIDs": frozenset(_rows_by_id(arrays, "invocationTemplates")),
    }
    retention_ids = frozenset(_rows_by_id(arrays, "evidenceRetentionPolicyRows"))
    executable_rows = _rows_by_id(arrays, "executableRows")
    invocation_rows = _rows_by_id(arrays, "invocationTemplates")
    profile_rows = _rows_by_id(arrays, "descendantProfiles")
    external_input_ids = supporting_ids["externalInputIDs"]
    tool_endpoint_kinds: Dict[str, str] = {}
    parsed_by_transition: Dict[str, Dict[str, ActionTemplate]] = {
        transition_id: {} for transition_id in transitions
    }

    for operation_id, transition in operations.items():
        binding = bindings[operation_id]
        expected_binding = {
            "operationID": operation_id,
            "admissionKind": "waveAdmission",
            "waveSliceID": operation_id,
            "entrypointID": "wave-admission-controller",
            "waveAdmissionEligible": True,
            "stateMutationEligible": True,
        }
        if transition.transition_id == "17":
            expected_binding = {
                "operationID": "w6.runtime-receipt-chain",
                "admissionKind": "runtimeChainPublication",
                "waveSliceID": "",
                "entrypointID": "external-admission-verifier",
                "waveAdmissionEligible": False,
                "stateMutationEligible": False,
            }
        if dict(binding) != expected_binding:
            raise ContractError(
                f"managed operation binding {operation_id} is not byte-exact"
            )
        coverage_row = coverage[operation_id]
        for field, known_ids in supporting_ids.items():
            references = _closed_id_array(coverage_row[field], f"coverage {field}")
            if not set(references).issubset(known_ids):
                raise ContractError(
                    f"coverage {operation_id} references an unknown {field}"
                )
        retention = coverage_row["evidenceRetentionPolicyID"]
        if retention is not None and retention not in retention_ids:
            raise ContractError("coverage references an unknown retention policy")
        for root_name in (
            "commandRowsRoot",
            "assertionRowsRoot",
            "externalInputRequirementRowsRoot",
            "toolRowsRoot",
            "descendantProfilesRoot",
            "executableRowsRoot",
            "invocationTemplatesRoot",
        ):
            if coverage_row[root_name] != value[root_name]:
                raise ContractError(
                    f"coverage {operation_id} root differs from policy root"
                )
        expected_ids = tuple(
            sorted(
                f"managed.{transition.transition_id}.{action}"
                for action in CLOSED_ACTIONS
            )
        )
        actual_ids = _closed_id_array(
            coverage_row["managedTransitionEndpointRowIDs"],
            "managedTransitionEndpointRowIDs",
        )
        if actual_ids != expected_ids:
            raise ContractError(
                f"coverage {operation_id} does not bind its exact three endpoints"
            )
        subset = [endpoint_rows[row_id] for row_id in expected_ids]
        if coverage_row["managedTransitionEndpointRowsRoot"] != policy_array_root(
            "managedTransitionEndpointRows", subset
        ):
            raise ContractError(
                f"coverage {operation_id} endpoint subset root mismatch"
            )

        for row_id in expected_ids:
            row = endpoint_rows[row_id]
            action = row["action"]
            if row["endpointRowID"] != f"managed.{transition.transition_id}.{action}":
                raise ContractError(
                    "managed endpoint row ID is not derived from transition/action"
                )
            if (
                row["transitionID"] != transition.transition_id
                or row["operationID"] != operation_id
                or action not in CLOSED_ACTIONS
                or row["resultSchema"] != "QinaoManagedTransitionObservationV1"
            ):
                raise ContractError(
                    "managed endpoint row identity/result schema mismatch"
                )
            tool_id = row["toolID"]
            executable_id = row["executableID"]
            template_id = row["invocationTemplateID"]
            endpoint_kind = row["endpointKind"]
            if not all(
                isinstance(item, str) and item
                for item in (tool_id, executable_id, template_id, endpoint_kind)
            ):
                raise ContractError(
                    "managed endpoint executable identities must be non-empty strings"
                )
            folded_kind = endpoint_kind.casefold().replace("-", "").replace("_", "")
            if any(
                fragment in folded_kind
                for fragment in FORBIDDEN_ENDPOINT_KIND_FRAGMENTS
            ):
                raise ContractError(
                    "managed endpoint row cannot directly invoke shell/provider authority"
                )
            if (
                tool_id not in tools
                or executable_id not in executable_rows
                or template_id not in invocation_rows
            ):
                raise ContractError(
                    "managed endpoint row has an unresolved execution reference"
                )
            executable = executable_rows[executable_id]
            invocation = invocation_rows[template_id]
            if (
                executable["toolID"] != tool_id
                or invocation["executableID"] != executable_id
            ):
                raise ContractError(
                    "managed endpoint tool/executable/template chain is inconsistent"
                )
            if template_id not in executable["allowedInvocationTemplateIDs"]:
                raise ContractError(
                    "managed endpoint template is not admitted by its executable"
                )
            coverage_profiles = coverage_row["descendantProfileIDs"]
            if not any(
                executable_id in profile_rows[profile_id]["executableIDs"]
                and template_id in profile_rows[profile_id]["invocationTemplateIDs"]
                for profile_id in coverage_profiles
            ):
                raise ContractError(
                    "managed endpoint has no coverage-bound descendant profile"
                )
            if (
                tool_id not in coverage_row["toolIDs"]
                or executable_id not in coverage_row["executableIDs"]
                or template_id not in coverage_row["invocationTemplateIDs"]
            ):
                raise ContractError(
                    "managed endpoint execution chain is absent from operation coverage"
                )
            argv = row["argvTemplate"]
            if not isinstance(argv, list) or not all(
                isinstance(token, str) for token in argv
            ):
                raise ContractError(
                    "managed endpoint argvTemplate must be a string array"
                )
            template = ActionTemplate(action, tool_id, endpoint_kind, tuple(argv))
            validate_template(template)
            placeholders = _template_placeholders(template)
            allowed = _closed_id_array(
                row["allowedPlaceholderNames"], "allowedPlaceholderNames"
            )
            if frozenset(allowed) != placeholders:
                raise ContractError(
                    "managed endpoint allowedPlaceholderNames mismatch argvTemplate"
                )
            available_bindings = (
                frozenset(tools)
                | external_input_ids
                | frozenset(("source-selection", "trust-root"))
            )
            for placeholder in placeholders:
                if placeholder.startswith("tool:") or placeholder.startswith("input:"):
                    if placeholder.split(":", 1)[1] not in available_bindings:
                        raise ContractError(
                            "managed endpoint references an unbound placeholder"
                        )
            common_required = frozenset(
                (
                    "transitionID",
                    "operationID",
                    "sourceSelection",
                    "trustRoot",
                    "reviewSourceHead",
                    "reviewSourceTree",
                )
            )
            dynamic_required = frozenset(
                ("expectedState", "expectedObservationRoot", "claimKey")
            )
            if not common_required.issubset(placeholders):
                raise ContractError(
                    "managed endpoint omits frozen identity placeholders"
                )
            if action == "queryExisting" and placeholders & dynamic_required:
                raise ContractError(
                    "managed query cannot depend on dynamic observation values"
                )
            if action != "queryExisting" and not dynamic_required.issubset(
                placeholders
            ):
                raise ContractError(
                    "managed effect endpoint omits dynamic observation values"
                )
            prior_kind = tool_endpoint_kinds.setdefault(tool_id, endpoint_kind)
            if prior_kind != endpoint_kind:
                raise ContractError(
                    "one policy tool cannot alias multiple endpoint kinds"
                )
            parsed_by_transition[transition.transition_id][action] = template

    contracts = {
        transition_id: TransitionContract(
            transition,
            launch.selection.review_sources[transition_id],
            parsed_by_transition[transition_id],
        )
        for transition_id, transition in transitions.items()
    }
    bound_tools = {
        tool_id: BoundTool(tool.path, tool.sha256, tool_endpoint_kinds[tool_id])
        for tool_id, tool in tools.items()
        if tool_id in tool_endpoint_kinds
    }
    immutable = dict(tool_immutable)
    immutable[path] = digest
    return AdmittedPolicyProjection(
        path=path,
        sha256=digest,
        contracts=contracts,
        tools=bound_tools,
        endpoint_rows=tuple(arrays["managedTransitionEndpointRows"]),
        immutable_files=immutable,
    )


OBSERVATION_FIELDS = frozenset(
    (
        "schema",
        "repositoryIdentity",
        "transitionID",
        "operationID",
        "machine",
        "state",
        "disposition",
        "claimKey",
        "outcome",
        "reviewSource",
        "observationRoot",
    )
)


def parse_observation(
    value: Mapping[str, object],
    expected: TransitionSpec,
    repository_identity: str,
    review_source: ReviewSource,
) -> Observation:
    if not isinstance(value, dict):
        raise ContractError("endpoint observation must be an object")
    _require_exact_keys(value, OBSERVATION_FIELDS, "endpoint observation")
    if value["schema"] != "QinaoManagedTransitionObservationV1":
        raise ContractError("endpoint observation schema mismatch")
    if value["repositoryIdentity"] != repository_identity:
        raise SourceDriftError("endpoint observation repository identity drift")
    if value["transitionID"] != expected.transition_id:
        raise SourceDriftError("endpoint observation transition identity drift")
    if value["operationID"] != expected.operation_id:
        raise SourceDriftError("endpoint observation operation identity drift")
    if value["machine"] != expected.machine:
        raise SourceDriftError("endpoint observation machine identity drift")
    parsed_review = _parse_review_source(value["reviewSource"])
    if parsed_review != review_source:
        raise SourceDriftError("endpoint observation review-source drift")
    state = value["state"]
    if not isinstance(state, str):
        raise ContractError("endpoint observation state must be a string")
    legal_states = set(MACHINE_STATES[expected.machine])
    if expected.machine == "designEdge":
        legal_states.add(DESIGN_ALREADY_PRESENT)
    if state not in legal_states:
        raise ContractError("endpoint observation state is outside the closed machine")
    disposition = value["disposition"]
    if disposition not in CLOSED_DISPOSITIONS:
        raise ContractError("endpoint observation disposition is invalid")
    outcome = value["outcome"]
    if outcome not in CLOSED_OUTCOMES:
        raise ContractError("endpoint observation outcome is invalid")
    claim_key = value["claimKey"]
    if claim_key is not None and (not isinstance(claim_key, str) or not claim_key):
        raise ContractError("claimKey must be null or a non-empty opaque string")
    initial_states = {MACHINE_STATES[expected.machine][0]}
    if expected.machine == "designEdge":
        initial_states.add(DESIGN_ALREADY_PRESENT)
    if state not in initial_states and claim_key is None:
        raise ContractError(
            "a noninitial state requires an existing durable claim identity"
        )
    root = value["observationRoot"]
    if not isinstance(root, str) or HEX_64.fullmatch(root) is None:
        raise ContractError("observationRoot must be lowercase SHA-256")
    if root != observation_root(value):
        raise ContractError("endpoint observation root mismatch")
    return Observation(
        schema="QinaoManagedTransitionObservationV1",
        repository_identity=repository_identity,
        transition_id=expected.transition_id,
        operation_id=expected.operation_id,
        machine=expected.machine,
        state=state,
        disposition=disposition,
        claim_key=claim_key,
        outcome=outcome,
        review_source=parsed_review,
        observation_root=root,
    )


def validate_template(template: ActionTemplate) -> None:
    if template.action not in CLOSED_ACTIONS:
        raise ContractError(
            "endpoint action is outside queryExisting|invokeOnce|verifyExisting"
        )
    if not template.tool_name or not template.endpoint_kind:
        raise ContractError(
            "endpoint template requires closed tool and endpoint identities"
        )
    if not template.argv:
        raise ContractError("endpoint argv template must be non-empty")
    for token in template.argv:
        if not isinstance(token, str) or not token or "\x00" in token:
            raise ContractError(
                "endpoint argv tokens must be non-empty strings without NUL"
            )
        if any(character in token for character in (";", "\n", "\r", "`")):
            raise ContractError("shell syntax is forbidden in endpoint argv templates")
        if "$(" in token or "$HOME" in token or "${env:" in token:
            raise ContractError("environment and shell expansion are forbidden")
        names = PLACEHOLDER.findall(token)
        if "${" in token and not names:
            raise ContractError("malformed endpoint placeholder")
        for name in names:
            dynamic_binding = name.startswith("tool:") or name.startswith("input:")
            if name not in ALLOWED_PLACEHOLDERS and not dynamic_binding:
                raise ContractError(f"unknown or authority-bearing placeholder: {name}")
        without_placeholders = PLACEHOLDER.sub("", token)
        if "$" in without_placeholders:
            raise ContractError("ambient environment expansion is forbidden")


def render_argv(
    template: ActionTemplate, context: Mapping[str, str]
) -> Tuple[str, ...]:
    validate_template(template)
    rendered = []
    for token in template.argv:

        def replace(match: re.Match) -> str:
            name = match.group(1)
            if name not in context:
                raise ContractError(f"missing closed argv value for {name}")
            value = context[name]
            if (
                not isinstance(value, str)
                or "\x00" in value
                or "\n" in value
                or "\r" in value
            ):
                raise ContractError(f"invalid closed argv value for {name}")
            return value

        rendered.append(PLACEHOLDER.sub(replace, token))
    return tuple(rendered)


def decide(observation: Observation, transition: TransitionSpec) -> Decision:
    if observation.outcome == "unknown" or observation.disposition == "queryOnly":
        return Decision("blocked", "BLOCKED_UNKNOWN_OUTCOME_QUERY_ONLY")
    if observation.outcome == "quarantined" or observation.disposition == "quarantined":
        return Decision("quarantined", "QUARANTINED_EXTERNAL_POSTSTATE")
    if observation.outcome == "blocked" or observation.disposition == "blocked":
        return Decision("blocked", "BLOCKED_EXTERNAL_CONDITION")
    if observation.state in FINAL_STATES[transition.machine]:
        if observation.outcome != "passed" and observation.disposition != "verified":
            if observation.state in VERIFY_STATES[transition.machine]:
                return Decision("verifyExisting", "VERIFY_EXISTING_TERMINAL")
        if observation.disposition == "verified" or observation.outcome == "passed":
            return Decision("complete", "VERIFIED_TRANSITION_TERMINAL")
    if observation.state in VERIFY_STATES[transition.machine]:
        return Decision("verifyExisting", "VERIFY_EXISTING_TERMINAL")
    if observation.disposition not in ("eligibleFresh", "resumeExisting"):
        return Decision("blocked", "BLOCKED_INVALID_RESUME_DISPOSITION")
    return Decision("invokeOnce", "INVOKE_EXACT_EXISTING_OR_FRESH_OPERATION")


def _context_for(
    contract: TransitionContract,
    base_context: Mapping[str, str],
    observation: Optional[Observation] = None,
) -> Dict[str, str]:
    result = dict(base_context)
    result.update(
        {
            "transitionID": contract.transition.transition_id,
            "operationID": contract.transition.operation_id,
            "machine": contract.transition.machine,
            "reviewCandidateID": contract.review_source.candidate_id,
            "comparisonBaseHEAD": contract.review_source.comparison_base_head,
            "reviewSourceHead": contract.review_source.head,
            "reviewSourceTree": contract.review_source.tree,
        }
    )
    if observation is not None:
        result.update(
            {
                "expectedState": observation.state,
                "expectedObservationRoot": observation.observation_root,
                "claimKey": observation.claim_key or "",
            }
        )
    return result


def _validate_callback_observation(
    observation: Observation,
    contract: TransitionContract,
    repository_identity: str,
) -> None:
    if observation.repository_identity != repository_identity:
        raise SourceDriftError("callback repository identity drift")
    if (
        observation.transition_id != contract.transition.transition_id
        or observation.operation_id != contract.transition.operation_id
        or observation.machine != contract.transition.machine
        or observation.review_source != contract.review_source
    ):
        raise SourceDriftError("callback transition or review-source drift")


def _call_action(
    action: str,
    contract: TransitionContract,
    context: Mapping[str, str],
    call: Callable[[str, Tuple[str, ...]], Observation],
) -> Observation:
    try:
        template = contract.actions[action]
    except KeyError as error:
        raise ContractError(f"missing exact {action} endpoint template") from error
    if template.action != action:
        raise ContractError("endpoint template action/key mismatch")
    return call(action, render_argv(template, context))


def _state_index(transition: TransitionSpec, state: str) -> int:
    if transition.machine == "designEdge" and state == DESIGN_ALREADY_PRESENT:
        return len(MACHINE_STATES[transition.machine])
    return MACHINE_STATES[transition.machine].index(state)


def dispatch_one_step(
    contract: TransitionContract,
    repository_identity: str,
    base_context: Mapping[str, str],
    call: Callable[[str, Tuple[str, ...]], Observation],
) -> DispatchResult:
    """Query, perform at most one edge, then query before any further effect."""

    for action in CLOSED_ACTIONS:
        if action not in contract.actions:
            raise ContractError(f"transition lacks closed {action} action")
    first = _call_action(
        "queryExisting", contract, _context_for(contract, base_context), call
    )
    _validate_callback_observation(first, contract, repository_identity)
    decision = decide(first, contract.transition)
    if decision.action in ("blocked", "quarantined", "complete"):
        return DispatchResult(
            decision.action if decision.action != "complete" else "complete",
            decision.code,
            first.transition_id,
            first.operation_id,
            first.state,
            first.observation_root,
            first.claim_key,
        )

    try:
        _call_action(
            decision.action,
            contract,
            _context_for(contract, base_context, first),
            call,
        )
    except EndpointUnknownOutcome:
        # The only legal response to an uncertain effect is another query of
        # the same frozen operation identity.
        pass

    after = _call_action(
        "queryExisting", contract, _context_for(contract, base_context), call
    )
    _validate_callback_observation(after, contract, repository_identity)
    if first.claim_key is not None and after.claim_key != first.claim_key:
        return DispatchResult(
            "quarantined",
            "QUARANTINED_CLAIM_IDENTITY_DRIFT",
            after.transition_id,
            after.operation_id,
            after.state,
            after.observation_root,
            after.claim_key,
        )
    if _state_index(contract.transition, after.state) < _state_index(
        contract.transition, first.state
    ):
        return DispatchResult(
            "quarantined",
            "QUARANTINED_STATE_REGRESSION",
            after.transition_id,
            after.operation_id,
            after.state,
            after.observation_root,
            after.claim_key,
        )
    next_decision = decide(after, contract.transition)
    if after.state == first.state and next_decision.action in (
        "invokeOnce",
        "verifyExisting",
    ):
        return DispatchResult(
            "blocked",
            "BLOCKED_NO_PROGRESS_REQUERY_REQUIRED",
            after.transition_id,
            after.operation_id,
            after.state,
            after.observation_root,
            after.claim_key,
        )
    status = next_decision.action
    if status not in ("blocked", "quarantined", "complete"):
        status = "progressed"
    return DispatchResult(
        status,
        next_decision.code,
        after.transition_id,
        after.operation_id,
        after.state,
        after.observation_root,
        after.claim_key,
    )


def _resume_transition_sequence(
    contracts: Mapping[str, TransitionContract],
    *,
    transitions: Tuple[TransitionSpec, ...],
    completion_code: str,
    repository_identity: str,
    base_context_for: Callable[[TransitionContract], Mapping[str, str]],
    caller_for: Callable[
        [TransitionContract], Callable[[str, Tuple[str, ...]], Observation]
    ],
    guard_for: Optional[Callable[[TransitionContract], object]] = None,
) -> DispatchResult:
    if not transitions:
        raise ContractError("internal transition sequence cannot be empty")
    last_result: Optional[DispatchResult] = None
    for row in transitions:
        contract = contracts.get(row.transition_id)
        if contract is None:
            code = (
                "BLOCKED_MISSING_BOOTSTRAP_ENDPOINT_TEMPLATE"
                if int(row.transition_id) <= 4
                else "BLOCKED_MISSING_ADMITTED_POLICY_TEMPLATE"
            )
            raise BlockedCondition(
                code, f"missing exact contract for transition {row.transition_id}"
            )
        if contract.transition != row:
            raise SourceDriftError(
                "transition contract no longer matches the closed registry"
            )
        guard = nullcontext() if guard_for is None else guard_for(contract)
        with guard:  # type: ignore[attr-defined]
            call = caller_for(contract)
            maximum_queries = len(MACHINE_STATES[row.machine]) + 4
            for _ in range(maximum_queries):
                result = dispatch_one_step(
                    contract,
                    repository_identity,
                    base_context_for(contract),
                    call,
                )
                last_result = result
                if result.status == "complete":
                    break
                if result.status in ("blocked", "quarantined"):
                    return result
                if result.status != "progressed":
                    raise ContractError("dispatcher produced an unclosed status")
            else:
                return DispatchResult(
                    "blocked",
                    "BLOCKED_BOUNDED_PROGRESS_EXHAUSTED",
                    row.transition_id,
                    row.operation_id,
                    last_result.state if last_result is not None else "unobserved",
                    last_result.observation_root
                    if last_result is not None
                    else "0" * 64,
                    last_result.claim_key if last_result is not None else None,
                )
    if last_result is None:
        raise ContractError("closed transition registry is unexpectedly empty")
    return DispatchResult(
        "complete",
        completion_code,
        transitions[-1].transition_id,
        transitions[-1].operation_id,
        last_result.state,
        last_result.observation_root,
        last_result.claim_key,
    )


def resume_contract_series(
    contracts: Mapping[str, TransitionContract],
    *,
    repository_identity: str,
    base_context_for: Callable[[TransitionContract], Mapping[str, str]],
    caller_for: Callable[
        [TransitionContract], Callable[[str, Tuple[str, ...]], Observation]
    ],
    guard_for: Optional[Callable[[TransitionContract], object]] = None,
) -> DispatchResult:
    """Resume the sole 19-transition registry in order.

    The public library operation has no previous-receipt or phase input. It
    always spans the complete registry; the fixed bootstrap/policy seam used
    by ``run_launch`` is private and cannot be selected from the CLI.
    """

    known_ids = frozenset(row.transition_id for row in TRANSITIONS)
    extra = sorted(frozenset(contracts) - known_ids)
    if extra:
        raise ContractError(
            f"unregistered transition contracts are forbidden: {extra!r}"
        )
    return _resume_transition_sequence(
        contracts,
        transitions=TRANSITIONS,
        completion_code="COMPLETE_MANAGED_CONVERGENCE",
        repository_identity=repository_identity,
        base_context_for=base_context_for,
        caller_for=caller_for,
        guard_for=guard_for,
    )


def _sha256_path(path: Path, *, executable: bool = False) -> str:
    if not path.is_absolute():
        raise ContractError("pinned external path must be absolute")
    try:
        metadata = path.lstat()
    except FileNotFoundError as error:
        raise BlockedCondition(
            "BLOCKED_EXTERNAL_ENDPOINT_UNAVAILABLE", "pinned external path is absent"
        ) from error
    if stat.S_ISLNK(metadata.st_mode) or not stat.S_ISREG(metadata.st_mode):
        raise ContractError("pinned external path must be a regular non-symlink file")
    if executable and (metadata.st_mode & 0o111) == 0:
        raise BlockedCondition(
            "BLOCKED_EXTERNAL_ENDPOINT_UNAVAILABLE", "pinned endpoint is not executable"
        )
    digest = hashlib.sha256()
    descriptor = os.open(str(path), os.O_RDONLY)
    try:
        opened = os.fstat(descriptor)
        if (opened.st_dev, opened.st_ino) != (metadata.st_dev, metadata.st_ino):
            raise SourceDriftError("pinned file changed while opening")
        while True:
            chunk = os.read(descriptor, 1024 * 1024)
            if not chunk:
                break
            digest.update(chunk)
        closed_check = os.fstat(descriptor)
        if (
            closed_check.st_dev,
            closed_check.st_ino,
            closed_check.st_size,
            closed_check.st_mtime_ns,
        ) != (metadata.st_dev, metadata.st_ino, metadata.st_size, metadata.st_mtime_ns):
            raise SourceDriftError("pinned file changed while hashing")
    finally:
        os.close(descriptor)
    return digest.hexdigest()


def _contract_digest(contract: TransitionContract) -> str:
    value = {
        "schema": "QinaoManagedTransitionEndpointContractV1",
        "transitionID": contract.transition.transition_id,
        "operationID": contract.transition.operation_id,
        "machine": contract.transition.machine,
        "reviewSource": contract.review_source.as_dict(),
        "actions": {
            name: {
                "action": template.action,
                "toolName": template.tool_name,
                "endpointKind": template.endpoint_kind,
                "argv": list(template.argv),
            }
            for name, template in sorted(contract.actions.items())
        },
    }
    return hashlib.sha256(canonical_json_bytes(value)).hexdigest()


def _json_no_duplicates(raw: bytes) -> Mapping[str, object]:
    def object_pairs(pairs: List[Tuple[str, object]]) -> Dict[str, object]:
        result: Dict[str, object] = {}
        for key, value in pairs:
            if key in result:
                raise ContractError(f"duplicate JSON key: {key}")
            result[key] = value
        return result

    def reject_nonfinite_constant(token: str) -> object:
        raise ContractError(f"non-finite JSON constant is forbidden: {token}")

    try:
        value = json.loads(
            raw.decode("utf-8"),
            object_pairs_hook=object_pairs,
            parse_constant=reject_nonfinite_constant,
        )
    except ContractError:
        raise
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        raise ContractError(
            "endpoint output is not one canonical JSON object"
        ) from error
    if not isinstance(value, dict):
        raise ContractError("endpoint output must be one JSON object")
    if canonical_json_bytes(value) != raw:
        raise ContractError("endpoint output must be canonical JSON plus one LF")
    return value


ExecutableIdentity = Tuple[int, int, int, int, int]


def _subject_can_write(path: Path) -> bool:
    try:
        return os.access(str(path), os.W_OK, effective_ids=True)
    except TypeError:  # pragma: no cover - effective_ids exists on supported POSIX.
        return os.access(str(path), os.W_OK)


def _require_immutable_executable_namespace(path: Path) -> None:
    """Require a Darwin-safe namespace that the current subject cannot replace."""

    if not path.is_absolute() or path.resolve(strict=True) != path:
        raise ContractError("endpoint executable path must be absolute and canonical")
    components = (path,) + tuple(path.parents)
    for index, component in enumerate(components):
        metadata = component.lstat()
        if stat.S_ISLNK(metadata.st_mode) or metadata.st_uid != 0:
            raise ContractError(
                "endpoint executable and every parent must be root-owned non-symlinks"
            )
        if index == 0:
            if not stat.S_ISREG(metadata.st_mode) or metadata.st_mode & 0o111 == 0:
                raise ContractError("endpoint executable must be a regular executable")
        elif not stat.S_ISDIR(metadata.st_mode):
            raise ContractError("endpoint executable parent must be a directory")
        if _subject_can_write(component):
            raise ContractError(
                "endpoint executable namespace is writable by the current subject"
            )


def _descriptor_digest(descriptor: int) -> str:
    digest = hashlib.sha256()
    os.lseek(descriptor, 0, os.SEEK_SET)
    while True:
        chunk = os.read(descriptor, 1024 * 1024)
        if not chunk:
            break
        digest.update(chunk)
    os.lseek(descriptor, 0, os.SEEK_SET)
    return digest.hexdigest()


def _executable_identity(metadata: os.stat_result) -> ExecutableIdentity:
    return (
        metadata.st_dev,
        metadata.st_ino,
        metadata.st_size,
        metadata.st_mtime_ns,
        stat.S_IMODE(metadata.st_mode),
    )


def _open_verified_executable(tool: BoundTool) -> Tuple[int, ExecutableIdentity]:
    _require_immutable_executable_namespace(tool.path)
    before = tool.path.lstat()
    flags = os.O_RDONLY
    if hasattr(os, "O_NOFOLLOW"):
        flags |= os.O_NOFOLLOW
    if hasattr(os, "O_CLOEXEC"):
        flags |= os.O_CLOEXEC
    descriptor = os.open(str(tool.path), flags)
    try:
        opened = os.fstat(descriptor)
        if (
            opened.st_dev,
            opened.st_ino,
        ) != (before.st_dev, before.st_ino):
            raise SourceDriftError("endpoint executable changed while stable-opening")
        if not stat.S_ISREG(opened.st_mode) or opened.st_mode & 0o111 == 0:
            raise ContractError("stable-opened endpoint is not executable")
        if _descriptor_digest(descriptor) != tool.sha256:
            raise SourceDriftError("stable-opened endpoint digest drifted")
        after = os.fstat(descriptor)
        if _executable_identity(after) != _executable_identity(opened):
            raise SourceDriftError("endpoint executable changed while hashing")
        return descriptor, _executable_identity(opened)
    except BaseException:
        os.close(descriptor)
        raise


def _verify_open_executable(
    descriptor: int, tool: BoundTool, identity: ExecutableIdentity
) -> None:
    if _executable_identity(os.fstat(descriptor)) != identity:
        raise SourceDriftError("stable-opened endpoint changed during invocation")
    if _descriptor_digest(descriptor) != tool.sha256:
        raise SourceDriftError("stable-opened endpoint bytes changed during invocation")
    check_descriptor, check_identity = _open_verified_executable(tool)
    try:
        if check_identity != identity:
            raise SourceDriftError("endpoint path identity changed during invocation")
    finally:
        os.close(check_descriptor)


@dataclass(frozen=True)
class _BoundedProcessResult:
    return_code: Optional[int]
    stdout: bytes
    stderr: bytes
    timed_out: bool
    stream_limit_exceeded: bool


def _collect_bounded_process_output(
    process: subprocess.Popen,
) -> _BoundedProcessResult:
    if process.stdout is None or process.stderr is None:
        raise ContractError("endpoint output pipes were not created")
    stream_by_name = {"stdout": process.stdout, "stderr": process.stderr}
    buffers = {"stdout": bytearray(), "stderr": bytearray()}
    selector = selectors.DefaultSelector()
    for name, stream in stream_by_name.items():
        os.set_blocking(stream.fileno(), False)
        selector.register(stream, selectors.EVENT_READ, name)
    deadline = time.monotonic() + ENDPOINT_TIMEOUT_SECONDS
    timed_out = False
    stream_limit_exceeded = False
    try:
        while selector.get_map():
            return_code = process.poll()
            if return_code is not None and return_code != 0:
                break
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                timed_out = True
                break
            events = selector.select(min(remaining, 0.05))
            for key, _ in events:
                name = key.data
                try:
                    chunk = os.read(key.fileobj.fileno(), 64 * 1024)
                except BlockingIOError:
                    continue
                if not chunk:
                    selector.unregister(key.fileobj)
                    continue
                available = ENDPOINT_STREAM_LIMIT_BYTES - len(buffers[name])
                buffers[name].extend(chunk[:available])
                if len(chunk) > available:
                    stream_limit_exceeded = True
                    break
            if stream_limit_exceeded:
                break
        return_code = process.poll()
        if (
            not timed_out
            and not stream_limit_exceeded
            and return_code is None
            and not selector.get_map()
        ):
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                timed_out = True
            else:
                try:
                    return_code = process.wait(timeout=remaining)
                except subprocess.TimeoutExpired:
                    timed_out = True
        return _BoundedProcessResult(
            return_code,
            bytes(buffers["stdout"]),
            bytes(buffers["stderr"]),
            timed_out,
            stream_limit_exceeded,
        )
    finally:
        selector.close()


def _process_group_exists(process_group_id: int) -> bool:
    try:
        os.killpg(process_group_id, 0)
    except ProcessLookupError:
        return False
    except PermissionError:
        return True
    return True


def _terminate_process_group(process: subprocess.Popen) -> None:
    process_group_id = process.pid
    try:
        os.killpg(process_group_id, signal.SIGTERM)
    except ProcessLookupError:
        pass
    except PermissionError:
        # Darwin can report EPERM after a just-exited session leader has
        # already lost its process group. Reap it; if it is still live, make
        # an individual best-effort termination and keep the outcome unknown.
        if process.poll() is None:
            process.terminate()
            try:
                process.wait(timeout=PROCESS_GROUP_TERM_GRACE_SECONDS)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait(timeout=PROCESS_GROUP_KILL_GRACE_SECONDS)
        return
    term_deadline = time.monotonic() + PROCESS_GROUP_TERM_GRACE_SECONDS
    while _process_group_exists(process_group_id) and time.monotonic() < term_deadline:
        process.poll()
        time.sleep(0.01)
    if _process_group_exists(process_group_id):
        try:
            os.killpg(process_group_id, signal.SIGKILL)
        except ProcessLookupError:
            pass
        except PermissionError:
            if process.poll() is None:
                process.kill()
    try:
        process.wait(timeout=PROCESS_GROUP_KILL_GRACE_SECONDS)
    except subprocess.TimeoutExpired as error:
        raise EndpointUnknownOutcome(
            "endpoint process group did not terminate after SIGKILL"
        ) from error


def _close_process_pipes(process: subprocess.Popen) -> None:
    for stream in (process.stdout, process.stderr):
        if stream is not None:
            stream.close()


class EndpointRunner:
    """Run only pinned schema-scoped endpoints with a sterile environment."""

    def __init__(
        self,
        *,
        repository_identity: str,
        tools: Mapping[str, BoundTool],
        journal: "ObservationJournal",
        immutable_files: Mapping[Path, str],
    ):
        self.repository_identity = repository_identity
        self.tools = dict(tools)
        self.journal = journal
        self.immutable_files = dict(immutable_files)

    def _verify_immutable_files(self) -> None:
        for path, expected_digest in self.immutable_files.items():
            if _sha256_path(path) != expected_digest:
                raise SourceDriftError("pinned selection/contract bytes drifted")

    def call(
        self,
        contract: TransitionContract,
        action: str,
        argv: Tuple[str, ...],
    ) -> Observation:
        if action not in CLOSED_ACTIONS:
            raise ContractError("runner action is outside the closed action set")
        try:
            template = contract.actions[action]
            tool = self.tools[template.tool_name]
        except KeyError as error:
            raise BlockedCondition(
                "BLOCKED_MISSING_TOOL_BINDING",
                "required schema-scoped endpoint is absent",
            ) from error
        if tool.endpoint_kind != template.endpoint_kind:
            raise SourceDriftError("endpoint kind differs from frozen action template")
        executable_descriptor, executable_identity = _open_verified_executable(tool)
        try:
            self._verify_immutable_files()
            contract_digest = _contract_digest(contract)
            empty_digest = hashlib.sha256(b"").hexdigest()
            self.journal.append(
                transition_id=contract.transition.transition_id,
                operation_id=contract.transition.operation_id,
                action=action,
                event="launching",
                contract_sha256=contract_digest,
                observation_root="0" * 64,
                return_code=None,
                stdout_sha256=empty_digest,
                stderr_sha256=empty_digest,
            )
            try:
                process = subprocess.Popen(
                    (str(tool.path),) + tuple(argv),
                    executable=str(tool.path),
                    stdin=subprocess.DEVNULL,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                    shell=False,
                    env=endpoint_environment(),
                    start_new_session=True,
                )
            except OSError as error:
                self.journal.append(
                    transition_id=contract.transition.transition_id,
                    operation_id=contract.transition.operation_id,
                    action=action,
                    event="unknown",
                    contract_sha256=contract_digest,
                    observation_root="0" * 64,
                    return_code=None,
                    stdout_sha256=empty_digest,
                    stderr_sha256=empty_digest,
                )
                raise EndpointUnknownOutcome(
                    "endpoint launch outcome is unknown"
                ) from error
            try:
                try:
                    completed = _collect_bounded_process_output(process)
                except OSError as error:
                    self.journal.append(
                        transition_id=contract.transition.transition_id,
                        operation_id=contract.transition.operation_id,
                        action=action,
                        event="unknown",
                        contract_sha256=contract_digest,
                        observation_root="0" * 64,
                        return_code=process.poll(),
                        stdout_sha256=empty_digest,
                        stderr_sha256=empty_digest,
                    )
                    _terminate_process_group(process)
                    raise EndpointUnknownOutcome(
                        "endpoint stream outcome is unknown"
                    ) from error
                stdout_digest = hashlib.sha256(completed.stdout).hexdigest()
                stderr_digest = hashlib.sha256(completed.stderr).hexdigest()
                residual_process_group = (
                    completed.return_code == 0 and _process_group_exists(process.pid)
                )
                if (
                    completed.timed_out
                    or completed.stream_limit_exceeded
                    or residual_process_group
                    or completed.return_code is None
                    or completed.return_code != 0
                ):
                    self.journal.append(
                        transition_id=contract.transition.transition_id,
                        operation_id=contract.transition.operation_id,
                        action=action,
                        event="unknown",
                        contract_sha256=contract_digest,
                        observation_root="0" * 64,
                        return_code=completed.return_code,
                        stdout_sha256=stdout_digest,
                        stderr_sha256=stderr_digest,
                    )
                    _terminate_process_group(process)
                    raise EndpointUnknownOutcome(
                        "endpoint timeout, output-cap, residual-group, or nonzero "
                        "outcome is unknown"
                    )
            finally:
                _close_process_pipes(process)
            self._verify_immutable_files()
            _verify_open_executable(executable_descriptor, tool, executable_identity)
            parsed = parse_observation(
                _json_no_duplicates(completed.stdout),
                contract.transition,
                self.repository_identity,
                contract.review_source,
            )
            self.journal.append(
                transition_id=contract.transition.transition_id,
                operation_id=contract.transition.operation_id,
                action=action,
                event="observed",
                contract_sha256=contract_digest,
                observation_root=parsed.observation_root,
                return_code=completed.return_code,
                stdout_sha256=stdout_digest,
                stderr_sha256=stderr_digest,
            )
            return parsed
        finally:
            os.close(executable_descriptor)


class ObservationJournal:
    """Append-only content-free diagnostics; never consulted for dispatch."""

    MAX_BYTES = 1024 * 1024

    def __init__(self, path: Path):
        self.path = path

    def append(
        self,
        *,
        transition_id: str,
        operation_id: str,
        action: str,
        event: str,
        contract_sha256: str,
        observation_root: str,
        return_code: Optional[int],
        stdout_sha256: str,
        stderr_sha256: str,
    ) -> None:
        if action not in CLOSED_ACTIONS:
            raise ContractError("journal action is not a closed dispatcher action")
        for name, digest in (
            ("contractSHA256", contract_sha256),
            ("observationRoot", observation_root),
            ("stdoutSHA256", stdout_sha256),
            ("stderrSHA256", stderr_sha256),
        ):
            if HEX_64.fullmatch(digest) is None:
                raise ContractError(f"journal {name} is not SHA-256")
        row = {
            "schema": "QinaoManagedConvergenceDiagnosticProjectionV1",
            "authority": "none-local-diagnostic-projection",
            "transitionID": transition_id,
            "operationID": operation_id,
            "action": action,
            "event": event,
            "contractSHA256": contract_sha256,
            "observationRoot": observation_root,
            "returnCode": return_code,
            "stdoutSHA256": stdout_sha256,
            "stderrSHA256": stderr_sha256,
        }
        self.path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
        encoded = canonical_json_bytes(row)
        flags = os.O_WRONLY | os.O_APPEND | os.O_CREAT
        if hasattr(os, "O_NOFOLLOW"):
            flags |= os.O_NOFOLLOW
        descriptor = os.open(str(self.path), flags, 0o600)
        try:
            os.fchmod(descriptor, 0o600)
            opened = os.fstat(descriptor)
            if not stat.S_ISREG(opened.st_mode):
                raise ContractError("diagnostic projection must be a regular file")
            if opened.st_size + len(encoded) > self.MAX_BYTES:
                raise BlockedCondition(
                    "BLOCKED_DIAGNOSTIC_PROJECTION_CAP",
                    "content-free diagnostic projection reached its fixed cap",
                )
            written = os.write(descriptor, encoded)
            if written != len(encoded):
                raise BlockedCondition(
                    "BLOCKED_DIAGNOSTIC_PROJECTION_WRITE",
                    "diagnostic projection write was incomplete",
                )
            os.fsync(descriptor)
        finally:
            os.close(descriptor)


def endpoint_environment(parent: Optional[Mapping[str, str]] = None) -> Dict[str, str]:
    del parent
    return {
        "LANG": "C",
        "LC_ALL": "C",
        "PYTHONDONTWRITEBYTECODE": "1",
        "TZ": "UTC",
    }


def _ensure_private_directory(path: Path) -> None:
    try:
        os.mkdir(str(path), 0o700)
    except FileExistsError:
        pass
    metadata = path.lstat()
    if stat.S_ISLNK(metadata.st_mode) or not stat.S_ISDIR(metadata.st_mode):
        raise ContractError("transition artifact component must be a real directory")
    if stat.S_IMODE(metadata.st_mode) != 0o700:
        raise ContractError("transition artifact component mode must be 0700")


def transition_directory(launch: LaunchContext, transition_id: str) -> Path:
    if transition_id not in tuple(f"{index:02d}" for index in range(1, 20)):
        raise ContractError("transition directory ID must be 01 through 19")
    selection_digest = launch.manifest.input_rows["source-selection"].sha256
    namespace = launch.artifact_root / selection_digest
    _ensure_private_directory(namespace)
    directory = namespace / f"t{transition_id}"
    _ensure_private_directory(directory)
    return directory


@contextmanager
def transition_lock(launch: LaunchContext, contract: TransitionContract):
    directory = transition_directory(launch, contract.transition.transition_id)
    flags = os.O_RDWR | os.O_CREAT
    if hasattr(os, "O_NOFOLLOW"):
        flags |= os.O_NOFOLLOW
    descriptor = os.open(str(directory / ".dispatcher.lock"), flags, 0o600)
    try:
        os.fchmod(descriptor, 0o600)
        opened = os.fstat(descriptor)
        if not stat.S_ISREG(opened.st_mode):
            raise ContractError("dispatcher lock must be a regular file")
        deadline = time.monotonic() + TRANSITION_LOCK_TIMEOUT_SECONDS
        while True:
            try:
                fcntl.flock(descriptor, fcntl.LOCK_EX | fcntl.LOCK_NB)
                break
            except BlockingIOError as error:
                remaining = deadline - time.monotonic()
                if remaining <= 0:
                    raise BlockedCondition(
                        "BLOCKED_TRANSITION_LOCK_TIMEOUT",
                        "transition dispatcher lock remained contended until deadline",
                    ) from error
                time.sleep(min(TRANSITION_LOCK_POLL_SECONDS, remaining))
        yield
    finally:
        try:
            fcntl.flock(descriptor, fcntl.LOCK_UN)
        finally:
            os.close(descriptor)


def _launch_base_context(
    launch: LaunchContext,
    contract: TransitionContract,
    tools: Optional[Mapping[str, BoundTool]] = None,
) -> Mapping[str, str]:
    context = {
        "root": str(launch.root),
        "sourceSelection": str(launch.source_selection_path),
        "trustRoot": str(launch.trust_root_path),
        "artifactRoot": str(launch.artifact_root),
        "bootstrapManifest": str(launch.bootstrap_manifest_path),
        "transitionDirectory": str(
            transition_directory(launch, contract.transition.transition_id)
        ),
    }
    for name, tool in (launch.tools if tools is None else tools).items():
        context[f"tool:{name}"] = str(tool.path)
    for name, path in launch.inputs.items():
        context[f"input:{name}"] = str(path)
    return context


def _runner_caller_for(
    launch: LaunchContext,
    tools: Mapping[str, BoundTool],
    immutable_files: Mapping[Path, str],
) -> Callable[[TransitionContract], Callable[[str, Tuple[str, ...]], Observation]]:
    def caller_for(contract: TransitionContract):
        directory = transition_directory(launch, contract.transition.transition_id)
        runner = EndpointRunner(
            repository_identity=launch.selection.repository_identity,
            tools=tools,
            journal=ObservationJournal(directory / "dispatcher-observations-v1.jsonl"),
            immutable_files=immutable_files,
        )

        def call(action: str, argv: Tuple[str, ...]) -> Observation:
            return runner.call(contract, action, argv)

        return call

    return caller_for


def run_launch(launch: LaunchContext) -> DispatchResult:
    """Run the fixed bootstrap seam, reopen its policy, then run t05--t19."""

    bootstrap_caller = _runner_caller_for(launch, launch.tools, launch.immutable_files)
    bootstrap_result = _resume_transition_sequence(
        launch.contracts,
        transitions=TRANSITIONS[:4],
        completion_code="COMPLETE_BOOTSTRAP_PREFIX",
        repository_identity=launch.selection.repository_identity,
        base_context_for=lambda contract: _launch_base_context(launch, contract),
        caller_for=bootstrap_caller,
        guard_for=lambda contract: transition_lock(launch, contract),
    )
    if bootstrap_result.status != "complete":
        return bootstrap_result

    policy = load_admitted_policy_projection(launch, bootstrap_result)
    duplicate_tool_ids = frozenset(launch.tools) & frozenset(policy.tools)
    if duplicate_tool_ids:
        raise ContractError(
            f"admitted policy aliases bootstrap tool IDs: {sorted(duplicate_tool_ids)!r}"
        )
    tools = dict(launch.tools)
    tools.update(policy.tools)
    immutable_files = dict(launch.immutable_files)
    for path, digest in policy.immutable_files.items():
        prior = immutable_files.get(path)
        if prior is not None and prior != digest:
            raise SourceDriftError(
                "bootstrap and policy bind one path to different digests"
            )
        immutable_files[path] = digest
    policy_caller = _runner_caller_for(launch, tools, immutable_files)

    return _resume_transition_sequence(
        policy.contracts,
        transitions=TRANSITIONS[4:],
        completion_code="COMPLETE_MANAGED_CONVERGENCE",
        repository_identity=launch.selection.repository_identity,
        base_context_for=lambda contract: _launch_base_context(launch, contract, tools),
        caller_for=policy_caller,
        guard_for=lambda contract: transition_lock(launch, contract),
    )


def _result_object(result: DispatchResult) -> Mapping[str, object]:
    return {
        "schema": "QinaoManagedConvergenceDispatchResultV1",
        "status": result.status,
        "code": result.code,
        "transitionID": result.transition_id,
        "operationID": result.operation_id,
        "state": result.state,
        "observationRoot": result.observation_root,
    }


def _blocked_object(code: str) -> Mapping[str, object]:
    return {
        "schema": "QinaoManagedConvergenceDispatchResultV1",
        "status": "blocked",
        "code": code,
    }


class _ExactlyOnceAction(argparse.Action):
    def __call__(
        self,
        parser: argparse.ArgumentParser,
        namespace: argparse.Namespace,
        values: object,
        option_string: Optional[str] = None,
    ) -> None:
        if getattr(namespace, self.dest, None) is not None:
            parser.error(f"{option_string} must appear exactly once")
        setattr(namespace, self.dest, values)


def _add_resume_arguments(parser: argparse.ArgumentParser) -> None:
    singleton_options = (
        "--root",
        "--source-selection",
        "--trust-root",
        "--artifact-root",
        "--bootstrap-manifest",
        "--expected-bootstrap-manifest-sha256",
        "--expected-coordinator-sha256",
    )
    for option in singleton_options:
        parser.add_argument(
            option,
            required=True,
            default=None,
            action=_ExactlyOnceAction,
        )
    parser.add_argument("--tool-binding", action="append", default=[])
    parser.add_argument("--input-binding", action="append", default=[])


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Resume the one closed Qinao managed convergence series",
        allow_abbrev=False,
    )
    subparsers = parser.add_subparsers(dest="command", required=True)
    resume = subparsers.add_parser("resume-series", allow_abbrev=False)
    _add_resume_arguments(resume)
    return parser


def main(argv: Optional[Sequence[str]] = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        launch = load_launch_context(
            root=Path(args.root),
            source_selection=Path(args.source_selection),
            trust_root=Path(args.trust_root),
            artifact_root=Path(args.artifact_root),
            bootstrap_manifest=Path(args.bootstrap_manifest),
            expected_bootstrap_manifest_sha256=args.expected_bootstrap_manifest_sha256,
            expected_coordinator_sha256=args.expected_coordinator_sha256,
            tool_bindings=parse_bindings(args.tool_binding),
            input_bindings=parse_bindings(args.input_binding),
            coordinator_path=Path(__file__).resolve(),
        )
        result = run_launch(launch)
    except BlockedCondition as error:
        print(canonical_json_bytes(_blocked_object(error.code)).decode("utf-8"), end="")
        return 2
    except EndpointUnknownOutcome:
        print(
            canonical_json_bytes(
                _blocked_object("BLOCKED_ENDPOINT_QUERY_UNAVAILABLE_OR_UNKNOWN")
            ).decode("utf-8"),
            end="",
        )
        return 2
    except SourceDriftError:
        print(
            canonical_json_bytes(_blocked_object("BLOCKED_FROZEN_SOURCE_DRIFT")).decode(
                "utf-8"
            ),
            end="",
        )
        return 2
    except ContractError:
        print(
            canonical_json_bytes(
                _blocked_object("BLOCKED_INVALID_CLOSED_CONTRACT")
            ).decode("utf-8"),
            end="",
        )
        return 2
    print(canonical_json_bytes(_result_object(result)).decode("utf-8"), end="")
    if result.status == "complete":
        return 0
    if result.status == "quarantined":
        return 3
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
