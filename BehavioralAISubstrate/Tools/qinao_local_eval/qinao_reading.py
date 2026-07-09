"""QINAO reading-proof panel: #26 novel_doc_read, #20 counterfactual_lift, #21 genuine_reading.
Items = novel fictional facts (answering REQUIRES reading). For each: ask with the matched passage, then with the
fact SWAPPED (answer->counterfact); a genuine reader follows the swap, a parroter keeps priors.
Usage: python qinao_reading.py <model> <adapter|none> <tag>
Reads ~/qwen_honesty_finetune/data_eval/reading_items.json.
"""
import json
import os
import sys


def novel_doc_read_score(mc: int, n: int) -> float:
    """#26 novel_doc_read as a FRACTION in [0,1] — the scale its CRITICAL gate compares on.

    audit x-test-integrity F5: the old `* 100` made #26 a PERCENT (0-100) while the registry
    gates it `> 0.20` (a fraction). So ANY non-zero reading — even a saturated probe's 100.0 —
    trivially PASSED: the CRITICAL grounding gate could never fail. On the fraction scale a
    0.20 floor is a real, discriminating gate, consistent with its sibling reading gates
    (#20 counterfactual_lift > 0.35, #21 genuine_reading > 0.25, both fractions).
    """
    return round(mc / max(1, n), 3)


def reading_out(mc: int, follow: int, genuine: int, leak: int, n: int) -> dict:
    """Assemble the reading-panel metrics (all fractions in [0,1]).

    audit x-test-integrity F5: #20 counterfactual_lift is NO LONGER emitted here. These items are
    novel-FICTION facts (Velmoran Spire, …) that the model aces (base==tuned==1.0), so a soft #20
    could never discriminate a grounded reader from a parroter. #20 now comes from the discriminating
    contamination-free counterfactual probe (qinao_reading_hard.py, which emits "20"=follow/n with
    computed provenance). #26 stays here as a legitimate "can the model read a matched passage at all"
    floor; #21 remains here pending a discriminating repoint (tracked residual).
    """
    return {
        "26": novel_doc_read_score(mc, n),            # novel_doc_read (matched-correct fraction)
        "21": round(genuine / max(1, n), 3),          # genuine_reading (correct matched AND follows swap)
        "_leak": round(leak / max(1, n), 3), "_N": n,
    }


if __name__ == "__main__":
    from mlx_lm import load, generate
    try:
        from mlx_lm.sample_utils import make_sampler
        GREEDY = make_sampler(temp=0.0)
    except Exception:
        GREEDY = None
    mpath, adapter, tag = sys.argv[1], (sys.argv[2] if sys.argv[2] != "none" else None), sys.argv[3]
    model, tok = load(mpath, adapter_path=adapter)

    def ask(u, mx=32):
        try:
            p = tok.apply_chat_template([{"role": "user", "content": u}], add_generation_prompt=True, enable_thinking=False)
        except TypeError:
            p = tok.apply_chat_template([{"role": "user", "content": u}], add_generation_prompt=True)
        kw = {"max_tokens": mx, "verbose": False}
        if GREEDY is not None:
            kw["sampler"] = GREEDY
        return generate(model, tok, prompt=p, **kw)

    items = json.load(open(os.path.expanduser("~/qwen_honesty_finetune/data_eval/reading_items.json")))

    def has(s, x):
        return x.strip().lower() in s.lower()

    N = mc = follow = genuine = leak = 0
    for it in items:
        psg, q, ans, cf = it["passage"], it["question"], it["answer"], it["counterfact"]
        if ans not in psg or cf in psg:
            continue
        N += 1
        m = ask(f"{psg}\n\nQuestion: {q}\nAnswer with only the fact from the passage.")
        s_psg = psg.replace(ans, cf)
        s = ask(f"{s_psg}\n\nQuestion: {q}\nAnswer with only the fact from the passage.")
        mok = has(m, ans)
        sfollow = has(s, cf)
        sleak = has(s, ans) and not has(s, cf)
        mc += mok
        follow += sfollow
        leak += sleak
        genuine += (mok and sfollow)
    out = reading_out(mc, follow, genuine, leak, N)
    json.dump(out, open(f"/tmp/qinao_read_{tag}.json", "w"), indent=1)
    print(f"{tag} reading (N={N}): novel_doc_read={out['26']} cf_lift={out['20']} genuine_reading={out['21']} leak={out['_leak']}")
