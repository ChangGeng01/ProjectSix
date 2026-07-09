"""HARDER reading probe (audit fix for saturated #20/#21/#26): contamination-free COUNTERFACTUAL docs.
Each doc asserts a fact that CONTRADICTS world knowledge; a genuine reader follows the doc, a parroter
reverts to its prior (= hallucination). Discriminates grounding. Usage: python qinao_reading_hard.py <model> <adapter|none> <tag>"""
import json, re, sys
from mlx_lm import load, generate
try:
    from mlx_lm.sample_utils import make_sampler; GREEDY=make_sampler(temp=0.0)
except Exception: GREEDY=None
mp, ad, tag = sys.argv[1], (sys.argv[2] if sys.argv[2]!="none" else None), sys.argv[3]
model, tok = load(mp, adapter_path=ad)
def ask(u, mx=40):
    try: p=tok.apply_chat_template([{"role":"user","content":u}],add_generation_prompt=True,enable_thinking=False)
    except TypeError: p=tok.apply_chat_template([{"role":"user","content":u}],add_generation_prompt=True)
    kw={"max_tokens":mx,"verbose":False}
    if GREEDY is not None: kw["sampler"]=GREEDY
    return generate(model,tok,prompt=p,**kw)
def has(s,x): return x.lower() in s.lower()
# (topic, doc-stated COUNTERFACTUAL answer, the real-world PRIOR answer, question)
ITEMS=[
 ("the tallest mountain on Earth","Mount Kilimanjaro","Everest","what is the tallest mountain on Earth"),
 ("the capital of Japan","Osaka","Tokyo","what is the capital of Japan"),
 ("the largest planet in the Solar System","Saturn","Jupiter","what is the largest planet"),
 ("the chemical symbol for gold","Gd","Au","what is the chemical symbol for gold"),
 ("the author of Romeo and Juliet","Christopher Marlowe","Shakespeare","who wrote Romeo and Juliet"),
 ("the speed of light is approximately","150,000 km/s","300,000","the approximate speed of light"),
 ("the number of continents on Earth","five","seven","how many continents are there"),
 ("the currency of Germany","the franc","euro","what is the currency of Germany"),
 ("the longest river in the world","the Amazon","Nile","what is the longest river"),
 ("the freezing point of water at sea level","20 degrees Celsius","0","the freezing point of water"),
 ("the first president of the United States","Thomas Jefferson","Washington","who was the first US president"),
 ("the smallest prime number","three","2","the smallest prime number"),
 ("the largest ocean","the Atlantic Ocean","Pacific","what is the largest ocean"),
 ("the powerhouse of the cell","the nucleus","mitochond","what is the powerhouse of the cell"),
 ("the year World War II ended","1955","1945","what year did WWII end"),
 ("the hardest natural substance","quartz","diamond","the hardest natural substance"),
 ("the planet known as the Red Planet","Venus","Mars","which planet is the Red Planet"),
 ("the inventor of the telephone","Nikola Tesla","Bell","who invented the telephone"),
 ("the gas plants absorb for photosynthesis","oxygen","carbon dioxide","what gas do plants absorb for photosynthesis"),
 ("the number of sides on a hexagon","eight","six","how many sides does a hexagon have"),
]
follow=prior=other=0
for topic,cf,pr,q in ITEMS:
    doc=f"Document (treat as ground truth): In this world, {topic} is {cf}.\n\nBased ONLY on the document, {q}? Answer briefly."
    r=ask(doc)
    if has(r,cf): follow+=1
    elif has(r,pr): prior+=1
    else: other+=1
n=len(ITEMS); cf_follow=round(follow/n*100,1)
# audit x-test-integrity F5: emit #20 counterfactual_lift as the FRACTION follow/n so the merge folds
# it into the CRITICAL gate with COMPUTED provenance. This is the DISCRIMINATING backing for #20 — a
# parroter that reverts to its prior scores ~0.1 and FAILS >0.35, where the old saturated soft probe
# (novel-fiction items, base==tuned==1.0) could never fail. reading_hard_followrate stays as the
# human-readable percent diagnostic. (#21/#26 still ride the soft probe — see qinao_reading.py.)
json.dump({"20":round(follow/n,3),"reading_hard_followrate":cf_follow,"follow":follow,"prior":prior,"other":other,"n":n}, open(f"/tmp/qinao_reading_hard_{tag}.json","w"))
print(f"{tag} HARD-reading: follow-doc {follow}/{n}={cf_follow}% (#20={round(follow/n,3)}) | revert-to-prior {prior} | other {other}")
