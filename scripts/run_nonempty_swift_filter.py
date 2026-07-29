#!/usr/bin/env python3
"""Run a closed Swift test-suite alternation and prove non-empty execution."""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path


EXIT_INVALID = 1
EXIT_BUILD_FAILURE = 2
EXIT_DISCOVERY_FAILURE = 3
EXIT_ZERO_EXECUTION = 4
EXIT_TEST_FAILURE = 5
SUITE_NAME = r"[A-Za-z_][A-Za-z0-9_]*"
CLOSED_ALTERNATION = re.compile(rf"{SUITE_NAME}(?:\|{SUITE_NAME})*")
BUILD_FAILURE_MARKERS = (
    "build failed",
    "compile command failed",
    "compilation failed",
    "emit-module command failed",
    "fatal error: module",
    "linker command failed",
)


class FilterError(ValueError):
    """A fail-closed filter or package validation error."""


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


def suite_is_listed(output: str, suite: str) -> bool:
    return re.search(
        rf"(?<![A-Za-z0-9_]){re.escape(suite)}(?=[/.:\s]|$)",
        output,
    ) is not None


def executed_suite_counts(output: str, suites: list[str]) -> dict[str, int]:
    counts = {suite: 0 for suite in suites}
    for line in output.splitlines():
        if re.search(r"\b(?:failed|passed|skipped)\b", line, re.IGNORECASE) is None:
            continue
        for suite in suites:
            if re.search(
                rf"(?<![A-Za-z0-9_]){re.escape(suite)}"
                r"(?=[/.:\s'\]]|$)",
                line,
            ):
                counts[suite] += 1
    return counts


def looks_like_build_failure(output: str) -> bool:
    lowered = output.casefold()
    return any(marker in lowered for marker in BUILD_FAILURE_MARKERS)


def run_swift(arguments: list[str]) -> subprocess.CompletedProcess[str]:
    try:
        return subprocess.run(
            ["swift", *arguments],
            check=False,
            capture_output=True,
            text=True,
        )
    except OSError as error:
        raise FilterError(f"swift tool invocation failed: {error}") from error


def replay_output(completed: subprocess.CompletedProcess[str]) -> None:
    if completed.stdout:
        print(completed.stdout, end="")
    if completed.stderr:
        print(completed.stderr, end="", file=sys.stderr)


def main() -> int:
    try:
        args = parse_args()
        suites = derived_suites(args.filter)
        required = args.require_suite
        if required is not None and (
            len(required) != len(set(required)) or set(required) != set(suites)
        ):
            raise FilterError(
                "--require-suite set must equal the complete filter-derived set"
            )
        package_path = args.package_path
        if not package_path.is_dir() or not (package_path / "Package.swift").is_file():
            raise FilterError(
                f"--package-path is not an exact Swift package: {package_path}"
            )
    except FilterError as error:
        print(f"swift-filter: invalid: {error}", file=sys.stderr)
        return EXIT_INVALID

    list_result = run_swift(
        ["test", "--package-path", str(package_path), "list"]
    )
    replay_output(list_result)
    list_output = list_result.stdout + list_result.stderr
    if list_result.returncode != 0:
        if looks_like_build_failure(list_output):
            print("swift-filter: build failure during discovery", file=sys.stderr)
            return EXIT_BUILD_FAILURE
        print("swift-filter: discovery failure", file=sys.stderr)
        return EXIT_DISCOVERY_FAILURE
    missing_discovery = [
        suite for suite in suites if not suite_is_listed(list_output, suite)
    ]
    if missing_discovery:
        print(
            "swift-filter: discovery failure; derived suites not discovered: "
            + ", ".join(missing_discovery),
            file=sys.stderr,
        )
        return EXIT_DISCOVERY_FAILURE

    run_result = run_swift(
        [
            "test",
            "--package-path",
            str(package_path),
            "--filter",
            args.filter,
        ]
    )
    replay_output(run_result)
    run_output = run_result.stdout + run_result.stderr
    counts = executed_suite_counts(run_output, suites)
    missing_execution = [
        suite for suite in suites if counts[suite] == 0
    ]
    if (
        run_result.returncode != 0
        and not any(counts.values())
        and looks_like_build_failure(run_output)
    ):
        print("swift-filter: build failure during execution", file=sys.stderr)
        return EXIT_BUILD_FAILURE
    if missing_execution:
        print(
            "swift-filter: zero execution; suites executed no tests: "
            + ", ".join(missing_execution),
            file=sys.stderr,
        )
        return EXIT_ZERO_EXECUTION
    if run_result.returncode != 0:
        print("swift-filter: test failure after non-empty execution", file=sys.stderr)
        return EXIT_TEST_FAILURE

    count_summary = " ".join(f"{suite}={counts[suite]}" for suite in suites)
    print(
        f"swift-filter: PASS executed={sum(counts.values())} {count_summary}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
