from __future__ import annotations

import os
import re
import subprocess
import tempfile
import unittest
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[1]
ORDINARY_WORKFLOW = PROJECT_ROOT / ".github/workflows/test.yml"
PROTECTED_WORKFLOW = (
    PROJECT_ROOT / ".github/workflows/qinao-wave-admission.yml"
)

CHECKOUT_ACTION = "actions/checkout"
PINNED_CHECKOUT = "11bd71901bbe5b1630ceea73d27597364c9af683"
PINNED_UPLOAD_ARTIFACT = "ea165f8d65b6e75b540449e92b4886f43607fa02"
PINNED_DOWNLOAD_ARTIFACT = "d3f86a106a0bac45b974a628896c90dbdf5c8093"
PROTECTED_REF = "refs/heads/qinao-admission-bootstrap-v1"
PROTECTED_REPORT_TOOL = (
    '/usr/bin/python3 "/dev/fd/$repository_runner_fd" report'
)
PROTECTED_ADMIT_TOOL = '"/dev/fd/$external_verifier_fd" admit-wave'
PROTECTED_VERIFY_TOOL = (
    '/usr/bin/python3 "/dev/fd/$repository_runner_fd" verify-receipt'
)

QINAO_MODULES = (
    "scripts.test_check_qinao_owner_ledger",
    "scripts.test_run_nonempty_swift_filter",
    "scripts.test_run_qinao_wave_admission",
    "scripts.test_run_qinao_k4_ios27_platform_spike",
    "scripts.test_qinao_admission_canonical_vectors",
    "scripts.test_qinao_plan_remediation",
    "scripts.test_test_workflow_owner_ledger",
)
FLOOR_UNIT_MODULE = "BehavioralAISubstrate.scripts.test_check_ios27_floor"
FLOOR_CHECK = "BehavioralAISubstrate/scripts/check-ios27-floor.sh"
ORDINARY_UNIT_JOB = "qinao-gates"
ORDINARY_FLOOR_JOB = "qinao-ios27-floor"
XCODE_27_ASSERTION = 'test "${xcode_version%%.*}" = "27"'

REPORT_ARGUMENTS = (
    '--root "$GITHUB_WORKSPACE"',
    '--bundle "$QINAO_CURRENT_WAVE_BUNDLE"',
    '--source-selection "$QINAO_SOURCE_SELECTION"',
    '--trust-root "$QINAO_ADMISSION_TRUST_ROOT"',
    '--previous-receipt "$QINAO_PREVIOUS_ADMISSION_RECEIPT"',
    '--candidate-tree "$QINAO_CANDIDATE_TREE"',
    '--unsigned-report "$QINAO_UNSIGNED_ADMISSION_REPORT"',
)
VERIFY_ARGUMENTS = (
    '--root "$GITHUB_WORKSPACE"',
    '--bundle "$QINAO_CURRENT_WAVE_BUNDLE"',
    '--source-selection "$QINAO_SOURCE_SELECTION"',
    '--trust-root "$QINAO_ADMISSION_TRUST_ROOT"',
    '--previous-receipt "$QINAO_PREVIOUS_ADMISSION_RECEIPT"',
    '--candidate-tree "$QINAO_CANDIDATE_TREE"',
    '--receipt "$QINAO_CURRENT_ADMISSION_RECEIPT"',
)
ADMIT_ARGUMENTS = (
    '--report "$QINAO_UNSIGNED_ADMISSION_REPORT"',
    '--bundle "$QINAO_CURRENT_WAVE_BUNDLE"',
    '--source-selection "$QINAO_SOURCE_SELECTION"',
    '--previous-receipt "$QINAO_PREVIOUS_ADMISSION_RECEIPT"',
    '--repository "$GITHUB_WORKSPACE"',
    '--candidate-tree "$QINAO_CANDIDATE_TREE"',
    '--trust-root "$QINAO_ADMISSION_TRUST_ROOT"',
    '--signing-provider "$QINAO_WAVE_ADMISSION_SIGNING_PROVIDER"',
    (
        '--signing-provider-sha256 '
        '"$QINAO_WAVE_ADMISSION_SIGNING_PROVIDER_SHA256"'
    ),
    '--receipt "$QINAO_CURRENT_ADMISSION_RECEIPT"',
)

ORDINARY_EXTERNAL_VARIABLES = (
    "QINAO_EXTERNAL_REPLAY_INPUTS_READY",
    "QINAO_CURRENT_WAVE_BUNDLE",
    "QINAO_SOURCE_SELECTION",
    "QINAO_ADMISSION_TRUST_ROOT",
    "QINAO_PREVIOUS_ADMISSION_RECEIPT",
    "QINAO_EXTERNAL_PREREQUISITES",
    "QINAO_PRIOR_ADMISSION_RECEIPTS",
    "QINAO_RUNTIME_ENTRY_PREDECESSOR",
    "QINAO_UNSIGNED_ADMISSION_REPORT",
)
W6_CONTEXT_ENVIRONMENT_VARIABLES = (
    "QINAO_PRIOR_ADMISSION_RECEIPTS",
    "QINAO_RUNTIME_ENTRY_PREDECESSOR",
)
PREREQUISITE_ARGUMENTS = (
    '${prerequisite_args[@]+"${prerequisite_args[@]}"}'
)
PRIOR_RECEIPT_ARGUMENTS = (
    '${prior_receipt_args[@]+"${prior_receipt_args[@]}"}'
)
RUNTIME_ENTRY_ARGUMENTS = (
    '${runtime_entry_args[@]+"${runtime_entry_args[@]}"}'
)
W6_CONTEXT_PARSER_TOKENS = (
    "expected_prior_wave_slice_ids=(",
    "w6.runtime.observation-values",
    "w6.semantic.audit-schema",
    "w6.runtime.audit-envelope-freeze",
    "w6.semantic.coordinator-behavior",
    "w6.runtime.integration-population",
    "canonical_external_path() {",
    "path == root or root in path.parents",
    "prior_receipt_args=()",
    "prior_receipt_bindings=()",
    "prior_receipt_fds=()",
    'while IFS= read -r prior_receipt; do',
    'test -n "$prior_receipt"',
    'test "$prior_wave_slice_id" = '
    '"${expected_prior_wave_slice_ids[$prior_receipt_index]}"',
    'case "$prior_receipt_path" in /*) ;; *) exit 1 ;; esac',
    'case "$prior_receipt_index" in',
    '0) prior_receipt_fd=20; exec 20<"$prior_receipt_path" ;;',
    '4) prior_receipt_fd=24; exec 24<"$prior_receipt_path" ;;',
    'prior_receipt_metadata="$(/usr/bin/python3 -c '
    '\'import os,stat,sys; value=os.fstat(int(sys.argv[1]));',
    "read -r prior_receipt_binding prior_receipt_link_count "
    "prior_receipt_mode prior_receipt_regular",
    'test "$prior_receipt_path_binding" = "$prior_receipt_binding"',
    'test "$prior_receipt_link_count" -eq 1',
    'test "$prior_receipt_mode" = 600',
    'test "$prior_receipt_regular" -eq 1',
    'test "$seen_prior_receipt_binding" != "$prior_receipt_binding"',
    'prior_receipt_args+=(--prior-admission-receipt '
    '"${prior_wave_slice_id}=/dev/fd/${prior_receipt_fd}")',
    'runtime_entry_args=()',
    '*$\'\\n\'*|*$\'\\r\'*|*=*) exit 1 ;;',
    'case "$QINAO_RUNTIME_ENTRY_PREDECESSOR" in /*) ;; *) exit 1 ;; esac',
    'runtime_entry_fd=25',
    'exec 25<"$runtime_entry_path"',
    'runtime_entry_metadata="$(/usr/bin/python3 -c '
    '\'import os,stat,sys; value=os.fstat(int(sys.argv[1]));',
    "read -r runtime_entry_binding runtime_entry_link_count "
    "runtime_entry_mode runtime_entry_regular",
    'test "$runtime_entry_path_binding" = "$runtime_entry_binding"',
    'test "$runtime_entry_link_count" -eq 1',
    'test "$runtime_entry_mode" = 600',
    'test "$runtime_entry_regular" -eq 1',
    'test "$prior_receipt_binding" != "$runtime_entry_binding"',
    'runtime_entry_args+=(--runtime-entry-predecessor '
    '"/dev/fd/$runtime_entry_fd")',
)
PROTECTED_INPUT_ENVIRONMENT = {
    "candidate_commit": "QINAO_CANDIDATE_COMMIT",
    "candidate_tree": "QINAO_CANDIDATE_TREE",
    "current_wave_bundle": "QINAO_CURRENT_WAVE_BUNDLE",
    "source_selection": "QINAO_SOURCE_SELECTION",
    "trust_root": "QINAO_ADMISSION_TRUST_ROOT",
    "previous_receipt": "QINAO_PREVIOUS_ADMISSION_RECEIPT",
    "external_prerequisites": "QINAO_EXTERNAL_PREREQUISITES",
}
PROTECTED_INPUTS = tuple(PROTECTED_INPUT_ENVIRONMENT)
PROTECTED_ENVIRONMENT_VARIABLES = (
    "QINAO_EXTERNAL_ADMISSION_VERIFIER",
    "QINAO_EXTERNAL_ADMISSION_VERIFIER_SHA256",
    "QINAO_WAVE_ADMISSION_SIGNING_PROVIDER",
    "QINAO_WAVE_ADMISSION_SIGNING_PROVIDER_SHA256",
)


def _read(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except FileNotFoundError:
        return ""


def _compact(value: str) -> str:
    return " ".join(value.split())


def _top_level_block(text: str, key: str) -> str:
    match = re.search(
        rf"(?ms)^{re.escape(key)}:\s*\n(.*?)(?=^[A-Za-z][A-Za-z0-9_-]*:\s*$|\Z)",
        text,
    )
    return match.group(1) if match else ""


def _job_block(text: str, job_id: str) -> str:
    match = re.search(
        rf"(?ms)^  {re.escape(job_id)}:\s*\n(.*?)(?=^  [A-Za-z0-9_-]+:\s*$|\Z)",
        _top_level_block(text, "jobs"),
    )
    return match.group(1) if match else ""


def _step_blocks(job: str) -> list[str]:
    starts = list(re.finditer(r"(?m)^      - (?:name|uses):", job))
    blocks: list[str] = []
    for index, start in enumerate(starts):
        end = starts[index + 1].start() if index + 1 < len(starts) else len(job)
        blocks.append(job[start.start() : end])
    return blocks


def _checkout_blocks(text: str) -> list[tuple[str, str]]:
    matches = list(
        re.finditer(
            rf"(?m)^(?P<indent>\s*)- uses: {re.escape(CHECKOUT_ACTION)}@"
            r"(?P<revision>[^\s]+)\s*$",
            text,
        )
    )
    blocks: list[tuple[str, str]] = []
    lines = text.splitlines(keepends=True)
    offsets: list[int] = []
    cursor = 0
    for line in lines:
        offsets.append(cursor)
        cursor += len(line)
    for match in matches:
        indentation = len(match.group("indent"))
        end = len(text)
        for offset, line in zip(offsets, lines):
            if offset <= match.start():
                continue
            if re.match(rf"^\s{{{indentation}}}- (?:name|uses):", line):
                end = offset
                break
        blocks.append((match.group("revision"), text[match.start() : end]))
    return blocks


def _require(errors: list[str], condition: bool, diagnostic: str) -> None:
    if not condition:
        errors.append(diagnostic)


def _unique_step_containing(job: str, token: str) -> str:
    matches = [step for step in _step_blocks(job) if token in step]
    return matches[0] if len(matches) == 1 else ""


def validate_ordinary_workflow(text: str) -> list[str]:
    errors: list[str] = []
    job = _job_block(text, ORDINARY_UNIT_JOB)
    floor_job = _job_block(text, ORDINARY_FLOOR_JOB)
    _require(errors, bool(job), "ordinary qinao-gates job")
    _require(errors, bool(floor_job), "ordinary dedicated Xcode 27 floor job")
    _require(
        errors,
        re.search(r"(?m)^    runs-on:\s*macos-latest\s*$", job)
        is not None,
        "ordinary unit job uses macos-latest",
    )
    _require(
        errors,
        re.search(r"(?m)^    runs-on:\s*xcode-27\s*$", floor_job)
        is not None,
        "ordinary floor job uses Xcode 27 runner",
    )
    _require(
        errors,
        re.search(
            rf"(?m)^    needs:\s*{re.escape(ORDINARY_UNIT_JOB)}\s*$",
            floor_job,
        )
        is not None,
        "ordinary floor job depends on unit job",
    )
    _require(
        errors,
        re.search(
            r"(?ms)^    permissions:\s*\n      contents:\s*read\s*$",
            job,
        )
        is not None,
        "ordinary read-only contents",
    )
    _require(
        errors,
        re.search(
            r"(?ms)^    permissions:\s*\n      contents:\s*read\s*$",
            floor_job,
        )
        is not None,
        "ordinary floor read-only contents",
    )
    _require(
        errors,
        "id-token:" not in job
        and "id-token:" not in floor_job
        and "environment:" not in job
        and "environment:" not in floor_job,
        "ordinary jobs have no admission authority",
    )

    checkouts = _checkout_blocks(text)
    _require(errors, bool(checkouts), "ordinary checkout present")
    _require(
        errors,
        bool(checkouts)
        and all(re.search(r"(?m)^\s+fetch-depth:\s*0\s*$", block) for _, block in checkouts),
        "ordinary checkout full history",
    )
    floor_checkouts = _checkout_blocks(floor_job)
    _require(
        errors,
        len(floor_checkouts) == 1,
        "ordinary floor has one checkout",
    )
    if len(floor_checkouts) == 1:
        floor_revision, floor_checkout = floor_checkouts[0]
        _require(
            errors,
            floor_revision == PINNED_CHECKOUT,
            "ordinary floor checkout is pinned",
        )
        _require(
            errors,
            "persist-credentials: false" in floor_checkout,
            "ordinary floor checkout does not persist credentials",
        )

    unit_step = _unique_step_containing(
        job,
        "scripts.test_run_qinao_wave_admission",
    )
    _require(errors, bool(unit_step), "ordinary unit step")
    _require(errors, "if:" not in unit_step, "ordinary unit step unconditional")
    _require(
        errors,
        "python3 -m unittest" in _compact(unit_step),
        "ordinary standard-library unittest",
    )
    for module in QINAO_MODULES:
        _require(
            errors,
            unit_step.count(module) == 1,
            f"ordinary module {module}",
        )

    _require(
        errors,
        FLOOR_UNIT_MODULE not in job and FLOOR_CHECK not in job,
        "ordinary unit job excludes Xcode 27 floor",
    )
    floor_unit_step = _unique_step_containing(
        floor_job,
        FLOOR_UNIT_MODULE,
    )
    _require(errors, bool(floor_unit_step), "ordinary floor unit step")
    _require(
        errors,
        bool(floor_unit_step) and "if:" not in floor_unit_step,
        "ordinary floor unit unconditional",
    )
    floor_check_step = _unique_step_containing(floor_job, FLOOR_CHECK)
    _require(errors, bool(floor_check_step), "ordinary floor local check")
    _require(
        errors,
        bool(floor_check_step) and "if:" not in floor_check_step,
        "ordinary floor local check unconditional",
    )
    toolchain_step = _unique_step_containing(floor_job, XCODE_27_ASSERTION)
    _require(
        errors,
        bool(toolchain_step)
        and "xcodebuild -version" in toolchain_step
        and "if:" not in toolchain_step,
        "ordinary floor asserts Xcode 27 toolchain",
    )

    report_step = _unique_step_containing(
        job,
        "scripts/run_qinao_wave_admission.py report",
    )
    compact_report = _compact(report_step)
    _require(errors, bool(report_step), "ordinary repository report step")
    _require(
        errors,
        "if: ${{ env.QINAO_EXTERNAL_REPLAY_INPUTS_READY == 'true' }}"
        in report_step,
        "ordinary report readiness guard",
    )
    _require(
        errors,
        'QINAO_CANDIDATE_TREE="$(git rev-parse HEAD^{tree})"'
        in report_step,
        "ordinary report candidate tree",
    )
    for argument in REPORT_ARGUMENTS:
        _require(
            errors,
            _compact(argument) in compact_report,
            f"ordinary report argument {argument}",
        )
    _require(
        errors,
        PREREQUISITE_ARGUMENTS in report_step,
        "ordinary dynamic external prerequisites",
    )
    for token in W6_CONTEXT_PARSER_TOKENS:
        _require(
            errors,
            _compact(token) in compact_report,
            f"ordinary strict W6 context parser token {token}",
        )
    _require(
        errors,
        re.search(r"\beval\b", report_step) is None,
        "ordinary W6 context parser does not eval configuration",
    )
    for binding in (
        (
            'prior_receipt_path="$(canonical_external_path '
            '"$prior_receipt_path" "$GITHUB_WORKSPACE")"'
        ),
        (
            'runtime_entry_path="$(canonical_external_path '
            '"$QINAO_RUNTIME_ENTRY_PREDECESSOR" "$GITHUB_WORKSPACE")"'
        ),
    ):
        _require(
            errors,
            _compact(binding) in compact_report,
            f"ordinary W6 context rejects repository origin {binding}",
        )
    for arguments, diagnostic in (
        (
            PRIOR_RECEIPT_ARGUMENTS,
            "ordinary replay prior-receipt forwarding",
        ),
        (
            RUNTIME_ENTRY_ARGUMENTS,
            "ordinary replay runtime-entry forwarding",
        ),
    ):
        _require(
            errors,
            report_step.count(arguments) == 1,
            diagnostic,
        )
    for variable in ORDINARY_EXTERNAL_VARIABLES:
        _require(
            errors,
            (
                f"{variable}: "
                f"${{{{ vars.{variable} }}}}"
            )
            in job,
            f"ordinary external variable {variable}",
        )
    _require(
        errors,
        unit_step
        and report_step
        and job.index(unit_step) < job.index(report_step),
        "ordinary unit then report order",
    )
    _require(
        errors,
        toolchain_step
        and floor_unit_step
        and floor_check_step
        and floor_job.index(toolchain_step)
        < floor_job.index(floor_unit_step)
        < floor_job.index(floor_check_step),
        "ordinary toolchain floor-unit floor-check order",
    )

    lowered = text.lower()
    forbidden = {
        "ordinary secrets": "secrets.",
        "ordinary private key": "private_key",
        "ordinary admit operation": "admit-wave",
        "ordinary receipt verification": "verify-receipt",
        "ordinary generic signing": "sign-evidence",
    }
    for diagnostic, token in forbidden.items():
        _require(errors, token not in lowered, diagnostic)
    _require(
        errors,
        "QINAO_WAVE_ADMISSION_SIGNING_PROVIDER" not in text,
        "ordinary signing provider",
    )
    return errors


def _validate_legacy_protected_privilege_separation(text: str) -> list[str]:
    """Validate that candidate execution and signing authority never coexist."""

    errors: list[str] = []
    top_permissions = _top_level_block(text, "permissions")
    _require(
        errors,
        "id-token: write" not in top_permissions,
        "top-level workflow permissions must not grant OIDC",
    )

    candidate_job = _job_block(text, "candidate-validation")
    privileged_job = _job_block(text, "admit-current-wave")
    _require(errors, bool(candidate_job), "unprivileged candidate-validation job")
    _require(errors, bool(privileged_job), "privileged admission job")

    _require(
        errors,
        re.search(r"(?m)^    runs-on:\s*xcode-27\s*$", candidate_job)
        is not None,
        "candidate validation uses ephemeral Xcode 27 runner",
    )
    _require(
        errors,
        re.search(
            r"(?ms)^    permissions:\s*\n"
            r"(?:      [^\n]+\n)*?"
            r"      contents:\s*read\s*$",
            candidate_job,
        )
        is not None,
        "candidate validation has read-only contents",
    )
    _require(
        errors,
        "id-token: write" not in candidate_job,
        "candidate validation has no OIDC",
    )
    _require(
        errors,
        "QINAO_WAVE_ADMISSION_SIGNING_PROVIDER" not in candidate_job,
        "candidate validation has no signing provider",
    )
    candidate_checkouts = _checkout_blocks(candidate_job)
    _require(
        errors,
        len(candidate_checkouts) == 1,
        "candidate validation has one pinned checkout",
    )
    if len(candidate_checkouts) == 1:
        revision, checkout = candidate_checkouts[0]
        _require(
            errors,
            revision == PINNED_CHECKOUT,
            "candidate validation checkout is pinned",
        )
        _require(
            errors,
            "ref: ${{ inputs.candidate_commit }}" in checkout,
            "candidate validation checks exact candidate",
        )
        _require(
            errors,
            re.search(
                r"(?m)^\s+persist-credentials:\s*false\s*$",
                checkout,
            )
            is not None,
            "candidate validation checkout does not persist credentials",
        )
    _require(
        errors,
        "python3 scripts/run_qinao_wave_admission.py report" in candidate_job,
        "candidate validation creates only the unsigned report",
    )
    _require(
        errors,
        FLOOR_CHECK in candidate_job,
        "candidate validation runs the real floor gate",
    )
    _require(
        errors,
        re.search(
            r"actions/upload-artifact@[0-9a-f]{40}",
            candidate_job,
        )
        is not None,
        "candidate validation uploads immutable artifacts with pinned action",
    )

    _require(
        errors,
        re.search(
            r"(?ms)^    permissions:\s*\n"
            r"(?:      [^\n]+\n)*?"
            r"      id-token:\s*write\s*$",
            privileged_job,
        )
        is not None,
        "privileged admission grants OIDC only at job scope",
    )
    _require(
        errors,
        re.search(
            r"(?m)^    environment:\s*qinao-admission\s*$",
            privileged_job,
        )
        is not None,
        "privileged admission retains protected environment",
    )
    _require(
        errors,
        not _checkout_blocks(privileged_job),
        "privileged admission never checks out candidate code",
    )
    for forbidden in (
        "python3 scripts/",
        "BehavioralAISubstrate/scripts/",
        "swift test",
        "xcodebuild",
        "--disable-sandbox",
    ):
        _require(
            errors,
            forbidden not in privileged_job,
            f"privileged admission does not execute candidate token {forbidden}",
        )
    _require(
        errors,
        re.search(
            r"actions/download-artifact@[0-9a-f]{40}",
            privileged_job,
        )
        is not None,
        "privileged admission downloads immutable artifacts with pinned action",
    )
    _require(
        errors,
        (
            "QINAO_ADMISSION_TRUST_ROOT_SHA256: "
            "${{ vars.QINAO_ADMISSION_TRUST_ROOT_SHA256 }}"
        )
        in privileged_job,
        "privileged admission pins expected trust-root digest",
    )
    _require(
        errors,
        (
            'shasum -a 256 "$QINAO_ADMISSION_TRUST_ROOT"'
            in privileged_job
            and '"$QINAO_ADMISSION_TRUST_ROOT_SHA256"' in privileged_job
        ),
        "privileged admission verifies expected trust-root digest",
    )
    _require(
        errors,
        (
            'shasum -a 256 "$QINAO_EXTERNAL_ADMISSION_VERIFIER"'
            in privileged_job
            and '"$QINAO_EXTERNAL_ADMISSION_VERIFIER_SHA256"' in privileged_job
        ),
        "privileged admission verifies expected external-verifier digest",
    )
    _require(
        errors,
        "QINAO_CANDIDATE_ARTIFACT_SHA256" in privileged_job,
        "privileged admission binds candidate artifact digest",
    )
    _require(
        errors,
        privileged_job.count(
            '"$QINAO_EXTERNAL_ADMISSION_VERIFIER"'
        )
        >= 1,
        "privileged admission executes only the pinned external verifier",
    )
    return errors


def _validate_legacy_protected_workflow(text: str) -> list[str]:
    errors: list[str] = []
    event_block = _top_level_block(text, "on")
    event_names = re.findall(r"(?m)^  ([a-z_]+):\s*$", event_block)
    _require(
        errors,
        event_names == ["workflow_dispatch"],
        "protected manual-only event",
    )
    for input_name in PROTECTED_INPUTS:
        _require(
            errors,
            re.search(rf"(?m)^      {re.escape(input_name)}:\s*$", event_block)
            is not None,
            f"protected input {input_name}",
        )

    permissions = _top_level_block(text, "permissions")
    _require(
        errors,
        re.search(r"(?m)^  contents:\s*read\s*$", permissions) is not None,
        "protected read-only contents",
    )
    _require(
        errors,
        re.search(r"(?m)^  id-token:\s*write\s*$", permissions) is not None,
        "protected OIDC permission",
    )
    _require(
        errors,
        "contents: write" not in permissions,
        "protected no contents write",
    )

    job = _job_block(text, "admit-current-wave")
    _require(errors, bool(job), "protected admission job")
    _require(
        errors,
        re.search(r"(?m)^    environment:\s*qinao-admission\s*$", job)
        is not None,
        "protected environment",
    )
    _require(
        errors,
        re.search(
            r"(?m)^    runs-on:\s*\[self-hosted,\s*macOS,\s*qinao-admission\]\s*$",
            job,
        )
        is not None,
        "protected self-hosted runner",
    )
    _require(
        errors,
        (
            "if: ${{ github.ref == "
            f"'{PROTECTED_REF}'"
            " }}"
        )
        in job,
        "protected ref expression guard",
    )
    _require(
        errors,
        f'test "$GITHUB_REF" = "{PROTECTED_REF}"' in job,
        "protected runtime ref guard",
    )

    checkouts = _checkout_blocks(job)
    _require(
        errors,
        len(checkouts) == 1,
        "protected single checkout",
    )
    if len(checkouts) == 1:
        revision, checkout = checkouts[0]
        _require(
            errors,
            revision == PINNED_CHECKOUT,
            "protected pinned checkout",
        )
        _require(
            errors,
            re.search(r"(?m)^\s+fetch-depth:\s*0\s*$", checkout) is not None,
            "protected checkout full history",
        )
        _require(
            errors,
            "ref: ${{ inputs.candidate_commit }}" in checkout,
            "protected exact candidate checkout",
        )

    for input_name, environment_name in PROTECTED_INPUT_ENVIRONMENT.items():
        _require(
            errors,
            (
                f"{environment_name}: "
                f"${{{{ inputs.{input_name} }}}}"
            )
            in job,
            f"protected dynamic input {input_name}",
        )
    for variable in PROTECTED_ENVIRONMENT_VARIABLES:
        _require(
            errors,
            f"{variable}: ${{{{ vars.{variable} }}}}" in job,
            f"protected environment pin {variable}",
        )

    compact = _compact(job)
    verifier_hash_check = _compact(
        'test "$(shasum -a 256 "$QINAO_EXTERNAL_ADMISSION_VERIFIER" '
        "| cut -d ' ' -f 1)\" = "
        '"$QINAO_EXTERNAL_ADMISSION_VERIFIER_SHA256"'
    )
    provider_hash_check = _compact(
        'test "$(shasum -a 256 "$QINAO_WAVE_ADMISSION_SIGNING_PROVIDER" '
        "| cut -d ' ' -f 1)\" = "
        '"$QINAO_WAVE_ADMISSION_SIGNING_PROVIDER_SHA256"'
    )
    _require(
        errors,
        verifier_hash_check in compact,
        "protected verifier SHA pin",
    )
    _require(
        errors,
        provider_hash_check in compact,
        "protected provider SHA pin",
    )

    report_anchor = "python3 scripts/run_qinao_wave_admission.py report"
    admit_anchor = '"$QINAO_EXTERNAL_ADMISSION_VERIFIER" admit-wave'
    verify_anchor = (
        "python3 scripts/run_qinao_wave_admission.py verify-receipt"
    )
    report_index = compact.find(report_anchor)
    admit_index = compact.find(admit_anchor)
    verify_index = compact.find(verify_anchor)
    floor_index = compact.find(FLOOR_CHECK)
    post_tree_anchor = (
        'test "$(git rev-parse HEAD^{tree})" = "$QINAO_CANDIDATE_TREE"'
    )
    post_tree_index = compact.rfind(post_tree_anchor)
    clean_anchor = 'test -z "$(git status --porcelain)"'
    clean_index = compact.rfind(clean_anchor)
    distinct_outputs_anchor = (
        'test "$QINAO_UNSIGNED_ADMISSION_REPORT" != '
        '"$QINAO_CURRENT_ADMISSION_RECEIPT"'
    )
    distinct_outputs_index = compact.find(distinct_outputs_anchor)
    _require(errors, report_index >= 0, "protected report command")
    _require(errors, admit_index >= 0, "protected external admit command")
    _require(errors, verify_index >= 0, "protected receipt verify command")
    _require(errors, floor_index >= 0, "protected floor command")
    _require(
        errors,
        post_tree_index > floor_index >= 0,
        "protected post tree assertion",
    )
    _require(
        errors,
        clean_index > post_tree_index >= 0,
        "protected clean assertion",
    )
    _require(
        errors,
        0 <= distinct_outputs_index < report_index,
        "protected distinct report and receipt",
    )
    _require(
        errors,
        min(
            report_index,
            admit_index,
            verify_index,
            floor_index,
            post_tree_index,
            clean_index,
        )
        >= 0
        and report_index
        < admit_index
        < verify_index
        < floor_index
        < post_tree_index
        < clean_index,
        "protected report admit verify floor tree clean order",
    )
    for argument in REPORT_ARGUMENTS:
        _require(
            errors,
            _compact(argument) in compact[report_index:admit_index],
            f"protected report argument {argument}",
        )
    for argument in ADMIT_ARGUMENTS:
        _require(
            errors,
            _compact(argument) in compact[admit_index:verify_index],
            f"protected admit argument {argument}",
        )
    for argument in VERIFY_ARGUMENTS:
        _require(
            errors,
            _compact(argument) in compact[verify_index:floor_index],
            f"protected verify argument {argument}",
        )
    _require(
        errors,
        compact.count(PREREQUISITE_ARGUMENTS) == 2,
        "protected dynamic prerequisite forwarding",
    )
    _require(
        errors,
        'test "$(git rev-parse HEAD)" = "$QINAO_CANDIDATE_COMMIT"'
        in compact,
        "protected candidate commit assertion",
    )
    _require(
        errors,
        "W0" not in text,
        "protected no hard-coded W0",
    )
    lowered = text.lower()
    _require(errors, "private_key" not in lowered, "protected private key")
    _require(errors, "sign-evidence" not in lowered, "protected generic signing")
    _require(errors, "secrets." not in lowered, "protected repository secrets")
    return errors


def validate_protected_privilege_separation(text: str) -> list[str]:
    """Require candidate execution and admission authority to stay disjoint."""

    errors: list[str] = []
    candidate = _job_block(text, "candidate-validation")
    privileged = _job_block(text, "admit-current-wave")
    _require(errors, bool(candidate), "unprivileged candidate-validation job")
    _require(errors, bool(privileged), "privileged admission job")
    _require(
        errors,
        re.search(r"(?m)^permissions:\s*\{\}\s*$", text) is not None,
        "top-level workflow permissions are empty",
    )

    _require(
        errors,
        re.search(r"(?m)^    runs-on:\s*xcode-27\s*$", candidate)
        is not None,
        "candidate validation uses ephemeral Xcode 27 runner",
    )
    _require(
        errors,
        re.search(
            r"(?ms)^    permissions:\s*\n      contents:\s*read\s*$",
            candidate,
        )
        is not None,
        "candidate validation has read-only contents",
    )
    for forbidden, diagnostic in (
        ("id-token:", "candidate validation has no OIDC"),
        ("environment:", "candidate validation has no protected environment"),
        (
            "QINAO_WAVE_ADMISSION_SIGNING_PROVIDER",
            "candidate validation has no signing provider",
        ),
        (
            "QINAO_ADMISSION_TRUST_ROOT",
            "candidate validation has no protected trust root",
        ),
        (
            "QINAO_SOURCE_SELECTION",
            "candidate validation has no external source-selection path",
        ),
        (
            "run_qinao_wave_admission.py",
            "candidate validation does not fabricate an admission report",
        ),
        ("admit-wave", "candidate validation never admits"),
        ("verify-receipt", "candidate validation never verifies a receipt"),
    ):
        _require(errors, forbidden not in candidate, diagnostic)

    candidate_checkouts = _checkout_blocks(candidate)
    _require(
        errors,
        len(candidate_checkouts) == 1,
        "candidate validation has one checkout",
    )
    if len(candidate_checkouts) == 1:
        revision, checkout = candidate_checkouts[0]
        _require(
            errors,
            revision == PINNED_CHECKOUT,
            "candidate validation checkout is pinned",
        )
        for token, diagnostic in (
            (
                "ref: ${{ inputs.candidate_commit }}",
                "candidate validation checks exact candidate",
            ),
            (
                "persist-credentials: false",
                "candidate validation checkout does not persist credentials",
            ),
            ("submodules: false", "candidate validation disables submodules"),
            ("lfs: false", "candidate validation disables LFS"),
            ("fetch-depth: 0", "candidate validation has full history"),
        ):
            _require(errors, token in checkout, diagnostic)
    _require(
        errors,
        f"actions/upload-artifact@{PINNED_UPLOAD_ARTIFACT}" in candidate,
        "candidate validation uses pinned artifact upload",
    )
    for token, diagnostic in (
        (
            "artifact_id: ${{ steps.upload.outputs.artifact-id }}",
            "candidate artifact exposes exact service ID",
        ),
        (
            "artifact_service_digest: ${{ steps.upload.outputs.artifact-digest }}",
            "candidate artifact exposes service digest",
        ),
        ("envelope_sha256:", "candidate artifact exposes envelope digest"),
        ("envelope_size:", "candidate artifact exposes envelope size"),
        ("log_sha256:", "candidate artifact exposes bounded-log digest"),
        ("log_size:", "candidate artifact exposes bounded-log size"),
        ("manifest_sha256:", "candidate artifact exposes manifest digest"),
        ("manifest_size:", "candidate artifact exposes manifest size"),
        (
            "QinaoCandidateValidationArtifactV1",
            "candidate artifact has a fixed schema",
        ),
        (
            "test \"$(wc -c < \"$raw_log\" | tr -d ' ')\" -le 8388608",
            "candidate validation log is bounded",
        ),
        (
            "-u GITHUB_OUTPUT",
            "candidate validation cannot write step outputs",
        ),
        (
            "-u GITHUB_ENV",
            "candidate validation cannot write step environment",
        ),
        (
            "-u GITHUB_PATH",
            "candidate validation cannot write the runner path",
        ),
        (
            "-u GITHUB_STEP_SUMMARY",
            "candidate validation cannot write the step summary",
        ),
        (
            "candidate validation failed; raw log withheld",
            "candidate failure emits only a fixed diagnostic",
        ),
    ):
        _require(errors, token in candidate, diagnostic)
    _require(
        errors,
        'tail -n 200 "$raw_log"' not in candidate
        and 'cat "$raw_log"' not in candidate,
        "candidate log is never replayed as a workflow command channel",
    )

    _require(
        errors,
        "needs: candidate-validation" in privileged,
        "privileged admission depends on candidate validation",
    )
    _require(
        errors,
        re.search(
            r"(?m)^    environment:\s*qinao-admission\s*$",
            privileged,
        )
        is not None,
        "privileged admission uses protected environment",
    )
    _require(
        errors,
        re.search(
            r"(?ms)^    permissions:\s*\n"
            r"      actions:\s*read\s*\n"
            r"      contents:\s*read\s*\n"
            r"      id-token:\s*write\s*$",
            privileged,
        )
        is not None,
        "privileged admission grants OIDC only at job scope",
    )
    _require(
        errors,
        f"actions/download-artifact@{PINNED_DOWNLOAD_ARTIFACT}" in privileged,
        "privileged admission uses pinned artifact download",
    )
    _require(
        errors,
        (
            "artifact-ids: "
            "${{ needs.candidate-validation.outputs.artifact_id }}"
        )
        in privileged,
        "privileged admission downloads exact artifact ID",
    )
    _require(
        errors,
        "tar -" not in privileged and "unzip " not in privileged,
        "privileged admission has no candidate-controlled extractor",
    )

    privileged_checkouts = _checkout_blocks(privileged)
    _require(
        errors,
        len(privileged_checkouts) == 2,
        "privileged admission has trusted-tools and candidate-data checkouts",
    )
    if len(privileged_checkouts) == 2:
        for revision, checkout in privileged_checkouts:
            _require(
                errors,
                revision == PINNED_CHECKOUT,
                "privileged checkouts are pinned",
            )
            for token, diagnostic in (
                (
                    "persist-credentials: false",
                    "privileged checkout does not persist credentials",
                ),
                ("submodules: false", "privileged checkout disables submodules"),
                ("lfs: false", "privileged checkout disables LFS"),
            ):
                _require(errors, token in checkout, diagnostic)
        _require(
            errors,
            any(
                "ref: ${{ github.sha }}" in checkout
                and "path: trusted-tools" in checkout
                for _, checkout in privileged_checkouts
            ),
            "privileged trusted tool checkout is workflow-pinned",
        )
        _require(
            errors,
            any(
                "ref: ${{ inputs.candidate_commit }}" in checkout
                and "path: candidate-data" in checkout
                for _, checkout in privileged_checkouts
            ),
            "privileged candidate checkout is isolated as data",
        )

    for token, diagnostic in (
        (
            "QINAO_REPOSITORY_RUNNER_SHA256: "
            "${{ vars.QINAO_REPOSITORY_RUNNER_SHA256 }}",
            "privileged admission pins repository runner",
        ),
        (
            "QINAO_OWNER_LEDGER_CHECKER_SHA256: "
            "${{ vars.QINAO_OWNER_LEDGER_CHECKER_SHA256 }}",
            "privileged admission pins owner-ledger checker",
        ),
        (
            "QINAO_ADMISSION_TRUST_ROOT_SHA256: "
            "${{ vars.QINAO_ADMISSION_TRUST_ROOT_SHA256 }}",
            "privileged admission pins trust root",
        ),
        (
            "QINAO_PROTECTED_WORKFLOW_SHA256: "
            "${{ vars.QINAO_PROTECTED_WORKFLOW_SHA256 }}",
            "privileged admission pins protected workflow bytes",
        ),
        (
            "QINAO_EXTERNAL_ADMISSION_VERIFIER_SHA256: "
            "${{ vars.QINAO_EXTERNAL_ADMISSION_VERIFIER_SHA256 }}",
            "privileged admission pins external verifier",
        ),
        (
            "QINAO_WAVE_ADMISSION_SIGNING_PROVIDER_SHA256: "
            "${{ vars.QINAO_WAVE_ADMISSION_SIGNING_PROVIDER_SHA256 }}",
            "privileged admission pins schema-scoped provider",
        ),
        (
            'test -x "$QINAO_WAVE_ADMISSION_SIGNING_PROVIDER"',
            "privileged provider must be executable",
        ),
        (
            'test -x "$QINAO_EXTERNAL_ADMISSION_VERIFIER"',
            "privileged verifier must be executable",
        ),
        (
            'exec 10<"$QINAO_REPOSITORY_RUNNER"',
            "privileged repository runner is opened before interpreter loading",
        ),
        (
            'exec 11<"$QINAO_OWNER_LEDGER_CHECKER"',
            "privileged owner-ledger checker is opened before interpreter loading",
        ),
        (
            '(( (8#$script_mode & 8#22) == 0 ))',
            "privileged Python tools reject group/world-writable modes",
        ),
    ):
        _require(errors, token in privileged, diagnostic)

    _require(
        errors,
        "python3 scripts/" not in privileged
        and "candidate-data/scripts/" not in privileged
        and "BehavioralAISubstrate/scripts/" not in privileged
        and "swift test" not in privileged
        and "xcodebuild" not in privileged
        and "--disable-sandbox" not in privileged,
        "privileged admission never executes candidate bytes",
    )
    _require(
        errors,
        PROTECTED_REPORT_TOOL in privileged
        and PROTECTED_ADMIT_TOOL in privileged
        and PROTECTED_VERIFY_TOOL in privileged
        and 'QINAO_PINNED_REPOSITORY_RUNNER="/dev/fd/$repository_runner_fd"'
        in privileged
        and 'QINAO_PINNED_OWNER_LEDGER_CHECKER="/dev/fd/$owner_checker_fd"'
        in privileged,
        "privileged admission executes only pinned admission tools",
    )
    return errors


def validate_protected_workflow(text: str) -> list[str]:
    errors = validate_protected_privilege_separation(text)
    event = _top_level_block(text, "on")
    _require(
        errors,
        re.findall(r"(?m)^  ([a-z_]+):\s*$", event)
        == ["workflow_dispatch"],
        "protected manual-only event",
    )
    expected_inputs = {
        "candidate_commit",
        "candidate_tree",
        "current_wave_bundle",
    }
    actual_inputs = set(
        re.findall(r"(?m)^      ([a-z_]+):\s*$", event)
    )
    _require(
        errors,
        actual_inputs == expected_inputs,
        "protected exact dispatch inputs",
    )

    candidate = _job_block(text, "candidate-validation")
    privileged = _job_block(text, "admit-current-wave")
    ref_expression = f"github.ref == '{PROTECTED_REF}'"
    for label, job in (("candidate", candidate), ("admission", privileged)):
        _require(
            errors,
            ref_expression in job,
            f"protected {label} ref expression guard",
        )
    _require(
        errors,
        f'test "$GITHUB_REF" = "{PROTECTED_REF}"' in candidate
        and f'test "$GITHUB_REF" = "{PROTECTED_REF}"' in privileged,
        "protected runtime ref guards",
    )
    for module in QINAO_MODULES:
        _require(
            errors,
            candidate.count(module) == 1,
            f"protected candidate module {module}",
        )
    unit_index = candidate.find("python3 -m unittest")
    floor_index = candidate.find(FLOOR_CHECK)
    final_tree_index = candidate.rfind(
        'test "$(git rev-parse HEAD^{tree})" = "$QINAO_CANDIDATE_TREE"'
    )
    final_clean_index = candidate.rfind(
        'test -z "$(git status --porcelain)"'
    )
    _require(
        errors,
        0 <= unit_index < floor_index < final_tree_index < final_clean_index,
        "protected candidate tests floor final tree clean order",
    )

    for variable in (
        "QINAO_SOURCE_SELECTION",
        "QINAO_ADMISSION_TRUST_ROOT",
        "QINAO_PREVIOUS_ADMISSION_RECEIPT",
        "QINAO_EXTERNAL_PREREQUISITES",
        "QINAO_PRIOR_ADMISSION_RECEIPTS",
        "QINAO_RUNTIME_ENTRY_PREDECESSOR",
    ):
        _require(
            errors,
            f"{variable}: ${{{{ vars.{variable} }}}}" in privileged,
            f"protected external configuration {variable}",
        )
    for variable in (
        "QINAO_CANDIDATE_ARTIFACT_ID",
        "QINAO_CANDIDATE_ARTIFACT_SERVICE_DIGEST",
        "QINAO_CANDIDATE_ENVELOPE_SHA256",
        "QINAO_CANDIDATE_ENVELOPE_SIZE",
        "QINAO_CANDIDATE_LOG_SHA256",
        "QINAO_CANDIDATE_LOG_SIZE",
        "QINAO_CANDIDATE_MANIFEST_SHA256",
        "QINAO_CANDIDATE_MANIFEST_SIZE",
    ):
        _require(
            errors,
            f"{variable}:" in privileged,
            f"protected artifact binding {variable}",
        )

    for token, diagnostic in (
        (
            "$'artifact-manifest.json\\nvalidation-envelope.json\\nvalidation.log'",
            "protected exact candidate artifact file set",
        ),
        (
            'shasum -a 256 "$artifact_root/validation-envelope.json"',
            "protected candidate envelope digest check",
        ),
        (
            'wc -c < "$artifact_root/validation-envelope.json"',
            "protected candidate envelope size check",
        ),
        (
            'shasum -a 256 "$artifact_root/validation.log"',
            "protected candidate log digest check",
        ),
        (
            'wc -c < "$artifact_root/validation.log"',
            "protected candidate log size check",
        ),
        (
            'shasum -a 256 "$artifact_root/artifact-manifest.json"',
            "protected candidate manifest digest check",
        ),
        (
            'wc -c < "$artifact_root/artifact-manifest.json"',
            "protected candidate manifest size check",
        ),
        (
            'cmp -s "$expected_manifest_path" '
            '"$artifact_root/artifact-manifest.json"',
            "protected candidate manifest exact-content check",
        ),
        (
            '"$QINAO_CANDIDATE_ARTIFACT_SERVICE_DIGEST"',
            "protected service artifact digest binding",
        ),
        (
            'test "$(shasum -a 256 "$QINAO_ADMISSION_TRUST_ROOT"',
            "protected expected trust-root digest verification",
        ),
        (
            'test "$(shasum -a 256 "/dev/fd/$repository_runner_fd"',
            "protected repository-runner digest verification",
        ),
        (
            'test "$(shasum -a 256 "/dev/fd/$owner_checker_fd"',
            "protected owner-checker digest verification",
        ),
        (
            'test "$(shasum -a 256 "$QINAO_PROTECTED_WORKFLOW"',
            "protected workflow digest verification",
        ),
        (
            'test "$(shasum -a 256 "/dev/fd/$external_verifier_fd"',
            "protected external-verifier digest verification",
        ),
        (
            'test "$(shasum -a 256 "/dev/fd/$signing_provider_fd"',
            "protected provider digest verification",
        ),
    ):
        _require(errors, token in privileged, diagnostic)

    compact = _compact(privileged)
    report_anchor = PROTECTED_REPORT_TOOL
    admit_anchor = PROTECTED_ADMIT_TOOL
    verify_anchor = PROTECTED_VERIFY_TOOL
    report_index = compact.find(report_anchor)
    admit_index = compact.find(admit_anchor)
    verify_index = compact.find(verify_anchor)
    post_commit_index = compact.rfind(
        'test "$(git -C "$candidate_root" rev-parse HEAD)" = '
        '"$QINAO_CANDIDATE_COMMIT"'
    )
    post_tree_index = compact.rfind(
        'test "$(git -C "$candidate_root" rev-parse HEAD^{tree})" = '
        '"$QINAO_CANDIDATE_TREE"'
    )
    post_clean_index = compact.rfind(
        'test -z "$(git -C "$candidate_root" status --porcelain)"'
    )
    _require(
        errors,
        0
        <= report_index
        < admit_index
        < verify_index
        < post_commit_index
        < post_tree_index
        < post_clean_index,
        "protected report admit verify final commit tree clean order",
    )
    for token in W6_CONTEXT_PARSER_TOKENS:
        _require(
            errors,
            _compact(token) in compact,
            f"protected strict W6 context parser token {token}",
        )
    _require(
        errors,
        re.search(r"\beval\b", privileged) is None,
        "protected W6 context parser does not eval configuration",
    )
    for binding in (
        (
            'prior_receipt_path="$(canonical_external_path '
            '"$prior_receipt_path" "$candidate_root" "$trusted_root")"'
        ),
        (
            'runtime_entry_path="$(canonical_external_path '
            '"$QINAO_RUNTIME_ENTRY_PREDECESSOR" '
            '"$candidate_root" "$trusted_root")"'
        ),
    ):
        _require(
            errors,
            _compact(binding) in compact,
            f"protected W6 context rejects repository origin {binding}",
        )
    for arguments, diagnostic in (
        (
            PRIOR_RECEIPT_ARGUMENTS,
            "protected prior-receipt three-way forwarding",
        ),
        (
            RUNTIME_ENTRY_ARGUMENTS,
            "protected runtime-entry three-way forwarding",
        ),
    ):
        normalized = _compact(arguments)
        _require(
            errors,
            normalized in compact[report_index:admit_index]
            and normalized in compact[admit_index:verify_index]
            and normalized in compact[verify_index:post_commit_index]
            and compact.count(normalized) == 3,
            diagnostic,
        )
    shared_arguments = (
        '--source-selection "$QINAO_SOURCE_SELECTION"',
        '--trust-root "$QINAO_ADMISSION_TRUST_ROOT"',
        '--previous-receipt "$QINAO_PREVIOUS_ADMISSION_RECEIPT"',
        '--candidate-tree "$QINAO_CANDIDATE_TREE"',
    )
    for argument in shared_arguments:
        normalized = _compact(argument)
        _require(
            errors,
            normalized in compact[report_index:admit_index],
            f"protected report argument {argument}",
        )
        _require(
            errors,
            normalized in compact[admit_index:verify_index],
            f"protected admit argument {argument}",
        )
        _require(
            errors,
            normalized in compact[verify_index:],
            f"protected verify argument {argument}",
        )
    for argument in (
        '--root "$candidate_root"',
        '--bundle "$candidate_root/$QINAO_CURRENT_WAVE_BUNDLE_RELATIVE"',
        '--unsigned-report "$QINAO_UNSIGNED_ADMISSION_REPORT"',
    ):
        _require(
            errors,
            _compact(argument) in compact[report_index:admit_index],
            f"protected report argument {argument}",
        )
    for argument in (
        '--report "$QINAO_UNSIGNED_ADMISSION_REPORT"',
        '--bundle "$candidate_root/$QINAO_CURRENT_WAVE_BUNDLE_RELATIVE"',
        '--repository "$candidate_root"',
        '--signing-provider "/dev/fd/$signing_provider_fd"',
        (
            '--signing-provider-sha256 '
            '"$QINAO_WAVE_ADMISSION_SIGNING_PROVIDER_SHA256"'
        ),
        '--receipt "$QINAO_CURRENT_ADMISSION_RECEIPT"',
    ):
        _require(
            errors,
            _compact(argument) in compact[admit_index:verify_index],
            f"protected admit argument {argument}",
        )
    _require(
        errors,
        "--candidate-validation-" not in privileged,
        "protected verifier CLI remains the frozen admit-wave interface",
    )
    for argument in (
        '--root "$candidate_root"',
        '--bundle "$candidate_root/$QINAO_CURRENT_WAVE_BUNDLE_RELATIVE"',
        '--receipt "$QINAO_CURRENT_ADMISSION_RECEIPT"',
    ):
        _require(
            errors,
            _compact(argument) in compact[verify_index:],
            f"protected verify argument {argument}",
        )
    _require(
        errors,
        compact.count(PREREQUISITE_ARGUMENTS) == 3,
        "protected exact three-way prerequisite forwarding",
    )
    _require(
        errors,
        f"actions/upload-artifact@{PINNED_UPLOAD_ARTIFACT}" in privileged,
        "protected pinned receipt upload",
    )
    lowered = text.lower()
    _require(errors, "w0" not in lowered, "protected no hard-coded W0")
    _require(errors, "private_key" not in lowered, "protected private key")
    _require(errors, "sign-evidence" not in lowered, "protected generic signing")
    _require(errors, "secrets." not in lowered, "protected repository secrets")
    return errors


def _remove_once(text: str, fragment: str) -> str:
    if fragment not in text:
        raise AssertionError(f"mutation fixture missing fragment: {fragment}")
    return text.replace(fragment, "", 1)


def _remove_last(text: str, fragment: str) -> str:
    index = text.rfind(fragment)
    if index < 0:
        raise AssertionError(f"mutation fixture missing fragment: {fragment}")
    return text[:index] + text[index + len(fragment) :]


def _remove_between(
    text: str,
    *,
    start: str,
    end: str,
    fragment: str,
) -> str:
    start_index = text.index(start)
    end_index = text.index(end, start_index + len(start))
    fragment_index = text.index(fragment, start_index, end_index)
    return text[:fragment_index] + text[fragment_index + len(fragment) :]


def _extracted_w6_context_parser(text: str) -> str:
    start_marker = "          expected_prior_wave_slice_ids=(\n"
    start = text.index(start_marker)
    end_markers = (
        '          QINAO_CANDIDATE_TREE="$(git rev-parse HEAD^{tree})"\n',
        (
            "          QINAO_PINNED_REPOSITORY_RUNNER="
            '"/dev/fd/$repository_runner_fd" \\\n'
        ),
    )
    end = min(
        text.index(marker, start)
        for marker in end_markers
        if marker in text[start:]
    )
    block = text[start:end]
    unindented = "".join(
        line[10:] if line.startswith("          ") else line
        for line in block.splitlines(keepends=True)
    )
    return (
        "set -euo pipefail\n"
        + unindented
        + "printf 'prior-arguments=%s\\n' \"${#prior_receipt_args[@]}\"\n"
        + "printf 'runtime-arguments=%s\\n' \"${#runtime_entry_args[@]}\"\n"
        + "exec 20<&-\n"
        + "exec 21<&-\n"
        + "exec 22<&-\n"
        + "exec 23<&-\n"
        + "exec 24<&-\n"
        + "exec 25<&-\n"
    )


class WorkflowOwnerLedgerTests(unittest.TestCase):
    maxDiff = None

    def assertNoContractErrors(self, errors: list[str]) -> None:
        self.assertEqual(errors, [])

    def test_ordinary_workflow_contract(self) -> None:
        self.assertNoContractErrors(
            validate_ordinary_workflow(_read(ORDINARY_WORKFLOW))
        )

    def test_ordinary_workflow_contract_rejects_each_realistic_mutation(
        self,
    ) -> None:
        workflow = _read(ORDINARY_WORKFLOW)
        self.assertNoContractErrors(validate_ordinary_workflow(workflow))
        mutations: list[tuple[str, str, str]] = [
            (
                "missing-floor-job",
                f"  {ORDINARY_FLOOR_JOB}:",
                "ordinary dedicated Xcode 27 floor job",
            ),
            (
                "floor-dependency",
                f"    needs: {ORDINARY_UNIT_JOB}",
                "ordinary floor job depends on unit job",
            ),
            (
                "floor-runner",
                "    runs-on: xcode-27",
                "ordinary floor job uses Xcode 27 runner",
            ),
            (
                "floor-toolchain",
                XCODE_27_ASSERTION,
                "ordinary floor asserts Xcode 27 toolchain",
            ),
            (
                "floor-checkout-credentials",
                "          persist-credentials: false",
                "ordinary floor checkout does not persist credentials",
            ),
            (
                "write-capable-job",
                "contents: read",
                "ordinary read-only contents",
            ),
            (
                "shallow-checkout",
                "fetch-depth: 0",
                "ordinary checkout full history",
            ),
            (
                "conditional-unit-step",
                "python3 -m unittest",
                "ordinary standard-library unittest",
            ),
            (
                "missing-floor-unit",
                FLOOR_UNIT_MODULE,
                "ordinary floor unit step",
            ),
            (
                "missing-floor-check",
                FLOOR_CHECK,
                "ordinary floor local check",
            ),
            (
                "unconditional-report",
                "if: ${{ env.QINAO_EXTERNAL_REPLAY_INPUTS_READY == 'true' }}",
                "ordinary report readiness guard",
            ),
            (
                "missing-candidate-tree",
                'QINAO_CANDIDATE_TREE="$(git rev-parse HEAD^{tree})"',
                "ordinary report candidate tree",
            ),
            (
                "missing-prerequisite-forwarding",
                PREREQUISITE_ARGUMENTS,
                "ordinary dynamic external prerequisites",
            ),
        ]
        for module in QINAO_MODULES:
            mutations.append(
                (
                    f"missing-{module}",
                    module,
                    f"ordinary module {module}",
                )
            )
        for argument in REPORT_ARGUMENTS:
            mutations.append(
                (
                    f"missing-report-{argument}",
                    _compact(argument),
                    f"ordinary report argument {argument}",
                )
            )
        for variable in ORDINARY_EXTERNAL_VARIABLES:
            mutations.append(
                (
                    f"fake-{variable}",
                    f"${{{{ vars.{variable} }}}}",
                    f"ordinary external variable {variable}",
                )
            )
        for label, fragment, diagnostic in mutations:
            with self.subTest(label=label):
                mutated = _remove_once(workflow, fragment)
                self.assertIn(
                    diagnostic,
                    validate_ordinary_workflow(mutated),
                )
        unit_start = f"  {ORDINARY_UNIT_JOB}:"
        floor_start = f"  {ORDINARY_FLOOR_JOB}:"
        with self.subTest(label="unit-runner"):
            mutated = _remove_between(
                workflow,
                start=unit_start,
                end=floor_start,
                fragment="    runs-on: macos-latest\n",
            )
            self.assertIn(
                "ordinary unit job uses macos-latest",
                validate_ordinary_workflow(mutated),
            )
        with self.subTest(label="floor-permissions"):
            floor = _job_block(workflow, ORDINARY_FLOOR_JOB)
            mutated_floor = _remove_once(floor, "      contents: read\n")
            mutated = workflow.replace(floor, mutated_floor, 1)
            self.assertIn(
                "ordinary floor read-only contents",
                validate_ordinary_workflow(mutated),
            )
        with self.subTest(label="floor-leaked-into-unit"):
            unit = _job_block(workflow, ORDINARY_UNIT_JOB)
            mutated_unit = unit + (
                "      - name: Illicit floor execution\n"
                f"        run: {FLOOR_CHECK}\n"
            )
            mutated = workflow.replace(unit, mutated_unit, 1)
            self.assertIn(
                "ordinary unit job excludes Xcode 27 floor",
                validate_ordinary_workflow(mutated),
            )
        with self.subTest(label="floor-oidc"):
            floor = _job_block(workflow, ORDINARY_FLOOR_JOB)
            mutated_floor = floor.replace(
                "      contents: read\n",
                "      contents: read\n      id-token: write\n",
                1,
            )
            mutated = workflow.replace(floor, mutated_floor, 1)
            self.assertIn(
                "ordinary jobs have no admission authority",
                validate_ordinary_workflow(mutated),
            )
        forbidden_mutations = {
            "secret": ("secrets.QINAO_KEY", "ordinary secrets"),
            "private-key": ("private_key", "ordinary private key"),
            "admit": ("admit-wave", "ordinary admit operation"),
            "verify": ("verify-receipt", "ordinary receipt verification"),
            "sign": ("sign-evidence", "ordinary generic signing"),
            "provider": (
                "QINAO_WAVE_ADMISSION_SIGNING_PROVIDER",
                "ordinary signing provider",
            ),
        }
        for label, (fragment, diagnostic) in forbidden_mutations.items():
            with self.subTest(label=label):
                self.assertIn(
                    diagnostic,
                    validate_ordinary_workflow(workflow + f"\n# {fragment}\n"),
                )

    def test_protected_workflow_contract(self) -> None:
        self.assertNoContractErrors(
            validate_protected_workflow(_read(PROTECTED_WORKFLOW))
        )

    def test_w6_context_forwarding_rejects_every_missing_call_site(
        self,
    ) -> None:
        ordinary = _read(ORDINARY_WORKFLOW)
        protected = _read(PROTECTED_WORKFLOW)

        for variable in W6_CONTEXT_ENVIRONMENT_VARIABLES:
            with self.subTest(workflow="ordinary", variable=variable):
                mutated = _remove_once(
                    ordinary,
                    (
                        f"      {variable}: "
                        f"${{{{ vars.{variable} }}}}\n"
                    ),
                )
                self.assertIn(
                    f"ordinary external variable {variable}",
                    validate_ordinary_workflow(mutated),
                )
            with self.subTest(workflow="protected", variable=variable):
                mutated = _remove_once(
                    protected,
                    (
                        f"      {variable}: "
                        f"${{{{ vars.{variable} }}}}\n"
                    ),
                )
                self.assertIn(
                    f"protected external configuration {variable}",
                    validate_protected_workflow(mutated),
                )

        strict_mutations = (
            (
                '              test -n "$prior_receipt"\n',
                'test -n "$prior_receipt"',
            ),
            (
                (
                    "                0) prior_receipt_fd=20; "
                    'exec 20<"$prior_receipt_path" ;;\n'
                ),
                (
                    "0) prior_receipt_fd=20; "
                    'exec 20<"$prior_receipt_path" ;;'
                ),
            ),
            (
                (
                    '                test "$seen_prior_receipt_binding" '
                    '!= "$prior_receipt_binding"\n'
                ),
                (
                    'test "$seen_prior_receipt_binding" '
                    '!= "$prior_receipt_binding"'
                ),
            ),
            (
                (
                    '              test "$prior_receipt_path_binding" '
                    '= "$prior_receipt_binding"\n'
                ),
                (
                    'test "$prior_receipt_path_binding" '
                    '= "$prior_receipt_binding"'
                ),
            ),
            (
                (
                    '            exec 25'
                    '<"$runtime_entry_path"\n'
                ),
                (
                    'exec 25<"$runtime_entry_path"'
                ),
            ),
            (
                (
                    '              test "$prior_receipt_binding" '
                    '!= "$runtime_entry_binding"\n'
                ),
                (
                    'test "$prior_receipt_binding" '
                    '!= "$runtime_entry_binding"'
                ),
            ),
        )
        for workflow_label, workflow, validator, diagnostic_prefix in (
            (
                "ordinary",
                ordinary,
                validate_ordinary_workflow,
                "ordinary strict W6 context parser token ",
            ),
            (
                "protected",
                protected,
                validate_protected_workflow,
                "protected strict W6 context parser token ",
            ),
        ):
            for fragment, token in strict_mutations:
                with self.subTest(
                    workflow=workflow_label,
                    parser_token=token,
                ):
                    mutated = _remove_once(workflow, fragment)
                    self.assertIn(
                        diagnostic_prefix + token,
                        validator(mutated),
                    )

        for arguments, diagnostic in (
            (
                PRIOR_RECEIPT_ARGUMENTS,
                "ordinary replay prior-receipt forwarding",
            ),
            (
                RUNTIME_ENTRY_ARGUMENTS,
                "ordinary replay runtime-entry forwarding",
            ),
        ):
            with self.subTest(workflow="ordinary", arguments=arguments):
                mutated = _remove_once(
                    ordinary,
                    f'            {arguments} \\\n',
                )
                self.assertIn(
                    diagnostic,
                    validate_ordinary_workflow(mutated),
                )

        protected_spans = (
            ("report", PROTECTED_REPORT_TOOL, PROTECTED_ADMIT_TOOL),
            ("admit", PROTECTED_ADMIT_TOOL, PROTECTED_VERIFY_TOOL),
            (
                "verify",
                PROTECTED_VERIFY_TOOL,
                "          exec 20<&-\n",
            ),
        )
        for arguments, diagnostic in (
            (
                PRIOR_RECEIPT_ARGUMENTS,
                "protected prior-receipt three-way forwarding",
            ),
            (
                RUNTIME_ENTRY_ARGUMENTS,
                "protected runtime-entry three-way forwarding",
            ),
        ):
            for call, start, end in protected_spans:
                with self.subTest(
                    workflow="protected",
                    call=call,
                    arguments=arguments,
                ):
                    mutated = _remove_between(
                        protected,
                        start=start,
                        end=end,
                        fragment=f'            {arguments} \\\n',
                    )
                    self.assertIn(
                        diagnostic,
                        validate_protected_workflow(mutated),
                    )

    def test_extracted_w6_context_parsers_fail_closed_on_malformed_inputs(
        self,
    ) -> None:
        slice_ids = (
            "w6.runtime.observation-values",
            "w6.semantic.audit-schema",
            "w6.runtime.audit-envelope-freeze",
            "w6.semantic.coordinator-behavior",
            "w6.runtime.integration-population",
        )
        with tempfile.TemporaryDirectory() as temporary_directory:
            directory = Path(temporary_directory)
            workspace = directory / "workspace"
            candidate_repository = workspace / "candidate-data"
            trusted_repository = workspace / "trusted-tools"
            candidate_repository.mkdir(parents=True)
            trusted_repository.mkdir()
            prior_paths = []
            for index in range(5):
                path = directory / f"prior-{index + 1}.json"
                path.write_text("{}\n", encoding="utf-8")
                path.chmod(0o600)
                prior_paths.append(path)
            runtime_entry = directory / "runtime-entry.json"
            runtime_entry.write_text("{}\n", encoding="utf-8")
            runtime_entry.chmod(0o600)
            valid_prior = "\n".join(
                f"{slice_id}={path}"
                for slice_id, path in zip(slice_ids, prior_paths)
            )

            def run_parser(
                workflow: Path,
                *,
                prior_value: str = valid_prior,
                runtime_value: str = str(runtime_entry),
                environment_overrides: dict[str, str] | None = None,
                script_replacement: tuple[str, str] | None = None,
            ) -> subprocess.CompletedProcess[str]:
                environment = dict(os.environ)
                environment.update(
                    {
                        "GITHUB_WORKSPACE": str(workspace),
                        "candidate_root": str(candidate_repository),
                        "QINAO_PRIOR_ADMISSION_RECEIPTS": prior_value,
                        "QINAO_RUNTIME_ENTRY_PREDECESSOR": runtime_value,
                        "trusted_root": str(trusted_repository),
                    }
                )
                environment.update(environment_overrides or {})
                script = _extracted_w6_context_parser(_read(workflow))
                if script_replacement is not None:
                    old, new = script_replacement
                    if script.count(old) != 1:
                        raise AssertionError(
                            "drift fixture must replace one shell boundary"
                        )
                    script = script.replace(old, new, 1)
                return subprocess.run(
                    ["/bin/bash"],
                    input=script,
                    env=environment,
                    text=True,
                    capture_output=True,
                    check=False,
                )

            for workflow in (ORDINARY_WORKFLOW, PROTECTED_WORKFLOW):
                with self.subTest(workflow=workflow.name, case="valid"):
                    result = run_parser(workflow)
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertIn("prior-arguments=10", result.stdout)
                    self.assertIn("runtime-arguments=2", result.stdout)

                with self.subTest(
                    workflow=workflow.name,
                    case="empty-ordinary-wave-context",
                ):
                    result = run_parser(
                        workflow,
                        prior_value="",
                        runtime_value="",
                    )
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertIn("prior-arguments=0", result.stdout)
                    self.assertIn("runtime-arguments=0", result.stdout)

                malformed_values = {
                    "empty-line": valid_prior.replace(
                        "\n",
                        "\n\n",
                        1,
                    ),
                    "carriage-return": valid_prior.replace(
                        "=",
                        "\r=",
                        1,
                    ),
                    "multiple-equals": valid_prior.replace(
                        str(prior_paths[0]),
                        f"{prior_paths[0]}=alias",
                        1,
                    ),
                    "wrong-order": "\n".join(
                        [
                            f"{slice_ids[1]}={prior_paths[1]}",
                            f"{slice_ids[0]}={prior_paths[0]}",
                            *[
                                f"{slice_id}={path}"
                                for slice_id, path in zip(
                                    slice_ids[2:],
                                    prior_paths[2:],
                                )
                            ],
                        ]
                    ),
                    "duplicate-slice": valid_prior.replace(
                        slice_ids[1],
                        slice_ids[0],
                        1,
                    ),
                    "same-path-alias": valid_prior.replace(
                        str(prior_paths[1]),
                        str(prior_paths[0]),
                        1,
                    ),
                    "missing-file": valid_prior.replace(
                        str(prior_paths[0]),
                        str(directory / "missing.json"),
                        1,
                    ),
                    "nonregular": valid_prior.replace(
                        str(prior_paths[0]),
                        str(directory),
                        1,
                    ),
                    "relative-path": valid_prior.replace(
                        str(prior_paths[0]),
                        "relative-prior.json",
                        1,
                    ),
                }
                symlink = directory / "prior-symlink.json"
                if not symlink.exists():
                    symlink.symlink_to(prior_paths[0])
                malformed_values["symlink"] = valid_prior.replace(
                    str(prior_paths[0]),
                    str(symlink),
                    1,
                )
                hardlink = directory / "prior-hardlink.json"
                if not hardlink.exists():
                    os.link(prior_paths[0], hardlink)
                malformed_values["hardlink-alias"] = valid_prior.replace(
                    str(prior_paths[1]),
                    str(hardlink),
                    1,
                )
                for label, prior_value in malformed_values.items():
                    with self.subTest(
                        workflow=workflow.name,
                        case=label,
                    ):
                        result = run_parser(
                            workflow,
                            prior_value=prior_value,
                        )
                        self.assertNotEqual(
                            result.returncode,
                            0,
                            result.stdout,
                        )
                hardlink.unlink()

                with self.subTest(
                    workflow=workflow.name,
                    case="runtime-prior-alias",
                ):
                    result = run_parser(
                        workflow,
                        runtime_value=str(prior_paths[0]),
                    )
                    self.assertNotEqual(result.returncode, 0, result.stdout)

                with self.subTest(
                    workflow=workflow.name,
                    case="runtime-relative-path",
                ):
                    result = run_parser(
                        workflow,
                        runtime_value="relative-entry.json",
                    )
                    self.assertNotEqual(result.returncode, 0, result.stdout)

                runtime_symlink = directory / "runtime-symlink.json"
                if not runtime_symlink.exists():
                    runtime_symlink.symlink_to(runtime_entry)
                for label, runtime_value in {
                    "runtime-newline": f"{runtime_entry}\n{runtime_entry}",
                    "runtime-carriage-return": f"{runtime_entry}\r",
                    "runtime-multiple-equals": f"{runtime_entry}=alias",
                    "runtime-missing": str(directory / "missing-entry.json"),
                    "runtime-nonregular": str(directory),
                    "runtime-symlink": str(runtime_symlink),
                }.items():
                    with self.subTest(
                        workflow=workflow.name,
                        case=label,
                    ):
                        result = run_parser(
                            workflow,
                            runtime_value=runtime_value,
                        )
                        self.assertNotEqual(
                            result.returncode,
                            0,
                            result.stdout,
                        )

                forbidden_roots = (
                    (workspace,)
                    if workflow == ORDINARY_WORKFLOW
                    else (candidate_repository, trusted_repository)
                )
                for root_index, forbidden_root in enumerate(forbidden_roots):
                    contained_prior = forbidden_root / (
                        f"contained-prior-{root_index}.json"
                    )
                    contained_prior.write_text("{}\n", encoding="utf-8")
                    contained_prior.chmod(0o600)
                    contained_runtime = forbidden_root / (
                        f"contained-runtime-{root_index}.json"
                    )
                    contained_runtime.write_text("{}\n", encoding="utf-8")
                    contained_runtime.chmod(0o600)
                    cases = {
                        "prior-repository-origin": (
                            valid_prior.replace(
                                str(prior_paths[0]),
                                str(contained_prior),
                                1,
                            ),
                            str(runtime_entry),
                        ),
                        "runtime-repository-origin": (
                            valid_prior,
                            str(contained_runtime),
                        ),
                        "prior-dotdot-repository-origin": (
                            valid_prior.replace(
                                str(prior_paths[0]),
                                (
                                    f"{forbidden_root}/../"
                                    f"{forbidden_root.name}/"
                                    f"{contained_prior.name}"
                                ),
                                1,
                            ),
                            str(runtime_entry),
                        ),
                    }
                    external_hardlink = directory / (
                        f"contained-prior-hardlink-{workflow.name}-"
                        f"{root_index}.json"
                    )
                    os.link(contained_prior, external_hardlink)
                    cases["prior-repository-hardlink-origin"] = (
                        valid_prior.replace(
                            str(prior_paths[0]),
                            str(external_hardlink),
                            1,
                        ),
                        str(runtime_entry),
                    )
                    for label, (prior_value, runtime_value) in cases.items():
                        with self.subTest(
                            workflow=workflow.name,
                            root=forbidden_root.name,
                            case=label,
                        ):
                            result = run_parser(
                                workflow,
                                prior_value=prior_value,
                                runtime_value=runtime_value,
                            )
                            self.assertNotEqual(
                                result.returncode,
                                0,
                                result.stdout,
                            )

            drift_target = directory / "drift-target.json"
            drift_target.write_text("old\n", encoding="utf-8")
            drift_target.chmod(0o600)
            drift_replacement = directory / "drift-replacement.json"
            drift_replacement.write_text("new\n", encoding="utf-8")
            drift_replacement.chmod(0o600)
            drift_target_identity = (
                drift_target.stat().st_dev,
                drift_target.stat().st_ino,
            )
            drift_replacement_identity = (
                drift_replacement.stat().st_dev,
                drift_replacement.stat().st_ino,
            )
            self.assertNotEqual(
                drift_target_identity,
                drift_replacement_identity,
            )
            drift_marker = directory / "drift-hook-ran"
            drift_prior = valid_prior.replace(
                str(prior_paths[0]),
                str(drift_target),
                1,
            )
            binding_line = (
                'prior_receipt_path_binding="$(stat -L -f \'%d:%i\' '
                '"$prior_receipt_path")"\n'
            )
            drift_hook = (
                binding_line
                + ': > "$DRIFT_MARKER"\n'
                + '/bin/mv "$DRIFT_REPLACEMENT" "$DRIFT_TARGET"\n'
            )
            with self.subTest(case="fd-tuple-drift"):
                result = run_parser(
                    PROTECTED_WORKFLOW,
                    prior_value=drift_prior,
                    environment_overrides={
                        "DRIFT_TARGET": str(drift_target),
                        "DRIFT_REPLACEMENT": str(drift_replacement),
                        "DRIFT_MARKER": str(drift_marker),
                    },
                    script_replacement=(binding_line, drift_hook),
                )
                self.assertTrue(drift_marker.is_file())
                self.assertFalse(drift_replacement.exists())
                self.assertEqual(
                    (
                        drift_target.stat().st_dev,
                        drift_target.stat().st_ino,
                    ),
                    drift_replacement_identity,
                )
                self.assertNotEqual(result.returncode, 0, result.stdout)

    def test_protected_workflow_separates_candidate_execution_from_oidc(
        self,
    ) -> None:
        self.assertNoContractErrors(
            validate_protected_privilege_separation(
                _read(PROTECTED_WORKFLOW)
            )
        )

    def _legacy_protected_workflow_contract_rejects_each_realistic_mutation(
        self,
    ) -> None:
        workflow = _read(PROTECTED_WORKFLOW)
        self.assertNoContractErrors(validate_protected_workflow(workflow))
        mutations: list[tuple[str, str, str]] = [
            (
                "event",
                "workflow_dispatch:",
                "protected manual-only event",
            ),
            (
                "contents",
                "contents: read",
                "protected read-only contents",
            ),
            (
                "oidc",
                "id-token: write",
                "protected OIDC permission",
            ),
            (
                "environment",
                "environment: qinao-admission",
                "protected environment",
            ),
            (
                "runner",
                "self-hosted",
                "protected self-hosted runner",
            ),
            (
                "expression-ref-guard",
                f"github.ref == '{PROTECTED_REF}'",
                "protected ref expression guard",
            ),
            (
                "runtime-ref-guard",
                f'test "$GITHUB_REF" = "{PROTECTED_REF}"',
                "protected runtime ref guard",
            ),
            (
                "checkout-pin",
                PINNED_CHECKOUT,
                "protected pinned checkout",
            ),
            (
                "full-history",
                "fetch-depth: 0",
                "protected checkout full history",
            ),
            (
                "candidate-checkout",
                "ref: ${{ inputs.candidate_commit }}",
                "protected exact candidate checkout",
            ),
            (
                "verifier-pin",
                (
                    'test "$(shasum -a 256 '
                    '"$QINAO_EXTERNAL_ADMISSION_VERIFIER"'
                ),
                "protected verifier SHA pin",
            ),
            (
                "provider-pin",
                (
                    'test "$(shasum -a 256 '
                    '"$QINAO_WAVE_ADMISSION_SIGNING_PROVIDER"'
                ),
                "protected provider SHA pin",
            ),
            (
                "report",
                "python3 scripts/run_qinao_wave_admission.py report",
                "protected report command",
            ),
            (
                "admit",
                '"$QINAO_EXTERNAL_ADMISSION_VERIFIER" admit-wave',
                "protected external admit command",
            ),
            (
                "verify",
                "python3 scripts/run_qinao_wave_admission.py verify-receipt",
                "protected receipt verify command",
            ),
            (
                "floor",
                FLOOR_CHECK,
                "protected floor command",
            ),
            (
                "post-tree",
                (
                    'test "$(git rev-parse HEAD^{tree})" = '
                    '"$QINAO_CANDIDATE_TREE"'
                ),
                "protected post tree assertion",
            ),
            (
                "clean",
                'test -z "$(git status --porcelain)"',
                "protected clean assertion",
            ),
            (
                "candidate-commit",
                (
                    'test "$(git rev-parse HEAD)" = '
                    '"$QINAO_CANDIDATE_COMMIT"'
                ),
                "protected candidate commit assertion",
            ),
            (
                "aliased-report-and-receipt",
                (
                    'test "$QINAO_UNSIGNED_ADMISSION_REPORT" != '
                    '"$QINAO_CURRENT_ADMISSION_RECEIPT"'
                ),
                "protected distinct report and receipt",
            ),
        ]
        for input_name in PROTECTED_INPUTS:
            mutations.append(
                (
                    f"input-{input_name}",
                    f"${{{{ inputs.{input_name} }}}}",
                    f"protected dynamic input {input_name}",
                )
            )
        for variable in PROTECTED_ENVIRONMENT_VARIABLES:
            mutations.append(
                (
                    f"pin-{variable}",
                    f"${{{{ vars.{variable} }}}}",
                    f"protected environment pin {variable}",
                )
            )
        for argument in REPORT_ARGUMENTS:
            mutations.append(
                (
                    f"report-{argument}",
                    _compact(argument),
                    f"protected report argument {argument}",
                )
            )
        for argument in ADMIT_ARGUMENTS:
            mutations.append(
                (
                    f"admit-{argument}",
                    _compact(argument),
                    f"protected admit argument {argument}",
                )
            )
        for argument in VERIFY_ARGUMENTS:
            mutations.append(
                (
                    f"verify-{argument}",
                    _compact(argument),
                    f"protected verify argument {argument}",
                )
            )
        for label, fragment, diagnostic in mutations:
            with self.subTest(label=label):
                if label == "checkout-pin":
                    mutated = workflow.replace(
                        PINNED_CHECKOUT,
                        "0" * 40,
                        1,
                    )
                elif label in {"post-tree", "clean"}:
                    mutated = _remove_last(workflow, fragment)
                elif label.startswith("admit---"):
                    mutated = _remove_between(
                        workflow,
                        start=(
                            '"$QINAO_EXTERNAL_ADMISSION_VERIFIER" '
                            "admit-wave"
                        ),
                        end=(
                            "python3 scripts/run_qinao_wave_admission.py "
                            "verify-receipt"
                        ),
                        fragment=fragment,
                    )
                elif label.startswith("verify---"):
                    mutated = _remove_between(
                        workflow,
                        start=(
                            "python3 scripts/run_qinao_wave_admission.py "
                            "verify-receipt"
                        ),
                        end=FLOOR_CHECK,
                        fragment=fragment,
                    )
                else:
                    mutated = _remove_once(workflow, fragment)
                self.assertIn(
                    diagnostic,
                    validate_protected_workflow(mutated),
                )

        report_command = "python3 scripts/run_qinao_wave_admission.py report"
        verify_command = (
            "python3 scripts/run_qinao_wave_admission.py verify-receipt"
        )
        order_mutation = workflow.replace(report_command, "__REPORT__", 1)
        order_mutation = order_mutation.replace(
            verify_command,
            report_command,
            1,
        )
        order_mutation = order_mutation.replace(
            "__REPORT__",
            verify_command,
            1,
        )
        with self.subTest(label="operation-order"):
            self.assertIn(
                "protected report admit verify floor tree clean order",
                validate_protected_workflow(order_mutation),
            )
        with self.subTest(label="hard-coded-wave"):
            self.assertIn(
                "protected no hard-coded W0",
                validate_protected_workflow(workflow + "\n# W0\n"),
            )
        forbidden_mutations = {
            "private-key": ("private_key", "protected private key"),
            "generic-sign": ("sign-evidence", "protected generic signing"),
            "secret": ("secrets.QINAO_KEY", "protected repository secrets"),
        }
        for label, (fragment, diagnostic) in forbidden_mutations.items():
            with self.subTest(label=label):
                self.assertIn(
                    diagnostic,
                    validate_protected_workflow(workflow + f"\n# {fragment}\n"),
                )

    def test_protected_workflow_contract_rejects_each_realistic_mutation(
        self,
    ) -> None:
        workflow = _read(PROTECTED_WORKFLOW)
        self.assertNoContractErrors(validate_protected_workflow(workflow))
        mutations = [
            (
                "manual-only",
                "workflow_dispatch:",
                "protected manual-only event",
            ),
            (
                "empty-top-permissions",
                "permissions: {}",
                "top-level workflow permissions are empty",
            ),
            (
                "exact-inputs",
                "      current_wave_bundle:",
                "protected exact dispatch inputs",
            ),
            (
                "candidate-xcode27",
                "    runs-on: xcode-27",
                "candidate validation uses ephemeral Xcode 27 runner",
            ),
            (
                "candidate-ref-guard",
                f"github.ref == '{PROTECTED_REF}'",
                "protected candidate ref expression guard",
            ),
            (
                "candidate-runtime-ref",
                f'test "$GITHUB_REF" = "{PROTECTED_REF}"',
                "protected runtime ref guards",
            ),
            (
                "candidate-checkout-ref",
                "ref: ${{ inputs.candidate_commit }}",
                "candidate validation checks exact candidate",
            ),
            (
                "candidate-no-credentials",
                "persist-credentials: false",
                "candidate validation checkout does not persist credentials",
            ),
            (
                "candidate-no-submodules",
                "submodules: false",
                "candidate validation disables submodules",
            ),
            (
                "candidate-no-lfs",
                "lfs: false",
                "candidate validation disables LFS",
            ),
            (
                "candidate-full-history",
                "fetch-depth: 0",
                "candidate validation has full history",
            ),
            (
                "candidate-log-bound",
                " -le 8388608",
                "candidate validation log is bounded",
            ),
            (
                "command-output-channel",
                "-u GITHUB_OUTPUT",
                "candidate validation cannot write step outputs",
            ),
            (
                "command-env-channel",
                "-u GITHUB_ENV",
                "candidate validation cannot write step environment",
            ),
            (
                "command-path-channel",
                "-u GITHUB_PATH",
                "candidate validation cannot write the runner path",
            ),
            (
                "command-summary-channel",
                "-u GITHUB_STEP_SUMMARY",
                "candidate validation cannot write the step summary",
            ),
            (
                "fixed-failure-diagnostic",
                "candidate validation failed; raw log withheld",
                "candidate failure emits only a fixed diagnostic",
            ),
            (
                "artifact-service-id",
                "artifact_id: ${{ steps.upload.outputs.artifact-id }}",
                "candidate artifact exposes exact service ID",
            ),
            (
                "artifact-service-digest",
                (
                    "artifact_service_digest: "
                    "${{ steps.upload.outputs.artifact-digest }}"
                ),
                "candidate artifact exposes service digest",
            ),
            (
                "artifact-schema",
                "QinaoCandidateValidationArtifactV1",
                "candidate artifact has a fixed schema",
            ),
            (
                "artifact-upload-pin",
                f"actions/upload-artifact@{PINNED_UPLOAD_ARTIFACT}",
                "candidate validation uses pinned artifact upload",
            ),
            (
                "protected-environment",
                "environment: qinao-admission",
                "privileged admission uses protected environment",
            ),
            (
                "protected-oidc",
                "      id-token: write",
                "privileged admission grants OIDC only at job scope",
            ),
            (
                "download-artifact-id",
                (
                    "artifact-ids: "
                    "${{ needs.candidate-validation.outputs.artifact_id }}"
                ),
                "privileged admission downloads exact artifact ID",
            ),
            (
                "download-pin",
                f"actions/download-artifact@{PINNED_DOWNLOAD_ARTIFACT}",
                "privileged admission uses pinned artifact download",
            ),
            (
                "trusted-checkout",
                "ref: ${{ github.sha }}",
                "privileged trusted tool checkout is workflow-pinned",
            ),
            (
                "trusted-path",
                "path: trusted-tools",
                "privileged trusted tool checkout is workflow-pinned",
            ),
            (
                "candidate-data-path",
                "path: candidate-data",
                "privileged candidate checkout is isolated as data",
            ),
            (
                "runner-pin",
                (
                    "QINAO_REPOSITORY_RUNNER_SHA256: "
                    "${{ vars.QINAO_REPOSITORY_RUNNER_SHA256 }}"
                ),
                "privileged admission pins repository runner",
            ),
            (
                "checker-pin",
                (
                    "QINAO_OWNER_LEDGER_CHECKER_SHA256: "
                    "${{ vars.QINAO_OWNER_LEDGER_CHECKER_SHA256 }}"
                ),
                "privileged admission pins owner-ledger checker",
            ),
            (
                "workflow-pin",
                (
                    "QINAO_PROTECTED_WORKFLOW_SHA256: "
                    "${{ vars.QINAO_PROTECTED_WORKFLOW_SHA256 }}"
                ),
                "privileged admission pins protected workflow bytes",
            ),
            (
                "trust-pin",
                (
                    "QINAO_ADMISSION_TRUST_ROOT_SHA256: "
                    "${{ vars.QINAO_ADMISSION_TRUST_ROOT_SHA256 }}"
                ),
                "privileged admission pins trust root",
            ),
            (
                "verifier-pin",
                (
                    "QINAO_EXTERNAL_ADMISSION_VERIFIER_SHA256: "
                    "${{ vars.QINAO_EXTERNAL_ADMISSION_VERIFIER_SHA256 }}"
                ),
                "privileged admission pins external verifier",
            ),
            (
                "provider-pin",
                (
                    "QINAO_WAVE_ADMISSION_SIGNING_PROVIDER_SHA256: "
                    "${{ vars.QINAO_WAVE_ADMISSION_SIGNING_PROVIDER_SHA256 }}"
                ),
                "privileged admission pins schema-scoped provider",
            ),
            (
                "exact-file-set",
                (
                    "$'artifact-manifest.json\\n"
                    "validation-envelope.json\\nvalidation.log'"
                ),
                "protected exact candidate artifact file set",
            ),
            (
                "exact-manifest",
                (
                    'cmp -s "$expected_manifest_path" '
                    '"$artifact_root/artifact-manifest.json"'
                ),
                "protected candidate manifest exact-content check",
            ),
            (
                "runner-digest-check",
                'test "$(shasum -a 256 "/dev/fd/$repository_runner_fd"',
                "protected repository-runner digest verification",
            ),
            (
                "checker-digest-check",
                'test "$(shasum -a 256 "/dev/fd/$owner_checker_fd"',
                "protected owner-checker digest verification",
            ),
            (
                "workflow-digest-check",
                'test "$(shasum -a 256 "$QINAO_PROTECTED_WORKFLOW"',
                "protected workflow digest verification",
            ),
            (
                "trust-digest-check",
                'test "$(shasum -a 256 "$QINAO_ADMISSION_TRUST_ROOT"',
                "protected expected trust-root digest verification",
            ),
            (
                "verifier-digest-check",
                (
                    'test "$(shasum -a 256 '
                    '"/dev/fd/$external_verifier_fd"'
                ),
                "protected external-verifier digest verification",
            ),
            (
                "provider-digest-check",
                (
                    'test "$(shasum -a 256 '
                    '"/dev/fd/$signing_provider_fd"'
                ),
                "protected provider digest verification",
            ),
            (
                "provider-executable",
                'test -x "$QINAO_WAVE_ADMISSION_SIGNING_PROVIDER"',
                "privileged provider must be executable",
            ),
            (
                "report-tool",
                PROTECTED_REPORT_TOOL,
                "privileged admission executes only pinned admission tools",
            ),
            (
                "admit-tool",
                PROTECTED_ADMIT_TOOL,
                "privileged admission executes only pinned admission tools",
            ),
            (
                "verify-tool",
                PROTECTED_VERIFY_TOOL,
                "privileged admission executes only pinned admission tools",
            ),
            (
                "three-way-prerequisites",
                PREREQUISITE_ARGUMENTS,
                "protected exact three-way prerequisite forwarding",
            ),
        ]
        for module in QINAO_MODULES:
            mutations.append(
                (
                    f"candidate-module-{module}",
                    module,
                    f"protected candidate module {module}",
                )
            )
        for label, fragment, diagnostic in mutations:
            with self.subTest(label=label):
                mutated = _remove_once(workflow, fragment)
                self.assertIn(
                    diagnostic,
                    validate_protected_workflow(mutated),
                )

        with self.subTest(label="candidate-oidc-injection"):
            mutated = workflow.replace(
                "    permissions:\n      contents: read",
                "    permissions:\n      contents: read\n      id-token: write",
                1,
            )
            self.assertIn(
                "candidate validation has no OIDC",
                validate_protected_workflow(mutated),
            )
        with self.subTest(label="candidate-trust-root-injection"):
            mutated = workflow.replace(
                "    steps:\n",
                (
                    "    env:\n"
                    "      QINAO_ADMISSION_TRUST_ROOT: candidate-controlled\n"
                    "    steps:\n"
                ),
                1,
            )
            self.assertIn(
                "candidate validation has no protected trust root",
                validate_protected_workflow(mutated),
            )
        with self.subTest(label="privileged-candidate-execution"):
            mutated = workflow.replace(
                "      - name: Upload admitted receipt",
                (
                    "      - run: python3 scripts/candidate.py\n"
                    "      - name: Upload admitted receipt"
                ),
            )
            self.assertIn(
                "privileged admission never executes candidate bytes",
                validate_protected_workflow(mutated),
            )
        with self.subTest(label="privileged-extractor"):
            mutated = workflow.replace(
                (
                    "      - name: Run only pinned admission tools over "
                    "candidate data\n"
                    "        shell: bash\n"
                    "        run: |\n"
                    "          set -euo pipefail"
                ),
                (
                    "      - name: Run only pinned admission tools over "
                    "candidate data\n"
                    "        shell: bash\n"
                    "        run: |\n"
                    "          set -euo pipefail\n"
                    "          tar -xf candidate.tar"
                ),
                1,
            )
            self.assertIn(
                "privileged admission has no candidate-controlled extractor",
                validate_protected_workflow(mutated),
            )
        with self.subTest(label="operation-order"):
            report = PROTECTED_REPORT_TOOL
            verify = PROTECTED_VERIFY_TOOL
            mutated = workflow.replace(report, "__REPORT__", 1)
            mutated = mutated.replace(verify, report, 1)
            mutated = mutated.replace("__REPORT__", verify, 1)
            self.assertIn(
                "protected report admit verify final commit tree clean order",
                validate_protected_workflow(mutated),
            )
        for label, fragment, diagnostic in (
            ("hard-coded-wave", "W0", "protected no hard-coded W0"),
            ("private-key", "private_key", "protected private key"),
            (
                "generic-sign",
                "sign-evidence",
                "protected generic signing",
            ),
            ("secret", "secrets.QINAO_KEY", "protected repository secrets"),
        ):
            with self.subTest(label=label):
                self.assertIn(
                    diagnostic,
                    validate_protected_workflow(
                        workflow + f"\n# {fragment}\n"
                    ),
                )


if __name__ == "__main__":
    unittest.main()
