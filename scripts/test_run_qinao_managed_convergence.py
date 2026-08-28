"""Tests for the unprivileged Qinao convergence dispatcher."""

from __future__ import annotations

import base64
import hashlib
import io
import json
import os
import stat
import subprocess
import sys
import tempfile
import time
import unittest
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path
from types import SimpleNamespace
from typing import Optional
from unittest import mock

from scripts import run_qinao_managed_convergence as managed


def canonical_bytes(value: object) -> bytes:
    return (
        json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
        + "\n"
    ).encode("utf-8")


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


PYTHON_CODE_LAUNCHER = "exec(__import__('base64').b64decode(__import__('sys').argv[1]))"


def python_code_argv(source: str) -> tuple[str, ...]:
    encoded = base64.b64encode(source.encode("utf-8")).decode("ascii")
    return ("-c", PYTHON_CODE_LAUNCHER, encoded)


def wait_for_path(path: Path, timeout_seconds: float = 5.0) -> bool:
    deadline = time.monotonic() + timeout_seconds
    while time.monotonic() < deadline:
        if path.exists():
            return True
        time.sleep(0.005)
    return path.exists()


def wait_for_process_group_exit(
    process_group_id: int, timeout_seconds: float = 5.0
) -> bool:
    deadline = time.monotonic() + timeout_seconds
    while time.monotonic() < deadline:
        if not managed._process_group_exists(process_group_id):
            return True
        time.sleep(0.01)
    return not managed._process_group_exists(process_group_id)


class RegistryTests(unittest.TestCase):
    def test_managed_series_contains_exactly_nineteen_ordered_transitions(self) -> None:
        self.assertEqual(
            [(row.transition_id, row.operation_id) for row in managed.TRANSITIONS],
            [
                ("01", "root.admission"),
                ("02", "design.edge"),
                ("03", "w0.gates"),
                ("04", "bootstrap.ledger-v2-migration"),
                ("05", "w1.artifact-mesh-contract-freeze"),
                ("06", "w2.state-and-retention"),
                ("07", "w3.state-projections"),
                ("08", "w3.context-convergence"),
                ("09", "w4.model-adaptive-context"),
                ("10", "w5.automation-apple-effects"),
                ("11", "w6.runtime.observation-values"),
                ("12", "w6.semantic.audit-schema"),
                ("13", "w6.runtime.audit-envelope-freeze"),
                ("14", "w6.semantic.coordinator-behavior"),
                ("15", "w6.runtime.integration-population"),
                ("16", "w6.runtime.engine-cutover"),
                ("17", "w6.runtime-receipt-chain"),
                ("18", "w6.apple-lab"),
                ("19", "w6.certification"),
            ],
        )

    def test_runtime_chain_outer_t17_follows_wave_v2_ordinal_12_and_precedes_ordinal_13(
        self,
    ) -> None:
        before, runtime_chain, after = managed.TRANSITIONS[15:18]
        self.assertEqual(
            (before.transition_id, runtime_chain.transition_id, after.transition_id),
            ("16", "17", "18"),
        )
        self.assertEqual(before.operation_id, "w6.runtime.engine-cutover")
        self.assertEqual(runtime_chain.operation_id, "w6.runtime-receipt-chain")
        self.assertEqual(runtime_chain.machine, "runtimeChain")
        self.assertEqual(after.operation_id, "w6.apple-lab")

    def test_w0_and_v2_use_distinct_closed_substate_orderings(self) -> None:
        self.assertEqual(
            managed.MACHINE_STATES["historicalWaveV1"],
            (
                "categoryDraft",
                "categoryReviewed",
                "categoryImported",
                "provisionalIndex",
                "bundleReviewed",
                "finalTree",
                "reportPublished",
                "receiptPublished",
                "exactLocalCommitInstalled",
            ),
        )
        self.assertEqual(
            managed.MACHINE_STATES["steadyStateWaveV2"],
            (
                "categoryDraft",
                "categoryReviewed",
                "categoryImported",
                "finalTree",
                "candidatePrepared",
                "bundleReviewed",
                "reportPublished",
                "controllerInFlight",
                "targetInstalled",
                "receiptPublished",
                "verified",
            ),
        )

    def test_k4_sign_and_import_are_migration_substates(self) -> None:
        states = managed.MACHINE_STATES["ledgerMigration"]
        self.assertLess(states.index("k4Signing"), states.index("k4Signed"))
        self.assertLess(states.index("k4Signed"), states.index("k4Verified"))
        self.assertLess(states.index("k4Verified"), states.index("k4Imported"))
        self.assertLess(states.index("k4Imported"), states.index("candidatePrepared"))


class SourceSelectionTests(unittest.TestCase):
    def _selection(self) -> dict[str, object]:
        rows = []
        for index in range(1, 20):
            head = f"{index:040x}"
            rows.append(
                {
                    "candidateID": f"{index:02d}",
                    "comparisonBaseHEAD": f"{max(1, index - 1):040x}",
                    "head": head,
                    "tree": f"{index + 100:040x}",
                    "selected": index == 1,
                    "committedRows": [],
                    "stagedRows": [],
                    "unstagedRows": [],
                    "untrackedRows": [],
                }
            )
        rows[0]["comparisonBaseHEAD"] = rows[0]["head"]
        return {
            "schemaVersion": "QinaoDualSpaceSourceSelectionV1",
            "repositoryIdentity": "repo.example",
            "selectedHEAD": rows[0]["head"],
            "selectedTree": rows[0]["tree"],
            "approvedDesign": {
                "path": "docs/design.md",
                "commit": "f" * 40,
                "tree": "e" * 40,
                "blob": "d" * 40,
                "byteLength": 1,
                "sha256": "c" * 64,
            },
            "candidateComparisons": rows,
            "reviewerPrincipal": "external-reviewer",
            "reviewerRole": "source-selector",
            "issuedAt": "2026-08-02T00:00:00Z",
            "expiresAt": "2026-08-03T00:00:00Z",
            "nonce": "opaque",
            "signatureAlgorithm": "Ed25519",
            "signature": "external-signature",
        }

    def test_source_selection_rows_map_bijectively_to_transition_registry(self) -> None:
        parsed = managed.parse_source_selection(self._selection())
        self.assertEqual(parsed.repository_identity, "repo.example")
        self.assertEqual(
            tuple(parsed.review_sources), tuple(f"{i:02d}" for i in range(1, 20))
        )
        self.assertEqual(parsed.review_sources["01"].head, parsed.selected_head)

    def test_source_selection_rejects_missing_reordered_selected_or_chainless_row(
        self,
    ) -> None:
        mutations = []
        missing = self._selection()
        missing["candidateComparisons"] = missing["candidateComparisons"][:-1]  # type: ignore[index]
        mutations.append(missing)
        reordered = self._selection()
        rows = reordered["candidateComparisons"]  # type: ignore[assignment]
        rows[3], rows[4] = rows[4], rows[3]  # type: ignore[index]
        mutations.append(reordered)
        selected = self._selection()
        selected["candidateComparisons"][1]["selected"] = True  # type: ignore[index]
        mutations.append(selected)
        chainless = self._selection()
        chainless["candidateComparisons"][8]["comparisonBaseHEAD"] = "a" * 40  # type: ignore[index]
        mutations.append(chainless)
        for value in mutations:
            with self.subTest(), self.assertRaises(managed.ContractError):
                managed.parse_source_selection(value)


class ContractParsingTests(unittest.TestCase):
    def _contract(self, transition_id: str = "01") -> dict[str, object]:
        row = managed.TRANSITIONS[int(transition_id) - 1]
        review = {
            "candidateID": transition_id,
            "comparisonBaseHEAD": "a" * 40,
            "head": "b" * 40,
            "tree": "c" * 40,
        }
        common = [
            "--transition-id",
            "${transitionID}",
            "--operation-id",
            "${operationID}",
            "--source-selection",
            "${sourceSelection}",
            "--trust-root",
            "${trustRoot}",
            "--transition-directory",
            "${transitionDirectory}",
            "--review-head",
            "${reviewSourceHead}",
            "--review-tree",
            "${reviewSourceTree}",
        ]
        return {
            "schema": "QinaoManagedTransitionEndpointContractV1",
            "repositoryIdentity": "repo.example",
            "transitionID": transition_id,
            "operationID": row.operation_id,
            "machine": row.machine,
            "reviewSource": review,
            "actions": {
                "queryExisting": {
                    "action": "queryExisting",
                    "toolName": "closed-endpoint",
                    "endpointKind": "schemaScopedEndpoint",
                    "argv": ["query-existing"] + common,
                },
                "invokeOnce": {
                    "action": "invokeOnce",
                    "toolName": "closed-endpoint",
                    "endpointKind": "schemaScopedEndpoint",
                    "argv": ["invoke-once"]
                    + common
                    + [
                        "--expected-state",
                        "${expectedState}",
                        "--expected-observation-root",
                        "${expectedObservationRoot}",
                        "--claim-key",
                        "${claimKey}",
                    ],
                },
                "verifyExisting": {
                    "action": "verifyExisting",
                    "toolName": "closed-endpoint",
                    "endpointKind": "schemaScopedEndpoint",
                    "argv": ["verify-existing"]
                    + common
                    + [
                        "--expected-state",
                        "${expectedState}",
                        "--expected-observation-root",
                        "${expectedObservationRoot}",
                        "--claim-key",
                        "${claimKey}",
                    ],
                },
            },
        }

    def test_contract_binds_exact_registry_review_row_tool_and_action_templates(
        self,
    ) -> None:
        row = managed.TRANSITIONS[0]
        review = managed.ReviewSource("01", "a" * 40, "b" * 40, "c" * 40)
        parsed = managed.parse_transition_contract(
            self._contract(),
            expected=row,
            repository_identity="repo.example",
            review_source=review,
            tool_endpoint_kinds={"closed-endpoint": "schemaScopedEndpoint"},
            available_bindings=frozenset(("source-selection", "trust-root")),
        )
        self.assertEqual(parsed.transition, row)
        self.assertEqual(frozenset(parsed.actions), managed.CLOSED_ACTIONS)

    def test_contract_rejects_missing_query_template_tool_drift_and_generic_endpoint(
        self,
    ) -> None:
        row = managed.TRANSITIONS[0]
        review = managed.ReviewSource("01", "a" * 40, "b" * 40, "c" * 40)
        values = []
        missing = self._contract()
        del missing["actions"]["queryExisting"]  # type: ignore[index]
        values.append((missing, {"closed-endpoint": "schemaScopedEndpoint"}))
        drift = self._contract()
        drift["actions"]["invokeOnce"]["endpointKind"] = "other"  # type: ignore[index]
        values.append((drift, {"closed-endpoint": "schemaScopedEndpoint"}))
        generic = self._contract()
        generic["actions"]["invokeOnce"]["endpointKind"] = "genericShell"  # type: ignore[index]
        values.append((generic, {"closed-endpoint": "genericShell"}))
        for value, tools in values:
            with self.subTest(), self.assertRaises(managed.ContractError):
                managed.parse_transition_contract(
                    value,
                    expected=row,
                    repository_identity="repo.example",
                    review_source=review,
                    tool_endpoint_kinds=tools,
                    available_bindings=frozenset(("source-selection", "trust-root")),
                )

    def test_invoke_and_verify_templates_must_bind_observation_and_same_claim(
        self,
    ) -> None:
        row = managed.TRANSITIONS[0]
        review = managed.ReviewSource("01", "a" * 40, "b" * 40, "c" * 40)
        for action in ("invokeOnce", "verifyExisting"):
            value = self._contract()
            value["actions"][action]["argv"] = ["unsafe-without-observation-binding"]  # type: ignore[index]
            with self.subTest(action=action), self.assertRaises(managed.ContractError):
                managed.parse_transition_contract(
                    value,
                    expected=row,
                    repository_identity="repo.example",
                    review_source=review,
                    tool_endpoint_kinds={"closed-endpoint": "schemaScopedEndpoint"},
                    available_bindings=frozenset(("source-selection", "trust-root")),
                )

    def test_migration_endpoint_must_bind_its_fixed_transition_directory(self) -> None:
        row = managed.TRANSITIONS[3]
        review = managed.ReviewSource("04", "a" * 40, "b" * 40, "c" * 40)
        value = self._contract("04")
        for action in managed.CLOSED_ACTIONS:
            value["actions"][action]["argv"] = [  # type: ignore[index]
                token
                for token in value["actions"][action]["argv"]  # type: ignore[index]
                if token not in ("--transition-directory", "${transitionDirectory}")
            ]
        with self.assertRaises(managed.ContractError):
            managed.parse_transition_contract(
                value,
                expected=row,
                repository_identity="repo.example",
                review_source=review,
                tool_endpoint_kinds={"closed-endpoint": "schemaScopedEndpoint"},
                available_bindings=frozenset(("source-selection", "trust-root")),
            )


class ParserTests(unittest.TestCase):
    def _minimum_resume_argv(self) -> list[str]:
        return [
            "resume-series",
            "--root",
            "/repo",
            "--source-selection",
            "/selection",
            "--trust-root",
            "/trust",
            "--artifact-root",
            "/artifacts",
            "--bootstrap-manifest",
            "/manifest",
            "--expected-bootstrap-manifest-sha256",
            "0" * 64,
            "--expected-coordinator-sha256",
            "1" * 64,
        ]

    def test_managed_coordinator_exposes_only_resume_series(self) -> None:
        parser = managed.build_parser()
        with redirect_stderr(io.StringIO()), self.assertRaises(SystemExit):
            parser.parse_args(["run-wave"])

    def test_managed_coordinator_has_no_phase_wave_slice_or_previous_selector(
        self,
    ) -> None:
        parser = managed.build_parser()
        forbidden = (
            "--operation",
            "--phase",
            "--wave",
            "--slice",
            "--ordinal",
            "--previous-receipt",
            "--candidate-path-list",
            "--target-ref",
            "--prerequisite",
            "--action",
            "--retry",
            "--risk-tier",
            "--admission-kind",
        )
        base = [
            "resume-series",
            "--root",
            "/repo",
            "--source-selection",
            "/selection",
            "--trust-root",
            "/trust",
            "--artifact-root",
            "/artifacts",
            "--bootstrap-manifest",
            "/manifest",
            "--expected-bootstrap-manifest-sha256",
            "0" * 64,
            "--expected-coordinator-sha256",
            "1" * 64,
        ]
        for option in forbidden:
            with (
                self.subTest(option=option),
                redirect_stderr(io.StringIO()),
                self.assertRaises(SystemExit),
            ):
                parser.parse_args(base + [option, "chosen-by-caller"])

    def test_every_singleton_option_is_required_exactly_once_and_never_abbreviated(
        self,
    ) -> None:
        singleton_options = (
            "--root",
            "--source-selection",
            "--trust-root",
            "--artifact-root",
            "--bootstrap-manifest",
            "--expected-bootstrap-manifest-sha256",
            "--expected-coordinator-sha256",
        )
        parser = managed.build_parser()
        base = self._minimum_resume_argv()
        parser.parse_args(base)
        for option in singleton_options:
            with self.subTest(option=option):
                value_index = base.index(option) + 1
                duplicate = base + [option, base[value_index]]
                with redirect_stderr(io.StringIO()), self.assertRaises(SystemExit):
                    parser.parse_args(duplicate)
        abbreviated = list(base)
        abbreviated[abbreviated.index("--root")] = "--roo"
        with redirect_stderr(io.StringIO()), self.assertRaises(SystemExit):
            parser.parse_args(abbreviated)


class TemplateTests(unittest.TestCase):
    def _template(self, action: str, argv: list[str]) -> managed.ActionTemplate:
        return managed.ActionTemplate(
            action=action,
            tool_name="endpoint",
            endpoint_kind="schemaScopedTestEndpoint",
            argv=tuple(argv),
        )

    def test_exact_argv_template_is_rendered_without_shell_or_environment_expansion(
        self,
    ) -> None:
        template = self._template(
            "queryExisting",
            [
                "query-existing",
                "--transition-id",
                "${transitionID}",
                "--operation-id",
                "${operationID}",
                "--selection",
                "${sourceSelection}",
                "--review-head",
                "${reviewSourceHead}",
            ],
        )
        rendered = managed.render_argv(
            template,
            {
                "transitionID": "01",
                "operationID": "root.admission",
                "sourceSelection": "/outside/selection.json",
                "reviewSourceHead": "a" * 40,
            },
        )
        self.assertEqual(
            rendered,
            (
                "query-existing",
                "--transition-id",
                "01",
                "--operation-id",
                "root.admission",
                "--selection",
                "/outside/selection.json",
                "--review-head",
                "a" * 40,
            ),
        )

    def test_template_rejects_secret_environment_shell_and_unknown_placeholders(
        self,
    ) -> None:
        bad = (
            ["query", "${env:HOME}"],
            ["query", "$HOME"],
            ["query", "$(touch /tmp/no)"],
            ["query", "${privateKey}"],
            ["query", "${unknown}"],
            ["query;", "anything"],
        )
        for argv in bad:
            with self.subTest(argv=argv), self.assertRaises(managed.ContractError):
                managed.validate_template(self._template("queryExisting", argv))

    def test_template_actions_are_closed(self) -> None:
        with self.assertRaises(managed.ContractError):
            managed.validate_template(self._template("sign", ["sign"]))


class ObservationTests(unittest.TestCase):
    def _observation(self, **changes: object) -> dict[str, object]:
        value: dict[str, object] = {
            "schema": "QinaoManagedTransitionObservationV1",
            "repositoryIdentity": "repo.example",
            "transitionID": "01",
            "operationID": "root.admission",
            "machine": "rootAdmission",
            "state": "absent",
            "disposition": "eligibleFresh",
            "claimKey": None,
            "outcome": "pending",
            "reviewSource": {
                "candidateID": "01",
                "comparisonBaseHEAD": "a" * 40,
                "head": "a" * 40,
                "tree": "b" * 40,
            },
        }
        value.update(changes)
        value["observationRoot"] = managed.observation_root(value)
        return value

    def test_observation_root_and_review_source_are_rederived(self) -> None:
        expected = managed.TRANSITIONS[0]
        review = managed.ReviewSource(
            candidate_id="01",
            comparison_base_head="a" * 40,
            head="a" * 40,
            tree="b" * 40,
        )
        parsed = managed.parse_observation(
            self._observation(), expected, "repo.example", review
        )
        self.assertEqual(parsed.state, "absent")
        broken = self._observation()
        broken["reviewSource"] = dict(broken["reviewSource"], head="c" * 40)  # type: ignore[arg-type]
        broken["observationRoot"] = managed.observation_root(broken)
        with self.assertRaises(managed.SourceDriftError):
            managed.parse_observation(broken, expected, "repo.example", review)

    def test_nonabsent_state_requires_same_durable_claim_identity(self) -> None:
        expected = managed.TRANSITIONS[0]
        review = managed.ReviewSource("01", "a" * 40, "a" * 40, "b" * 40)
        value = self._observation(
            state="signingInFlight",
            disposition="resumeExisting",
            claimKey=None,
        )
        with self.assertRaises(managed.ContractError):
            managed.parse_observation(value, expected, "repo.example", review)

    def test_unknown_outcome_is_query_only_not_success(self) -> None:
        expected = managed.TRANSITIONS[0]
        review = managed.ReviewSource("01", "a" * 40, "a" * 40, "b" * 40)
        value = self._observation(
            state="signingInFlight",
            disposition="queryOnly",
            claimKey="claim-01",
            outcome="unknown",
        )
        parsed = managed.parse_observation(value, expected, "repo.example", review)
        decision = managed.decide(parsed, expected)
        self.assertEqual(decision.action, "blocked")
        self.assertEqual(decision.code, "BLOCKED_UNKNOWN_OUTCOME_QUERY_ONLY")


class DispatcherTests(unittest.TestCase):
    def _review(self, transition_id: str) -> managed.ReviewSource:
        number = int(transition_id)
        return managed.ReviewSource(
            candidate_id=transition_id,
            comparison_base_head=f"{number - 1:040x}",
            head=f"{number:040x}",
            tree=f"{number + 100:040x}",
        )

    def _contract(self, row: managed.TransitionSpec) -> managed.TransitionContract:
        shared = [
            "--transition-id",
            "${transitionID}",
            "--operation-id",
            "${operationID}",
            "--review-head",
            "${reviewSourceHead}",
            "--review-tree",
            "${reviewSourceTree}",
        ]
        return managed.TransitionContract(
            transition=row,
            review_source=self._review(row.transition_id),
            actions={
                "queryExisting": managed.ActionTemplate(
                    "queryExisting", "endpoint", "test", tuple(["query"] + shared)
                ),
                "invokeOnce": managed.ActionTemplate(
                    "invokeOnce",
                    "endpoint",
                    "test",
                    tuple(
                        ["invoke"]
                        + shared
                        + [
                            "--expected-state",
                            "${expectedState}",
                            "--expected-observation-root",
                            "${expectedObservationRoot}",
                            "--claim-key",
                            "${claimKey}",
                        ]
                    ),
                ),
                "verifyExisting": managed.ActionTemplate(
                    "verifyExisting",
                    "endpoint",
                    "test",
                    tuple(
                        ["verify"]
                        + shared
                        + [
                            "--expected-state",
                            "${expectedState}",
                            "--expected-observation-root",
                            "${expectedObservationRoot}",
                            "--claim-key",
                            "${claimKey}",
                        ]
                    ),
                ),
            },
        )

    def _obs(
        self,
        row: managed.TransitionSpec,
        state: str,
        *,
        disposition: str,
        outcome: str = "pending",
        claim: Optional[str] = "same-claim",
    ) -> managed.Observation:
        value: dict[str, object] = {
            "schema": "QinaoManagedTransitionObservationV1",
            "repositoryIdentity": "repo.example",
            "transitionID": row.transition_id,
            "operationID": row.operation_id,
            "machine": row.machine,
            "state": state,
            "disposition": disposition,
            "claimKey": claim,
            "outcome": outcome,
            "reviewSource": self._review(row.transition_id).as_dict(),
        }
        value["observationRoot"] = managed.observation_root(value)
        return managed.parse_observation(
            value, row, "repo.example", self._review(row.transition_id)
        )

    def test_resume_queries_before_every_invoke_and_keeps_same_claim(self) -> None:
        row = managed.TRANSITIONS[0]
        calls: list[tuple[str, tuple[str, ...]]] = []
        responses = iter(
            [
                self._obs(row, "signingInFlight", disposition="resumeExisting"),
                self._obs(row, "receiptPublished", disposition="resumeExisting"),
            ]
        )

        def call(action: str, argv: tuple[str, ...]) -> managed.Observation:
            calls.append((action, argv))
            if action == "queryExisting":
                return next(responses)
            return self._obs(row, "signingInFlight", disposition="resumeExisting")

        result = managed.dispatch_one_step(
            self._contract(row),
            repository_identity="repo.example",
            base_context={},
            call=call,
        )
        self.assertEqual(
            [name for name, _ in calls],
            ["queryExisting", "invokeOnce", "queryExisting"],
        )
        self.assertEqual(result.state, "receiptPublished")
        self.assertIn("same-claim", calls[1][1])

    def test_unknown_invoke_result_is_queried_and_never_blindly_retried(self) -> None:
        row = managed.TRANSITIONS[3]
        calls: list[str] = []
        query_count = 0

        def call(action: str, argv: tuple[str, ...]) -> managed.Observation:
            nonlocal query_count
            del argv
            calls.append(action)
            if action == "queryExisting":
                query_count += 1
                if query_count == 1:
                    return self._obs(
                        row, "controllerInFlight", disposition="resumeExisting"
                    )
                return self._obs(
                    row,
                    "controllerInFlight",
                    disposition="queryOnly",
                    outcome="unknown",
                )
            raise managed.EndpointUnknownOutcome("simulated connection loss")

        result = managed.dispatch_one_step(
            self._contract(row),
            repository_identity="repo.example",
            base_context={},
            call=call,
        )
        self.assertEqual(calls, ["queryExisting", "invokeOnce", "queryExisting"])
        self.assertEqual(result.status, "blocked")
        self.assertEqual(result.code, "BLOCKED_UNKNOWN_OUTCOME_QUERY_ONLY")

    def test_source_drift_after_query_stops_before_invoke(self) -> None:
        row = managed.TRANSITIONS[4]
        calls: list[str] = []

        def call(action: str, argv: tuple[str, ...]) -> managed.Observation:
            del argv
            calls.append(action)
            if action != "queryExisting":
                self.fail("effect invoked after source drift")
            changed = self._obs(row, "categoryDraft", disposition="resumeExisting")
            return managed.Observation(
                **{**changed.__dict__, "review_source": self._review("06")}
            )

        with self.assertRaises(managed.SourceDriftError):
            managed.dispatch_one_step(
                self._contract(row),
                repository_identity="repo.example",
                base_context={},
                call=call,
            )
        self.assertEqual(calls, ["queryExisting"])

    def test_terminal_state_uses_verify_existing_never_invoke(self) -> None:
        row = managed.TRANSITIONS[16]
        calls: list[str] = []
        responses = iter(
            [
                self._obs(
                    row, "published", disposition="resumeExisting", outcome="passed"
                ),
                self._obs(row, "verified", disposition="verified", outcome="passed"),
            ]
        )

        def call(action: str, argv: tuple[str, ...]) -> managed.Observation:
            del argv
            calls.append(action)
            if action == "queryExisting":
                return next(responses)
            return self._obs(
                row, "published", disposition="resumeExisting", outcome="passed"
            )

        result = managed.dispatch_one_step(
            self._contract(row), "repo.example", {}, call
        )
        self.assertEqual(calls, ["queryExisting", "verifyExisting", "queryExisting"])
        self.assertEqual(result.status, "complete")
        self.assertEqual(result.claim_key, "same-claim")

    def test_ambiguous_unowned_or_claim_changed_poststate_is_quarantined(self) -> None:
        row = managed.TRANSITIONS[2]
        calls: list[str] = []
        responses = iter(
            [
                self._obs(
                    row,
                    "reportPublished",
                    disposition="resumeExisting",
                    claim="claim-a",
                ),
                self._obs(
                    row,
                    "receiptPublished",
                    disposition="resumeExisting",
                    claim="claim-b",
                ),
            ]
        )

        def call(action: str, argv: tuple[str, ...]) -> managed.Observation:
            del argv
            calls.append(action)
            if action == "queryExisting":
                return next(responses)
            return self._obs(
                row, "reportPublished", disposition="resumeExisting", claim="claim-a"
            )

        result = managed.dispatch_one_step(
            self._contract(row), "repo.example", {}, call
        )
        self.assertEqual(result.status, "quarantined")
        self.assertEqual(result.code, "QUARANTINED_CLAIM_IDENTITY_DRIFT")
        self.assertEqual(calls, ["queryExisting", "invokeOnce", "queryExisting"])

    def test_interruption_boundary_restarts_with_query_not_journal_state(self) -> None:
        row = managed.TRANSITIONS[2]
        contract = self._contract(row)
        first_calls: list[str] = []

        def interrupted(action: str, argv: tuple[str, ...]) -> managed.Observation:
            del argv
            first_calls.append(action)
            if action == "queryExisting":
                return self._obs(row, "bundleReviewed", disposition="resumeExisting")
            raise KeyboardInterrupt

        with self.assertRaises(KeyboardInterrupt):
            managed.dispatch_one_step(contract, "repo.example", {}, interrupted)
        self.assertEqual(first_calls, ["queryExisting", "invokeOnce"])

        resumed_calls: list[str] = []

        def resumed(action: str, argv: tuple[str, ...]) -> managed.Observation:
            del argv
            resumed_calls.append(action)
            return self._obs(
                row,
                "finalTree",
                disposition="resumeExisting",
                claim="same-claim",
            )

        managed.dispatch_one_step(contract, "repo.example", {}, resumed)
        self.assertEqual(resumed_calls[0], "queryExisting")

    def test_every_declared_interruption_boundary_resumes_by_query(self) -> None:
        representatives = {
            "rootAdmission": managed.TRANSITIONS[0],
            "designEdge": managed.TRANSITIONS[1],
            "historicalWaveV1": managed.TRANSITIONS[2],
            "ledgerMigration": managed.TRANSITIONS[3],
            "steadyStateWaveV2": managed.TRANSITIONS[4],
            "runtimeChain": managed.TRANSITIONS[16],
        }
        for machine, row in representatives.items():
            for state in managed.MACHINE_STATES[machine][:-1]:
                if state in managed.VERIFY_STATES[machine]:
                    continue
                calls: list[str] = []

                def interrupted(
                    action: str, argv: tuple[str, ...], *, current: str = state
                ) -> managed.Observation:
                    del argv
                    calls.append(action)
                    if action == "queryExisting":
                        claim = (
                            None
                            if current in ("absent", "k4Absent", "categoryDraft")
                            else "same-claim"
                        )
                        return self._obs(
                            row,
                            current,
                            disposition="eligibleFresh"
                            if claim is None
                            else "resumeExisting",
                            claim=claim,
                        )
                    raise KeyboardInterrupt

                with (
                    self.subTest(machine=machine, state=state),
                    self.assertRaises(KeyboardInterrupt),
                ):
                    managed.dispatch_one_step(
                        self._contract(row), "repo.example", {}, interrupted
                    )
                self.assertEqual(calls, ["queryExisting", "invokeOnce"])

                resumed_calls: list[str] = []

                def resumed(
                    action: str, argv: tuple[str, ...], *, current: str = state
                ) -> managed.Observation:
                    del argv
                    resumed_calls.append(action)
                    claim = (
                        None
                        if current in ("absent", "k4Absent", "categoryDraft")
                        else "same-claim"
                    )
                    return self._obs(
                        row,
                        current,
                        disposition="eligibleFresh"
                        if claim is None
                        else "resumeExisting",
                        claim=claim,
                    )

                managed.dispatch_one_step(
                    self._contract(row), "repo.example", {}, resumed
                )
                self.assertEqual(resumed_calls[0], "queryExisting")

    def test_full_series_completes_only_after_all_nineteen_external_terminals(
        self,
    ) -> None:
        contracts = {
            row.transition_id: self._contract(row) for row in managed.TRANSITIONS
        }
        positions = {row.transition_id: 0 for row in managed.TRANSITIONS}
        verified = []

        def caller_for(contract: managed.TransitionContract):
            row = contract.transition

            def call(action: str, argv: tuple[str, ...]) -> managed.Observation:
                del argv
                states = managed.MACHINE_STATES[row.machine]
                index = positions[row.transition_id]
                state = states[index]
                if action == "invokeOnce":
                    positions[row.transition_id] = min(index + 1, len(states) - 1)
                elif action == "verifyExisting":
                    positions[row.transition_id] = len(states) - 1
                    verified.append(row.transition_id)
                state = states[positions[row.transition_id]]
                final = positions[row.transition_id] == len(states) - 1
                claim = (
                    None
                    if positions[row.transition_id] == 0
                    else f"claim-{row.transition_id}"
                )
                return self._obs(
                    row,
                    state,
                    disposition="verified"
                    if final
                    else ("eligibleFresh" if claim is None else "resumeExisting"),
                    outcome="passed" if final else "pending",
                    claim=claim,
                )

            return call

        result = managed.resume_contract_series(
            contracts,
            repository_identity="repo.example",
            base_context_for=lambda contract: {},
            caller_for=caller_for,
        )
        self.assertEqual(result.status, "complete")
        self.assertEqual(result.code, "COMPLETE_MANAGED_CONVERGENCE")
        self.assertEqual(result.transition_id, "19")
        self.assertEqual(result.claim_key, "claim-19")
        self.assertTrue(
            all(
                positions[row.transition_id]
                == len(managed.MACHINE_STATES[row.machine]) - 1
                for row in managed.TRANSITIONS
            )
        )

    def test_missing_postmigration_policy_template_is_typed_blocked(self) -> None:
        contracts = {
            row.transition_id: self._contract(row) for row in managed.TRANSITIONS[:4]
        }
        with self.assertRaises(managed.BlockedCondition) as caught:
            managed.resume_contract_series(
                contracts,
                repository_identity="repo.example",
                base_context_for=lambda contract: {},
                caller_for=lambda contract: (
                    lambda action, argv: self._obs(
                        contract.transition,
                        managed.MACHINE_STATES[contract.transition.machine][-1],
                        disposition="verified",
                        outcome="passed",
                        claim="terminal-claim",
                    )
                ),
            )
        self.assertEqual(
            caught.exception.code, "BLOCKED_MISSING_ADMITTED_POLICY_TEMPLATE"
        )


class JournalTests(unittest.TestCase):
    def test_operation_journal_is_content_free_non_authoritative_projection(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "observations.jsonl"
            journal = managed.ObservationJournal(path)
            journal.append(
                transition_id="04",
                operation_id="bootstrap.ledger-v2-migration",
                action="invokeOnce",
                event="unknown",
                contract_sha256="a" * 64,
                observation_root="b" * 64,
                return_code=None,
                stdout_sha256="c" * 64,
                stderr_sha256="d" * 64,
            )
            mode = stat.S_IMODE(path.stat().st_mode)
            self.assertEqual(mode, 0o600)
            row = json.loads(path.read_text(encoding="utf-8"))
            self.assertEqual(row["authority"], "none-local-diagnostic-projection")
            forbidden = {
                "receipt",
                "previousReceipt",
                "challenge",
                "nonce",
                "privateKey",
                "credential",
                "claimPayload",
                "success",
            }
            self.assertTrue(forbidden.isdisjoint(row))


class EnvironmentTests(unittest.TestCase):
    def test_endpoint_environment_contains_no_parent_secret_or_operator_choice(
        self,
    ) -> None:
        env = managed.endpoint_environment(
            {
                "HOME": "/secret/home",
                "AWS_SECRET_ACCESS_KEY": "secret",
                "QINAO_PRIVATE_KEY": "secret",
                "QINAO_RISK_TIER": "authorityTransition",
                "PATH": "/attacker/bin",
            }
        )
        self.assertEqual(
            env,
            {
                "LANG": "C",
                "LC_ALL": "C",
                "PYTHONDONTWRITEBYTECODE": "1",
                "TZ": "UTC",
            },
        )


class CanonicalJSONTests(unittest.TestCase):
    def test_canonical_serializer_rejects_nonfinite_numbers(self) -> None:
        for value in (float("nan"), float("inf"), float("-inf")):
            with self.subTest(value=value), self.assertRaises(ValueError):
                managed.canonical_json_bytes({"value": value})

    def test_canonical_parser_rejects_nonfinite_json_constants(self) -> None:
        for token in (b"NaN", b"Infinity", b"-Infinity"):
            with self.subTest(token=token), self.assertRaises(managed.ContractError):
                managed._json_no_duplicates(b'{"value":' + token + b"}\n")


class LaunchContractTests(unittest.TestCase):
    def _manifest(self) -> dict[str, object]:
        return {
            "schema": "QinaoConvergenceBootstrapLaunchManifestV1",
            "repositoryIdentity": "repo.example",
            "activePlan": {"path": "docs/active.md", "sha256": "a" * 64},
            "coordinator": {"sha256": "b" * 64},
            "artifactRootIdentity": {
                "realPathDigest": "c" * 64,
                "fileSystemID": 1,
                "directoryFileID": 2,
                "ownerID": 3,
                "mode": "0700",
            },
            "transitionRange": {"first": 1, "last": 4},
            "toolRows": [
                {
                    "transitionIDs": ["01", "02", "03", "04"],
                    "name": "closed-endpoint",
                    "sha256": "d" * 64,
                    "role": "incumbent-verifier",
                    "endpointKind": "schemaScopedEndpoint",
                }
            ],
            "inputRows": [
                {
                    "transitionID": "01",
                    "name": "source-selection",
                    "schema": "QinaoDualSpaceSourceSelectionV1",
                    "sha256": "e" * 64,
                    "requiredRole": "source-selector",
                },
                {
                    "transitionID": "01",
                    "name": "trust-root",
                    "schema": "QinaoAdmissionTrustRootV1",
                    "sha256": "f" * 64,
                    "requiredRole": "public-verifier-root",
                },
                {
                    "transitionID": "01",
                    "name": "transition-01-endpoint-contract",
                    "schema": "QinaoManagedTransitionEndpointContractV1",
                    "sha256": "1" * 64,
                    "requiredRole": "dispatcher-contract",
                },
            ],
        }

    def test_bootstrap_manifest_has_closed_range_rows_and_no_authority_fields(
        self,
    ) -> None:
        parsed = managed.parse_bootstrap_manifest(self._manifest())
        self.assertEqual(parsed.repository_identity, "repo.example")
        self.assertEqual(tuple(parsed.tool_rows), ("closed-endpoint",))
        self.assertEqual(parsed.transition_range, (1, 4))

    def test_bootstrap_manifest_rejects_postmigration_binding_secret_or_selector(
        self,
    ) -> None:
        values = []
        postmigration = self._manifest()
        postmigration["toolRows"][0]["transitionIDs"].append("05")  # type: ignore[index]
        values.append(postmigration)
        secret = self._manifest()
        secret["privateKey"] = "never"
        values.append(secret)
        selector = self._manifest()
        selector["operationID"] = "chosen"
        values.append(selector)
        for value in values:
            with self.subTest(), self.assertRaises(managed.ContractError):
                managed.parse_bootstrap_manifest(value)

    def test_binding_parser_is_bijective_and_rejects_duplicate_or_relative_path(
        self,
    ) -> None:
        self.assertEqual(
            managed.parse_bindings(["one=/absolute/one", "two=/absolute/two"]),
            {"one": Path("/absolute/one"), "two": Path("/absolute/two")},
        )
        for rows in (
            ["one=/absolute/one", "one=/absolute/two"],
            ["one=relative"],
            ["bad name=/absolute/one"],
            ["no-equals"],
        ):
            with self.subTest(rows=rows), self.assertRaises(managed.ContractError):
                managed.parse_bindings(rows)

    def test_missing_external_role_is_typed_blocked_not_complete(self) -> None:
        manifest = managed.parse_bootstrap_manifest(self._manifest())
        with self.assertRaises(managed.BlockedCondition) as caught:
            managed.resolve_tool_bindings(manifest, {})
        self.assertEqual(caught.exception.code, "BLOCKED_MISSING_TOOL_BINDING")


class EndpointRunnerTests(unittest.TestCase):
    def _observation_bytes(self) -> bytes:
        value: dict[str, object] = {
            "schema": "QinaoManagedTransitionObservationV1",
            "repositoryIdentity": "repo.example",
            "transitionID": "01",
            "operationID": "root.admission",
            "machine": "rootAdmission",
            "state": "signingInFlight",
            "disposition": "resumeExisting",
            "claimKey": "existing-claim",
            "outcome": "pending",
            "reviewSource": {
                "candidateID": "01",
                "comparisonBaseHEAD": "a" * 40,
                "head": "a" * 40,
                "tree": "b" * 40,
            },
        }
        value["observationRoot"] = managed.observation_root(value)
        return canonical_bytes(value)

    def _contract(self) -> managed.TransitionContract:
        row = managed.TRANSITIONS[0]
        review = managed.ReviewSource("01", "a" * 40, "a" * 40, "b" * 40)
        actions = {}
        for action, command in (
            ("queryExisting", "query"),
            ("invokeOnce", "invoke"),
            ("verifyExisting", "verify"),
        ):
            actions[action] = managed.ActionTemplate(
                action, "closed-endpoint", "schemaScopedEndpoint", (command,)
            )
        return managed.TransitionContract(row, review, actions)

    def _runner_for_script(
        self,
        root: Path,
        script: str,
        *,
        bind_generated_executable: bool = False,
    ) -> tuple[managed.EndpointRunner, Path, Path, tuple[str, ...]]:
        if bind_generated_executable:
            executable = root / "endpoint.py"
            executable.write_text(script, encoding="utf-8")
            executable.chmod(0o700)
            command_prefix: tuple[str, ...] = ()
        else:
            executable = Path("/usr/bin/python3")
            command_prefix = python_code_argv(script)
        journal_path = root / "journal.jsonl"
        return (
            managed.EndpointRunner(
                repository_identity="repo.example",
                tools={
                    "closed-endpoint": managed.BoundTool(
                        executable,
                        sha256_bytes(executable.read_bytes()),
                        "schemaScopedEndpoint",
                    )
                },
                journal=managed.ObservationJournal(journal_path),
                immutable_files={},
            ),
            executable,
            journal_path,
            command_prefix,
        )

    def _bounded_process_for_code(self, source: str) -> subprocess.Popen:
        executable = "/usr/bin/python3"
        return subprocess.Popen(
            (executable,) + python_code_argv(source),
            executable=executable,
            stdin=subprocess.DEVNULL,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            env=os.environ.copy(),
            start_new_session=True,
        )

    def test_drip_feed_cannot_extend_the_single_absolute_endpoint_deadline(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            ready_path = Path(temporary) / "drip-feed-ready"
            process = self._bounded_process_for_code(
                "import os,time\n"
                "from pathlib import Path\n"
                "os.write(1,b'x')\n"
                f"Path({str(ready_path)!r}).write_text('ready')\n"
                "for _ in range(3000):\n"
                " os.write(1,b'x')\n"
                " time.sleep(0.01)\n"
            )
            try:
                self.assertTrue(
                    wait_for_path(ready_path),
                    "drip-feed fixture did not become ready",
                )
                with mock.patch.object(managed, "ENDPOINT_TIMEOUT_SECONDS", 0.12):
                    result = managed._collect_bounded_process_output(process)
                self.assertTrue(result.timed_out)
                self.assertFalse(result.stream_limit_exceeded)
                self.assertGreaterEqual(len(result.stdout), 1)
                self.assertIsNone(result.return_code)
            finally:
                managed._terminate_process_group(process)
                managed._close_process_pipes(process)

    def test_each_stream_accepts_exactly_one_megabyte_and_rejects_one_byte_more(
        self,
    ) -> None:
        limit = managed.ENDPOINT_STREAM_LIMIT_BYTES
        for stream_name, descriptor in (("stdout", 1), ("stderr", 2)):
            for byte_count, rejected in ((limit, False), (limit + 1, True)):
                with self.subTest(
                    stream=stream_name, byte_count=byte_count, rejected=rejected
                ):
                    process = self._bounded_process_for_code(
                        "import os\n"
                        f"payload=b'x'*{byte_count}\n"
                        f"view=memoryview(payload)\nwhile view:\n written=os.write({descriptor},view)\n view=view[written:]\n"
                    )
                    try:
                        result = managed._collect_bounded_process_output(process)
                        self.assertEqual(result.stream_limit_exceeded, rejected)
                        captured = (
                            result.stdout if stream_name == "stdout" else result.stderr
                        )
                        self.assertEqual(len(captured), limit)
                        if not rejected:
                            self.assertEqual(result.return_code, 0)
                            self.assertFalse(result.timed_out)
                    finally:
                        if process.poll() is None:
                            managed._terminate_process_group(process)
                        managed._close_process_pipes(process)

    def test_output_cap_kills_term_ignoring_descendant_and_records_unknown(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            descendant_marker = root / "descendant-survived"
            descendant_pid = root / "descendant-pid"
            descendant_code = (
                "import signal,time;from pathlib import Path;"
                "signal.signal(signal.SIGTERM,signal.SIG_IGN);"
                "time.sleep(0.35);"
                f"Path({str(descendant_marker)!r}).write_text('survived')"
            )
            runner, _, journal_path, command_prefix = self._runner_for_script(
                root,
                "#!/usr/bin/python3\n"
                "import os,subprocess,sys,time\n"
                f"child=subprocess.Popen([sys.executable,'-c',{descendant_code!r}],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)\n"
                f"fd=os.open({str(descendant_pid)!r},os.O_WRONLY|os.O_CREAT,0o600)\n"
                "os.write(fd,str(child.pid).encode());os.close(fd)\n"
                f"payload=b'x'*({managed.ENDPOINT_STREAM_LIMIT_BYTES}+1)\n"
                "view=memoryview(payload)\n"
                "while view:\n"
                " written=os.write(1,view)\n"
                " view=view[written:]\n"
                "time.sleep(1)\n",
            )
            with (
                mock.patch.object(managed, "PROCESS_GROUP_TERM_GRACE_SECONDS", 0.04),
                self.assertRaises(managed.EndpointUnknownOutcome),
            ):
                runner.call(
                    self._contract(), "invokeOnce", command_prefix + ("invoke",)
                )
            self.assertTrue(descendant_pid.exists())
            time.sleep(0.4)
            self.assertFalse(descendant_marker.exists())
            rows = [
                json.loads(line)
                for line in journal_path.read_text(encoding="utf-8").splitlines()
            ]
            self.assertEqual([row["event"] for row in rows], ["launching", "unknown"])

    def test_zero_exit_leader_with_live_descendant_is_unknown_and_group_is_cleaned(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            descendant_marker = root / "descendant-survived"
            descendant_pid = root / "descendant-pid"
            descendant_code = (
                "import signal,time;from pathlib import Path;"
                "signal.signal(signal.SIGTERM,signal.SIG_IGN);"
                "time.sleep(0.35);"
                f"Path({str(descendant_marker)!r}).write_text('survived')"
            )
            runner, _, journal_path, command_prefix = self._runner_for_script(
                root,
                "#!/usr/bin/python3\n"
                "import os,subprocess,sys\n"
                f"child=subprocess.Popen([sys.executable,'-c',{descendant_code!r}],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)\n"
                f"fd=os.open({str(descendant_pid)!r},os.O_WRONLY|os.O_CREAT,0o600)\n"
                "os.write(fd,str(child.pid).encode());os.close(fd)\n"
                f"os.write(1,{self._observation_bytes()!r})\n",
            )
            with (
                mock.patch.object(managed, "PROCESS_GROUP_TERM_GRACE_SECONDS", 0.04),
                self.assertRaises(managed.EndpointUnknownOutcome),
            ):
                runner.call(
                    self._contract(), "queryExisting", command_prefix + ("query",)
                )
            self.assertTrue(descendant_pid.exists())
            time.sleep(0.4)
            self.assertFalse(descendant_marker.exists())
            rows = [
                json.loads(line)
                for line in journal_path.read_text(encoding="utf-8").splitlines()
            ]
            self.assertEqual([row["event"] for row in rows], ["launching", "unknown"])

    def test_user_replaceable_endpoint_is_rejected_before_journal_or_execution(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            execution_marker = root / "executed"
            runner, _, journal_path, command_prefix = self._runner_for_script(
                root,
                "#!/usr/bin/python3\n"
                f"open({str(execution_marker)!r},'w').write('executed')\n",
                bind_generated_executable=True,
            )
            with self.assertRaises(managed.ContractError):
                runner.call(
                    self._contract(), "queryExisting", command_prefix + ("query",)
                )
            self.assertFalse(execution_marker.exists())
            self.assertFalse(journal_path.exists())

    def test_timeout_terminates_the_endpoint_process_group_and_records_unknown(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            descendant_pid = root / "descendant-pid"
            descendant_code = (
                "import signal,time;"
                "signal.signal(signal.SIGTERM,signal.SIG_IGN);"
                "time.sleep(30)"
            )
            runner, _, journal_path, command_prefix = self._runner_for_script(
                root,
                "#!/usr/bin/python3\n"
                "import os,subprocess,sys,time\n"
                f"child=subprocess.Popen([sys.executable,'-c',{descendant_code!r}])\n"
                f"fd=os.open({str(descendant_pid)!r},os.O_WRONLY|os.O_CREAT,0o600)\n"
                "os.write(fd,str(child.pid).encode());os.close(fd)\n"
                "time.sleep(30)\n",
            )
            real_popen = subprocess.Popen
            launched: list[subprocess.Popen] = []

            def launch_after_fixture_is_ready(*args: object, **kwargs: object):
                process = real_popen(*args, **kwargs)
                launched.append(process)
                if wait_for_path(descendant_pid):
                    return process
                managed._terminate_process_group(process)
                managed._close_process_pipes(process)
                self.fail("endpoint fixture did not publish its descendant PID")

            try:
                with (
                    mock.patch.object(
                        managed.subprocess,
                        "Popen",
                        side_effect=launch_after_fixture_is_ready,
                    ),
                    mock.patch.object(
                        managed, "ENDPOINT_TIMEOUT_SECONDS", 0.15, create=True
                    ),
                    mock.patch.object(
                        managed,
                        "PROCESS_GROUP_TERM_GRACE_SECONDS",
                        0.04,
                        create=True,
                    ),
                    self.assertRaises(managed.EndpointUnknownOutcome),
                ):
                    runner.call(
                        self._contract(),
                        "invokeOnce",
                        command_prefix + ("invoke",),
                    )
                self.assertEqual(len(launched), 1)
                self.assertTrue(descendant_pid.is_file())
                self.assertTrue(
                    wait_for_process_group_exit(launched[0].pid),
                    "endpoint process group remained after timeout cleanup",
                )
                rows = [
                    json.loads(line)
                    for line in journal_path.read_text(encoding="utf-8").splitlines()
                ]
                self.assertEqual(
                    [row["event"] for row in rows], ["launching", "unknown"]
                )
            finally:
                for process in launched:
                    if managed._process_group_exists(process.pid):
                        managed._terminate_process_group(process)
                    managed._close_process_pipes(process)

    def test_nonzero_endpoint_kills_term_ignoring_descendant_before_it_can_escape(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            descendant_marker = root / "descendant-survived"
            descendant_pid = root / "descendant-pid"
            descendant_code = (
                "import signal,time;from pathlib import Path;"
                "signal.signal(signal.SIGTERM,signal.SIG_IGN);"
                "time.sleep(0.35);"
                f"Path({str(descendant_marker)!r}).write_text('survived')"
            )
            runner, _, journal_path, command_prefix = self._runner_for_script(
                root,
                "#!/usr/bin/python3\n"
                "import os,subprocess,sys\n"
                f"child=subprocess.Popen([sys.executable,'-c',{descendant_code!r}])\n"
                f"fd=os.open({str(descendant_pid)!r},os.O_WRONLY|os.O_CREAT,0o600)\n"
                "os.write(fd,str(child.pid).encode());os.close(fd)\n"
                "raise SystemExit(7)\n",
            )
            with (
                mock.patch.object(
                    managed, "PROCESS_GROUP_TERM_GRACE_SECONDS", 0.04, create=True
                ),
                self.assertRaises(managed.EndpointUnknownOutcome),
            ):
                runner.call(
                    self._contract(), "invokeOnce", command_prefix + ("invoke",)
                )
            self.assertTrue(descendant_pid.exists())
            time.sleep(0.4)
            self.assertFalse(descendant_marker.exists())
            rows = [
                json.loads(line)
                for line in journal_path.read_text(encoding="utf-8").splitlines()
            ]
            self.assertEqual(rows[-1]["event"], "unknown")
            self.assertEqual(rows[-1]["returnCode"], 7)

    def test_each_output_stream_has_a_live_one_megabyte_hard_cap(self) -> None:
        for stream in ("stdout", "stderr"):
            with (
                self.subTest(stream=stream),
                tempfile.TemporaryDirectory() as temporary,
            ):
                root = Path(temporary)
                if stream == "stdout":
                    body = "os.write(1,b'x'*(1024*1024+1))\n"
                else:
                    body = (
                        "os.write(2,b'x'*(1024*1024+1))\n"
                        f"os.write(1,{self._observation_bytes()!r})\n"
                    )
                runner, _, journal_path, command_prefix = self._runner_for_script(
                    root, "#!/usr/bin/python3\nimport os\n" + body
                )
                with self.assertRaises(managed.EndpointUnknownOutcome):
                    runner.call(
                        self._contract(),
                        "invokeOnce",
                        command_prefix + ("invoke",),
                    )
                rows = [
                    json.loads(line)
                    for line in journal_path.read_text(encoding="utf-8").splitlines()
                ]
                self.assertEqual(rows[-1]["event"], "unknown")

    def test_real_endpoint_uses_exact_argv_no_shell_and_poisoned_path_is_inert(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            executable = Path("/usr/bin/python3")
            response = root / "response.json"
            log = root / "log.json"
            response.write_bytes(self._observation_bytes())
            endpoint_code = (
                "import json,os,sys\n"
                "log=sys.argv[sys.argv.index('--log')+1]\n"
                "response=sys.argv[sys.argv.index('--response')+1]\n"
                "with open(log,'w') as f: json.dump({'argv':sys.argv[1:],'env':dict(os.environ)},f,sort_keys=True)\n"
                "with open(response,'rb') as f: os.write(1,f.read())\n"
            )
            journal = managed.ObservationJournal(root / "journal.jsonl")
            runner = managed.EndpointRunner(
                repository_identity="repo.example",
                tools={
                    "closed-endpoint": managed.BoundTool(
                        executable,
                        sha256_bytes(executable.read_bytes()),
                        "schemaScopedEndpoint",
                    )
                },
                journal=journal,
                immutable_files={},
            )
            endpoint_argv = (
                "query",
                "--literal",
                "a b;not-shell",
                "--log",
                str(log),
                "--response",
                str(response),
            )
            argv = ("-c", endpoint_code) + endpoint_argv
            old_path = os.environ.get("PATH")
            os.environ["PATH"] = "/poisoned/path"
            os.environ["QINAO_PRIVATE_KEY"] = "must-not-cross"
            try:
                observed = runner.call(self._contract(), "queryExisting", argv)
            finally:
                if old_path is None:
                    os.environ.pop("PATH", None)
                else:
                    os.environ["PATH"] = old_path
                os.environ.pop("QINAO_PRIVATE_KEY", None)
            self.assertEqual(observed.claim_key, "existing-claim")
            invocation = json.loads(log.read_text(encoding="utf-8"))
            self.assertEqual(invocation["argv"], list(endpoint_argv))
            self.assertNotIn("PATH", invocation["env"])
            self.assertNotIn("QINAO_PRIVATE_KEY", invocation["env"])

    def test_nonzero_invoke_is_unknown_and_does_not_become_success(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            executable = Path("/usr/bin/python3")
            runner = managed.EndpointRunner(
                repository_identity="repo.example",
                tools={
                    "closed-endpoint": managed.BoundTool(
                        executable,
                        sha256_bytes(executable.read_bytes()),
                        "schemaScopedEndpoint",
                    )
                },
                journal=managed.ObservationJournal(root / "journal.jsonl"),
                immutable_files={},
            )
            with self.assertRaises(managed.EndpointUnknownOutcome):
                runner.call(
                    self._contract(),
                    "invokeOnce",
                    ("-c", "raise SystemExit(7)", "invoke"),
                )


class TransitionLockTests(unittest.TestCase):
    def _minimal_launch(self, artifact_root: Path) -> SimpleNamespace:
        return SimpleNamespace(
            artifact_root=artifact_root,
            manifest=SimpleNamespace(
                input_rows={"source-selection": SimpleNamespace(sha256="a" * 64)}
            ),
        )

    def test_default_lock_deadline_is_exactly_thirty_seconds_under_fake_clock(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            artifact_root = Path(temporary) / "artifacts"
            artifact_root.mkdir(mode=0o700)
            launch = self._minimal_launch(artifact_root)
            contract = EndpointRunnerTests()._contract()
            clock = [5.0]
            sleeps: list[float] = []

            def monotonic() -> float:
                return clock[0]

            def advance_clock(seconds: float) -> None:
                sleeps.append(seconds)
                clock[0] = 35.0

            def contended_flock(_descriptor: int, operation: int) -> None:
                if operation != managed.fcntl.LOCK_UN:
                    raise BlockingIOError(35, "contended")

            with (
                mock.patch.object(managed.time, "monotonic", monotonic),
                mock.patch.object(managed.time, "sleep", advance_clock),
                mock.patch.object(managed.fcntl, "flock", contended_flock),
                self.assertRaises(managed.BlockedCondition) as caught,
            ):
                with managed.transition_lock(launch, contract):
                    self.fail("a permanently contended lock cannot be acquired")
            self.assertEqual(caught.exception.code, "BLOCKED_TRANSITION_LOCK_TIMEOUT")
            self.assertEqual(clock[0] - 5.0, 30.0)
            self.assertEqual(sleeps, [managed.TRANSITION_LOCK_POLL_SECONDS])

    def test_lock_contention_uses_nonblocking_fixed_deadline_and_typed_block(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            artifact_root = Path(temporary) / "artifacts"
            artifact_root.mkdir(mode=0o700)
            launch = self._minimal_launch(artifact_root)
            contract = EndpointRunnerTests()._contract()
            directory = managed.transition_directory(launch, "01")
            lock_path = directory / ".dispatcher.lock"
            ready_path = directory / "holder-ready"
            holder = subprocess.Popen(
                [
                    sys.executable,
                    "-c",
                    (
                        "import fcntl,os,sys,time;"
                        "fd=os.open(sys.argv[1],os.O_RDWR|os.O_CREAT,0o600);"
                        "fcntl.flock(fd,fcntl.LOCK_EX);"
                        "rfd=os.open(sys.argv[2],os.O_WRONLY|os.O_CREAT,0o600);"
                        "os.write(rfd,b'ready');os.close(rfd);"
                        "time.sleep(1.0)"
                    ),
                    str(lock_path),
                    str(ready_path),
                ],
                stdin=subprocess.DEVNULL,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.PIPE,
            )
            try:
                deadline = time.monotonic() + 1.0
                while not ready_path.exists() and time.monotonic() < deadline:
                    time.sleep(0.005)
                if not ready_path.exists():
                    error_text = (
                        holder.stderr.read().decode()
                        if holder.stderr is not None
                        else "no stderr pipe"
                    )
                    self.fail(error_text)
                self.assertIsNone(holder.poll())
                probe = os.open(str(lock_path), os.O_RDWR)
                try:
                    with self.assertRaises(BlockingIOError):
                        managed.fcntl.flock(
                            probe, managed.fcntl.LOCK_EX | managed.fcntl.LOCK_NB
                        )
                finally:
                    os.close(probe)
                started = time.monotonic()
                with (
                    mock.patch.object(
                        managed, "TRANSITION_LOCK_TIMEOUT_SECONDS", 0.04, create=True
                    ),
                    self.assertRaises(managed.BlockedCondition) as caught,
                ):
                    with managed.transition_lock(launch, contract):
                        self.fail("contended lock must not be acquired after deadline")
                elapsed = time.monotonic() - started
                self.assertEqual(
                    caught.exception.code, "BLOCKED_TRANSITION_LOCK_TIMEOUT"
                )
                self.assertLess(elapsed, 0.15)
            finally:
                holder.terminate()
                holder.wait(timeout=2)
                if holder.stderr is not None:
                    holder.stderr.close()


class LoadLaunchContextTests(unittest.TestCase):
    def _write_external(self, path: Path, value: object) -> str:
        path.write_bytes(canonical_bytes(value))
        path.chmod(0o600)
        return sha256_bytes(path.read_bytes())

    def _fixture(self, temporary: str, *, terminal_endpoint: bool = False):
        top = Path(temporary).resolve()
        root = top / "repo"
        external = top / "external"
        artifact = top / "artifacts"
        (root / "docs").mkdir(parents=True)
        external.mkdir()
        artifact.mkdir()
        artifact.chmod(0o700)
        active_plan = root / "docs" / "active.md"
        active_plan.write_text("active\n", encoding="utf-8")

        selection_value = SourceSelectionTests()._selection()
        selection_path = external / "selection.json"
        selection_sha = self._write_external(selection_path, selection_value)
        trust_path = external / "trust.json"
        trust_sha = self._write_external(
            trust_path, {"schema": "QinaoAdmissionTrustRootV1", "keys": []}
        )
        tool = Path("/usr/bin/python3")
        if terminal_endpoint:
            tool_code = (
                "import hashlib,json,sys\n"
                "from pathlib import Path\n"
                "def arg(name): return sys.argv[sys.argv.index(name)+1]\n"
                "tid=arg('--transition-id')\n"
                "selection=json.load(open(arg('--source-selection')))\n"
                "row=selection['candidateComparisons'][int(tid)-1]\n"
                "machines={'01':('rootAdmission','verified'),'02':('designEdge','alreadyPresent'),'03':('historicalWaveV1','exactLocalCommitInstalled'),'04':('ledgerMigration','verified'),'05':('steadyStateWaveV2','verified'),'06':('steadyStateWaveV2','verified'),'07':('steadyStateWaveV2','verified'),'08':('steadyStateWaveV2','verified'),'09':('steadyStateWaveV2','verified'),'10':('steadyStateWaveV2','verified'),'11':('steadyStateWaveV2','verified'),'12':('steadyStateWaveV2','verified'),'13':('steadyStateWaveV2','verified'),'14':('steadyStateWaveV2','verified'),'15':('steadyStateWaveV2','verified'),'16':('steadyStateWaveV2','verified'),'17':('runtimeChain','verified'),'18':('steadyStateWaveV2','verified'),'19':('steadyStateWaveV2','verified')}\n"
                "machine,state=machines[tid]\n"
                "claim=None if tid=='02' else 'terminal-claim-'+tid\n"
                "if tid=='04':\n"
                " p=Path(arg('--transition-directory'))/'protected-command-policy-v1.json'\n"
                " claim='qinao-protected-policy-v1:'+hashlib.sha256(p.read_bytes() if p.exists() else b'').hexdigest()\n"
                "value={'schema':'QinaoManagedTransitionObservationV1','repositoryIdentity':selection['repositoryIdentity'],'transitionID':tid,'operationID':arg('--operation-id'),'machine':machine,'state':state,'disposition':'verified','claimKey':claim,'outcome':'passed','reviewSource':{k:row[k] for k in ('candidateID','comparisonBaseHEAD','head','tree')}}\n"
                "raw=(json.dumps(value,ensure_ascii=False,sort_keys=True,separators=(',',':'))+'\\n').encode()\n"
                "value['observationRoot']=hashlib.sha256(b'QINAO-MANAGED-TRANSITION-OBSERVATION-V1\\0'+raw).hexdigest()\n"
                "sys.stdout.write(json.dumps(value,ensure_ascii=False,sort_keys=True,separators=(',',':'))+'\\n')\n"
            )
        else:
            tool_code = "raise SystemExit(75)\n"
        tool_argv = python_code_argv(tool_code)
        tool_sha = sha256_bytes(tool.read_bytes())

        contract_paths = {}
        contract_rows = []
        comparisons = selection_value["candidateComparisons"]
        for index in range(1, 5):
            transition_id = f"{index:02d}"
            value = ContractParsingTests()._contract(transition_id)
            comparison = comparisons[index - 1]
            value["reviewSource"] = {
                key: comparison[key]
                for key in ("candidateID", "comparisonBaseHEAD", "head", "tree")
            }
            for action in value["actions"].values():
                action["argv"] = list(tool_argv) + action["argv"]
            path = external / f"contract-{transition_id}.json"
            digest = self._write_external(path, value)
            name = f"transition-{transition_id}-endpoint-contract"
            contract_paths[name] = path
            contract_rows.append(
                {
                    "transitionID": transition_id,
                    "name": name,
                    "schema": "QinaoManagedTransitionEndpointContractV1",
                    "sha256": digest,
                    "requiredRole": "dispatcher-contract",
                }
            )

        coordinator = Path(managed.__file__).resolve()
        coordinator_sha = sha256_bytes(coordinator.read_bytes())
        artifact_metadata = artifact.stat()
        manifest_value = {
            "schema": "QinaoConvergenceBootstrapLaunchManifestV1",
            "repositoryIdentity": "repo.example",
            "activePlan": {
                "path": "docs/active.md",
                "sha256": sha256_bytes(active_plan.read_bytes()),
            },
            "coordinator": {"sha256": coordinator_sha},
            "artifactRootIdentity": {
                "realPathDigest": sha256_bytes(str(artifact.resolve()).encode("utf-8")),
                "fileSystemID": artifact_metadata.st_dev,
                "directoryFileID": artifact_metadata.st_ino,
                "ownerID": artifact_metadata.st_uid,
                "mode": "0700",
            },
            "transitionRange": {"first": 1, "last": 4},
            "toolRows": [
                {
                    "transitionIDs": ["01", "02", "03", "04"],
                    "name": "closed-endpoint",
                    "sha256": tool_sha,
                    "role": "incumbent-verifier",
                    "endpointKind": "schemaScopedEndpoint",
                }
            ],
            "inputRows": [
                {
                    "transitionID": "01",
                    "name": "source-selection",
                    "schema": "QinaoDualSpaceSourceSelectionV1",
                    "sha256": selection_sha,
                    "requiredRole": "source-selector",
                },
                {
                    "transitionID": "01",
                    "name": "trust-root",
                    "schema": "QinaoAdmissionTrustRootV1",
                    "sha256": trust_sha,
                    "requiredRole": "public-verifier-root",
                },
            ]
            + contract_rows,
        }
        manifest_path = external / "bootstrap.json"
        manifest_sha = self._write_external(manifest_path, manifest_value)
        return {
            "root": root,
            "selection": selection_path,
            "trust": trust_path,
            "artifact": artifact,
            "manifest": manifest_path,
            "manifest_sha": manifest_sha,
            "coordinator": coordinator,
            "coordinator_sha": coordinator_sha,
            "tool_bindings": {"closed-endpoint": tool},
            "tool_argv": tool_argv,
            "input_bindings": contract_paths,
        }

    def _policy_value(self, fixture: dict[str, object]) -> dict[str, object]:
        tool_path = fixture["tool_bindings"]["closed-endpoint"]
        tool_sha = sha256_bytes(tool_path.read_bytes())
        tool_rows = [
            {
                "toolID": "policy.endpoint",
                "sourceKind": "externalProtectedEndpoint",
                "path": str(tool_path),
                "gitBlobOID": "0" * 40,
                "mode": f"0{stat.S_IMODE(tool_path.stat().st_mode):03o}",
                "byteLength": tool_path.stat().st_size,
                "sha256": tool_sha,
            }
        ]
        executable_rows = [
            {
                "executableID": "policy.exec",
                "toolID": "policy.endpoint",
                "absolutePath": str(tool_path),
                "codeIdentityDigest": tool_sha,
                "allowedInvocationTemplateIDs": ["policy.template"],
            }
        ]
        invocation_templates = [
            {
                "invocationTemplateID": "policy.template",
                "executableID": "policy.exec",
                "interpreterScriptToolID": None,
                "argvGrammar": "managed-transition-endpoint-v1",
                "permitsShell": False,
                "permitsPATHLookup": False,
            }
        ]
        descendant_profiles = [
            {
                "profileID": "policy.profile",
                "parentProfileID": None,
                "executableIDs": ["policy.exec"],
                "invocationTemplateIDs": ["policy.template"],
                "workingTreeMode": "none",
                "environmentRows": [
                    {
                        "name": "LANG",
                        "valueKind": "literal",
                        "literalValue": "C",
                        "externalInputID": None,
                    },
                    {
                        "name": "LC_ALL",
                        "valueKind": "literal",
                        "literalValue": "C",
                        "externalInputID": None,
                    },
                    {
                        "name": "PYTHONDONTWRITEBYTECODE",
                        "valueKind": "literal",
                        "literalValue": "1",
                        "externalInputID": None,
                    },
                    {
                        "name": "TZ",
                        "valueKind": "literal",
                        "literalValue": "UTC",
                        "externalInputID": None,
                    },
                ],
                "mountRows": [],
                "fileDescriptorRows": [],
                "networkMode": "denied",
                "maxProcessCount": 1,
                "dynamicLoaderPolicy": "systemOnly",
            }
        ]
        endpoint_rows = []
        operation_bindings = []
        operation_coverage = []
        common = [
            "--transition-id",
            "${transitionID}",
            "--operation-id",
            "${operationID}",
            "--source-selection",
            "${sourceSelection}",
            "--trust-root",
            "${trustRoot}",
            "--transition-directory",
            "${transitionDirectory}",
            "--review-head",
            "${reviewSourceHead}",
            "--review-tree",
            "${reviewSourceTree}",
        ]
        for transition in managed.TRANSITIONS[4:]:
            if transition.transition_id == "17":
                operation_bindings.append(
                    {
                        "operationID": transition.operation_id,
                        "admissionKind": "runtimeChainPublication",
                        "waveSliceID": "",
                        "entrypointID": "external-admission-verifier",
                        "waveAdmissionEligible": False,
                        "stateMutationEligible": False,
                    }
                )
            else:
                operation_bindings.append(
                    {
                        "operationID": transition.operation_id,
                        "admissionKind": "waveAdmission",
                        "waveSliceID": transition.operation_id,
                        "entrypointID": "wave-admission-controller",
                        "waveAdmissionEligible": True,
                        "stateMutationEligible": True,
                    }
                )
            ids = []
            for action, command in (
                ("queryExisting", "query-existing"),
                ("invokeOnce", "invoke-once"),
                ("verifyExisting", "verify-existing"),
            ):
                row_id = f"managed.{transition.transition_id}.{action}"
                ids.append(row_id)
                argv = list(fixture["tool_argv"]) + [command] + common
                allowed = {
                    "transitionID",
                    "operationID",
                    "sourceSelection",
                    "trustRoot",
                    "transitionDirectory",
                    "reviewSourceHead",
                    "reviewSourceTree",
                }
                if action != "queryExisting":
                    argv += [
                        "--expected-state",
                        "${expectedState}",
                        "--expected-observation-root",
                        "${expectedObservationRoot}",
                        "--claim-key",
                        "${claimKey}",
                    ]
                    allowed |= {"expectedState", "expectedObservationRoot", "claimKey"}
                endpoint_rows.append(
                    {
                        "endpointRowID": row_id,
                        "transitionID": transition.transition_id,
                        "operationID": transition.operation_id,
                        "action": action,
                        "toolID": "policy.endpoint",
                        "executableID": "policy.exec",
                        "invocationTemplateID": "policy.template",
                        "endpointKind": "schemaScopedEndpoint",
                        "argvTemplate": argv,
                        "allowedPlaceholderNames": sorted(allowed),
                        "resultSchema": "QinaoManagedTransitionObservationV1",
                    }
                )
            operation_coverage.append(
                {
                    "operationID": transition.operation_id,
                    "commandIDs": [],
                    "assertionIDs": [],
                    "externalInputIDs": [],
                    "toolIDs": ["policy.endpoint"],
                    "descendantProfileIDs": ["policy.profile"],
                    "executableIDs": ["policy.exec"],
                    "invocationTemplateIDs": ["policy.template"],
                    "evidenceRetentionPolicyID": None,
                    "commandRowsRoot": managed.policy_array_root("commandRows", []),
                    "assertionRowsRoot": managed.policy_array_root("assertionRows", []),
                    "externalInputRequirementRowsRoot": managed.policy_array_root(
                        "externalInputRequirements", []
                    ),
                    "toolRowsRoot": managed.policy_array_root("toolRows", tool_rows),
                    "descendantProfilesRoot": managed.policy_array_root(
                        "descendantProfiles", descendant_profiles
                    ),
                    "executableRowsRoot": managed.policy_array_root(
                        "executableRows", executable_rows
                    ),
                    "invocationTemplatesRoot": managed.policy_array_root(
                        "invocationTemplates", invocation_templates
                    ),
                    "managedTransitionEndpointRowIDs": sorted(ids),
                    "managedTransitionEndpointRowsRoot": managed.policy_array_root(
                        "managedTransitionEndpointRows",
                        sorted(
                            [
                                row
                                for row in endpoint_rows
                                if row["endpointRowID"] in ids
                            ],
                            key=lambda row: row["endpointRowID"],
                        ),
                    ),
                }
            )
        arrays = {
            "operationBindings": sorted(
                operation_bindings, key=lambda row: row["operationID"]
            ),
            "evidenceRetentionPolicyRows": [],
            "descendantProfiles": descendant_profiles,
            "executableRows": executable_rows,
            "invocationTemplates": invocation_templates,
            "toolRows": tool_rows,
            "commandRows": [],
            "externalInputRequirements": [],
            "assertionRows": [],
            "operationCoverageRows": sorted(
                operation_coverage, key=lambda row: row["operationID"]
            ),
            "managedTransitionEndpointRows": sorted(
                endpoint_rows, key=lambda row: row["endpointRowID"]
            ),
        }
        value: dict[str, object] = {
            "schema": "QinaoProtectedCommandPolicyV1",
            "policyID": "qinao.protected-command-policy.v1",
            "policyVersion": 1,
            **arrays,
        }
        root_names = {
            "operationBindings": "operationBindingsRoot",
            "evidenceRetentionPolicyRows": "evidenceRetentionPolicyRowsRoot",
            "descendantProfiles": "descendantProfilesRoot",
            "executableRows": "executableRowsRoot",
            "invocationTemplates": "invocationTemplatesRoot",
            "toolRows": "toolRowsRoot",
            "commandRows": "commandRowsRoot",
            "externalInputRequirements": "externalInputRequirementRowsRoot",
            "assertionRows": "assertionRowsRoot",
            "operationCoverageRows": "operationCoverageRowsRoot",
            "managedTransitionEndpointRows": "managedTransitionEndpointRowsRoot",
        }
        for array_name, root_name in root_names.items():
            value[root_name] = managed.policy_array_root(array_name, arrays[array_name])
        return value

    def _install_policy_projection(
        self, fixture: dict[str, object], launch: managed.LaunchContext
    ) -> tuple[Path, str]:
        policy = self._policy_value(fixture)
        path = (
            managed.transition_directory(launch, "04")
            / "protected-command-policy-v1.json"
        )
        path.write_bytes(canonical_bytes(policy))
        path.chmod(0o600)
        return path, sha256_bytes(path.read_bytes())

    def _reroot_policy(self, policy: dict[str, object]) -> None:
        root_names = dict(managed.POLICY_ARRAY_ROOT_FIELDS)
        for array_name, root_name in root_names.items():
            if array_name in ("operationCoverageRows", "managedTransitionEndpointRows"):
                continue
            policy[root_name] = managed.policy_array_root(
                array_name, policy[array_name]
            )
        policy["managedTransitionEndpointRowsRoot"] = managed.policy_array_root(
            "managedTransitionEndpointRows", policy["managedTransitionEndpointRows"]
        )
        supporting_roots = (
            "commandRowsRoot",
            "assertionRowsRoot",
            "externalInputRequirementRowsRoot",
            "toolRowsRoot",
            "descendantProfilesRoot",
            "executableRowsRoot",
            "invocationTemplatesRoot",
        )
        endpoints = {
            row["endpointRowID"]: row for row in policy["managedTransitionEndpointRows"]
        }
        for coverage in policy["operationCoverageRows"]:
            for root_name in supporting_roots:
                coverage[root_name] = policy[root_name]
            subset = [
                endpoints[row_id]
                for row_id in coverage["managedTransitionEndpointRowIDs"]
                if row_id in endpoints
            ]
            coverage["managedTransitionEndpointRowsRoot"] = managed.policy_array_root(
                "managedTransitionEndpointRows", subset
            )
        policy["operationCoverageRowsRoot"] = managed.policy_array_root(
            "operationCoverageRows", policy["operationCoverageRows"]
        )

    def test_launch_loader_reopens_every_digest_mode_binding_and_four_contracts(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            fixture = self._fixture(temporary)
            launch = managed.load_launch_context(
                root=fixture["root"],
                source_selection=fixture["selection"],
                trust_root=fixture["trust"],
                artifact_root=fixture["artifact"],
                bootstrap_manifest=fixture["manifest"],
                expected_bootstrap_manifest_sha256=fixture["manifest_sha"],
                expected_coordinator_sha256=fixture["coordinator_sha"],
                tool_bindings=fixture["tool_bindings"],
                input_bindings=fixture["input_bindings"],
                coordinator_path=fixture["coordinator"],
            )
            self.assertEqual(tuple(launch.contracts), ("01", "02", "03", "04"))
            self.assertEqual(tuple(launch.tools), ("closed-endpoint",))
            self.assertEqual(launch.selection.repository_identity, "repo.example")

    def test_launch_loader_rejects_digest_drift_extra_input_and_repository_local_external(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            fixture = self._fixture(temporary)
            cases = []
            drift = dict(fixture)
            drift["expected_coordinator_sha256"] = "0" * 64
            cases.append(drift)
            extra = dict(fixture)
            extra["input_bindings"] = dict(
                fixture["input_bindings"], extra=fixture["selection"]
            )
            cases.append(extra)
            local = dict(fixture)
            local["source_selection"] = fixture["root"] / "selection.json"
            local["source_selection"].write_bytes(fixture["selection"].read_bytes())
            local["source_selection"].chmod(0o600)
            cases.append(local)
            for case in cases:
                with self.subTest(), self.assertRaises(managed.ManagedConvergenceError):
                    managed.load_launch_context(
                        root=case["root"],
                        source_selection=case.get(
                            "source_selection", case["selection"]
                        ),
                        trust_root=case["trust"],
                        artifact_root=case["artifact"],
                        bootstrap_manifest=case["manifest"],
                        expected_bootstrap_manifest_sha256=case["manifest_sha"],
                        expected_coordinator_sha256=case.get(
                            "expected_coordinator_sha256", case["coordinator_sha"]
                        ),
                        tool_bindings=case["tool_bindings"],
                        input_bindings=case["input_bindings"],
                        coordinator_path=case["coordinator"],
                    )

    def test_main_queries_four_bootstrap_terminals_then_blocks_on_absent_admitted_policy(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            fixture = self._fixture(temporary, terminal_endpoint=True)
            argv = [
                "resume-series",
                "--root",
                str(fixture["root"]),
                "--source-selection",
                str(fixture["selection"]),
                "--trust-root",
                str(fixture["trust"]),
                "--artifact-root",
                str(fixture["artifact"]),
                "--bootstrap-manifest",
                str(fixture["manifest"]),
                "--expected-bootstrap-manifest-sha256",
                fixture["manifest_sha"],
                "--expected-coordinator-sha256",
                fixture["coordinator_sha"],
                "--tool-binding",
                f"closed-endpoint={fixture['tool_bindings']['closed-endpoint']}",
            ]
            for name, path in fixture["input_bindings"].items():
                argv.extend(("--input-binding", f"{name}={path}"))
            output = io.StringIO()
            with redirect_stdout(output):
                exit_code = managed.main(argv)
            self.assertEqual(exit_code, 2)
            result = json.loads(output.getvalue())
            self.assertEqual(result["status"], "blocked")
            self.assertEqual(
                result["code"], "BLOCKED_MISSING_ADMITTED_POLICY_PROJECTION"
            )
            selection_sha = json.loads(fixture["manifest"].read_text(encoding="utf-8"))[
                "inputRows"
            ][0]["sha256"]
            for transition_id in ("01", "02", "03", "04"):
                journal = (
                    fixture["artifact"]
                    / selection_sha
                    / f"t{transition_id}"
                    / "dispatcher-observations-v1.jsonl"
                )
                rows = [
                    json.loads(line)
                    for line in journal.read_text(encoding="utf-8").splitlines()
                ]
                self.assertEqual(
                    [row["action"] for row in rows], ["queryExisting", "queryExisting"]
                )
                self.assertEqual(
                    [row["event"] for row in rows], ["launching", "observed"]
                )

    def test_main_derives_postmigration_execution_only_from_fixed_policy_projection(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            fixture = self._fixture(temporary, terminal_endpoint=True)
            launch = managed.load_launch_context(
                root=fixture["root"],
                source_selection=fixture["selection"],
                trust_root=fixture["trust"],
                artifact_root=fixture["artifact"],
                bootstrap_manifest=fixture["manifest"],
                expected_bootstrap_manifest_sha256=fixture["manifest_sha"],
                expected_coordinator_sha256=fixture["coordinator_sha"],
                tool_bindings=fixture["tool_bindings"],
                input_bindings=fixture["input_bindings"],
                coordinator_path=fixture["coordinator"],
            )
            self._install_policy_projection(fixture, launch)
            argv = [
                "resume-series",
                "--root",
                str(fixture["root"]),
                "--source-selection",
                str(fixture["selection"]),
                "--trust-root",
                str(fixture["trust"]),
                "--artifact-root",
                str(fixture["artifact"]),
                "--bootstrap-manifest",
                str(fixture["manifest"]),
                "--expected-bootstrap-manifest-sha256",
                fixture["manifest_sha"],
                "--expected-coordinator-sha256",
                fixture["coordinator_sha"],
                "--tool-binding",
                f"closed-endpoint={fixture['tool_bindings']['closed-endpoint']}",
            ]
            for name, path in fixture["input_bindings"].items():
                argv.extend(("--input-binding", f"{name}={path}"))
            output = io.StringIO()
            with redirect_stdout(output):
                exit_code = managed.main(argv)
            self.assertEqual(exit_code, 0, output.getvalue())
            result = json.loads(output.getvalue())
            self.assertEqual(result["code"], "COMPLETE_MANAGED_CONVERGENCE")
            self.assertEqual(result["transitionID"], "19")
            selection_sha = json.loads(fixture["manifest"].read_text(encoding="utf-8"))[
                "inputRows"
            ][0]["sha256"]
            for transition_id in tuple(f"{index:02d}" for index in range(1, 20)):
                journal = (
                    fixture["artifact"]
                    / selection_sha
                    / f"t{transition_id}"
                    / "dispatcher-observations-v1.jsonl"
                )
                rows = [
                    json.loads(line)
                    for line in journal.read_text(encoding="utf-8").splitlines()
                ]
                self.assertEqual(
                    [row["action"] for row in rows], ["queryExisting", "queryExisting"]
                )

    def test_policy_loader_derives_exact_fifteen_times_three_templates_and_tools(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            fixture = self._fixture(temporary)
            launch = managed.load_launch_context(
                root=fixture["root"],
                source_selection=fixture["selection"],
                trust_root=fixture["trust"],
                artifact_root=fixture["artifact"],
                bootstrap_manifest=fixture["manifest"],
                expected_bootstrap_manifest_sha256=fixture["manifest_sha"],
                expected_coordinator_sha256=fixture["coordinator_sha"],
                tool_bindings=fixture["tool_bindings"],
                input_bindings=fixture["input_bindings"],
                coordinator_path=fixture["coordinator"],
            )
            path, digest = self._install_policy_projection(fixture, launch)
            result = managed.DispatchResult(
                "complete",
                "VERIFIED_TRANSITION_TERMINAL",
                "04",
                "bootstrap.ledger-v2-migration",
                "verified",
                "a" * 64,
                f"qinao-protected-policy-v1:{digest}",
            )
            loaded = managed.load_admitted_policy_projection(launch, result)
            self.assertEqual(
                tuple(loaded.contracts), tuple(f"{index:02d}" for index in range(5, 20))
            )
            self.assertEqual(len(loaded.endpoint_rows), 45)
            self.assertEqual(tuple(loaded.tools), ("policy.endpoint",))
            self.assertEqual(loaded.path, path)

    def test_policy_loader_blocks_missing_claim_file_root_drift_and_row_omission(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            fixture = self._fixture(temporary)
            launch = managed.load_launch_context(
                root=fixture["root"],
                source_selection=fixture["selection"],
                trust_root=fixture["trust"],
                artifact_root=fixture["artifact"],
                bootstrap_manifest=fixture["manifest"],
                expected_bootstrap_manifest_sha256=fixture["manifest_sha"],
                expected_coordinator_sha256=fixture["coordinator_sha"],
                tool_bindings=fixture["tool_bindings"],
                input_bindings=fixture["input_bindings"],
                coordinator_path=fixture["coordinator"],
            )
            missing_claim = managed.DispatchResult(
                "complete",
                "terminal",
                "04",
                "bootstrap.ledger-v2-migration",
                "verified",
                "a" * 64,
                None,
            )
            with self.assertRaises(managed.BlockedCondition):
                managed.load_admitted_policy_projection(launch, missing_claim)
            path, _ = self._install_policy_projection(fixture, launch)
            policy = json.loads(path.read_text(encoding="utf-8"))
            policy["managedTransitionEndpointRows"].pop()
            self._reroot_policy(policy)
            path.write_bytes(canonical_bytes(policy))
            path.chmod(0o600)
            changed_digest = sha256_bytes(path.read_bytes())
            changed_result = managed.DispatchResult(
                "complete",
                "terminal",
                "04",
                "bootstrap.ledger-v2-migration",
                "verified",
                "a" * 64,
                f"qinao-protected-policy-v1:{changed_digest}",
            )
            with self.assertRaises(managed.BlockedCondition) as missing_row:
                managed.load_admitted_policy_projection(launch, changed_result)
            self.assertEqual(
                missing_row.exception.code,
                "BLOCKED_INCOMPLETE_ADMITTED_POLICY_ENDPOINTS",
            )

    def test_policy_loader_rejects_dynamic_query_and_execution_reference_drift(
        self,
    ) -> None:
        mutations = (
            "dynamic-query",
            "missing-tool-coverage",
            "shell-template",
            "provider-endpoint",
            "runtime-wave-alias",
        )
        for mutation in mutations:
            with (
                self.subTest(mutation=mutation),
                tempfile.TemporaryDirectory() as temporary,
            ):
                fixture = self._fixture(temporary)
                launch = managed.load_launch_context(
                    root=fixture["root"],
                    source_selection=fixture["selection"],
                    trust_root=fixture["trust"],
                    artifact_root=fixture["artifact"],
                    bootstrap_manifest=fixture["manifest"],
                    expected_bootstrap_manifest_sha256=fixture["manifest_sha"],
                    expected_coordinator_sha256=fixture["coordinator_sha"],
                    tool_bindings=fixture["tool_bindings"],
                    input_bindings=fixture["input_bindings"],
                    coordinator_path=fixture["coordinator"],
                )
                path, _ = self._install_policy_projection(fixture, launch)
                policy = json.loads(path.read_text(encoding="utf-8"))
                if mutation == "dynamic-query":
                    row = next(
                        row
                        for row in policy["managedTransitionEndpointRows"]
                        if row["endpointRowID"] == "managed.05.queryExisting"
                    )
                    row["argvTemplate"].extend(("--claim-key", "${claimKey}"))
                    row["allowedPlaceholderNames"] = sorted(
                        row["allowedPlaceholderNames"] + ["claimKey"]
                    )
                elif mutation == "missing-tool-coverage":
                    coverage = next(
                        row
                        for row in policy["operationCoverageRows"]
                        if row["operationID"] == "w1.artifact-mesh-contract-freeze"
                    )
                    coverage["toolIDs"] = []
                elif mutation == "shell-template":
                    policy["invocationTemplates"][0]["permitsShell"] = True
                elif mutation == "provider-endpoint":
                    row = next(
                        row
                        for row in policy["managedTransitionEndpointRows"]
                        if row["endpointRowID"] == "managed.05.invokeOnce"
                    )
                    row["endpointKind"] = "signingProvider"
                else:
                    binding = next(
                        row
                        for row in policy["operationBindings"]
                        if row["operationID"] == "w6.runtime-receipt-chain"
                    )
                    binding.update(
                        {
                            "admissionKind": "waveAdmission",
                            "waveSliceID": "w6.runtime-receipt-chain",
                            "entrypointID": "wave-admission-controller",
                            "waveAdmissionEligible": True,
                            "stateMutationEligible": True,
                        }
                    )
                self._reroot_policy(policy)
                path.write_bytes(canonical_bytes(policy))
                path.chmod(0o600)
                digest = sha256_bytes(path.read_bytes())
                result = managed.DispatchResult(
                    "complete",
                    "terminal",
                    "04",
                    "bootstrap.ledger-v2-migration",
                    "verified",
                    "a" * 64,
                    f"qinao-protected-policy-v1:{digest}",
                )
                with self.assertRaises(managed.ContractError):
                    managed.load_admitted_policy_projection(launch, result)

    def test_policy_loader_rejects_claim_digest_and_file_mode_drift(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            fixture = self._fixture(temporary)
            launch = managed.load_launch_context(
                root=fixture["root"],
                source_selection=fixture["selection"],
                trust_root=fixture["trust"],
                artifact_root=fixture["artifact"],
                bootstrap_manifest=fixture["manifest"],
                expected_bootstrap_manifest_sha256=fixture["manifest_sha"],
                expected_coordinator_sha256=fixture["coordinator_sha"],
                tool_bindings=fixture["tool_bindings"],
                input_bindings=fixture["input_bindings"],
                coordinator_path=fixture["coordinator"],
            )
            path, digest = self._install_policy_projection(fixture, launch)
            wrong_claim = managed.DispatchResult(
                "complete",
                "terminal",
                "04",
                "bootstrap.ledger-v2-migration",
                "verified",
                "a" * 64,
                f"qinao-protected-policy-v1:{'0' * 64}",
            )
            with self.assertRaises(managed.SourceDriftError):
                managed.load_admitted_policy_projection(launch, wrong_claim)
            path.chmod(0o644)
            correct_claim = managed.DispatchResult(
                "complete",
                "terminal",
                "04",
                "bootstrap.ledger-v2-migration",
                "verified",
                "a" * 64,
                f"qinao-protected-policy-v1:{digest}",
            )
            with self.assertRaises(managed.ContractError):
                managed.load_admitted_policy_projection(launch, correct_claim)

    def test_policy_loader_never_reopens_nonendpoint_candidate_tools_for_execution(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            fixture = self._fixture(temporary)
            launch = managed.load_launch_context(
                root=fixture["root"],
                source_selection=fixture["selection"],
                trust_root=fixture["trust"],
                artifact_root=fixture["artifact"],
                bootstrap_manifest=fixture["manifest"],
                expected_bootstrap_manifest_sha256=fixture["manifest_sha"],
                expected_coordinator_sha256=fixture["coordinator_sha"],
                tool_bindings=fixture["tool_bindings"],
                input_bindings=fixture["input_bindings"],
                coordinator_path=fixture["coordinator"],
            )
            path, _ = self._install_policy_projection(fixture, launch)
            policy = json.loads(path.read_text(encoding="utf-8"))
            policy["toolRows"].append(
                {
                    "toolID": "w1.tool.candidate-fixture",
                    "sourceKind": "bootstrapGitBlob",
                    "path": "scripts/candidate_fixture.py",
                    "gitBlobOID": "1" * 40,
                    "mode": "0644",
                    "byteLength": 17,
                    "sha256": "2" * 64,
                }
            )
            policy["toolRows"].sort(key=lambda row: row["toolID"])
            coverage = next(
                row
                for row in policy["operationCoverageRows"]
                if row["operationID"] == "w1.artifact-mesh-contract-freeze"
            )
            coverage["toolIDs"].append("w1.tool.candidate-fixture")
            coverage["toolIDs"].sort()
            self._reroot_policy(policy)
            path.write_bytes(canonical_bytes(policy))
            path.chmod(0o600)
            digest = sha256_bytes(path.read_bytes())
            result = managed.DispatchResult(
                "complete",
                "terminal",
                "04",
                "bootstrap.ledger-v2-migration",
                "verified",
                "a" * 64,
                f"qinao-protected-policy-v1:{digest}",
            )
            loaded = managed.load_admitted_policy_projection(launch, result)
            self.assertEqual(tuple(loaded.tools), ("policy.endpoint",))

    def test_policy_loader_preserves_nonmanaged_policy_rows_without_dispatching_them(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            fixture = self._fixture(temporary)
            launch = managed.load_launch_context(
                root=fixture["root"],
                source_selection=fixture["selection"],
                trust_root=fixture["trust"],
                artifact_root=fixture["artifact"],
                bootstrap_manifest=fixture["manifest"],
                expected_bootstrap_manifest_sha256=fixture["manifest_sha"],
                expected_coordinator_sha256=fixture["coordinator_sha"],
                tool_bindings=fixture["tool_bindings"],
                input_bindings=fixture["input_bindings"],
                coordinator_path=fixture["coordinator"],
            )
            path, _ = self._install_policy_projection(fixture, launch)
            policy = json.loads(path.read_text(encoding="utf-8"))
            operation_id = "bootstrap.amendment3-protected-review"
            policy["operationBindings"].append(
                {
                    "operationID": operation_id,
                    "admissionKind": "bootstrapReviewOnly",
                    "waveSliceID": "",
                    "entrypointID": "amendment3-protected-review-controller",
                    "waveAdmissionEligible": False,
                    "stateMutationEligible": False,
                }
            )
            policy["operationBindings"].sort(key=lambda row: row["operationID"])
            policy["operationCoverageRows"].append(
                {
                    "operationID": operation_id,
                    "commandIDs": [],
                    "assertionIDs": [],
                    "externalInputIDs": [],
                    "toolIDs": [],
                    "descendantProfileIDs": [],
                    "executableIDs": [],
                    "invocationTemplateIDs": [],
                    "evidenceRetentionPolicyID": None,
                    "commandRowsRoot": policy["commandRowsRoot"],
                    "assertionRowsRoot": policy["assertionRowsRoot"],
                    "externalInputRequirementRowsRoot": policy[
                        "externalInputRequirementRowsRoot"
                    ],
                    "toolRowsRoot": policy["toolRowsRoot"],
                    "descendantProfilesRoot": policy["descendantProfilesRoot"],
                    "executableRowsRoot": policy["executableRowsRoot"],
                    "invocationTemplatesRoot": policy["invocationTemplatesRoot"],
                    "managedTransitionEndpointRowIDs": [],
                    "managedTransitionEndpointRowsRoot": managed.policy_array_root(
                        "managedTransitionEndpointRows", []
                    ),
                }
            )
            policy["operationCoverageRows"].sort(key=lambda row: row["operationID"])
            self._reroot_policy(policy)
            path.write_bytes(canonical_bytes(policy))
            path.chmod(0o600)
            digest = sha256_bytes(path.read_bytes())
            result = managed.DispatchResult(
                "complete",
                "terminal",
                "04",
                "bootstrap.ledger-v2-migration",
                "verified",
                "a" * 64,
                f"qinao-protected-policy-v1:{digest}",
            )
            loaded = managed.load_admitted_policy_projection(launch, result)
            self.assertEqual(
                tuple(loaded.contracts), tuple(f"{index:02d}" for index in range(5, 20))
            )


if __name__ == "__main__":
    unittest.main()
