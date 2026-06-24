"""#29 GSM8K — FAIR single harness (audit fix): CoT, max_tokens 1024 (avoid truncation that
suppressed base), robust last-'####'/'answer'/final-'=' extraction, logs truncation rate.
Applied identically to base+tuned. Usage: python qinao_gsm8k_fair.py <model> <adapter|none> <tag> [N]"""
import json, re, sys, random
from mlx_lm import load, generate
try:
    from mlx_lm.sample_utils import make_sampler; GREEDY=make_sampler(temp=0.0)
except Exception: GREEDY=None
from datasets import load_dataset
mp, ad, tag = sys.argv[1], (sys.argv[2] if sys.argv[2]!="none" else None), sys.argv[3]
N=int(sys.argv[4]) if len(sys.argv)>4 else 150
MX=1024
model, tok = load(mp, adapter_path=ad)
def ask(u):
    try: p=tok.apply_chat_template([{"role":"user","content":u}],add_generation_prompt=True,enable_thinking=True)
    except TypeError: p=tok.apply_chat_template([{"role":"user","content":u}],add_generation_prompt=True)
    kw={"max_tokens":MX,"verbose":False}
    if GREEDY is not None: kw["sampler"]=GREEDY
    return generate(model,tok,prompt=p,**kw)
def extract(resp):
    # prefer explicit #### / 'answer is' ; else number after the LAST '=' ; else last number
    m=re.findall(r'(?:####|answer\s*(?:is|:)?)\s*\$?(-?\d[\d,]*\.?\d*)', resp, re.I)
    if m: return m[-1].replace(",","").rstrip(".")
    eq=re.findall(r'=\s*\$?(-?\d[\d,]*\.?\d*)', resp)
    if eq: return eq[-1].replace(",","").rstrip(".")
    nums=re.findall(r'-?\d[\d,]*\.?\d*', resp.replace(",",""))
    return nums[-1].rstrip(".") if nums else None
ds=load_dataset("openai/gsm8k","main",split="test")
idx=list(range(len(ds))); random.seed(1); random.shuffle(idx); idx=idx[:N]
ok=tot=trunc=0
for i in idx:
    r=ds[i]; gold=r["answer"].split("####")[-1].strip().replace(",","")
    resp=ask(r["question"]+"\nReason step by step. End with: #### <final integer answer>")
    # truncation heuristic: no terminal '####' and response is long => likely hit the cap
    if "####" not in resp and len(resp)>MX*2: trunc+=1
    pred=extract(resp); tot+=1; ok+=(pred==gold)
sc=round(ok/max(1,tot)*100,1)
json.dump({"29_fair":sc,"_N":tot,"trunc_est":trunc}, open(f"/tmp/qinao_gsm8k_fair_{tag}.json","w"))
print(f"{tag} GSM8K(fair) = {ok}/{tot} = {sc}%  (trunc_est={trunc})")
