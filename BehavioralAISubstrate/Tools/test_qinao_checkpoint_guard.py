from __future__ import annotations

import ast
import errno
import hashlib
import importlib.util
import os
import subprocess
import sys
import tempfile
import types
import unittest
from pathlib import Path
from unittest import mock

from BehavioralAISubstrate.Tools.qinao_checkpoint_guard import (
    CheckpointVerificationError,
    load_verified_weights_checkpoint,
)


def _identity(payload: bytes) -> str:
    return f"sha256:{hashlib.sha256(payload).hexdigest()}"


def _load_deploy_module_for_config_test():
    fake_torch = types.ModuleType("torch")
    fake_nn = types.ModuleType("torch.nn")
    fake_functional = types.ModuleType("torch.nn.functional")

    class FakeModule:
        pass

    fake_nn.Module = FakeModule
    fake_torch.nn = fake_nn

    fake_coreai = types.ModuleType("coreai_torch")
    fake_compression = types.ModuleType("coreai_torch._compression")
    fake_custom_layers = types.ModuleType(
        "coreai_torch._compression.custom_layers"
    )
    fake_custom_layers.constexpr_blockwise_shift_scale = object()
    fake_compression_utils = types.ModuleType("coreai_torch._compression.utils")
    fake_compression_utils.inject_subbyte_tensors = lambda value: value

    fake_quant = types.ModuleType("llama_to_coreai_int8")
    fake_quant.QuantEmbed = object
    fake_quant.QuantLinear = object

    fake_trainable = types.ModuleType("mamba3_trainable")
    fake_trainable.H = 1
    fake_trainable.P = 64
    fake_trainable.N = 64
    fake_trainable.R = 1
    fake_trainable.D_MODEL = 1

    guard_module = sys.modules[
        "BehavioralAISubstrate.Tools.qinao_checkpoint_guard"
    ]
    fake_modules = {
        "torch": fake_torch,
        "torch.nn": fake_nn,
        "torch.nn.functional": fake_functional,
        "coreai_torch": fake_coreai,
        "coreai_torch._compression": fake_compression,
        "coreai_torch._compression.custom_layers": fake_custom_layers,
        "coreai_torch._compression.utils": fake_compression_utils,
        "llama_to_coreai_int8": fake_quant,
        "mamba3_trainable": fake_trainable,
        "qinao_checkpoint_guard": guard_module,
    }

    deploy_path = Path(__file__).with_name("mamba3_deploy.py")
    spec = importlib.util.spec_from_file_location(
        "_qinao_checkpoint_deploy_config_test", deploy_path
    )
    if spec is None or spec.loader is None:
        raise AssertionError("could not load deploy module spec")
    deploy_module = importlib.util.module_from_spec(spec)
    with (
        mock.patch.dict(sys.modules, fake_modules),
        mock.patch.object(sys, "argv", [str(deploy_path)]),
        mock.patch.object(sys, "path", sys.path.copy()),
    ):
        spec.loader.exec_module(deploy_module)
    return deploy_module


class _RecordingTorch(types.ModuleType):
    def __init__(self, result: object) -> None:
        super().__init__("torch")
        self.result = result
        self.calls: list[tuple[bytes, str | None, bool | None, int]] = []

    def load(
        self,
        checkpoint,
        *,
        map_location: str | None = None,
        weights_only: bool | None = None,
    ) -> object:
        self.calls.append(
            (
                checkpoint.read(),
                map_location,
                weights_only,
                os.fstat(checkpoint.fileno()).st_nlink,
            )
        )
        return self.result


class _CloseFailingFile:
    def __init__(self, wrapped, *, write_error: Exception | None = None) -> None:
        self._wrapped = wrapped
        self._write_error = write_error

    def __enter__(self):
        self._wrapped.__enter__()
        return self

    def __exit__(self, *args):
        try:
            self._wrapped.__exit__(*args)
        finally:
            raise OSError(errno.EIO, "simulated close failure")

    def close(self) -> None:
        try:
            self._wrapped.close()
        finally:
            raise OSError(errno.EIO, "simulated close failure")

    def write(self, data: bytes) -> int:
        if self._write_error is not None:
            raise self._write_error
        return self._wrapped.write(data)

    def __getattr__(self, name: str):
        return getattr(self._wrapped, name)


class CheckpointGuardTests(unittest.TestCase):
    def test_missing_or_malformed_identity_rejects_before_open_or_loader(self) -> None:
        malformed = [
            None,
            "",
            "sha256:abc",
            f"sha256:{'A' * 64}",
            f"sha512:{'0' * 64}",
            f"sha256:{'0' * 64} trailing",
        ]
        fake_torch = _RecordingTorch({"model": {}})

        with mock.patch.dict(sys.modules, {"torch": fake_torch}):
            for identity in malformed:
                with self.subTest(identity=identity):
                    with mock.patch(
                        "BehavioralAISubstrate.Tools.qinao_checkpoint_guard.os.open",
                        side_effect=AssertionError("opened"),
                    ):
                        with self.assertRaises(CheckpointVerificationError):
                            load_verified_weights_checkpoint(
                                "/path/that/must/not/be/opened", identity
                            )

        self.assertEqual(fake_torch.calls, [])

    def test_invalid_byte_limit_rejects_before_open_or_loader(self) -> None:
        fake_torch = _RecordingTorch({"model": {}})

        with mock.patch.dict(sys.modules, {"torch": fake_torch}):
            for max_bytes in (0, -1, 1.5, True, "12"):
                with self.subTest(max_bytes=max_bytes):
                    with mock.patch(
                        "BehavioralAISubstrate.Tools.qinao_checkpoint_guard.os.open",
                        side_effect=AssertionError("opened"),
                    ):
                        with self.assertRaises(CheckpointVerificationError):
                            load_verified_weights_checkpoint(
                                "/path/that/must/not/be/opened",
                                f"sha256:{'0' * 64}",
                                max_bytes=max_bytes,
                            )

        self.assertEqual(fake_torch.calls, [])

    def test_short_snapshot_write_rejects_before_loader(self) -> None:
        payload = b"checkpoint"
        fake_torch = _RecordingTorch({"model": {}})
        real_temporary_file = tempfile.TemporaryFile

        class ShortWritingSnapshot:
            def __init__(self, *args, **kwargs) -> None:
                self._file = real_temporary_file(*args, **kwargs)

            def __enter__(self):
                self._file.__enter__()
                return self

            def __exit__(self, *args):
                return self._file.__exit__(*args)

            def write(self, data: bytes) -> int:
                return self._file.write(data[:-1])

            def __getattr__(self, name: str):
                return getattr(self._file, name)

        with tempfile.TemporaryDirectory() as directory:
            checkpoint = Path(directory) / "weights.pt"
            checkpoint.write_bytes(payload)

            with mock.patch.dict(sys.modules, {"torch": fake_torch}), mock.patch(
                "BehavioralAISubstrate.Tools.qinao_checkpoint_guard.tempfile.TemporaryFile",
                side_effect=ShortWritingSnapshot,
            ):
                with self.assertRaisesRegex(
                    CheckpointVerificationError, "snapshot checkpoint exactly"
                ):
                    load_verified_weights_checkpoint(checkpoint, _identity(payload))

        self.assertEqual(fake_torch.calls, [])

    def test_fifo_without_writer_is_refused_promptly(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            fifo = Path(directory) / "checkpoint.fifo"
            os.mkfifo(fifo)
            child = """
import sys
from BehavioralAISubstrate.Tools.qinao_checkpoint_guard import (
    CheckpointVerificationError,
    load_verified_weights_checkpoint,
)

try:
    load_verified_weights_checkpoint(sys.argv[1], f"sha256:{'0' * 64}")
except CheckpointVerificationError:
    raise SystemExit(0)
raise SystemExit(2)
"""
            environment = os.environ.copy()
            environment["PYTHONDONTWRITEBYTECODE"] = "1"

            completed = subprocess.run(
                [sys.executable, "-c", child, str(fifo)],
                cwd=Path(__file__).parents[2],
                env=environment,
                capture_output=True,
                text=True,
                timeout=2,
                check=False,
            )

        self.assertEqual(
            completed.returncode,
            0,
            msg=f"stdout={completed.stdout!r} stderr={completed.stderr!r}",
        )

    def test_temporary_storage_failure_uses_public_verification_error(self) -> None:
        payload = b"checkpoint"
        fake_torch = _RecordingTorch({"model": {}})
        disk_full = OSError(errno.ENOSPC, "simulated disk full")
        with tempfile.TemporaryDirectory() as directory:
            checkpoint = Path(directory) / "weights.pt"
            checkpoint.write_bytes(payload)

            with mock.patch.dict(sys.modules, {"torch": fake_torch}), mock.patch(
                "BehavioralAISubstrate.Tools.qinao_checkpoint_guard.tempfile.TemporaryFile",
                side_effect=disk_full,
            ):
                with self.assertRaises(CheckpointVerificationError) as caught:
                    load_verified_weights_checkpoint(checkpoint, _identity(payload))

        self.assertIs(caught.exception.__cause__, disk_full)
        self.assertEqual(fake_torch.calls, [])

    def test_close_time_io_failure_uses_public_verification_error(self) -> None:
        payload = b"checkpoint"
        real_temporary_file = tempfile.TemporaryFile
        real_fdopen = os.fdopen

        for failing_resource in ("snapshot", "source"):
            with self.subTest(failing_resource=failing_resource):
                fake_torch = _RecordingTorch({"model": {}})
                with tempfile.TemporaryDirectory() as directory:
                    checkpoint = Path(directory) / "weights.pt"
                    checkpoint.write_bytes(payload)

                    patches = [mock.patch.dict(sys.modules, {"torch": fake_torch})]
                    if failing_resource == "snapshot":
                        patches.append(
                            mock.patch(
                                "BehavioralAISubstrate.Tools.qinao_checkpoint_guard.tempfile.TemporaryFile",
                                side_effect=lambda *args, **kwargs: _CloseFailingFile(
                                    real_temporary_file(*args, **kwargs)
                                ),
                            )
                        )
                    else:
                        patches.append(
                            mock.patch(
                                "BehavioralAISubstrate.Tools.qinao_checkpoint_guard.os.fdopen",
                                side_effect=lambda *args, **kwargs: _CloseFailingFile(
                                    real_fdopen(*args, **kwargs)
                                ),
                            )
                        )

                    with patches[0], patches[1]:
                        with self.assertRaises(
                            CheckpointVerificationError
                        ) as caught:
                            load_verified_weights_checkpoint(
                                checkpoint, _identity(payload)
                            )

                self.assertIsInstance(caught.exception.__cause__, OSError)
                self.assertEqual(caught.exception.__cause__.errno, errno.EIO)
                self.assertEqual(len(fake_torch.calls), 1)

    def test_cleanup_failure_does_not_replace_active_error(self) -> None:
        payload = b"checkpoint"
        real_temporary_file = tempfile.TemporaryFile
        fake_torch = _RecordingTorch({"model": {}})

        with tempfile.TemporaryDirectory() as directory:
            checkpoint = Path(directory) / "weights.pt"
            checkpoint.write_bytes(payload)

            with mock.patch.dict(sys.modules, {"torch": fake_torch}), mock.patch(
                "BehavioralAISubstrate.Tools.qinao_checkpoint_guard.tempfile.TemporaryFile",
                side_effect=lambda *args, **kwargs: _CloseFailingFile(
                    real_temporary_file(*args, **kwargs)
                ),
            ):
                with self.assertRaisesRegex(
                    CheckpointVerificationError, "digest mismatch"
                ):
                    load_verified_weights_checkpoint(
                        checkpoint, f"sha256:{'0' * 64}"
                    )

        self.assertEqual(fake_torch.calls, [])

    def test_cleanup_failure_does_not_replace_programmer_error(self) -> None:
        payload = b"checkpoint"
        real_temporary_file = tempfile.TemporaryFile
        programmer_error = RuntimeError("programmer failure")
        fake_torch = _RecordingTorch({"model": {}})
        with tempfile.TemporaryDirectory() as directory:
            checkpoint = Path(directory) / "weights.pt"
            checkpoint.write_bytes(payload)

            with mock.patch.dict(sys.modules, {"torch": fake_torch}), mock.patch(
                "BehavioralAISubstrate.Tools.qinao_checkpoint_guard.tempfile.TemporaryFile",
                side_effect=lambda *args, **kwargs: _CloseFailingFile(
                    real_temporary_file(*args, **kwargs),
                    write_error=programmer_error,
                ),
            ):
                with self.assertRaises(RuntimeError) as caught:
                    load_verified_weights_checkpoint(
                        checkpoint, _identity(payload)
                    )
            self.assertIs(caught.exception, programmer_error)

    def test_descriptor_cleanup_failure_does_not_replace_size_error(self) -> None:
        payload = b"checkpoint"
        with tempfile.TemporaryDirectory() as directory:
            checkpoint = Path(directory) / "weights.pt"
            checkpoint.write_bytes(payload)
            real_close = os.close

            def close_then_fail(file_descriptor: int) -> None:
                try:
                    real_close(file_descriptor)
                finally:
                    raise OSError(errno.EIO, "simulated descriptor close failure")

            with mock.patch(
                "BehavioralAISubstrate.Tools.qinao_checkpoint_guard.os.close",
                side_effect=close_then_fail,
            ):
                with self.assertRaisesRegex(
                    CheckpointVerificationError, "size limit"
                ):
                    load_verified_weights_checkpoint(
                        checkpoint, _identity(payload), max_bytes=len(payload) - 1
                    )

    def test_mismatched_identity_rejects_before_loader(self) -> None:
        fake_torch = _RecordingTorch({"model": {}})
        with tempfile.TemporaryDirectory() as directory:
            checkpoint = Path(directory) / "weights.pt"
            checkpoint.write_bytes(b"checkpoint")

            with mock.patch.dict(sys.modules, {"torch": fake_torch}):
                with self.assertRaisesRegex(
                    CheckpointVerificationError, "digest mismatch"
                ):
                    load_verified_weights_checkpoint(
                        checkpoint, f"sha256:{'0' * 64}"
                    )

        self.assertEqual(fake_torch.calls, [])

    def test_symlink_rejects_before_loader(self) -> None:
        fake_torch = _RecordingTorch({"model": {}})
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory) / "target.pt"
            target.write_bytes(b"checkpoint")
            symlink = Path(directory) / "link.pt"
            symlink.symlink_to(target)

            with mock.patch.dict(sys.modules, {"torch": fake_torch}):
                with self.assertRaises(CheckpointVerificationError):
                    load_verified_weights_checkpoint(symlink, _identity(b"checkpoint"))

        self.assertEqual(fake_torch.calls, [])

    def test_oversize_input_rejects_before_loader(self) -> None:
        fake_torch = _RecordingTorch({"model": {}})
        with tempfile.TemporaryDirectory() as directory:
            checkpoint = Path(directory) / "weights.pt"
            checkpoint.write_bytes(b"12345")

            with mock.patch.dict(sys.modules, {"torch": fake_torch}):
                with self.assertRaisesRegex(
                    CheckpointVerificationError, "size limit"
                ):
                    load_verified_weights_checkpoint(
                        checkpoint, _identity(b"12345"), max_bytes=4
                    )

        self.assertEqual(fake_torch.calls, [])

    def test_source_mutation_during_snapshot_rejects_before_loader(self) -> None:
        original = b"original"
        replacement = b"replacement"
        fake_torch = _RecordingTorch({"model": {}})
        real_temporary_file = tempfile.TemporaryFile

        with tempfile.TemporaryDirectory() as directory:
            checkpoint = Path(directory) / "weights.pt"
            checkpoint.write_bytes(original)

            class MutatingSnapshot:
                def __init__(self, *args, **kwargs) -> None:
                    self._file = real_temporary_file(*args, **kwargs)
                    self._mutated = False

                def __enter__(self):
                    self._file.__enter__()
                    return self

                def __exit__(self, *args):
                    return self._file.__exit__(*args)

                def write(self, data: bytes) -> int:
                    written = self._file.write(data)
                    if not self._mutated:
                        checkpoint.write_bytes(replacement)
                        self._mutated = True
                    return written

                def __getattr__(self, name: str):
                    return getattr(self._file, name)

            with mock.patch.dict(sys.modules, {"torch": fake_torch}), mock.patch(
                "BehavioralAISubstrate.Tools.qinao_checkpoint_guard.tempfile.TemporaryFile",
                side_effect=MutatingSnapshot,
            ):
                with self.assertRaisesRegex(
                    CheckpointVerificationError, "changed while being copied"
                ):
                    load_verified_weights_checkpoint(checkpoint, _identity(original))

        self.assertEqual(fake_torch.calls, [])

    def test_matching_identity_loads_exact_unlinked_snapshot_safely(self) -> None:
        payload = b"verified checkpoint bytes"
        loaded = {"model": {"weight": object()}, "layers": 8}
        fake_torch = _RecordingTorch(loaded)
        with tempfile.TemporaryDirectory() as directory:
            checkpoint = Path(directory) / "weights.pt"
            checkpoint.write_bytes(payload)

            with mock.patch.dict(sys.modules, {"torch": fake_torch}):
                result = load_verified_weights_checkpoint(
                    checkpoint, _identity(payload)
                )

        self.assertIs(result, loaded)
        self.assertEqual(fake_torch.calls, [(payload, "cpu", True, 0)])

    def test_loader_without_weights_only_support_is_not_retried(self) -> None:
        payload = b"checkpoint"
        calls = 0
        fake_torch = types.ModuleType("torch")

        def unsupported_load(checkpoint, **kwargs):
            nonlocal calls
            calls += 1
            raise TypeError("unexpected keyword argument 'weights_only'")

        fake_torch.load = unsupported_load
        with tempfile.TemporaryDirectory() as directory:
            checkpoint = Path(directory) / "weights.pt"
            checkpoint.write_bytes(payload)

            with mock.patch.dict(sys.modules, {"torch": fake_torch}):
                with self.assertRaises(CheckpointVerificationError):
                    load_verified_weights_checkpoint(checkpoint, _identity(payload))

        self.assertEqual(calls, 1)

    def test_non_mapping_payload_rejects(self) -> None:
        payload = b"checkpoint"
        fake_torch = _RecordingTorch(["not", "a", "mapping"])
        with tempfile.TemporaryDirectory() as directory:
            checkpoint = Path(directory) / "weights.pt"
            checkpoint.write_bytes(payload)

            with mock.patch.dict(sys.modules, {"torch": fake_torch}):
                with self.assertRaisesRegex(
                    CheckpointVerificationError, "mapping"
                ):
                    load_verified_weights_checkpoint(checkpoint, _identity(payload))


class DeployCheckpointIntegrationTests(unittest.TestCase):
    def test_deploy_uses_candidate_local_verified_checkpoint_loader(self) -> None:
        deploy_path = Path(__file__).with_name("mamba3_deploy.py")
        source = deploy_path.read_text(encoding="utf-8")
        tree = ast.parse(source)

        imported_names = {
            alias.name
            for node in ast.walk(tree)
            if isinstance(node, ast.ImportFrom)
            and node.module == "qinao_checkpoint_guard"
            for alias in node.names
        }
        called_names = {
            node.func.id
            for node in ast.walk(tree)
            if isinstance(node, ast.Call) and isinstance(node.func, ast.Name)
        }
        torch_load_calls = [
            node
            for node in ast.walk(tree)
            if isinstance(node, ast.Call)
            and isinstance(node.func, ast.Attribute)
            and isinstance(node.func.value, ast.Name)
            and node.func.value.id == "torch"
            and node.func.attr == "load"
        ]

        self.assertNotIn("/Users/changgeng/", source)
        self.assertIn("Path(__file__).resolve().parent", source)
        self.assertIn("load_verified_weights_checkpoint", imported_names)
        self.assertIn("load_verified_weights_checkpoint", called_names)
        self.assertEqual(torch_load_calls, [])

    def test_deploy_max_bytes_parser_rejects_arbitrarily_long_decimal(self) -> None:
        deploy = _load_deploy_module_for_config_test()

        with mock.patch.dict(os.environ, {"CKPT_MAX_BYTES": "17"}):
            self.assertEqual(deploy._checkpoint_max_bytes(), 17)

        with mock.patch.dict(os.environ, {"CKPT_MAX_BYTES": "9" * 5000}):
            with self.assertRaises(deploy.CheckpointVerificationError):
                deploy._checkpoint_max_bytes()

    def test_real_torch_rejects_execution_gadget_without_executing_it(self) -> None:
        try:
            import torch
        except ModuleNotFoundError as error:
            if error.name == "torch":
                self.skipTest("PyTorch is not installed")
            raise

        with tempfile.TemporaryDirectory() as directory:
            checkpoint = Path(directory) / "malicious.pt"
            marker = Path(directory) / "executed"

            class ExecutionGadget:
                def __reduce__(self):
                    return (os.system, (f"touch {marker}",))

            torch.save({"model": ExecutionGadget()}, checkpoint)
            payload = checkpoint.read_bytes()

            with self.assertRaises(CheckpointVerificationError):
                load_verified_weights_checkpoint(checkpoint, _identity(payload))

            self.assertFalse(marker.exists())


if __name__ == "__main__":
    unittest.main()
