import json,re,sys,random
from mlx_lm import load, generate
try:
    from mlx_lm.sample_utils import make_sampler; G=make_sampler(temp=0.0)
except: G=None
mp,ad,tag=sys.argv[1],(sys.argv[2] if sys.argv[2]!="none" else None),sys.argv[3]
m,t=load(mp,adapter_path=ad)
LETTERS="ABCDEFGH"
def ask(u,mx=8):
    try:p=t.apply_chat_template([{"role":"user","content":u}],add_generation_prompt=True,enable_thinking=False)
    except TypeError:p=t.apply_chat_template([{"role":"user","content":u}],add_generation_prompt=True)
    kw={"max_tokens":mx,"verbose":False}
    if G:kw["sampler"]=G
    return generate(m,t,prompt=p,**kw)
def let(s,n):
    x=re.search(rf'[\(\s]?([A-{LETTERS[n-1]}])[\)\.\s]'," "+s+" ");return x.group(1) if x else None
items=[json.loads(l) for l in open("data_eval/tqa_mc.jsonl")]
random.seed(0); random.shuffle(items)
ok=tot=0
for it in items[:120]:
    mc=it.get("mc1_targets") or {}; ch=mc.get("choices"); labs=mc.get("labels")
    q=it.get("question")
    if not (q and ch and labs and 1 in labs): continue
    n=min(len(ch),8); ch=ch[:n]; labs=labs[:n]
    if 1 not in labs: continue
    # shuffle choices to avoid position bias, track correct
    idx=list(range(n)); random.shuffle(idx)
    sh=[ch[i] for i in idx]; correct=idx.index(labs.index(1))
    body="\n".join(f"({LETTERS[j]}) {c}" for j,c in enumerate(sh))
    a=let(ask(f"{q}\n{body}\nWhich is the correct/truthful answer? Reply with just the letter."),n)
    tot+=1; ok+=(a==LETTERS[correct])
sc=round(ok/max(1,tot)*100,1)
json.dump({"13":sc,"_N":tot},open(f"/tmp/qinao_tqa_{tag}.json","w"))
print(f"{tag} TruthfulQA-MC1 = {ok}/{tot} = {sc}%")
