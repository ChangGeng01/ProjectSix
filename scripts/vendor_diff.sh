#!/usr/bin/env bash
# M229 — compare a candidate upstream Package.swift against the
# currently-vendored copy of a package.
#
# Use case: you want to upgrade `Vendor/mlx-swift-lm` from revision
# 7e2b7107… to a newer commit. Before you blindly `cp -r`, you
# need to know what changed in the dep graph — did the new
# revision add a new transitive (which would require vendoring it
# too)? Did it drop a dep we used to vendor (now safe to remove)?
# Did versions change?
#
# Usage:
#   vendor_diff.sh <package-name> <upstream-Package.swift>
#
# Example:
#   curl -L https://raw.githubusercontent.com/ml-explore/mlx-swift-lm/<rev>/Package.swift > /tmp/upstream.swift
#   ./scripts/vendor_diff.sh mlx-swift-lm /tmp/upstream.swift
#
# Output (per category):
#   ADDED:       deps the upstream has that we don't vendor yet
#   REMOVED:     deps we vendor that the upstream no longer needs
#   CHANGED:     deps that exist in both but with different version
#                constraints
#   PRESERVED:   deps unchanged across the two
#
# Exit code:
#   0  — diff completed (any number of changes; you decide whether
#        to act)
#   2  — usage error (wrong args, missing files)

set -euo pipefail

if [ $# -ne 2 ]; then
    cat <<USAGE
Usage: $(basename "$0") <package-name> <upstream-Package.swift>

Compare an upstream Package.swift against the currently-vendored
copy of a package under BehavioralAISubstrate/Vendor/.

Example:
  curl -L https://raw.githubusercontent.com/ml-explore/mlx-swift-lm/<rev>/Package.swift > /tmp/upstream.swift
  $(basename "$0") mlx-swift-lm /tmp/upstream.swift
USAGE
    exit 2
fi

PKG="$1"
UPSTREAM="$2"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VENDORED="$ROOT/BehavioralAISubstrate/Vendor/$PKG/Package.swift"

if [ ! -f "$VENDORED" ]; then
    echo "vendor_diff: no vendored Package.swift for '$PKG' at" >&2
    echo "  $VENDORED" >&2
    exit 2
fi

if [ ! -f "$UPSTREAM" ]; then
    echo "vendor_diff: upstream file not found at $UPSTREAM" >&2
    exit 2
fi

# Extract a normalised "deps" list from a Package.swift. Format:
#   <kind>:<location>:<constraint>
# where kind is "url" or "path", location is the URL or relative
# path, and constraint is the version requirement string (or
# "unspecified" for path: refs).
extract_deps() {
    local file="$1"
    # Match each .package(...) line, separating url: from path:.
    # Multi-line .package(url: "X", revision: "Y") declarations are
    # joined by squashing newlines first.
    tr '\n' ' ' < "$file" \
        | sed -E 's|\.package\(|\n.package(|g' \
        | grep -E '^\.package\(' \
        | while IFS= read -r line; do
            url=$(echo "$line" \
                | sed -nE 's/.*url:[[:space:]]*"([^"]+)".*/\1/p')
            path=$(echo "$line" \
                | sed -nE 's/.*path:[[:space:]]*"([^"]+)".*/\1/p')
            from=$(echo "$line" \
                | sed -nE 's/.*from:[[:space:]]*"([^"]+)".*/\1/p')
            revision=$(echo "$line" \
                | sed -nE 's/.*revision:[[:space:]]*"([^"]+)".*/\1/p')
            exact=$(echo "$line" \
                | sed -nE 's/.*exact:[[:space:]]*"([^"]+)".*/\1/p')
            range=$(echo "$line" \
                | sed -nE 's/.*("([0-9]+\.[0-9]+\.[0-9]+)").*("([0-9]+\.[0-9]+\.[0-9]+)").*/\2-\4/p')
            constraint="${revision:-${from:-${exact:-${range:-unspecified}}}}"
            if [ -n "$url" ]; then
                # Normalise URL: strip protocol + .git suffix +
                # github.com/ prefix to make comparisons stable.
                short=$(echo "$url" \
                    | sed -E 's|^https?://github\.com/||;s|\.git$||')
                echo "url:$short:$constraint"
            elif [ -n "$path" ]; then
                echo "path:$path:unspecified"
            fi
        done \
        | sort -u
}

VENDORED_DEPS="$(extract_deps "$VENDORED")"
UPSTREAM_DEPS="$(extract_deps "$UPSTREAM")"

echo "vendor_diff: $PKG"
echo "  vendored: $VENDORED"
echo "  upstream: $UPSTREAM"
echo ""

added=$(comm -13 \
    <(echo "$VENDORED_DEPS" | sort -u) \
    <(echo "$UPSTREAM_DEPS" | sort -u))
removed=$(comm -23 \
    <(echo "$VENDORED_DEPS" | sort -u) \
    <(echo "$UPSTREAM_DEPS" | sort -u))
preserved=$(comm -12 \
    <(echo "$VENDORED_DEPS" | sort -u) \
    <(echo "$UPSTREAM_DEPS" | sort -u))

# Detect "changed" cases: same package identity (URL or path) but
# different constraint. Strip the constraint to find shared keys.
key_of() { echo "$1" | awk -F: '{print $1":"$2}'; }
vendored_keys=$(echo "$VENDORED_DEPS" \
    | while IFS= read -r d; do key_of "$d"; done | sort -u)
upstream_keys=$(echo "$UPSTREAM_DEPS" \
    | while IFS= read -r d; do key_of "$d"; done | sort -u)
shared_keys=$(comm -12 \
    <(echo "$vendored_keys") \
    <(echo "$upstream_keys"))

changed=""
while IFS= read -r key; do
    [ -z "$key" ] && continue
    v=$(echo "$VENDORED_DEPS" | grep "^${key}:" || true)
    u=$(echo "$UPSTREAM_DEPS" | grep "^${key}:" || true)
    if [ -n "$v" ] && [ -n "$u" ] && [ "$v" != "$u" ]; then
        changed=$(printf "%s\n  %s -> %s\n" \
            "$changed" "$v" "$u")
    fi
done <<< "$shared_keys"

if [ -n "$added" ]; then
    echo "ADDED in upstream (need to vendor or remove):"
    echo "$added" | sed 's|^|  |'
    echo ""
fi
if [ -n "$removed" ]; then
    echo "REMOVED in upstream (can drop from Vendor/):"
    echo "$removed" | sed 's|^|  |'
    echo ""
fi
if [ -n "$changed" ]; then
    echo "CHANGED constraint:"
    echo "$changed"
    echo ""
fi
if [ -n "$preserved" ]; then
    echo "PRESERVED (no action needed):"
    echo "$preserved" | sed 's|^|  |'
    echo ""
fi

if [ -z "$added" ] && [ -z "$removed" ] && [ -z "$changed" ]; then
    echo "No dep changes between vendored '$PKG' and upstream."
fi
