#!/usr/bin/env bash

set -euo pipefail

if [[ "$#" != 1 ]] || [[ "$1" != "bas" && "$1" != "qinao" ]]; then
  echo "usage: run_ci_swift_tests.sh bas|qinao" >&2
  exit 2
fi

mode="$1"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
: "${RUNNER_TEMP:?run_ci_swift_tests: RUNNER_TEMP is required}"

if [[ "$mode" == "bas" ]]; then
  package_dir="$ROOT"
  test_cmd=(swift test --build-system native --package-path BehavioralAISubstrate)
else
  package_dir="$ROOT/QinaoRuntimeSDK"
  test_cmd=(swift test --build-system native)
fi

diag="$(mktemp -d "$RUNNER_TEMP/$mode-xctest-diagnostics.XXXXXX")"
marker="$diag/started.marker"
: > "$marker"
cd "$package_dir"

set +e
"${test_cmd[@]}" 2>&1 | tee "$diag/primary.log"
statuses=("${PIPESTATUS[@]}")
primary_rc=${statuses[0]}
capture_rc=${statuses[1]}
if ! printf 'primary=%s\nprimary_capture=%s\n' "$primary_rc" "$capture_rc" > "$diag/exits.txt"; then
  echo "run_ci_swift_tests: could not write $diag/exits.txt" >&2
fi

if [[ "$primary_rc" == 0 ]]; then
  exit "$capture_rc"
fi

set +e
"${test_cmd[@]}" --skip-build --disable-swift-testing 2>&1 \
  | tee "$diag/full-xctest-retained-products.log"
statuses=("${PIPESTATUS[@]}")
probe_rc=${statuses[0]}
probe_capture_rc=${statuses[1]}
if ! printf 'probe=%s\nprobe_capture=%s\n' "$probe_rc" "$probe_capture_rc" >> "$diag/exits.txt"; then
  echo "run_ci_swift_tests: could not append probe exits to $diag/exits.txt" >&2
fi

report_dir="$diag/crash-reports"
if ! mkdir -p "$report_dir"; then
  echo "run_ci_swift_tests: could not create crash-report directory $report_dir" >&2
  exit "$primary_rc"
fi
if [[ -z "${HOME:-}" ]]; then
  echo "run_ci_swift_tests: HOME is unavailable for crash-report collection" >&2
  exit "$primary_rc"
fi
report_root="$HOME/Library/Logs/DiagnosticReports"
reports=()
poll_rc=0
if [[ -d "$report_root" ]]; then
  for poll in 1 2 3 4 5; do
    reports=()
    candidates="$report_dir/poll-$poll-candidates.bin"
    find "$report_root" -type f -newer "$marker" \
      \( -name 'xctest*.ips' -o -name 'xctest*.crash' \
         -o -name '*PackageTests*.ips' -o -name '*PackageTests*.crash' \) \
      -print0 > "$candidates"
    poll_rc=$?
    if [[ "$poll_rc" != 0 ]]; then
      break
    fi
    while IFS= read -r -d '' report; do
      reports+=("$report")
    done < "$candidates"
    if [[ "$poll_rc" != 0 || "${#reports[@]}" != 0 ]]; then
      break
    fi
    if [[ "$poll" != 5 ]]; then
      sleep 2
      sleep_rc=$?
      if [[ "$sleep_rc" != 0 ]]; then
        if ! printf 'sleep failed with exit %s\n' "$sleep_rc" \
          >> "$report_dir/collection-errors.txt"; then
          echo "run_ci_swift_tests: could not record sleep failure" >&2
        fi
        break
      fi
    fi
  done
fi

if [[ "$poll_rc" != 0 ]]; then
  if ! printf 'report polling failed with exit %s\n' "$poll_rc" \
    >> "$report_dir/collection-errors.txt"; then
    echo "run_ci_swift_tests: could not record report polling failure" >&2
  fi
elif [[ "${#reports[@]}" == 0 ]]; then
  if ! printf 'No matching new XCTest crash report was found.\n' \
    > "$report_dir/no-report.txt"; then
    echo "run_ci_swift_tests: could not write $report_dir/no-report.txt" >&2
  fi
else
  index=0
  for report in "${reports[@]}"; do
    index=$((index + 1))
    if ! printf '%s\n' "$report" >> "$report_dir/selected-paths.txt"; then
      echo "run_ci_swift_tests: could not write $report_dir/selected-paths.txt" >&2
    fi
    destination="$(printf '%s/%03d-%s' "$report_dir" "$index" "${report##*/}")"
    cp "$report" "$destination"
    copy_rc=$?
    if [[ "$copy_rc" != 0 ]]; then
      if ! printf 'copy failed with exit %s for %s\n' "$copy_rc" "$report" \
        >> "$report_dir/collection-errors.txt"; then
        echo "run_ci_swift_tests: could not record copy failure for $report" >&2
      fi
    fi
  done
fi

exit "$primary_rc"
