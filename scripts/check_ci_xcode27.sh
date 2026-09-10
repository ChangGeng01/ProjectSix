#!/bin/bash
# Read-only CI SDK checks. The calling workflow selects Xcode explicitly.
set -euo pipefail
if (( $# == 0 )); then
  echo "At least one SDK name is required" >&2
  exit 2
fi
xcode_version="$(xcodebuild -version)"
printf '%s\n' "$xcode_version"
if [[ ! "${xcode_version%%$'\n'*}" =~ ^Xcode[[:space:]]27([.][0-9]+)*$ ]]; then
  echo "Expected Xcode 27 on the xcode-27 runner" >&2
  exit 1
fi
for sdk in "$@"; do
  sdk_version="$(xcrun --sdk "$sdk" --show-sdk-version)"
  printf '%s SDK: %s\n' "$sdk" "$sdk_version"
  if [[ ! "$sdk_version" =~ ^27([.][0-9]+)*$ ]]; then
    echo "Expected a 27-generation $sdk SDK" >&2
    exit 1
  fi
done
