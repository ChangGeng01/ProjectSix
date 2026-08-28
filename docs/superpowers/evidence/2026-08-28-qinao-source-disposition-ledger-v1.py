#!/usr/bin/env python3
"""Closed, non-shipping Project06 source-disposition ledger verifier v1."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import struct
import sys
import unicodedata
from collections import Counter, defaultdict
from pathlib import Path
from typing import Iterable, NamedTuple, Sequence


class LedgerError(ValueError):
    """Raised when frozen Markdown or ledger data is not canonical."""


NULL = "-"
SPEC_REL = "docs/superpowers/specs/2026-08-28-qinao-recovery-spine-and-deep-scan-closure-design.md"
VERIFIER_REL = "docs/superpowers/evidence/2026-08-28-qinao-source-disposition-ledger-v1.py"
HEADER = (
    "schemaVersion", "recordType", "subjectID", "unitID", "requirementID",
    "childID", "unitClass", "anchorKind", "specPath", "specBlob",
    "specByteLength", "specLineCount", "specSHA256", "headingPath",
    "anchorLocator", "unitStartByte", "unitEndByteExclusive", "unitStartLine",
    "unitEndLine", "unitSpanSHA256", "unitSemanticSHA256",
    "requirementSemanticSHA256", "disposition", "executionState", "clauseCount",
    "clauseRoot", "sourceBindingCount", "sourceBindingRoot", "targetBindingCount",
    "targetBindingRoot", "bindingOrdinal", "clauseOrdinal", "clauseRole",
    "clauseStartByte", "clauseEndByteExclusive", "clauseSHA256",
    "clauseCommitment", "sourceID", "sourceKind", "sourcePath", "sourceLocator",
    "sourceRevision", "sourceCommit", "sourceTree", "sourceBlob",
    "sourceByteLength", "sourceSHA256", "admissionState", "scanNumber",
    "scanKind", "scanID", "scanTargetRevision", "scanOfficialState",
    "canonicalArtifactState", "targetOrdinal", "governedOwner", "governedWave",
    "nonProductionClass", "selectorPath", "selectorID", "pendingGateID",
    "targetCommitment", "sourceBindingCommitment", "rowCommitment",
)

RECORD_RANK = {"UNIT": 0, "REQUIREMENT": 1, "CLAUSE": 2, "SOURCE": 3, "TARGET": 4}
AUTHORITY_ADMISSION_STATES = (
    "admittedControlled", "pendingA0", "pendingProtectedIntake", "uncommittedReviewOnly",
)
RECORD_SHAPE_ENUMS = {
    "unitClass": frozenset({"normativeBearing", "evidence", "introductory", "mixed"}),
    "anchorKind": frozenset({"prose", "listLeader", "fencedCode", "table"}),
    "executionState": frozenset({"sourceGoverned", "nonExecutable"}),
    "clauseRole": frozenset({"assertion", "sharedContext"}),
}
UNIT_CLASS_RULES = {
    "normativeBearing": {
        "requiresDirectSources": False,
        "allowsDirectSources": False,
        "allowsRequirements": True,
        "requiresRequirements": True,
    },
    "evidence": {
        "requiresDirectSources": True,
        "allowsDirectSources": True,
        "allowsRequirements": False,
        "requiresRequirements": False,
    },
    "introductory": {
        "requiresDirectSources": True,
        "allowsDirectSources": True,
        "allowsRequirements": False,
        "requiresRequirements": False,
    },
    "mixed": {
        "requiresDirectSources": True,
        "allowsDirectSources": True,
        "allowsRequirements": True,
        "requiresRequirements": True,
    },
}

CLAUSE_DOMAIN = b"qinao-source-disposition-clause/v1\0"
SOURCE_DOMAIN = b"qinao-source-disposition-source/v1\0"
TARGET_DOMAIN = b"qinao-source-disposition-target/v1\0"
CLAUSE_SET_DOMAIN = b"qinao-source-disposition-clause-set/v1\0"
SOURCE_SET_DOMAIN = b"qinao-source-disposition-source-set/v1\0"
TARGET_SET_DOMAIN = b"qinao-source-disposition-target-set/v1\0"
ROW_DOMAIN = b"qinao-source-disposition-row/v1\0"
LEDGER_DOMAIN = b"qinao-source-disposition-ledger/v1\0"
UNIT_SEMANTIC_DOMAIN = b"qinao-design-unit-semantic/v1\0"
UNIT_CLASS_MEMBER_DOMAIN = b"qinao-unit-class-member/v1\0"
UNIT_CLASS_SET_DOMAIN = b"qinao-unit-class-set/v1\0"
REQUIREMENT_SEMANTIC_MEMBER_DOMAIN = b"qinao-requirement-semantic-member/v1\0"
REQUIREMENT_SEMANTIC_SET_DOMAIN = b"qinao-requirement-semantic-set/v1\0"
PROVENANCE_UNIT_MEMBER_DOMAIN = b"qinao-provenance-mapping-unit-member/v1\0"
PROVENANCE_REQUIREMENT_MEMBER_DOMAIN = b"qinao-provenance-mapping-requirement-member/v1\0"
PROVENANCE_MAPPING_SET_DOMAIN = b"qinao-provenance-mapping-set/v1\0"
PROVENANCE_SOURCE_PROJECTION_FIELDS = (
    "sourceID", "sourceKind", "sourcePath", "admissionState", "scanNumber",
    "scanKind", "scanID", "scanTargetRevision", "scanOfficialState",
    "canonicalArtifactState",
)
PROVENANCE_TARGET_PROJECTION_FIELDS = (
    "governedOwner", "governedWave", "nonProductionClass", "selectorPath",
    "selectorID", "executionState", "pendingGateID",
)


class _SourceProjection(NamedTuple):
    sourceID: str
    sourceKind: str
    sourcePath: str
    admissionState: str
    scanNumber: str
    scanKind: str
    scanID: str
    scanTargetRevision: str
    scanOfficialState: str
    canonicalArtifactState: str


class _TargetProjection(NamedTuple):
    governedOwner: str
    governedWave: str
    nonProductionClass: str
    selectorPath: str
    selectorID: str
    executionState: str
    pendingGateID: str


class _ValidatedUnitProjection(NamedTuple):
    unitID: str
    unitClass: str
    unitSemanticSHA256: str
    sources: tuple[_SourceProjection, ...]


class _ValidatedRequirementProjection(NamedTuple):
    requirementID: str
    unitID: str
    requirementSemanticSHA256: str
    disposition: str
    executionState: str
    sources: tuple[_SourceProjection, ...]
    targets: tuple[_TargetProjection, ...]


class _ValidatedProjectionIndex(NamedTuple):
    units: tuple[_ValidatedUnitProjection, ...]
    requirements: tuple[_ValidatedRequirementProjection, ...]

FROZEN_SPEC_IDENTITY = {
    "specSHA256": "d2c7f8954d8559e8277a184035da1e76acf378475e630e4aadfa4b86268fa21b",
    "specBlob": "84346d35c8f366dca792f0c2e9fdbfb5161dc584",
    "specByteLength": 92869,
    "specLineCount": 1556,
}

CLAUSE_FIELDS = (
    "schemaVersion", "requirementID", "clauseOrdinal", "clauseRole",
    "clauseStartByte", "clauseEndByteExclusive", "clauseSHA256",
)
SOURCE_FIELDS = (
    "schemaVersion", "subjectID", "bindingOrdinal", "sourceID", "sourceKind",
    "sourcePath", "sourceLocator", "sourceRevision", "sourceCommit", "sourceTree",
    "sourceBlob", "sourceByteLength", "sourceSHA256", "admissionState",
    "scanNumber", "scanKind", "scanID", "scanTargetRevision", "scanOfficialState",
    "canonicalArtifactState",
)
TARGET_FIELDS = (
    "schemaVersion", "requirementID", "targetOrdinal", "governedOwner",
    "governedWave", "nonProductionClass", "selectorPath", "selectorID",
    "executionState", "pendingGateID",
)

SHARED_FIELDS = {
    "schemaVersion", "recordType", "subjectID", "unitID", "unitClass",
    "anchorKind", "specPath", "specBlob", "specByteLength", "specLineCount",
    "specSHA256", "headingPath", "anchorLocator", "unitStartByte",
    "unitEndByteExclusive", "unitStartLine", "unitEndLine", "unitSpanSHA256",
    "unitSemanticSHA256", "rowCommitment",
}
def _record_shape(
    required_extra: Iterable[str],
    conditional_extra: Iterable[str] = (),
) -> dict[str, frozenset[str]]:
    required = frozenset(SHARED_FIELDS | set(required_extra))
    return {
        "required": required,
        "allowed": frozenset(required | set(conditional_extra)),
    }


# RecordShapeV1's sole executable required/allowed-field declaration.  All
# generic and record-specific validation below consumes this matrix instead of
# restating a second base-required field set.
RECORD_SHAPES = {
    "UNIT": _record_shape({"sourceBindingCount", "sourceBindingRoot"}),
    "REQUIREMENT": _record_shape({
        "requirementID", "requirementSemanticSHA256", "disposition", "executionState",
        "clauseCount", "clauseRoot", "sourceBindingCount", "sourceBindingRoot",
        "targetBindingCount", "targetBindingRoot",
    }),
    "CLAUSE": _record_shape({
        "requirementID", "childID", "clauseOrdinal", "clauseRole",
        "clauseStartByte", "clauseEndByteExclusive", "clauseSHA256",
        "clauseCommitment",
    }),
    "SOURCE": _record_shape(
        {
            "childID", "bindingOrdinal", "sourceID", "sourceKind", "sourceLocator",
            "sourceRevision", "admissionState", "sourceBindingCommitment",
        },
        {
            "requirementID", "sourcePath", "sourceCommit", "sourceTree", "sourceBlob",
            "sourceByteLength", "sourceSHA256", "scanNumber", "scanKind", "scanID",
            "scanTargetRevision", "scanOfficialState", "canonicalArtifactState",
        },
    ),
    "TARGET": _record_shape(
        {
            "requirementID", "childID", "executionState", "targetOrdinal",
            "governedOwner", "targetCommitment",
        },
        {
            "governedWave", "nonProductionClass", "selectorPath", "selectorID",
            "pendingGateID",
        },
    ),
}

SCAN_SOURCE_FIELDS = frozenset({
    "scanNumber", "scanKind", "scanID", "scanTargetRevision",
    "scanOfficialState", "canonicalArtifactState",
})
SOURCE_FILE_IDENTITY_FIELDS = frozenset({
    "sourcePath", "sourceCommit", "sourceTree", "sourceBlob",
    "sourceByteLength", "sourceSHA256",
})

# RecordShapeV1's single declarative source for SOURCE-kind presence and exact
# value conditions. Runtime validation and the named-contract commitment both
# consume these objects.
SOURCE_KIND_FIELD_RULES = {
    "repositoryCommitted": {
        "required": frozenset({
            "sourcePath", "sourceCommit", "sourceTree", "sourceBlob",
            "sourceByteLength", "sourceSHA256",
        }),
        "forbidden": SCAN_SOURCE_FIELDS,
        "equals": {},
    },
    "repositoryPrecommit": {
        "required": frozenset({
            "sourcePath", "sourceBlob", "sourceByteLength", "sourceSHA256",
        }),
        "forbidden": frozenset({"sourceCommit", "sourceTree"}) | SCAN_SOURCE_FIELDS,
        "equals": {},
    },
    "externalFrozen": {
        "required": frozenset({"sourceByteLength", "sourceSHA256"}),
        "forbidden": frozenset({"sourceCommit", "sourceTree", "sourceBlob"}) | SCAN_SOURCE_FIELDS,
        "equals": {},
    },
    "scanRecord": {
        "required": frozenset(),
        "forbidden": SOURCE_FILE_IDENTITY_FIELDS,
        "equals": {},
    },
    "decisionReceipt": {
        "required": frozenset({
            "sourcePath", "sourceBlob", "sourceByteLength", "sourceSHA256",
        }),
        "forbidden": frozenset({"sourceCommit", "sourceTree"}) | SCAN_SOURCE_FIELDS,
        "equals": {},
    },
}

# Exact, closed admissionState -> sourceKind compatibility relation.
SOURCE_ADMISSION_KIND_COMPATIBILITY = {
    "admittedControlled": frozenset({"repositoryCommitted"}),
    "uncommittedReviewOnly": frozenset({"repositoryPrecommit"}),
    "pendingA0": frozenset({"repositoryCommitted", "repositoryPrecommit"}),
    "pendingProtectedIntake": frozenset({"repositoryCommitted", "repositoryPrecommit"}),
    "forensicEvidenceOnly": frozenset({
        "repositoryCommitted", "repositoryPrecommit", "externalFrozen",
    }),
    "operationalEvidenceOnly": frozenset({
        "repositoryCommitted", "repositoryPrecommit", "externalFrozen",
    }),
    "externalObservedOnly": frozenset({"externalFrozen", "scanRecord"}),
    "userDecisionOnly": frozenset({"decisionReceipt"}),
    "notStarted": frozenset({"scanRecord"}),
}

AUTHORITY_SET_REFERENCE = "@AuthoritySetV1"
DISPOSITION_SOURCE_RULES = {
    "projectionOfControlledRequirement": {
        "requiredAny": frozenset({AUTHORITY_SET_REFERENCE}),
        "allowed": frozenset({
            AUTHORITY_SET_REFERENCE, "forensicEvidenceOnly", "operationalEvidenceOnly",
            "externalObservedOnly", "userDecisionOnly",
        }),
        "executionStateEquals": None,
    },
    "forensicRiskInput": {
        "requiredAny": frozenset({"forensicEvidenceOnly", "externalObservedOnly"}),
        "allowed": frozenset({
            "forensicEvidenceOnly", "externalObservedOnly", "userDecisionOnly",
        }),
        "executionStateEquals": "nonExecutable",
    },
    "operationalScanGate": {
        "requiredAny": frozenset({
            "operationalEvidenceOnly", "externalObservedOnly", "notStarted",
        }),
        "allowed": frozenset({
            "operationalEvidenceOnly", "externalObservedOnly", "notStarted",
            "userDecisionOnly",
        }),
        "executionStateEquals": "nonExecutable",
    },
    "newControlDeltaPendingAdmission": {
        "requiredAny": frozenset({
            "pendingA0", "pendingProtectedIntake", "uncommittedReviewOnly",
        }),
        "allowed": frozenset({
            "pendingA0", "pendingProtectedIntake", "uncommittedReviewOnly",
            "userDecisionOnly",
        }),
        "executionStateEquals": "nonExecutable",
    },
}

# Closed cross-field presence operators for TARGET rows.
TARGET_PRESENCE_RULES = {
    "waveOrNonProductionClass": {
        "operator": "exactlyOne",
        "fields": ("governedWave", "nonProductionClass"),
    },
    "selectorPair": {
        "operator": "allOrNone",
        "fields": ("selectorPath", "selectorID"),
    },
}
GOVERNED_WAVES = frozenset(f"W{i}" for i in range(7))

SCAN_IDENTITY_FIELDS = (
    "admissionState", "scanKind", "scanID", "scanTargetRevision",
    "scanOfficialState", "canonicalArtifactState",
)
SCAN_IDENTITY_RULES = {
    "1": {
        "admissionState": "externalObservedOnly",
        "scanKind": "deep",
        "scanID": "bcffa52e-53cf-4407-b216-14288ae07061",
        "scanTargetRevision": "c8f80486895e12e26d567e610c35a6e2141b3489",
        "scanOfficialState": "complete",
        "canonicalArtifactState": "canonicalUnavailable",
    },
    "2": {
        "admissionState": "externalObservedOnly",
        "scanKind": "deep",
        "scanID": "3d22f697-0c9d-4dbb-8c6a-871a9cfbcca9",
        "scanTargetRevision": "243c083f345f3586ef226020d42af4653b31a62a",
        "scanOfficialState": "failed",
        "canonicalArtifactState": "canonicalUnavailable",
    },
    "3": {
        "admissionState": "notStarted",
        "scanKind": "deep",
        "scanID": NULL,
        "scanTargetRevision": "pendingD0Freeze",
        "scanOfficialState": "notStarted",
        "canonicalArtifactState": "canonicalPending",
    },
    NULL: {
        "admissionState": "externalObservedOnly",
        "scanKind": "standard",
        "scanID": "dd2acd18-3ead-44fa-9c10-f8fd8c911aa7",
        "scanTargetRevision": "unknownFrozen",
        "scanOfficialState": "unknownFrozen",
        "canonicalArtifactState": "unknownFrozen",
    },
}

LIST_RE = re.compile(br"^([ \t]*)([-+*]|[0-9]{1,9}[.)])[ \t]+")
ASCII_WHITESPACE_RE = re.compile(r"[\x09-\x0d\x20]+")
HEADING_RE = re.compile(br"^(#{1,6})[ \t]+(.*?)(?:\n)?$")
FENCE_RE = re.compile(br"^( {0,3})(`{3,}|~{3,})(.*?)(?:\n)?$")
RECORD_SCALAR_RULES = {
    "schemaVersion": {
        "kind": "literal",
        "value": "1",
    },
    "canonicalUInt64": {
        "kind": "boundedRegex",
        "language": re.compile(r"^(?:0|[1-9][0-9]*)$"),
        "maximum": "18446744073709551615",
    },
    "lowerHex64": {
        "kind": "regex",
        "language": re.compile(r"^[0-9a-f]{64}$"),
    },
    "gitObjectHex": {
        "kind": "regex",
        "language": re.compile(r"^[0-9a-f]{40}(?:[0-9a-f]{24})?$"),
    },
}


def _scalar_field_rule(
    scalar_rule: str,
    *,
    nullable: bool = True,
    positive_records: Iterable[str] = (),
) -> dict[str, object]:
    return {
        "scalarRule": scalar_rule,
        "nullable": nullable,
        "positiveRecords": frozenset(positive_records),
    }


# RecordShapeV1's sole field-to-scalar-language declaration.  Required/allowed
# presence remains owned by RECORD_SHAPES; this registry owns value syntax,
# conditional nullability, and record-specific strictly-positive semantics.
RECORD_SCALAR_FIELD_RULES = {
    "schemaVersion": _scalar_field_rule("schemaVersion", nullable=False),
    "specBlob": _scalar_field_rule("gitObjectHex"),
    "specByteLength": _scalar_field_rule("canonicalUInt64"),
    "specLineCount": _scalar_field_rule("canonicalUInt64"),
    "specSHA256": _scalar_field_rule("lowerHex64"),
    "unitStartByte": _scalar_field_rule("canonicalUInt64"),
    "unitEndByteExclusive": _scalar_field_rule("canonicalUInt64"),
    "unitStartLine": _scalar_field_rule("canonicalUInt64"),
    "unitEndLine": _scalar_field_rule("canonicalUInt64"),
    "unitSpanSHA256": _scalar_field_rule("lowerHex64"),
    "unitSemanticSHA256": _scalar_field_rule("lowerHex64"),
    "rowCommitment": _scalar_field_rule("lowerHex64"),
    "requirementSemanticSHA256": _scalar_field_rule("lowerHex64"),
    "clauseCount": _scalar_field_rule("canonicalUInt64", positive_records={"REQUIREMENT"}),
    "clauseRoot": _scalar_field_rule("lowerHex64"),
    "sourceBindingCount": _scalar_field_rule(
        "canonicalUInt64", positive_records={"REQUIREMENT"}
    ),
    "sourceBindingRoot": _scalar_field_rule("lowerHex64"),
    "targetBindingCount": _scalar_field_rule(
        "canonicalUInt64", positive_records={"REQUIREMENT"}
    ),
    "targetBindingRoot": _scalar_field_rule("lowerHex64"),
    "bindingOrdinal": _scalar_field_rule("canonicalUInt64", positive_records={"SOURCE"}),
    "clauseOrdinal": _scalar_field_rule("canonicalUInt64", positive_records={"CLAUSE"}),
    "clauseStartByte": _scalar_field_rule("canonicalUInt64"),
    "clauseEndByteExclusive": _scalar_field_rule("canonicalUInt64"),
    "clauseSHA256": _scalar_field_rule("lowerHex64"),
    "clauseCommitment": _scalar_field_rule("lowerHex64"),
    "sourceCommit": _scalar_field_rule("gitObjectHex", nullable=True),
    "sourceTree": _scalar_field_rule("gitObjectHex", nullable=True),
    "sourceBlob": _scalar_field_rule("gitObjectHex", nullable=True),
    "sourceByteLength": _scalar_field_rule("canonicalUInt64", nullable=True),
    "sourceSHA256": _scalar_field_rule("lowerHex64", nullable=True),
    "targetOrdinal": _scalar_field_rule("canonicalUInt64", positive_records={"TARGET"}),
    "targetCommitment": _scalar_field_rule("lowerHex64"),
    "sourceBindingCommitment": _scalar_field_rule("lowerHex64"),
    "anchorLocator.ordinal": _scalar_field_rule(
        "canonicalUInt64", nullable=False, positive_records=frozenset(RECORD_RANK)
    ),
}
CHILD_RECORD_RULES = {
    "CLAUSE": {
        "rank": RECORD_RANK["CLAUSE"], "ordinalField": "clauseOrdinal",
        "commitmentField": "clauseCommitment", "parentCountField": "clauseCount",
        "parentRootField": "clauseRoot", "setDomain": CLAUSE_SET_DOMAIN,
        "commitmentDomain": CLAUSE_DOMAIN, "commitmentPreimageFields": CLAUSE_FIELDS,
        "childIDLanguage": "CLAUSE.childID", "childIDPrefix": "QCL-",
        "parentRecords": frozenset({"REQUIREMENT"}),
    },
    "SOURCE": {
        "rank": RECORD_RANK["SOURCE"], "ordinalField": "bindingOrdinal",
        "commitmentField": "sourceBindingCommitment", "parentCountField": "sourceBindingCount",
        "parentRootField": "sourceBindingRoot", "setDomain": SOURCE_SET_DOMAIN,
        "commitmentDomain": SOURCE_DOMAIN, "commitmentPreimageFields": SOURCE_FIELDS,
        "childIDLanguage": "SOURCE.childID", "childIDPrefix": "QSC-",
        "parentRecords": frozenset({"UNIT", "REQUIREMENT"}),
    },
    "TARGET": {
        "rank": RECORD_RANK["TARGET"], "ordinalField": "targetOrdinal",
        "commitmentField": "targetCommitment", "parentCountField": "targetBindingCount",
        "parentRootField": "targetBindingRoot", "setDomain": TARGET_SET_DOMAIN,
        "commitmentDomain": TARGET_DOMAIN, "commitmentPreimageFields": TARGET_FIELDS,
        "childIDLanguage": "TARGET.childID", "childIDPrefix": "QTG-",
        "parentRecords": frozenset({"REQUIREMENT"}),
    },
}
IDENTIFIER_LANGUAGES = {
    "unitID": re.compile(r"^QUN-[0-9a-f]{24}$"),
    "requirementID": re.compile(r"^QRS-[0-9a-f]{24}$"),
    "CLAUSE.childID": re.compile(r"^QCL-[0-9a-f]{24}$"),
    "SOURCE.childID": re.compile(r"^QSC-[0-9a-f]{24}$"),
    "TARGET.childID": re.compile(r"^QTG-[0-9a-f]{24}$"),
    "sourceID": re.compile(r"^[A-Z][A-Z0-9-]{0,63}$"),
    "mappingID": re.compile(r"^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$"),
}
IDENTIFIER_FIELD_RULES = {
    "unitID": {
        "field": "unitID", "identifierLanguage": "unitID",
        "applicableRecords": frozenset(RECORD_RANK), "nullable": "recordShape",
    },
    "requirementID": {
        "field": "requirementID", "identifierLanguage": "requirementID",
        "applicableRecords": frozenset({"REQUIREMENT", "CLAUSE", "SOURCE", "TARGET"}),
        "nullable": "recordShape",
    },
    "CLAUSE.childID": {
        "field": "childID", "identifierLanguage": "@childRecord",
        "applicableRecords": frozenset({"CLAUSE"}), "nullable": "recordShape",
    },
    "SOURCE.childID": {
        "field": "childID", "identifierLanguage": "@childRecord",
        "applicableRecords": frozenset({"SOURCE"}), "nullable": "recordShape",
    },
    "TARGET.childID": {
        "field": "childID", "identifierLanguage": "@childRecord",
        "applicableRecords": frozenset({"TARGET"}), "nullable": "recordShape",
    },
    "sourceID": {
        "field": "sourceID", "identifierLanguage": "sourceID",
        "applicableRecords": frozenset({"SOURCE"}), "nullable": "recordShape",
    },
    "governedOwner": {
        "field": "governedOwner", "identifierLanguage": "mappingID",
        "applicableRecords": frozenset({"TARGET"}), "nullable": "recordShape",
    },
    "selectorID": {
        "field": "selectorID", "identifierLanguage": "mappingID",
        "applicableRecords": frozenset({"TARGET"}), "nullable": "recordShape",
    },
    "pendingGateID": {
        "field": "pendingGateID", "identifierLanguage": "mappingID",
        "applicableRecords": frozenset({"TARGET"}), "nullable": "recordShape",
    },
    "nonProductionClass": {
        "field": "nonProductionClass", "identifierLanguage": "mappingID",
        "applicableRecords": frozenset({"TARGET"}), "nullable": "recordShape",
    },
}
EXPECTED_IDENTIFIER_FIELD_PAIRS = frozenset({
    *((record_type, "unitID") for record_type in RECORD_RANK),
    *((record_type, "requirementID") for record_type in ("REQUIREMENT", "CLAUSE", "SOURCE", "TARGET")),
    ("CLAUSE", "childID"), ("SOURCE", "childID"), ("TARGET", "childID"),
    ("SOURCE", "sourceID"),
    ("TARGET", "governedOwner"), ("TARGET", "selectorID"),
    ("TARGET", "pendingGateID"), ("TARGET", "nonProductionClass"),
})
SOURCE_KINDS = frozenset(SOURCE_KIND_FIELD_RULES)
ADMISSION_STATES = frozenset(SOURCE_ADMISSION_KIND_COMPATIBILITY)


def _lp_bytes(value: str) -> bytes:
    encoded = value.encode("utf-8")
    return struct.pack(">Q", len(encoded)) + encoded


def typed_commitment(domain: bytes, fields: Sequence[str]) -> str:
    return hashlib.sha256(domain + b"".join(_lp_bytes(field) for field in fields)).hexdigest()


def _canonical_named_node(value: object) -> list[object]:
    if value is None:
        return ["null"]
    if isinstance(value, bool):
        return ["bool", value]
    if isinstance(value, int):
        return ["int", str(value)]
    if isinstance(value, str):
        return ["str", value]
    if isinstance(value, tuple):
        nodes = [_canonical_named_node(item) for item in value]
        return ["tuple", len(nodes), nodes]
    if isinstance(value, list):
        nodes = [_canonical_named_node(item) for item in value]
        return ["list", len(nodes), nodes]
    if isinstance(value, (set, frozenset)):
        nodes = [_canonical_named_node(item) for item in value]
        nodes.sort(key=lambda node: json.dumps(node, ensure_ascii=False, separators=(",", ":")))
        return ["set", len(nodes), nodes]
    if isinstance(value, dict):
        entries = [
            [_canonical_named_node(key), _canonical_named_node(item)]
            for key, item in value.items()
        ]
        entries.sort(
            key=lambda entry: json.dumps(
                entry[0], ensure_ascii=False, separators=(",", ":")
            )
        )
        return ["map", len(entries), entries]
    raise LedgerError(f"unsupported canonical named-payload type: {type(value).__name__}")


def canonical_named_value(tag: str, value: object) -> str:
    if not isinstance(tag, str) or tag == "":
        raise LedgerError("canonical named-payload tag must be a nonempty string")
    return json.dumps(
        ["qinao-named-structured/v1", _canonical_named_node(tag), _canonical_named_node(value)],
        ensure_ascii=False,
        separators=(",", ":"),
    )


def _scalar_regex(rule_name: str, expected_kind: str) -> re.Pattern[str]:
    rule = RECORD_SCALAR_RULES.get(rule_name)
    if not isinstance(rule, dict) or rule.get("kind") != expected_kind:
        raise LedgerError(f"{rule_name} scalar rule is unavailable")
    language = rule.get("language")
    if not isinstance(language, re.Pattern) or not isinstance(language.pattern, str):
        raise LedgerError(f"{rule_name} scalar language is unavailable")
    return language


def child_set_root(domain: bytes, commitments: Sequence[str]) -> str:
    raw = []
    commitment_language = _scalar_regex("lowerHex64", "regex")
    for commitment in commitments:
        if not commitment_language.fullmatch(commitment):
            raise LedgerError(f"invalid child commitment: {commitment!r}")
        raw.append(bytes.fromhex(commitment))
    return hashlib.sha256(domain + struct.pack(">Q", len(raw)) + b"".join(raw)).hexdigest()


def _heading_path(stack: Sequence[tuple[int, str]]) -> str:
    payload = bytearray(struct.pack(">I", len(stack)))
    for level, text in stack:
        payload.append(level)
        payload.extend(_lp_bytes(text))
    return "qhp1:" + payload.hex()


def _line_parts(data: bytes) -> list[tuple[int, int, bytes]]:
    parts: list[tuple[int, int, bytes]] = []
    start = 0
    for line in data.splitlines(keepends=True):
        end = start + len(line)
        parts.append((start, end, line))
        start = end
    if start < len(data):
        parts.append((start, len(data), data[start:]))
    return parts


def _is_blank(line: bytes) -> bool:
    return not line.rstrip(b"\n").strip(b" \t")


def _parse_heading(line: bytes) -> tuple[int, str] | None:
    match = HEADING_RE.fullmatch(line)
    if not match:
        return None
    body = match.group(2)
    trailing = re.fullmatch(br"(.*?)[ \t]+#+[ \t]*", body)
    if trailing:
        body = trailing.group(1)
    try:
        text = unicodedata.normalize("NFC", body.decode("utf-8"))
    except UnicodeDecodeError as error:
        raise LedgerError("heading is not UTF-8") from error
    return len(match.group(1)), text


def _fence_opener(line: bytes) -> tuple[int, int] | None:
    match = FENCE_RE.fullmatch(line)
    if not match:
        return None
    marker = match.group(2)
    return marker[0], len(marker)


def _is_fence_closer(line: bytes, marker: int, minimum: int) -> bool:
    body = line.rstrip(b"\n")
    match = re.fullmatch(b" {0,3}(" + re.escape(bytes([marker])) + b"{" + str(minimum).encode() + b",})[ \t]*", body)
    return bool(match)


def _has_unescaped_pipe(line: bytes) -> bool:
    escaped = False
    for byte in line.rstrip(b"\n"):
        if byte == 0x5C:
            escaped = not escaped
        else:
            if byte == 0x7C and not escaped:
                return True
            escaped = False
    return False


def _split_unescaped_pipes(line: bytes) -> list[bytes]:
    body = line.rstrip(b"\n")
    cells: list[bytearray] = [bytearray()]
    escaped = False
    for byte in body:
        if byte == 0x5C and not escaped:
            escaped = True
            cells[-1].append(byte)
            continue
        if byte == 0x7C and not escaped:
            cells.append(bytearray())
        else:
            cells[-1].append(byte)
        escaped = False
    if body.startswith(b"|"):
        cells = cells[1:]
    if body.endswith(b"|"):
        cells = cells[:-1]
    return [bytes(cell).strip(b" \t") for cell in cells]


def _is_table_delimiter(line: bytes) -> bool:
    if not _has_unescaped_pipe(line):
        return False
    cells = _split_unescaped_pipes(line)
    return bool(cells) and all(re.fullmatch(br":?-{3,}:?", cell) for cell in cells)


def _normalize_unit(span: bytes, kind: str) -> str:
    try:
        text_bytes = span
        if kind == "listLeader":
            match = LIST_RE.match(text_bytes)
            if not match:
                raise LedgerError("list unit lost its leader")
            text_bytes = text_bytes[match.end():]
        text = unicodedata.normalize("NFC", text_bytes.decode("utf-8"))
    except UnicodeDecodeError as error:
        raise LedgerError("unit is not UTF-8") from error
    return ASCII_WHITESPACE_RE.sub(" ", text).strip(" ")


def extract_markdown_units(data: bytes, spec_path: str) -> list[dict[str, object]]:
    if data.startswith(b"\xef\xbb\xbf"):
        raise LedgerError("BOM is forbidden")
    if b"\r" in data:
        raise LedgerError("only LF line endings are accepted")
    if b"\x00" in data:
        raise LedgerError("NUL is forbidden")
    try:
        data.decode("utf-8")
    except UnicodeDecodeError as error:
        raise LedgerError("specification is not UTF-8") from error

    lines = _line_parts(data)
    heading_stack: list[tuple[int, str]] = []
    raw_units: list[tuple[str, str, int, int, int, int]] = []
    i = 0
    list_indents: list[int] = []
    after_blank = False

    while i < len(lines):
        start, end, line = lines[i]
        if _is_blank(line):
            after_blank = True
            i += 1
            continue

        heading = _parse_heading(line)
        if heading is not None:
            level, text = heading
            heading_stack = [item for item in heading_stack if item[0] < level]
            heading_stack.append((level, text))
            list_indents = []
            after_blank = False
            i += 1
            continue

        path = _heading_path(heading_stack)
        opener = _fence_opener(line)
        if opener is not None:
            structural_indent = len(line) - len(line.lstrip(b" \t"))
            while list_indents and structural_indent <= list_indents[-1]:
                list_indents.pop()
            marker, minimum = opener
            j = i + 1
            while j < len(lines) and not _is_fence_closer(lines[j][2], marker, minimum):
                j += 1
            if j == len(lines):
                raise LedgerError(f"unterminated fence at line {i + 1}")
            raw_units.append(("fencedCode", path, start, lines[j][1], i + 1, j + 1))
            after_blank = False
            i = j + 1
            continue

        if i + 1 < len(lines) and _has_unescaped_pipe(line) and _is_table_delimiter(lines[i + 1][2]):
            structural_indent = len(line) - len(line.lstrip(b" \t"))
            while list_indents and structural_indent <= list_indents[-1]:
                list_indents.pop()
            j = i + 2
            while j < len(lines) and not _is_blank(lines[j][2]) and _has_unescaped_pipe(lines[j][2]):
                if _parse_heading(lines[j][2]) or _fence_opener(lines[j][2]) or LIST_RE.match(lines[j][2]):
                    raise LedgerError(f"ambiguous table continuation at line {j + 1}")
                j += 1
            raw_units.append(("table", path, start, lines[j - 1][1], i + 1, j))
            after_blank = False
            i = j
            continue

        leader = LIST_RE.match(line)
        if leader:
            indent = len(leader.group(1))
            while list_indents and indent < list_indents[-1]:
                list_indents.pop()
            if list_indents and indent > list_indents[-1]:
                list_indents.append(indent)
            elif list_indents and indent != list_indents[-1]:
                raise LedgerError(f"ambiguous list indentation at line {i + 1}")
            elif not list_indents:
                list_indents.append(indent)
            j = i + 1
            while j < len(lines):
                candidate = lines[j][2]
                if _is_blank(candidate) or _parse_heading(candidate) or _fence_opener(candidate):
                    break
                if LIST_RE.match(candidate):
                    break
                if j + 1 < len(lines) and _has_unescaped_pipe(candidate) and _is_table_delimiter(lines[j + 1][2]):
                    break
                continuation_indent = len(candidate) - len(candidate.lstrip(b" \t"))
                if continuation_indent <= indent:
                    raise LedgerError(f"ambiguous list continuation at line {j + 1}")
                j += 1
            raw_units.append(("listLeader", path, start, lines[j - 1][1], i + 1, j))
            after_blank = False
            i = j
            continue

        leading = len(line) - len(line.lstrip(b" \t"))
        if leading:
            if after_blank:
                while list_indents and leading <= list_indents[-1]:
                    list_indents.pop()
            if not list_indents or leading <= list_indents[-1]:
                raise LedgerError(f"unowned indented bytes at line {i + 1}")
        else:
            list_indents = []
        j = i + 1
        while j < len(lines):
            candidate = lines[j][2]
            if _is_blank(candidate) or _parse_heading(candidate) or _fence_opener(candidate) or LIST_RE.match(candidate):
                break
            if j + 1 < len(lines) and _has_unescaped_pipe(candidate) and _is_table_delimiter(lines[j + 1][2]):
                break
            j += 1
        raw_units.append(("prose", path, start, lines[j - 1][1], i + 1, j))
        after_blank = False
        i = j

    ordinals: Counter[tuple[str, str]] = Counter()
    seen_ids: set[str] = set()
    units: list[dict[str, object]] = []
    for kind, path, start, end, start_line, end_line in raw_units:
        span = data[start:end]
        normalized = _normalize_unit(span, kind)
        semantic = typed_commitment(UNIT_SEMANTIC_DOMAIN, [path, kind, normalized])
        unit_id = "QUN-" + semantic[:24]
        if unit_id in seen_ids:
            raise LedgerError(f"indistinguishable unit collision: {unit_id}")
        seen_ids.add(unit_id)
        ordinals[(path, kind)] += 1
        locator = f"qinao-unit-locator/v1:{path}:{kind}:{ordinals[(path, kind)]}"
        units.append(
            {
                "unitID": unit_id,
                "anchorKind": kind,
                "headingPath": path,
                "anchorLocator": locator,
                "startByte": start,
                "endByteExclusive": end,
                "startLine": start_line,
                "endLine": end_line,
                "spanSHA256": hashlib.sha256(span).hexdigest(),
                "semanticSHA256": semantic,
                "normalizedText": normalized,
            }
        )
    return units


class NamedUnitIdentity(NamedTuple):
    unit_id: str
    start_line: int
    anchor_kind: str
    heading_path: str
    semantic_sha256: str


class NamedContractOccurrence(NamedTuple):
    unit_id: str
    start_line: int
    anchor_kind: str
    heading_path: str
    semantic_sha256: str
    semantic_anchor: str


_ROOT_TITLE = "Qinao Recovery Spine A+ and Deep Scan Closure Design"
_SOURCE_CONTRACT_TITLE = "Source-disposition completeness contract"
_SOURCE_GATE_TITLE = "Every following condition must hold before implementation planning"
_ACCEPTANCE_TITLE = "Acceptance boundary"
_ACCEPTANCE_GATE_TITLE = (
    "Every following condition must hold before this design is ready for implementation planning"
)
_D0_D2_TITLE = "D0-D2 — Deep Scan #3"
_D2_TITLE = "D2: Official completion gate"
_REPORT_TITLE = "Canonical report projection and failure-state invariants"
_FROZEN_INPUTS_TITLE = "Frozen inputs and evidence status"
_DEEP_SCAN_SNAPSHOT_TITLE = "Deep Scan operational contract snapshot"
_ARCHITECTURAL_TITLE = "Architectural constraints"
_HONEST_RECOVERY_TITLE = "Honest recovery levels"
_RECOVERY_QUALITY_HEADING = (
    "`RecoveryQualitySetV1` is exactly these five `BASRecoveryQuality` cases, "
    "the derived non-Codable UI projection over reopened evidence."
)
_RECOVERY_INVARIANTS_TITLE = "Recovery-quality invariants and non-persistable limits"

_SOURCE_ROOT_HEADING = _heading_path(((1, _ROOT_TITLE), (2, _SOURCE_CONTRACT_TITLE)))
_SOURCE_GATE_HEADING = _heading_path(
    ((1, _ROOT_TITLE), (2, _SOURCE_CONTRACT_TITLE), (3, _SOURCE_GATE_TITLE))
)
_ACCEPTANCE_GATE_HEADING = _heading_path(
    ((1, _ROOT_TITLE), (2, _ACCEPTANCE_TITLE), (3, _ACCEPTANCE_GATE_TITLE))
)
_D2_GATE_HEADING = _heading_path(
    ((1, _ROOT_TITLE), (2, _D0_D2_TITLE), (3, _D2_TITLE))
)
_D2_REPORT_HEADING = _heading_path(
    ((1, _ROOT_TITLE), (2, _D0_D2_TITLE), (3, _D2_TITLE), (4, _REPORT_TITLE))
)
_DEEP_SCAN_SNAPSHOT_HEADING = _heading_path(
    ((1, _ROOT_TITLE), (2, _FROZEN_INPUTS_TITLE), (3, _DEEP_SCAN_SNAPSHOT_TITLE))
)
_RECOVERY_QUALITY_CASE_HEADING = _heading_path(
    ((1, _ROOT_TITLE), (2, _ARCHITECTURAL_TITLE), (3, _HONEST_RECOVERY_TITLE),
     (4, _RECOVERY_QUALITY_HEADING))
)
_RECOVERY_QUALITY_REFERENCE_HEADING = _heading_path(
    ((1, _ROOT_TITLE), (2, _ARCHITECTURAL_TITLE), (3, _HONEST_RECOVERY_TITLE),
     (4, _RECOVERY_INVARIANTS_TITLE))
)

REQUIRED_NAMED_CONTRACTS = frozenset(
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

NAMED_CONTRACT_OCCURRENCES: dict[str, tuple[NamedContractOccurrence, ...]] = {
    "ReportProjectionV1": (
        NamedContractOccurrence(
            "QUN-95e2b71cf8daed5ff13d147b", 1149, "prose", _D2_REPORT_HEADING,
            "95e2b71cf8daed5ff13d147bea5e2e375cc17bdc743ed4263684f3cf066b8000",
            "byte-equal to ReportProjectionV1 derived from the three canonical JSON documents",
        ),
        NamedContractOccurrence(
            "QUN-93b9acbf1822e0e41a9a1499", 1155, "prose", _D2_REPORT_HEADING,
            "93b9acbf1822e0e41a9a1499976f6da35aede79cedbcab63dbe3e8509ddea88b",
            "and ReportProjectionV1's exact bytes verify",
        ),
    ),
    "VerifierV1": (
        NamedContractOccurrence(
            "QUN-0957b04395a68cb236893eb9", 1194, "prose", _SOURCE_ROOT_HEADING,
            "0957b04395a68cb236893eb9660d475624731ceb328fafe69f52c3a67abcc07f",
            "The closed VerifierV1 source path is:",
        ),
        NamedContractOccurrence(
            "QUN-0b8e2e6fb129ad01019acbf1", 1209, "listLeader", _SOURCE_GATE_HEADING,
            "0b8e2e6fb129ad01019acbf15cd82081612e84162e613567595f57f28cc89b05",
            "implemented by VerifierV1's source code",
        ),
    ),
    "UnitNormV1": (
        NamedContractOccurrence(
            "QUN-9c1d445bba747e8273ee8dce", 1257, "listLeader", _SOURCE_GATE_HEADING,
            "9c1d445bba747e8273ee8dcecb9313d66931a2040eb836d550563f6865f81721",
            "UnitNormV1 applies Unicode NFC",
        ),
        NamedContractOccurrence(
            "QUN-366a43b37f9e1721665d4689", 1269, "listLeader", _SOURCE_GATE_HEADING,
            "366a43b37f9e1721665d4689c564e8241ac3df91094f58e31f15995f9ccc3bd0",
            "apply the UnitNormV1 NFC/ASCII-whitespace profile",
        ),
    ),
    "HeaderV1": (
        NamedContractOccurrence(
            "QUN-1ff5a0f84d85fc3ee88ace63", 1304, "listLeader", _SOURCE_GATE_HEADING,
            "1ff5a0f84d85fc3ee88ace634ffcb8f6ef96712dfd1d6ff67dd9464bfa7568f3",
            "Define TSV HeaderV1 via",
        ),
    ),
    "RecordShapeV1": (
        NamedContractOccurrence(
            "QUN-a7e9616bf9fc08e61ce85f51", 1313, "prose", _SOURCE_GATE_HEADING,
            "a7e9616bf9fc08e61ce85f51da12e85e7bd1821b108d15ae9eef6519e751b77d",
            "Define RecordShapeV1 as a closed matrix",
        ),
        NamedContractOccurrence(
            "QUN-07b5093fea6b7ed0389798cd", 1380, "prose", _SOURCE_GATE_HEADING,
            "07b5093fea6b7ed0389798cd293a76d8230406b847beefda21475819985efc15",
            "RecordShapeV1 validates every required and forbidden field",
        ),
        NamedContractOccurrence(
            "QUN-4007b25182af250dca4e35b9", 1521, "listLeader", _ACCEPTANCE_GATE_HEADING,
            "4007b25182af250dca4e35b94255f404c1cf1734fe4ff4e1b8b02be114b4cb9a",
            "RecordShapeV1 scan-field nulls",
        ),
    ),
    "AuthoritySetV1": (
        NamedContractOccurrence(
            "QUN-b330521402fa62f90961c49b", 1383, "prose", _SOURCE_GATE_HEADING,
            "b330521402fa62f90961c49bfb4aedd5ac9f5078e5da99cbf8ca2c891bc9daf5",
            "The closed AuthoritySetV1 source-state set is",
        ),
        NamedContractOccurrence(
            "QUN-b330521402fa62f90961c49b", 1383, "prose", _SOURCE_GATE_HEADING,
            "b330521402fa62f90961c49bfb4aedd5ac9f5078e5da99cbf8ca2c891bc9daf5",
            "weaken the AuthoritySetV1",
        ),
        NamedContractOccurrence(
            "QUN-a8055ebd89ddc4f7db1a8cbc", 1398, "prose", _SOURCE_GATE_HEADING,
            "a8055ebd89ddc4f7db1a8cbcaf895a8958bfc8aabc640aecbad08fa461d3db08",
            "in the AuthoritySetV1 or",
        ),
    ),
    "RecoveryQualitySetV1": (
        NamedContractOccurrence(
            "QUN-ac1282b9ed162e63fd7f62d7", 350, "prose",
            _RECOVERY_QUALITY_REFERENCE_HEADING,
            "ac1282b9ed162e63fd7f62d78ee5af1dd0e040d9345d69156f5cc7f3340beb30",
            "`RecoveryQualitySetV1` is no reducer input, authority, or alias/compatibility wire material.",
        ),
    ),
}

_REPORT_JSON_UNIT = NamedUnitIdentity(
    "QUN-dfd168637751e0a5679014ce", 1132, "prose", _D2_GATE_HEADING,
    "dfd168637751e0a5679014cec6ed6bba4b4542ec0c564dc8d35f0825660b42a3",
)
_REPORT_PROJECTION_IMPLEMENTATION_UNIT = NamedUnitIdentity(
    "QUN-106bfb2f37d543780817e982", 285, "listLeader", _DEEP_SCAN_SNAPSHOT_HEADING,
    "106bfb2f37d543780817e982320fc868aa0bd9da5cc0da10d3a1e179a3036c13",
)
_HEADER_NAMES_UNIT = NamedUnitIdentity(
    "QUN-f72aa897afa9968903edcbab", 1309, "fencedCode", _SOURCE_GATE_HEADING,
    "f72aa897afa9968903edcbab7ead1fcc67e4ea40641a46f6953910f405f68687",
)

NAMED_OCCURRENCE_DOMAIN = b"qinao-named-contract-occurrence/v1\0"
NAMED_CONTRACT_DOMAIN = b"qinao-named-contract/v1\0"
NAMED_CONTRACT_SET_DOMAIN = b"qinao-named-contract-set/v1\0"
FROZEN_NAMED_CONTRACT_COUNT = 7
FROZEN_NAMED_CONTRACT_ROOT = (
    "585e14ab6e320f55d4fa768ac7c3f7044eb81581410c17218007a2814ac2daee"
)
_RECOVERY_ALIAS_MARKERS = (
    b"# Qinao Recovery Spine A+ and Deep Scan Closure Design",
    b"ReportProjectionV1",
    b"VerifierV1",
    b"UnitNormV1",
    b"HeaderV1",
    b"RecordShapeV1",
    b"AuthoritySetV1",
    b"RecoveryQualitySetV1",
    b"qinao-source-disposition-ledger/v1",
    b"qinao-markdown-unit-extractor/v1",
)


def _find_named_unit(
    units: Sequence[dict[str, object]],
    identity: NamedUnitIdentity | NamedContractOccurrence,
    contract_name: str,
) -> dict[str, object]:
    matches = [
        unit
        for unit in units
        if unit["startLine"] == identity.start_line
        and unit["anchorKind"] == identity.anchor_kind
        and unit["headingPath"] == identity.heading_path
    ]
    if len(matches) != 1:
        raise LedgerError(
            f"{contract_name} does not resolve to one frozen UNIT/startLine/anchorKind/headingPath"
        )
    return matches[0]


def _assert_named_unit_identity(
    unit: dict[str, object],
    identity: NamedUnitIdentity | NamedContractOccurrence,
    contract_name: str,
) -> None:
    if unit["unitID"] != identity.unit_id or unit["semanticSHA256"] != identity.semantic_sha256:
        raise LedgerError(f"{contract_name} frozen UNIT semantic identity drift")


def _name_matches(text: str, name: str) -> list[re.Match[str]]:
    pattern = re.compile(rf"(?<![A-Za-z0-9_]){re.escape(name)}(?![A-Za-z0-9_])")
    return list(pattern.finditer(text))


def _validate_named_occurrences(
    spec_data: bytes,
    units: Sequence[dict[str, object]],
) -> dict[str, list[tuple[NamedContractOccurrence, dict[str, object]]]]:
    if not REQUIRED_NAMED_CONTRACTS:
        raise LedgerError("required named-contract set is empty")
    if frozenset(NAMED_CONTRACT_OCCURRENCES) != REQUIRED_NAMED_CONTRACTS:
        raise LedgerError("named-contract registry does not equal the required closed set")

    result: dict[str, list[tuple[NamedContractOccurrence, dict[str, object]]]] = {}
    raw_text = spec_data.decode("utf-8")
    for name in sorted(REQUIRED_NAMED_CONTRACTS):
        expectations = NAMED_CONTRACT_OCCURRENCES[name]
        if not expectations:
            raise LedgerError(f"{name} has no required occurrence")
        raw_expected = 2 if name == "RecoveryQualitySetV1" else len(expectations)
        if len(_name_matches(raw_text, name)) != raw_expected:
            raise LedgerError(f"{name} raw UTF-8 occurrence count mismatch")
        found: set[tuple[int, int]] = set()
        for unit in units:
            for match in _name_matches(str(unit["normalizedText"]), name):
                found.add((int(unit["startByte"]), match.start()))
        if len(found) != len(expectations):
            raise LedgerError(
                f"{name} occurrence count mismatch: expected {len(expectations)}, found {len(found)}"
            )

        assigned: set[tuple[int, int]] = set()
        resolved: list[tuple[NamedContractOccurrence, dict[str, object]]] = []
        for expectation in expectations:
            unit = _find_named_unit(units, expectation, name)
            text = str(unit["normalizedText"])
            if text.count(expectation.semantic_anchor) != 1:
                raise LedgerError(f"{name} semantic anchor mismatch")
            anchor_start = text.index(expectation.semantic_anchor)
            anchor_end = anchor_start + len(expectation.semantic_anchor)
            in_anchor = [
                match
                for match in _name_matches(text, name)
                if anchor_start <= match.start() and match.end() <= anchor_end
            ]
            if len(in_anchor) != 1:
                raise LedgerError(f"{name} definition/reference anchor is not singular")
            key = (int(unit["startByte"]), in_anchor[0].start())
            if key in assigned:
                raise LedgerError(f"{name} occurrence was assigned to two semantic anchors")
            assigned.add(key)
            resolved.append((expectation, unit))
        if assigned != found:
            raise LedgerError(f"{name} has an occurrence outside its frozen semantic anchors")
        result[name] = resolved
    return result


def _unit_identity_fields(unit: dict[str, object]) -> tuple[str, ...]:
    return (
        str(unit["unitID"]),
        str(unit["startLine"]),
        str(unit["anchorKind"]),
        str(unit["headingPath"]),
        str(unit["semanticSHA256"]),
    )


def _report_projection_contract_payload(
    units: Sequence[dict[str, object]],
    occurrences: dict[str, list[tuple[NamedContractOccurrence, dict[str, object]]]],
) -> tuple[str, ...]:
    definition = str(occurrences["ReportProjectionV1"][0][1]["normalizedText"])
    required_fragments = (
        "`report.md` is not in the canonical seal",
        "present and byte-equal to ReportProjectionV1 derived from the three canonical JSON documents",
        "under the frozen report- projection implementation",
        "Regenerating that projection must not change the canonical JSON or seal.",
    )
    if any(fragment not in definition for fragment in required_fragments):
        raise LedgerError("ReportProjectionV1 report/frozen-projection semantics drift")

    support = _find_named_unit(units, _REPORT_JSON_UNIT, "ReportProjectionV1 canonical JSON")
    json_names = tuple(re.findall(r"`([^`]+\.json)`", str(support["normalizedText"])))
    expected_json = ("scan-manifest.json", "findings.json", "coverage.json")
    if json_names != expected_json:
        raise LedgerError("ReportProjectionV1 canonical JSON input tuple mismatch")
    _assert_named_unit_identity(support, _REPORT_JSON_UNIT, "ReportProjectionV1 canonical JSON")

    implementation = _find_named_unit(
        units,
        _REPORT_PROJECTION_IMPLEMENTATION_UNIT,
        "ReportProjectionV1 frozen implementation",
    )
    implementation_match = re.fullmatch(
        r"`([^`]+)` \(([0-9,]+) bytes\): `([0-9a-f]{64})`; and",
        str(implementation["normalizedText"]),
    )
    expected_implementation = (
        "scripts/report_projection.py",
        "41,677",
        "d7a90862f92c29e2eb30c36dfa52c6e01a7c53a6cfa6ed4866b1a58aadae34ed",
    )
    if implementation_match is None or implementation_match.groups() != expected_implementation:
        raise LedgerError("ReportProjectionV1 frozen implementation identity drift")
    _assert_named_unit_identity(
        implementation,
        _REPORT_PROJECTION_IMPLEMENTATION_UNIT,
        "ReportProjectionV1 frozen implementation",
    )
    return (
        "report.md",
        *json_names,
        "presentAndByteEqual",
        "frozenProjectionImplementation",
        expected_implementation[0],
        expected_implementation[1].replace(",", ""),
        expected_implementation[2],
        "regenerationPreservesCanonicalJSONAndSeal",
        *_unit_identity_fields(support),
        *_unit_identity_fields(implementation),
    )


def _verifier_contract_payload(
    occurrences: dict[str, list[tuple[NamedContractOccurrence, dict[str, object]]]],
) -> tuple[str, ...]:
    definition = str(occurrences["VerifierV1"][0][1]["normalizedText"])
    paths = re.findall(r"The closed VerifierV1 source path is: `([^`]+)`\.", definition)
    if paths != [VERIFIER_REL] or definition.count(VERIFIER_REL) != 1:
        raise LedgerError("VerifierV1 exact source path mismatch")
    # Deliberately bind only the repository path. Reading or hashing this verifier
    # here would make the named-contract root depend on its own bytes.
    return (VERIFIER_REL,)


def _unit_norm_contract_payload(
    occurrences: dict[str, list[tuple[NamedContractOccurrence, dict[str, object]]]],
) -> tuple[str, ...]:
    definition = str(occurrences["UnitNormV1"][0][1]["normalizedText"])
    reference = str(occurrences["UnitNormV1"][1][1]["normalizedText"])
    required_definition = (
        "UnitNormV1 applies Unicode NFC",
        "removes only the first matched list marker plus following whitespace for a list unit",
        "replaces each maximal ASCII whitespace run (`09-0D` or `20`) with one U+0020",
        "trims leading/trailing U+0020",
    )
    required_reference = (
        "apply the UnitNormV1 NFC/ASCII-whitespace profile",
        "removing the list marker only when the clause starts at the parent list UNIT's start",
    )
    if any(fragment not in definition for fragment in required_definition) or any(
        fragment not in reference for fragment in required_reference
    ):
        raise LedgerError("UnitNormV1 prose/executable normalization contract drift")
    if LIST_RE.pattern != br"^([ \t]*)([-+*]|[0-9]{1,9}[.)])[ \t]+":
        raise LedgerError("UnitNormV1 list-leader regex drift")
    if ASCII_WHITESPACE_RE.pattern != r"[\x09-\x0d\x20]+":
        raise LedgerError("UnitNormV1 ASCII-whitespace regex drift")

    list_probe = b"  12. A\xcc\x8a\t \n B\x0b\x0c\r C  "
    prose_probe = b"12. A\xcc\x8a\tB"
    clause_probe = b"12. A\xcc\x8a\tB"
    list_value = _normalize_unit(list_probe, "listLeader")
    prose_value = _normalize_unit(prose_probe, "prose")
    clause_value = _normalize_clause(
        clause_probe,
        {"startByte": 0, "anchorKind": "listLeader"},
        {"clauseStartByte": "0", "clauseEndByteExclusive": str(len(clause_probe))},
    )
    if (unicodedata.normalize("NFC", "A\u030a"), list_value, prose_value, clause_value) != (
        "\u00c5", "\u00c5 B C", "12. \u00c5 B", "\u00c5 B",
    ):
        raise LedgerError("UnitNormV1 executable normalization payload mismatch")
    return (
        "UnicodeNFC",
        LIST_RE.pattern.decode("ascii"),
        ASCII_WHITESPACE_RE.pattern,
        list_value,
        prose_value,
        clause_value,
    )


def _parse_fenced_header_names(spec_data: bytes, unit: dict[str, object]) -> tuple[str, ...]:
    raw = spec_data[int(unit["startByte"]):int(unit["endByteExclusive"])]
    lines = raw.splitlines()
    if len(lines) < 3:
        raise LedgerError("HeaderV1 fenced code has no closed payload")
    opener = FENCE_RE.fullmatch(lines[0])
    if opener is None or opener.group(3).strip(b" \t") != b"text":
        raise LedgerError("HeaderV1 must use one text fenced-code UNIT")
    marker = opener.group(2)
    if not _is_fence_closer(lines[-1], marker[0], len(marker)):
        raise LedgerError("HeaderV1 fenced-code closer mismatch")
    try:
        return tuple(token.decode("ascii") for token in b"\n".join(lines[1:-1]).split())
    except UnicodeDecodeError as error:
        raise LedgerError("HeaderV1 contains a non-ASCII field name") from error


def _header_contract_payload(
    spec_data: bytes,
    units: Sequence[dict[str, object]],
    occurrences: dict[str, list[tuple[NamedContractOccurrence, dict[str, object]]]],
) -> tuple[str, ...]:
    definition = str(occurrences["HeaderV1"][0][1]["normalizedText"])
    references = re.findall(
        r"Define TSV HeaderV1 via (QUN-[0-9a-f]{24}) names, TAB-joined;",
        definition,
    )
    if len(references) != 1:
        raise LedgerError("HeaderV1 must name one QUN fenced-code definition and TAB join")
    matching_units = [unit for unit in units if unit["unitID"] == references[0]]
    if len(matching_units) != 1:
        raise LedgerError("HeaderV1 referenced QUN does not resolve uniquely")
    header_unit = matching_units[0]
    if (
        header_unit["startLine"] != _HEADER_NAMES_UNIT.start_line
        or header_unit["anchorKind"] != _HEADER_NAMES_UNIT.anchor_kind
        or header_unit["headingPath"] != _HEADER_NAMES_UNIT.heading_path
    ):
        raise LedgerError("HeaderV1 QUN resolves outside the frozen fenced-code UNIT")
    names = _parse_fenced_header_names(spec_data, header_unit)
    if len(names) != 64 or names != HEADER:
        raise LedgerError("HeaderV1 fenced names are not the exact 64-column HEADER tuple")
    tab_joined = "\t".join(names)
    if tab_joined.encode("ascii") != b"\t".join(name.encode("ascii") for name in HEADER):
        raise LedgerError("HeaderV1 TAB-join payload mismatch")
    _assert_named_unit_identity(header_unit, _HEADER_NAMES_UNIT, "HeaderV1")
    return (references[0], "64", tab_joined, *_unit_identity_fields(header_unit))


def _record_shape_condition_payloads() -> dict[str, object]:
    source_allowed = RECORD_SHAPES["SOURCE"]["allowed"]
    target_allowed = RECORD_SHAPES["TARGET"]["allowed"]

    expected_scalar_rules = {
        "schemaVersion": "literal",
        "canonicalUInt64": "boundedRegex",
        "lowerHex64": "regex",
        "gitObjectHex": "regex",
    }
    if set(RECORD_SCALAR_RULES) != set(expected_scalar_rules):
        raise LedgerError("RecordShape scalar-language registry is not closed")
    scalar_languages: dict[str, object] = {}
    for rule_name in sorted(RECORD_SCALAR_RULES):
        rule = RECORD_SCALAR_RULES[rule_name]
        kind = expected_scalar_rules[rule_name]
        expected_fields = {
            "literal": {"kind", "value"},
            "regex": {"kind", "language"},
            "boundedRegex": {"kind", "language", "maximum"},
        }[kind]
        if not isinstance(rule, dict) or set(rule) != expected_fields or rule["kind"] != kind:
            raise LedgerError("RecordShape scalar-language rule shape drift")
        if kind == "literal":
            value = rule["value"]
            if not isinstance(value, str) or value == "":
                raise LedgerError("RecordShape scalar literal is not closed")
            scalar_languages[rule_name] = {"kind": kind, "value": value}
            continue
        language = rule["language"]
        if not isinstance(language, re.Pattern) or not isinstance(language.pattern, str):
            raise LedgerError("RecordShape scalar language is not a compiled text regex")
        payload = {
            "kind": kind,
            "pattern": language.pattern,
            "flags": language.flags,
        }
        if kind == "boundedRegex":
            maximum = rule["maximum"]
            if not isinstance(maximum, str) or not language.fullmatch(maximum):
                raise LedgerError("RecordShape bounded scalar maximum is not in its language")
            payload["maximum"] = maximum
        scalar_languages[rule_name] = payload

    scalar_field_rules: dict[str, object] = {}
    for field in sorted(RECORD_SCALAR_FIELD_RULES):
        rule = RECORD_SCALAR_FIELD_RULES[field]
        if not isinstance(rule, dict) or set(rule) != {
            "scalarRule", "nullable", "positiveRecords"
        }:
            raise LedgerError("RecordShape scalar field rule shape drift")
        scalar_rule = rule["scalarRule"]
        nullable = rule["nullable"]
        positive_records = frozenset(rule["positiveRecords"])
        if (
            scalar_rule not in RECORD_SCALAR_RULES
            or not isinstance(nullable, bool)
            or not positive_records <= frozenset(RECORD_RANK)
        ):
            raise LedgerError("RecordShape scalar field rule is not closed")
        if field == "anchorLocator.ordinal":
            applicable_records = frozenset(RECORD_RANK)
            expected_nullable = False
        else:
            if field not in HEADER:
                raise LedgerError("RecordShape scalar field is not in HEADER")
            applicable_records = frozenset(
                record_type
                for record_type, shape in RECORD_SHAPES.items()
                if field in shape["allowed"]
            )
            if not applicable_records:
                raise LedgerError("RecordShape scalar field has no record consumer")
            # Presence is owned solely by RECORD_SHAPES.  Physical scalar
            # languages therefore admit the null sentinel and let the active
            # record shape decide whether that field is required.
            expected_nullable = field != "schemaVersion"
        if nullable != expected_nullable or not positive_records <= applicable_records:
            raise LedgerError("RecordShape scalar field presence/positive semantics drift")
        scalar_field_rules[field] = {
            "scalarRule": scalar_rule,
            "nullable": nullable,
            "positiveRecords": positive_records,
            "applicableRecords": applicable_records,
        }

    identifier_languages: dict[str, object] = {}
    for language_name in sorted(IDENTIFIER_LANGUAGES):
        language = IDENTIFIER_LANGUAGES[language_name]
        if not isinstance(language, re.Pattern) or not isinstance(language.pattern, str):
            raise LedgerError("identifier language is not a compiled text regex")
        identifier_languages[language_name] = {
            "pattern": language.pattern,
            "flags": language.flags,
        }

    identifier_fields: dict[str, object] = {}
    identifier_pairs: set[tuple[str, str]] = set()
    for rule_name in sorted(IDENTIFIER_FIELD_RULES):
        rule = IDENTIFIER_FIELD_RULES[rule_name]
        if not isinstance(rule, dict) or set(rule) != {
            "field", "identifierLanguage", "applicableRecords", "nullable"
        }:
            raise LedgerError("identifier field rule shape drift")
        field = rule["field"]
        language = rule["identifierLanguage"]
        records = frozenset(rule["applicableRecords"])
        if language == "@childRecord" and len(records) == 1:
            child_kind = next(iter(records))
            child_rule = CHILD_RECORD_RULES.get(child_kind)
            language = child_rule.get("childIDLanguage") if isinstance(child_rule, dict) else None
        if (
            field not in HEADER
            or language not in IDENTIFIER_LANGUAGES
            or not records
            or not records <= frozenset(RECORD_RANK)
            or rule["nullable"] != "recordShape"
            or any(field not in RECORD_SHAPES[kind]["allowed"] for kind in records)
        ):
            raise LedgerError("identifier field rule is not closed")
        pairs = {(record_type, field) for record_type in records}
        if identifier_pairs & pairs:
            raise LedgerError("identifier field mapping is not injective")
        identifier_pairs.update(pairs)
        identifier_fields[rule_name] = {
            "field": field,
            "identifierLanguage": language,
            "applicableRecords": records,
            "nullable": "recordShape",
        }
    if frozenset(identifier_pairs) != EXPECTED_IDENTIFIER_FIELD_PAIRS:
        raise LedgerError("identifier-bearing field coverage drift")

    child_topology: dict[str, object] = {}
    child_rule_fields = {
        "rank", "ordinalField", "commitmentField", "parentCountField",
        "parentRootField", "setDomain", "commitmentDomain",
        "commitmentPreimageFields", "childIDLanguage", "childIDPrefix", "parentRecords",
    }
    if frozenset(CHILD_RECORD_RULES) != frozenset({"CLAUSE", "SOURCE", "TARGET"}):
        raise LedgerError("child record topology coverage drift")
    official_preimages = {
        "CLAUSE": CLAUSE_FIELDS, "SOURCE": SOURCE_FIELDS, "TARGET": TARGET_FIELDS,
    }
    official_parent_topology = {
        "CLAUSE": ("clauseCount", "clauseRoot", frozenset({"REQUIREMENT"})),
        "SOURCE": ("sourceBindingCount", "sourceBindingRoot", frozenset({"UNIT", "REQUIREMENT"})),
        "TARGET": ("targetBindingCount", "targetBindingRoot", frozenset({"REQUIREMENT"})),
    }
    ranks: set[int] = set()
    ordinal_fields: set[str] = set()
    commitment_fields: set[str] = set()
    for kind in sorted(CHILD_RECORD_RULES):
        rule = CHILD_RECORD_RULES[kind]
        if not isinstance(rule, dict) or set(rule) != child_rule_fields:
            raise LedgerError("child record topology shape drift")
        preimage_fields = rule["commitmentPreimageFields"]
        parent_records = frozenset(rule["parentRecords"])
        language = IDENTIFIER_LANGUAGES.get(rule["childIDLanguage"])
        if (
            rule["rank"] != RECORD_RANK[kind]
            or rule["rank"] <= RECORD_RANK["REQUIREMENT"]
            or rule["ordinalField"] not in RECORD_SHAPES[kind]["required"]
            or rule["commitmentField"] not in RECORD_SHAPES[kind]["required"]
            or rule["childIDLanguage"] not in IDENTIFIER_LANGUAGES
            or not isinstance(rule["setDomain"], bytes)
            or not isinstance(rule["commitmentDomain"], bytes)
            or not isinstance(preimage_fields, tuple)
            or preimage_fields != official_preimages[kind]
            or len(preimage_fields) != len(set(preimage_fields))
            or not frozenset(preimage_fields) <= RECORD_SHAPES[kind]["allowed"]
            or not rule["childIDPrefix"].endswith("-")
            or not isinstance(language, re.Pattern)
            or not language.fullmatch(rule["childIDPrefix"] + "0" * 24)
            or not parent_records
            or (
                rule["parentCountField"], rule["parentRootField"], parent_records
            ) != official_parent_topology[kind]
            or not parent_records <= frozenset(RECORD_RANK)
            or any(
                rule["parentCountField"] not in RECORD_SHAPES[parent]["required"]
                or rule["parentRootField"] not in RECORD_SHAPES[parent]["required"]
                for parent in parent_records
            )
        ):
            raise LedgerError("child record topology is not closed")
        if (
            rule["rank"] in ranks
            or rule["ordinalField"] in ordinal_fields
            or rule["commitmentField"] in commitment_fields
        ):
            raise LedgerError("child record topology is not injective")
        ranks.add(rule["rank"])
        ordinal_fields.add(rule["ordinalField"])
        commitment_fields.add(rule["commitmentField"])
        child_topology[kind] = {
            **{key: value for key, value in rule.items() if key not in {"setDomain", "commitmentDomain"}},
            "setDomainHex": rule["setDomain"].hex(),
            "commitmentDomainHex": rule["commitmentDomain"].hex(),
        }

    base_enums: dict[str, object] = {}
    for field in sorted(RECORD_SHAPE_ENUMS):
        values = frozenset(RECORD_SHAPE_ENUMS[field])
        if (
            field not in HEADER
            or not values
            or any(not isinstance(value, str) or value in {"", NULL} for value in values)
        ):
            raise LedgerError("base RecordShape enum is not closed")
        applicable_records = frozenset(
            record_type for record_type, shape in RECORD_SHAPES.items()
            if field in shape["allowed"]
        )
        if not applicable_records:
            raise LedgerError("base RecordShape enum has no field consumer")
        base_enums[field] = {
            "values": values,
            "applicableRecords": applicable_records,
            "nullable": "recordShape",
        }

    if frozenset(UNIT_CLASS_RULES) != frozenset(RECORD_SHAPE_ENUMS["unitClass"]):
        raise LedgerError("UNIT class capability coverage drift")
    unit_class_rules: dict[str, object] = {}
    capability_fields = {
        "requiresDirectSources", "allowsDirectSources",
        "allowsRequirements", "requiresRequirements",
    }
    for unit_class in sorted(UNIT_CLASS_RULES):
        rule = UNIT_CLASS_RULES[unit_class]
        if (
            not isinstance(rule, dict)
            or set(rule) != capability_fields
            or any(not isinstance(value, bool) for value in rule.values())
            or (rule["requiresDirectSources"] and not rule["allowsDirectSources"])
            or (rule["requiresRequirements"] and not rule["allowsRequirements"])
        ):
            raise LedgerError("UNIT class capability rule is not closed")
        unit_class_rules[unit_class] = dict(rule)

    source_kind_rules: dict[str, object] = {}
    for source_kind in sorted(SOURCE_KIND_FIELD_RULES):
        rule = SOURCE_KIND_FIELD_RULES[source_kind]
        if set(rule) != {"required", "forbidden", "equals"}:
            raise LedgerError("SOURCE kind field rule shape drift")
        required = frozenset(rule["required"])
        forbidden = frozenset(rule["forbidden"])
        equals = rule["equals"]
        if (
            not isinstance(equals, dict)
            or not required <= source_allowed
            or not forbidden <= source_allowed
            or not frozenset(equals) <= source_allowed
            or required & forbidden
            or forbidden & frozenset(equals)
            or any(
                not isinstance(value, str) or value in {"", NULL}
                for value in equals.values()
            )
        ):
            raise LedgerError("SOURCE kind field rule is not closed")
        source_kind_rules[source_kind] = {
            "required": required,
            "forbidden": forbidden,
            "equals": dict(equals),
        }

    admission_compatibility: dict[str, object] = {}
    for admission_state in sorted(SOURCE_ADMISSION_KIND_COMPATIBILITY):
        source_kinds = frozenset(SOURCE_ADMISSION_KIND_COMPATIBILITY[admission_state])
        if not source_kinds or not source_kinds <= frozenset(SOURCE_KIND_FIELD_RULES):
            raise LedgerError("SOURCE admission compatibility is not closed")
        admission_compatibility[admission_state] = source_kinds
    compatibility_kinds = frozenset().union(
        *SOURCE_ADMISSION_KIND_COMPATIBILITY.values()
    )
    if compatibility_kinds != SOURCE_KINDS or ADMISSION_STATES != frozenset(
        SOURCE_ADMISSION_KIND_COMPATIBILITY
    ):
        raise LedgerError("SOURCE kind/admission compatibility coverage drift")

    disposition_rules: dict[str, object] = {}
    for disposition in sorted(DISPOSITION_SOURCE_RULES):
        rule = DISPOSITION_SOURCE_RULES[disposition]
        if set(rule) != {"requiredAny", "allowed", "executionStateEquals"}:
            raise LedgerError("disposition/SOURCE rule shape drift")
        required_expression = frozenset(rule["requiredAny"])
        allowed_expression = frozenset(rule["allowed"])
        if not required_expression or not allowed_expression:
            raise LedgerError("disposition/SOURCE rule has an empty state expression")
        required_states = resolve_admission_state_expression(required_expression)
        allowed_states = resolve_admission_state_expression(allowed_expression)
        execution_state = rule["executionStateEquals"]
        if (
            not required_states <= allowed_states
            or (
                execution_state is not None
                and execution_state not in RECORD_SHAPE_ENUMS["executionState"]
            )
        ):
            raise LedgerError("disposition/SOURCE rule is not closed")
        disposition_rules[disposition] = {
            "requiredExpression": required_expression,
            "requiredResolved": required_states,
            "allowedExpression": allowed_expression,
            "allowedResolved": allowed_states,
            "executionStateEquals": execution_state,
        }

    target_presence: dict[str, object] = {}
    for rule_name in sorted(TARGET_PRESENCE_RULES):
        rule = TARGET_PRESENCE_RULES[rule_name]
        if set(rule) != {"operator", "fields"}:
            raise LedgerError("TARGET presence rule shape drift")
        operator = rule["operator"]
        fields = tuple(rule["fields"])
        if (
            operator not in {"exactlyOne", "allOrNone"}
            or len(fields) < 2
            or len(set(fields)) != len(fields)
            or not frozenset(fields) <= target_allowed
        ):
            raise LedgerError("TARGET presence rule is not closed")
        target_presence[rule_name] = {
            "operator": operator,
            "fields": fields,
        }

    scan_identities: dict[str, object] = {}
    for scan_number in sorted(SCAN_IDENTITY_RULES, key=lambda value: (value == NULL, value)):
        values = SCAN_IDENTITY_RULES[scan_number]
        if (
            set(values) != set(SCAN_IDENTITY_FIELDS)
            or not frozenset(values) <= source_allowed
        ):
            raise LedgerError("scan identity rule shape drift")
        scan_identities[scan_number] = {
            field: values[field] for field in SCAN_IDENTITY_FIELDS
        }

    return {
        "scalarLanguages": scalar_languages,
        "scalarFieldRules": scalar_field_rules,
        "identifierLanguages": identifier_languages,
        "identifierFieldRules": identifier_fields,
        "childRecordRules": child_topology,
        "baseEnums": base_enums,
        "unitClassRules": unit_class_rules,
        "sourceKindFieldRules": source_kind_rules,
        "sourceAdmissionCompatibility": admission_compatibility,
        "dispositionEnum": frozenset(DISPOSITION_SOURCE_RULES),
        "dispositionSourceRules": disposition_rules,
        "targetPresenceRules": target_presence,
        "governedWaves": frozenset(GOVERNED_WAVES),
        "scanIdentityFields": tuple(SCAN_IDENTITY_FIELDS),
        "scanIdentities": scan_identities,
    }


def _record_shape_contract_payload(
    occurrences: dict[str, list[tuple[NamedContractOccurrence, dict[str, object]]]],
) -> tuple[str, ...]:
    definition = str(occurrences["RecordShapeV1"][0][1]["normalizedText"])
    enforcement = str(occurrences["RecordShapeV1"][1][1]["normalizedText"])
    acceptance = str(occurrences["RecordShapeV1"][2][1]["normalizedText"])
    if (
        "Define RecordShapeV1 as a closed matrix; every field is required, conditionally allowed, or `-`:"
        not in definition
        or "RecordShapeV1 validates every required and forbidden field; it is not merely documentation."
        not in enforcement
        or "RecordShapeV1 scan-field nulls" not in acceptance
    ):
        raise LedgerError("RecordShapeV1 closed required/conditional/null semantics drift")
    record_order = tuple(
        name for name, rank in sorted(RECORD_RANK.items(), key=lambda item: (item[1], item[0]))
    )
    expected_order = ("UNIT", "REQUIREMENT", "CLAUSE", "SOURCE", "TARGET")
    if record_order != expected_order or tuple(sorted(RECORD_RANK.values())) != tuple(range(5)):
        raise LedgerError("RecordShapeV1 record-type order drift")
    if frozenset(RECORD_SHAPES) != frozenset(expected_order):
        raise LedgerError("RecordShapeV1 allowed-field type set drift")
    if NULL != "-":
        raise LedgerError("RecordShapeV1 null sentinel drift")
    record_shapes = {
        record_type: {
            "required": frozenset(RECORD_SHAPES[record_type]["required"]),
            "allowed": frozenset(RECORD_SHAPES[record_type]["allowed"]),
        }
        for record_type in record_order
    }
    source_projection_fields = tuple(PROVENANCE_SOURCE_PROJECTION_FIELDS)
    target_projection_fields = tuple(PROVENANCE_TARGET_PROJECTION_FIELDS)
    if (
        source_projection_fields != tuple(_SourceProjection._fields)
        or target_projection_fields != tuple(_TargetProjection._fields)
        or len(source_projection_fields) != len(set(source_projection_fields))
        or len(target_projection_fields) != len(set(target_projection_fields))
        or not frozenset(source_projection_fields) <= RECORD_SHAPES["SOURCE"]["allowed"]
        or not frozenset(target_projection_fields) <= RECORD_SHAPES["TARGET"]["allowed"]
    ):
        raise LedgerError("RecordShapeV1 provenance projection schema drift")
    provenance_domains = (
        PROVENANCE_UNIT_MEMBER_DOMAIN,
        PROVENANCE_REQUIREMENT_MEMBER_DOMAIN,
        PROVENANCE_MAPPING_SET_DOMAIN,
    )
    if (
        any(type(domain) is not bytes or not domain.endswith(b"\0") for domain in provenance_domains)
        or len(set(provenance_domains)) != len(provenance_domains)
    ):
        raise LedgerError("RecordShapeV1 provenance projection domain drift")
    structured_payload = {
        "semantics": {
            "closed": True,
            "required": True,
            "conditionallyAllowed": True,
            "forbiddenValidated": True,
            "scanFieldNulls": True,
        },
        "null": NULL,
        "recordOrder": record_order,
        "header": tuple(HEADER),
        "recordShapes": record_shapes,
        "conditions": _record_shape_condition_payloads(),
        "provenanceProjection": {
            "sourceFields": source_projection_fields,
            "targetFields": target_projection_fields,
            "unitMemberDomainHex": PROVENANCE_UNIT_MEMBER_DOMAIN.hex(),
            "requirementMemberDomainHex": PROVENANCE_REQUIREMENT_MEMBER_DOMAIN.hex(),
            "mappingSetDomainHex": PROVENANCE_MAPPING_SET_DOMAIN.hex(),
        },
    }
    return (canonical_named_value("RecordShapeV1", structured_payload),)


def _authority_set_contract_payload(
    occurrences: dict[str, list[tuple[NamedContractOccurrence, dict[str, object]]]],
) -> tuple[str, ...]:
    definition = str(occurrences["AuthoritySetV1"][0][1]["normalizedText"])
    matches = re.findall(r"The closed AuthoritySetV1 source-state set is `([^`]+)`;", definition)
    if len(matches) != 1:
        raise LedgerError("AuthoritySetV1 has no singular closed source-state definition")
    states = tuple(matches[0].split(" | "))
    if states != AUTHORITY_ADMISSION_STATES:
        raise LedgerError("AuthoritySetV1 is not the exact four-state tuple")
    return states


_RECOVERY_QUALITY_CASES = (
    ("exactAppOwnedBytes", "QUN-6bf14af4b95bfe3b4dbcc775", 341, "6bf14af4b95bfe3b4dbcc775131b89ad40148e682cd624d3b5f35c24882918e8"),
    ("deterministicReplay", "QUN-88638a1669456e473d6f2470", 343, "88638a1669456e473d6f24703c652c25600c254291172956b5df75b225c41b1a"),
    ("semanticReconstruction", "QUN-3508ed9ab6ebaa7a3f57600f", 344, "3508ed9ab6ebaa7a3f57600f47b757989b4e2b18e2d8f5008fc265360d3414e5"),
    ("externalReconciliation", "QUN-1fe147c34d38e27ab82469f0", 346, "1fe147c34d38e27ab82469f06b1f240cc6a6cba7515806c5186bab9ecf9eac6c"),
    ("unavailable", "QUN-77a50d33d9f7f09c21d6f27f", 348, "77a50d33d9f7f09c21d6f27f29e261d2a1648154011b555a1dd5a9c9846957ef"),
)


def _recovery_quality_contract_payload(
    spec_data: bytes,
    units: Sequence[dict[str, object]],
    occurrences: dict[str, list[tuple[NamedContractOccurrence, dict[str, object]]]],
) -> tuple[str, ...]:
    heading = ("#### " + _RECOVERY_QUALITY_HEADING + "\n").encode("utf-8")
    if spec_data.count(heading) != 1:
        raise LedgerError("RecoveryQualitySetV1 exact definition heading drift")
    resolved: list[str] = []
    for case, unit_id, line, semantic in _RECOVERY_QUALITY_CASES:
        matches = [u for u in units if u["startLine"] == line and u["headingPath"] == _RECOVERY_QUALITY_CASE_HEADING]
        if len(matches) != 1:
            raise LedgerError("RecoveryQualitySetV1 case placement/order drift")
        unit = matches[0]
        if unit["unitID"] != unit_id or unit["semanticSHA256"] != semantic or not str(unit["normalizedText"]).startswith(f"`{case}`:"):
            raise LedgerError("RecoveryQualitySetV1 exact ordered case drift")
        resolved.extend((case, *_unit_identity_fields(unit)))
    case_units = [u for u in units if u["headingPath"] == _RECOVERY_QUALITY_CASE_HEADING]
    if len(case_units) != 5:
        raise LedgerError("RecoveryQualitySetV1 must contain exactly five case UNITs")
    reference = str(occurrences["RecoveryQualitySetV1"][0][1]["normalizedText"])
    if reference != "`RecoveryQualitySetV1` is no reducer input, authority, or alias/compatibility wire material.":
        raise LedgerError("RecoveryQualitySetV1 reference semantics drift")
    return (_RECOVERY_QUALITY_HEADING, *resolved, reference)


def validate_named_contracts(
    spec_data: bytes,
    spec_path: str,
    *,
    units: Sequence[dict[str, object]] | None = None,
) -> dict[str, object]:
    empty_root = child_set_root(NAMED_CONTRACT_SET_DOMAIN, [])
    if spec_path != SPEC_REL:
        if any(marker in spec_data for marker in _RECOVERY_ALIAS_MARKERS):
            raise LedgerError("recovery specification markers require the exact SPEC_REL identity")
        return {"namedContractCount": 0, "namedContractRoot": empty_root}

    extracted = list(units) if units is not None else extract_markdown_units(spec_data, spec_path)
    occurrences = _validate_named_occurrences(spec_data, extracted)
    payloads = {
        "ReportProjectionV1": _report_projection_contract_payload(extracted, occurrences),
        "VerifierV1": _verifier_contract_payload(occurrences),
        "UnitNormV1": _unit_norm_contract_payload(occurrences),
        "HeaderV1": _header_contract_payload(spec_data, extracted, occurrences),
        "RecordShapeV1": _record_shape_contract_payload(occurrences),
        "AuthoritySetV1": _authority_set_contract_payload(occurrences),
        "RecoveryQualitySetV1": _recovery_quality_contract_payload(spec_data, extracted, occurrences),
    }
    if frozenset(payloads) != REQUIRED_NAMED_CONTRACTS:
        raise LedgerError("named-contract semantic payload set is incomplete")

    contract_commitments: list[str] = []
    for name in sorted(REQUIRED_NAMED_CONTRACTS):
        occurrence_commitments: list[str] = []
        for expectation, unit in occurrences[name]:
            _assert_named_unit_identity(unit, expectation, name)
            occurrence_commitments.append(
                typed_commitment(
                    NAMED_OCCURRENCE_DOMAIN,
                    [
                        name,
                        expectation.unit_id,
                        str(expectation.start_line),
                        expectation.anchor_kind,
                        expectation.heading_path,
                        expectation.semantic_sha256,
                        expectation.semantic_anchor,
                    ],
                )
            )
        contract_envelope = canonical_named_value(
            "NamedContractV1",
            {
                "name": name,
                "payloadFields": tuple(payloads[name]),
                "occurrenceCommitments": tuple(occurrence_commitments),
            },
        )
        contract_commitments.append(
            typed_commitment(NAMED_CONTRACT_DOMAIN, [contract_envelope])
        )
    result = {
        "namedContractCount": len(contract_commitments),
        "namedContractRoot": child_set_root(NAMED_CONTRACT_SET_DOMAIN, contract_commitments),
    }
    expected = {
        "namedContractCount": FROZEN_NAMED_CONTRACT_COUNT,
        "namedContractRoot": FROZEN_NAMED_CONTRACT_ROOT,
    }
    if spec_path == SPEC_REL and result != expected:
        raise LedgerError("frozen named-contract set drift")
    return result


def _required(row: dict[str, str], fields: Iterable[str]) -> None:
    for field in fields:
        if row[field] == NULL:
            raise LedgerError(f"{row['recordType']} requires {field}")


def _canonical_uint(value: str, field: str, *, positive: bool = False) -> int:
    rule = RECORD_SCALAR_RULES.get("canonicalUInt64")
    if not isinstance(rule, dict) or rule.get("kind") != "boundedRegex":
        raise LedgerError("canonical uint64 scalar rule is unavailable")
    language = rule.get("language")
    uint64_max = rule.get("maximum")
    if (
        not isinstance(language, re.Pattern)
        or not isinstance(language.pattern, str)
        or not isinstance(uint64_max, str)
        or not language.fullmatch(value)
    ):
        raise LedgerError(f"{field} is not canonical unsigned decimal")
    if len(value) > len(uint64_max) or (len(value) == len(uint64_max) and value > uint64_max):
        raise LedgerError(f"{field} exceeds uint64")
    number = int(value)
    if positive and number == 0:
        raise LedgerError(f"{field} must be positive")
    return number


def _hex64(value: str, field: str) -> None:
    if not _scalar_regex("lowerHex64", "regex").fullmatch(value):
        raise LedgerError(f"{field} is not lowercase SHA-256")


def _git_object_hex(value: str, field: str) -> None:
    if not _scalar_regex("gitObjectHex", "regex").fullmatch(value):
        raise LedgerError(f"invalid repository identity {field}")


def _validate_scalar_value(
    value: str,
    field: str,
    mapping: dict[str, object],
    *,
    positive: bool,
) -> int | None:
    scalar_rule = mapping.get("scalarRule")
    rule = RECORD_SCALAR_RULES.get(scalar_rule)
    if not isinstance(rule, dict):
        raise LedgerError(f"{field} scalar rule is unavailable")
    if scalar_rule == "schemaVersion":
        if rule.get("kind") != "literal" or value != rule.get("value"):
            raise LedgerError("schemaVersion must be 1")
        return None
    if scalar_rule == "canonicalUInt64":
        return _canonical_uint(value, field, positive=positive)
    if scalar_rule == "lowerHex64":
        _hex64(value, field)
        return None
    if scalar_rule == "gitObjectHex":
        _git_object_hex(value, field)
        return None
    raise LedgerError(f"{field} has an unknown scalar rule")


def validate_record_scalar_fields(row: dict[str, str], record_type: str) -> None:
    allowed = RECORD_SHAPES[record_type]["allowed"]
    for field, mapping in RECORD_SCALAR_FIELD_RULES.items():
        if field in {"schemaVersion", "anchorLocator.ordinal"} or field not in allowed:
            continue
        if not isinstance(mapping, dict):
            raise LedgerError(f"{field} scalar field rule is unavailable")
        value = row[field]
        if value == NULL:
            if not mapping.get("nullable"):
                raise LedgerError(f"{record_type} requires scalar {field}")
            continue
        positive_records = mapping.get("positiveRecords")
        if not isinstance(positive_records, (set, frozenset)):
            raise LedgerError(f"{field} positive scalar rule is unavailable")
        _validate_scalar_value(
            value,
            field,
            mapping,
            positive=record_type in positive_records,
        )


def validate_identifier_fields(row: dict[str, str], record_type: str) -> None:
    for rule_name, rule in IDENTIFIER_FIELD_RULES.items():
        if not isinstance(rule, dict) or record_type not in rule.get("applicableRecords", ()):
            continue
        field = rule.get("field")
        language_name = rule.get("identifierLanguage")
        if not isinstance(field, str) or not isinstance(language_name, str):
            raise LedgerError(f"identifier field rule {rule_name} is unavailable")
        if language_name == "@childRecord":
            child_rule = CHILD_RECORD_RULES.get(record_type)
            language_name = (
                child_rule.get("childIDLanguage") if isinstance(child_rule, dict) else None
            )
            if not isinstance(language_name, str):
                raise LedgerError(f"identifier field rule {rule_name} has no child topology")
        value = row[field]
        if value == NULL:
            continue
        language = IDENTIFIER_LANGUAGES.get(language_name)
        if not isinstance(language, re.Pattern) or not language.fullmatch(value):
            raise LedgerError(f"invalid identifier field {field}")


def validate_enum_fields(row: dict[str, str], record_type: str) -> None:
    allowed = RECORD_SHAPES[record_type]["allowed"]
    for field, values in RECORD_SHAPE_ENUMS.items():
        if field not in allowed or row[field] == NULL:
            continue
        if row[field] not in values:
            raise LedgerError(f"invalid enum field {field}")
    if (
        record_type == "TARGET"
        and row["governedWave"] != NULL
        and row["governedWave"] not in GOVERNED_WAVES
    ):
        raise LedgerError("invalid governedWave")


def validate_scan_source(row: dict[str, str]) -> None:
    number = row["scanNumber"]
    expected = SCAN_IDENTITY_RULES.get(number)
    if expected is None:
        raise LedgerError("unknown or renumbered scan identity")
    if any(row[field] != expected[field] for field in SCAN_IDENTITY_FIELDS):
        raise LedgerError("exact scan identity/state/admission mismatch")


def validate_source_kind_admission(source_kind: str, admission_state: str) -> None:
    allowed = SOURCE_ADMISSION_KIND_COMPATIBILITY.get(admission_state, frozenset())
    if source_kind not in allowed:
        raise LedgerError("sourceKind/admissionState compatibility mismatch")


def validate_source_kind_field_rules(row: dict[str, str]) -> None:
    rule = SOURCE_KIND_FIELD_RULES.get(row["sourceKind"])
    if rule is None:
        raise LedgerError("unknown sourceKind")
    _required(row, rule["required"])
    for field in rule["forbidden"]:
        if row[field] != NULL:
            raise LedgerError(f"{row['sourceKind']} forbids {field}")
    for field, expected in rule["equals"].items():
        if row[field] != expected:
            raise LedgerError(f"{row['sourceKind']} requires {field}={expected}")


def validate_target_presence_rules(row: dict[str, str]) -> None:
    for rule_name, rule in TARGET_PRESENCE_RULES.items():
        present = tuple(row[field] != NULL for field in rule["fields"])
        operator = rule["operator"]
        if operator == "exactlyOne":
            valid = sum(present) == 1
        elif operator == "allOrNone":
            valid = all(present) or not any(present)
        else:
            raise LedgerError(f"unknown TARGET presence operator for {rule_name}")
        if not valid:
            raise LedgerError(f"TARGET {rule_name} presence mismatch")


def validate_row_shape(row: dict[str, str]) -> None:
    if set(row) != set(HEADER):
        missing = sorted(set(HEADER) - set(row))
        extra = sorted(set(row) - set(HEADER))
        raise LedgerError(f"row columns mismatch missing={missing} extra={extra}")
    for field, value in row.items():
        if not isinstance(value, str) or value == "" or any(char in value for char in "\t\r\n\x00"):
            raise LedgerError(f"noncanonical cell {field}")
    schema_mapping = RECORD_SCALAR_FIELD_RULES.get("schemaVersion")
    if not isinstance(schema_mapping, dict):
        raise LedgerError("schemaVersion scalar field rule is unavailable")
    _validate_scalar_value(row["schemaVersion"], "schemaVersion", schema_mapping, positive=False)
    record_type = row["recordType"]
    if record_type not in RECORD_RANK:
        raise LedgerError(f"unknown recordType {record_type!r}")
    _required(row, RECORD_SHAPES[record_type]["required"])
    allowed = RECORD_SHAPES[record_type]["allowed"]
    for field in HEADER:
        if field not in allowed and row[field] != NULL:
            raise LedgerError(f"{record_type} forbids {field}")
    validate_record_scalar_fields(row, record_type)
    validate_identifier_fields(row, record_type)
    validate_enum_fields(row, record_type)
    if int(row["unitEndByteExclusive"]) <= int(row["unitStartByte"]):
        raise LedgerError("unit byte span is empty or reversed")
    if int(row["unitEndLine"]) < int(row["unitStartLine"]):
        raise LedgerError("unit line span is reversed")
    expected_locator = f"qinao-unit-locator/v1:{row['headingPath']}:{row['anchorKind']}:"
    if not row["anchorLocator"].startswith(expected_locator):
        raise LedgerError("anchorLocator does not match unit identity")
    locator_mapping = RECORD_SCALAR_FIELD_RULES.get("anchorLocator.ordinal")
    if not isinstance(locator_mapping, dict):
        raise LedgerError("anchor locator ordinal scalar rule is unavailable")
    _validate_scalar_value(
        row["anchorLocator"][len(expected_locator):],
        "anchor ordinal",
        locator_mapping,
        positive=record_type in locator_mapping.get("positiveRecords", ()),
    )

    if record_type == "UNIT":
        if row["subjectID"] != row["unitID"] or row["requirementID"] != NULL or row["childID"] != NULL:
            raise LedgerError("UNIT subject/parent identity mismatch")
        count = int(row["sourceBindingCount"])
        class_rule = UNIT_CLASS_RULES[row["unitClass"]]
        if class_rule["requiresDirectSources"] and count == 0:
            raise LedgerError("evidence/introductory/mixed UNIT requires provenance")
    elif record_type == "REQUIREMENT":
        if row["subjectID"] != row["requirementID"]:
            raise LedgerError("REQUIREMENT identity mismatch")
        if row["disposition"] not in DISPOSITION_SOURCE_RULES:
            raise LedgerError("invalid requirement disposition/execution state")
    elif record_type == "CLAUSE":
        if row["subjectID"] != row["requirementID"]:
            raise LedgerError("CLAUSE parent mismatch")
        if int(row["clauseEndByteExclusive"]) <= int(row["clauseStartByte"]):
            raise LedgerError("invalid clause span")
    elif record_type == "SOURCE":
        if row["requirementID"] == NULL:
            if row["subjectID"] != row["unitID"] or not UNIT_CLASS_RULES[row["unitClass"]]["allowsDirectSources"]:
                raise LedgerError("UNIT SOURCE provenance is only for evidence/introductory/mixed units")
        elif row["subjectID"] != row["requirementID"]:
            raise LedgerError("SOURCE requirement parent mismatch")
        validate_source_kind_admission(row["sourceKind"], row["admissionState"])
        validate_source_kind_field_rules(row)
        kind = row["sourceKind"]
        if kind == "scanRecord":
            validate_scan_source(row)
    elif record_type == "TARGET":
        if row["subjectID"] != row["requirementID"]:
            raise LedgerError("TARGET parent mismatch")
        validate_target_presence_rules(row)


def child_record_commitment(row: dict[str, str]) -> str:
    rule = CHILD_RECORD_RULES.get(row["recordType"])
    if rule is None:
        raise LedgerError("commitment requested for a non-child record")
    return typed_commitment(
        rule["commitmentDomain"],
        [row[field] for field in rule["commitmentPreimageFields"]],
    )


def clause_commitment(row: dict[str, str]) -> str:
    return child_record_commitment(row)


def source_binding_commitment(row: dict[str, str]) -> str:
    return child_record_commitment(row)


def target_commitment(row: dict[str, str]) -> str:
    return child_record_commitment(row)


def _normalize_clause(spec_data: bytes, unit: dict[str, object], clause: dict[str, str]) -> str:
    start = int(clause["clauseStartByte"])
    end = int(clause["clauseEndByteExclusive"])
    span = spec_data[start:end]
    if not span or span[0] in b"\t\n\v\f\r " or span[-1] in b"\t\n\v\f\r ":
        raise LedgerError("CLAUSE includes leading/trailing ASCII whitespace")
    if start == int(unit["startByte"]) and unit["anchorKind"] == "listLeader":
        marker = LIST_RE.match(span)
        if marker:
            span = span[marker.end():]
    try:
        text = unicodedata.normalize("NFC", span.decode("utf-8"))
    except UnicodeDecodeError as error:
        raise LedgerError("CLAUSE is not UTF-8") from error
    return ASCII_WHITESPACE_RE.sub(" ", text).strip(" ")


def requirement_semantic(spec_data: bytes, unit: dict[str, object], clauses: Sequence[dict[str, str]]) -> str:
    ordered = sorted(clauses, key=lambda row: int(row["clauseOrdinal"]))
    ordinals = [int(row["clauseOrdinal"]) for row in ordered]
    if ordinals != list(range(1, len(ordered) + 1)) or not ordered:
        raise LedgerError("requirement CLAUSE ordinals are not positive contiguous")
    payload = bytearray(b"qinao-design-requirement-semantic/v1\0")
    payload.extend(_lp_bytes(str(unit["unitID"])))
    payload.extend(struct.pack(">Q", len(ordered)))
    for clause in ordered:
        payload.extend(struct.pack(">Q", int(clause["clauseOrdinal"])))
        payload.extend(_lp_bytes(clause["clauseRole"]))
        payload.extend(_lp_bytes(_normalize_clause(spec_data, unit, clause)))
    return hashlib.sha256(payload).hexdigest()


def validate_requirement_state(
    requirement: dict[str, str],
    sources: Sequence[dict[str, str]],
    targets: Sequence[dict[str, str]],
) -> None:
    if not sources or not targets:
        raise LedgerError("REQUIREMENT must have SOURCE and TARGET children")
    validate_disposition_source_compatibility(requirement, sources)
    authority_states = set(AUTHORITY_ADMISSION_STATES)
    authority_sources = [source for source in sources if source["admissionState"] in authority_states]
    fully_governed = (
        requirement["disposition"] == "projectionOfControlledRequirement"
        and bool(authority_sources)
        and all(source["admissionState"] == "admittedControlled" for source in authority_sources)
        and all(
            target["executionState"] == "sourceGoverned"
            and target["governedOwner"] != NULL
            and target["governedWave"] in GOVERNED_WAVES
            and target["nonProductionClass"] == NULL
            and target["selectorPath"] != NULL
            and target["selectorID"] != NULL
            and target["pendingGateID"] == NULL
            for target in targets
        )
    )
    expected_state = "sourceGoverned" if fully_governed else "nonExecutable"
    if requirement["executionState"] != expected_state:
        raise LedgerError("REQUIREMENT executionState is not the least-permissive fold")
    if not fully_governed and any(target["executionState"] != "nonExecutable" for target in targets):
        raise LedgerError("non-governed REQUIREMENT has a sourceGoverned TARGET")
    for target in targets:
        missing_selector = target["selectorPath"] == NULL or target["selectorID"] == NULL
        if missing_selector:
            unknown_owner_shape = (
                target["executionState"] == "nonExecutable"
                and target["governedOwner"] == "design.admission"
                and target["governedWave"] == NULL
                and target["nonProductionClass"] == "admissionTask"
                and target["selectorPath"] == NULL
                and target["selectorID"] == NULL
                and target["pendingGateID"] != NULL
            )
            known_owner_shape = (
                target["executionState"] == "nonExecutable"
                and target["governedOwner"] != "design.admission"
                and target["governedWave"] in GOVERNED_WAVES
                and target["nonProductionClass"] == NULL
                and target["selectorPath"] == NULL
                and target["selectorID"] == NULL
                and target["pendingGateID"] != NULL
            )
            ncd_shape = requirement["disposition"] == "newControlDeltaPendingAdmission" and (unknown_owner_shape or known_owner_shape)
            operational_exception = (
                requirement["disposition"] == "operationalScanGate"
                and unknown_owner_shape
                and target["pendingGateID"] == "D0.supportedPrecreateObservationABI"
            )
            if not ncd_shape and not operational_exception:
                raise LedgerError("unresolved TARGET is not the exact admission placeholder")


def resolve_admission_state_expression(tokens: Iterable[str]) -> frozenset[str]:
    resolved: set[str] = set()
    for token in tokens:
        if token == AUTHORITY_SET_REFERENCE:
            resolved.update(AUTHORITY_ADMISSION_STATES)
        elif token in SOURCE_ADMISSION_KIND_COMPATIBILITY:
            resolved.add(token)
        else:
            raise LedgerError(f"unknown admission-state expression token: {token!r}")
    return frozenset(resolved)


def validate_disposition_source_compatibility(
    requirement: dict[str, str],
    sources: Sequence[dict[str, str]],
) -> None:
    if not sources:
        raise LedgerError("REQUIREMENT has no SOURCE")
    states = {source["admissionState"] for source in sources}
    disposition = requirement["disposition"]
    rule = DISPOSITION_SOURCE_RULES.get(disposition)
    if rule is None:
        raise LedgerError("unknown requirement disposition")
    required_states = resolve_admission_state_expression(rule["requiredAny"])
    allowed_states = resolve_admission_state_expression(rule["allowed"])
    if not states <= allowed_states or not states & required_states:
        raise LedgerError("disposition/SOURCE compatibility mismatch")
    expected_execution = rule["executionStateEquals"]
    if expected_execution is not None and requirement["executionState"] != expected_execution:
        raise LedgerError("non-projection disposition must be nonExecutable")


def row_commitment(row: dict[str, str]) -> str:
    if set(row) != set(HEADER):
        raise LedgerError("cannot commit row with wrong columns")
    return typed_commitment(ROW_DOMAIN, [row[field] for field in HEADER if field != "rowCommitment"])


def _selected_ordinal(row: dict[str, str]) -> int:
    child_rule = CHILD_RECORD_RULES.get(row["recordType"])
    if child_rule is None:
        return 0
    field = child_rule["ordinalField"]
    mapping = RECORD_SCALAR_FIELD_RULES.get(field)
    if not isinstance(mapping, dict):
        raise LedgerError(f"{field} scalar field rule is unavailable")
    positive_records = mapping.get("positiveRecords")
    if not isinstance(positive_records, (set, frozenset)):
        raise LedgerError(f"{field} positive scalar rule is unavailable")
    value = _validate_scalar_value(
        row[field],
        field,
        mapping,
        positive=row["recordType"] in positive_records,
    )
    if not isinstance(value, int):
        raise LedgerError(f"{field} scalar rule is not numeric")
    return value


def sort_rows(rows: Sequence[dict[str, str]]) -> list[dict[str, str]]:
    return sorted(
        rows,
        key=lambda row: (
            (
                CHILD_RECORD_RULES[row["recordType"]]["rank"]
                if row["recordType"] in CHILD_RECORD_RULES
                else RECORD_RANK[row["recordType"]]
            ),
            row["unitID"].encode("utf-8"),
            ("" if row["requirementID"] == NULL else row["requirementID"]).encode("utf-8"),
            _selected_ordinal(row),
            row["childID"].encode("utf-8"),
            row["subjectID"].encode("utf-8"),
        ),
    )


def ledger_root(rows: Sequence[dict[str, str]]) -> str:
    ordered = sort_rows(rows)
    raw = []
    for row in ordered:
        expected = row_commitment(row)
        if row["rowCommitment"] != expected:
            raise LedgerError(f"stale row commitment for {row['subjectID']}")
        raw.append(bytes.fromhex(expected))
    return hashlib.sha256(LEDGER_DOMAIN + struct.pack(">Q", len(raw)) + b"".join(raw)).hexdigest()


def _git_blob(data: bytes) -> str:
    return hashlib.sha1(b"blob " + str(len(data)).encode("ascii") + b"\0" + data).hexdigest()


def validate_frozen_spec_identity(spec_data: bytes, spec_path: str) -> dict[str, object]:
    identity = {
        "specSHA256": hashlib.sha256(spec_data).hexdigest(),
        "specBlob": _git_blob(spec_data),
        "specByteLength": len(spec_data),
        "specLineCount": len(spec_data.splitlines()),
    }
    if spec_path == SPEC_REL and identity != FROZEN_SPEC_IDENTITY:
        raise LedgerError("frozen specification identity drift")
    return identity


def semantic_set_root(member_domain: bytes, set_domain: bytes, members: Sequence[Sequence[str]]) -> str:
    digests = [hashlib.sha256(member_domain + b"".join(_lp_bytes(field) for field in member)).digest() for member in members]
    if len(set(digests)) != len(digests):
        raise LedgerError("duplicate semantic-set member")
    return hashlib.sha256(set_domain + struct.pack(">Q", len(digests)) + b"".join(sorted(digests))).hexdigest()


def _require_validated_projection_index(index: object) -> _ValidatedProjectionIndex:
    if type(index) is not _ValidatedProjectionIndex:
        raise LedgerError("semantic/provenance roots require a validated projection index")
    if type(index.units) is not tuple or type(index.requirements) is not tuple:
        raise LedgerError("validated projection index containers must be immutable tuples")
    unit_ids: set[str] = set()
    for unit in index.units:
        if type(unit) is not _ValidatedUnitProjection:
            raise LedgerError("invalid validated UNIT projection type")
        if any(type(value) is not str for value in unit[:3]) or type(unit.sources) is not tuple:
            raise LedgerError("invalid validated UNIT projection scalar/container type")
        if unit.unitID in unit_ids:
            raise LedgerError("duplicate validated UNIT projection")
        unit_ids.add(unit.unitID)
        if any(type(source) is not _SourceProjection for source in unit.sources):
            raise LedgerError("invalid validated SOURCE projection type")
        if any(type(value) is not str for source in unit.sources for value in source):
            raise LedgerError("invalid validated SOURCE projection scalar type")
        if len(unit.sources) != len(set(unit.sources)):
            raise LedgerError("duplicate provenance projection within subject")
    requirement_ids: set[str] = set()
    for requirement in index.requirements:
        if type(requirement) is not _ValidatedRequirementProjection:
            raise LedgerError("invalid validated REQUIREMENT projection type")
        if (
            any(type(value) is not str for value in requirement[:5])
            or type(requirement.sources) is not tuple
            or type(requirement.targets) is not tuple
        ):
            raise LedgerError("invalid validated REQUIREMENT projection scalar/container type")
        if requirement.requirementID in requirement_ids:
            raise LedgerError("duplicate validated REQUIREMENT projection")
        requirement_ids.add(requirement.requirementID)
        if requirement.unitID not in unit_ids:
            raise LedgerError("validated REQUIREMENT projection has no UNIT")
        if any(type(source) is not _SourceProjection for source in requirement.sources):
            raise LedgerError("invalid validated SOURCE projection type")
        if any(type(target) is not _TargetProjection for target in requirement.targets):
            raise LedgerError("invalid validated TARGET projection type")
        if (
            any(type(value) is not str for source in requirement.sources for value in source)
            or any(type(value) is not str for target in requirement.targets for value in target)
        ):
            raise LedgerError("invalid validated child projection scalar type")
        if (
            len(requirement.sources) != len(set(requirement.sources))
            or len(requirement.targets) != len(set(requirement.targets))
        ):
            raise LedgerError("duplicate provenance projection within subject")
    return index


def _semantic_set_summary_from_validated_index(index: object) -> dict[str, object]:
    validated = _require_validated_projection_index(index)
    unit_members = [(unit.unitID, unit.unitClass) for unit in validated.units]
    requirement_members = [
        (requirement.requirementID, requirement.unitID, requirement.requirementSemanticSHA256)
        for requirement in validated.requirements
    ]
    counts = Counter(unit_class for _, unit_class in unit_members)
    return {
        "unitClassSetCount": len(unit_members),
        "unitClassSetRoot": semantic_set_root(
            UNIT_CLASS_MEMBER_DOMAIN, UNIT_CLASS_SET_DOMAIN, unit_members
        ),
        "unitClassCounts": {
            name: counts[name]
            for name in ("normativeBearing", "evidence", "introductory", "mixed")
        },
        "requirementSemanticSetCount": len(requirement_members),
        "requirementSemanticSetRoot": semantic_set_root(
            REQUIREMENT_SEMANTIC_MEMBER_DOMAIN,
            REQUIREMENT_SEMANTIC_SET_DOMAIN,
            requirement_members,
        ),
    }


FROZEN_SEMANTIC_SET_PINS = {
    "unitClassSetCount": 325,
    "unitClassSetRoot": "3129b6e700aa67202d46688384d04d95ea0fb8cf43f5e9e0c8392a1a9eec1c70",
    "unitClassCounts": {"normativeBearing": 238, "evidence": 63, "introductory": 6, "mixed": 18},
    "requirementSemanticSetCount": 1127,
    "requirementSemanticSetRoot": "93e3fe0dec5c8837643b2b838773f921ea2a06ecde307438b6cdec24a40d2a23",
}

FROZEN_PROVENANCE_MAPPING_PINS = {
    "provenanceMappingUnitCount": 325,
    "provenanceMappingRequirementCount": 1127,
    "provenanceMappingRoot": "402ea7a7e903aa2054c4fcb16fb66b3b22ee1804f8165e5e1b31607e3a577d5e",
}


def validate_frozen_semantic_sets(index: object, spec_path: str) -> dict[str, object]:
    summary = _semantic_set_summary_from_validated_index(index)
    if spec_path == SPEC_REL and summary != FROZEN_SEMANTIC_SET_PINS:
        raise LedgerError("frozen UNIT-class/REQUIREMENT semantic set drift")
    return summary


def _provenance_source_projection(row: dict[str, str]) -> _SourceProjection:
    return _SourceProjection(*(row[field] for field in PROVENANCE_SOURCE_PROJECTION_FIELDS))


def _provenance_target_projection(row: dict[str, str]) -> _TargetProjection:
    return _TargetProjection(*(row[field] for field in PROVENANCE_TARGET_PROJECTION_FIELDS))


def _build_validated_projection_index(
    unit_rows: Sequence[dict[str, str]],
    requirements: dict[str, dict[str, str]],
    validated_direct_sources: dict[str, tuple[dict[str, str], ...]],
    validated_children: dict[tuple[str, str], tuple[dict[str, str], ...]],
    *,
    expected_source_count: int,
    expected_target_count: int,
) -> _ValidatedProjectionIndex:
    """Seal projections only from child tuples already accepted by verify_tsv."""
    unit_ids = {row["unitID"] for row in unit_rows}
    if set(validated_direct_sources) - unit_ids:
        raise LedgerError("validated direct SOURCE index has an unknown UNIT")
    relevant_child_keys = {
        key for key in validated_children if key[1] in {"SOURCE", "TARGET"}
    }
    expected_child_keys = {
        (requirement_id, kind)
        for requirement_id in requirements
        for kind in ("SOURCE", "TARGET")
    }
    if relevant_child_keys != expected_child_keys:
        raise LedgerError("validated requirement child projection index is incomplete")

    units = tuple(
        _ValidatedUnitProjection(
            row["unitID"],
            row["unitClass"],
            row["unitSemanticSHA256"],
            tuple(
                _provenance_source_projection(source)
                for source in validated_direct_sources.get(row["unitID"], ())
            ),
        )
        for row in unit_rows
    )
    requirement_projections = tuple(
        _ValidatedRequirementProjection(
            requirement_id,
            requirement["unitID"],
            requirement["requirementSemanticSHA256"],
            requirement["disposition"],
            requirement["executionState"],
            tuple(
                _provenance_source_projection(source)
                for source in validated_children[(requirement_id, "SOURCE")]
            ),
            tuple(
                _provenance_target_projection(target)
                for target in validated_children[(requirement_id, "TARGET")]
            ),
        )
        for requirement_id, requirement in requirements.items()
    )
    actual_source_count = sum(len(unit.sources) for unit in units) + sum(
        len(requirement.sources) for requirement in requirement_projections
    )
    actual_target_count = sum(
        len(requirement.targets) for requirement in requirement_projections
    )
    if actual_source_count != expected_source_count or actual_target_count != expected_target_count:
        raise LedgerError("validated provenance projection exact-consumption failure")
    return _require_validated_projection_index(
        _ValidatedProjectionIndex(units, requirement_projections)
    )


def _summarize_validated_projection_index(index: object) -> dict[str, object]:
    """Hash stable authority semantics; raw ledger rows are deliberately impossible here."""
    validated = _require_validated_projection_index(index)
    unit_digests: list[bytes] = []
    for unit in validated.units:
        payload = bytearray(PROVENANCE_UNIT_MEMBER_DOMAIN)
        payload.extend(_lp_bytes(unit.unitID))
        payload.extend(_lp_bytes(unit.unitSemanticSHA256))
        payload.extend(struct.pack(">Q", len(unit.sources)))
        for source in unit.sources:
            payload.extend(b"".join(_lp_bytes(field) for field in source))
        unit_digests.append(hashlib.sha256(payload).digest())

    requirement_digests: list[bytes] = []
    for requirement in validated.requirements:
        payload = bytearray(PROVENANCE_REQUIREMENT_MEMBER_DOMAIN)
        for field in (
            requirement.requirementID,
            requirement.unitID,
            requirement.requirementSemanticSHA256,
            requirement.disposition,
            requirement.executionState,
        ):
            payload.extend(_lp_bytes(field))
        payload.extend(struct.pack(">Q", len(requirement.sources)))
        for source in requirement.sources:
            payload.extend(b"".join(_lp_bytes(field) for field in source))
        payload.extend(struct.pack(">Q", len(requirement.targets)))
        for target in requirement.targets:
            payload.extend(b"".join(_lp_bytes(field) for field in target))
        requirement_digests.append(hashlib.sha256(payload).digest())
    if (
        len(set(unit_digests)) != len(unit_digests)
        or len(set(requirement_digests)) != len(requirement_digests)
    ):
        raise LedgerError("duplicate provenance mapping member")
    root = hashlib.sha256(
        PROVENANCE_MAPPING_SET_DOMAIN
        + struct.pack(">Q", len(unit_digests))
        + b"".join(sorted(unit_digests))
        + struct.pack(">Q", len(requirement_digests))
        + b"".join(sorted(requirement_digests))
    ).hexdigest()
    return {
        "provenanceMappingUnitCount": len(unit_digests),
        "provenanceMappingRequirementCount": len(requirement_digests),
        "provenanceMappingRoot": root,
    }


def validate_frozen_provenance_mapping(index: object, spec_path: str) -> dict[str, object]:
    summary = _summarize_validated_projection_index(index)
    if spec_path == SPEC_REL and summary != FROZEN_PROVENANCE_MAPPING_PINS:
        raise LedgerError("frozen provenance mapping set drift")
    return summary


def _parse_tsv(data: bytes) -> list[dict[str, str]]:
    if data.startswith(b"\xef\xbb\xbf") or b"\r" in data or b"\x00" in data or not data.endswith(b"\n"):
        raise LedgerError("ledger must be UTF-8, LF-terminated, no BOM/CR/NUL")
    try:
        text = data.decode("utf-8")
    except UnicodeDecodeError as error:
        raise LedgerError("ledger is not UTF-8") from error
    # HeaderV1 is byte-canonical LF TSV.  Unicode splitlines() recognizes VT,
    # FF, U+0085, U+2028, and U+2029 as line boundaries and would therefore
    # accept non-LF record separators while rejecting those bytes inside cells.
    lines = text[:-1].split("\n")
    if not lines or tuple(lines[0].split("\t")) != HEADER:
        raise LedgerError("TSV header does not exactly match v1")
    rows = []
    for line_number, line in enumerate(lines[1:], 2):
        cells = line.split("\t")
        if len(cells) != len(HEADER):
            raise LedgerError(f"line {line_number} has {len(cells)} fields")
        row = dict(zip(HEADER, cells, strict=True))
        validate_row_shape(row)
        rows.append(row)
    if rows != sort_rows(rows):
        raise LedgerError("TSV data rows are not in canonical order")
    return rows


def _validate_child(
    parent: dict[str, str],
    children: Sequence[dict[str, str]],
    kind: str,
) -> tuple[dict[str, str], ...]:
    rule = CHILD_RECORD_RULES.get(kind)
    if rule is None:
        raise LedgerError("unknown child record topology")
    ordinal_field = rule["ordinalField"]
    commit_field = rule["commitmentField"]
    count_field = rule["parentCountField"]
    root_field = rule["parentRootField"]
    domain = rule["setDomain"]
    ordered = tuple(sorted(children, key=lambda row: (int(row[ordinal_field]), row["childID"])))
    ordinals = [int(row[ordinal_field]) for row in ordered]
    if ordinals != list(range(1, len(ordered) + 1)):
        raise LedgerError(f"{kind} ordinals are not contiguous for {parent['subjectID']}")
    if int(parent[count_field]) != len(ordered):
        raise LedgerError(f"{kind} child count mismatch for {parent['subjectID']}")
    root = child_set_root(domain, [row[commit_field] for row in ordered])
    if parent[root_field] != root:
        raise LedgerError(f"{kind} child root mismatch for {parent['subjectID']}")
    return ordered


def validate_unit_class_consistency(rows: Sequence[dict[str, str]]) -> None:
    unit_classes: dict[str, str] = {}
    for row in rows:
        if row["recordType"] == "UNIT":
            if row["unitID"] in unit_classes:
                raise LedgerError(f"duplicate UNIT row {row['unitID']}")
            unit_classes[row["unitID"]] = row["unitClass"]
    for row in rows:
        expected = unit_classes.get(row["unitID"])
        if expected is not None and row["unitClass"] != expected:
            raise LedgerError(f"conflicting unitClass for {row['unitID']}")


def validate_requirement_child_parent(child: dict[str, str], parent: dict[str, str]) -> None:
    if child.get("recordType") not in CHILD_RECORD_RULES:
        raise LedgerError("invalid requirement child record type")
    if (
        child.get("requirementID") != parent.get("requirementID")
        or child.get("unitID") != parent.get("unitID")
        or child.get("unitClass") != parent.get("unitClass")
    ):
        raise LedgerError("requirement child UNIT/class parent mismatch")


def validate_clause_overlaps(clauses: Sequence[dict[str, str]]) -> None:
    """Reject forbidden within-REQUIREMENT overlaps in O(n log n) time."""
    ordered = sorted(
        clauses,
        key=lambda row: (int(row["clauseStartByte"]), int(row["clauseEndByteExclusive"])),
    )
    max_end_any = -1
    max_end_assertion = -1
    for row in ordered:
        start = int(row["clauseStartByte"])
        end = int(row["clauseEndByteExclusive"])
        if row["clauseRole"] == "sharedContext":
            if max_end_assertion > start:
                raise LedgerError("unlabeled overlapping CLAUSE spans")
        elif max_end_any > start:
            raise LedgerError("unlabeled overlapping CLAUSE spans")
        max_end_any = max(max_end_any, end)
        if row["clauseRole"] != "sharedContext":
            max_end_assertion = max(max_end_assertion, end)


def validate_identifier_registries(rows: Sequence[dict[str, str]]) -> None:
    """Enforce ledger-wide source, selector, and pending-gate identity semantics."""
    requirement_dispositions = {
        row["requirementID"]: row["disposition"]
        for row in rows
        if row["recordType"] == "REQUIREMENT"
    }
    source_identities: dict[str, tuple[str, ...]] = {}
    selector_paths: dict[str, str] = {}
    pending_gate_scopes: dict[str, tuple[str, str, str, str, str]] = {}
    for row in rows:
        if row["recordType"] == "SOURCE":
            identity = tuple(row[field] for field in SOURCE_FIELDS[3:])
            previous = source_identities.setdefault(row["sourceID"], identity)
            if previous != identity:
                raise LedgerError("sourceID reused for a different immutable identity")
        elif row["recordType"] == "TARGET":
            if row["selectorID"] != NULL:
                previous_path = selector_paths.setdefault(row["selectorID"], row["selectorPath"])
                if previous_path != row["selectorPath"]:
                    raise LedgerError("selectorID reused for a different selector path")
            if row["pendingGateID"] != NULL:
                disposition = requirement_dispositions.get(row["requirementID"])
                if disposition is None:
                    raise LedgerError("pendingGateID has no parent disposition")
                scope = (
                    disposition,
                    *(row[field] for field in (
                        "governedOwner", "governedWave", "nonProductionClass", "executionState",
                    )),
                )
                previous_scope = pending_gate_scopes.setdefault(row["pendingGateID"], scope)
                if previous_scope != scope:
                    raise LedgerError("pendingGateID reused across semantic scopes")


def verify_tsv(spec_data: bytes, ledger_data: bytes, spec_path: str) -> dict[str, object]:
    if spec_path != SPEC_REL:
        raise LedgerError("official verifier is purpose-bound to the exact SPEC_REL identity")
    units = extract_markdown_units(spec_data, spec_path)
    named_contracts = validate_named_contracts(spec_data, spec_path, units=units)
    frozen_identity = validate_frozen_spec_identity(spec_data, spec_path)
    rows = _parse_tsv(ledger_data)
    by_unit = {unit["unitID"]: unit for unit in units}
    spec_sha = hashlib.sha256(spec_data).hexdigest()
    spec_blob = _git_blob(spec_data)
    spec_lines = len(spec_data.splitlines())

    unit_rows = [row for row in rows if row["recordType"] == "UNIT"]
    if len(unit_rows) != len(units) or {row["unitID"] for row in unit_rows} != set(by_unit):
        raise LedgerError("UNIT forward/reverse completeness failure")
    if len({row["unitID"] for row in unit_rows}) != len(unit_rows):
        raise LedgerError("duplicate UNIT rows")
    validate_unit_class_consistency(rows)

    for row in rows:
        unit = by_unit.get(row["unitID"])
        if unit is None:
            raise LedgerError(f"row references unknown unit {row['unitID']}")
        expected = {
            "specPath": spec_path,
            "specBlob": spec_blob,
            "specByteLength": str(len(spec_data)),
            "specLineCount": str(spec_lines),
            "specSHA256": spec_sha,
            "headingPath": unit["headingPath"],
            "anchorLocator": unit["anchorLocator"],
            "unitStartByte": str(unit["startByte"]),
            "unitEndByteExclusive": str(unit["endByteExclusive"]),
            "unitStartLine": str(unit["startLine"]),
            "unitEndLine": str(unit["endLine"]),
            "unitSpanSHA256": unit["spanSHA256"],
            "unitSemanticSHA256": unit["semanticSHA256"],
        }
        for field, value in expected.items():
            if row[field] != value:
                raise LedgerError(f"stale {field} for {row['subjectID']}")
        if row["rowCommitment"] != row_commitment(row):
            raise LedgerError(f"stale row commitment for {row['subjectID']}")

    requirements = {row["requirementID"]: row for row in rows if row["recordType"] == "REQUIREMENT"}
    if len(requirements) != sum(row["recordType"] == "REQUIREMENT" for row in rows):
        raise LedgerError("duplicate REQUIREMENT IDs")
    children: dict[tuple[str, str], list[dict[str, str]]] = defaultdict(list)
    evidence_sources: dict[str, list[dict[str, str]]] = defaultdict(list)
    validated_children: dict[tuple[str, str], tuple[dict[str, str], ...]] = {}
    validated_direct_sources: dict[str, tuple[dict[str, str], ...]] = {}
    seen_child_ids: set[str] = set()

    for row in rows:
        record_type = row["recordType"]
        child_rule = CHILD_RECORD_RULES.get(record_type)
        if child_rule is not None:
            if row["childID"] in seen_child_ids:
                raise LedgerError(f"duplicate childID {row['childID']}")
            seen_child_ids.add(row["childID"])
            expected = child_record_commitment(row)
            if (
                row[child_rule["commitmentField"]] != expected
                or row["childID"] != child_rule["childIDPrefix"] + expected[:24]
            ):
                raise LedgerError(f"invalid {record_type} commitment/ID")
        if record_type == "CLAUSE":
            start, end = int(row["clauseStartByte"]), int(row["clauseEndByteExclusive"])
            unit = by_unit[row["unitID"]]
            if start < int(unit["startByte"]) or end > int(unit["endByteExclusive"]):
                raise LedgerError("CLAUSE span escapes parent UNIT")
            if hashlib.sha256(spec_data[start:end]).hexdigest() != row["clauseSHA256"]:
                raise LedgerError("CLAUSE span hash mismatch")
            if row["requirementID"] not in requirements:
                raise LedgerError("CLAUSE references unknown REQUIREMENT")
            validate_requirement_child_parent(row, requirements[row["requirementID"]])
            children[(row["requirementID"], "CLAUSE")].append(row)
        elif record_type == "SOURCE":
            if row["requirementID"] == NULL:
                evidence_sources[row["unitID"]].append(row)
            else:
                if row["requirementID"] not in requirements:
                    raise LedgerError("SOURCE references unknown REQUIREMENT")
                validate_requirement_child_parent(row, requirements[row["requirementID"]])
                children[(row["requirementID"], "SOURCE")].append(row)
        elif record_type == "TARGET":
            if row["requirementID"] not in requirements:
                raise LedgerError("TARGET references unknown REQUIREMENT")
            validate_requirement_child_parent(row, requirements[row["requirementID"]])
            children[(row["requirementID"], "TARGET")].append(row)

    validate_identifier_registries(rows)

    requirements_by_unit: dict[str, list[dict[str, str]]] = defaultdict(list)
    for requirement_id, requirement in requirements.items():
        if not UNIT_CLASS_RULES[requirement["unitClass"]]["allowsRequirements"]:
            raise LedgerError("REQUIREMENT parent UNIT is not normative-bearing")
        requirements_by_unit[requirement["unitID"]].append(requirement)
        for kind in ("CLAUSE", "SOURCE", "TARGET"):
            validated_children[(requirement_id, kind)] = _validate_child(
                requirement, children[(requirement_id, kind)], kind
            )
        requirement_sources = validated_children[(requirement_id, "SOURCE")]
        requirement_targets = validated_children[(requirement_id, "TARGET")]
        validate_requirement_state(
            requirement,
            requirement_sources,
            requirement_targets,
        )

        clauses = validated_children[(requirement_id, "CLAUSE")]
        if not any(clause["clauseRole"] == "assertion" for clause in clauses):
            raise LedgerError("REQUIREMENT has no assertion CLAUSE")
        semantic = requirement_semantic(
            spec_data, by_unit[requirement["unitID"]], clauses
        )
        if requirement["requirementSemanticSHA256"] != semantic or requirement_id != "QRS-" + semantic[:24]:
            raise LedgerError("REQUIREMENT semantic digest/ID mismatch")
        validate_clause_overlaps(clauses)

    for unit_row in unit_rows:
        unit_id = unit_row["unitID"]
        unit_requirements = requirements_by_unit[unit_id]
        class_rule = UNIT_CLASS_RULES[unit_row["unitClass"]]
        if class_rule["requiresRequirements"] and not unit_requirements:
            raise LedgerError(f"normative UNIT has no REQUIREMENT: {unit_id}")
        if unit_requirements and not class_rule["allowsRequirements"]:
            raise LedgerError("evidence/introductory UNIT cannot carry REQUIREMENT authority")
        if class_rule["allowsDirectSources"]:
            validated_direct_sources[unit_id] = _validate_child(
                unit_row, evidence_sources[unit_id], "SOURCE"
            )
        elif evidence_sources[unit_id]:
            raise LedgerError("normativeBearing UNIT cannot use direct SOURCE provenance")
        elif unit_row["sourceBindingCount"] != "0" or unit_row["sourceBindingRoot"] != child_set_root(SOURCE_SET_DOMAIN, []):
            raise LedgerError("normativeBearing UNIT requires the empty direct SOURCE set")
        else:
            validated_direct_sources[unit_id] = ()

    root = ledger_root(rows)
    projection_index = _build_validated_projection_index(
        unit_rows,
        requirements,
        validated_direct_sources,
        validated_children,
        expected_source_count=sum(row["recordType"] == "SOURCE" for row in rows),
        expected_target_count=sum(row["recordType"] == "TARGET" for row in rows),
    )
    semantic_sets = validate_frozen_semantic_sets(projection_index, spec_path)
    provenance_mapping = validate_frozen_provenance_mapping(projection_index, spec_path)
    return {
        "ok": True,
        "specPath": spec_path,
        "specSHA256": spec_sha,
        "specBlob": spec_blob,
        "unitCount": len(units),
        "requirementCount": len(requirements),
        "dataRowCount": len(rows),
        "rowRoot": root,
        "fileSHA256": hashlib.sha256(ledger_data).hexdigest(),
        **named_contracts,
        **semantic_sets,
        **provenance_mapping,
        **frozen_identity,
    }


def _extract_report(spec_path: Path) -> dict[str, object]:
    data = spec_path.read_bytes()
    units = extract_markdown_units(data, str(spec_path))
    return {
        "specPath": str(spec_path),
        "specSHA256": hashlib.sha256(data).hexdigest(),
        "specBlob": _git_blob(data),
        "byteLength": len(data),
        "lineCount": len(data.splitlines()),
        "unitCount": len(units),
        "kindCounts": dict(sorted(Counter(unit["anchorKind"] for unit in units).items())),
        "units": units,
    }


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)
    extract_parser = subparsers.add_parser("extract", help="extract and report frozen Markdown units")
    extract_parser.add_argument("spec")
    verify_parser = subparsers.add_parser("verify", help="verify a source-disposition TSV")
    verify_parser.add_argument("spec")
    verify_parser.add_argument("ledger")
    verify_parser.add_argument("--spec-path", dest="spec_path_identity")
    args = parser.parse_args(argv)
    try:
        if args.command == "extract":
            result = _extract_report(Path(args.spec))
        else:
            spec = Path(args.spec)
            ledger = Path(args.ledger)
            result = verify_tsv(
                spec.read_bytes(),
                ledger.read_bytes(),
                args.spec_path_identity or str(spec),
            )
    except (OSError, LedgerError, UnicodeError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 2
    print(json.dumps(result, ensure_ascii=False, sort_keys=True, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
