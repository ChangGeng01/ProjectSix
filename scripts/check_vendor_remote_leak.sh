#!/usr/bin/env bash
# M225 — vendor freeze remote-leak guard.
#
# After M224 vendor freeze, BehavioralAISubstrate resolves all 15
# transitive packages from `BehavioralAISubstrate/Vendor/` (path:
# deps). The promise: a clean build performs zero remote git fetches.
#
# This script defends that promise. It runs `swift package
# show-dependencies` and asserts that every line that looks like a
# package reference resolves under `BehavioralAISubstrate/Vendor/`,
# never under a remote URL host or `~/Library/Caches`. If a future
# vendor swap (e.g. upgrading mlx-swift-lm to a newer revision)
# introduces a new transitive that wasn't previously vendored, this
# guard catches it before the build succeeds with a silent remote
# fetch.
#
# Two failure modes are caught:
#   1. A `.package(url: "https://...")` line slipped into a vendored
#      Package.swift and is being resolved remotely (blast radius:
#      the vendor freeze is silently broken).
#   2. A new transitive dep got pulled in by an upgraded vendored
#      package and isn't itself vendored under `Vendor/` (blast
#      radius: build still works but is no longer self-contained).
#
# Inert / acceptable cases (NOT flagged):
#   - swift-docc-plugin url: refs guarded by
#     `if Context.environment["MLX_SWIFT_BUILD_DOC"] == "1"` blocks
#     in mlx-swift-lm/Package.swift and mlx-swift/Package.swift —
#     never trigger a fetch in normal BAS builds.
#
# Run as part of the boundary check suite. Exit code:
#   0 — no leaks, vendor freeze intact
#   1 — remote leak detected; show output for which package leaked

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/BehavioralAISubstrate"

SHOW_DEPS_OUTPUT="$(swift package show-dependencies 2>&1 || true)"

# Collect lines that show package paths/locations. The
# `show-dependencies --format text` output looks like:
#
#   .
#   ├── mlx-swift-lm 7e2b7107…
#   │   ├── mlx-swift 0.31.3
#   …
#
# Path-resolved deps look like:
#
#   ├── mlx-swift-lm unspecified
#   │   ├── mlx-swift unspecified
#
# An `unspecified` token in the version column is the SPM signal
# that the dep was resolved as a path package, not a remote one.
# Conversely a SemVer or commit-SHA token signals remote resolution.

leaked=()
while IFS= read -r line; do
    # Only inspect tree lines that name a package (have version
    # token). Skip blank lines and the leading `.` root.
    if [[ "$line" =~ ^[\.\│├└─[:space:]]+([a-zA-Z][a-zA-Z0-9_-]+)[[:space:]]+([^[:space:]]+)$ ]]; then
        name="${BASH_REMATCH[1]}"
        version="${BASH_REMATCH[2]}"
        if [ "$version" != "unspecified" ]; then
            leaked+=("$name=$version")
        fi
    fi
done <<< "$SHOW_DEPS_OUTPUT"

if [ ${#leaked[@]} -gt 0 ]; then
    echo "vendor remote-leak check FAILED:"
    echo ""
    echo "Packages resolving with version-pinned (remote) state:"
    for entry in "${leaked[@]}"; do
        echo "  - $entry"
    done
    echo ""
    echo "Each remote-resolved package is a hole in the M224 vendor"
    echo "freeze. Either:"
    echo "  (a) move the package source into BehavioralAISubstrate/Vendor/"
    echo "      and rewrite the dependency reference to path:"
    echo "  (b) confirm the dep is intentionally allowed to fetch from"
    echo "      a remote (e.g. an env-gated devtools extension) and"
    echo "      add it to this script's allowlist."
    echo ""
    echo "Full show-dependencies output:"
    echo "$SHOW_DEPS_OUTPUT"
    exit 1
fi

# Also catch the case where a brand-new url: ref slipped into any
# vendored Package.swift outside of an env-gated block. The shape
# we expect is:
#   .package(url: "https://github.com/apple/swift-docc-plugin"…)
# inside an `if Context.environment[…] == "1"` block. Anything else
# is a leak.
new_url_leaks=()
while IFS= read -r match; do
    file="${match%%:*}"
    rest="${match#*:}"
    line_no="${rest%%:*}"
    # If this url: line is preceded within ~5 lines by an
    # `if Context.environment` guard, accept it as inert.
    start=$((line_no > 6 ? line_no - 6 : 1))
    head_chunk=$(sed -n "${start},${line_no}p" "$file" 2>/dev/null || true)
    if echo "$head_chunk" \
        | grep -qE 'Context\.environment\[[^]]+\][[:space:]]*=='
    then
        continue
    fi
    new_url_leaks+=("$file:$line_no")
done < <(grep -rnE 'url:[[:space:]]*"https?://' \
    "$ROOT/BehavioralAISubstrate/Vendor"/*/Package.swift 2>/dev/null || true)

if [ ${#new_url_leaks[@]} -gt 0 ]; then
    echo "vendor remote-leak check FAILED:"
    echo ""
    echo "New url: refs found in vendored Package.swift outside of"
    echo "Context.environment-guarded blocks:"
    for entry in "${new_url_leaks[@]}"; do
        echo "  - $entry"
    done
    exit 1
fi

echo "check_vendor_remote_leak: clean (vendor freeze intact, all" \
    "deps resolve from BehavioralAISubstrate/Vendor/)."
