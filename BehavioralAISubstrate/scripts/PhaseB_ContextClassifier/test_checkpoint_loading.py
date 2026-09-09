"""Real-Torch checkpoint boundary tests; Apple backends/output sinks are isolated."""
from __future__ import annotations

import contextlib
import importlib.util
import io
import os
from pathlib import Path
import sys
import tempfile
import types
import unittest
from unittest import mock

import torch


HERE = Path(__file__).resolve().parent


def _reducer_marker(path):
    Path(path).write_text("reducer executed", encoding="utf-8")
    return "unexpected custom checkpoint value"


class _MarkerPayload:
    def __init__(self, path):
        self.path = str(path)

    def __reduce__(self):
        return _reducer_marker, (self.path,)


class CheckpointLoadingTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)

    @contextlib.contextmanager
    def converter(self, name):
        observed = {"saved": [], "converted": []}

        class MLModel:
            def __init__(self):
                self.user_defined_metadata = {}

            def save(self, path):
                observed["saved"].append(path)
                observed["metadata"] = self.user_defined_metadata

        def coreml_convert(traced, **kwargs):
            observed["converted"].append((traced, kwargs))
            return MLModel()

        class Program:
            def optimize(self):
                observed["optimized"] = True

            def save_asset(self, path):
                observed["saved"].append(path)

        class TorchConverter:
            def add_exported_program(self, exported, **kwargs):
                observed["converted"].append((exported, kwargs))

            def to_coreai(self):
                return Program()

        coreml = types.ModuleType("coremltools")
        coreml.convert = coreml_convert
        coreml.TensorType = lambda **kwargs: kwargs
        coreai = types.ModuleType("coreai_torch")
        coreai.TorchConverter = TorchConverter
        coreai.get_decomp_table = lambda: {}
        # Restore only our backend substitutes. Restoring the entire sys.modules
        # mapping discards lazy Torch imports but leaves their registered kernels.
        missing = object()
        previous = {key: sys.modules.get(key, missing) for key in ("coremltools", "coreai_torch")}
        sys.modules.update({"coremltools": coreml, "coreai_torch": coreai})
        try:
            with mock.patch.object(sys, "path", [str(HERE), *sys.path]):
                spec = importlib.util.spec_from_file_location(f"checkpoint_test_{name}", HERE / f"{name}.py")
                module = importlib.util.module_from_spec(spec)
                spec.loader.exec_module(module)
                module.CHECKPOINT_PATH = self.root / f"{name}.pt"
                module.OUTPUT_PATH = self.root / ("output.mlmodel" if name == "convert" else "output.aimodel")
                yield module, observed
        finally:
            for key, value in previous.items():
                if value is missing:
                    sys.modules.pop(key, None)
                else:
                    sys.modules[key] = value

    def write_checkpoint(self, module, *, extra=None, zip_format=True):
        model = module.ContextClassifier(4, 3, 2)
        with torch.no_grad():
            for index, parameter in enumerate(model.parameters()):
                parameter.fill_((index + 1) / 10)
        checkpoint = {
            "state_dict": model.state_dict(), "num_buckets": 4, "hidden": 3,
            "num_classes": 2, "labels": ["chat", "task"], "seed": 42,
        }
        if extra is not None:
            checkpoint["extra"] = extra
        torch.save(checkpoint, module.CHECKPOINT_PATH, _use_new_zipfile_serialization=zip_format)
        return model

    def run_main(self, module):
        with contextlib.redirect_stdout(io.StringIO()) as output:
            module.main()
        return output.getvalue()

    def assert_conversion(self, module, observed, expected):
        self.assertEqual(len(observed["converted"]), 1)
        graph, arguments = observed["converted"][0]
        example = torch.ones(1, 4)
        if module.__name__.endswith("convert_coreai"):
            actual = graph.module()(example)
            self.assertEqual(arguments, {
                "input_names": ["bag_of_buckets"], "output_names": ["logits"],
                "entrypoint_name": "main",
            })
            self.assertIs(observed["optimized"], True)
        else:
            actual = graph(example)
            self.assertEqual(arguments, {
                "inputs": [{"name": "bag_of_buckets", "shape": (1, 4)}],
                "convert_to": "neuralnetwork",
            })
            self.assertEqual(observed["metadata"]["labels"], '["chat", "task"]')
            self.assertEqual(observed["metadata"]["num_buckets"], "4")
        torch.testing.assert_close(actual, expected(example), rtol=0, atol=0)
        self.assertEqual([Path(path) for path in observed["saved"]], [module.OUTPUT_PATH])
        self.assertFalse(module.OUTPUT_PATH.exists())

    def test_trainer_shaped_checkpoint_reaches_both_conversion_backends(self):
        for name in ("convert", "convert_coreai"):
            with self.subTest(converter=name), self.converter(name) as (module, observed):
                expected = self.write_checkpoint(module)
                output = self.run_main(module)
                self.assertIn("Loaded", output)
                self.assert_conversion(module, observed, expected)

    def test_reducer_payload_is_rejected_in_zip_and_legacy_checkpoints(self):
        for name in ("convert", "convert_coreai"):
            for zip_format in (True, False):
                with self.subTest(converter=name, zip=zip_format), self.converter(name) as (module, observed):
                    marker = self.root / f"{name}-{zip_format}.marker"
                    self.write_checkpoint(module, extra=_MarkerPayload(marker), zip_format=zip_format)
                    error = None
                    try:
                        self.run_main(module)
                    except Exception as caught:
                        error = caught
                    self.assertFalse(marker.exists(), "checkpoint reducer executed")
                    self.assertIsNotNone(error, "custom checkpoint value must be rejected")
                    self.assertEqual(observed["converted"], [])
                    self.assertEqual(observed["saved"], [])

    def test_explicit_restricted_cpu_load_overrides_no_weights_only_environment(self):
        for name in ("convert", "convert_coreai"):
            with self.subTest(converter=name), self.converter(name) as (module, observed):
                expected = self.write_checkpoint(module)
                real_load = torch.load
                with mock.patch.dict(os.environ, {"TORCH_FORCE_NO_WEIGHTS_ONLY_LOAD": "1"}), \
                        mock.patch.object(torch, "load", wraps=real_load) as load:
                    self.run_main(module)
                load.assert_called_once_with(module.CHECKPOINT_PATH, map_location="cpu", weights_only=True)
                self.assert_conversion(module, observed, expected)

    def test_unsupported_loader_never_retries_unrestricted(self):
        for name in ("convert", "convert_coreai"):
            with self.subTest(converter=name), self.converter(name) as (module, observed):
                self.write_checkpoint(module)
                failure = TypeError("unsupported weights_only argument")
                with mock.patch.object(torch, "load", side_effect=failure) as load:
                    with self.assertRaises(TypeError) as raised:
                        self.run_main(module)
                self.assertIs(raised.exception, failure)
                load.assert_called_once_with(module.CHECKPOINT_PATH, map_location="cpu", weights_only=True)
                self.assertEqual(observed["converted"], [])

    def test_unsafe_or_unverifiable_versions_are_rejected_before_loading(self):
        for name in ("convert", "convert_coreai"):
            for version in ("2.5.1", "2.6.0", "2.9.1", "2.9.1+cpu", "2.10.0rc1",
                            "2.10.0.dev1", "invalid", "", None, 2.12):
                with self.subTest(converter=name, version=version), self.converter(name) as (module, observed):
                    self.write_checkpoint(module)
                    with mock.patch.object(torch, "__version__", version), \
                            mock.patch.object(torch, "load", side_effect=AssertionError(
                                "checkpoint loaded before version validation")) as load:
                        with self.assertRaisesRegex(RuntimeError, "2.10.0"):
                            self.run_main(module)
                    load.assert_not_called()
                    self.assertEqual(observed["converted"], [])

    def test_final_floor_and_local_version_metadata_remain_supported(self):
        for name in ("convert", "convert_coreai"):
            for version in ("2.10.0", "2.10.0+cpu", "2.12.0+local.1"):
                with self.subTest(converter=name, version=version), self.converter(name) as (module, observed):
                    expected = self.write_checkpoint(module)
                    real_load = torch.load
                    with mock.patch.object(torch, "__version__", version), \
                            mock.patch.object(torch, "load", wraps=real_load) as load:
                        self.run_main(module)
                    load.assert_called_once_with(module.CHECKPOINT_PATH, map_location="cpu", weights_only=True)
                    self.assert_conversion(module, observed, expected)

    def test_missing_checkpoint_still_exits_before_loading(self):
        for name in ("convert", "convert_coreai"):
            with self.subTest(converter=name), self.converter(name) as (module, observed):
                with mock.patch.object(torch, "load") as load:
                    with self.assertRaises(SystemExit) as raised:
                        self.run_main(module)
                self.assertEqual(raised.exception.code, 1)
                load.assert_not_called()
                self.assertEqual(observed["saved"], [])


if __name__ == "__main__":
    unittest.main()
