"""QINAO Chinese benchmark panel (#31 C-Eval, #32 CMMLU) — MCQ auto-scorable.
Usage: python qinao_bench_zh.py <model> <adapter|none> <tag> [N]
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
N = int(sys.argv[4]) if len(sys.argv)>4 else 150
model, tok = load(mpath, adapter_path=adapter)
def ask(u, mx=12):
    try: p=tok.apply_chat_template([{"role":"user","content":u}],add_generation_prompt=True,enable_thinking=False)
    except TypeError: p=tok.apply_chat_template([{"role":"user","content":u}],add_generation_prompt=True)
    kw={"max_tokens":mx,"verbose":False}
    if GREEDY is not None: kw["sampler"]=GREEDY
    return generate(model,tok,prompt=p,**kw)
def letter(s):
    m=re.search(r'[\(\s]?([A-D])[\)\.\s。]', " "+s+" "); return m.group(1) if m else None
out={}
def run_mcq(rows, qk, akey, optkeys, seed):
    idx=list(range(len(rows))); random.seed(seed); random.shuffle(idx); idx=idx[:N]
    ok=tot=0
    for i in idx:
        r=rows[i]
        body="\n".join(f"({k}) {r[k]}" for k in optkeys if r.get(k) not in (None,""))
        gold=str(r[akey]).strip().upper()[:1]
        a=letter(ask(f"{r[qk]}\n{body}\n只用一个字母回答正确选项。"))
        tot+=1; ok+=(a==gold)
    return round(ok/max(1,tot)*100,1)
# #31 C-Eval (val split has answers)
try:
    ds=load_dataset("ceval/ceval-exam", "computer_network", split="val")  # one subject as a quick proxy; broaden later
    rows=[ds[i] for i in range(len(ds))]
    # gather a few subjects for breadth
    for sub in ["high_school_physics","logic","high_school_chemistry","college_economics"]:
        try:
            d2=load_dataset("ceval/ceval-exam", sub, split="val"); rows+=[d2[i] for i in range(len(d2))]
        except Exception: pass
    out["31"]=run_mcq(rows, "question", "answer", ["A","B","C","D"], 3)
except Exception as e:
    out["31_err"]=str(e)[:140]
# #32 CMMLU
try:
    ds=load_dataset("haonan-li/cmmlu", "logical", split="test")
    rows=[ds[i] for i in range(len(ds))]
    for sub in ["college_medicine","chinese_history","computer_science","elementary_mathematics"]:
        try:
            d2=load_dataset("haonan-li/cmmlu", sub, split="test"); rows+=[d2[i] for i in range(len(d2))]
        except Exception: pass
    out["32"]=run_mcq(rows, "Question", "Answer", ["A","B","C","D"], 4)
except Exception as e:
    out["32_err"]=str(e)[:140]
json.dump(out, open(f"/tmp/qinao_bench_zh_{tag}.json","w"), indent=1)
print(f"{tag} zh-bench: C-Eval={out.get('31')} CMMLU={out.get('32')} {out.get('31_err','')}{out.get('32_err','')}")
