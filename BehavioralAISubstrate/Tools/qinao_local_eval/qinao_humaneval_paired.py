"""#30 HumanEval pass@1 with PER-PROBLEM logging (for paired McNemar tests) + the
indentation false-FAIL fix the 2026-06-25 audit found in qinao_humaneval.py:line 31.

Two fixes vs qinao_humaneval.py:
 1. Body-only completions are indented under the prompt signature before gluing (the old
    `code = prompt + code` produced 'return outside function' SyntaxErrors for unindented bodies,
    a false-FAIL that could asymmetrically bias the v9-vs-v12 delta).
 2. Writes the full per-problem pass vector {task_id: 0/1} so a McNemar paired test is computable
    (the old harness saved only the aggregate scalar -> the +5.5 delta was unverifiable).

Greedy/deterministic, N=164 full set (seed 2, order-invariant). Same subprocess sandbox + 15s timeout.
Usage: python qinao_humaneval_paired.py <model> <adapter|none> <tag> [N]
"""
from __future__ import annotations

import json
import os
import re
import sys
import random
import textwrap
import subprocess
import tempfile

from mlx_lm import load, generate
from datasets import load_dataset

try:
    from mlx_lm.sample_utils import make_sampler
    GREEDY = make_sampler(temp=0.0)
except Exception:  # pragma: no cover
    GREEDY = None

PYBIN = os.path.expanduser("~/qwen_honesty_finetune/.venv/bin/python")


def main() -> None:
    mp = sys.argv[1]
    ad = sys.argv[2] if len(sys.argv) > 2 and sys.argv[2] != "none" else None
    tag = sys.argv[3]
    n = int(sys.argv[4]) if len(sys.argv) > 4 else 164

    model, tok = load(mp, adapter_path=ad)

    def ask(u: str, mx: int = 512) -> str:
        try:
            p = tok.apply_chat_template([{"role": "user", "content": u}], add_generation_prompt=True, enable_thinking=False)
        except TypeError:
            p = tok.apply_chat_template([{"role": "user", "content": u}], add_generation_prompt=True)
        kw = {"max_tokens": mx, "verbose": False}
        if GREEDY is not None:
            kw["sampler"] = GREEDY
        return generate(model, tok, prompt=p, **kw)

    def extract_code(resp: str) -> str:
        m = re.search(r"```(?:python)?\s*(.*?)```", resp, re.S)
        return m.group(1) if m else resp

    def assemble(prompt: str, code: str, entry: str) -> str:
        """Robust assembly that fixes the line-31 indentation false-FAIL."""
        if f"def {entry}" in code:
            return code  # model returned a full function
        body = code
        # body-only: indent under the prompt signature if it isn't already indented
        stripped = body.lstrip("\n")
        if stripped and not stripped.startswith((" ", "\t")):
            body = textwrap.indent(body, "    ")
        return prompt + body

    ds = load_dataset("openai/openai_humaneval", split="test")
    idx = list(range(len(ds)))
    random.seed(2)
    random.shuffle(idx)
    idx = idx[:n]

    per: dict[str, int] = {}
    ok = tot = 0
    for i in idx:
        r = ds[i]
        entry = r["entry_point"]
        resp = ask("Complete this Python function. Return ONLY the full function in a ```python code block```:\n\n" + r["prompt"])
        code = extract_code(resp)
        program = assemble(r["prompt"], code, entry) + "\n" + r["test"] + f"\ncheck({entry})\n"
        passed = 0
        path = None
        try:
            with tempfile.NamedTemporaryFile("w", suffix=".py", delete=False) as f:
                f.write(program)
                path = f.name
            res = subprocess.run([PYBIN, path], capture_output=True, timeout=15)
            passed = int(res.returncode == 0)
        except Exception:
            passed = 0
        finally:
            if path:
                try:
                    os.unlink(path)
                except Exception:
                    pass
        per[r["task_id"]] = passed
        ok += passed
        tot += 1

    sc = round(ok / max(1, tot) * 100, 1)
    json.dump({"30": sc, "_N": tot, "per_problem": per}, open(f"/tmp/qinao_humaneval_paired_{tag}.json", "w"))
    print(f"{tag} HumanEval(paired,fixed) pass@1 = {ok}/{tot} = {sc}%")


if __name__ == "__main__":
    main()
