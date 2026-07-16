#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
DEFAULT_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd -P)"
ROOT="${1:-$DEFAULT_ROOT}"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

require_only_declaration() {
  local file="$1"
  local key_pattern="$2"
  local expected_pattern="$3"
  local label="$4"
  local declarations

  declarations="$(rg -- "$key_pattern" "$file" || true)"
  if [[ -z "$declarations" ]] || \
    printf '%s\n' "$declarations" | rg -q -v -- "$expected_pattern"
  then
    fail "$label must declare only iOS 27.0"
  fi
}

verify_swift_manifest() {
  local manifest="$1"
  local package_path="${manifest%/Package.swift}"
  local manifest_json

  if ! manifest_json="$(
    swift package --package-path "$ROOT/$package_path" dump-package
  )"; then
    fail "$manifest could not be resolved"
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

for manifest in BehavioralAISubstrate/Package.swift SampleHost/Package.swift QinaoRuntimeSDK/Package.swift; do
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

rg -q '^[[:space:]]+com\.apple\.developer\.kernel\.increased-memory-limit: true$' "$XCODEGEN_SPEC" || {
  echo 'FAIL: XcodeGen spec would erase the increased-memory-limit entitlement' >&2
  exit 1
}
rg -q '^[[:space:]]+BGTaskSchedulerPermittedIdentifiers:$' "$XCODEGEN_SPEC" || {
  echo 'FAIL: XcodeGen spec would erase the background-task identifier' >&2
  exit 1
}
rg -q '<key>com\.apple\.developer\.kernel\.increased-memory-limit</key>' "$ROOT/BehavioralAISubstrate/DeviceTestApp/Resources/BASDeviceTestApp.entitlements" || {
  echo 'FAIL: generated entitlements lost increased-memory-limit' >&2
  exit 1
}
rg -q '<key>BGTaskSchedulerPermittedIdentifiers</key>' "$ROOT/BehavioralAISubstrate/DeviceTestApp/Resources/Info.plist" || {
  echo 'FAIL: generated Info.plist lost the background-task identifier' >&2
  exit 1
}

if rg -n 'release.*(inProcessK4|legacyK4)|(inProcessK4|legacyK4).*release' \
  "$ROOT/BehavioralAISubstrate" "$ROOT/SampleHost" "$ROOT/QinaoRuntimeSDK" \
  --glob '*.swift'; then
  echo 'FAIL: release-selectable in-process K4 fallback found' >&2
  exit 1
fi
