from __future__ import annotations

import ast
import functools
import hashlib
import json
import os
import platform
import re
import signal
import subprocess
import sys
import tempfile
import time
import unicodedata
import unittest
from pathlib import Path
from typing import Any
from unittest import mock


PROJECT_ROOT = Path(__file__).resolve().parents[1]
ORDINARY_WORKFLOW = PROJECT_ROOT / ".github/workflows/test.yml"
PROTECTED_WORKFLOW = PROJECT_ROOT / ".github/workflows/qinao-wave-admission.yml"

PINNED_CHECKOUT = "11bd71901bbe5b1630ceea73d27597364c9af683"
PINNED_SETUP_PYTHON = "a309ff8b426b58ec0e2a45f0f869d46889d02405"
PINNED_UPLOAD_ARTIFACT = "ea165f8d65b6e75b540449e92b4886f43607fa02"
PINNED_DOWNLOAD_ARTIFACT = "d3f86a106a0bac45b974a628896c90dbdf5c8093"
ORDINARY_WORKFLOW_NAME = "Test + boundary checks"
PROTECTED_WORKFLOW_NAME = "Qinao protected unsigned current-wave preparation"
PRIMARY_PYTHON_VERSION = "3.14.5"
ALLOWED_EXTERNAL_USES = {
    f"actions/checkout@{PINNED_CHECKOUT}",
    f"actions/setup-python@{PINNED_SETUP_PYTHON}",
    f"actions/upload-artifact@{PINNED_UPLOAD_ARTIFACT}",
    f"actions/download-artifact@{PINNED_DOWNLOAD_ARTIFACT}",
}
PROTECTED_REF = "refs/heads/qinao-admission-bootstrap-v1"
PROTECTED_REF_GUARD = "${{ github.ref == 'refs/heads/qinao-admission-bootstrap-v1' }}"
FLOOR_MAIN_ONLY_GUARD = (
    "${{ (github.event_name == 'push' || "
    "github.event_name == 'workflow_dispatch') && "
    "github.ref == 'refs/heads/main' }}"
)

QINAO_MODULES = (
    "scripts.test_check_qinao_owner_ledger",
    "scripts.test_run_nonempty_swift_filter",
    "scripts.test_run_nonempty_xcode_test",
    "scripts.test_check_artifact_mesh_device_recovery",
    "scripts.test_run_qinao_wave_admission",
    "scripts.test_prepare_qinao_v2_wave_candidate",
    "scripts.test_run_qinao_managed_convergence",
    "scripts.test_run_qinao_k4_ios27_platform_spike",
    "scripts.test_qinao_admission_canonical_vectors",
    "scripts.test_qinao_plan_remediation",
    "scripts.test_test_workflow_owner_ledger",
)
QINAO_GATE_UNIT_STEP_NAME = "Run Qinao gate units and real report-fixture smoke"
QINAO_GATE_UNIT_RUN = "python3 -m unittest " + " ".join(QINAO_MODULES)
PROTECTED_PYTHON_39_STEP_NAME = "Require protected Python 3.9.6 compatibility proof"
PROTECTED_PYTHON_39_RUN = (
    "set -euo pipefail\n"
    "test -x /usr/bin/python3\n"
    'test "$(/usr/bin/python3 --version 2>&1)" = "Python 3.9.6"\n'
    "/usr/bin/python3 -m unittest \\\n"
    "  scripts.test_check_qinao_owner_ledger.QinaoOwnerLedgerCLITests."
    "test_repository_owner_ledger_runs_under_protected_python_39\n"
)
WORKFLOW_TOP_LEVEL_FIELDS = {"name", "on", "permissions", "jobs"}

ORDINARY_JOBS = {
    "bas-tests",
    "qinao-tests",
    "samplehost-tests",
    "boundary-checks",
    "python-fuzz",
    "rust-tests",
    "qinao-gates",
    "qinao-ios27-floor",
}
PROTECTED_JOBS = {
    "runner-isolation-guard",
    "candidate-validation",
    "prepare-current-wave",
}
ORDINARY_EVENTS = {
    "push": {
        "branches": ["main", "m605-chapter-*", "decode-*"],
    },
    "pull_request": {"branches": ["main"]},
    "workflow_dispatch": None,
}
ORDINARY_JOB_TIMEOUTS = {
    "bas-tests": 30,
    "qinao-tests": 30,
    "samplehost-tests": 45,
    "boundary-checks": 10,
    "python-fuzz": 5,
    "rust-tests": 20,
    "qinao-gates": 20,
    "qinao-ios27-floor": 30,
}
PROTECTED_DISPATCH_INPUTS = {
    "candidate_commit": {
        "description": "Exact candidate commit to evaluate",
        "required": True,
        "type": "string",
    },
    "candidate_tree": {
        "description": ("Exact candidate tree expected for that commit"),
        "required": True,
        "type": "string",
    },
    "current_wave_bundle": {
        "description": ("Normalized current wave-bundle path in the candidate tree"),
        "required": True,
        "type": "string",
    },
}
PROTECTED_JOB_TIMEOUTS = {
    "runner-isolation-guard": 5,
    "candidate-validation": 45,
    "prepare-current-wave": 30,
}

HARDENED_GIT_ENVIRONMENT = {
    "GIT_ATTR_NOSYSTEM": "1",
    "GIT_CONFIG_COUNT": "9",
    "GIT_CONFIG_GLOBAL": "/dev/null",
    "GIT_CONFIG_NOSYSTEM": "1",
    "GIT_CONFIG_SYSTEM": "/dev/null",
    "GIT_CONFIG_KEY_0": "core.fsmonitor",
    "GIT_CONFIG_VALUE_0": "false",
    "GIT_CONFIG_KEY_1": "core.hooksPath",
    "GIT_CONFIG_VALUE_1": "/dev/null",
    "GIT_CONFIG_KEY_2": "diff.external",
    "GIT_CONFIG_VALUE_2": "",
    "GIT_CONFIG_KEY_3": "core.pager",
    "GIT_CONFIG_VALUE_3": "cat",
    "GIT_CONFIG_KEY_4": "submodule.recurse",
    "GIT_CONFIG_VALUE_4": "false",
    "GIT_CONFIG_KEY_5": "filter.lfs.clean",
    "GIT_CONFIG_VALUE_5": "",
    "GIT_CONFIG_KEY_6": "filter.lfs.smudge",
    "GIT_CONFIG_VALUE_6": "",
    "GIT_CONFIG_KEY_7": "filter.lfs.process",
    "GIT_CONFIG_VALUE_7": "",
    "GIT_CONFIG_KEY_8": "filter.lfs.required",
    "GIT_CONFIG_VALUE_8": "false",
    "GIT_LITERAL_PATHSPECS": "1",
    "GIT_NO_LAZY_FETCH": "1",
    "GIT_NO_REPLACE_OBJECTS": "1",
    "GIT_OPTIONAL_LOCKS": "0",
    "GIT_PAGER": "cat",
    "GIT_TERMINAL_PROMPT": "0",
    "PAGER": "cat",
    "XDG_CONFIG_HOME": "/nonexistent",
}

QINAO_GATES_ENVIRONMENT = {
    "QINAO_EXTERNAL_REPLAY_INPUTS_READY": (
        "${{ vars.QINAO_EXTERNAL_REPLAY_INPUTS_READY }}"
    ),
    "QINAO_CURRENT_WAVE_BUNDLE": ("${{ vars.QINAO_CURRENT_WAVE_BUNDLE }}"),
    "QINAO_SOURCE_SELECTION": "${{ vars.QINAO_SOURCE_SELECTION }}",
    "QINAO_ADMISSION_TRUST_ROOT": ("${{ vars.QINAO_ADMISSION_TRUST_ROOT }}"),
    "QINAO_PREVIOUS_ADMISSION_RECEIPT": (
        "${{ vars.QINAO_PREVIOUS_ADMISSION_RECEIPT }}"
    ),
    "QINAO_EXTERNAL_PREREQUISITES": ("${{ vars.QINAO_EXTERNAL_PREREQUISITES }}"),
    "QINAO_PRIOR_ADMISSION_RECEIPTS": ("${{ vars.QINAO_PRIOR_ADMISSION_RECEIPTS }}"),
    "QINAO_RUNTIME_ENTRY_PREDECESSOR": ("${{ vars.QINAO_RUNTIME_ENTRY_PREDECESSOR }}"),
    "QINAO_UNSIGNED_ADMISSION_REPORT": ("${{ vars.QINAO_UNSIGNED_ADMISSION_REPORT }}"),
}
QINAO_GATES_JOB_CONTEXT = {
    "name": "Qinao gate contracts and unsigned report smoke",
    "runs-on": "macos-latest",
    "timeout-minutes": 20,
    "permissions": {"contents": "read"},
    "env": QINAO_GATES_ENVIRONMENT,
}
QINAO_IOS27_FLOOR_RELATIVE = (
    "qinao-ios27-floor-${{ github.run_id }}-${{ github.run_attempt }}"
)
QINAO_IOS27_FLOOR_WORKING_DIRECTORY = (
    "${{ github.workspace }}/${{ env.QINAO_IOS27_FLOOR_RELATIVE }}"
)
QINAO_IOS27_FLOOR_ENVIRONMENT = {
    "QINAO_IOS27_FLOOR_RELATIVE": QINAO_IOS27_FLOOR_RELATIVE,
    **HARDENED_GIT_ENVIRONMENT,
}
QINAO_IOS27_FLOOR_JOB_CONTEXT = {
    "name": "Qinao Xcode 27 floor",
    "needs": "qinao-gates",
    "if": FLOOR_MAIN_ONLY_GUARD,
    "runs-on": {
        "group": "qinao-ios27-jit",
        "labels": ["self-hosted", "macOS", "xcode-27"],
    },
    "timeout-minutes": 30,
    "permissions": {"contents": "read"},
    "env": QINAO_IOS27_FLOOR_ENVIRONMENT,
}
PROTECTED_GUARD_ENVIRONMENT = {
    "QINAO_CANDIDATE_JIT_READY": ("${{ vars.QINAO_CANDIDATE_JIT_READY }}"),
    "QINAO_ADMISSION_JIT_READY": ("${{ vars.QINAO_ADMISSION_JIT_READY }}"),
}
PROTECTED_CANDIDATE_OUTPUTS = {
    "artifact_id": "${{ steps.upload.outputs.artifact-id }}",
    "envelope_sha256": ("${{ steps.snapshot.outputs.envelope_sha256 }}"),
    "envelope_size": "${{ steps.snapshot.outputs.envelope_size }}",
    "log_sha256": "${{ steps.snapshot.outputs.log_sha256 }}",
    "log_size": "${{ steps.snapshot.outputs.log_size }}",
    "manifest_sha256": ("${{ steps.snapshot.outputs.manifest_sha256 }}"),
    "manifest_size": "${{ steps.snapshot.outputs.manifest_size }}",
}
PROTECTED_CANDIDATE_ENVIRONMENT = {
    "QINAO_CANDIDATE_COMMIT": "${{ inputs.candidate_commit }}",
    "QINAO_CANDIDATE_TREE": "${{ inputs.candidate_tree }}",
    "QINAO_CANDIDATE_VALIDATION_RELATIVE": (
        "qinao-candidate-validation-${{ github.run_id }}-${{ github.run_attempt }}"
    ),
    **HARDENED_GIT_ENVIRONMENT,
}
PROTECTED_PREPARE_ENVIRONMENT = {
    "QINAO_CANDIDATE_COMMIT": "${{ inputs.candidate_commit }}",
    "QINAO_CANDIDATE_TREE": "${{ inputs.candidate_tree }}",
    "QINAO_CURRENT_WAVE_BUNDLE_RELATIVE": ("${{ inputs.current_wave_bundle }}"),
    "QINAO_CANDIDATE_ARTIFACT_ID": (
        "${{ needs.candidate-validation.outputs.artifact_id }}"
    ),
    "QINAO_CANDIDATE_ENVELOPE_SHA256": (
        "${{ needs.candidate-validation.outputs.envelope_sha256 }}"
    ),
    "QINAO_CANDIDATE_ENVELOPE_SIZE": (
        "${{ needs.candidate-validation.outputs.envelope_size }}"
    ),
    "QINAO_CANDIDATE_LOG_SHA256": (
        "${{ needs.candidate-validation.outputs.log_sha256 }}"
    ),
    "QINAO_CANDIDATE_LOG_SIZE": ("${{ needs.candidate-validation.outputs.log_size }}"),
    "QINAO_CANDIDATE_MANIFEST_SHA256": (
        "${{ needs.candidate-validation.outputs.manifest_sha256 }}"
    ),
    "QINAO_CANDIDATE_MANIFEST_SIZE": (
        "${{ needs.candidate-validation.outputs.manifest_size }}"
    ),
    "QINAO_SOURCE_SELECTION": "${{ vars.QINAO_SOURCE_SELECTION }}",
    "QINAO_ADMISSION_TRUST_ROOT": ("${{ vars.QINAO_ADMISSION_TRUST_ROOT }}"),
    "QINAO_ADMISSION_TRUST_ROOT_SHA256": (
        "${{ vars.QINAO_ADMISSION_TRUST_ROOT_SHA256 }}"
    ),
    "QINAO_PREVIOUS_ADMISSION_RECEIPT": (
        "${{ vars.QINAO_PREVIOUS_ADMISSION_RECEIPT }}"
    ),
    "QINAO_EXTERNAL_PREREQUISITES": ("${{ vars.QINAO_EXTERNAL_PREREQUISITES }}"),
    "QINAO_PRIOR_ADMISSION_RECEIPTS": ("${{ vars.QINAO_PRIOR_ADMISSION_RECEIPTS }}"),
    "QINAO_RUNTIME_ENTRY_PREDECESSOR": ("${{ vars.QINAO_RUNTIME_ENTRY_PREDECESSOR }}"),
    "QINAO_PROTECTED_WORKFLOW_SHA256": ("${{ vars.QINAO_PROTECTED_WORKFLOW_SHA256 }}"),
    "QINAO_OWNER_LEDGER_CHECKER_SHA256": (
        "${{ vars.QINAO_OWNER_LEDGER_CHECKER_SHA256 }}"
    ),
    "QINAO_REPOSITORY_RUNNER_SHA256": ("${{ vars.QINAO_REPOSITORY_RUNNER_SHA256 }}"),
    "QINAO_TRUSTED_TOOLS_RELATIVE": (
        "qinao-trusted-tools-${{ github.run_id }}-${{ github.run_attempt }}"
    ),
    "QINAO_CANDIDATE_DATA_RELATIVE": (
        "qinao-candidate-data-${{ github.run_id }}-${{ github.run_attempt }}"
    ),
    **HARDENED_GIT_ENVIRONMENT,
}
PROTECTED_JOB_CONTEXTS = {
    "runner-isolation-guard": {
        "runs-on": "ubuntu-latest",
        "timeout-minutes": 5,
        "permissions": {},
        "env": PROTECTED_GUARD_ENVIRONMENT,
    },
    "candidate-validation": {
        "needs": "runner-isolation-guard",
        "if": PROTECTED_REF_GUARD,
        "runs-on": {
            "group": "qinao-candidate-jit",
            "labels": ["self-hosted", "macOS", "xcode-27"],
        },
        "timeout-minutes": 45,
        "permissions": {"contents": "read"},
        "outputs": PROTECTED_CANDIDATE_OUTPUTS,
        "env": PROTECTED_CANDIDATE_ENVIRONMENT,
    },
    "prepare-current-wave": {
        "needs": "candidate-validation",
        "if": PROTECTED_REF_GUARD,
        "environment": "qinao-admission",
        "runs-on": {
            "group": "qinao-admission-jit",
            "labels": ["self-hosted", "macOS", "qinao-admission"],
        },
        "timeout-minutes": 30,
        "permissions": {"actions": "read", "contents": "read"},
        "env": PROTECTED_PREPARE_ENVIRONMENT,
    },
}

EXTERNAL_USE = re.compile(r"^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+@[0-9a-f]{40}$")

YAML_MAX_INPUT_BYTES = 1048576
YAML_MAX_CAPTURE_BYTES = 8388608
YAML_MAX_NODE_COUNT = 100000
YAML_MAX_DEPTH = 128
YAML_PARSER_TIMEOUT_SECONDS = 5

RUBY_RESTRICTED_WORKFLOW_TO_JSON = r"""
source = STDIN.read
max_nodes = Integer(ARGV.fetch(0), 10)
max_depth = Integer(ARGV.fetch(1), 10)
stream = Psych.parse_stream(source)
abort("workflow must contain exactly one YAML document") unless
  stream.children.length == 1
document = stream.children.fetch(0)
version = document.version
abort("workflow document version directives are forbidden") unless
  version.nil? || version.empty?
tag_directives = document.tag_directives
abort("workflow document tag directives are forbidden") unless
  tag_directives.nil? || tag_directives.empty?
abort("workflow document must contain exactly one root") unless
  document.children.length == 1

reject_metadata = lambda do |node|
  abort("YAML aliases are forbidden") if
    node.is_a?(Psych::Nodes::Alias)
  if node.respond_to?(:anchor) && node.anchor
    abort("YAML anchors are forbidden")
  end
  if node.respond_to?(:tag) && node.tag
    abort("explicit YAML tags are forbidden")
  end
end

node_count = 0
inspect_node = lambda do |node, depth|
  abort("YAML depth limit exceeded") if depth > max_depth
  node_count += 1
  abort("YAML node limit exceeded") if node_count > max_nodes
  reject_metadata.call(node)
end

convert = nil
convert = lambda do |node, depth|
  inspect_node.call(node, depth)
  case node
  when Psych::Nodes::Mapping
    abort("YAML mapping children must be key/value pairs") unless
      node.children.length.even?
    value = {}
    node.children.each_slice(2) do |key, child|
      inspect_node.call(key, depth + 1)
      abort("non-scalar YAML key") unless
        key.is_a?(Psych::Nodes::Scalar)
      key_text = key.value
      abort("duplicate YAML key: #{key_text}") if value.key?(key_text)
      value[key_text] = convert.call(child, depth + 1)
    end
    value
  when Psych::Nodes::Sequence
    node.children.map { |child| convert.call(child, depth + 1) }
  when Psych::Nodes::Scalar
    if !node.plain || node.quoted
      node.value
    else
      case node.value
      when "", "~", "null", "Null", "NULL"
        nil
      when "true", "True", "TRUE"
        true
      when "false", "False", "FALSE"
        false
      else
        if /\A-?(?:0|[1-9][0-9]*)\z/.match?(node.value)
          Integer(node.value, 10)
        else
          node.value
        end
      end
    end
  else
    abort("unsupported YAML node: #{node.class}")
  end
end

value = convert.call(document.children.fetch(0), 0)
abort("workflow root is not a mapping") unless value.is_a?(Hash)
STDOUT.write(JSON.generate(value, max_nesting: false))
"""

# Frozen after the second-pass workflow bodies were reviewed. Normalization is
# limited to NFC plus one trailing LF; comments and command order remain bytes.
CRITICAL_RUN_BODY_SHA256 = {
    (
        "ordinary",
        "qinao-gates",
        "Run repository report replay only with external inputs",
    ): "d85d4a012914d25721ca22eaa89262cc6f4ca37586f3e7c7972b8b8d6a3a0263",
    (
        "ordinary",
        "qinao-gates",
        "Require exclusive iOS 27 JIT runner readiness",
    ): "1dcaeaaacbe20763cbbfa0758a7390e995646a7669183e4f1ccf015f53608236",
    (
        "ordinary",
        "qinao-ios27-floor",
        "Assert isolated iOS 27 floor root is absent",
    ): "3f0786e6d1b90892159b1a60bdd0771a52b64eef6de5d6ed4d10b4b6e4100b34",
    (
        "ordinary",
        "qinao-ios27-floor",
        "Assert Xcode 27 toolchain",
    ): "2cf7aa04fe00e060385417cacd727dcd560b674f8fdd84664d2d12c684b334a0",
    (
        "ordinary",
        "qinao-ios27-floor",
        "Run iOS 27 floor unit tests",
    ): "61ee59a01bc1fdc2592450213faaada03f0a1c4791af15390812cd4896cf0163",
    (
        "ordinary",
        "qinao-ios27-floor",
        "Run local iOS 27 floor check",
    ): "9422cfae0ab4b1082ca24a4c8020ecf9cf9819d7c6d96cac7b064d51f2b954ca",
    (
        "protected",
        "runner-isolation-guard",
        "Assert protected bootstrap ref",
    ): "1a3513118cdcae33237c23d2c5c631773dc7474d12c4517bcf08c3f8cc6fcbf8",
    (
        "protected",
        "runner-isolation-guard",
        "Require explicit one-job runner readiness",
    ): "647f8a8623829304be75e1d622deeffc487e88c4a8a80652a13ccb2dfb51c8c8",
    (
        "protected",
        "candidate-validation",
        "Assert isolated candidate root is absent",
    ): "70cac927cb11ef930bb7588edad97e2ae3c2689a74ea2ef0e756b6723218525d",
    (
        "protected",
        "candidate-validation",
        "Validate candidate without admission authority",
    ): "c16b22a5abb831bf2b36c47c08d1cde6c205c92325c1fc60cb37218ba376f584",
    (
        "protected",
        "prepare-current-wave",
        "Assert isolated preparation roots are absent",
    ): "210f2d3435284e52a69389224b3b7d171a5bddd70999885c35c71a88bd4e3eab",
    (
        "protected",
        "prepare-current-wave",
        "Build unsigned report with pinned trusted tools",
    ): "08be825490471d208843a5d424c2f54766ce8e1fb175343740f846f2a4d7139d",
    (
        "protected",
        "prepare-current-wave",
        "Block authority transition until Phase C wire exists",
    ): "ae6e418705c44f705f80e0a1b6335f3e1c9caec0c59b157dc746acf80c305555",
}
PROTECTED_CRITICAL_STEP_CONTEXTS = {
    (
        "runner-isolation-guard",
        "Assert protected bootstrap ref",
    ): {
        "name": "Assert protected bootstrap ref",
        "shell": "bash",
    },
    (
        "runner-isolation-guard",
        "Require explicit one-job runner readiness",
    ): {
        "name": "Require explicit one-job runner readiness",
        "shell": "bash",
    },
    (
        "candidate-validation",
        "Assert isolated candidate root is absent",
    ): {
        "name": "Assert isolated candidate root is absent",
        "shell": "bash",
    },
    (
        "candidate-validation",
        "Validate candidate without admission authority",
    ): {
        "name": "Validate candidate without admission authority",
        "id": "snapshot",
        "shell": "bash",
    },
    (
        "prepare-current-wave",
        "Assert isolated preparation roots are absent",
    ): {
        "name": "Assert isolated preparation roots are absent",
        "shell": "bash",
    },
    (
        "prepare-current-wave",
        "Build unsigned report with pinned trusted tools",
    ): {
        "name": "Build unsigned report with pinned trusted tools",
        "shell": "bash",
    },
    (
        "prepare-current-wave",
        "Block authority transition until Phase C wire exists",
    ): {
        "name": "Block authority transition until Phase C wire exists",
        "if": "${{ always() }}",
        "shell": "bash",
    },
}


def _read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


@functools.lru_cache(maxsize=512)
def _parse_yaml(text: str) -> dict[str, Any]:
    """Parse a restricted YAML 1.2-core subset with string mapping keys."""

    try:
        source = text.encode("utf-8")
    except UnicodeEncodeError as error:
        raise ValueError("workflow YAML is not valid UTF-8") from error
    if len(source) > YAML_MAX_INPUT_BYTES:
        raise ValueError(f"workflow YAML exceeds {YAML_MAX_INPUT_BYTES} UTF-8 bytes")
    try:
        result = subprocess.run(
            [
                "/usr/bin/ruby",
                "-rjson",
                "-rpsych",
                "-e",
                RUBY_RESTRICTED_WORKFLOW_TO_JSON,
                str(YAML_MAX_NODE_COUNT),
                str(YAML_MAX_DEPTH),
            ],
            input=source,
            capture_output=True,
            timeout=YAML_PARSER_TIMEOUT_SECONDS,
            check=False,
        )
    except subprocess.TimeoutExpired as error:
        raise ValueError("workflow YAML parser timed out") from error
    if len(result.stdout) + len(result.stderr) > YAML_MAX_CAPTURE_BYTES:
        raise ValueError(
            f"workflow YAML parser output exceeds {YAML_MAX_CAPTURE_BYTES} bytes"
        )
    try:
        stdout = result.stdout.decode("utf-8")
        stderr = result.stderr.decode("utf-8")
    except UnicodeDecodeError as error:
        raise ValueError("workflow YAML parser returned invalid UTF-8") from error
    if result.returncode != 0:
        raise ValueError(stderr.strip() or "invalid YAML")
    try:
        value = json.loads(stdout)
    except (json.JSONDecodeError, UnicodeDecodeError) as error:
        raise ValueError("workflow YAML parser returned invalid JSON") from error
    if not isinstance(value, dict):
        raise ValueError("workflow root is not a mapping")
    return value


def _normalize_run_body(body: str) -> str:
    if "\x00" in body or "\r" in body:
        raise ValueError("run body contains forbidden NUL/CR bytes")
    return unicodedata.normalize("NFC", body).rstrip("\n") + "\n"


def _run_body_sha256(body: str) -> str:
    return hashlib.sha256(_normalize_run_body(body).encode("utf-8")).hexdigest()


def _events(document: dict[str, Any]) -> dict[str, Any]:
    value = document.get("on")
    return value if isinstance(value, dict) else {}


def _jobs(document: dict[str, Any]) -> dict[str, Any]:
    value = document.get("jobs")
    return value if isinstance(value, dict) else {}


def _steps(job: dict[str, Any]) -> list[dict[str, Any]]:
    value = job.get("steps")
    if not isinstance(value, list):
        return []
    return [step for step in value if isinstance(step, dict)]


def _named_step(job: dict[str, Any], name: str) -> dict[str, Any]:
    matches = [step for step in _steps(job) if step.get("name") == name]
    return matches[0] if len(matches) == 1 else {}


def _uses_steps(document: dict[str, Any]) -> list[dict[str, Any]]:
    return [
        step
        for job in _jobs(document).values()
        if isinstance(job, dict)
        for step in _steps(job)
        if "uses" in step
    ]


def _run_steps(document: dict[str, Any]) -> list[tuple[str, dict[str, Any]]]:
    return [
        (job_name, step)
        for job_name, job in _jobs(document).items()
        if isinstance(job, dict)
        for step in _steps(job)
        if isinstance(step.get("run"), str)
    ]


def _checkout_steps(document: dict[str, Any]) -> list[dict[str, Any]]:
    prefix = "actions/checkout@"
    return [
        step
        for step in _uses_steps(document)
        if str(step.get("uses", "")).startswith(prefix)
    ]


def _require(errors: list[str], condition: bool, diagnostic: str) -> None:
    if not condition:
        errors.append(diagnostic)


def _strict_yaml_equal(actual: Any, expected: Any) -> bool:
    """Compare restricted-YAML values without Python bool/int coercion."""

    if type(actual) is not type(expected):
        return False
    if isinstance(expected, dict):
        if len(actual) != len(expected):
            return False
        unmatched_actual_keys = list(actual)
        for expected_key, expected_value in expected.items():
            matching_indexes = [
                index
                for index, actual_key in enumerate(unmatched_actual_keys)
                if _strict_yaml_equal(actual_key, expected_key)
            ]
            if len(matching_indexes) != 1:
                return False
            actual_key = unmatched_actual_keys.pop(matching_indexes[0])
            if not _strict_yaml_equal(
                actual[actual_key],
                expected_value,
            ):
                return False
        return not unmatched_actual_keys
    if isinstance(expected, list):
        return len(actual) == len(expected) and all(
            _strict_yaml_equal(actual_value, expected_value)
            for actual_value, expected_value in zip(actual, expected)
        )
    return actual == expected


def _validate_yaml_and_actions(
    text: str,
) -> tuple[dict[str, Any], list[str]]:
    errors: list[str] = []
    try:
        document = _parse_yaml(text)
    except ValueError as error:
        return {}, [f"valid YAML: {error}"]

    for step in _uses_steps(document):
        use = step.get("uses")
        if not isinstance(use, str):
            errors.append("external uses is a string")
            continue
        if use.startswith("./"):
            continue
        _require(
            errors,
            EXTERNAL_USE.fullmatch(use) is not None and use in ALLOWED_EXTERNAL_USES,
            f"external action is on exact reviewed allowlist: {use}",
        )
    for job_name, job in _jobs(document).items():
        if not isinstance(job, dict):
            continue
        _require(
            errors,
            "continue-on-error" not in job,
            f"job {job_name} forbids continue-on-error",
        )
        for index, step in enumerate(_steps(job)):
            _require(
                errors,
                "continue-on-error" not in step,
                (f"job {job_name} step {index} forbids continue-on-error"),
            )
    return document, errors


def _validate_no_write_permissions(document: dict[str, Any], errors: list[str]) -> None:
    permission_maps: list[tuple[str, Any]] = [("workflow", document.get("permissions"))]
    permission_maps.extend(
        (f"job {name}", job.get("permissions"))
        for name, job in _jobs(document).items()
        if isinstance(job, dict)
    )
    for owner, permissions in permission_maps:
        if not isinstance(permissions, dict):
            errors.append(f"{owner} permissions mapping")
            continue
        for key, value in permissions.items():
            _require(
                errors,
                key != "id-token",
                f"{owner} has no OIDC permission",
            )
            _require(
                errors,
                value != "write",
                f"{owner} has no write permission",
            )


def _validate_checkout(
    errors: list[str],
    step: dict[str, Any],
    *,
    fetch_depth: int,
    ref: str | None = None,
    path: str | None = None,
) -> None:
    expected_inputs: dict[str, Any] = {
        "fetch-depth": fetch_depth,
        "persist-credentials": False,
        "submodules": False,
        "lfs": False,
        "set-safe-directory": False,
    }
    if ref is not None:
        expected_inputs["ref"] = ref
    if path is not None:
        expected_inputs["path"] = path
    expected_step = {
        "uses": f"actions/checkout@{PINNED_CHECKOUT}",
        "with": expected_inputs,
    }
    _require(
        errors,
        _strict_yaml_equal(step, expected_step),
        "checkout exact reviewed step shape and inputs",
    )


def _validate_setup_python(
    errors: list[str],
    step: dict[str, Any],
    *,
    name: str | None,
) -> None:
    expected: dict[str, Any] = {
        "uses": f"actions/setup-python@{PINNED_SETUP_PYTHON}",
        "with": {"python-version": PRIMARY_PYTHON_VERSION},
    }
    if name is not None:
        expected["name"] = name
    _require(
        errors,
        _strict_yaml_equal(step, expected),
        "setup-python exact reviewed step shape and inputs",
    )


def _validate_critical_hash(
    errors: list[str],
    workflow: str,
    job_name: str,
    job: dict[str, Any],
    step_name: str,
) -> None:
    step = _named_step(job, step_name)
    if workflow == "protected":
        expected_context = PROTECTED_CRITICAL_STEP_CONTEXTS.get((job_name, step_name))
        if expected_context is None:
            errors.append(
                f"{workflow} {job_name}/{step_name} has no reviewed step mapping"
            )
            return
        actual_context = {key: value for key, value in step.items() if key != "run"}
        _require(
            errors,
            set(step) == set(expected_context) | {"run"}
            and _strict_yaml_equal(actual_context, expected_context),
            (f"{workflow} {job_name}/{step_name} exact reviewed step mapping"),
        )
    body = step.get("run")
    _require(
        errors,
        isinstance(body, str),
        f"{workflow} {job_name}/{step_name} exact unique run body",
    )
    _require(
        errors,
        _strict_yaml_equal(step.get("shell"), "bash"),
        f"{workflow} {job_name}/{step_name} uses exact bash shell",
    )
    if not isinstance(body, str):
        return
    expected = CRITICAL_RUN_BODY_SHA256[(workflow, job_name, step_name)]
    _require(
        errors,
        _run_body_sha256(body) == expected,
        f"{workflow} {job_name}/{step_name} reviewed run-body SHA-256",
    )


def _validate_run_body_hash(
    errors: list[str],
    workflow: str,
    job_name: str,
    job: dict[str, Any],
    step_name: str,
) -> None:
    step = _named_step(job, step_name)
    body = step.get("run")
    _require(
        errors,
        isinstance(body, str),
        f"{workflow} {job_name}/{step_name} exact unique run body",
    )
    if not isinstance(body, str):
        return
    expected = CRITICAL_RUN_BODY_SHA256[(workflow, job_name, step_name)]
    _require(
        errors,
        _run_body_sha256(body) == expected,
        f"{workflow} {job_name}/{step_name} reviewed run-body SHA-256",
    )


def _validate_hardened_job_env(
    errors: list[str], job_name: str, job: dict[str, Any]
) -> None:
    environment = job.get("env")
    if not isinstance(environment, dict):
        errors.append(f"{job_name} hardened job environment")
        return
    for key, expected in HARDENED_GIT_ENVIRONMENT.items():
        _require(
            errors,
            _strict_yaml_equal(environment.get(key), expected),
            f"{job_name} hardened {key}",
        )


def validate_ordinary_workflow(text: str) -> list[str]:
    document, errors = _validate_yaml_and_actions(text)
    if not document and errors:
        return errors

    _require(
        errors,
        set(document) == WORKFLOW_TOP_LEVEL_FIELDS,
        "ordinary exact top-level field set",
    )
    _require(
        errors,
        _strict_yaml_equal(
            document.get("name"),
            ORDINARY_WORKFLOW_NAME,
        ),
        "ordinary exact workflow name",
    )
    _require(
        errors,
        _strict_yaml_equal(document.get("permissions"), {}),
        "ordinary top-level permissions are empty",
    )
    jobs = _jobs(document)
    _require(
        errors,
        set(jobs) == ORDINARY_JOBS,
        "ordinary exact reviewed job set",
    )
    _validate_no_write_permissions(document, errors)
    for name, job in jobs.items():
        if not isinstance(job, dict):
            errors.append(f"ordinary job {name} mapping")
            continue
        _require(
            errors,
            _strict_yaml_equal(
                job.get("permissions"),
                {"contents": "read"},
            ),
            f"ordinary job {name} has read-only contents",
        )
        _require(
            errors,
            name in ORDINARY_JOB_TIMEOUTS
            and _strict_yaml_equal(
                job.get("timeout-minutes"),
                ORDINARY_JOB_TIMEOUTS.get(name),
            ),
            f"ordinary job {name} has exact timeout",
        )
        expected_if = FLOOR_MAIN_ONLY_GUARD if name == "qinao-ios27-floor" else None
        _require(
            errors,
            (
                _strict_yaml_equal(job.get("if"), expected_if)
                if expected_if is not None
                else "if" not in job
            ),
            f"ordinary job {name} exact execution condition",
        )

    events = _events(document)
    _require(
        errors,
        _strict_yaml_equal(events, ORDINARY_EVENTS),
        "ordinary exact event contracts",
    )

    checkouts = _checkout_steps(document)
    _require(
        errors,
        len(checkouts) == len(ORDINARY_JOBS),
        "ordinary one checkout per job",
    )
    for job_name, job in jobs.items():
        if not isinstance(job, dict):
            continue
        job_checkouts = [
            step
            for step in _steps(job)
            if str(step.get("uses", "")).startswith("actions/checkout@")
        ]
        _require(
            errors,
            len(job_checkouts) == 1,
            f"ordinary job {job_name} has exactly one checkout",
        )
        if len(job_checkouts) == 1:
            _validate_checkout(
                errors,
                job_checkouts[0],
                fetch_depth=0,
                path=(
                    "${{ env.QINAO_IOS27_FLOOR_RELATIVE }}"
                    if job_name == "qinao-ios27-floor"
                    else None
                ),
            )

    setup_steps = [
        step
        for step in _uses_steps(document)
        if str(step.get("uses", "")).startswith("actions/setup-python@")
    ]
    _require(
        errors,
        len(setup_steps) == 3,
        "ordinary exact setup-python step count",
    )
    for job_name, expected_name in (
        ("python-fuzz", "Setup Python"),
        ("qinao-gates", None),
        ("qinao-ios27-floor", None),
    ):
        job = jobs.get(job_name, {})
        matches = [
            step
            for step in _steps(job if isinstance(job, dict) else {})
            if str(step.get("uses", "")).startswith("actions/setup-python@")
        ]
        _require(
            errors,
            len(matches) == 1,
            f"ordinary job {job_name} exact setup-python step",
        )
        if len(matches) == 1:
            _validate_setup_python(
                errors,
                matches[0],
                name=expected_name,
            )
    _require(
        errors,
        len(_uses_steps(document)) == len(ORDINARY_JOBS) + 3,
        "ordinary exact external action inventory",
    )

    gates = jobs.get("qinao-gates", {})
    floor = jobs.get("qinao-ios27-floor", {})
    if isinstance(gates, dict):
        gate_context = {key: value for key, value in gates.items() if key != "steps"}
        _require(
            errors,
            set(gates) == set(QINAO_GATES_JOB_CONTEXT) | {"steps"}
            and _strict_yaml_equal(
                gate_context,
                QINAO_GATES_JOB_CONTEXT,
            ),
            "ordinary qinao-gates exact reviewed job context",
        )
        gate_steps = _steps(gates)
        gate_names = [step.get("name", step.get("uses")) for step in gate_steps]
        _require(
            errors,
            isinstance(gates.get("steps"), list)
            and _strict_yaml_equal(gates.get("steps"), gate_steps)
            and _strict_yaml_equal(
                gate_names,
                [
                    f"actions/checkout@{PINNED_CHECKOUT}",
                    f"actions/setup-python@{PINNED_SETUP_PYTHON}",
                    PROTECTED_PYTHON_39_STEP_NAME,
                    QINAO_GATE_UNIT_STEP_NAME,
                    ("Run repository report replay only with external inputs"),
                    "Require exclusive iOS 27 JIT runner readiness",
                ],
            ),
            "ordinary qinao-gates exact safe step sequence",
        )
        if len(gate_steps) >= 2:
            _validate_checkout(
                errors,
                gate_steps[0],
                fetch_depth=0,
            )
            _validate_setup_python(
                errors,
                gate_steps[1],
                name=None,
            )
        compatibility = _named_step(gates, PROTECTED_PYTHON_39_STEP_NAME)
        _require(
            errors,
            _strict_yaml_equal(
                compatibility,
                {
                    "name": PROTECTED_PYTHON_39_STEP_NAME,
                    "shell": "bash",
                    "run": PROTECTED_PYTHON_39_RUN,
                },
            ),
            "ordinary protected Python 3.9.6 compatibility gate exact mapping",
        )
        unit = _named_step(gates, QINAO_GATE_UNIT_STEP_NAME)
        _require(
            errors,
            _strict_yaml_equal(
                unit,
                {
                    "name": QINAO_GATE_UNIT_STEP_NAME,
                    "run": QINAO_GATE_UNIT_RUN,
                },
            ),
            "ordinary Qinao gate unit step exact reviewed mapping",
        )
        report_name = "Run repository report replay only with external inputs"
        report = _named_step(gates, report_name)
        _require(
            errors,
            set(report) == {"name", "if", "shell", "run"}
            and _strict_yaml_equal(report.get("name"), report_name)
            and _strict_yaml_equal(
                report.get("if"),
                ("${{ env.QINAO_EXTERNAL_REPLAY_INPUTS_READY == 'true' }}"),
            )
            and _strict_yaml_equal(report.get("shell"), "bash"),
            "ordinary qinao-gates report step exact reviewed mapping",
        )
        readiness_name = "Require exclusive iOS 27 JIT runner readiness"
        readiness = _named_step(gates, readiness_name)
        _require(
            errors,
            set(readiness) == {"name", "if", "shell", "env", "run"}
            and _strict_yaml_equal(
                readiness.get("name"),
                readiness_name,
            )
            and _strict_yaml_equal(
                readiness.get("if"),
                FLOOR_MAIN_ONLY_GUARD,
            )
            and _strict_yaml_equal(readiness.get("shell"), "bash")
            and _strict_yaml_equal(
                readiness.get("env"),
                {
                    "QINAO_IOS27_JIT_EXCLUSIVE_READY": (
                        "${{ vars.QINAO_IOS27_JIT_EXCLUSIVE_READY }}"
                    )
                },
            ),
            "ordinary qinao-gates readiness step exact reviewed mapping",
        )
        _validate_critical_hash(
            errors,
            "ordinary",
            "qinao-gates",
            gates,
            "Run repository report replay only with external inputs",
        )
        _validate_critical_hash(
            errors,
            "ordinary",
            "qinao-gates",
            gates,
            "Require exclusive iOS 27 JIT runner readiness",
        )
    if isinstance(floor, dict):
        floor_context = {key: value for key, value in floor.items() if key != "steps"}
        _require(
            errors,
            set(floor) == set(QINAO_IOS27_FLOOR_JOB_CONTEXT) | {"steps"}
            and _strict_yaml_equal(
                floor_context,
                QINAO_IOS27_FLOOR_JOB_CONTEXT,
            ),
            "ordinary iOS 27 floor exact reviewed job context",
        )
        _require(
            errors,
            _strict_yaml_equal(
                floor.get("if"),
                FLOOR_MAIN_ONLY_GUARD,
            ),
            "ordinary Xcode 27 floor is merged-main/manual-main only",
        )
        _require(
            errors,
            _strict_yaml_equal(floor.get("needs"), "qinao-gates"),
            "ordinary Xcode 27 floor depends on hosted gates",
        )
        _require(
            errors,
            _strict_yaml_equal(
                floor.get("runs-on"),
                {
                    "group": "qinao-ios27-jit",
                    "labels": ["self-hosted", "macOS", "xcode-27"],
                },
            ),
            "ordinary Xcode 27 floor uses exclusive runner group",
        )
        _validate_hardened_job_env(errors, "ordinary floor", floor)
        floor_env = floor.get("env")
        floor_env = floor_env if isinstance(floor_env, dict) else {}
        _require(
            errors,
            _strict_yaml_equal(
                floor_env.get("QINAO_IOS27_FLOOR_RELATIVE"),
                QINAO_IOS27_FLOOR_RELATIVE,
            ),
            "ordinary Xcode 27 floor checkout root is run-unique",
        )
        floor_steps = _steps(floor)
        floor_names = [step.get("name", step.get("uses")) for step in floor_steps]
        _require(
            errors,
            isinstance(floor.get("steps"), list)
            and _strict_yaml_equal(floor.get("steps"), floor_steps)
            and _strict_yaml_equal(
                floor_names,
                [
                    "Assert isolated iOS 27 floor root is absent",
                    f"actions/checkout@{PINNED_CHECKOUT}",
                    f"actions/setup-python@{PINNED_SETUP_PYTHON}",
                    "Assert Xcode 27 toolchain",
                    "Run iOS 27 floor unit tests",
                    "Run local iOS 27 floor check",
                ],
            ),
            "ordinary Xcode 27 floor steps have exact safe order",
        )
        root_step = _named_step(floor, "Assert isolated iOS 27 floor root is absent")
        _require(
            errors,
            set(root_step) == {"name", "shell", "run"}
            and _strict_yaml_equal(root_step.get("shell"), "bash"),
            "ordinary iOS 27 floor root step exact reviewed mapping",
        )
        _validate_critical_hash(
            errors,
            "ordinary",
            "qinao-ios27-floor",
            floor,
            "Assert isolated iOS 27 floor root is absent",
        )
        if len(floor_steps) >= 2:
            _validate_checkout(
                errors,
                floor_steps[1],
                fetch_depth=0,
                path="${{ env.QINAO_IOS27_FLOOR_RELATIVE }}",
            )
        if len(floor_steps) >= 3:
            _validate_setup_python(
                errors,
                floor_steps[2],
                name=None,
            )
        expected_working_directory = QINAO_IOS27_FLOOR_WORKING_DIRECTORY
        for step_name in (
            "Assert Xcode 27 toolchain",
            "Run iOS 27 floor unit tests",
            "Run local iOS 27 floor check",
        ):
            _require(
                errors,
                _strict_yaml_equal(
                    _named_step(floor, step_name).get("working-directory"),
                    expected_working_directory,
                ),
                f"ordinary Xcode 27 floor {step_name} uses isolated root",
            )
        toolchain = _named_step(floor, "Assert Xcode 27 toolchain")
        _require(
            errors,
            set(toolchain) == {"name", "shell", "working-directory", "run"}
            and _strict_yaml_equal(toolchain.get("shell"), "bash")
            and _strict_yaml_equal(
                toolchain.get("working-directory"),
                expected_working_directory,
            ),
            "ordinary iOS 27 floor toolchain step exact reviewed mapping",
        )
        _validate_critical_hash(
            errors,
            "ordinary",
            "qinao-ios27-floor",
            floor,
            "Assert Xcode 27 toolchain",
        )
        floor_unit_name = "Run iOS 27 floor unit tests"
        floor_unit = _named_step(floor, floor_unit_name)
        _require(
            errors,
            _strict_yaml_equal(
                floor_unit,
                {
                    "name": floor_unit_name,
                    "working-directory": expected_working_directory,
                    "run": (
                        "python3 -m unittest "
                        "BehavioralAISubstrate.scripts."
                        "test_check_ios27_floor"
                    ),
                },
            ),
            "ordinary iOS 27 floor unit step exact reviewed mapping",
        )
        _validate_run_body_hash(
            errors,
            "ordinary",
            "qinao-ios27-floor",
            floor,
            floor_unit_name,
        )
        floor_local_name = "Run local iOS 27 floor check"
        floor_local = _named_step(floor, floor_local_name)
        _require(
            errors,
            _strict_yaml_equal(
                floor_local,
                {
                    "name": floor_local_name,
                    "working-directory": expected_working_directory,
                    "run": ("BehavioralAISubstrate/scripts/check-ios27-floor.sh"),
                },
            ),
            "ordinary iOS 27 floor local step exact reviewed mapping",
        )
        _validate_run_body_hash(
            errors,
            "ordinary",
            "qinao-ios27-floor",
            floor,
            floor_local_name,
        )

    allowed_step_ifs = {
        (
            "qinao-gates",
            "Run repository report replay only with external inputs",
        ): "${{ env.QINAO_EXTERNAL_REPLAY_INPUTS_READY == 'true' }}",
        (
            "qinao-gates",
            "Require exclusive iOS 27 JIT runner readiness",
        ): FLOOR_MAIN_ONLY_GUARD,
    }
    for job_name, job in jobs.items():
        if not isinstance(job, dict):
            continue
        for step in _steps(job):
            step_name = str(step.get("name", ""))
            expected_if = allowed_step_ifs.get((job_name, step_name))
            _require(
                errors,
                (
                    _strict_yaml_equal(step.get("if"), expected_if)
                    if expected_if is not None
                    else "if" not in step
                ),
                f"ordinary step {job_name}/{step_name} exact condition",
            )

    structured = json.dumps(document, sort_keys=True)
    for forbidden in (
        "id-token",
        "contents:write",
        "admit-wave",
        "verify-receipt",
        "sign-evidence",
        "private_key",
        "secrets.",
    ):
        _require(
            errors,
            forbidden not in structured,
            f"ordinary forbids authority token {forbidden}",
        )
    for _, step in _run_steps(document):
        body = str(step.get("run", ""))
        _require(
            errors,
            "--textconv" not in body
            and re.search(r"\bgit\s+(?:checkout|show|status|diff)\b", body) is None,
            "ordinary run bodies forbid unsafe Git inspection",
        )
    return errors


def validate_protected_workflow(text: str) -> list[str]:
    document, errors = _validate_yaml_and_actions(text)
    if not document and errors:
        return errors

    _require(
        errors,
        set(document) == WORKFLOW_TOP_LEVEL_FIELDS,
        "protected exact top-level field set",
    )
    _require(
        errors,
        _strict_yaml_equal(
            document.get("name"),
            PROTECTED_WORKFLOW_NAME,
        ),
        "protected exact workflow name",
    )
    _require(
        errors,
        _strict_yaml_equal(document.get("permissions"), {}),
        "protected top-level permissions are empty",
    )
    _validate_no_write_permissions(document, errors)
    jobs = _jobs(document)
    _require(
        errors,
        set(jobs) == PROTECTED_JOBS,
        "protected exact reviewed job set",
    )
    events = _events(document)
    _require(
        errors,
        _strict_yaml_equal(
            events,
            {
                "workflow_dispatch": {
                    "inputs": PROTECTED_DISPATCH_INPUTS,
                }
            },
        ),
        "protected exact manual event contract",
    )
    dispatch = events.get("workflow_dispatch")
    dispatch = dispatch if isinstance(dispatch, dict) else {}
    inputs = dispatch.get("inputs")
    inputs = inputs if isinstance(inputs, dict) else {}
    _require(
        errors,
        _strict_yaml_equal(inputs, PROTECTED_DISPATCH_INPUTS),
        "protected exact dispatch input contracts",
    )

    guard = jobs.get("runner-isolation-guard", {})
    candidate = jobs.get("candidate-validation", {})
    prepare = jobs.get("prepare-current-wave", {})
    if not all(isinstance(job, dict) for job in (guard, candidate, prepare)):
        return errors + ["protected jobs are mappings"]

    for job_name, expected_context in PROTECTED_JOB_CONTEXTS.items():
        job = jobs.get(job_name)
        if not isinstance(job, dict):
            errors.append(f"protected job {job_name} is a mapping")
            continue
        actual_context = {key: value for key, value in job.items() if key != "steps"}
        _require(
            errors,
            set(job) == set(expected_context) | {"steps"}
            and _strict_yaml_equal(actual_context, expected_context),
            f"protected {job_name} exact reviewed job context",
        )
        _require(
            errors,
            _strict_yaml_equal(
                job.get("timeout-minutes"),
                PROTECTED_JOB_TIMEOUTS.get(job_name),
            ),
            f"protected job {job_name} has exact timeout",
        )

    _require(
        errors,
        _strict_yaml_equal(guard.get("runs-on"), "ubuntu-latest"),
        "runner guard uses hosted runner",
    )
    _require(
        errors,
        _strict_yaml_equal(guard.get("permissions"), {}),
        "runner guard has no permissions",
    )
    _require(
        errors,
        "if" not in guard,
        "runner guard is reachable on every manual ref",
    )
    guard_env = guard.get("env")
    guard_env = guard_env if isinstance(guard_env, dict) else {}
    _require(
        errors,
        _strict_yaml_equal(guard_env, PROTECTED_GUARD_ENVIRONMENT),
        "runner guard requires both explicit readiness variables",
    )
    guard_steps = _steps(guard)
    guard_names = [step.get("name") for step in guard_steps]
    _require(
        errors,
        isinstance(guard.get("steps"), list)
        and _strict_yaml_equal(guard.get("steps"), guard_steps)
        and _strict_yaml_equal(
            guard_names,
            [
                "Assert protected bootstrap ref",
                "Require explicit one-job runner readiness",
            ],
        ),
        "runner guard has exact fail-closed step order",
    )
    for step_name in (
        "Assert protected bootstrap ref",
        "Require explicit one-job runner readiness",
    ):
        _validate_critical_hash(
            errors,
            "protected",
            "runner-isolation-guard",
            guard,
            step_name,
        )

    _require(
        errors,
        _strict_yaml_equal(
            candidate.get("needs"),
            "runner-isolation-guard",
        ),
        "candidate waits for runner guard",
    )
    _require(
        errors,
        _strict_yaml_equal(candidate.get("if"), PROTECTED_REF_GUARD),
        "candidate exact protected-ref guard",
    )
    _require(
        errors,
        _strict_yaml_equal(
            candidate.get("permissions"),
            {"contents": "read"},
        ),
        "candidate has read-only contents",
    )
    _require(
        errors,
        _strict_yaml_equal(
            candidate.get("runs-on"),
            {
                "group": "qinao-candidate-jit",
                "labels": ["self-hosted", "macOS", "xcode-27"],
            },
        ),
        "candidate uses isolated candidate runner group",
    )
    _validate_hardened_job_env(errors, "candidate", candidate)
    candidate_env = candidate.get("env")
    candidate_env = candidate_env if isinstance(candidate_env, dict) else {}
    _require(
        errors,
        _strict_yaml_equal(
            candidate_env.get("QINAO_CANDIDATE_VALIDATION_RELATIVE"),
            (
                "qinao-candidate-validation-${{ github.run_id }}-"
                "${{ github.run_attempt }}"
            ),
        ),
        "candidate checkout root is run-unique",
    )

    candidate_steps = _steps(candidate)
    candidate_names = [step.get("name", step.get("uses")) for step in candidate_steps]
    _require(
        errors,
        isinstance(candidate.get("steps"), list)
        and _strict_yaml_equal(candidate.get("steps"), candidate_steps)
        and _strict_yaml_equal(
            candidate_names,
            [
                "Assert isolated candidate root is absent",
                f"actions/checkout@{PINNED_CHECKOUT}",
                "Validate candidate without admission authority",
                "Upload exact candidate-validation artifact",
            ],
        ),
        "candidate steps have exact safe order",
    )
    _validate_critical_hash(
        errors,
        "protected",
        "candidate-validation",
        candidate,
        "Assert isolated candidate root is absent",
    )
    _validate_critical_hash(
        errors,
        "protected",
        "candidate-validation",
        candidate,
        "Validate candidate without admission authority",
    )
    if len(candidate_steps) >= 2:
        _validate_checkout(
            errors,
            candidate_steps[1],
            fetch_depth=0,
            ref="${{ inputs.candidate_commit }}",
            path="${{ env.QINAO_CANDIDATE_VALIDATION_RELATIVE }}",
        )
    outputs = candidate.get("outputs")
    outputs = outputs if isinstance(outputs, dict) else {}
    _require(
        errors,
        _strict_yaml_equal(outputs, PROTECTED_CANDIDATE_OUTPUTS),
        "candidate exposes exact ID and internal manifest bindings",
    )
    candidate_body = _named_step(
        candidate, "Validate candidate without admission authority"
    ).get("run", "")
    for module in QINAO_MODULES:
        _require(
            errors,
            isinstance(candidate_body, str) and candidate_body.count(module) == 1,
            f"candidate executes {module} exactly once",
        )
    try:
        supervisor_source = _embedded_candidate_supervisor_source(candidate_body)
        ast.parse(
            supervisor_source,
            filename="<candidate-supervisor>",
        )
    except (AssertionError, SyntaxError) as error:
        errors.append(f"candidate supervisor is exact valid Python: {error}")
        supervisor_source = ""
    waitid_position = supervisor_source.find("if observe_process_exit(process.pid):")
    term_position = supervisor_source.find("signal.SIGTERM")
    post_term_observation_position = supervisor_source.find(
        "leader_observed = observe_process_exit(",
        term_position,
    )
    kill_position = supervisor_source.find("signal.SIGKILL")
    kill_race_observation_position = supervisor_source.find(
        "leader_observed = observe_process_exit(",
        kill_position,
    )
    reap_position = supervisor_source.find("process.wait(")
    _require(
        errors,
        0
        <= waitid_position
        < term_position
        < post_term_observation_position
        < kill_position
        < kill_race_observation_position
        < reap_position
        and supervisor_source.count("process.wait(") == 1
        and "process.poll(" not in supervisor_source
        and "process.communicate(" not in supervisor_source
        and "os.WNOWAIT" in supervisor_source
        and "os.waitid(" in supervisor_source
        and "libc_waitid(" in supervisor_source
        and "start_new_session=True" in supervisor_source
        and "term_permission_denied" in supervisor_source
        and "os.killpg(validation_group, group_signal)" in supervisor_source,
        (
            "candidate supervisor observes without reaping, then "
            "TERM/KILL cleans the process group before bounded reap"
        ),
    )
    _require(
        errors,
        isinstance(candidate_body, str)
        and "\"2400\" <<'PY'" in candidate_body
        and "validation_timeout_seconds = float(" in supervisor_source
        and ("0.05 <= validation_timeout_seconds <= 2400" in supervisor_source)
        and ("124 if timed_out else reaped_return_code" in supervisor_source)
        and ("if cleanup_failed:\n    raise SystemExit(125)" in supervisor_source),
        (
            "candidate timeout is fixed in production, reports 124 "
            "after successful cleanup, and cleanup failure reports 125"
        ),
    )
    _require(
        errors,
        "import selectors\n" in supervisor_source
        and "stdout=subprocess.PIPE" in supervisor_source
        and "remaining = max(0, 8388608 - log_bytes)" in supervisor_source
        and "accepted = chunk[:remaining]" in supervisor_source
        and "resource.RLIMIT_FSIZE" not in supervisor_source
        and "preexec_fn=" not in supervisor_source,
        (
            "candidate parent bounds only captured output to 8 MiB "
            "without constraining legitimate build artifacts"
        ),
    )
    _require(
        errors,
        "environment = {" in supervisor_source
        and "dict(os.environ)" not in supervisor_source
        and "environment.pop(" not in supervisor_source
        and 'runtime_temp = os.environ["RUNNER_TEMP"]' in supervisor_source
        and '"HOME": "/nonexistent"' in supervisor_source
        and '"PATH": "/usr/bin:/bin"' in supervisor_source
        and '"PYTHONDONTWRITEBYTECODE": "1"' in supervisor_source
        and '"TMPDIR": runtime_temp' in supervisor_source
        and '"XDG_CONFIG_HOME": "/nonexistent"' in supervisor_source,
        "candidate subprocess receives an explicit sterile allowlist environment",
    )
    publish_position = supervisor_source.rfind("publish_bound_validation_log(")
    _require(
        errors,
        publish_position > reap_position
        and "if written == 0:" in supervisor_source
        and "descriptor_before = os.fstat(descriptor)" in supervisor_source
        and "path_metadata = os.lstat(path)" in supervisor_source
        and "descriptor_before.st_nlink != 1" in supervisor_source
        and "descriptor_before.st_size != expected_size" in supervisor_source
        and "actual_digest != expected_digest" in supervisor_source
        and "dir_fd=root_descriptor" in supervisor_source,
        (
            "candidate binds, verifies, and publishes the exact raw-log "
            "descriptor only after group cleanup and reap"
        ),
    )
    supervisor_prefix = (
        candidate_body.split("<<'PY'\n", 1)[0]
        if isinstance(candidate_body, str)
        else ""
    )
    _require(
        errors,
        'test ! -e "$artifact_root"' in supervisor_prefix
        and 'test ! -L "$artifact_root"' in supervisor_prefix
        and 'mkdir -m 0700 "$artifact_root"' not in supervisor_prefix
        and 'install -m 0600 "$raw_log"' not in candidate_body
        and "os.mkdir(artifact_root, 0o700)" in supervisor_source,
        (
            "candidate artifact root stays absent until the bound parent "
            "publishes after validation cleanup"
        ),
    )
    for token in (
        '\\"authority\\":\\"none\\"',
        ('\\"provenance\\":\\"candidate-runner-untrusted-observation\\"'),
        'test "$envelope_size" -le 4096',
        'test "$manifest_size" -le 4096',
        'test "$artifact_total_size" -le 8396800',
    ):
        _require(
            errors,
            isinstance(candidate_body, str) and token in candidate_body,
            f"candidate non-authoritative bounded artifact token {token}",
        )
    candidate_upload = _named_step(
        candidate, "Upload exact candidate-validation artifact"
    )
    _require(
        errors,
        _strict_yaml_equal(
            candidate_upload,
            {
                "name": "Upload exact candidate-validation artifact",
                "id": "upload",
                "uses": (f"actions/upload-artifact@{PINNED_UPLOAD_ARTIFACT}"),
                "with": {
                    "name": (
                        "qinao-candidate-validation-"
                        "${{ github.run_id }}-${{ github.run_attempt }}"
                    ),
                    "path": (
                        "${{ runner.temp }}/qinao-candidate-validation/"
                        "artifact-manifest.json\n"
                        "${{ runner.temp }}/qinao-candidate-validation/"
                        "validation-envelope.json\n"
                        "${{ runner.temp }}/qinao-candidate-validation/"
                        "validation.log\n"
                    ),
                    "if-no-files-found": "error",
                    "include-hidden-files": False,
                    "retention-days": 1,
                },
            },
        ),
        "candidate upload exact reviewed step shape and bounded paths",
    )

    _require(
        errors,
        _strict_yaml_equal(
            prepare.get("needs"),
            "candidate-validation",
        ),
        "preparation waits for candidate validation",
    )
    _require(
        errors,
        _strict_yaml_equal(prepare.get("if"), PROTECTED_REF_GUARD),
        "preparation exact protected-ref guard",
    )
    _require(
        errors,
        _strict_yaml_equal(
            prepare.get("environment"),
            "qinao-admission",
        ),
        "preparation retains protected review environment",
    )
    _require(
        errors,
        _strict_yaml_equal(
            prepare.get("permissions"),
            {"actions": "read", "contents": "read"},
        ),
        "preparation has read-only permissions and no OIDC",
    )
    _require(
        errors,
        _strict_yaml_equal(
            prepare.get("runs-on"),
            {
                "group": "qinao-admission-jit",
                "labels": [
                    "self-hosted",
                    "macOS",
                    "qinao-admission",
                ],
            },
        ),
        "preparation uses isolated admission runner group",
    )
    _validate_hardened_job_env(errors, "preparation", prepare)

    prepare_steps = _steps(prepare)
    prepare_names = [step.get("name", step.get("uses")) for step in prepare_steps]
    _require(
        errors,
        isinstance(prepare.get("steps"), list)
        and _strict_yaml_equal(prepare.get("steps"), prepare_steps)
        and _strict_yaml_equal(
            prepare_names,
            [
                "Assert isolated preparation roots are absent",
                f"actions/checkout@{PINNED_CHECKOUT}",
                f"actions/checkout@{PINNED_CHECKOUT}",
                ("Download exact candidate-validation artifact by service ID"),
                "Build unsigned report with pinned trusted tools",
                "Upload unsigned report for protected review",
                "Block authority transition until Phase C wire exists",
            ],
        ),
        "preparation steps have exact safe order",
    )
    for step_name in (
        "Assert isolated preparation roots are absent",
        "Build unsigned report with pinned trusted tools",
        "Block authority transition until Phase C wire exists",
    ):
        _validate_critical_hash(
            errors,
            "protected",
            "prepare-current-wave",
            prepare,
            step_name,
        )
    if len(prepare_steps) >= 3:
        _validate_checkout(
            errors,
            prepare_steps[1],
            fetch_depth=1,
            ref="${{ github.sha }}",
            path="${{ env.QINAO_TRUSTED_TOOLS_RELATIVE }}",
        )
        _validate_checkout(
            errors,
            prepare_steps[2],
            fetch_depth=0,
            ref="${{ inputs.candidate_commit }}",
            path="${{ env.QINAO_CANDIDATE_DATA_RELATIVE }}",
        )

    download = _named_step(
        prepare, "Download exact candidate-validation artifact by service ID"
    )
    _require(
        errors,
        _strict_yaml_equal(
            download,
            {
                "name": ("Download exact candidate-validation artifact by service ID"),
                "uses": (f"actions/download-artifact@{PINNED_DOWNLOAD_ARTIFACT}"),
                "with": {
                    "artifact-ids": (
                        "${{ needs.candidate-validation.outputs.artifact_id }}"
                    ),
                    "path": ("${{ runner.temp }}/qinao-candidate-validation"),
                    "merge-multiple": True,
                },
            },
        ),
        "preparation download exact reviewed step shape and service ID",
    )

    report = _named_step(prepare, "Build unsigned report with pinned trusted tools")
    report_body = report.get("run", "")
    _require(
        errors,
        isinstance(report_body, str)
        and '/usr/bin/python3 "/dev/fd/$repository_runner_fd" report' in report_body,
        "preparation invokes only pinned repository report operation",
    )
    _require(
        errors,
        isinstance(report_body, str)
        and "$'artifact-manifest.json\\nvalidation-envelope.json\\nvalidation.log'"
        in report_body
        and 'cmp -s "$expected_manifest_path" "$artifact_root/artifact-manifest.json"'
        in report_body,
        "preparation verifies exact internal artifact manifest",
    )
    for token in (
        'test "$QINAO_CANDIDATE_ENVELOPE_SIZE" -le 4096',
        'test "$QINAO_CANDIDATE_MANIFEST_SIZE" -le 4096',
        'test "$artifact_total_size" -le 8396800',
        '\\"authority\\":\\"none\\"',
        ('\\"provenance\\":\\"candidate-runner-untrusted-observation\\"'),
    ):
        _require(
            errors,
            isinstance(report_body, str) and token in report_body,
            f"preparation bounded non-authoritative artifact token {token}",
        )
    _require(
        errors,
        isinstance(report_body, str)
        and 'test "$(qinao_read_head_object "$candidate_root" commit)"' in report_body
        and 'test "$(qinao_read_head_object "$candidate_root" tree)"' in report_body,
        "preparation verifies exact candidate commit and tree",
    )
    _require(
        errors,
        isinstance(report_body, str)
        and "bind_external_input() {" in report_body
        and "assert_bound_input_unchanged() {" in report_body
        and 'canonical_external_path "$input_path" "$GITHUB_WORKSPACE"' in report_body
        and 'shasum -a 256 "$bound_trust_root"' in report_body,
        "preparation binds external inputs before hashing and consumption",
    )
    for option, bound_value, raw_value in (
        (
            "--source-selection",
            "$bound_source_selection",
            "$QINAO_SOURCE_SELECTION",
        ),
        (
            "--trust-root",
            "$bound_trust_root",
            "$QINAO_ADMISSION_TRUST_ROOT",
        ),
        (
            "--previous-receipt",
            "$bound_previous_receipt",
            "$QINAO_PREVIOUS_ADMISSION_RECEIPT",
        ),
    ):
        _require(
            errors,
            isinstance(report_body, str)
            and f'{option} "{bound_value}"' in report_body
            and f'{option} "{raw_value}"' not in report_body,
            f"preparation passes FD-bound {option} input",
        )
    for descriptor, metadata in (
        ("source_selection_fd", "source_selection_metadata"),
        ("trust_root_fd", "trust_root_metadata"),
        ("previous_receipt_fd", "previous_receipt_metadata"),
    ):
        _require(
            errors,
            isinstance(report_body, str)
            and (f'  "${descriptor}" \\\n  "${metadata}"') in report_body,
            f"preparation revalidates bound input ${descriptor}",
        )

    upload = _named_step(prepare, "Upload unsigned report for protected review")
    _require(
        errors,
        _strict_yaml_equal(
            upload,
            {
                "name": "Upload unsigned report for protected review",
                "uses": (f"actions/upload-artifact@{PINNED_UPLOAD_ARTIFACT}"),
                "with": {
                    "name": (
                        "qinao-unsigned-report-"
                        "${{ github.run_id }}-${{ github.run_attempt }}"
                    ),
                    "path": ("${{ runner.temp }}/qinao-unsigned-report.json"),
                    "if-no-files-found": "error",
                    "include-hidden-files": False,
                    "retention-days": 1,
                },
            },
        ),
        "unsigned report upload exact reviewed step shape and path",
    )
    blocker = _named_step(
        prepare, "Block authority transition until Phase C wire exists"
    )
    _require(
        errors,
        _strict_yaml_equal(blocker.get("if"), "${{ always() }}"),
        "authority blocker always executes",
    )
    _require(
        errors,
        set(blocker) == {"name", "if", "shell", "run"}
        and _strict_yaml_equal(blocker.get("shell"), "bash"),
        "authority blocker exact execution-shell shape",
    )
    blocker_body = blocker.get("run", "")
    for code in (
        "BLOCKED_PHASE_C_PROTECTED_REVIEW_OPERATION_WIRE",
        "BLOCKED_PHASE_C_RUNNER_ISOLATION_ATTESTATION_REQUIRED",
    ):
        _require(
            errors,
            isinstance(blocker_body, str) and code in blocker_body,
            f"authority blocker emits {code}",
        )
    _require(
        errors,
        len(_uses_steps(document)) == 6,
        "protected exact external action inventory",
    )
    for job_name, job in jobs.items():
        if not isinstance(job, dict):
            continue
        for step in _steps(job):
            step_name = str(step.get("name", ""))
            expected_if = (
                "${{ always() }}"
                if (
                    job_name == "prepare-current-wave"
                    and step_name
                    == "Block authority transition until Phase C wire exists"
                )
                else None
            )
            _require(
                errors,
                (
                    _strict_yaml_equal(step.get("if"), expected_if)
                    if expected_if is not None
                    else "if" not in step
                ),
                f"protected step {job_name}/{step_name} exact condition",
            )

    structured = json.dumps(document, sort_keys=True)
    for forbidden in (
        "artifact-digest",
        "ARTIFACT_SERVICE_DIGEST",
        "id-token",
        "contents:write",
        "admit-wave",
        "verify-receipt",
        "sign-evidence",
        "EXTERNAL_ADMISSION_VERIFIER",
        "WAVE_ADMISSION_SIGNING_PROVIDER",
        "private_key",
        "secrets.",
        "/bin/rm",
        "rm -rf",
        "--textconv",
    ):
        _require(
            errors,
            forbidden not in structured,
            f"protected forbids {forbidden}",
        )
    for body in (step.get("run", "") for _, step in _run_steps(document)):
        _require(
            errors,
            re.search(r"\bgit\s+(?:checkout|show|status|diff)\b", body) is None,
            "protected run bodies forbid unsafe Git inspection",
        )
    return errors


def _replace_first(text: str, old: str, new: str) -> str:
    if old not in text:
        raise AssertionError(f"mutation anchor is absent: {old!r}")
    return text.replace(old, new, 1)


def _move_block_before(text: str, block: str, anchor: str) -> str:
    if text.count(block) != 1 or text.count(anchor) != 1:
        raise AssertionError("move mutation anchors must be unique")
    without = text.replace(block, "", 1)
    return without.replace(anchor, block + anchor, 1)


def _embedded_candidate_supervisor_source(body: Any) -> str:
    if not isinstance(body, str):
        raise AssertionError("candidate validation run body is absent")
    opening = "<<'PY'\n"
    closing = "\nPY\n"
    if body.count(opening) != 1:
        raise AssertionError("candidate supervisor opening is not unique")
    start = body.index(opening) + len(opening)
    if body[start:].count(closing) != 1:
        raise AssertionError("candidate supervisor closing is not unique")
    return body[start : body.index(closing, start)]


def _candidate_supervisor_source(workflow: str) -> str:
    document = _parse_yaml(workflow)
    candidate = _jobs(document).get("candidate-validation", {})
    if not isinstance(candidate, dict):
        raise AssertionError("candidate-validation job is absent")
    body = _named_step(candidate, "Validate candidate without admission authority").get(
        "run"
    )
    return _embedded_candidate_supervisor_source(body)


def _dotted_name(node: ast.AST) -> str | None:
    if isinstance(node, ast.Name):
        return node.id
    if isinstance(node, ast.Attribute):
        owner = _dotted_name(node.value)
        return f"{owner}.{node.attr}" if owner else None
    return None


def _write_candidate_supervisor_fixture(
    candidate_root: Path,
    first_module_source: str,
) -> None:
    scripts_root = candidate_root / "scripts"
    scripts_root.mkdir()
    (scripts_root / "__init__.py").write_text("", encoding="utf-8")
    for index, module in enumerate(QINAO_MODULES):
        module_path = scripts_root / f"{module.rsplit('.', 1)[1]}.py"
        module_path.write_text(
            first_module_source if index == 0 else "",
            encoding="utf-8",
        )
    floor = candidate_root / "BehavioralAISubstrate/scripts/check-ios27-floor.sh"
    floor.parent.mkdir(parents=True)
    floor.write_text("#!/bin/bash\nexit 0\n", encoding="utf-8")
    floor.chmod(0o700)


class WorkflowOwnerLedgerTests(unittest.TestCase):
    maxDiff = None

    def assertNoContractErrors(self, errors: list[str]) -> None:
        self.assertEqual(errors, [])

    def test_ordinary_workflow_contract(self) -> None:
        self.assertNoContractErrors(
            validate_ordinary_workflow(_read(ORDINARY_WORKFLOW))
        )

    def test_protected_workflow_contract(self) -> None:
        self.assertNoContractErrors(
            validate_protected_workflow(_read(PROTECTED_WORKFLOW))
        )

    def test_ordinary_structural_mutations_fail_closed(self) -> None:
        workflow = _read(ORDINARY_WORKFLOW)
        self.assertNoContractErrors(validate_ordinary_workflow(workflow))
        floor_checkout = (
            "      - uses: "
            f"actions/checkout@{PINNED_CHECKOUT}\n"
            "        with:\n"
            "          path: ${{ env.QINAO_IOS27_FLOOR_RELATIVE }}\n"
            "          fetch-depth: 0\n"
            "          persist-credentials: false\n"
            "          submodules: false\n"
            "          lfs: false\n"
            "          set-safe-directory: false\n"
        )
        mutations = {
            "job-continue-on-error": _replace_first(
                workflow,
                "    timeout-minutes: 30\n",
                ("    timeout-minutes: 30\n    continue-on-error: true\n"),
            ),
            "step-continue-on-error": _replace_first(
                workflow,
                "      - name: Select Xcode\n",
                ("      - name: Select Xcode\n        continue-on-error: true\n"),
            ),
            "ordinary-job-if-false": _replace_first(
                workflow,
                "  bas-tests:\n",
                "  bas-tests:\n    if: ${{ false }}\n",
            ),
            "ordinary-event-payload-drift": _replace_first(
                workflow,
                ('    branches: [ main, "m605-chapter-*", "decode-*" ]\n'),
                '    branches: [ "**" ]\n',
            ),
            "top-write": _replace_first(
                workflow,
                "permissions: {}",
                "permissions: {contents: write}",
            ),
            "job-write": _replace_first(
                workflow,
                "      contents: read",
                "      contents: write",
            ),
            "oidc": _replace_first(
                workflow,
                "      contents: read",
                "      contents: read\n      id-token: write",
            ),
            "mutable-setup": _replace_first(
                workflow,
                f"actions/setup-python@{PINNED_SETUP_PYTHON}",
                "actions/setup-python@v5",
            ),
            "unknown-pinned-action": _replace_first(
                workflow,
                f"actions/setup-python@{PINNED_SETUP_PYTHON}",
                ("evil/example-action@0123456789abcdef0123456789abcdef01234567"),
            ),
            "mutable-checkout": _replace_first(
                workflow,
                f"actions/checkout@{PINNED_CHECKOUT}",
                "actions/checkout@v4",
            ),
            "missing-safe-directory": _replace_first(
                workflow,
                "          set-safe-directory: false\n",
                "",
            ),
            "checkout-if-false": _replace_first(
                workflow,
                f"      - uses: actions/checkout@{PINNED_CHECKOUT}\n",
                (
                    f"      - uses: actions/checkout@{PINNED_CHECKOUT}\n"
                    "        if: ${{ false }}\n"
                ),
            ),
            "floor-pr-execution": _replace_first(
                workflow,
                f"    if: {FLOOR_MAIN_ONLY_GUARD}\n",
                "    if: ${{ github.event_name == 'pull_request' }}\n",
            ),
            "floor-runner-group": _replace_first(
                workflow,
                "      group: qinao-ios27-jit",
                "      group: qinao-candidate-jit",
            ),
            "floor-checkout-before-absence-gate": _move_block_before(
                workflow,
                floor_checkout,
                "      - name: Assert isolated iOS 27 floor root is absent\n",
            ),
            "floor-global-config": _replace_first(
                workflow,
                '      GIT_CONFIG_GLOBAL: "/dev/null"',
                '      GIT_CONFIG_GLOBAL: "~/.gitconfig"',
            ),
            "floor-system-config": _replace_first(
                workflow,
                '      GIT_CONFIG_SYSTEM: "/dev/null"',
                '      GIT_CONFIG_SYSTEM: "/etc/gitconfig"',
            ),
            "floor-hooks": _replace_first(
                workflow,
                "      GIT_CONFIG_VALUE_1: /dev/null",
                "      GIT_CONFIG_VALUE_1: .githooks",
            ),
            "floor-filter": _replace_first(
                workflow,
                '      GIT_CONFIG_VALUE_6: ""',
                "      GIT_CONFIG_VALUE_6: evil-filter",
            ),
            "floor-fsmonitor": _replace_first(
                workflow,
                '      GIT_CONFIG_VALUE_0: "false"',
                '      GIT_CONFIG_VALUE_0: "true"',
            ),
            "inline-comment-command-spoof": _replace_first(
                workflow,
                "          qinao_read_head_object() {\n",
                "          : # qinao_read_head_object() {\n",
            ),
            "critical-shell": _replace_first(
                workflow,
                (
                    "      - name: Run repository report replay only "
                    "with external inputs\n"
                    "        if: ${{ env.QINAO_EXTERNAL_REPLAY_INPUTS_READY "
                    "== 'true' }}\n"
                    "        shell: bash\n"
                ),
                (
                    "      - name: Run repository report replay only "
                    "with external inputs\n"
                    "        if: ${{ env.QINAO_EXTERNAL_REPLAY_INPUTS_READY "
                    "== 'true' }}\n"
                    "        shell: sh\n"
                ),
            ),
            "textconv": _replace_first(
                workflow,
                "          set -euo pipefail\n",
                "          set -euo pipefail\n          git show --textconv HEAD\n",
            ),
        }
        for label, mutated in mutations.items():
            with self.subTest(label=label):
                self.assertTrue(validate_ordinary_workflow(mutated))

    def test_protected_structural_mutations_fail_closed(self) -> None:
        workflow = _read(PROTECTED_WORKFLOW)
        self.assertNoContractErrors(validate_protected_workflow(workflow))
        candidate_checkout = (
            "      - uses: "
            f"actions/checkout@{PINNED_CHECKOUT}\n"
            "        with:\n"
            "          ref: ${{ inputs.candidate_commit }}\n"
            "          path: "
            "${{ env.QINAO_CANDIDATE_VALIDATION_RELATIVE }}\n"
            "          fetch-depth: 0\n"
            "          persist-credentials: false\n"
            "          submodules: false\n"
            "          lfs: false\n"
            "          set-safe-directory: false\n"
        )
        mutations = {
            "job-continue-on-error": _replace_first(
                workflow,
                "    timeout-minutes: 5\n",
                ("    timeout-minutes: 5\n    continue-on-error: true\n"),
            ),
            "step-continue-on-error": _replace_first(
                workflow,
                "      - name: Assert protected bootstrap ref\n",
                (
                    "      - name: Assert protected bootstrap ref\n"
                    "        continue-on-error: true\n"
                ),
            ),
            "wrong-protected-ref": _replace_first(
                workflow,
                (
                    '          test "$GITHUB_REF" = '
                    '"refs/heads/qinao-admission-bootstrap-v1"\n'
                ),
                ('          test "$GITHUB_REF" = "refs/heads/main"\n'),
            ),
            "top-write": _replace_first(
                workflow,
                "permissions: {}",
                "permissions: {contents: write}",
            ),
            "oidc": _replace_first(
                workflow,
                "      actions: read\n      contents: read",
                "      actions: read\n      contents: read\n      id-token: write",
            ),
            "mutable-action": _replace_first(
                workflow,
                f"actions/download-artifact@{PINNED_DOWNLOAD_ARTIFACT}",
                "actions/download-artifact@v5",
            ),
            "unknown-pinned-action": _replace_first(
                workflow,
                f"actions/download-artifact@{PINNED_DOWNLOAD_ARTIFACT}",
                ("evil/example-action@0123456789abcdef0123456789abcdef01234567"),
            ),
            "download-missing-merge-multiple": _replace_first(
                workflow,
                "          merge-multiple: true\n",
                "",
            ),
            "download-disables-merge-multiple": _replace_first(
                workflow,
                "          merge-multiple: true\n",
                "          merge-multiple: false\n",
            ),
            "missing-safe-directory": _replace_first(
                workflow,
                "          set-safe-directory: false\n",
                "",
            ),
            "checkout-before-absence-gate": _move_block_before(
                workflow,
                candidate_checkout,
                "      - name: Assert isolated candidate root is absent\n",
            ),
            "artifact-pseudo-digest": _replace_first(
                workflow,
                "      artifact_id:",
                "      artifact_service_digest: fake\n      artifact_id:",
            ),
            "candidate-upload-root-path": _replace_first(
                workflow,
                (
                    "          path: |\n"
                    "            ${{ runner.temp }}/"
                    "qinao-candidate-validation/artifact-manifest.json\n"
                ),
                "          path: /\n",
            ),
            "candidate-upload-id-drift": _replace_first(
                workflow,
                "        id: upload\n",
                "        id: attacker-controlled\n",
            ),
            "candidate-reap-before-group-kill": _replace_first(
                workflow,
                ("                      if observe_process_exit(process.pid):\n"),
                (
                    "                      process.wait(timeout=2400)\n"
                    "                      if observe_process_exit("
                    "process.pid):\n"
                ),
            ),
            "candidate-skips-post-term-observation": _replace_first(
                workflow,
                (
                    "                          leader_observed = "
                    "observe_process_exit(\n"
                    "                              process.pid\n"
                    "                          )\n"
                ),
                "                          leader_observed = False\n",
            ),
            "candidate-production-timeout-drift": _replace_first(
                workflow,
                "            \"2400\" <<'PY'\n",
                "            \"1\" <<'PY'\n",
            ),
            "candidate-timeout-misreported": _replace_first(
                workflow,
                (
                    "                          124 if timed_out "
                    "else reaped_return_code\n"
                ),
                (
                    "                          125 if timed_out "
                    "else reaped_return_code\n"
                ),
            ),
            "candidate-bypass-parent-log-cap": _replace_first(
                workflow,
                "                  stdout=subprocess.PIPE,\n",
                "                  stdout=log_descriptor,\n",
            ),
            "candidate-zero-write-spin": _replace_first(
                workflow,
                "                  if written == 0:\n",
                "                  if written < 0:\n",
            ),
            "candidate-follow-replaced-log": _replace_first(
                workflow,
                "              path_metadata = os.lstat(path)\n",
                "              path_metadata = os.stat(path)\n",
            ),
            "candidate-precreates-artifact-root": _replace_first(
                workflow,
                (
                    '          test ! -L "$artifact_root"\n'
                    '          raw_log="$RUNNER_TEMP/'
                    'qinao-candidate-validation.raw.log"\n'
                ),
                (
                    '          test ! -L "$artifact_root"\n'
                    '          mkdir -m 0700 "$artifact_root"\n'
                    '          raw_log="$RUNNER_TEMP/'
                    'qinao-candidate-validation.raw.log"\n'
                ),
            ),
            "unsigned-upload-root-path": _replace_first(
                workflow,
                ("          path: ${{ runner.temp }}/qinao-unsigned-report.json\n"),
                "          path: /\n",
            ),
            "raw-trust-path-consumption": _replace_first(
                workflow,
                '--trust-root "$bound_trust_root"',
                '--trust-root "$QINAO_ADMISSION_TRUST_ROOT"',
            ),
            "raw-source-path-consumption": _replace_first(
                workflow,
                '--source-selection "$bound_source_selection"',
                '--source-selection "$QINAO_SOURCE_SELECTION"',
            ),
            "trust-hash-before-binding": _replace_first(
                workflow,
                'shasum -a 256 "$bound_trust_root"',
                'shasum -a 256 "$QINAO_ADMISSION_TRUST_ROOT"',
            ),
            "external-input-inside-workspace": _replace_first(
                workflow,
                ('canonical_external_path "$input_path" "$GITHUB_WORKSPACE"'),
                'canonical_external_path "$input_path"',
            ),
            "missing-external-postcheck": _replace_first(
                workflow,
                (
                    "          assert_bound_input_unchanged \\\n"
                    '            "$source_selection_fd" \\\n'
                    '            "$source_selection_metadata" \\\n'
                    '            "source selection"\n'
                ),
                "",
            ),
            "authority-operation": workflow
            + "\n# parsed comments are ignored\n"
            + "jobs:\n  injected:\n    permissions: {}\n"
            + "    runs-on: ubuntu-latest\n"
            + "    steps:\n      - run: admit-wave\n",
            "inline-comment-command-spoof": _replace_first(
                workflow,
                "          set -euo pipefail\n",
                "          : # set -euo pipefail\n",
            ),
            "unsafe-git-checkout": _replace_first(
                workflow,
                "          set -euo pipefail\n",
                "          set -euo pipefail\n          git checkout HEAD\n",
            ),
            "unsafe-textconv": _replace_first(
                workflow,
                "          set -euo pipefail\n",
                "          set -euo pipefail\n          git show --textconv HEAD\n",
            ),
            "global-config": _replace_first(
                workflow,
                '      GIT_CONFIG_GLOBAL: "/dev/null"',
                '      GIT_CONFIG_GLOBAL: "~/.gitconfig"',
            ),
            "system-config": _replace_first(
                workflow,
                '      GIT_CONFIG_SYSTEM: "/dev/null"',
                '      GIT_CONFIG_SYSTEM: "/etc/gitconfig"',
            ),
            "hooks": _replace_first(
                workflow,
                "      GIT_CONFIG_VALUE_1: /dev/null",
                "      GIT_CONFIG_VALUE_1: .githooks",
            ),
            "filter": _replace_first(
                workflow,
                '      GIT_CONFIG_VALUE_6: ""',
                "      GIT_CONFIG_VALUE_6: evil-filter",
            ),
            "fsmonitor": _replace_first(
                workflow,
                '      GIT_CONFIG_VALUE_0: "false"',
                '      GIT_CONFIG_VALUE_0: "true"',
            ),
            "rm-cleanup": _replace_first(
                workflow,
                '          test ! -e "$candidate_root"\n',
                (
                    '          /bin/rm -rf "$candidate_root"\n'
                    '          test ! -e "$candidate_root"\n'
                ),
            ),
            "provider": workflow.replace(
                "\npermissions: {}\n",
                (
                    "\npermissions: {}\n"
                    "# comment cannot satisfy structural checks\n"
                    "env:\n"
                    "  QINAO_WAVE_ADMISSION_SIGNING_PROVIDER: /tmp/provider\n"
                ),
                1,
            ),
            "blocker-shell": _replace_first(
                workflow,
                (
                    "      - name: Block authority transition until "
                    "Phase C wire exists\n"
                    "        if: ${{ always() }}\n"
                    "        shell: bash\n"
                ),
                (
                    "      - name: Block authority transition until "
                    "Phase C wire exists\n"
                    "        if: ${{ always() }}\n"
                    "        shell: sh\n"
                ),
            ),
            "blocker-continue-on-error": _replace_first(
                workflow,
                "        if: ${{ always() }}\n",
                ("        if: ${{ always() }}\n        continue-on-error: true\n"),
            ),
        }
        for label, mutated in mutations.items():
            with self.subTest(label=label):
                self.assertTrue(validate_protected_workflow(mutated))

    def test_comment_spoofs_do_not_replace_structural_actions(self) -> None:
        ordinary = _read(ORDINARY_WORKFLOW)
        real = f"      - uses: actions/setup-python@{PINNED_SETUP_PYTHON}\n"
        spoof = f"      # uses: actions/setup-python@{PINNED_SETUP_PYTHON}\n"
        mutated = _replace_first(ordinary, real, spoof)
        self.assertTrue(validate_ordinary_workflow(mutated))

    def test_invalid_duplicate_and_aliased_yaml_fail_closed(self) -> None:
        ordinary = _read(ORDINARY_WORKFLOW)
        invalid = ordinary + "\n  dangling: [\n"
        duplicate = ordinary + "\npermissions: {}\n"
        semantic_duplicate = ordinary + '\n"permissions": {}\n'
        aliased = _replace_first(
            ordinary,
            "permissions: {}",
            "permissions: &permissions {}\nextra: *permissions",
        )
        for label, mutated in (
            ("invalid", invalid),
            ("duplicate", duplicate),
            ("semantic-duplicate", semantic_duplicate),
            ("alias", aliased),
        ):
            with self.subTest(label=label):
                self.assertTrue(validate_ordinary_workflow(mutated))

    def test_yaml_11_event_key_spoofs_fail_closed(self) -> None:
        ordinary = _read(ORDINARY_WORKFLOW)
        for shadow_key in ("true", "yes", "ON"):
            mutated = _replace_first(
                ordinary,
                "on:\n",
                (f"on:\n  workflow_dispatch:\n{shadow_key}:\n"),
            )
            with self.subTest(shadow_key=shadow_key):
                errors = validate_ordinary_workflow(mutated)
                self.assertIn(
                    "ordinary exact top-level field set",
                    errors,
                )
                self.assertIn("ordinary exact event contracts", errors)

        for extra_key in ("false", "no", "off"):
            mutated = _replace_first(
                ordinary,
                "\npermissions: {}\n",
                f"\n{extra_key}: null\npermissions: {{}}\n",
            )
            with self.subTest(extra_key=extra_key):
                self.assertIn(
                    "ordinary exact top-level field set",
                    validate_ordinary_workflow(mutated),
                )

    def test_yaml_anchors_tags_and_non_scalar_keys_fail_closed(
        self,
    ) -> None:
        ordinary = _read(ORDINARY_WORKFLOW)
        mutations = {
            "anchor-without-alias": (
                _replace_first(
                    ordinary,
                    "permissions: {}",
                    "permissions: &permissions {}",
                ),
                "valid YAML: YAML anchors are forbidden",
            ),
            "explicit-tag": (
                _replace_first(
                    ordinary,
                    "permissions: {}",
                    "permissions: !!map {}",
                ),
                "valid YAML: explicit YAML tags are forbidden",
            ),
            "non-scalar-key": (
                ordinary + "\n? [unexpected]\n: value\n",
                "valid YAML: non-scalar YAML key",
            ),
        }
        for label, (mutated, diagnostic) in mutations.items():
            with self.subTest(label=label):
                self.assertIn(
                    diagnostic,
                    validate_ordinary_workflow(mutated),
                )

    def test_yaml_bool_integer_type_collisions_fail_closed(self) -> None:
        ordinary = _read(ORDINARY_WORKFLOW)
        protected = _read(PROTECTED_WORKFLOW)
        mutations = {
            "ordinary-fetch-depth-false-for-zero": (
                validate_ordinary_workflow,
                _replace_first(
                    ordinary,
                    "          fetch-depth: 0\n",
                    "          fetch-depth: false\n",
                ),
                "checkout exact reviewed step shape and inputs",
            ),
            "protected-fetch-depth-true-for-one": (
                validate_protected_workflow,
                _replace_first(
                    protected,
                    "          fetch-depth: 1\n",
                    "          fetch-depth: true\n",
                ),
                "checkout exact reviewed step shape and inputs",
            ),
            "protected-merge-one-for-true": (
                validate_protected_workflow,
                _replace_first(
                    protected,
                    "          merge-multiple: true\n",
                    "          merge-multiple: 1\n",
                ),
                ("preparation download exact reviewed step shape and service ID"),
            ),
            "protected-required-one-for-true": (
                validate_protected_workflow,
                _replace_first(
                    protected,
                    "        required: true\n",
                    "        required: 1\n",
                ),
                "protected exact dispatch input contracts",
            ),
            "protected-retention-true-for-one": (
                validate_protected_workflow,
                _replace_first(
                    protected,
                    "          retention-days: 1\n",
                    "          retention-days: true\n",
                ),
                ("candidate upload exact reviewed step shape and bounded paths"),
            ),
            "protected-hidden-zero-for-false": (
                validate_protected_workflow,
                _replace_first(
                    protected,
                    "          include-hidden-files: false\n",
                    "          include-hidden-files: 0\n",
                ),
                ("candidate upload exact reviewed step shape and bounded paths"),
            ),
        }
        for label, (validator, mutated, diagnostic) in mutations.items():
            with self.subTest(label=label):
                self.assertIn(diagnostic, validator(mutated))

    def test_protected_execution_context_injections_fail_closed(
        self,
    ) -> None:
        protected = _read(PROTECTED_WORKFLOW)
        defaults = "    defaults:\n      run:\n        shell: attacker\n"
        mutations = {
            "guard-timeout-wrong-type": (
                _replace_first(
                    protected,
                    "    timeout-minutes: 5\n",
                    "    timeout-minutes: true\n",
                ),
                ("protected runner-isolation-guard exact reviewed job context"),
            ),
            "guard-job-defaults": (
                _replace_first(
                    protected,
                    "  runner-isolation-guard:\n",
                    "  runner-isolation-guard:\n" + defaults,
                ),
                ("protected runner-isolation-guard exact reviewed job context"),
            ),
            "candidate-extra-env": (
                _replace_first(
                    protected,
                    (
                        "      QINAO_CANDIDATE_VALIDATION_RELATIVE: "
                        "qinao-candidate-validation-"
                        "${{ github.run_id }}-${{ github.run_attempt }}\n"
                    ),
                    (
                        "      QINAO_CANDIDATE_VALIDATION_RELATIVE: "
                        "qinao-candidate-validation-"
                        "${{ github.run_id }}-${{ github.run_attempt }}\n"
                        "      PYTHONPATH: attacker\n"
                    ),
                ),
                ("protected candidate-validation exact reviewed job context"),
            ),
            "candidate-job-defaults": (
                _replace_first(
                    protected,
                    "  candidate-validation:\n",
                    "  candidate-validation:\n" + defaults,
                ),
                ("protected candidate-validation exact reviewed job context"),
            ),
            "prepare-extra-env": (
                _replace_first(
                    protected,
                    (
                        "      QINAO_TRUSTED_TOOLS_RELATIVE: "
                        "qinao-trusted-tools-${{ github.run_id }}-"
                        "${{ github.run_attempt }}\n"
                    ),
                    (
                        "      QINAO_TRUSTED_TOOLS_RELATIVE: "
                        "qinao-trusted-tools-${{ github.run_id }}-"
                        "${{ github.run_attempt }}\n"
                        "      PYTHONPATH: attacker\n"
                    ),
                ),
                ("protected prepare-current-wave exact reviewed job context"),
            ),
            "prepare-job-defaults": (
                _replace_first(
                    protected,
                    "  prepare-current-wave:\n",
                    "  prepare-current-wave:\n" + defaults,
                ),
                ("protected prepare-current-wave exact reviewed job context"),
            ),
            "guard-critical-bash-env": (
                _replace_first(
                    protected,
                    (
                        "      - name: Assert protected bootstrap ref\n"
                        "        shell: bash\n"
                    ),
                    (
                        "      - name: Assert protected bootstrap ref\n"
                        "        shell: bash\n"
                        "        env:\n"
                        "          BASH_ENV: /tmp/attacker\n"
                    ),
                ),
                (
                    "protected runner-isolation-guard/"
                    "Assert protected bootstrap ref exact reviewed "
                    "step mapping"
                ),
            ),
            "candidate-critical-pythonpath": (
                _replace_first(
                    protected,
                    (
                        "      - name: Validate candidate without "
                        "admission authority\n"
                        "        id: snapshot\n"
                        "        shell: bash\n"
                    ),
                    (
                        "      - name: Validate candidate without "
                        "admission authority\n"
                        "        id: snapshot\n"
                        "        shell: bash\n"
                        "        env:\n"
                        "          PYTHONPATH: attacker\n"
                    ),
                ),
                (
                    "protected candidate-validation/"
                    "Validate candidate without admission authority "
                    "exact reviewed step mapping"
                ),
            ),
            "prepare-critical-pythonpath": (
                _replace_first(
                    protected,
                    (
                        "      - name: Build unsigned report with "
                        "pinned trusted tools\n"
                        "        shell: bash\n"
                    ),
                    (
                        "      - name: Build unsigned report with "
                        "pinned trusted tools\n"
                        "        shell: bash\n"
                        "        env:\n"
                        "          PYTHONPATH: attacker\n"
                    ),
                ),
                (
                    "protected prepare-current-wave/"
                    "Build unsigned report with pinned trusted tools "
                    "exact reviewed step mapping"
                ),
            ),
            "candidate-non-mapping-step": (
                _replace_first(
                    protected,
                    ("      - name: Validate candidate without admission authority\n"),
                    (
                        "      - false\n"
                        "      - name: Validate candidate without "
                        "admission authority\n"
                    ),
                ),
                "candidate steps have exact safe order",
            ),
        }
        for label, (mutated, diagnostic) in mutations.items():
            with self.subTest(label=label):
                self.assertIn(
                    diagnostic,
                    validate_protected_workflow(mutated),
                )

    def test_unknown_jobs_and_renamed_critical_steps_fail_closed(
        self,
    ) -> None:
        ordinary = _read(ORDINARY_WORKFLOW)
        protected = _read(PROTECTED_WORKFLOW)
        attacker_job = (
            "  attacker:\n    timeout-minutes: 1\n    permissions: {}\n    steps: []\n"
        )
        mutations = (
            (
                "ordinary-unknown-job",
                validate_ordinary_workflow,
                _replace_first(
                    ordinary,
                    "jobs:\n",
                    "jobs:\n" + attacker_job,
                ),
                "ordinary exact reviewed job set",
            ),
            (
                "protected-unknown-job",
                validate_protected_workflow,
                _replace_first(
                    protected,
                    "jobs:\n",
                    "jobs:\n" + attacker_job,
                ),
                "protected exact reviewed job set",
            ),
            (
                "protected-renamed-critical-step",
                validate_protected_workflow,
                _replace_first(
                    protected,
                    "Assert protected bootstrap ref",
                    "Renamed protected bootstrap ref",
                ),
                "runner guard has exact fail-closed step order",
            ),
        )
        for label, validator, mutated, diagnostic in mutations:
            with self.subTest(label=label):
                self.assertIn(diagnostic, validator(mutated))

    def test_strict_yaml_equality_recurses_through_mappings_and_lists(
        self,
    ) -> None:
        expected = {
            "job": {
                "timeout-minutes": 1,
                "steps": [
                    {"with": {"enabled": True, "fetch-depth": 0}},
                    False,
                    1,
                ],
            }
        }
        self.assertTrue(_strict_yaml_equal(expected, expected))
        collisions = (
            {
                "job": {
                    "timeout-minutes": True,
                    "steps": [
                        {"with": {"enabled": True, "fetch-depth": 0}},
                        False,
                        1,
                    ],
                }
            },
            {
                "job": {
                    "timeout-minutes": 1,
                    "steps": [
                        {"with": {"enabled": 1, "fetch-depth": 0}},
                        False,
                        1,
                    ],
                }
            },
            {
                "job": {
                    "timeout-minutes": 1,
                    "steps": [
                        {"with": {"enabled": True, "fetch-depth": False}},
                        False,
                        1,
                    ],
                }
            },
            {
                "job": {
                    "timeout-minutes": 1,
                    "steps": [
                        {"with": {"enabled": True, "fetch-depth": 0}},
                        0,
                        1,
                    ],
                }
            },
            {
                "job": {
                    "timeout-minutes": 1,
                    "steps": [
                        {"with": {"enabled": True, "fetch-depth": 0}},
                        False,
                        True,
                    ],
                }
            },
        )
        for actual in collisions:
            with self.subTest(actual=actual):
                self.assertFalse(_strict_yaml_equal(actual, expected))
        for actual, strict_expected in (
            ({True: "same"}, {1: "same"}),
            ({False: "same"}, {0: "same"}),
        ):
            with self.subTest(
                actual_key=next(iter(actual)),
                expected_key=next(iter(strict_expected)),
            ):
                self.assertFalse(_strict_yaml_equal(actual, strict_expected))

    def test_restricted_yaml_parser_resource_limits_fail_closed(
        self,
    ) -> None:
        node_heavy = "values: [" + ",".join(["0"] * 100001) + "]\n"
        deeply_nested = "value: " + ("[" * 130) + "0" + ("]" * 130) + "\n"
        for label, source, diagnostic in (
            (
                "input-bytes",
                "x" * 1048577,
                "workflow YAML exceeds 1048576 UTF-8 bytes",
            ),
            (
                "node-count",
                node_heavy,
                "YAML node limit exceeded",
            ),
            (
                "depth",
                deeply_nested,
                "YAML depth limit exceeded",
            ),
        ):
            with self.subTest(label=label):
                with self.assertRaisesRegex(ValueError, diagnostic):
                    _parse_yaml(source)

        timeout = subprocess.TimeoutExpired(
            cmd=["/usr/bin/ruby"],
            timeout=5,
        )
        with mock.patch.object(subprocess, "run", side_effect=timeout):
            with self.assertRaisesRegex(
                ValueError,
                "workflow YAML parser timed out",
            ):
                _parse_yaml("name: timeout-fixture\n")

        oversized_output = subprocess.CompletedProcess(
            args=["/usr/bin/ruby"],
            returncode=0,
            stdout=b"0" * 8388609,
            stderr=b"",
        )
        with mock.patch.object(
            subprocess,
            "run",
            return_value=oversized_output,
        ):
            with self.assertRaisesRegex(
                ValueError,
                "workflow YAML parser output exceeds 8388608 bytes",
            ):
                _parse_yaml("name: output-fixture\n")

    def test_workflow_top_level_fields_are_exact(self) -> None:
        for path, workflow_name, validator in (
            (
                ORDINARY_WORKFLOW,
                "Test + boundary checks",
                validate_ordinary_workflow,
            ),
            (
                PROTECTED_WORKFLOW,
                "Qinao protected unsigned current-wave preparation",
                validate_protected_workflow,
            ),
        ):
            workflow = _read(path)
            mutations = {
                "empty-workflow": "{}\n",
                "missing-name": _replace_first(
                    workflow,
                    f"name: {workflow_name}\n",
                    "",
                ),
                "extra-defaults": _replace_first(
                    workflow,
                    "\npermissions: {}\n",
                    "\ndefaults: {}\npermissions: {}\n",
                ),
            }
            for label, mutated in mutations.items():
                with self.subTest(workflow=path.name, label=label):
                    self.assertIn(
                        (
                            "ordinary exact top-level field set"
                            if path == ORDINARY_WORKFLOW
                            else "protected exact top-level field set"
                        ),
                        validator(mutated),
                    )

    def test_workflow_names_are_exact_strings(self) -> None:
        for path, expected_name, validator, diagnostic in (
            (
                ORDINARY_WORKFLOW,
                ORDINARY_WORKFLOW_NAME,
                validate_ordinary_workflow,
                "ordinary exact workflow name",
            ),
            (
                PROTECTED_WORKFLOW,
                PROTECTED_WORKFLOW_NAME,
                validate_protected_workflow,
                "protected exact workflow name",
            ),
        ):
            workflow = _read(path)
            anchor = f"name: {expected_name}\n"
            mutations = {
                "renamed": _replace_first(
                    workflow,
                    anchor,
                    "name: attacker-controlled workflow\n",
                ),
                "mapping": _replace_first(
                    workflow,
                    anchor,
                    "name: {attacker: controlled}\n",
                ),
                "boolean": _replace_first(
                    workflow,
                    anchor,
                    "name: false\n",
                ),
                "integer": _replace_first(
                    workflow,
                    anchor,
                    "name: 0\n",
                ),
            }
            for label, mutated in mutations.items():
                with self.subTest(workflow=path.name, label=label):
                    self.assertIn(diagnostic, validator(mutated))

    def test_primary_python_version_is_exact_in_all_setup_steps(
        self,
    ) -> None:
        workflow = _read(ORDINARY_WORKFLOW)
        anchor = f'          python-version: "{PRIMARY_PYTHON_VERSION}"\n'
        parts = workflow.split(anchor)
        self.assertEqual(
            len(parts),
            4,
            "ordinary CI must contain exactly three Python 3.14.5 setups",
        )
        self.assertNoContractErrors(validate_ordinary_workflow(workflow))

        for occurrence in range(3):
            for replacement in (
                '          python-version: "3.12"\n',
                '          python-version: "3.14"\n',
                '          python-version: "3.14.4"\n',
                "          python-version: true\n",
            ):
                mutated = (
                    anchor.join(parts[: occurrence + 1])
                    + replacement
                    + anchor.join(parts[occurrence + 1 :])
                )
                with self.subTest(
                    occurrence=occurrence,
                    replacement=replacement.strip(),
                ):
                    self.assertIn(
                        "setup-python exact reviewed step shape and inputs",
                        validate_ordinary_workflow(mutated),
                    )

    def test_protected_python_39_compatibility_is_a_non_skippable_primary_gate(
        self,
    ) -> None:
        ordinary = _read(ORDINARY_WORKFLOW)
        version_probe = (
            '          test "$(/usr/bin/python3 --version 2>&1)" = "Python 3.9.6"\n'
        )
        self.assertIn(version_probe, ordinary)
        self.assertNoContractErrors(validate_ordinary_workflow(ordinary))

        skip_counted_as_proof = _replace_first(
            ordinary,
            version_probe,
            version_probe.rstrip("\n") + " || true\n",
        )
        self.assertIn(
            "ordinary protected Python 3.9.6 compatibility gate exact mapping",
            validate_ordinary_workflow(skip_counted_as_proof),
        )

    def test_qinao_gate_unit_step_mutations_fail_closed(self) -> None:
        ordinary = _read(ORDINARY_WORKFLOW)
        mutations = {
            "printf-instead-of-unittest": _replace_first(
                ordinary,
                "          python3 -m unittest\n",
                "          printf '%s\\n'\n",
            ),
            "true-instead-of-unittest": _replace_first(
                ordinary,
                "          python3 -m unittest\n",
                "          true\n",
            ),
            "missing-unittest-mode": _replace_first(
                ordinary,
                "          python3 -m unittest\n",
                "          python3\n",
            ),
            "commented-out-unittest": _replace_first(
                ordinary,
                "          python3 -m unittest\n",
                "          : # python3 -m unittest\n",
            ),
            "extra-step-field": _replace_first(
                ordinary,
                (
                    "      - name: Run Qinao gate units and real "
                    "report-fixture smoke\n"
                    "        run: >-\n"
                ),
                (
                    "      - name: Run Qinao gate units and real "
                    "report-fixture smoke\n"
                    "        shell: bash\n"
                    "        run: >-\n"
                ),
            ),
        }
        for label, mutated in mutations.items():
            with self.subTest(label=label):
                self.assertIn(
                    "ordinary Qinao gate unit step exact reviewed mapping",
                    validate_ordinary_workflow(mutated),
                )

    def test_qinao_gate_job_context_mutations_fail_closed(self) -> None:
        ordinary = _read(ORDINARY_WORKFLOW)
        unit_anchor = (
            "      - name: Run Qinao gate units and real report-fixture smoke\n"
        )
        report_anchor = (
            "      - name: Run repository report replay only with external inputs\n"
        )
        mutations = {
            "run-before-unit": (
                _replace_first(
                    ordinary,
                    unit_anchor,
                    (
                        "      - name: Pollute before Qinao units\n"
                        "        run: true\n" + unit_anchor
                    ),
                ),
                "ordinary qinao-gates exact safe step sequence",
            ),
            "run-after-unit": (
                _replace_first(
                    ordinary,
                    report_anchor,
                    (
                        "      - name: Pollute after Qinao units\n"
                        "        run: true\n" + report_anchor
                    ),
                ),
                "ordinary qinao-gates exact safe step sequence",
            ),
            "non-mapping-step": (
                _replace_first(
                    ordinary,
                    unit_anchor,
                    "      - attacker\n" + unit_anchor,
                ),
                "ordinary qinao-gates exact safe step sequence",
            ),
            "pythonpath-env": (
                _replace_first(
                    ordinary,
                    (
                        "      QINAO_UNSIGNED_ADMISSION_REPORT: "
                        "${{ vars.QINAO_UNSIGNED_ADMISSION_REPORT }}\n"
                    ),
                    (
                        "      QINAO_UNSIGNED_ADMISSION_REPORT: "
                        "${{ vars.QINAO_UNSIGNED_ADMISSION_REPORT }}\n"
                        "      PYTHONPATH: attacker\n"
                    ),
                ),
                "ordinary qinao-gates exact reviewed job context",
            ),
        }
        for field, body in (
            ("defaults", "      run:\n        shell: attacker\n"),
            ("strategy", "      matrix:\n        lane: [attacker]\n"),
            ("container", "      image: attacker\n"),
            ("services", "      attacker:\n        image: attacker\n"),
        ):
            mutations[f"job-{field}"] = (
                _replace_first(
                    ordinary,
                    (
                        "  qinao-gates:\n"
                        "    name: Qinao gate contracts and unsigned "
                        "report smoke\n"
                    ),
                    (
                        "  qinao-gates:\n"
                        "    name: Qinao gate contracts and unsigned "
                        "report smoke\n"
                        f"    {field}:\n"
                        f"{body}"
                    ),
                ),
                "ordinary qinao-gates exact reviewed job context",
            )
        for label, (mutated, diagnostic) in mutations.items():
            with self.subTest(label=label):
                self.assertIn(
                    diagnostic,
                    validate_ordinary_workflow(mutated),
                )

    def test_qinao_gate_critical_step_context_mutations_fail_closed(
        self,
    ) -> None:
        ordinary = _read(ORDINARY_WORKFLOW)
        report_prefix = (
            "      - name: Run repository report replay only "
            "with external inputs\n"
            "        if: ${{ env.QINAO_EXTERNAL_REPLAY_INPUTS_READY "
            "== 'true' }}\n"
            "        shell: bash\n"
        )
        readiness_prefix = (
            "      - name: Require exclusive iOS 27 JIT runner "
            "readiness\n"
            f"        if: {FLOOR_MAIN_ONLY_GUARD}\n"
            "        shell: bash\n"
        )
        mutations = {}
        for field, body in (
            ("env", "          PYTHONPATH: attacker\n"),
            (
                "working-directory",
                "        working-directory: /tmp/attacker\n",
            ),
            ("timeout-minutes", "        timeout-minutes: 1\n"),
        ):
            insertion = "        env:\n" + body if field == "env" else body
            mutations[f"report-{field}"] = (
                _replace_first(
                    ordinary,
                    report_prefix,
                    report_prefix + insertion,
                ),
                "ordinary qinao-gates report step exact reviewed mapping",
            )
        mutations["readiness-extra-env"] = (
            _replace_first(
                ordinary,
                (
                    readiness_prefix
                    + "        env:\n"
                    + "          QINAO_IOS27_JIT_EXCLUSIVE_READY: "
                    "${{ vars.QINAO_IOS27_JIT_EXCLUSIVE_READY }}\n"
                ),
                (
                    readiness_prefix
                    + "        env:\n"
                    + "          QINAO_IOS27_JIT_EXCLUSIVE_READY: "
                    "${{ vars.QINAO_IOS27_JIT_EXCLUSIVE_READY }}\n"
                    + "          PYTHONPATH: attacker\n"
                ),
            ),
            "ordinary qinao-gates readiness step exact reviewed mapping",
        )
        for field, body in (
            (
                "working-directory",
                "        working-directory: /tmp/attacker\n",
            ),
            ("timeout-minutes", "        timeout-minutes: 1\n"),
        ):
            mutations[f"readiness-{field}"] = (
                _replace_first(
                    ordinary,
                    readiness_prefix,
                    readiness_prefix + body,
                ),
                "ordinary qinao-gates readiness step exact reviewed mapping",
            )
        for label, (mutated, diagnostic) in mutations.items():
            with self.subTest(label=label):
                self.assertIn(
                    diagnostic,
                    validate_ordinary_workflow(mutated),
                )

    def test_ios27_floor_job_context_mutations_fail_closed(self) -> None:
        ordinary = _read(ORDINARY_WORKFLOW)
        mutations = {
            "non-mapping-step": (
                _replace_first(
                    ordinary,
                    "      - name: Run iOS 27 floor unit tests\n",
                    ("      - attacker\n      - name: Run iOS 27 floor unit tests\n"),
                ),
                "ordinary Xcode 27 floor steps have exact safe order",
            ),
            "pythonpath-env": (
                _replace_first(
                    ordinary,
                    (
                        "      QINAO_IOS27_FLOOR_RELATIVE: "
                        "qinao-ios27-floor-${{ github.run_id }}-"
                        "${{ github.run_attempt }}\n"
                    ),
                    (
                        "      QINAO_IOS27_FLOOR_RELATIVE: "
                        "qinao-ios27-floor-${{ github.run_id }}-"
                        "${{ github.run_attempt }}\n"
                        "      PYTHONPATH: attacker\n"
                    ),
                ),
                "ordinary iOS 27 floor exact reviewed job context",
            ),
        }
        for field, body in (
            ("defaults", "      run:\n        shell: attacker\n"),
            ("strategy", "      matrix:\n        lane: [attacker]\n"),
            ("container", "      image: attacker\n"),
            ("services", "      attacker:\n        image: attacker\n"),
        ):
            mutations[f"job-{field}"] = (
                _replace_first(
                    ordinary,
                    "  qinao-ios27-floor:\n",
                    (f"  qinao-ios27-floor:\n    {field}:\n{body}"),
                ),
                "ordinary iOS 27 floor exact reviewed job context",
            )
        for label, (mutated, diagnostic) in mutations.items():
            with self.subTest(label=label):
                self.assertIn(
                    diagnostic,
                    validate_ordinary_workflow(mutated),
                )

    def test_ios27_floor_gate_and_step_mutations_fail_closed(self) -> None:
        ordinary = _read(ORDINARY_WORKFLOW)
        working_directory = (
            "${{ github.workspace }}/${{ env.QINAO_IOS27_FLOOR_RELATIVE }}"
        )
        root_prefix = (
            "      - name: Assert isolated iOS 27 floor root is absent\n"
            "        shell: bash\n"
        )
        toolchain_prefix = (
            "      - name: Assert Xcode 27 toolchain\n"
            "        shell: bash\n"
            f"        working-directory: {working_directory}\n"
        )
        unit_prefix = (
            "      - name: Run iOS 27 floor unit tests\n"
            f"        working-directory: {working_directory}\n"
        )
        local_prefix = (
            "      - name: Run local iOS 27 floor check\n"
            f"        working-directory: {working_directory}\n"
        )
        mutations = {
            "unit-run-true": (
                _replace_first(
                    ordinary,
                    (
                        unit_prefix
                        + "        run: >-\n"
                        + "          python3 -m unittest\n"
                        + "          BehavioralAISubstrate.scripts."
                        "test_check_ios27_floor\n"
                    ),
                    unit_prefix + "        run: true\n",
                ),
                "ordinary iOS 27 floor unit step exact reviewed mapping",
            ),
            "local-run-true": (
                _replace_first(
                    ordinary,
                    (
                        local_prefix + "        run: BehavioralAISubstrate/scripts/"
                        "check-ios27-floor.sh\n"
                    ),
                    local_prefix + "        run: true\n",
                ),
                "ordinary iOS 27 floor local step exact reviewed mapping",
            ),
            "root-extra-env": (
                _replace_first(
                    ordinary,
                    root_prefix,
                    (
                        root_prefix
                        + "        env:\n"
                        + "          PYTHONPATH: attacker\n"
                    ),
                ),
                "ordinary iOS 27 floor root step exact reviewed mapping",
            ),
            "toolchain-timeout": (
                _replace_first(
                    ordinary,
                    toolchain_prefix,
                    toolchain_prefix + "        timeout-minutes: 1\n",
                ),
                "ordinary iOS 27 floor toolchain step exact reviewed mapping",
            ),
            "unit-extra-env": (
                _replace_first(
                    ordinary,
                    unit_prefix,
                    (
                        unit_prefix
                        + "        env:\n"
                        + "          PYTHONPATH: attacker\n"
                    ),
                ),
                "ordinary iOS 27 floor unit step exact reviewed mapping",
            ),
            "local-extra-env": (
                _replace_first(
                    ordinary,
                    local_prefix,
                    (
                        local_prefix
                        + "        env:\n"
                        + "          PYTHONPATH: attacker\n"
                    ),
                ),
                "ordinary iOS 27 floor local step exact reviewed mapping",
            ),
        }
        for label, (mutated, diagnostic) in mutations.items():
            with self.subTest(label=label):
                self.assertIn(
                    diagnostic,
                    validate_ordinary_workflow(mutated),
                )

    def test_protected_ref_guard_has_only_fail_closed_terminals(
        self,
    ) -> None:
        document = _parse_yaml(_read(PROTECTED_WORKFLOW))
        guard = _jobs(document).get("runner-isolation-guard", {})
        body = _named_step(
            guard if isinstance(guard, dict) else {},
            "Assert protected bootstrap ref",
        ).get("run")
        self.assertIsInstance(body, str)
        assert isinstance(body, str)
        good = subprocess.run(
            ["/bin/bash"],
            input=body,
            text=True,
            capture_output=True,
            env={
                "GITHUB_REF": PROTECTED_REF,
                "PATH": "/usr/bin:/bin",
            },
            check=False,
        )
        wrong = subprocess.run(
            ["/bin/bash"],
            input=body,
            text=True,
            capture_output=True,
            env={
                "GITHUB_REF": "refs/heads/main",
                "PATH": "/usr/bin:/bin",
            },
            check=False,
        )
        self.assertEqual(good.returncode, 0, good.stderr)
        self.assertNotEqual(wrong.returncode, 0)
        self.assertIn(
            "BLOCKED_PHASE_C_PROTECTED_REF_REQUIRED",
            wrong.stdout,
        )

    def test_candidate_supervisor_observes_without_reaping_then_cleans_group(
        self,
    ) -> None:
        source = _candidate_supervisor_source(_read(PROTECTED_WORKFLOW))
        tree = ast.parse(source, filename="<candidate-supervisor>")
        calls = [node for node in ast.walk(tree) if isinstance(node, ast.Call)]
        waitid_calls = [
            node for node in calls if _dotted_name(node.func) == "os.waitid"
        ]
        observe_calls = [
            node for node in calls if _dotted_name(node.func) == "observe_process_exit"
        ]
        process_wait_calls = [
            node
            for node in calls
            if _dotted_name(node.func)
            in {"process.wait", "process.poll", "process.communicate"}
        ]
        term_calls = [
            node
            for node in calls
            if _dotted_name(node.func) == "signal_validation_group"
            and any(
                _dotted_name(argument) == "signal.SIGTERM" for argument in node.args
            )
        ]
        kill_calls = [
            node
            for node in calls
            if _dotted_name(node.func) == "signal_validation_group"
            and any(
                _dotted_name(argument) == "signal.SIGKILL" for argument in node.args
            )
        ]
        publish_calls = [
            node
            for node in calls
            if _dotted_name(node.func) == "publish_bound_validation_log"
        ]
        self.assertEqual(len(waitid_calls), 1)
        self.assertEqual(len(observe_calls), 3)
        self.assertIn(
            "wait_flags = os.WEXITED | os.WNOHANG | os.WNOWAIT",
            source,
        )
        self.assertEqual(len(term_calls), 1)
        self.assertEqual(len(kill_calls), 1)
        self.assertEqual(len(process_wait_calls), 1)
        self.assertEqual(len(publish_calls), 1)
        observe_lines = sorted(node.lineno for node in observe_calls)
        term_line = term_calls[0].lineno
        kill_line = kill_calls[0].lineno
        self.assertLess(observe_lines[0], term_line)
        self.assertLess(term_line, observe_lines[1])
        self.assertLess(observe_lines[1], kill_line)
        self.assertLess(kill_line, observe_lines[2])
        self.assertLess(kill_line, process_wait_calls[0].lineno)
        self.assertLess(
            process_wait_calls[0].lineno,
            publish_calls[0].lineno,
        )
        self.assertEqual(
            sum(_dotted_name(node.func) == "os.killpg" for node in calls),
            1,
        )
        self.assertIn("import selectors\n", source)
        self.assertIn("libc_waitid = libc.waitid\n", source)
        self.assertIn(
            "stdout=subprocess.PIPE,\n",
            source,
        )
        self.assertIn(
            "remaining = max(0, 8388608 - log_bytes)\n"
            "        accepted = chunk[:remaining]\n",
            source,
        )
        self.assertNotIn("resource.RLIMIT_FSIZE", source)
        self.assertNotIn("preexec_fn=", source)
        for token in (
            "if written == 0:",
            "descriptor_before = os.fstat(descriptor)",
            "path_metadata = os.lstat(path)",
            "descriptor_before.st_nlink != 1",
            "descriptor_before.st_size != expected_size",
            "actual_digest != expected_digest",
            "dir_fd=root_descriptor",
        ):
            self.assertIn(token, source)

    def test_candidate_supervisor_caps_times_out_and_cleans_descendants(
        self,
    ) -> None:
        source = _candidate_supervisor_source(_read(PROTECTED_WORKFLOW))
        with (
            tempfile.TemporaryDirectory() as directory,
            tempfile.TemporaryDirectory() as runtime_directory,
        ):
            candidate_root = Path(directory)
            probe_source = (
                "import os\n"
                "import subprocess\n"
                "import unittest\n"
                "from pathlib import Path\n\n"
                "class CandidateLimitProbe(unittest.TestCase):\n"
                "    def test_log_cap_and_group_cleanup(self):\n"
                "        artifact = Path('large-build-artifact.bin')\n"
                "        with artifact.open('wb') as stream:\n"
                "            for _ in range(256):\n"
                "                stream.write(b'a' * 65536)\n"
                "        sleeper = subprocess.Popen(['/bin/sleep', '60'])\n"
                "        Path('same-session-descendant.pid')"
                ".write_text(str(sleeper.pid), encoding='utf-8')\n"
                "        chunk = b'x' * 65536\n"
                "        while True:\n"
                "            os.write(1, chunk)\n"
            )
            _write_candidate_supervisor_fixture(
                candidate_root,
                probe_source,
            )

            pid_path = candidate_root / "same-session-descendant.pid"
            large_artifact_path = candidate_root / "large-build-artifact.bin"
            raw_log = candidate_root / "candidate.raw.log"
            artifact_root = candidate_root / "published-artifact"
            environment = dict(os.environ)
            environment["RUNNER_TEMP"] = os.path.realpath(runtime_directory)
            # This subcase proves the byte cap, not the timeout branch. Leave
            # enough wall-clock headroom for parallel CI load so an exact
            # 8 MiB prefix cannot race the producer's next over-cap byte.
            result = subprocess.run(
                [
                    sys.executable,
                    "-c",
                    source,
                    str(candidate_root),
                    str(raw_log),
                    str(artifact_root),
                    "30.0",
                ],
                cwd=PROJECT_ROOT,
                env=environment,
                text=True,
                capture_output=True,
                timeout=40,
                check=False,
            )
            self.assertEqual(
                result.returncode,
                125,
                result.stderr,
            )
            self.assertTrue(pid_path.is_file(), result.stderr)
            self.assertTrue(raw_log.is_file(), result.stderr)
            self.assertEqual(raw_log.stat().st_size, 8388608)
            self.assertFalse(artifact_root.exists())
            self.assertEqual(
                large_artifact_path.stat().st_size,
                16777216,
                "log cap must not constrain legitimate build artifacts",
            )

            sleeper_pid = int(pid_path.read_text(encoding="utf-8"))
            try:
                deadline = time.monotonic() + 3
                while time.monotonic() < deadline:
                    try:
                        os.kill(sleeper_pid, 0)
                    except ProcessLookupError:
                        break
                    time.sleep(0.05)
                else:
                    self.fail("same-session descendant survived group SIGKILL")
            finally:
                try:
                    os.kill(sleeper_pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass

        with (
            tempfile.TemporaryDirectory() as directory,
            tempfile.TemporaryDirectory() as runtime_directory,
        ):
            candidate_root = Path(directory)
            timeout_probe_source = (
                "import os\n"
                "import subprocess\n"
                "import time\n"
                "import unittest\n"
                "from pathlib import Path\n\n"
                "class CandidateTimeoutProbe(unittest.TestCase):\n"
                "    def test_timeout_and_group_cleanup(self):\n"
                "        sleeper = subprocess.Popen(['/bin/sleep', '60'])\n"
                "        Path('descendant.pid')"
                ".write_text(str(sleeper.pid), encoding='utf-8')\n"
                "        Path('group.pid')"
                ".write_text(str(os.getpgrp()), encoding='utf-8')\n"
                "        time.sleep(60)\n"
            )
            _write_candidate_supervisor_fixture(
                candidate_root,
                timeout_probe_source,
            )
            pid_path = candidate_root / "descendant.pid"
            group_path = candidate_root / "group.pid"
            raw_log = candidate_root / "candidate.raw.log"
            artifact_root = candidate_root / "published-artifact"
            environment = dict(os.environ)
            environment["RUNNER_TEMP"] = os.path.realpath(runtime_directory)
            result = subprocess.run(
                [
                    sys.executable,
                    "-c",
                    source,
                    str(candidate_root),
                    str(raw_log),
                    str(artifact_root),
                    "5.0",
                ],
                cwd=PROJECT_ROOT,
                env=environment,
                text=True,
                capture_output=True,
                timeout=15,
                check=False,
            )
            self.assertEqual(
                result.returncode,
                124,
                result.stderr,
            )
            self.assertTrue(pid_path.is_file(), result.stderr)
            self.assertTrue(raw_log.is_file(), result.stderr)
            self.assertFalse(artifact_root.exists())
            sleeper_pid = int(pid_path.read_text(encoding="utf-8"))
            try:
                deadline = time.monotonic() + 3
                while time.monotonic() < deadline:
                    try:
                        os.kill(sleeper_pid, 0)
                    except ProcessLookupError:
                        break
                    time.sleep(0.05)
                else:
                    self.fail("timeout descendant survived group SIGKILL")
            finally:
                try:
                    os.kill(sleeper_pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass

        with (
            tempfile.TemporaryDirectory() as directory,
            tempfile.TemporaryDirectory() as runtime_directory,
        ):
            candidate_root = Path(directory)
            _write_candidate_supervisor_fixture(
                candidate_root,
                timeout_probe_source,
            )
            pid_path = candidate_root / "descendant.pid"
            group_path = candidate_root / "group.pid"
            raw_log = candidate_root / "candidate.raw.log"
            artifact_root = candidate_root / "published-artifact"
            environment = dict(os.environ)
            environment["RUNNER_TEMP"] = os.path.realpath(runtime_directory)
            wrapper = (
                "import os\n"
                "import sys\n\n"
                "source = sys.stdin.read()\n"
                "def deny_group_signal(process_group, group_signal):\n"
                "    raise PermissionError("
                "1, 'injected group cleanup denial')\n"
                "os.killpg = deny_group_signal\n"
                "exec(compile(source, '<candidate-supervisor>', 'exec'))\n"
            )
            try:
                result = subprocess.run(
                    [
                        sys.executable,
                        "-c",
                        wrapper,
                        str(candidate_root),
                        str(raw_log),
                        str(artifact_root),
                        "5.0",
                    ],
                    cwd=PROJECT_ROOT,
                    env=environment,
                    input=source,
                    text=True,
                    capture_output=True,
                    timeout=15,
                    check=False,
                )
                self.assertEqual(
                    result.returncode,
                    125,
                    result.stderr,
                )
                self.assertTrue(pid_path.is_file(), result.stderr)
                self.assertTrue(group_path.is_file(), result.stderr)
                self.assertTrue(raw_log.is_file(), result.stderr)
                self.assertFalse(artifact_root.exists())
                denied_sleeper = int(pid_path.read_text(encoding="utf-8"))
                os.kill(denied_sleeper, 0)
            finally:
                if group_path.is_file():
                    denied_group = int(group_path.read_text(encoding="utf-8"))
                    try:
                        os.killpg(denied_group, signal.SIGKILL)
                    except ProcessLookupError:
                        pass
                if pid_path.is_file():
                    denied_sleeper = int(pid_path.read_text(encoding="utf-8"))
                    deadline = time.monotonic() + 3
                    while time.monotonic() < deadline:
                        try:
                            os.kill(denied_sleeper, 0)
                        except ProcessLookupError:
                            break
                        time.sleep(0.05)

    def test_candidate_supervisor_rejects_untrusted_runtime_temp(
        self,
    ) -> None:
        source = _candidate_supervisor_source(_read(PROTECTED_WORKFLOW))
        with (
            tempfile.TemporaryDirectory() as directory,
            tempfile.TemporaryDirectory() as runtime_directory,
        ):
            candidate_root = Path(directory)
            canonical_runtime_temp = os.path.realpath(runtime_directory)
            runtime_temp_link = candidate_root / "runtime-temp-link"
            runtime_temp_link.symlink_to(
                canonical_runtime_temp,
                target_is_directory=True,
            )
            cases = {
                "missing": None,
                "symlinked": str(runtime_temp_link),
                "noncanonical-spelling": f"{canonical_runtime_temp}/.",
            }
            for label, runtime_temp in cases.items():
                with self.subTest(label=label):
                    raw_log = candidate_root / f"{label}.raw.log"
                    artifact_root = candidate_root / f"{label}-artifact"
                    environment = dict(os.environ)
                    environment.pop("RUNNER_TEMP", None)
                    if runtime_temp is not None:
                        environment["RUNNER_TEMP"] = runtime_temp
                    result = subprocess.run(
                        [
                            sys.executable,
                            "-c",
                            source,
                            str(candidate_root),
                            str(raw_log),
                            str(artifact_root),
                            "10.0",
                        ],
                        cwd=PROJECT_ROOT,
                        env=environment,
                        text=True,
                        capture_output=True,
                        timeout=15,
                        check=False,
                    )
                    self.assertNotEqual(result.returncode, 0)
                    self.assertFalse(raw_log.exists())
                    self.assertFalse(artifact_root.exists())

    def test_candidate_supervisor_rejects_raw_log_path_replacement(
        self,
    ) -> None:
        source = _candidate_supervisor_source(_read(PROTECTED_WORKFLOW))
        with (
            tempfile.TemporaryDirectory() as directory,
            tempfile.TemporaryDirectory() as runtime_directory,
        ):
            candidate_root = Path(directory)
            probe_source = (
                "import os\n"
                "import unittest\n"
                "from pathlib import Path\n\n"
                "class CandidatePathProbe(unittest.TestCase):\n"
                "    def test_replace_raw_log_path(self):\n"
                "        raw_log = Path('candidate.raw.log')\n"
                "        raw_log.unlink()\n"
                "        raw_log.write_bytes(b'forged')\n"
            )
            _write_candidate_supervisor_fixture(
                candidate_root,
                probe_source,
            )
            raw_log = candidate_root / "candidate.raw.log"
            artifact_root = candidate_root / "published-artifact"
            environment = dict(os.environ)
            environment["RUNNER_TEMP"] = os.path.realpath(runtime_directory)
            result = subprocess.run(
                [
                    sys.executable,
                    "-c",
                    source,
                    str(candidate_root),
                    str(raw_log),
                    str(artifact_root),
                    "10.0",
                ],
                cwd=PROJECT_ROOT,
                env=environment,
                text=True,
                capture_output=True,
                timeout=15,
                check=False,
            )
            self.assertNotEqual(result.returncode, 0)
            self.assertIn(
                "candidate raw log binding changed",
                result.stderr,
            )
            self.assertEqual(raw_log.read_bytes(), b"forged")
            self.assertFalse(artifact_root.exists())

    def test_candidate_supervisor_publishes_exact_bound_log_after_cleanup(
        self,
    ) -> None:
        source = _candidate_supervisor_source(_read(PROTECTED_WORKFLOW))
        with (
            tempfile.TemporaryDirectory() as directory,
            tempfile.TemporaryDirectory() as runtime_directory,
        ):
            candidate_root = Path(directory)
            _write_candidate_supervisor_fixture(
                candidate_root,
                (
                    "import unittest\n\n"
                    "class CandidateSuccessProbe(unittest.TestCase):\n"
                    "    def test_success(self):\n"
                    "        self.assertTrue(True)\n"
                ),
            )
            raw_log = candidate_root / "candidate.raw.log"
            artifact_root = candidate_root / "published-artifact"
            environment = dict(os.environ)
            environment["RUNNER_TEMP"] = os.path.realpath(runtime_directory)
            result = subprocess.run(
                [
                    sys.executable,
                    "-c",
                    source,
                    str(candidate_root),
                    str(raw_log),
                    str(artifact_root),
                    "10.0",
                ],
                cwd=PROJECT_ROOT,
                env=environment,
                text=True,
                capture_output=True,
                timeout=15,
                check=False,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            published = artifact_root / "validation.log"
            self.assertEqual(
                sorted(path.name for path in artifact_root.iterdir()),
                ["validation.log"],
            )
            self.assertEqual(
                published.read_bytes(),
                raw_log.read_bytes(),
            )
            self.assertEqual(
                published.stat().st_mode & 0o777,
                0o600,
            )
            self.assertEqual(
                artifact_root.stat().st_mode & 0o777,
                0o700,
            )

    def test_all_run_bodies_parse_with_macos_bash_3_2(self) -> None:
        self.assertEqual(platform.system(), "Darwin")
        version = subprocess.run(
            ["/bin/bash", "--version"],
            text=True,
            capture_output=True,
            check=True,
        ).stdout
        self.assertIn("version 3.2.", version)
        bodies: list[tuple[str, str, str]] = []
        for path in (ORDINARY_WORKFLOW, PROTECTED_WORKFLOW):
            document = _parse_yaml(_read(path))
            for job_name, step in _run_steps(document):
                bodies.append((path.name, job_name, str(step.get("run"))))
        self.assertGreaterEqual(len(bodies), 24)
        for workflow, job, body in bodies:
            with self.subTest(workflow=workflow, job=job):
                result = subprocess.run(
                    ["/bin/bash", "-n"],
                    input=body,
                    text=True,
                    capture_output=True,
                    check=False,
                )
                self.assertEqual(result.returncode, 0, result.stderr)

    def test_runner_accepts_fd_bound_external_inputs(self) -> None:
        from scripts.run_qinao_wave_admission import external_file_bytes

        with (
            tempfile.TemporaryDirectory() as external_directory,
            tempfile.TemporaryDirectory() as repository_directory,
        ):
            external_path = Path(external_directory) / "bound.json"
            external_path.write_bytes(b"{}\n")
            external_path.chmod(0o600)
            descriptor = os.open(external_path, os.O_RDONLY)
            try:
                resolved, raw, identity = external_file_bytes(
                    Path(f"/dev/fd/{descriptor}"),
                    Path(repository_directory).resolve(),
                    "FD-bound workflow smoke",
                )
                metadata = os.fstat(descriptor)
                self.assertEqual(resolved, Path(f"/dev/fd/{descriptor}"))
                self.assertEqual(raw, b"{}\n")
                self.assertEqual(
                    identity,
                    (metadata.st_dev, metadata.st_ino),
                )
            finally:
                os.close(descriptor)

    def test_workflow_diff_has_no_whitespace_errors(self) -> None:
        result = subprocess.run(
            [
                "/usr/bin/git",
                "diff",
                "--check",
                "--",
                str(ORDINARY_WORKFLOW.relative_to(PROJECT_ROOT)),
                str(PROTECTED_WORKFLOW.relative_to(PROJECT_ROOT)),
                str(Path(__file__).resolve().relative_to(PROJECT_ROOT)),
            ],
            cwd=PROJECT_ROOT,
            text=True,
            capture_output=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
