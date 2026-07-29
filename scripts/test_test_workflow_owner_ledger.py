from __future__ import annotations

import re
import unittest
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[1]
ORDINARY_WORKFLOW = PROJECT_ROOT / ".github/workflows/test.yml"
PROTECTED_WORKFLOW = (
    PROJECT_ROOT / ".github/workflows/qinao-wave-admission.yml"
)

CHECKOUT_ACTION = "actions/checkout"
PINNED_CHECKOUT = "11bd71901bbe5b1630ceea73d27597364c9af683"
PROTECTED_REF = "refs/heads/qinao-admission-bootstrap-v1"

QINAO_MODULES = (
    "scripts.test_check_qinao_owner_ledger",
    "scripts.test_run_nonempty_swift_filter",
    "scripts.test_run_qinao_wave_admission",
    "scripts.test_run_qinao_k4_ios27_platform_spike",
    "scripts.test_qinao_plan_remediation",
    "scripts.test_test_workflow_owner_ledger",
)
FLOOR_UNIT_MODULE = "BehavioralAISubstrate.scripts.test_check_ios27_floor"
FLOOR_CHECK = "BehavioralAISubstrate/scripts/check-ios27-floor.sh"

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
    "QINAO_UNSIGNED_ADMISSION_REPORT",
)
PROTECTED_INPUT_ENVIRONMENT = {
    "candidate_commit": "QINAO_CANDIDATE_COMMIT",
    "candidate_tree": "QINAO_CANDIDATE_TREE",
    "current_wave_bundle": "QINAO_CURRENT_WAVE_BUNDLE",
    "source_selection": "QINAO_SOURCE_SELECTION",
    "trust_root": "QINAO_ADMISSION_TRUST_ROOT",
    "previous_receipt": "QINAO_PREVIOUS_ADMISSION_RECEIPT",
    "external_prerequisites": "QINAO_EXTERNAL_PREREQUISITES",
    "unsigned_report": "QINAO_UNSIGNED_ADMISSION_REPORT",
    "current_receipt": "QINAO_CURRENT_ADMISSION_RECEIPT",
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
    job = _job_block(text, "qinao-gates")
    _require(errors, bool(job), "ordinary qinao-gates job")
    _require(
        errors,
        re.search(
            r"(?ms)^    permissions:\s*\n      contents:\s*read\s*$",
            job,
        )
        is not None,
        "ordinary read-only contents",
    )

    checkouts = _checkout_blocks(text)
    _require(errors, bool(checkouts), "ordinary checkout present")
    _require(
        errors,
        bool(checkouts)
        and all(re.search(r"(?m)^\s+fetch-depth:\s*0\s*$", block) for _, block in checkouts),
        "ordinary checkout full history",
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

    floor_unit_step = _unique_step_containing(job, FLOOR_UNIT_MODULE)
    _require(errors, bool(floor_unit_step), "ordinary floor unit step")
    _require(
        errors,
        bool(floor_unit_step) and "if:" not in floor_unit_step,
        "ordinary floor unit unconditional",
    )
    floor_check_step = _unique_step_containing(job, FLOOR_CHECK)
    _require(errors, bool(floor_check_step), "ordinary floor local check")
    _require(
        errors,
        bool(floor_check_step) and "if:" not in floor_check_step,
        "ordinary floor local check unconditional",
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
        '"${prerequisite_args[@]}"' in report_step,
        "ordinary dynamic external prerequisites",
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
        and floor_unit_step
        and floor_check_step
        and report_step
        and job.index(unit_step)
        < job.index(floor_unit_step)
        < job.index(floor_check_step)
        < job.index(report_step),
        "ordinary tests floor report order",
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


def validate_protected_workflow(text: str) -> list[str]:
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
        compact.count('"${prerequisite_args[@]}"') == 2,
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
                '"${prerequisite_args[@]}"',
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

    def test_protected_workflow_contract_rejects_each_realistic_mutation(
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


if __name__ == "__main__":
    unittest.main()
