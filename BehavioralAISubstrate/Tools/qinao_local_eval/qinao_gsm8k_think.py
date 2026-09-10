"""#29 GSM8K with chain-of-thought (the legitimate capability measurement — the no-think
floor was an artifact). enable_thinking=True + room for reasoning; final-number match.
Same seed/N as qinao_bench so it's directly comparable. Usage: python qinao_gsm8k_think.py <model> <adapter|none> <tag> [N]"""
import json, re, sys, random
from mlx_lm import load, generate
try:
    from mlx_lm.sample_utils import make_sampler; GREEDY=make_sampler(temp=0.0)
except Exception: GREEDY=None
from datasets import load_dataset
mp, ad, tag = sys.argv[1], (sys.argv[2] if sys.argv[2]!="none" else None), sys.argv[3]
N=int(sys.argv[4]) if len(sys.argv)>4 else 150
model, tok = load(mp, adapter_path=ad)
def ask(u, mx=640):
    try: p=tok.apply_chat_template([{"role":"user","content":u}],add_generation_prompt=True,enable_thinking=True)
    except TypeError: p=tok.apply_chat_template([{"role":"user","content":u}],add_generation_prompt=True)
    kw={"max_tokens":mx,"verbose":False}
    if GREEDY is not None: kw["sampler"]=GREEDY
    return generate(model,tok,prompt=p,**kw)
ds=load_dataset("openai/gsm8k","main",split="test")
idx=list(range(len(ds))); random.seed(1); random.shuffle(idx); idx=idx[:N]
ok=tot=0
for i in idx:
    r=ds[i]; gold=r["answer"].split("####")[-1].strip().replace(",","")
    resp=ask(r["question"]+"\nSolve step by step, then give the final answer.")
    # prefer an explicit 'answer is X' / '#### X', else last number
    m=re.findall(r'(?:answer\s*(?:is|:)?\s*|####\s*)(-?\d[\d,]*\.?\d*)', resp, re.I)
    nums=m if m else re.findall(r'-?\d[\d,]*\.?\d*', resp.replace(",",""))
    tot+=1; ok+=(bool(nums) and nums[-1].replace(",","").rstrip(".")==gold)
sc=round(ok/max(1,tot)*100,1)
json.dump({"29_think":sc,"_N":tot}, open(f"/tmp/qinao_gsm8k_think_{tag}.json","w"))
print(f"{tag} GSM8K(think) = {ok}/{tot} = {sc}%")
