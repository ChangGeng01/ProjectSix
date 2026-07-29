#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
DEFAULT_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd -P)"
ROOT="${1:-$DEFAULT_ROOT}"
SWIFT_BIN="${QINAO_SWIFT:-swift}"
XCODEBUILD_BIN="${QINAO_XCODEBUILD:-xcodebuild}"
PROJECT="$ROOT/BehavioralAISubstrate/DeviceTestApp/BASDeviceTest.xcodeproj"
SCHEME="BASDeviceTestApp"
DERIVED_DATA="${QINAO_IOS27_DERIVED_DATA_PATH:-${TMPDIR:-/tmp}/qinao-ios27-floor-derived-data}"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/qinao-ios27-floor.XXXXXX")"
trap 'rm -rf "$WORK_DIR"' EXIT

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

require_file() {
  local file="$1"
  local label="$2"
  [[ -f "$file" && -s "$file" ]] || fail "$label is missing or empty: $file"
}

require_only_declaration() {
  local file="$1"
  local key_pattern="$2"
  local expected_pattern="$3"
  local label="$4"
  local declarations
  local scanner_status

  require_file "$file" "$label"
  set +e
  declarations="$(rg -- "$key_pattern" "$file" 2>"$WORK_DIR/rg-error")"
  scanner_status=$?
  set -e
  case "$scanner_status" in
    0) ;;
    1) fail "$label has no deployment declaration" ;;
    *)
      fail "$label scanner failed with exit $scanner_status: $(<"$WORK_DIR/rg-error")"
      ;;
  esac
  if printf '%s\n' "$declarations" | rg -q -v -- "$expected_pattern"; then
    fail "$label must declare only iOS 27.0"
  fi
}

verify_swift_manifest() {
  local manifest="$1"
  local package_path="${manifest%/Package.swift}"
  local manifest_json
  local swift_status

  require_file "$ROOT/$manifest" "$manifest"
  set +e
  manifest_json="$(
    "$SWIFT_BIN" package \
      --disable-sandbox \
      --package-path "$ROOT/$package_path" \
      dump-package 2>"$WORK_DIR/swift-error"
  )"
  swift_status=$?
  set -e
  if [[ "$swift_status" -ne 0 ]]; then
    fail "$manifest could not be resolved (swift exit $swift_status): $(<"$WORK_DIR/swift-error")"
  fi

  if ! MANIFEST="$manifest" python3 -c '
import json
import os
import sys

document = json.load(sys.stdin)
manifest = os.environ["MANIFEST"]
versions = [
    platform.get("version")
    for platform in document.get("platforms", [])
    if platform.get("platformName") == "ios"
]
if versions != ["27.0"]:
    print(
        f"FAIL: {manifest} resolved iOS floors "
        f"{versions!r}, expected ['27.0']",
        file=sys.stderr,
    )
    raise SystemExit(1)
' <<<"$manifest_json"
  then
    exit 1
  fi
}

for manifest in \
  BehavioralAISubstrate/Package.swift \
  QinaoRuntimeSDK/Package.swift \
  SampleHost/Package.swift
do
  verify_swift_manifest "$manifest"
done

XCODEGEN_SPEC="$ROOT/BehavioralAISubstrate/DeviceTestApp/project.yml"
GENERATED_PROJECT="$ROOT/BehavioralAISubstrate/DeviceTestApp/BASDeviceTest.xcodeproj/project.pbxproj"

require_only_declaration \
  "$XCODEGEN_SPEC" \
  '^[[:space:]]+iOS:' \
  '^[[:space:]]+iOS: "27\.0"[[:space:]]*$' \
  'project.yml XcodeGen deploymentTarget'
require_only_declaration \
  "$XCODEGEN_SPEC" \
  '^[[:space:]]+IPHONEOS_DEPLOYMENT_TARGET:' \
  '^[[:space:]]+IPHONEOS_DEPLOYMENT_TARGET: "27\.0"[[:space:]]*$' \
  'project.yml XcodeGen IPHONEOS_DEPLOYMENT_TARGET'
require_only_declaration \
  "$GENERATED_PROJECT" \
  '^[[:space:]]*IPHONEOS_DEPLOYMENT_TARGET[[:space:]]*=' \
  '^[[:space:]]*IPHONEOS_DEPLOYMENT_TARGET = 27\.0;[[:space:]]*$' \
  'generated project'

if ! python3 - "$XCODEGEN_SPEC" "$GENERATED_PROJECT" <<'PY'
from __future__ import annotations

import fnmatch
import re
import sys
from collections import Counter
from pathlib import Path

spec_path = Path(sys.argv[1])
project_path = Path(sys.argv[2])
spec = spec_path.read_text(encoding="utf-8")
project = project_path.read_text(encoding="utf-8")
target = re.search(
    r"(?ms)^  BASDeviceTests:\s*$"
    r"(?P<body>(?:\n(?: {4,}.*|\s*))*)",
    spec,
)
errors: list[str] = []
if target is None:
    errors.append("project.yml has no BASDeviceTests target")
required_products = (
    ("BehavioralAISubstrate", "BASAppleEdgeWiring"),
)
if re.search(
    r"(?m)^  SwiftSyntax:\s*$"
    r"\n^    path: \.\./Vendor/swift-syntax\s*$",
    spec,
) is not None:
    errors.append(
        "project.yml must not add the stripped vendored swift-syntax tree as "
        "a direct SwiftSyntax package root"
    )
if target is not None and re.search(
    r"(?m)^        product: (?:SwiftParser|SwiftSyntax)\s*$",
    target.group("body"),
) is not None:
    errors.append(
        "project.yml BASDeviceTests must not declare SwiftParser or "
        "SwiftSyntax package products"
    )
if re.search(
    r"(?m)^\s*productName = (?:SwiftParser|SwiftSyntax);\s*$",
    project,
) is not None:
    errors.append(
        "generated project must not contain SwiftParser or SwiftSyntax "
        "package-product dependencies"
    )
for package, product in required_products:
    if target is not None and re.search(
        rf"(?m)^      - package: {re.escape(package)}\s*$"
        rf"\n^        product: {re.escape(product)}\s*$",
        target.group("body"),
    ) is None:
        errors.append(
            "project.yml BASDeviceTests must declare directly imported "
            f"public product {product}"
        )
    if re.search(
        rf"(?m)^\s*productName = {re.escape(product)};\s*$",
        project,
    ) is None:
        errors.append(
            "generated project must contain the BASDeviceTests "
            f"{product} package-product dependency"
        )


def unquote(value: str) -> str:
    value = value.strip()
    if len(value) >= 2 and value[0] == value[-1] == '"':
        return value[1:-1]
    return value


if target is not None:
    source_entries: list[tuple[str, list[str]]] = []
    in_sources = False
    current_excludes: list[str] | None = None
    in_excludes = False
    for line in target.group("body").splitlines():
        if re.fullmatch(r"    sources:\s*", line):
            in_sources = True
            current_excludes = None
            in_excludes = False
            continue
        if re.match(r"^    \S", line):
            in_sources = False
            current_excludes = None
            in_excludes = False
        if not in_sources:
            continue
        path_match = re.fullmatch(r"      - path:\s*(.+?)\s*", line)
        if path_match:
            current_excludes = []
            source_entries.append(
                (unquote(path_match.group(1)), current_excludes)
            )
            in_excludes = False
            continue
        if re.fullmatch(r"        excludes:\s*", line):
            in_excludes = current_excludes is not None
            continue
        exclude_match = re.fullmatch(r"          -\s*(.+?)\s*", line)
        if in_excludes and current_excludes is not None and exclude_match:
            current_excludes.append(unquote(exclude_match.group(1)))

    expected_names: list[str] = []
    excluded_names: set[str] = set()
    for source_value, excludes in source_entries:
        source_path = (spec_path.parent / source_value).resolve()
        if not source_path.exists():
            errors.append(
                f"project.yml BASDeviceTests source path is missing: "
                f"{source_value}"
            )
            continue
        candidates = (
            [source_path]
            if source_path.is_file()
            else sorted(source_path.rglob("*.swift"))
        )
        for candidate in candidates:
            relative = (
                candidate.name
                if source_path.is_file()
                else candidate.relative_to(source_path).as_posix()
            )
            is_excluded = any(
                fnmatch.fnmatch(relative, pattern)
                or fnmatch.fnmatch(candidate.name, pattern)
                for pattern in excludes
            )
            if is_excluded:
                excluded_names.add(candidate.name)
            else:
                expected_names.append(candidate.name)

    duplicate_expected = sorted(
        name for name, count in Counter(expected_names).items() if count > 1
    )
    if duplicate_expected:
        errors.append(
            "project.yml BASDeviceTests source basenames are ambiguous: "
            + ", ".join(duplicate_expected)
        )
    reference_paths = re.findall(
        r"isa = PBXFileReference;[^}]*?\bpath = "
        r"(\"(?:\\.|[^\"])*\"|[^;]+);",
        project,
    )
    referenced_names = {
        Path(unquote(path_value)).name for path_value in reference_paths
    }
    for name in sorted(set(expected_names) - referenced_names):
        errors.append(
            f"generated project omits spec-included BASDeviceTests source: "
            f"{name}"
        )
    for name in sorted(excluded_names & referenced_names):
        errors.append(
            f"generated project contains spec-excluded BASDeviceTests source: "
            f"{name}"
        )

tests_root = (
    spec_path.parent.parent
    / "Tests"
    / "BehavioralAISubstrateTests"
)
audit_path = tests_root / "BASEventLogHeadSyntaxAudit.swift"
event_log_path = tests_root / "BASEventLogTests.swift"
try:
    audit_source = audit_path.read_text(encoding="utf-8")
except OSError as error:
    errors.append(f"BASEventLogHeadSyntaxAudit.swift is unreadable: {error}")
    audit_source = ""
try:
    event_log_source = event_log_path.read_text(encoding="utf-8")
except OSError as error:
    errors.append(f"BASEventLogTests.swift is unreadable: {error}")
    event_log_source = ""

audit_lines = audit_source.splitlines()
audit_nonempty = [
    index for index, line in enumerate(audit_lines) if line.strip()
]
audit_guarded = bool(audit_nonempty)
if audit_guarded:
    first = audit_nonempty[0]
    last = audit_nonempty[-1]
    audit_guarded = (
        audit_lines[first].strip() == "#if os(macOS)"
        and audit_lines[last].strip() == "#endif"
    )
    depth = 0
    for index in range(first, last + 1):
        directive = audit_lines[index].strip()
        if directive.startswith("#if "):
            depth += 1
        elif directive == "#endif":
            depth -= 1
            if depth == 0 and index != last:
                audit_guarded = False
            if depth < 0:
                audit_guarded = False
        elif depth == 1 and (
            directive == "#else" or directive.startswith("#elseif ")
        ):
            audit_guarded = False
    audit_guarded = audit_guarded and depth == 0
if not audit_guarded:
    errors.append(
        "BASEventLogHeadSyntaxAudit.swift must be entirely guarded "
        "by #if os(macOS)"
    )


def swift_code_only(source: str) -> str:
    output: list[str] = []
    index = 0
    block_comment_depth = 0
    string_closer: str | None = None
    string_hashes = 0
    while index < len(source):
        if block_comment_depth:
            if source.startswith("/*", index):
                block_comment_depth += 1
                output.extend((" ", " "))
                index += 2
            elif source.startswith("*/", index):
                block_comment_depth -= 1
                output.extend((" ", " "))
                index += 2
            else:
                output.append("\n" if source[index] == "\n" else " ")
                index += 1
            continue
        if string_closer is not None:
            escaped = False
            if string_hashes == 0 and source.startswith(
                string_closer,
                index,
            ):
                backslashes = 0
                cursor = index - 1
                while cursor >= 0 and source[cursor] == "\\":
                    backslashes += 1
                    cursor -= 1
                escaped = backslashes % 2 == 1
            if (
                source.startswith(string_closer, index)
                and not escaped
            ):
                output.extend(" " for _ in string_closer)
                index += len(string_closer)
                string_closer = None
                string_hashes = 0
            else:
                output.append("\n" if source[index] == "\n" else " ")
                index += 1
            continue
        if source.startswith("//", index):
            end = source.find("\n", index)
            if end == -1:
                output.extend(" " for _ in source[index:])
                break
            output.extend(" " for _ in source[index:end])
            output.append("\n")
            index = end + 1
            continue
        if source.startswith("/*", index):
            block_comment_depth = 1
            output.extend((" ", " "))
            index += 2
            continue

        hash_count = 0
        while (
            index + hash_count < len(source)
            and source[index + hash_count] == "#"
        ):
            hash_count += 1
        quote_index = index + hash_count
        if quote_index < len(source) and source[quote_index] == '"':
            quote_count = (
                3 if source.startswith('"""', quote_index) else 1
            )
            opener_length = hash_count + quote_count
            output.extend(" " for _ in range(opener_length))
            string_closer = '"' * quote_count + "#" * hash_count
            string_hashes = hash_count
            index += opener_length
            continue
        output.append(source[index])
        index += 1
    return "".join(output)


device_sources_root = spec_path.parent / "Sources"
expected_coreai_import_files = {
    "App/BASCoreAIDecodeProbe.swift",
    "App/BASCoreAIDuetProbe.swift",
    "App/BASCoreAIMamba3DualProbe.swift",
    "App/BASCoreAIMamba3Probe.swift",
    "App/BASCoreAIMambaSaguaroProbe.swift",
    "App/BASCoreAIPrefillProbe.swift",
    "App/BASCoreAIStateLakeProbe.swift",
    "App/BASQwen35RdarProbe.swift",
    "Experiments/BASCoreAIGpuProbe.swift",
    "Experiments/BASRhoProbe.swift",
}
coreai_gated_tokens = (
    "AIModel",
    "InferenceFunction",
    "NDArray",
    "SpecializationOptions",
    "ComputeUnitKind",
    "BASCoreAIDecodeSession",
    "BASCoreAIHybridDecodeSession",
    "BASCoreAILayerSplitSession",
    "BASCoreAIMamba3DualSession",
    "BASCoreAIMamba3Session",
    "BASCoreAIMambaSession",
    "BASCoreAIPrefillSession",
    "BASSaguaroSpeculator",
    "BASStateLakeReader",
    "BASCoreAINLIVerifier",
)
coreai_token = re.compile(
    r"\b(?:" + "|".join(map(re.escape, coreai_gated_tokens)) + r")\b"
)
coreai_import = re.compile(r"^\s*import\s+CoreAI\s*$")
device_sources = (
    sorted(device_sources_root.rglob("*.swift"))
    if device_sources_root.is_dir()
    else []
)
coreai_import_files: set[str] = set()


def positive_coreai_condition(expression: str) -> bool:
    normalized = re.sub(r"\s+", "", expression)
    return (
        "canImport(CoreAI)" in normalized
        and "!canImport(CoreAI)" not in normalized
        and "||" not in normalized
    )


for source_path in device_sources:
    try:
        source = source_path.read_text(encoding="utf-8")
    except OSError as error:
        errors.append(f"DeviceTestApp source is unreadable: {error}")
        continue
    relative = source_path.relative_to(device_sources_root).as_posix()
    code_lines = swift_code_only(source).splitlines()
    if any(coreai_import.fullmatch(line) for line in code_lines):
        coreai_import_files.add(relative)

    conditions: list[bool] = []
    for line_number, line in enumerate(code_lines, start=1):
        directive = line.strip()
        if directive.startswith("#if "):
            conditions.append(
                positive_coreai_condition(directive.removeprefix("#if "))
            )
            continue
        if directive.startswith("#elseif "):
            if conditions:
                conditions[-1] = positive_coreai_condition(
                    directive.removeprefix("#elseif ")
                )
            continue
        if directive == "#else":
            if conditions:
                conditions[-1] = False
            continue
        if directive == "#endif":
            if conditions:
                conditions.pop()
            continue

        matches = sorted(set(coreai_token.findall(line)))
        if coreai_import.fullmatch(line):
            matches.append("CoreAI")
        if matches and not any(conditions):
            errors.append(
                "CoreAI-gated token escapes #if canImport(CoreAI): "
                f"{relative}:{line_number}: {', '.join(matches)}"
            )

missing_coreai_imports = sorted(
    expected_coreai_import_files - coreai_import_files
)
unexpected_coreai_imports = sorted(
    coreai_import_files - expected_coreai_import_files
)
if missing_coreai_imports:
    errors.append(
        "DeviceTestApp CoreAI import matrix is missing: "
        + ", ".join(missing_coreai_imports)
    )
if unexpected_coreai_imports:
    errors.append(
        "DeviceTestApp CoreAI import matrix has unexpected files: "
        + ", ".join(unexpected_coreai_imports)
    )


def guarded_functions(source: str) -> list[tuple[str, bool]]:
    conditions: list[str] = []
    found: list[tuple[str, bool]] = []
    function = re.compile(
        r"^\s*(?:(?:private|fileprivate|internal|public|package|open|"
        r"final|static|class|override|nonisolated)\s+)*"
        r"func\s+([A-Za-z_][A-Za-z0-9_]*)"
    )
    for line in swift_code_only(source).splitlines():
        directive = line.strip()
        if directive.startswith("#if "):
            conditions.append(
                re.sub(r"\s+", "", directive.removeprefix("#if "))
            )
            continue
        if directive.startswith("#elseif "):
            if conditions:
                conditions[-1] = re.sub(
                    r"\s+",
                    "",
                    directive.removeprefix("#elseif "),
                )
            continue
        if directive == "#else":
            if conditions:
                conditions[-1] = f"!({conditions[-1]})"
            continue
        if directive == "#endif":
            if conditions:
                conditions.pop()
            continue
        match = function.match(line)
        if match:
            found.append(
                (match.group(1), "os(macOS)" in conditions)
            )
    return found


functions = guarded_functions(event_log_source)
macos_functions = {
    name for name, is_macos in functions if is_macos
}
host_helpers = {
    "removingSwiftLineComments",
    "regexCaptures",
    "regexMatchCount",
    "eventLogHeadDeclarationKinds",
    "eventLogHeadExtensionCount",
    "normalizedWhitespace",
}
host_tests = {
    "testEventLogHeadHasOneSourceOwnerAndNoGovernanceEntry",
    "testEventLogHeadOwnerGateRecognizesEveryDeclarationKind",
    "testEventLogHeadDeclarationSurfaceIsExactAndValueOnly",
}
function_names = [name for name, _ in functions]
for helper in sorted(host_helpers):
    if helper not in function_names:
        errors.append(f"host helper {helper} is missing")
    elif helper not in macos_functions:
        errors.append(
            f"host helper {helper} must be guarded by #if os(macOS)"
        )
for test in sorted(host_tests):
    if test not in function_names:
        errors.append(f"host gate {test} is missing")
    elif test not in macos_functions:
        errors.append(
            f"host gate {test} must be guarded by #if os(macOS)"
        )
unexpected_macos = sorted(
    macos_functions - host_helpers - host_tests
)
if unexpected_macos:
    errors.append(
        "BASEventLogTests.swift must keep non-host functions on iOS; "
        "unexpected macOS-only functions: "
        + ", ".join(unexpected_macos)
    )
all_tests = [name for name in function_names if name.startswith("test")]
ios_tests = [
    name
    for name, is_macos in functions
    if name.startswith("test") and not is_macos
]
if len(all_tests) != 34:
    errors.append(
        "BASEventLogTests.swift must contain exactly 34 tests; "
        f"found {len(all_tests)}"
    )
if len(ios_tests) != 31:
    errors.append(
        "expected 31 iOS BASEventLogTests after the three host gates; "
        f"found {len(ios_tests)}"
    )
if errors:
    for error in errors:
        print(f"FAIL: {error}", file=sys.stderr)
    raise SystemExit(1)
PY
then
  exit 1
fi

require_file \
  "$ROOT/BehavioralAISubstrate/scripts/build-rust-xcframework.sh" \
  "Rust XCFramework build script"
if ! python3 - "$ROOT" <<'PY'
from __future__ import annotations

import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
script_roots = (root / "BehavioralAISubstrate/scripts", root / "scripts")
scripts: set[Path] = set()
for script_root in script_roots:
    if not script_root.is_dir():
        continue
    for pattern in ("*build*.sh", "*export*.sh", "*archive*.sh"):
        scripts.update(script_root.glob(pattern))

rust_script = root / "BehavioralAISubstrate/scripts/build-rust-xcframework.sh"
scripts.add(rust_script)
assignment = re.compile(
    r"(?:^|[;&]\s*|env\s+|export\s+)"
    r"(IPHONEOS_DEPLOYMENT_TARGET|IPHONESIMULATOR_DEPLOYMENT_TARGET)"
    r"\s*=\s*[\"']?([0-9]+(?:\.[0-9]+)*)"
)
seen_rust: dict[str, list[str]] = {
    "IPHONEOS_DEPLOYMENT_TARGET": [],
    "IPHONESIMULATOR_DEPLOYMENT_TARGET": [],
}
errors: list[str] = []
rust_executable_lines: list[str] = []
for script in sorted(scripts):
    if not script.is_file() or script.stat().st_size == 0:
        errors.append(f"build/export script is missing or empty: {script}")
        continue
    for line_number, line in enumerate(
        script.read_text(encoding="utf-8").splitlines(),
        start=1,
    ):
        if line.lstrip().startswith("#"):
            continue
        if script == rust_script:
            rust_executable_lines.append(line)
        for name, version in assignment.findall(line):
            if script == rust_script:
                seen_rust[name].append(version)
            try:
                numeric = tuple(int(part) for part in version.split("."))
            except ValueError:
                numeric = ()
            if numeric < (27, 0):
                errors.append(
                    f"{script.relative_to(root)}:{line_number}: "
                    f"{name}={version} is below iOS 27.0"
                )
for name, versions in seen_rust.items():
    if versions != ["27.0"]:
        errors.append(
            "BehavioralAISubstrate/scripts/build-rust-xcframework.sh "
            f"must declare exactly one {name}=27.0; found {versions!r}"
        )
rust_executable = "\n".join(rust_executable_lines)
if 'export RUSTUP_TOOLCHAIN="1.96.0-aarch64-apple-darwin"' not in rust_executable:
    errors.append(
        "BehavioralAISubstrate/scripts/build-rust-xcframework.sh "
        "must select pinned Rust toolchain "
        "1.96.0-aarch64-apple-darwin independently of caller cwd"
    )
if "lib/rustlib/src/rust/library/Cargo.toml" not in rust_executable:
    errors.append(
        "BehavioralAISubstrate/scripts/build-rust-xcframework.sh "
        "must fail closed on a missing pinned rust-src manifest"
    )
if (
    "RUSTC_BOOTSTRAP=1 cargo build" not in rust_executable
    or "-Z build-std=std,panic_abort" not in rust_executable
):
    errors.append(
        "BehavioralAISubstrate/scripts/build-rust-xcframework.sh "
        "must compile both iOS standard libraries with "
        "RUSTC_BOOTSTRAP=1 and -Z build-std=std,panic_abort"
    )
if errors:
    for error in errors:
        print(f"FAIL: {error}", file=sys.stderr)
    raise SystemExit(1)
PY
then
  exit 1
fi

rg -q '^[[:space:]]+com\.apple\.developer\.kernel\.increased-memory-limit: true$' "$XCODEGEN_SPEC" || {
  fail 'XcodeGen spec would erase the increased-memory-limit entitlement'
}
rg -q '^[[:space:]]+BGTaskSchedulerPermittedIdentifiers:$' "$XCODEGEN_SPEC" || {
  fail 'XcodeGen spec would erase the background-task identifier'
}
rg -q '<key>com\.apple\.developer\.kernel\.increased-memory-limit</key>' \
  "$ROOT/BehavioralAISubstrate/DeviceTestApp/Resources/BASDeviceTestApp.entitlements" || {
  fail 'generated entitlements lost increased-memory-limit'
}
rg -q '<key>BGTaskSchedulerPermittedIdentifiers</key>' \
  "$ROOT/BehavioralAISubstrate/DeviceTestApp/Resources/Info.plist" || {
  fail 'generated Info.plist lost the background-task identifier'
}

require_file "$PROJECT/project.pbxproj" "BASDeviceTest Xcode project"
mkdir -p "$DERIVED_DATA"

simulator_json="$WORK_DIR/available-simulators.json"
set +e
xcrun simctl list devices available -j \
  >"$simulator_json" 2>"$WORK_DIR/available-simulators.error"
simulator_status=$?
set -e
if [[ "$simulator_status" -ne 0 ]]; then
  fail "simctl could not list an iOS 27 simulator with exit $simulator_status: $(<"$WORK_DIR/available-simulators.error")"
fi

set +e
enumeration_destination="$(
  OVERRIDE="${QINAO_IOS27_ENUMERATION_DESTINATION:-}" \
    python3 - "$simulator_json" 2>"$WORK_DIR/simulator-selector.error" <<'PY'
from __future__ import annotations

import json
import os
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
try:
    document = json.loads(path.read_text(encoding="utf-8"))
except (OSError, json.JSONDecodeError) as error:
    print(f"simulator inventory is invalid: {error}", file=sys.stderr)
    raise SystemExit(1)
uuid = re.compile(
    r"[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-"
    r"[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}"
)
candidates: list[tuple[int, str, str]] = []
devices_by_runtime = document.get("devices")
if isinstance(devices_by_runtime, dict):
    for runtime, devices in devices_by_runtime.items():
        match = re.search(r"\.iOS-(\d+)(?:-(\d+))?", runtime)
        if match is None or int(match.group(1)) < 27:
            continue
        if not isinstance(devices, list):
            continue
        for device in devices:
            if not isinstance(device, dict):
                continue
            identifier = device.get("udid")
            if (
                device.get("isAvailable") is not True
                or not isinstance(identifier, str)
                or uuid.fullmatch(identifier) is None
            ):
                continue
            state_rank = 0 if device.get("state") == "Booted" else 1
            name = device.get("name")
            candidates.append(
                (
                    state_rank,
                    name if isinstance(name, str) else "",
                    identifier.upper(),
                )
            )
candidates.sort()
override = os.environ["OVERRIDE"]
if override:
    match = re.fullmatch(
        r"platform=iOS Simulator,id=(" + uuid.pattern + r")",
        override,
    )
    if match is None:
        print(
            "QINAO_IOS27_ENUMERATION_DESTINATION must use "
            "platform=iOS Simulator,id=<UDID>",
            file=sys.stderr,
        )
        raise SystemExit(1)
    selected = match.group(1).upper()
    if selected not in {candidate[2] for candidate in candidates}:
        print(
            "QINAO_IOS27_ENUMERATION_DESTINATION override is not an "
            "available iOS 27+ simulator",
            file=sys.stderr,
        )
        raise SystemExit(1)
elif candidates:
    selected = candidates[0][2]
else:
    print("no available iOS 27+ simulator", file=sys.stderr)
    raise SystemExit(1)
print(f"platform=iOS Simulator,id={selected}")
PY
)"
destination_status=$?
set -e
if [[ "$destination_status" -ne 0 || -z "$enumeration_destination" ]]; then
  fail "$(<"$WORK_DIR/simulator-selector.error")"
fi
enumeration_udid="${enumeration_destination##*id=}"

destinations_log="$WORK_DIR/xcodebuild-destinations.log"
set +e
"$XCODEBUILD_BIN" \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -showdestinations >"$destinations_log" 2>&1
destinations_status=$?
set -e
if [[ "$destinations_status" -ne 0 ]]; then
  fail "xcodebuild -showdestinations failed with exit $destinations_status: $(tail -20 "$destinations_log")"
fi
if ! SIMULATOR_UDID="$enumeration_udid" \
  python3 - "$destinations_log" <<'PY'
from __future__ import annotations

import os
import re
import sys
from pathlib import Path

identifier = os.environ["SIMULATOR_UDID"]
lines = Path(sys.argv[1]).read_text(
    encoding="utf-8",
    errors="replace",
).splitlines()
valid = False
for line in lines:
    compact = re.sub(r"\s+", "", line)
    if f"id:{identifier}" not in compact:
        continue
    platform = "platform:iOSSimulator" in compact
    architecture = "arch:arm64" in compact
    match = re.search(r"(?:^|,)OS:([0-9]+(?:\.[0-9]+)*)", compact)
    version = (
        tuple(int(part) for part in match.group(1).split("."))
        if match is not None
        else ()
    )
    if platform and architecture and version >= (27, 0):
        valid = True
        break
if not valid:
    print(
        f"FAIL: selected simulator {identifier} is not an arm64 iOS 27+ "
        "simulator destination in xcodebuild -showdestinations",
        file=sys.stderr,
    )
    raise SystemExit(1)
PY
then
  exit 1
fi

for sdk in iphoneos iphonesimulator; do
  platform_args=(
    -sdk "$sdk"
    -destination "generic/platform=iOS"
    -destination-timeout 120
  )
  if [[ "$sdk" == "iphonesimulator" ]]; then
    # The concrete destination is authoritative for the simulator SDK and
    # architecture. Passing both it and -sdk makes Xcode 27 build Swift macro
    # executables for the simulator instead of the macOS plugin host.
    platform_args=(
      -destination "$enumeration_destination"
      -destination-timeout 120
    )
  fi
  build_log="$WORK_DIR/xcodebuild-$sdk.log"
  set +e
  "$XCODEBUILD_BIN" \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    "${platform_args[@]}" \
    -configuration Debug \
    -derivedDataPath "$DERIVED_DATA" \
    CODE_SIGNING_ALLOWED=NO \
    build-for-testing >"$build_log" 2>&1
  build_status=$?
  set -e
  if [[ "$build_status" -ne 0 ]]; then
    fail "xcodebuild $sdk build-for-testing failed with exit $build_status: $(tail -20 "$build_log")"
  fi

  if [[ "$sdk" == "iphonesimulator" ]]; then
  enumeration_json="$WORK_DIR/test-enumeration-$sdk.json"
  enumeration_log="$WORK_DIR/test-enumeration-$sdk.log"
  set +e
  "$XCODEBUILD_BIN" \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -destination "$enumeration_destination" \
    -destination-timeout 120 \
    -configuration Debug \
    -derivedDataPath "$DERIVED_DATA" \
    CODE_SIGNING_ALLOWED=NO \
    -only-testing:BASDeviceTests/BASEventLogTests \
    -enumerate-tests \
    -test-enumeration-style hierarchical \
    -test-enumeration-format json \
    -test-enumeration-output-path "$enumeration_json" \
    test-without-building >"$enumeration_log" 2>&1
  enumeration_status=$?
  set -e
  if [[ "$enumeration_status" -ne 0 ]]; then
    fail "xcodebuild $sdk test enumeration failed with exit $enumeration_status: $(tail -20 "$enumeration_log")"
  fi

  if ! SDK="$sdk" python3 - "$enumeration_json" <<'PY'
from __future__ import annotations

import json
import os
import re
import sys
from pathlib import Path

sdk = os.environ["SDK"]
path = Path(sys.argv[1])
try:
    document = json.loads(path.read_text(encoding="utf-8"))
except (OSError, json.JSONDecodeError) as error:
    print(
        f"FAIL: {sdk} test enumeration is invalid: {error}",
        file=sys.stderr,
    )
    raise SystemExit(1)

test_name = re.compile(r"\b(test[A-Za-z_][A-Za-z0-9_]*)\b")
found: set[str] = set()


def walk(value: object, inside_suite: bool = False) -> None:
    if isinstance(value, dict):
        strings = [
            item for item in value.values() if isinstance(item, str)
        ]
        contains_suite = inside_suite or any(
            "BASEventLogTests" in item for item in strings
        )
        if contains_suite:
            for item in strings:
                found.update(test_name.findall(item))
        for item in value.values():
            if isinstance(item, (dict, list)):
                walk(item, contains_suite)
    elif isinstance(value, list):
        for item in value:
            walk(item, inside_suite)


walk(document)
host_only = {
    "testEventLogHeadHasOneSourceOwnerAndNoGovernanceEntry",
    "testEventLogHeadOwnerGateRecognizesEveryDeclarationKind",
    "testEventLogHeadDeclarationSurfaceIsExactAndValueOnly",
}
leaked = sorted(found & host_only)
errors: list[str] = []
reported_errors = (
    document.get("errors")
    if isinstance(document, dict)
    else ["enumeration document is not an object"]
)
if reported_errors:
    errors.append(
        f"{sdk} test enumeration reported errors: {reported_errors!r}"
    )
if len(found) != 31:
    errors.append(
        f"{sdk} discovered {len(found)} BASEventLogTests; expected 31"
    )
if leaked:
    errors.append(
        f"{sdk} discovered host-only BASEventLogTests: "
        + ", ".join(leaked)
    )
representative = "testInMemoryAppendAssignsSequenceNumber"
if representative not in found:
    errors.append(
        f"{sdk} did not discover representative runtime test "
        f"{representative}"
    )
if errors:
    for error in errors:
        print(f"FAIL: {error}", file=sys.stderr)
    raise SystemExit(1)
PY
  then
    exit 1
  fi
  fi

  settings_json="$WORK_DIR/settings-$sdk.json"
  set +e
  "$XCODEBUILD_BIN" \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    "${platform_args[@]}" \
    -configuration Debug \
    -derivedDataPath "$DERIVED_DATA" \
    -showBuildSettings \
    -json >"$settings_json" 2>"$WORK_DIR/settings-$sdk.error"
  settings_status=$?
  set -e
  if [[ "$settings_status" -ne 0 ]]; then
    fail "xcodebuild $sdk -showBuildSettings failed with exit $settings_status: $(<"$WORK_DIR/settings-$sdk.error")"
  fi

  if ! SDK="$sdk" python3 - "$settings_json" <<'PY'
from __future__ import annotations

import json
import os
import plistlib
import sys
from pathlib import Path


def version(value: object) -> tuple[int, ...]:
    if not isinstance(value, str):
        return ()
    try:
        return tuple(int(part) for part in value.split("."))
    except ValueError:
        return ()


sdk = os.environ["SDK"]
settings_path = Path(sys.argv[1])
try:
    document = json.loads(settings_path.read_text(encoding="utf-8"))
except (OSError, json.JSONDecodeError) as error:
    print(f"FAIL: {sdk} resolved build settings are invalid: {error}", file=sys.stderr)
    raise SystemExit(1)
if not isinstance(document, list) or not document:
    print(f"FAIL: {sdk} resolved build settings are empty", file=sys.stderr)
    raise SystemExit(1)
product_count = 0
errors: list[str] = []
for entry in document:
    if not isinstance(entry, dict):
        errors.append(f"{sdk} resolved build settings contain a non-object entry")
        continue
    target = entry.get("target", "<unknown>")
    settings = entry.get("buildSettings")
    if not isinstance(settings, dict):
        errors.append(f"{sdk} target {target} has no resolved buildSettings")
        continue
    floor = settings.get("IPHONEOS_DEPLOYMENT_TARGET")
    if version(floor) < (27, 0):
        errors.append(
            f"{sdk} target {target} resolved "
            f"IPHONEOS_DEPLOYMENT_TARGET={floor!r}, below 27.0"
        )
    directory = settings.get("TARGET_BUILD_DIR")
    wrapper = settings.get("WRAPPER_NAME")
    if not isinstance(wrapper, str) or not wrapper:
        continue
    if not isinstance(directory, str) or not directory:
        errors.append(f"{sdk} target {target} has no TARGET_BUILD_DIR")
        continue
    product = Path(directory) / wrapper
    product_count += 1
    if not product.is_dir():
        errors.append(f"{sdk} built product is missing: {product}")
        continue
    info = product / "Info.plist"
    try:
        with info.open("rb") as handle:
            plist = plistlib.load(handle)
    except (OSError, plistlib.InvalidFileException) as error:
        errors.append(f"{sdk} built product Info.plist is invalid: {info}: {error}")
        continue
    minimum = plist.get("MinimumOSVersion")
    if version(minimum) < (27, 0):
        errors.append(
            f"{sdk} built product {product} MinimumOSVersion={minimum!r}, "
            "below 27.0"
        )
if product_count == 0:
    errors.append(f"{sdk} resolved settings named zero built products")
if errors:
    for error in errors:
        print(f"FAIL: {error}", file=sys.stderr)
    raise SystemExit(1)
PY
  then
    exit 1
  fi
done

XCFRAMEWORK_LIST="$WORK_DIR/xcframework-slices.tsv"
if ! QINAO_IOS27_FRESH_XCFRAMEWORKS="${QINAO_IOS27_FRESH_XCFRAMEWORKS:-}" \
  python3 - "$ROOT" >"$XCFRAMEWORK_LIST" <<'PY'
from __future__ import annotations

import os
import plistlib
import sys
from pathlib import Path

root = Path(sys.argv[1])
frameworks = set(root.glob("BehavioralAISubstrate/Vendor/**/*.xcframework"))
for value in os.environ["QINAO_IOS27_FRESH_XCFRAMEWORKS"].split(":"):
    if value:
        frameworks.add(Path(value))
if not frameworks:
    print("FAIL: no vendored or fresh XCFramework was found", file=sys.stderr)
    raise SystemExit(1)
errors: list[str] = []
rows: list[tuple[str, str, str]] = []
for framework in sorted(frameworks):
    info = framework / "Info.plist"
    try:
        with info.open("rb") as handle:
            document = plistlib.load(handle)
    except (OSError, plistlib.InvalidFileException) as error:
        errors.append(f"XCFramework Info.plist is invalid: {info}: {error}")
        continue
    libraries = document.get("AvailableLibraries")
    if not isinstance(libraries, list):
        errors.append(f"XCFramework has no AvailableLibraries: {framework}")
        continue
    device = 0
    simulator = 0
    for library in libraries:
        if not isinstance(library, dict) or library.get("SupportedPlatform") != "ios":
            continue
        identifier = library.get("LibraryIdentifier")
        library_path = library.get("LibraryPath") or library.get("BinaryPath")
        architectures = library.get("SupportedArchitectures")
        if not isinstance(identifier, str) or not isinstance(library_path, str):
            errors.append(f"XCFramework iOS library row is malformed: {framework}")
            continue
        variant = library.get("SupportedPlatformVariant")
        if variant is None:
            expected_platform = "2"
            device += 1
        elif variant == "simulator":
            expected_platform = "7"
            simulator += 1
            if (
                framework.name == "BASRustMemoryTracker.xcframework"
                and architectures != ["arm64"]
            ):
                errors.append(
                    "BASRustMemoryTracker.xcframework simulator slice must "
                    f"remain arm64-only; found {architectures!r}"
                )
        else:
            errors.append(
                f"XCFramework iOS library has unsupported variant {variant!r}: "
                f"{framework}/{identifier}"
            )
            continue
        archive = framework / identifier / library_path
        if not archive.is_file() or archive.stat().st_size == 0:
            errors.append(f"XCFramework archive is missing: {archive}")
            continue
        if "\t" in str(archive) or "\n" in str(archive):
            errors.append(f"XCFramework archive path is not representable: {archive}")
            continue
        rows.append((identifier, str(archive), expected_platform))
    if device == 0 or simulator == 0:
        errors.append(
            f"XCFramework must carry device and simulator archives independently: "
            f"{framework} device={device} simulator={simulator}"
        )
if errors:
    for error in errors:
        print(f"FAIL: {error}", file=sys.stderr)
    raise SystemExit(1)
for row in rows:
    print("\t".join(row))
PY
then
  exit 1
fi

while IFS=$'\t' read -r identifier archive expected_platform; do
  [[ -n "$archive" ]] || continue
  otool_output="$WORK_DIR/otool-$(printf '%s' "$identifier" | tr -c 'A-Za-z0-9._-' '_').txt"
  set +e
  if [[ -n "${QINAO_OTOOL:-}" ]]; then
    "$QINAO_OTOOL" -l "$archive" >"$otool_output" 2>"$otool_output.error"
  else
    xcrun otool -l "$archive" >"$otool_output" 2>"$otool_output.error"
  fi
  otool_status=$?
  set -e
  if [[ "$otool_status" -ne 0 ]]; then
    fail "otool failed with exit $otool_status for $identifier: $(<"$otool_output.error")"
  fi
  if ! python3 - "$identifier" "$expected_platform" "$otool_output" <<'PY'
from __future__ import annotations

import re
import sys
from pathlib import Path

identifier, expected_platform, output_path = sys.argv[1:]
lines = Path(output_path).read_text(encoding="utf-8").splitlines()
header = re.compile(r"^.+\(([^()]*)\):$")
members: list[tuple[str, list[tuple[str, str]]]] = []
current: str | None = None
current_versions: list[tuple[str, str]] | None = None
in_build_version = False
platform: str | None = None
for line in lines:
    match = header.match(line)
    if match:
        current = match.group(1)
        current_versions = []
        members.append((current, current_versions))
        in_build_version = False
        platform = None
        continue
    stripped = line.strip()
    if stripped == "cmd LC_BUILD_VERSION":
        in_build_version = True
        platform = None
        continue
    if in_build_version and stripped.startswith("platform "):
        platform = stripped.split()[1]
        continue
    if in_build_version and stripped.startswith("minos "):
        minimum = stripped.split()[1]
        if current is None or current_versions is None or platform is None:
            print(
                f"FAIL: {identifier} has an unbound LC_BUILD_VERSION",
                file=sys.stderr,
            )
            raise SystemExit(1)
        current_versions.append((platform, minimum))
        in_build_version = False
        platform = None
if not members:
    print(f"FAIL: {identifier} otool found no Mach-O archive members", file=sys.stderr)
    raise SystemExit(1)
errors: list[str] = []
for member, versions in members:
    if not versions:
        errors.append(f"{identifier} member {member} has no LC_BUILD_VERSION")
        continue
    for platform_value, minimum in versions:
        try:
            parsed = tuple(int(part) for part in minimum.split("."))
        except ValueError:
            parsed = ()
        if platform_value != expected_platform:
            errors.append(
                f"{identifier} member {member} platform {platform_value}, "
                f"expected {expected_platform}"
            )
        if parsed < (27, 0):
            errors.append(
                f"{identifier} member {member} minos {minimum}, below 27.0"
            )
if errors:
    for error in errors:
        print(f"FAIL: {error}", file=sys.stderr)
    raise SystemExit(1)
PY
  then
    exit 1
  fi
done <"$XCFRAMEWORK_LIST"

for directory in \
  "$ROOT/BehavioralAISubstrate" \
  "$ROOT/SampleHost" \
  "$ROOT/QinaoRuntimeSDK"
do
  [[ -d "$directory" ]] || fail "release fallback scan path is missing: $directory"
done
set +e
rg -n 'release.*(inProcessK4|legacyK4)|(inProcessK4|legacyK4).*release' \
  "$ROOT/BehavioralAISubstrate" "$ROOT/SampleHost" "$ROOT/QinaoRuntimeSDK" \
  --glob '*.swift' >"$WORK_DIR/release-fallback.matches" \
  2>"$WORK_DIR/release-fallback.error"
scanner_status=$?
set -e
case "$scanner_status" in
  0)
    cat "$WORK_DIR/release-fallback.matches" >&2
    fail 'release-selectable in-process K4 fallback found'
    ;;
  1) ;;
  *)
    fail "release fallback scanner failed with exit $scanner_status: $(<"$WORK_DIR/release-fallback.error")"
    ;;
esac

echo "PASS: first-party source, resolved products, and device/simulator Mach-O members require iOS 27.0"
