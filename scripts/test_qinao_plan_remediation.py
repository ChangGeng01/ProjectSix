from __future__ import annotations

import ast
import hashlib
import re
import shlex
import subprocess
import unittest
from collections import Counter
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PLAN_DIRECTORY = ROOT / "docs/superpowers/plans"
MASTER = (
    ROOT
    / "docs/superpowers/plans/"
    / "2026-07-29-qinao-dual-space-automation-controlled-convergence.md"
)
ORDER_MASTER = (
    PLAN_DIRECTORY / "2026-07-15-iphone-air-architecture-convergence-master.md"
)
SUPERSEDED_CONVERGENCE_PLANS = (
    PLAN_DIRECTORY / "2026-07-19-qinao-coreai-agent-controlled-document-convergence.md",
    PLAN_DIRECTORY / "2026-07-23-qinao-artifact-mesh-w1-task0.md",
    PLAN_DIRECTORY / "2026-07-23-qinao-authority-ledger-and-cw-evidence.md",
    PLAN_DIRECTORY / "2026-07-23-qinao-bootstrap-verifier-and-admission-lineage.md",
    PLAN_DIRECTORY / "2026-07-23-qinao-c0-provenance-and-safe-import.md",
    PLAN_DIRECTORY
    / "2026-07-23-qinao-clean-candidate-reconstruction-and-controlled-convergence.md",
    PLAN_DIRECTORY / "2026-07-23-qinao-w0-safety-and-k4-proof.md",
)
SUPERSEDED_SENTINEL = "SUPERSEDED; HISTORICAL; DO NOT EXECUTE; GRANTS NO AUTHORITY"
PLAN_REGISTRY_MARKER = re.compile(
    r"^> \*\*QINAO-PLAN-REGISTRY-V1: ([A-Z0-9_]+)\*\*$",
    flags=re.MULTILINE,
)
PLAN_REGISTRY_HEADER_CANDIDATE = re.compile(
    r"^> .*QINAO-PLAN-REGISTRY-V1:.*$",
    flags=re.MULTILINE,
)
ORDER_MASTER_CLASS = "ORDER_MASTER"
ACTIVE_ANNEX_CLASS = "ACTIVE_TASKS_0_2_ANNEX"
SUPERSEDED_CLASS = "SUPERSEDED_HISTORICAL"
ORDER_MASTER_WITHOUT_REGISTRY_MARKER_SHA256 = (
    "e6c520e12557e8a11d59797649e2189f14a4e5d0bf7dfa204e742d1338945507"
)
SUPERSEDED_PLAN_REMAINDER_SHA256 = {
    "2026-07-19-qinao-coreai-agent-controlled-document-convergence.md": "4e806b50955732be63ad5b97f2d0b5e6e57bd5ea59a96ae371686f921da60100",
    "2026-07-23-qinao-artifact-mesh-w1-task0.md": "5c977a50b86c0a8b7f71c4d97ae5168c0c54072b96ef3fb0a3155f8f330ab813",
    "2026-07-23-qinao-authority-ledger-and-cw-evidence.md": "28a17463705898fd41eb8c9bc54a3bf0978fa2891aad64eb2c0614c75d398c12",
    "2026-07-23-qinao-bootstrap-verifier-and-admission-lineage.md": "0443f8b5a578858444366bef94119e0dbf36194e06a9ce12c8a094853d2b8841",
    "2026-07-23-qinao-c0-provenance-and-safe-import.md": "5fb9c4e779164e4d43eb74d12b1a76bd6da54d472f6e66f5d3844f3f01d22605",
    "2026-07-23-qinao-clean-candidate-reconstruction-and-controlled-convergence.md": "74d3d5428caefe976b42cc04917addb754edb75928a85aa28b0b20a10c37b60d",
    "2026-07-23-qinao-w0-safety-and-k4-proof.md": "faff13be25c142dd8bd6510648744d678e8921db889299964da001d801e2d897",
}
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
NONEMPTY_XCODE = ROOT / "scripts/run_nonempty_xcode_test.py"
IOS27_FLOOR = ROOT / "BehavioralAISubstrate/scripts/check-ios27-floor.sh"
QINAO_PACKAGE = ROOT / "QinaoRuntimeSDK/Package.swift"
QINAO_TEST_DIRECTORY = ROOT / "QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests"
ORDINARY_WORKFLOW = ROOT / ".github/workflows/test.yml"
PROTECTED_WORKFLOW = ROOT / ".github/workflows/qinao-wave-admission.yml"
WORKFLOW_META_TEST = ROOT / "scripts/test_test_workflow_owner_ledger.py"
SOURCE_REVIEW_LEDGER_START = "#### QINAO-SOURCE-REVIEW-CLOSURE-V1"
SOURCE_REVIEW_LEDGER_END = "#### END QINAO-SOURCE-REVIEW-CLOSURE-V1"
SOURCE_REVIEW_IDS = {
    *(f"SR-B{ordinal:02d}" for ordinal in range(1, 12)),
    *(f"SR-M{ordinal:02d}" for ordinal in range(1, 12)),
    *(f"SR-m{ordinal:02d}" for ordinal in range(1, 18)),
}
GOVERNED_XCODE_PROJECT = "scripts/run_governed_xcode_project.py"
GOVERNED_XCODE_PROJECT_TEST = "scripts/test_run_governed_xcode_project.py"
NO_LANGUAGE_SURVIVAL_SENTINELS = (
    "BehavioralAISubstrateTests.BASProposalEngineContractTests/"
    "testCandidateKindsAreExactClosedAndModelIsNotPrivileged",
    "BehavioralAISubstrateTests.BASStructuredContextPacketTests/"
    "testCanonicalPacketContainsNoPromptTokensProviderMaterialOrPrivateKV",
    "BehavioralAISubstrateTests.BASAutomationDefinitionContractTests/"
    "testSignedStructuredDefinitionAcceptsHumanUIOrImporterWithoutNaturalLanguageProducer",
    "BehavioralAISubstrateTests.BASSemanticStateMarketTests/"
    "testR5GroundingBranchesAreClosedAndEligibilityIsBranchExact",
    "BehavioralAISubstrateTests.BASSemanticStateMarketTests/"
    "testR6ValidatesMatchingTypedReceiptAndRequiresProviderReceiptOnlyForModel",
    "BehavioralAISubstrateTests.BASProposalEngineAdapterTests/"
    "testAllCandidateKindsShareOneContractAndOnlyModelAllocatesProvider",
    "BehavioralAISubstrateTests.BASZeroModelSurvivalE2ETests/"
    "testStructuredInputThroughRecoveryUsesZeroProviderAllocationCallStepOrPrivateKV",
    "BehavioralAISubstrateTests.BASZeroModelSurvivalE2ETests/"
    "testOpenNaturalLanguageWithoutProducerReturnsTypedExternalProducerRequired",
    "BehavioralAISubstrateTests.BASDelegationSlotContractTests/"
    "testDelegationProposalOriginRequiresProviderExecutionRefOnlyForModel",
    "BehavioralAISubstrateTests.BASProposalEngineAdapterTests/"
    "testPostCompileInputsAreKindTaggedAndNonModelMaterializationIsTokenless",
    "BehavioralAISubstrateTests.BASProposalEngineContractTests/"
    "testCapabilityProfilesHaveExactCandidateGroundingAndAvailabilityMatrices",
    "BehavioralAISubstrateTests.BASSemanticStateMarketTests/"
    "testNoLanguageInferenceRequiresTypedR4AndR5DispositionReceipts",
    "BehavioralAISubstrateTests.BASZeroModelSurvivalE2ETests/"
    "testSuperstepSevenObservationIsBranchExactAndProviderRefIsModelOnly",
    "BehavioralAISubstrateTests.BASSemanticStateMarketTests/"
    "testTokenCostIsModelNeutralBeforeElectionAndProviderExactAfterModelElection",
    "BehavioralAISubstrateTests.BASModelBoundaryPinTests/"
    "testModelErasedCoreDependencyClosureCleanBuildsWithoutLanguageModelAssetsOrProviders",
    "BehavioralAISubstrateTests.BASProposalEngineContractTests/"
    "testCapabilityProfilesUseCanonicalKindsAndRequireTypedMechanismProofs",
    "BehavioralAISubstrateTests.BASSemanticTurnDAGTests/"
    "testSuperstepSevenRejectsProfileWorkCandidateAndMechanismProofMismatch",
    "BehavioralAISubstrateTests.BASProposalEngineAdapterTests/"
    "testNonModelPlanIsContainedModelFreeAndWorldModelSearchBindsBothCausalEdges",
    "BehavioralAISubstrateTests.BASModelBoundaryPinTests/"
    "testPhysicalProfilesRejectForbiddenCapabilitiesAndPermitOnlyProvedFrameworkSymbols",
    "BehavioralAISubstrateTests.BASZeroModelSurvivalE2ETests/"
    "testNoGenerativeProviderProfileCompletesDeterministicallyAndNeverWaitsForModel",
    "BehavioralAISubstrateTests.BASZeroModelSurvivalE2ETests/"
    "testNoLanguageInferenceProfileRejectsLanguageMechanismsAndResumesAfterInterruption",
    "BehavioralAISubstrateTests.BASZeroModelSurvivalE2ETests/"
    "testNoLearnedInferenceProfileUsesOnlyDeterministicOrStructuredExternalMechanismsThroughRecovery",
    "BehavioralAISubstrateTests.BASContextClassifierMLAdapterTests/"
    "testModelNeutralContractIsExactAndAdapterConformsAfterResourceMove",
    "BehavioralAISubstrateTests.BASContextClassifierMLAdapterTests/"
    "testClassifierBuildRecipesUseAppleAdaptersProcessedResource",
    "BehavioralAISubstrateTests.BASMLContextServiceFailureModeTests/"
    "testThrowingClassifierUsesHonestFailureFallback",
    "BehavioralAISubstrateTests.BASCognitiveBrainProbabilityDistributionTests/"
    "testAppleClassifierFactoryUsesOneClassifierForBothPresetsAndProbabilitySideChannel",
)

RESILIENCE_HARDENING_SENTINELS = (
    "BehavioralAISubstrateTests.BASRetentionContractTests/"
    "testSixClassesTaggedHorizonsAndRecoveryMinimumAreExact",
    "BehavioralAISubstrateTests.BASContinuationCheckpointContractTests/"
    "testCheckpointWiresUseThreeOwnerRefsCanonicalBudgetEvidenceAndCacheIsNeverTruth",
    "BehavioralAISubstrateTests.BASAgentContextIsolationContractTests/"
    "testAttentionReentryProjectionIsReceiptDerivedAndContentFree",
    "BehavioralAISubstrateTests.BASAgentContextIsolationContractTests/"
    "testInquiryBranchPinsMainReadSetAndEachMessageIsUserDurable",
    "BehavioralAISubstrateTests.BASAgentContextIsolationContractTests/"
    "testPersonaSourceCardWireIsSourceBoundPresentationOnly",
    "QinaoRuntimeSDKTests.QinaoProviderBoundaryTests/"
    "testQinaoSDKContainsNoConcreteProviderRuntime",
    "BehavioralAISubstrateTests.BASAutomationK3LifecycleTests/"
    "testMissionPlanRootCASCommitsBeforeAnyExecutableAllocation",
    "BehavioralAISubstrateTests.BASAutomationK3LifecycleTests/"
    "testInquiryMessageAppendRequiresCurrentPerMessageUserDurableAdmissionAndOwnHeadCAS",
    "BehavioralAISubstrateTests.BASAutomationCheckpointStorageTests/"
    "testCheckpointInstallReopensCanonicalRetentionAndBudgetZeroOrLatestUse",
    "BehavioralAISubstrateTests.BASRetentionDispositionTests/"
    "testRecoveryAndUserDurableImmediateOverridesFenceBodiesWithoutRoutineEarlyPrune",
    "BehavioralAISubstrateTests.BASSemanticSnapshotCoordinatorTests/"
    "testEveryCommittedTurnAdvancesBoundedMaintenanceBeforeNextAttemptCompilation",
    "BehavioralAISubstrateTests.BASSemanticSnapshotCoordinatorTests/"
    "testAttentionReentryReconstructsCurrentWorkFromReopenedEvidenceOnly",
    "BehavioralAISubstrateTests.BASAgentContextIsolationContractTests/"
    "testWebPersonaCardFallsBackNeutralOnConflictAndCannotChangeVerifiedFacts",
    "BehavioralAISubstrateTests.BASProviderFallbackDeterminismTests/"
    "testPCCAdapterUsesExplicitPrivateCloudModelPerAttemptAndNeverSystemDefault",
    "BehavioralAISubstrateTests.BASProviderFallbackDeterminismTests/"
    "testInquiryGrantIsReadPresentationOnlyAndPromotionStartsNewMainAttempt",
    "BehavioralAISubstrateTests.BASAutomationBoundaryRecoveryTests/"
    "testDurableCommandReopensTranscriptAndQueriesSameInvocationWithoutRedispatch",
    "BehavioralAISubstrateTests.AppleSurfaceArchitectureGateTests/"
    "testBorrowedCapabilitiesMapToTypedIngressReadOrZoneCEdgesAndNeverAgents",
    "BehavioralAISubstrateTests.BASEffectSagaCrashMatrixTests/"
    "testPersonaResearchUsesBoundedExplicitWebEffectAndOnlyFeedsLaterAttempt",
    "BehavioralAISubstrateTests.BASToolDispatcherTests/"
    "testProductionHandlerMapIsImmutableDuplicateRejectingAndDigestBound",
    "BehavioralAISubstrateTests.BASToolCallingPlannerTests/"
    "testPlannerReturnsDeferredToolProposalAndNeverDispatches",
    "BehavioralAISubstrateTests.BASGatedToolLoopE2ETests/"
    "testToolProposalReentersThroughOneBrokerAdapterPath",
    "BehavioralAISubstrateTests.BASAppleMutationSingleCallerTests/"
    "testNoProductionDispatcherReferenceExistsOutsideToolEffectAdapter",
)


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


def strict_shell_argv(command: str) -> list[str]:
    if "$(" in command or "`" in command:
        raise AssertionError(f"command substitution is forbidden: {command}")
    lexer = shlex.shlex(command, posix=True, punctuation_chars=";&|<>")
    lexer.whitespace_split = True
    lexer.commenters = ""
    argv = list(lexer)
    shell_controls = {";", "&", "&&", "|", "||", "<", "<<", ">", ">>"}
    controls = [token for token in argv if token in shell_controls]
    if controls:
        raise AssertionError(
            f"shell control tokens are forbidden: {controls}: {command}"
        )
    return argv


def direct_runner_argv(command: str, script: str) -> list[str]:
    argv = strict_shell_argv(command)
    if len(argv) < 3:
        raise AssertionError(f"incomplete runner command: {command}")
    allowed_python = re.fullmatch(r"\$QINAO_[A-Z0-9_]+_PROTECTED_PYTHON", argv[0])
    if not allowed_python or argv[1] != script:
        raise AssertionError(f"runner is not the direct executable argv: {command}")
    return argv


def option_values(argv: list[str], option: str) -> list[str]:
    values: list[str] = []
    for index, token in enumerate(argv):
        if token != option:
            continue
        if index + 1 >= len(argv) or argv[index + 1].startswith("--"):
            raise AssertionError(f"missing value for {option}: {argv}")
        values.append(argv[index + 1])
    return values


def validate_closed_runner_options(
    argv: list[str],
    *,
    singleton_options: set[str],
    repeatable_options: set[str],
) -> None:
    forbidden = {"-h", "--help", "--version", "--"}
    allowed = singleton_options | repeatable_options
    seen: dict[str, int] = {option: 0 for option in allowed}
    index = 2
    while index < len(argv):
        option = argv[index]
        if option in forbidden or option not in allowed:
            raise AssertionError(f"unexpected runner option {option!r}: {argv}")
        if index + 1 >= len(argv) or argv[index + 1].startswith("--"):
            raise AssertionError(f"missing value for {option}: {argv}")
        seen[option] += 1
        index += 2
    missing = sorted(option for option in singleton_options if seen[option] != 1)
    duplicated = sorted(option for option in singleton_options if seen[option] > 1)
    if missing or duplicated:
        raise AssertionError(
            f"invalid singleton runner options missing={missing} duplicated={duplicated}: {argv}"
        )


def naked_shell_tool_matches(contents: str, tool_names: set[str]) -> list[str]:
    alternation = "|".join(re.escape(name) for name in sorted(tool_names))
    pattern = re.compile(
        rf"(?<![A-Za-z0-9_./$-])(?:{alternation})(?=\s|$)",
    )
    matches: list[str] = []
    for block in fenced_shell_blocks(contents):
        # A shell removes a backslash-newline before tokenization, including
        # when the continuation splits a command name (for example xc\ + run).
        lexically_joined = re.sub(r"\\\r?\n[ \t]*", "", block)
        for command in logical_shell_commands(lexically_joined):
            if pattern.search(command):
                matches.append(command)
    return matches


def required_test_selectors(contents: str) -> list[str]:
    return [
        test_id
        for block in fenced_shell_blocks(contents)
        for command in logical_shell_commands(block)
        if "scripts/run_nonempty_swift_filter.py" in command
        for test_id in re.findall(
            r"--require-test\s+"
            r"([A-Za-z_][A-Za-z0-9_.]*/[A-Za-z_][A-Za-z0-9_]*)",
            command,
        )
    ]


def required_regex_group(pattern: str, value: str, label: str) -> str:
    match = re.search(pattern, value)
    if match is None:
        raise AssertionError(f"missing {label}: {value!r}")
    return match.group(1)


def source_review_regression_prefix(finding_id: str) -> str:
    match = re.fullmatch(r"SR-([BMm])[0-9]{2}", finding_id)
    if match is None:
        raise AssertionError(f"invalid source-review finding ID: {finding_id!r}")
    return {"B": "b", "M": "major", "m": "minor"}[match.group(1)]


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


def add_argument_actions(source: str) -> dict[str, str | None]:
    parsed = ast.parse(source)
    actions: dict[str, str | None] = {}
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
        action: str | None = None
        for keyword in node.keywords:
            if keyword.arg != "action":
                continue
            if isinstance(keyword.value, ast.Constant) and isinstance(
                keyword.value.value,
                str,
            ):
                action = keyword.value.value
            elif isinstance(keyword.value, ast.Name):
                action = keyword.value.id
        actions[first.value] = action
    return actions


def listed_swift_sentinel_ids(contents: str) -> set[str]:
    short_id = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*Tests\.[A-Za-z_][A-Za-z0-9_]*$")
    listed: set[str] = set()
    for match in re.finditer(r"```text\n(.*?)```", contents, flags=re.DOTALL):
        lines = [line.strip() for line in match.group(1).splitlines() if line.strip()]
        if not lines or not all(short_id.fullmatch(line) for line in lines):
            continue
        for line in lines:
            suite, test_name = line.split(".", 1)
            module = (
                "QinaoRuntimeSDKTests"
                if suite.startswith("Qinao")
                else "BehavioralAISubstrateTests"
            )
            full_id = f"{module}.{suite}/{test_name}"
            if full_id in listed:
                raise AssertionError(f"duplicate listed Swift sentinel: {full_id}")
            listed.add(full_id)
    return listed


def created_swift_test_suite_blocks(contents: str) -> list[set[str]]:
    blocks: list[set[str]] = []
    seen: set[str] = set()
    for block in re.findall(r"(?m)^- Create tests:\n((?:  - [^\n]+\n)+)", contents):
        block_suites: set[str] = set()
        for path in re.findall(r"(?m)^  - `([^`]+\.swift)`$", block):
            suite = Path(path).stem
            if suite in seen:
                raise AssertionError(f"duplicate created Swift test suite: {suite}")
            seen.add(suite)
            block_suites.add(suite)
        blocks.append(block_suites)
    return blocks


def created_swift_test_suites(contents: str) -> set[str]:
    return set().union(*created_swift_test_suite_blocks(contents))


def swift_reserved_declaration_count(contents: str, symbol: str) -> int:
    modifiers = (
        r"(?:(?:public|package|internal|fileprivate|private|open|final|indirect|"
        r"nonisolated)\s+)*"
    )
    return len(
        re.findall(
            rf"(?m)^\s*{modifiers}"
            rf"(?:struct|enum|class|actor|protocol|typealias)\s+"
            rf"{re.escape(symbol)}\b",
            contents,
        )
    )


def source_review_closure_rows(contents: str) -> dict[str, dict[str, str]]:
    ledger = section(
        contents,
        SOURCE_REVIEW_LEDGER_START,
        SOURCE_REVIEW_LEDGER_END,
    )
    expected_header = (
        "| ID | status | controlled owner / wave | executable correction | "
        "executable regression ID |"
    )
    expected_rule = "|---|---|---|---|---|"
    lines = [line.strip() for line in ledger.splitlines() if line.strip()]
    if lines[:2] != [expected_header, expected_rule]:
        raise AssertionError("source-review closure has a non-canonical table header")
    rows: dict[str, dict[str, str]] = {}
    for line in lines[2:]:
        if not line.startswith("| SR-"):
            raise AssertionError(f"non-row content in source-review closure: {line!r}")
        cells = [cell.strip() for cell in line.strip("|").split("|")]
        if len(cells) != 5:
            raise AssertionError(f"source-review row must have five cells: {line!r}")
        finding_id, status, owner_wave, correction, regression_id = cells
        if finding_id in rows:
            raise AssertionError(f"duplicate source-review finding ID: {finding_id}")
        rows[finding_id] = {
            "status": status,
            "owner_wave": owner_wave,
            "correction": correction,
            "regression_id": regression_id,
        }
    return rows


def replace_once(contents: str, old: str, new: str) -> str:
    count = contents.count(old)
    if count != 1:
        raise AssertionError(
            f"mutation source must occur exactly once, found {count}: {old!r}"
        )
    return contents.replace(old, new, 1)


def swift_declaration_block(contents: str, name: str) -> str:
    declaration = re.compile(
        rf"(?m)^public\s+(?:struct|enum|protocol)\s+{re.escape(name)}\b"
    )
    matches = list(declaration.finditer(contents))
    if len(matches) != 1:
        raise AssertionError(
            f"expected exactly one Swift declaration for {name}, found {len(matches)}"
        )
    opening = contents.find("{", matches[0].end())
    if opening < 0:
        raise AssertionError(f"missing Swift declaration body for {name}")

    depth = 0
    quote: str | None = None
    escaped = False
    line_comment = False
    block_comment_depth = 0
    index = opening
    while index < len(contents):
        character = contents[index]
        following = contents[index + 1] if index + 1 < len(contents) else ""
        if line_comment:
            if character == "\n":
                line_comment = False
            index += 1
            continue
        if block_comment_depth:
            if character == "/" and following == "*":
                block_comment_depth += 1
                index += 2
                continue
            if character == "*" and following == "/":
                block_comment_depth -= 1
                index += 2
                continue
            index += 1
            continue
        if quote is not None:
            if escaped:
                escaped = False
            elif character == "\\":
                escaped = True
            elif character == quote:
                quote = None
            index += 1
            continue
        if character == "/" and following == "/":
            line_comment = True
            index += 2
            continue
        if character == "/" and following == "*":
            block_comment_depth = 1
            index += 2
            continue
        if character in {'"', "'"}:
            quote = character
            index += 1
            continue
        if character == "{":
            depth += 1
        elif character == "}":
            depth -= 1
            if depth == 0:
                return contents[matches[0].start() : index + 1]
        index += 1
    raise AssertionError(f"unterminated Swift declaration body for {name}")


def replace_once_in_swift_declaration(
    contents: str, name: str, old: str, new: str
) -> str:
    declaration = swift_declaration_block(contents, name)
    mutated_declaration = replace_once(declaration, old, new)
    return replace_once(contents, declaration, mutated_declaration)


def swift_enum_cases(block: str) -> set[str]:
    return set(
        re.findall(
            r"(?m)^\s*case\s+([A-Za-z_][A-Za-z0-9_]*)\b",
            block,
        )
    )


def swift_enum_case_payload_types(block: str) -> dict[str, str | None]:
    cases: dict[str, str | None] = {}
    for match in re.finditer(
        r"(?m)^\s*case\s+([A-Za-z_][A-Za-z0-9_]*)"
        r"(?:\(([A-Za-z_][A-Za-z0-9_.]*)\))?\s*$",
        block,
    ):
        name, payload = match.groups()
        if name in cases:
            raise AssertionError(f"duplicate Swift enum case: {name}")
        cases[name] = payload
    return cases


def swift_stored_property_types(block: str) -> dict[str, str]:
    fields: dict[str, str] = {}
    for name, field_type in re.findall(
        r"(?m)^\s*public let ([A-Za-z_][A-Za-z0-9_]*):\s*"
        r"(\[?[A-Za-z_][A-Za-z0-9_.]*\]?)\s*$",
        block,
    ):
        if name in fields:
            raise AssertionError(f"duplicate Swift stored property: {name}")
        fields[name] = field_type
    return fields


def markdown_table_rows(contents: str, header: str) -> list[list[str]]:
    lines = contents.splitlines()
    header_indexes = [index for index, line in enumerate(lines) if line.strip() == header]
    if len(header_indexes) != 1:
        raise AssertionError(
            f"expected exactly one structured table header {header!r}, "
            f"found {len(header_indexes)}"
        )
    index = header_indexes[0] + 1
    if index >= len(lines) or not re.fullmatch(
        r"\|(?:\s*:?-+:?\s*\|)+", lines[index].strip()
    ):
        raise AssertionError(f"missing canonical rule below table header {header!r}")
    rows: list[list[str]] = []
    for line in lines[index + 1 :]:
        stripped = line.strip()
        if not stripped.startswith("|"):
            break
        rows.append([cell.strip().strip("`") for cell in stripped.strip("|").split("|")])
    if not rows:
        raise AssertionError(f"structured table {header!r} has no rows")
    return rows


class QinaoPlanRemediationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.master = MASTER.read_text(encoding="utf-8")

    def test_convergence_plan_registry_has_one_order_master_one_active_annex(
        self,
    ) -> None:
        active_prefix = "\n".join(self.master.splitlines()[:20])
        order = ORDER_MASTER.read_text(encoding="utf-8")
        order_prefix = "\n".join(order.splitlines()[:20])
        self.assertNotIn(SUPERSEDED_SENTINEL, active_prefix)
        self.assertNotIn(SUPERSEDED_SENTINEL, order_prefix)
        self.assertIn("sole active implementation annex for its Tasks 0-2", self.master)
        self.assertIn(
            "remains the only\nW0-W6 order and completion authority",
            self.master,
        )
        order_marker = f"> **QINAO-PLAN-REGISTRY-V1: {ORDER_MASTER_CLASS}**"
        self.assertEqual(order.splitlines()[2], order_marker)
        self.assertEqual(order.count(order_marker), 1)
        order_without_registry_marker = order.replace(
            f"{order_marker}\n\n",
            "",
            1,
        )
        self.assertEqual(
            hashlib.sha256(order_without_registry_marker.encode("utf-8")).hexdigest(),
            ORDER_MASTER_WITHOUT_REGISTRY_MARKER_SHA256,
        )

        tracked_plan_rows = subprocess.run(
            ["git", "ls-files", "docs/superpowers/plans/*.md"],
            cwd=ROOT,
            check=True,
            capture_output=True,
            text=True,
        ).stdout.splitlines()
        registry_classes = {}
        for row in tracked_plan_rows:
            if not row:
                continue
            path = ROOT / row
            contents = path.read_text(encoding="utf-8")
            markers = PLAN_REGISTRY_MARKER.findall(contents)
            header_candidates = PLAN_REGISTRY_HEADER_CANDIDATE.findall(contents)
            self.assertEqual(len(header_candidates), len(markers), path)
            self.assertLessEqual(len(markers), 1, path)
            if markers:
                registry_classes[path] = markers[0]
        self.assertEqual(
            registry_classes,
            {
                ORDER_MASTER: ORDER_MASTER_CLASS,
                MASTER: ACTIVE_ANNEX_CLASS,
                **{path: SUPERSEDED_CLASS for path in SUPERSEDED_CONVERGENCE_PLANS},
            },
        )

        tracked_rows = subprocess.run(
            ["git", "ls-files", "docs/superpowers/plans/*qinao*.md"],
            cwd=ROOT,
            check=True,
            capture_output=True,
            text=True,
        ).stdout.splitlines()
        tracked_qinao_plans = {ROOT / row for row in tracked_rows if row}
        self.assertEqual(
            tracked_qinao_plans,
            {MASTER, *SUPERSEDED_CONVERGENCE_PLANS},
        )
        self.assertEqual(len(SUPERSEDED_CONVERGENCE_PLANS), 7)
        self.assertEqual(
            set(SUPERSEDED_PLAN_REMAINDER_SHA256),
            {path.name for path in SUPERSEDED_CONVERGENCE_PLANS},
        )
        for path in SUPERSEDED_CONVERGENCE_PLANS:
            self.assertTrue(path.is_file(), path)
            prefix = "\n".join(path.read_text(encoding="utf-8").splitlines()[:20])
            self.assertEqual(prefix.count(SUPERSEDED_SENTINEL), 1, path)
            self.assertEqual(
                PLAN_REGISTRY_MARKER.findall(prefix),
                [SUPERSEDED_CLASS],
                path,
            )
            self.assertNotIn("> **For agentic workers:**", prefix, path)
            self.assertIn(path.name, self.master)

        payloads = self.master[
            self.master.index("## Controlled Domain-Plan Payload W1:") :
        ]
        self.assertIsNone(re.search(r"(?im)^\s*-\s*\[[xX]\]", payloads))
        self.assertIn(
            "No W1-W6 payload is complete or admitted by this annex",
            self.master,
        )

    def test_superseded_plan_changes_are_exact_header_only(self) -> None:
        goal_marker = "\n**Goal:**"
        for path in SUPERSEDED_CONVERGENCE_PLANS:
            candidate = path.read_text(encoding="utf-8")
            self.assertNotIn("> **For agentic workers:**", candidate, path)
            self.assertEqual(candidate.count(goal_marker), 1, path)
            self.assertEqual(
                hashlib.sha256(
                    (
                        candidate.splitlines()[0]
                        + goal_marker
                        + candidate.split(goal_marker, 1)[1]
                    ).encode("utf-8")
                ).hexdigest(),
                SUPERSEDED_PLAN_REMAINDER_SHA256[path.name],
                path,
            )

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
        normalized_master = re.sub(r"\s+", " ", self.master)
        for fail_fast_contract in (
            "Every authoritative fenced execution block is fail-fast",
            "terminates the wave on the first nonzero status",
            "can never mask an earlier failure",
            "already-expanded argv",
        ):
            self.assertIn(fail_fast_contract, normalized_master)
        shell_blocks = fenced_shell_blocks(self.master)
        commands = [
            command
            for block in shell_blocks
            for command in logical_shell_commands(block)
        ]
        filtered = [command for command in commands if "--filter" in command]
        self.assertGreater(len(filtered), 5)
        for command in filtered:
            argv = direct_runner_argv(command, "scripts/run_nonempty_swift_filter.py")
            validate_closed_runner_options(
                argv,
                singleton_options={
                    "--swift-executable",
                    "--package-path",
                    "--filter",
                },
                repeatable_options={"--require-suite", "--require-test"},
            )
            self.assertEqual(len(option_values(argv, "--swift-executable")), 1)
            self.assertEqual(len(option_values(argv, "--package-path")), 1)
            filters = option_values(argv, "--filter")
            self.assertEqual(len(filters), 1)
            suites = filters[0].split("|")
            self.assertEqual(len(suites), len(set(suites)))
            self.assertTrue(
                all(re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", suite) for suite in suites)
            )
            required_suites = option_values(argv, "--require-suite")
            self.assertTrue(required_suites, command)
            selectors = [identity.rsplit(".", 1)[-1] for identity in required_suites]
            self.assertEqual(len(selectors), len(set(selectors)))
            self.assertEqual(set(selectors), set(suites), command)

        flow_control = re.compile(
            r"^(?:if|then|elif|else|fi|for|while|until|case|esac|select|function|alias)\b"
        )
        function_definition = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*\s*\(\)\s*\{")
        shell_flow_or_error_state_builtin = re.compile(
            r"^(?:exit|return|set|trap|true|false|:|eval|source|\.|exec|"
            r"builtin|command)(?:\s|$)"
        )
        execution_environment_assignment = re.compile(
            r"^(?:PATH|PYTHONPATH|PYTHONHOME|BASH_ENV|ENV|SHELLOPTS|"
            r"QINAO_[A-Z0-9_]+_PROTECTED_PYTHON)="
        )
        for block in shell_blocks:
            if "scripts/run_nonempty_swift_filter.py" not in block and (
                "scripts/run_nonempty_xcode_test.py" not in block
            ):
                continue
            for command in logical_shell_commands(block):
                self.assertIsNone(flow_control.match(command), command)
                self.assertIsNone(function_definition.match(command), command)
                self.assertIsNone(
                    shell_flow_or_error_state_builtin.match(command), command
                )
                self.assertIsNone(
                    execution_environment_assignment.match(command), command
                )
                self.assertFalse(command.startswith(("{", "}")), command)

        xcode_commands = [
            command
            for command in commands
            if "scripts/run_nonempty_xcode_test.py" in command
        ]
        self.assertGreaterEqual(len(xcode_commands), 2)
        for command in xcode_commands:
            argv = direct_runner_argv(command, "scripts/run_nonempty_xcode_test.py")
            validate_closed_runner_options(
                argv,
                singleton_options={
                    "--xcodebuild-executable",
                    "--xcresulttool-executable",
                    "--scheme",
                    "--destination",
                    "--derived-data-path",
                    "--result-bundle-path",
                    "--require-target",
                },
                repeatable_options={
                    "--package-path",
                    "--project-path",
                    "--require-suite",
                    "--require-test",
                },
            )
            self.assertEqual(len(option_values(argv, "--xcodebuild-executable")), 1)
            self.assertEqual(len(option_values(argv, "--xcresulttool-executable")), 1)
            package_paths = option_values(argv, "--package-path")
            project_paths = option_values(argv, "--project-path")
            self.assertLessEqual(len(package_paths), 1, command)
            self.assertLessEqual(len(project_paths), 1, command)
            self.assertEqual(
                len(package_paths) + len(project_paths),
                1,
                "Xcode runner must receive exactly one package/project source selector",
            )
        for dual_mode_contract in (
            "accepts exactly one mutually exclusive source selector: either an exact "
            "Swift-package directory through `--package-path`, or an exact `.xcodeproj` "
            "bundle through `--project-path`",
            "rejects an invocation with neither selector or both selectors, a workspace, "
            "a symlinked/escaped project, a missing/non-regular `project.pbxproj`, and "
            "every unknown or abbreviated selector",
            "Package mode derives only `xcodebuild -packagePath`; project mode derives "
            "only `xcodebuild -project` and may not run XcodeGen, rewrite the project, "
            "select a workspace, or accept caller-supplied raw Xcode arguments",
            "descriptor-opens the project bundle, hashes its bounded regular-file tree "
            "before launch and requires the same identities and digest after evidence "
            "extraction",
            "accepts repeatable exact `--require-suite Target/Suite` and "
            "`--require-test Target/Suite/testName` selectors",
            "every test belongs to one required suite and the singleton target, every "
            "suite owns at least one test, and the runner derives only the corresponding "
            "exact `-only-testing:` argv",
            "Structured discovery/execution must equal those selectors bidirectionally",
            "Positive and mutation coverage exercises both modes, their exact derived "
            "argv, mutual exclusion, missing/symlinked/escaped project inputs, project "
            "mutation",
        ):
            self.assertIn(dual_mode_contract, normalized_master)

        source = NONEMPTY_FILTER.read_text(encoding="utf-8")
        for contract in (
            "CLOSED_ALTERNATION.fullmatch",
            '["test", "--package-path", str(package_path), "list"]',
            "missing_discovery",
            "executed_suite_counts",
            "missing_execution",
            "required_test_set",
            "validate_required_test_discovery",
            "required test IDs missing from non-skipped structured xUnit",
            "EXIT_ZERO_EXECUTION",
        ):
            self.assertIn(contract, source)
        self.assertIn("--swift-executable", required_add_argument_options(source))
        self.assertEqual(add_argument_actions(source)["--require-test"], "append")
        xcode_source = NONEMPTY_XCODE.read_text(encoding="utf-8")
        self.assertTrue(
            {"--xcodebuild-executable", "--xcresulttool-executable"}
            <= required_add_argument_options(xcode_source)
        )
        self.assertEqual(
            add_argument_actions(xcode_source)["--xcodebuild-executable"],
            "StoreOnceAction",
        )
        self.assertEqual(
            add_argument_actions(xcode_source)["--xcresulttool-executable"],
            "StoreOnceAction",
        )
        self.assertEqual(
            add_argument_actions(xcode_source)["--package-path"],
            "StoreOnceAction",
        )
        self.assertNotIn('["xcrun", "xcresulttool"', xcode_source)

    def test_named_swift_sentinels_equal_require_test_selectors_bidirectionally(
        self,
    ) -> None:
        listed = listed_swift_sentinel_ids(self.master)
        self.assertEqual(len(listed), 222)
        commands = [
            command
            for block in fenced_shell_blocks(self.master)
            for command in logical_shell_commands(block)
            if "scripts/run_nonempty_swift_filter.py" in command
        ]
        selected: list[str] = []
        for command in commands:
            filter_match = re.search(r"--filter\s+['\"]?([^'\"\s]+)", command)
            self.assertIsNotNone(filter_match, command)
            suites = set(filter_match.group(1).split("|"))
            command_ids = re.findall(
                r"--require-test\s+"
                r"([A-Za-z_][A-Za-z0-9_.]*/[A-Za-z_][A-Za-z0-9_]*)",
                command,
            )
            required_suites = {
                identity.rsplit(".", 1)[-1]
                for identity in option_values(
                    direct_runner_argv(command, "scripts/run_nonempty_swift_filter.py"),
                    "--require-suite",
                )
            }
            for test_id in command_ids:
                suite = test_id.split("/", 1)[0].rsplit(".", 1)[-1]
                self.assertIn(suite, suites, (test_id, command))
                self.assertIn(suite, required_suites, (test_id, command))
            selected.extend(command_ids)
        self.assertEqual(len(selected), len(set(selected)))
        self.assertEqual(set(selected), listed)

        wave_sections = {
            "W1": section(
                self.master,
                "## Controlled Domain-Plan Payload W1:",
                "## Controlled Domain-Plan Payload W2:",
            ),
            "W2": section(
                self.master,
                "## Controlled Domain-Plan Payload W2:",
                "## Controlled Domain-Plan Payload W3:",
            ),
            "W3": section(
                self.master,
                "## Controlled Domain-Plan Payload W3:",
                "### Payload 6D (W4)",
            ),
            "W4": section(
                self.master,
                "### Payload 6D (W4)",
                "## Controlled Domain-Plan Payload W5:",
            ),
            "W5": section(
                self.master,
                "## Controlled Domain-Plan Payload W5:",
                "## Controlled Domain-Plan Payload W6 Runtime:",
            ),
            "W6": self.master[
                self.master.index("## Controlled Domain-Plan Payload W6 Runtime:") :
            ],
        }
        expected_wave_counts = {
            "W1": 85,
            "W2": 46,
            "W3": 9,
            "W4": 14,
            "W5": 13,
            "W6": 55,
        }
        wave_selected: dict[str, list[str]] = {}
        for wave, contents in wave_sections.items():
            wave_selected[wave] = [
                test_id
                for block in fenced_shell_blocks(contents)
                for command in logical_shell_commands(block)
                if "scripts/run_nonempty_swift_filter.py" in command
                for test_id in re.findall(
                    r"--require-test\s+"
                    r"([A-Za-z_][A-Za-z0-9_.]*/[A-Za-z_][A-Za-z0-9_]*)",
                    command,
                )
            ]
        self.assertEqual(
            {wave: len(test_ids) for wave, test_ids in wave_selected.items()},
            expected_wave_counts,
        )
        wave_rows = [
            (wave, test_id)
            for wave in expected_wave_counts
            for test_id in wave_selected[wave]
        ]
        self.assertEqual(len(wave_rows), 222)
        self.assertEqual([test_id for _, test_id in wave_rows], selected)
        wave_map = "\n".join(f"{wave}\t{test_id}" for wave, test_id in wave_rows)
        self.assertEqual(
            hashlib.sha256(wave_map.encode("utf-8")).hexdigest(),
            "696fb383e79c30bedc4a321c13b7e715c73b0e9423e40fa1259c0d90691f7558",
        )

    def test_every_created_swift_suite_is_required_in_its_owning_wave(
        self,
    ) -> None:
        created_blocks = created_swift_test_suite_blocks(self.master)
        block_owners = (
            "W1",
            "W2",
            "W3",
            "W3",
            "W4",
            "W5",
            "W6",
            "W6",
            "W6",
        )
        self.assertEqual(len(created_blocks), len(block_owners))
        created_by_wave = {wave: set() for wave in set(block_owners)}
        for owner, suites in zip(block_owners, created_blocks):
            created_by_wave[owner].update(suites)
        self.assertEqual(
            set().union(*created_by_wave.values()),
            created_swift_test_suites(self.master),
        )
        expected_created_counts = {
            "W1": 30,
            "W2": 25,
            "W3": 17,
            "W4": 9,
            "W5": 11,
            "W6": 30,
        }
        gate_sections = {
            "W1": section(
                self.master,
                "## Controlled Domain-Plan Payload W1:",
                "## Controlled Domain-Plan Payload W2:",
            ),
            "W2": section(
                self.master,
                "## Controlled Domain-Plan Payload W2:",
                "## Controlled Domain-Plan Payload W3:",
            ),
            "W3": section(
                self.master,
                "## Controlled Domain-Plan Payload W3:",
                "### Payload 6D (W4)",
            ),
            "W4": section(
                self.master,
                "### Payload 6D (W4)",
                "## Controlled Domain-Plan Payload W5:",
            ),
            "W5": section(
                self.master,
                "## Controlled Domain-Plan Payload W5:",
                "## Controlled Domain-Plan Payload W6 Runtime:",
            ),
            "W6": self.master[
                self.master.index("## Controlled Domain-Plan Payload W6 Runtime:") :
            ],
        }
        required_by_wave = {wave: set() for wave in expected_created_counts}
        for wave, contents in gate_sections.items():
            for block in fenced_shell_blocks(contents):
                for command in logical_shell_commands(block):
                    if "scripts/run_nonempty_swift_filter.py" not in command:
                        continue
                    argv = direct_runner_argv(
                        command, "scripts/run_nonempty_swift_filter.py"
                    )
                    required_by_wave[wave].update(
                        identity.rsplit(".", 1)[-1]
                        for identity in option_values(argv, "--require-suite")
                    )
        for wave, created in created_by_wave.items():
            self.assertEqual(len(created), expected_created_counts[wave], wave)
            missing = sorted(created - required_by_wave[wave])
            self.assertEqual(missing, [], wave)

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
            "### Payload 3A-0 — Restore the Sole Artifact-Mesh Production Open First",
            "### Payload 3A — Write failing value and wire tests",
            "### Payload 3B — After Task-0 GREEN, implement the remaining "
            "low-entropy values",
            "### Payload 3C — Freeze the semantic DAG without a scheduler",
            "### Payload 3D — Prove fixtures and authority admission",
            "### Payload 3E — Verify and commit",
        ]
        positions = [w1.index(marker) for marker in markers]
        self.assertEqual(positions, sorted(positions))
        self.assertIn("RuntimeCore cannot import BASMemory", w1)
        self.assertIn("cross-target composition uses `BASArtifactID` references", w1)
        self.assertIn("Extension, Adapter and Fixture are each", w1)
        self.assertIn("`Create` is `notApplicable` for every Artifact-Mesh row", w1)
        self.assertIn("Payload 3A-0 is W1's sole physical-store exception", w1)

    def test_w1_artifact_mesh_task0_is_nonvacuous_and_single_receipt(
        self,
    ) -> None:
        w1 = section(
            self.master,
            "## Controlled Domain-Plan Payload W1:",
            "## Controlled Domain-Plan Payload W2:",
        )
        required_symbols = (
            "BASArtifactMeshAnchorPort",
            "BASArtifactMeshKeychainAnchor",
            "openProductionForAuthorizedCreate",
            "openProductionForReopen",
            "QinaoArtifactMeshConfiguration",
            "QinaoDefaults.makeArtifactMeshStore",
            "QinaoSovereignHost",
            "BASArtifactMeshCommittedOpenFacts",
        )
        for symbol in required_symbols:
            self.assertIn(symbol, w1)
        for suite in (
            "BASArtifactStoreTests",
            "BASArtifactMeshKeychainAnchorTests",
            "QinaoArtifactMeshAssemblyTests",
            "QinaoSovereignHostAssemblyTests",
            "QinaoEffectFacadeFreezeTests",
            "QinaoSampleSovereignSpineTests",
        ):
            self.assertIn(f"--require-suite {suite}", w1)
        self.assertIn(
            "rows=40 no_fault=26 faults=14",
            w1,
        )
        self.assertIn("after a real reboot and before first unlock", w1)
        self.assertIn("two separately signed application processes", w1)
        self.assertIn("one W1 admission receipt's existing", w1)
        self.assertIn("Do **not** create an Artifact-Mesh handoff", w1)
        self.assertEqual(w1.count("scripts/run_nonempty_xcode_test.py"), 2)
        self.assertEqual(w1.count("--require-target SampleHostTests"), 2)
        self.assertNotIn("iPhone 17e", w1)
        self.assertNotIn("/private/tmp/qinao-w1-samplehost-derived", w1)
        self.assertIsNone(re.search(r"(?m)^\s*\(cd SampleHost && xcodebuild test", w1))
        self.assertIsNone(
            re.search(
                r"(?m)^\s*swift test --package-path SampleHost\s*$",
                w1,
            )
        )
        self.assertNotIn(
            "docs/superpowers/evidence/qinao-ea-extensions/W1/artifact-mesh-task0.json",
            w1,
        )
        self.assertNotIn("w1.contract-freeze", self.master)
        self.assertNotIn(
            "feat(qinao): freeze dual-space automation contracts",
            self.master,
        )
        self.assertIn("w1.artifact-mesh-contract-freeze", w1)
        self.assertIn("artifactMeshStoreLineageID", w1)
        self.assertIn("storeLineageID", w1)
        self.assertNotIn("artifactMeshCommittedAnchorDigest", w1)
        key_domain_test_path = (
            ROOT
            / "QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/"
            / "QinaoKeyDomainSeparationTests.swift"
        )
        self.assertIn(
            "QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/"
            "QinaoKeyDomainSeparationTests.swift",
            w1,
        )
        key_domain_test = key_domain_test_path.read_text(encoding="utf-8")
        self.assertIn("import CryptoKit", key_domain_test)
        self.assertIsNone(re.search(r"(?m)^import Crypto$", key_domain_test))
        self.assertIn("do not add swift-crypto", re.sub(r"\s+", " ", w1))

        w2 = section(
            self.master,
            "## Controlled Domain-Plan Payload W2:",
            "## Controlled Domain-Plan Payload W3:",
        )
        self.assertIn(
            "immediate predecessor must be the one verified",
            w2,
        )
        self.assertIn("w1.artifact-mesh-contract-freeze", w2)
        self.assertNotIn("separately admitted Artifact-Mesh Task-0", w2)

    def test_w1_transplants_exact_four_artifact_mesh_ea_invariants(self) -> None:
        w1 = section(
            self.master,
            "## Controlled Domain-Plan Payload W1:",
            "## Controlled Domain-Plan Payload W2:",
        )
        rows = {
            (
                "BehavioralAISubstrate/Sources/BASMemory/"
                "BASArtifactMeshAnchorPort.swift",
                "BASArtifactMeshAnchorPort",
                "owner-private-anchor-record-and-cas-port",
                "artifact-mesh-anchor-keychain-cas-v1",
                "artifact-mesh-anchor-canonical-reopen-v1",
                "artifact-mesh-two-phase-floor-recovery-v1",
            ),
            (
                "BehavioralAISubstrate/Sources/BASMemory/"
                "BASArtifactMeshKeychainAnchor.swift",
                "BASArtifactMeshKeychainAnchor",
                "sole-shipping-keychain-anchor-adapter",
                "artifact-mesh-keychain-security-attributes-v1",
                "artifact-mesh-keychain-load-digest-v1",
                "artifact-mesh-keychain-unavailable-is-not-absent-v1",
            ),
            (
                "QinaoRuntimeSDK/Sources/QinaoDefaults/QinaoArtifactMeshAssembly.swift",
                "QinaoDefaults.makeArtifactMeshStore",
                "mechanism-only-production-store-factory",
                "artifact-mesh-qinao-production-factory-v1",
                "artifact-mesh-qinao-factory-reopen-v1",
                "artifact-mesh-qinao-factory-no-fallback-v1",
            ),
            (
                "QinaoRuntimeSDK/Sources/QinaoDefaults/"
                "QinaoSovereignHostAssembly.swift",
                "QinaoDefaults.makeSovereignHost",
                "single-host-process-artifact-mesh-call-seam",
                "artifact-mesh-host-single-store-reachability-v1",
                "artifact-mesh-host-reopen-same-store-v1",
                "artifact-mesh-host-no-injected-anchor-v1",
            ),
        }
        for row in rows:
            for literal in row:
                self.assertIn(literal, w1)
        self.assertIn("requires exact set equality: four", w1)
        self.assertIn("no fifth `artifact.mesh` E/A invariant row", w1)
        self.assertIn("The old slice IDs", w1)
        for legacy_slice_id in (
            "artifact-mesh.anchor-port-record.w1.v1",
            "artifact-mesh.keychain-anchor.w1.v1",
            "artifact-mesh.qinao-assembly.w1.v1",
            "artifact-mesh.sovereign-host-call-seam.w1.v1",
        ):
            self.assertNotIn(legacy_slice_id, w1)

    def test_workspace_and_continuity_contracts_are_literal_first_wires(
        self,
    ) -> None:
        w1 = section(
            self.master,
            "## Controlled Domain-Plan Payload W1:",
            "## Controlled Domain-Plan Payload W2:",
        )
        match = re.search(
            r"public struct ContextWorkspaceRef:.*?\n\}",
            w1,
            flags=re.DOTALL,
        )
        self.assertIsNotNone(match)
        workspace = match.group(0)
        fields = set(re.findall(r"public let ([A-Za-z0-9_]+):", workspace))
        self.assertEqual(
            fields,
            {
                "authorityScopeDigest",
                "workspaceID",
                "workspaceIncarnationID",
                "workspaceGeneration",
                "windowID",
                "windowGeneration",
                "sessionID",
                "sessionGeneration",
                "restorationEpoch",
                "capabilityEpoch",
                "policyEpoch",
                "deletionEpoch",
            },
        )
        for forbidden in (
            "applicationContainer",
            "workspaceArtifactID",
            "workspaceDigest",
        ):
            self.assertNotIn(f"public let {forbidden}:", workspace)
        for declaration in (
            "public enum ContinuationPolicy",
            "public struct WorkUnitRecoveryCursor",
            "public struct ContextContinuityManifest",
            "public enum BASWorkUnitRecoveryDisposition",
        ):
            self.assertEqual(w1.count(declaration), 1, declaration)
        self.assertIn("These declarations close a real HEAD gap", w1)
        self.assertIn("none may be described as\n“pre-existing.”", w1)
        self.assertIn("context-continuity | Create | state.snapshot-contracts", w1)
        self.assertIn(
            "continuation-policy-recovery | Extension | semantics.layercell",
            w1,
        )
        self.assertIn("one canonical claim/evidence pair", w1)
        self.assertNotIn("k3ZeroBudgetUseProofArtifactID", w1)

    def test_w1_agent_automation_abis_are_unique_literal_and_decodable(
        self,
    ) -> None:
        w1 = section(
            self.master,
            "## Controlled Domain-Plan Payload W1:",
            "## Controlled Domain-Plan Payload W2:",
        )
        primary_thirteen = (
            "BASAutomationRunRequest",
            "BASAutomationResumeRequest",
            "BASAutomationRunEvent",
            "BASAutomationRunOutcome",
            "BASAutomationRecurrenceRequest",
            "BASAutomationLogicalFireProposal",
            "BASAutomationCheckpointPayload",
            "BASAutomationInspectionRequest",
            "BASExperienceExposureContract",
            "BASDelegationProposal",
            "BASContextCapsule",
            "WorkUnitRecoveryCursor",
            "ContextContinuityManifest",
        )
        declaration_pattern = re.compile(
            r"^public (?:struct|enum) ([A-Za-z0-9_]+)\b",
            flags=re.MULTILINE,
        )
        declarations = list(declaration_pattern.finditer(w1))

        def declaration_block(name: str) -> str:
            matches = [match for match in declarations if match.group(1) == name]
            self.assertEqual(len(matches), 1, name)
            start = matches[0].start()
            later = [match.start() for match in declarations if match.start() > start]
            end = min(later) if later else len(w1)
            return w1[start:end]

        for name in primary_thirteen:
            block = declaration_block(name)
            self.assertIn("Codable", block, name)
            if name == "BASContextCapsule":
                self.assertIn("case attemptFrame(", block)
                self.assertIn("case providerStep(", block)
                self.assertIn("case kind, payload", block)
                self.assertIn("public init(from decoder: Decoder) throws", block)
                self.assertIn("public func encode(to encoder: Encoder) throws", block)
            else:
                self.assertIn("public init(", block, name)
                self.assertIn("private enum CodingKeys", block, name)
                self.assertIn("CaseIterable", block, name)
                self.assertIn(
                    "public init(from decoder: Decoder) throws",
                    block,
                    name,
                )

        self.assertEqual(
            len(primary_thirteen),
            13,
            "the frozen primary ABI set must not drift",
        )
        self.assertEqual(
            len(
                re.findall(
                    r"^public struct BASAutomationInspectionRequest\b",
                    w1,
                    flags=re.MULTILINE,
                )
            ),
            1,
        )
        for name in (
            "BASContinuationPolicyConstraints",
            "WorkUnitRecoveryCursor",
            "ContextContinuityManifest",
        ):
            block = declaration_block(name)
            self.assertIn("public init(", block, name)
            self.assertIn("exactKeySet(", block, name)
        cursor = declaration_block("WorkUnitRecoveryCursor")
        self.assertIn("public let budgetUseEvidence: BASBudgetUseEvidence", cursor)
        self.assertNotIn("budgetUseReceiptXORZeroUseProof", cursor)
        self.assertNotIn("k3ZeroBudgetUseProofArtifactID", cursor)
        continuation = declaration_block("ContinuationPolicy")
        self.assertIn("case tag", continuation)
        self.assertIn("case constraints", continuation)
        self.assertIn("exactKeySet(", continuation)
        missed_run = declaration_block("BASAutomationMissedRunPolicy")
        self.assertIn("case tag, maximumCount", missed_run)
        self.assertIn("exactKeySet(", missed_run)

    def test_w0_bootstrap_tools_and_ci_module_sets_are_nonvacuous(self) -> None:
        expected_paths = (
            "scripts/run_nonempty_xcode_test.py",
            "scripts/test_run_nonempty_xcode_test.py",
            "scripts/check_artifact_mesh_device_recovery.py",
            "scripts/run_artifact_mesh_device_recovery.py",
            "scripts/test_check_artifact_mesh_device_recovery.py",
        )
        task_one = section(
            self.master,
            "## Task 1: Make W0 Gates Non-Vacuous and Continuous",
            "## Task 2: Atomically Reconcile the Seven Controlled Documents",
        )
        for relative in expected_paths:
            self.assertIn(relative, task_one)
            self.assertTrue((ROOT / relative).is_file(), relative)
        self.assertIn("expected-set gate is evaluated even when both a file", task_one)
        self.assertIn("absent from the W1 path list", task_one)

        modules = (
            "scripts.test_run_nonempty_xcode_test",
            "scripts.test_check_artifact_mesh_device_recovery",
            "scripts.test_prepare_qinao_v2_wave_candidate",
            "scripts.test_run_qinao_managed_convergence",
        )
        workflow_texts = (
            ORDINARY_WORKFLOW.read_text(encoding="utf-8"),
            PROTECTED_WORKFLOW.read_text(encoding="utf-8"),
            WORKFLOW_META_TEST.read_text(encoding="utf-8"),
        )
        for module in modules:
            for text in workflow_texts:
                self.assertIn(module, text)

    def test_device_lab_cross_process_seam_and_entitlements_are_closed(
        self,
    ) -> None:
        w1 = section(
            self.master,
            "## Controlled Domain-Plan Payload W1:",
            "## Controlled Domain-Plan Payload W2:",
        )
        for literal in (
            "com.qinao.artifact-mesh-device-lab",
            "com.qinao.artifact-mesh-cas-contender-lab",
            "com.qinao.artifact-mesh-cas-lab-shared",
            "com.apple.developer.default-data-protection",
            "NSFileProtectionComplete",
            "BASArtifactMeshKeychainCASLabOutcome",
            "BASArtifactMeshKeychainCASLabProbe",
            "public static func seed(",
            "public static func contend(",
            "fixed-size digest bytes in\nconstant time",
        ):
            self.assertIn(literal, w1)
        self.assertIn("contains no App Group, iCloud/CloudKit", w1)

    def test_w2_sample_signature_transition_lists_every_consumer(self) -> None:
        w2 = section(
            self.master,
            "## Controlled Domain-Plan Payload W2:",
            "## Controlled Domain-Plan Payload W3:",
        )
        for path in (
            "QinaoRuntimeSDK/Sources/QinaoSample/SampleSovereignSpine.swift",
            "QinaoRuntimeSDK/Sources/QinaoSample/SampleSession.swift",
            "QinaoRuntimeSDK/Sources/QinaoSample/ContentView.swift",
            "QinaoRuntimeSDK/Sources/QinaoSampleApp/QinaoSampleApp.swift",
            "QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/"
            "QinaoSampleSovereignSpineTests.swift",
            "QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/"
            "QinaoSampleAppShowcaseWireTests.swift",
        ):
            self.assertIn(path, w2)

    def test_w1_exact_task0_test_ids_are_discovered_and_execution_locked(
        self,
    ) -> None:
        w1 = section(
            self.master,
            "## Controlled Domain-Plan Payload W1:",
            "## Controlled Domain-Plan Payload W2:",
        )
        match = re.search(
            r"Pin exactly these 41\s+Artifact-Mesh cases;.*?```text\n(.*?)```",
            w1,
            flags=re.DOTALL,
        )
        self.assertIsNotNone(match)
        short_ids = [
            line.strip() for line in match.group(1).splitlines() if line.strip()
        ]
        self.assertEqual(len(short_ids), 41)
        self.assertEqual(len(set(short_ids)), 41)

        expected_ids: set[str] = set()
        for short_id in short_ids:
            suite, test_name = short_id.split(".", 1)
            module = (
                "BehavioralAISubstrateTests"
                if suite.startswith("BAS")
                else "QinaoRuntimeSDKTests"
            )
            expected_ids.add(f"{module}.{suite}/{test_name}")
        expected_ids.add(
            "QinaoRuntimeSDKTests.QinaoProviderBoundaryTests/"
            "testQinaoSDKContainsNoConcreteProviderRuntime"
        )
        task0_execution = section(
            w1,
            "#### Step 7: Execute the one W1 candidate in this exact internal order",
            "### Payload 3A — Write failing value and wire tests",
        )
        required_ids = re.findall(
            r"--require-test ([A-Za-z_][A-Za-z0-9_.]*/[A-Za-z_][A-Za-z0-9_]*)",
            task0_execution,
        )
        self.assertEqual(len(required_ids), 42)
        self.assertEqual(set(required_ids), expected_ids)
        self.assertEqual(
            sum(
                item.startswith("BehavioralAISubstrateTests.") for item in required_ids
            ),
            34,
        )
        self.assertEqual(
            sum(item.startswith("QinaoRuntimeSDKTests.") for item in required_ids),
            8,
        )
        self.assertIn("exact 42-ID Task-0 sentinel root", w1)

    def test_w1_matrix_and_protected_policy_sets_are_closed(self) -> None:
        w1 = section(
            self.master,
            "## Controlled Domain-Plan Payload W1:",
            "## Controlled Domain-Plan Payload W2:",
        )
        matrix = section(
            w1,
            "#### Step 6: Prove the exact physical recovery matrix",
            "#### Step 7: Execute the one W1 candidate",
        )
        for token in (
            "ROW_KEYS = {",
            "NO_FAULT_EXPECTED = {",
            "FAULT_EXPECTED_STATE = {",
            'expectedStoreIdentity = "$derived.storeIdentity"',
            'expectedRecordRoot = "$derived.recordRoot"',
            'expectedCASHead = "$derived.casHead"',
            "exactly 40 unique rows",
            "non-canonical JSON",
            "all four are mandatory",
        ):
            self.assertIn(token, matrix)
        self.assertIn(
            "any `success`, `passed`, `wave`,\n`owner`, `status`, `admission`, "
            "`receipt`, `result`",
            matrix,
        )

        policy = section(
            self.master,
            "The Task-2 Ledger migration freezes W1's Artifact-Mesh proof",
            "For each row, `$QINAO_UNSIGNED_WAVE_BUNDLE`",
        )
        expected_commands = {
            "w1.artifact-mesh.bas-focused",
            "w1.artifact-mesh.bas-full",
            "w1.artifact-mesh.qinao-focused",
            "w1.artifact-mesh.qinao-full",
            "w1.artifact-mesh.samplehost-ios",
            "w1.artifact-mesh.matrix-meta",
            "w1.artifact-mesh.matrix-static",
            "w1.artifact-mesh.device-recovery",
        }
        expected_tools = {
            "w1.tool.git",
            "w1.tool.nonempty-swift-filter",
            "w1.tool.nonempty-xcode-test",
            "w1.tool.matrix-checker",
            "w1.tool.matrix-checker-tests",
            "w1.tool.device-recovery-controller",
            "w1.tool.protected-python",
            "w1.tool.swift6",
            "w1.tool.xcodebuild27",
            "w1.tool.xcresulttool27",
        }
        expected_inputs = {
            "w1.input.candidate-tree",
            "w1.input.git-runtime",
            "w1.input.python-runtime",
            "w1.input.swift-toolchain",
            "w1.input.xcode27-ios27-sdk",
            "w1.input.ios27-simulator",
            "w1.input.signed-device-profile",
            "w1.input.physical-device",
            "w1.input.lab-signing-entitlements",
            "w1.input.run-challenge",
            "w1.input.encrypted-custody",
        }
        expected_assertions = {
            "w1.assert.bas-required-tests-34",
            "w1.assert.qinao-required-tests-8",
            "w1.assert.bas-full-green",
            "w1.assert.qinao-full-green",
            "w1.assert.samplehost-nonempty-green",
            "w1.assert.matrix-meta-green",
            "w1.assert.matrix-static-40-26-14",
            "w1.assert.device-physical-40-of-40",
            "w1.assert.two-process-cas",
            "w1.assert.persist-wal-full",
            "w1.assert.sidecars-protected",
            "w1.assert.atomic-quarantine",
            "w1.assert.preunlock-zero-mutation",
            "w1.assert.factory-external-reopen",
            "w1.assert.release-exclusion",
            "w1.assert.custody-cleanup",
        }
        self.assertEqual(
            set(re.findall(r"`(w1\.artifact-mesh\.[a-z0-9-]+)`", policy)),
            expected_commands,
        )
        self.assertEqual(
            set(re.findall(r"`(w1\.tool\.[a-z0-9-]+)`", policy)),
            expected_tools,
        )
        self.assertEqual(
            set(re.findall(r"`(w1\.input\.[a-z0-9-]+)`", policy)),
            expected_inputs,
        )
        self.assertEqual(
            set(re.findall(r"`(w1\.assert\.[a-z0-9-]+)`", policy)),
            expected_assertions,
        )
        for root in (
            "toolRowsRoot",
            "commandRowsRoot",
            "assertionRowsRoot",
            "externalInputRequirementRowsRoot",
            "descendantProfilesRoot",
            "executableRowsRoot",
            "invocationTemplatesRoot",
            "operationCoverageRowsRoot",
        ):
            self.assertIn(root, policy)
        self.assertIn("requires exact set equality in both directions", policy)
        self.assertIn("all eleven external\ninput IDs", policy)
        self.assertIn("all ten tool IDs", policy)
        self.assertIn("five executable\nrows, six invocation templates", policy)
        self.assertIn("stateMutationEligible = true", policy)
        for collection in (
            "operationBindings[]",
            "evidenceRetentionPolicyRows[]",
            "descendantProfiles[]",
            "executableRows[]",
            "invocationTemplates[]",
            "operationCoverageRows[]",
        ):
            self.assertIn(collection, policy)
        for profile in (
            "w1.profile.swift-static",
            "w1.profile.python-static",
            "w1.profile.xcode-static",
            "w1.profile.device-physical",
        ):
            self.assertIn(profile, policy)
        self.assertIn("permitsShell=false", policy)
        self.assertIn("permitsPATHLookup=false", policy)
        self.assertIn("mutationLocator` is JSON null", policy)
        self.assertIn("`mutationDigest` is the empty", policy)
        self.assertIn("brokerObserved", policy)
        self.assertIn("runnerAuthenticated", policy)
        self.assertNotIn("controllerObservationOnly", policy)
        self.assertNotIn("w1.tool.python314", policy)
        self.assertNotIn("package exit 0 with structured nonzero execution", policy)
        self.assertNotIn("At minimum", policy)
        for token in (
            "QinaoArtifactMeshDeviceRecoveryLeaseV1",
            "QinaoArtifactMeshPhysicalBrokerRequestV1",
            "QinaoArtifactMeshPhysicalBrokerEvidenceV1",
            "QinaoArtifactMeshCustodyCleanupRequestV1",
            "QinaoArtifactMeshCustodyProofV1",
            "QinaoArtifactMeshArchiveAttestationV1",
            "QinaoArtifactMeshExternalReopenReceiptV1",
            "QinaoArtifactMeshProductionReachabilityV1",
            "eight-byte unsigned big-endian length",
            "exactly 40 ordered events",
            "exactly nine ordered physical assertions",
            "runnerAuthenticated",
            "generic or app-authored",
            "residueFileCount == 0",
            "residueByteCount == 0",
            "The controller never builds, signs, installs or runs either DeviceLab app",
            "separately admitted `protectedPhysicalBroker`",
        ):
            self.assertIn(token, w1)
        self.assertNotIn("It builds, signs, installs and runs both DeviceLab apps", w1)
        self.assertNotIn("opaque protected broker protocol", w1.casefold())

    def test_managed_policy_projection_closes_t04_to_t19_execution_seam(self) -> None:
        policy = section(
            self.master,
            "The Task-2 Ledger migration freezes W1's Artifact-Mesh proof",
            "For each row, `$QINAO_UNSIGNED_WAVE_BUNDLE`",
        )
        coordinator = section(
            self.master,
            "The whole admitted replay has one public entrypoint",
            "## Controlled Domain-Plan Payload W1:",
        )
        registry = section(
            self.master,
            "### Closed post-migration V2 Wave slice registry",
            "The managed coordinator sets W1's predecessor path",
        )
        for token in (
            "managedTransitionEndpointRows[]",
            "managedTransitionEndpointRowsRoot",
            "managedTransitionEndpointRowIDs",
            "endpointRowID, transitionID, operationID, action, toolID, executableID,",
            "invocationTemplateID, endpointKind, argvTemplate,",
            "allowedPlaceholderNames, resultSchema",
            "managed.<transitionID>.<queryExisting|invokeOnce|verifyExisting>",
            "exactly 45 rows",
            "exactly three rows",
            "managedTransitionEndpointRowIDs == []",
            "derives no transition contract or executable binding",
        ):
            self.assertIn(token, policy)
        for token in (
            "qinao-protected-policy-v1:<64-lowercase-hex>",
            "<transitionDirectory>/protected-command-policy-v1.json",
            "regular non-symlink mode-`0600`",
            "four-MiB",
            "queryExisting",
            "invokeOnce",
            "verifyExisting",
            "transitions 05-19",
        ):
            self.assertIn(token, coordinator)
        self.assertIn("stable-opens", coordinator)
        self.assertIn("canonical bytes", coordinator)
        self.assertIn("bootstrap manifest cannot replace a", coordinator)
        self.assertIn("transition-05-to-19 endpoint", coordinator)
        normalized_coordinator = re.sub(r"\s+", " ", coordinator)
        for schedule_position, slice_id, sequence_ordinal in (
            (12, "w6.runtime.engine-cutover", 6),
            (13, "w6.apple-lab", 7),
            (14, "w6.certification", 8),
        ):
            self.assertIn(
                f"global post-migration V2 schedule position {schedule_position} "
                f"(`{slice_id}`) and W6 `sequenceOrdinal = {sequence_ordinal}`",
                normalized_coordinator,
            )
        self.assertNotIn(
            "test_runtime_chain_occurs_between_v2_transition_twelve_and_thirteen",
            self.master,
        )
        for token in (
            "exactly these fourteen production operation rows",
            'operationID = "w6.runtime-receipt-chain"',
            'admissionKind = "runtimeChainPublication"',
            'waveSliceID = ""',
            'entrypointID = "external-admission-verifier"',
            "waveAdmissionEligible = false",
            "stateMutationEligible = false",
            "non-Wave runtime-chain operation",
        ):
            self.assertIn(token, registry)

    def test_git_tool_is_explicit_in_artifact_and_all_prepare_invocations(
        self,
    ) -> None:
        self.assertIn(
            "--git-executable ABSOLUTE_CANONICAL_GIT_EXECUTABLE",
            self.master,
        )
        self.assertIn("QINAO_GIT_EXECUTABLE", self.master)
        prepare_commands = [
            command
            for block in fenced_shell_blocks(self.master)
            for command in logical_shell_commands(block)
            if "scripts/prepare_qinao_v2_wave_candidate.py" in command
        ]
        self.assertEqual(len(prepare_commands), 14)
        for command in prepare_commands:
            self.assertEqual(command.count("--git-executable"), 1, command)
            self.assertIn('"$QINAO_GIT_EXECUTABLE"', command)

        all_shell_commands = [
            command
            for block in fenced_shell_blocks(self.master)
            for command in logical_shell_commands(block)
        ]
        self.assertEqual(naked_shell_tool_matches(self.master, {"git"}), [])
        git_wrapper_commands = [
            command
            for command in all_shell_commands
            if "scripts/" in command and "--git-executable" in command
        ]
        self.assertGreaterEqual(len(git_wrapper_commands), 15)
        for command in git_wrapper_commands:
            self.assertEqual(command.count("--git-executable"), 1, command)
            self.assertIn('"$QINAO_GIT_EXECUTABLE"', command)

        self.assertIn(
            "--git-executable,toolPath(git),--root,/candidate",
            self.master,
        )
        self.assertIn("all eleven W1 input IDs", self.master)
        self.assertIn("exactly ten rows", self.master)

    def test_security_hardening_contracts_remain_closed_across_all_runners(
        self,
    ) -> None:
        git_contract = section(
            self.master,
            "`--git-executable` is mandatory exactly once.",
            "For `report`, `verify-receipt`, `review-wave-bundle`, and `admit-wave`",
        )
        for token in (
            "root-owned",
            "every parent directory",
            "non-writable by the executing security subject",
            "stable-opened descriptor identity",
            "`PATH` absent",
        ):
            self.assertIn(token, git_contract)

        coordinator = section(
            self.master,
            "The whole admitted replay has one public entrypoint",
            "## Controlled Domain-Plan Payload W1:",
        )
        coordinator = re.sub(r"\s+", " ", coordinator)
        for token in (
            "one monotonic deadline",
            "stdout and stderr concurrently",
            "independent byte cap",
            "fresh process group",
            "SIGTERM",
            "SIGKILL",
            "process-scoped OS lock",
            "non-finite JSON",
            "closed CLI",
        ):
            self.assertIn(token, coordinator)

        artifact = section(
            self.master,
            "#### Step 6: Prove the exact physical recovery matrix",
            "#### Step 7: Execute the one W1 candidate",
        )
        artifact = re.sub(r"\s+", " ", artifact)
        for token in (
            "single shared monotonic protocol deadline",
            "FD3/FD4/FD5",
            "cannot reset the deadline",
            "stable-opened exact matrix bytes",
            "payload-tree blob",
        ):
            self.assertIn(token, artifact)

        xcode = section(
            self.master,
            "`run_nonempty_xcode_test.py` is a separate iOS runner.",
            "Add positive and mutation tests, then run:",
        )
        xcode = re.sub(r"\s+", " ", xcode)
        for token in (
            "sterile environment",
            "secure repository-external output roots",
            "summary and test tree",
            "exact target/suite/case counts",
            "fresh process group",
            "single monotonic deadline",
        ):
            self.assertIn(token, xcode)

    def test_w6_governed_xcode_wrapper_is_future_scoped_and_explicit(self) -> None:
        before_w6 = self.master[
            : self.master.index("## Controlled Domain-Plan Payload W6 Apple Lab:")
        ]
        apple = section(
            self.master,
            "## Controlled Domain-Plan Payload W6 Apple Lab:",
            "## Controlled Domain-Plan Payload W6 Certification:",
        )
        certification = self.master[
            self.master.index("## Controlled Domain-Plan Payload W6 Certification:") :
        ]
        self.assertNotIn(GOVERNED_XCODE_PROJECT, before_w6)
        self.assertNotIn(GOVERNED_XCODE_PROJECT_TEST, before_w6)
        for path in (GOVERNED_XCODE_PROJECT, GOVERNED_XCODE_PROJECT_TEST):
            self.assertIn(path, apple)
        normalized_apple = re.sub(r"\s+", " ", apple)
        self.assertIn(
            "the Apple-lab create set and its exact governed path list",
            normalized_apple,
        )

        commands = [
            command
            for block in fenced_shell_blocks(apple)
            for command in logical_shell_commands(block)
        ]
        wrapper_commands = [
            command for command in commands if GOVERNED_XCODE_PROJECT in command
        ]
        self.assertEqual(len(wrapper_commands), 3)
        self.assertEqual(
            {
                required_regex_group(
                    rf"{re.escape(GOVERNED_XCODE_PROJECT)}\s+"
                    r"(inspect|build-test|archive)",
                    command,
                    "governed Xcode wrapper subcommand",
                )
                for command in wrapper_commands
            },
            {"inspect", "build-test", "archive"},
        )
        for command in wrapper_commands:
            for option in (
                "--xcodebuild-executable",
                "--xcresulttool-executable",
                "--xcrun-executable",
                "--device-profile",
            ):
                self.assertEqual(command.count(option), 1, (option, command))
        self.assertEqual(
            naked_shell_tool_matches(
                apple,
                {"xcodebuild", "xcresulttool", "xcrun"},
            ),
            [],
        )

        for token in (
            "closed subcommand CLI",
            "sterile environment",
            "single monotonic deadline",
            "fresh process group",
            "bounded stdout/stderr",
            "secure repository-external output roots",
            "exact xcresult target/suite/case evidence",
            "signed physical-device profile",
        ):
            self.assertIn(token, normalized_apple)
        self.assertIn("scripts/run_nonempty_xcode_test.py", certification)
        self.assertIn("--require-target SampleHostTests", certification)
        self.assertEqual(
            naked_shell_tool_matches(
                certification,
                {"xcodebuild", "xcresulttool", "xcrun"},
            ),
            [],
        )

    def test_w1_swift_lab_and_w2_k3_composition_are_reachable(self) -> None:
        w1 = section(
            self.master,
            "## Controlled Domain-Plan Payload W1:",
            "## Controlled Domain-Plan Payload W2:",
        )
        for token in (
            '"ArtifactMeshDeviceLab"',
            "exactly two iOS-27 application targets",
            "BASMemory",
            "BASRuntimeCore",
            "QinaoDefaults",
            "QINAO_ARTIFACT_MESH_DEVICE_LAB",
            "QinaoArtifactMeshAssemblyError",
            "case unsupportedProtectionVersion(UInt64)",
            "package static func makeSovereignHostForTesting",
            "testOnlySovereignHostBuilder",
            "public nonisolated let committedOpenFacts",
            "BASArtifactMeshAnchorPort.swift",
        ):
            self.assertIn(token, w1)
        self.assertIn(
            "create `QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/"
            "QinaoEffectFacadeFreezeTests.swift`",
            w1,
        )

        payload_3d = section(
            w1,
            "### Payload 3D — Prove fixtures and authority admission",
            "### Payload 3E — Verify and commit",
        )
        ordered = (
            "draft the four",
            "review/sign them",
            "import all four",
            "materialize and stage",
            "write the final candidate tree",
            "prepare its deterministic commit/ref",
        )
        positions = [payload_3d.index(token) for token in ordered]
        self.assertEqual(positions, sorted(positions))
        self.assertNotIn("Gate/slice ID", w1)
        self.assertNotIn("Mandatory non-empty gate", w1)
        self.assertIn(
            'authorizedWaveSliceID == "w1.artifact-mesh-contract-freeze"',
            w1,
        )

        w2 = section(
            self.master,
            "## Controlled Domain-Plan Payload W2:",
            "## Controlled Domain-Plan Payload W3:",
        )
        for token in (
            "let governedK3Options = BASCognitiveOSBundleOptions(",
            "enableEventLog: true",
            "eventLogSQLiteURL: k3DatabaseURL",
            "`.allDisabled` and the incumbent in-memory",
            "private let cognitiveOSBundle: BASCognitiveOSBundle",
            "Qinao does not publish that\nbundle",
            "every required writer remain alive until Host",
            "sole `BASSQLiteEventLogStorage`",
        ):
            self.assertIn(token, w2)

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

    def test_source_review_closure_is_exact_executable_and_semantic(self) -> None:
        rows = source_review_closure_rows(self.master)
        self.assertEqual(set(rows), SOURCE_REVIEW_IDS)
        self.assertEqual(len(rows), 39)

        regression_ids: list[str] = []
        ambiguous = re.compile(
            r"\b(?:TBD|TODO|later|follow-up|as appropriate|etc)\b|"
            r"\bdefer(?:red)?\s+(?:fix|work|decision|resolution)\b",
            flags=re.IGNORECASE,
        )
        for finding_id, row in rows.items():
            self.assertEqual(row["status"], "confirmed", finding_id)
            self.assertRegex(
                row["owner_wave"],
                r"^[a-z0-9.+-]+/W[0-6](?:-W[0-6])?$",
                finding_id,
            )
            self.assertGreaterEqual(len(row["correction"]), 48, finding_id)
            self.assertIn("MUST", row["correction"], finding_id)
            self.assertIsNone(ambiguous.search(" ".join(row.values())), finding_id)
            self.assertNotIn("prose-only", " ".join(row.values()).lower())
            prefix = source_review_regression_prefix(finding_id)
            self.assertRegex(
                row["regression_id"],
                rf"^test_source_review_sr_{prefix}[0-9]{{2}}_[a-z0-9_]+$",
                finding_id,
            )
            regression_ids.append(row["regression_id"])
        self.assertEqual(len(regression_ids), len(set(regression_ids)))

        required_semantics = {
            "SR-M01": (
                "actual user-content store ↔ erasure owner ↔ production ACK emitter bijection",
                "ghost owner",
                "Set(BASErasureProjectionOwner.allCases)",
            ),
            "SR-M02": (
                "authorizedCompensation",
                "non-Provider",
                "K3 remains the sole outbox writer",
            ),
            "SR-M03": ("injected host sink profile", "exact-compare"),
            "SR-M04": (
                "early non-publishable",
                "never enters the manifest barrier",
            ),
            "SR-M05": (
                "exact stored-property inventory",
                "custom strict codec",
                "explicit nil encoding",
                "schema-version bump",
            ),
            "SR-M08": ("one warrant signer", "hostVersionID"),
            "SR-M09": ("default-off", "explicitly governed enabled path"),
            "SR-M11": ("production scope installer",),
            "SR-m14": (
                "dedicated rank-transition ports",
                "rank 2",
                "rank 3",
                "rank 4",
                "rank 5",
                "rank 6",
            ),
            "SR-m16": (
                "orthogonal axes decision table",
                "idempotency",
                "queryability",
                "compensatability",
                "irreversibility",
            ),
        }
        for finding_id, tokens in required_semantics.items():
            correction = rows[finding_id]["correction"]
            for token in tokens:
                self.assertIn(token, correction, (finding_id, token))

    def test_candidate_predecessor_verification_is_phase_dispatched(self) -> None:
        preparation = section(
            self.master,
            "The non-authoritative candidate-preparation utility has exactly this CLI:",
            "The utility requires `targetRef == HEAD`",
        )
        normalized_preparation = re.sub(r"\s+", " ", preparation)
        self.assertNotIn(
            "The cryptographically verified immediate predecessor",
            normalized_preparation,
        )
        for token in (
            "phase-dispatched",
            "protected-structural predecessor witness",
            "QinaoLedgerV2MigrationTerminalReceiptV1",
            "has no signer or signature fields",
            "does not claim or synthesize a signer or signature",
            "grants no admission",
            "external `wave-admission-controller` independently verifies",
            "protected claim and evidence-store authorization",
            "W2–W6",
            "Ed25519-verifies",
            "QinaoWaveAdmissionReceiptV2",
            "trusted `wave-admission-signer` role/schema",
            "derives target/base solely from `targetRefInstallation`",
        ):
            self.assertIn(token, normalized_preparation)

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

    def test_delegation_producer_origin_is_closed_and_provider_execution_is_model_only(
        self,
    ) -> None:
        expected_cases = {"rule", "search", "classicML", "human", "tool", "model"}
        expected_origin_payloads = {
            "rule": "BASArtifactID",
            "search": "BASArtifactID",
            "classicML": "BASArtifactID",
            "human": "BASArtifactID",
            "tool": "BASArtifactID",
            "model": "BASProviderExecutionRef",
        }
        required_proposal_fields = {
            "candidateKind": "BASProposalCandidateKind",
            "structuredProposalArtifactID": "BASArtifactID",
            "proposalAdmissionReceiptArtifactID": "BASArtifactID",
        }

        def validate(contents: str) -> None:
            proposal = swift_declaration_block(contents, "BASDelegationProposal")
            if "proposingProviderExecutionRef" in proposal:
                raise AssertionError(
                    "BASDelegationProposal must not require "
                    "proposingProviderExecutionRef"
                )
            proposal_fields = dict(
                re.findall(
                    r"(?m)^\s*public let ([A-Za-z_][A-Za-z0-9_]*):\s*"
                    r"([A-Za-z_][A-Za-z0-9_]*)\s*$",
                    proposal,
                )
            )
            for field, field_type in required_proposal_fields.items():
                self.assertEqual(
                    proposal_fields.get(field),
                    field_type,
                    f"BASDelegationProposal missing exact lineage field "
                    f"{field}: {field_type}",
                )
            self.assertIn(
                "public let producerOrigin: BASDelegationProducerOrigin",
                proposal,
                "BASDelegationProposal must carry the closed producer origin",
            )
            origin = swift_declaration_block(contents, "BASDelegationProducerOrigin")
            self.assertEqual(
                swift_enum_cases(origin),
                expected_cases,
                "producer-origin tags do not equal the six candidate kinds",
            )
            self.assertEqual(
                swift_enum_case_payload_types(origin),
                expected_origin_payloads,
                "every non-model producer origin must carry Artifact evidence and "
                "only model may carry a Provider execution ref",
            )
            self.assertEqual(
                contents.count("extension BASDelegationProducerOrigin: Codable {"),
                1,
                "producer origin must retain its one explicit Codable wire extension",
            )
            self.assertEqual(
                origin.count("BASProviderExecutionRef"),
                1,
                "provider execution ref is legal only for model origin",
            )
            self.assertRegex(
                origin,
                r"(?m)^\s*case model\(BASProviderExecutionRef\)\s*$",
                "the model origin must carry the sole Provider execution ref",
            )

        validate(self.master)
        mutations = {
            "drop-explicit-codable-wire": (
                "extension BASDelegationProducerOrigin: Codable {",
                "extension BASDelegationProducerOrigin {",
                "must retain its one explicit Codable wire extension",
            ),
            "replace-tool-artifact-evidence-with-string": (
                "case tool(BASArtifactID)",
                "case tool(String)",
                "every non-model producer origin must carry Artifact evidence",
            ),
            "restore-hard-provider-parent": (
                "public let producerOrigin: BASDelegationProducerOrigin",
                "public let proposingProviderExecutionRef: BASProviderExecutionRef",
                "must not require proposingProviderExecutionRef",
            ),
            "provider-ref-on-tool": (
                "case tool(BASArtifactID)",
                "case tool(BASProviderExecutionRef)",
                "every non-model producer origin must carry Artifact evidence",
            ),
            "drop-human-origin": (
                "case human(BASArtifactID)",
                "case omittedHuman(BASArtifactID)",
                "producer-origin tags do not equal the six candidate kinds",
            ),
            "drop-candidate-kind": (
                "public let candidateKind: BASProposalCandidateKind",
                "public let omittedCandidateKind: BASProposalCandidateKind",
                "missing exact lineage field candidateKind",
            ),
            "rename-structured-proposal-artifact": (
                "public let structuredProposalArtifactID: BASArtifactID",
                "public let proposalArtifactID: BASArtifactID",
                "missing exact lineage field structuredProposalArtifactID",
            ),
            "rename-admission-receipt-artifact": (
                "public let proposalAdmissionReceiptArtifactID: BASArtifactID",
                "public let admissionArtifactID: BASArtifactID",
                "missing exact lineage field proposalAdmissionReceiptArtifactID",
            ),
        }
        for label, (old, new, message) in mutations.items():
            with self.subTest(mutation=label), self.assertRaisesRegex(
                AssertionError, message
            ):
                if label == "drop-candidate-kind":
                    mutated = replace_once_in_swift_declaration(
                        self.master, "BASDelegationProposal", old, new
                    )
                else:
                    mutated = replace_once(self.master, old, new)
                validate(mutated)

    def test_capability_profiles_use_canonical_kinds_and_typed_mechanism_proofs(
        self,
    ) -> None:
        proof_payloads = {
            "deterministic": "BASProposalMechanismEvidence",
            "boundedNonLanguageLearned": "BASProposalMechanismEvidence",
            "boundedLanguageLearned": "BASProposalMechanismEvidence",
            "structuredHuman": "BASProposalMechanismEvidence",
            "languageHuman": "BASProposalMechanismEvidence",
            "structuredTool": "BASProposalMechanismEvidence",
            "languageTool": "BASProposalMechanismEvidence",
            "deterministicTool": "BASProposalMechanismEvidence",
            "openGenerativeProvider": "BASProposalMechanismEvidence",
            "boundedNonLanguageWorldModelSearch": "BASWorldModelSearchCausalProof",
        }
        candidate_rows = {
            "rule": "deterministic",
            "search": "deterministic,boundedNonLanguageWorldModelSearch",
            "classicML": "boundedNonLanguageLearned,boundedLanguageLearned",
            "human": "structuredHuman,languageHuman",
            "tool": "structuredTool,languageTool,deterministicTool",
            "model": "openGenerativeProvider",
        }
        all_proofs = ",".join(proof_payloads)
        profile_rows = {
            "fullProvider": all_proofs,
            "noGenerativeProvider": ",".join(
                proof for proof in proof_payloads if proof != "openGenerativeProvider"
            ),
            "noLanguageInference": (
                "deterministic,boundedNonLanguageLearned,structuredHuman,"
                "structuredTool,deterministicTool,boundedNonLanguageWorldModelSearch"
            ),
            "noLearnedInference": (
                "deterministic,structuredHuman,structuredTool,deterministicTool"
            ),
        }

        def validate_strict_wire(contents: str) -> None:
            try:
                wire = section(
                    contents,
                    "extension BASProposalMechanismProof: Codable {",
                    "\n}\n\npublic struct BASNonModelProposalPlan:",
                )
                coding_keys = section(
                    wire,
                    "private enum CodingKeys: String, CodingKey, CaseIterable {",
                    "\n    }\n\n    private enum Kind:",
                )
                kinds = section(
                    wire,
                    "private enum Kind: String, Codable {",
                    "\n    }\n\n    public init(from decoder: Decoder) throws {",
                )
                decoder = section(
                    wire,
                    "public init(from decoder: Decoder) throws {",
                    "\n    }\n\n    public func encode(to encoder: Encoder) throws {",
                )
                encoder = wire[
                    wire.index("public func encode(to encoder: Encoder) throws {") :
                ]
            except (AssertionError, ValueError) as error:
                raise AssertionError(
                    "mechanism proof lacks one explicit strict Codable wire"
                ) from error

            key_names = [
                name
                for line in re.findall(r"(?m)^\s*case\s+([^\n]+)$", coding_keys)
                for name in (item.strip() for item in line.split(","))
            ]
            self.assertEqual(
                key_names,
                ["kind", "evidence"],
                "mechanism proof CodingKeys must be exactly kind/evidence",
            )
            kind_names = re.findall(
                r"(?m)^\s*case\s+([A-Za-z_][A-Za-z0-9_]*)\s*$", kinds
            )
            self.assertEqual(
                kind_names,
                list(proof_payloads),
                "mechanism proof private Kind must be the exact ten-case wire",
            )
            self.assertEqual(
                decoder.count("BASContractWireValidation.exactKeySet"),
                1,
                "mechanism proof decoder must enforce one exact key set",
            )
            normalized_decoder = re.sub(r"\s+", " ", decoder)
            normalized_decoder = re.sub(r"\(\s+", "(", normalized_decoder)
            normalized_encoder = re.sub(r"\s+", " ", encoder)
            normalized_encoder = re.sub(r"\(\s+", "(", normalized_encoder)
            self.assertEqual(
                len(re.findall(r"case \.[A-Za-z_][A-Za-z0-9_]*:", decoder)),
                len(proof_payloads),
                "mechanism proof decoder must be exhaustive and branch exact",
            )
            self.assertEqual(
                len(
                    re.findall(
                        r"case \.[A-Za-z_][A-Za-z0-9_]*\(let evidence\):",
                        encoder,
                    )
                ),
                len(proof_payloads),
                "mechanism proof encoder must be exhaustive and branch exact",
            )
            for case_name, payload_type in proof_payloads.items():
                self.assertIn(
                    f"case .{case_name}: self = .{case_name}(try c.decode("
                    f"{payload_type}.self, forKey: .evidence))",
                    normalized_decoder,
                    f"mechanism proof decoder payload drifted for {case_name}",
                )
                self.assertIn(
                    f"case .{case_name}(let evidence): try c.encode("
                    f"Kind.{case_name}, forKey: .kind) "
                    "try c.encode(evidence, forKey: .evidence)",
                    normalized_encoder,
                    f"mechanism proof encoder payload drifted for {case_name}",
                )

        try:
            proof = swift_declaration_block(self.master, "BASProposalMechanismProof")
        except AssertionError as error:
            raise AssertionError(
                "missing exact typed proposal-mechanism proof contract"
            ) from error
        self.assertEqual(
            swift_enum_case_payload_types(proof),
            proof_payloads,
            "mechanism proof cases or associated evidence payloads drifted",
        )
        candidate_table = markdown_table_rows(
            self.master,
            "| candidate kind | admitted mechanism proofs |",
        )
        self.assertEqual(
            {row[0]: row[1] for row in candidate_table if len(row) == 2},
            candidate_rows,
            "candidate-to-proof table is not exact or uses pseudo candidate kinds",
        )
        self.assertEqual(
            set(candidate_rows),
            {"rule", "search", "classicML", "human", "tool", "model"},
        )
        profile_table = markdown_table_rows(
            self.master,
            "| capability profile | admitted mechanism proofs |",
        )
        self.assertEqual(
            {row[0]: row[1] for row in profile_table if len(row) == 2},
            profile_rows,
            "profile-to-proof table does not preserve the four distinct guarantees",
        )
        self.assertIn(
            "`BASProposalMechanismProof` uses one explicit `kind/evidence` strict "
            "decoder with an exact key set; synthesized enum Codable is forbidden.",
            re.sub(r"\s+", " ", self.master),
            "mechanism proof must not rely on synthesized enum Codable",
        )
        validate_strict_wire(self.master)

        proof_block = swift_declaration_block(
            self.master, "BASProposalMechanismProof"
        )

        def mutate_proof_wire(old: str, new: str) -> str:
            start = "extension BASProposalMechanismProof: Codable {"
            end = "\n}\n\npublic struct BASNonModelProposalPlan:"
            wire = start + section(self.master, start, end)
            return replace_once(self.master, wire, replace_once(wire, old, new))

        strict_wire_mutations = {
            "drop-codable-extension": lambda: replace_once(
                self.master,
                "extension BASProposalMechanismProof: Codable {",
                "extension BASProposalMechanismProof {",
            ),
            "drop-exact-key-set": lambda: mutate_proof_wire(
                "        try BASContractWireValidation.exactKeySet(\n"
                "            decoder, Set(CodingKeys.allCases.map(\\.rawValue)))\n",
                "",
            ),
            "deterministic-decodes-string": lambda: mutate_proof_wire(
                "case .deterministic:\n"
                "            self = .deterministic(try c.decode(\n"
                "                BASProposalMechanismEvidence.self, forKey: .evidence))",
                "case .deterministic:\n"
                "            self = .deterministic(try c.decode(\n"
                "                String.self, forKey: .evidence))",
            ),
            "world-search-decodes-artifact-id": lambda: mutate_proof_wire(
                "BASWorldModelSearchCausalProof.self, forKey: .evidence",
                "BASProposalMechanismEvidence.self, forKey: .evidence",
            ),
            "encoder-drops-deterministic-evidence": lambda: mutate_proof_wire(
                "        case .deterministic(let evidence):\n"
                "            try c.encode(Kind.deterministic, forKey: .kind)\n"
                "            try c.encode(evidence, forKey: .evidence)",
                "        case .deterministic:\n"
                "            try c.encode(Kind.deterministic, forKey: .kind)",
            ),
            "private-kind-drops-language-tool": lambda: mutate_proof_wire(
                "        case languageTool\n",
                "",
            ),
        }
        self.assertIn(
            "case languageTool(BASProposalMechanismEvidence)",
            proof_block,
            "public mechanism proof declaration lost languageTool",
        )
        for label, mutate in strict_wire_mutations.items():
            with self.subTest(mutation=label), self.assertRaises(AssertionError):
                validate_strict_wire(mutate())

    def test_mechanism_evidence_is_contained_strict_and_attested_without_self_reference(
        self,
    ) -> None:
        expected_determinism_cases = {
            "deterministic",
            "boundedNondeterministic",
            "externallySupplied",
            "providerOpaque",
        }
        expected_fields = {
            "mechanismArtifactID": "BASArtifactID",
            "mechanismID": "String",
            "mechanismVersion": "String",
            "codeOrModelDigest": "String",
            "determinismClass": "BASProposalMechanismDeterminismClass",
            "usesLanguageInference": "Bool",
            "usesLearnedInference": "Bool",
            "mayOpenGenerate": "Bool",
            "resourceClosureRoot": "String",
            "certificationReceiptArtifactID": "BASArtifactID",
        }
        try:
            determinism = swift_declaration_block(
                self.master, "BASProposalMechanismDeterminismClass"
            )
            evidence = swift_declaration_block(
                self.master, "BASProposalMechanismEvidence"
            )
        except AssertionError as error:
            raise AssertionError(
                "missing contained mechanism evidence and exact determinism wire"
            ) from error

        determinism_head = determinism.split("{", 1)[0]
        for conformance in ("String", "Codable", "Sendable", "Equatable"):
            self.assertIn(
                conformance,
                determinism_head,
                "mechanism determinism class must be a stable raw Codable value",
            )
        self.assertEqual(
            swift_enum_cases(determinism),
            expected_determinism_cases,
            "mechanism determinism class must have exactly four raw cases",
        )
        self.assertEqual(
            swift_stored_property_types(evidence),
            expected_fields,
            "contained mechanism evidence must expose the exact ten typed fields",
        )
        normalized_evidence = re.sub(r"\s+", " ", evidence)
        self.assertRegex(
            normalized_evidence,
            r"public init\(\s*mechanismArtifactID: BASArtifactID, mechanismID: String, "
            r"mechanismVersion: String, codeOrModelDigest: String, "
            r"determinismClass: BASProposalMechanismDeterminismClass, "
            r"usesLanguageInference: Bool, usesLearnedInference: Bool, "
            r"mayOpenGenerate: Bool, resourceClosureRoot: String, "
            r"certificationReceiptArtifactID: BASArtifactID\s*\) throws",
            "contained mechanism evidence needs one cross-module validating initializer",
        )
        try:
            coding_keys = section(
                evidence,
                "private enum CodingKeys: String, CodingKey, CaseIterable {",
                "\n    }\n\n    public init(from decoder: Decoder) throws {",
            )
            decoder = evidence[
                evidence.index("public init(from decoder: Decoder) throws {") :
            ]
        except (AssertionError, ValueError) as error:
            raise AssertionError(
                "contained mechanism evidence lacks one strict decoder"
            ) from error
        key_names = [
            name
            for line in re.findall(r"(?m)^\s*case\s+([^\n]+)$", coding_keys)
            for name in (item.strip() for item in line.split(","))
        ]
        self.assertEqual(
            key_names,
            list(expected_fields),
            "contained mechanism evidence CodingKeys must equal its ten fields",
        )
        self.assertEqual(
            decoder.count("BASContractWireValidation.exactKeySet"),
            1,
            "contained mechanism evidence decoder must reject unknown/missing keys",
        )
        self.assertEqual(
            decoder.count("try self.init("),
            1,
            "contained mechanism evidence decoder must reuse the validating initializer",
        )
        self.assertEqual(
            re.findall(r"(?m)^\s*self\.[A-Za-z_][A-Za-z0-9_]*\s*=", decoder),
            [],
            "contained mechanism evidence decoder must not bypass validation",
        )
        normalized_decoder = re.sub(r"\s+", " ", decoder)
        normalized_decoder = re.sub(r"\(\s+", "(", normalized_decoder)
        for field, field_type in expected_fields.items():
            self.assertIn(
                f"{field}: c.decode({field_type}.self, forKey: .{field})",
                normalized_decoder,
                f"contained mechanism evidence decoder type drifted for {field}",
            )

    def test_mechanism_attestation_preimage_is_non_circular_and_profile_independent(
        self,
    ) -> None:
        attestation_contract = (
            "Reopen `certificationReceiptArtifactID` as the incumbent "
            "`BASArtifactAttestationPayload`; its target is `mechanismArtifactID`, "
            "and its signed-statement preimage binds the proof kind plus the first "
            "nine evidence fields from `mechanismArtifactID` through "
            "`resourceClosureRoot`. It excludes `certificationReceiptArtifactID` "
            "itself to avoid a content-addressed self-reference; the downstream "
            "proof/plan canonical digest binds all ten fields. Capability-profile "
            "compatibility remains a separate pure admission check and is not "
            "duplicated into the certification."
        )
        self.assertIn(
            attestation_contract,
            re.sub(r"\s+", " ", self.master),
            "mechanism attestation must be non-circular and profile-independent",
        )

    def test_candidate_kind_has_one_exact_public_raw_declaration(self) -> None:
        try:
            candidate_kind = swift_declaration_block(
                self.master, "BASProposalCandidateKind"
            )
        except AssertionError as error:
            raise AssertionError(
                "BASProposalCandidateKind is referenced but has no exact declaration"
            ) from error
        declaration_head = candidate_kind.split("{", 1)[0]
        for conformance in ("String", "Codable", "Sendable", "Equatable"):
            self.assertIn(
                conformance,
                declaration_head,
                "candidate kind must be one stable public raw Codable enum",
            )
        self.assertEqual(
            swift_enum_cases(candidate_kind),
            {"rule", "search", "classicML", "human", "tool", "model"},
            "candidate kind declaration must contain exactly the canonical six cases",
        )

    def test_cross_module_proposal_values_have_explicit_public_initializers(
        self,
    ) -> None:
        cross_module_values = (
            "BASWorldModelSearchCausalProof",
            "BASProposalMechanismEvidence",
            "BASNonModelProposalPlan",
            "BASNonModelProposalInput",
            "BASR4DenseLaneAvailabilityReceipt",
            "BASR5ProducerAvailabilityReceipt",
            "BASSuperstepSevenProviderWork",
            "BASSuperstepSevenNonProviderWork",
            "BASSuperstepSevenNoWorkEvidence",
        )
        for symbol in cross_module_values:
            with self.subTest(symbol=symbol):
                try:
                    declaration = swift_declaration_block(self.master, symbol)
                except AssertionError as error:
                    raise AssertionError(
                        f"missing cross-module value declaration {symbol}"
                    ) from error
                self.assertRegex(
                    declaration,
                    r"(?s)\bpublic\s+init\(\s*(?!from\b)[A-Za-z_]",
                    f"{symbol} needs an explicit public construction initializer",
                )

    def test_superstep_seven_has_one_profile_work_proof_validator_and_typed_no_work(
        self,
    ) -> None:
        expected_provider_fields = {
            "providerExecutionRef": "BASProviderExecutionRef",
            "mechanismProof": "BASProposalMechanismProof",
            "workReceiptArtifactID": "BASArtifactID",
        }
        expected_non_provider_fields = {
            "candidateKind": "BASProposalCandidateKind",
            "mechanismProof": "BASProposalMechanismProof",
            "workReceiptArtifactID": "BASArtifactID",
        }
        expected_no_work_fields = {
            "notRequiredDispositionReceiptArtifactID": "BASArtifactID",
        }
        matrix_rows = {
            "fullProvider": (
                "providerPrefillDecode:openGenerativeProvider;"
                "boundedInference:boundedNonLanguageLearned,boundedLanguageLearned,"
                "boundedNonLanguageWorldModelSearch;deterministicProposal:deterministic;"
                "humanOrTool:structuredHuman,languageHuman,structuredTool,languageTool,"
                "deterministicTool;noWork:notRequired"
            ),
            "noGenerativeProvider": (
                "boundedInference:boundedNonLanguageLearned,boundedLanguageLearned,"
                "boundedNonLanguageWorldModelSearch;deterministicProposal:deterministic;"
                "humanOrTool:structuredHuman,languageHuman,structuredTool,languageTool,"
                "deterministicTool;noWork:notRequired"
            ),
            "noLanguageInference": (
                "boundedInference:boundedNonLanguageLearned,"
                "boundedNonLanguageWorldModelSearch;deterministicProposal:deterministic;"
                "humanOrTool:structuredHuman,structuredTool,deterministicTool;"
                "noWork:notRequired"
            ),
            "noLearnedInference": (
                "deterministicProposal:deterministic;"
                "humanOrTool:structuredHuman,structuredTool,deterministicTool;"
                "noWork:notRequired"
            ),
        }
        execution_payloads = {
            "providerPrefillDecode": "BASSuperstepSevenProviderWork",
            "boundedInference": "BASSuperstepSevenNonProviderWork",
            "deterministicProposal": "BASSuperstepSevenNonProviderWork",
            "humanOrTool": "BASSuperstepSevenNonProviderWork",
            "noWork": "BASSuperstepSevenNoWorkEvidence",
        }

        def validate_strict_wire_and_compatibility(contents: str) -> None:
            try:
                wire = section(
                    contents,
                    "extension BASSuperstepSevenExecutionKind: Codable {",
                    "\n}\n\npublic struct BASSuperstepSevenProviderWork:",
                )
                coding_keys = section(
                    wire,
                    "private enum CodingKeys: String, CodingKey, CaseIterable {",
                    "\n    }\n\n    private enum Kind:",
                )
                kinds = section(
                    wire,
                    "private enum Kind: String, Codable {",
                    "\n    }\n\n    public init(from decoder: Decoder) throws {",
                )
                decoder = section(
                    wire,
                    "public init(from decoder: Decoder) throws {",
                    "\n    }\n\n    public func encode(to encoder: Encoder) throws {",
                )
                encoder = wire[
                    wire.index("public func encode(to encoder: Encoder) throws {") :
                ]
                receipt_block = swift_declaration_block(
                    contents, "BASSuperstepSevenObservationReceipt"
                )
                compatibility = section(
                    receipt_block,
                    "package static func validateProfileWorkCompatibility(",
                    "\n    private enum CodingKeys:",
                )
            except (AssertionError, ValueError) as error:
                raise AssertionError(
                    "superstep-7 lacks one strict wire and compatibility validator"
                ) from error

            key_names = [
                name
                for line in re.findall(r"(?m)^\s*case\s+([^\n]+)$", coding_keys)
                for name in (item.strip() for item in line.split(","))
            ]
            self.assertEqual(
                key_names,
                ["kind", "evidence"],
                "superstep-7 CodingKeys must be exactly kind/evidence",
            )
            self.assertEqual(
                re.findall(
                    r"(?m)^\s*case\s+([A-Za-z_][A-Za-z0-9_]*)\s*$", kinds
                ),
                list(execution_payloads),
                "superstep-7 private Kind must be the exact five-case wire",
            )
            self.assertEqual(
                decoder.count("BASContractWireValidation.exactKeySet"),
                1,
                "superstep-7 decoder must enforce one exact key set",
            )
            normalized_decoder = re.sub(r"\s+", " ", decoder)
            normalized_decoder = re.sub(r"\(\s+", "(", normalized_decoder)
            normalized_encoder = re.sub(r"\s+", " ", encoder)
            normalized_encoder = re.sub(r"\(\s+", "(", normalized_encoder)
            self.assertEqual(
                len(re.findall(r"case \.[A-Za-z_][A-Za-z0-9_]*:", decoder)),
                len(execution_payloads),
                "superstep-7 decoder must be exhaustive and branch exact",
            )
            self.assertEqual(
                len(
                    re.findall(
                        r"case \.[A-Za-z_][A-Za-z0-9_]*\(let work\):", encoder
                    )
                ),
                len(execution_payloads),
                "superstep-7 encoder must be exhaustive and branch exact",
            )
            for case_name, payload_type in execution_payloads.items():
                self.assertIn(
                    f"case .{case_name}: self = .{case_name}(try c.decode("
                    f"{payload_type}.self, forKey: .evidence))",
                    normalized_decoder,
                    f"superstep-7 decoder payload drifted for {case_name}",
                )
                self.assertIn(
                    f"case .{case_name}(let work): try c.encode(Kind.{case_name}, "
                    "forKey: .kind) try c.encode(work, forKey: .evidence)",
                    normalized_encoder,
                    f"superstep-7 encoder payload drifted for {case_name}",
                )

            normalized_compatibility = re.sub(r"\s+", " ", compatibility)
            self.assertEqual(
                normalized_compatibility.count(
                    "case (.fullProvider, .providerPrefillDecode(let evidence)):"
                ),
                1,
                "provider prefill/decode must be fullProvider-only",
            )
            self.assertNotIn(
                ".noGenerativeProvider, .providerPrefillDecode",
                normalized_compatibility,
                "noGenerativeProvider must reject provider prefill/decode",
            )
            no_language_bounded = section(
                compatibility,
                "case (.noLanguageInference, .boundedInference(let evidence)):",
                "\n        case (.fullProvider, .deterministicProposal",
            )
            self.assertNotIn(
                ".boundedLanguageLearned",
                no_language_bounded,
                "noLanguageInference must reject bounded language inference",
            )
            for allowed in (
                "(.classicML, .boundedNonLanguageLearned)",
                "(.search, .boundedNonLanguageWorldModelSearch)",
            ):
                self.assertIn(
                    allowed,
                    no_language_bounded,
                    "noLanguageInference bounded work matrix drifted",
                )
            self.assertEqual(
                compatibility.count("case (_, .noWork):"),
                1,
                "typed noWork must be legal for every capability profile",
            )
            self.assertEqual(
                compatibility.count("guard compatible else {"),
                1,
                "superstep-7 compatibility result must fail closed",
            )
        try:
            provider = swift_declaration_block(
                self.master, "BASSuperstepSevenProviderWork"
            )
            non_provider = swift_declaration_block(
                self.master, "BASSuperstepSevenNonProviderWork"
            )
            no_work = swift_declaration_block(
                self.master, "BASSuperstepSevenNoWorkEvidence"
            )
            receipt = swift_declaration_block(
                self.master, "BASSuperstepSevenObservationReceipt"
            )
        except AssertionError as error:
            raise AssertionError(
                "missing typed superstep-7 work/no-work compatibility contract"
            ) from error
        self.assertEqual(
            swift_stored_property_types(provider), expected_provider_fields
        )
        self.assertEqual(
            swift_stored_property_types(non_provider), expected_non_provider_fields
        )
        self.assertEqual(swift_stored_property_types(no_work), expected_no_work_fields)
        rows = markdown_table_rows(
            self.master,
            "| capability profile | legal superstep-7 work and proof |",
        )
        self.assertEqual(
            {row[0]: row[1] for row in rows if len(row) == 2},
            matrix_rows,
            "profile/work/candidate/mechanism proof matrix is not exact",
        )
        self.assertIn("init(from decoder: Decoder)", receipt)
        self.assertGreaterEqual(
            receipt.count("validateProfileWorkCompatibility"),
            3,
            "initializer and strict decoder must reuse the one compatibility validator",
        )
        self.assertIn(
            "A noWork observation is admitted only after reopening the exact current "
            "notRequired disposition receipt and proving it is neither unavailable nor "
            "coverageDeficit.",
            re.sub(r"\s+", " ", self.master),
            "noWork must reopen typed notRequired evidence",
        )
        self.assertIn(
            "Every superstep-7 provider or non-provider work receipt is reopened and "
            "must match the outer TurnOperation, Attempt, candidate kind, mechanism "
            "proof, Context Packet digest, and capability profile.",
            re.sub(r"\s+", " ", self.master),
            "superstep work evidence must match the outer receipt lineage",
        )
        self.assertIn(
            "`BASSuperstepSevenExecutionKind` also uses an explicit strict tagged "
            "decoder; synthesized enum Codable cannot bypass profile/work validation.",
            re.sub(r"\s+", " ", self.master),
            "nested superstep work must use a strict tagged decoder",
        )
        validate_strict_wire_and_compatibility(self.master)

        def mutate_superstep_wire(old: str, new: str) -> str:
            start = "extension BASSuperstepSevenExecutionKind: Codable {"
            end = "\n}\n\npublic struct BASSuperstepSevenProviderWork:"
            wire = start + section(self.master, start, end)
            return replace_once(self.master, wire, replace_once(wire, old, new))

        def mutate_compatibility(old: str, new: str) -> str:
            receipt_block = swift_declaration_block(
                self.master, "BASSuperstepSevenObservationReceipt"
            )
            mutated_receipt = replace_once(receipt_block, old, new)
            return replace_once(self.master, receipt_block, mutated_receipt)

        strict_superstep_mutations = {
            "drop-codable-extension": lambda: replace_once(
                self.master,
                "extension BASSuperstepSevenExecutionKind: Codable {",
                "extension BASSuperstepSevenExecutionKind {",
            ),
            "drop-exact-key-set": lambda: mutate_superstep_wire(
                "        try BASContractWireValidation.exactKeySet(\n"
                "            decoder, Set(CodingKeys.allCases.map(\\.rawValue)))\n",
                "",
            ),
            "no-work-decodes-non-provider-work": lambda: mutate_superstep_wire(
                "BASSuperstepSevenNoWorkEvidence.self, forKey: .evidence",
                "BASSuperstepSevenNonProviderWork.self, forKey: .evidence",
            ),
            "no-work-becomes-full-provider-only": lambda: mutate_compatibility(
                "case (_, .noWork):",
                "case (.fullProvider, .noWork):",
            ),
            "no-generative-allows-provider-prefill": lambda: mutate_compatibility(
                "case (.fullProvider, .providerPrefillDecode(let evidence)):",
                "case (.fullProvider, .providerPrefillDecode(let evidence)),\n"
                "             (.noGenerativeProvider, "
                ".providerPrefillDecode(let evidence)):",
            ),
            "no-language-allows-bounded-language": lambda: mutate_compatibility(
                "case (.classicML, .boundedNonLanguageLearned),\n"
                "                 (.search, .boundedNonLanguageWorldModelSearch):",
                "case (.classicML, .boundedNonLanguageLearned),\n"
                "                 (.classicML, .boundedLanguageLearned),\n"
                "                 (.search, .boundedNonLanguageWorldModelSearch):",
            ),
            "compatibility-guard-bypassed": lambda: mutate_compatibility(
                "guard compatible else {",
                "guard true else {",
            ),
        }
        for label, mutate in strict_superstep_mutations.items():
            with self.subTest(mutation=label), self.assertRaises(AssertionError):
                validate_strict_wire_and_compatibility(mutate())

    def test_non_model_plan_is_contained_and_world_model_search_binds_two_edges(
        self,
    ) -> None:
        plan_fields = {
            "candidateKind": "BASProposalCandidateKind",
            "mechanismProof": "BASProposalMechanismProof",
            "planDigest": "String",
            "algorithmOrCapabilityArtifactID": "BASArtifactID",
            "boundedResourcePolicyArtifactID": "BASArtifactID",
            "expectedOutputSchemaArtifactID": "BASArtifactID",
            "orderedCausalParentArtifactIDs": "[BASArtifactID]",
        }
        input_fields = {
            "profile": "BASNonModelProposalInputProfile",
            "structuredContextPacketDigest": "String",
            "selectedPlan": "BASNonModelProposalPlan",
        }
        causal_fields = {
            "mechanismEvidence": "BASProposalMechanismEvidence",
            "boundedInferenceReceiptArtifactID": "BASArtifactID",
            "predictionEvidenceArtifactID": "BASArtifactID",
            "searchPlanArtifactID": "BASArtifactID",
            "nonLanguageCertificationArtifactID": "BASArtifactID",
        }
        try:
            selected_plan = swift_declaration_block(
                self.master, "BASNonModelProposalPlan"
            )
            proposal_input = swift_declaration_block(
                self.master, "BASNonModelProposalInput"
            )
            causal_proof = swift_declaration_block(
                self.master, "BASWorldModelSearchCausalProof"
            )
        except AssertionError as error:
            raise AssertionError(
                "missing contained non-model plan or world-model/search causal proof"
            ) from error
        self.assertEqual(swift_stored_property_types(selected_plan), plan_fields)
        self.assertEqual(swift_stored_property_types(proposal_input), input_fields)
        self.assertEqual(swift_stored_property_types(causal_proof), causal_fields)
        scoped = selected_plan + proposal_input
        for forbidden in (
            "BASExecutionPlan",
            "executionPlanArtifactID",
            "providerExecutionRef",
            "providerStep",
            "modelIdentityArtifactID",
            "modelProfileArtifactID",
            "tokenizerID",
            "promptArtifactID",
            "privateKVArtifactID",
        ):
            self.assertNotIn(forbidden, scoped, f"non-model plan contains {forbidden}")
        self.assertIn(
            "Reopen proves exactly two causal edges: "
            "`boundedInferenceReceiptArtifactID -> predictionEvidenceArtifactID` and "
            "`predictionEvidenceArtifactID -> searchPlanArtifactID`; the search plan's "
            "exact ordered parent is the same prediction evidence.",
            re.sub(r"\s+", " ", self.master),
            "world-model plus search must reopen both causal edges",
        )

    def test_post_compile_materialization_is_kind_tagged_and_non_model_tokenless(
        self,
    ) -> None:
        expected_cases = {"rule", "search", "classicML", "human", "tool", "model"}
        expected_materialization_payloads = {
            "rule": "BASNonModelProposalInput",
            "search": "BASNonModelProposalInput",
            "classicML": "BASNonModelProposalInput",
            "human": "BASNonModelProposalInput",
            "tool": "BASNonModelProposalInput",
            "model": "BASExactCompiledContext",
        }
        expected_profiles = {
            "structuredPacketDirect",
            "tensorState",
            "constraintGraph",
            "programIR",
            "policyState",
        }
        expected_non_model_fields = {
            "profile": "BASNonModelProposalInputProfile",
            "structuredContextPacketDigest": "String",
            "selectedPlan": "BASNonModelProposalPlan",
        }

        def validate(contents: str) -> None:
            try:
                materialization = swift_declaration_block(
                    contents, "BASProposalInputMaterialization"
                )
                non_model = swift_declaration_block(
                    contents, "BASNonModelProposalInput"
                )
                profiles = swift_declaration_block(
                    contents, "BASNonModelProposalInputProfile"
                )
            except AssertionError as error:
                raise AssertionError(
                    "missing closed post-compile proposal-input materialization contract"
                ) from error
            self.assertEqual(
                swift_enum_cases(materialization),
                expected_cases,
                "proposal-input materialization tags do not equal the six candidate kinds",
            )
            self.assertEqual(
                swift_enum_case_payload_types(materialization),
                expected_materialization_payloads,
                "proposal-input materialization payloads are not branch exact",
            )
            self.assertEqual(
                swift_enum_cases(profiles),
                expected_profiles,
                "technique-neutral proposal-input profiles are not the exact closed five",
            )
            for binding in (
                "structuredContextPacketDigest",
                "selectedPlan",
            ):
                self.assertIn(
                    binding,
                    non_model,
                    "proposal materialization must retain one packet and one execution spine",
                )
            forbidden = (
                "providerStep",
                "providerExecutionRef",
                "prompt",
                "tokenizer",
                "tokenIDs",
                "privateKV",
            )
            offenders = [field for field in forbidden if field in non_model]
            self.assertEqual(
                offenders,
                [],
                "non-model materialization contains model-only fields",
            )
            self.assertEqual(
                swift_stored_property_types(non_model),
                expected_non_model_fields,
                "non-model materialization must have the exact typed packet/profile/plan spine",
            )
            self.assertEqual(
                len(
                    re.findall(
                        r"(?m)^\s*case model\(BASExactCompiledContext\)\s*$",
                        materialization,
                    )
                ),
                1,
                "the model tag must reuse the incumbent exact compiled context",
            )
            self.assertNotIn(
                "BASModelMaterializedContext",
                contents,
                "a second model materialization aggregate is forbidden",
            )
            declaration_head = materialization.split("{", 1)[0]
            self.assertNotIn(
                "Codable",
                declaration_head,
                "ephemeral proposal-input materialization must not be serializable",
            )

        validate(self.master)
        mutations = {
            "tool-uses-untyped-payload": (
                "case tool(BASNonModelProposalInput)",
                "case tool(String)",
                "payloads are not branch exact",
            ),
            "classic-ml-uses-model-payload": (
                "case classicML(BASNonModelProposalInput)",
                "case classicML(BASExactCompiledContext)",
                "payloads are not branch exact",
            ),
            "drop-tensor-state-profile": (
                "case tensorState",
                "case omittedTensorState",
                "technique-neutral proposal-input profiles are not the exact closed five",
            ),
            "add-tokenizer-to-non-model": (
                "public let selectedPlan: BASNonModelProposalPlan",
                "public let selectedPlan: BASNonModelProposalPlan\n"
                "    public let tokenizerID: String",
                "non-model materialization contains model-only fields",
            ),
            "selected-plan-loses-contained-type": (
                "public let selectedPlan: BASNonModelProposalPlan",
                "public let selectedPlan: String",
                "must have the exact typed packet/profile/plan spine",
            ),
        }
        for label, (old, new, message) in mutations.items():
            with self.subTest(mutation=label), self.assertRaisesRegex(
                AssertionError, message
            ):
                validate(replace_once(self.master, old, new))

    def test_capability_profiles_have_exact_distinct_candidate_grounding_availability_matrices(
        self,
    ) -> None:
        expected_profiles = {
            "fullProvider",
            "noGenerativeProvider",
            "noLanguageInference",
            "noLearnedInference",
        }
        header = (
            "| profile | candidate kinds | grounding branches | "
            "open-language availability |"
        )
        frozen_attempt_contract = (
            "The selected `BASCapabilityExecutionProfile` is frozen for the "
            "complete Attempt; same-Attempt profile replacement is forbidden. "
            "A capability change returns typed unavailable or starts a new Attempt."
        )
        expected_rows = {
            "fullProvider": (
                "rule,search,classicML,human,tool,model",
                "model,boundedInference,deterministic,humanOrTool,notRequired",
                "availableOrTypedUnavailable",
            ),
            "noGenerativeProvider": (
                "rule,search,classicML,human,tool",
                "boundedInference,deterministic,humanOrTool,notRequired",
                "externalProducerRequired",
            ),
            "noLanguageInference": (
                "rule,search,classicML,human,tool",
                "boundedInference,deterministic,humanOrTool,notRequired",
                "externalProducerRequired",
            ),
            "noLearnedInference": (
                "rule,search,human,tool",
                "deterministic,humanOrTool,notRequired",
                "externalProducerRequired",
            ),
        }

        def validate(contents: str) -> None:
            try:
                declaration = swift_declaration_block(
                    contents, "BASCapabilityExecutionProfile"
                )
            except AssertionError as error:
                raise AssertionError(
                    "capability-profile tags are not the exact closed four"
                ) from error
            self.assertEqual(
                swift_enum_cases(declaration),
                expected_profiles,
                "capability-profile tags are not the exact closed four",
            )
            rows = markdown_table_rows(contents, header)
            parsed = {row[0]: tuple(row[1:]) for row in rows if len(row) == 4}
            self.assertEqual(
                parsed,
                expected_rows,
                "capability profiles collapse distinct execution guarantees",
            )
            self.assertIn(
                frozen_attempt_contract,
                re.sub(r"\s+", " ", contents),
                "capability profile must be frozen for the complete Attempt",
            )
            self.assertIn(
                "`waitingForModel` is legal only under `fullProvider` and only "
                "while an admitted recoverable model plan remains current.",
                re.sub(r"\s+", " ", contents),
                "waitingForModel must be fullProvider-only and recovery-bound",
            )

        validate(self.master)
        mutations = {
            "collapse-no-language-into-no-generative": (
                "| `noLanguageInference` |",
                "| `noGenerativeProvider` |",
                "collapse distinct execution guarantees",
            ),
            "permit-model-without-generative-provider": (
                "rule,search,classicML,human,tool` |",
                "rule,search,classicML,human,tool,model` |",
                "collapse distinct execution guarantees",
            ),
            "permit-classic-ml-without-learned-inference": (
                "rule,search,human,tool` |",
                "rule,search,classicML,human,tool` |",
                "collapse distinct execution guarantees",
            ),
            "permit-model-without-learned-inference": (
                "rule,search,human,tool` |",
                "rule,search,human,tool,model` |",
                "collapse distinct execution guarantees",
            ),
            "allow-same-attempt-profile-switch": (
                "same-Attempt profile replacement is forbidden",
                "same-Attempt profile replacement is permitted",
                "must be frozen for the complete Attempt",
            ),
        }
        for label, (old, new, message) in mutations.items():
            with self.subTest(mutation=label), self.assertRaisesRegex(
                AssertionError, message
            ):
                validate(replace_once(self.master, old, new))

    def test_no_language_inference_requires_typed_r4_r5_disposition_receipts(
        self,
    ) -> None:
        expected_dispositions = {
            "available",
            "unavailable",
            "notRequired",
            "coverageDeficit",
        }
        expected_disposition_payloads = {
            "available": "BASArtifactID",
            "unavailable": "BASArtifactID",
            "notRequired": "BASArtifactID",
            "coverageDeficit": "BASArtifactID",
        }
        required_fields = {
            "turnOperationRef": "BASTurnOperationRef",
            "attemptRefArtifactID": "BASArtifactID",
            "snapshotRoot": "String",
            "phaseEpoch": "UInt64",
            "capabilityProfile": "BASCapabilityExecutionProfile",
            "disposition": "BASLaneAvailabilityDisposition",
        }
        header = "| phase | required receipt | forbidden fallback |"
        durable_reopen_contract = (
            "R4 and R5 cannot advance until their exact current disposition "
            "receipt is durably committed and reopened."
        )
        expected_rows = {
            "R4 dense_semantic": (
                "BASR4DenseLaneAvailabilityReceipt",
                "silentRunOrSilentSkip",
            ),
            "R5 dedupe_fusion_bounded_grounding_proposal": (
                "BASR5ProducerAvailabilityReceipt",
                "unavailableAsNotRequiredOrCrossBranch",
            ),
        }

        def validate(contents: str) -> None:
            try:
                disposition = swift_declaration_block(
                    contents, "BASLaneAvailabilityDisposition"
                )
                receipts = {
                    name: swift_declaration_block(contents, name)
                    for name in (
                        "BASR4DenseLaneAvailabilityReceipt",
                        "BASR5ProducerAvailabilityReceipt",
                    )
                }
            except AssertionError as error:
                raise AssertionError(
                    "missing typed R4 dense-lane / R5 producer disposition receipts"
                ) from error
            self.assertEqual(
                swift_enum_cases(disposition),
                expected_dispositions,
                "R4/R5 unavailable, notRequired, and coverage deficit must remain distinct",
            )
            self.assertEqual(
                swift_enum_case_payload_types(disposition),
                expected_disposition_payloads,
                "every R4/R5 disposition must carry exact Artifact evidence",
            )
            for name, block in receipts.items():
                self.assertEqual(
                    swift_stored_property_types(block),
                    required_fields,
                    f"{name} is not fully operation/snapshot/profile bound",
                )
            rows = markdown_table_rows(contents, header)
            parsed = {row[0]: tuple(row[1:]) for row in rows if len(row) == 3}
            self.assertEqual(
                parsed,
                expected_rows,
                "R4/R5 phase can silently run, skip, or substitute a branch",
            )
            self.assertIn(
                durable_reopen_contract,
                re.sub(r"\s+", " ", contents),
                "R4/R5 phase must not advance before durable receipt reopen",
            )

        validate(self.master)
        mutations = {
            "unavailable-loses-artifact-evidence": (
                "case unavailable(BASArtifactID)",
                "case unavailable",
                "must carry exact Artifact evidence",
            ),
            "unavailable-becomes-not-required": (
                "case unavailable(BASArtifactID)",
                "case unavailableAsNotRequired(BASArtifactID)",
                "must remain distinct",
            ),
            "drop-coverage-deficit": (
                "case coverageDeficit",
                "case omittedCoverageDeficit",
                "must remain distinct",
            ),
            "allow-silent-r4-skip": (
                "silentRunOrSilentSkip` |",
                "none` |",
                "silently run, skip, or substitute",
            ),
            "advance-without-durable-reopen": (
                durable_reopen_contract,
                "R4 and R5 may advance without a current disposition receipt.",
                "must not advance before durable receipt reopen",
            ),
            "r4-snapshot-root-loses-string-type": (
                "public struct BASR4DenseLaneAvailabilityReceipt:\n"
                "    Codable, Sendable, Equatable {\n"
                "    public let turnOperationRef: BASTurnOperationRef\n"
                "    public let attemptRefArtifactID: BASArtifactID\n"
                "    public let snapshotRoot: String",
                "public struct BASR4DenseLaneAvailabilityReceipt:\n"
                "    Codable, Sendable, Equatable {\n"
                "    public let turnOperationRef: BASTurnOperationRef\n"
                "    public let attemptRefArtifactID: BASArtifactID\n"
                "    public let snapshotRoot: Bool",
                "not fully operation/snapshot/profile bound",
            ),
            "r5-disposition-loses-closed-type": (
                "public struct BASR5ProducerAvailabilityReceipt:\n"
                "    Codable, Sendable, Equatable {\n"
                "    public let turnOperationRef: BASTurnOperationRef\n"
                "    public let attemptRefArtifactID: BASArtifactID\n"
                "    public let snapshotRoot: String\n"
                "    public let phaseEpoch: UInt64\n"
                "    public let capabilityProfile: BASCapabilityExecutionProfile\n"
                "    public let disposition: BASLaneAvailabilityDisposition",
                "public struct BASR5ProducerAvailabilityReceipt:\n"
                "    Codable, Sendable, Equatable {\n"
                "    public let turnOperationRef: BASTurnOperationRef\n"
                "    public let attemptRefArtifactID: BASArtifactID\n"
                "    public let snapshotRoot: String\n"
                "    public let phaseEpoch: UInt64\n"
                "    public let capabilityProfile: BASCapabilityExecutionProfile\n"
                "    public let disposition: String",
                "not fully operation/snapshot/profile bound",
            ),
        }
        for label, (old, new, message) in mutations.items():
            with self.subTest(mutation=label), self.assertRaisesRegex(
                AssertionError, message
            ):
                validate(replace_once(self.master, old, new))

    def test_superstep_seven_observation_is_branch_exact_and_provider_ref_is_model_only(
        self,
    ) -> None:
        expected_execution_kinds = {
            "providerPrefillDecode",
            "boundedInference",
            "deterministicProposal",
            "humanOrTool",
            "noWork",
        }
        expected_execution_payloads = {
            "providerPrefillDecode": "BASSuperstepSevenProviderWork",
            "boundedInference": "BASSuperstepSevenNonProviderWork",
            "deterministicProposal": "BASSuperstepSevenNonProviderWork",
            "humanOrTool": "BASSuperstepSevenNonProviderWork",
            "noWork": "BASSuperstepSevenNoWorkEvidence",
        }
        required_fields = {
            "turnOperationRef": "BASTurnOperationRef",
            "attemptRefArtifactID": "BASArtifactID",
            "structuredContextPacketDigest": "String",
            "capabilityProfile": "BASCapabilityExecutionProfile",
            "superstepOrdinal": "UInt8",
            "work": "BASSuperstepSevenExecutionKind",
        }

        def validate(contents: str) -> None:
            try:
                execution_kind = swift_declaration_block(
                    contents, "BASSuperstepSevenExecutionKind"
                )
                provider_work = swift_declaration_block(
                    contents, "BASSuperstepSevenProviderWork"
                )
                receipt = swift_declaration_block(
                    contents, "BASSuperstepSevenObservationReceipt"
                )
            except AssertionError as error:
                raise AssertionError(
                    "missing branch-exact superstep-7 execution and observation contract"
                ) from error
            self.assertEqual(
                swift_enum_cases(execution_kind),
                expected_execution_kinds,
                "superstep-7 work tags are not the exact closed five",
            )
            self.assertEqual(
                swift_stored_property_types(provider_work).get(
                    "providerExecutionRef"
                ),
                "BASProviderExecutionRef",
                "Provider execution ref is legal only for providerPrefillDecode",
            )
            self.assertNotIn("BASProviderExecutionRef", execution_kind)
            self.assertEqual(
                swift_enum_case_payload_types(execution_kind),
                expected_execution_payloads,
                "every non-Provider superstep-7 branch must carry Artifact evidence",
            )
            self.assertEqual(
                swift_stored_property_types(receipt),
                required_fields,
                "noWork observation is not fully lineage-bound",
            )
            for token in (
                "Prefill and Decode",
                "superstepOrdinal == 7",
                "work",
            ):
                self.assertIn(
                    token,
                    receipt,
                    "observable superstep 7 must retain its name, ordinal, and real work tag",
                )

        validate(self.master)
        mutations = {
            "bounded-inference-loses-artifact-evidence": (
                "case boundedInference(BASSuperstepSevenNonProviderWork)",
                "case boundedInference(String)",
                "must carry Artifact evidence",
            ),
            "drop-packet-binding": (
                "public let structuredContextPacketDigest: String",
                "public let omittedPacketDigest: String",
                "not fully lineage-bound",
            ),
            "renumber-superstep": (
                "superstepOrdinal == 7",
                "superstepOrdinal == 8",
                "must retain its name, ordinal, and real work tag",
            ),
            "provider-ref-on-bounded-inference": (
                "case boundedInference(BASSuperstepSevenNonProviderWork)",
                "case boundedInference(BASSuperstepSevenProviderWork)",
                "must carry Artifact evidence",
            ),
            "ordinal-field-loses-uint8-type": (
                "public let superstepOrdinal: UInt8",
                "public let superstepOrdinal: UInt16",
                "not fully lineage-bound",
            ),
        }
        for label, (old, new, message) in mutations.items():
            with self.subTest(mutation=label), self.assertRaisesRegex(
                AssertionError, message
            ):
                if label == "drop-packet-binding":
                    mutated = replace_once_in_swift_declaration(
                        self.master,
                        "BASSuperstepSevenObservationReceipt",
                        old,
                        new,
                    )
                else:
                    mutated = replace_once(self.master, old, new)
                validate(mutated)

    def test_state_market_token_cost_is_model_neutral_before_election_and_provider_exact_after(
        self,
    ) -> None:
        neutral_fields = {
            "schemaVersion": "String",
            "structuredContextPacketDigest": "String",
            "resourceInventoryDigest": "String",
            "canonicalByteCount": "UInt64",
            "canonicalSectionCount": "UInt64",
            "resourceUnitCount": "UInt64",
            "conservativeTokenCost": "UInt64",
            "derivationRuleID": "String",
        }
        provider_fields = {
            "candidateKind": "BASProposalCandidateKind",
            "tokenizerID": "String",
            "inputTokenCount": "UInt64",
            "outputTokenCount": "UInt64",
            "eligibilityOrRankingFeedback": "Bool",
        }
        cost_mapping_contract = (
            "State Market.tokenCost = "
            "BASModelNeutralMarketCost.conservativeTokenCost"
        )

        def validate(contents: str) -> None:
            try:
                neutral = swift_declaration_block(
                    contents, "BASModelNeutralMarketCost"
                )
                provider = swift_declaration_block(
                    contents, "BASProviderExactAccounting"
                )
            except AssertionError as error:
                raise AssertionError(
                    "State Market tokenCost lacks a model-neutral pre-election derivation"
                ) from error
            neutral_actual = swift_stored_property_types(neutral)
            self.assertTrue(
                set(neutral_fields) <= set(neutral_actual),
                "model-neutral market cost omits byte/section/resource units",
            )
            forbidden_neutral = {
                field
                for field in ("tokenizerID", "tokenCount", "inputTokenCount", "outputTokenCount")
                if field in neutral_actual
            }
            self.assertEqual(
                forbidden_neutral,
                set(),
                "pre-election market cost must not depend on a tokenizer",
            )
            self.assertEqual(
                neutral_actual,
                neutral_fields,
                "model-neutral market cost must have the exact packet/resource basis fields",
            )
            self.assertIn(
                'schemaVersion == "1.0.0"',
                neutral,
                "model-neutral market cost must pin schemaVersion 1.0.0",
            )
            self.assertIn(
                "package init(",
                neutral,
                "model-neutral market cost direct construction must stay package-private",
            )
            try:
                package_initializer = section(
                    neutral,
                    "package init(",
                    "\n    private enum CodingKeys:",
                )
                coding_keys = section(
                    neutral,
                    "private enum CodingKeys: String, CodingKey, CaseIterable {",
                    "\n    }\n\n    public init(from decoder: Decoder) throws {",
                )
                decoder = neutral[
                    neutral.index("public init(from decoder: Decoder) throws {") :
                ]
            except (AssertionError, ValueError) as error:
                raise AssertionError(
                    "model-neutral market cost lacks one strict package initializer/decoder"
                ) from error
            key_names = [
                name
                for line in re.findall(r"(?m)^\s*case\s+([^\n]+)$", coding_keys)
                for name in (item.strip() for item in line.split(","))
            ]
            self.assertEqual(
                key_names,
                list(neutral_fields),
                "model-neutral market cost CodingKeys must equal its eight-field basis",
            )
            self.assertEqual(
                decoder.count("BASContractWireValidation.exactKeySet"),
                1,
                "model-neutral market cost decoder must enforce one exact key set",
            )
            self.assertEqual(
                decoder.count("try self.init("),
                1,
                "model-neutral market cost decoder must delegate once to its validator",
            )
            self.assertEqual(
                re.findall(r"(?m)^\s*self\.[A-Za-z_][A-Za-z0-9_]*\s*=", decoder),
                [],
                "model-neutral market cost decoder must not bypass its validator",
            )
            normalized_decoder = re.sub(r"\s+", " ", decoder)
            normalized_decoder = re.sub(r"\(\s+", "(", normalized_decoder)
            for field, field_type in neutral_fields.items():
                self.assertIn(
                    f"{field}: c.decode({field_type}.self, forKey: .{field})",
                    normalized_decoder,
                    f"model-neutral market cost decoder type drifted for {field}",
                )
                self.assertEqual(
                    package_initializer.count(f"self.{field} = {field}"),
                    1,
                    f"model-neutral market cost validator assignment drifted for {field}",
                )
            self.assertIn(
                "The `BASSemanticStateMarket` factory reopens the exact "
                "`BASStructuredContextPacket` and its canonical resource inventory, "
                "recomputes `canonicalByteCount`, `canonicalSectionCount`, and "
                "`resourceUnitCount`, and rejects caller-supplied basis drift; direct "
                "construction is package-private and decoded values remain ineligible "
                "until the same semantic validator succeeds.",
                re.sub(r"\s+", " ", contents),
                "market cost basis must be reopened and recomputed",
            )
            self.assertIn(
                'derivationRuleID == "qinao.market-token-units.v1"',
                neutral,
                "model-neutral market cost must bind the versioned derivation rule",
            )
            self.assertRegex(
                neutral,
                r"(?m)^\s*let byteUnits = canonicalByteCount\s*$",
                "model-neutral market cost must use one conservative unit per byte",
            )
            for fragment in (
                "canonicalSectionCount.multipliedReportingOverflow(by: 8)",
                "resourceUnitCount.multipliedReportingOverflow(by: 32)",
                "byteUnits.addingReportingOverflow(sectionUnits)",
                "partialCost.addingReportingOverflow(resourceUnits)",
                "!sectionOverflow, !resourceOverflow",
                "!partialOverflow, !totalOverflow",
                "conservativeTokenCost == derivedCost",
            ):
                self.assertIn(
                    fragment,
                    neutral,
                    "model-neutral market cost formula or overflow closure drifted",
                )
            self.assertIn(
                cost_mapping_contract,
                re.sub(r"\s+", " ", contents),
                "State Market.tokenCost must map to conservativeTokenCost",
            )
            provider_actual = swift_stored_property_types(provider)
            self.assertEqual(
                provider_actual,
                provider_fields,
                "post-election model accounting is not Provider-exact",
            )
            self.assertIn(
                "candidateKind == .model",
                provider,
                "provider-exact accounting is legal only after model election",
            )
            self.assertIn(
                "eligibilityOrRankingFeedback == false",
                provider,
                "provider-exact accounting must not feed back into eligibility or ranking",
            )

        validate(self.master)
        mutations = {
            "restore-byte-div-four-token-heuristic": (
                "let byteUnits = canonicalByteCount\n",
                "let byteUnits = canonicalByteCount / 4\n",
                "must use one conservative unit per byte",
            ),
            "neutralize-overflow-fail-closed": (
                "!sectionOverflow, !resourceOverflow,\n"
                "              !partialOverflow, !totalOverflow,",
                "sectionOverflow || true, resourceOverflow || true,\n"
                "              partialOverflow || true, totalOverflow || true,",
                "formula or overflow closure drifted",
            ),
            "tokenizer-before-election": (
                "public let resourceUnitCount: UInt64",
                "public let resourceUnitCount: UInt64\n"
                "    public let tokenizerID: String",
                "must not depend on a tokenizer",
            ),
            "drop-resource-units": (
                "public let resourceUnitCount: UInt64",
                "public let omittedResourceUnitCount: UInt64",
                "omits byte/section/resource units",
            ),
            "provider-accounting-for-all-kinds": (
                "candidateKind == .model",
                "candidateKind != .unknown",
                "legal only after model election",
            ),
            "remove-stored-provider-candidate-kind": (
                "    public let candidateKind:\n"
                "        BASProposalCandidateKind\n"
                "    public let tokenizerID: String",
                "    public let omittedCandidateKind:\n"
                "        BASProposalCandidateKind\n"
                "    public let tokenizerID: String",
                "not Provider-exact",
            ),
            "change-provider-feedback-field-type": (
                "public let eligibilityOrRankingFeedback: Bool",
                "public let eligibilityOrRankingFeedback: String",
                "not Provider-exact",
            ),
            "provider-accounting-feeds-ranking": (
                "eligibilityOrRankingFeedback == false",
                "eligibilityOrRankingFeedback == true",
                "must not feed back into eligibility or ranking",
            ),
            "change-market-cost-derivation-rule": (
                'derivationRuleID == "qinao.market-token-units.v1"',
                'derivationRuleID == "qinao.market-token-units.v2"',
                "must bind the versioned derivation rule",
            ),
            "disconnect-state-market-token-cost": (
                cost_mapping_contract,
                "State Market.tokenCost = providerTokenCount",
                "must map to conservativeTokenCost",
            ),
        }
        for label, (old, new, message) in mutations.items():
            with self.subTest(mutation=label), self.assertRaisesRegex(
                AssertionError, message
            ):
                validate(replace_once(self.master, old, new))

        neutral_block = swift_declaration_block(
            self.master, "BASModelNeutralMarketCost"
        )

        def mutate_neutral(old: str, new: str) -> str:
            return replace_once(
                self.master,
                neutral_block,
                replace_once(neutral_block, old, new),
            )

        strict_cost_mutations = {
            "decoder-drops-exact-key-set": lambda: mutate_neutral(
                "        try BASContractWireValidation.exactKeySet(\n"
                "            decoder, Set(CodingKeys.allCases.map(\\.rawValue)))\n",
                "",
            ),
            "packet-digest-decodes-bool": lambda: mutate_neutral(
                "structuredContextPacketDigest: c.decode(\n"
                "                String.self, forKey: .structuredContextPacketDigest)",
                "structuredContextPacketDigest: c.decode(\n"
                "                Bool.self, forKey: .structuredContextPacketDigest)",
            ),
            "resource-digest-assigned-from-packet": lambda: mutate_neutral(
                "self.resourceInventoryDigest = resourceInventoryDigest",
                "self.resourceInventoryDigest = structuredContextPacketDigest",
            ),
            "coding-keys-drop-resource-digest": lambda: mutate_neutral(
                "case resourceInventoryDigest, canonicalByteCount, canonicalSectionCount",
                "case canonicalByteCount, canonicalSectionCount",
            ),
            "decoder-bypasses-package-validator": lambda: mutate_neutral(
                "        try self.init(\n",
                "        let _ = (\n",
            ),
        }
        for label, mutate in strict_cost_mutations.items():
            with self.subTest(mutation=label), self.assertRaises(AssertionError):
                validate(mutate())

    def test_model_erased_core_dependency_closure_has_nonvacuous_clean_build_gate(
        self,
    ) -> None:
        runner_executable = "$QINAO_W1_ADMITTED_MODEL_ERASED_RUNNER"
        sections = {
            "W4": section(
                self.master,
                "### Payload 6D (W4)",
                "## Controlled Domain-Plan Payload W5:",
            ),
            "W6": self.master[
                self.master.index("## Controlled Domain-Plan Payload W6 Runtime:") :
            ],
        }
        commands = {
            wave: [
                command
                for block in fenced_shell_blocks(contents)
                for command in logical_shell_commands(block)
                if runner_executable in command
            ]
            for wave, contents in sections.items()
        }
        expected_runner_bindings = {
            "W4": {
                "python": "$QINAO_ADMITTED_PROTECTED_PYTHON",
                "candidate_tree": "$QINAO_W4_CANDIDATE_TREE",
            },
            "W6": {
                "python": "$QINAO_W6_PROTECTED_PYTHON",
                "candidate_tree": "$QINAO_W6_CERT_CANDIDATE_TREE",
            },
        }
        profile_manifest = "$QINAO_W1_ADMITTED_MODEL_ERASED_PROFILE_MANIFEST"
        profile_manifest_sha256 = "$QINAO_MODEL_ERASED_PROFILE_MANIFEST_SHA256"

        def validate_exact_runner_bindings(contents: str) -> None:
            scoped_sections = {
                "W4": section(
                    contents,
                    "### Payload 6D (W4)",
                    "## Controlled Domain-Plan Payload W5:",
                ),
                "W6": contents[
                    contents.index("## Controlled Domain-Plan Payload W6 Runtime:") :
                ],
            }
            for wave, scoped_contents in scoped_sections.items():
                scoped_commands = [
                    command
                    for block in fenced_shell_blocks(scoped_contents)
                    for command in logical_shell_commands(block)
                    if runner_executable in command
                ]
                self.assertEqual(
                    len(scoped_commands),
                    1,
                    f"{wave} must have one physical model-erased command",
                )
                argv = direct_runner_argv(
                    scoped_commands[0],
                    runner_executable,
                )
                expected = expected_runner_bindings[wave]
                self.assertEqual(
                    argv[0],
                    expected["python"],
                    f"{wave} model-erased proof uses the wrong protected Python",
                )
                self.assertEqual(
                    option_values(argv, "--candidate-tree"),
                    [expected["candidate_tree"]],
                    f"{wave} model-erased proof is not bound to its exact candidate tree",
                )
                self.assertEqual(
                    option_values(argv, "--profile-manifest"),
                    [profile_manifest],
                    f"{wave} model-erased proof uses the wrong profile manifest",
                )
                self.assertEqual(
                    option_values(argv, "--profile-manifest-sha256"),
                    [profile_manifest_sha256],
                    f"{wave} model-erased proof has an unbound profile-manifest digest",
                )

                runner_blocks = [
                    block
                    for block in fenced_shell_blocks(scoped_contents)
                    if runner_executable in block
                ]
                self.assertEqual(
                    len(runner_blocks),
                    1,
                    f"{wave} runner must occur in one executable shell block",
                )
                block = runner_blocks[0]
                runner_position = block.index(runner_executable)
                preparation_positions = [
                    match.start()
                    for match in re.finditer(
                        r"(?m)^[ \t]*python3 "
                        r"scripts/prepare_qinao_v2_wave_candidate\.py\b",
                        block,
                    )
                ]
                admission_positions = [
                    match.start()
                    for match in re.finditer(
                        r'(?m)^[ \t]*"\$QINAO_EXTERNAL_ADMISSION_VERIFIER" '
                        r"admit-wave\b",
                        block,
                    )
                ]
                self.assertTrue(
                    preparation_positions,
                    f"{wave} model-erased shell block lacks the real preparation call",
                )
                self.assertTrue(
                    admission_positions,
                    f"{wave} model-erased shell block lacks the real admission call",
                )
                self.assertLess(
                    runner_position,
                    min(preparation_positions),
                    f"{wave} model-erased gate must precede real candidate preparation",
                )
                self.assertLess(
                    runner_position,
                    min(admission_positions),
                    f"{wave} model-erased gate must precede real candidate admission",
                )

        validate_exact_runner_bindings(self.master)
        self.assertEqual(
            {wave: len(found) for wave, found in commands.items()},
            {"W4": 1, "W6": 1},
            "model-erased clean build must run exactly once before W4 admission "
            "and once on the W6 certification candidate",
        )
        expected_products = {
            "BehavioralAISubstrate:BASHostKit",
            "BehavioralAISubstrate:BASAppleLifecycleKit",
            "QinaoRuntimeSDK:QinaoRuntime",
            "QinaoRuntimeSDK:QinaoHost",
            "QinaoRuntimeSDK:QinaoDefaults",
        }
        expected_targets = {
            "BASAppleAdapters",
            "BASMLXAdapter",
            "BASChatCompletionsAdapter",
            "QinaoAppleFoundation",
            "QinaoMLX",
        }
        expected_packages = {
            "mlx-swift",
            "mlx-swift-lm",
            "swift-transformers",
            "swift-huggingface",
        }
        expected_profile_resources = {
            "no-language-inference:language-model-weight",
            "no-language-inference:tokenizer",
            "no-language-inference:prompt-template",
            "no-learned-inference:learned-weight",
            "no-learned-inference:language-model-weight",
            "no-learned-inference:tokenizer",
            "no-learned-inference:prompt-template",
        }
        argv_by_wave = {}
        for wave, found in commands.items():
            argv = direct_runner_argv(
                found[0], runner_executable
            )
            argv_by_wave[wave] = argv
            validate_closed_runner_options(
                argv,
                singleton_options={
                    "--git-executable",
                    "--root",
                    "--candidate-tree",
                    "--substrate-package-path",
                    "--sdk-package-path",
                    "--scratch-path",
                    "--profile-manifest",
                    "--profile-manifest-sha256",
                    "--runner-sha256",
                    "--require-signed-mechanism-certification",
                    "--require-source-count",
                    "--require-resolved-target-count",
                    "--require-object-count",
                    "--require-link-input-count",
                    "--require-test-count",
                    "--require-reachable-mechanism-row-count",
                    "--require-test",
                },
                repeatable_options={
                    "--profile",
                    "--require-product",
                    "--require-phase",
                    "--forbid-target",
                    "--forbid-package",
                    "--forbid-import",
                    "--forbid-profile-resource",
                    "--forbid-provider-registration",
                    "--require-inventory",
                    "--forbid-capability",
                    "--require-framework-symbol-proof",
                },
            )
            self.assertEqual(option_values(argv, "--git-executable"), ["$QINAO_GIT_EXECUTABLE"])
            self.assertEqual(option_values(argv, "--root"), ["$PWD"])
            self.assertEqual(
                argv[0],
                expected_runner_bindings[wave]["python"],
            )
            self.assertEqual(
                option_values(argv, "--candidate-tree"),
                [expected_runner_bindings[wave]["candidate_tree"]],
                f"{wave} model-erased proof must bind the exact candidate tree",
            )
            self.assertEqual(option_values(argv, "--substrate-package-path"), ["BehavioralAISubstrate"])
            self.assertEqual(option_values(argv, "--sdk-package-path"), ["QinaoRuntimeSDK"])
            self.assertEqual(
                option_values(argv, "--profile-manifest"),
                [profile_manifest],
            )
            self.assertEqual(
                option_values(argv, "--profile-manifest-sha256"),
                [profile_manifest_sha256],
            )
            self.assertEqual(
                option_values(argv, "--require-signed-mechanism-certification"),
                ["qinao.proposal-mechanism-certification.v1"],
            )
            self.assertEqual(
                Counter(option_values(argv, "--profile")),
                Counter({"no-language-inference", "no-learned-inference"}),
            )
            self.assertEqual(
                Counter(option_values(argv, "--require-product")),
                Counter(expected_products),
            )
            self.assertEqual(
                Counter(option_values(argv, "--require-phase")),
                Counter({"resolve", "build", "test"}),
            )
            self.assertEqual(
                Counter(option_values(argv, "--forbid-target")),
                Counter(expected_targets),
            )
            self.assertEqual(
                Counter(option_values(argv, "--forbid-package")),
                Counter(expected_packages),
            )
            self.assertEqual(
                Counter(option_values(argv, "--forbid-import")),
                Counter({"FoundationModels", "Tokenizers"}),
                "CoreAI, MLX, and NaturalLanguage are not categorically language-only",
            )
            self.assertEqual(
                Counter(option_values(argv, "--forbid-profile-resource")),
                Counter(expected_profile_resources),
            )
            self.assertEqual(
                Counter(option_values(argv, "--forbid-provider-registration")),
                Counter({"model", "chat-completions", "mlx", "foundation-models"}),
            )
            for option in (
                "--require-source-count",
                "--require-resolved-target-count",
                "--require-object-count",
                "--require-link-input-count",
                "--require-test-count",
            ):
                self.assertEqual(
                    option_values(argv, option),
                    ["1"],
                    f"model-erased proof is vacuous at {option}",
                )
            self.assertEqual(
                option_values(argv, "--require-test"),
                [
                    "BehavioralAISubstrateTests.BASModelBoundaryPinTests/"
                    "testModelErasedCoreDependencyClosureCleanBuildsWithoutLanguageModelAssetsOrProviders"
                ],
            )

        self.assertEqual(
            option_values(argv_by_wave["W4"], "--scratch-path"),
            ["$QINAO_W4_MODEL_ERASED_SCRATCH"],
        )
        self.assertEqual(
            option_values(argv_by_wave["W6"], "--scratch-path"),
            ["$QINAO_W6_MODEL_ERASED_SCRATCH"],
        )

        required_test = (
            "BehavioralAISubstrateTests.BASModelBoundaryPinTests/"
            "testModelErasedCoreDependencyClosureCleanBuildsWithoutLanguageModelAssetsOrProviders"
        )

        def replace_all_exact(
            contents: str,
            old: str,
            new: str,
            expected_count: int,
        ) -> str:
            actual_count = contents.count(old)
            if actual_count != expected_count:
                raise AssertionError(
                    f"mutation source count {actual_count} != {expected_count}: {old!r}"
                )
            return contents.replace(old, new)

        def move_runner_after_real_admission(
            contents: str,
            runner_start_token: str,
        ) -> str:
            runner_start = contents.index(runner_start_token)
            command_end = contents.index(
                f"    --require-test {required_test}\n",
                runner_start,
            ) + len(f"    --require-test {required_test}\n")
            ordering_comment = (
                "  # Ordering sentinel only: "
                "scripts/run_qinao_wave_admission.py admit-wave names the "
                "controller boundary below; the external verifier remains the "
                "sole signer/installer.\n"
            )
            if contents.startswith(ordering_comment, command_end):
                command_end += len(ordering_comment)
            runner_chunk = contents[runner_start:command_end]
            without_runner = contents[:runner_start] + contents[command_end:]
            shell_block_end = without_runner.index("```", runner_start)
            return (
                without_runner[:shell_block_end]
                + runner_chunk
                + without_runner[shell_block_end:]
            )

        def mask_w4_runner(contents: str) -> str:
            runner_start = contents.index(
                '  "$QINAO_ADMITTED_PROTECTED_PYTHON" '
                '"$QINAO_W1_ADMITTED_MODEL_ERASED_RUNNER"'
            )
            command_end = contents.index(
                f"    --require-test {required_test}\n",
                runner_start,
            )
            insertion = command_end + len(f"    --require-test {required_test}")
            return contents[:insertion] + " || true" + contents[insertion:]

        runner_mutations = {
            "w4-cross-wave-candidate-tree": (
                lambda contents: replace_once(
                    contents,
                    '--candidate-tree "$QINAO_W4_CANDIDATE_TREE"',
                    '--candidate-tree "$QINAO_W6_CERT_CANDIDATE_TREE"',
                ),
                "not bound to its exact candidate tree",
            ),
            "w6-cross-wave-candidate-tree": (
                lambda contents: replace_once(
                    contents,
                    '--candidate-tree "$QINAO_W6_CERT_CANDIDATE_TREE"',
                    '--candidate-tree "$QINAO_W4_CANDIDATE_TREE"',
                ),
                "not bound to its exact candidate tree",
            ),
            "w4-cross-wave-protected-python": (
                lambda contents: replace_once(
                    contents,
                    '"$QINAO_ADMITTED_PROTECTED_PYTHON" '
                    '"$QINAO_W1_ADMITTED_MODEL_ERASED_RUNNER"',
                    '"$QINAO_W6_PROTECTED_PYTHON" '
                    '"$QINAO_W1_ADMITTED_MODEL_ERASED_RUNNER"',
                ),
                "uses the wrong protected Python",
            ),
            "w6-cross-wave-protected-python": (
                lambda contents: replace_once(
                    contents,
                    '"$QINAO_W6_PROTECTED_PYTHON" '
                    '"$QINAO_W1_ADMITTED_MODEL_ERASED_RUNNER"',
                    '"$QINAO_ADMITTED_PROTECTED_PYTHON" '
                    '"$QINAO_W1_ADMITTED_MODEL_ERASED_RUNNER"',
                ),
                "uses the wrong protected Python",
            ),
            "unbound-profile-manifest-digest": (
                lambda contents: replace_all_exact(
                    contents,
                    '--profile-manifest-sha256 '
                    '"$QINAO_MODEL_ERASED_PROFILE_MANIFEST_SHA256"',
                    "--profile-manifest-sha256 unverified",
                    2,
                ),
                "unbound profile-manifest digest",
            ),
            "wrong-profile-manifest": (
                lambda contents: replace_all_exact(
                    contents,
                    '--profile-manifest "' + profile_manifest + '"',
                    '--profile-manifest "docs/superpowers/specs/unverified.json"',
                    2,
                ),
                "uses the wrong profile manifest",
            ),
            "w4-runner-after-real-admission": (
                lambda contents: move_runner_after_real_admission(
                    contents,
                    '  "$QINAO_ADMITTED_PROTECTED_PYTHON" '
                    '"$QINAO_W1_ADMITTED_MODEL_ERASED_RUNNER"',
                ),
                "must precede real candidate preparation",
            ),
            "w6-runner-after-real-admission": (
                lambda contents: move_runner_after_real_admission(
                    contents,
                    '  "$QINAO_W6_PROTECTED_PYTHON" '
                    '"$QINAO_W1_ADMITTED_MODEL_ERASED_RUNNER"',
                ),
                "must precede real candidate preparation",
            ),
            "shell-mask-runner-with-or-true": (
                mask_w4_runner,
                "shell control tokens are forbidden",
            ),
        }
        for label, (mutate, message) in runner_mutations.items():
            with self.subTest(mutation=label), self.assertRaisesRegex(
                AssertionError, message
            ):
                validate_exact_runner_bindings(mutate(self.master))

    def test_w1_executes_model_erased_runner_tests(self) -> None:
        w1 = section(
            self.master,
            "## Controlled Domain-Plan Payload W1:",
            "## Controlled Domain-Plan Payload W2:",
        )
        runner_test_commands = [
            command
            for block in fenced_shell_blocks(w1)
            for command in logical_shell_commands(block)
            if "scripts.test_run_qinao_model_erased_build" in command
        ]
        self.assertEqual(
            len(runner_test_commands),
            1,
            "W1 must actually execute the model-erased runner test suite once",
        )
        self.assertEqual(
            strict_shell_argv(runner_test_commands[0]),
            [
                "$QINAO_W1_PROTECTED_PYTHON",
                "-m",
                "unittest",
                "-v",
                "scripts.test_run_qinao_model_erased_build",
            ],
            "W1 runner tests must use the protected direct unittest argv",
        )

    def test_w1_binds_both_immutable_model_erased_trust_anchors(
        self,
    ) -> None:
        w1 = section(
            self.master,
            "## Controlled Domain-Plan Payload W1:",
            "## Controlled Domain-Plan Payload W2:",
        )
        trust_rows = markdown_table_rows(
            w1,
            "| trust-anchor source | terminal digest binding | read-only broker binding |",
        )
        self.assertEqual(
            trust_rows,
            [
                [
                    "scripts/run_qinao_model_erased_build.py",
                    "QINAO_MODEL_ERASED_RUNNER_SHA256",
                    "QINAO_W1_ADMITTED_MODEL_ERASED_RUNNER",
                ],
                [
                    "docs/superpowers/specs/qinao-model-erased-profiles-v1.json",
                    "QINAO_MODEL_ERASED_PROFILE_MANIFEST_SHA256",
                    "QINAO_W1_ADMITTED_MODEL_ERASED_PROFILE_MANIFEST",
                ],
            ],
            "W1 must bind runner/manifest bytes to both terminal digests and broker paths",
        )

    def test_physical_profiles_are_trust_anchored_capability_closed_and_proof_bound(
        self,
    ) -> None:
        w1 = section(
            self.master,
            "## Controlled Domain-Plan Payload W1:",
            "## Controlled Domain-Plan Payload W2:",
        )
        normalized = re.sub(r"\s+", " ", self.master)
        trust_contract = (
            "The W1-admitted runner blob and profile-manifest trust anchor are "
            "reopened before W4; neither the W4 candidate tree nor caller CLI may "
            "replace them."
        )
        self.assertIn("scripts/run_qinao_model_erased_build.py", w1)
        self.assertIn(
            "docs/superpowers/specs/qinao-model-erased-profiles-v1.json", w1
        )
        self.assertIn(trust_contract, normalized)
        self.assertIn(
            "The verified W1 terminal receipt transitively commits the fixed runner "
            "and profile-manifest policy rows through its unchanged installed tree "
            "and protected roots; the external broker derives "
            "`QINAO_MODEL_ERASED_RUNNER_SHA256` and "
            "`QINAO_MODEL_ERASED_PROFILE_MANIFEST_SHA256` and materializes read-only "
            "`QINAO_W1_ADMITTED_MODEL_ERASED_RUNNER` and "
            "`QINAO_W1_ADMITTED_MODEL_ERASED_PROFILE_MANIFEST` paths from that exact "
            "W1 tree only after both digests match, and missing or mismatched bindings "
            "block W4 and W6.",
            normalized,
            "W1 must define the immutable runner and policy bindings consumed later",
        )
        handoff_commands = [
            command
            for block in fenced_shell_blocks(w1)
            for command in logical_shell_commands(block)
            if "materialize-installed-blob" in command
        ]
        self.assertEqual(len(handoff_commands), 1)
        handoff_argv = strict_shell_argv(handoff_commands[0])
        self.assertEqual(handoff_argv[0], "$QINAO_GIT_PREPARATION_BROKER")
        self.assertEqual(
            option_values(handoff_argv, "--verified-terminal-receipt"),
            ["$QINAO_CURRENT_ADMISSION_RECEIPT"],
        )
        self.assertNotIn("--installed-tree", handoff_argv)
        self.assertNotIn("--source", handoff_argv)
        self.assertIn(
            "`reachableMechanismRows` is a bidirectional equality over every "
            "reachable source, target, compiler dependency, object symbol, link-map "
            "input, resource, Provider registration, dynamic-loader edge, and network "
            "edge; an unlisted or manifest-only row fails.",
            normalized,
            "reachableMechanismRows must prove both reachability directions",
        )
        self.assertIn(
            "The runner recomputes dependency, compiler-d, object-symbol, link-map, "
            "resource, registration, dynamic-loader, and network inventories from the "
            "exact candidate tree after clean resolve, build, and test.",
            normalized,
            "physical evidence must be recomputed from the clean candidate tree",
        )
        self.assertIn(
            "No reachable dynamic URL, downloaded or cached model, system-opaque "
            "language service, or unclassified symbol can be justified by the absence "
            "of a bundled weight; an unknown capability fails both profiles.",
            normalized,
            "dynamic and system model mechanisms must fail closed",
        )
        rows = markdown_table_rows(
            self.master,
            "| physical profile | forbidden capabilities |",
        )
        self.assertEqual(
            {row[0]: row[1] for row in rows if len(row) == 2},
            {
                "no-language-inference": (
                    "boundedLanguageLearned,languageHuman,languageTool,"
                    "openGenerativeProvider"
                ),
                "no-learned-inference": (
                    "boundedNonLanguageLearned,boundedLanguageLearned,languageHuman,"
                    "languageTool,openGenerativeProvider,"
                    "boundedNonLanguageWorldModelSearch"
                ),
            },
            "physical profile forbidden-capability matrix drifted",
        )

        commands = [
            command
            for block in fenced_shell_blocks(self.master)
            for command in logical_shell_commands(block)
            if "$QINAO_W1_ADMITTED_MODEL_ERASED_RUNNER" in command
        ]
        self.assertEqual(len(commands), 2)
        required_inventories = {
            "dependency",
            "compiler-d",
            "object-symbol",
            "link-map",
            "resource",
            "registration",
            "dynamic-loader",
            "network",
            "classifier-resource",
            "classifier-adapter",
        }
        forbidden_capabilities = {
            "no-language-inference:boundedLanguageLearned",
            "no-language-inference:languageHuman",
            "no-language-inference:languageTool",
            "no-language-inference:openGenerativeProvider",
            "no-learned-inference:boundedNonLanguageLearned",
            "no-learned-inference:boundedLanguageLearned",
            "no-learned-inference:languageHuman",
            "no-learned-inference:languageTool",
            "no-learned-inference:openGenerativeProvider",
            "no-learned-inference:boundedNonLanguageWorldModelSearch",
        }
        framework_proofs = {
            f"{profile}:{framework}"
            for profile in ("no-language-inference", "no-learned-inference")
            for framework in ("CoreAI", "MLX", "NaturalLanguage", "CoreML")
        }
        for command in commands:
            argv = direct_runner_argv(
                command, "$QINAO_W1_ADMITTED_MODEL_ERASED_RUNNER"
            )
            self.assertEqual(
                option_values(argv, "--runner-sha256"),
                ["$QINAO_MODEL_ERASED_RUNNER_SHA256"],
            )
            self.assertEqual(
                option_values(argv, "--require-reachable-mechanism-row-count"),
                ["1"],
                "reachable mechanism closure proof is vacuous",
            )
            self.assertEqual(
                Counter(option_values(argv, "--require-inventory")),
                Counter(required_inventories),
            )
            self.assertEqual(
                Counter(option_values(argv, "--forbid-capability")),
                Counter(forbidden_capabilities),
            )
            self.assertEqual(
                Counter(option_values(argv, "--require-framework-symbol-proof")),
                Counter(framework_proofs),
                "CoreAI/MLX/NaturalLanguage symbols require reachable mechanism proof",
            )

    def test_no_learned_classifier_resource_and_adapter_reachability_is_closed(
        self,
    ) -> None:
        self.assertIn(
            "`no-learned-inference` classifies the classifier itself: every "
            "classifier resource and adapter is present in the recomputed "
            "bidirectional reachability closure; a learned, unknown, manifest-only, "
            "or unreachable classifier dependency fails before candidate execution.",
            re.sub(r"\s+", " ", self.master),
            "no-learned proof must close classifier resource and adapter reachability",
        )

    def test_no_llm_proposal_engine_is_closed_owned_and_wave_bound(self) -> None:
        closure = section(
            self.master,
            "### Closed no-language-model survival delta",
            "## Task 0: Select and Pin the Only Convergence Predecessor",
        )
        normalized = re.sub(r"\s+", " ", closure)
        for token in (
            "`rule`, `search`, `classicML`, `human`, `tool`, and `model`",
            "model is one candidate kind",
            "`BASStructuredContextPacket` is the canonical context",
            "prompt/tokenized form is an ephemeral model-materialization adapter output",
            "No new owner, authority, store, manager, registry, scheduler, compiler, or wave",
            "29/14/14/7",
            "14/10/4/4/7",
        ):
            self.assertIn(token, normalized)

        expected_rows = (
            (
                "W1 contract",
                "state.snapshot-contracts",
                "BASSemanticStateLakeContracts.swift",
            ),
            (
                "W3 packet and grounding",
                "state.context-compiler",
                "ContextCompilerCore.swift",
            ),
            (
                "W3 packet and grounding",
                "state.snapshot-market",
                "BASSemanticStateMarket.swift",
            ),
            (
                "W4 plan and compiler materialization",
                "execution.plan-provider-router",
                "BASProposalEngineAdapter.swift",
            ),
            (
                "W6 composition",
                "runtime.semantic-executor",
                "BASTurnRuntimeEngine.swift",
            ),
        )
        for wave, owner, path in expected_rows:
            self.assertIn(wave, closure)
            self.assertIn(f"`{owner}`", closure)
            self.assertIn(path, closure)

    def test_r5_r6_grounding_is_tagged_and_provider_receipt_is_model_only(self) -> None:
        closure = section(
            self.master,
            "### Closed no-language-model survival delta",
            "## Task 0: Select and Pin the Only Convergence Predecessor",
        )
        normalized = re.sub(r"\s+", " ", closure)
        for branch in ("`model`", "`deterministic`", "`humanOrTool`", "`notRequired`"):
            self.assertIn(branch, closure)
        for token in (
            "exactly one closed tagged branch",
            "unavailable model is never eligibility evidence",
            "cannot be used as an availability fallback",
            "same tag and exact branch evidence",
            "Provider allocation/execution receipt is required only for `model`",
            "rejects a missing, extra, foreign, or cross-tag receipt",
        ):
            self.assertIn(token, normalized)

    def test_structured_automation_zero_model_and_frozen_dag_are_honest(self) -> None:
        closure = section(
            self.master,
            "### Closed no-language-model survival delta",
            "## Task 0: Select and Pin the Only Convergence Predecessor",
        )
        normalized = re.sub(r"\s+", " ", closure)
        for token in (
            "human, UI, or importer",
            "Natural language is only an optional proposal producer",
            "structured input → R0-R6 → canonical Context Packet → structured Proposal → Automation → K3 → effect → recovery",
            "zero Provider allocation, zero Provider call, zero `providerStep`, and zero Provider-private KV",
            "externalProducerRequired",
            "Identity, control, data, deterministic Automation, and recovery remain available",
            "fill, skip, order, or parallelize only predeclared frozen slots",
            "cannot append a role, descendant, capability, owner, or runtime DAG node",
        ):
            self.assertIn(token, normalized)

    def test_no_llm_sentinels_are_listed_selected_and_wave_local(self) -> None:
        expected = NO_LANGUAGE_SURVIVAL_SENTINELS
        self.assertEqual(len(expected), 26)
        self.assertEqual(len(set(expected)), 26)
        listed = listed_swift_sentinel_ids(self.master)
        self.assertTrue(set(expected) <= listed)
        closure = section(
            self.master,
            "### Closed no-language-model survival delta",
            "## Task 0: Select and Pin the Only Convergence Predecessor",
        )
        normalized_closure = re.sub(r"\s+", " ", closure)
        self.assertIn(
            "The twenty-six no-language-model RED-to-GREEN sentinels",
            normalized_closure,
        )
        self.assertIn(
            "from `123` to exactly `222`",
            normalized_closure,
        )
        self.assertIn("exactly `222`", closure)

        selected = required_test_selectors(self.master)
        for test_id in expected:
            self.assertEqual(selected.count(test_id), 1, test_id)

        wave_sections = {
            "W1": section(
                self.master,
                "### Payload 3A — Write failing value and wire tests",
                "### Payload 3B — After Task-0 GREEN, implement the remaining low-entropy values",
            ),
            "W3": section(self.master, "### Payload 5I", "### Payload 5J"),
            "W4": section(
                self.master,
                "### Payload 6D (W4)",
                "## Controlled Domain-Plan Payload W5:",
            ),
            "W6": section(self.master, "### Payload 10G", "### Payload 10H"),
        }
        expected_wave = {
            "BASProposalEngineContractTests": "W1",
            "BASStructuredContextPacketTests": "W1",
            "BASAutomationDefinitionContractTests": "W1",
            "BASDelegationSlotContractTests": "W1",
            "BASSemanticStateMarketTests": "W3",
            "BASProposalEngineAdapterTests": "W4",
            "BASZeroModelSurvivalE2ETests": "W6",
            "BASModelBoundaryPinTests": "W4",
        }
        for suite, wave in expected_wave.items():
            self.assertIn(f"{suite}/test", wave_sections[wave])

    def test_approved_history_closure_is_pinned_and_existing_owner_only(self) -> None:
        closure = section(
            self.master,
            "### Closed approved-history implementation delta",
            "## Task 0: Select and Pin the Only Convergence Predecessor",
        )
        normalized = re.sub(r"\s+", " ", closure)
        for token in (
            "2026-07-23-qinao-governed-learning-plane-data-flywheel-thinking-design.md",
            "75a34022593ea2d85405021e75272d7c7f0c2af1",
            "185314",
            "e14375de67f7baf9bfe9c4e466b1182fbe906f849da0e260a37bd8bbd6554079",
            "No new Store, Manager, Router, GraphManager, scheduler, compiler, layer, ring, plane, owner, or wave",
            "historical plans remain inert",
            "W1-W6 remain future and uncompleted",
            "selected predecessor must already contain the exact learning-design blob; otherwise C0 rejects",
        ):
            self.assertIn(token, normalized)

        task_zero = section(
            self.master,
            "## Task 0: Select and Pin the Only Convergence Predecessor",
            "## Task 1: Make W0 Gates Non-Vacuous and Continuous",
        )
        self.assertIn(
            "The selected predecessor must already contain the exact 2026-07-23 governed-learning design blob",
            task_zero,
        )
        self.assertIn("no third design edge", task_zero)

        task_two = section(
            self.master,
            "## Task 2: Atomically Reconcile the Seven Controlled Documents and Owner Ledger",
            "## Controlled Domain-Plan Payload W1:",
        )
        self.assertIn(
            "Treat as immutable, byte-pinned decision input: "
            "`docs/superpowers/specs/2026-07-23-qinao-governed-learning-plane-data-flywheel-thinking-design.md`",
            re.sub(r"\s+", " ", task_two),
        )

    def test_approved_resilience_delta_is_existing_owner_wave_and_selector_closed(
        self,
    ) -> None:
        closure = section(
            self.master,
            "#### G. Journal-first continuity, context, portfolio, and inquiry closure",
            "---\n\n## Task 0: Select and Pin the Only Convergence Predecessor",
        )
        normalized = re.sub(r"\s+", " ", closure)
        for token in (
            "Journal-first Continuity Fabric",
            "K3/EventLog + encrypted Artifact + owner receipts",
            "exactAppOwnedBytes",
            "deterministicReplay",
            "semanticReconstruction",
            "externalReconciliation",
            "unavailable",
            "Mission → Objective → WorkUnit → Attempt → SolutionArtifact",
            "before Provider, tool, state, effect, publication, or release allocation",
            "who, why, goal, completed, evidence, pending, uncertain, next, and blocked",
            "recovery72Hours",
            "minimumRetainUntilMs = trustedStart + 259200000",
            "plans and inquiry transcripts use `userDurable`",
            "`BASRetentionAdmissionReceipt` is the only min/max decision",
            "references that receipt and cannot copy a second expiry clock",
            "workspace × conversation × logicalAgent × role × workUnit × attempt × capsuleKind × capabilityProfile",
            "min(advertised, empiricallyCertified) - reserves",
            "every committed turn",
            "BASCacheCheckpointIdentity",
            "BASContinuationCheckpointRef",
            "BASProviderCheckpointReceipt",
            "BASContinuationRoute",
            "BASProviderCheckpointMaterializer",
            "accepted tokens remain authoritative",
            "Qwen3.5-4B",
            "MiniCPM5-1B",
            "Granite Embedding 311M Multilingual R2",
            "KaLM Reranker V1 Nano",
            "PrivateCloudComputeLanguageModel",
            "default PCC concurrency is one",
            "an experimental maximum of two",
            "Vision/VisionKit",
            "SpeechAnalyzer/SpeechTranscriber",
            "NaturalLanguage/Translation",
            "CoreSpotlight",
            "Whisper inquiry branch",
            "zero tool, effect, state, publication, memory, learning, Automation, or Sub-Agent-spawn authority",
            "source-bound Persona Card",
            "MorphoHDL",
            "labOnly/watch",
            "no second Store, Manager, Router, compiler, Agent bus, owner, wave, layer, ring, or plane",
        ):
            self.assertIn(token, normalized)

        header = (
            "| Requirement | Incumbent owner / path | Wave | Mandatory posture | "
            "Exact Swift sentinel |"
        )
        rows = markdown_table_rows(closure, header)
        expected = {
            "plan-before-action": (
                "W1",
                "BASSemanticTurnDAGTests.testExecutableSlotsRequireFrozenPlanAndCurrentPredecessorReceiptsBeforeAllocation",
            ),
            "per-turn-context-maintenance": (
                "W3",
                "BASSemanticSnapshotCoordinatorTests.testEveryCommittedTurnAdvancesBoundedMaintenanceBeforeNextAttemptCompilation",
            ),
            "per-model-context-adaptation": (
                "W4",
                "BASIndependentContextWindowStressTests.testEveryTurnRecompilesCurrentSnapshotWithinItsOwnProfileBudgetAndCacheIdentity",
            ),
            "closed-provider-roster": (
                "W4",
                "BASLocalAPIProviderParityTests.testAdmittedCompositionRosterIsClosedPerManifestAndCoreRemainsModelNeutral",
            ),
            "pcc-context-isolation": (
                "W4",
                "BASProviderKVIsolationTests.testConcurrentPCCContextsUseDistinctAttemptsCapsulesAccountingAndPrivateState",
            ),
            "pcc-post-handoff-recovery": (
                "W5",
                "BASProviderFallbackDeterminismTests.testPCCPostHandoffPreRespondAndUnknownEntryNeverResendOrSwapWithinAttempt",
            ),
            "persona-web-acquisition": (
                "W5",
                "BASEffectSagaCrashMatrixTests.testPersonaResearchUsesBoundedExplicitWebEffectAndOnlyFeedsLaterAttempt",
            ),
            "effect-crash-matrix": (
                "W5",
                "BASEffectSagaCrashMatrixTests.testEveryPossibleStartCutIsQueryOrReconcileOnlyUnderTheSameEffectIdentity",
            ),
            "apple-whisper-ingress": (
                "W6",
                "AppleSurfaceIngressAdapterTests.testWhisperTranscriptIsUntrustedInputOnlyAndHasZeroAuthoritativeOrEffectReachability",
            ),
            "apple-capability-cutover": (
                "W6",
                "BASAppleCapabilityCutoverTests.testCapabilityCannotEnableWithoutOwnerTargetConfigurationEntitlementDevicePrivacyEffectAndRecoveryClosure",
            ),
            "morphohdl-lab-boundary": (
                "W6",
                "BASAuthoritativeEntrypointTests.testMorphoHDLIsLabOnlyAndHasZeroShippingOrAuthoritativeReachability",
            ),
        }
        self.assertEqual(len(rows), len(expected))
        by_requirement = {row[0]: row for row in rows}
        self.assertEqual(set(by_requirement), set(expected))
        selectors = required_test_selectors(self.master)
        for requirement, (wave, short_id) in expected.items():
            row = by_requirement[requirement]
            self.assertEqual(row[2], wave)
            self.assertEqual(row[4], short_id)
            self.assertIn("existing", row[1].lower())
            self.assertNotIn("new authority", row[3].lower())
            suite, test_name = short_id.split(".", 1)
            full_id = f"BehavioralAISubstrateTests.{suite}/{test_name}"
            self.assertEqual(selectors.count(full_id), 1)

    def test_approved_resilience_delta_mutations_fail_closed(self) -> None:
        header = (
            "| Requirement | Incumbent owner / path | Wave | Mandatory posture | "
            "Exact Swift sentinel |"
        )

        def validate(candidate: str) -> None:
            closure = section(
                candidate,
                "#### G. Journal-first continuity, context, portfolio, and inquiry closure",
                "---\n\n## Task 0: Select and Pin the Only Convergence Predecessor",
            )
            rows = markdown_table_rows(closure, header)
            by_requirement = {row[0]: row for row in rows}
            self.assertEqual(len(rows), 11)
            for requirement in (
                "plan-before-action",
                "per-turn-context-maintenance",
                "per-model-context-adaptation",
                "pcc-context-isolation",
                "pcc-post-handoff-recovery",
                "persona-web-acquisition",
                "apple-whisper-ingress",
                "morphohdl-lab-boundary",
            ):
                self.assertIn(requirement, by_requirement)
            self.assertEqual(by_requirement["plan-before-action"][2], "W1")
            self.assertIn("runtime.semantic-dag", by_requirement["plan-before-action"][1])
            self.assertEqual(by_requirement["per-turn-context-maintenance"][2], "W3")
            self.assertEqual(by_requirement["per-model-context-adaptation"][2], "W4")
            self.assertEqual(by_requirement["pcc-context-isolation"][2], "W4")
            self.assertEqual(by_requirement["pcc-post-handoff-recovery"][2], "W5")
            self.assertEqual(by_requirement["persona-web-acquisition"][2], "W5")
            self.assertIn(
                "untrusted source Artifacts for a later Attempt",
                by_requirement["persona-web-acquisition"][3],
            )
            self.assertIn("labOnly/watch", by_requirement["morphohdl-lab-boundary"][3])
            self.assertIn(
                "zero authoritative or effect reachability",
                by_requirement["apple-whisper-ingress"][3],
            )
            normalized = re.sub(r"\s+", " ", closure)
            self.assertIn("recovery72Hours", normalized)
            self.assertIn(
                "minimumRetainUntilMs = trustedStart + 259200000",
                normalized,
            )
            self.assertIn("plans and inquiry transcripts use `userDurable`", normalized)
            self.assertIn(
                "`BASRetentionAdmissionReceipt` is the only min/max decision",
                normalized,
            )
            self.assertIn(
                "references that receipt and cannot copy a second expiry clock",
                normalized,
            )
            self.assertIn("default PCC concurrency is one", normalized)
            self.assertIn("accepted tokens remain authoritative", normalized)
            self.assertIn(
                "no second Store, Manager, Router, compiler, Agent bus, owner, wave, layer, ring, or plane",
                normalized,
            )
            self.assertNotIn("default **maximum** is 72 hours", candidate)
            self.assertNotIn("It may be deleted earlier after terminal completion", candidate)

        validate(self.master)
        mutations = {
            "new-plan-authority": (
                "existing `runtime.semantic-dag` + K3 root CAS",
                "new ConversationPlanManager authority",
            ),
            "wrong-pcc-wave": (
                "| pcc-post-handoff-recovery | existing Provider possible-start/observation boundary | W5 |",
                "| pcc-post-handoff-recovery | existing Provider possible-start/observation boundary | W4 |",
            ),
            "whisper-effect-authority": (
                "zero authoritative or effect reachability",
                "direct effect reachability",
            ),
            "recovery-minimum-becomes-maximum": (
                "minimumRetainUntilMs = trustedStart + 259200000",
                "maximumRetainUntilMs = trustedStart + 259200000",
            ),
            "pcc-hidden-state-claim": (
                "accepted tokens remain authoritative",
                "Provider-private KV remains authoritative",
            ),
            "morpho-shipping": (
                "`labOnly/watch`; zero shipping or authority reachability",
                "shipping runtime; direct authority reachability",
            ),
            "checkpoint-second-retention-clock": (
                "`BASRetentionAdmissionReceipt` is the only min/max decision.",
                "`BASRetentionAdmissionReceipt` is one min/max decision; checkpoints may override it.",
            ),
        }
        for label, (old, new) in mutations.items():
            with self.subTest(label=label):
                mutated = replace_once(self.master, old, new)
                with self.assertRaises(AssertionError):
                    validate(mutated)

    def test_recovery_retention_and_checkpoint_budget_are_exact(self) -> None:
        def fields(candidate: str, name: str) -> dict[str, str]:
            block = swift_declaration_block(candidate, name)
            return {
                field: field_type.strip()
                for field, field_type in re.findall(
                    r"(?m)^\s*public let ([A-Za-z_][A-Za-z0-9_]*):\s*([^\n]+)",
                    block,
                )
            }

        def assert_exact_retention_wires(candidate: str) -> None:
            self.assertEqual(
                fields(candidate, "BASRetentionAdmissionReceipt"),
                {
                    "schemaVersion": "String",
                    "retentionAdmissionID": "String",
                    "requestDigest": "String",
                    "envelopeDigest": "String",
                    "retentionClass": "BASRetentionClass",
                    "contentArtifactID": "BASArtifactID",
                    "contentDigest": "String",
                    "committedHead": "BASEventLogHead",
                    "committedRowVersion": "UInt64",
                    "decisionRevision": "UInt64",
                    "postStateRoot": "String",
                    "trustedWallStartMs": "Int64",
                    "sameBootMonotonicStartNs": "UInt64?",
                    "committedHorizon": "BASRetentionCommittedHorizon",
                    "purposeID": "String",
                    "consentEpoch": "UInt64",
                    "policyEpoch": "UInt64",
                    "privacyEpoch": "UInt64",
                    "deletionEpoch": "UInt64",
                    "revocationEpoch": "UInt64",
                    "erasureDomainID": "String",
                },
            )
            request_fields = fields(candidate, "BASRetentionDispositionRequest")
            for field, field_type in {
                "retentionAdmissionID": "String",
                "retentionAdmissionReceiptArtifactID": "BASArtifactID",
                "retentionAdmissionReceiptDigest": "String",
                "requestedDisposition": "BASRetentionDisposition",
                "expectedDecisionRevision": "UInt64",
                "expectedPredecessorReceiptArtifactID": "BASArtifactID?",
                "expectedPredecessorReceiptDigest": "String?",
                "expectedHead": "BASEventLogHead",
                "expectedRowVersion": "UInt64",
                "consentEpoch": "UInt64",
                "policyEpoch": "UInt64",
                "privacyEpoch": "UInt64",
                "deletionEpoch": "UInt64",
                "revocationEpoch": "UInt64",
                "idempotencyKey": "String",
            }.items():
                self.assertEqual(request_fields.get(field), field_type, field)
            receipt_fields = fields(candidate, "BASRetentionDispositionReceipt")
            for field, field_type in {
                "retentionAdmissionID": "String",
                "retentionAdmissionReceiptArtifactID": "BASArtifactID",
                "retentionAdmissionReceiptDigest": "String",
                "priorDecisionRevision": "UInt64",
                "predecessorReceiptArtifactID": "BASArtifactID?",
                "predecessorReceiptDigest": "String?",
                "newDecisionRevision": "UInt64",
                "committedDisposition": "BASRetentionDisposition",
                "committedHorizon": "BASRetentionCommittedHorizon?",
                "committedHead": "BASEventLogHead",
                "committedRowVersion": "UInt64",
                "postStateRoot": "String",
                "consentEpoch": "UInt64",
                "policyEpoch": "UInt64",
                "privacyEpoch": "UInt64",
                "deletionEpoch": "UInt64",
                "revocationEpoch": "UInt64",
            }.items():
                self.assertEqual(receipt_fields.get(field), field_type, field)

        assert_exact_retention_wires(self.master)
        retention = swift_declaration_block(self.master, "BASRetentionClass")
        self.assertEqual(
            swift_enum_cases(retention),
            {
                "neverPersist",
                "ephemeral",
                "recovery72Hours",
                "eligibleLearning72Hours",
                "userDurable",
                "auditProof",
            },
        )
        committed = swift_declaration_block(
            self.master, "BASRetentionCommittedHorizon"
        )
        normalized_committed = re.sub(r"\s+", " ", committed)
        self.assertIn(
            "case finite( minimumRetainUntilMs: Int64, maximumRetainUntilMs: Int64 )",
            normalized_committed,
        )
        self.assertIn("case untilExplicitDeletion", committed)

        claim_basis = swift_declaration_block(
            self.master, "BASBudgetUseClaimBasis"
        )
        self.assertEqual(
            swift_enum_cases(claim_basis),
            {"proveZeroUse", "latestUseReceipt"},
        )
        normalized_claim = re.sub(r"\s+", " ", claim_basis)
        self.assertIn("case proveZeroUse", normalized_claim)
        self.assertIn(
            "case latestUseReceipt(artifactID: BASArtifactID)",
            normalized_claim,
        )
        rebase = swift_declaration_block(self.master, "BASContextRebaseRequest")
        self.assertIn(
            "public let budgetUseClaimBasis: BASBudgetUseClaimBasis",
            re.sub(r"\s+", " ", rebase),
        )
        budget_evidence = re.sub(
            r"\s+", " ", swift_declaration_block(self.master, "BASBudgetUseEvidence")
        )
        for token in (
            "case zeroUse( leaseRevision: UInt64, sourceK3Head: BASEventLogHead, proofDigest: String )",
            "case latestUseReceipt( artifactID: BASArtifactID, artifactDigest: String, leaseRevision: UInt64, sourceK3Head: BASEventLogHead )",
        ):
            self.assertIn(token, budget_evidence)
        for name in ("WorkUnitRecoveryCursor", "BASAutomationCheckpointPayload"):
            block = swift_declaration_block(self.master, name)
            self.assertIn(
                "public let budgetUseEvidence: BASBudgetUseEvidence",
                re.sub(r"\s+", " ", block),
                name,
            )
        self.assertNotIn("BASRebaseBudgetUseEvidence", self.master)
        self.assertNotIn("k3ZeroBudgetUseProofArtifactID", self.master)
        normalized_master = re.sub(r"\s+", " ", self.master)
        for token in (
            "one governed `BASRetentionAdmissionReceipt` type and three distinct receipt instances",
            "qinao.continuation.accepted-token-prefix",
            "qinao.continuation.accepted-output-prefix",
            "qinao.continuation.cache-image",
        ):
            self.assertIn(token, normalized_master)

        top_retention = re.sub(
            r"\s+",
            " ",
            section(
                self.master,
                "**Three-day governed data posture.**",
                "This approval records the product intent",
            ),
        )
        for token in (
            "An ordinary, consented `eligibleLearning72Hours` admission starts at the committed K3 receipt and has an exact minimum of 72 hours plus a finite purpose-specific maximum",
            "Committed bytes needed for recovery use `recovery72Hours`. Their exact minimum is 72 hours from the same trusted K3 retention commit",
            "Terminal completion, routine pruning, archive, reboot, clock rollback, or disk pressure cannot delete them early",
        ):
            self.assertIn(token, top_retention)
        required_assertions = re.sub(
            r"\s+",
            " ",
            section(
                self.master,
                "## Required Assertions to Transplant into the Master and Domain Exit Gates",
                "## Completion State",
            ),
        )
        self.assertIn(
            "`recovery72Hours` and `eligibleLearning72Hours` each enforce an independent trusted-commit minimum of exactly 72 hours",
            required_assertions,
        )
        self.assertIn(
            "checkpoints copy no second retention clock",
            required_assertions,
        )
        for fixture_id in (
            "schema.BASRetentionAdmissionReceipt.current",
            "schema.BASRetentionAdmissionReceipt.future_rejection",
        ):
            self.assertEqual(self.master.count(fixture_id), 1, fixture_id)

        payload = section(self.master, "### Payload 4F", "### Payload 4G")
        normalized_payload = re.sub(r"\s+", " ", payload)
        for token in (
            "minimumRetainUntilMs = trustedStart + 72 * 60 * 60 * 1000",
            "maximumRetainUntilMs > minimumRetainUntilMs",
            "Terminal completion before `trustedStart + 259200000` cannot delete",
            "explicit/legal deletion, consent withdrawal, secret detection, or privacy/security reclassification",
            "`userDurable` uses the strict `.untilExplicitDeletion` horizon",
            "Disk pressure first removes rebuildable caches/projections",
            "both predecessor fields are nil only at revision zero",
            "every later request names the immediately preceding disposition receipt",
            "newDecisionRevision == priorDecisionRevision + 1",
            "purge and privacyFence are terminal",
            "no later disposition can resurrect",
        ):
            self.assertIn(token, normalized_payload)

        retention_mutations = (
            (
                "BASRetentionAdmissionReceipt",
                "public let committedRowVersion: UInt64",
                "public let rowVersion: UInt64",
            ),
            (
                "BASRetentionAdmissionReceipt",
                "public let privacyEpoch: UInt64",
                "public let privacyRevision: UInt64",
            ),
            (
                "BASRetentionDispositionReceipt",
                "public let newDecisionRevision: UInt64",
                "public let decisionRevision: UInt64",
            ),
        )
        for name, old, new in retention_mutations:
            with self.subTest(mutation=f"{name}:{old}"):
                mutated = replace_once_in_swift_declaration(
                    self.master, name, old, new
                )
                with self.assertRaises(AssertionError):
                    assert_exact_retention_wires(mutated)

        selected = required_test_selectors(self.master)
        for test_id in (
            RESILIENCE_HARDENING_SENTINELS[0],
            "BehavioralAISubstrateTests.BASAutomationCheckpointContractTests/"
            "testInstallReopenABIAcceptsCanonicalZeroOrLatestUseEvidenceExactlyOnce",
            RESILIENCE_HARDENING_SENTINELS[8],
            RESILIENCE_HARDENING_SENTINELS[9],
        ):
            self.assertEqual(selected.count(test_id), 1, test_id)

    def test_continuation_attention_and_command_recovery_are_concrete(self) -> None:
        def fields(name: str, candidate: str | None = None) -> dict[str, str]:
            block = swift_declaration_block(
                self.master if candidate is None else candidate, name
            )
            return {
                field: field_type.strip()
                for field, field_type in re.findall(
                    r"(?m)^\s*public let ([A-Za-z_][A-Za-z0-9_]*):\s*([^\n]+)",
                    block,
                )
            }

        self.assertEqual(
            fields("BASCacheCheckpointIdentity"),
            {
                "schemaVersion": "String",
                "cacheScopeContract": "BASCacheScopeContract",
                "providerExecutionRef": "BASProviderExecutionRef",
                "executionPlanArtifactID": "BASArtifactID",
                "executionPlanDigest": "String",
                "modelMaterialArtifactID": "BASArtifactID",
                "modelMaterialDigest": "String",
                "providerProfileArtifactID": "BASArtifactID",
                "providerProfileDigest": "String",
                "compiledContextDescriptorArtifactID": "BASArtifactID",
                "compiledContextDescriptorDigest": "String",
                "samplerState": "BASCheckpointSamplerState",
                "acceptedTokenPrefixArtifactID": "BASArtifactID",
                "acceptedTokenPrefixDigest": "String",
                "acceptedTokenCount": "UInt64",
                "acceptedOutputPrefixArtifactID": "BASArtifactID",
                "acceptedOutputPrefixDigest": "String",
                "cacheBodyArtifactID": "BASArtifactID",
                "cacheBodyDigest": "String",
                "cacheEncoding": "BASCacheCheckpointEncoding",
                "checkpointGeneration": "UInt64",
                "acceptedTokenRetentionAdmissionReceiptArtifactID": "BASArtifactID",
                "acceptedTokenRetentionAdmissionReceiptDigest": "String",
                "acceptedOutputRetentionAdmissionReceiptArtifactID": "BASArtifactID",
                "acceptedOutputRetentionAdmissionReceiptDigest": "String",
                "cacheBodyRetentionAdmissionReceiptArtifactID": "BASArtifactID",
                "cacheBodyRetentionAdmissionReceiptDigest": "String",
            },
        )
        sampler_block = swift_declaration_block(
            self.master, "BASCheckpointSamplerState"
        )
        sampler = re.sub(r"\s+", " ", sampler_block)
        self.assertEqual(
            swift_enum_cases(sampler_block),
            {"deterministic", "stochastic"},
        )
        self.assertIn(
            "case deterministic(configurationDigest: String)", sampler
        )
        self.assertIn(
            "case stochastic( configurationDigest: String, rngStateDigest: String )",
            sampler,
        )
        self.assertNotIn("rngStateArtifactID", sampler)
        continuation_fields = fields("BASContinuationCheckpointRef")
        for forbidden in ("checkpointIdentity", "checkpointArtifactID"):
            self.assertNotIn(forbidden, continuation_fields)
        for required in (
            "turnOperationRef",
            "workspaceRef",
            "workUnitRefArtifactID",
            "attemptRefArtifactID",
            "providerExecutionRef",
            "executionPlanArtifactID",
            "providerProfileArtifactID",
            "modelMaterialArtifactID",
            "compiledContextDescriptorArtifactID",
            "cacheCheckpointIdentityArtifactID",
            "acceptedTokenPrefixArtifactID",
            "acceptedOutputPrefixArtifactID",
            "cacheBodyArtifactID",
            "acceptedTokenRetentionAdmissionReceiptArtifactID",
            "acceptedOutputRetentionAdmissionReceiptArtifactID",
            "cacheBodyRetentionAdmissionReceiptArtifactID",
            "checkpointGeneration",
        ):
            self.assertIn(required, continuation_fields)
        receipt_fields = fields("BASProviderCheckpointReceipt")
        for forbidden in (
            "continuationCheckpointRef",
            "providerObservationReceiptArtifactID",
            "materializationReceiptArtifactID",
            "cacheEncoding",
        ):
            self.assertNotIn(forbidden, receipt_fields)
        for required in (
            "continuationCheckpointRefArtifactID",
            "continuationCheckpointRefDigest",
            "cacheCheckpointIdentityArtifactID",
            "cacheCheckpointIdentityDigest",
            "providerExecutionRef",
            "providerRuntimeIdentityArtifactID",
            "providerRuntimeIdentityDigest",
            "acceptedTokenPrefixArtifactID",
            "acceptedOutputPrefixArtifactID",
            "cacheBodyArtifactID",
            "acceptedTokenRetentionAdmissionReceiptArtifactID",
            "acceptedOutputRetentionAdmissionReceiptArtifactID",
            "cacheBodyRetentionAdmissionReceiptArtifactID",
            "representationDigest",
            "exactnessDisposition",
            "verificationReceiptArtifactID",
            "verificationReceiptDigest",
            "cacheScopeContractDigest",
            "verifiedRestorationEpoch",
            "verifiedCapabilityEpoch",
            "verifiedKillEpoch",
            "verifiedPolicyEpoch",
            "verifiedDeletionEpoch",
            "verifiedRevocationEpoch",
        ):
            self.assertIn(required, receipt_fields)

        route = re.sub(
            r"\s+", " ", swift_declaration_block(self.master, "BASContinuationRoute")
        )
        self.assertIn(
            "case recompileFromAcceptedPrefix( checkpointRefArtifactID: BASArtifactID, checkpointRefDigest: String )",
            route,
        )
        self.assertIn(
            "case accelerateWithVerifiedKV( checkpointRefArtifactID: BASArtifactID, checkpointRefDigest: String, providerCheckpointReceiptArtifactID: BASArtifactID, providerCheckpointReceiptDigest: String, cacheCheckpointIdentityArtifactID: BASArtifactID, cacheCheckpointIdentityDigest: String, verificationReceiptArtifactID: BASArtifactID, verificationReceiptDigest: String )",
            route,
        )
        materializer = re.sub(
            r"\s+",
            " ",
            swift_declaration_block(self.master, "BASProviderCheckpointMaterializer"),
        )
        for token in (
            "associatedtype CacheCheckpointIdentity: Codable & Sendable & Equatable",
            "_ ref: BASContinuationCheckpointRef",
            "cacheIdentity: CacheCheckpointIdentity",
            "authorizedCacheBody: BASAuthorizedArtifactRead",
            "async throws -> BASProviderCheckpointMaterializationObservation",
        ):
            self.assertIn(token, materializer)
        self.assertNotIn("-> BASContinuationRoute", materializer)
        observation = swift_declaration_block(
            self.master, "BASProviderCheckpointMaterializationObservation"
        )
        self.assertIn("Sendable, Equatable", observation)
        self.assertNotIn("Codable", observation)
        for required in (
            "cacheBodyArtifactID",
            "cacheBodyDigest",
            "acceptedTokenPrefixDigest",
            "acceptedTokenCount",
            "acceptedOutputPrefixDigest",
            "representationDigest",
            "exactnessDisposition",
            "cacheScopeContractDigest",
        ):
            self.assertIn(required, fields("BASProviderCheckpointMaterializationObservation"))

        attention = swift_declaration_block(self.master, "BASAttentionReentryProjection")
        self.assertIn("Sendable, Equatable", attention)
        self.assertNotIn("Codable", attention)
        self.assertNotIn("BASSchemaVersioned", attention)
        for required in (
            "logicalAgentRole",
            "turnOperationRef",
            "whyPurposeArtifactID",
            "orderedGoalArtifactIDs",
            "orderedCompletedSolutionArtifactIDs",
            "orderedNextEligibleNodeArtifactIDs",
            "sourceContinuityManifestDigest",
            "sourceMissionGraphDigest",
            "sourceSnapshotHighWatermark",
            "currentnessDigest",
            "recoveryQuality",
        ):
            self.assertIn(required, fields("BASAttentionReentryProjection"))

        durable_fields = fields("BASDurableToolRecoveryManifest")
        for required in (
            "toolInvocationID",
            "canonicalArgumentsArtifactID",
            "workingDirectoryArtifactID",
            "environmentAllowlistArtifactID",
            "inputTranscriptArtifactID",
            "outputTranscriptArtifactID",
            "canonicalArgumentsRetentionAdmissionReceiptArtifactID",
            "inputTranscriptRetentionAdmissionReceiptArtifactID",
            "outputTranscriptRetentionAdmissionReceiptArtifactID",
            "possibleStartDispositionArtifactID",
        ):
            self.assertIn(required, durable_fields)

        w1 = section(
            self.master,
            "## Controlled Domain-Plan Payload W1:",
            "## Controlled Domain-Plan Payload W2:",
        )
        w2 = section(
            self.master,
            "## Controlled Domain-Plan Payload W2:",
            "## Controlled Domain-Plan Payload W3:",
        )
        w4 = section(
            self.master,
            "### Payload 6D (W4)",
            "## Controlled Domain-Plan Payload W5:",
        )
        for declaration in (
            "BASCacheCheckpointIdentity",
            "BASContinuationCheckpointRef",
            "BASProviderCheckpointReceipt",
            "BASAttentionReentryProjection",
            "BASDurableToolRecoveryManifest",
        ):
            self.assertIn(f"public struct {declaration}", w1, declaration)
        self.assertNotIn("public enum BASContinuationRoute", w1)
        self.assertNotIn("public protocol BASProviderCheckpointMaterializer", w1)
        self.assertIn("public enum BASContinuationRoute", w4)
        self.assertIn("public protocol BASProviderCheckpointMaterializer", w4)

        checkpoint_types = (
            "BASCacheCheckpointIdentity",
            "BASContinuationCheckpointRef",
            "BASProviderCheckpointReceipt",
        )
        symbol_ledger = section(
            w1,
            "| Exact symbol/facet | Declaration/implementation path | Class | "
            "Authority candidate / gate row ID | Owner |",
            "\n\nNo row permits a new owner",
        )
        for type_name in checkpoint_types:
            rows = [
                line
                for line in symbol_ledger.splitlines()
                if line.startswith("|") and f"`{type_name}`" in line
            ]
            self.assertEqual(len(rows), 1, type_name)
            self.assertIn(
                "BASRuntimeCore/ProviderExecutionCore.swift", rows[0], type_name
            )
            for fixture_kind in ("current", "future_rejection"):
                fixture_id = f"schema.{type_name}.{fixture_kind}"
                self.assertEqual(self.master.count(fixture_id), 1, fixture_id)
            self.assertNotRegex(
                self.master,
                rf"schema\.{re.escape(type_name)}\.backward[A-Za-z0-9_.-]*",
                type_name,
            )

        resilience_w1 = section(
            self.master,
            "### W1 resilience first-wire supplement",
            "## Controlled Domain-Plan Payload W2:",
        )
        normalized_resilience_w1 = re.sub(r"\s+", " ", resilience_w1)
        self.assertIn("BASEBrainSchemaGovernanceRegistry", resilience_w1)
        chain_tokens = (
            "three inert body puts",
            "three independent K3 admissions",
            "three postcommit receipt puts/reopens",
            "Identity put",
            "Ref put",
        )
        previous_position = -1
        for token in chain_tokens:
            position = normalized_resilience_w1.find(token)
            self.assertGreater(position, previous_position, token)
            previous_position = position

        normalized_w2 = re.sub(r"\s+", " ", w2)
        for token in (
            "checkpoint install is a later K3 transaction",
            "reopens all three retention admission rows and their postcommit receipt Artifacts",
            "reopens `BASCacheCheckpointIdentity` and `BASContinuationCheckpointRef`",
            "only then publishes the checkpoint head",
        ):
            self.assertIn(token, normalized_w2)
        self.assertNotIn(
            "retention admission and checkpoint head commit atomically",
            normalized_w2,
        )

        normalized_w4 = re.sub(r"\s+", " ", w4)
        self.assertIn(
            "pure RuntimeCore factory constructs the self-ID-free "
            "`BASProviderCheckpointReceipt` and performs no I/O",
            normalized_w4,
        )
        self.assertIn(
            "upper Artifact facet ordinary-puts the factory result",
            normalized_w4,
        )
        self.assertNotIn(
            "factory constructs and ordinary-puts", normalized_w4
        )

        normalized = re.sub(r"\s+", " ", self.master)
        for token in (
            "accepted tokens and the accepted output prefix are the only continuation truth",
            "FP16 KV is optional acceleration",
            "Q4/lossy KV, MTP drafts, hidden reasoning, and unaccepted tokens are never recovery truth",
            "stochastic RNG physical state is part of the cache body",
            "does not claim to restore a Swift task stack, thread, process address space, OS-private state, Provider-hidden reasoning, or unsent model analysis",
            "same invocation identity enters query/reconcile and never replays an unknown command",
        ):
            self.assertIn(token, normalized)

        def assert_checkpoint_mutation_teeth(candidate: str) -> None:
            candidate_sampler = re.sub(
                r"\s+",
                " ",
                swift_declaration_block(candidate, "BASCheckpointSamplerState"),
            )
            self.assertIn("rngStateDigest: String", candidate_sampler)
            self.assertNotIn("rngStateArtifactID", candidate_sampler)
            candidate_receipt_fields = fields(
                "BASProviderCheckpointReceipt", candidate
            )
            for epoch in (
                "verifiedCapabilityEpoch",
                "verifiedKillEpoch",
                "verifiedRevocationEpoch",
            ):
                self.assertIn(epoch, candidate_receipt_fields)

        assert_checkpoint_mutation_teeth(self.master)
        checkpoint_mutations = (
            replace_once_in_swift_declaration(
                self.master,
                "BASCheckpointSamplerState",
                "rngStateDigest: String",
                "rngStateArtifactID: BASArtifactID",
            ),
            replace_once_in_swift_declaration(
                self.master,
                "BASProviderCheckpointReceipt",
                "public let verifiedRevocationEpoch: UInt64",
                "public let revocationEpoch: UInt64",
            ),
        )
        for ordinal, mutated in enumerate(checkpoint_mutations, start=1):
            with self.subTest(checkpoint_mutation=ordinal):
                with self.assertRaises(AssertionError):
                    assert_checkpoint_mutation_teeth(mutated)

        selected = required_test_selectors(self.master)
        for test_id in (
            RESILIENCE_HARDENING_SENTINELS[1],
            RESILIENCE_HARDENING_SENTINELS[2],
            RESILIENCE_HARDENING_SENTINELS[11],
            RESILIENCE_HARDENING_SENTINELS[15],
        ):
            self.assertEqual(selected.count(test_id), 1, test_id)

    def test_inquiry_is_user_durable_and_closed_across_waves(self) -> None:
        envelope = swift_declaration_block(self.master, "BASInquiryMessageEnvelope")
        normalized_envelope = re.sub(r"\s+", " ", envelope)
        for token in (
            "public let bodyArtifactID: BASArtifactID",
            "public let bodyDigest: String",
            "public let bodyRetentionAdmissionID: String",
            "public let bodyRetentionAdmissionReceiptArtifactID: BASArtifactID",
            "public let bodyRetentionAdmissionReceiptDigest: String",
        ):
            self.assertIn(token, normalized_envelope)

        branch = swift_declaration_block(self.master, "BASInquiryBranchRef")
        self.assertNotIn("retentionAdmissionArtifactID", branch)
        admission = swift_declaration_block(
            self.master, "BASRetentionAdmissionReceipt"
        )
        normalized_admission = re.sub(r"\s+", " ", admission)
        for token in (
            "public static let currentSchemaVersion = \"1.0.0\"",
            "public let requestDigest: String",
            "public let envelopeDigest: String",
            "public let retentionClass: BASRetentionClass",
            "public let contentArtifactID: BASArtifactID",
            "public let contentDigest: String",
        ):
            self.assertIn(token, normalized_admission)

        w1 = section(
            self.master,
            "## Controlled Domain-Plan Payload W1:",
            "## Controlled Domain-Plan Payload W2:",
        )
        w2 = section(
            self.master,
            "## Controlled Domain-Plan Payload W2:",
            "## Controlled Domain-Plan Payload W3:",
        )
        w5 = section(
            self.master,
            "## Controlled Domain-Plan Payload W5:",
            "## Controlled Domain-Plan Payload W6 Runtime:",
        )
        for token in (
            "BASInquiryBranchCreateRequest",
            "BASInquiryBranchCreateReceipt",
            "BASInquiryMessageAppendRequest",
            "BASInquiryMessageAppendReceipt",
            "BASInquiryBranchReopenRequest",
            "BASInquiryBranchSnapshot",
        ):
            self.assertIn(token, w1)
        normalized_w2 = re.sub(r"\s+", " ", w2)
        self.assertIn("body ordinary put is inert", normalized_w2)
        self.assertIn("admission precedes envelope put", normalized_w2)
        self.assertIn(
            "exact encrypted body with `.userDurable`",
            normalized_w2,
        )
        self.assertIn(
            "append transaction reopens the current admission row and receipt",
            normalized_w2,
        )
        self.assertIn("no transcript head can commit without", normalized_w2)
        self.assertIn("bodyRetentionAdmissionReceiptArtifactID", normalized_w2)
        self.assertEqual(
            normalized_w2.count("only the matching branch's transcript head"),
            2,
        )
        normalized_w5 = re.sub(r"\s+", " ", w5)
        self.assertIn("read/presentation Provider grant", normalized_w5)
        self.assertIn("new main-line Attempt", normalized_w5)

        selected = required_test_selectors(self.master)
        for test_id in (
            RESILIENCE_HARDENING_SENTINELS[3],
            RESILIENCE_HARDENING_SENTINELS[7],
            RESILIENCE_HARDENING_SENTINELS[14],
        ):
            self.assertEqual(selected.count(test_id), 1, test_id)

    def test_plan_context_maintenance_and_persona_have_wave_local_gates(self) -> None:
        closure = section(
            self.master,
            "#### G. Journal-first continuity, context, portfolio, and inquiry closure",
            "---\n\n## Task 0: Select and Pin the Only Convergence Predecessor",
        )
        normalized_closure = re.sub(r"\s+", " ", closure)
        self.assertIn("per-turn-context-maintenance", closure)
        self.assertIn("per-model-context-adaptation", closure)
        self.assertIn("W3", closure)
        self.assertIn("W4", closure)

        persona = swift_declaration_block(self.master, "BASPersonaSourceCard")
        for token in (
            "subjectClassification",
            "subjectReferenceArtifactID",
            "orderedSourceArtifactIDs",
            "orderedSourceDigests",
            "orderedClaimEvidenceArtifactIDs",
            "boundedPresentationTraits",
            "uncertaintyDigest",
            "scopeDigest",
            "expiresAtTrustedWallMs",
            "nonDeceptionPolicyArtifactID",
        ):
            self.assertIn(token, persona)
        self.assertIn(
            "public let subjectClassification: BASPersonaSubjectClassification",
            persona,
        )
        classification = swift_declaration_block(
            self.master, "BASPersonaSubjectClassification"
        )
        self.assertEqual(
            swift_enum_cases(classification),
            {"publicFigure", "fictionalCharacter"},
        )
        w1 = section(
            self.master,
            "## Controlled Domain-Plan Payload W1:",
            "## Controlled Domain-Plan Payload W2:",
        )
        self.assertIn("public enum BASPersonaSubjectClassification", w1)
        self.assertIn("public struct BASPersonaSourceCard", w1)

        selected = required_test_selectors(self.master)
        for test_id in (
            RESILIENCE_HARDENING_SENTINELS[4],
            RESILIENCE_HARDENING_SENTINELS[6],
            RESILIENCE_HARDENING_SENTINELS[10],
            RESILIENCE_HARDENING_SENTINELS[11],
            RESILIENCE_HARDENING_SENTINELS[12],
        ):
            self.assertEqual(selected.count(test_id), 1, test_id)

        w3_context = section(self.master, "### Payload 6A", "### Payload 6D (W4)")
        for index in (10, 11, 12):
            self.assertIn(
                RESILIENCE_HARDENING_SENTINELS[index].split("/", 1)[1],
                w3_context,
            )
        self.assertIn("neutral safe style", normalized_closure)

    def test_pcc_roster_and_apple_capability_edges_are_physically_bound(self) -> None:
        w1 = section(
            self.master,
            "## Controlled Domain-Plan Payload W1:",
            "## Controlled Domain-Plan Payload W2:",
        )
        qinao_concrete_paths: set[str] = set()
        for base in (ROOT / "QinaoRuntimeSDK/Sources", ROOT / "QinaoRuntimeSDK/Tests"):
            for path in base.rglob("*.swift"):
                source = path.read_text(encoding="utf-8")
                if re.search(
                    r"(?m)^\s*import\s+(?:BASAppleAdapters|BASMLXAdapter|"
                    r"BASChatCompletionsAdapter|FoundationModels)\b|"
                    r"\b(?:AppleFoundationOrganAdapter|LanguageModelSession|"
                    r"SystemLanguageModel|PrivateCloudComputeLanguageModel)\s*\(",
                    source,
                ):
                    qinao_concrete_paths.add(str(path.relative_to(ROOT)))
        self.assertGreaterEqual(len(qinao_concrete_paths), 20)
        for path in sorted(qinao_concrete_paths):
            self.assertIn(path, w1, path)
        for token in (
            "exhaustive and bidirectional",
            "every concrete-provider product, target, dependency, import, construction and registration",
            "testQinaoSDKContainsNoConcreteProviderRuntime",
        ):
            self.assertIn(token, re.sub(r"\s+", " ", w1))

        w4 = section(
            self.master,
            "### Payload 6D (W4)",
            "## Controlled Domain-Plan Payload W5:",
        )
        normalized_w4 = re.sub(r"\s+", " ", w4)
        for token in (
            "PrivateCloudComputeLanguageModel",
            "availability",
            ".deviceNotEligible",
            ".systemNotReady",
            "quotaUsage",
            ".belowLimit",
            ".limitReached",
            "contextSize",
            "supportedLanguages",
            "supportsLocale",
            "production invocation remains disabled until W5",
            "AFM remains only a negative compatibility fixture",
            "The incumbent AFM peer-Main, MiniCPM-V, and Granite-97M entries are retired compatibility/migration inputs and cannot be selected",
            "Default concurrency is one; an evidence-bound experimental maximum of two",
            "This W4 slice cannot reference W5 handoff/respond markers; it tests only profile/context/accounting and private-state isolation before possible-start",
            "No session, response call, handoff marker or possible-start edge is legal in W4",
            "BASCoreAIRosterAdapters.swift",
            "BASCoreAIRosterComposition.swift",
            "BASMemory.BASEmbeddingProvider",
            "BASMemory.BASVectorReranker",
            "manifest role -> asset -> certified tensor/tokenizer ABI -> adapter protocol",
            "the runner's existing generic named-tensor `run` call alone is never treated as a language-model adapter",
        ):
            self.assertIn(token, normalized_w4)
        self.assertNotIn("LanguageModelSession(model:", w4)

        w5 = section(
            self.master,
            "## Controlled Domain-Plan Payload W5:",
            "## Controlled Domain-Plan Payload W6 Runtime:",
        )
        normalized_w5 = re.sub(r"\s+", " ", w5)
        for token in (
            "PrivateCloudComputeLanguageModel()",
            "LanguageModelSession(model:",
            "omitted-model initializer is forbidden",
            "SystemLanguageModel.default",
            "AFM remains only a negative compatibility fixture",
            "AppleFoundationOrganAdapter.swift",
            "AppleFoundationOrganAdapter+Streaming.swift",
            "ProviderExecutionCore.swift",
            "pccRespondEntered",
            "same Attempt may query/reconcile only",
            "cannot resend",
            "After handoff or any lost/unknown reply, the same Attempt may query/reconcile only; it cannot resend, clear a marker, create a second PCC session, or swap to Qwen/API",
            "the same Attempt may query/reconcile only where an authenticated owner seam actually exists; otherwise it remains indeterminate",
            "It cannot resend, clear or replace the marker, create a second session, swap Provider, or infer success from app-visible partial chunks",
            "typed unavailable/indeterminate",
            "networkFailure",
            "quotaLimitReached",
            "serviceUnavailable",
            "BASBoundedWebSourceToolHandler.swift",
            "BASCoreAIRosterComposition.swift",
            "startup-time, duplicate-rejecting immutable",
            "typed `query`, `compensate` and `unsupported`",
            "`dispatchBatch` is not a production effect shortcut",
            "BASJournalCLI/MirrorLane.swift",
            "AppleFoundationOrganAdapterTests.swift",
            "BASToolDispatcherTests.swift",
            "BASPersistedToolResultPayload",
            "actually connected endpoint",
            "existing signed Release map",
            "It cannot create a Persona card, mutate the active Attempt or release an answer",
        ):
            self.assertIn(token, normalized_w5)
        apple_foundation_paths: set[str] = set()
        for base in (
            ROOT / "BehavioralAISubstrate/Sources",
            ROOT / "BehavioralAISubstrate/Tests",
        ):
            for path in base.rglob("*.swift"):
                source = path.read_text(encoding="utf-8")
                if re.search(
                    r"(?m)^\s*import\s+FoundationModels\b|"
                    r"\bAppleFoundationOrganAdapter\s*\(|"
                    r"\bLanguageModelSession\s*\(",
                    source,
                ):
                    apple_foundation_paths.add(str(path.relative_to(ROOT)))
        self.assertGreaterEqual(len(apple_foundation_paths), 12)
        for path in sorted(apple_foundation_paths):
            self.assertIn(path, w5, path)

        apple = section(self.master, "### Payload 9C", "### Payload 9D")
        header = (
            "| Borrowed Apple capability | Existing typed edge | Mutation posture | "
            "Enablement proof |"
        )
        rows = markdown_table_rows(apple, header)
        expected_capabilities = {
            "Vision/VisionKit",
            "SpeechAnalyzer/SpeechTranscriber",
            "SoundAnalysis",
            "NaturalLanguage/Translation",
            "CoreSpotlight query",
            "CoreSpotlight index/delete",
        }
        self.assertEqual({row[0] for row in rows}, expected_capabilities)
        by_capability = {row[0]: row for row in rows}
        self.assertIn("AppleReadGateway", by_capability["CoreSpotlight query"][1])
        self.assertIn("Zone-C", by_capability["CoreSpotlight index/delete"][1])
        self.assertIn("BASNLEmbeddingProvider", by_capability["NaturalLanguage/Translation"][1])
        self.assertIn("no implicit dense fallback", by_capability["NaturalLanguage/Translation"][2])
        self.assertIn("implementation digest", by_capability["CoreSpotlight index/delete"][3])
        for row in rows:
            self.assertNotIn("Agent", row[1])
            self.assertIn("owner", row[3].lower())
        self.assertIn(
            "framework availability alone is never a capability grant",
            re.sub(r"\s+", " ", apple),
        )

        selected = required_test_selectors(self.master)
        for test_id in (
            RESILIENCE_HARDENING_SENTINELS[5],
            RESILIENCE_HARDENING_SENTINELS[13],
            RESILIENCE_HARDENING_SENTINELS[16],
            RESILIENCE_HARDENING_SENTINELS[17],
        ):
            self.assertEqual(selected.count(test_id), 1, test_id)

        morpho_inventory = re.sub(
            r"\s+",
            " ",
            section(self.master, "### Payload 10E", "### Payload 10F"),
        )
        for token in (
            "`MorphoHDL` is an explicit negative inventory row",
            "Candidate-tree source, dependency, object, link, resource, registry, entrypoint and Release-archive scans must all prove zero shipping/runtime/compiler/store/owner reachability",
            "The positive lab fixture may emit only one bounded immutable mission-graph successor proposal",
        ):
            self.assertIn(token, morpho_inventory)
        morpho = section(self.master, "### Payload 10F", "### Payload 10G")
        for token in (
            "MorphoHDL",
            "source",
            "dependency",
            "object",
            "link",
            "resource",
            "registry",
            "entrypoint",
            "archive",
            "zero shipping",
        ):
            self.assertIn(token, morpho)

        for test_id in RESILIENCE_HARDENING_SENTINELS:
            self.assertEqual(selected.count(test_id), 1, test_id)

        apple_lab = section(
            self.master,
            "## Controlled Domain-Plan Payload W6 Apple Lab:",
            "## Controlled Domain-Plan Payload W6 Certification:",
        )
        governed_xcode_commands = [
            command
            for block in fenced_shell_blocks(apple_lab)
            for command in logical_shell_commands(block)
            if "scripts/run_governed_xcode_project.py" in command
        ]
        by_subcommand: dict[str, list[list[str]]] = {
            "inspect": [],
            "build-test": [],
            "archive": [],
        }
        for command in governed_xcode_commands:
            argv = direct_runner_argv(
                command, "scripts/run_governed_xcode_project.py"
            )
            self.assertIn(argv[2], by_subcommand)
            by_subcommand[argv[2]].append(argv)
        self.assertEqual(
            {name: len(rows) for name, rows in by_subcommand.items()},
            {"inspect": 1, "build-test": 1, "archive": 1},
        )
        self.assertEqual(
            option_values(by_subcommand["inspect"][0], "--output-root"),
            ["$QINAO_W6_XCODE_INSPECT_ROOT"],
        )
        self.assertEqual(
            option_values(by_subcommand["archive"][0], "--output-root"),
            ["$QINAO_W6_XCODE_ARCHIVE_ROOT"],
        )
        self.assertNotIn("--archive-path", by_subcommand["archive"][0])
        build_test_commands = [
            command
            for command in governed_xcode_commands
            if "scripts/run_governed_xcode_project.py build-test" in command
        ]
        self.assertEqual(len(build_test_commands), 1)
        xcode_argv = direct_runner_argv(
            build_test_commands[0], "scripts/run_governed_xcode_project.py"
        )
        self.assertEqual(
            option_values(xcode_argv, "--output-root"),
            ["$QINAO_W6_XCODE_BUILD_TEST_ROOT"],
        )
        pcc_test = (
            "BASDeviceTests/BASPCCPhysicalProbeTests/"
            "testForegroundPCCProbeBindsExplicitModelDeviceEvidenceAndNoResend"
        )
        self.assertEqual(option_values(xcode_argv, "--require-test").count(pcc_test), 1)
        self.assertEqual(
            option_values(xcode_argv, "--require-attachment"),
            [
                pcc_test
                + ":qinao-pcc-observation-v1.json:"
                + "qinao.pcc-physical-observation/1.0.0"
            ],
        )
        evidence_commands = [
            command
            for block in fenced_shell_blocks(apple_lab)
            for command in logical_shell_commands(block)
            if "scripts/assert_xcode_test_evidence.py" in command
        ]
        self.assertEqual(len(evidence_commands), 1)
        evidence_argv = direct_runner_argv(
            evidence_commands[0], "scripts/assert_xcode_test_evidence.py"
        )
        self.assertEqual(
            option_values(evidence_argv, "--build-test-manifest"),
            [
                "$QINAO_W6_XCODE_BUILD_TEST_ROOT/"
                "qinao-governed-xcode-build-test-manifest-v1.json"
            ],
        )
        self.assertEqual(
            option_values(evidence_argv, "--device-lifecycle-receipt"),
            [
                "docs/superpowers/evidence/"
                "qinao-w6-apple-device-lifecycle-receipt.json"
            ],
        )
        profile_commands = [
            command
            for block in fenced_shell_blocks(apple_lab)
            for command in logical_shell_commands(block)
            if "scripts/assert_qinao_ios27_device_profile.py" in command
        ]
        self.assertEqual(len(profile_commands), 1)
        profile_argv = direct_runner_argv(
            profile_commands[0], "scripts/assert_qinao_ios27_device_profile.py"
        )
        self.assertEqual(
            option_values(profile_argv, "--profile"),
            ["$QINAO_IOS27_DEVICE_PROFILE"],
        )
        self.assertEqual(
            option_values(profile_argv, "--trust-root"),
            ["$QINAO_ADMISSION_TRUST_ROOT"],
        )
        for token in (
            "BASFoundationModelsProbe.swift",
            "BASPCCPhysicalProbeTests.swift",
            "qinao-governed-xcode-build-test-manifest-v1.json",
            "qinao.governed-xcode-build-test-manifest/1.0.0",
            "qinao-governed-xcode-archive-manifest-v1.json",
            "qinao.governed-xcode-archive-manifest/1.0.0",
            "--build-test-manifest",
            "builtAppPath",
            "xcresultSummaryPath",
            "builtEntitlementsPath",
            "caller cannot supply or override",
            "--device-lifecycle-receipt",
            "cannot be handwritten independently of xcresult evidence",
        ):
            self.assertIn(token, apple_lab)
        for forbidden in (
            "$QINAO_DERIVED_DATA_PATH",
            "$QINAO_BUILT_ENTITLEMENTS_PATH",
            "$QINAO_XCRESULT_SUMMARY_PATH",
            "QINAO_BUILT_APP=",
            "$QINAO_ARCHIVE_PATH",
        ):
            self.assertNotIn(forbidden, apple_lab)

    def test_snapshot_sufficiency_identity_question_and_dispute_contracts_close(
        self,
    ) -> None:
        closure = section(
            self.master,
            "#### A. Snapshot, human-fit, question, and dispute closure",
            "#### B. Dynamic DAG, mission graph, rebase, checkpoint, and recovery closure",
        )
        normalized = re.sub(r"\s+", " ", closure)
        for token in (
            "state.snapshot-contracts",
            "BASSemanticStateLakeContracts.swift",
            "BASInformationSufficiencyPayload",
            "preflight",
            "finalOutcome",
            "readyVerified",
            "remandRetrieval",
            "remandTool",
            "needsClarification",
            "partialVerified",
            "abstain",
            "denied",
            "at most one ordinary remand",
            "HumanFitProjection",
            "confirmed durable preference",
            "authorized stable user identity",
            "selected App Agent",
            "BASNextQuestionProjection",
            "zero through five candidates",
            "render-currentness CAS",
            "no pre-tap work",
            "DisputeEpisodeEntry",
            "stable logicalInvocationKey",
            "inherited budget-use receipt and visited-state commitment",
            "fresh Attempt",
            "no `InformationSufficiencyManager`, `RecognitionManager`, `ChallengeManager`, or second projector",
        ):
            self.assertIn(token, normalized)

    def test_dag_rebase_recovery_checkpoint_and_lineage_contracts_close(self) -> None:
        closure = section(
            self.master,
            "#### B. Dynamic DAG, mission graph, rebase, checkpoint, and recovery closure",
            "#### C. Causality and observable reasoning closure",
        )
        normalized = re.sub(r"\s+", " ", closure)
        for token in (
            "runtime.semantic-dag",
            "BASSemanticTurnDAG.swift",
            "frozenSlot",
            "alternative",
            "delegation",
            "join",
            "boundTerminal",
            "provedUnused",
            "rejectedBeforeAllocation",
            "Mission → Objective → WorkUnit → Attempt → SolutionArtifact",
            "rebase_pending",
            "inactive successor grant",
            "active-head CAS",
            "BASAttemptRebaseReceipt",
            "safePreclaim",
            "reconcileOnly",
            "staleBoot",
            "liveSameBoundary",
            "BASAutomationCheckpointInstallRequest",
            "BASAutomationCheckpointReopenReceipt",
            "latest budget-use receipt XOR K3 zero-use proof",
            "trusted-now",
            "maximumInterruptionAgeMs",
            "ContextContinuityManifest.validateReopenedLineage",
            "same TurnOperation, snapshot, graph, generation, epoch, and Workspace lineage",
        ):
            self.assertIn(token, normalized)

    def test_dynamic_dag_reuses_the_approved_literal_wire_family(self) -> None:
        closure = section(
            self.master,
            "#### B. Dynamic DAG, mission graph, rebase, checkpoint, and recovery closure",
            "#### C. Causality and observable reasoning closure",
        )
        normalized = re.sub(r"\s+", " ", closure)
        for token in (
            "BASSemanticTurnEdge = {fromSlotID,toSlotID,dependencyRole,consumerInputSlotContractDigest}",
            "dataConsumption|controlBarrier|authorization|budget|snapshot|verification|effectPredecessor|publicationPredecessor",
            "BASSemanticTurnEdgeBinding = {edgeID,predecessorTerminalReceiptArtifactID,predecessorOutputArtifactID,consumerInputSlotID,consumerBindingArtifactID,attemptID,generation,epoch}",
            "BASDelegationSlotContract",
            "BASDelegationSlotClosure",
            "static topology never embeds dynamic receipt IDs",
        ):
            self.assertIn(token, normalized)

    def test_recovery_boundary_matrix_is_a_literal_copy_of_the_approved_source(
        self,
    ) -> None:
        approved = AGENT_CONTEXT_ADDENDUM.read_text(encoding="utf-8")
        matrix_header = (
            "| Exact mutually exclusive presence and proof | "
            "Per-boundary class | Only legal step |"
        )
        matrix_end = "The rows are mutually exclusive after first partitioning"
        approved_matrix = section(approved, matrix_header, matrix_end)
        active_matrix = section(self.master, matrix_header, matrix_end)
        self.assertEqual(active_matrix, approved_matrix)
        self.assertGreaterEqual(active_matrix.count("\n|"), 50)

    def test_causality_and_observable_reasoning_contracts_close(self) -> None:
        closure = section(
            self.master,
            "#### C. Causality and observable reasoning closure",
            "#### D. Provider-neutral context, grounding, API, and Core AI closure",
        )
        normalized = re.sub(r"\s+", " ", closure)
        for token in (
            "execution dependency",
            "ClaimSupportMap",
            "WorldClaimSet",
            "ExplanationProjection",
            "supports",
            "contradicts",
            "conflicted",
            "sequence and co-occurrence never establish world causation",
            "BASKnowledgeGraphEventExtractor",
            "LegacyCausality.projectUntrustedAssociations",
            "ConstraintLedger",
            "raw UTF-8 span",
            "canonical AST",
            "VerifierClaimContract",
            "committed before use",
            "exact downstream-consumer receipt",
            "explanationOnly",
            "directAttribution",
            "diagnosticAssociation",
            "identifiedCausalEffect",
            "zero process reward and zero causal credit",
        ):
            self.assertIn(token, normalized)

    def test_provider_context_grounding_api_and_coreai_contracts_close(self) -> None:
        closure = section(
            self.master,
            "#### D. Provider-neutral context, grounding, API, and Core AI closure",
            "#### E. Governed learning and data-flywheel closure",
        )
        normalized = re.sub(r"\s+", " ", closure)
        for token in (
            "CertifiedContextGeometry",
            "deterministicTokenSpans",
            "opaqueRuntimeExactCount",
            "certifiedConservativeUpperBound",
            "sharedTotal",
            "splitInputOutput",
            "encoderOnly",
            "LocalOperatingEnvelope",
            "SystemOpaqueEnvelope",
            "SystemManagedRemoteOpaqueEnvelope",
            "RemoteOperatingEnvelope",
            "AFMAccountingShape",
            "smallGroundingProposal",
            "proposal-only specialist",
            "BASCoreMLLayerHead",
            "purpose-and-digest allowlist",
            "BASChatCompletionsOrganAdapter.swift",
            "credential handle",
            "egress",
            "query/reconcile",
            "BASContextClassifier.aimodel",
            "is rejected before load",
            "exact tensor ABI",
            "Without a language model, deterministic persona formatting remains available",
        ):
            self.assertIn(token, normalized)
        for noncanonical_tag in (
            "LocalExact",
            "AFMSystemOpaque",
            "PCCSystemManagedRemoteOpaque",
            "CustomRemoteExact",
        ):
            self.assertNotIn(noncanonical_tag, closure)

    def test_governed_learning_contract_and_incumbent_dispositions_close(self) -> None:
        closure = section(
            self.master,
            "#### E. Governed learning and data-flywheel closure",
            "#### F. Exact closure sentinels and non-vacuous wave gates",
        )
        normalized = re.sub(r"\s+", " ", closure)
        for token in (
            "RewardEvidenceVector",
            "DatasetManifest",
            "TrainingJobManifest",
            "Policy-A",
            "Evidence-B",
            "SFT",
            "DPO",
            "KTO",
            "IPO",
            "ORPO",
            "RLVR",
            "GRPO",
            "contextual bandit",
            "BASDistillationBank",
            "BASUpdateTicketLifecycleCoordinator",
            "BASShadowTrialCoordinator",
            "BASABProtocolSpec",
            "BASCoreAIShadowComparison",
            "QinaoLearningExporter",
            "MLXLoRATrainer",
            "BASAppleInterventionBanditAdvisor",
            "The incumbent disposition is decided now",
            "external trainer computes gradients but cannot sign, admit, or cut over",
            "future snapshot only",
            "same-operation feedback is forbidden",
        ):
            self.assertIn(token, normalized)

    def test_closure_sentinels_are_exact_bidirectional_and_wave_nonvacuous(
        self,
    ) -> None:
        expected_by_wave = {
            "W1": (
                "BASInformationSufficiencyContractTests/testPhaseOutcomeMatrixAndSingleRemandAreExact",
                "BASHumanFitProjectionContractTests/testRecognitionUsesOnlyAuthorizedStableIdentityAndConfirmedDurablePreferences",
                "BASNextQuestionContractTests/testProjectionAbstainsAndRenderCASRejectsStaleOrPreTapWork",
                "BASContextContinuityContractTests/testDisputeEpisodeKeepsStableIdentityBudgetAndVisitedStateAcrossAttempts",
                "BASContextContinuityContractTests/testManifestCursorLineageRejectsForeignSnapshotGraphEpochOrWorkspace",
                "BASSemanticTurnDAGTests/testFrozenDynamicDAGWireClosesSlotsAlternativesDelegationJoinsAndTerminals",
                "BASMissionTaskGraphContractTests/testMissionObjectiveWorkUnitAttemptSolutionGraphHasOneRootCAS",
                "BASAutomationCheckpointContractTests/testInstallReopenABIAcceptsCanonicalZeroOrLatestUseEvidenceExactlyOnce",
                "BASContinuationPolicyContractTests/testTrustedNowInterruptionBoundaryAndConfirmationMatrixFailsClosed",
                "BASReasoningArtifactContractTests/testBeforeUseCommitAndConsumerReceiptGateProcessCredit",
                "BASCausalitySeparationContractTests/testExecutionClaimSupportAndWorldCausationAreNonInterchangeable",
                "BASClaimSupportMapContractTests/testEachMaterialClaimHasOneConflictPreservingAggregate",
                "BASWorldClaimSetContractTests/testSequenceOrCoOccurrenceCannotBecomeSupportedCausation",
                "BASConstraintLedgerContractTests/testRawSpanASTAndHardConstraintMutationsCannotBeLost",
                "BASProviderProfileVariantContractTests/testFourTaggedProfilesHaveExactPresenceAndUnavailableMatrices",
                "BASContextAccountingContractTests/testExactOpaqueAndConservativeAccountingObeyCertifiedTopology",
                "BASClassicMLContractTests/testAllowlistedCoreMLHeadCannotImpersonatePortfolioRole",
                "BASGovernedLearningContractTests/testLearningFamiliesAndIncumbentsHaveExactOwnerDispositions",
                "BASTrainingJobManifestContractTests/testTrainerChoiceIsBoundToEvidenceShapeAndVerifierDomain",
                "BASLearningCreditContractTests/testPostHocOrUnconsumedReasoningHasZeroProcessRewardAndCausalCredit",
                "BASEvidenceBCommitProtocolTests/testPolicyAExplorationOPEAndEvidenceBCutoverRemainSeparate",
                "BASContextRebaseContractTests/testContextRebaseRequestFreezesBoundaryBudgetRightsCeilingsHeadBootDeadlineAndEpochs",
                "BASAutomationRunContractTests/testReducerStateEvidenceMatrixRejectsIllegalCancellationReconciliationAndTerminalEdges",
                "BASAutomationRunContractTests/testBoundaryDispositionWireRejectsEmptyBadDigestWrongTagAndUnknownFields",
            ),
            "W2": (
                "BASAttemptRebaseRecoveryTests/testPendingPrecedesReservationAndAuthorizesNoSemanticWork",
                "BASAttemptRebaseRecoveryTests/testTwoWritersProduceExactlyOneActiveHeadAndOneRebaseReceipt",
                "BASAttemptRebaseRecoveryTests/testCrashAfterActiveHeadCASReopensWinningReceiptWithoutSecondSuccessor",
                "BASAutomationK3LifecycleTests/testK3ReopensPersistedBoundaryProvenanceBeforeReducerCAS",
            ),
            "W3": (
                "BASExplanationProjectionTests/testReplayFromFrozenRootsIsByteIdenticalAndDisclosureFiltered",
                "BASSemanticStateMarketTests/testModelGroundingRequiresProposalOnlySmallSpecialistProfile",
            ),
            "W4": (
                "BASPCCContextAccountingTests/testOpaqueQuotaBoundAccountingRechecksBeforeAllocation",
                "BASCoreAIConversionContractTests/testLegacyAssetIsRejectedAndExactTensorABIIsCertified",
            ),
            "W5": (
                "BASChatCompletionsGovernanceTests/testExistingAdapterUsesGovernedCredentialAccountingEgressAndReconcile",
                "BASK4AuthorizationLedgerTests/testReservedSuccessorGrantIsNonConsumableBeforeWinningK3Activation",
                "BASK4AuthorizationLedgerTests/testActivationReplyLossReopensUsableOrPendingWithoutSecondGrant",
                "BASK4AuthorizationLedgerTests/testDenialFenceIsDurableMonotonicAndNeverRollsBackActiveHead",
            ),
            "W6": (
                "BASAutomationBoundaryRecoveryTests/testRecoveryDispositionMatrixAllowsOnlyOneLegalActionPerBoundaryProof",
                "BASContextRebaseContractTests/testAtomicRebaseActivatesReservedGrantOnlyAfterActiveHeadCAS",
                "BASContextRebaseContractTests/testActivationPendingCannotRunRollbackOrMintReplacementGrant",
                "BASContextRebaseContractTests/testTerminalDeniedNeverRollsBackPredecessorOrIssuesSecondGrant",
                "BASLegacyCausalityRetirementTests/testLegacyCausesRowsCannotReachAuthoritativeStateOrRelease",
                "BASZeroModelSurvivalE2ETests/testDeterministicPersonaFormattingPreservesNeutralVerifiedContentWithoutModel",
            ),
        }
        wave_sections = {
            "W1": section(
                self.master,
                "## Controlled Domain-Plan Payload W1:",
                "## Controlled Domain-Plan Payload W2:",
            ),
            "W2": section(
                self.master,
                "## Controlled Domain-Plan Payload W2:",
                "## Controlled Domain-Plan Payload W3:",
            ),
            "W3": section(
                self.master,
                "## Controlled Domain-Plan Payload W3:",
                "## Controlled Domain-Plan Payload W5:",
            ),
            "W4": section(
                self.master,
                "### Payload 6D (W4)",
                "## Controlled Domain-Plan Payload W5:",
            ),
            "W5": section(
                self.master,
                "## Controlled Domain-Plan Payload W5:",
                "## Controlled Domain-Plan Payload W6 Runtime:",
            ),
            "W6": self.master[
                self.master.index("## Controlled Domain-Plan Payload W6 Runtime:") :
            ],
        }
        expected_full: list[str] = []
        for wave, short_ids in expected_by_wave.items():
            commands = [
                command
                for block in fenced_shell_blocks(wave_sections[wave])
                for command in logical_shell_commands(block)
                if "scripts/run_nonempty_swift_filter.py" in command
            ]
            for short_id in short_ids:
                suite, test_name = short_id.split("/", 1)
                full_id = f"BehavioralAISubstrateTests.{suite}/{test_name}"
                expected_full.append(full_id)
                matching = [
                    command
                    for command in commands
                    if f"--require-suite {suite}" in command
                    and f"--require-test {full_id}" in command
                ]
                self.assertEqual(len(matching), 1, (wave, full_id))

        listed = listed_swift_sentinel_ids(self.master)
        self.assertEqual(len(expected_full), 42)
        self.assertEqual(len(expected_full), len(set(expected_full)))
        self.assertTrue(set(expected_full) <= listed)

    def test_required_assertions_keep_closure_future_and_owner_complete(self) -> None:
        assertions = section(
            self.master,
            "## Required Assertions to Transplant into the Master and Domain Exit Gates",
            "## Completion State",
        )
        normalized = re.sub(r"\s+", " ", assertions)
        for token in (
            "seven-outcome information sufficiency",
            "stable dispute episode",
            "atomic context rebase",
            "exact recovery-disposition matrix",
            "dynamic frozen DAG",
            "three non-interchangeable causality tracks",
            "small-model grounding specialist",
            "four tagged Provider profiles",
            "Core AI conversion evidence",
            "complete governed-learning protocol",
            "no same-operation feedback",
            "every Swift suite listed under `Create tests` is individually required",
            "closed plan-wide risk-sentinel inventory is separately and bidirectionally required by exact test ID",
        ):
            self.assertIn(token, normalized)
        completion = self.master[self.master.index("## Completion State") :]
        self.assertIn("W1-W6 remain future, unadmitted, and uncompleted", completion)
        self.assertNotRegex(completion, r"(?m)^- \[x\]")

    def test_closure_owner_wave_path_matrix_is_executable(self) -> None:
        sections = {
            "W1": section(
                self.master,
                "## Controlled Domain-Plan Payload W1:",
                "## Controlled Domain-Plan Payload W2:",
            ),
            "W2": section(
                self.master,
                "## Controlled Domain-Plan Payload W2:",
                "## Controlled Domain-Plan Payload W3:",
            ),
            "W3": section(
                self.master,
                "## Controlled Domain-Plan Payload W3:",
                "### Payload 6D (W4)",
            ),
            "W4": section(
                self.master,
                "### Payload 6D (W4)",
                "## Controlled Domain-Plan Payload W5:",
            ),
            "W5": section(
                self.master,
                "## Controlled Domain-Plan Payload W5:",
                "## Controlled Domain-Plan Payload W6 Runtime:",
            ),
            "W6": self.master[
                self.master.index("## Controlled Domain-Plan Payload W6 Runtime:") :
            ],
        }
        expected = {
            "W1": (
                "BASSemanticStateLakeContracts.swift",
                "BASSemanticTurnDAG.swift",
                "BASInformationSufficiencyPayload",
                "BASMissionTaskGraph",
                "BASAutomationCheckpointInstallRequest",
                "CertifiedContextGeometry",
                "TrainingJobManifest",
            ),
            "W2": (
                "BASSQLiteEventLogStorage.swift",
                "advanceMissionTaskGraphRoot",
                "installAutomationCheckpoint",
                "claimBudgetUse",
                "advanceProjectorCursor",
                "advanceLearningCandidateHead",
            ),
            "W3": (
                "BASSemanticStateMarket.swift",
                "BASKunlunLayerProjections.swift",
                "produceInformationSufficiencyCandidate",
                "projectHumanFit",
                "projectNextQuestion",
                "deriveClaimSupportMap",
                "authorWorldClaimSet",
                "smallGroundingProposal",
            ),
            "W4": (
                "BASCoreMLConversionContract.swift",
                "BASCoreAIContextClassifierAdapter.swift",
                "accountSystemManagedRemoteOpaque",
                "validateCertifiedContextGeometry",
            ),
            "W5": (
                "BASChatCompletionsOrganAdapter.swift",
                "BASExactOutputVerificationPayload.claimSupportMap",
                "governedRemoteEgress",
            ),
            "W6": (
                "BASAutomationBoundaryRecoveryTests.swift",
                "BASLegacyCausalityRetirementTests.swift",
                "performAtomicContextRebase",
                "classifyRecoveryDisposition",
                "LegacyCausality.projectUntrustedAssociations",
                "certifyGovernedLearningCandidate",
                "same-operation feedback",
            ),
        }
        for wave, tokens in expected.items():
            normalized = re.sub(r"\s+", " ", sections[wave])
            for token in tokens:
                self.assertIn(token, normalized, (wave, token))

    def test_selected_predecessor_learning_blob_is_verified_through_bound_git(
        self,
    ) -> None:
        learning_path = (
            "docs/superpowers/specs/"
            "2026-07-23-qinao-governed-learning-plane-data-flywheel-thinking-design.md"
        )
        expected_commit = "7e4aa2d626e2c94b1b1f3405fb8454e73448514f"
        expected_blob = "75a34022593ea2d85405021e75272d7c7f0c2af1"
        expected_size = "185314"
        expected_sha256 = (
            "e14375de67f7baf9bfe9c4e466b1182fbe906f849da0e260a37bd8bbd6554079"
        )
        task_zero = section(
            self.master,
            "## Task 0: Select and Pin the Only Convergence Predecessor",
            "## Task 1: Make W0 Gates Non-Vacuous and Continuous",
        )
        for token in (
            'LEARNING_DESIGN_BLOB=$("$QINAO_GIT_EXECUTABLE" rev-parse "${QINAO_SELECTED_COMMIT}:'
            + learning_path
            + '")',
            'test "$LEARNING_DESIGN_BLOB" = ' + expected_blob,
            'cat-file -s "$LEARNING_DESIGN_BLOB")" = ' + expected_size,
            'cat-file blob "$LEARNING_DESIGN_BLOB" | shasum -a 256',
            expected_sha256,
            "before requesting the root signature, stable-opens the governed-learning path from verifiedHEAD through the bound Git executable",
        ):
            self.assertIn(token, task_zero)

        resolved_blob = subprocess.run(
            ["git", "rev-parse", f"{expected_commit}:{learning_path}"],
            cwd=ROOT,
            check=True,
            capture_output=True,
            text=True,
        ).stdout.strip()
        self.assertEqual(resolved_blob, expected_blob)
        resolved_size = subprocess.run(
            ["git", "cat-file", "-s", resolved_blob],
            cwd=ROOT,
            check=True,
            capture_output=True,
            text=True,
        ).stdout.strip()
        self.assertEqual(resolved_size, expected_size)
        resolved_bytes = subprocess.run(
            ["git", "cat-file", "blob", resolved_blob],
            cwd=ROOT,
            check=True,
            capture_output=True,
        ).stdout
        self.assertEqual(hashlib.sha256(resolved_bytes).hexdigest(), expected_sha256)

        task_two = section(
            self.master,
            "## Task 2: Atomically Reconcile the Seven Controlled Documents and Owner Ledger",
            "## Controlled Domain-Plan Payload W1:",
        )
        learning_slice = section(
            task_two,
            "Treat as immutable, byte-pinned decision input:",
            "Treat as immutable, byte-pinned supplemental decision input:",
        )
        self.assertIn("root-admitted selected predecessor", learning_slice)
        self.assertNotIn("admitted design edge", learning_slice)

    def test_run_reducer_cancel_and_reconcile_require_typed_boundary_proof(
        self,
    ) -> None:
        reducer = section(
            self.master,
            "public enum BASAutomationRunReducer {",
            "// The remaining W1 shapes below receive the same explicit stored-field",
        )
        normalized = re.sub(r"\s+", " ", reducer)
        transition_wire = self.master[
            self.master.index(
                "public struct BASAutomationBoundaryDispositionEvidence:"
            ) : self.master.index("public struct BASAutomationRunEvent:")
        ]
        proof_wire = transition_wire[
            transition_wire.index(
                "public enum BASAutomationBoundaryDispositionProof:"
            ) : transition_wire.index("public struct BASAutomationRunTransition:")
        ]
        normalized_transition_wire = re.sub(r"\s+", " ", transition_wire)
        reduction_wire = self.master[
            self.master.index(
                "public struct BASAutomationRunReduction:"
            ) : self.master.index("public enum BASAutomationRunReducer {")
        ]
        for token in (
            "case notRequired",
            "case provedPreBoundary",
            "case possibleOrUnknown",
            "case reconciledNoEffect",
            "case terminalResolution",
            "fileprivate init(",
            "private enum Tag: String, Codable",
            "private enum CodingKeys: String, CodingKey, CaseIterable",
            "public init(from decoder: Decoder) throws",
            "BASContractWireValidation.exactKeys",
            "public func encode(to encoder: Encoder) throws",
            "public let boundaryDispositionProof: BASAutomationBoundaryDispositionProof",
            "boundarySlotCoverageDigest",
            "proofRevision",
            "predecessorDispositionProofDigest",
            "orderedBoundaryEvidenceArtifactIDs",
        ):
            self.assertIn(token, normalized_transition_wire)
        self.assertEqual(proof_wire.count("allowEmpty: false"), 4)
        self.assertNotIn("allowEmpty: true", proof_wire)
        self.assertIn(
            "nextBoundaryDispositionProof:\n"
            "        BASAutomationBoundaryDispositionProof",
            reduction_wire,
        )
        evidence_fields = dict(
            re.findall(
                r"public let ([A-Za-z_][A-Za-z0-9_]*): ([^\n]+)",
                transition_wire[
                    : transition_wire.index(
                        "public enum BASAutomationBoundaryDispositionProof:"
                    )
                ],
            )
        )
        self.assertEqual(
            evidence_fields,
            {
                "boundarySlotCoverageDigest": "String",
                "proofRevision": "UInt64",
                "predecessorDispositionProofDigest": "String?",
                "orderedBoundaryEvidenceArtifactIDs": "[BASArtifactID]",
            },
        )
        for token in (
            "currentBoundaryDispositionProof: BASAutomationBoundaryDispositionProof",
            "expectedBoundarySlotCoverageDigest: String",
            "isBoundToExpectedCoverage( currentBoundaryDispositionProof, expectedBoundarySlotCoverageDigest: expectedBoundarySlotCoverageDigest)",
            "isBoundToExpectedCoverage( transition.boundaryDispositionProof, expectedBoundarySlotCoverageDigest: expectedBoundarySlotCoverageDigest)",
            "nextBoundaryDispositionProof: nextPersistedProof(for: transition)",
            "isValidPersistedProof( for: current, proof: currentBoundaryDispositionProof)",
            "isCancellableNonterminal(from)",
            "hasProvedPreBoundary( transition.boundaryDispositionProof)",
            "isReconciliationEligibleNonterminal(from)",
            "hasPossibleOrUnknownBoundary( transition.boundaryDispositionProof)",
            "if from == .observed { return false }",
            "if from == .admitted || from == .allocated { return hasProvedPreBoundary(proof) && isGenesisProof(proof) }",
            "private static func isGenesisProof(",
            "private static func isBoundToExpectedCoverage(",
            "return evidence.boundarySlotCoverageDigest == expectedBoundarySlotCoverageDigest",
            "private static func canonicalDispositionProofDigest(",
            "BASCanonicalPayloadValidator .canonicalBytes(for: proof)",
            "private static func isDirectProofSuccessor(",
            "nextEvidence.predecessorDispositionProofDigest == predecessorDigest",
            "nextEvidence.orderedBoundaryEvidenceArtifactIDs.count > currentEvidence.orderedBoundaryEvidenceArtifactIDs.count",
            "Array(nextEvidence.orderedBoundaryEvidenceArtifactIDs.prefix( currentEvidence.orderedBoundaryEvidenceArtifactIDs.count)) == currentEvidence.orderedBoundaryEvidenceArtifactIDs",
            "currentEvidence.proofRevision.addingReportingOverflow(1)",
            "isExactOrDirectProofSuccessor(",
            "hasReconciledNoEffect(boundaryDispositionProof) && isDirectProofSuccessor(",
            "hasTerminalResolution(boundaryDispositionProof) && isDirectProofSuccessor(",
            "if isDirectTerminalEdge(from: from, to: to)",
            "return false",
            "case .admitted, .allocated, .executing",
            ".checkpointed, .degraded:",
            "case .executing, .cancelRequested, .degraded:",
        ):
            self.assertIn(token, normalized)
        self.assertIn(
            "if to == .degraded { return isValidDegradationProof( from: from, currentBoundaryDispositionProof: currentBoundaryDispositionProof, proof: transition.boundaryDispositionProof) && reason == .boundedDegradation }",
            normalized,
        )
        self.assertIn(
            "boundaryDispositionProof == .notRequired",
            normalized,
        )
        self.assertNotIn("isCancellationSource", reducer)
        self.assertNotIn("isReconciliationSource", reducer)
        self.assertNotIn("if isTerminal(to)", reducer)
        self.assertNotIn(".allSatisfy(", reducer)
        for declaration in (
            "BASAutomationBoundaryDispositionEvidence",
            "BASAutomationBoundaryDispositionProof",
            "BASAutomationRunTransition",
            "BASAutomationRunReduction",
        ):
            kind = "enum" if declaration.endswith("Proof") else "struct"
            self.assertEqual(
                len(re.findall(rf"public {kind} {declaration}\s*:", self.master)),
                1,
                declaration,
            )
            self.assertEqual(
                swift_reserved_declaration_count(self.master, declaration),
                1,
                declaration,
            )

        k3_wire = self.master[
            self.master.index(
                "// Exact declaration path switches to\n"
                "// BASSemanticStateLakeContracts.swift under state.snapshot-contracts."
            ) : self.master.index(
                "// Exact declaration path resumes at BASSemanticTurnDAG.swift."
            )
        ]
        self.assertIn("they are not W2 placeholders", re.sub(r"\s+", " ", self.master))
        self.assertIn(
            "The request cannot carry a caller-\ncomputed next state, next proof or event payload",
            self.master,
        )

        def k3_public_fields(struct_name: str) -> dict[str, str]:
            start = k3_wire.index(f"public struct {struct_name}:")
            end = k3_wire.index("\n}\n", start) + 2
            normalized_struct = re.sub(r"\s+", " ", k3_wire[start:end])
            return dict(
                re.findall(
                    r"public let ([A-Za-z_][A-Za-z0-9_]*): "
                    r"([A-Za-z_][A-Za-z0-9_<>,\[\]? :]*?)"
                    r"(?= public let| public init| }$)",
                    normalized_struct,
                )
            )

        expected_k3_fields = {
            "BASAutomationK3TransitionRequest": {
                "schemaVersion": "String",
                "workspaceRef": "ContextWorkspaceRef",
                "transition": "BASAutomationRunTransition",
                "expectedState": "BASAutomationRunState",
                "expectedBoundaryDispositionProof": (
                    "BASAutomationBoundaryDispositionProof"
                ),
            },
            "BASAutomationK3TransitionReceipt": {
                "schemaVersion": "String",
                "requestDigest": "String",
                "workspaceRef": "ContextWorkspaceRef",
                "runID": "String",
                "transitionID": "String",
                "attemptRefArtifactID": "BASArtifactID",
                "previousState": "BASAutomationRunState",
                "previousBoundaryDispositionProof": (
                    "BASAutomationBoundaryDispositionProof"
                ),
                "nextState": "BASAutomationRunState",
                "nextBoundaryDispositionProof": (
                    "BASAutomationBoundaryDispositionProof"
                ),
                "canonicalEventPayloadDigest": "String",
                "committedEventArtifactID": "BASArtifactID",
                "committedHead": "BASEventLogHead",
                "committedRowVersion": "UInt64",
                "currentness": "BASAutomationCurrentnessEpochs",
                "postStateRoot": "String",
            },
            "BASAutomationK3SnapshotRequest": {
                "schemaVersion": "String",
                "workspaceRef": "ContextWorkspaceRef",
                "runID": "String",
                "attemptRefArtifactID": "BASArtifactID",
                "expectedCurrentness": "BASAutomationCurrentnessEpochs",
            },
            "BASAutomationK3Snapshot": {
                "schemaVersion": "String",
                "requestDigest": "String",
                "workspaceRef": "ContextWorkspaceRef",
                "runID": "String",
                "attemptRefArtifactID": "BASArtifactID",
                "currentState": "BASAutomationRunState",
                "currentBoundaryDispositionProof": (
                    "BASAutomationBoundaryDispositionProof"
                ),
                "latestEventArtifactID": "BASArtifactID",
                "currentHead": "BASEventLogHead",
                "currentRowVersion": "UInt64",
                "currentness": "BASAutomationCurrentnessEpochs",
                "stateRoot": "String",
            },
        }
        for struct_name, expected_fields in expected_k3_fields.items():
            fields = k3_public_fields(struct_name)
            self.assertEqual(fields, expected_fields, struct_name)
            struct_start = k3_wire.index(f"public struct {struct_name}:")
            struct_end = k3_wire.index("\n}\n", struct_start) + 2
            struct_wire = k3_wire[struct_start:struct_end]
            self.assertRegex(
                struct_wire,
                r"public init\(\s*\n\s*schemaVersion: String = "
                r"Self\.currentSchemaVersion,",
                struct_name,
            )
            self.assertEqual(
                struct_wire.count(
                    "private enum CodingKeys: String, CodingKey, CaseIterable"
                ),
                1,
                struct_name,
            )
            self.assertEqual(
                struct_wire.count("public init(from decoder: Decoder) throws"),
                1,
                struct_name,
            )
            self.assertEqual(
                struct_wire.count("BASContractWireValidation.exactKeys("),
                1,
                struct_name,
            )
            self.assertEqual(
                len(re.findall(rf"public struct {struct_name}\s*:", self.master)),
                1,
                struct_name,
            )
            self.assertEqual(
                swift_reserved_declaration_count(self.master, struct_name),
                1,
                struct_name,
            )
        for token in (
            "expectedState == transition.fromState",
            "automationK3TransitionExpectedState",
            "previousState != nextState, committedRowVersion > 0",
            "automationK3TransitionReceipt",
            "currentRowVersion > 0",
            'invalidRange("currentRowVersion")',
        ):
            self.assertIn(token, re.sub(r"\s+", " ", k3_wire))
        self.assertEqual(
            hashlib.sha256(
                re.sub(r"\s+", " ", k3_wire).strip().encode("utf-8")
            ).hexdigest(),
            "a62ac41ddfeda2bce6e0479083481143a65198277a261b51091b95d51b2474ab",
        )
        self.assertEqual(
            hashlib.sha256(
                normalized_transition_wire.strip().encode("utf-8")
            ).hexdigest(),
            "b5fbcf89fbd7dc32abee00a1f859fea31174493d8b1edabf95f72b1a9ae607c1",
        )
        self.assertEqual(
            hashlib.sha256(normalized.strip().encode("utf-8")).hexdigest(),
            "9c799069499b081e9f51dfa8e86ce1a43d05f38f307ea328583e98151b58e6da",
        )

    def test_w2_approved_history_k3_methods_are_formal_and_prose_exact(self) -> None:
        w2 = section(
            self.master,
            "## Controlled Domain-Plan Payload W2:",
            "## Controlled Domain-Plan Payload W3:",
        )
        normalized = re.sub(r"\s+", " ", w2)
        signatures = (
            "func advanceMissionTaskGraphRoot( _ request: BASMissionTaskGraphRootAdvanceRequest ) async throws -> BASMissionTaskGraphRootAdvanceReceipt",
            "func claimBudgetUse( _ request: BASBudgetUseRequest ) async throws -> BASBudgetUseClaimOutcome",
            "func advanceProjectorCursor( _ request: BASProjectorCursorAdvanceRequest ) async throws -> BASProjectorCursorAdvanceReceipt",
            "func advanceLearningCandidateHead( _ request: BASLearningCandidateHeadAdvanceRequest ) async throws -> BASLearningCandidateHeadAdvanceReceipt",
        )
        for signature in signatures:
            self.assertIn(signature, normalized)
        for value in (
            "BASMissionTaskGraphRootAdvanceRequest",
            "BASMissionTaskGraphRootAdvanceReceipt",
            "BASLearningCandidateHeadAdvanceRequest",
            "BASLearningCandidateHeadAdvanceReceipt",
        ):
            self.assertIn(value, normalized)
        self.assertIn(
            "public protocol BASK3ControlNucleusStorage: AnyObject, BASEventLogStorage, BASBudgetLeaseControlPort, BASProviderBranchControlPort {",
            normalized,
        )
        self.assertNotIn("advanceProjectorCursorRoot", w2)
        self.assertNotIn("claimDisputeEpisodeBudgetUse", w2)
        self.assertNotIn("BASDisputeEpisodeBudgetUseClaim", w2)
        self.assertIn("BASStateCommitContracts.swift", w2)
        self.assertIn(
            "Create through the already-approved non-empty `state.k3-control-nucleus` E candidate",
            normalized,
        )
        self.assertIn("BASSemanticStateLakeContracts.swift", w2)
        missing_in_selected = subprocess.run(
            [
                "git",
                "cat-file",
                "-e",
                "7e4aa2d626e2c94b1b1f3405fb8454e73448514f:"
                "BehavioralAISubstrate/Sources/BASRuntimeCore/"
                "BASStateCommitContracts.swift",
            ],
            cwd=ROOT,
            capture_output=True,
        )
        self.assertNotEqual(missing_in_selected.returncode, 0)

    def test_no_model_sentinels_have_same_command_suite_test_bijection_and_files(
        self,
    ) -> None:
        expected = NO_LANGUAGE_SURVIVAL_SENTINELS
        self.assertEqual(len(expected), 26)
        self.assertEqual(len(set(expected)), 26)
        commands = [
            command
            for block in fenced_shell_blocks(self.master)
            for command in logical_shell_commands(block)
            if "scripts/run_nonempty_swift_filter.py" in command
        ]
        for full_id in expected:
            suite = full_id.split("/", 1)[0].rsplit(".", 1)[-1]
            matching = [
                command
                for command in commands
                if f"--require-test {full_id}" in command
                and re.search(
                    rf"--require-suite\s+(?:BehavioralAISubstrateTests\.)?{re.escape(suite)}(?:\s|$)",
                    command,
                )
            ]
            self.assertEqual(len(matching), 1, full_id)
        w1 = section(
            self.master,
            "## Controlled Domain-Plan Payload W1:",
            "## Controlled Domain-Plan Payload W2:",
        )
        for path in (
            "BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASProposalEngineContractTests.swift",
            "BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASStructuredContextPacketTests.swift",
            "BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASDelegationSlotContractTests.swift",
        ):
            self.assertIn(path, w1)

    def test_rebase_and_context_accounting_have_one_formal_owner_and_wire(self) -> None:
        closure = section(
            self.master,
            "#### D. Provider-neutral context, grounding, API, and Core AI closure",
            "#### E. Governed learning and data-flywheel closure",
        )
        w6 = section(
            self.master,
            "## Controlled Domain-Plan Payload W6 Runtime:",
            "## Controlled Domain-Plan Payload W6 Apple Lab:",
        )
        normalized_w6 = re.sub(r"\s+", " ", w6)
        for token in (
            "owner `runtime.semantic-executor`",
            "BehavioralAISubstrate/Sources/BASHostKit/BASTurnRuntimeEngine.swift",
            "extension BASTurnRuntimeEngine",
            "func performAtomicContextRebase( _ request: BASContextRebaseRequest ) async throws -> BASAtomicContextRebaseResult",
            "usable",
            "activationPending",
            "terminalDenied",
            "crash-recoverable saga",
        ):
            self.assertIn(token, normalized_w6)
        normalized_closure = re.sub(r"\s+", " ", closure)
        owner_declaration = section(
            closure,
            "The accounting values have exactly one declaration each and follow the",
            "This is a controlled replacement of the still-unimplemented future sketch",
        )
        normalized_owner_declaration = re.sub(r"\s+", " ", owner_declaration)
        for token in (
            "existing owner `provider.package-boundary`",
            "BehavioralAISubstrate/Sources/BASRuntimeCore/ProviderExecutionCore.swift",
            "existing owner `state.context-compiler`",
            "BehavioralAISubstrate/Sources/BASOrchestration/ContextCompilerCore.swift",
            "RuntimeCore never imports BASOrchestration",
            "compiler depends inward on these base values",
        ):
            self.assertIn(token, normalized_owner_declaration)
        runtime_types = (
            "BASContextAccountingSection",
            "BASContextCapacityTopology",
            "BASContextSafetyMarginProjection",
            "BASContextReasoningMode",
            "BASContextAttachmentModality",
            "BASContextAttachmentGeometry",
            "BASContextAttachmentAccountingInput",
            "BASContextHardLimitKind",
            "BASContextHardLimitUnit",
            "BASContextHardLimitRelation",
            "BASContextCertifiedHardLimit",
            "BASContextCertifiedLimitVector",
            "BASOpaqueContextAccountingShape",
            "BASContextAccountingRequest",
            "BASContextAccountingFailureReason",
            "BASContextAccountingCountProjection",
            "BASContextAccountingOutcome",
            "BASContextAccountingReceipt",
        )
        compiler_types = (
            "BASContextBudgetAccountingEvidence",
            "BASContextByteSectionSpan",
            "BASContextSectionFingerprint",
            "BASContextConservationProof",
            "BASContextCheckedLimitValue",
            "BASContextHardPredicateVerdict",
            "BASContextOmissionReason",
            "BASContextOmissionEntry",
            "BASContextRemainingCapacity",
            "BASContextBudgetReceipt",
        )
        runtime_owner_types = owner_declaration[
            owner_declaration.index(
                "declares the Provider-visible base protocol values:"
            ) : owner_declaration.index("Under existing owner `state.context-compiler`")
        ]
        compiler_owner_types = owner_declaration[
            owner_declaration.index(
                "declares the compiler-local proof/output values:"
            ) : owner_declaration.index("RuntimeCore\nnever imports BASOrchestration")
        ]
        self.assertEqual(
            tuple(re.findall(r"`(BAS[A-Za-z0-9_]+)`", runtime_owner_types)),
            runtime_types,
        )
        self.assertEqual(
            tuple(re.findall(r"`(BAS[A-Za-z0-9_]+)`", compiler_owner_types)),
            compiler_types,
        )
        for token in (
            "controlled replacement of the still-unimplemented future sketch",
            "four-field `BASContextBudgetReceipt 1.0.0` sketch",
            "selected HEAD has zero production declarations",
            "typed migration-required blocker",
            "may contain exactly one shape",
            "allocation fields and `allocation(for:)` projection remain",
            "removes the stale `.backward_v1` demand",
        ):
            self.assertIn(token, normalized_closure)
        for token in (
            "state.context-compiler",
            "BASOrchestration/ContextCompilerCore.swift",
            "provider.package-boundary",
            "BASRuntimeCore/ProviderExecutionCore.swift",
            "BASOpaqueContextAccountingShape = providerWholeRequest(requestLayoutDigest) | afmFreshSession(countOverloadVectorDigest)",
            "BASContextSafetyMarginProjection = sharedTotal(sharedCount) | splitInputOutput(inputCount,outputCount) | encoderOnly(encoderCount)",
            "BASContextAccountingRequest = {schemaVersion,turnOperationRef,workspaceRef,workUnitRefArtifactID,attemptRefArtifactID,providerProfileArtifactID,providerCohortID,certifiedContextGeometryArtifactID,accountingContractDigest,opaqueAccountingShape,topology,safetyMargins,instructionBytes,transcriptBytes,promptBytes,toolContractBytes,schemaBytes,outputContractBytes,orderedAttachments,orderedSectionDigests,certifiedUpperBounds,certifiedUpperBoundsDigest,reasoningMode,visibleOutputReserve,privateReasoningReserve,protocolReserve,currentCapabilityEpoch}",
            "BASContextAccountingCountProjection = sharedTotal(exactWholeRequestCount) | splitInputOutput(exactInputCount,requiredOutputReserveCount) | encoderOnly(exactEncoderCount)",
            "BASContextAccountingOutcome = success(countProjection) | failure(reason)",
            "BASContextAccountingReceipt = {schemaVersion,requestDigest,providerProfileArtifactID,providerCohortID,certifiedContextGeometryArtifactID,accountingContractDigest,topology,reasoningMode,currentCapabilityEpoch,outcome}",
            "BASContextBudgetAccountingEvidence = deterministicTokenSpans(tokenizerArtifactID,tokenSpanProofDigest) | opaqueReceipt(accountingRequestArtifactID,accountingReceiptArtifactID) | certifiedConservativeUpperBound(certifiedBoundArtifactID,boundProofDigest)",
            "BASContextCheckedLimitValue = exactObserved(value) | certifiedUpperBound(value,boundProofDigest)",
            "BASContextBudgetReceipt = {schemaVersion,totalLimit,orderedAllocations,orderedCompressionArtifactIDs,contextCandidateDigest,providerProfileArtifactID,certifiedContextGeometryArtifactID,certifiedUpperBoundsDigest,topology,accountingEvidence,orderedByteSectionSpans,orderedSectionFingerprints,conservationProof,visibleOutputReserve,privateReasoningReserve,protocolReserve,hardPredicateVerdicts,omissionLedger,finalContextDescriptorDigest,remainingCapacity,currentCapabilityEpoch}",
            "Provider-owned receipt exists only for `opaqueRuntimeExactCount`",
            "deterministic and conservative paths construct neither a `BASContextAccountingRequest` nor a `BASContextAccountingReceipt`",
            "AFM fresh-session shape requires empty `transcriptBytes`",
            "failure forbids every count",
            "seven accounting sections are canonical",
            "modality/geometry mismatch",
            "No unused capacity in one dimension compensates for another",
            "Tool count and schema complexity/bytes, modality count",
            "`providerSpecificField` is legal only when `providerFieldID`",
            "The kind/relation matrix is closed",
            "The retained legacy projection is diagnostic, never authorization",
            "It is a checked, derived diagnostic projection and never a second cap or an input to authorization",
            "shared remaining equals `wholeRequestCapacity - (exactWholeRequestCount + visibleOutputReserve + privateReasoningReserve + protocolReserve + sharedSafetyMargin)`",
            "split input remaining equals `inputCapacity - (exactInputCount + inputSafetyMargin)`",
            "split output remaining equals `outputCapacity - requiredOutputReserveCount`",
            "encoder remaining equals `encoderCapacity - (exactEncoderCount + encoderSafetyMargin)`",
            'No receipt field may report or authorize Provider-claimed "available" capacity',
            "Request topology, receipt topology and success-projection tag must be equal",
            "Terminal output truth remains solely in the Provider usage-observation/reconciliation receipt",
            "For `encoderOnly`, `visibleOutputReserve`, `privateReasoningReserve`, and `protocolReserve` are all exactly zero",
            "The tag of the checked value must agree with `accountingEvidence`",
            "retention-classed `recovery72Hours`",
            "excluded from EventLog, analytics, learning, `auditProof`",
        ):
            self.assertIn(token, normalized_closure)
        self.assertNotIn("BASContextAccountingMeasurement", closure)
        self.assertNotIn("success(measurement)", closure)
        self.assertNotIn("countOverloadVectorDigest,instructionBytes", closure)
        for forbidden_available_field in (
            "availableSharedTotalCount",
            "availableInputCount",
            "availableOutputCount",
            "availableEncoderCount",
        ):
            self.assertNotIn(forbidden_available_field, closure)
        accounting_wires = closure[
            closure.index("public enum BASContextAccountingSection:") : closure.index(
                "The raw enums use exactly"
            )
        ]
        for enum_name in (
            "BASContextAccountingSection",
            "BASContextCapacityTopology",
            "BASContextSafetyMarginProjection",
            "BASContextReasoningMode",
            "BASContextAttachmentModality",
            "BASContextAttachmentGeometry",
            "BASContextHardLimitKind",
            "BASContextHardLimitUnit",
            "BASContextHardLimitRelation",
            "BASOpaqueContextAccountingShape",
            "BASContextAccountingFailureReason",
            "BASContextAccountingCountProjection",
            "BASContextAccountingOutcome",
            "BASContextBudgetAccountingEvidence",
            "BASContextCheckedLimitValue",
            "BASContextOmissionReason",
        ):
            self.assertEqual(
                len(re.findall(rf"public enum {enum_name}\s*:", self.master)),
                1,
                enum_name,
            )
        for struct_name in (
            "BASContextCertifiedHardLimit",
            "BASContextCertifiedLimitVector",
            "BASContextAttachmentAccountingInput",
            "BASContextByteSectionSpan",
            "BASContextSectionFingerprint",
            "BASContextConservationProof",
            "BASContextHardPredicateVerdict",
            "BASContextOmissionEntry",
            "BASContextRemainingCapacity",
            "BASContextAccountingRequest",
            "BASContextAccountingReceipt",
            "BASContextBudgetReceipt",
        ):
            self.assertEqual(
                len(re.findall(rf"public struct {struct_name}\s*:", self.master)),
                1,
                struct_name,
            )
        for reserved_symbol in runtime_types + compiler_types:
            self.assertEqual(
                swift_reserved_declaration_count(self.master, reserved_symbol),
                1,
                reserved_symbol,
            )

        def accounting_public_fields(struct_name: str) -> dict[str, str]:
            start = accounting_wires.index(f"public struct {struct_name}:")
            end = accounting_wires.index("\n}\n", start) + 2
            return dict(
                re.findall(
                    r"public let ([A-Za-z_][A-Za-z0-9_]*): ([^\n]+)",
                    accounting_wires[start:end],
                )
            )

        self.assertEqual(
            accounting_public_fields("BASContextCertifiedHardLimit"),
            {
                "limitID": "String",
                "kind": "BASContextHardLimitKind",
                "providerFieldID": "String?",
                "unit": "BASContextHardLimitUnit",
                "relation": "BASContextHardLimitRelation",
                "certifiedValue": "UInt64",
                "sourceContractDigest": "String",
            },
        )
        self.assertEqual(
            accounting_public_fields("BASContextCertifiedLimitVector"),
            {
                "orderedHardLimits": "[BASContextCertifiedHardLimit]",
            },
        )
        self.assertEqual(
            accounting_public_fields("BASContextConservationProof"),
            {
                "accountedInputCount": "UInt64",
                "accountedVisibleOutputReserve": "UInt64",
                "accountedPrivateReasoningReserve": "UInt64",
                "accountedProtocolReserve": "UInt64",
                "accountedSafetyMargins": "BASContextSafetyMarginProjection",
                "equationDigest": "String",
            },
        )
        self.assertEqual(
            accounting_public_fields("BASContextHardPredicateVerdict"),
            {
                "limitID": "String",
                "kind": "BASContextHardLimitKind",
                "providerFieldID": "String?",
                "unit": "BASContextHardLimitUnit",
                "relation": "BASContextHardLimitRelation",
                "checkedValue": "BASContextCheckedLimitValue",
                "certifiedValue": "UInt64",
                "passed": "Bool",
                "evidenceDigest": "String",
            },
        )
        self.assertEqual(
            accounting_public_fields("BASContextAccountingRequest"),
            {
                "schemaVersion": "String",
                "turnOperationRef": "BASTurnOperationRef",
                "workspaceRef": "ContextWorkspaceRef",
                "workUnitRefArtifactID": "BASArtifactID",
                "attemptRefArtifactID": "BASArtifactID",
                "providerProfileArtifactID": "BASArtifactID",
                "providerCohortID": "String",
                "certifiedContextGeometryArtifactID": "BASArtifactID",
                "accountingContractDigest": "String",
                "opaqueAccountingShape": "BASOpaqueContextAccountingShape",
                "topology": "BASContextCapacityTopology",
                "safetyMargins": "BASContextSafetyMarginProjection",
                "instructionBytes": "Data",
                "transcriptBytes": "Data",
                "promptBytes": "Data",
                "toolContractBytes": "Data",
                "schemaBytes": "Data",
                "outputContractBytes": "Data",
                "orderedAttachments": "[BASContextAttachmentAccountingInput]",
                "orderedSectionDigests": "[String]",
                "certifiedUpperBounds": "BASContextCertifiedLimitVector",
                "certifiedUpperBoundsDigest": "String",
                "reasoningMode": "BASContextReasoningMode",
                "visibleOutputReserve": "UInt64",
                "privateReasoningReserve": "UInt64",
                "protocolReserve": "UInt64",
                "currentCapabilityEpoch": "UInt64",
            },
        )
        self.assertEqual(
            accounting_public_fields("BASContextAccountingReceipt"),
            {
                "schemaVersion": "String",
                "requestDigest": "String",
                "providerProfileArtifactID": "BASArtifactID",
                "providerCohortID": "String",
                "certifiedContextGeometryArtifactID": "BASArtifactID",
                "accountingContractDigest": "String",
                "topology": "BASContextCapacityTopology",
                "reasoningMode": "BASContextReasoningMode",
                "currentCapabilityEpoch": "UInt64",
                "outcome": "BASContextAccountingOutcome",
            },
        )
        self.assertEqual(
            accounting_public_fields("BASContextBudgetReceipt"),
            {
                "schemaVersion": "String",
                "totalLimit": "Int",
                "orderedAllocations": "[BASContextBudgetAllocationEntry]",
                "orderedCompressionArtifactIDs": "[BASArtifactID]",
                "contextCandidateDigest": "String",
                "providerProfileArtifactID": "BASArtifactID",
                "certifiedContextGeometryArtifactID": "BASArtifactID",
                "certifiedUpperBoundsDigest": "String",
                "topology": "BASContextCapacityTopology",
                "accountingEvidence": "BASContextBudgetAccountingEvidence",
                "orderedByteSectionSpans": "[BASContextByteSectionSpan]",
                "orderedSectionFingerprints": "[BASContextSectionFingerprint]",
                "conservationProof": "BASContextConservationProof",
                "visibleOutputReserve": "UInt64",
                "privateReasoningReserve": "UInt64",
                "protocolReserve": "UInt64",
                "hardPredicateVerdicts": "[BASContextHardPredicateVerdict]",
                "omissionLedger": "[BASContextOmissionEntry]",
                "finalContextDescriptorDigest": "String",
                "remainingCapacity": "BASContextRemainingCapacity",
                "currentCapabilityEpoch": "UInt64",
            },
        )
        self.assertEqual(
            hashlib.sha256(
                re.sub(r"\s+", " ", accounting_wires).strip().encode("utf-8")
            ).hexdigest(),
            "de4ed025bc87ea27e0103a7c62f26a9c22970921cd363dfc8658097ef5ecacb6",
        )
        for shape_name in (
            "BASOpaqueContextAccountingShape",
            "BASContextSafetyMarginProjection",
            "BASContextAccountingRequest",
            "BASContextAccountingCountProjection",
            "BASContextAccountingOutcome",
            "BASContextAccountingReceipt",
            "BASContextBudgetAccountingEvidence",
            "BASContextCheckedLimitValue",
            "BASContextBudgetReceipt",
        ):
            self.assertEqual(
                len(
                    re.findall(
                        rf"^{shape_name} = ",
                        closure,
                        flags=re.MULTILINE,
                    )
                ),
                1,
                shape_name,
            )
        w1 = section(
            self.master,
            "## Controlled Domain-Plan Payload W1:",
            "## Controlled Domain-Plan Payload W2:",
        )
        for path in (
            "BehavioralAISubstrate/Sources/BASOrchestration/ContextCompilerCore.swift",
            "BehavioralAISubstrate/Sources/BASRuntimeCore/ProviderExecutionCore.swift",
            "BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASContextAccountingContractTests.swift",
        ):
            self.assertIn(path, w1)

    def test_atomic_rebase_has_formal_w1_w2_w5_prerequisites_before_w6(self) -> None:
        w1 = section(
            self.master,
            "## Controlled Domain-Plan Payload W1:",
            "## Controlled Domain-Plan Payload W2:",
        )
        w2 = section(
            self.master,
            "## Controlled Domain-Plan Payload W2:",
            "## Controlled Domain-Plan Payload W3:",
        )
        w5 = section(
            self.master,
            "## Controlled Domain-Plan Payload W5:",
            "## Controlled Domain-Plan Payload W6 Runtime:",
        )
        w6 = section(
            self.master,
            "## Controlled Domain-Plan Payload W6 Runtime:",
            "## Controlled Domain-Plan Payload W6 Apple Lab:",
        )
        normalized = {
            wave: re.sub(r"\s+", " ", contents)
            for wave, contents in (("W1", w1), ("W2", w2), ("W5", w5), ("W6", w6))
        }

        for token in (
            "existing `state.snapshot-contracts` owner",
            "BehavioralAISubstrate/Sources/BASRuntimeCore/BASSemanticStateLakeContracts.swift",
            "public enum BASBudgetUseClaimBasis: Codable, Sendable, Equatable",
            "case proveZeroUse",
            "public struct BASRebaseRightsSubset: Codable, Sendable, Equatable",
            "public struct BASContextRebaseRequest: Codable, Sendable, Equatable",
            "public let workspaceRef: ContextWorkspaceRef",
            "expectedOldActiveHeadArtifactID",
            "contextContinuityManifestArtifactID",
            "public let sourceEventHighWatermark: Int64",
            "public let sourceEventHead: BASEventLogHead",
            "public let orderedBoundaryTerminalRefs: [BASRebaseBoundaryTerminalRef]",
            "public let boundarySlotCoverageDigest: String",
            "boundaryTerminalSetDigest",
            "public let requestedRights: BASRebaseRightsSubset",
            "public let audiences: [String]",
            "public let phase: BASCapabilityPhase",
            "public let scopeBinding: BASArtifactScopeBinding",
            "public let turnBranchRef: BASTurnBranchRef?",
            "public let canonicalDigest: String",
            "public let reducedCeilingVector: BASRebaseCeilingVector",
            "reducedCeilingVectorDigest",
            "monotonicDeadlineNanos",
            "public let keyEpoch: UInt64",
            "public let warrantEpoch: UInt64",
            "case providerRecoveryAction",
            "BASContextContinuityContractTests.swift",
        ):
            self.assertIn(token, normalized["W1"])

        def public_fields(struct_name: str) -> dict[str, str]:
            start = w1.index(f"public struct {struct_name}:")
            end = w1.index("\n}\n", start) + 2
            return dict(
                re.findall(
                    r"public let ([A-Za-z_][A-Za-z0-9_]*): ([^\n]+)",
                    w1[start:end],
                )
            )

        self.assertEqual(
            public_fields("BASContextRebaseRequest"),
            {
                "schemaVersion": "String",
                "rebaseRequestID": "String",
                "turnOperationRef": "BASTurnOperationRef",
                "workspaceRef": "ContextWorkspaceRef",
                "workUnitRefArtifactID": "BASArtifactID",
                "predecessorAttemptArtifactID": "BASArtifactID",
                "predecessorGeneration": "UInt64",
                "successorAttemptArtifactID": "BASArtifactID",
                "successorGeneration": "UInt64",
                "expectedOldActiveHeadArtifactID": "BASArtifactID",
                "contextContinuityManifestArtifactID": "BASArtifactID",
                "l10CoverageReceiptArtifactID": "BASArtifactID",
                "sourceSnapshotArtifactID": "BASArtifactID",
                "sourceEventHighWatermark": "Int64",
                "sourceEventHead": "BASEventLogHead",
                "orderedBoundaryTerminalRefs": "[BASRebaseBoundaryTerminalRef]",
                "boundarySlotCoverageDigest": "String",
                "boundaryTerminalSetDigest": "String",
                "budgetUseClaimBasis": "BASBudgetUseClaimBasis",
                "visitedStateCommitmentArtifactID": "BASArtifactID",
                "authorizationBasisArtifactID": "BASArtifactID",
                "durableWarrantArtifactID": "BASArtifactID",
                "requestedRights": "BASRebaseRightsSubset",
                "reducedCeilingVector": "BASRebaseCeilingVector",
                "reducedCeilingVectorDigest": "String",
                "bootSessionID": "String",
                "monotonicDeadlineNanos": "UInt64",
                "keyEpoch": "UInt64",
                "warrantEpoch": "UInt64",
                "policyEpoch": "UInt64",
                "deletionEpoch": "UInt64",
                "revocationEpoch": "UInt64",
            },
        )
        self.assertEqual(
            public_fields("BASRebaseRightsSubset"),
            {
                "audiences": "[String]",
                "operation": "String",
                "resource": "String",
                "requestDigest": "String",
                "inputDigest": "String",
                "phase": "BASCapabilityPhase",
                "neuralExecutionContractDigest": "String?",
                "outputSchemaDigest": "String",
                "outputConstraintsDigest": "String",
                "projectionPolicyDigest": "String",
                "resultArtifactID": "BASArtifactID?",
                "effectRequestDigest": "String?",
                "purpose": "String",
                "scopeBinding": "BASArtifactScopeBinding",
                "turnOperationRef": "BASTurnOperationRef?",
                "turnBranchRef": "BASTurnBranchRef?",
                "workspaceReadSnapshotArtifactID": "BASArtifactID?",
                "generationVectorArtifactID": "BASArtifactID",
                "logicalEpoch": "UInt64",
                "canonicalDigest": "String",
            },
        )
        w1_rebase_wire = w1[
            w1.index("public enum BASBudgetUseClaimBasis:") : w1.index(
                "The request is self-ID-free."
            )
        ]
        self.assertEqual(
            hashlib.sha256(
                re.sub(r"\s+", " ", w1_rebase_wire).strip().encode("utf-8")
            ).hexdigest(),
            "01c026adf2334fd8daa53e8394d49a770dd83e89218825f1342f2e121fda9c52",
        )
        for kind, declaration in (
            ("enum", "BASBudgetUseClaimBasis"),
            ("enum", "BASBudgetUseEvidence"),
            ("enum", "BASRebaseBoundaryKind"),
            ("struct", "BASRebaseBoundaryTerminalRef"),
            ("struct", "BASRebaseRightsSubset"),
            ("struct", "BASRebaseCeilingVector"),
            ("struct", "BASContextRebaseRequest"),
        ):
            self.assertEqual(
                len(re.findall(rf"public {kind} {declaration}\s*:", self.master)),
                1,
                declaration,
            )
            self.assertEqual(
                swift_reserved_declaration_count(self.master, declaration),
                1,
                declaration,
            )

        rebase_budget_wire = w2[
            w2.index("public enum BASRebaseInheritedBudgetProof:") : w2.index(
                "BASK3AttemptRebasePendingReceipt ="
            )
        ]
        normalized_rebase_budget_wire = re.sub(r"\s+", " ", rebase_budget_wire)
        self.assertEqual(
            len(
                re.findall(
                    r"public enum BASRebaseInheritedBudgetProof\s*:",
                    rebase_budget_wire,
                )
            ),
            1,
        )
        self.assertEqual(
            swift_reserved_declaration_count(
                self.master, "BASRebaseInheritedBudgetProof"
            ),
            1,
        )
        for token in (
            "case zeroUse( predecessorLeaseRevision: UInt64, zeroUseSourceK3Root: String, zeroUseSourceWatermark: Int64, checkedRemainder: BASRebaseCeilingVector)",
            "case used( latestBudgetUseReceiptArtifactID: BASArtifactID, checkedRemainder: BASRebaseCeilingVector)",
            "explicit `zeroUse|used` discriminator",
            "per-tag exact `CodingKeys`",
            "no third budget-vector type is introduced",
            "checked subtraction from the reopened predecessor lease",
            "equality-reopens the referenced latest `BASBudgetUseReceipt`",
        ):
            self.assertIn(token, normalized_rebase_budget_wire)
        self.assertEqual(
            hashlib.sha256(
                normalized_rebase_budget_wire.strip().encode("utf-8")
            ).hexdigest(),
            "79343113b8b4cc92e83a5c87e38afe58391b98934096200927414dabbf5d1bfe",
        )
        self.assertNotIn("sourceEventHeadArtifactID", w1)

        w2_rebase_wire = w2[
            w2.index("public enum BASRebaseInheritedBudgetProof:") : w2.index(
                "There is no `BASK3AutomationStatePort`"
            )
        ]
        self.assertEqual(
            hashlib.sha256(
                re.sub(r"\s+", " ", w2_rebase_wire).strip().encode("utf-8")
            ).hexdigest(),
            "b89e216e6701675bf4eb667797120339da95dffa2347ffbc1341cdf47f3a00f7",
        )
        self.assertEqual(
            len(
                re.findall(
                    r"public enum BASRebaseInheritedBudgetProof\s*:",
                    self.master,
                )
            ),
            1,
        )

        for token in (
            "func beginAttemptRebase( _ request: BASContextRebaseRequest ) async throws -> BASK3AttemptRebasePendingReceipt",
            "func commitAttemptRebase( _ request: BASK3AttemptRebaseCommitRequest ) async throws -> BASAttemptRebaseReceipt",
            "func reopenAttemptRebase( _ request: BASK3AttemptRebaseReopenRequest ) async throws -> BASK3AttemptRebaseRecoverySnapshot",
            "BASAttemptRebaseRecoveryTests.swift",
            "same `BASK3ControlNucleusStorage`",
            "BASK3AttemptRebasePendingReceipt = {schemaVersion,rebaseRequestID,rebaseRequestDigest",
            "BASAttemptRebaseReceipt = {schemaVersion,rebaseRequestID,rebaseRequestDigest",
            "BASRebaseInheritedBudgetProof = zeroUse(predecessorLeaseRevision,zeroUseSourceK3Root,zeroUseSourceWatermark,checkedRemainder) | used(latestBudgetUseReceiptArtifactID,checkedRemainder)",
            "successorAuthorizationGrantArtifactID",
            "Every rebase field named `pendingSourceWatermark`",
            "is a nonnegative `Int64` in the incumbent EventLog sequence domain",
            "None is a `UInt64`, a wall/monotonic time, or a second watermark authority",
        ):
            self.assertIn(token, normalized["W2"])

        for token in (
            "existing `sovereign.k4-durable-lifecycle` owner",
            "BehavioralAISubstrate/Sources/BASSovereign/BASSovereignTokenAuthority.swift",
            "func reserveAttemptRebaseGrant( _ request: BASAttemptRebaseGrantReservationRequest ) async throws -> BASAttemptRebaseGrantReservationReceipt",
            "func activateAttemptRebaseGrant( _ request: BASAttemptRebaseGrantActivationRequest ) async throws -> BASAttemptRebaseGrantActivationOutcome",
            "func reopenAttemptRebaseGrantStatus( _ request: BASAttemptRebaseGrantStatusRequest ) async throws -> BASAttemptRebaseGrantActivationOutcome",
            "BASK4AuthorizationLedgerTests.swift",
            "BASAttemptRebaseGrantReservationRequest = {schemaVersion,rebaseRequestID,rebaseRequestDigest,pendingReceiptArtifactID,pendingRowRoot,pendingSourceWatermark,predecessorAttemptArtifactID,predecessorGeneration,successorAttemptArtifactID,successorGeneration,expectedOldActiveHeadArtifactID,authorizationBasisArtifactID,durableWarrantArtifactID,predecessorAuthorizationGrantArtifactID,requestedRights,reducedCeilingVector,reducedCeilingVectorDigest,bootSessionID,monotonicDeadlineNanos,keyEpoch,warrantEpoch,policyEpoch,deletionEpoch,revocationEpoch}",
            "BASAttemptRebaseGrantReservationReceipt = {schemaVersion,rebaseRequestID,rebaseRequestDigest,pendingReceiptArtifactID,pendingRowRoot,pendingSourceWatermark,predecessorAttemptArtifactID,predecessorGeneration,successorAttemptArtifactID,successorGeneration,expectedOldActiveHeadArtifactID,authorizationBasisArtifactID,durableWarrantArtifactID,predecessorAuthorizationGrantArtifactID,freshAuthorizationGrantArtifactID,requestedRights,reducedCeilingVector,reducedCeilingVectorDigest,bootSessionID,monotonicDeadlineNanos,k4CoveringRoot,k4CoveringWatermark,keyEpoch,warrantEpoch,policyEpoch,deletionEpoch,revocationEpoch,ledgerRequestDigest,ledgerResultDigest,signature}",
            "BASAttemptRebaseGrantActivationRequest = {schemaVersion,rebaseRequestID,rebaseRequestDigest",
            "BASAttemptRebaseGrantStatusRequest = {schemaVersion,rebaseRequestID,rebaseRequestDigest",
            "BASAttemptRebaseGrantActivationOutcome = usable(reservationReceiptArtifactID,activationReceiptArtifactID,grantStatusArtifactID) | activationPending(reservationReceiptArtifactID,statusEvidenceArtifactID) | terminalDenied(reservationReceiptArtifactID,denialFenceArtifactID)",
        ):
            self.assertIn(token, normalized["W5"])

        w5_rebase_wire = w5[
            w5.index("**Attempt-rebase K4 lifecycle:**") : w5.index(
                "**Inspection interface:**"
            )
        ]
        self.assertEqual(
            hashlib.sha256(
                re.sub(r"\s+", " ", w5_rebase_wire).strip().encode("utf-8")
            ).hexdigest(),
            "bde61bbd7075a7f81578b8fd29a154a1390f3455158dce04b9e9b421cdc8b0e2",
        )

        for token in (
            "case usable( reservationReceiptArtifactID: BASArtifactID, activationReceiptArtifactID: BASArtifactID, grantStatusArtifactID: BASArtifactID )",
            "case activationPending( reservationReceiptArtifactID: BASArtifactID, statusEvidenceArtifactID: BASArtifactID )",
            "case terminalDenied( reservationReceiptArtifactID: BASArtifactID, denialFenceArtifactID: BASArtifactID )",
            "K3 pending → K4 reservation → K3 CAS → K4 activation evidence matrix",
        ):
            self.assertIn(token, normalized["W6"])
        self.assertNotIn("workspaceRef: BASWorkspaceRef", w1)
        self.assertNotIn("orderedCanonicalRightIDs", w1)
        self.assertNotIn("zeroUseProofArtifactID", w2)
        self.assertNotIn("reservation → pending → K3 CAS", w6)

    def test_learning_incumbents_have_fixed_non_optional_dispositions(self) -> None:
        learning = section(
            self.master,
            "#### E. Governed learning and data-flywheel closure",
            "#### F. Exact closure sentinels and non-vacuous wave gates",
        )
        expected = {
            "BASDistillationBank": "fixtureOnly",
            "BASUpdateTicketLifecycleCoordinator": "adapt",
            "BASShadowTrialCoordinator": "adapt",
            "BASABProtocolSpec": "adapt",
            "BASCoreAIShadowComparison": "adapt",
            "QinaoLearningExporter": "adapt",
            "MLXLoRATrainer": "fixtureOnly",
            "BASAppleInterventionBanditAdvisor": "fixtureOnly",
        }
        rows = {}
        for line in learning.splitlines():
            if (
                not line.startswith("| `BAS")
                and not line.startswith("| `Qinao")
                and not line.startswith("| `MLX")
            ):
                continue
            cells = [cell.strip().strip("`") for cell in line.strip("|").split("|")]
            if len(cells) == 6 and cells[0] in expected:
                rows[cells[0]] = cells
        self.assertEqual(set(rows), set(expected))
        for symbol, disposition in expected.items():
            cells = rows[symbol]
            self.assertEqual(cells[1], disposition, symbol)
            for cell in cells[2:]:
                self.assertTrue(cell, (symbol, cells))
            self.assertIn("test", cells[5], symbol)
        self.assertNotIn("fixture/mechanism-only or retire", learning)
        self.assertNotIn("reuse | adapt | fixtureOnly | retire", learning)

    def test_plan_wording_is_grammatical_and_not_redundant(self) -> None:
        self.assertNotIn("is reject before load", self.master)
        self.assertIn("is rejected before load", self.master)
        self.assertNotIn(
            "Without a language model, deterministic persona formatting remains available\nwithout a language model",
            self.master,
        )

    def test_every_wave_admission_cli_receives_bound_git_exactly_once(self) -> None:
        commands = [
            command
            for block in fenced_shell_blocks(self.master)
            for command in logical_shell_commands(block)
            if "python3 scripts/run_qinao_wave_admission.py" in command
        ]
        self.assertEqual(len(commands), 42)
        for command in commands:
            self.assertEqual(command.count("--git-executable"), 1, command)
            self.assertIn('--git-executable "$QINAO_GIT_EXECUTABLE"', command)

    def test_grounding_wire_and_store_admission_are_exact(self) -> None:
        expected_branch_payloads = {
            "model": "BASArtifactID",
            "boundedInference": "BASArtifactID",
            "deterministic": "BASArtifactID",
            "humanOrTool": "BASArtifactID",
            "notRequired": "BASArtifactID",
        }
        expected_receipt_fields = {
            "turnOperationRef": "BASTurnOperationRef",
            "attemptRefArtifactID": "BASArtifactID",
            "structuredContextPacketDigest": "String",
            "capabilityProfile": "BASCapabilityExecutionProfile",
            "candidateKind": "BASProposalCandidateKind?",
            "mechanismProof": "BASProposalMechanismProof?",
            "branch": "BASGroundingProposalBranch",
        }
        expected_compatibility = {
            ("fullProvider", "model", "openGenerativeProvider", "model"),
            (
                "fullProvider",
                "classicML",
                "boundedNonLanguageLearned",
                "boundedInference",
            ),
            (
                "fullProvider",
                "classicML",
                "boundedLanguageLearned",
                "boundedInference",
            ),
            (
                "noGenerativeProvider",
                "classicML",
                "boundedNonLanguageLearned",
                "boundedInference",
            ),
            (
                "noGenerativeProvider",
                "classicML",
                "boundedLanguageLearned",
                "boundedInference",
            ),
            (
                "noLanguageInference",
                "classicML",
                "boundedNonLanguageLearned",
                "boundedInference",
            ),
            (
                "fullProvider",
                "search",
                "boundedNonLanguageWorldModelSearch",
                "boundedInference",
            ),
            (
                "noGenerativeProvider",
                "search",
                "boundedNonLanguageWorldModelSearch",
                "boundedInference",
            ),
            (
                "noLanguageInference",
                "search",
                "boundedNonLanguageWorldModelSearch",
                "boundedInference",
            ),
            ("_", "rule", "deterministic", "deterministic"),
            ("_", "search", "deterministic", "deterministic"),
            ("fullProvider", "human", "structuredHuman", "humanOrTool"),
            ("fullProvider", "human", "languageHuman", "humanOrTool"),
            ("fullProvider", "tool", "structuredTool", "humanOrTool"),
            ("fullProvider", "tool", "languageTool", "humanOrTool"),
            ("fullProvider", "tool", "deterministicTool", "humanOrTool"),
            (
                "noGenerativeProvider",
                "human",
                "structuredHuman",
                "humanOrTool",
            ),
            (
                "noGenerativeProvider",
                "human",
                "languageHuman",
                "humanOrTool",
            ),
            (
                "noGenerativeProvider",
                "tool",
                "structuredTool",
                "humanOrTool",
            ),
            (
                "noGenerativeProvider",
                "tool",
                "languageTool",
                "humanOrTool",
            ),
            (
                "noGenerativeProvider",
                "tool",
                "deterministicTool",
                "humanOrTool",
            ),
            (
                "noLanguageInference",
                "human",
                "structuredHuman",
                "humanOrTool",
            ),
            (
                "noLanguageInference",
                "tool",
                "structuredTool",
                "humanOrTool",
            ),
            (
                "noLanguageInference",
                "tool",
                "deterministicTool",
                "humanOrTool",
            ),
            (
                "noLearnedInference",
                "human",
                "structuredHuman",
                "humanOrTool",
            ),
            (
                "noLearnedInference",
                "tool",
                "structuredTool",
                "humanOrTool",
            ),
            (
                "noLearnedInference",
                "tool",
                "deterministicTool",
                "humanOrTool",
            ),
        }

        world = swift_declaration_block(
            self.master, "BASWorldModelSearchCausalProof"
        )
        for fact in (
            "mechanismEvidence.usesLanguageInference == false",
            "mechanismEvidence.usesLearnedInference == true",
            "mechanismEvidence.mayOpenGenerate == false",
            "guard Set(causalIDs).count == causalIDs.count else",
        ):
            self.assertIn(
                fact,
                world,
                "world-model/search evidence lost a fact or distinct-causal-ID guard",
            )

        branch = swift_declaration_block(self.master, "BASGroundingProposalBranch")
        self.assertEqual(
            swift_enum_case_payload_types(branch),
            expected_branch_payloads,
            "grounding must retain the exact five Artifact-backed branches",
        )
        branch_wire = section(
            self.master,
            "extension BASGroundingProposalBranch: Codable {",
            "\n}\n\npublic struct BASGroundingReceipt:",
        )
        self.assertEqual(
            branch_wire.count("BASContractWireValidation.exactKeySet"),
            1,
            "grounding branch decoder must enforce one exact key set",
        )
        self.assertEqual(
            branch_wire.count(
                "let evidence = try c.decode(BASArtifactID.self, forKey: .evidence)"
            ),
            1,
            "grounding branch evidence must decode as BASArtifactID",
        )

        receipt = swift_declaration_block(self.master, "BASGroundingReceipt")
        receipt_fields = dict(
            re.findall(
                r"(?m)^\s*public let ([A-Za-z_][A-Za-z0-9_]*):\s*"
                r"([A-Za-z_][A-Za-z0-9_.]*\??)\s*$",
                receipt,
            )
        )
        self.assertEqual(
            receipt_fields,
            expected_receipt_fields,
            "grounding receipt lineage or branch fields drifted",
        )
        self.assertEqual(
            receipt.count("BASContractWireValidation.exactKeySet"),
            1,
            "grounding receipt decoder must enforce one exact key set",
        )
        self.assertEqual(
            receipt.count("try self.init("),
            1,
            "grounding receipt decoder must delegate to its validating initializer",
        )
        self.assertIn(
            "guard candidateKind == nil, mechanismProof == nil else",
            receipt,
            "notRequired must carry explicit nil candidate/proof presence",
        )
        self.assertIn(
            "mechanismProof.validateExactFactsCandidateAndProfile(",
            receipt,
            "grounding must reuse the shared facts/candidate/profile validator",
        )
        self.assertIn(
            "case (.fullProvider, .model, .openGenerativeProvider, .model):",
            receipt,
            "model grounding must remain fullProvider-only",
        )
        self.assertIn(
            "guard compatible else {",
            receipt,
            "grounding compatibility must fail closed",
        )
        self.assertEqual(receipt.count("try c.encodeNil(forKey:"), 2)

        compatibility = section(
            receipt,
            "switch (capabilityProfile, candidateKind, mechanismProof, branch) {",
            "\n        default:",
        )
        tuple_pattern = re.compile(
            r"\((?:\.([A-Za-z][A-Za-z0-9]*)|(_)),\s*"
            r"\.([A-Za-z][A-Za-z0-9]*),\s*"
            r"\.([A-Za-z][A-Za-z0-9]*),\s*"
            r"\.([A-Za-z][A-Za-z0-9]*)\)"
        )
        actual_compatibility = {
            (profile or wildcard, candidate, proof, result_branch)
            for profile, wildcard, candidate, proof, result_branch in tuple_pattern.findall(
                compatibility
            )
        }
        self.assertEqual(
            actual_compatibility,
            expected_compatibility,
            "grounding profile/candidate/proof/branch map is not exact",
        )

        normalized = re.sub(r"\s+", " ", self.master)
        for admission_contract in (
            "`BASSemanticStateMarket` store-aware `admitGroundingReceipt` function "
            "reopens the outer operation and Attempt",
            "recomputes the plan/proof canonical digests",
            "Same-shape bytes, a valid receipt from another Attempt/profile/packet, "
            "and a proof whose certification is no longer current all fail closed.",
            "`BASContextCompiler.makeNonModelMaterialization(packet:"
            "selectedPlanArtifactID:capabilityProfile:artifactStore:)`",
            "`BASContextCompiler.makeModelMaterialization(packet:"
            "selectedExecutionPlanArtifactID:mechanismProof:capabilityProfile:"
            "compiledContext:artifactStore:)`",
        ):
            self.assertIn(
                admission_contract,
                normalized,
                "grounding/materialization admission lost a store-aware reopen binding",
            )
        for wave_contract in (
            "are the sole W4 compiler-extension factories accepted by execution",
            "the W3 candidate declares or references none of "
            "`BASNonModelProposalPlan`, `BASNonModelProposalInputProfile`, "
            "`BASNonModelProposalInput`, or `BASProposalInputMaterialization`",
            "In one atomic W4 candidate, planned first wire "
            "`BehavioralAISubstrate/Sources/BASOrgan/BASProposalEngineAdapter.swift` "
            "owns candidate election, returns the contained `BASNonModelProposalPlan`",
            "`BehavioralAISubstrate/Sources/BASOrchestration/"
            "ContextCompilerCore.swift` declares `BASNonModelProposalInputProfile`, "
            "`BASNonModelProposalInput`, and runtime-only "
            "`BASProposalInputMaterialization` plus their sole validating factories",
            "it first builds the exact W3 candidate and proves all four future type "
            "names absent from its dependency closure, then builds the W4 candidate "
            "with both the BASOrgan plan declaration and `ContextCompilerCore` "
            "materialization extension present",
        ):
            self.assertIn(
                wave_contract,
                normalized,
                "materialization must compile only in the atomic W4 two-owner slice",
            )

    def test_model_neutral_resource_inventory_is_closed_canonical_and_digest_bound(
        self,
    ) -> None:
        expected_kinds = {
            "artifact",
            "evidenceSpan",
            "outputSchema",
            "toolOrCapability",
            "attachment",
        }
        expected_fields = {
            "resourceKind": "BASModelNeutralResourceKind",
            "canonicalResourceID": "String",
            "contentDigest": "String",
        }
        kind = swift_declaration_block(self.master, "BASModelNeutralResourceKind")
        self.assertEqual(
            swift_enum_cases(kind),
            expected_kinds,
            "model-neutral inventory kinds must be the exact closed five",
        )
        row = swift_declaration_block(
            self.master, "BASModelNeutralResourceInventoryRow"
        )
        self.assertEqual(
            swift_stored_property_types(row),
            expected_fields,
            "model-neutral resource row fields or types drifted",
        )
        self.assertEqual(
            row.count("BASContractWireValidation.exactKeySet"),
            1,
            "resource row decoder must enforce one exact key set",
        )
        self.assertEqual(
            row.count("try self.init("),
            1,
            "resource row decoder must reuse its validating initializer",
        )

        inventory = re.sub(
            r"\s+",
            " ",
            section(
                self.master,
                "The factory enumerates every explicit packet reference",
                "That conservative cost is derived only",
            ),
        )
        for contract in (
            "It canonical-sorts unique rows by `(resourceKind.rawValue, "
            "canonicalResourceID UTF-8, contentDigest)`",
            "rejects an exact duplicate tuple, the same `(kind, ID)` with a different "
            "digest, an omitted packet reference, a foreign row, a reordered row or "
            "a digest mismatch",
            "One exact resource shared by several packet sections appears once;",
            "a resource whose monetary or execution cost is zero still contributes "
            "one unit",
            "`resourceUnitCount` must equal the unique canonical row count",
            "`resourceInventoryDigest` must equal the domain-separated "
            '`SHA256("qinao.model-neutral-resource-inventory.v1" || canonicalRows)`',
        ):
            self.assertIn(
                contract,
                inventory,
                "resource inventory canonicalization/dedup/digest contract drifted",
            )

    def test_superstep_store_admission_reopens_every_branch(self) -> None:
        admission = re.sub(
            r"\s+",
            " ",
            section(
                self.master,
                "Superstep 7 has two deliberately separate validation stages.",
                "R4 and R5 must close availability explicitly",
            ),
        )
        expected_signature = (
            "`BASSemanticTurnDAG.admitSuperstepSevenObservation(decoded:"
            "artifactStore:expectedTurnOperationRef:expectedAttemptRefArtifactID:"
            "expectedStructuredContextPacketDigest:expectedCapabilityProfile:) "
            "async throws`"
        )
        self.assertEqual(
            admission.count(expected_signature),
            1,
            "superstep 7 must have one exact store-aware admission API",
        )
        for contract in (
            "a successfully decoded value is inert and ineligible for execution",
            "requires the outer operation, Attempt, canonical packet digest and "
            "Attempt-frozen profile to equal the expected values",
            "reopens every contained mechanism certification and reruns the shared "
            "tag/facts/candidate/profile validator",
            "For `providerPrefillDecode` it reopens `providerExecutionRef` and "
            "`workReceiptArtifactID` as the incumbent Provider execution and "
            "terminal-work wrappers",
            "For each non-provider case it reopens the actual bounded-inference, "
            "deterministic-proposal or authenticated human/tool completion wrapper",
            "For `noWork` it reopens the exact current "
            "`BASR5ProducerAvailabilityReceipt`",
            "accepts only `.notRequired`; `.unavailable`, `.coverageDeficit`, a stale "
            "receipt or an open obligation fails",
            "strict decoding alone can never advance the superstep",
        ):
            self.assertIn(
                contract,
                admission,
                "superstep store admission lost lineage, reopen, or branch closure",
            )
        self.assertIn(
            "It receives the already-opened incumbent `BASArtifactStorePort` and does "
            "not create a store, writer, registry row, scheduler or execution authority.",
            admission,
            "superstep admission must reuse the incumbent Artifact store",
        )

    def test_w1_installed_tree_handoff_does_not_extend_closed_receipt(self) -> None:
        w1 = section(
            self.master,
            "## Controlled Domain-Plan Payload W1:",
            "## Controlled Domain-Plan Payload W2:",
        )
        handoff = re.sub(
            r"\s+",
            " ",
            section(
                w1,
                "W1 treats both capability-profile proof inputs as installed-tree trust",
                "### Payload 3E — Verify and commit",
            ),
        )
        for contract in (
            "The incumbent closed terminal receipt remains unchanged: its existing "
            "`installedCommit`, `installedTree`, and protected-validation "
            "`toolRowsRoot`/`externalInputRowsRoot`/command roots indirectly commit "
            "the sole-policy source rows.",
            "It verifies and reopens the receipt, derives `installedTree` itself, "
            "checks the root-bound source rows",
            "uses the incumbent `read_tree_blob` seam to derive both Git blob OIDs, "
            "bytes, modes, byte lengths and SHA-256 values at the two fixed source paths",
            "stable-opens fresh read-only regular files outside every later candidate "
            "worktree and returns the four table bindings atomically",
            "caller-provided bytes fails closed before W4 or W6",
        ):
            self.assertIn(
                contract,
                handoff,
                "W1 installed-tree handoff lost receipt, tree-read, or stable-open trust",
            )

        commands = [
            command
            for block in fenced_shell_blocks(w1)
            for command in logical_shell_commands(block)
            if "materialize-installed-blob" in command
        ]
        self.assertEqual(len(commands), 1)
        argv = strict_shell_argv(commands[0])
        self.assertEqual(argv[0], "$QINAO_GIT_PREPARATION_BROKER")
        self.assertEqual(
            option_values(argv, "--verified-terminal-receipt"),
            ["$QINAO_CURRENT_ADMISSION_RECEIPT"],
        )
        self.assertEqual(
            option_values(argv, "--format"),
            [
                "runner-sha256,runner-read-only-path,profile-manifest-sha256,"
                "profile-manifest-read-only-path"
            ],
        )
        for forbidden in ("--installed-tree", "--source", "--runner-bytes"):
            self.assertNotIn(forbidden, argv)
        self.assertIn(
            "QINAO_W1_MODEL_ERASED_HANDOFF_EXTRA",
            w1,
            "four-field broker handoff must reject a partial or extra projection",
        )
        self.assertIn(
            'test -z "$QINAO_W1_MODEL_ERASED_HANDOFF_EXTRA"',
            w1,
            "four-field broker handoff must fail on extra output",
        )

    def test_classifier_migration_and_profile_inheritance_are_exact(self) -> None:
        classifier = section(
            self.master,
            "- Split and migrate the incumbent context classifier without adding a target,",
            "The W1-admitted immutable closure runner establishes",
        )
        normalized_classifier = re.sub(r"\s+", " ", classifier)
        initial_migration = section(
            self.master,
            "- Split and migrate the incumbent context classifier without adding a target,",
            "- Modify runtime caller: `BehavioralAISubstrate/Sources/BASHostKit/"
            "BASTurnRuntimeEngine.swift`",
        )
        normalized_initial = re.sub(r"\s+", " ", initial_migration)

        for migration_contract in (
            "introducing the exact contained `BASContextClassifierContract`, "
            "`BASContextClassification`, `BASContextClassifierContractViolation`, and "
            "synchronous `BASContextClassifying` ABI below",
            "The protocol and result do **not** exist in the predecessor",
            "move `BehavioralAISubstrate/Sources/BASRuntimeCore/"
            "BASContextClassifierMLAdapter.swift` to `BehavioralAISubstrate/Sources/"
            "BASAppleAdapters/BASContextClassifierMLAdapter.swift`",
            "move `BehavioralAISubstrate/Sources/BASRuntimeCore/Resources/"
            "BASContextClassifier.mlmodel` to `BehavioralAISubstrate/Sources/"
            "BASAppleAdapters/Resources/BASContextClassifier.mlmodel`",
            "add exact `.process(\"Resources/BASContextClassifier.mlmodel\")` to the "
            "existing `BASAppleAdapters` resource list (not `.copy`",
            "preserve the existing dependency direction `BASAppleEdgeWiring -> "
            "BASHostKit + BASAppleAdapters`",
            "No concrete adapter name, CoreML import, model URL or model resource may "
            "remain reachable from `BASRuntimeCore` or `BASHostKit`",
            "Because the preserved thirteen-argument public factory surface names "
            "`BASMetalKernelLibraryLoader`, add the existing `BASMetalSubstrate` target "
            "as one direct `BASAppleEdgeWiring` dependency and import it in the new "
            "factory source",
            "do not rely on BASHostKit's transitive edge or add another product",
            "pure encoder/contract stays in RuntimeCore, concrete-adapter use moves "
            "to/imports `BASAppleAdapters`, learned full-default construction moves "
            "to/imports `BASAppleEdgeWiring`, or an explicitly model-neutral test/caller "
            "changes to the full `makeModelNeutral(pilotPreset:...)` surface",
        ):
            self.assertIn(
                migration_contract,
                normalized_initial,
                "classifier ABI, target migration, resource recipe, or inventory drifted",
            )

        production_call_sites = (
            "BehavioralAISubstrate/Sources/BASHostKit/BASMLContextService.swift",
            "BehavioralAISubstrate/Sources/BASHostKit/BASCognitiveBrain.swift",
            "BehavioralAISubstrate/Sources/BASHostKit/BASCognitiveBrain+Construction.swift",
            "BehavioralAISubstrate/Sources/BASHostKit/BASCognitiveBrain+Pilots.swift",
            "BehavioralAISubstrate/Sources/BASAppleAdapters/"
            "BASCoreAIContextClassifierAdapter.swift",
            "BehavioralAISubstrate/Sources/BASBrainCLI/main.swift",
            "BehavioralAISubstrate/Sources/BASJournalCLI/Verdict.swift",
            "BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/"
            "BASModuleLayeringTripwireTests.swift",
            "BehavioralAISubstrate/Sources/BASAppleEdgeWiring/"
            "BASCognitiveBrain+AppleContextClassifier.swift",
            "BehavioralAISubstrate/DeviceTestApp/project.yml",
            "BehavioralAISubstrate/DeviceTestApp/BASDeviceTest.xcodeproj/project.pbxproj",
            "BehavioralAISubstrate/DeviceTestApp/Sources/App/BASEnduranceAppRunner.swift",
            "BehavioralAISubstrate/Docs/ADR_041_COREAI_ONDEVICE_ADAPTER_SHADOW.md",
        )
        for path in production_call_sites:
            self.assertIn(f"`{path}`", initial_migration, path)
        for call_site_contract in (
            "add the existing `BASAppleEdgeWiring` product to the existing `BASBrainCLI` "
            "and `BASJournalCLI` target dependencies",
            "keep `BASAppleEdgeWiring == 9`, change exactly `BASBrainCLI` and "
            "`BASJournalCLI` from layer 9 to layer 10, preserve every other "
            "module/layer row, and preserve the incumbent strict-lower comparison "
            "plus its upward, downward and same-layer negative controls",
            "A CLI left at 9, EdgeWiring raised with it, weakened `>=` comparison, or "
            "newly permitted peer import fails the existing tripwire and the focused "
            "build-recipe sentinel below",
            "the `BASDeviceTestApp` application target does not: atomically modify "
            "`BehavioralAISubstrate/DeviceTestApp/project.yml` and its checked-in "
            "`BehavioralAISubstrate/DeviceTestApp/BASDeviceTest.xcodeproj/project.pbxproj` "
            "so the app target itself has exactly one `BASAppleEdgeWiring` product "
            "dependency",
            "while retaining its incumbent package/product dependencies and adding no "
            "second package reference",
            "The W4 recipe does not invoke ambient XcodeGen",
            "to import the already-linked edge-wiring product and use the explicit "
            "learned factory",
            "replace every direct `BASMLContextService(adapter: "
            "BASContextClassifierMLAdapter())` construction with the protocol-only "
            "`classifier:` seam",
            "migrate both synchronous Core ML probe sites and both asynchronous Core AI "
            "shadow sites to the nominal `BASContextClassification`/their still-separate "
            "async result surfaces",
            "preserve their current comparison, memory and audit behavior without a tuple "
            "compatibility shim or a second adapter instance",
            "The direct AppleAdapters-only `BASANEUtilizationProbe.swift` remains valid "
            "after the move but is still an inventoried adapter caller and must consume "
            "the nominal result rather than tuple-only API if it observes the return value",
            "machine-inventory every predecessor Swift source and test reference to "
            "`BASContextClassifierMLAdapter`, `mlClassifierAdapter`, and "
            "`BASCognitiveBrain.makeWithDefaults`/`makeWithAllPilots`",
            "An omitted, duplicated or unclassified caller blocks W4",
            "`SRC_MLMODEL` binding to the exact new `Sources/BASAppleAdapters/Resources/"
            "BASContextClassifier.mlmodel` path",
            "must still fail nonzero for a missing input and may not discover the source "
            "through `find`, `PATH`, a second copy or caller input",
            "plus the current-location statement in "
            "`BehavioralAISubstrate/Docs/ADR_041_COREAI_ONDEVICE_ADAPTER_SHADOW.md`",
        ):
            self.assertIn(call_site_contract, normalized_initial)
        self.assertIn(
            "`BehavioralAISubstrate/scripts/coreai-build-aimodel.sh`",
            initial_migration,
        )
        self.assertEqual(
            initial_migration.count('.process("Resources/BASContextClassifier.mlmodel")'),
            1,
            "Package.swift must have one exact processed classifier resource recipe",
        )

        expected_direct_tests = {
            "BASContextClassifierMLAdapterTests.swift",
            "BASContextClassifierHeldOutAccuracyTests.swift",
            "BASContextClassifierTokenizationParityTests.swift",
            "BASMLContextServiceDerivedSignalsTests.swift",
            "BASCognitiveBrainEdgeCaseTests.swift",
            "BASCognitiveBrainPerformanceTests.swift",
            "BASCognitiveBrainProbabilityDistributionTests.swift",
            "BAST1DeviceTests.swift",
            "BAST5EnergySessionDeviceTests.swift",
            "BASCoreAIPresenceTests.swift",
        }
        for filename in expected_direct_tests:
            self.assertEqual(
                initial_migration.count(filename),
                1,
                f"direct classifier caller/test inventory drifted: {filename}",
            )
        for test_contract in (
            "exact contract cases for the seven ordered labels, successful public "
            "result init, invalid/non-finite confidence, wrong/non-finite logits, "
            "permitted unknown label, both adapter compile branches' explicit "
            "conformance, and synchronous fake injection",
            "build-recipe case also asserts the exact `.process` resource move, runnable "
            "conversion-script path, the one direct `BASMetalSubstrate` dependency/import "
            "required by the EdgeWiring factory ABI, exact layering-tripwire rows "
            "`BASAppleEdgeWiring=9,BASBrainCLI=10,BASJournalCLI=10` with strict-lower "
            "semantics unchanged, one EdgeWiring dependency in both "
            "the DeviceTest app target's `project.yml` and checked-in `project.pbxproj`, "
            "with matching package-product identity",
            "inject a throwing `BASContextClassifying` fake and exercise the incumbent "
            "catch/audit-hint path without loading a model",
            "compile the pure contract, HostKit service and both closed model-neutral "
            "pilot presets while proving zero concrete-adapter/resource/symbol reachability",
            "full-profile fixture must compile both presets through the one Apple factory "
            "and prove the same adapter instance feeds classification and the probability "
            "side channel",
        ):
            self.assertIn(test_contract, normalized_initial)

        contract = swift_declaration_block(
            self.master,
            "BASContextClassifierContract",
        )
        self.assertEqual(
            re.findall(r'"([A-Za-z][A-Za-z0-9]*)"', contract),
            [
                "chat",
                "task",
                "choice",
                "conflict",
                "highPressure",
                "manipulationRisk",
                "highConsequence",
            ],
        )
        self.assertEqual(contract.count("public static let orderedLabels: [String]"), 1)

        violation = swift_declaration_block(
            self.master,
            "BASContextClassifierContractViolation",
        )
        self.assertEqual(
            violation.splitlines()[0].strip(),
            "public enum BASContextClassifierContractViolation:",
        )
        self.assertIn("Error, Equatable, Sendable {", violation)
        self.assertEqual(
            re.findall(r"(?m)^\s*case\s+([A-Za-z_][A-Za-z0-9_]*)\s*$", violation),
            ["invalidResult"],
        )

        result = swift_declaration_block(self.master, "BASContextClassification")
        self.assertEqual(
            result.splitlines()[0].strip(),
            "public struct BASContextClassification: Sendable, Equatable {",
        )
        self.assertNotIn("Codable", result)
        self.assertEqual(
            swift_stored_property_types(result),
            {"label": "String", "confidence": "Double", "logits": "[Float]"},
        )
        normalized_result = re.sub(r"\s+", " ", result)
        self.assertIn(
            "public init( label: String, confidence: Double, logits: [Float] ) throws {",
            normalized_result,
        )
        for invariant in (
            "confidence.isFinite",
            "(0.0...1.0).contains(confidence)",
            "logits.count == BASContextClassifierContract.orderedLabels.count",
            "logits.allSatisfy({ $0.isFinite })",
            "throw BASContextClassifierContractViolation.invalidResult",
            "self.label = label",
            "self.confidence = confidence",
            "self.logits = logits",
        ):
            self.assertEqual(result.count(invariant), 1, invariant)

        protocol_matches = re.findall(
            r"(?ms)^public protocol BASContextClassifying: Sendable \{\n(.*?)^\}",
            classifier,
        )
        self.assertEqual(len(protocol_matches), 1)
        self.assertEqual(
            re.sub(r"\s+", " ", protocol_matches[0]).strip(),
            "func classify(text: String) throws -> BASContextClassification",
        )
        self.assertEqual(swift_reserved_declaration_count(self.master, "BASContextClassifying"), 1)
        for result_contract in (
            "`BASContextClassification` is ephemeral and deliberately not `Codable`",
            "It deliberately permits an unknown label",
            "The moved `BASContextClassifierMLAdapter` explicitly conforms",
            "public `labels` compatibility alias as "
            "`BASContextClassifierContract.orderedLabels`",
            "The asynchronous Core AI shadow adapter is not forced into this "
            "synchronous port",
        ):
            self.assertIn(result_contract, normalized_classifier)

        pilot = swift_declaration_block(self.master, "BASCognitiveBrainPilotPreset")
        self.assertEqual(
            pilot.splitlines()[0].strip(),
            "public enum BASCognitiveBrainPilotPreset: String, Sendable, Equatable {",
        )
        self.assertNotIn("Codable", pilot)
        self.assertEqual(
            re.findall(r"(?m)^\s*case\s+([A-Za-z_][A-Za-z0-9_]*)\s*$", pilot),
            ["defaults", "allNative"],
        )
        factory_error = swift_declaration_block(
            self.master,
            "BASCognitiveBrainFactoryError",
        )
        self.assertEqual(
            factory_error.splitlines()[0].strip(),
            "public enum BASCognitiveBrainFactoryError: Error, Equatable, Sendable {",
        )
        self.assertEqual(
            re.findall(
                r"(?m)^\s*case\s+([A-Za-z_][A-Za-z0-9_]*)\s*$",
                factory_error,
            ),
            ["explicitPilotOverrideConflictsWithAllNative"],
        )
        self.assertNotIn("Codable", factory_error)

        factory_arguments = markdown_table_rows(
            self.master,
            "| argument label | exact type | exact default |",
        )
        self.assertEqual(
            factory_arguments,
            [
                [
                    "summaryHistoryCapacity",
                    "Int",
                    "BASCognitiveBrain.defaultSummaryHistoryCapacity",
                ],
                ["sqlHistoryStore", "BASSQLBrainHistoryStore?", "nil"],
                ["rustHistoryStore", "BASRustBrainHistoryStore?", "nil"],
                ["cxxSummaryCache", "BASCxxBrainSummaryCache?", "nil"],
                ["metalLibraryLoader", "BASMetalKernelLibraryLoader?", "nil"],
                [
                    "safetyConfidenceThreshold",
                    "Double",
                    "BASCognitiveBrain.safetyConfidenceThreshold",
                ],
                ["hostProfileService", "(any BASHostProfileServicing)?", "nil"],
                ["healthSnapshotHistoryCapacity", "Int", "0"],
                ["healthSnapshotAutoCaptureEvery", "Int", "0"],
                ["metalSignalThreshold", "Double?", "nil"],
                ["memoryEmbed", "(@Sendable (String) -> [Float])?", "nil"],
                ["memoryEmbedDim", "Int", "384"],
                ["memoryPersistence", "BASRoutedMemoryPersistence?", "nil"],
            ],
            "both brain factories must preserve the exact thirteen-argument union",
        )
        for factory_contract in (
            "Both public replacement factories have the same closed argument-label, "
            "type and default-value surface below after the required, non-defaulted "
            "`pilotPreset: BASCognitiveBrainPilotPreset`; both are `public static` and "
            "remain `async throws -> BASCognitiveBrain`",
            "Apple factory does not expose a classifier argument because its "
            "implementation supplies the sole lazy moved-adapter factory itself",
            "`package` common-construction routine has the same surface plus its one "
            "package-only lazy input `contextClassifierFactory: (@Sendable () throws -> "
            "any BASContextClassifying)?`",
            "it accepts no already-created classifier, context service, second closure "
            "or other classifier source",
            "No convenience overload may omit the preset, discard an incumbent "
            "customization, or create a third public composition path",
            "For `.defaults`, all thirteen arguments retain the incumbent "
            "`makeWithDefaults` semantics",
            "including every explicit SQL/Rust/C++/Metal injection and memory "
            "embed/persistence customization",
            "For `.allNative`, the common routine creates exactly the incumbent "
            "five-pilot composition (internal C clock plus SQL, Rust, C++ and Metal "
            "mechanisms)",
            "carries every non-pilot setting and all memory embed/dimension/persistence "
            "arguments through unchanged",
            "requires the four explicit pilot-override arguments "
            "`sqlHistoryStore|rustHistoryStore|cxxSummaryCache|metalLibraryLoader` all "
            "to be `nil`",
            "Any non-`nil` override throws exactly "
            "`BASCognitiveBrainFactoryError.explicitPilotOverrideConflictsWithAllNative` "
            "before constructing a pilot, classifier, service or brain",
            "it is never ignored, merged or allowed to shadow the preset",
            "each old 13-argument `makeWithDefaults` call and each old six-argument "
            "`makeWithAllPilots` call retains every explicitly supplied value",
            "targeted fixtures cover all thirteen labels, both presets, the typed "
            "conflict and byte-equivalent customization forwarding",
        ):
            self.assertIn(factory_contract, normalized_classifier)
        for composition_contract in (
            "`BASMLContextService` stores `any BASContextClassifying`, accepts it "
            "through a public `classifier:` initializer",
            "`BASCognitiveBrain.swift` stores `contextClassifier: "
            "(any BASContextClassifying)?`",
            "exposes only the full closed `makeModelNeutral(pilotPreset:...)` surface "
            "above for the zero-learned path",
            "exposes the one learned `makeWithAppleContextClassifier(pilotPreset:...)` "
            "surface with the same thirteen customization arguments",
            "supplies one lazy closure that can construct the moved Core ML adapter",
            "common routine validates the preset and all four override values before "
            "invoking that closure",
            "invokes it at most once per successful brain",
            "then constructs `BASMLContextService` and the probability side channel "
            "from that same returned existential instance",
            "constructs exactly one moved Core ML adapter per learned brain",
            "injects that same instance into `BASMLContextService` and the probability "
            "side channel",
            "Both public factories delegate one `package`-scoped common HostKit "
            "construction routine",
            "model-neutral factory selects the incumbent `BASPlaceholderContextService` "
            "only at L0 and retains the same incumbent power, host-profile, "
            "decomposition, memory, risk, Tri-Self, evolution, action and selected "
            "pilot composition as its learned counterpart",
            "It must not reuse the current explicit-services initializer that replaces "
            "the other services with placeholders, and must not invent a deterministic "
            "fake classifier",
            "Apple factory differs only by passing the lazy moved-classifier factory; "
            "the common routine alone creates the service and shares the result",
            "model-neutral factory passes `nil`",
            "a classifier/service pair can never be supplied from different sources",
            "Every predecessor call site is atomically rewritten to one of those two "
            "named factories with an explicit preset",
            "or second composition factory fails W4",
            "`BASJournalCLI` adds/imports the existing `BASAppleEdgeWiring` target and "
            "uses the full-profile factory",
        ):
            self.assertIn(composition_contract, normalized_classifier)

        w4_gate = section(
            self.master,
            "### Payload 6G (W4) — Admit and install the exact W4 candidate commit",
            "## Controlled Domain-Plan Payload W5:",
        )
        gate_commands = [
            command
            for block in fenced_shell_blocks(w4_gate)
            for command in logical_shell_commands(block)
            if "scripts/run_nonempty_swift_filter.py" in command
            and "--package-path BehavioralAISubstrate" in command
        ]
        self.assertEqual(len(gate_commands), 1)
        gate_argv = direct_runner_argv(
            gate_commands[0],
            "scripts/run_nonempty_swift_filter.py",
        )
        classifier_suites = [
            "BASContextClassifierMLAdapterTests",
            "BASMLContextServiceFailureModeTests",
            "BASCognitiveBrainProbabilityDistributionTests",
        ]
        gate_suites = option_values(gate_argv, "--require-suite")
        self.assertEqual(
            [suite for suite in gate_suites if suite in classifier_suites],
            classifier_suites,
            "W4 6G must non-vacuously execute all three classifier suites",
        )
        filter_suites = option_values(gate_argv, "--filter")[0].split("|")
        for suite in classifier_suites:
            self.assertEqual(filter_suites.count(suite), 1, suite)
        classifier_tests = [
            "BehavioralAISubstrateTests.BASContextClassifierMLAdapterTests/"
            "testModelNeutralContractIsExactAndAdapterConformsAfterResourceMove",
            "BehavioralAISubstrateTests.BASContextClassifierMLAdapterTests/"
            "testClassifierBuildRecipesUseAppleAdaptersProcessedResource",
            "BehavioralAISubstrateTests.BASMLContextServiceFailureModeTests/"
            "testThrowingClassifierUsesHonestFailureFallback",
            "BehavioralAISubstrateTests.BASCognitiveBrainProbabilityDistributionTests/"
            "testAppleClassifierFactoryUsesOneClassifierForBothPresetsAndProbabilitySideChannel",
        ]
        gate_tests = option_values(gate_argv, "--require-test")
        self.assertEqual(
            [test_id for test_id in gate_tests if test_id in classifier_tests],
            classifier_tests,
            "W4 6G must bind all four exact classifier tests",
        )

        xcode_gate_commands = [
            command
            for block in fenced_shell_blocks(w4_gate)
            for command in logical_shell_commands(block)
            if "scripts/run_nonempty_xcode_test.py" in command
        ]
        self.assertEqual(len(xcode_gate_commands), 1)
        xcode_argv = direct_runner_argv(
            xcode_gate_commands[0],
            "scripts/run_nonempty_xcode_test.py",
        )
        validate_closed_runner_options(
            xcode_argv,
            singleton_options={
                "--xcodebuild-executable",
                "--xcresulttool-executable",
                "--project-path",
                "--scheme",
                "--destination",
                "--derived-data-path",
                "--result-bundle-path",
                "--require-target",
            },
            repeatable_options={"--require-suite", "--require-test"},
        )
        self.assertNotIn("--package-path", xcode_argv)
        expected_xcode_options = {
            "--xcodebuild-executable": ["$QINAO_BOUND_XCODEBUILD_EXECUTABLE"],
            "--xcresulttool-executable": ["$QINAO_BOUND_XCRESULTTOOL_EXECUTABLE"],
            "--project-path": [
                "BehavioralAISubstrate/DeviceTestApp/BASDeviceTest.xcodeproj"
            ],
            "--scheme": ["BASDeviceTestApp"],
            "--destination": ["$QINAO_W4_IOS27_SIMULATOR_DESTINATION"],
            "--derived-data-path": ["$QINAO_W4_DEVICETEST_DERIVED_DATA_ROOT"],
            "--result-bundle-path": ["$QINAO_W4_DEVICETEST_RESULT_BUNDLE_ROOT"],
            "--require-target": ["BASDeviceTests"],
            "--require-suite": [
                "BASDeviceTests/BASCognitiveBrainProbabilityDistributionTests"
            ],
            "--require-test": [
                "BASDeviceTests/BASCognitiveBrainProbabilityDistributionTests/"
                "testAppleClassifierFactoryUsesOneClassifierForBothPresetsAndProbabilitySideChannel"
            ],
        }
        for option, expected in expected_xcode_options.items():
            self.assertEqual(option_values(xcode_argv, option), expected, option)
        normalized_w4_gate = re.sub(r"\s+", " ", w4_gate)
        for xcode_contract in (
            "reopens the unchanged W0-admitted `run_nonempty_xcode_test.py` Git blob "
            "and its W1-tested dual-mode contract",
            "exact installed W1 rows `w1.tool.xcodebuild27`, "
            "`w1.tool.xcresulttool27`, and `w1.input.ios27-simulator`",
            "broker also creates fresh unique repository-external DerivedData/result-"
            "bundle roots",
            "requires zero untracked row beneath the project/package source roots",
            "Project mode must build the `BASDeviceTestApp` host while executing exactly "
            "the required non-skipped `BASDeviceTests/"
            "BASCognitiveBrainProbabilityDistributionTests/"
            "testAppleClassifierFactoryUsesOneClassifierForBothPresetsAndProbabilitySideChannel` "
            "case and no extra case",
            "an Xcode project/source mutation, repository-local output, tree change, "
            "zero-test result or second test target blocks admission",
            "not a substitute for W6's governed physical-device project, signing, "
            "entitlement and archive certification",
        ):
            self.assertIn(xcode_contract, normalized_w4_gate)
        ordered_xcode_anchors = (
            'QINAO_W4_CANDIDATE_TREE=$("$QINAO_GIT_EXECUTABLE" write-tree)',
            '"$QINAO_GIT_EXECUTABLE" diff --quiet',
            'QINAO_W4_PRE_XCODE_UNTRACKED=$("$QINAO_GIT_EXECUTABLE" ls-files '
            '--others --exclude-standard -- BehavioralAISubstrate)',
            'test -z "$QINAO_W4_PRE_XCODE_UNTRACKED"',
            'QINAO_W4_PRE_XCODE_TREE=$("$QINAO_GIT_EXECUTABLE" write-tree)',
            'test "$QINAO_W4_PRE_XCODE_TREE" = "$QINAO_W4_CANDIDATE_TREE"',
            'scripts/run_nonempty_xcode_test.py \\',
            '"$QINAO_GIT_EXECUTABLE" diff --quiet',
            'QINAO_W4_POST_XCODE_UNTRACKED=$("$QINAO_GIT_EXECUTABLE" ls-files '
            '--others --exclude-standard -- BehavioralAISubstrate)',
            'test -z "$QINAO_W4_POST_XCODE_UNTRACKED"',
            'QINAO_W4_POST_XCODE_TREE=$("$QINAO_GIT_EXECUTABLE" write-tree)',
            'test "$QINAO_W4_POST_XCODE_TREE" = "$QINAO_W4_CANDIDATE_TREE"',
        )
        cursor = -1
        for anchor in ordered_xcode_anchors:
            cursor = w4_gate.find(anchor, cursor + 1)
            self.assertGreaterEqual(cursor, 0, anchor)

        commands = [
            command
            for block in fenced_shell_blocks(self.master)
            for command in logical_shell_commands(block)
            if "$QINAO_W1_ADMITTED_MODEL_ERASED_RUNNER" in command
        ]
        self.assertEqual(len(commands), 2)
        expected_resource_bans = {
            "no-language-inference:language-model-weight",
            "no-language-inference:tokenizer",
            "no-language-inference:prompt-template",
            "no-learned-inference:learned-weight",
            "no-learned-inference:language-model-weight",
            "no-learned-inference:tokenizer",
            "no-learned-inference:prompt-template",
        }
        for command in commands:
            argv = direct_runner_argv(
                command, "$QINAO_W1_ADMITTED_MODEL_ERASED_RUNNER"
            )
            self.assertEqual(
                Counter(option_values(argv, "--forbid-profile-resource")),
                Counter(expected_resource_bans),
                "physical profiles do not expand inherited resource prohibitions",
            )
            self.assertEqual(
                option_values(argv, "--forbid-target").count("BASAppleAdapters"),
                1,
                "model-erased profiles must remove the concrete classifier adapter target",
            )
        for inheritance_contract in (
            "`BASAppleEdgeWiring` target is the sole learned full-profile composition "
            "point",
            "The `fullProvider` projection retains that composition.",
            "The `noLearnedInference` projection must have zero reachable classifier-"
            "adapter source, `.mlmodel` resource, compiler dependency, object symbol, "
            "link-map input, registration or dynamic-loader row",
            "`noLanguageInference` inherits all `noGenerativeProvider` prohibitions, "
            "and `noLearnedInference` inherits all `noLanguageInference` prohibitions "
            "before also forbidding learned mechanisms",
        ):
            self.assertIn(inheritance_contract, re.sub(r"\s+", " ", self.master))

    def test_all_cross_target_values_have_strict_codec_and_public_init(
        self,
    ) -> None:
        strict_public_values = (
            "BASProposalMechanismEvidence",
            "BASWorldModelSearchCausalProof",
            "BASNonModelProposalPlan",
            "BASNonModelProposalInput",
            "BASR4DenseLaneAvailabilityReceipt",
            "BASR5ProducerAvailabilityReceipt",
            "BASGroundingReceipt",
            "BASSuperstepSevenProviderWork",
            "BASSuperstepSevenNonProviderWork",
            "BASSuperstepSevenNoWorkEvidence",
            "BASSuperstepSevenObservationReceipt",
            "BASModelNeutralResourceInventoryRow",
            "BASProviderExactAccounting",
        )
        for symbol in strict_public_values:
            with self.subTest(symbol=symbol):
                declaration = swift_declaration_block(self.master, symbol)
                self.assertRegex(
                    declaration,
                    r"(?s)\bpublic\s+init\(\s*(?!from\b)[A-Za-z_]",
                    f"{symbol} must expose one explicit cross-target initializer",
                )
                self.assertEqual(
                    declaration.count("public init(from decoder: Decoder)"),
                    1,
                    f"{symbol} must have one explicit decoder",
                )
                self.assertEqual(
                    declaration.count("BASContractWireValidation.exactKeySet"),
                    1,
                    f"{symbol} decoder must enforce one exact key set",
                )

        tagged_wires = {
            "BASProposalMechanismProof": (
                "extension BASProposalMechanismProof: Codable {",
                "\n}\n\npublic struct BASNonModelProposalPlan:",
            ),
            "BASLaneAvailabilityDisposition": (
                "extension BASLaneAvailabilityDisposition: Codable {",
                "\n}\n\npublic struct BASR4DenseLaneAvailabilityReceipt:",
            ),
            "BASGroundingProposalBranch": (
                "extension BASGroundingProposalBranch: Codable {",
                "\n}\n\npublic struct BASGroundingReceipt:",
            ),
            "BASSuperstepSevenExecutionKind": (
                "extension BASSuperstepSevenExecutionKind: Codable {",
                "\n}\n\npublic struct BASSuperstepSevenProviderWork:",
            ),
        }
        for symbol, (start, end) in tagged_wires.items():
            with self.subTest(symbol=symbol):
                wire = section(self.master, start, end)
                coding_keys = section(
                    wire,
                    "private enum CodingKeys: String, CodingKey, CaseIterable {",
                    "\n    }\n\n    private enum Kind:",
                )
                keys = [
                    name
                    for line in re.findall(r"(?m)^\s*case\s+([^\n]+)$", coding_keys)
                    for name in (item.strip() for item in line.split(","))
                ]
                self.assertEqual(
                    keys,
                    ["kind", "evidence"],
                    f"{symbol} must retain the strict kind/evidence envelope",
                )
                self.assertEqual(
                    wire.count("BASContractWireValidation.exactKeySet"),
                    1,
                    f"{symbol} must reject extra or omitted envelope keys",
                )
                self.assertIn(
                    "guard let value = Self(rawValue:",
                    wire,
                    f"{symbol} nested kind must reject unknown raw tags",
                )

        lane_wire = section(
            self.master,
            "extension BASLaneAvailabilityDisposition: Codable {",
            "\n}\n\npublic struct BASR4DenseLaneAvailabilityReceipt:",
        )
        lane_encoder = lane_wire[
            lane_wire.index("public func encode(to encoder: Encoder) throws {") :
        ]
        lane_cases = ("available", "unavailable", "notRequired", "coverageDeficit")
        for case_name in lane_cases:
            with self.subTest(lane_case=case_name):
                self.assertEqual(
                    lane_encoder.count(f"case .{case_name}(let evidence):"),
                    1,
                    f"{case_name} must have one encoder branch",
                )
                self.assertEqual(
                    lane_encoder.count(
                        f"try c.encode(Kind.{case_name}, forKey: .kind)"
                    ),
                    1,
                    f"{case_name} must encode its kind exactly once",
                )
        self.assertEqual(
            lane_encoder.count("try c.encode(evidence, forKey: .evidence)"),
            len(lane_cases),
            "each lane disposition must encode one evidence value",
        )

    def test_shell_tool_scan_reconstructs_lexical_cross_line_names(self) -> None:
        synthetic = "```bash\nxc\\\nrun xcresulttool get\n```"
        self.assertEqual(
            naked_shell_tool_matches(
                synthetic,
                {"xcodebuild", "xcresulttool", "xcrun"},
            ),
            ["xcrun xcresulttool get"],
        )

    def test_required_test_selector_collection_preserves_cardinality(self) -> None:
        synthetic = """```bash
$QINAO_TEST_PROTECTED_PYTHON scripts/run_nonempty_swift_filter.py \\
  --require-test Module.Suite/testOne \\
  --require-test Module.Suite/testOne
```
```bash
$QINAO_TEST_PROTECTED_PYTHON scripts/run_qinao_model_erased_build.py \\
  --require-test Module.Suite/testOne
```"""
        self.assertEqual(
            required_test_selectors(synthetic),
            ["Module.Suite/testOne", "Module.Suite/testOne"],
        )

    def test_required_regex_group_fails_as_an_assertion_not_attribute_error(
        self,
    ) -> None:
        with self.assertRaisesRegex(AssertionError, "missing subcommand"):
            required_regex_group(r"tool (inspect|build)", "tool", "subcommand")

    def test_source_review_id_classes_map_to_distinct_regression_prefixes(
        self,
    ) -> None:
        self.assertEqual(source_review_regression_prefix("SR-B01"), "b")
        self.assertEqual(source_review_regression_prefix("SR-M01"), "major")
        self.assertEqual(source_review_regression_prefix("SR-m01"), "minor")


if __name__ == "__main__":
    unittest.main()
