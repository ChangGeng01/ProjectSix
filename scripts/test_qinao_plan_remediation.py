from __future__ import annotations

import ast
import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MASTER = (
    ROOT
    / "docs/superpowers/plans/"
    / "2026-07-29-qinao-dual-space-automation-controlled-convergence.md"
)
CONTROLLED_CONVERGENCE = (
    ROOT
    / "docs/superpowers/plans/"
    / "2026-07-19-qinao-coreai-agent-controlled-document-convergence.md"
)
AGENT_CONTEXT_ADDENDUM = (
    ROOT
    / "docs/superpowers/specs/"
    / "2026-07-19-qinao-coreai-agent-context-memory-rsi-design.md"
)
OWNER_CHECKER = ROOT / "scripts/check_qinao_owner_ledger.py"
NONEMPTY_FILTER = ROOT / "scripts/run_nonempty_swift_filter.py"
IOS27_FLOOR = ROOT / "BehavioralAISubstrate/scripts/check-ios27-floor.sh"
QINAO_PACKAGE = ROOT / "QinaoRuntimeSDK/Package.swift"
QINAO_TEST_DIRECTORY = ROOT / "QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests"


def section(contents: str, start: str, end: str) -> str:
    if contents.count(start) != 1:
        raise AssertionError(f"expected exactly one section start: {start!r}")
    tail = contents.split(start, 1)[1]
    if end not in tail:
        raise AssertionError(f"missing section end after {start!r}: {end!r}")
    return tail.split(end, 1)[0]


def fenced_shell_blocks(contents: str) -> list[str]:
    return re.findall(r"```(?:bash|sh)\n(.*?)```", contents, flags=re.DOTALL)


def logical_shell_commands(block: str) -> list[str]:
    commands: list[str] = []
    pending = ""
    for line in block.splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        pending = f"{pending} {stripped}".strip()
        if pending.endswith("\\"):
            pending = pending[:-1].rstrip()
            continue
        commands.append(pending)
        pending = ""
    if pending:
        commands.append(pending)
    return commands


def required_add_argument_options(source: str) -> set[str]:
    parsed = ast.parse(source)
    required: set[str] = set()
    for node in ast.walk(parsed):
        if not isinstance(node, ast.Call):
            continue
        function = node.func
        if not isinstance(function, ast.Attribute) or function.attr != "add_argument":
            continue
        if not node.args:
            continue
        first = node.args[0]
        if not isinstance(first, ast.Constant) or not isinstance(first.value, str):
            continue
        if not first.value.startswith("--"):
            continue
        if any(
            keyword.arg == "required"
            and isinstance(keyword.value, ast.Constant)
            and keyword.value.value is True
            for keyword in node.keywords
        ):
            required.add(first.value)
    return required


class QinaoPlanRemediationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.master = MASTER.read_text(encoding="utf-8")

    def test_operator_bootstrap_is_unique_unadmitted_and_requires_external_replay(
        self,
    ) -> None:
        heading = "### Operator-pinned development bootstrap overlay"
        self.assertEqual(self.master.count(heading), 1)
        overlay = section(
            self.master,
            heading,
            "The following capabilities remain disabled until their named stop condition clears:",
        )
        for exact_binding in (
            "7e4aa2d626e2c94b1b1f3405fb8454e73448514f",
            "47304602b7d1c1eba8eed571dbc65ee36c3a5f21",
            ".worktrees/qinao-dual-space-controlled-convergence",
            "codex/qinao-dual-space-controlled-convergence",
        ):
            self.assertIn(exact_binding, overlay)
        self.assertIn("development branch and every commit", overlay)
        self.assertIn("explicitly **unadmitted**", overlay)
        self.assertIn("Deferred external gate", overlay)
        self.assertIn("Pre-merge/pre-release replay is mandatory", overlay)
        normalized_overlay = re.sub(r"\s+", " ", overlay)
        self.assertIn(
            "external bundle-review/admit/verify/signature commands are deferred",
            normalized_overlay,
        )
        self.assertIn("independently reviewed external verifier", normalized_overlay)
        self.assertIn(
            "original signed source-selection/root-admission receipt",
            normalized_overlay,
        )
        self.assertNotIn("development-bootstrap admission", overlay)

    def test_swift_test_target_and_paths_are_real_and_not_phantom(self) -> None:
        package = QINAO_PACKAGE.read_text(encoding="utf-8")
        self.assertRegex(
            package,
            r"\.testTarget\(\s*name:\s*\"QinaoRuntimeSDKTests\"",
        )
        self.assertTrue(QINAO_TEST_DIRECTORY.is_dir())
        self.assertGreater(
            len(tuple(QINAO_TEST_DIRECTORY.rglob("*.swift"))),
            0,
        )
        self.assertIn("`Tests/QinaoRuntimeSDKTests/`", self.master)
        self.assertNotIn("QinaoRuntimeTests", self.master)
        self.assertIn(
            "`BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/`",
            self.master,
        )
        self.assertIn(
            "`BehavioralAISubstrate/DeviceTestApp/Tests/AppleSystemSurfaces/`",
            self.master,
        )

    def test_every_filtered_swift_command_uses_the_nonempty_runner(self) -> None:
        commands = [
            command
            for block in fenced_shell_blocks(self.master)
            for command in logical_shell_commands(block)
        ]
        filtered = [command for command in commands if "--filter" in command]
        self.assertGreater(len(filtered), 5)
        for command in filtered:
            self.assertIn("scripts/run_nonempty_swift_filter.py", command)
            self.assertIn("--package-path", command)

        source = NONEMPTY_FILTER.read_text(encoding="utf-8")
        for contract in (
            "CLOSED_ALTERNATION.fullmatch",
            '["test", "--package-path", str(package_path), "list"]',
            "missing_discovery",
            "executed_suite_counts",
            "missing_execution",
            "EXIT_ZERO_EXECUTION",
        ):
            self.assertIn(contract, source)

    def test_negative_scans_cannot_false_green_on_rg_l_or_missing_input(
        self,
    ) -> None:
        for block in fenced_shell_blocks(self.master):
            self.assertNotIn("rg -L", block)
        task_one = section(
            self.master,
            "## Task 1: Make W0 Gates Non-Vacuous and Continuous",
            "## Task 2: Atomically Reconcile the Seven Controlled Documents",
        )
        self.assertIn("exact path existence/non-empty assertion", task_one)
        self.assertIn("status classification `0/1/2+`", task_one)
        self.assertIn("Never use `rg -L`", task_one)

        floor = IOS27_FLOOR.read_text(encoding="utf-8")
        self.assertIn('[[ -f "$file" && -s "$file" ]]', floor)
        self.assertIn('if [[ "$swift_status" -ne 0 ]]', floor)
        checker = OWNER_CHECKER.read_text(encoding="utf-8")
        self.assertIn("def resolve_anchor_paths(", checker)
        self.assertIn(
            '["git", "ls-tree", "-r", "-z", candidate_tree]',
            checker,
        )
        self.assertIn("missing anchored candidate-tree blob", checker)

    def test_all_four_candidate_category_cli_inputs_are_mandatory(self) -> None:
        checker = OWNER_CHECKER.read_text(encoding="utf-8")
        mandatory = required_add_argument_options(checker)
        category_options = {
            "--create-manifest-or-disposition",
            "--extension-manifest-or-disposition",
            "--adapter-manifest-or-disposition",
            "--fixture-set-or-disposition",
        }
        self.assertTrue(category_options <= mandatory)
        task_one = section(
            self.master,
            "## Task 1: Make W0 Gates Non-Vacuous and Continuous",
            "## Task 2: Atomically Reconcile the Seven Controlled Documents",
        )
        for option in category_options:
            self.assertIn(option, task_one)
        for category in ("Create", "Extension", "Adapter", "Fixture"):
            self.assertIn(f"{category}Gate", task_one)

    def test_w1_dependency_sequence_is_reachable_and_target_legal(self) -> None:
        w1 = section(
            self.master,
            "## Controlled Domain-Plan Payload W1:",
            "## Controlled Domain-Plan Payload W2:",
        )
        markers = [
            "### Payload 3A — Write failing value and wire tests",
            "### Payload 3B — Implement low-entropy values only",
            "### Payload 3C — Freeze the semantic DAG without a scheduler",
            "### Payload 3D — Prove fixtures and authority admission",
            "### Payload 3E — Verify and commit",
        ]
        positions = [w1.index(marker) for marker in markers]
        self.assertEqual(positions, sorted(positions))
        self.assertIn("RuntimeCore cannot import BASMemory", w1)
        self.assertIn("cross-target composition uses `BASArtifactID` references", w1)
        self.assertIn("non-empty Extension/Fixture", w1)
        self.assertIn("original Create manifest only if", w1)

    def test_throughput_is_a_measured_profile_target_not_a_completion_gate(
        self,
    ) -> None:
        self.assertIn(
            "Cold 40 tok/s and sustained 30 tok/s are measured optimization "
            "targets under a declared device/model/thermal protocol, not "
            "unconditional structural completion gates.",
            self.master,
        )
        performance = section(
            self.master,
            "### Payload 10D — Measure performance under a preregistered protocol",
            "### Payload 10E — Prove cardinality and authoritative entrypoints",
        )
        self.assertIn("reported as met/not-met", performance)
        self.assertIn("blocks only the performance target/cutover profile", performance)
        self.assertIn("does not falsify structural completion", performance)

    def test_k4_spike_precedes_production_and_unsupported_is_typed_disabled(
        self,
    ) -> None:
        spike = self.master.index(
            "Put the K4 platform spike in the W0 prerequisite section"
        )
        w1 = self.master.index("## Controlled Domain-Plan Payload W1:")
        w5 = self.master.index("## Controlled Domain-Plan Payload W5:")
        self.assertLess(spike, w1)
        self.assertLess(spike, w5)
        k4_contract = self.master[spike:w1]
        for status in (
            "supportedExactProfile",
            "disabledMissingTarget",
            "disabledMissingEntitlement",
            "disabledMissingDeviceProof",
        ):
            self.assertIn(status, k4_contract)
        self.assertIn(
            "profile remains disabled—never that an in-process substitute silently",
            k4_contract,
        )
        w5_entry = self.master[w5 : self.master.index("### Payload 7A", w5)]
        self.assertIn("no in-process substitute is allowed", w5_entry)
        self.assertIn("exact unexpired", w5_entry)

    def test_provider_executor_and_materialization_have_one_approved_contract(
        self,
    ) -> None:
        remediation = section(
            self.master,
            "- [ ] **Step 2E: Reconcile the K3 and recovery addenda**",
            "- [ ] **Step 2F: Update Owner Ledger without count drift**",
        )
        self.assertIn(
            "`BASProviderAttemptExecutor.executeAtMostOnce` symbol",
            remediation,
        )
        self.assertIn(
            "not from a misleading `executeExactlyOnce` method name",
            remediation,
        )
        self.assertIn(
            "existing materialized-request/execution-plan artifact path",
            remediation,
        )
        self.assertIn(
            "Do not add a fifth reference to the four-reference "
            "`BASProviderStepTemplate` binding",
            remediation,
        )
        self.assertIn(
            "Remove or define every dangling materialization artifact reference "
            "through the existing template mechanism",
            remediation,
        )

    def test_recovery_sentence_and_swift_scan_are_the_approved_mechanical_fixes(
        self,
    ) -> None:
        contents = CONTROLLED_CONVERGENCE.read_text(encoding="utf-8")
        expected_sentence = (
            "The exception cannot imply that a possibly sent provider call, "
            "publication, or effect was not sent. It cannot clear `sent_or_unknown`, "
            "`publication_indeterminate`, or `effect_indeterminate`; those identities "
            "remain blocked/query-only in the same mapped domain owner or an operator "
            "incident record. It cannot waive anti-rollback, restore eligibility, "
            "or manufacture success receipts."
        )
        replacement = section(
            contents,
            "In the delete-and-recreate exception, replace the complete exact phrase",
            "- [ ] **Step 5: Obtain exact RED, GREEN, and the four-path transaction**",
        )
        self.assertEqual(replacement.count(expected_sentence), 1)
        self.assertIn("Do not perform a substring-only replacement", replacement)
        self.assertIn(
            'self.assertNotIn("in a the same mapped domain owner", contents)',
            contents,
        )
        self.assertIn(
            'self.assertNotIn("operator incident record or operator incident '
            'record", contents)',
            contents,
        )
        self.assertIn("scan_swift_active_source", contents)
        self.assertIn('"scanner"] == "swift-active-source-v1"', contents)
        self.assertIn(
            "active_text, lexical_errors = scan_swift_active_source(text)",
            contents,
        )
        self.assertIn("expression-prefix bare slash", contents)
        self.assertNotIn(
            r"\b(import (CoreAI|FoundationModels|MLX)|Qwen3|MiniCPM|Granite)\b",
            contents,
        )

    def test_rsi_wire_compiler_and_known_issue_binding_remain_canonical(self) -> None:
        contents = AGENT_CONTEXT_ADDENDUM.read_text(encoding="utf-8")
        self.assertIn(
            "Swift case `needsConfirmation` has the existing canonical encoded "
            "spelling `needs-confirmation`",
            contents,
        )
        self.assertNotIn("needs_confirmation", contents)
        self.assertIn(
            "`BASContextCompiler` in `ContextCompilerCore.swift` remains the sole "
            "L3 context-packing owner",
            contents,
        )
        self.assertIn(
            "“Context Budget Allocator” and “State Compiler” name two phases",
            contents,
        )
        self.assertIn(
            "→ L3 BASContextCompiler finalization "
            "(context-budget allocation + State Compiler phase)",
            contents,
        )
        self.assertIn("knownIssueSetDigest", contents)
        self.assertIsNone(re.search(r"\bknownIssueSet\b", contents))


if __name__ == "__main__":
    unittest.main()
