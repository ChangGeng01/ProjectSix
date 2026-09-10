#!/usr/bin/env python3
"""Prepare one deterministic, non-authoritative Qinao Wave V2 Git commit."""

from __future__ import annotations

import argparse
import hashlib
import os
import re
import stat
import subprocess
import sys
from contextlib import contextmanager
from datetime import datetime
from pathlib import Path

try:
    import check_qinao_owner_ledger as owner_ledger
    import run_qinao_wave_admission as admission_runner
except ModuleNotFoundError:
    from scripts import check_qinao_owner_ledger as owner_ledger
    from scripts import run_qinao_wave_admission as admission_runner


EXIT_SUCCESS = 0
EXIT_USAGE = 2
EXIT_POLICY = 3
EXIT_GIT = 4
EXIT_CONFLICT = 5
EXIT_INTERNAL = 70

TARGET_REF = "refs/heads/codex/qinao-admitted-controlled-convergence"
PREPARED_REF_PREFIX = "refs/qinao/prepared/wave-v2/"
COMMIT_IDENTITY = "Qinao Wave Candidate <qinao-wave-candidate@invalid>"
TERMINAL_ROOT_DOMAIN = b"QINAO-LEDGER-V2-MIGRATION-TERMINAL-ROOT-V1\x00"
V2_ROLE_SCOPE = (
    "wave-admission-signer",
    "QinaoWaveAdmissionReceiptV2",
)

V2_ROWS = (
    (
        "W1",
        "w1.artifact-mesh-contract-freeze",
        1,
        "feat(qinao): restore mesh and freeze automation contracts",
    ),
    (
        "W2",
        "w2.state-and-retention",
        1,
        "feat(qinao): extend K3 for governed automation and retention",
    ),
    (
        "W3",
        "w3.state-projections",
        1,
        "feat(qinao): add dual-space state projections",
    ),
    (
        "W3",
        "w3.context-convergence",
        2,
        "feat(qinao): converge sole context compilation",
    ),
    (
        "W4",
        "w4.model-adaptive-context",
        1,
        "feat(qinao): compile isolated model-adaptive contexts",
    ),
    (
        "W5",
        "w5.automation-apple-effects",
        1,
        "feat(qinao): govern automation inspection and Apple effects",
    ),
    (
        "W6",
        "w6.runtime.observation-values",
        1,
        "feat(qinao): declare runtime observation values",
    ),
    (
        "W6",
        "w6.semantic.audit-schema",
        2,
        "feat(qinao): freeze audit projection schema",
    ),
    (
        "W6",
        "w6.runtime.audit-envelope-freeze",
        3,
        "feat(qinao): freeze same-run audit envelope",
    ),
    (
        "W6",
        "w6.semantic.coordinator-behavior",
        4,
        "feat(qinao): add coordinator audit outcome",
    ),
    (
        "W6",
        "w6.runtime.integration-population",
        5,
        "feat(qinao): populate governed runtime integration",
    ),
    (
        "W6",
        "w6.runtime.engine-cutover",
        6,
        "feat(qinao): cut over engine-owned same-run outcome",
    ),
    (
        "W6",
        "w6.apple-lab",
        7,
        "feat(qinao): prove governed Apple lab surfaces",
    ),
    (
        "W6",
        "w6.certification",
        8,
        "test(qinao): certify dual-space automation convergence",
    ),
)

MIGRATION_TERMINAL_FIELDS = {
    "authorizationCoreRoot",
    "baseOwnerLedgerBlobDigest",
    "candidateCommit",
    "candidateTree",
    "challengeConsumptionRoot",
    "challengeDigest",
    "committedAt",
    "controllerTransactionID",
    "evidenceRetentionLeaseRoot",
    "evidenceRetentionLeaseStoredByteLength",
    "evidenceRetentionLeaseStoredSHA256",
    "installedOwnerLedgerGitBlobOID",
    "installedOwnerLedgerPath",
    "installedOwnerLedgerStoredSHA256",
    "jobTerminalRoot",
    "operationAuthorizationRoot",
    "operationID",
    "operationInstanceKey",
    "outcome",
    "policyAuthorizationRoot",
    "predecessorCommit",
    "predecessorReceiptClosureRoot",
    "predecessorReceiptStoredSHA256",
    "predecessorRootReceiptDigest",
    "predecessorTree",
    "preparedRefName",
    "protectedResultStoredByteLength",
    "protectedResultStoredSHA256",
    "refCASResultRoot",
    "refExpectedOldOID",
    "refInstalledOID",
    "repositoryIdentity",
    "resultRowsRoot",
    "runAttemptID",
    "runFinalizationReceiptRoot",
    "runFinalizationReceiptStoredByteLength",
    "runFinalizationReceiptStoredSHA256",
    "schema",
    "state",
    "targetOwnerLedgerBlobDigest",
    "targetProtectedPolicyRoot",
    "targetRefName",
    "terminalRoot",
    "validationPayloadRoot",
}

V2_RECEIPT_FIELDS = admission_runner.RUNTIME_RECEIPT_FIELDS | {
    "fixtureProof",
    "protectedCandidateObservation",
    "protectedCommandPolicy",
    "protectedValidationObservation",
    "targetRefInstallation",
}

TARGET_INSTALLATION_FIELDS = {
    "controllerTransactionID",
    "installedAt",
    "installedCommit",
    "installedTree",
    "operationInstanceKey",
    "outcome",
    "preparedRefDeleteCASResultRoot",
    "preparedRefDisposition",
    "preparedRefName",
    "refCASResultRoot",
    "refExpectedOldOID",
    "refInstalledOID",
    "reopenedOwnerLedgerBlobDigest",
    "state",
    "targetRefName",
}

PROTECTED_CANDIDATE_FIELDS = {
    "admissionKind",
    "admissionStatus",
    "assertionRowsRoot",
    "authorizingOwnerLedgerBlobDigest",
    "baseCommit",
    "baseTree",
    "bootstrapCommit",
    "bootstrapTree",
    "candidateCommit",
    "candidateTree",
    "commandRowsRoot",
    "descendantProfilesRoot",
    "evidenceRetentionDurationSeconds",
    "evidenceRetentionPolicyRoot",
    "externalInputRequirementRowsRoot",
    "hardResourceCapsRoot",
    "kind",
    "operationID",
    "operationInstanceKey",
    "outcome",
    "policyAuthorizationRoot",
    "policyRoot",
    "preparedRefName",
    "refExpectedOldOID",
    "runtimeProfileID",
    "runtimeProfileRoot",
    "targetOwnerLedgerBlobDigest",
    "targetRefName",
    "toolRowsRoot",
    "waveSliceID",
}

PROTECTED_VALIDATION_FIELDS = {
    "admissionKind",
    "assertionCount",
    "assertionResultsRoot",
    "assertionRowsRoot",
    "authorizationCoreRoot",
    "authorizingOwnerLedgerBlobDigest",
    "baseCommit",
    "baseTree",
    "bootstrapCommit",
    "bootstrapTree",
    "candidateCommit",
    "candidateTree",
    "challengeConsumptionRoot",
    "challengeConsumptionStoredByteLength",
    "challengeConsumptionStoredSHA256",
    "challengeDigest",
    "challengeExpiresAt",
    "challengeIssuedAt",
    "commandRowsRoot",
    "commandTerminalRowsRoot",
    "descendantProfilesRoot",
    "evidenceRetentionDurationSeconds",
    "evidenceRetentionLeaseRoot",
    "evidenceRetentionLeaseStoredByteLength",
    "evidenceRetentionLeaseStoredSHA256",
    "evidenceRetentionPolicyRoot",
    "evidenceRowsRoot",
    "externalInputRequirementRowsRoot",
    "externalInputRowsRoot",
    "fencingTokenDigest",
    "finalizingEpoch",
    "hardResourceCapsRoot",
    "jobTerminalRoot",
    "jobTerminalStoredByteLength",
    "jobTerminalStoredSHA256",
    "kind",
    "operationAuthorizationRoot",
    "operationID",
    "operationInstanceKey",
    "outcome",
    "policyAuthorizationRoot",
    "policyRoot",
    "preparedRefName",
    "previousRunControlHeadRoot",
    "refExpectedOldOID",
    "requiredEvidenceRetentionNotBefore",
    "resultObjectRoot",
    "resultRowsRoot",
    "resultStoredByteLength",
    "resultStoredSHA256",
    "runAttemptID",
    "runAuthorizationRoot",
    "runClaimSetRoot",
    "runClaimSetStoredByteLength",
    "runClaimSetStoredSHA256",
    "runContextRoot",
    "runControlKey",
    "runFinalizationReceiptRoot",
    "runFinalizationReceiptStoredByteLength",
    "runFinalizationReceiptStoredSHA256",
    "runtimeProfileID",
    "runtimeProfileRoot",
    "targetOwnerLedgerBlobDigest",
    "targetRefName",
    "toolRowsRoot",
    "validationPayloadRoot",
    "verifiedAt",
    "waveSliceID",
}

HEX_64_FIELDS_MIGRATION = MIGRATION_TERMINAL_FIELDS - {
    "candidateCommit",
    "candidateTree",
    "committedAt",
    "controllerTransactionID",
    "evidenceRetentionLeaseStoredByteLength",
    "installedOwnerLedgerGitBlobOID",
    "installedOwnerLedgerPath",
    "operationID",
    "outcome",
    "predecessorCommit",
    "predecessorTree",
    "preparedRefName",
    "protectedResultStoredByteLength",
    "refExpectedOldOID",
    "refInstalledOID",
    "repositoryIdentity",
    "runAttemptID",
    "runFinalizationReceiptStoredByteLength",
    "schema",
    "state",
    "targetRefName",
}

FORBIDDEN_GIT_ENVIRONMENT = {
    "EMAIL",
    "GIT_ALTERNATE_OBJECT_DIRECTORIES",
    "GIT_ASKPASS",
    "GIT_ATTR_NOSYSTEM",
    "GIT_AUTHOR_DATE",
    "GIT_AUTHOR_EMAIL",
    "GIT_AUTHOR_NAME",
    "GIT_CEILING_DIRECTORIES",
    "GIT_COMMAND_DEBUG",
    "GIT_COMMITTER_DATE",
    "GIT_COMMITTER_EMAIL",
    "GIT_COMMITTER_NAME",
    "GIT_COMMON_DIR",
    "GIT_CONFIG",
    "GIT_CONFIG_COUNT",
    "GIT_CONFIG_GLOBAL",
    "GIT_CONFIG_NOSYSTEM",
    "GIT_CONFIG_SYSTEM",
    "GIT_CONFIG_PARAMETERS",
    "GIT_DEFAULT_HASH",
    "GIT_DIFF_OPTS",
    "GIT_DIR",
    "GIT_DISCOVERY_ACROSS_FILESYSTEM",
    "GIT_EXEC_PATH",
    "GIT_EXTERNAL_DIFF",
    "GIT_FLUSH",
    "GIT_GLOB_PATHSPECS",
    "GIT_ICASE_PATHSPECS",
    "GIT_LITERAL_PATHSPECS",
    "GIT_INDEX_FILE",
    "GIT_NAMESPACE",
    "GIT_NOGLOB_PATHSPECS",
    "GIT_NO_LAZY_FETCH",
    "GIT_NO_REPLACE_OBJECTS",
    "GIT_OBJECT_DIRECTORY",
    "GIT_OPTIONAL_LOCKS",
    "GIT_QUARANTINE_PATH",
    "GIT_REFLOG_ACTION",
    "GIT_REPLACE_REF_BASE",
    "GIT_SHALLOW_FILE",
    "GIT_SSH",
    "GIT_SSH_COMMAND",
    "GIT_WORK_TREE",
    "SSH_ASKPASS",
}
FORBIDDEN_GIT_ENVIRONMENT_PREFIXES = (
    "GIT_CONFIG_KEY_",
    "GIT_CONFIG_VALUE_",
    "GIT_TRACE",
)
ALLOWED_GIT_ENVIRONMENT = {
    "GIT_PAGER": "cat",
    "GIT_TERMINAL_PROMPT": "0",
}
REQUIRED_CLI_OPTIONS = (
    "--root",
    "--git-executable",
    "--source-selection",
    "--trust-root",
    "--previous-receipt",
    "--candidate-tree",
    "--candidate-path-list",
    "--wave",
    "--wave-slice-id",
    "--sequence-ordinal",
    "--commit-message",
)
SIGNING_CONFIG_PATTERN = (
    r"^(commit\.gpgsign|tag\.gpgsign|user\.signingkey|gpg\..*|"
    r"core\.hookspath)$"
)
HOOK_NAMES = {
    "applypatch-msg",
    "commit-msg",
    "fsmonitor-watchman",
    "post-applypatch",
    "post-checkout",
    "post-commit",
    "post-merge",
    "post-receive",
    "post-rewrite",
    "post-update",
    "pre-applypatch",
    "pre-auto-gc",
    "pre-commit",
    "pre-merge-commit",
    "pre-push",
    "pre-rebase",
    "pre-receive",
    "prepare-commit-msg",
    "push-to-checkout",
    "reference-transaction",
    "update",
}


class PreparationError(RuntimeError):
    """One typed preparation failure with a stable process exit code."""

    def __init__(self, message: str, exit_code: int = EXIT_POLICY) -> None:
        super().__init__(message)
        self.exit_code = exit_code


class GitFailure(PreparationError):
    def __init__(self, message: str) -> None:
        super().__init__(message, EXIT_GIT)


class PreparedRefConflict(PreparationError):
    def __init__(self, message: str) -> None:
        super().__init__(message, EXIT_CONFLICT)


def policy_error(message: str) -> None:
    raise PreparationError(message)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__, allow_abbrev=False)
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--git-executable", type=Path, required=True)
    parser.add_argument("--source-selection", type=Path, required=True)
    parser.add_argument("--trust-root", type=Path, required=True)
    parser.add_argument("--previous-receipt", type=Path, required=True)
    parser.add_argument("--candidate-tree", required=True)
    parser.add_argument("--candidate-path-list", type=Path, required=True)
    parser.add_argument("--wave", required=True)
    parser.add_argument("--wave-slice-id", required=True)
    parser.add_argument("--sequence-ordinal", type=int, required=True)
    parser.add_argument("--commit-message", required=True)
    tokens = sys.argv[1:]
    if tokens not in (["-h"], ["--help"]):
        if any(token.startswith("--") and "=" in token for token in tokens):
            parser.error("options and values must be separate argv tokens")
        observed_options = [token for token in tokens if token.startswith("--")]
        unknown = [
            option for option in observed_options if option not in REQUIRED_CLI_OPTIONS
        ]
        if unknown:
            parser.error("unknown or abbreviated option is forbidden: " + unknown[0])
        counts = {
            option: observed_options.count(option) for option in REQUIRED_CLI_OPTIONS
        }
        if any(count != 1 for count in counts.values()):
            parser.error("every required option must occur exactly once")
        if len(tokens) != len(REQUIRED_CLI_OPTIONS) * 2:
            parser.error("every option requires one separate value token")
        if any(
            tokens[index] not in REQUIRED_CLI_OPTIONS
            or tokens[index + 1].startswith("--")
            for index in range(0, len(tokens), 2)
        ):
            parser.error("closed CLI requires exact option/value token pairs")
    return parser.parse_args(tokens)


def reject_unsafe_environment(environment: dict[str, str]) -> None:
    for key, value in environment.items():
        if key in ALLOWED_GIT_ENVIRONMENT:
            if value != ALLOWED_GIT_ENVIRONMENT[key]:
                policy_error(f"unsafe Git environment override {key!r}")
            continue
        if key in FORBIDDEN_GIT_ENVIRONMENT or key.startswith(
            FORBIDDEN_GIT_ENVIRONMENT_PREFIXES
        ):
            policy_error(f"unsafe Git environment override {key!r}")


class BoundGitExecutable:
    """One held executable inode plus its canonical invocation path."""

    def __init__(self, path: Path, descriptor: int, binding: tuple[int, ...]) -> None:
        self.path = path
        self.descriptor = descriptor
        self.binding = binding

    @property
    def parent(self) -> Path:
        return self.path.parent

    def __str__(self) -> str:
        return str(self.path)

    @staticmethod
    def _binding(status: os.stat_result) -> tuple[int, ...]:
        return (
            status.st_dev,
            status.st_ino,
            status.st_mode,
            status.st_nlink,
            status.st_size,
            status.st_mtime_ns,
            status.st_ctime_ns,
        )

    def verify(self) -> None:
        try:
            path_status = self.path.lstat()
            descriptor_status = os.fstat(self.descriptor)
        except OSError as error:
            policy_error(f"--git-executable binding cannot be reopened: {error}")
        if (
            self._binding(path_status) != self.binding
            or self._binding(descriptor_status) != self.binding
        ):
            policy_error("--git-executable changed after its stable binding")

    def close(self) -> None:
        try:
            os.close(self.descriptor)
        except OSError:
            pass


def current_subject_can_write(path: Path) -> bool:
    """Inspect effective-identity write access, failing closed if unavailable."""

    try:
        return os.access(path, os.W_OK, effective_ids=True)
    except (NotImplementedError, OSError, TypeError) as error:
        policy_error(
            "--git-executable effective identity write access for the current "
            f"security subject cannot be inspected: {error}"
        )
    raise AssertionError("unreachable")


def bind_git_executable(argument: Path) -> BoundGitExecutable:
    if not argument.is_absolute():
        policy_error("--git-executable must be absolute")
    try:
        path_status = argument.lstat()
        resolved = argument.resolve(strict=True)
    except OSError as error:
        policy_error(f"--git-executable cannot be resolved: {error}")
    if resolved != argument or stat.S_ISLNK(path_status.st_mode):
        policy_error("--git-executable must be canonical and non-symlink")
    if not stat.S_ISREG(path_status.st_mode):
        policy_error("--git-executable must be a regular file")
    anchored_paths = (argument, *argument.parents)
    for anchored_path in anchored_paths:
        try:
            anchored_status = anchored_path.lstat()
        except OSError as error:
            policy_error(f"--git-executable immutable ancestry cannot be read: {error}")
        expected_kind = stat.S_ISREG if anchored_path == argument else stat.S_ISDIR
        if (
            not expected_kind(anchored_status.st_mode)
            or stat.S_ISLNK(anchored_status.st_mode)
            or anchored_status.st_uid != 0
            or anchored_status.st_mode & 0o022
            or current_subject_can_write(anchored_path)
        ):
            policy_error(
                "--git-executable and every parent must be root-owned and "
                "non-writable by the current security subject"
            )
    if path_status.st_mode & 0o111 == 0 or not os.access(argument, os.X_OK):
        policy_error("--git-executable must be executable")
    if path_status.st_mode & 0o022:
        policy_error("--git-executable must not be group/world writable")
    if not hasattr(os, "O_NOFOLLOW"):
        policy_error("--git-executable cannot be bound without O_NOFOLLOW")
    descriptor: int | None = None
    try:
        descriptor = os.open(
            argument,
            os.O_RDONLY | os.O_CLOEXEC | os.O_NOFOLLOW | os.O_NONBLOCK,
        )
        descriptor_status = os.fstat(descriptor)
    except OSError as error:
        if descriptor is not None:
            os.close(descriptor)
        policy_error(f"--git-executable cannot be stably opened: {error}")
    binding = BoundGitExecutable._binding(path_status)
    if BoundGitExecutable._binding(descriptor_status) != binding:
        os.close(descriptor)
        policy_error("--git-executable path/descriptor binding mismatch")
    return BoundGitExecutable(argument, descriptor, binding)


def safe_git_environment(git_executable: Path) -> dict[str, str]:
    del git_executable
    environment = dict(admission_runner.GIT_SUBPROCESS_ENVIRONMENT)
    environment.pop("PATH", None)
    return environment


def run_git_status(
    git_executable: Path,
    environment: dict[str, str],
    root: Path,
    arguments: list[str],
    *,
    input_bytes: bytes | None = None,
) -> subprocess.CompletedProcess:
    if isinstance(git_executable, BoundGitExecutable):
        git_executable.verify()
    try:
        completed = admission_runner.run_bounded_process(
            [str(git_executable), *arguments],
            cwd=root,
            env=environment,
            timeout_seconds=admission_runner.GIT_TIMEOUT_SECONDS,
            stdout_limit_bytes=admission_runner.GIT_STDOUT_LIMIT_BYTES,
            stderr_limit_bytes=admission_runner.PROCESS_STDERR_LIMIT_BYTES,
            text=False,
            input_bytes=input_bytes,
        )
    except (OSError, subprocess.TimeoutExpired) as error:
        raise GitFailure(
            f"Git command unavailable or timed out ({' '.join(arguments)}): {error}"
        ) from error
    if isinstance(git_executable, BoundGitExecutable):
        git_executable.verify()
    return completed


def run_git(
    git_executable: Path,
    environment: dict[str, str],
    root: Path,
    arguments: list[str],
    *,
    input_bytes: bytes | None = None,
) -> bytes:
    completed = run_git_status(
        git_executable,
        environment,
        root,
        arguments,
        input_bytes=input_bytes,
    )
    if completed.returncode != 0:
        diagnostic = completed.stderr.decode("utf-8", errors="replace").strip()
        raise GitFailure(
            f"Git command failed ({' '.join(arguments)}): "
            f"{diagnostic or f'exit {completed.returncode}'}"
        )
    return completed.stdout


@contextmanager
def isolated_environment(environment: dict[str, str]):
    previous = dict(os.environ)
    os.environ.clear()
    os.environ.update(environment)
    try:
        yield
    finally:
        os.environ.clear()
        os.environ.update(previous)


@contextmanager
def bound_owner_ledger_git(
    git_executable: BoundGitExecutable,
    environment: dict[str, str],
):
    previous = owner_ledger.run_bounded_process

    def run_bound(
        command: list[str],
        *,
        cwd: Path,
        timeout_seconds: float,
        termination_grace_seconds: float = owner_ledger.PROCESS_TERMINATION_GRACE_SECONDS,
        stdout_limit_bytes: int,
        stderr_limit_bytes: int,
        text: bool,
    ) -> subprocess.CompletedProcess:
        if not command or command[0] != "git":
            raise OSError("source-selection validator requested an unbound tool")
        git_executable.verify()
        completed = admission_runner.run_bounded_process(
            [str(git_executable), *command[1:]],
            cwd=cwd,
            env=environment,
            timeout_seconds=timeout_seconds,
            termination_grace_seconds=termination_grace_seconds,
            stdout_limit_bytes=stdout_limit_bytes,
            stderr_limit_bytes=stderr_limit_bytes,
            text=text,
        )
        git_executable.verify()
        return completed

    owner_ledger.run_bounded_process = run_bound
    try:
        yield
    finally:
        owner_ledger.run_bounded_process = previous


@contextmanager
def v2_trust_scope():
    previous = owner_ledger.FROZEN_ROLE_SCHEMA_SCOPES
    owner_ledger.FROZEN_ROLE_SCHEMA_SCOPES = previous | {V2_ROLE_SCOPE}
    try:
        yield
    finally:
        owner_ledger.FROZEN_ROLE_SCHEMA_SCOPES = previous


def strict_ascii_line(raw: bytes, label: str) -> str:
    try:
        value = raw.decode("ascii", errors="strict").strip()
    except UnicodeDecodeError as error:
        policy_error(f"{label} is not ASCII: {error}")
    if not value or any(character.isspace() for character in value):
        policy_error(f"{label} must be one non-whitespace token")
    return value


def object_pattern(object_format: str) -> re.Pattern[str]:
    if object_format == "sha1":
        return re.compile(r"[0-9a-f]{40}")
    if object_format == "sha256":
        return re.compile(r"[0-9a-f]{64}")
    policy_error(f"unsupported Git object format {object_format!r}")
    raise AssertionError("unreachable")


def require_object_id(value: object, label: str, pattern: re.Pattern[str]) -> str:
    if not isinstance(value, str) or pattern.fullmatch(value) is None:
        policy_error(f"{label} must be one full lowercase Git object ID")
    return value


def require_hex64(value: object, label: str) -> str:
    if not isinstance(value, str) or re.fullmatch(r"[0-9a-f]{64}", value) is None:
        policy_error(f"{label} must be one lowercase SHA-256 digest")
    return value


def require_nonempty(value: object, label: str) -> str:
    if not isinstance(value, str) or not value or value.strip() != value:
        policy_error(f"{label} must be a non-empty canonical string")
    if "\x00" in value:
        policy_error(f"{label} must not contain NUL")
    return value


def git_object_type(
    git_executable: Path,
    environment: dict[str, str],
    root: Path,
    object_id: str,
    expected_type: str,
) -> None:
    observed = strict_ascii_line(
        run_git(
            git_executable,
            environment,
            root,
            ["cat-file", "-t", object_id],
        ),
        f"Git object type for {object_id}",
    )
    if observed != expected_type:
        policy_error(
            f"Git object {object_id} must be {expected_type}, found {observed}"
        )


def commit_tree(
    git_executable: Path,
    environment: dict[str, str],
    root: Path,
    commit: str,
    pattern: re.Pattern[str],
) -> str:
    git_object_type(git_executable, environment, root, commit, "commit")
    tree = strict_ascii_line(
        run_git(
            git_executable,
            environment,
            root,
            ["rev-parse", "--verify", "--end-of-options", f"{commit}^{{tree}}"],
        ),
        f"tree for commit {commit}",
    )
    return require_object_id(tree, f"tree for commit {commit}", pattern)


def repository_root(
    argument: Path,
    git_executable: Path,
    environment: dict[str, str],
) -> Path:
    try:
        root = argument.resolve(strict=True)
    except OSError as error:
        policy_error(f"--root cannot be resolved: {error}")
    if not root.is_dir():
        policy_error("--root must be a directory")
    discovered_raw = run_git(
        git_executable,
        environment,
        root,
        ["rev-parse", "--show-toplevel"],
    )
    try:
        discovered = Path(
            discovered_raw.decode("utf-8", errors="strict").strip()
        ).resolve(strict=True)
    except (OSError, UnicodeDecodeError) as error:
        policy_error(f"Git worktree root cannot be resolved: {error}")
    if discovered != root:
        policy_error("--root must name the exact Git worktree root")
    inside = strict_ascii_line(
        run_git(
            git_executable,
            environment,
            root,
            ["rev-parse", "--is-inside-work-tree"],
        ),
        "Git worktree state",
    )
    if inside != "true":
        policy_error("--root must be a non-bare Git worktree")
    return root


def resolve_git_directory(
    git_executable: Path,
    environment: dict[str, str],
    root: Path,
    flag: str,
) -> Path:
    raw = run_git(git_executable, environment, root, ["rev-parse", flag])
    try:
        value = raw.decode("utf-8", errors="strict").strip()
        path = Path(value)
        if not path.is_absolute():
            path = root / path
        return path.resolve(strict=True)
    except (OSError, UnicodeDecodeError) as error:
        policy_error(f"{flag} cannot be resolved: {error}")
    raise AssertionError("unreachable")


def reject_repository_overrides(
    git_executable: Path,
    environment: dict[str, str],
    root: Path,
) -> None:
    shallow = strict_ascii_line(
        run_git(
            git_executable,
            environment,
            root,
            ["rev-parse", "--is-shallow-repository"],
        ),
        "Git shallow state",
    )
    if shallow != "false":
        policy_error("shallow Git history is forbidden")

    replace_refs = run_git(
        git_executable,
        environment,
        root,
        ["for-each-ref", "--format=%(refname)%00", "refs/replace/"],
    )
    if replace_refs.replace(b"\x00", b"").strip():
        policy_error("Git replace refs are forbidden")

    common_directory = resolve_git_directory(
        git_executable,
        environment,
        root,
        "--git-common-dir",
    )
    grafts = common_directory / "info" / "grafts"
    try:
        grafts.lstat()
    except FileNotFoundError:
        pass
    except OSError as error:
        policy_error(f"Git graft state cannot be inspected: {error}")
    else:
        policy_error("Git graft files are forbidden")

    for scope in ("--local", "--worktree"):
        completed = run_git_status(
            git_executable,
            environment,
            root,
            ["config", scope, "--name-only", "--get-regexp", SIGNING_CONFIG_PATTERN],
        )
        if completed.returncode == 0 and completed.stdout.strip():
            policy_error("Git signing or hooksPath configuration is forbidden")
        if completed.returncode not in {0, 1}:
            diagnostic = completed.stderr.decode("utf-8", errors="replace").strip()
            if scope == "--worktree" and "worktreeConfig" in diagnostic:
                continue
            raise GitFailure(
                f"Git configuration inspection failed ({scope}): "
                f"{diagnostic or completed.returncode}"
            )

    hooks = common_directory / "hooks"
    try:
        hook_directory_status = hooks.lstat()
    except FileNotFoundError:
        return
    except OSError as error:
        policy_error(f"Git hook directory cannot be inspected: {error}")
    if stat.S_ISLNK(hook_directory_status.st_mode):
        policy_error("Git hook directory must not be a symlink")
    try:
        entries = list(os.scandir(hooks))
    except OSError as error:
        policy_error(f"Git hook directory cannot be read: {error}")
    for entry in entries:
        if entry.name in HOOK_NAMES:
            policy_error(f"Git hook {entry.name!r} is forbidden")


def load_external_documents(
    root: Path,
    source_argument: Path,
    trust_argument: Path,
    receipt_argument: Path,
) -> tuple[bytes, dict, bytes, dict, bytes, dict]:
    bindings: list[tuple[Path, tuple[int, int]]] = []
    loaded: list[tuple[bytes, dict]] = []
    for argument, label in (
        (source_argument, "source selection"),
        (trust_argument, "trust root"),
        (receipt_argument, "previous receipt"),
    ):
        try:
            path, raw, identity = admission_runner.external_file_bytes(
                argument,
                root,
                label,
            )
            document = admission_runner.load_json_bytes(raw, label)
        except admission_runner.GateError as error:
            policy_error(str(error))
        if any(
            path == prior_path or identity == prior_identity
            for prior_path, prior_identity in bindings
        ):
            policy_error(
                "source selection, trust root, and previous receipt must be distinct"
            )
        bindings.append((path, identity))
        loaded.append((raw, document))
    return (
        loaded[0][0],
        loaded[0][1],
        loaded[1][0],
        loaded[1][1],
        loaded[2][0],
        loaded[2][1],
    )


def document_time(document: dict, field: str, label: str) -> datetime:
    value, error = owner_ledger.parse_utc_timestamp(
        document.get(field), f"{label} {field}"
    )
    if error is not None or value is None:
        policy_error(error or f"{label} {field} is invalid")
    return value


def validate_selection_and_trust(
    root: Path,
    git_executable: BoundGitExecutable,
    environment: dict[str, str],
    source_selection: dict,
    trust_root: dict,
) -> None:
    verification_time = document_time(
        source_selection,
        "issuedAt",
        "source selection",
    )
    with (
        v2_trust_scope(),
        isolated_environment(environment),
        bound_owner_ledger_git(git_executable, environment),
    ):
        trust_errors = owner_ledger.validate_trust_root(
            trust_root,
            verification_time=verification_time,
        )
        if trust_errors:
            policy_error("; ".join(trust_errors))
        source_errors = owner_ledger.validate_source_selection(
            source_selection,
            trust_root,
            root=root,
            verification_time=verification_time,
        )
        if source_errors:
            policy_error("; ".join(source_errors))


def migration_terminal_root(document: dict) -> str:
    unsigned = dict(document)
    unsigned.pop("terminalRoot", None)
    try:
        canonical = owner_ledger.canonical_json_bytes(unsigned)
    except ValueError as error:
        policy_error(f"migration terminal cannot be canonicalized: {error}")
    return hashlib.sha256(TERMINAL_ROOT_DOMAIN + canonical).hexdigest()


def read_tree_blob(
    git_executable: Path,
    environment: dict[str, str],
    root: Path,
    tree: str,
    relative_path: str,
    pattern: re.Pattern[str],
    label: str,
) -> tuple[str, bytes]:
    listing = run_git(
        git_executable,
        environment,
        root,
        ["ls-tree", "-z", "--full-tree", tree, "--", relative_path],
    )
    records = [record for record in listing.split(b"\x00") if record]
    if len(records) != 1:
        policy_error(f"{label} must exist exactly once in tree {tree}")
    try:
        metadata, encoded_path = records[0].split(b"\t", 1)
        mode, object_type, object_id = metadata.decode("ascii").split(" ")
        observed_path = encoded_path.decode("utf-8", errors="strict")
    except (UnicodeDecodeError, ValueError) as error:
        policy_error(f"{label} tree entry is malformed: {error}")
    if (
        observed_path != relative_path
        or mode not in {"100644", "100755"}
        or object_type != "blob"
    ):
        policy_error(f"{label} must be one regular Git blob at the exact path")
    require_object_id(object_id, f"{label} blob", pattern)
    raw = run_git(
        git_executable,
        environment,
        root,
        ["cat-file", "blob", object_id],
    )
    return object_id, raw


def validate_migration_terminal(
    document: dict,
    *,
    repository_identity: str,
    git_executable: Path,
    environment: dict[str, str],
    root: Path,
    pattern: re.Pattern[str],
) -> tuple[str, str, str]:
    if set(document) != MIGRATION_TERMINAL_FIELDS:
        policy_error("migration predecessor fields do not match the closed schema")
    if (
        document.get("schema") != "QinaoLedgerV2MigrationTerminalReceiptV1"
        or document.get("repositoryIdentity") != repository_identity
        or document.get("operationID") != "bootstrap.ledger-v2-migration"
        or document.get("state") != "installed"
        or document.get("outcome") != "passed"
        or document.get("targetRefName") != TARGET_REF
    ):
        policy_error("migration predecessor identity/state/outcome mismatch")
    for field in sorted(HEX_64_FIELDS_MIGRATION):
        require_hex64(document.get(field), f"migration predecessor {field}")
    for field in (
        "protectedResultStoredByteLength",
        "evidenceRetentionLeaseStoredByteLength",
        "runFinalizationReceiptStoredByteLength",
    ):
        value = document.get(field)
        if type(value) is not int or value < 1:
            policy_error(f"migration predecessor {field} must be positive")
    for field in (
        "controllerTransactionID",
        "operationInstanceKey",
        "preparedRefName",
        "runAttemptID",
    ):
        require_nonempty(document.get(field), f"migration predecessor {field}")
    migration_prepared_ref = document["preparedRefName"]
    if (
        not migration_prepared_ref.startswith("refs/qinao/prepared/")
        or run_git_status(
            git_executable,
            environment,
            root,
            ["check-ref-format", migration_prepared_ref],
        ).returncode
        != 0
    ):
        policy_error("migration predecessor preparedRefName is invalid")
    document_time(document, "committedAt", "migration predecessor")
    if document.get("terminalRoot") != migration_terminal_root(document):
        policy_error("migration predecessor terminalRoot mismatch")

    predecessor_commit = require_object_id(
        document.get("predecessorCommit"),
        "migration predecessor predecessorCommit",
        pattern,
    )
    predecessor_tree = require_object_id(
        document.get("predecessorTree"),
        "migration predecessor predecessorTree",
        pattern,
    )
    base_commit = require_object_id(
        document.get("candidateCommit"),
        "migration predecessor candidateCommit",
        pattern,
    )
    base_tree = require_object_id(
        document.get("candidateTree"),
        "migration predecessor candidateTree",
        pattern,
    )
    if (
        commit_tree(git_executable, environment, root, predecessor_commit, pattern)
        != predecessor_tree
    ):
        policy_error("migration predecessor commit/tree binding mismatch")
    if (
        commit_tree(git_executable, environment, root, base_commit, pattern)
        != base_tree
    ):
        policy_error("migration installed candidate commit/tree binding mismatch")
    if (
        document.get("refExpectedOldOID") != predecessor_commit
        or document.get("refInstalledOID") != base_commit
    ):
        policy_error("migration predecessor ref installation binding mismatch")

    ledger_path = document.get("installedOwnerLedgerPath")
    if not owner_ledger.is_normalized_workspace_path(ledger_path):
        policy_error("migration predecessor installed Owner Ledger path is invalid")
    ledger_blob, ledger_raw = read_tree_blob(
        git_executable,
        environment,
        root,
        base_tree,
        ledger_path,
        pattern,
        "migration installed Owner Ledger",
    )
    if ledger_blob != document.get("installedOwnerLedgerGitBlobOID") or hashlib.sha256(
        ledger_raw
    ).hexdigest() != document.get("installedOwnerLedgerStoredSHA256"):
        policy_error("migration predecessor installed Owner Ledger binding mismatch")
    return TARGET_REF, base_commit, base_tree


def expected_predecessor(row: tuple[str, str, int, str]) -> tuple[str, str, int] | None:
    index = V2_ROWS.index(row)
    if index == 0:
        return None
    previous = V2_ROWS[index - 1]
    return previous[0], previous[1], previous[2]


def validate_v2_receipt(
    document: dict,
    *,
    expected: tuple[str, str, int],
    repository_identity: str,
    source_selection: dict,
    source_raw: bytes,
    trust_root: dict,
    trust_raw: bytes,
    git_executable: Path,
    environment: dict[str, str],
    root: Path,
    pattern: re.Pattern[str],
) -> tuple[str, str, str]:
    if set(document) != V2_RECEIPT_FIELDS:
        policy_error("Wave V2 predecessor fields do not match the closed schema")
    if (
        document.get("schema") != "QinaoWaveAdmissionReceiptV2"
        or document.get("repositoryIdentity") != repository_identity
        or document.get("role") != "wave-admission-signer"
        or document.get("outcome") != "admitted"
        or (
            document.get("wave"),
            document.get("waveSliceID"),
            document.get("sequenceOrdinal"),
        )
        != expected
        or document.get("sourceSelectionBlobDigest")
        != hashlib.sha256(source_raw).hexdigest()
        or document.get("trustRootBlobDigest") != hashlib.sha256(trust_raw).hexdigest()
    ):
        policy_error("Wave V2 predecessor identity/schedule/outcome mismatch")
    verified_at = document_time(document, "verifiedAt", "Wave V2 predecessor")
    with v2_trust_scope(), isolated_environment(environment):
        trust_errors = owner_ledger.validate_trust_root(
            trust_root,
            verification_time=verified_at,
        )
        if trust_errors:
            policy_error("; ".join(trust_errors))
        signature_errors = owner_ledger.validate_signed_document(
            document,
            trust_root,
            expected_role="wave-admission-signer",
            expected_schema_scope="QinaoWaveAdmissionReceiptV2",
            label="Wave V2 predecessor",
            verification_time=verified_at,
        )
        if signature_errors:
            policy_error("; ".join(signature_errors))
        try:
            admission_runner.validate_receipt_time_relationships(
                document,
                label="Wave V2 predecessor",
                trust_root=trust_root,
                inputs=[("source selection", source_selection)],
            )
        except admission_runner.GateError as error:
            policy_error(str(error))

    receipt_base_commit = require_object_id(
        document.get("baseCommit"),
        "Wave V2 predecessor baseCommit",
        pattern,
    )
    receipt_base_tree = require_object_id(
        document.get("baseTree"),
        "Wave V2 predecessor baseTree",
        pattern,
    )
    receipt_candidate_tree = require_object_id(
        document.get("candidateTree"),
        "Wave V2 predecessor candidateTree",
        pattern,
    )
    if (
        commit_tree(
            git_executable,
            environment,
            root,
            receipt_base_commit,
            pattern,
        )
        != receipt_base_tree
    ):
        policy_error("Wave V2 predecessor base commit/tree binding mismatch")
    for field in (
        "approvedDesignBlob",
        "bundleBlobDigest",
        "previousReceiptBlobDigest",
        "productionDiffRoot",
        "sourceSelectionBlobDigest",
        "trustRootBlobDigest",
    ):
        require_hex64(document.get(field), f"Wave V2 predecessor {field}")
    path_list = document.get("pathList")
    if (
        not isinstance(path_list, dict)
        or set(path_list) != {"count", "root"}
        or type(path_list.get("count")) is not int
        or path_list["count"] < 1
    ):
        policy_error("Wave V2 predecessor pathList fields/count mismatch")
    require_hex64(path_list.get("root"), "Wave V2 predecessor pathList root")
    owner_ledger_binding = document.get("ownerLedger")
    if (
        not isinstance(owner_ledger_binding, dict)
        or set(owner_ledger_binding) != admission_runner.OWNER_LEDGER_FIELDS
        or owner_ledger_binding.get("path")
        != "docs/superpowers/specs/qinao-owner-ledger-v1.json"
    ):
        policy_error("Wave V2 predecessor Owner Ledger binding mismatch")
    require_hex64(
        owner_ledger_binding.get("blobDigest"),
        "Wave V2 predecessor Owner Ledger blobDigest",
    )
    categories = document.get("categories")
    if not isinstance(categories, dict) or set(categories) != set(
        admission_runner.CATEGORIES
    ):
        policy_error("Wave V2 predecessor categories fields mismatch")
    for category in admission_runner.CATEGORIES:
        binding = categories[category]
        if (
            not isinstance(binding, dict)
            or set(binding) != admission_runner.VERIFIED_CATEGORY_FIELDS
            or binding.get("status") not in {"present", "notApplicable"}
            or type(binding.get("rowCount")) is not int
            or binding["rowCount"] < 0
        ):
            policy_error(f"Wave V2 predecessor {category} category mismatch")
        require_hex64(
            binding.get("blobDigest"),
            f"Wave V2 predecessor {category} blobDigest",
        )
        require_hex64(
            binding.get("reviewedRowsRoot"),
            f"Wave V2 predecessor {category} reviewedRowsRoot",
        )
    for field in (
        "evidencePrerequisites",
        "externalPrerequisites",
        "frozenSchemaDigests",
    ):
        if not isinstance(document.get(field), list):
            policy_error(f"Wave V2 predecessor {field} must be an array")
    tool_blobs = document.get("toolBlobs")
    if (
        not isinstance(tool_blobs, dict)
        or set(tool_blobs) != admission_runner.TOOL_BLOBS_FIELDS
    ):
        policy_error("Wave V2 predecessor toolBlobs fields mismatch")
    for field in (
        "bundleReviewSigningProvider",
        "externalVerifier",
        "waveAdmissionSigningProvider",
    ):
        require_hex64(tool_blobs.get(field), f"Wave V2 predecessor toolBlobs.{field}")
    for field, expected_path in (
        ("ownerLedgerChecker", "scripts/check_qinao_owner_ledger.py"),
        ("repositoryRunner", "scripts/run_qinao_wave_admission.py"),
    ):
        binding = tool_blobs.get(field)
        if (
            not isinstance(binding, dict)
            or set(binding) != admission_runner.LOCATED_TOOL_FIELDS
            or binding.get("path") != expected_path
        ):
            policy_error(f"Wave V2 predecessor toolBlobs.{field} mismatch")
        require_hex64(
            binding.get("blobDigest"),
            f"Wave V2 predecessor toolBlobs.{field}.blobDigest",
        )

    installation = document.get("targetRefInstallation")
    if (
        not isinstance(installation, dict)
        or set(installation) != TARGET_INSTALLATION_FIELDS
    ):
        policy_error("Wave V2 predecessor targetRefInstallation fields mismatch")
    installed_commit = require_object_id(
        installation.get("installedCommit"),
        "Wave V2 installed commit",
        pattern,
    )
    installed_tree = require_object_id(
        installation.get("installedTree"),
        "Wave V2 installed tree",
        pattern,
    )
    if (
        installation.get("targetRefName") != TARGET_REF
        or installation.get("refExpectedOldOID") != receipt_base_commit
        or installation.get("refInstalledOID") != installed_commit
        or installation.get("preparedRefDisposition") != "deleted"
        or installation.get("state") != "installed"
        or installation.get("outcome") != "passed"
        or receipt_candidate_tree != installed_tree
        or commit_tree(git_executable, environment, root, installed_commit, pattern)
        != installed_tree
    ):
        policy_error("Wave V2 predecessor installation terminal mismatch")
    for field in (
        "refCASResultRoot",
        "preparedRefDeleteCASResultRoot",
        "reopenedOwnerLedgerBlobDigest",
    ):
        require_hex64(installation.get(field), f"Wave V2 installation {field}")
    require_hex64(
        installation.get("operationInstanceKey"),
        "Wave V2 installation operationInstanceKey",
    )
    for field in ("controllerTransactionID", "preparedRefName"):
        require_nonempty(installation.get(field), f"Wave V2 installation {field}")
    prior_prepared_ref = installation["preparedRefName"]
    if (
        not prior_prepared_ref.startswith(PREPARED_REF_PREFIX)
        or run_git_status(
            git_executable,
            environment,
            root,
            ["check-ref-format", prior_prepared_ref],
        ).returncode
        != 0
    ):
        policy_error("Wave V2 installation preparedRefName is invalid")
    if (
        ref_oid_if_present(
            git_executable,
            environment,
            root,
            prior_prepared_ref,
            pattern,
        )
        is not None
    ):
        policy_error("Wave V2 predecessor prepared ref was not retired")
    document_time(installation, "installedAt", "Wave V2 installation")

    candidate = document.get("protectedCandidateObservation")
    validation = document.get("protectedValidationObservation")
    policy = document.get("protectedCommandPolicy")
    fixture_proof = document.get("fixtureProof")
    if not isinstance(candidate, dict) or set(candidate) != PROTECTED_CANDIDATE_FIELDS:
        policy_error("Wave V2 protectedCandidateObservation fields mismatch")
    if (
        not isinstance(validation, dict)
        or set(validation) != PROTECTED_VALIDATION_FIELDS
    ):
        policy_error("Wave V2 protectedValidationObservation fields mismatch")
    if not isinstance(policy, dict) or set(policy) != {
        "authorizingOwnerLedgerBlobDigest",
        "policyRoot",
        "targetOwnerLedgerBlobDigest",
    }:
        policy_error("Wave V2 protectedCommandPolicy fields mismatch")
    if (
        not isinstance(fixture_proof, dict)
        or set(fixture_proof) != {"count", "root"}
        or type(fixture_proof.get("count")) is not int
        or fixture_proof["count"] < 0
    ):
        policy_error("Wave V2 fixtureProof fields mismatch")
    require_hex64(fixture_proof.get("root"), "Wave V2 fixtureProof root")
    for field in (
        "authorizingOwnerLedgerBlobDigest",
        "policyRoot",
        "targetOwnerLedgerBlobDigest",
    ):
        require_hex64(policy.get(field), f"Wave V2 protectedCommandPolicy {field}")
    if (
        candidate.get("kind") != "productionCandidate"
        or candidate.get("admissionStatus") != "unadmitted"
        or candidate.get("outcome") != "candidateReady"
        or validation.get("kind") != "productionWave"
        or validation.get("outcome") != "passed"
        or candidate.get("candidateCommit") != installed_commit
        or candidate.get("candidateTree") != installed_tree
        or validation.get("candidateCommit") != installed_commit
        or validation.get("candidateTree") != installed_tree
        or candidate.get("baseCommit") != receipt_base_commit
        or candidate.get("baseTree") != receipt_base_tree
        or validation.get("baseCommit") != receipt_base_commit
        or validation.get("baseTree") != receipt_base_tree
        or candidate.get("targetRefName") != TARGET_REF
        or validation.get("targetRefName") != TARGET_REF
        or candidate.get("preparedRefName") != installation.get("preparedRefName")
        or validation.get("preparedRefName") != installation.get("preparedRefName")
        or candidate.get("refExpectedOldOID") != receipt_base_commit
        or validation.get("refExpectedOldOID") != receipt_base_commit
        or candidate.get("operationInstanceKey")
        != installation.get("operationInstanceKey")
        or validation.get("operationInstanceKey")
        != installation.get("operationInstanceKey")
        or candidate.get("waveSliceID") != expected[1]
        or validation.get("waveSliceID") != expected[1]
        or candidate.get("policyRoot") != policy.get("policyRoot")
        or validation.get("policyRoot") != policy.get("policyRoot")
        or candidate.get("authorizingOwnerLedgerBlobDigest")
        != policy.get("authorizingOwnerLedgerBlobDigest")
        or validation.get("authorizingOwnerLedgerBlobDigest")
        != policy.get("authorizingOwnerLedgerBlobDigest")
        or candidate.get("targetOwnerLedgerBlobDigest")
        != policy.get("targetOwnerLedgerBlobDigest")
        or validation.get("targetOwnerLedgerBlobDigest")
        != policy.get("targetOwnerLedgerBlobDigest")
        or installation.get("reopenedOwnerLedgerBlobDigest")
        != policy.get("targetOwnerLedgerBlobDigest")
    ):
        policy_error("Wave V2 protected observation/installation binding mismatch")
    return TARGET_REF, installed_commit, installed_tree


def validate_predecessor(
    document: dict,
    *,
    row: tuple[str, str, int, str],
    repository_identity: str,
    source_selection: dict,
    source_raw: bytes,
    trust_root: dict,
    trust_raw: bytes,
    git_executable: Path,
    environment: dict[str, str],
    root: Path,
    pattern: re.Pattern[str],
) -> tuple[str, str, str]:
    predecessor = expected_predecessor(row)
    if predecessor is None:
        if document.get("schema") != "QinaoLedgerV2MigrationTerminalReceiptV1":
            policy_error(
                "W1 predecessor must be the verified Ledger-V2 migration terminal"
            )
        return validate_migration_terminal(
            document,
            repository_identity=repository_identity,
            git_executable=git_executable,
            environment=environment,
            root=root,
            pattern=pattern,
        )
    if document.get("schema") != "QinaoWaveAdmissionReceiptV2":
        policy_error("later Wave predecessor must be the exact prior Wave V2 receipt")
    return validate_v2_receipt(
        document,
        expected=predecessor,
        repository_identity=repository_identity,
        source_selection=source_selection,
        source_raw=source_raw,
        trust_root=trust_root,
        trust_raw=trust_raw,
        git_executable=git_executable,
        environment=environment,
        root=root,
        pattern=pattern,
    )


def validate_schedule(args: argparse.Namespace) -> tuple[str, str, int, str]:
    candidate = (
        args.wave,
        args.wave_slice_id,
        args.sequence_ordinal,
        args.commit_message,
    )
    if candidate not in V2_ROWS:
        matching_identity = [
            row
            for row in V2_ROWS
            if row[:3] == (args.wave, args.wave_slice_id, args.sequence_ordinal)
        ]
        if matching_identity:
            policy_error("--commit-message does not equal the closed slice message")
        policy_error("wave/slice/ordinal is not on the closed Wave V2 schedule")
    return candidate


def current_ref_oid(
    git_executable: Path,
    environment: dict[str, str],
    root: Path,
    ref_name: str,
    pattern: re.Pattern[str],
) -> str:
    value = strict_ascii_line(
        run_git(
            git_executable,
            environment,
            root,
            ["rev-parse", "--verify", "--end-of-options", f"{ref_name}^{{commit}}"],
        ),
        f"OID for {ref_name}",
    )
    return require_object_id(value, f"OID for {ref_name}", pattern)


def validate_target_and_head(
    git_executable: Path,
    environment: dict[str, str],
    root: Path,
    target_ref: str,
    base_commit: str,
    base_tree: str,
    pattern: re.Pattern[str],
) -> None:
    if target_ref != TARGET_REF:
        policy_error("predecessor target ref is not the fixed protected target")
    symbolic = run_git_status(
        git_executable,
        environment,
        root,
        ["symbolic-ref", "-q", "HEAD"],
    )
    if symbolic.returncode != 0:
        policy_error("HEAD must be attached to the inherited full target ref")
    try:
        head_ref = symbolic.stdout.decode("ascii", errors="strict").strip()
    except UnicodeDecodeError as error:
        policy_error(f"HEAD symbolic ref is malformed: {error}")
    if head_ref != target_ref:
        policy_error("targetRef must equal the full symbolic HEAD ref")
    target_symbolic = run_git_status(
        git_executable,
        environment,
        root,
        ["symbolic-ref", "-q", target_ref],
    )
    if target_symbolic.returncode == 0:
        policy_error("protected target must not be a symbolic-ref chain")
    if target_symbolic.returncode not in {1}:
        raise GitFailure("protected target symbolic-ref inspection failed")
    if (
        current_ref_oid(git_executable, environment, root, target_ref, pattern)
        != base_commit
    ):
        policy_error(
            "target-ref OID does not equal the verified predecessor base commit"
        )
    if (
        current_ref_oid(git_executable, environment, root, "HEAD", pattern)
        != base_commit
    ):
        policy_error("HEAD OID does not equal the verified predecessor base commit")
    if (
        commit_tree(git_executable, environment, root, base_commit, pattern)
        != base_tree
    ):
        policy_error("verified predecessor base commit/tree binding mismatch")


def repository_relative_path(argument: Path, root: Path, label: str) -> str:
    try:
        parent = argument.parent.resolve(strict=True)
        path = parent / argument.name
        relative = path.relative_to(root).as_posix()
        status = path.lstat()
    except (OSError, ValueError) as error:
        policy_error(f"{label} must resolve inside the exact repository: {error}")
    if not stat.S_ISREG(status.st_mode) or stat.S_ISLNK(status.st_mode):
        policy_error(f"{label} must be a regular non-symlink file")
    if not owner_ledger.is_normalized_workspace_path(relative):
        policy_error(f"{label} path is not normalized")
    return relative


def parse_path_list(raw: bytes, list_path: str) -> list[str]:
    if not raw or len(raw) > 8 * 1024 * 1024 or not raw.endswith(b"\n"):
        policy_error(
            "candidate path-list must be non-empty, bounded, and LF-terminated"
        )
    try:
        text = raw.decode("utf-8", errors="strict")
    except UnicodeDecodeError as error:
        policy_error(f"candidate path-list is not UTF-8: {error}")
    paths = text.removesuffix("\n").split("\n")
    if any(not owner_ledger.is_normalized_workspace_path(path) for path in paths):
        policy_error("candidate path-list contains a non-normalized path")
    if len(paths) != len(set(paths)):
        policy_error("candidate path-list contains duplicate paths")
    if paths != sorted(paths, key=lambda value: value.encode("utf-8")):
        policy_error("candidate path-list must be UTF-8 byte sorted")
    if list_path not in paths:
        policy_error("candidate path-list must include its own staged path")
    return paths


def decode_nul_paths(raw: bytes, label: str) -> list[str]:
    if raw and not raw.endswith(b"\x00"):
        policy_error(f"{label} did not produce a NUL-terminated path set")
    paths: list[str] = []
    for encoded in raw.split(b"\x00"):
        if not encoded:
            continue
        try:
            path = encoded.decode("utf-8", errors="strict")
        except UnicodeDecodeError as error:
            policy_error(f"{label} contains a non-UTF-8 path: {error}")
        if not owner_ledger.is_normalized_workspace_path(path):
            policy_error(f"{label} contains a non-normalized path")
        paths.append(path)
    if len(paths) != len(set(paths)):
        policy_error(f"{label} contains duplicate paths")
    return paths


def validate_object_closure(
    git_executable: Path,
    environment: dict[str, str],
    root: Path,
    base_commit: str,
    trees: tuple[str, ...],
    pattern: re.Pattern[str],
) -> None:
    history = run_git(
        git_executable,
        environment,
        root,
        ["rev-list", "--objects", "--missing=print", "--no-object-names", base_commit],
    )
    for line in history.splitlines():
        if line.startswith(b"?"):
            policy_error("base history contains a missing Git object")
        try:
            object_id = line.decode("ascii", errors="strict")
        except UnicodeDecodeError as error:
            policy_error(f"base history contains a malformed object ID: {error}")
        require_object_id(object_id, "base history object", pattern)

    checked_blobs: set[str] = set()
    for tree in trees:
        git_object_type(git_executable, environment, root, tree, "tree")
        listing = run_git(
            git_executable,
            environment,
            root,
            ["ls-tree", "-r", "-z", "--full-tree", tree],
        )
        if listing and not listing.endswith(b"\x00"):
            policy_error("Git tree traversal did not produce NUL-terminated rows")
        for record in listing.split(b"\x00"):
            if not record:
                continue
            try:
                metadata, _path = record.split(b"\t", 1)
                _mode, object_type, object_id = metadata.decode("ascii").split(" ")
            except (UnicodeDecodeError, ValueError) as error:
                policy_error(f"Git tree traversal row is malformed: {error}")
            require_object_id(object_id, "Git tree entry object", pattern)
            if object_type == "blob":
                checked_blobs.add(object_id)
            elif object_type != "commit":
                policy_error(f"Git tree entry type {object_type!r} is unsupported")
    for blob in sorted(checked_blobs):
        git_object_type(git_executable, environment, root, blob, "blob")


def validate_candidate_state(
    args: argparse.Namespace,
    *,
    git_executable: Path,
    environment: dict[str, str],
    root: Path,
    base_commit: str,
    base_tree: str,
    pattern: re.Pattern[str],
) -> tuple[str, list[str]]:
    candidate_tree = require_object_id(
        args.candidate_tree,
        "--candidate-tree",
        pattern,
    )
    git_object_type(git_executable, environment, root, candidate_tree, "tree")
    if run_git(git_executable, environment, root, ["ls-files", "-u", "-z"]):
        policy_error("Git index contains unresolved entries")
    index_tree = strict_ascii_line(
        run_git(git_executable, environment, root, ["write-tree"]),
        "Git index tree",
    )
    require_object_id(index_tree, "Git index tree", pattern)
    if index_tree != candidate_tree:
        policy_error("Git index tree does not equal --candidate-tree")

    path_list_relative = repository_relative_path(
        args.candidate_path_list,
        root,
        "--candidate-path-list",
    )
    _blob, path_list_raw = read_tree_blob(
        git_executable,
        environment,
        root,
        candidate_tree,
        path_list_relative,
        pattern,
        "candidate path-list",
    )
    paths = parse_path_list(path_list_raw, path_list_relative)
    expected = set(paths)
    tree_paths = set(
        decode_nul_paths(
            run_git(
                git_executable,
                environment,
                root,
                [
                    "diff-tree",
                    "--no-commit-id",
                    "--name-only",
                    "-r",
                    "-z",
                    "--no-renames",
                    base_tree,
                    candidate_tree,
                    "--",
                ],
            ),
            "candidate tree diff",
        )
    )
    staged_paths = set(
        decode_nul_paths(
            run_git(
                git_executable,
                environment,
                root,
                [
                    "diff",
                    "--cached",
                    "--name-only",
                    "-z",
                    "--no-renames",
                    base_commit,
                    "--",
                ],
            ),
            "staged path set",
        )
    )
    if expected != tree_paths or expected != staged_paths:
        policy_error(
            "candidate path-list, candidate-tree diff, and staged path set must agree"
        )

    unstaged = set(
        decode_nul_paths(
            run_git(
                git_executable,
                environment,
                root,
                ["diff-files", "--name-only", "-z", "--"],
            ),
            "unstaged path set",
        )
    )
    untracked = set(
        decode_nul_paths(
            run_git(
                git_executable,
                environment,
                root,
                ["ls-files", "--others", "--exclude-standard", "-z", "--"],
            ),
            "untracked path set",
        )
    )
    dirty_candidate_paths = expected & (unstaged | untracked)
    if dirty_candidate_paths:
        policy_error(
            "candidate set contains unstaged or untracked paths: "
            + ", ".join(sorted(dirty_candidate_paths))
        )
    validate_object_closure(
        git_executable,
        environment,
        root,
        base_commit,
        (base_tree, candidate_tree),
        pattern,
    )
    return candidate_tree, paths


def base_committer_timestamp(raw: bytes) -> int:
    header, separator, _message = raw.partition(b"\n\n")
    if not separator:
        policy_error("base commit object has no message separator")
    committer_rows = [
        row for row in header.splitlines() if row.startswith(b"committer ")
    ]
    if len(committer_rows) != 1:
        policy_error("base commit must contain exactly one committer header")
    match = re.search(rb" ([0-9]+) [+-][0-9]{4}$", committer_rows[0])
    if match is None:
        policy_error("base commit committer timestamp is malformed")
    timestamp = int(match.group(1))
    if timestamp >= 2**63 - 1:
        policy_error("base commit committer timestamp cannot be incremented")
    return timestamp


def canonical_commit_bytes(
    candidate_tree: str,
    base_commit: str,
    timestamp: int,
    message: str,
) -> bytes:
    try:
        message_bytes = message.encode("utf-8", errors="strict")
    except UnicodeEncodeError as error:
        policy_error(f"commit message is not UTF-8: {error}")
    if b"\x00" in message_bytes or b"\n" in message_bytes or b"\r" in message_bytes:
        policy_error("closed commit message must be one NUL/CR/LF-free line")
    return (
        (
            f"tree {candidate_tree}\n"
            f"parent {base_commit}\n"
            f"author {COMMIT_IDENTITY} {timestamp} +0000\n"
            f"committer {COMMIT_IDENTITY} {timestamp} +0000\n"
            "\n"
        ).encode("ascii")
        + message_bytes
        + b"\n"
    )


def prepared_ref_name(
    repository_identity: str,
    target_ref: str,
    row: tuple[str, str, int, str],
    base_commit: str,
    candidate_tree: str,
) -> str:
    identity = [
        repository_identity,
        target_ref,
        row[1],
        row[2],
        base_commit,
        candidate_tree,
    ]
    try:
        encoded = owner_ledger.canonical_json_bytes(identity)
    except ValueError as error:
        policy_error(f"prepared-ref identity cannot be canonicalized: {error}")
    return PREPARED_REF_PREFIX + hashlib.sha256(encoded).hexdigest()


def ref_oid_if_present(
    git_executable: Path,
    environment: dict[str, str],
    root: Path,
    ref_name: str,
    pattern: re.Pattern[str],
) -> str | None:
    existence = run_git_status(
        git_executable,
        environment,
        root,
        ["show-ref", "--verify", "--quiet", ref_name],
    )
    if existence.returncode == 1:
        return None
    if existence.returncode != 0:
        diagnostic = existence.stderr.decode("utf-8", errors="replace").strip()
        raise GitFailure(
            f"prepared ref inspection failed: {diagnostic or existence.returncode}"
        )
    completed = run_git_status(
        git_executable,
        environment,
        root,
        ["show-ref", "--verify", "--hash", ref_name],
    )
    if completed.returncode != 0:
        diagnostic = completed.stderr.decode("utf-8", errors="replace").strip()
        raise GitFailure(
            f"prepared ref changed during inspection: "
            f"{diagnostic or completed.returncode}"
        )
    return require_object_id(
        strict_ascii_line(completed.stdout, "prepared ref OID"),
        "prepared ref OID",
        pattern,
    )


def reopen_exact_prepared_commit(
    git_executable: Path,
    environment: dict[str, str],
    root: Path,
    prepared_ref: str,
    expected_oid: str,
    expected_bytes: bytes,
    pattern: re.Pattern[str],
) -> None:
    observed_oid = ref_oid_if_present(
        git_executable,
        environment,
        root,
        prepared_ref,
        pattern,
    )
    if observed_oid != expected_oid:
        raise PreparedRefConflict(
            "prepared ref already exists with a conflicting candidate commit"
        )
    git_object_type(git_executable, environment, root, observed_oid, "commit")
    observed_bytes = run_git(
        git_executable,
        environment,
        root,
        ["cat-file", "commit", observed_oid],
    )
    if observed_bytes != expected_bytes:
        raise PreparedRefConflict(
            "prepared ref commit metadata does not equal the deterministic candidate"
        )


def prepare_commit_and_ref(
    *,
    git_executable: Path,
    environment: dict[str, str],
    root: Path,
    base_commit: str,
    candidate_tree: str,
    commit_message: str,
    prepared_ref: str,
    pattern: re.Pattern[str],
) -> str:
    base_raw = run_git(
        git_executable,
        environment,
        root,
        ["cat-file", "commit", base_commit],
    )
    timestamp = base_committer_timestamp(base_raw) + 1
    commit_bytes = canonical_commit_bytes(
        candidate_tree,
        base_commit,
        timestamp,
        commit_message,
    )
    expected_oid = require_object_id(
        strict_ascii_line(
            run_git(
                git_executable,
                environment,
                root,
                ["hash-object", "-t", "commit", "--stdin"],
                input_bytes=commit_bytes,
            ),
            "deterministic candidate commit OID",
        ),
        "deterministic candidate commit OID",
        pattern,
    )
    existing = ref_oid_if_present(
        git_executable,
        environment,
        root,
        prepared_ref,
        pattern,
    )
    if existing is not None:
        reopen_exact_prepared_commit(
            git_executable,
            environment,
            root,
            prepared_ref,
            expected_oid,
            commit_bytes,
            pattern,
        )
        return expected_oid

    written_oid = require_object_id(
        strict_ascii_line(
            run_git(
                git_executable,
                environment,
                root,
                ["hash-object", "-t", "commit", "-w", "--stdin"],
                input_bytes=commit_bytes,
            ),
            "written candidate commit OID",
        ),
        "written candidate commit OID",
        pattern,
    )
    if written_oid != expected_oid:
        raise GitFailure("written candidate commit OID is nondeterministic")
    zero_oid = "0" * len(expected_oid)
    update = run_git_status(
        git_executable,
        environment,
        root,
        ["update-ref", "--no-deref", prepared_ref, expected_oid, zero_oid],
    )
    if update.returncode != 0:
        observed = ref_oid_if_present(
            git_executable,
            environment,
            root,
            prepared_ref,
            pattern,
        )
        if observed != expected_oid:
            raise PreparedRefConflict(
                "prepared-ref create-only CAS encountered a conflicting candidate"
            )
    reopen_exact_prepared_commit(
        git_executable,
        environment,
        root,
        prepared_ref,
        expected_oid,
        commit_bytes,
        pattern,
    )
    return expected_oid


def prepare_with_git(
    args: argparse.Namespace,
    row: tuple[str, str, int, str],
    git_executable: BoundGitExecutable,
) -> tuple[str, str, str, str, str]:
    environment = safe_git_environment(git_executable)
    root = repository_root(args.root, git_executable, environment)
    reject_repository_overrides(git_executable, environment, root)

    object_format = strict_ascii_line(
        run_git(
            git_executable,
            environment,
            root,
            ["rev-parse", "--show-object-format"],
        ),
        "Git object format",
    )
    pattern = object_pattern(object_format)
    source_raw, source, trust_raw, trust, _receipt_raw, receipt = (
        load_external_documents(
            root,
            args.source_selection,
            args.trust_root,
            args.previous_receipt,
        )
    )
    validate_selection_and_trust(root, git_executable, environment, source, trust)
    repository_identity = require_nonempty(
        source.get("repositoryIdentity"),
        "source selection repositoryIdentity",
    )
    if repository_identity != trust.get("repositoryIdentity"):
        policy_error("source selection and trust root repository identity mismatch")
    target_ref, base_commit, base_tree = validate_predecessor(
        receipt,
        row=row,
        repository_identity=repository_identity,
        source_selection=source,
        source_raw=source_raw,
        trust_root=trust,
        trust_raw=trust_raw,
        git_executable=git_executable,
        environment=environment,
        root=root,
        pattern=pattern,
    )
    validate_target_and_head(
        git_executable,
        environment,
        root,
        target_ref,
        base_commit,
        base_tree,
        pattern,
    )
    candidate_tree, _paths = validate_candidate_state(
        args,
        git_executable=git_executable,
        environment=environment,
        root=root,
        base_commit=base_commit,
        base_tree=base_tree,
        pattern=pattern,
    )
    prepared_ref = prepared_ref_name(
        repository_identity,
        target_ref,
        row,
        base_commit,
        candidate_tree,
    )
    check_ref = run_git_status(
        git_executable,
        environment,
        root,
        ["check-ref-format", prepared_ref],
    )
    if check_ref.returncode != 0:
        policy_error("derived prepared ref is not a canonical full Git ref")
    candidate_commit = prepare_commit_and_ref(
        git_executable=git_executable,
        environment=environment,
        root=root,
        base_commit=base_commit,
        candidate_tree=candidate_tree,
        commit_message=args.commit_message,
        prepared_ref=prepared_ref,
        pattern=pattern,
    )

    # Close races after object/ref creation without mutating any incumbent state.
    validate_target_and_head(
        git_executable,
        environment,
        root,
        target_ref,
        base_commit,
        base_tree,
        pattern,
    )
    final_index_tree = strict_ascii_line(
        run_git(git_executable, environment, root, ["write-tree"]),
        "final Git index tree",
    )
    if final_index_tree != candidate_tree:
        policy_error("Git index changed during candidate preparation")
    return target_ref, base_commit, base_tree, candidate_commit, prepared_ref


def prepare(args: argparse.Namespace) -> tuple[str, str, str, str, str]:
    row = validate_schedule(args)
    reject_unsafe_environment(dict(os.environ))
    git_executable = bind_git_executable(args.git_executable)
    try:
        return prepare_with_git(args, row, git_executable)
    finally:
        git_executable.close()


def main() -> int:
    try:
        values = prepare(parse_args())
        output = "\t".join(values).encode("ascii") + b"\n"
        sys.stdout.buffer.write(output)
        sys.stdout.buffer.flush()
        return EXIT_SUCCESS
    except PreparationError as error:
        print(f"candidate preparation failed: {error}", file=sys.stderr)
        return error.exit_code
    except BrokenPipeError:
        return EXIT_INTERNAL
    except Exception as error:  # pragma: no cover - last-resort fail-closed guard
        print(
            f"candidate preparation failed with an internal error: {error}",
            file=sys.stderr,
        )
        return EXIT_INTERNAL


if __name__ == "__main__":
    raise SystemExit(main())
