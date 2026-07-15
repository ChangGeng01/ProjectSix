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

PYBIN = os.path.expanduser("~/qwen_honesty_finetune/.venv/bin/python")


def counts_toward_denominator(outcome: str) -> bool:
    """audit tools-scripts LOW / decision 7 — only an execution that actually RAN the model's code
    (returned a result, or timed out = a legitimate wrong answer) counts toward the pass@1
    denominator. An INFRA failure (e.g. PYBIN missing, subprocess spawn error) must be EXCLUDED —
    otherwise a broken harness scores a false 0% capability. Mirrors the fix already shipped in the
    sibling qinao_humaneval.py (commit 13afefed8), which this paired variant had missed.
    Kinds: 'ran', 'timeout' -> True; 'infra' -> False."""
    return outcome in ("ran", "timeout")


def main() -> None:
    # audit tools-scripts LOW: heavy deps imported LAZILY (inside main) so the module — and its pure
    # helper counts_toward_denominator — can be imported for unit tests without mlx_lm/datasets present.
    from mlx_lm import load, generate
    from datasets import load_dataset
    try:
        from mlx_lm.sample_utils import make_sampler
        GREEDY = make_sampler(temp=0.0)
    except Exception:
        GREEDY = None

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
    ok = tot = infra_errs = 0
    for i in idx:
        r = ds[i]
        entry = r["entry_point"]
        resp = ask("Complete this Python function. Return ONLY the full function in a ```python code block```:\n\n" + r["prompt"])
        code = extract_code(resp)
        program = assemble(r["prompt"], code, entry) + "\n" + r["test"] + f"\ncheck({entry})\n"
        passed = 0
        outcome = "infra"
        path = None
        try:
            with tempfile.NamedTemporaryFile("w", suffix=".py", delete=False) as f:
                f.write(program)
                path = f.name
            # audit tools-scripts LOW / decision 7: -I isolated mode (ignore env / user site-packages)
            # hardens the exec of model-generated code a little (a real sandbox is the follow-up).
            res = subprocess.run([PYBIN, "-I", path], capture_output=True, timeout=15)
            passed = int(res.returncode == 0)
            outcome = "ran"
        except subprocess.TimeoutExpired:
            passed = 0
            outcome = "timeout"   # a hung program is a legitimate wrong answer
        except Exception as e:
            # audit tools-scripts LOW / decision 7: an INFRA failure (e.g. PYBIN missing) is NOT a
            # model wrong answer — it used to be `except: pass`-swallowed with an unconditional
            # `tot += 1`, scoring a broken harness as a false 0%. Surface it + EXCLUDE it.
            passed = 0
            outcome = "infra"
            sys.stderr.write(f"qinao_humaneval_paired: harness error (not a model failure) on task {i}: {e}\n")
        finally:
            if path:
                try:
                    os.unlink(path)
                except Exception:
                    pass
        if counts_toward_denominator(outcome):
            per[r["task_id"]] = passed
            ok += passed
            tot += 1
        else:
            infra_errs += 1

    sc = round(ok / max(1, tot) * 100, 1)
    out = {"30": sc, "_N": tot, "per_problem": per}
    if infra_errs:
        out["_infra_errs"] = infra_errs
    json.dump(out, open(f"/tmp/qinao_humaneval_paired_{tag}.json", "w"))
    print(f"{tag} HumanEval(paired,fixed) pass@1 = {ok}/{tot} = {sc}%"
          + (f"  ({infra_errs} task(s) EXCLUDED — harness/infra error, not model failures)" if infra_errs else ""))


if __name__ == "__main__":
    main()
