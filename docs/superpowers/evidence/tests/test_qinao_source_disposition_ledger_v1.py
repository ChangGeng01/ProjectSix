from __future__ import annotations

import csv
import hashlib
import importlib.util
import io
import json
import os
import re
import stat
import subprocess
import sys
import tempfile
import types
import unittest
from pathlib import Path


EVIDENCE_DIR = Path(__file__).resolve().parents[1]
TOOL_PATH = EVIDENCE_DIR / "2026-08-28-qinao-source-disposition-ledger-v1.py"
SPEC_PATH = (
    EVIDENCE_DIR.parent
    / "specs"
    / "2026-08-28-qinao-recovery-spine-and-deep-scan-closure-design.md"
)
LEDGER_PATH = EVIDENCE_DIR / "2026-08-28-qinao-recovery-spine-source-disposition.tsv"
SEMANTIC_MANIFEST_PATH = (
    EVIDENCE_DIR / "2026-08-28-qinao-final-requirement-semantic-corrections.tsv"
)
MAPPING_MANIFEST_PATH = (
    EVIDENCE_DIR / "2026-08-28-qinao-final-source-target-mapping.tsv"
)


def read_regular_bytes(path: Path) -> bytes:
    flags = os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0)
    descriptor = os.open(path, flags)
    with os.fdopen(descriptor, "rb") as handle:
        if not stat.S_ISREG(os.fstat(handle.fileno()).st_mode):
            raise AssertionError(f"expected a regular file: {path}")
        return handle.read()


def parse_tsv(data: bytes) -> list[dict[str, str]]:
    return list(csv.DictReader(io.StringIO(data.decode("utf-8")), delimiter="\t"))


def load_tool_from_bytes(data: bytes):
    module_name = "qinao_source_disposition_v1_authenticated_test"
    module = types.ModuleType(module_name)
    module.__file__ = str(TOOL_PATH)
    sys.modules[module_name] = module
    exec(compile(data, str(TOOL_PATH), "exec"), module.__dict__)
    return module


def load_tool():
    if not TOOL_PATH.is_file():
        raise AssertionError(f"source-disposition verifier is absent: {TOOL_PATH}")
    spec = importlib.util.spec_from_file_location("qinao_source_disposition_v1", TOOL_PATH)
    if spec is None or spec.loader is None:
        raise AssertionError(f"cannot load verifier: {TOOL_PATH}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def base_row(tool, record_type: str) -> dict[str, str]:
    row = {name: "-" for name in tool.HEADER}
    row.update(
        {
            "schemaVersion": "1",
            "recordType": record_type,
            "unitID": "QUN-111111111111111111111111",
            "unitClass": "normativeBearing",
            "anchorKind": "prose",
            "specPath": "docs/spec.md",
            "specBlob": "a" * 40,
            "specByteLength": "100",
            "specLineCount": "5",
            "specSHA256": "b" * 64,
            "headingPath": "qhp1:00000000",
            "anchorLocator": "qinao-unit-locator/v1:qhp1:00000000:prose:1",
            "unitStartByte": "0",
            "unitEndByteExclusive": "10",
            "unitStartLine": "1",
            "unitEndLine": "1",
            "unitSpanSHA256": "c" * 64,
            "unitSemanticSHA256": "d" * 64,
        }
    )
    return row


class MarkdownExtractorTests(unittest.TestCase):
    def test_extracts_closed_v1_units_with_exact_heading_paths_and_ownership(self):
        """Catches list children or fenced/table bytes being swallowed by prose."""
        tool = load_tool()
        source = (
            b"# Root\n"
            b"Intro line\n"
            b"continues.\n"
            b"\n"
            b"- parent\n"
            b"  continuation\n"
            b"  - child\n"
            b"\n"
            b"## Sub\n"
            b"```text\n"
            b"- not a list\n"
            b"```\n"
            b"\n"
            b"A | B\n"
            b"---|---\n"
            b"1 | 2\n"
            b"\n"
            b"Tail.\n"
        )
        units = tool.extract_markdown_units(source, "fixture.md")

        self.assertEqual(
            [unit["anchorKind"] for unit in units],
            ["prose", "listLeader", "listLeader", "fencedCode", "table", "prose"],
        )
        self.assertEqual(
            [source[unit["startByte"] : unit["endByteExclusive"]] for unit in units],
            [
                b"Intro line\ncontinues.\n",
                b"- parent\n  continuation\n",
                b"  - child\n",
                b"```text\n- not a list\n```\n",
                b"A | B\n---|---\n1 | 2\n",
                b"Tail.\n",
            ],
        )
        root_path = "qhp1:00000001010000000000000004526f6f74"
        sub_path = (
            "qhp1:00000002010000000000000004526f6f74"
            "020000000000000003537562"
        )
        self.assertEqual(
            [unit["headingPath"] for unit in units],
            [root_path, root_path, root_path, sub_path, sub_path, sub_path],
        )
        self.assertEqual(
            [unit["anchorLocator"] for unit in units],
            [
                f"qinao-unit-locator/v1:{root_path}:prose:1",
                f"qinao-unit-locator/v1:{root_path}:listLeader:1",
                f"qinao-unit-locator/v1:{root_path}:listLeader:2",
                f"qinao-unit-locator/v1:{sub_path}:fencedCode:1",
                f"qinao-unit-locator/v1:{sub_path}:table:1",
                f"qinao-unit-locator/v1:{sub_path}:prose:1",
            ],
        )
        self.assertEqual([(u["startLine"], u["endLine"]) for u in units], [(2, 3), (5, 6), (7, 7), (10, 12), (14, 16), (18, 18)])
        self.assertTrue(all(unit["unitID"].startswith("QUN-") for unit in units))

    def test_rejects_noncanonical_or_ambiguous_markdown_bytes(self):
        """Catches silent normalization of BOM, CRLF, unterminated fences, or unowned bytes."""
        tool = load_tool()
        invalid = [
            b"\xef\xbb\xbf# H\ntext\n",
            b"# H\r\ntext\r\n",
            b"# H\n```\nopen\n",
            b"# H\n    unowned indented bytes\n",
        ]
        for source in invalid:
            with self.subTest(source=source):
                with self.assertRaises(tool.LedgerError):
                    tool.extract_markdown_units(source, "fixture.md")

    def test_rejects_ambiguous_continuation_after_nested_list_child(self):
        """Catches assigning an under-indented post-child continuation to the child."""
        tool = load_tool()
        source = b"# H\n- parent\n  - child\n  ambiguous owner\n"
        with self.assertRaises(tool.LedgerError):
            tool.extract_markdown_units(source, "fixture.md")

    def test_extracts_additional_parent_paragraph_after_nested_list(self):
        """Catches rejecting a direct list paragraph after a nested child list."""
        tool = load_tool()
        source = b"# H\n1. parent\n   - child\n\n   additional paragraph\n"
        units = tool.extract_markdown_units(source, "fixture.md")
        self.assertEqual([unit["anchorKind"] for unit in units], ["listLeader", "listLeader", "prose"])
        self.assertEqual(
            [source[unit["startByte"] : unit["endByteExclusive"]] for unit in units],
            [b"1. parent\n", b"   - child\n", b"   additional paragraph\n"],
        )

    def test_root_structural_blocks_close_stale_list_ownership(self):
        """Catches a root fence/table lending stale list ownership to later orphan bytes."""
        tool = load_tool()
        invalid = [
            (
                b"# H\n- item\n\n```text\nroot block\n```\n\n  orphan\n"
            ),
            (
                b"# H\n- item\n\nA | B\n---|---\n1 | 2\n\n  orphan\n"
            ),
        ]
        for source in invalid:
            with self.subTest(source=source):
                with self.assertRaises(tool.LedgerError):
                    tool.extract_markdown_units(source, "fixture.md")

    def test_heading_guard_is_committed_to_child_identity_and_closed_by_sibling(self):
        """Catches losing a cross-unit guard or leaking it beyond its sibling scope."""
        tool = load_tool()
        guarded_a = (
            b"# Root\n"
            b"## Every following predicate must hold before launch\n"
            b"- evidence reopens exactly once\n"
            b"## After the launch gate\n"
            b"Tail invariant.\n"
        )
        guarded_b = guarded_a.replace(b"before launch", b"before execution")

        units_a = tool.extract_markdown_units(guarded_a, "fixture.md")
        units_b = tool.extract_markdown_units(guarded_b, "fixture.md")

        self.assertEqual([unit["normalizedText"] for unit in units_a], [unit["normalizedText"] for unit in units_b])
        self.assertNotEqual(units_a[0]["headingPath"], units_b[0]["headingPath"])
        self.assertNotEqual(units_a[0]["unitID"], units_b[0]["unitID"])
        self.assertEqual(units_a[1]["headingPath"], units_b[1]["headingPath"])
        self.assertEqual(units_a[1]["unitID"], units_b[1]["unitID"])

    def test_closed_mode_set_and_definitions_remain_one_list_unit(self):
        """Catches splitting a shared exactly-one mode contract into unlinked child units."""
        tool = load_tool()
        source = (
            b"# H\n"
            b"1. Select exactly one mode from the closed set\n"
            b"   {app, headless}.\n"
            b"   app means monitored. headless means residual.\n"
        )
        units = tool.extract_markdown_units(source, "fixture.md")
        self.assertEqual(len(units), 1)
        self.assertEqual(units[0]["anchorKind"], "listLeader")
        self.assertEqual(source[units[0]["startByte"] : units[0]["endByteExclusive"]], source[len(b"# H\n") :])


class RowShapeTests(unittest.TestCase):
    def test_accepts_each_record_shape_and_rejects_forbidden_fields(self):
        """Catches treating the matrix as advisory instead of required-and-forbidden."""
        tool = load_tool()

        unit = base_row(tool, "UNIT")
        unit.update(
            {
                "subjectID": unit["unitID"],
                "sourceBindingCount": "0",
                "sourceBindingRoot": "1" * 64,
                "rowCommitment": "2" * 64,
            }
        )
        tool.validate_row_shape(unit)
        invalid_unit = dict(unit, disposition="forensicRiskInput")
        with self.assertRaises(tool.LedgerError):
            tool.validate_row_shape(invalid_unit)

        requirement = base_row(tool, "REQUIREMENT")
        requirement.update(
            {
                "subjectID": "QRS-222222222222222222222222",
                "requirementID": "QRS-222222222222222222222222",
                "requirementSemanticSHA256": "3" * 64,
                "disposition": "projectionOfControlledRequirement",
                "executionState": "sourceGoverned",
                "clauseCount": "1",
                "clauseRoot": "4" * 64,
                "sourceBindingCount": "1",
                "sourceBindingRoot": "5" * 64,
                "targetBindingCount": "1",
                "targetBindingRoot": "6" * 64,
                "rowCommitment": "7" * 64,
            }
        )
        tool.validate_row_shape(requirement)
        with self.assertRaises(tool.LedgerError):
            tool.validate_row_shape(dict(requirement, clauseCount="0"))

    def test_record_shape_required_fields_have_one_executable_fact_source(self):
        """Catches a second literal required-field list overriding RECORD_SHAPES."""
        tool = load_tool()
        requirement = base_row(tool, "REQUIREMENT")
        requirement.update(
            {
                "subjectID": "QRS-222222222222222222222222",
                "requirementID": "QRS-222222222222222222222222",
                "requirementSemanticSHA256": "3" * 64,
                "disposition": "projectionOfControlledRequirement",
                "executionState": "sourceGoverned",
                "clauseCount": "-",
                "clauseRoot": "4" * 64,
                "sourceBindingCount": "1",
                "sourceBindingRoot": "5" * 64,
                "targetBindingCount": "1",
                "targetBindingRoot": "6" * 64,
                "rowCommitment": "7" * 64,
            }
        )
        original = tool.RECORD_SHAPES
        mutated = {
            kind: {key: frozenset(value) for key, value in shape.items()}
            for kind, shape in original.items()
        }
        mutated["REQUIREMENT"]["required"] = (
            mutated["REQUIREMENT"]["required"] - {"clauseCount"}
        )
        tool.RECORD_SHAPES = mutated
        try:
            tool.validate_row_shape(requirement)
        finally:
            tool.RECORD_SHAPES = original

    def test_pending_gate_identity_cannot_cross_semantic_scope(self):
        """Catches reusing one pendingGateID across owners, Waves, or classes."""
        tool = load_tool()
        first = {
            "recordType": "TARGET",
            "requirementID": "QRS-first",
            "selectorID": "selector.one",
            "selectorPath": "one.swift",
            "pendingGateID": "A0.sharedAdmission",
            "governedOwner": "state.owner",
            "governedWave": "W1",
            "nonProductionClass": "-",
            "executionState": "nonExecutable",
        }
        same_scope = dict(
            first,
            requirementID="QRS-second",
            selectorID="selector.two",
            selectorPath="two.swift",
        )
        requirements = [
            {
                "recordType": "REQUIREMENT",
                "requirementID": "QRS-first",
                "disposition": "newControlDeltaPendingAdmission",
            },
            {
                "recordType": "REQUIREMENT",
                "requirementID": "QRS-second",
                "disposition": "newControlDeltaPendingAdmission",
            },
        ]
        tool.validate_identifier_registries([*requirements, first, same_scope])
        with self.assertRaises(tool.LedgerError):
            tool.validate_identifier_registries([*requirements, first, dict(same_scope, governedWave="W2")])

        other_disposition = {
            "recordType": "REQUIREMENT",
            "requirementID": "QRS-other",
            "disposition": "operationalScanGate",
        }
        with self.assertRaises(tool.LedgerError):
            tool.validate_identifier_registries(
                [*requirements[:1], other_disposition, first, dict(same_scope, requirementID="QRS-other")]
            )

    def test_source_and_selector_identifiers_reuse_only_the_same_identity(self):
        """Catches deleting immutable sourceID or selectorID/path conflict closure."""
        tool = load_tool()
        source = {
            "recordType": "SOURCE",
            "sourceID": "SOURCE-ONE",
            "sourceKind": "repositoryCommitted",
            "sourcePath": "docs/source.md",
            "sourceLocator": "REQ-1",
            "sourceRevision": "v1",
            "sourceCommit": "b" * 40,
            "sourceTree": "c" * 40,
            "sourceBlob": "d" * 40,
            "sourceByteLength": "42",
            "sourceSHA256": "e" * 64,
            "admissionState": "admittedControlled",
            "scanNumber": "-",
            "scanKind": "-",
            "scanID": "-",
            "scanTargetRevision": "-",
            "scanOfficialState": "-",
            "canonicalArtifactState": "-",
        }
        same_source_identity = dict(source)
        conflicting_source_identity = dict(source, sourceRevision="v2")
        tool.validate_identifier_registries([source, same_source_identity])
        with self.assertRaisesRegex(tool.LedgerError, "sourceID"):
            tool.validate_identifier_registries([source, conflicting_source_identity])

        selector = {
            "recordType": "TARGET",
            "selectorID": "K3.owner",
            "selectorPath": "Sources/K3.swift",
            "pendingGateID": "-",
        }
        same_selector_path = dict(selector)
        conflicting_selector_path = dict(selector, selectorPath="Sources/K4.swift")
        tool.validate_identifier_registries([selector, same_selector_path])
        with self.assertRaisesRegex(tool.LedgerError, "selectorID"):
            tool.validate_identifier_registries([selector, conflicting_selector_path])

    def test_tsv_uses_only_literal_lf_as_a_record_separator(self):
        """Catches Unicode splitlines accepting non-LF record boundaries or splitting legal cells."""
        tool = load_tool()
        header = "\t".join(tool.HEADER)
        for separator in ("\u2028", "\x0b", "\x0c"):
            row = base_row(tool, "UNIT")
            row.update(
                subjectID=row["unitID"],
                specPath=f"docs/{separator}/spec.md",
                sourceBindingCount="0",
                sourceBindingRoot="1" * 64,
                rowCommitment="2" * 64,
            )
            encoded_row = "\t".join(row[field] for field in tool.HEADER)
            with self.subTest(separator=repr(separator), mode="cell"):
                self.assertEqual(tool._parse_tsv((header + "\n" + encoded_row + "\n").encode("utf-8")), [row])

            plain = dict(row, specPath="docs/spec.md")
            encoded_plain = "\t".join(plain[field] for field in tool.HEADER)
            injected = (header + "\n" + encoded_plain + separator + encoded_plain + "\n").encode("utf-8")
            with self.subTest(separator=repr(separator), mode="record-boundary"):
                with self.assertRaises(tool.LedgerError):
                    tool._parse_tsv(injected)

        clause = base_row(tool, "CLAUSE")
        clause.update(
            {
                "subjectID": "QRS-222222222222222222222222",
                "requirementID": "QRS-222222222222222222222222",
                "childID": "QCL-333333333333333333333333",
                "clauseOrdinal": "1",
                "clauseRole": "assertion",
                "clauseStartByte": "1",
                "clauseEndByteExclusive": "9",
                "clauseSHA256": "8" * 64,
                "clauseCommitment": "9" * 64,
                "rowCommitment": "a" * 64,
            }
        )
        tool.validate_row_shape(clause)

        source = base_row(tool, "SOURCE")
        source.update(
            {
                "subjectID": "QRS-222222222222222222222222",
                "requirementID": "QRS-222222222222222222222222",
                "childID": "QSC-444444444444444444444444",
                "bindingOrdinal": "1",
                "sourceID": "SRC-ONE",
                "sourceKind": "repositoryCommitted",
                "sourcePath": "docs/source.md",
                "sourceLocator": "REQ-1",
                "sourceRevision": "v1",
                "sourceCommit": "b" * 40,
                "sourceTree": "c" * 40,
                "sourceBlob": "d" * 40,
                "sourceByteLength": "42",
                "sourceSHA256": "e" * 64,
                "admissionState": "admittedControlled",
                "sourceBindingCommitment": "f" * 64,
                "rowCommitment": "0" * 64,
            }
        )
        tool.validate_row_shape(source)
        with self.assertRaises(tool.LedgerError):
            tool.validate_row_shape(dict(source, targetOrdinal="1"))

        target = base_row(tool, "TARGET")
        target.update(
            {
                "subjectID": "QRS-222222222222222222222222",
                "requirementID": "QRS-222222222222222222222222",
                "childID": "QTG-555555555555555555555555",
                "executionState": "nonExecutable",
                "targetOrdinal": "1",
                "governedOwner": "K3",
                "governedWave": "W1",
                "nonProductionClass": "-",
                "selectorPath": "Sources/K3.swift",
                "selectorID": "K3.owner",
                "pendingGateID": "A0",
                "targetCommitment": "1" * 64,
                "rowCommitment": "2" * 64,
            }
        )
        tool.validate_row_shape(target)
        with self.assertRaises(tool.LedgerError):
            tool.validate_row_shape(dict(target, nonProductionClass="R0"))
        with self.assertRaises(tool.LedgerError):
            tool.validate_row_shape(dict(target, pendingGateID="A0,R0"))

    def test_enforces_closed_source_kind_presence_and_admission_enums(self):
        """Catches dirty/precommit evidence being mislabeled as committed authority."""
        tool = load_tool()
        source = base_row(tool, "SOURCE")
        source.update(
            {
                "subjectID": "QRS-222222222222222222222222",
                "requirementID": "QRS-222222222222222222222222",
                "childID": "QSC-444444444444444444444444",
                "bindingOrdinal": "1",
                "sourceID": "SOURCE-ONE",
                "sourceKind": "repositoryPrecommit",
                "sourcePath": "docs/source.md",
                "sourceLocator": "REQ-1",
                "sourceRevision": "precommit-v1",
                "sourceCommit": "-",
                "sourceTree": "-",
                "sourceBlob": "d" * 40,
                "sourceByteLength": "42",
                "sourceSHA256": "e" * 64,
                "admissionState": "uncommittedReviewOnly",
                "sourceBindingCommitment": "f" * 64,
                "rowCommitment": "0" * 64,
            }
        )
        tool.validate_row_shape(source)
        with self.assertRaises(tool.LedgerError):
            tool.validate_row_shape(dict(source, sourceKind="repositoryCommitted"))
        with self.assertRaises(tool.LedgerError):
            tool.validate_row_shape(dict(source, admissionState="admitted"))
        with self.assertRaises(tool.LedgerError):
            tool.validate_row_shape(dict(source, admissionState="externalObservedOnly"))

        decision = dict(source)
        decision.update(sourceKind="decisionReceipt", admissionState="userDecisionOnly")
        tool.validate_row_shape(decision)
        with self.assertRaises(tool.LedgerError):
            tool.validate_row_shape(dict(decision, admissionState="admittedControlled"))

    def test_requirement_state_fold_fails_closed_except_exact_admission_placeholder(self):
        """Catches a pending source or unresolved target becoming executable."""
        tool = load_tool()
        requirement = {"disposition": "projectionOfControlledRequirement", "executionState": "sourceGoverned"}
        sources = [{"admissionState": "admittedControlled"}]
        targets = [
            {
                "executionState": "sourceGoverned",
                "governedOwner": "K3",
                "governedWave": "W1",
                "nonProductionClass": "-",
                "selectorPath": "Sources/K3.swift",
                "selectorID": "K3.owner",
                "pendingGateID": "-",
            }
        ]
        tool.validate_requirement_state(requirement, sources, targets)
        tool.validate_requirement_state(
            requirement,
            sources + [{"admissionState": "forensicEvidenceOnly"}],
            targets,
        )
        with self.assertRaises(tool.LedgerError):
            tool.validate_requirement_state(requirement, [{"admissionState": "pendingA0"}], targets)
        with self.assertRaises(tool.LedgerError):
            tool.validate_requirement_state(requirement, [{"admissionState": "forensicEvidenceOnly"}], targets)

        pending = {"disposition": "newControlDeltaPendingAdmission", "executionState": "nonExecutable"}
        placeholder = [
            {
                "executionState": "nonExecutable",
                "governedOwner": "design.admission",
                "governedWave": "-",
                "nonProductionClass": "admissionTask",
                "selectorPath": "-",
                "selectorID": "-",
                "pendingGateID": "A0",
            }
        ]
        tool.validate_requirement_state(pending, [{"admissionState": "pendingA0"}], placeholder)
        with self.assertRaises(tool.LedgerError):
            tool.validate_requirement_state(pending, [{"admissionState": "pendingA0"}], [dict(placeholder[0], pendingGateID="-")])

        known_owner_pending_selector = [
            {
                "executionState": "nonExecutable",
                "governedOwner": "K3",
                "governedWave": "W1",
                "nonProductionClass": "-",
                "selectorPath": "-",
                "selectorID": "-",
                "pendingGateID": "A0.selector",
            }
        ]
        tool.validate_requirement_state(pending, [{"admissionState": "pendingA0"}], known_owner_pending_selector)

        operational = {"disposition": "operationalScanGate", "executionState": "nonExecutable"}
        operational_placeholder = [dict(placeholder[0], pendingGateID="D0.supportedPrecreateObservationABI")]
        tool.validate_requirement_state(
            operational,
            [{"admissionState": "operationalEvidenceOnly"}],
            operational_placeholder,
        )
        with self.assertRaises(tool.LedgerError):
            tool.validate_requirement_state(
                operational,
                [{"admissionState": "operationalEvidenceOnly"}],
                [dict(placeholder[0], pendingGateID="D0.other")],
            )

    def test_enforces_disposition_source_compatibility_closed_sets(self):
        """Catches evidence or user decisions replacing the required source class."""
        tool = load_tool()
        cases = [
            ("projectionOfControlledRequirement", ["admittedControlled", "forensicEvidenceOnly"], "sourceGoverned"),
            ("forensicRiskInput", ["forensicEvidenceOnly", "userDecisionOnly"], "nonExecutable"),
            ("operationalScanGate", ["notStarted", "userDecisionOnly"], "nonExecutable"),
            ("newControlDeltaPendingAdmission", ["pendingProtectedIntake", "userDecisionOnly"], "nonExecutable"),
        ]
        for disposition, states, execution in cases:
            with self.subTest(disposition=disposition):
                tool.validate_disposition_source_compatibility(
                    {"disposition": disposition, "executionState": execution},
                    [{"admissionState": state} for state in states],
                )
        invalid = [
            ("projectionOfControlledRequirement", ["forensicEvidenceOnly"]),
            ("forensicRiskInput", ["userDecisionOnly"]),
            ("operationalScanGate", ["forensicEvidenceOnly"]),
            ("newControlDeltaPendingAdmission", ["userDecisionOnly"]),
        ]
        for disposition, states in invalid:
            with self.subTest(disposition=disposition, states=states):
                with self.assertRaises(tool.LedgerError):
                    tool.validate_disposition_source_compatibility(
                        {"disposition": disposition, "executionState": "nonExecutable"},
                        [{"admissionState": state} for state in states],
                    )

    def test_rejects_conflicting_unit_class_across_parent_and_child_rows(self):
        """Catches a child relabeling one UNIT to bypass provenance/authority rules."""
        tool = load_tool()
        unit = base_row(tool, "UNIT")
        unit.update(subjectID=unit["unitID"], sourceBindingCount="0", sourceBindingRoot="1" * 64, rowCommitment="2" * 64)
        child = base_row(tool, "CLAUSE")
        child["unitClass"] = "mixed"
        with self.assertRaises(tool.LedgerError):
            tool.validate_unit_class_consistency([unit, child])

    def test_rejects_malformed_ids_numbers_hashes_and_unknown_columns(self):
        """Catches permissive parsing that weakens stable identity or canonical bytes."""
        tool = load_tool()
        row = base_row(tool, "UNIT")
        row.update(
            {
                "subjectID": row["unitID"],
                "sourceBindingCount": "0",
                "sourceBindingRoot": "1" * 64,
                "rowCommitment": "2" * 64,
            }
        )
        mutations = [
            dict(row, unitStartByte="00"),
            dict(row, unitStartByte="9" * 5000),
            dict(row, unitSpanSHA256="ABC"),
            dict(row, unitID="QUN-short"),
            {**row, "unexpected": "value"},
        ]
        for mutated in mutations:
            with self.subTest(mutated=mutated):
                with self.assertRaises(tool.LedgerError):
                    tool.validate_row_shape(mutated)
        self.assertEqual(tool._canonical_uint("18446744073709551615", "boundary"), 0xFFFFFFFFFFFFFFFF)
        with self.assertRaises(tool.LedgerError):
            tool._canonical_uint("18446744073709551616", "boundary")


class CommitmentTests(unittest.TestCase):
    def test_typed_commitments_set_roots_and_row_root_are_domain_separated(self):
        """Catches delimiter hashing, self-hashing, or omission of count/domain."""
        tool = load_tool()
        self.assertEqual(
            tool.typed_commitment(b"qinao-source-disposition-clause/v1\0", ["1", "QRS-x", "1", "assertion", "2", "9", "a" * 64]),
            "8752aa8ea3c39cdedea54508e5f5fbb7dc26129ce49a9e0e6b106c23ce88b408",
        )
        self.assertEqual(
            tool.child_set_root(
                b"qinao-source-disposition-clause-set/v1\0",
                ["00" * 32, "11" * 32],
            ),
            "9243124fdf27b3565aacf592075a89b85bc08d3ca7d80ae6691d88b8f64162b0",
        )

        first = base_row(tool, "UNIT")
        first.update(
            {
                "subjectID": first["unitID"],
                "sourceBindingCount": "0",
                "sourceBindingRoot": "1" * 64,
            }
        )
        first["rowCommitment"] = tool.row_commitment(first)
        second = dict(first)
        second["unitID"] = "QUN-222222222222222222222222"
        second["subjectID"] = second["unitID"]
        second["rowCommitment"] = tool.row_commitment(second)
        self.assertEqual(tool.ledger_root([second, first]), tool.ledger_root([first, second]))
        self.assertNotEqual(tool.ledger_root([first]), tool.ledger_root([first, second]))

    def test_selected_ordinal_sorting_is_numeric_not_lexical(self):
        """Catches ordinal 10 sorting before ordinal 2."""
        tool = load_tool()
        rows = []
        for ordinal in (10, 2):
            row = base_row(tool, "CLAUSE")
            row.update(
                {
                    "subjectID": "QRS-222222222222222222222222",
                    "requirementID": "QRS-222222222222222222222222",
                    "childID": f"QCL-{ordinal:024x}",
                    "clauseOrdinal": str(ordinal),
                    "clauseRole": "assertion",
                    "clauseStartByte": "1",
                    "clauseEndByteExclusive": "9",
                    "clauseSHA256": "8" * 64,
                    "clauseCommitment": "9" * 64,
                    "rowCommitment": "a" * 64,
                }
            )
            rows.append(row)
        self.assertEqual([row["clauseOrdinal"] for row in tool.sort_rows(rows)], ["2", "10"])


class ScanIdentityTests(unittest.TestCase):
    def scan_row(self, tool, number, kind, scan_id, revision, state, artifacts):
        row = base_row(tool, "SOURCE")
        row.update(
            {
                "subjectID": "QRS-222222222222222222222222",
                "requirementID": "QRS-222222222222222222222222",
                "childID": "QSC-444444444444444444444444",
                "bindingOrdinal": "1",
                "sourceID": "SCAN-SOURCE",
                "sourceKind": "scanRecord",
                "sourcePath": "-",
                "sourceLocator": "scan-record",
                "sourceRevision": "v1",
                "sourceCommit": "-",
                "sourceTree": "-",
                "sourceBlob": "-",
                "sourceByteLength": "-",
                "sourceSHA256": "-",
                "admissionState": "notStarted" if number == "3" else "externalObservedOnly",
                "scanNumber": number,
                "scanKind": kind,
                "scanID": scan_id,
                "scanTargetRevision": revision,
                "scanOfficialState": state,
                "canonicalArtifactState": artifacts,
                "sourceBindingCommitment": "f" * 64,
                "rowCommitment": "0" * 64,
            }
        )
        return row

    def test_accepts_only_the_four_exact_scan_identities(self):
        """Catches renumbering, reviving #2, preallocating #3, or numbering Standard."""
        tool = load_tool()
        valid = [
            self.scan_row(tool, "1", "deep", "bcffa52e-53cf-4407-b216-14288ae07061", "c8f80486895e12e26d567e610c35a6e2141b3489", "complete", "canonicalUnavailable"),
            self.scan_row(tool, "2", "deep", "3d22f697-0c9d-4dbb-8c6a-871a9cfbcca9", "243c083f345f3586ef226020d42af4653b31a62a", "failed", "canonicalUnavailable"),
            self.scan_row(tool, "3", "deep", "-", "pendingD0Freeze", "notStarted", "canonicalPending"),
            self.scan_row(tool, "-", "standard", "dd2acd18-3ead-44fa-9c10-f8fd8c911aa7", "unknownFrozen", "unknownFrozen", "unknownFrozen"),
        ]
        for row in valid:
            with self.subTest(row=row):
                tool.validate_scan_source(row)
                tool.validate_row_shape(row)

        invalid = [
            dict(valid[0], scanNumber="2"),
            dict(valid[1], scanOfficialState="complete"),
            dict(valid[2], scanID="new-scan-id"),
            dict(valid[3], scanNumber="1"),
        ]
        for row in invalid:
            with self.subTest(row=row):
                with self.assertRaises(tool.LedgerError):
                    tool.validate_scan_source(row)

    def test_scan_identity_includes_exact_admission_state(self):
        """Catches swapping observed completed scans with the not-started #3 admission."""
        tool = load_tool()
        deep_scan_1 = self.scan_row(
            tool,
            "1",
            "deep",
            "bcffa52e-53cf-4407-b216-14288ae07061",
            "c8f80486895e12e26d567e610c35a6e2141b3489",
            "complete",
            "canonicalUnavailable",
        )
        deep_scan_3 = self.scan_row(
            tool,
            "3",
            "deep",
            "-",
            "pendingD0Freeze",
            "notStarted",
            "canonicalPending",
        )
        invalid = (
            dict(deep_scan_1, admissionState="notStarted"),
            dict(deep_scan_3, admissionState="externalObservedOnly"),
        )
        for row in invalid:
            with self.subTest(scanNumber=row["scanNumber"], admissionState=row["admissionState"]):
                with self.assertRaises(tool.LedgerError):
                    tool.validate_scan_source(row)


class FrozenSpecSemanticSetTests(unittest.TestCase):
    def setUp(self):
        self.tool = load_tool()
        self.spec_data = SPEC_PATH.read_bytes()

    def test_exact_spec_identity_is_frozen_after_named_contracts_and_before_tsv(self):
        """Catches accepting a same-shaped recovery spec with foreign bytes or Git identity."""
        validator = getattr(self.tool, "validate_frozen_spec_identity", None)
        self.assertTrue(callable(validator), "frozen spec identity validator is missing")
        identity = validator(self.spec_data, self.tool.SPEC_REL)
        self.assertEqual(
            identity,
            {
                "specSHA256": "d2c7f8954d8559e8277a184035da1e76acf378475e630e4aadfa4b86268fa21b",
                "specBlob": "84346d35c8f366dca792f0c2e9fdbfb5161dc584",
                "specByteLength": 92869,
                "specLineCount": 1556,
            },
        )
        drifted = self.spec_data.replace(b"Execution authority: none.", b"Execution authority: zero.", 1)
        with self.assertRaisesRegex(self.tool.LedgerError, "frozen specification identity"):
            self.tool.verify_tsv(drifted, b"wrong\theader\n", self.tool.SPEC_REL)

    def test_domain_separated_set_roots_are_sorted_and_duplicate_closed(self):
        """Catches delimiter hashing, source-order roots, or duplicate members."""
        root_fn = getattr(self.tool, "semantic_set_root", None)
        self.assertTrue(callable(root_fn), "semantic set-root function is missing")
        unit_members = [
            ("QUN-000000000000000000000001", "evidence"),
            ("QUN-000000000000000000000002", "mixed"),
        ]
        req_members = [
            ("QRS-000000000000000000000001", "QUN-000000000000000000000001", "1" * 64),
            ("QRS-000000000000000000000002", "QUN-000000000000000000000002", "2" * 64),
        ]
        self.assertEqual(
            root_fn(self.tool.UNIT_CLASS_MEMBER_DOMAIN, self.tool.UNIT_CLASS_SET_DOMAIN, unit_members),
            "292869057cc834e29a6c29b92a2047c7b312938e84204ea5965038407207b9ab",
        )
        self.assertEqual(
            root_fn(
                self.tool.REQUIREMENT_SEMANTIC_MEMBER_DOMAIN,
                self.tool.REQUIREMENT_SEMANTIC_SET_DOMAIN,
                list(reversed(req_members)),
            ),
            "46193efb74508742778012ac0d68e67baac9521bf719861e8b1d97157016a61f",
        )
        with self.assertRaises(self.tool.LedgerError):
            root_fn(self.tool.UNIT_CLASS_MEMBER_DOMAIN, self.tool.UNIT_CLASS_SET_DOMAIN, unit_members * 2)

    def test_semantic_summary_detects_class_and_requirement_omission_or_replacement(self):
        """Catches a classification or requirement mutation hidden behind valid row counts."""
        summary_fn = getattr(self.tool, "_semantic_set_summary_from_validated_index", None)
        self.assertTrue(callable(summary_fn), "validated semantic set summary is missing")
        unit_one = self.tool._ValidatedUnitProjection(
            "QUN-000000000000000000000001", "evidence", "a" * 64, (),
        )
        unit_two = self.tool._ValidatedUnitProjection(
            "QUN-000000000000000000000002", "mixed", "b" * 64, (),
        )
        requirement = self.tool._ValidatedRequirementProjection(
            "QRS-000000000000000000000001",
            unit_two.unitID,
            "1" * 64,
            "normativeCurrent",
            "nonExecutable",
            (),
            (),
        )
        baseline = summary_fn(self.tool._ValidatedProjectionIndex((unit_one, unit_two), (requirement,)))
        changed_class = summary_fn(self.tool._ValidatedProjectionIndex((unit_one._replace(unitClass="introductory"), unit_two), (requirement,)))
        missing_requirement = summary_fn(self.tool._ValidatedProjectionIndex((unit_one, unit_two), ()))
        replaced_requirement = summary_fn(
            self.tool._ValidatedProjectionIndex(
                (unit_one, unit_two),
                (requirement._replace(requirementSemanticSHA256="2" * 64),),
            )
        )
        self.assertNotEqual(changed_class["unitClassSetRoot"], baseline["unitClassSetRoot"])
        self.assertNotEqual(missing_requirement["requirementSemanticSetRoot"], baseline["requirementSemanticSetRoot"])
        self.assertNotEqual(replaced_requirement["requirementSemanticSetRoot"], baseline["requirementSemanticSetRoot"])

    def test_exact_spec_rejects_all_evidence_and_zero_requirements(self):
        """Catches satisfying structural UNIT coverage while erasing normative classification."""
        validator = getattr(self.tool, "validate_frozen_semantic_sets", None)
        self.assertTrue(callable(validator), "frozen semantic-set validator is missing")
        index = self.tool._ValidatedProjectionIndex(
            tuple(
                self.tool._ValidatedUnitProjection(
                    f"QUN-{ordinal:024x}", "evidence", f"{ordinal:064x}", (),
                )
                for ordinal in range(325)
            ),
            (),
        )
        with self.assertRaises(self.tool.LedgerError):
            validator(index, self.tool.SPEC_REL)

    def test_frozen_semantic_pins_are_explicit_and_repin_ready(self):
        """Catches silently retaining the obsolete independent-domain roots."""
        pins = getattr(self.tool, "FROZEN_SEMANTIC_SET_PINS", None)
        self.assertEqual(
            pins,
            {
                "unitClassSetCount": 325,
                "unitClassSetRoot": "3129b6e700aa67202d46688384d04d95ea0fb8cf43f5e9e0c8392a1a9eec1c70",
                "unitClassCounts": {
                    "normativeBearing": 238,
                    "evidence": 63,
                    "introductory": 6,
                    "mixed": 18,
                },
                "requirementSemanticSetCount": 1127,
                "requirementSemanticSetRoot": "93e3fe0dec5c8837643b2b838773f921ea2a06ecde307438b6cdec24a40d2a23",
            },
        )


class RequirementChildParentTests(unittest.TestCase):
    def assert_child_mismatch_rejected(self, record_type: str):
        tool = load_tool()
        validator = getattr(tool, "validate_requirement_child_parent", None)
        self.assertTrue(callable(validator), "requirement child-parent validator is missing")
        parent = {
            "requirementID": "QRS-111111111111111111111111",
            "unitID": "QUN-111111111111111111111111",
            "unitClass": "normativeBearing",
        }
        child = {
            "recordType": record_type,
            "requirementID": parent["requirementID"],
            "unitID": parent["unitID"],
            "unitClass": parent["unitClass"],
        }
        validator(child, parent)
        with self.assertRaises(tool.LedgerError):
            validator(dict(child, unitID="QUN-222222222222222222222222"), parent)
        with self.assertRaises(tool.LedgerError):
            validator(dict(child, unitClass="mixed"), parent)

    def test_clause_cannot_switch_parent_unit_or_class(self):
        """Catches a CLAUSE borrowing a foreign UNIT while keeping the parent requirement ID."""
        self.assert_child_mismatch_rejected("CLAUSE")

    def test_source_cannot_switch_parent_unit_or_class(self):
        """Catches requirement SOURCE provenance being attached under a foreign UNIT."""
        self.assert_child_mismatch_rejected("SOURCE")

    def test_target_cannot_switch_parent_unit_or_class(self):
        """Catches a TARGET mapping inheriting identity from the wrong parent UNIT."""
        self.assert_child_mismatch_rejected("TARGET")

    def test_nested_shared_context_cannot_hide_overlap_with_an_assertion(self):
        """Catches adjacent-pair checking missing a long interval bridged by a nested one."""
        tool = load_tool()
        clauses = [
            {"clauseStartByte": "0", "clauseEndByteExclusive": "100", "clauseRole": "sharedContext"},
            {"clauseStartByte": "10", "clauseEndByteExclusive": "20", "clauseRole": "sharedContext"},
            {"clauseStartByte": "30", "clauseEndByteExclusive": "40", "clauseRole": "assertion"},
        ]
        with self.assertRaises(tool.LedgerError):
            tool.validate_clause_overlaps(clauses)
        tool.validate_clause_overlaps(clauses[:2])

    def test_overlap_sweep_matches_the_complete_pairwise_oracle(self):
        """Catches sweep-state errors at equal starts, nesting, and touching endpoints."""
        tool = load_tool()
        spans = ((0, 2), (1, 3), (2, 4), (0, 4))
        roles = ("assertion", "sharedContext")
        for first in spans:
            for second in spans:
                for third in spans:
                    selected = (first, second, third)
                    for role_mask in range(8):
                        clauses = [
                            {
                                "clauseStartByte": str(start),
                                "clauseEndByteExclusive": str(end),
                                "clauseRole": roles[(role_mask >> index) & 1],
                            }
                            for index, (start, end) in enumerate(selected)
                        ]
                        expected_rejection = any(
                            max(int(left["clauseStartByte"]), int(right["clauseStartByte"]))
                            < min(int(left["clauseEndByteExclusive"]), int(right["clauseEndByteExclusive"]))
                            and not (
                                left["clauseRole"] == "sharedContext"
                                and right["clauseRole"] == "sharedContext"
                            )
                            for left_index, left in enumerate(clauses)
                            for right in clauses[left_index + 1:]
                        )
                        try:
                            tool.validate_clause_overlaps(clauses)
                            actual_rejection = False
                        except tool.LedgerError:
                            actual_rejection = True
                        self.assertEqual(
                            actual_rejection,
                            expected_rejection,
                            (selected, role_mask),
                        )


class ProvenanceMappingProjectionTests(unittest.TestCase):
    def setUp(self):
        self.tool = load_tool()

    def source(self, source_id: str = "S1"):
        return self.tool._SourceProjection(
            source_id, "externalFrozen", "-", "externalObservedOnly", "-",
            "-", "-", "-", "-", "-",
        )

    def target(self, selector_id: str = "K3.owner"):
        return self.tool._TargetProjection(
            "runtime.semantic-dag", "W1", "-", "Sources/K3.swift",
            selector_id, "nonExecutable", "-",
        )

    def unit(self, suffix: str = "1", sources=()):
        return self.tool._ValidatedUnitProjection(
            "QUN-" + suffix * 24, "evidence", suffix * 64, tuple(sources),
        )

    def requirement(self, suffix: str = "3", sources=(), targets=()):
        return self.tool._ValidatedRequirementProjection(
            "QRS-" + suffix * 24,
            "QUN-" + "2" * 24,
            suffix * 64,
            "forensicRiskInput",
            "nonExecutable",
            tuple(sources),
            tuple(targets),
        )

    def summary(self, index):
        return self.tool._summarize_validated_projection_index(index)

    def test_projection_excludes_recursive_identity_fields_and_preserves_child_order(self):
        """Catches a verifier self-hash cycle or treating ordinal child order as a set."""
        self.assertEqual(
            self.tool.PROVENANCE_SOURCE_PROJECTION_FIELDS,
            (
                "sourceID", "sourceKind", "sourcePath", "admissionState", "scanNumber",
                "scanKind", "scanID", "scanTargetRevision", "scanOfficialState",
                "canonicalArtifactState",
            ),
        )
        self.assertFalse(
            {"sourceLocator", "sourceRevision", "sourceCommit", "sourceTree", "sourceBlob",
             "sourceByteLength", "sourceSHA256"}
            & set(self.tool.PROVENANCE_SOURCE_PROJECTION_FIELDS)
        )
        first, second = self.source("S1"), self.source("S2")
        forward = self.summary(self.tool._ValidatedProjectionIndex((self.unit(sources=(first, second)),), ()))
        self.assertEqual(
            forward,
            {
                "provenanceMappingUnitCount": 1,
                "provenanceMappingRequirementCount": 0,
                "provenanceMappingRoot": "e764549ebbc88a17ba8be88d3befc107ddd40e83b2ae9f9e1cdc8fe6fb76dac7",
            },
        )
        reversed_children = self.summary(self.tool._ValidatedProjectionIndex((self.unit(sources=(second, first)),), ()))
        self.assertNotEqual(forward["provenanceMappingRoot"], reversed_children["provenanceMappingRoot"])

        left, right = self.unit("1"), self.unit("2")
        self.assertEqual(
            self.summary(self.tool._ValidatedProjectionIndex((left, right), ())),
            self.summary(self.tool._ValidatedProjectionIndex((right, left), ())),
        )

    def test_raw_rows_and_wrong_nested_types_cannot_reach_hasher(self):
        """Catches the orphan-SOURCE-to-valid-empty-root trust-boundary exploit."""
        raw = [{"recordType": "SOURCE", "unitID": "QUN-UNKNOWN", "requirementID": "-"}]
        with self.assertRaises(self.tool.LedgerError):
            self.summary(raw)
        malformed = self.tool._ValidatedProjectionIndex(
            (self.unit()._replace(sources=(("not", "a", "typed", "projection"),)),),
            (),
        )
        with self.assertRaises(self.tool.LedgerError):
            self.summary(malformed)

    def test_validated_projection_index_is_deeply_immutable_and_string_typed(self):
        """Catches mutable nested containers or non-UTF8 scalar types crossing the seal."""
        mutable_outer = self.tool._ValidatedProjectionIndex([self.unit()], [])
        mutable_inner = self.tool._ValidatedProjectionIndex(
            (self.unit()._replace(sources=[self.source()]),), ()
        )
        non_string = self.tool._ValidatedProjectionIndex(
            (self.unit()._replace(sources=(self.source()._replace(scanNumber=3),)),),
            (),
        )
        for index in (mutable_outer, mutable_inner, non_string):
            with self.subTest(index=index):
                with self.assertRaises(self.tool.LedgerError):
                    self.summary(index)

    def test_projection_rejects_duplicate_source_and_target_tuples(self):
        """Catches multiplicity laundering inside one validated subject projection."""
        source = self.source()
        with self.assertRaises(self.tool.LedgerError):
            self.summary(self.tool._ValidatedProjectionIndex((self.unit(sources=(source, source)),), ()))
        target = self.target()
        with self.assertRaises(self.tool.LedgerError):
            self.summary(
                self.tool._ValidatedProjectionIndex(
                    (self.unit("2"),),
                    (self.requirement(targets=(target, target)),),
                )
            )

    def test_projection_builder_requires_exact_source_and_target_consumption(self):
        """Catches a validated index silently omitting an already-classified child row."""
        source_row = dict(zip(self.tool.PROVENANCE_SOURCE_PROJECTION_FIELDS, self.source(), strict=True))
        unit_row = {
            "unitID": "QUN-" + "1" * 24,
            "unitClass": "evidence",
            "unitSemanticSHA256": "1" * 64,
        }
        with self.assertRaises(self.tool.LedgerError):
            self.tool._build_validated_projection_index(
                (unit_row,), {}, {unit_row["unitID"]: (source_row,)}, {},
                expected_source_count=2, expected_target_count=0,
            )

    def test_frozen_provenance_mapping_pins_are_exact(self):
        self.assertEqual(
            self.tool.FROZEN_PROVENANCE_MAPPING_PINS,
            {
                "provenanceMappingUnitCount": 325,
                "provenanceMappingRequirementCount": 1127,
                "provenanceMappingRoot": "402ea7a7e903aa2054c4fcb16fb66b3b22ee1804f8165e5e1b31607e3a577d5e",
            },
        )


class NamedContractTests(unittest.TestCase):
    EXPECTED_NAMES = frozenset(
        {
            "ReportProjectionV1",
            "VerifierV1",
            "UnitNormV1",
            "HeaderV1",
            "RecordShapeV1",
            "AuthoritySetV1",
            "RecoveryQualitySetV1",
        }
    )

    def setUp(self):
        self.tool = load_tool()
        self.spec_data = SPEC_PATH.read_bytes()

    def validate(self, data: bytes | None = None, spec_path: str | None = None):
        """Keep pre-implementation failures as assertions, not AttributeErrors."""
        validator = getattr(self.tool, "validate_named_contracts", None)
        self.assertTrue(callable(validator), "named-contract validator is missing")
        return validator(
            self.spec_data if data is None else data,
            getattr(self.tool, "SPEC_REL", "missing-SPEC_REL") if spec_path is None else spec_path,
        )

    def replace_once(self, old: bytes, new: bytes) -> bytes:
        self.assertEqual(self.spec_data.count(old), 1, old)
        return self.spec_data.replace(old, new, 1)

    def test_real_frozen_spec_closes_all_seven_named_contracts(self):
        """Catches a partial registry or a validator that reports success without a root."""
        required = getattr(self.tool, "REQUIRED_NAMED_CONTRACTS", None)
        self.assertEqual(required, self.EXPECTED_NAMES)
        self.assertGreater(len(required), 0)
        result = self.validate()
        self.assertEqual(result["namedContractCount"], self.tool.FROZEN_NAMED_CONTRACT_COUNT)
        self.assertEqual(result["namedContractRoot"], self.tool.FROZEN_NAMED_CONTRACT_ROOT)

    def test_required_registry_cannot_be_emptied_to_bypass_exact_spec_validation(self):
        """Catches deleting every registry entry and treating zero checks as success."""
        registry = getattr(self.tool, "NAMED_CONTRACT_OCCURRENCES", None)
        self.assertIsNotNone(registry, "named-contract occurrence registry is missing")
        self.tool.NAMED_CONTRACT_OCCURRENCES = {}
        try:
            with self.assertRaises(self.tool.LedgerError):
                self.validate()
        finally:
            self.tool.NAMED_CONTRACT_OCCURRENCES = registry

    def test_rejects_deleted_or_duplicated_named_occurrences(self):
        """Catches a name disappearing or being copied without a second definition."""
        deleted = self.replace_once(
            b"byte-equal to ReportProjectionV1 derived",
            b"byte-equal to ReportProjectionV0 derived",
        )
        duplicated = self.replace_once(
            b"byte-equal to ReportProjectionV1 derived",
            b"byte-equal to ReportProjectionV1 ReportProjectionV1 derived",
        )
        for mutation in (deleted, duplicated):
            with self.subTest(mutation=mutation[:16]):
                with self.assertRaises(self.tool.LedgerError):
                    self.validate(mutation)

    def test_rejects_relocated_reference_even_when_occurrence_count_matches(self):
        """Catches satisfying a reference count by moving the name to an unrelated UNIT."""
        moved = self.replace_once(
            b"and ReportProjectionV1's exact bytes verify",
            b"and ReportProjectionV0's exact bytes verify",
        ) + b"\nReportProjectionV1\n"
        with self.assertRaises(self.tool.LedgerError):
            self.validate(moved)

    def test_rejects_named_occurrence_hidden_in_excluded_heading_bytes(self):
        """Catches headings escaping occurrence enumeration because they are not UNIT text."""
        heading_duplicate = self.spec_data + b"\n## ReportProjectionV1\n"
        with self.assertRaises(self.tool.LedgerError):
            self.validate(heading_duplicate)

    def test_header_contract_rejects_wrong_qun_and_reordered_names(self):
        """Catches a foreign fenced-code anchor or a 64-column permutation."""
        wrong_qun = self.replace_once(
            b"QUN-f72aa897afa9968903edcbab names, TAB-joined",
            b"QUN-000000000000000000000000 names, TAB-joined",
        )
        with self.assertRaises(self.tool.LedgerError):
            self.validate(wrong_qun)

        reordered = self.replace_once(
            b"sourceID sourceKind",
            b"sourceKind sourceID",
        )
        units = self.tool.extract_markdown_units(reordered, self.tool.SPEC_REL)
        header_unit = [
            unit
            for unit in units
            if unit["startLine"] == 1309 and unit["anchorKind"] == "fencedCode"
        ]
        self.assertEqual(len(header_unit), 1)
        reordered = reordered.replace(
            b"QUN-f72aa897afa9968903edcbab names, TAB-joined",
            (header_unit[0]["unitID"] + " names, TAB-joined").encode("ascii"),
            1,
        )
        with self.assertRaises(self.tool.LedgerError):
            self.validate(reordered)

    def test_authority_set_contract_rejects_any_four_state_drift(self):
        """Catches broadening or replacing one authority-bearing admission state."""
        drifted = self.replace_once(
            b"AuthoritySetV1 source-state set is `admittedControlled | pendingA0 |\n   pendingProtectedIntake | uncommittedReviewOnly`",
            b"AuthoritySetV1 source-state set is `admittedControlled | pendingA1 |\n   pendingProtectedIntake | uncommittedReviewOnly`",
        )
        with self.assertRaises(self.tool.LedgerError):
            self.validate(drifted)

    def test_authority_admission_tuple_is_one_source_for_payload_fold_and_compatibility(self):
        """Catches three authority-state copies drifting independently."""
        states = getattr(self.tool, "AUTHORITY_ADMISSION_STATES", None)
        expected = (
            "admittedControlled",
            "pendingA0",
            "pendingProtectedIntake",
            "uncommittedReviewOnly",
        )
        self.assertEqual(states, expected)
        self.validate()
        self.tool.AUTHORITY_ADMISSION_STATES = ("admittedControlled",)
        try:
            with self.assertRaises(self.tool.LedgerError):
                self.validate()
            with self.assertRaises(self.tool.LedgerError):
                self.tool.validate_disposition_source_compatibility(
                    {"disposition": "projectionOfControlledRequirement", "executionState": "nonExecutable"},
                    [{"admissionState": "pendingA0"}],
                )
            with self.assertRaises(self.tool.LedgerError):
                self.tool.validate_requirement_state(
                    {"disposition": "projectionOfControlledRequirement", "executionState": "nonExecutable"},
                    [{"admissionState": "pendingA0"}],
                    [
                        {
                            "executionState": "nonExecutable",
                            "governedOwner": "K3",
                            "governedWave": "W1",
                            "nonProductionClass": "-",
                            "selectorPath": "Sources/K3.swift",
                            "selectorID": "K3.owner",
                            "pendingGateID": "A0",
                        }
                    ],
                )
        finally:
            self.tool.AUTHORITY_ADMISSION_STATES = states

    def test_verifier_contract_binds_only_the_exact_source_path(self):
        """Catches path drift without introducing a verifier-self-hash dependency."""
        exact_path = b"docs/superpowers/evidence/2026-08-28-qinao-source-disposition-ledger-v1.py"
        self.assertEqual(self.spec_data.count(exact_path), 1)
        drifted = self.spec_data.replace(exact_path, exact_path.replace(b"-v1.py", b"-v2.py"), 1)
        with self.assertRaises(self.tool.LedgerError):
            self.validate(drifted)

    def test_unit_norm_contract_reuses_exact_nfc_list_and_ascii_whitespace_rules(self):
        """Catches a contract whose prose drifts away from the executable normalizer."""
        result = self.validate()
        self.assertEqual(result["namedContractCount"], 7)
        self.assertEqual(
            self.tool._normalize_unit(b"  12. A\xcc\x8a\t \n B\x0b\x0c\r C  ", "listLeader"),
            "\u00c5 B C",
        )
        self.assertEqual(self.tool._normalize_unit(b"12. A\xcc\x8a\tB", "prose"), "12. \u00c5 B")
        drifted = self.replace_once(
            b"maximal ASCII whitespace run (`09-0D` or `20`)",
            b"maximal ASCII whitespace run (`09-0C` or `20`)",
        )
        with self.assertRaises(self.tool.LedgerError):
            self.validate(drifted)

    def test_report_projection_contract_binds_report_three_json_and_frozen_projection(self):
        """Catches weakening report bytes, canonical inputs, or frozen implementation binding."""
        mutations = [
            self.replace_once(b"`report.md`", b"`report.mx`"),
            self.replace_once(b"`scan-manifest.json`, `findings.json`, and `coverage.json`", b"`scan-manifest.json`, `findings.json`, and `summary.json`"),
            self.replace_once(b"under the frozen report-\nprojection implementation", b"under the mutable report-\nprojection implementation"),
            self.replace_once(b"`scripts/report_projection.py`", b"`scripts/report_projection_v2.py`"),
            self.replace_once(b"(41,677 bytes)", b"(41,678 bytes)"),
            self.replace_once(
                b"d7a90862f92c29e2eb30c36dfa52c6e01a7c53a6cfa6ed4866b1a58aadae34ed",
                b"0" * 64,
            ),
        ]
        for mutation in mutations:
            with self.subTest(mutation=mutation[:16]):
                with self.assertRaises(self.tool.LedgerError):
                    self.validate(mutation)

    def test_recovery_quality_contract_binds_heading_ordered_five_cases_and_reference(self):
        """Catches treating RecoveryQualitySetV1 as a mere occurrence-count assertion."""
        heading = (
            b"#### `RecoveryQualitySetV1` is exactly these five `BASRecoveryQuality` cases, "
            b"the derived non-Codable UI projection over reopened evidence."
        )
        reference = (
            b"`RecoveryQualitySetV1` is no reducer input, authority, or alias/compatibility\n"
            b"wire material."
        )
        mutations = [
            self.spec_data + b"\n" + heading + b"\n",
            self.replace_once(
                b"- `exactAppOwnedBytes`: required Qinao-owned committed bytes and receipts reopen\n  byte-exactly;\n"
                b"- `deterministicReplay`: pure work re-executes from the same frozen inputs;",
                b"- `deterministicReplay`: pure work re-executes from the same frozen inputs;\n\n"
                b"- `exactAppOwnedBytes`: required Qinao-owned committed bytes and receipts reopen\n  byte-exactly;",
            ),
            self.replace_once(
                b"- `unavailable`: lawful recovery cannot be proven.",
                b"- `unavailable`: lawful recovery cannot be proven.\n\n- `bestEffort`: recovery is attempted.",
            ),
            self.replace_once(reference, b"Recovery quality is no reducer input.") + b"\n" + reference + b"\n",
        ]
        for mutation in mutations:
            with self.subTest(mutation=mutation[-80:]):
                with self.assertRaises(self.tool.LedgerError):
                    self.validate(mutation)

    def test_record_shape_contract_binds_closed_required_conditional_and_null_semantics(self):
        """Catches turning the record matrix into an advisory or open shape."""
        mutations = [
            self.replace_once(
                b"Define RecordShapeV1 as a closed matrix; every\n   field is required, conditionally allowed, or `-`",
                b"Define RecordShapeV1 as an open matrix; every\n   field is required, conditionally allowed, or `-`",
            ),
            self.replace_once(
                b"RecordShapeV1 validates every required\n   and forbidden field; it is not merely documentation",
                b"RecordShapeV1 suggests every required\n   and forbidden field; it is not merely documentation",
            ),
            self.replace_once(b"RecordShapeV1 scan-field nulls", b"RecordShapeV1 scan-field values"),
        ]
        for mutation in mutations:
            with self.subTest(mutation=mutation[:16]):
                with self.assertRaises(self.tool.LedgerError):
                    self.validate(mutation)

    def test_record_shape_contract_binds_provenance_projection_schema_and_domains(self):
        """Catches a same-length field swap or domain drift hidden by a newly repinned data root."""
        source_fields = self.tool.PROVENANCE_SOURCE_PROJECTION_FIELDS
        target_fields = self.tool.PROVENANCE_TARGET_PROJECTION_FIELDS
        domains = (
            self.tool.PROVENANCE_UNIT_MEMBER_DOMAIN,
            self.tool.PROVENANCE_REQUIREMENT_MEMBER_DOMAIN,
            self.tool.PROVENANCE_MAPPING_SET_DOMAIN,
        )
        mutations = (
            ("PROVENANCE_SOURCE_PROJECTION_FIELDS", source_fields[:-2] + tuple(reversed(source_fields[-2:]))),
            ("PROVENANCE_TARGET_PROJECTION_FIELDS", target_fields[:-2] + tuple(reversed(target_fields[-2:]))),
            ("PROVENANCE_MAPPING_SET_DOMAIN", b"qinao-provenance-mapping-set/v2\0"),
        )
        try:
            for name, mutation in mutations:
                with self.subTest(name=name):
                    original = getattr(self.tool, name)
                    setattr(self.tool, name, mutation)
                    with self.assertRaises(self.tool.LedgerError):
                        self.validate()
                    setattr(self.tool, name, original)
        finally:
            self.tool.PROVENANCE_SOURCE_PROJECTION_FIELDS = source_fields
            self.tool.PROVENANCE_TARGET_PROJECTION_FIELDS = target_fields
            (
                self.tool.PROVENANCE_UNIT_MEMBER_DOMAIN,
                self.tool.PROVENANCE_REQUIREMENT_MEMBER_DOMAIN,
                self.tool.PROVENANCE_MAPPING_SET_DOMAIN,
            ) = domains

    def test_exact_spec_validation_runs_before_tsv_parsing_but_fixtures_are_exempt(self):
        """Catches malformed ledgers masking named-contract drift or fixtures being overconstrained."""
        fixture = self.validate(b"# H\nFixture.\n", "fixture.md")
        self.assertEqual(fixture["namedContractCount"], 0)
        self.assertRegex(fixture["namedContractRoot"], r"^[0-9a-f]{64}$")

        drifted = self.replace_once(
            b"The closed VerifierV1 source path is:",
            b"The open VerifierV1 source path is:",
        )
        with self.assertRaisesRegex(self.tool.LedgerError, "VerifierV1"):
            self.tool.verify_tsv(drifted, b"wrong\theader\n", self.tool.SPEC_REL)

    def test_official_verifier_is_purpose_bound_to_exact_spec_identity(self):
        """Catches marker removal plus alias-path relabeling bypassing all frozen gates."""
        with self.assertRaisesRegex(self.tool.LedgerError, "purpose-bound"):
            self.tool.verify_tsv(b"# H\nMarker-free alias.\n", b"wrong\theader\n", "alias.md")

    def test_recovery_spec_or_named_markers_cannot_hide_behind_an_alias_path(self):
        """Catches relabeling recovery-spec bytes as an exempt fixture."""
        with self.assertRaises(self.tool.LedgerError):
            self.validate(self.spec_data, "alias.md")
        markers = [
            b"# Qinao Recovery Spine A+ and Deep Scan Closure Design",
            *(name.encode("ascii") for name in sorted(self.EXPECTED_NAMES)),
            b"qinao-source-disposition-ledger/v1",
            b"qinao-markdown-unit-extractor/v1",
        ]
        for marker in markers:
            with self.subTest(marker=marker):
                with self.assertRaises(self.tool.LedgerError):
                    self.validate(b"# Fixture\n" + marker + b"\n", "alias.md")

    def test_record_shape_root_commits_executable_header_order_null_and_allowed_sets(self):
        """Catches a root that stays stable while executable record shapes drift."""
        baseline = self.validate()["namedContractRoot"]
        record_shapes = getattr(self.tool, "RECORD_SHAPES", None)
        self.assertIsNotNone(record_shapes, "single RecordShape declaration is missing")
        unit = base_row(self.tool, "UNIT")
        unit.update(
            subjectID=unit["unitID"],
            sourceBindingCount="0",
            sourceBindingRoot="1" * 64,
            rowCommitment="2" * 64,
            disposition="forensicRiskInput",
        )
        with self.assertRaises(self.tool.LedgerError):
            self.tool.validate_row_shape(unit)

        mutated_shapes = {
            kind: {
                key: ({condition: frozenset(fields) for condition, fields in value.items()} if isinstance(value, dict) else frozenset(value))
                for key, value in shape.items()
            }
            for kind, shape in record_shapes.items()
        }
        mutated_shapes["UNIT"]["allowed"] = mutated_shapes["UNIT"]["allowed"] | {"disposition"}
        self.tool.RECORD_SHAPES = mutated_shapes
        try:
            self.tool.validate_row_shape(unit)
            with self.assertRaises(self.tool.LedgerError):
                self.validate()
        finally:
            self.tool.RECORD_SHAPES = record_shapes

        header = self.tool.HEADER
        self.tool.HEADER = (header[1], header[0], *header[2:])
        try:
            with self.assertRaises(self.tool.LedgerError):
                self.validate()
        finally:
            self.tool.HEADER = header

        record_rank = self.tool.RECORD_RANK
        self.tool.RECORD_RANK = dict(record_rank, UNIT=1, REQUIREMENT=0)
        try:
            with self.assertRaises(self.tool.LedgerError):
                self.validate()
        finally:
            self.tool.RECORD_RANK = record_rank

        null = self.tool.NULL
        self.tool.NULL = "~"
        try:
            with self.assertRaises(self.tool.LedgerError):
                self.validate()
        finally:
            self.tool.NULL = null

    def test_source_kind_field_rules_are_one_fact_source_for_runtime_and_named_root(self):
        """Catches runtime SOURCE presence/equality rules drifting from RecordShapeV1."""
        rules = getattr(self.tool, "SOURCE_KIND_FIELD_RULES", None)
        self.assertIsNotNone(rules, "declarative SOURCE kind field rules are missing")
        self.validate()

        committed = base_row(self.tool, "SOURCE")
        committed.update(
            subjectID="QRS-222222222222222222222222",
            requirementID="QRS-222222222222222222222222",
            childID="QSC-444444444444444444444444",
            bindingOrdinal="1",
            sourceID="SOURCE-ONE",
            sourceKind="repositoryCommitted",
            sourcePath="docs/source.md",
            sourceLocator="REQ-1",
            sourceRevision="v1",
            sourceCommit="b" * 40,
            sourceTree="c" * 40,
            sourceBlob="d" * 40,
            sourceByteLength="42",
            sourceSHA256="e" * 64,
            admissionState="admittedControlled",
            sourceBindingCommitment="f" * 64,
            rowCommitment="0" * 64,
        )
        precommit = dict(
            committed,
            sourceKind="repositoryPrecommit",
            sourceCommit="-",
            sourceTree="-",
            admissionState="uncommittedReviewOnly",
        )
        decision = dict(
            precommit,
            sourceKind="decisionReceipt",
            admissionState="userDecisionOnly",
        )

        cases = (
            (
                "required",
                dict(committed, sourceTree="-"),
                "repositoryCommitted",
                "required",
                "sourceTree",
                "remove",
            ),
            (
                "forbidden",
                dict(precommit, sourceCommit="b" * 40),
                "repositoryPrecommit",
                "forbidden",
                "sourceCommit",
                "remove",
            ),
            (
                "equals",
                decision,
                "decisionReceipt",
                "equals",
                "sourceRevision",
                "unexpected-revision",
            ),
        )
        for label, candidate, kind, section, field, operation in cases:
            with self.subTest(rule=label):
                if label != "equals":
                    with self.assertRaises(self.tool.LedgerError):
                        self.tool.validate_row_shape(candidate)
                else:
                    self.tool.validate_row_shape(candidate)

                mutated = {
                    source_kind: {
                        "required": frozenset(rule["required"]),
                        "forbidden": frozenset(rule["forbidden"]),
                        "equals": dict(rule["equals"]),
                    }
                    for source_kind, rule in rules.items()
                }
                if operation == "remove":
                    mutated[kind][section] = mutated[kind][section] - {field}
                else:
                    mutated[kind][section][field] = operation
                self.tool.SOURCE_KIND_FIELD_RULES = mutated
                try:
                    if label != "equals":
                        self.tool.validate_row_shape(candidate)
                    else:
                        with self.assertRaises(self.tool.LedgerError):
                            self.tool.validate_row_shape(candidate)
                    with self.assertRaises(self.tool.LedgerError):
                        self.validate()
                finally:
                    self.tool.SOURCE_KIND_FIELD_RULES = rules

    def test_source_admission_compatibility_is_one_fact_source_for_runtime_and_named_root(self):
        """Catches a kind/admission pair accepted by runtime but absent from RecordShapeV1."""
        compatibility = getattr(self.tool, "SOURCE_ADMISSION_KIND_COMPATIBILITY", None)
        self.assertIsNotNone(compatibility, "declarative SOURCE admission compatibility is missing")
        self.validate()

        source = base_row(self.tool, "SOURCE")
        source.update(
            subjectID="QRS-222222222222222222222222",
            requirementID="QRS-222222222222222222222222",
            childID="QSC-444444444444444444444444",
            bindingOrdinal="1",
            sourceID="SOURCE-ONE",
            sourceKind="repositoryCommitted",
            sourcePath="docs/source.md",
            sourceLocator="REQ-1",
            sourceRevision="v1",
            sourceCommit="b" * 40,
            sourceTree="c" * 40,
            sourceBlob="d" * 40,
            sourceByteLength="42",
            sourceSHA256="e" * 64,
            admissionState="userDecisionOnly",
            sourceBindingCommitment="f" * 64,
            rowCommitment="0" * 64,
        )
        with self.assertRaises(self.tool.LedgerError):
            self.tool.validate_row_shape(source)

        mutated = {
            admission: frozenset(kinds)
            for admission, kinds in compatibility.items()
        }
        mutated["userDecisionOnly"] = mutated["userDecisionOnly"] | {"repositoryCommitted"}
        self.tool.SOURCE_ADMISSION_KIND_COMPATIBILITY = mutated
        try:
            self.tool.validate_row_shape(source)
            with self.assertRaises(self.tool.LedgerError):
                self.validate()
        finally:
            self.tool.SOURCE_ADMISSION_KIND_COMPATIBILITY = compatibility

    def test_target_presence_rules_are_one_fact_source_for_runtime_and_named_root(self):
        """Catches Wave/class or selector pairing rules drifting from RecordShapeV1."""
        rules = getattr(self.tool, "TARGET_PRESENCE_RULES", None)
        self.assertIsNotNone(rules, "declarative TARGET presence rules are missing")
        self.validate()

        target = base_row(self.tool, "TARGET")
        target.update(
            subjectID="QRS-222222222222222222222222",
            requirementID="QRS-222222222222222222222222",
            childID="QTG-555555555555555555555555",
            executionState="nonExecutable",
            targetOrdinal="1",
            governedOwner="K3",
            governedWave="W1",
            nonProductionClass="-",
            selectorPath="Sources/K3.swift",
            selectorID="K3.owner",
            pendingGateID="A0",
            targetCommitment="1" * 64,
            rowCommitment="2" * 64,
        )
        candidates = {
            "waveOrNonProductionClass": dict(target, nonProductionClass="R0"),
            "selectorPair": dict(target, selectorID="-"),
        }
        for rule_name, candidate in candidates.items():
            with self.subTest(rule=rule_name):
                with self.assertRaises(self.tool.LedgerError):
                    self.tool.validate_row_shape(candidate)
                mutated = {
                    name: {
                        "operator": rule["operator"],
                        "fields": tuple(rule["fields"]),
                    }
                    for name, rule in rules.items()
                    if name != rule_name
                }
                self.tool.TARGET_PRESENCE_RULES = mutated
                try:
                    self.tool.validate_row_shape(candidate)
                    with self.assertRaises(self.tool.LedgerError):
                        self.validate()
                finally:
                    self.tool.TARGET_PRESENCE_RULES = rules

    def test_governed_wave_set_is_one_fact_source_for_shape_fold_placeholder_and_root(self):
        """Catches W0-W6 drifting independently across TARGET validation paths."""
        waves = getattr(self.tool, "GOVERNED_WAVES", None)
        self.assertEqual(waves, frozenset(f"W{i}" for i in range(7)))
        self.validate()

        target_row = base_row(self.tool, "TARGET")
        target_row.update(
            subjectID="QRS-222222222222222222222222",
            requirementID="QRS-222222222222222222222222",
            childID="QTG-555555555555555555555555",
            executionState="sourceGoverned",
            targetOrdinal="1",
            governedOwner="K3",
            governedWave="W1",
            nonProductionClass="-",
            selectorPath="Sources/K3.swift",
            selectorID="K3.owner",
            pendingGateID="-",
            targetCommitment="1" * 64,
            rowCommitment="2" * 64,
        )
        governed_requirement = {
            "disposition": "projectionOfControlledRequirement",
            "executionState": "sourceGoverned",
        }
        governed_sources = [{"admissionState": "admittedControlled"}]
        governed_targets = [
            {
                "executionState": "sourceGoverned",
                "governedOwner": "K3",
                "governedWave": "W1",
                "nonProductionClass": "-",
                "selectorPath": "Sources/K3.swift",
                "selectorID": "K3.owner",
                "pendingGateID": "-",
            }
        ]
        pending_requirement = {
            "disposition": "newControlDeltaPendingAdmission",
            "executionState": "nonExecutable",
        }
        pending_sources = [{"admissionState": "pendingA0"}]
        pending_targets = [
            {
                "executionState": "nonExecutable",
                "governedOwner": "K3",
                "governedWave": "W1",
                "nonProductionClass": "-",
                "selectorPath": "-",
                "selectorID": "-",
                "pendingGateID": "A0.selector",
            }
        ]
        self.tool.validate_row_shape(target_row)
        self.tool.validate_requirement_state(
            governed_requirement, governed_sources, governed_targets
        )
        self.tool.validate_requirement_state(
            pending_requirement, pending_sources, pending_targets
        )

        self.tool.GOVERNED_WAVES = waves - {"W1"}
        try:
            with self.assertRaises(self.tool.LedgerError):
                self.tool.validate_row_shape(target_row)
            with self.assertRaises(self.tool.LedgerError):
                self.tool.validate_requirement_state(
                    governed_requirement, governed_sources, governed_targets
                )
            with self.assertRaises(self.tool.LedgerError):
                self.tool.validate_requirement_state(
                    pending_requirement, pending_sources, pending_targets
                )
            with self.assertRaises(self.tool.LedgerError):
                self.validate()
        finally:
            self.tool.GOVERNED_WAVES = waves

    def test_scan_identity_matrix_is_one_fact_source_for_runtime_and_named_root(self):
        """Catches an exact scan tuple changing without invalidating RecordShapeV1."""
        rules = getattr(self.tool, "SCAN_IDENTITY_RULES", None)
        self.assertIsNotNone(rules, "declarative exact scan identity matrix is missing")
        self.validate()
        scan = ScanIdentityTests().scan_row(
            self.tool,
            "1",
            "deep",
            "bcffa52e-53cf-4407-b216-14288ae07061",
            "c8f80486895e12e26d567e610c35a6e2141b3489",
            "complete",
            "canonicalUnavailable",
        )
        self.tool.validate_row_shape(scan)

        mutated = {
            number: dict(values)
            for number, values in rules.items()
        }
        mutated["1"]["admissionState"] = "notStarted"
        self.tool.SCAN_IDENTITY_RULES = mutated
        try:
            self.tool.validate_row_shape(dict(scan, admissionState="notStarted"))
            with self.assertRaises(self.tool.LedgerError):
                self.validate()
        finally:
            self.tool.SCAN_IDENTITY_RULES = rules

    def test_identifier_languages_are_one_fact_source_for_runtime_and_named_root(self):
        """Catches executable ID regexes drifting outside the RecordShapeV1 root."""
        languages = getattr(self.tool, "IDENTIFIER_LANGUAGES", None)
        expected_names = frozenset({
            "unitID",
            "requirementID",
            "CLAUSE.childID",
            "SOURCE.childID",
            "TARGET.childID",
            "sourceID",
            "mappingID",
        })
        self.assertIsNotNone(languages, "declarative identifier-language registry is missing")
        self.assertEqual(frozenset(languages), expected_names)
        self.validate()

        source = base_row(self.tool, "SOURCE")
        source.update(
            subjectID="QRS-222222222222222222222222",
            requirementID="QRS-222222222222222222222222",
            childID="QSC-444444444444444444444444",
            bindingOrdinal="1",
            sourceID="source-one",
            sourceKind="repositoryCommitted",
            sourcePath="docs/source.md",
            sourceLocator="REQ-1",
            sourceRevision="v1",
            sourceCommit="b" * 40,
            sourceTree="c" * 40,
            sourceBlob="d" * 40,
            sourceByteLength="42",
            sourceSHA256="e" * 64,
            admissionState="admittedControlled",
            sourceBindingCommitment="f" * 64,
            rowCommitment="0" * 64,
        )
        target = base_row(self.tool, "TARGET")
        target.update(
            subjectID="QRS-222222222222222222222222",
            requirementID="QRS-222222222222222222222222",
            childID="QTG-555555555555555555555555",
            executionState="nonExecutable",
            targetOrdinal="1",
            governedOwner="owner with spaces",
            governedWave="W1",
            nonProductionClass="-",
            selectorPath="Sources/K3.swift",
            selectorID="K3.owner",
            pendingGateID="A0",
            targetCommitment="1" * 64,
            rowCommitment="2" * 64,
        )
        runtime_mutations = (
            ("sourceID", source, re.compile(languages["sourceID"].pattern, re.IGNORECASE)),
            ("mappingID", target, re.compile(r"^.+$")),
        )
        for language_name, candidate, widened in runtime_mutations:
            with self.subTest(language=language_name, consumer="runtime"):
                with self.assertRaises(self.tool.LedgerError):
                    self.tool.validate_row_shape(candidate)
                original = languages[language_name]
                languages[language_name] = widened
                try:
                    self.tool.validate_row_shape(candidate)
                    with self.assertRaises(self.tool.LedgerError):
                        self.validate()
                finally:
                    languages[language_name] = original

        for language_name in sorted(expected_names - {"sourceID", "mappingID"}):
            with self.subTest(language=language_name, consumer="named-root"):
                original = languages[language_name]
                languages[language_name] = re.compile(r"^.*$")
                try:
                    with self.assertRaises(self.tool.LedgerError):
                        self.validate()
                finally:
                    languages[language_name] = original

    def test_scalar_languages_are_one_fact_source_for_runtime_and_named_root(self):
        """Catches scalar syntax or bounds being widened outside RecordShapeV1."""
        rules = getattr(self.tool, "RECORD_SCALAR_RULES", None)
        self.assertIsNotNone(rules, "declarative scalar-language registry is missing")
        self.assertEqual(
            frozenset(rules),
            frozenset({"schemaVersion", "canonicalUInt64", "lowerHex64", "gitObjectHex"}),
        )
        self.validate()

        unit = base_row(self.tool, "UNIT")
        unit.update(
            subjectID=unit["unitID"],
            sourceBindingCount="0",
            sourceBindingRoot="1" * 64,
            rowCommitment="2" * 64,
        )
        cases = (
            (
                "schemaVersion",
                dict(unit, schemaVersion="2"),
                {"kind": "literal", "value": "2"},
            ),
            (
                "canonicalUInt64",
                dict(unit, specByteLength="0100"),
                {
                    "kind": "boundedRegex",
                    "language": re.compile(r"^[0-9]+$"),
                    "maximum": "18446744073709551615",
                },
            ),
            (
                "lowerHex64",
                dict(unit, specSHA256="B" * 64),
                {
                    "kind": "regex",
                    "language": re.compile(r"^[0-9a-f]{64}$", re.IGNORECASE),
                },
            ),
            (
                "gitObjectHex",
                dict(unit, specBlob="a" * 65),
                {
                    "kind": "regex",
                    "language": re.compile(r"^[0-9a-f]{40,65}$"),
                },
            ),
        )
        for rule_name, candidate, widened in cases:
            with self.subTest(rule=rule_name):
                with self.assertRaises(self.tool.LedgerError):
                    self.tool.validate_row_shape(candidate)
                original = rules[rule_name]
                rules[rule_name] = widened
                try:
                    self.tool.validate_row_shape(candidate)
                    with self.assertRaises(self.tool.LedgerError):
                        self.validate()
                finally:
                    rules[rule_name] = original

        malformed_blob_rule = rules["gitObjectHex"]
        rules["gitObjectHex"] = {
            "kind": "regex",
            "language": re.compile(r"^.+$"),
        }
        try:
            self.tool.validate_row_shape(dict(unit, specBlob="not-a-git-object"))
            with self.assertRaises(self.tool.LedgerError):
                self.validate()
        finally:
            rules["gitObjectHex"] = malformed_blob_rule

        with self.assertRaises(self.tool.LedgerError):
            self.tool._canonical_uint("9" * 5000, "adversarialCount")

        missing_hex_rule = rules.pop("lowerHex64")
        try:
            with self.assertRaises(self.tool.LedgerError):
                self.tool.child_set_root(b"test-set/v1\0", [])
        finally:
            rules["lowerHex64"] = missing_hex_rule

    def test_scalar_field_mapping_is_closed_for_runtime_and_named_root(self):
        """Catches field language, nullability, or positivity escaping RecordShapeV1."""
        mappings = getattr(self.tool, "RECORD_SCALAR_FIELD_RULES", None)
        self.assertIsNotNone(mappings, "declarative scalar field mapping is missing")
        self.validate()

        unit = base_row(self.tool, "UNIT")
        unit.update(
            subjectID=unit["unitID"],
            sourceBindingCount="0",
            sourceBindingRoot="1" * 64,
            rowCommitment="2" * 64,
        )
        original = mappings["specByteLength"]
        mappings["specByteLength"] = dict(original, scalarRule="lowerHex64")
        try:
            self.tool.validate_row_shape(dict(unit, specByteLength="a" * 64))
            with self.assertRaises(self.tool.LedgerError):
                self.validate()
        finally:
            mappings["specByteLength"] = original

        clause = base_row(self.tool, "CLAUSE")
        clause.update(
            subjectID="QRS-222222222222222222222222",
            requirementID="QRS-222222222222222222222222",
            childID="QCL-333333333333333333333333",
            clauseOrdinal="0",
            clauseRole="assertion",
            clauseStartByte="1",
            clauseEndByteExclusive="9",
            clauseSHA256="3" * 64,
            clauseCommitment="4" * 64,
            rowCommitment="5" * 64,
        )
        with self.assertRaises(self.tool.LedgerError):
            self.tool.validate_row_shape(clause)
        ordinal_rule = mappings["clauseOrdinal"]
        mappings["clauseOrdinal"] = dict(ordinal_rule, positiveRecords=frozenset())
        try:
            self.tool.validate_row_shape(clause)
            self.assertEqual(self.tool.sort_rows([clause]), [clause])
            with self.assertRaises(self.tool.LedgerError):
                self.validate()
        finally:
            mappings["clauseOrdinal"] = ordinal_rule

        removed = mappings.pop("sourceByteLength")
        try:
            with self.assertRaises(self.tool.LedgerError):
                self.validate()
        finally:
            mappings["sourceByteLength"] = removed

        mappings["notAHeaderField"] = {
            "scalarRule": "canonicalUInt64",
            "nullable": True,
            "positiveRecords": frozenset(),
        }
        try:
            with self.assertRaises(self.tool.LedgerError):
                self.validate()
        finally:
            del mappings["notAHeaderField"]

    def test_identifier_field_mapping_is_closed_for_runtime_and_named_root(self):
        mappings = getattr(self.tool, "IDENTIFIER_FIELD_RULES", None)
        self.assertIsNotNone(mappings, "declarative identifier field mapping is missing")
        self.validate()
        target = base_row(self.tool, "TARGET")
        target.update(
            subjectID="QRS-222222222222222222222222",
            requirementID="QRS-222222222222222222222222",
            childID="QTG-555555555555555555555555",
            executionState="nonExecutable",
            targetOrdinal="1",
            governedOwner="owner.one",
            governedWave="W1",
            pendingGateID="gate with spaces",
            targetCommitment="1" * 64,
            rowCommitment="2" * 64,
        )
        with self.assertRaises(self.tool.LedgerError):
            self.tool.validate_row_shape(target)
        removed = mappings.pop("pendingGateID")
        try:
            self.tool.validate_row_shape(target)
            with self.assertRaises(self.tool.LedgerError):
                self.validate()
        finally:
            mappings["pendingGateID"] = removed

        original = mappings["governedOwner"]
        mappings["governedOwner"] = dict(original, identifierLanguage="sourceID")
        try:
            with self.assertRaises(self.tool.LedgerError):
                self.tool.validate_row_shape(dict(target, pendingGateID="-"))
            with self.assertRaises(self.tool.LedgerError):
                self.validate()
        finally:
            mappings["governedOwner"] = original

        child_rule = mappings["TARGET.childID"]
        mappings["TARGET.childID"] = dict(child_rule, applicableRecords=frozenset())
        try:
            self.tool.validate_row_shape(dict(target, childID="invalid", pendingGateID="-"))
            with self.assertRaises(self.tool.LedgerError):
                self.validate()
        finally:
            mappings["TARGET.childID"] = child_rule

        mappings["notAHeaderID"] = dict(original)
        try:
            with self.assertRaises(self.tool.LedgerError):
                self.validate()
        finally:
            del mappings["notAHeaderID"]

    def test_enum_fields_and_unit_class_capabilities_are_declarative(self):
        capabilities = getattr(self.tool, "UNIT_CLASS_RULES", None)
        self.assertIsNotNone(capabilities, "UNIT class capability rules are missing")
        self.validate()
        unit = base_row(self.tool, "UNIT")
        unit.update(
            subjectID=unit["unitID"],
            unitClass="evidence",
            sourceBindingCount="0",
            sourceBindingRoot="1" * 64,
            rowCommitment="2" * 64,
        )
        with self.assertRaises(self.tool.LedgerError):
            self.tool.validate_row_shape(unit)
        original = capabilities["evidence"]
        capabilities["evidence"] = dict(original, requiresDirectSources=False)
        try:
            self.tool.validate_row_shape(unit)
            with self.assertRaises(self.tool.LedgerError):
                self.validate()
        finally:
            capabilities["evidence"] = original

        enum_values = self.tool.RECORD_SHAPE_ENUMS.pop("clauseRole")
        try:
            with self.assertRaises(self.tool.LedgerError):
                self.validate()
        finally:
            self.tool.RECORD_SHAPE_ENUMS["clauseRole"] = enum_values

    def test_child_record_topology_is_one_fact_source(self):
        rules = getattr(self.tool, "CHILD_RECORD_RULES", None)
        self.assertIsNotNone(rules, "child record topology registry is missing")
        self.validate()
        target = base_row(self.tool, "TARGET")
        target.update(targetOrdinal="1")
        self.assertEqual(self.tool._selected_ordinal(target), 1)
        original = rules["TARGET"]
        rules["TARGET"] = dict(original, ordinalField="bindingOrdinal")
        try:
            with self.assertRaises(self.tool.LedgerError):
                self.tool._selected_ordinal(target)
            with self.assertRaises(self.tool.LedgerError):
                self.validate()
        finally:
            rules["TARGET"] = original

        removed = rules.pop("CLAUSE")
        try:
            with self.assertRaises(self.tool.LedgerError):
                self.validate()
        finally:
            rules["CLAUSE"] = removed
        rules["EXTRA"] = dict(original)
        try:
            with self.assertRaises(self.tool.LedgerError):
                self.validate()
        finally:
            del rules["EXTRA"]

    def test_identifier_pairs_and_child_topology_are_structurally_closed(self):
        identifier_rules = self.tool.IDENTIFIER_FIELD_RULES
        duplicate = dict(identifier_rules["pendingGateID"])
        identifier_rules["duplicatePendingGate"] = duplicate
        try:
            with self.assertRaises(self.tool.LedgerError):
                self.tool._record_shape_condition_payloads()
        finally:
            del identifier_rules["duplicatePendingGate"]

        child_rules = self.tool.CHILD_RECORD_RULES
        original = child_rules["CLAUSE"]
        mutations = (
            dict(original, parentCountField="targetBindingCount"),
            dict(original, commitmentPreimageFields=original["commitmentPreimageFields"][:-1]),
            dict(original, childIDPrefix="BAD-"),
            dict(original, rank=child_rules["SOURCE"]["rank"]),
        )
        for mutation in mutations:
            child_rules["CLAUSE"] = mutation
            try:
                with self.assertRaises(self.tool.LedgerError):
                    self.tool._record_shape_condition_payloads()
            finally:
                child_rules["CLAUSE"] = original

    def test_base_enums_are_one_fact_source_for_runtime_and_named_root(self):
        """Catches base record enums being widened without changing RecordShapeV1."""
        enums = getattr(self.tool, "RECORD_SHAPE_ENUMS", None)
        expected_fields = frozenset({"unitClass", "anchorKind", "executionState", "clauseRole"})
        self.assertIsNotNone(enums, "declarative base-enum registry is missing")
        self.assertEqual(frozenset(enums), expected_fields)
        self.validate()

        unit_class = base_row(self.tool, "UNIT")
        unit_class.update(
            subjectID=unit_class["unitID"],
            unitClass="futureClass",
            sourceBindingCount="0",
            sourceBindingRoot="1" * 64,
            rowCommitment="2" * 64,
        )
        anchor_kind = dict(
            unit_class,
            unitClass="normativeBearing",
            anchorKind="futureAnchor",
            anchorLocator="qinao-unit-locator/v1:qhp1:00000000:futureAnchor:1",
        )
        execution_state = base_row(self.tool, "REQUIREMENT")
        execution_state.update(
            subjectID="QRS-222222222222222222222222",
            requirementID="QRS-222222222222222222222222",
            requirementSemanticSHA256="3" * 64,
            disposition="projectionOfControlledRequirement",
            executionState="futureState",
            clauseCount="1",
            clauseRoot="4" * 64,
            sourceBindingCount="1",
            sourceBindingRoot="5" * 64,
            targetBindingCount="1",
            targetBindingRoot="6" * 64,
            rowCommitment="7" * 64,
        )
        clause_role = base_row(self.tool, "CLAUSE")
        clause_role.update(
            subjectID="QRS-222222222222222222222222",
            requirementID="QRS-222222222222222222222222",
            childID="QCL-333333333333333333333333",
            clauseOrdinal="1",
            clauseRole="futureRole",
            clauseStartByte="1",
            clauseEndByteExclusive="9",
            clauseSHA256="8" * 64,
            clauseCommitment="9" * 64,
            rowCommitment="a" * 64,
        )
        cases = (
            ("unitClass", "futureClass", unit_class),
            ("anchorKind", "futureAnchor", anchor_kind),
            ("executionState", "futureState", execution_state),
            ("clauseRole", "futureRole", clause_role),
        )
        for field, widened_value, candidate in cases:
            with self.subTest(field=field):
                with self.assertRaises(self.tool.LedgerError):
                    self.tool.validate_row_shape(candidate)
                original = enums[field]
                enums[field] = frozenset(original) | {widened_value}
                added_capability = False
                if field == "unitClass":
                    self.tool.UNIT_CLASS_RULES[widened_value] = dict(
                        self.tool.UNIT_CLASS_RULES["normativeBearing"]
                    )
                    added_capability = True
                try:
                    self.tool.validate_row_shape(candidate)
                    with self.assertRaises(self.tool.LedgerError):
                        self.validate()
                finally:
                    if added_capability:
                        del self.tool.UNIT_CLASS_RULES[widened_value]
                    enums[field] = original

    def test_record_shape_structured_payload_is_injective_for_delimiter_atoms(self):
        """Catches multiple atoms collapsing into one delimiter-bearing atom."""
        self.validate()
        clause_roles = self.tool.RECORD_SHAPE_ENUMS["clauseRole"]
        self.tool.RECORD_SHAPE_ENUMS["clauseRole"] = frozenset({
            "assertion,sharedContext",
        })
        try:
            with self.assertRaises(self.tool.LedgerError):
                self.validate()
        finally:
            self.tool.RECORD_SHAPE_ENUMS["clauseRole"] = clause_roles

        waves = self.tool.GOVERNED_WAVES
        self.tool.GOVERNED_WAVES = frozenset({
            "W0,W1", "W2", "W3", "W4", "W5", "W6",
        })
        try:
            with self.assertRaises(self.tool.LedgerError):
                self.validate()
        finally:
            self.tool.GOVERNED_WAVES = waves

    def test_disposition_source_rules_are_one_fact_source_for_runtime_enum_and_named_root(self):
        """Catches disposition admission logic or its enum escaping RecordShapeV1."""
        rules = getattr(self.tool, "DISPOSITION_SOURCE_RULES", None)
        self.assertIsNotNone(rules, "declarative disposition/SOURCE rules are missing")
        self.validate()

        requirement = {
            "disposition": "forensicRiskInput",
            "executionState": "nonExecutable",
        }
        sources = [{"admissionState": "operationalEvidenceOnly"}]
        with self.assertRaises(self.tool.LedgerError):
            self.tool.validate_disposition_source_compatibility(requirement, sources)

        original_rules = rules
        widened = {
            disposition: {
                "requiredAny": frozenset(rule["requiredAny"]),
                "allowed": frozenset(rule["allowed"]),
                "executionStateEquals": rule["executionStateEquals"],
            }
            for disposition, rule in rules.items()
        }
        widened["forensicRiskInput"]["requiredAny"] |= {"operationalEvidenceOnly"}
        widened["forensicRiskInput"]["allowed"] |= {"operationalEvidenceOnly"}
        self.tool.DISPOSITION_SOURCE_RULES = widened
        try:
            self.tool.validate_disposition_source_compatibility(requirement, sources)
            with self.assertRaises(self.tool.LedgerError):
                self.validate()
        finally:
            self.tool.DISPOSITION_SOURCE_RULES = original_rules

        future = {
            disposition: {
                "requiredAny": frozenset(rule["requiredAny"]),
                "allowed": frozenset(rule["allowed"]),
                "executionStateEquals": rule["executionStateEquals"],
            }
            for disposition, rule in rules.items()
        }
        future["futureDisposition"] = {
            "requiredAny": frozenset({"forensicEvidenceOnly"}),
            "allowed": frozenset({"forensicEvidenceOnly"}),
            "executionStateEquals": "nonExecutable",
        }
        future_row = base_row(self.tool, "REQUIREMENT")
        future_row.update(
            subjectID="QRS-222222222222222222222222",
            requirementID="QRS-222222222222222222222222",
            requirementSemanticSHA256="3" * 64,
            disposition="futureDisposition",
            executionState="nonExecutable",
            clauseCount="1",
            clauseRoot="4" * 64,
            sourceBindingCount="1",
            sourceBindingRoot="5" * 64,
            targetBindingCount="1",
            targetBindingRoot="6" * 64,
            rowCommitment="7" * 64,
        )
        self.tool.DISPOSITION_SOURCE_RULES = future
        try:
            self.tool.validate_row_shape(future_row)
            self.tool.validate_disposition_source_compatibility(
                {"disposition": "futureDisposition", "executionState": "nonExecutable"},
                [{"admissionState": "forensicEvidenceOnly"}],
            )
            with self.assertRaises(self.tool.LedgerError):
                self.validate()
        finally:
            self.tool.DISPOSITION_SOURCE_RULES = original_rules

    def test_named_contract_registry_does_not_change_scan_numbering(self):
        """Catches named-contract validation accidentally renumbering Deep or Standard scans."""
        self.validate()
        valid = [
            {
                "admissionState": "externalObservedOnly",
                "scanNumber": "1",
                "scanKind": "deep",
                "scanID": "bcffa52e-53cf-4407-b216-14288ae07061",
                "scanTargetRevision": "c8f80486895e12e26d567e610c35a6e2141b3489",
                "scanOfficialState": "complete",
                "canonicalArtifactState": "canonicalUnavailable",
            },
            {
                "admissionState": "externalObservedOnly",
                "scanNumber": "2",
                "scanKind": "deep",
                "scanID": "3d22f697-0c9d-4dbb-8c6a-871a9cfbcca9",
                "scanTargetRevision": "243c083f345f3586ef226020d42af4653b31a62a",
                "scanOfficialState": "failed",
                "canonicalArtifactState": "canonicalUnavailable",
            },
        ]
        for row in valid:
            self.tool.validate_scan_source(row)
        with self.assertRaises(self.tool.LedgerError):
            self.tool.validate_scan_source(dict(valid[1], scanOfficialState="complete"))


class OfficialLedgerIntegrationTests(unittest.TestCase):
    def test_official_ledger_and_permanent_manifests_close_final_identity(self):
        """Catches installing a stale ledger or losing either final audit layer."""
        expected_tool_path = (
            EVIDENCE_DIR / "2026-08-28-qinao-source-disposition-ledger-v1.py"
        )
        self.assertEqual(TOOL_PATH, expected_tool_path)
        self.assertFalse(TOOL_PATH.is_symlink())
        self.assertTrue(stat.S_ISREG(TOOL_PATH.stat().st_mode))
        verifier_data = read_regular_bytes(TOOL_PATH)
        verifier_sha = hashlib.sha256(verifier_data).hexdigest()
        verifier_blob = hashlib.sha1(
            f"blob {len(verifier_data)}\0".encode("ascii") + verifier_data
        ).hexdigest()
        self.assertEqual(len(verifier_data), 128454)
        self.assertEqual(
            verifier_sha,
            "96ab8a3bdb9d7b87a8554ca6e83125ad7985a9936b49d558dbce2c8f578a21a7",
        )
        self.assertEqual(verifier_blob, "5a5100a367b6061c195e45040a77ae48cb222a5e")

        tool = load_tool_from_bytes(verifier_data)
        ledger_data = read_regular_bytes(LEDGER_PATH)
        report = tool.verify_tsv(
            SPEC_PATH.read_bytes(),
            ledger_data,
            "docs/superpowers/specs/"
            "2026-08-28-qinao-recovery-spine-and-deep-scan-closure-design.md",
        )
        expected = {
            "fileSHA256": "08927cf99433267ee5a1e602dfb3ae225cf6393426aa53c5188839c917228cb1",
            "rowRoot": "bfd2c4c5807008510299514fae32d1a1edf8154f0fbb874adba00b1d1e87a461",
            "dataRowCount": 10293,
            "unitCount": 325,
            "requirementCount": 1127,
            "namedContractRoot": "585e14ab6e320f55d4fa768ac7c3f7044eb81581410c17218007a2814ac2daee",
            "unitClassSetRoot": "3129b6e700aa67202d46688384d04d95ea0fb8cf43f5e9e0c8392a1a9eec1c70",
            "requirementSemanticSetRoot": "93e3fe0dec5c8837643b2b838773f921ea2a06ecde307438b6cdec24a40d2a23",
            "provenanceMappingRoot": "402ea7a7e903aa2054c4fcb16fb66b3b22ee1804f8165e5e1b31607e3a577d5e",
        }
        self.assertEqual(
            {field: report[field] for field in expected},
            expected,
        )
        verifier_sources = {
            (
                row["sourcePath"],
                row["sourceLocator"],
                row["sourceKind"],
                row["sourceBlob"],
                row["sourceByteLength"],
                row["sourceSHA256"],
                row["admissionState"],
            )
            for row in parse_tsv(ledger_data)
            if row["recordType"] == "SOURCE" and row["sourceID"] == "VERIFIER28"
        }
        self.assertEqual(
            verifier_sources,
            {
                (
                    "docs/superpowers/evidence/"
                    "2026-08-28-qinao-source-disposition-ledger-v1.py",
                    "bytes:0-128454",
                    "repositoryPrecommit",
                    verifier_blob,
                    str(len(verifier_data)),
                    verifier_sha,
                    "uncommittedReviewOnly",
                )
            },
        )
        semantic_data = read_regular_bytes(SEMANTIC_MANIFEST_PATH)
        mapping_data = read_regular_bytes(MAPPING_MANIFEST_PATH)
        self.assertEqual(
            hashlib.sha256(semantic_data).hexdigest(),
            "ec2d42d5871efc50b780d1d1a75ccb5afff40518100b903d746c4e4ec259d3fc",
        )
        self.assertEqual(
            hashlib.sha256(mapping_data).hexdigest(),
            "66bbe9246cff6ee338234cd4a91610b9ef6212faf9cb39297cc74739e51dc548",
        )
        self.assertEqual(len(parse_tsv(semantic_data)), 195)
        self.assertEqual(len(parse_tsv(mapping_data)), 125)

    def test_semantic_only_replacements_keep_declared_final_bindings(self):
        """Catches the 166 semantic-only rows drifting behind aggregate roots."""
        ledger_data = read_regular_bytes(LEDGER_PATH)
        semantic_data = read_regular_bytes(SEMANTIC_MANIFEST_PATH)
        mapping_data = read_regular_bytes(MAPPING_MANIFEST_PATH)
        self.assertEqual(
            hashlib.sha256(ledger_data).hexdigest(),
            "08927cf99433267ee5a1e602dfb3ae225cf6393426aa53c5188839c917228cb1",
        )
        self.assertEqual(
            hashlib.sha256(semantic_data).hexdigest(),
            "ec2d42d5871efc50b780d1d1a75ccb5afff40518100b903d746c4e4ec259d3fc",
        )
        self.assertEqual(
            hashlib.sha256(mapping_data).hexdigest(),
            "66bbe9246cff6ee338234cd4a91610b9ef6212faf9cb39297cc74739e51dc548",
        )
        ledger_rows = parse_tsv(ledger_data)
        semantic_rows = parse_tsv(semantic_data)
        mapping_rows = parse_tsv(mapping_data)
        mapping_requirement_ids = {row["requirementID"] for row in mapping_rows}
        semantic_only = [
            row
            for row in semantic_rows
            if row["replacementRequirementID"] not in mapping_requirement_ids
        ]
        self.assertEqual(len(semantic_only), 166)

        requirements = {
            row["requirementID"]: row
            for row in ledger_rows
            if row["recordType"] == "REQUIREMENT"
        }
        sources: dict[str, list[dict[str, str]]] = {}
        targets: dict[str, list[dict[str, str]]] = {}
        for row in ledger_rows:
            requirement_id = row["requirementID"]
            if row["recordType"] == "SOURCE" and requirement_id != "-":
                sources.setdefault(requirement_id, []).append(row)
            elif row["recordType"] == "TARGET":
                targets.setdefault(requirement_id, []).append(row)

        target_fields = (
            "governedOwner",
            "governedWave",
            "nonProductionClass",
            "selectorPath",
            "selectorID",
            "pendingGateID",
            "executionState",
        )
        for manifest_row in semantic_only:
            requirement_id = manifest_row["replacementRequirementID"]
            with self.subTest(requirementID=requirement_id):
                requirement = requirements[requirement_id]
                self.assertEqual(
                    requirement["disposition"], manifest_row["disposition"]
                )
                self.assertEqual(requirement["executionState"], "nonExecutable")
                actual_sources = [
                    row["sourceID"]
                    for row in sorted(
                        sources[requirement_id],
                        key=lambda row: int(row["bindingOrdinal"]),
                    )
                ]
                self.assertEqual(
                    actual_sources,
                    manifest_row["sourceIDs"].split("|"),
                )
                actual_source_class = "|".join(
                    f"{row['sourceID']}:{row['sourceKind']}:{row['admissionState']}"
                    for row in sorted(
                        sources[requirement_id],
                        key=lambda row: int(row["bindingOrdinal"]),
                    )
                )
                self.assertEqual(
                    actual_source_class,
                    manifest_row["sourceClass"],
                )
                actual_targets = [
                    tuple(row[field] for field in target_fields)
                    for row in sorted(
                        targets[requirement_id],
                        key=lambda row: int(row["targetOrdinal"]),
                    )
                ]
                expected_targets = [
                    tuple(item.split("@"))
                    for item in manifest_row["targetTuple"].split("|")
                ]
                self.assertEqual(actual_targets, expected_targets)

        self.assertEqual(len(mapping_rows), 125)
        for manifest_row in mapping_rows:
            requirement_id = manifest_row["requirementID"]
            with self.subTest(mappingRequirementID=requirement_id):
                requirement = requirements[requirement_id]
                self.assertEqual(
                    requirement["disposition"], manifest_row["disposition"]
                )
                self.assertEqual(
                    requirement["executionState"], manifest_row["executionState"]
                )
                actual_sources = [
                    row["sourceID"]
                    for row in sorted(
                        sources[requirement_id],
                        key=lambda row: int(row["bindingOrdinal"]),
                    )
                ]
                self.assertEqual(
                    actual_sources,
                    manifest_row["sourceIDs"].split("|"),
                )
                actual_source_class = "|".join(
                    f"{row['sourceID']}:{row['sourceKind']}:{row['admissionState']}"
                    for row in sorted(
                        sources[requirement_id],
                        key=lambda row: int(row["bindingOrdinal"]),
                    )
                )
                self.assertEqual(
                    actual_source_class,
                    manifest_row["sourceClass"],
                )
                actual_targets = [
                    tuple(row[field] for field in target_fields)
                    for row in sorted(
                        targets[requirement_id],
                        key=lambda row: int(row["targetOrdinal"]),
                    )
                ]
                expected_targets = [
                    tuple(item.split("@"))
                    for item in manifest_row["targetTuple"].split("|")
                ]
                self.assertEqual(actual_targets, expected_targets)


class CLITests(unittest.TestCase):
    def test_extract_cli_reports_real_units_as_json(self):
        """Catches a CLI that reports counts without exposing extracted unit identities."""
        with tempfile.TemporaryDirectory() as directory:
            spec_path = Path(directory) / "spec.md"
            spec_path.write_bytes(b"# H\nOne.\n\n- Two.\n")
            result = subprocess.run(
                [sys.executable, str(TOOL_PATH), "extract", str(spec_path)],
                text=True,
                capture_output=True,
                check=False,
            )
        self.assertEqual(result.returncode, 0, result.stderr)
        payload = json.loads(result.stdout)
        self.assertEqual(payload["unitCount"], 2)
        self.assertEqual([unit["anchorKind"] for unit in payload["units"]], ["prose", "listLeader"])

    def test_verify_cli_fails_closed_on_malformed_tsv(self):
        """Catches accepting unknown headers, CRLF, or incomplete rows."""
        with tempfile.TemporaryDirectory() as directory:
            spec_path = Path(directory) / "spec.md"
            ledger_path = Path(directory) / "ledger.tsv"
            spec_path.write_bytes(b"# H\nOne.\n")
            ledger_path.write_bytes(b"wrong\theader\r\n")
            result = subprocess.run(
                [sys.executable, str(TOOL_PATH), "verify", str(spec_path), str(ledger_path)],
                text=True,
                capture_output=True,
                check=False,
            )
        self.assertEqual(result.returncode, 2)
        self.assertIn("error", result.stderr.lower())

    def test_verify_cli_rejects_even_canonical_foreign_ledgers(self):
        """Catches using the official acceptance entrypoint as a generic fixture verifier."""
        tool = load_tool()
        spec_data = b"# H\nEvidence.\n"
        spec_identity = "fixture.md"
        unit = tool.extract_markdown_units(spec_data, spec_identity)[0]
        shared = {
            "schemaVersion": "1",
            "unitID": unit["unitID"],
            "unitClass": "evidence",
            "anchorKind": unit["anchorKind"],
            "specPath": spec_identity,
            "specBlob": tool._git_blob(spec_data),
            "specByteLength": str(len(spec_data)),
            "specLineCount": str(len(spec_data.splitlines())),
            "specSHA256": __import__("hashlib").sha256(spec_data).hexdigest(),
            "headingPath": unit["headingPath"],
            "anchorLocator": unit["anchorLocator"],
            "unitStartByte": str(unit["startByte"]),
            "unitEndByteExclusive": str(unit["endByteExclusive"]),
            "unitStartLine": str(unit["startLine"]),
            "unitEndLine": str(unit["endLine"]),
            "unitSpanSHA256": unit["spanSHA256"],
            "unitSemanticSHA256": unit["semanticSHA256"],
        }
        source = {name: "-" for name in tool.HEADER}
        source.update(
            shared,
            recordType="SOURCE",
            subjectID=unit["unitID"],
            requirementID="-",
            bindingOrdinal="1",
            sourceID="EVIDENCE-ONE",
            sourceKind="externalFrozen",
            sourceLocator="fixture:source:1",
            sourceRevision="fixture-v1",
            sourceByteLength="7",
            sourceSHA256=__import__("hashlib").sha256(b"source\n").hexdigest(),
            admissionState="externalObservedOnly",
        )
        source["sourceBindingCommitment"] = tool.source_binding_commitment(source)
        source["childID"] = "QSC-" + source["sourceBindingCommitment"][:24]
        source["rowCommitment"] = tool.row_commitment(source)

        unit_row = {name: "-" for name in tool.HEADER}
        unit_row.update(
            shared,
            recordType="UNIT",
            subjectID=unit["unitID"],
            sourceBindingCount="1",
            sourceBindingRoot=tool.child_set_root(
                tool.SOURCE_SET_DOMAIN,
                [source["sourceBindingCommitment"]],
            ),
        )
        unit_row["rowCommitment"] = tool.row_commitment(unit_row)
        rows = tool.sort_rows([unit_row, source])
        ledger_data = (
            "\t".join(tool.HEADER)
            + "\n"
            + "".join("\t".join(row[field] for field in tool.HEADER) + "\n" for row in rows)
        ).encode("utf-8")

        with tempfile.TemporaryDirectory() as directory:
            spec_path = Path(directory) / "spec.md"
            ledger_path = Path(directory) / "ledger.tsv"
            spec_path.write_bytes(spec_data)
            ledger_path.write_bytes(ledger_data)
            result = subprocess.run(
                [
                    sys.executable,
                    str(TOOL_PATH),
                    "verify",
                    str(spec_path),
                    str(ledger_path),
                    "--spec-path",
                    spec_identity,
                ],
                text=True,
                capture_output=True,
                check=False,
            )

        self.assertEqual(result.returncode, 2)
        self.assertIn("purpose-bound", result.stderr)


if __name__ == "__main__":
    unittest.main()
