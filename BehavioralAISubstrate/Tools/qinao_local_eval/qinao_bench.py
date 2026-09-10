"""QINAO capability benchmark panel (#28 MMLU, #29 GSM8K) — the mandatory regression guard.
Samples each benchmark, scores base vs adapter, auto-scorable. Writes /tmp/qinao_bench_<tag>.json.
Usage: python qinao_bench.py <model> <adapter|none> <tag> [N_per_bench]
"""
import json, re, sys, random
from mlx_lm import load, generate
from datasets import load_dataset
try:
    from mlx_lm.sample_utils import make_sampler
    GREEDY = make_sampler(temp=0.0)
except Exception:
    GREEDY = None
mpath, adapter, tag = sys.argv[1], (sys.argv[2] if sys.argv[2]!="none" else None), sys.argv[3]
NB = int(sys.argv[4]) if len(sys.argv)>4 else 150
model, tok = load(mpath, adapter_path=adapter)
def ask(u, mx=12):
    try: p=tok.apply_chat_template([{"role":"user","content":u}],add_generation_prompt=True,enable_thinking=False)
    except TypeError: p=tok.apply_chat_template([{"role":"user","content":u}],add_generation_prompt=True)
    kw={"max_tokens":mx,"verbose":False}
    if GREEDY is not None: kw["sampler"]=GREEDY
    return generate(model,tok,prompt=p,**kw)
def letter(s):
    m=re.search(r'[\(\s]([A-D])[\)\.\s]'," "+s+" "); return m.group(1) if m else None
out={}
LET="ABCD"
# ---- #28 MMLU (sample across subjects) ----
try:
    ds=load_dataset("cais/mmlu","all",split="test")
    idx=list(range(len(ds))); random.seed(0); random.shuffle(idx); idx=idx[:NB]
    ok=0; tot=0
    for i in idx:
        r=ds[i]; ch=r["choices"]; ci=r["answer"]
        if len(ch)!=4: continue
        body="\n".join(f"({LET[j]}) {c}" for j,c in enumerate(ch))
        a=letter(ask(f"{r['question']}\n{body}\nAnswer with just the letter."))
        tot+=1; ok+=(a==LET[ci])
    out["28"]=round(ok/max(1,tot)*100,1)
except Exception as e:
    out["28_err"]=str(e)[:120]
# ---- #29 GSM8K (final-number match) ----
try:
    ds=load_dataset("openai/gsm8k","main",split="test")
    idx=list(range(len(ds))); random.seed(1); random.shuffle(idx); idx=idx[:NB]
    ok=0; tot=0
    for i in idx:
        r=ds[i]; gold=r["answer"].split("####")[-1].strip().replace(",","")
        resp=ask(r["question"]+"\nGive only the final numeric answer.", mx=24)
        nums=re.findall(r'-?\d[\d,]*\.?\d*', resp.replace(",",""))
        tot+=1; ok+=(bool(nums) and nums[-1].rstrip(".")==gold)
    out["29"]=round(ok/max(1,tot)*100,1)
except Exception as e:
    out["29_err"]=str(e)[:120]
json.dump(out, open(f"/tmp/qinao_bench_{tag}.json","w"), indent=1)
print(f"{tag} bench: MMLU={out.get('28')} GSM8K={out.get('29')} {out.get('28_err','')}{out.get('29_err','')}")
