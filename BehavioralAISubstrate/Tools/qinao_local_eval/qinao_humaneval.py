"""#30 HumanEval pass@1 with current-run receipt-bound evidence.

Usage: python qinao_humaneval.py <model> <adapter|none> <tag> [N]
"""

from __future__ import annotations

import os
import random
import re
import subprocess
import sys
import tempfile
import textwrap

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
from qinao_sandbox import run_sandboxed


PYBIN = os.path.expanduser("~/qwen_honesty_finetune/.venv/bin/python")


def extract_code(response: str) -> str:
    match = re.search(r"```(?:python)?\s*(.*?)```", response, re.S)
    return match.group(1) if match else response


def assemble_generated_function(prompt: str, code: str, entry_point: str) -> str:
    """Join a body-only completion without creating ``return outside function``."""

    if f"def {entry_point}" in code:
        return code
    body = code
    stripped = body.lstrip("\n")
    if stripped and not stripped.startswith((" ", "\t")):
        body = textwrap.indent(body, "    ")
    return prompt + body


def main() -> None:
    if len(sys.argv) < 4:
        raise SystemExit("usage: qinao_humaneval.py <model> <adapter|none> <tag> [N]")
    model_selector = sys.argv[1]
    adapter_selector = sys.argv[2] if sys.argv[2] != "none" else None
    tag = sys.argv[3]
    raw_sample_limit = sys.argv[4] if len(sys.argv) > 4 else None

    producer = HumanEvalProducer.STANDARD
    context = load_humaneval_run_context_from_env(required_tags=(tag,))
    output = prepare_humaneval_output(context, producer, tag)
    context.require_invocation(tag, model=model_selector, adapter=adapter_selector)
    sample_limit = validated_sample_limit(raw_sample_limit, default=60)

    # Heavy dependencies are deliberately imported only after the old output
    # has been removed. A crash/import failure therefore cannot replay success.
    from datasets import load_dataset
    from mlx_lm import generate, load

    try:
        from mlx_lm.sample_utils import make_sampler

        greedy = make_sampler(temp=0.0)
    except Exception:
        greedy = None

    dataset = load_dataset(DATASET_ID, split=DATASET_SPLIT)
    # This reads the dataset object's actual materialized fingerprint. The env
    # value is only the expected external receipt and is never copied blindly.
    context.require_dataset_fingerprint(getattr(dataset, "_fingerprint", None))
    model, tokenizer = load(model_selector, adapter_path=adapter_selector)

    def ask(prompt: str, max_tokens: int = 512) -> str:
        messages = [{"role": "user", "content": prompt}]
        try:
            rendered = tokenizer.apply_chat_template(
                messages,
                add_generation_prompt=True,
                enable_thinking=False,
            )
        except TypeError:
            rendered = tokenizer.apply_chat_template(
                messages, add_generation_prompt=True
            )
        arguments = {"max_tokens": max_tokens, "verbose": False}
        if greedy is not None:
            arguments["sampler"] = greedy
        return generate(model, tokenizer, prompt=rendered, **arguments)

    indices = list(range(len(dataset)))
    random.seed(2)
    random.shuffle(indices)
    indices = indices[:sample_limit]

    passed_count = total_count = infrastructure_errors = 0
    counted_sample_ids: list[str] = []
    for index in indices:
        row = dataset[index]
        task_id = row["task_id"]
        entry_point = row["entry_point"]
        response = ask(
            "Complete this Python function. Return ONLY the full function in a "
            "```python code block```:\n\n" + row["prompt"]
        )
        code = extract_code(response)
        code = assemble_generated_function(row["prompt"], code, entry_point)
        program = code + "\n" + row["test"] + f"\ncheck({entry_point})\n"
        path = None
        try:
            with tempfile.NamedTemporaryFile("w", suffix=".py", delete=False) as handle:
                handle.write(program)
                path = handle.name
            result = run_sandboxed(PYBIN, path)
            total_count += 1
            counted_sample_ids.append(task_id)
            passed_count += result.returncode == 0
        except subprocess.TimeoutExpired:
            total_count += 1
            counted_sample_ids.append(task_id)
        except Exception as error:
            infrastructure_errors += 1
            sys.stderr.write(
                "qinao_humaneval: harness error (not a model failure) "
                f"on task {index}: {error}\n"
            )
        finally:
            if path:
                try:
                    os.unlink(path)
                except OSError:
                    pass

    evidence = build_humaneval_evidence(
        passed=passed_count,
        total=total_count,
        infra_errors=infrastructure_errors,
        sample_ids=counted_sample_ids,
        producer=producer,
        context=context,
        tag=tag,
    )
    atomic_write_humaneval_evidence(output, evidence)
    score = f"{evidence['30']}%" if "30" in evidence else "UNAVAILABLE"
    suffix = (
        f"  ({infrastructure_errors} task(s) EXCLUDED — harness/infra error, "
        "not model failures)"
        if infrastructure_errors
        else ""
    )
    print(f"{tag} HumanEval pass@1 = {passed_count}/{total_count} = {score}{suffix}")


if __name__ == "__main__":
    main()
