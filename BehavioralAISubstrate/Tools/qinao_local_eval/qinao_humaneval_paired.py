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

import os
import re
import sys
import random
import subprocess
import tempfile

from qinao_sandbox import run_sandboxed
from qinao_humaneval import assemble_generated_function
from qinao_humaneval_evidence import (
    DATASET_ID,
    DATASET_SPLIT,
    HumanEvalProducer,
    atomic_write_humaneval_evidence,
    build_humaneval_evidence,
    load_humaneval_run_context_from_env,
    prepare_humaneval_output,
    validated_sample_limit,
)

PYBIN = os.path.expanduser("~/qwen_honesty_finetune/.venv/bin/python")


def execute_generated_program(pybin: str, script_path: str, timeout: int = 15):
    return run_sandboxed(pybin, script_path, timeout=timeout)


def counts_toward_denominator(outcome: str) -> bool:
    """audit tools-scripts LOW / decision 7 — only an execution that actually RAN the model's code
    (returned a result, or timed out = a legitimate wrong answer) counts toward the pass@1
    denominator. An INFRA failure (e.g. PYBIN missing, subprocess spawn error) must be EXCLUDED —
    otherwise a broken harness scores a false 0% capability. Mirrors the fix already shipped in the
    sibling qinao_humaneval.py (commit 13afefed8), which this paired variant had missed.
    Kinds: 'ran', 'timeout' -> True; 'infra' -> False."""
    return outcome in ("ran", "timeout")


def main() -> None:
    mp = sys.argv[1]
    ad = sys.argv[2] if len(sys.argv) > 2 and sys.argv[2] != "none" else None
    tag = sys.argv[3]
    raw_sample_limit = sys.argv[4] if len(sys.argv) > 4 else None

    producer = HumanEvalProducer.PAIRED
    context = load_humaneval_run_context_from_env(required_tags=(tag,))
    output = prepare_humaneval_output(context, producer, tag)
    context.require_invocation(tag, model=mp, adapter=ad)
    n = validated_sample_limit(raw_sample_limit, default=164)

    # audit tools-scripts LOW: heavy deps imported LAZILY (inside main) so the module — and its pure
    # helper counts_toward_denominator — can be imported for unit tests without mlx_lm/datasets present.
    # The current output was invalidated before these imports, so an import/model crash cannot replay it.
    from mlx_lm import load, generate
    from datasets import load_dataset

    try:
        from mlx_lm.sample_utils import make_sampler

        GREEDY = make_sampler(temp=0.0)
    except Exception:
        GREEDY = None

    ds = load_dataset(DATASET_ID, split=DATASET_SPLIT)
    # Compare the materialized dataset's actual fingerprint with the external
    # current-run receipt before loading the model.
    context.require_dataset_fingerprint(getattr(ds, "_fingerprint", None))
    model, tok = load(mp, adapter_path=ad)

    def ask(u: str, mx: int = 512) -> str:
        try:
            p = tok.apply_chat_template(
                [{"role": "user", "content": u}],
                add_generation_prompt=True,
                enable_thinking=False,
            )
        except TypeError:
            p = tok.apply_chat_template(
                [{"role": "user", "content": u}], add_generation_prompt=True
            )
        kw = {"max_tokens": mx, "verbose": False}
        if GREEDY is not None:
            kw["sampler"] = GREEDY
        return generate(model, tok, prompt=p, **kw)

    def extract_code(resp: str) -> str:
        m = re.search(r"```(?:python)?\s*(.*?)```", resp, re.S)
        return m.group(1) if m else resp

    idx = list(range(len(ds)))
    random.seed(2)
    random.shuffle(idx)
    idx = idx[:n]

    per: dict[str, int] = {}
    ok = tot = infra_errs = 0
    for i in idx:
        r = ds[i]
        entry = r["entry_point"]
        resp = ask(
            "Complete this Python function. Return ONLY the full function in a ```python code block```:\n\n"
            + r["prompt"]
        )
        code = extract_code(resp)
        program = (
            assemble_generated_function(r["prompt"], code, entry)
            + "\n"
            + r["test"]
            + f"\ncheck({entry})\n"
        )
        passed = 0
        outcome = "infra"
        path = None
        try:
            with tempfile.NamedTemporaryFile("w", suffix=".py", delete=False) as f:
                f.write(program)
                path = f.name
            res = execute_generated_program(PYBIN, path, timeout=15)
            passed = int(res.returncode == 0)
            outcome = "ran"
        except subprocess.TimeoutExpired:
            passed = 0
            outcome = "timeout"  # a hung program is a legitimate wrong answer
        except Exception as e:
            # audit tools-scripts LOW / decision 7: an INFRA failure (e.g. PYBIN missing) is NOT a
            # model wrong answer — it used to be `except: pass`-swallowed with an unconditional
            # `tot += 1`, scoring a broken harness as a false 0%. Surface it + EXCLUDE it.
            passed = 0
            outcome = "infra"
            sys.stderr.write(
                f"qinao_humaneval_paired: harness error (not a model failure) on task {i}: {e}\n"
            )
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

    out = build_humaneval_evidence(
        passed=ok,
        total=tot,
        infra_errors=infra_errs,
        per_problem=per,
        sample_ids=list(per),
        producer=producer,
        context=context,
        tag=tag,
    )
    atomic_write_humaneval_evidence(output, out)
    score = f"{out['30']}%" if "30" in out else "UNAVAILABLE"
    print(
        f"{tag} HumanEval(paired,fixed) pass@1 = {ok}/{tot} = {score}"
        + (
            f"  ({infra_errs} task(s) EXCLUDED — harness/infra error, not model failures)"
            if infra_errs
            else ""
        )
    )


if __name__ == "__main__":
    main()
