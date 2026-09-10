"""Fail-closed loading for authenticated PyTorch weights checkpoints."""

from __future__ import annotations

import hashlib
import hmac
import os
import re
import stat
import tempfile
from collections.abc import Callable, Mapping
from typing import Any


DEFAULT_MAX_BYTES = 16 * 1024 * 1024 * 1024
_COPY_CHUNK_BYTES = 1024 * 1024
_SHA256_IDENTITY = re.compile(r"sha256:([0-9a-f]{64})")


class CheckpointVerificationError(Exception):
    """The checkpoint could not be authenticated for restricted loading."""


def _validated_digest(expected_digest: object) -> str:
    if not isinstance(expected_digest, str):
        raise CheckpointVerificationError(
            "CKPT_SHA256 must be sha256:<64 lowercase hex>"
        )
    match = _SHA256_IDENTITY.fullmatch(expected_digest)
    if match is None:
        raise CheckpointVerificationError(
            "CKPT_SHA256 must be sha256:<64 lowercase hex>"
        )
    return match.group(1)


def _validated_max_bytes(max_bytes: object) -> int:
    if isinstance(max_bytes, bool) or not isinstance(max_bytes, int) or max_bytes <= 0:
        raise CheckpointVerificationError("checkpoint size limit must be a positive integer")
    return max_bytes


def _source_version(file_stat: os.stat_result) -> tuple[int, ...]:
    return (
        file_stat.st_dev,
        file_stat.st_ino,
        file_stat.st_mode,
        file_stat.st_size,
        file_stat.st_mtime_ns,
        file_stat.st_ctime_ns,
    )


def _close_preserving_primary(
    close: Callable[[], object],
    failure_message: str,
    active_error: BaseException | None,
) -> None:
    try:
        close()
    except BaseException as cleanup_error:
        if active_error is not None:
            return
        if isinstance(cleanup_error, OSError):
            raise CheckpointVerificationError(failure_message) from cleanup_error
        raise


def load_verified_weights_checkpoint(
    path: os.PathLike[str] | str,
    expected_digest: object,
    *,
    max_bytes: int = DEFAULT_MAX_BYTES,
) -> Mapping[str, Any]:
    """Authenticate ``path`` and safely load its exact snapshotted bytes."""

    expected_hex = _validated_digest(expected_digest)
    byte_limit = _validated_max_bytes(max_bytes)

    if not hasattr(os, "O_NOFOLLOW") or not hasattr(os, "O_NONBLOCK"):
        raise CheckpointVerificationError("platform cannot safely open checkpoints")

    flags = (
        os.O_RDONLY
        | os.O_NOFOLLOW
        | os.O_NONBLOCK
        | getattr(os, "O_CLOEXEC", 0)
    )
    try:
        source_fd = os.open(path, flags)
    except (OSError, TypeError, ValueError) as error:
        raise CheckpointVerificationError("checkpoint is not an accessible regular file") from error

    descriptor_error: BaseException | None = None
    try:
        try:
            before = os.fstat(source_fd)
        except OSError as error:
            raise CheckpointVerificationError("checkpoint source I/O failed") from error
        if not stat.S_ISREG(before.st_mode):
            raise CheckpointVerificationError("checkpoint is not a regular file")
        if before.st_size > byte_limit:
            raise CheckpointVerificationError("checkpoint exceeds configured size limit")

        try:
            source = os.fdopen(source_fd, "rb", closefd=True)
        except OSError as error:
            raise CheckpointVerificationError("checkpoint source I/O failed") from error
        source_fd = -1
        source_error: BaseException | None = None
        try:
            try:
                snapshot_file = tempfile.TemporaryFile(mode="w+b")
            except OSError as error:
                raise CheckpointVerificationError(
                    "checkpoint snapshot I/O failed"
                ) from error
            snapshot = snapshot_file
            snapshot_error: BaseException | None = None
            try:
                digest = hashlib.sha256()
                copied = 0
                try:
                    while True:
                        chunk = source.read(
                            min(_COPY_CHUNK_BYTES, byte_limit - copied + 1)
                        )
                        if not chunk:
                            break
                        copied += len(chunk)
                        if copied > byte_limit:
                            raise CheckpointVerificationError(
                                "checkpoint exceeds configured size limit"
                            )
                        digest.update(chunk)
                        if snapshot.write(chunk) != len(chunk):
                            raise CheckpointVerificationError(
                                "failed to snapshot checkpoint exactly"
                            )

                    after = os.fstat(source.fileno())
                    if (
                        _source_version(before) != _source_version(after)
                        or copied != after.st_size
                    ):
                        raise CheckpointVerificationError(
                            "checkpoint changed while being copied"
                        )

                    if not hmac.compare_digest(digest.hexdigest(), expected_hex):
                        raise CheckpointVerificationError("checkpoint digest mismatch")

                    snapshot.flush()
                    snapshot.seek(0)
                except OSError as error:
                    raise CheckpointVerificationError(
                        "checkpoint snapshot I/O failed"
                    ) from error

                try:
                    import torch
                except Exception as error:
                    raise CheckpointVerificationError(
                        "PyTorch is unavailable for restricted checkpoint loading"
                    ) from error

                try:
                    checkpoint = torch.load(
                        snapshot, map_location="cpu", weights_only=True
                    )
                except Exception as error:
                    raise CheckpointVerificationError(
                        "restricted checkpoint loading failed"
                    ) from error

                if not isinstance(checkpoint, Mapping):
                    raise CheckpointVerificationError(
                        "restricted checkpoint payload must be a mapping"
                    )
                return checkpoint
            except BaseException as error:
                snapshot_error = error
                raise
            finally:
                _close_preserving_primary(
                    lambda: snapshot_file.close(),
                    "checkpoint snapshot I/O failed",
                    snapshot_error,
                )
        except BaseException as error:
            source_error = error
            raise
        finally:
            _close_preserving_primary(
                lambda: source.close(),
                "checkpoint source I/O failed",
                source_error,
            )
    except BaseException as error:
        descriptor_error = error
        raise
    finally:
        if source_fd >= 0:
            _close_preserving_primary(
                lambda: os.close(source_fd),
                "checkpoint source I/O failed",
                descriptor_error,
            )
