#!/usr/bin/env bash
# check_sovereign_redaction.sh
#
# Enforce the Qinao SDK's "control plane public, verdict machinery
# private" discipline (see dazzling-weaving-plum plan §3.2 and §6).
#
# This script emits the QinaoRuntimeSDK symbol graph and scans the
# *public* declarations across every Qinao module for forbidden
# substrate-machinery tokens. Internal verdict engines, token
# authorities, sentinels, audit ledgers, etc. are allowed to be used
# privately inside Qinao modules — they just must not appear in any
# public symbol's declaration fragment.
#
# Also scans the README (when present) for the same token set.

set -euo pipefail

swift_backend_args=()
case "${QINAO_SWIFT_BUILD_SYSTEM-default}" in
  default) ;;
  native) swift_backend_args=(--build-system native) ;;
  *)
    echo "check_sovereign_redaction: QINAO_SWIFT_BUILD_SYSTEM must be default or native" >&2
    exit 2
    ;;
esac

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PKG_DIR="$ROOT/QinaoRuntimeSDK"

if [[ ! -d "$PKG_DIR" ]]; then
  echo "check_sovereign_redaction: $PKG_DIR not found" >&2
  exit 1
fi

cd "$PKG_DIR"

# M173 — use a per-invocation tmpdir so two parallel CI jobs on the
# same host don't race on a shared `/tmp/qinao_symbolgraph.log`.
SYMBOLGRAPH_LOG="$(mktemp -t qinao_symbolgraph.XXXXXX)"
trap 'rm -f "$SYMBOLGRAPH_LOG"' EXIT

# Generate a fresh symbol graph so stale builds can't mask a regression.
swift package ${swift_backend_args[@]+"${swift_backend_args[@]}"} dump-symbol-graph >"$SYMBOLGRAPH_LOG" 2>&1 || {
  echo "check_sovereign_redaction: symbol graph emission failed" >&2
  cat "$SYMBOLGRAPH_LOG" >&2
  exit 1
}

SYMBOL_DIR="$(ls -d "$PKG_DIR"/.build/*/symbolgraph 2>/dev/null | head -n 1 || true)"
if [[ -z "$SYMBOL_DIR" ]]; then
  echo "check_sovereign_redaction: no symbolgraph directory emitted" >&2
  exit 1
fi

export SYMBOL_DIR
export README_PATH="$PKG_DIR/README.md"

python3 - <<'PY'
import glob
import json
import os
import sys

FORBIDDEN = [
    # Internal L14 modules — names must never surface in Qinao's public API.
    "IntegritySentinel",
    "VerdictEngine",
    "SovereignLockManager",
    "TokenAuthority",
    "AuditLedger",
    "ContaminationGuard",
    "PrivilegeArbiter",
    "SnapshotManager",
    "StubRenderer",
    # Decision-plane nouns and brand-internal code names.
    "BlackRing",
    "EBRAIN",
    "EBrain",
    "Verdict",
    "Sentinel",
    # Chinese internal code names from the design docs.
    "宿纹",
    "玄戒",
]

# M331 (chapter 七十七) — per-symbol allowlist for `FORBIDDEN`
# tokens. Some Qinao *public* symbols intentionally use these
# tokens because they refer to advisory-only / multi-agent
# concepts that are NOT the L14 internal sovereign machinery.
# Without this exception layer, the boundary check has been in
# chronic FAILED state since pre-M298 (visible to any caller of
# `bash scripts/check_qinao_import_boundaries.sh`). The
# `FORBIDDEN` blacklist remains the safety net for *new* leaks;
# this allowlist documents the deliberate, design-reviewed
# exceptions:
#
#   - `Verdict` in QinaoSeats / QinaoLoopSeats refers to
#     `SeatVerdict` (M292.x), the multi-agent advisory-vote
#     value type. It is NOT `BASSovereignVerdict` (L14 audit
#     decision). The two concepts are orthogonal: a SeatVerdict
#     is one of many inputs that may inform the single
#     BASSovereignVerdict the runtime ultimately ships.
#   - `Sentinel` in QinaoSeats / QinaoLoopSeats refers to the
#     `sovereignSentinel` seat (a read-only watcher in the
#     9-seat fabric). It is NOT `IntegritySentinel` (L14
#     internal verifier module). The seat name was chosen for
#     its semantic clarity; renaming would break M292-M329
#     callers.
#
# Format: each FORBIDDEN token may carry an optional dict of
# {"modules": {...}} listing modules where the token is
# permitted in declarations. A token without an entry here
# remains globally forbidden.
FORBIDDEN_TOKEN_ALLOWLIST = {
    "Verdict": {
        "modules": {"QinaoSeats", "QinaoLoopSeats"},
    },
    "Sentinel": {
        "modules": {"QinaoSeats", "QinaoLoopSeats"},
    },
}

# M173 — structural whitelist. The blacklist above catches obvious
# leaks; the whitelist below catches NEW internal names a future
# engineer might introduce (e.g. "Crucible", "DarkRing"). We
# require every public Qinao symbol whose declaration mentions a
# bare type name to either:
#   * use a Qinao-prefixed name, or
#   * be a known stdlib / Foundation / well-known interop type.
#
# Internal substrate types must reach the public surface only via
# Qinao-prefixed mirrors / typealiases.
PUBLIC_TYPE_WHITELIST_PREFIXES = (
    "Qinao",        # Qinao's own types
    "Swift.",       # stdlib
    "Foundation.",  # Foundation (Date, Data, URL, ...)
    "_Concurrency.", "Dispatch.",
)
PUBLIC_TYPE_WHITELIST_LITERALS = {
    # Stdlib value types that often appear without a module prefix
    # in declaration fragments. Keep this set small and explicit.
    "Bool", "Int", "Int8", "Int16", "Int32", "Int64",
    "UInt", "UInt8", "UInt16", "UInt32", "UInt64",
    "Float", "Double", "String", "Substring",
    "Date", "Data", "UUID", "URL", "TimeInterval",
    "Array", "Dictionary", "Set", "Optional", "Result",
    "Sendable", "Equatable", "Hashable", "Codable",
    "Decodable", "Encodable", "Comparable", "CustomStringConvertible",
    "Error", "AnyObject", "Any", "Self", "Void", "Never",
    "Encoder", "Decoder", "KeyedDecodingContainer",
    "AsyncStream", "AsyncSequence", "Task", "TaskGroup",
    "ContinuousClock", "SuspendingClock", "Duration", "Instant",
    "ClosedRange", "Range",
    # Project-local types that the redaction blacklist doesn't
    # forbid AND are intentionally exported under their own name.
    "BASBudgetFrame",       # L1 budget type — re-exported by design
    "BASRenderFrame",       # L12 surface aggregator — same
    "BASSovereignFrame",    # L14 §5.1 aggregator — same
    "BASThermalGuardLevel", "BASMaintenanceClass",
    "BASEBrainRunMode", "BASRuntimePrecisionProfile",
    "BASDeviceRoute", "BASLeaseLifeCoordinator",
    "BASSurfaceDecision", "BASSurfaceDisclosure",
    "BASSurfaceMode", "BASSurfaceAgency",
    "BASSurfaceSubstitute", "BASCognitiveLayer",
    "BASObservationCoverageSummary",
    "BASObservationReconciliationReport",
    "BASContextFrame", "BASDecomposeFrame",
    "BASMemoryBundle", "BASThoughtFrame", "BASUpdateTicket",
    "BASNeuralOrganMap", "BASRenderedOutput",
    "BASCandidateFrontier", "BASJurisdictionMap",
    "BASContaminationLineage", "BASMirrorDraft",
    "BASRiskCard", "BASMemorySensitivity",
    "BASEvolutionPromotionGate", "BASShadowTrialLedger",
    "BASShadowTrialLedgerEntry",
    "BASInMemoryShadowTrialLedger",
    # M175 — the L13 evolution-furnace types
    # (BASExperienceCandidate / BASShadowTrialRecord /
    # BASEvolutionSeal / BASRetractionOrder) are now exposed via
    # QinaoFurnace-prefixed typealiases. The redaction scanner
    # sees the Qinao-prefixed names; the substrate types never
    # appear in declaration fragments. Whitelist entries
    # removed.
    # L5 host constitution leaks — QinaoHost accepts/returns
    # these directly. M175 to add Qinao mirrors.
    "BASHostCandidatePipeline", "BASHostConstitution",
    "BASHostConstitutionVault", "BASHostVersionTree",
    "BASHostChangeCandidate",
    # L8 memory enum leaks — QinaoMemory.AdmitRequest/Receipt
    # carry these through. M175 to mirror.
    "BASMemoryKind", "BASMemoryScope", "BASMemoryTier",
    "BASGovernedMemory",
    # L1 lifecycle observability types — QinaoLifecycle returns
    # these on its `currentReading()` / `lung*()` accessors.
    # Considered part of the L1 public contract (M66 design).
    "BASBreathScheduler", "BASComputeTierThermalSnapshot",
    "BASLeaseLifeObservationBundle", "BASLungStateAccumulator",
    "BASThermalTwin",
    # M9 audit observation primitive — QinaoSovereignControlPlane.
    # auditTurn(observations:) overload accepts the substrate
    # primitive form for parity with substrate test fixtures.
    "BASSovereignTurnObservations",
    # World-prior types intentionally re-exported via
    # QinaoWorldPrior. Qinao* wrappers handle the brand surface
    # but the BAS shapes are accepted today as L4 public contract.
    "BASWorldPriorClaim", "BASWorldPriorAxiom",
    "BASWorldPriorTemplate", "BASWorldPriorEvidence",
    # M331 (chapter 七十七) — M295.x training-boundary +
    # curriculum + reviewer types. Canonical public surface per
    # Doctrine A (private experience never enters L2 weights).
    # Qinao re-exports these directly because wrapping would
    # obscure the contract: the BAS types ARE the audit-grade
    # training-pipeline / reviewer / curriculum vocabulary.
    # Adding Qinao-prefixed mirrors would require parallel
    # maintenance with no behavioural improvement; the intent
    # is for hosts to grep one canonical name set across both
    # substrate audit logs and SDK callers. Closes the chronic
    # FAILED-state lint gap that existed since pre-M298 (246
    # structural violations across 42 distinct types).
    "BASWorldPriorTemplateAcceptance",
    "BASWorldPriorTemplateAcceptanceBatchReport",
    "BASWorldPriorTemplateEnvelope",
    "BASWorldPriorTemplateProvenance",
    "BASWorldPriorTemplateProvenanceGate",
    "BASWorldPriorTemplateAttestation",
    "BASWorldPriorTemplateAttestationGate",
    "BASWorldPriorTemplateAttestationIssue",
    "BASWorldPriorTemplateAuthoringAction",
    "BASWorldPriorTemplateAuthoringPolicy",
    "BASWorldPriorTemplateAuthoringSession",
    "BASWorldPriorTemplateAuthoringStage",
    "BASWorldPriorTemplateAuthoringTransition",
    "BASWorldPriorAuthoringBatchReport",
    "BASWorldPriorAuthoringProgressReport",
    "BASWorldPriorTrainingExporter",
    "BASWorldPriorTrainingPipelineFilter",
    "BASWorldPriorStarterCurriculum",
    "BASWorldPriorProductionCurriculum",
    "BASWorldPriorProductionCurriculumEntry",
    "BASWorldPriorProductionCurriculumWalkthrough",
    "BASWorldPriorReviewerBatch",
    "BASWorldPriorReviewerBatchApplier",
    "BASWorldPriorReviewerBatchFormatter",
    "BASWorldPriorReviewerBatchItem",
    "BASWorldPriorReviewerBatchResult",
    "BASWorldPriorReviewerDashboard",
    "BASWorldPriorReviewerDashboardFormatter",
    "BASWorldPriorReviewerDashboardPerDomain",
    "BASWorldPriorReviewerDashboardSummary",
    "BASWorldPriorReviewerDecision",
    "BASWorldPriorReviewerDecisionRecord",
    "BASWorldPriorReviewChecklistItem",
    "BASWorldPriorAIChecklistResult",
    "BASWorldPriorAIDraftHelper",
    "BASWorldPriorAIPersona",
    "BASWorldPriorAIPersonaPanelReview",
    "BASWorldPriorAIPersonaReview",
    "BASWorldPriorAIPersonaReviewer",
    "BASWorldPriorAIRecommendation",
    "BASWorldPriorAIReviewAdvisory",
    "BASWorldPriorAIReviewReport",
    "BASWorldPriorAIReviewerSimulation",
    # Substrate convenience types that surface today; audit each
    # addition individually before extending this set.
    "BASOrganRegistryEndpoint", "BASOrganAdapter",
    "BASMemoryGovernance", "BASMemoryTierFilter",
    "BASMemoryAtom", "BASMemoryHorizonPersistencePolicy",
    "BASRollbackAnchor", "BASLungState", "BASBudgetThermalGuard",
    "BASCritiqueBundle",
    "BASIntegrityWeaveFrame",
    "BASTriSelfScore", "BASTriSelfVoice",
}

symbol_dir = os.environ["SYMBOL_DIR"]
readme_path = os.environ["README_PATH"]

violations = []

# ---- 1. Public symbol graph scan -------------------------------------
qinao_graphs = sorted(glob.glob(os.path.join(symbol_dir, "Qinao*.symbols.json")))
if not qinao_graphs:
    print("check_sovereign_redaction: no Qinao*.symbols.json found", file=sys.stderr)
    sys.exit(1)

import re

# Identifiers in declaration fragments. We tokenize on
# non-identifier chars and check each `BAS*` identifier against
# the whitelist; anything not whitelisted is a structural leak
# (a substrate-internal type appearing on the public surface).
BAS_IDENTIFIER_RE = re.compile(r"\bBAS[A-Za-z0-9_]+\b")

for path in qinao_graphs:
    module = os.path.basename(path).removesuffix(".symbols.json")
    if module.endswith("PackageTests"):
        continue
    data = json.load(open(path))
    for sym in data.get("symbols", []):
        if sym.get("accessLevel") != "public":
            continue
        # M175 — typealias declarations are the controlled
        # `BAS* → Qinao*` re-export seam; the substrate name is
        # referenced exactly once (the alias body) and never
        # appears in any METHOD signature. Skip typealias
        # symbols here — the structural concern is a substrate
        # type leaking into method declarations, not the
        # typealias itself.
        kind = sym.get("kind", {}).get("identifier", "")
        if kind == "swift.typealias":
            continue
        decl = "".join(f.get("spelling", "")
                       for f in sym.get("declarationFragments", []))
        # 1. Forbidden-token blacklist (catches obvious leaks).
        # M331 — per-symbol allowlist (`FORBIDDEN_TOKEN_ALLOWLIST`)
        # short-circuits when the token is permitted in this
        # module's deliberate public surface (e.g. `Verdict` in
        # QinaoSeats refers to advisory `SeatVerdict`, NOT L14's
        # `BASSovereignVerdict`).
        for tok in FORBIDDEN:
            if tok in decl:
                allow_entry = FORBIDDEN_TOKEN_ALLOWLIST.get(tok, {})
                allowed_modules = allow_entry.get("modules", set())
                if module in allowed_modules:
                    continue
                title = sym.get("names", {}).get("title", "?")
                violations.append(
                    f"[public-api] {module}:{title} contains forbidden token "
                    f"'{tok}' in declaration:\n    {decl}")
        # 2. M173 — structural whitelist on `BAS*` identifiers.
        # Catches NEW internal substrate types a future engineer
        # might leak that are not on the FORBIDDEN list yet.
        title = sym.get("names", {}).get("title", "?")
        for match in BAS_IDENTIFIER_RE.findall(decl):
            if match not in PUBLIC_TYPE_WHITELIST_LITERALS:
                violations.append(
                    f"[structural] {module}:{title} references "
                    f"non-whitelisted substrate type '{match}'. "
                    f"Either add a Qinao-prefixed mirror, or add "
                    f"'{match}' to PUBLIC_TYPE_WHITELIST_LITERALS "
                    f"in scripts/check_sovereign_redaction.sh after "
                    f"reviewing whether the type is intentional "
                    f"public surface.\n    declaration: {decl}")

# ---- 2. README scan --------------------------------------------------
if os.path.exists(readme_path):
    with open(readme_path, encoding="utf-8") as fh:
        for lineno, line in enumerate(fh, 1):
            for tok in FORBIDDEN + ["BehavioralAISubstrate", "BAS"]:
                if tok in line:
                    # Allow attribution-style references at most in a
                    # "License / Credits" footer. For the strict check
                    # used on QinaoRuntimeSDK/README.md, even that is
                    # forbidden — the README is the brand surface.
                    violations.append(
                        f"[readme] {readme_path}:{lineno}: contains forbidden "
                        f"token '{tok}'\n    {line.rstrip()}")

if violations:
    print("Redaction violations found (Qinao SDK public surface):",
          file=sys.stderr)
    for v in violations:
        print("  " + v, file=sys.stderr)
    sys.exit(1)

print(f"check_sovereign_redaction: clean across "
      f"{len([p for p in qinao_graphs if not p.endswith('PackageTests.symbols.json')])} "
      f"Qinao modules.")
PY
