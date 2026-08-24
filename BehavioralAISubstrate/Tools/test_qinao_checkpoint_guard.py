from __future__ import annotations

import ast
import errno
import hashlib
import importlib.util
import os
import re
import shlex
import shutil
import subprocess
import sys
import tempfile
import textwrap
import types
import unittest
from pathlib import Path
from unittest import mock

from BehavioralAISubstrate.Tools.qinao_checkpoint_guard import (
    CheckpointVerificationError,
    load_verified_weights_checkpoint,
)


_RUNBOOK_PATH = Path(__file__).parents[1] / "Docs" / "RUNPOD_DISTILL.md"
_DEPLOY_PATH = Path(__file__).with_name("mamba3_deploy.py")


def _fenced_bash_scripts(markdown: str) -> list[str]:
    return re.findall(r"```bash\s*\n(.*?)```", markdown, flags=re.DOTALL)


def _documented_deploy_script() -> str:
    runbook = _RUNBOOK_PATH.read_text(encoding="utf-8")
    deploy_section = runbook.split("## Deploy back to the A19", 1)[1]
    deploy_section = deploy_section.split("## Cost", 1)[0]
    scripts = _fenced_bash_scripts(deploy_section)
    if len(scripts) != 1:
        raise AssertionError(
            f"expected one deploy shell block before Cost, found {len(scripts)}"
        )
    return scripts[0]


def _module_usage_script() -> str:
    source = _DEPLOY_PATH.read_text(encoding="utf-8")
    docstring = ast.get_docstring(ast.parse(source), clean=False)
    if docstring is None or "Run:" not in docstring:
        raise AssertionError("deploy module must carry a shell-checkable Run section")
    return textwrap.dedent(docstring.split("Run:", 1)[1]).strip()


def _unquoted_angle_placeholders(script: str) -> list[str]:
    placeholders = []
    quote = None
    escaped = False
    index = 0
    while index < len(script):
        character = script[index]
        if escaped:
            escaped = False
        elif character == "\\" and quote != "'":
            escaped = True
        elif quote is not None:
            if character == quote:
                quote = None
        elif character in ("'", '"'):
            quote = character
        elif character == "#":
            newline = script.find("\n", index)
            index = len(script) if newline < 0 else newline
        elif character == "<":
            end = script.find(">", index + 1)
            if end >= 0:
                placeholders.append(script[index : end + 1])
                index = end
        index += 1
    return placeholders


def _identity(payload: bytes) -> str:
    return f"sha256:{hashlib.sha256(payload).hexdigest()}"


_DOCUMENTED_SOURCE_GUARDS = (
    "test_deploy_uses_candidate_local_verified_checkpoint_loader",
    "test_optimized_deploy_refuses_unexpected_trained_keys_before_output",
    "test_optimized_deploy_refuses_missing_trained_keys_before_output",
    "test_optimized_deploy_accepts_only_registered_decode_state_buffers",
)


def _candidate_guard_module(
    *, failing_guard: str | None = None, dirty_after_preflight: bool = False
) -> str:
    methods = []
    for guard in _DOCUMENTED_SOURCE_GUARDS:
        if guard == failing_guard:
            body = f'self.fail("{guard} rejected candidate")'
        elif dirty_after_preflight and guard == _DOCUMENTED_SOURCE_GUARDS[-1]:
            body = (
                'Path("guard-created-untracked.py").write_text('
                '"created by passing guard", encoding="utf-8")'
            )
        else:
            body = "pass"
        methods.append(
            textwrap.indent(
                textwrap.dedent(
                    f"""
                    def {guard}(self) -> None:
                        {body}
                    """
                ).strip(),
                "    ",
            )
        )

    return (
        "import unittest\n"
        "from pathlib import Path\n\n\n"
        "class DeployCheckpointIntegrationTests(unittest.TestCase):\n"
        + "\n\n".join(methods)
        + "\n"
    )


class _DocumentedDeployFixture:
    def __init__(self, root: Path) -> None:
        self.root = root
        self.source = root / "source"
        self.fake_bin = root / "fake-bin"
        self.source.mkdir()
        self.fake_bin.mkdir()
        self._git_binary = shutil.which("git")
        if self._git_binary is None:
            raise AssertionError("git is required for documented deploy tests")

        self._git("init")
        self._git("config", "user.name", "Qinao deploy test")
        self._git("config", "user.email", "qinao-deploy-test.invalid")
        self._git("config", "commit.gpgsign", "false")
        self._write_candidate_tree()
        self.floor_commit = self._commit("security floor")
        self._git("branch", "-M", "main")

        (self.source / "README.md").write_text(
            "valid current descendant\n", encoding="utf-8"
        )
        self.current_commit = self._commit("valid current descendant")

        self.guard_failure_commits = {}
        for index, guard in enumerate(_DOCUMENTED_SOURCE_GUARDS):
            self._git("checkout", "--detach", self.current_commit)
            self._guard_path.write_text(
                _candidate_guard_module(failing_guard=guard), encoding="utf-8"
            )
            commit = self._commit(f"broken source guard {index}")
            self._git("branch", f"broken-guard-{index}", commit)
            self.guard_failure_commits[guard] = commit

        self._git("checkout", "--detach", self.current_commit)
        self._guard_path.write_text(
            _candidate_guard_module(dirty_after_preflight=True), encoding="utf-8"
        )
        self.post_preflight_dirty_commit = self._commit(
            "passing guard dirties candidate"
        )
        self._git("branch", "post-preflight-dirty", self.post_preflight_dirty_commit)

        self._git("checkout", "main")
        self._git("checkout", "--orphan", "nonancestor")
        self.nonancestor_commit = self._commit("nonancestor candidate")
        self._git("checkout", "main")
        self._write_wrappers()
        self._run_count = 0

    @property
    def _guard_path(self) -> Path:
        return (
            self.source
            / "BehavioralAISubstrate"
            / "Tools"
            / "test_qinao_checkpoint_guard.py"
        )

    def _write_candidate_tree(self) -> None:
        tools = self.source / "BehavioralAISubstrate" / "Tools"
        tools.mkdir(parents=True)
        (self.source / "BehavioralAISubstrate" / "__init__.py").write_text(
            "", encoding="utf-8"
        )
        (tools / "__init__.py").write_text("", encoding="utf-8")
        self._guard_path.write_text(_candidate_guard_module(), encoding="utf-8")
        (tools / "mamba3_deploy.py").write_text(
            "raise SystemExit('fake uv must intercept conversion')\n",
            encoding="utf-8",
        )

    def _git(self, *args: str) -> str:
        completed = subprocess.run(
            [self._git_binary, *args],
            cwd=self.source,
            capture_output=True,
            text=True,
            check=False,
        )
        if completed.returncode != 0:
            raise AssertionError(
                f"git {' '.join(args)} failed:\n{completed.stdout}{completed.stderr}"
            )
        return completed.stdout.strip()

    def _commit(self, message: str) -> str:
        self._git("add", "-A")
        self._git("commit", "--allow-empty", "-m", message)
        return self._git("rev-parse", "HEAD")

    def _write_wrappers(self) -> None:
        git_wrapper = self.fake_bin / "git"
        git_wrapper.write_text(
            "#!/bin/sh\n"
            'if [ "${QINAO_FAIL_GIT_STATUS:-0}" = 1 ] '
            '&& [ "${1:-}" = status ]; then\n'
            "  exit 86\n"
            "fi\n"
            f"exec {shlex.quote(self._git_binary)} \"$@\"\n",
            encoding="utf-8",
        )
        git_wrapper.chmod(0o755)

        uv_wrapper = self.fake_bin / "uv"
        uv_wrapper.write_text(
            "#!/bin/sh\n"
            "set -eu\n"
            ': "${QINAO_CONVERSION_SENTINEL:?}"\n'
            'printf "conversion reached\\n" > "$QINAO_CONVERSION_SENTINEL"\n',
            encoding="utf-8",
        )
        uv_wrapper.chmod(0o755)

    def run(
        self,
        *,
        reviewed_commit: str | None = None,
        floor_commit: str | None = None,
        after_checkout: str = "",
        fail_git_status: bool = False,
        shell: str = "bash",
    ) -> tuple[subprocess.CompletedProcess[str], Path]:
        self._run_count += 1
        checkout = self.root / f"checkout-{self._run_count}"
        sentinel = self.root / f"conversion-{self._run_count}"
        script = _documented_deploy_script()
        replacements = {
            "QINAO_REVIEWED_DEPLOY_COMMIT": reviewed_commit or self.current_commit,
            "QINAO_DEPLOY_REPO_URL": str(self.source),
            "QINAO_DEPLOY_CHECKOUT": str(checkout),
            "QINAO_DEPLOY_SECURITY_FLOOR": floor_commit or self.floor_commit,
        }
        for name, value in replacements.items():
            script, count = re.subn(
                rf"(?m)^export {name}=.*$",
                f"export {name}={shlex.quote(value)}",
                script,
                count=1,
            )
            if count != 1:
                raise AssertionError(f"documented deploy script must export {name}")

        if after_checkout:
            anchor = 'cd "$QINAO_DEPLOY_CHECKOUT"\n'
            if script.count(anchor) != 1:
                raise AssertionError("documented checkout handoff must be unique")
            script = script.replace(anchor, anchor + after_checkout + "\n", 1)

        env = {
            **os.environ,
            "PATH": f"{self.fake_bin}{os.pathsep}{os.environ['PATH']}",
            "PYTHONDONTWRITEBYTECODE": "1",
            "QINAO_CONVERSION_SENTINEL": str(sentinel),
            "QINAO_FAIL_GIT_STATUS": "1" if fail_git_status else "0",
        }
        completed = subprocess.run(
            [shell],
            input=script,
            cwd=self.root,
            env=env,
            capture_output=True,
            text=True,
            timeout=20,
            check=False,
        )
        return completed, sentinel


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


_OPTIMIZED_DEPLOY_DRIVER = r"""
import importlib.util
import os
import sys
import types
from pathlib import Path

if __debug__:
    raise SystemExit(90)

case, deploy_path, checkpoint_path, out_path, quant_marker, convert_marker, save_marker = sys.argv[1:]

fake_torch = types.ModuleType("torch")
fake_nn = types.ModuleType("torch.nn")
fake_functional = types.ModuleType("torch.nn.functional")

class FakeModule:
    def __init__(self, *args, **kwargs):
        pass
    def eval(self):
        return self
    def half(self):
        return self
    def register_buffer(self, name, value):
        setattr(self, name, value)
    def load_state_dict(self, _state, strict=False):
        if strict is not False:
            raise AssertionError("deploy must retain strict=False compatibility loading")
        if case == "unexpected":
            return [], ["attacker.extra_weight"]
        missing_by_case = {
            "missing": ["layers.0.in_proj.weight"],
            "stack-decode-state": [
                "angle_all", "ssm_all", "kprev_all", "vprev_all"
            ],
            "separate-decode-state": [
                "angle_0", "ssm_0", "kprev_0", "vprev_0",
                "angle_1", "ssm_1", "kprev_1", "vprev_1",
            ],
            "spoofed-decode-state": ["layers.0.attacker_all"],
        }
        return missing_by_case[case], []
    def __call__(self, *args, **kwargs):
        return object()

fake_nn.Module = FakeModule
fake_nn.Embedding = lambda *args, **kwargs: types.SimpleNamespace(weight=object())
fake_nn.ModuleList = lambda values: list(values)
fake_nn.Parameter = lambda value: value
fake_torch.nn = fake_nn
fake_torch.ones = lambda *args, **kwargs: object()
fake_torch.zeros = lambda *args, **kwargs: object()
fake_torch.manual_seed = lambda *_args, **_kwargs: None
fake_torch.float16 = object()
fake_torch.long = object()

class FakeExportedProgram:
    graph_signature = types.SimpleNamespace(buffers_to_mutate={})
    def run_decompositions(self, _table):
        return self

fake_torch.export = types.SimpleNamespace(
    export=lambda *_args, **_kwargs: FakeExportedProgram()
)

fake_coreai = types.ModuleType("coreai_torch")
class FakeAsset:
    def optimize(self):
        return None
    def save_asset(self, path):
        Path(save_marker).write_text("save-called", encoding="utf-8")
        Path(path).mkdir(parents=True, exist_ok=True)
class FakeConverter:
    def add_exported_program(self, *_args, **_kwargs):
        Path(convert_marker).write_text("convert-called", encoding="utf-8")
        return self
    def to_coreai(self):
        return FakeAsset()
fake_coreai.TorchConverter = FakeConverter
fake_coreai.get_decomp_table = lambda: {}

fake_compression = types.ModuleType("coreai_torch._compression")
fake_custom_layers = types.ModuleType("coreai_torch._compression.custom_layers")
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
fake_trainable.Lyr = lambda: object()

fake_guard = types.ModuleType("qinao_checkpoint_guard")
class FakeCheckpointVerificationError(Exception):
    pass
fake_guard.DEFAULT_MAX_BYTES = 1024
fake_guard.CheckpointVerificationError = FakeCheckpointVerificationError
fake_guard.load_verified_weights_checkpoint = lambda *_args, **_kwargs: {
    "layers": 2 if case == "separate-decode-state" else 1,
    "model": {},
}

sys.modules.update({
    "torch": fake_torch,
    "torch.nn": fake_nn,
    "torch.nn.functional": fake_functional,
    "coreai_torch": fake_coreai,
    "coreai_torch._compression": fake_compression,
    "coreai_torch._compression.custom_layers": fake_custom_layers,
    "coreai_torch._compression.utils": fake_compression_utils,
    "llama_to_coreai_int8": fake_quant,
    "mamba3_trainable": fake_trainable,
    "qinao_checkpoint_guard": fake_guard,
})

os.environ.pop("FORCE_RANDOM", None)
os.environ.pop("FP16", None)
os.environ.pop("STATE_WRITE", None)
if case == "separate-decode-state":
    os.environ["STATE_WRITE"] = "separate"
os.environ["CKPT"] = checkpoint_path
os.environ["CKPT_SHA256"] = "sha256:" + "0" * 64
sys.argv = [deploy_path, "2" if case == "separate-decode-state" else "1", "8"]

spec = importlib.util.spec_from_file_location("_qinao_optimized_deploy_test", deploy_path)
if spec is None or spec.loader is None:
    raise SystemExit(91)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
module.CKPT = checkpoint_path
module.OUT = out_path

def record_quantize(self):
    Path(quant_marker).write_text("quantize-called", encoding="utf-8")
    return self

module.DeployM.quantize = record_quantize
module.main()
"""


def _run_optimized_deploy_case(
    case: str, *, existing_output: bool
) -> tuple[subprocess.CompletedProcess[str], dict[str, object]]:
    deploy_path = Path(__file__).with_name("mamba3_deploy.py")
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        checkpoint = root / "checkpoint.pt"
        checkpoint.write_bytes(b"authenticated-by-test-double")
        output = root / "existing-output.aimodel"
        sentinel = output / "keep-me"
        if existing_output:
            output.mkdir()
            sentinel.write_text("pre-existing-output", encoding="utf-8")
        quant_marker = root / "quantize-called"
        convert_marker = root / "convert-called"
        save_marker = root / "save-called"

        completed = subprocess.run(
            [
                sys.executable,
                "-O",
                "-c",
                textwrap.dedent(_OPTIMIZED_DEPLOY_DRIVER),
                case,
                str(deploy_path),
                str(checkpoint),
                str(output),
                str(quant_marker),
                str(convert_marker),
                str(save_marker),
            ],
            cwd=Path(__file__).parents[2],
            env={**os.environ, "PYTHONDONTWRITEBYTECODE": "1"},
            capture_output=True,
            text=True,
            timeout=10,
            check=False,
        )

        observed = {
            "output_exists": output.exists(),
            "sentinel": (
                sentinel.read_text(encoding="utf-8") if sentinel.exists() else None
            ),
            "quantized": quant_marker.exists(),
            "converted": convert_marker.exists(),
            "saved": save_marker.exists(),
        }
        return completed, observed


def _assert_optimized_deploy_refuses_incomplete_state(case: str) -> None:
    completed, observed = _run_optimized_deploy_case(case, existing_output=True)
    diagnostic = completed.stdout + completed.stderr
    expected = (
        "checkpoint has tensors DeployM lacks"
        if case == "unexpected"
        else "DeployM missing trained params"
    )
    assert completed.returncode != 0, diagnostic
    assert expected in diagnostic, diagnostic
    assert observed == {
        "output_exists": True,
        "sentinel": "pre-existing-output",
        "quantized": False,
        "converted": False,
        "saved": False,
    }


def _assert_optimized_deploy_accepts_decode_state(case: str) -> None:
    completed, observed = _run_optimized_deploy_case(case, existing_output=False)
    diagnostic = completed.stdout + completed.stderr
    assert completed.returncode == 0, diagnostic
    assert observed == {
        "output_exists": True,
        "sentinel": None,
        "quantized": True,
        "converted": True,
        "saved": True,
    }


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

    def test_optimized_deploy_refuses_unexpected_trained_keys_before_output(self) -> None:
        _assert_optimized_deploy_refuses_incomplete_state("unexpected")

    def test_optimized_deploy_refuses_missing_trained_keys_before_output(self) -> None:
        _assert_optimized_deploy_refuses_incomplete_state("missing")

    def test_optimized_deploy_accepts_only_registered_decode_state_buffers(
        self,
    ) -> None:
        for case in ("stack-decode-state", "separate-decode-state"):
            with self.subTest(case=case):
                _assert_optimized_deploy_accepts_decode_state(case)
        with self.subTest(case="spoofed-decode-state"):
            _assert_optimized_deploy_refuses_incomplete_state(
                "spoofed-decode-state"
            )

    def test_documented_shell_and_module_usage_are_shell_valid(self) -> None:
        runbook = _RUNBOOK_PATH.read_text(encoding="utf-8")
        scripts = _fenced_bash_scripts(runbook)
        scripts.append(_module_usage_script())
        self.assertGreaterEqual(len(scripts), 3)

        for index, script in enumerate(scripts):
            with self.subTest(script=index):
                self.assertEqual(
                    _unquoted_angle_placeholders(script),
                    [],
                    msg=f"unquoted shell placeholder in:\n{script}",
                )
                for shell in ("bash", "zsh"):
                    completed = subprocess.run(
                        [shell, "-n"],
                        input=script,
                        capture_output=True,
                        text=True,
                        check=False,
                    )
                    self.assertEqual(
                        completed.returncode,
                        0,
                        msg=(
                            f"{shell} rejected documented script #{index}: "
                            f"{completed.stderr}\n{script}"
                        ),
                    )

    def test_runbook_binds_reviewed_deploy_source_and_runs_source_guards(self) -> None:
        runbook = _RUNBOOK_PATH.read_text(encoding="utf-8")
        deploy_section = runbook.split("## Deploy back to the A19", 1)[1]
        required_fragments = (
            "QINAO_REVIEWED_DEPLOY_COMMIT",
            "QINAO_DEPLOY_CHECKOUT",
            "checkout --detach",
            "rev-parse HEAD",
            "merge-base --is-ancestor",
            "3f5f49b85822aa7272a3c5d173eacd7906896b21",
            "test_deploy_uses_candidate_local_verified_checkpoint_loader",
            "test_optimized_deploy_refuses_unexpected_trained_keys_before_output",
            "test_optimized_deploy_refuses_missing_trained_keys_before_output",
            "test_optimized_deploy_accepts_only_registered_decode_state_buffers",
        )
        for fragment in required_fragments:
            with self.subTest(fragment=fragment):
                self.assertIn(fragment, deploy_section)
        self.assertIn("only a training recipe source", deploy_section)
        deploy_scripts = _fenced_bash_scripts(deploy_section)
        self.assertTrue(
            any(
                re.search(r"(?m)^set -euo pipefail$", script)
                for script in deploy_scripts
            ),
            "deploy checks must stop conversion on the first failed guard",
        )
        for script in deploy_scripts:
            self.assertNotIn("ssd-track-g-distill-optimized", script)
        self.assertRegex(
            deploy_section,
            r"trusted release receipt[^\n]*(?:checkpoint|CKPT)[^\n]*(?:commit|source)|"
            r"trusted release receipt[^\n]*(?:commit|source)[^\n]*(?:checkpoint|CKPT)",
        )

    def test_documented_deploy_refuses_dirty_checkout_before_conversion(self) -> None:
        cases = {
            "tracked": 'printf "mutated\\n" >> README.md',
            "untracked-import-shadow": (
                'printf "shadow\\n" > BehavioralAISubstrate/Tools/torch.py'
            ),
            "ignored-import-shadow": (
                "printf 'BehavioralAISubstrate/Tools/torch.py\\n' "
                ">> .git/info/exclude\n"
                'printf "shadow\\n" > BehavioralAISubstrate/Tools/torch.py'
            ),
            "ignored-non-torch-import-shadow": (
                "printf 'BehavioralAISubstrate/Tools/coreai_torch.py\\n' "
                ">> .git/info/exclude\n"
                'printf "shadow\\n" '
                "> BehavioralAISubstrate/Tools/coreai_torch.py"
            ),
        }
        with tempfile.TemporaryDirectory() as directory:
            fixture = _DocumentedDeployFixture(Path(directory))
            for case, mutation in cases.items():
                with self.subTest(case=case):
                    completed, sentinel = fixture.run(after_checkout=mutation)
                    diagnostic = completed.stdout + completed.stderr
                    self.assertNotEqual(completed.returncode, 0, diagnostic)
                    self.assertFalse(
                        sentinel.exists(),
                        f"{case} reached conversion despite dirty checkout:\n{diagnostic}",
                    )

    def test_documented_deploy_propagates_git_status_failure(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            fixture = _DocumentedDeployFixture(Path(directory))
            for shell in ("bash", "zsh"):
                with self.subTest(shell=shell):
                    completed, sentinel = fixture.run(
                        fail_git_status=True, shell=shell
                    )
                    diagnostic = completed.stdout + completed.stderr
                    self.assertNotEqual(completed.returncode, 0, diagnostic)
                    self.assertFalse(
                        sentinel.exists(),
                        f"{shell} masked git status failure and converted:\n{diagnostic}",
                    )

    def test_documented_deploy_runs_identity_and_source_guards_before_conversion(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as directory:
            fixture = _DocumentedDeployFixture(Path(directory))
            cases = {
                "wrong-exact-head": {
                    "after_checkout": (
                        'git checkout --detach "$QINAO_DEPLOY_SECURITY_FLOOR"'
                    )
                },
                "nonancestor": {"reviewed_commit": fixture.nonancestor_commit},
                **{
                    f"source-guard:{guard}": {"reviewed_commit": commit}
                    for guard, commit in fixture.guard_failure_commits.items()
                },
            }
            for case, arguments in cases.items():
                with self.subTest(case=case):
                    completed, sentinel = fixture.run(**arguments)
                    diagnostic = completed.stdout + completed.stderr
                    self.assertNotEqual(completed.returncode, 0, diagnostic)
                    self.assertFalse(
                        sentinel.exists(),
                        f"{case} reached conversion before its guard:\n{diagnostic}",
                    )

    def test_documented_deploy_rechecks_cleanliness_after_preflight(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            fixture = _DocumentedDeployFixture(Path(directory))
            completed, sentinel = fixture.run(
                reviewed_commit=fixture.post_preflight_dirty_commit
            )
            diagnostic = completed.stdout + completed.stderr
            self.assertNotEqual(completed.returncode, 0, diagnostic)
            self.assertFalse(
                sentinel.exists(),
                f"guard-created dirt reached conversion:\n{diagnostic}",
            )

    def test_documented_deploy_valid_current_head_reaches_conversion(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            fixture = _DocumentedDeployFixture(Path(directory))
            for shell in ("bash", "zsh"):
                with self.subTest(shell=shell):
                    completed, sentinel = fixture.run(shell=shell)
                    diagnostic = completed.stdout + completed.stderr
                    self.assertEqual(completed.returncode, 0, diagnostic)
                    self.assertEqual(
                        sentinel.read_text(encoding="utf-8"),
                        "conversion reached\n",
                    )

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
