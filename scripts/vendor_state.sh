#!/usr/bin/env bash
# M229 — print the current vendor freeze state.
#
# Companion to `check_vendor_remote_leak.sh` (M225). The leak guard
# answers "are there any remote URLs sneaking in?"; this script
# answers "what does my Vendor/ tree look like right now?"
#
# Output format (one block per package):
#
#   PACKAGE_NAME
#     swift-tools: 6.1
#     products:    LibA, LibB
#     deps:        ../sibling-1, ../sibling-2
#     env-gated:   apple/swift-docc-plugin
#     size:        12 MB
#     license:     Apache-2.0
#
# Use cases:
#   - Pre-upgrade snapshot: `vendor_state.sh > /tmp/vendor.before`
#     before swapping a vendored package, then run again after and
#     `diff -u` the two outputs to see exactly what changed.
#   - Audit: paste output into a doc / honesty-board entry to
#     document the current vendor freeze contents.
#   - Onboarding: reading this output teaches the vendor tree
#     shape in 30 seconds without reading 15 Package.swift files.

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VENDOR="$ROOT/BehavioralAISubstrate/Vendor"

if [ ! -d "$VENDOR" ]; then
    echo "vendor_state: no Vendor/ directory at $VENDOR" >&2
    exit 1
fi

echo "Vendor freeze state — $(date '+%Y-%m-%d %H:%M:%S')"
echo "Root:   $VENDOR"
total_size=$(du -sh "$VENDOR" 2>/dev/null | cut -f1 | tr -d ' ')
echo "Total:  $total_size"
pkg_count=$(find "$VENDOR" -mindepth 1 -maxdepth 1 -type d \
    2>/dev/null | wc -l | tr -d ' ')
echo "Count:  $pkg_count packages"
echo ""

# Flatten Package.swift onto a single line so multi-line
# declarations like
#   .library(
#       name: "EventSource",
#       targets: ["EventSource"]
#   )
# can be matched by single-pass regex extractors.
flatten() {
    tr '\n' ' ' < "$1" 2>/dev/null | sed -E 's|[[:space:]]+| |g'
}

list_products() {
    local flat="$1"
    echo "$flat" \
        | grep -oE '\.library\([[:space:]]*name:[[:space:]]*"[^"]+"' \
            2>/dev/null \
        | sed -E 's|.*name:[[:space:]]*"([^"]+)".*|\1|' \
        | sort -u | paste -sd, - \
        | sed 's|,| , |g'
}

list_path_deps() {
    local flat="$1"
    echo "$flat" \
        | grep -oE '\.package\([[:space:]]*path:[[:space:]]*"[^"]+"' \
            2>/dev/null \
        | sed -E 's|.*path:[[:space:]]*"([^"]+)".*|\1|' \
        | sort -u | paste -sd, - \
        | sed 's|,| , |g'
}

list_url_deps() {
    local flat="$1"
    echo "$flat" \
        | grep -oE '\.package\([[:space:]]*url:[[:space:]]*"[^"]+"' \
            2>/dev/null \
        | sed -E 's|.*url:[[:space:]]*"([^"]+)".*|\1|' \
        | sed -E 's|^https?://github\.com/||;s|\.git$||' \
        | sort -u | paste -sd, - \
        | sed 's|,| , |g'
}

for pkg_dir in "$VENDOR"/*/; do
    pkg=$(basename "$pkg_dir")
    pkg_swift="$pkg_dir/Package.swift"
    if [ ! -f "$pkg_swift" ]; then
        continue
    fi
    echo "$pkg"

    tools_line=$(grep -m1 -E '^// swift-tools-version' \
        "$pkg_swift" 2>/dev/null \
        | sed -E 's|^// swift-tools-version: ?||;s|^// swift-tools-version:||')
    echo "  swift-tools: ${tools_line:-unknown}"

    flat=$(flatten "$pkg_swift")

    products=$(list_products "$flat")
    echo "  products:    ${products:-(none)}"

    path_deps=$(list_path_deps "$flat")
    echo "  deps:        ${path_deps:-(none)}"

    url_deps=$(list_url_deps "$flat")
    if [ -n "$url_deps" ]; then
        echo "  env-gated:   $url_deps"
    fi

    size=$(du -sh "$pkg_dir" 2>/dev/null | cut -f1 | tr -d ' ')
    echo "  size:        $size"

    license_file=""
    for cand in LICENSE LICENSE.txt LICENSE.md COPYING; do
        if [ -f "$pkg_dir/$cand" ]; then
            license_file="$cand"
            break
        fi
    done
    if [ -n "$license_file" ]; then
        first_line=$(grep -m1 -v '^[[:space:]]*$' \
            "$pkg_dir/$license_file" 2>/dev/null \
            | sed -E 's|^[[:space:]]+||;s|[[:space:]]+$||')
        echo "  license:     $first_line ($license_file)"
    else
        echo "  license:     (no LICENSE file found)"
    fi
    echo ""
done
