#!/usr/bin/env bash
# Build the same-checkout MLX metallib used by native SwiftPM tests in CI.
set -euo pipefail

if (( $# != 0 )); then
  echo "prepare_ci_mlx_metallib.sh takes no arguments" >&2
  exit 2
fi

if [[ -z "${RUNNER_TEMP+x}" || -z "$RUNNER_TEMP" || ! -d "$RUNNER_TEMP" || ! -w "$RUNNER_TEMP" ]]; then
  echo "RUNNER_TEMP must name an existing writable directory" >&2
  exit 1
fi
if [[ -z "${GITHUB_ENV+x}" || -z "$GITHUB_ENV" || ! -f "$GITHUB_ENV" || ! -w "$GITHUB_ENV" ]]; then
  echo "GITHUB_ENV must name an existing writable regular file" >&2
  exit 1
fi
case "$RUNNER_TEMP" in
  *$'\n'*) echo "RUNNER_TEMP must not contain a newline" >&2; exit 1 ;;
esac
case "$GITHUB_ENV" in
  *$'\n'*) echo "GITHUB_ENV output record path must not contain a newline" >&2; exit 1 ;;
esac
RUNNER_TEMP="$(cd "$RUNNER_TEMP" && pwd -P)"
case "$RUNNER_TEMP" in
  *$'\n'*) echo "Canonical RUNNER_TEMP must not contain a newline" >&2; exit 1 ;;
esac

script_dir="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$script_dir/.." && pwd)"
vendor="$root/BehavioralAISubstrate/Vendor/mlx-swift/Source/Cmlx"
for input_dir in "$vendor/mlx" "$vendor/metal-cpp" "$vendor/json" "$vendor/fmt"; do
  if [[ ! -d "$input_dir" ]]; then
    echo "Required MLX build input directory not found: $input_dir" >&2
    exit 1
  fi
done

scratch="$(mktemp -d "$RUNNER_TEMP/qinao-ci-mlx-metallib.XXXXXX")"
case "$scratch" in
  *$'\n'*) echo "MLX metallib scratch path must not contain a newline" >&2; exit 1 ;;
esac

python3 -m venv "$scratch/tools"
"$scratch/tools/bin/python" -m pip install --disable-pip-version-check \
  --no-deps cmake==3.31.6
cmake="$scratch/tools/bin/cmake"
"$cmake" --version
"$cmake" -S "$vendor/mlx" -B "$scratch/build" \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_OSX_DEPLOYMENT_TARGET=14.0 \
  -DMLX_BUILD_METAL=ON -DMLX_METAL_JIT=OFF \
  -DMLX_BUILD_TESTS=OFF -DMLX_BUILD_EXAMPLES=OFF \
  -DMLX_BUILD_BENCHMARKS=OFF -DMLX_BUILD_PYTHON_BINDINGS=OFF \
  -DMLX_BUILD_PYTHON_STUBS=OFF -DFETCHCONTENT_FULLY_DISCONNECTED=ON \
  -DFETCHCONTENT_SOURCE_DIR_METAL_CPP="$vendor/metal-cpp" \
  -DFETCHCONTENT_SOURCE_DIR_JSON="$vendor/json" \
  -DFETCHCONTENT_SOURCE_DIR_FMT="$vendor/fmt"
"$cmake" --build "$scratch/build" --target mlx-metallib --parallel 8

artifact="$scratch/build/mlx/backend/metal/kernels/mlx.metallib"
if [[ ! -f "$artifact" || ! -s "$artifact" ]]; then
  echo "Expected nonempty MLX metallib was not produced: $artifact" >&2
  exit 1
fi

size="$(/usr/bin/stat -f '%z' "$artifact")"
digest="$(/usr/bin/shasum -a 256 "$artifact")"
digest="${digest%% *}"
printf 'MLX metallib path: %s\n' "$artifact"
printf 'MLX metallib size: %s bytes\n' "$size"
printf 'MLX metallib SHA-256: %s\n' "$digest"
printf 'MLX_METAL_PATH=%s\n' "$artifact" >> "$GITHUB_ENV"
