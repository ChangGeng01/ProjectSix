"""HARDER reading probe (audit fix for saturated #20/#21/#26): contamination-free COUNTERFACTUAL docs.
Arm B: each doc asserts a fact CONTRADICTING world knowledge; a genuine reader follows the doc, a
parroter reverts to its prior (= hallucination) -> #20 counterfactual_lift = follow/n.
Arm A (audit F5 residual #21, 2026-07-11): a TRUE-fact doc per item -- matched extraction. #21
genuine_reading = fraction(matched_ok AND follow), the conjunction: it additionally catches a
doc-contrarian/extraction-broken model that follows counterfactuals (passes #20) but cannot read a
true doc. Both gates ride COMPUTED provenance via the merge. Discriminates grounding.
Usage: python qinao_reading_hard.py <model> <adapter|none> <tag>"""
import json
import sys


def hard_reading_out(matched: int, follow: int, genuine: int, prior: int, other: int, n: int) -> dict:
    """Assemble the hard-probe sidefile (fractions in [0,1] for the gated metrics).

    audit x-test-integrity F5: "20" = follow/n (counterfactual follow, gate >0.35) and -- residual
    #21 repoint (2026-07-11) -- "21" = genuine/n where genuine = matched_ok AND follow per item
    (gate >0.25). genuine <= min(matched, follow) by construction; enforce it here so a probe bug
    can never silently inflate the CRITICAL gate.
    """
    if genuine > min(matched, follow):
        raise ValueError(
            f"genuine ({genuine}) exceeds min(matched={matched}, follow={follow}) -- "
            "the conjunction invariant is broken; refusing to emit an inflated #21")
    return {
        "20": round(follow / max(1, n), 3),
        "21": round(genuine / max(1, n), 3),
        "reading_hard_followrate": round(follow / max(1, n) * 100, 1),
        "_matched_frac": round(matched / max(1, n), 3),
        "follow": follow, "matched": matched, "genuine": genuine,
        "prior": prior, "other": other, "n": n,
    }


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


if __name__ == "__main__":
    from mlx_lm import load, generate
    try:
        from mlx_lm.sample_utils import make_sampler
        GREEDY = make_sampler(temp=0.0)
    except Exception:
        GREEDY = None
    mp, ad, tag = sys.argv[1], (sys.argv[2] if sys.argv[2] != "none" else None), sys.argv[3]
    model, tok = load(mp, adapter_path=ad)

    def ask(u, mx=40):
        try:
            p = tok.apply_chat_template([{"role": "user", "content": u}], add_generation_prompt=True, enable_thinking=False)
        except TypeError:
            p = tok.apply_chat_template([{"role": "user", "content": u}], add_generation_prompt=True)
        kw = {"max_tokens": mx, "verbose": False}
        if GREEDY is not None:
            kw["sampler"] = GREEDY
        return generate(model, tok, prompt=p, **kw)

    def has(s, x):
        return x.lower() in s.lower()

    matched = follow = genuine = prior = other = 0
    for topic, cf, pr, q in ITEMS:
        # Arm B -- counterfactual: a genuine reader follows the doc against its prior.
        doc_cf = f"Document (treat as ground truth): In this world, {topic} is {cf}.\n\nBased ONLY on the document, {q}? Answer briefly."
        r_cf = ask(doc_cf)
        item_follow = has(r_cf, cf)
        if item_follow:
            follow += 1
        elif has(r_cf, pr):
            prior += 1
        else:
            other += 1
        # Arm A -- matched TRUE doc: can the model extract at all? (F5 residual #21, 2026-07-11)
        doc_true = f"Document (treat as ground truth): In this world, {topic} is {pr}.\n\nBased ONLY on the document, {q}? Answer briefly."
        item_matched = has(ask(doc_true), pr)
        matched += item_matched
        genuine += (item_matched and item_follow)

    n = len(ITEMS)
    out = hard_reading_out(matched=matched, follow=follow, genuine=genuine, prior=prior, other=other, n=n)
    json.dump(out, open(f"/tmp/qinao_reading_hard_{tag}.json", "w"))
    print(f"{tag} HARD-reading: follow-doc {follow}/{n} (#20={out['20']}) | matched {matched}/{n} | "
          f"genuine(conj) {genuine}/{n} (#21={out['21']}) | revert-to-prior {prior} | other {other}")
