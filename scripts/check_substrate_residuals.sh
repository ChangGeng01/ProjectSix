#!/usr/bin/env bash
# DEPRECATED SHIM (2026-07-12): this parent-repo path collided with
# BehavioralAISubstrate/scripts/check_substrate_residuals.sh (the residuals GATE:
# print-count + density, called by pre-commit-gates.sh) while doing a DIFFERENT job
# (residual-MARKER regex scan). The marker scan now lives at its own unambiguous name;
# this shim only delegates so existing tooling keeps working.
exec "$(dirname "$0")/check_substrate_residual_markers.sh" "$@"
