#!/bin/bash
# Hosted CI prerequisite; unlike check_ci_xcode27.sh this may download a component.
# https://webkit.org/build-tools/ documents Apple's Metal Toolchain installation.
set -euo pipefail
resolver="selected-xcode"
if [[ "${1:-}" == "--resolver" ]]; then
  if (( $# < 2 )); then
    echo "A resolver value is required after --resolver" >&2
    exit 2
  fi
  resolver="$2"
  shift 2
  case "$resolver" in
    xcrun|selected-xcode) ;;
    *) echo "Unsupported CI Metal resolver: $resolver" >&2; exit 2 ;;
  esac
fi
if (( $# == 0 )); then
  echo "At least one SDK name is required" >&2
  exit 2
fi
for sdk in "$@"; do
  case "$sdk" in
    macosx|iphonesimulator) ;;
    *) echo "Unsupported CI Metal SDK: $sdk" >&2; exit 2 ;;
  esac
done

developer_dir=""
if ! developer_dir="$(xcode-select -p)"; then
  echo "Could not resolve selected Xcode developer directory" >&2
  exit 1
fi
if [[ -z "${developer_dir//[[:space:]]/}" ]]; then
  echo "Selected Xcode developer directory is empty" >&2
  exit 1
fi
metal_launcher="${developer_dir%/}/Toolchains/XcodeDefault.xctoolchain/usr/bin/metal"

needs_component=false
if [[ "$resolver" == "selected-xcode" ]] && ! "$metal_launcher" --version; then
  needs_component=true
fi
for sdk in "$@"; do
  if ! xcrun --sdk "$sdk" metal --version; then
    needs_component=true
  fi
done
if [[ "$needs_component" == false ]]; then
  exit 0
fi

echo "Preparing the missing Metal Toolchain component"
if ! xcodebuild -downloadComponent MetalToolchain; then
  echo "Metal Toolchain download failed" >&2
  exit 1
fi
verification_failed=false
if [[ "$resolver" == "selected-xcode" ]] && ! "$metal_launcher" --version; then
  echo "Selected Xcode Metal launcher unavailable after component preparation: $metal_launcher" >&2
  verification_failed=true
fi
for sdk in "$@"; do
  # The component installation changed tool availability; bypass prior lookups.
  if ! xcrun --no-cache --sdk "$sdk" metal --version; then
    echo "Metal compiler unavailable for $sdk after component preparation" >&2
    verification_failed=true
  fi
done
if [[ "$verification_failed" == true ]]; then
  exit 1
fi
