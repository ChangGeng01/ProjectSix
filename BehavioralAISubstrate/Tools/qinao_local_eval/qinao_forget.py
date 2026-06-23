"""QINAO #38 catastrophic_forget (item-level MMLU) + #32 CMMLU (raw CSV, dodges loader-script block).
Per-model: writes per-item MMLU correctness + CMMLU score. Merge step computes forget.
Usage: python qinao_forget.py <model> <adapter|none> <tag> [N]
"""
import json, re, sys, random
from mlx_lm import load, generate
from datasets import load_dataset
from huggingface_hub import hf_hub_download
import pandas as pd
try:
    from mlx_lm.sample_utils import make_sampler; GREEDY = make_sampler(temp=0.0)
except Exception: GREEDY = None
mpath, adapter, tag = sys.argv[1], (sys.argv[2] if sys.argv[2]!="none" else None), sys.argv[3]
N = int(sys.argv[4]) if len(sys.argv)>4 else 120
model, tok = load(mpath, adapter_path=adapter)
def ask(u, mx=12):
    try: p=tok.apply_chat_template([{"role":"user","content":u}],add_generation_prompt=True,enable_thinking=False)
    except TypeError: p=tok.apply_chat_template([{"role":"user","content":u}],add_generation_prompt=True)
    kw={"max_tokens":mx,"verbose":False}
    if GREEDY is not None: kw["sampler"]=GREEDY
    return generate(model,tok,prompt=p,**kw)
def letter(s, alph="ABCD"):
    m=re.search(rf'[\(\s]?([{alph}])[\)\.\s。]', " "+s+" "); return m.group(1) if m else None
LET="ABCD"
# per-item MMLU correctness (fixed seed -> identical items across models)
ds=load_dataset("cais/mmlu","all",split="test")
idx=list(range(len(ds))); random.seed(0); random.shuffle(idx); idx=idx[:N]
peritem={}
for i in idx:
    r=ds[i]; ch=r["choices"]; ci=r["answer"]
    if len(ch)!=4: continue
    body="\n".join(f"({LET[j]}) {c}" for j,c in enumerate(ch))
    a=letter(ask(f"{r['question']}\n{body}\nAnswer with just the letter."))
    peritem[str(i)]=int(a==LET[ci])
# CMMLU via raw CSV (dodge loader script)
cm=None
try:
    rows=[]
    for sub in ["logical","college_medicine","chinese_history","computer_science","elementary_mathematics"]:
        try:
            p=hf_hub_download("haonan-li/cmmlu", f"test/{sub}.csv", repo_type="dataset")
            rows.append(pd.read_csv(p))
        except Exception: pass
    if rows:
        df=pd.concat(rows, ignore_index=True); df=df.sample(min(N,len(df)), random_state=4)
        ok=tot=0
        for _,r in df.iterrows():
            body="\n".join(f"({k}) {r[k]}" for k in LET if k in r)
            gold=str(r["Answer"]).strip().upper()[:1]
            a=letter(ask(f"{r['Question']}\n{body}\n只用一个字母回答。"))
            tot+=1; ok+=(a==gold)
        cm=round(ok/max(1,tot)*100,1)
except Exception as e:
    cm=f"err:{str(e)[:80]}"
json.dump({"mmlu_peritem":peritem, "cmmlu":cm}, open(f"/tmp/qinao_forget_{tag}.json","w"))
print(f"{tag}: MMLU items {sum(peritem.values())}/{len(peritem)} | CMMLU={cm}")
