"""#32 CMMLU (Chinese MMLU) via extracted CSVs (dodges the unsupported loader script).
Reads ~/qwen_honesty_finetune/cmmlu_data/test/*.csv. Usage: python qinao_cmmlu.py <model> <adapter|none> <tag> [N]"""
import json, re, sys, random, glob, os
import pandas as pd
from mlx_lm import load, generate
try:
    from mlx_lm.sample_utils import make_sampler; GREEDY=make_sampler(temp=0.0)
except Exception: GREEDY=None
mp, ad, tag = sys.argv[1], (sys.argv[2] if sys.argv[2]!="none" else None), sys.argv[3]
N=int(sys.argv[4]) if len(sys.argv)>4 else 120
model, tok = load(mp, adapter_path=ad)
def ask(u, mx=12):
    try: p=tok.apply_chat_template([{"role":"user","content":u}],add_generation_prompt=True,enable_thinking=False)
    except TypeError: p=tok.apply_chat_template([{"role":"user","content":u}],add_generation_prompt=True)
    kw={"max_tokens":mx,"verbose":False}
    if GREEDY is not None: kw["sampler"]=GREEDY
    return generate(model,tok,prompt=p,**kw)
def letter(s):
    m=re.search(r'[\(\s]?([A-D])[\)\.\s。]'," "+s+" "); return m.group(1) if m else None
csvs=sorted(glob.glob(os.path.expanduser("~/qwen_honesty_finetune/cmmlu_data/test/*.csv")))
rows=[]
for c in csvs:
    df=pd.read_csv(c)
    for _,r in df.iterrows(): rows.append(r)
random.seed(4); random.shuffle(rows); rows=rows[:N]
ok=tot=0
for r in rows:
    body="\n".join(f"({k}) {r[k]}" for k in "ABCD" if k in r)
    gold=str(r["Answer"]).strip().upper()[:1]
    a=letter(ask(f"{r['Question']}\n{body}\n只用一个字母回答。"))
    tot+=1; ok+=(a==gold)
sc=round(ok/max(1,tot)*100,1)
json.dump({"32":sc,"_N":tot}, open(f"/tmp/qinao_cmmlu_{tag}.json","w"))
print(f"{tag} CMMLU = {ok}/{tot} = {sc}%")
