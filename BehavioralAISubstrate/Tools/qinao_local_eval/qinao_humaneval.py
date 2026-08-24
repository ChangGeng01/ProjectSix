"""#30 HumanEval pass@1 with a subprocess code-execution sandbox.
Generates a completion per problem, runs prompt+completion+test in an isolated
subprocess with a timeout. Usage: python qinao_humaneval.py <model> <adapter|none> <tag> [N]"""
import json, re, sys, random, subprocess, tempfile, os

from qinao_sandbox import run_sandboxed
from qinao_humaneval_evidence import build_humaneval_evidence

from mlx_lm import load, generate
try:
    from mlx_lm.sample_utils import make_sampler; GREEDY=make_sampler(temp=0.0)
except Exception: GREEDY=None
from datasets import load_dataset
mp, ad, tag = sys.argv[1], (sys.argv[2] if sys.argv[2]!="none" else None), sys.argv[3]
N=int(sys.argv[4]) if len(sys.argv)>4 else 60
PYBIN=os.path.expanduser("~/qwen_honesty_finetune/.venv/bin/python")
model, tok = load(mp, adapter_path=ad)
def ask(u, mx=512):
    try: p=tok.apply_chat_template([{"role":"user","content":u}],add_generation_prompt=True,enable_thinking=False)
    except TypeError: p=tok.apply_chat_template([{"role":"user","content":u}],add_generation_prompt=True)
    kw={"max_tokens":mx,"verbose":False}
    if GREEDY is not None: kw["sampler"]=GREEDY
    return generate(model,tok,prompt=p,**kw)
def extract_code(resp, entry):
    m=re.search(r"```(?:python)?\s*(.*?)```", resp, re.S)
    code=m.group(1) if m else resp
    return code
ds=load_dataset("openai/openai_humaneval", split="test")
idx=list(range(len(ds))); random.seed(2); random.shuffle(idx); idx=idx[:N]
ok=tot=infra_errs=0
for i in idx:
    r=ds[i]; entry=r["entry_point"]
    resp=ask("Complete this Python function. Return ONLY the full function in a ```python code block```:\n\n"+r["prompt"])
    code=extract_code(resp, entry)
    if f"def {entry}" not in code: code=r["prompt"]+code  # model returned only the body
    program=code+"\n"+r["test"]+f"\ncheck({entry})\n"
    path=None
    try:
        with tempfile.NamedTemporaryFile("w", suffix=".py", delete=False) as f:
            f.write(program); path=f.name
        # audit tools-scripts / decision 7 + LOW follow-up (2026-07-11): -I isolation PLUS the
        # seatbelt sandbox — the "real sandbox" follow-up, landed (see run_sandboxed above).
        res=run_sandboxed(PYBIN, path)
        tot+=1                      # counted only when the harness actually RAN the code
        ok+=(res.returncode==0)
    except subprocess.TimeoutExpired:
        tot+=1                      # generated code hung → a legitimate wrong answer
    except Exception as e:
        # audit tools-scripts / decision 7: an INFRA failure (e.g. PYBIN missing) is NOT a model wrong
        # answer — it used to be `except: pass`-swallowed and scored as one (a broken harness → a false
        # 0% capability). Surface it + EXCLUDE it from the denominator.
        infra_errs+=1
        sys.stderr.write(f"qinao_humaneval: harness error (not a model failure) on task {i}: {e}\n")
    finally:
        if path:
            try: os.unlink(path)
            except Exception: pass
out=build_humaneval_evidence(passed=ok,total=tot,infra_errors=infra_errs)
json.dump(out, open(f"/tmp/qinao_humaneval_{tag}.json","w"))
score=f"{out['30']}%" if "30" in out else "UNAVAILABLE"
print(f"{tag} HumanEval pass@1 = {ok}/{tot} = {score}"
      + (f"  ({infra_errs} task(s) EXCLUDED — harness/infra error, not model failures)" if infra_errs else ""))
