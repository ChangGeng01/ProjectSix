#!/usr/bin/env python3
"""Run a closed Swift test-suite alternation and prove exact execution."""

from __future__ import annotations

import argparse
import os
import re
import stat
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ElementTree
from pathlib import Path


EXIT_INVALID = 1
EXIT_BUILD_FAILURE = 2
EXIT_DISCOVERY_FAILURE = 3
EXIT_ZERO_EXECUTION = 4
EXIT_TEST_FAILURE = 5
SUITE_NAME = r"[A-Za-z_][A-Za-z0-9_]*"
CLOSED_ALTERNATION = re.compile(rf"{SUITE_NAME}(?:\|{SUITE_NAME})*")
DOTTED_SUITE = re.compile(rf"{SUITE_NAME}(?:\.{SUITE_NAME})*")
MAX_XUNIT_BYTES = 16 * 1024 * 1024


class FilterError(ValueError):
    """A fail-closed filter or package validation error."""


class DiscoveryError(ValueError):
    """SwiftPM discovery output was missing, ambiguous, or malformed."""


class EvidenceError(ValueError):
    """Structured test-execution evidence was missing or malformed."""


class SwiftInvocationError(OSError):
    """The Swift tool process could not be started."""


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--package-path", type=Path, required=True)
    parser.add_argument("--filter", required=True)
    parser.add_argument("--require-suite", action="append")
    return parser.parse_args()


def derived_suites(filter_value: str) -> list[str]:
    if CLOSED_ALTERNATION.fullmatch(filter_value) is None:
        raise FilterError(
            "--filter must be a closed alternation such as "
            "SuiteA|SuiteB|SuiteC"
        )
    suites = filter_value.split("|")
    if len(suites) != len(set(suites)):
        raise FilterError(
            "--filter must be a closed alternation with unique suite names"
        )
    return suites


def required_suite_map(
    required: list[str] | None,
    suites: list[str],
) -> dict[str, str]:
    if required is None:
        return {}
    if (
        len(required) != len(suites)
        or len(required) != len(set(required))
        or any(DOTTED_SUITE.fullmatch(item) is None for item in required)
    ):
        raise FilterError(
            "--require-suite set must equal the complete filter-derived set"
        )
    mapped: dict[str, str] = {}
    for identity in required:
        selector = identity.rsplit(".", 1)[-1]
        if selector not in suites or selector in mapped:
            raise FilterError(
                "--require-suite set must equal the complete filter-derived set"
            )
        mapped[selector] = identity
    if set(mapped) != set(suites):
        raise FilterError(
            "--require-suite set must equal the complete filter-derived set"
        )
    return mapped


def parse_discovered_test_ids(output: str) -> dict[str, str]:
    discovered: dict[str, str] = {}
    for line in output.splitlines():
        if not line or line != line.strip() or "/" not in line:
            raise DiscoveryError(
                "swift test list emitted a non-test or malformed line"
            )
        classname, name = line.split("/", 1)
        if (
            DOTTED_SUITE.fullmatch(classname) is None
            or not name
            or name != name.strip()
        ):
            raise DiscoveryError(
                f"swift test list emitted malformed test ID: {line!r}"
            )
        if line in discovered:
            raise DiscoveryError(
                f"swift test list emitted duplicate test ID: {line}"
            )
        discovered[line] = classname
    if not discovered:
        raise DiscoveryError("swift test list emitted no test IDs")
    return discovered


def resolve_suite_identities(
    discovered: dict[str, str],
    suites: list[str],
    required: dict[str, str],
) -> dict[str, str]:
    classnames = set(discovered.values())
    resolved: dict[str, str] = {}
    problems: list[str] = []
    for selector in suites:
        required_identity = required.get(selector)
        if required_identity is not None and "." in required_identity:
            candidates = (
                [required_identity] if required_identity in classnames else []
            )
        else:
            candidates = sorted(
                classname
                for classname in classnames
                if classname.rsplit(".", 1)[-1] == selector
            )
        if len(candidates) == 1:
            resolved[selector] = candidates[0]
        elif not candidates:
            problems.append(f"{selector} (missing)")
        else:
            problems.append(
                f"{selector} (ambiguous: {', '.join(candidates)})"
            )
    if problems:
        raise DiscoveryError(
            "derived suites not discovered exactly: " + "; ".join(problems)
        )
    return resolved


def expected_test_ids(
    discovered: dict[str, str],
    suite_identities: dict[str, str],
) -> set[str]:
    identities = set(suite_identities.values())
    expected = {
        test_id
        for test_id, classname in discovered.items()
        if classname in identities
    }
    missing_suites = [
        selector
        for selector, classname in suite_identities.items()
        if classname not in {
            discovered[test_id]
            for test_id in expected
        }
    ]
    if missing_suites:
        raise DiscoveryError(
            "derived suites contain no discovered test IDs: "
            + ", ".join(missing_suites)
        )
    return expected


def run_swift(arguments: list[str]) -> subprocess.CompletedProcess[str]:
    try:
        return subprocess.run(
            ["swift", *arguments],
            check=False,
            capture_output=True,
            text=True,
        )
    except OSError as error:
        raise SwiftInvocationError(
            f"swift tool invocation failed: {error}"
        ) from error


def replay_output(completed: subprocess.CompletedProcess[str]) -> None:
    if completed.stdout:
        print(completed.stdout, end="")
    if completed.stderr:
        print(completed.stderr, end="", file=sys.stderr)


def swift_testing_xunit_path(primary: Path) -> Path:
    return primary.with_name(
        f"{primary.stem}-swift-testing{primary.suffix}"
    )


def secure_xunit_bytes(path: Path) -> bytes:
    try:
        metadata = path.lstat()
    except FileNotFoundError:
        raise
    if (
        not stat.S_ISREG(metadata.st_mode)
        or metadata.st_nlink != 1
        or metadata.st_uid != os.getuid()
        or metadata.st_size <= 0
        or metadata.st_size > MAX_XUNIT_BYTES
    ):
        raise EvidenceError(
            f"structured xUnit report has unsafe file metadata: {path.name}"
        )
    try:
        raw = path.read_bytes()
    except OSError as error:
        raise EvidenceError(
            f"structured xUnit report cannot be read: {path.name}: {error}"
        ) from error
    if len(raw) != metadata.st_size:
        raise EvidenceError(
            f"structured xUnit report changed while being read: {path.name}"
        )
    lowered = raw.lower()
    if b"<!doctype" in lowered or b"<!entity" in lowered:
        raise EvidenceError(
            f"structured xUnit report contains forbidden DTD/entity: {path.name}"
        )
    return raw


def parse_xunit_report(
    path: Path,
) -> list[tuple[str, bool, bool]]:
    raw = secure_xunit_bytes(path)
    try:
        root = ElementTree.fromstring(raw)
    except ElementTree.ParseError as error:
        raise EvidenceError(
            f"malformed structured xUnit report {path.name}: {error}"
        ) from error
    if root.tag != "testsuites":
        raise EvidenceError(
            f"malformed structured xUnit root in {path.name}"
        )
    cases: list[tuple[str, bool, bool]] = []
    for testcase in root.iter("testcase"):
        classname = testcase.get("classname")
        name = testcase.get("name")
        if (
            classname is None
            or DOTTED_SUITE.fullmatch(classname) is None
            or name is None
            or not name
            or name != name.strip()
        ):
            raise EvidenceError(
                f"malformed structured xUnit testcase in {path.name}"
            )
        child_tags = [child.tag for child in testcase]
        if any(
            tag not in {"skipped", "failure", "error", "system-out", "system-err"}
            for tag in child_tags
        ):
            raise EvidenceError(
                f"malformed structured xUnit testcase child in {path.name}"
            )
        skipped = "skipped" in child_tags
        failed = "failure" in child_tags or "error" in child_tags
        if skipped and failed:
            raise EvidenceError(
                f"structured xUnit testcase is both skipped and failed: "
                f"{classname}/{name}"
            )
        cases.append((f"{classname}/{name}", skipped, failed))
    return cases


def exact_execution_from_reports(
    paths: tuple[Path, Path],
    expected: set[str],
) -> tuple[set[str], bool]:
    present = [path for path in paths if path.exists()]
    if not present:
        raise EvidenceError("structured xUnit reports are missing")
    observed: set[str] = set()
    executed: set[str] = set()
    had_failure = False
    for path in present:
        for test_id, skipped, failed in parse_xunit_report(path):
            if test_id in observed:
                raise EvidenceError(
                    f"duplicate structured xUnit test ID: {test_id}"
                )
            observed.add(test_id)
            if test_id not in expected:
                raise EvidenceError(
                    f"unknown structured xUnit test ID: {test_id}"
                )
            if not skipped:
                executed.add(test_id)
            had_failure = had_failure or failed
    missing_execution = sorted(expected - executed)
    if missing_execution:
        raise EvidenceError(
            "missing discovered test IDs from non-skipped structured xUnit "
            "execution: " + ", ".join(missing_execution)
        )
    return executed, had_failure


def executed_suite_counts(
    executed: set[str],
    suite_identities: dict[str, str],
) -> dict[str, int]:
    counts = {selector: 0 for selector in suite_identities}
    identity_to_selector = {
        identity: selector
        for selector, identity in suite_identities.items()
    }
    for test_id in executed:
        classname, _ = test_id.split("/", 1)
        selector = identity_to_selector.get(classname)
        if selector is not None:
            counts[selector] += 1
    return counts


def main() -> int:
    try:
        args = parse_args()
        suites = derived_suites(args.filter)
        required = required_suite_map(args.require_suite, suites)
        package_path = args.package_path
        if not package_path.is_dir() or not (package_path / "Package.swift").is_file():
            raise FilterError(
                f"--package-path is not an exact Swift package: {package_path}"
            )
    except FilterError as error:
        print(f"swift-filter: invalid: {error}", file=sys.stderr)
        return EXIT_INVALID

    build_arguments = [
        "build",
        "--package-path",
        str(package_path),
        "--build-tests",
    ]
    try:
        build_result = run_swift(build_arguments)
    except SwiftInvocationError as error:
        print(f"swift-filter: build failure: {error}", file=sys.stderr)
        return EXIT_BUILD_FAILURE
    replay_output(build_result)
    if build_result.returncode != 0:
        print("swift-filter: build failure", file=sys.stderr)
        return EXIT_BUILD_FAILURE

    list_arguments = ["test", "--package-path", str(package_path), "list"]
    list_arguments.append("--skip-build")
    try:
        list_result = run_swift(list_arguments)
    except SwiftInvocationError as error:
        print(f"swift-filter: discovery failure: {error}", file=sys.stderr)
        return EXIT_DISCOVERY_FAILURE
    replay_output(list_result)
    if list_result.returncode != 0:
        print("swift-filter: discovery failure", file=sys.stderr)
        return EXIT_DISCOVERY_FAILURE
    try:
        discovered = parse_discovered_test_ids(list_result.stdout)
        suite_identities = resolve_suite_identities(
            discovered,
            suites,
            required,
        )
        expected = expected_test_ids(discovered, suite_identities)
    except DiscoveryError as error:
        missing_discovery = str(error)
        print(
            f"swift-filter: discovery failure; {missing_discovery}",
            file=sys.stderr,
        )
        return EXIT_DISCOVERY_FAILURE

    with tempfile.TemporaryDirectory(
        prefix="qinao-swift-filter-"
    ) as output_directory:
        primary_xunit = Path(output_directory) / "results.xml"
        swift_testing_xunit = swift_testing_xunit_path(primary_xunit)
        run_arguments = [
            "test",
            "--package-path",
            str(package_path),
            "--skip-build",
            "--parallel",
            "--num-workers",
            "1",
            "--filter",
            args.filter,
            "--xunit-output",
            str(primary_xunit),
        ]
        try:
            run_result = run_swift(run_arguments)
        except SwiftInvocationError as error:
            print(f"swift-filter: test failure: {error}", file=sys.stderr)
            return EXIT_TEST_FAILURE
        replay_output(run_result)
        try:
            executed, structured_failure = exact_execution_from_reports(
                (primary_xunit, swift_testing_xunit),
                expected,
            )
        except EvidenceError as error:
            if run_result.returncode != 0:
                print(
                    "swift-filter: test failure with invalid structured "
                    f"xUnit evidence: {error}",
                    file=sys.stderr,
                )
                return EXIT_TEST_FAILURE
            print(
                f"swift-filter: zero execution; {error}",
                file=sys.stderr,
            )
            return EXIT_ZERO_EXECUTION

    counts = executed_suite_counts(executed, suite_identities)
    missing_execution = [
        suite for suite in suites if counts[suite] == 0
    ]
    if missing_execution:
        print(
            "swift-filter: zero execution; suites executed no tests: "
            + ", ".join(missing_execution),
            file=sys.stderr,
        )
        return EXIT_ZERO_EXECUTION
    if run_result.returncode != 0 or structured_failure:
        print("swift-filter: test failure after exact execution", file=sys.stderr)
        return EXIT_TEST_FAILURE

    count_summary = " ".join(f"{suite}={counts[suite]}" for suite in suites)
    print(
        f"swift-filter: PASS executed={len(executed)} {count_summary}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
