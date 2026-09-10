from __future__ import annotations

import functools
import json
import os
import platform
import re
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path
from typing import Any
from unittest import mock


PROJECT_ROOT = Path(__file__).resolve().parents[1]
ORDINARY_WORKFLOW = PROJECT_ROOT / ".github/workflows/test.yml"
PROTECTED_WORKFLOW = PROJECT_ROOT / ".github/workflows/qinao-wave-admission.yml"
PINNED_CHECKOUT = "11bd71901bbe5b1630ceea73d27597364c9af683"
PINNED_SETUP_PYTHON = "a309ff8b426b58ec0e2a45f0f869d46889d02405"
PRIMARY_PYTHON_VERSION = "3.14.5"
ORDINARY_WORKFLOW_NAME = "Test + boundary checks"
WORKFLOW_TOP_LEVEL_FIELDS = {"name", "on", "permissions", "jobs"}
ALLOWED_EXTERNAL_USES = {
    f"actions/checkout@{PINNED_CHECKOUT}",
    f"actions/setup-python@{PINNED_SETUP_PYTHON}",
}
ORDINARY_EVENTS = {
    "push": {"branches": ["main", "m605-chapter-*", "decode-*"]},
    "pull_request": {"branches": ["main"]},
    "workflow_dispatch": None,
}
APPLE_JOBS = {"bas-tests", "qinao-tests", "samplehost-tests", "boundary-checks"}


def _xcode27_selection(sdks: str = "macosx") -> dict[str, str]:
    return {"name": "Select Xcode", "run": "set -e\n"
            "sudo xcode-select -s /Applications/Xcode.app\n"
            f"bash scripts/check_ci_xcode27.sh {sdks}\n"}


def _metal_preparation(sdks: str = "macosx") -> dict[str, str]:
    return {"name": "Prepare Metal compiler",
            "run": f"bash scripts/ensure_ci_metal_toolchain.sh {sdks}"}


# These are the product commands CI must actually execute, not admission inputs.
PRODUCT_STEPS = {
    "bas-tests": [
        _xcode27_selection(),
        _metal_preparation(),
        {"name": "BAS test", "run": "swift test --package-path BehavioralAISubstrate"},
    ],
    "qinao-tests": [
        _xcode27_selection(),
        _metal_preparation(),
        {"name": "Qinao test", "working-directory": "QinaoRuntimeSDK", "run": "swift test"},
    ],
    "samplehost-tests": [
        _xcode27_selection("macosx iphonesimulator"),
        _metal_preparation("macosx iphonesimulator"),
        {
            "name": "Build SampleHost for iOS Simulator",
            "working-directory": "SampleHost",
            "run": "xcodebuild build \\\n"
                   "  -scheme SampleHost \\\n"
                   "  -destination 'platform=iOS Simulator,name=iPhone 17e' \\\n"
                   "  CODE_SIGNING_ALLOWED=NO\n",
        },
        {
            "name": "Test SampleHost on iOS Simulator",
            "working-directory": "SampleHost",
            "run": "xcodebuild test \\\n"
                   "  -scheme SampleHost \\\n"
                   "  -destination 'platform=iOS Simulator,name=iPhone 17e' \\\n"
                   "  CODE_SIGNING_ALLOWED=NO\n",
        },
    ],
    "boundary-checks": [
        _xcode27_selection(),
        _metal_preparation(),
        {"name": "Qinao import boundaries", "run": "bash scripts/check_qinao_import_boundaries.sh"},
        {"name": "Sovereign redaction", "run": "bash scripts/check_sovereign_redaction.sh"},
        {"name": "SDK import boundaries", "run": "bash scripts/check_sdk_import_boundaries.sh"},
        {"name": "Substrate residuals", "run": "bash scripts/check_substrate_residuals.sh"},
        {"name": "Cross-language schema parity", "run": "python3 scripts/check_chenglu_schema_parity.py"},
        {"name": "God-file size guard (M762 chapter 203)", "run": "bash scripts/check_god_files.sh"},
        {
            "name": "CI contract and iOS floor helper tests",
            "run": "set -e\ncommand -v rg\n"
                   "python3 -B -m unittest -v scripts.test_test_workflow_owner_ledger "
                   "BehavioralAISubstrate.scripts.test_check_ios27_floor "
                   "scripts.test_boundary_tool_errors scripts.test_ci_metal_toolchain\n",
        },
    ],
    "python-fuzz": [
        {
            "name": "Setup Python",
            "uses": f"actions/setup-python@{PINNED_SETUP_PYTHON}",
            "with": {"python-version": PRIMARY_PYTHON_VERSION},
        },
        {
            "name": "Run pytest",
            "run": "pip install pytest\npython3 -m pytest scripts/test_chenglu_feature_schema.py -v\n",
        },
    ],
    "rust-tests": [
        {
            "name": "cargo build + test (locked, pinned toolchain)",
            "working-directory": "BehavioralAISubstrate/Cargo",
            "run": "cargo build --locked --release\ncargo test --locked\n",
        },
    ],
}
ORDINARY_JOBS = set(PRODUCT_STEPS)
JOB_NAMES_AND_TIMEOUTS = {
    "bas-tests": ("BehavioralAISubstrate XCTest", 30),
    "qinao-tests": ("QinaoRuntimeSDK XCTest", 30),
    "samplehost-tests": ("SampleHost iOS XCTest", 45),
    "boundary-checks": ("4 boundary scripts + schema parity", 10),
    "python-fuzz": ("Python pytest fuzz tests", 5),
    "rust-tests": ("Rust cargo build + test (--locked)", 20),
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


def validate_ordinary_workflow(text: str) -> list[str]:
    document, errors = _validate_yaml_and_actions(text)
    if not document and errors:
        return errors
    _require(errors, set(document) == WORKFLOW_TOP_LEVEL_FIELDS,
             "ordinary exact top-level field set")
    _require(errors, _strict_yaml_equal(document.get("name"), ORDINARY_WORKFLOW_NAME),
             "ordinary exact workflow name")
    _require(errors, _strict_yaml_equal(document.get("permissions"), {}),
             "ordinary top-level permissions are empty")
    _require(errors, _strict_yaml_equal(_events(document), ORDINARY_EVENTS),
             "ordinary exact event contracts")
    _require(errors, set(_jobs(document)) == ORDINARY_JOBS,
             "ordinary exact reviewed job set")
    _validate_no_write_permissions(document, errors)
    for name, job in _jobs(document).items():
        if name not in ORDINARY_JOBS or not isinstance(job, dict):
            errors.append(f"unexpected or invalid job: {name}")
            continue
        display_name, timeout = JOB_NAMES_AND_TIMEOUTS[name]
        context = {key: value for key, value in job.items() if key != "steps"}
        _require(errors, _strict_yaml_equal(context, {
            "name": display_name, "runs-on": "xcode-27" if name in APPLE_JOBS else "macos-latest",
            "timeout-minutes": timeout, "permissions": {"contents": "read"},
        }), f"ordinary job {name} exact execution context")
        steps = job.get("steps")
        if not isinstance(steps, list) or not steps:
            errors.append(f"ordinary job {name} has nonempty steps")
            continue
        _validate_checkout(errors, steps[0], fetch_depth=0)
        _require(errors, _strict_yaml_equal(steps[1:], PRODUCT_STEPS[name]),
                 f"ordinary job {name} executes required product steps")
        if name == "python-fuzz":
            _validate_setup_python(
                errors, steps[1] if len(steps) > 1 else {}, name="Setup Python",
            )
    return errors


def _replace_first(text: str, old: str, new: str) -> str:
    if old not in text:
        raise AssertionError(f"mutation anchor is absent: {old!r}")
    return text.replace(old, new, 1)


class WorkflowOwnerLedgerTests(unittest.TestCase):
    maxDiff = None

    def assertNoContractErrors(self, errors: list[str]) -> None:
        self.assertEqual(errors, [])

    def test_active_ci_runs_only_the_six_product_jobs(self) -> None:
        document = _parse_yaml(_read(ORDINARY_WORKFLOW))
        self.assertEqual(set(_jobs(document)), {
            "bas-tests", "qinao-tests", "samplehost-tests",
            "boundary-checks", "python-fuzz", "rust-tests",
        })

    def test_protected_admission_is_not_an_active_workflow(self) -> None:
        self.assertFalse(PROTECTED_WORKFLOW.exists())

    def test_ordinary_workflow_contract(self) -> None:
        self.assertNoContractErrors(validate_ordinary_workflow(_read(ORDINARY_WORKFLOW)))

    def test_apple_jobs_select_standard_xcode27_before_product_steps(self) -> None:
        document = _parse_yaml(_read(ORDINARY_WORKFLOW))
        for name in ("bas-tests", "qinao-tests", "samplehost-tests", "boundary-checks"):
            with self.subTest(job=name):
                job = document["jobs"][name]
                self.assertEqual(job["runs-on"], "xcode-27")
                self.assertEqual(job["steps"][1]["name"], "Select Xcode")
                sdks = "macosx iphonesimulator" if name == "samplehost-tests" else "macosx"
                self.assertIn(f"bash scripts/check_ci_xcode27.sh {sdks}\n", job["steps"][1]["run"])
        for name in ("rust-tests", "python-fuzz"):
            self.assertEqual(document["jobs"][name]["runs-on"], "macos-latest")

    def test_boundary_error_suite_is_an_explicit_ci_consumer(self) -> None:
        document = _parse_yaml(_read(ORDINARY_WORKFLOW))
        helper = _named_step(document["jobs"]["boundary-checks"],
                             "CI contract and iOS floor helper tests")
        self.assertIn("scripts.test_boundary_tool_errors", helper["run"].split())
        self.assertIn("command -v rg", helper["run"])

    def test_apple_jobs_prepare_metal_before_product_commands(self) -> None:
        document = _parse_yaml(_read(ORDINARY_WORKFLOW))
        for name in ("bas-tests", "qinao-tests", "samplehost-tests", "boundary-checks"):
            with self.subTest(job=name):
                steps = document["jobs"][name]["steps"]
                self.assertEqual(steps[2]["name"], "Prepare Metal compiler")
                sdks = "macosx iphonesimulator" if name == "samplehost-tests" else "macosx"
                self.assertEqual(steps[2]["run"],
                                 f"bash scripts/ensure_ci_metal_toolchain.sh {sdks}")
        helper = _named_step(document["jobs"]["boundary-checks"],
                             "CI contract and iOS floor helper tests")
        self.assertIn("scripts.test_ci_metal_toolchain", helper["run"].split())

    def test_apple_alignment_and_boundary_consumer_mutations_are_rejected(self) -> None:
        document = _parse_yaml(_read(ORDINARY_WORKFLOW))
        self.assertNoContractErrors(validate_ordinary_workflow(json.dumps(document)))
        for name in ("bas-tests", "qinao-tests", "samplehost-tests", "boundary-checks"):
            for runner in ("macos-latest", "xcode-27-xlarge", "xcode-26"):
                changed = json.loads(json.dumps(document))
                changed["jobs"][name]["runs-on"] = runner
                with self.subTest(job=name, runner=runner):
                    self.assertTrue(validate_ordinary_workflow(json.dumps(changed)))
            for old, new in (("scripts/check_ci_xcode27.sh", "scripts/other.sh"),
                             (" macosx", " macosx26.6"),
                             (" macosx", ""),
                             ("bash scripts/check_ci_xcode27.sh", "true")):
                changed = json.loads(json.dumps(document))
                step = _named_step(changed["jobs"][name], "Select Xcode")
                self.assertIn(old, step["run"])
                step["run"] = step["run"].replace(old, new)
                with self.subTest(job=name, mutation=old):
                    self.assertTrue(validate_ordinary_workflow(json.dumps(changed)))
        changed = json.loads(json.dumps(document))
        step = _named_step(changed["jobs"]["samplehost-tests"], "Select Xcode")
        self.assertIn(" iphonesimulator", step["run"])
        step["run"] = step["run"].replace(" iphonesimulator", "")
        self.assertTrue(validate_ordinary_workflow(json.dumps(changed)))
        for old, new in ((" scripts.test_boundary_tool_errors", ""),
                         (" scripts.test_ci_metal_toolchain", ""),
                         ("command -v rg", "command -v rg || true"),
                         ("command -v rg\n", "")):
            changed = json.loads(json.dumps(document))
            step = _named_step(changed["jobs"]["boundary-checks"],
                               "CI contract and iOS floor helper tests")
            self.assertIn(old, step["run"])
            step["run"] = step["run"].replace(old, new)
            with self.subTest(mutation=old):
                self.assertTrue(validate_ordinary_workflow(json.dumps(changed)))

    def _run_selection_fixture(
        self, body: str, overrides: dict[str, str] | None = None,
    ) -> tuple[subprocess.CompletedProcess[str], list[str]]:
        with tempfile.TemporaryDirectory(prefix="ci-sdk-guard-") as directory:
            root = Path(directory)
            calls = root / "calls"
            (root / "scripts").mkdir()
            shutil.copy2(PROJECT_ROOT / "scripts/check_ci_xcode27.sh",
                         root / "scripts/check_ci_xcode27.sh")
            (root / "bash").symlink_to("/bin/bash")
            commands = {
                "sudo": '[[ "$*" == "xcode-select -s /Applications/Xcode.app" ]] || exit 64\n'
                        'exit "${SELECT_RC:-0}"\n',
                "xcodebuild": '[[ "$*" == "-version" ]] || exit 64\n'
                              'printf "%s\\n" "$XCODE_VERSION"\n'
                              'exit "${XCODE_RC:-0}"\n',
                "xcrun": '[[ "$1" == "--sdk" && "$3" == "--show-sdk-version" ]] || exit 64\n'
                         'case "$2" in\n'
                         '  macosx) printf "%s\\n" "$MACOS_VERSION"; exit "${MACOS_RC:-0}" ;;\n'
                         '  iphonesimulator) printf "%s\\n" "$SIM_VERSION"; exit "${SIM_RC:-0}" ;;\n'
                         '  *) exit 64 ;;\n'
                         'esac\n',
            }
            for name, command in commands.items():
                path = root / name
                path.write_text('#!/bin/bash\nset -u\n'
                                'printf "%s %s\\n" "${0##*/}" "$*" >> "$CALLS"\n'
                                + command, encoding="utf-8")
                path.chmod(0o700)
            env = {
                "PATH": str(root), "CALLS": str(calls),
                "XCODE_VERSION": "Xcode 27.0\nBuild version 18A123",
                "MACOS_VERSION": "27.0", "SIM_VERSION": "27.1",
            }
            env.update(overrides or {})
            result = subprocess.run(
                ["/bin/bash", "-e", "-c", body + '\nprintf "product\\n" >> "$CALLS"\n'],
                cwd=root, env=env, capture_output=True, text=True, timeout=10,
            )
            return result, calls.read_text().splitlines() if calls.exists() else []

    def test_actual_apple_selection_steps_accept_matching_toolchains(self) -> None:
        jobs = _parse_yaml(_read(ORDINARY_WORKFLOW))["jobs"]
        for name in ("bas-tests", "qinao-tests", "samplehost-tests", "boundary-checks"):
            with self.subTest(job=name):
                body = _named_step(jobs[name], "Select Xcode").get("run", "")
                result, calls = self._run_selection_fixture(body)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                expected = ["sudo xcode-select -s /Applications/Xcode.app", "xcodebuild -version",
                            "xcrun --sdk macosx --show-sdk-version"]
                if name == "samplehost-tests":
                    expected.append("xcrun --sdk iphonesimulator --show-sdk-version")
                self.assertEqual(calls, expected + ["product"])

    def test_actual_apple_selection_steps_reject_failures_before_product(self) -> None:
        jobs = _parse_yaml(_read(ORDINARY_WORKFLOW))["jobs"]
        cases = (
            {"SELECT_RC": "23"},
            {"XCODE_RC": "24"},
            {"XCODE_VERSION": "Xcode 26.6\nBuild version 17G10"},
            {"XCODE_VERSION": "Xcode 270.0\nBuild version 18A123"},
            {"XCODE_VERSION": "unknown"},
            {"MACOS_RC": "25"},
            {"MACOS_VERSION": ""},
            {"MACOS_VERSION": "27.garbage"},
            {"MACOS_VERSION": "26.6"},
        )
        for name in ("bas-tests", "qinao-tests", "samplehost-tests", "boundary-checks"):
            body = _named_step(jobs[name], "Select Xcode").get("run", "")
            for override in cases:
                with self.subTest(job=name, failure=override):
                    result, calls = self._run_selection_fixture(body, override)
                    self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
                    self.assertNotIn("product", calls)
                    self.assertNotIn("xcrun --sdk iphonesimulator --show-sdk-version", calls)
            if name == "samplehost-tests":
                for override in ({"SIM_RC": "26"}, {"SIM_VERSION": ""},
                                 {"SIM_VERSION": "26.6"}, {"SIM_VERSION": "27.garbage"}):
                    with self.subTest(job=name, failure=override):
                        result, calls = self._run_selection_fixture(body, override)
                        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
                        self.assertNotIn("product", calls)
                        self.assertIn("xcrun --sdk iphonesimulator --show-sdk-version", calls)

    def test_actual_helper_step_requires_rg_before_running_python(self) -> None:
        jobs = _parse_yaml(_read(ORDINARY_WORKFLOW))["jobs"]
        body = _named_step(jobs["boundary-checks"], "CI contract and iOS floor helper tests")["run"]
        for present in (False, True):
            with self.subTest(rg_available=present), tempfile.TemporaryDirectory(prefix="ci-helper-") as directory:
                root = Path(directory)
                calls = root / "calls"
                python = root / "python3"
                python.write_text('#!/bin/bash\nprintf "%s\\n" "$*" > "$CALLS"\n', encoding="utf-8")
                python.chmod(0o700)
                if present:
                    rg = root / "rg"
                    rg.write_text("#!/bin/bash\nexit 0\n", encoding="utf-8")
                    rg.chmod(0o700)
                result = subprocess.run(["/bin/bash", "-e", "-c", body], cwd=root,
                                        env={"PATH": str(root), "CALLS": str(calls)},
                                        text=True, capture_output=True, timeout=10)
                if present:
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertEqual(calls.read_text().split(), ["-B", "-m", "unittest", "-v",
                        "scripts.test_test_workflow_owner_ledger",
                        "BehavioralAISubstrate.scripts.test_check_ios27_floor",
                        "scripts.test_boundary_tool_errors",
                        "scripts.test_ci_metal_toolchain"])
                else:
                    self.assertNotEqual(result.returncode, 0)
                    self.assertFalse(calls.exists())

    def test_xcode_guard_requires_nonempty_sdk_arguments(self) -> None:
        result, calls = self._run_selection_fixture("bash scripts/check_ci_xcode27.sh")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("At least one SDK name is required", result.stderr)
        self.assertEqual(calls, [])

    def test_each_product_command_cannot_be_removed_skipped_or_masked(self) -> None:
        document = _parse_yaml(_read(ORDINARY_WORKFLOW))
        self.assertNoContractErrors(validate_ordinary_workflow(json.dumps(document)))
        for name, job in document["jobs"].items():
            for index, step in enumerate(job["steps"]):
                if "run" not in step:
                    continue
                for mode in ("removed", "skip", "masked", "wrong-command", "wrong-directory"):
                    mutated = json.loads(json.dumps(document))
                    steps = mutated["jobs"][name]["steps"]
                    if mode == "removed":
                        del steps[index]
                    elif mode == "skip":
                        steps[index]["if"] = "${{ false }}"
                    elif mode == "masked":
                        steps[index]["run"] += "\nexit 0\n"
                    elif mode == "wrong-command":
                        steps[index]["run"] = "true"
                    else:
                        steps[index]["working-directory"] = "/tmp"
                    with self.subTest(job=name, step=step["name"], mode=mode):
                        self.assertTrue(validate_ordinary_workflow(json.dumps(mutated)))

    def test_job_and_checkout_context_mutations_fail_closed(self) -> None:
        document = _parse_yaml(_read(ORDINARY_WORKFLOW))
        for name in document["jobs"]:
            for field, value in (
                ("if", "${{ false }}"), ("needs", "removed-admission"),
                ("runs-on", ["self-hosted"]), ("env", {"BASH_ENV": "/tmp/skip"}),
                ("defaults", {"run": {"shell": "bash {0} || true"}}),
                ("timeout-minutes", True),
            ):
                mutated = json.loads(json.dumps(document))
                mutated["jobs"][name][field] = value
                with self.subTest(job=name, field=field):
                    self.assertTrue(validate_ordinary_workflow(json.dumps(mutated)))
            for field in ("persist-credentials", "submodules", "lfs", "set-safe-directory"):
                mutated = json.loads(json.dumps(document))
                mutated["jobs"][name]["steps"][0]["with"][field] = True
                with self.subTest(job=name, checkout=field):
                    self.assertTrue(validate_ordinary_workflow(json.dumps(mutated)))
        mutated = json.loads(json.dumps(document))
        mutated["jobs"]["extra"] = {"runs-on": "macos-latest", "steps": [{"run": "true"}]}
        self.assertTrue(validate_ordinary_workflow(json.dumps(mutated)))

    def test_comment_spoofs_do_not_replace_structural_actions(self) -> None:
        ordinary = _read(ORDINARY_WORKFLOW)
        real = f"      - uses: actions/checkout@{PINNED_CHECKOUT}\n"
        spoof = f"      # uses: actions/checkout@{PINNED_CHECKOUT}\n"
        self.assertTrue(validate_ordinary_workflow(_replace_first(ordinary, real, spoof)))

    def test_yaml_bool_integer_type_collisions_fail_closed(self) -> None:
        ordinary = _read(ORDINARY_WORKFLOW)
        for before, after in (
            ("fetch-depth: 0", "fetch-depth: false"),
            ("persist-credentials: false", "persist-credentials: 0"),
        ):
            with self.subTest(replacement=after):
                self.assertIn(
                    "checkout exact reviewed step shape and inputs",
                    validate_ordinary_workflow(_replace_first(ordinary, before, after)),
                )

    def test_ordinary_structural_mutations_fail_closed(self) -> None:
        workflow = _read(ORDINARY_WORKFLOW)
        self.assertNoContractErrors(validate_ordinary_workflow(workflow))
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
        }
        for label, mutated in mutations.items():
            with self.subTest(label=label):
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
                        "ordinary exact top-level field set",
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
            2,
            "ordinary CI must contain exactly one Python 3.14.5 setups",
        )
        self.assertNoContractErrors(validate_ordinary_workflow(workflow))

        for occurrence in range(1):
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
        for path in (ORDINARY_WORKFLOW,):
            document = _parse_yaml(_read(path))
            for job_name, step in _run_steps(document):
                bodies.append((path.name, job_name, str(step.get("run"))))
        self.assertEqual(len(bodies), 21)
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
